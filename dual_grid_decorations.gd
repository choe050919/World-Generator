class_name DualGridDecorations
extends Node2D

## 장식물 생성 확률 설정
@export var tree_chance: float = 0.15
@export var bush_chance: float = 0.3
@export var rock_chance: float = 0.1
@export var grass_density: float = 0.4

## 색상 팔레트
var tree_color := Color(0.08, 0.35, 0.08)
var tree_shadow_color := Color(0.05, 0.25, 0.05)
var bush_color := Color(0.15, 0.45, 0.15)
var rock_color := Color(0.35, 0.35, 0.35)
var grass_color := Color(0.25, 0.55, 0.25)

# 각 레이어별 MultiMeshInstance2D
var mm_tree_shadow: MultiMeshInstance2D
var mm_tree: MultiMeshInstance2D
var mm_bush: MultiMeshInstance2D
var mm_rock: MultiMeshInstance2D
var mm_grass: MultiMeshInstance2D

# 기본 메쉬 및 쉐이더 재질
var default_mesh: Mesh
var wind_material: ShaderMaterial

func _ready() -> void:
	# 지형(View)보다 앞에 그려지도록 순서 조정
	z_index = 10
	
	# 1. 쉐이더 로드 및 재질 생성
	var shader = load("res://wind_sway.gdshader")
	if shader:
		wind_material = ShaderMaterial.new()
		wind_material.shader = shader
		# [중요] 쉐이더 파라미터 안전값 설정 (워프 방지)
		wind_material.set_shader_parameter("wind_strength", 0.05)
		wind_material.set_shader_parameter("wind_speed", 2.0)
	
	# 2. 기본 메쉬 생성 (1x1 Quad)
	default_mesh = QuadMesh.new()
	default_mesh.size = Vector2(1, 1)
	
	# 3. 레이어 생성
	# 그림자 (바람 X -> material: null)
	mm_tree_shadow = _create_layer("TreeShadow", default_mesh, null)
	# 풀 (바람 O -> material: wind_material)
	mm_grass = _create_layer("Grass", default_mesh, wind_material)
	# 바위 (바람 X -> material: null)
	mm_rock = _create_layer("Rock", default_mesh, null)
	# 덤불 (바람 O)
	mm_bush = _create_layer("Bush", default_mesh, wind_material)
	# 나무 (바람 O)
	mm_tree = _create_layer("Tree", default_mesh, wind_material)

## 레이어 생성 헬퍼
func _create_layer(name: String, mesh: Mesh, material: Material) -> MultiMeshInstance2D:
	var mmi = MultiMeshInstance2D.new()
	mmi.name = name
	mmi.material = material  # 쉐이더 재질 적용
	
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	mmi.multimesh.use_colors = true       # 개별 색상 사용
	mmi.multimesh.use_custom_data = true  # [핵심] 개별 데이터(위상, 민감도) 사용
	mmi.multimesh.mesh = mesh
	
	add_child(mmi)
	return mmi

