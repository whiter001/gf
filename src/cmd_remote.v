module main

import json2

// RemoteInfo is the redacted JSON shape for the remote command (no token leak).
struct RemoteInfo {
	platform  string
	host      string
	owner     string
	repo      string
	project   string
	api_base  string
	has_token bool
}

fn cmd_remote(parsed Parsed) CmdResult {
	if parsed.sub != '' || parsed.args.len > 0 {
		return usage_with(parsed, 'remote does not take subcommands')
	}
	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}
	info := RemoteInfo{
		platform:  platform_name(cfg.platform)
		host:      cfg.host
		owner:     cfg.owner
		repo:      cfg.repo
		project:   cfg.path
		api_base:  cfg.api_base
		has_token: cfg.token != ''
	}
	if ctx.json {
		return result_ok(json2.encode(info) + '\n')
	}
	lines := [
		'platform:  ${info.platform}',
		'host:      ${info.host}',
		'owner:     ${info.owner}',
		'repo:      ${info.repo}',
		'project:   ${info.project}',
		'api-base:  ${info.api_base}',
		'has-token: ${if info.has_token { 'yes' } else { 'no' }}',
	]
	return result_ok(lines.join('\n') + '\n')
}
