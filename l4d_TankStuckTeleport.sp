#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS		FCVAR_NOTIFY

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "Tank Anti-Stuck",
	author = "Dragokas",
	description = "Teleport tank if he was stuck within collision and can't move",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas"
}

/*
	ChangeLog:
	
	1.2 (05-Mar-2019)
	 - Added all user's ConVars.
	 - Added late loading code.
	 - Included anti-losing tank control ConVar (thanks to cravenge)
	
	1.1 (01-Mar-2019)
	 - Added more reliable logic
	
	1.0 (05-Jan-2019)
	 - Initial release
	 
==========================================================================================

	Credits:
	
*	Peace-Maker - for some examples on TraceHull filter.

*	stinkyfax - for examples of teleport in direction math.

*	cravenge - for some ConVar, possibly, preventing tank from losing control when stuck.

==========================================================================================

	Related topics:
	https://forums.alliedmods.net/showthread.php?t=313696
	https://forums.alliedmods.net/showthread.php?p=2133193
	https://forums.alliedmods.net/showthread.php?t=101998
	
*/

#define DEBUG 0

ConVar 	g_hCvarEnable;
ConVar 	g_hCvarNonAngryTime;
ConVar 	g_hCvarTankDistanceMax;
ConVar 	g_hCvarHeadHeightMax;
ConVar 	g_hCvarHeadHeightMin;
ConVar 	g_hCvarStuckInterval;
ConVar 	g_hCvarNonStuckRadius;
ConVar 	g_hCvarInstTeleDist;
ConVar 	g_hCvarSmoothTeleDist;
ConVar 	g_hCvarSmoothTelePower;
ConVar 	g_hCvarAllIntellect;
ConVar	g_hCvarApplyConVar;
ConVar 	g_hCvarStuckFailsafe;

float 	g_pos[MAXPLAYERS+1][3];
float 	g_fMaxNonAngryDist;
float 	g_fNonAngryTime;

bool 	g_bLeft4Dead2;
bool 	g_bAngry[MAXPLAYERS+1];
bool 	g_bMapStarted = true;
bool 	g_bLateload;

