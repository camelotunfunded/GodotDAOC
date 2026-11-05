extends RefCounted
class_name DaocZoneTransitionPlanner

## Offline transition diagnostics. This bridges client zonejump entries to
## WorldDestination candidates without applying movement to the player.

const DaocWorldDestinationResolverScript = preload("res://src/daoc/world/DaocWorldDestinationResolver.gd")

const SCOPE: String = "P1-17E2 zone transition planning offline"
const CHECKPOINT: String = "P1_17E2_ZONE_TRANSITION_PLANNING_OFFLINE"


func plan_zonejump_entry(entry: Dictionary, context: Dictionary = {}) -> Dictionary:
	var source_zone_id: int = int(entry.get("source_zone", entry.get("zone", -1)))
	var target_zone_id: int = int(entry.get("target_zone", entry.get("target", -1)))
	var frame_confirmed: bool = bool(context.get("coordinate_frame_confirmed", context.get("server_coordinate_frame_confirmed", false)))
	var plan: Dictionary = {
		"ok": target_zone_id >= 0,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"transition_source": "zonejump",
		"zonejump_id": int(entry.get("id", -1)),
		"zonejump_name": str(entry.get("name", "")),
		"source_zone_id": source_zone_id,
		"target_zone_id": target_zone_id,
		"server_destination_available": false,
		"coordinate_frame_confirmed": frame_confirmed,
		"can_apply_runtime_spawn": false,
		"requires_human_validation": false,
		"destination_resolution": {},
		"reason": "",
		"entry": entry.duplicate(true),
	}
	if target_zone_id < 0:
		plan["reason"] = "zonejump has no target zone"
		return plan

	var resolver: RefCounted = DaocWorldDestinationResolverScript.new()
	var resolver_context: Dictionary = context.duplicate(true)
	if not resolver_context.has("destination_backend_preference"):
		resolver_context["destination_backend_preference"] = "auto"
	var destination_result: Dictionary = resolver.call("resolve_destination_for_zone", target_zone_id, resolver_context) as Dictionary
	var destination_available: bool = bool(destination_result.get("ok", false))
	plan["server_destination_available"] = destination_available
	plan["destination_resolution"] = destination_result.duplicate(true)
	if not destination_available:
		plan["reason"] = "no server destination candidate for target zone"
		return plan
	plan["requires_human_validation"] = not frame_confirmed
	plan["can_apply_runtime_spawn"] = frame_confirmed
	plan["reason"] = "server destination candidate ready but coordinate frame unconfirmed" if not frame_confirmed else "server destination candidate ready"
	return plan


func plan_zonejump_entries(entries: Array, context: Dictionary = {}) -> Dictionary:
	var plans: Array = []
	var target_count: int = 0
	var server_destination_count: int = 0
	var validation_required_count: int = 0
	var apply_ready_count: int = 0
	for item in entries:
		var entry: Dictionary = item as Dictionary
		var plan: Dictionary = plan_zonejump_entry(entry, context)
		plans.append(plan)
		if int(plan.get("target_zone_id", -1)) >= 0:
			target_count += 1
		if bool(plan.get("server_destination_available", false)):
			server_destination_count += 1
		if bool(plan.get("requires_human_validation", false)):
			validation_required_count += 1
		if bool(plan.get("can_apply_runtime_spawn", false)):
			apply_ready_count += 1
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"plan_count": plans.size(),
		"target_count": target_count,
		"server_destination_count": server_destination_count,
		"validation_required_count": validation_required_count,
		"apply_ready_count": apply_ready_count,
		"plans": plans,
	}


func destination_coverage_for_zones(zone_ids: Array, context: Dictionary = {}) -> Dictionary:
	var resolver: RefCounted = DaocWorldDestinationResolverScript.new()
	var resolver_context: Dictionary = context.duplicate(true)
	if not resolver_context.has("destination_backend_preference"):
		resolver_context["destination_backend_preference"] = "auto"
	var frame_confirmed: bool = bool(context.get("coordinate_frame_confirmed", context.get("server_coordinate_frame_confirmed", false)))
	var rows: Array = []
	var server_destination_count: int = 0
	var validation_required_count: int = 0
	var apply_ready_count: int = 0
	for zone_value in zone_ids:
		var zone_id: int = int(zone_value)
		var resolution: Dictionary = resolver.call("resolve_destination_for_zone", zone_id, resolver_context) as Dictionary
		var available: bool = bool(resolution.get("ok", false))
		var requires_validation: bool = available and not frame_confirmed
		var apply_ready: bool = available and frame_confirmed
		if available:
			server_destination_count += 1
		if requires_validation:
			validation_required_count += 1
		if apply_ready:
			apply_ready_count += 1
		rows.append({
			"zone_id": zone_id,
			"server_destination_available": available,
			"coordinate_frame_confirmed": frame_confirmed,
			"requires_human_validation": requires_validation,
			"can_apply_runtime_spawn": apply_ready,
			"backend": str(resolution.get("backend", "none")),
			"source": str(resolution.get("source", "none")),
			"authenticity": str(resolution.get("authenticity", "fallback")),
			"error": str(resolution.get("error", "")),
			"destination_resolution": resolution.duplicate(true),
		})
	var missing_count: int = maxi(0, zone_ids.size() - server_destination_count)
	return {
		"ok": true,
		"scope": SCOPE,
		"checkpoint": CHECKPOINT,
		"zone_count": zone_ids.size(),
		"server_destination_count": server_destination_count,
		"missing_count": missing_count,
		"validation_required_count": validation_required_count,
		"apply_ready_count": apply_ready_count,
		"coordinate_frame_confirmed": frame_confirmed,
		"rows": rows,
	}
