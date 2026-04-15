#!/usr/bin/env bash
# Compile final LaTeX package and create submission bundle.
# Usage: compile_package.sh <workspace_path>
set -euo pipefail

WORKSPACE="${1:?Usage: compile_package.sh <workspace_path>}"
FINAL_DIR="$WORKSPACE/final"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['selected_mode'])" "$WORKSPACE/route.json" 2>/dev/null || echo 'research_paper')

if [ "$MODE" = "white_paper" ]; then
    python3 "$REPO_ROOT/scripts/package_exports.py" "$WORKSPACE"
    echo "OK: White paper package assembled (no LaTeX compilation needed)"
    exit 0
fi

# Verify final/paper.tex exists
if [ ! -f "$FINAL_DIR/paper.tex" ]; then
    echo "ERROR: $FINAL_DIR/paper.tex not found" >&2
    exit 1
fi

# Check for pdflatex
if ! command -v pdflatex &>/dev/null; then
    echo "WARNING: pdflatex not found on PATH — skipping PDF compilation"
    echo "  The LaTeX source package is ready at $FINAL_DIR/"
    echo "  Install TeX Live or MacTeX to enable PDF compilation."
    exit 0
fi

cd "$FINAL_DIR"

echo "==> Running pdflatex (pass 1)..."
pdflatex -interaction=nonstopmode paper.tex || {
    echo "ERROR: pdflatex pass 1 failed" >&2
    echo "  Check $FINAL_DIR/paper.log for details"
    exit 1
}

# Run bibtex if refs.bib exists
if [ -f "refs.bib" ]; then
    echo "==> Running bibtex..."
    bibtex paper || {
        echo "WARNING: bibtex had errors — continuing with remaining passes"
    }
fi

echo "==> Running pdflatex (pass 2)..."
pdflatex -interaction=nonstopmode paper.tex >/dev/null 2>&1

echo "==> Running pdflatex (pass 3)..."
pdflatex -interaction=nonstopmode paper.tex >/dev/null 2>&1

# Verify PDF was created
if [ -f "paper.pdf" ]; then
    echo "OK: PDF compiled successfully at $FINAL_DIR/paper.pdf"
else
    echo "ERROR: PDF was not produced" >&2
    exit 1
fi

# Create submission bundle
echo "==> Creating submission bundle..."
BUNDLE_FILES="paper.tex paper.pdf refs.bib"
[ -d "figures" ] && BUNDLE_FILES="$BUNDLE_FILES figures/"
[ -d "tables" ] && BUNDLE_FILES="$BUNDLE_FILES tables/"

# shellcheck disable=SC2086
zip -r submission_bundle.zip $BUNDLE_FILES 2>/dev/null || {
    echo "WARNING: zip not available — bundle not created"
    exit 0
}

echo "OK: Submission bundle at $FINAL_DIR/submission_bundle.zip"

if [ "$MODE" = "hybrid" ]; then
    python3 "$REPO_ROOT/scripts/package_exports.py" "$WORKSPACE"
else
    python3 "$REPO_ROOT/scripts/package_exports.py" "$WORKSPACE" 2>/dev/null || true
fi
