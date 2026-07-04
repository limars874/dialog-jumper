# Consensus R&D 从 0 接入 SOP

本文是一份 host project 接入 `ChronoAIProject/consensus-rnd` / `consensus-loop` 的操作手册。目标是让一个新项目能从空仓库或早期仓库开始，把 Consensus R&D 的 GitHub issue 驱动、多角色设计共识、daemon 调度、worker 执行和本地运行面完整跑起来。

当前 `dialog-jumper` 采用项目本地工具布局：

```text
<repo>/
  .tools/consensus-rnd/                    # ignored, local tool checkout
  .config/consensus-rnd/host.env           # ignored, machine-local runtime facts
  .config/consensus-rnd/host.env.example   # tracked, copyable template
  .refactor-loop/                          # ignored, runtime logs/state/cache/work artifacts
  .worktrees/                              # ignored, worker worktrees
```

推荐把 `consensus-rnd` 放在项目 `.tools/` 里并 `gitignore`。这样每个项目能固定自己的工具版本，README 只记录 clone URL、ref 和 commit SHA。

## 1. 先理解这套系统

Consensus R&D 是一套多进程、GitHub 可见状态驱动的 controller / worker 系统。它由几层组成：

1. `host repo`：真正要开发的项目，例如 `dialog-jumper`。
2. `consensus-rnd tool checkout`：工具源码，推荐放在 `.tools/consensus-rnd`。
3. `consensus-loop skill`：核心 controller contract，位于 `.tools/consensus-rnd/skills/consensus-loop`。
4. `host.env`：host 项目注入运行事实的唯一入口，例如 repo 路径、GitHub repo、build/test 命令、分支名。
5. `.refactor-loop/`：工具私有 runtime 目录，放 logs、state、prompt、run artifacts。
6. GitHub issues / labels / comments：对人可见的真实状态面。
7. `codex exec` worker：真正做设计、实现、review、修复的进程。

Controller 的职责是编排。产品代码、重构、测试、review 由 worker 进程做。GitHub 是可见状态面，本地 `.refactor-loop/` 是调试和恢复面。

## 2. 适用范围

适合：

- 需要用 GitHub issue 管理功能、bug、重构或文档任务。
- 希望让多个独立 worker 给出设计方案，再由 meta-judge 判断共识。
- 希望长时间无人值守推进：设计共识、实现、review、fix、PR、merge。
- 项目已经有稳定的 build/test 命令。

谨慎使用：

- 项目还没有可运行的 build/test baseline。
- GitHub repo 权限不足，无法创建/编辑 labels、issues、PR。
- 机器上没有稳定的 `gh` auth、`git` remote、Codex CLI。
- 当前需求含大量产品方向决策，需要 maintainer 先写清楚边界。

## 3. 前置条件

本机需要：

```bash
git --version
gh --version
python3 --version
codex --version
```

GitHub 需要：

```bash
gh auth status
gh repo view OWNER/REPO
```

项目需要：

```bash
git status --short --branch
git remote -v
```

新项目先把最小 build/test 跑绿。例如 Swift Package：

```bash
swift build
swift test
```

Node 项目示例：

```bash
npm ci --no-audit --no-fund
npm run build
npm test
```

`BUILD_CMD` 和 `TEST_CMD` 后续会被 worker 在 isolated worktree 中执行，所以命令要自包含。依赖目录通常被 `.gitignore` 忽略，fresh worktree 里需要命令自己安装依赖。

## 4. 安装工具到项目本地

从 host repo 根目录执行：

```bash
mkdir -p .tools
git clone --branch dev https://github.com/ChronoAIProject/consensus-rnd .tools/consensus-rnd
git -C .tools/consensus-rnd checkout abd6db05c508563e1e6fe17abf15925cc0fe8172
chmod +x .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli
```

记录 pin：

```text
Repo: https://github.com/ChronoAIProject/consensus-rnd
Ref: dev
Commit: abd6db05c508563e1e6fe17abf15925cc0fe8172
```

把 `.tools/` 加进 `.gitignore`：

```gitignore
.tools/
```

