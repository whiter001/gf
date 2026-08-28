module main

import os

const version_string = '0.1.0'

fn main() {
	res := dispatch(os.args[1..])
	if res.stdout != '' {
		print(res.stdout)
	}
	if res.stderr != '' {
		eprint(res.stderr)
	}
	exit(res.code)
}

// dispatch parses the command line and runs the requested command.
fn dispatch(args []string) CmdResult {
	parsed, perr := parse_args(args)
	if perr != '' {
		return usage_with(parsed, perr)
	}
	if parsed.flags.help {
		return result_ok(help_text())
	}
	if parsed.flags.version {
		return result_ok('gf ${version_string}\n')
	}
	match parsed.cmd {
		'' {
			return usage_with(parsed, 'missing command')
		}
		'help' {
			return result_ok(help_text())
		}
		'version' {
			return result_ok('gf ${version_string}\n')
		}
		'remote' {
			return cmd_remote(parsed)
		}
		'pr' {
			return cmd_pr(parsed)
		}
		'issue' {
			return cmd_issue(parsed)
		}
		'release' {
			return cmd_release(parsed)
		}
		'ci' {
			return cmd_ci(parsed)
		}
		'repo' {
			return cmd_repo(parsed)
		}
		'api' {
			return cmd_api(parsed)
		}
		'search' {
			return cmd_search(parsed)
		}
		'label' {
			return cmd_label(parsed)
		}
		'gist' {
			return cmd_gist(parsed)
		}
		'milestone' {
			return cmd_milestone(parsed)
		}
		'secret' {
			return cmd_secret(parsed)
		}
		'workflow' {
			return cmd_workflow(parsed)
		}
		else {
			return usage_with(parsed, 'unknown command "${parsed.cmd}"')
		}
	}
}
