## 통합 테스트: 노선 생성/수정에 따른 네트워크 그래프 및 경로 탐색 반영
## PRD 9.2 — 노선 생성 및 수정 → 네트워크 그래프 즉시 갱신 및 경로 탐색 반영
extends Node

const TEST_NAME := "test_network_and_pathfinding"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_graph_rebuild_on_line_creation())
	results.append(_test_transfer_pathfinding())
	results.append(_test_line_pause_updates_graph())
	return results


## 노선 생성 후 그래프 갱신 검증
func _test_graph_rebuild_on_line_creation() -> Dictionary:
	var gs := GameStateRepository.new()
	var ng := NetworkGraph.new(gs)
	
	var sA := StationEntity.new("s_A", Vector2(0, 0), StationEntity.Shape.CIRCLE, Color.BLUE)
	var sB := StationEntity.new("s_B", Vector2(200, 0), StationEntity.Shape.TRIANGLE, Color.CYAN)
	var sC := StationEntity.new("s_C", Vector2(400, 0), StationEntity.Shape.SQUARE, Color.PURPLE)
	gs.add_station(sA)
	gs.add_station(sB)
	gs.add_station(sC)
	
	# 노선 없이 검사
	ng.rebuild()
	if ng.has_connection("s_A", "s_B"):
		return {"test": "노선 생성 전 미연결", "passed": false, "reason": "노선 없는데 연결로 판정됨"}
	
	# 노선 1: A - B 연결
	var line1 := LineEntity.new("line_1", "1호선", Color.RED)
	line1.station_ids = ["s_A", "s_B"]
	gs.add_line(line1)
	ng.rebuild()
	
	if not ng.has_connection("s_A", "s_B"):
		return {"test": "노선 생성 후 연결 반영", "passed": false, "reason": "A-B 연결이 반영되지 않음"}
	
	if ng.has_connection("s_A", "s_C"):
		return {"test": "노선 미연결 구간 검증", "passed": false, "reason": "A-C가 연결되었다고 잘못 판정됨"}
	
	return {"test": "노선 생성 후 연결 반영", "passed": true, "reason": ""}


## 환승 경로 탐색 검증
func _test_transfer_pathfinding() -> Dictionary:
	var gs := GameStateRepository.new()
	var ng := NetworkGraph.new(gs)
	
	var sA := StationEntity.new("s_A", Vector2(0, 0), StationEntity.Shape.CIRCLE, Color.BLUE)
	var sB := StationEntity.new("s_B", Vector2(200, 0), StationEntity.Shape.TRIANGLE, Color.CYAN)
	var sC := StationEntity.new("s_C", Vector2(400, 0), StationEntity.Shape.SQUARE, Color.PURPLE)
	gs.add_station(sA)
	gs.add_station(sB)
	gs.add_station(sC)
	
	# 노선 1: A - B
	var line1 := LineEntity.new("line_1", "1호선", Color.RED)
	line1.station_ids = ["s_A", "s_B"]
	gs.add_line(line1)
	
	# 노선 2: B - C
	var line2 := LineEntity.new("line_2", "2호선", Color.GREEN)
	line2.station_ids = ["s_B", "s_C"]
	gs.add_line(line2)
	
	ng.rebuild()
	
	var path_info := ng.find_shortest_path("s_A", "s_C")
	if path_info.path.size() != 3 or path_info.path[0] != "s_A" or path_info.path[2] != "s_C":
		return {"test": "환승 경로 탐색", "passed": false, "reason": "A-B-C 경로 복원 실패: %s" % str(path_info.path)}
	
	if path_info.transfers != 1:
		return {"test": "환승 경로 탐색", "passed": false, "reason": "환승 횟수가 1이 아님: %d" % path_info.transfers}
	
	return {"test": "환승 경로 탐색", "passed": true, "reason": ""}


## 노선 일시정지 시 그래프 제외 검증
func _test_line_pause_updates_graph() -> Dictionary:
	var gs := GameStateRepository.new()
	var ng := NetworkGraph.new(gs)
	
	var sA := StationEntity.new("s_A", Vector2(0, 0), StationEntity.Shape.CIRCLE, Color.BLUE)
	var sB := StationEntity.new("s_B", Vector2(200, 0), StationEntity.Shape.TRIANGLE, Color.CYAN)
	gs.add_station(sA)
	gs.add_station(sB)
	
	var line1 := LineEntity.new("line_1", "1호선", Color.RED)
	line1.station_ids = ["s_A", "s_B"]
	gs.add_line(line1)
	ng.rebuild()
	
	# 일시정지
	line1.is_paused = true
	ng.rebuild()
	
	if ng.has_connection("s_A", "s_B"):
		return {"test": "노선 일시정지 반영", "passed": false, "reason": "일시정지된 노선이 여전히 연결됨"}
	
	# 재개
	line1.is_paused = false
	ng.rebuild()
	
	if not ng.has_connection("s_A", "s_B"):
		return {"test": "노선 일시정지 반영", "passed": false, "reason": "재개된 노선이 연결되지 않음"}
	
	return {"test": "노선 일시정지 반영", "passed": true, "reason": ""}
