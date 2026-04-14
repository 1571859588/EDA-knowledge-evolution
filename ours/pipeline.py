"""
pipeline.py — 4 阶段 Tri-Polar Memory Pipeline 编排器

完整流程：
  阶段 1：实体抽取 + KG 语义锚定  →  C_base
  阶段 2：知识增强查询重构        →  Q_dense
  阶段 3：双路召回 (Dense+BM25)   →  D_recall
  阶段 4：Cross-Encoder 精筛      →  D_final
  Solver：Working Memory 组装 + LLM 生成  →  Answer
"""

from __future__ import annotations

import os
import re
import time
from typing import Any

import yaml
from dotenv import load_dotenv

load_dotenv()


# ═══════════════════════════════════════════════════════════════════════════════
# 配置与 LLM 工具
# ═══════════════════════════════════════════════════════════════════════════════

def load_config(config_path: str) -> dict[str, Any]:
    """加载配置文件，展开 ${ENV_VAR:default} 环境变量。"""
    with open(config_path, encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    def expand(val: str) -> str:
        def replacer(m: re.Match) -> str:
            parts = m.group(1).split(":", 1)
            return os.environ.get(parts[0], parts[1] if len(parts) > 1 else "")
        return re.sub(r"\$\{([^}]+)\}", replacer, val) if isinstance(val, str) else val

    def deep_expand(obj: Any) -> Any:
        if isinstance(obj, dict):
            return {k: deep_expand(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [deep_expand(i) for i in obj]
        return expand(obj) if isinstance(obj, str) else obj

    return deep_expand(raw)


def make_llm_caller(config: dict[str, Any], llm_key: str = "llm"):
    """创建 OpenAI 兼容的 LLM 调用函数。"""
    from openai import OpenAI

    llm_cfg = config.get(llm_key, config.get("llm", {}))
    client = OpenAI(
        api_key=llm_cfg.get("api_key", ""),
        base_url=llm_cfg.get("api_base", "https://api.openai.com/v1"),
    )
    model = llm_cfg.get("model", "gpt-4o-mini")
    temperature = float(llm_cfg.get("temperature", 0.0))
    max_tokens = int(llm_cfg.get("max_tokens", 2048))

    def call(prompt: str) -> str:
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return resp.choices[0].message.content or ""

    return call


def make_embedder(config: dict[str, Any]):
    """创建 sentence-transformers Embedder。"""
    from sentence_transformers import SentenceTransformer
    import numpy as np

    emb_cfg = config.get("embedding", {})
    model_name = emb_cfg.get("model_name", "sentence-transformers/all-MiniLM-L6-v2")
    device = emb_cfg.get("device", "cpu")

    model = SentenceTransformer(model_name, device=device)

    class _Embedder:
        def __init__(self, m):
            self._model = m
            self.dim = m.get_sentence_embedding_dimension()

        def encode(self, texts, show_progress=True):
            return self._model.encode(
                texts,
                show_progress_bar=show_progress,
                convert_to_numpy=True,
            )

    return _Embedder(model)


# ═══════════════════════════════════════════════════════════════════════════════
# Pipeline 类
# ═══════════════════════════════════════════════════════════════════════════════

class TriPolarPipeline:
    """Tri-Polar Memory 4 阶段推理 Pipeline。"""

    def __init__(self, config_path: str = "ours/config.yaml") -> None:
        print("[Pipeline] 加载配置...")
        self.config = load_config(config_path)

        print("[Pipeline] 初始化 LLM...")
        self.llm = make_llm_caller(self.config, "llm")

        print("[Pipeline] 初始化 Embedder...")
        self.embedder = make_embedder(self.config)

        print("[Pipeline] 加载底层语义记忆 (KG)...")
        from ours.memory.semantic_memory import SemanticMemory
        kg_path = self.config.get("semantic_memory", {}).get(
            "kg_path", "ours/knowledge_store/semantic_kg.json"
        )
        self.semantic_memory = SemanticMemory.load(kg_path)
        print(f"  → {self.semantic_memory.summary()}")

        print("[Pipeline] 加载中层情景记忆 (VectorDB)...")
        from ours.memory.episodic_memory import EpisodicMemory
        index_dir = self.config.get("episodic_memory", {}).get(
            "index_dir", "ours/knowledge_store/episodic_index"
        )
        self.episodic_memory = EpisodicMemory.load(index_dir)

        print("[Pipeline] 初始化各阶段 Agent...")
        from ours.agents.entity_extractor import EntityExtractor
        from ours.agents.query_expander import QueryExpander
        from ours.agents.dual_retriever import DualRetriever
        from ours.agents.reranker import CrossEncoderReranker
        from ours.solver import Solver

        self.entity_extractor = EntityExtractor(self.llm, self.config)
        self.query_expander = QueryExpander(self.llm, self.config)
        self.dual_retriever = DualRetriever(self.embedder, self.config)
        self.reranker = CrossEncoderReranker(self.config)
        self.solver = Solver(self.llm, self.config)

        print("[Pipeline] ✅ 初始化完成！")

    def run(self, question: str) -> dict[str, Any]:
        """对单个问题执行完整的 4 阶段推理。

        Returns
        -------
        dict with keys:
            answer: str               最终回答
            entities: list[str]       抽取的实体
            base_concepts: str        KG 概念上下文
            expanded_query: str       扩展后的查询
            recall_chunks: list       粗筛文档
            final_chunks: list        精筛文档
            retrieved_chunk_ids: list  精筛文档的 source id（用于 Recall@K 计算）
            stage_times: dict[str, float]  各阶段耗时
        """
        times: dict[str, float] = {}

        # ── 阶段 1：实体抽取 + KG 锚定 ─────────────────────────────────────────
        t0 = time.time()
        entities, kg_result, base_concepts = self.entity_extractor.run(
            question, self.semantic_memory
        )
        times["stage1_entity_extraction"] = time.time() - t0

        # 从 KG 结果中提取例题
        from ours.memory.working_memory import WorkingMemory
        wm = WorkingMemory(self.config)
        examples = wm.format_examples(kg_result.get("concepts", []))

        # ── 阶段 2：查询重构 ────────────────────────────────────────────────────
        t0 = time.time()
        expanded_query = self.query_expander.expand(question, base_concepts)
        times["stage2_query_expansion"] = time.time() - t0

        # ── 阶段 3：双路召回 ────────────────────────────────────────────────────
        t0 = time.time()
        recall_results = self.dual_retriever.retrieve(
            expanded_query, self.episodic_memory
        )
        times["stage3_dual_retrieval"] = time.time() - t0

        # ── 阶段 4：Cross-Encoder 精筛 ─────────────────────────────────────────
        t0 = time.time()
        final_results = self.reranker.rerank(
            question, base_concepts, recall_results
        )
        times["stage4_reranking"] = time.time() - t0

        # ── Solver：Working Memory 组装 + 生成 ─────────────────────────────────
        t0 = time.time()
        answer = self.solver.solve(
            question=question,
            base_concepts=base_concepts,
            examples=examples,
            ranked_docs=final_results,
        )
        times["stage5_generation"] = time.time() - t0

        # 收集精筛文档的 chunk id（供 Recall@K 计算）
        retrieved_ids = [
            meta.get("source", "") for meta, _ in final_results
        ]
        # 也包含粗筛的供分析
        recall_ids = [
            meta.get("source", "") for meta, _ in recall_results
        ]

        return {
            "answer": answer,
            "entities": entities,
            "base_concepts": base_concepts,
            "examples": examples,
            "expanded_query": expanded_query,
            "recall_chunk_ids": recall_ids,
            "final_chunk_ids": retrieved_ids,
            "recall_count": len(recall_results),
            "final_count": len(final_results),
            "stage_times": times,
        }
