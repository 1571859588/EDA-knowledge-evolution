# eval/ — 统一实验入口

本目录是 **EDA-knowledge-evolution** 项目的统一评测中心。  
所有参数调整在此处完成，**无需直接改动子仓库代码**。

---

## 目录结构

```
eval/
├── configs/
│   ├── naive_rag_config.yaml       ← NavieRAG 配置（唯一修改入口）
│   └── graphrag_config.yml         ← GraphRAG 配置（唯一修改入口）
├── run_naive_rag_ingest.sh/.ps1    ← 索引 ORD-QA 文档（NavieRAG）
├── run_naive_rag_eval.sh/.ps1      ← 运行 NavieRAG × ORD-QA 评估
├── run_graphrag_ingest.sh/.ps1     ← 索引 ORD-QA 文档（GraphRAG）
├── run_graphrag_local_eval.sh/.ps1 ← 运行 GraphRAG Local × ORD-QA 评估
├── run_graphrag_global_eval.sh/.ps1← 运行 GraphRAG Global × ORD-QA 评估
├── run_all_eval.sh/.ps1            ← 串行跑所有 baseline 评估，汇总对比
└── README.md                       ← 本文件
```

---

## 快速上手

### 1. 设置环境变量 / API Key

```bash
# Linux / Git Bash
export OPENAI_API_KEY="sk-xxxxx"
export OPENAI_API_BASE="https://api.openai.com/v1"   # 或其他兼容端点
export GRAPHRAG_API_KEY="sk-xxxxx"
export GRAPHRAG_API_BASE="https://api.openai.com/v1"
```

```powershell
# Windows PowerShell
$env:OPENAI_API_KEY   = "sk-xxxxx"
$env:OPENAI_API_BASE  = "https://api.openai.com/v1"
$env:GRAPHRAG_API_KEY = "sk-xxxxx"
$env:GRAPHRAG_API_BASE = "https://api.openai.com/v1"
```

### 2. 修改配置（仅在此处改，无需动子仓库）

- 调整模型、Chunk 大小、Top-K 等参数 → 编辑 `eval/configs/naive_rag_config.yaml`
- 调整 GraphRAG 实体类型、社区大小、查询参数 → 编辑 `eval/configs/graphrag_config.yml`

### 3. 索引文档（首次或文档更新后）

```bash
# Linux / Git Bash
bash eval/run_naive_rag_ingest.sh
bash eval/run_graphrag_ingest.sh

# Windows PowerShell
.\eval\run_naive_rag_ingest.ps1
.\eval\run_graphrag_ingest.ps1
```

### 4. 运行评估

```bash
# 单独运行
bash eval/run_naive_rag_eval.sh
bash eval/run_graphrag_local_eval.sh
bash eval/run_graphrag_global_eval.sh

# 一键跑全部 baseline
bash eval/run_all_eval.sh
```

```powershell
# Windows PowerShell 单独运行
.\eval\run_naive_rag_eval.ps1
.\eval\run_graphrag_local_eval.ps1

# 一键跑全部
.\eval\run_all_eval.ps1
```

### 5. 查看结果

评估完成后，结果文件默认输出到：

| Baseline | 结果文件 |
|---|---|
| NavieRAG | `eval/results/naive_rag_results.json` |
| GraphRAG Local | `eval/results/graphrag_local_results.json` |
| GraphRAG Global | `eval/results/graphrag_global_results.json` |

---

## 原理说明

每个 `.sh` / `.ps1` 脚本的工作流程：

1. **`cp`** — 将 `eval/configs/` 下对应的配置文件复制覆盖到子仓库的 `eda_eval/` 目录
2. **`cd`** — 切换到对应子仓库目录（部分脚本需要在子仓库根目录运行以保证相对路径正确）
3. **`uv run python`** — 执行索引或评估脚本

> ⚠️ 每次运行脚本时，`eval/configs/` 中的配置会**覆盖**子仓库中的配置文件。因此，请始终在 `eval/configs/` 中进行修改，不要直接修改子仓库中的配置文件。
