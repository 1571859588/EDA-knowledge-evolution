# =============================================================================
# run_naive_rag_eval.ps1
# 运行 NavieRAG × ORD-QA 完整评估（Windows PowerShell）
# 请从项目根目录（EDAAgentMemory/）执行：.\eval\run_naive_rag_eval.ps1
# 可选：在调用前设置 $env:TOP_K / $env:QUESTION_TYPES / $env:MAX_SAMPLES
# =============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir

$NaiveRagDir  = Join-Path $RootDir "baselines\naive_rag"
$EvalConfig   = Join-Path $ScriptDir "configs\naive_rag_config.yaml"
$TargetConfig = Join-Path $NaiveRagDir "eda_eval\config_ordqa.yaml"
$Benchmark    = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\ORD-QA.jsonl"
$IndexDir     = Join-Path $NaiveRagDir "eda_eval\index"
$Output       = Join-Path $RootDir "eval\results\naive_rag_results.json"

# 可选覆盖参数
$TopK           = if ($env:TOP_K)           { $env:TOP_K }           else { "" }
$QuestionTypes  = if ($env:QUESTION_TYPES)  { $env:QUESTION_TYPES }  else { "" }
$MaxSamples     = if ($env:MAX_SAMPLES)     { $env:MAX_SAMPLES }     else { "-1" }

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  NavieRAG × ORD-QA 评估" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  配置来源  : $EvalConfig"
Write-Host "  基准数据  : $Benchmark"
Write-Host "  索引目录  : $IndexDir"
Write-Host "  结果输出  : $Output"
if ($TopK)          { Write-Host "  top_k     : $TopK" }
if ($QuestionTypes) { Write-Host "  只评估类型: $QuestionTypes" }
if ($MaxSamples -ne "-1") { Write-Host "  最大样本  : $MaxSamples" }
Write-Host ""

# 1. 同步配置
Write-Host "[步骤 1/2] 同步配置文件 → $TargetConfig" -ForegroundColor Yellow
Copy-Item -Force $EvalConfig $TargetConfig

# 2. 执行评估
Write-Host "[步骤 2/2] 开始评估..." -ForegroundColor Yellow
Push-Location $NaiveRagDir
try {
    $ExtraArgs = @("--max_samples", $MaxSamples)
    if ($TopK)          { $ExtraArgs += @("--top_k", $TopK) }
    if ($QuestionTypes) { $ExtraArgs += @("--question_types", $QuestionTypes) }

    uv run python eda_eval/evaluate_ordqa.py `
        --benchmark  $Benchmark `
        --index_dir  $IndexDir `
        --config     $TargetConfig `
        --output     $Output `
        @ExtraArgs
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ 评估完成！结果: $Output" -ForegroundColor Green
