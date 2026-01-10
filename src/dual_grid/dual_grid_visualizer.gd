class_name DualGridVisualizer
extends RefCounted

## 물/땅 색상
var water_color := Color(0.1, 0.2, 0.5)   # 파랑
var land_color := Color(0.2, 0.6, 0.2)    # 초록

## 타일 크기 (픽셀)
var tile_pixel_size: int = 8:
	set(value):
		if value != tile_pixel_size:
			print("=== tile_pixel_size setter: %d -> %d ===" % [tile_pixel_size, value])
			tile_pixel_size = value
			_generate_all_patterns()  # 크기 변경 시 패턴 재생성

## 그리드 선 표시 여부
var show_grid: bool = false
var grid_color: Color = Color(0.0, 0.0, 0.0, 0.3)

## 미리 생성된 타일 패턴
## tile_patterns[TileType][rotation] = Array[bool] (2D를 1D로 flatten)
var tile_patterns: Dictionary = {}

func _init() -> void:
	# 초기 패턴 생성
	_generate_all_patterns()

## 모든 타일 타입/회전 조합의 패턴 생성
func _generate_all_patterns() -> void:
	print("=== Starting pattern generation, tile_pixel_size=%d ===" % tile_pixel_size)
	tile_patterns.clear()
	
	# 각 타입별로 필요한 회전 생성
	tile_patterns[MarchingSquares.TileType.EMPTY] = {
		0: _generate_pattern(MarchingSquares.TileType.EMPTY, 0)
	}
	
	tile_patterns[MarchingSquares.TileType.FULL] = {
		0: _generate_pattern(MarchingSquares.TileType.FULL, 0)
	}
	
	tile_patterns[MarchingSquares.TileType.CORNER] = {
		0: _generate_pattern(MarchingSquares.TileType.CORNER, 0),
		90: _generate_pattern(MarchingSquares.TileType.CORNER, 90),
		180: _generate_pattern(MarchingSquares.TileType.CORNER, 180),
		270: _generate_pattern(MarchingSquares.TileType.CORNER, 270),
	}
	
	tile_patterns[MarchingSquares.TileType.EDGE] = {
		0: _generate_pattern(MarchingSquares.TileType.EDGE, 0),
		90: _generate_pattern(MarchingSquares.TileType.EDGE, 90),
		180: _generate_pattern(MarchingSquares.TileType.EDGE, 180),
		270: _generate_pattern(MarchingSquares.TileType.EDGE, 270),
	}
	
	tile_patterns[MarchingSquares.TileType.DIAGONAL] = {
		0: _generate_pattern(MarchingSquares.TileType.DIAGONAL, 0),
		90: _generate_pattern(MarchingSquares.TileType.DIAGONAL, 90),
	}
	
	tile_patterns[MarchingSquares.TileType.INVERSE_CORNER] = {
		0: _generate_pattern(MarchingSquares.TileType.INVERSE_CORNER, 0),
		90: _generate_pattern(MarchingSquares.TileType.INVERSE_CORNER, 90),
		180: _generate_pattern(MarchingSquares.TileType.INVERSE_CORNER, 180),
		270: _generate_pattern(MarchingSquares.TileType.INVERSE_CORNER, 270),
	}
	
	print("=== Pattern generation complete ===")

## 특정 타입/회전의 패턴 생성
## 반환: Array[bool] - flatten된 2D 배열 (row-major)
func _generate_pattern(tile_type: MarchingSquares.TileType, rotation: int) -> Array[bool]:
	var pattern: Array[bool] = []
	var expected_size := tile_pixel_size * tile_pixel_size
	pattern.resize(expected_size)
	
	print("Generating pattern: type=%d, rotation=%d, size=%d, expected=%d" % [tile_type, rotation, tile_pixel_size, expected_size])
	
	for py in range(tile_pixel_size):
		for px in range(tile_pixel_size):
			# 타일 내 정규화 좌표 [0, 1]
			var local_x := float(px) / float(tile_pixel_size)
			var local_y := float(py) / float(tile_pixel_size)
			
			# Godot는 Y축이 아래 방향이므로, 수학 좌표계로 변환 (Y 반전)
			local_y = 1.0 - local_y
			
			# 회전 적용
			var rotated := _rotate_point(local_x, local_y, -rotation)
			var x := rotated.x
			var y := rotated.y
			
			# 타입별 판정
			var is_land := _evaluate_base_pattern(x, y, tile_type)
			
			var idx := py * tile_pixel_size + px
			pattern[idx] = is_land
	
	print("  -> Generated pattern with %d elements" % pattern.size())
	return pattern

