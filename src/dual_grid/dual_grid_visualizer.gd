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

## Dev 등고선 (디버그용)
var show_dev_contours: bool = false
var dev_contour_step: float = 0.1
var dev_contour_color: Color = Color.WHITE

## Style 등고선 (스타일 요소)
var show_style_contours: bool = false
var style_contour_step: float = 0.2
var style_contour_color: Color = Color(0.0, 0.0, 0.0, 0.5)

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
	
	# Style 등고선 (land/water 렌더링 위에)
	if show_style_contours:
		_draw_style_contours(img, terrain)
	
	# 그리드 선 (선택적)
	if show_grid:
		_draw_grid(img, terrain.grid_size)
	
	# Dev 등고선 (맨 위 - 디버그 오버레이)
	if show_dev_contours:
		_draw_contours_with_params(img, terrain, dev_contour_step, dev_contour_color)
	
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


## =========================
## Contour rendering
## =========================

## 등고선 그리기 (공통 로직)
func _draw_contours_with_params(img: Image, terrain: DualGridTerrain, step: float, color: Color) -> void:
	if step <= 0.0:
		return
	
	# 스칼라 범위 산출
	var min_v := 1.0
	var max_v := 0.0
	for v in terrain.corner_values:
		if v < min_v: min_v = v
		if v > max_v: max_v = v
	
	# threshold를 중심으로 등고선 생성
	var center := terrain.threshold
	var levels: Array[float] = []
	
	# 중심선
	levels.append(center)
	
	# 위아래로 확장
	var i := 1
	while true:
		var upper := center + step * i
		var lower := center - step * i
		
		var added := false
		if upper <= max_v:
			levels.append(upper)
			added = true
		if lower >= min_v:
			levels.append(lower)
			added = true
		
		if not added:
			break
		i += 1
	
	# 각 레벨마다 등고선 그리기
	for level in levels:
		if level >= min_v and level <= max_v:
			_draw_contour_level(img, terrain, level, color)

## 특정 레벨의 등고선 그리기
func _draw_contour_level(img: Image, terrain: DualGridTerrain, iso: float, color: Color) -> void:
	var w := terrain.grid_size.x
	var h := terrain.grid_size.y
	
	for ty in range(h):
		for tx in range(w):
			# 타일의 4개 코너 스칼라 값
			var nw := terrain.get_corner(tx, ty)           # NW
			var ne := terrain.get_corner(tx + 1, ty)       # NE
			var sw := terrain.get_corner(tx, ty + 1)       # SW
			var se := terrain.get_corner(tx + 1, ty + 1)   # SE
			
			_draw_iso_in_tile(img, tx, ty, nw, ne, sw, se, iso, color)

## 표준 marching squares isoline (16케이스)
## 좌표계: (0,0)=NW, (1,0)=NE, (0,1)=SW, (1,1)=SE
func _draw_iso_in_tile(
	img: Image,
	tx: int,
	ty: int,
	nw: float,
	ne: float,
	sw: float,
	se: float,
	iso: float,
	color: Color
) -> void:
	# 케이스 인덱스 (NW,NE,SE,SW) = 8,4,2,1
	var b_nw := int(nw >= iso)
	var b_ne := int(ne >= iso)
	var b_se := int(se >= iso)
	var b_sw := int(sw >= iso)
	var case_idx := (b_nw << 3) | (b_ne << 2) | (b_se << 1) | b_sw
	
	if case_idx == 0 or case_idx == 15:
		return
	
	# edge 교차 여부
	var has_top := (b_nw != b_ne)
	var has_right := (b_ne != b_se)
	var has_bottom := (b_sw != b_se)
	var has_left := (b_nw != b_sw)
	
	var p_top: Vector2
	var p_right: Vector2
	var p_bottom: Vector2
	var p_left: Vector2
	
	if has_top:
		p_top = Vector2(_edge_t(nw, ne, iso), 0.0)
	if has_right:
		p_right = Vector2(1.0, _edge_t(ne, se, iso))
	if has_bottom:
		p_bottom = Vector2(_edge_t(sw, se, iso), 1.0)
	if has_left:
		p_left = Vector2(0.0, _edge_t(nw, sw, iso))
	
	match case_idx:
		1, 14:
			_draw_segment(img, tx, ty, p_left, p_bottom, color)
		2, 13:
			_draw_segment(img, tx, ty, p_right, p_bottom, color)
		3, 12:
			_draw_segment(img, tx, ty, p_left, p_right, color)
		4, 11:
			_draw_segment(img, tx, ty, p_top, p_right, color)
		6, 9:
			_draw_segment(img, tx, ty, p_top, p_bottom, color)
		7, 8:
			_draw_segment(img, tx, ty, p_top, p_left, color)
		5, 10:
			# ambiguous case: 중앙값으로 판단
			var center := (nw + ne + sw + se) * 0.25
			if case_idx == 5:
				if center >= iso:
					_draw_segment(img, tx, ty, p_top, p_left, color)
					_draw_segment(img, tx, ty, p_right, p_bottom, color)
				else:
					_draw_segment(img, tx, ty, p_top, p_right, color)
					_draw_segment(img, tx, ty, p_left, p_bottom, color)
			else:  # case 10
				if center >= iso:
					_draw_segment(img, tx, ty, p_top, p_right, color)
					_draw_segment(img, tx, ty, p_left, p_bottom, color)
				else:
					_draw_segment(img, tx, ty, p_top, p_left, color)
					_draw_segment(img, tx, ty, p_right, p_bottom, color)

