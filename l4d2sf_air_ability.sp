#include <dhooks>
#include <l4d2_skill_framework>

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include "modules/l4d2ps.sp"

ConVar cVomit, cZoom, cCharge, cSmoker, cSmokerAbility;

public Plugin myinfo =
{
	name = "特感空中使用能力",
	author = "BHaType",
	description = "Allow to use ability in air.",
	version = "0.0.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

int g_iSlotAbility, g_iOffsetActivation;
int g_iLevelAbility[MAXPLAYERS+1];

public void OnPluginStart()
{
	cVomit 			= CreateConVar("sm_detour_vomit"	, "1", "是否允许空中呕吐"	, FCVAR_NONE, true, 0.0, true, 1.0);
	cZoom 			= CreateConVar("sm_detour_zoom"		, "1", "是否允许空中开镜"					, FCVAR_NONE, true, 0.0, true, 1.0);
	cCharge 			= CreateConVar("sm_patch_charger"	, "1", "是否允许空中冲锋"	, FCVAR_NONE, true, 0.0, true, 1.0);
	cSmoker 			= CreateConVar("sm_patch_smoker"	, "1", "是否允许空中拉人"				, FCVAR_NONE, true, 0.0, true, 1.0);
	cSmokerAbility 	= CreateConVar("sm_detour_smoker"	, "1", "是否允许空中伸舌头"	, FCVAR_NONE, true, 0.0, true, 1.0);
	
	Handle hGamedata = LoadGameConfigFile("l4d2_patch_air");
	if( hGamedata == null ) SetFailState("Failed to load gamedata.");

	Handle hDetour, hDetourVomit, hDetourSmoker;
	
	//if(Enabled[3])
	//{
		/*
		//int iCharge = GameConfGetOffset(hGamedata, "Throw");
		Address patch = GameConfGetAddress(hGamedata, "Throw");

		for(int i = 93; i <= 96; i++)
			StoreToAddress(patch + view_as<Address>(i), 0x00, NumberType_Int8);
		for(int i = 100; i <= 108; i++)
			StoreToAddress(patch + view_as<Address>(i), 0x00, NumberType_Int8);
		for(int i = 109; i <= 117; i++)
			StoreToAddress(patch + view_as<Address>(i), 0x00, NumberType_Int8);
		//for(int i = 122; i <= 125; i++)
		//	StoreToAddress(patch + view_as<Address>(i), 0x90, NumberType_Int8);
			
		StoreToAddress(patch + view_as<Address>(121), 0x00, NumberType_Int8);
		//StoreToAddress(patch + view_as<Address>(129), 0x00, NumberType_Int8);
		//for(int i = 90; i <= 120; i++)
	//	{
		//	StoreToAddress(patch + view_as<Address>(i), 0x90, NumberType_Int8);
		//	PrintToServer("%i", i);
	//	}
		PrintToServer("1");
		*/
	//}
	
	//50, 51, 52, 53, 61, 62, 63, 64, 70, 71, 72, 75, 76, 77, 78, 81, 88, 90, 92, 94, 95, 97
	//59 I didnt test || Maybe will be crash with this
	// 92 no more sounds || 97 ??
	
	if(GetConVarInt(cCharge))
	{
		int iAllow = GameConfGetOffset(hGamedata, "charge_offset");
		Address patch = GameConfGetAddress(hGamedata, "Charge");
		for(int i; i <= 4; i++)
			StoreToAddress(patch + view_as<Address>(iAllow + i), 0x00, NumberType_Int8);
	}
	
	if(GetConVarInt(cSmokerAbility))
	{
		hDetourSmoker = DHookCreateFromConf(hGamedata, "TongueAbillity");
		if( !DHookEnableDetour(hDetourSmoker, true, detour_smoker) ) SetFailState("Failed to detour \"tongue_ability\".");
	}
	
	if(GetConVarInt(cSmoker))
	{
		int iAllow = GameConfGetOffset(hGamedata, "smoker_offset");
		Address patch = GameConfGetAddress(hGamedata, "Tongue");
		StoreToAddress(patch + view_as<Address>(iAllow), 0x00, NumberType_Int8);
	}
	
	if(GetConVarInt(cZoom))
	{
		hDetour = DHookCreateFromConf(hGamedata, "Should");
		if( !DHookEnableDetour(hDetour, true, detour) ) SetFailState("Failed to detour \"zoom\".");
	}
	
	if(GetConVarInt(cVomit))
	{
		hDetourVomit = DHookCreateFromConf(hGamedata, "Vomit");
		if( !DHookEnableDetour(hDetourVomit, true, detour_vomit) ) SetFailState("Failed to detour \"vomit\".");
	}
	
	delete hGamedata;
	
	g_iOffsetActivation = FindSendPropInfo("CBaseAbility","m_nextActivationTimer");
	
	LoadTranslations("l4d2sf_air_ability.phrases.txt");
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "air_ability", 2, 25, 5, 2.0);
}

public MRESReturn detour(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 0); // Welcome to hell
	return MRES_Supercede;
}

public MRESReturn detour_smoker(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 1); // Welcome to stack
	return MRES_Supercede;
}

public MRESReturn detour_vomit(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 1); // Welcome to vomit
	return MRES_Supercede;
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "air_ability"))
		FormatEx(result, maxlen, "%T", "空中能力", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "air_ability"))
		FormatEx(result, maxlen, "%T", tr("空中能力%d", IntBound(level, 1, 2)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "air_ability"))
		g_iLevelAbility[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelAbility[client] = L4D2SF_GetClientPerk(client, "air_ability");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon,
	int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!(buttons & IN_ATTACK) || !IsValidAliveClient(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_isGhost", 1))
		return Plugin_Continue;
	
	// 不在地上
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
		return Plugin_Continue;
	
	// 已经控住人了
	if(GetCurrentVictim(client) > 0)
		return Plugin_Continue;
	
	int level = 1;
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(class == Z_BOOMER || class == Z_SPITTER)
		level = 1;
	else if(class == Z_CHARGER || class == Z_SMOKER)
		level = 2;
	else
		return Plugin_Continue;
	
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(ability < MaxClients || !IsValidEntity(ability))
		return Plugin_Continue;
	
	// m_nextActivationTimer.m_timestamp
	float nextAttackTime = GetEntDataFloat(ability, g_iOffsetActivation + 8);
	
	// 能力还在冷却中
	if(nextAttackTime > GetGameTime())
		return Plugin_Continue;
	
	if(g_iLevelAbility[client] < level)
	{
		buttons &= ~IN_ATTACK;
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

int GetCurrentVictim(int client)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	int victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if(IsValidAliveClient(victim))
		return victim;
	
	return -1;
}
