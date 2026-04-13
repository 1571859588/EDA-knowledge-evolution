#!/usr/bin/env bash
# eval/run_all_eval.sh — 一键串行跑所有 baseline 评估并打印对比表格
# 请从项目根目录执行：bash eval/run_all_eval.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================"
echo "  EDAAgentMemory — 全量 Baseline 评估"
echo "  NavieRAG → GraphRAG Local → GraphRAG Global"
echo "======================================================"

echo ">>> [1/3] NavieRAG..."
bash "${SCRIPT_DIR}/naive_rag/run_eval.sh"

echo ">>> [2/3] GraphRAG Local..."
bash "${SCRIPT_DIR}/graphrag/run_local_eval.sh"

echo ">>> [3/3] GraphRAG Global..."
bash "${SCRIPT_DIR}/graphrag/run_global_eval.sh"

echo ""
echo "======================================================"
echo "  汇总对比"
echo "======================================================"
python3 - <<'PYEOF'
import json
from pathlib import Path
base = Path("eval")
files = {
    "NavieRAG":        base / "naive_rag/results.json",
    "GraphRAG Local":  base / "graphrag/results_local.json",
    "GraphRAG Global": base / "graphrag/results_global.json",
}
metrics = ["bleu-1","bleu-2","bleu-3","bleu-4","rouge_l","bert_score_f1","recall@k"]
print(f"{'Baseline':<22}" + "".join(f"{m:>14}" for m in metrics))
print("-" * (22 + 14 * len(metrics)))
for name, fp in files.items():
    if not fp.exists():
        print(f"{name:<22}  (未找到: {fp})"); continue
    agg = json.load(open(fp))["aggregate"]
    print(f"{name:<22}" + "".join(f"{agg.get(m,float('nan')):>14.4f}" for m in metrics))
PYEOF
echo "✅ 全量评估完成！"
