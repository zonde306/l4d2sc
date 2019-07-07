#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define _USE_PLUGIN_MAX_HEALTH_		// 使用当前插件定义的血量上限代替 m_iMaxHealth 作为标准
// #define _USE_CONSOLE_MESSAGE_	// 当玩家获得奖励时打印控制台信息
// #define _USE_DATABASE_SQLITE_		// 使用 SQLite 储存数据
#define _USE_DATABASE_MYSQL_		// 使用 MySQL 储存数据

// CNMRiH_Player::GetGrabbedBy(this)		获取正在抓住玩家的僵尸
#define SIG_GET_GRABBED_BY			"_ZN13CNMRiH_Player12GetGrabbedByEv"

// CNMRiH_Player::BecomeInfected(this)		// 让玩家进入感染状态
#define SIG_BECOME_INFECTED			"_ZN13CNMRiH_Player14BecomeInfectedEv"

// CNMRiH_Player::CureInfection(this)		// 治疗感染的玩家
#define SIG_CURE_INFECTED			"_ZN13CNMRiH_Player13CureInfectionEv"

// CNMRiH_Player::BleedOut(this)			// 让玩家进入出血状态
#define SIG_START_BLEEDOUT			"_ZN13CNMRiH_Player8BleedOutEv"

// CNMRiH_Player::StopBleedingOut(this)		// 治疗出血的玩家
#define SIG_STOP_BLEEDOUT			"_ZN13CNMRiH_Player15StopBleedingOutEv"

// TODO: 创建表
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
#include <geoip>
#include <geoipcity>

#define _SQL_CONNECT_HOST_		"zonde306.site"
#define _SQL_CONNECT_PORT_		"3306"
#define _SQL_CONNECT_DATABASE_	"source_game"
#define _SQL_CONNECT_USER_		"abby"
#define _SQL_CONNECT_PASSWORD_	"author6382"
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_

#define PLUGIN_VERSION	"0.1"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "简单战斗系统",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

ArrayList g_hPlayerSpell[MAXPLAYERS+1], g_hAllSpellList, g_hSellSpellList;
ArrayList g_hMenuItemInfo, g_hMenuItemDisplay;

bool g_bDefenseFriendly, g_bDamageFriendly, g_bSprintAllow, g_bJumpAllow;

// float g_fCombatRadius;
float g_fCombatDelay, g_fDefenseChance, g_fDefenseFactor, g_fDamageChance, g_fDamageFactor, g_fThinkInterval,
	g_fSprintWalk, g_fSprintDuck, g_fSprintWater, g_fJumpHeight, g_fStandingDelay, g_fStandingFactor,
	g_fDifficultyFactor, g_fCombatStamina, g_fSafeStamina, g_fCombatMagic, g_fSafeMagic, g_fBlockRevive;

int g_iDefenseLimit, g_iDamageLimit, g_iSprintLimit, g_iSprintPerSecond, g_iJumpLimit, g_iJumpConsume,
	g_iStandingLimit, g_iDamageMin, g_iDefenseMin;

/*
float g_fDefaultSpeed[10];
ConVar g_hCvarSurvivorSpeed, g_hCvarDuckSpeed, g_hCvarSmokerSpeed, g_hCvarBoomerSpeed, g_hCvarHunterSpeed,
	g_hCvarSpitterSpeed, g_hCvarJockeySpeed, g_hCvarChargerSpeed, g_hCvarTankSpeed, g_hCvarAdrenSpeed;
*/

ConVar g_hCvarDifficulty;

// ConVar g_pCvarCombatRadius;
ConVar g_pCvarAllow, g_pCvarDefenseFactor, g_pCvarDefenseChance, g_pCvarDefenseLimit,
	g_pCvarStaminaRate, g_pCvarStaminaIdleRate, g_pCvarMagicRate, g_pCvarMagicIdleRate,
	g_pCvarCombatDelay, g_pCvarDamageFactor, g_pCvarDamageChance, g_pCvarDamageLimit,
	g_pCvarDefenseFriendly, g_pCvarDamageFriendly, g_pCvarLevelExperience, g_pCvarLevelPoint,
	g_pCvarPointAmount, g_pCvarSprintLimit, g_pCvarSprintSpeed, g_pCvarSprintDuckSpeed,
	g_pCvarSprintWaterSpeed, g_pCvarSprintConsume, g_pCvarSprintAllow, g_pCvarJumpAllow,
	g_pCvarJumpHeight, g_pCvarJumpLimit, g_pCvarJumpConsume, g_pCvarShopCount, g_pCvarDifficulty,
	g_pCvarStandingDelay, g_pCvarStandingRate, g_pCvarStandingLimit, g_pCvarThinkInterval,
	g_pCvarDamageMin, g_pCvarDefenseMin, g_pCvarBlockRevive;

// 玩家属性
float g_fStamina[MAXPLAYERS+1], g_fMagic[MAXPLAYERS+1];
int g_iMaxStamina[MAXPLAYERS+1], g_iMaxMagic[MAXPLAYERS+1], g_iMaxHealth[MAXPLAYERS+1], g_iMaxWeight[MAXPLAYERS+1];
int g_iExperience[MAXPLAYERS+1], g_iLevel[MAXPLAYERS+1], g_iNextLevel[MAXPLAYERS+1], g_iSkillPoint[MAXPLAYERS+1],
	g_iAccount[MAXPLAYERS+1];

// 玩家状态
Handle g_hTimerCombatEnd[MAXPLAYERS+1];
bool g_bInBattle[MAXPLAYERS+1], g_bInSprint[MAXPLAYERS+1], g_bInJumping[MAXPLAYERS+1];
float g_fSprintSpeed[MAXPLAYERS+1], g_fNextStandingTime[MAXPLAYERS+1];

// 存档数据
KeyValues g_kvSaveData[MAXPLAYERS+1];
char g_szSaveDataPath[260];

// 击杀统计
int g_iZombieKilled[MAXPLAYERS+1], g_iZombieFired[MAXPLAYERS+1], g_iZombieHeadshot[MAXPLAYERS+1];

// 偏移地址
int g_iOffsetVelocity = -1;

// 中断恢复检查
float g_fNextReviveTime[MAXPLAYERS+1] = {0.0, ...};

#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
// 数据库
Database g_hDatabase = null;

// 玩家的 uid
int g_iClientUserId[MAXPLAYERS+1];

#endif

ConVar g_pCvarKillExperience, g_pCvarKillCash, g_pCvarFiredExperience, g_pCvarFiredCash,
	g_pCvarHeadshotExperience, g_pCvarHeadshotCash, g_pCvarWaveExperience, g_pCvarWaveCash,
	g_pCvarEscapeExperience, g_pCvarEscapeCash, g_pCvarObjectiveExperience, g_pCvarObjectiveCash,
	g_pCvarSafeHealExperience, g_pCvarSafeHealCash, g_pCvarPasswordExperience, g_pCvarPasswordCash,
	g_pCvarProtectExperience, g_pCvarProtectCash, g_pCvarRescueExperience, g_pCvarRescueCash;

#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	ConVar g_pCvarCoinAlive, g_pCvarCoinDead;
	int g_iCoinAlive, g_iCoinDead;
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_

// 最小触发几率
const float MIN_TRIGGER_CHANCE = 0.0001;

