#!/usr/bin/env bash
# =============================================================================
# run_naive_rag_eval.sh
# 运行 NavieRAG × ORD-QA 完整评估（需先运行 run_naive_rag_ingest.sh 建立索引）
# 请从项目根目录（EDAAgentMemory/）执行本脚本
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAIVE_RAG_DIR="${ROOT_DIR}/baselines/naive_rag"
EVAL_CONFIG="${SCRIPT_DIR}/configs/naive_rag_config.yaml"
TARGET_CONFIG="${NAIVE_RAG_DIR}/eda_eval/config_ordqa.yaml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
INDEX_DIR="${NAIVE_RAG_DIR}/eda_eval/index"
OUTPUT="${ROOT_DIR}/eval/results/naive_rag_results.json"

# ── 可选参数（命令行覆盖） ─────────────────────────────────────────────────────
TOP_K="${TOP_K:-}"                          # 空 = 读配置文件
QUESTION_TYPES="${QUESTION_TYPES:-}"        # 空 = 全部类型
MAX_SAMPLES="${MAX_SAMPLES:--1}"            # -1 = 全部样本

echo "======================================================"
echo "  NavieRAG × ORD-QA 评估"
echo "======================================================"
echo "  配置来源  : ${EVAL_CONFIG}"
echo "  基准数据  : ${BENCHMARK}"
echo "  索引目录  : ${INDEX_DIR}"
echo "  结果输出  : ${OUTPUT}"
[[ -n "${TOP_K}" ]]          && echo "  top_k     : ${TOP_K}"
[[ -n "${QUESTION_TYPES}" ]] && echo "  只评估类型: ${QUESTION_TYPES}"
[[ "${MAX_SAMPLES}" != "-1" ]] && echo "  最大样本  : ${MAX_SAMPLES}"
echo ""

# 1. 同步配置
echo "[步骤 1/2] 同步配置文件 → ${TARGET_CONFIG}"
cp -f "${EVAL_CONFIG}" "${TARGET_CONFIG}"

# 2. 执行评估
echo "[步骤 2/2] 开始评估..."
cd "${NAIVE_RAG_DIR}"

EXTRA_ARGS=""
[[ -n "${TOP_K}" ]]          && EXTRA_ARGS="${EXTRA_ARGS} --top_k ${TOP_K}"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA_ARGS="${EXTRA_ARGS} --question_types ${QUESTION_TYPES}"
EXTRA_ARGS="${EXTRA_ARGS} --max_samples ${MAX_SAMPLES}"

uv run python eda_eval/evaluate_ordqa.py \
    --benchmark  "${BENCHMARK}" \
    --index_dir  "${INDEX_DIR}" \
    --config     "${TARGET_CONFIG}" \
    --output     "${OUTPUT}" \
    ${EXTRA_ARGS}

echo ""
echo "✅ 评估完成！结果已保存至: ${OUTPUT}"
