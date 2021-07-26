#define PLUGIN_VERSION "1.4"

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6
int ZOMBIECLASS_TANK = 0;

public Plugin myinfo = 
{
	name = "刷怪数量限制",
	author = "Dragokas",
	description = "Limits the number of common zombies & infected bots allowed to spawn simultaneously",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas"
};

char CLASS_INFECTED[] = "infected";
char CLASS_WITCH[] = "witch";

bool g_bEnabled, g_bLeft4Dead2, g_bMapStarted, g_bLateload;
int g_iCommon, g_iBoomer, g_iHunter, g_iSmoker, g_iJockey, g_iSpitter, g_iCharger, g_iTank, g_iSI, g_iWitch, g_iZombieType[MAXPLAYERS+1];
int g_iCommonLimit, g_iBoomerLimit, g_iHunterLimit, g_iSmokerLimit, g_iJockeyLimit, g_iSpitterLimit, g_iChargerLimit, g_iTankLimit, g_iSILimit, g_iWitchLimit;
ConVar g_hCvarEnable, g_hCvarBoomer, g_hCvarHunter, g_hCvarSmoker, g_hCvarJockey, g_hCvarSpitter, g_hCvarCharger, g_hCvarTank, g_hCvarSI, g_hCvarCommon, g_hCvarWitch;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead2 ) {
		g_bLeft4Dead2 = true;
		ZOMBIECLASS_TANK = 8;
	}
	else if( test == Engine_Left4Dead ) {
		ZOMBIECLASS_TANK = 5;
	}
	else {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_zombie_limits_version", PLUGIN_VERSION, "Plugin version", FCVAR_DONTRECORD | CVAR_FLAGS);

	g_hCvarEnable = CreateConVar(	"l4d_zombie_limits_enabled", 	"1", "是否开启插件", CVAR_FLAGS);
	g_hCvarBoomer = CreateConVar(	"l4d_zombie_limits_boomer", 	"7", "胖子数量上限", CVAR_FLAGS);
	g_hCvarHunter = CreateConVar(	"l4d_zombie_limits_hunter", 	"7", "猎人数量上限", CVAR_FLAGS);
	g_hCvarSmoker = CreateConVar(	"l4d_zombie_limits_smoker", 	"7", "舌头数量上限", CVAR_FLAGS);
	if( g_bLeft4Dead2 )
	{
		g_hCvarJockey = CreateConVar(	"l4d_zombie_limits_jockey", 	"7", "猴子数量上限", CVAR_FLAGS);
		g_hCvarSpitter = CreateConVar(	"l4d_zombie_limits_spitter", 	"7", "口水数量上限", CVAR_FLAGS);
		g_hCvarCharger = CreateConVar(	"l4d_zombie_limits_charger", 	"7", "牛数量上限", CVAR_FLAGS);
	}
	g_hCvarTank = CreateConVar(		"l4d_zombie_limits_tank", 		"10", "克数量上限", CVAR_FLAGS);
	g_hCvarSI = CreateConVar(		"l4d_zombie_limits_si", 		"12", "特感数量上限(不含克)", CVAR_FLAGS);
	g_hCvarCommon = CreateConVar(	"l4d_zombie_limits_common", 	"40", "普感数量上限", CVAR_FLAGS);
	g_hCvarWitch = CreateConVar(	"l4d_zombie_limits_witch", 		"10", "萌妹数量上限", CVAR_FLAGS);
	
	AutoExecConfig(true, "l4d_zombie_limits");
	
	GetCvars();
	
	g_hCvarEnable.AddChangeHook(OnCvarChanged);
	g_hCvarBoomer.AddChangeHook(OnCvarChanged);
	g_hCvarHunter.AddChangeHook(OnCvarChanged);
	g_hCvarSmoker.AddChangeHook(OnCvarChanged);
	if( g_bLeft4Dead2 )
	{
		g_hCvarJockey.AddChangeHook(OnCvarChanged);
		g_hCvarSpitter.AddChangeHook(OnCvarChanged);
		g_hCvarCharger.AddChangeHook(OnCvarChanged);
	}
	g_hCvarTank.AddChangeHook(OnCvarChanged);
	g_hCvarSI.AddChangeHook(OnCvarChanged);
	g_hCvarCommon.AddChangeHook(OnCvarChanged);
	g_hCvarWitch.AddChangeHook(OnCvarChanged);
	
	RegAdminCmd("sm_zcount", CmdCount, ADMFLAG_ROOT, "Show the current number of each zombie type");
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	if( g_bEnabled && convar == g_hCvarEnable )
	{
		UpdateCount();
	}
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;
	g_iCommonLimit = g_hCvarCommon.IntValue;
	g_iSILimit = g_hCvarSI.IntValue;
	g_iBoomerLimit = g_hCvarBoomer.IntValue;
	g_iHunterLimit = g_hCvarHunter.IntValue;
	g_iSmokerLimit = g_hCvarSmoker.IntValue;
	if( g_bLeft4Dead2 )
	{
		g_iSpitterLimit = g_hCvarSpitter.IntValue;
		g_iJockeyLimit = g_hCvarJockey.IntValue;
		g_iChargerLimit = g_hCvarCharger.IntValue;
	}
	g_iTankLimit = g_hCvarTank.IntValue;
	g_iWitchLimit = g_hCvarWitch.IntValue;
	
	InitHook();
}

