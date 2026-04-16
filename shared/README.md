# shared/

Cohesion artifacts imported by every plugin subsite AND by the parent Hugo
theme at athandial.com. Keeps the three tiers (homepage → plugin landings →
plugin docs) feeling like one product even though they're built by three
different tools.

## Contents

| File | Purpose | Consumed by |
|---|---|---|
| `tokens.css` | CSS custom properties (palette, type, spacing, shadows, transitions). ~80 lines. Light + dark mode. | Every plugin landing (`site/`), every plugin docs (`docs/stylesheets/plugin.css` extends), parent Hugo theme (injected via custom CSS asset). |
| `header-strip.html` | "← athandial.com / skills / <plugin>" breadcrumb + theme-toggle. Substituted at build time into every plugin's `site/index.html` at the `<!-- HEADER_STRIP -->` marker. | `bin/build-plugin-site` at prod-build. |
| `README.md` | This file. | Humans. |

## Override rules

**Plugin authors MAY:**
- Extend tokens via a per-plugin `styles.css` (e.g. folio redefines `--color-bg` to parchment, `--font-serif` to Libre Baskerville).
- Customize `.header-strip` appearance for brand fit — just don't remove the breadcrumb links or the theme toggle.
- Add tokens their plugin needs but the shared set doesn't define (e.g. `--color-brand-accent`). Prefix with the plugin name to avoid collisions.

**Plugin authors MUST NOT:**
- Delete or rename existing tokens.
- Hardcode colors/spacing/type outside the token system (makes cohesion updates impossible).
- Change the DOM structure of `header-strip.html` (breaks the build-time substitution).

## When to update shared/

Touch these files when:
- The parent site's visual language changes (rare — this is a stable contract).
- You add a new token that most plugins would benefit from.

Don't touch these files for plugin-specific needs. If only one plugin needs a thing, it goes in that plugin's `styles.css`.

## Sync to parent Hugo site

The parent site at `~/Github/athan-dial.github.io/` symlinks or copies
`tokens.css` into its `assets/css/` at build time so Hugo layouts can
`{{ with resources.Get "css/tokens.css" }}...{{ end }}` it in. Sync mechanism
lives in the site repo's `scripts/` dir.