## 기본 패턴 평가 (회전 전, 기준 형태)
## x, y는 수학 좌표계 (Y축이 위쪽 양수)
func _evaluate_base_pattern(x: float, y: float, tile_type: MarchingSquares.TileType) -> bool:
	match tile_type:
		MarchingSquares.TileType.EMPTY:
			return false
		
		MarchingSquares.TileType.FULL:
			return true
		
		MarchingSquares.TileType.CORNER:
			# NW 코너만 land (위치: 0, 1)
			# 코너를 중심으로 반지름 0.5인 원호
			# 왼쪽 모서리 중앙 (0, 0.5)와 위쪽 모서리 중앙 (0.5, 1)을 지남
			var dist_sq := x * x + (y - 1.0) * (y - 1.0)
			return dist_sq <= 0.25  # 반지름 0.5의 제곱
		
		MarchingSquares.TileType.EDGE:
			# N(위쪽) 2개 코너가 land (NW, NE)
			# 왼쪽 모서리 중앙 (0, 0.5)과 오른쪽 모서리 중앙 (1, 0.5)를 잇는 수평선
			return y >= 0.5
		
		MarchingSquares.TileType.DIAGONAL:
			# NW-SE 대각선 - NW(0, 1) + SE(1, 0) 두 코너가 land
			# 각 코너를 중심으로 반지름 0.5인 원호 두 개
			var dist_nw_sq := x * x + (y - 1.0) * (y - 1.0)
			var dist_se_sq := (x - 1.0) * (x - 1.0) + y * y
			return dist_nw_sq <= 0.25 or dist_se_sq <= 0.25
		
		MarchingSquares.TileType.INVERSE_CORNER:
			# water at NW - NE, SE, SW가 land, NW만 water
			# CORNER의 정확한 반대
			var dist_sq := x * x + (y - 1.0) * (y - 1.0)
			return dist_sq > 0.25  # 반지름 0.5 바깥쪽
	
	return false

## 점 회전 (음수는 반시계방향)
func _rotate_point(x: float, y: float, degrees: int) -> Vector2:
	var normalized_deg := (degrees % 360 + 360) % 360
	
	match normalized_deg:
		90:
			# 90도 시계방향
			return Vector2(y, 1.0 - x)
		180:
			# 180도
			return Vector2(1.0 - x, 1.0 - y)
		270:
			# 270도 시계방향
			return Vector2(1.0 - y, x)
		_:
			return Vector2(x, y)

func render(terrain: DualGridTerrain) -> Image:
	var img_width := terrain.grid_size.x * tile_pixel_size
	var img_height := terrain.grid_size.y * tile_pixel_size
	var img := Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	
	# 각 타일 렌더링
	for ty in range(terrain.grid_size.y):
		for tx in range(terrain.grid_size.x):
			var tile_result := terrain.evaluate_tile(tx, ty)
			_render_tile_from_pattern(img, tx, ty, tile_result)
	
	# 그리드 선 (선택적)
	if show_grid:
		_draw_grid(img, terrain.grid_size)
	
	return img

## 미리 생성된 패턴으로 타일 렌더링
func _render_tile_from_pattern(img: Image, tx: int, ty: int, tile_result: Dictionary) -> void:
	var tile_type: MarchingSquares.TileType = tile_result.type
	var rotation: int = tile_result.rotation
	
	# 패턴 가져오기
	if not tile_patterns.has(tile_type):
		push_error("Unknown tile type: %d" % tile_type)
		return
	
	var type_patterns: Dictionary = tile_patterns[tile_type]
	if not type_patterns.has(rotation):
		push_error("Unknown rotation %d for tile type %d" % [rotation, tile_type])
		return
	
	var pattern: Array[bool] = type_patterns[rotation]
	
	# 패턴을 이미지에 그리기
	var start_x := tx * tile_pixel_size
	var start_y := ty * tile_pixel_size
	
	for py in range(tile_pixel_size):
		for px in range(tile_pixel_size):
			var pattern_idx := py * tile_pixel_size + px
			var is_land: bool = pattern[pattern_idx]
			
			var color := land_color if is_land else water_color
			
			var x := start_x + px
			var y := start_y + py
			if x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)

func _draw_grid(img: Image, grid_size: Vector2i) -> void:
	# 세로선
	for x in range(grid_size.x + 1):
		var px := x * tile_pixel_size
		for y in range(img.get_height()):
			if px < img.get_width():
				img.set_pixel(px, y, grid_color)
	
	# 가로선
	for y in range(grid_size.y + 1):
		var py := y * tile_pixel_size
		for x in range(img.get_width()):
			if py < img.get_height():
				img.set_pixel(x, py, grid_color)
