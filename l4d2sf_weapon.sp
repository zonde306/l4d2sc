#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>
#include <weaponhandling>
#include <left4dhooks>
#include <dhooks>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：武器调整",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMaxLevel = 4;
const int g_iMinLevel = 1;
const int g_iMinSkillLevel = 10;
const float g_fLevelFactor = 1.0;
const int g_iMaxClip = 254;					// 游戏所允许的最大弹匣数量 8bit，但是 255 会被显示为 0，超过会溢出
const int g_iMaxAmmo = 1023;				// 游戏所允许的最大子弹数量 10bit，超过会溢出

int g_iSlotPistol, g_iSlotShotgun, g_iSlotRifle, g_iSlotSniper, g_iSlotMelee;
ConVar g_cvPistolClip[g_iMaxLevel+1], g_cvPistolAmmo[g_iMaxLevel+1], g_cvPistolShot[g_iMaxLevel+1], g_cvPistolReload[g_iMaxLevel+1],
	g_cvShotgunClip[g_iMaxLevel+1], g_cvShotgunAmmo[g_iMaxLevel+1], g_cvShotgunShot[g_iMaxLevel+1], g_cvShotgunReload[g_iMaxLevel+1],
	g_cvRifleClip[g_iMaxLevel+1], g_cvRifleAmmo[g_iMaxLevel+1], g_cvRifleShot[g_iMaxLevel+1], g_cvRifleReload[g_iMaxLevel+1],
	g_cvSniperClip[g_iMaxLevel+1], g_cvSniperAmmo[g_iMaxLevel+1], g_cvSniperShot[g_iMaxLevel+1], g_cvSniperReload[g_iMaxLevel+1],
	g_cvMeleeRange[g_iMaxLevel+1], g_cvShoveRange[g_iMaxLevel+1], g_cvMeleeSwing[g_iMaxLevel+1], g_cvShoveCount[g_iMaxLevel+1];
ConVar g_hCvarShovRange, g_hCvarMeleeRange, g_hCvarChargerShove;

