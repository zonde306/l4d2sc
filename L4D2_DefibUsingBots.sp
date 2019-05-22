#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.6"
#define STARTSHOOTING 1
#define STOPSHOOTING 0

static shoot[MAXPLAYERS + 1] = 0;

static Handle:MedsArray = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D2] Defib using bots", 
	author = "DeathChaos25", 
	description = "Allows bots to use Defibrillators in L4D2", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=261566"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:s_GameFolder[32];
	GetGameFolderName(s_GameFolder, sizeof(s_GameFolder));
	if (!StrEqual(s_GameFolder, "left4dead2", false))
	{
		strcopy(error, err_max, "This plugin is for Left 4 Dead 2 Only!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	CreateConVar("sm_defib_bots_version", PLUGIN_VERSION, "Defib Bots Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	CreateTimer(1.0, BotsDefib, _, TIMER_REPEAT);
	CreateTimer(1.0, CheckForPickUps, _, TIMER_REPEAT);
	
	HookEvent("defibrillator_used_fail", Event_DefibFailed);
	HookEvent("defibrillator_interrupted", Event_DefibFailed);
	HookEvent("defibrillator_used", Event_DefibUsed);
	
	RegAdminCmd("sm_resetbots", ResetSurvivorAI, ADMFLAG_ROOT, "Completely Resets Survivor AI");
	RegAdminCmd("sm_regroup", RegroupBots, ADMFLAG_ROOT, "Commands Survivor Bots to move to your location");
	RegAdminCmd("sm_attack", AttackSI, ADMFLAG_ROOT, "Orders Survivor Bots to Attack the SI you are aiming at");
	RegAdminCmd("sm_retreat", RunAway, ADMFLAG_ROOT, "Orders Survivor Bots to retreat from the SI you are aiming at");
}

public OnEntityCreated(entity, const String:classname[])
{
	if (entity <= 0 || entity > 2048 || classname[0] != 'w')return;
	CreateTimer(2.0, CheckEntityForGrab, entity);
}

// checking for Defibs for the defib pickup
public OnEntityDestroyed(entity)
{
	if (entity <= 0 || entity > 2048)return;
	
	if (MedsArray != INVALID_HANDLE)
	{
		for (new i = 0; i <= GetArraySize(MedsArray) - 1; i++)
		{
			if (entity == GetArrayCell(MedsArray, i))
			{
				RemoveFromArray(MedsArray, i);
			}
		}
	}
}

// Timer based functions
public Action:CheckForPickUps(Handle:Timer)
{
	// trying to account for late loading and unexpected
	// or unreported weapons (stripper created weapons dont seem to fire OnEntityCreated)
	if (!IsServerProcessing())
	{
		return;
	}
	
	for (new entity = 0; entity < 2048; entity++)
	{
		if (!IsValidEntity(entity))
		{
			continue;
		}
		new String:classname[128];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "weapon_defibrillator", false)
			 || StrEqual(classname, "weapon_defibrillator_spawn", false)
			 || StrEqual(classname, "weapon_first_aid_kit", false)
			 || StrEqual(classname, "weapon_first_aid_kit_spawn", false))
		{
			if (!IsDefibOwned(entity))
			{
				for (new i = 0; i <= GetArraySize(MedsArray) - 1; i++)
				{
					if (entity == GetArrayCell(MedsArray, i))
					{
						return;
					}
					else if (!IsValidEntity(entity))
					{
						RemoveFromArray(MedsArray, entity);
					}
				}
				PushArrayCell(MedsArray, entity);
			}
			else if(IsDefibOwned(entity))
			{
				for (new i = 0; i <= GetArraySize(MedsArray) - 1; i++)
				{
					if (entity == GetArrayCell(MedsArray, i))
					{
						RemoveFromArray(MedsArray, i);
					}
				}
			}
		}
	}
}

