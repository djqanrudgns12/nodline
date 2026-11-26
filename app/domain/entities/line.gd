## 노선 엔티티 (Line)
## PRD 6.5 참조
## 역과 역 사이를 웨이포인트로 연결하는 폴리라인 기반 노선
class_name LineEntity
extends RefCounted

## 노선 색상 팔레트 (디자인 2: 노르딕 라이트 트랜짓 고대비 컬러)
const LINE_COLORS: Array[Color] = [
	Color("#15529E"),  # 코발트 블루 (1호선)
	Color("#D84315"),  # 코랄 크림슨 (2호선)
	Color("#2E7D32"),  # 포레스트 에메랄드 (3호선)
	Color("#6A1B9A"),  # 로열 바이올렛 (4호선)
	Color("#EF6C00"),  # 골든 앰버 (5호선)
	Color("#00695C"),  # 딥 틸 (6호선)
	Color("#C2185B"),  # 베리 마젠타 (7호선)
	Color("#B45309"),  # 웜 오커 (8호선)
]

var id: String
var name: String
var color: Color
var station_ids: Array[String] = []  # 경유 역 순서
var waypoints: Dictionary = {}       # Dictionary<String, Array[Vector2]> — "stationA_stationB" → [중간점들]
var is_paused: bool = false
var assigned_train_ids: Array[String] = []
var bridge_ids: Array[String] = []
var tunnel_ids: Array[String] = []
var created_at_sim_time: float = 0.0


func _init(p_id: String = "", p_name: String = "", p_color: Color = Color.WHITE) -> void:
	id = p_id
	name = p_name
	color = p_color


## 역을 노선 끝에 추가한다.
func add_station(station_id: String) -> void:
	if station_id not in station_ids:
		station_ids.append(station_id)


## 역을 노선에서 제거한다.
func remove_station(station_id: String) -> void:
	station_ids.erase(station_id)
	# 관련 웨이포인트 정리
	var keys_to_remove: Array[String] = []
	for key in waypoints.keys():
		if station_id in key:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		waypoints.erase(key)


## 두 역 사이의 웨이포인트를 설정한다.
func set_waypoints(station_a_id: String, station_b_id: String, points: Array[Vector2]) -> void:
	var key := _make_waypoint_key(station_a_id, station_b_id)
	waypoints[key] = points


## 두 역 사이의 웨이포인트를 반환한다.
func get_waypoints(station_a_id: String, station_b_id: String) -> Array[Vector2]:
	var key := _make_waypoint_key(station_a_id, station_b_id)
	if key in waypoints:
		return waypoints[key]
	# 역순 키도 확인
	var reverse_key := _make_waypoint_key(station_b_id, station_a_id)
	if reverse_key in waypoints:
		var reversed: Array[Vector2] = []
		var original: Array = waypoints[reverse_key]
		for i in range(original.size() - 1, -1, -1):
			reversed.append(original[i])
		return reversed
	return []


## 노선에 포함된 역 수를 반환한다.
func get_station_count() -> int:
	return station_ids.size()


## 노선이 특정 역을 포함하는지 확인한다.
func has_station(station_id: String) -> bool:
	return station_id in station_ids


## 다음 역을 반환한다 (왕복 운행).
## direction: 1 = 정방향, -1 = 역방향
func get_next_station_id(current_station_id: String, direction: int) -> Dictionary:
	var idx := station_ids.find(current_station_id)
	if idx == -1:
		return {"station_id": "", "direction": direction}
	
	var next_idx := idx + direction
	var new_direction := direction
	
	# 끝에 도달하면 방향 전환
	if next_idx >= station_ids.size():
		new_direction = -1
		next_idx = idx - 1
	elif next_idx < 0:
		new_direction = 1
		next_idx = idx + 1
	
	# 역이 2개 미만이면 이동 불가
	if next_idx < 0 or next_idx >= station_ids.size():
		return {"station_id": current_station_id, "direction": new_direction}
	
	return {"station_id": station_ids[next_idx], "direction": new_direction}


## 두 역 사이의 전체 경로 포인트를 반환한다 (역 위치 + 웨이포인트).
func get_path_points(from_station_id: String, to_station_id: String, station_positions: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	if from_station_id in station_positions:
		points.append(station_positions[from_station_id])
	
	var wps := get_waypoints(from_station_id, to_station_id)
	points.append_array(wps)
	
	if to_station_id in station_positions:
		points.append(station_positions[to_station_id])
	
	return points


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	var wp_dict := {}
	for key in waypoints.keys():
		var point_dicts: Array = []
		for p in waypoints[key]:
			point_dicts.append({"x": p.x, "y": p.y})
		wp_dict[key] = point_dicts
	
	return {
		"id": id,
		"name": name,
		"color": "#" + color.to_html(false),
		"station_ids": station_ids.duplicate(),
		"waypoints": wp_dict,
		"is_paused": is_paused,
		"assigned_train_ids": assigned_train_ids.duplicate(),
		"bridge_ids": bridge_ids.duplicate(),
		"tunnel_ids": tunnel_ids.duplicate(),
		"created_at_sim_time": created_at_sim_time
	}


func _make_waypoint_key(a: String, b: String) -> String:
	return a + "_" + b
