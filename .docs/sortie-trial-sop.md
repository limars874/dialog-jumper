# Sortie 试用 SOP

本文记录 `dialog-jumper` 试用 Sortie 作为 AI worker orchestration layer 的建议步骤。目标是先验证本地任务调度、独立 workspace、Codex worker、日志、token、状态恢复和 dashboard，再决定是否接入 GitHub tracker。

当前策略：

- 第一阶段使用 Sortie `file` tracker，本地 JSON 承载任务。
- 第一阶段使用 `codex` adapter，命令为 `codex app-server`。
- 第一阶段单并发运行，减少 workspace 和 git 状态复杂度。
- 所有 runtime 数据集中放入 `.sortie/`。
- Sortie 工具源码或 binary 放入 `.tools/sortie/` 或系统安装路径。
- 试用过程同步记录到 `.docs/sortie-trial-log.md`。

## 1. 为什么先试 Sortie

Sortie 更贴近我们想要的调度性工作流体系：

- `tracker adapter`：任务来源可以是 file、GitHub Issues、Linear、Jira。
- `agent adapter`：worker 可以是 Codex、Claude Code、Copilot CLI、OpenCode、Kiro。
- `workspace manager`：每个 issue 有独立 workspace。
- `SQLite state`：运行状态、重试、历史记录集中存储。
- `HTTP API / dashboard`：可以查看运行态、token、worker 状态。
- `WORKFLOW.md`：调度规则、prompt、hooks、agent 配置集中定义。

第一轮验证重点：

1. 本地 file tracker 是否比 GitHub polling 更快。
2. `codex app-server` worker 是否稳定。
3. 日志、token usage、runtime state 是否足够清楚。
4. workspace 里的代码变更能否容易审查和合入主工作区。
5. 停用时是否能按试用日志完整清理。

## 2. 推荐目录布局

```text
<repo>/
  .docs/sortie-trial-sop.md      # tracked，可复用 SOP
  .docs/sortie-trial-log.md      # tracked，本项目试用账本和回滚清单
  .sortie/                       # ignored，本地 runtime
    WORKFLOW.md                  # local Sortie workflow
    tasks.json                   # local file tracker task list
    state.db                     # SQLite state
    logs/                        # stdout/stderr/log capture
    workspaces/                  # per-issue cloned workspaces
  .tools/sortie/                 # ignored，可选源码 checkout 或 binary
```

`.sortie/` 是临时 runtime。产品事实、长期规则、设计结论进入 `.docs/`、`README.md`、source/tests 或 GitHub issue/PR record。

## 3. 前置检查

从 repo 根目录执行：

```bash
git status --short --branch
codex --version
codex app-server --help
swift build
swift test
```

`git status` 应保持干净，方便区分 Sortie workspace 变更和主工作区变更。

## 4. 安装 Sortie

推荐优先用系统级 binary，减少每个项目重复编译：

```bash
brew install --cask sortie-ai/tap/sortie
sortie --version
```

如果需要固定源码版本，用项目本地 checkout：

```bash
mkdir -p .tools
git clone https://github.com/sortie-ai/sortie .tools/sortie
git -C .tools/sortie checkout <pinned-sha>
go -C .tools/sortie build -o sortie ./cmd/sortie
.tools/sortie/sortie --version
```

当前 `dialog-jumper` 试用采用项目本地 binary：

```bash
mkdir -p .tools/sortie/bin
cp /tmp/sortie-check/sortie .tools/sortie/bin/sortie
.tools/sortie/bin/sortie --version
```

试用日志必须记录：

- 安装方式。
- Sortie version 或 commit SHA。
- binary path。
- 当前 Codex version。

## 5. 准备 ignored runtime

创建目录：

```bash
mkdir -p .sortie/logs .sortie/workspaces
```

`.gitignore` 应包含：

```gitignore
.sortie/
.tools/
```

## 6. 创建本地任务文件

第一轮只放一个文档任务，降低风险：

```bash
cat > .sortie/tasks.json <<'JSON'
[
  {
    "id": "sortie-trial-001",
    "identifier": "SORTIE-1",
    "title": "Sortie smoke task: inspect project context and update trial log",
    "state": "To Do",
    "description": "Read AGENTS.md, CLAUDE.md, .docs/ai-worker-context.md, .docs/sortie-trial-log.md, then update the trial log inside the workspace with observed command outputs and any blockers. Limit changes to documentation.",
    "labels": ["sortie-trial", "docs"],
    "priority": 1,
    "comments": []
  }
]
JSON
```

File tracker 是 read-only adapter。Sortie 读取 `tasks.json`，任务状态需要维护者或脚本手动修改。

常用状态：

```text
To Do        # 可调度
In Progress  # 可继续调度
Done         # 终态，workspace 可清理
Cancelled    # 可作为后续扩展终态
```

## 7. 创建本地 WORKFLOW.md

第一版 workflow 放在 `.sortie/WORKFLOW.md`，作为 runtime 文件。稳定后再考虑把模板提升到 tracked docs。

