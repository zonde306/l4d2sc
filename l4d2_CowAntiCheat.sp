/*	[CS:GO] CowAntiCheat Plugin - Burn the cheaters!
 *
 *	Copyright (C) 2018 Eric Edson // ericedson.me // thefraggingcow@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#define PLUGIN_AUTHOR "CodingCow, zonde306"
#define PLUGIN_VERSION "1.15"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
// #include <autoexecconfig>
#include <SteamWorks>
// #undef REQUIRE_PLUGIN
// #include <sourcebans>

// #define _USE_DETOUR_FUNC_		// 使用 hook 油桶

#if defined _USE_DETOUR_FUNC_
#include <dhooks>
#endif	// _USE_DETOUR_FUNC_

#pragma newdecls required

public Plugin myinfo =
{
	name = "反作弊",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

// bool sourcebans = false;

#define JUMP_HISTORY 30
#define MAX_TICK_DETECTION 30

int g_iCmdNum[MAXPLAYERS + 1];
int g_iAimbotCount[MAXPLAYERS + 1];
int g_iLastHitGroup[MAXPLAYERS + 1];
bool g_bAngleSet[MAXPLAYERS + 1];
float prev_angles[MAXPLAYERS + 1][3];
int g_iPerfectBhopCount[MAXPLAYERS + 1];
bool g_bThirdPersonEnabled[MAXPLAYERS + 1];
int g_iTicksOnGround[MAXPLAYERS + 1];
int g_iLastJumps[MAXPLAYERS + 1][JUMP_HISTORY];
int g_iLastJumpIndex[MAXPLAYERS + 1];
int g_iJumpsSent[MAXPLAYERS + 1][JUMP_HISTORY];
int g_iJumpsSentIndex[MAXPLAYERS + 1];
int g_iPrev_TicksOnGround[MAXPLAYERS + 1];
float prev_sidemove[MAXPLAYERS + 1];
int g_iPerfSidemove[MAXPLAYERS + 1];
int prev_buttons[MAXPLAYERS + 1];
bool g_bShootSpam[MAXPLAYERS + 1];
int g_iLastShotTick[MAXPLAYERS + 1];
bool g_bFirstShot[MAXPLAYERS + 1];
int g_iAutoShoot[MAXPLAYERS + 1];
int g_iTriggerBotCount[MAXPLAYERS + 1];
int g_iTicksOnPlayer[MAXPLAYERS + 1];
int g_iPrev_TicksOnPlayer[MAXPLAYERS + 1];
int g_iMacroCount[MAXPLAYERS + 1];
int g_iMacroDetectionCount[MAXPLAYERS + 1];
float g_fJumpStart[MAXPLAYERS + 1];
float g_fDefuseTime[MAXPLAYERS+1];
int g_iWallTrace[MAXPLAYERS + 1];
int g_iStrafeCount[MAXPLAYERS + 1];
bool turnRight[MAXPLAYERS + 1];
int g_iTickCount[MAXPLAYERS + 1];
int prev_mousedx[MAXPLAYERS + 1];
int g_iAHKStrafeDetection[MAXPLAYERS + 1];
int g_iMousedx_Value[MAXPLAYERS + 1];
int g_iMousedxCount[MAXPLAYERS + 1];
float g_fJumpPos[MAXPLAYERS + 1];
bool prev_OnGround[MAXPLAYERS + 1];
int g_iTickLeft[MAXPLAYERS + 1];
int g_iTickDetecton[MAXPLAYERS + 1];
float g_fTickDetectedTime[MAXPLAYERS + 1];
float g_fPrevLatency[MAXPLAYERS + 1];
int g_iMaxTick = 0;

float g_Sensitivity[MAXPLAYERS + 1];
float g_mYaw[MAXPLAYERS + 1];
Handle g_hTimerQueryTimeout[MAXPLAYERS + 1] = {null, ...};
int g_iQueryTimeout[MAXPLAYERS + 1] = {0, ...};

int g_iSendMoveCalled[MAXPLAYERS+1];
int g_iSendMoveRate[MAXPLAYERS+1];
float g_fSendMoveSecond[MAXPLAYERS+1];
bool g_bHasThirdChecked[MAXPLAYERS+1];
int g_iOffsetVomitTimer = -1;
float g_fVomitFadeTimer[MAXPLAYERS+1];
float g_fReleasedTimer[MAXPLAYERS+1];
float g_fDefibrillatorTimer[MAXPLAYERS+1];
float g_fGrenadeExplodeTimer[MAXPLAYERS+1];
float g_fGasCanTimer[MAXPLAYERS+1];
ArrayList g_aszClientSteamId;

/* Detection Cvars */
ConVar g_ConVar_AutoBhop;
ConVar g_ConVar_MaxCmdRate;
ConVar g_ConVar_MaxUpdateRate;
ConVar g_ConVar_DefibDuration;
ConVar g_ConVar_AimbotEnable;
ConVar g_ConVar_BhopEnable;
ConVar g_ConVar_SilentStrafeEnable;
ConVar g_ConVar_TriggerbotEnable;
ConVar g_ConVar_MacroEnable;
ConVar g_ConVar_AutoShootEnable;
ConVar g_ConVar_InstantDefuseEnable;
ConVar g_ConVar_PerfectStrafeEnable;
ConVar g_ConVar_BacktrackFixEnable;
ConVar g_ConVar_AHKStrafeEnable;
ConVar g_ConVar_HourCheckEnable;
ConVar g_ConVar_HourCheckValue;
ConVar g_ConVar_ProfileCheckEnable;
ConVar g_ConVar_SpeedHackEnable;
ConVar g_ConVar_ThirdESPEnable;
ConVar g_ConVar_BlockSpecialIdle;
ConVar g_ConVar_BlockVomitIdle;
ConVar g_ConVar_BlockGrenadeIdle;
ConVar g_ConVar_VomitDuration;
ConVar g_ConVar_GrenadeDuration;
ConVar g_ConVar_FamilySharing;
ConVar g_ConVar_MatHack;
ConVar g_ConVar_BlockDefibIdle;
ConVar g_ConVar_BlockReleaseIdle;
ConVar g_ConVar_BlockReleaseDuration;
ConVar g_ConVar_BlockGasCanIdle;
ConVar g_ConVar_BlockGasCanDuration;
ConVar g_ConVar_QueryMaxTime;
ConVar g_ConVar_QueryMaxCount;

/* Detection Thresholds Cvars */
ConVar g_ConVar_AimbotBanThreshold;
ConVar g_ConVar_BhopBanThreshold;
ConVar g_ConVar_SilentStrafeBanThreshold;
ConVar g_ConVar_TriggerbotBanThreshold;
ConVar g_ConVar_TriggerbotLogThreshold;
ConVar g_ConVar_MacroLogThreshold;
ConVar g_ConVar_AutoShootLogThreshold;
ConVar g_ConVar_PerfectStrafeBanThreshold;
ConVar g_ConVar_PerfectStrafeLogThreshold;
ConVar g_ConVar_AHKStrafeLogThreshold;

/* Ban Times */
ConVar g_ConVar_AimbotBanTime;
ConVar g_ConVar_BhopBanTime;
ConVar g_ConVar_SilentStrafeBanTime;
ConVar g_ConVar_TriggerbotBanTime;
ConVar g_ConVar_PerfectStrafeBanTime;
ConVar g_ConVar_InstantDefuseBanTime;

