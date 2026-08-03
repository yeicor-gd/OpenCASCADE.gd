@tool
class_name OpenCascadeGithubDownloader
extends RefCounted
## Editor-only helper for the OpenCASCADE.gd addon.
##
## Locates the GDExtension library that applies to the current editor platform or to an
## export preset (mirroring Godot's own [libraries] selection) and downloads it from the
## GitHub Actions artifacts of the OpenCASCADE.gd repository.
##
## All network access goes through a synchronous [HTTPClient], so these helpers can be used
## both from the editor dock (on user action) and from [method EditorExportPlugin._export_begin]
## (where the export loop cannot yield back to the main loop).

const REPO_OWNER := "yeicor-gd"
const REPO_NAME := "OCCT-Light.gd"

const ADDON_DIR := "res://addons/OpenCASCADE.gd"
const EXTENSION_CONFIG_PATH := "res://addons/OpenCASCADE.gd/gdext.gdextension"

const LIST_TIMEOUT_MSEC := 30_000
const DOWNLOAD_TIMEOUT_MSEC := 15 * 60 * 1000
const MAX_REDIRECTS := 5
const MAX_LIST_BODY := 8 * 1024 * 1024
const MAX_LIST_PAGES := 10

static var _trusted_ca: X509Certificate = null


## TLS options for client connections. Uses the OS CA bundle explicitly so that this plugin does
## not depend on Godot's built-in default certificates (which some builds fail to initialize).
static func _tls_options() -> TLSOptions:
	if _trusted_ca == null:
		var pem := OS.get_system_ca_certificates()
		if not pem.is_empty():
			var path := OS.get_temp_dir().path_join("opencascade-gd-ca.pem")
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(pem)
				file.close()
				var cert := X509Certificate.new()
				if cert.load(path) == OK:
					_trusted_ca = cert
				DirAccess.remove_absolute(path)
	if _trusted_ca != null:
		return TLSOptions.client(_trusted_ca)
	return TLSOptions.client()


## Builds the nightly.link URL that serves a specific artifact without requiring authentication.
## Resolving by artifact ID avoids nightly.link's per-run listing limit of 100 artifacts.
static func nightly_link_url(artifact_id: int) -> String:
	return "https://nightly.link/%s/%s/actions/artifacts/%d.zip" % [REPO_OWNER, REPO_NAME, artifact_id]


static func addon_dir() -> String:
	return ProjectSettings.globalize_path(ADDON_DIR)


static func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(EXTENSION_CONFIG_PATH) != OK:
		return null
	return config


## Picks the [libraries] entry whose tags are all satisfied by `predicate`, choosing the most
## specific one. This mirrors GDExtensionLibraryLoader::find_extension_library().
static func best_key(predicate: Callable) -> String:
	var config := _load_config()
	if config == null or not config.has_section("libraries"):
		return ""
	var best := ""
	var best_tags := 0
	for key in config.get_section_keys("libraries"):
		var tags := String(key).split(".")
		if tags.size() <= best_tags:
			continue
		var all_met := true
		for raw in tags:
			if not predicate.call(raw.strip_edges()):
				all_met = false
				break
		if all_met:
			best = key
			best_tags = tags.size()
	return best


static func best_key_for_os() -> String:
	return best_key(Callable(OS, "has_feature"))


static func best_key_for_features(features: PackedStringArray) -> String:
	return best_key(func(tag: String) -> bool: return features.has(tag))


static func library_filename(key: String) -> String:
	if key.is_empty():
		return ""
	var config := _load_config()
	if config == null:
		return ""
	return config.get_value("libraries", key, "")


static func library_abs_path(key: String) -> String:
	var filename := library_filename(key)
	if filename.is_empty():
		return ""
	return addon_dir().path_join(filename)


static func library_modified_time(key: String) -> int:
	var abs := library_abs_path(key)
	if not FileAccess.file_exists(abs):
		return 0
	return int(FileAccess.get_modified_time(abs))


## Maps a [libraries] key (e.g. "linux.x86_64.debug.single") to the vcpkg triplet used by the
## GitHub Actions build matrix (and therefore to the artifact name).
static func triplet_for_key(key: String) -> String:
	var parts := key.split(".")
	if parts.size() < 2:
		return ""
	match [parts[0], parts[1]]:
		["linux", "x86_64"]:
			return "x64-linux"
		["linux", "x86_32"]:
			return "x86-linux"
		["linux", "arm64"]:
			return "arm64-linux"
		["linux", "arm32"]:
			return "arm-linux"
		["windows", "x86_64"]:
			return "x64-windows-static"
		["windows", "x86_32"]:
			return "x86-windows-static"
		["windows", "arm64"]:
			return "arm64-windows-static"
		["macos", "universal"]:
			return "universal-osx"
		["web", "wasm32"]:
			return "wasm32-emscripten"
		["android", "x86_64"]:
			return "x64-android"
		["android", "x86_32"]:
			return "x86-android"
		["android", "arm64"]:
			return "arm64-android"
		["android", "arm32"]:
			return "arm-neon-android"
		["ios", "arm64"]:
			return "arm64-ios"
	return ""


