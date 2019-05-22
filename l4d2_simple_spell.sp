#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"0.1"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "简单法术",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

Handle g_hTimerGodMode, g_hTimerRevive, g_hTimerUnlimit, g_hTimerGravity, g_hTimerMelee, g_hTimerDucking,
	g_hTimerHelping, g_hTimerHappy, g_hTimerBurn, g_hTimerVomit, g_hTimerPipeBomb, g_hTimerIncap, g_hTimerSelfHelp;

ConVar g_hCvarInfiniteAmmo, g_hCvarReviveHealth, g_hCvarLimpHealth, g_hCvarDuckSpeed, g_hCvarMedicalDuration,
	g_hCvarReviveDuration, g_hCvarShoveRange, g_hCvarMeleeRange, g_hCvarAdrenalineDuration, g_hCvarGodMode,
	g_hCvarDefibrillatorDuration, g_hCvarBurnNormal, g_hCvarBurnHard, g_hCvarBurnExpert, g_hCvarVomitDuration,
	g_hCvarPipeBombDuration, g_hCvarGravity, g_hCvarShoveInterval, g_hCvarBurnEasy, g_pCvarSelfHelp;

public void OnPluginStart()
{
	CreateTimer(1.0, Timer_SetupSpell);
	
	g_hCvarInfiniteAmmo = FindConVar("sv_infinite_primary_ammo");
	g_hCvarReviveHealth = FindConVar("survivor_revive_health");
	g_hCvarLimpHealth = FindConVar("survivor_limp_health");
	g_hCvarDuckSpeed = FindConVar("survivor_crouch_speed");
	g_hCvarMedicalDuration = FindConVar("first_aid_kit_use_duration");
	g_hCvarReviveDuration = FindConVar("survivor_revive_duration");
	g_hCvarShoveRange = FindConVar("z_gun_range");
	g_hCvarMeleeRange = FindConVar("melee_range");
	g_hCvarAdrenalineDuration = FindConVar("adrenaline_duration");
	g_hCvarGodMode = FindConVar("god");
	g_hCvarDefibrillatorDuration = FindConVar("defibrillator_use_duration");
	g_hCvarBurnNormal = FindConVar("survivor_burn_factor_normal");
	g_hCvarBurnHard = FindConVar("survivor_burn_factor_hard");
	g_hCvarBurnExpert = FindConVar("survivor_burn_factor_expert");
	g_hCvarVomitDuration = FindConVar("survivor_it_duration");
	g_hCvarPipeBombDuration = FindConVar("pipe_bomb_timer_duration");
	g_hCvarGravity = FindConVar("sv_gravity");
	g_hCvarShoveInterval = FindConVar("z_gun_swing_interval");
	g_hCvarBurnEasy = FindConVar("survivor_burn_factor_easy");
	
	g_hCvarInfiniteAmmo.Flags &= ~FCVAR_NOTIFY;
	g_hCvarReviveHealth.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimpHealth.Flags &= ~FCVAR_NOTIFY;
	g_hCvarDuckSpeed.Flags &= ~FCVAR_NOTIFY;
	g_hCvarMedicalDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarReviveDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarShoveRange.Flags &= ~FCVAR_NOTIFY;
	g_hCvarMeleeRange.Flags &= ~FCVAR_NOTIFY;
	g_hCvarAdrenalineDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarGodMode.Flags &= ~FCVAR_NOTIFY;
	g_hCvarDefibrillatorDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnNormal.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnHard.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnExpert.Flags &= ~FCVAR_NOTIFY;
	g_hCvarVomitDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarPipeBombDuration.Flags &= ~FCVAR_NOTIFY;
	g_hCvarGravity.Flags &= ~FCVAR_NOTIFY;
	g_hCvarShoveInterval.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnEasy.Flags &= ~FCVAR_NOTIFY;
}

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

