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

// json_body encodes a map into a JSON string for request bodies.
fn json_body(fields map[string]string) string {
	return json2.encode(fields)
}
