"""
episodic_memory.py — 中层情景记忆（Episodic Memory）

基于 FAISS（密集检索）+ BM25（稀疏检索）的双索引文档存储。
存储 OpenROAD 工业文档的切片，支持：
  - Dense Search：Embedding 余弦相似度
  - Sparse Search：BM25 关键词匹配
  - Hybrid Search：RRF（Reciprocal Rank Fusion）融合

这是"温数据"层——随文档更新而增量构建。
"""

from __future__ import annotations

import json
import os
import pickle
from pathlib import Path
from typing import Any

import faiss
import numpy as np
from rank_bm25 import BM25Okapi


class EpisodicMemory:
    """FAISS + BM25 双索引文档检索。"""

    def __init__(self, dim: int = 384) -> None:
        self.dim = dim
        self.index: faiss.IndexFlatIP | None = None   # Inner Product (归一化后 = cosine)
        self.metadata: list[dict[str, Any]] = []       # 每条对应一个 chunk
        self.bm25: BM25Okapi | None = None
        self._tokenized_corpus: list[list[str]] = []

    # ── 构建 ──────────────────────────────────────────────────────────────────

    def build(
        self,
        texts: list[str],
        embeddings: np.ndarray,
        metadata_list: list[dict[str, Any]],
    ) -> None:
        """从文本、嵌入、元数据三组并行列表构建双索引。

        Parameters
        ----------
        texts : list[str]
            原始文本列表（用于 BM25 索引）。
        embeddings : np.ndarray
            形状 (N, dim) 的嵌入矩阵（用于 FAISS 索引）。
        metadata_list : list[dict]
            每条记录的元数据，需包含 'text', 'source' 字段。
        """
        assert len(texts) == len(embeddings) == len(metadata_list)

        # FAISS 索引（L2 归一化后做 Inner Product = Cosine Similarity）
        self.dim = embeddings.shape[1]
        faiss.normalize_L2(embeddings)
        self.index = faiss.IndexFlatIP(self.dim)
        self.index.add(embeddings)

        self.metadata = metadata_list

        # BM25 索引
        self._tokenized_corpus = [self._tokenize(t) for t in texts]
        self.bm25 = BM25Okapi(self._tokenized_corpus)

    @staticmethod
    def _tokenize(text: str) -> list[str]:
        """简单的空白 + 标点 tokenizer，适用于英文 EDA 文档。"""
        import re
        return re.findall(r"\w+", text.lower())

    # ── 检索 ──────────────────────────────────────────────────────────────────

    def dense_search(
        self,
        query_embedding: np.ndarray,
        top_k: int = 20,
    ) -> list[tuple[dict, float]]:
        """FAISS 密集检索，返回 [(metadata, score), ...]。"""
        if self.index is None:
            return []
        q = query_embedding.reshape(1, -1).astype(np.float32)
        faiss.normalize_L2(q)
        scores, indices = self.index.search(q, min(top_k, self.index.ntotal))
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0:
                continue
            results.append((self.metadata[idx], float(score)))
        return results

    def sparse_search(
        self,
        query_text: str,
        top_k: int = 20,
    ) -> list[tuple[dict, float]]:
        """BM25 稀疏检索，返回 [(metadata, score), ...]。"""
        if self.bm25 is None:
            return []
        tokens = self._tokenize(query_text)
        scores = self.bm25.get_scores(tokens)
        ranked = np.argsort(scores)[::-1][:top_k]
        results = []
        for idx in ranked:
            if scores[idx] > 0:
                results.append((self.metadata[idx], float(scores[idx])))
        return results

    def hybrid_search(
        self,
        query_text: str,
        query_embedding: np.ndarray,
        dense_top_k: int = 20,
        sparse_top_k: int = 20,
        hybrid_top_k: int = 20,
        rrf_k: int = 60,
    ) -> list[tuple[dict, float]]:
        """RRF（Reciprocal Rank Fusion）融合双路召回结果。

        RRF_score(d) = sum_over_systems( 1 / (rrf_k + rank_i(d)) )
        """
        dense_results = self.dense_search(query_embedding, dense_top_k)
        sparse_results = self.sparse_search(query_text, sparse_top_k)

        # 用 chunk 的 source (chunk_id) 作为去重键
        rrf_scores: dict[str, float] = {}
        rrf_meta: dict[str, dict] = {}

        for rank, (meta, _score) in enumerate(dense_results):
            key = meta.get("source", str(rank))
            rrf_scores[key] = rrf_scores.get(key, 0.0) + 1.0 / (rrf_k + rank + 1)
            rrf_meta[key] = meta

        for rank, (meta, _score) in enumerate(sparse_results):
            key = meta.get("source", f"sparse_{rank}")
            rrf_scores[key] = rrf_scores.get(key, 0.0) + 1.0 / (rrf_k + rank + 1)
            rrf_meta[key] = meta

        # 按 RRF 分数降序排列
        sorted_keys = sorted(rrf_scores, key=lambda k: rrf_scores[k], reverse=True)
        results = [
            (rrf_meta[k], rrf_scores[k])
            for k in sorted_keys[:hybrid_top_k]
        ]
        return results

    # ── 序列化 ────────────────────────────────────────────────────────────────

    def save(self, index_dir: str) -> None:
        """将 FAISS 索引 + 元数据 + BM25 模型保存到目录。"""
        dirpath = Path(index_dir)
        dirpath.mkdir(parents=True, exist_ok=True)

        if self.index is not None:
            faiss.write_index(self.index, str(dirpath / "faiss.index"))

        with open(dirpath / "metadata.json", "w", encoding="utf-8") as f:
            json.dump(self.metadata, f, ensure_ascii=False, indent=2)

        with open(dirpath / "bm25.pkl", "wb") as f:
            pickle.dump(
                {"bm25": self.bm25, "tokenized_corpus": self._tokenized_corpus},
                f,
            )

        print(f"[EpisodicMemory] 已保存至 '{index_dir}' (共 {len(self.metadata)} 条)")

    @classmethod
    def load(cls, index_dir: str) -> "EpisodicMemory":
        """从目录加载已持久化的索引。"""
        dirpath = Path(index_dir)
        mem = cls()

        mem.index = faiss.read_index(str(dirpath / "faiss.index"))
        mem.dim = mem.index.d

        with open(dirpath / "metadata.json", encoding="utf-8") as f:
            mem.metadata = json.load(f)

        bm25_path = dirpath / "bm25.pkl"
        if bm25_path.exists():
            with open(bm25_path, "rb") as f:
                bm25_data = pickle.load(f)  # noqa: S301
                mem.bm25 = bm25_data["bm25"]
                mem._tokenized_corpus = bm25_data["tokenized_corpus"]

        print(f"[EpisodicMemory] 已加载 '{index_dir}' ({len(mem.metadata)} 条, dim={mem.dim})")
        return mem