public Action Timer_SetupSpell(Handle timer, any data)
{
	SC_CreateSpell("ss_healall", "全体治疗", 250, 6500, "治疗全部队友\ngive health");
	SC_CreateSpell("ss_reviveall", "全体自救", 150, 3500, "救起全部队友\nCTerrorPlayer.ReviveFromIncap");
	SC_CreateSpell("ss_respawnall", "全体复活", 300, 10000, "复活全部死亡的队友\nCTerrorPlayer.ReviveByDefib");
	SC_CreateSpell("ss_adrenalineall", "全体兴奋", 75, 1000, "全部队友进入兴奋状态\nCTerrorPlayer.UseAdrenaline");
	SC_CreateSpell("ss_vomitall", "敌人沾上胆汁", 100, 2000, "全部敌人进入胆汁状态\nCTerrorPlayer.HitWithVomit");
	SC_CreateSpell("ss_staggerall", "震退敌人", 25, 750, "附近敌人进入僵直状态\nCTerrorPlayer.Stagger");
	SC_CreateSpell("ss_killall", "处死敌人", 500, 20000, "对全部敌人造成极高的伤害\nCTerrorPlayer.TakeDamage");
	SC_CreateSpell("ss_killinfected", "处死普感", 350, 13500, "干掉全部普通感染者\nCTerrorPlayer.TakeDamage");
	SC_CreateSpell("ss_godmode", "无敌人类", 255, 10000, "生还者进入无敌状态（不会掉血）\ngod 1");
	SC_CreateSpell("ss_revivefaster", "疾速救援", 164, 2000, "救人瞬间完成");
	SC_CreateSpell("ss_unlimitammo", "无限子弹", 235, 6000, "无限主武器子弹\nsv_infinite_primary_ammo 1");
	SC_CreateSpell("ss_gravity", "重力变异 (重力降低)", 50, 4000);
	SC_CreateSpell("ss_meleeshove", "剑气神托 (近战和推距离加大)", 175, 7000);
	SC_CreateSpell("ss_duckfaster", "蹲坑神速 (蹲下移动加速)", 108, 4500);
	SC_CreateSpell("ss_healfaster", "疾速医疗 (打包和电击加快)", 35, 1500);
	SC_CreateSpell("ss_veryhappy", "极度兴奋 (打针兴奋更长)", 65, 3250);
	SC_CreateSpell("ss_burnimmunity", "防火服 (免疫火烧)", 98, 3250);
	SC_CreateSpell("ss_vomitimmunity", "防化服 (被胆汁时间减少)", 123, 3250);
	SC_CreateSpell("ss_pipebombex", "土雷加强 (土雷吸怪时间更长)", 45, 3250);
	SC_CreateSpell("ss_incaphard", "意志坚定 (救起 100 血/血少不减速)", 168, 3250);
	SC_CreateSpell("ss_teleportto", "传送到队友那里", 64, 1000);
	SC_CreateSpell("ss_teleportfrom", "传送队友到这里", 72, 3000);
	
	if((g_pCvarSelfHelp = FindConVar("self_help_enable")) != null)
	{
		g_pCvarSelfHelp.Flags &= ~FCVAR_NOTIFY;
		SC_CreateSpell("ss_selfhelp", "手动自救", 75, 3000);
	}
	else
		SC_CreateSpell("ss_selfhelp", "被控倒地自救", 155, 6000);
}

