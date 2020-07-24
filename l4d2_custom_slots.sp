#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <regex>

public Plugin myinfo =
{
	name = "自定义槽位",
	author = "zonde306",
	description = "",
	version = "0.1",
	url = ""
};

enum struct MaxPlayerResult_t {
	int maxPlayers;
	int maxSurvivors;
	int maxZombies;
}

bool g_bIsVersus = false;
int g_iSlotMin = 999, g_iSlotMax = 0;
ConVar g_pCvarCoopSlotMin, g_pCvarCoopSlotMax, g_pCvarVersusSlotMin, g_pCvarVersusSlotMax;
ConVar g_hCvarMaxPlayers, g_hCvarMaxVisualPlayers, g_hCvarMaxSurvivor, g_hCvarMaxInfected, g_hCvarBaseSurvivor, g_hCvarExtraSurvivor, g_hCvarMaxPZ;

public void OnPluginStart()
{
	g_pCvarCoopSlotMin = CreateConVar("l4d2_slots_coop_min", "4", "合作模式最小槽位", FCVAR_NONE, true, 1.0, true, 32.0);
	g_pCvarCoopSlotMax = CreateConVar("l4d2_slots_coop_max", "4", "合作模式最大槽位", FCVAR_NONE, true, 1.0, true, 32.0);
	g_pCvarVersusSlotMin = CreateConVar("l4d2_slots_versus_min", "8", "对抗模式最小槽位", FCVAR_NONE, true, 1.0, true, 32.0);
	g_pCvarVersusSlotMax = CreateConVar("l4d2_slots_versus_max", "8", "对抗模式最大槽位", FCVAR_NONE, true, 1.0, true, 32.0);
	
	AutoExecConfig(true, "l4d2_custom_slots");
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	FindConVar("mp_gamemode").AddChangeHook(CVHook_UpdateLimit);
}

public void OnConfigsExecuted()
{
	CreateTimer(1.0, Timer_UpdateSlotLimit, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_UpdateSlotLimit, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public void CVHook_UpdateLimit(ConVar cv, const char[] ov, const char[] nv)
{
	CreateTimer(1.0, Timer_UpdateSlotLimit, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public void InitConVar()
{
	g_hCvarMaxPlayers = FindConVar("sv_maxplayers");
	g_hCvarMaxVisualPlayers = FindConVar("sv_visiblemaxplayers");
	g_hCvarMaxSurvivor = FindConVar("abm_teamlimitsur");
	g_hCvarMaxInfected = FindConVar("abm_teamlimitinf");
	g_hCvarBaseSurvivor = FindConVar("abm_minplayers");
	g_hCvarExtraSurvivor = FindConVar("abm_extraplayers");
	g_hCvarMaxPZ = FindConVar("z_max_player_zombies");
}

public Action Timer_UpdateSlotLimit(Handle timer, any unused)
{
	char map[64];
	if(GetCurrentMap(map, 64) <= 0)
		return Plugin_Continue;
	
	int entity = CreateEntityByName("info_gamemode");
	if(!IsValidEntity(entity))
		return Plugin_Continue;
	
	DispatchSpawn(entity);
	HookSingleEntityOutput(entity, "OnCoop", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnSurvival", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnVersus", OnOutput_OnGamemode, true);
	HookSingleEntityOutput(entity, "OnScavenge", OnOutput_OnGamemode, true);
	AcceptEntityInput(entity, "PostSpawnActivate");
	AcceptEntityInput(entity, "Kill");
	return Plugin_Stop;
}

public void OnOutput_OnGamemode(const char[] output, int caller, int activator, float delay)
{
	switch(output[3])
	{
		case 'o', 'u':
		{
			g_iSlotMin = g_pCvarCoopSlotMin.IntValue;
			g_iSlotMax = g_pCvarCoopSlotMax.IntValue;
			g_bIsVersus = false;
		}
		case 'e', 'c':
		{
			g_iSlotMin = g_pCvarVersusSlotMin.IntValue;
			g_iSlotMax = g_pCvarVersusSlotMax.IntValue;
			g_bIsVersus = true;
		}
		default:
		{
			// 不可能会出现的吧
			g_iSlotMin = -1;
			g_iSlotMax = -2;
			LogError("l4d2_custom_slots: unknown gamemode %s", output);
		}
	}
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if(client < 1 || client >= MaxClients || !IsClientInGame(client) || GetClientTeam(client) <= 1 || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	static char sayText[255];
	GetCmdArg(1, sayText, 255);
	
	static Regex re;
	if(re == null)
		re = CompileRegex("(\\d{1,2})slots", PCRE_CASELESS);
	
	if(re.Match(sayText) > 0 && g_iSlotMin >= g_iSlotMax)
	{
		int count = 0;
		static char matchs[8];
		if(re.GetSubString(1, matchs, 8) && matchs[0] != EOS && (g_iSlotMin <= (count = StringToInt(matchs)) <= g_iSlotMax))
		{
			MaxPlayerResult_t mpr; SetMaxPlayers(count, mpr);
			PrintToChatAll("\x03[Slots]\x01 已修改人类玩家数为 \x05%d\x01 玩家，\x05%d\x01 生还者，\x05%d\x01 感染者。", mpr.maxPlayers, mpr.maxSurvivors, mpr.maxZombies);
		}
	}
	
	return Plugin_Continue;
}

void SetMaxPlayers(int count, MaxPlayerResult_t result)
{
	if(g_hCvarMaxPlayers == null)
		InitConVar();
	
	g_hCvarMaxPlayers.IntValue = count + 1;
	g_hCvarMaxVisualPlayers.IntValue = count;
	result.maxPlayers = count;
	
	if(!g_bIsVersus)
	{
		if(g_hCvarMaxSurvivor != null)
			g_hCvarMaxSurvivor.IntValue = count;
		
		if(g_hCvarBaseSurvivor != null && g_hCvarExtraSurvivor != null)
		{
			int extra = count - g_hCvarBaseSurvivor.IntValue;
			g_hCvarExtraSurvivor.IntValue = (extra > 0 ? extra : 0);
		}
		
		result.maxSurvivors = count;
		result.maxZombies = -1;
	}
	else
	{
		int survivors = RoundToFloor(count / 2.0);
		int zombies = RoundToCeil(count / 2.0);
		
		if(g_hCvarMaxSurvivor != null)
			g_hCvarMaxSurvivor.IntValue = survivors;
		
		if(g_hCvarBaseSurvivor != null && g_hCvarExtraSurvivor != null)
		{
			g_hCvarBaseSurvivor.IntValue = survivors;
			g_hCvarExtraSurvivor.IntValue = 0;
		}
		
		if(g_hCvarMaxInfected != null)
			g_hCvarMaxInfected.IntValue = zombies;
		
		g_hCvarMaxPZ.IntValue = zombies;
		
		result.maxSurvivors = survivors;
		result.maxZombies = zombies;
	}
}
