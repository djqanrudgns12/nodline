## 단위 테스트: 혼잡도 및 게임오버 판정
## PRD 9.2 — 14명 → DANGER / 15명 → GAME_OVER
extends Node

const TEST_NAME := "test_congestion_game_over"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_normal_state())
	results.append(_test_warning_state())
	results.append(_test_danger_state())
	results.append(_test_game_over_state())
	results.append(_test_congestion_monitor_triggers_game_over())
	return results


## 0~11명: 정상 (NORMAL)
func _test_normal_state() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	
	for i in range(11):
		var p := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		station.add_passenger(p)
	
	var state := station.update_congestion_state(12, 14, 15)
	if state != StationEntity.CongestionState.NORMAL:
		return {"test": "11명 정상 상태", "passed": false, "reason": "상태가 NORMAL이 아님"}
	
	return {"test": "11명 정상 상태", "passed": true, "reason": ""}


## 12~13명: 주의 (WARNING)
func _test_warning_state() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	
	for i in range(12):
		var p := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		station.add_passenger(p)
	
	var state := station.update_congestion_state(12, 14, 15)
	if state != StationEntity.CongestionState.WARNING:
		return {"test": "12명 주의 상태", "passed": false, "reason": "상태가 WARNING이 아님"}
	
	return {"test": "12명 주의 상태", "passed": true, "reason": ""}


## 14명: 위험 (DANGER)
func _test_danger_state() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	
	for i in range(14):
		var p := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		station.add_passenger(p)
	
	var state := station.update_congestion_state(12, 14, 15)
	if state != StationEntity.CongestionState.DANGER:
		return {"test": "14명 위험 상태", "passed": false, "reason": "상태가 DANGER가 아님"}
	
	return {"test": "14명 위험 상태", "passed": true, "reason": ""}


## 15명: 게임오버 (GAME_OVER)
func _test_game_over_state() -> Dictionary:
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	
	for i in range(15):
		var p := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		station.add_passenger(p)
	
	var state := station.update_congestion_state(12, 14, 15)
	if state != StationEntity.CongestionState.GAME_OVER:
		return {"test": "15명 게임오버", "passed": false, "reason": "상태가 GAME_OVER가 아님"}
	
	return {"test": "15명 게임오버", "passed": true, "reason": ""}


## CongestionMonitorService가 게임오버를 트리거하는지 확인
func _test_congestion_monitor_triggers_game_over() -> Dictionary:
	var game_state := GameStateRepository.new()
	
	# 역 생성
	var station := StationEntity.new("s_001", Vector2.ZERO, StationEntity.Shape.CIRCLE, Color.WHITE)
	game_state.add_station(station)
	
	# 15명 승객 추가
	for i in range(15):
		var p := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		game_state.add_passenger(p)
		station.add_passenger(p)
	
	var monitor := CongestionMonitorService.new(game_state)
	var result := monitor.update()
	
	if not result.game_over:
		return {"test": "혼잡도 모니터 게임오버", "passed": false, "reason": "게임오버가 트리거되지 않음"}
	
	if result.game_over_station_id != "s_001":
		return {"test": "혼잡도 모니터 게임오버", "passed": false, "reason": "게임오버 역 ID 불일치"}
	
	return {"test": "혼잡도 모니터 게임오버", "passed": true, "reason": ""}
