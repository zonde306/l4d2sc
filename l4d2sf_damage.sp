#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能树伤害类技能",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 4;
const int g_iMinLevel = 5;
const int g_iMinSkillLevel = 15;
const float g_fLevelFactor = 1.5;

int g_iSlotPistol, g_iSlotShotgun, g_iSlotRifle, g_iSlotSniper, g_iSlotSpecial, g_iSlotMelee;
ConVar g_cvPistolMul[g_iMaxLevel+1], g_cvShotgunMul[g_iMaxLevel+1], g_cvRifleMul[g_iMaxLevel+1], g_cvSniperMul[g_iMaxLevel+1],
	g_cvSpecialMul[g_iMaxLevel+1], g_cvMeleeMul[g_iMaxLevel+1];

public OnPluginStart()
{
	InitPlugin("sfd");
	g_cvPistolMul[1] = CreateConVar("l4d2_sfd_pistol_1st", "1.25", "一级手枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolMul[2] = CreateConVar("l4d2_sfd_pistol_2nd", "1.5", "二级手枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolMul[3] = CreateConVar("l4d2_sfd_pistol_3rd", "1.75", "三级手枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolMul[4] = CreateConVar("l4d2_sfd_pistol_4th", "2.0", "四级手枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunMul[1] = CreateConVar("l4d2_sfd_shotgun_1st", "1.25", "一级霰弹枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunMul[2] = CreateConVar("l4d2_sfd_shotgun_2nd", "1.5", "二级霰弹枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunMul[3] = CreateConVar("l4d2_sfd_shotgun_3rd", "1.75", "三级霰弹枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunMul[4] = CreateConVar("l4d2_sfd_shotgun_4th", "2.0", "四级霰弹枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleMul[1] = CreateConVar("l4d2_sfd_rifle_1st", "1.25", "一级步枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleMul[2] = CreateConVar("l4d2_sfd_rifle_2nd", "1.5", "二级步枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleMul[3] = CreateConVar("l4d2_sfd_rifle_3rd", "1.75", "三级步枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleMul[4] = CreateConVar("l4d2_sfd_rifle_4th", "2.0", "四级步枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperMul[1] = CreateConVar("l4d2_sfd_sniper_1st", "1.25", "一级狙击枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperMul[2] = CreateConVar("l4d2_sfd_sniper_2nd", "1.5", "二级狙击枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperMul[3] = CreateConVar("l4d2_sfd_sniper_3rd", "1.75", "三级狙击枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperMul[4] = CreateConVar("l4d2_sfd_sniper_4th", "2.0", "四级狙击枪伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSpecialMul[1] = CreateConVar("l4d2_sfd_special_1st", "1.25", "一级特殊武器伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSpecialMul[2] = CreateConVar("l4d2_sfd_special_2nd", "1.5", "二级特殊武器伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSpecialMul[3] = CreateConVar("l4d2_sfd_special_3rd", "1.75", "三级特殊武器伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvSpecialMul[4] = CreateConVar("l4d2_sfd_special_4th", "2.0", "四级特殊武器伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeMul[1] = CreateConVar("l4d2_sfd_melee_1st", "1.25", "一级近战伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeMul[2] = CreateConVar("l4d2_sfd_melee_2nd", "1.5", "二级近战伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeMul[3] = CreateConVar("l4d2_sfd_melee_3rd", "1.75", "三级近战伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeMul[4] = CreateConVar("l4d2_sfd_melee_4th", "2.0", "四级近战伤害倍率", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfd");
	
	OnCvarChanged_UpdateCache(null, "", "");
	for(int i = 1; i <= g_iMaxLevel; ++i)
	{
		g_cvPistolMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
		g_cvShotgunMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
		g_cvRifleMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
		g_cvSniperMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
		g_cvSpecialMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
		g_cvMeleeMul[i].AddChangeHook(OnCvarChanged_UpdateCache);
	}
	
	LoadTranslations("l4d2sf_damage.phrases.txt");
	
	g_iSlotPistol = L4D2SF_RegSlot("pistol");
	g_iSlotShotgun = L4D2SF_RegSlot("shotgun");
	g_iSlotRifle = L4D2SF_RegSlot("rifle");
	g_iSlotSniper = L4D2SF_RegSlot("sniper");
	g_iSlotSpecial = L4D2SF_RegSlot("special");
	g_iSlotMelee = L4D2SF_RegSlot("melee");
	
	L4D2SF_RegPerk(g_iSlotPistol, "pistol_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSpecial, "special_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotMelee, "melee_dmg", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

float g_fRatePistol[g_iMaxLevel+1], g_fRateShotgun[g_iMaxLevel+1], g_fRateRifle[g_iMaxLevel+1], g_fRateSniper[g_iMaxLevel+1],
	g_fRateSpecial[g_iMaxLevel+1], g_fRateMelee[g_iMaxLevel+1];

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "pistol_dmg"))
		FormatEx(result, maxlen, "%T", "手枪伤害", client, level);
	else if(!strcmp(name, "shotgun_dmg"))
		FormatEx(result, maxlen, "%T", "喷子伤害", client, level);
	else if(!strcmp(name, "rifle_dmg"))
		FormatEx(result, maxlen, "%T", "步枪伤害", client, level);
	else if(!strcmp(name, "sniper_dmg"))
		FormatEx(result, maxlen, "%T", "狙击伤害", client, level);
	else if(!strcmp(name, "special_dmg"))
		FormatEx(result, maxlen, "%T", "特殊伤害", client, level);
	else if(!strcmp(name, "melee_dmg"))
		FormatEx(result, maxlen, "%T", "近战伤害", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(level <= 0 || level > g_iMaxLevel)
		return Plugin_Continue;
	
	if(!strcmp(name, "pistol_dmg"))
		FormatEx(result, maxlen, "%T", tr("手枪伤害%d", level), client, level, g_fRatePistol[level] * 100 - 100);
	else if(!strcmp(name, "shotgun_dmg"))
		FormatEx(result, maxlen, "%T", tr("喷子伤害%d", level), client, level, g_fRateShotgun[level] * 100 - 100);
	else if(!strcmp(name, "rifle_dmg"))
		FormatEx(result, maxlen, "%T", tr("步枪伤害%d", level), client, level, g_fRateRifle[level] * 100 - 100);
	else if(!strcmp(name, "sniper_dmg"))
		FormatEx(result, maxlen, "%T", tr("狙击伤害%d", level), client, level, g_fRateSniper[level] * 100 - 100);
	else if(!strcmp(name, "special_dmg"))
		FormatEx(result, maxlen, "%T", tr("特殊伤害%d", level), client, level, g_fRateSpecial[level] * 100 - 100);
	else if(!strcmp(name, "melee_dmg"))
		FormatEx(result, maxlen, "%T", tr("近战伤害%d", level), client, level, g_fRateMelee[level] * 100 - 100);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void OnCvarChanged_UpdateCache(ConVar cvar, const char[] ov, const char[] nv)
{
	for(int i = 1; i <= g_iMaxLevel; ++i)
	{
		g_fRatePistol[i] = g_cvPistolMul[i].FloatValue;
		g_fRateShotgun[i] = g_cvShotgunMul[i].FloatValue;
		g_fRateRifle[i] = g_cvRifleMul[i].FloatValue;
		g_fRateSniper[i] = g_cvSniperMul[i].FloatValue;
		g_fRateSpecial[i] = g_cvSpecialMul[i].FloatValue;
		g_fRateMelee[i] = g_cvMeleeMul[i].FloatValue;
	}
}

int g_iLevelPistol[MAXPLAYERS+1], g_iLevelShotgun[MAXPLAYERS+1], g_iLevelRifle[MAXPLAYERS+1],
	g_iLevelSniper[MAXPLAYERS+1], g_iLevelSpecial[MAXPLAYERS+1], g_iLevelMelee[MAXPLAYERS+1];

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "pistol_dmg"))
		g_iLevelPistol[client] = level;
	else if(!strcmp(perk, "shotgun_dmg"))
		g_iLevelShotgun[client] = level;
	else if(!strcmp(perk, "rifle_dmg"))
		g_iLevelRifle[client] = level;
	else if(!strcmp(perk, "sniper_dmg"))
		g_iLevelSniper[client] = level;
	else if(!strcmp(perk, "special_dmg"))
		g_iLevelSpecial[client] = level;
	else if(!strcmp(perk, "melee_dmg"))
		g_iLevelMelee[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelPistol[client] = L4D2SF_GetClientPerk(client, "pistol_dmg");
	g_iLevelShotgun[client] = L4D2SF_GetClientPerk(client, "shotgun_dmg");
	g_iLevelRifle[client] = L4D2SF_GetClientPerk(client, "rifle_dmg");
	g_iLevelSniper[client] = L4D2SF_GetClientPerk(client, "sniper_dmg");
	g_iLevelSpecial[client] = L4D2SF_GetClientPerk(client, "special_dmg");
	g_iLevelMelee[client] = L4D2SF_GetClientPerk(client, "melee_dmg");
	
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!strcmp(classname, "infected", false) || !strcmp(classname, "witch", false))
	{
		SDKUnhook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	}
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon,
	float damageForce[3], float damagePosition[3], int damageCustom)
{
	if(!IsValidClient(attacker) || damage <= 0.0)
		return Plugin_Continue;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetEntProp(victim, Prop_Data, "m_iTeamNum");
	if(teamAttacker == teamVictim)
		return Plugin_Continue;
	
	char classname[64];
	if(weapon > MaxClients && IsValidEdict(weapon))
		GetEdictClassname(weapon, classname, sizeof(classname));
	else if(inflictor > MaxClients && IsValidEdict(inflictor))
		GetEdictClassname(inflictor, classname, sizeof(classname));
	else
		return Plugin_Continue;
	
	if(teamAttacker == 2 && teamVictim == 3)
	{
		if((damageType & DMG_BUCKSHOT) || IsShotgun(classname))
		{
			damage *= LevelFactor(g_iLevelShotgun[attacker], g_fRateShotgun);
		}
		else if((damageType & DMG_BULLET) && IsRifle(classname))
		{
			damage *= LevelFactor(g_iLevelRifle[attacker], g_fRateRifle);
		}
		else if((damageType & DMG_BULLET) && IsSniper(classname))
		{
			damage *= LevelFactor(g_iLevelSniper[attacker], g_fRateSniper);
		}
		else if((damageType & DMG_BULLET) && IsPistol(classname))
		{
			damage *= LevelFactor(g_iLevelPistol[attacker], g_fRatePistol);
		}
		else if((damageType & (DMG_SLASH|DMG_CLUB)) || IsMelee(classname))
		{
			damage *= LevelFactor(g_iLevelMelee[attacker], g_fRateMelee);
		}
		else
		{
			damage *= LevelFactor(g_iLevelSpecial[attacker], g_fRateSpecial);
		}
	}
	else if(teamAttacker == 3 && teamVictim == 2)
	{
		if(IsClaw(classname))
		{
			damage *= LevelFactor(g_iLevelMelee[attacker], g_fRateMelee);
		}
		else if(GetCurrentVictim(attacker) != victim)
		{
			damage *= LevelFactor(g_iLevelSpecial[attacker], g_fRateSpecial);
		}
		else
		{
			return Plugin_Continue;
		}
	}
	else
	{
		return Plugin_Continue;
	}
	
	return Plugin_Changed;
}

bool IsShotgun(const char[] weapon)
{
	return StrContains(weapon, "shotgun") > -1;
}

bool IsRifle(const char[] weapon, bool withSMG = true)
{
	if(StrContains(weapon, "rifle") > -1)
		return true;
	
	return withSMG && StrContains(weapon, "smg") > -1;
}

bool IsPistol(const char[] weapon)
{
	return StrContains(weapon, "pistol") > -1;
}

bool IsSniper(const char[] weapon)
{
	return StrContains(weapon, "sniper") > -1;
}

bool IsMelee(const char[] weapon)
{
	return StrContains(weapon, "melee") > -1;
}

bool IsClaw(const char[] weapon)
{
	return StrContains(weapon, "claw") > -1;
}

float LevelFactor(int level, float[] factors)
{
	if(level <= 0)
		return 1.0;
	if(level > g_iMaxLevel)
		return factors[g_iMaxLevel];
	return factors[level];
}

int GetCurrentAttacker(int client)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if(IsValidAliveClient(attacker))
		return attacker;
	
	return -1;
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