public Action SC_OnUseSpellPre(int client, char[] classname, int maxClassname)
{
	if(!StrEqual(classname, "ss_teleportfrom", false))
		return Plugin_Continue;
	
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		PrintToChat(client, "\x03[提示]\x01 请站在地上使用这个功能。");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	if(StrEqual(classname, "ss_healall", false))
		OnSpellUse_HealAll(client);
	else if(StrEqual(classname, "ss_reviveall", false))
		OnSpellUse_ReviveAll(client);
	else if(StrEqual(classname, "ss_respawnall", false))
		OnSpellUse_RespawnAll(client);
	else if(StrEqual(classname, "ss_adrenalineall", false))
		OnSpellUse_AdrenalineAll(client);
	else if(StrEqual(classname, "ss_vomitall", false))
		OnSpellUse_VomitAll(client);
	else if(StrEqual(classname, "ss_staggerall", false))
		OnSpellUse_StaggerAll(client);
	else if(StrEqual(classname, "ss_killall", false))
		OnSpellUse_KillAll(client);
	else if(StrEqual(classname, "ss_killinfected", false))
		OnSpellUse_KillInfected(client);
	else if(StrEqual(classname, "ss_godmode", false))
		OnSpellUse_GodMode(client);
	else if(StrEqual(classname, "ss_revivefaster", false))
		OnSpellUse_ReviveFaster(client);
	else if(StrEqual(classname, "ss_unlimitammo", false))
		OnSpellUse_UnlimitAmmo(client);
	else if(StrEqual(classname, "ss_gravity", false))
		OnSpellUse_LowGravity(client);
	else if(StrEqual(classname, "ss_meleeshove", false))
		OnSpellUse_MeleeRange(client);
	else if(StrEqual(classname, "ss_duckfaster", false))
		OnSpellUse_DuckBoosting(client);
	else if(StrEqual(classname, "ss_healfaster", false))
		OnSpellUse_HealBoosting(client);
	else if(StrEqual(classname, "ss_veryhappy", false))
		OnSpellUse_VeryHappy(client);
	else if(StrEqual(classname, "ss_burnimmunity", false))
		OnSpellUse_ImmunityBurn(client);
	else if(StrEqual(classname, "ss_vomitimmunity", false))
		OnSpellUse_ImmunityVomit(client);
	else if(StrEqual(classname, "ss_pipebombex", false))
		OnSpellUse_ExtraPipeBomb(client);
	else if(StrEqual(classname, "ss_incaphard", false))
		OnSpellUse_ExtraIncap(client);
	else if(StrEqual(classname, "ss_selfhelp", false))
		OnSpellUse_EnableSelfHelp(client);
	else if(StrEqual(classname, "ss_teleportto", false))
		OnSpellUse_TeleportTo(client);
	else if(StrEqual(classname, "ss_teleportfrom", false))
		OnSpellUse_TeleportFrom(client);
	
	// PrintToChat(client, "SC_OnUseSpellPost - %s", classname);
}

void OnSpellUse_HealAll(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != team)
			continue;
		
		CheatCommand(i, "give", "health");
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体治疗");
}

void OnSpellUse_ReviveAll(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != team)
			continue;
		
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(i));
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体自救");
}

void OnSpellUse_RespawnAll(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsPlayerAlive(i) || GetClientTeam(i) != team)
			continue;
		
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).ReviveByDefib()", GetClientUserId(i));
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体复活");
}

void OnSpellUse_AdrenalineAll(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != team)
			continue;
		
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).UseAdrenaline(15.0)", GetClientUserId(i));
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体兴奋");
}

void OnSpellUse_VomitAll(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) == team)
			continue;
		
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).HitWithVomit()", GetClientUserId(i));
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体胆汁");
}

void OnSpellUse_StaggerAll(int client)
{
	float origin[3];
	int team = GetClientTeam(client);
	GetClientAbsOrigin(client, origin);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) == team)
			continue;
		
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).Stagger(Vector(%f,%f,%f))", GetClientUserId(i),
			origin[0], origin[1], origin[2]);
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体僵直");
}

void OnSpellUse_KillAll(int client)
{
	int team = GetClientTeam(client);
	// int uid = GetClientUserId(client);
	int weapon = GetPlayerWeaponSlot(client, 0);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) == team)
			continue;
		
		/*
		CheatCommand(i, "script", "GetPlayerFromUserID(%d).TakeDamage(%d,%d,GetPlayerFromUserID(%d))",
			GetClientUserId(i), 100, DMG_BUCKSHOT, uid);
		*/
		
		SDKHooks_TakeDamage(i, 0, client, 1000.0, DMG_BULLET, weapon);
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体伤害");
}

void OnSpellUse_KillInfected(int client)
{
	int i = -1;
	// int uid = GetClientUserId(client);
	int weapon = GetPlayerWeaponSlot(client, 0);
	while((i = FindEntityByClassname(i, "infected")) != -1)
	{
		/*
		CheatCommand(client, "script", "Ent(%d).TakeDamage(%d,%d,GetPlayerFromUserID(%d))",
			entity, 50, DMG_BUCKSHOT, uid);
		*/
		
		SDKHooks_TakeDamage(i, 0, client, 100.0, DMG_BLAST, weapon);
	}
	
	// PrintToChat(client, "\x04[提示]\x01 你使用了 \x05全体爆炸");
}

