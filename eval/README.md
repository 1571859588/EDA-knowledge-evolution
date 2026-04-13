# eval/ — 统一实验入口

所有参数调整在此处完成，**无需直接改动子仓库代码**。

## 目录结构

```
eval/
├── naive_rag/
│   ├── config.yaml             ← NavieRAG 配置（唯一修改入口）
│   ├── run_ingest.sh/.ps1      ← 索引 ORD-QA 文档
│   ├── run_eval.sh/.ps1        ← 运行评估
│   └── results.json            ← 评估结果（运行后生成，不入库）
├── graphrag/
│   ├── config.yml              ← GraphRAG 配置（唯一修改入口）
│   ├── run_ingest.sh/.ps1      ← 索引 ORD-QA 文档（触发 graphrag index）
│   ├── run_local_eval.sh/.ps1  ← GraphRAG Local 评估
│   ├── run_global_eval.sh/.ps1 ← GraphRAG Global 评估
│   ├── results_local.json      ← 评估结果（运行后生成，不入库）
│   └── results_global.json
├── run_all_eval.sh/.ps1        ← 一键串行跑所有 baseline + 打印对比表
└── README.md
```

## 工作流

### 1. 修改参数（只在此处改）

| 要调整的内容 | 编辑文件 |
|---|---|
| NavieRAG 模型、Embedding、Chunk、Top-K | `eval/naive_rag/config.yaml` |
| GraphRAG 实体类型、社区参数、查询 LLM | `eval/graphrag/config.yml` |

### 2. 建立索引（首次或文档更新后执行一次）

```bash
# Linux / Git Bash（从项目根目录）
bash eval/naive_rag/run_ingest.sh
bash eval/graphrag/run_ingest.sh
```

```powershell
# Windows PowerShell（从项目根目录）
.\eval\naive_rag\run_ingest.ps1
.\eval\graphrag\run_ingest.ps1
```

### 3. 运行评估

```bash
# 单独运行
bash eval/naive_rag/run_eval.sh
bash eval/graphrag/run_local_eval.sh
bash eval/graphrag/run_global_eval.sh

# 一键跑全部 + 打印对比表格
bash eval/run_all_eval.sh
```

```powershell
.\eval\naive_rag\run_eval.ps1
.\eval\graphrag\run_local_eval.ps1
.\eval\graphrag\run_global_eval.ps1

.\eval\run_all_eval.ps1
```

### 4. 可选环境变量（覆盖默认参数）

| 变量 | 作用 |
|---|---|
| `TOP_K` | 覆盖 NavieRAG 的 top_k 检索数量 |
| `QUESTION_TYPES` | 只评估指定类型（如 `functionality,vlsi_flow`） |
| `MAX_SAMPLES` | 限制样本数（调试用，如 `10`） |
| `OPENAI_API_KEY` | OpenAI 兼容 API 密钥 |
| `GRAPHRAG_API_KEY` | GraphRAG API 密钥 |

## 原理

每个脚本运行时：
1. `cp` 本目录的 config 文件 **覆盖** 子仓库的 `eda_eval/config_ordqa*`
2. `cd` 到子仓库目录后执行 `uv run python eda_eval/xxx.py`
3. 结果 JSON 写回本目录（`results*.json`）