public void OnPluginStart()
{
	CreateConVar("sc_version", PLUGIN_VERSION, "插件版本", CVAR_FLAGS);
	g_pCvarAllow = CreateConVar("sc_allow", "0", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	// g_pCvarCombatRadius = CreateConVar("sc_combat_raduis", "300.0", "在多大范围内有敌人视为战斗状态", CVAR_FLAGS, true, 10.0);
	g_pCvarCombatDelay = CreateConVar("sc_combat_leave_delay", "3.0", "离开战斗状态的延迟", CVAR_FLAGS, true, 0.1);
	
	g_pCvarStaminaRate = CreateConVar("sc_stamina_combat_rate", "0.035", "战斗时每秒恢复耐力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStaminaIdleRate = CreateConVar("sc_stamina_safe_rate", "0.1", "非战斗时每秒恢复耐力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	g_pCvarMagicRate = CreateConVar("sc_magic_combat_rate", "0.05", "战斗时每秒恢复魔力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarMagicIdleRate = CreateConVar("sc_magic_safe_rate", "0.1", "非战斗时每秒恢复魔力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	g_pCvarDefenseChance = CreateConVar("sc_default_defense_chance", "1.0", "耐力抵挡伤害触发几率（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseLimit = CreateConVar("sc_stamina_defense_limit", "25.0", "耐力至少有多少才能触发抵挡伤害", CVAR_FLAGS, true, 0.0);
	g_pCvarDefenseFactor = CreateConVar("sc_stamina_defense_factor", "0.5", "耐力抵挡伤害的百分比（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseFriendly = CreateConVar("sc_stamina_defense_friendly", "1", "耐力抵挡伤害是否支持队友伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseMin = CreateConVar("sc_stamina_defense_min", "4", "耐力抵挡触发所需最小伤害", CVAR_FLAGS, true, 0.0);
	
	g_pCvarDamageChance = CreateConVar("sc_stamina_damage_chance", "1.0", "耐力增加伤害触发几率（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDamageLimit = CreateConVar("sc_stamina_damage_limit", "50.0", "耐力至少有多少才能触发增加伤害", CVAR_FLAGS, true, 0.0);
	g_pCvarDamageFactor = CreateConVar("sc_stamina_damage_factor", "1.0", "耐力增加伤害的百分比（1.0=100％）", CVAR_FLAGS, true, 0.0);
	g_pCvarDamageFriendly = CreateConVar("sc_stamina_damage_friendly", "0", "耐力增加伤害是否支持队友伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDamageMin = CreateConVar("sc_stamina_damage_min", "10", "耐力增加伤害触发所需最小伤害", CVAR_FLAGS, true, 0.0);
	
	g_pCvarSprintAllow = CreateConVar("sc_sprint_allow", "0", "是否开启冲刺功能", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSprintLimit = CreateConVar("sc_sprint_limit", "10", "耐力必须大于多少才能冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintConsume = CreateConVar("sc_sprint_consume", "20", "冲刺每秒消耗多少耐力", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintSpeed = CreateConVar("sc_sprint_speed", "1.5", "站立时冲刺速度倍数（1.0=100％）.0=禁止站立冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintDuckSpeed = CreateConVar("sc_sprint_duck_speed", "0", "蹲下时冲刺速度倍数(基于蹲下移动速度).0=禁止蹲下冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintWaterSpeed = CreateConVar("sc_sprint_water_speed", "0", "水中时冲刺速度倍数(基于水中移动速度).0=禁止水中冲刺", CVAR_FLAGS, true, 0.0);
	
	g_pCvarJumpAllow = CreateConVar("sc_jump_allow", "1", "是否开启冲刺跳跃功能", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarJumpLimit = CreateConVar("sc_jump_limit", "30.0", "耐力必须大于多少才能冲刺跳跃", CVAR_FLAGS, true, 0.0);
	g_pCvarJumpConsume = CreateConVar("sc_jump_consume", "25.0", "冲刺跳跃消耗多少耐力", CVAR_FLAGS, true, 0.0);
	g_pCvarJumpHeight = CreateConVar("sc_jump_height", "100.0", "冲刺跳跃获得的高度", CVAR_FLAGS, true, 0.0);
	
	g_pCvarStandingDelay = CreateConVar("sc_standing_delay", "3.0", "站立不动多长时间(秒)自动回血", CVAR_FLAGS, true, 0.0);
	g_pCvarStandingRate = CreateConVar("sc_standing_factor", "0.1", "站立回血百分比(魔力上限)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStandingLimit = CreateConVar("sc_standing_limit", "10.0", "魔力至少需要多少才会启动回血", CVAR_FLAGS, true, 0.0);
	
	g_pCvarLevelExperience = CreateConVar("sc_level_experience", "306", "每升一级需要多少经验值", CVAR_FLAGS, true, 1.0);
	g_pCvarLevelPoint = CreateConVar("sc_level_point", "1", "每升一级获得多少技能点", CVAR_FLAGS, true, 0.0);
	g_pCvarPointAmount = CreateConVar("sc_point_amount", "10", "每一个技能点可以增加多少上限", CVAR_FLAGS, true, 0.0);
	g_pCvarShopCount = CreateConVar("sc_shop_count", "5", "商店出售法术数量", CVAR_FLAGS, true, 0.0);
	g_pCvarThinkInterval = CreateConVar("sc_think_interval", "1.0", "菜单和奖励思考间隔。\n较小的值可以提升精度，但是会占用更多的 CPU", CVAR_FLAGS, true, 0.01, true, 9.0);
	g_pCvarDifficulty = CreateConVar("sc_bouns_difficulty", "0.5", "根据难度进行奖励加成百分比(简单=当前数值.普通=当前×2.困难=当前×2.25.专家=当前×2.5)", CVAR_FLAGS, true, MIN_TRIGGER_CHANCE);
	g_pCvarBlockRevive = CreateConVar("sc_block_by_hurt", "3", "被攻击后中断多少秒回复耐力和魔力", CVAR_FLAGS, true, 0.0);
	
	g_pCvarKillExperience = CreateConVar("sc_exp_killed", "3", "击杀僵尸 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarFiredExperience = CreateConVar("sc_exp_burn", "2", "烧死僵尸 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHeadshotExperience = CreateConVar("sc_exp_headshot", "2", "爆头僵尸 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarWaveExperience = CreateConVar("sc_exp_wave", "100", "成功守住一波尸潮 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarEscapeExperience = CreateConVar("sc_exp_escape", "500", "逃脱成功 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarObjectiveExperience = CreateConVar("sc_exp_objective", "15", "完成一次任务 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarSafeHealExperience = CreateConVar("sc_exp_healing", "5", "修复安全区 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPasswordExperience = CreateConVar("sc_exp_password", "20", "输入密码 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarProtectExperience = CreateConVar("sc_exp_protect", "30", "救出被控队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRescueExperience = CreateConVar("sc_exp_rescue", "32", "开门复活队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	
	g_pCvarKillCash = CreateConVar("sc_cash_killed", "3", "击杀僵尸 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarFiredCash = CreateConVar("sc_cash_burn", "2", "烧死僵尸 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarHeadshotCash = CreateConVar("sc_cash_headshot", "2", "爆头僵尸 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarWaveCash = CreateConVar("sc_cash_wave", "100", "成功守住一波尸潮 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarEscapeCash = CreateConVar("sc_cash_escape", "500", "逃脱成功 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarObjectiveCash = CreateConVar("sc_cash_objective", "15", "完成一次任务 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarSafeHealCash = CreateConVar("sc_cash_healing", "5", "修复安全区 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPasswordCash = CreateConVar("sc_cash_password", "20", "输入密码 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarProtectCash = CreateConVar("sc_cash_protect", "30", "救出被控队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRescueCash = CreateConVar("sc_cash_rescue", "32", "开门复活队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	g_pCvarCoinAlive = CreateConVar("sc_coin_alive", "2", "活着每秒获得多少硬币", CVAR_FLAGS, true, 0.0);
	g_pCvarCoinDead = CreateConVar("sc_coin_dead", "1", "死亡每秒获得多少硬币", CVAR_FLAGS, true, 0.0);
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	
	AutoExecConfig(true, "nmp_smiple_combat");
	BuildPath(Path_SM, g_szSaveDataPath, 260, "data/nmrih_simple_combat");
	
	RegConsoleCmd("sc", Cmd_MainMenu);
	RegConsoleCmd("lv", Cmd_MainMenu);
	// RegConsoleCmd("rpg", Cmd_MainMenu);
	RegConsoleCmd("spell", Cmd_SpellMenu);
	RegConsoleCmd("skill", Cmd_SpellMenu);
	RegConsoleCmd("attr", Cmd_AttributesMenu);
	RegConsoleCmd("attributes", Cmd_AttributesMenu);
	RegConsoleCmd("buyspell", Cmd_BuySpellMenu);
	RegConsoleCmd("buyskill", Cmd_BuySpellMenu);
	
	RegAdminCmd("fullall", Cmd_DebugFullAll, ADMFLAG_CHEATS);
	RegAdminCmd("giveexp", Cmd_DebugGiveExperience, ADMFLAG_CHEATS);
	RegAdminCmd("givecash", Cmd_DebugGiveCash, ADMFLAG_CHEATS);
	
	/*
	g_hCvarSurvivorSpeed = FindConVar("survivor_speed");
	g_hCvarDuckSpeed = FindConVar("survivor_crouch_speed");
	g_hCvarSmokerSpeed = FindConVar("z_gas_speed");
	g_hCvarBoomerSpeed = FindConVar("z_exploding_speed");
	g_hCvarHunterSpeed = FindConVar("z_hunter_speed");
	g_hCvarSpitterSpeed = FindConVar("z_spitter_speed");
	g_hCvarJockeySpeed = FindConVar("z_jockey_speed");
	g_hCvarChargerSpeed = FindConVar("z_charge_start_speed");
	g_hCvarTankSpeed = FindConVar("z_tank_speed");
	g_hCvarAdrenSpeed = FindConVar("adrenaline_run_speed");
	HookConVarChange(g_hCvarSurvivorSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarDuckSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarSmokerSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarBoomerSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarHunterSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarJockeySpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarChargerSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarTankSpeed, ConVarHook_OnSpeedChanged);
	HookConVarChange(g_hCvarAdrenSpeed, ConVarHook_OnSpeedChanged);
	ConVarHook_OnSpeedChanged(null, "", "");
	*/
	
	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_fDifficultyFactor = g_pCvarDifficulty.FloatValue;
	HookConVarChange(g_hCvarDifficulty, ConVarHook_OnDifficultyChanged);
	
	ConVarHook_OnValueChanged(null, "", "");
	// HookConVarChange(g_pCvarCombatRadius, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarCombatDelay, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarStaminaRate, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarStaminaIdleRate, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarMagicRate, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarMagicIdleRate, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarStandingDelay, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarJumpAllow, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarSprintAllow, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarSprintConsume, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarSprintSpeed, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarThinkInterval, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarDefenseMin, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarDamageMin, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarBlockRevive, ConVarHook_OnValueChanged);
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	HookConVarChange(g_pCvarCoinAlive, ConVarHook_OnValueChanged);
	HookConVarChange(g_pCvarCoinDead, ConVarHook_OnValueChanged);
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	
	// 这个明面上是 float 类型，但实际是 Vector 类型的
	// 使用这个可以避免 GetEntPropFloat 的类型检查
	g_iOffsetVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	HookEvent("nmrih_round_begin", Event_RoundStart);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("game_round_restart", Event_RoundStart);
	HookEvent("game_win", Event_RoundEnd);
	HookEvent("wave_complete", Event_RoundEnd);
	HookEvent("state_change", Event_StageChanged);
	HookEvent("game_win", Event_RoundWin);
	HookEvent("wave_complete", Event_SurvivalWaveComplete);
	HookEvent("keycode_enter", Event_PasswordEnter);
	HookEvent("player_extracted", Event_PlayerEscape);
	HookEvent("objective_complete", Event_MissionComplete);
	HookEvent("player_changename", Event_PlayerChangeName);
	HookEvent("player_active", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	// 并没有什么效果
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_jump_apex", Event_PlayerJump);
	
	// 奖励获得
	HookEvent("npc_killed", Event_ZombieKilled);
	HookEvent("zombie_killed", Event_ZombieDeath);
	HookEvent("zombie_killed_by_fire", Event_ZombieDeathFire);
	HookEvent("zombie_head_split", Event_ZombieHeadShot);
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_SQLITE_
	CreateTimer(1.0, Timer_ConnectDatabase);
#endif
}

// 回血声音
#define SOUND_STANDING_HEAL		"ui/beep07.wav"

public void OnMapStart()
{
	PrecacheSound(SOUND_STANDING_HEAL, true);
}

#define IsValidClient(%1)				(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)			(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))
#define IsPlayerIncapacitated(%1)		(GetEntProp(%1, Prop_Send, "m_isIncapacitated", 1) != 0)
#define IsPlayerHanging(%1)				(GetEntProp(%1, Prop_Send, "m_isHangingFromLedge", 1) != 0)
#define IsPlayerFalling(%1)				(GetEntProp(%1, Prop_Send, "m_isFallingFromLedge", 1) != 0)
#define IsPlayerGhost(%1)				(GetEntProp(%1, Prop_Send, "m_isGhost", 1) != 0)

// 属性相关的 forward
Handle g_fwStaminaIncreasePre, g_fwStaminaDecreasePre, g_fwMagicIncreasePre, g_fwMagicDecreasePre,
	g_fwStaminaIncreasePost, g_fwStaminaDecreasePost, g_fwMagicIncreasePost, g_fwMagicDecreasePost,
	g_fwOnLevelUpPre, g_fwOnLevelUpPost, g_fwOnGainExperiencePre, g_fwOnGainExperiencePost,
	g_fwOnGainCashPre, g_fwOnGainCashPost;

// 战斗相关的 forward
Handle g_fwOnStartCombatPre, g_fwOnStartCombatPost, g_fwOnLeaveCombatPre, g_fwOnLeaveCombatPost;

// 菜单 forward
Handle g_fwOnMenuItemClickPre, g_fwOnMenuItemClickPost;

// 法术相关 forward
Handle g_fwOnUseSpellPre, g_fwOnUseSpellPost, g_fwOnGainSpellPre, g_fwOnGainSpellPost;

#define DECL_MENU_CALL_PRE(%1)		Menu refMenu = menu;\
	Action result = Plugin_Continue;\
	Call_StartForward(%1);\
	Call_PushCell(client);\
	Call_PushCellRef(refMenu):\
	Call_Finish(result);\
	if(result == Plugin_Changed)\
		menu = refMenu;\
	else if(result == Plugin_Handled)\
		return Plugin_Handled

#define DECL_MENU_CALL_POST(%1)		Call_StartForward(%1);\
	Call_PushCell(client);\
	Call_PushCell(menu):\
	Call_Finish()

int g_iPlayerMenu[MAXPLAYERS+1];

public Action Cmd_MainMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Menu m = CreateMenu(MenuHandler_MainMenu);
	
	m.SetTitle(tr(
		"========= 主菜单 =========\n等级：%d丨经验：%d/%d丨金钱：%d丨技能点：%d\n体力：%.0f/%d丨生命上限：%d丨能量：%.0f/%d",
		g_iLevel[client], g_iExperience[client], g_iNextLevel[client], g_iAccount[client], g_iSkillPoint[client],
		g_fStamina[client], g_iMaxStamina[client], g_iMaxHealth[client], g_fMagic[client], g_iMaxMagic[client]));
	
	m.AddItem("use_spell", tr("使用法术（%d）", g_hPlayerSpell[client].Length));
	m.AddItem("attributes", tr("属性查看（%d）", g_iSkillPoint[client]));
	m.AddItem("buy_spell", tr("购买法术（%d）", g_hSellSpellList.Length));
	
	char info[64], display[128];
	int length = g_hMenuItemInfo.Length;
	for(int i = 0; i < length; ++i)
	{
		g_hMenuItemInfo.GetString(i, info, 64);
		g_hMenuItemDisplay.GetString(i, display, 64);
		m.AddItem(info, display);
	}
	
	m.ExitButton = true;
	m.ExitBackButton = false;
	m.Display(client, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 1;
	
	return Plugin_Continue;
}

public Action Cmd_AttributesMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Panel m = CreatePanel();
	m.SetTitle("========= 属性面板 =========");
	m.DrawText(tr("属性点：%d丨等级：%d", g_iSkillPoint[client], g_iLevel[client]));
	
	m.DrawItem(tr("耐力（%.0f/%d）", g_fStamina[client], g_iMaxStamina[client]));
	m.DrawText("耐力可以用于抵挡伤害，增加攻击力和冲刺。");
	
	m.DrawItem(tr("生命（%d）", g_iMaxHealth[client]));
	m.DrawText("生命值上限，让你的血条更长。");
	
	m.DrawItem(tr("能量（%.0f/%d）", g_fMagic[client], g_iMaxMagic[client]));
	m.DrawText("能量用于使用各类法术。");
	m.DrawText("使用法术可以获得经验值。");
	
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("返回 (Back)", ITEMDRAW_CONTROL);
	m.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	
	m.Send(client, MenuHandler_AttributesMenu, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 2;
	
	return Plugin_Continue;
}

public Action Cmd_SpellMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	if(g_hPlayerSpell[client] == null || g_hPlayerSpell[client].Length <= 0)
	{
		PrintToChat(client, "\x03[提示]\x01 你没有任何法术。");
		g_iPlayerMenu[client] = 0;
		return Plugin_Continue;
	}
	
	Menu m = CreateMenu(MenuHandler_SpellMenu);
	m.SetTitle(tr("========= 法术菜单 =========\n能量：%.0f/%d丨等级：%d",
		g_fMagic[client], g_iMaxMagic[client], g_iLevel[client]));
	
	int consume = -1, i = 0;
	char classname[64], display[128];
	int length = g_hPlayerSpell[client].Length;
	
	for(i = 0; i < length; ++i)
	{
		StringMap spell = g_hPlayerSpell[client].Get(i);
		if(spell == null || !spell.GetString("display", display, 128) || !spell.GetValue("consume", consume))
		{
			g_hPlayerSpell[client].Erase(i--);
			PrintToServer("法术 %s 已失效，将会被删除。", classname);
			continue;
		}
		
		IntToString(view_as<int>(spell), classname, 64);
		m.AddItem(classname, tr("%s [%d]", display, consume));
	}
	
	m.ExitBackButton = true;
	m.ExitButton = true;
	m.Display(client, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 3;
	
	return Plugin_Continue;
}

public Action Cmd_BuySpellMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	if(g_hSellSpellList == null || g_hSellSpellList.Length <= 0)
	{
		PrintToChat(client, "\x03[提示]\x01 目前没有任何可以出售的法术。");
		g_iPlayerMenu[client] = 0;
		return Plugin_Continue;
	}
	
	Menu m = CreateMenu(MenuHandler_BuySpellMenu);
	m.SetTitle(tr("========= 法术购买菜单 =========\n能量：%.0f/%d丨等级：%d丨金钱：%d",
		g_fMagic[client], g_iMaxMagic[client], g_iLevel[client], g_iAccount[client]));
	
	int consume = -1, cost = -1, i = 0;
	char classname[64], display[128];
	int length = g_hSellSpellList.Length;
	
	for(i = 0; i < length; ++i)
	{
		StringMap spell = g_hSellSpellList.Get(i);
		if(spell == null || !spell.GetString("display", display, 128) || !spell.GetValue("consume", consume) ||
			!spell.GetValue("cost", cost))
		{
			g_hSellSpellList.Erase(i--);
			continue;
		}
		
		IntToString(view_as<int>(spell), classname, 64);
		m.AddItem(classname, tr("%s [价格 %d丨消耗 %d]", display, cost, consume));
	}
	
	m.ExitBackButton = true;
	m.ExitButton = true;
	m.Display(client, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 4;
	
	return Plugin_Continue;
}

public Action Cmd_DebugFullAll(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	g_fMagic[client] = float(g_iMaxMagic[client]);
	g_fStamina[client] = float(g_iMaxStamina[client]);
	PrintToChat(client, "\x03[提示]\x01 完成。");
	
	return Plugin_Continue;
}

public Action Cmd_DebugGiveExperience(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	char amount[8];
	GetCmdArg(1, amount, 8);
	GiveExperience(client, StringToInt(amount));
	
	PrintToChat(client, "\x03[提示]\x01 完成。");
	
	return Plugin_Continue;
}

public Action Cmd_DebugGiveCash(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	char amount[8];
	GetCmdArg(1, amount, 8);
	GiveCash(client, StringToInt(amount));
	
	PrintToChat(client, "\x03[提示]\x01 完成。");
	
	return Plugin_Continue;
}

stock bool UseSpellByClient(int client, const char[] classname)
{
	char refClassname[64] = "";
	Action result = Plugin_Continue;
	
	char _classname[64];
	strcopy(refClassname, 64, classname);
	strcopy(_classname, 64, classname);
	
	Call_StartForward(g_fwOnUseSpellPre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushCell(sizeof(refClassname));
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	
	if(result == Plugin_Changed)
		strcopy(_classname, 64, refClassname);
	
	Call_StartForward(g_fwOnUseSpellPost);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_Finish();
	
	return true;
}

public int MenuHandler_MainMenu(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client))
		return 0;
	
	if(action != MenuAction_Select)
	{
		if(action == MenuAction_Cancel || action == MenuAction_End)
			g_iPlayerMenu[client] = 0;
		
		return 0;
	}
	
	char info[64], display[128];
	m.GetItem(select, info, 64, _, display, 128);
	
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnMenuItemClickPre);
	Call_PushCell(client);
	Call_PushString(info);
	Call_PushString(display);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return 0;
	
	switch(select)
	{
		case 0:
		{
			Cmd_SpellMenu(client, 0);
			return 0;
		}
		case 1:
		{
			Cmd_AttributesMenu(client, 0);
			return 0;
		}
		case 2:
		{
			Cmd_BuySpellMenu(client, 0);
			return 0;
		}
	}
	
	Call_StartForward(g_fwOnMenuItemClickPost);
	Call_PushCell(client);
	Call_PushString(info);
	Call_PushString(display);
	Call_Finish();
	
	g_iPlayerMenu[client] = 0;
	
	return 0;
}

public int MenuHandler_AttributesMenu(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client))
		return 0;
	
	/*
	if(action != MenuAction_Select)
		return 0;
	*/
	
	switch(select)
	{
		case 1:
		{
			if(g_iSkillPoint[client] >= 1)
			{
				g_iSkillPoint[client] -= 1;
				g_iMaxStamina[client] += g_pCvarPointAmount.IntValue;
			}
		}
		case 2:
		{
			if(g_iSkillPoint[client] >= 1)
			{
				g_iSkillPoint[client] -= 1;
				g_iMaxHealth[client] += g_pCvarPointAmount.IntValue;
			}
		}
		case 3:
		{
			if(g_iSkillPoint[client] >= 1)
			{
				g_iSkillPoint[client] -= 1;
				g_iMaxMagic[client] += g_pCvarPointAmount.IntValue;
			}
		}
		case 9:
		{
			Cmd_MainMenu(client, 0);
			return 0;
		}
		case 0, 10:
		{
			g_iPlayerMenu[client] = 0;
			return 0;
		}
	}
	
	Cmd_AttributesMenu(client, 0);
	return 0;
}

public int MenuHandler_SpellMenu(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			Cmd_MainMenu(client, 0);
		else
			g_iPlayerMenu[client] = 0;
		
		return 0;
	}
	
	if(action != MenuAction_Select)
	{
		if(action == MenuAction_End)
			g_iPlayerMenu[client] = 0;
		
		return 0;
	}
	
	char classname[64];
	m.GetItem(select, classname, 64);
	
	StringMap map = view_as<StringMap>(StringToInt(classname));
	int index = g_hPlayerSpell[client].FindValue(map);
	if(index == -1 || map == null)
	{
		g_hPlayerSpell[client].Erase(index);
		PrintToChat(client, "\x03[提示]\x01 施法失败，发生未知错误。");
		
		Cmd_SpellMenu(client, 0);
		return 0;
	}
	
	int consume = -1;
	map.GetValue("consume", consume);
	
	if(g_fMagic[client] < consume)
	{
		PrintToChat(client, "\x03[提示]\x01 施法失败，能量不足 \x05(%d/%.0f)\x01。", consume, g_fMagic[client]);
		Cmd_SpellMenu(client, 0);
		return 0;
	}
	
	if(!UseSpellByClient(client, classname))
		return 0;
	
	MagicDecrease(client, float(consume));
	g_hPlayerSpell[client].Erase(index);
	GiveExperience(client, consume);
	
	char display[128];
	map.GetString("display", display, 128);
	
	if(g_pCvarAllow.BoolValue)
		PrintToChat(client, "\x03[提示]\x01 你使用了 \x04%s\x01，经验 +\x05%d\x01。", display, consume);
	
	Cmd_SpellMenu(client, 0);
	return 0;
}

public int MenuHandler_BuySpellMenu(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			Cmd_MainMenu(client, 0);
		else
			g_iPlayerMenu[client] = 0;
		
		return 0;
	}
	
	if(action != MenuAction_Select)
	{
		if(action == MenuAction_End)
			g_iPlayerMenu[client] = 0;
		
		return 0;
	}
	
	char classname[64];
	m.GetItem(select, classname, 64);
	
	StringMap map = view_as<StringMap>(StringToInt(classname));
	int index = g_hSellSpellList.FindValue(map);
	if(index == -1 || map == null)
	{
		g_hSellSpellList.Erase(index);
		PrintToChat(client, "\x03[提示]\x01 购买失败，发生未知错误。");
		
		Cmd_BuySpellMenu(client, 0);
		return 0;
	}
	
	int cost = -1;
	map.GetValue("cost", cost);
	
	char refClassname[64] = "";
	Action result = Plugin_Continue;
	strcopy(refClassname, 64, classname);
	
	Call_StartForward(g_fwOnGainSpellPre);
	Call_PushCell(client);
	Call_PushString(refClassname);
	Call_PushCell(sizeof(refClassname));
	Call_Finish(result);
	
	if(result == Plugin_Handled)
	{
		PrintToChat(client, "\x03[提示]\x01 购买失败，被未知力量阻止了。");
		Cmd_BuySpellMenu(client, 0);
		return 0;
	}
	else if(result == Plugin_Changed)
	{
		// 修改购买的法术
		strcopy(classname, 64, refClassname);
	}
	
	if(g_iAccount[client] < cost)
	{
		PrintToChat(client, "\x03[提示]\x01 购买失败，你的钱不够 \x05(%d/%d)\x01。", cost, g_iAccount[client]);
		Cmd_BuySpellMenu(client, 0);
		return 0;
	}
	
	if(g_hPlayerSpell[client] == null)
		g_hPlayerSpell[client] = CreateArray();
	
	g_iAccount[client] -= cost;
	g_hPlayerSpell[client].Push(map);
	g_hSellSpellList.Erase(index);
	
	Call_StartForward(g_fwOnGainSpellPost);
	Call_PushCell(client);
	Call_PushString(refClassname);
	Call_Finish();
	
	Cmd_BuySpellMenu(client, 0);
	return 0;
}

public void ConVarHook_OnValueChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	// g_fCombatRadius = g_pCvarCombatRadius.FloatValue;
	g_fCombatDelay = g_pCvarCombatDelay.FloatValue;
	g_fCombatStamina = g_pCvarStaminaRate.FloatValue;
	g_fSafeStamina = g_pCvarStaminaIdleRate.FloatValue;
	g_fCombatMagic = g_pCvarMagicRate.FloatValue;
	g_fSafeMagic = g_pCvarMagicIdleRate.FloatValue;
	g_fDefenseChance = g_pCvarDefenseChance.FloatValue;
	g_fDefenseFactor = g_pCvarDefenseFactor.FloatValue;
	g_iDefenseLimit = g_pCvarDefenseLimit.IntValue;
	g_fDamageChance = g_pCvarDamageChance.FloatValue;
	g_fDamageFactor = g_pCvarDamageFactor.FloatValue;
	g_iDamageLimit = g_pCvarDamageLimit.IntValue;
	g_bDefenseFriendly = g_pCvarDefenseFriendly.BoolValue;
	g_bDamageFriendly = g_pCvarDamageFriendly.BoolValue;
	g_bSprintAllow = g_pCvarSprintAllow.BoolValue;
	g_iSprintLimit = g_pCvarSprintLimit.IntValue;
	g_iSprintPerSecond = g_pCvarSprintConsume.IntValue;
	g_fSprintWalk = g_pCvarSprintSpeed.FloatValue;
	g_fSprintDuck = g_pCvarSprintDuckSpeed.FloatValue;
	g_fSprintWater = g_pCvarSprintWaterSpeed.FloatValue;
	g_bJumpAllow = g_pCvarJumpAllow.BoolValue;
	g_iJumpLimit = g_pCvarJumpLimit.IntValue;
	g_iJumpConsume = g_pCvarJumpConsume.IntValue;
	g_fJumpHeight = g_pCvarJumpHeight.FloatValue;
	g_fStandingDelay = g_pCvarStandingDelay.FloatValue;
	g_fStandingFactor = g_pCvarStandingRate.FloatValue;
	g_iStandingLimit = g_pCvarStandingLimit.IntValue;
	g_fThinkInterval = g_pCvarThinkInterval.FloatValue;
	g_iDamageMin = g_pCvarDamageMin.IntValue;
	g_iDefenseMin = g_pCvarDefenseMin.IntValue;
	g_fBlockRevive = g_pCvarBlockRevive.FloatValue;
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	g_iCoinAlive = g_pCvarCoinAlive.IntValue;
	g_iCoinDead = g_pCvarCoinDead.IntValue;
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
}

public void ConVarHook_OnDifficultyChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(newValue, "impossible", false))
		g_fDifficultyFactor = g_pCvarDifficulty.FloatValue * 2.5;
	else if(StrEqual(newValue, "hard", false))
		g_fDifficultyFactor = g_pCvarDifficulty.FloatValue * 2.25;
	else if(StrEqual(newValue, "normal", false))
		g_fDifficultyFactor = g_pCvarDifficulty.FloatValue * 2.0;
	else // if(StrEqual(newValue, "easy", false))
		g_fDifficultyFactor = g_pCvarDifficulty.FloatValue;
	
	PrintToServer("当前难度：%s丨当前奖励倍率：%.3f", newValue, g_fDifficultyFactor);
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i))
			continue;
		
		LoadFromFile(i);
		SetupPlayerHook(i);
	}
	
	int length = (g_pCvarShopCount.IntValue > g_hAllSpellList.Length ? g_hAllSpellList.Length : g_pCvarShopCount.IntValue);
	
	g_hSellSpellList.Clear();
	SortADTArray(g_hAllSpellList, Sort_Random, Sort_Integer);
	
	for(int i = 0; i < length; ++i)
		g_hSellSpellList.Push(g_hAllSpellList.Get(i));
	
	char difficulty[32];
	g_hCvarDifficulty.GetString(difficulty, 32);
	ConVarHook_OnDifficultyChanged(g_hCvarDifficulty, "", difficulty);
}

public void Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i))
			continue;
		
		SaveToFile(i);
	}
}

public void Event_StageChanged(Event event, const char[] eventName, bool dontBroadcast)
{
	// int survival = event.GetInt("game_type");
	int state = event.GetInt("state");
	
	switch(state)
	{
		case 1:
		{
			// 地图开始？不确定
			LogMessage("========= 地图开始 =========");
		}
		case 2:
		{
			// 练习时间结束
			LogMessage("========= 准备时间结束 =========");
		}
		case 3:
		{
			// 回合开始
			LogMessage("========= 回合开始 =========");
			Event_RoundStart(event, eventName, dontBroadcast);
		}
		case 5, 8:
		{
			// 全部玩家死亡或者上救援了
			// 5 == 全部玩家死亡 | 8 == 回合结束
			LogMessage("========= 回合结束 =========");
			Event_RoundEnd(event, eventName, dontBroadcast);
		}
		case 6:
		{
			// 救援到时间离开了
			LogMessage("========= 救援离开 =========");
		}
	}
}

public void Event_PlayerChangeName(Event event, const char[] eventName, bool dontBroadcast)
{
	char newName[MAX_NAME_LENGTH];
	int client = GetClientOfUserId(event.GetInt("userid"));
	event.GetString("newname", newName, MAX_NAME_LENGTH);
	if(!IsValidClient(client) || newName[0] == '\0')
		return;
	
	g_hDatabase.Escape(newName, newName, MAX_NAME_LENGTH);
	SQL_FastQuery(g_hDatabase, tr("UPDATE user_info SET name = '%s' WHERE uid = '%d';", newName, g_iClientUserId[client]));
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	// LoadFromFile(client);
	// SetupPlayerHook(client);
	RequestFrame(SetupPlayerHook, client);
}

public void Event_ZombieDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = event.GetInt("killeridx");
	if(!IsValidClient(client))
		return;
	
	g_iZombieKilled[client] += 1;
}

public void Event_ZombieDeathFire(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = event.GetInt("igniter_id");
	if(!IsValidClient(client))
		return;
	
	g_iZombieFired[client] += 1;
}

public void Event_ZombieHeadShot(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = event.GetInt("player_id");
	if(!IsValidClient(client))
		return;
	
	g_iZombieHeadshot[client] += 1;
}

public void Event_ZombieKilled(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = event.GetInt("entindex_attacker");
	if(!IsValidClient(client))
		return;
	
	g_iZombieKilled[client] += 1;
}

public void Event_RoundWin(Event event, const char[] eventName, bool dontBroadcast)
{
	char mapName[64];
	event.GetString("strMapName", mapName, 64);
	
	int difficulty = event.GetInt("difficulty");
	int wave = event.GetInt("wave");
	int live = event.GetInt("livingplayers");
	
	LogMessage("========= 回合胜利 =========");
	LogMessage("\t当前难度：%d", difficulty);
	LogMessage("\t波数：%d", wave);
	LogMessage("\t存活玩家数：%d", live);
	LogMessage("========= End =========");
}

public void Event_SurvivalWaveComplete(Event event, const char[] eventName, bool dontBroadcast)
{
	int experience = g_pCvarWaveExperience.IntValue;
	int cash = g_pCvarWaveCash.IntValue;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i))
			continue;
		
		GiveExperience(i, experience);
		GiveCash(i, cash);
		
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(i, "[SC] exp +%d, cash +%d with wave.", experience, cash);
#endif	// _USE_CONSOLE_MESSAGE_
	}
}

public void Event_PasswordEnter(Event event, const char[] eventName, bool dontBroadcast)
{
	char input[9] = "", correct[9] = "";
	int client = event.GetInt("player");
	int keypad = event.GetInt("keypad_idx");
	event.GetString("code", input, 9);
	
	if(!IsValidAliveClient(client) || !IsValidEntity(keypad) || input[0] == '\0')
		return;
	
	GetEntPropString(keypad, Prop_Data, "m_pszCode", correct, 8, 0);
	if(!StrEqual(input, correct, false))
	{
		LogMessage("玩家 %N 输入了错误的密码 %s，正确的密码是 %s。", client, input, correct);
		return;
	}
	
	GiveExperience(client, g_pCvarPasswordExperience.IntValue);
	GiveCash(client, g_pCvarPasswordCash.IntValue);
	
	LogMessage("玩家 %N 输入了正确的密码 %s", client, input);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(client, "[SC] exp +%d, cash +%d with password.",
		g_pCvarPasswordExperience.IntValue, g_pCvarPasswordCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_PlayerEscape(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = event.GetInt("player_id");
	if(!IsValidClient(client))
		return;
	
	GiveExperience(client, g_pCvarEscapeExperience.IntValue);
	GiveCash(client, g_pCvarEscapeCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(client, "[SC] exp +%d, cash +%d with escape.",
		g_pCvarEscapeExperience.IntValue, g_pCvarEscapeCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_PlayerJump(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if(!IsValidClient(client) || !g_bInJumping[client])
		return;
	
	float velocity[3];
	GetEntDataVector(client, g_iOffsetVelocity, velocity);
	
	// 在地上有摩擦力，太低的速度无法起跳
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1 || velocity[0] <= 0.0)
		return;
	
	float length = NormalizeVector(velocity, velocity);
	ScaleVector(velocity, length + g_fJumpHeight);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
	
	if(g_iJumpConsume > 0)
		StaminaDecrease(client, float(g_iJumpConsume));
	
	// PrintCenterText(client, "冲刺跳跃");
	g_bInJumping[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SaveToFile(client);
	UninstallPlayerHook(client);
}

public void Event_PlayerHurt(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(victim))
		return;
	
	g_fNextReviveTime[victim] = GetGameTime() + g_fBlockRevive;
}

public void Event_MissionComplete(Event event, const char[] eventName, bool dontBroadcast)
{
	int experience = g_pCvarObjectiveExperience.IntValue;
	int cash = g_pCvarObjectiveCash.IntValue;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i))
			continue;
		
		GiveExperience(i, experience);
		GiveCash(i, cash);
		
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(i, "[SC] exp +%d, cash +%d with objective.", experience, cash);
#endif	// _USE_CONSOLE_MESSAGE_
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// 2048 是 edic_t 上限
	if(entity <= MaxClients || entity > 2048)
		return;
	
	if(StrEqual(classname, "npc_nmrih_turnedzombie", false) ||
		StrEqual(classname, "npc_nmrih_kidzombie", false) ||
		StrEqual(classname, "npc_nmrih_runnerzombie", false) ||
		StrEqual(classname, "npc_nmrih_shamblerzombie", false) ||
		StrEqual(classname, "npc_nmrih_normalzombie", false))
		SDKHook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
}

int g_iGameFramePerSecond = 0;

public void OnGameFrame()
{
	static int frame;
	++frame;
	
	if(g_iGameFramePerSecond > 0)
		Timer_OnCombatThink(INVALID_HANDLE, 0);
	
	static float nextTime;
	float curTime = GetEngineTime();
	if(curTime < nextTime)
		return;
	
	g_iGameFramePerSecond = frame;
	nextTime = curTime + g_fThinkInterval;
	frame = 0;
	
	Timer_OnMenuThink(INVALID_HANDLE, 0);
}

// 每个 tick 调用一次，默认为每秒 30 次
public Action Timer_OnCombatThink(Handle timer, any data)
{
	float time = GetGameTime();
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
			continue;
		
		if(!IsPlayerAlive(i) || IsPlayerGhost(i))
		{
			if(g_bInBattle[i])
				CombatEnd(i);
			
			/*
			if(g_hPlayerMenu[client] != null)
			{
				CancelClientMenu(client);
				g_hPlayerMenu[client].Close();
				g_hPlayerMenu[client] = null;
			}
			*/
			
			continue;
		}
		
		// 战斗状态检查
		// if(FindEnemyInRange(i, g_fCombatRadius) > 0)
		if(IsVisibleThreats(i))
		{
			if(!g_bInBattle[i])
			{
				if(CombatStart(i) && g_pCvarAllow.BoolValue)
					PrintToChat(i, "\x03[战斗]\x01 进入战斗状态。");
			}
			else if(g_hTimerCombatEnd[i] != null)
			{
				KillTimer(g_hTimerCombatEnd[i], false);
				g_hTimerCombatEnd[i] = null;
			}
		}
		else
		{
			if(g_bInBattle[i] && g_hTimerCombatEnd[i] == null)
				g_hTimerCombatEnd[i] = CreateTimer(g_fCombatDelay, Timer_LeaveCombat, i);
		}
		
		// 冲刺消耗
		if(g_bInSprint[i])
		{
			if(g_iSprintPerSecond > 0)
				StaminaDecrease(i, g_iSprintPerSecond / float(g_iGameFramePerSecond));
			
			// 跑步时相机左右摇摆
			/*
			{
				float viewPunch[3];
				viewPunch[0] = 5.0;
				viewPunch[2] = 0.0;
				
				if(g_bSprintFilp[i])
					viewPunch[1] = 5.0;
				else
					viewPunch[1] = -5.0;
				
				g_bSprintFilp[i] = !g_bSprintFilp[i];
				SetEntPropVector(i, Prop_Send, "m_vecPunchAngle", viewPunch);
				SetEntPropVector(i, Prop_Send, "m_vecPunchAngleVel", viewPunch);
			}
			*/
		}
		// 自动恢复能量，被攻击时除外
		else if(g_fNextReviveTime[i] <= time)
		{
			if(g_bInBattle[i])
			{
				if(g_fStamina[i] < g_iMaxStamina[i])
					StaminaIncrease(i, g_fCombatStamina * g_iMaxStamina[i] / g_iGameFramePerSecond);
				
				if(g_fMagic[i] < g_iMaxMagic[i])
					MagicIncrease(i, g_fCombatMagic * g_iMaxMagic[i] / g_iGameFramePerSecond);
			}
			else
			{
				if(g_fStamina[i] < g_iMaxStamina[i])
					StaminaIncrease(i, g_fSafeStamina * g_iMaxStamina[i] / g_iGameFramePerSecond);
				
				if(g_fMagic[i] < g_iMaxMagic[i])
					MagicIncrease(i, g_fSafeMagic * g_iMaxMagic[i] / g_iGameFramePerSecond);
			}
		}
		
		// 升级检查(可以不要)
		if(g_iExperience[i] >= g_iNextLevel[i])
		{
			if(CheckLevelUp(i) && g_pCvarAllow.BoolValue)
			{
				PrintToChat(i, "\x03[战斗]\x01 你升级了，当前等级：\x05%d\x01 经验：\x04%d\x01/\x03%d\x01。",
					g_iLevel[i], g_iExperience[i], g_iNextLevel[i]);
			}
		}
	}
	
	return Plugin_Continue;
}

// 每秒调用一次
public Action Timer_OnMenuThink(Handle timer, any data)
{
	float time = GetGameTime();
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	int alivePlayer[MAXPLAYERS + 1] = {-1, ...}, maxAlivePlayer = 0;
	int deadPlayer[MAXPLAYERS + 1] = {-1, ...}, maxDeadPlayer = 0;
#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
			continue;
		
		// 菜单更新
		if(g_iPlayerMenu[i] > 0)
		{
			switch(g_iPlayerMenu[i])
			{
				case 1:
				{
					Cmd_MainMenu(i, 0);
				}
				case 2:
				{
					Cmd_AttributesMenu(i, 0);
				}
				case 3:
				{
					Cmd_SpellMenu(i, 0);
				}
				case 4:
				{
					Cmd_BuySpellMenu(i, 0);
				}
			}
		}
		
		if(g_iZombieKilled[i] > 0 || g_iZombieFired[i] > 0 || g_iZombieHeadshot[i] > 0)
		{
			int experience = (g_pCvarKillExperience.IntValue * g_iZombieKilled[i]) +
				(g_pCvarFiredExperience.IntValue * g_iZombieFired[i]) +
				(g_pCvarHeadshotExperience.IntValue * g_iZombieHeadshot[i]);
			int cash = (g_pCvarKillCash.IntValue * g_iZombieKilled[i]) +
				(g_pCvarFiredCash.IntValue * g_iZombieFired[i]) +
				(g_pCvarHeadshotCash.IntValue * g_iZombieHeadshot[i]);
			
			GiveExperience(i, experience);
			GiveCash(i, cash);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%d, cash +%d with kill %d, burn %d, headshot %d.",
				experience, cash, g_iZombieKilled[i], g_iZombieFired[i], g_iZombieHeadshot[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iZombieKilled[i] = 0;
			g_iZombieFired[i] = 0;
			g_iZombieHeadshot[i] = 0;
		}
		
		// 站立不动自动回血
		if(IsPlayerAlive(i) && g_fMagic[i] >= g_iStandingLimit && g_fNextStandingTime[i] <= time)
		{
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			
#if defined _USE_PLUGIN_MAX_HEALTH_
			int maxHealth = g_iMaxHealth[i];
#else
			int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
#endif	// _USE_PLUGIN_MAX_HEALTH_
			
			if(health < maxHealth)
			{
				float amount = g_iMaxMagic[i] * g_fStandingFactor * g_fThinkInterval;
				if(amount + health > maxHealth)
					amount = float(maxHealth - health);
				
				if(amount < g_fMagic[i])
					amount = g_fMagic[i];
				
				if(amount > 0.0)
				{
					health += RoundToCeil(amount);
					MagicDecrease(i, amount);
					SetEntProp(i, Prop_Data, "m_iHealth", health);
					
#if defined SOUND_STANDING_HEAL
					// ClientCommand(i, "play \"ui/beep07.wav\"");
					EmitSoundToClient(i, SOUND_STANDING_HEAL, _, SNDCHAN_VOICE, SNDLEVEL_HOME);
#endif	// SOUND_STANDING_HEAL
				}
			}
		}
		
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
		if(IsPlayerAlive(i))
			alivePlayer[maxAlivePlayer++] = i;
		else
			deadPlayer[maxDeadPlayer++] = i;
#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	}
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	
	char buffer[255] = "";
	Transaction tran = SQL_CreateTransaction();
	
	for(int i = 0; i < maxAlivePlayer; ++i)
	{
		if(i == 0)
			FormatEx(buffer, 255, "'%d'", g_iClientUserId[alivePlayer[i]]);
		else
			StrCat(buffer, 255, tr(", '%d'", g_iClientUserId[alivePlayer[i]]));
	}
	
	if(maxAlivePlayer > 0)
	{
#if defined _USE_DATABASE_MYSQL_
		tran.AddQuery(tr("UPDATE user_online SET coin = coin + %.0f, online = date_add(online, interval 1 second) WHERE uid IN (%s);",
			g_iCoinAlive * g_fThinkInterval, buffer));
#else
		tran.AddQuery(tr("UPDATE user_online SET coin = coin + %.0f, online = time(online, '+1 second') WHERE uid IN (%s);",
			g_iCoinAlive * g_fThinkInterval, buffer));
#endif
	}
	
	for(int i = 0; i < maxDeadPlayer; ++i)
	{
		if(i == 0)
			FormatEx(buffer, 255, "'%d'", g_iClientUserId[deadPlayer[i]]);
		else
			StrCat(buffer, 255, tr(", '%d'", g_iClientUserId[deadPlayer[i]]));
	}
	
	if(maxDeadPlayer > 0)
	{
#if defined _USE_DATABASE_MYSQL_
		tran.AddQuery(tr("UPDATE user_online SET coin = coin + %.0f, online = date_add(online, interval 1 second) WHERE uid IN (%s);",
			g_iCoinDead * g_fThinkInterval, buffer));
#else
		tran.AddQuery(tr("UPDATE user_online SET coin = coin + %.0f, online = time(online, '+1 second') WHERE uid IN (%s);",
			g_iCoinDead * g_fThinkInterval, buffer));
#endif
	}
	
	if(maxAlivePlayer > 0 || maxDeadPlayer > 0)
		SQL_ExecuteTransaction(g_hDatabase, tran);
	
#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
}

public Action Timer_LeaveCombat(Handle timer, any client)
{
	if(!IsValidClient(client))
	{
		if(client > 0 && client <= MAXPLAYERS)
			g_hTimerCombatEnd[client] = null;
		
		return Plugin_Continue;
	}
	
	// KillTimer(g_hTimerCombatEnd[client], false);
	g_hTimerCombatEnd[client] = null;
	
	if(CombatEnd(client) && g_pCvarAllow.BoolValue)
		PrintToChat(client, "\x03[战斗]\x01 离开战斗状态。");
	
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	InitializationPlayer(client);
}

public void OnClientPutInServer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	LoadFromFile(client);
}

public void OnClientDisconnect(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	SaveToFile(client);
	delete g_kvSaveData[client];
	InitializationPlayer(client);
	g_kvSaveData[client] = null;
}

// 按住这些按键可以冲刺
#define SPRINT_BUTTON			(IN_WALK|IN_ALT1|IN_ALT2)

// 这些按键被按住后无法冲刺
#define INVALID_SPRINT_BUTTON	(IN_BACK|IN_LEFT|IN_RIGHT|IN_MOVELEFT|IN_MOVERIGHT|IN_SPEED|IN_DUCK|IN_JUMP|IN_ATTACK|IN_ATTACK2)

// 移动按钮
#define MOVING_BUTTON			(IN_FORWARD|IN_BACK|IN_LEFT|IN_RIGHT|IN_MOVELEFT|IN_MOVERIGHT|IN_JUMP)

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3],
	int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	int flags = GetEntityFlags(client);
	
	if(g_bInSprint[client])
	{
		if(g_bJumpAllow && g_fStamina[client] >= g_iJumpLimit && (buttons & IN_JUMP) && (flags & FL_ONGROUND))
		{
			g_bInJumping[client] = true;
		}
		
		if(!g_bSprintAllow || !(buttons & SPRINT_BUTTON) || g_fStamina[client] < g_iSprintLimit ||
			(buttons & INVALID_SPRINT_BUTTON) || (g_fSprintDuck <= 0.0 && (flags & FL_DUCKING)) ||
			(g_fSprintWater <= 0.0 && (flags & FL_INWATER)) || (g_fSprintWalk <= 0 && (flags & FL_ONGROUND)))
		{
			g_bInSprint[client] = false;
			// g_bInJumping[client] = false;
			g_fSprintSpeed[client] = 0.0;
		}
	}
	else if(g_bSprintAllow && (buttons & SPRINT_BUTTON) && !(buttons & INVALID_SPRINT_BUTTON) &&
		g_fStamina[client] >= g_iSprintLimit && (flags & FL_ONGROUND) &&
		(g_fSprintDuck > 0.0 || g_fSprintWater > 0.0 || g_fSprintWalk > 0.0))
	{
		if(flags & FL_DUCKING)
		{
			g_bInSprint[client] = (g_fSprintDuck > 0.0);
			g_fSprintSpeed[client] = g_fSprintDuck;
		}
		else if(flags & FL_INWATER)
		{
			g_bInSprint[client] = (g_fSprintWater > 0.0);
			g_fSprintSpeed[client] = g_fSprintWater;
		}
		else if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1)
		{
			g_bInSprint[client] = (g_fSprintWalk > 0.0);
			g_fSprintSpeed[client] = g_fSprintWalk;
		}
		
		g_bInJumping[client] = false;
	}
	
	/*
	if(g_bInSprint[client] && g_fSprintSpeed[client] > 0.0)
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSprintSpeed[client]);
	else
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	*/
	
	if(GetClientTeam(client) == 3 && IsPlayerAlive(client) && !IsPlayerGhost(client))
	{
		if(!(flags & FL_ONGROUND) || (buttons & MOVING_BUTTON) || GetVectorLength(vel, false) > 15.0)
			g_fNextStandingTime[client] = GetGameTime() + g_fStandingDelay;
	}
	
	return Plugin_Continue;
}

// 不是有效的攻击伤害
const int INVALID_DAMAGE_TYPE = (DMG_FALL|DMG_BURN|DMG_BLAST);

public Action PlayerHook_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &ammotype, int hitbox, int hitgroup)
{
	if(!IsValidClient(attacker) || !IsValidEdict(victim) || damage < g_iDamageMin || (damagetype & INVALID_DAMAGE_TYPE))
		return Plugin_Continue;
	
	if(!g_bDamageFriendly && GetClientTeam(attacker) == GetEntProp(victim, Prop_Send, "m_iTeamNum"))
		return Plugin_Continue;
	
	if(g_fStamina[attacker] < g_iDamageLimit || GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) > g_fDamageChance)
		return Plugin_Continue;
	
	float plusDamage = damage * g_fDamageFactor;
	if(plusDamage > g_fStamina[attacker])
		plusDamage = g_fStamina[attacker];
	
	if(plusDamage < 1.0)
		return Plugin_Continue;
	
	// PrintCenterText(attacker, "plus %.0f + %.0f damage", damage, plusDamage);
	
	damage += plusDamage;
	damagetype |= DMG_CRIT;
	StaminaDecrease(attacker, plusDamage);
	return Plugin_Changed;
}

