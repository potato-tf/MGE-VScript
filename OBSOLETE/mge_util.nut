::CONST <- getconsttable()
::ROOT <- getroottable()

::class_string_names <- [ "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer" ]

if (!("ConstantNamingConvention" in ROOT)) {

	foreach(a, b in Constants)
		foreach(k, v in b)
		{
			CONST[k] <- v != null ? v : 0
			ROOT[k] <- v != null ? v : 0
		}
}

foreach(k, v in ::NetProps.getclass())
	if (k != "IsValid" && !(k in ROOT))
		ROOT[k] <- ::NetProps[k].bindenv(::NetProps)

foreach(k, v in ::Entities.getclass())
	if (k != "IsValid" && !(k in ROOT))
		ROOT[k] <- ::Entities[k].bindenv(::Entities)

foreach(k, v in ::EntityOutputs.getclass())
	if (k != "IsValid" && !(k in ROOT))
		ROOT[k] <- ::EntityOutputs[k].bindenv(::EntityOutputs)

foreach(k, v in ::NavMesh.getclass())
	if (k != "IsValid" && !(k in ROOT))
		ROOT[k] <- ::NavMesh[k].bindenv(::NavMesh)

::GetPlayerUserID <- function(player)
{
    return NetProps.GetPropIntArray(Entities.FindByClassname(null, "tf_player_manager"), "m_iUserID", player.entindex())
}

class MGE_Util {
	function GetEntityIndexInSlot(player, slot) {
		local item

		//first check, children
		for (local child = player.FirstMoveChild(); child != null; child = child.NextMovePeer()) 
			if (child instanceof CBaseCombatWeapon && child.GetSlot() == slot)
			{
				item = child	
				break
			}

		if (item) return item.entindex()

		//second check, m_hMyWeapons
		for (local i = 0; i < SLOT_COUNT; i++) {
			local wep = GetPropEntityArray(player, "m_hMyWeapons", i)
			if ( wep == null || wep.GetSlot() != slot) continue

			item = wep
			break
		}

		return item ? item.entindex() : 0
	}
}
