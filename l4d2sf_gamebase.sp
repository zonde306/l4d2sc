#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.0"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能树经验和技能",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

int g_iSlotSurvival, g_iSlotHealing, g_iSlotPistol, g_iSlotShotgun, g_iSlotRifle, g_iSlotSniper, g_iSlotSpecial, g_iSlotAbility, g_iSlotMelee;
ConVar g_cvHurtRate, g_cvHealRate, g_cvPistolRate, g_cvShotgunRate, g_cvRifleRate, g_cvSniperRate, g_cvSpecialRate, g_cvAbilityRate, g_cvMeleeRate, g_cvKillRate;
ConVar g_cvEasy, g_cvNormal, g_cvHard, g_cvExpert, g_cvRealism;
ConVar g_hDiff, g_hMode;

public OnPluginStart()
{
	InitPlugin("sfgb");
	g_cvHurtRate = CreateConVar("l4d2_sfgb_hurt_rate", "1.0", "受伤经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvHealRate = CreateConVar("l4d2_sfgb_cure_rate", "1.0", "治疗经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvPistolRate = CreateConVar("l4d2_sfgb_pistol_rate", "1.0", "手枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvShotgunRate = CreateConVar("l4d2_sfgb_shotgun_rate", "1.0", "霰弹枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvRifleRate = CreateConVar("l4d2_sfgb_rifle_rate", "1.0", "步枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvSniperRate = CreateConVar("l4d2_sfgb_sniper_rate", "1.0", "狙击枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvSpecialRate = CreateConVar("l4d2_sfgb_special_rate", "1.0", "特殊武器经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvAbilityRate = CreateConVar("l4d2_sfgb_ability_rate", "1.0", "特感能力经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvMeleeRate = CreateConVar("l4d2_sfgb_melee_rate", "1.0", "近战武器经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvKillRate = CreateConVar("l4d2_sfgb_kill_rate", "1.0", "击杀经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvEasy = CreateConVar("l4d2_sfgb_difficulty_easy", "0.8", "简单难度经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvNormal = CreateConVar("l4d2_sfgb_difficulty_normal", "1.0", "普通难度经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvHard = CreateConVar("l4d2_sfgb_difficulty_hard", "1.2", "困难难度经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvExpert = CreateConVar("l4d2_sfgb_difficulty_expert", "1.5", "专家难度经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvRealism = CreateConVar("l4d2_sfgb_difficulty_realism", "1.25", "写实难度经验乘数", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfgb");
	
	g_hDiff = FindConVar("z_difficulty");
	g_hMode = FindConVar("mp_gamemode");
	OnCvarChanged_UpdateCache(null, "", "");
	g_cvHurtRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvHealRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvPistolRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvShotgunRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvRifleRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvSniperRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvSpecialRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvAbilityRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvMeleeRate.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvEasy.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvNormal.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvHard.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvExpert.AddChangeHook(OnCvarChanged_UpdateCache);
	g_cvRealism.AddChangeHook(OnCvarChanged_UpdateCache);
	g_hDiff.AddChangeHook(OnCvarChanged_UpdateDifficulty);
	g_hMode.AddChangeHook(OnCvarChanged_UpdateDifficulty);
	
	LoadTranslations("l4d2sf_gamebase.phrases.txt");
	
	g_iSlotSurvival = L4D2SF_RegSlot("survival");
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	g_iSlotPistol = L4D2SF_RegSlot("pistol");
	g_iSlotShotgun = L4D2SF_RegSlot("shotgun");
	g_iSlotRifle = L4D2SF_RegSlot("rifle");
	g_iSlotSniper = L4D2SF_RegSlot("sniper");
	g_iSlotSpecial = L4D2SF_RegSlot("special");
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	g_iSlotMelee = L4D2SF_RegSlot("melee");
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("revive_success", Event_ReviveSuccess);
	// HookEvent("weapon_fire", Event_WeaponFire);
	// HookEvent("weapon_reload", Event_WeaponReload);
	HookEvent("award_earned", Event_AwardEarned);
	HookEvent("upgrade_pack_added", Event_UpgradePickup);
	HookEvent("player_now_it", Event_PlayerHitByVomit);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("tongue_grab", Event_PlayerGrabbed);
	HookEvent("lunge_pounce", Event_PlayerGrabbed);
	HookEvent("jockey_ride", Event_PlayerGrabbed);
	HookEvent("charger_pummel_start", Event_PlayerGrabbed);
	HookEvent("charger_carry_start", Event_PlayerGrabbed);
	HookEvent("ability_use", Event_AbilityUsed);
	HookEvent("player_death", Event_PlayerDeath);
	// HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("witch_spawn", Event_WitchSpawn);
}

float g_fRateHurt, g_fRateHeal, g_fRatePistol, g_fRateShotgun, g_fRateRifle, g_fRateSniper, g_fRateSpecial, g_fRateAbility, g_fRateMelee, g_fFacDiff, g_fRateKill;

public void OnCvarChanged_UpdateCache(ConVar cvar, const char[] ov, const char[] nv)
{
	g_fRateHurt = g_cvHurtRate.FloatValue;
	g_fRateHeal = g_cvHealRate.FloatValue;
	g_fRatePistol = g_cvPistolRate.FloatValue;
	g_fRateShotgun = g_cvShotgunRate.FloatValue;
	g_fRateRifle = g_cvRifleRate.FloatValue;
	g_fRateSniper = g_cvSniperRate.FloatValue;
	g_fRateSpecial = g_cvSpecialRate.FloatValue;
	g_fRateAbility = g_cvAbilityRate.FloatValue;
	g_fRateMelee = g_cvMeleeRate.FloatValue;
	g_fRateKill = g_cvKillRate.FloatValue;
	OnCvarChanged_UpdateDifficulty(null, "", "");
}

public void OnCvarChanged_UpdateDifficulty(ConVar cvar, const char[] ov, const char[] nv)
{
	char diff[16];
	g_hDiff.GetString(diff, sizeof(diff));
	
	if(!strcmp(diff, "easy", false))
		g_fFacDiff = g_cvEasy.FloatValue;
	else if(!strcmp(diff, "normal", false))
		g_fFacDiff = g_cvNormal.FloatValue;
	else if(!strcmp(diff, "hard", false))
		g_fFacDiff = g_cvHard.FloatValue;
	else if(!strcmp(diff, "impossible", false))
		g_fFacDiff = g_cvExpert.FloatValue;
	
	char mode[32];
	g_hMode.GetString(mode, sizeof(mode));
	if(StrContains(mode, "realism", false) > -1)
		g_fFacDiff *= g_cvRealism.FloatValue;
}

public Action L4D2SF_OnGetSlotName(int client, int slotId, char[] result, int maxlen)
{
	if(slotId == g_iSlotSurvival)
		FormatEx(result, maxlen, "%T", "生存", client);
	else if(slotId == g_iSlotHealing)
		FormatEx(result, maxlen, "%T", "治疗", client);
	else if(slotId == g_iSlotPistol)
		FormatEx(result, maxlen, "%T", "手枪", client);
	else if(slotId == g_iSlotShotgun)
		FormatEx(result, maxlen, "%T", "霰弹枪", client);
	else if(slotId == g_iSlotRifle)
		FormatEx(result, maxlen, "%T", "步枪", client);
	else if(slotId == g_iSlotSniper)
		FormatEx(result, maxlen, "%T", "狙击枪", client);
	else if(slotId == g_iSlotSpecial)
		FormatEx(result, maxlen, "%T", "特殊武器", client);
	else if(slotId == g_iSlotAbility)
		FormatEx(result, maxlen, "%T", "特感能力", client);
	else if(slotId == g_iSlotMelee)
		FormatEx(result, maxlen, "%T", "近战武器", client);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

/*
********************************************
*                 事件处理                 *
********************************************
*/

int g_iDamageDone[4096][MAXPLAYERS+1];

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int damage = GetEventInt(event, "dmg_health");
	int damageType = event.GetInt("type");
	// int hitgroup = event.GetInt("hitgroup");
	
	if(damage <= 0 || !IsValidClient(victim))
		return;
	
	static char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	int teamAttacker = 0;
	int teamVictim = GetClientTeam(victim);
	
	if(IsValidClient(attacker))
	{
		teamAttacker = GetClientTeam(attacker);
		if(teamAttacker == 2 && teamVictim == 3)
		{
			if((damageType & DMG_BUCKSHOT) || IsShotgun(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotShotgun, RoundFloat(damage * g_fRateShotgun));
			}
			else if((damageType & DMG_BULLET) && IsRifle(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotRifle, RoundFloat(damage * g_fRateRifle));
			}
			else if((damageType & DMG_BULLET) && IsSniper(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotSniper, RoundFloat(damage * g_fRateSniper));
			}
			else if((damageType & DMG_BULLET) && IsMelee(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else if((damageType & DMG_BULLET) && IsPistol(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotPistol, RoundFloat(damage * g_fRatePistol));
			}
			else if((damageType & (DMG_SLASH|DMG_CLUB)) || IsMelee(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else
			{
				GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(damage * g_fRateSpecial));
			}
		}
		else if(teamAttacker == 3 && teamVictim == 2)
		{
			if(IsClaw(weapon))
			{
				GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else
			{
				GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(damage * g_fRateAbility));
			}
		}
		
		if(teamAttacker != teamVictim)
		{
			GiveSkillExperience(victim, g_iSlotSurvival, RoundFloat(damage * g_fRateHurt));
		}
		
		g_iDamageDone[victim][attacker] += damage;
	}
	else
	{
		attacker = event.GetInt("attackerentid");
		if(attacker > MaxClients && IsValidEdict(attacker))
		{
			teamAttacker = GetEntProp(attacker, Prop_Data, "m_iTeamNum");
			if(teamAttacker == 3 && teamVictim == 2)
			{
				GiveSkillExperience(victim, g_iSlotSurvival, RoundFloat(damage * g_fRateHurt));
			}
		}
	}
}

public void Event_InfectedHurt(Event event, const char[] eventName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = event.GetInt("entityid");
	int damage = event.GetInt("amount");
	int damageType = event.GetInt("type");
	// int hitgroup = event.GetInt("hitgroup");
	
	if(victim < MaxClients || damage <= 0 || !IsValidClient(attacker) || !IsValidEdict(victim) || GetClientTeam(attacker) != 2)
		return;
	
	int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	if((damageType & DMG_BUCKSHOT) && IsShotgun(classname))
	{
		GiveSkillExperience(attacker, g_iSlotShotgun, RoundFloat(damage * g_fRateShotgun));
	}
	else if((damageType & DMG_BULLET) && IsRifle(classname))
	{
		GiveSkillExperience(attacker, g_iSlotRifle, RoundFloat(damage * g_fRateRifle));
	}
	else if((damageType & DMG_BULLET) && IsSniper(classname))
	{
		GiveSkillExperience(attacker, g_iSlotSniper, RoundFloat(damage * g_fRateSniper));
	}
	else if((damageType & DMG_BULLET) && IsMelee(classname))
	{
		GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
	}
	else if((damageType & DMG_BULLET) && IsPistol(classname))
	{
		GiveSkillExperience(attacker, g_iSlotPistol, RoundFloat(damage * g_fRatePistol));
	}
	else if((damageType & (DMG_SLASH|DMG_CLUB)) && IsMelee(classname))
	{
		GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
	}
	else
	{
		GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(damage * g_fRateSpecial));
	}
	
	g_iDamageDone[victim][attacker] += damage;
}

public void Event_PillsUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	GiveSkillExperience(client, g_iSlotHealing, RoundFloat(50 * g_fRateHeal));
}

public void Event_AdrenalineUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	GiveSkillExperience(client, g_iSlotHealing, RoundFloat(30 * g_fRateHeal));
}

public void Event_HealSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	int health = event.GetInt("health_restored");
	if(health <= 0 || !IsValidClient(client) || !IsValidClient(subject))
		return;
	
	if(client == subject)
	{
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(health * g_fRateHeal));
	}
	else
	{
		int amount = RoundFloat(health * g_fRateHeal);
		GiveSkillExperience(client, g_iSlotHealing, amount > health ? amount : health);
		GiveSkillExperience(subject, g_iSlotHealing, amount > health ? health : amount);
	}
}

public void Event_DefibrillatorUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client) || !IsValidClient(subject))
		return;
	
	if(client != subject)
	{
		int amount = RoundFloat(50 * g_fRateHeal);
		GiveSkillExperience(client, g_iSlotHealing, amount > 50 ? amount : 50);
		GiveSkillExperience(subject, g_iSlotHealing, amount > 50 ? 50 : amount);
	}
	else
	{
		// 这不可能
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(50 * g_fRateHeal));
	}
}

public void Event_ReviveSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	bool hanging = event.GetBool("ledge_hang");
	if(hanging || !IsValidClient(client) || !IsValidClient(subject))
		return;
	
	if(client != subject)
	{
		int amount = RoundFloat(30 * g_fRateHeal);
		GiveSkillExperience(client, g_iSlotHealing, amount > 30 ? amount : 30);
		GiveSkillExperience(subject, g_iSlotHealing, amount > 30 ? 30 : amount);
	}
	else
	{
		// 这不可能
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(30 * g_fRateHeal));
	}
}

