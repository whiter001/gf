# gf - Unified CLI for GitHub / GitLab / Gitee

gf is a unified CLI tool that provides consistent commands across GitHub, GitLab, and Gitee platforms.

## Platform Detection

gf auto-detects the platform from the git remote URL. You can also specify manually:
- `--platform=github|gitlab|gitee`
- `--api-base` for self-hosted instances
- `--project-id` for GitLab numeric project ID

## Token Precedence

```
GH_TOKEN/GITHUB_TOKEN/GITLAB_TOKEN/GL_TOKEN/GITEE_TOKEN > GF_TOKEN > --token flag
```

## Core Commands

### issue - Issue Management
```bash
# List issues
gf issue list [--state open|closed|all] [--limit N]

# Show issue details
gf issue show <number>

# Create issue
gf issue create --title "Title" [--body "description"]

# Close issue
gf issue close <number>

# Comment on issue
gf issue comment <number> --body "comment text"
```

### pr - Pull Request / Merge Request
```bash
# List PRs/MRs
gf pr list [--state open|closed|merged|all] [--limit N]

# Show PR/MR details
gf pr show <number>

# Create PR/MR
gf pr create --title "Title" --head <branch> --base <branch> [--body "description"]

# Merge PR/MR
gf pr merge <number> [--method merge|squash|rebase]

# Close PR/MR
gf pr close <number>

# Comment on PR/MR
gf pr comment <number> --body "comment text"
```

### release - Release Management
```bash
# List releases
gf release list [--limit N]

# Show release details
gf release show <tag>

# Create release
gf release create --tag <tag> [--name "name"] [--notes "release notes"]
```

### ci - CI/CD Pipeline
```bash
# List CI runs/pipelines
gf ci list [--limit N]

# Check CI status
gf ci status [--run <id>]

# Trigger CI run
gf ci run --ref <branch> [--workflow <file>]

# View CI logs
gf ci logs <id>
```

### repo - Repository Operations
```bash
# Clone repository
gf repo clone <url> [directory]

# Create repository
gf repo create [--private] [--description "desc"] [--homepage URL]

# Fork repository
gf repo fork

# Sync forked repository
gf repo sync
```

### api - Generic API Caller
```bash
gf api --method GET|POST|PUT|PATCH|DELETE --path /api/path [--body '{"key":"value"}']
```
Example:
```bash
gf api --method GET --path /repos/o/r
gf api --method POST --path /user/repos --body '{"name":"my-repo","private":true}'
```

### search - Search
```bash
gf search --type repositories|code|commits|issues --query <text>
```
Examples:
```bash
gf search --type repositories --query "vue3"
gf search --type issues --query "bug in:title"
```

### label - Label Management
```bash
# List labels
gf label list

# Create label
gf label create --label-name <name> --color <RRGGBB|color-name>

# Delete label
gf label delete <name>
```

### gist - Code Snippets
GitHub: gists | GitLab: snippets
```bash
# List snippets
gf gist list [--limit N]

# Show snippet
gf gist show <id>

# Create snippet
gf gist create --file <path> [--gist-description "desc"] [--public]

# Delete snippet
gf gist delete <id>
```

### milestone - Milestone Management
```bash
# List milestones
gf milestone list [--state open|closed|all]

# Show milestone
gf milestone show <number>

# Create milestone
gf milestone create --milestone-title <title> [--milestone-desc "desc"] [--due-date YYYY-MM-DD]

# Close milestone
gf milestone close <number>
```

### secret - Secrets Management
GitHub: Actions secrets (requires encryption) | GitLab: CI variables
```bash
# List secrets/variables
gf secret list

# Create secret/variable
gf secret create --secret-name <name> --value <value>

# Delete secret/variable
gf secret delete <name>
```

### workflow - GitHub Actions Workflows (GitHub Only)
```bash
# List workflows
gf workflow list

# View workflow file
gf workflow view <workflow-file>

# Trigger workflow
gf workflow run <workflow-file> [--ref <branch>]
```

## Global Flags

| Flag | Description |
|------|-------------|
| `-j, --json` | JSON output |
| `-q, --quiet` | Suppress non-essential output |
| `-R, --repo OWNER/REPO` | Override repo |
| `--platform` | Force platform: github/gitlab/gitee |
| `--api-base URL` | Override API base URL |
| `--token TOKEN` | API token |
| `--project-id ID` | GitLab numeric project ID |

## Examples

### GitLab Self-Hosted
```bash
gf --platform=gitlab --api-base=http://git.example.com/api/v4 --project-id=1234 issue list
```

### Create Issue with Body from File
```bash
gf issue create --title "Bug" --body-file - < description.txt
```

### Search Issues
```bash
gf search --type issues --query "authentication error"
```

## Exit Codes

- 0: Success
- 1: API/network/config error
- 2: Usage error
