## 메인 게임 컨트롤러
## project.godot의 main_scene으로 지정된 루트 씬 스크립트
## 모든 프레젠테이션 요소를 초기화하고, GameManager를 구동한다.
extends Node2D

# === 핵심 매니저 ===
var game_manager: GameManager

# === UI 참조 ===
@onready var camera: Camera2D = $GameCamera
@onready var map_renderer: Node2D = $MapRenderer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var top_bar: Control = $UILayer/TopBar
@onready var left_rail: Control = $UILayer/LeftRail
@onready var right_panel: Control = $UILayer/RightPanel
@onready var bottom_bar: Control = $UILayer/BottomBar
@onready var game_over_screen: Control = $UILayer/GameOverScreen
@onready var hint_label: Label = $UILayer/HintLabel
@onready var error_popup: Control = $UILayer/ErrorPopup

# === 입력 및 노선 연결 상태 ===
enum InputMode {
	NORMAL,
	DRAWING_LINE,
	PLACING_WAYPOINT,
}

var _input_mode: InputMode = InputMode.NORMAL
var _selected_station_id: String = ""
var _connecting_from_station_id: String = ""  # 현재 연결을 시작한 역 ID
var _is_dragging_connection: bool = false     # 마우스 드래그로 노선 연결 중인지 여부
var _hovered_station_id: String = ""
var _is_dragging_camera: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_button: int = -1
var _drag_distance: float = 0.0


func _ready() -> void:
	if get_window() != null:
		get_window().title = "%s v%s" % [GameConfig.APP_NAME, GameConfig.APP_VERSION]
	
	game_manager = GameManager.new()
	
	# 이벤트 구독
	_connect_events()
	
	# UI 버튼 시그널 연결
	_setup_ui_buttons()
	
	# 디자인 2: 노르딕 아키텍처 라이트 UI 테마 적용
	_apply_nordic_theme()
	
	# 새 게임 시작
	game_manager.start_new_game()
	
	# 초기 렌더링
	_render_full_map()
	_update_ui()
	
	# 카메라 초기 위치
	_center_camera()


func _process(delta: float) -> void:
	_process_keyboard_camera(delta)
	game_manager.tick(delta)
	_update_ui()
	_update_train_rendering()


func _unhandled_input(event: InputEvent) -> void:
	# 단축키 처리
	if event is InputEventKey and event.pressed:
		_handle_shortcut(event)
	
	# 마우스 입력
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


## UI 버튼 클릭 이벤트 연결
func _setup_ui_buttons() -> void:
	if not is_instance_valid(ui_layer):
		return
	
	# 배속 컨트롤
	var pause_btn := ui_layer.get_node_or_null("TopBar/HBoxContainer/SpeedButtons/PauseBtn") as Button
	if pause_btn:
		pause_btn.pressed.connect(func():
			game_manager.simulation_clock.toggle_pause()
			_update_speed_display()
		)
	var speed1_btn := ui_layer.get_node_or_null("TopBar/HBoxContainer/SpeedButtons/Speed1Btn") as Button
	if speed1_btn:
		speed1_btn.pressed.connect(func():
			game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.NORMAL)
			_update_speed_display()
		)
	var speed2_btn := ui_layer.get_node_or_null("TopBar/HBoxContainer/SpeedButtons/Speed2Btn") as Button
	if speed2_btn:
		speed2_btn.pressed.connect(func():
			game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.FAST)
			_update_speed_display()
		)
	var speed4_btn := ui_layer.get_node_or_null("TopBar/HBoxContainer/SpeedButtons/Speed4Btn") as Button
	if speed4_btn:
		speed4_btn.pressed.connect(func():
			game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.VERY_FAST)
			_update_speed_display()
		)
	
	# 좌측 도구 레일 버튼
	var line_btn := ui_layer.get_node_or_null("LeftRail/LineBtn") as Button
	if line_btn:
		line_btn.pressed.connect(func():
			_show_toast("노선 연결: 역을 클릭하거나 드래그하여 다른 역과 연결하세요")
		)
	var bridge_btn := ui_layer.get_node_or_null("LeftRail/BridgeBtn") as Button
	if bridge_btn:
		bridge_btn.pressed.connect(func():
			_show_toast("다리: 노선이 강을 통과할 때 자동 건설됩니다 (보유: %d개)" % game_manager.game_state.available_bridges)
		)
	var tunnel_btn := ui_layer.get_node_or_null("LeftRail/TunnelBtn") as Button
	if tunnel_btn:
		tunnel_btn.pressed.connect(func():
			_show_toast("터널: 노선이 산을 통과할 때 자동 건설됩니다 (보유: %d개)" % game_manager.game_state.available_tunnels)
		)
	var undo_btn := ui_layer.get_node_or_null("LeftRail/UndoBtn") as Button
	if undo_btn:
		undo_btn.pressed.connect(func():
			game_manager.undo_redo.undo()
			_render_full_map()
			_update_ui()
		)
	var redo_btn := ui_layer.get_node_or_null("LeftRail/RedoBtn") as Button
	if redo_btn:
		redo_btn.pressed.connect(func():
			game_manager.undo_redo.redo()
			_render_full_map()
			_update_ui()
		)
	
	# 게임오버 다시 시작 버튼
	var restart_btn := ui_layer.get_node_or_null("GameOverScreen/CenterContainer/VBox/RestartBtn") as Button
	if restart_btn:
		restart_btn.pressed.connect(func():
			_restart_game()
		)


