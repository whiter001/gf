module main

fn cmd_pr(parsed Parsed) CmdResult {
	if parsed.sub !in ['', 'list', 'show', 'create', 'merge', 'close', 'comment'] {
		return usage_with(parsed, 'unknown pr subcommand "${parsed.sub}"')
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
			if state !in ['open', 'closed', 'merged', 'all'] {
				return result_usage_ctx(ctx,
					'invalid --state "${state}"; must be open|closed|merged|all')
			}
			limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }
			resp := ad.pr_list(state, limit) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'pr')
		}
		'show' {
			num, usage := parse_number_arg(parsed, 'pr show')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			resp := ad.pr_show(num) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'pr')
		}
		'create' {
			if parsed.flags.title == '' {
				return result_usage_ctx(ctx, 'pr create requires --title')
			}
			if parsed.flags.head == '' {
				return result_usage_ctx(ctx, 'pr create requires --head <source branch>')
			}
			base := if parsed.flags.base != '' { parsed.flags.base } else { 'main' }
			body := read_body(parsed.flags.body, parsed.flags.body_file) or {
				return result_error(ctx, 'usage', err.msg(), 0, '', 2)
			}
			resp := ad.pr_create(parsed.flags.title, parsed.flags.head, base, body) or {
				return result_from_any_error(ctx, err)
			}
			return api_result(ctx, resp, 'pr')
		}
		'merge' {
			num, usage := parse_number_arg(parsed, 'pr merge')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			method := if parsed.flags.method != '' { parsed.flags.method } else { 'merge' }
			if method !in ['merge', 'squash', 'rebase'] {
				return result_usage_ctx(ctx,
					'invalid --method "${method}"; must be merge|squash|rebase')
			}
			if cfg.platform == .gitlab && method == 'rebase' {
				return result_usage_ctx(ctx,
					'--method rebase is not supported on GitLab; use merge or squash')
			}
			resp := ad.pr_merge(num, method) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'pr')
		}
		'close' {
			num, usage := parse_number_arg(parsed, 'pr close')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			resp := ad.pr_close(num) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'pr')
		}
		'comment' {
			num, usage := parse_number_arg(parsed, 'pr comment')
			if usage != '' {
				return result_usage_ctx(ctx, usage)
			}
			body := read_body(parsed.flags.body, parsed.flags.body_file) or {
				return result_error(ctx, 'usage', err.msg(), 0, '', 2)
			}
			if body == '' {
				return result_usage_ctx(ctx, 'pr comment requires a body via --body or --body-file')
			}
			resp := ad.pr_comment(num, body) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'pr')
		}
		'' {
			return result_usage_ctx(ctx,
				'pr requires a subcommand: list|show|create|merge|close|comment')
		}
		else {
			return usage_with(parsed, 'unknown pr subcommand "${parsed.sub}"')
		}
	}
}
