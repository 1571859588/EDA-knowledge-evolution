#!/usr/bin/env bash
# =============================================================================
# run_graphrag_global_eval.sh
# 运行 GraphRAG Global Search × ORD-QA 评估
# Global Search = 基于社区摘要的宏观检索，适合开放性跨主题问题
# 请从项目根目录（EDAAgentMemory/）执行本脚本
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GRAPHRAG_DIR="${ROOT_DIR}/baselines/graphrag"
EVAL_CONFIG="${SCRIPT_DIR}/configs/graphrag_config.yml"
TARGET_CONFIG="${GRAPHRAG_DIR}/eda_eval/config_ordqa.yml"
BENCHMARK="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/ORD-QA.jsonl"
WORKSPACE="${GRAPHRAG_DIR}/eda_eval/workspace"
OUTPUT="${ROOT_DIR}/eval/results/graphrag_global_results.json"

QUESTION_TYPES="${QUESTION_TYPES:-}"
MAX_SAMPLES="${MAX_SAMPLES:--1}"

echo "======================================================"
echo "  GraphRAG Global × ORD-QA 评估"
echo "======================================================"
echo "  配置来源  : ${EVAL_CONFIG}"
echo "  基准数据  : ${BENCHMARK}"
echo "  工作空间  : ${WORKSPACE}"
echo "  结果输出  : ${OUTPUT}"
[[ -n "${QUESTION_TYPES}" ]] && echo "  只评估类型: ${QUESTION_TYPES}"
[[ "${MAX_SAMPLES}" != "-1" ]] && echo "  最大样本  : ${MAX_SAMPLES}"
echo ""

echo "[步骤 1/2] 同步配置文件 → ${TARGET_CONFIG}"
cp -f "${EVAL_CONFIG}" "${TARGET_CONFIG}"

echo "[步骤 2/2] 开始评估（Global Search）..."
cd "${GRAPHRAG_DIR}"

EXTRA_ARGS="--query_type global"
[[ -n "${QUESTION_TYPES}" ]] && EXTRA_ARGS="${EXTRA_ARGS} --question_types ${QUESTION_TYPES}"
EXTRA_ARGS="${EXTRA_ARGS} --max_samples ${MAX_SAMPLES}"

uv run python eda_eval/evaluate_ordqa.py \
    --benchmark  "${BENCHMARK}" \
    --workspace  "${WORKSPACE}" \
    --config     "${TARGET_CONFIG}" \
    --output     "${OUTPUT}" \
    ${EXTRA_ARGS}

echo ""
echo "✅ GraphRAG Global 评估完成！结果: ${OUTPUT}"
