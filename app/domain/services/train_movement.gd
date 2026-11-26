## 열차 이동 서비스 (Train Movement Service)
## PRD 6.4 참조
## 열차의 이동, 역 정차, 승하차 처리를 담당한다.
## 역 도착 시 정차 처리 순서:
##   1. 목적지 도착 승객 하차
##   2. 환승 필요 승객 처리 (역 대기열 합류 + 15명 검사)
##   3. 새로 탑승 가능한 승객 검색
##   4. 열차 수용량 확인
##   5. 잔여 공간만큼 탑승
##   6. 열차 상태 업데이트
##   7. 다음 역으로 이동
class_name TrainMovementService
extends RefCounted

var _game_state: GameStateRepository
var _network_graph: NetworkGraph

## 역 정차 시간 (게임 내 초)
const STATION_DWELL_TIME: float = 2.0
var _dwell_timers: Dictionary = {}  # train_id → remaining_dwell_time


func _init(game_state: GameStateRepository, network_graph: NetworkGraph) -> void:
	_game_state = game_state
	_network_graph = network_graph


## 모든 열차를 한 틱 진행한다.
func tick(game_delta: float) -> void:
	if game_delta <= 0.0:
		return
	
	var balance := GameConfig.balance
	
	for train in _game_state.get_all_trains():
		if train.operation_state == TrainEntity.OperationState.IDLE:
			continue
		if train.operation_state == TrainEntity.OperationState.PAUSED:
			continue
		
		var line := _game_state.get_line(train.line_id)
		if line == null or line.is_paused:
			continue
		
		if line.get_station_count() < 2:
			continue
		
		match train.operation_state:
			TrainEntity.OperationState.AT_STATION:
				_process_at_station(train, line, game_delta, balance)
			TrainEntity.OperationState.MOVING:
				_process_moving(train, line, game_delta, balance)


## 역 정차 처리
func _process_at_station(train: TrainEntity, line: LineEntity, game_delta: float, balance: GameBalanceConfig) -> void:
	# 정차 시간 대기
	if train.id in _dwell_timers:
		_dwell_timers[train.id] -= game_delta
		if _dwell_timers[train.id] > 0.0:
			return
		_dwell_timers.erase(train.id)
	
	# 정차 처리 시작
	var station := _game_state.get_station(train.current_station_id)
	if station == null:
		_start_moving(train, line)
		return
	
	# 1. 목적지 도착 승객 하차
	var arrived_passengers := train.get_passengers_for_station(station.id)
	for passenger in arrived_passengers:
		train.remove_passenger(passenger)
		passenger.complete_arrival()
		_game_state.total_arrived_passengers += 1
		_game_state.remove_passenger(passenger.id)
		EventBus.passenger_arrived.emit(passenger.id, station.id)
	
	# 2. 환승 필요 승객 처리
	var transfer_passengers := train.get_passengers_needing_transfer(station.id, line.station_ids)
	for passenger in transfer_passengers:
		train.remove_passenger(passenger)
		passenger.start_transfer(station.id)
		station.add_passenger(passenger)
		passenger.complete_transfer()  # 즉시 대기 상태로
		EventBus.passenger_transfer_started.emit(passenger.id, station.id)
		EventBus.station_passengers_changed.emit(station.id, station.get_passenger_count())
	
	# 3~5. 새로 탑승 가능한 승객 탑승
	var remaining_capacity := train.get_remaining_capacity(balance.max_passengers_per_carriage)
	if remaining_capacity > 0 and not station.waiting_passengers.is_empty():
		# 이 노선으로 목적지에 도달할 수 있는 승객을 우선 탑승
		var passengers_to_board: Array = []
		
		for passenger in station.waiting_passengers:
			if passengers_to_board.size() >= remaining_capacity:
				break
			
			# 목적지가 현재 노선에 있는지 확인
			if passenger.destination_station_id in line.station_ids:
				passengers_to_board.append(passenger)
		
		# 남은 공간에 다른 승객도 탑승 (환승을 통해 도달 가능하며, 다음 경로가 이 노선인 경우)
		if passengers_to_board.size() < remaining_capacity:
			for passenger in station.waiting_passengers:
				if passengers_to_board.size() >= remaining_capacity:
					break
				if passenger not in passengers_to_board:
					var path_info: Dictionary = _network_graph.find_shortest_path(station.id, passenger.destination_station_id)
					if not path_info.lines.is_empty() and path_info.lines[0] == line.id:
						passengers_to_board.append(passenger)
		
		for passenger in passengers_to_board:
			station.remove_passenger(passenger)
			passenger.board_train(train.id)
			passenger.complete_boarding()
			train.board_passenger(passenger, balance.max_passengers_per_carriage)
			EventBus.passenger_boarded.emit(passenger.id, train.id)
			EventBus.station_passengers_changed.emit(station.id, station.get_passenger_count())
	
	# 6~7. 다음 역으로 이동 시작
	_start_moving(train, line)


