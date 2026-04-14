# TPMA (Tri-Polar Memory Architecture) 使用指南

## 架构概述

三极记忆层级 + 四阶段推理 Pipeline：

```
用户问题 Q
    ↓
阶段 1: 实体抽取 → KG 图检索 → 基础概念 C_base
    ↓
阶段 2: Q + C_base → LLM 查询重构 → 扩展查询 Q_dense
    ↓
阶段 3: Q_dense → Dense(FAISS) + Sparse(BM25) → RRF 融合 → D_recall(20条)
    ↓
阶段 4: (Q + C_base, D_recall) → Cross-Encoder 精筛 → D_final(3~5条)
    ↓
Solver: [人设 + 概念 + 例题 + 工业文档 + 问题] → LLM → 回答
```

### 三极记忆

| 层级 | 名称 | 存储形式 | 数据温度 | 作用 |
|---|---|---|---|---|
| 底层 | 语义记忆 | NetworkX KG | 冷数据（只读） | 概念定义、关系、例题 |
| 中层 | 情景记忆 | FAISS + BM25 | 温数据（可增量） | 工业文档向量索引 |
| 表层 | 工作记忆 | LLM Prompt | 热数据（每次重建） | 结构化组装最终上下文 |

---

## 快速开始

### 1. 安装依赖

```bash
cd <项目根目录>
uv pip install -r ours/requirements.txt
```

### 2. 配置 API Key

```bash
export OPENAI_API_KEY="sk-xxx"
export OPENAI_API_BASE="https://api.openai.com/v1"
```

或修改 `ours/config.yaml` 中的 `llm.api_key` 和 `llm.api_base`。

### 3. 构建知识库

```bash
# 一次性构建底层 KG + 中层向量索引
uv run python ours/build_knowledge.py \
    --doc_json benchmarks/ORD-QA/benchmark/openroad_documentation.json

# 仅构建向量索引（跳过 KG，节省 API 调用）
uv run python ours/build_knowledge.py --skip_kg

# 仅构建 KG（跳过向量索引）
uv run python ours/build_knowledge.py --skip_vector
```

> ⚠️ **KG 构建会大量调用 LLM API**（每个文档 chunk 一次），请确认余额充足。
> OpenROAD 文档约 200+ chunk，使用 gpt-4o-mini 约消耗 $1-3。

构建完成后，知识库存储在：
- `ours/knowledge_store/semantic_kg.json` — 底层 KG
- `ours/knowledge_store/episodic_index/` — 中层向量索引

### 4. 运行评估

```bash
uv run python ours/evaluate_ordqa.py \
    --benchmark benchmarks/ORD-QA/benchmark/ORD-QA.jsonl \
    --config    ours/config.yaml \
    --output    ours/results_tpma.json
```

**可选参数：**

| 参数 | 说明 |
|---|---|
| `--question_types` | 只评估指定类型（如 `functionality,vlsi_flow`） |
| `--max_samples 10` | 调试时限制样本数 |

### 5. 查看结果

结果 JSON 中包含：
- `aggregate`：总体 BLEU/ROUGE-L/BERTScore/Recall@K
- `by_type`：按问题类型细分
- `avg_stage_times`：各阶段平均耗时
- `details`：每条样本的完整中间结果（实体、扩展查询、检索文档等）

---

## 关键参数调指南

| 场景 | 调整 |
|---|---|
| 提高 Recall@K | 增大 `retrieval.dense_top_k` / `sparse_top_k` |
| 提高精度 | 降低 `reranker.score_threshold`，减小 `reranker.top_k` |
| 控制成本 | 把 `llm.model` 换为 `gpt-4o-mini`，`kg_builder_llm` 也改为更便宜的模型 |
| 提升质量 | 把 `llm.model` 换为 `gpt-4o`，增大 `semantic_memory.max_hops` |
| 加速推理 | 设 `embedding.device: cuda`，`reranker.device: cuda` |

---

## 与 Baseline 对比

TPMA 的评估指标与 NavieRAG / GraphRAG 完全相同，结果可直接横向比较：

```bash
# 跑完 TPMA 后，与 baseline 结果放在一起比较
# TPMA 结果: ours/results_tpma.json
# NavieRAG:  eval/naive_rag/results.json
# GraphRAG:  eval/graphrag/results_local.json
```
