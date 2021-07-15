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
ConVar g_cvHurtRate, g_cvHealRate, g_cvPistolRate, g_cvShotgunRate, g_cvRifleRate, g_cvSniperRate, g_cvSpecialRate, g_cvAbilityRate, g_cvMeleeRate;

public OnPluginStart()
{
	InitPlugin("sfgb");
	g_cvHurtRate = CreateConVar("l4d2sf_hurt_rate", "1.0", "受伤经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvHealRate = CreateConVar("l4d2sf_cure_rate", "1.0", "治疗经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvPistolRate = CreateConVar("l4d2sf_pistol_rate", "1.0", "手枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvShotgunRate = CreateConVar("l4d2sf_shotgun_rate", "1.0", "霰弹枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvRifleRate = CreateConVar("l4d2sf_rifle_rate", "1.0", "步枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvSniperRate = CreateConVar("l4d2sf_sniper_rate", "1.0", "狙击枪经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvSpecialRate = CreateConVar("l4d2sf_special_rate", "1.0", "特殊武器经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvAbilityRate = CreateConVar("l4d2sf_ability_rate", "1.0", "特感能力经验乘数", CVAR_FLAGS, true, 0.0);
	g_cvMeleeRate = CreateConVar("l4d2sf_melee_rate", "1.0", "近战武器经验乘数", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2sf_gamebase");
	
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
	// HookEvent("player_death", Event_PlayerDeath);
	HookEvent("infected_hurt", Event_InfectedHurt);
	// HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("heal_success", Event_HealSuccess);
	// HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_reload", Event_WeaponReload);
	HookEvent("award_earned", Event_AwardEarned);
	// HookEvent("survivor_rescued", Event_SurvivorRescued);
	HookEvent("upgrade_pack_added", Event_UpgradePickup);
	HookEvent("player_now_it", Event_PlayerHitByVomit);
	HookEvent("player_shoved", Event_PlayerShoved);
	// HookEvent("survival_at_30min", Event_SurvivalAt30Min, EventHookMode_PostNoCopy);
	// HookEvent("survival_at_10min", Event_SurvivalAt10Min, EventHookMode_PostNoCopy);
	HookEvent("tongue_grab", Event_PlayerGrabbed);
	HookEvent("lunge_pounce", Event_PlayerGrabbed);
	HookEvent("jockey_ride", Event_PlayerGrabbed);
	HookEvent("charger_pummel_start", Event_PlayerGrabbed);
	HookEvent("charger_carry_start", Event_PlayerGrabbed);
	HookEvent("ability_use", Event_AbilityUsed);
}

float g_fRateHurt, g_fRateHeal, g_fRatePistol, g_fRateShotgun, g_fRateRifle, g_fRateSniper, g_fRateSpecial, g_fRateAbility, g_fRateMelee;

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
				L4D2SF_GiveSkillExperience(attacker, g_iSlotShotgun, RoundFloat(damage * g_fRateShotgun));
			}
			else if((damageType & DMG_BULLET) && IsRifle(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotRifle, RoundFloat(damage * g_fRateRifle));
			}
			else if((damageType & DMG_BULLET) && IsSniper(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotSniper, RoundFloat(damage * g_fRateSniper));
			}
			else if((damageType & DMG_BULLET) && IsMelee(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else if((damageType & DMG_BULLET) && IsPistol(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotPistol, RoundFloat(damage * g_fRatePistol));
			}
			else if((damageType & (DMG_SLASH|DMG_CLUB)) || IsMelee(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(damage * g_fRateSpecial));
			}
		}
		else if(teamAttacker == 3 && teamVictim == 2)
		{
			if(IsClaw(weapon))
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
			}
			else
			{
				L4D2SF_GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(damage * g_fRateAbility));
			}
		}
	}
	else
	{
		attacker = event.GetInt("attackerentid");
		if(attacker > MaxClients && IsValidEdict(attacker))
		{
			teamAttacker = GetEntProp(attacker, Prop_Data, "m_iTeamNum");
			if(teamAttacker != teamVictim)
			{
				L4D2SF_GiveSkillExperience(victim, g_iSlotSurvival, RoundFloat(damage * g_fRateHurt));
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
		L4D2SF_GiveSkillExperience(attacker, g_iSlotShotgun, RoundFloat(damage * g_fRateShotgun));
	}
	else if((damageType & DMG_BULLET) && IsRifle(classname))
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotRifle, RoundFloat(damage * g_fRateRifle));
	}
	else if((damageType & DMG_BULLET) && IsSniper(classname))
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotSniper, RoundFloat(damage * g_fRateSniper));
	}
	else if((damageType & DMG_BULLET) && IsMelee(classname))
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
	}
	else if((damageType & DMG_BULLET) && IsPistol(classname))
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotPistol, RoundFloat(damage * g_fRatePistol));
	}
	else if((damageType & (DMG_SLASH|DMG_CLUB)) && IsMelee(classname))
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(damage * g_fRateMelee));
	}
	else
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(damage * g_fRateSpecial));
	}
}