public void OnPluginStart()
{
	g_ConVar_AimbotEnable = CreateConVar("cac_aimbot", "1", "是否开启自动瞄准检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BhopEnable = CreateConVar("cac_bhop", "1", "是否开启自动连跳检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_SilentStrafeEnable = CreateConVar("cac_silentstrafe", "1", "是否开启隐藏式自动连跳加速检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_TriggerbotEnable = CreateConVar("cac_triggerbot", "1", "是否开启自动开枪检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_MacroEnable = CreateConVar("cac_macro", "1", "是否开启自动连跳宏检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_AutoShootEnable = CreateConVar("cac_autoshoot", "1", "是否开启自动手枪连射检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_InstantDefuseEnable = CreateConVar("cac_instantdefuse", "1", "是否开启快速拆包检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_PerfectStrafeEnable = CreateConVar("cac_perfectstrafe", "1", "是否开启完美自动连跳加速检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BacktrackFixEnable = CreateConVar("cac_backtrack", "1", "是否开启屏蔽 Backtrack", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_AHKStrafeEnable = CreateConVar("cac_ahkstrafe", "1", "是否开启 AHK 自动连跳加速检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_HourCheckEnable = CreateConVar("cac_hourcheck", "0", "是否开启游戏时间检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_HourCheckValue = CreateConVar("cac_hourcheck_value", "50", "游戏时间必须大于多少才可以加入服务器");
	g_ConVar_ProfileCheckEnable = CreateConVar("cac_profilecheck", "1", "是否开启账户信息是否公开检测，开启后账户信息非公开会被踢出", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_SpeedHackEnable = CreateConVar("cac_speedhack", "1", "是否开启加速检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_ThirdESPEnable = CreateConVar("cac_thirdesp", "1", "是否开启第三人称透视检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_FamilySharing = CreateConVar("cac_family_sharing", "0", "是否开启禁止家庭共享的玩家加入服务器", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_MatHack = CreateConVar("cac_mathack", "1", "是否开启检查玩家的 mat_ 控制台变量", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockDefibIdle = CreateConVar("cac_block_defib_idle", "0", "是否开启禁止电击复活闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockReleaseIdle = CreateConVar("cac_block_release_idle", "0", "是否开启禁止解除控制闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockReleaseDuration = CreateConVar("cac_block_release_duration", "5.0", "禁止解除控制闲置持续时间", FCVAR_NONE, true, 0.1);
	g_ConVar_BlockGasCanIdle  = CreateConVar("cac_block_gascan_idle", "0", "是否开启禁止点油闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockGasCanDuration = CreateConVar("cac_block_gascan_duration", "9.0", "禁止点油闲置持续时间", FCVAR_NONE, true, 0.1);
	g_ConVar_QueryMaxTime = CreateConVar("cac_query_cvar_max_duration", "3.0", "查询 ConVar 超时时间", FCVAR_NONE, true, 0.1);
	g_ConVar_QueryMaxCount = CreateConVar("cac_query_cvar_max_count", "5", "查询 ConVar 超时次数", FCVAR_NONE, true, 0.0);
	
	g_ConVar_AimbotBanThreshold = CreateConVar("cac_aimbot_ban_threshold", "5", "检测为自瞄需要的 tick 数量");
	g_ConVar_BhopBanThreshold = CreateConVar("cac_bhop_ban_threshold", "10", "检测为自动连跳需要的 tick 数量");
	g_ConVar_SilentStrafeBanThreshold = CreateConVar("cac_silentstrafe_ban_threshold", "10", "检测为隐藏式自动连跳加速需要的 tick 数量");
	g_ConVar_TriggerbotBanThreshold = CreateConVar("cac_triggerbot_ban_threshold", "5", "检测为自动开枪需要的 tick 数量");
	g_ConVar_TriggerbotLogThreshold = CreateConVar("cac_triggerbot_log_threshold", "3", "检测自动连跳记录日志的 tick 数量");
	g_ConVar_MacroLogThreshold = CreateConVar("cac_macro_log_threshold", "20", "检测自动连跳宏记录日志的 tick 数量");
	g_ConVar_AutoShootLogThreshold = CreateConVar("cac_autoshoot_log_threshold", "20", "检测自动手枪连射记录日志的 tick 数量");
	g_ConVar_PerfectStrafeBanThreshold = CreateConVar("cac_perfectstrafe_ban_threshold", "15", "检测为完美自动连跳加速需要的 tick 数量");
	g_ConVar_PerfectStrafeLogThreshold = CreateConVar("cac_perfectstrafe_log_threshold", "10", "检测完美自动连跳加速记录日志需要的 tick 数量");
	g_ConVar_AHKStrafeLogThreshold = CreateConVar("cac_ahkstrafe_log_threshold", "25", "检测为 AHK 自动连跳需要的 tick 数量");

	g_ConVar_AimbotBanTime = CreateConVar("cac_aimbot_bantime", "0", "被检测到自瞄封禁多长时间");
	g_ConVar_BhopBanTime = CreateConVar("cac_bhop_bantime", "10080", "被检测到自动连跳封禁多长时间");
	g_ConVar_SilentStrafeBanTime = CreateConVar("cac_silentstrafe_bantime", "0", "被检测到隐藏式自动连跳加速封禁多长时间");
	g_ConVar_TriggerbotBanTime = CreateConVar("cac_triggerbot_bantime", "0", "被检测到自动开枪封禁多长时间");
	g_ConVar_PerfectStrafeBanTime = CreateConVar("cac_perfectstrafe_bantime", "0", "被检测到完美自动连跳加速封禁多长时间");
	g_ConVar_InstantDefuseBanTime = CreateConVar("cac_instantdefuse_bantime", "0", "被检测到快速拆包封禁多长时间");

	g_ConVar_BlockSpecialIdle = CreateConVar("cac_block_grabbed_idle", "1", "是否开启被控禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockVomitIdle = CreateConVar("cac_block_vomit_idle", "1", "是否开启沾到胆汁禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BlockGrenadeIdle = CreateConVar("cac_block_grenade_idle", "1", "是否开启丢雷禁止闲置", FCVAR_NONE, true, 0.0, true, 1.0);

	AutoExecConfig(true, "l4d2_CowAntiCheat");

	HookEventEx("bomb_begindefuse", Event_BombBeginDefuse);
	HookEventEx("bomb_defused", Event_BombDefused);
	HookEventEx("player_now_it", Event_PlayerHitByVomit);
	HookEventEx("jockey_ride_end", Event_PlayerReleased);
	HookEventEx("charger_pummel_end", Event_PlayerReleased);
	HookEventEx("tongue_release", Event_PlayerReleased);
	HookEventEx("pounce_stopped", Event_PlayerReleased);
	HookEventEx("defibrillator_used", Event_PlayerDefibrillator);

	g_ConVar_AutoBhop = FindConVar("sv_autobunnyhopping");
	g_ConVar_MaxCmdRate = FindConVar("sv_maxcmdrate");
	g_ConVar_MaxUpdateRate = FindConVar("sv_maxupdaterate");
	g_ConVar_VomitDuration = FindConVar("survivor_it_duration");
	g_ConVar_GrenadeDuration = FindConVar("pipe_bomb_timer_duration");
	g_ConVar_DefibDuration = FindConVar("defibrillator_return_to_life_time");
	g_iMaxTick = RoundToCeil(1.0 / GetTickInterval() * 2.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		SetDefaults(i);
	}

	g_aszClientSteamId = CreateArray(255);
	g_iOffsetVomitTimer = FindSendPropInfo("CTerrorPlayer", "m_itTimer") + 8;
	// g_iOffsetVomitTimer += FindSendPropInfo("DT_CountdownTimer", "m_timestamp");

	CreateTimer(1.5, Timer_CheckClientConVar, _, TIMER_REPEAT);
	CreateTimer(3.0, Timer_CheckSteamId, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_CheckTickCount, _, TIMER_REPEAT);

	AddCommandListener(Command_Away, "go_away_from_keyboard");
	AddCommandListener(Command_Away, "jointeam");

	RegConsoleCmd("cac_version", Cmd_GetVersion);
	RegAdminCmd("cac_bhopcheck", Cmd_GetBunnyHop, ADMFLAG_BAN);
	
#if defined _USE_DETOUR_FUNC_
	InstallGascanHook();
#endif
}

#if defined _USE_DETOUR_FUNC_
Handle g_pfnGasCanKilled = null;
void InstallGascanHook()
{
	Handle file = LoadGameConfigFile("l4d2_cowanticheat");
	if(file == null)
	{
		LogError("找不到文件 l4d2_cowanticheat.txt");
		return;
	}
	
	g_pfnGasCanKilled = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if(g_pfnGasCanKilled == null)
	{
		LogError("创建 DHookCreateDetour 失败");
		return;
	}
	
	if(!DHookSetFromConf(g_pfnGasCanKilled, file, SDKConf_Signature, "CGasCan::Event_Killed"))
	{
		LogError("加载 CGasCan::Event_Killed 失败");
		g_pfnGasCanKilled = null;
		file.Close();
		return;
	}
	
	file.Close();
	DHookAddParam(g_pfnGasCanKilled, HookParamType_ObjectPtr, -1, DHookPass_ByRef);
	if(!DHookEnableDetour(g_pfnGasCanKilled, false, Hooked_GasCanKilled))
	{
		LogError("安装 CGasCan::Event_Killed 失败");
		g_pfnGasCanKilled = null;
		return;
	}
}
#endif	// _USE_DETOUR_FUNC_

public void OnClientPutInServer(int client)
{
	SetDefaults(client);
	if(IsValidClient(client))
	{
		if(g_ConVar_ProfileCheckEnable.BoolValue)
		{
			Handle request = CreateRequest_ProfileStatus(client);
			SteamWorks_SendHTTPRequest(request);
		}
		if(g_ConVar_HourCheckEnable.BoolValue)
		{
			Handle request = CreateRequest_TimePlayed(client);
			SteamWorks_SendHTTPRequest(request);
		}
	}
}

/* Command Callbacks */
public Action Cmd_GetVersion(int client, int args)
{
	PrintToChat(client, "[\x02CAC\x01] 当前版本: \x05%s", PLUGIN_VERSION);
}

public Action Cmd_GetBunnyHop(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: cac_bhopcheck <#userid|name>");
		return Plugin_Handled;
	}

	char arg[128];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, true, false);

	if(!IsValidClient(target))
	{
		PrintToChat(client, "[\x02CAC\x01] Not a valid target!");
		return Plugin_Handled;
	}

	PrintToChat(client, "[\x02CAC\x01] See console for output.");

	PrintToConsole(client, "--------------------------------------------");
	PrintToConsole(client, "	%N's Detection Logs", target);
	PrintToConsole(client, "--------------------------------------------");
	PrintToConsole(client, "Perfect Jumps: %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i",
	g_iLastJumps[target][0],
	g_iLastJumps[target][1],
	g_iLastJumps[target][2],
	g_iLastJumps[target][3],
	g_iLastJumps[target][4],
	g_iLastJumps[target][5],
	g_iLastJumps[target][6],
	g_iLastJumps[target][7],
	g_iLastJumps[target][8],
	g_iLastJumps[target][9],
	g_iLastJumps[target][10],
	g_iLastJumps[target][11],
	g_iLastJumps[target][12],
	g_iLastJumps[target][13],
	g_iLastJumps[target][14],
	g_iLastJumps[target][15],
	g_iLastJumps[target][16],
	g_iLastJumps[target][17],
	g_iLastJumps[target][18],
	g_iLastJumps[target][19],
	g_iLastJumps[target][20],
	g_iLastJumps[target][21],
	g_iLastJumps[target][22],
	g_iLastJumps[target][23],
	g_iLastJumps[target][24],
	g_iLastJumps[target][25],
	g_iLastJumps[target][26],
	g_iLastJumps[target][27],
	g_iLastJumps[target][28],
	g_iLastJumps[target][29]);

	int perf = 0;

	for (int i = 0; i < JUMP_HISTORY; i++)
	{
		if(g_iLastJumps[target][i] == 1)
		{
			perf++;
		}
	}

	float avgPerf = perf / 30.0;

	PrintToConsole(client, "Avg Perfect Jumps: %.2f%", avgPerf * 100);

	PrintToConsole(client, "Jump Commands: %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i",
	g_iJumpsSent[target][0],
	g_iJumpsSent[target][1],
	g_iJumpsSent[target][2],
	g_iJumpsSent[target][3],
	g_iJumpsSent[target][4],
	g_iJumpsSent[target][5],
	g_iJumpsSent[target][6],
	g_iJumpsSent[target][7],
	g_iJumpsSent[target][8],
	g_iJumpsSent[target][9],
	g_iJumpsSent[target][10],
	g_iJumpsSent[target][11],
	g_iJumpsSent[target][12],
	g_iJumpsSent[target][13],
	g_iJumpsSent[target][14],
	g_iJumpsSent[target][15],
	g_iJumpsSent[target][16],
	g_iJumpsSent[target][17],
	g_iJumpsSent[target][18],
	g_iJumpsSent[target][19],
	g_iJumpsSent[target][20],
	g_iJumpsSent[target][21],
	g_iJumpsSent[target][22],
	g_iJumpsSent[target][23],
	g_iJumpsSent[target][24],
	g_iJumpsSent[target][25],
	g_iJumpsSent[target][26],
	g_iJumpsSent[target][27],
	g_iJumpsSent[target][28],
	g_iJumpsSent[target][29]);

	int jumps = 0;
	for (int i = 0; i < JUMP_HISTORY; i++)
	{
		jumps += g_iJumpsSent[target][i];
	}

	float avgJumps = jumps / 30.0;

	PrintToConsole(client, "Avg Jump Commands: %.2f", avgJumps);

	return Plugin_Handled;
}

#if defined _USE_DETOUR_FUNC_
public MRESReturn Hooked_GasCanKilled(int pThis, Handle hParams)
{
	int client = DHookGetParamObjectPtrVar(hParams, 1, 52, ObjectValueType_Ehandle);
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) ||
		!IsPlayerAlive(client) || GetClientTeam(client) != 2)
		return MRES_Ignored;
	
	g_fGasCanTimer[client] = GetGameTime() + g_ConVar_BlockGasCanDuration.FloatValue;
	return MRES_Ignored;
}
#endif

public Action Command_Away(int client, const char[] command, int argc)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) ||
		!IsPlayerAlive(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;

	float time = GetGameTime();
	if(g_ConVar_BlockSpecialIdle.BoolValue)
	{
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		{
			PrintToChat(client, "\x03[CAE]\x01 被控禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockReleaseIdle.BoolValue)
	{
		if(g_fReleasedTimer[client] > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 被控释放禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockVomitIdle.BoolValue)
	{
		if(GetEntDataFloat(client, g_iOffsetVomitTimer) > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 沾上胆汁禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}

		if(g_fVomitFadeTimer[client] > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 沾上胆汁禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}

	if(g_ConVar_BlockGrenadeIdle.BoolValue)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weapon > MaxClients && IsValidEntity(weapon) &&
			GetEntProp(weapon, Prop_Send, "m_iClip1") == 0)
		{
			char classname[64];
			GetEntityClassname(weapon, classname, 64);
			if(StrEqual("weapon_molotov", classname, false) ||
				StrEqual("weapon_pipe_bomb", classname, false) ||
				StrEqual("weapon_vomitjar", classname, false))
			{
				PrintToChat(client, "\x03[CAE]\x01 丢雷禁止 闲置/切换队伍。");
				return Plugin_Handled;
			}
		}

		if(g_fGrenadeExplodeTimer[client] > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 丢雷禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockDefibIdle.BoolValue)
	{
		if(g_fDefibrillatorTimer[client] > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 电击复活禁止 闲置/切换队伍。");
			return Plugin_Handled;
		}
	}
	
	if(g_ConVar_BlockGasCanIdle.BoolValue)
	{
		if(g_fGasCanTimer[client] > time)
		{
			PrintToChat(client, "\x03[CAE]\x01 禁止点燃油桶闲置。");
			return Plugin_Handled;
		}
	}

	ClientCommand(client, "cl_consistencycheck");
	return Plugin_Continue;
}

/* Get Player Settings */
public Action Timer_CheckClientConVar(Handle timer)
{
	float time = GetGameTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			// 一秒重置一次
			// if(g_fSendMoveSecond[i] <= time)
			{
				g_iSendMoveCalled[i] = 0;
				g_bHasThirdChecked[i] = false;
				g_fSendMoveSecond[i] = time + 1.0;
			}

			QueryClientConVar(i, "sensitivity", ConVar_QueryClient, i);
			QueryClientConVar(i, "m_yaw", ConVar_QueryClient, i);
			QueryClientConVar(i, "c_thirdpersonshoulder", ConVar_QueryClient, i);
			QueryClientConVar(i, "cl_cmdrate", ConVar_QueryClient, i);

			if(g_ConVar_MatHack.BoolValue)
			{
				QueryClientConVar(i, "mat_queue_mode", ConVar_QueryClient, i);
				QueryClientConVar(i, "mat_hdr_level", ConVar_QueryClient, i);
				QueryClientConVar(i, "mat_postprocess_enable", ConVar_QueryClient, i);
				QueryClientConVar(i, "r_drawothermodels", ConVar_QueryClient, i);
				QueryClientConVar(i, "cl_drawshadowtexture", ConVar_QueryClient, i);
				QueryClientConVar(i, "mat_fullbright", ConVar_QueryClient, i);
			}
			
			if(g_ConVar_QueryMaxCount.IntValue > 0)
				g_hTimerQueryTimeout[i] = CreateTimer(g_ConVar_QueryMaxTime.FloatValue, Timer_QueryConVarTimeout, i);
		}
	}
}

public Action Timer_QueryConVarTimeout(Handle timer, any client)
{
	g_hTimerQueryTimeout[client] = null;
	g_iQueryTimeout[client] += 1;
	
	if(!IsValidClient(client))
		return Plugin_Stop;
	
	int maxQueryCount = g_ConVar_QueryMaxCount.IntValue;
	if(maxQueryCount > 0 && g_iQueryTimeout[client] > maxQueryCount)
		if(!(GetUserFlagBits(client) & ADMFLAG_ROOT))
			KickClient(client, "查询 ConVar 失败，请重启游戏\nQuery ConVar Timeout");
	
	return Plugin_Continue;
}

public void ConVar_QueryClient(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if(IsValidClient(client))
	{
		if(result == ConVarQuery_Okay)
		{
			if(StrEqual("sensitivity", cvarName))
			{
				g_Sensitivity[client] = StringToFloat(cvarValue);
			}
			else if(StrEqual("m_yaw", cvarName))
			{
				g_mYaw[client] = StringToFloat(cvarValue);
			}
			else if(StrEqual("c_thirdpersonshoulder", cvarName))
			{
				if(StringToInt(cvarValue) > 0)
					g_bThirdPersonEnabled[client] = true;
				else
					g_bThirdPersonEnabled[client] = false;
			}
			else if(StrEqual("cl_cmdrate", cvarName))
			{
				g_iSendMoveRate[client] = StringToInt(cvarValue);
			}
			else if(StrEqual("mat_queue_mode", cvarName))
			{
				if(StringToInt(cvarValue) >= 3)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					KickClient(client, "隐藏 Boomer 胆汁屏幕效果\nRemove boomer vomit");
				}
			}
			else if(StrEqual("mat_hdr_level", cvarName))
			{
				if(StringToInt(cvarValue) != 2)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					KickClient(client, "地图高亮\nFull Bright");
				}
			}
			else if(StrEqual("mat_postprocess_enable", cvarName))
			{
				if(StringToInt(cvarValue) != 1)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					KickClient(client, "隐藏屏幕效果\nClean Screen");
				}
			}
			else if(StrEqual("r_drawothermodels", cvarName))
			{
				if(StringToInt(cvarValue) != 1)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					
					if(cvarValue[0] == '2')
						BanClient(client, 0, BANFLAG_AUTO, "[CAC] r_drawothermodels Wireframe", "线框透视\nWireframe WallHack");
					else
						KickClient(client, "不合理的控制台变量\nConVar violation");
				}
			}
			else if(StrEqual("cl_drawshadowtexture", cvarName))
			{
				if(StringToInt(cvarValue) > 0)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					
					if(cvarValue[0] == '1')
						BanClient(client, 0, BANFLAG_AUTO, "[CAC] cl_drawshadowtexture 3DBox", "3D 方框透视\n3DBox WallHack");
					else
						KickClient(client, "不合理的控制台变量\nConVar violation");
				}
			}
			else if(StrEqual("mat_fullbright", cvarName))
			{
				if(StringToInt(cvarValue) > 0)
				{
					PrintToChatOther(client, "\x03[CAC]\x01 玩家 \x04%N\x01 的 \x03%s\x01 为 \x05%s\x01.", client, cvarName, cvarValue);
					CowAC_Log("玩家 %N 的 ConVar %s 为 %s，不符合规范", client, cvarName, cvarValue);
					KickClient(client, "地图高亮\nFull Bright");
				}
			}
		}
		else
		{
			PrintToChatOther(client, "\x03[CAC]\x01 对玩家 \x04%N\x01 进行安全验证 \x05%s\x01 失败。", client, cvarName);

			switch(result)
			{
				case ConVarQuery_NotFound:
				{
					CowAC_Log("玩家 %N 查询 ConVar %s 失败：ConVarQuery_NotFound", client, cvarName);
					KickClient(client, "检查 ConVar 失败\n ConVarQuery_NotFound", cvarName);
				}
				case ConVarQuery_NotValid:
				{
					CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_NotValid", client, cvarName);
					KickClient(client, "检查 ConVar 失败\n ConVarQuery_NotValid", cvarName);
				}
				case ConVarQuery_Protected:
				{
					CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_Protected", client, cvarName);
					KickClient(client, "检查 ConVar 失败\n ConVarQuery_Protected", cvarName);
				}
				default:
				{
					CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_Unknown", client, cvarName);
					KickClient(client, "检查 ConVar 失败\n ConVarQuery_Unknown", cvarName);
				}
			}
		}

		if(g_bThirdPersonEnabled[client] && !g_bHasThirdChecked[client] && g_ConVar_ThirdESPEnable.BoolValue)
		{
			g_bHasThirdChecked[client] = true;
			QueryClientConVar(client, "cam_idealdist", ConVar_QueryThirdPerson);
			QueryClientConVar(client, "c_thirdpersonshoulderheight", ConVar_QueryThirdPerson);
			QueryClientConVar(client, "c_thirdpersonshoulderoffset", ConVar_QueryThirdPerson);
		}
		
		if(g_hTimerQueryTimeout[client])
		{
			g_iQueryTimeout[client] = 0;
			KillTimer(g_hTimerQueryTimeout[client]);
			g_hTimerQueryTimeout[client] = null;
		}
	}
}

public int SW_OnValidateClient(int ownerSteamId, int clientSteamId)
{
	if(!g_ConVar_FamilySharing.BoolValue)
		return 0;

	char steamId[255];
	FormatEx(steamId, 255, "STEAM_1:%d:%d|STEAM_1:%d:%d",
		(ownerSteamId & 1), (ownerSteamId >> 1),
		(clientSteamId & 1), (clientSteamId >> 1));

	g_aszClientSteamId.PushString(steamId);
	return 0;
}

public Action Timer_CheckSteamId(Handle timer, any data)
{
	if(!g_ConVar_FamilySharing.BoolValue)
		return Plugin_Continue;

	char sTwo[255], sClient[2][64];
	int i = 0;

	for(i = 0; i < g_aszClientSteamId.Length; ++i)
	{
		g_aszClientSteamId.GetString(i, sTwo, 255);
		ExplodeString(sTwo, "|", sClient, 2, 64);
		TrimString(sClient[0]);
		TrimString(sClient[1]);

		int client = FindClientBySteamId(sClient[1]);
		if(client == -1)
			client = FindClientBySteamId(sClient[0]);

		// 等待玩家加入游戏
		if(client == -1)
			continue;

		g_aszClientSteamId.Erase(i);
		i -= 1;

		if(StrEqual(sClient[0], sClient[1], false))
			continue;

		if(client == -1)
		{
			PrintToServer("[CAC] 玩家 %d 的 SteamID 为 %s 游戏所有者为 %s", client, sClient[1], sClient[0]);
			CowAC_Log("玩家 %d 的 SteamID 为 %s，但游戏所有者的 SteamID 为 %s", client, sClient[1], sClient[0]);
			ServerCommand("kickid \"%s\" \"请不要使用家庭共享的游戏进入\nYou have been refused entry to this server due to Steam Family Sharing being detected on your account. Please reconnect using a game you own.\"", sClient[1]);
			ServerCommand("kickid \"%s\" \"请不要使用家庭共享的游戏进入\nYou have been refused entry to this server due to Steam Family Sharing being detected on your account. Please reconnect using a game you own.\"", sClient[0]);
		}
		else
		{
			PrintToServer("[CAC] 玩家 %N 的 SteamID 为 %s 游戏所有者为 %s", client, sClient[1], sClient[0]);
			CowAC_Log("玩家 %N 的 SteamID 为 %s，但游戏所有者的 SteamID 为 %s", client, sClient[1], sClient[0]);

			if(GetUserFlagBits(client) & ADMFLAG_ROOT)
				continue;

			KickClient(client, "请不要使用家庭共享的游戏进入\nYou have been refused entry to this server due to Steam Family Sharing being detected on your account. Please reconnect using a game you own.");
		}
	}

	return Plugin_Continue;
}

public Action Timer_CheckTickCount(Handle timer, any data)
{
	static float fLastProcessed;
	int iNewTicks = RoundToCeil((GetEngineTime() - fLastProcessed) / GetTickInterval());
	float time = GetGameTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			// Make sure latency didn't spike more than 5ms.
			// We want to avoid writing a lagging client to logs.
			float fLatency = GetClientLatency(i, NetFlow_Outgoing);

			if (g_iTickLeft[i] <= 0 && FloatAbs(g_fPrevLatency[i] - fLatency) <= 0.005)
			{
				if (++g_iTickDetecton[i] >= MAX_TICK_DETECTION && time > g_fTickDetectedTime[i])
				{
					PrintToChatOther(i, "\x03[CAC]\x01 玩家 \x04%N\x01 移动速度过快。", i);
					CowAC_Log("玩家 %N 的移动速度过快", i);
					// KickClient(i, "移动速度过快\nspeedhack");
					BanClient(i, g_ConVar_InstantDefuseBanTime.IntValue, BANFLAG_AUTO,
						"[CAC] Speed Hack Detected.", "移动速度过快\nSpeed Hack");

					g_fTickDetectedTime[i] = time + 30.0;
				}
			}
			else if (g_iTickDetecton[i])
			{
				g_iTickDetecton[i]--;
			}

			g_fPrevLatency[i] = fLatency;
		}

		if ((g_iTickLeft[i] += iNewTicks) > g_iMaxTick)
		{
			g_iTickLeft[i] = g_iMaxTick;
		}
	}

	fLastProcessed = GetEngineTime();
	return Plugin_Continue;
}

stock int FindClientBySteamId(const char[] steamID)
{
	char steamId[64];
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;

		GetClientAuthId(i, AuthId_Steam2, steamId, 64, false);
		ReplaceString(steamId, 64, "STEAM_0:", "STEAM_1:");

		if(StrEqual(steamId, steamID, false))
			return i;
	}

	return -1;
}

public void ConVar_QueryThirdPerson(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if(!IsValidClient(client) || cookie == QUERYCOOKIE_FAILED)
		return;

	int value = StringToInt(cvarValue);
	if(StrEqual("c_thirdpersonshoulderoffset", cvarName))
	{
		if(value > 50 || value < -50)
		{
			// 通过检测玩家的第三人称相机偏移，防止玩家通过移动相机看到墙后面的东西
			PrintToAdmins("[\x02CAC\x01] 玩家 \x04%N\x01 被检测到第三人称水平偏移过大 (%d).", client, value);
			CowAC_Log("玩家 %N 的参数 %s 是 %d", client, cvarName, value);
			PrintToChatAll("\x03[CAC]\x01 玩家 \x05%N\x01 的 c_thirdpersonshoulderoffset 不符合规范（-50～50）。", client);
			PrintHintText(client, "请将你的 c_thirdpersonshoulderoffset 设置为 -50 到 50 之间");
			ChangeClientTeam(client, 1);
		}
	}
	else if(StrEqual("c_thirdpersonshoulderheight", cvarName))
	{
		if(value > 25 || value < -5)
		{
			// 通过检测玩家的第三人称相机高度，防止玩家通过移动相机看到墙后面的东西
			PrintToAdmins("[\x02CAC\x01] 玩家 \x04%N\x01 被检测到第三人垂直偏移过大 (%d).", client, value);
			CowAC_Log("玩家 %N 的参数 %s 是 %d", client, cvarName, value);
			PrintToChatAll("\x03[CAC]\x01 玩家 \x05%N\x01 的 c_thirdpersonshoulderheight 不符合规范（-5～25）。", client);
			PrintHintText(client, "请将你的 c_thirdpersonshoulderheight 设置为 -5 到 25 之间");
			ChangeClientTeam(client, 1);
		}
	}
	else if(StrEqual("cam_idealdist", cvarName))
	{
		if(value > 130 || value < -30)
		{
			// 通过检测玩家的第三人称相机距离，防止玩家通过移动相机看到墙后面的东西
			PrintToAdmins("[\x02CAC\x01] 玩家 \x04%N\x01 被检测到第三人称距离过远 (%d).", client, value);
			CowAC_Log("玩家 %N 的参数 %s 是 %d", client, cvarName, value);
			PrintToChatAll("\x03[CAC]\x01 玩家 \x05%N\x01 的 cam_idealdist 不符合规范（-30～130）。", client);
			PrintHintText(client, "请将你的 cam_idealdist 设置为 -30 到 130 之间");
			ChangeClientTeam(client, 1);
		}
	}
	else
	{
		PrintToChatOther(client, "\x03[CAC]\x01 对玩家 \x04%N\x01 进行安全验证 \x05%s\x01 失败。", client, cvarName);

		switch(result)
		{
			case ConVarQuery_NotFound:
			{
				CowAC_Log("玩家 %N 查询 ConVar %s 失败：ConVarQuery_NotFound", client, cvarName);
				KickClient(client, "检查 ConVar 失败\n ConVarQuery_NotFound", cvarName);
			}
			case ConVarQuery_NotValid:
			{
				CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_NotValid", client, cvarName);
				KickClient(client, "检查 ConVar 失败\n ConVarQuery_NotValid", cvarName);
			}
			case ConVarQuery_Protected:
			{
				CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_Protected", client, cvarName);
				KickClient(client, "检查 ConVar 失败\n ConVarQuery_Protected", cvarName);
			}
			default:
			{
				CowAC_Log("玩家 %N 查询 ConVar %s ConVarQuery_Unknown", client, cvarName);
				KickClient(client, "检查 ConVar 失败\n ConVarQuery_Unknown", cvarName);
			}
		}
	}
}

public void Event_BombBeginDefuse(Handle event, const char[] name, bool dontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if(g_ConVar_InstantDefuseEnable.BoolValue)
	{
		g_fDefuseTime[client] = GetEngineTime();
	}
}

public void Event_BombDefused(Handle event, const char[] name, bool dontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if(GetEngineTime() - g_fDefuseTime[client] < 3.5 && g_ConVar_InstantDefuseEnable.BoolValue)
	{
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到快速拆包!", client);
		BanClient(client, g_ConVar_InstantDefuseBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] Instant Defuse Detected.", "快速拆雷\nInstant Defuse Detected");
	}
}

public void Event_PlayerHitByVomit(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fVomitFadeTimer[client] = GetGameTime() + g_ConVar_VomitDuration.FloatValue;
}

public void Event_PlayerReleased(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fReleasedTimer[client] = GetGameTime() + g_ConVar_BlockReleaseDuration.FloatValue;
}

public void Event_PlayerDefibrillator(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_fDefibrillatorTimer[client] = GetGameTime() + g_ConVar_DefibDuration.FloatValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity <= MaxClients || entity > 2048)
		return;

	if(StrEqual("molotov_projectile", classname, false) ||
		StrEqual("pipe_bomb_projectile", classname, false) ||
		StrEqual("vomitjar_projectile", classname, false))
		SDKHook(entity, SDKHook_SpawnPost, EntityHook_OnGrenadeThrown);
}

public void EntityHook_OnGrenadeThrown(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, EntityHook_OnGrenadeThrown);

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	char classname[64];
	GetEntityClassname(entity, classname, 64);
	if(StrEqual("molotov_projectile", classname, false) ||
		StrEqual("pipe_bomb_projectile", classname, false) ||
		StrEqual("vomitjar_projectile", classname, false))
		g_fGrenadeExplodeTimer[client] = GetGameTime() + g_ConVar_GrenadeDuration.FloatValue;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsValidClient(client) && !IsFakeClient(client) && IsPlayerAlive(client) && !(GetUserFlagBits(client) & ADMFLAG_ROOT))
	{
		float vOrigin[3], AnglesVec[3], EndPoint[3];

		float Distance = 999999.0;

		GetClientEyePosition(client,vOrigin);
		GetAngleVectors(fAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

		EndPoint[0] = vOrigin[0] + (AnglesVec[0]*Distance);
		EndPoint[1] = vOrigin[1] + (AnglesVec[1]*Distance);
		EndPoint[2] = vOrigin[2] + (AnglesVec[2]*Distance);

		Handle trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint,
			TraceEntityFilterPlayer, client);

		if(g_ConVar_AimbotEnable.BoolValue)
			CheckAimbot(client, iButtons, fAngles, trace);

		if(g_ConVar_BhopEnable.BoolValue && (g_ConVar_AutoBhop == null || !g_ConVar_AutoBhop.BoolValue))
			CheckBhop(client, iButtons);

		if(g_ConVar_SilentStrafeEnable.BoolValue)
			CheckSilentStrafe(client, fVelocity[1]);

		if(g_ConVar_TriggerbotEnable.BoolValue)
			CheckTriggerBot(client, iButtons, trace);

		if(g_ConVar_MacroEnable.BoolValue)
			CheckMacro(client, iButtons);

		if(g_ConVar_AutoShootEnable.BoolValue)
			CheckAutoShoot(client, iButtons);

		if(g_ConVar_PerfectStrafeEnable.BoolValue)
			CheckPerfectStrafe(client, mouse[0], iButtons);

		if(g_ConVar_AHKStrafeEnable.BoolValue)
			CheckAHKStrafe(client, mouse[0]);

		if(g_ConVar_SpeedHackEnable.BoolValue)
			CheckSpeedHack(client);

		//CheckWallTrace(client, fAngles);
		delete trace;

		prev_OnGround[client] = (GetEntityFlags(client) & FL_ONGROUND) == FL_ONGROUND;

		prev_angles[client] = fAngles;
		prev_buttons[client] = iButtons;
	}
	else
	{
		for (int f = 0; f < sizeof(prev_angles[]); f++)
			prev_angles[client][f] = 0.0;

		g_bAngleSet[client] = false;
	}

	g_iCmdNum[client]++;

	if(g_ConVar_BacktrackFixEnable.BoolValue)
	{
		StopBacktracking(client, tickcount, iButtons);
		return Plugin_Changed;
	}
	else
		return Plugin_Continue;
}

