#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：伤害修复",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 1;
const int g_iMinLevel = 4;
const int g_iMinSkillLevel = 30;
const float g_fLevelFactor = 1.0;

int g_iSlotShotgun, g_iSlotMelee, g_iSlotSurvival;
int g_iLevelCharge[MAXPLAYERS+1], g_iLevelSkeet[MAXPLAYERS+1], g_iLevelStagging[MAXPLAYERS+1], g_iLevelGettingUP[MAXPLAYERS+1];
ConVar g_cvSkeetDamage;

public OnPluginStart()
{
	g_cvSkeetDamage = FindConVar("z_pounce_damage_interrupt");
	OnSkeetDamageChanged(null, "", "");
	g_cvSkeetDamage.AddChangeHook(OnSkeetDamageChanged);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	
	LoadTranslations("l4d2sf_ai_dmgfix.phrases.txt");
	
	g_iSlotShotgun = L4D2SF_RegSlot("shotgun");
	g_iSlotMelee = L4D2SF_RegSlot("melee");
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	L4D2SF_RegPerk(g_iSlotMelee, "charging_dmg", 2, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "skeet_dmg", 2, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSurvival, "stagging_hurt", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSurvival, "gettingup_hurt", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

float g_fSkeetDamage;

public void OnSkeetDamageChanged(ConVar cvar, const char[] ov, const char[] nv)
{
	g_fSkeetDamage = g_cvSkeetDamage.FloatValue;
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "charging_dmg"))
		FormatEx(result, maxlen, "%T", "冲锋伤害修正", client, level);
	else if(!strcmp(name, "skeet_dmg"))
		FormatEx(result, maxlen, "%T", "飞碟伤害修正", client, level);
	else if(!strcmp(name, "stagging_hurt"))
		FormatEx(result, maxlen, "%T", "失衡伤害修正", client, level);
	else if(!strcmp(name, "gettingup_hurt"))
		FormatEx(result, maxlen, "%T", "起身伤害修正", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "charging_dmg"))
		FormatEx(result, maxlen, "%T", tr("冲锋伤害修正%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "skeet_dmg"))
		FormatEx(result, maxlen, "%T", tr("飞碟伤害修正%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "stagging_hurt"))
		FormatEx(result, maxlen, "%T", tr("失衡伤害修正%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "gettingup_hurt"))
		FormatEx(result, maxlen, "%T", tr("起身伤害修正%d", IntBound(level, 1, 2)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "charging_dmg"))
		g_iLevelCharge[client] = level;
	else if(!strcmp(perk, "skeet_dmg"))
		g_iLevelSkeet[client] = level;
	else if(!strcmp(perk, "stagging_hurt"))
		g_iLevelStagging[client] = level;
	else if(!strcmp(perk, "gettingup_hurt"))
		g_iLevelGettingUP[client] = level;
}

float g_fDamageTake[MAXPLAYERS+1];
int g_iCarrying[MAXPLAYERS+1];

public Action L4D2_OnStagger(int target, int source)
{
	for(int i = 1; i <= MaxClients; ++i)
		if(g_iCarrying[i] == target)
			g_iCarrying[i] = 0;
	
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelCharge[client] = L4D2SF_GetClientPerk(client, "charging_dmg");
	g_iLevelSkeet[client] = L4D2SF_GetClientPerk(client, "skeet_dmg");
	g_iLevelStagging[client] = L4D2SF_GetClientPerk(client, "stagging_hurt");
	g_iLevelGettingUP[client] = L4D2SF_GetClientPerk(client, "gettingup_hurt");
	
	g_fDamageTake[client] = 0.0;
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_fDamageTake[client] = 0.0;
	SDKUnhook(client, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	
	for(int i = 1; i <= MaxClients; ++i)
		if(g_iCarrying[i] == client)
			g_iCarrying[i] = 0;
}

public void Event_ChargerCarryEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(!IsValidClient(victim))
		return;
	
	if(!IsValidAliveClient(attacker) || IsPlayerStagging(attacker))
	{
		g_iCarrying[victim] = 0;
	}
	else
	{
		int parent = GetEntPropEnt(victim, Prop_Send, "moveparent");
		if(parent == attacker)
			g_iCarrying[victim] = attacker;
	}
}

public void Event_ChargerPummelStart(Event event, const char[] eventName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(!IsValidClient(victim) || !IsValidAliveClient(attacker))
		return;
	
	g_iCarrying[victim] = 0;
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_iCarrying[player] = g_iCarrying[bot];
	SDKUnhook(bot, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(player, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	g_iCarrying[bot] = g_iCarrying[player];
	SDKUnhook(player, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
	SDKHook(bot, SDKHook_OnTakeDamage, EntHook_OnTakeDamage);
}

#define IsSurvivorHeld(%1)		(GetEntPropEnt(%1, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(%1, Prop_Send, "m_carryAttacker") > 0)

public Action EntHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon,
	float damageForce[3], float damagePosition[3], int damageCustom)
{
	int temaAttacker = GetEntProp(attacker, Prop_Data, "m_iTeamNum");
	int teamVictim = GetClientTeam(victim);
	
	if(temaAttacker == 2 && teamVictim == 3 && IsFakeClient(victim) && IsValidClient(attacker))
	{
		int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if(zClass == Z_CHARGER && g_iLevelCharge[attacker] >= 1 && (damageType & (DMG_SLASH|DMG_CLUB|DMG_MELEE)))
		{
			if(IsChargerCharging(victim))
			{
				damage = damage * 3 + 1;
				return Plugin_Changed;
			}
		}
		else if(zClass == Z_HUNTER && g_iLevelSkeet[attacker] >= 1 && (damageType & DMG_BUCKSHOT))
		{
			if(GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
			{
				g_fDamageTake[victim] += damage;
				if(g_fDamageTake[victim] >= g_fSkeetDamage)
				{
					damage = float(GetClientHealth(victim));
					return Plugin_Changed;
				}
			}
		}
		else if(zClass == Z_JOCKEY && g_iLevelSkeet[attacker] >= 2 && (damageType & DMG_BUCKSHOT))
		{
			if(IsJockeyLeaping(victim))
			{
				g_fDamageTake[victim] += damage;
				if(g_fDamageTake[victim] >= g_fSkeetDamage)
				{
					damage = float(GetClientHealth(victim));
					return Plugin_Changed;
				}
			}
		}
	}
	else if(temaAttacker == 3 && teamVictim == 2)
	{
		if(g_iLevelStagging[victim] >= 1 && IsValidClient(attacker) && IsFakeClient(attacker) && IsPlayerStagging(attacker))
		{
			damage = 0.0;
			return Plugin_Changed;
		}
		
		if(g_iLevelGettingUP[victim] >= 1 && !GetEntProp(victim, Prop_Send, "m_isIncapacitated", 1) &&
			!GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1) && !IsSurvivorHeld(victim) && IsPlayerGettingUp(victim))
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	else if(temaAttacker == 2 && teamVictim == 2)
	{
		if(g_iLevelCharge[victim] >= 2)
		{
			int charger = GetEntPropEnt(victim, Prop_Send, "m_carryAttacker");
			if(!IsValidClient(charger))
				charger = g_iCarrying[victim];
			
			if(IsValidClient(charger))
			{
				damage = 0.0;
				SDKHooks_TakeDamage(charger, inflictor, attacker, damage, damageType, weapon, damageForce, damagePosition);
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

bool IsChargerCharging(int client)
{
	if( GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_CHARGER )
	{
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility"); // ability_charge
		if( ability > 0 && IsValidEdict(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") )
		{
			return true;
		}
	}
	
	return false;
}

bool IsJockeyLeaping( int jockey )
{
	if(GetEntProp(jockey, Prop_Send, "m_zombieClass") != Z_JOCKEY ||
		GetEntPropEnt(jockey, Prop_Send, "m_hGroundEntity") > -1 ||
		GetEntityMoveType(jockey) != MOVETYPE_WALK ||
		GetEntProp(jockey, Prop_Send, "m_nWaterLevel") >= 3 ||	// 0: no water, 1: a little, 2: half body, 3: full body under water
		GetEntPropEnt(jockey, Prop_Send, "m_jockeyVictim") > -1)
		return false;
	
	int abilityEnt = GetEntPropEnt( jockey, Prop_Send, "m_customAbility" );
	if ( IsValidEntity(abilityEnt) && HasEntProp(abilityEnt, Prop_Send, "m_isLeaping") &&
		GetEntProp(abilityEnt, Prop_Send, "m_isLeaping") )
		return true;
	
	/*
	new Float:time = GetGameTime();
	if ( IsValidEntity(abilityEnt) && HasEntProp(abilityEnt, Prop_Send, "m_timestamp") &&
		GetEntPropFloat(abilityEnt, Prop_Send, "m_timestamp") <= time &&
		GetEntPropEnt(jockey, Prop_Send, "m_hGroundEntity") == -1 )
		return true;
	*/
	
	float vel[3];
	GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", vel ); 
	vel[2] = 0.0;
	
	if(GetVectorLength(vel) >= 15.0 && GetEntPropEnt(jockey, Prop_Send, "m_hGroundEntity") == -1)
		return true;
	
	return false;
}

void L4D2_RunScript(char[] sCode, any ...)
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static char sBuffer[8192];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

bool IsPlayerStagging(int client)
{
	static ConVar cv_result;
	if(cv_result == null)
		cv_result = CreateConVar("l4d2sf_aidmgfix_stagging", "", "");
	
	L4D2_RunScript("Convars.SetValue(\"l4d2sf_aidmgfix_stagging\", PlayerInstanceFromIndex(%d).IsStaggering())", client);
	return cv_result.BoolValue;
}

bool IsPlayerGettingUp(int client)
{
	static ConVar cv_result;
	if(cv_result == null)
		cv_result = CreateConVar("l4d2sf_aidmgfix_gettingup", "", "");
	
	L4D2_RunScript("Convars.SetValue(\"l4d2sf_aidmgfix_gettingup\", PlayerInstanceFromIndex(%d).IsGettingUp())", client);
	return cv_result.BoolValue;
}
