## 노선 생성 및 연장 유즈케이스
## PRD 6.5 참조
## 노선 생성/연장 흐름: 역 선택 → 드래그 → 미리보기 → 지형 검사 → 연결 가능 여부 확인 → 노선 연장 또는 생성 → 확정
class_name CreateLineUseCase
extends RefCounted

var _game_state: GameStateRepository
var _terrain_checker: TerrainChecker
var _network_graph: NetworkGraph
var _undo_redo: UndoRedoSystem


func _init(
	game_state: GameStateRepository,
	terrain_checker: TerrainChecker,
	network_graph: NetworkGraph,
	undo_redo: UndoRedoSystem
) -> void:
	_game_state = game_state
	_terrain_checker = terrain_checker
	_network_graph = network_graph
	_undo_redo = undo_redo


## 두 역 사이에 노선을 생성하거나 기존 노선을 연장한다.
## 반환: {success: bool, line_id: String, message: String, needs_bridge: bool, needs_tunnel: bool, is_extension: bool}
func execute(from_station_id: String, to_station_id: String, waypoints: Array[Vector2] = []) -> Dictionary:
	var balance := GameConfig.balance
	
	# 역 존재 확인
	var from_station := _game_state.get_station(from_station_id)
	var to_station := _game_state.get_station(to_station_id)
	
	if from_station == null or to_station == null:
		return _error("역을 찾을 수 없습니다.")
	
	if from_station_id == to_station_id:
		return _error("같은 역끼리는 연결할 수 없습니다.")
	
	# 이미 두 역이 직접 인접하여 연결되어 있는지 확인
	for line in _game_state.get_all_lines():
		var s_ids: Array[String] = line.station_ids
		for i in range(s_ids.size() - 1):
			if (s_ids[i] == from_station_id and s_ids[i + 1] == to_station_id) or \
			   (s_ids[i] == to_station_id and s_ids[i + 1] == from_station_id):
				return _error("이미 연결되어 있는 역입니다.")
		# 같은 노선에 둘 다 이미 포함되어 있는 경우
		if line.has_station(from_station_id) and line.has_station(to_station_id):
			# 양 끝점을 잇는 순환선(Loop) 연결인지 확인
			var is_loop_closure := false
			if line.station_ids.size() >= 3:
				var front_id: String = line.station_ids[0]
				var back_id: String = line.station_ids[-1]
				if (from_station_id == front_id and to_station_id == back_id) or \
				   (from_station_id == back_id and to_station_id == front_id):
					is_loop_closure = true
			if not is_loop_closure:
				return _error("이미 '%s' 노선에 함께 포함되어 있는 역입니다." % line.name)
	
	# 경로 구성 (역 위치 + 웨이포인트)
	var path_points: Array[Vector2] = [from_station.position]
	path_points.append_array(waypoints)
	path_points.append(to_station.position)
	
	# 지형 검사
	var terrain_result := _terrain_checker.check_polyline(path_points)
	
	# 다리/터널 필요 여부 확인
	if terrain_result.needs_bridge:
		if _game_state.available_bridges < terrain_result.bridge_count_needed:
			return _error("다리가 부족합니다. 필요: %d개, 보유: %d개. 현재 경로가 강을 통과합니다." % [
				terrain_result.bridge_count_needed, _game_state.available_bridges
			])
	
	if terrain_result.needs_tunnel:
		if _game_state.available_tunnels < terrain_result.tunnel_count_needed:
			return _error("터널이 부족합니다. 필요: %d개, 보유: %d개. 현재 경로가 산을 통과합니다." % [
				terrain_result.tunnel_count_needed, _game_state.available_tunnels
			])
	
	# 기존 노선 연장 가능 여부 확인
	# from_station 또는 to_station이 기존 노선의 끝점이고, 상대 역은 해당 노선에 없는 경우
	var candidate_line: LineEntity = null
	var extend_station: StationEntity = null
	var is_front: bool = false
	
	for line in _game_state.get_all_lines():
		if line.station_ids.is_empty():
			continue
		var front_id: String = line.station_ids[0]
		var back_id: String = line.station_ids[-1]
		
		if back_id == from_station_id and not line.has_station(to_station_id):
			candidate_line = line
			extend_station = to_station
			is_front = false
			break
		elif front_id == from_station_id and not line.has_station(to_station_id):
			candidate_line = line
			extend_station = to_station
			is_front = true
			break
		elif back_id == to_station_id and not line.has_station(from_station_id):
			candidate_line = line
			extend_station = from_station
			is_front = false
			break
		elif front_id == to_station_id and not line.has_station(from_station_id):
			candidate_line = line
			extend_station = from_station
			is_front = true
			break
	
	# ----------------------------------------------------
	# 1. 기존 노선 연장 처리
	# ----------------------------------------------------
	if candidate_line != null:
		var ext_check := LineConnectionRule.can_connect(extend_station, candidate_line.id, balance.max_lines_per_station)
		if not ext_check.valid:
			EventBus.line_connection_rejected.emit(extend_station.id, ext_check.reason)
			return _error(ext_check.reason)
		
		# 다리 건설
		var built_bridges: Array = []
		if terrain_result.needs_bridge:
			for river_terrain in terrain_result.river_terrains:
				var bridge_pos := _terrain_checker.get_intersection_center(
					from_station.position, to_station.position, river_terrain
				)
				var bridge := BridgeEntity.new(
					_game_state.generate_id("bridge"),
					candidate_line.id,
					from_station_id,
					to_station_id,
					bridge_pos,
					river_terrain.id
				)
				_game_state.add_bridge(bridge)
				_game_state.available_bridges -= 1
				candidate_line.bridge_ids.append(bridge.id)
				built_bridges.append(bridge)
				EventBus.bridge_built.emit(bridge.to_dict())
		
		# 터널 건설
		var built_tunnels: Array = []
		if terrain_result.needs_tunnel:
			for mountain_terrain in terrain_result.mountain_terrains:
				var tunnel_pos := _terrain_checker.get_intersection_center(
					from_station.position, to_station.position, mountain_terrain
				)
				var tunnel := TunnelEntity.new(
					_game_state.generate_id("tunnel"),
					candidate_line.id,
					from_station_id,
					to_station_id,
					tunnel_pos,
					mountain_terrain.id
				)
				_game_state.add_tunnel(tunnel)
				_game_state.available_tunnels -= 1
				candidate_line.tunnel_ids.append(tunnel.id)
				built_tunnels.append(tunnel)
				EventBus.tunnel_built.emit(tunnel.to_dict())
		
		# 노선에 역 추가
		if is_front:
			candidate_line.station_ids.push_front(extend_station.id)
		else:
			candidate_line.station_ids.append(extend_station.id)
		
		var wp_key := candidate_line._make_waypoint_key(from_station_id, to_station_id)
		if not waypoints.is_empty():
			candidate_line.set_waypoints(from_station_id, to_station_id, waypoints)
		
		extend_station.add_line_connection(candidate_line.id, balance.max_lines_per_station)
		
		# 그래프 갱신
		_network_graph.rebuild()
		
		# Undo 명령 등록
		var ext_cmd := _ExtendLineCommand.new(
			_game_state, _network_graph, candidate_line, extend_station,
			is_front, built_bridges, built_tunnels, balance,
			wp_key if not waypoints.is_empty() else "", waypoints
		)
		ext_cmd.description = "%s 연장: %s" % [candidate_line.name, extend_station.id]
		_undo_redo._undo_stack.append(ext_cmd)
		_undo_redo._redo_stack.clear()
		
		EventBus.line_modified.emit(candidate_line.id)
		GameLogger.log_info("LINE", "노선 연장: %s (역 %s 추가, 총 %d개 역)" % [
			candidate_line.name, extend_station.id, candidate_line.station_ids.size()
		])
		
		return {
			"success": true,
			"line_id": candidate_line.id,
			"message": "%s 노선이 연장되었습니다. (총 %d개 역)" % [candidate_line.name, candidate_line.station_ids.size()],
			"needs_bridge": terrain_result.needs_bridge,
			"needs_tunnel": terrain_result.needs_tunnel,
			"is_extension": true
		}
	
	# ----------------------------------------------------
	# 2. 신규 노선 생성 처리
	# ----------------------------------------------------
	# 최대 노선 슬롯 수 확인
	if _game_state.lines.size() >= balance.initial_lines:
		return _error("최대 노선 수(%d개)에 도달했습니다. 새로운 노선을 생성할 수 없습니다." % balance.initial_lines)
	
	var line_id := _game_state.generate_id("line")
	
	var from_check := LineConnectionRule.can_connect(from_station, line_id, balance.max_lines_per_station)
	if not from_check.valid:
		EventBus.line_connection_rejected.emit(from_station_id, from_check.reason)
		return _error(from_check.reason)
	
	var to_check := LineConnectionRule.can_connect(to_station, line_id, balance.max_lines_per_station)
	if not to_check.valid:
		EventBus.line_connection_rejected.emit(to_station_id, to_check.reason)
		return _error(to_check.reason)
	
	# 노선 색상 결정
	var line_index := _game_state.lines.size()
	var line_color: Color = LineEntity.LINE_COLORS[line_index % LineEntity.LINE_COLORS.size()]
	
	# 노선 생성
	var line := LineEntity.new(line_id, "노선 %d" % (line_index + 1), line_color)
	line.add_station(from_station_id)
	line.add_station(to_station_id)
	line.set_waypoints(from_station_id, to_station_id, waypoints)
	line.created_at_sim_time = _game_state.simulation_time
	
	# 다리 건설
	var built_bridges: Array = []
	if terrain_result.needs_bridge:
		for river_terrain in terrain_result.river_terrains:
			var bridge_pos := _terrain_checker.get_intersection_center(
				from_station.position, to_station.position, river_terrain
			)
			var bridge := BridgeEntity.new(
				_game_state.generate_id("bridge"),
				line_id,
				from_station_id,
				to_station_id,
				bridge_pos,
				river_terrain.id
			)
			_game_state.add_bridge(bridge)
			_game_state.available_bridges -= 1
			line.bridge_ids.append(bridge.id)
			built_bridges.append(bridge)
			EventBus.bridge_built.emit(bridge.to_dict())
	
	# 터널 건설
	var built_tunnels: Array = []
	if terrain_result.needs_tunnel:
		for mountain_terrain in terrain_result.mountain_terrains:
			var tunnel_pos := _terrain_checker.get_intersection_center(
				from_station.position, to_station.position, mountain_terrain
			)
			var tunnel := TunnelEntity.new(
				_game_state.generate_id("tunnel"),
				line_id,
				from_station_id,
				to_station_id,
				tunnel_pos,
				mountain_terrain.id
			)
			_game_state.add_tunnel(tunnel)
			_game_state.available_tunnels -= 1
			line.tunnel_ids.append(tunnel.id)
			built_tunnels.append(tunnel)
			EventBus.tunnel_built.emit(tunnel.to_dict())
	
	# 저장소에 추가
	_game_state.add_line(line)
	from_station.add_line_connection(line_id, balance.max_lines_per_station)
	to_station.add_line_connection(line_id, balance.max_lines_per_station)
	
	# 그래프 갱신
	_network_graph.rebuild()
	
	# Undo 명령 등록
	var cmd := _CreateLineCommand.new(
		_game_state, _network_graph, line, from_station, to_station,
		built_bridges, built_tunnels, balance
	)
	cmd.description = "노선 생성: %s" % line.name
	_undo_redo._undo_stack.append(cmd)  # execute는 이미 완료
	_undo_redo._redo_stack.clear()
	
	EventBus.line_created.emit(line.to_dict())
	GameLogger.log_info("LINE", "신규 노선 생성: %s (%s → %s)" % [line.name, from_station_id, to_station_id])
	
	return {
		"success": true,
		"line_id": line_id,
		"message": "새 노선(%s)을 생성했습니다." % line.name,
		"needs_bridge": terrain_result.needs_bridge,
		"needs_tunnel": terrain_result.needs_tunnel,
		"is_extension": false
	}


