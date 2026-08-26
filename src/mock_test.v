module main

import json2
import net
import net.http
import os
import time

// MockRoute is a canned response for a "METHOD path" key.
struct MockRoute {
	status int
	body   string
}

// MockServer is a tiny scripted HTTP server used as a stand-in API.
struct MockServer {
	routes            map[string]MockRoute
	require_auth      bool
	echo_auth_path    string // when set, respond with the received auth value
	echo_request_path string // when set, respond with method/path/body echo
}

fn (m MockServer) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	key := '${req.method} ${path}'
	mut res := http.Response{}
	if m.echo_auth_path != '' && path == m.echo_auth_path {
		auth := req.header.get(.authorization) or { '' }
		pt := req.header.get_custom('PRIVATE-TOKEN', exact: false) or { '' }
		received := if auth != '' {
			auth
		} else if pt != '' {
			pt
		} else if req.url.contains('access_token=') {
			'query-token'
		} else {
			'none'
		}
		res.body = json2.encode({
			'received_auth': received
		})
		res.status_code = 200
		res.set_version(req.version)
		return res
	}
	if m.echo_request_path != '' && path == m.echo_request_path {
		res.body = json2.encode({
			'method':       req.method.str()
			'path':         path
			'query':        req.url.all_after_first('?')
			'body':         req.data
			'content_type': req.header.get(.content_type) or { '' }
		})
		res.status_code = 200
		res.set_version(req.version)
		return res
	}
	if m.require_auth {
		auth := req.header.get(.authorization) or { '' }
		pt := req.header.get_custom('PRIVATE-TOKEN', exact: false) or { '' }
		if auth == '' && pt == '' && !req.url.contains('access_token=') {
			res.body = '{"message": "unauthorized"}'
			res.status_code = 401
			res.set_version(req.version)
			return res
		}
	}
	if route := m.routes[key] {
		res.body = route.body
		res.status_code = route.status
	} else {
		res.body = '{"message": "no mock for ${key}"}'
		res.status_code = 404
	}
	res.set_version(req.version)
	return res
}

fn start_mock(m MockServer) (&http.Server, thread) {
	// 预绑定 TCP 监听器拿到真实端口，再把监听器交给 Server：
	// 既消除「等监听线程回写 srv.addr」的竞态，也规避 V http.Server 进程内
	// 首次 listen 时 addr 一直不刷新（读到空串拼出非法 URL）的问题。
	mut l := net.listen_tcp(net.AddrFamily.ip, '127.0.0.1:0') or { panic(err) }
	bound := l.addr() or { panic(err) }
	mut srv := &http.Server{
		accept_timeout:       200 * time.millisecond
		handler:              m
		listener:             l
		addr:                 bound.str()
		show_startup_message: false
	}
	t := spawn srv.listen_and_serve()
	srv.wait_till_running() or {
		srv.stop()
		t.wait()
		panic(err)
	}
	return srv, t
}

fn clear_token_env() {
	for name in ['GH_TOKEN', 'GITHUB_TOKEN', 'GITLAB_TOKEN', 'GL_TOKEN', 'GITEE_TOKEN', 'GF_TOKEN'] {
		os.unsetenv(name)
	}
}

// --- fixtures ---

// fixtures use the realistic API shapes: global db `id` is always present and
// must NOT be shown as the pr/issue number in human output.

const github_pr_list = '[{"id":103741,"number":12,"title":"fix login","state":"open","html_url":"https://github.com/o/r/pull/12"},{"id":103740,"number":11,"title":"add docs","state":"closed","html_url":"https://github.com/o/r/pull/11"}]'

const github_pr_show = '{"id":103741,"number":12,"title":"fix login","state":"open","html_url":"https://github.com/o/r/pull/12"}'

const github_pr_mixed = '[{"id":2001,"number":12,"title":"open pr","state":"open","html_url":"https://github.com/o/r/pull/12","merged_at":null},{"id":2002,"number":11,"title":"closed pr","state":"closed","html_url":"https://github.com/o/r/pull/11","merged_at":null},{"id":2003,"number":10,"title":"merged pr","state":"closed","merged_at":"2024-01-01T00:00:00Z","html_url":"https://github.com/o/r/pull/10"}]'

