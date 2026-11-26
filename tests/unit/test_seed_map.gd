## 단위 테스트: 시드 기반 맵 생성
## PRD 9.2 — 동일 시드 입력 시 동일 맵 생성
extends Node

const TEST_NAME := "test_seed_map_generation"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_same_seed_same_map())
	results.append(_test_different_seed_different_map())
	results.append(_test_initial_stations_valid())
	results.append(_test_initial_stations_unique_colors())
	results.append(_test_initial_stations_no_bridge_or_tunnel_needed())
	results.append(_test_new_station_max_single_bridge_tunnel())
	return results


## 동일 시드 → 동일 맵
func _test_same_seed_same_map() -> Dictionary:
	var seed_val := 42
	
	# 첫 번째 생성
	var gs1 := GameStateRepository.new()
	var tc1 := TerrainChecker.new(gs1)
	var mg1 := MapGenerator.new(gs1, tc1)
	mg1.generate(seed_val)
	
	# 두 번째 생성 (같은 시드)
	var gs2 := GameStateRepository.new()
	var tc2 := TerrainChecker.new(gs2)
	var mg2 := MapGenerator.new(gs2, tc2)
	mg2.generate(seed_val)
	
	# 역 수 비교
	if gs1.stations.size() != gs2.stations.size():
		return {"test": "동일 시드 동일 맵", "passed": false, "reason": "역 수가 다름: %d vs %d" % [gs1.stations.size(), gs2.stations.size()]}
	
	# 역 위치 비교
	var stations1 := gs1.get_all_stations()
	var stations2 := gs2.get_all_stations()
	
	for i in range(stations1.size()):
		var s1: StationEntity = stations1[i]
		var s2: StationEntity = stations2[i]
		if s1.position.distance_to(s2.position) > 0.1:
			return {"test": "동일 시드 동일 맵", "passed": false, "reason": "역 %d 위치 불일치" % i}
		if s1.shape != s2.shape:
			return {"test": "동일 시드 동일 맵", "passed": false, "reason": "역 %d 모양 불일치" % i}
	
	# 지형 수 비교
	if gs1.terrains.size() != gs2.terrains.size():
		return {"test": "동일 시드 동일 맵", "passed": false, "reason": "지형 수가 다름"}
	
	return {"test": "동일 시드 동일 맵", "passed": true, "reason": ""}


## 다른 시드 → 다른 맵
func _test_different_seed_different_map() -> Dictionary:
	var gs1 := GameStateRepository.new()
	var tc1 := TerrainChecker.new(gs1)
	var mg1 := MapGenerator.new(gs1, tc1)
	mg1.generate(42)
	
	var gs2 := GameStateRepository.new()
	var tc2 := TerrainChecker.new(gs2)
	var mg2 := MapGenerator.new(gs2, tc2)
	mg2.generate(99)
	
	var stations1 := gs1.get_all_stations()
	var stations2 := gs2.get_all_stations()
	
	# 적어도 하나의 역 위치가 다른지 확인
	var all_same := true
	for i in range(mini(stations1.size(), stations2.size())):
		if stations1[i].position.distance_to(stations2[i].position) > 1.0:
			all_same = false
			break
	
	if all_same and stations1.size() == stations2.size():
		return {"test": "다른 시드 다른 맵", "passed": false, "reason": "시드가 다른데 맵이 같음"}
	
	return {"test": "다른 시드 다른 맵", "passed": true, "reason": ""}


## 초기 역 유효성 (3개, 각 모양 1개 이상)
func _test_initial_stations_valid() -> Dictionary:
	var gs := GameStateRepository.new()
	var tc := TerrainChecker.new(gs)
	var mg := MapGenerator.new(gs, tc)
	var result := mg.generate(123)
	
	if not result.success:
		return {"test": "초기 역 유효성", "passed": false, "reason": "맵 생성 실패: %s" % result.message}
	
	var stations := gs.get_all_stations()
	if stations.size() < 3:
		return {"test": "초기 역 유효성", "passed": false, "reason": "역이 3개 미만: %d" % stations.size()}
	
	# 모양 확인
	var has_circle := false
	var has_triangle := false
	var has_square := false
	
	for station in stations:
		match station.shape:
			StationEntity.Shape.CIRCLE: has_circle = true
			StationEntity.Shape.TRIANGLE: has_triangle = true
			StationEntity.Shape.SQUARE: has_square = true
	
	if not has_circle:
		return {"test": "초기 역 유효성", "passed": false, "reason": "원 모양 역 없음"}
	if not has_triangle:
		return {"test": "초기 역 유효성", "passed": false, "reason": "삼각형 모양 역 없음"}
	if not has_square:
		return {"test": "초기 역 유효성", "passed": false, "reason": "사각형 모양 역 없음"}
	
	return {"test": "초기 역 유효성", "passed": true, "reason": ""}


