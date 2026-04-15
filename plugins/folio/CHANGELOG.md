# Changelog

All notable changes to the `folio` plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Pre-1.0 policy:** breaking changes ship as MINOR bumps (and are called out under **Breaking** below). Post-1.0, breaking changes will require a MAJOR bump.

## [Unreleased]

## [0.2.0] — 2026-04-15

### Added
- Migrated from the standalone `athan-dial/paperorchestra` repo into the `athan-dial/skills` monorepo as `plugins/folio/`. Brings the full plugin surface into the marketplace:
  - `docs/` — Zensical source for the Folio doc site (guides, reference, modes, stylesheets).
  - `site/` — hand-crafted editorial landing page (`index.html` with bespoke CSS).
  - `justfile` — `docs-build` / `docs-stage` / `docs-serve` / `site-serve` recipes.
  - `scripts/`, `templates/`, `references/`, `skills/` — manuscript pipeline assets (preserved from paperorchestra).
- `plugin.json` now pinned to `0.2.0` to reflect the monorepo migration as a material release (was `0.1.0` in the thin pre-migration shell).

### Changed
- Justfile default `ZENSICAL_BIN` now points at the repo-local venv (`../../tools/venv/bin/zensical`, pinned to `zensical==0.0.33` in `skills/tools/requirements.txt`) instead of assuming `zensical` is on `PATH`. No more "borrowed from crosswalk venv" note.
- Doc examples throughout `docs/` and `references/` now prefix commands with `cd plugins/folio && ...` so they remain runnable when invoked from the skills repo root.

### Removed
- Paperorchestra's standalone repo is archived after this release; source history lives there for reference. No user-visible removals from folio itself.

---

## Bump rules (self-reference)

| Bump | When |
|---|---|
| PATCH | Docs, copy, internal refactors, script fixes, no user-visible behavior change. |
| MINOR | New commands / skills / agents; backwards-compatible capability additions. Pre-1.0: also accepts breaking changes (flagged **Breaking**). |
| MAJOR | Post-1.0 only: removed/renamed user-facing commands, changed input/output contracts, reshaped state files. |

Default to PATCH. Bundle unreleased changes into a single bump rather than bumping per-commit.
