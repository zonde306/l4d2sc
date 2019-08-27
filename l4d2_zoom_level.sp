#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

static const int g_iLevels[] =
{
	5,
	20,
	35,
	50,
	65
};

Handle hLevelZoom, hGetFov, hGetDefaultFov;

int g_iZoomLevel[2048 + 1] = {20, ...};

public Plugin myinfo =
{
	name = "[L4D2] Zoom Level",
	author = "BHaType",
	description = "Now everyone can change zoom level for snipers.",
	version = "0.0.0",
	url = "N/A"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_zoom", eZoom);
	
	Handle hGameConf = LoadGameConfigFile("l4d2_zoom_hack"); 
	
	int iLevel = GameConfGetOffset(hGameConf, "GetZoomLevel");
	if(!iLevel)
		SetFailState("Where is offset?");
	
	hLevelZoom = DHookCreate(iLevel, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, eZoomLevel);
	
	if(hLevelZoom == null)
		SetFailState("Ehhhhh... Thats so bad");
	
	StartPrepSDKCall(SDKCall_Player);
	if ( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CGetFov") == false )
		SetFailState("Could not load the \"CGetFov\" gamedata signature.");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hGetFov = EndPrepSDKCall();
	if ( hGetFov == null )
		SetFailState("Could not prep the \"CGetFov\" function.");
	
	StartPrepSDKCall(SDKCall_Player);
	if ( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CGetDefaultFov") == false )
		SetFailState("Could not load the \"CGetDefaultFov\" gamedata signature.");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hGetDefaultFov = EndPrepSDKCall();
	if ( hGetDefaultFov == null )
		SetFailState("Could not prep the \"CGetDefaultFov\" function.");
}

public void OnEntityCreated (int entity, const char[] name)
{
	if (IsValidEntity(entity) && strcmp(name, "weapon_hunting_rifle") == 0 || StrContains(name, "sniper") > 0 )
		SDKHook(EntIndexToEntRef(entity), SDKHook_Spawn, eSpawn);
}

public void eSpawn (int entity)
{
	if ((entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
		DHookEntity(hLevelZoom, true, entity);
}

public Action eZoom (int client, int args)
{
	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(iCurrentWeapon))
		return Plugin_Handled;
	
	if(!IsWeaponCanZoom(iCurrentWeapon))
	{
		PrintToChat(client, "\x01\x03You \x04cant change zoom level for this \x05weapon");
		return Plugin_Handled;
	}
	
	if(SDKCall(hGetFov, client) != SDKCall(hGetDefaultFov, client))
	{
		PrintToChat(client, "\x01\x03You \x04cant change zoom level in \x05zoom");
		return Plugin_Handled;
	}
		
	int index;
	for (int i; i < sizeof g_iLevels; i++)
	{
		if(g_iLevels[i] == g_iZoomLevel[iCurrentWeapon])
		{
			index = i;
			break;
		}
	}
	
	if(index == sizeof g_iLevels - 1)
		index = 0;
	else
		index++;
		
	g_iZoomLevel[iCurrentWeapon] = g_iLevels[index];
	PrintToChat(client, "\x01\x03Your \x04zoom level is \x05%i", g_iLevels[index]);
	return Plugin_Handled;
}

public MRESReturn eZoomLevel(int pThis, Handle hReturn, Handle hParams)
{
	if (pThis > MaxClients && pThis <= 2048 && IsValidEntity(pThis))
	{
		DHookSetReturn(hReturn, g_iZoomLevel[pThis]);
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

bool IsWeaponCanZoom(int weapon)
{
	char sWeaponEx[36];
	GetEntityClassname(weapon, sWeaponEx, sizeof sWeaponEx);
	if(strcmp(sWeaponEx, "weapon_hunting_rifle") == 0 || StrContains(sWeaponEx, "sniper") > 0)
		return true;
	return false;
}