public void Event_PillsUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(50 * g_fRateHeal));
}

public void Event_AdrenalineUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(30 * g_fRateHeal));
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
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(health * g_fRateHeal));
	}
	else
	{
		int amount = RoundFloat(health * g_fRateHeal);
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, amount > health ? amount : health);
		L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, amount > health ? health : amount);
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
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, amount > 50 ? amount : 50);
		L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, amount > 50 ? 50 : amount);
	}
	else
	{
		// 这不可能
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(50 * g_fRateHeal));
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
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, amount > 30 ? amount : 30);
		L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, amount > 30 ? 30 : amount);
	}
	else
	{
		// 这不可能
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(30 * g_fRateHeal));
	}
}

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
		L4D2SF_GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 5));
	}
	else if(IsRifle(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 5));
	}
	else if(IsSniper(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else if(IsPistol(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 5));
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
		L4D2SF_GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 5));
	}
	else if(IsRifle(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 5));
	}
	else if(IsSniper(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else if(IsPistol(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 5));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 5));
	}
	else
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 5));
	}
}

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
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(3 * g_fRateHeal));
	}
	else if(award == 68)
	{
		// 给队友递药
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(20 * g_fRateHeal));
		
		if(IsValidClient(subject))
			L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(5 * g_fRateHeal));
	}
	else if(award == 69)
	{
		// 给队友递针
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(15 * g_fRateHeal));
		
		if(IsValidClient(subject))
			L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(5 * g_fRateHeal));
	}
	else if(award == 76)
	{
		// 把队友从特感的控制中救出
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(2 * g_fRateHeal));
	}
	else if(award == 80)
	{
		// 开门复活队友
		L4D2SF_GiveSkillExperience(client, g_iSlotHealing, RoundFloat(10 * g_fRateHeal));
		
		if(IsValidClient(subject))
			L4D2SF_GiveSkillExperience(subject, g_iSlotHealing, RoundFloat(2 * g_fRateHeal));
	}
	else if(award == 81)
	{
		// 克局过后没有死亡
		L4D2SF_GiveSkillExperience(client, g_iSlotSurvival, RoundFloat(10 * g_fRateHeal));
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
		L4D2SF_GiveSkillExperience(client, g_iSlotShotgun, GetRandomInt(1, 10));
	}
	else if(IsRifle(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotRifle, GetRandomInt(1, 10));
	}
	else if(IsSniper(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSniper, GetRandomInt(1, 10));
	}
	else if(IsMelee(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 10));
	}
	else if(IsPistol(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotPistol, GetRandomInt(1, 10));
	}
	else if(IsMelee(classname) || IsClaw(classname))
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotMelee, GetRandomInt(1, 10));
	}
	else
	{
		L4D2SF_GiveSkillExperience(client, g_iSlotSpecial, GetRandomInt(1, 10));
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
		L4D2SF_GiveSkillExperience(attacker, g_iSlotSpecial, RoundFloat(20 * g_fRateSpecial));
	}
	else if(teamAttacker == 3)
	{
		L4D2SF_GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(20 * g_fRateAbility));
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
	
	L4D2SF_GiveSkillExperience(attacker, g_iSlotMelee, RoundFloat(20 * g_fRateMelee));
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
	
	L4D2SF_GiveSkillExperience(attacker, g_iSlotAbility, RoundFloat(30 * g_fRateAbility));
}

public void Event_AbilityUsed(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return;
	
	L4D2SF_GiveSkillExperience(client, g_iSlotAbility, RoundFloat(10 * g_fRateAbility));
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
