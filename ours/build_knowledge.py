"""
build_knowledge.py — 一键构建底层语义 KG + 中层向量索引

从 ORD-QA 的 openroad_documentation.json 出发：
  1. 底层 KG：对每个文档 chunk 调用 LLM 抽取三元组，写入 NetworkX 图谱
  2. 中层索引：对每个 chunk 编码为向量，写入 FAISS + BM25 双索引

用法（在项目根目录）：
    uv run python ours/build_knowledge.py \\
        --doc_json benchmarks/ORD-QA/benchmark/openroad_documentation.json \\
        --config   ours/config.yaml
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

# 确保项目根在 sys.path 中
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ours.pipeline import load_config, make_llm_caller, make_embedder
from ours.memory.semantic_memory import (
    SemanticMemory,
    KG_EXTRACTION_PROMPT,
    build_kg_from_llm_response,
)
from ours.memory.episodic_memory import EpisodicMemory


# ── 文档加载 ──────────────────────────────────────────────────────────────────

def load_documentation(doc_json: str) -> list[dict]:
    with open(doc_json, encoding="utf-8") as f:
        raw = json.load(f)
    if isinstance(raw, list):
        return [
            {"id": str(item.get("id", f"chunk_{i}")),
             "content": item.get("content") or item.get("text") or item.get("body", "")}
            for i, item in enumerate(raw)
        ]
    if isinstance(raw, dict):
        return [{"id": k, "content": v} for k, v in raw.items()]
    raise ValueError(f"Unrecognized format in {doc_json}")


# ── 底层 KG 构建 ──────────────────────────────────────────────────────────────

def build_semantic_kg(
    chunks: list[dict],
    config: dict,
) -> SemanticMemory:
    """对每个 chunk 调用 LLM 抽取三元组，构建知识图谱。"""
    memory = SemanticMemory()
    llm = make_llm_caller(config, "kg_builder_llm")

    print(f"[KG] 开始抽取，共 {len(chunks)} 个 chunk。")
    for i, chunk in enumerate(chunks):
        chunk_id = chunk["id"]
        text = chunk["content"][:3000]  # 截断超长文本

        prompt = KG_EXTRACTION_PROMPT.format(chunk_id=chunk_id, text=text)

        try:
            response = llm(prompt)
            build_kg_from_llm_response(memory, response, chunk_id)
        except Exception as e:
            print(f"  [KG] ⚠️ chunk {chunk_id} 抽取失败: {e}")
            continue

        if (i + 1) % 20 == 0 or i == len(chunks) - 1:
            print(f"  [KG] 进度: {i+1}/{len(chunks)} | {memory.summary()}")

    return memory


# ── 中层向量索引构建 ──────────────────────────────────────────────────────────

def build_episodic_index(
    chunks: list[dict],
    config: dict,
) -> EpisodicMemory:
    """将文档 chunk 编码为向量，构建 FAISS + BM25 双索引。"""
    embedder = make_embedder(config)

    # 二次切片（如有超长 chunk）
    ep_cfg = config.get("episodic_memory", {})
    chunk_size = ep_cfg.get("chunk_size", 600)
    chunk_overlap = ep_cfg.get("chunk_overlap", 80)

    all_chunks = []
    for c in chunks:
        text = c["content"]
        if len(text) <= chunk_size:
            all_chunks.append(c)
        else:
            start = 0
            sub_idx = 0
            while start < len(text):
                end = min(start + chunk_size, len(text))
                all_chunks.append({
                    "id": f"{c['id']}__sub{sub_idx}",
                    "content": text[start:end],
                })
                sub_idx += 1
                start += chunk_size - chunk_overlap

    print(f"[VectorDB] 切片后共 {len(all_chunks)} 个 chunk。")

    texts = [c["content"] for c in all_chunks]
    meta_list = [
        {"text": c["content"], "source": c["id"]}
        for c in all_chunks
    ]

    print("[VectorDB] 编码文档向量...")
    embeddings = embedder.encode(texts, show_progress=True)
    if not isinstance(embeddings, np.ndarray):
        embeddings = np.array(embeddings)
    embeddings = embeddings.astype(np.float32)

    memory = EpisodicMemory(dim=embeddings.shape[1])
    memory.build(texts, embeddings, meta_list)
    return memory


# ── 主入口 ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="构建 TPMA 底层语义 KG + 中层向量索引"
    )
    parser.add_argument(
        "--doc_json",
        default="benchmarks/ORD-QA/benchmark/openroad_documentation.json",
        help="OpenROAD 文档 JSON 路径",
    )
    parser.add_argument("--config", default="ours/config.yaml", help="配置文件")
    parser.add_argument("--skip_kg", action="store_true", help="跳过 KG 构建（仅建向量索引）")
    parser.add_argument("--skip_vector", action="store_true", help="跳过向量索引构建（仅建 KG）")
    args = parser.parse_args()

    config = load_config(args.config)
    chunks = load_documentation(args.doc_json)
    print(f"[Build] 读取到 {len(chunks)} 个文档 chunk。")

    # 底层 KG
    if not args.skip_kg:
        print("\n" + "=" * 60)
        print("  构建底层语义记忆 (Knowledge Graph)")
        print("=" * 60)
        t0 = time.time()
        kg = build_semantic_kg(chunks, config)
        kg_path = config.get("semantic_memory", {}).get(
            "kg_path", "ours/knowledge_store/semantic_kg.json"
        )
        kg.save(kg_path)
        print(f"[KG] ✅ 保存至 {kg_path}（耗时 {time.time()-t0:.1f}s）")
        print(f"[KG] {kg.summary()}")
    else:
        print("[Build] 跳过 KG 构建 (--skip_kg)")

    # 中层向量索引
    if not args.skip_vector:
        print("\n" + "=" * 60)
        print("  构建中层情景记忆 (FAISS + BM25)")
        print("=" * 60)
        t0 = time.time()
        episodic = build_episodic_index(chunks, config)
        index_dir = config.get("episodic_memory", {}).get(
            "index_dir", "ours/knowledge_store/episodic_index"
        )
        episodic.save(index_dir)
        print(f"[VectorDB] ✅ 保存至 {index_dir}（耗时 {time.time()-t0:.1f}s）")
    else:
        print("[Build] 跳过向量索引构建 (--skip_vector)")

    print("\n✅ 知识库构建完成！")


if __name__ == "__main__":
    main()