public Action:CheckEntityForGrab(Handle:timer, any:entity)
{
	if (IsValidEntity(entity) && MedsArray != INVALID_HANDLE)
	{
		new String:classname[128];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "weapon_defibrillator", false)
			 || StrEqual(classname, "weapon_defibrillator_spawn", false)
			 || StrEqual(classname, "weapon_first_aid_kit", false)
			 || StrEqual(classname, "weapon_first_aid_kit_spawn", false))
		{
			if (!IsDefibOwned(entity))
			{
				for (new i = 0; i <= GetArraySize(MedsArray) - 1; i++)
				{
					if (entity == GetArrayCell(MedsArray, i))
					{
						return;
					}
				}
				PushArrayCell(MedsArray, entity);
			}
		}
	}
}

public Action:BotsDefib(Handle:timer)
{
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}
	
	decl Float:Origin[3], Float:TOrigin[3];
	new i = -1;
	while ((i = FindEntityByClassname(i, "survivor_death_model")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", Origin);
		for (new j = 1; j <= MaxClients; j++)
		{
			if (IsSurvivor(j) && IsFakeClient(j) && IsPlayerAlive(j) && !IsIncapacitated(j) && !IsPlayerHeld(j) && !IsAssistNeeded() && ClientHasFewThreats(j))
			{
				GetEntPropVector(j, Prop_Send, "m_vecOrigin", TOrigin);
				new Float:distance = GetVectorDistance(TOrigin, Origin);
				new String:defib[32];
				if (IsValidEdict(GetPlayerWeaponSlot(j, 3)))
				{
					GetEdictClassname(GetPlayerWeaponSlot(j, 3), defib, sizeof(defib));
					if (distance > 100 && distance < 800)
					{
						if (StrEqual(defib, "weapon_defibrillator"))
						{
							ScriptCommand(j, "script", "CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", Origin[0], Origin[1], Origin[2], GetClientUserId(j));
							break;
						}
					}
					else if (distance < 100)
					{
						if (StrEqual(defib, "weapon_defibrillator") && ChangePlayerWeaponSlot(j, 3))
						{
							decl Float:EyePos[3], Float:AimOnDeadSurvivor[3], Float:AimAngles[3];
							GetClientEyePosition(j, EyePos);
							MakeVectorFromPoints(EyePos, Origin, AimOnDeadSurvivor);
							GetVectorAngles(AimOnDeadSurvivor, AimAngles);
							TeleportEntity(j, NULL_VECTOR, AimAngles, NULL_VECTOR);
							
							CreateTimer(0.2, AllowDefib, GetClientUserId(j), TIMER_FLAG_NO_MAPCHANGE);
							break;
						}
					}
				}
			}
		}
		break;
	}
	return Plugin_Continue;
}

// Bot AI Manipulations Functions
public Action:RegroupBots(client, args)
{
	decl Float:Origin[3];
	GetClientAbsOrigin(client, Origin);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i) && !IsAssistNeeded() && ClientHasFewThreats(i))
		{
			ScriptCommand(i, "script", "CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", Origin[0], Origin[1], Origin[2], GetClientUserId(i));
		}
	}
}

public Action:AttackSI(client, args)
{
	if (!IsSurvivor(client))
		return;
	
	new target = GetClientAimTarget(client);
	if (!IsInfected(target))
		return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i) && !IsAssistNeeded())
		{
			ScriptCommand(i, "script", "CommandABot({cmd=0,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(i), GetClientUserId(target));
		}
	}
}

public Action:RunAway(client, args)
{
	if (!IsSurvivor(client))
		return;
	
	new target = GetClientAimTarget(client);
	if (!IsInfected(target))
		return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i) && !IsAssistNeeded())
		{
			ScriptCommand(i, "script", "CommandABot({cmd=2,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(i), GetClientUserId(target));
		}
	}
}

