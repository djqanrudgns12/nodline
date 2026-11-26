## 단위 테스트: 역 노선 연결 규칙
## PRD 9.2 — 한 역에 5개 노선 연결 → 성공 / 6번째 → 실패
extends Node

const TEST_NAME := "test_station_line_connection_rule"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_5_connections_succeed())
	results.append(_test_6th_connection_fails())
	results.append(_test_duplicate_connection_ignored())
	return results


## 5개 노선 연결 성공
func _test_5_connections_succeed() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	var max_lines := 5
	
	for i in range(5):
		var line_id := "line_%d" % i
		var result := LineConnectionRule.can_connect(station, line_id, max_lines)
		if not result.valid:
			return {"test": "5개 노선 연결 성공", "passed": false, "reason": "연결 %d에서 실패: %s" % [i + 1, result.reason]}
		station.add_line_connection(line_id, max_lines)
	
	if station.connected_line_ids.size() != 5:
		return {"test": "5개 노선 연결 성공", "passed": false, "reason": "연결 수가 5가 아님: %d" % station.connected_line_ids.size()}
	
	return {"test": "5개 노선 연결 성공", "passed": true, "reason": ""}


## 6번째 노선 연결 실패
func _test_6th_connection_fails() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	var max_lines := 5
	
	for i in range(5):
		station.add_line_connection("line_%d" % i, max_lines)
	
	var result := LineConnectionRule.can_connect(station, "line_5", max_lines)
	
	if result.valid:
		return {"test": "6번째 노선 연결 실패", "passed": false, "reason": "6번째 연결이 허용됨"}
	
	return {"test": "6번째 노선 연결 실패", "passed": true, "reason": ""}


## 이미 연결된 노선 중복 연결은 허용 (기존 연결 유지)
func _test_duplicate_connection_ignored() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	var max_lines := 5
	
	station.add_line_connection("line_0", max_lines)
	var result := LineConnectionRule.can_connect(station, "line_0", max_lines)
	
	if not result.valid:
		return {"test": "중복 연결 무시", "passed": false, "reason": "이미 연결된 노선이 거부됨"}
	
	return {"test": "중복 연결 무시", "passed": true, "reason": ""}
