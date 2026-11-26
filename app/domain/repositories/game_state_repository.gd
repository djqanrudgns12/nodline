## 게임 상태 저장소 (Game State Repository)
## 모든 게임 엔티티를 중앙에서 관리하는 In-Memory 저장소
## PRD 3.2 CRUD 관리 매트릭스의 구현체
class_name GameStateRepository
extends RefCounted

var stations: Dictionary = {}      # Dictionary<String, StationEntity>
var passengers: Dictionary = {}    # Dictionary<String, PassengerEntity>
var lines: Dictionary = {}         # Dictionary<String, LineEntity>
var trains: Dictionary = {}        # Dictionary<String, TrainEntity>
var carriages: Dictionary = {}     # Dictionary<String, CarriageEntity>
var terrains: Dictionary = {}      # Dictionary<String, TerrainEntity>
var bridges: Dictionary = {}       # Dictionary<String, BridgeEntity>
var tunnels: Dictionary = {}       # Dictionary<String, TunnelEntity>

## 자원 인벤토리
var available_bridges: int = 0
var available_tunnels: int = 0
var available_trains: int = 0
var available_carriages: int = 0
var available_line_slots: int = 0

## 게임 메타데이터
var seed_value: int = 0
var simulation_time: float = 0.0  # 게임 내 경과 시간 (초 단위)
var game_day: int = 1
var is_game_over: bool = false
var total_arrived_passengers: int = 0
var max_simultaneous_passengers: int = 0
var speed_multiplier: float = 1.0

## ID 생성 카운터
var _next_id_counters: Dictionary = {
	"station": 0,
	"passenger": 0,
	"line": 0,
	"train": 0,
	"carriage": 0,
	"terrain": 0,
	"bridge": 0,
	"tunnel": 0
}


## 고유 ID를 생성한다.
func generate_id(entity_type: String) -> String:
	var counter: int = _next_id_counters.get(entity_type, 0)
	_next_id_counters[entity_type] = counter + 1
	return "%s_%04d" % [entity_type, counter]


# === Station CRUD ===

func add_station(station: StationEntity) -> void:
	stations[station.id] = station


func get_station(station_id: String) -> StationEntity:
	return stations.get(station_id)


func get_all_stations() -> Array:
	return stations.values()


func remove_station(station_id: String) -> void:
	stations.erase(station_id)


# === Passenger CRUD ===

func add_passenger(passenger: PassengerEntity) -> void:
	passengers[passenger.id] = passenger


func get_passenger(passenger_id: String) -> PassengerEntity:
	return passengers.get(passenger_id)


func get_all_passengers() -> Array:
	return passengers.values()


func remove_passenger(passenger_id: String) -> void:
	passengers.erase(passenger_id)


# === Line CRUD ===

func add_line(line: LineEntity) -> void:
	lines[line.id] = line


func get_line(line_id: String) -> LineEntity:
	return lines.get(line_id)


func get_all_lines() -> Array:
	return lines.values()


func remove_line(line_id: String) -> void:
	lines.erase(line_id)


# === Train CRUD ===

func add_train(train: TrainEntity) -> void:
	trains[train.id] = train


func get_train(train_id: String) -> TrainEntity:
	return trains.get(train_id)


func get_all_trains() -> Array:
	return trains.values()


func remove_train(train_id: String) -> void:
	trains.erase(train_id)


# === Carriage CRUD ===

func add_carriage(carriage: CarriageEntity) -> void:
	carriages[carriage.id] = carriage


func get_carriage(carriage_id: String) -> CarriageEntity:
	return carriages.get(carriage_id)


func remove_carriage(carriage_id: String) -> void:
	carriages.erase(carriage_id)


# === Terrain CRUD ===

func add_terrain(terrain: TerrainEntity) -> void:
	terrains[terrain.id] = terrain


func get_terrain(terrain_id: String) -> TerrainEntity:
	return terrains.get(terrain_id)


func get_all_terrains() -> Array:
	return terrains.values()


func get_rivers() -> Array:
	var result: Array = []
	for t in terrains.values():
		if t.terrain_type == TerrainEntity.TerrainType.RIVER:
			result.append(t)
	return result


func get_mountains() -> Array:
	var result: Array = []
	for t in terrains.values():
		if t.terrain_type == TerrainEntity.TerrainType.MOUNTAIN:
			result.append(t)
	return result


# === Bridge CRUD ===

func add_bridge(bridge: BridgeEntity) -> void:
	bridges[bridge.id] = bridge


func get_bridge(bridge_id: String) -> BridgeEntity:
	return bridges.get(bridge_id)


func remove_bridge(bridge_id: String) -> void:
	bridges.erase(bridge_id)


# === Tunnel CRUD ===

func add_tunnel(tunnel: TunnelEntity) -> void:
	tunnels[tunnel.id] = tunnel


func get_tunnel(tunnel_id: String) -> TunnelEntity:
	return tunnels.get(tunnel_id)


func remove_tunnel(tunnel_id: String) -> void:
	tunnels.erase(tunnel_id)


## 게임 시간을 시(hour)로 반환한다.
func get_game_hour() -> float:
	var balance := GameConfig.balance
	var seconds_per_hour := balance.day_duration_real_seconds / 24.0
	var total_hours := simulation_time / seconds_per_hour
	return fmod(total_hours, 24.0)


## 게임 일수를 반환한다.
func get_game_day() -> int:
	var balance := GameConfig.balance
	return int(simulation_time / balance.day_duration_real_seconds) + 1


## 역 위치 맵을 반환한다 (경로 계산용)
func get_station_positions() -> Dictionary:
	var positions := {}
	for station in stations.values():
		positions[station.id] = station.position
	return positions


## 전체 상태를 초기화한다.
func clear() -> void:
	stations.clear()
	passengers.clear()
	lines.clear()
	trains.clear()
	carriages.clear()
	terrains.clear()
	bridges.clear()
	tunnels.clear()
	available_bridges = 0
	available_tunnels = 0
	available_trains = 0
	available_carriages = 0
	available_line_slots = 0
	seed_value = 0
	simulation_time = 0.0
	game_day = 1
	is_game_over = false
	total_arrived_passengers = 0
	max_simultaneous_passengers = 0
	speed_multiplier = 1.0
	for key in _next_id_counters.keys():
		_next_id_counters[key] = 0
