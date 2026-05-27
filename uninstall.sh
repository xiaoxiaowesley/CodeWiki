#!/usr/bin/env bash
#
# CodeWiki uninstall — removes skill symlinks and global config.
#
# Usage: ./uninstall.sh
#
# What it does:
#   1. Removes global skill symlinks (all agent directories)
#   2. Removes project-local skill symlinks
#   3. Removes ~/.code-wiki/ global config directory
#   4. Optionally removes .env
#   5. Does NOT touch any generated wiki content in your projects
#
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}✅  $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️   $1${NC}"; }
error() { echo -e "${RED}❌  $1${NC}"; }

# ── Prerequisites ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.skills"

if [ ! -d "$SKILLS_DIR" ]; then
  error "Must run from CodeWiki project root (could not find .skills/ directory)"
  exit 1
fi

# ── remove_skills <target_dir> <label> ──────────────────────────────────────
# Removes symlinks for each skill found in .skills/ from the target directory.
remove_skills() {
  local target_dir="$1"
  local label="$2"
  local removed=0

  if [ ! -d "$target_dir" ]; then
    return
  fi

  for skill in "$SKILLS_DIR"/*/; do
    [ -d "$skill" ] || continue
    local skill_name link_path
    skill_name="$(basename "$skill")"
    link_path="$target_dir/$skill_name"

    if [ -L "$link_path" ]; then
      rm "$link_path"
      removed=$((removed + 1))
    fi
  done

  if [ $removed -gt 0 ]; then
    info "Removed $removed symlinks from $label"
  fi
}

# ── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         CodeWiki — Uninstall                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Remove global skill symlinks ────────────────────────────────────
echo "── Removing global skill symlinks ──"

GLOBAL_DIRS=(
  "$HOME/.gemini/skills"
  "$HOME/.codex/skills"
  "$HOME/.hermes/skills"
  "$HOME/.openclaw/skills"
  "$HOME/.copilot/skills"
  "$HOME/.trae/skills"
  "$HOME/.trae-cn/skills"
  "$HOME/.kiro/skills"
  "$HOME/.pi/agent/skills"
  "$HOME/.agents/skills"
  "$HOME/.qoder/skills"
)

for gdir in "${GLOBAL_DIRS[@]}"; do
  remove_skills "$gdir" "$gdir"
done

# ── Step 2: Remove project-local skill symlinks ─────────────────────────────
echo ""
echo "── Removing project-local skill symlinks ──"

LOCAL_DIRS=(
  ".cursor/skills"
  ".windsurf/skills"
  ".kiro/skills"
  ".agents/skills"
)

for agent_dir in "${LOCAL_DIRS[@]}"; do
  remove_skills "$SCRIPT_DIR/$agent_dir" "$agent_dir/"
done

# ── Step 3: Remove global config ────────────────────────────────────────────
echo ""
GLOBAL_CONFIG_DIR="$HOME/.code-wiki"

if [ -d "$GLOBAL_CONFIG_DIR" ]; then
  rm -rf "$GLOBAL_CONFIG_DIR"
  info "Removed global config directory ~/.code-wiki/"
else
  info "No global config found (already clean)"
fi

# ── Step 4: Optionally remove .env ──────────────────────────────────────────
echo ""
if [ -f "$SCRIPT_DIR/.env" ]; then
  echo -n "Remove local .env file? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm "$SCRIPT_DIR/.env"
    info "Removed .env"
  else
    info "Kept .env (no changes)"
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "───────────────────────────────────────────────────"
echo " Uninstall complete!"
echo ""
echo " What was removed:"
echo "   • Global skill symlinks (all agent directories)"
echo "   • Project-local skill symlinks"
echo "   • ~/.code-wiki/ global config"
echo ""
echo " What was NOT removed:"
echo "   • This CodeWiki repo itself"
echo "   • Any ./wiki/ directories in your code projects"
echo "   • Agent bootstrap files (AGENTS.md, CLAUDE.md, etc.)"
echo ""
echo " To fully remove CodeWiki, delete this directory:"
echo "   rm -rf $SCRIPT_DIR"
echo "───────────────────────────────────────────────────"
echo ""