## The GitHub Actions artifact that contains the library for `key` (e.g.
## "gdext-x64-linux-template_debug-single" or "gdext-wasm32-emscripten-template_debug-single-on").
static func artifact_name_for_key(key: String) -> String:
	var triplet := triplet_for_key(key)
	if triplet.is_empty():
		return ""
	var parts := key.split(".")
	var target_type := "template_debug" if parts.has("debug") else "template_release"
	var precision := parts[parts.size() - 1]
	var name := "gdext-%s-%s-%s" % [triplet, target_type, precision]
	if parts.has("threads"):
		name += "-on"
	return name


static func format_bytes(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.2f GiB" % (bytes / (1024.0 * 1024.0 * 1024.0))
	if bytes >= 1024 * 1024:
		return "%.1f MiB" % (bytes / (1024.0 * 1024.0))
	if bytes >= 1024:
		return "%.1f KiB" % (bytes / 1024.0)
	return "%d B" % bytes


## Parses a GitHub "YYYY-MM-DDTHH:MM:SSZ" timestamp into milliseconds since the Unix epoch.
static func github_time_to_msec(iso: String) -> int:
	var date_time := iso.split("T")
	if date_time.size() != 2:
		return 0
	var date := date_time[0].split("-")
	var time_parts := date_time[1].split(":")
	if date.size() < 3 or time_parts.size() < 3:
		return 0
	var seconds := int(time_parts[2].substr(0, 2))
	var dict := {
		"year": int(date[0]),
		"month": int(date[1]),
		"day": int(date[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": seconds,
	}
	return int(Time.get_unix_time_from_datetime_dict(dict)) * 1000


static func _split_url(url: String) -> Dictionary:
	var rest := url
	var ssl := false
	if rest.begins_with("https://"):
		ssl = true
		rest = rest.trim_prefix("https://")
	elif rest.begins_with("http://"):
		rest = rest.trim_prefix("http://")
	else:
		return {}
	var host_and_port := rest
	var path := "/"
	var slash := rest.find("/")
	if slash != -1:
		host_and_port = rest.substr(0, slash)
		path = rest.substr(slash)
	if path.is_empty():
		path = "/"
	var port := 443 if ssl else 80
	var host := host_and_port
	if host_and_port.contains(":"):
		var bits := host_and_port.split(":")
		host = bits[0]
		port = bits[1].to_int()
	if host.is_empty():
		return {}
	return {"host": host, "port": port, "ssl": ssl, "path": path}


static func _response_header(client: HTTPClient, name: String) -> String:
	var headers := client.get_response_headers_as_dictionary()
	for k in headers:
		if String(k).to_lower() == name.to_lower():
			return str(headers[k])
	return ""


static func _elapsed_since(started_msec: int) -> int:
	return Time.get_ticks_msec() - started_msec


static func _http_error_message(code: int, body: String, host: String) -> String:
	var message := "HTTP %d from %s" % [code, host]
	if not body.is_empty():
		var parsed := JSON.parse_string(body)
		if parsed is Dictionary and parsed.has("message"):
			message += ": %s" % parsed["message"]
		elif parsed is Dictionary and parsed.has("error"):
			message += ": %s" % parsed["error"]
		else:
			message += ": %s" % body.strip_edges().left(300)
	if code == 401 or code == 403 or code == 429:
		message += " (GitHub may be rate limiting requests; retry in a few minutes)"
	return message


## Synchronous GET with redirect following. When `body_sink` is valid it receives the body in
## chunks (useful for streaming a large download to disk); otherwise the body is accumulated in
## memory (capped by `max_body`) and returned as "body".
static func _get_sync(url: String, headers: PackedStringArray, body_sink: Callable, timeout_msec: int, max_body: int) -> Dictionary:
	var client := HTTPClient.new()
	client.read_chunk_size = 1 << 16
	var started := Time.get_ticks_msec()
	var redirects := 0
	var target := url
	var u := {}
	var buffered := PackedByteArray()
	while true:
		u = _split_url(target)
		if u.is_empty():
			client.close()
			return {"ok": false, "error": "Invalid URL: %s" % target}
		var err := client.connect_to_host(u["host"], u["port"], _tls_options() if u["ssl"] else null)
		if err != OK:
			client.close()
			return {"ok": false, "error": "Failed to connect to %s: %s" % [u["host"], error_string(err)]}
		while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
			client.poll()
			if _elapsed_since(started) > timeout_msec:
				client.close()
				return {"ok": false, "error": "Timeout connecting to %s" % u["host"]}
			OS.delay_msec(5)
		var status := client.get_status()
		if status in [HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
			client.close()
			return {"ok": false, "error": "Could not connect to %s (status %d)" % [u["host"], status]}
		err = client.request(HTTPClient.METHOD_GET, u["path"], headers)
		if err != OK:
			client.close()
			return {"ok": false, "error": "Request to %s failed: %s" % [target, error_string(err)]}
		while not client.has_response():
			client.poll()
			if _elapsed_since(started) > timeout_msec:
				client.close()
				return {"ok": false, "error": "Timeout waiting for response from %s" % u["host"]}
			OS.delay_msec(5)
		var code := client.get_response_code()
		if code >= 300 and code < 400:
			redirects += 1
			var location := _response_header(client, "location")
			var old_host: String = u["host"]
			client.close()
			if redirects > MAX_REDIRECTS:
				return {"ok": false, "error": "Too many redirects downloading %s" % url}
			if location.is_empty():
				return {"ok": false, "error": "Redirect response without a Location header from %s" % u["host"]}
			target = location
			# Do not forward credentials to a different host (the SAS-signed redirect
			# URL is authoritative; Azure blob storage rejects an Authorization header).
			var redirected := _split_url(target)
			if not redirected.is_empty() and String(redirected["host"]).to_lower() != old_host.to_lower():
				for i in range(headers.size() - 1, -1, -1):
					if String(headers[i]).begins_with("Authorization:"):
						headers.remove_at(i)
			continue
		if code != 200:
			var error_body := ""
			while client.get_status() == HTTPClient.STATUS_BODY:
				client.poll()
				var chunk := client.read_response_body_chunk()
				if chunk.size() > 0:
					error_body += chunk.get_string_from_utf8()
					if error_body.length() > 4096:
						break
				OS.delay_msec(5)
			client.close()
			return {"ok": false, "error": _http_error_message(code, error_body, u["host"])}
		break
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			if body_sink.is_valid():
				body_sink.call(chunk)
			else:
				buffered.append_array(chunk)
				if max_body > 0 and buffered.size() > max_body:
					client.close()
					return {"ok": false, "error": "Response exceeded %d bytes" % max_body}
		if _elapsed_since(started) > timeout_msec:
			client.close()
			return {"ok": false, "error": "Timeout downloading from %s" % u["host"]}
		OS.delay_msec(5)
	client.close()
	var result := {"ok": true}
	if body_sink.is_valid():
		result["bytes"] = buffered.size()
	else:
		result["body"] = buffered.get_string_from_utf8()
	return result


## Lists the newest non-expired artifact for each requested artifact name.
## The GitHub API returns artifacts newest-first across all runs, so a single paginated scan
## (a few requests) covers every name, including ones that fall outside nightly.link's per-run
## listing limit of 100 artifacts. No authentication is required for public repositories.
## Returns { ok: bool, error?, artifacts: {name: artifact_dict} }.
static func list_artifacts(names: PackedStringArray) -> Dictionary:
	var wanted := {}
	for name in names:
		if not name.is_empty():
			wanted[name] = true
	if wanted.is_empty():
		return {"ok": true, "artifacts": {}}
	var headers := PackedStringArray(["User-Agent: OpenCASCADE.gd-editor-plugin", "Accept: application/vnd.github+json"])
	var found := {}
	for page in range(1, MAX_LIST_PAGES + 1):
		var url := "https://api.github.com/repos/%s/%s/actions/artifacts?per_page=100&page=%d" % [REPO_OWNER, REPO_NAME, page]
		var result := _get_sync(url, headers, Callable(), LIST_TIMEOUT_MSEC, MAX_LIST_BODY)
		if not result.get("ok", false):
			return {"ok": false, "error": result.get("error", "Failed to list artifacts")}
		var parsed := JSON.parse_string(result.get("body", ""))
		if parsed == null or not (parsed is Dictionary) or not parsed.has("artifacts"):
			return {"ok": false, "error": "Unexpected GitHub API response: %s" % String(result.get("body", "")).strip_edges().left(300)}
		var page_artifacts: Array = parsed.get("artifacts", [])
		if page_artifacts.is_empty():
			break
		for art in page_artifacts:
			if art is Dictionary:
				var name := String(art.get("name", ""))
				if wanted.has(name) and not found.has(name) and not art.get("expired", false):
					found[name] = art
		if found.size() >= wanted.size():
			break
	return {"ok": true, "artifacts": found}


## Returns the newest non-expired artifact for `key`, or {} when none is available.
static func newest_artifact_for_key(key: String) -> Dictionary:
	if key.is_empty():
		return {}
	var name := artifact_name_for_key(key)
	if name.is_empty():
		return {}
	var result := list_artifacts(PackedStringArray([name]))
	if not result.get("ok", false):
		return {"error": result.get("error", "Failed to list artifacts")}
	var artifacts: Dictionary = result.get("artifacts", {})
	return artifacts.get(name, {})


## Downloads an artifact zip from nightly.link (no authentication needed). The optional `progress`
## callable receives the number of bytes written so far; `total_bytes` lets the caller compute a ratio.
static func download_artifact_zip(artifact_id: int, zip_path: String, progress: Callable = Callable(), total_bytes: int = 0) -> Dictionary:
	var url := nightly_link_url(artifact_id)
	var headers := PackedStringArray(["User-Agent: OpenCASCADE.gd-editor-plugin"])
	var file := FileAccess.open(zip_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot open %s for writing" % zip_path}
	var started := Time.get_ticks_msec()
	var state := {"written": 0}
	var result := _get_sync(url, headers, func(chunk: PackedByteArray) -> void:
		file.store_buffer(chunk)
		state["written"] = state["written"] + chunk.size()
		if progress.is_valid():
			progress.call(state["written"], total_bytes)
	, DOWNLOAD_TIMEOUT_MSEC, 0)
	file.close()
	if not result.get("ok", false):
		DirAccess.remove_absolute(zip_path)
		return result
	return {"ok": true, "bytes": state["written"], "elapsed_msec": _elapsed_since(started)}


## Extracts `filename` from the zip at `zip_path` into `dest_dir` (absolute paths).
## The zip stores files under a `demo/addons/OpenCASCADE.gd/` prefix, so entries are matched by name.
static func extract_library(zip_path: String, filename: String, dest_dir: String) -> Dictionary:
	var zip := ZIPReader.new()
	var err := zip.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "Cannot open downloaded zip: %s" % error_string(err)}
	var entry := ""
	for name in zip.get_files():
		if name.get_file() == filename:
			entry = name
			break
	zip.close()
	if entry.is_empty():
		return {"ok": false, "error": "'%s' not found in the downloaded artifact" % filename}
	zip = ZIPReader.new()
	if zip.open(zip_path) != OK:
		return {"ok": false, "error": "Cannot open downloaded zip: %s" % error_string(err)}
	var dest_abs := dest_dir.path_join(filename)
	var file := FileAccess.open(dest_abs, FileAccess.WRITE)
	if file == null:
		zip.close()
		return {"ok": false, "error": "Cannot open %s for writing" % dest_abs}
	file.store_buffer(zip.read_file(entry))
	file.close()
	zip.close()
	FileAccess.set_unix_permissions(dest_abs, 493)
	return {"ok": true}


## Downloads and installs the library for `key` into the addon folder (replacing any existing one).
## `progress` (optional) receives `(bytes_written, total_bytes)`.
static func install_library_for_key(key: String, progress: Callable = Callable()) -> Dictionary:
	var filename := library_filename(key)
	if filename.is_empty():
		return {"ok": false, "error": "No library configured for '%s'" % key}
	var artifact := newest_artifact_for_key(key)
	if artifact.is_empty():
		return {"ok": false, "error": "No non-expired '%s' artifact found on GitHub Actions (the build may not have finished or may have expired)." % artifact_name_for_key(key)}
	if not artifact.has("id"):
		return artifact
	var zip_abs := ProjectSettings.globalize_path("user://opencascade-gdext-%d.zip" % artifact.get("id", 0))
	var dl := download_artifact_zip(int(artifact.get("id", 0)), zip_abs, progress, int(artifact.get("size_in_bytes", 0)))
	if not dl.get("ok", false):
		return dl
	var ex := extract_library(zip_abs, filename, addon_dir())
	DirAccess.remove_absolute(zip_abs)
	if not ex.get("ok", false):
		return ex
	return {"ok": true, "filename": filename, "artifact": artifact, "bytes": dl.get("bytes", 0)}


## Downloads and installs the library for `key` only when the file is missing locally.
static func ensure_library(key: String) -> Dictionary:
	if key.is_empty():
		return {"ok": true, "downloaded": false, "skipped": true}
	var abs := library_abs_path(key)
	if FileAccess.file_exists(abs):
		return {"ok": true, "downloaded": false, "filename": library_filename(key)}
	return install_library_for_key(key)