const github_issue_list = '[{"id":505050,"number":5,"title":"bug report","state":"open","html_url":"https://github.com/o/r/issues/5"}]'

const github_release_list = '[{"tag_name":"v1.0.0","name":"Release v1.0.0","html_url":"https://github.com/o/r/releases/tag/v1.0.0"}]'

const github_ci_list = '{"total_count":2,"workflow_runs":[{"id":123,"status":"completed","head_branch":"main","html_url":"https://github.com/o/r/actions/runs/123"},{"id":122,"status":"in_progress","head_branch":"dev","html_url":"https://github.com/o/r/actions/runs/122"}]}'

const github_run_show = '{"id":123,"status":"completed","head_branch":"main","html_url":"https://github.com/o/r/actions/runs/123"}'

const gitlab_mr_list = '[{"id":9999,"iid":7,"title":"merge me","state":"opened","web_url":"https://gitlab.com/o/r/-/merge_requests/7"}]'

const gitlab_pipeline_list = '[{"id":55,"status":"success","ref":"main","web_url":"https://gitlab.com/o/r/-/pipelines/55"}]'

const gitee_pr_list = '[{"id":555,"number":3,"title":"gitee pr","state":"open","html_url":"https://gitee.com/o/r/pulls/3"}]'

const gitee_pr_mixed = '[{"id":6001,"number":3,"title":"gitee open pr","state":"open","html_url":"https://gitee.com/o/r/pulls/3","merged_at":null},{"id":6002,"number":2,"title":"gitee closed pr","state":"closed","html_url":"https://gitee.com/o/r/pulls/2","merged_at":null},{"id":6003,"number":1,"title":"gitee merged pr","state":"closed","merged_at":"2024-02-02T02:02:02+08:00","html_url":"https://gitee.com/o/r/pulls/1"}]'

// --- github ---

fn test_github_pr_list_json() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   github_pr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list', '--json'])
	assert res.code == 0
	assert res.stdout.contains('"number":12')
	assert res.stdout.contains('"title":"fix login"')
}

fn test_github_pr_list_human() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   github_pr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list'])
	assert res.code == 0
	assert res.stdout.contains('#12')
	assert res.stdout.contains('fix login')
	assert res.stdout.contains('open')
	// the global db id must not leak into the human-readable number
	assert !res.stdout.contains('#103741')
	assert !res.stdout.contains('103741')
}

fn test_github_pr_list_merged_filters() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   github_pr_mixed
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// json mode: only the merged PR survives the client-side merged_at filter
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list', '--state', 'merged', '--json'])
	assert res.code == 0
	assert res.stdout.contains('"number":10')
	assert !res.stdout.contains('"number":12')
	assert !res.stdout.contains('"number":11')
	// human mode: shows the merged PR number
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r',
		'pr', 'list', '--state', 'merged'])
	assert res2.code == 0
	assert res2.stdout.contains('#10')
	assert !res2.stdout.contains('#12')
	assert !res2.stdout.contains('#11')
}

fn test_github_pr_list_merged_sends_all() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// GitHub pulls API rejects state=merged (422); it must be sent as state=all
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list', '--state', 'merged', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	// GET requests carry no body, so no Content-Type must be sent
	assert echo.content_type == ''
	params := echo.query.split('&')
	assert 'state=all' in params
	assert 'state=merged' !in params
}

fn test_github_auth_header() {
	clear_token_env()
	m := MockServer{
		echo_auth_path: '/repos/o/r/pulls'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list', '--json', '--token', 'sekrit'])
	assert res.code == 0
	assert res.stdout.contains('Bearer sekrit')
}

fn test_no_token_unauthorized() {
	clear_token_env()
	m := MockServer{
		require_auth: true
		routes:       {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   github_pr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// human mode: exit 1, message mentions 401
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'list'])
	assert res.code == 1
	assert res.stderr.contains('401')
	// json mode: parseable error envelope
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r',
		'pr', 'list', '--json'])
	assert res2.code == 1
	env := json2.decode[ErrorEnvelope](res2.stderr) or { panic(err) }
	assert env.error.kind == 'http'
	assert env.error.status == 401
	assert env.error.url.contains('/repos/o/r/pulls')
}

