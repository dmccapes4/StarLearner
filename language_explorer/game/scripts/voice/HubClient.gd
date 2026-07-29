class_name HubClient
extends RefCounted
## HTTP client for Voice-to-Writing ASR.
## Probes configured bases (LAN first, then hub). Uses shipped hub.crt for TLS
## (self-signed hub); falls back to client_unsafe if the cert is missing.

const LOCAL_BASE := "http://127.0.0.1:8770"
const HUB_ASR_BASE := "https://starlearner.dylanmccapes.systems/api/asr"
const TIMEOUT_SEC := 60.0
const HEALTH_TIMEOUT_SEC := 8.0

static var _active_base: String = ""

static func config() -> Dictionary:
	var path := "res://data/hub_client.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
	return {}

static func candidate_bases() -> Array:
	var out: Array = []
	var cfg := config()
	if cfg.has("bases") and typeof(cfg["bases"]) == TYPE_ARRAY:
		for b in cfg["bases"]:
			var s := str(b).strip_edges().rstrip("/")
			if not s.is_empty() and not out.has(s):
				out.append(s)
	if cfg.has("base"):
		var one := str(cfg["base"]).strip_edges().rstrip("/")
		if not one.is_empty() and not out.has(one):
			out.append(one)
	# Desktop convenience.
	if OS.has_feature("editor") or OS.get_name() in ["Linux", "Windows", "macOS"]:
		if not out.has(LOCAL_BASE):
			out.push_front(LOCAL_BASE)
	if out.is_empty():
		out.append(HUB_ASR_BASE)
	return out

static func base_url() -> String:
	if not _active_base.is_empty():
		return _active_base
	var bases := candidate_bases()
	if not bases.is_empty():
		return str(bases[0])
	return HUB_ASR_BASE

static func auth_token() -> String:
	var cfg := config()
	if cfg.has("token"):
		return str(cfg["token"])
	return ""

static func _tls_for_url(url: String) -> TLSOptions:
	if not url.begins_with("https://"):
		return null
	# Legacy 245 hub used a self-signed cert (pinned via hub.crt). Cloudflare
	# edge certs need the system trust store — pinning hub.crt would fail.
	var needs_pin := ("hub.starlearner.app" in url) or (":8443" in url)
	if needs_pin:
		var cert := X509Certificate.new()
		if cert.load("res://data/hub.crt") == OK:
			return TLSOptions.client(cert)
		return TLSOptions.client_unsafe()
	return TLSOptions.client()

static func _apply_tls(http: HTTPRequest, url: String) -> void:
	var tls := _tls_for_url(url)
	if tls != null:
		http.set_tls_options(tls)

static func online_probe(tree: SceneTree) -> bool:
	_active_base = ""
	for base in candidate_bases():
		var url := "%s/health" % str(base)
		var http := HTTPRequest.new()
		tree.root.add_child(http)
		http.timeout = HEALTH_TIMEOUT_SEC
		_apply_tls(http, url)
		var err := http.request(url, _headers(), HTTPClient.METHOD_GET)
		if err != OK:
			http.queue_free()
			continue
		var result: Array = await http.request_completed
		http.queue_free()
		var code: int = int(result[1])
		if code == 200:
			_active_base = str(base)
			return true
	return false

static func voice_write(tree: SceneTree, wav_res_path: String, lang: String = "en") -> Dictionary:
	return await _post_audio(tree, "/v1/voice_write", wav_res_path, {"lang": lang})

static func command(tree: SceneTree, wav_res_path: String) -> Dictionary:
	return await _post_audio(tree, "/v1/command", wav_res_path, {})

static func _headers() -> PackedStringArray:
	var h := PackedStringArray(["Accept: application/json"])
	var tok := auth_token()
	# Bearer only needed for hub; harmless on local ASR.
	if not tok.is_empty():
		h.append("Authorization: Bearer %s" % tok)
	return h

static func _post_audio(tree: SceneTree, route: String, wav_res_path: String, fields: Dictionary) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(wav_res_path)
	if not FileAccess.file_exists(abs_path):
		return {"ok": false, "error": "missing_file"}
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "open_failed"}
	var audio: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var boundary := "----LangVoice%x" % Time.get_ticks_msec()
	var body := PackedByteArray()
	for key in fields.keys():
		body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
		body.append_array(('Content-Disposition: form-data; name="%s"\r\n\r\n' % str(key)).to_utf8_buffer())
		body.append_array(str(fields[key]).to_utf8_buffer())
		body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array('Content-Disposition: form-data; name="audio"; filename="clip.wav"\r\n'.to_utf8_buffer())
	body.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	body.append_array(audio)
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())

	# If no active base yet, probe once.
	if _active_base.is_empty():
		await online_probe(tree)
	if _active_base.is_empty():
		return {"ok": false, "error": "offline"}

	var http := HTTPRequest.new()
	tree.root.add_child(http)
	http.timeout = TIMEOUT_SEC
	var headers := _headers()
	headers.append("Content-Type: multipart/form-data; boundary=%s" % boundary)
	var url := "%s%s" % [base_url(), route]
	_apply_tls(http, url)
	var err := http.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "request_failed", "code": err}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = int(result[1])
	var raw_body: PackedByteArray = result[3]
	var text := raw_body.get_string_from_utf8()
	if code < 200 or code >= 300:
		return {"ok": false, "error": "http_%d" % code, "body": text}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_json", "body": text}
	var d: Dictionary = parsed
	if not d.has("ok"):
		d["ok"] = true
	return d
