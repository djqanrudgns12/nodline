## 맵 생성 서비스 (Map Generator)
## PRD 6.6 참조
## 시드 기반으로 지형(강/산)과 역을 배치한다.
## 맵 생성 순서: 영역 → 강 → 산 → 역 위치 → 거리 검사 → 모양 → 색 → 유효성
class_name MapGenerator
extends RefCounted

var _game_state: GameStateRepository
var _terrain_checker: TerrainChecker
var _rng: RandomNumberGenerator


func _init(game_state: GameStateRepository, terrain_checker: TerrainChecker) -> void:
	_game_state = game_state
	_terrain_checker = terrain_checker
	_rng = RandomNumberGenerator.new()


## 시드 기반으로 맵을 생성한다.
## 반환: {success: bool, message: String}
func generate(seed_value: int) -> Dictionary:
	_rng.seed = seed_value
	_game_state.seed_value = seed_value
	
	var balance := GameConfig.balance
	
	# 1. 플레이 가능 영역 확인
	var play_area := Rect2(
		Vector2(balance.play_area_margin, balance.play_area_margin),
		Vector2(balance.play_area_width, balance.play_area_height)
	)
	
	# 2. 강 생성
	_generate_rivers(play_area)
	
	# 3. 산 생성
	_generate_mountains(play_area)
	
	# 4~7. 초기 3개 역 생성 (다리/터널 없이 서로 연결 가능한 위치에 배치)
	var station_result := _generate_initial_stations(play_area)
	if not station_result.success:
		return station_result
	
	# 8. 유효성 검사: 최소 3개 역, 각 모양 1개 이상
	var validation := _validate_map()
	if not validation.success:
		return validation
	
	GameLogger.log_info("MAP", "맵 생성 완료. 시드: %d, 역: %d개, 지형: %d개" % [
		seed_value, _game_state.stations.size(), _game_state.terrains.size()
	])
	
	return {"success": true, "message": "맵 생성 완료"}


## 강 생성 — 플레이 영역을 가로지르는 곡선형 강
func _generate_rivers(play_area: Rect2) -> void:
	# 1개의 강을 생성 (왼쪽에서 오른쪽으로 흐르는 형태)
	var river_points := PackedVector2Array()
	var start_y := _rng.randf_range(play_area.position.y + play_area.size.y * 0.3, play_area.position.y + play_area.size.y * 0.7)
	var river_width := _rng.randf_range(40.0, 70.0)
	
	var segments := 8
	var segment_width := play_area.size.x / segments
	
	# 상단 경계선
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	
	var current_y := start_y
	for i in range(segments + 1):
		var x := play_area.position.x + segment_width * i
		if i > 0 and i < segments:
			current_y += _rng.randf_range(-80.0, 80.0)
			current_y = clampf(current_y, play_area.position.y + 50.0, play_area.position.y + play_area.size.y - 50.0)
		
		top_points.append(Vector2(x, current_y - river_width * 0.5))
		bottom_points.append(Vector2(x, current_y + river_width * 0.5))
	
	# 폴리곤 구성 (상단 → 하단 역순)
	for p in top_points:
		river_points.append(p)
	for i in range(bottom_points.size() - 1, -1, -1):
		river_points.append(bottom_points[i])
	
	var river := TerrainEntity.new(
		_game_state.generate_id("terrain"),
		TerrainEntity.TerrainType.RIVER,
		river_points
	)
	_game_state.add_terrain(river)


## 산 생성 — 불규칙한 타원형 산
func _generate_mountains(play_area: Rect2) -> void:
	# 1~2개의 산을 생성
	var mountain_count := _rng.randi_range(1, 2)
	
	for _m in range(mountain_count):
		var center := Vector2(
			_rng.randf_range(play_area.position.x + 200.0, play_area.position.x + play_area.size.x - 200.0),
			_rng.randf_range(play_area.position.y + 150.0, play_area.position.y + play_area.size.y - 150.0)
		)
		
		var radius_x := _rng.randf_range(80.0, 160.0)
		var radius_y := _rng.randf_range(60.0, 120.0)
		var point_count := 12
		var polygon := PackedVector2Array()
		
		for i in range(point_count):
			var angle := (float(i) / point_count) * TAU
			var noise := _rng.randf_range(0.8, 1.2)
			var x := center.x + cos(angle) * radius_x * noise
			var y := center.y + sin(angle) * radius_y * noise
			polygon.append(Vector2(x, y))
		
		var mountain := TerrainEntity.new(
			_game_state.generate_id("terrain"),
			TerrainEntity.TerrainType.MOUNTAIN,
			polygon
		)
		_game_state.add_terrain(mountain)


