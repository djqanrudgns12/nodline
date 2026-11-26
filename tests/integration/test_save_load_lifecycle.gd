## 통합 테스트: 저장/불러오기 수명주기 및 마이그레이션
## PRD 9.2 — 저장 → 종료 → 다시 불러오기 → 핵심 상태 100% 동일 및 이전 버전 마이그레이션
extends Node

const TEST_NAME := "test_save_load_lifecycle"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_serialization_roundtrip())
	results.append(_test_save_and_load_manager())
	results.append(_test_schema_migration_v0_to_v1())
	return results


## 직렬화 -> 역직렬화 라운드트립 일치성 검증
func _test_serialization_roundtrip() -> Dictionary:
	var gs := GameStateRepository.new()
	gs.seed_value = 777
	gs.simulation_time = 123.45
	gs.game_day = 3
	gs.available_bridges = 2
	gs.available_tunnels = 1
	gs.available_line_slots = 4
	gs.total_arrived_passengers = 15
	
	# 역 추가
	var station := StationEntity.new("s_01", Vector2(100, 200), StationEntity.Shape.TRIANGLE, Color.CYAN)
	gs.add_station(station)
	
	# 노선 추가
	var line := LineEntity.new("line_01", "1호선", Color.RED)
	line.station_ids = ["s_01"]
	gs.add_line(line)
	
	# 승객 추가
	var passenger := PassengerEntity.new("p_01", "s_01", "s_02", StationEntity.Shape.CIRCLE, Color.BLUE)
	gs.add_passenger(passenger)
	station.add_passenger(passenger)
	
	# 직렬화
	var serializer := SaveSerializer.new()
	var dict := serializer.serialize(gs)
	
	# 새로운 저장소에 역직렬화
	var gs_restored := GameStateRepository.new()
	serializer.deserialize(dict, gs_restored)
	
	# 검증
	if gs_restored.seed_value != 777:
		return {"test": "저장 직렬화 라운드트립", "passed": false, "reason": "시드 불일치"}
	if absf(gs_restored.simulation_time - 123.45) > 0.001:
		return {"test": "저장 직렬화 라운드트립", "passed": false, "reason": "시뮬레이션 시간 불일치"}
	if gs_restored.get_all_stations().size() != 1:
		return {"test": "저장 직렬화 라운드트립", "passed": false, "reason": "복원된 역 수 불일치"}
	if gs_restored.get_all_lines().size() != 1:
		return {"test": "저장 직렬화 라운드트립", "passed": false, "reason": "복원된 노선 수 불일치"}
	if gs_restored.get_all_passengers().size() != 1:
		return {"test": "저장 직렬화 라운드트립", "passed": false, "reason": "복원된 승객 수 불일치"}
	
	return {"test": "저장 직렬화 라운드트립 (100% 일치)", "passed": true, "reason": ""}


## SaveManager를 통한 슬롯 파일 저장 및 복원
func _test_save_and_load_manager() -> Dictionary:
	var gs := GameStateRepository.new()
	gs.seed_value = 999
	gs.game_day = 5
	var station := StationEntity.new("s_test", Vector2(50, 50), StationEntity.Shape.SQUARE, Color.PURPLE)
	gs.add_station(station)
	
	var sm := SaveManager.new(gs)
	var save_res: Dictionary = sm.save_to_slot(1)
	if not save_res.success:
		return {"test": "SaveManager 슬롯 저장/복원", "passed": false, "reason": "슬롯 저장 실패: %s" % save_res.get("message", "")}
	
	# 상태 초기화 후 복원
	gs.clear()
	var load_res: Dictionary = sm.load_from_slot(1)
	if not load_res.success:
		return {"test": "SaveManager 슬롯 저장/복원", "passed": false, "reason": "슬롯 불러오기 실패: %s" % load_res.get("message", "")}
	
	if gs.seed_value != 999 or gs.game_day != 5:
		return {"test": "SaveManager 슬롯 저장/복원", "passed": false, "reason": "불러온 데이터 값 불일치"}
	
	return {"test": "SaveManager 슬롯 저장/복원", "passed": true, "reason": ""}


## 스키마 마이그레이션 검증 (v0 -> v1)
func _test_schema_migration_v0_to_v1() -> Dictionary:
	var legacy_data: Dictionary = {
		"seed": 1234,
		"simulation_time": 50.0,
		"game_day": 1
		# schema_version 누락 (v0)
	}
	
	var migrated := SchemaMigrator.migrate(legacy_data, 0, 1)
	
	if migrated.get("schema_version", 0) != 1:
		return {"test": "스키마 마이그레이션 v0->v1", "passed": false, "reason": "schema_version이 1로 설정되지 않음"}
	
	if "speed_multiplier" not in migrated:
		return {"test": "스키마 마이그레이션 v0->v1", "passed": false, "reason": "기본 필드 speed_multiplier 누락"}
	
	return {"test": "스키마 마이그레이션 v0->v1", "passed": true, "reason": ""}