fn test_http_404_error() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/issues/99': MockRoute{
				status: 404
				body:   '{"message": "Not Found"}'
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'issue',
		'show', '99', '--json'])
	assert res.code == 1
	env := json2.decode[ErrorEnvelope](res.stderr) or { panic(err) }
	assert env.error.status == 404
	assert env.error.message.contains('Not Found')
}

fn test_github_create_with_body_file() {
	clear_token_env()
	body_path := os.join_path(os.temp_dir(), 'gf_body.txt')
	os.write_file(body_path, 'hello from file') or { panic(err) }
	defer {
		os.rm(body_path) or {}
	}
	m := MockServer{
		routes: {
			'POST /repos/o/r/pulls': MockRoute{
				status: 201
				body:   '{"number":13,"title":"new pr","state":"open","html_url":"https://github.com/o/r/pull/13"}'
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'create', '--title', 'new pr', '--head', 'feat', '--base', 'main', '--body-file', body_path,
		'--json'])
	assert res.code == 0
	assert res.stdout.contains('"number":13')
}

fn test_github_create_echo_body() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'create', '--title', 'T', '--head', 'dev', '--base', 'main', '--body', 'note', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert echo.method == 'POST'
	assert echo.path == '/repos/o/r/pulls'
	assert echo.content_type == 'application/json'
	assert echo.body.contains('"title":"T"')
	assert echo.body.contains('"head":"dev"')
	assert echo.body.contains('"base":"main"')
}

struct EchoResp {
	method       string
	path         string
	query        string
	body         string
	content_type string
}

fn test_github_issue_and_release() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/issues':   MockRoute{
				status: 200
				body:   github_issue_list
			}
			'GET /repos/o/r/releases': MockRoute{
				status: 200
				body:   github_release_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'issue',
		'list', '--json'])
	assert res.code == 0
	assert res.stdout.contains('"number":5')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r',
		'release', 'list'])
	assert res2.code == 0
	assert res2.stdout.contains('v1.0.0')
}

fn test_github_ci_run_204() {
	clear_token_env()
	m := MockServer{
		routes: {
			'POST /repos/o/r/actions/workflows/ci.yml/dispatches': MockRoute{
				status: 204
				body:   ''
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'ci',
		'run', '--ref', 'main', '--workflow', 'ci.yml'])
	assert res.code == 0
	assert res.stdout.contains('CI run triggered')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r',
		'ci', 'run', '--ref', 'main', '--workflow', 'ci.yml', '--json'])
	assert res2.code == 0
	assert res2.stdout == '{}'
}

fn test_github_ci_status_latest() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/actions/runs':     MockRoute{
				status: 200
				body:   github_ci_list
			}
			'GET /repos/o/r/actions/runs/123': MockRoute{
				status: 200
				body:   github_run_show
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'ci',
		'status'])
	assert res.code == 0
	assert res.stdout.contains('123')
	assert res.stdout.contains('completed')
}

fn test_github_ci_list_human_wrapped() {
	// Regression: GitHub /actions/runs returns {"total_count":N,"workflow_runs":[...]}.
	// Human-readable ci list must correctly unwrap and render the runs.
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/actions/runs': MockRoute{
				status: 200
				body:   github_ci_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'ci',
		'list'])
	assert res.code == 0
	assert res.stdout.contains('123')
	assert res.stdout.contains('122')
	assert res.stdout.contains('completed')
	assert res.stdout.contains('in_progress')
}

fn test_github_ci_logs_saves_file() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/actions/runs/9/logs': MockRoute{
				status: 200
				body:   'fake-zip-bytes'
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'ci',
		'logs', '9', '--json'])
	assert res.code == 0
	assert res.stdout.contains('gf-run-9-logs.zip')
	fname := os.join_path(os.getwd(), 'gf-run-9-logs.zip')
	assert os.exists(fname)
	content := os.read_file(fname) or { panic(err) }
	assert content == 'fake-zip-bytes'
	os.rm(fname) or {}
}

