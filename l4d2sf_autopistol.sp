#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：手枪连射",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 2;
const int g_iMinLevel = 1;
const int g_iMinSkillLevel = 10;
const float g_fLevelFactor = 1.0;

int g_iSlotPistol;
int g_iLevelAutoPistol[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	LoadTranslations("l4d2sf_autopistol.phrases.txt");
	
	g_iSlotPistol = L4D2SF_RegSlot("pistol");
	L4D2SF_RegPerk(g_iSlotPistol, "autopistol", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "autopistol"))
		FormatEx(result, maxlen, "%T", "手枪连射", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "autopistol"))
		FormatEx(result, maxlen, "%T", tr("手枪连射%d", IntBound(level, 1, g_iMaxLevel)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "autopistol"))
		g_iLevelAutoPistol[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelAutoPistol[client] = L4D2SF_GetClientPerk(client, "autopistol");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelAutoPistol[client] = L4D2SF_GetClientPerk(client, "autopistol");
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon,
	int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(weapon < MaxClients)
		weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(g_iLevelAutoPistol[client] <= 0 || !(buttons & IN_ATTACK) || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname)))
		return;
	
	if(g_iLevelAutoPistol[client] == 1)
	{
		if(IsPistol(classname))
			SetEntProp(weapon, Prop_Send, "m_isHoldingFireButton", 0, 1);
	}
	else if(g_iLevelAutoPistol[client] >= 2)
	{
		if(HasEntProp(weapon, Prop_Send, "m_isHoldingFireButton"))
			SetEntProp(weapon, Prop_Send, "m_isHoldingFireButton", 0, 1);
	}
}

bool IsShotgun(const char[] weapon)
{
	return StrContains(weapon, "shotgun") > -1;
}

bool IsPistol(const char[] weapon)
{
	return StrContains(weapon, "pistol") > -1;
}

bool IsSniper(const char[] weapon)
{
	return StrContains(weapon, "sniper") > -1 || !strcmp(weapon, "weapon_hunting_rifle");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}