## 이동 처리
func _process_moving(train: TrainEntity, line: LineEntity, game_delta: float, balance: GameBalanceConfig) -> void:
	if train.path_points.is_empty():
		_start_moving(train, line)
		return
	
	# 경로 전체 길이 계산
	var total_length := 0.0
	for i in range(1, train.path_points.size()):
		total_length += train.path_points[i - 1].distance_to(train.path_points[i])
	
	if total_length <= 0.0:
		_arrive_at_station(train)
		return
	
	# 이동 속도 계산 (교차 감속 포함)
	var speed := balance.train_base_speed_px_per_sec
	
	# 노선 교차 지점 감속 확인
	var current_pos := train.get_current_position()
	if _is_at_crossing(current_pos, train.line_id, balance.line_crossing_radius_px):
		speed *= balance.line_crossing_speed_multiplier
	
	train.current_speed = speed
	train.path_progress += speed * game_delta
	
	# 도착 판정
	if train.path_progress >= total_length:
		_arrive_at_station(train)


## 이동 시작
func _start_moving(train: TrainEntity, line: LineEntity) -> void:
	var next_info := line.get_next_station_id(train.current_station_id, train.direction)
	var next_station_id: String = next_info.station_id
	train.direction = next_info.direction
	
	if next_station_id == train.current_station_id or next_station_id.is_empty():
		return  # 이동할 역이 없음
	
	train.target_station_id = next_station_id
	
	# 경로 포인트 설정
	var positions := _game_state.get_station_positions()
	train.path_points = line.get_path_points(train.current_station_id, next_station_id, positions)
	train.path_progress = 0.0
	train.operation_state = TrainEntity.OperationState.MOVING
	
	EventBus.train_departed.emit(train.id, train.current_station_id)


## 역 도착 처리
func _arrive_at_station(train: TrainEntity) -> void:
	train.current_station_id = train.target_station_id
	train.target_station_id = ""
	train.operation_state = TrainEntity.OperationState.AT_STATION
	train.path_progress = 0.0
	train.path_points = []
	
	# 정차 시간 설정
	_dwell_timers[train.id] = STATION_DWELL_TIME
	
	EventBus.train_arrived.emit(train.id, train.current_station_id)


## 노선 교차 지점인지 확인한다.
func _is_at_crossing(position: Vector2, current_line_id: String, radius: float) -> bool:
	for line in _game_state.get_all_lines():
		if line.id == current_line_id or line.is_paused:
			continue
		
		var positions := _game_state.get_station_positions()
		
		for i in range(line.station_ids.size() - 1):
			var from_id: String = line.station_ids[i]
			var to_id: String = line.station_ids[i + 1]
			var from_pos: Vector2 = positions.get(from_id, Vector2.ZERO)
			var to_pos: Vector2 = positions.get(to_id, Vector2.ZERO)
			
			# 선분과 점의 거리 계산
			var closest := Geometry2D.get_closest_point_to_segment(position, from_pos, to_pos)
			if position.distance_to(closest) < radius:
				return true
	
	return false
