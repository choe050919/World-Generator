extends Control

@onready var view: TextureRect = $View

@export var resolution := Vector2i(256, 256)

@export var seed: int = 777
@export var frequency: float = 0.03
@export var sample_scale: float = 1.0

var _factory := NoiseFieldFactory.new()
var _field: NoiseField

func _ready() -> void:
	_regenerate()

func _regenerate() -> void:
	var spec := NoiseSpec.new()
	spec.dim = NoiseSpec.Dim.D2
	spec.seed = seed
	spec.frequency = frequency

	# (선택) 디폴트도 되지만, 데모에서 명시해두면 혼선이 줄어듦
	spec.noise_type = FastNoiseLite.TYPE_SIMPLEX
	spec.fractal_type = FastNoiseLite.FRACTAL_FBM
	spec.fractal_octaves = 4
	spec.fractal_lacunarity = 2.0
	spec.fractal_gain = 0.5

	_field = _factory.make(spec)
	_render()

func _to01(v: float) -> float:
	return clamp((v + 1.0) * 0.5, 0.0, 1.0)

func _render() -> void:
	var img := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)

	for y in range(resolution.y):
		for x in range(resolution.x):
			var p := Vector2(x, y) * sample_scale
			var v := _field.sample2(p)        # 기대 범위 [-1, 1]
			var g := _to01(v)                 # [0, 1]
			img.set_pixel(x, y, Color(g, g, g, 1.0))

	view.texture = ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			seed += 1
			_regenerate()
