"""
working_memory.py — 表层工作记忆（Working Memory）

负责按照固定拓扑结构组装 LLM Prompt：
  [系统人设] → [底层概念解析] → [实战例题] → [工业界参考文档] → [用户问题]

工作记忆是"热数据"——仅存在于单次请求的生命周期内，每个问题的 Prompt
都是由 SemanticMemory 和 EpisodicMemory 的检索结果即时组装的。
"""

from __future__ import annotations

from typing import Any


class WorkingMemory:
    """结构化 Prompt 组装器。"""

    def __init__(self, config: dict[str, Any]) -> None:
        wm_cfg = config.get("working_memory", {})
        self.system_persona: str = wm_cfg.get("system_persona", "你是一名 EDA 领域专家。")
        self.template: str = wm_cfg.get(
            "assembly_template",
            (
                "{system_persona}\n\n"
                "## 一、核心概念解析\n{base_concepts}\n\n"
                "## 二、相关实战例题\n{examples}\n\n"
                "## 三、工业界参考文档\n{industrial_docs}\n\n"
                "## 四、用户问题\n{question}\n\n"
                "请根据以上信息，给出完整、准确的回答。"
            ),
        )

    def assemble(
        self,
        question: str,
        base_concepts: str,
        examples: str,
        industrial_docs: str,
    ) -> str:
        """按固定拓扑组装最终 Prompt。

        Parameters
        ----------
        question : str
            用户的原始问题。
        base_concepts : str
            底层语义记忆中检索到的概念定义和关系（来自 KG）。
        examples : str
            与概念关联的例题解答片段。
        industrial_docs : str
            经过精筛的工业文档片段（来自 Cross-Encoder Reranking）。

        Returns
        -------
        str
            组装好的完整 Prompt。
        """
        return self.template.format(
            system_persona=self.system_persona.strip(),
            base_concepts=base_concepts.strip() or "（未检索到底层概念）",
            examples=examples.strip() or "（无关联例题）",
            industrial_docs=industrial_docs.strip() or "（未检索到工业文档）",
            question=question.strip(),
        )

    def format_industrial_docs(
        self,
        ranked_docs: list[tuple[dict, float]],
    ) -> str:
        """将精筛后的文档列表格式化为 Prompt 中的工业文档片段。"""
        if not ranked_docs:
            return "（未检索到工业文档）"

        parts: list[str] = []
        for i, (meta, score) in enumerate(ranked_docs, 1):
            source = meta.get("source", "unknown")
            text = meta.get("text", "")
            parts.append(
                f"### 参考文档 {i} [来源: {source}, 相关度: {score:.3f}]\n{text}"
            )
        return "\n\n".join(parts)

    def format_examples(self, concepts: list[dict]) -> str:
        """从概念列表中提取所有关联的例题。"""
        examples: list[str] = []
        for c in concepts:
            for ex in c.get("examples", []):
                if ex.strip():
                    examples.append(f"- **{c['id']}** 相关示例：{ex}")
        return "\n".join(examples) if examples else "（无关联例题）"