## 새 게임 다시 시작
func _restart_game() -> void:
	if is_instance_valid(game_over_screen):
		game_over_screen.visible = false
	_cancel_current_action()
	game_manager.start_new_game()
	_center_camera()
	_render_full_map()
	_update_ui()
	_show_toast("새 게임을 시작했습니다.")


## 단축키 처리 (ShortcutManager)
func _handle_shortcut(event: InputEventKey) -> void:
	if event.is_action_pressed("pause_toggle") or event.keycode == KEY_SPACE:
		game_manager.simulation_clock.toggle_pause()
		_update_speed_display()
	elif event.is_action_pressed("speed_1x") or event.keycode == KEY_1:
		game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.NORMAL)
		_update_speed_display()
	elif event.is_action_pressed("speed_2x") or event.keycode == KEY_2:
		game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.FAST)
		_update_speed_display()
	elif event.is_action_pressed("speed_4x") or event.keycode == KEY_4:
		game_manager.simulation_clock.set_speed(SimulationClock.SpeedMode.VERY_FAST)
		_update_speed_display()
	elif event.is_action_pressed("undo") or event.keycode == KEY_U:
		game_manager.undo_redo.undo()
		_render_full_map()
	elif event.is_action_pressed("redo") or event.keycode == KEY_R:
		game_manager.undo_redo.redo()
		_render_full_map()
	elif event.is_action_pressed("save_game") or event.keycode == KEY_S:
		var result := game_manager.save_manager.save_to_slot(1)
		_show_toast(result.message)
	elif event.is_action_pressed("cancel") or event.keycode == KEY_ESCAPE:
		_cancel_current_action()
	elif event.is_action_pressed("tool_line") or event.keycode == KEY_L:
		_show_toast("역을 클릭하거나 드래그하여 노선을 연결하세요")
	elif event.is_action_pressed("tool_bridge") or event.keycode == KEY_B:
		_show_toast("다리: 노선이 강을 통과할 때 자동 건설됩니다 (보유: %d개)" % game_manager.game_state.available_bridges)
	elif event.is_action_pressed("tool_tunnel") or event.keycode == KEY_T:
		_show_toast("터널: 노선이 산을 통과할 때 자동 건설됩니다 (보유: %d개)" % game_manager.game_state.available_tunnels)
	elif event.is_action_pressed("focus_selection") or event.keycode == KEY_F:
		_focus_selected_station()
	elif event.is_action_pressed("toggle_info_panel") or event.keycode == KEY_TAB:
		if is_instance_valid(right_panel):
			right_panel.visible = not right_panel.visible
	elif event.keycode == KEY_C or event.keycode == KEY_HOME:
		_center_camera()


