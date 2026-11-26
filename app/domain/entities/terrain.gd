## 지형 엔티티 (Terrain)
## PRD 6.5, 3.2 참조
## 강, 산 등 지형 장애물을 관리하는 데이터 클래스
## 게임 중 수정하지 않음(불변)
class_name TerrainEntity
extends RefCounted

## 지형 유형
enum TerrainType {
	RIVER,    # 강 — 다리 필요
	MOUNTAIN  # 산 — 터널 필요
}

## 지형 판정 결과
enum TerrainCheckResult {
	CLEAR,              # 통과 가능
	RIVER,              # 강 — 다리 필요
	MOUNTAIN,           # 산 — 터널 필요
	RIVER_AND_MOUNTAIN, # 강 + 산
	INVALID             # 잘못된 경로
}

var id: String
var terrain_type: TerrainType
var polygon: PackedVector2Array  # 지형 영역 폴리곤
var color: Color


func _init(p_id: String = "", p_type: TerrainType = TerrainType.RIVER, p_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	id = p_id
	terrain_type = p_type
	polygon = p_polygon
	
	match terrain_type:
		TerrainType.RIVER:
			color = Color("#1E3A5F")
		TerrainType.MOUNTAIN:
			color = Color("#2D3B2D")


## 특정 점이 이 지형 내부에 있는지 확인한다.
func contains_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


## 선분이 이 지형과 교차하는지 확인한다.
func intersects_segment(from: Vector2, to: Vector2) -> bool:
	if polygon.size() < 3:
		return false
	
	# 점이 폴리곤 내부에 있으면 교차
	if contains_point(from) or contains_point(to):
		return true
	
	# 선분과 폴리곤 변의 교차 검사
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var intersection = Geometry2D.segment_intersects_segment(from, to, polygon[i], polygon[j])
		if intersection != null:
			return true
	
	return false


## 폴리라인이 이 지형과 교차하는지 확인한다.
func intersects_polyline(points: Array[Vector2]) -> bool:
	for i in range(points.size() - 1):
		if intersects_segment(points[i], points[i + 1]):
			return true
	return false


## 직렬화 (저장용)
func to_dict() -> Dictionary:
	var poly_array: Array = []
	for p in polygon:
		poly_array.append({"x": p.x, "y": p.y})
	
	return {
		"id": id,
		"terrain_type": TerrainType.keys()[terrain_type],
		"polygon": poly_array
	}
