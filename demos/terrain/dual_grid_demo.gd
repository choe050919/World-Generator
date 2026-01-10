extends Control

@onready var view: TextureRect = $View

## 그리드 설정
@export var grid_size := Vector2i(64, 64)
@export var tile_pixel_size: int = 8

## 노이즈 설정
@export var noise_seed: int = 777
@export var frequency: float = 0.05
@export var threshold: float = 0.5

## 시각화 설정
@export var show_grid: bool = false
@export var show_decorations: bool = true  # 장식물 표시

var _factory := NoiseFieldFactory.new()
var _terrain: DualGridTerrain
var _visualizer: DualGridVisualizer
var _decoration_layer: DecorationLayer

func _ready() -> void:
	_setup()
	_regenerate()

func _setup() -> void:
	_terrain = DualGridTerrain.new(grid_size)
	_terrain.threshold = threshold
	
	_visualizer = DualGridVisualizer.new()
	_visualizer.tile_pixel_size = tile_pixel_size
	_visualizer.show_grid = show_grid
	
	_decoration_layer = DecorationLayer.new()

func _regenerate() -> void:
	# 노이즈 필드 생성
	var spec := NoiseSpec.new()
	spec.dim = NoiseSpec.Dim.D2
	spec.seed = noise_seed
	spec.frequency = frequency
	spec.noise_type = FastNoiseLite.TYPE_SIMPLEX
	spec.fractal_type = FastNoiseLite.FRACTAL_FBM
	spec.fractal_octaves = 4
	
	var noise_field := _factory.make(spec)
	
	# 지형 생성
	_terrain.fill_from_noise(noise_field)
	
	# 렌더링
	_render()

func _render() -> void:
	var img := _visualizer.render(_terrain)
	
	# 장식물 레이어 적용 (선택적)
	if show_decorations:
		img = _decoration_layer.apply(img, _terrain, noise_seed)
	
	view.texture = ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				noise_seed += 1
				_regenerate()
			KEY_G:
				_visualizer.show_grid = not _visualizer.show_grid
				_render()
			KEY_D:
				show_decorations = not show_decorations
				_render()
				print("Decorations: ", "ON" if show_decorations else "OFF")
			KEY_UP:
				threshold = min(1.0, threshold + 0.05)
				_terrain.threshold = threshold
				_render()
				print("Threshold: ", threshold)
			KEY_DOWN:
				threshold = max(0.0, threshold - 0.05)
				_terrain.threshold = threshold
				_render()
				print("Threshold: ", threshold)
			KEY_EQUAL, KEY_PLUS:
				frequency = min(1.0, frequency * 1.2)
				_regenerate()
				print("Frequency: ", frequency)
			KEY_MINUS:
				frequency = max(0.001, frequency / 1.2)
				_regenerate()
				print("Frequency: ", frequency)
