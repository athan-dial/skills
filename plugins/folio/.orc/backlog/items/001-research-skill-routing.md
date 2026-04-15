# Use proper research skills for Folio pipeline

**Priority**: p1
**Tags**: [folio, research, pipeline]
**Created**: 2026-04-14
**Origin**: First Folio white paper production run — research agents dispatched as generic general-purpose instead of using specialized skills

## Why

The Folio pipeline dispatches research agents for "from scratch" papers. Internal and external research have different optimal tools — using generic agents misses the specialized capabilities.

## Routing rule

- **`/research`** (parallel multi-agent) → **Montai internal** sources: Confluence, Slack, SharePoint, Jira
- **`/deep-research`** (Exa + NotebookLM RAG) → **external/public** sources: web, industry blogs, academic papers, company engineering blogs

## Suggested first step

Update the orchestrator's research dispatch logic (or document in the folio:prep sub-skill) to route by source type.

## Estimated scope

Focused — Claude direct
