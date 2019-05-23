#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION		"0.1"
#include "modules/l4d2ps.sp"

const float g_fMinCycleTime = 0.01;
const float g_fMinCycleRifle = 0.05;
const float g_fMinReloadTime = 0.1;
#define SKILL_FASTFIRE_SLOW_EFFECT	(1.0 - (SC_GetClientLevel(client) / 10 * 0.05))
#define SKILL_FASTFIRE_FAST_EFFECT	(1.0 - (SC_GetClientLevel(client) / 10 * 0.01))
#define SKILL_FASTRELOAD_EFFECT		(1.0 - (SC_GetClientLevel(client) / 10 * 0.1))

public Plugin myinfo =
{
	name = "武器射速/武器填装速度",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	InitPlugin("ws");
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_reload", Event_WeaponReload);
	
	CreateTimer(1.0, Timer_SetupSkill);
}

public Action Timer_SetupSkill(Handle timer, any unused)
{
	SC_CreateSkill("ws_fastfire", "开枪加速", 0, "武器射速加快");
	SC_CreateSkill("abh_fastinsert", "换弹加速", 0, "更换弹夹/填装弹药加快");
	// SC_CreateSkill("abh_autofire", "手枪连射", 0, "手枪和单发武器改为连发");
	return Plugin_Continue;
}

public Action SC_OnSkillGetInfo(int client, const char[] classname,
	char[] display, int displayMaxLength, char[] description, int descriptionMaxLength)
{
	if(StrEqual(classname, "ws_fastfire", false))
		FormatEx(description, descriptionMaxLength, "慢武器射速 ＋%.2f％丨快武器射速 ＋%.2f％", (1 - SKILL_FASTFIRE_SLOW_EFFECT) * 100, (1 - SKILL_FASTFIRE_FAST_EFFECT) * 100);
	else if(StrEqual(classname, "abh_fastinsert", false))
		FormatEx(description, descriptionMaxLength, "换弹速度 ＋%.2f％", (1 - SKILL_FASTRELOAD_EFFECT) * 100);
	else
		return Plugin_Continue;
	
	return Plugin_Changed;
}

public void Event_WeaponFire(Event event, const char[] eventName, bool unknown)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	if(SC_IsClientHaveSkill(client, "ws_fastfire"))
		RequestFrame(SetPlayerFireSpeed, client);
}

public void Event_WeaponReload(Event event, const char[] eventName, bool unknown)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	if(SC_IsClientHaveSkill(client, "abh_fastinsert"))
		SetWeaponReloadSpeed(client);
}

/*
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapons, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!SC_IsClientHaveSkill(client, "abh_autofire") || !(buttons & IN_ATTACK) || !IsPlayerAlive(client) ||
		GetEntProp(client, Prop_Send, "m_isGhost", 1) || GetEntityMoveType(client) == MOVETYPE_LADDER)
		return Plugin_Continue;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon <= MaxClients || !IsValidEdict(weapon))
		return Plugin_Continue;
	
	bool canFire = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") <= GetGameTime();
	if(GetClientTeam(client) == 3)
	{
		if(!canFire && !IsInfectedCarry(client))
		{
			buttons &= ~IN_ATTACK;
			return Plugin_Changed;
		}
	}
	else
	{
		char classname[64];
		GetEntityClassname(weapon, classname, 64);
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		bool inReload = GetEntProp(weapon, Prop_Send, "m_bInReload", 1) > 0;
		if(!canFire && !inReload && clip > 0 && !IsSurvivorHeld(client) && IsSingleWeapon(classname))
		{
			buttons &= ~IN_ATTACK;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}
*/

bool IsSingleWeapon(const char[] classname)
{
	return (StrContains(classname, "sniper", false) > -1 || StrContains(classname, "shotgun", false) > -1 ||
		StrContains(classname, "hunting", false) > -1 || StrContains(classname, "pistol", false) > -1 ||
		StrContains(classname, "launcher", false) > -1);
}

bool IsSurvivorHeld(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0);
}

bool IsInfectedCarry(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0);
}

bool IsGunWeapon(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	return (StrContains(classname, "sniper", false) > -1 || StrContains(classname, "shotgun", false) > -1 ||
		StrContains(classname, "hunting", false) > -1 || StrContains(classname, "pistol", false) > -1 ||
		StrContains(classname, "launcher", false) > -1 || StrContains(classname, "smg", false) > -1 ||
		StrContains(classname, "rifle", false) > -1);
}

bool IsFastShotWeapon(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	return (StrContains(classname, "rifle", false) > -1 || StrContains(classname, "smg", false) > -1);
}

