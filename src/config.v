module main

import os

// Config is the fully resolved runtime configuration.
struct Config {
	platform Platform
	host     string
	owner    string
	repo     string
	path     string
	path_enc string
	api_base string
	token    string
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
		ref := detect_remote_repo() or {
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
			host = platform_host(platform)
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
		platform: platform
		host:     host
		owner:    owner
		repo:     repo
		path:     full_path
		path_enc: path_enc
		api_base: api_base
		token:    token
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
// platform specific env var > GF_TOKEN > --token flag.
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
	return flag_token
}
