#!/usr/bin/env bash
# Install node-use into ~/.local/bin and set up the required shell function.
set -euo pipefail

BIN="${BIN:-$HOME/.local/bin}"
RCD="$HOME/.bashrc.d"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/node-use"

[ -f "$SRC" ] || { echo "install.sh: cannot find node-use next to this script" >&2; exit 1; }

install -Dm755 "$SRC" "$BIN/node-use"
echo "installed $BIN/node-use"

mkdir -p "$RCD"
if [ -e "$RCD/node.sh" ] && ! grep -q 'node-use() *{' "$RCD/node.sh" 2>/dev/null; then
    echo "note: $RCD/node.sh exists and has no node-use function; appending"
    cat >> "$RCD/node.sh" <<'EOF'

# Added by node-use install.sh
node-use() {
    command node-use "$@" || return $?
    hash -r 2>/dev/null || true
}
EOF
elif [ ! -e "$RCD/node.sh" ]; then
    cat > "$RCD/node.sh" <<'EOF'
# Stop corepack prompting before it downloads a pnpm/yarn version.
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Wrapper around the node-use script. Required: switching versions changes
# which path `node` resolves to, and bash caches command locations. A child
# process cannot clear the parent shell's hash table, so we do it here.
node-use() {
    command node-use "$@" || return $?
    hash -r 2>/dev/null || true
}
EOF
    echo "created $RCD/node.sh"
else
    echo "$RCD/node.sh already defines node-use; left unchanged"
fi

# sanity checks
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "WARNING: $BIN is not on your PATH - add it in ~/.bashrc" ;;
esac
if ! grep -q 'bashrc.d' "$HOME/.bashrc" 2>/dev/null; then
    echo "WARNING: ~/.bashrc does not source ~/.bashrc.d/* - add:"
    echo '  for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done'
fi
for t in curl jq tar; do
    command -v "$t" >/dev/null 2>&1 || echo "WARNING: missing required tool: $t"
done
command -v gpg >/dev/null 2>&1 || echo "note: gpg not found - installs will verify by SHA-256 only"

echo
echo "Done. Open a new shell (or: . $RCD/node.sh) then run: node-use"
