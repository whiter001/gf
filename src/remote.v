module main

import os

// Platform is the supported Git hosting platform.
enum Platform {
	github
	gitlab
	gitee
}

// RepoRef holds the parsed identity of a repository.
struct RepoRef {
	owner    string // top level group / owner (e.g. "whiter001")
	repo     string // last path segment (the repo name on github/gitee)
	path     string // full path; on GitLab this includes subgroups (e.g. "grp/sub/proj")
	path_enc string // path with "/" replaced by "%2F" (GitLab API requirement)
	host     string // authority from the remote URL, may include a port
	hostname string // host without port
	platform Platform
	api_base string // default api base derived from platform+host
}

// detect_remote_repo runs `git remote get-url origin` in the current directory.
fn detect_remote_repo() !RepoRef {
	res := os.execute('git remote get-url origin')
	if res.exit_code != 0 {
		return error('no "origin" remote found: ${res.output}')
	}
	url := res.output.trim_space()
	if url == '' {
		return error('no "origin" remote found (empty output)')
	}
	return parse_remote_url(url)
}

// parse_remote_url parses a git remote URL in any of the common formats:
//   - scp-like: git@github.com:owner/repo.git
//   - https:    https://github.com/owner/repo.git
//   - ssh:      ssh://git@github.com/owner/repo.git
//   - git:      git://github.com/owner/repo.git
fn parse_remote_url(url string) !RepoRef {
	raw := url.trim_space()
	if raw == '' {
		return error('empty remote url')
	}
	mut path := ''
	mut authority := ''
	if raw.contains('://') {
		rest := raw.all_after_first('://')
		slash := rest.index('/') or { return error('invalid remote url "${raw}": missing path') }
		authority = rest[..slash]
		path = rest[slash..]
	} else {
		colon := raw.index(':') or {
			return error('invalid remote url "${raw}": missing ":" separator')
		}
		authority = raw[..colon]
		path = raw[colon + 1..]
	}
	path = path.trim_left('/')
	if path.ends_with('.git') {
		path = path[..path.len - 4]
	}
	path = path.trim_right('/')
	host := authority.all_after_last('@')
	hostname := strip_port(host)
	parts := path.split('/').filter(it != '')
	if parts.len < 2 {
		return error('invalid remote url "${raw}": path must contain owner/repo')
	}
	owner := parts[0]
	repo := parts[parts.len - 1]
	full_path := parts.join('/')
	if owner == '' || repo == '' {
		return error('invalid remote url "${raw}": path must contain owner/repo')
	}
	platform := platform_from_host(hostname)!
	api_base := default_api_base(platform, host, hostname)
	return RepoRef{
		owner:    owner
		repo:     repo
		path:     full_path
		path_enc: full_path.replace('/', '%2F')
		host:     host
		hostname: hostname
		platform: platform
		api_base: api_base
	}
}

// strip_port removes an ":port" suffix from a host.
fn strip_port(host string) string {
	if host.starts_with('[') {
		// IPv6 literal [addr]:port
		end := host.index(']') or { return host }
		return host[..end + 1]
	}
	idx := host.last_index(':') or { return host }
	if idx < host.len - 1 && all_digits(host[idx + 1..]) {
		return host[..idx]
	}
	return host
}

// platform_from_host maps a hostname to a Platform by name pattern.
fn platform_from_host(hostname string) !Platform {
	h := hostname.to_lower()
	if h == 'github.com' || h.ends_with('.github.com') || h.contains('github') {
		return .github
	}
	if h == 'gitlab.com' || h.ends_with('.gitlab.com') || h.contains('gitlab') {
		return .gitlab
	}
	if h == 'gitee.com' || h.ends_with('.gitee.com') || h.contains('gitee') {
		return .gitee
	}
	return error('cannot detect platform from host "${hostname}"; pass --platform and/or --api-base to override')
}

// platform_parse converts a user supplied platform name into a Platform.
fn platform_parse(name string) !Platform {
	match name.to_lower() {
		'github', 'gh' {
			return .github
		}
		'gitlab', 'gl' {
			return .gitlab
		}
		'gitee' {
			return .gitee
		}
		else {
			return error('invalid platform "${name}"; must be one of github, gitlab, gitee')
		}
	}
}

// platform_name returns the canonical short name of a platform.
fn platform_name(p Platform) string {
	return match p {
		.github { 'github' }
		.gitlab { 'gitlab' }
		.gitee { 'gitee' }
	}
}

// platform_host returns the canonical host for a platform.
fn platform_host(p Platform) string {
	return match p {
		.github { 'github.com' }
		.gitlab { 'gitlab.com' }
		.gitee { 'gitee.com' }
	}
}

// default_api_base returns the default API base URL for a platform+host.
// `hostname` (without port) decides whether the canonical SaaS URL is used.
fn default_api_base(p Platform, host string, hostname string) string {
	match p {
		.github {
			return if hostname == 'github.com' {
				'https://api.github.com'
			} else {
				'https://${host}/api/v3'
			}
		}
		.gitlab {
			return if hostname == 'gitlab.com' {
				'https://gitlab.com/api/v4'
			} else {
				'https://${host}/api/v4'
			}
		}
		.gitee {
			return if hostname == 'gitee.com' {
				'https://gitee.com/api/v5'
			} else {
				'https://${host}/api/v5'
			}
		}
	}
}
