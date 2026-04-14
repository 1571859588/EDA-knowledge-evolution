# eval/tpma/run_eval.ps1 — TPMA × ORD-QA 评估（Windows PowerShell）
$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$SrcConfig  = Join-Path $ScriptDir "config.yaml"
$DstConfig  = Join-Path $RootDir "ours\config.yaml"
$Benchmark  = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\ORD-QA.jsonl"
$Output     = Join-Path $ScriptDir "results.json"
$QTypes     = if ($env:QUESTION_TYPES) { $env:QUESTION_TYPES } else { "" }
$MaxSamples = if ($env:MAX_SAMPLES)    { $env:MAX_SAMPLES }    else { "-1" }

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  TPMA × ORD-QA 评估  →  $Output"                     -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  [1/2] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Write-Host "  [2/2] 开始评估..." -ForegroundColor Yellow
Push-Location $RootDir
try {
    $Extra = @("--max_samples", $MaxSamples)
    if ($QTypes) { $Extra += @("--question_types", $QTypes) }
    uv run python ours/evaluate_ordqa.py `
        --benchmark $Benchmark --config $DstConfig `
        --output $Output @Extra
} finally { Pop-Location }
Write-Host "✅ TPMA 评估完成！" -ForegroundColor Green
