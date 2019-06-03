#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <adminmenu>

#define _USE_SKILL_DETECT_			// 使用 l4d2_skill_detect.smx 插件提供的 forward
// #define _USE_PLUGIN_MAX_HEALTH_		// 使用当前插件定义的血量上限代替 m_iMaxHealth 作为标准
// #define _USE_CONSOLE_MESSAGE_		// 当玩家获得奖励时打印控制台信息
// #define _USE_DATABASE_SQLITE_		// 使用 SQLite 储存数据
#define _USE_DATABASE_MYSQL_		// 使用 MySQL 储存数据
// #define _USE_DETOUR_FUNC_		// 使用 hook 伤害

#if defined _USE_SKILL_DETECT_
#include <l4d2_skill_detect>
#endif	// _USE_SKILL_DETECT_

#if defined _USE_DETOUR_FUNC_
#include <dhooks>
#endif	// _USE_DETOUR_FUNC_

#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
#include <geoip>
#include <geoipcity>

#define _SQL_CONNECT_HOST_		"zonde306.site"
#define _SQL_CONNECT_PORT_		"3306"
#define _SQL_CONNECT_DATABASE_	"source_game"
#define _SQL_CONNECT_USER_		"srcgame"
#define _SQL_CONNECT_PASSWORD_	"abby6382"
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_

#define PLUGIN_VERSION	"0.2"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "简单战斗系统",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

enum()
{
	Z_COMMON = 0,
	Z_SMOKER = 1,
	Z_BOOMER = 2,
	Z_HUNTER = 3,
	Z_SPITTER = 4,
	Z_JOCKEY = 5,
	Z_CHARGER = 6,
	Z_WITCH = 7,
	Z_TANK = 8,
	Z_SURVIVOR = 9
};

ArrayList g_hMenuItemInfo, g_hMenuItemDisplay;
ArrayList g_hPlayerSkill[MAXPLAYERS+1], g_hAllSkillList;
ArrayList g_hPlayerSpell[MAXPLAYERS+1], g_hAllSpellList, g_hSellSpellList;

bool g_bDefenseFriendly, g_bDamageFriendly, g_bSprintAllow, g_bMenuFlush, g_bSprintAttack,
	g_bSprintShove, g_bSprintJump, g_bHurtBonus;

// float g_fCombatRadius;
float g_fCombatDelay, g_fThinkInterval, g_fSprintWalk, g_fSprintDuck, g_fSprintWater,
	g_fStandingDelay, g_fStandingFactor, g_fDifficultyFactor, g_fCombatStamina, g_fSafeStamina, g_fCombatMagic,
	g_fSafeMagic, g_fBlockRevive, g_fCombatWillpower, g_fSafeWillpower, g_fMaxFakeDamage;

int g_iDefenseLimit, g_iDamageLimit, g_iSprintLimit, g_iSprintPerSecond, g_iStandingLimit, g_iDamageMin,
	g_iDefenseMin, g_iSlotMax, g_iSlotLevel, g_iSlotCost, g_iShowBonus;

/*
float g_fDefaultSpeed[10];
ConVar g_hCvarSurvivorSpeed, g_hCvarDuckSpeed, g_hCvarSmokerSpeed, g_hCvarBoomerSpeed, g_hCvarHunterSpeed,
	g_hCvarSpitterSpeed, g_hCvarJockeySpeed, g_hCvarChargerSpeed, g_hCvarTankSpeed, g_hCvarAdrenSpeed;
*/

ConVar g_hCvarDifficulty, g_hCvarMaxHealth, g_hCvarMaxBufferHealth;

// ConVar g_pCvarCombatRadius;
ConVar g_pCvarAllow, g_pCvarDefenseFactor, g_pCvarDefenseChance, g_pCvarDefenseLimit,
	g_pCvarStaminaRate, g_pCvarStaminaIdleRate, g_pCvarMagicRate, g_pCvarMagicIdleRate,
	g_pCvarCombatDelay, g_pCvarDamageFactor, g_pCvarDamageChance, g_pCvarDamageLimit,
	g_pCvarDefenseFriendly, g_pCvarDamageFriendly, g_pCvarLevelExperience, g_pCvarLevelPoint,
	g_pCvarPointAmount, g_pCvarSprintLimit, g_pCvarSprintSpeed, g_pCvarSprintDuckSpeed,
	g_pCvarSprintWaterSpeed, g_pCvarSprintConsume, g_pCvarSprintAllow, g_pCvarShopCount,
	g_pCvarDifficulty, g_pCvarStandingDelay, g_pCvarStandingRate, g_pCvarStandingLimit,
	g_pCvarThinkInterval, g_pCvarDamageMin, g_pCvarDefenseMin, g_pCvarBlockRevive,
	g_pCvarTankPropExperience, g_pCvarTankPropCash, g_pCvarMenuFlush, g_pCvarWillpowerIdleRate,
	g_pCvarWillpowerRate, g_pCvarSprintAttack, g_pCvarSprintShove, g_pCvarSprintJump,
	g_pCvarHurtBonus, g_pCvarMaxFakeDamage, g_pCvarSlotLevel, g_pCvarSlotCost, g_pCvarSlotMax,
	g_pCvarSkillChooseInterval, g_pCvarShowBonus, g_pCvarSqlConfig;

// 玩家属性
float g_fStamina[MAXPLAYERS+1], g_fMagic[MAXPLAYERS+1], g_fWillpower[MAXPLAYERS+1];
int g_iMaxStamina[MAXPLAYERS+1], g_iMaxMagic[MAXPLAYERS+1], g_iMaxHealth[MAXPLAYERS+1], g_iMaxWillpower[MAXPLAYERS+1];
int g_iExperience[MAXPLAYERS+1], g_iLevel[MAXPLAYERS+1], g_iNextLevel[MAXPLAYERS+1], g_iSkillPoint[MAXPLAYERS+1],
	g_iAccount[MAXPLAYERS+1], g_iDefaultHealth[MAXPLAYERS+1], g_iSkillSlot[MAXPLAYERS+1];
float g_fDefenseChance[MAXPLAYERS+1], g_fDefenseFactor[MAXPLAYERS+1], g_fDamageChance[MAXPLAYERS+1],
	g_fDamageFactor[MAXPLAYERS+1], g_fNextSkillChoose[MAXPLAYERS+1];

// 玩家状态
Handle g_hTimerCombatEnd[MAXPLAYERS+1];
bool g_bInBattle[MAXPLAYERS+1], g_bInSprint[MAXPLAYERS+1];
float g_fSprintSpeed[MAXPLAYERS+1], g_fNextStandingTime[MAXPLAYERS+1];

// 存档数据
KeyValues g_kvSaveData[MAXPLAYERS+1];
char g_szSaveDataPath[260];

// 偏移地址
// int g_iOffsetVelocity = -1;

// 伤害统计
int g_iDamageTotal[MAXPLAYERS+1][MAXPLAYERS+1], g_iDamageSpitTotal[MAXPLAYERS+1], g_iDamageAssistTotal[MAXPLAYERS+1],
	g_iCommonKillTotal[MAXPLAYERS+1], g_iAttackTotal[MAXPLAYERS+1], g_iTankPropTotal[MAXPLAYERS+1];

// Boomer 胆汁助攻检查
int g_iVomitAttacker[MAXPLAYERS+1];
float g_fVomitEndTime[MAXPLAYERS+1];

// 中断恢复检查
float g_fNextReviveTime[MAXPLAYERS+1] = {0.0, ...};

// Hunter 突袭伤害
float g_fVecHunterStart[MAXPLAYERS+1][3];

// Witch 伤害统计
ArrayList g_hWitchDamage = null;

#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
// 数据库
Database g_hDatabase = null;
// 玩家的 uid
int g_iClientUserId[MAXPLAYERS+1];
#endif

// 生还者 经验/金钱 获得
ConVar g_pCvarKilledExperience[Z_SURVIVOR+1], g_pCvarKilledCash[Z_SURVIVOR+1],
	g_pCvarReviveExperience, g_pCvarReviveCash, g_pCvarDefibExperience, g_pCvarDefibCash,
	g_pCvarRespawnExperience, g_pCvarRespawnCash, g_pCvarLedgeExperience, g_pCvarLedgeCash,
	g_pCvarPillExperience, g_pCvarPillCash, g_pCvarAdrenExperience, g_pCvarAdrenCash,
	g_pCvarProtectExperience, g_pCvarProtectCash, g_pCvarRescueExperience, g_pCvarRescueCash,
	g_pCvarHealExperience, g_pCvarHealCash, g_pCvarHeadshotExperience, g_pCvarHeadshotCash,
	g_pCvarRealExperience, g_pCvarRealCash, g_pCvarTempExperience, g_pCvarTempCash,
	g_pCvarAliveExperience, g_pCvarAliveCash;

// 感染者 经验/金钱 获得
ConVar g_pCvarClawExperience[Z_WITCH], g_pCvarClawCash[Z_WITCH], g_pCvarRockExperience, g_pCvarRockCash,
	g_pCvarSlapExperience, g_pCvarSlapCash, g_pCvarBileExperience, g_pCvarBileCash,
	g_pCvarSpitExperience, g_pCvarSpitCash, g_pCvarPullingExperience, g_pCvarPullingCash,
	g_pCvarPouncedExperience, g_pCvarPouncedCash, g_pCvarRideExperience, g_pCvarRideCash,
	g_pCvarImpactExperience, g_pCvarImpactCash, g_pCvarPummelExperience, g_pCvarPummelCash,
	g_pCvarCarryExperience, g_pCvarCarryCash, g_pCvarAttackExperience, g_pCvarAttackCash,
	g_pCvarAssistExperience, g_pCvarAssistCash, g_pCvarPounceDmgExperience, g_pCvarPounceDmgCash;

// 使用 l4d2_skill_detect 获得的奖励
#if defined _USE_SKILL_DETECT_
ConVar g_pCvarSkeetExperience, g_pCvarSkeetCash, g_pCvarHurtSkeetExperience, g_pCvarHurtSkeetCash,
	g_pCvarLeveledExperience, g_pCvarLeveledCash, g_pCvarHurtLeveledExperience, g_pCvarHurtLeveledCash,
	g_pCvarCrownExperience, g_pCvarCrownCash, g_pCvarHurtCrownExperience, g_pCvarHurtCrownCash,
	g_pCvarTongueCutExperience, g_pCvarTongueCutCash, g_pCvarTongueClearExperience, g_pCvarTongueClearCash,
	g_pCvarRockSkeetExperience, g_pCvarRockSkeetCash, g_pCvarBunnyHopExperience, g_pCvarBunnyHopCash,
	g_pCvarBoomerPopExperience, g_pCvarBoomerPopCash, g_pCvarHighPounceExperience, g_pCvarHighPounceCash,
	g_pCvarDeathChargeExperience, g_pCvarDeathChargeCash, g_pCvarHighRideExperience, g_pCvarHighRideCash,
	g_pCvarVomitLandedExperience, g_pCvarVomitLandedCash;
#endif	// _USE_SKILL_DETECT_

#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	ConVar g_pCvarCoinAlive, g_pCvarCoinDead;
	int g_iCoinAlive, g_iCoinDead;
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_

// 最小触发几率
const float MIN_TRIGGER_CHANCE = 0.0001;

// 函数指针
Handle g_pfnAllowTakeDamage;

