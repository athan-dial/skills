# Bin Scripts

- `bin/new-plugin <plugin-name> [--tagline "..."] [--description "..."]`
- Copies `plugins/_template` into `plugins/<plugin-name>/`, substitutes the scaffold placeholders, and creates `.claude-plugin/plugin.json`.
- Rejects invalid names and existing plugin directories.

- `bin/gen-commands-doc <plugin-name>`
- Reads `plugins/<plugin-name>/commands/*.md` frontmatter and rewrites `docs/reference/commands.md`.
- If `commands/` is missing, prints `no commands/ dir, skipping` and exits successfully.

- `bin/build-plugin-site <plugin-name>`
- Runs `bin/gen-commands-doc`, injects `shared/header-strip.html` into the landing page on a temporary working copy, exports `SITE_URL`, and calls `just -C plugins/<plugin-name>/ prod-build`.
- Packages `plugins/<plugin-name>/site/` as `dist/<plugin-name>-site-<version>.tar.gz`.

- All scripts resolve paths relative to this repo checkout.
- Keep them executable with `chmod +x bin/new-plugin bin/gen-commands-doc bin/build-plugin-site`.