// 调用顺序：TraceAttack -> OnTakeDamage -> OnTakeDamage_Alive -> player_hurt
// 其中 OnTakeDamage_Alive 是玩家专属的
public Action PlayerHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsValidClient(victim) || attacker <= 0 || !IsValidEdict(attacker) || damage < g_iDefenseMin || (damagetype & INVALID_DAMAGE_TYPE))
		return Plugin_Continue;
	
	if(!g_bDefenseFriendly && GetEntProp(attacker, Prop_Send, "m_iTeamNum") == GetClientTeam(victim))
		return Plugin_Continue;
	
	if(g_fStamina[victim] < g_iDefenseLimit || GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) > g_fDefenseChance)
		return Plugin_Continue;
	
	float minusDamage = damage * g_fDefenseFactor;
	if(minusDamage - 1.0 > damage)
		minusDamage = damage - 1.0;
	
	if(minusDamage > g_fStamina[victim])
		minusDamage = g_fStamina[victim];
	
	if(minusDamage <= 1.0)
		return Plugin_Continue;
	
	// PrintCenterText(victim, "take %.0f - %.0f damage", damage, minusDamage);
	
	damage -= minusDamage;
	StaminaDecrease(victim, minusDamage);
	return Plugin_Changed;
}

public void ZombieHook_OnSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	SDKHook(entity, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	
	// PrintToServer("Zombie %d Spawned.", entity);
}

