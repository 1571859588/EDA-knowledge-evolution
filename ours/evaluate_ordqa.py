"""
evaluate_ordqa.py — TPMA × ORD-QA 完整评估脚本

指标（与 baseline 完全对齐）：
  - BLEU-1/2/3/4, ROUGE-L, BERTScore F1, Recall@K
  - 额外输出各阶段耗时和中间结果

用法（在项目根目录）：
    uv run python ours/evaluate_ordqa.py \\
        --benchmark benchmarks/ORD-QA/benchmark/ORD-QA.jsonl \\
        --config    ours/config.yaml \\
        --output    ours/results_tpma.json
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from tqdm import tqdm

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

# ── 指标计算（与 baseline 脚本复用相同函数） ──────────────────────────────────
import nltk
from nltk.translate.bleu_score import SmoothingFunction, sentence_bleu
from rouge_score import rouge_scorer

nltk.download("punkt", quiet=True)
nltk.download("punkt_tab", quiet=True)

_smoother = SmoothingFunction().method1
_rouge = rouge_scorer.RougeScorer(["rougeL"], use_stemmer=True)


def compute_bleu(ref: str, hyp: str) -> dict[str, float]:
    ref_tok = nltk.word_tokenize(ref.lower())
    hyp_tok = nltk.word_tokenize(hyp.lower())
    return {
        f"bleu-{n}": sentence_bleu(
            [ref_tok], hyp_tok,
            weights=tuple([1/n]*n + [0]*(4-n)),
            smoothing_function=_smoother,
        )
        for n in range(1, 5)
    }


def compute_rouge_l(ref: str, hyp: str) -> float:
    return _rouge.score(ref, hyp)["rougeL"].fmeasure


def compute_bert_score(refs: list[str], hyps: list[str]) -> list[float]:
    import bert_score as bs
    _, _, F = bs.score(hyps, refs, lang="en", verbose=False)
    return F.tolist()


def compute_recall(pred_ids: list[str], gold_refs: list[str]) -> float:
    if not gold_refs:
        return 0.0
    pred_set = set(pred_ids)
    # 模糊匹配：gold ref 是否被检索结果的前缀匹配
    hits = 0
    for ref in gold_refs:
        for pid in pred_set:
            if ref in pid or pid in ref:
                hits += 1
                break
    return hits / len(gold_refs)


# ── 数据 ──────────────────────────────────────────────────────────────────────

def load_benchmark(path: str) -> list[dict]:
    samples = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))
    return samples


def filter_samples(samples, qtypes, max_n):
    if qtypes:
        type_set = {t.strip().lower() for t in qtypes}
        samples = [s for s in samples if s.get("type", "").lower() in type_set]
    if max_n > 0:
        samples = samples[:max_n]
    return samples


# ── 主评估 ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="TPMA × ORD-QA 评估")
    parser.add_argument("--benchmark", default="benchmarks/ORD-QA/benchmark/ORD-QA.jsonl")
    parser.add_argument("--config", default="ours/config.yaml")
    parser.add_argument("--output", default="ours/results_tpma.json")
    parser.add_argument("--question_types", default=None)
    parser.add_argument("--max_samples", type=int, default=-1)
    args = parser.parse_args()

    # 初始化 Pipeline
    from ours.pipeline import TriPolarPipeline
    pipeline = TriPolarPipeline(config_path=args.config)

    # 加载基准
    samples = load_benchmark(args.benchmark)
    qtypes = args.question_types.split(",") if args.question_types else None
    samples = filter_samples(samples, qtypes, args.max_samples)
    print(f"[eval] 共 {len(samples)} 条样本")

    detailed: list[dict] = []
    predictions: list[str] = []
    references: list[str] = []
    total_stage_times: dict[str, float] = {}

    for sample in tqdm(samples, desc="TPMA 推理中"):
        question = sample.get("question", "").strip()
        gold_ans = sample.get("answer", "").strip()
        gold_refs = sample.get("reference", [])

        try:
            result = pipeline.run(question)
            pred_ans = result["answer"]
        except Exception as e:
            print(f"\n  [⚠️] id={sample.get('id')} 失败: {e}")
            pred_ans = ""
            result = {"final_chunk_ids": [], "recall_chunk_ids": [],
                      "entities": [], "expanded_query": "", "stage_times": {}}

        # 计算指标
        bleu = compute_bleu(gold_ans, pred_ans)
        rl = compute_rouge_l(gold_ans, pred_ans)
        recall = compute_recall(result.get("final_chunk_ids", []), gold_refs)
        recall_coarse = compute_recall(result.get("recall_chunk_ids", []), gold_refs)

        record = {
            "id": sample.get("id"),
            "type": sample.get("type"),
            "question": question,
            "gold": gold_ans,
            "pred": pred_ans,
            "gold_refs": gold_refs,
            "entities": result.get("entities", []),
            "expanded_query": result.get("expanded_query", ""),
            "recall_chunk_ids": result.get("recall_chunk_ids", []),
            "final_chunk_ids": result.get("final_chunk_ids", []),
            "recall@k_coarse": recall_coarse,
            "recall@k": recall,
            "rouge_l": rl,
            **bleu,
            "stage_times": result.get("stage_times", {}),
        }
        detailed.append(record)
        predictions.append(pred_ans)
        references.append(gold_ans)

        # 累加阶段耗时
        for k, v in result.get("stage_times", {}).items():
            total_stage_times[k] = total_stage_times.get(k, 0.0) + v

    # BERTScore
    print("[eval] 计算 BERTScore...")
    bert_f1 = compute_bert_score(references, predictions)
    for item, bf in zip(detailed, bert_f1):
        item["bert_score_f1"] = bf

    # 汇总
    n = len(detailed)
    keys = ["bleu-1", "bleu-2", "bleu-3", "bleu-4", "rouge_l",
            "recall@k_coarse", "recall@k", "bert_score_f1"]
    agg = {k: round(sum(d.get(k, 0) for d in detailed) / n, 4) for k in keys}
    avg_times = {k: round(v / n, 3) for k, v in total_stage_times.items()}

    # 按类型分层
    by_type: dict[str, dict] = {}
    for qtype in {"functionality", "vlsi_flow", "gui & installation & test"}:
        subset = [d for d in detailed if d.get("type", "") == qtype]
        if subset:
            by_type[qtype] = {
                k: round(sum(d.get(k, 0) for d in subset) / len(subset), 4)
                for k in keys
            }
            by_type[qtype]["count"] = len(subset)

    # 打印
    print("\n" + "=" * 60)
    print("  TPMA × ORD-QA 评估结果")
    print("=" * 60)
    print(f"  样本数: {n}")
    print(f"  {'指标':<24} {'值':>8}")
    print("  " + "-" * 34)
    for k, v in agg.items():
        print(f"  {k:<24} {v:>8.4f}")
    print()
    print("  平均各阶段耗时 (秒/样本):")
    for k, v in avg_times.items():
        print(f"    {k:<30} {v:.3f}")
    if by_type:
        print("\n  按问题类型细分:")
        for qtype, metrics in by_type.items():
            cnt = metrics.pop("count")
            print(f"    [{qtype}] n={cnt}")
            for mk, mv in metrics.items():
                print(f"      {mk:<22} {mv:.4f}")
            metrics["count"] = cnt
    print("=" * 60)

    # 写出 JSON
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    output_data = {
        "config": {
            "method": "TPMA (Tri-Polar Memory Architecture)",
            "model": pipeline.config.get("llm", {}).get("model", ""),
            "total_samples": n,
        },
        "aggregate": agg,
        "avg_stage_times": avg_times,
        "by_type": by_type,
        "details": detailed,
    }
    with open(out, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    print(f"\n[eval] 结果已保存至: {out}")


if __name__ == "__main__":
    main()
