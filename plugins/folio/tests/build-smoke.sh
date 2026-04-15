#!/usr/bin/env bash
# folio build smoke — verify docs build + stage without running the server.
# Exits 0 if docs/site/ and site/docs/ both exist with non-empty index.html.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$FOLIO_ROOT"

echo "→ just docs-build"
just docs-build > /dev/null

echo "→ just docs-stage"
just docs-stage > /dev/null

for path in docs/site/index.html site/index.html site/docs/index.html; do
  if [ ! -s "$path" ]; then
    echo "FAIL: $path missing or empty"
    exit 1
  fi
  echo "  ✓ $path ($(wc -c < "$path" | tr -d ' ') bytes)"
done

echo "✓ folio build smoke passed"