func _error(message: String) -> Dictionary:
	return {
		"success": false,
		"line_id": "",
		"message": message,
		"needs_bridge": false,
		"needs_tunnel": false,
		"is_extension": false
	}


## Undo/Redo용 노선 생성 명령 클래스
class _CreateLineCommand extends UndoRedoSystem.Command:
	var _game_state: GameStateRepository
	var _network_graph: NetworkGraph
	var _line: LineEntity
	var _from_station: StationEntity
	var _to_station: StationEntity
	var _bridges: Array
	var _tunnels: Array
	var _balance: GameBalanceConfig
	
	func _init(gs, ng, ln, fs, ts, br, tn, bal) -> void:
		_game_state = gs
		_network_graph = ng
		_line = ln
		_from_station = fs
		_to_station = ts
		_bridges = br
		_tunnels = tn
		_balance = bal
	
	func execute() -> void:
		_game_state.add_line(_line)
		_from_station.add_line_connection(_line.id, _balance.max_lines_per_station)
		_to_station.add_line_connection(_line.id, _balance.max_lines_per_station)
		for b in _bridges:
			_game_state.add_bridge(b)
			_game_state.available_bridges -= 1
		for t in _tunnels:
			_game_state.add_tunnel(t)
			_game_state.available_tunnels -= 1
		_network_graph.rebuild()
		EventBus.line_created.emit(_line.to_dict())
	
	func undo() -> void:
		for train_id in _line.assigned_train_ids:
			var train := _game_state.get_train(train_id)
			if train:
				train.operation_state = TrainEntity.OperationState.IDLE
				train.line_id = ""
				_game_state.available_trains += 1
		
		_from_station.remove_line_connection(_line.id)
		_to_station.remove_line_connection(_line.id)
		
		for b in _bridges:
			_game_state.remove_bridge(b.id)
			_game_state.available_bridges += 1
		for t in _tunnels:
			_game_state.remove_tunnel(t.id)
			_game_state.available_tunnels += 1
		
		_game_state.remove_line(_line.id)
		_network_graph.rebuild()
		EventBus.line_deleted.emit(_line.id)


