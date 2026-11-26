## 단위 테스트: 객차 탑승 규칙
## PRD 9.2 — 객차 5명 탑승 → 성공 / 6번째 → 실패
extends Node

const TEST_NAME := "test_carriage_boarding_rule"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_5_passengers_board_successfully())
	results.append(_test_6th_passenger_rejected())
	results.append(_test_train_capacity_check())
	return results


## 객차에 5명 탑승 성공
func _test_5_passengers_board_successfully() -> Dictionary:
	var carriage := CarriageEntity.new("c_001", "t_001")
	var max_p := 5
	
	for i in range(5):
		var check := BoardingRule.can_board_carriage(carriage, max_p)
		if not check.valid:
			return {"test": "5명 탑승 성공", "passed": false, "reason": "승객 %d에서 실패" % (i + 1)}
		
		var passenger := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		carriage.passengers.append(passenger)
	
	if carriage.get_passenger_count() != 5:
		return {"test": "5명 탑승 성공", "passed": false, "reason": "탑승 수가 5가 아님: %d" % carriage.get_passenger_count()}
	
	return {"test": "5명 탑승 성공", "passed": true, "reason": ""}


## 6번째 승객 탑승 거부
func _test_6th_passenger_rejected() -> Dictionary:
	var carriage := CarriageEntity.new("c_001", "t_001")
	var max_p := 5
	
	for i in range(5):
		var passenger := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		carriage.passengers.append(passenger)
	
	var check := BoardingRule.can_board_carriage(carriage, max_p)
	if check.valid:
		return {"test": "6번째 승객 거부", "passed": false, "reason": "6번째 승객이 탑승 허용됨"}
	
	return {"test": "6번째 승객 거부", "passed": true, "reason": ""}


## 열차 전체 수용량 확인
func _test_train_capacity_check() -> Dictionary:
	var train := TrainEntity.new("t_001", "l_001")
	var max_per_carriage := 5
	
	# 객차 3개 연결
	for i in range(3):
		var carriage := CarriageEntity.new("c_%d" % i, "t_001")
		train.carriages.append(carriage)
	
	# 총 수용량 = 15
	var total_cap := train.get_total_capacity(max_per_carriage)
	if total_cap != 15:
		return {"test": "열차 수용량", "passed": false, "reason": "총 수용량이 15가 아님: %d" % total_cap}
	
	# 승객 15명 탑승
	for i in range(15):
		var passenger := PassengerEntity.new("p_%d" % i, "s_001", "s_002")
		var boarded := train.board_passenger(passenger, max_per_carriage)
		if not boarded:
			return {"test": "열차 수용량", "passed": false, "reason": "승객 %d 탑승 실패" % (i + 1)}
	
	# 16번째 승객 거부
	var extra := PassengerEntity.new("p_15", "s_001", "s_002")
	var boarded := train.board_passenger(extra, max_per_carriage)
	if boarded:
		return {"test": "열차 수용량", "passed": false, "reason": "16번째 승객이 탑승됨"}
	
	return {"test": "열차 수용량", "passed": true, "reason": ""}
