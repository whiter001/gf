module main

fn cmd_label(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing label subcommand')
	}
	match parsed.sub {
		'list', 'create', 'delete' {}
		else {
			return usage_with(parsed, 'unknown label subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'list' {
			return label_list(ctx, cfg)
		}
		'create' {
			return label_create(ctx, cfg, parsed)
		}
		'delete' {
			return label_delete(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn label_list(ctx Ctx, cfg Config) CmdResult {
	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.label_list() or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'label')
}

fn label_create(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.flags.label_name == '' {
		return result_usage_ctx(ctx, 'label create requires --name')
	}
	if parsed.flags.label_color == '' {
		return result_usage_ctx(ctx, 'label create requires --color')
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.label_create(parsed.flags.label_name, parsed.flags.label_color,
		parsed.flags.label_desc) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'label')
}

fn label_delete(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'label delete requires a name')
	}
	name := parsed.args[0]

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.label_delete(name) or {
		return result_from_any_error(ctx, err)
	}
	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	return result_ok('Label "${name}" deleted.\n')
}
