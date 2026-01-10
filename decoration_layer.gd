class_name DecorationLayer
extends RefCounted

## 지형 위에 장식물을 추가하는 독립적인 레이어
## 기존 이미지를 받아서 장식물을 그린 후 반환

enum DecorType {
	TREE,      # 나무 (큰 원 + 그림자)
	BUSH,      # 덤불 (작은 원)
	ROCK,      # 바위 (회색 원)
	GRASS,     # 풀 (점)
}

## 장식물 배치 확률
var tree_chance: float = 0.15
var bush_chance: float = 0.3
var rock_chance: float = 0.1
var grass_density: float = 0.4

## 색상 팔레트
var tree_color := Color(0.08, 0.35, 0.08)     # 진한 초록
var tree_shadow := Color(0.05, 0.25, 0.05)    # 나무 그림자
var bush_color := Color(0.15, 0.45, 0.15)     # 중간 초록
var rock_color := Color(0.35, 0.35, 0.35)     # 회색
var grass_color := Color(0.25, 0.55, 0.25)    # 밝은 초록

## 메인 함수: 이미지에 장식물 추가
func apply(base_image: Image, terrain: DualGridTerrain, seed_value: int) -> Image:
	# 이미지 복사 (원본 보존)
	var img := Image.create(base_image.get_width(), base_image.get_height(), false, Image.FORMAT_RGBA8)
	img.copy_from(base_image)
	
	var rng := RandomNumberGenerator.new()
	var tile_pixel_size := base_image.get_width() / terrain.grid_size.x
	
	# 각 타일마다 장식물 생성
	for ty in range(terrain.grid_size.y):
		for tx in range(terrain.grid_size.x):
			# 타일별 시드 (위치 기반으로 결정적)
			rng.seed = _tile_seed(seed_value, tx, ty)
			
			var tile_result := terrain.evaluate_tile(tx, ty)
			_add_decorations_for_tile(img, tile_result.type, tx, ty, tile_pixel_size, rng)
	
	return img

## 타일별 고유 시드 생성
func _tile_seed(base_seed: int, x: int, y: int) -> int:
	return base_seed + x * 73856093 + y * 19349663

## 타일 타입에 따라 장식물 추가
func _add_decorations_for_tile(img: Image, tile_type: MarchingSquares.TileType, tx: int, ty: int, tile_size: int, rng: RandomNumberGenerator) -> void:
	match tile_type:
		MarchingSquares.TileType.FULL:
			# 완전히 땅 - 모든 장식물 가능
			if rng.randf() < tree_chance:
				_draw_tree(img, tx, ty, tile_size, rng)
			
			var bush_count := rng.randi_range(0, 2)
			for i in bush_count:
				if rng.randf() < bush_chance:
					_draw_bush(img, tx, ty, tile_size, rng)
			
			if rng.randf() < rock_chance:
				_draw_rock(img, tx, ty, tile_size, rng)
			
			var grass_count := rng.randi_range(0, 3)
			for i in grass_count:
				if rng.randf() < grass_density:
					_draw_grass(img, tx, ty, tile_size, rng)
		
		MarchingSquares.TileType.INVERSE_CORNER:
			# 대부분 땅 - 적당히
			if rng.randf() < tree_chance * 0.5:
				_draw_tree(img, tx, ty, tile_size, rng)
			
			if rng.randf() < bush_chance:
				_draw_bush(img, tx, ty, tile_size, rng)
			
			var grass_count := rng.randi_range(0, 2)
			for i in grass_count:
				if rng.randf() < grass_density:
					_draw_grass(img, tx, ty, tile_size, rng)
		
		MarchingSquares.TileType.EDGE:
			# 절반 땅 - 풀만
			if rng.randf() < grass_density * 0.5:
				_draw_grass(img, tx, ty, tile_size, rng)

## 나무 그리기 (큰 원 + 그림자)
func _draw_tree(img: Image, tx: int, ty: int, tile_size: int, rng: RandomNumberGenerator) -> void:
	var center_x := tx * tile_size + rng.randi_range(int(tile_size * 0.3), int(tile_size * 0.7))
	var center_y := ty * tile_size + rng.randi_range(int(tile_size * 0.3), int(tile_size * 0.7))
	var radius := int(tile_size * rng.randf_range(0.35, 0.45))
	
	# 그림자 (약간 오프셋)
	_draw_circle(img, center_x + 1, center_y + 1, radius, tree_shadow)
	
	# 나무
	_draw_circle(img, center_x, center_y, radius, tree_color)

## 덤불 그리기 (작은 원)
func _draw_bush(img: Image, tx: int, ty: int, tile_size: int, rng: RandomNumberGenerator) -> void:
	var center_x := tx * tile_size + rng.randi_range(0, tile_size - 1)
	var center_y := ty * tile_size + rng.randi_range(0, tile_size - 1)
	var radius := int(tile_size * rng.randf_range(0.15, 0.25))
	
	_draw_circle(img, center_x, center_y, radius, bush_color)

## 바위 그리기 (회색 원)
func _draw_rock(img: Image, tx: int, ty: int, tile_size: int, rng: RandomNumberGenerator) -> void:
	var center_x := tx * tile_size + rng.randi_range(0, tile_size - 1)
	var center_y := ty * tile_size + rng.randi_range(0, tile_size - 1)
	var radius := int(tile_size * rng.randf_range(0.12, 0.2))
	
	_draw_circle(img, center_x, center_y, radius, rock_color)

## 풀 그리기 (작은 점)
func _draw_grass(img: Image, tx: int, ty: int, tile_size: int, rng: RandomNumberGenerator) -> void:
	var center_x := tx * tile_size + rng.randi_range(0, tile_size - 1)
	var center_y := ty * tile_size + rng.randi_range(0, tile_size - 1)
	var radius := 1
	
	_draw_circle(img, center_x, center_y, radius, grass_color)

## 원 그리기 헬퍼 (midpoint circle algorithm)
func _draw_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var width := img.get_width()
	var height := img.get_height()
	
	# 채워진 원 그리기
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < width and y >= 0 and y < height:
					img.set_pixel(x, y, color)
