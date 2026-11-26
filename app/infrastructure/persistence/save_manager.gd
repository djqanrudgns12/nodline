## 저장 관리자 (Save Manager)
## PRD 7장 참조
## 로컬 저장/불러오기, 자동 저장, 오류 복구, 스키마 마이그레이션
## 저장 위치: user://saves/, user://settings/
class_name SaveManager
extends RefCounted

const SAVE_DIR := "user://saves/"
const SETTINGS_DIR := "user://settings/"
const AUTOSAVE_FILE := "autosave.json"
const BACKUP_SUFFIX := ".backup"
const MAX_MANUAL_SLOTS := 3
const CURRENT_SCHEMA_VERSION := 1
const GAME_VERSION := "1.0.0"

var _game_state: GameStateRepository
var _serializer: SaveSerializer


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state
	_serializer = SaveSerializer.new()
	_ensure_directories()


func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(SETTINGS_DIR):
		DirAccess.make_dir_recursive_absolute(SETTINGS_DIR)


## 수동 저장 (슬롯 1~3)
func save_to_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_MANUAL_SLOTS:
		return {"success": false, "message": "잘못된 저장 슬롯입니다. (1~%d)" % MAX_MANUAL_SLOTS}
	
	var filename := "save_slot_%d.json" % slot
	return _save_to_file(filename)


## 자동 저장
func autosave() -> Dictionary:
	return _save_to_file(AUTOSAVE_FILE)


## 슬롯에서 불러오기
func load_from_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_MANUAL_SLOTS:
		return {"success": false, "message": "잘못된 저장 슬롯입니다."}
	
	var filename := "save_slot_%d.json" % slot
	return _load_from_file(filename)


## 자동 저장 불러오기
func load_autosave() -> Dictionary:
	return _load_from_file(AUTOSAVE_FILE)


## 저장 슬롯 목록 조회
func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	
	for i in range(1, MAX_MANUAL_SLOTS + 1):
		var filename := "save_slot_%d.json" % i
		var filepath := SAVE_DIR + filename
		var slot_info := {"slot": i, "exists": false, "filename": filename}
		
		if FileAccess.file_exists(filepath):
			var data: Variant = _read_json_file(filepath)
			if data != null:
				slot_info["exists"] = true
				slot_info["game_version"] = data.get("game_version", "unknown")
				slot_info["save_time"] = data.get("save_time", "unknown")
				slot_info["simulation_time"] = data.get("simulation_time", 0.0)
				slot_info["game_day"] = data.get("game_day", 1)
		
		slots.append(slot_info)
	
	# 자동 저장 정보
	var auto_path := SAVE_DIR + AUTOSAVE_FILE
	var auto_info := {"slot": 0, "exists": false, "filename": AUTOSAVE_FILE, "is_autosave": true}
	if FileAccess.file_exists(auto_path):
		var data: Variant = _read_json_file(auto_path)
		if data != null:
			auto_info["exists"] = true
			auto_info["game_version"] = data.get("game_version", "unknown")
			auto_info["save_time"] = data.get("save_time", "unknown")
			auto_info["simulation_time"] = data.get("simulation_time", 0.0)
			auto_info["game_day"] = data.get("game_day", 1)
	slots.append(auto_info)
	
	return slots


## 슬롯 삭제
func delete_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_MANUAL_SLOTS:
		return {"success": false, "message": "잘못된 저장 슬롯입니다."}
	
	var filename := "save_slot_%d.json" % slot
	var filepath := SAVE_DIR + filename
	
	if FileAccess.file_exists(filepath):
		DirAccess.remove_absolute(filepath)
		GameLogger.log_info("SAVE", "저장 슬롯 %d 삭제 완료" % slot)
		return {"success": true, "message": "삭제 완료"}
	
	return {"success": false, "message": "저장 파일이 없습니다."}


## 내부: 파일로 저장
func _save_to_file(filename: String) -> Dictionary:
	var filepath := SAVE_DIR + filename
	
	# 직렬화
	var save_data := _serializer.serialize(_game_state)
	save_data["game_version"] = GAME_VERSION
	save_data["schema_version"] = CURRENT_SCHEMA_VERSION
	save_data["save_time"] = Time.get_datetime_string_from_system()
	
	# 기존 파일 백업
	if FileAccess.file_exists(filepath):
		var backup_path := filepath + BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		DirAccess.rename_absolute(filepath, backup_path)
	
	# JSON 저장
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		var message := "저장 실패: 파일을 열 수 없습니다. (오류: %d)" % err
		GameLogger.log_error("SAVE", message)
		EventBus.save_failed.emit(message)
		
		# 백업 복구
		var backup_path := filepath + BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, filepath)
		
		return {"success": false, "message": message}
	
	file.store_string(json_string)
	file.close()
	
	var slot_name := filename.get_basename()
	GameLogger.log_info("SAVE", "저장 완료: %s" % filename)
	EventBus.game_saved.emit(slot_name)
	
	return {"success": true, "message": "저장 완료"}


## 내부: 파일에서 불러오기
func _load_from_file(filename: String) -> Dictionary:
	var filepath := SAVE_DIR + filename
	
	if not FileAccess.file_exists(filepath):
		# 백업 파일 시도
		var backup_path := filepath + BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			GameLogger.log_warning("SAVE", "원본 저장 파일 없음. 백업에서 복구 시도: %s" % backup_path)
			filepath = backup_path
		else:
			var message := "저장 파일을 찾을 수 없습니다: %s" % filename
			EventBus.load_failed.emit(message)
			return {"success": false, "message": message}
	
	var data: Variant = _read_json_file(filepath)
	if data == null:
		# 손상된 파일 — 백업 시도
		var backup_path := filepath + BACKUP_SUFFIX
		if filepath != backup_path and FileAccess.file_exists(backup_path):
			GameLogger.log_warning("SAVE", "저장 파일 손상. 백업에서 복구 시도.")
			data = _read_json_file(backup_path)
		
		if data == null:
			var message := "저장 파일이 손상되었습니다: %s" % filename
			GameLogger.log_error("SAVE", message)
			EventBus.load_failed.emit(message)
			return {"success": false, "message": message}
	
	# 스키마 마이그레이션
	var schema_ver: int = data.get("schema_version", 0)
	if schema_ver < CURRENT_SCHEMA_VERSION:
		data = SchemaMigrator.migrate(data, schema_ver, CURRENT_SCHEMA_VERSION)
		GameLogger.log_info("SAVE", "스키마 마이그레이션 완료: v%d → v%d" % [schema_ver, CURRENT_SCHEMA_VERSION])
	
	# 역직렬화
	var result := _serializer.deserialize(data, _game_state)
	if not result.success:
		EventBus.load_failed.emit(result.message)
		return result
	
	var slot_name := filename.get_basename()
	GameLogger.log_info("SAVE", "불러오기 완료: %s" % filename)
	EventBus.game_loaded.emit(slot_name)
	
	return {"success": true, "message": "불러오기 완료"}


## JSON 파일 읽기
func _read_json_file(filepath: String) -> Variant:
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		GameLogger.log_error("SAVE", "JSON 파싱 실패: %s (줄 %d)" % [json.get_error_message(), json.get_error_line()])
		return null
	
	return json.data
