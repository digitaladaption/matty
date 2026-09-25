#!/usr/bin/env bash
# Install the harness into a target project.
#   ./install.sh /path/to/project          # skip files that already exist
#   ./install.sh /path/to/project --force  # overwrite existing files
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${1:?usage: install.sh <project-dir> [--force]}"
force="${2:-}"

[[ -d "$target" ]] || { echo "not a directory: $target" >&2; exit 1; }
target="$(cd "$target" && pwd)"

copy() {
  local rel="$1" dest="$target/$1"
  if [[ -e "$dest" && "$force" != "--force" ]]; then
    echo "skip   $rel (exists)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src/$rel" "$dest"
  echo "write  $rel"
}

cd "$src"
while IFS= read -r f; do
  copy "${f#./}"
done < <(find ./.claude -type f -not -path './.claude/memory/*')

copy CLAUDE.md
chmod +x "$target"/.claude/hooks/*.sh

# Session memory is personal by default. Delete this line from the project's
# .gitignore to share it (e.g. so cloud sessions keep it between runs).
if ! grep -qxF '.claude/memory/' "$target/.gitignore" 2>/dev/null; then
  echo '.claude/memory/' >>"$target/.gitignore"
  echo "write  .gitignore (+ .claude/memory/)"
fi

echo "Harness installed into $target"
