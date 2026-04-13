# =============================================================================
# run_graphrag_ingest.ps1
# 索引 ORD-QA 文档 → GraphRAG 知识图谱（Windows PowerShell）
# 请从项目根目录（EDAAgentMemory/）执行：.\eval\run_graphrag_ingest.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir

$GraphRAGDir  = Join-Path $RootDir "baselines\graphrag"
$EvalConfig   = Join-Path $ScriptDir "configs\graphrag_config.yml"
$TargetConfig = Join-Path $GraphRAGDir "eda_eval\config_ordqa.yml"
$DocJson      = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\openroad_documentation.json"
$Workspace    = Join-Path $GraphRAGDir "eda_eval\workspace"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  GraphRAG × ORD-QA 文档索引" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  配置来源  : $EvalConfig"
Write-Host "  文档路径  : $DocJson"
Write-Host "  工作空间  : $Workspace"
Write-Host ""
Write-Host "  ⚠️  本操作会大量调用 LLM API，请确认 API 余额充足！" -ForegroundColor Yellow
Write-Host ""

# 1. 同步配置
Write-Host "[步骤 1/3] 同步配置文件 → $TargetConfig" -ForegroundColor Yellow
Copy-Item -Force $EvalConfig $TargetConfig

# 2. 初始化工作空间（如不存在）
$SettingsFile = Join-Path $Workspace "settings.yaml"
Push-Location $GraphRAGDir
try {
    if (-not (Test-Path $SettingsFile)) {
        Write-Host "[步骤 2/3] 初始化 GraphRAG 工作空间..." -ForegroundColor Yellow
        uv run graphrag init --root $Workspace
    } else {
        Write-Host "[步骤 2/3] 工作空间已存在，跳过初始化。" -ForegroundColor Gray
    }

    # 3. 执行索引
    Write-Host "[步骤 3/3] 开始索引文档..." -ForegroundColor Yellow
    uv run python eda_eval/ingest_ordqa.py `
        --doc_json  $DocJson `
        --workspace $Workspace
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ GraphRAG 索引完成！" -ForegroundColor Green
