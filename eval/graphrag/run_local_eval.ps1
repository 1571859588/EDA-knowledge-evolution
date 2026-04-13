# eval/graphrag/run_local_eval.ps1（Windows PowerShell）
# $env:QUESTION_TYPES / $env:MAX_SAMPLES 可选
$ErrorActionPreference = "Stop"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir     = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$GraphRAGDir = Join-Path $RootDir "baselines\graphrag"
$SrcConfig   = Join-Path $ScriptDir "config.yml"
$DstConfig   = Join-Path $GraphRAGDir "eda_eval\config_ordqa.yml"
$Benchmark   = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\ORD-QA.jsonl"
$Workspace   = Join-Path $GraphRAGDir "eda_eval\workspace"
$Output      = Join-Path $ScriptDir "results_local.json"
$QTypes      = if ($env:QUESTION_TYPES) { $env:QUESTION_TYPES } else { "" }
$MaxSamples  = if ($env:MAX_SAMPLES)    { $env:MAX_SAMPLES }    else { "-1" }

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  GraphRAG Local × ORD-QA 评估  →  $Output"            -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  [1/2] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Write-Host "  [2/2] 开始评估（local）..." -ForegroundColor Yellow
Push-Location $GraphRAGDir
try {
    $Extra = @("--query_type", "local", "--max_samples", $MaxSamples)
    if ($QTypes) { $Extra += @("--question_types", $QTypes) }
    uv run python eda_eval/evaluate_ordqa.py `
        --benchmark $Benchmark --workspace $Workspace `
        --config $DstConfig --output $Output @Extra
} finally { Pop-Location }
Write-Host "✅ GraphRAG Local 评估完成！" -ForegroundColor Green
