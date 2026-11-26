## 승객 생성 서비스 (Passenger Spawner)
## PRD 6.3 참조
## 시간대별 생성 배율에 따라 승객을 생성한다.
## 생성 공식: 기본 생성량 × 시간대 배율 × 역 수요 배율 × 난이도 배율 × 랜덤 계수
class_name PassengerSpawner
extends RefCounted

var _game_state: GameStateRepository
var _destination_resolver: DestinationResolver
var _rng: RandomNumberGenerator

## 기본 생성 간격 (게임 내 초 단위)
const BASE_SPAWN_INTERVAL: float = 8.0
## 그레이스 기간 배율 (첫 30초 동안 낮은 생성량)
const GRACE_PERIOD_MULTIPLIER: float = 0.3

var _spawn_timer: float = 0.0


func _init(game_state: GameStateRepository, destination_resolver: DestinationResolver) -> void:
	_game_state = game_state
	_destination_resolver = destination_resolver
	_rng = RandomNumberGenerator.new()
	_rng.seed = game_state.seed_value + 12345


## 시뮬레이션 틱마다 호출. 승객 생성을 처리한다.
func tick(game_delta: float) -> void:
	if game_delta <= 0.0:
		return
	
	_spawn_timer += game_delta
	
	var balance := GameConfig.balance
	var current_hour := _game_state.get_game_hour()
	var time_multiplier := balance.get_spawn_rate_for_hour(current_hour)
	
	# 그레이스 기간 (첫 30초)
	if _game_state.simulation_time < balance.grace_period_seconds:
		time_multiplier *= GRACE_PERIOD_MULTIPLIER
	
	# 역 수에 따른 난이도 배율
	var station_count := _game_state.stations.size()
	var difficulty_multiplier := 1.0 + (station_count - 3) * 0.1
	difficulty_multiplier = maxf(0.5, difficulty_multiplier)
	
	# 생성 간격 계산
	var adjusted_interval := BASE_SPAWN_INTERVAL / (time_multiplier * difficulty_multiplier)
	adjusted_interval = maxf(2.0, adjusted_interval)
	
	while _spawn_timer >= adjusted_interval:
		_spawn_timer -= adjusted_interval
		_try_spawn_passenger()


## 승객 생성을 시도한다.
func _try_spawn_passenger() -> void:
	var stations := _game_state.get_all_stations()
	if stations.size() < 2:
		return
	
	# 랜덤 역 선택 (수요 배율 적용)
	var station: StationEntity = stations[_rng.randi() % stations.size()]
	
	# 이미 게임오버 임계값에 도달한 역은 생성하지 않음
	var balance := GameConfig.balance
	if station.get_passenger_count() >= balance.max_passengers_per_station:
		return
	
	# 목적지 결정
	var destination: Dictionary = _destination_resolver.resolve(station)
	if destination.is_empty():
		return
	
	# 승객 생성
	var passenger := PassengerEntity.new(
		_game_state.generate_id("passenger"),
		station.id,
		destination.station_id,
		destination.shape,
		destination.color
	)
	passenger.spawned_at_sim_time = _game_state.simulation_time
	
	# 저장소에 추가
	_game_state.add_passenger(passenger)
	station.add_passenger(passenger)
	
	# 동시 승객 수 기록 갱신
	var total_waiting := 0
	for s in stations:
		total_waiting += s.get_passenger_count()
	if total_waiting > _game_state.max_simultaneous_passengers:
		_game_state.max_simultaneous_passengers = total_waiting
	
	EventBus.passenger_spawned.emit(passenger.to_dict())
	EventBus.station_passengers_changed.emit(station.id, station.get_passenger_count())
