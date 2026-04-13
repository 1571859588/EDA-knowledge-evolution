# eval/graphrag/run_ingest.ps1（Windows PowerShell）
$ErrorActionPreference = "Stop"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir     = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$GraphRAGDir = Join-Path $RootDir "baselines\graphrag"
$SrcConfig   = Join-Path $ScriptDir "config.yml"
$DstConfig   = Join-Path $GraphRAGDir "eda_eval\config_ordqa.yml"
$DocJson     = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\openroad_documentation.json"
$Workspace   = Join-Path $GraphRAGDir "eda_eval\workspace"

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  GraphRAG × ORD-QA 文档索引  ⚠️  大量 API 调用"       -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  [1/3] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Push-Location $GraphRAGDir
try {
    if (-not (Test-Path (Join-Path $Workspace "settings.yaml"))) {
        Write-Host "  [2/3] 初始化工作空间..." -ForegroundColor Yellow
        uv run graphrag init --root $Workspace
    } else {
        Write-Host "  [2/3] 工作空间已存在，跳过。" -ForegroundColor Gray
    }
    Write-Host "  [3/3] 开始索引..." -ForegroundColor Yellow
    uv run python eda_eval/ingest_ordqa.py --doc_json $DocJson --workspace $Workspace
} finally { Pop-Location }
Write-Host "✅ GraphRAG 索引完成！" -ForegroundColor Green