## 키보드 WASD / 방향키 카메라 이동 처리
func _process_keyboard_camera(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	
	if pan != Vector2.ZERO:
		var speed: float = 750.0 / camera.zoom.x
		camera.position += pan.normalized() * speed * delta


## 마우스 버튼 처리 (역 드래그 연결 & 클릭 연결 완벽 지원)
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var world_pos := _get_world_mouse_position()
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var station_id := _find_station_at(world_pos)
			
			if not station_id.is_empty():
				# 1. 역을 클릭한 경우
				if not _connecting_from_station_id.is_empty() and _connecting_from_station_id != station_id:
					# 이미 시작 역이 선택된 상태에서 다른 역 클릭 (클릭-클릭 연결 방식)
					_execute_connect(_connecting_from_station_id, station_id)
					_connecting_from_station_id = ""
					_is_dragging_connection = false
					queue_redraw()
				elif _connecting_from_station_id == station_id:
					# 같은 역을 다시 클릭하면 연결 대기 해제
					_connecting_from_station_id = ""
					_is_dragging_connection = false
					queue_redraw()
				else:
					# 새로운 연결 시작 (드래그 시작 또는 첫 번째 클릭)
					_connecting_from_station_id = station_id
					_is_dragging_connection = true
					_selected_station_id = station_id
					_update_right_panel()
					_show_toast("다른 역으로 드래그하거나 클릭하여 연결하세요")
					queue_redraw()
			else:
				# 2. 빈 공간을 클릭한 경우
				if not _connecting_from_station_id.is_empty() and not _is_dragging_connection:
					_connecting_from_station_id = ""
					queue_redraw()
				
				# 빈 공간에서 카메라 드래그 시작
				_is_dragging_camera = true
				_drag_button = MOUSE_BUTTON_LEFT
				_drag_distance = 0.0
		else:
			# 마우스 버튼을 놓았을 때 (Release)
			if _is_dragging_connection:
				_is_dragging_connection = false
				var target_station_id := _find_station_at(world_pos)
				
				if not target_station_id.is_empty() and target_station_id != _connecting_from_station_id:
					# 다른 역 위에서 마우스를 놓았음 (드래그-앤-드롭 연결 성공!)
					_execute_connect(_connecting_from_station_id, target_station_id)
					_connecting_from_station_id = ""
					queue_redraw()
				elif target_station_id == _connecting_from_station_id or target_station_id.is_empty():
					# 같은 역이거나 빈 공간에서 마우스를 놓은 경우:
					# 클릭-클릭 방식으로 연결할 수 있도록 _connecting_from_station_id 유지
					queue_redraw()
			
			if _is_dragging_camera and _drag_button == MOUSE_BUTTON_LEFT:
				_is_dragging_camera = false
				if _drag_distance < 6.0:
					# 빈 공간 단순 클릭 시 선택 해제
					_selected_station_id = ""
					_connecting_from_station_id = ""
					_update_right_panel()
					queue_redraw()
	
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_is_dragging_camera = true
			_drag_button = MOUSE_BUTTON_RIGHT
			_drag_distance = 0.0
		else:
			if _is_dragging_camera and _drag_button == MOUSE_BUTTON_RIGHT:
				_is_dragging_camera = false
				if _drag_distance < 6.0:
					_cancel_current_action()
	
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_is_dragging_camera = true
			_drag_button = MOUSE_BUTTON_MIDDLE
			_drag_distance = 0.0
		else:
			_is_dragging_camera = false
	
	# 줌 (마우스 커서 중심 확대/축소)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at_mouse(1.15)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at_mouse(0.85)


## 두 역 연결 실행
func _execute_connect(from_id: String, to_id: String) -> void:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		return
	
	var result := game_manager.create_line(from_id, to_id)
	if result.success:
		_show_toast(result.message)
		_log_event(result.message)
		_render_full_map()
		_update_ui()
	else:
		_show_error("노선 연결 불가", result.message)
		_log_event("연결 실패: " + result.message)


## 하단 바 이벤트 로그 출력
func _log_event(text: String) -> void:
	if is_instance_valid(bottom_bar):
		var event_log := bottom_bar.get_node_or_null("HBoxContainer/EventLog") as Label
		if event_log:
			event_log.text = text


## 마우스 위치 중심 부드러운 줌
func _zoom_at_mouse(factor: float) -> void:
	var mouse_world_before := get_global_mouse_position()
	var new_zoom: Vector2 = (camera.zoom * factor).clamp(Vector2(0.25, 0.25), Vector2(3.5, 3.5))
	camera.zoom = new_zoom
	var mouse_world_after := get_global_mouse_position()
	camera.position += (mouse_world_before - mouse_world_after)


## 선택된 역으로 카메라 집중
func _focus_selected_station() -> void:
	if not _selected_station_id.is_empty():
		var station := game_manager.game_state.get_station(_selected_station_id)
		if station:
			camera.position = station.position
			_show_toast("역 %s(으)로 카메라 이동" % station.id)
	else:
		_center_camera()


## 마우스 이동 처리
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# 카메라 드래그
	if _is_dragging_camera:
		camera.position -= event.relative / camera.zoom
		_drag_distance += event.relative.length()
	
	# 역 호버 감지
	var world_pos := _get_world_mouse_position()
	_update_hover(world_pos)
	
	# 노선 연결 미리보기 갱신
	if not _connecting_from_station_id.is_empty():
		queue_redraw()


## 현재 작업 취소
func _cancel_current_action() -> void:
	_input_mode = InputMode.NORMAL
	_connecting_from_station_id = ""
	_is_dragging_connection = false
	_selected_station_id = ""
	_update_right_panel()
	queue_redraw()
	_show_toast("선택이 취소되었습니다.")


## 역 선택 시도
func _try_select_at(world_pos: Vector2) -> void:
	var station_id := _find_station_at(world_pos)
	if not station_id.is_empty():
		_selected_station_id = station_id
		EventBus.selection_changed.emit("station", station_id)
		_update_right_panel()
	else:
		_selected_station_id = ""
		_update_right_panel()


## 월드 좌표에서 역 찾기 (여유 반경 36px)
func _find_station_at(world_pos: Vector2) -> String:
	var click_radius := 36.0
	var closest_id := ""
	var closest_dist := INF
	
	for station in game_manager.game_state.get_all_stations():
		var dist := world_pos.distance_to(station.position)
		if dist < click_radius and dist < closest_dist:
			closest_dist = dist
			closest_id = station.id
	
	return closest_id


## 호버 업데이트
func _update_hover(world_pos: Vector2) -> void:
	var new_hover := _find_station_at(world_pos)
	if new_hover != _hovered_station_id:
		_hovered_station_id = new_hover
		queue_redraw()


## 월드 마우스 좌표 반환
func _get_world_mouse_position() -> Vector2:
	return get_global_mouse_position()


## 카메라 중앙 정렬
func _center_camera() -> void:
	var balance := GameConfig.balance
	camera.position = Vector2(
		balance.play_area_margin + balance.play_area_width * 0.5,
		balance.play_area_margin + balance.play_area_height * 0.5
	)
	camera.zoom = Vector2(0.85, 0.85)


# =============================================
# 렌더링
# =============================================
# 렌더링 (디자인 2: 노르딕 아키텍처 라이트 / 클린 페이퍼 블루프린트)
# =============================================

func _draw() -> void:
	_draw_paper_background()
	_draw_terrain()
	_draw_lines()
	_draw_line_preview()
	_draw_stations()
	_draw_passengers_on_stations()
	_draw_trains()


## 웜 아이보리 페이퍼 캔버스 및 아키텍처 블루프린트 모안선 그리기
func _draw_paper_background() -> void:
	var balance := GameConfig.balance
	var play_area := Rect2(
		Vector2(balance.play_area_margin, balance.play_area_margin),
		Vector2(balance.play_area_width, balance.play_area_height)
	)
	
	# 1. 따뜻한 아이보리 페이퍼 캔버스
	draw_rect(play_area, Color("#F8F6F0"), true)
	
	# 2. 정밀한 아키텍처 그리드 (64px 간격 은은한 모안선)
	var grid_spacing := 64.0
	var grid_color := Color("#E8E4DA", 0.75)
	
	var x := play_area.position.x
	while x <= play_area.position.x + play_area.size.x:
		draw_line(Vector2(x, play_area.position.y), Vector2(x, play_area.position.y + play_area.size.y), grid_color, 1.0)
		x += grid_spacing
	
	var y := play_area.position.y
	while y <= play_area.position.y + play_area.size.y:
		draw_line(Vector2(play_area.position.x, y), Vector2(play_area.position.x + play_area.size.x, y), grid_color, 1.0)
		y += grid_spacing
	
	# 3. 맵 외곽 테두리선
	draw_rect(play_area, Color("#D5CEC2"), false, 1.5)


## 지형 그리기 (스칸디나비안 블루 강 & 세이지 그레이 산)
func _draw_terrain() -> void:
	for terrain in game_manager.game_state.get_all_terrains():
		match terrain.terrain_type:
			TerrainEntity.TerrainType.RIVER:
				# 노르딕 블루 스칸디나비안 강
				draw_colored_polygon(terrain.polygon, Color("#A2C5DC", 0.92))
				draw_polyline(terrain.polygon, Color("#5A8AA8", 1.0), 2.5)
			TerrainEntity.TerrainType.MOUNTAIN:
				# 건축 도면 스타일의 부드러운 세이지 그레이 산
				draw_colored_polygon(terrain.polygon, Color("#DCE3DB", 0.92))
				draw_polyline(terrain.polygon, Color("#9DB09B", 1.0), 2.0)


## 노선 그리기 (고대비 스위스 트랜짓 라인 & 다리/터널)
func _draw_lines() -> void:
	var positions := game_manager.game_state.get_station_positions()
	
	for line in game_manager.game_state.get_all_lines():
		if line.get_station_count() < 2:
			continue
		
		for i in range(line.station_ids.size() - 1):
			var from_id: String = line.station_ids[i]
			var to_id: String = line.station_ids[i + 1]
			var points: Array[Vector2] = line.get_path_points(from_id, to_id, positions)
			
			if points.size() >= 2:
				var packed := PackedVector2Array(points)
				# 굵고 선명한 6px 노선 라인
				draw_polyline(packed, line.color, 6.0, true)
	
	# 다리 표시 (화이트 필 + 블루 교각 마커)
	for bridge in game_manager.game_state.bridges.values():
		var b_rect := Rect2(bridge.position - Vector2(10, 6), Vector2(20, 12))
		draw_rect(b_rect, Color("#FFFFFF"), true)
		draw_rect(b_rect, Color("#15529E"), false, 2.0)
		draw_line(bridge.position - Vector2(10, 0), bridge.position + Vector2(10, 0), Color("#15529E"), 2.5)
	
	# 터널 표시 (다크 슬레이트 아치 마커)
	for tunnel in game_manager.game_state.tunnels.values():
		draw_circle(tunnel.position, 9.0, Color("#334155"))
		draw_arc(tunnel.position, 12.0, PI, TAU, 16, Color("#1E293B"), 2.5)


## 노선 연결 미리보기 (마우스 실시간 추적 러버밴드 + 자석 스냅 + 지형 경고)
func _draw_line_preview() -> void:
	if _connecting_from_station_id.is_empty():
		return
	
	var from_station := game_manager.game_state.get_station(_connecting_from_station_id)
	if from_station == null:
		return
	
	var mouse_pos := get_global_mouse_position()
	var target_pos := mouse_pos
	var is_snapped := false
	
	# 목표 역 호버 시 스냅 및 하이라이트
	if not _hovered_station_id.is_empty() and _hovered_station_id != _connecting_from_station_id:
		var target_station := game_manager.game_state.get_station(_hovered_station_id)
		if target_station:
			target_pos = target_station.position
			is_snapped = true
	
	# 시작 역 강조 (선명한 로열 블루 링 + 중심점)
	draw_arc(from_station.position, 28.0, 0, TAU, 32, Color("#1D5299"), 3.5)
	draw_circle(from_station.position, 7.0, Color("#1D5299"))
	
	# 지형 장애 및 자원 부족 여부 실시간 검사
	var seg_check := game_manager.terrain_checker.check_segment(from_station.position, target_pos)
	var blocked := false
	var warning_msg := ""
	if seg_check.needs_bridge and game_manager.game_state.available_bridges <= 0:
		blocked = true
		warning_msg = "다리 부족"
	elif seg_check.needs_tunnel and game_manager.game_state.available_tunnels <= 0:
		blocked = true
		warning_msg = "터널 부족"
	
	var preview_color := Color("#15529E") if not blocked else Color("#DC2626")
	
	if is_snapped:
		# 목표 역 스냅 상태: 고광택 글로우 + 메인 라인 + 목표 역 타겟 링
		draw_line(from_station.position, target_pos, Color(preview_color.r, preview_color.g, preview_color.b, 0.25), 12.0)
		draw_line(from_station.position, target_pos, preview_color, 6.0)
		draw_arc(target_pos, 32.0, 0, TAU, 32, preview_color, 4.0)
		
		var font := ThemeDB.fallback_font
		if blocked:
			draw_string(font, target_pos + Vector2(-30, -38), "⚠ " + warning_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#DC2626"))
		else:
			draw_string(font, target_pos + Vector2(-36, -38), "✔ 클릭하여 연결", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#1D5299"))
	else:
		# 마우스 커서 추적: 고해상도 점선 안내선 + 커서 타겟 링
		draw_dashed_line(from_station.position, target_pos, preview_color, 4.5, 10.0)
		draw_circle(target_pos, 6.0, preview_color)
		draw_arc(target_pos, 14.0, 0, TAU, 24, Color(preview_color.r, preview_color.g, preview_color.b, 0.7), 2.0)
		
		if blocked:
			var font := ThemeDB.fallback_font
			draw_string(font, target_pos + Vector2(18, -8), "⚠ " + warning_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#DC2626"))


## 역 그리기 (선명한 3색 + 짙은 슬레이트 아웃라인 + 화이트 코어)
func _draw_stations() -> void:
	for station in game_manager.game_state.get_all_stations():
		var pos: Vector2 = station.position
		var size := 20.0
		var fill_color: Color = station.color
		var outline_color := Color("#1E293B")  # 다크 슬레이트 아웃라인
		var outline_width := 3.5
		
		# 호버/선택 효과
		if station.id == _hovered_station_id:
			size = 23.0
			outline_width = 4.0
			draw_arc(pos, size + 8.0, 0, TAU, 32, Color("#1D5299", 0.6), 2.5)
		if station.id == _selected_station_id or station.id == _connecting_from_station_id:
			draw_arc(pos, size + 10.0, 0, TAU, 32, Color("#1D5299"), 3.0)
		
		# 혼잡 상태 색상 오버레이
		match station.congestion_state:
			StationEntity.CongestionState.WARNING:
				outline_color = Color("#D97706")  # 앰버
				outline_width = 4.5
			StationEntity.CongestionState.DANGER:
				outline_color = Color("#DC2626")  # 크림슨
				outline_width = 5.0
		
		# 기하학 역 본체 그리기
		match station.shape:
			StationEntity.Shape.CIRCLE:
				draw_circle(pos, size, fill_color)
				draw_arc(pos, size, 0, TAU, 32, outline_color, outline_width)
				draw_circle(pos, 5.0, Color.WHITE)
			StationEntity.Shape.TRIANGLE:
				var tri := PackedVector2Array([
					pos + Vector2(0, -size * 1.15),
					pos + Vector2(size, size * 0.7),
					pos + Vector2(-size, size * 0.7)
				])
				draw_colored_polygon(tri, fill_color)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), outline_color, outline_width)
				draw_circle(pos + Vector2(0, size * 0.1), 4.0, Color.WHITE)
			StationEntity.Shape.SQUARE:
				var rect := Rect2(pos - Vector2(size, size), Vector2(size * 2, size * 2))
				draw_rect(rect, fill_color, true)
				draw_rect(rect, outline_color, false, outline_width)
				draw_circle(pos, 5.0, Color.WHITE)
		
		# 승객 수 텍스트 배지 (먹색 차콜)
		var count: int = station.get_passenger_count()
		if count > 0:
			var label_text := "%d" % count
			var label_color := Color("#1C2024")
			
			match station.congestion_state:
				StationEntity.CongestionState.WARNING:
					label_color = Color("#D97706")
					label_text = "%d ⚠" % count
				StationEntity.CongestionState.DANGER:
					label_color = Color("#DC2626")
					label_text = "%d !" % count
			
			var font := ThemeDB.fallback_font
			var font_size := 14
			var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			
			# 깔끔한 화이트 배지 카드
			var badge_rect := Rect2(pos + Vector2(-text_size.x * 0.5 - 6, -size - 22), Vector2(text_size.x + 12, 18))
			draw_rect(badge_rect, Color("#FFFFFF", 0.95), true)
			draw_rect(badge_rect, Color("#D0D7DE"), false, 1.0)
			draw_string(font, pos + Vector2(-text_size.x * 0.5, -size - 8), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)


## 역 대기 승객 표시 (작은 기하학 아이콘)
func _draw_passengers_on_stations() -> void:
	for station in game_manager.game_state.get_all_stations():
		var passengers: Array = station.waiting_passengers
		var max_display := mini(passengers.size(), 12)
		
		for i in range(max_display):
			var passenger: PassengerEntity = passengers[i]
			var offset := Vector2(
				(i % 4) * 11 - 16,
				(i / 4) * 11 + 26
			)
			var ppos: Vector2 = station.position + offset
			var psize := 4.5
			var outline := Color("#1E293B")
			
			# 목적지 모양으로 표시
			match passenger.destination_shape:
				StationEntity.Shape.CIRCLE:
					draw_circle(ppos, psize, passenger.destination_color)
					draw_arc(ppos, psize, 0, TAU, 16, outline, 1.0)
				StationEntity.Shape.TRIANGLE:
					var tri := PackedVector2Array([
						ppos + Vector2(0, -psize),
						ppos + Vector2(psize * 0.866, psize * 0.5),
						ppos + Vector2(-psize * 0.866, psize * 0.5)
					])
					draw_colored_polygon(tri, passenger.destination_color)
					draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), outline, 1.0)
				StationEntity.Shape.SQUARE:
					var rect := Rect2(ppos - Vector2(psize, psize), Vector2(psize * 2, psize * 2))
					draw_rect(rect, passenger.destination_color, true)
					draw_rect(rect, outline, false, 1.0)