这一步只管理工具源码归属。host repo 提交 README 和 example config，工具 checkout 本身留在本机。

## 5. 可选：清理无效内容

这一节用于把完整 clone 变成 runtime-only snapshot。适合只运行 `consensus-loop`，并且接受后续更新时重新下载或重新复制工具目录的项目。

执行前确认当前工具版本已经 pin 到目标 commit：

```bash
git -C .tools/consensus-rnd rev-parse HEAD
```

当前 `dialog-jumper` 使用：

```text
abd6db05c508563e1e6fe17abf15925cc0fe8172
```

保守清理策略：

```bash
rm -rf .tools/consensus-rnd/.git
rm -rf .tools/consensus-rnd/.github
rm -rf .tools/consensus-rnd/.claude-plugin
rm -rf .tools/consensus-rnd/.codex-plugin
rm -rf .tools/consensus-rnd/.cursor-plugin
rm -rf .tools/consensus-rnd/skills/sshx
find .tools/consensus-rnd -type d -name '__pycache__' -prune -exec rm -rf {} +
```

激进清理策略：

```bash
rm -rf .tools/consensus-rnd/.git
rm -rf .tools/consensus-rnd/.github
rm -rf .tools/consensus-rnd/.claude-plugin
rm -rf .tools/consensus-rnd/.codex-plugin
rm -rf .tools/consensus-rnd/.cursor-plugin
rm -rf .tools/consensus-rnd/skills/sshx
find .tools/consensus-rnd -type d -name '__pycache__' -prune -exec rm -rf {} +
find .tools/consensus-rnd/skills/consensus-loop/scripts -maxdepth 1 -type f -name 'test_*.py' -delete
rm -rf .tools/consensus-rnd/skills/consensus-loop/scripts/test_support
```

清理后保留这些 runtime 核心面：

```text
.tools/consensus-rnd/skills/consensus-loop/SKILL.md
.tools/consensus-rnd/skills/consensus-loop/host.env.example
.tools/consensus-rnd/skills/consensus-loop/prompts
.tools/consensus-rnd/skills/consensus-loop/authorizations
.tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli
.tools/consensus-rnd/skills/consensus-loop/scripts/ghwrap
.tools/consensus-rnd/skills/consensus-loop/scripts/codex_refactor_loop
```

代价：

- 删除 `.git` 后，`.tools/consensus-rnd` 变成普通目录，后续无法在里面 `git fetch` / `git checkout`。
- 删除 `test_*.py` 后，无法在本机运行工具自身测试。
- runtime 仍会重新生成 `__pycache__`，这属于 Python 正常缓存。

清理后做一次 smoke check：

```bash
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels validate-catalog
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
```

所有删除命令都属于永久操作，按项目删除确认规则执行。本文只给出步骤，实际运行前先列出路径和预期影响。

## 6. 准备 host.env

创建目录和本机配置：

```bash
mkdir -p .config/consensus-rnd
cp .tools/consensus-rnd/skills/consensus-loop/host.env.example .config/consensus-rnd/host.env
```

把本机文件加入 `.gitignore`：

```gitignore
.config/consensus-rnd/host.env
```

提交一个可复制模板：

```bash
cp .config/consensus-rnd/host.env .config/consensus-rnd/host.env.example
```

编辑 `.config/consensus-rnd/host.env`。最小必填项：

```bash
export REPO_ROOT="/abs/path/to/your/repo"
export GH_REPO_SLUG="owner/repo"

export BUILD_CMD="your build command"
export TEST_CMD="your test command"

export INTEGRATION_BRANCH="main"
export REVIEW_BASE_BRANCH="main"
```

`dialog-jumper` 当前示例：

```bash
export REPO_ROOT="/Users/yi/Documents/code/me/dialog-jumper"
export GH_REPO_SLUG="limars874/dialog-jumper"
export BUILD_CMD="swift build"
export TEST_CMD="swift test"
export INTEGRATION_BRANCH="main"
export REVIEW_BASE_BRANCH="main"
export CODEX_FLOOR="2"
export HOST_WORK_LANGUAGE="zh"
```

