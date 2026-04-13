#!/usr/bin/env bash
# eval/graphrag/run_global_eval.sh — GraphRAG Global × ORD-QA 评估
# 请从项目根目录执行：bash eval/graphrag/run_global_eval.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GRAPHRAG_DIR="${ROOT_DIR}/baselines/graphrag"
SRC_CONFIG="${SCRIPT_DIR}/config.yml"
DST_CONFIG="${GRAPHRAG_DIR}/eda_eval/config_ordqa.yml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
WORKSPACE="${GRAPHRAG_DIR}/eda_eval/workspace"
OUTPUT="${SCRIPT_DIR}/results_global.json"
QUESTION_TYPES="${QUESTION_TYPES:-}"
MAX_SAMPLES="${MAX_SAMPLES:--1}"

echo "======================================================"
echo "  GraphRAG Global × ORD-QA 评估"
echo "  结果 → ${OUTPUT}"
echo "======================================================"
echo "  [1/2] 同步配置 → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 开始评估（global）..."
cd "${GRAPHRAG_DIR}"
EXTRA="--query_type global --max_samples ${MAX_SAMPLES}"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA="${EXTRA} --question_types ${QUESTION_TYPES}"
uv run python eda_eval/evaluate_ordqa.py \
    --benchmark "${BENCHMARK}" --workspace "${WORKSPACE}" \
    --config    "${DST_CONFIG}" --output "${OUTPUT}" \
    ${EXTRA}
echo "✅ GraphRAG Global 评估完成！"