public void OnPluginStart()
{
	CreateConVar("sc2_version", PLUGIN_VERSION, "插件版本", CVAR_FLAGS);
	g_pCvarAllow = CreateConVar("sc2_allow", "0", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarMenuFlush = CreateConVar("sc2_menu_flush", "1", "是否菜单自动刷新", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSqlConfig = CreateConVar("sc2_sql_config", "playerstats", "数据库配置", CVAR_FLAGS);
	
	// g_pCvarCombatRadius = CreateConVar("sc2_combat_raduis", "300.0", "在多大范围内有敌人视为战斗状态", CVAR_FLAGS, true, 10.0);
	g_pCvarCombatDelay = CreateConVar("sc2_combat_leave_delay", "3.0", "离开战斗状态的延迟", CVAR_FLAGS, true, 0.1);
	g_pCvarHurtBonus = CreateConVar("sc2_hurt_bonus", "1", "是否开启杀死特感根据伤害来奖励.0=只有杀死者有奖励.1=助攻者也有奖励", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarShowBonus = CreateConVar("sc2_show_bonus", "0", "是否显示奖励.0=关闭.1=显示经验.2=显示金钱.3=经验/金钱.4=显示累计", CVAR_FLAGS, true, 0.0, true, 7.0);
	
	g_pCvarStaminaRate = CreateConVar("sc2_stamina_combat_rate", "0.025", "战斗时每秒恢复耐力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStaminaIdleRate = CreateConVar("sc2_stamina_safe_rate", "0.1", "非战斗时每秒恢复耐力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarMagicRate = CreateConVar("sc2_magic_combat_rate", "0.05", "战斗时每秒恢复魔力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarMagicIdleRate = CreateConVar("sc2_magic_safe_rate", "0.1", "非战斗时每秒恢复魔力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarWillpowerRate = CreateConVar("sc2_willpower_combat_rate", "0.05", "战斗时每秒恢复精力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarWillpowerIdleRate = CreateConVar("sc2_willpower_safe_rate", "0.1", "非战斗时每秒恢复精力百分比", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	g_pCvarDefenseChance = CreateConVar("sc2_stamina_defense_chance", "1.0", "耐力抵挡伤害触发几率（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseLimit = CreateConVar("sc2_stamina_defense_limit", "2.0", "耐力至少有多少才能触发抵挡伤害", CVAR_FLAGS, true, 0.0);
	g_pCvarDefenseFactor = CreateConVar("sc2_stamina_defense_factor", "0.5", "耐力抵挡伤害的百分比（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseFriendly = CreateConVar("sc2_stamina_defense_friendly", "1", "耐力抵挡伤害是否支持队友伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDefenseMin = CreateConVar("sc2_stamina_defense_min", "1", "耐力抵挡伤害触发所需最小伤害", CVAR_FLAGS, true, 0.0);
	
	g_pCvarDamageChance = CreateConVar("sc2_willpower_damage_chance", "1.0", "精力增加伤害触发几率（1.0=100％）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDamageLimit = CreateConVar("sc2_willpower_damage_limit", "2.0", "精力至少有多少才能触发增加伤害", CVAR_FLAGS, true, 0.0);
	g_pCvarDamageFactor = CreateConVar("sc2_willpower_damage_factor", "1.0", "精力增加伤害的百分比（1.0=100％）", CVAR_FLAGS, true, 0.0);
	g_pCvarDamageFriendly = CreateConVar("sc2_willpower_damage_friendly", "0", "精力增加伤害是否支持队友伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDamageMin = CreateConVar("sc2_willpower_damage_min", "1", "精力增加伤害触发所需最小伤害", CVAR_FLAGS, true, 0.0);
	
	g_pCvarSprintAllow = CreateConVar("sc2_sprint_allow", "1", "是否开启冲刺功能", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSprintLimit = CreateConVar("sc2_sprint_limit", "10", "耐力必须大于多少才能冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintConsume = CreateConVar("sc2_sprint_consume", "20", "冲刺每秒消耗多少耐力", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintSpeed = CreateConVar("sc2_sprint_speed", "1.5", "站立时冲刺速度倍数（1.0=100％）.0=禁止站立冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintDuckSpeed = CreateConVar("sc2_sprint_duck_speed", "0", "蹲下时冲刺速度倍数(基于蹲下移动速度).0=禁止蹲下冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintWaterSpeed = CreateConVar("sc2_sprint_water_speed", "0", "水中时冲刺速度倍数(基于水中移动速度).0=禁止水中冲刺", CVAR_FLAGS, true, 0.0);
	g_pCvarSprintAttack = CreateConVar("sc2_sprint_attack", "1", "是否允许冲刺时攻击（左键）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSprintShove = CreateConVar("sc2_sprint_shove", "1", "是否允许冲刺时推（右键）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSprintJump = CreateConVar("sc2_sprint_jump", "1", "是否允许冲刺时跳跃（空格键）", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	g_pCvarStandingDelay = CreateConVar("sc2_standing_delay", "3.0", "站立不动多长时间(秒)自动回血", CVAR_FLAGS, true, 0.0);
	g_pCvarStandingRate = CreateConVar("sc2_standing_factor", "0.1", "站立回血百分比(魔力上限)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarStandingLimit = CreateConVar("sc2_standing_limit", "10.0", "魔力至少需要多少才会启动回血", CVAR_FLAGS, true, 0.0);
	
	g_pCvarLevelExperience = CreateConVar("sc2_level_experience", "306", "每升一级需要多少经验值", CVAR_FLAGS, true, 1.0);
	g_pCvarLevelPoint = CreateConVar("sc2_level_point", "1", "每升一级获得多少技能点", CVAR_FLAGS, true, 0.0);
	g_pCvarPointAmount = CreateConVar("sc2_point_amount", "10", "每一个技能点可以增加多少上限", CVAR_FLAGS, true, 0.0);
	g_pCvarShopCount = CreateConVar("sc2_shop_count", "7", "商店出售法术数量", CVAR_FLAGS, true, 0.0);
	g_pCvarThinkInterval = CreateConVar("sc2_think_interval", "9.0", "菜单和奖励思考间隔。\n较小的值可以提升精度，但是会占用更多的 CPU", CVAR_FLAGS, true, 0.1, true, 60.0);
	g_pCvarDifficulty = CreateConVar("sc2_bouns_difficulty", "0.5", "根据难度进行奖励加成百分比(简单=当前数值.普通=当前×2.困难=当前×2.25.专家=当前×2.5)", CVAR_FLAGS, true, 0.1);
	g_pCvarBlockRevive = CreateConVar("sc2_block_by_hurt", "3", "被攻击后中断多少秒回复耐力和魔力", CVAR_FLAGS, true, 0.0);
	g_pCvarMaxFakeDamage = CreateConVar("sc2_fake_damage", "1.0", "溢出伤害上限(倍率)", CVAR_FLAGS, true, 0.0, true, 10.0);
	
	g_pCvarSkillChooseInterval = CreateConVar("sc2_skill_choose_interval", "120.0", "重新选择技能间隔，防止刷技能", CVAR_FLAGS, true, 9.0, true, 360.0);
	g_pCvarSlotLevel = CreateConVar("sc2_slot_level", "10", "每多少级解锁一个技能槽", CVAR_FLAGS, true, 1.0, true, 100.0);
	g_pCvarSlotCost = CreateConVar("sc2_slot_cost", "2500", "解锁技能槽每级需要多少金钱", CVAR_FLAGS, true, 1.0, true, 65535.0);
	g_pCvarSlotMax = CreateConVar("sc2_slot_max", "8", "技能槽获取上限", CVAR_FLAGS, true, 0.0, true, 8.0);
	
	// 经验获得
	g_pCvarKilledExperience[Z_COMMON] = CreateConVar("sc2_exp_kill_common", "3", "击杀 普感 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_SMOKER] = CreateConVar("sc2_exp_kill_smoker", "20", "击杀 Smoker 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_BOOMER] = CreateConVar("sc2_exp_kill_boomer", "15", "击杀 Boomer 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_HUNTER] = CreateConVar("sc2_exp_kill_hunter", "25", "击杀 Hunter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_SPITTER] = CreateConVar("sc2_exp_kill_spitter", "12", "击杀 Spitter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_JOCKEY] = CreateConVar("sc2_exp_kill_jockey", "23", "击杀 Jockey 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_CHARGER] = CreateConVar("sc2_exp_kill_charger", "30", "击杀 Charger 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_WITCH] = CreateConVar("sc2_exp_kill_witch", "50", "击杀 Witch 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_TANK] = CreateConVar("sc2_exp_kill_tank", "100", "击杀 Tank 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledExperience[Z_SURVIVOR] = CreateConVar("sc2_exp_kill_survivor", "1", "击杀 生还者 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHeadshotExperience = CreateConVar("sc2_exp_kill_headshot", "1.5", "爆头击杀获得经验倍率", CVAR_FLAGS, true, 0.0);
	g_pCvarReviveExperience = CreateConVar("sc2_exp_revive", "10", "救起倒地队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarDefibExperience = CreateConVar("sc2_exp_defib", "25", "电击器复活队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRespawnExperience = CreateConVar("sc2_exp_respawn", "9", "开门复活队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarLedgeExperience = CreateConVar("sc2_exp_ledge", "2", "拉起挂边队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPillExperience = CreateConVar("sc2_exp_pills", "7", "给队友递药 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarAdrenExperience = CreateConVar("sc2_exp_adren", "5", "给队友递针 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarProtectExperience = CreateConVar("sc2_exp_protect", "3", "保护队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRescueExperience = CreateConVar("sc2_exp_rescue", "4", "营救被控队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHealExperience = CreateConVar("sc2_exp_heal", "35", "治疗队友 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRealExperience = CreateConVar("sc2_exp_mission_real_health", "2", "过关每有1实血 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTempExperience = CreateConVar("sc2_exp_mission_temp_health", "1", "过关每有1虚血 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarAliveExperience = CreateConVar("sc2_exp_mission_alive", "100", "过关每有1活着生还者 获得多少经验", CVAR_FLAGS, true, 0.0);
	
	g_pCvarClawExperience[Z_SMOKER] = CreateConVar("sc2_exp_claw_smoker", "5", "使用 Smoker 爪击每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarClawExperience[Z_BOOMER] = CreateConVar("sc2_exp_claw_boomer", "6", "使用 Boomer 爪击每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarClawExperience[Z_HUNTER] = CreateConVar("sc2_exp_claw_hunter", "10", "使用 Hunter 爪击每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarClawExperience[Z_SPITTER] = CreateConVar("sc2_exp_claw_spitter", "8", "使用 Spitter 爪每下击获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarClawExperience[Z_JOCKEY] = CreateConVar("sc2_exp_claw_jockey", "6", "使用 Jockey 爪击每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarClawExperience[Z_CHARGER] = CreateConVar("sc2_exp_claw_charger", "7", "使用 Charger 爪击每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarSlapExperience = CreateConVar("sc2_exp_claw_tank", "15", "使用 Tank 拍打获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRockExperience = CreateConVar("sc2_exp_rock_tank", "20", "使用 Tank 投石获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarBileExperience = CreateConVar("sc2_exp_boomer_vomit", "25", "使用 Boomer 喷人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarSpitExperience = CreateConVar("sc2_exp_spitter_spit", "2", "使用 Spitter 烫人每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPullingExperience = CreateConVar("sc2_exp_smoker_pull", "15", "使用 Smoker 拉人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPouncedExperience = CreateConVar("sc2_exp_hunter_pounced", "20", "使用 Hunter 扑人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPounceDmgExperience = CreateConVar("sc2_exp_hunter_pounce_dmg", "2", "使用 Hunter 扑人每点伤害获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRideExperience = CreateConVar("sc2_exp_jockey_ride", "18", "使用 Jockey 套头获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarCarryExperience = CreateConVar("sc2_exp_charger_carry", "17", "使用 Charger 带人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarPummelExperience = CreateConVar("sc2_exp_charger_pummel", "10", "使用 Charger 带人锤地板获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarImpactExperience = CreateConVar("sc2_exp_charger_impact", "12", "使用 Charger 撞飞人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarAttackExperience = CreateConVar("sc2_exp_infected_attack", "3", "特感控人后每次攻击获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarAssistExperience = CreateConVar("sc2_exp_vomit_assists", "2", "使用 Boomer 胆汁助攻每下获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTankPropExperience = CreateConVar("sc2_exp_tank_prop", "5", "使用 Tank 打铁伤害每下获得多少经验", CVAR_FLAGS, true, 0.0);
	
	// 金钱获得
	g_pCvarKilledCash[Z_COMMON] = CreateConVar("sc2_cash_kill_common", "2", "击杀 普感 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_SMOKER] = CreateConVar("sc2_cash_kill_smoker", "10", "击杀 Smoker 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_BOOMER] = CreateConVar("sc2_cash_kill_boomer", "5", "击杀 Boomer 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_HUNTER] = CreateConVar("sc2_cash_kill_hunter", "12", "击杀 Hunter 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_SPITTER] = CreateConVar("sc2_cash_kill_sptter", "5", "击杀 Spitter 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_JOCKEY] = CreateConVar("sc2_cash_kill_jockey", "15", "击杀 Jockey 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_CHARGER] = CreateConVar("sc2_cash_kill_charger", "20", "击杀 Charger 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_WITCH] = CreateConVar("sc2_cash_kill_witch", "25", "击杀 Witch 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_TANK] = CreateConVar("sc2_cash_kill_tank", "100", "击杀 Tank 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarKilledCash[Z_SURVIVOR] = CreateConVar("sc2_cash_kill_survivor", "1", "击杀 生还者 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarHeadshotCash = CreateConVar("sc2_cash_kill_headshot", "1.25", "爆头击杀获得金钱倍率", CVAR_FLAGS, true, 0.0);
	g_pCvarReviveCash = CreateConVar("sc2_cash_revive", "5", "救起倒地队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarDefibCash = CreateConVar("sc2_cash_defib", "10", "电击器复活队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRespawnCash = CreateConVar("sc2_cash_respawn", "2", "开门复活队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarLedgeCash = CreateConVar("sc2_cash_ledge", "1", "拉起挂边队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPillCash = CreateConVar("sc2_cash_pills", "4", "给队友递药 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarAdrenCash = CreateConVar("sc2_cash_adren", "3", "给队友递针 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarProtectCash = CreateConVar("sc2_cash_protect", "2", "保护队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRescueCash = CreateConVar("sc2_cash_rescue", "6", "营救被控队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarHealCash = CreateConVar("sc2_cash_heal", "15", "治疗队友 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRealCash = CreateConVar("sc2_cash_mission_real_health", "2", "过关每有1实血 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarTempCash = CreateConVar("sc2_cash_mission_temp_health", "1", "过关每有1虚血 获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarAliveCash = CreateConVar("sc2_cash_mission_alive", "100", "过关每有1活着生还者 获得多少金钱", CVAR_FLAGS, true, 0.0);
	
	g_pCvarClawCash[Z_SMOKER] = CreateConVar("sc2_cash_claw_smoker", "5", "使用 Smoker 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarClawCash[Z_BOOMER] = CreateConVar("sc2_cash_claw_boomer", "6", "使用 Boomer 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarClawCash[Z_HUNTER] = CreateConVar("sc2_cash_claw_hunter", "10", "使用 Hunter 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarClawCash[Z_SPITTER] = CreateConVar("sc2_cash_claw_spitter", "8", "使用 Spitter 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarClawCash[Z_JOCKEY] = CreateConVar("sc2_cash_claw_jockey", "6", "使用 Jockey 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarClawCash[Z_CHARGER] = CreateConVar("sc2_cash_claw_charger", "7", "使用 Charger 爪击每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarSlapCash = CreateConVar("sc2_cash_claw_tank", "15", "使用 Tank 拍打获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRockCash = CreateConVar("sc2_cash_rock_tank", "20", "使用 Tank 投石获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarBileCash = CreateConVar("sc2_cash_boomer_vomit", "25", "使用 Boomer 喷人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarSpitCash = CreateConVar("sc2_cash_spitter_spit", "2", "使用 Spitter 烫人每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPullingCash = CreateConVar("sc2_cash_smoker_pull", "15", "使用 Smoker 拉人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPouncedCash = CreateConVar("sc2_cash_hunter_pounced", "20", "使用 Hunter 扑人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPounceDmgCash = CreateConVar("sc2_cash_hunter_pounce_dmg", "1", "使用 Hunter 扑人每点伤害获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarRideCash = CreateConVar("sc2_cash_jockey_ride", "18", "使用 Jockey 套头获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarCarryCash = CreateConVar("sc2_cash_charger_carry", "17", "使用 Charger 带人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarPummelCash = CreateConVar("sc2_cash_charger_pummel", "10", "使用 Charger 带人锤地板获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarImpactCash = CreateConVar("sc2_cash_charger_impact", "12", "使用 Charger 撞飞人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarAttackCash = CreateConVar("sc2_cash_infected_attack", "3", "特感控人后每次攻击获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarAssistCash = CreateConVar("sc2_cash_vomit_assists", "2", "使用 Boomer 胆汁助攻每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarTankPropCash = CreateConVar("sc2_cash_tank_prop", "5", "使用 Tank 打铁伤害每下获得多少金钱", CVAR_FLAGS, true, 0.0);
	
#if defined _USE_SKILL_DETECT_
	// l4d2_skill_detect 经验获得
	g_pCvarSkeetExperience = CreateConVar("sc2_exp_skeet", "100", "秒飞扑 Hunter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtSkeetExperience = CreateConVar("sc2_exp_hurt_skeet", "50", "打死飞扑 Hunter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarLeveledExperience = CreateConVar("sc2_exp_level", "150", "近战秒冲锋 Charger 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtLeveledExperience = CreateConVar("sc2_exp_hurt_level", "75", "近战砍死冲锋 Charger 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarCrownExperience = CreateConVar("sc2_exp_crown", "50", "喷子秒 Witch 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtCrownExperience = CreateConVar("sc2_exp_hurt_crown", "75", "喷子引秒 Witch 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTongueCutExperience = CreateConVar("sc2_exp_cut", "65", "砍 Smoker 舌头获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTongueClearExperience = CreateConVar("sc2_exp_selfclear", "45", "被 Smoker 拉自救获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRockSkeetExperience = CreateConVar("sc2_exp_rock", "30", "打爆 Tank 石头获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarBunnyHopExperience = CreateConVar("sc2_exp_bhop", "10", "连跳 每次获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarBoomerPopExperience = CreateConVar("sc2_exp_pop", "25", "打爆尝试空降的 Boomer 每次获得多少经验", CVAR_FLAGS, true, 0.0);
	
	g_pCvarHighPounceExperience = CreateConVar("sc2_exp_hunter_high_pounce", "35", "使用 Hunter 高空砸人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarDeathChargeExperience = CreateConVar("sc2_exp_charger_dead_charge", "45", "使用 Charger 秒人获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHighRideExperience = CreateConVar("sc2_exp_jockey_high_ride", "30", "使用 Jockey 空投骑脸获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarVomitLandedExperience = CreateConVar("sc2_exp_boomer_landed", "28", "使用 Boomer 空投爆炸获得多少经验", CVAR_FLAGS, true, 0.0);
	
	// l4d2_skill_detect 金钱获得
	g_pCvarSkeetCash = CreateConVar("sc2_cash_skeet", "100", "秒飞扑 Hunter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtSkeetCash = CreateConVar("sc2_cash_hurt_skeet", "50", "打死飞扑 Hunter 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarLeveledCash = CreateConVar("sc2_cash_level", "150", "近战秒冲锋 Charger 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtLeveledCash = CreateConVar("sc2_cash_hurt_level", "75", "近战砍死冲锋 Charger 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarCrownCash = CreateConVar("sc2_cash_crown", "50", "喷子秒 Witch 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarHurtCrownCash = CreateConVar("sc2_cash_hurt_crown", "75", "喷子引秒 Witch 获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTongueCutCash = CreateConVar("sc2_cash_cut", "65", "砍 Smoker 舌头获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarTongueClearCash = CreateConVar("sc2_cash_selfclear", "45", "被 Smoker 拉自救获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarRockSkeetCash = CreateConVar("sc2_cash_rock", "30", "打爆 Tank 石头获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarBunnyHopCash = CreateConVar("sc2_cash_bhop", "10", "连跳 每次获得多少经验", CVAR_FLAGS, true, 0.0);
	g_pCvarBoomerPopCash = CreateConVar("sc2_cash_pop", "25", "打爆尝试空降的 Boomer 每次获得多少经验", CVAR_FLAGS, true, 0.0);
	
	g_pCvarHighPounceCash = CreateConVar("sc2_cash_hunter_high_pounce", "35", "使用 Hunter 高空砸人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarDeathChargeCash = CreateConVar("sc2_cash_charger_dead_charge", "45", "使用 Charger 秒人获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarHighRideCash = CreateConVar("sc2_cash_jockey_high_ride", "30", "使用 Jockey 空投骑脸获得多少金钱", CVAR_FLAGS, true, 0.0);
	g_pCvarVomitLandedCash = CreateConVar("sc2_cash_boomer_landed", "28", "使用 Boomer 空投爆炸获得多少金钱", CVAR_FLAGS, true, 0.0);
#endif	// _USE_SKILL_DETECT_
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	g_pCvarCoinAlive = CreateConVar("sc2_coin_alive", "2", "活着每秒获得多少硬币", CVAR_FLAGS, true, 0.0);
	g_pCvarCoinDead = CreateConVar("sc2_coin_dead", "1", "死亡每秒获得多少硬币", CVAR_FLAGS, true, 0.0);
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	
	AutoExecConfig(true, "l4d2_smiple_combat2");
	BuildPath(Path_SM, g_szSaveDataPath, 260, "data/l4d2_simple_combat");
	g_hWitchDamage = CreateArray(MAXPLAYERS + 1);
	
	RegConsoleCmd("sm_sc", Cmd_MainMenu);
	RegConsoleCmd("sm_lv", Cmd_MainMenu);
	RegConsoleCmd("sm_rpg", Cmd_MainMenu);
	RegConsoleCmd("sm_spell", Cmd_SpellMenu);
	RegConsoleCmd("sm_skill", Cmd_SpellMenu);
	RegConsoleCmd("sm_attr", Cmd_AttributesMenu);
	RegConsoleCmd("sm_attributes", Cmd_AttributesMenu);
	RegConsoleCmd("sm_buyspell", Cmd_BuySpellMenu);
	// RegConsoleCmd("sm_buyskill", Cmd_BuySpellMenu);
	RegConsoleCmd("sm_skill", Cmd_SkillMenu);
	
	RegAdminCmd("sm_fullall", Cmd_DebugFullAll, ADMFLAG_CHEATS);
	RegAdminCmd("sm_giveexp", Cmd_DebugGiveExperience, ADMFLAG_CHEATS);
	RegAdminCmd("sm_givecash", Cmd_DebugGiveCash, ADMFLAG_CHEATS);
	
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
	g_hCvarSurvivorSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarDuckSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarSmokerSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarBoomerSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarHunterSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarJockeySpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarChargerSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarTankSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	g_hCvarAdrenSpeed.AddChangeHook(ConVarHook_OnSpeedChanged);
	ConVarHook_OnSpeedChanged(null, "", "");
	*/
	
	g_hCvarDifficulty = FindConVar("z_difficulty");
	g_hCvarMaxHealth = FindConVar("first_aid_kit_max_heal");
	g_hCvarMaxBufferHealth = FindConVar("pain_pills_health_threshold");
	g_fDifficultyFactor = g_pCvarDifficulty.FloatValue;
	g_hCvarDifficulty.AddChangeHook(ConVarHook_OnDifficultyChanged);
	
	ConVarHook_OnValueChanged(null, "", "");
	// g_pCvarCombatRadius.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarCombatDelay.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarStaminaRate.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarStaminaIdleRate.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarMagicRate.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarMagicIdleRate.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarStandingDelay.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintAllow.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintConsume.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintSpeed.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarThinkInterval.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarDefenseMin.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarDamageMin.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarBlockRevive.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarMenuFlush.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintAttack.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintShove.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSprintJump.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarHurtBonus.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarMaxFakeDamage.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSlotLevel.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSlotMax.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarSlotCost.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarShowBonus.AddChangeHook(ConVarHook_OnValueChanged);
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	g_pCvarCoinAlive.AddChangeHook(ConVarHook_OnValueChanged);
	g_pCvarCoinDead.AddChangeHook(ConVarHook_OnValueChanged);
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	
	// 这个明面上是 float 类型，但实际是 Vector 类型的
	// 使用这个可以避免 GetEntPropFloat 的类型检查
	// g_iOffsetVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_left_start_area", Event_RoundStart);
	HookEvent("door_unlocked", Event_DoorUnlocked);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("finale_win", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	
	// 经验/金钱 获得
	HookEvent("player_hurt", Event_PlayerTakeDamage);
	HookEvent("infected_hurt", Event_InfectedTakeDamage);
	HookEvent("player_death", Event_PlayerKilled);
	HookEvent("revive_success", Event_PlayerRevived);
	HookEvent("defibrillator_used", Event_PlayerDefibrillator);
	HookEvent("heal_success", Event_PlayerHealing);
	HookEvent("award_earned", Event_PlayerAwardEarned);
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("player_now_it", Event_BoomerVomit);
	HookEvent("player_no_longer_it", Event_BoomerVomitFaded);
	HookEvent("charger_carry_start", Event_ChargerCarry);
	HookEvent("charger_impact", Event_ChargerImpact);
	HookEvent("charger_pummel_start", Event_ChargerPummel);
	HookEvent("tongue_grab", Event_SmokerPulling);
	HookEvent("ability_use", Event_AbilityUsed);
	HookEvent("lunge_pounce", Event_HunterPounced);
	HookEvent("map_transition", Event_MissionComplete);
	HookEvent("finale_vehicle_leaving", Event_FinaleComplete);
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_SQLITE_
	Timer_ConnectDatabase(null, 0);
#endif
	
#if defined _USE_DETOUR_FUNC_
	// 一些有用的 Hook
	InitHook();
#endif
	
	// sm_admin 菜单
	TopMenu tm = GetAdminTopMenu();
	if(LibraryExists("adminmenu") && tm != null)
		OnAdminMenuReady(tm);
	
	// 多语言支持
	LoadTranslations("l4d2_simplecombat2.phrases.txt");
	LoadTranslations("core.phrases.txt");
	LoadTranslations("common.phrases.txt");
}

#if defined _USE_DETOUR_FUNC_
void InitHook()
{
	Handle file = LoadGameConfigFile("l4d2_simple_combat");
	if(file == null)
	{
		LogError("找不到文件 l4d2_simple_combat.txt");
		return;
	}
	
	g_pfnAllowTakeDamage = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	if(g_pfnAllowTakeDamage == null)
	{
		LogError("创建 DHookCreateDetour 失败");
		return;
	}
	
	if(!DHookSetFromConf(g_pfnAllowTakeDamage, file, SDKConf_Signature, "CDirectorChallengeMode::ScriptAllowDamage"))
	{
		LogError("加载 CDirectorChallengeMode::ScriptAllowDamage 失败");
		g_pfnAllowTakeDamage = null;
		file.Close();
		return;
	}
	
	file.Close();
	DHookAddParam(g_pfnAllowTakeDamage, HookParamType_CBaseEntity, -1, DHookPass_ByVal);
	DHookAddParam(g_pfnAllowTakeDamage, HookParamType_ObjectPtr, -1, DHookPass_ByRef);
	if(!DHookEnableDetour(g_pfnAllowTakeDamage, false, Hooked_AllowTakeDamage))
	{
		LogError("安装 CDirectorChallengeMode::ScriptAllowDamage 失败");
		g_pfnAllowTakeDamage = null;
		return;
	}
	
	// PrintToServer("加载 CDirectorChallengeMode::ScriptAllowDamage 完毕");
}
#endif	// _USE_DETOUR_FUNC_

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
	g_fwOnGainCashPre, g_fwOnGainCashPost, g_fwWillpowerIncreasePre, g_fwWillpowerIncreasePost,
	g_fwWillpowerDecreasePre, g_fwWillpowerDecreasePost, g_fwOnDamagePre, g_fwOnDamagePost;

// 战斗相关的 forward
Handle g_fwOnStartCombatPre, g_fwOnStartCombatPost, g_fwOnLeaveCombatPre, g_fwOnLeaveCombatPost;

// 菜单 forward
Handle g_fwOnMenuItemClickPre, g_fwOnMenuItemClickPost, g_fwOnSpellDisplayPre/*, g_fwOnSpellDisplayPost*/,
	g_fwOnSkillDisplayPre/*, g_fwOnSkillDisplayPost*/, g_fwOnSpellDescriptionPre, g_fwOnSkillDescriptionPre,
	g_fwOnSpellGetInfo, g_fwOnSkillGetInfo;

// 法术相关 forward
Handle g_fwOnSpellUsePre, g_fwOnSpellUsePost, g_fwOnSpellGainPre, g_fwOnSpellGainPost;

// 存档相关 forward
Handle g_fwOnSavePre, g_fwOnSavePost, g_fwOnLoadPre, g_fwOnLoadPost, g_fwOnDataBaseConnected;

// 技能相关
Handle g_fwOnSkillGainPre, g_fwOnSkillGainPost, g_fwOnSkillLostPre, g_fwOnSkillLostPost;

StringMap g_hMenuSlot[MAXPLAYERS+1];
int g_iPlayerMenu[MAXPLAYERS+1], g_iMenuPage[MAXPLAYERS+1], g_iMenuData[MAXPLAYERS+1];

public Action Cmd_MainMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Menu m = CreateMenu(MenuHandler_MainMenu);
	
	m.SetTitle("%T", "主菜单", client,
		g_iLevel[client], g_iExperience[client], g_iNextLevel[client], g_iAccount[client], g_iSkillPoint[client],
		g_fStamina[client], g_iMaxStamina[client], g_iMaxHealth[client], g_fMagic[client], g_iMaxMagic[client],
		g_fWillpower[client], g_iMaxWillpower[client]);
	
	m.AddItem("use_spell", tr("%T", "使用法术", client, g_hPlayerSpell[client].Length));
	m.AddItem("attributes", tr("%T", "属性查看", client, g_iSkillPoint[client]));
	m.AddItem("buy_spell", tr("%T", "购买法术", client, g_hSellSpellList.Length));
	m.AddItem("skill", tr("%T", "技能查看", client, g_hPlayerSkill[client].Length, g_iSkillSlot[client]));
	
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
	m.SetTitle(tr("%T", "属性面板", client));
	m.DrawText(tr("%T", "属性点和等级", client, g_iSkillPoint[client], g_iLevel[client]));
	
	m.DrawItem(tr("%T", "耐力状态", client, g_fStamina[client], g_iMaxStamina[client]));
	m.DrawText((tr("%T", "耐力介绍", client, g_fDefenseChance[client] * 100, g_fDefenseFactor[client] * 100)));
	
	m.DrawItem(tr("%T", "生命状态", client, g_iMaxHealth[client]));
	m.DrawText(tr("%T", "生命介绍", client));
	
	m.DrawItem(tr("%T", "能量状态", client, g_fMagic[client], g_iMaxMagic[client]));
	m.DrawText(tr("%T", "能量介绍", client));
	// m.DrawText("使用法术可以获得经验值");
	
	m.DrawItem(tr("%T", "精力状态", client, g_fWillpower[client], g_iMaxWillpower[client]));
	m.DrawText(tr("%T", "精力介绍", client, g_fDamageChance[client] * 100, g_fDamageFactor[client] * 100));
	
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	// m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem(tr("%T", "Back", client), ITEMDRAW_CONTROL);
	m.DrawItem(tr("%T", "Exit", client), ITEMDRAW_CONTROL);
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
		CPrintToChat(client, "\x03[SC]\x01 %T", "你没有任何法术", client);
		if(g_iPlayerMenu[client] == 3)
			Cmd_MainMenu(client, 0);
		else
			g_iPlayerMenu[client] = 0;
		return Plugin_Continue;
	}
	
	Menu m = CreateMenu(MenuHandler_SpellMenu);
	m.SetTitle("%T", "法术菜单", client,
		g_fMagic[client], g_iMaxMagic[client], g_iLevel[client]);
	
	int consume = -1, i = 0;
	char classname[11], display[128];
	int length = g_hPlayerSpell[client].Length;
	
	for(i = 0; i < length; ++i)
	{
		StringMap spl = g_hPlayerSpell[client].Get(i);
		// if(spell == null || !spell.GetString("display", display, 128) || !spell.GetValue("consume", consume))
		GetSpellShowInfo(spl, client, display, 128);
		if(spl == null || display[0] == EOS || !spl.GetValue("consume", consume))
		{
			g_hPlayerSpell[client].Erase(i--);
			PrintToServer("法术 %s 已失效，将会被删除。", classname);
			continue;
		}
		
		IntToString(view_as<int>(spl), classname, 11);
		m.AddItem(classname, tr("%s [%d]", display, consume));
	}
	
	m.ExitBackButton = true;
	m.ExitButton = true;
	
	if(argc > 0 && argc < m.ItemCount)
		m.DisplayAt(client, argc, MENU_TIME_FOREVER);
	else
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
		CPrintToChat(client, "\x03[SC]\x01 %T", "目前没有任何可以出售的法术", client);
		if(g_iPlayerMenu[client] == 4)
			Cmd_MainMenu(client, 0);
		else
			g_iPlayerMenu[client] = 0;
		
		return Plugin_Continue;
	}
	
	Menu m = CreateMenu(MenuHandler_BuySpellMenu);
	m.SetTitle("%T", "法术购买菜单", client,
		g_fMagic[client], g_iMaxMagic[client], g_iLevel[client], g_iAccount[client]);
	
	int consume = -1, cost = -1, i = 0;
	char classname[11], display[128];
	int length = g_hSellSpellList.Length;
	
	for(i = 0; i < length; ++i)
	{
		StringMap spl = g_hSellSpellList.Get(i);
		// if(spell == null || !spell.GetString("display", display, 128) || !spell.GetValue("consume", consume) ||
		GetSpellShowInfo(spl, client, display, 128);
		if(spl == null || display[0] == EOS || !spl.GetValue("consume", consume) ||
			!spl.GetValue("cost", cost))
		{
			g_hSellSpellList.Erase(i--);
			continue;
		}
		
		IntToString(view_as<int>(spl), classname, 11);
		m.AddItem(classname, tr("%T", "购买法术项目", client, display, cost, consume));
	}
	
	m.ExitBackButton = true;
	m.ExitButton = true;
	
	if(argc > 0 && argc < m.ItemCount)
		m.DisplayAt(client, argc, MENU_TIME_FOREVER);
	else
		m.Display(client, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 4;
	return Plugin_Continue;
}

public Action Cmd_SkillMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	Panel m = CreatePanel();
	m.SetTitle(tr("%T", "选择技能菜单", client, g_iLevel[client], g_iAccount[client], g_iSkillPoint[client]));
	
	int length = g_hPlayerSkill[client].Length;
	if(length > g_iSkillSlot[client])
		length = g_iSkillSlot[client];
	if(length > g_iSlotMax)
		length = g_iSlotMax;
	
	char display[64], description[255];
	for(int i = 0; i < length; ++i)
	{
		StringMap skill = g_hPlayerSkill[client].Get(i);
		if(skill == null/* || !skill.GetString("display", display, 64)*/)
			continue;
		
		GetSkillShowInfo(skill, client, display, 64, description, 255);
		m.DrawItem(display);
		m.DrawText(description);
	}
	
	if(length < g_iSlotMax)
	{
		if(length < g_iSkillSlot[client])
		{
			m.DrawItem(tr("%T", "未选择技能", client));
			// m.DrawText(tr("%T", "未选择提示", client));
		}
		else
		{
			m.DrawItem(tr("%T", "未解锁空位", client));
			
			int cost = (g_iSlotLevel * (g_iSkillSlot[client] + 1) - g_iLevel[client]) * g_iSlotCost;
			m.DrawText(tr("%T", "未解锁提示", client, g_iSlotLevel * (g_iSkillSlot[client] + 1),
				(cost > 0 ? cost : 0)));
		}
		
		length += 1;
	}
	
	// 填充菜单空位
	for(int i = length; i < 8; ++i)
		m.DrawItem("", ITEMDRAW_SPACER);
	
	m.DrawItem(tr("%T", "Back", client), ITEMDRAW_CONTROL);
	m.DrawItem(tr("%T", "Exit", client), ITEMDRAW_CONTROL);
	m.Send(client, MenuHandler_SkillInfo, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 5;
	return Plugin_Continue;
}

public Action Cmd_DebugFullAll(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	g_fMagic[client] = float(g_iMaxMagic[client]);
	g_fStamina[client] = float(g_iMaxStamina[client]);
	g_fWillpower[client] = float(g_iMaxWillpower[client]);
	PrintToChat(client, "\x03[SC]\x01 完成。");
	
	return Plugin_Continue;
}

public Action Cmd_DebugGiveExperience(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	char count[8];
	GetCmdArg(1, count, 8);
	int amount = StringToInt(count);
	GiveExperience(client, amount);
	PrintToChat(client, "\x03[SC]\x01 完成：%d", amount);
	
	return Plugin_Continue;
}

public Action Cmd_DebugGiveCash(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	char count[8];
	GetCmdArg(1, count, 8);
	int amount = StringToInt(count);
	GiveCash(client, amount);
	PrintToChat(client, "\x03[SC]\x01 完成：%d", amount);
	
	return Plugin_Continue;
}

void ChooseSkill(int client, int page = 0, StringMap lastSkill = null)
{
	Menu m = CreateMenu(MenuHandler_ChooseSkill);
	
	// char display[64];
	if(lastSkill != null/* && lastSkill.GetString("display", display, 64)*/)
		m.SetTitle("%T", "替换技能", client, GetSkillShowInfo(lastSkill, client));
	else
		m.SetTitle("%T", "选择新技能", client);
	
	char info[11], name[32];
	int classId = 0, length = g_hAllSkillList.Length;
	for(int i = 0; i < length; ++i)
	{
		StringMap skill = g_hAllSkillList.Get(i);
		if(skill == null)
			continue;
		
		// 技能重复是没有意义的
		if(g_hPlayerSkill[client].FindValue(skill) > -1)
			continue;
		
		/*
		if(!skill.GetString("display", display, 64))
			continue;
		*/
		
		IntToString(view_as<int>(skill), info, 11);
		
		if(skill.GetValue("zombie", classId) && GetZombieName(classId, name, 32))
			m.AddItem(info, tr("[%s] %s", name, GetSkillShowInfo(skill, client)));
		else
			m.AddItem(info, GetSkillShowInfo(skill, client));
	}
	
	if(m.ItemCount <= 0)
	{
		delete m;
		PrintToChat(client, "\x03[SC]\x01 %T", "没有任何技能", client);
		Cmd_SkillMenu(client, 0);
		return;
	}
	
	if(page > 0 && page < m.ItemCount)
		m.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		m.Display(client, MENU_TIME_FOREVER);
	
	g_iPlayerMenu[client] = 6;
	g_hMenuSlot[client] = lastSkill;
	g_iMenuPage[client] = (page > 0 ? page : 0);
}

stock bool GetZombieName(int classId, char[] output = "", int outMaxLength)
{
	char buffer[32];
	switch(classId)
	{
		case Z_SMOKER:
			strcopy(buffer, 32, "舌头");
		case Z_BOOMER:
			strcopy(buffer, 32, "胖子");
		case Z_HUNTER:
			strcopy(buffer, 32, "猎人");
		case Z_SPITTER:
			strcopy(buffer, 32, "口水");
		case Z_JOCKEY:
			strcopy(buffer, 32, "猴");
		case Z_CHARGER:
			strcopy(buffer, 32, "牛");
		case Z_TANK:
			strcopy(buffer, 32, "克");
		case Z_SURVIVOR:
			strcopy(buffer, 32, "生还者");
		default:
			return false;
	}
	
	if(outMaxLength > 0)
		strcopy(output, outMaxLength, buffer);
	
	return true;
}

stock bool UseSpellByClient(int client, const char[] classname)
{
	char refClassname[64] = "";
	Action result = Plugin_Continue;
	
	char _classname[64];
	strcopy(refClassname, 64, classname);
	strcopy(_classname, 64, classname);
	
	Call_StartForward(g_fwOnSpellUsePre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushCell(sizeof(refClassname));
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return false;
	
	if(result == Plugin_Changed)
		strcopy(_classname, 64, refClassname);
	
	Call_StartForward(g_fwOnSpellUsePost);
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
	
	if(result >= Plugin_Handled)
		return 0;
	
	switch(select)
	{
		case 0:
			Cmd_SpellMenu(client, 0);
		case 1:
			Cmd_AttributesMenu(client, 0);
		case 2:
			Cmd_BuySpellMenu(client, 0);
		case 3:
			Cmd_SkillMenu(client, 0);
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
	if(!IsValidClient(client) || action != MenuAction_Select)
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
				UpdateDamageBonus(client);
			}
		}
		case 2:
		{
			if(g_iSkillPoint[client] >= 1)
			{
				g_iSkillPoint[client] -= 1;
				g_iMaxHealth[client] += g_pCvarPointAmount.IntValue;
				UpdateMaxHealth(client);
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
		case 4:
		{
			if(g_iSkillPoint[client] >= 1)
			{
				g_iSkillPoint[client] -= 1;
				g_iMaxWillpower[client] += g_pCvarPointAmount.IntValue;
				UpdateDamageBonus(client);
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
	
	StringMap spl = view_as<StringMap>(StringToInt(classname));
	int index = g_hPlayerSpell[client].FindValue(spl);
	if(index == -1 || spl == null)
	{
		g_hPlayerSpell[client].Erase(index);
		CPrintToChat(client, "\x03[SC]\x01 %T", "施法失败，发生未知错误", client);
		Cmd_SpellMenu(client, m.Selection);
		return 0;
	}
	
	int consume = -1;
	spl.GetValue("consume", consume);
	
	if(g_fMagic[client] < consume)
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "施法失败，能量不足", client,
			g_fMagic[client], consume);
		
		Cmd_SpellMenu(client, m.Selection);
		return 0;
	}
	
	spl.GetString("classname", classname, 64);
	if(!UseSpellByClient(client, classname))
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "施法失败，被未知力量阻止了", client);
		Cmd_SpellMenu(client, m.Selection);
		return 0;
	}
	
	MagicDecrease(client, float(consume));
	g_hPlayerSpell[client].Erase(index);
	GiveExperience(client, consume);
	
	// char display[128];
	// spell.GetString("display", display, 128);
	CPrintToChat(client, "\x03[SC]\x01 %T", "使用了法术", client, GetSpellShowInfo(spl, client), consume);
	
	Cmd_SpellMenu(client, m.Selection);
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
		CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，发生未知错误", client);
		Cmd_BuySpellMenu(client, m.Selection);
		return 0;
	}
	
	int cost = -1;
	map.GetValue("cost", cost);
	
	char refClassname[64] = "";
	Action result = Plugin_Continue;
	strcopy(refClassname, 64, classname);
	
	Call_StartForward(g_fwOnSpellGainPre);
	Call_PushCell(client);
	Call_PushStringEx(refClassname, 64, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(refClassname));
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		if(result == Plugin_Handled)
			CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，被未知力量阻止了", client);
		
		Cmd_BuySpellMenu(client, m.Selection);
		return 0;
	}
	else if(result == Plugin_Changed)
	{
		// 修改购买的法术
		strcopy(classname, 64, refClassname);
	}
	
	if(g_iAccount[client] < cost)
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，你的钱不够", client, g_iAccount[client], cost);
		Cmd_BuySpellMenu(client, m.Selection);
		return 0;
	}
	
	ShowSpellInfoPanel(client, map, cost, index);
	return 0;
}

void ShowSpellInfoPanel(int client, StringMap spell, int cost, int data)
{
	Panel m = CreatePanel();
	m.SetTitle(tr("%T", "购买法术确认", client));
	
	char display[64], description[255];
	GetSpellShowInfo(spell, client, display, 64, description, 255);
	
	m.DrawText(display);
	
	int consume = 0;
	spell.GetValue("consume", consume);
	
	if(cost > 0)
		m.DrawText(tr("%T", "购买价格", client, cost, g_iAccount[client]));
	
	if(consume > 0)
		m.DrawText(tr("%T", "法术消耗", client, consume, g_iMaxMagic[client]));
	
	m.DrawText(description);
	
	if(consume > g_iMaxMagic[client])
		m.DrawText(tr("%T", "消耗不起", client));
	
	m.DrawItem(tr("%T", "Yes", client));
	m.DrawItem(tr("%T", "No", client));
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem(tr("%T", "Back", client), ITEMDRAW_CONTROL);
	m.DrawItem(tr("%T", "Exit", client), ITEMDRAW_CONTROL);
	
	g_iPlayerMenu[client] = 0;
	m.Send(client, MenuHandler_BuySpellConfirm, MENU_TIME_FOREVER);
	g_iMenuData[client] = cost;
	g_hMenuSlot[client] = spell;
	g_iMenuPage[client] = data;
}

public int MenuHandler_BuySpellConfirm(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;
	
	if(select == 10)
	{
		ClearMenuParam(client);
		return 0;
	}
	
	if(select != 1)
	{
		Cmd_BuySpellMenu(client, 0);
		ClearMenuParam(client);
		return 0;
	}
	
	if(g_iAccount[client] < g_iMenuData[client])
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，你的钱不够", client, g_iAccount[client], g_iMenuData[client]);
		Cmd_BuySpellMenu(client, m.Selection);
		ClearMenuParam(client);
		return 0;
	}
	
	g_iAccount[client] -= g_iMenuData[client];
	g_hPlayerSpell[client].Push(g_hMenuSlot[client]);
	g_hSellSpellList.Erase(g_iMenuPage[client]);
	
	char classname[64];
	g_hMenuSlot[client].GetString("classname", classname, 64);
	
	Call_StartForward(g_fwOnSpellGainPost);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_Finish();
	
	CPrintToChat(client, "\x03[SC]\x01 %T", "购买了法术", client, GetSpellShowInfo(g_hMenuSlot[client], client), g_iMenuData[client], g_iAccount[client]);
	Cmd_BuySpellMenu(client, 0);
	ClearMenuParam(client);
	return 0;
}

void ClearMenuParam(int client)
{
	g_iMenuData[client] = 0;
	g_hMenuSlot[client] = null;
	g_iMenuPage[client] = 0;
}

public int MenuHandler_SkillInfo(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;
	
	if(select == 10)
	{
		g_iPlayerMenu[client] = 0;
		return 0;
	}
	
	if(select == 9)
	{
		Cmd_MainMenu(client, 0);
		return 0;
	}
	
	select -= 1;
	int length = g_hPlayerSkill[client].Length;
	if(length > g_iSkillSlot[client])
		length = g_iSkillSlot[client];
	if(length > g_iSlotMax)
		length = g_iSlotMax;
	
	if(select < length)
	{
		if(g_fNextSkillChoose[client] > GetEngineTime())
		{
			CPrintToChat(client, "\x03[SC]\x01 %T", "操作过快", client);
			Cmd_SkillMenu(client, 0);
			return 0;
		}
		
		// 替换已选技能
		ChooseSkill(client, 0, g_hPlayerSkill[client].Get(select));
		return 0;
	}
	else if(select == length && length < g_iSlotMax)
	{
		if(length < g_iSkillSlot[client])
		{
			// 空位选择新技能
			ChooseSkill(client, 0, null);
			return 0;
		}
		else
		{
			// 购买技能位
			int cost = (g_iSlotLevel * (g_iSkillSlot[client] + 1) - g_iLevel[client]) * g_iSlotCost;
			if(cost < 0)
				cost = 0;
			
			if(g_iAccount[client] < cost)
			{
				CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，你的钱不够", client, cost, g_iAccount[client]);
			}
			else if(g_iSkillSlot[client] >= g_iSlotMax)
			{
				CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，已达到上限", client, g_iSlotMax);
			}
			else
			{
				g_iAccount[client] -= cost;
				g_iSkillSlot[client] += 1;
				CPrintToChat(client, "\x03[SC]\x01 %T", "购买技能位成功", client, g_iSkillSlot[client], g_iSlotMax, cost, g_iAccount[client]);
			}
		}
	}
	
	Cmd_SkillMenu(client, 0);
	return 0;
}

public int MenuHandler_ChooseSkill(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			Cmd_SkillMenu(client, 0);
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
	StringMap skill = view_as<StringMap>(StringToInt(classname));
	if(skill == null || !skill.GetString("classname", classname, 64))
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，发生未知错误");
		Cmd_SkillMenu(client, 0);
		return 0;
	}
	
	char lost[64];
	Action result = Plugin_Continue;
	if(g_hMenuSlot[client] != null && g_hMenuSlot[client].GetString("classname", lost, 64))
	{
		char refLost[64];
		strcopy(refLost, 64, lost);
		
		Call_StartForward(g_fwOnSkillLostPre);
		Call_PushCell(client);
		Call_PushStringEx(refLost, 64, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(64);
		Call_PushString(classname);
		Call_Finish(result);
		
		if(result >= Plugin_Handled)
		{
			if(result == Plugin_Handled)
				CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，被未知力量阻止了");
			
			ChooseSkill(client, g_iMenuPage[client], g_hMenuSlot[client]);
			return 0;
		}
		
		int index = -1;
		if(result == Plugin_Changed)
		{
			// strcopy(lost, 64, refLost);
			index = FindValueIndexByClassName(refLost, g_hPlayerSkill[client]);
		}
		else
		{
			index = g_hPlayerSkill[client].FindValue(g_hMenuSlot[client]);
		}
		
		if(index < 0)
		{
			CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，发生未知错误");
			Cmd_SkillMenu(client, 0);
			return 0;
		}
		
		g_hPlayerSkill[client].Erase(index);
		
		Call_StartForward(g_fwOnSkillLostPost);
		Call_PushCell(client);
		Call_PushString(lost);
		Call_PushString(classname);
		Call_Finish();
	}
	
	result = Plugin_Continue;
	strcopy(lost, 64, classname);
	Call_StartForward(g_fwOnSkillGainPre);
	Call_PushCell(client);
	Call_PushString(lost);
	Call_PushCell(64);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		if(result == Plugin_Handled)
			CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，被未知力量阻止了");
		
		ChooseSkill(client, g_iMenuPage[client], g_hMenuSlot[client]);
		return 0;
	}
	
	if(result == Plugin_Changed)
	{
		strcopy(classname, 64, lost);
		skill = FindValueByClassName(lost, g_hAllSkillList);
		if(skill == null)
		{
			CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，被未知力量阻止了");
			ChooseSkill(client, g_iMenuPage[client], g_hMenuSlot[client]);
			return 0;
		}
	}
	
	ShowSkillInfoPanel(client, skill);
	return 0;
}

void ShowSkillInfoPanel(int client, StringMap skill)
{
	Panel m = CreatePanel();
	m.SetTitle(tr("%T", "选择技能确认", client));
	
	char display[64], description[255];
	GetSkillShowInfo(skill, client, display, 64, description, 255);
	m.DrawText(display);
	
	m.DrawText(description);
	
	m.DrawItem(tr("%T", "Yes", client));
	m.DrawItem(tr("%T", "No", client));
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem("", ITEMDRAW_SPACER);
	m.DrawItem(tr("%T", "Back", client), ITEMDRAW_CONTROL);
	m.DrawItem(tr("%T", "Exit", client), ITEMDRAW_CONTROL);
	
	g_iPlayerMenu[client] = 0;
	m.Send(client, MenuHandler_GetSkillConfirm, MENU_TIME_FOREVER);
	g_iMenuData[client] = view_as<int>(skill);
}

public int MenuHandler_GetSkillConfirm(Menu m, MenuAction action, int client, int select)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;
	
	if(select != 1)
	{
		// 把技能放回去吧，虽然顺序错乱了...
		if(g_hMenuSlot[client] != null && g_hPlayerSkill[client].FindValue(g_hMenuSlot[client]) == -1)
			g_hPlayerSkill[client].Push(g_hMenuSlot[client]);
		
		if(select == 10)
		{
			ClearMenuParam(client);
			return 0;
		}
		
		ChooseSkill(client, g_iMenuPage[client], g_hMenuSlot[client]);
		// ClearMenuParam(client);
		return 0;
	}
	
	char/* display[64], */description[255];
	StringMap skill = view_as<StringMap>(g_iMenuData[client]);
	if(skill == null ||/* !skill.GetString("display", display, 64) ||*/
		!skill.GetString("description", description, 255))
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "选择失败，发生未知错误");
		ChooseSkill(client, g_iMenuPage[client], g_hMenuSlot[client]);
		return 0;
	}
	
	g_hPlayerSkill[client].Push(skill);
	
	char classname[64];
	skill.GetString("classname", classname, 64);
	
	Call_StartForward(g_fwOnSkillGainPost);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_Finish();
	
	CPrintToChat(client, "\x03[SC]\x01 %T", "选择了技能", client, GetSkillShowInfo(skill, client));
	CPrintToChat(client, "\x03[SC]\x01 %T", "技能效果", client, description);
	
	if(g_hMenuSlot[client] != null)
		g_fNextSkillChoose[client] = GetEngineTime() + g_pCvarSkillChooseInterval.FloatValue;
	
	Cmd_SkillMenu(client, 0);
	ClearMenuParam(client);
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
	g_fCombatWillpower = g_pCvarWillpowerRate.FloatValue;
	g_fSafeWillpower = g_pCvarWillpowerIdleRate.FloatValue;
	// g_fDefenseChance = g_pCvarDefenseChance.FloatValue;
	// g_fDefenseFactor = g_pCvarDefenseFactor.FloatValue;
	g_iDefenseLimit = g_pCvarDefenseLimit.IntValue;
	// g_fDamageChance = g_pCvarDamageChance.FloatValue;
	// g_fDamageFactor = g_pCvarDamageFactor.FloatValue;
	g_iDamageLimit = g_pCvarDamageLimit.IntValue;
	g_bDefenseFriendly = g_pCvarDefenseFriendly.BoolValue;
	g_bDamageFriendly = g_pCvarDamageFriendly.BoolValue;
	g_bSprintAllow = g_pCvarSprintAllow.BoolValue;
	g_iSprintLimit = g_pCvarSprintLimit.IntValue;
	g_iSprintPerSecond = g_pCvarSprintConsume.IntValue;
	g_fSprintWalk = g_pCvarSprintSpeed.FloatValue;
	g_fSprintDuck = g_pCvarSprintDuckSpeed.FloatValue;
	g_fSprintWater = g_pCvarSprintWaterSpeed.FloatValue;
	g_fStandingDelay = g_pCvarStandingDelay.FloatValue;
	g_fStandingFactor = g_pCvarStandingRate.FloatValue;
	g_iStandingLimit = g_pCvarStandingLimit.IntValue;
	g_fThinkInterval = g_pCvarThinkInterval.FloatValue;
	g_iDamageMin = g_pCvarDamageMin.IntValue;
	g_iDefenseMin = g_pCvarDefenseMin.IntValue;
	g_fBlockRevive = g_pCvarBlockRevive.FloatValue;
	g_bMenuFlush = g_pCvarMenuFlush.BoolValue;
	g_bHurtBonus = g_pCvarHurtBonus.BoolValue;
	g_fMaxFakeDamage = g_pCvarMaxFakeDamage.FloatValue;
	g_iSlotCost = g_pCvarSlotCost.IntValue;
	g_iSlotLevel = g_pCvarSlotLevel.IntValue;
	g_iSlotMax = g_pCvarSlotMax.IntValue;
	
#if defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	g_iCoinAlive = g_pCvarCoinAlive.IntValue;
	g_iCoinDead = g_pCvarCoinDead.IntValue;
#endif	// defined _USE_DATABASE_SQLITE_ || defined _USE_DATABASE_MYSQL_
	
	g_bSprintAttack = g_pCvarSprintAttack.BoolValue;
	g_bSprintShove = g_pCvarSprintShove.BoolValue;
	g_bSprintJump = g_pCvarSprintJump.BoolValue;
	g_iShowBonus = g_pCvarShowBonus.IntValue;
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
	
	// PrintToServer("difficulty: %s丨factor: %.3f", newValue, g_fDifficultyFactor);
}

/*
public void ConVarHook_OnSpeedChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fDefaultSpeed[Z_COMMON] = g_hCvarDuckSpeed.FloatValue;
	g_fDefaultSpeed[Z_SMOKER] = g_hCvarSmokerSpeed.FloatValue;
	g_fDefaultSpeed[Z_BOOMER] = g_hCvarBoomerSpeed.FloatValue;
	g_fDefaultSpeed[Z_HUNTER] = g_hCvarHunterSpeed.FloatValue;
	g_fDefaultSpeed[Z_SPITTER] = g_hCvarSpitterSpeed.FloatValue;
	g_fDefaultSpeed[Z_JOCKEY] = g_hCvarJockeySpeed.FloatValue;
	g_fDefaultSpeed[Z_CHARGER] = g_hCvarChargerSpeed.FloatValue;
	g_fDefaultSpeed[Z_TANK] = g_hCvarTankSpeed.FloatValue;
	g_fDefaultSpeed[Z_WITCH] = g_hCvarAdrenSpeed.FloatValue;
	g_fDefaultSpeed[Z_SURVIVOR] = g_hCvarSurvivorSpeed.FloatValue;
}
*/

public Action Timer_UpdateScriptConfig(Handle timer, any unused)
{
	char script[1024] = "";
	int logicScript = CreateEntityByName("logic_script");
	StrCat(script, 1024, "::DamageLimit.ConfigVar.Enable = false;\r\n");
	StrCat(script, 1024, "::DifficultyBanalce.ConfigVar.Enable = false;\r\n");
	// StrCat(script, 1024, "::RoundSupply.ConfigVar.Enable = false;\r\n");
	
	SetVariantString("OnUser1 !self:Kill::1:1");
	AcceptEntityInput(logicScript, "AddOutput");
	SetVariantString(script);
	AcceptEntityInput(logicScript, "RunScriptCode");
	AcceptEntityInput(logicScript, "FireUser1");
	
	return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	/*
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i))
			continue;
		
		LoadFromFile(i);
		SetupPlayerHook(i);
	}
	*/
	
	if(g_hDatabase == null)
		Timer_ConnectDatabase(null, 0);
	
	int length = (g_pCvarShopCount.IntValue > g_hAllSpellList.Length ? g_hAllSpellList.Length : g_pCvarShopCount.IntValue);
	
	g_hSellSpellList.Clear();
	SortADTArray(g_hAllSpellList, Sort_Random, Sort_Integer);
	CreateTimer(1.0, Timer_UpdateScriptConfig);
	
	for(int i = 0; i < length; ++i)
		g_hSellSpellList.Push(g_hAllSpellList.Get(i));
	
	char difficulty[32];
	g_hCvarDifficulty.GetString(difficulty, 32);
	ConVarHook_OnDifficultyChanged(g_hCvarDifficulty, "", difficulty);
}

public void Event_DoorUnlocked(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!event.GetBool("checkpoint"))
		return;
	
	Event_RoundStart(event, eventName, dontBroadcast);
}

public void Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i))
			continue;
		
		SaveToFile(i);
		// g_iDefaultHealth[i] = 0;
	}
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	// LoadFromFile(client);
	// g_iDefaultHealth[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	// SetupPlayerHook(client);
	RequestFrame(SetupPlayerHook, client);
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if(!IsValidClient(client))
		return;
	
	// g_iDefaultHealth[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	SetupPlayerHook(client);
	// RequestFrame(SetupPlayerHook, client);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(IsValidClient(client))
	{
		UninstallPlayerHook(client);
		// g_iDefaultHealth[client] = 0;
	}
	
	if(IsValidClient(bot))
	{
		if(!IsPlayerHanging(bot) && !IsPlayerIncapacitated(bot))
			SetEntProp(bot, Prop_Data, "m_iMaxHealth", 100);
		
		AddHealth(bot, 0, true);
	}
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	// SaveToFile(client);
	UninstallPlayerHook(client);
	g_iDefaultHealth[client] = 0;
}

public void Event_PlayerTakeDamage(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int damage = event.GetInt("dmg_health");
	float time = GetGameTime();
	
	if(IsValidClient(victim))
	{
		g_fNextReviveTime[victim] = time + g_fBlockRevive;
		g_fNextStandingTime[victim] = time + g_fStandingDelay;
	}
	else
	{
		return;
	}
	
	if(victim == attacker || damage <= 0)
		return;
	
	if(IsValidClient(attacker))
	{
		// 这里只进行伤害统计，不进行伤害修改
		g_iDamageTotal[attacker][victim] += damage;
		
		if(GetClientTeam(attacker) == 3 && GetClientTeam(victim) == 2)
		{
			char weapon[32];
			event.GetString("weapon", weapon, 32);
			int zombie = GetEntProp(attacker, Prop_Send, "m_zombieClass");
			
			if(StrEqual(weapon, "insect_swarm", false))
			{
				if(zombie == Z_SPITTER)
				{
					// Spitter 的酸液攻击
					// 防止在短时间内多次调用导致服务器负载过大
					g_iDamageSpitTotal[attacker] += 1;
				}
			}
			else if(StrEqual(weapon, "tank_claw", false))
			{
				if(zombie == Z_TANK)
				{
					// GiveExperience(attacker, g_pCvarSlapExperience.IntValue);
					// GiveCash(attacker, g_pCvarSlapCash.IntValue);
					GiveBonus(attacker, g_pCvarSlapExperience.IntValue, g_pCvarSlapCash.IntValue,
						"拍了生还者一巴掌");
					
#if defined _USE_CONSOLE_MESSAGE_
					PrintToConsole(attacker, "[SC] exp +%d, cash +%d with claw %N.",
						g_pCvarSlapExperience.IntValue, g_pCvarSlapCash.IntValue, victim);
#endif	// _USE_CONSOLE_MESSAGE_
				}
			}
			else if(StrEqual(weapon, "tank_rock", false))
			{
				if(zombie == Z_TANK)
				{
					// GiveExperience(attacker, g_pCvarRockExperience.IntValue);
					// GiveCash(attacker, g_pCvarRockCash.IntValue);
					GiveBonus(attacker, g_pCvarRockExperience.IntValue, g_pCvarRockCash.IntValue,
						"投石砸到了生还者");
					
#if defined _USE_CONSOLE_MESSAGE_
					PrintToConsole(attacker, "[SC] exp +%d, cash +%d with rock hit %N.",
						g_pCvarRockExperience.IntValue, g_pCvarRockCash.IntValue, victim);
#endif	// _USE_CONSOLE_MESSAGE_
				}
			}
			else if(GetCurrentVictim(attacker) == victim || GetCurrentAttacker(victim) == attacker)
			{
				// 一般为特感控人持续攻击
				g_iAttackTotal[attacker] += 1;
			}
			else if(StrContains(weapon, "_claw", false) > 0)
			{
				if(zombie >= Z_SMOKER && zombie <= Z_CHARGER)
				{
					// GiveExperience(attacker, g_pCvarClawExperience[zombie].IntValue);
					// GiveCash(attacker, g_pCvarClawCash[zombie].IntValue);
					GiveBonus(attacker, g_pCvarClawExperience[zombie].IntValue, g_pCvarClawCash[zombie].IntValue);
					
#if defined _USE_CONSOLE_MESSAGE_
					PrintToConsole(attacker, "[SC] exp +%d, cash +%d with claw %N.",
						g_pCvarClawExperience[zombie].IntValue, g_pCvarClawCash[zombie].IntValue, victim);
#endif	// _USE_CONSOLE_MESSAGE_
				}
			}
		}
		
		// g_fNextReviveTime[attacker] = time + g_fBlockRevive;
		g_fNextStandingTime[attacker] = time + g_fStandingDelay;
	}
	else if(IsValidClient(g_iVomitAttacker[victim]) && g_fVomitEndTime[victim] >= GetGameTime())
	{
		attacker = event.GetInt("attackerentid");
		if(attacker > MaxClients && IsValidEntity(attacker))
		{
			char classname[64];
			GetEntityClassname(attacker, classname, 64);
			if(StrEqual(classname, "infected", false))
			{
				// Boomer 胆汁助攻
				g_iDamageAssistTotal[g_iVomitAttacker[victim]] += 1;
			}
		}
	}
}

public void Event_InfectedTakeDamage(Event event, const char[] eventName, bool dontBroadcast)
{
	int damage = event.GetInt("amount");
	int victim = event.GetInt("entityid");
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(damage <= 0 || victim <= MaxClients || !IsValidClient(attacker) || !IsValidEntity(victim))
		return;
	
	// Witch
	if(HasEntProp(victim, Prop_Send, "m_rage"))
	{
		int data[MAXPLAYERS + 1];
		int index = FindValueOfArray(victim, 0, g_hWitchDamage);
		if(index > -1)
		{
			g_hWitchDamage.GetArray(index, data, MAXPLAYERS + 1);
			data[attacker] += damage;
			g_hWitchDamage.SetArray(index, data, MAXPLAYERS + 1);
		}
		else
		{
			data[0] = victim;
			data[attacker] = damage;
			g_hWitchDamage.PushArray(data, MAXPLAYERS + 1);
		}
	}
}

int FindValueOfArray(any value, int slot, ArrayList array)
{
	int length = array.Length;
	any[] data = new any[slot + 1];
	for(int i = 0; i < length; ++i)
	{
		array.GetArray(i, data, slot + 1);
		if(data[slot] == value)
			return i;
	}
	
	// delete[] data;
	return -1;
}

public void Event_PlayerKilled(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");
	
	if(victim == attacker)
		return;
	
	if(IsValidClient(attacker))
	{
		if(IsValidClient(victim))
		{
			int zombie = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if(zombie != Z_TANK && !g_bHurtBonus)
			{
#if defined _USE_PLUGIN_MAX_HEALTH_
				float factor = g_iDamageTotal[attacker][victim] / float(g_iMaxHealth[victim] + g_iDefaultHealth[victim]);
#else
				float factor = g_iDamageTotal[attacker][victim] / float(GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
#endif	// _USE_PLUGIN_MAX_HEALTH_
				
				if(factor > 0.0)
				{
					if(factor > g_fMaxFakeDamage)
						factor = g_fMaxFakeDamage;
					
					float experience = g_pCvarKilledExperience[zombie].FloatValue * factor;
					float cash = g_pCvarKilledCash[zombie].FloatValue * factor;
					
					if(headshot)
					{
						experience *= g_pCvarHeadshotExperience.FloatValue;
						cash *= g_pCvarHeadshotCash.FloatValue;
					}
					
					// GiveExperience(attacker, RoundToZero(experience));
					// GiveCash(attacker, RoundToZero(cash));
					GiveBonus(attacker, RoundToZero(experience), RoundToZero(cash), "打死了 %N", victim);
					
	#if defined _USE_CONSOLE_MESSAGE_
					PrintToConsole(attacker, "[SC] exp +%.0f, cash +%.0f with kill %N (%.2f%%/%d).",
						experience, cash, victim, factor * 100, g_iDamageTotal[attacker][victim]);
	#endif	// _USE_CONSOLE_MESSAGE_
				}
			}
			else
			{
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(!IsValidClient(i))
						continue;
					
#if defined _USE_PLUGIN_MAX_HEALTH_
					float factor = g_iDamageTotal[i][victim] / float(g_iMaxHealth[victim] + g_iDefaultHealth[victim]);
#else
					float factor = g_iDamageTotal[i][victim] / float(GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
#endif	// _USE_PLUGIN_MAX_HEALTH_
					
					if(factor <= 0.0)
						continue;
					
					if(factor > g_fMaxFakeDamage)
						factor = g_fMaxFakeDamage;
					
					float experience = g_pCvarKilledExperience[zombie].FloatValue * factor;
					float cash = g_pCvarKilledCash[zombie].FloatValue * factor;
					
					if(headshot && i == attacker && zombie != Z_TANK)
					{
						experience *= g_pCvarHeadshotExperience.FloatValue;
						cash *= g_pCvarHeadshotCash.FloatValue;
					}
					
					// GiveExperience(i, RoundToZero(experience));
					// GiveCash(i, RoundToZero(cash));
					if(i == attacker)
						GiveBonus(i, RoundToZero(experience), RoundToZero(cash), "打死了 %N", victim);
					else
						GiveBonus(i, RoundToZero(experience), RoundToZero(cash), "帮助 %N 打死了 %N", attacker, victim);
					
#if defined _USE_CONSOLE_MESSAGE_
					PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with %N killed (%.2f%%/%d).",
						experience, cash, victim, factor * 100, g_iDamageTotal[i][victim]);
#endif	// _USE_CONSOLE_MESSAGE_
				}
			}
		}
		else if(IsValidEntity((victim = event.GetInt("entityid"))))
		{
			int index = FindValueOfArray(victim, 0, g_hWitchDamage);
			if(index > -1 && HasEntProp(victim, Prop_Send, "m_rage"))
			{
				int data[MAXPLAYERS + 1];
				g_hWitchDamage.GetArray(index, data, MAXPLAYERS + 1);
				
				if(g_bHurtBonus)
				{
					for(int i = 1; i <= MaxClients; ++i)
					{
						if(!IsValidClient(i))
							continue;
						
						float factor = data[i] / float(GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
						if(factor <= 0.0)
							continue;
						
						if(factor > g_fMaxFakeDamage)
							factor = g_fMaxFakeDamage;
						
						int experience = RoundToZero(g_pCvarKilledExperience[Z_WITCH].FloatValue * factor);
						int cash = RoundToZero(g_pCvarKilledCash[Z_WITCH].FloatValue * factor);
						
						// GiveExperience(attacker, experience);
						// GiveCash(attacker, cash);
						
						if(i == attacker)
							GiveBonus(i, experience, cash, "打死了 Witch");
						else
							GiveBonus(i, experience, cash, "帮助 %N 打死了 Witch", attacker);
						
#if defined _USE_CONSOLE_MESSAGE_
						PrintToConsole(i, "[SC] exp +%d, cash +%d with kills witch (%.2f%%/%d).",
							experience, cash, factor * 100, data[i]);
#endif	// _USE_CONSOLE_MESSAGE_
					}
				}
				else
				{
					float factor = data[attacker] / float(GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
					if(factor > 0.0)
					{
						if(factor > g_fMaxFakeDamage)
							factor = g_fMaxFakeDamage;
						
						int experience = RoundToZero(g_pCvarKilledExperience[Z_WITCH].FloatValue * factor);
						int cash = RoundToZero(g_pCvarKilledCash[Z_WITCH].FloatValue * factor);
						
						// GiveExperience(attacker, experience);
						// GiveCash(attacker, cash);
						GiveBonus(attacker, experience, cash, "打死了 Witch");
						
#if defined _USE_CONSOLE_MESSAGE_
						PrintToConsole(attacker, "[SC] exp +%d, cash +%d with kills witch (%.2f%%/%d).",
							experience, cash, factor * 100, data[attacker]);
#endif	// _USE_CONSOLE_MESSAGE_
					}
				}
			}
			else if(HasEntProp(victim, Prop_Send, "m_bIsBurning"))
			{
				// 防止在短时间内多次调用导致服务器负载过大
				g_iCommonKillTotal[attacker] += 1;
			}
			
			if(index > -1)
				g_hWitchDamage.Erase(index);
		}
	}
	
	if(IsValidClient(victim))
	{
		for(int i = 1; i <= MaxClients; ++i)
			g_iDamageTotal[i][victim] = 0;
	}
}

public void Event_PlayerRevived(Event event, const char[] eventName, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revivee = GetClientOfUserId(event.GetInt("subject"));
	
	if(!IsValidAliveClient(reviver) || !IsValidAliveClient(revivee) || reviver == revivee)
		return;
	
	if(event.GetBool("ledge_hang"))
	{
		// GiveExperience(reviver, g_pCvarLedgeExperience.IntValue);
		// GiveCash(reviver, g_pCvarLedgeCash.IntValue);
		GiveBonus(reviver, g_pCvarLedgeExperience.IntValue, g_pCvarLedgeCash.IntValue,
			"救起了挂边的 %N", revivee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(reviver, "[SC] exp +%d, cash +%d with revive by ledge.",
			g_pCvarLedgeExperience.IntValue,
			g_pCvarLedgeCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	else
	{
		// GiveExperience(reviver, g_pCvarReviveExperience.IntValue);
		// GiveCash(reviver, g_pCvarReviveCash.IntValue);
		GiveBonus(reviver, g_pCvarReviveExperience.IntValue, g_pCvarReviveCash.IntValue,
			"救起了倒地的 %N", revivee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(reviver, "[SC] exp +%d, cash +%d with revive.",
			g_pCvarReviveExperience.IntValue,
			g_pCvarReviveCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
}

public void Event_PlayerDefibrillator(Event event, const char[] eventName, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revivee = GetClientOfUserId(event.GetInt("subject"));
	
	if(!IsValidAliveClient(reviver) || !IsValidAliveClient(revivee) || reviver == revivee)
		return;
	
	// GiveExperience(reviver, g_pCvarDefibExperience.IntValue);
	// GiveCash(reviver, g_pCvarDefibCash.IntValue);
	GiveBonus(reviver, g_pCvarDefibExperience.IntValue, g_pCvarDefibCash.IntValue,
		"电击复活了 %N", revivee);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(reviver, "[SC] exp +%d, cash +%d with defibrillator.",
		g_pCvarDefibExperience.IntValue,
		g_pCvarDefibCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_PlayerHealing(Event event, const char[] eventName, bool dontBroadcast)
{
	int healer = GetClientOfUserId(event.GetInt("userid"));
	int healee = GetClientOfUserId(event.GetInt("subject"));
	
	if(!IsValidAliveClient(healer) || !IsValidAliveClient(healee) || healer == healee)
		return;
	
	// GiveExperience(healer, g_pCvarHealExperience.IntValue);
	// GiveCash(healer, g_pCvarHealCash.IntValue);
	GiveBonus(healer, g_pCvarHealExperience.IntValue, g_pCvarHealCash.IntValue,
		"治疗了 %N", healee);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(healer, "[SC] exp +%d, cash +%d with heal.",
		g_pCvarHealExperience.IntValue,
		g_pCvarHealCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_PlayerAwardEarned(Event event, const char[] eventName, bool dontBroadcast)
{
	int caller = GetClientOfUserId(event.GetInt("userid"));
	int callee = event.GetInt("subjectentid");
	int award = event.GetInt("award");
	
	if(!IsValidAliveClient(caller) || !IsValidAliveClient(callee) || caller == callee)
		return;
	
	// 保护队友
	if(award == 67)
	{
		// GiveExperience(caller, g_pCvarProtectExperience.IntValue);
		// GiveCash(caller, g_pCvarProtectCash.IntValue);
		GiveBonus(caller, g_pCvarProtectExperience.IntValue, g_pCvarProtectCash.IntValue,
			"保护了 %N", callee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d with protect.",
			g_pCvarProtectExperience.IntValue,
			g_pCvarProtectCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	// 给队友递药
	else if(award == 68)
	{
		// GiveExperience(caller, g_pCvarPillExperience.IntValue);
		// GiveCash(caller, g_pCvarPillCash.IntValue);
		GiveBonus(caller, g_pCvarPillExperience.IntValue, g_pCvarPillCash.IntValue,
			"递给 %N 一瓶药", callee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d with pills.",
			g_pCvarPillExperience.IntValue,
			g_pCvarPillCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	// 给队友递针
	else if(award == 69)
	{
		// GiveExperience(caller, g_pCvarAdrenExperience.IntValue);
		// GiveCash(caller, g_pCvarAdrenCash.IntValue);
		GiveBonus(caller, g_pCvarAdrenExperience.IntValue, g_pCvarAdrenCash.IntValue,
			"递给 %N 一根针", callee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d adrenaline.",
			g_pCvarAdrenExperience.IntValue,
			g_pCvarAdrenCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	
	/*
	// 治疗队友
	else if(award == 70)
	{
		GiveExperience(caller, g_pCvarHealExperience.IntValue);
		GiveCash(caller, g_pCvarHealCash.IntValue);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d with healing.",
			g_pCvarHealExperience.IntValue,
			g_pCvarHealCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	*/
	
	/*
	// 救起挂边队友
	else if(award == 75)
	{
		GiveExperience(caller, g_pCvarLedgeExperience.IntValue);
		GiveCash(caller, g_pCvarLedgeCash.IntValue);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d with revive from ledge.",
			g_pCvarLedgeExperience.IntValue,
			g_pCvarLedgeCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	*/
	
	// 从特感手里救回队友
	else if(award == 76)
	{
		// GiveExperience(caller, g_pCvarRescueExperience.IntValue);
		// GiveCash(caller, g_pCvarRescueCash.IntValue);
		GiveBonus(caller, g_pCvarRescueExperience.IntValue, g_pCvarRescueCash.IntValue,
			"从特感手里救回 %N", callee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d saving from special.",
			g_pCvarRescueExperience.IntValue,
			g_pCvarRescueCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
	// 开门复活队友
	else if(award == 80)
	{
		// GiveExperience(caller, g_pCvarRespawnExperience.IntValue);
		// GiveCash(caller, g_pCvarRespawnCash.IntValue);
		GiveBonus(caller, g_pCvarRespawnExperience.IntValue, g_pCvarRespawnCash.IntValue,
			"开门复活 %N", callee);
		
#if defined _USE_CONSOLE_MESSAGE_
		PrintToConsole(caller, "[SC] exp +%d, cash +%d with rescue.",
			g_pCvarRespawnExperience.IntValue,
			g_pCvarRespawnCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	}
}

public void Event_JockeyRide(Event event, const char[] eventName, bool dontBroadcast)
{
	int rider = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(rider))
		return;
	
	// GiveExperience(rider, g_pCvarRideExperience.IntValue);
	// GiveCash(rider, g_pCvarRideCash.IntValue);
	GiveBonus(rider, g_pCvarRideExperience.IntValue, g_pCvarRideCash.IntValue,
		"骑在生还者脸上");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(rider, "[SC] exp +%d, cash +%d with ride.",
		g_pCvarRideExperience.IntValue,
		g_pCvarRideCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_BoomerVomit(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!event.GetBool("by_boomer"))
		return;
	
	int vomiter = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(vomiter))
		return;
	
	// GiveExperience(vomiter, g_pCvarBileExperience.IntValue);
	// GiveCash(vomiter, g_pCvarBileCash.IntValue);
	GiveBonus(vomiter, g_pCvarBileExperience.IntValue, g_pCvarBileCash.IntValue,
		"%s了生还者一脸", (event.GetBool("exploded") ? "糊" : "吐"));
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(vomiter, "[SC] exp +%d, cash +%d with bile.",
		g_pCvarBileExperience.IntValue,
		g_pCvarBileCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(victim) || GetClientTeam(victim) != 2)
		return;
	
	static ConVar survivor_it_duration;
	if(survivor_it_duration == null)
		survivor_it_duration = FindConVar("survivor_it_duration");
	
	g_iVomitAttacker[victim] = vomiter;
	
	// 这个或许可以用 CTerrorPlayer::m_itTimer 代替，但好像效果不对
	g_fVomitEndTime[victim] = GetGameTime() + survivor_it_duration.FloatValue;
}

public void Event_BoomerVomitFaded(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(victim))
		return;
	
	g_iVomitAttacker[victim] = -1;
	g_fVomitEndTime[victim] = 0.0;
}

public void Event_SmokerPulling(Event event, const char[] eventName, bool dontBroadcast)
{
	int puller = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(puller))
		return;
	
	// GiveExperience(puller, g_pCvarPullingExperience.IntValue);
	// GiveCash(puller, g_pCvarPullingCash.IntValue);
	GiveBonus(puller, g_pCvarPullingExperience.IntValue, g_pCvarPullingCash.IntValue,
		"拉走生还者");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(puller, "[SC] exp +%d, cash +%d with pulling.",
		g_pCvarPullingExperience.IntValue,
		g_pCvarPullingCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_AbilityUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	char ability[64];
	event.GetString("ability", ability, 64);
	if(StrEqual(ability, "ability_lunge", false))
		GetClientAbsOrigin(client, g_fVecHunterStart[client]);
}

public void Event_HunterPounced(Event event, const char[] eventName, bool dontBroadcast)
{
	int swoop = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(swoop))
		return;
	
	float damage = GetHunterPounceDamage(swoop);
	int experience = g_pCvarPouncedExperience.IntValue;
	int cash = g_pCvarPouncedCash.IntValue;
	if(damage >= 1.0)
	{
		experience += RoundToZero(damage * g_pCvarPounceDmgExperience.FloatValue);
		cash += RoundToZero(damage * g_pCvarPounceDmgCash.FloatValue);
	}
	
	// GiveExperience(swoop, experience);
	// GiveCash(swoop, cash);
	GiveBonus(swoop, experience, cash, "扑到了生还者身上，伤害 %.0f", damage);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(swoop, "[SC] exp +%d, cash +%d with pounced.",
		g_pCvarPouncedExperience.IntValue,
		g_pCvarPouncedCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

stock float GetHunterPounceDamage(int client)
{
	static ConVar cvMaxRange, cvMinRange, cvDamage;
	if(cvDamage == null)
	{
		cvMaxRange = FindConVar("z_pounce_damage_range_max");
		cvMinRange = FindConVar("z_pounce_damage_range_min");
		cvDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
	}
	
	// distance supplied isn't the actual 2d vector distance needed for damage calculation. See more about it at
	// http://forums.alliedmods.net/showthread.php?t=93207
	// new eventDistance = GetEventInt(event, "distance");
	
	//get hunter-related pounce cvars
	float max = (cvMaxRange ? cvMaxRange.FloatValue : 1024.0);
	float min = (cvMinRange ? cvMinRange.FloatValue : 300.0);
	float maxDmg = cvDamage.FloatValue;
	
	float position[3];
	GetClientAbsOrigin(client, position);
	
	float distance = GetVectorDistance(g_fVecHunterStart[client], position);
	if(distance < min)
		return 0.0;
	
	return (((distance - min) / max - min) * maxDmg) + 1.0;
}

public void Event_ChargerCarry(Event event, const char[] eventName, bool dontBroadcast)
{
	int carrier = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(carrier))
		return;
	
	// GiveExperience(carrier, g_pCvarCarryExperience.IntValue);
	// GiveCash(carrier, g_pCvarCarryCash.IntValue);
	GiveBonus(carrier, g_pCvarCarryExperience.IntValue, g_pCvarCarryCash.IntValue,
		"把生还者带走");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(carrier, "[SC] exp +%d, cash +%d with carry.",
		g_pCvarCarryExperience.IntValue,
		g_pCvarCarryCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_ChargerImpact(Event event, const char[] eventName, bool dontBroadcast)
{
	int impactor = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(impactor))
		return;
	
	// GiveExperience(impactor, g_pCvarImpactExperience.IntValue);
	// GiveCash(impactor, g_pCvarImpactCash.IntValue);
	GiveBonus(impactor, g_pCvarImpactExperience.IntValue, g_pCvarImpactCash.IntValue,
		"把生还者撞飞");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(impactor, "[SC] exp +%d, cash +%d with impact.",
		g_pCvarImpactExperience.IntValue,
		g_pCvarImpactCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_ChargerPummel(Event event, const char[] eventName, bool dontBroadcast)
{
	int hammer = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(hammer))
		return;
	
	// GiveExperience(hammer, g_pCvarPummelExperience.IntValue);
	// GiveCash(hammer, g_pCvarPummelCash.IntValue);
	GiveBonus(hammer, g_pCvarPummelExperience.IntValue, g_pCvarPummelCash.IntValue,
		"把生还者按到地上");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(hammer, "[SC] exp +%d, cash +%d with pummel.",
		g_pCvarPummelExperience.IntValue,
		g_pCvarPummelCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public void Event_MissionComplete(Event event, const char[] eventName, bool dontBroadcast)
{
	int total = 0;
	int aliveList[MAXPLAYERS];
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
			continue;
		
		aliveList[total++] = i;
	}
	
	for(int i = 0; i < total; ++i)
		RoundEndSurvivorReward(aliveList[i], total);
}

public void Event_FinaleComplete(Event event, const char[] eventName, bool dontBroadcast)
{
	int total = 0;
	int aliveList[MAXPLAYERS];
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2 || IsPlayerIncapacitated(i) ||
			IsPlayerHanging(i) || IsPlayerFalling(i))
			continue;
		
		aliveList[total++] = i;
	}
	
	for(int i = 0; i < total; ++i)
		RoundEndSurvivorReward(aliveList[i], total);
}

void RoundEndSurvivorReward(int client, int total)
{
	if(total <= 0 || !IsValidAliveClient(client) || GetClientTeam(client) != 2)
		return;
	
	int experience = g_pCvarAliveExperience.IntValue * total;
	int cash = g_pCvarAliveCash.IntValue * total;
	
	// 没倒地挂边需要计算血分
	if(!IsPlayerIncapacitated(client) && !IsPlayerHanging(client) && !IsPlayerFalling(client))
	{
#if defined _USE_PLUGIN_MAX_HEALTH_
		int maxHealth = g_iMaxHealth[client] + g_iDefaultHealth[client];
#else
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
#endif	// _USE_PLUGIN_MAX_HEALTH_
		
		int health = GetEntProp(client, Prop_Data, "m_iHealth");
		int buffer = GetPlayerTempHealth(client);
		
		if(health >= maxHealth)
		{
			health = maxHealth;
			buffer = 0;
		}
		else if(health + buffer > maxHealth)
		{
			buffer = maxHealth - health;
			if(buffer < 0)
				buffer = 0;
		}
		
		// 实血
		experience += g_pCvarRealExperience.IntValue * health;
		cash += g_pCvarRealCash.IntValue * health;
		
		// 虚血
		experience += g_pCvarTempExperience.IntValue * buffer;
		cash += g_pCvarTempCash.IntValue * buffer;
	}
	
	// GiveExperience(client, experience);
	// GiveCash(client, cash);
	GiveBonus(client, experience, cash, "进入 安全室/救援载具 过关");
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(client, "[SC] exp +%d, cash +%d with mission complete, alive %d.", experience, cash, total);
#endif	// _USE_CONSOLE_MESSAGE_
}

#if defined _USE_SKILL_DETECT_
public int OnSkeet(int survivor, int hunter)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarSkeetExperience.IntValue);
	// GiveCash(survivor, g_pCvarSkeetCash.IntValue);
	GiveBonus(survivor, g_pCvarSkeetExperience.IntValue, g_pCvarSkeetCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with skeet.",
		g_pCvarSkeetExperience.IntValue,
		g_pCvarSkeetCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnSkeetMelee(int survivor, int hunter)
{
	OnSkeet(survivor, hunter);
}

public int OnSkeetGL(int survivor, int hunter)
{
	OnSkeet(survivor, hunter);
}

public int OnSkeetSniper(int survivor, int hunter)
{
	OnSkeet(survivor, hunter);
}

public int OnSkeetHurt(int survivor, int hunter, int damage, bool isOverkill)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarHurtSkeetExperience.IntValue);
	// GiveCash(survivor, g_pCvarHurtSkeetCash.IntValue);
	GiveBonus(survivor, g_pCvarHurtSkeetExperience.IntValue, g_pCvarHurtSkeetCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with hurt skeet.",
		g_pCvarHurtSkeetExperience.IntValue,
		g_pCvarHurtSkeetCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnSkeetMeleeHurt(int survivor, int hunter, int damage, bool isOverkill)
{
	OnSkeetHurt(survivor, hunter, damage, isOverkill);
}

public int OnSkeetSniperHurt(int survivor, int hunter, int damage, bool isOverkill)
{
	OnSkeetHurt(survivor, hunter, damage, isOverkill);
}

public int OnBoomerPop(int survivor, int boomer, int shoveCount, float timeAlive)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarBoomerPopExperience.IntValue);
	// GiveCash(survivor, g_pCvarBoomerPopCash.IntValue);
	GiveBonus(survivor, g_pCvarBoomerPopExperience.IntValue, g_pCvarBoomerPopCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with boomer popped.",
		g_pCvarBoomerPopExperience.IntValue,
		g_pCvarBoomerPopCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnChargerLevel(int survivor, int charger)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarLeveledExperience.IntValue);
	// GiveCash(survivor, g_pCvarLeveledCash.IntValue);
	GiveBonus(survivor, g_pCvarLeveledExperience.IntValue, g_pCvarLeveledCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with level.",
		g_pCvarLeveledExperience.IntValue,
		g_pCvarLeveledCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnChargerLevelHurt(int survivor, int charger)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarHurtLeveledExperience.IntValue);
	// GiveCash(survivor, g_pCvarHurtLeveledCash.IntValue);
	GiveBonus(survivor, g_pCvarHurtLeveledExperience.IntValue, g_pCvarHurtLeveledCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with level.",
		g_pCvarHurtLeveledExperience.IntValue,
		g_pCvarHurtLeveledCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnWitchCrown(int survivor, int damage)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarCrownExperience.IntValue);
	// GiveCash(survivor, g_pCvarCrownCash.IntValue);
	GiveBonus(survivor, g_pCvarCrownExperience.IntValue, g_pCvarCrownCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with crown.",
		g_pCvarCrownExperience.IntValue,
		g_pCvarCrownCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnWitchCrownHurt(int survivor, int damage, int chipDamage)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarHurtCrownExperience.IntValue);
	// GiveCash(survivor, g_pCvarHurtCrownCash.IntValue);
	GiveBonus(survivor, g_pCvarHurtCrownExperience.IntValue, g_pCvarHurtCrownCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with lure crown.",
		g_pCvarHurtCrownExperience.IntValue,
		g_pCvarHurtCrownCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnTongueCut(int survivor, int smoker)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarTongueCutExperience.IntValue);
	// GiveCash(survivor, g_pCvarTongueCutCash.IntValue);
	GiveBonus(survivor, g_pCvarTongueCutExperience.IntValue, g_pCvarTongueCutCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with tongue cut.",
		g_pCvarTongueCutExperience.IntValue,
		g_pCvarTongueCutCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnSmokerSelfClear(int survivor, int smoker, bool withShove)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarTongueClearExperience.IntValue);
	// GiveCash(survivor, g_pCvarTongueClearCash.IntValue);
	GiveBonus(survivor, g_pCvarTongueClearExperience.IntValue, g_pCvarTongueClearCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with tongue self clear.",
		g_pCvarTongueClearExperience.IntValue,
		g_pCvarTongueClearCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnTankRockSkeeted(int survivor, int tank)
{
	if(!IsValidAliveClient(survivor))
		return;
	
	// GiveExperience(survivor, g_pCvarRockSkeetExperience.IntValue);
	// GiveCash(survivor, g_pCvarRockSkeetCash.IntValue);
	GiveBonus(survivor, g_pCvarRockSkeetExperience.IntValue, g_pCvarRockSkeetCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with rock skeeted.",
		g_pCvarRockSkeetExperience.IntValue,
		g_pCvarRockSkeetCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnBunnyHopStreak(int survivor, int streak, float maxVelocity)
{
	if(!IsValidAliveClient(survivor) || streak < 3 || maxVelocity < 210.0)
		return;
	
	// GiveExperience(survivor, g_pCvarBunnyHopExperience.IntValue * streak);
	// GiveCash(survivor, g_pCvarBunnyHopCash.IntValue * streak);
	GiveBonus(survivor, g_pCvarBunnyHopExperience.IntValue, g_pCvarBunnyHopCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(survivor, "[SC] exp +%d, cash +%d with bhop.",
		g_pCvarBunnyHopExperience.IntValue * streak,
		g_pCvarBunnyHopCash.IntValue * streak);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnHunterHighPounce(int hunter, int survivor, int actualDamage, float calculatedDamage,
	float height, bool reportedHigh)
{
	if(!IsValidAliveClient(hunter))
		return;
	
	// GiveExperience(hunter, g_pCvarHighPounceExperience.IntValue);
	// GiveCash(hunter, g_pCvarHighPounceCash.IntValue);
	GiveBonus(hunter, g_pCvarHighPounceExperience.IntValue, g_pCvarHighPounceCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(hunter, "[SC] exp +%d, cash +%d with high pounce.",
		g_pCvarHighPounceExperience.IntValue,
		g_pCvarHighPounceCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnJockeyHighPounce(int jockey, int victim, float height, bool reportedHigh)
{
	if(!IsValidAliveClient(jockey))
		return;
	
	// GiveExperience(jockey, g_pCvarHighRideExperience.IntValue);
	// GiveCash(jockey, g_pCvarHighRideCash.IntValue);
	GiveBonus(jockey, g_pCvarHighRideExperience.IntValue, g_pCvarHighRideCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(jockey, "[SC] exp +%d, cash +%d with high ride.",
		g_pCvarHighRideExperience.IntValue,
		g_pCvarHighRideCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnDeathCharge(int charger, int survivor, float height, float distance, bool wasCarried)
{
	if(!IsValidAliveClient(charger))
		return;
	
	// GiveExperience(charger, g_pCvarDeathChargeExperience.IntValue);
	// GiveCash(charger, g_pCvarDeathChargeCash.IntValue);
	GiveBonus(charger, g_pCvarDeathChargeExperience.IntValue, g_pCvarDeathChargeCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(charger, "[SC] exp +%d, cash +%d with dead charge.",
		g_pCvarDeathChargeExperience.IntValue,
		g_pCvarDeathChargeCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}

public int OnBoomerVomitLanded(int boomer, int amount)
{
	if(!IsValidAliveClient(boomer) || amount < 4)
		return;
	
	// GiveExperience(boomer, g_pCvarVomitLandedExperience.IntValue);
	// GiveCash(boomer, g_pCvarVomitLandedCash.IntValue);
	GiveBonus(boomer, g_pCvarVomitLandedExperience.IntValue, g_pCvarVomitLandedCash.IntValue);
	
#if defined _USE_CONSOLE_MESSAGE_
	PrintToConsole(boomer, "[SC] exp +%d, cash +%d with vomit landed.",
		g_pCvarVomitLandedExperience.IntValue,
		g_pCvarVomitLandedCash.IntValue);
#endif	// _USE_CONSOLE_MESSAGE_
}
#endif	// _USE_SKILL_DETECT_

#if !defined _USE_DETOUR_FUNC_
public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false))
		SDKHook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
}

public void OnEntityDestroyed(int entity)
{
	UninstallPlayerHook(entity);
}

#endif

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
					CPrintToChat(i, "\x03[SC]\x01 %T", "进入战斗状态", i);
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
				
				if(g_fWillpower[i] < g_iMaxWillpower[i])
					WillpowerIncrease(i, g_fCombatWillpower * g_iMaxWillpower[i] / g_iGameFramePerSecond);
			}
			else
			{
				if(g_fStamina[i] < g_iMaxStamina[i])
					StaminaIncrease(i, g_fSafeStamina * g_iMaxStamina[i] / g_iGameFramePerSecond);
				
				if(g_fMagic[i] < g_iMaxMagic[i])
					MagicIncrease(i, g_fSafeMagic * g_iMaxMagic[i] / g_iGameFramePerSecond);
				
				if(g_fWillpower[i] < g_iMaxWillpower[i])
					WillpowerIncrease(i, g_fSafeWillpower * g_iMaxWillpower[i] / g_iGameFramePerSecond);
			}
		}
		
		// 升级检查(可以不要)
		if(g_iExperience[i] >= g_iNextLevel[i])
		{
			if(CheckLevelUp(i) && g_pCvarAllow.BoolValue)
			{
				CPrintToChat(i, "\x03[SC]\x01 %T", "你升级了", i,
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
		if(g_bMenuFlush && g_iPlayerMenu[i] > 0)
		{
			switch(g_iPlayerMenu[i])
			{
				case 1:
					Cmd_MainMenu(i, 0);
				case 2:
					Cmd_AttributesMenu(i, 0);
				case 3:
					Cmd_SpellMenu(i, 0);
				case 4:
					Cmd_BuySpellMenu(i, 0);
				case 5:
					Cmd_SkillMenu(i, 0);
			}
		}
		
		// 一下三种情况只可以出现一种
		// 因为某个玩家不可能同时扮演 生还者/口水/控人特感
		if(g_iCommonKillTotal[i] > 0)
		{
			// GiveExperience(i, g_pCvarKilledExperience[Z_COMMON].IntValue * g_iCommonKillTotal[i]);
			// GiveCash(i, g_pCvarKilledCash[Z_COMMON].IntValue * g_iCommonKillTotal[i]);
			GiveBonus(i, RoundToZero(g_pCvarKilledExperience[Z_COMMON].FloatValue * g_iCommonKillTotal[i]),
				RoundToZero(g_pCvarKilledCash[Z_COMMON].FloatValue * g_iCommonKillTotal[i]),
				"打死 %d 普感", g_iCommonKillTotal[i]);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with kills infected %d.",
				g_pCvarKilledExperience[Z_COMMON].FloatValue * g_iCommonKillTotal[i],
				g_pCvarKilledCash[Z_COMMON].FloatValue * g_iCommonKillTotal[i],
				g_iCommonKillTotal[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iCommonKillTotal[i] = 0;
		}
		if(g_iDamageSpitTotal[i] > 0)
		{
			// GiveExperience(i, g_pCvarSpitExperience.IntValue * g_iDamageSpitTotal[i]);
			// GiveCash(i, g_pCvarSpitCash.IntValue * g_iDamageSpitTotal[i]);
			GiveBonus(i, RoundToZero(g_pCvarSpitExperience.FloatValue * g_iDamageSpitTotal[i]),
				RoundToZero(g_pCvarSpitCash.FloatValue * g_iDamageSpitTotal[i]),
				"酸液烫到生还者 %d 次", g_iDamageSpitTotal[i]);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with spit %d.",
				g_pCvarSpitExperience.FloatValue * g_iDamageSpitTotal[i],
				g_pCvarSpitCash.FloatValue * g_iDamageSpitTotal[i],
				g_iDamageSpitTotal[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iDamageSpitTotal[i] = 0;
		}
		if(g_iAttackTotal[i] > 0)
		{
			// GiveExperience(i, g_pCvarAttackExperience.IntValue * g_iAttackTotal[i]);
			// GiveCash(i, g_pCvarAttackCash.IntValue * g_iAttackTotal[i]);
			GiveBonus(i, RoundToZero(g_pCvarAttackExperience.FloatValue * g_iAttackTotal[i]),
				RoundToZero(g_pCvarAttackCash.FloatValue * g_iAttackTotal[i]),
				"控制幸存者并攻击 %d 次", g_iAttackTotal[i]);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with attack %d.",
				g_pCvarAttackExperience.FloatValue * g_iAttackTotal[i],
				g_pCvarAttackCash.FloatValue * g_iAttackTotal[i],
				g_iAttackTotal[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iAttackTotal[i] = 0;
		}
		if(g_iDamageAssistTotal[i] > 0)
		{
			// GiveExperience(i, g_pCvarAssistExperience.IntValue * g_iDamageAssistTotal[i]);
			// GiveCash(i, g_pCvarAssistCash.IntValue * g_iDamageAssistTotal[i]);
			GiveBonus(i, RoundToZero(g_pCvarAssistExperience.FloatValue * g_iDamageAssistTotal[i]),
				RoundToZero(g_pCvarAssistCash.FloatValue * g_iDamageAssistTotal[i]),
				"胆汁助攻 %d 次", g_iDamageAssistTotal[i]);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with assist %d.",
				RoundToZero(g_pCvarAssistExperience.FloatValue * g_iDamageAssistTotal[i]),
				RoundToZero(g_pCvarAssistCash.FloatValue * g_iDamageAssistTotal[i]),
				g_iDamageAssistTotal[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iDamageAssistTotal[i] = 0;
		}
		if(g_iTankPropTotal[i] > 0)
		{
			// GiveExperience(i, g_pCvarTankPropExperience.IntValue * g_iTankPropTotal[i]);
			// GiveCash(i, g_pCvarTankPropCash.IntValue * g_iTankPropTotal[i]);
			GiveBonus(i, RoundToZero(g_pCvarTankPropExperience.FloatValue * g_iTankPropTotal[i]),
				RoundToZero(g_pCvarTankPropCash.FloatValue * g_iTankPropTotal[i]),
				"打铁命中 %d 次", g_iTankPropTotal[i]);
			
#if defined _USE_CONSOLE_MESSAGE_
			PrintToConsole(i, "[SC] exp +%.0f, cash +%.0f with prop %d.",
				g_pCvarTankPropExperience.FloatValue * g_iTankPropTotal[i],
				g_pCvarTankPropCash.FloatValue * g_iTankPropTotal[i],
				g_iTankPropTotal[i]);
#endif	// _USE_CONSOLE_MESSAGE_
			
			g_iTankPropTotal[i] = 0;
		}
		
		// 站立不动自动回血
		if(IsPlayerAlive(i) && !IsPlayerGhost(i) && g_fMagic[i] >= g_iStandingLimit && g_fNextStandingTime[i] <= time)
		{
#if defined _USE_PLUGIN_MAX_HEALTH_
			int maxHealth = g_iMaxHealth[i] + g_iDefaultHealth[i];
#else
			int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
#endif	// _USE_PLUGIN_MAX_HEALTH_
			
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			float buffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");
			
			if(health + buffer < maxHealth && (GetClientTeam(i) == 3 ||
				(!g_bInBattle[i] && GetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 1))))
			{
				float amount = g_iMaxMagic[i] * g_fStandingFactor * g_fThinkInterval;
				if(amount > g_fMagic[i])
					amount = g_fMagic[i];
				
				MagicDecrease(i, amount);
				AddHealth(i, RoundToCeil(amount), true);
				// ClientCommand(i, "play \"ui/beep07.wav\"");
				EmitSoundToClient(i, SOUND_STANDING_HEAL, _, SNDCHAN_VOICE, SNDLEVEL_HOME);
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

stock bool AddHealth(int client, int amount, bool limit = true)
{
	if(!IsValidAliveClient(client) || amount == 0)
		return false;

	int team = GetClientTeam(client);
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	
#if defined _USE_PLUGIN_MAX_HEALTH_
	int maxHealth = g_iMaxHealth[client] + g_iDefaultHealth[client];
#else
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
#endif	// _USE_PLUGIN_MAX_HEALTH_
	
	if(team == 2 && !IsPlayerIncapacitated(client) && !IsPlayerHanging(client))
	{
		float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
		
		buffer += amount;
		if(buffer > 200.0)
		{
			health += RoundToZero(buffer - 200.0);
			buffer = 200.0;
		}
		
		if(limit)
		{
			if(health + RoundToCeil(buffer) > maxHealth)
				buffer = float(maxHealth - health);
			if(health > maxHealth)
				health = maxHealth;
			if(buffer < 0.0)
				buffer = 0.0;
		}

		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	else
	{
		health += amount;
		if(limit)
		{
			if(health > maxHealth)
				health = maxHealth;
		}
	}

	SetEntProp(client, Prop_Data, "m_iHealth", health);
	return true;
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
		CPrintToChat(client, "\x03[SC]\x01 %T", "离开战斗状态", client);
	
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
#define SPRINT_BUTTON			(IN_WALK|IN_ALT1|IN_ALT2|IN_SPEED)

// 这些按键被按住后无法冲刺
#define INVALID_SPRINT_BUTTON	(IN_BACK|IN_LEFT|IN_RIGHT|IN_MOVELEFT|IN_MOVERIGHT|IN_DUCK|IN_JUMP)

// 移动按钮
#define MOVING_BUTTON			(IN_FORWARD|IN_BACK|IN_LEFT|IN_RIGHT|IN_MOVELEFT|IN_MOVERIGHT|IN_JUMP)

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3],
	int &weapons, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	bool hasChanged = false;
	int flags = GetEntityFlags(client);
	
	if(g_bInSprint[client])
	{
		if(!g_bSprintAllow || !(buttons & SPRINT_BUTTON) || g_fStamina[client] < g_iSprintLimit ||
			(buttons & INVALID_SPRINT_BUTTON) || (g_fSprintDuck <= 0.0 && (flags & FL_DUCKING)) ||
			(g_fSprintWater <= 0.0 && (flags & FL_INWATER)) || (g_fSprintWalk <= 0 && (flags & FL_ONGROUND)) ||
			(!g_bSprintAttack && (buttons & IN_ATTACK)) || (!g_bSprintShove && (buttons & IN_ATTACK2)) ||
			(!g_bSprintJump && (buttons & IN_JUMP)))
		{
			g_bInSprint[client] = false;
			g_fSprintSpeed[client] = 0.0;
		}
		else if(buttons & IN_SPEED)
		{
			// 强制把静音走改为冲刺
			buttons &= ~IN_SPEED;
			hasChanged = true;
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
	}
	
	/*
	if(g_bInSprint[client] && g_fSprintSpeed[client] > 0.0)
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSprintSpeed[client]);
	else
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	*/
	
	if(IsPlayerAlive(client))
	{
		if(!(flags & FL_ONGROUND) || (buttons & MOVING_BUTTON) || GetVectorLength(vel, false) > 15.0 ||
			GetCurrentAttacker(client) > 0 || GetCurrentVictim(client) > 0)
			g_fNextStandingTime[client] = GetGameTime() + g_fStandingDelay;
	}
	
	if(hasChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

// 不是有效的攻击伤害
const int INVALID_DAMAGE_TYPE = (DMG_FALL|DMG_BURN|DMG_BLAST);

Action HandleTakeDamage(int victim, int attacker, float& damage, int& damageType, int inflictor = 0, int weapon = -1,
	const float damageForce[3] = NULL_VECTOR, const float damagePosition[3] = NULL_VECTOR)
{
	if(victim < 1 || attacker < 1 || victim == attacker || !IsValidEdict(victim) || !IsValidEdict(attacker) ||
		(damageType & INVALID_DAMAGE_TYPE) || !HasEntProp(victim, Prop_Send, "m_iTeamNum") ||
		!HasEntProp(attacker, Prop_Send, "m_iTeamNum"))
		return Plugin_Continue;
	
	bool isSameTeam = (GetEntProp(attacker, Prop_Send, "m_iTeamNum") == GetEntProp(victim, Prop_Send, "m_iTeamNum"));
	
	// 修复 BOT 攻击队友造成伤害
	if(isSameTeam && IsValidClient(attacker) && IsValidClient(victim) && IsFakeClient(attacker))
		return Plugin_Handled;
	
	int grabber = GetCurrentAttacker(victim);
	
	// 修复攻击被控队友
	if(isSameTeam && grabber > 0 && IsValidClient(attacker) && IsValidClient(victim))
	{
		SDKHooks_TakeDamage(grabber, inflictor, attacker, damage, damageType, weapon, damageForce, damagePosition);
		return Plugin_Handled;
	}
	
	float plusDamage = 0.0, minusDamage = 0.0;
	
	// 精力增加伤害
	if(IsValidClient(attacker) && damage >= g_iDamageMin && (g_bDamageFriendly || !isSameTeam))
	{
		SetRandomSeed(GetSysTickCount() + attacker);
		if(g_fWillpower[attacker] >= g_iDamageLimit &&
			GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) <= g_fDamageChance[attacker])
		{
			plusDamage = damage * g_fDamageFactor[attacker];
			if(plusDamage > g_fWillpower[attacker])
				plusDamage = g_fWillpower[attacker];
		}
	}
	
	// 耐力减少伤害
	if(IsValidClient(victim) && damage >= g_iDefenseMin && (g_bDefenseFriendly || !isSameTeam))
	{
		SetRandomSeed(GetSysTickCount() + victim);
		if(g_fStamina[victim] >= g_iDefenseLimit &&
			GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) <= g_fDefenseChance[victim])
		{
			minusDamage = damage * g_fDefenseFactor[victim];
			if(minusDamage > g_fStamina[victim])
				minusDamage = g_fStamina[victim];
		}
	}
	
	float refDamage = damage;
	int refDamageType = damageType;
	float refPlusDmg = plusDamage;
	float refMinusDmg = minusDamage;
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnDamagePre);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushFloatRef(refDamage);
	Call_PushCellRef(refDamageType);
	Call_PushFloatRef(refPlusDmg);
	Call_PushFloatRef(refMinusDmg);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return Plugin_Handled;
	
	if(result == Plugin_Changed)
	{
		damage = refDamage;
		damageType = refDamageType;
		plusDamage = refPlusDmg;
		minusDamage = refMinusDmg;
	}
	
	int health = GetEntProp(victim, Prop_Data, "m_iHealth");
	if(GetEntProp(victim, Prop_Send, "m_iTeamNum") == 2)
		health += GetPlayerTempHealth(victim);
	
	float fakeDamage = (health - damage - plusDamage + minusDamage);
	if(fakeDamage < 0.0)
	{
		// 去除溢出伤害，减少不必要的精力消耗
		// 加一个负数，相当于减少伤害
		plusDamage += fakeDamage;
	}
	
	if(plusDamage >= 1.0)
	{
		// PrintCenterText(attacker, "＋%.0f dmg of %.0f dmg", plusDamage, damage);
		
		damage += plusDamage;
		damageType |= DMG_CRIT;
		WillpowerDecrease(attacker, plusDamage);
	}
	
	if(minusDamage >= 1.0)
	{
		// PrintCenterText(victim, "－%.0f dmg of %.0f dmg", minusDamage, damage);
		
		damage -= minusDamage;
		StaminaDecrease(victim, minusDamage);
	}
	
	Call_StartForward(g_fwOnDamagePost);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushFloat(damage);
	Call_PushCell(damageType);
	Call_PushFloat(plusDamage);
	Call_PushFloat(minusDamage);
	Call_Finish();
	
	if(damage < 1.0)
		damage = 1.0;
	
	return Plugin_Changed;
}

// 这里是初始伤害，最终伤害将会根据难度调整
public Action PlayerHook_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &ammotype, int hitbox, int hitgroup)
{
	/*
	if(!IsValidClient(attacker) || !IsValidEdict(victim) || damage < g_iDamageMin || (damagetype & INVALID_DAMAGE_TYPE))
		return Plugin_Continue;
	
	if(!g_bDamageFriendly && GetClientTeam(attacker) == GetEntProp(victim, Prop_Send, "m_iTeamNum"))
		return Plugin_Continue;
	
	if(g_fWillpower[attacker] < g_iDamageLimit)
		return Plugin_Continue;
	
	SetRandomSeed(view_as<int>(GetGameTime()));
	if(GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) > g_fDamageChance[attacker])
		return Plugin_Continue;
	
	float plusDamage = damage * g_fDamageFactor[attacker];
	if(plusDamage > g_fWillpower[attacker])
		plusDamage = g_fWillpower[attacker];
	
	if(plusDamage < 1.0)
		return Plugin_Continue;
	
	// PrintCenterText(attacker, "plus %.0f + %.0f damage", damage, plusDamage);
	
	damage += plusDamage;
	damagetype |= DMG_CRIT;
	WillpowerDecrease(attacker, plusDamage);
	return Plugin_Changed;
	*/
	
	return HandleTakeDamage(victim, attacker, damage, damagetype);
}

// 这里是最终受到的伤害
// 调用顺序：TraceAttack -> OnTakeDamage -> OnTakeDamage_Alive -> player_hurt
// 其中 OnTakeDamage_Alive 是玩家专属的
// 获取到的伤害很奇怪，被僵尸打一下会触发多次，并且每次伤害数量都不同，有时候伤害修改也没效果（例如 Spitter 酸液伤害）
public Action PlayerHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	/*
	if(!IsValidClient(victim) || attacker <= 0 || !IsValidEdict(attacker) || damage < g_iDefenseMin || (damagetype & INVALID_DAMAGE_TYPE))
		return Plugin_Continue;
	
	if(!g_bDefenseFriendly && GetEntProp(attacker, Prop_Send, "m_iTeamNum") == GetClientTeam(victim))
		return Plugin_Continue;
	
	if(g_fStamina[victim] < g_iDefenseLimit)
		return Plugin_Continue;
	
	SetRandomSeed(view_as<int>(GetEngineTime()));
	if(GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) > g_fDefenseChance[victim])
		return Plugin_Continue;
	
	float minusDamage = damage * g_fDefenseFactor[victim];
	if(minusDamage - 1.0 > damage)
		minusDamage = damage - 1.0;
	
	if(minusDamage > g_fStamina[victim])
		minusDamage = g_fStamina[victim];
	
	if(minusDamage < 1.0)
		return Plugin_Continue;
	
	// PrintCenterText(victim, "take %.0f - %.0f damage", damage, minusDamage);
	
	damage -= minusDamage;
	StaminaDecrease(victim, minusDamage);
	return Plugin_Changed;
	*/
	
	return HandleTakeDamage(victim, attacker, damage, damagetype, inflictor, weapon, damageForce, damagePosition);
}

#if defined _USE_DETOUR_FUNC_
// 最终受到的伤害，这里已经不会被其他东西修改了，可以放心设置
public MRESReturn Hooked_AllowTakeDamage(Address pThis, Handle hReturn, Handle hParams)
{
	
	int victim = DHookGetParam(hParams, 1);
	int attacker = DHookGetParamObjectPtrVar(hParams, 2, 52, ObjectValueType_Ehandle);
	float damage = DHookGetParamObjectPtrVar(hParams, 2, 60, ObjectValueType_Float);
	int damageType = DHookGetParamObjectPtrVar(hParams, 2, 72, ObjectValueType_Int);
	// int weapon = DHookGetParamObjectPtrVar(hParams, 2, 56, ObjectValueType_Ehandle);
	
	/*
	if(victim < 1 || attacker < 1 || victim == attacker || !IsValidEdict(victim) || !IsValidEdict(attacker) ||
		(damageType & INVALID_DAMAGE_TYPE) || !HasEntProp(victim, Prop_Send, "m_iTeamNum") ||
		!HasEntProp(attacker, Prop_Send, "m_iTeamNum"))
		return MRES_Ignored;
	
	bool isSameTeam = (GetEntProp(attacker, Prop_Send, "m_iTeamNum") == GetEntProp(victim, Prop_Send, "m_iTeamNum"));
	
	// 修复 BOT 攻击队友造成伤害
	if(isSameTeam && IsValidClient(attacker) && IsValidClient(victim) && IsFakeClient(attacker))
	{
		DHookSetReturn(hReturn, false);
		return MRES_Override;
	}
	
	float plusDamage = 0.0, minusDamage = 0.0;
	if(IsValidClient(attacker) && damage >= g_iDamageMin && (g_bDamageFriendly || !isSameTeam))
	{
		SetRandomSeed(GetSysTickCount() + attacker);
		if(g_fWillpower[attacker] >= g_iDamageLimit &&
			GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) <= g_fDamageChance[attacker])
		{
			plusDamage = damage * g_fDamageFactor[attacker];
			if(plusDamage > g_fWillpower[attacker])
				plusDamage = g_fWillpower[attacker];
		}
	}
	
	if(IsValidClient(victim) && damage >= g_iDefenseMin && (g_bDefenseFriendly || !isSameTeam))
	{
		SetRandomSeed(GetSysTickCount() + victim);
		if(g_fStamina[victim] >= g_iDefenseLimit &&
			GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) <= g_fDefenseChance[victim])
		{
			minusDamage = damage * g_fDefenseFactor[victim];
			if(minusDamage > g_fStamina[victim])
				minusDamage = g_fStamina[victim];
		}
	}
	
	float refDamage = damage;
	int refDamageType = damageType;
	float refPlusDmg = plusDamage;
	float refMinusDmg = minusDamage;
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnDamagePre);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushFloatRef(refDamage);
	Call_PushCellRef(refDamageType);
	Call_PushFloatRef(refPlusDmg);
	Call_PushFloatRef(refMinusDmg);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return MRES_Ignored;
	
	if(result == Plugin_Changed)
	{
		damage = refDamage;
		damageType = refDamageType;
		plusDamage = refPlusDmg;
		minusDamage = refMinusDmg;
	}
	
	float fakeDamage = (GetEntProp(victim, Prop_Data, "m_iHealth") - damage - plusDamage + minusDamage);
	if(fakeDamage < 0.0)
	{
		// 去除溢出伤害，减少不必要的精力消耗
		plusDamage += fakeDamage;
	}
	
	if(plusDamage >= 1.0)
	{
		// PrintCenterText(attacker, "＋%.0f dmg of %.0f dmg", plusDamage, damage);
		
		damage += plusDamage;
		damageType |= DMG_CRIT;
		WillpowerDecrease(attacker, plusDamage);
	}
	
	if(minusDamage >= 1.0)
	{
		// PrintCenterText(victim, "－%.0f dmg of %.0f dmg", minusDamage, damage);
		
		damage -= minusDamage;
		StaminaDecrease(victim, minusDamage);
	}
	
	Call_StartForward(g_fwOnDamagePost);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushFloat(damage);
	Call_PushCell(damageType);
	Call_PushFloat(plusDamage);
	Call_PushFloat(minusDamage);
	Call_Finish();
	*/
	
	/*
	if(!IsValidClient(victim) || attacker <= 0 || !IsValidEdict(attacker) || damage < g_iDefenseMin ||
		(damageType & INVALID_DAMAGE_TYPE))
		return MRES_Ignored;
	
	if(!g_bDefenseFriendly && GetEntProp(attacker, Prop_Send, "m_iTeamNum") == GetClientTeam(victim))
		return MRES_Ignored;
	
	if(g_fStamina[victim] < g_iDefenseLimit)
		return MRES_Ignored;
	
	SetRandomSeed(view_as<int>(GetEngineTime()));
	if(GetRandomFloat(MIN_TRIGGER_CHANCE, 1.0) > g_fDefenseChance[victim])
		return MRES_Ignored;
	
	float minusDamage = damage * g_fDefenseFactor[victim];
	if(minusDamage - 1.0 > damage)
		minusDamage = damage - 1.0;
	
	if(minusDamage > g_fStamina[victim])
		minusDamage = g_fStamina[victim];
	
	// 才这么点伤害，没必要去减少了
	if(minusDamage < 1.0)
		return MRES_Ignored;
	
	// PrintCenterText(victim, "take %.0f - %.0f damage", damage, minusDamage);
	
	damage -= minusDamage;
	StaminaDecrease(victim, minusDamage);
	// PrintToChat(victim, "dmg %.0f", damage);
	*/
	
	/*
	if(damage < 1.0)
		damage = 1.0;
	*/
	
	Action result = HandleTakeDamage(victim, attacker, damage, damageType);
	if(result == Plugin_Continue)
		return MRES_Ignored;
	
	if(result >= Plugin_Handled)
	{
		DHookSetReturn(hReturn, false);
		return MRES_Override;
	}
	
	DHookSetParamObjectPtrVar(hParams, 2, 60, ObjectValueType_Float, damage);
	DHookSetParamObjectPtrVar(hParams, 2, 72, ObjectValueType_Int, damageType);
	return MRES_ChangedHandled;
}
#endif	// _USE_DETOUR_FUNC_

public void PlayerHook_OnTankPropDamage(int victim, int attacker, int inflictor, float damage, int damagetype,
	int weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsValidClient(victim) || !IsValidClient(attacker) || damage <= 0.0 || !IsValidEntity(inflictor) ||
		inflictor == attacker || GetClientTeam(victim) != 2 || GetClientTeam(attacker) != 3 ||
		GetEntProp(attacker, Prop_Send, "m_zombieClass") != Z_TANK || IsPlayerIncapacitated(victim) ||
		IsPlayerFalling(victim) || IsPlayerHanging(victim))
		return;
	
	char classname[64];
	GetEntityClassname(inflictor, classname, 64);
	if(StrContains(classname, "prop_", false) != 0)
		return;
	
	g_iTankPropTotal[attacker] += 1;
}

public void ZombieHook_OnSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	// SDKHook(entity, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	SDKHook(entity, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	
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

/*
stock float GetPlayerSpeed(int client)
{
	if(!IsValidAliveClient(client))
		return 210.0;
	
	int flags = GetEntityFlags(client);
	int zombie = GetEntProp(client, Prop_Send, "m_zombieClass");
	int adrenaline = GetEntProp(client, Prop_Send, "m_bAdrenalineActive");
	float modifier = GetEntPropFloat(client, Prop_Send, "m_flVelocityModifier");
	
	if(flags & FL_DUCKING)
		return (g_fDefaultSpeed[Z_COMMON] * modifier);
	else if(flags & FL_INWATER)
		return (g_fDefaultSpeed[Z_SURVIVOR] * modifier);
	else if(zombie == Z_SURVIVOR && adrenaline != 0)
		return (g_fDefaultSpeed[Z_WITCH] * modifier);
	
	return (g_fDefaultSpeed[zombie] * modifier);
}
*/

// 去除多余的技能
stock void ClearFakeSkill(int client)
{
	if(g_hPlayerSkill[client] != null)
	{
		// 去除超过上限的技能
		if(g_hPlayerSkill[client].Length > g_iSkillSlot[client])
		{
			if(g_iSkillSlot[client] <= 0)
			{
				g_hPlayerSkill[client].Clear();
			}
			else
			{
				int length = 0;
				while((length = g_hPlayerSkill[client].Length) > g_iSkillSlot[client] && length > 0)
					g_hPlayerSkill[client].Erase(0);
			}
		}
		
		// 去除重复的技能
		if(g_hPlayerSkill[client].Length > 0)
		{
			SortADTArray(g_hPlayerSkill[client], Sort_Ascending, Sort_Integer);
			int length = g_hPlayerSkill[client].Length, i = 0, last = 0, current;
			for(; i < length; ++i)
			{
				current = g_hPlayerSkill[client].Get(i);
				if(current == last)
				{
					g_hPlayerSkill[client].Erase(i);
					length -= 1;
					i -= 1;
				}
				else
				{
					last = current;
				}
			}
		}
	}
}

public void SetupPlayerHook(any client)
{
	if(!IsValidClient(client))
		return;
	
	g_iDamageSpitTotal[client] = 0;
	g_iCommonKillTotal[client] = 0;
	g_iAttackTotal[client] = 0;
	g_fNextStandingTime[client] = GetGameTime();
	g_iVomitAttacker[client] = -1;
	g_fVomitEndTime[client] = 0.0;
	g_iDamageAssistTotal[client] = 0;
	g_fNextReviveTime[client] = GetGameTime();
	g_iTankPropTotal[client] = 0;
	
	if(g_iMaxHealth[client] < 0)
		g_iMaxHealth[client] = 0;
	if(g_iMaxMagic[client] < 0)
		g_iMaxMagic[client] = 0;
	if(g_iMaxStamina[client] < 0)
		g_iMaxStamina[client] = 0;
	if(g_iAccount[client] < 0)
		g_iAccount[client] = 0;
	if(g_iExperience[client] < 0)
		g_iExperience[client] = 0;
	if(g_iLevel[client] < 0)
		g_iLevel[client] = 0;
	
	// 防止意外
	int slot = g_iLevel[client] / g_iSlotLevel;
	if(slot > g_iSlotMax)
		slot = g_iSlotMax;
	
	if(g_iSkillSlot[client] != slot)
		g_iSkillSlot[client] = slot;
	else if(g_iSkillSlot[client] < 0)
		g_iSkillSlot[client] = 0;
	else if(g_iSkillSlot[client] > g_iSlotMax)
		g_iSkillSlot[client] = g_iSlotMax;
	
	// ClearFakeSkill(client);
	UninstallPlayerHook(client);
	UpdateDamageBonus(client);
	
	if(g_iMaxHealth[client] > 0)
		RequestFrame(UpdateMaxHealth, client);
	
	SDKHook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKHook(client, SDKHook_OnTakeDamagePost, PlayerHook_OnTankPropDamage);
	SDKHook(client, SDKHook_GetMaxHealth, PlayerHook_OnMaxHealth);
	if(g_pfnAllowTakeDamage == null)
	{
		// SDKHook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamageAlive, PlayerHook_OnTakeDamage);
		// SDKHook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	}
	
	// PrintToServer("player %N (%d) Hooked (%d).", client, client, g_iMaxHealth[client]);
}

void UninstallPlayerHook(int client)
{
	SDKUnhook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	SDKUnhook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, PlayerHook_OnTankPropDamage);
	SDKUnhook(client, SDKHook_GetMaxHealth, PlayerHook_OnMaxHealth);
	SDKUnhook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, PlayerHook_OnTakeDamage);
	
	// g_iDefaultHealth[client] = 0;
	// PrintToServer("player %d Unhooked.", client);
}

public void UpdateMaxHealth(any client)
{
	g_iDefaultHealth[client] = GetPlayerMaxHealth(client);
	if(IsPlayerIncapacitated(client) || IsPlayerHanging(client))
		return;
	
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	if(g_iDefaultHealth[client] == 0 || maxHealth == 0)
		return;
	
	int newMaxHealth = g_iDefaultHealth[client] + g_iMaxHealth[client];
	if(newMaxHealth == maxHealth)
		return;
	
	float healthPercentage = GetEntProp(client, Prop_Data, "m_iHealth") / float(maxHealth);
	float bufferPercentage = GetPlayerTempHealth(client) / float(maxHealth);
	if(healthPercentage < 0.0)
		healthPercentage = 0.0;
	if(bufferPercentage < 0.0)
		bufferPercentage = 0.0;
	
	SetEntProp(client, Prop_Data, "m_iMaxHealth", newMaxHealth);
	SetEntProp(client, Prop_Data, "m_iHealth", RoundToZero(healthPercentage * newMaxHealth));
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", bufferPercentage * newMaxHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	
	if(g_hCvarMaxHealth.IntValue < newMaxHealth)
	{
		g_hCvarMaxHealth.IntValue = (newMaxHealth > 1268 ? 1268 : newMaxHealth);
		g_hCvarMaxBufferHealth.IntValue = (newMaxHealth > 200 ? 200 : newMaxHealth);
	}
	
	/*
	PrintToServer("player %N got maxHealth %d, health %.2f%%, buffer %.2f%%, newMaxHealth %d, defMaxHealth %d",
		client, maxHealth, healthPercentage, bufferPercentage, newMaxHealth, g_iDefaultHealth[client]);
	*/
}

public void UpdateDamageBonus(any client)
{
	if(g_iMaxStamina[client] > 0)
	{
		g_fDefenseChance[client] = g_pCvarDefenseChance.FloatValue;
		g_fDefenseFactor[client] = g_pCvarDefenseFactor.FloatValue;
		
		if(g_fDefenseChance[client] < 1.0)
			g_fDefenseChance[client] += g_iMaxStamina[client] / 1000.0;
		if(g_fDefenseFactor[client] < 1.0)
			g_fDefenseFactor[client] += g_iMaxStamina[client] / 2500.0;
		
		if(g_fDefenseChance[client] > 1.0)
			g_fDefenseChance[client] = 1.0;
		if(g_fDefenseFactor[client] > 1.0)
			g_fDefenseFactor[client] = 1.0;
	}
	else
	{
		g_fDefenseChance[client] = 0.0;
		g_fDefenseFactor[client] = 0.0;
	}
	
	if(g_iMaxWillpower[client] > 0)
	{
		g_fDamageChance[client] = g_pCvarDamageChance.FloatValue;
		g_fDamageFactor[client] = g_pCvarDamageFactor.FloatValue;
		
		if(g_fDamageChance[client] < 1.0)
			g_fDamageChance[client] += g_iMaxWillpower[client] / 500.0;
		g_fDamageFactor[client] += g_iMaxWillpower[client] / 200.0;
		
		if(g_fDamageChance[client] > 1.0)
			g_fDamageChance[client] = 1.0;
	}
	else
	{
		g_fDamageChance[client] = 0.0;
		g_fDamageFactor[client] = 0.0;
	}
}

int GetPlayerMaxHealth(int client)
{
	static ConVar z_charger_health, z_exploding_health, z_gas_health, z_hunter_health,
		z_jockey_health, z_spitter_health/*, z_tank_health*/;
	
	if(z_charger_health == null)
	{
		z_charger_health = FindConVar("z_charger_health");
		z_exploding_health = FindConVar("z_exploding_health");
		z_gas_health = FindConVar("z_gas_health");
		z_hunter_health = FindConVar("z_hunter_health");
		z_jockey_health = FindConVar("z_jockey_health");
		z_spitter_health = FindConVar("z_spitter_health");
		// z_tank_health = FindConVar("z_tank_health");
	}
	
	switch(GetEntProp(client, Prop_Send, "m_zombieClass"))
	{
		case Z_SMOKER:
			return z_gas_health.IntValue;
		case Z_BOOMER:
			return z_exploding_health.IntValue;
		case Z_HUNTER:
			return z_hunter_health.IntValue;
		case Z_SPITTER:
			return z_spitter_health.IntValue;
		case Z_JOCKEY:
			return z_jockey_health.IntValue;
		case Z_CHARGER:
			return z_charger_health.IntValue;
		case Z_TANK:
			// return z_tank_health.IntValue;
			return 8000;
		case Z_SURVIVOR:
			return 100;
	}
	
	return 0;
}

public Action PlayerHook_OnMaxHealth(int client, int& amount)
{
	if(g_iDefaultHealth[client] == 0 && amount > 0)
		g_iDefaultHealth[client] = amount;
	
	if(g_iMaxHealth[client] <= 0 || g_iDefaultHealth[client] <= 0)
		return Plugin_Continue;
	
	// 修复 100 血不能打包的问题
	amount = g_iDefaultHealth[client] + g_iMaxHealth[client];
	return Plugin_Changed;
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
	
	if(result >= Plugin_Handled)
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
	
	if(result >= Plugin_Handled)
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
	
	if(result >= Plugin_Handled)
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
	
	if(result >= Plugin_Handled)
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
	
	if(result >= Plugin_Handled)
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
	
	if(result >= Plugin_Handled)
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

// 增加玩家的精力
float WillpowerIncrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fWillpower[client] + amount > g_iMaxWillpower[client])
		amount = g_iMaxWillpower[client] - g_fWillpower[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwWillpowerIncreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fWillpower[client] += amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwWillpowerIncreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

// 减少玩家的精力
float WillpowerDecrease(int client, float amount)
{
	if(!IsValidClient(client))
		return -1.0;
	
	if(g_fWillpower[client] - amount < 0)
		amount = g_fWillpower[client];
	
	if(amount < 0.0)
		amount = 0.0;
	
	// 调用 Pre 函数
	int refAmount = RoundToZero(amount);
	Action result = Plugin_Continue;
	Call_StartForward(g_fwWillpowerDecreasePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return 0.0;
	else if(result == Plugin_Changed)
		amount = float(refAmount);
	
	g_fWillpower[client] -= amount;
	
	// 调用 Post 函数
	Call_StartForward(g_fwWillpowerDecreasePost);
	Call_PushCell(client);
	Call_PushCell(RoundToZero(amount));
	Call_Finish();
	
	return amount;
}

bool GiveCash(int client, int& amount)
{
	if(!IsValidClient(client))
		return false;
	
	int refAmount = amount;
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnGainCashPre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return false;
	else if(result == Plugin_Changed)
		amount = refAmount;
	
	if(amount < 0)
		return false;
	
	g_iAccount[client] += RoundToZero(amount * g_fDifficultyFactor);
	
	Call_StartForward(g_fwOnGainCashPost);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
	
	return true;
}

bool GiveExperience(int client, int& amount)
{
	if(!IsValidClient(client))
		return false;
	
	int refAmount = amount;
	Action result = Plugin_Continue;
	
	Call_StartForward(g_fwOnGainExperiencePre);
	Call_PushCell(client);
	Call_PushCellRef(refAmount);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return false;
	else if(result == Plugin_Changed)
		amount = refAmount;
	
	if(amount < 0)
		return false;
	
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
	
	if(result >= Plugin_Handled)
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
	
	SaveToFile(client);
	return true;
}

void GiveBonus(int client, int experience, int cash, const char[] reason = "", any ...)
{
	GiveExperience(client, experience);
	GiveCash(client, cash);
	
	if(reason[0] == EOS || g_iShowBonus == 0)
		return;
	
	char buffer[255];
	VFormat(buffer, 255, reason, 5);
	
	if(g_iShowBonus & 1)
		StrCat(buffer, 255, tr((g_iShowBonus & 4 ? ", ＋%de (%d/%d)" : ", ＋%de"), experience, g_iExperience[client], g_iNextLevel[client]));
	if(g_iShowBonus & 2)
		StrCat(buffer, 255, tr((g_iShowBonus & 4 ? ", ＋%dc (%d)" : ", ＋%dc"), cash, g_iAccount[client]));
	
	CPrintToChat(client, "\x03[SC]\x01 %s", buffer);
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
	g_bInBattle[client] = false;
	g_fSprintSpeed[client] = 0.0;
	g_fNextReviveTime[client] = 0.0;
	g_fNextStandingTime[client] = 0.0;
	g_iDefaultHealth[client] = 0;
	g_iPlayerMenu[client] = 0;
	g_iSkillSlot[client] = 0;
	g_hMenuSlot[client] = null;
	g_iMenuPage[client] = 0;
	g_iMenuData[client] = 0;
	g_fNextSkillChoose[client] = 0.0;
	
	if(g_hPlayerSpell[client] != null)
	{
		delete g_hPlayerSpell[client];
		g_hPlayerSpell[client] = null;
	}
	
	if(g_hPlayerSkill[client] != null)
	{
		delete g_hPlayerSkill[client];
		g_hPlayerSkill[client] = null;
	}
	
	if(g_kvSaveData[client] != null)
	{
		delete g_kvSaveData[client];
		g_kvSaveData[client] = null;
	}
	
	UninstallPlayerHook(client);
}

stock bool IsFriendly(int client, int other)
{
	if(!IsValidClient(client) || !IsValidEdict(other))
		return false;
	
	int team = GetClientTeam(client);
	if(IsValidClient(other))
		return (GetClientTeam(other) == team);
	
	if(team == 2 || team == 4)
	{
		char classname[64];
		GetEntityClassname(other, classname, 64);
		if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false))
			return false;
	}
	
	return true;
}

// 返回 display
stock char[] GetSpellShowInfo(StringMap spl, int client, char[] bufDsp = "", int bufDspLen = 0, char[] bufDsc = "", int bufDscLen = 0)
{
	char classname[64], display[128], dspBuf[128], description[255], dscBuf[255];
	spl.GetString("classname", classname, 64);
	spl.GetString("display", display, 128);
	spl.GetString("description", description, 255);
	
	Action result = Plugin_Continue;
	strcopy(dspBuf, 128, display);
	strcopy(dscBuf, 255, description);
	
	Call_StartForward(g_fwOnSpellGetInfo);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(dspBuf, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(128);
	Call_PushStringEx(dscBuf, 255, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(255);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		display[0] = EOS;
		return display;
	}
	
	if(result == Plugin_Changed)
	{
		strcopy(display, 128, dspBuf);
		strcopy(description, 255, dscBuf);
	}
	
	if(bufDspLen > 0)
		strcopy(bufDsp, bufDspLen, display);
	if(bufDscLen > 0)
		strcopy(bufDsc, bufDscLen, description);
	
	return display;
}

// 返回 display
stock char[] GetSkillShowInfo(StringMap skl, int client, char[] bufDsp = "", int bufDspLen = 0, char[] bufDsc = "", int bufDscLen = 0)
{
	char classname[64], display[128], dspBuf[128], description[255], dscBuf[255];
	skl.GetString("classname", classname, 64);
	skl.GetString("display", display, 128);
	skl.GetString("description", description, 255);
	
	Action result = Plugin_Continue;
	strcopy(dspBuf, 128, display);
	strcopy(dscBuf, 255, description);
	
	Call_StartForward(g_fwOnSkillGetInfo);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(dspBuf, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(128);
	Call_PushStringEx(dscBuf, 255, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(255);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		display[0] = EOS;
		return display;
	}
	
	if(result == Plugin_Changed)
	{
		strcopy(display, 128, dspBuf);
		strcopy(description, 255, dscBuf);
	}
	
	if(bufDspLen > 0)
		strcopy(bufDsp, bufDspLen, display);
	if(bufDscLen > 0)
		strcopy(bufDsc, bufDscLen, description);
	
	return display;
}

#pragma deprecated 使用 GetSpellShowInfo 代替
stock char[] GetSpellName(StringMap spl, int client, char[] outBuffer = "", int outMaxLength = 0)
{
	char display[128], classname[64], buffer[128];
	spl.GetString("display", display, 128);
	spl.GetString("classname", classname, 64);
	strcopy(buffer, 128, display);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnSpellDisplayPre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(buffer, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(128);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		display[0] = EOS;
		return display;
	}
	
	if(result == Plugin_Changed)
		strcopy(display, 128, buffer);
	
	if(outMaxLength > 0)
		strcopy(outBuffer, outMaxLength, display);
	
	/*
	Call_StartForward(g_fwOnSpellDisplayPost);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushString(buffer);
	Call_Finish();
	*/
	
	return display;
}

#pragma deprecated 使用 GetSkillShowInfo 代替
stock char GetSkillName(StringMap skill, int client, char[] outBuffer = "", int outMaxLength = 0)
{
	char display[128], classname[64], buffer[128];
	skill.GetString("display", display, 128);
	skill.GetString("classname", classname, 64);
	strcopy(buffer, 128, display);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnSkillDisplayPre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(buffer, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(128);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		display[0] = EOS;
		return display;
	}
	
	if(result == Plugin_Changed)
		strcopy(display, 128, buffer);
	
	if(outMaxLength > 0)
		strcopy(outBuffer, outMaxLength, buffer);
	
	/*
	Call_StartForward(g_fwOnSkillDisplayPost);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushString(buffer);
	Call_Finish();
	*/
	
	return display;
}

#pragma deprecated 使用 GetSpellShowInfo 代替
stock char GetSpellDescription(StringMap spl, int client, char[] outBuffer = "", int outMaxLength = 0)
{
	char classname[64], description[255], buffer[255];
	spl.GetString("classname", classname, 64);
	spl.GetString("description", description, 64);
	strcopy(buffer, 255, description);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnSpellDescriptionPre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(buffer, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(255);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		description[0] = EOS;
		return description;
	}
	
	if(result == Plugin_Changed)
		strcopy(description, 128, buffer);
	
	if(outMaxLength > 0)
		strcopy(outBuffer, outMaxLength, description);
	
	return description;
}

#pragma deprecated 使用 GetSkillShowInfo 代替
stock char GetSkillDescription(StringMap skl, int client, char[] outBuffer = "", int outMaxLength = 0)
{
	char classname[64], description[255], buffer[255];
	skl.GetString("classname", classname, 64);
	skl.GetString("description", description, 64);
	strcopy(buffer, 255, description);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnSkillDescriptionPre);
	Call_PushCell(client);
	Call_PushString(classname);
	Call_PushStringEx(buffer, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(255);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
	{
		description[0] = EOS;
		return description;
	}
	
	if(result == Plugin_Changed)
		strcopy(description, 128, buffer);
	
	if(outMaxLength > 0)
		strcopy(outBuffer, outMaxLength, description);
	
	return description;
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

#define ABS_ADD(%1,%2)		(%1 >= 0 ? (%1 += %2) : (%1 -= %2))

stock bool IsVisibleThreats(int client)
{
	if(!IsValidAliveClient(client))
		return false;
	
	return (GetEntProp(client, Prop_Send, "m_hasVisibleThreats", 1) != 0 ||
		GetEntProp(client, Prop_Send, "m_clientIntensity") > 0);
	
	/*
	return (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") > 0 ||
		GetEntProp(client, Prop_Send, "m_clientIntensity") >= 10 ||
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") ||
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0);
	*/
}

stock int GetCurrentAttacker(int client)
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

stock int GetCurrentVictim(int client)
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

stock int GetPlayerTempHealth(int client)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	static ConVar pain_pills_decay_rate;
	if(pain_pills_decay_rate == null)
		pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	
	int amount = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") -
		((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) *
		pain_pills_decay_rate.FloatValue) - 1);
	
	return (amount > 0 ? amount : 0);
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
	char buffer[1024];
	VFormat(buffer, 1024, text, 2);
	return buffer;
}

#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
public Action Timer_ConnectDatabase(Handle timer, any unused)
{
	if(g_hDatabase != null)
		return Plugin_Stop;
	
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
	
	char error[255], config[64];
	g_pCvarSqlConfig.GetString(config, 64);
	if(config[0] != EOS && SQL_CheckConfig(config))
		g_hDatabase = SQL_Connect(config, true, error, 255);
	
	if(g_hDatabase == null)
		g_hDatabase = SQL_ConnectCustom(kv, error, 255, true);
	
	if(g_hDatabase == null)
	{
		LogError("数据库连接失败：%s", error);
		CreateTimer(3.0, Timer_ConnectDatabase);
		return Plugin_Continue;
	}
	
#if defined _USE_DATABASE_MYSQL_
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `user_info` (`uid` int(10) unsigned NOT NULL AUTO_INCREMENT, `sid` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID64', `sid2` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID2', `sid3` char(20) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'SteamID3', `name` text COLLATE utf8_bin COMMENT '???', `ip` char(16) COLLATE utf8_bin DEFAULT NULL COMMENT '???????IP', `country` char(64) COLLATE utf8_bin DEFAULT NULL COMMENT 'IP???', `joindate` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '????????', PRIMARY KEY (`uid`), UNIQUE KEY `sid` (`sid`), UNIQUE KEY `sid2` (`sid2`), UNIQUE KEY `sid3` (`sid3`), `legit` int(10) unsigned NOT NULL DEFAULT '0') ENGINE=MyISAM AUTO_INCREMENT=20 DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='????';");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `user_online` (`uid` int(11) NOT NULL AUTO_INCREMENT, `coin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '???????????', `country_name` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `region` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `city` varchar(64) NOT NULL DEFAULT '' COMMENT 'ip????', `code` char(3) NOT NULL DEFAULT '' COMMENT '?????????? CN', `code3` char(4) NOT NULL DEFAULT '' COMMENT '?????????? CHN', `online` time NOT NULL DEFAULT '00:00:00' COMMENT '??????', `last` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '????????', PRIMARY KEY (`uid`)) ENGINE=MyISAM AUTO_INCREMENT=20 DEFAULT CHARSET=utf8;");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `l4d2_simple_combat2` (`uid` int(10) unsigned NOT NULL, `max_health` int(10) unsigned NOT NULL DEFAULT '0', `max_stamina` int(10) unsigned NOT NULL DEFAULT '0', `max_magic` int(10) unsigned NOT NULL DEFAULT '0', `max_willpower` int(10) unsigned NOT NULL DEFAULT '0', `accounts` int(11) NOT NULL DEFAULT '0', `points` int(11) NOT NULL DEFAULT '0', `level` smallint(5) unsigned NOT NULL DEFAULT '0', `experience` int(10) unsigned NOT NULL DEFAULT '0', `level_experience` int(10) unsigned NOT NULL DEFAULT '0', `skill_slot` int(10) unsigned NOT NULL DEFAULT '0', PRIMARY KEY (`uid`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `l4d2_simple_combat_spell` (`uid` int(10) unsigned NOT NULL, `spell` text NOT NULL, `skill` text NOT NULL, PRIMARY KEY (`uid`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;");
#elseif defined _USE_DATABASE_SQLITE_
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS user_info (uid INTEGER PRIMARY KEY AUTOINCREMENT, sid CHAR(20) UNIQUE NOT NULL, sid2 CHAR(20) UNIQUE NOT NULL, sid3 CHAR(20) UNIQUE NOT NULL, name TEXT NOT NULL, ip CHAR(16) DEFAULT(''), country VARCHAR(32) DEFAULT(''), joindate DATETIME DEFAULT(datetime('now')), legit INT(10) DEFAULT(0));");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS user_online (uid INTEGER PRIMARY KEY AUTOINCREMENT, coin INT(10) DEFAULT(0), country_name VARCHAR(64) DEFAULT(''), region VARCHAR(64) DEFAULT(''), city VARCHAR(64) DEFAULT(''), code CHAR(3) DEFAULT(''), code3 CHAR(4) DEFAULT(''), online TIME DEFAULT(time('0', '-12 hour')), last DATETIME DEFAULT(datetime('now')));");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS l4d2_simple_combat2 (uid INTEGER PRIMARY KEY AUTOINCREMENT, max_health INT(10) DEFAULT(0), max_stamina INT(10) DEFAULT(0), max_magic INT(10) DEFAULT(0), max_willpower INT(10) DEFAULT(0), accounts INT(10) DEFAULT(0), points INT(10) DEFAULT(0), level INT(10) DEFAULT(0), experience INT(10) DEFAULT(0), level_experience INT(10) DEFAULT(0), skill_slot INT(10) DEFAULT(0));");
	SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS l4d2_simple_combat_spell (uid INTEGER PRIMARY KEY AUTOINCREMENT, spell TEXT DEFAULT(''), skill TEXT DEFAULT(''));");
	
	// 创建触发器必须先开启事务
	// SQL_FastQuery("CREATE TRIGGER update_last_online AFTER UPDATE ON user_online FOR EACH ROW WHEN new.last <= old.last BEGIN UPDATE user_online SET last = datetime('now') WHERE uid = new.uid; END;");
#endif
	
	Handle db = CloneHandle(g_hDatabase);
	Call_StartForward(g_fwOnDataBaseConnected);
	Call_PushCell(db);
#if defined _USE_DATABASE_MYSQL_
	Call_PushCell(true);
#else
	Call_PushCell(false);
#endif
	Call_Finish();
	delete db;
	
	return Plugin_Continue;
}
#endif

stock StringMap FindValueByClassName(const char[] classname, ArrayList array)
{
	int index = FindValueIndexByClassName(classname, array);
	if(index == -1)
		return null;
	
	return array.Get(index);
}

stock int FindValueIndexByClassName(const char[] classname, ArrayList array)
{
	char temp[64];
	int length = array.Length;
	int hash = GetStringHash(classname), cmp = 0;
	
	for(int i = 0; i < length; ++i)
	{
		StringMap spl = array.Get(i);
		if(spl == null)
			continue;
		
		if(spl.GetValue("hash", cmp) && cmp == hash)
			return i;
		
		if(spl.GetString("classname", temp, 64) && StrEqual(classname, temp, false))
			return i;
	}
	
	return -1;
}

char Serialization(ArrayList array, char[] output = "", int outMaxLength = 0)
{
	StringMap spl = null;
	int length = array.Length;
	char buffer[1024], classname[64];
	for(int i = 0; i < length; ++i)
	{
		spl = array.Get(i);
		if(spl == null || !spl.GetString("classname", classname, 64))
			continue;
		
		if(i == 0)
			strcopy(buffer, 1024, classname);
		else
			StrCat(buffer, 1024, tr("|%s", classname));
	}
	
	if(outMaxLength > 0)
		strcopy(output, outMaxLength, buffer);
	
	// LogMessage("保存");
	// LogMessage("%s", buffer);
	// LogMessage("%d", length);
	// LogMessage("保存结束");
	return buffer;
}

ArrayList Unserialization(const char[] input, ArrayList dataSrc)
{
	char dataTuple[32][64];
	ArrayList array = CreateArray();
	int count = ExplodeString(input, "|", dataTuple, 64, 64);
	for(int i = 0; i < count; ++i)
	{
		StringMap data = FindValueByClassName(dataTuple[i], dataSrc);
		if(data != null)
			array.Push(data);
	}
	
	// LogMessage("读取");
	// LogMessage("%s", input);
	// LogMessage("%d", array.Length);
	// LogMessage("读取结束");
	return array;
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
	SQL_FastQuery(g_hDatabase, tr("INSERT IGNORE INTO user_info (name, sid, ip, sid2, sid3, country, legit) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%d');",
		name, auth, ip, auth2, auth3, country, GetSteamAccountID(client, true)));
#else
	SQL_FastQuery(g_hDatabase, tr("INSERT OR IGNORE INTO user_info (name, sid, ip, sid2, sid3, country, legit) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%d');",
		name, auth, ip, auth2, auth3, country, GetSteamAccountID(client, true)));
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
	
	if(g_hPlayerSkill[client] == null)
		g_hPlayerSkill[client] = CreateArray();
	else
		g_hPlayerSkill[client].Clear();
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	int userId = GetPlayerUserId(client);
	Transaction tran = SQL_CreateTransaction();
	
	// 更新数据
#if defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("INSERT IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO l4d2_simple_combat2 (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO l4d2_simple_combat_spell (uid) VALUES ('%d');", userId));
#else
	tran.AddQuery(tr("INSERT OR IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO l4d2_simple_combat2 (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO l4d2_simple_combat_spell (uid) VALUES ('%d');", userId));
#endif
	
	SQL_ExecuteTransaction(g_hDatabase, tran);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnLoadPre);
	Call_PushCell(client);
	Call_PushCell(userId);
#if defined _USE_DATABASE_MYSQL_
	Call_PushCell(true);
#else
	Call_PushCell(false);
#endif
	Call_Finish(result);
	if(result >= Plugin_Handled)
		return false;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	g_hDatabase.Escape(name, name, MAX_NAME_LENGTH);
	
	char ip[64], country[64];
	GetClientIP(client, ip, 64);
	GeoipCountry(ip, country, 64);
	
	tran = SQL_CreateTransaction();
	g_iClientUserId[client] = userId;
	
	// 读取存档
	tran.AddQuery(tr("SELECT max_health, max_stamina, max_magic, max_willpower, accounts, points, level, experience, level_experience, skill_slot FROM l4d2_simple_combat2 WHERE uid = '%d';", userId));
	tran.AddQuery(tr("SELECT spell, skill FROM l4d2_simple_combat_spell WHERE uid = '%d';", userId));
	
#if !defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("UPDATE user_online SET last = datetime('now') WHERE uid = '%d';", userId));
#endif	// !defined _USE_DATABASE_MYSQL_
	
	tran.AddQuery(tr("UPDATE user_info SET name = '%s', ip = '%s', country = '%s', legit = '%d' WHERE uid = %d;",
		name, ip, country, GetSteamAccountID(client, true), userId));
	
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
	GetClientAuthId(client, AuthId_Steam2, steamId2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, steamId3, 64, false);
	GetClientAuthId(client, AuthId_SteamID64, steamId64, 64, false);
	GetClientName(client, name, 128);
	GetClientIP(client, ip, 32);
	
	g_kvSaveData[client] = CreateKeyValues("PlayerData");
	g_kvSaveData[client].ImportFromFile(tr("%s/%s.txt", g_szSaveDataPath, steamId64));
	
	g_kvSaveData[client].SetString("steamId_2", steamId2);
	g_kvSaveData[client].SetString("steamId_3", steamId3);
	g_kvSaveData[client].SetString("steamId_64", steamId64);
	g_kvSaveData[client].SetString("name", name);
	g_kvSaveData[client].SetString("ip", ip);
	
	g_iMaxHealth[client] = g_kvSaveData[client].GetNum("max_health", 0);
	g_iMaxStamina[client] = g_kvSaveData[client].GetNum("max_stamina", 0);
	g_iMaxMagic[client] = g_kvSaveData[client].GetNum("max_magic", 0);
	g_iMaxWillpower[client] = g_kvSaveData[client].GetNum("max_willpower", 0);
	g_iAccount[client] = g_kvSaveData[client].GetNum("accounts", 0);
	g_iSkillPoint[client] = g_kvSaveData[client].GetNum("points", 0);
	g_iLevel[client] = g_kvSaveData[client].GetNum("level", 0);
	g_iExperience[client] = g_kvSaveData[client].GetNum("experience", 0);
	g_iNextLevel[client] = g_kvSaveData[client].GetNum("level_experience", g_pCvarLevelExperience.IntValue);
	g_iSkillSlot[client] = g_kvSaveData[client].GetNum("skill_slot", 0);
	
	if(g_kvSaveData[client].JumpToKey("spell_list", false))
	{
		char classname[64];
		int length = g_kvSaveData[client].GetNum("count", 0);
		
		for(int i = 0; i < length; ++i)
		{
			g_kvSaveData[client].GetString(tr("spell_%d", i), classname, 64, "");
			if(classname[0] == EOS)
				break;
			
			StringMap spell = FindValueByClassName(classname, g_hAllSpellList);
			if(spell != null)
				g_hPlayerSpell[client].Push(spell);
		}
	}
	
	if(g_kvSaveData[client].JumpToKey("skill_list", false))
	{
		char classname[64];
		int length = g_kvSaveData[client].GetNum("count", 0);
		
		for(int i = 0; i < length; ++i)
		{
			g_kvSaveData[client].GetString(tr("skill_%d", i), classname, 64, "");
			if(classname[0] == EOS)
				break;
			
			StringMap skill = FindValueByClassName(classname, g_hAllSkillList);
			if(skill != null)
				g_hPlayerSkill[client].Push(skill);
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
		g_iMaxWillpower[client] = res[0].FetchInt(3);
		g_iAccount[client] = res[0].FetchInt(4);
		g_iSkillPoint[client] = res[0].FetchInt(5);
		g_iLevel[client] = res[0].FetchInt(6);
		g_iExperience[client] = res[0].FetchInt(7);
		g_iNextLevel[client] = res[0].FetchInt(8);
		g_iSkillSlot[client] = res[0].FetchInt(9);
	}
	else
	{
		// 这种情况一般不会出现的
		LogError("错误：玩家 %N 查询信息失败。", client);
	}
	
	if(res[1] != null && res[1].RowCount > 0 && res[1].FetchRow())
	{
		char spellSeries[1024], skillSeries[1024];
		res[1].FetchString(0, spellSeries, 1024);
		res[1].FetchString(1, skillSeries, 1024);
		
		if(g_hPlayerSpell[client] != null)
			delete g_hPlayerSpell[client];
		if(g_hPlayerSkill[client] != null)
			delete g_hPlayerSkill[client];
		
		g_hPlayerSpell[client] = Unserialization(spellSeries, g_hAllSpellList);
		g_hPlayerSkill[client] = Unserialization(skillSeries, g_hAllSkillList);
	}
	else
	{
		// 这种情况一般不会出现的
		LogError("错误：玩家 %N 查询法术失败。", client);
	}
	
	Call_StartForward(g_fwOnLoadPost);
	Call_PushCell(client);
	Call_PushCell(g_iClientUserId[client]);
#if defined _USE_DATABASE_MYSQL_
	Call_PushCell(true);
#else
	Call_PushCell(false);
#endif
	Call_Finish();
	
	LogMessage("读取玩家 %N 成功，共有 %d 个法术和 %d 个技能。", client, g_hPlayerSpell[client].Length, g_hPlayerSkill[client].Length);
	// SetupPlayerHook(client);
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
	
	if(g_hPlayerSkill[client] == null)
		g_hPlayerSkill[client] = CreateArray();
	
#if defined _USE_DATABASE_MYSQL_ || defined _USE_DATABASE_SQLITE_
	int userId = g_iClientUserId[client];
	if(userId <= 0)
		userId = GetPlayerUserId(client);
	
	Transaction tran = SQL_CreateTransaction();
	
	// 更新数据
#if defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("INSERT IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO l4d2_simple_combat2 (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT IGNORE INTO l4d2_simple_combat_spell (uid) VALUES ('%d');", userId));
#else
	tran.AddQuery(tr("INSERT OR IGNORE INTO user_online (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO l4d2_simple_combat2 (uid) VALUES ('%d');", userId));
	tran.AddQuery(tr("INSERT OR IGNORE INTO l4d2_simple_combat_spell (uid) VALUES ('%d');", userId));
#endif
	
	SQL_ExecuteTransaction(g_hDatabase, tran);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_fwOnSavePre);
	Call_PushCell(client);
	Call_PushCell(userId);
#if defined _USE_DATABASE_MYSQL_
	Call_PushCell(true);
#else
	Call_PushCell(false);
#endif
	Call_Finish(result);
	if(result >= Plugin_Handled)
		return false;
	
	char spellData[512] = "", skillData[512] = "";
	tran = SQL_CreateTransaction();
	
	tran.AddQuery(tr("UPDATE l4d2_simple_combat2 SET max_health = '%d', max_stamina = '%d', max_magic = '%d', max_willpower = '%d', accounts = '%d', points = '%d', level = '%d', experience = '%d', level_experience = '%d', skill_slot = '%d' WHERE uid = '%d';",
		g_iMaxHealth[client], g_iMaxStamina[client], g_iMaxMagic[client], g_iMaxWillpower[client],
		g_iAccount[client], g_iSkillPoint[client],
		g_iLevel[client], g_iExperience[client], g_iNextLevel[client],
		g_iSkillSlot[client],
		userId));
	
	Serialization(g_hPlayerSpell[client], spellData, 512);
	Serialization(g_hPlayerSkill[client], skillData, 512);
	
	// g_hDatabase.Escape(spellData, spellData, 512);
	tran.AddQuery(tr("UPDATE l4d2_simple_combat_spell SET spell = '%s', skill = '%s' WHERE uid = '%d';",
		spellData, skillData, userId));
	
	// PrintToChat(client, spellData);
	
#if !defined _USE_DATABASE_MYSQL_
	tran.AddQuery(tr("UPDATE user_online SET last = datetime('now') WHERE uid = '%d';", userId));
#endif	// !defined _USE_DATABASE_MYSQL_
	
	SQL_ExecuteTransaction(g_hDatabase, tran, SQLTran_SavePlayerComplete, SQLTran_SavePlayerFailure, client);
#else
	if(g_kvSaveData[client] == null)
		g_kvSaveData[client] = CreateKeyValues("PlayerData");
	
	char steamId2[64], steamId3[64], steamId64[64], name[128], ip[32];
	GetClientAuthId(client, AuthId_Steam2, steamId2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, steamId3, 64, false);
	GetClientAuthId(client, AuthId_SteamID64, steamId64, 64, false);
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
	g_kvSaveData[client].SetNum("max_willpower", g_iMaxWillpower[client]);
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
		
		g_kvSaveData[client].GoBack();
	}
	
	if(g_kvSaveData[client].JumpToKey("skill_list", true))
	{
		char classname[64];
		int length = g_hPlayerSkill[client].Length;
		g_kvSaveData[client].SetNum("count", length);
		
		for(int i = 0; i < length; ++i)
		{
			StringMap spell = g_hPlayerSkill[client].Get(i);
			if(spell == null || !spell.GetString("classname", classname, 64))
				continue;
			
			g_kvSaveData[client].SetString(tr("skill_%d", i), classname);
		}
		
		g_kvSaveData[client].GoBack();
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
		LogMessage("保存玩家 %N 成功，共有 %d 个法术和 %d 个技能。", client, g_hPlayerSpell[client].Length, g_hPlayerSkill[client].Length);
	else
		LogMessage("保存玩家 %d 成功。", client);
	
	Call_StartForward(g_fwOnSavePost);
	Call_PushCell(client);
	Call_PushCell(g_iClientUserId[client]);
#if defined _USE_DATABASE_MYSQL_
	Call_PushCell(true);
#else
	Call_PushCell(false);
#endif
	Call_Finish();
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

stock int GetStringHash(const char[] text)
{
	const int seed = 131;
	
	int hash = 0;
	// int length = strlen(text);
	for(int i = 0; text[i] != EOS; ++i)
		hash = hash * seed + text[i];
	
	return (hash & 0x7FFFFFFF);
}

#define DECL_MENU_PRE(%1)			CreateGlobalForward(%1, ET_Event, Param_Cell, Param_CellByRef)
#define DECL_MENU_POST(%1)			CreateGlobalForward(%1, ET_Ignore, Param_Cell, Param_Cell)
#define DECL_MENU_SELECT_PRE(%1)	CreateGlobalForward(%1, ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef)
#define DECL_MENU_SELECT_POST(%1)	CreateGlobalForward(%1, ET_Ignore, Param_Cell, Param_Cell, Param_Cell)

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_simple_combat");
	g_hAllSpellList = CreateArray();
	g_hAllSkillList = CreateArray();
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
	g_fwWillpowerIncreasePre = CreateGlobalForward("SC_OnWillpowerIncreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwWillpowerIncreasePost = CreateGlobalForward("SC_OnWillpowerIncreasePost", ET_Ignore, Param_Cell, Param_Cell);
	g_fwWillpowerDecreasePre = CreateGlobalForward("SC_OnWillpowerDecreasePre", ET_Hook, Param_Cell, Param_CellByRef);
	g_fwWillpowerDecreasePost = CreateGlobalForward("SC_OnWillpowerDecreasePost", ET_Ignore, Param_Cell, Param_Cell);
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
	g_fwOnDamagePre = CreateGlobalForward("SC_OnDamagePre", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef, Param_CellByRef, Param_FloatByRef, Param_FloatByRef);
	g_fwOnDamagePost = CreateGlobalForward("SC_OnDamagePost", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Float, Param_Float);
	
	// 菜单
	g_fwOnMenuItemClickPre = CreateGlobalForward("SC_OnMenuItemClickPre", ET_Hook, Param_Cell, Param_String, Param_String);
	g_fwOnMenuItemClickPost = CreateGlobalForward("SC_OnMenuItemClickPost", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_fwOnSpellDisplayPre = CreateGlobalForward("SC_OnSpellDisplay", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell);
	// g_fwOnSpellDisplayPost = CreateGlobalForward("SC_OnSpellDisplayPost", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_fwOnSkillDisplayPre = CreateGlobalForward("SC_OnSkillDisplay", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell);
	// g_fwOnSkillDisplayPost = CreateGlobalForward("SC_OnSkillDisplayPost", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_fwOnSpellDescriptionPre = CreateGlobalForward("SC_OnSpellDescription", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell);
	g_fwOnSkillDescriptionPre = CreateGlobalForward("SC_OnSkillDescription", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell);
	g_fwOnSpellGetInfo = CreateGlobalForward("SC_OnSpellGetInfo", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_String, Param_Cell);
	g_fwOnSkillGetInfo = CreateGlobalForward("SC_OnSkillGetInfo", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_String, Param_Cell);
	
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
	CreateNative("SC_GetClientWillpower", Native_GetClientWillpower);
	CreateNative("SC_SetClientWillpower", Native_SetClientWillpower);
	CreateNative("SC_GetClientMaxStamina", Native_GetClientMaxStamina);
	CreateNative("SC_SetClientMaxStamina", Native_SetClientMaxStamina);
	CreateNative("SC_GetClientMaxHealth", Native_GetClientMaxHealth);
	CreateNative("SC_SetClientMaxHealth", Native_SetClientMaxHealth);
	CreateNative("SC_GetClientMaxWillpower", Native_GetClientMaxWillpower);
	CreateNative("SC_SetClientMaxWillpower", Native_SetClientMaxWillpower);
	CreateNative("SC_IsClientSprint", Native_GetClientSprint);
	CreateNative("SC_IsClientCombat", Native_GetClientCombat);
	
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
	
	// 保存读取
	g_fwOnSavePre = CreateGlobalForward("SC_OnSavePre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnSavePost = CreateGlobalForward("SC_OnSavePost", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnLoadPre = CreateGlobalForward("SC_OnLoadPre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnLoadPost = CreateGlobalForward("SC_OnLoadPost", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnDataBaseConnected = CreateGlobalForward("SC_OnDataBaseReady", ET_Ignore, Param_Cell, Param_Cell);
	CreateNative("SC_GetClientUserID", Native_GetUserId);
	CreateNative("SC_GetDataBase", Native_GetDataBase);
	
	// 法术
	g_fwOnSpellUsePre = CreateGlobalForward("SC_OnUseSpellPre", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_fwOnSpellUsePost = CreateGlobalForward("SC_OnUseSpellPost", ET_Ignore, Param_Cell, Param_String);
	g_fwOnSpellGainPre = CreateGlobalForward("SC_OnGainSpellPre", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_fwOnSpellGainPost = CreateGlobalForward("SC_OnGainSpellPost", ET_Ignore, Param_Cell, Param_String);
	
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
	CreateNative("SC_IsClientHaveSpell", Native_IsClientHaveSpell);
	
	CreateNative("SC_GetSpellClass", Native_GetSpellClassName);
	CreateNative("SC_SetSpellClass", Native_SetSpellClassName);
	CreateNative("SC_GetSpellName", Native_GetSpellDisplayName);
	CreateNative("SC_SetSpellName", Native_SetSpellDisplayName);
	CreateNative("SC_GetSpellCost", Native_GetSpellCost);
	CreateNative("SC_SetSpellCost", Native_SetSpellCost);
	CreateNative("SC_GetSpellConsume", Native_GetSpellConsume);
	CreateNative("SC_SetSpellConsume", Native_SetSpellConsume);
	CreateNative("SC_GetSpellDescription", Native_GetSpellDescription);
	CreateNative("SC_SetSpellDescription", Native_SetSpellDescription);
	
	// 技能
	g_fwOnSkillGainPre = CreateGlobalForward("SC_OnGainSkillPre", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_fwOnSkillGainPost = CreateGlobalForward("SC_OnGainSkillPost", ET_Ignore, Param_Cell, Param_String);
	g_fwOnSkillLostPre = CreateGlobalForward("SC_OnLostSkillPre", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_String);
	g_fwOnSkillLostPost = CreateGlobalForward("SC_OnLostSkillPost", ET_Ignore, Param_Cell, Param_String, Param_String);
	
	CreateNative("SC_CreateSkill", Native_CreateSkill);
	CreateNative("SC_FindSkill", Native_FindSkill);
	CreateNative("SC_RemoveSkill", Native_FreeSkill);
	CreateNative("SC_GetSkillCount", Native_GetSkillCount);
	CreateNative("SC_GetSkill", Native_GetSkill);
	
	CreateNative("SC_GetClientSkillCount", Native_GetClientSkillCount);
	CreateNative("SC_GetClientSkill", Native_GetClientSkill);
	CreateNative("SC_GiveClientSkill", Native_GiveClientSkill);
	CreateNative("SC_RemoveClientSkill", Native_RemoveClientSkill);
	CreateNative("SC_FindClientSkill", Native_FindClientSkill);
	CreateNative("SC_GetClientSkillSlot", Native_GetClientSkillSlot);
	CreateNative("SC_SetClientSkillSlot", Native_SetClientSkillSlot);
	CreateNative("SC_IsClientHaveSkill", Native_IsClientHaveSkill);
	
	CreateNative("SC_GetSkillName", Native_GetSkillDisplayName);
	CreateNative("SC_SetSkillName", Native_SetSkillDisplayName);
	CreateNative("SC_GetSkillClass", Native_GetSkillClassName);
	CreateNative("SC_SetSkillClass", Native_SetSkillClassName);
	CreateNative("SC_GetSkillDescription", Native_GetSkillDescription);
	CreateNative("SC_SetSkillDescription", Native_SetSkillDescription);
	CreateNative("SC_GetSkillZombieType", Native_GetSkillZombieType);
	CreateNative("SC_SetSkillZombieType", Native_SetSkillZombieType);
	
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

public int Native_GetClientWillpower(Handle plugin, int argc)
{
	DECL_NATIVE_GET_F(g_fWillpower);
}

public int Native_SetClientWillpower(Handle plugin, int argc)
{
	DECL_NATIVE_SET_F(g_fWillpower);
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

public int Native_GetClientMaxWillpower(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iMaxWillpower);
}

public int Native_SetClientMaxWillpower(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iMaxWillpower);
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

public int Native_GetClientSkillSlot(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_iSkillSlot);
}

public int Native_SetClientSkillSlot(Handle plugin, int argc)
{
	DECL_NATIVE_SET(g_iSkillSlot);
}

public int Native_GetClientSprint(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_bInSprint);
}

public int Native_GetClientCombat(Handle plugin, int argc)
{
	DECL_NATIVE_GET(g_bInBattle);
}

public int Native_GiveClientExperience(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	int amount = GetNativeCell(2);
	GiveExperience(client, amount);
	return amount;
}

public int Native_GiveClientCash(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	int amount = GetNativeCell(2);
	GiveCash(client, amount);
	return amount;
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

public int Native_CreateSpell(Handle plugin, int argc)
{
	if(argc < 4)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	int index = FindValueIndexByClassName(classname, g_hAllSpellList);
	if(index > -1)
		return index;
	
	char display[128];
	StringMap spl = CreateTrie();
	GetNativeString(2, display, 128);
	
	spl.SetString("classname", classname, true);
	spl.SetString("display", display, true);
	spl.SetValue("consume", GetNativeCell(3), true);
	spl.SetValue("cost", GetNativeCell(4), true);
	spl.SetValue("hash", GetStringHash(classname), true);
	
	// 10/24/2018
	if(argc >= 5)
	{
		char description[255];
		GetNativeString(5, description, 255);
		spl.SetString("description", description, true);
	}
	
	return g_hAllSpellList.Push(spl);
}

public int Native_CreateSkill(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	int index = FindValueIndexByClassName(classname, g_hAllSkillList);
	if(index > -1)
		return index;
	
	char display[128];
	StringMap skill = CreateTrie();
	GetNativeString(2, display, 128);
	
	skill.SetString("classname", classname, true);
	skill.SetString("display", display, true);
	skill.SetValue("zombie", GetNativeCell(3), true);
	skill.SetValue("hash", GetStringHash(classname), true);
	
	if(argc >= 4)
	{
		char description[255];
		GetNativeString(4, description, 255);
		skill.SetString("description", description, true);
	}
	
	return g_hAllSkillList.Push(skill);
}

public int Native_FindSpell(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	return FindValueIndexByClassName(classname, g_hAllSpellList);
}

public int Native_FindSkill(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	char classname[64];
	GetNativeString(1, classname, 64);
	return FindValueIndexByClassName(classname, g_hAllSkillList);
}

public int Native_FreeSpell(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSpellList.Length)
		return false;
	
	StringMap spl = g_hAllSpellList.Get(index);
	g_hAllSpellList.Erase(index);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(g_hPlayerSpell[i] == null || g_hPlayerSpell[i].Length <= 0)
			continue;
		
		// 玩家可以同时拥有多个法术
		while((index = g_hPlayerSpell[i].FindValue(spl)) != -1)
			g_hPlayerSpell[i].Erase(index);
	}
	
	return true;
}

public int Native_FreeSkill(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSkillList.Length)
		return false;
	
	StringMap spl = g_hAllSkillList.Get(index);
	g_hAllSkillList.Erase(index);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(g_hPlayerSkill[i] == null || g_hPlayerSkill[i].Length <= 0)
			continue;
		
		// 玩家不能拥有相同的技能
		if((index = g_hPlayerSkill[i].FindValue(spl)) != -1)
			g_hPlayerSkill[i].Erase(index);
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

public int Native_GetSkillCount(Handle plugin, int argc)
{
	return g_hAllSkillList.Length;
}

public int Native_GetSpell(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSpellList.Length)
		ThrowNativeError(SP_ERROR_PARAM, "索引超出范围");
	
	StringMap spl = g_hAllSpellList.Get(index);
	if(spl == null)
		return view_as<int>(INVALID_HANDLE);
	
	return view_as<int>(CloneHandle(spl, plugin));
}

public int Native_GetSkill(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int index = GetNativeCell(1);
	if(index < 0 || index >= g_hAllSkillList.Length)
		ThrowNativeError(SP_ERROR_PARAM, "索引超出范围");
	
	StringMap skill = g_hAllSkillList.Get(index);
	if(skill == null)
		return view_as<int>(INVALID_HANDLE);
	
	return view_as<int>(CloneHandle(skill, plugin));
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

public int Native_GetClientSkillCount(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSkill[client] == null)
		return -1;
	
	return g_hPlayerSkill[client].Length;
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
	
	StringMap spl = g_hPlayerSpell[client].Get(index);
	if(spl == null)
		return view_as<int>(INVALID_HANDLE);
	
	return view_as<int>(CloneHandle(spl, plugin));
}

public int Native_GetClientSkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	int index = GetNativeCell(2);
	if(index < 0 || index >= g_hPlayerSkill[client].Length)
		ThrowNativeError(SP_ERROR_PARAM, "索引超出范围");
	
	StringMap skill = g_hPlayerSkill[client].Get(index);
	if(skill == null)
		return view_as<int>(INVALID_HANDLE);
	
	return view_as<int>(CloneHandle(skill, plugin));
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
	StringMap spl = FindValueByClassName(classname, g_hAllSpellList);
	if(spl == null)
		return -1;
	
	return g_hPlayerSpell[client].Push(spl);
}

public int Native_GiveClientSkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	char classname[64];
	GetNativeString(2, classname, 64);
	StringMap skill = FindValueByClassName(classname, g_hAllSkillList);
	if(skill == null)
		return -1;
	
	int index = FindValueIndexByClassName(classname, g_hPlayerSkill[client]);
	if(index > -1)
		return index;
	
	return g_hPlayerSkill[client].Push(skill);
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

public int Native_RemoveClientSkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSkill[client] == null)
		return false;
	
	int index = GetNativeCell(2);
	if(index < 0 || index >= g_hPlayerSkill[client].Length)
		return false;
	
	g_hPlayerSkill[index].Erase(index);
	return true;
}

public int Native_FindClientSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSpell[client] == null || g_hPlayerSpell[client].Length <= 0)
		return -1;
	
	char classname[64];
	GetNativeString(2, classname, 64);
	return FindValueIndexByClassName(classname, g_hPlayerSpell[client]);
}

public int Native_IsClientHaveSpell(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || g_hPlayerSpell[client] == null || g_hPlayerSpell[client].Length <= 0)
		return false;
	
	char classname[64];
	GetNativeString(2, classname, 64);
	return (FindValueIndexByClassName(classname, g_hPlayerSpell[client]) > -1);
}

public int Native_FindClientSkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "无效的客户端");
	
	if(g_hPlayerSkill[client] == null || g_hPlayerSkill[client].Length <= 0)
		return -1;
	
	char classname[64];
	GetNativeString(2, classname, 64);
	return FindValueIndexByClassName(classname, g_hPlayerSkill[client]);
}

public int Native_IsClientHaveSkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client) || g_hPlayerSkill[client] == null || g_hPlayerSkill[client].Length <= 0)
		return false;
	
	char classname[64];
	GetNativeString(2, classname, 64);
	return (FindValueIndexByClassName(classname, g_hPlayerSkill[client]) > -1);
}


#define DECL_OBJECT_GET_SET_STRING(%1,%2,%3)\
public int Native_Get%1(Handle plugin, int argc)\
{\
	if(argc < 3)\
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int index = GetNativeCell(1);\
	if(%3 == null || index < 0 || index >= %3.Length)\
		return false;\
	char buffer[64];\
	StringMap data = %3.Get(index);\
	if(data == null || !data.GetString(%2, buffer, 64))\
		return false;\
	return (SetNativeString(2, buffer, GetNativeCell(3)) == SP_ERROR_NONE);\
}\
public int Native_Set%1(Handle plugin, int argc)\
{\
	if(argc < 2)\
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int index = GetNativeCell(1);\
	if(%3 == null || index < 0 || index >= %3.Length)\
		return false;\
	char buffer[64];\
	GetNativeString(2, buffer, 64);\
	StringMap data = %3.Get(index);\
	if(data == null)\
		return false;\
	return (data.SetString(%2, buffer, true));\
}

#define DECL_OBJECT_GET_SET_CELL(%1,%2,%3)\
public int Native_Get%1(Handle plugin, int argc)\
{\
	if(argc < 2)\
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int index = GetNativeCell(1);\
	if(%3 == null || index < 0 || index >= %3.Length)\
		return -1;\
	int buffer = -1;\
	StringMap data = %3.Get(index);\
	if(data == null || !data.GetValue(%2, buffer))\
		return -1;\
	return buffer;\
}\
public int Native_Set%1(Handle plugin, int argc)\
{\
	if(argc < 1)\
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");\
	int index = GetNativeCell(1);\
	if(%3 == null || index < 0 || index >= %3.Length)\
		return false;\
	StringMap data = %3.Get(index);\
	if(data == null)\
		return false;\
	return (data.SetValue(%2, GetNativeCell(2), true));\
}

DECL_OBJECT_GET_SET_STRING(SpellClassName,"classname",g_hAllSpellList)
DECL_OBJECT_GET_SET_STRING(SpellDisplayName,"display",g_hAllSpellList)
DECL_OBJECT_GET_SET_STRING(SpellDescription,"description",g_hAllSpellList)
DECL_OBJECT_GET_SET_CELL(SpellConsume,"consume",g_hAllSpellList)
DECL_OBJECT_GET_SET_CELL(SpellCost,"cost",g_hAllSpellList)
DECL_OBJECT_GET_SET_STRING(SkillClassName,"classname",g_hAllSkillList)
DECL_OBJECT_GET_SET_STRING(SkillDisplayName,"display",g_hAllSkillList)
DECL_OBJECT_GET_SET_STRING(SkillDescription,"description",g_hAllSkillList)
DECL_OBJECT_GET_SET_CELL(SkillZombieType,"zombie",g_hAllSkillList)

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

public int Native_GetUserId(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "参数数量不足");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		return -1;
	
	return g_iClientUserId[client];
}

public int Native_GetDataBase(Handle plugin, int argc)
{
	return view_as<int>(CloneHandle(g_hDatabase, plugin));
}

// 管理员菜单
public void OnAdminMenuReady(Handle tm)
{
	if(tm == null)
		return;
	
	TopMenuObject tmo = AddToTopMenu(tm, "l4d2sc_adminmenu", TopMenuObject_Category, TopMenuCategory_MainMenu,
		INVALID_TOPMENUOBJECT, "l4d2sc_adminmenu", ADMFLAG_GENERIC);
	if(tmo == INVALID_TOPMENUOBJECT)
		return;
	
	AddToTopMenu(tm, "l4d2sc_giveexp", TopMenuObject_Item, TopMenuItem_GiveExperience, tmo, "l4d2sc_giveexp", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_givecsh", TopMenuObject_Item, TopMenuItem_GiveCash, tmo, "l4d2sc_givecsh", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_givelvl", TopMenuObject_Item, TopMenuItem_GiveLevel, tmo, "l4d2sc_givelvl", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_fillall", TopMenuObject_Item, TopMenuItem_GiveFill, tmo, "l4d2sc_fillall", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_givesp", TopMenuObject_Item, TopMenuItem_GivePoints, tmo, "l4d2sc_givesp", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_rstsp", TopMenuObject_Item, TopMenuItem_ResetPoints, tmo, "l4d2sc_rstsp", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_givespl", TopMenuObject_Item, TopMenuItem_GiveSpell, tmo, "l4d2sc_givespl", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sc_usespl", TopMenuObject_Item, TopMenuItem_UseSpell, tmo, "l4d2sc_usespl", ADMFLAG_CHEATS);
}

public void TopMenuCategory_MainMenu(TopMenu topmenu, TopMenuAction action,
	TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption || action == TopMenuAction_DisplayTitle)
		FormatEx(buffer, maxlength, "战斗系统菜单");
}

#define MAKE_ADMMENU_GIVE(%1,%2,%3)\
public void TopMenuItem_%2(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)\
{\
	if(action == TopMenuAction_DisplayOption)\
		FormatEx(buffer, maxlength, %1);\
	if(action != TopMenuAction_SelectOption)\
		return;\
	Menu menu = CreateMenu(MenuHandler_SelectCount_%2);\
	menu.SetTitle("%s - 选择数量", %1);\
	menu.AddItem("", tr("%d", %3));\
	menu.AddItem("", tr("%d", %3 * 2));\
	menu.AddItem("", tr("%d", %3 * 5));\
	menu.AddItem("", tr("%d", %3 * 10));\
	menu.AddItem("", tr("%d", %3 * 20));\
	menu.AddItem("", tr("%d", %3 * 50));\
	menu.AddItem("", tr("%d", %3 * 100));\
	menu.ExitButton = true;\
	menu.ExitBackButton = true;\
	menu.Display(client, MENU_TIME_FOREVER);\
}\
public int MenuHandler_SelectCount_%2(Menu menu, MenuAction action, int client, int selected)\
{\
	if(action == MenuAction_End)\
		return 0;\
	if(action == MenuAction_Cancel)\
	{\
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)\
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);\
		return 0;\
	}\
	if(action != MenuAction_Select)\
		return 0;\
	char display[16];\
	menu.GetItem(selected, "", 0, _, display, 16);\
	Menu menu2 = CreateMenu(MenuHandler_GivePlayer_%2);\
	menu2.SetTitle("%s - %s", %1, display);\
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);\
	menu2.ExitButton = true;\
	menu2.ExitBackButton = true;\
	menu2.Display(client, MENU_TIME_FOREVER);\
	return 0;\
}\
public int MenuHandler_GivePlayer_%2(Menu menu, MenuAction action, int client, int selected)\
{\
	if(action == MenuAction_End)\
		return 0;\
	if(action == MenuAction_Cancel)\
	{\
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)\
			TopMenuItem_%2(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);\
		return 0;\
	}\
	if(action != MenuAction_Select)\
		return 0;\
	char info[8], display[64];\
	menu.GetTitle(display, 64);\
	menu.GetItem(selected, info, 8);\
	ReplaceString(display, 64, tr("%s - ", %1), "", false);\
	int target = GetClientOfUserId(StringToInt(info));\
	int amount = StringToInt(display);\
	if(!IsValidClient(target))\
	{\
		PrintToChat(client, "\x03[SC]\x01 玩家已失效，请重新选择。");\
		TopMenuItem_%2(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);\
		return 0;\
	}\
	%2(target, amount);\
	PrintToChat(client, "\x03[SC]\x01 你对 \x04%N\x01 使用了 \x02%s\x01 数量 \x05%d\x01。", target, %1, amount);\
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);\
	return 0;\
}

MAKE_ADMMENU_GIVE("给玩家经验",GiveExperience,100)
MAKE_ADMMENU_GIVE("给玩家金钱",GiveCash,100)
MAKE_ADMMENU_GIVE("给玩家等级",GiveLevel,1)
MAKE_ADMMENU_GIVE("给玩家技能点",GivePoints,1)

void GiveLevel(int client, int amount)
{
	g_iLevel[client] += amount;
	g_iSkillPoint[client] += amount;
}

void GivePoints(int client, int amount)
{
	g_iSkillPoint[client] += amount;
}

public void TopMenuItem_GiveFill(TopMenu topmenu, TopMenuAction action,
	TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "恢复耐力");
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveFill);
	menu.SetTitle("恢复耐力");
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GiveFill(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	char info[16];
	menu.GetItem(selected, info, 16);
	int target = GetClientOfUserId(StringToInt(info));
	if(IsValidClient(target))
	{
		g_fStamina[target] = float(g_iMaxStamina[target]);
		g_fMagic[target] = float(g_iMaxMagic[target]);
		PrintToChat(client, "\x03[提示]\x01 给玩家 \x04%N\x01 回复了耐力。", target);
	}
	else
	{
		PrintToChat(client, "\x03[SC]\x01 玩家已失效，请重新选择。");
	}
	
	TopMenuItem_GiveFill(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
	return 0;
}

public void TopMenuItem_ResetPoints(TopMenu topmenu, TopMenuAction action,
	TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "重置技能点");
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_ResetPoints);
	menu.SetTitle("重置技能点");
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ResetPoints(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	char info[16];
	menu.GetItem(selected, info, 16);
	int target = GetClientOfUserId(StringToInt(info));
	if(IsValidClient(target))
	{
		int cpl = g_pCvarPointAmount.IntValue;
		int points = (g_iMaxHealth[target] / cpl) + (g_iMaxStamina[target] / cpl) + (g_iMaxMagic[target] / cpl);
		g_iMaxHealth[target] = g_iMaxStamina[target] = g_iMaxMagic[target] = g_iMaxWillpower[target] = 0;
		g_fStamina[target] = g_fMagic[target] = g_fWillpower[target] = 0.0;
		g_iSkillPoint[target] += points;
		PrintToChat(client, "\x03[提示]\x01 给玩家 \x04%N\x01 返还了 \x05%d\x01 个技能点。", target, cpl);
	}
	else
	{
		PrintToChat(client, "\x03[SC]\x01 玩家已失效，请重新选择。");
	}
	
	TopMenuItem_ResetPoints(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
	return 0;
}

public void TopMenuItem_GiveSpell(TopMenu topmenu, TopMenuAction action,
	TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "给玩家法术");
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveSpell);
	menu.SetTitle("给玩家法术");
	
	char display[128], classname[11];
	int maxLength = g_hAllSpellList.Length;
	for(int i = 0; i < maxLength; ++i)
	{
		StringMap spl = g_hAllSpellList.Get(i);
		if(spl == null)
			continue;
		
		spl.GetString("display", display, 128);
		IntToString(view_as<int>(spl), classname, 11);
		menu.AddItem(classname, display);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GiveSpell(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	char classname[64];
	menu.GetItem(selected, classname, 64);
	StringMap map = view_as<StringMap>(StringToInt(classname));
	int index = g_hAllSpellList.FindValue(map);
	if(index == -1 || map == null)
	{
		CPrintToChat(client, "\x03[SC]\x01 %T", "购买失败，发生未知错误", client);
		TopMenuItem_GiveSpell(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	g_hPlayerSpell[client].Push(map);
	CPrintToChat(client, "\x03[SC]\x01 %T", "购买了法术", client, classname, 0, g_iAccount[client]);
	
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	// TopMenuItem_GiveSpell(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
	return 0;
}

public void TopMenuItem_UseSpell(TopMenu topmenu, TopMenuAction action,
	TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "使用法术");
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_UseSpell);
	menu.SetTitle("使用法术");
	
	char classname[64], display[128];
	int maxLength = g_hAllSpellList.Length;
	for(int i = 0; i < maxLength; ++i)
	{
		StringMap spl = g_hAllSpellList.Get(i);
		if(spl == null)
			continue;
		
		spl.GetString("classname", classname, 64);
		spl.GetString("display", display, 128);
		menu.AddItem(classname, display);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_UseSpell(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	char classname[64];
	menu.GetItem(selected, classname, 64);
	UseSpellByClient(client, classname);
	CPrintToChat(client, "\x03[SC]\x01 %T", "使用了法术", client, classname, 0);
	
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	// TopMenuItem_UseSpell(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
	return 0;
}
