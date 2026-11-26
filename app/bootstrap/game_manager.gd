## 게임 매니저 (Game Manager)
## 모든 도메인 서비스를 초기화하고 게임 루프를 관리하는 부트스트래퍼
## PRD 5.1 CQRS 흐름의 중앙 오케스트레이터
class_name GameManager
extends RefCounted

# === 핵심 저장소 ===
var game_state: GameStateRepository

# === 도메인 서비스 ===
var terrain_checker: TerrainChecker
var map_generator: MapGenerator
var network_graph: NetworkGraph
var simulation_clock: SimulationClock
var destination_resolver: DestinationResolver
var passenger_spawner: PassengerSpawner
var congestion_monitor: CongestionMonitorService
var train_movement: TrainMovementService
var score_calculator: ScoreCalculator

# === 응용 서비스 ===
var undo_redo: UndoRedoSystem
var create_line_use_case: CreateLineUseCase

# === 인프라 서비스 ===
var save_manager: SaveManager

# === 자원 보급 타이머 ===
var _last_station_spawn_hour: float = 0.0
var _last_reward_day: int = 0

# === 자동 저장 타이머 ===
var _autosave_interval: float = 60.0  # 실시간 60초마다
var _autosave_timer: float = 0.0

# === 온보딩 ===
var _hints_shown: Array[int] = []


func _init() -> void:
	# 저장소
	game_state = GameStateRepository.new()
	
	# 도메인 서비스 (의존성 주입 순서)
	terrain_checker = TerrainChecker.new(game_state)
	map_generator = MapGenerator.new(game_state, terrain_checker)
	network_graph = NetworkGraph.new(game_state)
	simulation_clock = SimulationClock.new(game_state)
	destination_resolver = DestinationResolver.new(game_state)
	passenger_spawner = PassengerSpawner.new(game_state, destination_resolver)
	congestion_monitor = CongestionMonitorService.new(game_state)
	train_movement = TrainMovementService.new(game_state, network_graph)
	score_calculator = ScoreCalculator.new(game_state)
	
	# 응용 서비스
	undo_redo = UndoRedoSystem.new()
	create_line_use_case = CreateLineUseCase.new(game_state, terrain_checker, network_graph, undo_redo)
	
	# 인프라 서비스
	save_manager = SaveManager.new(game_state)


## 새 게임을 시작한다.
func start_new_game(seed_value: int = -1) -> Dictionary:
	# 기존 상태 초기화
	game_state.clear()
	undo_redo.clear()
	GameLogger.clear()
	
	# 시드 결정
	if seed_value < 0:
		seed_value = randi()
	
	var balance := GameConfig.balance
	
	# 맵 생성
	var map_result := map_generator.generate(seed_value)
	if not map_result.success:
		return map_result
	
	# 초기 자원 지급
	game_state.available_bridges = balance.initial_bridges
	game_state.available_tunnels = balance.initial_tunnels
	game_state.available_trains = balance.initial_trains
	game_state.available_carriages = balance.initial_carriages
	game_state.available_line_slots = balance.initial_lines
	
	# 초기 열차 + 객차 생성
	var train := TrainEntity.new(game_state.generate_id("train"), "")
	var carriage := CarriageEntity.new(game_state.generate_id("carriage"), train.id)
	train.carriages.append(carriage)
	game_state.add_train(train)
	game_state.add_carriage(carriage)
	game_state.available_trains -= 1  # 인벤토리에서 차감 (이미 생성됨)
	game_state.available_carriages -= 1
	
	# 시뮬레이션 시작 시간 설정 (이른 아침 05:00)
	var seconds_per_hour := balance.day_duration_real_seconds / 24.0
	game_state.simulation_time = seconds_per_hour * 5.0  # 05:00 시작
	
	# 시계를 일시정지 상태로 시작
	simulation_clock.set_speed(SimulationClock.SpeedMode.PAUSED)
	
	_last_station_spawn_hour = 5.0
	_last_reward_day = 1
	
	GameLogger.log_info("GAME", "새 게임 시작. 시드: %d" % seed_value)
	EventBus.game_started.emit(seed_value)
	
	# 자동 저장
	save_manager.autosave()
	
	# 첫 번째 온보딩 힌트
	_show_hint(0)
	
	return {"success": true, "message": "게임 시작 완료", "seed": seed_value}


