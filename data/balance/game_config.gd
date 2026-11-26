## 게임 설정 싱글톤 (Autoload)
## GameBalanceConfig 리소스를 로드하여 전역에서 접근 가능하게 한다.
extends Node

var balance: GameBalanceConfig


func _ready() -> void:
	_load_balance_config()


func _load_balance_config() -> void:
	var path := "res://data/balance/default_balance.tres"
	if ResourceLoader.exists(path):
		balance = load(path) as GameBalanceConfig
	else:
		push_warning("GameConfig: 기본 밸런스 파일을 찾을 수 없습니다. 기본값을 사용합니다. 경로: %s" % path)
		balance = GameBalanceConfig.new()
