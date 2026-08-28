module main

import json2

// Adapter exposes one unified endpoint interface over the three platforms.
struct Adapter {
	client ApiClient
	cfg    Config
}

fn new_adapter(client ApiClient, cfg Config) Adapter {
	return Adapter{
		client: client
		cfg:    cfg
	}
}

// --- pull requests ---

fn (ad Adapter) pr_list(state string, limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_list(state, limit) }
		.gitlab { ad.gitlab_pr_list(state, limit) }
		.gitee { ad.gitee_pr_list(state, limit) }
	}
}

fn (ad Adapter) pr_show(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_show(num) }
		.gitlab { ad.gitlab_pr_show(num) }
		.gitee { ad.gitee_pr_show(num) }
	}
}

fn (ad Adapter) pr_create(title string, head string, base string, body string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_create(title, head, base, body) }
		.gitlab { ad.gitlab_pr_create(title, head, base, body) }
		.gitee { ad.gitee_pr_create(title, head, base, body) }
	}
}

fn (ad Adapter) pr_merge(num int, method string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_merge(num, method) }
		.gitlab { ad.gitlab_pr_merge(num, method) }
		.gitee { ad.gitee_pr_merge(num, method) }
	}
}

fn (ad Adapter) pr_close(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_close(num) }
		.gitlab { ad.gitlab_pr_close(num) }
		.gitee { ad.gitee_pr_close(num) }
	}
}

fn (ad Adapter) pr_comment(num int, body string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_pr_comment(num, body) }
		.gitlab { ad.gitlab_pr_comment(num, body) }
		.gitee { ad.gitee_pr_comment(num, body) }
	}
}

// --- issues ---

fn (ad Adapter) issue_list(state string, limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_issue_list(state, limit) }
		.gitlab { ad.gitlab_issue_list(state, limit) }
		.gitee { ad.gitee_issue_list(state, limit) }
	}
}

fn (ad Adapter) issue_show(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_issue_show(num) }
		.gitlab { ad.gitlab_issue_show(num) }
		.gitee { ad.gitee_issue_show(num) }
	}
}

fn (ad Adapter) issue_create(title string, body string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_issue_create(title, body) }
		.gitlab { ad.gitlab_issue_create(title, body) }
		.gitee { ad.gitee_issue_create(title, body) }
	}
}

fn (ad Adapter) issue_close(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_issue_close(num) }
		.gitlab { ad.gitlab_issue_close(num) }
		.gitee { ad.gitee_issue_close(num) }
	}
}

fn (ad Adapter) issue_comment(num int, body string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_issue_comment(num, body) }
		.gitlab { ad.gitlab_issue_comment(num, body) }
		.gitee { ad.gitee_issue_comment(num, body) }
	}
}

// --- releases ---

fn (ad Adapter) release_list(limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_release_list(limit) }
		.gitlab { ad.gitlab_release_list(limit) }
		.gitee { ad.gitee_release_list(limit) }
	}
}

fn (ad Adapter) release_show(tag string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_release_show(tag) }
		.gitlab { ad.gitlab_release_show(tag) }
		.gitee { ad.gitee_release_show(tag) }
	}
}

fn (ad Adapter) release_create(tag string, name string, notes string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_release_create(tag, name, notes) }
		.gitlab { ad.gitlab_release_create(tag, name, notes) }
		.gitee { ad.gitee_release_create(tag, name, notes) }
	}
}

// --- ci ---

fn (ad Adapter) ci_list(limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_ci_list(limit) }
		.gitlab { ad.gitlab_ci_list(limit) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) ci_status(run_id string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_ci_status(run_id) }
		.gitlab { ad.gitlab_ci_status(run_id) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) ci_run(ref string, workflow string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_ci_run(ref, workflow) }
		.gitlab { ad.gitlab_ci_run(ref) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) ci_logs(run_id string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_ci_logs(run_id) }
		.gitlab { ad.gitlab_ci_logs(run_id) }
		.gitee { return unsupported_error() }
	}
}

// --- repo ---

fn (ad Adapter) repo_clone_url() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_repo_clone_url() }
		.gitlab { ad.gitlab_repo_clone_url() }
		.gitee { ad.gitee_repo_clone_url() }
	}
}

fn (ad Adapter) repo_create(owner string, is_private bool, description string, homepage string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_repo_create(owner, is_private, description, homepage) }
		.gitlab { ad.gitlab_repo_create(owner, is_private, description, homepage) }
		.gitee { ad.gitee_repo_create(owner, is_private, description, homepage) }
	}
}

