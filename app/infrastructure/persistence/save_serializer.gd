## 직렬화/역직렬화 서비스 (Save Serializer)
## PRD 7장 참조
## 게임 상태를 Dictionary로 변환하고, Dictionary에서 복원한다.
## 필수 포함 데이터: 게임 버전, 스키마 버전, 맵 시드, 시뮬레이션 시간,
##   역, 노선, 열차, 승객, 다리, 터널, 자원
class_name SaveSerializer
extends RefCounted


## 게임 상태를 직렬화한다.
func serialize(game_state: GameStateRepository) -> Dictionary:
	var data := {}
	
	# 메타데이터
	data["seed"] = game_state.seed_value
	data["simulation_time"] = game_state.simulation_time
	data["game_day"] = game_state.game_day
	data["is_game_over"] = game_state.is_game_over
	data["total_arrived_passengers"] = game_state.total_arrived_passengers
	data["max_simultaneous_passengers"] = game_state.max_simultaneous_passengers
	data["speed_multiplier"] = game_state.speed_multiplier
	
	# 자원
	data["available_bridges"] = game_state.available_bridges
	data["available_tunnels"] = game_state.available_tunnels
	data["available_trains"] = game_state.available_trains
	data["available_carriages"] = game_state.available_carriages
	data["available_line_slots"] = game_state.available_line_slots
	
	# 역
	var stations_data: Array = []
	for station in game_state.stations.values():
		stations_data.append(station.to_dict())
	data["stations"] = stations_data
	
	# 승객
	var passengers_data: Array = []
	for passenger in game_state.passengers.values():
		passengers_data.append(passenger.to_dict())
	data["passengers"] = passengers_data
	
	# 노선
	var lines_data: Array = []
	for line in game_state.lines.values():
		lines_data.append(line.to_dict())
	data["lines"] = lines_data
	
	# 열차
	var trains_data: Array = []
	for train in game_state.trains.values():
		trains_data.append(train.to_dict())
	data["trains"] = trains_data
	
	# 객차
	var carriages_data: Array = []
	for carriage in game_state.carriages.values():
		carriages_data.append(carriage.to_dict())
	data["carriages"] = carriages_data
	
	# 지형
	var terrains_data: Array = []
	for terrain in game_state.terrains.values():
		terrains_data.append(terrain.to_dict())
	data["terrains"] = terrains_data
	
	# 다리
	var bridges_data: Array = []
	for bridge in game_state.bridges.values():
		bridges_data.append(bridge.to_dict())
	data["bridges"] = bridges_data
	
	# 터널
	var tunnels_data: Array = []
	for tunnel in game_state.tunnels.values():
		tunnels_data.append(tunnel.to_dict())
	data["tunnels"] = tunnels_data
	
	# ID 카운터
	data["id_counters"] = game_state._next_id_counters.duplicate()
	
	return data


