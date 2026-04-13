# 全局科研项目进度池 (PROGRESS.md)

本项目主要记录多Agent跨领域知识自进化的研究进展、文件结构说明以及每次版本的演进历史。

## 1. 核心选型说明
- **Baseline架构思路**: 选择**Memory-Augmented Multi-Agent**作为初始基线。通过设计Reader Agent、Practitioner Agent、Solver Agent角色分离的方式，配合工作记忆(Working)、语义记忆(Semantic)与情景记忆(Episodic)，完成从概念摄入到排坑实战的学习流。
- **Benchmark选择**: 选择 **ORD-QA** (OpenROAD QA) 作为首选评测基准。ORD-QA专注于开源EDA工具流的使用问答，极其契合“查阅文档 -> 运行基础流 -> 回答复杂应用任务”的情景设定。

## 2. 目录结构说明
- `survey/` : 存放早期的学术调研文档和架构设计思路。
  - `eda_agent_memory_survey.md`: 课题背景、相关论文、架构Baseline和Benchmark选型的初步调研报告。
- `README.md` : 项目入口和简介。
- `PROGRESS.md` : 维护全局的项目进度与推送汇总（当前文件）。

## 3. 进度与版本控制节点 (Git Push History)

| 日期 | 分支 | 节点 (Commit / Push) | 变更摘要与进度总结 |
| :--- | :--- | :--- | :--- |
| 2026-04-13 | main | `first commit` | 项目初始化。完成课题初期调研（`survey/`），确立初步架构与基线选型（ORD-QA）。接入Git版本控制。 |

---
*注：请在每次阶段性突破或向远端推送（Push）前，更新此文档以追踪科研历程。*
