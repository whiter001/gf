module main

fn cmd_search(parsed Parsed) CmdResult {
	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	search_type := parsed.flags.search_type
	if search_type == '' {
		return result_usage_ctx(ctx, 'gf search requires --type (repositories|code|commits|issues)')
	}

	mut query := parsed.flags.search_query
	if query == '' && parsed.args.len > 0 {
		query = parsed.args.join(' ')
	}
	if query == '' {
		return result_usage_ctx(ctx, 'gf search requires --query')
	}

	limit := if parsed.flags.limit > 0 { parsed.flags.limit } else { 30 }

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.search(query, search_type, limit) or {
		return result_from_any_error(ctx, err)
	}

	return api_result(ctx, resp, 'search')
}
