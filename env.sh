# Moonbit_EPUB 开发环境（bash）
#
# 用途：
#   1. 可选：如工具链需要覆盖核心库源码，先设置 MOON_CORE_DIR。
#   2. 默认后端为 wasm-gc —— preferred_target 已设为 wasm-gc，无需再显式指定。
#
# 用法：source env.sh

if [ -n "$MOON_CORE_DIR" ]; then
  export MOON_CORE_OVERRIDE="$MOON_CORE_DIR"
fi
export PATH="$HOME/.moon/bin:$PATH"

# 便捷包装：自动带上 --target wasm-gc
moon-gc() {
  moon "$@" --target wasm-gc
}

echo "[moon-epub] PATH 已包含 ~/.moon/bin"
echo "[moon-epub] 默认使用 wasm-gc 后端（可用 moon-gc <cmd> 显式指定）"