## 게임 상태를 역직렬화한다.
func deserialize(data: Dictionary, game_state: GameStateRepository) -> Dictionary:
	game_state.clear()
	
	# 메타데이터
	game_state.seed_value = data.get("seed", 0)
	game_state.simulation_time = data.get("simulation_time", 0.0)
	game_state.game_day = data.get("game_day", 1)
	game_state.is_game_over = data.get("is_game_over", false)
	game_state.total_arrived_passengers = data.get("total_arrived_passengers", 0)
	game_state.max_simultaneous_passengers = data.get("max_simultaneous_passengers", 0)
	game_state.speed_multiplier = data.get("speed_multiplier", 1.0)
	
	# 자원
	game_state.available_bridges = data.get("available_bridges", 0)
	game_state.available_tunnels = data.get("available_tunnels", 0)
	game_state.available_trains = data.get("available_trains", 0)
	game_state.available_carriages = data.get("available_carriages", 0)
	game_state.available_line_slots = data.get("available_line_slots", 0)
	
	# ID 카운터
	var counters = data.get("id_counters", {})
	for key in counters:
		game_state._next_id_counters[key] = int(counters[key])
	
	# 지형 복원
	for t_data in data.get("terrains", []):
		var polygon := PackedVector2Array()
		for p in t_data.get("polygon", []):
			polygon.append(Vector2(p.get("x", 0), p.get("y", 0)))
		var terrain_type: TerrainEntity.TerrainType
		match t_data.get("terrain_type", "RIVER"):
			"RIVER": terrain_type = TerrainEntity.TerrainType.RIVER
			"MOUNTAIN": terrain_type = TerrainEntity.TerrainType.MOUNTAIN
		var terrain := TerrainEntity.new(t_data.get("id", ""), terrain_type, polygon)
		game_state.add_terrain(terrain)
	
	# 역 복원
	for s_data in data.get("stations", []):
		var shape: StationEntity.Shape
		match s_data.get("shape", "CIRCLE"):
			"CIRCLE": shape = StationEntity.Shape.CIRCLE
			"TRIANGLE": shape = StationEntity.Shape.TRIANGLE
			"SQUARE": shape = StationEntity.Shape.SQUARE
		var pos_data = s_data.get("position", {"x": 0, "y": 0})
		var station := StationEntity.new(
			s_data.get("id", ""),
			Vector2(pos_data.get("x", 0), pos_data.get("y", 0)),
			shape,
			Color.from_string(s_data.get("color", "#FFFFFF"), Color.WHITE)
		)
		station.connected_line_ids.assign(s_data.get("connected_line_ids", []))
		station.created_at_sim_time = s_data.get("created_at_sim_time", 0.0)
		var state_str: String = s_data.get("congestion_state", "NORMAL")
		match state_str:
			"NORMAL": station.congestion_state = StationEntity.CongestionState.NORMAL
			"WARNING": station.congestion_state = StationEntity.CongestionState.WARNING
			"DANGER": station.congestion_state = StationEntity.CongestionState.DANGER
			"GAME_OVER": station.congestion_state = StationEntity.CongestionState.GAME_OVER
		game_state.add_station(station)
	
	# 승객 복원
	for p_data in data.get("passengers", []):
		var dest_shape: StationEntity.Shape
		match p_data.get("destination_shape", "CIRCLE"):
			"CIRCLE": dest_shape = StationEntity.Shape.CIRCLE
			"TRIANGLE": dest_shape = StationEntity.Shape.TRIANGLE
			"SQUARE": dest_shape = StationEntity.Shape.SQUARE
		var passenger := PassengerEntity.new(
			p_data.get("id", ""),
			p_data.get("origin_station_id", ""),
			p_data.get("destination_station_id", ""),
			dest_shape,
			Color.from_string(p_data.get("destination_color", "#FFFFFF"), Color.WHITE)
		)
		passenger.current_station_id = p_data.get("current_station_id", "")
		passenger.current_train_id = p_data.get("current_train_id", "")
		passenger.spawned_at_sim_time = p_data.get("spawned_at_sim_time", 0.0)
		passenger.waiting_time = p_data.get("waiting_time", 0.0)
		var state_str: String = p_data.get("state", "WAITING")
		match state_str:
			"WAITING": passenger.state = PassengerEntity.State.WAITING
			"BOARDING": passenger.state = PassengerEntity.State.BOARDING
			"ON_TRAIN": passenger.state = PassengerEntity.State.ON_TRAIN
			"TRANSFER_WAITING": passenger.state = PassengerEntity.State.TRANSFER_WAITING
			"ALIGHTING": passenger.state = PassengerEntity.State.ALIGHTING
			"ARRIVED": passenger.state = PassengerEntity.State.ARRIVED
		game_state.add_passenger(passenger)
		
		# 역에 대기 승객 연결
		if passenger.current_station_id != "" and passenger.state in [PassengerEntity.State.WAITING, PassengerEntity.State.TRANSFER_WAITING]:
			var station := game_state.get_station(passenger.current_station_id)
			if station:
				station.add_passenger(passenger)
	
	# 객차 복원
	for c_data in data.get("carriages", []):
		var carriage := CarriageEntity.new(c_data.get("id", ""), c_data.get("train_id", ""))
		# 승객 연결은 열차 복원 후 처리
		game_state.add_carriage(carriage)
	
	# 노선 복원
	for l_data in data.get("lines", []):
		var line := LineEntity.new(
			l_data.get("id", ""),
			l_data.get("name", ""),
			Color.from_string(l_data.get("color", "#FFFFFF"), Color.WHITE)
		)
		for sid in l_data.get("station_ids", []):
			line.station_ids.append(sid)
		line.is_paused = l_data.get("is_paused", false)
		line.assigned_train_ids.assign(l_data.get("assigned_train_ids", []))
		line.bridge_ids.assign(l_data.get("bridge_ids", []))
		line.tunnel_ids.assign(l_data.get("tunnel_ids", []))
		line.created_at_sim_time = l_data.get("created_at_sim_time", 0.0)
		# 웨이포인트 복원
		var wp_data = l_data.get("waypoints", {})
		for key in wp_data:
			var points: Array[Vector2] = []
			for p in wp_data[key]:
				points.append(Vector2(p.get("x", 0), p.get("y", 0)))
			line.waypoints[key] = points
		game_state.add_line(line)
	
	# 열차 복원
	for tr_data in data.get("trains", []):
		var train := TrainEntity.new(tr_data.get("id", ""), tr_data.get("line_id", ""))
		train.current_station_id = tr_data.get("current_station_id", "")
		train.target_station_id = tr_data.get("target_station_id", "")
		train.direction = int(tr_data.get("direction", 1))
		train.progress = tr_data.get("progress", 0.0)
		train.current_speed = tr_data.get("current_speed", 0.0)
		train.path_progress = tr_data.get("path_progress", 0.0)
		var op_state_str: String = tr_data.get("operation_state", "IDLE")
		match op_state_str:
			"IDLE": train.operation_state = TrainEntity.OperationState.IDLE
			"MOVING": train.operation_state = TrainEntity.OperationState.MOVING
			"AT_STATION": train.operation_state = TrainEntity.OperationState.AT_STATION
			"PAUSED": train.operation_state = TrainEntity.OperationState.PAUSED
		# 객차 연결
		for c_id in tr_data.get("carriage_ids", []):
			var carriage := game_state.get_carriage(c_id)
			if carriage:
				train.carriages.append(carriage)
				# 객차 내 승객 연결
				for c_data_inner in data.get("carriages", []):
					if c_data_inner.get("id", "") == c_id:
						for p_id in c_data_inner.get("passenger_ids", []):
							var p := game_state.get_passenger(p_id)
							if p:
								carriage.passengers.append(p)
		game_state.add_train(train)
	
	# 다리 복원
	for b_data in data.get("bridges", []):
		var pos_data = b_data.get("position", {"x": 0, "y": 0})
		var bridge := BridgeEntity.new(
			b_data.get("id", ""),
			b_data.get("line_id", ""),
			b_data.get("segment_from_station_id", ""),
			b_data.get("segment_to_station_id", ""),
			Vector2(pos_data.get("x", 0), pos_data.get("y", 0)),
			b_data.get("terrain_id", "")
		)
		game_state.add_bridge(bridge)
	
	# 터널 복원
	for tn_data in data.get("tunnels", []):
		var pos_data = tn_data.get("position", {"x": 0, "y": 0})
		var tunnel := TunnelEntity.new(
			tn_data.get("id", ""),
			tn_data.get("line_id", ""),
			tn_data.get("segment_from_station_id", ""),
			tn_data.get("segment_to_station_id", ""),
			Vector2(pos_data.get("x", 0), pos_data.get("y", 0)),
			tn_data.get("terrain_id", "")
		)
		game_state.add_tunnel(tunnel)
	
	return {"success": true, "message": "역직렬화 완료"}
