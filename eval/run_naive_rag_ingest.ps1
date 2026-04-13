# =============================================================================
# run_naive_rag_ingest.ps1
# 索引 ORD-QA 文档库 → NavieRAG FAISS 向量索引（Windows PowerShell）
# 请从项目根目录（EDAAgentMemory/）执行：.\eval\run_naive_rag_ingest.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir

$NaiveRagDir  = Join-Path $RootDir "baselines\naive_rag"
$EvalConfig   = Join-Path $ScriptDir "configs\naive_rag_config.yaml"
$TargetConfig = Join-Path $NaiveRagDir "eda_eval\config_ordqa.yaml"
$DocJson      = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\openroad_documentation.json"
$IndexDir     = Join-Path $NaiveRagDir "eda_eval\index"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  NavieRAG × ORD-QA 文档索引" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  配置来源  : $EvalConfig"
Write-Host "  文档路径  : $DocJson"
Write-Host "  索引输出  : $IndexDir"
Write-Host ""

# 1. 同步配置
Write-Host "[步骤 1/2] 同步配置文件 → $TargetConfig" -ForegroundColor Yellow
Copy-Item -Force $EvalConfig $TargetConfig

# 2. 执行索引
Write-Host "[步骤 2/2] 开始建立 FAISS 索引..." -ForegroundColor Yellow
Push-Location $NaiveRagDir
try {
    uv run python eda_eval/ingest_ordqa.py `
        --doc_json  $DocJson `
        --index_dir $IndexDir `
        --config    $TargetConfig
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ 索引完成！" -ForegroundColor Green
