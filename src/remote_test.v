module main

fn test_parse_scp_github() {
	ref := parse_remote_url('git@github.com:whiter001/gf.git') or { panic(err) }
	assert ref.platform == .github
	assert ref.owner == 'whiter001'
	assert ref.repo == 'gf'
	assert ref.path == 'whiter001/gf'
	assert ref.path_enc == 'whiter001%2Fgf'
	assert ref.host == 'github.com'
	assert ref.hostname == 'github.com'
	assert ref.api_base == 'https://api.github.com'
}

fn test_parse_https_github() {
	ref := parse_remote_url('https://github.com/owner/repo') or { panic(err) }
	assert ref.platform == .github
	assert ref.owner == 'owner'
	assert ref.repo == 'repo'
}

fn test_parse_https_gitlab_subgroup() {
	ref := parse_remote_url('https://gitlab.com/group/sub/project.git') or { panic(err) }
	assert ref.platform == .gitlab
	assert ref.owner == 'group'
	assert ref.repo == 'project'
	assert ref.path == 'group/sub/project'
	assert ref.path_enc == 'group%2Fsub%2Fproject'
	assert ref.api_base == 'https://gitlab.com/api/v4'
}

fn test_parse_scp_gitlab_subgroup() {
	ref := parse_remote_url('git@gitlab.com:mygroup/mysub/myproj.git') or { panic(err) }
	assert ref.platform == .gitlab
	assert ref.path_enc == 'mygroup%2Fmysub%2Fmyproj'
}

fn test_parse_gitee() {
	ref := parse_remote_url('git@gitee.com:foo/bar.git') or { panic(err) }
	assert ref.platform == .gitee
	assert ref.owner == 'foo'
	assert ref.repo == 'bar'
	assert ref.api_base == 'https://gitee.com/api/v5'
}

fn test_parse_ssh_with_port_selfhosted_gitlab() {
	ref := parse_remote_url('ssh://git@gitlab.example.com:2222/team/app.git') or { panic(err) }
	assert ref.platform == .gitlab
	assert ref.host == 'gitlab.example.com:2222'
	assert ref.hostname == 'gitlab.example.com'
	assert ref.api_base == 'https://gitlab.example.com:2222/api/v4'
}

fn test_parse_https_port() {
	ref := parse_remote_url('https://github.com:8443/owner/repo.git') or { panic(err) }
	assert ref.host == 'github.com:8443'
	assert ref.hostname == 'github.com'
	assert ref.platform == .github
	assert ref.api_base == 'https://api.github.com'
}

fn test_parse_git_protocol() {
	ref := parse_remote_url('git://github.com/owner/repo.git') or { panic(err) }
	assert ref.platform == .github
	assert ref.owner == 'owner'
	assert ref.repo == 'repo'
}

fn test_parse_unknown_host() {
	if _ := parse_remote_url('git@bitbucket.org:o/r.git') {
		assert false
	} else {
		assert true
	}
}

fn test_parse_missing_path() {
	if _ := parse_remote_url('git@github.com:onlyowner') {
		assert false
	} else {
		assert true
	}
}

fn test_parse_missing_colon() {
	if _ := parse_remote_url('https://github.com') {
		assert false
	} else {
		assert true
	}
}

fn test_parse_empty() {
	if _ := parse_remote_url('   ') {
		assert false
	} else {
		assert true
	}
}

fn test_platform_parse_aliases() {
	assert platform_parse('github')! == .github
	assert platform_parse('GH')! == .github
	assert platform_parse('gitlab')! == .gitlab
	assert platform_parse('gl')! == .gitlab
	assert platform_parse('gitee')! == .gitee
	if _ := platform_parse('bitbucket') {
		assert false
	} else {
		assert true
	}
}

fn test_strip_port() {
	assert strip_port('github.com') == 'github.com'
	assert strip_port('github.com:2222') == 'github.com'
	assert strip_port('gitlab.example.com:443') == 'gitlab.example.com'
}

fn test_default_api_base_github_enterprise() {
	// self hosted GitHub Enterprise uses /api/v3
	ref := parse_remote_url('https://github.mycorp.example/team/app.git') or { panic(err) }
	assert ref.platform == .github
	assert ref.api_base == 'https://github.mycorp.example/api/v3'
}

fn test_default_api_base_selfhosted_gitee() {
	ref := parse_remote_url('https://gitee.mycorp.example/team/app.git') or { panic(err) }
	assert ref.platform == .gitee
	assert ref.api_base == 'https://gitee.mycorp.example/api/v5'
}
