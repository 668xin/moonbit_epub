# Moonbit_EPUB 开发环境（PowerShell）
#
# 用途：
#   1. MOON_CORE_OVERRIDE —— 本机 moon 工具链需要它指向核心库源码目录，
#      否则报 "Cannot inject the standard library `moonbitlang/core`"。
#   2. 提示使用 js 后端 —— 本机 wasm-gc 后端 println 静默丢失、moon test 崩溃，
#      所有命令必须带 --target js。
#
# 用法：. .\env.ps1

$env:MOON_CORE_OVERRIDE = "C:\Users\xinxin.deng\.moon\registry\cache\moonbitlang\core\0.1.20260714+ade96c819"
$env:PATH = "$HOME\.moon\bin;$env:PATH"

function moon-js { moon @args --target js }

Write-Host "[moon-epub] MOON_CORE_OVERRIDE 已设置"
Write-Host "[moon-epub] 请使用 'moon <cmd> --target js'（或包装函数 moon-js <cmd>）"