每次运行 CLI 前注入：

```bash
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
```

关键规则：

- `CONSENSUS_RND_HOST_ENV` 指向 host-owned `host.env`。
- `REPO_ROOT` 使用绝对路径。
- `GH_REPO_SLUG` 使用 `OWNER/REPO`。
- `BUILD_CMD` 和 `TEST_CMD` 是 shell command string，调用方用 `bash -lc "$BUILD_CMD"` / `bash -lc "$TEST_CMD"`。
- runtime fact 统一来自 `CONSENSUS_RND_HOST_ENV` 指向的 host-owned `host.env`。
- `env $(grep ...)` 这类注入方式会破坏含空格的命令值，使用 `source "$CONSENSUS_RND_HOST_ENV"`。

## 7. 推荐的 host.env 选项

小项目或早期项目：

```bash
export CODEX_FLOOR="2"
export AUDIT_FALLBACK_ENABLE="false"
export DEFAULT_ISSUE_INTAKE_ENABLE="false"
export ROLLUP_AUTO_MERGE="manual"
export RELEASE_AUTO_ENABLE="false"
export RUNTIME_RETENTION_ENABLE="false"
export HOST_WORK_LANGUAGE="zh"
```

含义：

- `CODEX_FLOOR=2`：最低并行 worker 数，适合小项目。
- `AUDIT_FALLBACK_ENABLE=false`：先用明确 issue 驱动，避免系统自动找活。
- `DEFAULT_ISSUE_INTAKE_ENABLE=false`：先手动挑 issue 进入 managed flow。
- `ROLLUP_AUTO_MERGE=manual`：rollup PR 保留人工 merge。
- `RELEASE_AUTO_ENABLE=false`：release 自动化关闭。
- `RUNTIME_RETENTION_ENABLE=false`：runtime cleanup 关闭，方便初期观察。
- `HOST_WORK_LANGUAGE=zh`：GitHub 评论、issue、PR 等外部文本用中文。

成熟项目可以逐步打开：

```bash
export AUDIT_FALLBACK_ENABLE="true"
export DEFAULT_ISSUE_INTAKE_ENABLE="true"
export RUNTIME_RETENTION_ENABLE="true"
```

## 8. 项目规则文件

`PROJECT_RULES` 默认是 `CLAUDE.md`：

```bash
export PROJECT_RULES="CLAUDE.md"
```

这个文件是 worker 读项目约束的入口。建议同时维护：

```text
AGENTS.md
CLAUDE.md
README.md
```

`AGENTS.md` / `CLAUDE.md` 至少写清：

- 默认语言。
- build/test 命令。
- 代码风格和注释规则。
- 测试放置规则。
- 删除操作确认规则。
- GitHub / PR / issue 约定。
- 当前产品目标和近期边界。

运行 fixed point probe：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli check-project-rules
```

如果它写出 `.refactor-loop/runs/project-rules-fixed-point.patch` 并非 0 退出，先处理规则文件，再进入 daemon / worker。

## 9. 准备 GitHub labels

先验证本地 catalog：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels validate-catalog
```

查看 GitHub drift plan：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels check-github --plan
```

创建一个 design issue 至少需要这三个 label：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels design-issue-labels
```

当前输出：

```text
crnd:lifecycle:managed,crnd:phase:design-solving,crnd:human:auto
```

第一次接入时，用 `gh label create` 按 plan 创建缺失的 `crnd:*` labels。label 写入会改变 GitHub repo，执行前先确认计划。历史非 `crnd:*` labels 可以保持原状。

示例：

```bash
gh label create "crnd:lifecycle:managed" --repo "$GH_REPO_SLUG" --color "1f6feb" --description "Consensus R&D managed item"
gh label create "crnd:phase:design-solving" --repo "$GH_REPO_SLUG" --color "0969da" --description "Consensus R&D design consensus phase"
gh label create "crnd:human:auto" --repo "$GH_REPO_SLUG" --color "2da44e" --description "Consensus R&D auto-routed item"
```