## 외부 호출: 지형 데이터로 장식물 배치
func generate(terrain: DualGridTerrain, tile_pixel_size: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	
	# 데이터 수집용 딕셔너리
	# customs: 쉐이더로 보낼 값 (Color r, g, b, a)
	# r: 랜덤 위상 (타이밍)
	# g: 민감도 (흔들림 강도 계수)
	var data = {
		"tree":   {"xforms": [], "colors": [], "customs": []},
		"shadow": {"xforms": [], "colors": [], "customs": []},
		"bush":   {"xforms": [], "colors": [], "customs": []},
		"rock":   {"xforms": [], "colors": [], "customs": []},
		"grass":  {"xforms": [], "colors": [], "customs": []}
	}
	
	for ty in range(terrain.grid_size.y):
		for tx in range(terrain.grid_size.x):
			rng.seed = _tile_seed(seed_value, tx, ty)
			var tile_result := terrain.evaluate_tile(tx, ty)
			_process_tile(tile_result.type, tx, ty, tile_pixel_size, rng, data)

	# 수집된 데이터 적용
	_apply_to_multimesh(mm_tree, data.tree)
	_apply_to_multimesh(mm_tree_shadow, data.shadow)
	_apply_to_multimesh(mm_bush, data.bush)
	_apply_to_multimesh(mm_rock, data.rock)
	_apply_to_multimesh(mm_grass, data.grass)

func _tile_seed(base_seed: int, x: int, y: int) -> int:
	return base_seed + x * 73856093 + y * 19349663

func _process_tile(type: int, tx: int, ty: int, size: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	match type:
		MarchingSquares.TileType.FULL:
			if rng.randf() < tree_chance:
				_add_tree(tx, ty, size, rng, data)
			
			for i in rng.randi_range(0, 2):
				if rng.randf() < bush_chance:
					# 덤불: 중간 민감도 (0.4 ~ 0.7)
					_add_simple(tx, ty, size, rng, bush_color, data.bush, 0.15, 0.25, 0.4, 0.7)
			
			if rng.randf() < rock_chance:
				# 바위: 민감도 0 (안 흔들림)
				_add_simple(tx, ty, size, rng, rock_color, data.rock, 0.12, 0.2, 0.0, 0.0)
				
			for i in rng.randi_range(0, 3):
				if rng.randf() < grass_density:
					# 풀: 높은 민감도 (0.8 ~ 1.2) - 가벼워서 잘 흔들림
					_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1, 0.8, 1.2)

		MarchingSquares.TileType.INVERSE_CORNER:
			if rng.randf() < tree_chance * 0.5:
				_add_tree(tx, ty, size, rng, data)
			if rng.randf() < bush_chance:
				_add_simple(tx, ty, size, rng, bush_color, data.bush, 0.15, 0.25, 0.4, 0.7)
			for i in rng.randi_range(0, 2):
				if rng.randf() < grass_density:
					_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1, 0.8, 1.2)

		MarchingSquares.TileType.EDGE:
			if rng.randf() < grass_density * 0.5:
				_add_simple(tx, ty, size, rng, grass_color, data.grass, 0.05, 0.1, 0.8, 1.2)

func _add_tree(tx: int, ty: int, size: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var offset_x = rng.randi_range(int(size * 0.3), int(size * 0.7))
	var offset_y = rng.randi_range(int(size * 0.3), int(size * 0.7))
	var pos = Vector2(tx * size + offset_x, ty * size + offset_y)
	
	# 나무 크기 (스케일)
	var scale_val = size * rng.randf_range(0.35, 0.45) * 2.0 
	
	# [핵심] Custom Data 생성
	var random_phase = rng.randf()
	# 나무 민감도: 0.2 ~ 0.4 (무거워서 조금만 흔들림)
	var sensitivity = rng.randf_range(0.2, 0.4) 
	var custom_data = Color(random_phase, sensitivity, 0, 0)
	
	# 나무 본체 추가
	var xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, pos)
	data.tree.xforms.append(xform)
	data.tree.colors.append(tree_color)
	data.tree.customs.append(custom_data) 
	
	# 그림자 추가 (민감도 0)
	var shadow_pos = pos + Vector2(size * 0.1, size * 0.1)
	var shadow_xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, shadow_pos)
	data.shadow.xforms.append(shadow_xform)
	data.shadow.colors.append(tree_shadow_color)
	data.shadow.customs.append(Color(0, 0, 0, 0))

func _add_simple(tx: int, ty: int, size: int, rng: RandomNumberGenerator, color: Color, list: Dictionary, min_r: float, max_r: float, sensitivity_min: float, sensitivity_max: float) -> void:
	var pos = Vector2(
		tx * size + rng.randi_range(0, size - 1),
		ty * size + rng.randi_range(0, size - 1)
	)
	var scale_val = size * rng.randf_range(min_r, max_r) * 2.0
	
	# [핵심] Custom Data 생성 (타입별 민감도 적용)
	var random_phase = rng.randf()
	var sensitivity = rng.randf_range(sensitivity_min, sensitivity_max)
	var custom_data = Color(random_phase, sensitivity, 0, 0)
	
	var xform = Transform2D(0.0, Vector2(scale_val, scale_val), 0.0, pos)
	list.xforms.append(xform)
	list.colors.append(color)
	list.customs.append(custom_data)

func _apply_to_multimesh(mmi: MultiMeshInstance2D, list: Dictionary) -> void:
	var count = list.xforms.size()
	mmi.multimesh.instance_count = count
	
	for i in range(count):
		mmi.multimesh.set_instance_transform_2d(i, list.xforms[i])
		mmi.multimesh.set_instance_color(i, list.colors[i])
		# 쉐이더로 데이터 전송 (r: 위상, g: 민감도)
		mmi.multimesh.set_instance_custom_data(i, list.customs[i])
