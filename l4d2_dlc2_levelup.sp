#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <geoip>
// #include <l4d2_skill_detect>
#include <left4dhooks>
// #include <l4d_info_editor>
#include <dhooks>

#define SOUND_Bomb					"weapons/grenade_launcher/grenadefire/grenade_launcher_explode_1.wav"
#define SOUND_BCLAW					"animation/bombing_run_01.wav"
#define SOUND_FREEZE				"physics/glass/glass_impact_bullet4.wav"
#define SOUND_GOOD					"level/gnomeftw.wav"
#define SOUND_BAD					"npc/moustachio/strengthattract05.wav"
#define SOUND_WARP					"ambient/energy/zap7.wav"
#define SOUND_Ball					"physics/destruction/explosivegasleak.wav"
#define PARTICLE_BLOOD				"blood_impact_infected_01"
#define SOUND_GIFT_PICKUP			"ui/gift_pickup.wav"

#define g_flSoH_rate 0.4
#define ZC_SMOKER			1
#define ZC_BOOMER			2
#define ZC_HUNTER			3
#define ZC_SPITTER			4
#define ZC_JOCKEY			5
#define ZC_CHARGER			6
#define ZC_WITCH			7
#define ZC_TANK				8
#define ZC_SURVIVOR			9
#define TEAM_SPECTATORS		1
#define TEAM_SURVIVORS		2
#define TEAM_INFECTED		3
#define CVAR_FLAGS			FCVAR_PROTECTED|FCVAR_NOT_CONNECTED|FCVAR_DONTRECORD

#define AMMOTYPE_PISTOL				1
#define AMMOTYPE_MAGNUM				2
#define AMMOTYPE_ASSAULTRIFLE		3
#define AMMOTYPE_MINIGUN			4
#define AMMOTYPE_SMG				5
#define AMMOTYPE_M60				6
#define AMMOTYPE_SHOTGUN			7
#define AMMOTYPE_AUTOSHOTGUN		8
#define AMMOTYPE_HUNTINGRIFLE		9
#define AMMOTYPE_SNIPERRIFLE		10
#define AMMOTYPE_TURRET				11
#define AMMOTYPE_PIPEBOMB			12
#define AMMOTYPE_MOLOTOV			13
#define AMMOTYPE_VOMITJAR			14
#define AMMOTYPE_PAINPILLS			15
#define AMMOTYPE_FIRSTAID			16
#define AMMOTYPE_GRENADELAUNCHER	17
#define AMMOTYPE_ADRENALINE			18
#define AMMOTYPE_CHAINSAW			19

#define g_flSoHAutoS		0.666666
#define g_flSoHAutoI		0.4
#define g_flSoHAutoE		0.675
#define g_flSoHSpasS		0.5
#define g_flSoHSpasI		0.375
#define g_flSoHSpasE		0.699999
#define g_flSoHPumpS		0.5
#define g_flSoHPumpI		0.5
#define g_flSoHPumpE		0.6
#define TRACE_TOLERANCE		25.0

Handle g_pfnFindUseEntity = null;
// StringMap g_WeaponClipSize, g_WeaponDamage;

const int g_iMaxClip = 254;					// 游戏所允许的最大弹匣数量 8bit，但是 255 会被显示为 0，超过会溢出
const int g_iMaxAmmo = 1023;				// 游戏所允许的最大子弹数量 10bit，超过会溢出
const int g_iMaxHealHealth = 1268;			// 游戏所允许的最大治疗量，超过会溢出
const float g_fIncapShovePenalty = 0.1;		// 连续倒地推惩罚时间
const int g_iIncapShoveNumTrace = 11;
const float g_fIncapShoveDegree = 90.0;
const float g_fJumpHeight = 35.0;			// 跳跃高度
const float g_fJumpHeightDucking = 52.0;	// 跳跃高度(蹲下)

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1) && !GetEntProp(%1, Prop_Send, "m_isGhost"))
#define IsSurvivorHeld(%1)		(GetEntPropEnt(%1, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(%1, Prop_Send, "m_carryAttacker") > 0)
#define mps(%1,%2)				tr("%s %s", %1, (%2 ? "√" : ""))
#define IsNullVector(%1)		(%1[0] == NULL_VECTOR[0] || %1[1] == NULL_VECTOR[1] || %1[2] == NULL_VECTOR[2])

int g_clSkill_1[MAXPLAYERS+1], g_clSkill_2[MAXPLAYERS+1], g_clSkill_3[MAXPLAYERS+1], g_clSkill_4[MAXPLAYERS+1], g_clSkill_5[MAXPLAYERS+1];

enum()
{
	SKL_1_MaxHealth = 1,
	SKL_1_Movement = 2,
	SKL_1_ReviveHealth = 4,
	SKL_1_DmgExtra = 8,
	SKL_1_MagnumInf = 16,
	SKL_1_Gravity = 32,
	SKL_1_Firendly = 64,
	SKL_1_RapidFire = 128,
	SKL_1_Armor = 256,
	SKL_1_NoRecoil = 512,
	SKL_1_KeepClip = 1024,
	SKL_1_ReviveBlock = 2048,
	SKL_1_DisplayHealth = 4096,
	SKL_1_ShoveFatigue = 8192,

	SKL_2_Chainsaw = 1,
	SKL_2_Excited = 2,
	SKL_2_PainPills = 4,
	SKL_2_FullHealth = 8,
	SKL_2_Defibrillator = 16,
	SKL_2_HealBouns = 32,
	SKL_2_PipeBomb = 64,
	SKL_2_SelfHelp = 128,
	SKL_2_Defensive = 256,
	SKL_2_DoubleJump = 512,
	SKL_2_ProtectiveSuit = 1024,
	SKL_2_Magnum = 2048,
	SKL_2_LadderGun = 4096,
	SKL_2_IncapCrawling = 8192,

	SKL_3_Sacrifice = 1,
	SKL_3_Respawn = 2,
	SKL_3_IncapFire = 4,
	SKL_3_ReviveBonus = 8,
	SKL_3_Freeze = 16,
	SKL_3_Kickback = 32,
	SKL_3_GodMode = 64,
	SKL_3_SelfHeal = 128,
	SKL_3_BunnyHop = 256,
	SKL_3_Parachute = 512,
	SKL_3_MoreAmmo = 1024,
	SKL_3_TempSanctuary = 2048,
	SKL_3_Ricochet = 4096,
	SKL_3_Accurate = 8192,

	SKL_4_ClawHeal = 1,
	SKL_4_DmgExtra = 2,
	SKL_4_DuckShover = 4,
	SKL_4_FastFired = 8,
	SKL_4_SniperExtra = 16,
	SKL_4_FastReload = 32,
	SKL_4_MachStrafe = 64,
	SKL_4_MoreDmgExtra = 128,
	SKL_4_Defensive = 256,
	SKL_4_ClipSize = 512,
	SKL_4_Shove = 1024,
	SKL_4_TempRespite = 2048,
	SKL_4_Terror = 4096,

	SKL_5_FireBullet = 1,
	SKL_5_ExpBullet = 2,
	SKL_5_RetardBullet = 4,
	SKL_5_DmgExtra = 8,
	SKL_5_Vampire = 16,
	SKL_5_InfAmmo = 32,
	SKL_5_Overkill = 64,
	SKL_5_RocketDude = 128,
	SKL_5_ClipHold = 256,
	SKL_5_Sneak = 512,
	SKL_5_MeleeRange = 1024,
	SKL_5_ShoveRange = 2048,
	SKL_5_TempRegen = 4096,
};

new g_ttTankKilled		= 0;
new propinfoghost		= -1;
new g_iNextPAttO		= -1;
new g_iVMStartTimeO		= -1;
new g_iShotStartDurO	= -1;
new g_iShotInsertDurO	= -1;
new g_iShotEndDurO		= -1;
new g_iPlayRateO		= -1;
new g_iShotRelStateO	= -1;
new g_iNextAttO			= -1;
new g_iTimeIdleO		= -1;
new g_iActiveWO			= -1;
new g_iViewModelO		= -1;
int g_iVelocityO		= -1;
// int g_iBileTimestamp	= -1;
new g_clSkillPoint[MAXPLAYERS+1] = 0;
new g_ttDefibUsed[MAXPLAYERS+1] = 0;
new g_ttOtherRevived[MAXPLAYERS+1] = 0;
new g_ttSpecialKilled[MAXPLAYERS+1] = 0;
new g_ttCommonKilled[MAXPLAYERS+1] = 0;
new g_ttGivePills[MAXPLAYERS+1] = 0;
new g_ttProtected[MAXPLAYERS+1] = 0;
new g_ttCleared[MAXPLAYERS+1] = 0;
new g_ttPaincEvent[MAXPLAYERS+1] = 0;
new g_ttRescued[MAXPLAYERS+1] = 0;
new g_csSlapCount[MAXPLAYERS+1] = 0;
new bool:MeleeDelay[MAXPLAYERS+1];
new bool:g_bHasRPActive = false;
new bool:g_bIsRPActived[MAXPLAYERS+1] = false;
new bool:g_cdCanTeleport[MAXPLAYERS+1] = false;
new bool:g_bHasVampire[MAXPLAYERS+1] = false;
new bool:g_bHasRetarding[MAXPLAYERS+1] = false;
new bool:g_bCanGunShover[MAXPLAYERS+1] = false;
// new bool:g_bCanDoubleJump[MAXPLAYERS+1] = false;
// new bool:g_bHanFirstRelease[MAXPLAYERS+1] = false;
float g_fMaxSpeedModify[MAXPLAYERS+1] = { 1.0, ... };
float g_fMaxGravityModify[MAXPLAYERS+1] = { 1.0, ... };
float g_fNextCalmTime[MAXPLAYERS+1] = { 0.0, ... };
int g_iIncapShoveIgnore[g_iIncapShoveNumTrace + 1];
bool g_bIsHitByVomit[MAXPLAYERS+1] = { false, ... };
// bool g_bIsInvulnerable[MAXPLAYERS+1];
bool g_bDeadlineHint[MAXPLAYERS+1];
int g_iExtraAmmo[MAXPLAYERS+1];
int g_iExtraArmor[MAXPLAYERS+1];
bool g_bAccurateShot[MAXPLAYERS+1];
bool g_bOnRocketDude[MAXPLAYERS+1];
int g_iDamageChance[MAXPLAYERS+1];
int g_iDamageChanceMin[MAXPLAYERS+1];
int g_iDamageChanceMax[MAXPLAYERS+1];
int g_iDamageBase[MAXPLAYERS+1];
bool g_bIsVerified[MAXPLAYERS+1];
// ArrayList g_aDoorHandled;
Handle g_hTimerSurvival = null;
int g_iGlowModel[MAXPLAYERS+1];
int g_iGlowOwner[4096];
int g_iExtraPrimaryAmmo[MAXPLAYERS+1];

enum struct TDInfo_t {
	int dmg;
	int dmg_type;
	bool headshot;
	bool death;
}

#define MAX_CACHED_MESSAGES		8
StringMap g_mTotalDamage[MAXPLAYERS+1];
// int g_iMessageChannel = 0;
// char g_sCacheMessage[MAXPLAYERS+1][MAX_CACHED_MESSAGES][64];
// Handle g_hClearCacheMessage[MAXPLAYERS+1];
bool g_bIsGamePlaying = false;

enum
{
	JF_None = 0,
	JF_HasJumping = 1,
	JF_CanDoubleJump = 2,
	JF_FirstReleased = 4,
	JF_CanBunnyHop = 8,
	JF_HasFirstJump = 16
};

#define LG_MODE_MANUAL 1
#define LG_MODE_AUTO 2
MoveType mtLastMoveType[MAXPLAYERS+1];

int g_iJumpFlags[MAXPLAYERS+1] = 0;
// int g_iTotalDamage[MAXPLAYERS+1][MAXPLAYERS+1] = 0;
// int g_iLastDamage[MAXPLAYERS+1][MAXPLAYERS+1] = 0;

new String:g_soundLevel[80];
new String:g_sndPortalERROR[80];
new String:g_sndPortalFX[80];
new String:g_particle[80];
new Handle:hTimerAchieved[MAXPLAYERS+1];
new Handle:hTimerMiniFireworks[MAXPLAYERS+1];
new Handle:hTimerLoopEffect[MAXPLAYERS+1];
new Handle:g_CvarSoundLevel = INVALID_HANDLE;
new Handle:g_Cvarautomenu = INVALID_HANDLE;
ConVar g_Cvarhppack = null;
new Handle:cv_sndPortalERROR = INVALID_HANDLE;
new Handle:cv_sndPortalFX = INVALID_HANDLE;
new Handle:cv_particle = INVALID_HANDLE;
// new Handle:sdkRevive = INVALID_HANDLE;
// new Handle:hRoundRespawn = INVALID_HANDLE;
// new Handle:sdkCallPushPlayer = INVALID_HANDLE;
// new Handle:g_hGameConf = INVALID_HANDLE;
// new Handle: sdkAdrenaline = INVALID_HANDLE;
int g_iOldMeleeSwingRange = 0, g_iOldShoveSwingRange = 0, g_iOldShoveCharger = -1;
StringMap g_tMeleeRange, g_tShoveRange, g_tWeaponSkin;
const int g_iUnknownMeleeRange = 90;
const int g_iUnknownShoveRange = 90;

// new Float:cung_cdSaveCount[MAXPLAYERS+1][100][3];
new g_cdSaveCount[MAXPLAYERS+1];
new Float:g_fOldMovement[MAXPLAYERS+1];
new g_clAngryMode[MAXPLAYERS+1];
new g_clAngryPoint[MAXPLAYERS+1];

float g_fForgiveOfTK[MAXPLAYERS+1];
float g_fForgiveOfFF[MAXPLAYERS+1];
int g_iForgiveTKTarget[MAXPLAYERS+1];
int g_iForgiveFFTarget[MAXPLAYERS+1];

#define SPRITE_BEAM					"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO					"materials/sprites/halo01.vmt"
#define SPRITE_GLOW					"materials/sprites/glow.vmt"
#define SOUND_IMPACT1				"physics/flesh/flesh_impact_bullet1.wav"
#define SOUND_IMPACT2				"physics/concrete/concrete_impact_bullet1.wav"
#define SOUND_STEEL					"physics/metal/metal_solid_impact_hard5.wav"
// #define SOUND_WARP					"ambient/energy/zap9.wav"
#define MODEL_SMOKER				"models/infected/smoker.mdl"
#define MODEL_BOOMER				"models/infected/boomer.mdl"
#define MODEL_HUNTER				"models/infected/hunter.mdl"
#define MODEL_SPITTER				"models/infected/spitter.mdl"
#define MODEL_JOCKEY				"models/infected/jockey.mdl"
#define MODEL_CHARGER				"models/infected/charger.mdl"
#define MODEL_TANK					"models/infected/hulk.mdl"

static const char g_sndShoveInfected[][] = {
	"player/survivor/hit/rifle_swing_hit_infected7.wav",
	"player/survivor/hit/rifle_swing_hit_infected8.wav",
	"player/survivor/hit/rifle_swing_hit_infected9.wav",
	"player/survivor/hit/rifle_swing_hit_infected10.wav",
	"player/survivor/hit/rifle_swing_hit_infected11.wav",
	"player/survivor/hit/rifle_swing_hit_infected12.wav",
};

static const char g_sndShoveMiss[][] = {
	"player/survivor/swing/swish_weaponswing_swipe5.wav",
	"player/survivor/swing/swish_weaponswing_swipe6.wav",
};

new g_BeamSprite;
new g_HaloSprite;
// new g_GlowSrpite;

#define MOLOTOV 0
#define EXPLODE 1

int g_iReloadWeaponEntity[MAXPLAYERS+1];
int g_iReloadWeaponClip[MAXPLAYERS+1];
int g_iReloadWeaponOldClip[MAXPLAYERS+1];
int g_iReloadWeaponKeepClip[MAXPLAYERS+1];
int g_iReloadWeaponUpgrade[MAXPLAYERS+1];
int g_iReloadWeaponUpgradeClip[MAXPLAYERS+1];
float g_fIncapShoveTimeout[MAXPLAYERS+1] = { 0.0, ... };
char g_sLastWeapon[MAXPLAYERS+1][64];
int g_iLastWeaponClip[MAXPLAYERS+1];
bool g_bLastWeaponDual[MAXPLAYERS+1];
// int g_iOldRealHealth[MAXPLAYERS+1];
int g_iLastWeaponAmmo[MAXPLAYERS+1];

//装备附加
new g_iRoundEvent = 0;
float g_fNextRoundEvent = 0.0;
new String:g_szRoundEvent[64];

// 增加部位需要同时增加 g_clCurEquip 大小
enum EquipPart_t {
	EquipPart_Head,		// 头部
	EquipPart_Body,		// 身体
	EquipPart_Hand,		// 手部
	EquipPart_Foot,		// 脚部
}

enum EquipPrefix_t {
	EquipPrefix_Fire,		// 烈火(主伤害)
	EquipPrefix_Water,		// 流水(主生命)
	EquipPrefix_Sky,		// 破天(主跳跃)
	EquipPrefix_Wind,		// 疾风(主速度)
	EquipPrefix_Lucky,		// 惊魄(主暴击)
}

// 属性值上限
const int g_iMaxEquipDamage = 100;	// 字面值
const int g_iMaxEquipHealth = 200;	// 百分比
const int g_iMaxEquipSpeed = 20;	// 百分比
const int g_iMaxEquipGravity = 25;	// 百分比
const int g_iMaxEquipCrit = 1000;	// 千分比

enum struct EquipData_t {
	int hashID;				// 装备唯一ID
	bool valid;				// 装备是否存在
	EquipPrefix_t prefix;	// 装备类型
	EquipPart_t parts;		// 装备部位
	int damage;				// 伤害加成(基础)
	int health;				// 生命上限加成
	int speed;				// 移动速度加成
	int gravity;			// 跳跃高度加成
	int crit;				// 暴击率加成
	int effect;				// 装备附魔效果，参考 RebuildEquipStr 里的定义
	
	// 字符串(仅显示用)
	// 一个utf8字符大概需要4字节，末尾还要加一个字节存放\0
	char sPrefix[32];
	char sParts[32];
	char sEffect[128];
	char sNamed[32];
}

StringMap g_mEquipData[MAXPLAYERS+1];

/*
new bool:g_eqmValid[MAXPLAYERS+1][12];	//装备是否存在
new g_eqmPrefix[MAXPLAYERS+1][12];		//装备类型
new String:g_esPrefix[MAXPLAYERS+1][12][32];		//装备类型名称
new g_eqmParts[MAXPLAYERS+1][12];		//装备部件类型
new String:g_esParts[MAXPLAYERS+1][12][32];		//装备部件名称
new g_eqmDamage[MAXPLAYERS+1][12];		//装备+伤害
new g_eqmHealth[MAXPLAYERS+1][12];		//装备+HP上限
new g_eqmSpeed[MAXPLAYERS+1][12];		//装备+速度
new g_eqmGravity[MAXPLAYERS+1][12];		//装备+重力
new g_eqmUpgrade[MAXPLAYERS+1][12];		//装备+暴击率
new String:g_esEffects[MAXPLAYERS+1][12][128];		//装备附加天赋技能名称
new g_eqmEffects[MAXPLAYERS+1][12];		//装备附加天赋技能类型
new String: g_esUpgrade[MAXPLAYERS+1][12][32];		//装备的完美度
*/

new g_clCurEquip[MAXPLAYERS+1][4];		//当前装备部件所在栏位
int g_iActiveEffects[MAXPLAYERS+1][sizeof(g_clCurEquip[])];

// new SelectEqm[MAXPLAYERS+1];		//选择的装备
new bool:g_csHasGodMode[MAXPLAYERS+1] = {	false, ...};			//无敌天赋无限子弹判断
Handle g_timerRespawn[MAXPLAYERS+1] = {null, ...};
const int g_iMaxEqmEffects = 39;
// bool g_bIgnorePreventStagger[MAXPLAYERS+1];

//玩家基本资料
char g_szSavePath[256];
KeyValues g_kvSavePlayer[MAXPLAYERS+1];

//附加
float g_ctPainPills[MAXPLAYERS+1], g_ctFullHealth[MAXPLAYERS+1], g_ctDefibrillator[MAXPLAYERS+1],
	g_ctPipeBomb[MAXPLAYERS+1], g_ctGodMode[MAXPLAYERS+1], g_ctSelfHeal[MAXPLAYERS+1], g_ctConvTemp[MAXPLAYERS+1];

new g_stFallDamageKilled = 0;
bool g_bHasTeleportActived = false;
bool g_bHasFirstJoin[MAXPLAYERS+1];
bool g_bHasJumping[MAXPLAYERS+1];
bool g_bIsPaincEvent = false;
bool g_bIsPaincIncap = false;

new bool:g_bIsAngryCritActive = false;
new bool:g_bIsAngryLastStandActive = false;
new bool:g_bIsAngryBloodthirstyActive = false;
new bool:g_bIsAngryActive = false;

#define STAR_1_MDL		"models/editor/air_node_hint.mdl"
#define STAR_2_MDL		"models/editor/air_node.mdl"
#define MUSHROOM_MDL	"models/editor/node_hint.mdl"
#define CHAIN_MDL		"models/editor/scriptedsequence.mdl"
#define GOMBA_MDL		"models/editor/overlay_helper.mdl"
#define LUMA_MDL		"models/items/l4d_gift.mdl"
#define INDICATOR_MDL	"models/extras/info_speech.mdl"

#define SLOT_NUM		20

#define REWARD_SOUND	"ui/pickup_guitarriff10.wav"
int g_iBulletFired[MAXPLAYERS+1];

float g_fFreezeTime[MAXPLAYERS+1] = 0.0;
int g_iWeaponSpeedEntity[MAXPLAYERS+1];
float g_fWeaponSpeedUpdate[MAXPLAYERS+1];
int g_iWeaponSpeedTotal = 0;
bool g_bIsPluginCrawling = false;

ConVar g_pCvarCommonKilled, g_pCvarDefibUsed, g_pCvarGivePills, g_pCvarOtherRevived, g_pCvarProtected,
	g_pCvarSpecialKilled, g_pCvarCleared, g_pCvarPaincEvent, g_pCvarRescued, g_pCvarTankDeath, g_pCvarReimburse,
	g_pCvarSurvivorBot, g_pCvarInfectedBot, g_pCvarEquipment;

ConVar g_hCvarGodMode, g_hCvarInfinite, g_hCvarBurnNormal, g_hCvarBurnHard, g_hCvarBurnExpert, g_hCvarReviveHealth,
	g_hCvarZombieSpeed, g_hCvarLimpHealth, g_hCvarDuckSpeed, g_hCvarMedicalTime, g_hCvarReviveTime, g_hCvarGravity,
	g_hCvarShovRange, g_hCvarShovTime, g_hCvarMeleeRange, g_hCvarAdrenTime, g_hCvarDefibTime, g_hCvarZombieHealth,
	g_hCvarIncapCount, g_hCvarPaincEvent, g_hCvarLimitSmoker, g_hCvarLimitBoomer, g_hCvarLimitHunter, g_hCvarLimitSpitter,
	g_hCvarLimitJockey, g_hCvarLimitCharger, g_hCvarLimitSpecial, g_hCvarAccele, g_hCvarCollide, g_hCvarVelocity,
	g_hCvarFirstAidMaxHeal, g_hCvarPainPillsMaxHeal, g_hCvarIncapCrawling, g_hCvarChargerShove;

// int g_iZombieSpawner = -1;
int g_iCommonHealth = 50;
bool /*g_bRoundFirstStarting = false, */g_bLateLoad = false;
ConVar g_pCvarKickSteamId, g_pCvarAllow, g_pCvarValidity, g_pCvarGiftChance, g_pCvarStartPoints, g_pCvarRP, g_pCvarRE, g_pCvarAS, g_pCvarSaveStatus, g_pCvarBotRP;
Handle g_hDetourTestMeleeSwingCollision = null, g_hDetourTestSwingCollision = null/*, g_hDetourIsInvulnerable = null*/;
Handle g_pfnOnSwingStart = null, g_pfnOnPummelEnded = null, g_pfnEndCharge = null, g_pfnOnCarryEnded = null, g_pfnIsInvulnerable = null, g_pfnCreateGift = null,
	g_pfnCreateSmoker = null, g_pfnCreateBoomer = null, g_pfnCreateHunter = null, g_pfnCreateSpitter = null, g_pfnCreateJockey = null, g_pfnCreateCharger = null,
	g_pfnCreateTank = null;
GlobalForward g_fwOnUpdateStatus, g_fwOnGiveHealth, g_fwOnGiveAmmo, g_fwOnGiveArmor, g_fwOnGivePoints, g_fwOnGiveEquipment, g_fwOnSkillLearn, g_fwOnSkillForget,
	g_fwOnFreeze, g_fwOnGiftPickup, g_fwOnLottery, g_fwOnRoundEvent, g_fwOnAngrySkill, g_fwOnAngryPoint;

public Plugin:myinfo =
{
	name = "娱乐插件",
	author = "zonde306",
	description = "",
	version = "1.1.2",
	url = "https://forums.alliedmods.net/",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	RegPluginLibrary("l4d2_dlc2_levelup");
	
	// void LV_GiveHealth(int client, int amount, bool limited, bool convertable)
	CreateNative("LV_GiveHealth", Native_AddHealth);
	
	// void LV_GiveAmmo(int client, int amount, int limited)
	CreateNative("LV_GiveAmmo", Native_AddAmmo);
	
	// void LV_GiveArmor(int client, int amount, bool helmet)
	CreateNative("LV_GiveArmor", Native_AddArmor);
	
	// void LV_GivePoints(int client, int amount)
	CreateNative("LV_GivePoints", Native_GiveSkillPoints);
	
	// int LV_GetPoints(int client)
	CreateNative("LV_GetPoints", Native_GetSkillPoints);
	
	// int LV_GiveEquipment(int client, int parts)
	CreateNative("LV_GiveEquipment", Native_GiveEquipment);
	
	// void LV_GenerateRandom(int client, bool uncap)
	CreateNative("LV_GenerateRandom", Native_GenerateRandomStatus);
	
	// bool LV_SaveToFile(int client, bool checkpoint)
	CreateNative("LV_SaveToFile", Native_SaveToFile);
	
	// bool LV_LoadFromFile(int client, bool checkpoint)
	CreateNative("LV_LoadFromFile", Native_LoadFromFile);
	
	// bool LV_GetSkill(int client, int level, int skill)
	CreateNative("LV_GetSkill", Native_GetSkill);
	
	// void LV_GiveSkill(int client, int level, int skill)
	CreateNative("LV_GiveSkill", Native_GiveSkill);
	
	// void LV_RemoveSkill(int client, int level, int skill)
	CreateNative("LV_RemoveSkill", Native_RemoveSkill);
	
	// int LV_GetEffects(int client, int effect)
	CreateNative("LV_GetEffects", Native_GetEffects);
	
	// int LV_GetPower(int client)
	CreateNative("LV_GetPower", Native_GetPower);
	
	// void LV_GetAttrs(int client, int& damage, int& health, int& speed, int& gravity, int& crit, bool withSkill)
	CreateNative("LV_GetAttrs", Native_GetAttrs);
	
	// int LV_GetAngrySkill(int client)
	CreateNative("LV_GetAngrySkill", Native_GetAngrySkill);
	
	// void LV_SetAngrySkill(int client, int skill)
	CreateNative("LV_SetAngrySkill", Native_SetAngrySkill);
	
	// int LV_GetAngryPoints(int client)
	CreateNative("LV_GetAngryPoints", Native_GetAngryPoints);
	
	// void LV_SetAngryPoints(int client, int amount)
	CreateNative("LV_GiveAngryPoints", Native_GiveAngryPoints);
	
	// int LV_GetRoundEvent()
	CreateNative("LV_GetRoundEvent", Native_GetRoundEvent);
	
	// void LV_SetRoundEvent(int event)
	CreateNative("LV_SetRoundEvent", Native_SetRoundEvent);
	
	// void LV_FreezePlayer(int client, float duration)
	CreateNative("LV_Freeze", Native_FreezePlayer);
	
	// void LV_GetTempHealth(int client)
	CreateNative("LV_GetTempHealth", Native_GetTempHealth);
	
	// int LV_GetCurrentAttacker(int client)
	CreateNative("LV_GetCurrentAttacker", Native_GetCurrentAttacker);
	
	// int LV_GetCurrentVictim(int client)
	CreateNative("LV_GetCurrentVictim", Native_GetCurrentVictim);
	
	// int LV_GetArmor(int client)
	CreateNative("LV_GetArmor", Native_GetArmor);
	
	// int LV_GetAmmo(int client)
	CreateNative("LV_GetAmmo", Native_GetAmmo);
	
	// void LV_GetEquipment(int client, int[] results, int size_results)
	CreateNative("LV_GetEquipment", Native_GetEquipment);
	
	// void LV_TriggerAngry(int client, int mode)
	CreateNative("LV_TriggerAngry", Native_TriggerAngry);
	
	// void LV_TriggerGift(int client, int mode)
	CreateNative("LV_TriggerGift", Native_TriggerGift);
	
	// void LV_TriggerLottery(int client, int mode)
	CreateNative("LV_TriggerLottery", Native_TriggerLottery);
	
	// float LV_GetFreezeTimer(int client)
	CreateNative("LV_GetFreezeTimer", Native_GetFreezeTimer);
	
	// void LV_SetFreezeTimer(int client, float time)
	CreateNative("LV_SetFreezeTimer", Native_SetFreezeTimer);
	
	// Action LV_OnUpdateStatus(int client, bool& heal, int& damage, int& health, int& speed, int& gravity, int& critChance, int& critDamageMin, int& critDamageMax, int[] effects, int num_effects)
	g_fwOnUpdateStatus = CreateGlobalForward("LV_OnUpdateStatus", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array, Param_Cell);
	
	// Action LV_OnGiveHealth(int client, int& amount, bool& limited, bool& convertable)
	g_fwOnGiveHealth = CreateGlobalForward("LV_OnGiveHealth", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	
	// Action LV_OnGiveAmmo(int client, int& amount, int& limited)
	g_fwOnGiveAmmo = CreateGlobalForward("LV_OnGiveAmmo", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef);
	
	// Action LV_OnGiveAmmo(int client, int& amount, bool& helmet)
	g_fwOnGiveArmor = CreateGlobalForward("LV_OnGiveArmor", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef);
	
	// Action LV_OnGivePoints(int client, int& amount)
	g_fwOnGivePoints = CreateGlobalForward("LV_OnGivePoints", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnGiveEquipment(int client, int& parts)
	g_fwOnGiveEquipment = CreateGlobalForward("LV_OnGiveEquipment", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnSkillLearn(int client, int& level, int& skill, bool& free)
	g_fwOnSkillLearn = CreateGlobalForward("LV_OnSkillLearn", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	
	// Action LV_OnSkillForget(int client, int& level, int& skill)
	g_fwOnSkillForget = CreateGlobalForward("LV_OnSkillForget", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef);
	
	// Action LV_OnSkillForget(int client, float& duration)
	g_fwOnFreeze = CreateGlobalForward("LV_OnFreeze", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnGift(int client, int& reward)
	g_fwOnGiftPickup = CreateGlobalForward("LV_OnGift", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnLottery(int client, int& reward)
	g_fwOnLottery = CreateGlobalForward("LV_OnLottery", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnRoundEvent(int& event)
	g_fwOnRoundEvent = CreateGlobalForward("LV_OnRoundEvent", ET_Hook, Param_CellByRef);
	
	// Action LV_OnArgryTrigger(int client, int& mode)
	g_fwOnAngrySkill = CreateGlobalForward("LV_OnArgryTrigger", ET_Hook, Param_Cell, Param_CellByRef);
	
	// Action LV_OnGiveArgryPoints(int client, int& amount)
	g_fwOnAngryPoint = CreateGlobalForward("LV_OnGiveArgryPoints", ET_Hook, Param_Cell, Param_CellByRef);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	g_pCvarAllow = CreateConVar("lv_enable", "1", "是否开启插件", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvarautomenu = CreateConVar("lv_automenu", "1", "是否在需要时候自动弹出天赋技能选单", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarKickSteamId = CreateConVar("lv_autokick", "0", "是否禁止 SteamID 不正确的玩家加入", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarRP = CreateConVar("lv_enable_rp", "1", "是否开启人品功能", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarRE = CreateConVar("lv_enable_re", "1", "是否开启天启功能", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarAS = CreateConVar("lv_enable_as", "1", "是否开启怒气技功能", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvarhppack = CreateConVar("lv_hppack", "0", "是否开启开局自动回血", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarSaveStatus = CreateConVar("lv_save_status", "0", "保存奖励计数", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarEquipment = CreateConVar("lv_enable_eq", "1", "是否开启装备功能", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarSurvivorBot = CreateConVar("lv_survivor_bot", "1", "是否为生还者机器人生存随机属性.0=禁用.1=启用.2=启用+强化", FCVAR_NONE, true, 0.0, true, 2.0);
	g_pCvarInfectedBot = CreateConVar("lv_infected_bot", "1", "是否为感染者机器人生存随机属性.0=禁用.1=启用.2=启用+强化", FCVAR_NONE, true, 0.0, true, 2.0);
	g_CvarSoundLevel = CreateConVar("lv_sound_level", "items/suitchargeok1.wav", "天赋技能选单声音文件途径");
	cv_particle = CreateConVar("lv_portals_particle", "electrical_arc_01_system", "存读点特效", FCVAR_NONE);
	cv_sndPortalERROR = CreateConVar("lv_portals_sounderror","buttons/blip2.wav", "存点声音文件途径", FCVAR_NONE);
	cv_sndPortalFX = CreateConVar("lv_portals_soundfx","ui/pickup_misc42.wav", "读点声音文件途径", FCVAR_NONE);
	g_pCvarValidity = CreateConVar("lv_save_validity","86400", "存档有效期(秒)，过期无法读档.0=无限", FCVAR_NONE, true, 0.0);
	g_pCvarGiftChance = CreateConVar("lv_gift_chance","1", "特感死亡掉落礼物几率(1~100)", FCVAR_NONE, true, 0.0, true, 100.0);
	g_pCvarStartPoints = CreateConVar("lv_starter_points","3", "初始硬币数量", FCVAR_NONE, true, 0.0, true, 30.0);
	g_pCvarReimburse = CreateConVar("lv_expired_reimburse","1750", "存档过期战斗力补偿(补偿硬币=先前战斗力/补偿数值).0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarBotRP = CreateConVar("lv_bot_rp","15", "机器人开门时触发人品事件的几率(1~100)", FCVAR_NONE, true, 0.0, true, 100.0);
	
	g_pCvarCommonKilled = CreateConVar("lv_bonus_common_kill", "150", "干掉多少普感奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarDefibUsed = CreateConVar("lv_bonus_defib_used", "6", "治疗/电击多少次队友奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarGivePills = CreateConVar("lv_bonus_give_pills", "20", "给队友递药/针多少次奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarOtherRevived = CreateConVar("lv_bonus_revive", "15", "救起队友多少次奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarProtected = CreateConVar("lv_bonus_protect", "40", "保护队友多少次奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarSpecialKilled = CreateConVar("lv_bonus_special_kill", "30", "干掉多少特感奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarCleared = CreateConVar("lv_bonus_cleared", "10", "清理多少个区域奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarPaincEvent = CreateConVar("lv_bonus_painc_event", "10", "守住多波个尸潮奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarRescued = CreateConVar("lv_bonus_rescue", "30", "救援队友多少次奖励一硬币.0=禁用", FCVAR_NONE, true, 0.0);
	g_pCvarTankDeath = CreateConVar("lv_bonus_tank", "1", "是否开启Tank死亡奖励.0=禁用.1=启用", FCVAR_NONE, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "l4d2_dlc2_levelup");
	
	g_iNextPAttO		=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	g_iShotStartDurO	=	FindSendPropInfo("CBaseShotgun","m_reloadStartDuration");
	g_iShotInsertDurO	=	FindSendPropInfo("CBaseShotgun","m_reloadInsertDuration");
	g_iShotEndDurO		=	FindSendPropInfo("CBaseShotgun","m_reloadEndDuration");
	g_iPlayRateO		=	FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
	g_iShotRelStateO	=	FindSendPropInfo("CBaseShotgun","m_reloadState");
	g_iNextAttO			=	FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
	g_iTimeIdleO		=	FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
	g_iVMStartTimeO		=	FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
	g_iActiveWO			=	FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	g_iViewModelO		=	FindSendPropInfo("CTerrorPlayer","m_hViewModel");
	propinfoghost		=	FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	g_iVelocityO		=	FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	// g_iBileTimestamp	=	FindSendPropInfo("CTerrorPlayer", "m_itTimer") + 8;

	g_hCvarGodMode = FindConVar("god");
	// g_hCvarInfinite = FindConVar("sv_infinite_ammo");
	g_hCvarInfinite = FindConVar("sv_infinite_primary_ammo");
	g_hCvarBurnNormal = FindConVar("survivor_burn_factor_normal");
	g_hCvarBurnHard = FindConVar("survivor_burn_factor_hard");
	g_hCvarBurnExpert = FindConVar("survivor_burn_factor_expert");
	g_hCvarReviveHealth = FindConVar("survivor_revive_health");
	g_hCvarZombieSpeed = FindConVar("z_speed");
	g_hCvarLimpHealth = FindConVar("survivor_limp_health");
	g_hCvarDuckSpeed = FindConVar("survivor_crouch_speed");
	g_hCvarMedicalTime = FindConVar("first_aid_kit_use_duration");
	g_hCvarReviveTime = FindConVar("survivor_revive_duration");
	g_hCvarGravity = FindConVar("sv_gravity");
	g_hCvarShovRange = FindConVar("z_gun_range");
	g_hCvarShovTime = FindConVar("z_gun_swing_interval");
	g_hCvarMeleeRange = FindConVar("melee_range");
	g_hCvarAdrenTime = FindConVar("adrenaline_duration");
	g_hCvarDefibTime = FindConVar("defibrillator_use_duration");
	g_hCvarZombieHealth = FindConVar("z_health");
	g_hCvarIncapCount = FindConVar("survivor_max_incapacitated_count");
	g_hCvarPaincEvent = FindConVar("director_panic_forever");
	g_hCvarLimitSpecial = FindConVar("z_max_player_zombies");
	g_hCvarLimitSmoker = FindConVar("z_smoker_limit");
	g_hCvarLimitBoomer = FindConVar("z_boomer_limit");
	g_hCvarLimitHunter = FindConVar("z_hunter_limit");
	g_hCvarLimitSpitter = FindConVar("z_spitter_limit");
	g_hCvarLimitJockey = FindConVar("z_jockey_limit");
	g_hCvarLimitCharger = FindConVar("z_charger_limit");
	g_hCvarAccele = FindConVar("sv_airaccelerate");
	g_hCvarCollide = FindConVar("sv_bounce");
	g_hCvarVelocity = FindConVar("sv_maxvelocity");
	g_hCvarFirstAidMaxHeal = FindConVar("first_aid_kit_max_heal");
	g_hCvarPainPillsMaxHeal = FindConVar("pain_pills_health_threshold");
	g_hCvarIncapCrawling = FindConVar("survivor_allow_crawling");
	g_hCvarChargerShove = FindConVar("z_charger_allow_shove");

	HookConVarChange(g_hCvarZombieHealth, ConVarChaged_ZombieHealth);
	g_iCommonHealth = g_hCvarZombieHealth.IntValue;
	// g_WeaponClipSize = new StringMap();
	// g_WeaponDamage = new StringMap();
	// g_aDoorHandled = CreateArray();
	
	BuildPath(Path_SM, g_szSavePath, sizeof(g_szSavePath), "data/l4d2_dlc2_levelup");

	RegConsoleCmd("lv", Command_Levelup, "", FCVAR_HIDDEN);
	RegConsoleCmd("rpg", Command_Levelup, "", FCVAR_HIDDEN);
	RegConsoleCmd("perks", Command_Levelup, "", FCVAR_HIDDEN);
	RegConsoleCmd("skills", Command_Levelup, "", FCVAR_HIDDEN);
	RegConsoleCmd("shop", Command_Shop, "", FCVAR_HIDDEN);
	RegConsoleCmd("buy", Command_Shop, "", FCVAR_HIDDEN);
	RegConsoleCmd("b", Command_Shop, "", FCVAR_HIDDEN);
	RegConsoleCmd("rp", Command_RandEvent, "", FCVAR_HIDDEN);
	RegConsoleCmd("ldw", Command_RandEvent, "", FCVAR_HIDDEN);
	// RegConsoleCmd("cd", Command_SavePoint, "", FCVAR_HIDDEN);
	// RegConsoleCmd("dd", Command_LoadPoint, "", FCVAR_HIDDEN);
	// RegConsoleCmd("ld", Command_BackPoint, "", FCVAR_HIDDEN);
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	AddCommandListener(Command_Give, "give");
	AddCommandListener(Command_Away, "go_away_from_keyboard");
	// AddCommandListener(Command_Scripted, "scripted_user_func");

	// HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_entered_start_area", Event_PlayerEnterStartArea);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawnNotify);
	HookEvent("bot_player_replace", Event_PlayerReplaceBot);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
	// HookEvent("spit_burst", Event_SpitBurst);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("tank_killed", Event_TankKilled);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("weapon_reload", Event_WeaponReload);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_pre_entity", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_post_nav", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundWin, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	HookEvent("player_falldamage", Event_PlayerFallDamage);
	HookEvent("award_earned", Event_AwardEarned);
	HookEvent("player_complete_sacrifice", Event_PlayerSacrifice);
	// HookEvent("charger_killed", Event_ChargerKilled);
	// HookEvent("hunter_headshot", Event_HunterKilled);
	HookEvent("scavenge_match_finished", Event_VersusFinish);
	HookEvent("versus_match_finished", Event_VersusFinish);
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_jump_apex", Event_PlayerJumpApex);
	// HookEvent("door_unlocked", Event_DoorUnlocked);
	HookEvent("door_open", Event_DoorEvent);
	HookEvent("door_close", Event_DoorEvent);
	// HookEvent("door_moving", Event_DoorMoving);
	// HookEvent("rescue_door_open", Event_RescueDoorOpen);
	// HookEvent("success_checkpoint_button_used", Event_ButtonPressed);
	// HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("area_cleared", Event_AreaCleared);
	// HookEvent("vomit_bomb_tank", Event_VomitjarTank);
	HookEvent("create_panic_event", Event_PaincEventStart, EventHookMode_PostNoCopy);
	HookEvent("panic_event_finished", Event_PaincEventStop, EventHookMode_PostNoCopy);
	// HookEvent("strongman_bell_knocked_off", Event_StrongmanTrigged);
	// HookEvent("molotov_thrown", Event_MolotovThrown);
	// HookEvent("stashwhacker_game_won", Event_StashwhackerTrigged);
	// HookEvent("scavenge_gas_can_destroyed", Event_GascanDestoryed);
	HookEvent("survivor_rescued", Event_SurvivorRescued);
	HookEvent("weapon_drop", Event_WeaponDropped);
	HookEvent("ammo_pickup", Event_AmmoPickup);
	HookEvent("ammo_pile_weapon_cant_use_ammo", Event_AmmoPickup);
	// HookEvent("weapon_out_of_ammo", Event_AmmoPickup);
	// HookEvent("all_weapons_out_of_ammo", Event_AmmoPickup);
	// HookEvent("ammo_pack_used_fail_doesnt_use_ammo", Event_AmmoPickup);
	// HookEvent("ammo_pack_used_fail_full", Event_AmmoPickup);
	HookEvent("item_pickup", Event_WeaponPickuped);
	HookEvent("player_use", Event_PlayerUsed);
	HookEvent("upgrade_pack_added", Event_UpgradePickup);
	// HookEvent("upgrade_incendiary_ammo", Event_UpgradePickup);
	// HookEvent("upgrade_explosive_ammo", Event_UpgradePickup);
	HookEvent("player_now_it", Event_PlayerHitByVomit);
	HookEvent("player_no_longer_it", Event_PlayerVomitTimeout);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("bullet_impact", Event_BulletImpact);
	HookEvent("christmas_gift_grab", Event_GiftPickup);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("start_holdout", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("survival_at_30min", Event_SurvivalAt30Min, EventHookMode_PostNoCopy);
	HookEvent("survival_at_10min", Event_SurvivalAt10Min, EventHookMode_PostNoCopy);
	HookEvent("tongue_grab", Event_PlayerGrabbed);
	HookEvent("lunge_pounce", Event_PlayerGrabbed);
	HookEvent("jockey_ride", Event_PlayerGrabbed);
	HookEvent("charger_pummel_start", Event_PlayerGrabbed);
	HookEvent("charger_carry_start", Event_PlayerGrabbed);
	HookEvent("jockey_ride_end", Event_PlayerReleased);
	HookEvent("charger_pummel_end", Event_PlayerReleased);
	HookEvent("charger_carry_end", Event_PlayerReleased);
	HookEvent("tongue_release", Event_PlayerReleased);
	HookEvent("pounce_stopped", Event_PlayerReleased);
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrabbed);
	HookEvent("revive_begin", Event_PlayerReviveBegging);
	HookEvent("revive_end", Event_PlayerReviveEnded);
	
	// 检查第一回合用
	// HookEvent("player_first_spawn", Event__PlayerSpawnFirst);
	// HookEvent("player_team", Event__PlayerTeam);
	
	g_tWeaponSkin = CreateTrie();
	g_tWeaponSkin.SetValue("weapon_pistol_magnum",		2);
	g_tWeaponSkin.SetValue("weapon_smg_silenced",		1);
	g_tWeaponSkin.SetValue("weapon_smg",				1);
	g_tWeaponSkin.SetValue("weapon_shotgun_chrome",		1);
	g_tWeaponSkin.SetValue("weapon_pumpshotgun",		1);
	g_tWeaponSkin.SetValue("weapon_autoshotgun",		1);
	g_tWeaponSkin.SetValue("weapon_rifle",				2);
	g_tWeaponSkin.SetValue("weapon_rifle_ak47",			2);
	g_tWeaponSkin.SetValue("weapon_hunting_rifle",		1);
	g_tWeaponSkin.SetValue("crowbar",					1);
	g_tWeaponSkin.SetValue("cricket_bat",				1);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", "l4d2_dlc2_levelup");
	if( FileExists(sPath) )
	{
		Handle hGameData = LoadGameConfigFile("l4d2_dlc2_levelup");
		if( hGameData )
		{
			g_hDetourTestMeleeSwingCollision = DHookCreateFromConf(hGameData, "CTerrorMeleeWeapon::TestMeleeSwingCollision");
			if(DHookEnableDetour(g_hDetourTestMeleeSwingCollision, false, TestMeleeSwingCollisionPre) &&
				DHookEnableDetour(g_hDetourTestMeleeSwingCollision, true, TestMeleeSwingCollisionPost))
			{
				g_tMeleeRange = CreateTrie();
				g_tMeleeRange.SetValue("baseball_bat",		130);
				g_tMeleeRange.SetValue("cricket_bat",		130);
				g_tMeleeRange.SetValue("crowbar",			100);
				g_tMeleeRange.SetValue("electric_guitar",	150);
				g_tMeleeRange.SetValue("fireaxe",			140);
				g_tMeleeRange.SetValue("frying_pan",		100);
				g_tMeleeRange.SetValue("golfclub",			130);
				g_tMeleeRange.SetValue("katana",			140);
				g_tMeleeRange.SetValue("knife",				120);
				g_tMeleeRange.SetValue("machete",			120);
				g_tMeleeRange.SetValue("tonfa",				100);
				g_tMeleeRange.SetValue("riotshield",		100);
				g_tMeleeRange.SetValue("shovel",			175);
				g_tMeleeRange.SetValue("pitchfork",			200);
				
				LogMessage("l4d2_dlc2_levelup: CTerrorMeleeWeapon::TestMeleeSwingCollision Hooked.");
			}
			else
			{
				LogMessage("l4d2_dlc2_levelup: CTerrorMeleeWeapon::TestMeleeSwingCollision Error.");
			}
			
			g_hDetourTestSwingCollision = DHookCreateFromConf(hGameData, "CTerrorWeapon::TestSwingCollision");
			if(DHookEnableDetour(g_hDetourTestSwingCollision, false, TestSwingCollisionPre) &&
				DHookEnableDetour(g_hDetourTestSwingCollision, true, TestSwingCollisionPost))
			{
				g_tShoveRange = CreateTrie();
				g_tShoveRange.SetValue("baseball_bat",				130);
				g_tShoveRange.SetValue("cricket_bat",				130);
				g_tShoveRange.SetValue("crowbar",					100);
				g_tShoveRange.SetValue("electric_guitar",			150);
				g_tShoveRange.SetValue("fireaxe",					140);
				g_tShoveRange.SetValue("frying_pan",				100);
				g_tShoveRange.SetValue("golfclub",					130);
				g_tShoveRange.SetValue("katana",					140);
				g_tShoveRange.SetValue("knife",						120);
				g_tShoveRange.SetValue("machete",					120);
				g_tShoveRange.SetValue("tonfa",						100);
				g_tShoveRange.SetValue("riotshield",				100);
				g_tShoveRange.SetValue("weapon_chainsaw",			100);
				g_tShoveRange.SetValue("shovel",					175);
				g_tShoveRange.SetValue("pitchfork",					200);
				
				g_tShoveRange.SetValue("weapon_pistol",				90);
				g_tShoveRange.SetValue("weapon_pistol_magnum",		90);
				g_tShoveRange.SetValue("weapon_smg",				100);
				g_tShoveRange.SetValue("weapon_smg_silenced",		100);
				g_tShoveRange.SetValue("weapon_smg_mp5",			100);
				g_tShoveRange.SetValue("weapon_pumpshotgun",		120);
				g_tShoveRange.SetValue("weapon_shotgun_chrome",		120);
				g_tShoveRange.SetValue("weapon_autoshotgun",		120);
				g_tShoveRange.SetValue("weapon_shotgun_spas",		120);
				g_tShoveRange.SetValue("weapon_rifle",				130);
				g_tShoveRange.SetValue("weapon_rifle_ak47",			130);
				g_tShoveRange.SetValue("weapon_rifle_desert",		130);
				g_tShoveRange.SetValue("weapon_rifle_sg552",		130);
				g_tShoveRange.SetValue("weapon_hunting_rifle",		140);
				g_tShoveRange.SetValue("weapon_sniper_military",	140);
				g_tShoveRange.SetValue("weapon_sniper_scout",		140);
				g_tShoveRange.SetValue("weapon_sniper_awp",			140);
				g_tShoveRange.SetValue("weapon_rifle_m60",			150);
				g_tShoveRange.SetValue("weapon_grenade_launcher",	110);
				
				/*
				g_tShoveRange.SetValue("weapon_pipe_bomb",			90);
				g_tShoveRange.SetValue("weapon_molotov",			90);
				g_tShoveRange.SetValue("weapon_vomitjar",			90);
				g_tShoveRange.SetValue("weapon_pain_pills",			90);
				g_tShoveRange.SetValue("weapon_adrenaline",			90);
				g_tShoveRange.SetValue("weapon_first_aid_kit",		90);
				g_tShoveRange.SetValue("weapon_defibrillator",		90);
				g_tShoveRange.SetValue("weapon_upgradepack_incendiary",		90);
				g_tShoveRange.SetValue("weapon_upgradepack_explosive",		90);
				*/
				
				LogMessage("l4d2_dlc2_levelup: CTerrorWeapon::TestSwingCollision Hooked.");
			}
			else
			{
				LogMessage("l4d2_dlc2_levelup: CTerrorWeapon::TestSwingCollision Error.");
			}
			
			/*
			g_hDetourIsInvulnerable = DHookCreateFromConf(hGameData, "CTerrorPlayer::IsInvulnerable");
			if(DHookEnableDetour(g_hDetourIsInvulnerable, false, IsInvulnerablePre) && DHookEnableDetour(g_hDetourIsInvulnerable, true, IsInvulnerablePost))
			{
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::IsInvulnerable Hooked.");
			}
			*/
			
			StartPrepSDKCall(SDKCall_Entity);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorWeapon::OnSwingStart"))
			{
				PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
				g_pfnOnSwingStart = EndPrepSDKCall();
			}
			
			if(g_pfnOnSwingStart != null)
				LogMessage("l4d2_dlc2_levelup: CTerrorWeapon::OnSwingStart Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CTerrorWeapon::OnSwingStart Not Found.");
			
			StartPrepSDKCall(SDKCall_Entity);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded"))
			{
				PrepSDKCall_AddParameter(SDKType_String, SDKPass_ByRef);
				PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
				g_pfnOnPummelEnded = EndPrepSDKCall();
			}
			
			if(g_pfnOnPummelEnded != null)
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::OnPummelEnded Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::OnPummelEnded Not Found.");
			
			StartPrepSDKCall(SDKCall_Player);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::FindUseEntity"))
			{
				PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
				PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity,SDKPass_Pointer);
				g_pfnFindUseEntity = EndPrepSDKCall();
			}
			
			if(g_pfnFindUseEntity != null)
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::FindUseEntity Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::FindUseEntity Not Found.");
			
			StartPrepSDKCall(SDKCall_Entity);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCharge::EndCharge"))
				g_pfnEndCharge = EndPrepSDKCall();
			
			if(g_pfnEndCharge != null)
				LogMessage("l4d2_dlc2_levelup: CCharge::EndCharge Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CCharge::EndCharge Not Found.");
			
			StartPrepSDKCall(SDKCall_Player);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnCarryEnded"))
			{
				PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
				g_pfnOnCarryEnded = EndPrepSDKCall();
			}
			
			if(g_pfnOnCarryEnded != null)
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::OnCarryEnded Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::OnCarryEnded Not Found.");
			
			StartPrepSDKCall(SDKCall_Player);
			if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::IsInvulnerable"))
			{
				PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
				g_pfnIsInvulnerable = EndPrepSDKCall();
			}
			
			if(g_pfnIsInvulnerable != null)
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::IsInvulnerable Found.");
			else
				LogMessage("l4d2_dlc2_levelup: CTerrorPlayer::IsInvulnerable Not Found.");
			
			delete hGameData;
		}
	}
	
	PrepSDKCall_CreateSpecials();
	
	// 缓存以及读取
	if(g_bLateLoad)
	{
		OnMapStart();
		OnConfigsExecuted();
		g_bIsGamePlaying = L4D_HasAnySurvivorLeftSafeArea();
	}
	else
	{
		CreateTimer(1.0, Timer_RestoreDefault);
	}
}

public void OnConfigsExecuted()
{
	ConVar l4d2_crawling = FindConVar("l4d2_crawling");
	g_bIsPluginCrawling = (l4d2_crawling != null && l4d2_crawling.BoolValue);
}

public void OnPluginEnd()
{
	if(g_hDetourTestMeleeSwingCollision)
	{
		DHookDisableDetour(g_hDetourTestMeleeSwingCollision, false, TestMeleeSwingCollisionPre);
		DHookDisableDetour(g_hDetourTestMeleeSwingCollision, true, TestMeleeSwingCollisionPost);
	}
	
	if(g_hDetourTestSwingCollision)
	{
		DHookDisableDetour(g_hDetourTestSwingCollision, false, TestSwingCollisionPre);
		DHookDisableDetour(g_hDetourTestSwingCollision, true, TestSwingCollisionPost);
	}
	
	/*
	if(g_hDetourIsInvulnerable)
	{
		DHookDisableDetour(g_hDetourIsInvulnerable, false, IsInvulnerablePre);
		DHookDisableDetour(g_hDetourIsInvulnerable, true, IsInvulnerablePost);
	}
	*/
	
	// 清理以及保存
	OnMapEnd();
}

public void ConVarChaged_ZombieHealth(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iCommonHealth = StringToInt(newValue);
	// g_iCommonHealth = g_hCvarZombieHealth.IntValue;
	PrintToServer("僵尸血量更改：%d丨%s", g_iCommonHealth, newValue);
}

/*
public void Event__PlayerSpawnFirst(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_bRoundFirstStarting)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_bRoundFirstStarting = true;
	PrintToServer("玩家 %N 出现在战役第一关", client);
	// CheatCommand(client, "script", "::WeaponAmmo_AntiReload<-false");
	// CheatCommand(client, "script", "::WeaponInfo.WeaponData={}");
	// CheatCommand(client, "script", "::DamageLimit_IncapRelease<-false");
	// CheatCommand(client, "script", "::WeaponAmmo_Enable<-false");
	// CheatCommand(client, "script", "::DamageLimit_CommonIgnore<-false");
	// CheatCommand(client, "script", "::FriendlyFire_Enable<-false");
	// CheatCommand(client, "script", "::ShotgunSndFix_Enable<-false");
	// CheatCommand(client, "script", "::DifficultyBanalce_MinIntensity<-1");
	// CheatCommand(client, "script", "::DamageLimit_RealHealthValue<--1");
}

public void Event__PlayerTeam(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_bRoundFirstStarting)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int newTeam = event.GetInt("team");
	if(!IsValidClient(client) || newTeam <= 1)
		return;
	
	g_bRoundFirstStarting = true;
	PrintToServer("玩家 %N 出现在第一回合。", client);
	// CheatCommand(client, "script", "::WeaponAmmo_AntiReload<-false");
	// CheatCommand(client, "script", "::WeaponInfo.WeaponData={}");
	// CheatCommand(client, "script", "::DamageLimit_IncapRelease<-false");
	// CheatCommand(client, "script", "::WeaponAmmo_Enable<-false");
	// CheatCommand(client, "script", "::DamageLimit_CommonIgnore<-false");
	// CheatCommand(client, "script", "::FriendlyFire_Enable<-false");
	// CheatCommand(client, "script", "::ShotgunSndFix_Enable<-false");
	// CheatCommand(client, "script", "::DifficultyBanalce_MinIntensity<-1");
	// CheatCommand(client, "script", "::DamageLimit_RealHealthValue<--1");
}
*/

public OnMapStart()
{
	BuildPath(Path_SM, g_szSavePath, sizeof(g_szSavePath), "data/l4d2_dlc2_levelup");

	g_bIsAngryCritActive = false;
	g_bIsAngryLastStandActive = false;
	g_bIsAngryBloodthirstyActive = false;
	g_bIsAngryActive = false;
	g_bHasRPActive = false;
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_szRoundEvent = "无";
	g_bHasTeleportActived = false;
	g_bIsGamePlaying = false;
	
	/*
	PrecacheModel("models/survivors/survivor_teenangst.mdl", true);
	PrecacheModel("models/survivors/survivor_namvet.mdl", true);
	PrecacheModel("models/survivors/survivor_manager.mdl", true);
	PrecacheModel("models/survivors/survivor_biker.mdl", true);
	PrecacheModel("models/survivors/survivor_gambler.mdl", true);
	PrecacheModel("models/survivors/survivor_producer.mdl", true);
	PrecacheModel("models/survivors/survivor_coach.mdl", true);
	PrecacheModel("models/survivors/survivor_mechanic.mdl", true);
	PrecacheModel("models/infected/witch.mdl", true);
	PrecacheModel("models/infected/smoker.mdl", true);
	PrecacheModel("models/infected/boomer.mdl", true);
	PrecacheModel("models/infected/hunter.mdl", true);
	PrecacheModel("models/infected/charger.mdl", true);
	PrecacheModel("models/infected/jockey.mdl", true);
	PrecacheModel("models/infected/spitter.mdl", true);
	PrecacheModel("models/infected/hulk.mdl", true);
	PrecacheModel("models/infected/common_male_ceda.mdl", true);
	PrecacheModel("models/infected/common_male_clown.mdl", true);
	PrecacheModel("models/infected/common_male_mud.mdl", true);
	PrecacheModel("models/infected/common_male_roadcrew.mdl", true);
	PrecacheModel("models/infected/common_male_riot.mdl", true);
	PrecacheModel("models/infected/common_male_fallen_survivor.mdl", true);
	PrecacheModel("models/infected/common_male_jimmy.mdl", true);
	PrecacheModel("models/infected/boomette.mdl", true);
	PrecacheModel("models/w_models/weapons/w_eq_medkit.mdl", true);
	*/
	
	// 部分地图缺少模型，为避免 CTD，必须进行缓存
	PrecacheModel("models/infected/witch_bride.mdl", true);
	PrecacheModel("models/infected/hulk_dlc3.mdl", true);
	PrecacheModel("models/infected/witch.mdl", true);

	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	// g_GlowSrpite = PrecacheModel(SPRITE_GLOW);

	GetConVarString(g_CvarSoundLevel, g_soundLevel, sizeof(g_soundLevel));
	PrecacheSound(g_soundLevel, true);
	PrecacheSound("ui/gift_drop.wav", true);
	
	for(int i = 0; i < sizeof(g_sndShoveInfected); ++i)
		PrecacheSound(g_sndShoveInfected[i], true);
	for(int i = 0; i < sizeof(g_sndShoveMiss); ++i)
		PrecacheSound(g_sndShoveMiss[i], true);

	GetConVarString(cv_particle, g_particle, sizeof(g_particle));
	GetConVarString(cv_sndPortalERROR, g_sndPortalERROR, sizeof(g_sndPortalERROR));
	GetConVarString(cv_sndPortalFX, g_sndPortalFX, sizeof(g_sndPortalFX));
	
	PrecacheParticle(g_particle);
	PrecacheParticle(PARTICLE_BLOOD);
	
	PrecacheSound(g_sndPortalERROR, true);
	PrecacheSound(g_sndPortalFX, true);
	PrecacheSound(SOUND_FREEZE, true);
	PrecacheSound(SOUND_GOOD, true);
	PrecacheSound(SOUND_BAD, true);
	PrecacheSound(SOUND_BCLAW, true);
	PrecacheSound(SOUND_WARP, true);
	PrecacheSound(SOUND_Ball, true);
	PrecacheSound(SOUND_Bomb, true);
	PrecacheSound(SOUND_IMPACT1);
	PrecacheSound(SOUND_IMPACT2);
	PrecacheSound(SOUND_STEEL);
	PrecacheSound(SOUND_GIFT_PICKUP);
	// PrecacheSound(SOUND_WARP);

	PrecacheModel( STAR_1_MDL );
	PrecacheModel( STAR_2_MDL );
	PrecacheModel( MUSHROOM_MDL );
	PrecacheModel( CHAIN_MDL );
	PrecacheModel( GOMBA_MDL );
	PrecacheModel( LUMA_MDL );
	PrecacheModel( MODEL_BOOMER );
	PrecacheModel( MODEL_CHARGER );
	PrecacheModel( MODEL_HUNTER );
	PrecacheModel( MODEL_JOCKEY );
	PrecacheModel( MODEL_SMOKER );
	PrecacheModel( MODEL_SPITTER );
	PrecacheModel( MODEL_TANK );

	PrecacheSound( REWARD_SOUND, true );
	RestoreConVar();

	for(int i = 0; i <= MAXPLAYERS; ++i)
		g_kvSavePlayer[i] = null;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		// Initialization(i);
		ClientSaveToFileLoad(i, g_pCvarSaveStatus.BoolValue);
		
		if(IsValidAliveClient(i))
			RegPlayerHook(i, false);
	}
}

void RestoreConVar()
{
	/*
	g_hCvarGodMode.RestoreDefault(true, false);
	g_hCvarInfinite.RestoreDefault(true, false);
	g_hCvarBurnNormal.RestoreDefault(true, false);
	g_hCvarBurnHard.RestoreDefault(true, false);
	g_hCvarBurnExpert.RestoreDefault(true, false);
	g_hCvarReviveHealth.RestoreDefault(true, false);
	g_hCvarZombieSpeed.RestoreDefault(true, false);
	g_hCvarLimpHealth.RestoreDefault(true, false);
	g_hCvarDuckSpeed.RestoreDefault(true, false);
	g_hCvarMedicalTime.RestoreDefault(true, false);
	g_hCvarReviveTime.RestoreDefault(true, false);
	g_hCvarGravity.RestoreDefault(true, false);
	g_hCvarShovRange.RestoreDefault(true, false);
	g_hCvarShovTime.RestoreDefault(true, false);
	g_hCvarMeleeRange.RestoreDefault(true, false);
	g_hCvarAdrenTime.RestoreDefault(true, false);
	*/

	g_hCvarGodMode.Flags &= ~FCVAR_NOTIFY;
	g_hCvarInfinite.Flags &= ~FCVAR_NOTIFY;
	g_hCvarReviveHealth.Flags &= ~FCVAR_NOTIFY;
	g_hCvarZombieSpeed.Flags &= ~FCVAR_NOTIFY;
	g_hCvarDuckSpeed.Flags &= ~FCVAR_NOTIFY;
	g_hCvarGravity.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimpHealth.Flags &= ~FCVAR_NOTIFY;
	g_hCvarMeleeRange.Flags &= ~FCVAR_NOTIFY;
	g_hCvarShovTime.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnNormal.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnExpert.Flags &= ~FCVAR_NOTIFY;
	g_hCvarBurnHard.Flags &= ~FCVAR_NOTIFY;
	g_hCvarDefibTime.Flags &= ~FCVAR_NOTIFY;
	g_hCvarZombieHealth.Flags &= ~FCVAR_NOTIFY;
	g_hCvarIncapCount.Flags &= ~FCVAR_NOTIFY;
	g_hCvarPaincEvent.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitSpecial.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitSmoker.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitBoomer.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitHunter.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitSpitter.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitJockey.Flags &= ~FCVAR_NOTIFY;
	g_hCvarLimitCharger.Flags &= ~FCVAR_NOTIFY;
	g_hCvarAccele.Flags &= ~FCVAR_NOTIFY;
	g_hCvarCollide.Flags &= ~FCVAR_NOTIFY;
	g_hCvarVelocity.Flags &= ~FCVAR_NOTIFY;
	g_hCvarIncapCrawling.Flags &= ~FCVAR_NOTIFY;

	g_iCommonHealth = 50;
	g_hCvarGodMode.IntValue = 0;
	g_hCvarInfinite.IntValue = 0;
	g_hCvarBurnNormal.FloatValue = 0.2;
	g_hCvarBurnHard.FloatValue = 0.4;
	g_hCvarBurnExpert.FloatValue = 1.0;
	g_hCvarReviveHealth.IntValue = 30;
	g_hCvarZombieSpeed.IntValue = 250;
	g_hCvarLimpHealth.IntValue = 40;
	g_hCvarDuckSpeed.IntValue = 75;
	g_hCvarMedicalTime.FloatValue = 5.0;
	g_hCvarReviveTime.FloatValue = 5.0;
	g_hCvarGravity.IntValue = 800;
	g_hCvarShovRange.IntValue = 75;
	g_hCvarShovTime.FloatValue = 0.7;
	g_hCvarMeleeRange.IntValue = 70;
	g_hCvarAdrenTime.FloatValue = 15.0;
	g_hCvarDefibTime.FloatValue = 3.0;
	g_hCvarZombieHealth.IntValue = 50;
	g_hCvarIncapCount.IntValue = 2;
	g_hCvarPaincEvent.IntValue = 0;
	g_hCvarLimitSpecial.IntValue = 4;
	g_hCvarLimitSmoker.IntValue = 1;
	g_hCvarLimitBoomer.IntValue = 1;
	g_hCvarLimitHunter.IntValue = 1;
	g_hCvarLimitSpitter.IntValue = 1;
	g_hCvarLimitJockey.IntValue = 1;
	g_hCvarLimitCharger.IntValue = 1;
	g_hCvarAccele.IntValue = 10;
	g_hCvarCollide.IntValue = 0;
	g_hCvarVelocity.IntValue = 3500;
	g_hCvarIncapCrawling.IntValue = 1;
	
	/*
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i))
			continue;

		PrintToServer("需要玩家 %N 调整配置。", i);
		// CheatCommand(i, "script", "::WeaponAmmo_AntiReload<-false");
		// CheatCommand(i, "script", "::WeaponInfo.WeaponData={}");
		// CheatCommand(i, "script", "::DamageLimit_IncapRelease<-false");
		// CheatCommand(i, "script", "::WeaponAmmo_Enable<-false");
		// CheatCommand(i, "script", "::DamageLimit_CommonIgnore<-false");
		// CheatCommand(i, "script", "::FriendlyFire_Enable<-false");
		// CheatCommand(i, "script", "::ShotgunSndFix_Enable<-false");
		// CheatCommand(i, "script", "::DifficultyBanalce_MinIntensity<-1");
		// CheatCommand(i, "script", "::DamageLimit_RealHealthValue<--1");
		break;
	}
	*/
}

public OnMapEnd()
{
	// CloseHandle(LVSave);
	g_bHasRPActive = false;
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_bIsGamePlaying = false;
	g_hTimerSurvival = null;

	for(new i = 1; i <= MaxClients; i++)
	{
		// Initialization(i);
		ClientSaveToFileSave(i, g_pCvarSaveStatus.BoolValue);
		OnEntityDestroyed(i);
	}
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_fNextRoundEvent = 0.0;
	// g_bRoundFirstStarting = false;
	g_bIsGamePlaying = false;
	// g_aDoorHandled.Clear();

	for(new i = 1; i <= MaxClients; i++)
	{
		ClientSaveToFileSave(i, g_pCvarSaveStatus.BoolValue);
		// Initialization(i);
		g_bHasFirstJoin[i] = false;
		// g_bHasJumping[i] = false;
		OnEntityDestroyed(i);
		
		if(IsValidClient(i))
		{
			PerformGlow(i, 0, 0, 0);
			RemoveGlowModel(i);
		}
	}
	
	RestoreConVar();
	
	/*
	if(g_iZombieSpawner > -1)
	{
		if(IsValidEntity(g_iZombieSpawner))
			AcceptEntityInput(g_iZombieSpawner, "Kill");

		g_iZombieSpawner = -1;
	}
	*/
	
	if(g_hTimerSurvival != null)
	{
		KillTimer(g_hTimerSurvival);
		g_hTimerSurvival = null;
	}
}

public Action:Event_FinaleWin(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_bIsGamePlaying = false;
	// PrintToChatAll("\x03[\x05提示\x03]\x04最终关卡胜利所有生还者硬币增加\x033\x04枚!");

	/*
	for(new i = 1; i <= MaxClients; i++)
	{
		g_cdSaveCount[client] = -1;
		g_bCanGunShover[client] = false;
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			g_clSkillPoint[client] += 3;
		}
	}
	*/

	RestoreConVar();
}

public void Event_FinaleVehicleLeaving(Event event, const char[] eventName, bool dontBroadcast)
{
	g_bIsGamePlaying = false;
	
	int count = event.GetInt("survivorcount");
	if(count <= 0)
		return;
	if(count > 4)
		count = 4;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		// Initialization(i);
		ClientSaveToFileSave(i, g_pCvarSaveStatus.BoolValue);

		if(IsValidAliveClient(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated") && !GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
		{
			GiveSkillPoint(i, count);

			if(g_pCvarAllow.BoolValue)
				PrintToChat(i, "\x03[提示]\x01 你因为救援关逃跑成功而获得 \x05%d\x01 硬币。", count);
		}
	}
}

public Action:Event_MissionLost(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_fNextRoundEvent = 0.0;

	for(new i = 1; i <= MaxClients; i++)
	{
		// Initialization(i);
		ClientSaveToFileSave(i, g_pCvarSaveStatus.BoolValue);
	}
	
	RestoreConVar();
}

public void Event_SurvivalAt10Min(Event event, const char[] event_name, bool dontBroadcast)
{
	int num_humans = 0;
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidAliveClient(i) && GetClientTeam(i) == 2)
			num_humans += 1;
	
	if(num_humans <= 0)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
			continue;
		
		GiveSkillPoint(i, num_humans);
		if(g_pCvarAllow.BoolValue)
			PrintToChat(i, "\x03[提示]\x01 你因为生存了 10 分钟而获得 %d 硬币。", num_humans);
	}
}

public void Event_SurvivalAt30Min(Event event, const char[] event_name, bool dontBroadcast)
{
	int num_humans = 0;
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidAliveClient(i) && GetClientTeam(i) == 2)
			num_humans += 1;
	
	if(num_humans <= 0)
		return;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
			continue;
		
		GiveSkillPoint(i, num_humans * 3);
		if(g_pCvarAllow.BoolValue)
			PrintToChat(i, "\x03[提示]\x01 你因为生存了 30 分钟而获得 %d 硬币。", num_humans * 3);
	}
}

public void Event_PlayerLeftStartArea(Event event, const char[] event_name, bool dontBroadcast)
{
	L4D_OnFirstSurvivorLeftSafeArea(-1);
	
	if(StrEqual(event_name, "survival_round_start", false))
	{
		g_hTimerSurvival = CreateTimer(4.0 * 60.0, Timer_SurvivalTimer, GetGameTime(), TIMER_FLAG_NO_MAPCHANGE);
		PrintToServer("生还者模式计时开始");
	}
}

public Action Timer_SurvivalTimer(Handle timer, any startTime)
{
	g_hTimerSurvival = null;
	int num_humans = 0;
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidAliveClient(i) && GetClientTeam(i) == 2)
			num_humans += 1;
	
	// 已经没有人了
	if(num_humans <= 0)
		return Plugin_Continue;
	
	int points = 0;
	int timeleft = RoundToNearest((GetGameTime() - view_as<float>(startTime)) / 60);
	switch(timeleft)
	{
		// 铜牌
		case 3, 4, 5:
		{
			points = 1;
			timeleft = 4;
			g_hTimerSurvival = CreateTimer(3.0 * 60.0, Timer_SurvivalTimer, startTime, TIMER_FLAG_NO_MAPCHANGE);
		}
		// 银牌
		case 6, 7, 8:
		{
			points = 2;
			timeleft = 7;
			g_hTimerSurvival = CreateTimer(3.0 * 60.0, Timer_SurvivalTimer, startTime, TIMER_FLAG_NO_MAPCHANGE);
		}
		// 金牌
		case 9, 10, 11:
		{
			points = 3;
			timeleft = 10;
			g_hTimerSurvival = CreateTimer(600.0, Timer_SurvivalTimer, startTime, TIMER_FLAG_NO_MAPCHANGE);
		}
		default:
		{
			// 每10分钟一次
			if(timeleft > 10)
			{
				points = 3 + timeleft / 10;
				g_hTimerSurvival = CreateTimer(600.0, Timer_SurvivalTimer, startTime, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	if(points > 0)
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
				continue;
			
			GiveSkillPoint(i, points);
			if(g_pCvarAllow.BoolValue)
				PrintToChat(i, "\x03[提示]\x01 你因为生存了 \x05%d\x01 分钟而获得 \x05%d\x01 硬币。", timeleft, points);
		}
	
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bIsGamePlaying = true;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidAliveClient(i) && GetClientTeam(i) == 2)
		{
			if(g_pCvarSurvivorBot.BoolValue && IsFakeClient(i))
			{
				GenerateRandomStats(i, g_pCvarSurvivorBot.IntValue > 1);
				PrintToServer("为生还者机器人 %N 生成随机属性，战斗力 %d", i, CalcPlayerPower(i));
			}
			
			RegPlayerHook(i, g_Cvarhppack.BoolValue);
		}
	}
	
	PrintToServer("游戏开始");
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_ttTankKilled = 0;
	g_iRoundEvent = 0;
	g_szRoundEvent = "无";
	g_fNextRoundEvent = 0.0;

	CreateTimer(1.0, Timer_RoundStartPost);
}

public void Event_PlayerGrabbed(Event event, const char[] event_name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidAliveClient(attacker))
	{
		if(g_bIsHitByVomit[attacker])
		{
			// 胆汁效果紫色
			CreateGlowModel(attacker, 0xFF80FF);
		}
		else
		{
			// 控制状态红色
			CreateGlowModel(attacker, 0x8080FF);
		}
	}
	
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidAliveClient(victim))
	{
		// 被控状态橙色
		CreateGlowModel(victim, 0x4080FF);
	}
}

public void Event_PlayerReleased(Event event, const char[] event_name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(attacker))
	{
		if(!IsPlayerAlive(attacker))
		{
			// 已经不再需要光圈了
			RemoveGlowModel(attacker);
		}
		else if(g_bIsHitByVomit[attacker])
		{
			// 胆汁效果紫色
			CreateGlowModel(attacker, 0xFF80FF);
		}
		else
		{
			// 没什么情况，不需要光圈
			RemoveGlowModel(attacker);
		}
	}
	
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(IsValidClient(victim))
	{
		if(!IsPlayerAlive(victim))
		{
			// 已经不再需要光圈了
			RemoveGlowModel(victim);
		}
		else if(GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1) || GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1))
		{
			// 倒地/挂边 黄色
			CreateGlowModel(victim, 0x80FFFF);
		}
		else if(GetEntProp(victim, Prop_Send, "m_bIsOnThirdStrike", 1))
		{
			// 黑白状态 白色
			CreateGlowModel(victim, 0xFFFFFF);
		}
		else
		{
			// 没什么情况，不需要光圈
			RemoveGlowModel(victim);
		}
	}
}

public void Event_PlayerLedgeGrabbed(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	// 倒地/挂边 黄色
	CreateGlowModel(client, 0x80FFFF);
}

public void Event_PlayerReviveBegging(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidAliveClient(client))
		return;
	
	// 正在被救援
	RemoveGlowModel(client);
}

public void Event_PlayerReviveEnded(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidAliveClient(client))
		return;
	
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		// 没能救起来
		CreateGlowModel(client, 0x80FFFF);
	}
	else
	{
		// 救起来了
		RemoveGlowModel(client);
	}
}

public Action Timer_RoundStartPost(Handle timer, any data)
{
	RestoreConVar();
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || GetClientTeam(i) != 2)
			continue;
		
		if(!g_Cvarhppack.BoolValue && !IsPlayerHaveEffect(i, 35))
			continue;
		
		if(!IsPlayerAlive(i))
			CheatCommand(i, "respawn");
		
		CheatCommand(i, "give", "health");
	}
	
	for(int i = 1; i <= MaxClients; ++i)
		g_fIncapShoveTimeout[i] = 0.0;
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
			continue;
		
		RegPlayerHook(i, false);
	}
	
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		ClientSaveToFileSave(client, false);
		CreateHideMotd(client);
	}
	
	Initialization(client, true);
	
	if(g_kvSavePlayer[client])
		delete g_kvSavePlayer[client];
	g_kvSavePlayer[client] = null;
}

public void OnClientPutInServer(int client)
{
	Initialization(client, true);
	
	if(!IsFakeClient(client))
	{
		if(g_kvSavePlayer[client] != null)
		{
			delete g_kvSavePlayer[client];
			g_kvSavePlayer[client] = null;
		}

		ClientSaveToFileLoad(client, false);
	}
}

void GenerateRandomStats(int client, bool uncap)
{
	if(g_mEquipData[client] == null)
		g_mEquipData[client] = CreateTrie();
	else
		g_mEquipData[client].Clear();
	
	SetRandomSeed(GetSysTickCount() + client);
	
	// 硬币
	g_clSkillPoint[client] = g_pCvarStartPoints.IntValue;
	g_clAngryPoint[client] = 0;
	
	// 怒气技能
	g_clAngryMode[client] = GetRandomInt(0, 7);
	
	// 技能
	g_clSkill_1[client] = GetRandomInt(0, 16383);
	g_clSkill_2[client] = GetRandomInt(0, 16383);
	g_clSkill_3[client] = GetRandomInt(0, 16383);
	g_clSkill_4[client] = GetRandomInt(0, 8191);
	g_clSkill_5[client] = GetRandomInt(0, 8191);
	
	// 装备
	for(int i = 0; i < 4; ++i)
	{
		g_clCurEquip[client][i] = GiveEquipment(client, i);
		if(!uncap || !g_clCurEquip[client][i])
			continue;
		
		static char key[16];
		static EquipData_t data;
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		if(g_mEquipData[client].GetArray(key, data, sizeof(data)))
		{
			SetRandomSeed(client * (i + 1));
			data.damage = GetRandomInt((data.prefix == EquipPrefix_Fire ? g_iMaxEquipDamage / 2 : 1), g_iMaxEquipDamage);
			data.health = GetRandomInt((data.prefix == EquipPrefix_Water ? g_iMaxEquipHealth / 2 : 1), g_iMaxEquipHealth);
			data.speed = GetRandomInt((data.prefix == EquipPrefix_Wind ? g_iMaxEquipSpeed / 2 : 1), g_iMaxEquipSpeed);
			data.gravity = GetRandomInt((data.prefix == EquipPrefix_Sky ? g_iMaxEquipGravity / 2 : 1), g_iMaxEquipGravity);
			data.crit = GetRandomInt((data.prefix == EquipPrefix_Lucky ? g_iMaxEquipCrit / 2 : 1), g_iMaxEquipCrit);
			g_mEquipData[client].SetArray(key, data, sizeof(data));
		}
	}
	
	// g_bIsVerified[client] = true;
}

void Initialization(int client, bool invalid = false)
{
	if(invalid)
	{
		for(new i = 0; i < 4; i ++)
			g_clCurEquip[client][i] = 0;
		
		g_clSkillPoint[client] = g_clAngryPoint[client] = g_clAngryMode[client] = g_clSkill_1[client] =
			g_clSkill_2[client] = g_clSkill_3[client] = g_clSkill_4[client] = g_clSkill_5[client] = 0;
	}

	g_bCanGunShover[client] = false;
	g_iJumpFlags[client] = JF_None;
	g_csHasGodMode[client] = false;
	g_bHasVampire[client] = false;
	g_bHasRetarding[client] = false;
	g_bIsRPActived[client] = false;
	g_cdSaveCount[client] = -1;
	g_iBulletFired[client] = 0;
	g_iReloadWeaponOldClip[client] = 0;
	g_iReloadWeaponKeepClip[client] = 0;
	g_iReloadWeaponClip[client] = 0;
	g_iReloadWeaponEntity[client] = INVALID_ENT_REFERENCE;
	g_timerRespawn[client] = null;
	g_fFreezeTime[client] = 0.0;
	g_fMaxSpeedModify[client] = 1.0;
	g_fMaxGravityModify[client] = 1.0;
	g_fNextCalmTime[client] = 0.0;
	g_cdCanTeleport[client] = true;
	g_bIsHitByVomit[client] = false;
	g_bDeadlineHint[client] = false;
	// g_bIsInvulnerable[client] = false;
	g_sLastWeapon[client][0] = EOS;
	g_iLastWeaponClip[client] = -1;
	g_bLastWeaponDual[client] = false;
	// g_iOldRealHealth[client] = 0;
	StringMap toDelete1 = g_mTotalDamage[client];
	g_mTotalDamage[client] = null;
	mtLastMoveType[client] = MOVETYPE_WALK;
	g_iExtraAmmo[client] = 0;
	g_iExtraArmor[client] = 0;
	g_bAccurateShot[client] = false;
	g_iReloadWeaponUpgrade[client] = 0;
	g_iReloadWeaponUpgradeClip[client] = 0;
	g_fForgiveOfTK[client] = 0.0;
	g_fForgiveOfFF[client] = 0.0;
	g_iForgiveTKTarget[client] = 0;
	g_iForgiveFFTarget[client] = 0;
	g_bOnRocketDude[client] = false;
	g_iDamageBase[client] = 0;
	g_iDamageChance[client] = 0;
	g_iDamageChanceMax[client] = 0;
	g_iDamageChanceMin[client] = 0;
	g_bIsVerified[client] = false;
	g_iGlowModel[client] = INVALID_ENT_REFERENCE;
	g_iExtraPrimaryAmmo[client] = 0;
	g_iGlowOwner[client] = 0;
	// g_bIgnorePreventStagger[client] = false;
	// Handle toDelete2 = g_hClearCacheMessage[client];
	// g_hClearCacheMessage[client] = null;
	
	/*
	for(int i = 0; i < MAX_CACHED_MESSAGES; ++i)
		g_sCacheMessage[client][i][0] = EOS;
	*/
	
	g_ttCommonKilled[client] = g_ttDefibUsed[client] = g_ttGivePills[client] = g_ttOtherRevived[client] =
		g_ttProtected[client] = g_ttSpecialKilled[client] = g_csSlapCount[client] = g_ttCleared[client] =
		g_ttPaincEvent[client] = g_ttRescued[client] = 0;
	
	if(g_mEquipData[client] == null)
		g_mEquipData[client] = CreateTrie();
	else
		g_mEquipData[client].Clear();
	
	SDKUnhook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	// SDKUnhook(client, SDKHook_OnTakeDamagePost, PlayerHook_OnTakeDamagePost);
	SDKUnhook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKUnhook(client, SDKHook_TraceAttackPost, PlayerHook_OnTraceAttackPost);
	SDKUnhook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKUnhook(client, SDKHook_PostThinkPost, PlayerHook_OnPostThinkPost);
	SDKUnhook(client, SDKHook_GetMaxHealth, PlayerHook_OnGetMaxHealth);
	SDKUnhook(client, SDKHook_WeaponCanUse, PlayerHook_OnWeaponCanUse);
	
	if(toDelete1 != null)
		delete toDelete1;
	// if(toDelete2 != null)
		// delete toDelete2;
	// if(toDelete3 != null)
		// delete toDelete3;
}

//读档
bool ClientSaveToFileLoad(int client, bool remember = false)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return false;
	
	char steamId[64];
	GetClientAuthId(client, AuthId_SteamID64, steamId, 64, false);
	
	if(steamId[0] == EOS || StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_ID_PENDING", false) ||
		StrEqual(steamId, "STEAM_ID_STOP_IGNORING_RETVALS", false) || StrEqual(steamId, "STEAM_1:0:0", false))
	{
		Initialization(client, true);
		return false;
	}

	if(g_kvSavePlayer[client] == null)
	{
		g_kvSavePlayer[client] = CreateKeyValues(tr("%s", steamId));
		// FileToKeyValues(g_kvSavePlayer[client], tr("%s/%s.txt", g_szSavePath, steamId));
		g_kvSavePlayer[client].ImportFromFile(tr("%s/%s.txt", g_szSavePath, steamId));
	}
	
	int power = g_kvSavePlayer[client].GetNum("power", 0);
	int deadline = g_pCvarValidity.IntValue;
	if(deadline > 0)
	{
		int current = GetTime();
		int prev = g_kvSavePlayer[client].GetNum("deadline", 0);
		if(prev + deadline < current)
		{
			delete g_kvSavePlayer[client];
			g_kvSavePlayer[client] = CreateKeyValues(tr("%s", steamId));
			
			if(prev > 0)
			{
				PrintToServer("玩家 %N 的存档过期了", client);
				g_bDeadlineHint[client] = true;
			}
		}
	}
	
	int points = g_pCvarStartPoints.IntValue;
	if(g_pCvarReimburse.IntValue > 0 && power > 0 && g_bDeadlineHint[client])
		points += power / g_pCvarReimburse.IntValue;
	
	char name[MAX_NAME_LENGTH], ip[16], country[32], code[3];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientIP(client, ip, 16, true);
	GeoipCountry(ip, country, 32);
	GeoipCode2(ip, code);

	// 玩家信息
	g_kvSavePlayer[client].SetString("name", name);
	g_kvSavePlayer[client].SetString("ip", ip);
	g_kvSavePlayer[client].SetString("country", country);
	g_kvSavePlayer[client].SetString("country_code", code);
	
	char steamId2[32], steamId3[32];
	GetClientAuthId(client, AuthId_Steam2, steamId2, 64, false);
	GetClientAuthId(client, AuthId_Steam3, steamId3, 64, false);

	g_kvSavePlayer[client].SetString("steamId_64", steamId);
	g_kvSavePlayer[client].SetString("steamId_2", steamId2);
	g_kvSavePlayer[client].SetString("steamId_3", steamId3);

	// 技能和属性
	g_clSkillPoint[client] = g_kvSavePlayer[client].GetNum("skill_point", points);
	g_clSkill_1[client] = g_kvSavePlayer[client].GetNum("skill_1", 0);
	g_clSkill_2[client] = g_kvSavePlayer[client].GetNum("skill_2", 0);
	g_clSkill_3[client] = g_kvSavePlayer[client].GetNum("skill_3", 0);
	g_clSkill_4[client] = g_kvSavePlayer[client].GetNum("skill_4", 0);
	g_clSkill_5[client] = g_kvSavePlayer[client].GetNum("skill_5", 0);
	
	if(g_pCvarAllow.BoolValue)
		g_clAngryMode[client] = g_kvSavePlayer[client].GetNum("angry_mode", 0);
	
	if(remember)
	{
		g_clAngryPoint[client] = g_kvSavePlayer[client].GetNum("angry_point", 0);
		g_ttDefibUsed[client] = g_kvSavePlayer[client].GetNum("defib_used", 0);
		g_ttOtherRevived[client] = g_kvSavePlayer[client].GetNum("revived_count", 0);
		g_ttSpecialKilled[client] = g_kvSavePlayer[client].GetNum("si_killed", 0);
		g_ttCommonKilled[client] = g_kvSavePlayer[client].GetNum("ci_killed", 0);
		g_ttGivePills[client] = g_kvSavePlayer[client].GetNum("pills_given", 0);
		g_ttProtected[client] = g_kvSavePlayer[client].GetNum("team_protected", 0);
		g_ttCleared[client] = g_kvSavePlayer[client].GetNum("zone_cleared", 0);
		g_ttPaincEvent[client] = g_kvSavePlayer[client].GetNum("painc_holdout", 0);
		g_ttRescued[client] = g_kvSavePlayer[client].GetNum("rescued_count", 0);
	}
	/*
	else
	{
		g_ttCommonKilled[client] = g_ttDefibUsed[client] = g_ttGivePills[client] = g_ttOtherRevived[client] =
			g_ttProtected[client] = g_ttSpecialKilled[client] = g_csSlapCount[client] = g_ttCleared[client] =
			g_ttPaincEvent[client] = g_ttRescued[client] = g_clAngryPoint[client] = 0;
	}
	*/
	
	// 装备相关
	if(g_kvSavePlayer[client].JumpToKey("equipment", false))
	{
		for(int i = 0; i < 4; ++i)
		{
			g_clCurEquip[client][i] = g_kvSavePlayer[client].GetNum(tr("eqm_%d", i), -1);
		}
		g_kvSavePlayer[client].GoBack();
	}
	
	if(g_mEquipData[client] == null)
		g_mEquipData[client] = CreateTrie();
	
	// 背包里的装备
	if(g_kvSavePlayer[client].JumpToKey("bage", false))
	{
		if(g_mEquipData[client] == null)
			g_mEquipData[client] = CreateTrie();
		else
			g_mEquipData[client].Clear();
		
		int size = g_kvSavePlayer[client].GetNum("bage_items", 0);
		for(int i = 0; i < size; ++i)
		{
			if(!g_kvSavePlayer[client].JumpToKey(tr("item_%d", i), false))
				continue;
			
			static EquipData_t data;
			data.valid = view_as<bool>(g_kvSavePlayer[client].GetNum("valid", 0));
			data.prefix = view_as<EquipPrefix_t>(g_kvSavePlayer[client].GetNum("prefix", 0));
			data.parts = view_as<EquipPart_t>(g_kvSavePlayer[client].GetNum("parts", 0));
			data.damage = g_kvSavePlayer[client].GetNum("damage", 0);
			data.health = g_kvSavePlayer[client].GetNum("health", 0);
			data.speed = g_kvSavePlayer[client].GetNum("speed", 0);
			data.gravity = g_kvSavePlayer[client].GetNum("gravity", 0);
			data.crit = g_kvSavePlayer[client].GetNum("crit", 0);
			data.effect = g_kvSavePlayer[client].GetNum("effect", 0);
			data.hashID = g_kvSavePlayer[client].GetNum("hashId", 0);
			
			if(data.valid && data.hashID)
			{
				static char key[16];
				IntToString(data.hashID, key, sizeof(key));
				RebuildEquipStr(data);
				g_mEquipData[client].SetArray(key, data, sizeof(data));
			}
			
			g_kvSavePlayer[client].GoBack();
		}
		
		g_kvSavePlayer[client].GoBack();
	}
	
	g_bIsVerified[client] = true;
	return true;
}

//存档
bool ClientSaveToFileSave(int client, bool remember = false)
{
	if(client > 0 && client <= MaxClients && !g_bIsVerified[client])
		return false;
	
	char steamId[64];
	steamId[0] = EOS;
	
	if(IsValidClient(client))
		GetClientAuthId(client, AuthId_SteamID64, steamId, 64, false);
	else if(g_kvSavePlayer[client] != null)
		g_kvSavePlayer[client].GetString("steamId_64", steamId, 64, "");
	else
		return false;

	if(steamId[0] == EOS || StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_ID_PENDING", false) ||
		StrEqual(steamId, "STEAM_ID_STOP_IGNORING_RETVALS", false) || StrEqual(steamId, "STEAM_1:0:0", false))
		return false;

	if(g_kvSavePlayer[client] == null)
		g_kvSavePlayer[client] = CreateKeyValues(tr("%s", steamId));
	if(g_mEquipData[client] == null)
		g_mEquipData[client] = CreateTrie();
	
	char name[MAX_NAME_LENGTH], ip[16], country[32], code[3];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientIP(client, ip, 16, true);
	GeoipCountry(ip, country, 32);
	GeoipCode2(ip, code);

	// 玩家信息
	g_kvSavePlayer[client].SetString("name", name);
	g_kvSavePlayer[client].SetString("ip", ip);
	g_kvSavePlayer[client].SetString("country", country);
	g_kvSavePlayer[client].SetString("country_code", code);
	g_kvSavePlayer[client].SetNum("deadline", GetTime());
	g_kvSavePlayer[client].SetNum("power", CalcPlayerPower(client));

	// 技能和属性
	g_kvSavePlayer[client].SetNum("skill_point", g_clSkillPoint[client]);
	g_kvSavePlayer[client].SetNum("angry_mode", g_clAngryMode[client]);
	g_kvSavePlayer[client].SetNum("skill_1", g_clSkill_1[client]);
	g_kvSavePlayer[client].SetNum("skill_2", g_clSkill_2[client]);
	g_kvSavePlayer[client].SetNum("skill_3", g_clSkill_3[client]);
	g_kvSavePlayer[client].SetNum("skill_4", g_clSkill_4[client]);
	g_kvSavePlayer[client].SetNum("skill_5", g_clSkill_5[client]);
	
	// 统计信息
	if(remember)
	{
		g_kvSavePlayer[client].SetNum("angry_point", g_clAngryPoint[client]);
		g_kvSavePlayer[client].SetNum("defib_used", g_ttDefibUsed[client]);
		g_kvSavePlayer[client].SetNum("revived_count", g_ttOtherRevived[client]);
		g_kvSavePlayer[client].SetNum("si_killed", g_ttSpecialKilled[client]);
		g_kvSavePlayer[client].SetNum("ci_killed", g_ttCommonKilled[client]);
		g_kvSavePlayer[client].SetNum("pills_given", g_ttGivePills[client]);
		g_kvSavePlayer[client].SetNum("team_protected", g_ttProtected[client]);
		g_kvSavePlayer[client].SetNum("zone_cleared", g_ttCleared[client]);
		g_kvSavePlayer[client].SetNum("painc_holdout", g_ttPaincEvent[client]);
		g_kvSavePlayer[client].SetNum("rescued_count", g_ttRescued[client]);
	}
	else
	{
		g_kvSavePlayer[client].SetNum("angry_point", 0);
		g_kvSavePlayer[client].SetNum("defib_used", 0);
		g_kvSavePlayer[client].SetNum("revived_count", 0);
		g_kvSavePlayer[client].SetNum("si_killed", 0);
		g_kvSavePlayer[client].SetNum("ci_killed", 0);
		g_kvSavePlayer[client].SetNum("pills_given", 0);
		g_kvSavePlayer[client].SetNum("team_protected", 0);
		g_kvSavePlayer[client].SetNum("zone_cleared", 0);
		g_kvSavePlayer[client].SetNum("painc_holdout", 0);
		g_kvSavePlayer[client].SetNum("rescued_count", 0);
	}
	
	// 装备相关
	g_kvSavePlayer[client].JumpToKey("equipment", true);
	for(int i = 0; i < 4; ++i)
		g_kvSavePlayer[client].SetNum(tr("eqm_%d", i), g_clCurEquip[client][i]);
	g_kvSavePlayer[client].GoBack();

	// 背包里的装备
	g_kvSavePlayer[client].JumpToKey("bage", true);
	
	StringMapSnapshot iterator = g_mEquipData[client].Snapshot();
	int size = iterator.Length;
	g_kvSavePlayer[client].SetNum("bage_items", size);
	
	for(int i = 0; i < size; ++i)
	{
		static char key[16];
		static EquipData_t data;
		if(!iterator.GetKey(i, key, sizeof(key)) || !g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
		{
			g_kvSavePlayer[client].DeleteKey(tr("item_%d", i));
			continue;
		}
		
		g_kvSavePlayer[client].JumpToKey(tr("item_%d", i), true);
		
		g_kvSavePlayer[client].SetNum("hashId", data.hashID);
		g_kvSavePlayer[client].SetNum("valid", data.valid);
		g_kvSavePlayer[client].SetNum("prefix", view_as<int>(data.prefix));
		g_kvSavePlayer[client].SetNum("parts", view_as<int>(data.parts));
		g_kvSavePlayer[client].SetNum("damage", data.damage);
		g_kvSavePlayer[client].SetNum("health", data.health);
		g_kvSavePlayer[client].SetNum("speed", data.speed);
		g_kvSavePlayer[client].SetNum("gravity", data.gravity);
		g_kvSavePlayer[client].SetNum("crit", data.crit);
		g_kvSavePlayer[client].SetNum("effect", data.effect);
		
		g_kvSavePlayer[client].GoBack();
	}
	
	// 保存到文件
	g_kvSavePlayer[client].Rewind();
	g_kvSavePlayer[client].ExportToFile(tr("%s/%s.txt", g_szSavePath, steamId));

	return true;
}

/*
public Action:Command_SavePoint(client, args)
{
	StatusSelectMenuFuncCD(client);
}

public Action:StatusSelectMenuFuncCD(client)
{
	if(GetClientTeam(client) != TEAM_SURVIVORS)
	{
		PrintToChat(client, "\x05*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "\x05*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(g_cdSaveCount[client] >= 99)
	{
		PrintToChat(client, "\x05*你所存点数已达到最大值100,无法再存点!");
		return Plugin_Handled;
	}

	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		PrintToChat(client, "\x05*必须站在地上才能使用这个功能");
		return Plugin_Handled;
	}

	g_cdSaveCount[client] ++;
	EmitSoundToAll(g_sndPortalERROR, client);
	GetClientAbsOrigin(client, cung_cdSaveCount[client][g_cdSaveCount[client]]);
	cung_cdSaveCount[client][g_cdSaveCount[client]][2] += 0.2;
	PrintToChat(client, "\x05*存点成功.你现有存点:\x04%d\x05.",(g_cdSaveCount[client] + 1));
	return Plugin_Handled;
}

public Action:Command_LoadPoint(client, args)
{
	StatusSelectMenuFuncDD(client);
}

public Action:StatusSelectMenuFuncDD(client)
{
	if(GetClientTeam(client) != TEAM_SURVIVORS)
	{
		PrintToChat(client, "*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(g_cdSaveCount[client] == -1)
	{
		PrintToChat(client, "*你还没有存点,请先存点!");
		return Plugin_Handled;
	}
	if(g_cdCanTeleport[client])
	{
		PrintToChat(client, "*你读点太快,两次读点间隔是30秒,请稍后再试!");
		return Plugin_Handled;
	}

	g_cdCanTeleport[client] = true;
	EmitSoundToAll(g_sndPortalFX, client);
	TeleportEntity(client, cung_cdSaveCount[client][g_cdSaveCount[client]], NULL_VECTOR, NULL_VECTOR);
	ShowParticle(cung_cdSaveCount[client][g_cdSaveCount[client]], "electrical_arc_01_system", 5.0);
	PrintToChat(client, "*读取最新存点成功.你现有存点:%d.",(g_cdSaveCount[client] + 1));
	CreateTimer(30.0, Event_Dudian, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action:Command_BackPoint(client, args)
{
	StatusSelectMenuFuncSC(client);
}

public Action:StatusSelectMenuFuncSC(client)
{
	if(GetClientTeam(client) != TEAM_SURVIVORS)
	{
		PrintToChat(client, "*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "*该功能只允许活着的生还者使用!");
		return Plugin_Handled;
	}
	if(g_cdSaveCount[client] <= 0)
	{
		PrintToChat(client, "*存点超过2时才能读取上一存点!");
		return Plugin_Handled;
	}
	if(g_cdCanTeleport[client])
	{
		PrintToChat(client, "*你读点太快,两次读点间隔是30秒,请稍后再试!");
		return Plugin_Handled;
	}

	g_cdCanTeleport[client] = true;
	EmitSoundToAll(g_sndPortalFX, client);
	g_cdSaveCount[client] --;
	TeleportEntity(client, cung_cdSaveCount[client][g_cdSaveCount[client]], NULL_VECTOR, NULL_VECTOR);
	ShowParticle(cung_cdSaveCount[client][g_cdSaveCount[client]], "electrical_arc_01_system", 5.0);
	PrintToChat(client, "*读取上一存点成功.你现有存点:%d.",(g_cdSaveCount[client] + 1));
	CreateTimer(30.0, Event_Dudian, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}
*/

void StatusSelectMenuFuncCS(int client)
{
	if(!IsValidAliveClient(client))
	{
		ReplyToCommand(client, "该功能只允许活着的玩家使用");
		return;
	}

	Panel menu = CreatePanel();
	menu.SetTitle("全体传送");
	menu.DrawText("确定将所有生还者传送到身边？");
	menu.DrawText(tr("需要 2 硬币，现有 %d 硬币", g_clSkillPoint[client]));
	menu.DrawText("警告：传送导致队友受伤会受到惩罚");
	menu.DrawItem("是");
	menu.DrawItem("否");
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("返回（Back）", ITEMDRAW_CONTROL);
	menu.DrawItem("退出（Exit）", ITEMDRAW_CONTROL);

	menu.Send(client, MenuHandler_TeamTeleport, MENU_TIME_FOREVER);
}

public int MenuHandler_TeamTeleport(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 1)
	{
		if(!IsPlayerAlive(client))
		{
			PrintToChat(client, "\x03[提示]\x01 你已经死了，无法使用这个功能。");
			return 0;
		}

		if(g_clSkillPoint[client] < 2)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusSelectMenuFuncCS(client);
			return 0;
		}

		if(!(GetEntityFlags(client) & FL_ONGROUND))
		{
			PrintToChat(client, "\x03[提示]\x01 请站在地上使用这个功能！");
			StatusSelectMenuFuncCS(client);
			return 0;
		}

		if(g_bHasTeleportActived)
		{
			PrintToChat(client, "\x03[提示]\x01 已经有人启动了这个功能，无法多次启动。");
			StatusSelectMenuFuncCS(client);
			return 0;
		}

		float position[3];
		GetClientAbsOrigin(client, position);
		g_bHasTeleportActived = true;

		DataPack data = CreateDataPack();
		data.WriteCell(client);
		data.WriteFloat(position[0]);
		data.WriteFloat(position[1]);
		data.WriteFloat(position[2]);

		GiveSkillPoint(client, -2);
		CreateTimer(5.0, Timer_TeamTeleport, data);
		StatusChooseMenuFunc(client);

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]\x05 %N\x04使用了\x03全员传送\x04,\x035秒后\x04所有队友将会传送到他身边开会...", client);
	}

	if(selected == 9)
		StatusChooseMenuFunc(client);

	return 0;
}

public Action Timer_TeamTeleport(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	g_bHasTeleportActived = false;
	pack.Reset();

	float position[3];
	int client = pack.ReadCell();
	position[0] = pack.ReadFloat();
	position[1] = pack.ReadFloat();
	position[2] = pack.ReadFloat();
	delete pack;

	if(!IsValidAliveClient(client))
	{
		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]\x04 由于 \x05%N\x04 已经挂了，本次传送失败！", client);
		return Plugin_Continue;
	}

	float tmpOrigin[3];
	g_stFallDamageKilled = 0;
	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == client || !IsValidAliveClient(i) || GetClientTeam(i) != team)
			continue;

		tmpOrigin[0] = position[0] + GetRandomFloat(0.1, 0.9);
		tmpOrigin[1] = position[1] + GetRandomFloat(0.1, 0.9);
		tmpOrigin[2] = position[2] + 1.0;

		TeleportEntity(i, tmpOrigin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		// ClientCommand(i, "play \"%s\"", SOUND_GOOD);
	}

	// ClientCommand(client, "play \"%s\"", SOUND_GOOD);
	EmitAmbientSound(SOUND_WARP, position, client, SNDLEVEL_HELICOPTER);
	PrintToChat(client, "\x03[\x05提示\x03]\x04 传送完毕。");
	CreateTimer(5.0, Timer_TeamTeleportCheck, client);

	return Plugin_Stop;
}

public void Event_PlayerFallDamage(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bHasTeleportActived)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	float damage = event.GetFloat("damage");

	if(!IsValidClient(client) || damage <= 0.0)
		return;

	if(damage >= GetEntProp(client, Prop_Data, "m_iHealth") + GetPlayerTempHealth(client))
	{
		++g_stFallDamageKilled;
		PrintToServer("玩家 %N 因为被传送而摔倒了", client);
	}
}

public Action Timer_TeamTeleportCheck(Handle timer, any client)
{
	g_bHasTeleportActived = false;

	if(!IsValidClient(client))
		return Plugin_Continue;

	if(g_stFallDamageKilled > 0)
	{
		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]\x04由于OP发现了 \x05%N\x04 之前恶意使用全员传送,扣除了他\x05硬币两块\x04作为警告.", client);

		GiveSkillPoint(client, -2);
		
		if(!IsFakeClient(client))
			ClientCommand(client, "play \"%s\"", SOUND_BAD);
	}

	g_stFallDamageKilled = 0;
	return Plugin_Stop;
}

/*
public Action OnClientCommand(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	char command[64];
	GetCmdArg(0, command, 64);
	if(StrContains(command, "admin", false) != -1 || StrEqual(command, "sm_cvar", false) ||
		StrEqual(command, "sm", false) || StrEqual(command, "sm_ban", false) ||
		StrEqual(command, "sm_kick", false) || StrEqual(command, "sm_rcon", false) ||
		StrEqual(command, "status", false) || StrEqual(command, "sm_help", false))
	{
		if(!(GetUserFlagBits(client) & (ADMFLAG_ROOT|ADMFLAG_KICK|ADMFLAG_BAN)))
		{
			LogMessage("玩家 %N 使用了命令：%s", client, command);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}
*/

/*
stock void PrintToLeft(int client, const char[] text, any ...)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	char buffer[255];
	VFormat(buffer, 255, text, 3);

	BfWrite bf = UserMessageToBfWrite(StartMessageOne("KeyHintText", client));
	bf.WriteByte(1);
	bf.WriteString(buffer);
	EndMessage();
}

stock void PrintToLeftAll(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);

	BfWrite bf = UserMessageToBfWrite(StartMessageAll("KeyHintText"));
	bf.WriteByte(1);
	bf.WriteString(buffer);
	EndMessage();
}
*/

public Action Command_Away(int client, const char[] command, int argc)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	// 冻结禁止闲置
	if(g_fFreezeTime[client] > GetEngineTime())
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Command_Scripted(int client, const char[] command, int argc)
{
	if(!IsValidClient(client) || argc < 1)
		return Plugin_Continue;

	char cmdArg[255];
	GetCmdArgString(cmdArg, 255);
	ReplaceStringEx(cmdArg, 255, "scripted_user_func", "", _, _, false);
	TrimString(cmdArg);
	ReplaceString(cmdArg, 255, " ", ",");

	CheatCommandEx(client, "script", "::UserConsoleCommand(GetPlayerFromUserID(%d),\"%s\")",
		GetClientUserId(client), cmdArg);

	return Plugin_Handled;
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	static char sayText[255];
	GetCmdArg(1, sayText, 255);

	if(g_pCvarAllow.BoolValue)
	{
		if(StrEqual(sayText, "lv", false) || StrEqual(sayText, "rpg", false))
		{
			StatusChooseMenuFunc(client);
			return Plugin_Handled;
		}

		if(StrEqual(sayText, "buy", false) || StrEqual(sayText, "shop", false))
		{
			StatusSelectMenuFuncBuy(client, false);
			return Plugin_Handled;
		}

		if(StrEqual(sayText, "rp", false) || StrEqual(sayText, "ldw", false))
		{
			StatusSelectMenuFuncRP(client);
			return Plugin_Handled;
		}
		
		/*
		if(StrEqual(sayText, "cd", false))
		{
			StatusSelectMenuFuncCD(client);
			return Plugin_Handled;
		}

		if(StrEqual(sayText, "dd", false))
		{
			StatusSelectMenuFuncDD(client);
			return Plugin_Handled;
		}
		*/
	}

	/*
	char cmdArg[255];
	GetCmdArgString(cmdArg, 255);
	ReplaceStringEx(cmdArg, 255, command, "", _, _, false);
	TrimString(cmdArg);
	ReplaceString(cmdArg, 255, " ", ",");

	CheatCommandEx(client, "script", "::InterceptChat(\"%s\",GetPlayerFromUserID(%d))",
		cmdArg, GetClientUserId(client));
	*/

	return Plugin_Continue;
}

public Action Command_Give(int client, const char[] command, int argc)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	if(GetCommandFlags(command) & FCVAR_CHEAT)
	{
		static ConVar sv_cheats;
		if(sv_cheats == null)
			sv_cheats = FindConVar("sv_cheats");
		if(sv_cheats != null && !sv_cheats.BoolValue)
			return Plugin_Continue;
	}
	
	char item[64];
	GetCmdArg(1, item, 64);
	
	if(StrEqual(item, "ammo", false))
	{
		AddAmmo(client, 999);
		return Plugin_Handled;
	}
	else if(StrEqual(item, "health", false))
	{
		// 得等命令执行完才会设置血量
		if(g_iRoundEvent == 19)
			RequestFrame(ApplyHealthSwap, client);
	}
	
	return Plugin_Continue;
}

public void ApplyHealthSwap(any client)
{
	if(!IsValidAliveClient(client) || GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
		return;
	
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		int health = L4D2Direct_GetPreIncapHealth(client) + L4D2Direct_GetPreIncapHealthBuffer(client) - 1;
		L4D2Direct_SetPreIncapHealthBuffer(client, health);
		L4D2Direct_SetPreIncapHealth(client, 1);
	}
	else
	{
		int health = GetEntProp(client, Prop_Data, "m_iHealth") + GetPlayerTempHealth(client) - 1;
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health * 1.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntProp(client, Prop_Data, "m_iHealth", 1);
	}
	
}

public Action:Command_Levelup(client, args)
{
	if(IsValidClient(client))
		StatusChooseMenuFunc(client);
	return Plugin_Handled;
}

public Action:Command_Shop(client, args)
{
	if(IsValidClient(client))
		StatusSelectMenuFuncBuy(client, false);
	return Plugin_Handled;
}

public Action Command_RandEvent(int client, int argc)
{
	if(IsValidClient(client))
		StatusSelectMenuFuncRP(client);
	return Plugin_Handled;
}

void StatusChooseMenuFunc(int client, int pg = -1)
{
	Menu menu = CreateMenu(MenuHandler_MainMenu);
	menu.SetTitle(tr("天启•天赋•装备系统(!lv)\n当前硬币：%d", g_clSkillPoint[client]));
	menu.AddItem("1", "一级天赋(1币)");
	menu.AddItem("2", "二级天赋(2币)");
	menu.AddItem("3", "三级天赋(3币)");
	menu.AddItem("4", "四级天赋(4币)");
	menu.AddItem("5", "五级天赋(5币)");
	menu.AddItem("6", "激活随机人品(抽奖)事件(!rp)");
	menu.AddItem("7", "商店菜单(!buy)");
	menu.AddItem("8", "怒气系统");
	menu.AddItem("9", "天启装备系统");
	menu.AddItem("10", "全员传送");
	menu.AddItem("11", "复活自己(限加入时)");
	menu.AddItem("12", "复活其他玩家");

	menu.ExitButton = true;
	menu.ExitBackButton = false;
	if(pg > -1)
		menu.DisplayAt(client, pg, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
	
	if(g_bDeadlineHint[client])
	{
		g_bDeadlineHint[client] = false;
		PrintHintText(client, "你的存档过期了。。。");
	}
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int selected)
{
	if(action != MenuAction_Select || !IsValidClient(client))
		return 0;

	switch(selected)
	{
		case 0:
			StatusSelectMenuFuncA(client);
		case 1:
			StatusSelectMenuFuncB(client);
		case 2:
			StatusSelectMenuFuncC(client);
		case 3:
			StatusSelectMenuFuncD(client);
		case 4:
			StatusSelectMenuFuncE(client);
		case 5:
			StatusSelectMenuFuncRP(client, true);
		case 6:
			StatusSelectMenuFuncBuy(client);
		case 7:
			StatusSelectMenuFuncNCJ(client);
		case 8:
			StatusSelectMenuFuncEqment(client);
		case 9:
			StatusSelectMenuFuncCS(client);
		case 10:
			FirstJoinRespawn(client);
		case 11:
			RespawnOther(client);
	}

	return 0;
}

public bool OnClientConnect(int client, char[] kickMessage, int msglen)
{
	if(IsFakeClient(client))
		return true;

	if(g_pCvarKickSteamId.IntValue)
	{
		char steamId[64];
		GetClientAuthId(client, AuthId_Steam2, steamId, 64, false);

		if(steamId[0] == EOS || StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_ID_PENDING", false) ||
			StrEqual(steamId, "STEAM_ID_STOP_IGNORING_RETVALS", false) || StrEqual(steamId, "STEAM_1:0:0", false))
		{
			FormatEx(kickMessage, msglen, "你的 SteamID 无效\n%s\n请更换或升级破解补丁", steamId);
			return false;
		}
	}

	return true;
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;

	g_bHasFirstJoin[client] = true;
	// g_bHasJumping[client] = false;
}

void RespawnOther(int client, bool msg = true)
{
	if(!IsValidClient(client))
		return;

	Menu menu = CreateMenu(MenuHandler_RespawnOther);
	menu.SetTitle("========= 复活队友 =========\n需要 3 硬币，现有 %d 硬币", g_clSkillPoint[client]);

	int team = GetClientTeam(client);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsPlayerAlive(i) || GetClientTeam(i) != team || i == client || g_timerRespawn[i] != null)
			continue;

		menu.AddItem(tr("%d", i), tr("%N", i));
	}

	if(menu.ItemCount <= 0)
	{
		delete menu;

		if(msg)
			PrintToChat(client, "\x03[提示]\x01 没有死亡的队友。");

		StatusChooseMenuFunc(client);
		return;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_RespawnOther(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	if(g_clSkillPoint[client] < 3)
	{
		PrintToChat(client, "\x03[提示]\x01 你的钱不够。");
		RespawnOther(client, false);
		return 0;
	}

	char info[8];
	menu.GetItem(selected, info, 8);
	int subject = StringToInt(info);
	if(!IsValidClient(subject))
	{
		PrintToChat(client, "\x03[提示]\x01 无效的选择：%s", info);
		RespawnOther(client, false);
		return 0;
	}

	if(IsPlayerAlive(subject))
	{
		PrintToChat(client, "\x03[提示]\x01 他还活着。");
		RespawnOther(client, false);
		return 0;
	}

	GiveSkillPoint(client, -3);
	g_timerRespawn[subject] = CreateTimer(3.0, Timer_RespawnPlayer, subject);
	PrintToChat(client, "\x03[提示]\x01 你选择的玩家 \x04%N\x01 将会在 \x053\x01 秒后复活。", subject);
	PrintHintText(subject, "有个神秘的队友对你进行续命\n你将会在 3 秒后活过来");

	RespawnOther(client, false);
	return 0;
}

void FirstJoinRespawn(int client)
{
	if(!IsValidClient(client))
		return;

	if(!g_bHasFirstJoin[client])
	{
		PrintToChat(client, "\x03[提示]\x01 这个功能只有刚加入游戏时处于死亡状态才能使用。");
		PrintToChat(client, "\x03[提示]\x01 并且只能使用一次。");
		return;
	}

	if(IsPlayerAlive(client))
	{
		g_bHasFirstJoin[client] = false;
		PrintToChat(client, "\x03[提示]\x01 你还活着。");
		return;
	}

	CreateConfirmPanel("========= 复活 =========", "你确定要复活么？\n需要 1 硬币，现有 %d 硬币",
		g_clSkillPoint[client]).Send(client, MenuHandler_Respawn, MENU_TIME_FOREVER);
}

public int MenuHandler_Respawn(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 9 || selected == 2)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(selected == 1)
	{
		if(!g_bHasFirstJoin[client])
		{
			PrintToChat(client, "\x03[提示]\x01 你并不是刚刚才加入游戏，无法使用这个功能。");
			StatusChooseMenuFunc(client);
			return 0;
		}

		if(IsPlayerAlive(client))
		{
			g_bHasFirstJoin[client] = false;
			PrintToChat(client, "\x03[提示]\x01 你还活着。");
			StatusChooseMenuFunc(client);
			return 0;
		}

		if(g_clSkillPoint[client] < 1)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			FirstJoinRespawn(client);
			return 0;
		}


		GiveSkillPoint(client, -1);
		g_bHasFirstJoin[client] = false;
		CreateTimer(3.0, Timer_RespawnPlayer, client);
		PrintToChat(client, "\x03[提示]\x01 你将会在 \x053\x01 秒后复活。");

		StatusChooseMenuFunc(client);
		return 0;
	}

	if(selected != 10)
		FirstJoinRespawn(client);
	
	return 0;
}

void StatusSelectMenuFuncBuy(int client, bool back = true)
{
	Menu menu = CreateMenu(MenuHandler_Shop);
	menu.SetTitle("商店菜单(!buy)\n全部两块 (现有 %d 硬币)", g_clSkillPoint[client]);

	menu.AddItem("smg_silenced katana upgradepack_explosive", "消音冲锋枪 + 武士刀 + 高爆弹药包");
	menu.AddItem("shotgun_chrome fireaxe upgradepack_incendiary", "铁喷 + 消防斧 + 燃烧弹药包");
	menu.AddItem("rifle_ak47 machete molotov", "AK47 + 开山刀 + 火瓶");
	menu.AddItem("autoshotgun pistol_magnum pipe_bomb", "连喷(一代) + 马格南 + 土制炸弹");
	menu.AddItem("sniper_scout crowbar firework_crate", "鸟狙(Scout) + 物理学圣剑(撬棍) + 烟花盒");
	menu.AddItem("sniper_awp knife gascan", "大鸟(AWP) + 小刀 + 汽油桶");
	menu.AddItem("rifle_m60 chainsaw vomitjar", "机枪(M60) + 电锯 + 胆汁");
	menu.AddItem("grenade_launcher cricket_bat vomitjar", "榴弹 + 板球棒 + 胆汁");
	menu.AddItem("first_aid_kit adrenaline ammo", "医疗包 + 针筒 + 补充弹药");
	menu.AddItem("defibrillator pain_pills ammo", "电击器 + 药丸 + 补充弹药");
	// menu.AddItem("health", "回血/自救");

	menu.ExitButton = true;
	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Shop(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidAliveClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	if(g_clSkillPoint[client] < 2)
	{
		PrintToChat(client, "\x03[提示]\x01 你的硬币不够。");
		StatusSelectMenuFuncBuy(client, menu.ExitBackButton);
		return 0;
	}

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "\x03[提示]\x01 你已经死了。");
		StatusSelectMenuFuncBuy(client, menu.ExitBackButton);
		return 0;
	}

	char info[128], item[4][32];
	menu.GetItem(selected, info, 64);
	int count = ExplodeString(info, " ", item, 4, 32);
	for(int i = 0; i < count; ++i)
	{
		if(item[i][0] == EOS)
			continue;
		
		if(StrEqual(item[i], "ammo", false))
			AddAmmo(client, 999);
		else
			CheatCommand(client, "give", item[i]);
	}

	GiveSkillPoint(client, -2);
	PrintToChat(client, "\x03[提示]\x01 完成。");
	StatusSelectMenuFuncBuy(client, menu.ExitBackButton);
	return 0;
}

void StatusSelectMenuFuncNCJ(int client)
{
	if(!g_pCvarAS.BoolValue)
	{
		PrintToChat(client, "\x03[提示]\x01 功能已禁用。");
		StatusChooseMenuFunc(client);
		return;
	}
	
	Menu menu = CreateMenu(MenuHandler_Angry);
	menu.SetTitle("怒气系统\n怒气值：%d/100", g_clAngryPoint[client]);
	menu.AddItem("1", mps("王者之仁德",g_clAngryMode[client]==1));
	menu.AddItem("2", mps("霸者之号令",g_clAngryMode[client]==2));
	menu.AddItem("3", mps("智者之教诲",g_clAngryMode[client]==3));
	menu.AddItem("4", mps("强者之霸气",g_clAngryMode[client]==4));
	menu.AddItem("5", mps("热血沸腾",g_clAngryMode[client]==5));
	menu.AddItem("6", mps("背水一战",g_clAngryMode[client]==6));
	menu.AddItem("7", mps("嗜血如命",g_clAngryMode[client]==7));

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Angry(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	switch(selected)
	{
		case 0:
		{
			if(g_clAngryMode[client] != 1)
			{
				g_clAngryMode[client] = 1;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03王者之仁德\x01,效果:\x03附近队友恢复满血(倒地/被控除外)\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 1:
		{
			if(g_clAngryMode[client] != 2)
			{
				g_clAngryMode[client] = 2;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03霸者之号令\x01,效果:\x03全员暴击率+500,持续40秒\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 2:
		{
			if(g_clAngryMode[client] != 3)
			{
				g_clAngryMode[client] = 3;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03智者之教诲\x01,效果:\x03附近队友硬币+1\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 3:
		{
			if(g_clAngryMode[client] != 4)
			{
				g_clAngryMode[client] = 4;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03强者之霸气\x01,效果:\x03附近特感受到2500伤害\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 4:
		{
			if(g_clAngryMode[client] != 5)
			{
				g_clAngryMode[client] = 5;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03热血沸腾\x01,效果:\x03附近队友兴奋,持续50秒\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 5:
		{
			if(g_clAngryMode[client] != 6)
			{
				g_clAngryMode[client] = 6;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03背水一战\x01,效果:\x03自身HP减半,全员获得无限燃烧子弹,持续60秒\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
		case 6:
		{
			if(g_clAngryMode[client] != 7)
			{
				g_clAngryMode[client] = 7;
				PrintToChat(client, "\x03[提示]\x01 你选择的是:\x03嗜血如命\x01,效果:\x03全员获得嗜血(主+近)天赋,持续75秒\x01.");
			}
			else
			{
				g_clAngryMode[client] = 0;
				PrintToChat(client, "\x03[提示]\x01 已取消选择。");
			}
			
			StatusSelectMenuFuncNCJ(client);
		}
	}

	return 0;
}

void StatusSelectMenuFuncA(int client, int page = -1)
{
	Menu menu = CreateMenu(MenuHandler_Skill);
	menu.SetTitle(tr("一级天赋(1硬币)\n你现在有 %d 硬币", g_clSkillPoint[client]));

	menu.AddItem(tr("1_%d",SKL_1_MaxHealth), mps("「强身」血量上限+50",(g_clSkill_1[client]&SKL_1_MaxHealth)));
	menu.AddItem(tr("1_%d",SKL_1_Movement), mps("「疾步」移动速度+10%",(g_clSkill_1[client]&SKL_1_Movement)));
	menu.AddItem(tr("1_%d",SKL_1_ReviveHealth), mps("「自愈」倒地救起血量+50",(g_clSkill_1[client]&SKL_1_ReviveHealth)));
	menu.AddItem(tr("1_%d",SKL_1_DmgExtra), mps("「凶狠」暴击率+5",(g_clSkill_1[client]&SKL_1_DmgExtra)));
	menu.AddItem(tr("1_%d",SKL_1_MagnumInf), mps("「手控」手枪无限子弹",(g_clSkill_1[client]&SKL_1_MagnumInf)));
	menu.AddItem(tr("1_%d",SKL_1_Gravity), mps("「轻盈」跳得更高",(g_clSkill_1[client]&SKL_1_Gravity)));
	menu.AddItem(tr("1_%d",SKL_1_Firendly), mps("「谨慎」避免队友伤害",(g_clSkill_1[client]&SKL_1_Firendly)));
	menu.AddItem(tr("1_%d",SKL_1_RapidFire), mps("「手速」手枪自动连发",(g_clSkill_1[client]&SKL_1_RapidFire)));
	menu.AddItem(tr("1_%d",SKL_1_Armor), mps("「护甲」复活护甲+100",(g_clSkill_1[client]&SKL_1_Armor)));
	menu.AddItem(tr("1_%d",SKL_1_NoRecoil), mps("「稳定」自带激光/无后坐力",(g_clSkill_1[client]&SKL_1_NoRecoil)));
	menu.AddItem(tr("1_%d",SKL_1_KeepClip), mps("「保守」保留弹匣/升级叠加补子弹/填装可中断",(g_clSkill_1[client]&SKL_1_KeepClip)));
	menu.AddItem(tr("1_%d",SKL_1_ReviveBlock), mps("「坚毅」拉起不被打断",(g_clSkill_1[client]&SKL_1_ReviveBlock)));
	menu.AddItem(tr("1_%d",SKL_1_DisplayHealth), mps("「察觉」显示伤害/刷特提示",(g_clSkill_1[client]&SKL_1_DisplayHealth)));
	menu.AddItem(tr("1_%d",SKL_1_ShoveFatigue), mps("「充沛」推不会疲劳",(g_clSkill_1[client]&SKL_1_ShoveFatigue)));

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(page > -1 && page < menu.ItemCount)
		menu.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

void StatusSelectMenuFuncB(int client, int page = -1)
{
	Menu menu = CreateMenu(MenuHandler_Skill);
	menu.SetTitle(tr("二级天赋(2硬币)\n你现在有 %d 硬币", g_clSkillPoint[client]));

	menu.AddItem(tr("2_%d",SKL_2_Chainsaw), mps("「狂锯」无限电(链)锯燃油",(g_clSkill_2[client]&SKL_2_Chainsaw)));
	menu.AddItem(tr("2_%d",SKL_2_Excited), mps("「热血」爆头杀死特感1/3几率兴奋",(g_clSkill_2[client]&SKL_2_Excited)));
	menu.AddItem(tr("2_%d",SKL_2_PainPills), mps("「嗜药」每120秒获得一个药丸",(g_clSkill_2[client]&SKL_2_PainPills)));
	menu.AddItem(tr("2_%d",SKL_2_FullHealth), mps("「永康」每300秒恢复全血",(g_clSkill_2[client]&SKL_2_FullHealth)));
	menu.AddItem(tr("2_%d",SKL_2_Defibrillator), mps("「电疗」每200秒获得一个电击器",(g_clSkill_2[client]&SKL_2_Defibrillator)));
	menu.AddItem(tr("2_%d",SKL_2_HealBouns), mps("「擅医」打包治疗量+50",(g_clSkill_2[client]&SKL_2_HealBouns)));
	menu.AddItem(tr("2_%d",SKL_2_PipeBomb), mps("「爆破」每100秒获得一个土制",(g_clSkill_2[client]&SKL_2_PipeBomb)));
	menu.AddItem(tr("2_%d",SKL_2_SelfHelp), mps("「顽强」倒地1/4几率自救",(g_clSkill_2[client]&SKL_2_SelfHelp)));
	menu.AddItem(tr("2_%d",SKL_2_Defensive), mps("「自守」倒地推开特感",(g_clSkill_2[client]&SKL_2_Defensive)));
	menu.AddItem(tr("2_%d",SKL_2_DoubleJump), mps("「踏空」允许二级跳",(g_clSkill_2[client]&SKL_2_DoubleJump)));
	menu.AddItem(tr("2_%d",SKL_2_ProtectiveSuit), mps("「防化服」胆汁时间减半",(g_clSkill_2[client]&SKL_2_ProtectiveSuit)));
	menu.AddItem(tr("2_%d",SKL_2_Magnum), mps("「炮台」倒地马格南",(g_clSkill_2[client]&SKL_2_Magnum)));
	menu.AddItem(tr("2_%d",SKL_2_LadderGun), mps("「固定」梯子上掏枪",(g_clSkill_2[client]&SKL_2_LadderGun)));
	
	if(!g_bIsPluginCrawling && g_hCvarIncapCrawling.BoolValue)
		menu.AddItem(tr("2_%d",SKL_2_IncapCrawling), mps("「爬行」倒地爬行",(g_clSkill_2[client]&SKL_2_IncapCrawling)));
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(page > -1 && page < menu.ItemCount)
		menu.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

void StatusSelectMenuFuncC(int client, int page = -1)
{
	Menu menu = CreateMenu(MenuHandler_Skill);
	menu.SetTitle(tr("三级天赋(3硬币)\n你现在有 %d 硬币", g_clSkillPoint[client]));

	menu.AddItem(tr("3_%d",SKL_3_Sacrifice), mps("「牺牲」死亡时1/3几率带走全图感染者",(g_clSkill_3[client]&SKL_3_Sacrifice)));
	menu.AddItem(tr("3_%d",SKL_3_Respawn), mps("「永生」死亡时复活几率+1/10",(g_clSkill_3[client]&SKL_3_Respawn)));
	menu.AddItem(tr("3_%d",SKL_3_IncapFire), mps("「纵火」倒地点燃攻击者和周围普感",(g_clSkill_3[client]&SKL_3_IncapFire)));
	menu.AddItem(tr("3_%d",SKL_3_ReviveBonus), mps("「妙手」帮助队友随机获得奖励",(g_clSkill_3[client]&SKL_3_ReviveBonus)));
	menu.AddItem(tr("3_%d",SKL_3_Freeze), mps("「释冰」倒地冻结攻击者和周围特感",(g_clSkill_3[client]&SKL_3_Freeze)));
	menu.AddItem(tr("3_%d",SKL_3_Kickback), mps("「轰炸」暴击时1/3几率附加击退效果",(g_clSkill_3[client]&SKL_3_Kickback)));
	menu.AddItem(tr("3_%d",SKL_3_GodMode), mps("「无敌」每80秒获得9秒无敌时间",(g_clSkill_3[client]&SKL_3_GodMode)));
	menu.AddItem(tr("3_%d",SKL_3_SelfHeal), mps("「暴疗」每200秒恢复80HP(可转换)",(g_clSkill_3[client]&SKL_3_SelfHeal)));
	menu.AddItem(tr("3_%d",SKL_3_BunnyHop), mps("「灵活」自动连跳",(g_clSkill_3[client]&SKL_3_BunnyHop)));
	menu.AddItem(tr("3_%d",SKL_3_Parachute), mps("「降落」按住E可以缓慢落地",(g_clSkill_3[client]&SKL_3_Parachute)));
	menu.AddItem(tr("3_%d",SKL_3_MoreAmmo), mps("「储备」更多携带弹药",(g_clSkill_3[client]&SKL_3_MoreAmmo)));
	menu.AddItem(tr("3_%d",SKL_3_TempSanctuary), mps("「守备」受到伤害时优先使用虚血承担",(g_clSkill_3[client]&SKL_3_TempSanctuary)));
	menu.AddItem(tr("3_%d",SKL_3_Ricochet), mps("「跳弹」子弹击中墙壁可以反弹",(g_clSkill_3[client]&SKL_3_Ricochet)));
	menu.AddItem(tr("3_%d",SKL_3_Accurate), mps("「瞄准」第一枪一定会暴击",(g_clSkill_3[client]&SKL_3_Accurate)));

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(page > -1 && page < menu.ItemCount)
		menu.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

void StatusSelectMenuFuncD(int client, int page = -1)
{
	Menu menu = CreateMenu(MenuHandler_Skill);
	menu.SetTitle(tr("四级天赋(4硬币)\n你现在有 %d 硬币", g_clSkillPoint[client]));

	menu.AddItem(tr("4_%d",SKL_4_ClawHeal), mps("「坚韧」被坦克击中恢复HP",(g_clSkill_4[client]&SKL_4_ClawHeal)));
	menu.AddItem(tr("4_%d",SKL_4_DmgExtra), mps("「狂妄」暴击率+20",(g_clSkill_4[client]&SKL_4_DmgExtra)));
	menu.AddItem(tr("4_%d",SKL_4_DuckShover), mps("「霸气」蹲下推弹开周围特感",(g_clSkill_4[client]&SKL_4_DuckShover)));
	menu.AddItem(tr("4_%d",SKL_4_FastFired), mps("「疾射」射速增加",(g_clSkill_4[client]&SKL_4_FastFired)));
	menu.AddItem(tr("4_%d",SKL_4_SniperExtra), mps("「神狙」AWP射速加快无限备弹",(g_clSkill_4[client]&SKL_4_SniperExtra)));
	menu.AddItem(tr("4_%d",SKL_4_FastReload), mps("「嗜弹」上弹速度提升",(g_clSkill_4[client]&SKL_4_FastReload)));
	menu.AddItem(tr("4_%d",SKL_4_MachStrafe), mps("「扫射」M60无限子弹",(g_clSkill_4[client]&SKL_4_MachStrafe)));
	menu.AddItem(tr("4_%d",SKL_4_MoreDmgExtra), mps("「残忍」暴击伤害上限+200",(g_clSkill_4[client]&SKL_4_MoreDmgExtra)));
	menu.AddItem(tr("4_%d",SKL_4_Defensive), mps("「御策」被普感锤伤害减半或反伤",(g_clSkill_4[client]&SKL_4_Defensive)));
	menu.AddItem(tr("4_%d",SKL_4_ClipSize), mps("「弹匣」弹匣容量增加",(g_clSkill_4[client]&SKL_4_ClipSize)));
	
	if(g_pfnOnSwingStart != null)
		menu.AddItem(tr("4_%d",SKL_4_Shove), mps("「力大」可以推牛/倒地可以推",(g_clSkill_4[client]&SKL_4_Shove)));
	else
		menu.AddItem(tr("4_%d",SKL_4_Shove), mps("「力大」可以推牛",(g_clSkill_4[client]&SKL_4_Shove)));
	
	menu.AddItem(tr("4_%d",SKL_4_TempRespite), mps("「喘息」虚血会慢慢恢复为实血",(g_clSkill_4[client]&SKL_4_TempRespite)));
	menu.AddItem(tr("4_%d",SKL_4_Terror), mps("「支配」写实显示光圈/胆汁会让特感叛变",(g_clSkill_4[client]&SKL_4_Terror)));
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(page > -1 && page < menu.ItemCount)
		menu.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

void StatusSelectMenuFuncE(int client, int page = -1)
{
	Menu menu = CreateMenu(MenuHandler_Skill);
	menu.SetTitle(tr("五级天赋(5硬币)\n你现在有 %d 硬币", g_clSkillPoint[client]));

	menu.AddItem(tr("5_%d",SKL_5_FireBullet), mps("「烈火」主武器1/4几率发射燃烧子弹",(g_clSkill_5[client]&SKL_5_FireBullet)));
	menu.AddItem(tr("5_%d",SKL_5_ExpBullet), mps("「碎骨」主武器1/4几率发射高爆子弹",(g_clSkill_5[client]&SKL_5_ExpBullet)));
	menu.AddItem(tr("5_%d",SKL_5_RetardBullet), mps("「冰封」主武器/近战击中特感有几率减速",(g_clSkill_5[client]&SKL_5_RetardBullet)));
	menu.AddItem(tr("5_%d",SKL_5_DmgExtra), mps("「狂暴」牺牲暴击伤害大大增加暴击率",(g_clSkill_5[client]&SKL_5_DmgExtra)));
	menu.AddItem(tr("5_%d",SKL_5_Vampire), mps("「嗜血」近战击中特感时有几率吸血",(g_clSkill_5[client]&SKL_5_Vampire)));
	menu.AddItem(tr("5_%d",SKL_5_InfAmmo), mps("「节省」开枪有1/3几率回收子弹",(g_clSkill_5[client]&SKL_5_InfAmmo)));
	menu.AddItem(tr("5_%d",SKL_5_Overkill), mps("「精准」对普感1/4几率暴击",(g_clSkill_5[client]&SKL_5_Overkill)));
	menu.AddItem(tr("5_%d",SKL_5_RocketDude), mps("「火箭」允许榴弹跳",(g_clSkill_5[client]&SKL_5_RocketDude)));
	menu.AddItem(tr("5_%d",SKL_5_ClipHold), mps("「持久」冲锋枪25连射后改为消耗备用弹药",(g_clSkill_5[client]&SKL_5_ClipHold)));
	menu.AddItem(tr("5_%d",SKL_5_Sneak), mps("「潜行」降低被特感发现的几率",(g_clSkill_5[client]&SKL_5_Sneak)));
	
	if(g_tMeleeRange != null && g_hDetourTestMeleeSwingCollision != null)
		menu.AddItem(tr("5_%d",SKL_5_MeleeRange), mps("「刀客」增加近战武器攻击范围",(g_clSkill_5[client]&SKL_5_MeleeRange)));
	
	if(g_tShoveRange != null && g_hDetourTestSwingCollision != null)
		menu.AddItem(tr("5_%d",SKL_5_ShoveRange), mps("「枪托」增加推的攻击范围",(g_clSkill_5[client]&SKL_5_ShoveRange)));
	
	menu.AddItem(tr("5_%d",SKL_5_TempRegen), mps("「抗性」受伤消耗实血时有1/3几率恢复等量虚血",(g_clSkill_5[client]&SKL_5_TempRegen)));
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	if(page > -1 && page < menu.ItemCount)
		menu.DisplayAt(client, page, MENU_TIME_FOREVER);
	else
		menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Skill(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	char info[32], display[128], exploded[2][16];
	menu.GetItem(selected, info, 32, _, display, 128);
	ExplodeString(info, "_", exploded, 2, 16);
	
	bool free = false;
	int level = StringToInt(exploded[0]);
	int skill = StringToInt(exploded[1]);
	if(level == 0 || skill == 0)
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%s->%s|%s", info, exploded[0], exploded[1]);
		StatusChooseMenuFunc(client);
		return 0;
	}
	
	if((level == 1 && !(g_clSkill_1[client] & skill)) || (level == 2 && !(g_clSkill_2[client] & skill)) ||
		(level == 3 && !(g_clSkill_3[client] & skill)) || (level == 4 && !(g_clSkill_4[client] & skill)) ||
		(level == 5 && !(g_clSkill_5[client] & skill)))
	{
		Call_StartForward(g_fwOnSkillLearn);
		Call_PushCell(client);
		
		int refLevel = level;
		Call_PushCellRef(refLevel);
		
		int refSkill = skill;
		Call_PushCellRef(refSkill);
		
		bool refFree = free;
		Call_PushCellRef(refFree);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return 0;
		
		if(refResult == Plugin_Changed)
		{
			level = refLevel;
			skill = refSkill;
			free = refFree;
		}
	}
	
	switch(level)
	{
		case 1:
		{
			if(g_clSkill_1[client] & skill)
			{
				// PrintToChat(client, "\x03[提示]\x01 你已经拥有这个技能了。");
				// StatusSelectMenuFuncA(client);

				Menu m = CreateMenu(MenuHandler_CancelSkill);
				m.SetTitle("【放弃技能】\n你确定放弃技能：\n%s", display);
				m.AddItem(info, "确定");
				m.AddItem(info, "取消");

				m.ExitButton = true;
				m.ExitBackButton = true;
				m.Display(client, MENU_TIME_FOREVER);

				return 0;
			}

			if(!free && g_clSkillPoint[client] < 1)
			{
				PrintToChat(client, "\x03[提示]\x01 硬币不够(需要1币)。");
				StatusSelectMenuFuncA(client, menu.Selection);
				return 0;
			}

			g_clSkill_1[client] |= skill;
			
			if(!free)
				GiveSkillPoint(client, -1);
			
			StatusSelectMenuFuncA(client, menu.Selection);
		}
		case 2:
		{
			if(g_clSkill_2[client] & skill)
			{
				// PrintToChat(client, "\x03[提示]\x01 你已经拥有这个技能了。");
				// StatusSelectMenuFuncB(client);

				Menu m = CreateMenu(MenuHandler_CancelSkill);
				m.SetTitle("【放弃技能】\n你确定放弃技能：\n%s", display);
				m.AddItem(info, "确定");
				m.AddItem(info, "取消");

				m.ExitButton = true;
				m.ExitBackButton = true;
				m.Display(client, MENU_TIME_FOREVER);

				return 0;
			}

			if(!free && g_clSkillPoint[client] < 2)
			{
				PrintToChat(client, "\x03[提示]\x01 硬币不够(需要2币)。");
				StatusSelectMenuFuncB(client, menu.Selection);
				return 0;
			}

			g_clSkill_2[client] |= skill;
			
			if(!free)
				GiveSkillPoint(client, -2);
			
			StatusSelectMenuFuncB(client, menu.Selection);
		}
		case 3:
		{
			if(g_clSkill_3[client] & skill)
			{
				// PrintToChat(client, "\x03[提示]\x01 你已经拥有这个技能了。");
				// StatusSelectMenuFuncC(client);

				Menu m = CreateMenu(MenuHandler_CancelSkill);
				m.SetTitle("【放弃技能】\n你确定放弃技能：\n%s", display);
				m.AddItem(info, "确定");
				m.AddItem(info, "取消");

				m.ExitButton = true;
				m.ExitBackButton = true;
				m.Display(client, MENU_TIME_FOREVER);

				return 0;
			}

			if(!free && g_clSkillPoint[client] < 3)
			{
				PrintToChat(client, "\x03[提示]\x01 硬币不够(需要3币)。");
				StatusSelectMenuFuncC(client, menu.Selection);
				return 0;
			}

			g_clSkill_3[client] |= skill;
			
			if(!free)
				GiveSkillPoint(client, -3);
			
			StatusSelectMenuFuncC(client, menu.Selection);
		}
		case 4:
		{
			if(g_clSkill_4[client] & skill)
			{
				// PrintToChat(client, "\x03[提示]\x01 你已经拥有这个技能了。");
				// StatusSelectMenuFuncD(client);

				Menu m = CreateMenu(MenuHandler_CancelSkill);
				m.SetTitle("【放弃技能】\n你确定放弃技能：\n%s", display);
				m.AddItem(info, "确定");
				m.AddItem(info, "取消");

				m.ExitButton = true;
				m.ExitBackButton = true;
				m.Display(client, MENU_TIME_FOREVER);

				return 0;
			}

			if(!free && g_clSkillPoint[client] < 4)
			{
				PrintToChat(client, "\x03[提示]\x01 硬币不够(需要4币)。");
				StatusSelectMenuFuncD(client, menu.Selection);
				return 0;
			}

			g_clSkill_4[client] |= skill;

			if(!free)
				GiveSkillPoint(client, -4);
			
			StatusSelectMenuFuncD(client, menu.Selection);
		}
		case 5:
		{
			if(g_clSkill_5[client] & skill)
			{
				// PrintToChat(client, "\x03[提示]\x01 你已经拥有这个技能了。");
				// StatusSelectMenuFuncE(client);

				Menu m = CreateMenu(MenuHandler_CancelSkill);
				m.SetTitle("【放弃技能】\n你确定放弃技能：\n%s", display);
				m.AddItem(info, "确定");
				m.AddItem(info, "取消");

				m.ExitButton = true;
				m.ExitBackButton = true;
				m.Display(client, MENU_TIME_FOREVER);

				return 0;
			}

			if(!free && g_clSkillPoint[client] < 5)
			{
				PrintToChat(client, "\x03[提示]\x01 硬币不够(需要5币)。");
				StatusSelectMenuFuncE(client, menu.Selection);
				return 0;
			}

			g_clSkill_5[client] |= skill;

			if(!free)
				GiveSkillPoint(client, -5);
			
			StatusSelectMenuFuncE(client, menu.Selection);
		}
	}

	RegPlayerHook(client, false);
	PrintToChat(client, "\x03[提示]\x01 技能获得：\x05%s\x01。", display);
	PrintToServer("玩家 %N 选择了 %s", client, display);
	OnSkillAttach(client, level, skill);
	return 0;
}

public int MenuHandler_CancelSkill(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	char info[32], display[128], exploded[2][16];
	menu.GetItem(0, info, 32, _, display, 128);
	ExplodeString(info, "_", exploded, 2, 16);

	int level = StringToInt(exploded[0]);
	int skill = StringToInt(exploded[1]);
	if(level == 0 || skill == 0)
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%s->%s|%s", info, exploded[0], exploded[1]);
		StatusChooseMenuFunc(client);
		return 0;
	}
	
	{
		Call_StartForward(g_fwOnSkillForget);
		Call_PushCell(client);
		
		int refLevel = level;
		Call_PushCellRef(refLevel);
		
		int refSkill = skill;
		Call_PushCellRef(refSkill);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return 0;
		
		if(refResult == Plugin_Changed)
		{
			level = refLevel;
			skill = refSkill;
		}
	}
	
	if(selected == 0)
	{
		switch(level)
		{
			case 1:
			{
				if(!(g_clSkill_1[client] & skill))
				{
					PrintToChat(client, "\x03[提示]\x01 你没有这个技能。");
					StatusSelectMenuFuncA(client);
					return 0;
				}

				g_clSkill_1[client] &= ~skill;
				PrintToChat(client, "\x03[提示]\x01 放弃技能成功。");
				StatusSelectMenuFuncA(client);
			}
			case 2:
			{
				if(!(g_clSkill_2[client] & skill))
				{
					PrintToChat(client, "\x03[提示]\x01 你没有这个技能。");
					StatusSelectMenuFuncB(client);
					return 0;
				}

				g_clSkill_2[client] &= ~skill;
				PrintToChat(client, "\x03[提示]\x01 放弃技能成功。");
				StatusSelectMenuFuncB(client);
			}
			case 3:
			{
				if(!(g_clSkill_3[client] & skill))
				{
					PrintToChat(client, "\x03[提示]\x01 你没有这个技能。");
					StatusSelectMenuFuncC(client);
					return 0;
				}

				g_clSkill_3[client] &= ~skill;
				// GiveSkillPoint(client, 1);
				PrintToChat(client, "\x03[提示]\x01 放弃技能成功。");
				StatusSelectMenuFuncC(client);
			}
			case 4:
			{
				if(!(g_clSkill_4[client] & skill))
				{
					PrintToChat(client, "\x03[提示]\x01 你没有这个技能。");
					StatusSelectMenuFuncD(client);
					return 0;
				}

				g_clSkill_4[client] &= ~skill;
				// GiveSkillPoint(client, 1);
				PrintToChat(client, "\x03[提示]\x01 放弃技能成功。");
				StatusSelectMenuFuncD(client);
			}
			case 5:
			{
				if(!(g_clSkill_5[client] & skill))
				{
					PrintToChat(client, "\x03[提示]\x01 你没有这个技能。");
					StatusSelectMenuFuncE(client);
					return 0;
				}

				g_clSkill_5[client] &= ~skill;
				// GiveSkillPoint(client, 2);
				PrintToChat(client, "\x03[提示]\x01 放弃技能成功。");
				StatusSelectMenuFuncE(client);
			}
		}
	}
	else if(selected == 1)
	{
		switch(level)
		{
			case 1:
				StatusSelectMenuFuncA(client);
			case 2:
				StatusSelectMenuFuncB(client);
			case 3:
				StatusSelectMenuFuncC(client);
			case 4:
				StatusSelectMenuFuncD(client);
			case 5:
				StatusSelectMenuFuncE(client);
		}
	}
	
	RegPlayerHook(client, false);
	return 0;
}

void StatusSelectMenuFuncEqment(int client)
{
	Panel menu = CreatePanel();
	menu.SetTitle("天启•装备系统");
	menu.DrawText(tr("当前天启：%s", g_szRoundEvent));
	menu.DrawItem("装备栏");
	menu.DrawItem("打开天启幸运箱");
	menu.DrawItem("打开装备幸运箱");
	menu.DrawItem("天启装备操作说明");
	menu.DrawItem("查看当前属性统计");
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("返回（Back）", ITEMDRAW_CONTROL);
	menu.DrawItem("退出（Exit）", ITEMDRAW_CONTROL);

	menu.Send(client, MenuHandler_EquipMain, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipMain(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 9)
	{
		StatusChooseMenuFunc(client);
		return 0;
	}

	switch(selected)
	{
		case 1: StatusEqmFuncA(client, true);
		case 2: StatusEqmFuncB(client);
		case 3: StatusEqmFuncC(client);
		case 4: StatusEqmFuncD(client);
		case 5:
		{
			int damage, health, speed, gravity, crit;
			CalcPlayerAttr(client, damage, health, speed, gravity, crit, true);
			
			PrintToChat(client,
				"\x05[属性]\x01 伤害+\x03%d％\x01 HP+\x03%d％\x01 速度+\x03%d％\x01 跳跃+\x03%d％\x01 暴击+\x03%d‰\x01 战斗力=\x03%d\x01.",
				damage,health,speed,gravity,crit,CalcPlayerPower(client)
			);
			
			StatusSelectMenuFuncEqment(client);
		}
	}

	return 0;
}

int CalcPlayerPower(int client)
{
	if(!IsValidClient(client))
		return -1;
	
	int power = 0;
	
	for(int i = 0; i < 31; ++i)
		if(g_clSkill_1[client] & (1 << i))
			power += 100;
	for(int i = 0; i < 31; ++i)
		if(g_clSkill_2[client] & (1 << i))
			power += 200;
	for(int i = 0; i < 31; ++i)
		if(g_clSkill_3[client] & (1 << i))
			power += 300;
	for(int i = 0; i < 31; ++i)
		if(g_clSkill_4[client] & (1 << i))
			power += 400;
	for(int i = 0; i < 31; ++i)
		if(g_clSkill_5[client] & (1 << i))
			power += 500;
	
	for(int i = 0; i < sizeof(g_clCurEquip[]); ++i)
	{
		if(!g_clCurEquip[client][i])
			continue;
		
		static char key[16];
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		
		static EquipData_t data;
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
			continue;
		
		if(data.effect > 0)
			power += 250;
	}
	
	int damage, health, speed, gravity, crit;
	CalcPlayerAttr(client, damage, health, speed, gravity, crit, true);
	
	power += damage * 5;
	power += health * 8;
	power += speed * 6;
	power += gravity * 3;
	power += crit * 4;
	
	if(g_clSkillPoint[client] > 0)
		power += g_clSkillPoint[client] * 25;
	
	return power;
}

int CalcEquipPower(EquipData_t data)
{
	int power = 0;
	
	if(data.effect > 0)
		power += 250;
	if(data.effect == 8)
		power += 5 * 4;
	
	/*
	if(data.prefix == EquipPrefix_Lucky)
		power += 2 * 4;
	*/
	
	power += data.damage * 5;
	power += data.health * 8;
	power += data.speed * 6;
	power += data.gravity * 3;
	power += data.crit * 4;
	
	return power;
}

void StatusEqmFuncD(int client)
{
	Panel menu = CreatePanel();
	menu.SetTitle("========= 天启装备操作说明 =========");
	menu.DrawItem("锻造装备类型说明");
	menu.DrawItem("锻造装备属性说明");
	menu.DrawItem("打开天启幸运箱说明");
	menu.DrawItem("打开装备幸运箱说明");
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("返回（Back）", ITEMDRAW_CONTROL);
	menu.DrawItem("退出（Exit）", ITEMDRAW_CONTROL);

	menu.Send(client, MenuHandler_EquipDescription, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipDescription(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 9)
	{
		StatusSelectMenuFuncEqment(client);
		return 0;
	}

	switch(selected)
	{
		case 1:
		{
			PrintToChat(client, "\x01[说明]装备类型有:\x03烈火,流水,破天,疾风,惊魄\x01.");
			PrintToChat(client, "\x01[说明]装备部件有:\x03帽子,腰带,鞋,衣服\x01.");
			PrintToChat(client, "\x01[说明]学习\x03五级天赋\x01后,必须穿齐相应的同类型装备技能才有效.");
			PrintToChat(client, "\x01[说明]\x03烈火\x01对应\x03烈火\x01,\x03碎骨\x01对应\x03破天\x01,\x03冰封\x01对应\x03流水\x01,\x03狂暴\x01对应\x03惊魄\x01,\x03嗜血\x01对应\x03疾风\x01.");
			PrintToChat(client, "\x01[说明]通过\x03类型锻造\x01可以更改装备的类型,不会失败,耗\x03一硬币\x01.");
		}
		case 2:
		{
			PrintToChat(client, "\x01[说明]装备属性有:\x03+伤害,+HP上限,+速度,+暴击,附加\x01.附加天赋技能不可迭加.");
			PrintToChat(client, "\x01[说明]装备按瑕疵度分:\x03琥珀,水晶,玛瑙\x01三等.");
			PrintToChat(client, "\x01[说明]通过\x03属性锻造\x01可以按装备原属性随机改变属性,较高几率属性增加,耗\x03一硬币\x01.");
		}
		case 3:
		{
			PrintToChat(client, "\x01[说明]打开\x03天启幸运箱\x01需要杀死本关卡第一个坦克\x03激活天启事件\x01后才能使用.");
			PrintToChat(client, "\x01[说明]将随机更改\x03当前天启\x01,耗\x03三硬币\x01.");
		}
		case 4:
		{
			PrintToChat(client, "\x01[说明]打开\x03装备幸运箱\x01需要\x03装备栏未满\x01状态才能使用.");
			PrintToChat(client, "\x01[说明]较高几率获得一件\x03玛瑙\x01瑕疵度的装备,耗\x03三硬币\x01.");
		}
	}

	StatusEqmFuncD(client);
	return 0;
}

stock Panel CreateConfirmPanel(const char[] title, const char[] text = "", any ...)
{
	Panel menu = CreatePanel();
	menu.SetTitle(title);

	if(text[0] != EOS)
	{
		char line[1024];
		VFormat(line, 1024, text, 3);
		menu.DrawText(line);
	}

	menu.DrawItem("是");
	menu.DrawItem("否");
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("", ITEMDRAW_NOTEXT);
	menu.DrawItem("返回（Back）", ITEMDRAW_CONTROL);
	menu.DrawItem("退出（Exit）", ITEMDRAW_CONTROL);
	return menu;
}

stock Menu CreateConfirmMenu(const char[] title, MenuHandler handler, const char[] info = "", const char[] text = "", any ...)
{
	Menu menu = CreateMenu(handler);

	char line[1024] = "";
	if(text[0] != EOS)
		VFormat(line, 1024, text, 5);

	menu.SetTitle("%s\n%s", title, line);
	menu.AddItem(info, "是");
	menu.AddItem(info, "否");

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	return menu;
}

void StatusEqmFuncB(int client)
{
	if(!g_pCvarRE.BoolValue)
	{
		PrintToChat(client, "\x03[提示]\x01 此功能已禁用。");
		StatusSelectMenuFuncEqment(client);
		return;
	}
	
	CreateConfirmPanel("========= 天启幸运箱 =========",
		"确定打开天启幸运箱？\n需要 1 币，现有 %d 币",
		g_clSkillPoint[client]).Send(client, MenuHandler_OpenLucky, MENU_TIME_FOREVER);
}

void StatusEqmFuncC(int client)
{
	if(!g_pCvarEquipment.BoolValue)
	{
		PrintToChat(client, "\x03[提示]\x01 此功能已禁用。");
		StatusSelectMenuFuncEqment(client);
		return;
	}
	
	CreateConfirmPanel("========= 装备幸运箱 =========",
		"确定打开装备幸运箱？\n需要 3 币，现有 %d 币",
		g_clSkillPoint[client]).Send(client, MenuHandler_OpenEquipment, MENU_TIME_FOREVER);
}

public int MenuHandler_OpenEquipment(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 9 || selected == 2)
	{
		StatusSelectMenuFuncEqment(client);
		return 0;
	}

	if(selected == 1)
	{
		if(g_clSkillPoint[client] < 3)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusEqmFuncC(client);
			return 0;
		}

		int j = GiveEquipment(client);
		if(!j)
		{
			PrintToChat(client, "\x03[提示]\x01 你的装备栏已满，无法打开装备幸运箱。");
			StatusEqmFuncC(client);
			return 0;
		}
		
		GiveSkillPoint(client, -3);
		
		char key[16];
		IntToString(j, key, sizeof(key));
		
		static EquipData_t data;
		if(g_mEquipData[client].GetArray(key, data, sizeof(data)) && data.valid)
			PrintToChat(client, "\x03[提示]\x01 你获得了：\x05%s\x01", FormatEquip(client, data));
	}

	if(selected != 10)
		StatusEqmFuncC(client);
	
	return 0;
}

public int MenuHandler_OpenLucky(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client) || action != MenuAction_Select)
		return 0;

	if(selected == 9 || selected == 2)
	{
		StatusSelectMenuFuncEqment(client);
		return 0;
	}

	if(selected == 1)
	{
		if(g_iRoundEvent == 0)
		{
			PrintToChat(client, "\x03[\x05提示\x03]\x04天启尚未激活，只有天启被激活了才能打开天启幸运箱。");
			StatusEqmFuncB(client);
			return 0;
		}

		if(g_clSkillPoint[client] < 1)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusEqmFuncC(client);
			return 0;
		}

		GiveSkillPoint(client, -1);
		StartRoundEvent();

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[提示]\x01 有人偷偷打开了天启幸运箱，本回合的天启更改为：\x04%s\x01。", g_szRoundEvent);
	}
	
	if(selected != 10)
		StatusEqmFuncB(client);
	
	return 0;
}

// char FormatEquip(int client, int index, char[] buffer = "", int len = 0)
stock char FormatEquip(int client, EquipData_t data, char[] buffer = "", int len = 0, bool lite = false)
{
	char text[255];
	if(!data.valid)
	{
		strcopy(text, 255, "<无>");

		if(len > 5)
			strcopy(buffer, len, text);

		return text;
	}

	char extrastr[16] = "";
	bool legend = (data.damage >= g_iMaxEquipDamage ||
		data.health >= g_iMaxEquipHealth ||
		data.speed >= g_iMaxEquipSpeed ||
		data.gravity >= g_iMaxEquipGravity ||
		data.crit >= g_iMaxEquipCrit
	);

	// 特殊标记
	if(data.effect > 0 && legend)
		strcopy(extrastr, sizeof(extrastr), "★");	// 黑星
	else if(data.effect > 0)
		strcopy(extrastr, sizeof(extrastr), "☆");	// 白星
	else
		strcopy(extrastr, sizeof(extrastr), "");

	// 正在使用
	if(g_clCurEquip[client][data.parts] == data.hashID)
		StrCat(extrastr, sizeof(extrastr), " √");
	
	int lentex = 0;
	int power = CalcEquipPower(data);
	
	if(lite)
	{
		lentex = FormatEx(text, 255, "%s%s%s|(%d)%s", data.sPrefix, data.sNamed, data.sParts, power, extrastr);
	}
	else
	{
		lentex = FormatEx(text, 255, "%s%s%s|伤害+%d％|血量+%d％|速度+%d％|暴击+%d‰|跳跃+%d％|(%d)%s",
			data.sPrefix, data.sNamed, data.sParts,
			data.damage, data.health, data.speed, data.crit, data.gravity, power, extrastr
		);
	}

	if(len > lentex)
		strcopy(buffer, len, text);

	return text;
}

void StatusEqmFuncA(int client, bool showEmpty = false)
{
	if(!g_pCvarEquipment.BoolValue)
	{
		PrintToChat(client, "\x03[提示]\x01 此功能已禁用。");
		StatusSelectMenuFuncEqment(client);
		return;
	}
	
	Menu menu = CreateMenu(MenuHandler_SelectEquip);
	menu.SetTitle("========= 装备栏 =========");
	
	static char key[16];
	static EquipData_t data;
	
	// 已经装备上的排在前面
	for(int i = 0; i < sizeof(g_clCurEquip[]); ++i)
	{
		if(!g_clCurEquip[client][i])
			continue;
		
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
		{
			g_clCurEquip[client][i] = 0;
			continue;
		}
		
		menu.AddItem(key, FormatEquip(client, data, _, _, true));
	}
	
	// 然后是背包里的装备
	StringMapSnapshot snap = g_mEquipData[client].Snapshot();
	int size = snap.Length;
	for(int i = 0; i < size; ++i)
	{
		snap.GetKey(i, key, sizeof(key));
		
		// 忽略已经装备上的(因为上面已经添加了)
		int hashId = StringToInt(key);
		for(int j = 0; j < sizeof(g_clCurEquip[]); ++j)
		{
			if(hashId != g_clCurEquip[client][j])
				continue;
			
			hashId = 0;
			break;
		}
		if(!hashId)
			continue;
		
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
			continue;
		
		if(!data.valid)
		{
			g_mEquipData[client].Remove(key);
			continue;
		}
		
		menu.AddItem(key, FormatEquip(client, data, _, _, true));
	}
	
	if(menu.ItemCount > 0)
	{
		menu.ExitButton = true;
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		if(showEmpty)
			PrintToChat(client, "\x03[提示]\x01 你没有任何装备。");

		StatusSelectMenuFuncEqment(client);
	}
}

// void StatusEqmMenu(int client, int index = -1)
void StatusEqmMenu(int client, char[] key, EquipData_t data)
{
	Menu menu = CreateMenu(MenuHandler_EquipInfo);
	menu.SetTitle("装备信息\n%s", FormatEquip(client, data));
	menu.AddItem(key, "穿上");
	menu.AddItem(key, "卸下");
	menu.AddItem(key, "改类型");
	menu.AddItem(key, "改属性");
	menu.AddItem(key, "回收(出售)");
	menu.AddItem(key, "查看附加");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipInfo(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusEqmFuncA(client, false);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;
	
	static char key[16];
	menu.GetItem(0, key, 16);
	static EquipData_t data;
	
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", selected, key);
		StatusEqmFuncA(client);
		return 0;
	}

	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}
	
	int damage, health, speed, gravity, crit;
	
	switch(selected)
	{
		case 0:
		{
			if(g_clCurEquip[client][data.parts] == data.hashID)
			{
				PrintToChat(client, "\x03[提示]\x01 你已穿上该装备，无需重复穿上。");
			}
			else
			{
				g_clCurEquip[client][data.parts] = data.hashID;
				RegPlayerHook(client, false);
				CalcPlayerAttr(client, damage, health, speed, gravity, crit, false);
				
				PrintToChat(client,
					"\x03[提示]\x01 成功穿上该装备,穿上后 伤害+\x03%d％\x01 HP+\x03%d％\x01 速度+\x03%d％\x01 跳跃+\x03%d％\x01 暴击+\x03%d‰\x01 附加:\x03%s\x01.",
					damage,health,speed,gravity,crit,data.sEffect
				);
				// EmitSoundToClient(client,g_soundLevel);
				ClientCommand(client, "play \"%s\"", g_soundLevel);
			}
		}
		case 1:
		{
			if(g_clCurEquip[client][data.parts] != data.hashID)
			{
				PrintToChat(client, "\x03[提示]\x01 你没有穿上该装备，无需卸下。");
			}
			else
			{
				g_clCurEquip[client][data.parts] = 0;
				RegPlayerHook(client, false);
				CalcPlayerAttr(client, damage, health, speed, gravity, crit, false);
				
				PrintToChat(client,
					"\x03[提示]\x01 成功卸下该装备,卸下后 伤害+\x03%d％\x01 HP+\x03%d％\x01 速度+\x03%d％\x01 跳跃+\x03%d％\x01 暴击+\x03%d‰\x01 取消:\x03%s\x01.",
					damage,health,speed,gravity,crit,data.sEffect
				);
			}
		}
		case 2:
		{
			if(g_clCurEquip[client][data.parts] != data.hashID)
			{
				StatusEqmChangeType(client, key);
				return 0;
			}
			
			PrintToChat(client, "\x03[提示]\x01 请先卸下该装备再进行操作。");
		}
		case 3:
		{
			if(g_clCurEquip[client][data.parts] != data.hashID)
			{
				StatusEqmChangePoint(client, key);
				return 0;
			}
			
			PrintToChat(client, "\x03[提示]\x01 请先卸下该装备再进行操作。");
		}
		case 4:
		{
			if(g_clCurEquip[client][data.parts] != data.hashID)
			{
				StatusEqmSell(client, key);
				return 0;
			}
			
			PrintToChat(client, "\x03[提示]\x01 请先卸下该装备再进行操作。");
		}
		case 5:
		{
			PrintToChat(client, "\x03[提示]\x01 该装备附加天赋技能：\x03%s\x01。", data.sEffect);
		}
	}
	
	StatusEqmMenu(client, key, data);
	return 0;
}

void StatusEqmSell(int client, char[] key)
{
	CreateConfirmMenu("========= 回收(出售)装备 =========", MenuHandler_SellEquip, key,
		"确定回收(出售)该装备？\n现有 %d 币，回收(出售)获得 1 币",
		g_clSkillPoint[client]).Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SellEquip(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	char key[16];
	menu.GetItem(0, key, 16);
	
	static EquipData_t data;
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", selected, key);
		StatusEqmFuncA(client);
		return 0;
	}
	
	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		if(data.valid)
			StatusEqmMenu(client, key, data);
		else
			StatusEqmFuncA(client);

		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}

	if(selected == 0)
	{
		g_mEquipData[client].Remove(key);
		GiveSkillPoint(client, 1);
		PrintToChat(client, "\x03[提示]\x01 完成。");
	}
	else if(selected == 1)
	{
		StatusEqmFuncA(client);
		return 0;
	}

	StatusSelectMenuFuncEqment(client);
	return 0;
}

// void StatusEqmChangePoint(int client, int index = -1)
void StatusEqmChangePoint(int client, char[] key)
{
	// 普通锻造
	CreateConfirmMenu("【锻造装备】", MenuHandler_EquipProperty, key,
		"确定锻造该装备以提升属性？\n现有 %d 币，需要 1 币",
		g_clSkillPoint[client]).Display(client, MENU_TIME_FOREVER);
}

// void StatusEqmChangePointLegend(int client, int index = -1)
void StatusEqmChangePointLegend(int client, char[] key)
{
	// 传奇锻造
	CreateConfirmMenu("【锻造装备•极致】", MenuHandler_EquipSkill, key,
		"确定锻造该装备以更改附加技能？\n现有 %d 币，需要 3 币",
		g_clSkillPoint[client]).Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipSkill(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	char key[16];
	menu.GetItem(0, key, 16);
	
	static EquipData_t data;
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", selected, key);
		StatusEqmFuncA(client);
		return 0;
	}
	
	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		if(data.valid)
			StatusEqmMenu(client, key, data);
		else
			StatusEqmFuncA(client);

		return 0;
	}

	if(action != MenuAction_Select)
		return 0;
	
	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}

	if(selected == 0)
	{
		if(g_clSkillPoint[client] < 3)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusEqmChangePointLegend(client, key);
			return 0;
		}

		GiveSkillPoint(client, -3);
		
		data.effect = GetRandomInt(1, g_iMaxEqmEffects);
		
		RebuildEquipStr(data);
		g_mEquipData[client].SetArray(key, data, sizeof(data));

		PrintToChat(client, "\x03[提示]\x01 锻造后：%s", FormatEquip(client, data));
	}
	else if(selected == 1)
	{
		StatusEqmMenu(client, key, data);
		return 0;
	}

	StatusEqmChangePointLegend(client, key);
	return 0;
}

public int MenuHandler_EquipProperty(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	char key[16];
	menu.GetItem(0, key, 16);
	
	static EquipData_t data;
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", selected, key);
		StatusEqmFuncA(client);
		return 0;
	}
	
	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		if(data.valid)
			StatusEqmMenu(client, key, data);
		else
			StatusEqmFuncA(client);

		return 0;
	}

	if(action != MenuAction_Select)
		return 0;
	
	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}

	if(selected == 0)
	{
		if(g_clSkillPoint[client] < 1)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusEqmChangePoint(client, key);
			return 0;
		}
		
		if(data.damage >= g_iMaxEquipDamage ||
			data.health >= g_iMaxEquipHealth ||
			data.speed >= g_iMaxEquipSpeed ||
			data.gravity >= g_iMaxEquipGravity ||
			data.crit >= g_iMaxEquipCrit
		)
		{
			PrintHintText(client, "\x03[\x05提示\x03]\x04该装备已经锻造至极致,继续锻造需耗硬币三枚,且只会随机获得附加技能,不会再改变属性!");
			StatusEqmChangePointLegend(client, key);
			return 0;
		}

		GiveSkillPoint(client, -1);
		SetRandomSeed(GetGameTickCount() + client);
		
		switch(data.parts)
		{
			case EquipPart_Head:
			{
				data.damage += GetRandomInt(-3, 5);
				data.health += GetRandomInt(-10, 15);
				data.crit += GetRandomInt(-2, 3);
			}
			case EquipPart_Body:
			{
				data.damage += GetRandomInt(-2, 3);
				data.health += GetRandomInt(-15, 30);
				data.speed += GetRandomInt(-3, 5);
				data.gravity += GetRandomInt(-3, 5);
			}
			case EquipPart_Hand:
			{
				data.damage += GetRandomInt(-10, 20);
				data.health += GetRandomInt(-2, 5);
				data.crit += GetRandomInt(-10, 15);
			}
			case EquipPart_Foot:
			{
				data.damage += GetRandomInt(-1, 3);
				data.health += GetRandomInt(-1, 5);
				data.speed += GetRandomInt(-5, 10);
				data.gravity += GetRandomInt(-5, 10);
			}
		}
		
		SetRandomSeed(GetSysTickCount() + client);
		
		switch(data.prefix)
		{
			case EquipPrefix_Fire:
				data.damage += GetRandomInt(1, 10);
			case EquipPrefix_Water:
				data.health += GetRandomInt(1, 10);
			case EquipPrefix_Sky:
				data.gravity += GetRandomInt(1, 5);
			case EquipPrefix_Wind:
				data.speed += GetRandomInt(1, 5);
			case EquipPrefix_Lucky:
				data.crit += GetRandomInt(1, 5);
		}
		
		RebuildEquipStr(data);
		g_mEquipData[client].SetArray(key, data, sizeof(data));
		PrintToChat(client, "\x03[提示]\x01 锻造后：%s", FormatEquip(client, data));
	}
	else if(selected == 1)
	{
		StatusEqmMenu(client, key, data);
		return 0;
	}

	StatusEqmChangePoint(client, key);
	return 0;
}

// void StatusEqmChangeType(int client, int index = -1)
void StatusEqmChangeType(int client, char[] key)
{
	Menu menu = CreateMenu(MenuHandler_EquipType);
	menu.SetTitle("========= 锻造装备 =========\n选择要更改成哪个类型？\n需要 1 币，现有 %d 币",
		g_clSkillPoint[client]);
	
	menu.AddItem(key, "烈火(伤害)");
	menu.AddItem(key, "流水(生命)");
	menu.AddItem(key, "破天(跳跃)");
	menu.AddItem(key, "疾风(速度)");
	menu.AddItem(key, "惊魄(暴击)");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipType(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	char key[16];
	menu.GetItem(0, key, 16);
	
	static EquipData_t data;
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", key, selected);
		StatusEqmFuncA(client);
		return 0;
	}
	
	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		if(data.valid)
			StatusEqmMenu(client, key, data);
		else
			StatusEqmFuncA(client);

		return 0;
	}

	if(action != MenuAction_Select)
		return 0;
	
	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}

	if(0 <= selected <= 4)
	{
		if(g_clSkillPoint[client] < 1)
		{
			PrintToChat(client, "\x03[提示]\x01 你的硬币不足。");
			StatusEqmChangeType(client, key);
			return 0;
		}

		GiveSkillPoint(client, -1);
	}

	switch(selected)
	{
		case 0:
		{
			data.prefix = EquipPrefix_Fire;
			strcopy(data.sPrefix, sizeof(data.sPrefix), "烈火");
			PrintToChat(client, "\x03[提示]\x01 改成了：\x04烈火");
		}
		case 1:
		{
			data.prefix = EquipPrefix_Water;
			strcopy(data.sPrefix, sizeof(data.sPrefix), "流水");
			PrintToChat(client, "\x03[提示]\x01 改成了：\x04流水");
		}
		case 2:
		{
			data.prefix = EquipPrefix_Sky;
			strcopy(data.sPrefix, sizeof(data.sPrefix), "破天");
			PrintToChat(client, "\x03[提示]\x01 改成了：\x04破天");
		}
		case 3:
		{
			data.prefix = EquipPrefix_Wind;
			strcopy(data.sPrefix, sizeof(data.sPrefix), "疾风");
			PrintToChat(client, "\x03[提示]\x01 改成了：\x04疾风");
		}
		case 4:
		{
			data.prefix = EquipPrefix_Lucky;
			strcopy(data.sPrefix, sizeof(data.sPrefix), "惊魄");
			PrintToChat(client, "\x03[提示]\x01 改成了：\x04惊魄");
		}
	}
	g_mEquipData[client].SetArray(key, data, sizeof(data));
	
	StatusEqmChangeType(client, key);
	return 0;
}

public int MenuHandler_SelectEquip(Menu menu, MenuAction action, int client, int selected)
{
	if(!IsValidClient(client))
		return 0;

	if(action == MenuAction_Cancel && selected == MenuCancel_ExitBack)
	{
		StatusSelectMenuFuncEqment(client);
		return 0;
	}

	if(action != MenuAction_Select)
		return 0;

	char key[16];
	menu.GetItem(selected, key, 16);
	
	static EquipData_t data;
	if(!g_mEquipData[client].GetArray(key, data, sizeof(data)))
	{
		PrintToChat(client, "\x03[提示]\x01 没有这种操作：%d|%s", selected, key);
		StatusEqmFuncA(client);
		return 0;
	}

	if(!data.valid)
	{
		PrintToChat(client, "\x03[提示]\x01 这个选项无效。");
		StatusEqmFuncA(client);
		return 0;
	}

	// SelectEqm[client] = index;
	StatusEqmMenu(client, key, data);
	return 0;
}

void StatusSelectMenuFuncRP(int clientId, bool withMenu = false)
{
	if(!IsValidClient(clientId))
		return;
	
	if(!g_pCvarRP.BoolValue)
	{
		PrintToChat(clientId, "\x03[提示]\x01 此功能已禁用。");
		
		if(withMenu)
			StatusChooseMenuFunc(clientId);
		return;
	}
	
	if(IsPlayerAlive(clientId))
	{
		if(!g_bHasRPActive && !g_bIsRPActived[clientId])
		{
			GiveAngryPoint(clientId, 2);

			g_bHasRPActive = true;
			g_bIsRPActived[clientId] = true;
			CreateTimer(40.0, Event_RP, clientId, TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(90.0, Client_RP, clientId, TIMER_FLAG_NO_MAPCHANGE);

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03[\x05提示\x03]%N\x04激活了人品(抽奖)事件,怒气值\x05+2\x04,等待\x03[\x0540\x03]\x04秒后人品(抽奖)事件发生!", clientId);
			else
				PrintToChat(clientId, "\x03[提示]\x01 你启动了人品(抽奖)事件，等待 \x0540\x01 秒后发生一些事情。");
		}
		else if(g_bHasRPActive)
		{
			// if(g_pCvarAllow.BoolValue)
			PrintToChat(clientId, "\x03[\x05提示\x03]\x04人品(抽奖)事件已经激活,等待\x03[\x0540\x03]\x04秒后才能重新激活!");
		}
		else
		{
			// if(g_pCvarAllow.BoolValue)
			PrintToChat(clientId, "\x03[\x05提示\x03]\x04你丫的当刷人品(抽奖)是吃饭啊,刷过了就要等\x03[\x0590\x03]\x04秒后才能再刷!");
		}
	}
	else
	{
		// if(g_pCvarAllow.BoolValue)
		PrintToChat(clientId, "\x03[\x05提示\x03]\x04你不是活着的生还者,无法激活人品(抽奖)事件!");
	}
}

stock void FreezePlayer(int client, float time)
{
	{
		Call_StartForward(g_fwOnFreeze);
		Call_PushCell(client);
		
		float refTime = time;
		Call_PushCellRef(refTime);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return;
		
		if(refResult == Plugin_Changed)
			time = refTime;
	}
	
	g_fFreezeTime[client] = GetEngineTime() + time;
	
	if(!IsFakeClient(client))
	{
		ClientCommand(client, "play \"physics/glass/glass_impact_bullet4.wav\"");
		PrintHintText(client, "你被冻结 %.0f 秒", time);
	}
	
	// CheatCommandEx(client, "stopsound");
	SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
	// SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityRenderColor(client, 0, 128, 255, 192);
	SetEntProp(client, Prop_Data, "m_afButtonDisabled", 0xFFFFFFFF);
	SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN | FL_FREEZING);
}

public void OnGameFrame()
{
	// 修改武器攻击速度
	if(g_iWeaponSpeedTotal > 0)
	{
		char className[64];
		float gameTime = GetGameTime(), endTime;
		for(int i = 0; i < g_iWeaponSpeedTotal; ++i)
		{
			if(g_iWeaponSpeedEntity[i] == INVALID_ENT_REFERENCE || !IsValidEntity(g_iWeaponSpeedEntity[i]))
				continue;

			GetEntityClassname(g_iWeaponSpeedEntity[i], className, 64);
			if(StrContains(className, "weapon_", false) != 0 ||
				GetEntProp(g_iWeaponSpeedEntity[i], Prop_Send, "m_bInReload") ||
				GetEntProp(g_iWeaponSpeedEntity[i], Prop_Send, "m_iClip1") <= 0)
				continue;

			// 动作速度
			SetEntPropFloat(g_iWeaponSpeedEntity[i], Prop_Send, "m_flPlaybackRate", g_fWeaponSpeedUpdate[i]);

			// 主要攻击(开枪)
			endTime = (GetEntPropFloat(g_iWeaponSpeedEntity[i], Prop_Send, "m_flNextPrimaryAttack") - gameTime) / g_fWeaponSpeedUpdate[i];
			SetEntPropFloat(g_iWeaponSpeedEntity[i], Prop_Send, "m_flNextPrimaryAttack", endTime + gameTime);

			// 次要攻击(推)
			// endTime = (GetEntPropFloat(g_iWeaponSpeedEntity[i], Prop_Send, "m_flNextSecondaryAttack") - gameTime) / g_fWeaponSpeedUpdate[i];
			// SetEntPropFloat(g_iWeaponSpeedEntity[i], Prop_Send, "m_flNextSecondaryAttack", endTime + gameTime);
			
			// 还原动作速度
			CreateTimer(endTime, Timer_ResetWeaponSpeed, g_iWeaponSpeedEntity[i], TIMER_FLAG_NO_MAPCHANGE);
		}

		g_iWeaponSpeedTotal = 0;
	}
	
	// 修改武器弹匣大小
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(g_iReloadWeaponEntity[i] != INVALID_ENT_REFERENCE)
				PlayerHook_OnReloadThink(i);
		}
	}
	
	static float nextSecond;
	float curTime = GetEngineTime();
	if(nextSecond <= curTime)
	{
		nextSecond = curTime + 1.0;
		int randPlayer = -1;

		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsValidClient(i) || !IsPlayerAlive(i))
				continue;

			randPlayer = i;
			int team = GetClientTeam(i);
			if(team != 2 && team != 3)
				continue;

			if(team == 2)
			{
				if(!g_bIsGamePlaying)
				{
					g_ctPainPills[i] = curTime + 120.0;
					g_ctPipeBomb[i] = curTime + 100.0;
					g_ctDefibrillator[i] = curTime + 200.0;
					g_ctConvTemp[i] = curTime + 2.0;
					g_ctFullHealth[i] = curTime + 200.0;
					g_ctSelfHeal[i] = curTime + 150.0;
					g_ctGodMode[i] = curTime + 80.0;
					g_csHasGodMode[i] = false;
				}
				
				if((g_clSkill_2[i] & SKL_2_PainPills) && g_ctPainPills[i] > 0.0 && g_ctPainPills[i] <= curTime)
				{
					g_ctPainPills[i] = curTime + 120.0;
					if(GetPlayerWeaponSlot(i, 4) == -1)
					{
						CheatCommand(i, "give", "pain_pills");
						PrintToChat(i, "\x03「嗜药」\x01你获得了药丸。");
					}
					else
					{
						PrintToChat(i, "\x03「嗜药」\x01你的物品栏已经满了，无法获得药丸。");
					}
				}

				if((g_clSkill_2[i] & SKL_2_PipeBomb) && g_ctPipeBomb[i] > 0.0 && g_ctPipeBomb[i] <= curTime)
				{
					g_ctPipeBomb[i] = curTime + 100.0;
					if(GetPlayerWeaponSlot(i, 2) == -1)
					{
						if(IsPlayerHaveEffect(i, 28))
						{
							CheatCommand(i, "give", "vomitjar");
							PrintToChat(i, "\x03「爆破•改」\x01你获得了胆汁。");
						}
						else
						{
							CheatCommand(i, "give", "pipe_bomb");
							PrintToChat(i, "\x03「爆破」\x01你获得了土制炸弹。");
						}
					}
					else
					{
						PrintToChat(i, "\x03「爆破」\x01你的物品栏已经满了，无法获得土制炸弹。");
					}
				}

				if((g_clSkill_2[i] & SKL_2_Defibrillator) && g_ctDefibrillator[i] > 0.0 && g_ctDefibrillator[i] <= curTime)
				{
					g_ctDefibrillator[i] = curTime + 200.0;
					if(GetPlayerWeaponSlot(i, 3) == -1)
					{
						if(IsPlayerHaveEffect(i, 27))
						{
							CheatCommand(i, "give", "first_aid_kit");
							PrintToChat(i, "\x03「电疗•改」\x01你获得了医疗包。");
						}
						else
						{
							CheatCommand(i, "give", "defibrillator");
							PrintToChat(i, "\x03「电疗」\x01你获得了电击器。");
						}
						
					}
					else
					{
						PrintToChat(i, "\x03「电疗」\x01你的物品栏已经满了，无法获得电击器。");
					}
				}
				
				if((g_clSkill_4[i] & SKL_4_TempRespite) && g_ctConvTemp[i] > 0.0 && g_ctConvTemp[i] <= curTime &&
					!IsPlayerIncapped(i) && !GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1))
				{
					g_ctConvTemp[i] = curTime + 2.0;
					
					int tempHealth = GetPlayerTempHealth(i);
					if(tempHealth > 0)
					{
						int health = GetEntProp(i, Prop_Data, "m_iHealth");
						int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
						if(health + 1 <= maxHealth)
						{
							SetEntProp(i, Prop_Data, "m_iHealth", health + 1);
							SetEntPropFloat(i, Prop_Send, "m_healthBuffer", float(tempHealth - 1));
							SetEntPropFloat(i, Prop_Send, "m_healthBufferTime", GetGameTime());
						}
					}
				}
				
				if(IsPlayerHaveEffect(i, 13))
				{
					int tempHealth = GetPlayerTempHealth(i);
					if(tempHealth > 0)
					{
						SetEntPropFloat(i, Prop_Send, "m_healthBufferTime", GetGameTime());
					}
				}
			}

			if((g_clSkill_2[i] & SKL_2_FullHealth) && g_ctFullHealth[i] > 0.0 && g_ctFullHealth[i] <= curTime)
			{
				g_ctFullHealth[i] = curTime + 300.0;
				int maxHealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
				int health = GetEntProp(i, Prop_Data, "m_iHealth");

				int buffer = GetPlayerTempHealth(i);
				if(team == 3)
					buffer = 0;
				
				if(IsPlayerHaveEffect(i, 26))
				{
					CheatCommand(i, "give", "health");
					PrintToChat(i, "\x03「永康•改」\x01你回满了血并重置倒地次数。");
				}
				else if(health + buffer >= maxHealth)
				{
					PrintToChat(i, "\x03「永康」\x01未能回血，因为已经满了。");
				}
				else
				{
					AddHealth(i, 999);
					PrintToChat(i, "\x03「永康」\x01你回满血了。");
				}
			}

			if((g_clSkill_3[i] & SKL_3_SelfHeal) && g_ctSelfHeal[i] > 0.0 && g_ctSelfHeal[i] <= curTime)
			{
				g_ctSelfHeal[i] = curTime + 200.0;
				
				if(team == 2 && !GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1))
				{
					int health = GetPlayerTempHealth(i) + 80;
					if(health > 200)
						health = 200;
					
					SetEntPropFloat(i, Prop_Send, "m_healthBuffer", health * 1.0);
					SetEntPropFloat(i, Prop_Send, "m_healthBufferTime", GetGameTime());
				}
				else
				{
					// SetEntProp(i, Prop_Data, "m_iHealth", GetEntProp(i, Prop_Data, "m_iHealth") + 80);
					AddHealth(i, 80, true, true);
				}

				PrintToChat(i, "\x03「暴疗」\x01你获得 \x0580\x01 生命值。");
			}

			if((g_clSkill_3[i] & SKL_3_GodMode) && g_ctGodMode[i] > 0.0 && g_ctGodMode[i] <= curTime)
			{
				g_ctGodMode[i] = -curTime - 9.0;
				g_csHasGodMode[i] = !!IsPlayerHaveEffect(i, 9);
				
				// SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
				// EmitSoundToClient(client, g_soundLevel);

				ClientCommand(i, "play \"%s\"", g_soundLevel);
				
				if(g_csHasGodMode[i])
					PrintToChat(i, "\x03「无敌•改」\x01在 \x059\x01 秒以内不会受到伤害（掉落伤害除外）且无限子弹。");
				else
					PrintToChat(i, "\x03「无敌」\x01在 \x059\x01 秒以内不会受到伤害（掉落伤害除外）。");
			}
			else if(g_ctGodMode[i] < 0.0 && g_ctGodMode[i] >= -curTime)
			{
				g_ctGodMode[i] = curTime + 80.0;
				g_csHasGodMode[i] = false;
				PrintToChat(i, "\x03「无敌」\x01状态结束了。");
			}
			
			if(g_fFreezeTime[i] > 0.0 && g_fFreezeTime[i] <= curTime)
			{
				g_fFreezeTime[i] = 0.0;
				
				if(!IsFakeClient(i))
				{
					ClientCommand(i, "play \"physics/glass/glass_impact_bullet4.wav\"");
					PrintHintText(i, "解冻完成");
				}
				
				// 取消冻结玩家
				SetEntPropFloat(i, Prop_Send, "m_TimeForceExternalView", 0.0);
				SetEntityRenderColor(i);
				// SetEntityMoveType(i, MOVETYPE_WALK);
				SetEntProp(i, Prop_Data, "m_afButtonDisabled", 0);
				SetEntityFlags(i, GetEntityFlags(i) & ~(FL_FROZEN|FL_FREEZING));
			}
			else if(g_fFreezeTime[i] > 0.0 && g_fFreezeTime[i] > curTime)
			{
				int timeleft = RoundToCeil(g_fFreezeTime[i] - curTime);
				if(!IsFakeClient(i))
					PrintHintText(i, "距离解冻还有 %d 秒", timeleft);
			}
		}

		if(g_iRoundEvent > 0 && g_fNextRoundEvent <= curTime)
		{
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(!IsValidClient(i))
					continue;

				if(!IsPlayerAlive(i) || GetClientTeam(i) == 3)
				{
					randPlayer = i;
					break;
				}
			}

			if(g_iRoundEvent == 11)
			{
				// CheatCommand(randPlayer, "z_spawn_old", "witch auto");
				SpawnCommand(-1, ZC_WITCH);
				// PrintToServer("玩家 %N 刷出了一只 Witch", randPlayer);
				g_fNextRoundEvent = curTime + 120.0;
			}
			else if(g_iRoundEvent == 13)
			{
				int randNumber = 0;
				for(int i = 0; i < 8; ++i)
				{
					randNumber = GetRandomInt(1, 6);
					switch(randNumber)
					{
						case 1:
							// CheatCommand(randPlayer, "z_spawn_old", "smoker auto");
							SpawnCommand(-1, ZC_SMOKER);
						case 2:
							// CheatCommand(randPlayer, "z_spawn_old", "boomer auto");
							SpawnCommand(-1, ZC_BOOMER);
						case 3:
							// CheatCommand(randPlayer, "z_spawn_old", "hunter auto");
							SpawnCommand(-1, ZC_HUNTER);
						case 4:
							// CheatCommand(randPlayer, "z_spawn_old", "spitter auto");
							SpawnCommand(-1, ZC_SPITTER);
						case 5:
							// CheatCommand(randPlayer, "z_spawn_old", "jockey auto");
							SpawnCommand(-1, ZC_JOCKEY);
						case 6:
							// CheatCommand(randPlayer, "z_spawn_old", "charger auto");
							SpawnCommand(-1, ZC_CHARGER);
					}
				}

				// CheatCommand(randPlayer, "script", "::DifficultyBanalce_MinIntensity<-0");
				// PrintToServer("玩家 %N 刷出了 8 只特感", randPlayer);
				g_fNextRoundEvent = curTime + 40.0;
			}
			else if(g_iRoundEvent == 15)
			{
				// CheatCommand(randPlayer, "z_spawn_old", "spitter auto");
				// CheatCommand(randPlayer, "z_spawn_old", "boomer auto");
				// CheatCommand(randPlayer, "z_spawn_old", "spitter auto");
				// CheatCommand(randPlayer, "z_spawn_old", "boomer auto");
				SpawnCommand(-1, ZC_SPITTER);
				SpawnCommand(-1, ZC_SPITTER);
				SpawnCommand(-1, ZC_BOOMER);
				SpawnCommand(-1, ZC_BOOMER);
				// PrintToServer("玩家 %N 刷出了一只 Boomer 和 Spitter", randPlayer);
				g_fNextRoundEvent = curTime + 30.0;
			}
			else if(g_iRoundEvent == 16)
			{
				// CheatCommand(randPlayer, "z_spawn_old", "hunter auto");
				// CheatCommand(randPlayer, "z_spawn_old", "hunter auto");
				SpawnCommand(-1, ZC_HUNTER);
				SpawnCommand(-1, ZC_HUNTER);
				// PrintToServer("玩家 %N 刷出了一只 Hunter", randPlayer);
				g_fNextRoundEvent = curTime + 20.0;
			}
			else if(g_iRoundEvent == 17)
			{
				// CheatCommand(randPlayer, "script", "::VSLib.Utils.SpawnZombieNearPlayer(::VSLib.Player(GetPlayerFromUserID(%d)),'common_male_fallen_survivor')");

				float position[3];
				GetClientEyeAiming(randPlayer, position);
				SpawnCommonZombie("common_male_fallen_survivor", position);
				// PrintToServer("玩家 %N 刷出了一只 带补给的僵尸", randPlayer);
				g_fNextRoundEvent = curTime + 90.0;
			}
			else if(g_iRoundEvent == 18)
			{
				// CheatCommand(randPlayer, "z_spawn_old", "jockey auto");
				// CheatCommand(randPlayer, "z_spawn_old", "jockey auto");
				SpawnCommand(-1, ZC_JOCKEY);
				SpawnCommand(-1, ZC_JOCKEY);
				// PrintToServer("玩家 %N 刷出了一只 Jockey", randPlayer);
				g_fNextRoundEvent = curTime + 20.0;
			}
		}
	}

	// 跳跃处理
	/*
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsValidAliveClient(i))
				continue;

			// if((g_iJumpFlags[i] & JF_HasJumping) && (GetEntityFlags(i) & FL_ONGROUND))
			if((g_iJumpFlags[i] & JF_HasJumping) && GetEntPropEnt(i, Prop_Send, "m_hGroundEntity") > -1)
			{
				// int buttons = GetClientButtons(i);

				// 玩家跳起来然后落地了
				// 重置多重跳状态

				if(!(g_clSkill_3[i] & SKL_3_BunnyHop) || !(GetClientButtons(i) & IN_JUMP))
					g_iJumpFlags[i] &= ~(JF_HasJumping|JF_FirstReleased|JF_CanDoubleJump);
				// PrintCenterText(i, "落在地上了");
			}
		}
	}
	*/
	
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if(!g_bIsGamePlaying)
		return Plugin_Continue;
	
	if(!IsValidAliveClient(curTarget))
		return Plugin_Continue;
	
	// 特感攻击队友
	if(g_bIsHitByVomit[specialInfected])
	{
		int victim = ChooseSpecialVictim(specialInfected, curTarget);
		if(victim > -1 && victim != curTarget)
		{
			curTarget = victim;
			return Plugin_Changed;
		}
	}
	
	// 防止特感故意攻击胆汁玩家
	if((g_clSkill_2[curTarget] & SKL_2_ProtectiveSuit) && g_bIsHitByVomit[curTarget])
	{
		int victim = ChooseOtherVictim(specialInfected);
		if(victim > -1 && victim != curTarget)
		{
			curTarget = victim;
			return Plugin_Changed;
		}
	}
	
	// 特感切换目标
	if((g_clSkill_5[curTarget] & SKL_5_Sneak) && g_fNextCalmTime[curTarget] <= GetEngineTime() && !GetRandomInt(0, 1))
	{
		int victim = ChooseOtherVictim(specialInfected, curTarget);
		if(victim > -1)
		{
			curTarget = victim;
			return Plugin_Changed;
		}
		else
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

int ChooseOtherVictim(int attacker, int ignore = -1)
{
	float origin[3], position[3];
	float distance = 1000.0 * 1000.0;
	int victim = -1;
	
	GetClientAbsOrigin(attacker, origin);
	int team = GetClientTeam(attacker);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == ignore || i == attacker || !IsValidAliveClient(i) || GetClientTeam(i) == team)
			continue;
		
		if(GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1) || IsSurvivorHeld(i))
			continue;
		
		GetClientAbsOrigin(i, position);
		float dist = GetVectorDistance(origin, position, true);
		if(dist < distance)
		{
			distance = dist;
			victim = i;
		}
	}
	
	return victim;
}

int ChooseSpecialVictim(int attacker, int ignore = -1)
{
	float origin[3], position[3];
	float distance = 1000.0 * 1000.0;
	int victim = -1;
	
	GetClientAbsOrigin(attacker, origin);
	int team = GetClientTeam(attacker);
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == ignore || i == attacker || !IsValidAliveClient(i) || GetClientTeam(i) != team)
			continue;
		
		// Tank 会用到
		if(GetEntProp(i, Prop_Send, "m_isIncapacitated", 1))
			continue;
		
		GetClientAbsOrigin(i, position);
		float dist = GetVectorDistance(origin, position, true);
		if(dist < distance)
		{
			distance = dist;
			victim = i;
		}
	}
	
	return victim;
}

stock int SpawnCommand(int spawnner, int zClass)
{
	if(!IsValidClient(spawnner))
		spawnner = L4D_GetHighestFlowSurvivor();
	
	static ConVar z_spawn_range;
	if(z_spawn_range == null)
		z_spawn_range = FindConVar("z_spawn_range");
	
	float vPos[3];
	if(!L4D_GetRandomPZSpawnPosition(spawnner, zClass, z_spawn_range.IntValue, vPos))
		return 0;
	
	int bot = -1;
	bool postspawn = false;
	switch(zClass)
	{
		case ZC_SMOKER:
		{
			if(g_pfnCreateSmoker != null)
			{
				bot = SDKCall(g_pfnCreateSmoker, "舌头");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_SMOKER);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "smoker auto");
		}
		case ZC_BOOMER:
		{
			if(g_pfnCreateBoomer != null)
			{
				bot = SDKCall(g_pfnCreateBoomer, "胖子");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_BOOMER);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "boomer auto");
		}
		case ZC_HUNTER:
		{
			if(g_pfnCreateHunter != null)
			{
				bot = SDKCall(g_pfnCreateHunter, "猎人");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_HUNTER);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "hunter auto");
		}
		case ZC_SPITTER:
		{
			if(g_pfnCreateSpitter != null)
			{
				bot = SDKCall(g_pfnCreateSpitter, "口水");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_SPITTER);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "spitter auto");
		}
		case ZC_JOCKEY:
		{
			if(g_pfnCreateJockey != null)
			{
				bot = SDKCall(g_pfnCreateJockey, "猴");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_JOCKEY);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "jockey auto");
		}
		case ZC_CHARGER:
		{
			if(g_pfnCreateCharger != null)
			{
				bot = SDKCall(g_pfnCreateCharger, "牛");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_CHARGER);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnSpecial(zClass, vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "charger auto");
		}
		case ZC_TANK:
		{
			if(g_pfnCreateTank != null)
			{
				bot = SDKCall(g_pfnCreateTank, "克");
				if(bot > 0)
				{
					SetEntityModel(bot, MODEL_TANK);
					postspawn = true;
				}
			}
			if(bot <= 0)
				bot = L4D2_SpawnTank(vPos, Float:{0.0, 0.0, 0.0});
			if(bot <= 0)
				CheatCommand(spawnner, "z_spawn_old", "tank auto");
		}
		case ZC_WITCH:
		{
			if(GetRandomInt(0, 1))
				bot = L4D2_SpawnWitchBride(vPos, Float:{0.0, 0.0, 0.0}) > 0;
			else
				bot = L4D2_SpawnWitch(vPos, Float:{0.0, 0.0, 0.0}) > 0;
		}
	}
	
	if(postspawn && bot)
	{
		ChangeClientTeam(bot, 3);
		SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(bot, Prop_Send, "movetype", 2);
		SetEntProp(bot, Prop_Send, "deadflag", 0);
		SetEntProp(bot, Prop_Send, "m_lifeState", 0);
		SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(bot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(bot);
		ActivateEntity(bot);
		TeleportEntity(bot, vPos, NULL_VECTOR, NULL_VECTOR);
	}
	
	return bot;
}

stock void SpawnCommonZombie(const char[] zombieName, float position[3], const char[] targetName = "")
{
	static int iZombieSpawner = INVALID_ENT_REFERENCE;
	if(iZombieSpawner == INVALID_ENT_REFERENCE || !IsValidEntity(iZombieSpawner))
	{
		iZombieSpawner = EntIndexToEntRef(CreateEntityByName("commentary_zombie_spawner"));
		if(iZombieSpawner == INVALID_ENT_REFERENCE || !IsValidEntity(iZombieSpawner))
			SetFailState("Could not create 'commentary_zombie_spawner'");
		
		DispatchSpawn(iZombieSpawner);
	}
	
	TeleportEntity(iZombieSpawner, position, NULL_VECTOR, NULL_VECTOR);
	
	if(targetName[0] != EOS)
		SetVariantString(tr("%s,%s", zombieName, targetName));
	else
		SetVariantString(zombieName);
	
	AcceptEntityInput(iZombieSpawner, "SpawnZombie");
}

// 获取玩家瞄准的实体
stock int GetClientEyeAiming(int client, float origin[3] = NULL_VECTOR, int mask = MASK_SHOT)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return -1;

	float eye[3], angle[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, angle);

	Handle trace = TR_TraceRayFilterEx(eye, angle, mask, RayType_Infinite, TraceFilter_NonPlayerOtherAny, client);

	int entity = -1;
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(origin, trace);
		entity = TR_GetEntityIndex(trace);
	}

	trace.Close();
	return entity;
}

// 获取玩家瞄准的位置的距离
stock float GetClientEyeDistance(int client, float origin[3] = NULL_VECTOR, int mask = MASK_SHOT)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return 0.0;

	float eye[3], angle[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, angle);

	Handle trace = TR_TraceRayFilterEx(eye, angle, mask, RayType_Infinite, TraceFilter_NonPlayerOtherAny, client);

	float distance = 0.0;
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(origin, trace);
		distance = GetVectorDistance(eye, origin, false);
	}

	trace.Close();
	return distance;
}

public Action Timer_ResetWeaponSpeed(Handle timer, any weapon)
{
	if(weapon <= MaxClients || !IsValidEntity(weapon))
		return Plugin_Continue;

	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 1.0);
	// SetEntProp(weapon, Prop_Send, "m_nSequence", 0);
	// SetEntPropFloat(weapon, Prop_Send, "m_flCycle", 0.0);
	
	/*
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if(IsValidAliveClient(client))
	{
		int model = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		if(model > MaxClients && IsValidEntity(model) && IsValidEdict(model))
		{
			// 停止重复抛壳动画
			// SetEntPropFloat(model, Prop_Send, "m_flPlaybackRate", 1.0);
			SetEntPropFloat(model, Prop_Send, "m_flLayerStartTime", 0.0);
			// SetEntProp(model, Prop_Send, "m_nLayerSequence", 0);
			// SetEntPropFloat(model, Prop_Send, "m_flCycle", 0.0);
		}
	}
	*/
	
	return Plugin_Continue;
}

public Action PlayerHook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsValidAliveClient(victim) || damage <= 0.0)
		return Plugin_Continue;
	
	if((damagetype & DMG_FALL) || attacker <= 0)
	{
		if(g_bOnRocketDude[victim])
			return Plugin_Handled;
		
		return Plugin_Continue;
	}
	
	if(IsValidClient(attacker) && GetClientTeam(attacker) == GetClientTeam(victim) &&
		((g_clSkill_1[attacker] & SKL_1_Firendly) || (g_clSkill_1[victim] & SKL_1_Firendly)))
	{
		// 免疫队友和自己的伤害
		return Plugin_Handled;
	}
	
	float time = GetEngineTime();
	if((g_ctGodMode[victim] < 0.0 && g_ctGodMode[victim] < -time) || (g_fFreezeTime[victim] > time && IsPlayerHaveEffect(victim, 29)))
	{
		// 无敌模式伤害免疫
		if(!IsNullVector(damagePosition) && (g_pfnIsInvulnerable == null || SDKCall(g_pfnIsInvulnerable, victim) <= 0))
			EmitAmbientSound(SOUND_STEEL, damagePosition, victim, SNDLEVEL_HOME);
		return Plugin_Handled;
	}
	
	if(attacker > 0 && IsValidEntity(attacker))
	{
		static char classname[64];
		GetEdictClassname(attacker, classname, 64);
		
		int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");
		int health = GetEntProp(victim, Prop_Data, "m_iHealth") + GetPlayerTempHealth(victim);
		if(IsPlayerIncapped(victim) && IsValidAliveClient(reviver) && health > damage &&
			((g_clSkill_1[victim] & SKL_1_ReviveBlock) || (g_clSkill_1[reviver] & SKL_1_ReviveBlock)))
		{
			// 将伤害类型替换为不会打断
			damagetype = (DMG_ENERGYBEAM|DMG_RADIATION);
		}
		
		if((g_clSkill_4[victim] & SKL_4_Defensive) && StrEqual(classname, "infected", false))
		{
			if(damage > 1.0 && (health <= damage || GetRandomInt(0, 1)))
			{
				damage /= 2.0;
				if(damage < 1.0)
					damage = 1.0;
			}
			else
			{
				// 附加同等伤害
				SDKHooks_TakeDamage(attacker, 0, victim, damage * 3.0, damagetype);
			}
		}
		
		if(IsPlayerHaveEffect(victim, 37) && StrEqual(classname, "infected", false))
		{
			// 取消攻击者，避免减速效果
			attacker = inflictor = 0;
		}
	}
	
	// g_iOldRealHealth[victim] = GetEntProp(victim, Prop_Data, "m_iHealth");
	return Plugin_Changed;
}

/*
public void ZombieHook_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype,
	int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(!IsValidEntity(victim) || !IsValidClient(attacker) || damage <= 0.0 || GetClientTeam(attacker) != 2 || (damagetype & DMG_FALL))
		return;
	
	if((damagetype & DMG_CRIT) && (damagetype & (DMG_BULLET|DMG_BUCKSHOT)) && IsValidAliveClient(attacker) && g_bAccurateShot[attacker] && !IsNullVector(damagePosition))
	{
		float vStart[3];
		GetClientEyePosition(attacker, vStart);
		
		TE_SetupBeamPoints(vStart, damagePosition, g_BeamSprite, 0, 0, 0, 0.1, 0.01, 0.08, 1, 0.0, {0, 0, 200, 230}, 0);
		TE_SendToAll();
	}
}
*/

/*
public void PlayerHook_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype,
	int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(!IsValidAliveClient(victim) || attacker <= 0 || damage <= 0.0 || (damagetype & DMG_FALL))
		return;
	
	if((damagetype & DMG_CRIT) && (damagetype & (DMG_BULLET|DMG_BUCKSHOT)) && IsValidAliveClient(attacker) && g_bAccurateShot[attacker] && !IsNullVector(damagePosition))
	{
		float vStart[3];
		GetClientEyePosition(attacker, vStart);
		
		TE_SetupBeamPoints(vStart, damagePosition, g_BeamSprite, 0, 0, 0, 0.1, 0.01, 0.08, 1, 0.0, {0, 0, 200, 230}, 0);
		TE_SendToAll();
	}
}
*/

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity <= MaxClients || entity > 2048)
		return;
	
	// 敌人
	if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false) || StrEqual(classname, "tank_rock", false))
		SDKHook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	
	// 自带的易碎物品
	else if(StrEqual(classname, "func_door_rotating", false) || StrEqual(classname, "prop_wall_breakable", false) ||
		StrEqual(classname, "func_breakable", false) || StrEqual(classname, "func_breakable_surf", false) ||
		// 插件兼容，例如某特殊实体的带血量的路障
		StrEqual(classname, "prop_physics", false) || StrEqual(classname, "prop_physics_override", false) ||
		StrEqual(classname, "prop_dynamic", false) || StrEqual(classname, "prop_dynamic_override", false))
		SDKHook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	
	// 可伤害实体
	else if(HasEntProp(entity, Prop_Data, "m_takedamage") && HasEntProp(entity, Prop_Data, "m_iHealth") &&
		GetEntProp(entity, Prop_Data, "m_takedamage") == 2 && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
		SDKHook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	
	/*
	if(StrContains(classname, "_projectile", false) > 0)
		SDKHook(entity, SDKHook_SpawnPost, EntityHook_OnProjectileSpawned);
	*/
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	SDKUnhook(entity, SDKHook_TraceAttack, ZombieHook_OnTraceAttack);
	// SDKUnhook(entity, SDKHook_TraceAttackPost, ZombieHook_OnTraceAttackPost);
	// SDKUnhook(entity, SDKHook_OnTakeDamagePost, ZombieHook_OnTakeDamagePost);
	SDKUnhook(entity, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	// SDKUnhook(entity, SDKHook_OnTakeDamagePost, PlayerHook_OnTakeDamagePost);
	SDKUnhook(entity, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKUnhook(entity, SDKHook_TraceAttackPost, PlayerHook_OnTraceAttackPost);
	SDKUnhook(entity, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKUnhook(entity, SDKHook_PostThinkPost, PlayerHook_OnPostThinkPost);
	SDKUnhook(entity, SDKHook_GetMaxHealth, PlayerHook_OnGetMaxHealth);
	SDKUnhook(entity, SDKHook_PreThink, PlayerHook_OnReloadThink);
	SDKUnhook(entity, SDKHook_WeaponSwitchPost, PlayerHook_OnReloadStopped);
	SDKUnhook(entity, SDKHook_WeaponDropPost, PlayerHook_OnReloadStopped);
	SDKUnhook(entity, SDKHook_SetTransmit, GlowHook_SetTransmit);
	SDKUnhook(entity, SDKHook_WeaponCanUse, PlayerHook_OnWeaponCanUse);
}

public void ZombieHook_OnSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, ZombieHook_OnSpawned);
	SDKHook(entity, SDKHook_TraceAttack, ZombieHook_OnTraceAttack);
	// SDKHook(entity, SDKHook_TraceAttackPost, ZombieHook_OnTraceAttackPost);
	// SDKHook(entity, SDKHook_OnTakeDamagePost, ZombieHook_OnTakeDamagePost);
}

/*
public void EntityHook_OnProjectileSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, EntityHook_OnProjectileSpawned);

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(!IsValidAliveClient(client))
		return;
	
	static char classname[64];
	GetEntityClassname(entity, classname, 64);
	if(g_clSkill_5[client] & SKL_5_RocketDude)
	{
		if(StrEqual(classname, "grenade_launcher_projectile", false) ||
			StrEqual(classname, "spitter_projectile", false))
		{
			// 把它变成跟踪的
			CreateMissiles(client, entity);
		}
	}
}
*/

/*
public void ZombieHook_OnTraceAttackPost(int victim, int attacker, int inflictor, float damage, int damagetype,
	int ammotype, int hitbox, int hitgroup)
{
	if(!IsValidClient(attacker))
		return;
	
	if((damagetype & DMG_CRIT) && g_bAccurateShot[attacker])
		g_bAccurateShot[attacker] = false;
}
*/

// 临时、根据情况的不在这里计算
void CalcDamageExtra(int attacker, int& chance, int& minChDmg, int& maxChDmg, int& baseDmg)
{
	if(!IsValidClient(attacker))
		return;
	
	chance = 0;
	minChDmg = 50;
	maxChDmg = 100;
	baseDmg = 0;
	
	// 技能和事件的几率加成
	if(g_clSkill_1[attacker] & SKL_1_DmgExtra)
		chance += 5;
	if(g_clSkill_4[attacker] & SKL_4_DmgExtra)
		chance += 20;
	
	for(int i = 0; i < 4; ++i)
	{
		if(!g_clCurEquip[attacker][i])
			continue;
		
		static char key[16];
		IntToString(g_clCurEquip[attacker][i], key, sizeof(key));
		
		static EquipData_t data;
		if(!g_mEquipData[attacker].GetArray(key, data, sizeof(data)) || !data.valid)
			continue;
		
		// 暴击率
		if(data.crit > 0)
			chance += data.crit;
		
		// 装备附加技能
		if(data.effect == 8)
			chance += 5;
		
		/*
		// 装备前缀
		if(data.prefix == EquipPrefix_Lucky)
			chance += 2;
		*/
		
		// 装备伤害
		if(data.damage > 0)
			baseDmg += data.damage;
		
		// 暴击伤害加成
		if(data.effect == 6)
			maxChDmg += 200;
	}
	
	if(g_clSkill_4[attacker] & SKL_4_MoreDmgExtra)
		maxChDmg += 200;
	
	if(g_clSkill_5[attacker] & SKL_5_DmgExtra)
	{
		chance += chance / 3;
		minChDmg /= 3;
		maxChDmg /= 3;
	}
}

public Action ZombieHook_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &ammotype, int hitbox, int hitgroup)
{
	if(!IsValidEdict(victim) || !IsValidClient(attacker) || damage <= 0.0/* || GetClientTeam(attacker) != 2*/ || (damagetype & DMG_FALL))
		return Plugin_Continue;
	
	// 子弹、钢珠弹(霰弹)、砍击、钝击
	if(!(damagetype & (DMG_BULLET|DMG_BUCKSHOT|DMG_SLASH|DMG_CLUB)))
		return Plugin_Continue;
	
	if(HasEntProp(victim, Prop_Data, "m_takedamage") && GetEntProp(victim, Prop_Data, "m_takedamage") == 0)
		return Plugin_Continue;
	
	/*
	// 忽略非主武器的攻击
	if(ammotype <= 2 || ammotype >= 12 || !(damagetype & (DMG_BULLET|DMG_BUCKSHOT)))
		return Plugin_Continue;
	*/
	
	// 狙击枪伤害增加
	if(ammotype == AMMOTYPE_SNIPERRIFLE && (g_clSkill_4[attacker] & SKL_4_SniperExtra))
	{
		static char className[64];
		if(IsValidEntity(inflictor) && IsValidEdict(inflictor))
		{
			GetEntityClassname(inflictor, className, 64);
			if(StrEqual(className, "weapon_sniper_awp", false))
				damage *= 3;
			else if(StrEqual(className, "weapon_sniper_scout", false))
				damage *= 2;
		}
	}
	
	int chance = g_iDamageChance[attacker];
	int minChDmg = g_iDamageChanceMin[attacker];
	int maxChDmg = g_iDamageChanceMax[attacker];
	int baseDmg = g_iDamageBase[attacker];
	float originalDamage = damage;
	
	if(victim > MaxClients)
	{
		// 可能不需要马格南，因为这个已经是可以秒普感了
		if((g_clSkill_5[attacker] & SKL_5_Overkill) &&
			(damagetype & (DMG_BULLET|DMG_BUCKSHOT)) &&
			ammotype > AMMOTYPE_PISTOL && ammotype < AMMOTYPE_TURRET && !GetRandomInt(0, 3))
			chance += 250;
	}
	
	if(g_bIsAngryCritActive)
		chance += 500;
	
	if(g_bAccurateShot[attacker] || GetRandomInt(1, 1000) <= chance)
	{
		// ClientCommand(attacker, "play \"ui/pickup_secret01.wav\"");
		
		if(!IsFakeClient(attacker))
		{
			if(g_bAccurateShot[attacker])
				ClientCommand(attacker, "play \"ui/pickup_secret01.wav\"");
			else
				ClientCommand(attacker, "play \"ui/littlereward.wav\"");
		}
		
		damage += originalDamage * GetRandomInt(minChDmg, maxChDmg) / 100.0;
		damagetype |= DMG_CRIT;
		// g_bAccurateShot[attacker] = false;
		
		/*
		if(g_pCvarAllow.BoolValue)
		{
			// PrintHintText(attacker, "暴击伤害：%d丨额外伤害：%d", extraChanceDamage, extraDamage);
			PrintCenterText(attacker, "暴击伤害：%d丨额外伤害：%d", extraChanceDamage, extraDamage);
		}
		*/
	}
	
	damage += originalDamage * baseDmg / 100.0;
	return Plugin_Changed;
}

public Action:EventRevive(Handle:timer, any:client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(IsPlayerHaveEffect(client, 20))
		{
			int attacker = -1;
			if(((attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker")) > 0 ||
				(attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker")) > 0 ||
				(attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner")) > 0 ||
				(attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker")) > 0 ||
				(attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker")) > 0) &&
				IsValidAliveClient(attacker)
			)
				ForcePlayerSuicide(attacker);
		}
		
		RevivePlayer(client);
	}
}

public void Event_HealSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	int health = event.GetInt("health_restored");

	/*
	static ConVar cv_percent;
	if(cv_percent == null)
		cv_percent = FindConVar("first_aid_heal_percent");
	*/

	if(!IsValidAliveClient(client) || !IsValidAliveClient(subject))
		return;
	
	/*
	int maxHealth = GetEntProp(subject, Prop_Send, "m_iMaxHealth");
	int lossHealth = maxHealth - GetEntProp(subject, Prop_Data, "m_iHealth") + health;
	int lastHealth = maxHealth - lossHealth;
	if(lastHealth < 10)
	{
		// 治疗量为血量上限的 80％
		health = RoundToCeil(maxHealth * cv_percent.FloatValue);
		SetEntProp(subject, Prop_Data, "m_iHealth", health);
		health -= lastHealth;
	}
	else if(lossHealth >= 10)
	{
		// 治疗量为已损失的血量的 80％
		health = RoundToCeil(lossHealth * cv_percent.FloatValue);
		SetEntProp(subject, Prop_Data, "m_iHealth", lastHealth + health);
	}
	else
	{
		// 治疗量为全部血量
		health = maxHealth;
		SetEntProp(subject, Prop_Data, "m_iHealth", maxHealth);
		// SetVariantInt(999);
		// AcceptEntityInput(subject, "SetHealth", client, subject);
	}
	*/
	
	if(g_bIsGamePlaying && client != subject && health >= 50)
	{
		g_ttDefibUsed[client] += 1;
		if(g_fForgiveOfFF[client] >= GetEngineTime() && g_iForgiveFFTarget[client] == GetClientUserId(subject))
		{
			g_fForgiveOfFF[client] = 0.0;
			g_iForgiveFFTarget[client] = 0;
			g_ttDefibUsed[client]--;
			
			GiveSkillPoint(client, 1);
			if(g_pCvarAllow.BoolValue && !IsFakeClient(client))
				PrintToChat(client, "\x03[\x05提示\x03]\x04 你因为给队友 打包 而获得了 \x051\x01 硬币。");
		}
		
		if(g_pCvarDefibUsed.IntValue > 0 && g_ttDefibUsed[client] >= g_pCvarDefibUsed.IntValue)
		{
			GiveSkillPoint(client, 1);
			g_ttDefibUsed[client] -= g_pCvarDefibUsed.IntValue;

			if(g_pCvarAllow.BoolValue && !IsFakeClient(client))
				PrintToChat(client, "\x03[\x05提示\x03]\x04 你因为多次给队友 电击/打包 而获得了 \x051\x01 硬币。");
		}
	}
	
	if((g_clSkill_2[subject] & SKL_2_HealBouns) || (g_clSkill_2[client] & SKL_2_HealBouns))
		AddHealth(subject, 50, false);
	
	if(g_bIsGamePlaying && (g_clSkill_3[client] & SKL_3_ReviveBonus) && client != subject)
		GiveHelpBouns(client);
	
	int mulEffect = IsPlayerHaveEffect(subject, 34);
	if((g_clSkill_1[subject] & SKL_1_Armor) && mulEffect > 0)
	{
		AddArmor(subject, 50 * mulEffect);
	}
	
	RemoveGlowModel(subject);
	
	if(g_iRoundEvent == 19)
	{
		ApplyHealthSwap(subject);
	}
}

public Action:Event_PillsUsed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) return;
	if(IsClientConnected(client))
	{
		int mulEffect = IsPlayerHaveEffect(client, 2);
		if(mulEffect > 0)
		{
			// SDKCall(sdkAdrenaline, client, 30.0);
			// CheatCommand(client, "script", "GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(client), 30);
			L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(client), 10 * mulEffect);
		}
	}
}

public void Event_PlayerIncapacitatedStart(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidAliveClient(client) || GetClientTeam(client) != 2)
		return;
	
	if(g_clSkill_2[client] & SKL_2_Magnum)
	{
		int weapon = GetPlayerWeaponSlot(client, 1);
		if(weapon > MaxClients && IsValidEntity(weapon))
		{
			char classname[64];
			GetEntityClassname(weapon, classname, 64);
			if(StrEqual(classname, "weapon_melee", false))
				GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", classname, 64);
			
			strcopy(g_sLastWeapon[client], sizeof(g_sLastWeapon[]), classname);
			g_iLastWeaponClip[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");
			g_bLastWeaponDual[client] = (HasEntProp(weapon, Prop_Send, "m_hasDualWeapons") && GetEntProp(weapon, Prop_Send, "m_hasDualWeapons", 1));
		}
	}
}

public Action:Event_PlayerIncapacitated(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsValidAliveClient(client))
		return;
	
	float time = GetEngineTime();
	if(GetClientTeam(client) != 2)
	{
		// 修复 Tank 死亡冻结 bug
		if(g_fFreezeTime[client] > time)
			g_fFreezeTime[client] = time;
		
		RemoveGlowModel(client);
		return;
	}
	
	if (g_clSkill_2[client] & SKL_2_SelfHelp)
	{
		int chance = 1 + IsPlayerHaveEffect(client, 17);
		if(GetRandomInt(0, 3) < chance)
		{
			CreateTimer(3.0, EventRevive, client);
			
			if(!IsFakeClient(client))
				PrintToChat(client, "\x03「顽强」\x01你将会在\x053\x01秒后倒地自救(如果那时没被控)!");
		}
	}

	g_bIsPaincIncap = true;
	g_ttPaincEvent[client] = 0;
	bool tk = (IsValidAliveClient(attacker) && GetClientTeam(attacker) == 2);

	float origin[3], position[3];
	GetClientAbsOrigin(client, origin);

	if(g_clSkill_3[client] & SKL_3_Freeze)
	{
		float radius = 250.0 * (1 + IsPlayerHaveEffect(client, 24));
		
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsValidAliveClient(i) || GetClientTeam(i) != 3)
				continue;

			// GetEntPropVector(i, Prop_Send, "m_vecOrigin", position);
			GetClientAbsOrigin(i, position);
			if(GetVectorDistance(origin, position, false) > radius)
				continue;
			
			// ServerCommand("sm_freeze \"%N\" \"12\"", i);
			FreezePlayer(i, 12.0);
		}

		if(!tk && attacker > 0 && attacker <= MaxClients)
		{
			// 先推开再冻结
			if(g_clSkill_2[client] & SKL_2_Defensive)
				L4D_StaggerPlayer(attacker, client, NULL_VECTOR);
			
			// ServerCommand("sm_freeze \"%N\" \"12\"",attacker);
			FreezePlayer(attacker, 12.0);
			
			// new String:name[32];
			// GetClientName(attacker, name, 32);
			// PrintToChatAll("\x03[\x05提示\x03] %N\x04使用\x03释冰\x04天赋冻结了\x03%s\x0412秒!",client,name);
			PrintToChat(client, "\x03「释冰」\x01冻结了攻击者 \x04%N\x05 12 \x01秒", attacker);
		}
		
		if(g_pCvarAllow.BoolValue)
		{
			// (目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度(20.0),播放振幅, 颜色, 播放速度(10), 标识(0))
			TE_SetupBeamRingPoint(origin, 2.0, radius, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 12.0, 1.0, {0, 0, 255, 255}, 0, 0);
			TE_SendToAll();
		}
	}

	if((g_clSkill_3[client] & SKL_3_IncapFire))
	{
		char classname[64];
		float radius = 175.0 * (1 + IsPlayerHaveEffect(client, 25));
		
		for(int i = MaxClients + 1; i <= 2048; ++i)
		{
			if(!IsValidEntity(i) || !IsValidEdict(i))
				continue;
			
			GetEdictClassname(i, classname, 64);
			if(!StrEqual(classname, "infected", false))
				continue;
			
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", position);
			if(GetVectorDistance(origin, position, false) > radius)
				continue;
			
			DealDamage(client, i, 1, DMG_BURN);
			SetEntProp(i, Prop_Send, "m_bIsBurning", 1);
		}

		if(!tk && attacker > 0 && attacker <= MaxClients)
		{
			new extradmg = 150;
			int mulEffect = IsPlayerHaveEffect(client, 5);
			if(mulEffect > 0) extradmg += 100 * mulEffect;

			DealDamage(client, attacker, extradmg, DMG_BURN);
			IgniteEntity(attacker, 60.0, true);

			// new String:name[32];
			// GetClientName(attacker, name, 32);
			// PrintToChatAll("\x03[\x05提示\x03] %N\x04使用\x03纵火\x04天赋给予\x03%s %d\x04点伤害并燃烧60秒!",client,name,extradmg);
			PrintToChat(client, "\x03「纵火」\x01点燃了攻击者 \x04%N\x05 60 \x01秒", attacker);
		}
		
		if(g_pCvarAllow.BoolValue)
		{
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度(20.0),播放振幅, 颜色, 播放速度(10), 标识(0))
			TE_SetupBeamRingPoint(origin, 2.0, radius, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 12.0, 1.0, {255, 0, 0, 255}, 0, 0);
			TE_SendToAll();
		}
	}
	
	if((g_clSkill_2[client] & SKL_2_Magnum) && g_sLastWeapon[client][0] != EOS)
	{
		int weapon = GetPlayerWeaponSlot(client, 1);
		if(weapon > MaxClients && IsValidEntity(weapon))
			RemoveEntity(weapon);
		
		CheatCommand(client, "give", "pistol_magnum");
		CreateTimer(0.1, Timer_CheckHavePistol, client);
	}
	
	if(tk && attacker != client)
	{
		GiveSkillPoint(attacker, -1);
		g_fForgiveOfFF[attacker] = GetEngineTime() + 45.0;
		g_iForgiveFFTarget[attacker] = GetClientUserId(client);
		
		if(!IsFakeClient(attacker) && g_pCvarAllow.BoolValue)
			PrintToChat(attacker, "\x03[提示]\x01 你因为放倒队友而失去了 \x051\x01 硬币。");
	}
	
	if(g_fFreezeTime[client] > time && IsPlayerHaveEffect(client, 16))
	{
		// 取消冰冻效果
		g_fFreezeTime[client] = time;
	}
	
	if(GetCurrentAttacker(client) > 0)
	{
		// 被控 橙色
		CreateGlowModel(client, 0x4080FF);
	}
	else
	{
		// 倒地 黄色
		CreateGlowModel(client, 0x80FFFF);
	}
	
	if(g_iRoundEvent == 14)
	{
		SetEntProp(client, Prop_Data, "m_iHealth", 1);
		SDKHooks_TakeDamage(client, 0, attacker, 666.0, DMG_FALL);
	}
}

public Action Timer_CheckHavePistol(Handle timer, any client)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon == -1 || !IsValidEntity(weapon))
		CheatCommand(client, "give", "pistol_magnum");
	
	return Plugin_Continue;
}

/*
public void PlayerHook_OnTraceAttackPost(int victim, int attacker, int inflictor, float damage, int damagetype,
	int ammotype, int hitbox, int hitgroup)
{
	if(!IsValidClient(attacker))
		return;
	
	if((damagetype & DMG_CRIT) && g_bAccurateShot[attacker])
		g_bAccurateShot[attacker] = false;
}
*/

public Action PlayerHook_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
	int &ammotype, int hitbox, int hitgroup)
{
	if(!IsValidAliveClient(victim) || !IsValidClient(attacker) || (damagetype & DMG_FALL))
		return Plugin_Continue;
	
	// 榴弹炸自己
	if(attacker == victim && (g_clSkill_5[attacker] & SKL_5_RocketDude) && inflictor > MaxClients)
	{
		static char classname[32];
		if(GetEdictClassname(inflictor, classname, sizeof(classname)) &&
			StrEqual(classname, "grenade_launcher_projectile", false))
		{
			float vPos[3], vDir[3], vVel[3], nVel[3], nDir[3];
			GetEntPropVector(inflictor, Prop_Send, "m_vecOrigin", vPos);
			// GetClientAbsOrigin(victim, vDir);
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vDir);
			GetEntDataVector(victim, g_iVelocityO, vVel);
			
			SubtractVectors(vDir, vPos, vDir);
			NormalizeVector(vDir, vDir);
			
			NormalizeVector(vVel, nVel);
			nDir[0] = vDir[0]; nDir[1] = vDir[1]; nDir[2] = 0.0; nVel[2] = 0.0;
			
			ScaleVector(vDir, 300.0);
			vDir[2] *= 1.5;
			
			if(GetVectorDotProduct(nVel, nDir) >= 0.0)
			{
				// 方向相同
				AddVectors(vVel, vDir, vVel);
			}
			else
			{
				// 方向相反
				vDir[0] = -vDir[0]; vDir[1] = -vDir[1];
				AddVectors(vVel, vDir, vVel);
			}
			
			TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vVel);
			// SetEntPropVector(victim, Prop_Send, "m_vecBaseVelocity", vVel);
			
			// 避免掉落伤害、榴弹伤害降低
			g_bOnRocketDude[victim] = true;
			// damage /= 4.0;
			return Plugin_Changed;
		}
	}
	
	if(damage <= 0.0 || hitbox <= 0)
		return Plugin_Continue;
	
	int attackerTeam = GetClientTeam(attacker);
	int victimTeam = GetClientTeam(victim);
	
	int chance = g_iDamageChance[attacker];
	int minChDmg = g_iDamageChanceMin[attacker];
	int maxChDmg = g_iDamageChanceMax[attacker];
	int baseDmg = g_iDamageBase[attacker];
	float originalDamage = damage;
	
	if(g_bIsAngryCritActive)
		chance += 500;
	
	// 生还者攻击特感
	if(attackerTeam == TEAM_SURVIVORS && victimTeam == TEAM_INFECTED)
	{
		// 榴弹伤害增加
		/*
		if((g_clSkill_5[attacker] & SKL_5_RocketDude) && inflictor > MaxClients)
		{
			static char classname[32];
			GetEdictClassname(inflictor, classname, sizeof(classname));
			if(StrEqual(classname, "grenade_launcher_projectile", false))
			{
				float vPos[3];
				GetEntPropVector(inflictor, Prop_Send, "m_vecOrigin", vPos);
				
				// CheatCommand(attacker, "script", "GetPlayerFromUserID(%d).Stagger(Vector(%f,%f,%f))", GetClientUserId(victim), vPos[0], vPos[1], vPos[2]);
				L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%.0f,%.0f,%.0f))", GetClientUserId(victim), vPos[0], vPos[1], vPos[2]);
				
				damage *= 5;
				if(classname[0] == 'p')
					damage *= 2;
				
				return Plugin_Changed;
			}
		}
		*/
		
		// 子弹、钢珠弹(霰弹)、砍击、钝击
		if(!(damagetype & (DMG_BULLET|DMG_BUCKSHOT|DMG_SLASH|DMG_CLUB)))
			return Plugin_Continue;
		
		/*
		// 忽略非主武器的射击
		if(ammotype <= 2 || ammotype >= 12 || !(damagetype & (DMG_BULLET|DMG_BUCKSHOT)))
			return Plugin_Continue;
		*/
		
		// 狙击枪伤害增加
		if(ammotype == AMMOTYPE_SNIPERRIFLE && (g_clSkill_4[attacker] & SKL_4_SniperExtra))
		{
			static char className[64];
			if(inflictor > MaxClients)
			{
				GetEntityClassname(inflictor, className, 64);
				if(StrEqual(className, "weapon_sniper_awp", false))
				{
					damage *= 3;
					originalDamage = damage;
				}
				else if(StrEqual(className, "weapon_sniper_scout", false))
				{
					damage *= 2;
					originalDamage = damage;
				}
			}
		}
		
		if(g_bAccurateShot[attacker] || GetRandomInt(1, 1000) <= chance)
		{
			if(!IsFakeClient(victim))
				ClientCommand(victim, "play \"plats/churchbell_end.wav\"");
			
			// ClientCommand(attacker, "play \"ui/pickup_secret01.wav\"");
			
			if(!IsFakeClient(attacker))
			{
				if(g_bAccurateShot[attacker])
					ClientCommand(attacker, "play \"ui/pickup_secret01.wav\"");
				else
					ClientCommand(attacker, "play \"ui/littlereward.wav\"");
			}
			
			damage += originalDamage * GetRandomInt(minChDmg, maxChDmg) / 100.0;
			damagetype |= DMG_CRIT;
			// g_bAccurateShot[attacker] = false;
			
			if((g_clSkill_3[attacker] & SKL_3_Kickback) && !GetRandomInt(0, 2))
			{
				// Charge(victim, attacker, 250.0, 250.0);
				/*
				float vPos[3];
				GetClientAbsOrigin(attacker, vPos);
				L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%.0f,%.0f,%.0f))", GetClientUserId(victim), vPos[0], vPos[1], vPos[2]);
				*/
				
				float vAng[3], vDir[3];
				GetClientEyeAngles(attacker, vAng);
				GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(vDir, 300.0 * (1 + IsPlayerHaveEffect(attacker, 23)));
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vDir);
			}
			
			/*
			if(g_pCvarAllow.BoolValue)
				PrintHintText(attacker, "暴击伤害：%d丨额外伤害：%d", extraChanceDamage, extraDamage);
			*/
		}
		
		damage += originalDamage * baseDmg / 100.0;
		return Plugin_Changed;
	}
	// 特感攻击生还者
	else if(attackerTeam == TEAM_INFECTED && victimTeam == TEAM_SURVIVORS)
	{
		// 子弹、钢珠弹(霰弹)、燃烧、野火、电击
		if(damagetype & (DMG_BULLET|DMG_BUCKSHOT|DMG_BURN|DMG_SLOWBURN|DMG_SHOCK))
			return Plugin_Continue;
		
		if(GetRandomInt(1, 1000) <= chance)
		{
			if(!IsFakeClient(victim))
				ClientCommand(victim, "play \"plats/churchbell_end.wav\"");
			
			if(!IsFakeClient(attacker))
				ClientCommand(attacker, "play \"ui/pickup_secret01.wav\"");
			
			damage += originalDamage * GetRandomInt(minChDmg, maxChDmg) / 100.0;
			damagetype |= DMG_CRIT;
			
			if((g_clSkill_3[attacker] & SKL_3_Kickback) && !IsSurvivorHeld(victim))
			{
				new RanChance = 2;
				if(GetRandomInt(1,4) > RanChance)
					Charge(victim, attacker);
			}
			
			/*
			if(g_pCvarAllow.BoolValue)
				PrintCenterText(attacker, "暴击伤害：%d丨额外伤害：%d", extraChanceDamage / 10, extraDamage / 5);
			*/
		}
		
		damage += originalDamage * baseDmg / 100.0;
		return Plugin_Changed;
	}
	/*
	else if(attackerTeam == victimTeam && ((g_clSkill_5[attacker] & SKL_5_RocketDude) || (g_clSkill_5[victim] & SKL_5_RocketDude)) && inflictor > MaxClients)
	{
		static char classname[32];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		if(StrEqual(classname, "grenade_launcher_projectile", false))
		{
			damage /= 4.0;
			return Plugin_Changed;
		}
	}
	*/
	
	return Plugin_Continue;
}

/*
stock void PrintCenterTextEx(int client, const char[] msg, any ...)
{
	for(int i = MAX_CACHED_MESSAGES - 1; i > 0; --i)
		strcopy(g_sCacheMessage[client][i], sizeof(g_sCacheMessage[][]), g_sCacheMessage[client][i-1]);
	
	VFormat(g_sCacheMessage[client][0], sizeof(g_sCacheMessage[][]), msg, 3);
	
	char buffer[255];
	for(int i = MAX_CACHED_MESSAGES - 1; i >= 0; --i)
		Format(buffer, sizeof(buffer), "%s\n", g_sCacheMessage[client][i]);
	PrintCenterText(client, buffer);
	
	Handle killer = g_hClearCacheMessage[client];
	g_hClearCacheMessage[client] = CreateTimer(2.5, Timer_ClearCacheMessage, client);
	
	if(killer != null)
		KillTimer(killer);
}

public Action Timer_ClearCacheMessage(Handle timer, any client)
{
	g_hClearCacheMessage[client] = null;
	for(int i = 0; i < MAX_CACHED_MESSAGES; ++i)
		g_sCacheMessage[client][i][0] = EOS;
}
*/

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	bool attackPlayer = IsValidClient(attacker);

	if(!IsValidClient(victim))
		return;

	static char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	int dmg = GetEventInt(event, "dmg_health");
	int dmg_type = event.GetInt("type");
	
	if (attackPlayer && (StrEqual(weapon, "tank_claw") || StrEqual(weapon, "tank_rock")) &&
		GetClientTeam(victim) == 2 && !GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
	{
		/*
		new RandomIce = GetRandomInt(0, 5);
		if (RandomIce == 5) CreateTimer(1.0, BoomerIce, victim);
		*/

		if ((g_clSkill_4[victim] & SKL_4_ClawHeal))
		{
			new hp = dmg * GetRandomInt(20, 90) / 100;
			// SetEntProp(victim,Prop_Send,"m_iHealth",GetEntProp(victim,Prop_Send,"m_iHealth")+hp);
			AddHealth(victim, hp);
			
			if(!IsFakeClient(victim))
				PrintToChat(victim,"\x03[\x05提示\x03]\x04你使用\x03坚韧\x04天赋随机恢复\x03%d\x04HP!",hp);
		}
	}

	if (attackPlayer && GetClientTeam(victim) == TEAM_INFECTED && GetClientTeam(attacker) == 2)
	{
		if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
		{
			if(StrEqual(weapon, "melee") || StrEqual(weapon, "chainsaw"))
			{
				int mulEffect = IsPlayerHaveEffect(attacker, 11);
				if (mulEffect > 0)
				{
					// ServerCommand("sm_freeze \"%N\" \"5\"",victim);
					FreezePlayer(victim, 1.0 * mulEffect);
				}
			}
		}
		
		bool isGunShot = (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "smg_mp5")
			|| StrEqual(weapon, "rifle") || StrEqual(weapon, "rifle_sg552") || StrEqual(weapon, "rifle_ak47")
			|| StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas") || StrEqual(weapon, "rifle_m60")
			|| StrEqual(weapon, "sniper_awp") || StrEqual(weapon, "sniper_military") || StrEqual(weapon, "sniper_scout")
			|| StrEqual(weapon, "hunting_rifle") || StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome")
			|| StrEqual(weapon, "grenade_launcher") || StrEqual(weapon, "rifle_desert")
		);
		bool isMeleeHack = (StrEqual(weapon, "melee"));
		
		if (isGunShot || isMeleeHack)
		{
			if ((g_clSkill_5[attacker] & SKL_5_RetardBullet) && !GetRandomInt(0, 5))
			{
				if (!g_bHasRetarding[victim])
				{
					g_bHasRetarding[victim] = true;
					new Float:vec[3];
					GetClientEyePosition(victim, vec);
					EmitAmbientSound(SOUND_FREEZE, vec, victim, SNDLEVEL_RAIDSIREN);
					g_fOldMovement[victim] = GetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue");
					SetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue", g_fOldMovement[victim] * 0.55);
					CreateTimer(1.0, Timer_StopRetard, victim);
				}
			}
			
			if(dmg_type & DMG_CRIT)
			{
				int mulEffect = IsPlayerHaveEffect(attacker, 12);
				if (mulEffect > 0)
				{
					// SetEntProp(attacker,Prop_Send,"m_iHealth",GetEntProp(attacker,Prop_Send,"m_iHealth")+5);
					AddHealth(attacker, 5 * mulEffect);
				}
			}
			
			// 【嗜血如命】激活时允许主武器触发，否则只能由近战武器触发
			if ((g_bIsAngryBloodthirstyActive || isMeleeHack) && (g_bIsAngryBloodthirstyActive || (g_clSkill_5[attacker] & SKL_5_Vampire)) && !GetRandomInt(0, 2))
			{
				// SetEntProp(attacker,Prop_Send,"m_iHealth",GetEntProp(attacker,Prop_Send,"m_iHealth")+1);
				
				int health = dmg / 30;
				AddHealth(attacker, (health > 1 ? health : 1));
				// ClientCommand(attacker, "play \"ui/littlereward.wav\"");
				
				if (!g_bHasVampire[attacker])
				{
					g_bHasVampire[attacker] = true;
					g_fOldMovement[attacker] = GetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue");
					SetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue", g_fOldMovement[attacker] * 1.15);
					CreateTimer(1.0, Timer_StopVampire, attacker);
				}
			}
		}
		
		if((g_clSkill_1[attacker] & SKL_1_DisplayHealth) && (dmg_type & (DMG_BULLET|DMG_BUCKSHOT|DMG_SLASH|DMG_CLUB)) && !IsFakeClient(attacker))
		{
			int health = GetEventInt(event, "health");
			bool headshot = event.GetBool("headshot");
			
			if(!(dmg_type & DMG_BUCKSHOT))
			{
				PrintCenterText(attacker, "%N|%s伤害%d|%s", victim, ((dmg_type & DMG_CRIT) ? "暴击" : ""), dmg, ((health<=0) ? (headshot?"爆头":"击杀") : tr("剩余%d", health)));
			}
			else
			{
				if(g_mTotalDamage[attacker] == null)
				{
					g_mTotalDamage[attacker] = CreateTrie();
					RequestFrame(NotifyDamageInfo, attacker);
				}
				
				static char eRef[12];
				IntToString(EntIndexToEntRef(victim), eRef, sizeof(eRef));
				
				TDInfo_t td;
				if(g_mTotalDamage[attacker].GetArray(eRef, td, sizeof(td)))
				{
					td.dmg += dmg;
					td.dmg_type |= dmg_type;
					td.headshot |= headshot;
					td.death = (health <= 0);
				}
				else
				{
					td.dmg = dmg;
					td.dmg_type = dmg_type;
					td.headshot = headshot;
					td.death = (health <= 0);
				}
				
				g_mTotalDamage[attacker].SetArray(eRef, td, sizeof(td));
			}
		}
	}
	else if(attackPlayer && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker) &&
		GetEntProp(victim, Prop_Send, "m_isIncapacitated") && IsSurvivorHeld(victim))
	{
		int zombieType = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if((g_clSkill_2[victim] & SKL_2_Defensive) && (zombieType == ZC_HUNTER || zombieType == ZC_SMOKER ||
			zombieType == ZC_JOCKEY || zombieType == ZC_CHARGER || zombieType == ZC_TANK))
		{
			// 推开控制者
			// Charge(attacker, victim);
			
			// float vPos[3];
			// GetClientAbsOrigin(victim, vPos);
			// L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(attacker), GetClientUserId(victim));
			L4D_StaggerPlayer(attacker, victim, NULL_VECTOR);
		}
	}
	
	int attackerId = event.GetInt("attackerentid");
	if(GetClientTeam(victim) == 2 && !(dmg_type & (DMG_FALL|DMG_BURN|DMG_BLAST|DMG_SHOCK|DMG_DROWN|DMG_SLOWBURN)))
	{
		bool isInfected = (attackPlayer && GetClientTeam(attacker) == 3);
		if(!isInfected && attackerId > 0 && IsValidEntity(attackerId) && IsValidEdict(attackerId))
		{
			static char classname[64];
			GetEdictClassname(attackerId, classname, 64);
			isInfected = (StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false));
		}
		
		if(isInfected)
		{
			int amount = 0;
			if(GetEntProp(victim, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1))
				amount = (dmg > 3 ? 3 : dmg);
			else
				amount = (dmg > 10 ? 10 : dmg);
			
			GiveAngryPoint(victim, amount);
			
			int tempHealth = GetPlayerTempHealth(victim);
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");
			int maxHealth = GetEntProp(victim, Prop_Send, "m_iMaxHealth");
			if((g_pfnIsInvulnerable == null || SDKCall(g_pfnIsInvulnerable, victim) <= 0) &&
				!GetEntProp(victim, Prop_Send, "m_isIncapacitated", 1) &&
				!GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1))
			{
				if((g_clSkill_3[victim] & SKL_3_TempSanctuary) && tempHealth > 0)
				{
					if(tempHealth >= dmg)
					{
						tempHealth -= dmg;
						health += dmg;
						dmg = 0;
						SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", float(tempHealth));
						SetEntPropFloat(victim, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntProp(victim, Prop_Data, "m_iHealth", health);
					}
					else
					{
						dmg -= tempHealth;
						health += tempHealth;
						tempHealth = 0;
						SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", 0.0);
						SetEntPropFloat(victim, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntProp(victim, Prop_Data, "m_iHealth", health);
					}
				}
				
				if((g_clSkill_5[victim] & SKL_5_TempRegen) && dmg > 0 && !GetRandomInt(0, 2))
				{
					if(health + tempHealth + dmg <= maxHealth)
					{
						tempHealth += dmg;
						SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", float(tempHealth));
						SetEntPropFloat(victim, Prop_Send, "m_healthBufferTime", GetGameTime());
					}
				}
			}
		}
	}
	
	// 此时还未实际受到伤害，必须等待下一帧才需要更新护甲
	if(attacker > 0 || attackerId > 0)
		RequestFrame(FillExtraArmor, victim);
}

public void FillExtraArmor(any client)
{
	if(!IsValidAliveClient(client))
		return;
	
	int count = g_iExtraArmor[client] + GetEntProp(client, Prop_Send, "m_ArmorValue");
	if(count <= 0)
		return;
	
	if(count > 127)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", 127);
		g_iExtraArmor[client] = count - 127;
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", count);
		g_iExtraArmor[client] = 0;
	}
	
	PrintCenterText(client, "护甲剩余 %d|血量剩余 %d", count, GetEntProp(client, Prop_Data, "m_iHealth") + GetPlayerTempHealth(client));
}

void GiveAngryPoint(int victim, int amount)
{
	if(!IsValidClient(victim))
		return;
	
	if(g_iRoundEvent == 10)
		amount *= 2;
	
	{
		Call_StartForward(g_fwOnAngryPoint);
		Call_PushCell(victim);
		
		int refAmount = amount;
		Call_PushCellRef(refAmount);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return;
		
		if(refResult == Plugin_Changed)
			amount = refAmount;
	}
	
	g_clAngryPoint[victim] += amount;
	
	if(!IsPlayerAlive(victim))
		return;
	
	if(g_clAngryPoint[victim] >= 100 && !g_bIsAngryActive && g_clAngryMode[victim] > 0 && g_pCvarAS.BoolValue)
	{
		g_clAngryPoint[victim] -= 100;
		
		int mulEffect = IsPlayerHaveEffect(victim, 3);
		if(mulEffect > 0)
		{
			g_clAngryPoint[victim] += 10 * mulEffect;
			if(g_iRoundEvent == 10) g_clAngryPoint[victim] += 10 * mulEffect;
		}
		
		TriggerAngrySkill(victim, g_clAngryMode[victim]);
	}
}

void TriggerAngrySkill(int victim, int mode)
{
	int team = GetClientTeam(victim);
	
	{
		Call_StartForward(g_fwOnAngrySkill);
		Call_PushCell(victim);
		
		int refMode = mode;
		Call_PushCellRef(refMode);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return;
		
		if(refResult == Plugin_Changed)
			mode = refMode;
	}
	
	switch(mode)
	{
		case 1:
		{
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(SOUND_GOOD, i);
						// EmitSoundToAll(SOUND_GOOD, i);
						ClientCommand(i, "play \"ui/survival_teamrec.wav\"");
					}
				}

			
			float vLoc[3], vPos[3];
			GetClientAbsOrigin(victim, vLoc);
			bool selfhelp = !!IsPlayerHaveEffect(victim, 36);
			for(new i = 1; i <= MaxClients; i++)
			{
				if(!IsValidAliveClient(i))
					continue;
				
				int et = GetClientTeam(i);
				GetClientAbsOrigin(i, vPos);
				if(et == team && GetVectorDistance(vLoc, vPos) < 1000.0)
				{
					if(!IsPlayerIncapped(i) && !IsSurvivorHeld(i))
						CheatCommand(i, "give", "health");
					else if(selfhelp || IsPlayerHaveEffect(i, 36))
						CreateTimer(3.0, EventRevive, i);
				}
			}
			
			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05王者之仁德\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03附近队友恢复满血，倒地/被控除外\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04王者之仁德\x05（附近队友回血，倒地/被控除外）\x01。");
		}
		case 2:
		{
			g_bIsAngryCritActive = true;
			g_bIsAngryActive = true;
			CreateTimer(40.0, Timer_AngryCritEnd, 0, TIMER_FLAG_NO_MAPCHANGE);
			
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(g_soundLevel, i);
						// EmitSoundToAll(g_soundLevel, i);
						ClientCommand(i, "play \"ui/survival_teamrec.wav\"");
					}
				}
			
			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05霸者之号令\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03全员暴击率+500,持续40秒\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04霸者之号令\x05（全员暴击率+500,持续40秒）\x01。");
		}
		case 3:
		{
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(SOUND_GOOD, i);
						// EmitSoundToAll(SOUND_GOOD, i);
						ClientCommand(i, "play \"ui/pickup_secret01.wav\"");
					}
				}
			
			float vLoc[3], vPos[3];
			GetClientAbsOrigin(victim, vLoc);
			for(new i = 1; i <= MaxClients; i++)
			{
				if(!IsValidAliveClient(i))
					continue;
				
				int et = GetClientTeam(i);
				GetClientAbsOrigin(i, vPos);
				if(et == team && GetVectorDistance(vLoc, vPos) < 1000.0)
					GiveSkillPoint(i, 1);
			}
			
			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05智者之教诲\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03全员硬币+1\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04智者之教诲\x05（全员硬币+1）\x01。");
		}
		case 4:
		{
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(SOUND_BCLAW, i);
						// EmitSoundToAll(SOUND_BCLAW, i);
						ClientCommand(i, "play \"level/bell_normal.wav\"");
					}
				}
			
			float vLoc[3], vPos[3];
			GetClientAbsOrigin(victim, vLoc);
			for(new i = 1; i <= MaxClients; i++)
			{
				if(!IsValidAliveClient(i))
					continue;
				
				int et = GetClientTeam(i);
				GetClientAbsOrigin(i, vPos);
				if(et != team && GetVectorDistance(vLoc, vPos) < 1000.0)
					DealDamage(victim, i, (et == 3 ? 2500 : 25));
			}

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05强者之霸气\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03附近特感受到2500伤害\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04强者之霸气\x05（附近特感受到2500伤害）\x01。");
		}
		case 5:
		{
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(g_soundLevel, i);
						// EmitSoundToAll(g_soundLevel, i);
						ClientCommand(i, "play \"level/gnomeftw.wav\"");
					}
				}
			
			float vLoc[3], vPos[3];
			GetClientAbsOrigin(victim, vLoc);
			for(new i = 1; i <= MaxClients; i++)
			{
				if(!IsValidAliveClient(i))
					continue;
				
				int et = GetClientTeam(i);
				GetClientAbsOrigin(i, vPos);
				if(et == team && GetVectorDistance(vLoc, vPos) < 1000.0)
					L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(i), 50);
			}

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05热血沸腾\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03附近队友兴奋,持续50秒\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04热血沸腾\x05（附近队友兴奋,持续50秒）\x01。");
		}
		case 6:
		{
			g_bIsAngryLastStandActive = true;
			g_bIsAngryActive = true;
			CreateTimer(60.0, Timer_AngryLastStandEnd, 0, TIMER_FLAG_NO_MAPCHANGE);
			
			if(g_pCvarAllow.BoolValue)
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i))
					{
						// EmitSoundToAll(g_soundLevel, i);
						// EmitSoundToAll(g_soundLevel, i);
						ClientCommand(i, "play \"level/scoreregular.wav\"");
					}
				}
			
			if(!IsPlayerIncapped(victim))
			{
				if(GetEntProp(victim, Prop_Send, "m_isHangingFromLedge"))
				{
					int health = L4D2Direct_GetPreIncapHealth(victim) / 2;
					if(health < 1)
						health = 1;
					
					L4D2Direct_SetPreIncapHealth(victim, health);
				}
				else
				{
					int health = GetEntProp(victim,Prop_Send,"m_iHealth") / 2;
					if(health < 1)
						health = 1;
					SetEntProp(victim,Prop_Send,"m_iHealth",health);
				}
			}
			
			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05背水一战\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03自身HP减半,全员获得无限燃烧子弹,持续60秒\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04背水一战\x05（全员获得无限燃烧子弹,持续60秒）\x01。");
		}
		case 7:
		{
			g_bIsAngryBloodthirstyActive = true;
			g_bIsAngryActive = true;
			CreateTimer(75.0, Timer_AngryBloodthirstyEnd, 0, TIMER_FLAG_NO_MAPCHANGE);
			for (new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					// EmitSoundToAll(g_soundLevel, i);
					// EmitSoundToAll(g_soundLevel, i);
					ClientCommand(i, "play \"level/scoreregular.wav\"");
				}
			}

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05嗜血如命\x03】\x04触发怒气技者:\x03%N\x04 效果:\x03全员获得嗜血天赋(主+近),持续75秒\x04.",victim);
			else
				PrintToChat(victim, "\x03[提示]\x01 你触发了怒气技：\x04嗜血如命\x05（全员获得嗜血(主+近)天赋,持续75秒）\x01。");
		}
	}
}

public Action:Timer_AngryCritEnd(Handle:timer, any:client)
{
	g_bIsAngryCritActive = false;
	g_bIsAngryActive = false;
	
	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03【\x05霸者之号令\x03】\x04 已结束。");
	else if(IsValidClient(client))
		PrintToChat(client, "\x03[提示]\x01 \x05霸者之号令\x01 已结束。");
}

public Action:Timer_AngryLastStandEnd(Handle:timer, any:client)
{
	g_bIsAngryLastStandActive = false;
	g_bIsAngryActive = false;
	
	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03【\x05背水一战\x03】\x04 已结束。");
	else if(IsValidClient(client))
		PrintToChat(client, "\x03[提示]\x01 \x05背水一战\x01 已结束。");
}

public Action:Timer_AngryBloodthirstyEnd(Handle:timer, any:client)
{
	g_bIsAngryBloodthirstyActive = false;
	g_bIsAngryActive = false;
	
	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03【\x05嗜血如命\x03】\x04 已结束。");
	else if(IsValidClient(client))
		PrintToChat(client, "\x03[提示]\x01 \x05嗜血如命\x01 已结束。");
}

public Action:SSJ4_DMG(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	EmitSoundToAll(SOUND_Bomb, client);
	new hp = 0;
	if ((g_clSkill_4[client] & SKL_4_ClawHeal))
	{
		hp = GetRandomInt(20, 60);
		if(!IsFakeClient(client))
		{
			ClientCommand(client, "play \"level/timer_bell.wav\"");
			
			if(g_pCvarAllow.BoolValue)
				PrintToChat(client,"\x03[\x05提示\x03]\x04你使用\x03坚韧\x04天赋随机恢复\x03%d\x04HP!",hp);
		}
	}
	DealDamage(client,client,(100 - hp),2);
	Charge(client, client, 1000.0);
}

public Action:Timer_StopVampire(Handle:timer, any:client)
{
	if(g_bHasVampire[client]) g_bHasVampire[client] = false;
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fOldMovement[client]);
}

public Action:Timer_StopRetard(Handle:timer, any:client)
{
	if(g_bHasRetarding[client]) g_bHasRetarding[client] = false;
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fOldMovement[client]);
}

public Action:BoomerIce(Handle:Timer, any:target)
{
	if (!target || !IsClientInGame(target) || !IsPlayerAlive(target)) return;
	// ServerCommand("sm_freeze \"%N\" \"5\"",target);
	FreezePlayer(target, 5.0);
	if(!IsFakeClient(target))
	{
		ClientCommand(target, "play \"level/puck_fail.wav\"");
		PrintCenterText(target, "你悲剧地被打麻痹了!");
	}
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	new attacker = GetClientOfUserId(event.GetInt("attacker"));
	new victim = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(victim))
	{
		int team = GetClientTeam(victim);
		if(team == TEAM_SURVIVORS)
		{
			if (IsValidAliveClient(attacker))
			{
				int attackerTeam = GetClientTeam(attacker);
				if(attackerTeam != victim)
				{
					int mulEffect = IsPlayerHaveEffect(victim, 10);
					if(mulEffect > 0)
					{
						DealDamage(victim, attacker, 3000 * mulEffect, 0);
						ClientCommand(victim, "play \"level/lurd/climber.wav\"");
						// new String:name[32];
						// GetClientName(attacker, name, 32);
						// PrintToChatAll("\x03[\x05提示\x03]%N\x04死亡前引爆自身炸弹给予\x03%s\x043000点伤害!",victim,name);
						PrintToChat(victim, "\x03[提示]\x01 你死亡前死亡前引爆炸弹对 \x04%N\x01 造成 \x05%d\x01 伤害。", attacker, 3000 * mulEffect);
					}
				}
				else
				{
					GiveSkillPoint(attacker, -3);
					g_fForgiveOfTK[attacker] = GetEngineTime() + 45.0;
					g_iForgiveTKTarget[attacker] = GetClientUserId(victim);
					
					if(!IsFakeClient(attacker) && g_pCvarAllow.BoolValue)
						PrintToChat(attacker, "\x03[提示]\x01 你因为干掉队友而失去了 \x053\x01 硬币。");
				}
			}
			
			if((g_clSkill_3[victim] & SKL_3_Sacrifice))
			{
				int chance = 1 + IsPlayerHaveEffect(victim, 19);
				if(GetRandomInt(0, 2) < chance)
				{
					SetVariantInt(1);
					ClientCommand(victim, "play \"level/lurd/adrenaline_impact.wav\"");

					for(int i = 1; i <= MaxClients; ++i)
					{
						if(!IsValidAliveClient(i) || GetClientTeam(i) != 3)
							continue;

						// 将血量设置为 1 然后再对其造成伤害
						AcceptEntityInput(i, "SetHealth", victim, i);
						DealDamage(victim, i, 9999, DMG_PLASMA);
					}
					
					int numEdict = GetMaxEntities();
					for(int i = MaxClients + 1; i < numEdict; ++i)
					{
						if(!IsValidEdict(i))
							continue;
						
						static char classname[64];
						GetEdictClassname(i, classname, 64);
						if(StrEqual(classname, "infected", false) || StrEqual(classname, "witch", false))
						{
							SetEntProp(i, Prop_Data, "m_iHealth", 1);
							DealDamage(victim, i, 999, DMG_PLASMA);
						}
					}
				}
				else
					PrintToChat(victim, "\x03「牺牲」\x01未能触发。");
			}
			
			if(g_clSkill_3[victim] & SKL_3_Respawn)
			{
				int chance = 1 + IsPlayerHaveEffect(victim, 18);
				if(GetRandomInt(0, 9) < chance)
				{
					CreateTimer(5.0, Timer_RespawnPlayer, victim);
					ClientCommand(victim, "play \"level/pointscored.wav\"");
					// PrintToChatAll("\x03[\x05提示\x03] %N\x04成功\x03转生\x04,5秒后复活到队友身边!",victim);
					PrintToChat(victim, "\x03「永生」\x01触发成功，将会在 \x055\x01 秒后复活到队友身边。");
				}
				else
				{
					// PrintToChatAll("\x03[\x05提示\x03]\x04很遗憾!\x03%N\x04转生失败!",victim);
					PrintToChat(victim, "\x03「永生」\x01未能触发。");
				}
			}
			
			g_bIsPaincIncap = true;
		}
		else if(team == TEAM_INFECTED)
		{
			if(GetRandomInt(1, 100) <= g_pCvarGiftChance.IntValue)
			{
				// 特感死亡掉落物品
				switch(GetRandomInt(1, 6))
				{
					case 1:
						DropItem( victim, STAR_1_MDL );
					case 2:
						DropItem( victim, STAR_2_MDL );
					case 3:
						DropItem( victim, MUSHROOM_MDL );
					case 4:
						DropItem( victim, CHAIN_MDL );
					case 5:
						DropItem( victim, GOMBA_MDL );
					case 6:
						DropItem( victim, LUMA_MDL );
				}
			}
		}
		
		g_fFreezeTime[victim] = 0.0;
		// Initialization(victim);
		ClientSaveToFileSave(victim, g_pCvarSaveStatus.BoolValue);
		
		// 去除光圈
		PerformGlow(victim, 0, 0, 0);
		RemoveGlowModel(victim);
	}

	if(g_bIsGamePlaying && IsValidClient(attacker))
	{
		if(IsValidClient(victim) && GetClientTeam(victim) == TEAM_INFECTED && GetClientTeam(attacker) == TEAM_SURVIVORS)
		{
			if((g_clSkill_2[attacker] & SKL_2_Excited) && event.GetBool("headshot") && !GetRandomInt(0, 2))
			{
				// SDKCall(sdkAdrenaline, attacker, 14.0);
				// CheatCommand(attacker, "script", "GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(attacker), 14);
				L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(attacker), 5);
				
				EmitSoundToClient(attacker,g_soundLevel);
				if(!IsFakeClient(attacker)) PrintToChat(attacker, "\x03「热血」\x01你进入状态兴奋 \x055\x01 秒。");
			}
			
			g_ttSpecialKilled[attacker] += 1;
			if(g_pCvarSpecialKilled.IntValue > 0 && g_ttSpecialKilled[attacker] >= g_pCvarSpecialKilled.IntValue)
			{
				GiveSkillPoint(attacker, 1);
				g_ttSpecialKilled[attacker] -= g_pCvarSpecialKilled.IntValue;
				
				if(g_pCvarAllow.BoolValue && !IsFakeClient(attacker))
					PrintToChat(attacker, "\x03[\x05提示\x03]\x04你多次杀死特感获得额外的硬币一枚!输入\x03!lv\x04查看!");
			}
		}
	}
}

void DropItem( int client, const char[] Model )
{
	float vecPos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
	vecPos[2] += 20.0;
	
	if(g_pfnCreateGift != null)
	{
		SDKCall(g_pfnCreateGift, vecPos, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), 0);
		return;
	}
	
	int entity = CreateEntityByName( "scripted_item_drop" );
	if ( entity != -1 )
	{
		DispatchKeyValue( entity, "model", Model );
		DispatchKeyValue( entity, "solid", "6" );
		DispatchKeyValue( entity, "targetname", "reward_drop" );
		DispatchSpawn( entity );

		SetEntityRenderMode( entity, RENDER_TRANSCOLOR );
		SetEntityRenderColor( entity, 255, 255, 255, 235 );

		if ( StrEqual( Model, CHAIN_MDL, false ))
		{
			SetEntPropFloat( entity, Prop_Send, "m_flModelScale", 0.7 );
		}
		else if ( StrEqual( Model, GOMBA_MDL, false ))
		{
			SetEntPropFloat( entity, Prop_Send, "m_flModelScale", 1.5 );
			SetEntityRenderColor( entity, 255, 255, 255, 255 );
		}

		// SetEntProp( entity, Prop_Send, "m_CollisionGroup", 1 );
		TeleportEntity( entity, vecPos, NULL_VECTOR, NULL_VECTOR);

		// g_ItemLife[slotNumber] = CreateTimer( 0.05, Timer_ItemLifeSpawn, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
		// SDKHook(entity, SDKHook_StartTouch, RewardHook_OnStartTouch);
		HookSingleEntityOutput(entity, "OnPlayerTouch", DropGiftHook_OnTouchPickup, false);
		HookSingleEntityOutput(entity, "OnPlayerPickup", DropGiftHook_OnTouchPickup, false);
		// SDKHook(entity, SDKHook_ThinkPost, DropGiftHook_OnThink);

		/*
		SetVariantString("OnUser4 !self:FireUser3::0.1:-1");
		AcceptEntityInput(entity, "AddOutput", client, entity);
		HookSingleEntityOutput(entity, "OnUser3", DropGiftHook_OnThink, false);
		AcceptEntityInput(entity, "FireUser4", client, entity);
		*/
		
		float dir[3] = { 0.0, 1.0, 0.0 };
		NormalizeVector(dir, dir);
		ScaleVector(dir, 10.0);
		L4D_AngularVelocity(entity, dir);

		SetVariantString("OnUser1 !self:Kill::30:1");
		AcceptEntityInput(entity, "AddOutput", client, entity);
		AcceptEntityInput(entity, "FireUser1", client, entity);

		EmitAmbientSound("ui/gift_drop.wav", vecPos, entity, SNDLEVEL_CAR);
	}
}

public void DropGiftHook_OnThink(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidEntity(caller))
		return;
	
	decl Float:myAng[3];
	GetEntPropVector( caller, Prop_Data, "m_angRotation", myAng );
	myAng[0] = 0.0;
	myAng[1] += 10.0;
	myAng[2] = 0.0;
	TeleportEntity( caller, NULL_VECTOR, myAng, NULL_VECTOR);
	
	AcceptEntityInput(caller, "FireUser4", activator, caller);
}

public void DropGiftHook_OnTouchPickup(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidEntity(caller) || !IsValidAliveClient(activator) || GetClientTeam(activator) != 2)
		return;

	// ClientCommand(activator, "play \"ui/gift_pickup.wav\"");
	
	float vPos[3];
	GetClientAbsOrigin(activator, vPos);
	EmitAmbientSound(SOUND_GIFT_PICKUP, vPos, activator);
	
	RewardPicker(activator);
	AcceptEntityInput(caller, "Kill", activator, caller);
}

//幸运箱奖励
void RewardPicker(int client, int reward = -1)
{
	if(!IsValidAliveClient(client))
		return;

	static ConVar cv_incaphealth;
	if(cv_incaphealth == null)
		cv_incaphealth = FindConVar("survivor_incap_health");
	
	if(reward == -1)
		reward = GetRandomInt((CheckTankNumber() ? 0 : 2), 9);
	
	{
		Call_StartForward(g_fwOnGiftPickup);
		Call_PushCell(client);
		
		int refReward = reward;
		Call_PushCellRef(refReward);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return;
		
		if(refResult == Plugin_Changed)
			reward = refReward;
	}
	
	switch(reward)
	{
		// 怒气触发
		case 0:
		{
			if(!g_bIsAngryActive && g_pCvarAS.BoolValue)
			{
				TriggerAngrySkill(client, GetRandomInt(1, 7));
			}
			else
			{
				EmitSoundToClient( client, REWARD_SOUND );
				GiveAngryPoint(client, 30);

				if(g_pCvarAllow.BoolValue)
					PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03怒气值+30\x04.",client);
				else
					PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，怒气值＋30");
			}
		}
		// 天启触发
		case 1:
		{
			if(g_iRoundEvent == 0 || !g_pCvarRE.BoolValue)
			{
				if(g_pCvarAllow.BoolValue)
					PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,结果发现是一个空箱子...",client);
				else
					PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，但是里面什么也没有。");
			}
			else if(GetRandomInt(0, 1))
			{
				if(g_pCvarAllow.BoolValue)
					PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 尝试打开天启幸运箱,箱子蠢蠢欲动,可惜还是没打开...",client);
				else
					PrintToChat(client, "\x03[提示]\x01 你尝试打开箱子，但是失败了。");
			}
			else
			{
				EmitSoundToClient( client, REWARD_SOUND );
				StartRoundEvent();

				if(g_pCvarAllow.BoolValue)
					PrintToChatAll("\x03[提示]\x01 玩家 \x04%N\x01 打开了幸运箱，本回合天启更改为：\x05%s\x01。", client, g_szRoundEvent);
				else
					PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，本回合天启更改为：\x05%s\x01。", g_szRoundEvent);
			}
		}
		case 2:
		{
			EmitSoundToClient( client, REWARD_SOUND );

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03随机获得一件装备\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，捡到了一个\x04奇怪的东西\x01。");

			if(g_clSkillPoint[client] < 0)
			{
				GiveSkillPoint(client, 2);

				if(g_pCvarAllow.BoolValue)
					PrintToChat(client, "\x03[提示]\x01 由于你的硬币是负数，获得装备改成了获得硬币。");
			}
			else
			{
				new j = GiveEquipment(client);
				if(!j)
				{
					if(g_pCvarAllow.BoolValue)
						PrintToChat(client, "\x01[装备]你的装备栏已满,无法再获得装备.");
				}
				else
				{
					static char key[16];
					IntToString(j, key, sizeof(key));
					static EquipData_t data;
					if(g_pCvarAllow.BoolValue && g_mEquipData[client].GetArray(key, data, sizeof(data)) && data.valid)
					{
						PrintToChat(client, "\x03[提示]\x01 装备获得：\x05%s\x01，输入 !lv 查看。", FormatEquip(client, data));
					}
				}
			}
		}
		case 3:
		{
			if((GetEntProp(client,Prop_Send,"m_iHealth") < GetEntProp(client,Prop_Send,"m_iMaxHealth")) || GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			{
				CheatCommand(client, "give", "health");
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
			}
			EmitSoundToClient( client, REWARD_SOUND );

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03恢复满血\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04恢复满血\x01。");
		}
		case 4:
		{

			GiveSkillPoint(client, 1);
			EmitSoundToClient( client, REWARD_SOUND );

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03获得硬币一枚\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04获得硬币一枚\x01。");
		}
		case 5:
		{
			EmitSoundToClient( client, REWARD_SOUND );
			GiveAngryPoint(client, 10);

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03怒气值+10\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04怒气值+10\x01。");
		}
		case 6:
		{
			// CheatCommand(client, "give", "ammo");
			AddAmmo(client, 999);
			EmitSoundToClient( client, REWARD_SOUND );

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03弹药得到了补充\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04弹药得到了补充\x01。");
		}
		case 7:
		{
			CheatCommand(client, "give", "pipe_bomb");
			CheatCommand(client, "give", "weapon_sniper_awp");
			CheatCommand(client, "give", "pain_pills");
			CheatCommand(client, "give", "first_aid_kit");
			CheatCommand(client, "give", "pistol_magnum");
			EmitSoundToClient( client, REWARD_SOUND );

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03发现了一背包的物品\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04发现了一背包的物品\x01。");
		}
		case 8:
		{
			EmitSoundToClient(client,SOUND_BAD);
			// ServerCommand("sm_freeze \"%N\" \"30\"",client);
			FreezePlayer(client, 30.0);

			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,原来里面藏着一颗冰冻弹,\x03被冰冻30秒\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，原来里面藏着一颗冰冻弹，\x04被冰冻30秒\x01。");
		}
		case 9:
		{
			EmitSoundToClient(client,SOUND_BAD);
			
			Event event = CreateEvent("player_incapacitated_start");
			event.SetInt("userid", GetClientUserId(client));
			event.SetInt("attacker", 0);
			event.SetInt("attackerentid", 0);
			event.SetInt("type", 0);
			event.SetString("weapon", "");
			event.Fire(false);
			
			SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
			SetEntProp(client, Prop_Data, "m_iHealth", cv_incaphealth.IntValue);
			
			// 修复倒地没武器
			// CheatCommand(client, "give", "pistol");
			CreateTimer(0.2, Timer_GivePistol, client);
			
			event = CreateEvent("player_incapacitated");
			event.SetInt("userid", GetClientUserId(client));
			event.SetInt("attacker", 0);
			event.SetInt("attackerentid", 0);
			event.SetInt("type", 0);
			event.SetString("weapon", "");
			event.Fire(false);
			
			if(g_pCvarAllow.BoolValue)
				PrintToChatAll("\x03【\x05幸运箱\x03】%N\x04 打开了幸运箱,\x03被里面的玩具拳击倒了\x04.",client);
			else
				PrintToChat(client, "\x03[提示]\x01 你打开了幸运箱，\x04被里面的玩具拳击倒了\x01。");
		}
	}
}

public Action Timer_GivePistol(Handle timer, any client)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	char classname[64];
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEntity(weapon) || !GetEdictClassname(weapon, classname, sizeof(classname)) || StrContains(classname, "pistol", false) == -1)
	{
		if(g_clSkill_2[client] & SKL_2_Magnum)
			CheatCommand(client, "give", "pistol_magnum");
		else
			CheatCommand(client, "give", "pistol");
	}
	
	return Plugin_Continue;
}

int CheckTankNumber()
{
	new j = 0;
	for(new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i) == 3)
		{
			new iclass = GetEntProp(i, Prop_Send, "m_zombieClass");
			if(IsPlayerAlive(i) && iclass == 8) j++;
		}
	}
	return j;
}

public Action:Timer_RespawnPlayer(Handle:timer, any:client)
{
	if(client > -1 && client <= MaxClients)
		g_timerRespawn[client] = null;

	if (client && IsClientInGame(client) && IsClientConnected(client) && GetClientTeam(client) == 2)
	{
		// decl String:playername[64];
		// GetClientName(client, playername, sizeof(playername));
		new teletarget = 0;
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i)) continue;
			if(!IsPlayerAlive(i)) continue;
			if(GetClientTeam(i) != 2) continue;
			if(i == client) continue;
			teletarget = i;
			break;
		}
		if(IsPlayerAlive(client))
		{
			// PrintToChatAll("\x03[\x05提示\x03]\x04由于玩家\x03%s\x04已经是活着的状态,玩家\x03%s\x04复活失败.", playername);
			PrintToChat(client, "\x03[提示]\x01 你已经活过来了。");
		}
		else if(teletarget == 0)
		{
			// PrintToChatAll("\x03[\x05提示\x03]\x04由于没有可传送的队友,玩家\x03%s\x04复活失败.", playername);
			PrintToChat(client, "\x03[提示]\x01 复活失败，没有其他活着的队友。");
		}
		else
		{
			// SDKCall(hRoundRespawn, client);
			// CheatCommand(client, "script", "GetPlayerFromUserID(%d).ReviveByDefib()", GetClientUserId(client));
			L4D2_RunScript("GetPlayerFromUserID(%d).ReviveByDefib()", GetClientUserId(client));
			
			// PrintToChatAll("\x03[\x05提示\x03]\x04玩家\x03%s\x04顺利复活.", playername);
			PrintToChat(client, "\x03[提示]\x01 复活完毕。");
			// ClientCommand(client, "play \"ui/helpful_event_1.wav\"");

			new Float:position[3];
			new Float:anglestarget[3];
			GetClientAbsOrigin(teletarget, position);
			position[2] + 0.2;
			GetClientAbsAngles(teletarget, anglestarget);
			TeleportEntity(client, position, anglestarget, NULL_VECTOR);
			EmitAmbientSound(SOUND_WARP, position, client, SNDLEVEL_HELICOPTER);
		}
	}
}

public Action:Event_TankKilled(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if(!g_bIsGamePlaying)
		return Plugin_Continue;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool solo = GetEventBool(event, "solo");
	bool melee = GetEventBool(event, "melee_only");

	if(g_pCvarAllow.BoolValue)
	{
		g_ttTankKilled ++;
		DataPack data = CreateDataPack();
		data.WriteCell(attacker);
		data.WriteCell(solo);
		data.WriteCell(melee);
		
		if(g_pCvarTankDeath.BoolValue)
			CreateTimer(0.1, Timer_TankDeath, data);

		if(g_ttTankKilled >= 1 || g_iRoundEvent == 0)
			CreateTimer(5.0, Round_Random_Event);
	}
	
	return Plugin_Handled;
}

public Action:Round_Random_Event(Handle:timer, any:data)
{
	if(!g_pCvarRE.BoolValue)
		return Plugin_Continue;
	
	RestoreConVar();
	
	char buffer[64];
	StartRoundEvent(_, buffer, sizeof(buffer));
	
	PrintToChatAll("\x03[\x05提示\x03]\x04回合首只坦克死亡触发\x03天启事件\x04...");
	PrintToChatAll("\x03[提示]\x01 本回合天启：\x04%s\x05（%s）\x01。", g_szRoundEvent, buffer);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || IsFakeClient(i))
			continue;

		ClientCommand(i, "play \"buttons/bell1.wav\"");
	}

	PrintToServer("本回合天启事件：%s丨%s", g_szRoundEvent, buffer);
	return Plugin_Continue;
}

public Action:Timer_TankDeath(Handle:timer, any:data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int attacker = pack.ReadCell();
	bool solo = view_as<bool>(pack.ReadCell());
	bool melee = view_as<bool>(pack.ReadCell());
	delete pack;

	if(IsValidClient(attacker) && !IsFakeClient(attacker) && solo)
	{

		GiveSkillPoint(attacker, 1);
		if(IsPlayerAlive(attacker))
			AttachParticle(attacker, "achieved", 3.0);

		if(g_pCvarAllow.BoolValue)
			PrintToChat(attacker, "\x03[提示]\x01 你因为单挑坦克而获得 \x051\x01 硬币。");
	}

	if(g_ttTankKilled >= 4)
	{
		/*
		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]\x04由于本关卡坦克死亡数已超过3只,将不再补血,生还者也将无法获得任何奖励!");
		*/
		return Plugin_Continue;
	}

	// PrintToChatAll("\x03[\x05提示\x03]\x04坦克死亡所有生还者和感染者(\x03包括坦克\x04)补满血气!");
	// float gameTime = GetGameTime();
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i))
			continue;

		/*
		if(IsPlayerAlive(i))
		{
			if(GetClientTeam(i) == 3)
			{
				// 特感回血
				CheatCommand(i, "give", "health");
			}
			else
			{
				if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
					CheatCommand(i, "script", "GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(i));

				AddHealth(i, 999);
			}
		}
		*/
		
		if(GetClientTeam(i) == 2)
		{
			CreateTimer(1.0, AutoMenuOpen, i);
			EmitSoundToClient(i,g_soundLevel);
			new chance = GetRandomInt(1, 7);
			if(chance < 6)
			{
				GiveSkillPoint(i, 1);

				if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
					PrintToChat(i,"\x03[\x05提示\x03]\x04坦克死亡你随机获得硬币\x031\x04枚!");

				if(melee)
				{
					GiveSkillPoint(i, 1);

					if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
						PrintToChat(i, "\x03[提示]\x01 因为坦克是被刀死的，你额外获得 \x051\x01 硬币。");
				}
			}
			else
			{
				if(IsPlayerAlive(i)) AttachParticle(i, "achieved", 9.0);
				
				if(g_clSkillPoint[i] < 0)
				{
					GiveSkillPoint(i, 2);

					if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
						PrintToChat(i, "\x03[提示]\x01 由于你的硬币是负数，获得装备改成了获得硬币。");
				}
				else
				{
					new j = GiveEquipment(i);
					if(!j)
					{
						GiveSkillPoint(i, 2);

						if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
							PrintToChat(i,"\x03[\x05提示\x03]\x04坦克死亡你随机获得硬币\x032\x04枚!");
					}
					else
					{
						static char key[16];
						IntToString(j, key, sizeof(key));
						static EquipData_t ed;
						if(g_pCvarAllow.BoolValue && !IsFakeClient(i) && g_mEquipData[i].GetArray(key, ed, sizeof(ed)) && ed.valid)
							PrintToChat(i, "\x03[提示]\x01 获得装备：\x05%s\x01 输入 !lv 查看", FormatEquip(i, ed));
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data) // Check if the TraceRay hit the itself.
	{
		return false; // Don't let the entity be hit
	}
	return true; // It didn't hit itself
}

/* 准心坐标获取 */
public GetTracePosition(client, Float:TracePosition[3])
{
	decl Float:clientPos[3], Float:clientAng[3];

	GetClientEyePosition(client, clientPos);
	GetClientEyeAngles(client, clientAng);
	new Handle:trace = TR_TraceRayFilterEx(clientPos, clientAng, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(TracePosition, trace);
	}
	CloseHandle(trace);
}

/* 准心坐标获取_调用 */
public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

/* 取距离 */
public Float:DistanceToHit(ent)
{
	if (!(GetEntityFlags(ent) & (FL_ONGROUND)))
	{
		decl Handle:h_Trace, Float:entpos[3], Float:hitpos[3], Float:angle[3];

		// GetEntPropVector(ent, Prop_Data, "m_vecVelocity[0]", angle);
		GetEntDataVector(ent, g_iVelocityO, angle);

		GetVectorAngles(angle, angle);

		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", entpos);
		h_Trace = TR_TraceRayFilterEx(entpos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, ent);

		if (TR_DidHit(h_Trace))
		{
			TR_GetEndPosition(hitpos, h_Trace);

			CloseHandle(h_Trace);

			return GetVectorDistance(entpos, hitpos);
		}

		CloseHandle(h_Trace);
	}

	return 0.0;
}

public Action:Event_DefibrillatorUsed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int subject = GetClientOfUserId(GetEventInt(event, "subject"));
	if(!IsValidClient(subject))
		return Plugin_Continue;

	if(g_bIsGamePlaying && IsValidAliveClient(client) && subject != client)
	{
		g_ttDefibUsed[client]++;
		if(g_fForgiveOfTK[client] >= GetEngineTime() && g_iForgiveTKTarget[client] == GetClientUserId(subject))
		{
			g_fForgiveOfTK[client] = 0.0;
			g_iForgiveTKTarget[client] = 0;
			g_ttDefibUsed[client]--;
			
			GiveSkillPoint(client, 3);
			if(g_pCvarAllow.BoolValue && !IsFakeClient(client))
				PrintToChat(client, "\x03[\x05提示\x03]\x04 你因为给队友 电击 而获得了 \x053\x01 硬币。");
		}
		
		if(g_pCvarDefibUsed.IntValue > 0 && g_ttDefibUsed[client] >= g_pCvarDefibUsed.IntValue)
		{
			GiveSkillPoint(client, 1);
			g_ttDefibUsed[client] -= g_pCvarDefibUsed.IntValue;

			if(g_pCvarAllow.BoolValue && !IsFakeClient(client))
				PrintToChat(client, "\x03[\x05提示\x03]\x04 你因为多次给队友 电击/打包 而获得了 \x051\x01 硬币。");
		}
	}
	
	/*
	if(g_clSkill_1[subject] & SKL_1_Armor)
	{
		AddArmor(subject, 100 + (100 * IsPlayerHaveEffect(subject, 33)));
	}
	*/
	
	RegPlayerHook(subject, (g_Cvarhppack.BoolValue || IsPlayerHaveEffect(subject, 35)));
	
	// 修复电击复活后的武器
	if((g_clSkill_2[subject] & SKL_2_Magnum) && g_sLastWeapon[subject][0] != EOS)
	{
		int weapon = GetPlayerWeaponSlot(subject, 1);
		if(weapon > MaxClients && IsValidEntity(weapon))
			RemoveEntity(weapon);
		
		/*
		if(StrContains(g_sLastWeapon[subject], "weapon_", false) == 0)
		{
			ReplaceString(g_sLastWeapon[subject], sizeof(g_sLastWeapon[]), "weapon_", "", false);
			
			CheatCommand(subject, "give", g_sLastWeapon[subject]);
			if(g_bLastWeaponDual[subject])
				CheatCommand(subject, "give", g_sLastWeapon[subject]);
			
			CreateTimer(0.1, Timer_SetWeaponClip, subject);
		}
		else
		{
			CheatCommand(subject, "give", g_sLastWeapon[subject]);
		}
		*/
		
		DataPack data = CreateDataPack();
		data.WriteCell(subject);
		data.WriteString(g_sLastWeapon[subject]);
		data.WriteCell(g_bLastWeaponDual[subject]);
		CreateTimer(0.1, Timer_DelayGivePistol, data);
		
		g_sLastWeapon[subject][0] = EOS;
	}
	
	if(g_bIsGamePlaying && IsValidClient(client) && (g_clSkill_3[client] & SKL_3_ReviveBonus) && client != subject)
		GiveHelpBouns(client);
	
	if(g_iRoundEvent == 19)
	{
		ApplyHealthSwap(subject);
	}

	return Plugin_Continue;
}

public Action:Event_ReviveSuccess(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));
	new bool:WasLedgeHang = GetEventBool(event, "ledge_hang");
	if (!IsValidAliveClient(subject)) return;
	
	if(IsValidClient(client) && !WasLedgeHang)
	{
		new extrahp = 0;
		if((g_clSkill_1[subject] & SKL_1_ReviveHealth))
		{
			extrahp += 50;
		}
		
		int mulEffect = IsPlayerHaveEffect(subject, 1);
		if(mulEffect > 0) extrahp += 20 * mulEffect;
		
		if(extrahp)
		{
			float buffer = GetEntPropFloat(subject, Prop_Send, "m_healthBuffer");
			if(buffer + extrahp > 200.0)
				extrahp = RoundToZero(200 - buffer);
			
			SetEntPropFloat(subject, Prop_Send, "m_healthBuffer", buffer + extrahp);
			if(!IsFakeClient(subject)) PrintToChat(subject, "\x03[\x05提示\x03]\x04倒地被救起恢复额外HP:%d",extrahp);
		}
		
		mulEffect = IsPlayerHaveEffect(subject, 4);
		if(mulEffect > 0)
		{
			// SDKCall(sdkAdrenaline, subject, 15.0);
			// CheatCommand(subject, "script", "GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(subject), 15);
			L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(subject), 10 * mulEffect);
		}
		
		if(g_bIsGamePlaying && client != subject)
		{
			g_ttOtherRevived[client] ++;
			if(g_pCvarOtherRevived.IntValue > 0 && g_ttOtherRevived[client] >= g_pCvarOtherRevived.IntValue)
			{
				GiveSkillPoint(client, 1);
				g_ttOtherRevived[client] -= g_pCvarOtherRevived.IntValue;

				if(g_pCvarAllow.BoolValue && !IsFakeClient(client))
					PrintToChat(client, "\x03[\x05提示\x03]\x04 你多次拉起队友获得了 \x051\x01 硬币。");
			}
		}
		if(g_bIsGamePlaying && client != subject && (g_clSkill_3[client] & SKL_3_ReviveBonus))
		{
			GiveHelpBouns(client);
		}
	}
	
	if((g_clSkill_2[subject] & SKL_2_Magnum) && g_sLastWeapon[subject][0] != EOS)
	{
		int weapon = GetPlayerWeaponSlot(subject, 1);
		if(weapon > MaxClients && IsValidEntity(weapon))
			RemoveEntity(weapon);
		
		/*
		if(StrContains(g_sLastWeapon[subject], "weapon_", false) == 0)
		{
			ReplaceString(g_sLastWeapon[subject], sizeof(g_sLastWeapon[]), "weapon_", "", false);
			
			CheatCommand(subject, "give", g_sLastWeapon[subject]);
			if(g_bLastWeaponDual[subject])
				CheatCommand(subject, "give", g_sLastWeapon[subject]);
			
			CreateTimer(0.1, Timer_SetWeaponClip, subject);
		}
		else
		{
			CheatCommand(subject, "give", g_sLastWeapon[subject]);
		}
		*/
		
		DataPack data = CreateDataPack();
		data.WriteCell(subject);
		data.WriteString(g_sLastWeapon[subject]);
		data.WriteCell(g_bLastWeaponDual[subject]);
		CreateTimer(0.1, Timer_DelayGivePistol, data);
		
		g_sLastWeapon[subject][0] = EOS;
	}
	
	int mulEffect = IsPlayerHaveEffect(subject, 34);
	if((g_clSkill_1[subject] & SKL_1_Armor) && mulEffect > 0)
	{
		AddArmor(subject, 50 * mulEffect);
	}
	
	RegPlayerHook(subject, false);
	
	if(g_iRoundEvent == 14)
	{
		SetEntProp(subject, Prop_Send, "m_bIsOnThirdStrike", 0);
		SetEntProp(subject, Prop_Send, "m_isGoingToDie", 0);
	}
	
	if(GetEntProp(subject, Prop_Send, "m_bIsOnThirdStrike", 1))
	{
		// 黑白状态
		CreateGlowModel(subject, 0xFFFFFF);
	}
	else
	{
		// 正常
		RemoveGlowModel(subject);
	}
}

void GiveHelpBouns(int client)
{
	new RandomGiv = GetRandomInt(0, 11);
	switch(RandomGiv)
	{
		case 0:
		{
			CheatCommand(client, "give", "adrenaline");

			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03肾上腺素\x04!");
		}
		case 1:
		{
			CheatCommand(client, "give", "pain_pills");

			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03止痛药\x04!");
		}
		case 2:
		{
			CheatCommand(client, "give", "molotov");

			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03燃烧瓶\x04!");
		}
		case 3:
		{
			CheatCommand(client, "upgrade_add", "INCENDIARY_AMMO");

			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03燃烧子弹\x04!");
		}
		case 4:
		{
			CheatCommand(client, "give", "defibrillator");

			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03电击器\x04!");
		}
		case 5:
		{
			if(!GetRandomInt(0, 3))
			{
				GiveSkillPoint(client, 1);
				if(g_pCvarAllow.BoolValue)
					PrintToChat(client, "\x03「妙手」\x04你获得了\x03硬币一枚\x04!");
			}
		}
		case 6:
		{
			int number = GetRandomInt(5, 20);
			AddHealth(client, number, true, true);
			
			if(g_pCvarAllow.BoolValue)
				PrintToChat(client, "\x03「妙手」\x04你获得了\x03HP+%d\x04!", number);
		}
	}
}

public Action Timer_DelaySetClip(Handle timer, any client)
{
	if(!IsValidAliveClient(client) || g_iLastWeaponClip[client] < 0)
		return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return Plugin_Continue;
	
	SetEntProp(weapon, Prop_Send, "m_iClip1", g_iLastWeaponClip[client]);
	return Plugin_Continue;
}

public Action Timer_DelayGivePistol(Handle timer, any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	char classname[64];
	int subject = data.ReadCell();
	data.ReadString(classname, 64);
	int dual = data.ReadCell();
	ReplaceString(classname, 64, "weapon_", "", false);
	
	if(!IsValidAliveClient(subject) || classname[0] == EOS)
		return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(subject, 1);
	if(weapon < MaxClients || !IsValidEntity(weapon))
	{
		CheatCommand(subject, "give", classname);
		if(dual)
			CheatCommand(subject, "give", classname);
	}
	
	CreateTimer(0.1, Timer_DelaySetClip, subject);
	return Plugin_Continue;
}

public void Event_AwardEarned(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = event.GetInt("subjectentid");
	// int entity = event.GetInt("entityid");
	int award = event.GetInt("award");

	if(!IsValidAliveClient(client) || client == subject)
		return;
	
	bool bot = IsFakeClient(client);
	
	if(award == 67)
	{
		// 保护队友
		if(g_bIsGamePlaying)
		{
			g_ttProtected[client] += 1;
			if(g_pCvarProtected.IntValue > 0 && g_ttProtected[client] >= g_pCvarProtected.IntValue)
			{
				g_ttProtected[client] -= g_pCvarProtected.IntValue;

				GiveSkillPoint(client, 1);

				if(!bot && g_pCvarAllow.BoolValue)
					PrintToChat(client, "\x03[提示]\x01 你因为多次保护队友获得 \x051\x01 硬币。");
			}
		}
	}

	if(award == 68)
	{
		// 给队友递药
		if(g_bIsGamePlaying)
		{
			g_ttGivePills[client] += 1;
			if(g_pCvarGivePills.IntValue > 0 && g_ttGivePills[client] > g_pCvarGivePills.IntValue)
			{
				g_ttGivePills[client] -= g_pCvarGivePills.IntValue;

				GiveSkillPoint(client, 1);

				if(!bot && g_pCvarAllow.BoolValue)
					PrintToChat(client, "\x03[提示]\x01 你因为多次给队友递药获得 \x051\x01 硬币。");
			}
		}
	}

	if(award == 69)
	{
		// 给队友递针
		if(g_bIsGamePlaying)
		{
			// 这里并不去触发检查
			g_ttGivePills[client] += 1;
		}
	}

	if(award == 76)
	{
		// 把队友从特感的控制中救出
		if(g_bIsGamePlaying)
		{
			// g_ttOtherRevived[client] += 1;
			g_ttRescued[client] += 1;
			if(g_pCvarRescued.IntValue > 0 && g_ttRescued[client] >= g_pCvarRescued.IntValue)
			{
				GiveSkillPoint(client, 1);
				g_ttRescued[client] -= g_pCvarRescued.IntValue;

				if(!bot && g_pCvarAllow.BoolValue)
					PrintToChat(client, "\x03[提示]\x01 你因为营救队友而获得了 \x051\x01 硬币。");
			}
		}
	}

	if(award == 80)
	{
		// 开门复活队友
		// 这里并不去触发检查
		// g_ttOtherRevived[client] += 1;
		// g_ttRescued[client] += 1;
	}
	
	if(award == 81)
	{
		if(g_bIsGamePlaying && !g_pCvarAllow.BoolValue && g_pCvarTankDeath.BoolValue)
			// 克局过后没有死亡
			GiveSkillPoint(client, 1);

		// if(g_pCvarAllow.BoolValue)
			// PrintToChat(client, "\x03[提示]\x01 你因为克局过后没有死亡获得 \x051\x01 硬币。");
	}

	if(award == 84)
	{
		// 把队友干掉了
		/*
		GiveSkillPoint(client, -3);
		
		if(IsValidClient(subject))
		{
			g_fForgiveOfTK[client] = GetEngineTime() + 45.0;
			g_iForgiveTKTarget[client] = GetClientUserId(subject);
		}

		if(!bot && g_pCvarAllow.BoolValue)
			PrintToChat(client, "\x03[提示]\x01 你因为干掉队友而失去了 \x053\x01 硬币。");
		*/
	}

	if(award == 85 || award == 89)
	{
		// 把队友打趴下了
		/*
		GiveSkillPoint(client, -1);
		
		if(IsValidClient(subject))
		{
			g_fForgiveOfFF[client] = GetEngineTime() + 45.0;
			g_iForgiveFFTarget[client] = GetClientUserId(subject);
		}

		if(!bot && g_pCvarAllow.BoolValue)
			PrintToChat(client, "\x03[提示]\x01 你因为放倒队友而失去了 \x051\x01 硬币。");
		*/
	}

	if(award == 95)
	{
		// 有普感进了安全室
	}
}

public void Event_PlayerSacrifice(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;

	int count = 0;
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidAliveClient(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			++count;
	}

	if(count > 0)
	{
		GiveSkillPoint(client, count);

		if(g_pCvarAllow.BoolValue)
			PrintToChat(client, "\x03[提示]\x01 你因为救援关牺牲而获得 \x05%d\x01 硬币。", count);
	}
}

public int OnSkeet(int survivor, int hunter)
{
	if(!IsValidClient(survivor))
		return 0;
	
	g_ttSpecialKilled[survivor] += 1;
	return 0;
}

public int OnSkeetMelee(int survivor, int hunter)
{
	if(!IsValidClient(survivor))
		return 0;
	
	g_ttSpecialKilled[survivor] += 2;
	return 0;
}

public int OnSkeetGL(int survivor, int hunter)
{
	if(!IsValidClient(survivor) || IsFakeClient(survivor))
		return 0;
	
	g_ttSpecialKilled[survivor] += 1;
	return 0;
}

public int OnSkeetSniper(int survivor, int hunter)
{
	if(!IsValidClient(survivor) || IsFakeClient(survivor))
		return 0;
	
	g_ttSpecialKilled[survivor] += 1;
	return 0;
}

public int OnChargerLevel(int survivor, int charger)
{
	if(!IsValidClient(survivor))
		return 0;
	
	GiveSkillPoint(survivor, 1);
	
	g_ttSpecialKilled[survivor] += 5;
	return 0;
}

public int OnWitchCrown(int survivor, int damage)
{
	if(!IsValidClient(survivor))
		return 0;
	
	g_ttCommonKilled[survivor] += 20;
	return 0;
}

public int OnWitchCrownHurt(int survivor, int damage, int chipDamage)
{
	if(!IsValidClient(survivor))
		return 0;
	
	g_ttCommonKilled[survivor] += 10;
	return 0;
}

public int OnBunnyHopStreak(int survivor, int streak, float maxVelocity)
{
	if(!IsValidClient(survivor))
		return 0;
	
	g_ttProtected[survivor] += streak;
	return 0;
}

public int OnHunterHighPounce(int hunter, int survivor, int actualDamage, float calculatedDamage, float height, bool reportedHigh)
{
	if(!IsValidClient(hunter))
		return 0;
	
	if(actualDamage < 20 || height < 300)
		return 0;
	
	GiveSkillPoint(hunter, 1);
	
	if(g_pCvarAllow.BoolValue && !IsFakeClient(hunter))
		PrintToChat(hunter, "\x03[提示]\x01 你因为高扑造成 \x04%d\x01 伤害而获得 \x051\x01 硬币。", actualDamage);
	return 0;
}

public int OnJockeyHighPounce(int jockey, int victim, float height, bool reportedHigh)
{
	if(!IsValidClient(jockey))
		return 0;
	
	if(height < 300)
		return 0;
	
	GiveSkillPoint(jockey, 1);
	
	if(g_pCvarAllow.BoolValue && !IsFakeClient(jockey))
		PrintToChat(jockey, "\x03[提示]\x01 你因为空投骑脸高度 \x04%d\x01 高度而获得 \x051\x01 硬币。", height);
	return 0;
}

public int OnDeathCharge(int charger, int survivor, float height, float distance, bool wasCarried)
{
	if(!IsValidClient(charger))
		return 0;
	
	GiveSkillPoint(charger, 1);
	
	if(g_pCvarAllow.BoolValue && !IsFakeClient(charger))
		PrintToChat(charger, "\x03[提示]\x01 你因为冲锋秒人 \x04%d\x01 高度而获得 \x051\x01 硬币。", height);
	return 0;
}

public bool TraceFilter_NonPlayerOtherAny(int entity, int mask, any other)
{
	return (entity > MaxClients && entity != other);
}

public void Event_VersusFinish(Event event, const char[] eventName, bool dontBroadcast)
{
	int winner = event.GetInt("winners");
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || GetEntProp(i, Prop_Send, "m_iVersusTeam") != winner)
			continue;

		GiveSkillPoint(i, 3);

		if(g_pCvarAllow.BoolValue && IsFakeClient(i))
			PrintToChat(i, "\x03[提示]\x01 你因为 对抗/清道夫 胜利而获得 \x053\x01 硬币。");
	}
}

public void Event_InfectedDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bIsGamePlaying)
		return;
	
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(client))
		return;

	g_ttCommonKilled[client]++;
	if(g_pCvarCommonKilled.IntValue > 0 && g_ttCommonKilled[client] >= g_pCvarCommonKilled.IntValue)
	{
		g_ttCommonKilled[client] -= g_pCvarCommonKilled.IntValue;

		GiveSkillPoint(client, 1);

		if(g_pCvarAllow.BoolValue && IsFakeClient(client))
			PrintToChat(client, "\x03[提示]\x01 你因为杀死一些普感而获得 \x051\x01 硬币。");
	}
}

public void Event_InfectedHurt(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	int victim = event.GetInt("entityid");
	int damage = event.GetInt("amount");
	int type = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	
	if(!IsValidAliveClient(client) || !IsValidEntity(victim) || damage <= 0)
		return;
	
	static char classname[64];
	GetEdictClassname(victim, classname, 64);
	
	if((g_clSkill_1[client] & SKL_1_DisplayHealth) && (type & (DMG_BULLET|DMG_BUCKSHOT|DMG_SLASH|DMG_CLUB)) && !IsFakeClient(client))
	{
		int health = GetEntProp(victim, Prop_Data, "m_iHealth");
		bool headshot = (hitgroup == 1);
		
		if(!(type & DMG_BUCKSHOT))
		{
			if(StrEqual(classname, "infected", false))
				PrintCenterText(client, "普感%d|%s伤害%d|%s", victim, ((type & DMG_CRIT) ? "暴击" : ""), damage, ((health-damage<=0) ? (headshot ? "爆头" : "击杀") : tr("剩余%d", health-damage)));
			else if(StrEqual(classname, "witch", false))
				PrintCenterText(client, "妹%d|%s伤害%d|%s", victim, ((type & DMG_CRIT) ? "暴击" : ""), damage, ((health-damage<=0) ? (headshot ? "爆头" : "击杀") : tr("剩余%d", health-damage)));
			else
				PrintCenterText(client, "%s%d|%s伤害%d|%s", classname, victim, ((type & DMG_CRIT) ? "暴击" : ""), damage, ((health-damage<=0) ? (headshot ? "爆头" : "击杀") : tr("剩余%d", health-damage)));
		}
		else
		{
			if(g_mTotalDamage[client] == null)
			{
				g_mTotalDamage[client] = CreateTrie();
				RequestFrame(NotifyDamageInfo, client);
			}
			
			static char eRef[12];
			IntToString(EntIndexToEntRef(victim), eRef, sizeof(eRef));
			
			TDInfo_t td;
			if(g_mTotalDamage[client].GetArray(eRef, td, sizeof(td)))
			{
				td.dmg += damage;
				td.dmg_type |= type;
				td.headshot |= headshot;
				td.death = (health - damage <= 0);
			}
			else
			{
				td.dmg = damage;
				td.dmg_type = type;
				td.headshot = headshot;
				td.death = (health - damage <= 0);
			}
			
			g_mTotalDamage[client].SetArray(eRef, td, sizeof(td));
		}
	}
}

public void NotifyDamageInfo(any client)
{
	if(g_mTotalDamage[client] == null)
		return;
	
	if(g_mTotalDamage[client].Size <= 0)
	{
		delete g_mTotalDamage[client];
		g_mTotalDamage[client] = null;
		return;
	}
	
	StringMapSnapshot snap = g_mTotalDamage[client].Snapshot();
	int size = snap.Length;
	
	
	static char eRef[12];
	static char name[MAX_NAME_LENGTH];
	int health = -1;
	static TDInfo_t td;
	bool alive = false;
	
	static char msg[255];
	msg[0] = EOS;
	
	for(int i = 0; i < size; ++i)
	{
		snap.GetKey(i, eRef, sizeof(eRef));
		int entity = StringToInt(eRef);
		if(entity == INVALID_ENT_REFERENCE)
			continue;
		
		entity = EntRefToEntIndex(entity);
		if(entity <= 0 || !IsValidEntity(entity))
			continue;
		
		if(!g_mTotalDamage[client].GetArray(eRef, td, sizeof(td)) || td.dmg <= 0)
			continue;
		
		health = GetEntProp(entity, Prop_Data, "m_iHealth");
		if(IsValidClient(entity))
		{
			GetClientName(entity, name, sizeof(name));
			alive = !td.death;
		}
		else
		{
			GetEdictClassname(entity, name, sizeof(name));
			alive = !td.death;
			
			if(StrEqual(name, "infected", false))
				alive = (alive && !GetEntProp(entity, Prop_Send, "m_bIsBurning", 1));
			
			if(StrEqual(name, "infected", false))
				FormatEx(name, sizeof(name), "普感%d", entity);
			else if(StrEqual(name, "witch", false))
				FormatEx(name, sizeof(name), "妹%d", entity);
		}
		
		Format(msg, sizeof(msg), "%s%s|%s伤害%d|%s\n", msg, name, ((td.dmg_type & DMG_CRIT) ? "暴击" : ""), td.dmg, (alive ? tr("剩余%d", health) : (td.headshot ? "爆头" : "击杀")));
	}
	
	if(msg[0] != EOS)
		PrintCenterText(client, msg);
	
	delete snap;
	delete g_mTotalDamage[client];
	g_mTotalDamage[client] = null;
}

public void Event_RoundWin(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
			continue;

		GiveSkillPoint(i, 1);

		if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
			PrintToChat(i, "\x03[提示]\x01 你因为过关时还活着获得了 \x051\x01 硬币。");
	}
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	bool si = (GetClientTeam(client) == 3 && StrEqual(eventName, "player_first_spawn", false));
	bool sur = (StrEqual(eventName, "player_first_spawn", false) && IsPlayerHaveEffect(client, 35));
	RegPlayerHook(client, (si || sur || (g_Cvarhppack.BoolValue && !g_bIsGamePlaying)));
	
	if(g_clSkill_1[client] & SKL_1_Armor)
	{
		AddArmor(client, 100 + (100 * IsPlayerHaveEffect(client, 33)));
	}
}

public void Event_PlayerSpawnNotify(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bIsGamePlaying)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(zClass != ZC_SURVIVOR && zClass != ZC_WITCH)
	{
		int power, health;
		float vPos[3], vLoc[3], distance;
		GetClientAbsOrigin(client, vPos);
		
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2 || IsFakeClient(i) || !(g_clSkill_1[i] & SKL_1_DisplayHealth))
				continue;
			
			GetClientAbsOrigin(i, vLoc);
			distance = GetVectorDistance(vPos, vLoc);
			power = CalcPlayerPower(client);
			health = GetClientHealth(client);
			
			switch(zClass)
			{
				case ZC_SMOKER:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnSmoker");
					PrintToChat(i, "\x04有一只 \x03Smoker\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_BOOMER:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnBoomer");
					PrintToChat(i, "\x04有一只 \x03Boomer\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_HUNTER:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnHunter");
					PrintToChat(i, "\x04有一只 \x03Hunter\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_SPITTER:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnSpitter");
					PrintToChat(i, "\x04有一只 \x03Spitter\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_JOCKEY:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnJockey");
					PrintToChat(i, "\x04有一只 \x03Jockey\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_CHARGER:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnCharger");
					PrintToChat(i, "\x04有一只 \x03Charger\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
				case ZC_TANK:
				{
					// FakeClientCommandEx(i, "vocalize PlayerAlsoWarnTank");
					PrintToChat(i, "\x04有一只 \x03Tank\x04 出现了，距离 \x05%.0f\x01，战斗力 \x05%d\x01，血量 \x05%d\x01。", distance, power, health);
				}
			}
		}
	}
}

public void Event_PlayerJumpApex(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;

	/*
	if(g_iJumpFlags[client] & JF_HasJumping)
		g_iJumpFlags[client] |= JF_CanDoubleJump;
	*/

	g_iJumpFlags[client] |= JF_CanBunnyHop;
	g_iJumpFlags[client] &= ~JF_HasFirstJump;
	// PrintCenterText(client, "正在落地 %d", !!(g_iJumpFlags[client] & JF_CanBunnyHop));
}

public void Event_PlayerJump(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;

	g_iJumpFlags[client] = JF_HasJumping|JF_HasFirstJump;
	// PrintCenterText(client, "起跳 %d", !!(g_iJumpFlags[client] & JF_CanBunnyHop));
	
	// 在这里是无法获取到向上速度的，必须等待下一帧
	if(g_fMaxGravityModify[client] >= 0.0)
		RequestFrame(ApplyJumpVelocity, client);
}

float CaclJumpVelocity(int client)
{
	bool ducking = ((GetClientButtons(client) & IN_DUCK) && (GetEntityFlags(client) & FL_DUCKING));
	
	// GetEntityGravity 返回 0.0，好像用不了
	float height = SquareRoot(2.0 * g_hCvarGravity.FloatValue * (ducking ? g_fJumpHeightDucking : g_fJumpHeight)/* / GetEntityGravity(client)*/);
	// PrintToChat(client, "d=%d, gg=%d, pg=%.2f, h=%.0f, jh=%.0f", ducking, g_hCvarGravity.IntValue, GetEntityGravity(client), height, (ducking ? g_fJumpHeightDucking : g_fJumpHeight));
	
	return height;
}

public void ApplyJumpVelocity(any client)
{
	if(!IsValidAliveClient(client) || g_fMaxGravityModify[client] < 0.0)
		return;
	
	float velocity[3];
	GetEntDataVector(client, g_iVelocityO, velocity);
	// velocity[0] *= g_fMaxGravityModify[client];
	// velocity[1] *= g_fMaxGravityModify[client];
	velocity[2] *= g_fMaxGravityModify[client];
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

/*
public void Event_DoorMoving(Event event, const char[] eventName, bool dontBroadcast)
{
	int chance = g_pCvarBotRP.IntValue;
	if(chance <= 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int door = event.GetInt("entindex");
	if(door <= MaxClients || !IsValidAliveClient(client) || !IsValidEdict(door))
		return;
	
	int hammerId = GetEntProp(door, Prop_Data, "m_iHammerID");
	PrintToChatAll("Client %N, Door %d, HammerID %d", client, door, hammerId);
	
	if(hammerId == 0)
		return;
	
	if(g_aDoorHandled.FindValue(hammerId) > -1)
		return;
	
	g_aDoorHandled.Push(hammerId);
	if(GetRandomInt(1, 100) <= chance)
		StatusSelectMenuFuncRP(client, false);
}
*/

public void Event_DoorEvent(Event event, const char[] eventName, bool dontBroadcast)
{
	int chance = g_pCvarBotRP.IntValue;
	if(chance <= 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client) || !IsFakeClient(client) || GetClientTeam(client) != 2)
		return;
	
	if(GetRandomInt(1, 100) <= chance)
		StatusSelectMenuFuncRP(client, false);
}

public void Event_AreaCleared(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bIsGamePlaying)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int area = event.GetInt("area");
	if(!IsValidAliveClient(client) || area <= 0)
		return;
	
	g_ttCleared[client] += 1;
	if(g_pCvarCleared.IntValue > 0 && g_ttCleared[client] >= g_pCvarCleared.IntValue)
	{
		GiveSkillPoint(client, 1);
		g_ttCleared[client] -= g_pCvarCleared.IntValue;

		if(g_pCvarAllow.BoolValue)
			PrintToChat(client, "\x03[提示]\x01 你因为把一些地方的僵尸清干净而获得 \x051\x01 硬币。");
	}
}

public void Event_PaincEventStart(Event event, const char[] eventName, bool dontBroadcast)
{
	/*
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	*/
	
	g_bIsPaincEvent = true;
	g_bIsPaincIncap = false;
	// PrintToChatTeam(2, "\x03[提示]\x01 玩家 \x04%N\x01 搞了一波尸潮。", client);
}

public void Event_PaincEventStop(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bIsPaincEvent || !g_bIsGamePlaying)
		return;

	g_bIsPaincEvent = false;
	if(!g_bIsPaincIncap)
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
				continue;
			
			g_ttPaincEvent[i] += 1;
			if(g_pCvarPaincEvent.IntValue > 0 && g_ttPaincEvent[i] >= g_pCvarPaincEvent.IntValue)
			{
				g_ttPaincEvent[i] -= g_pCvarPaincEvent.IntValue;

				if(g_pCvarAllow.BoolValue && !IsFakeClient(i))
					PrintToChat(i, "\x03[提示]\x01 你因为好几波尸潮没有人倒地或死亡而获得 \x051\x01 硬币。");
			}
		}
	}

	g_bIsPaincIncap = false;
}

public void Event_SurvivorRescued(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("rescuer"));
	int subject = GetClientOfUserId(event.GetInt("victim"));
	if(!IsValidAliveClient(client) || !IsValidClient(subject))
		return;

	if(client != subject)
		g_ttRescued[client] += 1;
	
	if(g_clSkill_1[subject] & SKL_1_Armor)
	{
		// 上限 127
		AddArmor(subject, 100 + (100 * IsPlayerHaveEffect(subject, 33)));
	}
	
	RegPlayerHook(subject, (g_Cvarhppack.BoolValue || IsPlayerHaveEffect(subject, 35)));
	
	if(g_iRoundEvent == 19)
	{
		/*
		static ConVar cv_respawnhealth;
		if(cv_respawnhealth == null)
			cv_respawnhealth = FindConVar("z_survivor_respawn_health");
		
		SetEntProp(client, Prop_Data, "m_iHealth", 1);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", cv_respawnhealth.FloatValue - 1.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		*/
		
		ApplyHealthSwap(subject);
	}
}

public void UpdateWeaponAmmo(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	int client = pack.ReadCell();
	if(!IsValidAliveClient(client))
		return;
	
	static char classname[64], className[64];
	pack.ReadString(classname, 64);
	
	bool fullClip = pack.ReadCell();
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon > MaxClients && IsValidEntity(weapon))
		GetEntityClassname(weapon, className, 64);
	if(weapon < MaxClients || !IsValidEntity(weapon) || !StrEqual(className, classname, false))
		weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && IsValidEntity(weapon))
		GetEntityClassname(weapon, className, 64);
	if(weapon < MaxClients || !IsValidEntity(weapon) || !StrEqual(className, classname, false))
		return;
	
	if(fullClip && !GetEntProp(weapon, Prop_Send, "m_bInReload"))
	{
		SetEntProp(weapon, Prop_Send, "m_iClip1", CalcPlayerClip(client, weapon));
		
		int skin = 0;
		if(IsPlayerHaveEffect(client, 39) && g_tWeaponSkin.GetValue(classname, skin) && skin > 0)
		{
			if(!GetEntProp(weapon, Prop_Send, "m_nSkin"))
				SetEntProp(weapon, Prop_Send, "m_nSkin", GetRandomInt(0, skin));
		}
	}
	
	AddAmmo(client, 999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	
	if((g_clSkill_1[client] & SKL_1_NoRecoil) && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | 4);
	}
}

public void UpdateLaserSign(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	int client = pack.ReadCell();
	if(!IsValidAliveClient(client))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon > MaxClients && IsValidEntity(weapon))
		if((g_clSkill_1[client] & SKL_1_NoRecoil) && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
		{
			int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
			SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | 4);
		}
	
	weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && IsValidEntity(weapon))
		if((g_clSkill_1[client] & SKL_1_NoRecoil) && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
		{
			int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
			SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | 4);
		}
}

public void Event_AmmoPickup(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(!IsValidEntity(weapon))
		return;
	
	char classname[64];
	GetEntityClassname(weapon, classname, 64);
	
	DataPack data = CreateDataPack();
	data.WriteCell(client);
	data.WriteString(classname);
	data.WriteCell(false);
	
	// AddAmmo(client, 999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	RequestFrame(UpdateWeaponAmmo, data);
}

public void Event_WeaponPickuped(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	char classname[64];
	event.GetString("item", classname, 64);
	Format(classname, 64, "weapon_%s", classname);
	if(StrContains(classname, "shotgun", false) != -1 || StrContains(classname, "smg", false) != -1 ||
		StrContains(classname, "rifle", false) != -1 || StrContains(classname, "sniper", false) != -1 ||
		StrContains(classname, "pistol", false) != -1 || StrContains(classname, "launcher", false) != -1)
	{
		DataPack data = CreateDataPack();
		data.WriteCell(client);
		data.WriteString(classname);
		data.WriteCell(true);
		
		// 捡起固定刷武器和插件给的武器只会触发 item_pickup，不会触发 player_use
		RequestFrame(UpdateWeaponAmmo, data);
	}
	
	if((g_clSkill_5[client] & SKL_5_MeleeRange) || (g_clSkill_5[client] & SKL_5_ShoveRange))
	{
		DataPack data = CreateDataPack();
		data.WriteCell(client);
		data.WriteString(classname);
		
		RequestFrame(NotifyWeaponRange, data);
	}
	
	// PrintToChat(client, "item_pickup");
}

public void Event_PlayerUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	int item = event.GetInt("targetid");
	if(item <= MaxClients || !IsValidEntity(item))
		return;
	
	static char classname[64];
	if(!GetEntityClassname(item, classname, sizeof(classname)))
		return;
	
	bool isPistol = (StrContains(classname, "pistol", false) != -1);
	if(StrContains(classname, "smg", false) == -1 && StrContains(classname, "rifle", false) == -1 &&
		StrContains(classname, "sniper", false) == -1 && StrContains(classname, "shotgun", false) == -1 &&
		StrContains(classname, "grenade_launcher", false) == -1 && !isPistol)
		return;
	
	// 捡起地上零散武器只会触发 player_use，而不会触发 item_pickup
	int maxAmmo = GetDefaultAmmo(item);
	if(!isPistol && maxAmmo > -1 && HasEntProp(item, Prop_Send, "m_upgradeBitVec") && g_iExtraPrimaryAmmo[client] > 0)
	{
		g_iExtraAmmo[client] = g_iExtraPrimaryAmmo[client] - maxAmmo;
		if(g_iExtraAmmo[client] < 0)
			g_iExtraAmmo[client] = 0;
		
		RequestFrame(UpdateAmmo, client);
	}
	else if(!isPistol)
	{
		g_iExtraAmmo[client] = 0;
	}
	
	if(g_clSkill_1[client] & SKL_1_NoRecoil)
	{
		DataPack data = CreateDataPack();
		data.WriteCell(client);
		// data.WriteCell(item);
		RequestFrame(UpdateLaserSign, data);
	}
	
	// PrintToChat(client, "player_use");
}

public void UpdateAmmo(any client)
{
	if(IsValidAliveClient(client))
		AddAmmo(client, 0);
}

public void Event_WeaponDropped(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	int weapon = event.GetInt("propid");
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return;
	
	if((g_clSkill_1[client] & SKL_1_NoRecoil) && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags & ~4);
	}
	
	char classname[64];
	if(g_iExtraAmmo[client] > 0 && GetEdictClassname(weapon, classname, sizeof(classname)) &&
		(StrContains(classname, "smg", false) != -1 || StrContains(classname, "rifle", false) != -1 ||
		StrContains(classname, "sniper", false) != -1 || StrContains(classname, "shotgun", false) != -1 ||
		StrContains(classname, "grenade_launcher", false) != -1))
	{
		DataPack data = CreateDataPack();
		data.WriteCell(weapon);
		data.WriteCell(g_iExtraAmmo[client]);
		RequestFrame(PatchExtraPrimaryAmmo, data);
	}
}

public void PatchExtraPrimaryAmmo(any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	int weapon = data.ReadCell();
	int ammo = data.ReadCell();
	
	if(weapon > MaxClients && IsValidEntity(weapon) && HasEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo"))
		SetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo", GetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo") + ammo);
}

public Action PlayerHook_OnWeaponCanUse(int client, int weapon)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	static char classname[64], weaponName[64];
	
	int primary = GetPlayerWeaponSlot(client, 0);
	if(primary <= MaxClients || !IsValidEdict(primary) || !GetEdictClassname(primary, weaponName, sizeof(weaponName)))
		return Plugin_Continue;
	
	if(!GetEdictClassname(weapon, classname, sizeof(classname)) || StrContains(classname, "weapon_", false) != 0)
		return Plugin_Continue;
	
	int isSpawnner = (StrContains(classname, "_spawn", false) > 0);
	if(isSpawnner)
		ReplaceString(classname, sizeof(classname), "_spawn", "", false);
	
	if(!StrEqual(weaponName, classname, false))
		return Plugin_Continue;
	
	int ammoType = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
	int currentAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
	
	if(isSpawnner)
	{
		int defaultAmmo = GetDefaultAmmo(primary, ammoType);
		// PrintToChat(client, "当前：%d丨默认：%d", currentAmmo, defaultAmmo);
		if(currentAmmo >= defaultAmmo)
		{
			// 修复无法补充弹药的问题
			AddAmmo(client, 999);
			return Plugin_Handled;
		}
	}
	else
	{
		int extraAmmo = GetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo");
		// PrintToChat(client, "当前：%d丨目标：%d", currentAmmo + g_iExtraAmmo[client], extraAmmo);
		if(currentAmmo + g_iExtraAmmo[client] >= extraAmmo)
		{
			// 防止捡起弹药比现在少的武器
			return Plugin_Handled;
		}
		else
		{
			// 修复在 player_use 无法获取到正确 m_iExtraPrimaryAmmo 的问题
			g_iExtraPrimaryAmmo[client] = extraAmmo;
		}
	}
	
	return Plugin_Continue;
}

public void NotifyWeaponRange(any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	char classname[64];
	int client = data.ReadCell();
	data.ReadString(classname, 64);
	
	if(!IsValidAliveClient(client))
		return;
	
	int weapon = -1;
	bool isMelee = false;
	if(StrContains(classname, "melee", false) > -1)
	{
		weapon = GetPlayerWeaponSlot(client, 1);
		if(IsValidEntity(weapon) && HasEntProp(weapon, Prop_Data, "m_strMapSetScriptName"))
		{
			GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", classname, 64);
			isMelee = true;
		}
	}
	else
	{
		weapon = GetPlayerWeaponSlot(client, 0);
	}
	
	int range;
	char msg[255];
	msg[0] = EOS;
	
	if((g_clSkill_5[client] & SKL_5_MeleeRange) && isMelee)
	{
		if(g_tMeleeRange == null || !g_tMeleeRange.GetValue(classname, range))
			range = g_iUnknownMeleeRange;
		
		FormatEx(msg, 255, "攻击范围 %d", range);
	}
	if(g_clSkill_5[client] & SKL_5_ShoveRange)
	{
		if(g_tShoveRange == null || !g_tShoveRange.GetValue(classname, range))
			range = g_iUnknownShoveRange;
		
		if(msg[0] == EOS)
			FormatEx(msg, 255, "推范围 %d", range);
		else
			Format(msg, 255, "%s丨推范围 %d", msg, range);
	}
	
	if(msg[0] != EOS)
		PrintCenterText(client, msg);
	
	int skin = 0;
	if(IsPlayerHaveEffect(client, 39) && g_tWeaponSkin.GetValue(classname, skin) && skin > 0)
	{
		if(weapon > MaxClients && IsValidEntity(weapon) && !GetEntProp(weapon, Prop_Send, "m_nSkin"))
			SetEntProp(weapon, Prop_Send, "m_nSkin", GetRandomInt(0, skin));
	}
}

public void Event_UpgradePickup(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int upgradePack = event.GetInt("upgradeid");
	if(!IsValidAliveClient(client) || upgradePack < MaxClients || !IsValidEntity(upgradePack))
		return;
	
	char upgradeName[64];
	GetEntityClassname(upgradePack, upgradeName, 64);
	if(!StrEqual(upgradeName, "upgrade_ammo_incendiary", false) &&
		!StrEqual(upgradeName, "upgrade_ammo_explosive", false))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return;
	
	// 希望不会冲突吧
	int maxClip = CalcPlayerClip(client, weapon);
	SetEntProp(weapon, Prop_Send, "m_iClip1", maxClip);
	
	int mulEffect = IsPlayerHaveEffect(client, 31);
	if(mulEffect > 0)
		maxClip += maxClip * mulEffect;
	if(maxClip > 255)
		maxClip = 255;
	if(maxClip > 0)
		SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", maxClip);
	
	if((g_clSkill_1[client] & SKL_1_KeepClip) && g_iReloadWeaponUpgradeClip[client] > 0)
	{
		int flags = 0;
		if(upgradeName[13] == 'i' || upgradeName[13] == 'I')
			flags = 1;
		else if(upgradeName[13] == 'e' || upgradeName[13] == 'E')
			flags = 2;
		
		if(flags > 0 && (g_iReloadWeaponUpgrade[client] & flags))
		{
			int clip = GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") + g_iReloadWeaponUpgradeClip[client];
			if(clip > 255)	// 8bit(1bytes)
				clip = 255;
			
			SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clip);
		}
	}
	
	if(g_clSkill_1[client] & SKL_1_KeepClip)
		AddAmmo(client, 999);
	
	if(g_iLastWeaponAmmo[client] > 0)
	{
		SetEntProp(client, Prop_Send, "m_iAmmo", g_iLastWeaponAmmo[client], _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
		g_iLastWeaponAmmo[client] = 0;
	}
	
	g_iReloadWeaponUpgradeClip[client] = 0;
	g_iReloadWeaponUpgrade[client] = 0;
}

public void Event_PlayerHitByVomit(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidAliveClient(client))
		return;
	
	if(g_clSkill_2[client] & SKL_2_ProtectiveSuit)
		RequestFrame(UpdateVomitDuration, client);
	
	if(IsValidAliveClient(attacker) && (g_clSkill_4[attacker] & SKL_4_Terror) && GetClientTeam(attacker) == 2 && GetClientTeam(client) == 3)
	{
		g_bIsHitByVomit[client] = true;
		
		// 胆汁效果紫色
		CreateGlowModel(client, 0xFF80FF);
	}
}

public void Event_PlayerVomitTimeout(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_bIsHitByVomit[client] = false;
	
	if(GetClientTeam(client) == 3)
	{
		if(GetCurrentVictim(client) > 0)
		{
			// 控制状态红色
			CreateGlowModel(client, 0x8080FF);
		}
		else
		{
			// 常规状态无光圈
			RemoveGlowModel(client);
		}
	}
}

public void Event_PlayerShoved(Event event, const char[] eventName, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(!IsValidAliveClient(attacker) || !IsValidAliveClient(victim))
		return;
	
	int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if((g_clSkill_4[attacker] & SKL_4_Shove) && zClass == ZC_CHARGER)
	{
		// 游戏自带的 z_charger_allow_shove 对锤地板时的牛无效，仍然需要自行解控
		if(!g_hCvarChargerShove.BoolValue || GetEntPropEnt(victim, Prop_Send, "m_pummelVictim") > 0)
		{
			// L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(victim), GetClientUserId(attacker));
			L4D_StaggerPlayer(victim, attacker, NULL_VECTOR);
			
			// 放开受害者
			int survivor = GetEntPropEnt(victim, Prop_Send, "m_pummelVictim");
			if(IsValidAliveClient(survivor))
				ForceDropVictim(victim, survivor);
			survivor = GetEntPropEnt(victim, Prop_Send, "m_carryVictim");
			if(IsValidAliveClient(survivor))
				ForceDropVictim(victim, survivor);
			
			// 停止冲锋
			if(IsChargerCharging(victim))
			{
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
				
				if(g_pfnEndCharge != null)
					SDKCall(g_pfnEndCharge, GetEntPropEnt(victim, Prop_Send, "m_customAbility"));
			}
		}
	}
	
	if((g_clSkill_1[attacker] & SKL_1_DisplayHealth) && zClass == ZC_SURVIVOR && !IsFakeClient(attacker))
	{
		char msg[255];
		int damage, health, speed, gravity, crit;
		CalcPlayerAttr(victim, damage, health, speed, gravity, crit, true);
		int power = CalcPlayerPower(victim);
		
		FormatEx(msg, sizeof(msg), "%N\n战斗力：%d|攻击+%d％|生命+%d％|速度+%d％|跳跃+%d％|暴击+%d‰", victim, power, damage, health, speed, gravity, crit);
		if(GetEntProp(victim, Prop_Send, "m_bIsOnThirdStrike"))
			Format(msg, sizeof(msg), "%s\n黑白状态", msg);
		
		PrintHintText(attacker, msg);
	}
}

public void Event_BulletImpact(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon <= MaxClients || !IsValidEdict(weapon))
		return;
	
	static char classname[64];
	if(!GetEdictClassname(weapon, classname, 64))
		return;
	
	float vEnd[3];
	vEnd[0] = event.GetFloat("x");
	vEnd[1] = event.GetFloat("y");
	vEnd[2] = event.GetFloat("z");
	
	if(g_clSkill_3[client] & SKL_3_Ricochet)
	{
		if(StrContains(classname, "smg", false) > -1 || StrContains(classname, "rifle", false) > -1 ||
			StrContains(classname, "sniper", false) > -1 || StrContains(classname, "magnum", false) > -1)
		{
			float fEyeAngles[3], fBeamOneStart[3], fBeamOneEnd[3], fBeamEndNormals[3], fBeamTwoDirection[3], fBeamForwards[3], fBeamTwoStart[3], fBeamTwoEnd[3];
			GetClientEyeAngles(client, fEyeAngles);
			GetClientEyePosition(client, fBeamOneStart);
			float damage = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_Damage) * 0.5;
			
			// 反弹降低伤害
			/*
			if(g_WeaponDamage.GetValue(classname, damage) && damage > 0.0)
			{
				// PrintCenterText(client, "dmg %.0f", damage);
				damage /= 2;
			}
			else
			{
				PrintCenterText(client, "no dmg");
			}
			*/
			
			Handle trace = TR_TraceRayFilterEx(fBeamOneStart, fEyeAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, client);
			if(TR_DidHit(trace))
			{
				fBeamOneEnd = vEnd;
				// TR_GetEndPosition(fBeamOneEnd, trace);
				TR_GetPlaneNormal(trace, fBeamEndNormals);
				delete trace;
				
				for(int i = 0;i < 3; i++)
					fBeamTwoDirection[i] = fBeamOneEnd[i] - fBeamOneStart[i];
				
				GetVectorAngles(fBeamTwoDirection, fBeamTwoDirection);
				GetAngleVectors(fBeamTwoDirection, fBeamForwards, NULL_VECTOR, NULL_VECTOR);
				
				for(int i = 0;i < 3; i++)
					fBeamTwoEnd[i] = fBeamOneEnd[i] + fBeamForwards[i] * 8192.0;
				
				float dotProduct = GetVectorDotProduct(fBeamEndNormals, fBeamForwards);
				ScaleVector(fBeamEndNormals, dotProduct);
				ScaleVector(fBeamEndNormals, 2.0);
				
				float vBounceVec[3];
				SubtractVectors(fBeamForwards, fBeamEndNormals, vBounceVec);
				
				float fBeamTwoFinalDirection[3];
				GetVectorAngles(vBounceVec, fBeamTwoFinalDirection);
				
				fBeamTwoStart = fBeamOneEnd;
				
				trace = TR_TraceRayFilterEx(fBeamTwoStart, fBeamTwoFinalDirection, MASK_SHOT, RayType_Infinite, TraceRayDontHitTeam, 2);
				if(TR_DidHit(trace))
				{
					TR_GetEndPosition(fBeamTwoEnd, trace);
					int iTarget = TR_GetEntityIndex(trace);
					delete trace;
					
					// TODO: 计算暴击和额外伤害
					if(iTarget > 0 && damage > 0.0 && GetVectorDistance(fBeamTwoStart, fBeamTwoEnd) <= L4D2_GetFloatWeaponAttribute(classname, L4D2FWA_Range))
					{
						// EmitSoundToAll(SOUND_IMPACT1, iTarget,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1, fBeamTwoEnd, NULL_VECTOR, true, 0.0);
						EmitAmbientSound(SOUND_IMPACT1, fBeamTwoEnd, iTarget, SNDLEVEL_TRAFFIC);
						SDKHooks_TakeDamage(iTarget, weapon, client, damage, DMG_BULLET, weapon, NULL_VECTOR, fBeamTwoEnd);
						ShowParticle(fBeamTwoEnd, PARTICLE_BLOOD, 0.5);
					}
					else
					{
						// EmitSoundToAll(SOUND_IMPACT2, 0,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1, fBeamTwoEnd, NULL_VECTOR, true, 0.0);
						EmitAmbientSound(SOUND_IMPACT2, fBeamTwoEnd, 0, SNDLEVEL_TRAFFIC);
					}
					
					// 子弹效果
					TE_SetupBeamPoints(fBeamTwoStart, fBeamTwoEnd, g_BeamSprite, 0, 0, 0, 0.06, 0.01, 0.08, 1, 0.0, {200, 200, 200, 230}, 0);
					TE_SendToAll();
				}
				else
				{
					delete trace;
				}
			}
			else
			{
				// PrintCenterText(client, "no hit");
				delete trace;
			}
		}
		
	}
	
	if(g_clSkill_4[client] & SKL_4_FastFired)
	{
		if(StrContains(classname, "rifle_desert", false) > 0)
			SetWeaponSpeed2(weapon, 1.25);
	}
}

public void Event_GiftPickup(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	if(g_pCvarGiftChance.IntValue > 0)
		RewardPicker(client);
}

public bool TraceRayDontHitTeam(int entity, int mask, any data)
{
	if(IsValidClient(entity) && GetClientTeam(entity) == data)
		return false;
	
	return true;
}

void UpdateVomitDuration(any client)
{
	if(!IsValidAliveClient(client))
		return;
	
	static ConVar cv_bile_duration;
	if(cv_bile_duration == null)
		cv_bile_duration = FindConVar("survivor_it_duration");
	
	// PropFieldType type = PropField_Unsupported;
	// int itOffset = FindDataMapInfo(client, "m_itTimer", type);
	
	// PrintToChat(client, "m_itTimer = %d, m_timestamp = %d", FindSendPropInfo("CTerrorPlayer", "m_itTimer"), FindSendPropInfo("DT_CountdownTimer", "m_timestamp"));
	// SetEntDataFloat(client, g_iBileTimestamp, GetGameTime() + (cv_bile_duration.FloatValue / 2), true);
	// SetEntPropFloat(client, Prop_Send, "m_itTimer", GetGameTime() + (cv_bile_duration.FloatValue / 2), 2);
	L4D2_RunScript("NetProps.SetPropFloat(GetPlayerFromUserID(%d),\"m_itTimer.m_timestamp\",Time()+%.2f)", GetClientUserId(client), (cv_bile_duration.FloatValue / 2));
	CreateTimer(cv_bile_duration.FloatValue / 2, Timer_UnVimit, client, TIMER_FLAG_NO_MAPCHANGE);
	g_bIsHitByVomit[client] = true;
}

public Action Timer_UnVimit(Handle timer, any client)
{
	if(IsValidAliveClient(client))
		L4D_OnITExpired(client);
	
	g_bIsHitByVomit[client] = false;
}

stock void PrintToChatTeam(int team, const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 3);

	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || GetClientTeam(i) != team)
			continue;

		PrintToChat(i, buffer);
	}
}

public void Event_PlayerTeam(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int disconnect = event.GetInt("disconnect");
	bool bot = event.GetBool("isbot");
	if(!IsValidClient(client))
		return;

	int newTeam = event.GetInt("team");
	int oldTeam = event.GetInt("oldteam");

	// 当玩家切换到观察者或者离开游戏时停止正在播放的音乐
	if(!bot && (disconnect || newTeam <= 1))
	{
		// PrintToServer("玩家 %N 不再进行游戏了。", client);
		CreateHideMotd(client);
	}

	/*
	if(newTeam > 1 && !bot && g_pCvarAllow.BoolValue)
	{
		char steamId[64];
		GetClientAuthId(client, AuthId_Steam2, steamId, 64, false);

		if(steamId[0] == EOS || StrEqual(steamId, "BOT", false) || StrEqual(steamId, "STEAM_ID_PENDING", false) ||
			StrEqual(steamId, "STEAM_ID_STOP_IGNORING_RETVALS", false) || StrEqual(steamId, "STEAM_1:0:0", false))
		{
			PrintToChat(client, "\x03[警告]\x01 你的 SteamID 无效，将不提供保存功能！");
			PrintToChat(client, "\x03[警告]\x01 当前的 SteamID 为：%s", steamId);
			PrintToChat(client, "\x03[提示]\x01 解决这个问题的方法：更换/更新破解补丁或使用正版游戏。");
			PrintHintText(client, "========= 警告 =========\n由于你的 SteamID 无效，将不提供保存功能\n%s\n建议更换破解补丁或者使用正版游戏", steamId);
		}
	}
	*/

	if(!IsFakeClient(client))
	{
		if(oldTeam <= 1 && newTeam >= 2)
		{
			// ClientSaveToFileLoad(client, g_pCvarSaveStatus.BoolValue);
			// RegPlayerHook(client, false);
			CreateTimer(0.6, Timer_RegPlayerHook, client, TIMER_FLAG_NO_MAPCHANGE);
			// PrintToServer("读取 %N 的数据，原因：加入队伍");
		}
		else if(oldTeam >= 2 && newTeam >= 2)
		{
			// RegPlayerHook(client, false);
			CreateTimer(0.1, Timer_RegPlayerHook, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		else if(oldTeam >= 2 && newTeam == 1)
		{
			ClientSaveToFileSave(client, g_pCvarSaveStatus.BoolValue);
		}
	}
	else if(newTeam == 2 && g_pCvarSurvivorBot.BoolValue)
	{
		GenerateRandomStats(client, g_pCvarSurvivorBot.IntValue > 1);
		// RegPlayerHook(client, false);
		CreateTimer(1.0, Timer_RegPlayerHook, client, TIMER_FLAG_NO_MAPCHANGE);
		PrintToServer("为生还者机器人 %N 生成随机属性，战斗力 %d", client, CalcPlayerPower(client));
	}
	else if(newTeam == 3 && g_pCvarInfectedBot.BoolValue)
	{
		GenerateRandomStats(client, g_pCvarInfectedBot.IntValue > 1);
		// RegPlayerHook(client, false);
		CreateTimer(1.0, Timer_RegPlayerHook, client, TIMER_FLAG_NO_MAPCHANGE);
		PrintToServer("为生还者机器人 %N 生成随机属性，战斗力 %d", client, CalcPlayerPower(client));
	}
	
	if(newTeam <= 1)
	{
		g_iExtraArmor[client] = 0;
		g_iExtraAmmo[client] = 0;
	}
	
	// Initialization(client);
	g_iJumpFlags[client] = JF_None;
	g_bCanGunShover[client] = true;
}

public Action Timer_RegPlayerHook(Handle timer, any client)
{
	if(IsValidAliveClient(client))
		RegPlayerHook(client, false);
}

public void Event_PlayerEnterStartArea(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;

	RegPlayerHook(client, false);
}

public void Event_PlayerReplaceBot(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if(!IsValidClient(client))
		return;

	// g_bHasFirstJoin[client] = false;
	g_bHasJumping[client] = false;
	// RegPlayerHook(client, false);
	CreateTimer(0.1, Timer_RegPlayerHook, client, TIMER_FLAG_NO_MAPCHANGE);
	
	// 修复数值不正常
	g_iExtraAmmo[client] = 0;
	g_iExtraArmor[client] = 0;
	AddHealth(client, 0);
	AddAmmo(client, 0);
	AddArmor(client, 0);
}

public void Event_BotReplacePlayer(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if(!IsValidClient(client))
		return;
	
	ClientSaveToFileSave(client, g_pCvarSaveStatus.BoolValue);
	
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!IsValidClient(bot))
		return;
	
	g_clSkill_1[bot] = g_clSkill_1[client];
	g_clSkill_2[bot] = g_clSkill_2[client];
	g_clSkill_3[bot] = g_clSkill_3[client];
	g_clSkill_4[bot] = g_clSkill_4[client];
	g_clSkill_5[bot] = g_clSkill_5[client];
	g_clAngryMode[bot] = g_clAngryMode[client];
	g_clAngryPoint[bot] = g_clAngryPoint[client];
	g_iExtraArmor[bot] = g_iExtraArmor[client];
	g_iExtraAmmo[bot] = g_iExtraAmmo[client];
	g_fFreezeTime[bot] = g_fFreezeTime[client];
	
	if(g_mEquipData[bot] == null)
		g_mEquipData[bot] = CreateTrie();
	else
		g_mEquipData[bot].Clear();
	
	for(int i = 0; i < sizeof(g_clCurEquip[]); ++i)
	{
		g_clCurEquip[bot][i] = g_clCurEquip[client][i];
		if(!g_clCurEquip[bot][i])
			continue;
		
		static char key[16];
		static EquipData_t data;
		
		IntToString(g_clCurEquip[bot][i], key, sizeof(key));
		if(g_mEquipData[client].GetArray(key, data, sizeof(data)))
			g_mEquipData[bot].SetArray(key, data, sizeof(data));
		else
			g_clCurEquip[bot][i] = 0;
	}
	
	CreateTimer(0.1, Timer_RegPlayerHook, bot, TIMER_FLAG_NO_MAPCHANGE);
	PrintToServer("%N copy to %N", client, bot);
}

void RegPlayerHook(int client, bool fullHealth = false)
{
	int baseMaxHealth = GetMaxHealth(client);
	
	int damage, health, speed, gravity, crit;
	CalcPlayerAttr(client, damage, health, speed, gravity, crit);
	
	int chance, minChDmg, maxChDmg, baseDmg;
	CalcDamageExtra(client, chance, minChDmg, maxChDmg, baseDmg);
	
	for(int i = 0; i < sizeof(g_clCurEquip[]); i++)
	{
		g_iActiveEffects[client][i] = 0;
		
		if(!g_clCurEquip[client][i])
			continue;
		
		static char key[16];
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		
		static EquipData_t data;
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
			continue;
		
		g_iActiveEffects[client][i] = data.effect;
	}
	
	{
		Call_StartForward(g_fwOnUpdateStatus);
		Call_PushCell(client);
		
		bool refFullHealth = fullHealth;
		Call_PushCellRef(refFullHealth);
		
		int refDamage = baseDmg;
		Call_PushCellRef(refDamage);
		
		int refHealth = health;
		Call_PushCellRef(refHealth);
		
		int refSpeed = speed;
		Call_PushCellRef(refSpeed);
		
		int refGravity = gravity;
		Call_PushCellRef(refGravity);
		
		int refChance = chance;
		Call_PushCellRef(refChance);
		
		int refChanceDamageMin = minChDmg;
		Call_PushCellRef(refChanceDamageMin);
		
		int refChanceDamageMax = maxChDmg;
		Call_PushCellRef(refChanceDamageMax);
		
		int refEffects[sizeof(g_iActiveEffects[])];
		Call_PushArrayEx(refEffects, sizeof(refEffects), SM_PARAM_COPYBACK);
		Call_PushCell(sizeof(refEffects));
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult == Plugin_Changed)
		{
			fullHealth = refFullHealth;
			baseDmg = refDamage;
			health = refHealth;
			speed = refSpeed;
			gravity = refGravity;
			chance = refChance;
			minChDmg = refChanceDamageMin;
			maxChDmg = refChanceDamageMax;
			
			for(int i = 0; i < sizeof(refEffects); i++)
				g_iActiveEffects[client][i] = refEffects[i];
		}
	}
	
	int maxHealth = (baseMaxHealth + (baseMaxHealth * health / 100));
	SetEntProp(client, Prop_Data, "m_iMaxHealth", maxHealth);
	g_fMaxSpeedModify[client] = 1.0 + (speed / 100.0);
	g_fMaxGravityModify[client] = 1.0 + (gravity / 100.0);
	g_iDamageBase[client] = baseDmg;
	g_iDamageChance[client] = chance;
	g_iDamageChanceMax[client] = maxChDmg;
	g_iDamageChanceMin[client] = minChDmg;
	
	float curTime = GetEngineTime();
	g_ctPainPills[client] = (g_clSkill_2[client] & SKL_2_PainPills ? curTime + 120.0 : 0.0);
	g_ctPipeBomb[client] = (g_clSkill_2[client] & SKL_2_PipeBomb ? curTime + 100.0 : 0.0);
	g_ctDefibrillator[client] = (g_clSkill_2[client] & SKL_2_Defibrillator ? curTime + 200.0 : 0.0);
	g_ctFullHealth[client] = (g_clSkill_2[client] & SKL_2_FullHealth ? curTime + 300.0 : 0.0);
	g_ctSelfHeal[client] = (g_clSkill_3[client] & SKL_3_SelfHeal ? curTime + 200.0 : 0.0);
	g_ctGodMode[client] = (g_clSkill_3[client] & SKL_3_GodMode ? curTime + 80.0 : 0.0);
	g_ctConvTemp[client] = (g_clSkill_4[client] & SKL_4_TempRespite ? curTime + 2.0 : 0.0);
	g_csHasGodMode[client] = false;
	
	if(fullHealth)
	{
		// 满血
		SetEntProp(client, Prop_Data, "m_iHealth", maxHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		
		// 脱离黑白状态
		SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
	}
	
	SDKUnhook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	// SDKUnhook(client, SDKHook_OnTakeDamagePost, PlayerHook_OnTakeDamagePost);
	SDKUnhook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKUnhook(client, SDKHook_TraceAttackPost, PlayerHook_OnTraceAttackPost);
	SDKUnhook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKUnhook(client, SDKHook_PostThinkPost, PlayerHook_OnPostThinkPost);
	SDKUnhook(client, SDKHook_GetMaxHealth, PlayerHook_OnGetMaxHealth);
	SDKUnhook(client, SDKHook_WeaponCanUse, PlayerHook_OnWeaponCanUse);
	SDKHook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamage);
	// SDKHook(client, SDKHook_OnTakeDamagePost, PlayerHook_OnTakeDamagePost);
	SDKHook(client, SDKHook_TraceAttack, PlayerHook_OnTraceAttack);
	// SDKHook(client, SDKHook_TraceAttackPost, PlayerHook_OnTraceAttackPost);
	SDKHook(client, SDKHook_PreThinkPost, PlayerHook_OnPreThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, PlayerHook_OnPostThinkPost);
	SDKHook(client, SDKHook_GetMaxHealth, PlayerHook_OnGetMaxHealth);
	SDKHook(client, SDKHook_WeaponCanUse, PlayerHook_OnWeaponCanUse);
	
	if(GetClientTeam(client) == 2)
	{
		// 超过就会出 bug
		if(maxHealth > g_iMaxHealHealth)
			maxHealth = g_iMaxHealHealth;
		
		if(maxHealth > g_hCvarFirstAidMaxHeal.IntValue)
			g_hCvarFirstAidMaxHeal.IntValue = maxHealth;
		if(maxHealth > g_hCvarPainPillsMaxHeal.IntValue)
			g_hCvarPainPillsMaxHeal.IntValue = maxHealth;
	}
}

public void PlayerHook_OnPostThinkPost(int client)
{
	if((g_clSkill_1[client] & SKL_1_NoRecoil) && (GetClientButtons(client) & IN_ATTACK) &&
		!IsSurvivorHeld(client) && !IsPlayerIncapped(client) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		// 无后坐力
		SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
		// ChangeEdictState(client, FindDataMapInfo(client, "m_iShotsFired"));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", Float:{0.0, 0.0, 0.0});
		// ChangeEdictState(client, FindDataMapInfo(client, "m_vecPunchAngle"));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", Float:{0.0, 0.0, 0.0});
		// ChangeEdictState(client, FindDataMapInfo(client, "m_vecPunchAngleVel"));
	}
}

public void PlayerHook_OnPreThinkPost(int client)
{
	/*
	if(g_clSkill_1[client] & SKL_1_NoRecoil)
	{
		// 无后坐力
		SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
		// ChangeEdictState(client, FindDataMapInfo(client, "m_iShotsFired"));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", Float:{0.0, 0.0, 0.0});
		// ChangeEdictState(client, FindDataMapInfo(client, "m_vecPunchAngle"));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", Float:{0.0, 0.0, 0.0});
		// ChangeEdictState(client, FindDataMapInfo(client, "m_vecPunchAngleVel"));
	}
	*/
	
	float maxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	
	int flags = GetEntityFlags(client);
	int buttons = GetClientButtons(client);
	if(GetClientTeam(client) == 2 && (flags & FL_ONGROUND) && !IsPlayerIncapped(client) &&
		!(buttons & (IN_SPEED|IN_WALK)) && !GetEntProp(client, Prop_Send, "m_bAdrenalineActive") &&
		GetCurrentAttacker(client) == -1 && IsPlayerHaveEffect(client, 38))
	{
		static ConVar survivor_speed;
		if(survivor_speed == null)
			survivor_speed = FindConVar("survivor_speed");
		
		bool isWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") > 0);
		bool isLimp = ((GetEntProp(client, Prop_Data, "m_iHealth") + GetPlayerTempHealth(client)) / GetEntProp(client, Prop_Data, "m_iMaxHealth") < g_hCvarLimpHealth.IntValue);
		float speed = (((flags & FL_DUCKING) || (buttons & IN_DUCK)) ? g_hCvarDuckSpeed.FloatValue : survivor_speed.FloatValue);
		
		if((isWater || isLimp) && maxspeed < speed)
			maxspeed = speed;
	}
	
	// 移动速度，比 m_flLaggedMovementValue 好（不会更改跳跃速度）
	if(g_fMaxSpeedModify[client] >= 0.0)
		maxspeed *= g_fMaxSpeedModify[client];
	
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", maxspeed);
}

public int PlayerHook_OnGetMaxHealth(int client)
{
	// 修复 100 血无法打包
	return GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

int GetMaxHealth(int client)
{
	if(!IsValidClient(client))
		return 100;

	static ConVar cv_common, cv_witch, cv_smoker, cv_boomer, cv_hunter, cv_spitter,
		cv_jockey, cv_charger, cv_tank;
	if(cv_common == null)
	{
		cv_common = FindConVar("z_health");
		cv_witch = FindConVar("z_witch_health");
		cv_smoker = FindConVar("z_gas_health");
		cv_boomer = FindConVar("z_exploding_health");
		cv_hunter = FindConVar("z_hunter_health");
		cv_spitter = FindConVar("z_spitter_health");
		cv_jockey = FindConVar("z_jockey_health");
		cv_charger = FindConVar("z_charger_health");
		cv_tank = FindConVar("z_tank_health");
	}

	int zombieType = GetEntProp(client, Prop_Send, "m_zombieClass");
	switch(zombieType)
	{
		case 0:
			return cv_common.IntValue;
		case ZC_SMOKER:
			return cv_smoker.IntValue;
		case ZC_BOOMER:
			return cv_boomer.IntValue;
		case ZC_HUNTER:
			return cv_hunter.IntValue;
		case ZC_SPITTER:
			return cv_spitter.IntValue;
		case ZC_JOCKEY:
			return cv_jockey.IntValue;
		case ZC_CHARGER:
			return cv_charger.IntValue;
		case ZC_WITCH:
			return cv_witch.IntValue;
		case ZC_TANK:
			return cv_tank.IntValue;
		case ZC_SURVIVOR:
			return 100;
		case 10:
			return 0;
	}

	return -1;
}

public Action:TankEventEnd1(Handle:timer)
{
	SetConVarString(g_hCvarGodMode, "0");

	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03[\x05提示\x03]【无敌人类】\x04事件结束.");
}

public Action:TankEventEnd2(Handle:timer)
{
	SetConVarString(g_hCvarGravity, "800");

	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03[\x05提示\x03]【重力变异】\x04事件结束.");
}

public Action:TankEventEnd3(Handle:timer)
{
	SetConVarString(g_hCvarLimpHealth, "40");

	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03[\x05提示\x03]【减速诅咒】\x04事件结束.");
}

public Action:TankEventEnd4(Handle:timer)
{
	SetConVarString(g_hCvarInfinite, "0");

	if(g_pCvarAllow.BoolValue)
		PrintToChatAll("\x03[\x05提示\x03]【无限子弹】\x04事件结束.");
}

public Action:TankEventEnd5(Handle:timer)
{
	if(g_iRoundEvent != 3)
	{
		SetConVarString(g_hCvarMeleeRange, "75");

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]【剑气技能】\x04事件结束.");
	}
}

public Action:TankEventEnd7(Handle:timer)
{
	if(g_iRoundEvent != 4)
	{
		SetConVarString(g_hCvarDuckSpeed, "75");

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]【蹲坑神速】\x04事件结束.");
	}
}

public Action:TankEventEnd8(Handle:timer)
{
	if(g_iRoundEvent != 5)
	{
		SetConVarString(g_hCvarReviveTime, "5");

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]【疾速救援】\x04事件结束.");
	}
}

public Action:TankEventEnd9(Handle:timer)
{
	if(g_iRoundEvent != 5)
	{
		SetConVarString(g_hCvarMedicalTime, "5");

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]【疾速医疗】\x04事件结束.");
	}
}

public Action:TankEventEndx1(Handle:timer)
{
	if(g_iRoundEvent != 6)
	{
		SetConVarString(g_hCvarAdrenTime, "15");

		if(g_pCvarAllow.BoolValue)
			PrintToChatAll("\x03[\x05提示\x03]【极度兴奋】\x04事件结束.");
	}
}

public Action:CommandSlapPlayer(Handle:timer, any:client)
{
	if(g_bIsGamePlaying && g_csSlapCount[client] >= 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		// ServerCommand("sm_slap \"%N\" \"1\"",client);
		SlapPlayer(client, 1, true);
		g_csSlapCount[client] --;
		
		// CreateTimer(1.0, CommandSlapPlayer, client);
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

public Action:CommandSlapTank(Handle:timer, any:client)
{
	if(g_bIsGamePlaying && g_csSlapCount[client] >= 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		// ServerCommand("sm_slap \"%N\" \"0\"",client);
		SlapPlayer(client, 0, true);
		g_csSlapCount[client] --;
		
		// CreateTimer(0.2, CommandSlapTank, client);
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

public Event_SpitBurst(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		// SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		// CreateTimer(3.0, Superman, client);
	}
}

public Action:Superman(Handle:timer, any:client)
{
	g_csHasGodMode[client] = false;
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	if(!IsFakeClient(client)) PrintToChat(client, "\x03[\x05提示\x03]\x04无敌能力失效.");
}

/*
public void OnGetWeaponsInfo(int pThis, const char[] classname)
{
	static char value[64];
	InfoEditor_GetString(pThis, "clip_size", value, 64);
	g_WeaponClipSize.SetValue(classname, StringToInt(value));
	
	InfoEditor_GetString(pThis, "Damage", value, 64);
	g_WeaponDamage.SetValue(classname, StringToFloat(value));
}
*/

int GetDefaultClip(int weapon)
{
	if(!IsValidEntity(weapon) || !IsValidEdict(weapon))
		return -1;

	char className[64];
	if(!GetEdictClassname(weapon, className, 64))
		return -1;
	
	int clipSize = L4D2_GetIntWeaponAttribute(className, L4D2IWA_ClipSize);
	if(HasEntProp(weapon, Prop_Send, "m_hasDualWeapons") && GetEntProp(weapon, Prop_Send, "m_hasDualWeapons", 1))
		return clipSize * 2;
	
	return clipSize;
	/*
	int clip = -1;
	if(g_WeaponClipSize.GetValue(className, clip) && clip > 0)
	{
		if(HasEntProp(weapon, Prop_Send, "m_hasDualWeapons") && GetEntProp(weapon, Prop_Send, "m_hasDualWeapons", 1))
			return clip * 2;
		
		return clip;
	}
	*/
	
	/*
	if(StrContains(className, "smg", false) != -1 || StrEqual(className, "weapon_rifle", false) ||
		StrEqual(className, "weapon_rifle_sg552", false))
		return 50;

	if(StrEqual(className, "weapon_shotgun_chrome", false) || StrEqual(className, "weapon_pumpshotgun", false) ||
		StrEqual(className, "weapon_pistol_magnum"))
		return 8;

	if(StrContains(className, "shotgun", false) != -1)
		return 10;

	if(StrContains(className, "pistol", false) != -1)
	{
		if(GetEntProp(weapon, Prop_Send, "m_hasDualWeapons"))
			return 30;

		return 15;
	}

	if(StrEqual(className, "weapon_rifle_m60", false))
		return 150;

	if(StrEqual(className, "weapon_rifle_desert", false))
		return 60;

	if(StrEqual(className, "weapon_rifle_ak47", false))
		return 40;

	if(StrEqual(className, "weapon_sniper_military", false))
		return 30;

	if(StrEqual(className, "weapon_sniper_awp", false))
		return 20;

	if(StrEqual(className, "weapon_hunting_rifle", false) || StrEqual(className, "weapon_sniper_scout", false))
		return 15;

	if(StrEqual(className, "weapon_grenade_launcher", false))
		return 1;

	return 0;
	*/
}

int CalcPlayerClip(int client, int weapon)
{
	float scale = 1.0;
	scale += IsPlayerHaveEffect(client, 14) * 0.15;
	if(g_clSkill_4[client] & SKL_4_ClipSize)
		scale += 0.5;
	
	return RoundToZero(GetDefaultClip(weapon) * scale);
}

public Event_WeaponReload (Handle:event, const String:name[], bool:dontBroadcast)
{
	new iCid=GetClientOfUserId(GetEventInt(event,"userid"));
	if (!IsValidAliveClient(iCid) || GetClientTeam(iCid) != 2)
		return;
	
	int weapon = GetEntPropEnt(iCid, Prop_Send, "m_hActiveWeapon");
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return;
	
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	
	if ((g_clSkill_4[iCid] & SKL_4_FastReload))
		SoH_OnReload(iCid);
	
	if((g_clSkill_1[iCid] & SKL_1_KeepClip) && g_iReloadWeaponKeepClip[iCid] > 0)
	{
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		// PrintToChat(iCid, "clip size: %d", clip);
		
		if(clip == 0)
		{
			int clipSize = CalcPlayerClip(iCid, weapon);
			if(g_iReloadWeaponKeepClip[iCid] > clipSize)
				g_iReloadWeaponKeepClip[iCid] = clipSize;
			
			SetEntProp(weapon, Prop_Send, "m_iClip1", g_iReloadWeaponKeepClip[iCid]);
			SetEntProp(iCid, Prop_Send, "m_iAmmo", GetEntProp(iCid, Prop_Send, "m_iAmmo", _, ammoType) - g_iReloadWeaponKeepClip[iCid], _, ammoType);
			g_iReloadWeaponKeepClip[iCid] = 0;
		}
	}
	
	if(g_clSkill_4[iCid] & SKL_4_ClipSize)
	{
		// 检查换子弹
		HookPlayerReload(iCid, CalcPlayerClip(iCid, weapon));
		// PrintToLeft(iCid, "开始换弹匣：%d", RoundToZero(GetDefaultClip(weapon) * 1.5));
		// PrintToChat(iCid, "开始换弹匣：%d", RoundToZero(GetDefaultClip(weapon) * 1.5));
	}
	
	if(/*(g_clSkill_3[iCid] & SKL_3_MoreAmmo) && */g_iExtraAmmo[iCid] > 0 && weapon == GetPlayerWeaponSlot(iCid, 0))
	{
		int ammo = GetEntProp(iCid, Prop_Send, "m_iAmmo", _, ammoType);
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		int amount = g_iMaxAmmo - ammo - clip - GetDefaultClip(weapon) + 1;
		if(amount > g_iExtraAmmo[iCid])
			amount = g_iExtraAmmo[iCid];
		
		g_iExtraAmmo[iCid] -= amount;
		SetEntProp(iCid, Prop_Send, "m_iAmmo", ammo + amount, _, ammoType);
		PrintCenterText(iCid, "扩展备弹剩余 %d", g_iExtraAmmo[iCid]);
	}
}

public void Event_WeaponFire(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon))
		return;

	char weapons[64], classname[64];
	event.GetString("weapon", weapons, 64);
	GetEdictClassname(weapon, classname, 64);
	if(StrContains(classname, weapons, false) == -1)
		return;
	
	static ConVar sv_infinite_ammo, sv_infinite_primary_ammo;
	if(sv_infinite_ammo == null)
	{
		sv_infinite_ammo = FindConVar("sv_infinite_ammo");
		sv_infinite_primary_ammo = FindConVar("sv_infinite_primary_ammo");
	}
	
	float weaponSpeed = 1.0;
	int maxClip = CalcPlayerClip(client, weapon);
	int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
	bool isShotgun = (StrContains(classname, "shotgun", false) != -1);
	bool isSniper = (StrContains(classname, "sniper", false) != -1 || StrContains(classname, "hunting", false) != -1);
	if(isShotgun || isSniper || StrContains(classname, "smg", false) != -1 || StrContains(classname, "rifle", false) != -1)
	{
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		bool hasGetAmmo = false;
		bool hasInfAmmo = (sv_infinite_ammo.BoolValue || sv_infinite_primary_ammo.BoolValue);
		
		if((g_clSkill_4[client] & SKL_4_MachStrafe) && StrEqual(classname, "weapon_rifle_m60", false))
		{
			// 机枪无限子弹
			SetEntProp(weapon, Prop_Send, "m_iClip1", 151);
			hasGetAmmo = true;
			hasInfAmmo = true;
			weaponSpeed = 0.8;
		}
		else if(g_iRoundEvent == 2 || g_bIsAngryLastStandActive || g_csHasGodMode[client])
		{
			// 临时无限子弹
			SetEntProp(weapon, Prop_Send, "m_iClip1", 2);
			hasGetAmmo = true;
			hasInfAmmo = true;
			
			// 修复无限子弹导致子弹丢失
			if(clip > 2)
				AddAmmo(client, clip - 2, ammoType, true);
		}
		else if((g_clSkill_5[client] & SKL_5_InfAmmo) && !((isShotgun || isSniper) ? GetRandomInt(0, 2) : GetRandomInt(0, 3)))
		{
			// 自动获得子弹(手枪本来就是无限子弹的)
			// GivePlayerAmmo(client, 1, ammoType, true);
			AddAmmo(client, 1, ammoType, true);
			hasGetAmmo = true;
		}
		else if(((g_clSkill_3[client] & SKL_3_Accurate) && clip == maxClip) ||							// 第一枪一定会暴击
			((g_clSkill_5[client] & SKL_5_Sneak) && g_fNextCalmTime[client] <= GetEngineTime()))		// 潜行攻击
		{
			// 只有非无限子弹才生效
			g_bAccurateShot[client] = true;
			// PrintToChat(client, "weapon_fire");
			
			// 好像不是很必要
			RequestFrame(EndAccurateShot, client);
		}
		else
		{
			// 取消效果
			g_bAccurateShot[client] = false;
		}
		
		if((g_clSkill_4[client] & SKL_4_SniperExtra) &&
			(StrEqual(classname, "weapon_sniper_awp", false) || StrEqual(classname, "weapon_sniper_scout", false)))
		{
			// AWP 射速加快无限子弹
			if(classname[14] == 'a')
			{
				// SetEntProp(weapon, Prop_Send, "m_iClip1", 20);
				// GivePlayerAmmo(client, 1, ammoType, true);
				
				if(!hasGetAmmo)
					AddAmmo(client, 1, ammoType, true);
				
				weaponSpeed = 2.25;
			}
			else if(classname[14] == 's')
			{
				// 鸟狙只加快射速不无限子弹
				weaponSpeed = 2.0;
			}
		}

		if(g_clSkill_4[client] & SKL_4_FastFired)
		{
			// 武器射速加快
			weaponSpeed *= 1.25;
		}

		// 必须要目前没有 高爆/燃烧 子弹时才需要提供升级弹药
		if(GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") <= 0)
		{
			if(g_iRoundEvent == 12 || g_bIsAngryLastStandActive)
			{
				// 临时无限燃烧子弹(1=燃烧.2=高爆.4=激光)
				SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", 1);
				SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 1);
			}
			else
			{
				int rn = GetRandomInt(0, 3);
				int flag = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec", 1) & ~3;
				switch(rn)
				{
					case 1:
					{
						if(g_clSkill_5[client] & SKL_5_FireBullet)
						{
							// 随机燃烧子弹
							SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flag | 1);
							SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 1);
						}
					}
					case 2:
					{
						if(g_clSkill_5[client] & SKL_5_ExpBullet)
						{
							// 随机高爆子弹
							SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flag | 2);
							SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 1);
						}
					}
				}
			}
		}

		if((g_clSkill_5[client] & SKL_5_ClipHold) && !hasInfAmmo && StrContains(classname, "smg", false) > -1)
		{
			clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
			int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
			if(++g_iBulletFired[client] > 25 && ammo > 0 && clip > 1)
			{
				// 将备用弹药移动到弹匣里
				if(g_iExtraAmmo[client] > 0)
					g_iExtraAmmo[client] -= 1;
				else
					SetEntProp(client, Prop_Send, "m_iAmmo", ammo - 1, _, ammoType);
				
				SetEntProp(weapon, Prop_Send, "m_iClip1", clip + 1);
			}
			else if(g_iBulletFired[client] == 25)
				ClientCommand(client, "play \"ui/bigreward.wav\"");
		}
		
		// 消音冲锋枪和其他武器
		if(StrContains(classname, "smg_silenced", false))
			g_fNextCalmTime[client] = GetEngineTime() + 3.0;
		else
			g_fNextCalmTime[client] = GetEngineTime() + 5.0;
	}
	else if(StrContains(classname, "pistol", false) > -1)
	{
		if(g_clSkill_1[client] & SKL_1_MagnumInf)
		{
			// 手枪无限子弹
			if(classname[13] == EOS)
			{
				if(GetEntProp(weapon, Prop_Send, "m_hasDualWeapons"))
				{
					// 双持手枪，特殊处理，以修复只有一侧武器开火动画
					if(GetRandomInt(0, 1))
						SetEntProp(weapon, Prop_Send, "m_iClip1", 31);
					else
						SetEntProp(weapon, Prop_Send, "m_iClip1", 30);
				}
				else
				{
					// 单手枪
					SetEntProp(weapon, Prop_Send, "m_iClip1", 16);
				}
			}
			else
			{
				// 马格南
				SetEntProp(weapon, Prop_Send, "m_iClip1", 7);
			}
		}
		
		// 小手枪和马格南
		if(classname[13] == EOS)
			g_fNextCalmTime[client] = GetEngineTime() + 3.0;
		else
			g_fNextCalmTime[client] = GetEngineTime() + 5.0;
	}
	else if(StrEqual(classname, "weapon_chainsaw", false))
	{
		if(g_clSkill_2[client] & SKL_2_Chainsaw)
		{
			// 电锯无限燃料
			SetEntProp(weapon, Prop_Send, "m_iClip1", 31);
		}
		
		g_fNextCalmTime[client] = GetEngineTime() + 6.0;
	}
	else if((g_clSkill_5[client] & SKL_5_RocketDude) && !(GetEntityFlags(client) & FL_ONGROUND) && StrContains(classname, "grenade_launcher", false) != -1)
	{
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
		if(ammo > 0 && clip >= 0)
		{
			// 将备用弹药移动到弹匣里
			if(g_iExtraAmmo[client] > 0)
				g_iExtraAmmo[client] -= 1;
			else
				SetEntProp(client, Prop_Send, "m_iAmmo", ammo - 1, _, ammoType);
			
			SetEntProp(weapon, Prop_Send, "m_iClip1", clip + 1);
		}
	}
	
	int pbDuration = IsPlayerHaveEffect(client, 21);
	if(pbDuration > 0)
	{
		static ConVar pipe_bomb_timer_duration;
		if(pipe_bomb_timer_duration == null)
			pipe_bomb_timer_duration = FindConVar("pipe_bomb_timer_duration");
		
		int ov = pipe_bomb_timer_duration.IntValue;
		pipe_bomb_timer_duration.IntValue = ov * pbDuration;
		RequestFrame(ResetPipeBombDuration, ov);
	}
	
	// 只对单发有效，三连发无效
	if(weaponSpeed != 1.0)
	{
		// AdjustWeaponSpeed(weapon, weaponSpeed);
		// SetWeaponSpeed(weapon, weaponSpeed);
		SetWeaponSpeed2(weapon, weaponSpeed);
	}
}

public void EndAccurateShot(any client)
{
	g_bAccurateShot[client] = false;
}

public void ResetPipeBombDuration(any data)
{
	static ConVar pipe_bomb_timer_duration;
	if(pipe_bomb_timer_duration == null)
		pipe_bomb_timer_duration = FindConVar("pipe_bomb_timer_duration");
	
	pipe_bomb_timer_duration.IntValue = view_as<int>(data);
}

void HookPlayerReload(int client, int clipSize)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon) || !IsValidEdict(weapon) || clipSize <= 0)
		return;
	
	if(clipSize > g_iMaxClip)
		clipSize = g_iMaxClip;
	
	char className[64];
	GetEntityClassname(weapon, className, 64);
	if(StrContains(className, "smg", false) > -1 || StrContains(className, "rifle", false) > -1 ||
		StrContains(className, "shotgun", false) > -1 || StrContains(className, "sniper", false) > -1 ||
		StrContains(className, "pistol", false) > -1 || StrEqual(className, "weapon_grenade_launcher", false))
	{
		g_iReloadWeaponEntity[client] = EntIndexToEntRef(weapon);
		g_iReloadWeaponClip[client] = clipSize;
		// PrintToChat(client, "武器：%d丨玩家：%d丨弹匣：%d丨原有：%d丨现有：%d", weapon, client, clipSize, g_iReloadWeaponOldClip[client], GetEntProp(weapon, Prop_Send, "m_iClip1"));

		if(g_iReloadWeaponOldClip[client] <= 0)
			g_iReloadWeaponOldClip[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");

		SDKUnhook(client, SDKHook_PreThink, PlayerHook_OnReloadThink);
		SDKUnhook(client, SDKHook_WeaponSwitchPost, PlayerHook_OnReloadStopped);
		SDKUnhook(client, SDKHook_WeaponDropPost, PlayerHook_OnReloadStopped);
		// SDKHook(client, SDKHook_PreThink, PlayerHook_OnReloadThink);
		SDKHook(client, SDKHook_WeaponSwitchPost, PlayerHook_OnReloadStopped);
		SDKHook(client, SDKHook_WeaponDropPost, PlayerHook_OnReloadStopped);
	}
}

public void PlayerHook_OnReloadStopped(int client, int weapon)
{
	SDKUnhook(client, SDKHook_PreThink, PlayerHook_OnReloadThink);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, PlayerHook_OnReloadStopped);
	SDKUnhook(client, SDKHook_WeaponDropPost, PlayerHook_OnReloadStopped);
	g_iReloadWeaponEntity[client] = INVALID_ENT_REFERENCE;
	g_iReloadWeaponClip[client] = 0;
	g_iReloadWeaponOldClip[client] = 0;

	/*
	if(IsValidClient(client))
		PrintToChat(client, "停止换子弹");
	*/
}

public void PlayerHook_OnReloadThink(int client)
{
	if(!IsValidAliveClient(client) || GetClientTeam(client) != 2 || IsSurvivorHeld(client) ||
		GetEntityMoveType(client) == MOVETYPE_LADDER || IsSurvivorThirdPerson(client))
	{
		PlayerHook_OnReloadStopped(client, 0);
		// PrintToChatAll("无效玩家：%d", client);
		return;
	}

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon) || !IsValidEdict(weapon) || EntIndexToEntRef(weapon) != g_iReloadWeaponEntity[client])
	{
		PlayerHook_OnReloadStopped(client, weapon);
		// PrintToChatAll("无效武器：%d丨玩家：%d", weapon, client);
		return;
	}

	char className[64];
	GetEntityClassname(weapon, className, 64);

	/*
	if(StrContains(className, "smg", false) == -1 && StrContains(className, "rifle", false) == -1 &&
		StrContains(className, "shotgun", false) == -1 && StrContains(className, "sniper", false) == -1)
	{
		// 这玩意不是枪械
		PlayerHook_OnReloadStopped(client, weapon);
		PrintToChatAll("不是枪械：%d", weapon);
		return;
	}
	*/

	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
	if(StrContains(className, "shotgun", false) == -1)
	{
		// 非霰弹枪检查剩余弹药
		if(g_iReloadWeaponClip[client] > ammo)
			g_iReloadWeaponClip[client] = ammo;
	}
	else
	{
		// 霰弹枪检查剩余弹药
		if(g_iReloadWeaponClip[client] - g_iReloadWeaponOldClip[client] > ammo)
			g_iReloadWeaponClip[client] = g_iReloadWeaponOldClip[client] + ammo;
	}

	if(g_iReloadWeaponClip[client] <= 0)
	{
		// PrintHintText(client, "不需要或无法换弹匣");
		PlayerHook_OnReloadStopped(client, weapon);
		return;
	}

	if(GetEntProp(weapon, Prop_Send, "m_bInReload"))
	{
		if(StrContains(className, "shotgun", false) > -1)
		{
			if(g_iReloadWeaponOldClip[client] > 0)
			{
				int clipSize = CalcPlayerClip(client, weapon);
				if(g_iReloadWeaponOldClip[client] > clipSize)
					g_iReloadWeaponOldClip[client] = clipSize;
				
				// PrintToChat(client, "当前：%d丨原来：%d", GetEntProp(weapon, Prop_Send, "m_iClip1"), g_iReloadWeaponOldClip[client]);
				
				// 将霰弹枪的弹匣还原，并且取消已经填装的子弹，以开始新的填装
				SetEntProp(weapon, Prop_Send, "m_iClip1", g_iReloadWeaponOldClip[client]);
				// SetEntProp(weapon, Prop_Send, "m_shellsInserted", 0);
				g_iReloadWeaponClip[client] -= g_iReloadWeaponOldClip[client];
				if(g_iReloadWeaponClip[client] > ammo)
					g_iReloadWeaponClip[client] = ammo;
				if(g_iReloadWeaponClip[client] > clipSize)
					g_iReloadWeaponClip[client] = clipSize - g_iReloadWeaponOldClip[client];
				
				// PrintHintText(client, "原有子弹：%d", g_iReloadWeaponOldClip[client]);
				g_iReloadWeaponOldClip[client] = 0;
			}
			
			// BUG 修复
			if(g_iReloadWeaponClip[client] < 1)
				g_iReloadWeaponClip[client] = GetEntProp(weapon, Prop_Send, "m_reloadNumShells");
			
			// 设置霰弹枪需要填装多少子弹
			// 霰弹枪最终弹匣为 现有子弹+需要填装的子弹
			SetEntProp(weapon, Prop_Send, "m_reloadNumShells", g_iReloadWeaponClip[client]);
			// PrintCenterText(client, "%d丨%d", GetEntProp(weapon, Prop_Send, "m_shellsInserted"), GetEntProp(weapon, Prop_Send, "m_reloadNumShells"));
		}
	}
	else
	{
		if(StrContains(className, "shotgun", false) > -1)
		{
			// 霰弹枪填装完毕
			PlayerHook_OnReloadStopped(client, weapon);
			// PrintHintText(client, "填装弹药完成");
			
			// 修复卡壳问题
			float time = GetGameTime() + 0.3;
			if(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") > time)
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time);
			if(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") > time)
				SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time);
			SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", time - 0.3);
		}
		else if(GetEntProp(weapon, Prop_Send, "m_iClip1") > 0 || ammo <= 0)
		{
			// 非霰弹枪换弹匣完成
			ammo += GetEntProp(weapon, Prop_Send, "m_iClip1");
			ammo -= g_iReloadWeaponClip[client];
			
			// 修复溢出子弹消失的问题
			int defaultClip = GetDefaultClip(weapon);
			if(g_iReloadWeaponOldClip[client] > defaultClip)
				ammo += g_iReloadWeaponOldClip[client] - defaultClip;
			
			SetEntProp(weapon, Prop_Send, "m_iClip1", g_iReloadWeaponClip[client]);
			SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammoType);

			PlayerHook_OnReloadStopped(client, weapon);
			// PrintHintText(client, "换弹匣完成");
		}
		
		g_iReloadWeaponOldClip[client] = 0;
	}

	// PrintCenterText(client, "备用：%d丨目标：%d", ammo, g_iReloadWeaponClip[client]);
}

SoH_OnReload (iCid)
{
	if (GetClientTeam(iCid) == TEAM_SURVIVORS)
	{
		new iEntid = GetEntDataEnt2(iCid,g_iActiveWO);
		if (IsValidEntity(iEntid)==false) return;

		decl String:stClass[32];
		GetEntityNetClass(iEntid,stClass,32);

		if (StrContains(stClass,"shotgun",false) == -1)
		{
			SoH_MagStart(iEntid,iCid);
			return;
		}

		else if (StrContains(stClass,"autoshotgun",false) != -1)
		{
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, iCid);
			WritePackCell(hPack, iEntid);

			CreateTimer(0.1,SoH_AutoshotgunStart,hPack);
			return;
		}

		else if (StrContains(stClass,"shotgun_spas",false) != -1)
		{
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, iCid);
			WritePackCell(hPack, iEntid);

			CreateTimer(0.1,SoH_SpasShotgunStart,hPack);
			return;
		}

		else if (StrContains(stClass,"pumpshotgun",false) != -1
			|| StrContains(stClass,"shotgun_chrome",false) != -1)
		{
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, iCid);
			WritePackCell(hPack, iEntid);

			CreateTimer(0.1,SoH_PumpshotgunStart,hPack);
			return;
		}
	}
}

SoH_MagStart (iEntid, iCid)
{
	new Float:flGameTime = GetGameTime();
	new Float:flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
	new Float:flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_flSoH_rate ;

	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/g_flSoH_rate, true);
	CreateTimer( flNextTime_calc, SoH_MagEnd, iEntid);

	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iCid);
	new Float:flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - g_flSoH_rate ) ;
	WritePackFloat(hPack, flStartTime_calc);
	if ( (flNextTime_calc - 0.4) > 0 ) CreateTimer( flNextTime_calc - 0.4 , SoH_MagEnd2, hPack);

	flNextTime_calc += flGameTime;
	SetEntDataFloat(iEntid, g_iTimeIdleO, flNextTime_calc, true);
	SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
	SetEntDataFloat(iCid, g_iNextAttO, flNextTime_calc, true);
}

public Action:SoH_AutoshotgunStart (Handle:timer, Handle:hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
		return Plugin_Stop;

	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new iEntid = ReadPackCell(hPack);
	CloseHandle(hPack);
	hPack = CreateDataPack();
	WritePackCell(hPack, iCid);
	WritePackCell(hPack, iEntid);

	if (iCid <= 0
		|| iEntid <= 0
		|| IsValidEntity(iCid)==false
		|| IsValidEntity(iEntid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	SetEntDataFloat(iEntid,	g_iShotStartDurO,	g_flSoHAutoS*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotInsertDurO,	g_flSoHAutoI*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotEndDurO,		g_flSoHAutoE*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/g_flSoH_rate, true);

	CreateTimer(0.3,SoH_ShotgunEnd,hPack,TIMER_REPEAT);
	return Plugin_Stop;
}

public Action:SoH_SpasShotgunStart (Handle:timer, Handle:hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false) return Plugin_Stop;

	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new iEntid = ReadPackCell(hPack);
	CloseHandle(hPack);
	hPack = CreateDataPack();
	WritePackCell(hPack, iCid);
	WritePackCell(hPack, iEntid);

	if (iCid <= 0
		|| iEntid <= 0
		|| IsValidEntity(iCid)==false
		|| IsValidEntity(iEntid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	SetEntDataFloat(iEntid,	g_iShotStartDurO,	g_flSoHSpasS*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotInsertDurO,	g_flSoHSpasI*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotEndDurO,		g_flSoHSpasE*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/g_flSoH_rate, true);

	CreateTimer(0.3,SoH_ShotgunEnd,hPack,TIMER_REPEAT);
	return Plugin_Stop;
}

public Action:SoH_PumpshotgunStart (Handle:timer, Handle:hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false) return Plugin_Stop;

	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new iEntid = ReadPackCell(hPack);
	CloseHandle(hPack);
	hPack = CreateDataPack();
	WritePackCell(hPack, iCid);
	WritePackCell(hPack, iEntid);

	if (iCid <= 0
		|| iEntid <= 0
		|| IsValidEntity(iCid)==false
		|| IsValidEntity(iEntid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	SetEntDataFloat(iEntid,	g_iShotStartDurO,	g_flSoHPumpS*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotInsertDurO,	g_flSoHPumpI*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid,	g_iShotEndDurO,		g_flSoHPumpE*g_flSoH_rate,	true);
	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/g_flSoH_rate, true);

	CreateTimer(0.3,SoH_ShotgunEnd,hPack,TIMER_REPEAT);
	return Plugin_Stop;
}

public Action:SoH_MagEnd (Handle:timer, any:iEntid)
{
	KillTimer(timer);
	if (IsServerProcessing()==false) return Plugin_Stop;

	if (iEntid <= 0 || IsValidEntity(iEntid)==false) return Plugin_Stop;

	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

	return Plugin_Stop;
}

public Action:SoH_MagEnd2 (Handle:timer, Handle:hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
	{
		CloseHandle(hPack);
		return Plugin_Stop;
	}

	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new Float:flStartTime_calc = ReadPackFloat(hPack);
	CloseHandle(hPack);

	if (iCid <= 0
		|| IsValidEntity(iCid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	new iVMid = GetEntDataEnt2(iCid,g_iViewModelO);
	SetEntDataFloat(iVMid, g_iVMStartTimeO, flStartTime_calc, true);

	return Plugin_Stop;
}

public Action:SoH_ShotgunEnd (Handle:timer, Handle:hPack)
{
	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new iEntid = ReadPackCell(hPack);

	if (IsServerProcessing()==false
		|| iCid <= 0
		|| iEntid <= 0
		|| IsValidEntity(iCid)==false
		|| IsValidEntity(iEntid)==false
		|| IsClientInGame(iCid)==false)
	{
		KillTimer(timer);
		return Plugin_Stop;
	}

	if (GetEntData(iEntid,g_iShotRelStateO)==0 || GetEntProp(iEntid, Prop_Send, "m_bInReload", 1) == 0)
	{
		SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

		new Float:flTime=GetGameTime()+0.2;
		SetEntDataFloat(iCid,	g_iNextAttO,	flTime,	true);
		SetEntDataFloat(iEntid,	g_iTimeIdleO,	flTime,	true);
		SetEntDataFloat(iEntid,	g_iNextPAttO,	flTime,	true);
		SetEntPropFloat(iEntid, Prop_Send, "m_flTimeWeaponIdle", flTime - 0.2);

		KillTimer(timer);
		CloseHandle(hPack);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:SoH_ShotgunEndCock (Handle:timer, any:hPack)
{
	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new iEntid = ReadPackCell(hPack);

	if (IsServerProcessing()==false
		|| iCid <= 0
		|| iEntid <= 0
		|| IsValidEntity(iCid)==false
		|| IsValidEntity(iEntid)==false
		|| IsClientInGame(iCid)==false)
	{
		KillTimer(timer);
		return Plugin_Stop;
	}

	if (GetEntData(iEntid,g_iShotRelStateO)==0 || GetEntProp(iEntid, Prop_Send, "m_bInReload", 1) == 0)
	{
		SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

		new Float:flTime= GetGameTime() + 1.0;
		SetEntDataFloat(iCid,	g_iNextAttO,	flTime,	true);
		SetEntDataFloat(iEntid,	g_iTimeIdleO,	flTime,	true);
		SetEntDataFloat(iEntid,	g_iNextPAttO,	flTime,	true);
		SetEntPropFloat(iEntid, Prop_Send, "m_flTimeWeaponIdle", flTime - 1.0);

		KillTimer(timer);
		CloseHandle(hPack);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void OnSkillAttach(int client, int level, int skill)
{
	if(!g_bIsGamePlaying)
		return;
	
	if(level == 4 && skill == SKL_4_SniperExtra)
		CheatCommand(client, "give", "sniper_awp");
	else if(level == 4 && skill == SKL_4_MachStrafe)
		CheatCommand(client, "give", "rifle_m60");
	else if(level == 5 && skill == SKL_5_RocketDude)
		CheatCommand(client, "give", "grenade_launcher");
	else if(level == 2 && skill == SKL_2_Chainsaw)
		CheatCommand(client, "give", "chainsaw");
	else if(level == 2 && skill == SKL_2_PainPills)
		CheatCommand(client, "give", "pain_pills");
	else if(level == 2 && skill == SKL_2_Defibrillator)
		CheatCommand(client, "give", "defibrillator");
	else if(level == 2 && skill == SKL_2_PipeBomb)
		CheatCommand(client, "give", "pipe_bomb");
	else if(level == 4 && skill == SKL_4_Terror)
		CheatCommand(client, "give", "vomitjar");
	else if(level == 3 && skill == SKL_3_MoreAmmo)
		AddAmmo(client, 999);
	else if(level == 4 && skill == SKL_4_ClipSize)
		AddAmmo(client, 999);
	else if(level == 2 && skill == SKL_2_HealBouns)
		CheatCommand(client, "give", "first_aid_kit");
	else if(level == 1 && skill == SKL_1_NoRecoil)
		CheatCommand(client, "upgrade_add", "LASER_SIGHT");
	else if(level == 1 && skill == SKL_1_Armor)
		AddArmor(client, 100);
}

stock bool AddHealth(int client, int amount, bool limit = true, bool conv = false)
{
	if(!IsValidAliveClient(client))
		return false;
	
	int team = GetClientTeam(client);
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	
	{
		Call_StartForward(g_fwOnGiveHealth);
		Call_PushCell(client);
		
		int refAmount = amount;
		Call_PushCellRef(refAmount);
		
		bool refLimit = limit;
		Call_PushCellRef(refLimit);
		
		bool refConv = conv;
		Call_PushCellRef(refConv);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return false;
		
		if(refResult == Plugin_Changed)
		{
			amount = refAmount;
			limit = refLimit;
			conv = refConv;
		}
	}
	
	if(team == 2 && !GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		float buffer = GetPlayerTempHealth(client) * 1.0;
		buffer += amount;
		
		if(limit)
		{
			if(conv)
			{
				int cv = (health + RoundToZero(buffer)) - maxHealth;
				if(cv > 0)
				{
					if(cv > buffer)
						cv = RoundToZero(buffer);
					
					buffer -= cv;
					health += cv;
				}
			}
			
			if(health + RoundToZero(buffer) > maxHealth)
				buffer = float(maxHealth - health);
			if(health > maxHealth)
				health = maxHealth;
			if(buffer < 0.0)
				buffer = 0.0;
		}

		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	else if(team == 3)
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

stock int GetDefaultAmmo(int weapon, int ammoType = -1)
{
	ConVar cv_rifle, cv_autoshotgun, cv_grenadelauncher, cv_huntingrifle, cv_m60, cv_shotgun, cv_smg, cv_sniper;
	if(cv_rifle == null)
	{
		cv_rifle = FindConVar("ammo_assaultrifle_max");
		cv_autoshotgun = FindConVar("ammo_autoshotgun_max");
		cv_grenadelauncher = FindConVar("ammo_grenadelauncher_max");
		cv_huntingrifle = FindConVar("ammo_huntingrifle_max");
		cv_m60 = FindConVar("ammo_m60_max");
		cv_shotgun = FindConVar("ammo_shotgun_max");
		cv_smg = FindConVar("ammo_smg_max");
		cv_sniper = FindConVar("ammo_sniperrifle_max");
	}
	
	if(ammoType <= -1 && weapon > MaxClients && IsValidEntity(weapon) && HasEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
		ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	
	switch(ammoType)
	{
		case AMMOTYPE_ASSAULTRIFLE:
			return cv_rifle.IntValue;
		case AMMOTYPE_SMG:
			return cv_smg.IntValue;
		case AMMOTYPE_M60:
			return cv_m60.IntValue;
		case AMMOTYPE_SHOTGUN:
			return cv_shotgun.IntValue;
		case AMMOTYPE_AUTOSHOTGUN:
			return cv_autoshotgun.IntValue;
		case AMMOTYPE_HUNTINGRIFLE:
			return cv_huntingrifle.IntValue;
		case AMMOTYPE_SNIPERRIFLE:
			return cv_sniper.IntValue;
		case AMMOTYPE_GRENADELAUNCHER:
			return cv_grenadelauncher.IntValue;
	}
	
	return -1;
}

stock bool AddAmmo(int client, int amount, int ammoType = -1, bool noSound = false, bool limit = true)
{
	if(!IsValidAliveClient(client))
		return false;
	
	int maxAmmo = -1;
	int primary = GetPlayerWeaponSlot(client, 0);
	
	if(ammoType <= -1 && primary > MaxClients && IsValidEntity(primary))
		ammoType = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
	
	if(limit)
	{
		maxAmmo = GetDefaultAmmo(primary, ammoType);
		if(maxAmmo < 0)
			return false;
		
		float scale = 1.0;
		scale += IsPlayerHaveEffect(client, 15) * 0.25;
		
		if(g_clSkill_3[client] & SKL_3_MoreAmmo)
			scale += 1.0;
		
		maxAmmo = RoundToZero(maxAmmo * scale);
	}
	else
	{
		maxAmmo = g_iMaxAmmo;
	}
	
	int clip = 0, maxClip = 0;
	// int secondry = GetPlayerWeaponSlot(client, 1);
	// int grenade = GetPlayerWeaponSlot(client, 2);
	// int kit = GetPlayerWeaponSlot(client, 3);
	// int drug = GetPlayerWeaponSlot(client, 4);
	if(primary > MaxClients && IsValidEntity(primary) &&
		GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = CalcPlayerClip(client, primary);
		if(maxClip > 0)
		{
			// 主武器
			clip = GetEntProp(primary, Prop_Send, "m_iClip1");
			if(clip > -1)
				maxAmmo += maxClip - clip;
		}
	}
	/*
	else if(secondry > MaxClients && IsValidEntity(secondry) &&
		GetEntProp(secondry, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = GetDefaultClip(secondry);
		if(maxClip > 0)
		{
			if(g_clSkill_4[client] & SKL_4_ClipSize)
				maxClip = RoundToNearest(maxClip * 1.5);

			// 副武器
			clip = GetEntProp(secondry, Prop_Send, "m_iClip1");
			if(clip > -1)
				maxAmmo += maxClip - clip;
		}
	}
	else if(grenade > MaxClients && IsValidEntity(grenade) &&
		GetEntProp(grenade, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = GetDefaultClip(grenade);
		if(maxClip > 0)
		{
			// 投掷武器
			clip = GetEntProp(grenade, Prop_Send, "m_iClip1");
			// maxAmmo += maxClip - clip;
		}
	}
	else if(kit > MaxClients && IsValidEntity(kit) &&
		GetEntProp(kit, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = GetDefaultClip(kit);
		if(maxClip > 0)
		{
			// 工具套件
			clip = GetEntProp(kit, Prop_Send, "m_iClip1");
			// maxAmmo += maxClip - clip;
		}
	}
	else if(drug > MaxClients && IsValidEntity(drug) &&
		GetEntProp(drug, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = GetDefaultClip(drug);
		if(maxClip > 0)
		{
			// 药物
			clip = GetEntProp(drug, Prop_Send, "m_iClip1");
			// maxAmmo += maxClip - drug;
		}
	}
	*/
	
	{
		Call_StartForward(g_fwOnGiveAmmo);
		Call_PushCell(client);
		
		int refAmount = amount;
		Call_PushCellRef(refAmount);
		
		bool refLimit = limit;
		Call_PushCellRef(refLimit);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return false;
		
		if(refResult == Plugin_Changed)
		{
			amount = refAmount;
			limit = refLimit;
		}
	}
	
	// 实际可用上限，来自于游戏限制
	int available = maxAmmo + maxClip;
	if(available > g_iMaxAmmo)
	{
		// g_iExtraAmmo[client] = maxAmmo + maxClip - g_iMaxAmmo;
		// maxAmmo = g_iMaxAmmo - clip;
		available = g_iMaxAmmo - clip;	// 满弹匣时无法填装的，所以这里或许可以+1
	}
	else
	{
		g_iExtraAmmo[client] = 0;
		// maxAmmo += maxClip - clip;
	}
	
	int oldAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
	int newAmmo = oldAmmo + g_iExtraAmmo[client] + amount;
	if(newAmmo < 0)
		newAmmo = 0;
	
	// 理论上限
	if(limit && maxAmmo > 0 && newAmmo > maxAmmo)
		newAmmo = maxAmmo;
	
	// 实际上限(由于引擎限制)
	if(available > 0 && newAmmo > available)
	{
		g_iExtraAmmo[client] = newAmmo - available;
		newAmmo = available;
	}
	
	SetEntProp(client, Prop_Send, "m_iAmmo", newAmmo, _, ammoType);
	if(!noSound && amount != 0 && newAmmo > oldAmmo)
	{
		// 在弹药增加的情况下才是需要播放声音
		ClientCommand(client, "play \"items/itempickup.wav\"");
	}
	
	// PrintToChat(client, "ammo +%d, ov %d, nv %d, cl %d, ex %d, lim %d, ava %d, mc %d", amount, oldAmmo, newAmmo, clip, g_iExtraAmmo[client], maxAmmo, available, maxClip);
	return (oldAmmo != newAmmo);
}

stock bool AddArmor(int client, int amount, bool helmet = true)
{
	if(!IsValidAliveClient(client))
		return false;
	
	{
		Call_StartForward(g_fwOnGiveArmor);
		Call_PushCell(client);
		
		int refAmount = amount;
		Call_PushCellRef(refAmount);
		
		bool refHelmet = helmet;
		Call_PushCellRef(refHelmet);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return false;
		
		if(refResult == Plugin_Changed)
		{
			amount = refAmount;
			helmet = refHelmet;
		}
	}
	
	int count = g_iExtraArmor[client] + GetEntProp(client, Prop_Send, "m_ArmorValue") + amount;
	
	if(count > 127)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", 127);
		g_iExtraArmor[client] = count - 127;
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", count);
		g_iExtraArmor[client] = 0;
	}
	
	// 没头盔时加上，已经有就不要去掉
	bool haveHelmet = !!GetEntProp(client, Prop_Send, "m_bHasHelmet");
	if(!haveHelmet && helmet)
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
	
	return true;
}

stock bool IsSurvivorThirdPerson(int iClient)
{
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime())
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true;
	switch(GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction"))
	{
		case 1:
		{
			static iTarget;
			iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");

			if(iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner"))
				return true;
			else if(iTarget != iClient)
				return true;
		}
		case 4, 6, 7, 8, 9, 10:
		return true;
	}

	static String:sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 626, 625, 624, 623, 622, 621, 661, 662, 664, 665, 666, 667, 668, 670, 671, 672, 673, 674, 620, 680, 616:
				return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625, 616:
				return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 656, 622, 623, 624, 625, 626, 663, 662, 661, 660, 659, 658, 657, 654, 653, 652, 651, 621, 620, 669, 615:
				return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 625, 675, 626, 627, 628, 629, 630, 631, 678, 677, 676, 575, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 684, 621:
				return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 528, 759, 763, 764, 529, 530, 531, 532, 533, 534, 753, 676, 675, 761, 758, 757, 756, 755, 754, 527, 772, 762, 522:
				return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 537, 819, 823, 824, 538, 539, 540, 541, 542, 543, 813, 828, 825, 822, 821, 820, 818, 817, 816, 815, 814, 536, 809, 572:
				return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 532, 533, 534, 535, 536, 537, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 531, 530, 775, 525:
				return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 529, 530, 531, 532, 533, 534, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 527, 772, 528, 522:
				return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625:
				return true;
			}
		}
	}

	return false;
}

stock bool IsInfectedThirdPerson(int iClient)
{
	if(GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime())
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true;

	switch(GetEntProp(iClient, Prop_Send, "m_zombieClass"))
	{
		case 1://smoker
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 30, 31, 32, 36, 37, 38, 39:
				return true;
			}
		}
		case 2://boomer
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 30, 31, 32, 33:
				return true;
			}
		}
		case 3://hunter
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 38, 39, 40, 41, 42, 43, 45, 46, 47, 48, 49:
				return true;
			}
		}
		case 4://spitter
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 17, 18, 19, 20:
				return true;
			}
		}
		case 5://jockey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 8 , 15, 16, 17, 18:
				return true;
			}
		}
		case 6://charger
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 5, 27, 28, 29, 31, 32, 33, 34, 35, 39, 40, 41, 42:
				return true;
			}
		}
		case 8://tank
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 28, 29, 30, 31, 49, 50, 51, 73, 74, 75, 76 ,77:
				return true;
			}
		}
	}

	return false;
}

stock int FindUseEntity(int client, float radius = 0.0)
{
	if(g_pfnFindUseEntity == null)
		return -1;
	
	static ConVar cvUseRadius;
	if(cvUseRadius == null)
		cvUseRadius = FindConVar("player_use_radius");
	
	return SDKCall(g_pfnFindUseEntity, client, (radius > 0.0 ? radius : cvUseRadius.FloatValue), 0.0, 0.0, 0, false);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon,
	int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	// 冻结时禁止任何操作
	if(g_fFreezeTime[client] > GetEngineTime())
		return Plugin_Handled;
	
	// 用于检查玩家状态
	int useTarget = -1;
	int flags = GetEntityFlags(client);
	bool isGrabbed = IsSurvivorHeld(client);
	
	if(GetClientTeam(client) == 2 && !IsSurvivorHeld(client))
	{
		if((buttons & IN_USE) && !isGrabbed)
		{
			useTarget = GetClientAimTarget(client, false);
			if(useTarget <= MaxClients || !IsValidEntity(useTarget) || !IsValidEdict(useTarget))
				useTarget = FindUseEntity(client);
		}
		
		if ((g_clSkill_4[client] & SKL_4_DuckShover) && g_bCanGunShover[client] && !isGrabbed &&
			(flags & FL_DUCKING) && (buttons & IN_ATTACK2) && (buttons & IN_DUCK))
		{
			g_bCanGunShover[client] = false;
			new Float:pos[3];
			// GetClientAbsOrigin(client, pos);
			GetClientEyePosition(client, pos);

			// EmitSoundToAll(SOUND_BCLAW, client);
			EmitAmbientSound(SOUND_BCLAW, pos, client);
			float radius = 500.0 * (1 + IsPlayerHaveEffect(client, 32));

			for (new i = 1; i <= MaxClients; i++)
			{
				if(!IsValidAliveClient(i) || GetClientTeam(i) != 3)
					continue;

				decl Float:vec[3], Float:dir[3];
				GetClientAbsOrigin(i, vec);
				if(GetVectorDistance(vec, pos) > radius)
					continue;
				
				SubtractVectors(vec, pos, dir);
				
				Charge(i, client, 750.0);
				SDKHooks_TakeDamage(i, 0, client, float(GetRandomInt(1, 50)), DMG_AIRBOAT, weapon, dir, pos);
			}
			
			if(IsPlayerHaveEffect(client, 30))
			{
				int numEdict = GetMaxEntities();
				for(int i = MaxClients + 1; i < numEdict; ++i)
				{
					if(!IsValidEdict(i) || !IsValidEntity(i))
						continue;
					
					// 只要普感，不要 Witch
					if(!HasEntProp(i, Prop_Send, "m_bIsBurning") || HasEntProp(i, Prop_Send, "m_rage"))
						continue;
					
					decl Float:vec[3], Float:dir[3];
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec);
					if(GetVectorDistance(vec, pos) > radius)
						continue;
					
					SubtractVectors(vec, pos, dir);
					SDKHooks_TakeDamage(i, 0, client, float(GetRandomInt(1, 30)), DMG_AIRBOAT, weapon, dir, pos);
				}
			}
			
			CreateTimer(15.0, Timer_GunShovedReset, client, TIMER_FLAG_NO_MAPCHANGE);
			
			if(g_pCvarAllow.BoolValue)
			{
				new newcolor1[4];
				newcolor1[0] = GetRandomInt(0,255);
				newcolor1[1] = GetRandomInt(0,255);
				newcolor1[2] = GetRandomInt(0,255);
				newcolor1[3] = 225;
				pos[2] += 10;
				
				//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度(20.0),播放振幅, 颜色, 播放速度(10), 标识(0))
				TE_SetupBeamRingPoint(pos, 2.0, radius, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 12.0, 1.0, newcolor1, 0, 0);
				TE_SendToAll();
			}
		}

		int weaponId = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(IsValidEntity(weaponId))
		{
			static char classname[64];
			GetEntityClassname(weaponId, classname, 64);
			int clip = GetEntProp(weaponId, Prop_Send, "m_iClip1");
			bool isReloading = view_as<bool>(GetEntProp(weaponId, Prop_Send, "m_bInReload"));

			if((buttons & IN_ATTACK) && (g_clSkill_1[client] & SKL_1_RapidFire) && !isReloading &&
				GetEntityMoveType(client) != MOVETYPE_LADDER &&
				!GetEntProp(client, Prop_Send, "m_usingMountedGun") &&
				!GetEntProp(client, Prop_Send, "m_usingMountedWeapon") &&
				!(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ATTACK2) &&
				GetEntPropFloat(weaponId, Prop_Send, "m_flCycle") <= 0.0 &&
				!GetEntProp(weaponId, Prop_Send, "m_bInReload")
			)
			{
				/*
				if((StrContains(classname, "shotgun", false) != -1 || StrContains(classname, "pistol", false) != -1 ||
					StrContains(classname, "sniper", false) != -1 || StrEqual(classname, "weapon_hunting_rifle", false) ||
					StrEqual(classname, "weapon_grenade_launcher", false)) &&
					(GetEntPropFloat(weaponId, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime() || clip <= 0))
				{
					// 单发武器无法开枪时取消开枪
					// 应该(也许)不会触发spam检测吧
					buttons &= ~IN_ATTACK;
				}
				*/
				
				SetEntProp(weaponId, Prop_Send, "m_isHoldingFireButton", 0);
				ChangeEdictState(weaponId, FindDataMapInfo(weaponId, "m_isHoldingFireButton"));
				
				/*
				if(StrContains(classname, "pistol_magnum", false) != -1)
				{
					SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.2);
					ChangeEdictState(iWeapon, FindDataMapInfo(iWeapon, "m_flNextPrimaryAttack"));
				}
				else if(StrContains(classname, "pistol", false) != -1)
				{
					SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.4);
					ChangeEdictState(iWeapon, FindDataMapInfo(iWeapon, "m_flNextPrimaryAttack"));
				}
				*/
			}

			if(!(buttons & IN_ATTACK) || clip <= 0 || GetEntProp(weaponId, Prop_Send, "m_bInReload") ||
				GetEntityMoveType(client) == MOVETYPE_LADDER || StrContains(classname, "smg", false) == -1 ||
				IsSurvivorThirdPerson(client))
			{
				if(g_iBulletFired[client] != 0)
				{
					g_iBulletFired[client] = 0;
					// PrintToLeft(client, "连续开枪停止");
				}
			}
			
			if((g_iRoundEvent == 2 || g_bIsAngryLastStandActive || g_csHasGodMode[client]) && (buttons & IN_RELOAD) &&
				(StrContains(classname, "shotgun", false) != -1 || StrContains(classname, "smg", false) != -1 ||
				StrContains(classname, "rifle", false) != -1 || StrContains(classname, "sniper", false) != -1))
			{
				// 临时无限子弹时防止填装
				buttons &= ~IN_RELOAD;
			}
			
			if((g_clSkill_1[client] & SKL_1_KeepClip) && !isReloading && (buttons & IN_RELOAD) && StrContains(classname, "shotgun", false) == -1)
			{
				g_iReloadWeaponKeepClip[client] = clip;
				// PrintToChat(client, "pre clip size:%d", clip);
			}
			
			int defaultClip = GetDefaultClip(weaponId);
			if((g_clSkill_4[client] & SKL_4_ClipSize) && !isReloading && (buttons & IN_RELOAD) &&
				defaultClip > 0 && clip >= defaultClip)
			{
				int maxClip = CalcPlayerClip(client, weaponId);
				int ammoType = GetEntProp(weaponId, Prop_Send, "m_iPrimaryAmmoType");
				int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
				if(clip < maxClip && ammo > 0)
				{
					if(StrContains(classname, "shotgun", false) != -1)
					{
						if(g_iReloadWeaponOldClip[client] <= 0)
						{
							g_iReloadWeaponOldClip[client] = clip;

							// SetEntProp(weaponId, Prop_Send, "m_iClip1", (clip >= defaultClip ? defaultClip - 1 : clip));

							// 这样会更好，不会出现改了子弹却没触发填装动作
							SetEntProp(weaponId, Prop_Send, "m_iClip1", 0);
						}
					}
					else
					{
						SetEntProp(weaponId, Prop_Send, "m_iClip1", 0);
						
						if(ammo + clip > g_iMaxAmmo)
						{
							// AddAmmo 有限制的，应该不会触发的吧
							SetEntProp(client, Prop_Send, "m_iAmmo", g_iMaxAmmo, _, ammoType);
							g_iExtraAmmo[client] += ammo + clip - g_iMaxAmmo;
						}
						else
						{
							SetEntProp(client, Prop_Send, "m_iAmmo", ammo + clip, _, ammoType);
						}
						
						g_iReloadWeaponOldClip[client] = 0;
					}

					// HookPlayerReload(client, RoundToNearest(defaultClip * 1.5));
				}
				else
				{
					// 修复非霰弹枪弹匣过大可以强制重新装填的 bug
					// 会和其他修改弹匣大小的插件冲突
					buttons &= ~IN_RELOAD;
				}
			}
			
			if((g_clSkill_4[client] & SKL_4_Shove) && (buttons & IN_ATTACK2) && !(buttons & IN_FORWARD) &&
				GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) &&
				GetEntPropFloat(client, Prop_Send, "m_flNextShoveTime") <= GetGameTime())
			{
				ForceSwingStart(weaponId);
				
				int penalty = GetEntProp(client, Prop_Send, "m_iShovePenalty");
				
				if(g_fIncapShovePenalty > 0)
				{
					if( penalty > 0 )
					{
						int last = RoundToFloor(GetGameTime() - g_fIncapShoveTimeout[client]);
						if( last > 1 )
						{
							penalty -= last;
							if( penalty < 0 )
								penalty = 0;
						}
					}
					
					SetEntProp(client, Prop_Send, "m_iShovePenalty", penalty + 1);
					g_fIncapShoveTimeout[client] = GetGameTime();
				}
				
				SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", GetGameTime() + g_hCvarShovTime.FloatValue + (penalty * g_fIncapShovePenalty));
				
				DoShoveSimulation(client, weaponId);
			}
			
			if((g_clSkill_1[client] & SKL_1_ShoveFatigue) && (buttons & IN_ATTACK2))
			{
				SetEntProp(client, Prop_Send, "m_iShovePenalty", 0);
			}
			
			if((g_clSkill_1[client] & SKL_1_KeepClip) && isReloading && (buttons & IN_ATTACK) && !(buttons & (IN_ATTACK2|IN_RELOAD)) &&
				clip > 0 && StrContains(classname, "shotgun", false) == -1)
			{
				float time = GetGameTime();
				SetEntProp(weaponId, Prop_Send, "m_bInReload", 0);
				SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time);
				SetEntPropFloat(weaponId, Prop_Send, "m_flNextPrimaryAttack", time);
				PlayerHook_OnReloadStopped(client, weaponId);
			}
		}
		
		weaponId = GetPlayerWeaponSlot(client, 0);
		if(((g_clSkill_3[client] & SKL_3_MoreAmmo) || (g_clSkill_4[client] & SKL_4_ClipSize)) && (buttons & IN_USE) &&
			weaponId > MaxClients && IsValidEntity(weaponId) &&
			useTarget > MaxClients && IsValidEntity(useTarget) && IsValidEdict(useTarget))
		{
			static char className[64], weaponName[64];
			GetEntityClassname(useTarget, className, 64);
			GetEntityClassname(weaponId, weaponName, 64);
			
			float origin[3], position[3];
			GetClientEyePosition(client, origin);
			GetEntPropVector(useTarget, Prop_Send, "m_vecOrigin", position);
			
			static ConVar cv_usedst;
			if(cv_usedst == null)
				cv_usedst = FindConVar("player_use_radius");
			
			if(GetVectorDistance(origin, position, false) <= cv_usedst.FloatValue)
			{
				bool isAmmo = (StrEqual(className, "weapon_ammo_spawn", false) || StrEqual(className, "weapon_ammo_pack", false));	// 弹药堆
				bool isSpawnner = (StrContains(className, weaponName, false) == 0 && StrContains(className, "_spawn", false) > 0);	// weapon_*_spawn
				
				if(isAmmo || isSpawnner)
				{
					DataPack data = CreateDataPack();
					data.WriteCell(client);
					data.WriteString(weaponName);
					data.WriteCell(isSpawnner);
					
					// FIXME: 处理基于 weaponId 的 weapon_spawn 实体
					// AddAmmo(client, 999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
					RequestFrame(UpdateWeaponAmmo, data);
				}
				else if(StrEqual(className, "upgrade_ammo_explosive", false) || StrEqual(className, "upgrade_ammo_incendiary", false))
				{
					g_iLastWeaponAmmo[client] = GetEntProp(weaponId, Prop_Send, "m_iClip1") +
						GetEntProp(client, Prop_Send, "m_iAmmo", _, GetEntProp(weaponId, Prop_Send, "m_iPrimaryAmmoType"));
				}
			}
		}
		
		if((g_clSkill_1[client] & SKL_1_KeepClip) && (buttons & IN_USE) &&
			weaponId > MaxClients && IsValidEntity(weaponId) &&
			useTarget > MaxClients && IsValidEntity(useTarget) && IsValidEdict(useTarget))
		{
			static char className[64];
			GetEntityClassname(useTarget, className, 64);
			
			float origin[3], position[3];
			GetClientEyePosition(client, origin);
			GetEntPropVector(useTarget, Prop_Send, "m_vecOrigin", position);
			
			static ConVar cv_usedst;
			if(cv_usedst == null)
				cv_usedst = FindConVar("player_use_radius");
			
			if(GetVectorDistance(origin, position, false) <= cv_usedst.FloatValue &&
				(StrEqual(className, "upgrade_ammo_explosive", false) || StrEqual(className, "upgrade_ammo_incendiary", false)))
			{
				g_iReloadWeaponUpgrade[client] = GetEntProp(weaponId, Prop_Send, "m_upgradeBitVec");
				g_iReloadWeaponUpgradeClip[client] = GetEntProp(weaponId, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			}
		}
		
		if((g_clSkill_2[client] & SKL_2_LadderGun))
		{
			MoveType mtAmbulatoryStyle = GetEntityMoveType(client);
			if (mtAmbulatoryStyle == MOVETYPE_FLY)
			{
				if (mtLastMoveType[client] != MOVETYPE_LADDER)
				{
					// return Plugin_Continue;
				}
				else if (IsMoving(client) || (buttons & IN_JUMP))
				{
					SetEntityMoveType(client, MOVETYPE_LADDER);
				}
			}
			else if (mtAmbulatoryStyle == MOVETYPE_LADDER)
			{
				if(!IsMoving(client))
				{
					if (mtLastMoveType[client] == MOVETYPE_FLY)
					{
						// return Plugin_Continue;
					}
					else
					{
						SetEntityMoveType(client, MOVETYPE_FLY);
						mtLastMoveType[client] = mtAmbulatoryStyle;	
					}
				}
			}
		}
		
		if(!(g_clSkill_2[client] & SKL_2_IncapCrawling) && !g_bIsPluginCrawling && g_hCvarIncapCrawling.BoolValue && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
		{
			// 禁止自带的倒地爬行
			buttons &= ~IN_FORWARD;
		}
	}
	else if(g_bIsHitByVomit[client])
	{
		// 强制特感攻击
		int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if(zClass >= ZC_SMOKER && zClass <= ZC_TANK)
		{
			if(zClass == ZC_TANK)
				buttons |= IN_ATTACK;
			else
				buttons |= IN_ATTACK2;
		}
	}

	if(!(flags & FL_ONGROUND) && (buttons & IN_USE) && (g_clSkill_3[client] & SKL_3_Parachute))
	{
		float velocity[3];
		// GetEntPropVector(client, Prop_Send, "m_vecVelocity[0]", velocity);
		GetEntDataVector(client, g_iVelocityO, velocity);

		if(velocity[2] < -25.0)
			velocity[2] = -100.0;

		// 降落，减少掉落速度
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
	}

	if((g_iJumpFlags[client] & JF_HasJumping) && !(buttons & IN_JUMP))
	{
		if(!(g_iJumpFlags[client] & JF_FirstReleased))
		{
			// 在空中放开了跳跃键
			g_iJumpFlags[client] |= JF_FirstReleased;
			g_iJumpFlags[client] |= JF_CanDoubleJump;

			if(g_clSkill_2[client] & SKL_2_DoubleJump)
			{
				// 现在进行双重跳，不要进行连跳
				g_iJumpFlags[client] &= ~JF_CanBunnyHop;
			}

			// PrintCenterText(client, "放开跳跃键");
		}
	}

	if((g_clSkill_2[client] & SKL_2_DoubleJump) && !isGrabbed && (g_iJumpFlags[client] & JF_CanDoubleJump) && (buttons & IN_JUMP))
	{
		g_iJumpFlags[client] &= ~JF_CanDoubleJump;
		g_iJumpFlags[client] |= JF_CanBunnyHop;

		float velocity[3];
		// GetEntPropVector(client, Prop_Send, "m_vecVelocity[0]", velocity);
		GetEntDataVector(client, g_iVelocityO, velocity);
		
		float upVel = CaclJumpVelocity(client);
		if(velocity[2] < upVel)
			velocity[2] = upVel;
		
		if(g_fMaxGravityModify[client] > 0.0)
			velocity[2] *= g_fMaxGravityModify[client];
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		// CreateTimer(1.0, Timer_DoubleJumpReset, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
		/*
		Event event = CreateEvent("player_jump");
		event.SetInt("userid", GetClientUserId(client));
		event.Fire();
		*/
		
		// PrintCenterText(client, "双重跳 %d", !!(g_iJumpFlags[client] & JF_CanBunnyHop));
	}

	if((g_clSkill_3[client] & SKL_3_BunnyHop) && !isGrabbed && (g_iJumpFlags[client] & JF_CanBunnyHop) &&
		(buttons & IN_JUMP) && !(g_iJumpFlags[client] & JF_HasFirstJump))
	{
		// 连跳，空中取消按键
		/*
		if(!(flags & FL_ONGROUND) && GetEntityMoveType(client) != MOVETYPE_LADDER && !(buttons & IN_DUCK) &&
			GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
			buttons &= ~IN_JUMP;
		*/

		// 检查是否允许连跳，被水淹没无法跳跃
		if(GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1 ||
			(buttons & (IN_SPEED|IN_USE|IN_SCORE)))
		{
			// 在某些时候不可以进行连跳
			g_iJumpFlags[client] &= ~JF_CanBunnyHop;
			// PrintCenterText(client, "连跳取消");
		}
		// else if(flags & FL_ONGROUND)
		else if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1)
		{
			float velocity[3];
			GetEntDataVector(client, g_iVelocityO, velocity);

			// 提供一个向上的速度
			velocity[2] = CaclJumpVelocity(client);
			if(g_fMaxGravityModify[client] > 0.0)
				velocity[2] *= g_fMaxGravityModify[client];
			
			// 因为引擎的问题，必须要把 m_hGroundEntity 设置为 -1 才能在地面上设置向上速度
			// 否则会被摩擦力阻止小于 300.0 的向上速度，即使玩家是完全静止的
			SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
			
			/*
			Event event = CreateEvent("player_jump");
			event.SetInt("userid", GetClientUserId(client));
			event.Fire();
			*/

			// g_iJumpFlags[client] = JF_HasJumping;
			// PrintCenterText(client, "连跳 (%.2f %.2f %.2f -> %.2f)", velocity[0], velocity[1], velocity[2], GetVectorLength(velocity));
		}
	}

	if(!(buttons & IN_JUMP) && g_iJumpFlags[client] != JF_None &&
		GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1)
	{
		// 取消任何标记
		g_iJumpFlags[client] = JF_None;
	}
	
	if((flags & FL_ONGROUND) && g_bOnRocketDude[client] && vel[2] == 0.0)
	{
		// 已经成功落地
		g_bOnRocketDude[client] = false;
	}
	
	if(GetVectorLength(vel) > 9.0 && !(buttons & IN_SPEED))
		g_fNextCalmTime[client] += GetEngineTime() + 1.0;
	
	return Plugin_Changed;
}

bool:IsMoving(client)
{
	decl Float:fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	return (GetVectorLength(fVelocity) > 0.0);
}

public Action Timer_GunShovedReset(Handle timer, any client)
{
	if(1 <= client <= MaxClients)
		g_bCanGunShover[client] = true;

	return Plugin_Continue;
}

stock void ForceSwingStart(int weapon)
{
	if(g_pfnOnSwingStart != null)
		SDKCall(g_pfnOnSwingStart, weapon, weapon);
}

stock void ForceDropVictim(int client, int target, int stagger = 3)
{
	static ConVar z_charge_interval;
	if(z_charge_interval == null)
		z_charge_interval = FindConVar("z_charge_interval");
	
	if(g_pfnOnPummelEnded != null)
		SDKCall(g_pfnOnPummelEnded, client, "", target);
	if(g_pfnOnCarryEnded != null)
		SDKCall(g_pfnOnCarryEnded, client, 1, 0, 0);
	
	SetEntPropEnt(client, Prop_Send, "m_carryVictim", -1);
	SetEntPropEnt(target, Prop_Send, "m_carryAttacker", -1);
	
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if( ability != -1 )
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + z_charge_interval.FloatValue);
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if( weapon != -1 )
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.6);
	
	float vPos[3];
	vPos[0] = GetEntProp(target, Prop_Send, "m_isIncapacitated") == 1 ? 20.0 : 50.0;
	SetVariantString("!activator");
	AcceptEntityInput(target, "SetParent", client);
	TeleportEntity(target, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(target, "ClearParent");
	
	CreateTimer(0.3, Timer_FixAnim, GetClientUserId(target));
	
	if( stagger & (1<<0) )
	{
		// L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(client), GetClientUserId(target));
		L4D_StaggerPlayer(client, target, NULL_VECTOR);
	}
	
	if( stagger & (1<<1) )
	{
		// L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(target), GetClientUserId(client));
		L4D_StaggerPlayer(target, client, NULL_VECTOR);
	}
}

public Action Timer_FixAnim(Handle t, any target)
{
	target = GetClientOfUserId(target);
	if( target && IsPlayerAlive(target) )
	{
		int seq = GetEntProp(target, Prop_Send, "m_nSequence");
		if( seq == 650 || seq == 665 || seq == 661 || seq == 651 || seq == 554 || seq == 551 ) // Coach, Ellis, Nick, Rochelle, Francis/Zoey, Bill/Louis
		{
			float vPos[3];
			GetClientAbsOrigin(target, vPos);
			SetEntityMoveType(target, MOVETYPE_WALK);
			TeleportEntity(target, vPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}
	}
}

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

stock void DoShoveSimulation(int client, int weapon = 0)
{
	g_iIncapShoveIgnore[0] = client;
	
	float vPos[3], vAng[3], vLoc[3], vDir[3];
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);
	
	vAng[1] += (g_fIncapShoveDegree / 2);
	vAng[0] = 0.0; // Point horizontal
	// vAng[0] = -15.0; // Point up
	// vPos[2] -= 5;
	vPos[2] += 15;
	
	char sTemp[32];
	Handle trace;
	int target;
	float range = g_hCvarShovRange.FloatValue;
	bool hit = false;
	
	if( weapon > MaxClients && (g_clSkill_5[client] & SKL_5_ShoveRange) )
	{
		GetEntityClassname(weapon, sTemp, sizeof(sTemp));
		if(StrEqual(sTemp, "weapon_melee", false))
			GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof(sTemp));
		
		if( g_tShoveRange != null )
			g_tShoveRange.GetValue(sTemp, range);
	}
	
	for( int i = 1; i <= g_iIncapShoveNumTrace; i++ )
	{
		g_iIncapShoveIgnore[i] = 0;
		
		vAng[1] -= (g_fIncapShoveDegree / (g_iIncapShoveNumTrace + 1));
		trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if( !TR_DidHit(trace) )
		{
			delete trace;
			continue;
		}
		
		target = TR_GetEntityIndex(trace);
		TR_GetEndPosition(vLoc, trace);
		delete trace;
		
		if( target <= 0 || IsValidEntity(target) == false )
			continue;
		
		for( int x = 0; x < i; x++ )
			if( g_iIncapShoveIgnore[x] == target )
				target = 0;
		
		if( target <= 0 )
			continue;
		
		g_iIncapShoveIgnore[i] = target;
		SubtractVectors(vLoc, vPos, vDir);
		
		if( target <= MaxClients )
		{
			int zClass = GetEntProp(target, Prop_Send, "m_zombieClass");
			if( IsClientInGame(target) && IsPlayerAlive(target) && zClass != ZC_SURVIVOR )
			{
				// GetClientEyePosition(target, vLoc);
				if( GetVectorDistance(vPos, vLoc) <= range )
				{
					// L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(target), GetClientUserId(client));
					SDKHooks_TakeDamage(target, (weapon ? weapon : client), client, 25.0, DMG_AIRBOAT, weapon, vDir, vLoc);
					L4D_StaggerPlayer(target, client, vPos);
					
					// 停止冲锋
					if(IsChargerCharging(target))
					{
						TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
						
						if(g_pfnEndCharge != null)
							SDKCall(g_pfnEndCharge, GetEntPropEnt(target, Prop_Send, "m_customAbility"));
					}
					
					// 声音
					EmitSoundToClient(client, g_sndShoveInfected[GetRandomInt(0, sizeof(g_sndShoveInfected)-1)], target,
						SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vLoc);
					
					// 事件
					Event event = CreateEvent("player_shoved");
					event.SetInt("userid", GetClientUserId(target));
					event.SetInt("attacker", GetClientUserId(client));
					event.Fire();
					
					hit = true;
				}
			}
		}
		else
		{
			GetEdictClassname(target, sTemp, sizeof(sTemp));
			if( StrEqual(sTemp, "infected", false) || (StrEqual(sTemp, "witch", false) && GetEntPropFloat(target, Prop_Send, "m_rage") >= 1.0) )
			{
				// GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vLoc);
				if( GetVectorDistance(vPos, vLoc) <= range )
					SDKHooks_TakeDamage(target, (weapon ? weapon : client), client, 25.0, DMG_AIRBOAT, weapon, vDir, vLoc);
				
				// 声音
				EmitSoundToClient(client, g_sndShoveInfected[GetRandomInt(0, sizeof(g_sndShoveInfected)-1)], target,
					SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vLoc);
				
				// 事件
				Event event = CreateEvent("entity_shoved");
				event.SetInt("entityid", target);
				event.SetInt("attacker", GetClientUserId(client));
				event.Fire();
				
				hit = true;
			}
		}
	}
	
	if(!hit)
	{
		// 声音
		EmitSoundToClient(client, g_sndShoveMiss[GetRandomInt(0, sizeof(g_sndShoveMiss)-1)], client,
			SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vPos);
	}
}

stock bool IsChargerCharging(int client)
{
	if( GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_CHARGER )
	{
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility"); // ability_charge
		if( ability > 0 && IsValidEdict(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") )
		{
			return true;
		}
	}
	
	return false;
}

public MRESReturn TestMeleeSwingCollisionPre(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	if( IsValidEntity(pThis) )
	{
		int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
		if( IsValidAliveClient(owner) && (g_clSkill_5[owner] & SKL_5_MeleeRange) )
		{
			static char sTemp[16];
			GetEntPropString(pThis, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof(sTemp));
			
			int range = 0;
			if(g_tMeleeRange == null || !g_tMeleeRange.GetValue(sTemp, range))
				range = g_iUnknownMeleeRange;
			
			if(range > g_hCvarMeleeRange.IntValue)
			{
				g_iOldMeleeSwingRange = g_hCvarMeleeRange.IntValue;
				g_hCvarMeleeRange.IntValue = range;
			}
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn TestMeleeSwingCollisionPost(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	if( g_iOldMeleeSwingRange > 0 && g_iOldMeleeSwingRange < g_hCvarMeleeRange.IntValue )
	{
		g_hCvarMeleeRange.IntValue = g_iOldMeleeSwingRange;
		g_iOldMeleeSwingRange = 0;
	}
	
	return MRES_Ignored;
}

public MRESReturn TestSwingCollisionPre(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	if( IsValidEntity(pThis) )
	{
		int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
		if( IsValidAliveClient(owner) )
		{
			if(g_clSkill_5[owner] & SKL_5_ShoveRange)
			{
				static char sTemp[32];
				GetEntityClassname(pThis, sTemp, 32);
				if(StrEqual(sTemp, "weapon_melee", false))
					GetEntPropString(pThis, Prop_Data, "m_strMapSetScriptName", sTemp, 32);
				
				int range = 0;
				if(g_tShoveRange == null || !g_tShoveRange.GetValue(sTemp, range))
					range = g_iUnknownShoveRange;
				
				if(range > g_hCvarShovRange.IntValue)
				{
					g_iOldShoveSwingRange = g_hCvarShovRange.IntValue;
					g_hCvarShovRange.IntValue = range;
				}
			}
			
			if(g_clSkill_4[owner] & SKL_4_Shove)
			{
				g_iOldShoveCharger = g_hCvarChargerShove.IntValue;
				g_hCvarChargerShove.BoolValue = true;
			}
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn TestSwingCollisionPost(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	if( g_iOldShoveSwingRange > 0 && g_iOldShoveSwingRange < g_hCvarShovRange.IntValue )
	{
		g_hCvarShovRange.IntValue = g_iOldShoveSwingRange;
		g_iOldShoveSwingRange = 0;
	}
	
	if(g_iOldShoveCharger > -1)
	{
		g_hCvarChargerShove.IntValue = g_iOldShoveCharger;
		g_iOldShoveCharger = -1;
	}
	
	return MRES_Ignored;
}

/*
public MRESReturn IsInvulnerablePre(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	return MRES_Ignored;
}

public MRESReturn IsInvulnerablePost(int pThis, Handle hReturn)
{
	if(!g_bIsGamePlaying)
		return MRES_Ignored;
	
	bool invul = DHookGetReturn(hReturn);
	if(IsValidClient(pThis))
		g_bIsInvulnerable[pThis] = invul;
	
	return MRES_Ignored;
}
*/

/*
public Action Timer_DoubleJumpReset(Handle timer, any client)
{
	if(!IsValidAliveClient(client) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		if(1 <= client <= MaxClients)
			g_bCanDoubleJump[client] = false;

		return Plugin_Stop;
	}

	if((GetEntityFlags(client) & FL_ONGROUND) || GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > 0)
	{
		g_bCanDoubleJump[client] = false;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}
*/

public Action L4D2_OnStagger(int target, int source)
{
	if(!g_bIsGamePlaying)
		return Plugin_Continue;
	
	if(!IsValidAliveClient(target))
		return Plugin_Continue;
	
	if(IsPlayerHaveEffect(target, 22))
		return Plugin_Handled;
	
	int team = GetClientTeam(target);
	// 生还者失衡
	if(team == 2)
	{
		if(g_bIsHitByVomit[target])
		{
			// 胆汁效果紫色
			CreateGlowModel(target, 0xFF80FF);
		}
		else if(GetEntProp(target, Prop_Send, "m_isHangingFromLedge", 1) || GetEntProp(target, Prop_Send, "m_isHangingFromLedge", 1))
		{
			// 倒地/挂边 黄色
			CreateGlowModel(target, 0x80FFFF);
		}
		else if(GetEntProp(target, Prop_Send, "m_bIsOnThirdStrike", 1))
		{
			// 黑白状态 白色
			CreateGlowModel(target, 0xFFFFFF);
		}
		else
		{
			// 没有情况
			RemoveGlowModel(target);
		}
		
		int attacker = GetCurrentAttacker(target);
		if(IsValidAliveClient(attacker))
		{
			if(g_bIsHitByVomit[attacker])
			{
				// 胆汁效果紫色
				CreateGlowModel(attacker, 0xFF80FF);
			}
			else
			{
				// 没有情况
				RemoveGlowModel(attacker);
			}
		}
	}
	// 感染者失衡
	else if(team == 3)
	{
		if(g_bIsHitByVomit[target])
		{
			// 胆汁效果紫色
			CreateGlowModel(target, 0xFF80FF);
		}
		else
		{
			// 没有情况
			RemoveGlowModel(target);
		}
		
		int victim = GetCurrentVictim(target);
		if(IsValidAliveClient(victim))
		{
			if(g_bIsHitByVomit[victim])
			{
				// 胆汁效果紫色
				CreateGlowModel(victim, 0xFF80FF);
			}
			else if(GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1) || GetEntProp(victim, Prop_Send, "m_isHangingFromLedge", 1))
			{
				// 倒地/挂边 黄色
				CreateGlowModel(victim, 0x80FFFF);
			}
			else if(GetEntProp(victim, Prop_Send, "m_bIsOnThirdStrike", 1))
			{
				// 黑白状态 白色
				CreateGlowModel(victim, 0xFFFFFF);
			}
			else
			{
				// 没有情况
				RemoveGlowModel(victim);
			}
		}
	}
	
	return Plugin_Continue;
}

public OnClientPostAdminCheck(client)
{
	CreateTimer(5.0, AutoMenuOpen, client);
}

public Action:AutoMenuOpen(Handle:timer, any:client)
{
	if(!GetConVarInt(g_Cvarautomenu))
		return;

	if(!client) return;
	if(!IsClientInGame(client)) return;
	if(!IsClientConnected(client)) return;
	if(!IsPlayerAlive(client) || g_clSkillPoint[client] <= 0) return;
	if(IsFakeClient(client)) return;
	if(GetClientTeam(client) == TEAM_SURVIVORS) StatusChooseMenuFunc(client);
	CreateHideMotd(client);
}

stock bool:AttachParticle(ent, String:particleType[], Float:time=10.0)
{
	if (ent < 1) return false;

	new particle = CreateEntityByName("info_particle_system");

	if (IsValidEdict(particle))
	{
		decl String:tName[32];
		new Float:pos[3];

		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		pos[2] += 60;

		Format(tName, sizeof(tName), "target%i", ent);
		DispatchKeyValue(ent, "targetname", tName);

		DispatchKeyValue(particle, "targetname", "l4d2_dlc2_levelup_particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		if (DispatchSpawn(particle))
		{
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
			SetVariantString(tName);
			AcceptEntityInput(particle, "SetParent", particle, particle, 0);

			/*
			SetVariantString("OnUser1 !self,Start,,0.0,-1");
			AcceptEntityInput(particle, "AddOutput");
			SetVariantString("OnUser2 !self,Stop,,4.0,-1");
			AcceptEntityInput(particle, "AddOutput");
			ActivateEntity(particle);
			AcceptEntityInput(particle, "FireUser1");
			AcceptEntityInput(particle, "FireUser2");
			*/

			// SetVariantString("OnUser2 !self:Stop::4:-1");
			// AcceptEntityInput(particle, "AddOutput", ent, particle);
			SetVariantString("OnUser3 !self:FireUser2::4:-1");
			AcceptEntityInput(particle, "AddOutput", ent, particle);
			SetVariantString("OnUser4 !self:Start::0.1:1");
			AcceptEntityInput(particle, "AddOutput", ent, particle);
			AcceptEntityInput(particle, "FireUser3", ent, particle);
			HookSingleEntityOutput(particle, "OnUser2", ParticleHook_OnThink);

			AcceptEntityInput(particle, "Start", ent, particle);
			SetVariantString(tr("OnUser1 !self:Kill::%.2f:1", time));
			AcceptEntityInput(particle, "AddOutput", ent, particle);
			AcceptEntityInput(particle, "FireUser1", ent, particle);

			/*
			new Handle:pack;
			CreateDataTimer(time, DeleteParticle, pack);
			WritePackCell(pack, particle);
			WritePackString(pack, particleType);
			WritePackCell(pack, ent);

			new Handle:packLoop;
			hTimerLoopEffect[ent] = CreateDataTimer(4.2, LoopParticleEffect, packLoop, TIMER_REPEAT);
			WritePackCell(packLoop, particle);
			WritePackCell(packLoop, ent);
			*/

			return true;
		}
		else
		{
			if (IsValidEdict(particle)) RemoveEdict(particle);
			return false;
		}
	}
	return false;
}

public void ParticleHook_OnThink(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidEntity(caller) || !IsValidEntity(activator))
		return;

	// 停止当前的效果
	AcceptEntityInput(caller, "Stop", activator, caller);

	// 在 0.1 秒后启动效果
	AcceptEntityInput(caller, "FireUser4", activator, caller);

	// 在 4 秒后重新运行当前函数
	AcceptEntityInput(caller, "FireUser3", activator, caller);
}

public Action:DeleteParticle(Handle:timer, Handle:pack)
{
	decl String:particleType[32];

	ResetPack(pack);
	new particle = ReadPackCell(pack);
	ReadPackString(pack, particleType, sizeof(particleType));
	new client = ReadPackCell(pack);

	if (hTimerLoopEffect[client] != INVALID_HANDLE)
	{
		KillTimer(hTimerLoopEffect[client]);
		hTimerLoopEffect[client] = INVALID_HANDLE;
	}

	if (IsValidEntity(particle))
	{
		decl String:classname[128];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}

	if (StrEqual(particleType, "achieved", true))
	{
		hTimerAchieved[client] = INVALID_HANDLE;
	}
	else if (StrEqual(particleType, "mini_fireworks", true))
	{
		hTimerMiniFireworks[client] = INVALID_HANDLE;
	}
}

public Action:LoopParticleEffect(Handle:timer, Handle:pack)
{

	ResetPack(pack);
	new particle = ReadPackCell(pack);
	new client = ReadPackCell(pack);

	if (IsValidEntity(particle))
	{
		decl String:classname[128];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "FireUser1");
			AcceptEntityInput(particle, "FireUser2");
			return Plugin_Continue;
		}
	}
	hTimerLoopEffect[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

stock bool CheatCommand(int client = 0, const char[] command, const char[] arguments = "", any ...)
{
	char fmt[1024];
	VFormat(fmt, 1024, arguments, 4);

	int cmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, cmdFlags & ~FCVAR_CHEAT);

	if(IsValidClient(client))
	{
		int adminFlags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		FakeClientCommand(client, "%s \"%s\"", command, fmt);
		SetUserFlagBits(client, adminFlags);
	}
	else
	{
		ServerCommand("%s \"%s\"", command, fmt);
	}

	SetCommandFlags(command, cmdFlags);

	return true;
}

stock bool CheatCommandEx(int client = 0, const char[] command, const char[] arguments = "", any ...)
{
	char fmt[1024];
	VFormat(fmt, 1024, arguments, 4);

	int cmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, cmdFlags & ~FCVAR_CHEAT);

	if(IsValidClient(client))
	{
		int adminFlags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		// FakeClientCommand(client, "%s %s", command, fmt);
		ClientCommand(client, "%s %s", command, fmt);
		SetUserFlagBits(client, adminFlags);
	}
	else
	{
		ServerCommand("%s %s", command, fmt);
	}

	SetCommandFlags(command, cmdFlags);

	return true;
}

stock void L4D2_RunScript(char[] sCode, any ...)
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

stock void SetWeaponSpeed(int weapon, float speed)
{
	if(g_iWeaponSpeedTotal > MAXPLAYERS)
		return;

	g_iWeaponSpeedEntity[g_iWeaponSpeedTotal] = EntIndexToEntRef(weapon);
	g_fWeaponSpeedUpdate[g_iWeaponSpeedTotal] = speed;
	++g_iWeaponSpeedTotal;
}

stock void SetWeaponSpeed2(int weapon, float speed)
{
	DataPack data = CreateDataPack();
	data.WriteCell(weapon);
	data.WriteFloat(speed);

	RequestFrame(AttachWeaponSpeed, data);
}

stock void AdjustWeaponSpeed(int weapon, float speed)
{
	if(weapon <= MaxClients || !IsValidEntity(weapon) || !IsValidEdict(weapon)/* ||
		!IsValidAliveClient(GetEntProp(weapon, Prop_Send, "m_hOwnerEntity"))*/)
		return;
	
	char classname[64];
	GetEdictClassname(weapon, classname, 64);
	if(StrContains(classname, "weapon_", false) != 0 || GetEntProp(weapon, Prop_Send, "m_bInReload")/* ||
		GetEntPropFloat(weapon, Prop_Send, "m_flCycle") != 0.0*/ || GetEntProp(weapon, Prop_Send, "m_iClip1") <= 0)
		return;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", speed);
	float time = GetGameTime();
	
	float delay = (GetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle") - time) / speed;
	if(delay >= 0.0)
		SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", time + delay);
	
	delay = (GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") - time) / speed;
	if(delay >= 0.0)
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time + delay);
	
	/*
	// 这个不需要
	delay = (GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack") - time) / speed;
	if(delay >= 0.0)
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", time + delay);
	*/
	
	if(delay >= 0.0)
		CreateTimer(delay, Timer_ResetWeaponSpeed, weapon, TIMER_FLAG_NO_MAPCHANGE);
}

public void AttachWeaponSpeed(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int weapon = pack.ReadCell();
	float speed = pack.ReadFloat();
	delete pack;

	AdjustWeaponSpeed(weapon, speed);
}

stock L4D2_Fling(target, Float:vector[3], attacker, Float:incaptime = 3.0)
{
	/*
	new Handle:MySDKCall = INVALID_HANDLE;
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);

	StartPrepSDKCall(SDKCall_Player);
	new bool:bFlingFuncLoaded = PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	if(!bFlingFuncLoaded) LogError("无法下载扇飞插件文件");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

	MySDKCall = EndPrepSDKCall();
	if(MySDKCall == INVALID_HANDLE) LogError("无法启用扇飞功能");

	SDKCall(MySDKCall, target, vector, 76, attacker, incaptime);
	*/

	// Charge(target, 0);
	L4D2_CTerrorPlayer_Fling(target, attacker, vector);
}

stock bool:IsPlayerSpawnGhost(client)
{
	if (GetEntData(client, propinfoghost, 1)) return true;
	return false;
}

stock bool:IsPlayerIncapped(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}

public Action:ResetMeleeDelay(Handle:timer, any:client)
{
	MeleeDelay[client] = false;
}

public Action:StopShake(Handle:timer, any:target)
{
	if (!target || !IsClientInGame(target)) return;

	new Handle:hBf = StartMessageOne("Shake", target);
	BfWriteByte(hBf, 0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	EndMessage();
}

stock bool:IsVisibleTo(Float:position[3], Float:targetposition[3])
{
	decl Float:vAngles[3], Float:vLookAt[3];

	MakeVectorFromPoints(position, targetposition, vLookAt);
	GetVectorAngles(vLookAt, vAngles);

	new Handle:trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, _TraceFilter);

	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace);

		if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true;
		}
	}
	else
	{
		LogError("Tracer Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);

	return isVisible;
}

public bool:_TraceFilter(entity, contentsMask)
{
	if (!entity || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
}

stock int CreateGlowModel(int client, int color)
{
	int entity = CreateEntityByName("prop_dynamic_ornament");
	if(entity <= MaxClients)
		return -1;
	
	static char model[64];
	GetClientModel(client, model, sizeof(model));
	// GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
	
	SetEntityModel(entity, model);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 4500);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_hOwnerEntity", client);
	
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	AcceptEntityInput(entity, "StartGlowing");
	
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(entity, 0, 0, 0, 0);
	
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetAttached", client);
	AcceptEntityInput(entity, "TurnOn");
	
	SDKHook(entity, SDKHook_SetTransmit, GlowHook_SetTransmit);
	
	if(g_iGlowModel[client] != INVALID_ENT_REFERENCE && IsValidEntity(g_iGlowModel[client]))
		RemoveEntity(g_iGlowModel[client]);
	
	g_iGlowModel[client] = EntIndexToEntRef(entity);
	g_iGlowOwner[entity] = client;
	return entity;
}

void RemoveGlowModel(int client)
{
	if(g_iGlowModel[client] != INVALID_ENT_REFERENCE && IsValidEntity(g_iGlowModel[client]))
		RemoveEntity(g_iGlowModel[client]);
	
	g_iGlowModel[client] = INVALID_ENT_REFERENCE;
}

public Action GlowHook_SetTransmit(int entity, int client)
{
	int owner = g_iGlowOwner[entity];
	if(client == owner)
		return Plugin_Handled;
	
	/*
	if(IsValidAliveClient(owner) && (GetCurrentAttacker(owner) == client || GetCurrentVictim(owner) == client))
		return Plugin_Handled;
	*/
	
	if(g_clSkill_4[client] & SKL_4_Terror)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:Event_RP(Handle:timer, any:client)
{
	if(g_bHasRPActive && IsValidAliveClient(client) && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		TriggerRP(client);
	}
	else
	{
		g_bHasRPActive = false;
		PrintToChatAll("\x03[\x05RP\x03]%N\x04人品十分有问题,没有事情发生.", client);
		ClientCommand(client, "play \"ambient/animal/crow_2.wav\"");
	}
}

void TriggerRP(int client, int RandomRP = -1, bool force = false)
{
	if((g_bHasRPActive || force) && IsValidAliveClient(client) && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		g_bHasRPActive = false;
		
		if(RandomRP == -1)
			RandomRP = GetRandomInt(0, 59);
		
		{
			Call_StartForward(g_fwOnLottery);
			Call_PushCell(client);
			
			int refReward = RandomRP;
			Call_PushCellRef(refReward);
			
			Action refResult = Plugin_Continue;
			if(Call_Finish(refResult) != SP_ERROR_NONE)
				refResult = Plugin_Continue;
			
			if(refResult >= Plugin_Handled)
				return;
			
			if(refResult == Plugin_Changed)
				RandomRP = refReward;
		}
		
		switch(RandomRP)
		{
			case 0:
			{
				EmitSoundToAll(SOUND_BAD,client);
				/*
				CheatCommand(client, "z_spawn_old", "hunter auto");
				CheatCommand(client, "z_spawn_old", "boomer auto");
				CheatCommand(client, "z_spawn_old", "jockey auto");
				CheatCommand(client, "z_spawn_old", "smoker auto");
				CheatCommand(client, "z_spawn_old", "charger auto");
				CheatCommand(client, "z_spawn_old", "spitter auto");
				*/
				
				SpawnCommand(client, ZC_BOOMER);
				SpawnCommand(client, ZC_CHARGER);
				SpawnCommand(client, ZC_HUNTER);
				SpawnCommand(client, ZC_JOCKEY);
				SpawnCommand(client, ZC_SMOKER);
				SpawnCommand(client, ZC_SPITTER);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04由于人品极差,召唤了一大堆小BOSS到他身边.", client);
			}
			case 1:
			{
				EmitSoundToAll(SOUND_BAD,client);
				PanicEvent();
				PrintToChatAll("\x03[\x05RP\x03]%N\x04丑的无法形容,一大堆小SS特来强势围观,于是尸潮来了.", client);
			}
			case 2:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
					{
						new ent = GetPlayerWeaponSlot(i, 1);
						if(ent != -1) RemovePlayerItem(i, ent);
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04搞恶作剧变走了所有生还者的手枪和近战.", client);
			}
			case 3:
			{
				EmitSoundToAll(SOUND_BAD,client);
				/*
				CheatCommand(client, "z_spawn_old", "witch auto");
				CheatCommand(client, "z_spawn_old", "witch auto");
				CheatCommand(client, "z_spawn_old", "witch auto");
				CheatCommand(client, "z_spawn_old", "witch auto");
				*/
				
				SpawnCommand(client, ZC_WITCH);
				SpawnCommand(client, ZC_WITCH);
				SpawnCommand(client, ZC_WITCH);
				SpawnCommand(client, ZC_WITCH);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04招了一群美女出来准备围观GHS.", client);
			}
			case 4:
			{
				EmitSoundToAll(SOUND_BAD,client);
				// ServerCommand("sm_freeze \"%N\" \"30\"",client);
				FreezePlayer(client, 30.0);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04为了拯救世界和平决定冰封自我30秒闭关修炼.", client);
			}
			case 5:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarGodMode, "1");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发事件:\x03【无敌人类】\x04所有生还者无敌40秒!", client);
				CreateTimer(40.0, TankEventEnd1, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 6:
			{
				EmitSoundToAll(SOUND_BAD,client);
				SetConVarString(g_hCvarGravity, "3000");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品败坏,触发事件:\x03【超强重力】\x04令生还者无法跳跃30秒!", client);
				CreateTimer(30.0, TankEventEnd2, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 7:
			{
				EmitSoundToAll(SOUND_BAD,client);
				SetConVarString(g_hCvarLimpHealth, "1000");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品败坏,触发事件:\x03【减速诅咒】\x04令所有生还者速度变慢30秒!", client);
				CreateTimer(30.0, TankEventEnd3, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 8:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarInfinite, "1");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发事件:\x03【无限子弹】\x04所有生还者子弹无限40秒!", client);
				CreateTimer(40.0, TankEventEnd4, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 9:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarGravity, "200");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发事件:\x03【重力解除】\x04令生还者自由飞翔30秒!", client);
				CreateTimer(30.0, TankEventEnd2, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 10:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarMeleeRange, "2000");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发事件:\x03【剑气技能】\x04生还者近战攻击范围超远40秒!", client);
				CreateTimer(40.0, TankEventEnd5, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 11:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						CheatCommand(i, "give", "gascan");
						CheatCommand(i, "give", "oxygentank");
						CheatCommand(i, "give", "propanetank");
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,OP赠每人人手一套煮饭工具!", client);
			}
			case 12:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarDuckSpeed, "300");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发事件:\x03【蹲坑神速】\x04生还者蹲下速度加快40秒!", client);
				CreateTimer(40.0, TankEventEnd7, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 13:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetConVarString(g_hCvarReviveTime, "2");
				SetConVarString(g_hCvarMedicalTime, "2");
				PrintToChatAll("\x03[\x05RP\x03 %N\x04人品大爆发,触发双重事件:\x03【疾速救援】\x04减少救人时间40秒!", client);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,触发双重事件:\x03【疾速医疗】\x04减少打包时间40秒!", client);
				CreateTimer(40.0, TankEventEnd8, 0, TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(40.0, TankEventEnd9, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 14:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						CheatCommand(i, "give", "adrenaline");
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				SetConVarString(g_hCvarAdrenTime, "30");
				CreateTimer(40.0, TankEventEndx1, 0, TIMER_FLAG_NO_MAPCHANGE);
				PrintToChatAll("\x03[\x05RP\x03 %N\x04人品大爆发,触发事件:\x03【极度兴奋】\x0440秒内打上肾上腺激素可以兴奋30秒!", client);
			}
			case 15:
			{
				EmitSoundToAll(SOUND_BAD,client);
				g_csSlapCount[client] = 30;
				CreateTimer(0.1, CommandSlapPlayer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04作业没写完就跑去网吧玩求生之路,被老爹狠打屁股30下.", client);
			}
			case 16:
			{
				int team = GetClientTeam(client);
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
					{
						// ServerCommand("sm_freeze \"%N\" \"15\"",i);
						FreezePlayer(i, 15.0);
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品败坏,把队友全部冻结15秒.", client);
			}
			case 17:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_4[client] |= SKL_4_MoreDmgExtra;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04学会了\x03残忍-暴击时追加伤害上限+200\x04天赋.", client);
			}
			case 18:
			{
				EmitSoundToAll(SOUND_BAD,client);
				g_csSlapCount[client] += 300;
				CreateTimer(0.1, CommandSlapTank, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04决定游行太空,记得打开你的降落伞以免落地过猛!", client);
			}
			case 19:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				SetEntityRenderColor(client, 65, 125, 125, 255);

				CheatCommand(client, "give", "health");
				SetEntProp(client,Prop_Send,"m_iHealth", 1000);
				SetEntPropFloat(client,Prop_Send,"m_healthBuffer", 0.0);
				PerformGlow(client, 3, 4713783, GetRandomInt(-32767,32767) * 128);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04成功练成了葵花宝典,生命值上升为1000.", client);
				PrintHintText(client, "你被强化了，快上");
			}
			case 20:
			{
				EmitSoundToAll(SOUND_BAD,client);
				// ServerCommand("sm_timebomb \"%N\"",client);
				
				float position[3];
				GetClientAbsOrigin(client, position);
				CreateExplosion(client, 1000.0, position, 512.0);
				ForcePlayerSuicide(client);
				
				PrintToChatAll("\x03[\x05RP\x03]%N\x04昨晚初恋表白被拒绝,觉得生无可恋,决定引爆自身的炸弹.", client);
			}
			case 21:
			{
				EmitSoundToAll(SOUND_BAD,client);
				/*
				CheatCommand(client, "z_spawn_old", "boomer auto");
				CheatCommand(client, "z_spawn_old", "boomer auto");
				CheatCommand(client, "z_spawn_old", "boomer auto");
				CheatCommand(client, "z_spawn_old", "boomer auto");
				*/
				
				SpawnCommand(client, ZC_BOOMER);
				SpawnCommand(client, ZC_BOOMER);
				SpawnCommand(client, ZC_BOOMER);
				SpawnCommand(client, ZC_BOOMER);
				
				CheatCommand(client, "script", "GetPlayerFromUserID(%d).HitWithVomit()", GetClientUserId(client));
				L4D2_RunScript("GetPlayerFromUserID(%d).HitWithVomit()", GetClientUserId(client));
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品败坏,OP特赠BOOMER胆汁一口.", client);
			}
			case 22:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				GiveSkillPoint(client, 3);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,额外获得硬币\x033\x04枚!", client);
			}
			case 23:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				CheatCommand(client, "give", "first_aid_kit");
				CheatCommand(client, "give", "first_aid_kit");
				CheatCommand(client, "give", "first_aid_kit");
				CheatCommand(client, "give", "first_aid_kit");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04慷慨解囊,掏出偷偷塞在菊花里的四个医疗包给队友.", client);
			}
			case 24:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						GiveSkillPoint(client, 1);
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,所有玩家获得硬币一枚!输入\x03!lv\x04查看!", client);
			}
			case 25:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
					{
						CheatCommand(i, "give", "health");
						SetEntPropFloat(i, Prop_Send, "m_healthBuffer", 0.0);
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品大爆发,为所有玩家治疗了伤口.", client);
			}
			case 26:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_INFECTED)
					{
						// ServerCommand("sm_timebomb \"%N\"",i);
						SDKHooks_TakeDamage(i, 0, client, 3000.0, DMG_NERVEGAS);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04成为天神,把BOSS全部送去轮回,大家致敬!", client);
			}
			case 27:
			{
				EmitSoundToAll(SOUND_BAD,client);
				// CheatCommand(client, "z_spawn_old", "tank auto");
				SpawnCommand(client, ZC_TANK);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04闲着无聊,把自家的宠物坦克牵了出来玩玩.", client);
			}
			case 28:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_INFECTED)
					{
						// ServerCommand("sm_freeze \"%N\" \"30\"",i);
						FreezePlayer(i, 30.0);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04重出江湖,用寒冰掌把所有BOSS打定于空中30秒", client);
			}
			case 29:
			{
				EmitSoundToAll(SOUND_BAD,client);
				
				/*
				CheatCommand(client, "z_spawn_old", "hunter auto");
				CheatCommand(client, "z_spawn_old", "hunter auto");
				CheatCommand(client, "z_spawn_old", "hunter auto");
				CheatCommand(client, "z_spawn_old", "hunter auto");
				*/
				
				SpawnCommand(client, ZC_HUNTER);
				SpawnCommand(client, ZC_HUNTER);
				SpawnCommand(client, ZC_HUNTER);
				SpawnCommand(client, ZC_HUNTER);
				PrintToChatAll("\x03[\x05RP\x03] %N\x04召唤了一队职业灭团Hunter.", client);
			}
			case 30:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						g_clAngryPoint[client] /= 2;
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04弘扬起大爱精神,所有玩家怒气值减半...", client);
			}
			case 31:
			{
				EmitSoundToAll(SOUND_GOOD,client);
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_INFECTED)
					{
						g_csSlapCount[i] += 100;
						CreateTimer(0.2, CommandSlapTank, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04仰天大笑:不要迷恋哥,哥只是传说.接着所有感染者被拍上外太空了", client);
			}
			case 32:
			{
				EmitSoundToAll(SOUND_BAD,client);
				new color[3];
				CreateColorSmoke(client, 1500, 30, 30, color, 24.0);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04放了一个大屁,全世界都灰暗了.", client);
			}
			case 33:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_3[client] |= SKL_3_Sacrifice;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03牺牲-死亡时1/3几率与僵尸同归于尽\x04.", client);
			}
			case 34:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					EmitSoundToClient(i,g_soundLevel,client);
					if(IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS) g_clSkill_3[client] |= SKL_3_IncapFire;
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04发动魔法卡:\x03技能获取\x04,全队获得天赋\x03纵火-倒地点燃周围普感\x04.", client);
			}
			case 35:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					EmitSoundToClient(i,g_soundLevel,client);
					if(IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS) g_clSkill_3[client] |= SKL_3_ReviveBonus;
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04发动魔法卡:\x03技能获取\x04,全队获得天赋\x03妙手-帮助队友时随机获得物品或硬币\x04.", client);
			}
			case 36:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					EmitSoundToClient(i,g_soundLevel,client);
					if(IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS) g_clSkill_3[client] |= SKL_3_Freeze;
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04发动魔法卡:\x03技能获取\x04,全队获得天赋\x03释冰-倒地冻结周围特感\x04.", client);
			}
			case 37:
			{
				EmitSoundToAll(g_soundLevel, client);
				g_clSkill_4[client] |= SKL_4_ClawHeal;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03坚韧-被坦克击中随机恢复HP\x04.", client);
			}
			case 38:
			{
				EmitSoundToAll(g_soundLevel, client);
				GiveAngryPoint(client, 40);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04捡起了一坛好酒猛喝,\x03怒气值+40\x04.", client);
			}
			case 39:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					EmitSoundToClient(i,SOUND_GOOD,client);
					if(IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						// CheatCommand(i, "give", "ammo");
						AddAmmo(i, 999);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04为所有生还者\x03补充弹药\x04,大家感谢他!", client);
			}
			case 40:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_4[client] |= SKL_4_FastFired;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03疾射-武器攻击速度提升\x04.", client);
			}
			case 41:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_4[client] |= SKL_4_SniperExtra;
				CheatCommand(client, "give", "weapon_sniper_awp");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03神狙-无限疾速AWP子弹\x04.", client);
			}
			case 42:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_4[client] |= SKL_4_FastReload;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03嗜弹-武器上弹速度提升\x04.", client);
			}
			case 43:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_4[client] |= SKL_4_DuckShover;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03霸气-蹲加右击推开附近特感\x04.", client);
			}
			case 44:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_3[client] |= SKL_3_Respawn;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03永生-死亡时有几率复活\x04.", client);
			}
			case 45:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_3[client] |= SKL_3_Kickback;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03轰炸-暴击时有几率附加击退效果\x04.", client);
			}
			case 46:
			{
				EmitSoundToAll(g_soundLevel,client);
				g_clSkill_2[client] |= SKL_2_Excited;
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成果,获得天赋\x03热血-爆头杀死特感有几率兴奋\x04.", client);
			}
			case 47:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i) || i == client) continue;
					EmitSoundToClient(i,SOUND_BAD);
				}
				
				int level = GetRandomInt(1, 5);
				switch(level)
				{
					case 1:
						g_clSkill_1[client] = 0;
					case 2:
						g_clSkill_2[client] = 0;
					case 3:
						g_clSkill_3[client] = 0;
					case 4:
						g_clSkill_4[client] = 0;
					case 5:
						g_clSkill_5[client] = 0;
				}
				
				ClientCommand(client, "play \"ambient/animal/crow_1.wav\"");
				
				RegPlayerHook(client, false);
				// ClientSaveToFileSave(client, false);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修仙走火入魔,丧失掉所有\x03%d级\x04天赋技能,大家一起默哀三分钟...", client, level);
			}
			case 48:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					EmitSoundToClient(i,SOUND_GOOD);
				}
				SetEntityRenderColor(client, 255, 255, 255, 0);
				PerformGlow(client, 3, 4713783, GetRandomInt(-32767,32767) * 128);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04变成了幽灵战士,随机获得一件装备.", client);
				if(g_clSkillPoint[client] < 0)
				{
					GiveSkillPoint(client, 2);
					PrintToChat(client, "\x03[提示]\x01 由于你的硬币是负数，获得装备改成了获得硬币。");
				}
				else
				{
					new j = GiveEquipment(client);
					if(!j)
						PrintToChat(client, "\x01[装备]你的装备栏已满,无法再获得装备.");
					else
					{
						static char key[16];
						IntToString(j, key, sizeof(key));
						static EquipData_t data;
						if(g_mEquipData[client].GetArray(key, data, sizeof(data)) && data.valid)
							PrintToChat(client, "\x03[提示]\x01 装备获得：\x05%s\x01 输入 !lv 查看", FormatEquip(client, data));
					}
				}
			}
			case 49:
			{
				EmitSoundToAll(SOUND_BAD,client);
				GiveSkillPoint(client, -3);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04的阴阳怪气激怒了OP,OP扣除他硬币3枚.", client);
			}
			case 50:
			{
				EmitSoundToAll(SOUND_BAD,client);
				// CheatCommand(client, "z_spawn_old", "tank auto");
				SpawnCommand(client, ZC_TANK);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04画个圈圈召唤出了坦克.", client);
			}
			case 51:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						EmitSoundToClient(i,SOUND_BAD,client);
						GiveSkillPoint(client, -1);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04人品超级败坏,所有玩家硬币被扣除一枚...", client);
			}
			case 52:
			{
				EmitSoundToAll(SOUND_BAD,client);
				/*
				CheatCommand(client, "z_spawn_old", "spitter auto");
				CheatCommand(client, "z_spawn_old", "spitter auto");
				CheatCommand(client, "z_spawn_old", "spitter auto");
				CheatCommand(client, "z_spawn_old", "spitter auto");
				*/
				SpawnCommand(client, ZC_SPITTER);
				SpawnCommand(client, ZC_SPITTER);
				SpawnCommand(client, ZC_SPITTER);
				SpawnCommand(client, ZC_SPITTER);
				PrintToChatAll("\x03[\x05RP\x03]%N\x04画个圈圈发现有好多口水妈.", client);
			}
			case 53:
			{
				EmitSoundToAll(SOUND_BAD,client);
				if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
				{
					// CheatCommand(client, "give", "health");
					L4D2_RunScript("script", "GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
				}
				SetEntProp(client,Prop_Send,"m_iHealth", 1);
				SetEntPropFloat(client,Prop_Send,"m_healthBuffer", 0.0);
				SetEntPropFloat(client,Prop_Send,"m_healthBufferTime", GetGameTime());
				PrintToChatAll("\x03[\x05RP\x03]%N\x04修炼成圣女贞德受荆棘之苦血量变成1.", client);
			}
			case 54:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						g_csSlapCount[i] += 30;
						CreateTimer(0.5, CommandSlapPlayer, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04突然提出意见:不如跳只集体舞吧?所有生还者集体跳起了舞.", client);
			}
			case 55:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						new ent = GetPlayerWeaponSlot(i, 0);
						if(ent != -1) RemovePlayerItem(i, ent);
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04对僵尸做了一个鄙视的手势,于是OP没收了所有生还者的主武器.", client);
			}
			case 56:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						new Float:vec[3];
						GetClientAbsOrigin(client, vec);
						vec[1] += GetRandomFloat(0.1,0.9);
						vec[2] += GetRandomFloat(0.1,0.9);
						TeleportEntity(i, vec, NULL_VECTOR, NULL_VECTOR);
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04把所有队友都叫到他身边开会了.", client);
			}
			case 57:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_INFECTED)
					{
						new Float:vec[3];
						GetClientAbsOrigin(client, vec);
						vec[1] += GetRandomFloat(0.1,0.9);
						vec[2] += GetRandomFloat(0.1,0.9);
						TeleportEntity(i, vec, NULL_VECTOR, NULL_VECTOR);
						EmitSoundToClient(i,SOUND_BAD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04使用吸星大法把所有特感都吸到身边.", client);
			}
			case 58:
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVORS)
					{
						CheatCommand(i, "give", "cola_bottles");
						EmitSoundToClient(i,SOUND_GOOD,client);
					}
				}
				PrintToChatAll("\x03[\x05RP\x03]%N\x04中彩票后买了几箱可乐分给大伙庆祝.", client);
			}
			case 59:
			{
				for(new i = 0; i < 5; i++)
				{
					new ent = GetPlayerWeaponSlot(client, i);
					if(ent != -1) RemovePlayerItem(client, ent);
					EmitSoundToClient(i,SOUND_BAD,client);
				}
				CheatCommand(client, "give", "pistol_magnum");
				PrintToChatAll("\x03[\x05RP\x03]%N\x04平时撸管过多,OP只准他打手枪了,身上其他东西全部没收.", client);
			}
		}
	}
	else
	{
		g_bHasRPActive = false;
	}
}

public Action:Client_RP(Handle:timer, any:client)
{
	g_bIsRPActived[client] = false;
}

public Action:Event_Dudian(Handle:timer, any:client)
{
	g_cdCanTeleport[client] = false;
}

public PerformGlow(Client, Type, Range, Color)
{
	SetEntProp(Client, Prop_Send, "m_iGlowType", Type);
	SetEntProp(Client, Prop_Send, "m_nGlowRange", Range);
	SetEntProp(Client, Prop_Send, "m_glowColorOverride", Color);
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	if(IsClientInGame(target))
	{
		new Handle:msg = StartMessageOne("Fade", target);
		BfWriteShort(msg, 500);
		BfWriteShort(msg, duration);
		if (type == 0) BfWriteShort(msg, (0x0002 | 0x0008));
		else BfWriteShort(msg, (0x0001 | 0x0010));
		BfWriteByte(msg, red);
		BfWriteByte(msg, green);
		BfWriteByte(msg, blue);
		BfWriteByte(msg, alpha);
		EndMessage();
	}
}

public ScreenShake(target, Float:intensity)
{
	if(IsClientInGame(target))
	{
		new Handle:msg = StartMessageOne("Shake", target);
		BfWriteByte(msg, 0);
		BfWriteFloat(msg, intensity);
		BfWriteFloat(msg, 10.0);
		BfWriteFloat(msg, 3.0);
		EndMessage();
	}
}

stock CreateColorSmoke(client, MaxSize, LastSize, SmokeRate, SmokeColor[3], Float:SmokeTimer)
{
	new SmokeEnt = CreateEntityByName("env_smokestack");
	if(SmokeEnt)
	{
		//坐标
		new Float:pos[3];
		new String:originData[64];
		GetClientAbsOrigin(client, pos);
		Format(originData, sizeof(originData), "%f %f %f", pos[0], pos[1], (pos[2]+15.0));
		DispatchKeyValue(SmokeEnt,"Origin", originData);
		//基本蔓延
		DispatchKeyValue(SmokeEnt,"BaseSpread", "100");
		//蔓延速度
		DispatchKeyValue(SmokeEnt,"SpreadSpeed", "70");
		//速度
		DispatchKeyValue(SmokeEnt,"Speed", "80");
		//初始大小
		new String:z_MaxSize[64];
		Format(z_MaxSize, sizeof(z_MaxSize), "%d",	MaxSize);
		DispatchKeyValue(SmokeEnt,"StartSize", z_MaxSize);
		//完结大小
		new String:z_LastSize[64];
		Format(z_LastSize, sizeof(z_LastSize), "%d",  LastSize);
		DispatchKeyValue(SmokeEnt,"EndSize", z_LastSize);
		//厚度
		new String:z_SmokeRate[64];
		Format(z_SmokeRate, sizeof(z_SmokeRate), "%d",	SmokeRate);
		DispatchKeyValue(SmokeEnt,"Rate", z_SmokeRate);
		//射流长度
		DispatchKeyValue(SmokeEnt,"JetLength", "400");
		//漩涡
		DispatchKeyValue(SmokeEnt,"Twist", "20");
		//颜色
		new String:z_SmokeColor[64];
		Format(z_SmokeColor, sizeof(z_SmokeColor), "%d %d %d", SmokeColor[0], SmokeColor[1], SmokeColor[2]+20.0);
		DispatchKeyValue(SmokeEnt,"RenderColor", z_SmokeColor);
		//透明度
		DispatchKeyValue(SmokeEnt,"RenderAmt", "255");
		//材料
		DispatchKeyValue(SmokeEnt,"SmokeMaterial", "particle/particle_smokegrenade1.vmt");

		DispatchSpawn(SmokeEnt);
		AcceptEntityInput(SmokeEnt, "TurnOn");

		new Handle:pack;
		CreateDataTimer(SmokeTimer, Timer_KillSmoke, pack);
		WritePackCell(pack, SmokeEnt);

		new Float:longerdelay = 5.0 + SmokeTimer;
		new Handle:pack2;
		CreateDataTimer(longerdelay, Timer_StopSmoke, pack2);
		WritePackCell(pack2, SmokeEnt);
	}
}

public Action:Timer_KillSmoke(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new SmokeEnt = ReadPackCell(pack);
	StopSmokeEnt(SmokeEnt);
}

StopSmokeEnt(target)
{

	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "TurnOff");
	}
}

public Action:Timer_StopSmoke(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new SmokeEnt = ReadPackCell(pack);
	RemoveSmokeEnt(SmokeEnt);
}

RemoveSmokeEnt(target)
{
	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "Kill");
	}
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
	if (IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		RemoveEdict(particle);
	}
}

stock RevivePlayer(iTarget)
{
	if(GetEntProp(iTarget, Prop_Send, "m_isIncapacitated") || GetEntProp(iTarget, Prop_Send, "m_isHangingFromLedge"))
	{
		// SDKCall(sdkRevive, iTarget);

		/*
		int incap_count = GetEntProp(iTarget, Prop_Send, "m_currentReviveCount");
		CheatCommand(iTarget, "give", "health");
		SetEntProp(iTarget, Prop_Data, "m_iHealth", 1);
		SetEntPropFloat(iTarget, Prop_Send, "m_healthBuffer", g_hCvarReviveHealth.FloatValue);
		SetEntPropFloat(iTarget, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntProp(iTarget, Prop_Send, "m_currentReviveCount", incap_count + 1);

		if(incap_count + 1 == FindConVar("survivor_max_incapacitated_count").IntValue)
			SetEntProp(iTarget, Prop_Send, "m_bIsOnThirdStrike", 1);
		*/

		// CheatCommand(iTarget, "script", "GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(iTarget));
		L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(iTarget));
	}
}

void Charge(int target, int sender, float force = 500.0, float height = 500.0)
{
	decl Float:tpos[3], Float:spos[3];
	decl Float:distance[3], Float:ratio[3], Float:addVel[3], Float:tvec[3];
	GetClientAbsOrigin(target, tpos);
	GetClientAbsOrigin(sender, spos);
	distance[0] = (spos[0] - tpos[0]);
	distance[1] = (spos[1] - tpos[1]);
	distance[2] = (spos[2] - tpos[2]);
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", tvec);
	ratio[0] =	(distance[0] / (SquareRoot(distance[1]*distance[1] + distance[0]*distance[0])));//Ratio x/hypo
	ratio[1] =	(distance[1] / (SquareRoot(distance[1]*distance[1] + distance[0]*distance[0])));//Ratio y/hypo

	addVel[0] = ((ratio[0]*-1) * force);
	addVel[1] = ((ratio[1]*-1) * force);
	addVel[2] = height;

	// SDKCall(sdkCallPushPlayer, target, addVel, 76, sender, 7.0);
	L4D2_CTerrorPlayer_Fling(target, sender, addVel);

	/*
	float angles[3], velocity[3];
	GetClientEyeAngles(sender, angles);
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, power);
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, velocity);
	*/
	
	/*
	if(target == sender)
	{
		// CheatCommand(target, "script", "GetPlayerFromUserID(%d).Stagger(Vector(0,0,0))", GetClientUserId(target));
		L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(0,0,0))", GetClientUserId(target));
	}
	else
	{
		// CheatCommand(target, "script", "GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(target), GetClientUserId(sender));
		L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(target), GetClientUserId(sender));
	}
	*/
}

DealDamage(attacker=0,victim,damage,dmg_type=0)
{
	/*
	if(IsValidEdict(victim) && damage>0)
	{
		new String:victimid[64];
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new PointHurt = CreateEntityByName("point_hurt");
		if(PointHurt)
		{
			Format(victimid, 64, "victim%d", victim);
			DispatchKeyValue(victim,"targetname",victimid);
			DispatchKeyValue(PointHurt,"DamageTarget",victimid);
			DispatchKeyValueFloat(PointHurt,"Damage",float(damage));
			DispatchKeyValue(PointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(PointHurt,"classname",weapon);
			}
			DispatchSpawn(PointHurt);
			if(IsClientInGame(attacker))
			{
				AcceptEntityInput(PointHurt, "Hurt", attacker);
			} else	AcceptEntityInput(PointHurt, "Hurt", -1);
			RemoveEdict(PointHurt);
		}
	}
	*/

	SDKHooks_TakeDamage(victim, 0, attacker, float(damage), dmg_type);
}

public LittleFlower(Float:pos[3], type)
{
	/* Cause fire(type=0) or explosion(type=1) */
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
		else
			/* explode */
			DispatchKeyValue(entity, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

stock PanicEvent()
{
	new Director = CreateEntityByName("info_director");
	DispatchSpawn(Director);
	AcceptEntityInput(Director, "ForcePanicEvent");
	AcceptEntityInput(Director, "Kill");
}

public Action:Timer_RestoreDefault(Handle:timer, any:client)
{
	if(IsValidClient(client))
	{
		Initialization(client, true);
	}
	else
	{
		for (new i = 1; i <= MaxClients; i ++)
		{
			Initialization(i, true);
		}
	}

	return Plugin_Continue;
}

public int Native_AddHealth(Handle plugin, int argc)
{
	if(argc < 4)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int amount = GetNativeCell(2);
	bool limit = GetNativeCell(3);
	bool convertable = GetNativeCell(4);
	
	return AddHealth(client, amount, limit, convertable);
}

public int Native_AddAmmo(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int amount = GetNativeCell(2);
	bool limit = GetNativeCell(3);
	
	return AddAmmo(client, amount, _, _, limit);
}

public int Native_AddArmor(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int amount = GetNativeCell(2);
	bool helmet = GetNativeCell(3);
	
	return AddArmor(client, amount, helmet);
}

public int Native_GiveSkillPoints(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int amount = GetNativeCell(2);
	
	return GiveSkillPoint(client, amount);
}

public int Native_GetSkillPoints(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return g_clSkillPoint[client];
}

public int Native_GiveEquipment(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int parts = GetNativeCell(2);
	
	return GiveEquipment(client, parts);
}

public int Native_GenerateRandomStatus(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	GenerateRandomStats(client, !!GetNativeCell(2));
	return 0;
}

public int Native_SaveToFile(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	bool checkpoint = GetNativeCell(2);
	
	return ClientSaveToFileSave(client, checkpoint);
}

public int Native_LoadFromFile(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	bool checkpoint = GetNativeCell(2);
	
	return ClientSaveToFileLoad(client, checkpoint);
}

public int Native_GetSkill(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int level = GetNativeCell(2);
	int skill = GetNativeCell(3);
	
	switch(level)
	{
		case 1:
			return (g_clSkill_1[client] & skill);
		case 2:
			return (g_clSkill_2[client] & skill);
		case 3:
			return (g_clSkill_3[client] & skill);
		case 4:
			return (g_clSkill_4[client] & skill);
		case 5:
			return (g_clSkill_5[client] & skill);
	}
	
	return 0;
}

public int Native_GiveSkill(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int level = GetNativeCell(2);
	int skill = GetNativeCell(3);
	
	switch(level)
	{
		case 1:
			return (g_clSkill_1[client] |= skill);
		case 2:
			return (g_clSkill_2[client] |= skill);
		case 3:
			return (g_clSkill_3[client] |= skill);
		case 4:
			return (g_clSkill_4[client] |= skill);
		case 5:
			return (g_clSkill_5[client] |= skill);
	}
	
	return 0;
}

public int Native_RemoveSkill(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int level = GetNativeCell(2);
	int skill = GetNativeCell(3);
	
	switch(level)
	{
		case 1:
			return (g_clSkill_1[client] &= ~skill);
		case 2:
			return (g_clSkill_2[client] &= ~skill);
		case 3:
			return (g_clSkill_3[client] &= ~skill);
		case 4:
			return (g_clSkill_4[client] &= ~skill);
		case 5:
			return (g_clSkill_5[client] &= ~skill);
	}
	
	return 0;
}

public int Native_GetEffects(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int effect = GetNativeCell(2);
	
	return IsPlayerHaveEffect(client, effect);
}

public int Native_GetPower(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return CalcPlayerPower(client);
}

public int Native_GetAttrs(Handle plugin, int argc)
{
	if(argc < 6)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	bool withSkill = GetNativeCell(7);
	
	int damage, health, speed, gravity, crit;
	CalcPlayerAttr(client, damage, health, speed, gravity, crit, withSkill);
	
	SetNativeCellRef(2, damage);
	SetNativeCellRef(3, health);
	SetNativeCellRef(4, speed);
	SetNativeCellRef(5, gravity);
	SetNativeCellRef(6, crit);
	
	return 0;
}

public int Native_GetAngrySkill(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return g_clAngryMode[client];
}

public int Native_SetAngrySkill(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int skill = GetNativeCell(2);
	
	return g_clAngryMode[client] = skill;
}

public int Native_GetAngryPoints(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return g_clAngryPoint[client];
}

public int Native_GiveAngryPoints(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int amount = GetNativeCell(2);
	
	GiveAngryPoint(client, amount);
	return 0;
}

public int Native_GetRoundEvent(Handle plugin, int argc)
{
	return g_iRoundEvent;
}

public int Native_SetRoundEvent(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	StartRoundEvent(GetNativeCell(1));
	return 0;
}

public int Native_FreezePlayer(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	float duration = GetNativeCell(2);
	
	FreezePlayer(client, duration);
	return 0;
}

public int Native_GetTempHealth(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return GetPlayerTempHealth(client);
}

public int Native_GetCurrentAttacker(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return GetCurrentAttacker(client);
}

public int Native_GetCurrentVictim(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return GetCurrentVictim(client);
}

public int Native_GetArmor(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return GetEntProp(client, Prop_Send, "m_ArmorValue") + g_iExtraArmor[client];
}

public int Native_GetAmmo(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients || !IsValidEntity(weapon))
		ThrowNativeError(SP_ERROR_PARAM, "no primary weapon");
	
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType) + g_iExtraAmmo[client];
}

public int Native_GetEquipment(Handle plugin, int argc)
{
	if(argc < 3)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	int size = GetNativeCell(3);
	if(size > sizeof(g_clCurEquip[]))
		size = sizeof(g_clCurEquip[]);
	
	SetNativeArray(2, g_clCurEquip[client], size);
	return 0;
}

public int Native_TriggerAngry(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	TriggerAngrySkill(client, GetNativeCell(2));
	return 0;
}

public int Native_TriggerGift(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	RewardPicker(client, GetNativeCell(2));
	return 0;
}

public int Native_TriggerLottery(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	TriggerRP(client, GetNativeCell(2), true);
	return 0;
}

public any Native_GetFreezeTimer(Handle plugin, int argc)
{
	if(argc < 1)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	return g_fFreezeTime[client];
}

public int Native_SetFreezeTimer(Handle plugin, int argc)
{
	if(argc < 2)
		ThrowNativeError(SP_ERROR_PARAM, "params mismatch");
	
	int client = GetNativeCell(1);
	if(!IsValidAliveClient(client))
		ThrowNativeError(SP_ERROR_PARAM, "invalid client");
	
	g_fFreezeTime[client] = view_as<float>(GetNativeCell(2));
	return 0;
}

// 以隐藏的方式打开一个 MOTD 浏览器（也可以用于关闭）
// 这个浏览器将会在客户端后台运行
// 也就是如果这个网页播放的声音客户端听得到，但是看不到网页
stock void CreateHideMotd(int client, const char[] url = "about:blank", const char[] title = "这是一个标题")
{
	if(!IsValidClient(client))
		return;

	/*
	Protobuf pb = UserMessageToProtobuf(StartMessageOne("VGUIMenu", client));
	pb.SetString("name", "info");
	pb.SetBool("show", false);

	Protobuf sub = pb.AddMessage("subkeys");
	sub.SetString("name", "title");
	sub.SetString("str", "");

	sub = pb.AddMessage("subkeys");
	sub.SetString("name", "type");
	sub.SetString("str", "0");

	sub = pb.AddMessage("subkeys");
	sub.SetString("name", "msg");
	sub.SetString("str", "");

	sub = pb.AddMessage("subkeys");
	sub.SetString("name", "cmd");
	sub.SetString("str", "1");

	EndMessage();
	*/

	static KeyValues kv;
	if(kv == null)
	{
		kv = CreateKeyValues("data");
		kv.SetString("title", title);
		kv.SetNum("type", MOTDPANEL_TYPE_URL);
		kv.SetString("msg", url);
	}

	kv.SetString("title", title);
	kv.SetString("msg", url);

	if(!StrEqual(url, "about:blank", false))
		ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);

	ShowVGUIPanel(client, "info", kv, false);
}

// 创建一个跟踪导弹
/*
stock int CreateMissiles(int client, int entity)
{
	if(!IsValidAliveClient(client))
		return -1;
	
	CheatCommand(client, "make_missile", "%d", entity);
	return entity;
}
*/

public bool TraceFilter_DontHitOwnerOrEntity(int entity, int contentsMask, any self)
{
	return (entity != self && entity != GetEntPropEnt(self, Prop_Send, "m_hOwnerEntity"));
}

stock void CreateExplosion(int attacker = -1, float damage, float origin[3], float radius, const char[] classname = "", int inflictor = -1, float force = 0.0)
{
	int entity = CreateEntityByName("env_explosion");
	if(entity == -1)
		return;

	DispatchKeyValue(entity, "iMagnitude", tr("%.0f", damage));
	DispatchKeyValue(entity, "iRadiusOverride", tr("%.0f", radius));
	DispatchKeyValue(entity, "spawnflags", "6146");
	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueFloat(entity, "DamageForce", force);

	if(classname[0] != EOS)
		DispatchKeyValue(entity, "classname", classname);
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", attacker);
	if(inflictor > -1 && HasEntProp(entity, Prop_Data, "m_hInflictor"))
		SetEntPropEnt(entity, Prop_Data, "m_hInflictor", inflictor);
	if(HasEntProp(entity, Prop_Data, "m_hEntityIgnore"))
		SetEntPropEnt(entity, Prop_Data, "m_hEntityIgnore", attacker);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);

	AcceptEntityInput(entity, "Explode", -1, entity);
	// EmitSoundToAll("weapons/hegrenade/explode5.wav", entity, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, origin, NULL_VECTOR, false, 0.0);
	EmitAmbientSound("weapons/hegrenade/explode5.wav", origin, entity, SNDLEVEL_SCREAMING);

	SetVariantString("OnUser1 !self:Kill::1:1");
	AcceptEntityInput(entity, "AddOutput", attacker, entity);
	AcceptEntityInput(entity, "FireUser1", attacker, entity);
}

stock int GetPlayerTempHealth(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
		return 0;
	
	ConVar painPillsDecayCvar;
	if (painPillsDecayCvar == null)
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
	
	int tempHealth = RoundToCeil(
		GetEntPropFloat(client, Prop_Send, "m_healthBuffer") -
		((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) *
		painPillsDecayCvar.FloatValue)) - 1;
	
	return tempHealth < 0 ? 0 : tempHealth;
}

stock bool GiveSkillPoint(int client, int amount)
{
	if(!IsValidClient(client))
		return false;
	
	{
		Call_StartForward(g_fwOnGivePoints);
		Call_PushCell(client);
		
		int refAmount = amount;
		Call_PushCellRef(refAmount);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return false;
		
		if(refResult == Plugin_Changed)
			amount = refAmount;
	}
	
	g_clSkillPoint[client] += amount;
	return true;
}

stock int GiveEquipment(int client, int parts = -1)
{
	if(!IsValidClient(client))
		return 0;
	
	if(g_mEquipData[client] == null)
		g_mEquipData[client] = CreateTrie();
	
	{
		Call_StartForward(g_fwOnGiveEquipment);
		Call_PushCell(client);
		
		int refParts = parts;
		Call_PushCellRef(refParts);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return 0;
		
		if(refResult == Plugin_Changed)
			parts = refParts;
	}
	
	static EquipData_t data;
	
	data.valid = true;
	data.prefix = view_as<EquipPrefix_t>(GetRandomInt(0, 4));
	data.parts = view_as<EquipPart_t>(0 <= parts <= 3 ? parts : GetRandomInt(0, 3));
	data.crit = (GetRandomInt(0, 1) ? GetRandomInt(0, 5) : 0);
	data.effect = (!GetRandomInt(0, 2) ? GetRandomInt(0, g_iMaxEqmEffects) : 0);
	data.hashID = GetSysTickCount() + GetGameTickCount() + client + parts;
	
	SetRandomSeed(GetSysTickCount() + client);
	
	switch(data.parts)
	{
		case EquipPart_Head:
		{
			data.damage = GetRandomInt(1, 8);
			data.health = GetRandomInt(5, 10);
			data.crit = GetRandomInt(0, 3);
			data.gravity = 0;
			data.speed = 0;
		}
		case EquipPart_Body:
		{
			data.damage = GetRandomInt(1, 6);
			data.health = GetRandomInt(10, 20);
			data.crit = 0;
			data.gravity = GetRandomInt(0, 3);
			data.speed = GetRandomInt(0, 5);
		}
		case EquipPart_Hand:
		{
			data.damage = GetRandomInt(10, 20);
			data.health = GetRandomInt(1, 5);
			data.crit = GetRandomInt(5, 15);
			data.gravity = 0;
			data.speed = 0;
		}
		case EquipPart_Foot:
		{
			data.damage = GetRandomInt(1, 3);
			data.health = GetRandomInt(1, 7);
			data.crit = 0;
			data.gravity = GetRandomInt(4, 10);
			data.speed = GetRandomInt(5, 15);
		}
	}
	
	SetRandomSeed(GetGameTickCount() + client);
	
	switch(data.prefix)
	{
		case EquipPrefix_Fire:
			data.damage += GetRandomInt(5, 20);
		case EquipPrefix_Water:
			data.health += GetRandomInt(5, 20);
		case EquipPrefix_Sky:
			data.gravity += GetRandomInt(5, 20);
		case EquipPrefix_Wind:
			data.speed += GetRandomInt(5, 20);
		case EquipPrefix_Lucky:
			data.crit += GetRandomInt(5, 20);
	}
	
	static char key[16];
	IntToString(data.hashID, key, sizeof(key));
	RebuildEquipStr(data);
	g_mEquipData[client].SetArray(key, data, sizeof(data));
	
	return data.hashID;
}

// 数组其实传的是指针，不需要引用传参
void RebuildEquipStr(EquipData_t data)
{
	switch(data.prefix)
	{
		case EquipPrefix_Fire:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "烈火");
		case EquipPrefix_Water:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "流水");
		case EquipPrefix_Sky:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "破天");
		case EquipPrefix_Wind:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "疾风");
		case EquipPrefix_Lucky:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "惊魄");
		default:
			strcopy(data.sPrefix, sizeof(data.sPrefix), "");
	}

	switch(data.parts)
	{
		case EquipPart_Head:
			strcopy(data.sParts, sizeof(data.sParts), "帽");
		case EquipPart_Hand:
			strcopy(data.sParts, sizeof(data.sParts), "手套");
		case EquipPart_Body:
			strcopy(data.sParts, sizeof(data.sParts), "衣");
		case EquipPart_Foot:
			strcopy(data.sParts, sizeof(data.sParts), "鞋");
		default:
			strcopy(data.sParts, sizeof(data.sParts), "");
	}

	switch(data.effect)
	{
		case 1:
			strcopy(data.sEffect, sizeof(data.sEffect), "倒地被救起时恢复HP+20");
		case 2:
			strcopy(data.sEffect, sizeof(data.sEffect), "使用药丸时兴奋10秒");
		case 3:
			strcopy(data.sEffect, sizeof(data.sEffect), "使用怒气技时怒气值恢复10");
		case 4:
			strcopy(data.sEffect, sizeof(data.sEffect), "倒地被救起时兴奋10秒");
		case 5:
			strcopy(data.sEffect, sizeof(data.sEffect), "倒地时反伤HP+100并点燃攻击者");
		case 6:
			strcopy(data.sEffect, sizeof(data.sEffect), "暴击时追加伤害上限+200");
		case 7:
			strcopy(data.sEffect, sizeof(data.sEffect), "「霸气」伤害上限+300,附加回血功能");
		case 8:
			strcopy(data.sEffect, sizeof(data.sEffect), "暴击率+5");
		case 9:
			strcopy(data.sEffect, sizeof(data.sEffect), "「无敌」附加无限子弹功能");
		case 10:
			strcopy(data.sEffect, sizeof(data.sEffect), "死亡时反伤杀害者3000伤害");
		case 11:
			strcopy(data.sEffect, sizeof(data.sEffect), "近战击中坦克时冰冻坦克1秒");
		case 12:
			strcopy(data.sEffect, sizeof(data.sEffect), "每次暴击能恢复5点HP");
		case 13:
			strcopy(data.sEffect, sizeof(data.sEffect), "虚血不会衰减");
		case 14:
			strcopy(data.sEffect, sizeof(data.sEffect), "弹匣容量+15%");
		case 15:
			strcopy(data.sEffect, sizeof(data.sEffect), "携带备用弹药+25%");
		case 16:
			strcopy(data.sEffect, sizeof(data.sEffect), "倒地取消(受到的)冰冻效果");
		case 17:
			strcopy(data.sEffect, sizeof(data.sEffect), "「顽强」触发几率+1/4");
		case 18:
			strcopy(data.sEffect, sizeof(data.sEffect), "「永生」触发几率+1/10");
		case 19:
			strcopy(data.sEffect, sizeof(data.sEffect), "「牺牲」触发几率+1/3");
		case 20:
			strcopy(data.sEffect, sizeof(data.sEffect), "「顽强」触发时处死控制者");
		case 21:
			strcopy(data.sEffect, sizeof(data.sEffect), "土雷引怪持续时间加倍");
		case 22:
			strcopy(data.sEffect, sizeof(data.sEffect), "避免失衡效果(不包括被撞飞/拍飞)");
		case 23:
			strcopy(data.sEffect, sizeof(data.sEffect), "「轰炸」效果加倍");
		case 24:
			strcopy(data.sEffect, sizeof(data.sEffect), "「释冰」范围加倍");
		case 25:
			strcopy(data.sEffect, sizeof(data.sEffect), "「纵火」范围加倍");
		case 26:
			strcopy(data.sEffect, sizeof(data.sEffect), "「永康」回复实血并重置倒地次数");
		case 27:
			strcopy(data.sEffect, sizeof(data.sEffect), "「电疗」替换为医疗包");
		case 28:
			strcopy(data.sEffect, sizeof(data.sEffect), "「爆破」替换为胆汁");
		case 29:
			strcopy(data.sEffect, sizeof(data.sEffect), "被冻结时不会受到伤害");
		case 30:
			strcopy(data.sEffect, sizeof(data.sEffect), "「霸气」目标包括普感");
		case 31:
			strcopy(data.sEffect, sizeof(data.sEffect), "获得弹药升级数量加倍");
		case 32:
			strcopy(data.sEffect, sizeof(data.sEffect), "「霸气」范围增加");
		case 33:
			strcopy(data.sEffect, sizeof(data.sEffect), "「护甲」复活/开局+100");
		case 34:
			strcopy(data.sEffect, sizeof(data.sEffect), "「护甲」倒地救起/打包+50");
		case 35:
			strcopy(data.sEffect, sizeof(data.sEffect), "开局/复活满血");
		case 36:
			strcopy(data.sEffect, sizeof(data.sEffect), "【王者之仁德】增加「顽强」效果");
		case 37:
			strcopy(data.sEffect, sizeof(data.sEffect), "被僵尸锤不减速");
		case 38:
			strcopy(data.sEffect, sizeof(data.sEffect), "水中/残血不减速");
		case 39:
			strcopy(data.sEffect, sizeof(data.sEffect), "武器随机皮肤");
		default:
			strcopy(data.sEffect, sizeof(data.sEffect), "");
	}
	
	bool legend = (data.damage >= g_iMaxEquipDamage ||
		data.health >= g_iMaxEquipHealth ||
		data.speed >= g_iMaxEquipSpeed ||
		data.gravity >= g_iMaxEquipGravity ||
		data.crit >= g_iMaxEquipCrit
	);

	if(data.effect > 0 && legend)
		strcopy(data.sNamed, sizeof(data.sNamed), "玛瑙");
	else if(data.effect > 0 || legend)
		strcopy(data.sNamed, sizeof(data.sNamed), "水晶");
	else
		strcopy(data.sNamed, sizeof(data.sNamed), "琥珀");
}

stock int IsPlayerHaveEffect(int client, int effect)
{
	if(g_mEquipData[client] == null)
		return 0;
	
	int ExtraAdd = 0;
	
	/*
	for(int i = 0; i < sizeof(g_clCurEquip[]); i++)
	{
		if(!g_clCurEquip[client][i])
			continue;
		
		static char key[16];
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		
		static EquipData_t data;
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
			continue;
		
		if(data.effect == effect)
		{
			ExtraAdd += 1;
			// break;
		}
	}
	*/
	
	for(int i = 0; i < sizeof(g_iActiveEffects[]); ++i)
	{
		if(g_iActiveEffects[client][i] == effect)
		{
			ExtraAdd += 1;
			// break;
		}
	}
	
	return ExtraAdd;
}

stock void CalcPlayerAttr(int client, int& damage = 0, int& health = 0, int& speed = 0, int& gravity = 0, int& crit = 0, bool withSkill = true)
{
	damage = health = speed = gravity = crit = 0;
	
	for(int i = 0; i < sizeof(g_clCurEquip[]); i++)
	{
		if(!g_clCurEquip[client][i])
			continue;
		
		static char key[16];
		IntToString(g_clCurEquip[client][i], key, sizeof(key));
		
		static EquipData_t data;
		if(!g_mEquipData[client].GetArray(key, data, sizeof(data)) || !data.valid)
			continue;
		
		if(data.damage > 0)
			damage += data.damage;
		if(data.health > 0)
			health += data.health;
		if(data.speed > 0)
			speed += data.speed;
		if(data.gravity > 0)
			gravity += data.gravity;
		if(data.crit > 0)
			crit += data.crit;
		
		if(withSkill)
		{
			if(data.effect == 8)
				crit += 5;
			
			/*
			if(data.prefix == EquipPrefix_Lucky)
				crit += 2;
			*/
		}
	}
	
	if(withSkill)
	{
		if(g_clSkill_1[client] & SKL_1_MaxHealth)
			health += 50;
		if(g_clSkill_1[client] & SKL_1_Movement)
			speed += 10;
		if(g_clSkill_1[client] & SKL_1_Gravity)
			gravity += 20;
		if(g_clSkill_5[client] & SKL_5_DmgExtra)
			crit += crit / 3 + 25;
	}
}

char StartRoundEvent(int event = -1, char[] text = "", int len = 0)
{
	char buffer[64];
	RestoreConVar();

	if(event == -1)
		event = GetRandomInt(0, 19);
	
	{
		Call_StartForward(g_fwOnRoundEvent);
		
		int refEvent = event;
		Call_PushCellRef(refEvent);
		
		Action refResult = Plugin_Continue;
		if(Call_Finish(refResult) != SP_ERROR_NONE)
			refResult = Plugin_Continue;
		
		if(refResult >= Plugin_Handled)
			return buffer;
		
		if(refResult == Plugin_Changed)
			event = refEvent;
	}
	
	switch(event)
	{
		case 0:
		{
			g_iRoundEvent = 1;
			g_hCvarPaincEvent.IntValue = 1;
			PanicEvent();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "无限尸潮");
			strcopy(buffer, sizeof(buffer), "无限尸潮");
		}
		case 1:
		{
			g_iRoundEvent = 2;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "无限子弹");
			strcopy(buffer, sizeof(buffer), "无限主武器子弹(榴弹除外)");
		}
		case 2:
		{
			g_iRoundEvent = 3;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "剑气+神托");
			SetConVarString(g_hCvarMeleeRange, "2000");
			SetConVarString(g_hCvarShovRange, "2000");
			SetConVarString(g_hCvarShovTime, "0.3");
			strcopy(buffer, sizeof(buffer), "近战攻击范围和枪托范围超远");
		}
		case 3:
		{
			g_iRoundEvent = 4;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "蹲坑神速");
			SetConVarString(g_hCvarDuckSpeed, "300");
			strcopy(buffer, sizeof(buffer), "蹲下行走速度加快");
		}
		case 4:
		{
			g_iRoundEvent = 5;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "疾速救援+疾速医疗");
			SetConVarString(g_hCvarReviveTime, "1");
			SetConVarString(g_hCvarMedicalTime, "1");
			SetConVarString(g_hCvarDefibTime, "1");
			strcopy(buffer, sizeof(buffer), "打包和救人电击时间减少");
		}
		case 5:
		{
			g_iRoundEvent = 6;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "极度兴奋");
			SetConVarString(g_hCvarAdrenTime, "30");
			strcopy(buffer, sizeof(buffer), "打上肾上腺的兴奋时间是30秒");
		}
		case 6:
		{
			g_iRoundEvent = 7;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "丧尸强化");
			g_iCommonHealth = 100;
			SetConVarString(g_hCvarZombieSpeed, "300");
			SetConVarString(g_hCvarZombieHealth, "100");
			strcopy(buffer, sizeof(buffer), "普通僵尸速度加快血量增加");
		}
		case 7:
		{
			g_iRoundEvent = 8;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "意志坚定");
			SetConVarString(g_hCvarReviveHealth, "100");
			strcopy(buffer, sizeof(buffer), "倒地被救起的血量为100");
		}
		case 8:
		{
			g_iRoundEvent = 9;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "防火服");
			SetConVarString(g_hCvarBurnNormal, "0");
			SetConVarString(g_hCvarBurnHard, "0");
			SetConVarString(g_hCvarBurnExpert, "0");

			strcopy(buffer, sizeof(buffer), "生还者免疫火烧");
		}
		case 9:
		{
			g_iRoundEvent = 10;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "怒火街头");
			strcopy(buffer, sizeof(buffer), "玩家获取的怒气值加倍");
		}
		case 10:
		{
			g_iRoundEvent = 11;
			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "女巫季节");
			strcopy(buffer, sizeof(buffer), "每120秒出现一个witch");
		}
		case 11:
		{
			g_iRoundEvent = 12;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "天赐神技");
			strcopy(buffer, sizeof(buffer), "生还者临时获得天赋:烈火-开枪1/2出现燃烧子弹");
		}
		case 12:
		{
			g_iRoundEvent = 13;
			g_hCvarLimitSpecial.IntValue = 8;
			g_hCvarLimitSmoker.IntValue = 2;
			g_hCvarLimitBoomer.IntValue = 2;
			g_hCvarLimitHunter.IntValue = 2;
			g_hCvarLimitSpitter.IntValue = 2;
			g_hCvarLimitJockey.IntValue = 2;
			g_hCvarLimitCharger.IntValue = 2;

			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "绝境求生");
			strcopy(buffer, sizeof(buffer), "每隔40秒刷8个特感");
		}
		case 13:
		{
			g_iRoundEvent = 14;
			g_hCvarIncapCount.IntValue = 0;
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
					continue;

				// SetEntProp(i, Prop_Send, "m_currentReviveCount", 0);
				SetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 0);
				SetEntProp(i, Prop_Send, "m_isGoingToDie", 0);
				// CheatCommandEx(i, "stopsound");
			}

			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "死亡之门");
			strcopy(buffer, sizeof(buffer), "倒地就死");
		}
		case 14:
		{
			g_iRoundEvent = 15;
			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "感染季节");
			strcopy(buffer, sizeof(buffer), "每隔30秒刷两对Boomer和Spitter");
		}
		case 15:
		{
			g_iRoundEvent = 16;
			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "狩猎盛宴");
			strcopy(buffer, sizeof(buffer), "每隔20秒刷两只Hunter");
		}
		case 16:
		{
			g_iRoundEvent = 17;
			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "运输大队");
			strcopy(buffer, sizeof(buffer), "每隔90秒刷一只携带补给的普感");
		}
		case 17:
		{
			g_iRoundEvent = 18;
			g_fNextRoundEvent = GetGameTime();
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "乘骑派对");
			strcopy(buffer, sizeof(buffer), "每隔20秒刷两只Jockey");
		}
		case 18:
		{
			g_iRoundEvent = 19;
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(!IsValidAliveClient(i) || GetClientTeam(i) != 2)
					continue;
				
				ApplyHealthSwap(i);
			}
			
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "血流不止");
			strcopy(buffer, sizeof(buffer), "打包/电击/复活血量改为虚血");
		}
		case 19:
		{
			g_iRoundEvent = 20;
			g_hCvarAccele.IntValue = 2000;
			g_hCvarCollide.IntValue = 1;
			strcopy(g_szRoundEvent, sizeof(g_szRoundEvent), "弹力鞋");
			strcopy(buffer, sizeof(buffer), "连跳可以跳得更高更快");
		}

		default:
			buffer[0] = EOS;
	}

	if(len > strlen(buffer))
		strcopy(text, len, buffer);

	return buffer;
}

char tr(const char[] text, any ...)
{
	char line[1024];
	VFormat(line, 1024, text, 2);
	return line;
}

void PrepSDKCall_CreateSpecials()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", "l4dinfectedbots");
	if(FileExists(sPath))
	{
		Handle hGameConf = LoadGameConfigFile("l4dinfectedbots");
		if(hGameConf)
		{
			//find create bot signature
			Address replaceWithBot = GameConfGetAddress(hGameConf, "NextBotCreatePlayerBot.jumptable");
			if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
				// We're on L4D2 and linux
				PrepWindowsCreateBotCalls(replaceWithBot);
			}
			else
			{
				PrepL4D1CreateBotCalls(hGameConf);
				PrepL4D2CreateBotCalls(hGameConf);
			}
			
			delete hGameConf;
		}
	}
}

#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();	
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) {
	Handle hInfectedFuncs = CreateTrie();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.
	
	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++) {
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		//PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
	}

	g_pfnCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	g_pfnCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	g_pfnCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	g_pfnCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	g_pfnCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	g_pfnCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	g_pfnCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
}

void PrepL4D2CreateBotCalls(Handle hGameConf) {
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateSpitter))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateSpitter = EndPrepSDKCall();
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateJockey))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateJockey = EndPrepSDKCall();
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateCharger))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateCharger = EndPrepSDKCall();
	}
}

void PrepL4D1CreateBotCalls(Handle hGameConf) {
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateSmoker))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateSmoker = EndPrepSDKCall();
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateBoomer))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateBoomer = EndPrepSDKCall();
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateHunter))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateHunter = EndPrepSDKCall();
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, NAME_CreateTank))
	{
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_pfnCreateTank = EndPrepSDKCall();
	}
}