// --- gitlab ---

fn test_gitlab_mr_list_and_encoding() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /projects/group%2Fsub%2Fproj/merge_requests': MockRoute{
				status: 200
				body:   gitlab_mr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R',
		'group/sub/proj', 'pr', 'list', '--json'])
	assert res.code == 0
	assert res.stdout.contains('"iid":7')
}

fn test_gitlab_auth_header() {
	clear_token_env()
	m := MockServer{
		echo_auth_path: '/projects/o%2Fr/merge_requests'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'pr',
		'list', '--json', '--token', 'gl-secret'])
	assert res.code == 0
	assert res.stdout.contains('gl-secret')
}

fn test_gitlab_pipelines() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /projects/o%2Fr/pipelines': MockRoute{
				status: 200
				body:   gitlab_pipeline_list
			}
			'POST /projects/o%2Fr/pipeline': MockRoute{
				status: 201
				body:   '{"id":56,"status":"created","ref":"main","web_url":"https://gitlab.com/o/r/-/pipelines/56"}'
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'ci',
		'list'])
	assert res.code == 0
	assert res.stdout.contains('55')
	assert res.stdout.contains('success')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r',
		'ci', 'run', '--ref', 'dev', '--json'])
	assert res2.code == 0
	assert res2.stdout.contains('"id":56')
}

fn test_gitlab_pr_default_state_maps_to_opened() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/projects/o%2Fr/merge_requests'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// the CLI default state "open" must be sent as "opened" (GitLab API rejects "open")
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'pr',
		'list', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	params := echo.query.split('&')
	assert 'state=opened' in params
	assert 'state=open' !in params
	// explicit --state open maps the same way; closed passes through unchanged
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r',
		'pr', 'list', '--json', '--state', 'open'])
	assert res2.code == 0
	echo2 := json2.decode[EchoResp](res2.stdout) or { panic(err) }
	params2 := echo2.query.split('&')
	assert 'state=opened' in params2
	assert 'state=open' !in params2
	res3 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r',
		'pr', 'list', '--json', '--state', 'closed'])
	assert res3.code == 0
	echo3 := json2.decode[EchoResp](res3.stdout) or { panic(err) }
	params3 := echo3.query.split('&')
	assert 'state=closed' in params3
}

// --- pr merge --method ---

fn test_github_pr_merge_sends_merge_method() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls/5/merge'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'github', '-R', 'o/r', 'pr',
		'merge', '5', '--method', 'rebase', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert echo.method == 'PUT'
	assert echo.path == '/repos/o/r/pulls/5/merge'
	assert echo.body.contains('"merge_method":"rebase"')
}

fn test_gitlab_pr_merge_squash_sends_param() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/projects/o%2Fr/merge_requests/5/merge'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// --method squash must reach the GitLab merge API as squash=true, not be dropped
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'pr',
		'merge', '5', '--method', 'squash', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert echo.method == 'PUT'
	assert echo.path == '/projects/o%2Fr/merge_requests/5/merge'
	assert 'squash=true' in echo.query.split('&')
}

fn test_gitlab_pr_merge_default_no_squash() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/projects/o%2Fr/merge_requests/5/merge'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'pr',
		'merge', '5', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert !echo.query.contains('squash=')
}

fn test_gitlab_pr_merge_rebase_rejected() {
	clear_token_env()
	m := MockServer{}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// GitLab merge API has no rebase method; --method rebase must be an explicit
	// usage error (exit 2) instead of being silently downgraded to a plain merge.
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r', 'pr',
		'merge', '5', '--method', 'rebase', '--json'])
	assert res.code == 2
	assert res.stderr.contains('rebase')
	assert res.stderr.contains('not supported')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitlab', '-R', 'o/r',
		'pr', 'merge', '5', '--method', 'rebase'])
	assert res2.code == 2
	assert res2.stderr.contains('rebase')
}

