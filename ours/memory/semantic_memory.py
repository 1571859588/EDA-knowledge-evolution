"""
semantic_memory.py — 底层语义记忆（Semantic Memory）

基于 NetworkX 的 EDA 知识图谱。存储从 OpenROAD 文档中抽取的：
  - 实体节点（命令、概念、阶段、参数等）及其定义/描述
  - 关系边（BELONGS_TO, USED_IN, HAS_PARAMETER, DEPENDS_ON 等）
  - 关联的例题与解答片段

这是"冷数据"层——构建后只读，为 Pipeline 阶段 1 提供语义锚定。
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import networkx as nx


class SemanticMemory:
    """NetworkX 知识图谱封装，支持构建、查询、序列化。"""

    def __init__(self) -> None:
        self.graph = nx.DiGraph()

    # ── 节点 / 边操作 ─────────────────────────────────────────────────────────

    def add_entity(
        self,
        entity_id: str,
        entity_type: str,
        definition: str = "",
        examples: list[str] | None = None,
        source_chunk_id: str = "",
        **extra: Any,
    ) -> None:
        """添加一个实体节点。"""
        self.graph.add_node(
            entity_id,
            entity_type=entity_type,
            definition=definition,
            examples=examples or [],
            source_chunk_id=source_chunk_id,
            **extra,
        )

    def add_relation(
        self,
        src: str,
        dst: str,
        relation_type: str,
        **extra: Any,
    ) -> None:
        """添加一条有向关系边。"""
        # 确保端点存在（允许先建边后补属性）
        if src not in self.graph:
            self.graph.add_node(src, entity_type="unknown", definition="")
        if dst not in self.graph:
            self.graph.add_node(dst, entity_type="unknown", definition="")
        self.graph.add_edge(src, dst, relation_type=relation_type, **extra)

    # ── 图检索 ────────────────────────────────────────────────────────────────

    def query_by_entities(
        self,
        entities: list[str],
        max_hops: int = 2,
    ) -> dict[str, Any]:
        """给定一组实体名，返回 k-hop 子图内的概念定义、例题、关系。

        返回格式:
        {
            "concepts": [{"id": ..., "type": ..., "definition": ..., "examples": [...]}],
            "relations": [{"src": ..., "dst": ..., "type": ...}],
        }
        """
        # 模糊匹配：将查询实体映射到图内已有节点
        matched_nodes: set[str] = set()
        all_nodes = set(self.graph.nodes)
        for ent in entities:
            ent_lower = ent.lower().strip().replace(" ", "_")
            for node in all_nodes:
                node_lower = node.lower().strip().replace(" ", "_")
                if ent_lower == node_lower or ent_lower in node_lower or node_lower in ent_lower:
                    matched_nodes.add(node)

        # BFS 展开 k-hop 邻居
        expanded: set[str] = set(matched_nodes)
        frontier = set(matched_nodes)
        for _ in range(max_hops):
            next_frontier: set[str] = set()
            for node in frontier:
                # 出边邻居
                next_frontier.update(self.graph.successors(node))
                # 入边邻居
                next_frontier.update(self.graph.predecessors(node))
            next_frontier -= expanded
            expanded.update(next_frontier)
            frontier = next_frontier

        # 收集结果
        concepts = []
        for node in expanded:
            data = self.graph.nodes[node]
            concepts.append({
                "id": node,
                "type": data.get("entity_type", "unknown"),
                "definition": data.get("definition", ""),
                "examples": data.get("examples", []),
            })

        relations = []
        for u, v, data in self.graph.edges(data=True):
            if u in expanded and v in expanded:
                relations.append({
                    "src": u,
                    "dst": v,
                    "type": data.get("relation_type", "RELATED_TO"),
                })

        return {"concepts": concepts, "relations": relations}

    def format_as_context(self, query_result: dict[str, Any]) -> str:
        """将 query_by_entities 的结果格式化为可读的上下文文本。"""
        lines: list[str] = []

        # 按类型分组概念
        by_type: dict[str, list[dict]] = {}
        for c in query_result["concepts"]:
            by_type.setdefault(c["type"], []).append(c)

        for etype, items in by_type.items():
            lines.append(f"### {etype}")
            for item in items:
                lines.append(f"- **{item['id']}**: {item['definition']}")
                if item["examples"]:
                    for ex in item["examples"]:
                        lines.append(f"  例题/示例: {ex}")
            lines.append("")

        if query_result["relations"]:
            lines.append("### 概念关系")
            for rel in query_result["relations"]:
                lines.append(f"- {rel['src']} —[{rel['type']}]→ {rel['dst']}")

        return "\n".join(lines) if lines else "（未找到相关基础概念）"

    # ── 统计 ──────────────────────────────────────────────────────────────────

    @property
    def num_entities(self) -> int:
        return self.graph.number_of_nodes()

    @property
    def num_relations(self) -> int:
        return self.graph.number_of_edges()

    def summary(self) -> str:
        type_counts: dict[str, int] = {}
        for _, data in self.graph.nodes(data=True):
            t = data.get("entity_type", "unknown")
            type_counts[t] = type_counts.get(t, 0) + 1
        parts = [f"{t}: {c}" for t, c in sorted(type_counts.items())]
        return (
            f"SemanticMemory: {self.num_entities} entities, "
            f"{self.num_relations} relations | {', '.join(parts)}"
        )

    # ── 序列化 ────────────────────────────────────────────────────────────────

    def save(self, path: str) -> None:
        """保存知识图谱为 JSON 文件。"""
        filepath = Path(path)
        filepath.parent.mkdir(parents=True, exist_ok=True)

        data = {
            "nodes": [],
            "edges": [],
        }
        for node, attrs in self.graph.nodes(data=True):
            data["nodes"].append({"id": node, **attrs})
        for u, v, attrs in self.graph.edges(data=True):
            data["edges"].append({"src": u, "dst": v, **attrs})

        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    @classmethod
    def load(cls, path: str) -> "SemanticMemory":
        """从 JSON 文件加载知识图谱。"""
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        mem = cls()
        for node_data in data.get("nodes", []):
            node_id = node_data.pop("id")
            mem.graph.add_node(node_id, **node_data)
        for edge_data in data.get("edges", []):
            src = edge_data.pop("src")
            dst = edge_data.pop("dst")
            mem.graph.add_edge(src, dst, **edge_data)
        return mem


# ── KG 构建辅助（被 build_knowledge.py 调用） ─────────────────────────────────

KG_EXTRACTION_PROMPT = """你是一个 EDA 知识图谱构建专家。请从下面这段 OpenROAD 文档中抽取结构化知识。

