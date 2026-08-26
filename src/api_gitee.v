module main

import json2
import net.urllib

// Endpoint implementations for Gitee (gitee.com/api/v5).
// Authentication uses the access_token query parameter.
// Gitee CI (Gitee Go) has no stable public API; the ci commands report unsupported_error().

fn gitee_repo(ad Adapter) string {
	return '/repos/${ad.cfg.owner}/${ad.cfg.repo}'
}

// gitee_pr_list maps the CLI state to the Gitee API spelling.
// The pulls list API only accepts open|closed|all, so `merged` is sent as `all`
// and the result is filtered client-side on merged_at, keeping the unified
// --state open|closed|merged|all surface identical across all three platforms.
fn (ad Adapter) gitee_pr_list(state string, limit int) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls'
	wire_state := if state == 'merged' { 'all' } else { state }
	mut resp := ad.client.get(path, {
		'state':    wire_state
		'per_page': '${limit}'
	})!
	if state != 'merged' || resp.body == '' {
		return resp
	}
	items := json2.decode[[]json2.Any](resp.body) or { return resp }
	mut merged := []json2.Any{}
	for it in items {
		m := it.as_map()
		mut ma := json2.Any{}
		if v := m['merged_at'] {
			ma = v
		}
		if any_string(ma) != '' {
			merged << it
		}
	}
	return ApiResponse{
		status_code: resp.status_code
		body:        json2.encode(merged)
		url:         resp.url
		rate_limit:  resp.rate_limit
	}
}

fn (ad Adapter) gitee_pr_show(num int) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitee_pr_create(title string, head string, base string, body string) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls'
	return ad.client.send(.post, path, {}, json_body({
		'title': title
		'head':  head
		'base':  base
		'body':  body
	}))
}

fn (ad Adapter) gitee_pr_merge(num int, method string) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls/${num}/merge'
	// Gitee accepts merge|squash|rebase via the merge_method parameter; the
	// default method is `merge`, so no parameter is sent unless one is chosen.
	mut params := map[string]string{}
	if method != 'merge' {
		params['merge_method'] = method
	}
	return ad.client.send(.put, path, params, json_body({}))
}

fn (ad Adapter) gitee_pr_close(num int) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls/${num}'
	return ad.client.send(.patch, path, {}, json_body({
		'state': 'closed'
	}))
}

fn (ad Adapter) gitee_pr_comment(num int, body string) !ApiResponse {
	path := '${gitee_repo(ad)}/pulls/${num}/comments'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) gitee_issue_list(state string, limit int) !ApiResponse {
	path := '${gitee_repo(ad)}/issues'
	return ad.client.get(path, {
		'state':    state
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitee_issue_show(num int) !ApiResponse {
	path := '${gitee_repo(ad)}/issues/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitee_issue_create(title string, body string) !ApiResponse {
	path := '${gitee_repo(ad)}/issues'
	return ad.client.send(.post, path, {}, json_body({
		'title': title
		'body':  body
	}))
}

fn (ad Adapter) gitee_issue_close(num int) !ApiResponse {
	path := '${gitee_repo(ad)}/issues/${num}'
	return ad.client.send(.patch, path, {}, json_body({
		'state': 'closed'
	}))
}

fn (ad Adapter) gitee_issue_comment(num int, body string) !ApiResponse {
	path := '${gitee_repo(ad)}/issues/${num}/comments'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) gitee_release_list(limit int) !ApiResponse {
	path := '${gitee_repo(ad)}/releases'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitee_release_show(tag string) !ApiResponse {
	path := '${gitee_repo(ad)}/releases/tags/${urllib.path_escape(tag)}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitee_release_create(tag string, name string, notes string) !ApiResponse {
	path := '${gitee_repo(ad)}/releases'
	return ad.client.send(.post, path, {}, json_body({
		'tag_name': tag
		'name':     name
		'body':     notes
	}))
}