fn test_gitee_pr_merge_method_sent() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls/5/merge'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// Gitee accepts merge|squash|rebase via merge_method; the choice must travel
	// to the API rather than being silently ignored.
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'merge', '5', '--method', 'rebase', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert echo.method == 'PUT'
	assert echo.path == '/repos/o/r/pulls/5/merge'
	assert 'merge_method=rebase' in echo.query.split('&')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'merge', '5', '--method', 'squash', '--json'])
	assert res2.code == 0
	echo2 := json2.decode[EchoResp](res2.stdout) or { panic(err) }
	assert 'merge_method=squash' in echo2.query.split('&')
}

fn test_gitee_pr_merge_default_no_method() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls/5/merge'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// the default merge method on Gitee is already `merge`, so no param is needed
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'merge', '5', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	assert !echo.query.contains('merge_method=')
}

// --- gitee ---

fn test_gitee_pr_list_and_token_query() {
	clear_token_env()
	m := MockServer{
		echo_auth_path: '/repos/o/r/pulls'
		routes:         {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   gitee_pr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'list', '--json', '--token', 'gitee-secret'])
	assert res.code == 0
	// gitee tokens travel in the query string, not a header
	assert res.stdout.contains('query-token')
}

fn test_gitee_pr_list_human_uses_number() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   gitee_pr_list
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'list'])
	assert res.code == 0
	// the human-readable number is the PR number, not the global db id
	assert res.stdout.contains('#3')
	assert !res.stdout.contains('#555')
}

fn test_gitee_pr_list_merged_filters() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 200
				body:   gitee_pr_mixed
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// json mode: only the merged PR survives the client-side merged_at filter
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'list', '--state', 'merged', '--json'])
	assert res.code == 0
	assert res.stdout.contains('"number":1')
	assert !res.stdout.contains('"number":3')
	assert !res.stdout.contains('"number":2')
	// human mode: shows the merged PR number
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r',
		'pr', 'list', '--state', 'merged'])
	assert res2.code == 0
	assert res2.stdout.contains('#1')
	assert !res2.stdout.contains('#3')
	assert !res2.stdout.contains('#2')
}

fn test_gitee_pr_list_merged_sends_all() {
	clear_token_env()
	m := MockServer{
		echo_request_path: '/repos/o/r/pulls'
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	// Gitee pulls API rejects state=merged (4xx); it must be sent as state=all
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'list', '--state', 'merged', '--json'])
	assert res.code == 0
	echo := json2.decode[EchoResp](res.stdout) or { panic(err) }
	params := echo.query.split('&')
	assert 'state=all' in params
	assert 'state=merged' !in params
}

fn test_gitee_ci_unsupported() {
	clear_token_env()
	m := MockServer{}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'ci',
		'list'])
	assert res.code == 1
	assert res.stderr.contains('not supported')
	res2 := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'ci',
		'list', '--json'])
	assert res2.code == 1
	env := json2.decode[ErrorEnvelope](res2.stderr) or { panic(err) }
	assert env.error.kind == 'unsupported'
}

fn test_gitee_token_not_leaked_in_error() {
	clear_token_env()
	m := MockServer{
		routes: {
			'GET /repos/o/r/pulls': MockRoute{
				status: 404
				body:   '{"message": "Not Found"}'
			}
		}
	}
	mut srv, t := start_mock(m)
	defer {
		srv.stop()
		t.wait()
	}
	res := dispatch(['--api-base', 'http://${srv.addr}', '--platform', 'gitee', '-R', 'o/r', 'pr',
		'list', '--json', '--token', 'gitee-supersecret'])
	assert res.code == 1
	assert !res.stderr.contains('gitee-supersecret')
	assert !res.stderr.contains('access_token')
	env := json2.decode[ErrorEnvelope](res.stderr) or { panic(err) }
	assert env.error.url.contains('/repos/o/r/pulls')
	assert !env.error.url.contains('access_token')
}

// --- exit codes ---

fn test_usage_error_exit_code() {
	res := dispatch(['pr', 'list', '--bogus'])
	assert res.code == 2
	res2 := dispatch(['pr', 'create'])
	assert res2.code == 2
	res3 := dispatch(['release', 'create'])
	assert res3.code == 2
	// in this repo (github remote) ci run without --workflow is a usage error
	res4 := dispatch(['ci', 'run'])
	assert res4.code == 2
}
