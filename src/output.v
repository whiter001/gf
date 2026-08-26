module main

import json2
import os
import strings

// CmdResult is what every command handler returns.
struct CmdResult {
mut:
	stdout string
	stderr string
	code   int
}

// ErrorInfo is the JSON shape for error output.
struct ErrorInfo {
	kind    string
	message string
	status  int
	url     string
}

struct ErrorEnvelope {
	error ErrorInfo
}

// HumanItem is a normalized view over API objects used for human readable output.
struct HumanItem {
	id      int    @[json: 'id']
	number  int    @[json: 'number']
	iid     int    @[json: 'iid']
	title   string @[json: 'title']
	name    string @[json: 'name']
	state   string @[json: 'state']
	status  string @[json: 'status']
	url     string @[json: 'html_url']
	web_url string @[json: 'web_url']
	tag     string @[json: 'tag_name']
	branch  string @[json: 'head_branch']
	ref     string @[json: 'ref']
}

// Ctx carries the shared per-command state.
struct Ctx {
	cfg   Config
	json  bool
	quiet bool
}

// prepare_ctx resolves the runtime config for a command.
// On failure it returns a non-zero CmdResult which the caller must return.
fn prepare_ctx(parsed Parsed) (Ctx, Config, CmdResult) {
	ctx := Ctx{
		json:  parsed.flags.json
		quiet: parsed.flags.quiet
	}
	cfg := resolve_config(parsed.flags) or {
		if err is GfError {
			return ctx, Config{}, result_from_gf_error(ctx, err)
		}
		return ctx, Config{}, result_from_gf_error(ctx, GfError{
			kind:    'internal'
			message: err.msg()
		})
	}
	return ctx, cfg, CmdResult{}
}

// result_ok builds a success result.
fn result_ok(stdout string) CmdResult {
	return CmdResult{
		stdout: stdout
		code:   0
	}
}

// result_usage builds a usage error (exit code 2).
fn result_usage(message string) CmdResult {
	return CmdResult{
		stderr: 'gf: ${message}\n\ntry "gf --help" for usage'
		code:   2
	}
}

// result_usage_json builds a usage error as JSON (for --json callers).
fn result_usage_json(message string) CmdResult {
	env := ErrorEnvelope{
		error: ErrorInfo{
			kind:    'usage'
			message: message
		}
	}
	return CmdResult{
		stderr: json2.encode(env)
		code:   2
	}
}

// usage_with picks the JSON or human usage error based on the --json flag.
fn usage_with(parsed Parsed, message string) CmdResult {
	if parsed.flags.json {
		return result_usage_json(message)
	}
	return result_usage(message)
}

// result_usage_ctx is usage_with for callers that already have a Ctx.
fn result_usage_ctx(ctx Ctx, message string) CmdResult {
	if ctx.json {
		return result_usage_json(message)
	}
	return result_usage(message)
}

// result_error builds an error result; in json mode the error is emitted as JSON.
fn result_error(ctx Ctx, kind string, message string, status int, url string, code int) CmdResult {
	if ctx.json {
		env := ErrorEnvelope{
			error: ErrorInfo{
				kind:    kind
				message: message
				status:  status
				url:     url
			}
		}
		return CmdResult{
			stderr: json2.encode(env)
			code:   code
		}
	}
	return CmdResult{
		stderr: 'gf: ${kind} error: ${message}'
		code:   code
	}
}

// result_from_gf_error converts a GfError into a CmdResult.
fn result_from_gf_error(ctx Ctx, err GfError) CmdResult {
	code := if err.kind == 'usage' { 2 } else { 1 }
	return result_error(ctx, err.kind, err.message, err.status, err.url, code)
}

// result_from_any_error converts any IError into a CmdResult.
fn result_from_any_error(ctx Ctx, err IError) CmdResult {
	if err is GfError {
		return result_from_gf_error(ctx, err)
	}
	return result_from_gf_error(ctx, GfError{
		kind:    'internal'
		message: err.msg()
	})
}

