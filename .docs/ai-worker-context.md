# AIWorkerContextContract

## Purpose

给 managed AI workers 一个短、稳定、始终读取的执行上下文入口；任务专属背景由 issue `Context refs` 精确引用。

## Always-on context

Managed AI workers 在 planning、implementation、review 前始终读取：

- `CLAUDE.md`
- `AGENTS.md`
- `.docs/ai-worker-context.md`

## Referenced-only context

Issue `Context refs` 使用 repo path 或 repo path plus heading/anchor 选择任务文档。
Catalog entries 使用四个字段：
- Repo path：仓库内相对路径。
- Heading/anchor：可选 heading、anchor 或 line-stable section 名。
- When to load：触发读取的任务类型或判断条件。
- Owner responsibility：维护该文档新鲜度的责任边界。
Initial catalog:
- Repo path: `README.md`
  Heading/anchor: `Consensus R&D Local Tooling`
  When to load: 需要快速了解 product status、本地工具 pin、host runtime setup 时。
  Owner responsibility: Maintainer 更新 product quick status 与本地 tooling 入口。
- Repo path: `.docs/consensus-rnd-sop.md`
  Heading/anchor: 相关运行章节
  When to load: 任务涉及 `consensus-loop` runtime、controller/worker boundary、daemon、labels、host.env 时。
  Owner responsibility: Consensus runtime owner 更新 workflow 与边界规则。
- Repo path: `.docs/project-memory.md`
  Heading/anchor: `Stable constraints` 或 `Harvest queue`
  When to load: 任务需要跨 issue durable facts、post-completion harvest、destination decision 或 review memory gate 时。
  Owner responsibility: Consensus runtime owner 保持 records bounded、source-linked、referenced-only。
- Repo path: `.docs/dfx-open-save-dialog-companion.md`
  Heading/anchor: 相关 product、UI、automation research section
  When to load: 任务涉及 Open / Save dialog companion、DFX 对标、Accessibility、Automation、overlay UI 时。
  Owner responsibility: Product/UX owner 更新研究结论、MVP scope 与风险。
Budget: keep this section at 24-30 lines until split.
Split trigger: move catalog to `.docs/task-context-index.md` when this section exceeds 30 lines, catalog needs more than 6-8 repo docs, ownership boundaries conflict, or reviews repeatedly find missed task refs.

## Product stage

`dialog-jumper` 处于 early MVP exploration。第一阶段验证 Open / Save dialog 检测、贴边 `NSPanel`、`Command+Shift+G` 跳转闭环。

## UI and interaction tone

Companion UI 应该轻量、贴近系统 dialog、减少焦点干扰。优先验证真实工作流体验，再扩大 favorites、Finder windows、recent folders。

## Architecture boundaries

- Swift/AppKit 是主技术栈。
- `.refactor-loop/` 只承载 runtime、cache、log、state、prompt、run artifacts。
- Product facts 属于 host-owned config、rules、docs、source files。
- Cross-issue durable facts 属于 source-linked `project memory` 或对应 owner 文档；`.refactor-loop/` artifact 只作为发现来源。
- 大设计变更先进入 GitHub issue 与 consensus 流程。

## Technical constraints

- 不做进程注入，不关闭 SIP，不替换系统 dialog。
- 外部 app 的 `NSOpenPanel` / `NSSavePanel` 通过 Accessibility 与标准 keyboard flow 间接驱动。
- Tests 放入 `Tests/` 下最接近被测模块的位置。

## Quality gates

- `swift build`
- `swift test`
- Issue 指定的 verification commands
- 相关 architecture guards

## Manual QA

涉及 UI、Accessibility、Automation 或 Open / Save dialog 的任务，应记录手动验证 app、dialog 类型、权限状态、跳转目标与失败现象。

## Known exclusions

首版排除 Finder toolbar integration、license system、metadata editing、full DFX drawer、screen recording 依赖与跨进程 private API。

## Worker Context proof

Worker output 必须包含 `Context proof`，最低覆盖：

- Always-on docs read
- Task refs read
- Scope check
- Verification performed
- Post-completion harvest result and durable home decisions
- Context gaps/staleness

## Review checklist

Review 必须检查：

- Issue `Context refs` 是否覆盖任务专属 repo docs。
- Worker `Context proof` 是否列明已读 context 与 gaps。
- Scope 与 out-of-scope 是否与 issue/template 一致。
- Verification commands 是否真实运行并记录结果。
- Durable facts 是否完成 `post-completion harvest`，或进入 `.docs/project-memory.md` 的 `Harvest queue`。
- `.refactor-loop/` 是否仍只作为 runtime/cache/log boundary。

## Freshness rule

当 issue、review 或实现发现 task refs 缺失、catalog 超出预算、owner boundary 冲突、文档 stale 或 durable fact 无 owner，优先更新本 contract、`.docs/project-memory.md` 或拆分到 `.docs/task-context-index.md`，再继续扩大 worker prompt prose。