public void SetPlayerFireSpeed(any client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon <= MaxClients || !IsValidEdict(weapon) || !IsGunWeapon(weapon))
		return;
	
	float time = GetGameTime();
	float nextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
	if(nextAttack <= time)
		return;
	
	bool fast = IsFastShotWeapon(weapon);
	float rate = (fast ? SKILL_FASTFIRE_FAST_EFFECT : SKILL_FASTFIRE_SLOW_EFFECT);
	float minRate = (fast ? g_fMinCycleRifle : g_fMinCycleTime);
	if(rate < minRate)
		rate = minRate;
	
	// 动作速度
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0 / rate);
	
	// 开枪间隔
	float primary = (nextAttack - time) * rate;
	if(primary < minRate)
		primary = minRate;
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time + primary);
	
	// 推间隔
	float secondary = (GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack") - time) * rate;
	if(secondary < minRate)
		secondary = minRate;
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", time + secondary);
	
	// 掏出武器时间
	float drawing = (GetEntPropFloat(client, Prop_Send, "m_flNextAttack") - time) * rate;
	if(drawing < minRate)
		drawing = minRate;
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time + drawing);
	
	CreateTimer(primary, Timer_ResetWeaponPlayback, weapon, TIMER_FLAG_NO_MAPCHANGE);
}

public void SetWeaponReloadSpeed(any client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon <= MaxClients || !IsValidEdict(weapon) || !IsGunWeapon(weapon))
		return;
	
	float rate = SKILL_FASTRELOAD_EFFECT;
	if(rate < g_fMinReloadTime)
		rate = g_fMinReloadTime;
	
	if(HasEntProp(weapon, Prop_Send, "m_reloadNumShells"))
	{
		DataPack data = CreateDataPack();
		CreateTimer(0.1, Timer_HandleShotgunReloadSpeed, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(client);
		data.WriteCell(weapon);
		data.WriteFloat(rate);
		return;
	}
	
	float time = GetGameTime();
	float nextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
	float calc = (nextAttack - time) * rate;
	if(calc < g_fMinReloadTime)
		calc = g_fMinReloadTime;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0 / rate);
	CreateTimer(calc, Timer_ResetWeaponPlayback, weapon, TIMER_FLAG_NO_MAPCHANGE);
	
	if(calc > 0.4)
	{
		DataPack data = CreateDataPack();
		CreateTimer(calc - 0.4, Timer_ResetPlayerViewModelTime, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(client);
		data.WriteFloat((time - nextAttack) * (1.0 - rate));
	}
	
	calc += time;
	SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", calc);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", calc);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", calc);
}

public Action Timer_ResetWeaponPlayback(Handle timer, any entity)
{
	if(IsValidEdict(entity))
		SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
	
	return Plugin_Stop;
}

public Action Timer_ResetPlayerViewModelTime(Handle timer, any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	int client = data.ReadCell();
	float start = data.ReadFloat();
	delete data;
	
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(!IsValidEdict(viewModel))
		return Plugin_Stop;
	
	SetEntPropFloat(viewModel, Prop_Send, "m_flLayerStartTime", start);
	return Plugin_Stop;
}

public Action Timer_HandleShotgunReloadSpeed(Handle timer, any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	data.ReadCell();
	int weapon = data.ReadCell();
	float rate = data.ReadFloat();
	// delete data;
	if(rate < g_fMinReloadTime)
		rate = g_fMinReloadTime;
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	if(StrEqual(classname, "weapon_autoshotgun", false))
	{
		SetEntPropFloat(weapon, Prop_Send, "m_reloadStartDuration", 0.666666 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.4 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.675 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0 / rate);
	}
	else if(StrEqual(classname, "weapon_shotgun_spas", false))
	{
		SetEntPropFloat(weapon, Prop_Send, "m_reloadStartDuration", 0.5 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.375 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.699999 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0 / rate);
	}
	else if(StrEqual(classname, "weapon_pumpshotgun", false) ||
		StrEqual(classname, "weapon_shotgun_chrome", false))
	{
		SetEntPropFloat(weapon, Prop_Send, "m_reloadStartDuration", 0.5 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadInsertDuration", 0.5 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_reloadEndDuration", 0.6 * rate);
		SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0 / rate);
	}
	
	CreateTimer(0.3, Timer_ResetShotgunTime, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return Plugin_Stop;
}

public Action Timer_ResetShotgunTime(Handle timer, any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	int client = data.ReadCell();
	int weapon = data.ReadCell();
	if(!IsValidEntity(weapon))
		return Plugin_Stop;
	
	if(GetEntProp(weapon, Prop_Send, "m_reloadState") != 0)
		return Plugin_Continue;
	
	delete data;
	float time = GetGameTime() + 0.2;
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0);
	SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", time);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time);
	return Plugin_Stop;
}
