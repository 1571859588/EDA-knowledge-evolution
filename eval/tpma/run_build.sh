#!/usr/bin/env bash
# eval/tpma/run_build.sh — 构建 TPMA 知识库（KG + 向量索引）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_CONFIG="${SCRIPT_DIR}/config.yaml"
DST_CONFIG="${ROOT_DIR}/ours/config.yaml"
DOC_JSON="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/openroad_documentation.json"

echo "======================================================"
echo "  TPMA 知识库构建"
echo "  ⚠️  KG 构建会大量调用 LLM API"
echo "======================================================"
echo "  [1/2] 同步配置: ${SRC_CONFIG} → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

echo "  [2/2] 构建知识库..."
cd "${ROOT_DIR}"
uv run python ours/build_knowledge.py --doc_json "${DOC_JSON}" --config "${DST_CONFIG}"
echo "✅ 知识库构建完成！"
