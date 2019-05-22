#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

bool bPassedPills[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "递药不切换武器",
    author = "MasterMind420",
    description = "防秒妹递药",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
	HookEvent("weapon_given", eWeaponGiven, EventHookMode_Pre);
	HookEvent("player_disconnect", ePlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
		SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	if(IsValidClient(client) && IsValidEntity(weapon))
	{
		if(GetClientTeam(client) == 2)
		{
			if(bPassedPills[client])
			{
				bPassedPills[client] = false;

				char sClsName[32];
				GetEntityClassname(weapon, sClsName, sizeof(sClsName));

				if(StrContains(sClsName, "adrenaline") > -1 || StrContains(sClsName, "pills") > -1)
					return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public void eWeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	int receiver = GetClientOfUserId(event.GetInt("userid"));

	char item[32];
	GetEventString(event, "weapon", item, sizeof(item));

	if(StrEqual(item, "15") || StrEqual(item, "23"))
		bPassedPills[receiver] = true;
}

public Action ePlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		bPassedPills[client] = false;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}