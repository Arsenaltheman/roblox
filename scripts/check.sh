#!/usr/bin/env bash
# Runs every check that must pass before a push. Usage: scripts/check.sh
# Needs: stylua, selene, lune, rojo, luau-lsp on PATH (see docs/DEVELOPING.md).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== format (StyLua)"
# A StyLua built without the "luau" feature silently skips .luau files when given folders, so first
# make sure it can actually parse one.
stylua --check src/server/main.server.luau > /dev/null || {
	echo "StyLua can't read Luau. Reinstall with: cargo install stylua --features luau"
	exit 1
}
stylua --check src tests tools

echo "== lint (selene)"
selene src tests tools

echo "== unit tests (Lune)"
lune run tests/run

echo "== cross-service references"
lune run tools/check-registry

echo "== economy simulator gates"
lune run tools/econ-sim/main -- --seeds 60 --gates > /dev/null

echo "== build (Rojo)"
mkdir -p build
rojo build default.project.json -o build/CritterExpress.rbxl

if command -v luau-lsp > /dev/null; then
	echo "== types (luau-lsp, strict)"
	rojo sourcemap default.project.json -o sourcemap.json > /dev/null
	out=$(luau-lsp analyze --sourcemap=sourcemap.json --definitions=types/globalTypes.d.luau --ignore="vendor/**" src tests/cloud 2>&1 | grep -v '^\[INFO\]\|^\[WARN\]' || true)
	if [ -n "$out" ]; then
		echo "$out"
		exit 1
	fi
else
	echo "== types: luau-lsp not installed, skipped"
fi

echo "All checks passed."
