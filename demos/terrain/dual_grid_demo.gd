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
#var _decoration_layer: DecorationLayer
var _decorations: DualGridDecorations

func _ready() -> void:
	_setup()
	_regenerate()

func _setup() -> void:
	_terrain = DualGridTerrain.new(grid_size)
	_terrain.threshold = threshold
	
	_visualizer = DualGridVisualizer.new()
	_visualizer.tile_pixel_size = tile_pixel_size
	_visualizer.show_grid = show_grid
	
	#_decoration_layer = DecorationLayer.new()
	_decorations = DualGridDecorations.new()
	view.add_child(_decorations)

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
	view.texture = ImageTexture.create_from_image(img)
	
	# 장식물 레이어 적용 (선택적)
	if show_decorations:
		_decorations.visible = true
		_decorations.generate(_terrain, tile_pixel_size, noise_seed)
	else:
		_decorations.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# === 생성 관련 ===
			KEY_R:
				noise_seed += 1
				_regenerate()
				print("New seed: ", noise_seed)
			
			# === 표시 토글 ===
			KEY_G:
				_visualizer.show_grid = not _visualizer.show_grid
				_render()
				print("Grid: ", "ON" if _visualizer.show_grid else "OFF")
			
			KEY_D:
				show_decorations = not show_decorations
				_render()
				print("Decorations: ", "ON" if show_decorations else "OFF")
			
			KEY_C:
				_visualizer.show_style_contours = not _visualizer.show_style_contours
				_render()
				print("Style Contours: ", "ON" if _visualizer.show_style_contours else "OFF")
			
			KEY_V:
				_visualizer.show_dev_contours = not _visualizer.show_dev_contours
				_render()
				print("Dev Contours: ", "ON" if _visualizer.show_dev_contours else "OFF")
			
			# === Threshold 조정 ===
			KEY_UP:
				threshold = min(1.0, threshold + 0.05)
				_terrain.threshold = threshold
				_render()
				print("Threshold: %.2f" % threshold)
			
			KEY_DOWN:
				threshold = max(0.0, threshold - 0.05)
				_terrain.threshold = threshold
				_render()
				print("Threshold: %.2f" % threshold)
			
			# === Frequency 조정 ===
			KEY_EQUAL, KEY_PLUS:
				frequency = min(1.0, frequency * 1.2)
				_regenerate()
				print("Frequency: %.3f" % frequency)
			
			KEY_MINUS:
				frequency = max(0.001, frequency / 1.2)
				_regenerate()
				print("Frequency: %.3f" % frequency)
			
			# === 등고선 간격 조정 ===
			KEY_BRACKETLEFT:  # [
				if _visualizer.show_dev_contours:
					_visualizer.dev_contour_step = max(0.01, _visualizer.dev_contour_step - 0.05)
					_render()
					print("Dev Contour Step: %.2f" % _visualizer.dev_contour_step)
				elif _visualizer.show_style_contours:
					_visualizer.style_contour_step = max(0.05, _visualizer.style_contour_step - 0.05)
					_render()
					print("Style Contour Step: %.2f" % _visualizer.style_contour_step)
			
			KEY_BRACKETRIGHT:  # ]
				if _visualizer.show_dev_contours:
					_visualizer.dev_contour_step = min(0.5, _visualizer.dev_contour_step + 0.05)
					_render()
					print("Dev Contour Step: %.2f" % _visualizer.dev_contour_step)
				elif _visualizer.show_style_contours:
					_visualizer.style_contour_step = min(0.5, _visualizer.style_contour_step + 0.05)
					_render()
					print("Style Contour Step: %.2f" % _visualizer.style_contour_step)
