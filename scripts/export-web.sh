#!/usr/bin/env bash
# 本地导出 Web 版到 web/，供 Vercel 静态部署（方案 A）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 godot 命令。可设置: GODOT=/path/to/godot $0" >&2
	exit 1
fi

mkdir -p web
"$GODOT" --headless --export-release "Web" "$ROOT/web/index.html"
echo "导出完成: $ROOT/web/"
echo "提交 web/ 并 push 后 Vercel 会自动更新。"