public void PlayerHook_OnPreThinkPost(int client)
{
	if(!IsValidAliveClient(client))
	{
		// UninstallPlayerHook(client);
		SDKUnhook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
		return;
	}
	
	if(g_bInSprint[client] && g_fSprintSpeed[client] > 0.0)
	{
		// SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", GetPlayerSpeed(client) * g_fSprintSpeed[client]);
		// SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSprintSpeed[client]);
		
		// CBasePlayer::PreThink 里面会调整 m_flMaxspeed 的值，这里可以直接改
		// 到了 CBasePlayer::PostThink 时会调用客户端(实际上在 engine.dll 里)的 CL_Move 进行移动
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") * g_fSprintSpeed[client]);
	}
}

public void SetupPlayerHook(any client)
{
	if(!IsValidClient(client))
		return;
	
	g_fNextStandingTime[client] = GetGameTime();
	g_fNextReviveTime[client] = GetGameTime();
	g_iZombieKilled[client] = 0;
	g_iZombieFired[client] = 0;
	g_iZombieHeadshot[client] = 0;
	
	if(g_iMaxHealth[client] < 100)
		g_iMaxHealth[client] = 100;
	if(g_iMaxMagic[client] < 0)
		g_iMaxMagic[client] = 0;
	if(g_iMaxStamina[client] < 0)
		g_iMaxStamina[client] = 0;
	if(g_iAccount[client] < 0)
		g_iAccount[client] = 0;
	if(g_iExperience[client] < 0)
		g_iExperience[client] = 0;
	
	if(g_iMaxHealth[client] > 100)
	{
		int health = GetEntProp(client, Prop_Data, "m_iHealth");
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
		
		// 修复血量百分比
		health = g_iMaxHealth[client] * health / 100;
		buffer = g_iMaxHealth[client] * buffer / 100;
		maxHealth = g_iMaxHealth[client] * maxHealth / 100;
		
		SetEntProp(client, Prop_Data, "m_iMaxHealth", maxHealth);
		SetEntProp(client, Prop_Data, "m_iHealth", health);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	
	SDKHook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKHook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, PlayerHook_OnTakeDamage);
	SDKHook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	
	// PrintToServer("player %N (%d) Hooked (%d).", client, client, g_iMaxHealth[client]);
}

