extends RefCounted
class_name DaocOpenDaocEnvironmentCodec

## P1-94 — l'heure et la meteo, telles que le SERVEUR les dit.
##
## Jusqu'ici la scene Online restait sur `environment_time_hours` local : le
## 0x7E arrivait a chaque entree monde (CONFIRMED_LIVE des juillet) et etait
## compte parmi les opcodes « ignores sans tuer la session ». Le GM voyait le
## jour, nous la nuit — un probleme d'AUTORITE, pas de rendu.
##
##   0x7E Time (PacketLib168.SendTime), 8 octets, GROS-boutiste :
##     u32 heure de jeu en MILLISECONDES du jour (0 .. 86 400 000),
##     u32 increment : combien de ms de jeu par ms reelle (24 par defaut dans
##     DOL : un jour de jeu dure une heure reelle). Le serveur ne renvoie
##     l'heure qu'a l'entree monde et au changement de region : entre deux, le
##     client fait tourner l'horloge lui-meme a cet increment.
##
##   0x92 Weather (PacketLib168.SendWeather), 15 octets :
##     u32 x, u32 width, u16 fogdiffusion, u16 speed, u16 intensity, u8 0.
##     Un front vide (tout a zero) EFFACE la meteo. Ce sont exactement les
##     champs bruts que `DaocWeatherFrontState.configure` attend depuis P1-20K.

const OPCODE_TIME := 0x7E
const OPCODE_WEATHER := 0x92
const GAME_DAY_MS := 86_400_000


static func decode_time(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 8:
		return {"ok": false, "error": "time_payload_too_short", "size": payload.size()}
	var day_ms := _u32(payload, 0)
	var increment := _u32(payload, 4)
	return {
		"ok": true,
		"opcode": OPCODE_TIME,
		"game_day_ms": day_ms,
		"server_time_seconds": int(posmod(day_ms, GAME_DAY_MS) / 1000),
		"time_hours": float(posmod(day_ms, GAME_DAY_MS)) / 3_600_000.0,
		"day_increment": increment,
		"payload_size": payload.size(),
	}


static func decode_weather(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 14:
		return {"ok": false, "error": "weather_payload_too_short", "size": payload.size()}
	var raw := {
		"x": float(_u32(payload, 0)),
		"width": float(_u32(payload, 4)),
		"fogdiffusion": float(_u16(payload, 8)),
		"speed": float(_u16(payload, 10)),
		"intensity": float(_u16(payload, 12)),
	}
	return {
		"ok": true,
		"opcode": OPCODE_WEATHER,
		"raw": raw,
		"cleared": raw.x == 0.0 and raw.width == 0.0 and raw.intensity == 0.0,
		"payload_size": payload.size(),
	}


## Encodeurs, pour les suites a faux pair uniquement.
static func encode_time(day_ms: int, increment: int) -> PackedByteArray:
	var out := PackedByteArray()
	_w32(out, day_ms)
	_w32(out, increment)
	return out


static func encode_weather(x: int, width: int, fogdiffusion: int, speed: int, intensity: int) -> PackedByteArray:
	var out := PackedByteArray()
	_w32(out, x)
	_w32(out, width)
	_w16(out, fogdiffusion)
	_w16(out, speed)
	_w16(out, intensity)
	out.append(0)
	return out


static func _u16(p: PackedByteArray, o: int) -> int:
	return ((int(p[o]) & 0xff) << 8) | (int(p[o + 1]) & 0xff)


static func _u32(p: PackedByteArray, o: int) -> int:
	return (_u16(p, o) << 16) | _u16(p, o + 2)


static func _w16(out: PackedByteArray, v: int) -> void:
	out.append((v >> 8) & 0xff)
	out.append(v & 0xff)


static func _w32(out: PackedByteArray, v: int) -> void:
	_w16(out, (v >> 16) & 0xffff)
	_w16(out, v & 0xffff)
