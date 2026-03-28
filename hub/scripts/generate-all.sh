#!/usr/bin/env bash
# Régénère toutes les images du projet Quiz Buzzer Docs :
#   1. Diagrammes de flux (Mermaid → PNG)
#   2. Pages de couverture (HTML/CSS → PNG)
#
# Prérequis : @mermaid-js/mermaid-cli installé globalement (npm install -g @mermaid-js/mermaid-cli)
# Usage     : bash scripts/generate-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
PUPPETEER_CFG="$SCRIPT_DIR/puppeteer.config.json"

echo "=== 🔄 Génération des diagrammes de flux (Mermaid) ==="
for mmd in "$ROOT/diagrams"/*.mmd; do
  png="${mmd%.mmd}.png"
  echo "  → $(basename "$mmd")"
  mmdc -i "$mmd" -o "$png" --puppeteerConfigFile "$PUPPETEER_CFG" --theme forest
done
echo "✅ Diagrammes générés"

echo ""
echo "=== 🖼️  Génération des pages de couverture ==="
node "$SCRIPT_DIR/generate-covers.mjs"
echo "✅ Couvertures générées"

echo ""
echo "🎉 Toutes les images sont à jour dans diagrams/"