/*
public void Event_WeaponFire(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	if(IsShotgun(classname))
	{
		GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 5));
	}
	else if(IsRifle(classname))
	{
		GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 5));
	}
	else if(IsSniper(classname))
	{
		GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else if(IsPistol(classname))
	{
		GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else
	{
		GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 5));
	}
}

public void Event_WeaponReload(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	if(IsShotgun(classname))
	{
		GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 5));
	}
	else if(IsRifle(classname))
	{
		GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 5));
	}
	else if(IsSniper(classname))
	{
		GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else if(IsPistol(classname))
	{
		GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else
	{
		GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 5));
	}
}
*/

public void Event_AwardEarned(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = event.GetInt("subjectentid");
	// int entity = event.GetInt("entityid");
	int award = event.GetInt("award");

	if(!IsValidClient(client) || client == subject)
		return;
	
	if(award == 67)
	{
		// 保护队友
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(3 * g_fRateHeal));
	}
	else if(award == 68)
	{
		// 给队友递药
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(20 * g_fRateHeal));
		
		if(IsValidClient(subject))
			GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(5 * g_fRateHeal));
	}
	else if(award == 69)
	{
		// 给队友递针
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(15 * g_fRateHeal));
		
		if(IsValidClient(subject))
			GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(5 * g_fRateHeal));
	}
	else if(award == 76)
	{
		// 把队友从特感的控制中救出
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(2 * g_fRateHeal));
	}
	else if(award == 80)
	{
		// 开门复活队友
		GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(2 * g_fRateHeal));
	}
	else if(award == 81)
	{
		// 克局过后没有死亡
		GiveSkillExperience(client, g_iSlotSurvival, RoundFloat(10 * g_fRateHeal));
	}
}

