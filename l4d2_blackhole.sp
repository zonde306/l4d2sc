/*  TF2 Black Hole Rockets
 *
 *  Copyright (C) 2017 Calvin Lee (Chaosxk)
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
 
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <l4d_stocks>

#define PLUGIN_VERSION "1.2"
#define SPRITE_GLOW        "materials/sprites/glow01.vmt"

ConVar g_cEnabled, g_cRadius, g_cIRadius, g_cForce, g_cDamage, g_cDuration, g_cShake, g_cFriendly;

int g_iBlackhole[MAXPLAYERS+1];
int g_iTeleport[MAXPLAYERS+1];
float g_fPos[MAXPLAYERS+1][3];

int g_GlowSprite;

public Plugin myinfo = 
{
	name = "[L4d2]Black hole grenade launcher",
	author = "Tak (Chaosxk),AK978",
	version = PLUGIN_VERSION,
}

public void OnPluginStart()
{
	CreateConVar("sm_blackhole_version", "1.0", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cEnabled = CreateConVar("sm_blackhole_enabled", "1", "Enables/Disables Black hole rockets.");
	g_cRadius = CreateConVar("sm_blackhole_radius", "200.0", "Radius of pull.");
	g_cIRadius = CreateConVar("sm_blackhole_inner_radius", "100.0", "How close player is before doing damage/teleported them?");
	g_cForce = CreateConVar("sm_blackhole_pullforce", "1000.0", "What should the pull force be?");
	g_cDamage = CreateConVar("sm_blackhole_damage", "100.0", "How much damage should the blackholes do per second?");
	g_cDuration = CreateConVar("sm_blackhole_duration", "10.0", "How long does the black hole last?");
	g_cShake = CreateConVar("sm_blackhole_shake", "1", "When players are in radius of the black hole, their screens will shake.");
	g_cFriendly = CreateConVar("sm_blackhole_ff", "0", "If set to 1, black hole rockets will effect teammates.");

	RegConsoleCmd("sm_bh", Command_BlackHole, "Turn on Black Hole rockets for anyone.");	
	RegConsoleCmd("sm_setbh", Command_SetBlackHole, "Set the end point location for blackhole, blackhole will teleport instead of doing damage.");
	RegConsoleCmd("sm_resetbh", Command_ResetBlackHole, "Reset the end point location for blackhole, blackhole will start doing damage.");
	
	AutoExecConfig(true, "blackhole");	
}

public OnMapStart()
{
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);
}

public Action Command_BlackHole(int client, int args)
{
	g_iBlackhole[client] = 1;
	PrintToChat(client, "開啟榴彈黑洞功能,Open grenade black hole function");
}

public Action Command_SetBlackHole(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	GetClientAbsOrigin(client, g_fPos[client]);
	g_iTeleport[client] = 1;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes no longer do damage and will teleport to this location. \nType !resetbh to undo.");
	return Plugin_Handled;
}

public Action Command_ResetBlackHole(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	g_iTeleport[client] = 0;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes will no longer teleport and will do damage. \nType !setbh to undo.");
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_cEnabled.BoolValue)
		return;
		
	for(new i=1; i<=MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			SDKHook(entity, SDKHook_StartTouchPost, OnEntityTouch);
		}
	}
}

public Action OnEntityTouch(int entity, int other)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || g_iBlackhole[client] == 0 || !CheckWeapon(client))
		return Plugin_Continue;
		
	float pos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	
	DataPack pPack;
	CreateDataTimer(0.1, Timer_Pull, pPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			
	pPack.WriteFloat(GetEngineTime() + g_cDuration.FloatValue);
	pPack.WriteFloat(pos[0]);
	pPack.WriteFloat(pos[1]);
	pPack.WriteFloat(pos[2]);
	pPack.WriteCell(GetClientUserId(client));

	return Plugin_Handled;
}

public Action Timer_Pull(Handle timer, DataPack pack)
{
	pack.Reset();	
	
	if (GetEngineTime() >= pack.ReadFloat())
	{
		return Plugin_Stop;
	}
	
	float pos[3];
	pos[0] = pack.ReadFloat();
	pos[1] = pack.ReadFloat();
	pos[2] = pack.ReadFloat();

	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 1.5, 250);
	TE_SendToAll();
	
	int attacker = GetClientOfUserId(pack.ReadCell());
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i)) 
			continue;
			
		float cpos[3];
		GetClientAbsOrigin(i, cpos);
		
		float Distance = GetVectorDistance(pos, cpos);
		
		if (attacker == i)
			continue;
			
		if (!g_cFriendly.BoolValue && GetClientTeam(i) == GetClientTeam(attacker) && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
			continue;
			
		if (Distance <= g_cRadius.FloatValue)
		{
			float velocity[3];
			MakeVectorFromPoints(pos, cpos, velocity);
			NormalizeVector(velocity, velocity);
			ScaleVector(velocity, -g_cForce.FloatValue);
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
			
			if(g_cShake.BoolValue) 
				ShakeScreen(i, 20.0, 0.1, 0.7);
		}
		
		if (Distance <= g_cIRadius.FloatValue)
		{
			if (g_iTeleport[attacker])
			{
				TeleportEntity(i, g_fPos[attacker], NULL_VECTOR, NULL_VECTOR);
				return Plugin_Continue;
			}
			SDKHooks_TakeDamage(i, attacker, attacker, g_cDamage.FloatValue, DMG_REMOVENORAGDOLL); //dmg_removenoragdoll dont work?
		
			if (!IsPlayerAlive(i))
			{
				int ragdoll = GetEntPropEnt(i, Prop_Send, "m_hRagdoll");
				
				if (!IsValidEntity(ragdoll))
					continue;
					
				AcceptEntityInput(ragdoll, "kill");
			}
		}
	}
	return Plugin_Continue;
}

stock int CreateEntityParticle(const char[] sParticle, const float[3] pos)
{
	int entity = CreateEntityByName("info_particle_system");
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	return entity;
}

stock void SetEntitySelfDestruct(int entity, float duration)
{
	char output[64]; 
	Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", duration);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
}

stock void ShakeScreen(int client, float intensity, float duration, float frequency)
{
	Handle bf; 
	if ((bf = StartMessageOne("Shake", client)) != null)
	{
		BfWriteByte(bf, 0);
		BfWriteFloat(bf, intensity);
		BfWriteFloat(bf, duration);
		BfWriteFloat(bf, frequency);
		EndMessage();
	}
}

stock bool:CheckWeapon(int client)
{
	decl String:weapon[64];

	GetClientWeapon(client, weapon, sizeof(weapon));	
		
	if(StrEqual(weapon, "weapon_grenade_launcher"))
	{
		return true;
	}
	return false;
}

stock bool:IsValidClient(int client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}