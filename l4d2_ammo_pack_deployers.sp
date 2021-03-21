/*
 *  [L4D2] Ammo Pack Deployers plugin. A SourceMod plugin for Left 4 Dead 2.
 *	===========================================================================
 *	Copyright (C) 2018-2019 John Mark "cravenge" Moreno.  All rights reserved.
 *	Co-coded and published by Kaitlyn "kitty" Sanchez.
 *	===========================================================================
 *	
 *	The source code in this file is originally made by me, courtesy of
 *	DeathChaos25 for the code of manipulating bots into picking and
 *	avoiding specific items in the game.
 *	
 *	I strictly prohibit the unauthorized tweaking/modification, and/or
 *	redistribution of this plugin under the same and/or different names
 *	but there are exceptions.
 *
 *	If you have any suggestions on improving the plugin's functionality,
 *	please do not hesitate to send a private message to my AlliedModders
 *	profile. For feedbacks, you can post them in the thread without any
 *	worries.
 *
 *	------------------------------- Changelog ---------------------------------
 *	Version 1.11 (June 28, 2018)
 *	X (Probably) Final release.
 *	+ Prevented "Invalid Handle 0" error from spamming.
 *	
 *	Version 1.1 (March 2, 2018)
 *	+ Fixed low ammunition check.
 *	+ Added check for bots who are reviving other players.
 *	+ Delayed ammo pack use to prevent bots from not doing anything.
 *	+ Priority of bots picking up ammo packs over medkits and defibs balanced.
 *	
 *	Version 1.0 (February 3, 2018)
 *	X Initial release.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.11"

ConVar apdMinAmmoSMGs, apdMinAmmoT1Shotguns, apdMinAmmoRifles, apdMinAmmoT2Shotguns,
	apdMinAmmoSnipers, apdMinAmmoM60s, apdMinAmmoLaunchers, apdLowAmmo, apdTankSpawns, apdWitchSpawns,
	apdMobSpawns;

int iMinAmmoSMGs, iMinAmmoT1Shotguns, iMinAmmoRifles, iMinAmmoT2Shotguns, iMinAmmoSnipers,
	iMinAmmoM60s, iMinAmmoLaunchers, iDeploy[MAXPLAYERS+1];

bool bIsL4DTFound, bLowAmmo, bTankSpawns, bWitchSpawns, bMobSpawns, bTongued[MAXPLAYERS+1];
ArrayList alAmmoPacks;

public Plugin myinfo =
{
	name = "机器人部署弹药包", 
	author = "cravenge", 
	description = "Manipulates Bots To Grab And Deploy Ammo Packs.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=261566"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if (!StrEqual(sGameName, "left4dead2", false))
	{
		strcopy(error, err_max, "[APD] Plugin Supports L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sExtensionFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sExtensionFile, sizeof(sExtensionFile), "extensions/left4downtown.ext.2.l4d2.dll");
	if (FileExists(sExtensionFile))
	{
		bIsL4DTFound = true;
	}
	else
	{
		bIsL4DTFound = false;
	}
	
	CreateConVar("ammo_pack_deployers-l4d2_version", PLUGIN_VERSION, "插件版本", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	apdLowAmmo = CreateConVar("apd-l4d2_low_ammo", "1", "弹药较低时部署弹药包", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	apdTankSpawns = CreateConVar("apd-l4d2_tank_spawns", "1", "刷克时部署弹药包", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	apdWitchSpawns = CreateConVar("apd-l4d2_witch_spawns", "1", "刷妹时部署弹药包", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	apdMobSpawns = CreateConVar("apd-l4d2_mob_spawns", "1", "刷尸潮时部署弹药包", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	apdMinAmmoSMGs = CreateConVar("apd-l4d2_min_ammo_smgs", "15", "冲锋枪弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoT1Shotguns = CreateConVar("apd-l4d2_min_ammo_t1shotguns", "10", "单喷弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoRifles = CreateConVar("apd-l4d2_min_ammo_rifles", "25", "步枪弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoT2Shotguns = CreateConVar("apd-l4d2_min_ammo_t2shotguns", "10", "连喷弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoSnipers = CreateConVar("apd-l4d2_min_ammo_snipers", "20", "狙击弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoM60s = CreateConVar("apd-l4d2_min_ammo_m60s", "30", "机枪弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	apdMinAmmoLaunchers = CreateConVar("apd-l4d2_min_ammo_launchers", "5", "榴弹弹药少于多少才算较低", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	bLowAmmo = apdLowAmmo.BoolValue;
	bTankSpawns = apdTankSpawns.BoolValue;
	bWitchSpawns = apdWitchSpawns.BoolValue;
	bMobSpawns = apdMobSpawns.BoolValue;
	
	iMinAmmoSMGs = apdMinAmmoSMGs.IntValue;
	iMinAmmoT1Shotguns = apdMinAmmoT1Shotguns.IntValue;
	iMinAmmoRifles = apdMinAmmoRifles.IntValue;
	iMinAmmoT2Shotguns = apdMinAmmoT2Shotguns.IntValue;
	iMinAmmoSnipers = apdMinAmmoSnipers.IntValue;
	iMinAmmoM60s = apdMinAmmoM60s.IntValue;
	iMinAmmoLaunchers = apdMinAmmoLaunchers.IntValue;
	
	apdLowAmmo.AddChangeHook(OnAPDCVarsChanged);
	apdTankSpawns.AddChangeHook(OnAPDCVarsChanged);
	apdWitchSpawns.AddChangeHook(OnAPDCVarsChanged);
	apdMobSpawns.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoSMGs.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoT1Shotguns.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoRifles.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoT2Shotguns.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoSnipers.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoM60s.AddChangeHook(OnAPDCVarsChanged);
	apdMinAmmoLaunchers.AddChangeHook(OnAPDCVarsChanged);
	
	AutoExecConfig(true, "ammo_pack_deployers-l4d2");
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("tongue_grab", OnTongueGrab);
	HookEvent("tongue_release", OnTongueRelease);
	HookEvent("upgrade_pack_used", OnUpgradePackUsed);
	if (!bIsL4DTFound)
	{
		HookEvent("tank_spawn", OnTankSpawn);
		HookEvent("witch_spawn", OnWitchSpawn);
		HookEvent("create_panic_event", OnCreatePanicEvent);
	}
	
	CreateTimer(1.0, CheckBotsAmmo, _, TIMER_REPEAT);
}

public void OnAPDCVarsChanged(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	bLowAmmo = apdLowAmmo.BoolValue;
	bTankSpawns = apdTankSpawns.BoolValue;
	bWitchSpawns = apdWitchSpawns.BoolValue;
	bMobSpawns = apdMobSpawns.BoolValue;
	
	iMinAmmoSMGs = apdMinAmmoSMGs.IntValue;
	iMinAmmoT1Shotguns = apdMinAmmoT1Shotguns.IntValue;
	iMinAmmoRifles = apdMinAmmoRifles.IntValue;
	iMinAmmoT2Shotguns = apdMinAmmoT2Shotguns.IntValue;
	iMinAmmoSnipers = apdMinAmmoSnipers.IntValue;
	iMinAmmoM60s = apdMinAmmoM60s.IntValue;
	iMinAmmoLaunchers = apdMinAmmoLaunchers.IntValue;
}

public Action CheckBotsAmmo(Handle timer)
{
	if (!IsServerProcessing() || !bLowAmmo)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPrimary = GetPlayerWeaponSlot(i, 0);
			if (HasLowAmmo(i, iPrimary))
			{
				int iPack = GetPlayerWeaponSlot(i, 3);
				if (IsValidEnt(iPack))
				{
					char sPackClass[64];
					GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
					if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false) && !StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
					{
						continue;
					}
					
					FakeClientCommand(i, "use %s", sPackClass);
					CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
					
					break;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action UsePackDelay(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || !IsFakeClient(client) || iDeploy[client] == 1)
	{
		return Plugin_Stop;
	}
	
	iDeploy[client] = 1;
	return Plugin_Stop;
}

public void OnPluginEnd()
{
	apdLowAmmo.RemoveChangeHook(OnAPDCVarsChanged);
	apdTankSpawns.RemoveChangeHook(OnAPDCVarsChanged);
	apdWitchSpawns.RemoveChangeHook(OnAPDCVarsChanged);
	apdMobSpawns.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoSMGs.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoT1Shotguns.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoRifles.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoT2Shotguns.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoSnipers.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoM60s.RemoveChangeHook(OnAPDCVarsChanged);
	apdMinAmmoLaunchers.RemoveChangeHook(OnAPDCVarsChanged);
	
	delete apdLowAmmo;
	delete apdTankSpawns;
	delete apdWitchSpawns;
	delete apdMobSpawns;
	delete apdMinAmmoSMGs;
	delete apdMinAmmoT1Shotguns;
	delete apdMinAmmoRifles;
	delete apdMinAmmoT2Shotguns;
	delete apdMinAmmoSnipers;
	delete apdMinAmmoM60s;
	delete apdMinAmmoLaunchers;
	
	UnhookEvent("round_start", OnRoundStart);
	UnhookEvent("tongue_grab", OnTongueGrab);
	UnhookEvent("tongue_release", OnTongueRelease);
	UnhookEvent("upgrade_pack_used", OnUpgradePackUsed);
	if (!bIsL4DTFound)
	{
		UnhookEvent("tank_spawn", OnTankSpawn);
		UnhookEvent("witch_spawn", OnWitchSpawn);
		UnhookEvent("create_panic_event", OnCreatePanicEvent);
	}
}

public void OnMapStart()
{
	alAmmoPacks = new ArrayList();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1 || entity > 2048)
	{
		return;
	}
	
	if (StrContains(classname, "weapon_", false) != -1)
	{
		CreateTimer(2.0, CheckEntityForGrab, entity);
	}
}

public Action CheckEntityForGrab(Handle timer, any entity)
{
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	char sEntityClass[64];
	GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
	if (StrContains(sEntityClass, "weapon_", false) != -1)
	{
		if (IsIncExp(entity) && !IsAmmoPackOwned(entity))
		{
			for (int i = 0; i < alAmmoPacks.Length; i++)
			{
				if (entity == alAmmoPacks.Get(i))
				{
					return Plugin_Stop;
				}
				else if (!IsValidEntity(alAmmoPacks.Get(i)))
				{
					alAmmoPacks.Erase(i);
				}
			}
			alAmmoPacks.Push(entity);
		}
	}
	
	return Plugin_Stop;
}

public void OnEntityDestroyed(int entity)
{
	if (IsIncExp(entity))
	{
		if (alAmmoPacks == null || IsAmmoPackOwned(entity))
		{
			return;
		}
		
		for (int i = 0; i < alAmmoPacks.Length; i++)
		{
			if (entity == alAmmoPacks.Get(i))
			{
				alAmmoPacks.Erase(i);
			}
		}
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iDeploy[i] = 0;
			
			bTongued[i] = false;
		}
	}
}

public void OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int grabbed = GetClientOfUserId(event.GetInt("victim"));
	if (!IsSurvivor(grabbed) || bTongued[grabbed])
	{
		return;
	}
	
	bTongued[grabbed] = true;
}

public void OnTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int released = GetClientOfUserId(event.GetInt("victim"));
	if (!IsSurvivor(released) || !bTongued[released])
	{
		return;
	}
	
	bTongued[released] = false;
}

public void OnUpgradePackUsed(Event event, const char[] name, bool dontBroadcast)
{
	int upgrader = GetClientOfUserId(event.GetInt("userid"));
	if (!IsSurvivor(upgrader) || !IsPlayerAlive(upgrader) || iDeploy[upgrader] == 0)
	{
		return;
	}
	
	int upgrade = event.GetInt("upgradeid");
	if (IsValidEnt(upgrade))
	{
		char sUpgradeClass[64];
		GetEntityClassname(upgrade, sUpgradeClass, sizeof(sUpgradeClass));
		if (StrEqual(sUpgradeClass, "upgrade_laser_sight"))
		{
			return;
		}
		
		iDeploy[upgrader] = 0;
	}
}

public void OnTankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!bTankSpawns)
	{
		return;
	}
	
	int tank = GetClientOfUserId(event.GetInt("userid"));
	if (tank)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
			{
				if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
				{
					continue;
				}
				
				int iPack = GetPlayerWeaponSlot(i, 3);
				if (IsValidEnt(iPack))
				{
					char sPackClass[64];
					GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
					if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false))
					{
						continue;
					}
					
					FakeClientCommand(i, "use weapon_upgradepack_incendiary");
					CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
					
					break;
				}
			}
		}
	}
}

public void OnWitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!bWitchSpawns)
	{
		return;
	}
	
	int iWitchID = event.GetInt("witchid");
	if (IsValidEnt(iWitchID))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i) && IsFine(i) && iDeploy[i] == 0)
			{
				if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
				{
					continue;
				}
				
				int iPack = GetPlayerWeaponSlot(i, 3);
				if (IsValidEnt(iPack))
				{
					char sPackClass[64];
					GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
					if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false) && !StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
					{
						continue;
					}
					
					FakeClientCommand(i, "use %s", sPackClass);
					CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
					
					break;
				}
			}
		}
	}
}

public void OnCreatePanicEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!bMobSpawns)
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPack = GetPlayerWeaponSlot(i, 3);
			if (IsValidEnt(iPack))
			{
				char sPackClass[64];
				GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
				if (!StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
				{
					continue;
				}
				
				FakeClientCommand(i, "use weapon_upgradepack_explosive");
				CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
				
				break;
			}
		}
	}
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (!bTankSpawns)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPack = GetPlayerWeaponSlot(i, 3);
			if (IsValidEnt(iPack))
			{
				char sPackClass[64];
				GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
				if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false))
				{
					continue;
				}
				
				FakeClientCommand(i, "use weapon_upgradepack_incendiary");
				CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
				
				break;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action L4D_OnSpawnWitch(const float vector[3], const float qangle[3])
{
	if (!bWitchSpawns)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPack = GetPlayerWeaponSlot(i, 3);
			if (IsValidEnt(iPack))
			{
				char sPackClass[64];
				GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
				if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false) && !StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
				{
					continue;
				}
				
				FakeClientCommand(i, "use %s", sPackClass);
				CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
				
				break;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action L4D_OnSpawnWitchBride(const float vector[3], const float qangle[3])
{
	if (!bWitchSpawns)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPack = GetPlayerWeaponSlot(i, 3);
			if (IsValidEnt(iPack))
			{
				char sPackClass[64];
				GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
				if (!StrEqual(sPackClass, "weapon_upgradepack_incendiary", false) && !StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
				{
					continue;
				}
				
				FakeClientCommand(i, "use %s", sPackClass);
				CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
				
				break;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &amount)
{
	if (!bMobSpawns)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i) && IsFine(i))
		{
			if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
			{
				continue;
			}
			
			int iPack = GetPlayerWeaponSlot(i, 3);
			if (IsValidEnt(iPack))
			{
				char sPackClass[64];
				GetEntityClassname(iPack, sPackClass, sizeof(sPackClass));
				if (!StrEqual(sPackClass, "weapon_upgradepack_explosive", false))
				{
					continue;
				}
				
				FakeClientCommand(i, "use weapon_upgradepack_explosive");
				CreateTimer(0.2, UsePackDelay, GetClientUserId(i));
				
				break;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action L4D2_OnFindScavengeItem(int client, int &item)
{
	if (!item)
	{
		float fItemPos[3], fScavengerPos[3];
		
		int iPack = GetPlayerWeaponSlot(client, 3);
		if (!IsValidEdict(iPack))
		{
			for (int i = 0; i < alAmmoPacks.Length; i++)
			{
				if (!IsValidEntity(alAmmoPacks.Get(i)))
				{
					return Plugin_Continue;
				}
				
				char sItemClass[64];
				GetEntityClassname(alAmmoPacks.Get(i), sItemClass, sizeof(sItemClass));
				if (StrContains(sItemClass, "weapon_", false) == -1)
				{
					alAmmoPacks.Erase(i);
					return Plugin_Continue;
				}
				
				GetEntPropVector(alAmmoPacks.Get(i), Prop_Send, "m_vecOrigin", fItemPos);
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", fScavengerPos);
				
				float fDist = GetVectorDistance(fScavengerPos, fItemPos);
				if (fDist < 250.0)
				{
					item = alAmmoPacks.Get(i);
					return Plugin_Changed;
				}
			}
		}
	}
	else
	{
		int iPack = GetPlayerWeaponSlot(client, 3);
		
		if (IsIncExp(item))
		{
			if (IsPack(iPack))
			{
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsSurvivor(client) && IsPlayerAlive(client) && IsFakeClient(client) && IsFine(client))
	{
		int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon > 0 && IsValidEntity(iActiveWeapon))
		{
			char sWeaponClass[64];
			GetEntityClassname(iActiveWeapon, sWeaponClass, sizeof(sWeaponClass));
			if (iActiveWeapon == GetPlayerWeaponSlot(client, 3) && (StrEqual(sWeaponClass, "weapon_upgradepack_incendiary") || StrEqual(sWeaponClass, "weapon_upgradepack_explosive")))
			{
				if (iDeploy[client] == 1)
				{
					buttons |= IN_ATTACK;
				}
				else
				{
					buttons &= ~IN_ATTACK;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnMapEnd()
{
	alAmmoPacks.Clear();
}

bool IsIncExp(int entity)
{
	if (entity > 0 && entity < 2049 && IsValidEntity(entity))
	{
		char sEntityClass[64], sEntityModel[128];
		
		GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
		GetEntPropString(entity, Prop_Data, "m_ModelName", sEntityModel, sizeof(sEntityModel));
		
		if (StrEqual(sEntityClass, "weapon_upgradepack_incendiary") || StrEqual(sEntityClass, "weapon_upgradepack_incendiary_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_incendiary_ammopack.mdl") || 
			StrEqual(sEntityClass, "weapon_upgradepack_explosive") || StrEqual(sEntityClass, "weapon_upgradepack_explosive_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_explosive_ammopack.mdl"))
		{
			return true;
		}
	}
	
	return false;
}

bool IsAmmoPackOwned(int entity)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (GetPlayerWeaponSlot(i, 3) == entity)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool IsPack(int entity)
{
	if (IsValidEnt(entity))
	{
		if (IsIncExp(entity) || IsDefKit(entity))
		{
			return true;
		}
	}
	
	return false;
}

bool IsDefKit(int entity)
{
	if (entity > 0 && entity < 2049 && IsValidEntity(entity))
	{
		char sEntityClass[64], sEntityModel[128];
		
		GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
		GetEntPropString(entity, Prop_Data, "m_ModelName", sEntityModel, sizeof(sEntityModel));
		
		if (StrEqual(sEntityClass, "weapon_defibrillator") || StrEqual(sEntityClass, "weapon_defibrillator_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_defibrillator.mdl") || 
			StrEqual(sEntityClass, "weapon_first_aid_kit") || StrEqual(sEntityClass, "weapon_first_aid_kit_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_medkit.mdl"))
		{
			return true;
		}
	}
	
	return false;
}

bool HasLowAmmo(int client, int weapon)
{
	if (IsValidEnt(weapon))
	{
		char sWeaponClass[64];
		GetEdictClassname(weapon, sWeaponClass, sizeof(sWeaponClass));
		if (StrEqual(sWeaponClass, "weapon_grenade_launcher"))
		{
			if (GetEntData(client, FindDataMapInfo(client, "m_iAmmo") + (68)) <= iMinAmmoLaunchers)
			{
				return true;
			}
		}
		else
		{
			int iPrimaryType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"),
				iAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", _, iPrimaryType);
			
			if ((StrEqual(sWeaponClass, "weapon_smg") || StrEqual(sWeaponClass, "weapon_smg_silenced") || StrEqual(sWeaponClass, "weapon_smg_mp5")) && iAmmo <= iMinAmmoSMGs)
			{
				return true;
			}
			else if ((StrEqual(sWeaponClass, "weapon_pumpshotgun") || StrEqual(sWeaponClass, "weapon_shotgun_chrome")) && iAmmo <= iMinAmmoT1Shotguns)
			{
				return true;
			}
			else if ((StrEqual(sWeaponClass, "weapon_rifle") || StrEqual(sWeaponClass, "weapon_rifle_ak47") || StrEqual(sWeaponClass, "weapon_rifle_desert") || StrEqual(sWeaponClass, "weapon_rifle_sg552")) && iAmmo <= iMinAmmoRifles)
			{
				return true;
			}
			else if ((StrEqual(sWeaponClass, "weapon_autoshotgun") || StrEqual(sWeaponClass, "weapon_shotgun_spas")) && iAmmo <= iMinAmmoT2Shotguns)
			{
				return true;
			}
			else if ((StrEqual(sWeaponClass, "weapon_hunting_rifle") || StrEqual(sWeaponClass, "weapon_sniper_military") || StrEqual(sWeaponClass, "weapon_sniper_scout") || StrEqual(sWeaponClass, "weapon_sniper_awp")) && iAmmo <= iMinAmmoSnipers)
			{
				return true;
			}
			else if (StrEqual(sWeaponClass, "weapon_rifle_m60") && iAmmo <= iMinAmmoM60s)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool IsFine(int client)
{
	return (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !bTongued[client] && GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") < 1 && 
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") < 1 && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") < 1 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") < 1);
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

