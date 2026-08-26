module main

fn cmd_release(parsed Parsed) CmdResult {
	if parsed.sub !in ['', 'list', 'show', 'create'] {
		return usage_with(parsed, 'unknown release subcommand "${parsed.sub}"')
	}
	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}
	client := new_client(cfg)
	ad := new_adapter(client, cfg)
	match parsed.sub {
		'list' {
			limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }
			resp := ad.release_list(limit) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'release')
		}
		'show' {
			if parsed.args.len == 0 {
				return result_usage_ctx(ctx, 'release show requires a <tag> argument')
			}
			resp := ad.release_show(parsed.args[0]) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'release')
		}
		'create' {
			if parsed.flags.tag == '' {
				return result_usage_ctx(ctx, 'release create requires --tag')
			}
			name := if parsed.flags.name != '' { parsed.flags.name } else { parsed.flags.tag }
			notes := read_body(parsed.flags.notes, parsed.flags.notes_file) or {
				return result_error(ctx, 'usage', err.msg(), 0, '', 2)
			}
			resp := ad.release_create(parsed.flags.tag, name, notes) or {
				return result_from_any_error(ctx, err)
			}
			return api_result(ctx, resp, 'release')
		}
		'' {
			return result_usage_ctx(ctx, 'release requires a subcommand: list|show|create')
		}
		else {
			return usage_with(parsed, 'unknown release subcommand "${parsed.sub}"')
		}
	}
}
