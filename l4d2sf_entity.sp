#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：实体",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 4;

int g_iSlotSpecial;
int g_iLevelDamage[MAXPLAYERS+1], g_iLevelButton[MAXPLAYERS+1];
ConVar g_cvDamageRate[g_iMaxLevel+1], g_cvTimeRate[g_iMaxLevel+1];

public OnPluginStart()
{
	InitPlugin("sfe");
	g_cvDamageRate[1] = CreateConVar("l4d2_sfe_entity_1st", "2.0", "一级实体伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvDamageRate[2] = CreateConVar("l4d2_sfe_entity_2nd", "3.0", "二级实体伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvDamageRate[3] = CreateConVar("l4d2_sfe_entity_3rd", "4.0", "三级实体伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvDamageRate[4] = CreateConVar("l4d2_sfe_entity_4th", "5.0", "四级实体伤害倍率", CVAR_FLAGS, true, 0.0);
	g_cvTimeRate[1] = CreateConVar("l4d2_sfe_button_1st", "0.75", "一级按钮时间倍率", CVAR_FLAGS, true, 0.0);
	g_cvTimeRate[2] = CreateConVar("l4d2_sfe_button_2nd", "0.5", "二级按钮时间倍率", CVAR_FLAGS, true, 0.0);
	g_cvTimeRate[3] = CreateConVar("l4d2_sfe_button_3rd", "0.25", "三级按钮时间倍率", CVAR_FLAGS, true, 0.0);
	g_cvTimeRate[4] = CreateConVar("l4d2_sfe_button_4th", "0.1", "四级按钮时间倍率", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2sf_entity");
	
	CvarHook_UpdateCache(null, "", "");
	for(int i = 1; i <= g_iMaxLevel; ++i)
	{
		g_cvDamageRate[i].AddChangeHook(CvarHook_UpdateCache);
		g_cvTimeRate[i].AddChangeHook(CvarHook_UpdateCache);
	}
	
	LoadTranslations("l4d2sf_entity.phrases.txt");
	
	g_iSlotSpecial = L4D2SF_RegSlot("special");
	L4D2SF_RegPerk(g_iSlotSpecial, "ent_dmg", g_iMaxLevel, 10, 5, 2.0);
	L4D2SF_RegPerk(g_iSlotSpecial, "btn_time", g_iMaxLevel, 10, 5, 2.0);
}

float g_fDamageRate[g_iMaxLevel+1], g_fTimeRate[g_iMaxLevel+1];

public void CvarHook_UpdateCache(ConVar cvar, const char[] ov, const char[] nv)
{
	for(int i = 1; i <= g_iMaxLevel; ++i)
	{
		g_fDamageRate[i] = g_cvDamageRate[i].FloatValue;
		g_fTimeRate[i] = g_cvTimeRate[i].FloatValue;
	}
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "ent_dmg"))
		FormatEx(result, maxlen, "%T", "实体伤害", client, level);
	else if(!strcmp(name, "btn_time"))
		FormatEx(result, maxlen, "%T", "按钮时间", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "ent_dmg"))
		FormatEx(result, maxlen, "%T", tr("实体伤害%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fDamageRate[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "btn_time"))
		FormatEx(result, maxlen, "%T", tr("按钮时间%d", IntBound(level, 1, g_iMaxLevel)), client, level, 100 - g_fDamageRate[IntBound(level, 1, g_iMaxLevel)] * 100);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "ent_dmg"))
		g_iLevelDamage[client] = level;
	else if(!strcmp(perk, "btn_time"))
		g_iLevelButton[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelDamage[client] = L4D2SF_GetClientPerk(client, "ent_dmg");
	g_iLevelButton[client] = L4D2SF_GetClientPerk(client, "btn_time");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!strcmp(classname, "infected", false) || !strcmp(classname, "player", false) || !strcmp(classname, "witch", false))
		return;
	
	if(HasEntProp(entity, Prop_Data, "m_takedamage") && HasEntProp(entity, Prop_Data, "m_iHealth"))
		SDKHook(entity, SDKHook_SpawnPost, EntHook_DamageableSpawn);
	else if(!strcmp(classname, "func_door_rotating") || !strcmp(classname, "prop_wall_breakable") ||
		!strcmp(classname, "func_breakable") || !strcmp(classname, "func_breakable_surf") ||
		!strcmp(classname, "prop_physics") || !strcmp(classname, "prop_physics_override") ||
		!strcmp(classname, "prop_dynamic") || !strcmp(classname, "prop_dynamic_override"))
		SDKHook(entity, SDKHook_SpawnPost, EntHook_DamageableSpawn);
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	if(!strcmp(classname, "infected", false) || !strcmp(classname, "player", false) || !strcmp(classname, "witch", false))
		return;
	
	SDKUnhook(entity, SDKHook_SpawnPost, EntHook_DamageableSpawn);
	
	if(HasEntProp(entity, Prop_Data, "m_takedamage") && HasEntProp(entity, Prop_Data, "m_iHealth") &&
		GetEntProp(entity, Prop_Data, "m_takedamage") == DAMAGE_YES && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
		SDKHook(entity, SDKHook_OnTakeDamage, EntHook_TakeDamage);
}

public void EntHook_DamageableSpawn(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, EntHook_DamageableSpawn);
	
	if(HasEntProp(entity, Prop_Data, "m_takedamage") && HasEntProp(entity, Prop_Data, "m_iHealth") &&
		GetEntProp(entity, Prop_Data, "m_takedamage") == DAMAGE_YES && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
		SDKHook(entity, SDKHook_OnTakeDamage, EntHook_TakeDamage);
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, EntHook_DamageableSpawn);
	SDKUnhook(entity, SDKHook_OnTakeDamage, EntHook_TakeDamage);
}