要求输出严格的 JSON 格式：
{{
  "entities": [
    {{"id": "实体名(英文, 下划线连接)", "type": "实体类型", "definition": "一句话定义"}}
  ],
  "relations": [
    {{"src": "源实体id", "dst": "目标实体id", "type": "关系类型"}}
  ],
  "examples": [
    {{"concept": "关联的实体id", "content": "示例/例题内容"}}
  ]
}}

实体类型可选：EDA_tool, EDA_command, EDA_stage, EDA_parameter, EDA_concept, EDA_file_format, Tcl_command
关系类型可选：BELONGS_TO, USED_IN, HAS_PARAMETER, DEPENDS_ON, EXAMPLE_OF, PREREQUISITE_OF, PRODUCES

文档片段（chunk_id = {chunk_id}）：
{text}

只输出 JSON，不要有其他文字。"""


def build_kg_from_llm_response(
    memory: SemanticMemory,
    llm_response: str,
    chunk_id: str,
) -> None:
    """解析 LLM 返回的 JSON 并写入知识图谱。"""
    # 提取 JSON 块（兼容 markdown code fence）
    json_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", llm_response, re.DOTALL)
    if json_match:
        raw_json = json_match.group(1)
    else:
        raw_json = llm_response.strip()

    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        # 尝试修复常见问题
        try:
            # 有时 LLM 会输出单引号
            fixed = raw_json.replace("'", '"')
            data = json.loads(fixed)
        except json.JSONDecodeError:
            print(f"  [KG] ⚠️ chunk {chunk_id} 的 LLM 输出无法解析为 JSON，跳过。")
            return

    # 写入实体
    for ent in data.get("entities", []):
        memory.add_entity(
            entity_id=ent.get("id", ""),
            entity_type=ent.get("type", "unknown"),
            definition=ent.get("definition", ""),
            source_chunk_id=chunk_id,
        )

    # 写入关系
    for rel in data.get("relations", []):
        memory.add_relation(
            src=rel.get("src", ""),
            dst=rel.get("dst", ""),
            relation_type=rel.get("type", "RELATED_TO"),
        )

    # 写入例题（挂到对应实体节点上）
    for ex in data.get("examples", []):
        concept_id = ex.get("concept", "")
        content = ex.get("content", "")
        if concept_id in memory.graph and content:
            existing = memory.graph.nodes[concept_id].get("examples", [])
            existing.append(content)
            memory.graph.nodes[concept_id]["examples"] = existing
