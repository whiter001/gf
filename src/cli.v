module main

// Flags holds every CLI option.
struct Flags {
mut:
	json       bool
	quiet      bool
	repo       string
	platform   string
	api_base   string
	token      string
	project_id int
	help       bool
	version    bool
	// command options
	state      string
	limit      int
	title      string
	head       string
	base       string
	body       string
	body_file  string
	method     string
	tag        string
	name       string
	notes      string
	notes_file string
	ref        string
	workflow   string
	run        string
	// repo flags
	clone       bool
	create      bool
	fork        bool
	sync        bool
	private     bool
	description string
	homepage   string
	// api flags
	api_path   string
	// search flags
	search_type  string
	search_query string
	// label flags
	label_name  string
	label_color string
	label_desc  string
	// gist flags
	gist_public bool
	gist_file   string
	// milestone flags
	ms_title    string
	ms_desc     string
	ms_due_date string
	// secret flags
	secret_name string
	secret_value string
	// workflow flags
	workflow_file string
}

// Parsed is the result of argument parsing.
struct Parsed {
mut:
	cmd   string
	sub   string
	args  []string
	flags Flags
}

// global_flags are accepted anywhere on the command line.
const global_flags = {
	'-j':             'json'
	'--json':         'json'
	'-q':             'quiet'
	'--quiet':        'quiet'
	'-R':             'repo'
	'--repo':         'repo'
	'--platform':     'platform'
	'--api-base':     'api_base'
	'--token':        'token'
	'--project-id':   'project_id'
	'-h':             'help'
	'--help':         'help'
	'--version':      'version'
}

// option_flags are command specific flags that take a value.
const option_flags = {
	'--state':      'state'
	'--limit':      'limit'
	'--title':      'title'
	'--head':       'head'
	'--base':       'base'
	'--body':       'body'
	'--body-file':  'body_file'
	'--method':     'method'
	'--tag':        'tag'
	'--name':       'name'
	'--notes':      'notes'
	'--notes-file': 'notes_file'
	'--ref':        'ref'
	'--workflow':   'workflow'
	'--run':        'run'
	// repo flags
	'--clone':       'clone'
	'--create':      'create'
	'--fork':        'fork'
	'--sync':        'sync'
	'--private':     'private'
	'--description': 'description'
	'--homepage':    'homepage'
	// api flags
	'--path':        'api_path'
	// search flags
	'--type':        'search_type'
	'--query':       'search_query'
	// label flags
	'--label-name':  'label_name'
	'--color':       'label_color'
	// gist flags
	'--file':        'gist_file'
	'--gist-description': 'name'
	// milestone flags
	'--milestone-title': 'ms_title'
	'--milestone-desc':  'ms_desc'
	'--due-date':        'ms_due_date'
	// secret flags
	'--secret-name': 'secret_name'
	'--value':       'secret_value'
	// workflow flags
}

// bool_flags are flags that do not take a value.
const bool_flags = ['-j', '--json', '-q', '--quiet', '-h', '--help', '--version']

// parse_args parses argv (without the program name).
// Returns (Parsed, error message). An empty error message means success.
fn parse_args(args []string) (Parsed, string) {
	mut p := Parsed{}
	mut positionals := []string{}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg == '--' {
			positionals << args[i + 1..]
			break
		}
		if arg.starts_with('-') && arg != '-' {
			name := if arg.contains('=') { arg.all_before('=') } else { arg }
			field := if name in global_flags {
				global_flags[name]
			} else if name in option_flags {
				option_flags[name]
			} else {
				''
			}
			if field == '' {
				return p, 'unknown flag "${name}"'
			}
			if name in bool_flags {
				if arg.contains('=') {
					val := arg.all_after_first('=')
					if val !in ['true', '1', 'yes'] {
						return p, 'flag "${name}" does not take a value'
					}
				}
				set_bool_flag(mut p.flags, field)
			} else {
				value := if arg.contains('=') {
					arg.all_after_first('=')
				} else {
					if i + 1 >= args.len {
						return p, 'flag "${name}" requires a value'
					}
					i++
					args[i]
				}
				serr := set_str_flag(mut p.flags, field, value)
				if serr != '' {
					return p, serr
				}
			}
		} else {
			positionals << arg
		}
		i++
	}
	if positionals.len > 0 {
		p.cmd = positionals[0]
	}
	if positionals.len > 1 {
		p.sub = positionals[1]
	}
	if positionals.len > 2 {
		p.args = positionals[2..]
	}
	return p, ''
}

fn set_bool_flag(mut f Flags, field string) {
	match field {
		'json' {
			f.json = true
		}
		'quiet' {
			f.quiet = true
		}
		'help' {
			f.help = true
		}
		'version' {
			f.version = true
		}
		else {}
	}
}