int 	g_bEnabled;
int 	g_iTimes[MAXPLAYERS+1];
int 	g_iStuckTimes[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2) {
		g_bLeft4Dead2 = true;		
	}
	else if (test != Engine_Left4Dead) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar(							"l4d_TankAntiStuck_version",				PLUGIN_VERSION,	"Plugin version", FCVAR_DONTRECORD );
	g_hCvarEnable = CreateConVar(			"l4d_TankAntiStuck_enable",					"1",		"Enable plugin (1 - On / 0 - Off)", CVAR_FLAGS );
	g_hCvarNonAngryTime = CreateConVar(		"l4d_TankAntiStuck_non_angry_time",			"45",		"Automatic tank teleport if he is not angry within specified time (in sec.) after spawn (0 - to disable)", CVAR_FLAGS );
	g_hCvarTankDistanceMax = CreateConVar(	"l4d_TankAntiStuck_tank_distance_max",		"1000",		"Maximum distance allowed between tank and the nearest player (after been angered). Otherwise, it will be teleported (0 - to disable)", CVAR_FLAGS );
	g_hCvarHeadHeightMax = CreateConVar(	"l4d_TankAntiStuck_head_height_max",		"150",		"Distance under the head of player, tank will be instantly teleported to, by default, when tank failed to unstuck wasting all attempts to free using smooth teleport", CVAR_FLAGS );
	g_hCvarHeadHeightMin = CreateConVar(	"l4d_TankAntiStuck_head_height_min",		"80",		"Distance under the head of player, tank will be instantly teleported to, if plugin failed to find more appropriate location", CVAR_FLAGS );
	g_hCvarStuckInterval = CreateConVar(	"l4d_TankAntiStuck_check_interval",			"3",		"Time intervals (in sec.) tank stuck should be checked", CVAR_FLAGS );
	g_hCvarNonStuckRadius = CreateConVar(	"l4d_TankAntiStuck_non_stuck_radius",		"15",		"Maximum radius where tank is cosidered non-stucked when not moved during X sec. (see l4d_TankAntiStuck_check_interval ConVar)", CVAR_FLAGS );
	g_hCvarInstTeleDist = CreateConVar(		"l4d_TankAntiStuck_inst_tele_dist",			"50",		"Distance for instant type of teleport", CVAR_FLAGS );
	g_hCvarSmoothTeleDist = CreateConVar(	"l4d_TankAntiStuck_smooth_tele_dist",		"150",		"Distance for smooth type of teleport", CVAR_FLAGS );
	g_hCvarSmoothTelePower = CreateConVar(	"l4d_TankAntiStuck_smooth_tele_power",		"300",		"Power (velocity) for smooth type of teleport", CVAR_FLAGS, true, 251.0, true, 500.0 );
	g_hCvarAllIntellect = CreateConVar(		"l4d_TankAntiStuck_all_intellect",			"1",		"1 - Apply anti-stuck to both: when bots or real player control tank, 0 - apply to tank bot (fake) only", CVAR_FLAGS );
	g_hCvarApplyConVar = CreateConVar(		"l4d_TankAntiStuck_apply_convar",			"1",		"1 - Apply special ConVar in attempt to fix problem when tank losing its control after stuck (just in case). 0 - do not apply", CVAR_FLAGS );
	
	AutoExecConfig(true,			"l4d_tank_antistuck");
	
	g_hCvarStuckFailsafe = FindConVar("tank_stuck_failsafe");
	
	#if (DEBUG)
		//test staff
		RegAdminCmd	("sm_movetype", 	Cmd_TankShow,			ADMFLAG_ROOT,	"Check some props on aim target");
		RegAdminCmd	("sm_move", 		Cmd_Move,				ADMFLAG_ROOT,	"Teleport aim target a little bit as attempt to manually free it from stuck");
		RegAdminCmd	("sm_findempty", 	Cmd_FindEmpty,			ADMFLAG_ROOT,	"Find empty location next to the player and try teleport player there");
		RegAdminCmd	("sm_reproduce", 	Cmd_ReproduceProp,		ADMFLAG_ROOT,	"Clone properties on aim target based on the properties previously saved by sm_ted_select of tEntDev");
	#endif
	
	HookConVarChange(g_hCvarEnable,			ConVarChanged);
	
	GetCvars();
	
	if (g_bLateload && g_bEnabled) {
		for (int i = 1; i <= MaxClients; i++) {
			if (i != 0 && IsClientInGame(i) && CheckTankIntellect(i)) {
				if (IsTank(i))
					BeginTankTracing(i);
			}
		}
	}
}

bool CheckTankIntellect(int tank)
{
	if (g_hCvarAllIntellect.BoolValue)
		return true;
	else
		if (IsFakeClient(tank)) {
			return true;
		}
	return false;
}

public void OnConfigsExecuted()
{
	if (g_hCvarApplyConVar.BoolValue) {
		if (g_hCvarStuckFailsafe != null)
			g_hCvarStuckFailsafe.SetInt(0);
	}
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;
	g_fMaxNonAngryDist = g_hCvarTankDistanceMax.FloatValue;
	g_fNonAngryTime = g_hCvarNonAngryTime.FloatValue;
	
	InitHook();
}