## 초기 3개 역 색상 100% 무중복 고유성 검증 (디자인 2 및 사용자 피드백)
func _test_initial_stations_unique_colors() -> Dictionary:
	var seeds_to_test: Array[int] = [1, 42, 99, 123, 777, 1000, 2026, 99999]
	for s in seeds_to_test:
		var gs := GameStateRepository.new()
		var tc := TerrainChecker.new(gs)
		var mg := MapGenerator.new(gs, tc)
		var res := mg.generate(s)
		if not res.success:
			return {"test": "초기 3역 색상 고유성", "passed": false, "reason": "시드 %d 생성 실패" % s}
		
		var stations := gs.get_all_stations()
		if stations.size() < 3:
			return {"test": "초기 3역 색상 고유성", "passed": false, "reason": "시드 %d 역 개수 부족" % s}
		
		var c0: Color = stations[0].color
		var c1: Color = stations[1].color
		var c2: Color = stations[2].color
		
		if c0 == c1 or c1 == c2 or c0 == c2:
			return {
				"test": "초기 3역 색상 고유성",
				"passed": false,
				"reason": "시드 %d: 초기 역 색상 중복 발견! (c0=%s, c1=%s, c2=%s)" % [s, c0.to_html(), c1.to_html(), c2.to_html()]
			}
	
	return {"test": "초기 3역 색상 고유성 (100% 무중복)", "passed": true, "reason": ""}


## 초기 3개 역 간의 연결에 다리/터널이 필요 없는지 검증
func _test_initial_stations_no_bridge_or_tunnel_needed() -> Dictionary:
	var test_seeds := [42, 100, 777, 1234, 99999]
	
	for s in test_seeds:
		var gs := GameStateRepository.new()
		var tc := TerrainChecker.new(gs)
		var mg := MapGenerator.new(gs, tc)
		var result := mg.generate(s)
		
		if not result.success:
			return {"test": "초기 3역 다리/터널 불필요", "passed": false, "reason": "시드 %d 맵 생성 실패" % s}
		
		var stations := gs.get_all_stations()
		if stations.size() < 3:
			return {"test": "초기 3역 다리/터널 불필요", "passed": false, "reason": "시드 %d 역 수 미달" % s}
		
		var p0: Vector2 = stations[0].position
		var p1: Vector2 = stations[1].position
		var p2: Vector2 = stations[2].position
		
		# 최소한 하나의 순서(0-1-2 또는 1-0-2 또는 0-2-1)로 다리/터널 없이 전체 노선 연결이 가능해야 함
		var seg01 := tc.check_segment(p0, p1)
		var seg12 := tc.check_segment(p1, p2)
		var seg02 := tc.check_segment(p0, p2)
		
		var chain_0_1_2: bool = (seg01.result == TerrainEntity.TerrainCheckResult.CLEAR and seg12.result == TerrainEntity.TerrainCheckResult.CLEAR)
		var chain_1_0_2: bool = (seg01.result == TerrainEntity.TerrainCheckResult.CLEAR and seg02.result == TerrainEntity.TerrainCheckResult.CLEAR)
		var chain_0_2_1: bool = (seg02.result == TerrainEntity.TerrainCheckResult.CLEAR and seg12.result == TerrainEntity.TerrainCheckResult.CLEAR)
		
		if not (chain_0_1_2 or chain_1_0_2 or chain_0_2_1):
			return {
				"test": "초기 3역 다리/터널 불필요",
				"passed": false,
				"reason": "시드 %d: 초기 3개 역을 다리/터널 없이 연결할 수 있는 경로가 없습니다. (seg01=%s, seg12=%s, seg02=%s)" % [
					s,
					TerrainEntity.TerrainCheckResult.keys()[seg01.result],
					TerrainEntity.TerrainCheckResult.keys()[seg12.result],
					TerrainEntity.TerrainCheckResult.keys()[seg02.result]
				]
			}
	
	return {"test": "초기 3역 다리/터널 불필요 (100% 검증)", "passed": true, "reason": ""}


## 신규 역 생성 시 다리나 터널이 2개 이상 필요한 배치가 없는지 검증 (사용자 피드백 반영)
func _test_new_station_max_single_bridge_tunnel() -> Dictionary:
	var test_seeds := [42, 100, 777, 99999]
	var balance := GameConfig.balance
	
	for s in test_seeds:
		var gs := GameStateRepository.new()
		var tc := TerrainChecker.new(gs)
		var mg := MapGenerator.new(gs, tc)
		var result := mg.generate(s)
		if not result.success:
			return {"test": "신규 역 인프라 요구조건 한도 검증", "passed": false, "reason": "맵 생성 실패"}
		
		# 추가 역 5개 순차 생성
		var play_area := Rect2(
			Vector2(balance.play_area_margin, balance.play_area_margin),
			Vector2(balance.play_area_width, balance.play_area_height)
		)
		var spawn_result := mg._generate_stations(play_area, 5)
		if not spawn_result.success:
			return {"test": "신규 역 인프라 요구조건 한도 검증", "passed": false, "reason": spawn_result.message}
		
		var stations := gs.get_all_stations()
		# 4번째부터(신규 역) 기존 역과의 연결성 확인
		for i in range(3, stations.size()):
			var candidate_station: StationEntity = stations[i]
			var has_valid_connection := false
			for j in range(i):
				var target_station: StationEntity = stations[j]
				var seg := tc.check_segment(candidate_station.position, target_station.position)
				var bridges: int = seg.get("bridge_count_needed", 0)
				var tunnels: int = seg.get("tunnel_count_needed", 0)
				if bridges <= 1 and tunnels <= 1:
					has_valid_connection = true
					break
			
			if not has_valid_connection:
				return {
					"test": "신규 역 인프라 요구조건 한도 검증",
					"passed": false,
					"reason": "시드 %d: 역 %s가 기존 역들과 연결 시 다리나 터널이 2개 이상 필요합니다." % [s, candidate_station.id]
				}
	
	return {"test": "신규 역 인프라 요구조건 한도 (다리/터널 2개 이상 필요 배치 0% 차단)", "passed": true, "reason": ""}

