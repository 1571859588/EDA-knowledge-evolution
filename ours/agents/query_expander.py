"""
query_expander.py — 阶段 2：基于常识的查询重构

Pipeline 第二步：
  "带着常识去搜索，比带着问题去搜索更准。"

  输入：原始问题 Q_raw + 基础概念上下文 C_base
  输出：扩展后的检索查询 Q_dense

  示例：
    原问题: "怎么修 setup violation"
    → 扩展: "OpenROAD 中通过 repair_timing -setup 或 insert_buffer
             来优化 setup time violation 的 Tcl 命令调用及参数说明"
"""

from __future__ import annotations

from typing import Any


class QueryExpander:
    """知识增强的查询重构器。"""

    def __init__(
        self,
        llm_caller,       # callable(prompt) -> str
        config: dict[str, Any],
    ) -> None:
        self.llm = llm_caller
        self.prompt_template: str = config.get(
            "query_expansion_prompt",
            (
                "原始问题：{question}\n"
                "基础概念上下文：\n{base_context}\n"
                "请生成一个更精准的检索查询："
            ),
        )

    def expand(self, question: str, base_context: str) -> str:
        """根据原始问题和基础概念生成扩展检索查询。

        Parameters
        ----------
        question : str
            用户原始问题。
        base_context : str
            阶段 1 从知识图谱中取到的概念上下文。

        Returns
        -------
        str
            扩展后的查询字符串（用于密集检索）。
        """
        if not base_context or base_context.strip() == "（未找到相关基础概念）":
            # 没有找到 KG 锚点时，退化为原始问题 + 领域前缀
            return f"OpenROAD EDA: {question}"

        prompt = self.prompt_template.format(
            question=question,
            base_context=base_context,
        )
        expanded = self.llm(prompt)
        # 清理输出（去掉多余的引号、换行等）
        expanded = expanded.strip().strip('"').strip("'")
        # 如果扩展结果过长或过短，降级回原问题
        if len(expanded) < 10 or len(expanded) > 1000:
            return question
        return expanded