颜色和描述以 `check-github --plan` 的实际输出为准。

## 10. 首次启动 daemon

注入 host facts：

```bash
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
```

验证 baseline：

```bash
bash -lc "$BUILD_CMD"
bash -lc "$TEST_CMD"
```

启动或修复 daemon：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
```

读取状态：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli peek
```

正常情况下会维护 7 个 daemon：

```text
concurrency_monitor
comment-monitor
codex-progress-reporter
dev_sync_daemon
phase9_router_daemon
closed_label_reconciler
wakeup_runner_daemon
```

`daemon-status --json` 中理想状态：

```text
status: running
heartbeat_status: fresh
fingerprint_current: true
duplicate_canonical_wrappers: 0
```

有 `stale` / `dead` 时执行：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
```

## 11. 创建第一个 managed issue

先按 `.github/ISSUE_TEMPLATE/managed-work-unit.yml` 的字段结构写一个具体、可执行、范围清楚的 GitHub issue。即使用 `gh issue create` 手动创建，也保持同一组 section，方便新会话、worker 和 reviewer 使用一致的上下文合同。

最小 body 结构：

```markdown
## Problem

描述具体问题、风险或缺失能力。

## Goal

描述期望终态和可观察结果。

## Context refs

- `CLAUDE.md`
- `AGENTS.md`
- `.docs/ai-worker-context.md`
- `<task-specific repo path or path#heading>`

## Task-local facts

只写本任务临时事实；持久事实应进入 repo docs。

## Scope

列出授权修改的文件、模块、命令或行为面。

## Out of scope

列出本任务保持不动的边界。

## Verification

- `swift build`
- `swift test`
- `<manual QA or guard command>`

## Review checklist

- Worker output includes `Context proof`.
- Scope and out-of-scope are preserved.
- Verification commands are recorded.
- `.refactor-loop/` remains runtime/cache/log state only.
```

命令示例：

```bash
ISSUE_BODY="$(mktemp /tmp/managed-issue.XXXXXX.md)"
cat > "$ISSUE_BODY" <<'EOF'
## Problem

Current managed workers need a bounded task description with explicit context.

## Goal

Deliver one observable, reviewable change without expanding beyond the stated scope.

## Context refs

- `CLAUDE.md`
- `AGENTS.md`
- `.docs/ai-worker-context.md`
- `.docs/dfx-open-save-dialog-companion.md#relevant-section`

## Task-local facts

- Replace this with facts that apply only to this issue.

## Scope

- Replace this with authorized files, modules, commands, or behavior surfaces.

## Out of scope

- Replace this with preserved boundaries.

## Verification

- `swift build`
- `swift test`

## Review checklist

- Worker output includes `Context proof`.
- Scope and out-of-scope are preserved.
- Verification commands are recorded.
- `.refactor-loop/` remains runtime/cache/log state only.
EOF

gh issue create \
  --repo "$GH_REPO_SLUG" \
  --title "P0: dialog companion clipboard jump" \
  --body-file "$ISSUE_BODY" \
  --label "crnd:lifecycle:managed" \
  --label "crnd:phase:design-solving" \
  --label "crnd:human:auto"
```

好的 issue 需要包含：

- `Problem`：问题背景、风险或缺失能力。
- `Goal`：目标行为和可观察结果。
- `Context refs`：worker 必读的 repo paths 或 path plus heading/anchor。
- `Task-local facts`：本任务临时事实。
- `Scope`：授权修改范围。
- `Out of scope`：保持不动的边界。
- `Verification`：build、test、guard、manual QA。
- `Review checklist`：context proof、scope、verification、runtime boundary 检查点。

issue 创建后，`phase9_router_daemon` 会发现 open managed design issue，并派发第一轮 solver triplet：

```text
minimal
structural
delete
```

三个 solver 都完成后，router 会派发 meta-judge。meta-judge 可能输出：

- `consensus`：进入实现或后续 route。
- `converge`：继续下一轮 solver。
- meta-layer route：进入 reflector / re-design / human decision 等流程。

## 12. 观察工作流

常用命令：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli peek
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli wakeup-plan
```

