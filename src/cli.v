module main

// Flags holds every CLI option.
struct Flags {
mut:
	json     bool
	quiet    bool
	repo     string
	platform string
	api_base string
	token    string
	help     bool
	version  bool
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
	'-j':         'json'
	'--json':     'json'
	'-q':         'quiet'
	'--quiet':    'quiet'
	'-R':         'repo'
	'--repo':     'repo'
	'--platform': 'platform'
	'--api-base': 'api_base'
	'--token':    'token'
	'-h':         'help'
	'--help':     'help'
	'--version':  'version'
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

Notes:
  --body-file - / --notes-file - read the content from stdin.
  Token resolution order: platform env (GH_TOKEN/GITHUB_TOKEN, GITLAB_TOKEN/GL_TOKEN,
  GITEE_TOKEN) > GF_TOKEN > --token.
  Exit codes: 0 success, 1 API/network/config error, 2 usage error.
  Gitee CI (Gitee Go) has no stable public API; the ci commands report an error there.
'
}