void UninstallPlayerHook(int client)
{
	SDKUnhook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKUnhook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, PlayerHook_OnTakeDamage);
	SDKUnhook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	
	// PrintToServer("player %d Unhooked.", client);
}

bool CombatStart(int client)
{
	if(!IsValidAliveClient(client))
		return false;
	
	if(g_bInBattle[client])
		return true;
	
	// 调用 Pre 函数
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnStartCombatPre);
	Call_PushCell(client);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	
	g_bInBattle[client] = true;
	
	// 调用 Post 函数
	Call_StartForward(g_fwOnStartCombatPost);
	Call_PushCell(client);
	Call_Finish();
	
	return true;
}

bool CombatEnd(int client)
{
	if(!IsValidClient(client))
		return false;
	
	if(!g_bInBattle[client])
		return true;
	
	// 调用 Pre 函数
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnLeaveCombatPre);
	Call_PushCell(client);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	
	g_bInBattle[client] = false;
	
	// 调用 Post 函数
	Call_StartForward(g_fwOnLeaveCombatPost);
	Call_PushCell(client);
	Call_Finish();
	
	return true;
}

// 增加玩家的耐力
float StaminaIncrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fStamina[client] + amount > g_iMaxStamina[client])
		amount = g_iMaxStamina[client] - g_fStamina[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwStaminaIncreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fStamina[client] += amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwStaminaIncreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

// 减少玩家的耐力
float StaminaDecrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fStamina[client] - amount < 0)
		amount = g_fStamina[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwStaminaDecreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fStamina[client] -= amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwStaminaDecreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

// 增加玩家的魔力
float MagicIncrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fMagic[client] + amount > g_iMaxMagic[client])
		amount = g_iMaxMagic[client] - g_fMagic[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwMagicIncreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fMagic[client] += amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwMagicIncreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

// 减少玩家的魔力
float MagicDecrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fMagic[client] - amount < 0)
		amount = g_fMagic[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwMagicDecreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fMagic[client] -= amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwMagicDecreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

bool GiveCash(int client, int amount)
{
	if(!IsValidClient(client))
		return false;
	
	int refAmount = amount;
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnGainCashPre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	else if(result == Plugin_Changed)
		amount = refAmount;
	
	g_iAccount[client] += RoundToZero(amount * g_fDifficultyFactor);
	
	Call_StartForward(g_fwOnGainCashPost);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
	
	return true;
}

bool GiveExperience(int client, int amount)
{
	if(!IsValidClient(client))
		return false;
	
	int refAmount = amount;
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnGainExperiencePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	else if(result == Plugin_Changed)
		amount = refAmount;
	
	g_iExperience[client] += RoundToZero(amount * g_fDifficultyFactor);
	
	Call_StartForward(g_fwOnGainExperiencePost);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
	
	/*
	if(g_iExperience[client] >= g_iNextLevel[client])
		CheckLevelUp(client);
	*/
	
	return true;
}

bool CheckLevelUp(int client)
{
	if(!IsValidClient(client))
		return false;
	
	if(g_iNextLevel[client] <= 0)
		g_iNextLevel[client] = (g_pCvarLevelExperience.IntValue * (g_iLevel[client] + 1));
	
	if(g_iExperience[client] < g_iNextLevel[client])
		return false;
	
	int refExperience = g_iExperience[client];
	int refNextLevel = g_iNextLevel[client];
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnLevelUpPre);
	Call_PushCell(client);
	Call_PushCell(g_iLevel[client]);
	Call_PushCellRef(refExperience);
	Call_PushCellRef(refNextLevel);
	Call_Finish(result);
	
	if(result == Plugin_Handled)
		return false;
	else if(result == Plugin_Changed)
	{
		g_iExperience[client] = refExperience;
		g_iNextLevel[client] = refNextLevel;
	}
	
	if(g_iExperience[client] < g_iNextLevel[client])
		return false;
	
	g_iLevel[client] += 1;
	g_iSkillPoint[client] += g_pCvarLevelPoint.IntValue;
	g_iExperience[client] -= g_iNextLevel[client];
	g_iNextLevel[client] = (g_pCvarLevelExperience.IntValue * (g_iLevel[client] + 1));
	
	refExperience = g_iExperience[client];
	refNextLevel = g_iNextLevel[client];
	
	Call_StartForward(g_fwOnLevelUpPost);
	Call_PushCell(client);
	Call_PushCell(g_iLevel[client]);
	Call_PushCellRef(refExperience);
	Call_PushCellRef(refNextLevel);
	Call_Finish(result);
	
	if(result == Plugin_Changed)
	{
		g_iExperience[client] = refExperience;
		g_iNextLevel[client] = refNextLevel;
	}
	
	return true;
}

