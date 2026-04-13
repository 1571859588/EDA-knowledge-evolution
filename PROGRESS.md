# 全局科研项目进度池 (PROGRESS.md)

本项目主要记录多Agent跨领域知识自进化的研究进展、文件结构说明以及每次版本的演进历史。

## 1. 核心选型说明
- **Baseline选型**: 确定使用最主流的传统 **Naive RAG** 和 **GraphRAG** 作为对比基线。为避免重复造轮子，直接通过 Git Submodule 引入相关的开源实现库（目前已引入 GraphRAG 和基于 Hugging Face Transformers 的官方 Naive RAG 作为子模块）。用以凸显我们的多Agent在认知进化上的优势。
- **核心架构思路**: 选择**Memory-Augmented Multi-Agent**作为主要创新。通过设计Reader Agent、Practitioner Agent、Solver Agent角色分离的方式，配合工作记忆(Working)、语义记忆(Semantic)与情景记忆(Episodic)，完成从概念摄入到排坑实战的学习流。
- **Benchmark选择**: 选择 **ORD-QA** (OpenROAD QA) 作为首选评测基准。ORD-QA专注于开源EDA工具流的使用问答，极其契合“查阅文档 -> 运行基础流 -> 回答复杂应用任务”的情景设定。

## 2. 目录结构说明
- `baselines/` : 存放所有对比基线的Git子仓库（Submodules）。
  - `graphrag/` : 引入的GraphRAG公共实现仓库。
  - `naive_rag/` : 自建的 NavieRAG 库，包含完整复现流。
- `eval/` : **统一评测中心**，所有参数调整均在此完成，无需修改子仓库。
  - `configs/` : 各 Baseline 的配置文件（唯一修改入口）。
  - `run_*.sh` / `run_*.ps1` : 自动同步配置并执行对应子仓库的评估脚本。
  - `run_all_eval.*` : 一键托跟所有 Baseline 并打印对比表格。
- `benchmarks/` : 存放各类评测集及对应的基准测评数据集。
  - `ORD-QA/` : OpenROAD QA官方开源库，作为核心EDA评测集资源。
- `survey/` : 存放早期的学术调研文档和架构设计思路。
  - `eda_agent_memory_survey.md`: 课题背景、相关论文、架构Baseline和Benchmark选型的初步调研报告。
- `README.md` : 项目入口和简介。
- `PROGRESS.md` : 维护全局的项目进度与推送汇总（当前文件）。

## 3. 进度与版本控制节点 (Git Push History)

| 日期 | 分支 | 节点 (Commit / Push) | 变更摘要与进度总结 |
| :--- | :--- | :--- | :--- |
| 2026-04-13 | main | `first commit` | 项目初始化。完成课题初期调研（`survey/`），确立初步架构与基线选型（ORD-QA）。接入Git版本控制。 |
| 2026-04-13 | main | `add graphrag submodule` | 引入 GraphRAG 开源仓库作为子模块基线，调整基线选取策略为利用现有成熟库以降低造轮子成本。 |
| 2026-04-13 | main | `add ord-qa dataset` | 在 benchmarks/ 目录下引入了 ORD-QA (RAG-EDA) 官方开源仓库作为子模块。 |
| 2026-04-13 | main | `add naive rag submodule` | 删除过大的 Transformers 子模块，自建精简版 NavieRAG 并推送到 NavieRAG.git，再以新子模块形式挂载入主仓。 |
| 2026-04-13 | graphrag/EDAAgentMemory | `feat: add ORD-QA evaluation suite` | 在 `baselines/graphrag/eda_eval/` 下新增 GraphRAG × ORD-QA 完整评估套件：索引脚本、EDA 配置、评估脚本（BLEU/ROUGE-L/BERTScore/Recall@K）及中文 USAGE.md。 |
| 2026-04-13 | naive_rag/EDAAgentMemory | `feat: add ORD-QA evaluation suite` | 在 `baselines/naive_rag/eda_eval/` 下对称新增 NavieRAG × ORD-QA 完整评估套件：`ingest_ordqa.py`（读取 openroad_documentation.json 建 FAISS 索引）、`config_ordqa.yaml`、`evaluate_ordqa.py`（含按问题类型细分统计）及中文 USAGE.md。 |
| 2026-04-13 | main | `feat: add eval/ unified runner` | 新增 `eval/` 统一评测中心：配置文件集中于 `eval/configs/`，提供 `.sh`（Git Bash/Linux）和 `.ps1`（Windows PowerShell）双版本运行脚本，自动同步配置并调用各 Baseline 的鼨建/评估脚本，`run_all_eval` 一键串行跑完并打印指标对比表格。 |

---
*注：请在每次阶段性突破或向远端推送（Push）前，更新此文档以追踪科研历程。*
