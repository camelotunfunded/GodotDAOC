extends RefCounted
class_name DaocOpenDaocChecksum

const HEADER_TOTAL_SIZE: int = 12

## Verified against the target OpenDAoC PacketProcessor.CalculateChecksum source.
const SOURCE: String = "OpenDAoC PacketProcessor.CalculateChecksum L723-L738"


func algorithm_status() -> Dictionary:
	return {
		"available": true,
		"reason": "",
		"source": SOURCE,
		"warning": "",
		"verified_against_server_source": true,
		"initial_values": "val1=0x7E val2=0x7E",
	}


func compute_checksum(packet_without_checksum: PackedByteArray) -> int:
	var val1 := 0x7e
	var val2 := 0x7e
	for b in packet_without_checksum:
		val1 = (val1 + (int(b) & 0xff)) & 0xff
		val2 = (val2 + val1) & 0xff
	return (val2 - (((val1 + val2) & 0xffff) << 8)) & 0xffff


func verify_checksum(full_packet: PackedByteArray) -> Dictionary:
	var status := algorithm_status()
	if not bool(status.get("available", false)):
		return {"ok": false, "available": false, "checksum_status": "checksum_algorithm_missing", "reason": status.get("reason", "checksum_algorithm_missing")}
	if full_packet.size() < HEADER_TOTAL_SIZE:
		return {"ok": false, "available": true, "checksum_status": "short_packet", "reason": "packet shorter than 12 bytes"}
	var declared_payload_size := _u16_be_read(full_packet, 0)
	var total_size := declared_payload_size + HEADER_TOTAL_SIZE
	if full_packet.size() < total_size or total_size < 2:
		return {"ok": false, "available": true, "checksum_status": "incomplete_packet", "declared_total_size": total_size, "available_size": full_packet.size()}
	var packet_without_checksum := full_packet.slice(0, total_size - 2)
	var expected := compute_checksum(packet_without_checksum)
	var actual := _u16_be_read(full_packet, total_size - 2)
	return {
		"ok": expected == actual,
		"available": true,
		"checksum_status": "ok" if expected == actual else "mismatch",
		"expected": expected,
		"actual": actual,
		"source": SOURCE,
	}


func _u16_be_read(data: PackedByteArray, offset: int) -> int:
	var i := int(offset)
	if i < 0 or i + 1 >= data.size():
		return 0
	return ((int(data[i]) & 0xff) << 8) | (int(data[i + 1]) & 0xff)