public Action EntHook_TakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon,
	float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsValidClient(attacker) || g_iLevelDamage[attacker] < 1 || damage <= 0.0)
		return Plugin_Continue;
	
	damage *= g_fDamageRate[IntBound(g_iLevelDamage[attacker], 1, g_iMaxLevel)];
	return Plugin_Changed;
}

public void OnMapStart()
{
	HookEntityOutput("func_button_timed", "OnPressed", EntHook_ButtonPressed);
	HookEntityOutput("func_button_timed", "OnUnPressed", EntHook_ButtonUnPressed);
	HookEntityOutput("func_button_timed", "OnTimeUp", EntHook_ButtonUnPressed);
	HookEntityOutput("point_script_use_target", "OnUseStarted", EntHook_TargetPressed);
	HookEntityOutput("point_script_use_target", "OnUseCanceled", EntHook_TargetUnPressed);
	HookEntityOutput("point_script_use_target", "OnUseFinished", EntHook_TargetUnPressed);
}

public void OnMapEnd()
{
	UnhookEntityOutput("func_button_timed", "OnPressed", EntHook_ButtonPressed);
	UnhookEntityOutput("func_button_timed", "OnUnPressed", EntHook_ButtonUnPressed);
	UnhookEntityOutput("func_button_timed", "OnTimeUp", EntHook_ButtonUnPressed);
	UnhookEntityOutput("point_script_use_target", "OnUseStarted", EntHook_TargetPressed);
	UnhookEntityOutput("point_script_use_target", "OnUseCanceled", EntHook_TargetUnPressed);
	UnhookEntityOutput("point_script_use_target", "OnUseFinished", EntHook_TargetUnPressed);
}

int g_iOldUseTime[2049];
float g_fOldDuration[2049];

public void EntHook_ButtonPressed(const char[] output, int button, int client, float delay)
{
	if(button <= MaxClients || button > 2048 || !IsValidClient(client) || g_iLevelButton[client] < 1)
		return;
	
	g_iOldUseTime[button] = GetEntProp(button, Prop_Data, "m_nUseTime");
	if(g_iOldUseTime[button] <= 1)
		return;
	
	int time = RoundFloat(g_iOldUseTime[button] * g_fTimeRate[IntBound(g_iLevelButton[client], 1, 4)]);
	SetEntProp(button, Prop_Data, "m_nUseTime", (time > 1 ? time : 1));
}

public void EntHook_ButtonUnPressed(const char[] output, int button, int client, float delay)
{
	if(button <= MaxClients || button > 2048 || g_iOldUseTime[client] <= 0)
		return;
	
	SetEntProp(button, Prop_Data, "m_nUseTime", g_iOldUseTime[client]);
	g_iOldUseTime[client] = -1;
}

public void EntHook_TargetPressed(const char[] output, int button, int client, float delay)
{
	if(button <= MaxClients || button > 2048 || !IsValidClient(client) || g_iLevelButton[client] <= 0)
		return;
	
	g_fOldDuration[button] = GetEntPropFloat(button, Prop_Data, "m_flDuration");
	if(g_fOldDuration[button] <= 0.1)
		return;
	
	float time = g_fOldDuration[button] * g_fTimeRate[IntBound(g_iLevelButton[client], 1, 4)];
	SetEntPropFloat(button, Prop_Data, "m_flDuration", (time > 0.1 ? time : 0.1));
}

public void EntHook_TargetUnPressed(const char[] output, int button, int client, float delay)
{
	if(button <= MaxClients || button > 2048 || g_fOldDuration[client] <= 0.0)
		return;
	
	SetEntPropFloat(button, Prop_Data, "m_flDuration", g_fOldDuration[client]);
	g_fOldDuration[client] = -1.0;
}