public void CheckAimbot(int client, int buttons, float angles[3], Handle trace)
{
	// Prevent incredibly high sensitivity from causing detections
	if(FloatAbs(g_Sensitivity[client] * g_mYaw[client]) > 0.6)
	{
		return;
	}

	if(!g_bAngleSet[client])
	{
		g_bAngleSet[client] = true;
	}

	float delta = NormalizeAngle(angles[1] - prev_angles[client][1]);

	if (TR_DidHit(trace))
	{
		int target = TR_GetEntityIndex(trace);

		if (IsValidTarget(target, GetClientTeam(client)) && IsPlayerAlive(client))
		{
			if(delta > 15.0 || delta < -15.0)
			{
				int hitgroup = TR_GetHitGroup(trace);

				if(buttons & IN_ATTACK && hitgroup == g_iLastHitGroup[client])
				{
					g_iAimbotCount[client]++;
				}
				else
				{
					g_iAimbotCount[client] = 0;
				}

				g_iLastHitGroup[client] = hitgroup;
			}
		}
	}

	if(g_iAimbotCount[client] >= g_ConVar_AimbotBanThreshold.IntValue)
	{
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到自动瞄准!", client);
  		char date[32], log[128], steamid[64];
  		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
		Format(log, sizeof(log), "[CowAC] %s | BAN | %N (%s) has been detected for Aimbot (%i)", date, client, steamid, g_iAimbotCount[client]);
		CowAC_Log(log);
		BanClient(client, g_ConVar_AimbotBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] Aimbot Detected.", "自动瞄准\nAimbot Detected");
		g_iAimbotCount[client] = 0;
	}
}

