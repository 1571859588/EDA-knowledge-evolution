#!/usr/bin/env bash
# eval/graphrag/run_local_eval.sh — GraphRAG Local × ORD-QA 评估
# 请从项目根目录执行：bash eval/graphrag/run_local_eval.sh
# 可选环境变量：QUESTION_TYPES, MAX_SAMPLES
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GRAPHRAG_DIR="${ROOT_DIR}/baselines/graphrag"
SRC_CONFIG="${SCRIPT_DIR}/config.yml"
DST_CONFIG="${GRAPHRAG_DIR}/eda_eval/config_ordqa.yml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
WORKSPACE="${GRAPHRAG_DIR}/eda_eval/workspace"
OUTPUT="${SCRIPT_DIR}/results_local.json"
QUESTION_TYPES="${QUESTION_TYPES:-}"
MAX_SAMPLES="${MAX_SAMPLES:--1}"

echo "======================================================"
echo "  GraphRAG Local × ORD-QA 评估"
echo "  结果 → ${OUTPUT}"
echo "======================================================"
echo "  [1/2] 同步配置 → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 开始评估（local）..."
cd "${GRAPHRAG_DIR}"
EXTRA="--query_type local --max_samples ${MAX_SAMPLES}"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA="${EXTRA} --question_types ${QUESTION_TYPES}"
uv run python eda_eval/evaluate_ordqa.py \
    --benchmark "${BENCHMARK}" --workspace "${WORKSPACE}" \
    --config    "${DST_CONFIG}" --output "${OUTPUT}" \
    ${EXTRA}
echo "✅ GraphRAG Local 评估完成！"
