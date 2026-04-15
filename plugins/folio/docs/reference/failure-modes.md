# Failure Modes

This reference covers every named gate failure in Folio, common runtime problems, and repair steps for each.

---

## Gate failures

Gates are deterministic quality checks that must pass before a stage exits. When a gate fails, Folio states which gate failed, lists the failing artifacts or checks, proposes concrete fixes, and asks whether to attempt auto-repair or pause for manual editing.

Blockers are logged in `logs/run_log.md`. All artifacts produced so far are preserved.

---

### Gate A: Input Completeness

**When it triggers:** `validate_inputs.py` reports `MISSING` or `PLACEHOLDER` errors.

**Typical symptoms:**
- Required input files are absent after prep
- A file exists but contains only placeholder text (under ~50 characters)

**Repair:**
1. Check whether raw materials were provided — if not, the user needs to supply more context
2. Re-run the prep stage with additional guidance
3. Manually edit the sparse input files (e.g., add content to `idea.md`) and re-run `validate_inputs.py`

---

### Gate B: Plan Completeness

**When it triggers:** Planning artifacts are incomplete or structurally invalid after Stage D2.

**Typical symptoms:**
- Missing outline sections for the venue type
- Claims in the ledger with no `support_level` assigned
- Empty `literature_plan.json` or `figure_plan.json`

**Repair:**
1. Re-run the planning stage
2. If the idea is too vague, return to prep and strengthen `idea.md` before replanning

---

### Gate C: Evidence Integrity

**When it triggers:** `build_claim_ledger.py` reports unsupported or untraced claims.

**Typical symptoms:**
- Claim `support_level` is `unsupported` without user acknowledgment
- Numerical claims have no `evidence_source`
- Unrecognized claim types

**Repair:**
1. Remove or soften the unsupported claim
2. Add evidence source to `experimental_log.md` and re-map the claim
3. Downgrade the claim from `quantitative` to `qualitative`
4. Explicitly acknowledge the unsupported claim and log the decision

---

### Gate D: Citation Integrity

**When it triggers:** `verify_citations.py` reports unverified, duplicate, or phantom citations.

**Typical symptoms:**
- Citations in `citation_pool.json` have `verified: false`
- Duplicate BibTeX keys in `refs.bib`
- Citations appear in the draft that are not in `refs.bib`

**Repair:**
1. Verify the citation through DOI lookup or search
2. Remove unverifiable citations from the pool
3. Regenerate `refs.bib` from the cleaned pool

!!! warning "No fabricated citations"
    Folio blocks unverified citations from entering the manuscript. Either find a DOI or URL confirming the paper exists, remove the citation and find an alternative, or mark it as unverified with explicit user acknowledgment.

---

### Gate E: Artifact Integrity

**When it triggers:** Figures or tables referenced in the draft do not exist.

**Typical symptoms:**
- `check_artifacts.py` reports missing figure files
- Unmatched `\ref{}` targets in the LaTeX draft

**Repair:**
1. Generate the missing figure
2. Remove the `\ref{}` from the draft if the figure will not be provided
3. Update `captions.json` to reflect the actual state

---

### Gate F: Rendering Integrity

**When it triggers:** LaTeX structural errors in `drafts/paper.tex`.

**Typical symptoms:**
- Missing `\begin{document}` or `\end{document}`
- Unbalanced LaTeX environments
- Missing `\documentclass`

**Repair:**
1. Fix the specific LaTeX structural issue
2. Re-run `check_artifacts.py` to verify
3. If using a LaTeX template, ensure `inputs/template.tex` is present in the workspace

---

### Gate G: Refinement Integrity

**When it triggers:** The `overall` score in `scorecard.json` decreases after a revision.

**Typical symptoms:**
- Post-revision `overall` score is lower than the pre-revision score

**Repair:**
- **Automatic:** Folio reverts to the pre-revision draft
- **Manual:** Review the revision diff to understand what degraded; address the root cause before attempting another round

!!! tip "Round limit"
    Folio caps review-repair at 3 rounds and retains the best-scoring version. If quality is still unsatisfactory after 3 rounds, manually edit the draft and re-run the review stage.

---

### Gate IP: Redline Safety

**When it triggers:** `scan_redlines.py` flags content against `ip_policy.json`.

**Typical symptoms:**
- Forbidden terms appear in draft files
- Sensitive metric patterns matched in prose

**Repair:**
1. Review `reviews/ip_safety_report.md` for the full list of violations with file paths and line numbers
2. Redact or rephrase the flagged terms
3. Add terms to `redline_exceptions` in `ip_policy.json` if they are intentionally public
4. Explicitly acknowledge the risk (must be logged in `logs/run_log.md`)

**Folio will not mark any review stage complete with unaddressed IP violations.**

See [IP Policy](ip-policy.md) for `ip_policy.json` configuration.

---

### Gate H: Hostile Review

**When it triggers:** White paper or hybrid review reveals critical external-readiness issues.

**Typical symptoms:**
- Logical gaps in the argument flow
- Claims without adequate framing or caveats
- Content that poses competitive or reputational risk if published

**Repair:**
1. Address logical gaps in the draft
2. Soften or caveat unsupported claims
3. Add disclaimers where appropriate
4. Re-run the review stage

---

### Routing Confidence

**When it triggers:** `route_mode.py` reports confidence below 0.5.

**Typical symptoms:**
- Materials mix is ambiguous (e.g., equal signals for narrative and empirical content)

**Repair:**
- Select a mode explicitly via the user override at the routing checkpoint
- Folio logs the override in `route.json` and `logs/checkpoints.md`

---

## Common problems

### "pdflatex not found"

Install a TeX distribution:

```bash
# macOS
brew install --cask mactex-no-gui

# Ubuntu / Debian
sudo apt-get install texlive-full
```

Folio degrades gracefully if LaTeX is absent — you still receive the full LaTeX source package.

---

### "Workspace already exists"

Folio detects existing workspaces and offers to resume from the last completed stage. If you want a fresh run, rename or remove the existing workspace directory before invoking Folio.

---

### "Citation could not be verified"

Folio blocks unverified citations. Options:

- Find a DOI or URL confirming the paper exists, update `citation_pool.json`, and re-run `verify_citations.py`
- Remove the citation and find an alternative
- Mark it as unverified with explicit user acknowledgment (logged)

---

### Review loop exceeded 3 rounds

Folio caps review-repair at 3 rounds. After the cap, it selects the best-scoring version and documents residual issues. If the result is still unsatisfactory:

1. Manually edit the draft outside the automated review loop
2. Re-run the review stage once more to re-score the edited draft
