module main

import json2

fn test_parse_args_basic() {
	p, err := parse_args(['pr', 'list', '--state', 'open', '--json'])
	assert err == ''
	assert p.cmd == 'pr'
	assert p.sub == 'list'
	assert p.flags.state == 'open'
	assert p.flags.json == true
}

fn test_parse_args_equals_form() {
	p, err := parse_args(['pr', 'create', '--title=hello', '--base', 'dev'])
	assert err == ''
	assert p.flags.title == 'hello'
	assert p.flags.base == 'dev'
}

fn test_parse_args_global_flags_anywhere() {
	p, err := parse_args(['-R', 'o/r', '--platform', 'github', 'pr', 'list'])
	assert err == ''
	assert p.flags.repo == 'o/r'
	assert p.flags.platform == 'github'
	assert p.cmd == 'pr'
}

fn test_parse_args_short_flags() {
	p, err := parse_args(['-j', '-q', 'pr', 'list'])
	assert err == ''
	assert p.flags.json == true
	assert p.flags.quiet == true
}

fn test_parse_args_positional_number() {
	p, err := parse_args(['pr', 'show', '12'])
	assert err == ''
	assert p.cmd == 'pr'
	assert p.sub == 'show'
	assert p.args.len == 1
	assert p.args[0] == '12'
}

fn test_parse_args_unknown_flag() {
	_, err := parse_args(['pr', 'list', '--nope'])
	assert err != ''
	assert err.contains('unknown flag')
}

fn test_parse_args_missing_value() {
	_, err := parse_args(['pr', 'list', '--state'])
	assert err != ''
	assert err.contains('requires a value')
}

fn test_parse_args_invalid_limit() {
	_, err := parse_args(['pr', 'list', '--limit', 'abc'])
	assert err != ''
	assert err.contains('invalid --limit')
}

fn test_parse_args_double_dash() {
	p, err := parse_args(['pr', 'show', '--', '--weird'])
	assert err == ''
	assert p.args.len == 1
	assert p.args[0] == '--weird'
}

fn test_parse_args_body_file_dash() {
	p, err := parse_args(['issue', 'comment', '5', '--body-file', '-'])
	assert err == ''
	assert p.flags.body_file == '-'
}

fn test_dispatch_version_and_help() {
	res := dispatch(['--version'])
	assert res.code == 0
	assert res.stdout.contains('0.1.0')
	res2 := dispatch(['--help'])
	assert res2.code == 0
	assert res2.stdout.contains('Usage:')
}

fn test_dispatch_unknown_command() {
	res := dispatch(['frobnicate'])
	assert res.code == 2
	assert res.stderr.contains('unknown command')
}

fn test_dispatch_missing_command_json() {
	res := dispatch(['--json'])
	assert res.code == 2
	env := json2.decode[ErrorEnvelope](res.stderr) or { panic(err) }
	assert env.error.kind == 'usage'
}

fn test_dispatch_remote_unknown_subcommand() {
	res := dispatch(['remote', 'list'])
	assert res.code == 2
}
