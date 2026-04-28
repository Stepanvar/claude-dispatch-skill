# claude-dispatch-skill

A Claude Code skill that routes work to the right tmux window automatically.

Type a task in your `meta` tmux window. The skill classifies which project it belongs to, decides how complex it is, and dispatches it to the right place — an inline subagent, a persistent anchor window, or a fresh ephemeral task window — so your meta context stays small.

## Why

Every Claude Code session has a finite context window. When you use the meta window as a dispatch board instead of a workspace, you get:
- parallel project sessions with isolated contexts
- automatic task briefs for medium/complex work
- a full JSONL audit trail of every dispatch

## Architecture

```
meta window (claude + dispatch skill)
    │
    ├── folder classify ── keyword regex → project folder
    ├── depth triage    ── quick / medium / complex
    │
    ├─── quick  → inline Agent subagent (returns to meta)
    │
    ├─── medium → anchor window (persistent)
    │              claude + /remote-control bridge
    │              auto-generated task brief
    │
    └─── complex → ephemeral task window
                   claude + /remote-control bridge
                   full task brief + iron-fist protocol
                   (plan mode + brainstorming forced)
```

## Prerequisites

- **tmux** — sessions and windows
- **claude CLI** — `claude` must be on `PATH` (or set `CLAUDE_BIN`)
- **/remote-control** — Claude Code slash command that creates a controllable bridge; must be installed separately. Without it, `ensure-anchor.sh` will boot Claude but the anchor-back dispatch will not work.
- **bash 4+** — all scripts use bash-specific features
- **flock** — for lazy-anchor spawn serialization (usually ships with `util-linux`)
- **jq** (optional) — for inspecting `~/.claude/dispatch/log`

## Install

```bash
git clone https://github.com/szuev/claude-dispatch-skill.git
# Symlink into your Claude skills directory:
ln -s ~/claude-dispatch-skill ~/.claude/skills/dispatch
# Or copy if you prefer a standalone snapshot:
cp -r ~/claude-dispatch-skill ~/.claude/skills/dispatch
```

Claude Code picks up skills from `~/.claude/skills/<name>/SKILL.md` automatically.

## Configure

### 1. Edit `references/folder-map.md`

Replace the `proj-a` / `proj-b` placeholder sections with your actual projects and keyword regexes. First match wins.

### 2. Set env vars (optional but recommended)

| Variable | Default | Purpose |
|---|---|---|
| `TMUX_SESSION` | `claude` | Name of your tmux session |
| `CLAUDE_BIN` | `${HOME}/.local/bin/claude` | Path to claude CLI binary |
| `DISPATCH_LAZY_ANCHORS` | _(empty)_ | Comma-separated anchor names eligible for lazy spawn. Example: `proj-a,proj-b` |
| `MAX_LIVE_LAZY` | `1` | Max number of lazy anchors alive at once |
| `CLAUDE_READY_TIMEOUT` | `30` | Seconds to wait for claude pane to be ready after spawn |

Put them in your shell profile or a `.env` file you source before starting tmux.

### 3. Name your meta window

The skill's `description` field targets the window named `meta`. Create it once:

```bash
tmux new-window -n meta -c ~
```

Then launch Claude in it with the dispatch skill active.

## Usage

1. Open the `meta` tmux window.
2. Type any task — "add validation to the login form", "what does auth middleware do?", "build the CSV export feature".
3. The skill prints its classification and waits for one-key confirmation:
   ```
   pick: proj-a  reason: mentions proja
   depth: medium  reason: bounded imperative
   [y] accept  [1] meta  [2] proj-a  [3] proj-b  [4] other
   > _
   ```
4. Press `y` (or a number to override) and the work lands in the right window.

## State files

All runtime state lives under `~/.claude/dispatch/`:

| Path | Purpose |
|---|---|
| `anchors/<name>.last` | mtime-based last-dispatch timestamp per anchor |
| `anchors/spawn.lock` | flock mutex — prevents parallel lazy spawns |
| `log` | JSONL audit log, one line per dispatch |
| `last-dispatch.json` | last dispatch record (used for redirect meta-intent) |

Task briefs are written to `~/.claude/tasks/YYYY-MM-DD-HHMM-<slug>.md`.

## Meta-intents

These work in the meta window without triggering a dispatch:

| Message | Action |
|---|---|
| `list` | Show running tmux windows + last 10 log lines |
| `kill task:<slug>` | Kill an ephemeral task window and remove its registry entry |
| `reattach <name>` | Print the `tmux attach` command for a window |
| `show last` | Print `last-dispatch.json` |
| `compact` | Run `/compact` to trim meta context |
| `cancel` | Abort without dispatching |
| `actually ...` / `redirect to ...` | Re-classify and dispatch to a different target |

## Limits

- Linux-tested only (uses `stat -c%Y`, `pgrep -P`, GNU `split`, `bc`).
- Depends on `/remote-control` Claude Code command — install separately.
- Scripts assume bash 4+. `wait-for-claude-ready.sh` polls at 0.5 s intervals.
- The skill's dispatch logic lives in `SKILL.md` and is executed by Claude, not by a shell. The scripts handle tmux mechanics only.

## License

MIT — see [LICENSE](LICENSE).