fn set_str_flag(mut f Flags, field string, value string) string {
	match field {
		'repo' {
			f.repo = value
		}
		'platform' {
			f.platform = value
		}
		'api_base' {
			f.api_base = value
		}
		'token' {
			f.token = value
		}
		'project_id' {
			if value == '' || !all_digits(value) {
				return 'invalid --project-id "${value}": expected a number'
			}
			f.project_id = value.int()
		}
		'state' {
			f.state = value
		}
		'limit' {
			if value == '' || !all_digits(value) {
				return 'invalid --limit "${value}": expected a number'
			}
			f.limit = value.int()
		}
		'title' {
			f.title = value
		}
		'head' {
			f.head = value
		}
		'base' {
			f.base = value
		}
		'body' {
			f.body = value
		}
		'body_file' {
			f.body_file = value
		}
		'method' {
			f.method = value
		}
		'tag' {
			f.tag = value
		}
		'name' {
			f.name = value
		}
		'notes' {
			f.notes = value
		}
		'notes_file' {
			f.notes_file = value
		}
		'ref' {
			f.ref = value
		}
		'workflow' {
			f.workflow = value
		}
		'run' {
			f.run = value
		}
		'description' {
			f.description = value
		}
		'homepage' {
			f.homepage = value
		}
		'api_path' {
			f.api_path = value
		}
		'search_type' {
			f.search_type = value
		}
		'search_query' {
			f.search_query = value
		}
		'label_color' {
			f.label_color = value
		}
		'label_name' {
			f.label_name = value
		}
		'gist_file' {
			f.gist_file = value
		}
		'ms_title' {
			f.ms_title = value
		}
		'ms_desc' {
			f.ms_desc = value
		}
		'ms_due_date' {
			f.ms_due_date = value
		}
		'secret_name' {
			f.secret_name = value
		}
		'secret_value' {
			f.secret_value = value
		}
		'workflow_file' {
			f.workflow_file = value
		}
		else {
			return 'unknown flag "${field}"'
		}
	}
	return ''
}

// help_text renders the top level help.
fn help_text() string {
	return 'gf ${version_string} - unified CLI for GitHub / GitLab / Gitee

Usage:
  gf [global flags] <command> [subcommand] [flags] [args]

Global flags:
  -j, --json        output JSON (raw API payload on success, {"error":...} on failure)
  -q, --quiet       suppress non-essential output
  -R, --repo OWNER/REPO   override the repo detected from the git remote
      --platform P  force platform: github | gitlab | gitee
      --api-base URL  override the API base URL (e.g. for self-hosted instances)
      --token TOK   API token (see env precedence below)
  -h, --help        show this help
      --version     show version

Commands:
  remote            show detected platform, owner/repo and api base
  pr                pull requests (GitLab: merge requests)
  issue             issues
  release           releases
  ci                CI runs / pipelines
  repo              repository operations (clone, create, fork, sync)
  api               generic API caller (--method, --path, --body)
  search            search repositories, code, commits, issues
  label             manage labels
  gist              code snippets (GitHub) / snippets (GitLab)
  milestone         manage milestones
  secret            manage CI/CD secrets (GitLab: variables)
  workflow          GitHub Actions workflows (GitHub only)
  version           show version

Subcommands:
  pr|issue:
    list [--state open|closed|merged|all] [--limit N]
    show <number>
    create --title T [--body TEXT | --body-file -] [--head BRANCH --base BRANCH]
    merge <number> [--method merge|squash|rebase]   (pr only; rebase not supported on GitLab)
    close <number>
    comment <number> --body TEXT | --body-file -
  release:
    list [--limit N]
    show <tag>
    create --tag TAG [--name NAME] [--notes TEXT | --notes-file -]
  ci:
    list [--limit N]
    status [--run ID]            (latest run when --run is omitted)
    run [--ref BRANCH] [--workflow FILE]
    logs <id>                    (github: run id, saves a zip; gitlab: job id, prints trace)
  repo:
    clone <src> [dir]           git clone a repository
    create [--private] [--description T] [--homepage URL]
    fork                         fork the current repository
    sync                         sync a forked repository
  api:
    --method GET|POST|PUT|PATCH|DELETE --path /api/path [--body TEXT]
  search:
    --type repositories|code|commits|issues --query <text>
  label:
    list
    create --name N --color RRGGBB [--description T]
    delete <name>
  gist:
    list [--limit N]
    show <id>
    create [--public] --file <path> [--description T]
    delete <id>
  milestone:
    list [--state open|closed|all]
    show <number>
    create --title T [--description T] [--due-date YYYY-MM-DD]
    close <number>
  secret:
    list
    create --name N --value V
    delete <name>
  workflow:
    list
    view <workflow-file>
    run <workflow-file> [--ref BRANCH]

Notes:
  --body-file - / --notes-file - read the content from stdin.
  Token resolution order: platform env (GH_TOKEN/GITHUB_TOKEN, GITLAB_TOKEN/GL_TOKEN,
  GITEE_TOKEN) > GF_TOKEN > --token.
  Exit codes: 0 success, 1 API/network/config error, 2 usage error.
  Gitee CI (Gitee Go) has no stable public API; the ci commands report an error there.
'
}
