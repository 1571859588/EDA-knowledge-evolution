#!/usr/bin/env bash
# =============================================================================
# run_graphrag_ingest.sh
# 索引 ORD-QA 文档库 → 生成 GraphRAG 知识图谱索引
# 请从项目根目录（EDAAgentMemory/）执行本脚本
# 注意：索引阶段会大量调用 LLM API，请确认 API 余额充足！
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GRAPHRAG_DIR="${ROOT_DIR}/baselines/graphrag"
EVAL_CONFIG="${SCRIPT_DIR}/configs/graphrag_config.yml"
TARGET_CONFIG="${GRAPHRAG_DIR}/eda_eval/config_ordqa.yml"
DOC_JSON="${ROOT_DIR}/benchmarks/ORD-QA/benchmark/openroad_documentation.json"
WORKSPACE="${GRAPHRAG_DIR}/eda_eval/workspace"

echo "======================================================"
echo "  GraphRAG × ORD-QA 文档索引"
echo "======================================================"
echo "  配置来源  : ${EVAL_CONFIG}"
echo "  文档路径  : ${DOC_JSON}"
echo "  工作空间  : ${WORKSPACE}"
echo ""
echo "  ⚠️  本操作会大量调用 LLM API（实体抽取 + 社区摘要）"
echo "     OpenROAD 文档约需 500~2000 次 API 调用，请确认余额充足"
echo ""

# 1. 同步配置
echo "[步骤 1/3] 同步配置文件 → ${TARGET_CONFIG}"
cp -f "${EVAL_CONFIG}" "${TARGET_CONFIG}"

# 2. 初始化工作空间（如不存在）
if [ ! -f "${WORKSPACE}/settings.yaml" ]; then
    echo "[步骤 2/3] 初始化 GraphRAG 工作空间..."
    cd "${GRAPHRAG_DIR}"
    uv run graphrag init --root "${WORKSPACE}"
else
    echo "[步骤 2/3] 工作空间已存在，跳过初始化。"
fi

# 3. 执行索引
echo "[步骤 3/3] 开始索引（写入文档 + 触发 graphrag index）..."
cd "${GRAPHRAG_DIR}"
uv run python eda_eval/ingest_ordqa.py \
    --doc_json  "${DOC_JSON}" \
    --workspace "${WORKSPACE}"

echo ""
echo "✅ GraphRAG 索引完成！"
