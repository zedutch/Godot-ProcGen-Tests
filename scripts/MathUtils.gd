extends Node

func log2(s):
	return log(s) / log(2)

func is_int(s):
	return s - int(s) == 0