## 탑승 규칙 (Boarding Rule)
## PRD 6.4 참조
## 객차당 최대 5명 탑승 제한을 강제한다.
class_name BoardingRule
extends RefCounted


## 객차 탑승 가능 여부를 검사한다.
static func can_board_carriage(carriage: CarriageEntity, max_passengers: int) -> Dictionary:
	if carriage.get_passenger_count() >= max_passengers:
		return {
			"valid": false,
			"reason": "객차가 가득 찼습니다. 현재 %d/%d명입니다." % [carriage.get_passenger_count(), max_passengers]
		}
	return {
		"valid": true,
		"reason": ""
	}


## 열차 탑승 가능 여부를 검사한다.
static func can_board_train(train: TrainEntity, max_per_carriage: int) -> Dictionary:
	if train.get_remaining_capacity(max_per_carriage) <= 0:
		return {
			"valid": false,
			"reason": "열차가 만석입니다. (%d/%d명)" % [train.get_total_passengers(), train.get_total_capacity(max_per_carriage)]
		}
	return {
		"valid": true,
		"reason": ""
	}
