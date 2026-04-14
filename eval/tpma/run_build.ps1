# eval/tpma/run_build.ps1 — 构建 TPMA 知识库（Windows PowerShell）
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$SrcConfig = Join-Path $ScriptDir "config.yaml"
$DstConfig = Join-Path $RootDir "ours\config.yaml"
$DocJson   = Join-Path $RootDir "benchmarks\ORD-QA\benchmark\openroad_documentation.json"

Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  TPMA 知识库构建  ⚠️  大量 API 调用"                  -ForegroundColor Cyan
Write-Host "======================================================"  -ForegroundColor Cyan
Write-Host "  [1/2] 同步配置 → $DstConfig" -ForegroundColor Yellow
Copy-Item -Force $SrcConfig $DstConfig

Write-Host "  [2/2] 构建知识库..." -ForegroundColor Yellow
Push-Location $RootDir
try {
    uv run python ours/build_knowledge.py --doc_json $DocJson --config $DstConfig
} finally { Pop-Location }
Write-Host "✅ 知识库构建完成！" -ForegroundColor Green
