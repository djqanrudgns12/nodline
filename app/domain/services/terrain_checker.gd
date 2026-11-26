## 지형 검사 서비스 (Terrain Checker)
## PRD 6.5 참조
## 노선 구간이 지형(강/산)을 통과하는지 폴리곤 기하학으로 판정한다.
## 픽셀 색으로 추측하지 않고 실제 기하학 데이터로 판정한다.
class_name TerrainChecker
extends RefCounted

var _game_state: GameStateRepository


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 두 점 사이의 지형 판정 결과를 반환한다.
func check_segment(from: Vector2, to: Vector2) -> Dictionary:
	var hits_river := false
	var hits_mountain := false
	var river_terrains: Array = []
	var mountain_terrains: Array = []
	
	for terrain in _game_state.get_all_terrains():
		if terrain.intersects_segment(from, to):
			match terrain.terrain_type:
				TerrainEntity.TerrainType.RIVER:
					hits_river = true
					river_terrains.append(terrain)
				TerrainEntity.TerrainType.MOUNTAIN:
					hits_mountain = true
					mountain_terrains.append(terrain)
	
	var result: TerrainEntity.TerrainCheckResult
	if hits_river and hits_mountain:
		result = TerrainEntity.TerrainCheckResult.RIVER_AND_MOUNTAIN
	elif hits_river:
		result = TerrainEntity.TerrainCheckResult.RIVER
	elif hits_mountain:
		result = TerrainEntity.TerrainCheckResult.MOUNTAIN
	else:
		result = TerrainEntity.TerrainCheckResult.CLEAR
	
	return {
		"result": result,
		"hits_river": hits_river,
		"hits_mountain": hits_mountain,
		"river_terrains": river_terrains,
		"mountain_terrains": mountain_terrains,
		"needs_bridge": hits_river,
		"needs_tunnel": hits_mountain,
		"bridge_count_needed": river_terrains.size(),
		"tunnel_count_needed": mountain_terrains.size()
	}


## 폴리라인(웨이포인트 포함) 경로의 지형 판정 결과를 반환한다.
func check_polyline(points: Array[Vector2]) -> Dictionary:
	var total_hits_river := false
	var total_hits_mountain := false
	var all_river_terrains: Array = []
	var all_mountain_terrains: Array = []
	
	for i in range(points.size() - 1):
		var segment_result := check_segment(points[i], points[i + 1])
		if segment_result.hits_river:
			total_hits_river = true
			for t in segment_result.river_terrains:
				if t not in all_river_terrains:
					all_river_terrains.append(t)
		if segment_result.hits_mountain:
			total_hits_mountain = true
			for t in segment_result.mountain_terrains:
				if t not in all_mountain_terrains:
					all_mountain_terrains.append(t)
	
	var result: TerrainEntity.TerrainCheckResult
	if total_hits_river and total_hits_mountain:
		result = TerrainEntity.TerrainCheckResult.RIVER_AND_MOUNTAIN
	elif total_hits_river:
		result = TerrainEntity.TerrainCheckResult.RIVER
	elif total_hits_mountain:
		result = TerrainEntity.TerrainCheckResult.MOUNTAIN
	else:
		result = TerrainEntity.TerrainCheckResult.CLEAR
	
	return {
		"result": result,
		"hits_river": total_hits_river,
		"hits_mountain": total_hits_mountain,
		"river_terrains": all_river_terrains,
		"mountain_terrains": all_mountain_terrains,
		"needs_bridge": total_hits_river,
		"needs_tunnel": total_hits_mountain,
		"bridge_count_needed": all_river_terrains.size(),
		"tunnel_count_needed": all_mountain_terrains.size()
	}


## 특정 점이 지형 위에 있는지 확인한다 (역 배치용).
func is_point_on_terrain(point: Vector2) -> bool:
	for terrain in _game_state.get_all_terrains():
		if terrain.contains_point(point):
			return true
	return false


## 교차 지점의 중심 위치를 반환한다 (다리/터널 렌더링용).
func get_intersection_center(from: Vector2, to: Vector2, terrain: TerrainEntity) -> Vector2:
	var intersections: Array[Vector2] = []
	
	for i in range(terrain.polygon.size()):
		var j := (i + 1) % terrain.polygon.size()
		var result = Geometry2D.segment_intersects_segment(from, to, terrain.polygon[i], terrain.polygon[j])
		if result != null:
			intersections.append(result)
	
	if intersections.is_empty():
		return (from + to) * 0.5
	
	# 교차점들의 중심을 반환
	var center := Vector2.ZERO
	for p in intersections:
		center += p
	return center / intersections.size()
