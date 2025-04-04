extends TextureProgressBar

var meter = 0 : set = _set_meter

func _set_meter(new_meter):
	var prev_meter = meter
	meter = min(max_value, new_meter)
	value = meter
	
	

func _init_meter(_meter):
	meter = _meter
	max_value = meter
	value = meter
	
