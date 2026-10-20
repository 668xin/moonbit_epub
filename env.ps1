# Moonbit_EPUB 开发环境（PowerShell）
#
# 用途：
#   1. 可选：如工具链需要覆盖核心库源码，先设置 MOON_CORE_DIR。
#   2. 默认后端为 wasm-gc —— preferred_target 已设为 wasm-gc，无需再显式指定。
#
# 用法：. .\env.ps1

if ($env:MOON_CORE_DIR) {
  $env:MOON_CORE_OVERRIDE = $env:MOON_CORE_DIR
}
$env:PATH = "$HOME\.moon\bin;$env:PATH"

function moon-gc { moon @args --target wasm-gc }

Write-Host "[moon-epub] PATH 已包含 ~/.moon/bin"
Write-Host "[moon-epub] 默认使用 wasm-gc 后端（可用 moon-gc <cmd> 显式指定）"
