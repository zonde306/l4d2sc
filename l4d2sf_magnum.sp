#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：倒地武器",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 1;
const int g_iMinLevel = 3;
const int g_iMinSkillLevel = 20;
const float g_fLevelFactor = 1.0;

int g_iSlotPistol;
int g_iLevelMagnum[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("survivor_rescued", Event_SurvivorRescued);
	
	LoadTranslations("l4d2sf_magnum.phrases.txt");
	
	g_iSlotPistol = L4D2SF_RegSlot("pistol");
	L4D2SF_RegPerk(g_iSlotPistol, "incap_magnum", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "incap_magnum"))
		FormatEx(result, maxlen, "%T", "倒地马格南", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "incap_magnum"))
		FormatEx(result, maxlen, "%T", tr("倒地马格南%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "incap_magnum"))
		g_iLevelMagnum[client] = level;
}

enum WeaponType_t
{
	WEAPON_UNKNOWN,
	WEAPON_PISTOL,
	WEAPON_DOUBLE,
	WEAPON_MELEE,
	WEAPON_MAGNUM,
	WEAPON_CHAINSAW,
};

char g_szMeleeWeapon[MAXPLAYERS+1][32];
int g_iChainsawClip[MAXPLAYERS+1];
WeaponType_t g_eWeaponType[MAXPLAYERS+1];

public void L4D2SF_OnLoad(int client)
{
	g_iLevelMagnum[client] = L4D2SF_GetClientPerk(client, "incap_magnum");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelMagnum[client] = L4D2SF_GetClientPerk(client, "incap_magnum");
	
	if(g_iLevelMagnum[client] >= 1)
	{
		// RestoreWeapon(client);
		RequestFrame(RestoreWeapon, client);
	}
}

public void Event_PlayerIncapacitatedStart(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || g_iLevelMagnum[client] <= 0)
		return;
	
	char classname[64];
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon <= MaxClients || !IsValidEdict(weapon) || !GetEdictClassname(weapon, classname, sizeof(classname)))
		return;
	
	if(!strcmp(classname, "weapon_pistol", false))
	{
		if(GetEntProp(weapon, Prop_Send, "m_hasDualWeapons", 1))
			g_eWeaponType[client] = WEAPON_DOUBLE;
		else
			g_eWeaponType[client] = WEAPON_PISTOL;
	}
	else if(!strcmp(classname, "weapon_melee", false))
	{
		g_eWeaponType[client] = WEAPON_MELEE;
		GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", g_szMeleeWeapon[client], sizeof(g_szMeleeWeapon[]));
	}
	else if(!strcmp(classname, "weapon_pistol_magnum", false))
	{
		g_eWeaponType[client] = WEAPON_MAGNUM;
	}
	else if(!strcmp(classname, "weapon_chainsaw", false))
	{
		g_eWeaponType[client] = WEAPON_CHAINSAW;
		g_iChainsawClip[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");
	}
	
	PrintToServer("player %N incap, weapon %d", client, g_eWeaponType[client]);
}

public void Event_PlayerIncapacitated(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || g_iLevelMagnum[client] <= 0)
		return;
	
	if(g_eWeaponType[client] == WEAPON_UNKNOWN)
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && IsValidEdict(weapon))
		RemoveEdict(weapon);
	
	CheatCommand(client, "give", "pistol_magnum");
	CreateTimer(0.25, Timer_CheckPistol, client);
}

public void Event_ReviveSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || g_iLevelMagnum[client] <= 0)
		return;
	
	RestoreWeapon(client);
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_eWeaponType[player] = g_eWeaponType[bot];
	g_iChainsawClip[player] = g_iChainsawClip[bot];
	g_szMeleeWeapon[player] = g_szMeleeWeapon[bot];
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_eWeaponType[bot] = g_eWeaponType[player];
	g_iChainsawClip[bot] = g_iChainsawClip[player];
	g_szMeleeWeapon[bot] = g_szMeleeWeapon[player];
}

public void Event_DefibrillatorUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || g_iLevelMagnum[client] <= 0)
		return;
	
	// RestoreWeapon(client);
	RequestFrame(RestoreWeapon, client);
}

public void Event_SurvivorRescued(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || g_iLevelMagnum[client] <= 0)
		return;
	
	// RestoreWeapon(client);
	RequestFrame(RestoreWeapon, client);
}

public void RestoreWeapon(any client)
{
	if(g_eWeaponType[client] == WEAPON_UNKNOWN)
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && IsValidEdict(weapon))
		RemoveEdict(weapon);
	
	switch(g_eWeaponType[client])
	{
		case WEAPON_PISTOL:
		{
			CheatCommand(client, "give", "pistol");
		}
		case WEAPON_DOUBLE:
		{
			CheatCommand(client, "give", "pistol");
			CheatCommand(client, "give", "pistol");
		}
		case WEAPON_MELEE:
		{
			CheatCommand(client, "give", g_szMeleeWeapon[client]);
		}
		case WEAPON_MAGNUM:
		{
			CheatCommand(client, "give", "pistol_magnum");
		}
		case WEAPON_CHAINSAW:
		{
			CheatCommand(client, "give", "chainsaw");
			CreateTimer(0.1, Timer_SetClip, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	PrintToServer("player %N restore weapon %d", client, g_eWeaponType[client]);
	g_eWeaponType[client] = WEAPON_UNKNOWN;
}

public Action Timer_SetClip(Handle timer, any client)
{
	if(!IsValidClient(client))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && IsValidEdict(weapon))
		SetEntProp(weapon, Prop_Send, "m_iClip1", g_iChainsawClip[client]);
}

public Action Timer_CheckPistol(Handle timer, any client)
{
	if(!IsValidClient(client))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon < MaxClients)
		CheatCommand(client, "give", "pistol_magnum");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}