void OnSpellUse_GodMode(int client)
{
	// g_hCvarGodMode.Flags |= FCVAR_NOTIFY;
	g_hCvarGodMode.BoolValue = true;
	
	if(g_hTimerGodMode != null)
		KillTimer(g_hTimerGodMode);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 5) + 15.0;
	g_hTimerGodMode = CreateTimer(duration, Timer_ResetConVar_GodMode);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04无敌人类\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_GodMode(Handle timer, any unused)
{
	g_hTimerGodMode = null;
	g_hCvarGodMode.BoolValue = false;
	PrintToChatAll("\x04[提示]\x01 无敌模式关闭。");
	return Plugin_Continue;
}

void OnSpellUse_ReviveFaster(int client)
{
	// g_hCvarReviveDuration.Flags |= FCVAR_NOTIFY;
	g_hCvarReviveDuration.FloatValue = 0.1;
	
	if(g_hTimerRevive != null)
		KillTimer(g_hTimerRevive);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 15) + 20.0;
	g_hTimerRevive = CreateTimer(duration, Timer_ResetConVar_ReviveFaster);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04疾速救援\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_ReviveFaster(Handle timer, any unused)
{
	g_hTimerRevive = null;
	g_hCvarReviveDuration.FloatValue = 5.0;
	PrintToChatAll("\x04[提示]\x01 快速救人关闭。");
	return Plugin_Continue;
}

void OnSpellUse_UnlimitAmmo(int client)
{
	// g_hCvarInfiniteAmmo.Flags |= FCVAR_NOTIFY;
	g_hCvarInfiniteAmmo.BoolValue = true;
	
	if(g_hTimerUnlimit != null)
		KillTimer(g_hTimerUnlimit);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 10) + 20.0;
	g_hTimerUnlimit = CreateTimer(duration, Timer_ResetConVar_UnlimitAmmo);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04无限子弹\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_UnlimitAmmo(Handle timer, any unused)
{
	g_hTimerUnlimit = null;
	g_hCvarInfiniteAmmo.BoolValue = false;
	PrintToChatAll("\x04[提示]\x01 无限子弹关闭。");
	return Plugin_Continue;
}

void OnSpellUse_LowGravity(int client)
{
	// g_hCvarGravity.Flags |= FCVAR_NOTIFY;
	g_hCvarGravity.IntValue = 200;
	
	if(g_hTimerGravity != null)
		KillTimer(g_hTimerGravity);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 9) + 20.0;
	g_hTimerGravity = CreateTimer(duration, Timer_ResetConVar_LowGravity);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04重力变异\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_LowGravity(Handle timer, any unused)
{
	g_hTimerGravity = null;
	g_hCvarGravity.IntValue = 800;
	PrintToChatAll("\x04[提示]\x01 减少重力关闭。");
	return Plugin_Continue;
}

void OnSpellUse_MeleeRange(int client)
{
	// g_hCvarMeleeRange.Flags |= FCVAR_NOTIFY;
	// g_hCvarShoveRange.Flags |= FCVAR_NOTIFY;
	// g_hCvarShoveInterval.Flags |= FCVAR_NOTIFY;
	g_hCvarMeleeRange.IntValue = 250;
	g_hCvarShoveRange.IntValue = 300;
	g_hCvarShoveInterval.FloatValue = 0.3;
	
	if(g_hTimerMelee != null)
		KillTimer(g_hTimerMelee);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 6) + 20.0;
	g_hTimerMelee = CreateTimer(duration, Timer_ResetConVar_MeleeRange);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04剑气神托\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_MeleeRange(Handle timer, any unused)
{
	g_hTimerMelee = null;
	g_hCvarMeleeRange.IntValue = 70;
	g_hCvarShoveRange.IntValue = 75;
	g_hCvarShoveInterval.FloatValue = 0.7;
	PrintToChatAll("\x04[提示]\x01 近战/推 范围增加关闭。");
	return Plugin_Continue;
}

