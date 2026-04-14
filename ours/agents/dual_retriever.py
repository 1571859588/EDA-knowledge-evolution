"""
dual_retriever.py — 阶段 3：双路召回

Pipeline 第三步：
  同时执行 Dense Retrieval（Embedding 相似度）和 Sparse Retrieval（BM25），
  再通过 RRF 融合排序，得到粗筛的候选文档集 D_recall。
"""

from __future__ import annotations

from typing import Any

import numpy as np

from ours.memory.episodic_memory import EpisodicMemory


class DualRetriever:
    """Dense + BM25 双路召回器。"""

    def __init__(
        self,
        embedder,          # 需要有 encode([text]) -> np.ndarray 的方法
        config: dict[str, Any],
    ) -> None:
        self.embedder = embedder
        ret_cfg = config.get("retrieval", {})
        self.dense_top_k: int = ret_cfg.get("dense_top_k", 20)
        self.sparse_top_k: int = ret_cfg.get("sparse_top_k", 20)
        self.hybrid_top_k: int = ret_cfg.get("hybrid_top_k", 20)
        self.rrf_k: int = ret_cfg.get("rrf_k", 60)

    def retrieve(
        self,
        query_text: str,
        episodic_memory: EpisodicMemory,
    ) -> list[tuple[dict, float]]:
        """执行双路召回并返回 RRF 融合后的排序结果。

        Parameters
        ----------
        query_text : str
            扩展后的查询文本 Q_dense（来自阶段 2）。
        episodic_memory : EpisodicMemory
            中层情景记忆实例。

        Returns
        -------
        list[tuple[dict, float]]
            RRF 融合排序后的 [(metadata, rrf_score), ...]，
            按 rrf_score 降序，最多 hybrid_top_k 条。
        """
        # 编码查询文本为向量
        q_emb = self.embedder.encode([query_text], show_progress=False)
        if isinstance(q_emb, list):
            q_emb = np.array(q_emb)
        q_emb = q_emb[0]  # 取出单个向量

        # 执行双路检索 + RRF 融合
        results = episodic_memory.hybrid_search(
            query_text=query_text,
            query_embedding=q_emb,
            dense_top_k=self.dense_top_k,
            sparse_top_k=self.sparse_top_k,
            hybrid_top_k=self.hybrid_top_k,
            rrf_k=self.rrf_k,
        )
        return results
