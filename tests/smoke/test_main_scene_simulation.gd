## 스모크 테스트: 메인 씬 시뮬레이션 및 4배속 안정성
## PRD 8.1 / 9.1 — 4배속 안정성 및 게임 루프 스모크 테스트
extends Node

const TEST_NAME := "test_main_scene_simulation"


func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_main_scene_instantiation_and_loop())
	results.append(_test_4x_simulation_stability())
	return results


## 메인 씬 초기화 및 기본 루프 검증
func _test_main_scene_instantiation_and_loop() -> Dictionary:
	var main_scene = load("res://app/presentation/scenes/main.tscn")
	if main_scene == null:
		return {"test": "메인 씬 로드 및 초기화", "passed": false, "reason": "main.tscn 로드 실패"}
	
	var main_node = main_scene.instantiate()
	if main_node == null:
		return {"test": "메인 씬 로드 및 초기화", "passed": false, "reason": "main.tscn 인스턴스화 실패"}
	
	# 트리에 추가하고 _ready() 명시적 실행
	add_child(main_node)
	if main_node.get("game_manager") == null:
		main_node._ready()
	
	var gm: GameManager = main_node.get("game_manager")
	if gm == null:
		main_node.queue_free()
		return {"test": "메인 씬 로드 및 초기화", "passed": false, "reason": "GameManager가 초기화되지 않음"}
	
	var station_count: int = gm.game_state.get_all_stations().size()
	if station_count < 3:
		main_node.queue_free()
		return {"test": "메인 씬 로드 및 초기화", "passed": false, "reason": "초기 역 수가 3 미만: %d" % station_count}
	
	# 30 프레임 1배속 시뮬레이션
	gm.simulation_clock.set_speed(SimulationClock.SpeedMode.NORMAL)
	var initial_time: float = gm.game_state.simulation_time
	
	for i in range(30):
		main_node._process(0.016)
	
	if gm.game_state.simulation_time <= initial_time:
		main_node.queue_free()
		return {"test": "메인 씬 로드 및 초기화", "passed": false, "reason": "시뮬레이션 시간이 진행되지 않음"}
	
	main_node.queue_free()
	return {"test": "메인 씬 로드 및 기본 루프", "passed": true, "reason": ""}


## 4배속 시뮬레이션 120프레임 안정성 검증
func _test_4x_simulation_stability() -> Dictionary:
	var main_scene = load("res://app/presentation/scenes/main.tscn")
	var main_node = main_scene.instantiate()
	add_child(main_node)
	if main_node.get("game_manager") == null:
		main_node._ready()
	
	var gm: GameManager = main_node.get("game_manager")
	gm.simulation_clock.set_speed(SimulationClock.SpeedMode.VERY_FAST)
	
	var t_start: float = gm.game_state.simulation_time
	
	# 120 프레임 시뮬레이션 (4배속)
	for i in range(120):
		main_node._process(0.016)
	
	var elapsed_sim: float = gm.game_state.simulation_time - t_start
	
	# 120 * 0.016 * 4.0 = 약 7.68초 게임 시간 진행
	if elapsed_sim < 5.0:
		main_node.queue_free()
		return {"test": "4배속 시뮬레이션 안정성", "passed": false, "reason": "4배속 시간 진행률 미달: %f" % elapsed_sim}
	
	main_node.queue_free()
	return {"test": "4배속 시뮬레이션 안정성 (120 프레임)", "passed": true, "reason": ""}
