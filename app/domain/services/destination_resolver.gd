## 목적지 결정 서비스 (Destination Resolver)
## PRD D-02 (ADR) 참조
## B 방식: 모양 후보 + 색상 우선
## 1) 승객의 모양과 같은 역들을 후보군으로 만든다.
## 2) 후보군 중 승객의 색상과 같은 역을 우선 선택한다.
## 3) 같은 색 역이 없거나 복수일 경우 직선거리가 가장 짧은 역을 최종 선택한다.
class_name DestinationResolver
extends RefCounted

var _game_state: GameStateRepository


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 승객의 목적지를 결정한다.
## 반환: {station_id: String, shape: Shape, color: Color} 또는 {}
func resolve(origin_station: StationEntity) -> Dictionary:
	var all_stations := _game_state.get_all_stations()
	
	# 자기 자신을 제외한 다른 역들
	var other_stations: Array = []
	for station in all_stations:
		if station.id != origin_station.id:
			other_stations.append(station)
	
	if other_stations.is_empty():
		return {}
	
	# 후보군을 무작위로 만든다: 모양이 같은 역 (자기 자신 제외)
	# 모양이 같은 역이 없으면 아무 역이나 선택
	var shape_candidates: Array = []
	for station in other_stations:
		if station.shape != origin_station.shape:
			shape_candidates.append(station)
	
	# 모양이 같은 역만 있으면 (모두 같은 모양) 전체 후보 사용
	if shape_candidates.is_empty():
		shape_candidates = other_stations
	
	if shape_candidates.is_empty():
		return {}
	
	# 1단계: 후보군에서 같은 색이 아닌 역 우선 (다양성을 위해)
	# → PRD 정의: "목적지 모양"이 승객의 속성이므로, 
	#   승객에게는 "이동해야 할 모양"이 부여된다.
	# 가장 가까운 목적지를 선택
	var best_station: StationEntity = null
	var best_distance := INF
	
	# 색상 우선: 출발역과 다른 색상의 역을 우선
	var color_preferred: Array = []
	var color_others: Array = []
	
	for station in shape_candidates:
		if station.color != origin_station.color:
			color_preferred.append(station)
		else:
			color_others.append(station)
	
	# 색상 우선 역이 있으면 그 중에서 선택
	var final_candidates: Array = color_preferred if not color_preferred.is_empty() else color_others
	
	# 거리가 가장 가까운 역 선택
	for station in final_candidates:
		var dist := origin_station.position.distance_to(station.position)
		if dist < best_distance:
			best_distance = dist
			best_station = station
	
	if best_station == null:
		return {}
	
	return {
		"station_id": best_station.id,
		"shape": best_station.shape,
		"color": best_station.color
	}
