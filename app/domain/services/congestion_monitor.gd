## 혼잡도 모니터 서비스 (Congestion Monitor)
## PRD 6.2 참조
## 모든 역의 혼잡도를 감시하고, 게임오버 조건을 판정한다.
class_name CongestionMonitorService
extends RefCounted

var _game_state: GameStateRepository
var _most_congested_station_id: String = ""


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 모든 역의 혼잡 상태를 업데이트한다.
## 반환: {game_over: bool, game_over_station_id: String}
func update() -> Dictionary:
	var balance := GameConfig.balance
	var game_over := false
	var game_over_station_id := ""
	var max_passengers := 0
	
	for station in _game_state.get_all_stations():
		var old_state: StationEntity.CongestionState = station.congestion_state
		var new_state: StationEntity.CongestionState = station.update_congestion_state(
			balance.station_warning_threshold,
			balance.station_danger_threshold,
			balance.max_passengers_per_station
		)
		
		# 상태 변경 시 이벤트 발행
		if new_state != old_state:
			EventBus.station_congestion_changed.emit(
				station.id,
				station.get_passenger_count(),
				StationEntity.CongestionState.keys()[new_state]
			)
			
			# 로그 기록
			match new_state:
				StationEntity.CongestionState.WARNING:
					GameLogger.log_warning("STATION", "역 %s 주의 상태: %d/%d명" % [
						station.id, station.get_passenger_count(), balance.max_passengers_per_station
					])
				StationEntity.CongestionState.DANGER:
					GameLogger.log_warning("STATION", "역 %s 위험 상태: %d/%d명" % [
						station.id, station.get_passenger_count(), balance.max_passengers_per_station
					])
				StationEntity.CongestionState.GAME_OVER:
					GameLogger.log_error("STATION", "역 %s 게임오버: %d/%d명" % [
						station.id, station.get_passenger_count(), balance.max_passengers_per_station
					])
		
		# 게임오버 판정
		if new_state == StationEntity.CongestionState.GAME_OVER:
			game_over = true
			game_over_station_id = station.id
		
		# 가장 혼잡한 역 기록
		if station.get_passenger_count() > max_passengers:
			max_passengers = station.get_passenger_count()
			_most_congested_station_id = station.id
	
	return {
		"game_over": game_over,
		"game_over_station_id": game_over_station_id
	}


## 가장 혼잡한 역 ID를 반환한다.
func get_most_congested_station_id() -> String:
	return _most_congested_station_id