void InitHook()
{
	static bool bHooked;
	
	if( g_bEnabled ) {
		if( !bHooked ) {
			HookEvent("player_spawn",			Event_PlayerSpawn);
			HookEvent("witch_spawn",			Event_WitchSpawn);
			bHooked = true;
		}
	} else {
		if( bHooked ) {
			UnhookEvent("player_spawn",			Event_PlayerSpawn);
			UnhookEvent("witch_spawn",			Event_WitchSpawn);
			bHooked = false;
		}
	}
}

public Action CmdCount(int client, int argc)
{
	UpdateCount();
	
	if( g_bLeft4Dead2 )
	{
		PrintToChat(client, "Charger: \x04 %i\n" ...
						"Jockey: \x04 %i\n" ...
						"Spitter: \x04 %i", g_iCharger, g_iJockey, g_iSpitter);
	}
	
	PrintToChat(client, "Boomer: \x04 %i\n" ...
						"Smoker: \x04 %i\n" ...
						"Hunter: \x04 %i\n" ...
						"Tank: \x04 %i\n" ...
						"SI: \x04 %i\n" ...
						"Common: \x04 %i\n" ...
						"Witch: \x04 %i", g_iBoomer, g_iSmoker, g_iHunter, g_iTank, g_iSI, g_iCommon, g_iWitch);
	
	return Plugin_Handled;
}

void UpdateCount()
{
	ResetCount();
	
	int ent = -1;
	while( -1 != (ent = FindEntityByClassname(ent, CLASS_INFECTED)) )
	{
		++ g_iCommon;
	}
	ent = -1;
	while( -1 != (ent = FindEntityByClassname(ent, CLASS_WITCH)) )
	{
		++ g_iWitch;
	}
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsFakeClient(i) )
		{
			int class = GetEntProp(i, Prop_Send, "m_zombieClass");
			if( class == ZOMBIECLASS_SMOKER ) 		{ ++ g_iSI; ++ g_iSmoker; }
			else if( class == ZOMBIECLASS_BOOMER ) 	{ ++ g_iSI; ++ g_iBoomer; }
			else if( class == ZOMBIECLASS_HUNTER ) 	{ ++ g_iSI; ++ g_iHunter; }
			else if( class == ZOMBIECLASS_TANK )	{ ++ g_iSI; ++ g_iTank; }
			else if( g_bLeft4Dead2 )
			{
				if( class == ZOMBIECLASS_SPITTER )		{ ++ g_iSI; ++ g_iSpitter; }
				else if( class == ZOMBIECLASS_JOCKEY )	{ ++ g_iSI; ++ g_iJockey; }
				else if( class == ZOMBIECLASS_CHARGER )	{ ++ g_iSI; ++ g_iCharger; }
			}
		}
	}
}

