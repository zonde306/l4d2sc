#pragma semicolon 1

#define DEBUG_CHARGER_TARGET 0

// custom convar
new Handle:hCvarChargeProximity;
new Handle:hCvarAimOffsetSensitivityCharger;
new Handle:hCvarHealthThresholdCharger;
new bShouldCharge[MAXPLAYERS]; // manual tracking of charge cooldown

public Charger_OnModuleStart() {
	// Charge proximity
	hCvarChargeProximity = CreateConVar("ai_charge_proximity", "300", "Charger 需要多近才能开始冲锋");	
	// Aim offset sensitivity
	hCvarAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger",
									"20",
									"Charger 冲锋瞄准的目标范围，超出范围则换一个目标",
									FCVAR_NONE,
									true, 0.0, true, 179.0);
	// Health threshold
	hCvarHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "300", "Charger 血量小于这个范围则强制冲锋");	
}

public Charger_OnModuleEnd() {
}

/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/

// Initialise spawned chargers
public Action:Charger_OnSpawn(botCharger) {
	bShouldCharge[botCharger] = false;
	return Plugin_Handled;
}

public Action:Charger_OnPlayerRunCmd(charger, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	// prevent charge until survivors are within the defined proximity
	new Float:chargerPos[3];
	GetClientAbsOrigin(charger, chargerPos);
	new target = GetClientAimTarget(charger);	
	new iSurvivorProximity = GetSurvivorProximity(chargerPos, target); // invalid(=-1) target will cause GetSurvivorProximity() to return distance to closest survivor
	new chargerHealth = GetEntProp(charger, Prop_Send, "m_iHealth");
	if( chargerHealth > GetConVarInt(hCvarHealthThresholdCharger) && iSurvivorProximity > GetConVarInt(hCvarChargeProximity) ) {	
		if( !bShouldCharge[charger] ) { 				
			BlockCharge(charger);
			return Plugin_Changed;
		} 			
	} else {
		bShouldCharge[charger] = true;
	}
	return Plugin_Continue;	
}

BlockCharge(charger) {
	new chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (chargeEntity > 0) {  // charger entity persists for a short while after death; check ability entity is valid
		SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1); // keep extending end of cooldown period
	} 			
}

Charger_OnCharge(charger) {
	// Assign charger a new survivor target if they are not specifically targetting anybody with their charge or their target is watching
	new aimTarget = GetClientAimTarget(charger);
	if( !IsSurvivor(aimTarget) || IsTargetWatchingAttacker(charger, GetConVarInt(hCvarAimOffsetSensitivityCharger)) ) {	
		new Float:chargerPos[3];
		GetClientAbsOrigin(charger, chargerPos);
		new newTarget = GetClosestSurvivor(chargerPos, aimTarget);	// try and find another closeby survivor
		if( newTarget != -1 && GetSurvivorProximity(chargerPos, newTarget) <= GetConVarInt(hCvarChargeProximity) ) {
			aimTarget = newTarget; // might be the same survivor if there were no other survivors within configured charge proximity
			
			#if DEBUG_CHARGER_TARGET	
				new String:targetName[32];
				GetClientName(newTarget, targetName, sizeof(targetName));
				PrintToChatAll("Charger forced to charge survivor %s", targetName);
			#endif
		
		}
		
		ChargePrediction(charger, aimTarget);
	}
}

ChargePrediction(charger, survivor) {
	if( !IsBotCharger(charger) || !IsSurvivor(survivor) ) {
		return;
	}
	new Float:survivorPos[3];
	new Float:chargerPos[3];
	new Float:attackDirection[3];
	new Float:attackAngle[3];
	// Add some fancy schmancy trignometric prediction here; as a placeholder charger will face survivor directly
	GetClientAbsOrigin(charger, chargerPos);
	GetClientAbsOrigin(survivor, survivorPos);
	MakeVectorFromPoints( chargerPos, survivorPos, attackDirection );
	GetVectorAngles(attackDirection, attackAngle);	
	TeleportEntity(charger, NULL_VECTOR, attackAngle, NULL_VECTOR); 
}