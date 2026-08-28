module main

fn cmd_workflow(parsed Parsed) CmdResult {
	if parsed.sub == '' {
		return usage_with(parsed, 'missing workflow subcommand')
	}
	match parsed.sub {
		'list', 'view', 'run' {}
		else {
			return usage_with(parsed, 'unknown workflow subcommand "${parsed.sub}"')
		}
	}

	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	match parsed.sub {
		'list' {
			return workflow_list(ctx, cfg)
		}
		'view' {
			return workflow_view(ctx, cfg, parsed)
		}
		'run' {
			return workflow_run(ctx, cfg, parsed)
		}
		else {
			return result_ok('')
		}
	}
}

fn workflow_list(ctx Ctx, cfg Config) CmdResult {
	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.workflow_list() or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'workflow')
}

fn workflow_view(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'workflow view requires a workflow file name')
	}
	workflow_file := parsed.args[0]

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.workflow_view(workflow_file) or {
		return result_from_any_error(ctx, err)
	}
	return api_result(ctx, resp, 'workflow')
}

fn workflow_run(ctx Ctx, cfg Config, parsed Parsed) CmdResult {
	if parsed.args.len == 0 {
		return result_usage_ctx(ctx, 'workflow run requires a workflow file name')
	}
	workflow_file := parsed.args[0]

	ref := if parsed.flags.ref != '' { parsed.flags.ref } else { 'main' }

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.workflow_run(workflow_file, ref) or {
		return result_from_any_error(ctx, err)
	}
	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	return result_ok('Workflow "${workflow_file}" triggered on ${ref}.\n')
}
