class_name DualGridTerrain
extends RefCounted

## 듀얼 그리드 기반 지형 생성
## - 그리드의 코너(꼭짓점)에 land/water 속성 할당
## - 각 타일은 4개 코너의 조합으로 결정됨

var grid_size: Vector2i  # 타일 개수 (예: 32x32)
var corner_values: Array[float] = []  # (grid_size + 1) 크기의 1D 배열
var threshold: float = 0.5  # land/water 구분 임계값

func _init(size: Vector2i = Vector2i(32, 32)) -> void:
	grid_size = size
	_allocate_corners()

func _allocate_corners() -> void:
	# 코너는 타일보다 1개씩 더 많음 (예: 32x32 타일 = 33x33 코너)
	var corner_count := (grid_size.x + 1) * (grid_size.y + 1)
	corner_values.clear()
	corner_values.resize(corner_count)
	corner_values.fill(0.0)

## 코너 인덱스 계산
func _corner_index(x: int, y: int) -> int:
	return y * (grid_size.x + 1) + x

## 코너 값 설정
func set_corner(x: int, y: int, value: float) -> void:
	var idx := _corner_index(x, y)
	if idx >= 0 and idx < corner_values.size():
		corner_values[idx] = value

## 코너 값 가져오기
func get_corner(x: int, y: int) -> float:
	var idx := _corner_index(x, y)
	if idx >= 0 and idx < corner_values.size():
		return corner_values[idx]
	return 0.0

## 코너 값 → land/water 판정
func is_land(x: int, y: int) -> bool:
	return get_corner(x, y) >= threshold

## 특정 타일의 4개 코너 상태 가져오기
## 타일 (tx, ty)의 코너는:
## - NW: (tx, ty)
## - NE: (tx+1, ty)
## - SW: (tx, ty+1)
## - SE: (tx+1, ty+1)
func get_tile_corners(tx: int, ty: int) -> Dictionary:
	return {
		"nw": is_land(tx, ty),
		"ne": is_land(tx + 1, ty),
		"sw": is_land(tx, ty + 1),
		"se": is_land(tx + 1, ty + 1)
	}

## 타일의 Marching Squares 결과 계산
func evaluate_tile(tx: int, ty: int) -> Dictionary:
	var corners := get_tile_corners(tx, ty)
	return MarchingSquares.evaluate(
		corners.nw,
		corners.ne,
		corners.sw,
		corners.se
	)

## 노이즈 필드로 코너 값 채우기
func fill_from_noise(noise_field: NoiseField) -> void:
	for y in range(grid_size.y + 1):
		for x in range(grid_size.x + 1):
			var pos := Vector2(x, y)
			var value := noise_field.sample2(pos)
			# 노이즈 값을 [0, 1] 범위로 정규화
			var normalized := (value + 1.0) / 2.0
			set_corner(x, y, normalized)
