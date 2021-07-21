#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#define PL_VERSION "2.1"

new Float:fLastMeleeSwing[MAXPLAYERS + 1];
new bool:bLate;

public Plugin myinfo =
{
	name = "速砍修复",
	author = "sheo",
	description = "Fixes the bug with too fast melee attacks",
	version = PL_VERSION,
	url = "http://steamcommunity.com/groups/b1com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	bLate = late;
	return APLRes_Success;
}

int g_iSlotMelee;
int g_iLevelMelee[MAXPLAYERS+1];

public OnPluginStart()
{
	decl String:gfstring[128];
	GetGameFolderName(gfstring, sizeof(gfstring));
	if (!StrEqual(gfstring, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	HookEvent("weapon_fire", Event_WeaponFire);
	CreateConVar("l4d2_fast_melee_fix_version", PL_VERSION, "Fast melee fix version", FCVAR_PLUGIN | FCVAR_NOTIFY);
	if (bLate)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
			}
		}
	}
	
	LoadTranslations("l4d2sf_fast_melee.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotMelee = L4D2SF_RegSlot("melee");
	L4D2SF_RegPerk(g_iSlotMelee, "fast_melee", 1, 5, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "fast_melee"))
		FormatEx(result, maxlen, "%T", "速砍", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "fast_melee"))
		FormatEx(result, maxlen, "%T", tr("速砍%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "fast_melee"))
		g_iLevelMelee[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelMelee[client] = L4D2SF_GetClientPerk(client, "fast_melee");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelMelee[client] = L4D2SF_GetClientPerk(client, "fast_melee");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public OnClientPutInServer(client)
{
	if (!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
	}
	fLastMeleeSwing[client] = 0.0;
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && !IsFakeClient(client))
	{
		decl String:sBuffer[64];
		GetEventString(event, "weapon", sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "melee"))
		{
			fLastMeleeSwing[client] = GetGameTime();
		}
	}
}

public OnWeaponSwitched(client, weapon)
{
	if (!IsFakeClient(client) && g_iLevelMelee[client] < 1)
	{
		decl String:sBuffer[32];
		GetEntityClassname(weapon, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "weapon_melee"))
		{
			new Float:fShouldbeNextAttack = fLastMeleeSwing[client] + 0.92;
			new Float:fByServerNextAttack = GetGameTime() + 0.5;
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", (fShouldbeNextAttack > fByServerNextAttack) ? fShouldbeNextAttack : fByServerNextAttack);
		}
	}
}