void ResetCount()
{
	g_iSI = 0;
	g_iCommon = 0;
	g_iBoomer = 0;
	g_iHunter = 0;
	g_iSmoker = 0;
	g_iSpitter = 0;
	g_iJockey = 0;
	g_iCharger = 0;
	g_iTank = 0;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && IsClientInGame(client) && IsFakeClient(client) )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		g_iZombieType[client] = class;
		if( class == ZOMBIECLASS_SMOKER ) 		{ ++ g_iSI; ++ g_iSmoker; 		CheckMax(client, g_iSmoker, g_iSmokerLimit); }
		else if( class == ZOMBIECLASS_BOOMER ) 	{ ++ g_iSI; ++ g_iBoomer; 		CheckMax(client, g_iBoomer, g_iBoomerLimit); }
		else if( class == ZOMBIECLASS_HUNTER ) 	{ ++ g_iSI; ++ g_iHunter;		CheckMax(client, g_iHunter, g_iHunterLimit); }
		else if( class == ZOMBIECLASS_TANK )	{
			++ g_iTank;
			if( g_iTank > g_iTankLimit ) { 
				KillClient(client);
				PrintToChatAll("Tank killed. Over limit! %i > %i", g_iTank, g_iTankLimit);
			} 
		}
		else if( g_bLeft4Dead2 )
		{
			if( class == ZOMBIECLASS_SPITTER )		{ ++ g_iSI; ++ g_iSpitter;	CheckMax(client, g_iSpitter, g_iSpitterLimit); }
			else if( class == ZOMBIECLASS_JOCKEY )	{ ++ g_iSI; ++ g_iJockey;	CheckMax(client, g_iJockey, g_iJockeyLimit); }
			else if( class == ZOMBIECLASS_CHARGER )	{ ++ g_iSI; ++ g_iCharger;	CheckMax(client, g_iCharger, g_iChargerLimit); }
		}
	}
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	++ g_iWitch;
	if( g_iWitch > g_iWitchLimit )
	{
		CreateTimer(0.1, Timer_KillWitch, EntIndexToEntRef(event.GetInt("witchid")), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_KillWitch(Handle timer, int ref)
{
	int witch = EntRefToEntIndex(ref);
	if( witch && witch != INVALID_ENT_REFERENCE )
	{
		RemoveEntity(witch);
	}
}

void CheckMax(int client, int iCount, int iCountLimit)
{
	if( iCount > iCountLimit )
	{
		KillClient(client);
		return;
	}
	if( g_iSI > g_iSILimit )
	{
		KillClient(client);
	}
}

void KillClient(int client)
{
	CreateTimer(0.1, Timer_KillClient, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); // prevents smoker particles infinite cycle
}

public Action Timer_KillClient(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if( client && IsClientInGame(client) )
	{
		RemoveEntity(client);
	}
}

public void OnClientDisconnect(int client)
{
	if( client )
	{
		int class = g_iZombieType[client];
		if( class == ZOMBIECLASS_SMOKER ) 		{ -- g_iSI; -- g_iSmoker; }
		else if( class == ZOMBIECLASS_BOOMER ) 	{ -- g_iSI; -- g_iBoomer; }
		else if( class == ZOMBIECLASS_HUNTER ) 	{ -- g_iSI; -- g_iHunter; }
		else if( class == ZOMBIECLASS_TANK )	{ 			-- g_iTank; }
		else if( g_bLeft4Dead2 )
		{
			if( class == ZOMBIECLASS_SPITTER )		{ -- g_iSI; -- g_iSpitter; }
			else if( class == ZOMBIECLASS_JOCKEY )	{ -- g_iSI; -- g_iJockey; }
			else if( class == ZOMBIECLASS_CHARGER )	{ -- g_iSI; -- g_iCharger; }
		}
	}
}

public void OnMapStart()
{
	ResetCount();
	g_bMapStarted = true;
	
	if( g_bLateload )
	{
		g_bLateload = false;
		UpdateCount();
	}
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bMapStarted && g_bEnabled )
	{
		if( strcmp(classname, CLASS_INFECTED) == 0 )
		{
			++ g_iCommon;
			if( g_iCommon > g_iCommonLimit )
			{
				SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
			}
		}
	}
}

public Action OnSpawnPost(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if( entity != INVALID_ENT_REFERENCE )
	{
		RemoveEntity(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	static char class[32];
	if( g_bMapStarted && g_bEnabled )
	{
		if( entity != INVALID_ENT_REFERENCE )
		{
			GetEntityClassname(entity, class, sizeof(class));
			if( class[0] == 'i' || class[0] == 'w' )
			{
				if( strcmp(class, CLASS_INFECTED) == 0 )
				{
					-- g_iCommon;
				}
				else if( strcmp(class, CLASS_WITCH) == 0 )
				{
					-- g_iWitch;
				}
			}
		}
	}
}