void OnSpellUse_DuckBoosting(int client)
{
	// g_hCvarDuckSpeed.Flags |= FCVAR_NOTIFY;
	g_hCvarDuckSpeed.IntValue = 300;
	
	if(g_hTimerDucking != null)
		KillTimer(g_hTimerDucking);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 20) + 20.0;
	g_hTimerDucking = CreateTimer(duration, Timer_ResetConVar_DuckBoosting);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04蹲坑神速\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_DuckBoosting(Handle timer, any unused)
{
	g_hTimerDucking = null;
	g_hCvarDuckSpeed.IntValue = 75;
	PrintToChatAll("\x04[提示]\x01 蹲下移动加速关闭。");
	return Plugin_Continue;
}

void OnSpellUse_HealBoosting(int client)
{
	// g_hCvarMedicalDuration.Flags |= FCVAR_NOTIFY;
	// g_hCvarDefibrillatorDuration.Flags |= FCVAR_NOTIFY;
	g_hCvarMedicalDuration.IntValue = 1;
	g_hCvarDefibrillatorDuration.IntValue = 1;
	
	if(g_hTimerHelping != null)
		KillTimer(g_hTimerHelping);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 20) + 25.0;
	g_hTimerHelping = CreateTimer(duration, Timer_ResetConVar_HealBoosting);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04疾速医疗\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_HealBoosting(Handle timer, any unused)
{
	g_hTimerHelping = null;
	g_hCvarMedicalDuration.IntValue = 5;
	g_hCvarDefibrillatorDuration.IntValue = 3;
	PrintToChatAll("\x04[提示]\x01 治疗加速关闭。");
	return Plugin_Continue;
}

void OnSpellUse_VeryHappy(int client)
{
	// g_hCvarAdrenalineDuration.Flags |= FCVAR_NOTIFY;
	g_hCvarAdrenalineDuration.IntValue = 30;
	
	if(g_hTimerHappy != null)
		KillTimer(g_hTimerHappy);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 20) + 10.0;
	g_hTimerHappy = CreateTimer(duration, Timer_ResetConVar_VeryHappy);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04极度兴奋\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_VeryHappy(Handle timer, any unused)
{
	g_hTimerHappy = null;
	g_hCvarAdrenalineDuration.IntValue = 15;
	PrintToChatAll("\x04[提示]\x01 打针更长关闭。");
	return Plugin_Continue;
}

void OnSpellUse_ImmunityBurn(int client)
{
	// g_hCvarBurnExpert.Flags |= FCVAR_NOTIFY;
	// g_hCvarBurnHard.Flags |= FCVAR_NOTIFY;
	// g_hCvarBurnNormal.Flags |= FCVAR_NOTIFY;
	g_hCvarBurnExpert.IntValue = 0;
	g_hCvarBurnHard.IntValue = 0;
	g_hCvarBurnNormal.IntValue = 0;
	g_hCvarBurnEasy.IntValue = 0;
	
	if(g_hTimerBurn != null)
		KillTimer(g_hTimerBurn);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 25) + 10.0;
	g_hTimerBurn = CreateTimer(duration, Timer_ResetConVar_ImmunityBurn);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04防火服\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_ImmunityBurn(Handle timer, any unused)
{
	g_hTimerBurn = null;
	g_hCvarBurnExpert.FloatValue = 1.0;
	g_hCvarBurnHard.FloatValue = 0.4;
	g_hCvarBurnNormal.FloatValue = 0.2;
	g_hCvarBurnEasy.FloatValue = 0.2;
	PrintToChatAll("\x04[提示]\x01 免疫火焰关闭。");
	return Plugin_Continue;
}

void OnSpellUse_ImmunityVomit(int client)
{
	// g_hCvarVomitDuration.Flags |= FCVAR_NOTIFY;
	g_hCvarVomitDuration.IntValue = 10;
	
	if(g_hTimerVomit != null)
		KillTimer(g_hTimerVomit);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 6) + 10.0;
	g_hTimerVomit = CreateTimer(duration, Timer_ResetConVar_ImmunityVomit);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04防化服\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_ImmunityVomit(Handle timer, any unused)
{
	g_hTimerVomit = null;
	g_hCvarVomitDuration.IntValue = 20;
	PrintToChatAll("\x04[提示]\x01 胆汁减少关闭。");
	return Plugin_Continue;
}

