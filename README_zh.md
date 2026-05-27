# CodeWiki

<p align="center">
  <img width="768" alt="CodeWiki" src="assets/logo.png" />
</p>

<p align="center">
  <a href="README.md">English</a> | <b>中文</b>
</p>

AI 驱动的代码知识库生成器。将任意源码仓库转换为由 AI 编程助手维护的、结构化、可搜索的 wiki。

## 灵感来源

- [Andrej Karpathy 的 LLM Wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) —— 将知识一次性编译为相互链接的 markdown 文件，并由 LLM 持续维护的理念。
- [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki) —— 架构改编自这套面向 AI 维护型知识库的 skill 框架。

## 三层架构

```
┌─────────────────────────────────────────────────────┐
│  第 3 层：Schema（本仓库）                            │
│  规则、模板、skill —— 告诉 LLM 如何工作              │
├─────────────────────────────────────────────────────┤
│  第 2 层：Wiki（由 LLM 维护）                        │
│  编译后的知识 —— 已综合、已交叉引用                  │
├─────────────────────────────────────────────────────┤
│  第 1 层：原始源码（你的代码仓库）                    │
│  事实来源 —— 永不会被 wiki 修改                      │
└─────────────────────────────────────────────────────┘
```

| 层级 | 角色 | 维护者 |
|---|---|---|
| **原始源码** | 你的源代码 —— `.ts`、`.py`、`.go`、`.java`、`.rs`、配置、测试 | 你（开发者） |
| **Wiki** | 编译后的知识 —— 架构、模块、流程、决策 | LLM（通过 skill） |
| **Schema** | 管控 wiki 结构的规则 —— 分类、模板、约定 | 本仓库 |

Wiki 是代码库的 **读优化投影**。它用写入时的算力（LLM 分析）换取读取时的速度（从预编译的页面中获得即时回答）。

## Wiki 层目录结构

默认的 wiki 结构定义在 [`schema/wiki-structure.yaml`](schema/wiki-structure.yaml)：

| 目录 | 标签 | 用途 |
|---|---|---|
| `01-overview/` | 项目总览 | 仓库是做什么的 —— 背景、技术栈、入口 |
| `02-architecture/` | 架构说明 | 代码如何组织 —— 分层、组件、边界 |
| `03-modules/` | 模块说明 | 每个模块做什么 —— 职责、关键文件、API |
| `04-flows/` | 流程说明 | 功能端到端如何运作 —— 调用链、数据流 |
| `05-config/` | 配置说明 | 每项配置的作用 —— 环境变量、默认值、影响 |
| `06-testing/` | 测试说明 | 如何测试 —— 策略、结构、覆盖率 |
| `07-ops/` | 排障手册 | 出问题时怎么办 —— 错误、调试、修复 |
| `08-decisions/` | 决策记录 | 为什么这样设计 —— ADR、权衡 |

## 安装

```bash
npx skills add xiaoxiang/CodeWiki
```

或手动克隆：

```bash
git clone https://github.com/xiaoxiang/CodeWiki.git ~/CodeWiki
cd ~/CodeWiki
./install.sh
```

`install.sh` 会创建 `.env`、将全局配置写入 `~/.code-wiki/config`，并把 skill 通过 symlink 链接到所有受支持的 AI agent。

## 使用指南

安装完成后，你可以在任意代码仓库中通过斜杠命令调用对应的 skill。下面按使用顺序介绍：

### 第一步：生成 Wiki —— `/code-wiki-ingest`

安装完成后，在你的 AI 助手（Claude Code、Cursor、Windsurf 等）中打开目标仓库，**在助手的对话框里输入斜杠命令**，而不是在终端里执行：

```text
# 在 AI 助手的对话窗口中（不是 shell！）：
/code-wiki-ingest
```

> 终端只用于 `cd` 进入项目（或在编辑器里打开它）。所有 `/code-wiki-*` 命令都是在 LLM 对话中调用的 —— AI 助手会读取 `.skills/` 下对应的 skill 文件并执行。

该 skill 会完成以下工作：

- **扫描仓库结构**：遍历源码目录、读取 README、解析 package metadata 与 git 历史。
- **解析模块边界**：识别模块划分、依赖关系图与入口文件。
- **提取架构、API 与设计模式**：从代码中归纳系统分层、接口约定、惯用模式。
- **生成互相链接的文档页面**：按 `schema/wiki-structure.yaml` 定义的八大类目（项目总览、架构说明、模块说明、流程说明、配置说明、测试说明、排障手册、决策记录）输出带 frontmatter 的 markdown 页面，并通过 `[[wikilinks]]` 互相串联。
- **维护元数据**：写入 `.manifest.json`、更新 `index.md` 与 `log.md`。再次运行时只处理 git delta，不会重复生成。