```bash
cat > .sortie/WORKFLOW.md <<'EOF'
---
tracker:
  kind: file
  active_states:
    - To Do
    - In Progress
  terminal_states:
    - Done
    - Cancelled

file:
  path: .sortie/tasks.json

polling:
  interval_ms: 30000

workspace:
  root: /Users/yi/Documents/code/me/dialog-jumper/.sortie/workspaces

db_path: state.db

hooks:
  after_create: |
    git clone --no-hardlinks "$SORTIE_REPO_PATH" .
  before_run: |
    git fetch "$SORTIE_REPO_PATH" main
    git checkout -B "sortie/${SORTIE_ISSUE_IDENTIFIER}" FETCH_HEAD
  after_run: |
    git status --short
    git add -A
    git diff --cached --quiet || git commit -m "sortie(${SORTIE_ISSUE_IDENTIFIER}): automated changes"
  timeout_ms: 120000

agent:
  kind: codex
  command: codex app-server
  max_turns: 3
  max_concurrent_agents: 1
  turn_timeout_ms: 1800000
  read_timeout_ms: 10000
  stall_timeout_ms: 300000
  max_retry_backoff_ms: 120000

codex:
  approval_policy: never
  thread_sandbox: workspaceWrite
  skip_git_repo_check: false

server:
  port: 7678
---

You are a senior engineer working inside an isolated Sortie workspace for `dialog-jumper`.

## Task

**{{ .issue.identifier }}**: {{ .issue.title }}

{{ if .issue.description }}
{{ .issue.description }}
{{ end }}

## Required context

Read these files before making changes:

- `AGENTS.md`
- `CLAUDE.md`
- `.docs/ai-worker-context.md`
- `.docs/project-memory.md`
- `.docs/sortie-trial-sop.md`
- `.docs/sortie-trial-log.md`

## Rules

1. Keep the change within the task description.
2. Prefer documentation-only edits for the first smoke task.
3. Run `swift build` and `swift test` when source code changes.
4. Record verification commands and outcomes in the final response.
5. Record durable facts in the smallest durable home listed by `.docs/project-memory.md`.
6. Leave runtime files under `.sortie/` out of product facts.

{{ if .run.is_continuation }}
## Continuation

This is turn {{ .run.turn_number }} of {{ .run.max_turns }}. Inspect current workspace state with `git status --short` and continue from the previous attempt.
{{ end }}
EOF
```

`SORTIE_REPO_PATH` 在启动 Sortie 时传入，指向当前 repo。workspace 会从本地 repo clone，适合验证本地未推送提交。

## 8. 校验 workflow

```bash
SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie validate .sortie/WORKFLOW.md
SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --dry-run .sortie/WORKFLOW.md
```

校验通过后，把输出摘要写入 `.docs/sortie-trial-log.md`。

## 9. 启动试跑

前台运行，方便随时 Ctrl-C：

```bash
SORTIE_REPO_PATH="$PWD" .tools/sortie/bin/sortie --log-level debug .sortie/WORKFLOW.md 2>&1 | tee .sortie/logs/sortie-$(date +%Y%m%d-%H%M%S).log
```

打开 dashboard：

```text
http://127.0.0.1:7678
```

常用 API：

```bash
curl -s http://127.0.0.1:7678/readyz
curl -s http://127.0.0.1:7678/api/v1/state
```

## 10. 审查 worker 输出

查看 workspace：

```bash
find .sortie/workspaces -maxdepth 2 -type d -print
git -C .sortie/workspaces/SORTIE-1 status --short
git -C .sortie/workspaces/SORTIE-1 log --oneline -n 5
git -C .sortie/workspaces/SORTIE-1 show --stat --oneline HEAD
```

合入主工作区前先人工 review：

```bash
git -C .sortie/workspaces/SORTIE-1 diff main...HEAD
```

推荐合入方式：

```bash
git fetch .sortie/workspaces/SORTIE-1 sortie/SORTIE-1
git merge --no-ff FETCH_HEAD
```

## 11. 状态收口

任务完成后，手动把 `.sortie/tasks.json` 中对应 issue 的 `state` 改成 `Done`。Sortie 下次 reconciliation 会把终态任务从 active set 移出。

每次试跑后记录：

- Sortie version / commit。
- Codex version。
- 启动命令。
- 任务 ID。
- workspace path。
- 是否生成 commit。
- token usage。
- 总耗时。
- 失败、超时、阻塞、人工介入点。
- 清理或保留的 runtime 路径。

## 12. 后续升级路线

只有在 file tracker 试跑稳定后，再逐步打开：

1. GitHub tracker。
2. `handoff_state` / `in_progress_state`。
3. 多并发。
4. self-review。
5. PR push 和 review reactions。
6. Claude Code / OpenCode adapter 对比。

升级时每次只变更一个维度，并把结果写入试用日志。

## 13. 停用和回滚

停进程：

```bash
ps -eo pid,ppid,stat,etime,command | rg 'sortie|codex app-server'
kill -TERM <pid...>
```

确认删除前列路径：

```bash
du -sh .sortie .tools/sortie 2>/dev/null
find .sortie -maxdepth 2 -print 2>/dev/null
```

可清理对象：

```text
.sortie/
.tools/sortie/
sortie binary if installed only for this trial
```

如果修改过 tracked 文件，按 `git status --short` 审查后单独决定提交或回滚。删除操作必须先取得明确确认。
