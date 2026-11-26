## 점수 계산 서비스 (Score Calculator)
## PRD D-08 참조
## C 방식: 네트워크 효율 + 생존 시간
## 총점 = (누적 도착 승객 수 × 10) + (생존 일수 × 50) + 네트워크 효율 보너스
class_name ScoreCalculator
extends RefCounted

var _game_state: GameStateRepository


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 최종 점수를 계산한다.
func calculate() -> Dictionary:
	var balance := GameConfig.balance
	
	var arrived_score := _game_state.total_arrived_passengers * balance.score_per_arrived_passenger
	var survival_score := _game_state.game_day * balance.score_per_survived_day
	var efficiency_bonus := _calculate_efficiency_bonus()
	var total := arrived_score + survival_score + efficiency_bonus
	
	return {
		"total_score": total,
		"arrived_passengers": _game_state.total_arrived_passengers,
		"arrived_score": arrived_score,
		"survival_days": _game_state.game_day,
		"survival_score": survival_score,
		"efficiency_bonus": efficiency_bonus,
		"max_simultaneous_passengers": _game_state.max_simultaneous_passengers,
		"total_stations": _game_state.stations.size(),
		"total_lines": _game_state.lines.size(),
		"total_trains": _game_state.trains.size(),
		"total_bridges": _game_state.bridges.size(),
		"total_tunnels": _game_state.tunnels.size()
	}


## 네트워크 효율 보너스를 계산한다.
## 모든 역이 연결되어 있으면 추가 보너스
func _calculate_efficiency_bonus() -> int:
	var stations := _game_state.get_all_stations()
	if stations.size() < 2:
		return 0
	
	# 연결된 역 비율로 보너스 계산
	var connected_count := 0
	for station in stations:
		if not station.connected_line_ids.is_empty():
			connected_count += 1
	
	var connection_ratio := float(connected_count) / stations.size()
	
	# 기본 효율 보너스: 연결 비율 × 100
	var bonus := int(connection_ratio * 100.0)
	
	# 모든 역 연결 시 추가 보너스
	if connected_count == stations.size():
		bonus += 200
	
	return bonus