public void CheckBhop(int client, int buttons)
{
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		g_iTicksOnGround[client]++;
	}
	else
	{
		g_iTicksOnGround[client] = 0;
	}

	if(g_iTicksOnGround[client] <= 20 && GetEntityFlags(client) & FL_ONGROUND && buttons & IN_JUMP && !(prev_buttons[client] & IN_JUMP))
	{
		g_iLastJumps[client][g_iLastJumpIndex[client]] = g_iTicksOnGround[client];

		g_iLastJumpIndex[client]++;
	}

	if(g_iLastJumpIndex[client] == 30)
			g_iLastJumpIndex[client] = 0;

	if((g_iTicksOnGround[client] == 1 || g_iTicksOnGround[client] == g_iPrev_TicksOnGround[client]) && GetEntityFlags(client) & FL_ONGROUND && buttons & IN_JUMP && !(prev_buttons[client] & IN_JUMP))
	{
		g_iPerfectBhopCount[client]++;

		g_iPrev_TicksOnGround[client] = g_iTicksOnGround[client];
	}
	else if(g_iTicksOnGround[client] >= g_iPrev_TicksOnGround[client] && GetEntityFlags(client) & FL_ONGROUND)
	{
		g_iPerfectBhopCount[client] = 0;
	}

	if(g_iPerfectBhopCount[client] >= g_ConVar_BhopBanThreshold.IntValue)
	{
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到自动连跳!", client);
		char date[32], log[128], steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
		Format(log, sizeof(log), "[CowAC] %s | BAN | %N (%s) has been detected for Bhop Assist (%i)", date, client, steamid, g_iPerfectBhopCount[client]);
		CowAC_Log(log);
		BanClient(client, g_ConVar_BhopBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] Bhop Assist Detected.", "自动连跳\nBhop Assist Detected");
		g_iPerfectBhopCount[client] = 0;
	}
}

