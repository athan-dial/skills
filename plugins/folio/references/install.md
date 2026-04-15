# Installation

## Prerequisites

- **Claude Code** — the skill runs as a Claude Code plugin
- **Python 3.10+** — for validation and prep scripts (stdlib only, no pip installs)
- **pdflatex + bibtex** — optional, for final PDF compilation

### Installing LaTeX (optional)

macOS:
```bash
brew install --cask mactex-no-gui
```

Ubuntu/Debian:
```bash
sudo apt-get install texlive-full
```

## Install the Skill Pack

### Option A: Clone and symlink

```bash
git clone https://github.com/athan-dial/folio.git
ln -s "$(pwd)/folio" ~/.claude/skills/folio
```

### Option B: Copy into skills directory

```bash
git clone https://github.com/athan-dial/folio.git
cp -r folio ~/.claude/skills/folio
```

## Verify Installation

In Claude Code, run:
```
/folio
```

The skill should prompt for your paper idea and materials path.

All sub-commands (`/folio:init`, `/folio:prep`, `/folio:plan`, `/folio:support`, `/folio:draft`, `/folio:review`, `/folio:export`, `/folio:status`) are auto-discovered from the `skills/` directory and become available as soon as the skill pack is installed.

## Updating

```bash
cd /path/to/folio
git pull
```

If you symlinked, updates apply immediately. If you copied, re-copy after pulling.
