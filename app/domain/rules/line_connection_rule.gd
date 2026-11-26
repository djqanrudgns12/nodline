## 노선 연결 규칙 (Line Connection Rule)
## PRD 6.5 참조
## 역당 최대 5개 노선 연결 제한을 강제한다.
class_name LineConnectionRule
extends RefCounted


## 노선 연결 가능 여부를 검사한다.
## 반환: {valid: bool, reason: String}
static func can_connect(station: StationEntity, line_id: String, max_lines: int) -> Dictionary:
	# 이미 연결된 노선인지 확인
	if line_id in station.connected_line_ids:
		return {
			"valid": true,
			"reason": "이미 연결된 노선입니다."
		}
	
	# 최대 노선 수 확인
	if not station.can_connect_line(max_lines):
		return {
			"valid": false,
			"reason": "노선을 연결할 수 없습니다. 이 역은 이미 %d개 노선이 연결되어 있습니다. (최대 %d개)" % [station.connected_line_ids.size(), max_lines]
		}
	
	return {
		"valid": true,
		"reason": ""
	}
