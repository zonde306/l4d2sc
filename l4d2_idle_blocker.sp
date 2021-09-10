#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "防止故意闲置",
	author = "zonde306",
	description = "防止生还者故意闲置",
	version = "0.1",
	url = ""
};

ConVar g_ConVar_BlockSpecialIdle;
ConVar g_ConVar_BlockVomitIdle;
ConVar g_ConVar_BlockGrenadeIdle;
ConVar g_ConVar_VomitDuration;
ConVar g_ConVar_GrenadeDuration;
ConVar g_ConVar_DefibDuration;
ConVar g_ConVar_BlockReleaseIdle;
ConVar g_ConVar_BlockReleaseDuration;
ConVar g_ConVar_BlockGasCanIdle;
ConVar g_ConVar_BlockGasCanDuration;
ConVar g_ConVar_BlockDefibIdle;
ConVar g_ConVar_BlockAirIdle;

float g_fVomitFadeTimer[MAXPLAYERS+1];
float g_fReleasedTimer[MAXPLAYERS+1];
float g_fDefibrillatorTimer[MAXPLAYERS+1];
float g_fGrenadeExplodeTimer[MAXPLAYERS+1];
float g_fGasCanTimer[MAXPLAYERS+1];

ArrayList gascanArray = null;
ArrayList hitterArray = null;
bool isLate = false, mapStarted = false, isModifying = false;

