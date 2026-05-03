---
name: dispatch
description: "Use at the start of ANY user message in the tmux window named 'manager' (the claude dispatch orchestrator session) — every task spawns a fresh ephemeral tmux window (`task:<slug>`). No folder classification, no depth triage. Strict: no inline subagent, no anchor reuse. Optional `@(smartast|metagap|life|metaenhance)` prefix sets cwd; default = $HOME. Optional `overnight:` prefix → opus + automode. Handles meta-intents: list, kill, reattach, show last, compact, cancel, redirect. Do NOT use in any other tmux window."
---

# Dispatch Orchestrator Skill

**Strict mode: every task → fresh `task:<slug>` ephemeral tmux window. No
inline path, no anchor reuse, no busy-check, no folder/depth classification.
Single dispatch shape.**

Reference files (read when needed):
- `references/brief-template.md` — task brief markdown template

Scripts (call via Bash tool):
- `scripts/ensure-anchor.sh <name> <cwd> [--overnight]`
- `scripts/dispatch-to-window.sh <name> --paste-file <path>|--text <str>`
- `scripts/wait-for-claude-ready.sh <name> [--timeout N] [--trace]`

State files:
- `~/.claude/dispatch/log` — JSONL audit
- `~/.claude/dispatch/last-dispatch.json` — last dispatch record (for redirects)
- `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md` — per-task briefs

---

## Flow (follow in strict order)

### Step 1 — Meta-intent check

Read user message. Match patterns (case-insensitive):

| Pattern | Action |
|---|---|
| `^(list\|ls\|status\|what'?s running)` | `tmux list-windows -t claude -F '#{window_name} #{window_index}'` + tail `~/.claude/dispatch/log` last 10 lines. Print result. Exit skill. |
| `^kill task:(\S+)` | `tmux kill-window -t claude:task:<slug>`. Print confirmation. Exit skill. |
| `^reattach (\S+)` | Print: `tmux attach -t claude \; select-window -t <name>`. Exit skill. |
| `^show last` | `cat ~/.claude/dispatch/last-dispatch.json`. Exit skill. |
| `^compact` | Run `/compact` in current session. Exit skill. |
| `^cancel` | Print "dispatch cancelled." Exit skill. |
| `^(actually\|wait\|switch to\|change to\|instead\|redirect\|reroute)` | Redirect: read `last-dispatch.json`, kill prior `task:<slug>` window via `tmux kill-window -t claude:<window>` (every dispatch is ephemeral), then proceed from Step 2 with combined prompt. Tag reasoning line "redirect:". |

If no match → continue to Step 2.

### Step 2 — Overnight + folder prefix

1. Strip leading `overnight:` (case-insensitive, after whitespace). If matched:
   - `OVERNIGHT=true`
   - Print: `[dispatch] overnight mode → opus + automode`
2. Strip leading `@(smartast|metagap|life|metaenhance)`. Map prefix → cwd:

   | Prefix | cwd |
   |---|---|
   | `@smartast` | `$HOME/lytech_smartast` |
   | `@metagap` | `$HOME/MetaGap` |
   | `@life` | `$HOME/Life` |
   | `@metaenhance` | `$HOME` |
   | (none) | `$HOME` |

3. Print: `cwd: <path>`.

No regex inference, no LLM guessing, no interactive folder confirm. Typo in
prefix (e.g. `@smaartast`) silently falls through to `$HOME` — user sees the
mismatch on the printed `cwd:` line.

### Step 3 — Slug derive

First 4 significant words of stripped prompt (drop stopwords: the/a/an/to/in/
for/with/and/of). Lowercase, hyphen-join.

Collision check: if `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md` exists, append
`-s<seconds>`. If still collides, append `-r$(openssl rand -hex 3)`.

### Step 4 — Brief write

Read `references/brief-template.md`. Fill placeholders:

- `FOLDER_PLACEHOLDER` → cwd
- `SESSION_SHAPE_PLACEHOLDER` → `ephemeral:task:<slug>`
- `DEPTH_PLACEHOLDER` → `complex` (constant — every task is complex)
- `CREATED_PLACEHOLDER` → `date -Iseconds`
- `SLUG_PLACEHOLDER` → derived slug
- `TITLE_PLACEHOLDER` → Title-cased slug
- `GOAL_PLACEHOLDER` → tightened one-paragraph summary of prompt
- `CRITERIA_PLACEHOLDER` → 2–3 measurable bullets inferred from prompt
- `RESEARCH_PLACEHOLDER` → `yes — <skill rec>` or `no`
- `ORIGINAL_PROMPT_PLACEHOLDER` → verbatim user prompt
- `DISPATCH_CMD_PLACEHOLDER` → tmux paste-buffer command from Step 5

Write to `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md`. No interactive confirm —
strict mode: brief auto-generated, dispatched immediately.

### Step 5 — Spawn + dispatch (always ephemeral)

1. Spawn fresh window:
   - `OVERNIGHT=true` → `scripts/ensure-anchor.sh task:<slug> <cwd> --overnight`
   - `OVERNIGHT=false` → `scripts/ensure-anchor.sh task:<slug> <cwd>`

   No `--lazy`, no busy-check, no anchor lookup. Always new.

2. Write iron-fist dispatch message to a temp file:

   ```text
   Read ~/.claude/tasks/<brief>.md.

   This task is COMPLEX — follow the iron-fist protocol:

   1. Enter plan mode immediately via the EnterPlanMode tool (load schema with
      ToolSearch first if not in tools list).
   2. Invoke superpowers:brainstorming skill to clarify intent and surface edge
      cases.
   3. Invoke superpowers:writing-plans skill to draft an implementation plan.
   4. Present the plan via ExitPlanMode and wait for user approval before any
      edit.

   Work in: <cwd>. Target file is <one-line hint from brief Goal/Success
   Criteria, or "see brief">.
   ```

   Substitute `<brief>`, `<cwd>` literally. "Target file" hint: scan brief
   Goal/Success Criteria for a file path; fall back to "see brief".

3. `scripts/dispatch-to-window.sh task:<slug> --paste-file <tempfile>`.

   Per `~/.claude/rules/learning-dispatch-script-exit1.md`: ignore exit 1,
   verify delivery via `tmux capture-pane -p -t claude:task:<slug> | tail -20`.

### Step 6 — Audit + print

Append JSONL line to `~/.claude/dispatch/log`:
```json
{"ts":"<ISO>","slug":"<slug>","folder":"<cwd>","shape":"ephemeral:task:<slug>","window":"task:<slug>","brief":"<path>","exit":0}
```

Write `~/.claude/dispatch/last-dispatch.json` with the same fields (full json,
not JSONL).

Print:
```
task <slug> dispatched → claude:task:<slug>
attach: tmux attach -t claude \; select-window -t task:<slug>
brief:  ~/.claude/tasks/<file>.md
```