// unwrap_ci_runs handles the GitHub /actions/runs response shape which wraps
// the workflow runs array in a {"total_count":N,"workflow_runs":[...]} object.
// For all other payloads (GitLab pipelines, GitHub single-run, PRs, etc.)
// the body is returned unchanged.
fn unwrap_ci_runs(body string) string {
	obj := json2.decode[map[string]json2.Any](body) or { return body }
	if runs := obj['workflow_runs'] {
		// 空数组同样解包为 `[]`：ci list 应渲染空表，而不是整对象解码失败后的全零行
		return json2.encode(runs.as_array())
	}
	return body
}

// api_result turns a successful API response into a CmdResult.
// In json mode the raw API body is passed through; otherwise a human readable table.
fn api_result(ctx Ctx, resp ApiResponse, kind string) CmdResult {
	if ctx.json {
		body := if resp.body == '' { '{}' } else { resp.body }
		return result_ok(body)
	}
	raw := if kind == 'ci' { unwrap_ci_runs(resp.body) } else { resp.body }
	items := json2.decode[[]HumanItem](raw) or {
		single := json2.decode[HumanItem](raw) or { return result_ok(resp.body) }
		return result_ok(render_single(kind, single))
	}
	return result_ok(render_table(kind, items))
}

// render_table renders a list of items for human consumption.
fn render_table(kind string, items []HumanItem) string {
	mut sb := strings.new_builder(512)
	for it in items {
		line := item_line(kind, it)
		if line != '' {
			sb.write_string(line)
			sb.write_string('\n')
		}
	}
	return sb.str()
}

// render_single renders one item for human consumption.
fn render_single(kind string, it HumanItem) string {
	line := item_line(kind, it)
	if line == '' {
		return ''
	}
	return line + '\n'
}

// item_line renders one item as a single line.
fn item_line(kind string, it HumanItem) string {
	// pr/issue numbers are the platform-scoped iid (GitLab) or number (GitHub/Gitee);
	// the global database `id` must never be shown here since users act on the number.
	// ci runs/pipelines are addressed by their global `id` instead.
	num := match kind {
		'ci' {
			if it.id > 0 {
				it.id
			} else if it.iid > 0 {
				it.iid
			} else {
				it.number
			}
		}
		'pr', 'issue' {
			if it.iid > 0 {
				it.iid
			} else {
				it.number
			}
		}
		else {
			if it.iid > 0 {
				it.iid
			} else if it.id > 0 {
				it.id
			} else {
				it.number
			}
		}
	}
	title := if it.title != '' { it.title } else { it.name }
	state := if it.state != '' { it.state } else { it.status }
	url := if it.url != '' { it.url } else { it.web_url }
	branch := if it.branch != '' { it.branch } else { it.ref }
	return match kind {
		'pr', 'issue' {
			if num > 0 {
				'#${num}\t${state}\t${title}\t${url}'
			} else {
				'${state}\t${title}\t${url}'
			}
		}
		'release' {
			tag := if it.tag != '' { it.tag } else { title }
			'${tag}\t${state}\t${url}'
		}
		'ci' {
			if num > 0 {
				'${num}\t${state}\t${branch}\t${url}'
			} else {
				'${state}\t${url}'
			}
		}
		else {
			'${state}\t${title}\t${url}'
		}
	}
}

// read_body reads the request body from --body or --body-file ("-" reads stdin).
fn read_body(body string, body_file string) !string {
	if body_file != '' {
		if body_file == '-' {
			return read_all_stdin()
		}
		return os.read_file(body_file)
	}
	return body
}

// read_all_stdin reads all of stdin.
fn read_all_stdin() string {
	mut f := os.stdin()
	mut buf := []u8{len: 4096}
	mut out := []u8{}
	for {
		n := f.read(mut buf) or { break }
		if n <= 0 {
			break
		}
		out << buf[..n]
	}
	return out.bytestr()
}

// parse_number_arg extracts the numeric argument for commands like `show <number>`.
fn parse_number_arg(parsed Parsed, usage string) (int, string) {
	if parsed.args.len == 0 {
		return 0, '${usage} requires a number argument'
	}
	raw := parsed.args[0]
	if !all_digits(raw) {
		return 0, 'invalid number "${raw}" for ${usage}'
	}
	return raw.int(), ''
}

// all_digits reports whether every character of s is an ASCII digit.
fn all_digits(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}
