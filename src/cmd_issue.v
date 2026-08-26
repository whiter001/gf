module main

fn cmd_issue(parsed Parsed) CmdResult {
	if parsed.sub !in ['', 'list', 'show', 'create', 'close', 'comment'] {
		return usage_with(parsed, 'unknown issue subcommand "${parsed.sub}"')
	}
	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}
	client := new_client(cfg)
	ad := new_adapter(client, cfg)
	match parsed.sub {
		'list' {
			state := if parsed.flags.state != '' { parsed.flags.state } else { 'open' }
			if state !in ['open', 'closed', 'all'] {
				return result_usage_ctx(ctx, 'invalid --state "${state}"; must be open|closed|all')
			}
			limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }
			resp := ad.issue_list(state, limit) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'issue')
		}
		'show' {
			num, usage := parse_number_arg(parsed, 'issue show')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			resp := ad.issue_show(num) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'issue')
		}
		'create' {
			if parsed.flags.title == '' {
				return result_usage_ctx(ctx, 'issue create requires --title')
			}
			body := read_body(parsed.flags.body, parsed.flags.body_file) or {
				return result_error(ctx, 'usage', err.msg(), 0, '', 2)
			}
			resp := ad.issue_create(parsed.flags.title, body) or {
				return result_from_any_error(ctx, err)
			}
			return api_result(ctx, resp, 'issue')
		}
		'close' {
			num, usage := parse_number_arg(parsed, 'issue close')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			resp := ad.issue_close(num) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'issue')
		}
		'comment' {
			num, usage := parse_number_arg(parsed, 'issue comment')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			body := read_body(parsed.flags.body, parsed.flags.body_file) or {
				return result_error(ctx, 'usage', err.msg(), 0, '', 2)
			}
			if body == '' {
				return result_usage_ctx(ctx,
					'issue comment requires a body via --body or --body-file')
			}
			resp := ad.issue_comment(num, body) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'issue')
		}
		'' {
			return result_usage_ctx(ctx,
				'issue requires a subcommand: list|show|create|close|comment')
		}
		else {
			return usage_with(parsed, 'unknown issue subcommand "${parsed.sub}"')
		}
	}
}
