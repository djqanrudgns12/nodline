## 승객 엔티티 (Passenger)
## PRD 6.3 참조
## 순수 데이터 클래스 — UI를 참조하지 않는다.
class_name PassengerEntity
extends RefCounted

## 승객 상태
enum State {
	WAITING,          # 역에서 대기 중
	BOARDING,         # 열차에 탑승 중 (애니메이션)
	ON_TRAIN,         # 열차 안
	TRANSFER_WAITING, # 환승 대기
	ALIGHTING,        # 하차 중 (애니메이션)
	ARRIVED           # 목적지 도착
}

var id: String
var origin_station_id: String
var destination_station_id: String
var destination_shape: StationEntity.Shape
var destination_color: Color
var current_station_id: String
var current_train_id: String
var state: State = State.WAITING
var spawned_at_sim_time: float = 0.0
var waiting_time: float = 0.0


func _init(
	p_id: String = "",
	p_origin_id: String = "",
	p_dest_id: String = "",
	p_dest_shape: StationEntity.Shape = StationEntity.Shape.CIRCLE,
	p_dest_color: Color = Color.WHITE
) -> void:
	id = p_id
	origin_station_id = p_origin_id
	destination_station_id = p_dest_id
	destination_shape = p_dest_shape
	destination_color = p_dest_color
	current_station_id = p_origin_id


## 목적지에 도착했는지 확인한다.
func has_arrived_at_destination(station_id: String) -> bool:
	return station_id == destination_station_id


## 열차에 탑승한다.
func board_train(train_id: String) -> void:
	state = State.BOARDING
	current_train_id = train_id
	current_station_id = ""


## 탑승 완료 (애니메이션 후 호출)
func complete_boarding() -> void:
	state = State.ON_TRAIN


## 하차한다.
func alight_at_station(station_id: String) -> void:
	state = State.ALIGHTING
	current_station_id = station_id
	current_train_id = ""


## 하차 완료 (목적지 도착)
func complete_arrival() -> void:
	state = State.ARRIVED


## 환승 대기 상태로 변경한다.
func start_transfer(station_id: String) -> void:
	state = State.TRANSFER_WAITING
	current_station_id = station_id
	current_train_id = ""


## 환승 대기에서 일반 대기로 전환한다.
func complete_transfer() -> void:
	state = State.WAITING


## 대기 시간을 증가시킨다.
func accumulate_wait_time(delta: float) -> void:
	if state == State.WAITING or state == State.TRANSFER_WAITING:
		waiting_time += delta


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"origin_station_id": origin_station_id,
		"destination_station_id": destination_station_id,
		"destination_shape": StationEntity.Shape.keys()[destination_shape],
		"destination_color": "#" + destination_color.to_html(false),
		"current_station_id": current_station_id,
		"current_train_id": current_train_id,
		"state": State.keys()[state],
		"spawned_at_sim_time": spawned_at_sim_time,
		"waiting_time": waiting_time
	}
