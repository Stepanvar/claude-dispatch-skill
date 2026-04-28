# Triage depth — quick / medium / complex

Inspect: character count, newline count, vocab, question mark. First matching tier wins (check complex first).

## complex (→ ephemeral task window + brainstorming in target)

Any one of:
- Length > 1500 chars
- Contains any: `design`, `architect`, `refactor`, `build a`, `figure out`, `explore`, `unclear`, `spec`, `plan`, `multi-step`, `from scratch`, `think through`, `evaluate options`
- Ends with or contains a "how should I" / "what approach" question about architecture
- Asks user to decide between options ("which is better", "should I use X or Y")
- Contains "investigate why" (implies unknown solution)

## medium (→ anchor window + auto-brief)

All of:
- Length 240–1500 chars, OR 2–6 paragraph breaks
- Clear imperative verb: `add`, `wire up`, `fix`, `port`, `update`, `migrate`, `implement`, `write tests for`, `convert`, `rename`, `move`, `extract`
- Bounded scope — one module / one file / one endpoint / one model
- No complex-tier keywords

## quick (→ inline Agent subagent in meta)

All of:
- Length ≤ 240 chars AND ≤ 1 newline
- No complex-tier or medium-tier verbs
- Often: factual lookup, one-liner fix, "what does X mean", "show me X", "where is Y"
- Frequently ends with `?`

## Override UX

After triage prints `depth: <d>  reason: <cue>`:
- `y` = accept
- `q` = override to quick
- `m` = override to medium
- `c` = override to complex