查看进程：

```bash
ps -eo pid,ppid,stat,etime,command | rg 'consensus-rnd-cli|spawn-codex|phase9'
```

查看 logs：

```bash
tail -n 80 .refactor-loop/logs/phase9_router_daemon.log
tail -n 80 .refactor-loop/logs/wakeup_runner_daemon.log
tail -n 80 .refactor-loop/logs/concurrency_monitor.log
```

查看某个 issue 的 run artifact：

```bash
find .refactor-loop/runs -maxdepth 1 -type f -name 'phase9-issue<N>-*.md' -print | sort
find .refactor-loop/logs -maxdepth 1 -type f -name 'phase9-issue<N>-*.log' -print | sort
```

GitHub 上看：

```bash
gh issue view <N> --repo "$GH_REPO_SLUG" --comments
gh issue view <N> --repo "$GH_REPO_SLUG" --json labels,state,title,updatedAt
```

## 13. 日常操作节奏

建议 maintainer 的日常循环：

1. 写清一个 GitHub issue。
2. 加 `crnd:lifecycle:managed`、`crnd:phase:design-solving`、`crnd:human:auto`。
3. 等 daemon 派发 solver / judge。
4. 看 GitHub comments 和 labels。
5. 如需干预，在 issue 里评论明确的新约束。
6. 需要重开设计时，加 `crnd:triage:resume-requested`。
7. PR 出来后按 review gate 观察。

维护者可以随时在 issue 里补充：

```text
Scope update:
- Keep implementation inside Sources/DialogJumper.
- Add tests under Tests/DialogJumperTests.
- Treat Accessibility permission UX as out of scope for this issue.
```

comment-monitor 会读取 maintainer comment，并让后续 worker 使用它作为上下文。

## 14. 常见状态含义

`crnd:lifecycle:managed`：该 issue/PR 由 Consensus R&D 管理。

`crnd:phase:design-solving`：设计共识中。

`crnd:phase:implementing`：实现中。

`crnd:phase:pr-open`：已有 PR。

`crnd:phase:merged`：已合并。

`crnd:human:auto`：自动流转。

`crnd:human:maintainer-decision`：需要 maintainer 介入判断。

`crnd:triage:resume-requested`：maintainer 请求基于新信息继续。

## 15. daemon 分工

`concurrency_monitor`：维护 worker 并发和 statusline snapshot。

`comment-monitor`：监听 maintainer 评论和 triage 信号。

`codex-progress-reporter`：汇总 worker 进度。

`dev_sync_daemon`：维护 integration branch 与 review base 的同步。

`phase9_router_daemon`：设计共识 router，负责 issue intake、solver triplet、meta-judge、converge 等 route。

`closed_label_reconciler`：修正 closed managed item 的 phase-label drift。

`wakeup_runner_daemon`：消费 `wakeup-plan` 的 closed action projection，执行调度动作。

## 16. 排障

### CLI 报 host.env 缺失

检查：

```bash
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
test -f "$CONSENSUS_RND_HOST_ENV"
source "$CONSENSUS_RND_HOST_ENV"
```

### daemon stale / dead

执行：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
```

### worker 卡住

先看是否还有 `spawn-codex`：

```bash
ps -eo pid,ppid,stat,etime,command | rg 'spawn-codex|phase9-issue'
```

再看对应 log：

```bash
tail -n 120 .refactor-loop/logs/phase9-issue<N>-r<R>-<role>.log
```

普通 routing 依赖 clean `EXIT=0` 和 marker。log 异常、stream disconnect、timeout、缺 marker 时，再看 `wakeup-plan`：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli wakeup-plan
```

### label 漏建

