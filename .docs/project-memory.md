# Project Memory

## Purpose

`project memory` 是 bounded、source-linked、referenced-only 的项目事实索引。它保存跨 issue 仍然有效的少量 durable facts，并把每条事实指向一个最小 durable home。

Workers 默认读取 `CLAUDE.md`、`AGENTS.md`、`.docs/ai-worker-context.md`。只有 issue `Context refs`、review gate 或 `post-completion harvest` 明确需要时，才读取本文件。

## Stable constraints

- ID: PM-001
  Fact: `.refactor-loop/` 只承载 runtime、cache、log、state、prompt、run artifacts；产品事实进入 host-owned config、rules、docs、source files。
  Source: `CLAUDE.md` / `AGENTS.md` / `.docs/ai-worker-context.md`
  Durable home: `CLAUDE.md`、`AGENTS.md`、`.docs/ai-worker-context.md`
  Last checked: issue #6
- ID: PM-002
  Fact: Managed AI workers 在 planning、implementation、review 前读取 `CLAUDE.md`、`AGENTS.md`、`.docs/ai-worker-context.md`，任务专属背景通过 issue `Context refs` 选择。
  Source: `CLAUDE.md` / `AGENTS.md` / `.docs/ai-worker-context.md`
  Durable home: `.docs/ai-worker-context.md`
  Last checked: issue #6
- ID: PM-003
  Fact: `dialog-jumper` 当前阶段聚焦 Open / Save dialog 检测、贴边 `NSPanel`、`Command+Shift+G` 跳转闭环。
  Source: `README.md` / `CLAUDE.md` / `.docs/ai-worker-context.md`
  Durable home: `README.md`、`.docs/ai-worker-context.md`
  Last checked: issue #6
- ID: PM-004
  Fact: 完成 work unit 时必须执行 `post-completion harvest`，把 durable facts 放入最小 durable home：project memory、execution context、SOP、product research docs、source/tests 或 issue/PR record。
  Source: issue #6 consensus decision
  Durable home: `.docs/project-memory.md`、`.docs/ai-worker-context.md`、`.docs/consensus-rnd-sop.md`
  Last checked: issue #6

## Destination matrix

Use the smallest durable home that will be read by the next owner.

- Stable cross-issue constraint: `.docs/project-memory.md`
- Always-read worker rule: `.docs/ai-worker-context.md` or project rules
- Consensus runtime procedure: `.docs/consensus-rnd-sop.md`
- Product, UI, Accessibility, or automation research: `.docs/dfx-open-save-dialog-companion.md`
- Executable behavior or contract: source code and nearest tests
- One-off task decision with low reuse value: GitHub issue or PR record
- Machine-local runtime value: tool-specific ignored runtime config
- Controller runtime artifact: `.refactor-loop/`

## Post-completion harvest

At completion time:

1. Scan implementation notes, review findings, and PR body for durable facts.
2. Classify each fact with the destination matrix.
3. Update the smallest durable home inside the authorized scope.
4. If the right home is outside scope, add a `Harvest queue` item with source, target home, and reason.
5. If no durable fact remains, record that result in the worker summary or PR body.

## Harvest queue

No open harvest items.

Queue item format:

- Source:
  Durable fact:
  Target home:
  Reason:

## Record guidance

Keep this file compact. Each record should include:

- ID
- Fact
- Source
- Durable home
- Last checked
- When to revisit, when useful

Prefer links to existing durable homes over duplicating long background. Move detailed product research into product docs and keep this file as the routing index.
