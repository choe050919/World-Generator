extends Control

@onready var view: TextureRect = $View

@export var resolution := Vector2i(256, 256)
@export var seed: int = 777
@export var base_frequency: float = 0.03
@export var sample_scale: float = 1.0

@export var s_floor: float = 0.35
@export var v_floor: float = 0.35

var _factory := NoiseFieldFactory.new()
var _pack: Dictionary

func _ready() -> void:
	_regenerate()

func _regenerate() -> void:
	_pack = _factory.make_channel_pack(seed, base_frequency)
	_render_hsv()

func _to01(v: float) -> float:
	return clamp((v + 1.0) * 0.5, 0.0, 1.0)

func _render_hsv() -> void:
	var img := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)

	var f_h = _pack["height"]
	var f_s = _pack["moisture"]
	var f_v = _pack["temperature"]

	for y in range(resolution.y):
		for x in range(resolution.x):
			var p := Vector2(x, y) * sample_scale

			var h := _to01(f_h.sample2(p))
			var s: float = max(s_floor, _to01(f_s.sample2(p)))
			var v: float = max(v_floor, _to01(f_v.sample2(p)))

			img.set_pixel(x, y, Color.from_hsv(h, s, v, 1.0))

	view.texture = ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		seed += 1
		_regenerate()
