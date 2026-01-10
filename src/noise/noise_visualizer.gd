class_name NoiseVisualizer
extends RefCounted

# 값 재매핑
var curve: Curve
var input_range := Vector2(-1.0, 1.0)  # NoiseField 출력 범위
var output_range := Vector2(0.0, 1.0)  # 정규화 후 범위

# 구간별 색상 (threshold → color)
# 예: [0.2, 0.5, 0.8] → 4개 구간
var thresholds: Array[float] = []
var colors: Array[Color] = []

# 경계선
var border_thickness: float = 0.02  # threshold ± 이 값 범위에서 선 표시
var border_color: Color = Color.BLACK

func _init() -> void:
	# 기본 선형 커브
	if not curve:
		curve = Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(1.0, 1.0))
	
	# 기본 4단계 grayscale
	thresholds = [0.25, 0.5, 0.75]
	colors = [
		Color(0.2, 0.2, 0.2),
		Color(0.4, 0.4, 0.4),
		Color(0.6, 0.6, 0.6),
		Color(0.8, 0.8, 0.8),
	]

func normalize(raw_value: float) -> float:
	# input_range → [0, 1]
	var t := inverse_lerp(input_range.x, input_range.y, raw_value)
	return clamp(t, 0.0, 1.0)

func apply_curve(normalized_value: float) -> float:
	# Curve 적용
	var curved := curve.sample(clamp(normalized_value, 0.0, 1.0))
	# output_range로 스케일
	return lerp(output_range.x, output_range.y, curved)

func colorize(normalized_value: float) -> Color:
	var v: float = clamp(normalized_value, 0.0, 1.0)
	
	# 경계선 체크
	for threshold in thresholds:
		if abs(v - threshold) < border_thickness:
			return border_color
	
	# 구간 색상
	for i in range(thresholds.size()):
		if v < thresholds[i]:
			return colors[i]
	
	# 마지막 구간
	return colors[thresholds.size()]

# 편의 함수: raw → color (한 번에)
func process(raw_value: float) -> Color:
	var normalized := normalize(raw_value)
	var curved := apply_curve(normalized)
	return colorize(curved)

# 편의 함수: raw → float (색상 없이 값만)
func process_scalar(raw_value: float) -> float:
	var normalized := normalize(raw_value)
	return apply_curve(normalized)
