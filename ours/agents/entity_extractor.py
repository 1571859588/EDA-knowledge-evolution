"""
entity_extractor.py — 阶段 1：实体抽取与语义锚定

Pipeline 第一步：
  1. 使用 LLM 从用户问题中提取 EDA 核心实体
  2. 在底层语义记忆（知识图谱）中执行 k-hop 图检索
  3. 返回基础概念上下文 C_base
"""

from __future__ import annotations

import json
import re
from typing import Any

from ours.memory.semantic_memory import SemanticMemory


class EntityExtractor:
    """EDA 实体抽取 + KG 锚定。"""

    def __init__(
        self,
        llm_caller,       # callable(prompt) -> str
        config: dict[str, Any],
    ) -> None:
        self.llm = llm_caller
        self.prompt_template: str = config.get(
            "entity_extraction_prompt",
            '从下面问题中提取 EDA 实体：\n{question}\n输出 JSON：{{"entities": [...]}}',
        )
        self.max_hops: int = config.get("semantic_memory", {}).get("max_hops", 2)

    def extract_entities(self, question: str) -> list[str]:
        """调用 LLM 从问题中提取 EDA 实体列表。"""
        prompt = self.prompt_template.format(question=question)
        response = self.llm(prompt)

        # 解析 JSON
        entities = self._parse_entity_response(response)
        return entities

    def anchor_to_knowledge(
        self,
        entities: list[str],
        semantic_memory: SemanticMemory,
    ) -> dict[str, Any]:
        """在 KG 中锚定实体，返回子图检索结果。"""
        if not entities:
            return {"concepts": [], "relations": []}
        return semantic_memory.query_by_entities(entities, max_hops=self.max_hops)

    def run(
        self,
        question: str,
        semantic_memory: SemanticMemory,
    ) -> tuple[list[str], dict[str, Any], str]:
        """完整执行阶段 1。

        Returns
        -------
        (entities, kg_result, formatted_context)
        """
        entities = self.extract_entities(question)
        kg_result = self.anchor_to_knowledge(entities, semantic_memory)
        formatted = semantic_memory.format_as_context(kg_result)
        return entities, kg_result, formatted

    @staticmethod
    def _parse_entity_response(response: str) -> list[str]:
        """从 LLM 响应中提取实体列表。"""
        # 尝试直接解析 JSON
        json_match = re.search(r"\{.*?\}", response, re.DOTALL)
        if json_match:
            try:
                data = json.loads(json_match.group())
                return data.get("entities", [])
            except json.JSONDecodeError:
                pass

        # 降级：按行提取
        entities = []
        for line in response.splitlines():
            line = line.strip().strip("-•*").strip()
            if line and len(line) < 100:
                entities.append(line)
        return entities
