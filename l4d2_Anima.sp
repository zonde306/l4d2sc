#pragma semicolon 1
#pragma newdecls required

#define INVALID_REFERENCE 0

#include <sdktools>
#include <sdkhooks>

int iClip[2048+1], iWeaponRef[2048+1];
bool AlreadyInflicted[2048+1];

public Plugin myinfo = 
{
	name        = "[L4D2] Anima unlock",
	author      = "BHaType",
	description = "Put your hands up!",
	version     = "0.0.1",
	url         = "https://www.sourcemod.net/plugins.php?cat=0&mod=6&title=&author=BHaType&description=&search=1"
};
 
public void OnPluginStart()
{
	HookEvent("weapon_reload", eReloadWeapon, EventHookMode_Pre);
	HookEvent("item_pickup", eWeaponPick, EventHookMode_Pre);
}
 
public Action Hook(int weapon)
{
	int intCl = GetEntProp(weapon, Prop_Send, "m_iClip1");
	iClip[weapon] = intCl;
}
 
public void eWeaponPick(Event event, const char[] name, bool dontBroadcast)
{
	int iClient, iCurrentWeapon, iWeaponRefrence;
	char sWeaponName[32];
		
	iClient = GetClientOfUserId(event.GetInt("userid"));
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	
	iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(iCurrentWeapon))
		iWeaponRefrence = EntRefToEntIndex(iWeaponRef[iCurrentWeapon]);
 
	if(iWeaponRefrence == INVALID_REFERENCE && strcmp(sWeaponName, "weapon_hunting_rifle") == 0)
	{
		SDKHook(iCurrentWeapon, SDKHook_Reload, Hook);
		AlreadyInflicted[iCurrentWeapon] = true;
		iWeaponRef[iCurrentWeapon] = EntIndexToEntRef(iCurrentWeapon);
	}
}
 
public Action eReloadWeapon(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if(IsClientInGame(iClient))
	{
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if(!IsValidEntity(iViewModel) || !IsValidEntity(iCurrentWeapon))
			return Plugin_Continue;
	   
		char sWeaponName[32];
		GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	 
		if (strcmp(sWeaponName, "weapon_hunting_rifle", false) == 0 && iClip[iCurrentWeapon] == 0)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", 3);
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapInfo(iViewModel, "m_nLayerSequence"));
			SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", GetGameTime() + 4.5);
			SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 4.5);
		}
	}
	return Plugin_Continue;
}