// This only fires if we have Left4Downtown2!
public Action:L4D2_OnFindScavengeItem(client, &item)
{
	if (!item)
	{
		decl Float:Origin[3], Float:TOrigin[3];
		if (MedsArray != INVALID_HANDLE)
		{
			new iWeapon = GetPlayerWeaponSlot(client, 3);
			if (iWeapon > MaxClients)
			{
				new String:weapon[32];
				if (IsValidEdict(GetEdictClassname(GetPlayerWeaponSlot(client, 3), weapon, sizeof(weapon))))
				{
					if (StrEqual(weapon, "weapon_defibrillator") || StrEqual(weapon, "weapon_first_aid_kit"))
					{
						return Plugin_Continue;
					}
				}
			}
			for (new i = 0; i <= GetArraySize(MedsArray) - 1; i++)
			{
				if (IsValidEntity(i))
				{
					GetEntPropVector(GetArrayCell(MedsArray, i), Prop_Send, "m_vecOrigin", Origin);
					GetEntPropVector(client, Prop_Send, "m_vecOrigin", TOrigin);
					new Float:distance = GetVectorDistance(TOrigin, Origin);
					if (distance < 300)
					{
						item = GetArrayCell(MedsArray, i);
						return Plugin_Changed;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

// Functions to allow the Bot to use Defibs
public Action:AllowDefib(Handle:Timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	shoot[client] = STARTSHOOTING;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsSurvivor(client) && IsPlayerAlive(client) && IsFakeClient(client))
	{
		new defib = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(defib))
		{
			decl String:classname[128];
			GetEntityClassname(defib, classname, sizeof(classname));
			if (defib == GetPlayerWeaponSlot(client, 3) && StrEqual(classname, "weapon_defibrillator"))
			{
				if (shoot[client] == STARTSHOOTING)
				{
					buttons |= IN_ATTACK;
				}
				else if (shoot[client] == STOPSHOOTING)
				{
					buttons &= ~IN_ATTACK;
				}
			}
		}
	}
	return Plugin_Continue;
}

// Event Hooks so we can reset bots and prevent them from being stuck in the trying to defib state
public Action:Event_DefibUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client) && IsFakeClient(client))
	{
		shoot[client] = STOPSHOOTING;
		CreateTimer(0.4, ResetBotAI, GetClientUserId(client));
	}
}

public Action:Event_DefibFailed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client) && IsFakeClient(client))
	{
		shoot[client] = STOPSHOOTING;
		CreateTimer(6.0, ResetBotAI, GetClientUserId(client));
	}
}

public Action:ResetSurvivorAI(client, args)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i) && !IsAssistNeeded() && ClientHasFewThreats(i))
		{
			ScriptCommand(i, "script", "CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(i));
		}
	}
}

public Action:ResetBotAI(Handle:Timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsSurvivor(client) && IsFakeClient(client))
	{
		shoot[client] = STOPSHOOTING;
		ScriptCommand(client, "script", "CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
	}
}

// Stock functions, bools, etc
stock bool:IsIncapacitated(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0)
		return true;
	return false;
}

stock bool:ChangePlayerWeaponSlot(Client, weaponslot)
{
	new iWeapon = GetPlayerWeaponSlot(Client, weaponslot);
	if (iWeapon > MaxClients)
	{
		new String:weapon[32];
		if (IsValidEdict(GetEdictClassname(GetPlayerWeaponSlot(Client, 3), weapon, sizeof(weapon))))
		{
			if (StrEqual(weapon, "weapon_defibrillator"))
			{
				FakeClientCommand(Client, "use weapon_defibrillator");
				return true;
			}
		}
	}
	return false;
}

stock bool:IsPlayerHeld(client)
{
	new jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	new charger = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	new hunter = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	new smoker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (jockey > 0 || charger > 0 || hunter > 0 || smoker > 0)
	{
		return true;
	}
	return false;
}

stock bool:IsAssistNeeded()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i))
		{
			if (IsIncapacitated(i) || IsPlayerHeld(i))
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:IsDefibOwned(defib)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i))
		{
			if (GetPlayerWeaponSlot(i, 3) == defib)
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:ClientHasFewThreats(client)
{
	if (IsSurvivor(client))
	{
		new threats = GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
		if (threats <= 0)
		{
			return true;
		}
	}
	return false;
}

stock ScriptCommand(client, const String:command[], const String:arguments[], any:...)
{
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 4);
	
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags^FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, vscript);
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}

stock bool:IsSurvivor(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}

stock bool:IsInfected(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		return true;
	}
	return false;
} 

public OnMapStart()
{
	MedsArray = CreateArray();
}

public OnMapEnd()
{
	CloseHandle(MedsArray);
	MedsArray = INVALID_HANDLE;
}