# CLAUDE.md

本文件是 `consensus-rnd` 的项目规则入口，内容与 `AGENTS.md` 保持同一语义。

## 目标

- 先跑通 `consensus-loop` 的 host 接入、只读状态面、daemon 管理和 issue-driven 主路径。
- App 第一阶段只验证 `Open / Save dialog` 检测、贴边 `NSPanel`、`Command+Shift+G` 跳转闭环。
- 功能开发必须围绕小闭环推进，所有较大设计变更先进入 GitHub issue 让 consensus 流程处理。

## 代码规则

- Swift/AppKit 是主技术栈。
- 核心逻辑保持高内聚、低耦合，避免提前引入复杂抽象。
- 新增测试放入 `Tests/` 下最接近被测模块的位置。
- 注释使用中文，代码实体和技术术语保持英文。
- 禁止用假实现、假数据或空逻辑伪装功能完成。

## consensus-rnd 运行规则

- host 配置位于 `.config/consensus-rnd/host.env`。
- `.refactor-loop/` 是 `consensus-loop` 运行态目录，不能作为产品事实来源。
- 自动 release、rollup auto merge、audit fallback、default issue intake 在本地试跑初期保持关闭。
- 启动 daemon 或 worker 前必须先让 `swift build` 和 `swift test` 在主 checkout 绿色。

## AI worker execution context

- Managed AI workers 在 planning、implementation、review 前始终读取 `CLAUDE.md`、`AGENTS.md`、`.docs/ai-worker-context.md`。
- Issue 的 `Context refs` 字段按 repo path 或 repo path plus heading/anchor 选择任务专属文档；长背景材料保持 referenced-only。
- Worker output 必须包含 `Context proof`，说明 always-on docs、task refs、scope check、verification 与 context gaps/staleness。
- Review 使用 issue `Context refs`、worker `Context proof`、scope/out-of-scope、verification commands 与 `.refactor-loop/` runtime/cache/log 边界作为共同检查面。
- `.refactor-loop/` 只承载 runtime、cache、log、state、prompt、run artifacts；产品事实进入 host-owned config、rules、docs 或 source files。

## 当前基线命令

```bash
swift build
swift test
```
