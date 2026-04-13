#!/usr/bin/env bash
# =============================================================================
# eval/naive_rag/run_eval.sh — NavieRAG × ORD-QA 评估
# 请从项目根目录执行：bash eval/naive_rag/run_eval.sh
# 可选环境变量：TOP_K, QUESTION_TYPES, MAX_SAMPLES
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAIVE_RAG_DIR="${ROOT_DIR}/baselines/naive_rag"
SRC_CONFIG="${SCRIPT_DIR}/config.yaml"
DST_CONFIG="${NAIVE_RAG_DIR}/eda_eval/config_ordqa.yaml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
INDEX_DIR="${NAIVE_RAG_DIR}/eda_eval/index"
OUTPUT="${ROOT_DIR}/eval/naive_rag/results.json"

TOP_K="${TOP_K:-}"
QUESTION_TYPES="${QUESTION_TYPES:-}"
MAX_SAMPLES="${MAX_SAMPLES:--1}"

echo "======================================================"
echo "  NavieRAG × ORD-QA 评估"
echo "======================================================"
[[ -n "${TOP_K}" ]]          && echo "  top_k: ${TOP_K}"
[[ -n "${QUESTION_TYPES}" ]] && echo "  类型:  ${QUESTION_TYPES}"
echo "  结果 → ${OUTPUT}"

echo "  [1/2] 同步配置: ${SRC_CONFIG} → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 开始评估..."
cd "${NAIVE_RAG_DIR}"

EXTRA=""
[[ -n "${TOP_K}" ]]          && EXTRA="${EXTRA} --top_k ${TOP_K}"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA="${EXTRA} --question_types ${QUESTION_TYPES}"
EXTRA="${EXTRA} --max_samples ${MAX_SAMPLES}"

uv run python eda_eval/evaluate_ordqa.py \
    --benchmark "${BENCHMARK}" \
    --index_dir "${INDEX_DIR}" \
    --config    "${DST_CONFIG}" \
    --output    "${OUTPUT}" \
    ${EXTRA}

echo "✅ 评估完成！结果: ${OUTPUT}"
