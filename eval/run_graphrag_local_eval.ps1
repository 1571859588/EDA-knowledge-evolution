# =============================================================================
# run_graphrag_local_eval.ps1  /  run_graphrag_global_eval.ps1
# 运行 GraphRAG Local 或 Global Search × ORD-QA 评估（Windows PowerShell）
# 请从项目根目录（EDAAgentMemory/）执行：
#   .\eval\run_graphrag_local_eval.ps1
# 或使用 Global 模式：
#   $env:QUERY_TYPE="global"; .\eval\run_graphrag_local_eval.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir

$GraphRAGDir  = Join-Path $RootDir "baselines\graphrag"
$EvalConfig   = Join-Path $ScriptDir "configs\graphrag_config.yml"
$TargetConfig = Join-Path $GraphRAGDir "eda_eval\config_ordqa.yml"
$Benchmark    = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\ORD-QA.jsonl"
$Workspace    = Join-Path $GraphRAGDir "eda_eval\workspace"

# 本文件硬编码为 local；global 版通过 run_graphrag_global_eval.ps1 调用
$QueryType      = if ($env:QUERY_TYPE)      { $env:QUERY_TYPE }      else { "local" }
$QuestionTypes  = if ($env:QUESTION_TYPES)  { $env:QUESTION_TYPES }  else { "" }
$MaxSamples     = if ($env:MAX_SAMPLES)     { $env:MAX_SAMPLES }     else { "-1" }
$Output         = Join-Path $RootDir "eval\results\graphrag_${QueryType}_results.json"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  GraphRAG $($QueryType.ToUpper()) × ORD-QA 评估" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  配置来源  : $EvalConfig"
Write-Host "  基准数据  : $Benchmark"
Write-Host "  工作空间  : $Workspace"
Write-Host "  查询模式  : $QueryType"
Write-Host "  结果输出  : $Output"
if ($QuestionTypes) { Write-Host "  只评估类型: $QuestionTypes" }
if ($MaxSamples -ne "-1") { Write-Host "  最大样本  : $MaxSamples" }
Write-Host ""

Write-Host "[步骤 1/2] 同步配置文件 → $TargetConfig" -ForegroundColor Yellow
Copy-Item -Force $EvalConfig $TargetConfig

Write-Host "[步骤 2/2] 开始评估（$QueryType Search）..." -ForegroundColor Yellow
Push-Location $GraphRAGDir
try {
    $ExtraArgs = @("--query_type", $QueryType, "--max_samples", $MaxSamples)
    if ($QuestionTypes) { $ExtraArgs += @("--question_types", $QuestionTypes) }

    uv run python eda_eval/evaluate_ordqa.py `
        --benchmark  $Benchmark `
        --workspace  $Workspace `
        --config     $TargetConfig `
        --output     $Output `
        @ExtraArgs
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ GraphRAG $($QueryType.ToUpper()) 评估完成！结果: $Output" -ForegroundColor Green
