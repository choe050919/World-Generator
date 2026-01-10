shader_type canvas_item;

// 강도와 속도는 에디터나 코드에서 조절
uniform float wind_strength = 0.05;
uniform float wind_speed = 2.0;

// 바람 방향 (정규화는 코드 내부에서 수행)
const vec2 wind_dir = vec2(1.0, 0.5);

void vertex() {
	// 1. 랜덤 위상 (타이밍 다르게)
	float phase = INSTANCE_CUSTOM.r * 6.2831853;
	float time = TIME * wind_speed + phase;

	// 2. 중심 거리 마스크 개선 (AI 제안 적용)
	// QuadMesh의 최대 거리는 약 0.7071 (대각선)
	float dist = length(VERTEX);
	// 거리를 0~1로 정규화하고 제곱하여 '가장자리만' 움직이게 함 -> 뿌리 고정 효과 강화
	float t = clamp(dist / 0.70710678, 0.0, 1.0);
	t = pow(t, 2.0);

	// 3. 바람 방향 정규화 (일정한 강도 보장)
	vec2 dir = normalize(wind_dir);

	// 4. 인스턴스별 민감도 적용 (작은 풀은 많이, 큰 나무는 적게 등)
	// INSTANCE_CUSTOM.g 값을 이용해 0.6배 ~ 1.4배로 강도 다양화
	float responsiveness = mix(0.6, 1.4, INSTANCE_CUSTOM.g);

	// 5. 최종 움직임 적용
	VERTEX += dir * cos(time) * wind_strength * t * responsiveness;
}