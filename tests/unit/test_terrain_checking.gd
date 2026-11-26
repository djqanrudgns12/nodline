## 단위 테스트: 지형 판정
## PRD 9.2 — 강 통과 → 다리 필요 / 산 통과 → 터널 필요
extends Node

const TEST_NAME := "test_terrain_checking"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_clear_path())
	results.append(_test_river_crossing_needs_bridge())
	results.append(_test_mountain_crossing_needs_tunnel())
	results.append(_test_point_on_terrain())
	return results


## 지형이 없는 경로: CLEAR
func _test_clear_path() -> Dictionary:
	var game_state := GameStateRepository.new()
	var checker := TerrainChecker.new(game_state)
	
	var result := checker.check_segment(Vector2(0, 0), Vector2(100, 0))
	if result.result != TerrainEntity.TerrainCheckResult.CLEAR:
		return {"test": "빈 경로 CLEAR", "passed": false, "reason": "결과가 CLEAR가 아님"}
	
	return {"test": "빈 경로 CLEAR", "passed": true, "reason": ""}


## 강 통과 시 다리 필요
func _test_river_crossing_needs_bridge() -> Dictionary:
	var game_state := GameStateRepository.new()
	
	# 가로 강 생성 (y=50 부근)
	var river_polygon := PackedVector2Array([
		Vector2(0, 40), Vector2(200, 40),
		Vector2(200, 60), Vector2(0, 60)
	])
	var river := TerrainEntity.new("terrain_0000", TerrainEntity.TerrainType.RIVER, river_polygon)
	game_state.add_terrain(river)
	
	var checker := TerrainChecker.new(game_state)
	
	# 세로 선분이 강을 관통
	var result := checker.check_segment(Vector2(100, 0), Vector2(100, 100))
	
	if not result.needs_bridge:
		return {"test": "강 통과 다리 필요", "passed": false, "reason": "다리가 필요하지 않다고 판정됨"}
	if result.result != TerrainEntity.TerrainCheckResult.RIVER:
		return {"test": "강 통과 다리 필요", "passed": false, "reason": "결과가 RIVER가 아님"}
	
	return {"test": "강 통과 다리 필요", "passed": true, "reason": ""}


## 산 통과 시 터널 필요
func _test_mountain_crossing_needs_tunnel() -> Dictionary:
	var game_state := GameStateRepository.new()
	
	# 원형 산 생성
	var mountain_polygon := PackedVector2Array()
	for i in range(8):
		var angle := (float(i) / 8.0) * TAU
		mountain_polygon.append(Vector2(100 + cos(angle) * 50, 100 + sin(angle) * 50))
	var mountain := TerrainEntity.new("terrain_0000", TerrainEntity.TerrainType.MOUNTAIN, mountain_polygon)
	game_state.add_terrain(mountain)
	
	var checker := TerrainChecker.new(game_state)
	
	# 산을 관통하는 선분
	var result := checker.check_segment(Vector2(0, 100), Vector2(200, 100))
	
	if not result.needs_tunnel:
		return {"test": "산 통과 터널 필요", "passed": false, "reason": "터널이 필요하지 않다고 판정됨"}
	if result.result != TerrainEntity.TerrainCheckResult.MOUNTAIN:
		return {"test": "산 통과 터널 필요", "passed": false, "reason": "결과가 MOUNTAIN이 아님"}
	
	return {"test": "산 통과 터널 필요", "passed": true, "reason": ""}


## 지형 위 점 감지
func _test_point_on_terrain() -> Dictionary:
	var game_state := GameStateRepository.new()
	
	var river_polygon := PackedVector2Array([
		Vector2(0, 40), Vector2(200, 40),
		Vector2(200, 60), Vector2(0, 60)
	])
	var river := TerrainEntity.new("terrain_0000", TerrainEntity.TerrainType.RIVER, river_polygon)
	game_state.add_terrain(river)
	
	var checker := TerrainChecker.new(game_state)
	
	# 강 위의 점
	if not checker.is_point_on_terrain(Vector2(100, 50)):
		return {"test": "지형 위 점 감지", "passed": false, "reason": "강 위의 점을 감지하지 못함"}
	
	# 강 밖의 점
	if checker.is_point_on_terrain(Vector2(100, 0)):
		return {"test": "지형 위 점 감지", "passed": false, "reason": "강 밖의 점을 지형으로 판정"}
	
	return {"test": "지형 위 점 감지", "passed": true, "reason": ""}
