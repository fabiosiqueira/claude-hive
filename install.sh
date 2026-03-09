#!/usr/bin/env bash
# install.sh — Sync hive plugin from repo to all Claude Code install locations
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_JSON="$REPO_DIR/.claude-plugin/plugin.json"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local-desktop-app-uploads/hive"
CACHE_BASE="$HOME/.claude/plugins/cache/local-desktop-app-uploads/hive"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

# --- Read version from plugin.json ---
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 required" >&2; exit 1
fi

VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])")
echo "Hive $VERSION"

# --- Sync to marketplace (installPath) ---
echo "→ marketplace: $MARKETPLACE_DIR"
mkdir -p "$MARKETPLACE_DIR"
rsync -a --delete \
  --exclude='.git' \
  --exclude='.hive' \
  --exclude='install.sh' \
  "$REPO_DIR/" "$MARKETPLACE_DIR/"

# --- Sync to versioned cache ---
CACHE_DIR="$CACHE_BASE/$VERSION"
echo "→ cache:       $CACHE_DIR"
mkdir -p "$CACHE_DIR"
rsync -a --delete \
  --exclude='.git' \
  --exclude='.hive' \
  --exclude='install.sh' \
  "$REPO_DIR/" "$CACHE_DIR/"

# --- Remove old cache versions ---
for dir in "$CACHE_BASE"/*/; do
  [[ -d "$dir" ]] || continue
  dir_version=$(basename "$dir")
  if [[ "$dir_version" != "$VERSION" ]]; then
    echo "→ removing old cache: $dir_version"
    rm -rf "$dir"
  fi
done

# --- Update installed_plugins.json ---
echo "→ installed_plugins.json: version → $VERSION"
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
python3 - <<PYEOF
import json, sys

path = "$INSTALLED_PLUGINS"
with open(path) as f:
    data = json.load(f)

key = "hive@local-desktop-app-uploads"
if key not in data["plugins"]:
    print(f"ERROR: {key} not found in installed_plugins.json", file=sys.stderr)
    sys.exit(1)

data["plugins"][key][0]["version"] = "$VERSION"
data["plugins"][key][0]["lastUpdated"] = "$UPDATED_AT"

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

echo "Done. Restart Claude Code to load the new version."
