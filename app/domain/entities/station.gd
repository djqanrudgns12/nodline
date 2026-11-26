## 역 엔티티 (Station)
## PRD 6.2 참조
## UI를 참조하지 않는 순수 데이터 클래스
class_name StationEntity
extends RefCounted

## 역 모양 열거
enum Shape {
	CIRCLE,
	TRIANGLE,
	SQUARE
}

## 역 혼잡 상태
enum CongestionState {
	NORMAL,   # 0~11명
	WARNING,  # 12~13명
	DANGER,   # 14명
	GAME_OVER # >= 15명
}

var id: String
var position: Vector2
var shape: Shape
var color: Color
var waiting_passengers: Array = []  # Array of PassengerEntity
var connected_line_ids: Array[String] = []
var congestion_state: CongestionState = CongestionState.NORMAL
var created_at_sim_time: float = 0.0


func _init(p_id: String = "", p_position: Vector2 = Vector2.ZERO, p_shape: Shape = Shape.CIRCLE, p_color: Color = Color.WHITE) -> void:
	id = p_id
	position = p_position
	shape = p_shape
	color = p_color


## 대기 승객 수를 반환한다.
func get_passenger_count() -> int:
	return waiting_passengers.size()


## 노선 연결 가능 여부를 검사한다.
func can_connect_line(max_lines: int) -> bool:
	return connected_line_ids.size() < max_lines


## 노선 연결을 추가한다. 성공 여부를 반환한다.
func add_line_connection(line_id: String, max_lines: int) -> bool:
	if not can_connect_line(max_lines):
		return false
	if line_id in connected_line_ids:
		return false
	connected_line_ids.append(line_id)
	return true


## 노선 연결을 제거한다.
func remove_line_connection(line_id: String) -> void:
	connected_line_ids.erase(line_id)


## 승객을 대기열에 추가한다.
func add_passenger(passenger) -> void:
	waiting_passengers.append(passenger)


## 승객을 대기열에서 제거한다.
func remove_passenger(passenger) -> void:
	waiting_passengers.erase(passenger)


## 혼잡도 상태를 업데이트하고 반환한다.
func update_congestion_state(warning_threshold: int, danger_threshold: int, max_passengers: int) -> CongestionState:
	var count := get_passenger_count()
	var old_state := congestion_state
	
	if count >= max_passengers:
		congestion_state = CongestionState.GAME_OVER
	elif count >= danger_threshold:
		congestion_state = CongestionState.DANGER
	elif count >= warning_threshold:
		congestion_state = CongestionState.WARNING
	else:
		congestion_state = CongestionState.NORMAL
	
	return congestion_state


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	var passenger_ids: Array[String] = []
	for p in waiting_passengers:
		passenger_ids.append(p.id)
	
	return {
		"id": id,
		"position": {"x": position.x, "y": position.y},
		"shape": Shape.keys()[shape],
		"color": "#" + color.to_html(false),
		"waiting_passenger_ids": passenger_ids,
		"connected_line_ids": connected_line_ids.duplicate(),
		"congestion_state": CongestionState.keys()[congestion_state],
		"created_at_sim_time": created_at_sim_time
	}


## 역 모양 이름을 반환한다.
static func shape_name(s: Shape) -> String:
	match s:
		Shape.CIRCLE: return "원"
		Shape.TRIANGLE: return "삼각형"
		Shape.SQUARE: return "사각형"
		_: return "알 수 없음"
