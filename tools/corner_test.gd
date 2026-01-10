extends Control

## 16가지 코너 조합을 모두 표시하고 검증

@onready var container: GridContainer = $ScrollContainer/GridContainer

@export var pattern_size: int = 64

var _visualizer: DualGridVisualizer

func _ready() -> void:
	container.columns = 4
	_visualizer = DualGridVisualizer.new()
	_visualizer.tile_pixel_size = pattern_size
	
	_generate_all_combinations()

func _to_binary_string(value: int, bits: int = 4) -> String:
	var result := ""
	for i in range(bits - 1, -1, -1):
		result += "1" if (value & (1 << i)) else "0"
	return result

func _generate_all_combinations() -> void:
	print("\n=== Testing all 16 corner combinations ===")
	
	# 16가지 비트마스크 (0000 ~ 1111)
	for bitmask in range(16):
		var nw := bool(bitmask & 0b1000)
		var ne := bool(bitmask & 0b0100)
		var sw := bool(bitmask & 0b0010)
		var se := bool(bitmask & 0b0001)
		
		# MarchingSquares 결과
		var result := MarchingSquares.evaluate(nw, ne, sw, se)
		
		var binary_str := _to_binary_string(bitmask)
		print("%s (NW=%d NE=%d SW=%d SE=%d) -> Type=%d Rotation=%d" % [
			binary_str, int(nw), int(ne), int(sw), int(se), result.type, result.rotation
		])
		
		# UI 생성
		var vbox := VBoxContainer.new()
		
		# 비트마스크 표시
		var label := Label.new()
		label.text = "%s\n%s %d°" % [binary_str, _type_name(result.type), result.rotation]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		
		# 패턴 렌더링
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(pattern_size, pattern_size)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var img := _render_with_corners(result, nw, ne, sw, se)
		texture_rect.texture = ImageTexture.create_from_image(img)
		
		vbox.add_child(texture_rect)
		container.add_child(vbox)

func _render_with_corners(result: Dictionary, nw: bool, ne: bool, sw: bool, se: bool) -> Image:
	var img := Image.create(pattern_size, pattern_size, false, Image.FORMAT_RGBA8)
	
	var rotation: int = result.rotation
	
	# 패턴 가져오기
	if not _visualizer.tile_patterns.has(result.type):
		img.fill(Color.MAGENTA)
		return img
	
	var type_patterns: Dictionary = _visualizer.tile_patterns[result.type]
	if not type_patterns.has(rotation):
		img.fill(Color.YELLOW)
		return img
	
	var pattern: Array[bool] = type_patterns[rotation]
	
	# 패턴 렌더링
	for y in range(pattern_size):
		for x in range(pattern_size):
			var idx := y * pattern_size + x
			var is_land: bool = pattern[idx]
			var color := _visualizer.land_color if is_land else _visualizer.water_color
			img.set_pixel(x, y, color)
	
	# 코너 표시 (빨간 점)
	var corner_size := 4
	var corners := [
		{"pos": Vector2(0, 0), "val": nw},           # NW (왼쪽 위)
		{"pos": Vector2(pattern_size-1, 0), "val": ne},  # NE (오른쪽 위)
		{"pos": Vector2(0, pattern_size-1), "val": sw},  # SW (왼쪽 아래)
		{"pos": Vector2(pattern_size-1, pattern_size-1), "val": se}  # SE (오른쪽 아래)
	]
	
	for corner in corners:
		var pos: Vector2 = corner.pos
		var is_land: bool = corner.val
		var marker_color := Color.RED if is_land else Color.CYAN
		
		for dy in range(-corner_size, corner_size+1):
			for dx in range(-corner_size, corner_size+1):
				var px := int(pos.x) + dx
				var py := int(pos.y) + dy
				if px >= 0 and px < pattern_size and py >= 0 and py < pattern_size:
					img.set_pixel(px, py, marker_color)
	
	return img

func _type_name(tile_type: MarchingSquares.TileType) -> String:
	match tile_type:
		MarchingSquares.TileType.EMPTY: return "EMPTY"
		MarchingSquares.TileType.FULL: return "FULL"
		MarchingSquares.TileType.CORNER: return "CORNER"
		MarchingSquares.TileType.EDGE: return "EDGE"
		MarchingSquares.TileType.DIAGONAL: return "DIAG"
		MarchingSquares.TileType.INVERSE_CORNER: return "INV"
		_: return "???"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		for child in container.get_children():
			child.queue_free()
		_generate_all_combinations()