public void CheckSilentStrafe(int client, float sidemove)
{
	if(sidemove > 0 && prev_sidemove[client] < 0)
	{
		g_iPerfSidemove[client]++;

		if(g_iCmdNum[client] % 50 == 1)
			CheckSidemoveCount(client);
	}
	else if(sidemove < 0 && prev_sidemove[client] > 0)
	{
		g_iPerfSidemove[client]++;

		if(g_iCmdNum[client] % 50 == 1)
			CheckSidemoveCount(client);
	}
	else
	{
		g_iPerfSidemove[client] = 0;
	}

	prev_sidemove[client] = sidemove;
}

public void CheckSidemoveCount(int client)
{
	if(g_iPerfSidemove[client] >= g_ConVar_SilentStrafeBanThreshold.IntValue)
	{
		char date[32], log[128], steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
		Format(log, sizeof(log), "[CowAC] %s | BAN | %N (%s) has been detected for Silent-Strafe (%i)", date, client, steamid, g_iPerfSidemove[client]);
		CowAC_Log(log);
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到隐藏式自动连跳加速!", client);
		BanClient(client, g_ConVar_SilentStrafeBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] Silent-Strafe Detected.", "自动连跳加速\nSilent-Strafe Detected");
	}

	g_iPerfSidemove[client] = 0;
}

