module main

import net.http
import net.urllib

// Endpoint implementations for GitLab (gitlab.com/api/v4, or a self hosted instance).
// Project paths (including multi level subgroups) must be URL encoded with %2F.

fn gitlab_proj(ad Adapter) string {
	if ad.cfg.project_id > 0 {
		return '/projects/${ad.cfg.project_id}'
	}
	return '/projects/${ad.cfg.path_enc}'
}

// gitlab_state maps the CLI normalized state spelling to the GitLab API spelling.
// The CLI uses the GitHub/Gitee terminology ("open") while the GitLab API only
// accepts "opened" for merge requests and issues.
fn gitlab_state(s string) string {
	return if s == 'open' { 'opened' } else { s }
}

// gitlab_ms_state maps state for milestones: GitLab uses active/closed.
fn gitlab_ms_state(s string) string {
	return if s == 'open' { 'active' } else { s }
}

fn (ad Adapter) gitlab_pr_list(state string, limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests'
	return ad.client.get(path, {
		'state':    gitlab_state(state)
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_pr_show(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_pr_create(title string, head string, base string, body string) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests'
	return ad.client.send(.post, path, {}, json_body({
		'source_branch': head
		'target_branch': base
		'title':         title
		'description':   body
	}))
}

// gitlab_pr_merge merges an MR. The GitLab merge API accepts a `squash` boolean
// (passed as a query parameter); there is no rebase merge method, so `--method
// rebase` is rejected up front in cmd_pr before reaching this adapter.
fn (ad Adapter) gitlab_pr_merge(num int, method string) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests/${num}/merge'
	mut params := map[string]string{}
	if method == 'squash' {
		params['squash'] = 'true'
	}
	return ad.client.send(.put, path, params, json_body({}))
}

fn (ad Adapter) gitlab_pr_close(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests/${num}'
	return ad.client.send(.put, path, {}, json_body({
		'state_event': 'close'
	}))
}

fn (ad Adapter) gitlab_pr_comment(num int, body string) !ApiResponse {
	path := '${gitlab_proj(ad)}/merge_requests/${num}/notes'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) gitlab_issue_list(state string, limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/issues'
	return ad.client.get(path, {
		'state':    gitlab_state(state)
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_issue_show(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/issues/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_issue_create(title string, body string) !ApiResponse {
	path := '${gitlab_proj(ad)}/issues'
	return ad.client.send(.post, path, {}, json_body({
		'title':       title
		'description': body
	}))
}

fn (ad Adapter) gitlab_issue_close(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/issues/${num}'
	return ad.client.send(.put, path, {}, json_body({
		'state_event': 'close'
	}))
}

fn (ad Adapter) gitlab_issue_comment(num int, body string) !ApiResponse {
	path := '${gitlab_proj(ad)}/issues/${num}/notes'
	return ad.client.send(.post, path, {}, json_body({
		'body': body
	}))
}

fn (ad Adapter) gitlab_release_list(limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/releases'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_release_show(tag string) !ApiResponse {
	path := '${gitlab_proj(ad)}/releases/${urllib.path_escape(tag)}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_release_create(tag string, name string, notes string) !ApiResponse {
	path := '${gitlab_proj(ad)}/releases'
	return ad.client.send(.post, path, {}, json_body({
		'tag_name':    tag
		'name':        name
		'description': notes
	}))
}

fn (ad Adapter) gitlab_ci_list(limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/pipelines'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_ci_status(run_id string) !ApiResponse {
	path := '${gitlab_proj(ad)}/pipelines/${run_id}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_ci_run(ref string) !ApiResponse {
	path := '${gitlab_proj(ad)}/pipeline'
	return ad.client.send(.post, path, {
		'ref': ref
	}, json_body({}))
}

fn (ad Adapter) gitlab_ci_logs(run_id string) !ApiResponse {
	// The id refers to a pipeline job; the trace endpoint returns plain text.
	path := '${gitlab_proj(ad)}/jobs/${run_id}/trace'
	return ad.client.get(path, {})
}

// --- repo ---

fn (ad Adapter) gitlab_repo_clone_url() !ApiResponse {
	path := '${gitlab_proj(ad)}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_repo_create(owner string, is_private bool, description string, homepage string) !ApiResponse {
	path := '/projects'
	visibility := if is_private { 'private' } else { 'public' }
	mut body := {
		'name':       owner
		'visibility': visibility
	}
	if description != '' {
		body['description'] = description
	}
	if homepage != '' {
		body['web_url'] = homepage
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) gitlab_repo_fork() !ApiResponse {
	path := '${gitlab_proj(ad)}/fork'
	return ad.client.send(.post, path, {}, '{}')
}

fn (ad Adapter) gitlab_repo_sync() !ApiResponse {
	path := '${gitlab_proj(ad)}/mirror/pull'
	return ad.client.send(.post, path, {}, '{}')
}

// --- api ---

fn (ad Adapter) gitlab_api_call(method string, path string, body string) !ApiResponse {
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

fn (ad Adapter) gitlab_search(query string, search_type string, limit int) !ApiResponse {
	scope := match search_type {
		'repositories' { 'projects' }
		'code' { 'blobs' }
		'commits' { 'commits' }
		'issues' { 'issues' }
		else { 'projects' }
	}
	path := '/search'
	return ad.client.get(path, {
		'scope':  scope
		'search': query
		'per_page': '${limit}'
	})
}

// --- label ---

fn (ad Adapter) gitlab_label_list() !ApiResponse {
	path := '${gitlab_proj(ad)}/labels'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_label_create(name string, color string, description string) !ApiResponse {
	path := '${gitlab_proj(ad)}/labels'
	mut body := {
		'name':  name
		'color': color
	}
	if description != '' {
		body['description'] = description
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) gitlab_label_delete(name string) !ApiResponse {
	// GitLab labels use numeric ID, need to find it first
	// For simplicity, try to delete by name
	path := '${gitlab_proj(ad)}/labels/${urllib.path_escape(name)}'
	return ad.client.send(.delete, path, {}, '')
}

// --- snippets (GitLab equivalent of gists) ---

fn (ad Adapter) gitlab_snippet_list(limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/snippets'
	return ad.client.get(path, {
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_snippet_show(id string) !ApiResponse {
	path := '${gitlab_proj(ad)}/snippets/${id}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_snippet_create(description string, files map[string]string) !ApiResponse {
	path := '${gitlab_proj(ad)}/snippets'
	// Build JSON manually since mixed types are complex
	mut json_str := '{"title":"${description.replace('\\', '\\\\').replace('"', '\\"')}","visibility":"private","files":['
	mut first := true
	for fname, content in files {
		if !first {
			json_str += ','
		}
		first = false
		json_str += '{"file_path":"${fname}","content":"${content.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')}"}'
	}
	json_str += ']}'
	return ad.client.send(.post, path, {}, json_str)
}

fn (ad Adapter) gitlab_snippet_delete(id string) !ApiResponse {
	path := '${gitlab_proj(ad)}/snippets/${id}'
	return ad.client.send(.delete, path, {}, '')
}

// --- milestone ---

fn (ad Adapter) gitlab_milestone_list(state string, limit int) !ApiResponse {
	path := '${gitlab_proj(ad)}/milestones'
	return ad.client.get(path, {
		'state':    gitlab_ms_state(state)
		'per_page': '${limit}'
	})
}

fn (ad Adapter) gitlab_milestone_show(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/milestones/${num}'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_milestone_create(title string, description string, due_date string) !ApiResponse {
	path := '${gitlab_proj(ad)}/milestones'
	mut body := {'title': title}
	if description != '' {
		body['description'] = description
	}
	if due_date != '' {
		body['due_date'] = due_date
	}
	return ad.client.send(.post, path, {}, json_body(body))
}

fn (ad Adapter) gitlab_milestone_close(num int) !ApiResponse {
	path := '${gitlab_proj(ad)}/milestones/${num}'
	return ad.client.send(.put, path, {}, json_body({
		'state_event': 'close'
	}))
}

// --- variable (GitLab CI variables, simpler than secrets) ---

fn (ad Adapter) gitlab_variable_list() !ApiResponse {
	path := '${gitlab_proj(ad)}/variables'
	return ad.client.get(path, {})
}

fn (ad Adapter) gitlab_variable_create(name string, value string) !ApiResponse {
	path := '${gitlab_proj(ad)}/variables'
	return ad.client.send(.post, path, {}, json_body({
		'key':   name
		'value': value
	}))
}

fn (ad Adapter) gitlab_variable_delete(name string) !ApiResponse {
	path := '${gitlab_proj(ad)}/variables/${urllib.path_escape(name)}'
	return ad.client.send(.delete, path, {}, '')
}
