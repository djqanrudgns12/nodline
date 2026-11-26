## Undo/Redo 시스템
## PRD 8.3 참조
## 실행 취소/다시 실행 대상: 노선 생성, 수정, 삭제, 다리 건설, 터널 건설
class_name UndoRedoSystem
extends RefCounted

## 명령 인터페이스
class Command:
	var description: String
	
	func execute() -> void:
		pass
	
	func undo() -> void:
		pass

var _undo_stack: Array = []  # Array of Command
var _redo_stack: Array = []
var _max_history: int = 50


## 명령을 실행하고 히스토리에 추가한다.
func execute_command(command: Command) -> void:
	command.execute()
	_undo_stack.append(command)
	_redo_stack.clear()  # 새 명령 실행 시 redo 스택 초기화
	
	# 최대 히스토리 초과 시 오래된 항목 제거
	if _undo_stack.size() > _max_history:
		_undo_stack.pop_front()
	
	GameLogger.log_info("UNDO", "명령 실행: %s" % command.description)


## 실행 취소
func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	
	var command: Command = _undo_stack.pop_back()
	command.undo()
	_redo_stack.append(command)
	
	EventBus.action_undone.emit(command.description)
	GameLogger.log_info("UNDO", "실행 취소: %s" % command.description)
	return true


## 다시 실행
func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	
	var command: Command = _redo_stack.pop_back()
	command.execute()
	_undo_stack.append(command)
	
	EventBus.action_redone.emit(command.description)
	GameLogger.log_info("UNDO", "다시 실행: %s" % command.description)
	return true


## 실행 취소 가능 여부
func can_undo() -> bool:
	return not _undo_stack.is_empty()


## 다시 실행 가능 여부
func can_redo() -> bool:
	return not _redo_stack.is_empty()


## 히스토리 초기화
func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
