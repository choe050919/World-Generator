extends Control

## 모든 타일 타입/회전 조합을 시각적으로 표시하는 디버그 씬

@onready var container: GridContainer = $ScrollContainer/GridContainer

@export var pattern_size: int = 32  # 각 패턴의 픽셀 크기

var _visualizer: DualGridVisualizer

func _ready() -> void:
	_setup_grid()
	_generate_all_samples()

func _setup_grid() -> void:
	# 6열로 설정 (타입별로 행 구성)
	container.columns = 6

func _generate_all_samples() -> void:
	print("\n=== DEBUG: Creating visualizer with pattern_size=%d ===" % pattern_size)
	_visualizer = DualGridVisualizer.new()
	_visualizer.tile_pixel_size = pattern_size
	print("=== DEBUG: Visualizer created, generating samples ===")
	
	# EMPTY
	_add_sample_row("EMPTY", MarchingSquares.TileType.EMPTY, [0])
	
	# FULL
	_add_sample_row("FULL", MarchingSquares.TileType.FULL, [0])
	
	# CORNER
	_add_sample_row("CORNER", MarchingSquares.TileType.CORNER, [0, 90, 180, 270])
	
	# EDGE
	_add_sample_row("EDGE", MarchingSquares.TileType.EDGE, [0, 90, 180, 270])
	
	# DIAGONAL
	_add_sample_row("DIAGONAL", MarchingSquares.TileType.DIAGONAL, [0, 90])
	
	# INVERSE_CORNER
	_add_sample_row("INVERSE_CORNER", MarchingSquares.TileType.INVERSE_CORNER, [0, 90, 180, 270])
	
	print("=== DEBUG: All samples generated ===")

func _add_sample_row(type_name: String, tile_type: MarchingSquares.TileType, rotations: Array) -> void:
	# 타입 이름 레이블
	var label := Label.new()
	label.text = type_name
	label.custom_minimum_size = Vector2(120, pattern_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)
	
	# 각 회전별 패턴 표시
	for rotation in rotations:
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(pattern_size, pattern_size)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 패턴 렌더링
		var img := _render_single_pattern(tile_type, rotation)
		texture_rect.texture = ImageTexture.create_from_image(img)
		
		# 회전 각도 표시용 레이블 추가
		var vbox := VBoxContainer.new()
		vbox.add_child(texture_rect)
		
		var rot_label := Label.new()
		rot_label.text = "%d°" % rotation
		rot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rot_label)
		
		container.add_child(vbox)
	
	# 남은 칸 채우기 (6열 맞추기)
	var remaining := 6 - 1 - rotations.size()  # -1은 타입 이름 레이블
	for i in range(remaining):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(pattern_size, pattern_size)
		container.add_child(spacer)

func _render_single_pattern(tile_type: MarchingSquares.TileType, rotation: int) -> Image:
	var img := Image.create(pattern_size, pattern_size, false, Image.FORMAT_RGBA8)
	
	print("Rendering pattern: type=%d, rotation=%d, pattern_size=%d" % [tile_type, rotation, pattern_size])
	
	# 패턴 가져오기
	if not _visualizer.tile_patterns.has(tile_type):
		print("  ERROR: No patterns for tile type %d" % tile_type)
		img.fill(Color.MAGENTA)
		return img
	
	var type_patterns: Dictionary = _visualizer.tile_patterns[tile_type]
	if not type_patterns.has(rotation):
		print("  ERROR: No rotation %d for tile type %d" % [rotation, tile_type])
		img.fill(Color.YELLOW)
		return img
	
	var pattern: Array[bool] = type_patterns[rotation]
	print("  Pattern size: %d, Expected: %d" % [pattern.size(), pattern_size * pattern_size])
	
	# 패턴 렌더링
	for y in range(pattern_size):
		for x in range(pattern_size):
			var idx := y * pattern_size + x
			if idx >= pattern.size():
				print("  ERROR: Index %d out of bounds (size=%d) at (%d,%d)" % [idx, pattern.size(), x, y])
				img.set_pixel(x, y, Color.RED)  # 에러 표시
			else:
				var is_land: bool = pattern[idx]
				var color := _visualizer.land_color if is_land else _visualizer.water_color
				img.set_pixel(x, y, color)
	
	return img

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				pattern_size = min(128, pattern_size * 2)
				_refresh()
			KEY_DOWN:
				pattern_size = max(8, pattern_size / 2)
				_refresh()
			KEY_R:
				_refresh()

func _refresh() -> void:
	# 기존 샘플 제거
	for child in container.get_children():
		child.queue_free()
	
	# 재생성
	_generate_all_samples()
	
	print("Pattern size: %d" % pattern_size)
