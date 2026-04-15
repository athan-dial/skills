# Failure Modes Reference

## Gate Failures

### Gate A: Canonical Input Completeness
**Trigger**: Required input files missing or still placeholder content after prep.

**Symptoms**:
- `validate_inputs.py` reports MISSING or PLACEHOLDER errors

**Repair**:
1. Check if raw materials were provided — if not, the user needs to supply more context
2. Re-run the prep stage with additional guidance
3. Manually edit the sparse input files and re-validate

---

### Gate B: Plan Completeness
**Trigger**: Planning artifacts incomplete or structurally invalid.

**Symptoms**:
- Missing outline sections
- Claims with no support_level assigned
- Empty literature or figure plans

**Repair**:
1. Re-run the planning stage
2. If the idea is too vague, return to prep and strengthen idea.md

---

### Gate C: Evidence Integrity
**Trigger**: Claims without evidence backing.

**Symptoms**:
- `build_claim_ledger.py` reports unsupported or untraced claims

**Repair**:
1. Remove or soften the unsupported claim
2. Add evidence source to experimental_log.md and re-map
3. Downgrade the claim from quantitative to qualitative

---

### Gate D: Citation Integrity
**Trigger**: Unverified, duplicate, or phantom citations.

**Symptoms**:
- `verify_citations.py` reports unverified or duplicate keys
- Citations in draft not in refs.bib

**Repair**:
1. Verify the citation through DOI lookup or search
2. Remove unverifiable citations from the pool
3. Regenerate refs.bib from the cleaned pool

---

### Gate E: Artifact Integrity
**Trigger**: Figures or tables referenced in draft don't exist.

**Symptoms**:
- `check_artifacts.py` reports missing figure files or unmatched \ref{} targets

**Repair**:
1. Generate the missing figure
2. Remove the reference from the draft
3. Update captions.json to reflect actual state

---

### Gate F: Rendering Integrity
**Trigger**: LaTeX structural errors.

**Symptoms**:
- Missing \begin{document} or \end{document}
- Unbalanced environments
- Missing \documentclass

**Repair**:
1. Fix the specific LaTeX structural issue
2. Re-run `check_artifacts.py` to verify
3. If using a template, ensure it's in the workspace

---

### Gate G: Refinement Integrity
**Trigger**: Review score decreased after revision.

**Symptoms**:
- Post-revision scorecard.json overall score < pre-revision score

**Repair**:
- Automatic: skill reverts to pre-revision draft
- Manual: review the revision diff to understand what degraded

---

### Gate IP: Redline Safety
**Trigger**: `scan_redlines.py` flags content against `ip_policy.json`.

**Symptoms**:
- Forbidden terms in draft

**Repair**:
- Redact terms, add to exceptions, or remove content

---

### Gate H: Hostile Review
**Trigger**: During white paper or hybrid review.

**Symptoms**:
- Critical external-readiness issues

**Repair**:
- Address logical gaps, soften claims, add disclaimers

---

### Routing Confidence
**Trigger**: `route_mode.py` reports confidence below 0.5.

**Symptoms**:
- Ambiguous materials mix

**Repair**:
- User manually selects mode via override

---

## Common Problems

### "pdflatex not found"
Install TeX Live or MacTeX. The skill degrades gracefully — you still get the LaTeX source package.

### "Workspace already exists"
The skill detects existing workspaces and offers to resume. If you want a fresh start, remove or rename the existing workspace directory.

### "Citation could not be verified"
The skill blocks unverified citations from entering the manuscript. Either:
- Find a DOI or URL confirming the paper exists
- Remove the citation and find an alternative
- Mark it as unverified with explicit user acknowledgment

### Review loop exceeded 3 rounds
The skill caps review-repair at 3 rounds and selects the best-scoring version. If quality is still unsatisfactory, manually edit the draft and re-run the review stage.
