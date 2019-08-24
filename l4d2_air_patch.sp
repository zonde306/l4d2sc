#include <dhooks>

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar cVomit, cZoom, cCharge, cSmoker, cSmokerAbility;

public Plugin myinfo =
{
	name = "Air Ability Patch",
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

public void OnPluginStart()
{
	cVomit 			= CreateConVar("sm_detour_vomit"	, "1", "Enable/Disable use ability vomit in air"	, FCVAR_NONE, true, 0.0, true, 1.0);
	cZoom 			= CreateConVar("sm_detour_zoom"		, "1", "Enable/Disable zoom in air"					, FCVAR_NONE, true, 0.0, true, 1.0);
	cCharge 			= CreateConVar("sm_patch_charger"	, "1", "Enable/Disable use ability charge in air"	, FCVAR_NONE, true, 0.0, true, 1.0);
	cSmoker 			= CreateConVar("sm_patch_smoker"	, "1", "Enable/Disable smoke in air"				, FCVAR_NONE, true, 0.0, true, 1.0);
	cSmokerAbility 	= CreateConVar("sm_detour_smoker"	, "1", "Enable/Disable use ability tongue in air"	, FCVAR_NONE, true, 0.0, true, 1.0);
	
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