# Folder classifier — keyword regex seeds

First match wins. Customize the sections below for your own projects.
Add one section per project; the final `meta` section is the catch-all fallback.

## proj-a → ~/proj-a

Matches (case-insensitive):
- `\.py\b` — Python file extension
- `proja|projectA` — project name(s)
- `<your-domain-keyword>` — domain terms unique to this project

## proj-b → ~/proj-b

Matches:
- `\.ts\b|\.tsx\b` — TypeScript file extension
- `projb|project-b` — project name(s)
- `<your-keywords>` — replace with project-specific terms

## meta → ~ (fallback)

Meta-work on the Claude/agent/session/dispatch system itself.
Anything that doesn't match a project section above falls here.

Signals: `claude skill|hook|settings\.json|CLAUDE\.md|tmux session|tmux window|dispatch|anchor|subagent|agent\b|orchestrat|research\b|planning\b`.