public void Event_UpgradePickup(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	if(IsShotgun(classname))
	{
		GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 10));
	}
	else if(IsRifle(classname))
	{
		GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 10));
	}
	else if(IsSniper(classname))
	{
		GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 10));
	}
	else if(IsMelee(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 10));
	}
	else if(IsPistol(classname))
	{
		GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 10));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 10));
	}
	else
	{
		GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 10));
	}
}

public void Event_PlayerHitByVomit(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(victim) || !IsValidClient(attacker))
		return;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetClientTeam(victim);
	if(teamAttacker == teamVictim)
		return;
	
	if(teamAttacker == 2)
	{
		GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(20 * g_fRateSpecial));
	}
	else if(teamAttacker == 3)
	{
		GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(20 * g_fRateAbility));
	}
}

public void Event_PlayerShoved(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(!IsValidClient(attacker) || !IsValidClient(victim))
		return;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetClientTeam(victim);
	if(teamAttacker != 2 || teamVictim != 3)
		return;
	
	GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(20 * g_fRateMelee));
}

public void Event_PlayerGrabbed(Event event, const char[] event_name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	int victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if(!IsValidClient(attacker) || !IsValidClient(victim))
		return;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetClientTeam(victim);
	if(teamAttacker != 3 || teamVictim != 2)
		return;
	
	GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(30 * g_fRateAbility));
}

