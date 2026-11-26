## 게임 로그 시스템 (Autoload)
## 게임 내 모든 주요 이벤트를 시간 순서대로 기록한다.
## 게임오버 화면의 "최근 주요 이벤트 10개"에 사용된다.
extends Node

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR
}

## 로그 항목 구조
class LogEntry:
	var timestamp: float  # 게임 시뮬레이션 시간
	var level: LogLevel
	var category: String  # 예: "STATION", "LINE", "TRAIN", "PASSENGER", "GAME"
	var message: String
	var data: Dictionary
	
	func _init(p_timestamp: float, p_level: LogLevel, p_category: String, p_message: String, p_data: Dictionary = {}) -> void:
		timestamp = p_timestamp
		level = p_level
		category = p_category
		message = p_message
		data = p_data
	
	func to_dict() -> Dictionary:
		return {
			"timestamp": timestamp,
			"level": LogLevel.keys()[level],
			"category": category,
			"message": message,
			"data": data
		}

## 최대 로그 보관 수
const MAX_LOG_ENTRIES: int = 500

## 로그 저장소
var _entries: Array[LogEntry] = []
var _current_sim_time: float = 0.0


func set_simulation_time(sim_time: float) -> void:
	_current_sim_time = sim_time


func log_debug(category: String, message: String, data: Dictionary = {}) -> void:
	_add_entry(LogLevel.DEBUG, category, message, data)


func log_info(category: String, message: String, data: Dictionary = {}) -> void:
	_add_entry(LogLevel.INFO, category, message, data)


func log_warning(category: String, message: String, data: Dictionary = {}) -> void:
	_add_entry(LogLevel.WARNING, category, message, data)
	push_warning("[%s] %s" % [category, message])


func log_error(category: String, message: String, data: Dictionary = {}) -> void:
	_add_entry(LogLevel.ERROR, category, message, data)
	push_error("[%s] %s" % [category, message])


func get_recent_entries(count: int = 10, min_level: LogLevel = LogLevel.INFO) -> Array[LogEntry]:
	var filtered: Array[LogEntry] = []
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].level >= min_level:
			filtered.append(_entries[i])
			if filtered.size() >= count:
				break
	return filtered


func get_entries_by_category(category: String, count: int = 50) -> Array[LogEntry]:
	var filtered: Array[LogEntry] = []
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].category == category:
			filtered.append(_entries[i])
			if filtered.size() >= count:
				break
	return filtered


func clear() -> void:
	_entries.clear()


func _add_entry(level: LogLevel, category: String, message: String, data: Dictionary) -> void:
	var entry := LogEntry.new(_current_sim_time, level, category, message, data)
	_entries.append(entry)
	
	# 최대 수 초과 시 오래된 항목 제거
	if _entries.size() > MAX_LOG_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_LOG_ENTRIES)
	
	# 디버그 출력
	if OS.is_debug_build():
		print("[%.1f][%s][%s] %s" % [_current_sim_time, LogLevel.keys()[level], category, message])
