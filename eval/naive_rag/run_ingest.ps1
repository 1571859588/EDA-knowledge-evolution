# eval/naive_rag/run_ingest.ps1 — NavieRAG 文档索引（Windows PowerShell）
# 请从项目根目录执行：.\eval\naive_rag\run_ingest.ps1
$ErrorActionPreference = "Stop"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir      = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$NaiveRagDir  = Join-Path $RootDir "baselines\naive_rag"
$SrcConfig    = Join-Path $ScriptDir "config.yaml"
$DstConfig    = Join-Path $NaiveRagDir "eda_eval\config_ordqa.yaml"
$DocJson      = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\openroad_documentation.json"
$IndexDir     = Join-Path $NaiveRagDir "eda_eval\index"

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  NavieRAG × ORD-QA 文档索引"                           -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  [1/2] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Write-Host "  [2/2] 建立 FAISS 索引..." -ForegroundColor Yellow
Push-Location $NaiveRagDir
try {
    uv run python eda_eval/ingest_ordqa.py --doc_json $DocJson --index_dir $IndexDir --config $DstConfig
} finally { Pop-Location }
Write-Host "✅ 索引完成！" -ForegroundColor Green
