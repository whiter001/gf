module main

import os

fn cmd_gist(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing gist subcommand')
	}
	match parsed.sub {
		'list', 'show', 'create', 'delete' {}
		else {
			return usage_with(parsed, 'unknown gist subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'list' {
			return gist_list(ctx, cfg, parsed)
		}
		'show' {
			return gist_show(ctx, cfg, parsed)
		}
		'create' {
			return gist_create(ctx, cfg, parsed)
		}
		'delete' {
			return gist_delete(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn gist_list(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.gist_list(limit) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'gist')
}

fn gist_show(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'gist show requires a gist ID')
	}
	id := parsed.args[0]

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.gist_show(id) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'gist')
}

fn gist_create(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.flags.gist_file == '' {
		return result_usage_ctx(ctx, 'gist create requires --file')
	}

	// Read file content
	content := os.read_file(parsed.flags.gist_file) or {
		return result_error(ctx, 'config', 'could not read file "${parsed.flags.gist_file}": ${err.msg()}', 0, '', 1)
	}

	filename := parsed.flags.gist_file.all_after_last('/')
	files := {filename: content}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.gist_create(parsed.flags.gist_public, parsed.flags.name, files) or {
		return result_from_any_error(ctx, err)
	}

	// Extract URL from response for human mode
	if !ctx.json {
		// Look for html_url in response
		idx := resp.body.index('"html_url"') or { return api_result(ctx, resp, 'gist') }
		start := resp.body.index_after('"', idx + 11) or { return api_result(ctx, resp, 'gist') }
		end := resp.body.index_after('"', start) or { return api_result(ctx, resp, 'gist') }
		if end > start {
			url := resp.body[start..end]
			return result_ok('Gist created: ${url}\n')
		}
	}
	return api_result(ctx, resp, 'gist')
}

fn gist_delete(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'gist delete requires a gist ID')
	}
	id := parsed.args[0]

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.gist_delete(id) or {
		return result_from_any_error(ctx, err)
	}
	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	return result_ok('Gist ${id} deleted.\n')
}