void InitHook()
{
	static bool bHooked;
	
	if (g_bEnabled) {
		if (!bHooked) {
			HookEvent("player_spawn",			Event_PlayerSpawn);
			HookEvent("round_start", 			Event_RoundStart,	EventHookMode_PostNoCopy);
			HookEvent("round_end", 				Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("finale_win", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("mission_lost", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			bHooked = true;
		}
	} else {
		if (bHooked) {
			UnhookEvent("player_spawn",			Event_PlayerSpawn);
			UnhookEvent("round_start", 			Event_RoundStart,	EventHookMode_PostNoCopy);
			UnhookEvent("round_end", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("finale_win", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("mission_lost", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			bHooked = false;
		}
	}
}

public Action Cmd_FindEmpty(int client, int args)
{
	float vEnd[3], vOrigin[3];
	
	GetClientAbsOrigin(client, vOrigin);
	
	if (FindEmptyPos(client, client, 300.0, vEnd)) {
		PrintToChat(client, "Empty pos is found, distance: %f", GetVectorDistance(vOrigin, vEnd));
		TeleportEntity(client, vEnd, NULL_VECTOR, NULL_VECTOR);
	}
	else {
		PrintToChat(client, "Cannot found empty pos!!!");
		
		float fSetDist = 100.0;
		
		CopyVector(vOrigin, vEnd);
		vEnd[0] -= fSetDist;
		float dist;
		if ((dist = GetDistanceToVec(client, vEnd)) >= fSetDist) {
			PrintToChat(client, "ray infinite. dist = %f", dist);
		}
		else {
			PrintToChat(client, "ray infinite. dist = %f", dist);
		}
		
	}
	return Plugin_Handled;
}

/*
public Action Timer_ChangeAngle(Handle timer)
{
	float vecOrigin[3], vecTarget[3], angle[3];
	
	int iReal;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
			iReal = i;
	
	GetClientAbsOrigin(iReal, vecOrigin);
	GetVectorOrigins(vecOrigin, vecTarget, angle);
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i)) {
			TeleportEntity(i, NULL_VECTOR, angle, NULL_VECTOR);
		}
}
*/

public Action Cmd_Move(int client, int args)
{
	int target = GetClientAimTarget(client, false);
	
	if (target > 0) {
		TeleportPlayerInstantByPreset(target);
	}
	return Plugin_Handled;
}

public Action Cmd_TankShow(int client, int args)
{
	int ent = GetClientAimTarget(client, false);

	if (ent > 0) {
		if (IsTank(ent))
		{
			int state = GetEntProp(ent, Prop_Send, "m_zombieState");
			MoveType movetype = GetEntityMoveType(ent);
			int anim = GetEntProp(ent, Prop_Send, "m_nSequence");
			//int coll = GetEntProp(client, Prop_Send, "m_Collision");
			//int collGrp = GetEntProp(ent, Prop_Send, "m_CollisionGroup");
			//int movecollide = GetEntProp(ent, Prop_Send, "movecollide");
			
			PrintToChat(client, "%N zombie state is: %i, movetype: %i, anim: %i, stuck? %b", ent, state, movetype, anim, IsClientStuck(ent));
		}
	}
	return Plugin_Handled;
}

public Action Cmd_ReproduceProp(int client, int args)
{
	int ent = GetClientAimTarget(client, false);
	
	if (ent < 0 || !IsTank(ent)) {
		PrintToChat(client, "Not aimed or not a tank! Ent = %i", ent);
		return Plugin_Handled;
	}

	PrintToChatAll("Reproducing properties on %N ...", ent);

	/*
	SetEntProp(ent, Prop_Send, "movetype", 11);
	SetEntProp(ent, Prop_Send, "m_bAnimatedEveryTick", 0);
	SetEntProp(ent, Prop_Send, "m_nForceBone", 3);
	SetEntProp(ent, Prop_Send, "m_nSequence", 21);
	SetEntProp(ent, Prop_Send, "m_nNewSequenceParity", 6);
	SetEntProp(ent, Prop_Send, "m_nResetEventsParity", 6);
	SetEntProp(ent, Prop_Send, "m_hGroundEntity", -1);
	SetEntProp(ent, Prop_Send, "m_fFlags", 386);
	SetEntProp(ent, Prop_Send, "m_bDucked", 1);
	SetEntProp(ent, Prop_Send, "m_zombieState", 1);
	SetEntProp(ent, Prop_Send, "m_customAbility", 36708634);
	SetEntProp(ent, Prop_Send, "m_lookatPlayer", 59863049);
	SetEntPropFloat(ent, Prop_Send, "m_flFallVelocity", -72.0);
	SetEntPropFloat(ent, Prop_Send, "m_vecVelocity[0]", -13.1128);
	SetEntPropFloat(ent, Prop_Send, "m_vecVelocity[1]", 10.3466);
	SetEntPropFloat(ent, Prop_Send, "m_vecVelocity[2]", 72.0927);
	SetEntPropFloat(ent, Prop_Send, "m_timestamp", -1.0);
	SetEntPropFloat(ent, Prop_Send, "m_mainSequenceStartTime", 2799.7333);
	SetEntPropFloat(ent, Prop_Send, "m_fireLayerStartTime", 0.0);
	SetEntPropFloat(ent, Prop_Send, "m_noiseLevelTime", 2759.6667);
	SetEntPropFloat(ent, Prop_Send, "m_overriddenRenderYaw", 90.0);
	*/
	
	KeyValues kv;
	char sItem[16], sName[64], sValue[64];
	int iValue;
	float fValue, vValue[3];
	
	kv = CreateKeyValues("tank");
	
	if (FileToKeyValues(kv, "kvtest.txt")) { // tEntDev report file (root of game folder)
		PrintToChatAll("kvtest.txt is Loaded");
		
		kv.Rewind();
		kv.GotoFirstSubKey();
		
		do
		{
			kv.GetSectionName(sItem, sizeof(sItem)); // compare to full list
			
			kv.GetString("Name", sName, sizeof(sName));
			
			if (HasEntProp(ent, Prop_Send, sName)) {
			
				PrintToChatAll("Name: %s", sName);
				
				switch(kv.GetNum("type")) {
					case 0: { // integer
						iValue = kv.GetNum("value");
						SetEntProp(ent, Prop_Send, sName, iValue);
						PrintToChatAll("%s = %i", sName, iValue);
					}
					case 1: { // float
						fValue = kv.GetFloat("value");
						SetEntPropFloat(ent, Prop_Send, sName, fValue);
						PrintToChatAll("%s = %f", sName, fValue);
					}
					case 2: { // vector
						kv.GetVector("value", vValue);
						SetEntPropVector(ent, Prop_Send, sName, vValue);
						PrintToChatAll("%s = %f %f %f", sName, vValue[0], vValue[1], vValue[2]);
					}
					case 3: { // ??
					}
					case 4: { // string
						kv.GetString("value", sValue, sizeof(sValue), "error");
						if (!StrEqual(sValue, "error")) {
							SetEntPropString(ent, Prop_Send, sName, sValue);
							PrintToChatAll("%s = %s", sName, sValue);
						}
					}
				}
			}
		} while (kv.GotoNextKey());
		
		ChangeEdictState(ent, 0);
	}
	else {
		PrintToChatAll("kvtest.txt file is not found!");
	}
	return Plugin_Handled;
}

bool TeleportPlayerSmoothByPreset(int client)
{
	return TeleportPlayerSmooth(client, g_hCvarSmoothTeleDist.FloatValue, g_hCvarSmoothTelePower.FloatValue);
}

// smooth teleport in eye view direction (with collision)
//
stock bool TeleportPlayerSmooth(int client, float distance, float jump_power = 251.0)
{
	float angle[3], dir[3], current[3], resulting[3], vecOrigin[3], vecTarget[3];
	
	static int iVelocity = 0;
	if (iVelocity == 0)
		iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
		//GetEntPropVector(client, Prop_Send, "m_vecVelocity", current);
	
	int iNear = GetNearestClient(client);
	if (iNear != 0) {
		GetClientAbsOrigin(client, vecOrigin);
		GetClientAbsOrigin(iNear, vecTarget);
		GetVectorOrigins(vecOrigin, vecTarget, angle);
		TeleportEntity(client, NULL_VECTOR, angle, NULL_VECTOR);
	}
	
	GetClientEyeAngles(client, angle);
	
	/*
	int iNear = GetNearestClient(client);
	if (iNear == 0) {
		GetClientEyeAngles(client, angle);
	}
	else {
		GetClientAbsOrigin(client, vecOrigin);
		GetClientAbsOrigin(iNear, vecTarget);
		GetVectorOrigins(vecOrigin, vecTarget, angle);
	}
	*/
	
	//dir[0] = Cosine(DegToRad(angle[1])) * distance;
	//dir[1] = Sine(DegToRad(angle[1])) * distance;
	GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, distance);
	
	GetEntDataVector(client, iVelocity, current);
	resulting[0] = current[0] + dir[0];
	resulting[1] = current[1] + dir[1];
	resulting[2] = jump_power; // min. 251
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, resulting);
	return true;
}

bool TeleportPlayerInstantByPreset(int client)
{
	return TeleportPlayerInstant(client, g_hCvarInstTeleDist.FloatValue);
}

// instant teleport in eye view direction (no collisions)
//
stock bool TeleportPlayerInstant(int client, float distance) // Credits: stinkyfax
{
	if (client != 0)
	{
		if (IsPlayerAlive(client))
		{
			float angle[3], endpos[3], startpos[3], dir[3];
			
			GetClientEyeAngles(client, angle);
			GetClientEyePosition(client, startpos);
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(dir, distance);
			AddVectors(startpos, dir, endpos);
			
			TR_TraceRayFilter(startpos, endpos, MASK_ALL, RayType_EndPoint, AimTargetFilter);
			TR_GetEndPosition(endpos);
			distance = GetVectorDistance(startpos, endpos);
			
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(dir, distance - 33.0);
			AddVectors(startpos, dir, endpos);
			endpos[2] -= 30.0;
			
			TeleportEntity(client, endpos, NULL_VECTOR, NULL_VECTOR);
			return true;
		}
	}
	return false;
}

public bool AimTargetFilter(int entity, int mask)
{
	return (entity > MaxClients || !entity);
}

public Action Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast) 
{
	OnMapStart();
}
public Action Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast) 
{
	OnMapEnd();
}

public void OnMapStart() {
	g_bMapStarted = true;
	for (int i = 1; i < MaxClients; i++)
		g_iTimes[i] = 0;
}
public void OnMapEnd() {
	g_bMapStarted = false;
}

public Action Event_PlayerSpawn(Event hEvent, const char[] name, bool dontBroadcast) 
{
	if (!g_bEnabled || !g_bMapStarted) return Plugin_Continue;
	
	int UserId = hEvent.GetInt("userid");
	int client = GetClientOfUserId(UserId);
	
	if (client != 0 && IsClientInGame(client) && CheckTankIntellect(client)) {
		if (IsTank(client)) {
			#if (DEBUG)
				//EmulateStuck(client);
			#endif
			
			BeginTankTracing(client);
		}
	}
	return Plugin_Continue;
}

void BeginTankTracing(int client)
{
	g_iStuckTimes[client] = 0;
	g_bAngry[client] = false;
	GetClientAbsOrigin(client, g_pos[client]);

	// wait until somebody make tank angry to begin check for stuck
	CreateTimer(2.0, Timer_CheckAngry, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	if (g_fNonAngryTime != 0) {
		// check if tank didnt't become angry within 45 sec
		CreateTimer(g_fNonAngryTime, Timer_CheckAngryTimeout, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

// Stuck emulation on the map "l4d_airport04_terminal"
//
stock void EmulateStuck(int client) {
	char sMap[100];
	GetCurrentMap(sMap, sizeof(sMap));
	if (StrEqual(sMap, "l4d_airport04_terminal", false)) { // L4D1
		float pos[3] = {419.714569, 4453.435546, 296.932739};
		TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
	}
}

public Action Timer_CheckAngry(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && g_bMapStarted) {
		// became angry?
		if (GetEntProp(client, Prop_Send, "m_zombieState") != 0 || g_bAngry[client]) {
		
			// check if he is not moving within X sec.
			CreateTimer(g_hCvarStuckInterval.FloatValue, Timer_CheckPos, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Timer_CheckPos(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && g_bMapStarted) {
		
		float pos[3];
		GetClientAbsOrigin(client, pos);
	
		// Checking the tank is not idle
		//if (GetEntProp(client, Prop_Send, "m_zombieState") != 0)
		{
			float distance = GetVectorDistance(pos, g_pos[client], false);
			
			#if (DEBUG)
				PrintToChatAll("dist = %f", distance);
			#endif
			
			//int anim = GetEntProp(client, Prop_Send, "m_nSequence");
			
			if (distance < g_hCvarNonStuckRadius.FloatValue) {
				if (g_fMaxNonAngryDist != 0.0 && (GetDistanceToNearestClient(client) > g_fMaxNonAngryDist || g_iStuckTimes[client] >= 2)) {
					TeleportToSurvivor(client);
					TeleportPlayerSmoothByPreset(client);
				}
				else {
					/*
					SetEntityMoveType (client, MOVETYPE_NOCLIP);
					#if (DEBUG)
						PrintToChatAll("%N movetype: noclip", client);
					#endif
					*/
					//CreateTimer(0.1, Timer_Teleport, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					MakeTeleport(client);
					
					/*
					SetEntProp(client, Prop_Send, "m_nSequence", 12);
					CreateTimer(0.5, Timer_SetWalk, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					*/
				}
				g_iStuckTimes[client]++;
				
				CreateTimer(0.5, Timer_Unstuck, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else {
				g_iStuckTimes[client] = 0;
			}
		}
		g_pos[client] = pos;
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Timer_Unstuck(Handle timer, int UserId)
{
	const int MAX_TRY = 10;
	
	int client = GetClientOfUserId(UserId);
	
	if (client != 0 && IsClientInGame(client) && IsClientStuck(client)) {
		if (g_iTimes[client] < MAX_TRY) {
			TeleportPlayerSmoothByPreset(client);
			g_iTimes[client]++;
		}
		else {
			TeleportToSurvivor(client);
			TeleportPlayerSmoothByPreset(client);
			g_iTimes[client] = 0;
			return Plugin_Stop;
		}
	}
	else {
		g_iTimes[client] = 0;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void MakeTeleport(int client)
{
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
		//SetEntityMoveType (client, MOVETYPE_NOCLIP);
		TeleportPlayerInstantByPreset(client);
		TeleportPlayerSmoothByPreset(client);
		//SetEntityMoveType (client, MOVETYPE_WALK);
		#if (DEBUG)
			PrintToChatAll("%N stucked => micro-teleport", client);
		#endif
	}
}

public Action Timer_SetWalk(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
		#if (DEBUG)
			PrintToChatAll("%N movetype: walk", client);
		#endif
		SetEntityMoveType (client, MOVETYPE_WALK);
	}
}

public Action Timer_CheckAngryTimeout(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
		if (GetEntProp(client, Prop_Send, "m_zombieState") == 0) {
			TeleportToSurvivor(client);
			TeleportPlayerSmoothByPreset(client);
		}
		// force angry flag to allow timer to begin check for position even if tank became angry but still not moving
		SetEntProp(client, Prop_Send, "m_zombieState", 1);
		g_bAngry[client] = true; // just in case
	}
}

void TeleportToSurvivor(int target) {
	int survivor = GetAnyClient();
	if (survivor != 0) {
		float pos[3];
		
		if (!FindEmptyPos(survivor, target, g_hCvarHeadHeightMax.FloatValue, pos)) {
			GetClientAbsOrigin(survivor, pos);
			pos[2] += g_hCvarHeadHeightMin.FloatValue;
		}
		
		TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
		#if (DEBUG)
			PrintToChatAll("%N is not angry. Teleported to %N", target, survivor);
		#endif
	}
}

float GetDistanceToNearestClient(int client) {
	float tpos[3], spos[3], dist, mindist;
	GetClientAbsOrigin(client, tpos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, spos);
			dist = GetVectorDistance(tpos, spos, false);
			if (dist < mindist || mindist < 0.1)
				mindist = dist;
		}
	}
	return mindist;
}

int GetNearestClient(int client) {
	float tpos[3], spos[3], dist, mindist;
	int iNearClient = 0;
	GetClientAbsOrigin(client, tpos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, spos);
			dist = GetVectorDistance(tpos, spos, false);
			if (dist < mindist || mindist < 0.1) {
				mindist = dist;
				iNearClient = i;
			}
		}
	}
	return iNearClient;
}

stock bool IsTank(int client)
{
	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( class == (g_bLeft4Dead2 ? 8 : 5 ))
			return true;
	}
	return false;
}

int GetAnyClient() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return i;
	}
	return 0;
}

void GetVectorOrigins(float vecClientPos[3], float vecTargetPos[3], float ang[3])
{
	float v[3];
	SubtractVectors(vecTargetPos, vecClientPos, v);
	NormalizeVector(v, v);
	GetVectorAngles(v, ang);
}

bool IsClientStuck(int iClient)
{
	float vMin[3], vMax[3], vOrigin[3];
	GetClientMins(iClient, vMin);
	GetClientMaxs(iClient, vMax);
	GetClientAbsOrigin(iClient, vOrigin);
	TR_TraceHullFilter(vOrigin, vOrigin, vMin, vMax, MASK_PLAYERSOLID, TraceRay_DontHitSelf, iClient);
	return TR_DidHit();
}

public bool TraceRay_DontHitSelf(int iEntity, int iMask, any data)
{
	return (iEntity != data);
}

/*
stock float GetDistanceToFloor(int client)
{ 
	float fStart[3], fDistance = 0.0;
	
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == 0)
		return 0.0;
	
	GetClientAbsOrigin(client, fStart);
	
	fStart[2] += 10.0;
	
	Handle hTrace = TR_TraceRayFilterEx(fStart, view_as<float>({90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client); 
	if(TR_DidHit())
	{
		float fEndPos[3];
		TR_GetEndPosition(fEndPos, hTrace);
		fStart[2] -= 10.0;
		fDistance = GetVectorDistance(fStart, fEndPos);
	}
	CloseHandle(hTrace);
	return fDistance; 
}
*/

public bool TraceRayNoPlayers(int entity, int mask, any data)
{
    if(entity == data || (entity >= 1 && entity <= MaxClients))
    {
        return false;
    }
    return true;
}

stock float GetDistanceToVec(int client, float vEnd[3]) // credits: Peace-Maker
{ 
	float vMin[3], vMax[3], vOrigin[3], vStart[3], fDistance = 0.0;
	GetClientAbsOrigin(client, vStart);
	vStart[2] += 10.0;
	GetClientMins(client, vMin);
	GetClientMaxs(client, vMax);
	GetClientAbsOrigin(client, vOrigin);
	Handle hTrace = TR_TraceHullFilterEx(vOrigin, vEnd, vMin, vMax, MASK_PLAYERSOLID, TraceRayNoPlayers, client);
	
	if(TR_DidHit())
	{
		float fEndPos[3];
		TR_GetEndPosition(fEndPos, hTrace);
		vStart[2] -= 10.0;
		fDistance = GetVectorDistance(vStart, fEndPos);
	}
	else {
		vStart[2] -= 10.0;
		fDistance = GetVectorDistance(vStart, vEnd);
	}
	CloseHandle(hTrace);
	return fDistance; 
}

bool FindEmptyPos(int client, int target, float fSetDist, float vEnd[3])
{
	const float fClientHeight = 71.0;
	
	float vMin[3], vMax[3], vStart[3];
	
	GetClientMins(target, vMin);
	GetClientMaxs(target, vMax);
	float fTargetHeigth = vMax[2] - vMin[2];
	
	GetClientAbsOrigin(client, vStart);
	
	//to the roof;
	CopyVector(vStart, vEnd);
	vEnd[2] += (fClientHeight + fSetDist);
	
	if (GetDistanceToVec(client, vEnd) >= (fClientHeight + fSetDist)) {
		vEnd[2] -= fTargetHeigth;
		return true;
	}

	//to the right
	CopyVector(vStart, vEnd);
	vEnd[0] += fSetDist;
	if (GetDistanceToVec(client, vEnd) >= fSetDist)
		return true;
	
	//to the left
	CopyVector(vStart, vEnd);
	vEnd[0] -= fSetDist;
	if (GetDistanceToVec(client, vEnd) >= fSetDist)
		return true;

	//to the forward
	CopyVector(vStart, vEnd);
	vEnd[1] += fSetDist;
	if (GetDistanceToVec(client, vEnd) >= fSetDist)
		return true;
		
	//to the backward
	CopyVector(vStart, vEnd);
	vEnd[1] -= fSetDist;
	if (GetDistanceToVec(client, vEnd) >= fSetDist)
		return true;
		
	//to the right + up
	CopyVector(vStart, vEnd);
	vEnd[0] += fSetDist;
	vEnd[2] += (fClientHeight + fSetDist);
	if (GetDistanceToVec(client, vEnd) >= fSetDist) {
		vEnd[2] -= fTargetHeigth;
		return true;
	}
	
	//to the left + up
	CopyVector(vStart, vEnd);
	vEnd[0] -= fSetDist;
	vEnd[2] += (fClientHeight + fSetDist);
	if (GetDistanceToVec(client, vEnd) >= fSetDist) {
		vEnd[2] -= fTargetHeigth;
		return true;
	}
	
	//to the forward + up
	CopyVector(vStart, vEnd);
	vEnd[1] += fSetDist;
	vEnd[2] += (fClientHeight + fSetDist);
	if (GetDistanceToVec(client, vEnd) >= fSetDist) {
		vEnd[2] -= fTargetHeigth;
		return true;
	}
	
	//to the backward + up
	CopyVector(vStart, vEnd);
	vEnd[1] -= fSetDist;
	vEnd[2] += (fClientHeight + fSetDist);
	if (GetDistanceToVec(client, vEnd) >= fSetDist) {
		vEnd[2] -= fTargetHeigth;
		return true;
	}
	
	if (fSetDist >= 100.0) {
		FindEmptyPos(client, target, fSetDist - 50.0, vEnd); // recurse => decrease a distance until found appropriate location
	}
	
	return false;
}

void CopyVector(const float vecSrc[3], float vecDest[3]) {
	vecDest[0] = vecSrc[0];
	vecDest[1] = vecSrc[1];
	vecDest[2] = vecSrc[2];
}