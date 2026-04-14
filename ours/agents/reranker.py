"""
reranker.py — 阶段 4：交叉注意力精筛

Pipeline 第四步：
  使用 Cross-Encoder 模型对 (Q_raw + C_base, candidate_chunk) 打分。
  Cross-Encoder 能够捕捉查询与文档之间的深层语义交互（不同于 Bi-Encoder 的独立编码），
  以此剔除噪音、保留最高质量的文档片段。

  模型默认使用 cross-encoder/ms-marco-MiniLM-L-6-v2，轻量且效果好。
"""

from __future__ import annotations

from typing import Any


class CrossEncoderReranker:
    """Cross-Encoder 精筛器。"""

    def __init__(self, config: dict[str, Any]) -> None:
        reranker_cfg = config.get("reranker", {})
        self.model_name: str = reranker_cfg.get(
            "model_name", "cross-encoder/ms-marco-MiniLM-L-6-v2"
        )
        self.device: str = reranker_cfg.get("device", "cpu")
        self.score_threshold: float = reranker_cfg.get("score_threshold", 0.3)
        self.top_k: int = reranker_cfg.get("top_k", 5)

        self._model = None  # 延迟加载

    def _ensure_model(self) -> None:
        """延迟加载 Cross-Encoder 模型（首次调用时才加载）。"""
        if self._model is not None:
            return
        from sentence_transformers import CrossEncoder
        print(f"[Reranker] 加载模型: {self.model_name} (device={self.device})")
        self._model = CrossEncoder(self.model_name, device=self.device)

    def rerank(
        self,
        question: str,
        base_context: str,
        candidates: list[tuple[dict, float]],
    ) -> list[tuple[dict, float]]:
        """对候选文档进行 Cross-Encoder 重排序。

        Parameters
        ----------
        question : str
            用户原始问题 Q_raw。
        base_context : str
            阶段 1 的概念上下文 C_base（作为条件拼接到 query 侧）。
        candidates : list[tuple[dict, float]]
            阶段 3 粗筛的候选列表 [(metadata, rrf_score), ...]。

        Returns
        -------
        list[tuple[dict, float]]
            重排序后的 Top-K 列表 [(metadata, ce_score), ...]。
        """
        if not candidates:
            return []

        self._ensure_model()

        # 构造 Cross-Encoder 输入对：(query_side, document_side)
        # query_side = 原始问题 + 概念上下文（截断以控制长度）
        query_side = f"{question}\n\n{base_context[:500]}" if base_context else question

        pairs = [
            (query_side, meta.get("text", ""))
            for meta, _ in candidates
        ]

        # Cross-Encoder 打分
        scores = self._model.predict(pairs)

        # 按分数降序排列，过滤低分，取 Top-K
        scored = sorted(
            zip(candidates, scores),
            key=lambda x: x[1],
            reverse=True,
        )

        results = []
        for (meta, _old_score), ce_score in scored:
            if len(results) >= self.top_k:
                break
            if ce_score >= self.score_threshold:
                results.append((meta, float(ce_score)))

        # 如果全部被过滤，至少保留分数最高的一个
        if not results and scored:
            best_meta, _old = scored[0][0]
            results.append((best_meta, float(scored[0][1])))

        return results
