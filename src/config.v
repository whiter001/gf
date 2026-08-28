module main

import os

// Config is the fully resolved runtime configuration.
struct Config {
	platform   Platform
	host       string
	owner      string
	repo       string
	path       string
	path_enc   string
	api_base   string
	token      string
	project_id int
}

// resolve_config builds a Config from CLI flags, the environment and the git remote.
fn resolve_config(f Flags) !Config {
	mut platform := Platform.github
	platform_set := f.platform != ''
	if platform_set {
		platform = platform_parse(f.platform) or {
			return GfError{
				kind:    'usage'
				message: err.msg()
			}
		}
	}

	// Resolve owner/repo either from --repo or from the git remote.
	mut owner := ''
	mut repo := ''
	mut full_path := ''
	mut path_enc := ''
	mut host := ''

	if f.repo != '' {
		repo_flag := f.repo.trim('/')
		parts := repo_flag.split('/').filter(it != '')
		if parts.len < 2 {
			return GfError{
				kind:    'usage'
				message: 'invalid --repo "${f.repo}"; expected owner/repo'
			}
		}
		owner = parts[0]
		repo = parts[parts.len - 1]
		full_path = parts.join('/')
		path_enc = full_path.replace('/', '%2F')
		if !platform_set {
			return GfError{
				kind:    'usage'
				message: '--repo was given but the platform is unknown; pass --platform github|gitlab|gitee (or use the git remote instead of --repo)'
			}
		}
		host = platform_host(platform)
	} else {
		ref := detect_remote_repo(platform) or {
			return GfError{
				kind:    'config'
				message: err.msg()
			}
		}
		owner = ref.owner
		repo = ref.repo
		full_path = ref.path
		path_enc = ref.path_enc
		if platform_set {
			// use the real host from the remote; platform_host is only a fallback
			// for the --repo case (no git remote).
			host = ref.host
		} else {
			platform = ref.platform
			host = ref.host
		}
	}

	api_base := if f.api_base != '' {
		f.api_base.trim_right('/')
	} else {
		default_api_base(platform, host, host)
	}

	token := resolve_token(platform, f.token)

	return Config{
		platform:   platform
		host:       host
		owner:      owner
		repo:       repo
		path:       full_path
		path_enc:   path_enc
		api_base:   api_base
		token:      token
		project_id: f.project_id
	}
}

// token_env_names returns the platform specific environment variables.
fn token_env_names(p Platform) []string {
	return match p {
		.github { ['GH_TOKEN', 'GITHUB_TOKEN'] }
		.gitlab { ['GITLAB_TOKEN', 'GL_TOKEN'] }
		.gitee { ['GITEE_TOKEN'] }
	}
}

// resolve_token resolves the API token with this precedence:
// platform specific env var > GF_TOKEN > ~/.gf/config file > --token flag.
fn resolve_token(p Platform, flag_token string) string {
	for name in token_env_names(p) {
		v := os.getenv(name)
		if v != '' {
			return v
		}
	}
	v := os.getenv('GF_TOKEN')
	if v != '' {
		return v
	}
	cfg_tok := read_config_token(p)
	if cfg_tok != '' {
		return cfg_tok
	}
	return flag_token
}

// read_config_token reads the token from ~/.gf/config for the given platform.
fn read_config_token(p Platform) string {
	home := os.home_dir()
	if home == '' {
		return ''
	}
	cfg_path := os.join_path(home, '.gf', 'config')
	if !os.exists(cfg_path) {
		return ''
	}
	content := os.read_file(cfg_path) or { return '' }
	platform_key := platform_name(p)
	// support both "gitlab = token" and '"gitlab": "token"' formats
	for line in content.split('\n') {
		mut trimmed := line.trim_space()
		if trimmed == '' || trimmed.starts_with('#') {
			continue
		}
		if trimmed.contains('=') {
			// key = value format
			parts := trimmed.split_nth('=', 2)
			if parts[0].trim_space() == platform_key {
				return parts[1].trim_space().trim('"')
			}
		} else if trimmed.contains(':') {
			// JSON-like "key": "value" format
			parts := trimmed.split_nth(':', 2)
			if parts[0].trim_space().trim('"') == platform_key {
				return parts[1].trim_space().trim('"')
			}
		}
	}
	return ''
}