public OnPluginStart()
{
	InitPlugin("sfw");
	
	g_cvPistolClip[1] = CreateConVar("l4d2_sfw_pistol_clip_1st", "1.25", "一级手枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolClip[2] = CreateConVar("l4d2_sfw_pistol_clip_2nd", "1.5", "二级手枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolClip[3] = CreateConVar("l4d2_sfw_pistol_clip_3rd", "1.75", "三级手枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolClip[4] = CreateConVar("l4d2_sfw_pistol_clip_4th", "2.0", "四级手枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolAmmo[1] = CreateConVar("l4d2_sfw_pistol_ammo_1st", "1.25", "一级手枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolAmmo[2] = CreateConVar("l4d2_sfw_pistol_ammo_2nd", "1.5", "二级手枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolAmmo[3] = CreateConVar("l4d2_sfw_pistol_ammo_3rd", "1.75", "三级手枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolAmmo[4] = CreateConVar("l4d2_sfw_pistol_ammo_4th", "2.0", "四级手枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolShot[1] = CreateConVar("l4d2_sfw_pistol_fire_1st", "1.25", "一级手枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolShot[2] = CreateConVar("l4d2_sfw_pistol_fire_2nd", "1.5", "二级手枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolShot[3] = CreateConVar("l4d2_sfw_pistol_fire_3rd", "1.75", "三级手枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolShot[4] = CreateConVar("l4d2_sfw_pistol_fire_4th", "2.0", "四级手枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolReload[1] = CreateConVar("l4d2_sfw_pistol_reload_1st", "1.25", "一级手枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolReload[2] = CreateConVar("l4d2_sfw_pistol_reload_2nd", "1.5", "二级手枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolReload[3] = CreateConVar("l4d2_sfw_pistol_reload_3rd", "1.75", "三级手枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvPistolReload[4] = CreateConVar("l4d2_sfw_pistol_reload_4th", "2.0", "四级手枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvShotgunClip[1] = CreateConVar("l4d2_sfw_shotgun_clip_1st", "1.25", "一级霰弹枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunClip[2] = CreateConVar("l4d2_sfw_shotgun_clip_2nd", "1.5", "二级霰弹枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunClip[3] = CreateConVar("l4d2_sfw_shotgun_clip_3rd", "1.75", "三级霰弹枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunClip[4] = CreateConVar("l4d2_sfw_shotgun_clip_4th", "2.0", "四级霰弹枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunAmmo[1] = CreateConVar("l4d2_sfw_shotgun_ammo_1st", "1.25", "一级霰弹枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunAmmo[2] = CreateConVar("l4d2_sfw_shotgun_ammo_2nd", "1.5", "二级霰弹枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunAmmo[3] = CreateConVar("l4d2_sfw_shotgun_ammo_3rd", "1.75", "三级霰弹枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunAmmo[4] = CreateConVar("l4d2_sfw_shotgun_ammo_4th", "2.0", "四级霰弹枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunShot[1] = CreateConVar("l4d2_sfw_shotgun_fire_1st", "1.25", "一级霰弹枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunShot[2] = CreateConVar("l4d2_sfw_shotgun_fire_2nd", "1.5", "二级霰弹枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunShot[3] = CreateConVar("l4d2_sfw_shotgun_fire_3rd", "1.75", "三级霰弹枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunShot[4] = CreateConVar("l4d2_sfw_shotgun_fire_4th", "2.0", "四级霰弹枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunReload[1] = CreateConVar("l4d2_sfw_shotgun_reload_1st", "1.25", "一级霰弹枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunReload[2] = CreateConVar("l4d2_sfw_shotgun_reload_2nd", "1.5", "二级霰弹枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunReload[3] = CreateConVar("l4d2_sfw_shotgun_reload_3rd", "1.75", "三级霰弹枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvShotgunReload[4] = CreateConVar("l4d2_sfw_shotgun_reload_4th", "2.0", "四级霰弹枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvRifleClip[1] = CreateConVar("l4d2_sfw_rifle_clip_1st", "1.25", "一级步枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleClip[2] = CreateConVar("l4d2_sfw_rifle_clip_2nd", "1.5", "二级步枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleClip[3] = CreateConVar("l4d2_sfw_rifle_clip_3rd", "1.75", "三级步枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleClip[4] = CreateConVar("l4d2_sfw_rifle_clip_4th", "2.0", "四级步枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleAmmo[1] = CreateConVar("l4d2_sfw_rifle_ammo_1st", "1.25", "一级步枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleAmmo[2] = CreateConVar("l4d2_sfw_rifle_ammo_2nd", "1.5", "二级步枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleAmmo[3] = CreateConVar("l4d2_sfw_rifle_ammo_3rd", "1.75", "三级步枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleAmmo[4] = CreateConVar("l4d2_sfw_rifle_ammo_4th", "2.0", "四级步枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleShot[1] = CreateConVar("l4d2_sfw_rifle_fire_1st", "1.25", "一级步枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleShot[2] = CreateConVar("l4d2_sfw_rifle_fire_2nd", "1.5", "二级步枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleShot[3] = CreateConVar("l4d2_sfw_rifle_fire_3rd", "1.75", "三级步枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleShot[4] = CreateConVar("l4d2_sfw_rifle_fire_4th", "2.0", "四级步枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleReload[1] = CreateConVar("l4d2_sfw_rifle_reload_1st", "1.25", "一级步枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleReload[2] = CreateConVar("l4d2_sfw_rifle_reload_2nd", "1.5", "二级步枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleReload[3] = CreateConVar("l4d2_sfw_rifle_reload_3rd", "1.75", "三级步枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvRifleReload[4] = CreateConVar("l4d2_sfw_rifle_reload_4th", "2.0", "四级步枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvSniperClip[1] = CreateConVar("l4d2_sfw_sniper_clip_1st", "1.25", "一级狙击枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperClip[2] = CreateConVar("l4d2_sfw_sniper_clip_2nd", "1.5", "二级狙击枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperClip[3] = CreateConVar("l4d2_sfw_sniper_clip_3rd", "1.75", "三级狙击枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperClip[4] = CreateConVar("l4d2_sfw_sniper_clip_4th", "2.0", "四级狙击枪弹匣倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperAmmo[1] = CreateConVar("l4d2_sfw_sniper_ammo_1st", "1.25", "一级狙击枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperAmmo[2] = CreateConVar("l4d2_sfw_sniper_ammo_2nd", "1.5", "二级狙击枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperAmmo[3] = CreateConVar("l4d2_sfw_sniper_ammo_3rd", "1.75", "三级狙击枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperAmmo[4] = CreateConVar("l4d2_sfw_sniper_ammo_4th", "2.0", "四级狙击枪弹药倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperShot[1] = CreateConVar("l4d2_sfw_sniper_fire_1st", "1.25", "一级狙击枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperShot[2] = CreateConVar("l4d2_sfw_sniper_fire_2nd", "1.5", "二级狙击枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperShot[3] = CreateConVar("l4d2_sfw_sniper_fire_3rd", "1.75", "三级狙击枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperShot[4] = CreateConVar("l4d2_sfw_sniper_fire_4th", "2.0", "四级狙击枪射速倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperReload[1] = CreateConVar("l4d2_sfw_sniper_reload_1st", "1.25", "一级狙击枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperReload[2] = CreateConVar("l4d2_sfw_sniper_reload_2nd", "1.5", "二级狙击枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperReload[3] = CreateConVar("l4d2_sfw_sniper_reload_3rd", "1.75", "三级狙击枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	g_cvSniperReload[4] = CreateConVar("l4d2_sfw_sniper_reload_4th", "2.0", "四级狙击枪装填速度倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvMeleeRange[1] = CreateConVar("l4d2_sfw_melee_range_1st", "1.25", "一级近战范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeRange[2] = CreateConVar("l4d2_sfw_melee_range_2nd", "1.5", "二级近战范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeRange[3] = CreateConVar("l4d2_sfw_melee_range_3rd", "1.75", "三级近战范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeRange[4] = CreateConVar("l4d2_sfw_melee_range_4th", "2.0", "四级近战范围倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvShoveRange[1] = CreateConVar("l4d2_sfw_shove_range_1st", "1.25", "一级推范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveRange[2] = CreateConVar("l4d2_sfw_shove_range_2nd", "1.5", "二级推范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveRange[3] = CreateConVar("l4d2_sfw_shove_range_3rd", "1.75", "三级推范围倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveRange[4] = CreateConVar("l4d2_sfw_shove_range_4th", "2.0", "四级推范围倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvMeleeSwing[1] = CreateConVar("l4d2_sfw_melee_fire_1st", "1.25", "一级近战攻速倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeSwing[2] = CreateConVar("l4d2_sfw_melee_fire_2nd", "1.5", "二级近战攻速倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeSwing[3] = CreateConVar("l4d2_sfw_melee_fire_3rd", "1.75", "三级近战攻速倍率", CVAR_FLAGS, true, 0.0);
	g_cvMeleeSwing[4] = CreateConVar("l4d2_sfw_melee_fire_4th", "2.0", "四级近战攻速倍率", CVAR_FLAGS, true, 0.0);
	
	g_cvShoveCount[1] = CreateConVar("l4d2_sfw_shove_penalty_1st", "1.25", "一级推次数倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveCount[2] = CreateConVar("l4d2_sfw_shove_penalty_2nd", "1.5", "二级推次数倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveCount[3] = CreateConVar("l4d2_sfw_shove_penalty_3rd", "1.75", "三级推次数倍率", CVAR_FLAGS, true, 0.0);
	g_cvShoveCount[4] = CreateConVar("l4d2_sfw_shove_penalty_4th", "2.0", "四级推次数倍率", CVAR_FLAGS, true, 0.0);
	
	AutoExecConfig(true, "l4d2_sfw");
	
	g_hCvarMeleeRange = FindConVar("melee_range");
	g_hCvarShovRange = FindConVar("z_gun_range");
	g_hCvarChargerShove = FindConVar("z_charger_allow_shove");
	
	OnConfigChanged_UpdateCache(null, "", "");
	g_cvPistolClip[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolClip[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolClip[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolClip[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolAmmo[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolAmmo[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolAmmo[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolAmmo[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolShot[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolShot[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolShot[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolShot[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolReload[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolReload[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolReload[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvPistolReload[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunClip[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunClip[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunClip[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunClip[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunAmmo[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunAmmo[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunAmmo[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunAmmo[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunShot[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunShot[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunShot[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunShot[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunReload[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunReload[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunReload[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShotgunReload[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleClip[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleClip[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleClip[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleClip[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleAmmo[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleAmmo[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleAmmo[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleAmmo[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleShot[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleShot[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleShot[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleShot[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleReload[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleReload[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleReload[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvRifleReload[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperClip[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperClip[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperClip[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperClip[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperAmmo[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperAmmo[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperAmmo[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperAmmo[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperShot[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperShot[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperShot[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperShot[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperReload[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperReload[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperReload[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvSniperReload[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeRange[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeRange[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeRange[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeRange[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveRange[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveRange[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveRange[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveRange[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeSwing[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeSwing[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeSwing[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvMeleeSwing[4].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveCount[1].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveCount[2].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveCount[3].AddChangeHook(OnConfigChanged_UpdateCache);
	g_cvShoveCount[4].AddChangeHook(OnConfigChanged_UpdateCache);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	// HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_reload", Event_WeaponReload);
	HookEvent("ammo_pickup", Event_AmmoPickup);
	HookEvent("item_pickup", Event_WeaponPickuped);
	HookEvent("player_use", Event_PlayerUsed);
	HookEvent("weapon_drop", Event_WeaponDropped);
	HookEvent("upgrade_pack_added", Event_UpgradePickup);
	
	InitSwingHook();
	
	LoadTranslations("l4d2sf_weapon.phrases.txt");
	
	g_iSlotPistol = L4D2SF_RegSlot("pistol");
	g_iSlotShotgun = L4D2SF_RegSlot("shotgun");
	g_iSlotRifle = L4D2SF_RegSlot("rifle");
	g_iSlotSniper = L4D2SF_RegSlot("sniper");
	g_iSlotMelee = L4D2SF_RegSlot("melee");
	
	L4D2SF_RegPerk(g_iSlotPistol, "pistol_clip", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	// L4D2SF_RegPerk(g_iSlotPistol, "pistol_ammo", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotPistol, "pistol_fire", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotPistol, "pistol_reload", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotPistol, "pistol_recoil", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_clip", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_ammo", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_fire", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_reload", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotShotgun, "shotgun_recoil", 2, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_clip", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_ammo", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_fire", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_reload", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_keep", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotRifle, "rifle_recoil", 2, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_clip", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_ammo", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_fire", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_reload", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_keep", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotSniper, "sniper_recoil", 2, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	
	L4D2SF_RegPerk(g_iSlotMelee, "melee_range", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotMelee, "melee_fire", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotMelee, "shove_range", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	// L4D2SF_RegPerk(g_iSlotMelee, "shove_count", g_iMaxLevel, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotMelee, "shove_charger", 1, g_iMinSkillLevel, g_iMinLevel, g_fLevelFactor);
}

Handle g_pfnFindUseEntity = null;
Handle g_hDetourTestMeleeSwingCollision = null, g_hDetourTestSwingCollision = null;

void InitSwingHook()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", "l4d2_dlc2_levelup");
	if( FileExists(sPath) )
	{
		Handle hGameData = LoadGameConfigFile("l4d2_dlc2_levelup");
		if( hGameData != null )
		{
			g_hDetourTestMeleeSwingCollision = DHookCreateFromConf(hGameData, "CTerrorMeleeWeapon::TestMeleeSwingCollision");
			if(g_hDetourTestMeleeSwingCollision != null)
			{
				DHookEnableDetour(g_hDetourTestMeleeSwingCollision, false, TestMeleeSwingCollisionPre);
				DHookEnableDetour(g_hDetourTestMeleeSwingCollision, true, TestMeleeSwingCollisionPost);
			}
			
			g_hDetourTestSwingCollision = DHookCreateFromConf(hGameData, "CTerrorWeapon::TestSwingCollision");
			if(g_hDetourTestSwingCollision != null)
			{
				DHookEnableDetour(g_hDetourTestSwingCollision, false, TestSwingCollisionPre);
				DHookEnableDetour(g_hDetourTestSwingCollision, true, TestSwingCollisionPost);
			}
			
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
			
			delete hGameData;
		}
	}
}

float g_fPistolClip[g_iMaxLevel+1], g_fPistolAmmo[g_iMaxLevel+1], g_fPistolShot[g_iMaxLevel+1], g_fPistolReload[g_iMaxLevel+1],
	g_fShotgunClip[g_iMaxLevel+1], g_fShotgunAmmo[g_iMaxLevel+1], g_fShotgunShot[g_iMaxLevel+1], g_fShotgunReload[g_iMaxLevel+1],
	g_fRifleClip[g_iMaxLevel+1], g_fRifleAmmo[g_iMaxLevel+1], g_fRifleShot[g_iMaxLevel+1], g_fRifleReload[g_iMaxLevel+1],
	g_fSniperClip[g_iMaxLevel+1], g_fSniperAmmo[g_iMaxLevel+1], g_fSniperShot[g_iMaxLevel+1], g_fSniperReload[g_iMaxLevel+1],
	g_fMeleeRange[g_iMaxLevel+1], g_fShoveRange[g_iMaxLevel+1], g_fMeleeSwing[g_iMaxLevel+1], g_fShoveCount[g_iMaxLevel+1];

public void OnConfigChanged_UpdateCache(ConVar cvar, const char[] ov, const char[] nv)
{
	g_fPistolClip[1] = g_cvPistolClip[1].FloatValue;
	g_fPistolClip[2] = g_cvPistolClip[2].FloatValue;
	g_fPistolClip[3] = g_cvPistolClip[3].FloatValue;
	g_fPistolClip[4] = g_cvPistolClip[4].FloatValue;
	g_fPistolAmmo[1] = g_cvPistolAmmo[1].FloatValue;
	g_fPistolAmmo[2] = g_cvPistolAmmo[2].FloatValue;
	g_fPistolAmmo[3] = g_cvPistolAmmo[3].FloatValue;
	g_fPistolAmmo[4] = g_cvPistolAmmo[4].FloatValue;
	g_fPistolShot[1] = g_cvPistolShot[1].FloatValue;
	g_fPistolShot[2] = g_cvPistolShot[2].FloatValue;
	g_fPistolShot[3] = g_cvPistolShot[3].FloatValue;
	g_fPistolShot[4] = g_cvPistolShot[4].FloatValue;
	g_fPistolReload[1] = g_cvPistolReload[1].FloatValue;
	g_fPistolReload[2] = g_cvPistolReload[2].FloatValue;
	g_fPistolReload[3] = g_cvPistolReload[3].FloatValue;
	g_fPistolReload[4] = g_cvPistolReload[4].FloatValue;
	g_fShotgunClip[1] = g_cvShotgunClip[1].FloatValue;
	g_fShotgunClip[2] = g_cvShotgunClip[2].FloatValue;
	g_fShotgunClip[3] = g_cvShotgunClip[3].FloatValue;
	g_fShotgunClip[4] = g_cvShotgunClip[4].FloatValue;
	g_fShotgunAmmo[1] = g_cvShotgunAmmo[1].FloatValue;
	g_fShotgunAmmo[2] = g_cvShotgunAmmo[2].FloatValue;
	g_fShotgunAmmo[3] = g_cvShotgunAmmo[3].FloatValue;
	g_fShotgunAmmo[4] = g_cvShotgunAmmo[4].FloatValue;
	g_fShotgunShot[1] = g_cvShotgunShot[1].FloatValue;
	g_fShotgunShot[2] = g_cvShotgunShot[2].FloatValue;
	g_fShotgunShot[3] = g_cvShotgunShot[3].FloatValue;
	g_fShotgunShot[4] = g_cvShotgunShot[4].FloatValue;
	g_fShotgunReload[1] = g_cvShotgunReload[1].FloatValue;
	g_fShotgunReload[2] = g_cvShotgunReload[2].FloatValue;
	g_fShotgunReload[3] = g_cvShotgunReload[3].FloatValue;
	g_fShotgunReload[4] = g_cvShotgunReload[4].FloatValue;
	g_fRifleClip[1] = g_cvRifleClip[1].FloatValue;
	g_fRifleClip[2] = g_cvRifleClip[2].FloatValue;
	g_fRifleClip[3] = g_cvRifleClip[3].FloatValue;
	g_fRifleClip[4] = g_cvRifleClip[4].FloatValue;
	g_fRifleAmmo[1] = g_cvRifleAmmo[1].FloatValue;
	g_fRifleAmmo[2] = g_cvRifleAmmo[2].FloatValue;
	g_fRifleAmmo[3] = g_cvRifleAmmo[3].FloatValue;
	g_fRifleAmmo[4] = g_cvRifleAmmo[4].FloatValue;
	g_fRifleShot[1] = g_cvRifleShot[1].FloatValue;
	g_fRifleShot[2] = g_cvRifleShot[2].FloatValue;
	g_fRifleShot[3] = g_cvRifleShot[3].FloatValue;
	g_fRifleShot[4] = g_cvRifleShot[4].FloatValue;
	g_fRifleReload[1] = g_cvRifleReload[1].FloatValue;
	g_fRifleReload[2] = g_cvRifleReload[2].FloatValue;
	g_fRifleReload[3] = g_cvRifleReload[3].FloatValue;
	g_fRifleReload[4] = g_cvRifleReload[4].FloatValue;
	g_fSniperClip[1] = g_cvSniperClip[1].FloatValue;
	g_fSniperClip[2] = g_cvSniperClip[2].FloatValue;
	g_fSniperClip[3] = g_cvSniperClip[3].FloatValue;
	g_fSniperClip[4] = g_cvSniperClip[4].FloatValue;
	g_fSniperAmmo[1] = g_cvSniperAmmo[1].FloatValue;
	g_fSniperAmmo[2] = g_cvSniperAmmo[2].FloatValue;
	g_fSniperAmmo[3] = g_cvSniperAmmo[3].FloatValue;
	g_fSniperAmmo[4] = g_cvSniperAmmo[4].FloatValue;
	g_fSniperShot[1] = g_cvSniperShot[1].FloatValue;
	g_fSniperShot[2] = g_cvSniperShot[2].FloatValue;
	g_fSniperShot[3] = g_cvSniperShot[3].FloatValue;
	g_fSniperShot[4] = g_cvSniperShot[4].FloatValue;
	g_fSniperReload[1] = g_cvSniperReload[1].FloatValue;
	g_fSniperReload[2] = g_cvSniperReload[2].FloatValue;
	g_fSniperReload[3] = g_cvSniperReload[3].FloatValue;
	g_fSniperReload[4] = g_cvSniperReload[4].FloatValue;
	g_fMeleeRange[1] = g_cvMeleeRange[1].FloatValue;
	g_fMeleeRange[2] = g_cvMeleeRange[2].FloatValue;
	g_fMeleeRange[3] = g_cvMeleeRange[3].FloatValue;
	g_fMeleeRange[4] = g_cvMeleeRange[4].FloatValue;
	g_fShoveRange[1] = g_cvShoveRange[1].FloatValue;
	g_fShoveRange[2] = g_cvShoveRange[2].FloatValue;
	g_fShoveRange[3] = g_cvShoveRange[3].FloatValue;
	g_fShoveRange[4] = g_cvShoveRange[4].FloatValue;
	g_fMeleeSwing[1] = g_cvMeleeSwing[1].FloatValue;
	g_fMeleeSwing[2] = g_cvMeleeSwing[2].FloatValue;
	g_fMeleeSwing[3] = g_cvMeleeSwing[3].FloatValue;
	g_fMeleeSwing[4] = g_cvMeleeSwing[4].FloatValue;
	g_fShoveCount[1] = g_cvShoveCount[1].FloatValue;
	g_fShoveCount[2] = g_cvShoveCount[2].FloatValue;
	g_fShoveCount[3] = g_cvShoveCount[3].FloatValue;
	g_fShoveCount[4] = g_cvShoveCount[4].FloatValue;
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "pistol_clip"))
		FormatEx(result, maxlen, "%T", "手枪弹匣", client, level);
	else if(!strcmp(name, "pistol_ammo"))
		FormatEx(result, maxlen, "%T", "手枪备弹", client, level);
	else if(!strcmp(name, "pistol_fire"))
		FormatEx(result, maxlen, "%T", "手枪射速", client, level);
	else if(!strcmp(name, "pistol_reload"))
		FormatEx(result, maxlen, "%T", "手枪装速", client, level);
	else if(!strcmp(name, "pistol_recoil"))
		FormatEx(result, maxlen, "%T", "手枪后座", client, level);
	
	else if(!strcmp(name, "shotgun_clip"))
		FormatEx(result, maxlen, "%T", "霰弹枪弹匣", client, level);
	else if(!strcmp(name, "shotgun_ammo"))
		FormatEx(result, maxlen, "%T", "霰弹枪备弹", client, level);
	else if(!strcmp(name, "shotgun_fire"))
		FormatEx(result, maxlen, "%T", "霰弹枪射速", client, level);
	else if(!strcmp(name, "shotgun_reload"))
		FormatEx(result, maxlen, "%T", "霰弹枪装速", client, level);
	else if(!strcmp(name, "shotgun_recoil"))
		FormatEx(result, maxlen, "%T", "霰弹枪后座", client, level);
	
	else if(!strcmp(name, "rifle_clip"))
		FormatEx(result, maxlen, "%T", "步枪弹匣", client, level);
	else if(!strcmp(name, "rifle_ammo"))
		FormatEx(result, maxlen, "%T", "步枪备弹", client, level);
	else if(!strcmp(name, "rifle_fire"))
		FormatEx(result, maxlen, "%T", "步枪射速", client, level);
	else if(!strcmp(name, "rifle_reload"))
		FormatEx(result, maxlen, "%T", "步枪装速", client, level);
	else if(!strcmp(name, "rifle_keep"))
		FormatEx(result, maxlen, "%T", "步枪中断", client, level);
	else if(!strcmp(name, "rifle_recoil"))
		FormatEx(result, maxlen, "%T", "步枪后座", client, level);
	
	else if(!strcmp(name, "sniper_clip"))
		FormatEx(result, maxlen, "%T", "狙击枪弹匣", client, level);
	else if(!strcmp(name, "sniper_ammo"))
		FormatEx(result, maxlen, "%T", "狙击枪备弹", client, level);
	else if(!strcmp(name, "sniper_fire"))
		FormatEx(result, maxlen, "%T", "狙击枪射速", client, level);
	else if(!strcmp(name, "sniper_reload"))
		FormatEx(result, maxlen, "%T", "狙击枪装速", client, level);
	else if(!strcmp(name, "sniper_keep"))
		FormatEx(result, maxlen, "%T", "狙击枪中断", client, level);
	else if(!strcmp(name, "sniper_recoil"))
		FormatEx(result, maxlen, "%T", "狙击枪后座", client, level);
	
	else if(!strcmp(name, "melee_range"))
		FormatEx(result, maxlen, "%T", "近战范围", client, level);
	else if(!strcmp(name, "melee_fire"))
		FormatEx(result, maxlen, "%T", "近战攻速", client, level);
	else if(!strcmp(name, "shove_range"))
		FormatEx(result, maxlen, "%T", "推范围", client, level);
	else if(!strcmp(name, "shove_count"))
		FormatEx(result, maxlen, "%T", "推次数", client, level);
	else if(!strcmp(name, "shove_charger"))
		FormatEx(result, maxlen, "%T", "推牛", client, level);
	
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "pistol_clip"))
		FormatEx(result, maxlen, "%T", tr("手枪弹匣%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fPistolClip[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "pistol_ammo"))
		FormatEx(result, maxlen, "%T", tr("手枪备弹%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fPistolAmmo[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "pistol_fire"))
		FormatEx(result, maxlen, "%T", tr("手枪射速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fPistolShot[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "pistol_reload"))
		FormatEx(result, maxlen, "%T", tr("手枪装速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fPistolReload[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "pistol_recoil"))
		FormatEx(result, maxlen, "%T", tr("手枪后座%d", IntBound(level, 1, 1)), client, level);
	
	else if(!strcmp(name, "shotgun_clip"))
		FormatEx(result, maxlen, "%T", tr("霰弹枪弹匣%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShotgunClip[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shotgun_ammo"))
		FormatEx(result, maxlen, "%T", tr("霰弹枪备弹%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShotgunAmmo[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shotgun_fire"))
		FormatEx(result, maxlen, "%T", tr("霰弹枪射速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShotgunShot[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shotgun_reload"))
		FormatEx(result, maxlen, "%T", tr("霰弹枪装速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShotgunReload[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shotgun_recoil"))
		FormatEx(result, maxlen, "%T", tr("霰弹枪后座%d", IntBound(level, 1, 2)), client, level);
	
	else if(!strcmp(name, "rifle_clip"))
		FormatEx(result, maxlen, "%T", tr("步枪弹匣%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fRifleClip[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "rifle_ammo"))
		FormatEx(result, maxlen, "%T", tr("步枪备弹%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fRifleAmmo[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "rifle_fire"))
		FormatEx(result, maxlen, "%T", tr("步枪射速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fRifleShot[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "rifle_reload"))
		FormatEx(result, maxlen, "%T", tr("步枪装速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fRifleReload[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "rifle_keep"))
		FormatEx(result, maxlen, "%T", tr("步枪中断%d", IntBound(level, 1, 1)), client, level);
	else if(!strcmp(name, "rifle_recoil"))
		FormatEx(result, maxlen, "%T", tr("步枪后座%d", IntBound(level, 1, 2)), client, level);
	
	else if(!strcmp(name, "sniper_clip"))
		FormatEx(result, maxlen, "%T", tr("狙击枪弹匣%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fSniperClip[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "sniper_ammo"))
		FormatEx(result, maxlen, "%T", tr("狙击枪备弹%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fSniperAmmo[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "sniper_fire"))
		FormatEx(result, maxlen, "%T", tr("狙击枪射速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fSniperShot[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "sniper_reload"))
		FormatEx(result, maxlen, "%T", tr("狙击枪装速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fSniperReload[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "sniper_keep"))
		FormatEx(result, maxlen, "%T", tr("狙击枪中断%d", IntBound(level, 1, 1)), client, level);
	else if(!strcmp(name, "sniper_recoil"))
		FormatEx(result, maxlen, "%T", tr("狙击枪后座%d", IntBound(level, 1, 2)), client, level);
	
	else if(!strcmp(name, "melee_range"))
		FormatEx(result, maxlen, "%T", tr("近战范围%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fMeleeRange[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "melee_fire"))
		FormatEx(result, maxlen, "%T", tr("近战攻速%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fMeleeSwing[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shove_range"))
		FormatEx(result, maxlen, "%T", tr("推范围%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShoveRange[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shove_count"))
		FormatEx(result, maxlen, "%T", tr("推次数%d", IntBound(level, 1, g_iMaxLevel)), client, level, g_fShoveCount[IntBound(level, 1, g_iMaxLevel)] * 100 - 100);
	else if(!strcmp(name, "shove_charger"))
		FormatEx(result, maxlen, "%T", tr("推牛%d", IntBound(level, 1, 1)), client, level);
	
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

int g_iLevelPistolClip[MAXPLAYERS+1], g_iLevelPistolAmmo[MAXPLAYERS+1], g_iLevelPistolShot[MAXPLAYERS+1], g_iLevelPistolReload[MAXPLAYERS+1],
	g_iLevelShotgunClip[MAXPLAYERS+1], g_iLevelShotgunAmmo[MAXPLAYERS+1], g_iLevelShotgunShot[MAXPLAYERS+1], g_iLevelShotgunReload[MAXPLAYERS+1],
	g_iLevelRifleClip[MAXPLAYERS+1], g_iLevelRifleAmmo[MAXPLAYERS+1], g_iLevelRifleShot[MAXPLAYERS+1], g_iLevelRifleReload[MAXPLAYERS+1],
	g_iLevelSniperClip[MAXPLAYERS+1], g_iLevelSniperAmmo[MAXPLAYERS+1], g_iLevelSniperShot[MAXPLAYERS+1], g_iLevelSniperReload[MAXPLAYERS+1],
	g_iLevelMeleeRange[MAXPLAYERS+1], g_iLevelMeleeSwing[MAXPLAYERS+1], g_iLevelShoveRange[MAXPLAYERS+1], g_iLevelShoveCount[MAXPLAYERS+1],
	g_iLevelRifleKeep[MAXPLAYERS+1], g_iLevelSniperKeep[MAXPLAYERS+1], g_iLevelShoveCharger[MAXPLAYERS+1],
	g_iLevelPistolRecoil[MAXPLAYERS+1], g_iLevelShotgunRecoil[MAXPLAYERS+1], g_iLevelRifleRecoil[MAXPLAYERS+1], g_iLevelSniperRecoil[MAXPLAYERS+1];

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "pistol_clip"))
		g_iLevelPistolClip[client] = level;
	else if(!strcmp(perk, "pistol_ammo"))
		g_iLevelPistolAmmo[client] = level;
	else if(!strcmp(perk, "pistol_fire"))
		g_iLevelPistolShot[client] = level;
	else if(!strcmp(perk, "pistol_reload"))
		g_iLevelPistolReload[client] = level;
	else if(!strcmp(perk, "pistol_recoil"))
		g_iLevelPistolRecoil[client] = level;
	
	if(!strcmp(perk, "shotgun_clip"))
		g_iLevelShotgunClip[client] = level;
	else if(!strcmp(perk, "shotgun_ammo"))
		g_iLevelShotgunAmmo[client] = level;
	else if(!strcmp(perk, "shotgun_fire"))
		g_iLevelShotgunShot[client] = level;
	else if(!strcmp(perk, "shotgun_reload"))
		g_iLevelShotgunReload[client] = level;
	else if(!strcmp(perk, "shotgun_recoil"))
		g_iLevelShotgunRecoil[client] = level;
	
	if(!strcmp(perk, "rifle_clip"))
		g_iLevelRifleClip[client] = level;
	else if(!strcmp(perk, "rifle_ammo"))
		g_iLevelRifleAmmo[client] = level;
	else if(!strcmp(perk, "rifle_fire"))
		g_iLevelRifleShot[client] = level;
	else if(!strcmp(perk, "rifle_reload"))
		g_iLevelRifleReload[client] = level;
	else if(!strcmp(perk, "rifle_keep"))
		g_iLevelRifleKeep[client] = level;
	else if(!strcmp(perk, "rifle_recoil"))
		g_iLevelRifleRecoil[client] = level;
	
	if(!strcmp(perk, "sniper_clip"))
		g_iLevelSniperClip[client] = level;
	else if(!strcmp(perk, "sniper_ammo"))
		g_iLevelSniperAmmo[client] = level;
	else if(!strcmp(perk, "sniper_fire"))
		g_iLevelSniperShot[client] = level;
	else if(!strcmp(perk, "sniper_reload"))
		g_iLevelSniperReload[client] = level;
	else if(!strcmp(perk, "sniper_keep"))
		g_iLevelSniperKeep[client] = level;
	else if(!strcmp(perk, "sniper_recoil"))
		g_iLevelSniperRecoil[client] = level;
	
	if(!strcmp(perk, "melee_range"))
		g_iLevelMeleeRange[client] = level;
	else if(!strcmp(perk, "melee_fire"))
		g_iLevelMeleeSwing[client] = level;
	else if(!strcmp(perk, "shove_range"))
		g_iLevelShoveRange[client] = level;
	else if(!strcmp(perk, "shove_count"))
		g_iLevelShoveCount[client] = level;
	else if(!strcmp(perk, "shove_charger"))
		g_iLevelShoveCharger[client] = level;
}

#define IsSurvivorHeld(%1)		(GetEntPropEnt(%1, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(%1, Prop_Send, "m_carryAttacker") > 0)
int g_iExtraAmmo[MAXPLAYERS+1], g_iExtraPrimaryAmmo[MAXPLAYERS+1], g_iPreClip[MAXPLAYERS+1], g_iPreUpgrade[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || IsSurvivorHeld(client))
		return Plugin_Continue;
	
	Action result = Plugin_Continue;
	
	if(buttons & IN_RELOAD)
	{
		int weaponId = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weaponId > MaxClients && IsValidEdict(weaponId))
		{
			static char classname[64];
			GetEdictClassname(weaponId, classname, sizeof(classname));
			
			int clip = GetEntProp(weaponId, Prop_Send, "m_iClip1");
			int clipSize = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
			int maxClipSize = GetPlayerClipSize(client, classname);
			
			if(clip >= maxClipSize)
			{
				buttons &= ~IN_RELOAD;
				result = Plugin_Changed;
			}
			else if(!(buttons & IN_ATTACK) && !GetEntProp(weaponId, Prop_Send, "m_bInReload", 1))
			{
				if(clip >= clipSize && clip < maxClipSize && IsShotgun(classname))
				{
					// 等待触发填装时还原
					g_iPreClip[client] = clip;
					
					// 霰弹弹药超上限时无法进行填充，此处强制进入填充装填
					SetEntProp(weaponId, Prop_Send, "m_iClip1", 0);
					
					// 启动填装失败的还原措施
					DataPack dp = CreateDataPack();
					CreateTimer(0.2, Timer_ResetWeaponClip, dp);
					dp.WriteCell(client);
					dp.WriteCell(weaponId);
					dp.WriteCell(clip);
				}
				else if(clip > 0 && ((g_iLevelSniperKeep[client] >= 1 && IsSniper(classname)) || (g_iLevelRifleKeep[client] >= 1 && IsRifle(classname))))
				{
					// 保留弹匣
					g_iPreClip[client] = clip;
				}
			}
		}
	}
	
	if(buttons & IN_USE)
	{
		int weaponId = GetPlayerWeaponSlot(client, 0);
		if(weaponId > MaxClients && IsValidEdict(weaponId))
		{
			int useTarget = GetClientAimTarget(client, false);
			if(useTarget <= MaxClients || !IsValidEdict(useTarget))
				useTarget = FindUseEntity(client);
			
			if(useTarget > MaxClients && IsValidEdict(useTarget))
			{
				static ConVar cv_usedst;
				if(cv_usedst == null)
					cv_usedst = FindConVar("player_use_radius");
				
				float origin[3], position[3];
				GetClientEyePosition(client, origin);
				GetEntPropVector(useTarget, Prop_Send, "m_vecOrigin", position);
				
				if(GetVectorDistance(origin, position, true) <= Pow(cv_usedst.FloatValue, 2.0))
				{
					static char classname[64], targetname[64];
					GetEdictClassname(weaponId, classname, sizeof(classname));
					GetEdictClassname(useTarget, targetname, sizeof(targetname));
					
					bool isAmmo = (!strcmp(targetname, "weapon_ammo_spawn", false) || !strcmp(targetname, "weapon_ammo_pack", false));
					bool isSpawnner = (StrContains(targetname, classname, false) == 0 && StrContains(targetname, "_spawn", false) > 0);
					if(HasEntProp(useTarget, Prop_Send, "m_weaponID") && GetEntProp(useTarget, Prop_Send, "m_weaponID") == L4D2_GetWeaponId(classname))
						isSpawnner = true;
					
					if(isAmmo || isSpawnner)
					{
						DataPack data = CreateDataPack();
						data.WriteCell(client);
						data.WriteString(classname);
						data.WriteCell(isSpawnner);
						
						// AddAmmo(client, 999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
						RequestFrame(UpdateWeaponAmmo, data);
					}
					else if(!strcmp(targetname, "upgrade_ammo_explosive", false) || !strcmp(targetname, "upgrade_ammo_incendiary", false))
					{
						int flags = GetEntProp(weaponId, Prop_Send, "m_upgradeBitVec");
						int ammo = GetEntProp(weaponId, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
						g_iPreUpgrade[client] = (flags << 16) | ammo;
					}
				}
			}
		}
	}
	
	return result;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelPistolClip[client] = L4D2SF_GetClientPerk(client, "pistol_clip");
	g_iLevelPistolAmmo[client] = L4D2SF_GetClientPerk(client, "pistol_ammo");
	g_iLevelPistolShot[client] = L4D2SF_GetClientPerk(client, "pistol_fire");
	g_iLevelPistolReload[client] = L4D2SF_GetClientPerk(client, "pistol_reload");
	g_iLevelPistolRecoil[client] = L4D2SF_GetClientPerk(client, "pistol_recoil");
	g_iLevelShotgunClip[client] = L4D2SF_GetClientPerk(client, "shotgun_clip");
	g_iLevelShotgunAmmo[client] = L4D2SF_GetClientPerk(client, "shotgun_ammo");
	g_iLevelShotgunShot[client] = L4D2SF_GetClientPerk(client, "shotgun_fire");
	g_iLevelShotgunReload[client] = L4D2SF_GetClientPerk(client, "shotgun_reload");
	g_iLevelShotgunRecoil[client] = L4D2SF_GetClientPerk(client, "shotgun_recoil");
	g_iLevelRifleClip[client] = L4D2SF_GetClientPerk(client, "rifle_clip");
	g_iLevelRifleAmmo[client] = L4D2SF_GetClientPerk(client, "rifle_ammo");
	g_iLevelRifleShot[client] = L4D2SF_GetClientPerk(client, "rifle_fire");
	g_iLevelRifleReload[client] = L4D2SF_GetClientPerk(client, "rifle_reload");
	g_iLevelRifleKeep[client] = L4D2SF_GetClientPerk(client, "rifle_keep");
	g_iLevelRifleRecoil[client] = L4D2SF_GetClientPerk(client, "rifle_recoil");
	g_iLevelSniperClip[client] = L4D2SF_GetClientPerk(client, "sniper_clip");
	g_iLevelSniperAmmo[client] = L4D2SF_GetClientPerk(client, "sniper_ammo");
	g_iLevelSniperShot[client] = L4D2SF_GetClientPerk(client, "sniper_fire");
	g_iLevelSniperReload[client] = L4D2SF_GetClientPerk(client, "sniper_reload");
	g_iLevelSniperKeep[client] = L4D2SF_GetClientPerk(client, "sniper_keep");
	g_iLevelSniperRecoil[client] = L4D2SF_GetClientPerk(client, "sniper_recoil");
	g_iLevelMeleeRange[client] = L4D2SF_GetClientPerk(client, "melee_range");
	g_iLevelMeleeSwing[client] = L4D2SF_GetClientPerk(client, "melee_fire");
	g_iLevelShoveRange[client] = L4D2SF_GetClientPerk(client, "shove_range");
	g_iLevelShoveCount[client] = L4D2SF_GetClientPerk(client, "shove_count");
	g_iLevelShoveCharger[client] = L4D2SF_GetClientPerk(client, "shove_charger");
	
	SDKHook(client, SDKHook_PostThinkPost, EntHook_PlayerPostThinkPost);
	SDKHook(client, SDKHook_WeaponCanUse, EntHook_PlayerCanUse);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SDKUnhook(client, SDKHook_PostThinkPost, EntHook_PlayerPostThinkPost);
	SDKUnhook(client, SDKHook_WeaponCanUse, EntHook_PlayerCanUse);
}

/*
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
	
	
}
*/

public void Event_WeaponReload(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon))
		return;
	
	char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname)))
		return;
	
	if(g_iPreClip[client] > 0 && (
		(g_iLevelSniperKeep[client] >= 1 && IsSniper(classname)) ||
		(g_iLevelRifleKeep[client] >= 1 && IsRifle(classname)) ||
		IsShotgun(classname)))
	{
		// 现在已经进入填装状态，进行还原弹匣
		SetEntProp(weapon, Prop_Send, "m_iClip1", g_iPreClip[client]);
		g_iPreClip[client] = 0;
	}
	
	if(g_iExtraAmmo[client] > 0 && weapon == GetPlayerWeaponSlot(client, 0))
	{
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
		int amount = g_iMaxAmmo - ammo - clip - L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize) + 1;
		if(amount > g_iExtraAmmo[client])
			amount = g_iExtraAmmo[client];
		
		g_iExtraAmmo[client] -= amount;
		SetEntProp(client, Prop_Send, "m_iAmmo", ammo + amount, _, ammoType);
		PrintCenterText(client, "%T", "备弹剩余", client, g_iExtraAmmo[client]);
	}
	
	if((g_iLevelPistolClip[client] > 0 && IsPistol(classname)) ||
		(g_iLevelSniperClip[client] > 0 && IsSniper(classname)) ||
		(g_iLevelRifleClip[client] > 0 && IsRifle(classname)) ||
		(g_iLevelShotgunClip[client] > 0 && IsShotgun(classname)))
	{
		// SDKHook(weapon, SDKHook_ThinkPost, EntHook_WpnThinkPost);
		SDKHook(client, SDKHook_PreThinkPost, EntHook_PlayerPreThinkPost);
		SDKHook(client, SDKHook_WeaponSwitchPost, EntHook_PlayerSwitchWeaponPost);
		
		if(IsShotgun(classname))
		{
			DataPack data = CreateDataPack();
			data.WriteCell(client);
			data.WriteCell(weapon);
			RequestFrame(SetInsertShells, data);
		}
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
		StrContains(classname, "pistol", false) != -1)
	{
		DataPack data = CreateDataPack();
		data.WriteCell(client);
		data.WriteString(classname);
		data.WriteCell(true);
		
		// 捡起固定刷武器和插件给的武器只会触发 item_pickup，不会触发 player_use
		RequestFrame(UpdateWeaponAmmo, data);
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
	
	if(StrContains(classname, "shotgun", false) != -1 || StrContains(classname, "smg", false) != -1 ||
		StrContains(classname, "rifle", false) != -1 || StrContains(classname, "sniper", false) != -1 ||
		StrContains(classname, "launcher", false) != -1)
	{
		int maxAmmo = GetDefaultAmmo(item);
		if(maxAmmo > -1 && HasEntProp(item, Prop_Send, "m_upgradeBitVec") && g_iExtraPrimaryAmmo[client] > 0)
		{
			g_iExtraAmmo[client] = g_iExtraPrimaryAmmo[client] - maxAmmo;
			if(g_iExtraAmmo[client] < 0)
				g_iExtraAmmo[client] = 0;
			
			RequestFrame(UpdateAmmo, client);
		}
		else
		{
			g_iExtraAmmo[client] = 0;
		}
	}
	
	if(HasEntProp(item, Prop_Send, "m_upgradeBitVec") && (
		(g_iLevelPistolRecoil[client] >= 2 && IsPistol(classname)) ||
		(g_iLevelSniperRecoil[client] >= 2 && IsSniper(classname)) ||
		(g_iLevelShotgunRecoil[client] >= 2 && IsShotgun(classname)) ||
		(g_iLevelRifleRecoil[client] >= 2 && IsRifle(classname))))
	{
		int flags = GetEntProp(item, Prop_Send, "m_upgradeBitVec");
		SetEntProp(item, Prop_Send, "m_upgradeBitVec", flags | 4);
	}
	
	// PrintToChat(client, "player_use");
}

public void Event_WeaponDropped(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	int weapon = event.GetInt("propid");
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return;
	
	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	
	if(HasEntProp(weapon, Prop_Send, "m_upgradeBitVec") && (
		(g_iLevelPistolRecoil[client] >= 2 && IsPistol(classname)) ||
		(g_iLevelSniperRecoil[client] >= 2 && IsSniper(classname)) ||
		(g_iLevelShotgunRecoil[client] >= 2 && IsShotgun(classname)) ||
		(g_iLevelRifleRecoil[client] >= 2 && IsRifle(classname))))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags & ~4);
	}
	
	if(g_iExtraAmmo[client] > 0 &&
		(StrContains(classname, "smg", false) != -1 || StrContains(classname, "rifle", false) != -1 ||
		StrContains(classname, "sniper", false) != -1 || StrContains(classname, "shotgun", false) != -1 ||
		StrContains(classname, "launcher", false) != -1))
	{
		DataPack data = CreateDataPack();
		data.WriteCell(weapon);
		data.WriteCell(g_iExtraAmmo[client]);
		RequestFrame(PatchExtraPrimaryAmmo, data);
	}
}

public void Event_UpgradePickup(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int upgradePack = event.GetInt("upgradeid");
	if(!IsValidAliveClient(client) || upgradePack < MaxClients || !IsValidEntity(upgradePack))
		return;
	
	char upgradeName[64];
	GetEntityClassname(upgradePack, upgradeName, sizeof(upgradeName));
	if(!StrEqual(upgradeName, "upgrade_ammo_incendiary", false) &&
		!StrEqual(upgradeName, "upgrade_ammo_explosive", false))
		return;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon < MaxClients || !IsValidEntity(weapon))
		return;
	
	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	int clipSize = GetPlayerClipSize(client, classname);
	SetEntProp(weapon, Prop_Send, "m_iClip1", clipSize);
	SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clipSize);
}

public Action EntHook_PlayerCanUse(int client, int weapon)
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

public void EntHook_PlayerPostThinkPost(int client)
{
	if(!IsValidAliveClient(client))
	{
		SDKUnhook(client, SDKHook_PostThinkPost, EntHook_PlayerPostThinkPost);
		return;
	}
	
	if(!(GetClientButtons(client) & IN_ATTACK) || GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) ||
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || IsSurvivorHeld(client))
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEdict(weapon))
		return;
	
	static char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname)))
		return;
	
	if((g_iLevelPistolRecoil[client] > 0 && IsPistol(classname)) ||
		(g_iLevelSniperRecoil[client] > 0 && IsSniper(classname)) ||
		(g_iLevelRifleRecoil[client] > 0 && IsRifle(classname)) ||
		(g_iLevelShotgunRecoil[client] > 0 && IsShotgun(classname)))
	{
		SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", Float:{0.0, 0.0, 0.0});
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", Float:{0.0, 0.0, 0.0});
	}
}

public void EntHook_PlayerSwitchWeaponPost(int client, int weapon)
{
	SDKUnhook(client, SDKHook_PreThinkPost, EntHook_PlayerPreThinkPost);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, EntHook_PlayerSwitchWeaponPost);
}

// public void EntHook_WpnThinkPost(int weapon)
public void EntHook_PlayerPreThinkPost(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidClient(client) || !IsValidEdict(weapon))
	{
		SDKUnhook(client, SDKHook_PreThinkPost, EntHook_PlayerPreThinkPost);
		SDKUnhook(client, SDKHook_WeaponSwitchPost, EntHook_PlayerSwitchWeaponPost);
		return;
	}
	
	// 等待直到完成
	if(GetEntProp(weapon, Prop_Send, "m_bInReload") || (HasEntProp(weapon, Prop_Send, "m_reloadState") && GetEntProp(weapon, Prop_Send, "m_reloadState")))
		return;
	
	SDKUnhook(client, SDKHook_PreThinkPost, EntHook_PlayerPreThinkPost);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, EntHook_PlayerSwitchWeaponPost);
	
	if(HasEntProp(weapon, Prop_Send, "m_reloadNumShells"))
	{
		float time = GetGameTime();
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", time);
		SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", time);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time);
	}
	else
	{
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		
		char classname[64];
		GetEdictClassname(weapon, classname, sizeof(classname));
		
		// 检查是否真的完成了（未被中断）
		if(ammo == 0 || clip == L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize))
		{
			int newClip = 0;
			if(g_iLevelPistolClip[client] > 0 && IsPistol(classname))
				newClip = RoundFloat(clip * g_fPistolClip[IntBound(g_iLevelPistolClip[client], 1, g_iMaxLevel)]);
			else if(g_iLevelSniperClip[client] > 0 && IsSniper(classname))
				newClip = RoundFloat(clip * g_fSniperClip[IntBound(g_iLevelSniperClip[client], 1, g_iMaxLevel)]);
			else if(g_iLevelRifleClip[client] > 0 && IsRifle(classname))
				newClip = RoundFloat(clip * g_fRifleClip[IntBound(g_iLevelRifleClip[client], 1, g_iMaxLevel)]);
			
			int diff = newClip - clip;
			if(diff > ammo)
			{
				diff = ammo;
				newClip = clip + diff;
			}
			
			if(newClip > 0 && diff > 0 && newClip > clip)
			{
				ammo -= diff;
				SetEntProp(weapon, Prop_Send, "m_iClip1", newClip);
				SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammoType);
			}
		}
	}
}

void SetInsertShells(any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	int client = data.ReadCell();
	int weapon = data.ReadCell();
	if(!IsValidClient(client) || GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)
		return;
	
	if(!GetEntProp(weapon, Prop_Send, "m_bInReload") && (HasEntProp(weapon, Prop_Send, "m_reloadState") || !GetEntProp(weapon, Prop_Send, "m_reloadState")))
		return;
	
	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
	int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
	int maxClip = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
	
	int newClip = 0;
	if(g_iLevelShotgunClip[client] > 0 && IsShotgun(classname))
		newClip = RoundFloat(maxClip * g_fShotgunClip[IntBound(g_iLevelShotgunClip[client], 1, 4)]);
	
	if(newClip > 0 && newClip > maxClip)
	{
		int insert = newClip - clip;
		if(insert > ammo)
			insert = ammo;
		if(insert > 0)
			SetEntProp(weapon, Prop_Send, "m_reloadNumShells", insert);
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
		int maxClip = GetPlayerClipSize(client, classname);
		if(maxClip > 0)
			SetEntProp(weapon, Prop_Send, "m_iClip1", maxClip);
	}
	
	AddAmmo(client, 999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
	
	if(HasEntProp(weapon, Prop_Send, "m_upgradeBitVec") && (
		(g_iLevelPistolRecoil[client] >= 2 && IsPistol(classname)) ||
		(g_iLevelSniperRecoil[client] >= 2 && IsSniper(classname)) ||
		(g_iLevelShotgunRecoil[client] >= 2 && IsShotgun(classname)) ||
		(g_iLevelRifleRecoil[client] >= 2 && IsRifle(classname))))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | 4);
	}
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	if(g_iLevelMeleeSwing[client] > 0)
	{
		speedmodifier *= g_fMeleeSwing[IntBound(g_iLevelMeleeSwing[client], 1, 4)];
	}
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iLevelPistolReload[client] > 0 && (weapontype == L4D2WeaponType_Pistol || weapontype == L4D2WeaponType_Magnum))
	{
		speedmodifier *= g_fPistolReload[IntBound(g_iLevelPistolReload[client], 1, 4)];
	}
	else if(g_iLevelShotgunReload[client] > 0 && (weapontype == L4D2WeaponType_Autoshotgun || weapontype == L4D2WeaponType_AutoshotgunSpas ||
		weapontype == L4D2WeaponType_Pumpshotgun || weapontype == L4D2WeaponType_PumpshotgunChrome))
	{
		speedmodifier *= g_fShotgunReload[IntBound(g_iLevelShotgunReload[client], 1, 4)];
	}
	else if(g_iLevelSniperReload[client] > 0 && (weapontype == L4D2WeaponType_HuntingRifle || weapontype == L4D2WeaponType_SniperAwp ||
		weapontype == L4D2WeaponType_SniperMilitary || weapontype == L4D2WeaponType_SniperScout))
	{
		speedmodifier *= g_fSniperReload[IntBound(g_iLevelSniperReload[client], 1, 4)];
	}
	else if(g_iLevelRifleReload[client] > 0 && (weapontype == L4D2WeaponType_Rifle || weapontype == L4D2WeaponType_RifleAk47 ||
		weapontype == L4D2WeaponType_RifleDesert || weapontype == L4D2WeaponType_RifleM60 || weapontype == L4D2WeaponType_RifleSg552 ||
		weapontype == L4D2WeaponType_SMG || weapontype == L4D2WeaponType_SMGSilenced || weapontype == L4D2WeaponType_SMGMp5))
	{
		speedmodifier *= g_fRifleReload[IntBound(g_iLevelRifleReload[client], 1, 4)];
	}
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iLevelPistolShot[client] > 0 && (weapontype == L4D2WeaponType_Pistol || weapontype == L4D2WeaponType_Magnum))
	{
		speedmodifier *= g_fPistolShot[IntBound(g_iLevelPistolShot[client], 1, 4)];
	}
	else if(g_iLevelShotgunShot[client] > 0 && (weapontype == L4D2WeaponType_Autoshotgun || weapontype == L4D2WeaponType_AutoshotgunSpas ||
		weapontype == L4D2WeaponType_Pumpshotgun || weapontype == L4D2WeaponType_PumpshotgunChrome))
	{
		speedmodifier *= g_fShotgunShot[IntBound(g_iLevelShotgunShot[client], 1, 4)];
	}
	else if(g_iLevelSniperShot[client] > 0 && (weapontype == L4D2WeaponType_HuntingRifle || weapontype == L4D2WeaponType_SniperAwp ||
		weapontype == L4D2WeaponType_SniperMilitary || weapontype == L4D2WeaponType_SniperScout))
	{
		speedmodifier *= g_fSniperShot[IntBound(g_iLevelSniperShot[client], 1, 4)];
	}
	else if(g_iLevelRifleShot[client] > 0 && (weapontype == L4D2WeaponType_Rifle || weapontype == L4D2WeaponType_RifleAk47 ||
		weapontype == L4D2WeaponType_RifleDesert || weapontype == L4D2WeaponType_RifleM60 || weapontype == L4D2WeaponType_RifleSg552 ||
		weapontype == L4D2WeaponType_SMG || weapontype == L4D2WeaponType_SMGSilenced || weapontype == L4D2WeaponType_SMGMp5))
	{
		speedmodifier *= g_fRifleShot[IntBound(g_iLevelRifleShot[client], 1, 4)];
	}
}

int g_iOldMeleeRange = -1, g_iOldShoveRange = -1, g_iOldShoveCharger = -1;

public MRESReturn TestMeleeSwingCollisionPre(int pThis, Handle hReturn)
{
	if( IsValidEntity(pThis) )
	{
		int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
		if( IsValidAliveClient(owner) && g_iLevelMeleeRange[owner] > 0 )
		{
			g_iOldMeleeRange = g_hCvarMeleeRange.IntValue;
			g_hCvarMeleeRange.IntValue = RoundFloat(g_iOldMeleeRange * g_fMeleeRange[IntBound(g_iLevelMeleeRange[owner], 1, 4)]);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn TestMeleeSwingCollisionPost(int pThis, Handle hReturn)
{
	if( g_iOldMeleeRange >= -1 )
	{
		g_hCvarMeleeRange.IntValue = g_iOldMeleeRange;
		g_iOldMeleeRange = -1;
	}
	
	return MRES_Ignored;
}

public MRESReturn TestSwingCollisionPre(int pThis, Handle hReturn)
{
	if( IsValidEntity(pThis) )
	{
		int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
		if( IsValidAliveClient(owner) )
		{
			if(g_iLevelShoveRange[owner] > 0)
			{
				g_iOldShoveRange = g_hCvarShovRange.IntValue;
				g_hCvarShovRange.IntValue = RoundFloat(g_iOldShoveRange * g_fShoveRange[IntBound(g_iLevelShoveRange[owner], 1, 4)]);
			}
			
			if(g_iLevelShoveCharger[owner] > 0)
			{
				g_iOldShoveCharger = g_hCvarChargerShove.IntValue;
				g_hCvarChargerShove.IntValue = 1;
			}
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn TestSwingCollisionPost(int pThis, Handle hReturn)
{
	if( g_iOldShoveRange > -1 )
	{
		g_hCvarShovRange.IntValue = g_iOldShoveRange;
		g_iOldShoveRange = -1;
	}
	
	if(g_iOldShoveCharger > -1)
	{
		g_hCvarChargerShove.IntValue = g_iOldShoveCharger;
		g_iOldShoveCharger = -1;
	}
	
	return MRES_Ignored;
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

bool IsShotgun(const char[] weapon)
{
	return StrContains(weapon, "shotgun") > -1;
}

bool IsRifle(const char[] weapon, bool withSMG = true)
{
	if(StrContains(weapon, "rifle") > -1 && StrContains(weapon, "hunting") == -1)
		return true;
	
	return withSMG && StrContains(weapon, "smg") > -1;
}

bool IsPistol(const char[] weapon)
{
	return StrContains(weapon, "pistol") > -1;
}

bool IsSniper(const char[] weapon)
{
	return StrContains(weapon, "sniper") > -1 || !strcmp(weapon, "weapon_hunting_rifle");
}

bool IsMelee(const char[] weapon)
{
	return StrContains(weapon, "melee") > -1;
}

bool AddAmmo(int client, int amount, int ammoType = -1, bool limit = true)
{
	if(!IsValidAliveClient(client))
		return false;
	
	int maxAmmo = -1;
	int primary = GetPlayerWeaponSlot(client, 0);
	
	char classname[64];
	if(primary > MaxClients && IsValidEntity(primary))
	{
		GetEdictClassname(primary, classname, sizeof(classname));
		if(ammoType <= -1)
			ammoType = GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType");
	}
	
	if(limit)
	{
		maxAmmo = GetDefaultAmmo(primary, ammoType);
		if(maxAmmo < 0)
			return false;
		
		if(g_iLevelPistolAmmo[client] > 0 && IsPistol(classname))
			maxAmmo = RoundFloat(maxAmmo * g_fPistolAmmo[IntBound(g_iLevelPistolAmmo[client], 1, g_iMaxLevel)]);
		else if(g_iLevelSniperAmmo[client] > 0 && IsSniper(classname))
			maxAmmo = RoundFloat(maxAmmo * g_fSniperAmmo[IntBound(g_iLevelSniperAmmo[client], 1, g_iMaxLevel)]);
		else if(g_iLevelShotgunAmmo[client] > 0 && IsShotgun(classname))
			maxAmmo = RoundFloat(maxAmmo * g_fShotgunAmmo[IntBound(g_iLevelShotgunAmmo[client], 1, 4)]);
		else if(g_iLevelRifleAmmo[client] > 0 && IsRifle(classname))
			maxAmmo = RoundFloat(maxAmmo * g_fRifleAmmo[IntBound(g_iLevelRifleAmmo[client], 1, g_iMaxLevel)]);
	}
	else
	{
		maxAmmo = g_iMaxAmmo;
	}
	
	int clip = 0, maxClip = 0;
	if(primary > MaxClients && IsValidEntity(primary) &&
		GetEntProp(primary, Prop_Send, "m_iPrimaryAmmoType") == ammoType)
	{
		maxClip = GetPlayerClipSize(client, classname);
		if(maxClip > 0)
		{
			// 主武器
			clip = GetEntProp(primary, Prop_Send, "m_iClip1");
			if(clip > -1)
				maxAmmo += maxClip - clip;
		}
	}
	
	// 实际可用上限，来自于游戏限制
	int available = maxAmmo + maxClip;
	if(available > g_iMaxAmmo)
	{
		available = g_iMaxAmmo - clip;	// 满弹匣时无法填装的，所以这里或许可以+1
	}
	else
	{
		g_iExtraAmmo[client] = 0;
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
	
	// PrintToChat(client, "ammo +%d, ov %d, nv %d, cl %d, ex %d, lim %d, ava %d, mc %d", amount, oldAmmo, newAmmo, clip, g_iExtraAmmo[client], maxAmmo, available, maxClip);
	return (oldAmmo != newAmmo);
}

int GetDefaultAmmo(int weapon, int ammoType = -1)
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

int GetPlayerClipSize(int client, const char[] classname)
{
	int maxClip = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
	if(g_iLevelPistolClip[client] > 0 && IsPistol(classname))
		maxClip = RoundFloat(maxClip * g_fPistolClip[IntBound(g_iLevelPistolClip[client], 1, g_iMaxLevel)]);
	else if(g_iLevelSniperClip[client] > 0 && IsSniper(classname))
		maxClip = RoundFloat(maxClip * g_fSniperClip[IntBound(g_iLevelSniperClip[client], 1, g_iMaxLevel)]);
	else if(g_iLevelShotgunClip[client] > 0 && IsShotgun(classname))
		maxClip = RoundFloat(maxClip * g_fShotgunClip[IntBound(g_iLevelShotgunClip[client], 1, 4)]);
	else if(g_iLevelRifleClip[client] > 0 && IsRifle(classname))
		maxClip = RoundFloat(maxClip * g_fRifleClip[IntBound(g_iLevelRifleClip[client], 1, g_iMaxLevel)]);
	return maxClip;
}

public void UpdateAmmo(any client)
{
	if(IsValidAliveClient(client))
		AddAmmo(client, 0);
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

public Action Timer_ResetWeaponClip(Handle timer, any data)
{
	DataPack dp = view_as<DataPack>(data);
	dp.Reset();
	
	int client = dp.ReadCell();
	int weapon = dp.ReadCell();
	int clip = dp.ReadCell();
	
	if(IsValidEdict(weapon) && GetEntProp(weapon, Prop_Send, "m_iClip1") == 0)
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	
	g_iPreClip[client] = 0;
	return Plugin_Continue;
}

int FindUseEntity(int client, float radius = 0.0)
{
	if(g_pfnFindUseEntity == null)
		return -1;
	
	static ConVar cvUseRadius;
	if(cvUseRadius == null)
		cvUseRadius = FindConVar("player_use_radius");
	
	return SDKCall(g_pfnFindUseEntity, client, (radius > 0.0 ? radius : cvUseRadius.FloatValue), 0.0, 0.0, 0, false);
}
