#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN_DIR="$(cd "$SITE_DIR/.." && pwd)"
CONTENT_DIR="$SITE_DIR/content"
RESULTS_DIR="$GEN_DIR/results"
TRANSFORM="$SITE_DIR/transform_math.py"
PORT="${PORT:-3264}"

if [[ ! -d "$SITE_DIR/themes/MATbook" ]]; then
  bash "$SITE_DIR/setup_theme.sh"
fi

sync_content() {
  echo "Syncing results into site/content/ ..."

  local results_content="$CONTENT_DIR/results"
  rm -rf "$results_content"
  mkdir -p "$results_content"

  cat > "$results_content/_index.md" <<'EOF'
+++
title = "results"
sort_by = "weight"
weight = 1
+++
EOF

  if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "No results directory found at $RESULTS_DIR"
    return
  fi

  local weight=1
  for prob_dir in "$RESULTS_DIR"/*/; do
    [[ -d "$prob_dir" ]] || continue
    local prob_name
    prob_name="$(basename "$prob_dir")"

    for md in "$prob_dir"/*.md; do
      [[ -f "$md" ]] || continue
      local stem
      stem="$(basename "$md" .md)"
      local page_title="${prob_name} — ${stem}"
      local dest="$results_content/${prob_name}_${stem}.md"
      local ts
      ts="$(date -r "$md" +%Y-%m-%d 2>/dev/null || echo "2026-01-01")"

      local tmp="$dest.tmp"
      python3 "$TRANSFORM" "$md" "$tmp"

      {
        printf '+++\ntitle = "%s"\ndate = %s\nweight = %d\n' \
          "$page_title" "$ts" "$weight"
        printf '[extra]\nmath = true\n+++\n\n'
        cat "$tmp"
      } > "$dest"
      rm -f "$tmp"
      weight=$((weight + 1))
    done
  done

  echo "Done. Synced $((weight - 1)) page(s)."
}

sync_content

echo ""
echo "Starting zola serve on http://localhost:${PORT} ..."
echo ""
cd "$SITE_DIR"
exec zola serve --port "$PORT" --interface 127.0.0.1
