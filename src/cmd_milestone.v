module main

fn cmd_milestone(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing milestone subcommand')
	}
	match parsed.sub {
		'list', 'show', 'create', 'close' {}
		else {
			return usage_with(parsed, 'unknown milestone subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'list' {
			return milestone_list(ctx, cfg, parsed)
		}
		'show' {
			return milestone_show(ctx, cfg, parsed)
		}
		'create' {
			return milestone_create(ctx, cfg, parsed)
		}
		'close' {
			return milestone_close(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn milestone_list(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	state := if parsed.flags.state != '' { parsed.flags.state } else { 'open' }
	limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.milestone_list(state, limit) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'milestone')
}

fn milestone_show(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'milestone show requires a number')
	}
	num := parsed.args[0].int()

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.milestone_show(num) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'milestone')
}

fn milestone_create(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.flags.ms_title == '' {
		return result_usage_ctx(ctx, 'milestone create requires --title')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.milestone_create(parsed.flags.ms_title, parsed.flags.ms_desc,
		parsed.flags.ms_due_date) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'milestone')
}

fn milestone_close(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'milestone close requires a number')
	}
	num := parsed.args[0].int()

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.milestone_close(num) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'milestone')
}