### 日常使用：其他 Skill 的适用场景

#### `/code-wiki-query` —— 从 Wiki 中查询信息

当你想了解 “X 是做什么的”、“Y 是怎么工作的”、“Z 在哪里实现的” 时使用。它会优先检索页面标题、tags 与 frontmatter 的 `summary` 字段（快速索引模式），仅在无法回答时才打开页面正文进行深度搜索，最终返回带 `[[wikilink]]` 引用的综合答案。

```text
# 在 AI 助手的对话窗口中：
/code-wiki-query 用户登录流程是怎么实现的
```

#### `/code-wiki-lint` —— 审计 Wiki 健康状况

用于体检已生成的 wiki，检查以下问题并给出修复建议：

- 断链与失效的 `[[wikilinks]]`
- 没有被任何页面引用的孤立页面
- 与源码已经偏离的过时内容
- 缺失或不合规的 frontmatter（`title`、`category`、`tags`、`sources`、`created`、`updated`）

```text
# 在 AI 助手的对话窗口中：
/code-wiki-lint
```

#### `/code-wiki-rebuild` —— 归档并重建 Wiki

当 wiki 与代码偏差过大、增量更新无法修复，或希望恢复到某个历史版本时使用。它支持归档当前 wiki、从零重建，以及恢复之前的快照版本。

```text
# 在 AI 助手的对话窗口中：
/code-wiki-rebuild
```

## 创建你的第一个 Wiki

安装完成后，在你的 AI 助手（Claude Code、Cursor、Windsurf、Gemini CLI 等）中打开目标仓库，然后**在助手的对话窗口里调用 ingest skill** —— 不是在 shell 里执行。

1. **在终端中**进入项目目录（或在编辑器里打开它）：

   ```bash
   cd /path/to/your/project
   ```

2. **在 AI 助手的对话窗口中**输入：

   ```text
   /code-wiki-ingest

   # 或显式指定路径：
   /code-wiki-ingest /path/to/your/project
   ```

   助手会从 `.skills/` 加载 `code-wiki-ingest` skill 并替你执行。

首次 ingest 会自动创建 `./wiki/` 目录结构，并为你的代码库生成完整的知识库。后续运行会基于 git delta 增量处理，只更新发生变化的部分。

> **注意：** `/code-wiki-*` 是 *skill 命令*，不是 shell 命令。在 bash 里运行会报 "command not found"，必须作为消息发送给基于 LLM 的编程助手。

## Skills

所有内容都位于 `.skills/`。每个 skill 是一份 markdown 文件，agent 会在被触发时读取它：

| Skill | 作用 | 触发方式 |
|---|---|---|
| `code-wiki-ingest` | 分析源码并生成 wiki 页面 | `/code-wiki-ingest` |
| `code-wiki-query` | 从已编译的 wiki 中回答问题 | `/code-wiki-query` |
| `code-wiki-lint` | 检查断链、孤立页面、过时内容 | `/code-wiki-lint` |
| `code-wiki-rebuild` | 归档、从零重建或恢复 | `/code-wiki-rebuild` |

> 斜杠命令（`/skill-name`）在 Claude Code、Cursor、Windsurf 以及大多数现代 AI agent 中均可使用。在其他工具中，描述你想做什么，agent 会自动找到合适的 skill。

## 支持的 AI 平台

适用于 **任意可读取文件的 AI 编程 agent**。`install.sh` 会自动处理各平台的 skill 发现。

