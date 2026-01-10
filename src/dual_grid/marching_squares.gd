class_name MarchingSquares
extends RefCounted

## Marching Squares 알고리즘
## 4개 코너(NW, NE, SW, SE)의 상태(land/water)를 받아서
## 타일 타입을 반환합니다.
##
## 16가지 조합 → 회전/대칭 고려 → 6가지 기본 케이스

enum TileType {
	EMPTY,        # 0000 - 모두 water
	FULL,         # 1111 - 모두 land
	CORNER,       # 1개만 land (예: 1000, 0100, 0010, 0001)
	EDGE,         # 2개 인접 (예: 1100, 0110, 0011, 1001)
	DIAGONAL,     # 2개 대각선 (예: 1010, 0101)
	INVERSE_CORNER # 3개 land = 1개만 water (예: 0111, 1011, 1101, 1110)
}

## 코너 인덱스 (비트 위치)
## NW(북서) = bit 3 (0b1000)
## NE(북동) = bit 2 (0b0100)
## SW(남서) = bit 1 (0b0010)
## SE(남동) = bit 0 (0b0001)

## 16가지 케이스 → 기본 타입 + 회전 매핑
const TILE_TYPE_MAP := {
	0b0000: TileType.EMPTY,           # 0 - 모두 water
	0b1111: TileType.FULL,            # 15 - 모두 land
	
	# CORNER (1개만 land)
	0b1000: TileType.CORNER,          # 8  - NW
	0b0100: TileType.CORNER,          # 4  - NE
	0b0010: TileType.CORNER,          # 2  - SW
	0b0001: TileType.CORNER,          # 1  - SE
	
	# EDGE (2개 인접 - 한 변을 공유)
	0b1100: TileType.EDGE,            # 12 - NW+NE (위)
	0b0011: TileType.EDGE,            # 3  - SW+SE (아래)
	0b1010: TileType.EDGE,            # 10 - NW+SW (왼쪽)
	0b0101: TileType.EDGE,            # 5  - NE+SE (오른쪽)
	
	# DIAGONAL (2개 대각선 - 변을 공유하지 않음)
	0b1001: TileType.DIAGONAL,        # 9  - NW+SE
	0b0110: TileType.DIAGONAL,        # 6  - NE+SW
	
	# INVERSE_CORNER (3개 land = 1개만 water)
	0b0111: TileType.INVERSE_CORNER,  # 7  - water at NW
	0b1011: TileType.INVERSE_CORNER,  # 11 - water at NE
	0b1101: TileType.INVERSE_CORNER,  # 13 - water at SW
	0b1110: TileType.INVERSE_CORNER,  # 14 - water at SE
}

## 회전 정보 (0, 90, 180, 270도)
## 기준: NW 코너를 0도로 보고, 시계방향 회전 필요 각도
const ROTATION_MAP := {
	0b0000: 0,    # EMPTY - 회전 무관
	0b1111: 0,    # FULL - 회전 무관
	
	# CORNER - NW가 기준(0도)
	0b1000: 0,    # NW → 그대로
	0b0100: 90,   # NE → 90도 시계방향 회전하면 NW
	0b0001: 180,  # SE → 180도 회전하면 NW
	0b0010: 270,  # SW → 270도(= -90도) 회전하면 NW
	
	# EDGE - N(위쪽)이 기준(0도)
	0b1100: 0,    # NW+NE (위) → 그대로
	0b0101: 90,   # NE+SE (오른쪽) → 90도 회전하면 위
	0b0011: 180,  # SW+SE (아래) → 180도 회전하면 위
	0b1010: 270,  # NW+SW (왼쪽) → 270도 회전하면 위
	
	# DIAGONAL
	0b1001: 0,    # NW+SE
	0b0110: 90,   # NE+SW
	
	# INVERSE_CORNER - water at NW가 기준(0도)
	0b0111: 0,    # water at NW → 그대로
	0b1011: 90,   # water at NE → 90도 회전하면 water at NW
	0b1110: 180,  # water at SE → 180도 회전하면 water at NW
	0b1101: 270,  # water at SW → 270도 회전하면 water at NW
}

## 4개 bool 값을 받아서 비트마스크로 변환
static func corners_to_bitmask(nw: bool, ne: bool, sw: bool, se: bool) -> int:
	var mask := 0
	if nw: mask |= 0b1000
	if ne: mask |= 0b0100
	if sw: mask |= 0b0010
	if se: mask |= 0b0001
	return mask

## 비트마스크 → 타일 타입
static func get_tile_type(bitmask: int) -> TileType:
	return TILE_TYPE_MAP.get(bitmask, TileType.EMPTY)

## 비트마스크 → 회전 각도
static func get_rotation(bitmask: int) -> int:
	return ROTATION_MAP.get(bitmask, 0)

## 편의 함수: 코너 4개 → (타일 타입, 회전)
static func evaluate(nw: bool, ne: bool, sw: bool, se: bool) -> Dictionary:
	var mask := corners_to_bitmask(nw, ne, sw, se)
	return {
		"type": get_tile_type(mask),
		"rotation": get_rotation(mask),
		"bitmask": mask
	}
