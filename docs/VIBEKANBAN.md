# VibeKanban Integration Guide

This guide explains how to use VibeKanban to orchestrate AI-assisted development on Sure Finance.

## What is VibeKanban?

[VibeKanban](https://vibekanban.com) is an orchestration platform for AI coding agents. It runs each task in an isolated git worktree, preventing conflicts between parallel work.

**Key Benefits:**
- Isolated git worktrees per task
- Multi-agent support (Claude Code, Codex, Gemini, etc.)
- Visual code review with diffs
- Subtask support for breaking down complex work
- MCP server for programmatic task management

## Quick Start

### 1. Install & Launch

```bash
npx vibe-kanban
```

Opens a web UI in your browser.

### 2. Add Sure Finance Project

VibeKanban auto-discovers recent git repos. Add `/Users/Cody/code_projects/sure` if not shown.

### 3. Configure Claude Code

In Settings → Agent Profiles, ensure Claude Code is configured:
- Executor: `claude-code`
- Variants: DEFAULT, PLAN

## Importing Sprint Tasks

We have pre-built tools to import our sprint documentation into VibeKanban.

### Option A: JSON Export (Manual Import)

Generate the export file:

```bash
node tools/vibekanban/vibekanban-import.mjs
```

Creates `tools/vibekanban/vibekanban-export.json` with all sprints, tasks, and subtasks.

### Option B: MCP Commands (Programmatic Import)

Generate MCP-compatible commands:

```bash
node tools/vibekanban/vibekanban-import.mjs --output mcp --subtasks
```

Creates `tools/vibekanban/vibekanban-tasks.json` with `create_task` commands.

### Filter by Sprint

Import only specific sprints:

```bash
# Quick Wins only
node tools/vibekanban/vibekanban-import.mjs --sprint quickwins --output mcp

# Goals & Savings only
node tools/vibekanban/vibekanban-import.mjs --sprint goals --output mcp

# Budget Intelligence only
node tools/vibekanban/vibekanban-import.mjs --sprint budget --output mcp

# AI Discoverability only
node tools/vibekanban/vibekanban-import.mjs --sprint ai --output mcp
```

## Task Tags

We provide reusable task tags for Sure Finance patterns in `tools/vibekanban/vibekanban-task-tags.json`.

### Available Tags

| Tag | Description |
|-----|-------------|
| `@rails-conventions` | Current.user, model patterns, concerns |
| `@i18n-pattern` | Internationalization requirements |
| `@hotwire-pattern` | Turbo + Stimulus patterns |
| `@viewcomponent-pattern` | ViewComponent guidelines |
| `@testing-pattern` | Minitest + fixtures requirements |
| `@design-system` | TailwindCSS design tokens |
| `@model-pattern` | Model structure template |
| `@controller-pattern` | Controller structure template |
| `@migration-pattern` | Database migration guidelines |
| `@acceptance-criteria` | Definition of Done checklist |
| `@ai-function-pattern` | AI assistant function template |

### Using Task Tags

1. Open VibeKanban Settings → Task Tags
2. Import tags from `tools/vibekanban/vibekanban-task-tags.json`
3. In task descriptions, type `@` to insert a tag

Example task description:
```
Implement savings goal model and CRUD

@model-pattern
@migration-pattern
@testing-pattern
@acceptance-criteria
```

## Recommended Workflow

### Sprint Execution

1. **Import Sprint Tasks**
   ```bash
   node tools/vibekanban/vibekanban-import.mjs --sprint quickwins --output mcp --subtasks
   ```

2. **Create Tasks in VibeKanban**
   - Use MCP server bulk import, OR
   - Create manually from `vibekanban-export.json`

3. **Start Tasks**
   - Select task → Create & Start
   - Choose Claude Code executor
   - Select base branch (e.g., `main` or `sprint/quick-wins`)

4. **Review & Merge**
   - Review diff in VibeKanban
   - Create PR or merge directly

### Parallel Work

VibeKanban enables safe parallel execution:

```
main
├── task/pdf-export          (Claude Code working)
├── task/anomaly-alerts      (Claude Code working)
└── task/period-comparison   (Claude Code working)
```

Each task has its own worktree - no conflicts.

## MCP Server Setup

To use VibeKanban's MCP server with Claude Desktop:

1. In VibeKanban: Settings → MCP Servers → Vibe Kanban → Save
2. Or add to Claude Desktop config:
   ```json
   {
     "mcpServers": {
       "vibe-kanban": {
         "command": "npx",
         "args": ["-y", "vibe-kanban@latest", "--mcp"]
       }
     }
   }
   ```

### MCP Tools Available

- `list_projects` - Get all projects
- `list_tasks` - Get tasks (filterable by status)
- `create_task` - Create new task
- `start_task_attempt` - Launch coding agent on task
- `get_task` / `update_task` / `delete_task`

## Sprint Mapping

| Sprint | Tasks | VibeKanban Project |
|--------|-------|-------------------|
| Quick Wins | 6 tasks, 40+ UOWs | sure/sprint-quickwins |
| Goals & Savings | 14 tasks, 50+ UOWs | sure/sprint-goals |
| Budget Intelligence | 8 tasks, 30+ UOWs | sure/sprint-budget |
| AI Discoverability | 6 tasks, 25+ UOWs | sure/sprint-ai |

## Tips

1. **Use Subtasks** - Our UOWs map naturally to VibeKanban subtasks
2. **Tag Everything** - Use task tags for consistent patterns
3. **Branch Per Sprint** - Create `sprint/quick-wins`, `sprint/goals`, etc.
4. **Review Before Merge** - Always review Claude's changes in VibeKanban's diff viewer
5. **Parallel is Safe** - Run multiple tasks simultaneously without fear

## Files Reference

| File | Purpose |
|------|---------|
| `tools/vibekanban/vibekanban-import.mjs` | Sprint doc → VibeKanban converter |
| `tools/vibekanban/vibekanban-export.json` | Full JSON export of all sprints |
| `tools/vibekanban/vibekanban-tasks.json` | MCP create_task commands |
| `tools/vibekanban/vibekanban-task-tags.json` | Reusable task tag definitions |
| `docs/VIBEKANBAN.md` | This guide |
