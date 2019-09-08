#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"0.1"
#include "modules/l4d2ps.sp"

const int g_iMaxClip = 254;		// 游戏所允许的最大弹夹数量 8bit，但是 255 会被显示为 0，超过会溢出
const int g_iMaxAmmo = 1023;	// 游戏所允许的最大子弹数量 10bit，超过会溢出

#define SKILLCLIP_SIZE			(1.0 + ((SC_GetClientLevel(client) / 10) * 0.25))
#define SKILLAMMO_SIZE			(1.0 + ((SC_GetClientLevel(client) / 10) * 0.5))
#define SKILLUPGRADE_SIZE		(1.0 + ((SC_GetClientLevel(client) / 10) * 0.25))

public Plugin:myinfo = 
{
	name = "武器弹药控制",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

Handle g_hFindUseEntity = null;

bool g_bHasShotGunChanged[MAXPLAYERS+1] = {false, ...};
int g_iLastShotGunClip[MAXPLAYERS+1] = {0, ...}, g_iLastUpgradeClip[MAXPLAYERS+1] = {0, ...},
	g_iLastUpgradeAmmo[MAXPLAYERS+1] = {0, ...};

int g_iAmmoSmg, g_iAmmoSilenced, g_iAmmoMP5, g_iAmmoPump, g_iAmmoChrome, g_iAmmoSG552, g_iAmmoRifle, g_iAmmoAk47,
	g_iAmmoDesert, g_iAmmoAuto, g_iAmmoSpas, g_iAmmoHunting, g_iAmmoMilitary, g_iAmmoScout, g_iAmmoAwp;

int g_iClipSmg, g_iClipSilenced, g_iClipMP5, g_iClipPump, g_iClipChrome, g_iClipSG552, g_iClipRifle, g_iClipAk47,
	g_iClipDesert, g_iClipAuto, g_iClipSpas, g_iClipHunting, g_iClipMilitary, g_iClipScout, g_iClipAwp;

ConVar g_pCvarPatchReloadShot;
ConVar g_pCvarSmgClip, g_pCvarSmgAmmo, g_pCvarSilencedClip, g_pCvarSilencedAmmo, g_pCvarMP5Clip, g_pCvarMP5Ammo,
	g_pCvarPumpClip, g_pCvarPumpAmmo, g_pCvarChromeClip, g_pCvarChromeAmmo, g_pCvarSG552Clip, g_pCvarSG552Ammo,
	g_pCvarRifleClip, g_pCvarRifleAmmo, g_pCvarAk47Clip, g_pCvarAk47Ammo, g_pCvarDesertClip, g_pCvarDesertAmmo,
	g_pCvarAutoClip, g_pCvarAutoAmmo, g_pCvarSpasClip, g_pCvarSpasAmmo, g_pCvarHuntingClip, g_pCvarHuntingAmmo,
	g_pCvarMilitaryClip, g_pCvarMilitaryAmmo, g_pCvarScoutClip, g_pCvarScoutAmmo, g_pCvarAwpClip, g_pCvarAwpAmmo;

public OnPluginStart()
{
	InitPlugin("wa");
	g_pCvarPatchReloadShot = CreateConVar("l4d2_wa_reload_shot_fix", "1", "修复霰弹枪无法开枪", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarSmgClip = CreateConVar("l4d2_wa_smg_clip", "50", "普通冲锋枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarSmgAmmo = CreateConVar("l4d2_wa_smg_ammo", "650", "普通冲锋枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarSilencedClip = CreateConVar("l4d2_wa_smg_silenced_clip", "50", "消音冲锋枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarSilencedAmmo = CreateConVar("l4d2_wa_smg_silenced_ammo", "650", "消音冲锋枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarMP5Clip = CreateConVar("l4d2_wa_smg_mp5_clip", "50", "MP5 冲锋枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarMP5Ammo = CreateConVar("l4d2_wa_smg_mp5_ammo", "650", "MP5 冲锋枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarPumpClip = CreateConVar("l4d2_wa_pumpshotgun_clip", "8", "木单喷弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarPumpAmmo = CreateConVar("l4d2_wa_pumpshotgun_ammo", "56", "木单喷弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarChromeClip = CreateConVar("l4d2_wa_shotgun_chrome_clip", "8", "铁单喷弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarChromeAmmo = CreateConVar("l4d2_wa_shotgun_chrome_ammo", "56", "铁单喷弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarRifleClip = CreateConVar("l4d2_wa_rifle_clip", "50", "M16 步枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarRifleAmmo = CreateConVar("l4d2_wa_rifle_ammo", "360", "M16 步枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarAk47Clip = CreateConVar("l4d2_wa_rifle_ak47_clip", "40", "AK47 步枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarAk47Ammo = CreateConVar("l4d2_wa_rifle_ak47_ammo", "360", "AK47 步枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarDesertClip = CreateConVar("l4d2_wa_rifle_desert_clip", "60", "三连发步枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarDesertAmmo = CreateConVar("l4d2_wa_rifle_desert_ammo", "360", "三连发步枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarSG552Clip = CreateConVar("l4d2_wa_rifle_sg552_clip", "50", "SG552 发步枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarSG552Ammo = CreateConVar("l4d2_wa_rifle_sg552_ammo", "360", "SG552 步枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarAutoClip = CreateConVar("l4d2_wa_autoshotgun_clip", "10", "一代连喷弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarAutoAmmo = CreateConVar("l4d2_wa_autoshotugn_ammo", "90", "一代连喷弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarSpasClip = CreateConVar("l4d2_wa_shotgun_spas_clip", "10", "二代连喷弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarSpasAmmo = CreateConVar("l4d2_wa_shotgun_spas_ammo", "90", "二代连喷弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarHuntingClip = CreateConVar("l4d2_wa_hunging_rifle_clip", "15", "猎枪弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarHuntingAmmo = CreateConVar("l4d2_wa_hunting_rifle_ammo", "150", "猎枪弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarMilitaryClip = CreateConVar("l4d2_wa_sniper_military_clip", "30", "连狙弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarMilitaryAmmo = CreateConVar("l4d2_wa_sniper_military_ammo", "180", "连狙弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarScoutClip = CreateConVar("l4d2_wa_sniper_scout_clip", "15", "鸟狙弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarScoutAmmo = CreateConVar("l4d2_wa_sniper_scout_ammo", "180", "鸟狙弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	g_pCvarAwpClip = CreateConVar("l4d2_wa_sniper_awp_clip", "20", "大鸟弹夹", FCVAR_NONE, true, 0.0, true, float(g_iMaxClip));
	g_pCvarAwpAmmo = CreateConVar("l4d2_wa_sniper_awp_ammo", "180", "大鸟弹药", FCVAR_NONE, true, 0.0, true, float(g_iMaxAmmo));
	AutoExecConfig(true, "l4d2_weapon_ammo");
	
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("ammo_pickup", Event_AmmoPickup);
	HookEvent("upgrade_pack_added", Event_UpgradePickup);
	HookEvent("weapon_reload", Event_WeaponReload);
	
	OnCvarUpdate_UpdateAmmo(null, "", "");
	g_pCvarSmgClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSmgAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSilencedClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSilencedAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarMP5Clip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarMP5Ammo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarPumpClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarPumpAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarChromeClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarChromeAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarRifleClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarRifleAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAk47Clip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAk47Ammo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarDesertClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarDesertAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSG552Clip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSG552Ammo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAutoClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAutoAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSpasClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarSpasAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarHuntingClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarHuntingAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarMilitaryClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarMilitaryAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarScoutClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarScoutAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAwpClip.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	g_pCvarAwpAmmo.AddChangeHook(OnCvarUpdate_UpdateAmmo);
	
	InitFindEntity();
	CreateTimer(1.0, Timer_SkillRegister);
}

public Action Timer_SkillRegister(Handle timer, any unused)
{
	SC_CreateSkill("ca_maxammo", "更多弹药", 0, "备用弹药更多");
	SC_CreateSkill("ca_maxclip", "更大弹夹", 0, "弹夹大小更大");
	SC_CreateSkill("upf_moreupgrade", "更多升级弹药", 0, "弹药升级包加量");
	return Plugin_Continue;
}

public void OnCvarUpdate_UpdateAmmo(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iClipSmg = g_pCvarSmgClip.IntValue;
	g_iAmmoSmg = g_pCvarSmgAmmo.IntValue;
	g_iClipSilenced = g_pCvarSilencedClip.IntValue;
	g_iAmmoSilenced = g_pCvarSilencedAmmo.IntValue;
	g_iClipMP5 = g_pCvarMP5Clip.IntValue;
	g_iAmmoMP5 = g_pCvarMP5Ammo.IntValue;
	g_iClipPump = g_pCvarPumpClip.IntValue;
	g_iAmmoPump = g_pCvarPumpAmmo.IntValue;
	g_iClipChrome = g_pCvarChromeClip.IntValue;
	g_iAmmoChrome = g_pCvarChromeAmmo.IntValue;
	g_iClipRifle = g_pCvarRifleClip.IntValue;
	g_iAmmoRifle = g_pCvarRifleAmmo.IntValue;
	g_iClipAk47 = g_pCvarAk47Clip.IntValue;
	g_iAmmoAk47 = g_pCvarAk47Ammo.IntValue;
	g_iClipDesert = g_pCvarDesertClip.IntValue;
	g_iAmmoDesert = g_pCvarDesertAmmo.IntValue;
	g_iClipSG552 = g_pCvarSG552Clip.IntValue;
	g_iAmmoSG552 = g_pCvarSG552Ammo.IntValue;
	g_iClipAuto = g_pCvarAutoClip.IntValue;
	g_iAmmoAuto = g_pCvarAutoAmmo.IntValue;
	g_iClipSpas = g_pCvarSpasClip.IntValue;
	g_iAmmoSpas = g_pCvarSpasAmmo.IntValue;
	g_iClipHunting = g_pCvarHuntingClip.IntValue;
	g_iAmmoHunting = g_pCvarHuntingAmmo.IntValue;
	g_iClipMilitary = g_pCvarMilitaryClip.IntValue;
	g_iAmmoMilitary = g_pCvarMilitaryAmmo.IntValue;
	g_iClipScout = g_pCvarScoutClip.IntValue;
	g_iAmmoScout = g_pCvarScoutAmmo.IntValue;
	g_iClipAwp = g_pCvarAwpClip.IntValue;
	g_iAmmoAwp = g_pCvarAwpAmmo.IntValue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!(buttons & IN_USE) && !(buttons & IN_RELOAD))
		return Plugin_Continue;
	
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;
	
	int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(currentWeapon < MaxClients)
		return Plugin_Continue;
	
	char classname[64];
	GetEntityClassname(currentWeapon, classname, 64);
	int maxClip = GetClientWeaponClip(client, classname);
	if(maxClip <= 0)
		return Plugin_Continue;
	
	if(buttons & IN_USE)
	{
		int entity = FindUseEntity(client);
		
		char primaryWeaponName[64];
		int primaryWeapon = GetPlayerWeaponSlot(client, 0);
		if(primaryWeapon > MaxClients)
			GetEntityClassname(primaryWeapon, primaryWeaponName, 64);
		
		if(entity > MaxClients && primaryWeapon > MaxClients && IsValidEntity(entity))
		{
			char useEntityName[64];
			GetEntityClassname(entity, useEntityName, 64);
			// PrintToChat(client, "pickup");
			
			if(StrEqual(useEntityName, "weapon_ammo_spawn", false))
			{
				Event event = CreateEvent("ammo_pickup");
				event.SetInt("userid", GetClientUserId(client));
				// event.Fire();
				Event_AmmoPickup(event, "ammo_pickup", true);
			}
			else if(StrContains(useEntityName, "_spawn", false) > -1 &&
				StrContains(useEntityName, primaryWeaponName, false) == 0)
			{
				DataPack data = CreateDataPack();
				data.WriteCell(client);
				data.WriteString(primaryWeaponName);
				OnPickupWeapon(data);
			}
			else if(StrContains(useEntityName, "upgrade_ammo_", false) == 0)
			{
				// 修复捡起弹药升级导致子弹溢出
				g_iLastUpgradeClip[client] = GetEntProp(primaryWeapon, Prop_Send, "m_iClip1");
				g_iLastUpgradeAmmo[client] = GetEntProp(client, Prop_Send, "m_iAmmo", _, GetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryAmmoType"));
			}
		}
	}
	
	if(buttons & IN_RELOAD)
	{
		int currentClip = GetEntProp(currentWeapon, Prop_Send, "m_iClip1");
		if(currentClip >= maxClip)
		{
			buttons &= ~IN_RELOAD;
			return Plugin_Changed;
		}
		
		int ammoType = GetEntProp(currentWeapon, Prop_Send, "m_iPrimaryAmmoType");
		int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
		// PrintToChat(client, "ammoType %d, ammo %d, clip %d", ammoType, ammo, currentClip);
		
		if(currentClip > 0 && ammo > 0 && (GetEntProp(currentWeapon, Prop_Send, "m_bInReload", 1) == 0))
		{
			// PrintToChat(client, "reload");
			if(HasEntProp(currentWeapon, Prop_Send, "m_reloadNumShells"))
			{
				g_iLastShotGunClip[client] = currentClip;
				SetEntProp(currentWeapon, Prop_Send, "m_iClip1", 0);
			}
			else
			{
				ammo += currentClip;
				if(ammo > g_iMaxAmmo)
					ammo = g_iMaxAmmo;
				
				SetEntProp(currentWeapon, Prop_Send, "m_iClip1", 0);
				SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammoType);
				// PrintToChat(client, "ammo to %d", ammo);
			}
		}
		
		// Event event = CreateEvent("weapon_reload");
		// event.SetInt("userid", GetClientUserId(client));
		// event.SetBool("manual", false);
		// event.Fire();
		// Event_WeaponReload(event, "weapon_reload", true);
	}
	
	return Plugin_Continue;
}

public void Event_ItemPickup(Event event, const char[] eventName, bool unknown)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	char classname[64];
	event.GetString("item", classname, 64);
	Format(classname, 64, "weapon_%s", classname);
	
	DataPack data = CreateDataPack();
	RequestFrame(OnPickupWeapon, data);
	data.WriteCell(client);
	data.WriteString(classname);
	
	// PrintToChat(client, "item_pickup");
}

public void Event_AmmoPickup(Event event, const char[] eventName, bool unknown)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients)
		return;
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	
	/*
	DataPack data = CreateDataPack();
	RequestFrame(OnPickupWeapon, data);
	data.WriteCell(client);
	data.WriteString(classname);
	*/
	
	int maxClip = GetClientWeaponClip(client, classname);
	int maxAmmo = GetClientWeaponAmmo(client, classname);
	if(maxClip <= 0 || maxAmmo <= 0)
		return;
	
	int ammo = maxAmmo + maxClip - GetEntProp(weapon, Prop_Send, "m_iClip1");
	if(ammo > g_iMaxAmmo)
		ammo = g_iMaxAmmo;
	
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	// PrintToChat(client, "ammo_pickup");
}

public void Event_UpgradePickup(Event event, const char[] eventName, bool unknown)
{
	int upgradePack = event.GetInt("upgradeid");
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || upgradePack < MaxClients || !IsValidEntity(upgradePack) || GetClientTeam(client) != 2)
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients)
		return;
	
	// 修复捡起弹药升级导致子弹溢出
	if(g_iLastUpgradeClip[client] > 0)
		SetEntProp(weapon, Prop_Send, "m_iClip1", g_iLastUpgradeClip[client]);
	if(g_iLastUpgradeAmmo[client] > 0)
		SetEntProp(client, Prop_Send, "m_iAmmo", g_iLastUpgradeAmmo[client], _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	g_iLastUpgradeClip[client] = 0;
	g_iLastUpgradeAmmo[client] = 0;
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	int clip = GetClientWeaponClip(client, classname);
	if(clip < 0)
		return;
	
	char upgradeName[64];
	GetEntityClassname(upgradePack, upgradeName, 64);
	if(!StrEqual(upgradeName, "upgrade_ammo_incendiary", false) &&
		!StrEqual(upgradeName, "upgrade_ammo_explosive", false))
		return;
	
	if(SC_IsClientHaveSkill(client, "upf_moreupgrade"))
		clip = RoundToZero(clip * SKILLUPGRADE_SIZE);
	if(clip > g_iMaxClip)
		clip = g_iMaxClip;
	
	SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clip);
	// PrintToChat(client, "upgrade_pack_added");
}

public void Event_WeaponReload(Event event, const char[] eventName, bool unknown)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients)
		return;
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	int clip = GetClientWeaponClip(client, classname);
	if(clip <= 0)
		return;
	
	SDKUnhook(client, SDKHook_PreThink, OnThink_UpdateWeapon);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnSwitch_ChangeWeapon);
	g_bHasShotGunChanged[client] = false;
	
	SDKHook(client, SDKHook_PreThink, OnThink_UpdateWeapon);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnSwitch_ChangeWeapon);
	
	// PrintToChat(client, "weapon_reload");
}

public void OnSwitch_ChangeWeapon(int client, int weapon)
{
	if(IsValidClient(client) && g_iLastShotGunClip[client] > 0)
	{
		int primaryWeapon = GetPlayerWeaponSlot(client, 0);
		if(primaryWeapon > MaxClients && IsValidEntity(primaryWeapon) &&
			HasEntProp(primaryWeapon, Prop_Send, "m_reloadNumShells") &&
			GetEntProp(primaryWeapon, Prop_Send, "m_iClip1") == 0)
		{
			SetEntProp(primaryWeapon, Prop_Send, "m_iClip1", g_iLastShotGunClip[client]);
			g_iLastShotGunClip[client] = 0;
		}
	}
	
	g_iLastShotGunClip[client] = 0;
	SDKUnhook(client, SDKHook_PreThink, OnThink_UpdateWeapon);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnSwitch_ChangeWeapon);
	// PrintToChat(client, "weapon_switch");
}

public void OnThink_UpdateWeapon(int client)
{
	if(!IsValidClient(client))
	{
		OnSwitch_ChangeWeapon(client, -1);
		return;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients)
	{
		OnSwitch_ChangeWeapon(client, weapon);
		return;
	}
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	int maxClip = GetClientWeaponClip(client, classname);
	
	int currentClip = GetEntProp(weapon, Prop_Send, "m_iClip1");
	bool finished = (GetEntProp(weapon, Prop_Send, "m_bInReload", 1) == 0);
	if(!finished)
	{
		if(!g_bHasShotGunChanged[client] && HasEntProp(weapon, Prop_Send, "m_reloadNumShells"))
		{
			if(g_iLastShotGunClip[client] > 0 && currentClip == 0)
			{
				currentClip = g_iLastShotGunClip[client];
				SetEntProp(weapon, Prop_Send, "m_iClip1", currentClip);
				g_iLastShotGunClip[client] = 0;
			}
			
			int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
			int shell = maxClip - currentClip;
			if(shell > ammo)
				shell = ammo;
			
			SetEntProp(weapon, Prop_Send, "m_reloadNumShells", shell);
			g_bHasShotGunChanged[client] = true;
			
			/*
			PrintToChat(client, "m_reloadState = %d", GetEntProp(weapon, Prop_Send, "m_reloadState"));
			PrintToChat(client, "m_reloadAnimState = %d", GetEntProp(weapon, Prop_Send, "m_reloadAnimState"));
			PrintToChat(client, "m_reloadNumShells = %d", GetEntProp(weapon, Prop_Send, "m_reloadNumShells"));
			PrintToChat(client, "m_reloadStartTime = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadStartTime"));
			PrintToChat(client, "m_reloadInsertDuration = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration"));
			PrintToChat(client, "m_reloadEndDuration = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration"));
			PrintToChat(client, "m_shellsInserted = %d", GetEntProp(weapon, Prop_Send, "m_shellsInserted"));
			*/
		}
		
		return;
	}
	
	/*
	if(HasEntProp(weapon, Prop_Send, "m_reloadNumShells"))
	{
		// PrintToChat(client, "m_reloadState = %d", GetEntProp(weapon, Prop_Send, "m_reloadState"));
		// PrintToChat(client, "m_reloadAnimState = %d", GetEntProp(weapon, Prop_Send, "m_reloadAnimState"));
		// PrintToChat(client, "m_reloadNumShells = %d", GetEntProp(weapon, Prop_Send, "m_reloadNumShells"));
		// PrintToChat(client, "m_reloadStartTime = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadStartTime"));
		// PrintToChat(client, "m_reloadInsertDuration = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration"));
		// PrintToChat(client, "m_reloadEndDuration = %f", GetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration"));
		// PrintToChat(client, "m_shellsInserted = %d", GetEntProp(weapon, Prop_Send, "m_shellsInserted"));
		
		if(StrEqual(classname, "weapon_autoshotgun", false))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_reloadStartTime", 0.666666);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.4);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.675);
		}
		else if(StrEqual(classname, "weapon_shotgun_spas", false))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_reloadStartDuration", 0.5);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.375);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.699999);
		}
		else
		{
			SetEntPropFloat(weapon, Prop_Send, "m_reloadStartDuration", 0.5);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.5);
			SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.6);
		}
	}
	*/
	
	// 取消换弹夹，但是没有换武器（爬梯/开机关/按按钮/挂边）
	if(currentClip == 0 || HasEntProp(weapon, Prop_Send, "m_reloadNumShells"))
	{
		OnSwitch_ChangeWeapon(client, weapon);
		
		if(g_pCvarPatchReloadShot.BoolValue)
		{
			float time = GetGameTime() + 0.3;
			if(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") > time)
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time);
			if(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") > time)
				SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time);
			SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", time - 0.3);
		}
		
		return;
	}
	
	if(maxClip > 0)
	{
		// 如果设置的子弹多则减备用自动，少则增加
		int change = maxClip - currentClip;
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		SetEntProp(weapon, Prop_Send, "m_iClip1", maxClip);
		SetEntProp(client, Prop_Send, "m_iAmmo", GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType) - change, _, ammoType);
	}
	
	OnSwitch_ChangeWeapon(client, weapon);
	// PrintToChat(client, "weapon_reload_post");
}

public void SetWeaponClip(any dataPack)
{
	DataPack data = view_as<DataPack>(dataPack);
	data.Reset();
	
	int client = data.ReadCell();
	int weapon = data.ReadCell();
	int clip = data.ReadCell();
	int shell = data.ReadCell();
	
	if(!IsValidClient(client) || GetClientTeam(client) != 2 || weapon < MaxClients)
		return;
	
	if(clip > 0)
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	if(shell > 0)
		SetEntProp(weapon, Prop_Send, "m_reloadNumShells", shell);
}

public void OnPickupWeapon(any dataPack)
{
	DataPack data = view_as<DataPack>(dataPack);
	data.Reset();
	
	char classname[64];
	int client = data.ReadCell();
	data.ReadString(classname, 64);
	
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients)
		return;
	
	int clip = GetClientWeaponClip(client, classname);
	int ammo = GetClientWeaponAmmo(client, classname);
	if(clip > 0)
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	if(ammo > 0)
		SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	
	// PrintToChat(client, "weapon_pickup");
}

int GetWeaponClip(const char[] classname)
{
	if(StrContains(classname, "weapon_") != 0)
		return -1;
	
	if(StrEqual(classname, "weapon_rifle", false))
		return g_iClipRifle;
	if(StrEqual(classname, "weapon_rifle_ak47", false))
		return g_iClipAk47;
	if(StrEqual(classname, "weapon_rifle_desert", false))
		return g_iClipDesert;
	if(StrEqual(classname, "weapon_rifle_sg552", false))
		return g_iClipSG552;
	if(StrEqual(classname, "weapon_smg", false))
		return g_iClipSmg;
	if(StrEqual(classname, "weapon_smg_silenced", false))
		return g_iClipSilenced;
	if(StrEqual(classname, "weapon_smg_mp5", false))
		return g_iClipMP5;
	if(StrEqual(classname, "weapon_sniper_military", false))
		return g_iClipMilitary;
	if(StrEqual(classname, "weapon_sniper_scout", false))
		return g_iClipScout;
	if(StrEqual(classname, "weapon_sniper_awp", false))
		return g_iClipAwp;
	if(StrEqual(classname, "weapon_hunting_rifle", false))
		return g_iClipHunting;
	if(StrEqual(classname, "weapon_pumpshotgun", false))
		return g_iClipPump;
	if(StrEqual(classname, "weapon_shotgun_spas", false))
		return g_iClipSpas;
	if(StrEqual(classname, "weapon_shotgun_chrome", false))
		return g_iClipChrome;
	if(StrEqual(classname, "weapon_autoshotgun", false))
		return g_iClipAuto;
	
	return -1;
}

int GetWeaponAmmo(const char[] classname)
{
	if(StrContains(classname, "weapon_") != 0)
		return -1;
	
	if(StrEqual(classname, "weapon_rifle", false))
		return g_iAmmoRifle;
	if(StrEqual(classname, "weapon_rifle_ak47", false))
		return g_iAmmoAk47;
	if(StrEqual(classname, "weapon_rifle_desert", false))
		return g_iAmmoDesert;
	if(StrEqual(classname, "weapon_rifle_sg552", false))
		return g_iAmmoSG552;
	if(StrEqual(classname, "weapon_smg", false))
		return g_iAmmoSmg;
	if(StrEqual(classname, "weapon_smg_silenced", false))
		return g_iAmmoSilenced;
	if(StrEqual(classname, "weapon_smg_mp5", false))
		return g_iAmmoMP5;
	if(StrEqual(classname, "weapon_sniper_military", false))
		return g_iAmmoMilitary;
	if(StrEqual(classname, "weapon_sniper_scout", false))
		return g_iAmmoScout;
	if(StrEqual(classname, "weapon_sniper_awp", false))
		return g_iAmmoAwp;
	if(StrEqual(classname, "weapon_hunting_rifle", false))
		return g_iAmmoHunting;
	if(StrEqual(classname, "weapon_pumpshotgun", false))
		return g_iAmmoPump;
	if(StrEqual(classname, "weapon_shotgun_spas", false))
		return g_iAmmoSpas;
	if(StrEqual(classname, "weapon_shotgun_chrome", false))
		return g_iAmmoChrome;
	if(StrEqual(classname, "weapon_autoshotgun", false))
		return g_iAmmoAuto;
	
	return -1;
}

int GetClientWeaponClip(int client, const char[] classname)
{
	int clip = GetWeaponClip(classname);
	if(clip < 0)
	{
		// PrintToChat(client, "no match %s clip", classname);
		return -1;
	}
	
	if(!SC_IsClientHaveSkill(client, "ca_maxclip"))
		return clip;
	
	clip = RoundToZero(clip * SKILLCLIP_SIZE);
	if(clip > g_iMaxClip)
		clip = g_iMaxClip;
	
	return clip;
}

int GetClientWeaponAmmo(int client, const char[] classname)
{
	int ammo = GetWeaponAmmo(classname);
	if(ammo < 0)
	{
		// PrintToChat(client, "no match %s ammo", classname);
		return -1;
	}
	
	if(IsFakeClient(client))
	{
		int defaults = GetDefaultWeaponAmmo(classname);
		if(defaults > ammo)
			ammo = defaults;
	}
	
	if(!SC_IsClientHaveSkill(client, "ca_maxammo"))
		return ammo;
	
	ammo = RoundToZero(ammo * SKILLAMMO_SIZE);
	if(ammo > g_iMaxAmmo)
		ammo = g_iMaxAmmo;
	
	return ammo;
}

int GetDefaultWeaponAmmo(const char[] classname)
{
	if(StrContains(classname, "weapon_") != 0)
		return -1;
	
	static ConVar ammo_assaultrifle_max, ammo_autoshotgun_max, ammo_huntingrifle_max,
		ammo_shotgun_max, ammo_smg_max, ammo_sniperrifle_max;
	if(ammo_assaultrifle_max == null)
	{
		ammo_assaultrifle_max = FindConVar("ammo_assaultrifle_max");
		ammo_autoshotgun_max = FindConVar("ammo_autoshotgun_max");
		ammo_huntingrifle_max = FindConVar("ammo_huntingrifle_max");
		ammo_shotgun_max = FindConVar("ammo_shotgun_max");
		ammo_smg_max = FindConVar("ammo_smg_max");
		ammo_sniperrifle_max = FindConVar("ammo_sniperrifle_max");
	}
	
	if(StrEqual(classname, "weapon_rifle", false))
		return ammo_assaultrifle_max.IntValue;
	if(StrEqual(classname, "weapon_rifle_ak47", false))
		return ammo_assaultrifle_max.IntValue;
	if(StrEqual(classname, "weapon_rifle_desert", false))
		return ammo_assaultrifle_max.IntValue;
	if(StrEqual(classname, "weapon_rifle_sg552", false))
		return ammo_assaultrifle_max.IntValue;
	if(StrEqual(classname, "weapon_smg", false))
		return ammo_smg_max.IntValue;
	if(StrEqual(classname, "weapon_smg_silenced", false))
		return ammo_smg_max.IntValue;
	if(StrEqual(classname, "weapon_smg_mp5", false))
		return ammo_smg_max.IntValue;
	if(StrEqual(classname, "weapon_sniper_military", false))
		return ammo_sniperrifle_max.IntValue;
	if(StrEqual(classname, "weapon_sniper_scout", false))
		return ammo_sniperrifle_max.IntValue;
	if(StrEqual(classname, "weapon_sniper_awp", false))
		return ammo_sniperrifle_max.IntValue;
	if(StrEqual(classname, "weapon_hunting_rifle", false))
		return ammo_huntingrifle_max.IntValue;
	if(StrEqual(classname, "weapon_pumpshotgun", false))
		return ammo_shotgun_max.IntValue;
	if(StrEqual(classname, "weapon_shotgun_spas", false))
		return ammo_autoshotgun_max.IntValue;
	if(StrEqual(classname, "weapon_shotgun_chrome", false))
		return ammo_shotgun_max.IntValue;
	if(StrEqual(classname, "weapon_autoshotgun", false))
		return ammo_autoshotgun_max.IntValue;
	
	return -1;
}

stock void InitFindEntity()
{
	new Handle:gConf = LoadGameConfigFile("upgradepackfix");
	if(gConf == null)
		return;
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "CTerrorPlayer::FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity,SDKPass_Pointer);
	g_hFindUseEntity = EndPrepSDKCall();
	
	CloseHandle(gConf);
}

stock int FindUseEntity(int client)
{
	if(g_hFindUseEntity == null)
		return GetClientAimTarget(client, false);
	
	static ConVar cvUseRadius;
	if(cvUseRadius == null)
		cvUseRadius = FindConVar("player_use_radius");
	
	return SDKCall(g_hFindUseEntity,client,cvUseRadius.FloatValue,0.0,0.0,0,false);
}
