# Changelog

All notable changes to the `orc` plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Pre-1.0 policy:** breaking changes ship as MINOR bumps (and are called out under **Breaking** below). Post-1.0, breaking changes will require a MAJOR bump.

## [Unreleased]

## [0.6.0] — 2026-04-24

### Added
- `skills/plan/` — new `orc:plan` skill. Grill-me-style interview producing dispatch-ready `.orc/plans/<slug>/` directories in the new `orc-plan/1` format. Forces explicit per-PR file ownership at plan time so dispatch can refuse colliding waves before executing.
- `skills/dispatch/scripts/cursor-task-iso.sh` — HOME-isolated cursor-agent dispatcher. Per-job throwaway `$HOME` (seeded with two small files + `~/Library` symlink) sidesteps the `~/.cursor/cli-config.json.tmp` rename race that capped legacy parallelism at ~3. Empirically validated 8/8 parallel with zero races.
- `skills/dispatch/scripts/validate-plan.sh` — schema + invariants validator for `orc-plan/1`. Refuses plans where two tracks in the same wave list the same file in `expected_files` (the largest historical source of dispatch-time merge conflicts).
- `skills/dispatch/scripts/verify-diff.sh` — per-PR diff verifier. Detects empty diff (worker reported success without writing) and scope drift (out-of-scope file edits).
- `commands/plan.md` — invokes the new `plan` skill.
- `skills/plan/references/format.md` + `skills/plan/assets/prompt-template.txt` — orc-plan/1 format reference + per-PR prompt skeleton.

### Changed
- **`orc:dispatch` is now structured-plan-first.** Canonical input is an `.orc/plans/<slug>/` directory; freeform input triggers a soft refuse: dispatch generates an inferred plan, prints it, and offers `/orc:plan` (recommended), `--accept-guess`, or abort.
- **3-parallel-Cursor cap removed** when using `cursor-task-iso.sh`. Ceiling is now machine-bound (RAM/CPU) and API rate-limit-bound, not config-race-bound. Legacy `cursor-task.sh` retains the 3-parallel constraint.
- `skills/dispatch/references/routing.md` concurrency table updated; per-track parallelism + per-PR verification rules documented.
- `skills/dispatch/SKILL.md` — added Phase A (validate plan), Phase B (execute) with continuous-merge protocol; per-PR retry policy table; soft-refuse flow.

### Deprecated
- Legacy `cursor-task.sh` for new dispatches — keep for backward compat but prefer `cursor-task-iso.sh`.

### Notes
- `/orc:orchestrate` continues to alias `/orc:dispatch`.
- No auto-fire from `/orc:plan` to `/orc:dispatch`. Plan prints the slug; user invokes dispatch when ready.

## [0.5.0] — 2026-04-16

### Added
- `plugins/orc/site/` — bespoke dark-mode-default landing page for `athandial.com/skills/orc/`. Terminal-native aesthetic: monospace type, violet accent, staggered-wave ASCII animation. Includes install command, "What's here" cards linking into docs.
- `plugins/orc/justfile` — Zensical build + stage + prod-build recipes, matching the template contract (`bin/build-plugin-site orc` produces `dist/orc-site-0.5.0.tar.gz`).
- `docs/zensical.toml`, `docs/changelog.md`, `docs/stylesheets/orc.css` — complete Zensical doc-site config, auto-generated changelog, per-plugin CSS overrides.
- Transitional Hugo bundles at `athandial.com/skills/orc/` removed; the subsite is now served from release-asset tarballs, matching folio's pipeline.

## [0.4.0] — 2026-04-15

### Changed
- Monorepo milestone (no orc code changes). Shipped the plugin-subsite template system (template scaffold under `plugins/`) + shared cohesion artifacts at `shared/` (tokens.css, header-strip.html), matrix CI workflow at `.github/workflows/build-plugin-sites.yml`, and three generators at `bin/` (`new-plugin`, `build-plugin-site`, `gen-commands-doc`). Site repo rewired to consume release-asset tarballs instead of Hugo bundles. Next (stage 3): instantiate the template for orc and cut over the transitional Hugo bundles for `athandial.com/skills/orc/`.

## [0.3.1] — 2026-04-15

### Changed
- Internal: unified handoff state directory on `.orc/` (was `.orchestrate/`). All handoff artifacts (`HANDOFF.md`, `state.json`, `AUTO-RESUME.txt`, `tasks.json`) now live alongside `.orc/backlog/` and `.orc/plans/` in a single per-repo state dir. Updated `handoff/` scripts and `SKILL.md` accordingly. Existing `.orchestrate/` dirs in user repos are not auto-migrated — `checkpoint.sh` will simply start writing to `.orc/` next run.
- Refreshed stale `orc:plan` references to `orc:orchestrate` across SKILL.md frontmatter descriptions (all seven skills), `install.sh` banner, `CLAUDE.md`, and the `orchestrate/` prose that still pointed at the pre-0.2 command name. Also corrected `orchestrate/SKILL.md`'s "Part of the orc system" line which still listed the pre-consolidation names `orc:add / orc:list / orc:pick` (rolled into `orc:backlog` in 0.1.0).

## [0.3.0] — 2026-04-15

### Added
- `plugins/orc/docs/` — source for the public docs surface at <https://athandial.com/skills/orc/>. Page bundle with `_index.md`, `quickstart.md`, `architecture.md`. The companion site auto-generates `commands.md` (from `commands/*.md` frontmatter) and `changelog.md` (from this file) at build time.

### Changed
- `README.md` rewritten to reflect the current `/orc:*` command surface (was still referencing the pre-0.2 names like `orc:plan`, `orc:add`, `orc:list`). Now points to the docs site as the source of truth for everything beyond install + command list.

## [0.2.0] — 2026-04-15

### Added
- Seven `/orc:*` slash command wrappers in `plugins/orc/commands/` — `orchestrate`, `backlog`, `status`, `scope`, `recap`, `handoff`, `autoresearch`. Makes orc skills tab-completable as first-class slash commands instead of Skill-tool-only.

### Changed
- **Breaking:** renamed the `orchestrate` skill → `dispatch` (and its dir `plugins/orc/skills/orchestrate/` → `plugins/orc/skills/dispatch/`). Invoke as `/orc:dispatch`. `/orc:orchestrate` remains as an alias for compatibility.

## [0.1.0] — 2026-04-14

### Added
- Initial plugin release, migrated from standalone `fl65inc/orc` repo into the `athan-dial/skills` monorepo.
- Skills: `orchestrate` (then named `plan`), `backlog`, `status`, `scope`, `recap`, `handoff`, `autoresearch`.
- Markdown-table renderers for `backlog` and `status` (replaced prior ANSI/TUI machinery).

### Fixed
- `marketplace.json` schema: `name` no longer contains `/`; `owner` is an object.
- `plugin.json` schema: `author` is an object.

---

## Bump rules (self-reference)

| Bump | When |
|---|---|
| PATCH | Docs, copy, internal refactors, script fixes, no user-visible behavior change. |
| MINOR | New commands / skills / agents; backwards-compatible capability additions. Pre-1.0: also accepts breaking changes (flagged **Breaking**). |
| MAJOR | Post-1.0 only: removed/renamed user-facing commands, changed input/output contracts, reshaped state files. |

Default to PATCH. Bundle unreleased changes into a single bump rather than bumping per-commit.
