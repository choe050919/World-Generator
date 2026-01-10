extends Control

@onready var view: TextureRect = $View

@export var resolution := Vector2i(256, 256)
@export var seed: int = 777
@export var frequency: float = 0.03
@export var sample_scale: float = 1.0

var _factory := NoiseFieldFactory.new()
var _field: NoiseField
var _visualizer: NoiseVisualizer

func _ready() -> void:
	_setup_visualizer()
	_regenerate()

func _setup_visualizer() -> void:
	_visualizer = NoiseVisualizer.new()
	
	# 커브: 중간값 강조 (선택적)
	_visualizer.curve = Curve.new()
	_visualizer.curve.add_point(Vector2(0.0, 0.0))
	_visualizer.curve.add_point(Vector2(1.0, 1.0))
	
	# 4단계 구간: 물/모래/풀/바위
	_visualizer.thresholds = [0.3, 0.5, 0.7]
	_visualizer.colors = [
		Color(0.1, 0.2, 0.5),  # 물 (파랑)
		Color(0.8, 0.7, 0.3),  # 모래 (노랑)
		Color(0.2, 0.6, 0.2),  # 풀 (초록)
		Color(0.5, 0.5, 0.5),  # 바위 (회색)
	]
	
	# 경계선 설정
	_visualizer.border_thickness = 0.015
	_visualizer.border_color = Color.BLACK

func _regenerate() -> void:
	var spec := NoiseSpec.new()
	spec.dim = NoiseSpec.Dim.D2
	spec.seed = seed
	spec.frequency = frequency
	spec.noise_type = FastNoiseLite.TYPE_SIMPLEX
	spec.fractal_type = FastNoiseLite.FRACTAL_FBM
	spec.fractal_octaves = 4
	spec.fractal_lacunarity = 2.0
	spec.fractal_gain = 0.5
	
	_field = _factory.make(spec)
	_render()

func _render() -> void:
	var img := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)
	
	for y in range(resolution.y):
		for x in range(resolution.x):
			var p := Vector2(x, y) * sample_scale
			var raw_value := _field.sample2(p)
			var color := _visualizer.process(raw_value)
			img.set_pixel(x, y, color)
	
	view.texture = ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			seed += 1
			_regenerate()
