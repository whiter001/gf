module main

fn cmd_secret(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing secret subcommand')
	}
	match parsed.sub {
		'list', 'create', 'delete' {}
		else {
			return usage_with(parsed, 'unknown secret subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'list' {
			return secret_list(ctx, cfg)
		}
		'create' {
			return secret_create(ctx, cfg, parsed)
		}
		'delete' {
			return secret_delete(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn secret_list(ctx Ctx, cfg Config) CmdResult {
	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.secret_list() or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'secret')
}

fn secret_create(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.flags.secret_name == '' {
		return result_usage_ctx(ctx, 'secret create requires --name')
	}
	if parsed.flags.secret_value == '' {
		return result_usage_ctx(ctx, 'secret create requires --value')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.secret_create(parsed.flags.secret_name, parsed.flags.secret_value) or {
		return result_from_any_error(ctx, err)
	}

	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	// GitHub secrets require encryption - show helpful message
	if resp.body.contains('unsupported') || resp.body.contains('encryption') {
		return result_error(ctx, 'unsupported', resp.body, 0, '', 1)
	}
	return result_ok('Secret "${parsed.flags.secret_name}" created.\n')
}

fn secret_delete(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'secret delete requires a name')
	}
	name := parsed.args[0]

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.secret_delete(name) or {
		return result_from_any_error(ctx, err)
	}
	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	return result_ok('Secret "${name}" deleted.\n')
}
