#!/usr/bin/env bash
# =============================================================================
# run_naive_rag_ingest.sh
# 索引 ORD-QA 文档库 → 生成 NavieRAG FAISS 向量索引
# 请从项目根目录（EDAAgentMemory/）执行本脚本
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAIVE_RAG_DIR="${ROOT_DIR}/baselines/naive_rag"
EVAL_CONFIG="${SCRIPT_DIR}/configs/naive_rag_config.yaml"
TARGET_CONFIG="${NAIVE_RAG_DIR}/eda_eval/config_ordqa.yaml"
DOC_JSON="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/openroad_documentation.json"
INDEX_DIR="${NAIVE_RAG_DIR}/eda_eval/index"

echo "======================================================"
echo "  NavieRAG × ORD-QA 文档索引"
echo "======================================================"
echo "  配置来源  : ${EVAL_CONFIG}"
echo "  文档路径  : ${DOC_JSON}"
echo "  索引输出  : ${INDEX_DIR}"
echo ""

# 1. 将 eval/configs 中的配置覆盖到子仓库
echo "[步骤 1/2] 同步配置文件 → ${TARGET_CONFIG}"
cp -f "${EVAL_CONFIG}" "${TARGET_CONFIG}"

# 2. 执行索引
echo "[步骤 2/2] 开始建立 FAISS 索引..."
cd "${NAIVE_RAG_DIR}"
uv run python eda_eval/ingest_ordqa.py \
    --doc_json  "${DOC_JSON}" \
    --index_dir "${INDEX_DIR}" \
    --config    "${TARGET_CONFIG}"

echo ""
echo "✅ 索引完成！"