| 平台 | Bootstrap 文件 | Skills 目录 |
|---|---|---|
| **Claude Code** | `CLAUDE.md` | `.cursor/skills/`（本地） |
| **Cursor** | `.cursor/rules/code-wiki.mdc` | `.cursor/skills/` |
| **Windsurf** | `.windsurf/rules/code-wiki.md` | `.windsurf/skills/` |
| **Gemini CLI** | `GEMINI.md` | `~/.gemini/skills/` |
| **Google Antigravity** | `.agent/rules/` + `.agent/workflows/` | `.agents/skills/` |
| **Codex (OpenAI)** | `AGENTS.md` | `~/.codex/skills/` |
| **Kiro** | `.kiro/steering/code-wiki.md` | `.kiro/skills/` + `~/.kiro/skills/` |
| **Hermes** | `AGENTS.md` | `~/.hermes/skills/` |
| **OpenClaw** | `AGENTS.md` | `~/.openclaw/skills/` |
| **OpenCode** | `AGENTS.md` | `~/.agents/skills/` |
| **Aider** | `AGENTS.md` | `~/.agents/skills/` |
| **Factory Droid** | `AGENTS.md` | `~/.agents/skills/` |
| **Trae / Trae CN** | `AGENTS.md` | `~/.trae/skills/` |
| **Pi** | `AGENTS.md` | `~/.pi/agent/skills/` |
| **Kilocode** | `AGENTS.md` / `CLAUDE.md` | `.agents/skills/` |
| **GitHub Copilot** | `.github/copilot-instructions.md` | `~/.copilot/skills/` |
| **Qoder** | `AGENTS.md` | `~/.qoder/skills/` |

## 配置

复制 `.env.example` 为 `.env` 并按需修改：

```bash
cp .env.example .env
```

关键变量：

| 变量 | 用途 | 默认值 |
|---|---|---|
| `CODE_WIKI_OUTPUT_PATH` | Wiki 存放位置（相对于代码仓库） | `./wiki` |
| `CODE_WIKI_LINK_FORMAT` | 链接风格：`wikilink` 或 `markdown` | `wikilink` |
| `CODE_WIKI_MAX_PAGES_PER_INGEST` | 每次 ingest 更新页面的上限 | `20` |
| `LINT_SCHEDULE` | Wiki 健康检查频率 | `manual` |

完整列表见 [`.env.example`](.env.example)。

## QMD 语义搜索（可选）

默认情况下，skill 使用 Grep/Glob 完成搜索 —— 功能完整、无需额外配置。对于大型代码库或概念级匹配的场景，可以接入 [QMD](https://github.com/tobi/qmd)：

```bash
# 为你的 wiki 与源码建索引
qmd index --name wiki /path/to/wiki
qmd index --name code /path/to/source
```

然后在 `.env` 中设置：

```env
QMD_WIKI_COLLECTION=wiki
QMD_CODE_COLLECTION=code
QMD_TRANSPORT=mcp    # mcp | cli
```

**接入 QMD 后的变化：**
- `code-wiki-query` 会在 grep 之前先执行语义搜索 —— 即使没有精确关键字匹配，也能找到概念上相关的页面
- `code-wiki-ingest` 在写入前会先查询已索引的代码 —— 浮现相关模块、识别重叠

未配置 QMD 时，两个 skill 都会优雅降级。

## 项目结构

```
CodeWiki/
├── .skills/                        # 规范的 skill 定义（事实来源）
│   ├── code-wiki/SKILL.md          # 核心模式 —— 三层架构
│   ├── code-wiki-ingest/SKILL.md   # 分析代码 → 生成 wiki
│   ├── code-wiki-query/SKILL.md    # 查询 wiki
│   ├── code-wiki-lint/SKILL.md     # 审计 wiki 健康
│   └── code-wiki-rebuild/SKILL.md  # 归档/重建/恢复
│
├── schema/
│   └── wiki-structure.yaml         # 可配置的 wiki 目录结构
│
├── CLAUDE.md                       # Bootstrap → Claude Code / Kilocode
├── GEMINI.md                       # Bootstrap → Gemini CLI / Antigravity
├── AGENTS.md                       # Bootstrap → Codex、OpenCode、Aider、Droid、Trae、Hermes、Pi
├── .cursor/rules/code-wiki.mdc     # 始终启用 → Cursor
├── .windsurf/rules/code-wiki.md    # 始终启用 → Windsurf
├── .kiro/steering/code-wiki.md     # 始终启用 → Kiro
├── .github/copilot-instructions.md # 始终启用 → GitHub Copilot (VS Code)
│
├── install.sh                       # 一键安装到 agent
├── uninstall.sh                    # 移除所有 symlink 与配置
├── .env.example                    # 配置模板
└── README.md                       # 你正在阅读
```

## 自定义 Wiki 结构

默认的 8 目录结构定义在 `schema/wiki-structure.yaml` 中。你可以自定义：

- 增加或删除分类目录
- 修改每个分类的 `sections` 列表
- 调整标签与描述
- 创建项目特定的结构

修改完成后，下一次 ingest 会按照新的结构生成页面。

完整 schema 定义见 [`schema/wiki-structure.yaml`](schema/wiki-structure.yaml)。
