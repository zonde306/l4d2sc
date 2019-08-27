#pragma semicolon 1
#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>

new String:pClass[64];

#define L4D2_SMGS (StrEqual(pClass, "weapon_smg_silenced", false) || StrEqual(pClass, "weapon_smg_mp5", false))
#define L4D2_PUMPSHOTGUNS StrEqual(pClass, "weapon_shotgun_chrome", false)
#define L4D2_RIFLES (StrEqual(pClass, "weapon_rifle_ak47", false) || StrEqual(pClass, "weapon_rifle_desert", false) || StrEqual(pClass, "weapon_rifle_sg552", false))
#define L4D2_SHOTGUNS StrEqual(pClass, "weapon_shotgun_spas", false)
#define L4D2_SNIPERS (StrEqual(pClass, "weapon_sniper_military", false) || StrEqual(pClass, "weapon_sniper_scout", false) || StrEqual(pClass, "weapon_sniper_awp", false))

new Handle:hECSMGs, Handle:hECPumpShotguns, Handle:hECRifles, Handle:hECShotguns, Handle:hECSnipers,
	iEC1, iEC2; iEC3, iEC4, iEC5;

public Plugin:myinfo =
{
	name = "Extra Clips",
	author = "cravenge",
	description = "Provides Extra Primary Ammos In Weapons.",
	version = "1.2",
	url = ""
};

public OnPluginStart()
{
	decl String:cGame[12];
	GetGameFolderName(cGame, sizeof(cGame));
	if(!StrEqual(cGame, "left4dead2", false))
	{
		SetFailState("[EC] Plugin Supports L4D2 Only!");
	}
	
	CreateConVar("ec_version", "1.2", "Extra Clips Version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	hECSMGs = CreateConVar("ec_smgs", "60", "Extra Primary Ammo In SMGs", FCVAR_NOTIFY);
	hECPumpShotguns = CreateConVar("ec_pumpshotguns", "15", "Extra Primary Ammo In Pump Shotguns", FCVAR_NOTIFY);
	hECRifles = CreateConVar("ec_rifles", "75", "Extra Primary Ammo In Rifles", FCVAR_NOTIFY);
	hECShotguns = CreateConVar("ec_shotguns", "25", "Extra Primary Ammo In Shotguns", FCVAR_NOTIFY);
	hECSnipers = CreateConVar("ec_snipers", "40", "Extra Primary Ammo In Snipers", FCVAR_NOTIFY);
	
	iEC1 = GetConVarInt(hECSMGs);
	iEC2 = GetConVarInt(hECPumpShotguns);
	iEC3 = GetConVarInt(hECRifles);
	iEC4 = GetConVarInt(hECShotguns);
	iEC5 = GetConVarInt(hECSnipers);
	
	HookEvent("player_use", OnPlayerUse);
	
	HookConVarChange(hECSMGs, OnIntsChanged);
	HookConVarChange(hECPumpShotguns, OnIntsChanged);
	HookConVarChange(hECRifles, OnIntsChanged);
	HookConVarChange(hECShotguns, OnIntsChanged);
	HookConVarChange(hECSnipers, OnIntsChanged);
	
	AutoExecConfig(true, "extra_clips");
}

public OnIntsChanged(Handle:cCVar, const String:oV[], const String:nV[])
{
	iEC1 = GetConVarInt(hECSMGs);
	iEC2 = GetConVarInt(hECPumpShotguns);
	iEC3 = GetConVarInt(hECRifles);
	iEC4 = GetConVarInt(hECShotguns);
	iEC5 = GetConVarInt(hECSnipers);
}

public Action:OnPlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new picker = GetClientOfUserId(GetEventInt(event, "userid"));
	if(picker <= 0 || picker > MaxClients || !IsClientInGame(picker) || GetClientTeam(picker) != 2 || !IsPlayerAlive(picker))
	{
		return Plugin_Continue;
	}
	
	new picked = GetEventInt(event, "targetid");
	if (picked <= 0 || !IsValidEntity(picked) || !IsValidEdict(picked))
	{
		return Plugin_Continue;
	}
	
	GetEdictClassname(picked, pClass, sizeof(pClass));
	if (strncmp(pClass, "weapon", 6) == 0)
	{
		new clipinfo = 0;
		if (StrEqual(pClass, "weapon_rifle", false) || L4D2_RIFLES)
		{
			clipinfo = iEC3;
		}
		else if (StrEqual(pClass, "weapon_smg", false) || L4D2_SMGS)
		{
			clipinfo = iEC1;
		}
		else if (StrEqual(pClass, "weapon_pumpshotgun", false) || L4D2_PUMPSHOTGUNS)
		{
			clipinfo = iEC2;
		}
		else if (StrEqual(pClass, "weapon_autoshotgun", false) || L4D2_SHOTGUNS)
		{
			clipinfo = iEC4;
		}
		else if (StrEqual(pClass, "weapon_hunting_rifle", false) || L4D2_SNIPERS)
		{
			clipinfo = iEC5;
		}
		else
		{
			return Plugin_Continue;
		}
		
		SetEntProp(picked, Prop_Send, "m_iClip1", clipinfo, 1);
		SetEntProp(picked, Prop_Data, "m_iClip1", clipinfo, 1);
	}
	
	return Plugin_Continue;
}

