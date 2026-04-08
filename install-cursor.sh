#!/usr/bin/env bash
#
# Install org-skills into Cursor's skills directory.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cloud-bulldozer/org-skills/main/install-cursor.sh | bash
#

set -euo pipefail

REPO="cloud-bulldozer/org-skills"
BRANCH="main"
SKILLS_DIR="$HOME/.cursor/skills"
TEMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

echo "Installing org-skills into Cursor..."

echo "  Cloning $REPO..."
git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$TEMP_DIR" 2>/dev/null

mkdir -p "$SKILLS_DIR"

for skill_dir in "$TEMP_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")

  # Resolve the source directory: if SKILL.md is a symlink, use the
  # directory it points to so that sibling docs/scripts/assets are included.
  if [ -L "$skill_dir/SKILL.md" ]; then
    src_file=$(cd "$TEMP_DIR" && realpath "$skill_dir/SKILL.md" 2>/dev/null || readlink -f "$skill_dir/SKILL.md")
    src_dir=$(dirname "$src_file")
  else
    src_dir="$skill_dir"
  fi

  if [ -f "$src_dir/SKILL.md" ]; then
    rm -rf "$SKILLS_DIR/$skill_name"
    cp -R "$src_dir" "$SKILLS_DIR/$skill_name"
    echo "  Installed: $skill_name"
  fi
done

echo ""
echo "Done! Skills installed to $SKILLS_DIR"
echo "Restart Cursor to pick up the new skills."
