extends RefCounted
## Personal + team COMBO (§11.7 / fetchcombo.md).
## Qualify: one delivery clears remaining guest list with ≥3 pieces.

signal changed

var personal: Array[int] = [0, 0]
var team: int = 0


func reset(seat_count: int = 1) -> void:
	personal = []
	for _i in maxi(1, seat_count):
		personal.append(0)
	team = 0
	changed.emit()


func personal_of(seat: int) -> int:
	if seat < 0 or seat >= personal.size():
		return 0
	return personal[seat]


func note_qualify(seat: int) -> void:
	_ensure_seat(seat)
	personal[seat] = int(personal[seat]) + 1
	team += 1
	changed.emit()


func note_break_personal(seat: int) -> void:
	_ensure_seat(seat)
	if int(personal[seat]) == 0:
		return
	personal[seat] = 0
	changed.emit()


func _ensure_seat(seat: int) -> void:
	while personal.size() <= seat:
		personal.append(0)
