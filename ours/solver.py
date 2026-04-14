"""
solver.py — Solver Agent：最终答案生成

在工作记忆（Working Memory）中组装好结构化 Prompt 后，调用 LLM 生成最终回答。
"""

from __future__ import annotations

from typing import Any

from ours.memory.working_memory import WorkingMemory


class Solver:
    """最终答案生成器。"""

    def __init__(
        self,
        llm_caller,        # callable(prompt) -> str
        config: dict[str, Any],
    ) -> None:
        self.llm = llm_caller
        self.working_memory = WorkingMemory(config)

    def solve(
        self,
        question: str,
        base_concepts: str,
        examples: str,
        ranked_docs: list[tuple[dict, float]],
    ) -> str:
        """组装 Prompt → 调用 LLM → 返回答案。

        Parameters
        ----------
        question : str
            用户原始问题。
        base_concepts : str
            阶段 1：KG 概念上下文。
        examples : str
            阶段 1：例题片段。
        ranked_docs : list[tuple[dict, float]]
            阶段 4：精筛后的工业文档。

        Returns
        -------
        str
            LLM 生成的最终答案。
        """
        # 格式化工业文档
        industrial_docs = self.working_memory.format_industrial_docs(ranked_docs)

        # 组装完整 Prompt
        prompt = self.working_memory.assemble(
            question=question,
            base_concepts=base_concepts,
            examples=examples,
            industrial_docs=industrial_docs,
        )

        # 调用 LLM
        answer = self.llm(prompt)
        return answer.strip()
