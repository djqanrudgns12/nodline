## 게임 밸런스 설정 리소스
## 모든 게임 수치를 한 곳에서 관리하여 매직 넘버를 제거한다.
## PRD 6.1 참조
class_name GameBalanceConfig
extends Resource

# === 역 (Station) ===
@export var max_lines_per_station: int = 5
@export var max_passengers_per_station: int = 15
@export var station_warning_threshold: int = 12
@export var station_danger_threshold: int = 14
@export var max_station_count: int = 20
@export var initial_station_count: int = 3

# === 승객 (Passenger) ===
@export var max_passengers_per_carriage: int = 5

# === 열차 (Train) ===
@export var max_carriages_per_train: int = 3
@export var initial_trains: int = 1
@export var initial_carriages: int = 1
@export var train_base_speed_px_per_sec: float = 120.0

# === 노선 (Line) ===
@export var initial_lines: int = 1
@export var line_crossing_speed_multiplier: float = 0.6
@export var line_crossing_radius_px: float = 24.0

# === 다리/터널 ===
@export var initial_bridges: int = 1
@export var initial_tunnels: int = 1

# === 시뮬레이션 시간 및 스폰 주기 ===
@export var day_duration_real_seconds: float = 120.0
@export var new_station_spawn_interval_hours: float = 24.0 # 기본 24시간마다 1개
@export var station_base_spawn_interval_hours: float = 24.0
@export var station_bonus_spawn_interval_hours: float = 12.0 # 12시간마다 보너스 판정
@export var station_bonus_spawn_chance: float = 0.25 # 25% 확률
@export var map_expansion_interval_days: float = 7.0 # 1주일마다 맵 확장
@export var map_expansion_rate: float = 0.10 # 10% 확장
@export var max_infrastructure_requirement_per_station: int = 1 # 다리나 터널이 2개씩 필요한 역 배치 금지
@export var grace_period_seconds: float = 30.0

# === 점수 ===
@export var score_per_arrived_passenger: int = 10
@export var score_per_survived_day: int = 50

# === 시간대별 승객 생성 배율 ===
@export var spawn_rate_early_morning: float = 0.55  # 05:00~07:00
@export var spawn_rate_rush_morning: float = 1.80   # 07:00~10:00
@export var spawn_rate_morning: float = 1.10         # 10:00~12:00
@export var spawn_rate_afternoon: float = 0.90       # 12:00~17:00
@export var spawn_rate_rush_evening: float = 2.10    # 17:00~20:00
@export var spawn_rate_evening: float = 1.20         # 20:00~23:00
@export var spawn_rate_night: float = 0.40           # 23:00~05:00

# === 역 색상 (게임 오브젝트 전용 — 디자인 2 노르딕 라이트 3색) ===
@export var station_color_blue: Color = Color("#1D5299")    # 로열 코발트 블루
@export var station_color_coral: Color = Color("#D84315")   # 코랄 크림슨 레드
@export var station_color_emerald: Color = Color("#2E7D32") # 포레스트 에메랄드 그린

# === UI 색상 토큰 (디자인 2: 노르딕 아키텍처 라이트) ===
@export var ui_bg: Color = Color("#F8F6F0")             # 따뜻한 아이보리 페이퍼
@export var ui_panel: Color = Color("#FFFFFF")          # 순백색 카드 패널
@export var ui_panel_accent: Color = Color("#F1EFE8")   # 부드러운 크림 강조색
@export var ui_text_primary: Color = Color("#1C2024")   # 짙은 먹색 차콜 본문
@export var ui_text_secondary: Color = Color("#57606A") # 차분한 슬레이트 회색
@export var ui_border: Color = Color("#D0D7DE")         # 얇고 섬세한 경계선
@export var ui_button_primary: Color = Color("#1D5299") # 북유럽 코발트 블루
@export var ui_warning: Color = Color("#D97706")        # 앰버 경고
@export var ui_success: Color = Color("#16A34A")        # 산뜻한 초록
@export var ui_danger: Color = Color("#DC2626")         # 선명한 레드 경보

# === 맵 생성 ===
@export var min_station_distance_px: float = 150.0
@export var play_area_width: float = 1600.0
@export var play_area_height: float = 900.0
@export var play_area_margin: float = 100.0


## 시간대에 따른 승객 생성 배율을 반환한다.
func get_spawn_rate_for_hour(hour: float) -> float:
	if hour >= 5.0 and hour < 7.0:
		return spawn_rate_early_morning
	elif hour >= 7.0 and hour < 10.0:
		return spawn_rate_rush_morning
	elif hour >= 10.0 and hour < 12.0:
		return spawn_rate_morning
	elif hour >= 12.0 and hour < 17.0:
		return spawn_rate_afternoon
	elif hour >= 17.0 and hour < 20.0:
		return spawn_rate_rush_evening
	elif hour >= 20.0 and hour < 23.0:
		return spawn_rate_evening
	else:
		return spawn_rate_night


## 역 색상 배열을 반환한다.
func get_station_colors() -> Array[Color]:
	return [station_color_blue, station_color_coral, station_color_emerald]