public void OnPluginStart()
{
	g_ConVar_BlockSpecialIdle = CreateConVar("l4d2_idle_block_grabbed_idle", "1", "是否开启被控禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockVomitIdle = CreateConVar("l4d2_idle_block_vomit_idle", "1", "是否开启沾到胆汁禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockGrenadeIdle = CreateConVar("l4d2_idle_block_grenade_idle", "1", "是否开启丢雷禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockDefibIdle = CreateConVar("l4d2_idle_block_defib_idle", "1", "是否开启禁止电击复活闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockReleaseIdle = CreateConVar("l4d2_idle_block_release_idle", "1", "是否开启禁止解除控制闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockReleaseDuration = CreateConVar("l4d2_idle_block_release_duration", "5.0", "禁止解除控制闲置持续时间", FCVAR_NONE, true, 0.1);
	g_ConVar_BlockGasCanIdle  = CreateConVar("l4d2_idle_block_gascan_idle", "1", "是否开启禁止点油闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockAirIdle  = CreateConVar("l4d2_idle_block_air_idle", "1", "是否开启禁止空中闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockGasCanDuration = CreateConVar("l4d2_idle_block_gascan_duration", "9.0", "禁止点油闲置持续时间", FCVAR_NONE, true, 0.1);
	
	AutoExecConfig(true, "l4d2_idle_blocker");
	
	g_ConVar_VomitDuration = FindConVar("survivor_it_duration");
	g_ConVar_GrenadeDuration = FindConVar("pipe_bomb_timer_duration");
	g_ConVar_DefibDuration = FindConVar("defibrillator_return_to_life_time");
	
	AddCommandListener(Command_Away, "go_away_from_keyboard");
	AddCommandListener(Command_Away, "jointeam");
	
	gascanArray = CreateArray();
	hitterArray = CreateArray();
	
	HookEvent("player_now_it", Event_PlayerHitByVomit);
	HookEvent("jockey_ride_end", Event_PlayerReleased);
	HookEvent("charger_pummel_end", Event_PlayerReleased);
	HookEvent("tongue_release", Event_PlayerReleased);
	HookEvent("pounce_stopped", Event_PlayerReleased);
	HookEvent("charger_carry_end", Event_PlayerReleased);
	HookEvent("defibrillator_used", Event_PlayerDefibrillator);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	RefreshThem();
	ModifyThem();
	
	if (isLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	isLate = late;
	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnGasCanEquip);
}

public Action OnGasCanEquip(int client, int weapon)
{
	if(gascanArray == null)
		return;
	
	if (IsValidEnt(weapon))
	{
		static char weaponClassname[32];
		GetEdictClassname(weapon, weaponClassname, sizeof(weaponClassname));
		if (!StrEqual(weaponClassname, "weapon_gascan"))
		{
			return;
		}
		
		int weaponIndex = FindValueInArray(gascanArray, weapon);
		if (weaponIndex > -1)
		{
			SetArrayCell(hitterArray, weaponIndex, -1);
		}
	}
}

public Action OnGasCansDamaged(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidClient(attacker) || !IsValidEnt(victim))
	{
		return Plugin_Continue;
	}
	
	char victimClass[32];
	GetEdictClassname(victim, victimClass, sizeof(victimClass));
	if (!StrEqual(victimClass, "weapon_gascan"))
	{
		return Plugin_Continue;
	}
	
	int victimIndex = FindValueInArray(gascanArray, victim);
	if (victimIndex != -1)
	{
		if (GetArrayCell(hitterArray, victimIndex) != -1)
		{
			SetArrayCell(hitterArray, victimIndex, -1);
		}
		SetArrayCell(hitterArray, victimIndex, attacker);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	mapStarted = true;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (mapStarted)
	{
		RefreshThem();
		ModifyThem();
	}
}

public void OnEntityDestroyed(int entity)
{
	if (gascanArray == null || !IsValidEnt(entity))
		return;
	
	char entClass[32];
	GetEdictClassname(entity, entClass, sizeof(entClass));
	if (!StrEqual(entClass, "weapon_gascan", false))
		return;
	
	int gascanIndex = FindValueInArray(gascanArray, entity);
	if (gascanIndex != -1)
	{
		int gascanHitter = GetArrayCell(hitterArray, gascanIndex);
		if (IsValidClient(gascanHitter))
		{
			Event event = CreateEvent("scavenge_gas_can_destroyed", true);
			event.SetInt("userid", GetClientUserId(gascanHitter));
			event.Fire(false);
			
			g_fGasCanTimer[gascanHitter] = GetEngineTime() + g_ConVar_BlockGasCanDuration.FloatValue;
		}
		SDKUnhook(entity, SDKHook_OnTakeDamage, OnGasCansDamaged);
		SetArrayCell(gascanArray, gascanIndex, -1);
	}
}

public void OnMapEnd()
{
	mapStarted = false;
	
	CloseHandle(gascanArray);
	gascanArray = null;
	
	CloseHandle(hitterArray);
	hitterArray = null;
}

void RefreshThem()
{
	if (isModifying)
		return;
	
	GasCansHook(false);
	
	if(gascanArray)
		ClearArray(gascanArray);
	
	if(hitterArray)
		ClearArray(hitterArray);
	
	GasCansHook(true);
}

void GasCansHook(bool apply)
{
	if(gascanArray == null)
		return;
	
	if (apply)
	{
		for (int i = 0; i <= GetMaxEntities(); i++)
		{
			if (IsValidEntity(i) && IsValidEdict(i))
			{
				static char gcClassname[32];
				GetEdictClassname(i, gcClassname, sizeof(gcClassname));
				if (!StrEqual(gcClassname, "weapon_gascan", false))
					continue;
				
				SDKHook(i, SDKHook_OnTakeDamage, OnGasCansDamaged);
				
				PushArrayCell(gascanArray, i);
				PushArrayCell(hitterArray, -1);
			}
		}
	}
	else
	{
		for (int i = 0; i < GetArraySize(gascanArray); i++)
		{
			int entity = GetArrayCell(gascanArray, i);
			if (entity != -1)
				SDKUnhook(entity, SDKHook_OnTakeDamage, OnGasCansDamaged);
		}
	}
}

void ModifyThem()
{
	isModifying = true;
	
	for (int i = 0; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			static char gcModel[128], iClassname[32];
			
			gcModel[0] = '\0';
			
			GetEdictClassname(i, iClassname, sizeof(iClassname));
			if (StrEqual(iClassname, "prop_physics", false))
			{
				GetEntPropString(i, Prop_Data, "m_ModelName", gcModel, sizeof(gcModel));
				if (StrEqual(gcModel, "models/props_junk/gascan001a.mdl"))
				{
					int replacedGC = CreateEntityByName("weapon_gascan");
					SetEntityModel(replacedGC, gcModel);
					
					float vPos[3], vAng[3];
					
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vPos);
					GetEntPropVector(i, Prop_Send, "m_angRotation", vAng);
					
					DispatchKeyValueVector(replacedGC, "origin", vPos);
					DispatchKeyValueVector(replacedGC, "angles", vAng);
					DispatchSpawn(replacedGC);
					
					AcceptEntityInput(i, "Kill");
				}
			}
		}
	}
	
	isModifying = false;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) > 1);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

public void Event_PlayerHitByVomit(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fVomitFadeTimer[client] = GetEngineTime() + g_ConVar_VomitDuration.FloatValue;
}

public void Event_PlayerReleased(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fReleasedTimer[client] = GetEngineTime() + g_ConVar_BlockReleaseDuration.FloatValue;
}

public void Event_PlayerDefibrillator(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fDefibrillatorTimer[client] = GetEngineTime() + g_ConVar_DefibDuration.FloatValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity <= MaxClients || entity > 2048)
		return;

	if(StrEqual("molotov_projectile", classname, false) ||
		StrEqual("pipe_bomb_projectile", classname, false) ||
		StrEqual("vomitjar_projectile", classname, false)
	)
		SDKHook(entity, SDKHook_SpawnPost, EntityHook_OnGrenadeThrown);
	
	if (StrEqual(classname, "weapon_gascan", false))
		RefreshThem();
}

