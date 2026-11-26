## 시뮬레이션 시계 (Simulation Clock)
## PRD 6.6 참조
## 일시정지, 1x, 2x, 4x 배속 지원
## UI 프레임과 게임 계산 시간을 분리한다.
class_name SimulationClock
extends RefCounted

enum SpeedMode {
	PAUSED,    # 0x
	NORMAL,    # 1x
	FAST,      # 2x
	VERY_FAST  # 4x
}

const SPEED_MULTIPLIERS := {
	SpeedMode.PAUSED: 0.0,
	SpeedMode.NORMAL: 1.0,
	SpeedMode.FAST: 2.0,
	SpeedMode.VERY_FAST: 4.0,
}

var speed_mode: SpeedMode = SpeedMode.PAUSED
var _game_state: GameStateRepository
var _last_day: int = 0
var _last_spawn_check_hour: float = 0.0


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 시뮬레이션을 진행한다.
## 반환: 게임 내 경과 시간 (초)
func tick(real_delta: float) -> float:
	var multiplier: float = SPEED_MULTIPLIERS.get(speed_mode, 0.0)
	var game_delta := real_delta * multiplier
	
	if game_delta <= 0.0:
		return 0.0
	
	_game_state.simulation_time += game_delta
	_game_state.speed_multiplier = multiplier
	
	# 게임 시간 업데이트
	var current_hour := _game_state.get_game_hour()
	EventBus.simulation_time_changed.emit(current_hour)
	
	# 날짜 변경 감지
	var current_day := _game_state.get_game_day()
	if current_day != _last_day:
		_last_day = current_day
		_game_state.game_day = current_day
		EventBus.day_changed.emit(current_day)
	
	GameLogger.set_simulation_time(_game_state.simulation_time)
	
	return game_delta


## 배속을 설정한다.
func set_speed(mode: SpeedMode) -> void:
	var old_mode := speed_mode
	speed_mode = mode
	
	var multiplier: float = SPEED_MULTIPLIERS.get(mode, 0.0)
	_game_state.speed_multiplier = multiplier
	
	if mode == SpeedMode.PAUSED:
		EventBus.game_paused.emit()
	elif old_mode == SpeedMode.PAUSED:
		EventBus.game_resumed.emit()
	
	EventBus.speed_changed.emit(multiplier)
	GameLogger.log_info("CLOCK", "배속 변경: %s (%.1fx)" % [SpeedMode.keys()[mode], multiplier])


## 일시정지/재생을 토글한다.
func toggle_pause() -> void:
	if speed_mode == SpeedMode.PAUSED:
		set_speed(SpeedMode.NORMAL)
	else:
		set_speed(SpeedMode.PAUSED)


## 현재 배속 텍스트를 반환한다.
func get_speed_text() -> String:
	match speed_mode:
		SpeedMode.PAUSED: return "일시정지"
		SpeedMode.NORMAL: return "1배속"
		SpeedMode.FAST: return "2배속"
		SpeedMode.VERY_FAST: return "4배속"
		_: return "알 수 없음"


## 게임 내 시간 텍스트를 반환한다 (HH:MM 형식).
func get_time_text() -> String:
	var hour := _game_state.get_game_hour()
	var minutes := int(fmod(hour * 60.0, 60.0))
	return "%02d:%02d" % [int(hour), minutes]


## 현재 일시정지 상태인지 반환한다.
func is_paused() -> bool:
	return speed_mode == SpeedMode.PAUSED
