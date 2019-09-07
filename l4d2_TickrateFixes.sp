/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
//<<<<<<<<<<<<<<<<<<<<< TICKRATE FIXES >>>>>>>>>>>>>>>>>>
//// ------- Fast Pistols ---------
// ***************************** 
//Cvars
ConVar g_hPistolDelayDualies;
ConVar g_hPistolDelaySingle;
ConVar g_hPistolDelayIncapped;

//Floats
float g_fNextAttack[MAXPLAYERS + 1];
float g_fPistolDelayDualies 		= 0.1;
float g_fPistolDelaySingle 		= 0.2;
float g_fPistolDelayIncapped 		= 0.3;

float tickInterval;
float tickRRate;

//Cvar Check & Adjust
ConVar g_hCvarGravity;

#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "高 tick 修复",
	author = "Sir, Griffin",
	description = "Fixes a handful of silly Tickrate bugs",
	version = "1.0",
	url = "Nawl."
}

public OnPluginStart()
{
	//Is Server 40+ Tick?
    tickInterval = GetTickInterval();
    if(0.0 < tickInterval) tickRRate = 1.0/tickInterval;
    if(tickRRate >= 40)
    {
        //Hook Pistols
        for (int client = 1; client <= MaxClients; client++)
        {
            if (!IsClientInGame(client)) continue;
            SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
        }
        g_hPistolDelayDualies = CreateConVar("l4d_pistol_delay_dualies", "0.1", "Minimum time (in seconds) between dual pistol shots", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        g_hPistolDelaySingle = CreateConVar("l4d_pistol_delay_single", "0.2", "Minimum time (in seconds) between single pistol shots", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        g_hPistolDelayIncapped = CreateConVar("l4d_pistol_delay_incapped", "0.3", "Minimum time (in seconds) between pistol shots while incapped", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        
        UpdatePistolDelays();
        
        HookConVarChange(g_hPistolDelayDualies, Cvar_PistolDelay);
        HookConVarChange(g_hPistolDelaySingle, Cvar_PistolDelay);
        HookConVarChange(g_hPistolDelayIncapped, Cvar_PistolDelay);
        HookEvent("weapon_fire", Event_WeaponFire);
        
        //Gravity
        g_hCvarGravity = FindConVar("sv_gravity");
        if (GetConVarInt(g_hCvarGravity) != 750) SetConVarInt(g_hCvarGravity, 750);
    }
	else
	{
		// We don't need you on this 30T Server
		// ServerCommand("sm plugins unload l4d2_TickrateFixes.smx");
		SetFailState("We don't need you on this 30T Server");
	}
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_PreThink, Hook_OnPostThinkPost);
    g_fNextAttack[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_PreThink, Hook_OnPostThinkPost);
}

public void Cvar_PistolDelay(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdatePistolDelays();
}

stock UpdatePistolDelays()
{
    g_fPistolDelayDualies = GetConVarFloat(g_hPistolDelayDualies);
    if (g_fPistolDelayDualies < 0.0) g_fPistolDelayDualies = 0.0;
    else if (g_fPistolDelayDualies > 5.0) g_fPistolDelayDualies = 5.0;
    
    g_fPistolDelaySingle = GetConVarFloat(g_hPistolDelaySingle);
    if (g_fPistolDelaySingle < 0.0) g_fPistolDelaySingle = 0.0;
    else if (g_fPistolDelaySingle > 5.0) g_fPistolDelaySingle = 5.0;
    
    g_fPistolDelayIncapped = GetConVarFloat(g_hPistolDelayIncapped);
    if (g_fPistolDelayIncapped < 0.0) g_fPistolDelayIncapped = 0.0;
    else if (g_fPistolDelayIncapped > 5.0) g_fPistolDelayIncapped = 5.0;
}

public Action Hook_OnPostThinkPost(int client)
{
    // Human survivors only
    if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
    int activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(activeweapon)) return;
    char weaponname[64];
    GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
    if (strcmp(weaponname, "weapon_pistol") != 0) return;
    
    float old_value = GetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack");
    float new_value = g_fNextAttack[client];
    
    // Never accidentally speed up fire rate
    if (new_value > old_value)
    {
        // PrintToChatAll("Readjusting delay: Old=%f, New=%f", old_value, new_value);
        SetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack", new_value);
    }
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
    int activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(activeweapon)) return;
    char weaponname[64];
    GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
    if (strcmp(weaponname, "weapon_pistol") != 0) return;
    // int dualies = GetEntProp(activeweapon, Prop_Send, "m_hasDualWeapons");
    if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelayIncapped;
    }
    // What is the difference between m_isDualWielding and m_hasDualWeapons ?
    else if (GetEntProp(activeweapon, Prop_Send, "m_isDualWielding"))
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelayDualies;
    }
    else
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelaySingle;
    }
}
