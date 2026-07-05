# Sortie 试用日志

本文记录 `dialog-jumper` 对 Sortie 的本地试用过程。它是试用账本，也是停用/清理时的回滚索引。

## Current status

- Status: local setup validated
- Started at: 2026-07-05 19:13:11 CST
- Last updated: 2026-07-05 19:17:06 CST
- Owner: local maintainer
- Related docs:
  - `.docs/sortie-trial-sop.md`
  - `.docs/consensus-rnd-sop.md#22-实际试用备注与换型评估`
  - `.docs/ai-worker-context.md`
  - `.docs/project-memory.md`

## Trial goal

验证 Sortie 是否能替代当前 `consensus-rnd` 的日常调度层：

- 本地任务文件驱动 worker。
- 独立 workspace 执行。
- Codex worker 稳定运行。
- 日志、token、状态恢复可观察。
- 后续可接 GitHub 作为同步/审计层。
- 停用时可完整清理 runtime 和工具数据。

## Baseline before trial

记录执行前状态：

```bash
git status --short --branch
codex --version
codex app-server --help
swift build
swift test
```

Result:

```text
git status --short --branch:
## main...origin/main [ahead 4]
 M .docs/ai-worker-context.md
 M .docs/project-memory.md
 M .gitignore
 M README.md
?? .docs/sortie-trial-log.md
?? .docs/sortie-trial-sop.md

codex --version:
codex-cli 0.140.0

codex app-server --help:
available; supports stdio, unix socket, ws transports

swift build:
passed

swift test:
passed; 22 tests passed
```

## Installed tool record

| Field | Value |
| --- | --- |
| Install method | copied existing local test binary into project-local `.tools/sortie/bin/sortie` |
| Sortie binary path | `.tools/sortie/bin/sortie` |
| Sortie version | `sortie dev (commit: unknown, built: unknown, go1.26.1, darwin/arm64)` |
| Sortie source repo | `https://github.com/sortie-ai/sortie` |
| Sortie commit SHA | `2191f9a5dfb667d2e7e873ea12be69e814a0a493` from `/tmp/sortie-check` |
| Codex version | `codex-cli 0.140.0` |
| Installed by | local Codex session |
| Installed at | 2026-07-05 19:13:11 CST |

Notes:

- Use system binary when possible.
- If source checkout is used, expected path is `.tools/sortie/`.

## Runtime paths

| Path | Type | Tracked | Cleanup action |
| --- | --- | --- | --- |
| `.sortie/WORKFLOW.md` | local workflow | no | delete with `.sortie/` |
| `.sortie/tasks.json` | file tracker task store | no | delete with `.sortie/` |
| `.sortie/state.db` | SQLite state | no | delete with `.sortie/` |
| `.sortie/logs/` | logs | no | delete with `.sortie/` |
| `.sortie/workspaces/` | per-issue workspaces | no | review, then delete |
| `.tools/sortie/` | optional source checkout | no | delete if used |

Tracked files intentionally added for this trial:

```text
.docs/sortie-trial-sop.md
.docs/sortie-trial-log.md
```

Tracked files intentionally updated for this trial:

```text
README.md
.gitignore
.docs/ai-worker-context.md
.docs/project-memory.md
```

## Environment variables

| Name | Value / Source | Notes |
| --- | --- | --- |
| `SORTIE_REPO_PATH` | `$PWD` | Local clone source for workspaces |
| `CODEX_API_KEY` | inherited or Codex login | Do not paste secret |
| `SORTIE_WORKSPACE_ROOT` | optional | SOP uses workflow-local `workspaces` |

## Planned local workflow

Expected command:

```bash
SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --log-level debug .sortie/WORKFLOW.md 2>&1 | tee .sortie/logs/sortie-$(date +%Y%m%d-%H%M%S).log
```

Expected dashboard:

```text
http://127.0.0.1:7678
```

Expected first task:

```text
SORTIE-1: Sortie smoke task: inspect project context and update trial log
```

## Run records

### Run 1

- Date: 2026-07-05
- Sortie command: pending full run
- Task: `SORTIE-1`
- Start time:
- End time:
- Elapsed:
- Workspace:
- Log file:
- Dashboard/API observations:
- Token usage:
- Result:
- Generated commit:
- Files changed:
- Verification:
- Blockers:
- Cleanup performed:

Raw notes:

```text
Setup:
- Created project-local binary at `.tools/sortie/bin/sortie`.
- Created ignored runtime files `.sortie/WORKFLOW.md` and `.sortie/tasks.json`.
- `SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie validate .sortie/WORKFLOW.md` passed with no output.
- `SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --dry-run .sortie/WORKFLOW.md` found one candidate:
  issue_id=sortie-trial-001
  issue_identifier=SORTIE-1
  state=To Do
  would_dispatch=true
  max_concurrent_agents=1
```

## Findings

Record facts only after a real run.

### What worked

- pending

### What was slow or awkward

- pending

### What failed

- pending

### Comparison with consensus-rnd

- pending

## Decision log

| Date | Decision | Reason | Follow-up |
| --- | --- | --- | --- |
| pending | Start with file tracker + Codex adapter | Lowest-risk local orchestration test | Create `.sortie/WORKFLOW.md` and `.sortie/tasks.json` |

## Rollback checklist

Before cleanup:

```bash
ps -eo pid,ppid,stat,etime,command | rg 'sortie|codex app-server'
git status --short --branch
du -sh .sortie .tools/sortie 2>/dev/null
find .sortie -maxdepth 2 -print 2>/dev/null
```

Runtime cleanup candidates:

```text
.sortie/
.tools/sortie/
```

Tracked trial docs:

```text
.docs/sortie-trial-sop.md
.docs/sortie-trial-log.md
```

Tracked context updates:

```text
README.md
.gitignore
.docs/ai-worker-context.md
.docs/project-memory.md
```

Cleanup rules:

- Stop Sortie and spawned Codex processes first.
- Review workspace commits before deleting `.sortie/workspaces/`.
- Keep this log until the final tool decision is made.
- Run deletion only after explicit confirmation.

## Final decision

- Decision: pending
- Keep:
- Remove:
- Follow-up:
