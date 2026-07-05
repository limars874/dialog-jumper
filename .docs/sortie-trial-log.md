# Sortie 试用日志

本文记录 `dialog-jumper` 对 Sortie 的本地试用过程。它是试用账本，也是停用/清理时的回滚索引。

## Current status

- Status: smoke run completed; follow-up investigation needed
- Started at: 2026-07-05 19:13:11 CST
- Last updated: 2026-07-05 20:12:55 CST
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
- Sortie command:
  ```bash
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --log-level debug .sortie/WORKFLOW.md 2>&1 | tee .sortie/logs/sortie-20260705-192312.log
  ```
- Task: `SORTIE-1`
- Start time: 2026-07-05 19:23:12 CST
- End time: 2026-07-05 19:30:42 CST, then stopped manually with Ctrl-C after idle ticks
- Elapsed: about 7m30s wall time; active worker time ended at 19:27:37 CST
- Workspace: `.sortie/workspaces/SORTIE-1`
- Log file: `.sortie/logs/sortie-20260705-192312.log`
- Dashboard/API observations: local server started on `127.0.0.1:7678`; no dashboard persistence after process stop
- Token usage: SQLite reported `input_tokens=0`, `output_tokens=0`, `total_tokens=0`; `api_request_count=2`
- Result: Sortie dispatched the task and drove Codex turns, but the worker produced no file changes
- Generated commit: none
- Files changed: none inside `.sortie/workspaces/SORTIE-1`
- Verification:
  ```bash
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie validate .sortie/WORKFLOW.md
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --dry-run .sortie/WORKFLOW.md
  git -C .sortie/workspaces/SORTIE-1 status --short --branch
  git -C .sortie/workspaces/SORTIE-1 diff --stat
  sqlite3 -readonly -header -column 'file:.sortie/state.db?mode=ro' "SELECT id,issue_id,attempt,status,started_at,completed_at,turns_completed,input_tokens,output_tokens,total_tokens,error FROM run_history ORDER BY id;"
  sqlite3 -readonly -header -column 'file:.sortie/state.db?mode=ro' "SELECT issue_id,session_id,agent_pid,input_tokens,output_tokens,total_tokens,api_request_count,updated_at FROM session_metadata;"
  ```
- Blockers: file tracker state requires external mutation; current Codex adapter token accounting returned zero; worker content is not visible in Sortie debug log
- Cleanup performed: no deletion; stopped foreground Sortie process

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

Run:
- Sortie created workspace `.sortie/workspaces/SORTIE-1`.
- Sortie started Codex app-server session `019f3204-a42b-7bb3-9711-d5ed7a01a3d2`.
- Sortie completed 3 turns in attempt 1, then retried the same issue because `.sortie/tasks.json` still had `state=To Do`.
- Sortie completed 3 turns in attempt 2, then retried again for the same reason.
- During attempt 3, `.sortie/tasks.json` was manually changed to `state=Done`.
- Sortie refreshed the issue state as `Done`, released the claim, and idled with `running=0`.
- The workspace branch remained `sortie/SORTIE-1` at commit `5b67fa3`.
- `git diff --stat` and `git diff --stat main...HEAD` were empty.
```

### Run 2

- Date: 2026-07-05
- Sortie command:
  ```bash
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --log-level debug .sortie/WORKFLOW.md 2>&1 | tee .sortie/logs/sortie-20260705-195741.log
  ```
- Task: `SORTIE-2`
- Runtime workflow change: `agent.max_turns` changed from `3` to `1`
- Task goal: create `.docs/sortie-worker-proof.md` inside the workspace with two fixed lines
- Start time: 2026-07-05 19:57:41 CST
- Terminal state set: 2026-07-05 20:03:41 CST
- Process stopped: 2026-07-05 20:06:11 CST, with Ctrl-C after idle ticks
- Workspace: `.sortie/workspaces/SORTIE-2`
- Log file: `.sortie/logs/sortie-20260705-195741.log`
- Result: Sortie repeatedly ran 1-turn worker attempts; no proof file was available after terminal cleanup
- Run history: 8 succeeded attempts, then 1 cancelled attempt when terminal state stopped the active worker
- Token usage: SQLite reported `input_tokens=0`, `output_tokens=0`, `total_tokens=0`; `api_request_count=0`
- Generated commit: none observed
- Files changed: none available for review; `.sortie/workspaces/` was empty after terminal cleanup
- Verification:
  ```bash
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie validate .sortie/WORKFLOW.md
  SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --dry-run .sortie/WORKFLOW.md
  find .sortie/workspaces -maxdepth 2 -type d -print
  test -f .sortie/workspaces/SORTIE-2/.docs/sortie-worker-proof.md && sed -n '1,20p' .sortie/workspaces/SORTIE-2/.docs/sortie-worker-proof.md || echo 'proof file missing'
  sqlite3 -readonly -header -column 'file:.sortie/state.db?mode=ro' "SELECT id,issue_id,attempt,status,started_at,completed_at,turns_completed,input_tokens,output_tokens,total_tokens,error FROM run_history ORDER BY id;"
  ```
- Blockers: `Done` triggers terminal workspace cleanup; file tracker still needs external state management; Codex adapter did not prove file edit path
- Cleanup performed: foreground Sortie stopped; no manual deletion performed

Raw notes:

```text
Setup:
- `SORTIE-1` remained `Done`.
- Added `SORTIE-2` with `state=To Do`.
- Set `agent.max_turns: 1`.
- `validate` passed.
- `--dry-run` showed only `SORTIE-2` as would_dispatch=true.