void InitializationPlayer(int client)
{
	if(client <= 0 || client > MaxClients)
		return;
	
	g_fStamina[client] = 0.0;
	g_iMaxStamina[client] = 0;
	g_fMagic[client] = 0.0;
	g_iMaxMagic[client] = 0;
	g_iMaxHealth[client] = 0;
	g_iExperience[client] = 0;
	g_iLevel[client] = 0;
	g_iNextLevel[client] = 0;
	g_iSkillPoint[client] = 0;
	g_bInSprint[client] = false;
	g_bInJumping[client] = false;
	g_bInBattle[client] = false;
	g_fSprintSpeed[client] = 0.0;
	g_fNextReviveTime[client] = 0.0;
	g_fNextStandingTime[client] = 0.0;
	
	if(g_hPlayerSpell[client] != null)
	{
		delete g_hPlayerSpell[client];
		g_hPlayerSpell[client] = null;
	}
	
	if(g_kvSaveData[client] != null)
	{
		delete g_kvSaveData[client];
		g_kvSaveData[client] = null;
	}
	
	UninstallPlayerHook(client);
}

stock bool IsValidEnemy(int client, int other)
{
	if(!IsValidClient(client) || !IsValidEdict(other))
		return false;
	
	int team = GetClientTeam(client);
	
	if(IsValidClient(other))
	{
		int enemyTeam = GetClientTeam(other);
		bool lookat = (GetEntPropEnt(client, Prop_Send, "m_lookatPlayer") == client);
		
		if(team == 2)
			return (enemyTeam == 3 && lookat);
		
		return (enemyTeam != 2 && lookat);
	}
	
	if(team == 3)
		return false;
	
	char classname[64];
	GetEntityClassname(other, classname, 64);
	if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false))
		return (team == 2);
	
	return false;
}

stock bool IsVisibleThreats(int client)
{
	if(!IsValidAliveClient(client))
		return false;
	
}

/*
stock int FindEnemyInRange(int client, float radius = 300.0)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	float myOrigin[3], myMins[3], myMaxs[3];
	GetClientAbsOrigin(client, myOrigin);
	GetClientMins(client, myMins);
	GetClientMaxs(client, myMaxs);
	
	float length = GetVectorLength(myMins, false);
	ScaleVector(myMins, radius / 3 + length);
	length = GetVectorLength(myMaxs, false);
	ScaleVector(myMaxs, radius / 3 + length);
	
	Handle trace = TR_TraceHullFilterEx(myOrigin, myOrigin, myMins, myMaxs, MASK_SHOT, TraceFilter_FindEnemyInRange, client);
	
	if(TR_DidHit(trace))
	{
		delete trace;
		return true;
	}
	
	delete trace;
	return false;
}
*/

public bool TraceFilter_FindEnemyInRange(int entity, int mask, any client)
{
	if(entity == 0 || entity == client || !IsValidEdict(entity))
		return false;
	
	int team = GetClientTeam(client);
	if(IsValidAliveClient(entity))
		return (GetClientTeam(entity) != team);
	
	if(team != 2)
		return false;
	
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false))
		return true;
	
	return false;
}

stock char tr(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);
	return buffer;
}

