extends RefCounted
## 全體集資：挑哪些客人立刻收錢。

const Customer = preload("res://scripts/customer.gd")


static func choose(customers: Array, level: int) -> Array:
	var pool: Array = []
	for c in customers:
		if not _eligible(c):
			continue
		if level <= 1 and not _queued(c):
			continue
		pool.append(c)
	if level == 2:
		return _half(pool)
	return pool


static func _eligible(c) -> bool:
	if bool(c.get("is_thief")):
		return false
	var st := int(c.get("state"))
	return st != Customer.State.LEAVE and st != Customer.State.FLEE


static func _queued(c) -> bool:
	var st := int(c.get("state"))
	return st == Customer.State.QUEUE or st == Customer.State.PAYING


static func _half(pool: Array) -> Array:
	var need := int(ceil(float(pool.size()) / 2.0))
	if need >= pool.size():
		return pool
	var ranked: Array = pool.duplicate()
	ranked.sort_custom(func(a, b) -> bool:
		return _ahead(a, b)
	)
	var chosen: Array = []
	var i := 0
	while chosen.size() < need and i < ranked.size():
		var group: Array = []
		var anchor = ranked[i]
		while i < ranked.size() and _same_rank(anchor, ranked[i]):
			group.append(ranked[i])
			i += 1
		var slots := need - chosen.size()
		if group.size() <= slots:
			chosen.append_array(group)
		else:
			group.shuffle()
			for k in slots:
				chosen.append(group[k])
	return chosen


static func _ahead(a, b) -> bool:
	if _cart_n(a) != _cart_n(b):
		return _cart_n(a) > _cart_n(b)
	if _value(a) != _value(b):
		return _value(a) > _value(b)
	if _anger(a) != _anger(b):
		return _anger(a) > _anger(b)
	return false


static func _same_rank(a, b) -> bool:
	return _cart_n(a) == _cart_n(b) and _value(a) == _value(b) and _anger(a) == _anger(b)


static func _cart_n(c) -> int:
	return int(c.cart.size())


static func _value(c) -> int:
	return int(c.call("cart_total"))


static func _anger(c) -> int:
	return int(c.get("dissatisfaction"))
