#pragma semicolon 1

enum Angle_Vector {
	Pitch = 0,
	Yaw,
	Roll
};

new Handle:hCvarJockeyLeapRange; // vanilla cvar

new Handle:hCvarHopActivationProximity; // custom cvar

// Leaps
new bool:bCanLeap[MAXPLAYERS];
new bool:bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
 // shoved jockeys will stop hopping

new Handle:hCvarJockeyStumbleRadius; // stumble radius of jockey ride

// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public Jockey_OnModuleStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	hCvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	SetConVarInt(hCvarJockeyLeapRange, 1000); 
	
	// proximity when plugin will start forcing jockeys to hop
	hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "距离敌人多近时开始连跳");
	
	// Jockey stumble
	HookEvent("jockey_ride", OnJockeyRide, EventHookMode_Pre); 
	hCvarJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "骑到敌人头上时弹开其他敌人范围");
}

public Jockey_OnModuleEnd() {
	ResetConVar(hCvarJockeyLeapRange);
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action:Jockey_OnPlayerRunCmd(jockey, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, bool:hasBeenShoved) {
	new Float:jockeyPos[3];
	GetClientAbsOrigin(jockey, jockeyPos);
	new iSurvivorsProximity = GetSurvivorProximity(jockeyPos);
	new bool:bHasLOS = bool:GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats"); // line of sight to any survivor
	
	// Start hopping if within range	
	if ( bHasLOS && (iSurvivorsProximity < GetConVarInt(hCvarHopActivationProximity)) ) {
		
		// Force them to hop 
		new flags = GetEntityFlags(jockey);
		
		// Alternate normal jump and pounces if jockey has not been shoved
		if ( (flags & FL_ONGROUND) && !hasBeenShoved ) { // jump/leap off cd when on ground (unless being shoved)
			if (bDoNormalJump[jockey]) {
				buttons |= IN_JUMP; // normal jump
				bDoNormalJump[jockey] = false;
			} else {
				if( bCanLeap[jockey] ) {
					buttons |= IN_ATTACK; // pounce leap
					bCanLeap[jockey] = false; // leap should be on cooldown
					new Float:leapCooldown = float( GetConVarInt(FindConVar("z_jockey_leap_again_timer")) );
					CreateTimer(leapCooldown, Timer_LeapCooldown, any:jockey, TIMER_FLAG_NO_MAPCHANGE);
					bDoNormalJump[jockey] = true;
				} 			
			}
			
		} else { // midair, release buttons
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}		
		return Plugin_Changed;
	} 

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/

// Enable hopping on spawned jockeys
public Action:Jockey_OnSpawn(botJockey) {
	bCanLeap[botJockey] = true;
	return Plugin_Handled;
}

// Disable hopping when shoved
public Jockey_OnShoved(botJockey) {
	bCanLeap[botJockey] = false;
	new leapCooldown = GetConVarInt(FindConVar("z_jockey_leap_again_timer"));
	CreateTimer( float(leapCooldown), Timer_LeapCooldown, any:botJockey, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action:Timer_LeapCooldown(Handle:timer, any:jockey) {
	bCanLeap[jockey] = true;
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public OnJockeyRide(Handle:event, const String:name[], bool:dontBroadcast) {	
	if (IsCoop()) {
		new attacker = GetClientOfUserId(GetEventInt(event, "userid"));  
		new victim = GetClientOfUserId(GetEventInt(event, "victim"));  
		if(attacker > 0 && victim > 0) {
			StumbleBystanders(victim, attacker);
		} 
	}	
}

bool:IsCoop() {
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return (!StrEqual(GameName, "versus", false) && !StrEqual(GameName, "scavenge", false));
}

StumbleBystanders( pinnedSurvivor, pinner ) {
	decl Float:pinnedSurvivorPos[3];
	decl Float:pos[3];
	decl Float:dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	new radius = GetConVarInt(hCvarJockeyStumbleRadius);
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i) ) {
			if( i != pinnedSurvivor && i != pinner && !IsPinned(i) ) {
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if( GetVectorLength(dir) <= float(radius) ) {
					NormalizeVector( dir, dir ); 
					L4D_StaggerPlayer( i, pinnedSurvivor, dir );
				}
			}
		} 
	}
}

stock Float:modulus(Float:a, Float:b) {
	while(a > b)
		a -= b;
	return a;
}