public void CheckTriggerBot(int client, int buttons, Handle trace)
{
	if (TR_DidHit(trace))
	{
		int target = TR_GetEntityIndex(trace);

		if (IsValidTarget(target, GetClientTeam(client)) && IsPlayerAlive(client) && !g_bShootSpam[client])
		{
			g_iTicksOnPlayer[client]++;

			if(buttons & IN_ATTACK && !(prev_buttons[client] & IN_ATTACK) && g_iTicksOnPlayer[client] == g_iPrev_TicksOnPlayer[client])
			{
				g_iTriggerBotCount[client]++;
			}
			else if(buttons & IN_ATTACK && prev_buttons[client] & IN_ATTACK && g_iTicksOnPlayer[client] == 1)
			{
				if(g_iTriggerBotCount[client] >= g_ConVar_TriggerbotLogThreshold.IntValue)
				{
					char message[128];
					Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01被检测到有 \x10%i\x01 个 tick 完美的射击。", client, g_iTriggerBotCount[client]);
					PrintToAdmins(message);
					char date[32], log[128], steamid[64];
					GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
					FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
					Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for %i 1 tick perfect shots", date, client, steamid, g_iTriggerBotCount[client]);
					CowAC_Log(log);
				}

				g_iTriggerBotCount[client] = 0;
			}
			else if(!(buttons & IN_ATTACK) && !(prev_buttons[client] & IN_ATTACK) && g_iTicksOnPlayer[client] >= g_iPrev_TicksOnPlayer[client])
			{
				if(g_iTriggerBotCount[client] >= g_ConVar_TriggerbotLogThreshold.IntValue)
				{
					char message[128];
					Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01被检测到有 \x10%i\x01 个 tick 完美的射击。", client, g_iTriggerBotCount[client]);
					PrintToAdmins(message);
					char date[32], log[128], steamid[64];
					GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
					FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
					Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for %i 1 tick perfect shots", date, client, steamid, g_iTriggerBotCount[client]);
					CowAC_Log(log);
				}

				g_iTriggerBotCount[client] = 0;
			}
		}
		else
		{
			if(g_iTicksOnPlayer[client] > 0)
				g_iPrev_TicksOnPlayer[client] = g_iTicksOnPlayer[client];

			g_iTicksOnPlayer[client] = 0;
		}
	}
	else
	{
		if(g_iTicksOnPlayer[client] > 0)
			g_iPrev_TicksOnPlayer[client] = g_iTicksOnPlayer[client];

		g_iTicksOnPlayer[client] = 0;
	}

	if(g_iTriggerBotCount[client] >= g_ConVar_TriggerbotBanThreshold.IntValue)
	{
  		char date[32], log[128], steamid[64];
  		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
		Format(log, sizeof(log), "[CowAC] %s | BAN | %N (%s) has been detected for TriggerBot / Smooth Aimbot (%i)", date, client, steamid, g_iTriggerBotCount[client]);
		CowAC_Log(log);
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到自动开枪/平滑自动瞄准!", client);
		BanClient(client, g_ConVar_TriggerbotBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] TriggerBot / Smooth Aimbot Detected.", "自动开枪/平滑自动瞄准\nTriggerBot / Smooth Aimbot Detected");
		g_iTriggerBotCount[client] = 0;
	}
}