## 열차 그리기 (스위스 모던 메트로 스타일: 화이트 바디 + 라인 컬러 스트라이프)
func _draw_trains() -> void:
	for train in game_manager.game_state.get_all_trains():
		if train.operation_state == TrainEntity.OperationState.IDLE:
			continue
		
		var pos: Vector2
		if train.operation_state == TrainEntity.OperationState.MOVING:
			pos = train.get_current_position()
		else:
			var station := game_manager.game_state.get_station(train.current_station_id)
			if station:
				pos = station.position + Vector2(0, -32)
			else:
				continue
		
		if pos == Vector2.ZERO:
			continue
		
		var line := game_manager.game_state.get_line(train.line_id)
		var train_color: Color = line.color if line else Color("#15529E")
		
		# 노르딕 라이트 열차: 깔끔한 화이트 바디 + 상단 라인 컬러 스트라이프 + 다크 슬레이트 아웃라인
		var train_rect := Rect2(pos - Vector2(14, 7), Vector2(28, 14))
		draw_rect(train_rect, Color("#FFFFFF"), true)
		draw_rect(Rect2(pos - Vector2(14, 7), Vector2(28, 4)), train_color, true)
		draw_rect(train_rect, Color("#1F2937"), false, 1.5)
		
		# 탑승 인원 표시
		var passengers: int = train.get_total_passengers()
		if passengers > 0:
			var font := ThemeDB.fallback_font
			var text := "%d" % passengers
			draw_string(font, pos + Vector2(-4, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#1F2937"))


## 전체 맵 렌더링 갱신
func _render_full_map() -> void:
	queue_redraw()


## 열차 렌더링 업데이트
func _update_train_rendering() -> void:
	if not game_manager.simulation_clock.is_paused():
		queue_redraw()


# =============================================
# UI 업데이트
# =============================================

func _update_ui() -> void:
	_update_top_bar()
	_update_speed_display()


func _update_top_bar() -> void:
	if not is_instance_valid(top_bar):
		return
	
	var gs := game_manager.game_state
	var balance := GameConfig.balance
	
	# 시간
	var time_label := top_bar.get_node_or_null("TimeLabel")
	if time_label:
		time_label.text = "Day %d  %s" % [gs.get_game_day(), game_manager.simulation_clock.get_time_text()]
	
	# 점수
	var score_label := top_bar.get_node_or_null("ScoreLabel")
	if score_label:
		var score := gs.total_arrived_passengers * balance.score_per_arrived_passenger
		score_label.text = "점수: %d" % score
	
	# 자원
	var resource_label := top_bar.get_node_or_null("ResourceLabel")
	if resource_label:
		resource_label.text = "🌉 %d  🚇 %d  🚂 %d" % [gs.available_bridges, gs.available_tunnels, gs.available_trains]


func _update_speed_display() -> void:
	var speed_label := top_bar.get_node_or_null("SpeedLabel") if is_instance_valid(top_bar) else null
	if speed_label:
		speed_label.text = game_manager.simulation_clock.get_speed_text()


func _update_right_panel() -> void:
	if not is_instance_valid(right_panel):
		return
	
	var info_label := right_panel.get_node_or_null("InfoLabel")
	if info_label == null:
		return
	
	if _selected_station_id.is_empty():
		info_label.text = "역을 선택하면 정보가 표시됩니다."
		right_panel.visible = false
		return
	
	right_panel.visible = true
	var station := game_manager.game_state.get_station(_selected_station_id)
	if station == null:
		info_label.text = "역을 찾을 수 없습니다."
		return
	
	var balance := GameConfig.balance
	var shape_name := StationEntity.shape_name(station.shape)
	var state_text := ""
	match station.congestion_state:
		StationEntity.CongestionState.NORMAL: state_text = "정상"
		StationEntity.CongestionState.WARNING: state_text = "⚠ 주의"
		StationEntity.CongestionState.DANGER: state_text = "! 위험"
	
	info_label.text = "%s\n모양: %s\n승객: %d / %d %s\n노선: %d / %d개 연결" % [
		station.id,
		shape_name,
		station.get_passenger_count(),
		balance.max_passengers_per_station,
		state_text,
		station.connected_line_ids.size(),
		balance.max_lines_per_station
	]


## 토스트 메시지 표시
func _show_toast(message: String) -> void:
	if is_instance_valid(hint_label):
		hint_label.text = message
		hint_label.visible = true
		if is_inside_tree():
			var tree := get_tree()
			if tree != null:
				tree.create_timer(3.5).timeout.connect(func():
					if is_instance_valid(hint_label):
						hint_label.visible = false
				)


## 노르딕 아키텍처 라이트 (디자인 2) UI 테마 스타일링 적용
func _apply_nordic_theme() -> void:
	if not is_instance_valid(ui_layer):
		return
	
	# 1. 상단 바 (TopBar) 카드 스타일
	if is_instance_valid(top_bar):
		var top_style := StyleBoxFlat.new()
		top_style.bg_color = Color("#FFFFFF", 0.95)
		top_style.border_color = Color("#D0D7DE")
		top_style.set_border_width_all(1)
		top_style.set_corner_radius_all(10)
		top_style.content_margin_left = 20
		top_style.content_margin_right = 20
		top_style.content_margin_top = 8
		top_style.content_margin_bottom = 8
		top_style.shadow_color = Color(0, 0, 0, 0.05)
		top_style.shadow_size = 4
		top_style.shadow_offset = Vector2(0, 2)
		top_bar.add_theme_stylebox_override("panel", top_style)
		
		# 라벨 색상 설정 (다크 먹색 잉크)
		for label_name in ["TimeLabel", "SpeedLabel", "ScoreLabel", "ResourceLabel"]:
			var lbl := top_bar.get_node_or_null("HBoxContainer/" + label_name) as Label
			if lbl:
				lbl.add_theme_color_override("font_color", Color("#1C2024"))
		
		# 배속 버튼들 스타일링 (필 형태)
		var speed_btns := top_bar.get_node_or_null("HBoxContainer/SpeedButtons")
		if speed_btns:
			for btn in speed_btns.get_children():
				if btn is Button:
					_style_pill_button(btn)
	
	# 2. 좌측 도구 레일 (LeftRail)
	if is_instance_valid(left_rail):
		for child in left_rail.get_children():
			if child is Button:
				_style_tool_button(child)
	
	# 3. 우측 정보 패널 (RightPanel)
	if is_instance_valid(right_panel):
		var right_style := StyleBoxFlat.new()
		right_style.bg_color = Color("#FFFFFF", 0.96)
		right_style.border_color = Color("#D0D7DE")
		right_style.set_border_width_all(1)
		right_style.set_corner_radius_all(10)
		right_style.content_margin_left = 16
		right_style.content_margin_right = 16
		right_style.content_margin_top = 16
		right_style.content_margin_bottom = 16
		right_style.shadow_color = Color(0, 0, 0, 0.05)
		right_style.shadow_size = 4
		right_panel.add_theme_stylebox_override("panel", right_style)
		
		var title_lbl := right_panel.get_node_or_null("VBoxContainer/PanelTitle") as Label
		if title_lbl:
			title_lbl.add_theme_color_override("font_color", Color("#15529E"))
		var info_lbl := right_panel.get_node_or_null("VBoxContainer/InfoLabel") as Label
		if info_lbl:
			info_lbl.add_theme_color_override("font_color", Color("#1C2024"))
	
	# 4. 하단 상태 바 (BottomBar)
	if is_instance_valid(bottom_bar):
		var btm_style := StyleBoxFlat.new()
		btm_style.bg_color = Color("#FFFFFF", 0.95)
		btm_style.border_color = Color("#D0D7DE")
		btm_style.set_border_width_all(1)
		btm_style.set_corner_radius_all(8)
		btm_style.content_margin_left = 16
		btm_style.content_margin_right = 16
		btm_style.content_margin_top = 8
		btm_style.content_margin_bottom = 8
		bottom_bar.add_theme_stylebox_override("panel", btm_style)
		
		var event_log := bottom_bar.get_node_or_null("HBoxContainer/EventLog") as Label
		if event_log:
			event_log.add_theme_color_override("font_color", Color("#334155"))
	
	# 5. 토스트 힌트 라벨 (HintLabel)
	if is_instance_valid(hint_label):
		var hint_style := StyleBoxFlat.new()
		hint_style.bg_color = Color("#1E293B", 0.92)  # 선명한 차콜 플로팅 필
		hint_style.set_corner_radius_all(16)
		hint_style.content_margin_left = 18
		hint_style.content_margin_right = 18
		hint_style.content_margin_top = 8
		hint_style.content_margin_bottom = 8
		hint_label.add_theme_stylebox_override("normal", hint_style)
		hint_label.add_theme_color_override("font_color", Color("#FFFFFF"))


func _style_pill_button(btn: Button) -> void:
	btn.flat = false
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color("#F6F8FA")
	normal_box.border_color = Color("#D0D7DE")
	normal_box.set_border_width_all(1)
	normal_box.set_corner_radius_all(6)
	normal_box.content_margin_left = 10
	normal_box.content_margin_right = 10
	normal_box.content_margin_top = 4
	normal_box.content_margin_bottom = 4
	
	var hover_box := normal_box.duplicate() as StyleBoxFlat
	hover_box.bg_color = Color("#EBF3FE")
	hover_box.border_color = Color("#1D5299")
	
	var pressed_box := normal_box.duplicate() as StyleBoxFlat
	pressed_box.bg_color = Color("#1D5299")
	
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", pressed_box)
	btn.add_theme_color_override("font_color", Color("#1C2024"))
	btn.add_theme_color_override("font_hover_color", Color("#1D5299"))
	btn.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))


