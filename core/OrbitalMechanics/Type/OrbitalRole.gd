# OrbitalRole.gd
extends RefCounted
class_name OrbitalRole

enum Type {
	STAR,
	PLANET,
	MOON,
	ASTEROID,
	SHIP,
	STATION,
	DEBRIS,
	UNASSIGNED,
	TEST_PARTICLE
}
