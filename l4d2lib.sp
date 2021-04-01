#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util_stocks>

#include "rounds.inc"
#include "mapinfo.inc"
#include "survivorindex.inc"
#include "tanks.inc"

bool IsMapInStart;

public Plugin myinfo = 
{
	name = "L4D2Lib",
	author = "Confogl Team",
	description = "Useful natives and fowards for L4D2 Plugins",
	version = "1.0",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("L4D2_IsFirstRound", _native_IsFirstRound);
	CreateNative("L4D2_CurrentlyInRound", _native_CurrentlyInRound);
	CreateNative("L4D2_GetSurvivorCount", _native_GetSurvivorCount);
	CreateNative("L4D2_GetSurvivorOfIndex", _native_GetSurvivorOfIndex);
	CreateNative("L4D2_GetMapValueInt", _native_GetMapValueInt);
	CreateNative("L4D2_GetMapValueFloat", _native_GetMapValueFloat);
	CreateNative("L4D2_GetMapValueVector", _native_GetMapValueVector);
	CreateNative("L4D2_GetMapValueString", _native_GetMapValueString);
	CreateNative("L4D2_CopyMapSubsection", _native_CopyMapSubsection);
	CreateNative("L4D2_IsEntityInSaferoom", _native_IsEntityInSaferoom);
	CreateNative("L4D2_IsEntityInStartSaferoom", _native_IsEntityInStartSaferoom);
	CreateNative("L4D2_IsEntityInEndSaferoom", _native_IsEntityInEndSaferoom);
	CreateNative("L4D2_IsPlayerInSaferoom", _native_IsPlayerInSaferoom);
	CreateNative("L4D2_IsPlayerInStartSaferoom", _native_IsPlayerInStartSaferoom);
	CreateNative("L4D2_IsPlayerInEndSaferoom", _native_IsPlayerInEndSaferoom);
	
	hFwdRoundStart = CreateGlobalForward("L4D2_OnRealRoundStart", ET_Ignore);
	hFwdRoundEnd = CreateGlobalForward("L4D2_OnRealRoundEnd", ET_Ignore);
	hFwdFirstTankSpawn = CreateGlobalForward("L4D2_OnTankFirstSpawn", ET_Ignore, Param_Cell);
	hFwdTankPassControl = CreateGlobalForward("L4D2_OnTankPassControl", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	hFwdTankDeath = CreateGlobalForward("L4D2_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell);
	hFwdPlayerHurtPre = CreateGlobalForward("L4D2_OnPlayerHurtPre", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	hFwdPlayerHurtPost = CreateGlobalForward("L4D2_OnPlayerHurtPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	hFwdTeamChanged = CreateGlobalForward("L4D2_OnPlayerTeamChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("l4d2lib");
	return APLRes_Success;
}

public void OnPluginStart()
{
	MapInfo_Init();
	
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
	
	HookEvent("tank_spawn", TankSpawn_Event);
	HookEvent("item_pickup", ItemPickup_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("player_hurt", PlayerHurt_Event_Pre, EventHookMode_Pre);
	HookEvent("player_hurt", PlayerHurt_Event_Post, EventHookMode_Post);
	HookEvent("player_spawn", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("defibrillator_used", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event);
}

public void OnPluginEnd()
{
	MapInfo_OnPluginEnd();
}

public void OnMapStart()
{
	MapInfo_OnMapStart_Update();
	Rounds_OnMapStart_Update();
	Tanks_OnMapStart();
	IsMapInStart = true;
}

public void OnMapEnd()
{
	IsMapInStart = false;
	MapInfo_OnMapEnd_Update();
	Rounds_OnMapEnd_Update();
}


/* Events */
public Action RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	Rounds_OnRoundEnd_Update();
}

public Action RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Delay, _, TIMER_REPEAT);
}

public Action RoundStart_Delay(Handle timer)
{
	if (IsMapInStart)
	{
		Rounds_OnRoundStart_Update();
		Tanks_RoundStart();
		Survivors_RebuildArray();
		PrintToServer("%s", g_sMapname);
		KillTimer(timer);
	}
}

public Action TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	Tanks_TankSpawn(event);
}

public Action ItemPickup_Event(Event event, const char[] name, bool dontBroadcast)
{
	Tanks_ItemPickup(event);
}

public Action PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	Tanks_PlayerDeath(event);
	Survivors_RebuildArray();
}

public Action PlayerHurt_Event_Pre(Event event, const char[] name, bool dontBroadcast)
{
	Players_PlayerHurt_Event_Pre(event);
}

public Action PlayerHurt_Event_Post(Event event, const char[] name, bool dontBroadcast)
{
	Players_PlayerHurt_Event_Post(event);
}

public Action SI_BuildIndex_Event(Event event, const char[] name, bool dontBroadcast)
{
	Survivors_RebuildArray();
}

public Action PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	Survivors_RebuildArray_Delay();
	Players_TeamChange_Event(event);
}

/* Plugin Natives */
public int _native_IsFirstRound(Handle plugin, int numParams)
{
	return IsFirstRound();
}

public int _native_CurrentlyInRound(Handle plugin, int numParams)
{
	return view_as<int>(CurrentlyInRound());
}

public int _native_GetSurvivorCount(Handle plugin, int numParams)
{
	return GetSurvivorCount();
}

public int _native_GetSurvivorOfIndex(Handle plugin, int numParams)
{
    return GetSurvivorOfIndex(GetNativeCell(1));
}

public int _native_GetMapValueInt(Handle plugin, int numParams)
{
	int len, defval;
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	defval = GetNativeCell(2);
	return GetMapValueInt(key, defval);
}

public int _native_GetMapValueFloat(Handle plugin, int numParams)
{
	int len;
	float defval;
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	defval = GetNativeCell(2);
	return view_as<int>(GetMapValueFloat(key, defval));
}

public int _native_GetMapValueVector(Handle plugin, int numParams)
{
	int len;
	float defval[3], value[3];
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	GetNativeArray(3, defval, 3);
	GetMapValueVector(key, value, defval);
	SetNativeArray(2, value, 3);
}

public int _native_GetMapValueString(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	GetNativeStringLength(4, len);
	char[] defval = new char[len+1];
	GetNativeString(4, defval, len+1);
	len = GetNativeCell(3);
	char[] buf = new char[len+1];
	GetMapValueString(key, buf, len, defval);
	SetNativeString(2, buf, len);
}

public int _native_CopyMapSubsection(Handle plugin, int numParams)
{
	int len;
	Handle kv;
	GetNativeStringLength(2, len);
	char[] key = new char[len+1];
	GetNativeString(2, key, len+1);
	kv = GetNativeCell(1);
	CopyMapSubsection(kv, key);
}

public int _native_IsEntityInSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    return view_as<int>(IsEntityInSaferoom(entity));
}
public int _native_IsEntityInStartSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    return view_as<int>(IsEntityInStartSaferoom(entity));
}
public int _native_IsEntityInEndSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    return view_as<int>(IsEntityInEndSaferoom(entity));
}

public int _native_IsPlayerInSaferoom(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return view_as<int>(IsPlayerInSaferoom(client));
}
public int _native_IsPlayerInStartSaferoom(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return view_as<int>(IsPlayerInStartSaferoom(client));
}
public int _native_IsPlayerInEndSaferoom(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return view_as<int>(IsPlayerInEndSaferoom(client));
}
