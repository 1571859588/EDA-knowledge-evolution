# =============================================================================
# run_graphrag_global_eval.ps1
# 运行 GraphRAG Global Search × ORD-QA 评估（Windows PowerShell 快捷入口）
# 请从项目根目录（EDAAgentMemory/）执行：.\eval\run_graphrag_global_eval.ps1
# =============================================================================
$env:QUERY_TYPE = "global"
& "$PSScriptRoot\run_graphrag_local_eval.ps1"
