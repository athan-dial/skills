# Worker Prompt Templates

Templates for prompting each worker type. Adapt to fit the task — these are starting structures, not rigid forms.

## Codex Prompt

Codex reads the repo itself — point to paths, don't embed content.

```
You are working in [repo name] at: [absolute path]

## Context to load first
- [repo]/CLAUDE.md — hard rules for this repo
- [repo]/.mex/ROUTER.md — routing map (if present)
- [repo]/.mex/context/<domain>.md — [why this task needs it]

## Task
[Specific task description — what to build/change]

## Context
- Read [path/to/file.py] for the existing pattern
- Read [path/to/schema.py] for the data model
- [Any other files to read for context]

## Deliverable
- Create [path/to/new_file.py] with [description]
- Modify [path/to/existing.py] to [change description]

## Constraints
- Follow the pattern in [path/to/example.py]
- Do not modify files outside the deliverable list
- [Project-specific: type hints, test conventions, etc.]
```

## Cursor Prompt

Cursor runs headlessly with full tool access. Good for focused, single-file work.

```
You are working in [repo/vault] at: [absolute path]

## Task
[Specific task description]

## Context
[Project context, relevant file paths to read]

## Deliverable
[Exact output — file path, format, content structure]

## Constraints
- Only modify files specified in the deliverable
- Do not call any APIs or MCP servers
- [Project-specific constraints]
```

## Claude Subagent Prompt

Use Agent() with appropriate subagent_type. Full MCP access available. For file-change isolation, use `isolation="worktree"`.

```
[Context about the project and what we're doing]

## Task
[What to do — search, research, read, or operate via MCP]

## Deliverable
[What to report back — findings, summary, or actions taken]

## Constraints
- [Scope limits]
- Report findings concisely — under [N] words
```

## Prompt Quality Checklist

Before dispatching any prompt, verify:

- [ ] Task is specific enough that a developer seeing it for the first time could execute it
- [ ] All file paths are absolute, not relative
- [ ] An example file is referenced when a pattern must be followed
- [ ] Exclusions are explicit ("do NOT modify X")
- [ ] Expected output format is clear