Run:
- Sortie created `.sortie/workspaces/SORTIE-2`.
- Sortie started Codex app-server session `019f3224-35fc-7ff2-ba2d-ab823f677019`.
- Because `SORTIE-2` stayed `To Do`, Sortie retried after each 1-turn success.
- `.sortie/tasks.json` was manually changed to `state=Done` during attempt 9.
- Sortie detected terminal state and stopped the active worker.
- Source check: Sortie docs and source confirm terminal-state workspace cleanup.
- After process stop, `find .sortie/workspaces -maxdepth 2 -type d -print` returned only `.sortie/workspaces`.
```

## Findings

### What worked

- Project-local binary ran from `.tools/sortie/bin/sortie`.
- Project-local runtime stayed under ignored `.sortie/`.
- `validate` and `--dry-run` worked with `SORTIE_REPO_PATH="$PWD"`.
- Sortie created an isolated workspace and branch.
- Sortie started `codex app-server`, processed turns, persisted run history in SQLite, and released the task after `state=Done`.
- `max_turns: 1` works as a narrower smoke-test throttle.

### What was slow or awkward

- The first run took about 4m25s of active worker time across 8 turns before manual terminal state.
- The `file` tracker is a read-only source. State transition needs a maintainer action or a separate controller script.
- With `max_turns: 3`, one active `To Do` task can consume multiple turns and retries while no completion state is written.
- Sortie logs record event types and state transitions clearly, while worker message content is largely opaque in the captured debug log.
- `Done` is a terminal state and triggers workspace cleanup, so reviewable changes need to be inspected before terminal transition or moved out by a hook.

### What failed

- The smoke worker produced no documentation update and no commit.
- Token usage persisted as zero despite `api_request_count=2`.
- The run did not prove that Codex edits can be reliably driven through this Sortie configuration.
- Run 2 also failed to prove the edit path: no proof document survived for review, and token/accounting data remained zero.

### Comparison with consensus-rnd

- Sortie is much simpler to run locally than the previous GitHub-polling consensus daemon.
- Sortie has cleaner local workspace/state structure for orchestration experiments.
- Sortie still needs a local state-completion mechanism, a review-before-cleanup state, and better worker-output observability before it can replace the previous flow.

## Decision log

| Date | Decision | Reason | Follow-up |
| --- | --- | --- | --- |
| 2026-07-05 | Start with file tracker + Codex adapter | Lowest-risk local orchestration test | Create `.sortie/WORKFLOW.md` and `.sortie/tasks.json` |
| 2026-07-05 | Keep Sortie runtime project-local | Avoid global workflow pollution across projects | Keep `.sortie/` and `.tools/` ignored |
| 2026-07-05 | Treat Run 1 as a partial smoke pass | Scheduler ran; worker edit path and token accounting still need proof | Run a narrower second task with `max_turns: 1` and explicit one-file edit |
| 2026-07-05 | Treat Run 2 as a failed edit-path proof | Scheduler ran repeatedly; terminal cleanup removed workspace before review; token accounting stayed zero | Add a review state or after-run export hook before further trials |

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

- Decision: pause evaluation until workflow state design is adjusted
- Keep: tracked SOP/log docs and ignored project-local Sortie runtime for now
- Remove: no cleanup performed yet
- Follow-up: add a non-terminal review state or after-run export hook, then retry one-file edit proof
