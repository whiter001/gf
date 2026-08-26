module main

import os

fn clear_token_env() {
	for name in ['GH_TOKEN', 'GITHUB_TOKEN', 'GITLAB_TOKEN', 'GL_TOKEN', 'GITEE_TOKEN', 'GF_TOKEN'] {
		os.unsetenv(name)
	}
}

fn test_resolve_token_platform_env_wins() {
	clear_token_env()
	os.setenv('GH_TOKEN', 'env-gh', true)
	os.setenv('GF_TOKEN', 'env-gf', true)
	defer {
		clear_token_env()
	}
	assert resolve_token(.github, 'flag-tok') == 'env-gh'
	// GF_TOKEN is the universal fallback for platforms without their own env var
	assert resolve_token(.gitlab, 'flag-tok') == 'env-gf'
	assert resolve_token(.gitee, 'flag-tok') == 'env-gf'
}

fn test_resolve_token_gf_token_beats_flag() {
	clear_token_env()
	os.setenv('GF_TOKEN', 'env-gf', true)
	defer {
		clear_token_env()
	}
	assert resolve_token(.github, 'flag-tok') == 'env-gf'
}

fn test_resolve_token_flag_fallback() {
	clear_token_env()
	assert resolve_token(.github, 'flag-tok') == 'flag-tok'
	assert resolve_token(.github, '') == ''
}

fn test_resolve_token_gitlab_variants() {
	clear_token_env()
	os.setenv('GL_TOKEN', 'env-gl', true)
	defer {
		clear_token_env()
	}
	assert resolve_token(.gitlab, '') == 'env-gl'
}

fn test_resolve_config_with_repo_and_flags() {
	clear_token_env()
	f := Flags{
		repo:     'o/r'
		platform: 'github'
		api_base: 'https://mock.example'
		token:    'tok'
	}
	cfg := resolve_config(f) or { panic(err) }
	assert cfg.platform == .github
	assert cfg.owner == 'o'
	assert cfg.repo == 'r'
	assert cfg.api_base == 'https://mock.example'
	assert cfg.token == 'tok'
	assert cfg.host == 'github.com'
}

fn test_resolve_config_api_base_default() {
	clear_token_env()
	f := Flags{
		repo:     'o/r'
		platform: 'gitlab'
	}
	cfg := resolve_config(f) or { panic(err) }
	assert cfg.api_base == 'https://gitlab.com/api/v4'
	assert cfg.repo == 'r'
	assert cfg.path == 'o/r'
	assert cfg.path_enc == 'o%2Fr'
}

fn test_resolve_config_repo_without_platform() {
	f := Flags{
		repo: 'o/r'
	}
	if _ := resolve_config(f) {
		assert false
	} else {
		if err is GfError {
			assert err.kind == 'usage'
		} else {
			assert false
		}
	}
}

fn test_resolve_config_bad_repo_format() {
	f := Flags{
		repo:     'norepo'
		platform: 'github'
	}
	if _ := resolve_config(f) {
		assert false
	} else {
		if err is GfError {
			assert err.kind == 'usage'
		} else {
			assert false
		}
	}
}

fn test_resolve_config_bad_platform() {
	f := Flags{
		repo:     'o/r'
		platform: 'bitbucket'
	}
	if _ := resolve_config(f) {
		assert false
	} else {
		if err is GfError {
			assert err.kind == 'usage'
		} else {
			assert false
		}
	}
}

fn test_detect_remote_no_git() {
	dir := os.join_path(os.temp_dir(), 'gf_test_nogit')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	defer {
		os.rmdir_all(dir) or {}
	}
	old := os.getwd()
	os.chdir(dir) or { panic(err) }
	defer {
		os.chdir(old) or {}
	}
	if _ := detect_remote_repo() {
		assert false
	} else {
		assert true
	}
}
