# Getting Started

This guide covers installing Folio, verifying the install, and running your first manuscript workflow.

---

## Prerequisites

- **Claude Code** — Folio runs as a Claude Code skill pack
- **Python 3.10+** — required for validation and prep scripts (stdlib only; no pip installs needed)
- **pdflatex + bibtex** — optional, only needed for final PDF compilation

### Install LaTeX (optional)

If you want compiled PDF output, install a TeX distribution:

**macOS:**
```bash
brew install --cask mactex-no-gui
```

**Ubuntu / Debian:**
```bash
sudo apt-get install texlive-full
```

If LaTeX is not available, Folio degrades gracefully — it delivers the LaTeX source bundle without compiling a PDF.

---

## Install the Skill Pack

### Option A: Symlink (recommended for development)

```bash
git clone https://github.com/athan-dial/folio.git
ln -s "$(pwd)/folio" ~/.claude/skills/folio
```

Updates apply immediately after `git pull` — no re-copy needed.

### Option B: Copy into skills directory

```bash
git clone https://github.com/athan-dial/folio.git
cp -r folio ~/.claude/skills/folio
```

After pulling updates, re-copy to apply changes.

---

## Verify Installation

Open Claude Code and run:

```
/folio
```

Folio should prompt for your paper idea and materials path. If it doesn't respond, confirm the skills directory path in your Claude Code configuration.

---

## Updating

```bash
cd /path/to/folio
git pull
```

---

## First Invocation

Folio accepts an optional idea and materials path as inline arguments:

```
/folio [idea] [materials_path]
```

Both are optional — Folio will prompt interactively for anything not provided.

**Examples:**

```
/folio
```
Starts with interactive prompts for everything.

```
/folio "Benchmarking LLM routing strategies for enterprise workloads" ~/research/llm-routing/
```
Passes the idea and materials path directly; Folio skips those prompts.

---

## What to expect

After invocation, Folio walks you through these stages:

1. **Stage 0 — Initialize:** Folio collects your idea, audience, thesis, constraints, and optional venue. It creates a `workspace/` directory with canonical subdirectories and writes `intent.json`.

2. **Stage 1 — Prep:** Your raw materials are scanned, classified, and normalized into structured input artifacts (`idea.md`, `experimental_log.md`, `venue_profile.md`, etc.). Scripts run to classify materials and recommend a mode.

3. **Checkpoint 1:** Folio shows you what was synthesized versus copied verbatim, any gaps, and its mode recommendation. **You confirm before proceeding.**

4. **Routing checkpoint:** Folio presents `route.json` — recommended mode and confidence. You accept or override.

5. **Mode-specific stages (2–5):** Planning, drafting, and review stages run on the branch you confirmed. See the [Workflow Overview](workflow-overview.md) for details.

6. **Checkpoint 3 + Export:** After review, Folio pauses for final approval, then packages and exports your manuscript.

---

## Standalone Commands

You can run individual stages independently:

```
# Just initialize a workspace
/folio:init

# Run prep on an existing workspace
/folio:prep workspace/

# Check status
/folio:status workspace/
```

Each command picks up where the workspace left off. See the [Command Reference](../reference/commands.md) for the full list and entry conditions.

---

!!! tip "Resuming a workspace"
    If a session is interrupted, re-invoke `/folio` with your workspace path. Folio reads `logs/checkpoints.md` and offers to resume from where you left off.

!!! warning "IP policy"
    If your organization has sensitive terms or internal code names, create an `ip_policy.json` in your workspace before drafting begins. See [IP Policy](../reference/ip-policy.md) for configuration details.
