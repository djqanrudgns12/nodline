## 도메인 이벤트 버스 (Autoload)
## 모든 도메인 이벤트를 발행(emit)하고 구독(connect)하는 중앙 허브.
## UI는 이 버스를 통해 도메인 변화를 감지한다.
## PRD 5.1 CQRS: Domain → Event → Presentation 흐름의 핵심.
extends Node

# === 역 이벤트 ===
signal station_created(station_data: Dictionary)
signal station_congestion_changed(station_id: String, passenger_count: int, state: String)
signal station_passengers_changed(station_id: String, passenger_count: int)

# === 승객 이벤트 ===
signal passenger_spawned(passenger_data: Dictionary)
signal passenger_boarded(passenger_id: String, train_id: String)
signal passenger_alighted(passenger_id: String, station_id: String)
signal passenger_arrived(passenger_id: String, station_id: String)
signal passenger_transfer_started(passenger_id: String, station_id: String)

# === 노선 이벤트 ===
signal line_created(line_data: Dictionary)
signal line_modified(line_id: String)
signal line_deleted(line_id: String)
signal line_connection_rejected(station_id: String, reason: String)

# === 열차 이벤트 ===
signal train_departed(train_id: String, from_station_id: String)
signal train_arrived(train_id: String, at_station_id: String)
signal train_full(train_id: String)

# === 자원 이벤트 ===
signal bridge_built(bridge_data: Dictionary)
signal bridge_returned(bridge_id: String)
signal tunnel_built(tunnel_data: Dictionary)
signal tunnel_returned(tunnel_id: String)
signal resources_granted(resource_data: Dictionary)

# === 게임 상태 이벤트 ===
signal game_started(seed_value: int)
signal game_over(result_data: Dictionary)
signal game_paused()
signal game_resumed()
signal speed_changed(new_speed: float)
signal day_changed(day_number: int)
signal simulation_time_changed(game_hours: float)

# === 저장 이벤트 ===
signal game_saved(slot_name: String)
signal game_loaded(slot_name: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

# === UI 이벤트 ===
signal hint_requested(hint_text: String)
signal error_message(title: String, description: String, action: String)
signal selection_changed(object_type: String, object_id: String)

# === Undo/Redo 이벤트 ===
signal action_undone(action_type: String)
signal action_redone(action_type: String)

# === 네트워크 이벤트 ===
signal network_graph_updated()