public void EntityHook_OnGrenadeThrown(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, EntityHook_OnGrenadeThrown);

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	char classname[64];
	GetEntityClassname(entity, classname, 64);
	if(StrEqual("molotov_projectile", classname, false) ||
		StrEqual("pipe_bomb_projectile", classname, false) ||
		StrEqual("vomitjar_projectile", classname, false)
	)
		g_fGrenadeExplodeTimer[client] = GetEngineTime() + g_ConVar_GrenadeDuration.FloatValue;
}

public Action Command_Away(int client, const char[] command, int argc)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) ||
		!IsPlayerAlive(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;

	float time = GetEngineTime();
	if(g_ConVar_BlockSpecialIdle.BoolValue)
	{
		if(
			// GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||
			// GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
			// GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
		)
		{
			PrintToChat(client, "被控禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockReleaseIdle.BoolValue)
	{
		if(g_fReleasedTimer[client] > time || IsGettingUp(client) || IsStaggering(client))
		{
			PrintToChat(client, "起身禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockVomitIdle.BoolValue)
	{
		if(g_fVomitFadeTimer[client] > time || IsInBile(client))
		{
			PrintToChat(client, "沾上胆汁禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}

	if(g_ConVar_BlockGrenadeIdle.BoolValue)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weapon > MaxClients && IsValidEntity(weapon) &&
			GetEntProp(weapon, Prop_Send, "m_iClip1") == 0
		)
		{
			char classname[64];
			GetEntityClassname(weapon, classname, 64);
			if(StrEqual("weapon_molotov", classname, false) ||
				StrEqual("weapon_pipe_bomb", classname, false) ||
				StrEqual("weapon_vomitjar", classname, false))
			{
				PrintToChat(client, "丢雷禁止 闲置/切换队伍。");
				return Plugin_Handled;
			}
		}

		if(g_fGrenadeExplodeTimer[client] > time)
		{
			PrintToChat(client, "扔雷禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockDefibIdle.BoolValue)
	{
		if(g_fDefibrillatorTimer[client] > time)
		{
			PrintToChat(client, "电击复活禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockGasCanIdle.BoolValue)
	{
		if(g_fGasCanTimer[client] > time)
		{
			PrintToChat(client, "禁止点燃油桶闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockAirIdle.BoolValue)
	{
		if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
		{
			PrintToChat(client, "禁止空中闲置/切换队伍。");
			return Plugin_Handled;
		}
	}

	// ClientCommand(client, "cl_consistencycheck");
	return Plugin_Continue;
}

stock bool IsInBile(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsIT()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

stock bool IsTrapped(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsDominatedBySpecialInfected()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

stock bool IsGettingUp(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsGettingUp()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

stock bool IsStaggering(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsStaggering()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

char tr(const char[] text, any ...)
{
	char line[1024];
	VFormat(line, 1024, text, 2);
	return line;
}
