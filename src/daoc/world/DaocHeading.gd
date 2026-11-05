extends RefCounted
class_name DaocHeading

## P1-112 — LE CAP DAoC N EST PAS L ANGLE DU MOTEUR, et l ecart est de 90°.
##
## Mesure le 2026-09-22 en live par le GM, depuis un client d origine : notre
## personnage regardait la maison, sa boule de feu partait a 90° a GAUCHE, le
## serveur repondait « le rat n est pas visible » (DOL `IsObjectInFront` lit
## le cap) et une deconnexion / reconnexion nous rendait tournes de 90° a
## droite. Trois symptomes, une cause : le cap partait et revenait sans
## conversion.
##
## DOL (`Point2D.GetPointFromHeading`, Point2D.cs:80) : angle a = cap × 2π/4096,
## direction = (−sin a, +cos a) en X/Y DAoC. Donc cap 0 = +Y, 1024 = −X,
## 2048 = −Y, 3072 = +X. `GetHeading` fait l inverse : atan2(−dx, dy).
##
## Moteur (`DaocPlayerMotor.motor_compute_forward_vector`) : direction =
## (cos θ, sin θ), donc θ = 0 → +X, 90 → +Y. `rotation.y = −θ`.
##
## Les deux se recoupent par θ = cap_deg + 90 (mod 360). Tout passage entre le
## fil (0x88, 0xA9, 0xDA, 0xA1, 0x4B, zonejumps) et le moteur / une scene
## passe ICI, jamais par une regle de trois locale.

const UNITS_PER_TURN := 4096.0
## Decalage moteur − DOL, en degres. 90 : mesure, pas choisi.
const MOTOR_OFFSET_DEG := 90.0


## Cap DAoC (0..4095, bits hauts ignores) → heading_deg du moteur.
static func raw_to_motor_deg(raw: int) -> float:
	return fposmod(float(raw & 0x0fff) * 360.0 / UNITS_PER_TURN + MOTOR_OFFSET_DEG, 360.0)


## heading_deg du moteur → cap DAoC 0..4095.
static func motor_deg_to_raw(deg: float) -> int:
	return int(round(fposmod(deg - MOTOR_OFFSET_DEG, 360.0) / 360.0 * UNITS_PER_TURN)) & 0x0fff


## Cap DAoC → rotation.y (radians) d une scene dont l avant est +X local,
## la convention du joueur et des scenes du Lab.
static func raw_to_godot_yaw(raw: int) -> float:
	return -deg_to_rad(raw_to_motor_deg(raw))


## Direction DAoC (dx, dy) → cap DAoC, comme DOL `Point2D.GetHeading`.
static func raw_from_direction(dx: float, dy: float) -> int:
	var heading := atan2(-dx, dy) * UNITS_PER_TURN / TAU
	if heading < 0.0:
		heading += UNITS_PER_TURN
	return int(round(heading)) & 0x0fff


## Direction DAoC unitaire d un cap, comme DOL `GetPointFromHeading`.
static func direction_from_raw(raw: int) -> Vector2:
	var a := float(raw & 0x0fff) * TAU / UNITS_PER_TURN
	return Vector2(-sin(a), cos(a))