func _style_tool_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(40, 40)
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color("#FFFFFF", 0.95)
	normal_box.border_color = Color("#D0D7DE")
	normal_box.set_border_width_all(1)
	normal_box.set_corner_radius_all(8)
	normal_box.shadow_color = Color(0, 0, 0, 0.05)
	normal_box.shadow_size = 2
	
	var hover_box := normal_box.duplicate() as StyleBoxFlat
	hover_box.bg_color = Color("#EBF3FE")
	hover_box.border_color = Color("#1D5299")
	
	var pressed_box := normal_box.duplicate() as StyleBoxFlat
	pressed_box.bg_color = Color("#1D5299")
	
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", pressed_box)
	btn.add_theme_color_override("font_color", Color("#1C2024"))
	btn.add_theme_color_override("font_hover_color", Color("#1D5299"))
	btn.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))


## 오류 메시지 표시
func _show_error(title: String, message: String) -> void:
	EventBus.error_message.emit(title, message, "")
	_show_toast("⚠ " + message)


## 이벤트 연결
func _connect_events() -> void:
	EventBus.game_over.connect(_on_game_over)
	EventBus.hint_requested.connect(_on_hint_requested)
	EventBus.station_congestion_changed.connect(_on_congestion_changed)
	
	EventBus.line_created.connect(func(line_data):
		_log_event("노선 개통: %s" % line_data.get("name", ""))
		_render_full_map()
		_update_ui()
	)
	EventBus.line_modified.connect(func(line_id):
		var line := game_manager.game_state.get_line(line_id)
		var line_name: String = line.name if line != null else line_id
		_log_event("노선 연장: %s" % line_name)
		_render_full_map()
		_update_ui()
	)
	EventBus.station_created.connect(func(station_data):
		_log_event("새로운 역 등장: %s" % station_data.get("id", ""))
		_render_full_map()
	)
	EventBus.bridge_built.connect(func(_b):
		_render_full_map()
		_update_ui()
	)
	EventBus.tunnel_built.connect(func(_t):
		_render_full_map()
		_update_ui()
	)
	EventBus.action_undone.connect(func(desc):
		_show_toast("실행 취소: " + desc)
		_render_full_map()
		_update_ui()
	)
	EventBus.action_redone.connect(func(desc):
		_show_toast("다시 실행: " + desc)
		_render_full_map()
		_update_ui()
	)


func _on_game_over(result_data: Dictionary) -> void:
	if is_instance_valid(game_over_screen):
		game_over_screen.visible = true
		var result_label := game_over_screen.get_node_or_null("ResultLabel")
		if result_label:
			result_label.text = "게임 종료!\n\n" + \
				"총 점수: %d\n" % result_data.get("total_score", 0) + \
				"도착 승객: %d명\n" % result_data.get("arrived_passengers", 0) + \
				"생존 일수: %d일\n" % result_data.get("survival_days", 0) + \
				"최대 동시 승객: %d명\n" % result_data.get("max_simultaneous_passengers", 0) + \
				"노선: %d개  열차: %d대\n" % [result_data.get("total_lines", 0), result_data.get("total_trains", 0)] + \
				"다리: %d개  터널: %d개" % [result_data.get("total_bridges", 0), result_data.get("total_tunnels", 0)]


func _on_hint_requested(hint_text: String) -> void:
	_show_toast(hint_text)


func _on_congestion_changed(station_id: String, count: int, state: String) -> void:
	queue_redraw()
	match state:
		"WARNING":
			_show_toast("⚠ 역 %s 주의: %d명" % [station_id, count])
		"DANGER":
			_show_toast("! 역 %s 위험: %d명" % [station_id, count])
