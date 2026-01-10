class_name DualGridDecorations
extends Node2D

## 장식물 설정
@export var tree_chance: float = 0.15
@export var bush_chance: float = 0.3
@export var rock_chance: float = 0.1
@export var grass_density: float = 0.4

## 색상 팔레트 (기존 유지)
var tree_color := Color(0.08, 0.35, 0.08)
var tree_shadow_color := Color(0.05, 0.25, 0.05)
var bush_color := Color(0.15, 0.45, 0.15)
var rock_color := Color(0.35, 0.35, 0.35)
var grass_color := Color(0.25, 0.55, 0.25)

# 각 장식물 타입별 MultiMeshInstance2D
var mm_tree_shadow: MultiMeshInstance2D
var mm_tree: MultiMeshInstance2D
var mm_bush: MultiMeshInstance2D
var mm_rock: MultiMeshInstance2D
var mm_grass: MultiMeshInstance2D

# 텍스처 (없으면 사각형으로 나옴, 원형 텍스처 할당 권장)
var default_mesh: Mesh

func _ready() -> void:
	# 기본 메쉬 생성 (1x1 크기의 Quad)
	default_mesh = QuadMesh.new()
	default_mesh.size = Vector2(1, 1) # 스케일로 크기 조절 예정
	
	# 레이어 순서대로 노드 생성 (그림자 -> 풀 -> 바위 -> 덤불 -> 나무)
	# Y-Sort가 안되므로 레이어 순서가 렌더링 순서가 됨
	mm_tree_shadow = _create_layer("TreeShadow", default_mesh)
	mm_grass = _create_layer("Grass", default_mesh)
	mm_rock = _create_layer("Rock", default_mesh)
	mm_bush = _create_layer("Bush", default_mesh)
	mm_tree = _create_layer("Tree", default_mesh)

## MultiMeshInstance2D 노드 생성 및 설정 헬퍼
func _create_layer(name: String, mesh: Mesh) -> MultiMeshInstance2D:
	var mmi = MultiMeshInstance2D.new()
	mmi.name = name
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	mmi.multimesh.use_colors = true # 개별 색상 사용
	mmi.multimesh.mesh = mesh
	add_child(mmi)
	return mmi

## 외부에서 호출: 지형 데이터를 받아 장식물 배치
func generate(terrain: DualGridTerrain, tile_pixel_size: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	
	# 데이터를 모을 배열들 (Transform2D, Color)
	# 직접 MultiMesh에 넣는 것보다 배열에 모았다가 한 번에 넣는 게 빠름
	var data = {
		"tree": {"xforms": [], "colors": []},
		"shadow": {"xforms": [], "colors": []},
		"bush": {"xforms": [], "colors": []},
		"rock": {"xforms": [], "colors": []},
		"grass": {"xforms": [], "colors": []}
	}
	
	for ty in range(terrain.grid_size.y):
		for tx in range(terrain.grid_size.x):
			rng.seed = _tile_seed(seed_value, tx, ty)
			var tile_result := terrain.evaluate_tile(tx, ty)
			
			_process_tile(tile_result.type, tx, ty, tile_pixel_size, rng, data)

	# 수집된 데이터를 실제 MultiMesh에 적용
	_apply_to_multimesh(mm_tree, data.tree)
	_apply_to_multimesh(mm_tree_shadow, data.shadow)
	_apply_to_multimesh(mm_bush, data.bush)
	_apply_to_multimesh(mm_rock, data.rock)
	_apply_to_multimesh(mm_grass, data.grass)

## 타일 시드 생성 (기존 로직 유지)
func _tile_seed(base_seed: int, x: int, y: int) -> int:
	return base_seed + x * 73856093 + y * 19349663

## 타일별 장식물 로직 (기존 확률 로직 유지)
func _process_tile(type: int, tx: int, ty: int, size: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	match type:
		MarchingSquares.TileType.FULL:
			if rng.randf() < tree_chance:
				_add_tree(tx, ty, size, rng, data)
			
			for i in rng.randi_range(0, 2):
				if rng.randf() < bush_chance:
					_add_simple(tx, ty, size, rng, bush_color, data.bush, 0.15, 0.25)
			
			if rng.randf() < rock_chance:
				_add_simple(tx, ty, size, rng, rock_color, data.rock, 0.12, 0.2)
				
			for i in rng.randi_range(0, 3):
				if rng.randf() < grass_density:
					_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1) # 풀은 작게

		MarchingSquares.TileType.INVERSE_CORNER:
			if rng.randf() < tree_chance * 0.5:
				_add_tree(tx, ty, size, rng, data)
			if rng.randf() < bush_chance:
				_add_simple(tx, ty, size, rng, bush_color, data.bush, 0.15, 0.25)
			for i in rng.randi_range(0, 2):
				if rng.randf() < grass_density:
					_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1)

		MarchingSquares.TileType.EDGE:
			if rng.randf() < grass_density * 0.5:
				_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1)

## 나무 데이터 추가 (그림자 포함)
func _add_tree(tx: int, ty: int, size: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var offset_x = rng.randi_range(int(size * 0.3), int(size * 0.7))
	var offset_y = rng.randi_range(int(size * 0.3), int(size * 0.7))
	var pos = Vector2(tx * size + offset_x, ty * size + offset_y)
	
	# 반경을 스케일로 변환 (기존 로직: size * 0.35 ~ 0.45)
	# QuadMesh가 1x1이므로, 스케일이 곧 지름(2 * radius)이 됨
	var scale_val = size * rng.randf_range(0.35, 0.45) * 2.0 
	
	# 나무 본체
	var xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, pos)
	data.tree.xforms.append(xform)
	data.tree.colors.append(tree_color)
	
	# 그림자 (약간 아래 오른쪽으로 오프셋)
	var shadow_pos = pos + Vector2(size * 0.1, size * 0.1)
	var shadow_xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, shadow_pos)
	data.shadow.xforms.append(shadow_xform)
	data.shadow.colors.append(tree_shadow_color)

## 일반 장식물(풀, 바위, 덤불) 데이터 추가
func _add_simple(tx: int, ty: int, size: int, rng: RandomNumberGenerator, color: Color, list: Dictionary, min_r: float, max_r: float) -> void:
	var pos = Vector2(
		tx * size + rng.randi_range(0, size - 1),
		ty * size + rng.randi_range(0, size - 1)
	)
	var scale_val = size * rng.randf_range(min_r, max_r) * 2.0
	
	var xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, pos)
	list.xforms.append(xform)
	list.colors.append(color)

## 최종적으로 MultiMesh에 데이터 적용
func _apply_to_multimesh(mmi: MultiMeshInstance2D, list: Dictionary) -> void:
	var count = list.xforms.size()
	mmi.multimesh.instance_count = count # 인스턴스 개수 설정 (필수)
	
	for i in range(count):
		mmi.multimesh.set_instance_transform_2d(i, list.xforms[i])
		mmi.multimesh.set_instance_color(i, list.colors[i])
