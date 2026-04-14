#!/usr/bin/env bash
# eval/tpma/run_eval.sh — TPMA × ORD-QA 评估
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_CONFIG="${SCRIPT_DIR}/config.yaml"
DST_CONFIG="${ROOT_DIR}/ours/config.yaml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
OUTPUT="${SCRIPT_DIR}/results.json"
QUESTION_TYPES="${QUESTION_TYPES:-}"
MAX_SAMPLES="${MAX_SAMPLES:--1}"

echo "======================================================"
echo "  TPMA × ORD-QA 评估"
echo "  结果 → ${OUTPUT}"
echo "======================================================"
echo "  [1/2] 同步配置 → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 开始评估..."
cd "${ROOT_DIR}"
EXTRA="--max_samples ${MAX_SAMPLES}"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA="${EXTRA} --question_types ${QUESTION_TYPES}"
uv run python ours/evaluate_ordqa.py \
    --benchmark "${BENCHMARK}" --config "${DST_CONFIG}" \
    --output "${OUTPUT}" ${EXTRA}
echo "✅ TPMA 评估完成！"
