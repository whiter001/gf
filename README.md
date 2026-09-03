# gf

`gf` 是一套用 [V 语言](https://vlang.io) 编写的命令行工具，用同一套命令统一操作 **GitHub / GitLab / Gitee** 上的 Pull Request（GitLab 即 Merge Request）、Issue、Release 与 CI。

- 自动识别当前仓库 `git remote get-url origin` 对应的平台与 owner/repo（GitLab 支持多级 subgroup，路径自动做 `%2F` 编码）。
- 三平台子命令与参数完全一致，底层各自映射到平台 REST API。
- 面向脚本与 AI Agent：`--json` 稳定输出、规范退出码、`--body-file -` / `--notes-file -` 从 stdin 读内容、错误输出到 stderr 且不泄露 token。

## 构建

```powershell
.\build.ps1          # 构建并将 gf.exe 链接到 D:\public\gf.exe
v test src/           # 运行单元测试与本地 mock 集成测试
```

> 当前环境若遇到 v3 编译器内存限制，可显式使用稳定编译器：`v -old-compiler -o gf src/`。

如需只生成仓库内的可执行文件，也可以运行 `v -o gf src/`。

## 用法

```
gf [global flags] <command> [subcommand] [flags] [args]
```

### 全局参数

| 参数 | 说明 |
| --- | --- |
| `-j, --json` | 成功时 stdout 输出原始 API JSON；失败时 stderr 输出 `{"error":{...}}` |
| `-q, --quiet` | 精简输出 |
| `-R, --repo OWNER/REPO` | 覆盖从 git remote 识别的仓库（多级路径如 `group/sub/proj`） |
| `--platform P` | 强制平台：`github` / `gitlab` / `gitee` |
| `--api-base URL` | 覆盖 API 地址（自建实例、mock 等） |
| `--token TOK` | API token（优先级见下） |

token 解析优先级（依序）：

1. 平台专用环境变量：GitHub `GH_TOKEN` / `GITHUB_TOKEN`，GitLab `GITLAB_TOKEN` / `GL_TOKEN`，Gitee `GITEE_TOKEN`
2. 通用环境变量 `GF_TOKEN`
3. 命令行 `--token`

> 说明：显式 `--token` 优先级最低，是为了防止脚本误覆盖环境中已配置的凭据；若希望 `--token` 生效，请先清空对应环境变量。

### 命令

```
remote                       查看识别的平台 / owner / repo / api-base
pr|issue:
  list   [--state open|closed|merged|all] [--limit N]
  show   <number>
  create --title T [--body TEXT | --body-file -] [--head BRANCH --base BRANCH]
  merge  <number> [--method merge|squash|rebase]     # 仅 pr；GitLab 仅支持 merge|squash
  close  <number>
  comment <number> --body TEXT | --body-file -
release:
  list   [--limit N]
  show   <tag>
  create --tag TAG [--name NAME] [--notes TEXT | --notes-file -]
ci:
  list   [--limit N]
  status [--run ID]                     # 省略时展示最近一次 run/pipeline
  run    [--ref BRANCH] [--workflow FILE]  # GitHub 需 --workflow；GitLab 走 POST pipeline
  logs   <id>                           # GitHub: run id，保存为 zip 文件；GitLab: job id，输出 trace
version                                 # 或 --version
```

### 退出码

| 退出码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | API / 网络 / 配置 / 不支持错误 |
| 2 | 用法错误（未知命令、参数缺失、非法取值） |

### 示例

```sh
# 在仓库目录内直接使用（自动识别 remote）
gf remote
gf pr list --json
gf issue create --title "fix login bug" --body-file - < body.txt
gf release create --tag v1.0.0 --notes "first release"
gf ci status

# 指定仓库与平台（不依赖 git remote）
gf --platform gitlab -R group/sub/project pr list --state all --limit 10
gf --platform gitee  -R owner/repo issue list --json
```

## 平台映射说明

- **GitHub**：`api.github.com`，PR/Issue 走 `/repos/{owner}/{repo}/...`，鉴权 `Authorization: Bearer`。
- **GitLab**：`gitlab.com/api/v4`（或自建 `https://<host>/api/v4`），MR/Issue 走 `/projects/{path}/...`，多级 subgroup 路径以 `%2F` 编码，鉴权 `PRIVATE-TOKEN`。
- **Gitee**：`gitee.com/api/v5`（或自建），走 `/repos/{owner}/{repo}/...`，鉴权为 query 参数 `access_token`。
- **自建实例**：remote host 含 `github/gitlab/gitee` 关键字时自动识别；其他 host 需 `--platform` + `--api-base` 显式指定。
- **`pr merge --method`**：GitHub 传 `merge_method`（merge/squash/rebase），Gitee 传 `merge_method`（同），GitLab 传 `squash` 布尔参数（GitLab merge API 无 rebase 合并方式，`--method rebase` 在 GitLab 上报用法错误、退出码 2）。
- **Gitee CI**：Gitee Go 无稳定公开 API，`ci` 系列命令对 Gitee 明确报错（退出码 1）。

## 已知限制（v1）

- release 资产上传（GitHub 直传 / GitLab URL link / Gitee attach_files 协议差异大）暂不实现，仅支持 release 本体创建。
- 列表仅取单页，通过 `--limit` / `per_page` 控制条数，不做完整翻页。
- GitHub `ci logs` 返回 zip，自动保存为 `gf-run-<id>-logs.zip`；GitLab `ci logs` 输出 job trace 文本。
