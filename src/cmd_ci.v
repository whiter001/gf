module main

import json2
import os

fn cmd_ci(parsed Parsed) CmdResult {
	if parsed.sub !in ['', 'list', 'status', 'run', 'logs'] {
		return usage_with(parsed, 'unknown ci subcommand "${parsed.sub}"')
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
			resp := ad.ci_list(limit) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'ci')
		}
		'status' {
			mut run_id := parsed.flags.run
			if run_id == '' {
				// fetch the most recent run/pipeline and show its status
				latest := ad.ci_list(1) or { return result_from_any_error(ctx, err) }
				items := decode_items(latest)
				if items.len == 0 {
					return result_error(ctx, 'http', 'no CI runs found', latest.status_code,
						latest.url, 1)
				}
				run_id = '${items[0].id}'
			}
			resp := ad.ci_status(run_id) or { return result_from_any_error(ctx, err) }
			return api_result(ctx, resp, 'ci')
		}
		'run' {
			ref := if parsed.flags.ref != '' { parsed.flags.ref } else { 'main' }
			workflow := parsed.flags.workflow
			if cfg.platform == .github && workflow == '' {
				return result_usage_ctx(ctx, 'ci run on GitHub requires --workflow <workflow file>')
			}
			resp := ad.ci_run(ref, workflow) or { return result_from_any_error(ctx, err) }
			if ctx.json {
				body := if resp.body == '' { '{}' } else { resp.body }
				return result_ok(body)
			}
			if resp.body == '' {
				return result_ok('CI run triggered (ref: ${ref})\n')
			}
			return result_ok(resp.body + '\n')
		}
		'logs' {
			if parsed.args.len == 0 {
				return result_usage_ctx(ctx,
					'ci logs requires an <id> argument (github: run id, gitlab: job id)')
			}
			run_id := parsed.args[0]
			resp := ad.ci_logs(run_id) or { return result_from_any_error(ctx, err) }
			if cfg.platform == .github {
				// GitHub returns a zip archive; save it to a file.
				fname := 'gf-run-${run_id}-logs.zip'
				os.write_file(fname, resp.body) or {
					return result_error(ctx, 'internal', 'failed to write ${fname}: ${err}', 0, '',
						1)
				}
				if ctx.json {
					return result_ok('{"saved": "${fname}", "size": ${resp.body.len}}\n')
				}
				return result_ok('saved ${fname} (${resp.body.len} bytes)\n')
			}
			if ctx.json {
				return result_ok(json2.encode({
					'job': resp.body
				}) + '\n')
			}
			return result_ok(resp.body)
		}
		'' {
			return result_usage_ctx(ctx, 'ci requires a subcommand: list|status|run|logs')
		}
		else {
			return usage_with(parsed, 'unknown ci subcommand "${parsed.sub}"')
		}
	}
}

// decode_items parses an array response body into HumanItems.
fn decode_items(resp ApiResponse) []HumanItem {
	raw := unwrap_ci_runs(resp.body)
	return json2.decode[[]HumanItem](raw) or { []HumanItem{} }
}