## edge 상의 선형 보간 파라미터 계산
func _edge_t(v0: float, v1: float, iso: float) -> float:
	var denom := (v1 - v0)
	if abs(denom) < 0.000001:
		return 0.5
	return clamp((iso - v0) / denom, 0.0, 1.0)

## 타일 내 선분 그리기
func _draw_segment(img: Image, tx: int, ty: int, a: Vector2, b: Vector2, color: Color) -> void:
	var x0 := tx * tile_pixel_size + int(round(a.x * float(tile_pixel_size - 1)))
	var y0 := ty * tile_pixel_size + int(round(a.y * float(tile_pixel_size - 1)))
	var x1 := tx * tile_pixel_size + int(round(b.x * float(tile_pixel_size - 1)))
	var y1 := ty * tile_pixel_size + int(round(b.y * float(tile_pixel_size - 1)))
	_draw_line(img, x0, y0, x1, y1, color)

## Bresenham 라인 알고리즘
func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx: int = abs(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	
	while true:
		if x0 >= 0 and x0 < img.get_width() and y0 >= 0 and y0 < img.get_height():
			img.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## =========================
## Style Contours (Pattern-based)
## =========================

## Style 등고선 - 타일 패턴 경계 기반
func _draw_style_contours(img: Image, terrain: DualGridTerrain) -> void:
	if style_contour_step <= 0.0:
		return
	
	# 스칼라 범위 산출
	var min_v := 1.0
	var max_v := 0.0
	for v in terrain.corner_values:
		if v < min_v: min_v = v
		if v > max_v: max_v = v
	
	# threshold를 중심으로 등고선 레벨 생성
	var center := terrain.threshold
	var levels: Array[float] = []
	
	levels.append(center)
	
	var i := 1
	while true:
		var upper := center + style_contour_step * i
		var lower := center - style_contour_step * i
		
		var added := false
		if upper <= max_v:
			levels.append(upper)
			added = true
		if lower >= min_v:
			levels.append(lower)
			added = true
		
		if not added:
			break
		i += 1
	
	# 각 레벨마다 패턴 경계 그리기
	for level in levels:
		if level >= min_v and level <= max_v:
			_draw_pattern_boundaries_for_level(img, terrain, level)

## 특정 레벨의 패턴 경계 그리기
func _draw_pattern_boundaries_for_level(img: Image, terrain: DualGridTerrain, iso_level: float) -> void:
	var w := terrain.grid_size.x
	var h := terrain.grid_size.y
	
	for ty in range(h):
		for tx in range(w):
			# 4개 코너 값을 iso_level 기준으로 boolean 변환
			var nw := terrain.get_corner(tx, ty) >= iso_level
			var ne := terrain.get_corner(tx + 1, ty) >= iso_level
			var sw := terrain.get_corner(tx, ty + 1) >= iso_level
			var se := terrain.get_corner(tx + 1, ty + 1) >= iso_level
			
			# Marching Squares 평가
			var tile_result := MarchingSquares.evaluate(nw, ne, sw, se)
			var tile_type: MarchingSquares.TileType = tile_result.type
			var rotation: int = tile_result.rotation
			
			# EMPTY나 FULL은 경계가 없으므로 스킵
			if tile_type == MarchingSquares.TileType.EMPTY or tile_type == MarchingSquares.TileType.FULL:
				continue
			
			# 해당 타일의 패턴 가져오기
			if not tile_patterns.has(tile_type):
				continue
			var type_patterns: Dictionary = tile_patterns[tile_type]
			if not type_patterns.has(rotation):
				continue
			var pattern: Array[bool] = type_patterns[rotation]
			
			# 패턴의 경계 픽셀 그리기
			_draw_pattern_boundary(img, tx, ty, pattern)

## 패턴의 경계 픽셀만 등고선 색상으로 그리기
func _draw_pattern_boundary(img: Image, tx: int, ty: int, pattern: Array[bool]) -> void:
	var start_x := tx * tile_pixel_size
	var start_y := ty * tile_pixel_size
	
	for py in range(tile_pixel_size):
		for px in range(tile_pixel_size):
			var idx := py * tile_pixel_size + px
			var is_land: bool = pattern[idx]
			
			# land 픽셀만 검사
			if not is_land:
				continue
			
			# 상하좌우에 water가 있는지 확인 (경계 판정)
			var is_boundary := false
			
			# 상 (타일 내부만)
			if py > 0:
				var up_idx := (py - 1) * tile_pixel_size + px
				if not pattern[up_idx]:
					is_boundary = true
			
			# 하 (타일 내부만)
			if py < tile_pixel_size - 1:
				var down_idx := (py + 1) * tile_pixel_size + px
				if not pattern[down_idx]:
					is_boundary = true
			
			# 좌 (타일 내부만)
			if px > 0:
				var left_idx := py * tile_pixel_size + (px - 1)
				if not pattern[left_idx]:
					is_boundary = true
			
			# 우 (타일 내부만)
			if px < tile_pixel_size - 1:
				var right_idx := py * tile_pixel_size + (px + 1)
				if not pattern[right_idx]:
					is_boundary = true
			
			# 경계 픽셀이면 등고선 색상으로
			if is_boundary:
				var x := start_x + px
				var y := start_y + py
				if x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, style_contour_color)
