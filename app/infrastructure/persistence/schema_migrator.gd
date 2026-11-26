## 스키마 마이그레이터 (Schema Migrator)
## PRD 7장 참조
## 데이터 구조 변경에 대비한 버전 변환(Migration) 기능
## 손상된 저장 파일 발견 시 원본을 바로 삭제하지 않고 보존한다.
class_name SchemaMigrator
extends RefCounted


## 스키마 마이그레이션을 실행한다.
static func migrate(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	var current := data.duplicate(true)
	
	for version in range(from_version, to_version):
		match version:
			0:
				current = _migrate_v0_to_v1(current)
			# 향후 버전 추가 시 여기에 case 추가
			# 1:
			#     current = _migrate_v1_to_v2(current)
	
	current["schema_version"] = to_version
	return current


## v0 → v1: 초기 스키마 정의
## 스키마 버전이 없는 구버전 파일을 v1으로 변환
static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	# 누락된 필드에 기본값 설정
	if "schema_version" not in data:
		data["schema_version"] = 1
	
	if "speed_multiplier" not in data:
		data["speed_multiplier"] = 1.0
	
	if "max_simultaneous_passengers" not in data:
		data["max_simultaneous_passengers"] = 0
	
	if "available_line_slots" not in data:
		data["available_line_slots"] = 0
	
	if "id_counters" not in data:
		data["id_counters"] = {}
	
	# 역 데이터 보정
	for station in data.get("stations", []):
		if "congestion_state" not in station:
			station["congestion_state"] = "NORMAL"
		if "created_at_sim_time" not in station:
			station["created_at_sim_time"] = 0.0
	
	# 승객 데이터 보정
	for passenger in data.get("passengers", []):
		if "waiting_time" not in passenger:
			passenger["waiting_time"] = 0.0
	
	# 노선 데이터 보정
	for line in data.get("lines", []):
		if "waypoints" not in line:
			line["waypoints"] = {}
		if "bridge_ids" not in line:
			line["bridge_ids"] = []
		if "tunnel_ids" not in line:
			line["tunnel_ids"] = []
		if "created_at_sim_time" not in line:
			line["created_at_sim_time"] = 0.0
	
	return data
