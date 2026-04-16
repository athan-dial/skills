---
title: "Changelog"
weight: 50
---

All notable changes to the `orc` plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Pre-1.0 policy:** breaking changes ship as MINOR bumps (and are called out under **Breaking** below). Post-1.0, breaking changes will require a MAJOR bump.

## [Unreleased]

## [0.4.0] — 2026-04-15

### Changed
- Monorepo milestone (no orc code changes). Shipped the plugin-subsite template system (template scaffold under `plugins/`) + shared cohesion artifacts at `shared/` (tokens.css, header-strip.html), matrix CI workflow at `.github/workflows/build-plugin-sites.yml`, and three generators at `bin/` (`new-plugin`, `build-plugin-site`, `gen-commands-doc`). Site repo rewired to consume release-asset tarballs instead of Hugo bundles. Next (stage 3): instantiate the template for orc and cut over the transitional Hugo bundles for `athandial.com/skills/orc/`.

## [0.3.1] — 2026-04-15

### Changed
- Internal: unified handoff state directory on `.orc/` (was `.orchestrate/`). All handoff artifacts (`HANDOFF.md`, `state.json`, `AUTO-RESUME.txt`, `tasks.json`) now live alongside `.orc/backlog/` and `.orc/plans/` in a single per-repo state dir. Existing `.orchestrate/` dirs in user repos are not auto-migrated — `checkpoint.sh` will simply start writing to `.orc/` next run.
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
- **Breaking:** renamed the `plan` skill → `orchestrate` (and its dir `plugins/orc/skills/plan/` → `plugins/orc/skills/orchestrate/`). Invoke as `/orc:orchestrate` instead of `/orc:plan`. Rationale: "plan" collides semantically with Claude-native plan mode (Shift+Tab) and reads as planning rather than multi-agent execution.

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
