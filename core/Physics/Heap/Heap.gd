class_name Heap
extends RefCounted

## Comparator:
## Returns true if a has higher priority than b
## (i.e. a should be above b in the heap)
var _less: Callable

var _data: Array = []

# ----------------------------------------------------
# Initialization
# ----------------------------------------------------

func _init(comparator: Callable = Callable()):
	if comparator.is_valid():
		_less = comparator
	else:
		_less = _default_less

# ----------------------------------------------------
# Public API
# ----------------------------------------------------

func size() -> int:
	return _data.size()

func is_empty() -> bool:
	return _data.is_empty()

func peek():
	return _data[0] if _data.size() > 0 else null

func push(item) -> void:
	_data.append(item)
	_sift_up(_data.size() - 1)

func pop():
	if _data.is_empty():
		return null

	var root = _data[0]
	var last = _data.pop_back()

	if not _data.is_empty():
		_data[0] = last
		_sift_down(0)

	return root

func clear() -> void:
	_data.clear()

# ----------------------------------------------------
# Heap internals
# ----------------------------------------------------

func _sift_up(i: int) -> void:
	while i > 0:
		var parent := (i - 1) >> 1
		if _less.call(_data[i], _data[parent]):
			_swap(i, parent)
			i = parent
		else:
			break

func _sift_down(i: int) -> void:
	var n := _data.size()
	while true:
		var left := (i << 1) + 1
		var right := left + 1
		var best := i

		if left < n and _less.call(_data[left], _data[best]):
			best = left
		if right < n and _less.call(_data[right], _data[best]):
			best = right

		if best != i:
			_swap(i, best)
			i = best
		else:
			break

func _swap(i: int, j: int) -> void:
	var tmp = _data[i]
	_data[i] = _data[j]
	_data[j] = tmp

# ----------------------------------------------------
# Default comparator
# ----------------------------------------------------

func _default_less(a, b) -> bool:
	# Min-heap using built-in comparison
	return a < b


## Removes all items that do NOT satisfy the predicate
## Usage: heap.filter(func(task): return task.body != invalid_body)
func filter(predicate: Callable) -> void:
	var new_data = []
	for item in _data:
		if predicate.call(item):
			new_data.append(item)
	
	_data = new_data
	_rebuild_heap()

## Bottom-up heap construction (Floyd's algorithm)
## Efficiently restores heap property in O(n) time
func _rebuild_heap() -> void:
	var n = _data.size()
	# Start from the last non-leaf node and sift down
	for i in range((n >> 1) - 1, -1, -1):
		_sift_down(i)
