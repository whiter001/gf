module main

fn cmd_api(parsed Parsed) CmdResult {
	ctx, cfg, res := prepare_ctx(parsed)
	if res.code != 0 {
		return res
	}

	if parsed.flags.api_path == '' {
		return result_usage_ctx(ctx, 'gf api requires --path')
	}

	method := if parsed.flags.method != '' {
		parsed.flags.method
	} else {
		'GET'
	}

	body := if parsed.flags.body_file != '' {
		read_body(parsed.flags.body, parsed.flags.body_file) or {
			return result_from_any_error(ctx, err)
		}
	} else {
		parsed.flags.body
	}

	client := new_client(cfg)
	ad := new_adapter(client, cfg)

	resp := ad.api_call(method, parsed.flags.api_path, body) or {
		return result_from_any_error(ctx, err)
	}

	if ctx.json {
		return result_ok(resp.body + '\n')
	}
	return result_ok(resp.body + '\n')
}
