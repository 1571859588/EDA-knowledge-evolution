# eval/naive_rag/run_eval.ps1 — NavieRAG × ORD-QA 评估（Windows PowerShell）
# 请从项目根目录执行：.\eval\naive_rag\run_eval.ps1
# 可选：$env:TOP_K / $env:QUESTION_TYPES / $env:MAX_SAMPLES
$ErrorActionPreference = "Stop"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir      = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$NaiveRagDir  = Join-Path $RootDir "baselines\naive_rag"
$SrcConfig    = Join-Path $ScriptDir "config.yaml"
$DstConfig    = Join-Path $NaiveRagDir "eda_eval\config_ordqa.yaml"
$Benchmark    = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\ORD-QA.jsonl"
$IndexDir     = Join-Path $NaiveRagDir "eda_eval\index"
$Output       = Join-Path $ScriptDir "results.json"

$TopK          = if ($env:TOP_K)           { $env:TOP_K }          else { "" }
$QTypes        = if ($env:QUESTION_TYPES)  { $env:QUESTION_TYPES } else { "" }
$MaxSamples    = if ($env:MAX_SAMPLES)     { $env:MAX_SAMPLES }    else { "-1" }

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  NavieRAG × ORD-QA 评估"                               -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  结果 → $Output"

Write-Host "  [1/2] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Write-Host "  [2/2] 开始评估..." -ForegroundColor Yellow
Push-Location $NaiveRagDir
try {
    $Extra = @("--max_samples", $MaxSamples)
    if ($TopK)   { $Extra += @("--top_k", $TopK) }
    if ($QTypes) { $Extra += @("--question_types", $QTypes) }
    uv run python eda_eval/evaluate_ordqa.py `
        --benchmark $Benchmark --index_dir $IndexDir `
        --config $DstConfig --output $Output @Extra
} finally { Pop-Location }
Write-Host "✅ 评估完成！结果: $Output" -ForegroundColor Green
