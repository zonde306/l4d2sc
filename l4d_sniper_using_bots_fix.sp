#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define PLUGIN_VERSION "1.1"

new ammoOffset;
new ammotype;

public Plugin:myinfo = 
{
	name = "修复幸存者机器人不使用狙击枪",
	author = "sereky",
	description = "Fixes Bugs About Bots Using Snipers.",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (StrEqual(game_name, "left4dead2", false))
	{
		ammotype = 36;
	}
	else if (StrEqual(game_name, "left4dead", false))
	{
		ammotype = 8;
	}
	else
	{
		SetFailState("[FIX] Plugin Supports L4D and L4D2 Only!");
	}
	
	ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	CreateConVar("sniper_using_bots_version", PLUGIN_VERSION, "Sniper Using Bots Fix Version", FCVAR_SPONLY|FCVAR_NOTIFY);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action:OnWeaponSwitch(client, weapon)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsFakeClient(client) && !IsIncapacitated(client))
	{
		if (weapon != -1 && IsValidEdict(weapon))
		{
			decl String:sClassname[32];
			GetEdictClassname(weapon, sClassname, sizeof(sClassname));
			if (StrEqual(sClassname, "weapon_pistol"))
			{
				new i_Weapon = GetPlayerWeaponSlot(client, 0);
				if (i_Weapon != -1 && IsValidEdict(i_Weapon))
				{
					new String:sniper[64];
					GetEdictClassname(i_Weapon, sniper, sizeof(sniper));
					if (StrEqual(sniper, "weapon_hunting_rifle"))
					{
						new ammohunr = GetEntData(client, ammoOffset + (ammotype));
						if (ammohunr != 0)
						{
							return Plugin_Handled;
						}
					}
					else if (StrEqual(sniper, "weapon_sniper_scout"))
					{
						new ammosnip = GetEntData(client, ammoOffset + (40));
						if (ammosnip != 0)
						{
							return Plugin_Handled;
						}
					}
					else if (StrEqual(sniper, "weapon_sniper_military"))
					{
						new ammosnip = GetEntData(client, ammoOffset + (40));
						if (ammosnip != 0)
						{
							return Plugin_Handled;
						}
					}
					else if (StrEqual(sniper, "weapon_sniper_awp"))
					{
						new ammosnip = GetEntData(client, ammoOffset + (40));
						if (ammosnip != 0)
						{
							return Plugin_Handled;
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool:IsIncapacitated(client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0)
	{
		return true;
	}
	return false;
}