fn (ad Adapter) repo_fork() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_repo_fork() }
		.gitlab { ad.gitlab_repo_fork() }
		.gitee { ad.gitee_repo_fork() }
	}
}

fn (ad Adapter) repo_sync() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_repo_sync() }
		.gitlab { ad.gitlab_repo_sync() }
		.gitee { ad.gitee_repo_sync() }
	}
}

// --- api ---

fn (ad Adapter) api_call(method string, path string, body string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_api_call(method, path, body) }
		.gitlab { ad.gitlab_api_call(method, path, body) }
		.gitee { ad.gitee_api_call(method, path, body) }
	}
}

// --- search ---

fn (ad Adapter) search(query string, search_type string, limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_search(query, search_type, limit) }
		.gitlab { ad.gitlab_search(query, search_type, limit) }
		.gitee { ad.gitee_search(query, search_type, limit) }
	}
}

// --- label ---

fn (ad Adapter) label_list() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_label_list() }
		.gitlab { ad.gitlab_label_list() }
		.gitee { ad.gitee_label_list() }
	}
}

fn (ad Adapter) label_create(name string, color string, description string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_label_create(name, color, description) }
		.gitlab { ad.gitlab_label_create(name, color, description) }
		.gitee { ad.gitee_label_create(name, color, description) }
	}
}

fn (ad Adapter) label_delete(name string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_label_delete(name) }
		.gitlab { ad.gitlab_label_delete(name) }
		.gitee { ad.gitee_label_delete(name) }
	}
}

// --- gist ---

fn (ad Adapter) gist_list(limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_gist_list(limit) }
		.gitlab { ad.gitlab_snippet_list(limit) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) gist_show(id string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_gist_show(id) }
		.gitlab { ad.gitlab_snippet_show(id) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) gist_create(public bool, description string, files map[string]string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_gist_create(public, description, files) }
		.gitlab { ad.gitlab_snippet_create(description, files) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) gist_delete(id string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_gist_delete(id) }
		.gitlab { ad.gitlab_snippet_delete(id) }
		.gitee { return unsupported_error() }
	}
}

// --- milestone ---

fn (ad Adapter) milestone_list(state string, limit int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_milestone_list(state, limit) }
		.gitlab { ad.gitlab_milestone_list(state, limit) }
		.gitee { ad.gitee_milestone_list(state, limit) }
	}
}

fn (ad Adapter) milestone_show(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_milestone_show(num) }
		.gitlab { ad.gitlab_milestone_show(num) }
		.gitee { ad.gitee_milestone_show(num) }
	}
}

fn (ad Adapter) milestone_create(title string, description string, due_date string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_milestone_create(title, description, due_date) }
		.gitlab { ad.gitlab_milestone_create(title, description, due_date) }
		.gitee { ad.gitee_milestone_create(title, description, due_date) }
	}
}

fn (ad Adapter) milestone_close(num int) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_milestone_close(num) }
		.gitlab { ad.gitlab_milestone_close(num) }
		.gitee { ad.gitee_milestone_close(num) }
	}
}

// --- secret ---

fn (ad Adapter) secret_list() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_secret_list() }
		.gitlab { ad.gitlab_variable_list() }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) secret_create(name string, value string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_secret_create(name, value) }
		.gitlab { ad.gitlab_variable_create(name, value) }
		.gitee { return unsupported_error() }
	}
}

fn (ad Adapter) secret_delete(name string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_secret_delete(name) }
		.gitlab { ad.gitlab_variable_delete(name) }
		.gitee { return unsupported_error() }
	}
}

// --- workflow ---

fn (ad Adapter) workflow_list() !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_workflow_list() }
		.gitlab { return unsupported_error_msg('workflows are not supported on GitLab (use pipeline schedules instead)') }
		.gitee { return unsupported_error_msg('workflows are not supported on Gitee') }
	}
}

fn (ad Adapter) workflow_view(workflow_file string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_workflow_view(workflow_file) }
		.gitlab { return unsupported_error_msg('workflows are not supported on GitLab') }
		.gitee { return unsupported_error_msg('workflows are not supported on Gitee') }
	}
}

fn (ad Adapter) workflow_run(workflow_file string, ref string) !ApiResponse {
	return match ad.cfg.platform {
		.github { ad.github_workflow_run(workflow_file, ref) }
		.gitlab { return unsupported_error_msg('workflows are not supported on GitLab') }
		.gitee { return unsupported_error_msg('workflows are not supported on Gitee') }
	}
}

// json_body encodes a map into a JSON string for request bodies.
fn json_body(fields map[string]string) string {
	return json2.encode(fields)
}