## 게임 루프 틱 (매 프레임 호출)
func tick(real_delta: float) -> void:
	if game_state.is_game_over:
		return
	
	# 시뮬레이션 시간 진행
	var game_delta := simulation_clock.tick(real_delta)
	if game_delta <= 0.0:
		return
	
	var balance := GameConfig.balance
	
	# 승객 생성
	passenger_spawner.tick(game_delta)
	
	# 열차 이동
	train_movement.tick(game_delta)
	
	# 혼잡도 감시 및 게임오버 판정
	var congestion_result := congestion_monitor.update()
	if congestion_result.game_over:
		_trigger_game_over(congestion_result.game_over_station_id)
		return
	
	# 신규 역 스폰 체크
	_check_station_spawn()
	
	# 일일 보상 체크
	_check_daily_rewards()
	
	# 자동 저장 타이머
	_autosave_timer += real_delta
	if _autosave_timer >= _autosave_interval:
		_autosave_timer = 0.0
		save_manager.autosave()
	
	# 온보딩 힌트
	_check_hints()


## 노선을 생성한다.
func create_line(from_station_id: String, to_station_id: String, waypoints: Array[Vector2] = []) -> Dictionary:
	var result := create_line_use_case.execute(from_station_id, to_station_id, waypoints)
	
	if result.success:
		# 첫 노선 생성 시 열차 자동 배치
		var line := game_state.get_line(result.line_id)
		if line != null:
			_assign_train_to_line(line)
		
		# 자동 저장
		save_manager.autosave()
	
	return result


## 노선에 열차를 배치한다.
func _assign_train_to_line(line: LineEntity) -> void:
	# 미배치 열차 찾기
	for train in game_state.get_all_trains():
		if train.operation_state == TrainEntity.OperationState.IDLE:
			train.line_id = line.id
			train.current_station_id = line.station_ids[0]
			train.operation_state = TrainEntity.OperationState.AT_STATION
			train.direction = 1
			line.assigned_train_ids.append(train.id)
			
			GameLogger.log_info("TRAIN", "열차 %s → 노선 %s 배치" % [train.id, line.name])
			return


## 노선을 삭제한다.
func delete_line(line_id: String) -> Dictionary:
	var line := game_state.get_line(line_id)
	if line == null:
		return {"success": false, "message": "노선을 찾을 수 없습니다."}
	
	# 열차 회수
	for train_id in line.assigned_train_ids:
		var train := game_state.get_train(train_id)
		if train:
			# 열차 내 승객 하차 (현재 역 또는 첫 번째 역에)
			var drop_station_id := train.current_station_id
			if drop_station_id.is_empty() and not line.station_ids.is_empty():
				drop_station_id = line.station_ids[0]
			
			for passenger in train.get_all_passengers():
				train.remove_passenger(passenger)
				if not drop_station_id.is_empty():
					var station := game_state.get_station(drop_station_id)
					if station:
						passenger.start_transfer(drop_station_id)
						passenger.complete_transfer()
						station.add_passenger(passenger)
			
			train.operation_state = TrainEntity.OperationState.IDLE
			train.line_id = ""
			train.path_points = []
	
	# 다리/터널 반환
	for bridge_id in line.bridge_ids:
		game_state.remove_bridge(bridge_id)
		game_state.available_bridges += 1
		EventBus.bridge_returned.emit(bridge_id)
	
	for tunnel_id in line.tunnel_ids:
		game_state.remove_tunnel(tunnel_id)
		game_state.available_tunnels += 1
		EventBus.tunnel_returned.emit(tunnel_id)
	
	# 역 연결 해제
	for station_id in line.station_ids:
		var station := game_state.get_station(station_id)
		if station:
			station.remove_line_connection(line_id)
	
	# 노선 삭제
	game_state.remove_line(line_id)
	network_graph.rebuild()
	
	EventBus.line_deleted.emit(line_id)
	GameLogger.log_info("LINE", "노선 삭제: %s" % line.name)
	
	save_manager.autosave()
	
	return {"success": true, "message": "노선을 삭제했습니다."}


