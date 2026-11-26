## 객차 엔티티 (Carriage)
## PRD 6.4 참조
## 열차에 연결되어 승객을 수송하는 객차 (최대 5명)
class_name CarriageEntity
extends RefCounted

var id: String
var train_id: String
var passengers: Array = []  # Array of PassengerEntity


func _init(p_id: String = "", p_train_id: String = "") -> void:
	id = p_id
	train_id = p_train_id


## 탑승 가능 여부를 확인한다.
func can_board(max_passengers: int) -> bool:
	return passengers.size() < max_passengers


## 승객을 탑승시킨다. 성공 여부를 반환한다.
func board_passenger(passenger) -> bool:
	if passengers.size() >= GameConfig.balance.max_passengers_per_carriage:
		return false
	passengers.append(passenger)
	return true


## 승객 수를 반환한다.
func get_passenger_count() -> int:
	return passengers.size()


## 승객을 하차시킨다.
func remove_passenger(passenger) -> void:
	passengers.erase(passenger)


## 잔여 공간을 반환한다.
func get_remaining_space(max_passengers: int) -> int:
	return max_passengers - passengers.size()


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	var passenger_ids: Array[String] = []
	for p in passengers:
		passenger_ids.append(p.id)
	
	return {
		"id": id,
		"train_id": train_id,
		"passenger_ids": passenger_ids
	}
