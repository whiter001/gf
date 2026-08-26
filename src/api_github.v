module main

import json2
import net.urllib

// Endpoint implementations for GitHub (api.github.com).
// PRs are accessed under /repos/{owner}/{repo}/pulls.

// github_pr_list maps the CLI state to the GitHub API spelling.
// The pulls list API only accepts open|closed|all, so `merged` is sent as `all`
// and the result is filtered client-side on merged_at, keeping the unified
// --state open|closed|merged|all surface identical across all three platforms.
fn (ad Adapter) github_pr_list(state string, limit int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/pulls'
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

// any_string unwraps a json2.Any into a string, treating json null as empty.
fn any_string(a json2.Any) string {
	return match a {
		json2.Null { '' }
		string { a }
		else { a.str() }
	}
}

fn (ad Adapter) github_pr_show(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/pulls/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_pr_create(title string, head string, base string, body string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/pulls'
	return ad.client.send(.post, path, {}, json_body({
		'title': title
		'head':  head
		'base':  base
		'body':  body
	}))
}

fn (ad Adapter) github_pr_merge(num int, method string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/pulls/${num}/merge'
	return ad.client.send(.put, path, {}, json_body({
		'merge_method': method
	}))
}

fn (ad Adapter) github_pr_close(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/pulls/${num}'
	return ad.client.send(.patch, path, {}, json_body({
		'state': 'closed'
	}))
}

fn (ad Adapter) github_pr_comment(num int, body string) !ApiResponse {
	// GitHub PRs are issues; a generic issue comment works for both.
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues/${num}/comments'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) github_issue_list(state string, limit int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues'
	return ad.client.get(path, {
		'state':    state
		'per_page': '${limit}'
	})
}

fn (ad Adapter) github_issue_show(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_issue_create(title string, body string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues'
	return ad.client.send(.post, path, {}, json_body({
		'title': title
		'body':  body
	}))
}

fn (ad Adapter) github_issue_close(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues/${num}'
	return ad.client.send(.patch, path, {}, json_body({
		'state': 'closed'
	}))
}

fn (ad Adapter) github_issue_comment(num int, body string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/issues/${num}/comments'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) github_release_list(limit int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/releases'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) github_release_show(tag string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/releases/tags/${urllib.path_escape(tag)}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_release_create(tag string, name string, notes string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/releases'
	return ad.client.send(.post, path, {}, json_body({
		'tag_name': tag
		'name':     name
		'body':     notes
	}))
}

fn (ad Adapter) github_ci_list(limit int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/runs'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) github_ci_status(run_id string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/runs/${run_id}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_ci_run(ref string, workflow string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/workflows/${urllib.path_escape(workflow)}/dispatches'
	return ad.client.send(.post, path, {}, json_body({
		'ref': ref
	}))
}

fn (ad Adapter) github_ci_logs(run_id string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/runs/${run_id}/logs'
	return ad.client.get(path, {})
}
