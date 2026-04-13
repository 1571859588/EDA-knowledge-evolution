# =============================================================================
# run_all_eval.ps1
# 串行执行所有 Baseline 的 ORD-QA 评估，最终打印汇总对比表格（Windows PowerShell）
# 请从项目根目录（EDAAgentMemory/）执行：.\eval\run_all_eval.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  EDAAgentMemory — 全量 Baseline 评估" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  依次执行: NavieRAG → GraphRAG Local → GraphRAG Global"
Write-Host "======================================================"
Write-Host ""

# 1. NavieRAG
Write-Host ">>> [1/3] NavieRAG 评估..." -ForegroundColor Magenta
& "$ScriptDir\run_naive_rag_eval.ps1"
Write-Host ""

# 2. GraphRAG Local
Write-Host ">>> [2/3] GraphRAG Local 评估..." -ForegroundColor Magenta
& "$ScriptDir\run_graphrag_local_eval.ps1"
Write-Host ""

# 3. GraphRAG Global
Write-Host ">>> [3/3] GraphRAG Global 评估..." -ForegroundColor Magenta
& "$ScriptDir\run_graphrag_global_eval.ps1"
Write-Host ""

# 汇总对比
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  汇总对比（来自 eval\results\）" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$ResultsDir = Join-Path $RootDir "eval\results"
$Files = @{
    "NavieRAG"        = Join-Path $ResultsDir "naive_rag_results.json"
    "GraphRAG Local"  = Join-Path $ResultsDir "graphrag_local_results.json"
    "GraphRAG Global" = Join-Path $ResultsDir "graphrag_global_results.json"
}
$Metrics = @("bleu-1","bleu-2","bleu-3","bleu-4","rouge_l","bert_score_f1","recall@k")

# 表头
$Header = "{0,-22}" -f "Baseline"
foreach ($m in $Metrics) { $Header += "{0,14}" -f $m }
Write-Host $Header
Write-Host ("-" * (22 + 14 * $Metrics.Count))

foreach ($name in $Files.Keys) {
    $fpath = $Files[$name]
    if (-not (Test-Path $fpath)) {
        Write-Host ("{0,-22}  (文件不存在: {1})" -f $name, $fpath) -ForegroundColor Red
        continue
    }
    $data = Get-Content $fpath -Raw | ConvertFrom-Json
    $agg  = $data.aggregate
    $Row  = "{0,-22}" -f $name
    foreach ($m in $Metrics) {
        $val = if ($null -ne $agg.$m) { "{0,14:F4}" -f [double]$agg.$m } else { "{0,14}" -f "N/A" }
        $Row += $val
    }
    Write-Host $Row
}

Write-Host ""
Write-Host "✅ 全量评估完成！" -ForegroundColor Green
