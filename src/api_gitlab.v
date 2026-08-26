module main

import net.urllib

// Endpoint implementations for GitLab (gitlab.com/api/v4, or a self hosted instance).
// Project paths (including multi level subgroups) must be URL encoded with %2F.

fn gitlab_proj(ad Adapter) string {
	return '/projects/${ad.cfg.path_enc}'
}

// gitlab_state maps the CLI normalized state spelling to the GitLab API spelling.
// The CLI uses the GitHub/Gitee terminology ("open") while the GitLab API only
// accepts "opened" for merge requests and issues.
fn gitlab_state(s string) string {
	return if s == 'open' { 'opened' } else { s }
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
