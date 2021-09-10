#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION			"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "刷特感",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

bool g_bLateLoad;
ConVar g_pCvarFirstInterval, g_pCvarInterval, g_pCvarCount, g_pCvarMaxCount, g_pCvarMaxSpecials[Z_WITCH], g_pCvarChanceSpecials[Z_WITCH];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	InitPlugin("sss");
	g_pCvarFirstInterval = CreateConVar("l4d2_sss_first_interval", "16.0", "首次刷特间隔(秒)", CVAR_FLAGS, true, 0.01);
	g_pCvarInterval = CreateConVar("l4d2_sss_interval", "9.0", "刷特间隔(秒)", CVAR_FLAGS, true, 0.01);
	g_pCvarCount = CreateConVar("l4d2_sss_count", "1", "刷特数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxCount = CreateConVar("l4d2_sss_count_max", "4", "特感上限", CVAR_FLAGS, true, 1.0, true, 32.0);
	g_pCvarMaxSpecials[Z_SMOKER] = CreateConVar("l4d2_sss_smoker_max", "1", "舌头数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxSpecials[Z_BOOMER] = CreateConVar("l4d2_sss_boomer_max", "1", "胖子数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxSpecials[Z_HUNTER] = CreateConVar("l4d2_sss_hunter_max", "1", "猎人数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxSpecials[Z_SPITTER] = CreateConVar("l4d2_sss_spitter_max", "1", "口水数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxSpecials[Z_JOCKEY] = CreateConVar("l4d2_sss_jockey_max", "1", "猴子数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarMaxSpecials[Z_CHARGER] = CreateConVar("l4d2_sss_charger_max", "1", "牛数量上限", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_pCvarChanceSpecials[Z_SMOKER] = CreateConVar("l4d2_sss_smoker_chance", "100", "舌头出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarChanceSpecials[Z_BOOMER] = CreateConVar("l4d2_sss_boomer_chance", "100", "胖子出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarChanceSpecials[Z_HUNTER] = CreateConVar("l4d2_sss_hunter_chance", "100", "猎人出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarChanceSpecials[Z_SPITTER] = CreateConVar("l4d2_sss_spitter_chance", "100", "口水出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarChanceSpecials[Z_JOCKEY] = CreateConVar("l4d2_sss_jockey_chance", "100", "猴子出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	g_pCvarChanceSpecials[Z_CHARGER] = CreateConVar("l4d2_sss_charger_chance", "100", "牛出现几率", CVAR_FLAGS, true, 0.0, true, 2147483647.0);
	
	AutoExecConfig(true, "l4d2_simple_special_spawnner");
	
	CvarHook_OnChanged(null, "", "");
	g_pCvarFirstInterval.AddChangeHook(CvarHook_OnChanged);
	g_pCvarInterval.AddChangeHook(CvarHook_OnChanged);
	g_pCvarCount.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxCount.AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_SMOKER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_BOOMER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_HUNTER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_SPITTER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_JOCKEY].AddChangeHook(CvarHook_OnChanged);
	g_pCvarMaxSpecials[Z_CHARGER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_SMOKER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_BOOMER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_HUNTER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_SPITTER].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_JOCKEY].AddChangeHook(CvarHook_OnChanged);
	g_pCvarChanceSpecials[Z_CHARGER].AddChangeHook(CvarHook_OnChanged);
	
	HookEvent("player_left_start_area", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("start_holdout", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_pre_entity", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_post_nav", Event_RoundEnd, EventHookMode_PostNoCopy);
	
	if(g_bLateLoad)
	{
		if(L4D_HasAnySurvivorLeftSafeArea())
			TryActiveSpawnQueue();
	}
}

/*
******************************************
*	ConVars
******************************************
*/

float g_fFirstInterval, g_fInterval;
int g_iCount, g_iMaxCount, g_iTotalChance, g_iMaxSpecials[Z_WITCH], g_iChanceSpecials[Z_WITCH];
int g_iCacheZombies[] = { Z_SMOKER, Z_BOOMER, Z_HUNTER, Z_SPITTER, Z_JOCKEY, Z_CHARGER };

public void CvarHook_OnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fFirstInterval = g_pCvarFirstInterval.FloatValue;
	g_fInterval = g_pCvarInterval.FloatValue;
	g_iCount = g_pCvarCount.IntValue;
	g_iMaxCount = g_pCvarMaxCount.IntValue;
	
	g_iTotalChance = 0;
	g_iMaxSpecials[Z_COMMON] = 0;
	g_iChanceSpecials[Z_COMMON] = 0;
	for(int i = Z_SMOKER; i < Z_WITCH; ++i)
	{
		g_iMaxSpecials[i] = g_pCvarMaxSpecials[i].IntValue;
		g_iChanceSpecials[i] = g_pCvarChanceSpecials[i].IntValue;
		g_iTotalChance += g_iChanceSpecials[i];
	}
}

/*
******************************************
*	Events
******************************************
*/

bool g_bIsSurvivalMode = false;
Handle g_hTimerSpawnQueue = null;
Handle g_hTimerQueuedSpawnner = null;

public void Event_RoundStart(Event event, const char[] event_name, bool dontBroadcast)
{
	if(StrEqual(event_name, "survival_round_start", false))
		g_bIsSurvivalMode = true;
	
	TryActiveSpawnQueue();
}

public void Event_RoundEnd(Event event, const char[] event_name, bool dontBroadcast)
{
	Handle deleteme1 = null, deleteme2 = null;
	
	if(g_hTimerSpawnQueue != null)
	{
		deleteme1 = g_hTimerSpawnQueue;
		g_hTimerSpawnQueue = null;
	}
	
	if(g_hTimerQueuedSpawnner != null)
	{
		deleteme2 = g_hTimerQueuedSpawnner;
		g_hTimerQueuedSpawnner = null;
	}
	
	if(deleteme1)
		KillTimer(deleteme1);
	if(deleteme2)
		KillTimer(deleteme2);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	TryActiveSpawnQueue();
	return Plugin_Continue;
}

/*
******************************************
*	Starter
******************************************
*/

void TryActiveSpawnQueue()
{
	int entity = CreateEntityByName("info_gamemode");
	if(entity > MaxClients)
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemodeCoop, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemodeSurvival, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemodeVersus, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemodeVersus, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		RemoveEntity(entity);
	}
	else
	{
		static ConVar mp_gamemode;
		if(mp_gamemode == null)
			mp_gamemode = FindConVar("mp_gamemode");
		
		static char gamemode[64];
		mp_gamemode.GetString(gamemode, sizeof(gamemode));
		if(StrContains(gamemode, "versus", false) != -1 || StrContains(gamemode, "scavenge", false) != -1)
		{
			SetFailState("Plugin does not support PvP modes");
		}
		else if(StrContains(gamemode, "survival", false) != -1 || StrContains(gamemode, "holdout", false) != -1)
		{
			// 稍后开始
		}
		else
		{
			if(g_hTimerSpawnQueue == null)
				g_hTimerSpawnQueue = CreateTimer(g_fFirstInterval, Timer_ActiveSpawnner, 1);
		}
	}
}

public void OnGamemodeCoop(const char[] output, int caller, int activator, float delay)
{
	if(g_hTimerSpawnQueue == null)
		g_hTimerSpawnQueue = CreateTimer(g_fFirstInterval, Timer_ActiveSpawnner, 1);
}

public void OnGamemodeSurvival(const char[] output, int caller, int activator, float delay)
{
	if(g_bIsSurvivalMode)
	{
		if(g_hTimerSpawnQueue == null)
			g_hTimerSpawnQueue = CreateTimer(g_fFirstInterval, Timer_ActiveSpawnner, 1);
	}
}

public void OnGamemodeVersus(const char[] output, int caller, int activator, float delay)
{
	// SetFailState("Plugin does not support PvP modes");
}

public Action Timer_ActiveSpawnner(Handle timer, any first)
{
	QueueSpawnner();
	
	if(first)
		g_hTimerSpawnQueue = CreateTimer(g_fInterval, Timer_ActiveSpawnner, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

/*
******************************************
*	Spawnner
******************************************
*/

int g_iQueuedToSpawn = 0;

void QueueSpawnner()
{
	int zombies = 0;
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 3)
			continue;
		
		int zClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if(zClass < Z_SMOKER || zClass > Z_CHARGER)
			continue;
		
		zombies += 1;
	}
	
	if(zombies >= g_iMaxCount)
		return;
	
	g_iQueuedToSpawn = g_iCount;
	
	if(g_hTimerQueuedSpawnner == null)
		g_hTimerQueuedSpawnner = CreateTimer(0.1, Timer_SpawnQueue, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SpawnQueue(Handle timer, any unused)
{
	if(g_iQueuedToSpawn <= 0 || !IsPluginAllow())
	{
		g_hTimerQueuedSpawnner = null;
		return Plugin_Stop;
	}
	
	g_iQueuedToSpawn -= 1;
	
	int special = GetRandomSpecial();
	if(special > 0)
		SpawnCommand(special);
	
	return Plugin_Continue;
}

/*
******************************************
*	Misc.
******************************************
*/

stock int GetRandomSurvivor()
{
	int count = 0;
	int survivors[MAXPLAYERS];
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidAliveClient(i) && GetClientTeam(i) == 2)
			survivors[count++] = i;
	
	SortIntegers(survivors, count, Sort_Random);
	return survivors[0];
}

stock int SpawnCommand(int zClass)
{
	L4D2_ExecVScriptCode(tr(
		"local a={"
			..."'cm_DominatorLimit':null,"
			..."'cm_MaxSpecials':null,"
			..."'MaxSpecials':null,"
			..."'SmokerLimit':null,"
			..."'BoomerLimit':null,"
			..."'HunterLimit':null,"
			..."'SpitterLimit':null,"
			..."'JockeyLimit':null,"
			..."'ChargerLimit':null,"
			..."'WitchLimit':null,"
			..."'cm_WitchLimit':null,"
			..."'TankLimit':null,"
			..."'cm_TankLimit':null,"
		..."};"
		..."foreach(k,v in a){"
			..."if(k in SessionOptions&&SessionOptions[k]!=null)"
				..."a[key]=v;"
			..."SessionOptions[k]<-99;"
		..."}"
		..."ZSpawn({'type':%d});"
		..."foreach(k,v in a){"
			..."if(v!=null)"
				..."SessionOptions[k]<-v;"
			..."else "
				..."delete SessionOptions[k];"
		..."}",
		zClass
	));
	
	return -1;
}

stock int GetRandomSpecial()
{
	int zombies[Z_WITCH];
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidAliveClient(i) || GetClientTeam(i) != 3)
			continue;
		
		int zClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if(zClass < Z_SMOKER || zClass > Z_CHARGER)
			continue;
		
		zombies[zClass] += 1;
	}
	
	int number = GetRandomInt(1, g_iTotalChance);
	SortIntegers(g_iCacheZombies, sizeof(g_iCacheZombies), Sort_Random);
	
	// 根据优先级选择
	for(int i = 0; i < sizeof(g_iCacheZombies); ++i)
	{
		int zClass = g_iCacheZombies[i];
		
		number -= g_iChanceSpecials[zClass];
		if(number > 0)
			continue;
		
		if(zombies[zClass] >= g_iMaxSpecials[zClass])
			continue;
		
		return zClass;
	}
	
	// 优先选择失败，随机选择
	for(int i = 0; i < sizeof(g_iCacheZombies); ++i)
	{
		int zClass = g_iCacheZombies[i];
		
		if(zombies[zClass] >= g_iMaxSpecials[zClass])
			continue;
		
		return zClass;
	}
	
	// 位置已满
	return -1;
}
