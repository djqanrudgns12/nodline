## 열차 엔티티 (Train)
## PRD 6.4 참조
## 노선 위를 이동하며 승객을 수송하는 열차
class_name TrainEntity
extends RefCounted

## 열차 운행 상태
enum OperationState {
	IDLE,        # 노선 미배치 (인벤토리)
	MOVING,      # 이동 중
	AT_STATION,  # 역 정차 중
	PAUSED       # 노선 일시정지
}

var id: String
var line_id: String
var carriages: Array = []  # Array of CarriageEntity
var current_station_id: String
var target_station_id: String
var operation_state: OperationState = OperationState.IDLE
var direction: int = 1  # 1 = 정방향, -1 = 역방향
var progress: float = 0.0  # 구간 이동 진행률 (0.0 ~ 1.0)
var current_speed: float = 0.0
var path_points: Array[Vector2] = []  # 현재 이동 중인 경로 포인트
var path_progress: float = 0.0  # 전체 경로 진행 거리


func _init(p_id: String = "", p_line_id: String = "") -> void:
	id = p_id
	line_id = p_line_id


## 객차를 추가한다. 성공 여부를 반환한다.
func add_carriage(carriage, max_carriages: int) -> bool:
	if carriages.size() >= max_carriages:
		return false
	carriages.append(carriage)
	carriage.train_id = id
	return true


## 객차를 제거한다.
func remove_carriage(carriage) -> void:
	carriages.erase(carriage)
	carriage.train_id = ""


## 총 수용 인원을 반환한다.
func get_total_capacity(max_per_carriage: int) -> int:
	return carriages.size() * max_per_carriage


## 현재 탑승 인원을 반환한다.
func get_total_passengers() -> int:
	var total := 0
	for carriage in carriages:
		total += carriage.get_passenger_count()
	return total


## 탑승 가능한 잔여 공간을 반환한다.
func get_remaining_capacity(max_per_carriage: int) -> int:
	return get_total_capacity(max_per_carriage) - get_total_passengers()


## 승객을 탑승시킨다. 성공 여부를 반환한다.
func board_passenger(passenger, max_per_carriage: int) -> bool:
	for carriage in carriages:
		if carriage.can_board(max_per_carriage):
			carriage.board_passenger(passenger)
			return true
	return false


## 목적지에 도착한 승객들을 반환한다.
func get_passengers_for_station(station_id: String) -> Array:
	var result: Array = []
	for carriage in carriages:
		for p in carriage.passengers:
			if p.has_arrived_at_destination(station_id):
				result.append(p)
	return result


## 특정 역에서 환승이 필요한 승객들을 반환한다.
## 이 역이 승객의 최종 목적지가 아니면서, 현재 노선으로는 도달할 수 없는 경우
func get_passengers_needing_transfer(station_id: String, line_station_ids: Array[String]) -> Array:
	var result: Array = []
	for carriage in carriages:
		for p in carriage.passengers:
			if not p.has_arrived_at_destination(station_id):
				# 목적지가 현재 노선에 없으면 환승 필요
				if p.destination_station_id not in line_station_ids:
					result.append(p)
	return result


## 승객을 하차시킨다.
func remove_passenger(passenger) -> void:
	for carriage in carriages:
		if passenger in carriage.passengers:
			carriage.remove_passenger(passenger)
			return


## 모든 탑승 승객을 반환한다.
func get_all_passengers() -> Array:
	var result: Array = []
	for carriage in carriages:
		result.append_array(carriage.passengers)
	return result


## 특정 ID의 승객이 탑승 중인지 확인한다.
func has_passenger(passenger_id: String) -> bool:
	for carriage in carriages:
		for p in carriage.passengers:
			if p.id == passenger_id:
				return true
	return false


## 현재 위치를 경로 진행 기반으로 반환한다.
func get_current_position() -> Vector2:
	if path_points.is_empty():
		return Vector2.ZERO
	
	if path_points.size() == 1:
		return path_points[0]
	
	# 전체 경로 길이 계산
	var total_length := 0.0
	for i in range(1, path_points.size()):
		total_length += path_points[i - 1].distance_to(path_points[i])
	
	if total_length <= 0.0:
		return path_points[0]
	
	var target_distance := path_progress
	var accumulated := 0.0
	
	for i in range(1, path_points.size()):
		var segment_length := path_points[i - 1].distance_to(path_points[i])
		if accumulated + segment_length >= target_distance:
			var t := (target_distance - accumulated) / segment_length if segment_length > 0.0 else 0.0
			return path_points[i - 1].lerp(path_points[i], t)
		accumulated += segment_length
	
	return path_points[-1]


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	var carriage_ids: Array[String] = []
	for c in carriages:
		carriage_ids.append(c.id)
	
	return {
		"id": id,
		"line_id": line_id,
		"carriage_ids": carriage_ids,
		"current_station_id": current_station_id,
		"target_station_id": target_station_id,
		"operation_state": OperationState.keys()[operation_state],
		"direction": direction,
		"progress": progress,
		"current_speed": current_speed,
		"path_progress": path_progress
	}
