#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1
#include <l4d2_skill_framework>
// #include "modules/l4d2ps.sp"

#define L4D2 Charger Jump
#define PLUGIN_VERSION "1.11"

#define ZOMBIECLASS_CHARGER 						6

new Handle:cvarInertiaVault;
new Handle:cvarInertiaVaultPower;

new Handle:PluginStartTimer = INVALID_HANDLE;
new Handle:cvarResetDelayTimer[MAXPLAYERS+1] = INVALID_HANDLE;

new bool:isCharging[MAXPLAYERS+1] = false;
new bool:buttondelay[MAXPLAYERS+1] = false;
new bool:isInertiaVault = false;


public Plugin:myinfo = 
{
    name = "牛跳跃",
    author = "Mortiegama",
    description = "Allows the Charger to jump while Charging.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2116076#post2116076"
}

int g_iSlotAbility;
int g_iLevelJump[MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("l4d_cjm_version", PLUGIN_VERSION, "Charger Jump Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvarInertiaVault = CreateConVar("l4d_cjm_inertiavault", "1", "Enables the ability Inertia Vault, allows the Charger to jump while charging. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarInertiaVaultPower = CreateConVar("l4d_cjm_inertiavaultpower", "400.0", "Power behind the Charger's jump. (Def 400.0)", FCVAR_PLUGIN, true, 0.0, false, _);

	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);	
	
	AutoExecConfig(true, "L4D2_ChargerJump");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	
	LoadTranslations("l4d2sf_charger_jump.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "charger_jump", 1, 25, 5, 2.0);
}

stock char tr(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);
	return buffer;
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "charger_jump"))
		FormatEx(result, maxlen, "%T", "牛起跳", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "charger_jump"))
		FormatEx(result, maxlen, "%T", tr("牛起跳%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "charger_jump"))
		g_iLevelJump[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelJump[client] = L4D2SF_GetClientPerk(client, "charger_jump");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelJump[client] = L4D2SF_GetClientPerk(client, "charger_jump");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public Action:OnPluginStart_Delayed(Handle:timer)
{	
	if (GetConVarInt(cvarInertiaVault))
	{
		isInertiaVault = true;
	}
	
	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public Event_ChargeStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		isCharging[client] = true;
	}
}

public Event_ChargeEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		isCharging[client] = false;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_JUMP && IsValidCharger(client) && isCharging[client] && g_iLevelJump[client] > 0)
	{
		if (isInertiaVault && !buttondelay[client] && IsPlayerOnGround(client))
		{
			buttondelay[client] = true;
			new Float:vec[3];
			new Float:power = GetConVarFloat(cvarInertiaVaultPower);
			vec[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
			vec[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
			vec[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]") + power;
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
			cvarResetDelayTimer[client] = CreateTimer(1.0, ResetDelay, client);
		}
	}
}

public Action:ResetDelay(Handle:timer, any:client)
{
	buttondelay[client] = false;
	
	if (cvarResetDelayTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarResetDelayTimer[client]);
		cvarResetDelayTimer[client] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public OnMapEnd()
{
    for (new client=1; client<=MaxClients; client++)
	{
	if (IsValidClient(client))
		{
			isCharging[client] = false;
		}
	}
}

public IsValidClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	return true;
}

public IsPlayerOnGround(client)
{
	if (GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND) return true;
		else return false;
}

public IsValidCharger(client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_CHARGER)
			return true;
		
		return false;
	}
	
	return false;
}