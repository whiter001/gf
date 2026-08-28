module main

import os

fn cmd_repo(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing repo subcommand')
	}
	match parsed.sub {
		'clone', 'create', 'fork', 'sync' {}
		else {
			return usage_with(parsed, 'unknown repo subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'clone' {
			return repo_clone(ctx, cfg, parsed)
		}
		'create' {
			return repo_create(ctx, cfg, parsed)
		}
		'fork' {
			return repo_fork(ctx, cfg, parsed)
		}
		'sync' {
			return repo_sync(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn repo_clone(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	src_repo := if parsed.args.len > 0 { parsed.args[0] } else { '' }
	if src_repo == '' {
		return result_usage_ctx(ctx, 'repo clone requires a repository argument (owner/repo or URL)')
	}

	// If it's a URL, use it directly; otherwise assume owner/repo format
	mut clone_url := ''
	mut target_dir := ''

	if src_repo.contains('://') || src_repo.starts_with('git@') {
		clone_url = src_repo
		if parsed.args.len > 1 {
			target_dir = parsed.args[1]
		}
	} else {
		// Parse owner/repo
		parts := src_repo.split('/')
		if parts.len < 2 {
			return result_usage_ctx(ctx, 'invalid repository format "${src_repo}", expected owner/repo')
		}
		owner := parts[0]
		repo_name := parts[1]

		// Get clone URL from API
		client := new_client(cfg)
		ad := new_adapter(client, cfg)
		resp := ad.repo_clone_url() or {
			return result_from_any_error(ctx, err)
		}

		// Parse JSON to get clone_url
		if ctx.json {
			return result_ok(resp.body + '\n')
		}

		// Extract clone_url from response
		clone_url = extract_clone_url(resp.body, cfg.platform)
		if clone_url == '' {
			return result_error(ctx, 'config', 'could not find clone URL in response', 0, '', 1)
		}

		if target_dir == '' {
			target_dir = repo_name
		}
	}

	// Execute git clone
	cmd := if target_dir != '' {
		'git clone "${clone_url}" "${target_dir}"'
	} else {
		'git clone "${clone_url}"'
	}

	res := os.execute(cmd)
	if res.exit_code != 0 {
		return result_error(ctx, 'internal', 'git clone failed: ${res.output}', 0, '', 1)
	}

	return result_ok(res.output)
}

fn repo_create(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len > 0 {
		return result_usage_ctx(ctx, 'repo create does not accept positional arguments')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.repo_create(cfg.owner, parsed.flags.private, parsed.flags.description,
		parsed.flags.homepage) or {
		return result_from_any_error(ctx, err)
	}

	return api_result(ctx, resp, 'repo')
}

fn repo_fork(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len > 0 {
		return result_usage_ctx(ctx, 'repo fork does not accept positional arguments')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.repo_fork() or {
		return result_from_any_error(ctx, err)
	}

	// Fork is async on GitHub (202 Accepted)
	if resp.status_code == 202 || ctx.json {
		return api_result(ctx, resp, 'repo')
	}

	return result_ok('Fork initiated. Check your repositories in a moment.\n')
}

fn repo_sync(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len > 0 {
		return result_usage_ctx(ctx, 'repo sync does not accept positional arguments')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.repo_sync() or {
		return result_from_any_error(ctx, err)
	}

	return api_result(ctx, resp, 'repo')
}

fn extract_clone_url(body string, platform Platform) string {
	// Simple JSON parsing to extract clone_url
	// GitHub: clone_url, GitLab: http_url_to_repo, Gitee: clone_url
	search_key := if platform == .gitlab { 'http_url_to_repo' } else { 'clone_url' }
	offset := if platform == .gitlab { 19 } else { 12 }

	idx := body.index('"${search_key}"') or { return '' }
	start := body.index_after('"', idx + offset) or { return '' }
	end := body.index_after('"', start) or { return '' }
	if end > start {
		return body[start..end]
	}
	return ''
}