public void Event_AbilityUsed(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	GiveSkillExperience(client, g_iSlotAbility, RoundFloat(10 * g_fRateAbility));
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(attacker))
		return;
	
	int teamVictim = 0;
	int teamAttacker = GetClientTeam(attacker);
	
	if(IsValidClient(victim))
	{
		teamVictim = GetClientTeam(victim);
	}
	else
	{
		victim = event.GetInt("entityid");
		if(!IsValidEdict(victim))
			return;
		
		teamVictim = GetEntProp(victim, Prop_Data, "m_iTeamNum");
	}
	
	if(teamAttacker == teamVictim)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && g_iDamageDone[victim][i] > 0)
			GiveExperience(i, RoundFloat(g_iDamageDone[victim][i] * g_fRateKill));
		g_iDamageDone[victim][i] = 0;
	}
}

/*
public void Event_InfectedDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = event.GetInt("infected_id");
	
	if(!IsValidClient(attacker) || !IsValidEdict(victim))
		return;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetEntProp(victim, Prop_Data, "m_iTeamNum");
	if(teamAttacker == teamVictim)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && g_iDamageDone[victim][i] > 0)
			GiveExperience(i, RoundFloat(g_iDamageDone[victim][i] * g_fRateKill));
		g_iDamageDone[victim][i] = 0;
	}
}
*/

public void Event_PlayerIncapacitated(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(!IsValidClient(attacker) || !IsValidClient(victim))
		return;
	
	int teamAttacker = GetClientTeam(attacker);
	int teamVictim = GetClientTeam(victim);
	if(teamAttacker == teamVictim)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidClient(i) && g_iDamageDone[victim][i] > 0)
			GiveExperience(i, RoundFloat(g_iDamageDone[victim][i] * g_fRateKill));
		g_iDamageDone[victim][i] = 0;
	}
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
		g_iDamageDone[client][i] = 0;
}

public void Event_WitchSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if(!IsValidEdict(witch))
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
		g_iDamageDone[witch][i] = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!strcmp(classname, "infected", false))
	{
		for(int i = 1; i <= MaxClients; ++i)
			g_iDamageDone[entity][i] = 0;
	}
}

/*
********************************************
*                   杂项                   *
********************************************
*/

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

void GiveSkillExperience(int client, int slotId, int amount)
{
	L4D2SF_GiveSkillExperience(client, slotId, RoundFloat(amount * g_fFacDiff));
}

void GiveExperience(int client, int amount)
{
	L4D2SF_GiveExperience(client, RoundFloat(amount * g_fFacDiff));
}