public void CheckMacro(int client, int buttons)
{
	float vec[3];
	GetClientAbsOrigin(client, vec);

	if(buttons & IN_JUMP && !(prev_buttons[client] & IN_JUMP) && !(GetEntityFlags(client) & FL_ONGROUND) && vec[2] > g_fJumpStart[client])
	{
		g_iMacroCount[client]++;
	}
	else if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(g_iMacroCount[client] >= g_ConVar_MacroLogThreshold.IntValue)
		{
			char message[128];
			Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01 被检测到连跳脚本 (\x04%i\x01)!", client, g_iMacroCount[client]);
			PrintToAdmins(message);

			char date[32], log[128], steamid[64];
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
			FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
			Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for Macro / Hyperscroll (%i)", date, client, steamid, g_iMacroCount[client]);
			CowAC_Log(log);
			g_iMacroDetectionCount[client]++;

			if(g_iMacroDetectionCount[client] >= 10)
			{
				KickClient(client, "自动连跳 脚本/宏\nMacro / Hyperscroll");
				g_iMacroDetectionCount[client] = 0;
			}
		}

		if(g_iMacroCount[client] > 0)
		{
			g_iJumpsSent[client][g_iJumpsSentIndex[client]] = g_iMacroCount[client];
			g_iJumpsSentIndex[client]++;

			if(g_iJumpsSentIndex[client] == 30)
				g_iJumpsSentIndex[client] = 0;
		}

		g_iMacroCount[client] = 0;

		g_fJumpStart[client] = vec[2];
	}
}

public void CheckAutoShoot(int client, int buttons)
{
	if(buttons & IN_ATTACK && !(prev_buttons[client] & IN_ATTACK))
	{
		if(g_bFirstShot[client])
		{
			g_bFirstShot[client] = false;

			g_iLastShotTick[client] = g_iCmdNum[client];
		}
		else if(g_iCmdNum[client] - g_iLastShotTick[client] <= 10 && !g_bFirstShot[client])
		{
			g_bShootSpam[client] = true;
			g_iAutoShoot[client]++;
			g_iLastShotTick[client] = g_iCmdNum[client];
		}
		else
		{
			if(g_iAutoShoot[client] >= g_ConVar_AutoShootLogThreshold.IntValue)
			{
				char message[128];
				Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01 被检测到手枪连射脚本 (\x04%i\x01)!", client, g_iAutoShoot[client]);
				PrintToAdmins(message);
				char date[32], log[128], steamid[64];
				GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
				FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
				Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for AutoShoot Script (%i)", date, client, steamid, g_iAutoShoot[client]);
				CowAC_Log(log);
			}

			g_iAutoShoot[client] = 0;
			g_bShootSpam[client] = false;
			g_bFirstShot[client] = true;
		}
	}
}

public void CheckWallTrace(int client, float angles[3])
{
	float vOrigin[3], AnglesVec[3];
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, AnglesVec);

	Handle trace = TR_TraceRayFilterEx(vOrigin, AnglesVec, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, client);

	if (TR_DidHit(trace))
	{
		int target = TR_GetEntityIndex(trace);

		if (IsValidTarget(target, GetClientTeam(client)) && IsPlayerAlive(client))
		{
			g_iWallTrace[client]++;
		}
		else
		{
			g_iWallTrace[client] = 0;
		}
	}
	else
	{
		g_iWallTrace[client] = 0;
	}
	delete trace;

	float tickrate = 1.0 / GetTickInterval();

	if(g_iWallTrace[client] >= RoundToZero(tickrate))
	{
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到自动跟踪墙.", client);
		g_iWallTrace[client] = 0;
	}
}

public void CheckPerfectStrafe(int client, int mousedx, int buttons)
{
	if(mousedx > 0 && turnRight[client])
	{
		if(!(prev_buttons[client] & IN_MOVERIGHT) && buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT))
		{
			g_iStrafeCount[client]++;

			CheckPerfCount(client);
		}
		else
		{
			if(g_iStrafeCount[client] >= g_ConVar_PerfectStrafeLogThreshold.IntValue)
			{
				char message[128];
				Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01 被检测到 for \x10%i\x01 次完美的连跳加速。", client, g_iStrafeCount[client]);
				PrintToAdmins(message);
				char date[32], log[128], steamid[64];
				GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
				FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
				Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for Consistant Perfect Strafes (%i)", date, client, steamid, g_iStrafeCount[client]);
				CowAC_Log(log);
			}

			g_iStrafeCount[client] = 0;
		}

		turnRight[client] = false;
	}
	else if(mousedx < 0 && !turnRight[client])
	{
		if(!(prev_buttons[client] & IN_MOVELEFT) && buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT))
		{
			g_iStrafeCount[client]++;

			CheckPerfCount(client);
		}
		else
		{
			if(g_iStrafeCount[client] >= g_ConVar_PerfectStrafeLogThreshold.IntValue)
			{
				char message[128];
				Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01被检测到 \x10%i\x01 次完美的连跳加速。", client, g_iStrafeCount[client]);
				PrintToAdmins(message);
				char date[32], log[128], steamid[64];
				GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
				FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
				Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for Consistant Perfect Strafes (%i)", date, client, steamid, g_iStrafeCount[client]);
				CowAC_Log(log);
			}

			g_iStrafeCount[client] = 0;
		}

		turnRight[client] = true;
	}
}

public void CheckPerfCount(int client)
{
	if(g_iStrafeCount[client] >= g_ConVar_PerfectStrafeBanThreshold.IntValue)
	{
		PrintToChatOther(client, "[\x02CAC\x01] \x04%N \x01被检测到完美自动连跳加速 (%i)!", client, g_iStrafeCount[client]);
		char date[32], log[128], steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
		Format(log, sizeof(log), "[CowAC] %s | BAN | %N (%s) has been detected for Consistant Perfect Strafes (%i)", date, client, steamid, g_iStrafeCount[client]);
		CowAC_Log(log);
		BanClient(client, g_ConVar_PerfectStrafeBanTime.IntValue, BANFLAG_AUTO,
			"[CAC] Consistant Perfect Strafes Detected.", "自动连跳加速\nConsistant Perfect Strafes Detected");
		g_iStrafeCount[client] = 0;
	}
}

public void CheckSpeedHack(int client)
{
	/*
	g_iSendMoveCalled[client] += 1;
	if(g_iSendMoveCalled[client] > g_ConVar_MaxCmdRate.IntValue &&
		g_iSendMoveCalled[client] > g_ConVar_MaxUpdateRate.IntValue &&
		(g_iSendMoveRate[client] <= 0 || g_iSendMoveCalled[client] > g_iSendMoveRate[client]))
	{
		// 检查原理为如果玩家使用加速，就会在短时间内调用超过上限次数的 CL_SendMove
		// 一般情况下只会根据服务器设置的上限进行有限的调用
		// 通过修改 m_flLaggedMovementValue 实现的加速不会被检测到
		// 当然不一定准确，因为玩家在打开控制台的时候也会触发这个的
		// PrintToChatOther(client, "[\x02CAC\x01] 玩家 \x04%N\x01 被检测到加速。", client);
		PrintToAdmins("[CAC] 玩家 %N 被检测到过多的消息 (%d/%d).",
			g_iSendMoveCalled[client], g_ConVar_MaxCmdRate.IntValue);

		g_iSendMoveCalled[client] = 0;
	}
	*/

	if (g_iTickLeft[client] <= 0)
		return;

	g_iTickLeft[client]--;
}

public void StopBacktracking(int client, int &tickcount, int buttons)
{
	/* Big thanks to Shavit for the help here */
	if(tickcount < g_iTickCount[client] && (buttons & IN_ATTACK) > 0 && IsPlayerAlive(client))
	{
		tickcount = ++g_iTickCount[client];
	}

	g_iTickCount[client] = tickcount;
}

