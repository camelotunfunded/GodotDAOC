class_name DaocMpkArchive
extends RefCounted

## Lecteur des archives MPAK du client (gamedata.mpk, charman/*.mpk...).
##
## Disposition relevee sur gamedata.mpk : « MPAK », u8 version, puis 16 octets
## brouilles par XOR avec leur rang (octet i ^ i) : u32 crc, u32 taille
## compressee du repertoire, u32 taille compressee du nom, u32 nombre de
## fichiers (petit-boutiste). Suivent trois flux zlib : le nom de l'archive,
## le repertoire (284 octets par fichier : nom sur 256, u32 date, u32 ?,
## u32 decalage decompresse, u32 taille, u32 decalage compresse relatif a la
## fin du repertoire, u32 taille compressee, u32 crc), puis les donnees.

const HEADER_SIZE := 21
const ENTRY_SIZE := 284

var path := ""
var entries: Dictionary = {}
var error := ""
var _data_start := 0


static func open(archive_path: String) -> DaocMpkArchive:
	var archive := DaocMpkArchive.new()
	archive.path = archive_path
	archive._read_directory()
	return archive


func _read_directory() -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "archive illisible"
		return
	var head := file.get_buffer(HEADER_SIZE)
	if head.size() < HEADER_SIZE or head.slice(0, 4).get_string_from_ascii() != "MPAK":
		error = "pas une archive MPAK"
		return
	var plain := PackedByteArray()
	for index in range(16):
		plain.append(int(head[5 + index]) ^ index)
	var directory_size := plain.decode_u32(4)
	var name_size := plain.decode_u32(8)
	var count := plain.decode_u32(12)
	file.seek(HEADER_SIZE + name_size)
	var directory := _inflate(file.get_buffer(directory_size), count * ENTRY_SIZE)
	if directory.size() < count * ENTRY_SIZE:
		error = "repertoire corrompu"
		return
	_data_start = HEADER_SIZE + name_size + directory_size
	for index in range(count):
		var at := index * ENTRY_SIZE
		var name := directory.slice(at, at + 256).get_string_from_ascii().to_lower()
		entries[name] = {
			"size": directory.decode_u32(at + 256 + 12),
			"offset": directory.decode_u32(at + 256 + 16),
			"compressed_size": directory.decode_u32(at + 256 + 20),
		}


func names() -> Array:
	var out := entries.keys()
	out.sort()
	return out


func read_file(name: String) -> PackedByteArray:
	var entry: Dictionary = entries.get(name.to_lower(), {}) as Dictionary
	if entry.is_empty():
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	file.seek(_data_start + int(entry["offset"]))
	return _inflate(file.get_buffer(int(entry["compressed_size"])), int(entry["size"]))


func read_text(name: String) -> String:
	return read_file(name).get_string_from_utf8()


static func _inflate(data: PackedByteArray, expected_size: int) -> PackedByteArray:
	# Godot : COMPRESSION_DEFLATE lit le flux zlib (en-tete 78 9c) tel quel.
	var out := data.decompress(maxi(expected_size, 1), FileAccess.COMPRESSION_DEFLATE)
	if out.size() == expected_size:
		return out
	return data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