## 초기 3개 역 생성 — 다리/터널 없이 서로 연결 가능한 위치에 배치
## 3개 역 모두 다른 형태(Circle, Triangle, Square)와 다른 색상을 100% 보장
func _generate_initial_stations(play_area: Rect2) -> Dictionary:
	var balance := GameConfig.balance
	var colors := balance.get_station_colors()
	var shapes: Array[StationEntity.Shape] = [
		StationEntity.Shape.CIRCLE,
		StationEntity.Shape.TRIANGLE,
		StationEntity.Shape.SQUARE
	]
	
	var best_positions: Array[Vector2] = []
	var max_group_attempts := 500
	
	for group_attempt in range(max_group_attempts):
		# 1. 첫 번째 역 위치 (기준점)
		var p0 := Vector2(
			_rng.randf_range(play_area.position.x + 120.0, play_area.position.x + play_area.size.x - 120.0),
			_rng.randf_range(play_area.position.y + 120.0, play_area.position.y + play_area.size.y - 120.0)
		)
		if _terrain_checker.is_point_on_terrain(p0):
			continue
		
		# 2. 두 번째 역 위치 탐색 (p0와의 연결 경로에 강/산 지형이 없어야 함)
		var p1 := Vector2.ZERO
		var found_p1 := false
		for attempt1 in range(50):
			var angle := _rng.randf_range(0, TAU)
			var dist := _rng.randf_range(balance.min_station_distance_px, balance.min_station_distance_px * 2.5)
			var candidate := p0 + Vector2(cos(angle), sin(angle)) * dist
			
			if not play_area.has_point(candidate):
				continue
			if _terrain_checker.is_point_on_terrain(candidate):
				continue
			
			var seg := _terrain_checker.check_segment(p0, candidate)
			if seg.result == TerrainEntity.TerrainCheckResult.CLEAR:
				p1 = candidate
				found_p1 = true
				break
		
		if not found_p1:
			continue
		
		# 3. 세 번째 역 위치 탐색 (p1 및 p0와의 연결 경로에 강/산 지형이 없어야 함)
		var p2 := Vector2.ZERO
		var found_p2 := false
		var fallback_p2 := Vector2.ZERO
		
		for attempt2 in range(80):
			var angle := _rng.randf_range(0, TAU)
			var dist := _rng.randf_range(balance.min_station_distance_px, balance.min_station_distance_px * 2.5)
			var candidate := p1 + Vector2(cos(angle), sin(angle)) * dist
			
			if not play_area.has_point(candidate):
				continue
			if candidate.distance_to(p0) < balance.min_station_distance_px:
				continue
			if _terrain_checker.is_point_on_terrain(candidate):
				continue
			
			var seg_1_2 := _terrain_checker.check_segment(p1, candidate)
			if seg_1_2.result == TerrainEntity.TerrainCheckResult.CLEAR:
				var seg_0_2 := _terrain_checker.check_segment(p0, candidate)
				if seg_0_2.result == TerrainEntity.TerrainCheckResult.CLEAR:
					# 3개 역 모두 상호 간에 지형 없이 직접 연결 가능 (삼각형 무장애)
					p2 = candidate
					found_p2 = true
					break
				elif fallback_p2 == Vector2.ZERO:
					# 최소한 p0-p1-p2 선형 연결은 지형 없이 가능
					fallback_p2 = candidate
		
		if found_p2:
			best_positions = [p0, p1, p2]
			break
		elif fallback_p2 != Vector2.ZERO and best_positions.is_empty():
			best_positions = [p0, p1, fallback_p2]
	
	# 만약 3개 위치를 찾지 못한 경우 강 북쪽/남쪽 안전 구역에서 무장애 삼각형 탐색
	if best_positions.size() < 3:
		for safe_attempt in range(100):
			var sub_y_start := play_area.position.y + 100.0
			var sub_y_end := play_area.position.y + play_area.size.y * 0.3
			var p0 := Vector2(_rng.randf_range(play_area.position.x + 150.0, play_area.position.x + play_area.size.x - 150.0), _rng.randf_range(sub_y_start, sub_y_end))
			if _terrain_checker.is_point_on_terrain(p0):
				continue
			var p1 := p0 + Vector2(_rng.randf_range(balance.min_station_distance_px, 250.0), _rng.randf_range(-40.0, 40.0))
			if not play_area.has_point(p1) or _terrain_checker.is_point_on_terrain(p1):
				continue
			var p2 := (p0 + p1) * 0.5 + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(balance.min_station_distance_px, 200.0))
			if not play_area.has_point(p2) or _terrain_checker.is_point_on_terrain(p2):
				continue
			if _terrain_checker.check_segment(p0, p1).result == TerrainEntity.TerrainCheckResult.CLEAR and \
			   _terrain_checker.check_segment(p1, p2).result == TerrainEntity.TerrainCheckResult.CLEAR and \
			   _terrain_checker.check_segment(p0, p2).result == TerrainEntity.TerrainCheckResult.CLEAR:
				best_positions = [p0, p1, p2]
				break
	
	if best_positions.size() < 3:
		return _generate_stations(play_area, 3)
	
	# 3개 역 색상이 모두 서로 다르도록 colors 목록을 셔플하여 고유하게 배정 (중복 색상 0%)
	var shuffled_colors: Array[Color] = colors.duplicate()
	for i in range(shuffled_colors.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := shuffled_colors[i]
		shuffled_colors[i] = shuffled_colors[j]
		shuffled_colors[j] = tmp
	
	# 역 엔티티 생성 및 등록 (모양 3종 각각 1개, 색상 3종 각각 1개 100% 보장)
	for i in range(3):
		var shape: StationEntity.Shape = shapes[i]
		var color: Color = shuffled_colors[i % shuffled_colors.size()]
		var station := StationEntity.new(
			_game_state.generate_id("station"),
			best_positions[i],
			shape,
			color
		)
		station.created_at_sim_time = 0.0
		_game_state.add_station(station)
		EventBus.station_created.emit(station.to_dict())
	
	return {"success": true, "message": ""}


## 일반 역 생성 — 지형 위에 겹치지 않게 배치 (신규 역 스폰 시 사용)
func _generate_stations(play_area: Rect2, count: int) -> Dictionary:
	var balance := GameConfig.balance
	var colors := balance.get_station_colors()
	
	var shapes: Array[StationEntity.Shape] = [
		StationEntity.Shape.CIRCLE,
		StationEntity.Shape.TRIANGLE,
		StationEntity.Shape.SQUARE
	]
	
	var max_attempts := 100
	var placed_positions: Array[Vector2] = []
	for existing in _game_state.get_all_stations():
		placed_positions.append(existing.position)
	
	for i in range(count):
		var position := Vector2.ZERO
		var valid := false
		
		for attempt in range(max_attempts):
			position = Vector2(
				_rng.randf_range(play_area.position.x + 80.0, play_area.position.x + play_area.size.x - 80.0),
				_rng.randf_range(play_area.position.y + 80.0, play_area.position.y + play_area.size.y - 80.0)
			)
			
			# 지형 위인지 확인
			if _terrain_checker.is_point_on_terrain(position):
				continue
			
			# 다른 역과의 최소 거리 확인
			var too_close := false
			for existing_pos in placed_positions:
				if position.distance_to(existing_pos) < balance.min_station_distance_px:
					too_close = true
					break
			
			if too_close:
				continue
			
			# 시작 자원(다리 1개, 터널 1개)을 감안하여, 다리 2개 이상 또는 터널 2개 이상 필요한 고립 배치는 차단
			# (기존 역 중 최소 1개 이상과 다리 <= 1, 터널 <= 1로 연결 가능해야 유효)
			if not placed_positions.is_empty():
				var has_accessible_connection := false
				for existing_pos in placed_positions:
					var seg := _terrain_checker.check_segment(existing_pos, position)
					var bridges: int = seg.get("bridge_count_needed", 0)
					var tunnels: int = seg.get("tunnel_count_needed", 0)
					if bridges <= balance.max_infrastructure_requirement_per_station and tunnels <= balance.max_infrastructure_requirement_per_station:
						has_accessible_connection = true
						break
				
				if not has_accessible_connection:
					continue
			
			valid = true
			break
		
		if not valid:
			return {"success": false, "message": "역 %d번째 배치 실패. 유효한 위치를 찾을 수 없습니다." % (i + 1)}
		
		placed_positions.append(position)
		
		var shape: StationEntity.Shape = shapes[_rng.randi() % shapes.size()]
		var color: Color = colors[_rng.randi() % colors.size()]
		
		var station := StationEntity.new(
			_game_state.generate_id("station"),
			position,
			shape,
			color
		)
		station.created_at_sim_time = _game_state.simulation_time
		_game_state.add_station(station)
		
		EventBus.station_created.emit(station.to_dict())
	
	return {"success": true, "message": ""}


## 신규 역 스폰 (게임 진행 중)
func spawn_new_station() -> Dictionary:
	var balance := GameConfig.balance
	
	if _game_state.stations.size() >= balance.max_station_count:
		return {"success": false, "message": "최대 역 수(%d)에 도달했습니다." % balance.max_station_count}
	
	var play_area := Rect2(
		Vector2(balance.play_area_margin, balance.play_area_margin),
		Vector2(balance.play_area_width, balance.play_area_height)
	)
	
	var result := _generate_stations(play_area, 1)
	return result


## 맵 유효성 검사
func _validate_map() -> Dictionary:
	var stations := _game_state.get_all_stations()
	
	if stations.size() < 3:
		return {"success": false, "message": "맵에 최소 3개의 역이 필요합니다. 현재: %d개" % stations.size()}
	
	# 각 모양이 최소 1개 이상인지 확인
	var shape_counts := {
		StationEntity.Shape.CIRCLE: 0,
		StationEntity.Shape.TRIANGLE: 0,
		StationEntity.Shape.SQUARE: 0
	}
	
	for station in stations:
		shape_counts[station.shape] += 1
	
	for shape in shape_counts.keys():
		if shape_counts[shape] == 0:
			return {
				"success": false,
				"message": "%s 모양의 역이 없습니다. 각 모양 최소 1개가 필요합니다." % StationEntity.shape_name(shape)
			}
	
	return {"success": true, "message": ""}