#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
public Action Timer_ConnectDatabase(Handle timer, any unused)
{
	static KeyValues kv;
	if(kv == null)
	{
		kv = CreateKeyValues("");
		
#if defined _USE_DATABASE_MYSQL_
		kv.SetString("driver", "mysql");
#elseif defined _USE_DATABASE_SQLITE_
		kv.SetString("driver", "sqlite");
#endif
		
		kv.SetString("host", _SQL_CONNECT_HOST_);
		kv.SetString("database", _SQL_CONNECT_DATABASE_);
		kv.SetString("user", _SQL_CONNECT_USER_);
		kv.SetString("pass", _SQL_CONNECT_PASSWORD_);
		kv.SetString("port", _SQL_CONNECT_PORT_);
	}
	
	char error[255];
	g_hDatabase = SQL_ConnectCustom(kv, error, 255, true);
	if(g_hDatabase == null)
	{
		LogError("数据库连接失败：%s", error);
		CreateTimer(3.0, Timer_ConnectDatabase);
		return Plugin_Continue;
	}
	
	Transaction tran = SQL_CreateTransaction();
	
#if defined _USE_DATABASE_MYSQL_
	tran.AddQuery("CREATE TABLE IF NOT EXISTS `user_info` (`uid` int(10) unsigned NOT NULL AUTO_INCREMENT, `sid` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID64', `sid2` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID2', `sid3` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID3', `name` text COLLATE utf8_bin COMMENT '???', `ip` char(16) COLLATE utf8_bin DEFAULT NULL COMMENT '???????IP', `country` char(64) COLLATE utf8_bin DEFAULT NULL COMMENT 'IP???', `joindate` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '????????', PRIMARY KEY (`uid`), UNIQUE KEY `sid` (`sid`), UNIQUE KEY `sid2` (`sid2`), UNIQUE KEY `sid3` (`sid3`)) ENGINE=MyISAM AUTO_INCREMENT=20 DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='????';");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS `user_online` (`uid` int(11) NOT NULL AUTO_INCREMENT, `coin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '???????????', `country_name` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `region` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `city` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `code` char(3) NOT NULL DEFAULT '' COMMENT '?????????? CN', `code3` char(4) NOT NULL DEFAULT '' COMMENT '?????????? CHN', `online` time NOT NULL DEFAULT '00:00:00' COMMENT '??????', `last` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '????????', PRIMARY KEY (`uid`)) ENGINE=MyISAM AUTO_INCREMENT=20 DEFAULT CHARSET=utf8;");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS `nmrih_simple_combat` (`uid` int(10) unsigned NOT NULL, `max_health` int(10) unsigned NOT NULL DEFAULT '100', `max_stamina` int(10) unsigned NOT NULL DEFAULT '0', `max_magic` int(10) unsigned NOT NULL DEFAULT '0', `accounts` int(11) NOT NULL DEFAULT '0', `points` int(11) NOT NULL DEFAULT '0', `level` smallint(5) unsigned NOT NULL DEFAULT '0', `experience` int(10) unsigned NOT NULL DEFAULT '0', `level_experience` int(10) unsigned NOT NULL DEFAULT '0', PRIMARY KEY (`uid`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS `nmrih_simple_combat_spell` (`uid` int(10) unsigned NOT NULL, `spell` text NOT NULL, PRIMARY KEY (`uid`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;");
#elseif defined _USE_DATABASE_SQLITE_
	tran.AddQuery("CREATE TABLE IF NOT EXISTS user_info (uid INTEGER PRIMARY KEY AUTOINCREMENT, sid CHAR(20) UNIQUE NOT NULL, sid2 CHAR(20) UNIQUE NOT NULL, sid3 CHAR(20) UNIQUE NOT NULL, name TEXT NOT NULL, ip CHAR(16) DEFAULT(''), country VARCHAR(32) DEFAULT(''), joindate DATETIME DEFAULT(datetime('now')));");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS user_online (uid INTEGER PRIMARY KEY AUTOINCREMENT, coin INT(10) DEFAULT(0), country_name VARCHAR(64) DEFAULT(''), region VARCHAR(64) DEFAULT(''), city VARCHAR(64) DEFAULT(''), code CHAR(3) DEFAULT(''), code3 CHAR(4) DEFAULT(''), online TIME DEFAULT(time('0', '-12 hour')), last DATETIME DEFAULT(datetime('now')));");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS nmrih_simple_combat (uid INTEGER PRIMARY KEY AUTOINCREMENT, max_health INT(10) DEFAULT(100), max_stamina INT(10) DEFAULT(0), max_magic INT(10) DEFAULT(0), accounts INT(10) DEFAULT(0), points INT(10) DEFAULT(0), level INT(10) DEFAULT(0), experience INT(10) DEFAULT(0), level_experience INT(10) DEFAULT(0));");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS nmrih_simple_combat_spell (uid INTEGER PRIMARY KEY AUTOINCREMENT, spell TEXT DEFAULT(''));");
	tran.AddQuery("CREATE TABLE IF NOT EXISTS nmrih_cost (idx INTEGER PRIMARY KEY AUTOINCREMENT, classname CHAR(32), display TEXT, price INT(10), currency INT(5), sell INT(10), weight INT(10), ammo INT(3), ammotype INT(3), classification INT(3), surplus INT(5));");
	
	// 创建触发器必须先开启事务
	// tran.AddQuery("CREATE TRIGGER update_last_online AFTER UPDATE ON user_online FOR EACH ROW WHEN new.last <= old.last BEGIN UPDATE user_online SET last = datetime('now') WHERE uid = new.uid; END;");
#endif
	
	SQL_ExecuteTransaction(g_hDatabase, tran);
	
	return Plugin_Continue;
}
#endif

#define DECL_MENU_PRE(%1)			CreateGlobalForward(%1, ET_Event, Param_Cell, Param_CellByRef)
#define DECL_MENU_POST(%1)			CreateGlobalForward(%1, ET_Ignore, Param_Cell, Param_Cell)
#define DECL_MENU_SELECT_PRE(%1)	CreateGlobalForward(%1, ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef)
#define DECL_MENU_SELECT_POST(%1)	CreateGlobalForward(%1, ET_Ignore, Param_Cell, Param_Cell, Param_Cell)

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("nmrih_simple_combat");
	g_hAllSpellList = CreateArray();
	g_hMenuItemInfo = CreateArray(64);
	g_hMenuItemDisplay = CreateArray(128);
	g_hSellSpellList = CreateArray();
	
	// 属性变动
	g_fwStaminaIncreasePre = CreateGlobalForward("SC_OnStaminaIncreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwStaminaIncreasePost = CreateGlobalForward("SC_OnStaminaIncreasePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwStaminaDecreasePre = CreateGlobalForward("SC_OnStaminaDecreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwStaminaDecreasePost = CreateGlobalForward("SC_OnStaminaDecreasePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwMagicIncreasePre = CreateGlobalForward("SC_OnMagicIncreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwMagicIncreasePost = CreateGlobalForward("SC_OnMagicIncreasePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwMagicDecreasePre = CreateGlobalForward("SC_OnMagicDecreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwMagicDecreasePost = CreateGlobalForward("SC_OnMagicDecreasePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnLevelUpPre = CreateGlobalForward("SC_OnLevelUpPre", ET_Hook, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	g_fwOnLevelUpPost = CreateGlobalForward("SC_OnLevelUpPost", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	g_fwOnGainExperiencePre = CreateGlobalForward("SC_OnGainExperiencePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwOnGainExperiencePost = CreateGlobalForward("SC_OnGainExperiencePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnGainCashPre = CreateGlobalForward("SC_OnGainCashPre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwOnGainCashPost = CreateGlobalForward("SC_OnGainCashPre", ET_Ignore, Param_Cell, Param_Cell);
	
	// 战斗相关
	g_fwOnStartCombatPre = CreateGlobalForward("SC_OnCombatStartPre", ET_Event, Param_Cell);
	g_fwOnStartCombatPost = CreateGlobalForward("SC_OnCombatStartPost", ET_Ignore, Param_Cell);
	g_fwOnLeaveCombatPre = CreateGlobalForward("SC_OnCombatEndPre", ET_Event, Param_Cell);
	g_fwOnLeaveCombatPost = CreateGlobalForward("SC_OnCombatEndPost", ET_Ignore, Param_Cell);
	
	// 菜单
	g_fwOnMenuItemClickPre = CreateGlobalForward("SC_OnMenuItemClickPre", ET_Hook, Param_Cell, Param_String, Param_String);
	g_fwOnMenuItemClickPost = CreateGlobalForward("SC_OnMenuItemClickPost", ET_Ignore, Param_Cell, Param_String, Param_String);
	CreateNative("SC_AddMainMenuItem", Native_AddMainMenuItem);
	CreateNative("SC_RemoveMainMenuItem", Native_RemoveMainMenuItem);
	
	// 属性
	CreateNative("SC_GetClientCash", Native_GetClientCash);
	CreateNative("SC_SetClientCash", Native_SetClientCash);
	CreateNative("SC_GetClientMagic", Native_GetClientMagic);
	CreateNative("SC_SetClientMagic", Native_SetClientMagic);
	CreateNative("SC_GetClientMaxMagic", Native_GetClientMaxMagic);
	CreateNative("SC_SetClientMaxMagic", Native_SetClientMaxMagic);
	CreateNative("SC_GetClientStamina", Native_GetClientStamina);
	CreateNative("SC_SetClientStamina", Native_SetClientStamina);
	CreateNative("SC_GetClientMaxStamina", Native_GetClientMaxStamina);
	CreateNative("SC_SetClientMaxStamina", Native_SetClientMaxStamina);
	CreateNative("SC_GetClientMaxHealth", Native_GetClientMaxHealth);
	CreateNative("SC_SetClientMaxHealth", Native_SetClientMaxHealth);
	
	// 等级
	CreateNative("SC_GetClientExperience", Native_GetClientExperience);
	CreateNative("SC_SetClientExperience", Native_SetClientExperience);
	CreateNative("SC_GetClientLevel", Native_GetClientLevel);
	CreateNative("SC_SetClientLevel", Native_SetClientLevel);
	CreateNative("SC_GetClientNextLevelExperience", Native_GetClientNextLevelExperience);
	CreateNative("SC_SetClientNextLevelExperience", Native_SetClientNextLevelExperience);
	CreateNative("SC_GetClientSkillPoint", Native_GetClientSkillPoint);
	CreateNative("SC_SetClientSkillPoint", Native_SetClientSkillPoint);
	
	// 功能类函数
	CreateNative("SC_GiveClientExperience", Native_GiveClientExperience);
	CreateNative("SC_GiveClientCash", Native_GiveClientCash);
	CreateNative("SC_ShowMainMenu", Native_ShowMainMenu);
	
	// 法术
	g_fwOnUseSpellPre = CreateGlobalForward("SC_OnUseSpellPre", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_fwOnUseSpellPost = CreateGlobalForward("SC_OnUseSpellPost", ET_Ignore, Param_Cell, Param_String);
	g_fwOnGainSpellPre = CreateGlobalForward("SC_OnGainSpellPre", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_fwOnGainSpellPost = CreateGlobalForward("SC_OnGainSpellPost", ET_Ignore, Param_Cell, Param_String);
	CreateNative("SC_CreateSpell", Native_CreateSpell);
	CreateNative("SC_FindSpell", Native_FindSpell);
	CreateNative("SC_RemoveSpell", Native_FreeSpell);
	CreateNative("SC_FakeUseSpell", Native_ForceUseSpell);
	CreateNative("SC_GetSpellCount", Native_GetSpellCount);
	CreateNative("SC_GetSpell", Native_GetSpell);
	
	CreateNative("SC_GetClientSpellCount", Native_GetClientSpellCount);
	CreateNative("SC_GetClientSpell", Native_GetClientSpell);
	CreateNative("SC_GiveClientSpell", Native_GiveClientSpell);
	CreateNative("SC_RemoveClientSpell", Native_RemoveClientSpell);
	CreateNative("SC_FindClientSpell", Native_FindClientSpell);
	
	CreateNative("SC_GetSpellName", Native_GetSpellDisplayName);
	CreateNative("SC_SetSpellName", Native_SetSpellDisplayName);
	CreateNative("SC_GetSpellCost", Native_GetSpellCost);
	CreateNative("SC_SetSpellCost", Native_SetSpellCost);
	CreateNative("SC_GetSpellConsume", Native_GetSpellConsume);
	CreateNative("SC_SetSpellConsume", Native_SetSpellConsume);
	
	return APLRes_Success;
}

#define DECL_NATIVE_GET(%1)		if(argc < 1)\
	ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int client = GetNativeCell(1);\
	if(!IsValidClient(client))\
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");\
	return %1[client]

#define DECL_NATIVE_SET(%1)		if(argc < 1)\
	ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int client = GetNativeCell(1);\
	if(!IsValidClient(client))\
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");\
	return (%1[client] = GetNativeCell(2))

#define DECL_NATIVE_GET_F(%1)		if(argc < 1)\
	ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int client = GetNativeCell(1);\
	if(!IsValidClient(client))\
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");\
	return RoundToZero(%1[client])

#define DECL_NATIVE_SET_F(%1)		if(argc < 1)\
	ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int client = GetNativeCell(1);\
	if(!IsValidClient(client))\
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");\
	return RoundToZero(%1[client] = view_as<float>(GetNativeCell(2)))

public int Native_GetClientCash(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iAccount);
}

public int Native_SetClientCash(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iAccount);
}

public int Native_GetClientMagic(Handle plugin, int argc)
{
	DECL_NATIVE_GET_F(g_fMagic);
}

public int Native_SetClientMagic(Handle plugin, int argc)
{
	DECL_NATIVE_SET_F(g_fMagic);
}

public int Native_GetClientMaxMagic(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iMaxMagic);
}

public int Native_SetClientMaxMagic(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iMaxMagic);
}

public int Native_GetClientStamina(Handle plugin, int argc)
{
	DECL_NATIVE_GET_F(g_fStamina);
}

public int Native_SetClientStamina(Handle plugin, int argc)
{
	DECL_NATIVE_SET_F(g_fStamina);
}

public int Native_GetClientMaxStamina(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iMaxStamina);
}

public int Native_SetClientMaxStamina(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iMaxStamina);
}

public int Native_GetClientMaxHealth(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iExperience);
}

public int Native_SetClientMaxHealth(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iMaxHealth);
}

public int Native_GetClientExperience(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iExperience);
}

public int Native_SetClientExperience(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iExperience);
}

public int Native_GetClientLevel(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iLevel);
}

public int Native_SetClientLevel(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iLevel);
}

public int Native_GetClientNextLevelExperience(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iNextLevel);
}

public int Native_SetClientNextLevelExperience(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iNextLevel);
}

public int Native_GetClientSkillPoint(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iSkillPoint);
}

public int Native_SetClientSkillPoint(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iSkillPoint);
}

public int Native_GiveClientExperience(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	return GiveExperience(client, GetNativeCell(2));
}

public int Native_GiveClientCash(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	return GiveCash(client, GetNativeCell(2));
}

public int Native_ShowMainMenu(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	int menuIndex = GetNativeCell(2);
	switch(menuIndex)
	{
		case 1:
			Cmd_MainMenu(client, 0);
		case 2:
			Cmd_AttributesMenu(client, 0);
		case 3:
			Cmd_SpellMenu(client, 0);
		case 4:
			Cmd_BuySpellMenu(client, 0);
		default:
			return false;
	}
	
	return true;
}

stock StringMap FindSpellByClassname(const char[] classname)
{
	int index = FindSpellIndexByClassname(classname);
	if(index == -1)
		return null;
	
	return g_hAllSpellList.Get(index);
}

stock int FindSpellIndexByClassname(const char[] classname)
{
	int length = g_hAllSpellList.Length;
	char _classname[64];
	
	for(int i = 0; i < length; ++i)
	{
		StringMap spell = g_hAllSpellList.Get(i);
		if(spell == null || !spell.GetString("classname", _classname, 64))
			continue;
		
		if(StrEqual(classname, _classname, false))
			return i;
	}
	
	return -1;
}

#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_

// 获取 玩家(客户端) 的 uid
stock int GetPlayerUserId(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return -1;
	
	// 玩家的 SteamId
	char auth2[64], auth3[64], auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, auth3, 64, false);
	GetClientAuthId(client, AuthId_SteamID64, auth, 64, false);
	ReplaceString(auth2, 64, "STEAM_0:", "STEAM_1:");
	ReplaceString(auth3, 64, "[", "");
	ReplaceString(auth3, 64, "]", "");
	
	DBResultSet res = SQL_Query(g_hDatabase, tr("SELECT uid FROM user_info WHERE sid = '%s' or sid2 = '%s' or sid3 = '%s';",
		auth, auth2, auth3));
	
// #if defined _USE_DATABASE_MYSQL_
	if(res != null && res.RowCount > 0 && res.FetchRow())
// #else
	// if(res != null && res.RowCount > 0)
// #endif	// defined _USE_DATABASE_MYSQL_
	{
		return (g_iClientUserId[client] = res.FetchInt(0));
	}
	
	// 客户端信息
	char name[MAX_NAME_LENGTH], ip[64], country[64];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientIP(client, ip, 64);
	GeoipCountry(ip, country, 64);
	g_hDatabase.Escape(name, name, MAX_NAME_LENGTH);
	
	// 这个仅用于第一次加入时记录，最后一次的信息在 user_online 查看
#if defined _USE_DATABASE_MYSQL_
	SQL_FastQuery(g_hDatabase, tr("INSERT IGNORE INTO user_info (name, sid, ip, sid2, sid3, country) VALUES ('%s', '%s', '%s', '%s', '%s', '%s');",
		name, auth, ip, auth2, auth3, country));
#else
	SQL_FastQuery(g_hDatabase, tr("INSERT OR IGNORE INTO user_info (name, sid, ip, sid2, sid3, country) VALUES ('%s', '%s', '%s', '%s', '%s', '%s');",
		name, auth, ip, auth2, auth3, country));
#endif
	
	res = SQL_Query(g_hDatabase, tr("SELECT uid FROM user_info WHERE sid = '%s' or sid2 = '%s' or sid3 = '%s';",
		auth, auth2, auth3));
	
	// #if defined _USE_DATABASE_MYSQL_
	if(res == null || res.RowCount <= 0 || !res.FetchRow())
// #else
	// if(res == null || res.RowCount <= 0)
// #endif	// defined _USE_DATABASE_MYSQL_
	{
		return -1;
	}
	
	return (g_iClientUserId[client] = res.FetchInt(0));
}
#endif

bool LoadFromFile(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		InitializationPlayer(client);
		return false;
	}
	
	if(g_hPlayerSpell[client] == null)
		g_hPlayerSpell[client] = CreateArray();
	else
		g_hPlayerSpell[client].Clear();
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	int userId = GetPlayerUserId(client);
	Transaction tran = SQL_CreateTransaction();
	
	// 更新数据
#if defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("INSERT IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO nmrih_simple_combat (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO nmrih_simple_combat_spell (uid) VALUES ('%d');", userId));
#else
	tran.AddQuery(tr("INSERT OR IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO nmrih_simple_combat (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO nmrih_simple_combat_spell (uid) VALUES ('%d');", userId));
#endif
	
	SQL_ExecuteTransaction(g_hDatabase, tran);
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	g_hDatabase.Escape(name, name, MAX_NAME_LENGTH);
	
	char ip[64], country[64];
	GetClientIP(client, ip, 64);
	GeoipCountry(ip, country, 64);
	
	tran = SQL_CreateTransaction();
	g_iClientUserId[client] = userId;
	
	// 读取存档
	tran.AddQuery(tr("SELECT max_health, max_stamina, max_magic, accounts, points, level, experience, level_experience FROM nmrih_simple_combat WHERE uid = '%d';", userId));
	tran.AddQuery(tr("SELECT spell FROM nmrih_simple_combat_spell WHERE uid = '%d';", userId));
	
#if !defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("UPDATE user_online SET last = datetime('now') WHERE uid = '%d';", userId));
#endif	// !defined _USE_DATABASE_MYSQL_
	
	tran.AddQuery(tr("UPDATE user_info SET name = '%s', ip = '%s', country = '%s' WHERE uid = %d;",
		name, ip, country, userId));
	
	char city[45], region[45], country_name[45], country_code[3], country_code3[4];
	if(GeoipGetRecord(ip, city, region, country_name, country_code, country_code3))
	{
		// 更新客户端物理地址详细信息
		tran.AddQuery(tr("UPDATE user_online SET country_name = '%s', region = '%s', city = '%s', code = '%s', code3 = '%s' WHERE uid = %d;",
			country_name, region, city, country_code, country_code3, userId));
	}
	
	SQL_ExecuteTransaction(g_hDatabase, tran, SQLTran_LoadPlayerComplete, SQLTran_LoadPlayerFailure, client);
	
#else
	if(g_kvSaveData[client])
	{
		delete g_kvSaveData[client];
		g_kvSaveData[client] = null;
	}
	
	char steamId2[64], steamId3[64], steamId64[64], name[128], ip[32];
	GetClientAuthId(client, AuthId_Steam2, steamId2, 64);
	GetClientAuthId(client, AuthId_Steam3, steamId3, 64);
	GetClientAuthId(client, AuthId_SteamID64, steamId64, 64);
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 32);
	
	g_kvSaveData[client] = CreateKeyValues("PlayerData");
	g_kvSaveData[client].ImportFromFile(tr("%s/%s.txt", g_szSaveDataPath, steamId64));
	
	g_kvSaveData[client].SetString("steamId_2", steamId2);
	g_kvSaveData[client].SetString("steamId_3", steamId3);
	g_kvSaveData[client].SetString("steamId_64", steamId64);
	g_kvSaveData[client].SetString("name", name);
	g_kvSaveData[client].SetString("ip", ip);
	
	g_iMaxHealth[client] = g_kvSaveData[client].GetNum("max_health", 100);
	g_iMaxStamina[client] = g_kvSaveData[client].GetNum("max_stamina", 100);
	g_iMaxMagic[client] = g_kvSaveData[client].GetNum("max_magic", 100);
	g_iAccount[client] = g_kvSaveData[client].GetNum("accounts", 0);
	g_iSkillPoint[client] = g_kvSaveData[client].GetNum("points", 0);
	g_iLevel[client] = g_kvSaveData[client].GetNum("level", 0);
	g_iExperience[client] = g_kvSaveData[client].GetNum("experience", 0);
	g_iNextLevel[client] = g_kvSaveData[client].GetNum("level_experience", g_pCvarLevelExperience.IntValue);
	
	if(g_kvSaveData[client].JumpToKey("spell_list", false))
	{
		char classname[64];
		int length = g_kvSaveData[client].GetNum("count", 0);
		
		for(int i = 0; i < length; ++i)
		{
			g_kvSaveData[client].GetString(tr("spell_%d", i), classname, 64, "");
			if(classname[0] == '\0')
				break;
			
			StringMap spell = FindSpellByClassname(classname);
			if(spell != null)
				g_hPlayerSpell[client].Push(spell);
		}
	}
	
	g_kvSaveData[client].Rewind();
#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	
	return true;
}

#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
public void SQLTran_LoadPlayerComplete(Database db, any client, int numQueries, DBResultSet[] res, any[] unused)
{
	if(!IsValidClient(client))
		return;
	
	if(res[0] != null && res[0].RowCount > 0 && res[0].FetchRow())
	{
		g_iMaxHealth[client] = res[0].FetchInt(0);
		g_iMaxStamina[client] = res[0].FetchInt(1);
		g_iMaxMagic[client] = res[0].FetchInt(2);
		g_iAccount[client] = res[0].FetchInt(3);
		g_iSkillPoint[client] = res[0].FetchInt(4);
		g_iLevel[client] = res[0].FetchInt(5);
		g_iExperience[client] = res[0].FetchInt(6);
		g_iNextLevel[client] = res[0].FetchInt(7);
	}
	else
	{
		// 这种情况一般不会出现的
		LogError("错误：玩家 %N 查询信息失败。", client);
	}
	
	if(res[1] != null && res[1].RowCount > 0 && res[1].FetchRow())
	{
		char spellSeries[512], spellTuple[16][32];
		res[1].FetchString(0, spellSeries, 512);
		int count = ExplodeString(spellSeries, "|", spellTuple, 16, 32);
		
		for(int i = 0; i < count; ++i)
		{
			StringMap spell = FindSpellByClassname(spellTuple[i]);
			if(spell != null)
				g_hPlayerSpell[client].Push(spell);
		}
	}
	else
	{
		// 这种情况一般不会出现的
		LogError("错误：玩家 %N 查询法术失败。", client);
	}
	
	LogMessage("读取玩家 %N 成功，共有 %d 个法术。", client, g_hPlayerSpell[client].Length);
	SetupPlayerHook(client);
}

public void SQLTran_LoadPlayerFailure(Database db, any client, int numQueries, const char[] error, int failIndex, any[] unused)
{
	if(!IsValidClient(client) || failIndex == -1)
		return;
	
	LogError("读取玩家 %N 失败：%s", client, error[failIndex]);
}

#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_

bool SaveToFile(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return false;
	
	if(g_hPlayerSpell[client] == null)
		g_hPlayerSpell[client] = CreateArray();
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	int userId = g_iClientUserId[client];
	if(userId <= 0)
		userId = GetPlayerUserId(client);
	
	Transaction tran = SQL_CreateTransaction();
	
	// 更新数据
#if defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("INSERT IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO nmrih_simple_combat (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO nmrih_simple_combat_spell (uid) VALUES ('%d');", userId));
#else
	tran.AddQuery(tr("INSERT OR IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO nmrih_simple_combat (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO nmrih_simple_combat_spell (uid) VALUES ('%d');", userId));
#endif
	
	SQL_ExecuteTransaction(g_hDatabase, tran);
	
	char classname[64], commit[512] = "";
	int length = g_hPlayerSpell[client].Length;
	tran = SQL_CreateTransaction();
	
	tran.AddQuery(tr("UPDATE nmrih_simple_combat SET max_health = '%d', max_stamina = '%d', max_magic = '%d', accounts = '%d', points = '%d', level = '%d', experience = '%d', level_experience = '%d' WHERE uid = '%d';",
		g_iMaxHealth[client], g_iMaxStamina[client], g_iMaxMagic[client],
		g_iAccount[client], g_iSkillPoint[client],
		g_iLevel[client], g_iExperience[client], g_iNextLevel[client],
		userId));
	
	for(int i = 0; i < length; ++i)
	{
		StringMap spell = g_hPlayerSpell[client].Get(i);
		if(spell == null || !spell.GetString("classname", classname, 64))
			continue;
		
		if(i == 0)
			strcopy(commit, 512, classname);
		else
			StrCat(commit, 512, tr("|%s", classname));
	}
	
	// g_hDatabase.Escape(commit, commit, 512);
	tran.AddQuery(tr("UPDATE nmrih_simple_combat_spell SET spell = '%s' WHERE uid = '%d';",
		commit, userId));
	
	// PrintToChat(client, commit);
	
#if !defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("UPDATE user_online SET last = datetime('now') WHERE uid = '%d';", userId));
#endif	// !defined _USE_DATABASE_MYSQL_
	
	SQL_ExecuteTransaction(g_hDatabase, tran, SQLTran_SavePlayerComplete, SQLTran_SavePlayerFailure, client);
#else
	if(g_kvSaveData[client] == null)
		g_kvSaveData[client] = CreateKeyValues("PlayerData");
	
	char steamId2[64], steamId3[64], steamId64[64], name[128], ip[32];
	GetClientAuthId(client, AuthId_Steam2, steamId2, 64);
	GetClientAuthId(client, AuthId_Steam3, steamId3, 64);
	GetClientAuthId(client, AuthId_SteamID64, steamId64, 64);
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 32);
	
	g_kvSaveData[client].SetString("steamId_2", steamId2);
	g_kvSaveData[client].SetString("steamId_3", steamId3);
	g_kvSaveData[client].SetString("steamId_64", steamId64);
	g_kvSaveData[client].SetString("name", name);
	g_kvSaveData[client].SetString("ip", ip);
	
	g_kvSaveData[client].SetNum("max_health", g_iMaxHealth[client]);
	g_kvSaveData[client].SetNum("max_stamina", g_iMaxStamina[client]);
	g_kvSaveData[client].SetNum("max_magic", g_iMaxMagic[client]);
	g_kvSaveData[client].SetNum("accounts", g_iAccount[client]);
	g_kvSaveData[client].SetNum("points", g_iSkillPoint[client]);
	g_kvSaveData[client].SetNum("level", g_iLevel[client]);
	g_kvSaveData[client].SetNum("experience", g_iExperience[client]);
	g_kvSaveData[client].SetNum("level_experience", g_iNextLevel[client]);
	
	if(g_kvSaveData[client].JumpToKey("spell_list", true))
	{
		char classname[64];
		int length = g_hPlayerSpell[client].Length;
		g_kvSaveData[client].SetNum("count", length);
		
		for(int i = 0; i < length; ++i)
		{
			StringMap spell = g_hPlayerSpell[client].Get(i);
			if(spell == null || !spell.GetString("classname", classname, 64))
				continue;
			
			g_kvSaveData[client].SetString(tr("spell_%d", i), classname);
		}
	}
	
	g_kvSaveData[client].Rewind();
	g_kvSaveData[client].ExportToFile(tr("%s/%s.txt", g_szSaveDataPath, steamId64));
#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	
	return true;
}

#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
public void SQLTran_SavePlayerComplete(Database db, any client, int numQueries, DBResultSet[] res, any[] unused)
{
	if(IsValidClient(client))
		LogMessage("保存玩家 %N 成功，共有 %d 个法术。", client, g_hPlayerSpell[client].Length);
	else
		LogMessage("保存玩家 %d 成功。", client);
}

public void SQLTran_SavePlayerFailure(Database db, any client, int numQueries, const char[] error, int failIndex, any[] unused)
{
	if(failIndex == -1)
		return;
	
	if(IsValidClient(client))
		LogError("保存玩家 %N 失败：%s", client, error[failIndex]);
	else
		LogError("保存玩家 %d 失败：%s", client, error[failIndex]);
}

#endif	// defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_

public int Native_CreateSpell(Handle plugin, int argc)
{
	if(argc < 4)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64], _classname[128];
	GetNativeString(1, classname, 64);
	
	int length = g_hAllSpellList.Length;
	for(int i = 0; i < length; ++i)
	{
		StringMap spell = g_hAllSpellList.Get(i);
		if(spell == null || !spell.GetString("classname", _classname, 128))
			continue;
		
		if(StrEqual(classname, _classname, false))
			return i;
	}
	
	StringMap spell = CreateTrie();
	GetNativeString(2, _classname, 128);
	
	spell.SetString("classname", classname, true);
	spell.SetString("display", _classname, true);
	spell.SetValue("consume", GetNativeCell(3), true);
	spell.SetValue("cost", GetNativeCell(4), true);
	return g_hAllSpellList.Push(spell);
}

public int Native_FindSpell(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	return FindSpellIndexByClassname(classname);
}

public int Native_FreeSpell(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSpellList.Length)
		return false;
	
	StringMap spell = g_hAllSpellList.Get(index);
	g_hAllSpellList.Erase(index);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(g_hPlayerSpell[i] == null)
			continue;
		
		while((index = g_hPlayerSpell[i].FindValue(spell)) != -1)
			g_hPlayerSpell[i].Erase(index);
	}
	
	return true;
}

public int Native_ForceUseSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	char classname[64];
	GetNativeString(2, classname, 64);
	
	return UseSpellByClient(client, classname);
}

public int Native_GetSpellCount(Handle plugin, int argc)
{
	return g_hAllSpellList.Length;
}

public int Native_GetSpell(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSpellList.Length)
		ThrowNativeError(SP_ERROR_PARAM, "索引超出范围");
	
	char classname[64];
	StringMap spell = g_hAllSpellList.Get(index);
	if(spell == null || !spell.GetString("classname", classname, 64))
		return false;
	
	SetNativeString(2, classname, GetNativeCell(3));
	return true;
}

public int Native_GetClientSpellCount(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSpell[client] == null)
		return -1;
	
	return g_hPlayerSpell[client].Length;
}

public int Native_GetClientSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	int index = GetNativeCell(2);
	if(index < 0 || index >= g_hPlayerSpell[client].Length)
		ThrowNativeError(SP_ERROR_PARAM, "索引超出范围");
	
	char classname[64];
	StringMap spell = g_hPlayerSpell[client].Get(index);
	if(spell == null || !spell.GetString("classname", classname, 64))
		return false;
	
	SetNativeString(3, classname, GetNativeCell(4));
	return true;
}

public int Native_GiveClientSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	char classname[64];
	GetNativeString(2, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return -1;
	
	return g_hPlayerSpell[client].Push(spell);
}

public int Native_RemoveClientSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSpell[client] == null)
		return false;
	
	int index = GetNativeCell(2);
	if(index < 0 || index >= g_hPlayerSpell[client].Length)
		return false;
	
	g_hPlayerSpell[index].Erase(index);
	return true;
}

public int Native_FindClientSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	char classname[64], _classname[64];
	GetNativeString(2, classname, 64);
	
	int length = g_hPlayerSpell[client].Length;
	for(int i = 0; i < length; ++i)
	{
		StringMap spell = g_hPlayerSpell[client].Get(i);
		if(spell == null || !spell.GetString("classname", _classname, 64))
			continue;
		
		if(StrEqual(classname, _classname, false))
			return i;
	}
	
	return -1;
}

public int Native_GetSpellDisplayName(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return false;
	
	char display[64];
	spell.GetString("display", display, 64);
	SetNativeString(2, display, GetNativeCell(3));
	return true;
}

public int Native_SetSpellDisplayName(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return false;
	
	char display[64];
	GetNativeString(2, display, 64);
	spell.SetString("display", display, true);
	return true;
}

public int Native_GetSpellConsume(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return -1;
	
	int consume = -1;
	if(!spell.GetValue("consume", consume))
		return -1;
	
	return consume;
}

public int Native_SetSpellConsume(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return false;
	
	return spell.SetValue("consume", GetNativeCell(2));
}

public int Native_GetSpellCost(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return -1;
	
	int cost = -1;
	if(!spell.GetValue("cost", cost))
		return -1;
	
	return cost;
}

public int Native_SetSpellCost(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	StringMap spell = FindSpellByClassname(classname);
	if(spell == null)
		return false;
	
	return spell.SetValue("cost", GetNativeCell(2));
}

public int Native_AddMainMenuItem(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char info[64], display[128];
	GetNativeString(1, info, 64);
	GetNativeString(2, display, 128);
	
	int index = g_hMenuItemInfo.FindString(info);
	if(index > -1)
		return index;
	
	g_hMenuItemDisplay.PushString(display);
	return g_hMenuItemInfo.PushString(info);
}

public int Native_RemoveMainMenuItem(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char info[64];
	GetNativeString(1, info, 64);
	
	int index = g_hMenuItemInfo.FindString(info);
	if(index < 0)
		return false;
	
	g_hMenuItemInfo.Erase(index);
	g_hMenuItemDisplay.Erase(index);
	return true;
}
