#!/usr/bin/env bash
# =============================================================================
# eval/naive_rag/run_ingest.sh — NavieRAG 文档索引
# 请从项目根目录执行：bash eval/naive_rag/run_ingest.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAIVE_RAG_DIR="${ROOT_DIR}/baselines/naive_rag"
SRC_CONFIG="${SCRIPT_DIR}/config.yaml"
DST_CONFIG="${NAIVE_RAG_DIR}/eda_eval/config_ordqa.yaml"
DOC_JSON="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/openroad_documentation.json"
INDEX_DIR="${NAIVE_RAG_DIR}/eda_eval/index"

echo "======================================================"
echo "  NavieRAG × ORD-QA 文档索引"
echo "======================================================"
echo "  [1/2] 同步配置: ${SRC_CONFIG} → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 建立 FAISS 索引..."
cd "${NAIVE_RAG_DIR}"
uv run python eda_eval/ingest_ordqa.py \
    --doc_json  "${DOC_JSON}" \
    --index_dir "${INDEX_DIR}" \
    --config    "${DST_CONFIG}"

echo "✅ 索引完成！"
