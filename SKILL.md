---
name: dispatch
description: "Use at the start of ANY user message in the tmux window named 'meta' (the claude dispatch orchestrator session) — classifies target folder, triages task depth (quick/medium/complex), scaffolds a task brief when needed, dispatches to tmux anchor / ephemeral task window / inline subagent. Also handles meta-intents: list sessions, kill task, reattach, show last dispatch, compact, follow-up redirect ('actually switch to X'). Do NOT use in any other tmux window."
---

# Dispatch Orchestrator Skill

> **Customize before use:**
> - Edit `references/folder-map.md` to map your project names to their paths.
> - Set `DISPATCH_LAZY_ANCHORS` env var (comma-separated anchor names) for lazy-spawn support.
> - See the [README](README.md) for full configuration options.

Reference files (read when needed):
- `references/folder-map.md` — keyword→folder regex seeds
- `references/triage-cues.md` — quick/medium/complex thresholds
- `references/brief-template.md` — medium brief markdown template

Scripts (call via Bash tool):
- `scripts/ensure-anchor.sh <name> <cwd> [--lazy]`
- `scripts/dispatch-to-window.sh <name> --paste-file <path>|--text <str>`
- `scripts/lazy-anchor-registry.sh touch|age|list|remove <name>`
- `scripts/wait-for-claude-ready.sh <name> [--timeout N] [--trace]`

State files:
- `~/.claude/dispatch/anchors/<name>.last` — mtime = last dispatch
- `~/.claude/dispatch/anchors/spawn.lock` — flock mutex for lazy spawns
- `~/.claude/dispatch/log` — JSONL audit
- `~/.claude/dispatch/last-dispatch.json` — last dispatch record (for redirects)
- `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md` — per-task briefs

---

## Flow (follow in strict order)

### Step 1 — Meta-intent check

Read the user message. Match against these patterns (case-insensitive):

| Pattern | Action |
|---|---|
| `^(list\|ls\|status\|what'?s running)` | `tmux list-windows -t $TMUX_SESSION -F '#{window_name} #{window_index}'` + tail `~/.claude/dispatch/log` last 10 lines. Print result. Exit skill. |
| `^kill task:(\S+)` | `tmux kill-window -t $TMUX_SESSION:task:<slug>` + `scripts/lazy-anchor-registry.sh remove task:<slug>`. Print confirmation. Exit skill. |
| `^reattach (\S+)` | Print: `tmux attach -t $TMUX_SESSION \; select-window -t <name>`. Exit skill. |
| `^show last` | `cat ~/.claude/dispatch/last-dispatch.json`. Exit skill. |
| `^compact` | Run `/compact` in the current session. Exit skill. |
| `^cancel` | Print "dispatch cancelled." Exit skill. |
| `^(actually\|wait\|switch to\|change to\|instead\|redirect\|reroute)` | Follow-up redirect: read `last-dispatch.json`, re-classify folder+depth with combined context (previous target + new message), proceed from Step 2 with "redirect:" prefix in reasoning line. Optionally kill prior window if ephemeral. |

If no match → continue to Step 2.

### Step 2 — Folder classify

Read `references/folder-map.md`. Apply in order:

1. Explicit prefix: `@(<folder-name>)` in message → pick directly, skip reasoning.
   (Customize the recognized prefix list to match your own folder names.)
2. Keyword regex table — first section that matches wins.
3. LLM inference if no regex hit — one sentence.

Print: `pick: <folder>  reason: <one line>`

Folder → cwd mapping (defined in `references/folder-map.md`; examples):
- `meta` → `$HOME` (meta-work: agents, sessions, dispatch, hooks, claude config)
- `proj-a` → `$HOME/proj-a`
- `proj-b` → `$HOME/proj-b`

### Step 3 — Confirm folder

```
[y] accept  [1] meta  [2] proj-a  [3] proj-b  [4] other (type path)
> _
```

Wait for 1 char. If `4`, prompt for path; must exist or re-prompt. Re-print pick line after any override.
Customize this prompt menu to list your actual folder names.

### Step 4 — Triage depth

Read `references/triage-cues.md`. Classify: quick / medium / complex.

Inspect: `len(message)`, newline count, vocabulary, ends-with-`?`.

Print: `depth: <d>  reason: <cue>`

Override: accept `y` / `q` (quick) / `m` (medium) / `c` (complex).

Depth implications:
- quick → inline Agent in meta (no plan mode)
- medium → anchor window with auto-brief (no plan mode)
- complex → ephemeral task window with **plan mode + brainstorming forced** in target