## 게임오버 처리
func _trigger_game_over(station_id: String) -> void:
	game_state.is_game_over = true
	simulation_clock.set_speed(SimulationClock.SpeedMode.PAUSED)
	
	var score_data := score_calculator.calculate()
	score_data["game_over_station_id"] = station_id
	score_data["most_congested_station_id"] = congestion_monitor.get_most_congested_station_id()
	score_data["recent_events"] = []
	
	var recent := GameLogger.get_recent_entries(10)
	for entry in recent:
		score_data["recent_events"].append(entry.to_dict())
	
	# 가장 많이 이용된 노선 찾기
	var most_used_line := ""
	# (통계가 별도 추적되지 않으므로 연결 역 수 기준)
	var max_stations := 0
	for line in game_state.get_all_lines():
		if line.get_station_count() > max_stations:
			max_stations = line.get_station_count()
			most_used_line = line.name
	score_data["most_used_line"] = most_used_line
	
	GameLogger.log_info("GAME", "게임 종료. 점수: %d" % score_data.total_score)
	EventBus.game_over.emit(score_data)
	
	save_manager.autosave()


## 신규 역 스폰 체크
func _check_station_spawn() -> void:
	var balance := GameConfig.balance
	var current_hour := game_state.get_game_hour()
	var hours_elapsed := current_hour - _last_station_spawn_hour
	if hours_elapsed < 0:
		hours_elapsed += 24.0
	
	if hours_elapsed >= balance.new_station_spawn_interval_hours:
		_last_station_spawn_hour = current_hour
		var result := map_generator.spawn_new_station()
		if result.success:
			GameLogger.log_info("GAME", "신규 역 생성")
			network_graph.rebuild()


## 일일 보상 체크 (자정마다)
func _check_daily_rewards() -> void:
	var current_day := game_state.get_game_day()
	if current_day <= _last_reward_day:
		return
	
	_last_reward_day = current_day
	
	# 매일 자정 보상
	var rewards := {}
	
	# 2일차부터 열차 추가
	if current_day >= 2:
		game_state.available_carriages += 1
		rewards["carriages"] = 1
	
	# 3일차마다 열차 추가
	if current_day % 3 == 0:
		var train := TrainEntity.new(game_state.generate_id("train"), "")
		var carriage := CarriageEntity.new(game_state.generate_id("carriage"), train.id)
		train.carriages.append(carriage)
		game_state.add_train(train)
		game_state.add_carriage(carriage)
		rewards["trains"] = 1
	
	# 2일차마다 다리 또는 터널 추가
	if current_day % 2 == 0:
		if current_day % 4 == 0:
			game_state.available_tunnels += 1
			rewards["tunnels"] = 1
		else:
			game_state.available_bridges += 1
			rewards["bridges"] = 1
	
	if not rewards.is_empty():
		EventBus.resources_granted.emit(rewards)
		GameLogger.log_info("GAME", "일일 보상 지급 (Day %d): %s" % [current_day, str(rewards)])


## 온보딩 힌트 체크
func _show_hint(index: int) -> void:
	if index in _hints_shown:
		return
	_hints_shown.append(index)
	
	var hints := [
		"첫 번째 역을 다른 역으로 연결하세요.",
		"승객의 모양과 색을 확인하세요.",
		"한 역에 승객 15명이 모이면 게임이 종료됩니다."
	]
	
	if index < hints.size():
		EventBus.hint_requested.emit(hints[index])


func _check_hints() -> void:
	# 첫 노선 생성 후 두 번째 힌트
	if 1 not in _hints_shown and not game_state.lines.is_empty():
		_show_hint(1)
	
	# 첫 승객 생성 후 세 번째 힌트
	if 2 not in _hints_shown and not game_state.passengers.is_empty():
		_show_hint(2)
