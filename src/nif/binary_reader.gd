## NifBinaryReader — lecteur d'octets little-endian au-dessus de FileAccess.
##
## NIF est stocke en little-endian (defaut de FileAccess.big_endian = false).
## Regle d'or DAoC 4.2.2.0 (CONFIRME, voir NOTE_TERRAIN §11) : les booleens sont
## sur 1 OCTET, il n'y a pas de flag has_uv / has_triangles separe.
##
## Toute lecture passe par ici pour qu'on ait UN seul endroit qui connaisse
## l'encodage binaire (meme discipline que la conversion de coordonnees).
class_name NifBinaryReader
extends RefCounted

var _f: FileAccess = null
var path: String = ""


func open(p: String) -> bool:
	path = p
	_f = FileAccess.open(p, FileAccess.READ)
	if _f == null:
		push_error("NIF: impossible d'ouvrir %s (err %d)" % [p, FileAccess.get_open_error()])
		return false
	_f.big_endian = false  # NIF = little-endian
	return true


func close() -> void:
	if _f != null:
		_f.close()
		_f = null


# --- position / etat ---
func pos() -> int:
	return _f.get_position()

func length() -> int:
	return _f.get_length()

func eof() -> bool:
	return _f.get_position() >= _f.get_length()

func seek(p: int) -> void:
	_f.seek(p)

func skip(n: int) -> void:
	_f.seek(_f.get_position() + n)


# --- scalaires ---
func u8() -> int:
	return _f.get_8()

func u16() -> int:
	return _f.get_16()

func u32() -> int:
	return _f.get_32()

## Entier signe 32 bits (utilise pour les liens / refs : -1 = aucun).
func i32() -> int:
	var v: int = _f.get_32()
	return v - 0x100000000 if v >= 0x80000000 else v

func f32() -> float:
	return _f.get_float()

## Booleen DAoC 4.2.2.0 : 1 octet (PAS 4). CONFIRME.
func boolb() -> bool:
	return _f.get_8() != 0


# --- composes ---
func vec3() -> Vector3:
	return Vector3(f32(), f32(), f32())

func color4() -> Color:
	var r: float = f32()
	var g: float = f32()
	var b: float = f32()
	var a: float = f32()
	return Color(r, g, b, a)

## Matrice de rotation 3x3 stockee en row-major (m00,m01,m02, m10,...).
## On construit une Basis Godot telle que Basis * v reproduise NIF M * v
## (les colonnes de la Basis = images des vecteurs de base).
func matrix33() -> Basis:
	var m00: float = f32(); var m01: float = f32(); var m02: float = f32()
	var m10: float = f32(); var m11: float = f32(); var m12: float = f32()
	var m20: float = f32(); var m21: float = f32(); var m22: float = f32()
	return Basis(
		Vector3(m00, m10, m20),
		Vector3(m01, m11, m21),
		Vector3(m02, m12, m22)
	)

## Chaine prefixee par sa longueur (uint32). Utilisee pour le nom de TYPE de
## chaque bloc et pour les noms d'objets en NIF "ancien" (< 10.x).
func sized_string() -> String:
	var n: int = u32()
	if n < 0 or n > 65536:
		push_error("NIF: longueur de chaine absurde (%d) @0x%X — desync probable" % [n, pos()])
		return ""
	if n == 0:
		return ""
	var buf: PackedByteArray = _f.get_buffer(n)
	return buf.get_string_from_ascii()



## Lecture brute, utile aux helpers de peek/resync du lecteur NIF.
func read_bytes(n: int) -> PackedByteArray:
	return _f.get_buffer(n)


## Lit un uint32 sans avancer durablement.
func peek_u32() -> int:
	var p := pos()
	var v := u32()
	seek(p)
	return v


## Regarde une chaine prefixee uint32 sans log d'erreur et sans avancer.
## Sert a reconnaitre le header du bloc suivant dans les vieux NIF sans table de tailles.
func peek_sized_ascii(max_len: int = 60) -> String:
	var p := pos()
	if p + 4 > length():
		return ""
	var n := u32()
	if n < 2 or n > max_len or pos() + n > length():
		seek(p)
		return ""
	var buf := _f.get_buffer(n)
	seek(p)
	return buf.get_string_from_ascii()

## Ligne de l'en-tete terminee par \n (ex. "NetImmerse File Format, Version 4.2.2.0").
func line_string() -> String:
	var bytes := PackedByteArray()
	while not eof():
		var c: int = _f.get_8()
		if c == 0x0A:
			break
		bytes.append(c)
	return bytes.get_string_from_ascii()
