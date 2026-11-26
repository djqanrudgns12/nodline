## 네트워크 그래프 서비스 (Network Graph)
## PRD 6.3 참조
## 역 = 그래프의 점, 역과 역의 연결 = 그래프의 선
## 그래프 데이터 ≠ 화면에 그려진 선
class_name NetworkGraph
extends RefCounted

## 그래프 엣지 데이터
class Edge:
	var from_station_id: String
	var to_station_id: String
	var line_id: String
	var weight: float  # 이동 시간 (거리 기반)
	
	func _init(p_from: String, p_to: String, p_line: String, p_weight: float) -> void:
		from_station_id = p_from
		to_station_id = p_to
		line_id = p_line
		weight = p_weight

## 인접 리스트
var _adjacency: Dictionary = {}  # Dictionary<String, Array[Edge]>
var _game_state: GameStateRepository

## 환승 비용 (초 단위)
const TRANSFER_COST: float = 30.0


func _init(game_state: GameStateRepository) -> void:
	_game_state = game_state


## 전체 그래프를 재구성한다.
func rebuild() -> void:
	_adjacency.clear()
	
	for line in _game_state.get_all_lines():
		if line.is_paused:
			continue
		
		var station_ids: Array[String] = line.station_ids
		var positions := _game_state.get_station_positions()
		
		for i in range(station_ids.size() - 1):
			var from_id: String = station_ids[i]
			var to_id: String = station_ids[i + 1]
			
			# 거리 기반 가중치 계산
			var from_pos: Vector2 = positions.get(from_id, Vector2.ZERO)
			var to_pos: Vector2 = positions.get(to_id, Vector2.ZERO)
			var distance: float = from_pos.distance_to(to_pos)
			var weight: float = distance / GameConfig.balance.train_base_speed_px_per_sec
			
			# 양방향 엣지 추가
			_add_edge(from_id, to_id, line.id, weight)
			_add_edge(to_id, from_id, line.id, weight)
	
	EventBus.network_graph_updated.emit()


## 최단 경로를 찾는다 (다익스트라 알고리즘)
## 반환: {path: Array[String], lines: Array[String], total_cost: float, transfers: int}
func find_shortest_path(from_station_id: String, to_station_id: String) -> Dictionary:
	if from_station_id == to_station_id:
		return {"path": [from_station_id], "lines": [], "total_cost": 0.0, "transfers": 0}
	
	# 다익스트라
	var distances: Dictionary = {}
	var previous: Dictionary = {}
	var previous_line: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = []  # [cost, station_id, current_line_id]
	
	distances[from_station_id] = 0.0
	queue.append([0.0, from_station_id, ""])
	
	while not queue.is_empty():
		# 최소 비용 노드 선택 (간단한 선형 탐색)
		var min_idx := 0
		for i in range(1, queue.size()):
			if queue[i][0] < queue[min_idx][0]:
				min_idx = i
		
		var current = queue[min_idx]
		queue.remove_at(min_idx)
		
		var current_cost: float = current[0]
		var current_id: String = current[1]
		var current_line: String = current[2]
		
		if current_id in visited:
			continue
		visited[current_id] = true
		
		if current_id == to_station_id:
			break
		
		# 인접 노드 탐색
		var edges := _get_edges(current_id)
		for edge in edges:
			if edge.to_station_id in visited:
				continue
			
			var cost: float = current_cost + edge.weight
			
			# 환승 비용 추가 (노선이 바뀌면)
			if current_line != "" and edge.line_id != current_line:
				cost += TRANSFER_COST
			
			if cost < distances.get(edge.to_station_id, INF):
				distances[edge.to_station_id] = cost
				previous[edge.to_station_id] = current_id
				previous_line[edge.to_station_id] = edge.line_id
				queue.append([cost, edge.to_station_id, edge.line_id])
	
	# 경로가 없는 경우
	if to_station_id not in previous:
		return {"path": [], "lines": [], "total_cost": INF, "transfers": -1}
	
	# 경로 복원
	var path: Array[String] = []
	var lines_used: Array[String] = []
	var current_id := to_station_id
	
	while current_id != from_station_id:
		path.insert(0, current_id)
		if current_id in previous_line:
			var ln: String = previous_line[current_id]
			if lines_used.is_empty() or lines_used[0] != ln:
				lines_used.insert(0, ln)
		current_id = previous[current_id]
	path.insert(0, from_station_id)
	
	var transfers := maxi(0, lines_used.size() - 1)
	
	return {
		"path": path,
		"lines": lines_used,
		"total_cost": distances.get(to_station_id, INF),
		"transfers": transfers
	}


## 두 역이 연결되어 있는지 확인한다.
func has_connection(from_station_id: String, to_station_id: String) -> bool:
	var result := find_shortest_path(from_station_id, to_station_id)
	return not result.path.is_empty()


## 특정 역에 연결된 노선 ID 목록을 반환한다.
func get_lines_at_station(station_id: String) -> Array[String]:
	var line_ids: Array[String] = []
	var edges := _get_edges(station_id)
	for edge in edges:
		if edge.line_id not in line_ids:
			line_ids.append(edge.line_id)
	return line_ids


func _add_edge(from: String, to: String, line_id: String, weight: float) -> void:
	if from not in _adjacency:
		_adjacency[from] = []
	_adjacency[from].append(Edge.new(from, to, line_id, weight))


func _get_edges(station_id: String) -> Array:
	return _adjacency.get(station_id, [])