执行：

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels validate-catalog
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels check-github --plan
```

按 plan 补 label。

### GitHub auth 异常

执行：

```bash
gh auth status
gh repo view "$GH_REPO_SLUG"
```

`current_github_login` 在 `daemon-status` 里为空时，优先确认 `gh auth status`。

### build/test 在 worker worktree 失败

在一个临时 worktree 模拟：

```bash
git worktree add .worktrees/smoke-test HEAD
cd .worktrees/smoke-test
export CONSENSUS_RND_HOST_ENV=../../.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
bash -lc "$BUILD_CMD"
bash -lc "$TEST_CMD"
```

如果失败，把依赖安装步骤加进 `BUILD_CMD` / `TEST_CMD` 或封装成 repo 内脚本。

删除 `.worktrees/smoke-test` 前先走项目删除确认流程。

## 17. 多项目使用建议

每个项目维护自己的：

```text
.tools/consensus-rnd
.config/consensus-rnd/host.env
.refactor-loop
.worktrees
```

README 记录工具版本：

```text
Repo: https://github.com/ChronoAIProject/consensus-rnd
Ref: dev
Commit: <sha>
```

这样同时打开多个项目时，daemon 命令路径、`REPO_ROOT`、`.refactor-loop`、GitHub repo 都属于当前项目。全局 skill 适合快速试跑；项目本地工具副本适合长期复现。

## 18. 更新工具版本

先停旧 daemon：

```bash
ps -eo pid,ppid,stat,etime,command | rg 'consensus-rnd-cli|spawn-codex'
```

确认没有关键 worker 在写当前 issue 后，执行：

```bash
git -C .tools/consensus-rnd fetch origin
git -C .tools/consensus-rnd checkout <new-sha>
chmod +x .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli
```

更新 README 里的 pinned commit。

重启 daemon：

```bash
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
```

## 19. 停用和回滚

临时停 daemon：

```bash
ps -eo pid,ppid,stat,etime,command | rg 'consensus-rnd-cli|spawn-codex'
```

对确认属于当前项目的 PIDs 发送 `TERM`：

```bash
kill -TERM <pid...>
```

删除目录属于永久操作，先列出路径并确认。常见路径：

```text
.tools/consensus-rnd
.refactor-loop
.worktrees
~/.codex/skills/consensus-loop
```

`host.env` 可以保留在本机，便于以后恢复。若它已经被 git tracking，使用：

```bash
git rm --cached .config/consensus-rnd/host.env
```

这个命令只移出 git index，本地文件仍保留。

## 20. 新项目最短 checklist

```bash
# 1. baseline
bash -lc "<build command>"
bash -lc "<test command>"

# 2. tool checkout
mkdir -p .tools
git clone --branch dev https://github.com/ChronoAIProject/consensus-rnd .tools/consensus-rnd
git -C .tools/consensus-rnd checkout abd6db05c508563e1e6fe17abf15925cc0fe8172
chmod +x .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli

# 3. optional runtime-only cleanup
# Follow "可选：清理无效内容" after confirming the pinned commit and delete scope.

# 4. host env
mkdir -p .config/consensus-rnd
cp .tools/consensus-rnd/skills/consensus-loop/host.env.example .config/consensus-rnd/host.env
$EDITOR .config/consensus-rnd/host.env
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"

# 5. local checks
bash -lc "$BUILD_CMD"
bash -lc "$TEST_CMD"
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels validate-catalog
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli labels check-github --plan

# 6. daemon
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json

# 7. first issue
ISSUE_BODY="$(mktemp /tmp/managed-issue.XXXXXX.md)"
$EDITOR "$ISSUE_BODY"
gh issue create \
  --repo "$GH_REPO_SLUG" \
  --title "P0: <concrete work item>" \
  --body-file "$ISSUE_BODY" \
  --label "crnd:lifecycle:managed" \
  --label "crnd:phase:design-solving" \
  --label "crnd:human:auto"
```

## 21. 维护原则

- 提交 README 和 `host.env.example`，保留本机 `host.env`。
- 工具源码 pin 在 `.tools/consensus-rnd`，通过 README 记录版本。
- 所有 runtime state 留在 `.refactor-loop/`。
- 所有 worker worktree 留在 `.worktrees/`。
- GitHub issue / label / comment 是人类观察主界面。
- 删除、清理、停止大量 worker 前先列路径或 PID。
- 初期用明确 managed issue 驱动，等工作流稳定后再打开 audit fallback。
