class_name MagneticUtils
extends RefCounted


static func get_polarity(node: Node) -> int:
	if node.has_method("get_magnetic_polarity"):
		return node.call("get_magnetic_polarity")
	if node.get("polarity") != null:
		return node.polarity
	return 0
