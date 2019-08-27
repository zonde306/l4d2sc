#define PLUGIN_VERSION "1.2"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

public Plugin myinfo = 
{
	name = "萌妹随机动作",
	author = "Alex Dragokas",
	description = "Witch is appearing in the map with a random animation",
	version = PLUGIN_VERSION,
	url = "https://dragokas.com"
};

/*
	ChangeLog
	
	1.2 (15-Mar-2019)
	 - Entity index replaced by reference
	
	1.1 (22-Feb-2019)
	 - Added exclusion for witches initially spawned as a rage (e.g. on fire)
	
	1.0
	 - Initial release

*/

ConVar g_ConVarEnable;
ConVar g_ConVarChance;

int g_bEnabled;
int g_iChance;
int g_iOffsetRage;

//bool g_bLeft4Dead2;

int g_iAnim[15] = {3, 5, 10, 12, 15, 18, 23, 24, 31, 41, 43, 44, 48, 69, 70};

/*
	TODO:
	 - random anim for witch on spine

*/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead) {
		//g_bLeft4Dead1 = true;
	}
	else if (test == Engine_Left4Dead2) {
		//g_bLeft4Dead2 = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_witch_drunked_version", PLUGIN_VERSION, "Plugin version", FCVAR_DONTRECORD);

	g_ConVarEnable = CreateConVar("l4d_witch_drunked_enabled", "1", "是否开启插件", CVAR_FLAGS);
	g_ConVarChance = CreateConVar("l4d_witch_drunked_chance", "100", "出现几率", CVAR_FLAGS);

	AutoExecConfig(true, "l4d_witch_drunked");
	
	g_iOffsetRage = FindSendPropInfo("Witch", "m_rage");
	
	HookConVarChange(g_ConVarEnable,		ConVarChanged);
	HookConVarChange(g_ConVarChance,		ConVarChanged);
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_ConVarEnable.BoolValue;
	g_iChance = g_ConVarChance.IntValue;
	InitHook();
}

void InitHook()
{
	static bool bHooked;
	
	if (g_bEnabled) {
		if (!bHooked) {
			HookEvent("witch_spawn",		Event_WitchSpawn);
			bHooked = true;
		}
	} else {
		if (bHooked) {
			UnhookEvent("witch_spawn",		Event_WitchSpawn);
			bHooked = false;
		}
	}
}

public Action Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	int UserId = event.GetInt("witchid");
	
	if( UserId != 0 ) {
		if (GetRandomInt(1, 100) <= g_iChance)
		{
			CreateTimer(1.1, Timer_MakeAnim, EntIndexToEntRef(UserId), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action Timer_MakeAnim(Handle timer, int iEntRef)
{
	int UserId = EntRefToEntIndex(iEntRef);
	
	if (UserId && UserId != INVALID_ENT_REFERENCE && IsValidEntity(UserId))
	{
		/*
		if (g_bLeft4Dead2) {
			fRage = GetEntPropFloat(UserId, Prop_Send, "m_wanderrage");
		}
		else {
			//fRage = GetEntPropFloat(UserId, Prop_Data, "m_rage");
			fRage = GetEntDataFloat(UserId, g_iOffsetRage);
		}*/
		float fRage = GetEntDataFloat(UserId, g_iOffsetRage);
		
		if (fRage != 1.0)
		{
			SetEntProp(UserId, Prop_Send, "m_nSequence", g_iAnim[GetRandomInt(0, sizeof(g_iAnim) - 1)]);
		}
	}
}