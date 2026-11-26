## 통합 테스트: 열차 정차 사이클 (하차 → 환승 → 탑승)
## PRD 9.2 — 열차 역 도착 → 목적지 하차 → 환승 처리 → 신규 탑승 순서 동작
extends Node

const TEST_NAME := "test_train_stop_cycle"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_full_stop_cycle())
	return results


func _test_full_stop_cycle() -> Dictionary:
	var gs := GameStateRepository.new()
	var ng := NetworkGraph.new(gs)
	var tm := TrainMovementService.new(gs, ng)
	var balance := GameConfig.balance
	
	# 역 A, B, C 생성
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
	
	# 열차 1 (1호선 운행, 객차 1개, 최대 5명)
	var train := TrainEntity.new("train_1", "line_1")
	var carriage := CarriageEntity.new("carriage_1", "train_1")
	train.carriages.append(carriage)
	gs.add_train(train)
	gs.add_carriage(carriage)
	
	# 1) 목적지가 B인 승객 (p_dest_B) -> 열차 탑승 중
	var p_dest_B := PassengerEntity.new("p_dest_B", "s_A", "s_B")
	p_dest_B.board_train("train_1")
	train.board_passenger(p_dest_B, 5)
	gs.add_passenger(p_dest_B)
	
	# 2) 목적지가 C인 승객 (p_transfer_C) -> 열차 탑승 중 (1호선 종점 B에서 2호선으로 환승 필요)
	var p_transfer_C := PassengerEntity.new("p_transfer_C", "s_A", "s_C")
	p_transfer_C.board_train("train_1")
	train.board_passenger(p_transfer_C, 5)
	gs.add_passenger(p_transfer_C)
	
	# 3) B역에서 대기 중인 승객 (p_waiting_B) -> 목적지 A
	var p_waiting_B := PassengerEntity.new("p_waiting_B", "s_B", "s_A")
	sB.add_passenger(p_waiting_B)
	gs.add_passenger(p_waiting_B)
	
	# 열차가 B역에 도착하여 정차(AT_STATION) 처리
	train.operation_state = TrainEntity.OperationState.AT_STATION
	train.current_station_id = "s_B"
	
	# 정차 로직 실행 (tick)
	tm.tick(0.1)
	
	# 검증 1: p_dest_B는 하차 완료 및 도착 카운트 증가
	if gs.total_arrived_passengers != 1:
		return {"test": "열차 정차 하차 순서", "passed": false, "reason": "도착 승객 카운트 불일치: %d" % gs.total_arrived_passengers}
	if gs.get_passenger("p_dest_B") != null:
		return {"test": "열차 정차 하차 순서", "passed": false, "reason": "하차 승객이 저장소에서 제거되지 않음"}
	
	# 검증 2: p_transfer_C는 열차에서 내려 B역 대기열로 환승
	if train.has_passenger("p_transfer_C"):
		return {"test": "열차 정차 환승 처리", "passed": false, "reason": "환승 승객이 열차에 남아있음"}
	if not sB.waiting_passengers.has(p_transfer_C):
		return {"test": "열차 정차 환승 처리", "passed": false, "reason": "환승 승객이 B역 대기열에 없음"}
	
	# 검증 3: p_waiting_B는 B역에서 열차로 신규 탑승
	if sB.waiting_passengers.has(p_waiting_B):
		return {"test": "열차 정차 신규 탑승", "passed": false, "reason": "대기 승객이 역에서 제거되지 않음"}
	if not train.has_passenger("p_waiting_B"):
		return {"test": "열차 정차 신규 탑승", "passed": false, "reason": "대기 승객이 열차에 탑승하지 않음"}
	
	return {"test": "열차 정차 사이클 (하차->환승->탑승)", "passed": true, "reason": ""}