## Undo/Redo용 노선 연장 명령 클래스
class _ExtendLineCommand extends UndoRedoSystem.Command:
	var _game_state: GameStateRepository
	var _network_graph: NetworkGraph
	var _line: LineEntity
	var _station: StationEntity
	var _is_front: bool
	var _bridges: Array
	var _tunnels: Array
	var _balance: GameBalanceConfig
	var _waypoints_key: String
	var _waypoints: Array[Vector2]
	
	func _init(gs, ng, ln, st, is_front: bool, br, tn, bal, wp_key: String, wps: Array[Vector2]) -> void:
		_game_state = gs
		_network_graph = ng
		_line = ln
		_station = st
		_is_front = is_front
		_bridges = br
		_tunnels = tn
		_balance = bal
		_waypoints_key = wp_key
		_waypoints = wps
	
	func execute() -> void:
		if _is_front:
			_line.station_ids.push_front(_station.id)
		else:
			_line.station_ids.append(_station.id)
		if not _waypoints_key.is_empty():
			_line.waypoints[_waypoints_key] = _waypoints
		_station.add_line_connection(_line.id, _balance.max_lines_per_station)
		for b in _bridges:
			_game_state.add_bridge(b)
			_game_state.available_bridges -= 1
		for t in _tunnels:
			_game_state.add_tunnel(t)
			_game_state.available_tunnels -= 1
		_network_graph.rebuild()
		EventBus.line_modified.emit(_line.id)
	
	func undo() -> void:
		_station.remove_line_connection(_line.id)
		if _is_front:
			if _line.station_ids.size() > 0 and _line.station_ids[0] == _station.id:
				_line.station_ids.pop_front()
		else:
			if _line.station_ids.size() > 0 and _line.station_ids[-1] == _station.id:
				_line.station_ids.pop_back()
		if not _waypoints_key.is_empty():
			_line.waypoints.erase(_waypoints_key)
		for b in _bridges:
			_game_state.remove_bridge(b.id)
			_game_state.available_bridges += 1
		for t in _tunnels:
			_game_state.remove_tunnel(t.id)
			_game_state.available_tunnels += 1
		_network_graph.rebuild()
		EventBus.line_modified.emit(_line.id)
