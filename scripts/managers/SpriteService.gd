extends Node
class_name SpriteService

signal sprite_ready(pokedex_id: int, texture: Texture2D)
signal sprite_failed(pokedex_id: int)
signal back_sprite_ready(pokedex_id: int, texture: Texture2D)
signal back_sprite_failed(pokedex_id: int)

const CACHE_DIR := "user://sprite_cache"
const API_SPRITE_URL_TEMPLATE := "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/%d.png"
const API_BACK_SPRITE_URL_TEMPLATE := "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/%d.png"

var in_memory_cache: Dictionary = {}
var in_memory_back_cache: Dictionary = {}
var pending_requests: Dictionary = {}
var pending_back_requests: Dictionary = {}


func _ready() -> void:
	_ensure_cache_dir_exists()


func request_sprite(pokedex_id: int) -> void:
	if in_memory_cache.has(pokedex_id):
		var cached_texture: Texture2D = in_memory_cache[pokedex_id]
		emit_signal("sprite_ready", pokedex_id, cached_texture)
		return

	var cache_path: String = _cache_path_for_id(pokedex_id)
	if FileAccess.file_exists(cache_path):
		var loaded_texture: Texture2D = _texture_from_png_file(cache_path)
		if loaded_texture != null:
			in_memory_cache[pokedex_id] = loaded_texture
			emit_signal("sprite_ready", pokedex_id, loaded_texture)
			return

	if pending_requests.has(pokedex_id):
		return

	pending_requests[pokedex_id] = true
	_download_sprite_from_api(pokedex_id)


func request_back_sprite(pokedex_id: int) -> void:
	if in_memory_back_cache.has(pokedex_id):
		var cached_texture: Texture2D = in_memory_back_cache[pokedex_id]
		emit_signal("back_sprite_ready", pokedex_id, cached_texture)
		return

	var cache_path: String = _cache_path_for_id(pokedex_id, true)
	if FileAccess.file_exists(cache_path):
		var loaded_texture: Texture2D = _texture_from_png_file(cache_path)
		if loaded_texture != null:
			in_memory_back_cache[pokedex_id] = loaded_texture
			emit_signal("back_sprite_ready", pokedex_id, loaded_texture)
			return

	if pending_back_requests.has(pokedex_id):
		return

	pending_back_requests[pokedex_id] = true
	_download_sprite_from_api(pokedex_id, true)


func _download_sprite_from_api(pokedex_id: int, is_back: bool = false) -> void:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var url: String = API_SPRITE_URL_TEMPLATE % pokedex_id
	if is_back:
		url = API_BACK_SPRITE_URL_TEMPLATE % pokedex_id
	var request_err: int = request.request(url)
	if request_err != OK:
		if is_back:
			pending_back_requests.erase(pokedex_id)
		else:
			pending_requests.erase(pokedex_id)
		request.queue_free()
		if is_back:
			emit_signal("back_sprite_failed", pokedex_id)
		else:
			emit_signal("sprite_failed", pokedex_id)
		return

	var response: Array = await request.request_completed
	request.queue_free()
	if is_back:
		pending_back_requests.erase(pokedex_id)
	else:
		pending_requests.erase(pokedex_id)

	var result_code: int = int(response[0])
	var response_code: int = int(response[1])
	var body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if is_back:
			emit_signal("back_sprite_failed", pokedex_id)
		else:
			emit_signal("sprite_failed", pokedex_id)
		return

	var texture: Texture2D = _texture_from_png_body(body)
	if texture == null:
		if is_back:
			emit_signal("back_sprite_failed", pokedex_id)
		else:
			emit_signal("sprite_failed", pokedex_id)
		return

	_write_sprite_cache_file(pokedex_id, body, is_back)
	if is_back:
		in_memory_back_cache[pokedex_id] = texture
		emit_signal("back_sprite_ready", pokedex_id, texture)
	else:
		in_memory_cache[pokedex_id] = texture
		emit_signal("sprite_ready", pokedex_id, texture)


func _texture_from_png_body(body: PackedByteArray) -> Texture2D:
	var image: Image = Image.new()
	var parse_err: int = image.load_png_from_buffer(body)
	if parse_err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _write_sprite_cache_file(pokedex_id: int, body: PackedByteArray, is_back: bool = false) -> void:
	var file: FileAccess = FileAccess.open(_cache_path_for_id(pokedex_id, is_back), FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(body)


func _texture_from_png_file(path: String) -> Texture2D:
	var image: Image = Image.new()
	var load_err: int = image.load(path)
	if load_err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _cache_path_for_id(pokedex_id: int, is_back: bool = false) -> String:
	if is_back:
		return "%s/%d_back.png" % [CACHE_DIR, pokedex_id]
	return "%s/%d.png" % [CACHE_DIR, pokedex_id]


func _ensure_cache_dir_exists() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("sprite_cache"):
		dir.make_dir("sprite_cache")
