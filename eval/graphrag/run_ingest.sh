#!/usr/bin/env bash
# eval/graphrag/run_ingest.sh — GraphRAG 文档索引
# 请从项目根目录执行：bash eval/graphrag/run_ingest.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GRAPHRAG_DIR="${ROOT_DIR}/baselines/graphrag"
SRC_CONFIG="${SCRIPT_DIR}/config.yml"
DST_CONFIG="${GRAPHRAG_DIR}/eda_eval/config_ordqa.yml"
DOC_JSON="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/openroad_documentation.json"
WORKSPACE="${GRAPHRAG_DIR}/eda_eval/workspace"

echo "======================================================"
echo "  GraphRAG × ORD-QA 文档索引"
echo "  ⚠️  将大量调用 LLM API，请确认余额充足！"
echo "======================================================"
echo "  [1/3] 同步配置: ${SRC_CONFIG} → ${DST_CONFIG}"
cp -f "${SRC_CONFIG}" "${DST_CONFIG}"

cd "${GRAPHRAG_DIR}"
if [ ! -f "${WORKSPACE}/settings.yaml" ]; then
    echo "  [2/3] 初始化工作空间..."
    uv run graphrag init --root "${WORKSPACE}"
else
    echo "  [2/3] 工作空间已存在，跳过初始化。"
fi

echo "  [3/3] 开始索引文档..."
uv run python eda_eval/ingest_ordqa.py \
    --doc_json  "${DOC_JSON}" \
    --workspace "${WORKSPACE}"
echo "✅ GraphRAG 索引完成！"
