module main

import json2
import net.http
import net.urllib
import time

// GfError is the structured error type used across the CLI.
struct GfError {
	kind    string // usage | config | network | http | unsupported | internal
	message string
	status  int
	url     string
}

fn (e GfError) msg() string {
	return e.message
}

fn (e GfError) code() int {
	return if e.kind == 'usage' { 2 } else { 1 }
}

// ApiResponse is a normalized HTTP response.
struct ApiResponse {
	status_code int
	body        string
	url         string
	rate_limit  string
}

// ApiClient wraps the low level HTTP layer with platform auth injection.
struct ApiClient {
mut:
	platform Platform
	api_base string
	token    string
}

fn new_client(cfg Config) ApiClient {
	return ApiClient{
		platform: cfg.platform
		api_base: cfg.api_base
		token:    cfg.token
	}
}

// request performs an HTTP request against the platform API.
// `params` become query parameters (URL encoded), `body` is the raw request body.
fn (c &ApiClient) request(method http.Method, path string, params map[string]string, body string) !ApiResponse {
	query := build_query(params, c.platform, c.token)
	mut url := '${c.api_base}${path}'
	if query != '' {
		url += if url.contains('?') { '&' } else { '?' } + query
	}
	// The actual request URL may carry the Gitee access_token in the query string;
	// error output must use the sanitized form so the token never leaks to stderr.
	safe_url := sanitize_url(url)
	mut h := http.new_header()
	h.add(.accept, 'application/json')
	// Write requests carry a JSON body (built by json_body in the api adapters);
	// GitLab/Gitee reject requests without an explicit Content-Type (HTTP 415),
	// so it must be set whenever a body is present.
	if body != '' {
		h.add(.content_type, 'application/json')
	}
	if c.token != '' {
		match c.platform {
			.github {
				h.add(.authorization, 'Bearer ${c.token}')
			}
			.gitlab {
				h.add_custom('PRIVATE-TOKEN', c.token) or {}
			}
			.gitee {
				// the access_token is appended as a query parameter
			}
		}
	}
	resp := http.fetch(
		method:       method
		url:          url
		data:         body
		header:       h
		user_agent:   'gf/${version_string}'
		read_timeout: 30 * time.second
	) or {
		return GfError{
			kind:    'network'
			message: 'request to ${safe_url} failed: ${err}'
			url:     safe_url
		}
	}
	return ApiResponse{
		status_code: resp.status_code
		body:        resp.body
		url:         safe_url
		rate_limit:  resp.header.get_custom('x-ratelimit-remaining', exact: false) or { '' }
	}
}

// get is a convenience wrapper for GET requests.
fn (c &ApiClient) get(path string, params map[string]string) !ApiResponse {
	return c.expect(c.request(.get, path, params, '')!)
}

// send is a convenience wrapper that checks the status code.
fn (c &ApiClient) send(method http.Method, path string, params map[string]string, body string) !ApiResponse {
	return c.expect(c.request(method, path, params, body)!)
}

// expect turns a non-2xx response into a structured GfError.
fn (c &ApiClient) expect(resp ApiResponse) !ApiResponse {
	if resp.status_code >= 200 && resp.status_code < 300 {
		return resp
	}
	message := api_error_message(resp)
	rl := if resp.rate_limit == '0' {
		' (rate limit exceeded)'
	} else if resp.rate_limit != '' {
		' (rate limit remaining: ${resp.rate_limit})'
	} else {
		''
	}
	return GfError{
		kind:    'http'
		message: '${resp.status_code} ${message}${rl}'
		status:  resp.status_code
		url:     resp.url
	}
}

// api_error_message extracts a human readable message from an API error body.
fn api_error_message(resp ApiResponse) string {
	if resp.body == '' {
		return http.status_from_int(resp.status_code).str()
	}
	msg := extract_error_message(resp.body)
	if msg != '' {
		return msg
	}
	if resp.body.len > 200 {
		return resp.body[..200]
	}
	return resp.body
}

struct ApiErrorBody {
	message string
	error   string
}

// extract_error_message tries to parse common API error shapes.
fn extract_error_message(body string) string {
	parsed := json2.decode[ApiErrorBody](body) or { return '' }
	if parsed.message != '' {
		return parsed.message
	}
	if parsed.error != '' {
		return parsed.error
	}
	return ''
}

// build_query builds the query string for a request, injecting the Gitee access_token.
fn build_query(params map[string]string, platform Platform, token string) string {
	mut parts := []string{}
	for k, v in params {
		if v == '' {
			continue
		}
		parts << '${urllib.query_escape(k)}=${urllib.query_escape(v)}'
	}
	if platform == .gitee && token != '' {
		parts << 'access_token=${urllib.query_escape(token)}'
	}
	return parts.join('&')
}

// sanitize_url strips the Gitee access_token query parameter from a URL.
// It is used for error reporting so that the token never appears on stderr.
fn sanitize_url(url string) string {
	if !url.contains('?') {
		return url
	}
	base := url.all_before('?')
	query := url.all_after_first('?')
	parts := query.split('&').filter(!it.starts_with('access_token='))
	if parts.len == 0 {
		return base
	}
	return base + '?' + parts.join('&')
}

// unsupported_error builds the GfError for Gitee CI which has no stable public API.
fn unsupported_error() GfError {
	return GfError{
		kind:    'unsupported'
		message: 'Gitee CI (Gitee Go) does not expose a stable public API; the ci commands are not supported on Gitee'
	}
}
