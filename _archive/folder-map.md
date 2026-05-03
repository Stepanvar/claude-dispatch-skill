# Folder classifier — keyword regex seeds

> **FROZEN 2026-05-01.** Dispatch skill simplified to always-new-window with no
> folder classification — only an explicit `@(smartast|metagap|life|metaenhance)`
> prefix sets cwd. This file kept for history; harness does not load it.



First match wins. Check in order: smartast → metagap → life → metaenhance (fallback).

## smartast → ~/lytech_smartast

Matches (case-insensitive):
- `\.cs\b` — C# file extension
- `\.cpp\b` — C++ file extension
- `P/Invoke|pinvoke` — interop layer
- `MVVM|ViewModel|ViewModelBase` — MVVM pattern
- `CrossSmart|SmartCross|lytech|smartast` — project names
- `susceptibility|antimicrobial|antibiogram|MIC\b` — domain terms
- `CalculateCross|ImageProcess` — C++ library names
- `dotnet|\.sln\b|\.csproj\b|\.xaml\b` — .NET artifacts

## metagap → ~/MetaGap

Matches:
- `django|manage\.py|settings\.py` — Django framework
- `vcf\b|\.vcf\b` — VCF genomics files
- `genomics|genomic|variant|bioinformatics` — domain
- `MetaGap|metagap` — project name
- `VcfImport|VcfParser|VariantRecord` — code symbols
- `postgres|psql` — MetaGap uses PostgreSQL (not other projects)
- `i18n|gettext|\.po\b|\.pot\b` — MetaGap has i18n requirement

## life → ~/Life

Matches:
- `obsidian|vault` — Obsidian app/concept
- `daily note|journal|zettelkasten|MOC\b` — Obsidian conventions
- `\.md note|periodic note|dataview` — Obsidian plugin terms
- `Life/|~/Life` — explicit path
- `workflow|braindump|capture note` — PKM vocabulary

## metaenhance → ~ (fallback)

Meta-work on the Claude/agent/session/dispatch system itself.

Applies when: no above match, plus explicit signals:
- `claude skill|claude hook|settings\.json|CLAUDE\.md` — Claude Code config
- `watchdog|tmux session|tmux window|remote.control|dispatch skill|anchor` — infra/orchestration
- `subagent|agent\b|metasession|metawork|orchestrat` — agent/session work
- `research\b|planning\b` — cross-cutting
- Anything else not matched above → metaenhance
