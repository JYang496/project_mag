class_name RareWeaponVfxSignature
extends RefCounted

enum Style { NONE, FROST, NAPALM, ARC, PRISM }


static func for_weapon(weapon: Node) -> Dictionary:
	if weapon == null:
		return {}
	var runtime: Variant = weapon.get("branch_runtime")
	var ids: Array = runtime.branch_ids if runtime != null else []
	return for_branch_ids(ids)


static func for_branch_ids(branch_ids: Array) -> Dictionary:
	for id_variant in branch_ids:
		var id := str(id_variant).to_lower()
		if "frost" in id or "cryo" in id or "subzero" in id or "glacier" in id:
			return {"signature_style": Style.FROST, "tint": Color(0.46, 0.95, 1.0), "tint_strength": 0.52, "width_scale": 1.18}
		if "napalm" in id or "fire" in id or "thermal" in id:
			return {"signature_style": Style.NAPALM, "tint": Color(1.0, 0.30, 0.08), "tint_strength": 0.55, "width_scale": 1.35}
		if "arc" in id or "energy" in id or "overcharge" in id:
			return {"signature_style": Style.ARC, "tint": Color(0.54, 0.72, 1.0), "tint_strength": 0.48, "length_scale": 1.28}
		if "prism" in id:
			return {"signature_style": Style.PRISM, "tint": Color(0.92, 0.48, 1.0), "tint_strength": 0.50, "length_scale": 1.18, "width_scale": 1.20}
	return {}
