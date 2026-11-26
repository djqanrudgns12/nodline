## 다리 엔티티 (Bridge)
## PRD 6.5 참조
## 강을 통과하는 노선 구간에 건설되는 다리
class_name BridgeEntity
extends RefCounted

var id: String
var line_id: String
var segment_from_station_id: String
var segment_to_station_id: String
var position: Vector2  # 강과 교차하는 위치 (렌더링용)
var terrain_id: String  # 통과하는 강의 ID


func _init(
	p_id: String = "",
	p_line_id: String = "",
	p_from: String = "",
	p_to: String = "",
	p_position: Vector2 = Vector2.ZERO,
	p_terrain_id: String = ""
) -> void:
	id = p_id
	line_id = p_line_id
	segment_from_station_id = p_from
	segment_to_station_id = p_to
	position = p_position
	terrain_id = p_terrain_id


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"line_id": line_id,
		"segment_from_station_id": segment_from_station_id,
		"segment_to_station_id": segment_to_station_id,
		"position": {"x": position.x, "y": position.y},
		"terrain_id": terrain_id
	}
