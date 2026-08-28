module main

import json2
import net.http
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

// --- repo ---

fn (ad Adapter) github_repo_clone_url() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_repo_create(owner string, is_private bool, description string, homepage string) !ApiResponse {
	path := '/user/repos'
	mut body := {
		'name': owner
		'private': if is_private { 'true' } else { 'false' }
	}
	if description != '' {
		body['description'] = description
	}
	if homepage != '' {
		body['homepage'] = homepage
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) github_repo_fork() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/forks'
	return ad.client.send(.post, path, {}, '{}')
}

fn (ad Adapter) github_repo_sync() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/merge-upstream'
	// Get the parent info first
	parent_resp := ad.client.get('/repos/${ad.cfg.owner}/${ad.cfg.repo}', {})!
	parent_body := parent_resp.body
	// Extract parent.default_branch
	// For now, just try to sync with the default branch
	return ad.client.send(.put, path, {}, json_body({
		'branch': 'main'
	}))
}

// --- api ---

fn (ad Adapter) github_api_call(method string, path string, body string) !ApiResponse {
	mut m := http.Method.get
	um := method.to_upper()
	if um == 'POST' {
		m = http.Method.post
	} else if um == 'PUT' {
		m = http.Method.put
	} else if um == 'PATCH' {
		m = http.Method.patch
	} else if um == 'DELETE' {
		m = http.Method.delete
	}
	return ad.client.send(m, path, {}, body)
}

// --- search ---

fn (ad Adapter) github_search(query string, search_type string, limit int) !ApiResponse {
	path := '/search/${search_type}'
	return ad.client.get(path, {
		'q': query
		'per_page': '${limit}'
	})
}

// --- label ---

fn (ad Adapter) github_label_list() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/labels'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_label_create(name string, color string, description string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/labels'
	mut body := {
		'name': name
		'color': color
	}
	if description != '' {
		body['description'] = description
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) github_label_delete(name string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/labels/${urllib.path_escape(name)}'
	return ad.client.send(.delete, path, {}, '')
}

// --- gist ---

fn (ad Adapter) github_gist_list(limit int) !ApiResponse {
	path := '/gists'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) github_gist_show(id string) !ApiResponse {
	path := '/gists/${id}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_gist_create(public bool, description string, files map[string]string) !ApiResponse {
	path := '/gists'
	// Build JSON manually for nested structure
	mut files_json := '['
	mut first := true
	for fname, content in files {
		if !first {
			files_json += ','
		}
		first = false
		files_json += '{"filename":"${fname}","content":"${content.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')}"}'
	}
	files_json += ']'
	mut body_json := '{"public":${if public { 'true' } else { 'false' }},"files":${files_json}'
	if description != '' {
		body_json += ',"description":"${description.replace('\\', '\\\\').replace('"', '\\"')}"'
	}
	body_json += '}'
	return ad.client.send(.post, path, {}, body_json)
}

fn (ad Adapter) github_gist_delete(id string) !ApiResponse {
	path := '/gists/${id}'
	return ad.client.send(.delete, path, {}, '')
}

// --- milestone ---

fn (ad Adapter) github_milestone_list(state string, limit int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/milestones'
	return ad.client.get(path, {
		'state':    state
		'per_page': '${limit}'
	})
}

fn (ad Adapter) github_milestone_show(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/milestones/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_milestone_create(title string, description string, due_date string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/milestones'
	mut body := {'title': title}
	if description != '' {
		body['description'] = description
	}
	if due_date != '' {
		body['due_on'] = due_date
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) github_milestone_close(num int) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/milestones/${num}'
	return ad.client.send(.patch, path, {}, json_body({
		'state': 'closed'
	}))
}

// --- secret ---

fn (ad Adapter) github_secret_list() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/secrets'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_secret_create(name string, value string) !ApiResponse {
	// Note: Real implementation requires encryption with public key
	// This is a stub that returns an error
	return GfError{
		kind:    'unsupported'
		message: 'secret create requires encryption (not yet implemented); use GitLab CI variables instead'
		status:  0
		url:     ''
	}
}

fn (ad Adapter) github_secret_delete(name string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/secrets/${urllib.path_escape(name)}'
	return ad.client.send(.delete, path, {}, '')
}

// --- workflow ---

fn (ad Adapter) github_workflow_list() !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/workflows'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_workflow_view(workflow_file string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/contents/${urllib.path_escape(workflow_file)}'
	return ad.client.get(path, {})
}

fn (ad Adapter) github_workflow_run(workflow_file string, ref string) !ApiResponse {
	path := '/repos/${ad.cfg.owner}/${ad.cfg.repo}/actions/workflows/${urllib.path_escape(workflow_file)}/dispatches'
	return ad.client.send(.post, path, {}, json_body({
		'ref': ref
	}))
}