public void CheckAHKStrafe(int client, int mouse)
{
	float vec[3];
	GetClientAbsOrigin(client, vec);

	if(prev_OnGround[client] && !(GetEntityFlags(client) & FL_ONGROUND))
	{
		g_fJumpPos[client] = vec[2];
	}

	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		if((mouse >= 10 || mouse <= -10) && g_fJumpPos[client] < vec[2])
		{
			if(mouse == g_iMousedx_Value[client] || mouse == g_iMousedx_Value[client] * -1)
			{
				g_iMousedxCount[client]++;
			}
			else
			{
				g_iMousedx_Value[client] = mouse;
				g_iMousedxCount[client] = 0;
			}

			if(g_iMousedxCount[client] >= g_ConVar_AHKStrafeLogThreshold.IntValue)
			{
				g_iMousedxCount[client] = 0;
				g_iAHKStrafeDetection[client]++;

				if(g_iAHKStrafeDetection[client] >= 10)
				{
					char message[128];
					Format(message, sizeof(message), "[\x02CAC\x01] 玩家 \x04%N \x01 被检测到 AHK 自动连跳加速。", client);
					PrintToAdmins(message);
					char date[32], log[128], steamid[64];
					GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
					FormatTime(date, sizeof(date), "%m/%d/%Y %I:%M:%S", GetTime());
					Format(log, sizeof(log), "[CowAC] %s | LOG | %N (%s) has been detected for AHK Strafe (%i Infractions)", date, client, steamid, g_iAHKStrafeDetection[client]);
					CowAC_Log(log);
					g_iAHKStrafeDetection[client] = 0;
				}
				// g_iMousedxCount[client] = 0;
			}
		}
	}
}


Handle CreateRequest_TimePlayed(int client)
{
	char request_url[256];
	Format(request_url, sizeof(request_url), "http://www.cowanticheat.com/CheckTime.php");
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);

	char steamid[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));

	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestContextValue(request, client);
	SteamWorks_SetHTTPCallbacks(request, TimePlayed_OnHTTPResponse);
	return request;
}

public int TimePlayed_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		delete request;
		return;
	}

	int iBufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, iBufferSize);

	char[] sBody = new char[iBufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, sBody, iBufferSize);

	int time = StringToInt(sBody, 10) / 60 / 60;

	if(time <= 0)
	{
		KickClient(client, "请将你的个人资料设置成公开\nPlease connect with a public steam profile");
	}
	else if(time < g_ConVar_HourCheckValue.IntValue)
	{
		KickClient(client, "你的游戏时间太短了 (%i/%i)\nYou do not meet the minimum hour requirement to play here", time, g_ConVar_HourCheckValue.IntValue);
	}

	delete request;
}

Handle CreateRequest_ProfileStatus(int client)
{
	char request_url[256];
	Format(request_url, sizeof(request_url), "http://www.cowanticheat.com/CheckProfile.php");
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);

	char steamid[64];
	GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));

	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestContextValue(request, client);
	SteamWorks_SetHTTPCallbacks(request, ProfileStatus_OnHTTPResponse);
	return request;
}

public int ProfileStatus_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		delete request;
		return;
	}

	int iBufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, iBufferSize);

	char[] sBody = new char[iBufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, sBody, iBufferSize);

	int profile = StringToInt(sBody, 10) / 60 / 60;

	if(profile < 3 && !(GetUserFlagBits(client) & ADMFLAG_ROOT))
	{
		KickClient(client, "请将你的个人资料设置成公开\nPlease connect with a public steam profile");
	}

	delete request;
}

public bool TraceEntityFilterPlayer(int entity, int mask, any data)
{
	return data != entity;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	if(entity == 0)
		return false;
	else
		return entity != data && 0 < entity <= MaxClients;
}

public void SetDefaults(int client)
{
	g_iCmdNum[client] = 0;
	g_iAimbotCount[client] = 0;
	g_iLastHitGroup[client] = 0;
	for (int f = 0; f < sizeof(prev_angles[]); f++)
		prev_angles[client][f] = 0.0;
	g_bAngleSet[client] = false;
	g_iPerfectBhopCount[client] = 0;
	g_bThirdPersonEnabled[client] = false;
	g_iTicksOnGround[client] = 0;
	g_iPrev_TicksOnGround[client] = 0;
	prev_sidemove[client] = 0.0;
	g_iPerfSidemove[client] = 0;
	prev_buttons[client] = 0;
	g_bShootSpam[client] = false;
	g_iLastShotTick[client] = 0;
	g_bFirstShot[client] = true;
	g_iAutoShoot[client] = 0;
	g_iTriggerBotCount[client] = 0;
	g_iTicksOnPlayer[client] = 0;
	g_iPrev_TicksOnPlayer[client] = 1;
	g_iMacroCount[client] = 0;
	g_iMacroDetectionCount[client] = 0;
	g_fJumpStart[client] = 0.0;
	g_fDefuseTime[client] = 0.0;
	g_Sensitivity[client] = 0.0;
	g_mYaw[client] = 0.0;
	g_iWallTrace[client] = 0;
	g_iStrafeCount[client] = 0;
	turnRight[client] = true;
	g_iTickCount[client] = 0;
	prev_mousedx[client] = 0;
	g_iAHKStrafeDetection[client] = 0;
	g_iMousedx_Value[client] = 0;
	g_iMousedxCount[client] = 0;
	g_fJumpPos[client] = 0.0;
	prev_OnGround[client] = true;
	g_iSendMoveCalled[client] = 0;
	g_fSendMoveSecond[client] = 0.0;
	g_bHasThirdChecked[client] = false;
	g_iSendMoveRate[client] = 0;
	g_fVomitFadeTimer[client] = 0.0;
	g_fReleasedTimer[client] = 0.0;
	g_fDefibrillatorTimer[client] = 0.0;
	g_fGrenadeExplodeTimer[client] = 0.0;
	g_fGasCanTimer[client] = 0.0;
	g_iTickLeft[client] = g_iMaxTick;
	g_iTickDetecton[client] = 0;
	g_fPrevLatency[client] = 0.0;
	g_fTickDetectedTime[client] = 0.0;
	g_iQueryTimeout[client] = 0;
	g_hTimerQueryTimeout[client] = null;

	for (int i = 0; i < JUMP_HISTORY; i++)
	{
		g_iLastJumps[client][i] = 0;
		g_iJumpsSent[client][i] = 0;
	}
	g_iLastJumpIndex[client] = 0;
	g_iJumpsSentIndex[client] = 0;
}

/* Stocks */
stock void PrintToAdmins(const char[] message, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, message, 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			if (GetUserFlagBits(i) & ADMFLAG_BAN)
			{
				PrintToChat(i, buffer);
			}
		}
	}
}

stock void CowAC_Log(char[] message, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, message, 2);

	Handle logFile = OpenFile("addons/sourcemod/logs/CowAC_Log.txt", "a");
	WriteFileLine(logFile, buffer);
	delete logFile;
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}

public float NormalizeAngle(float angle)
{
	float newAngle = angle;
	while (newAngle <= -180.0) newAngle += 360.0;
	while (newAngle > 180.0) newAngle -= 360.0;
	return newAngle;
}

public float GetClientVelocity(int client, bool UseX, bool UseY, bool UseZ)
{
	float vVel[3];

	if(UseX)
	{
		vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	}

	if(UseY)
	{
		vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	}

	if(UseZ)
	{
		vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	}

	return GetVectorLength(vVel);
}

stock void PrintToChatOther(int ignoreClient, const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 3);

	if(!IsValidClient(ignoreClient) || GetUserFlagBits(ignoreClient) == 0)
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(i == ignoreClient || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) < 1)
				continue;

			PrintToChat(i, buffer);
		}
	}
	else
	{
		PrintToChat(ignoreClient, buffer);
	}

	LogMessage(buffer);
	CowAC_Log(buffer);
}

stock bool IsValidTarget(int entity, int team = -1)
{
	if(entity <= 0 || !IsValidEntity(entity))
		return false;

	if(entity >= 1 && entity <= MaxClients)
	{
		if(IsClientInGame(entity) && IsPlayerAlive(entity) && GetClientTeam(entity) != team)
			return true;

		return false;
	}

	char classname[64];
	GetEntityClassname(entity, classname, 64);
	if(StrEqual("witch", classname, false))
	{
		if(team > -1 && team != 2)
			return false;

		if(GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
			return true;

		return false;
	}
	else if(StrEqual("infected", classname, false))
	{
		if(team > -1 && team != 2)
			return false;

		if(GetEntProp(entity, Prop_Data, "m_iHealth") > 0 && !GetEntProp(entity, Prop_Send, "m_bIsBurning", 1))
			return true;

		return false;
	}

	return false;
}