### Step 5 — Medium brief (medium only)

Read `references/brief-template.md`. Fill:
- `FOLDER_PLACEHOLDER` → confirmed folder path
- `SESSION_SHAPE_PLACEHOLDER` → `anchor:<folder-name>`
- `DEPTH_PLACEHOLDER` → `medium`
- `CREATED_PLACEHOLDER` → `date -Iseconds`
- `SLUG_PLACEHOLDER` → first 4 significant words of prompt (strip: the/a/an/to/in/for/with/and/of)
- `TITLE_PLACEHOLDER` → Title-cased slug
- `GOAL_PLACEHOLDER` → tightened one-paragraph summary of prompt
- `CRITERIA_PLACEHOLDER` → 2–3 measurable bullets inferred from prompt
- `RESEARCH_PLACEHOLDER` → `yes — <skill recommendation>` or `no`
- `ORIGINAL_PROMPT_PLACEHOLDER` → verbatim user prompt
- `DISPATCH_CMD_PLACEHOLDER` → the tmux paste-buffer command (see Step 7)

Slug collision check: if `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md` exists, append `-s<seconds>`; if still collision, append `-r$(openssl rand -hex 3)`.

Write to `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md`.

Show rendered brief in meta pane. Confirm `y` / open for inline edit.

### Step 6 — Session shape

| Depth | Shape |
|---|---|
| quick | `inline` |
| medium | `anchor:<folder-name>` |
| complex | `ephemeral:task:<slug>` |

### Step 7 — Dispatch

**inline:**
```
Agent(
  subagent_type="general-purpose",
  prompt="<full user prompt>\n\nWork in: <cwd>\n\nUse bash tool to cd <cwd> before any file operations."
)
```
Return summary to meta. Done.

**anchor:<name>:**
1. Check if window exists: `tmux list-windows -t $TMUX_SESSION -F '#{window_name}' | grep -qx <name>`
2. If missing and name is in the lazy-anchors list (`$DISPATCH_LAZY_ANCHORS`): `scripts/ensure-anchor.sh <name> <cwd> --lazy`
3. If missing and name is a static anchor (must pre-exist): warn user. Do NOT call `Skill("remote-control")` — `/remote-control` is a UI command, `ensure-anchor.sh` sends it via `tmux send-keys` internally.
4. `scripts/dispatch-to-window.sh <name> --paste-file ~/.claude/tasks/<brief>.md`

**ephemeral:task:<slug>:**
1. `scripts/ensure-anchor.sh task:<slug> <cwd>` (no --lazy; always new)
2. Create minimal brief (Step 5 template but `session_shape: ephemeral:task:<slug>`, body only Goal + Original Prompt + Dispatch Cmd)
3. Write dispatch message to temp file with the iron-fist protocol:

   ```text
   Read ~/.claude/tasks/<brief>.md.

   This task is COMPLEX — follow the iron-fist protocol:

   1. Enter plan mode immediately via the EnterPlanMode tool (load schema with ToolSearch first if not in tools list).
   2. Invoke superpowers:brainstorming skill to clarify intent and surface edge cases.
   3. Invoke superpowers:writing-plans skill to draft an implementation plan.
   4. Present the plan via ExitPlanMode and wait for user approval before any edit.

   Work in: <cwd>. Target file is <one-line hint from brief Goal/Success Criteria, or "see brief" if none>.
   ```

   Substitute `<brief>` and `<cwd>` literally. "Target file" hint: scan the brief Goal/Success Criteria for a file path; fall back to "see brief".

4. `scripts/dispatch-to-window.sh task:<slug> --paste-file <tempfile>`

### Step 8 — Register

If anchor used: `scripts/lazy-anchor-registry.sh touch <anchor-name>`

### Step 9 — Audit

Append JSONL line to `~/.claude/dispatch/log`:
```json
{"ts":"<ISO>","slug":"<slug>","folder":"<folder>","shape":"<shape>","window":"<window>","brief":"<path>","exit":0}
```

Write `~/.claude/dispatch/last-dispatch.json` with same fields (full json, not JSONL).

### Step 10 — Print anchor-back

```
task <slug> dispatched → $TMUX_SESSION:<window>
attach: tmux attach -t $TMUX_SESSION \; select-window -t <window>
brief:  <path or "none">
```

---

## Meta context hygiene

Inline tasks (Step 7 inline path) use Agent subagents so meta's own context accumulates only summaries. All audit/list operations are file reads. Use `compact` meta-intent on demand.
