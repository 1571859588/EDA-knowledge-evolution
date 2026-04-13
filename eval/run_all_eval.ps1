# eval/run_all_eval.ps1（Windows PowerShell）
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  EDAAgentMemory — 全量 Baseline 评估"                 -ForegroundColor Cyan
Write-Host "  NavieRAG → GraphRAG Local → GraphRAG Global"
Write-Host "======================================================"

Write-Host ">>> [1/3] NavieRAG..." -ForegroundColor Magenta
& "$ScriptDir\naive_rag\run_eval.ps1"

Write-Host ">>> [2/3] GraphRAG Local..." -ForegroundColor Magenta
& "$ScriptDir\graphrag\run_local_eval.ps1"

Write-Host ">>> [3/3] GraphRAG Global..." -ForegroundColor Magenta
& "$ScriptDir\graphrag\run_global_eval.ps1"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  汇总对比" -ForegroundColor Cyan
Write-Host "======================================================"

$Files = @{
    "NavieRAG"        = Join-Path $ScriptDir "naive_rag\results.json"
    "GraphRAG Local"  = Join-Path $ScriptDir "graphrag\results_local.json"
    "GraphRAG Global" = Join-Path $ScriptDir "graphrag\results_global.json"
}
$Metrics = @("bleu-1","bleu-2","bleu-3","bleu-4","rouge_l","bert_score_f1","recall@k")
$Header = "{0,-22}" -f "Baseline"
foreach ($m in $Metrics) { $Header += "{0,13}" -f $m }
Write-Host $Header
Write-Host ("-" * (22 + 13 * $Metrics.Count))

foreach ($name in $Files.Keys) {
    $fp = $Files[$name]
    if (-not (Test-Path $fp)) { Write-Host ("{0,-22}  (未找到)" -f $name) -ForegroundColor Red; continue }
    $agg = (Get-Content $fp -Raw | ConvertFrom-Json).aggregate
    $row = "{0,-22}" -f $name
    foreach ($m in $Metrics) {
        $v = if ($null -ne $agg.$m) { "{0,13:F4}" -f [double]$agg.$m } else { "{0,13}" -f "N/A" }
        $row += $v
    }
    Write-Host $row
}
Write-Host "✅ 全量评估完成！" -ForegroundColor Green
