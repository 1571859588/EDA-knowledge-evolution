#!/usr/bin/env bash
# =============================================================================
# run_all_eval.sh
# 串行执行所有 Baseline 的 ORD-QA 评估，最终打印汇总对比表格
# 请从项目根目录（EDAAgentMemory/）执行本脚本
# 依赖：各子仓库的 FAISS 索引 / GraphRAG 知识图谱需已建立
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================"
echo "  EDAAgentMemory — 全量 Baseline 评估"
echo "======================================================"
echo "  本脚本将依次运行："
echo "    1. NavieRAG"
echo "    2. GraphRAG Local"
echo "    3. GraphRAG Global"
echo "======================================================"
echo ""

# ── 1. NavieRAG ───────────────────────────────────────────────────────────────
echo ">>> [1/3] NavieRAG 评估..."
bash "${SCRIPT_DIR}/run_naive_rag_eval.sh"
echo ""

# ── 2. GraphRAG Local ─────────────────────────────────────────────────────────
echo ">>> [2/3] GraphRAG Local 评估..."
bash "${SCRIPT_DIR}/run_graphrag_local_eval.sh"
echo ""

# ── 3. GraphRAG Global ────────────────────────────────────────────────────────
echo ">>> [3/3] GraphRAG Global 评估..."
bash "${SCRIPT_DIR}/run_graphrag_global_eval.sh"
echo ""

# ── 汇总打印（需要 python + json 模块） ───────────────────────────────────────
echo "======================================================"
echo "  汇总对比（所有结果来自 eval/results/）"
echo "======================================================"

python3 - <<'PYEOF'
import json, os, sys
from pathlib import Path

results_dir = Path(__file__).parent / "results" if False else Path("eval/results")
files = {
    "NavieRAG":       results_dir / "naive_rag_results.json",
    "GraphRAG Local": results_dir / "graphrag_local_results.json",
    "GraphRAG Global":results_dir / "graphrag_global_results.json",
}
metrics = ["bleu-1", "bleu-2", "bleu-3", "bleu-4", "rouge_l", "bert_score_f1", "recall@k"]

# 表头
header = f"{'Baseline':<22}" + "".join(f"{m:>16}" for m in metrics)
print(header)
print("-" * (22 + 16 * len(metrics)))

for name, fpath in files.items():
    if not fpath.exists():
        print(f"{name:<22}  (结果文件不存在: {fpath})")
        continue
    with open(fpath, encoding="utf-8") as f:
        data = json.load(f)
    agg = data.get("aggregate", {})
    row = f"{name:<22}" + "".join(f"{agg.get(m, float('nan')):>16.4f}" for m in metrics)
    print(row)
PYEOF

echo ""
echo "✅ 全量评估完成！"