void OnSpellUse_ExtraPipeBomb(int client)
{
	// g_hCvarPipeBombDuration.Flags |= FCVAR_NOTIFY;
	g_hCvarPipeBombDuration.IntValue = 15;
	
	if(g_hTimerPipeBomb != null)
		KillTimer(g_hTimerPipeBomb);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 8) + 10.0;
	g_hTimerPipeBomb = CreateTimer(duration, Timer_ResetConVar_ExtraPipeBomb);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04土雷加强\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_ExtraPipeBomb(Handle timer, any unused)
{
	g_hTimerPipeBomb = null;
	g_hCvarPipeBombDuration.IntValue = 6;
	PrintToChatAll("\x04[提示]\x01 土雷加长关闭。");
	return Plugin_Continue;
}

void OnSpellUse_ExtraIncap(int client)
{
	// g_hCvarLimpHealth.Flags |= FCVAR_NOTIFY;
	// g_hCvarReviveHealth.Flags |= FCVAR_NOTIFY;
	g_hCvarLimpHealth.IntValue = 0;
	g_hCvarReviveHealth.IntValue = 100;
	
	if(g_hTimerIncap != null)
		KillTimer(g_hTimerIncap);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 21) + 10.0;
	g_hTimerIncap = CreateTimer(duration, Timer_ResetConVar_ExtraPipeBomb);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04意志坚定\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_ExtraIncap(Handle timer, any unused)
{
	g_hTimerIncap = null;
	g_hCvarLimpHealth.IntValue = 40;
	g_hCvarReviveHealth.IntValue = 30;
	PrintToChatAll("\x04[提示]\x01 救起更多血/不会减速 关闭。");
	return Plugin_Continue;
}

void OnSpellUse_EnableSelfHelp(int client)
{
	if(g_pCvarSelfHelp != null)
		g_pCvarSelfHelp.BoolValue = true;
	else
		CheatCommand(client, "script", "SessionOptions.cm_AutoReviveFromSpecialIncap<-1");
	
	if(g_hTimerSelfHelp != null)
		KillTimer(g_hTimerSelfHelp);
	
	float duration = ((SC_GetClientLevel(client) + 1) * 22) + 10.0;
	g_hTimerSelfHelp = CreateTimer(duration, Timer_ResetConVar_SelfHelp);
	
	PrintToChat(client, "\x04[提示]\x01 你使用了 \x04自救\x01 持续 \x05%.0f\x01秒。", duration);
}

public Action Timer_ResetConVar_SelfHelp(Handle timer, any unused)
{
	g_hTimerSelfHelp = null;
	
	if(g_pCvarSelfHelp != null)
		g_pCvarSelfHelp.BoolValue = false;
	else
		CheatCommand(-1, "script", "SessionOptions.cm_AutoReviveFromSpecialIncap<-0");
	
	PrintToChatAll("\x04[提示]\x01 自救 关闭。");
	return Plugin_Continue;
}

void OnSpellUse_TeleportTo(int client)
{
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != team || client == i)
			continue;
		
		/*
		if(!(GetEntityFlags(i) & FL_ONGROUND))
			continue;
		*/
		
		float origin[3];
		GetClientAbsOrigin(i, origin);
		TeleportEntity(client, origin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		return;
	}
	
	PrintToChat(client, "\x03[提示]\x01 没有可传送的队友。");
}

void OnSpellUse_TeleportFrom(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != team || client == i)
			continue;
		
		/*
		if(!(GetEntityFlags(i) & FL_ONGROUND))
			continue;
		*/
		
		TeleportEntity(i, origin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	}
}

void CheatCommand(int client, const char[] command, const char[] buffer = "", any ...)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	
	char args[255];
	VFormat(args, 255, tr("%s \"%s\"", command, buffer), 4);
	
	if(IsValidClient(client))
		FakeClientCommand(client, args);
	else
		ServerCommand(args);
	
	SetCommandFlags(command, flags);
}

stock char tr(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);
	return buffer;
}
