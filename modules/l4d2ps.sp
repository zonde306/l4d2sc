#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS				FCVAR_NONE
#define IsValidClient(%1) 		((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(IsValidClient(%1) && IsPlayerAlive(%1))

enum GameMode_t
{
	GMF_NONE = 0,
	GMF_COOP = (1 << 0),		// 合作类型
	GMF_SURVIVAL = (1 << 1),	// 生存类型
	GMF_VERSUS = (1 << 2),		// 对抗类型
	GMF_SCAVENGE = (1 << 4)		// 清道夫类型
};

int g_iAllowPluginMode;
GameMode_t g_iGameModeFlags;
Handle g_hTimerCheckGameMode;
ConVar g_pCvarAllow, g_pCvarAllowMode, g_pCvarEnableMode, g_pCvarDisableMode;
bool g_bAllowByPlugin, g_bAllowByMode;

const int Z_COMMON = 0;
const int Z_INFECTED = 0;
const int Z_SMOKER = 1;
const int Z_BOOMER = 2;
const int Z_HUNTER = 3;
const int Z_SPITTER = 4;
const int Z_JOCKEY = 5;
const int Z_CHARGER = 6;
const int Z_WITCH = 7;
const int Z_TANK = 8;
const int Z_SURVIVOR = 9;
const int Z_L4D1_SURVIVOR = 10;

const int AMMOTYPE_PISTOL = 1;
const int AMMOTYPE_MAGNUM = 2;
const int AMMOTYPE_ASSAULTRIFLE = 3;
const int AMMOTYPE_MINIGUN = 4;
const int AMMOTYPE_SMG = 5;
const int AMMOTYPE_M60 = 6;
const int AMMOTYPE_SHOTGUN = 7;
const int AMMOTYPE_AUTOSHOTGUN = 8;
const int AMMOTYPE_HUNTINGRIFLE = 9;
const int AMMOTYPE_SNIPERRIFLE = 10;
const int AMMOTYPE_TURRET = 11;
const int AMMOTYPE_PIPEBOMB = 12;
const int AMMOTYPE_MOLOTOV = 13;
const int AMMOTYPE_VOMITJAR = 14;
const int AMMOTYPE_PAINPILLS = 15;
const int AMMOTYPE_FIRSTAID = 16;
const int AMMOTYPE_GRENADELAUNCHER = 17;
const int AMMOTYPE_ADRENALINE = 18;
const int AMMOTYPE_CHAINSAW = 19;

const int HITGROUP_GENERIC = 0;
const int HITGROUP_HEAD = 1;
const int HITGROUP_CHEST = 2;
const int HITGROUP_STOMACH = 3;
const int HITGROUP_LEFTARM = 4;
const int HITGROUP_RIGHTARM = 5;
const int HITGROUP_LEFTLEG = 6;
const int HITGROUP_RIGHTLEG = 7;
const int HITGROUP_GEAR = 10;		// alerts NPC; but doesn't do damage or bleed (1/100th damage)

const int DMG_CHOKE = (1 << 20);
const int DMG_MELEE = (1 << 21);
const int DMG_STUMBLE = (1 << 25);
const int DMG_HEADSHOT = (1 << 30);
const int DMG_DISMEMBER = (1 << 31);

const int DAMAGE_NO = 0;
const int DAMAGE_EVENTS_ONLY = 1;
const int DAMAGE_YES = 2;
const int DAMAGE_AIM = 3;

stock bool IsPluginAllow()
{
	if(!g_bAllowByPlugin || !g_bAllowByMode)
		return false;
	
	if(!(g_iAllowPluginMode & view_as<int>(g_iGameModeFlags)))
		return false;
	
	return true;
}

stock void InitPlugin(const char[] prefix)
{
	CreateConVar(tr("l4d2_%s_version", prefix), PLUGIN_VERSION, "插件版本", CVAR_FLAGS);
	g_pCvarAllow = CreateConVar(tr("l4d2_%s_allow", prefix), "1", "是否开启插件(主开关)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarAllowMode = CreateConVar(tr("l4d2_%s_allow_mode", prefix), "15", "开启插件的模式\n0=禁用.1=战役/写实.2=生存.4=对抗.8=清道夫.15=全部", CVAR_FLAGS, true, 0.0, true, 15.0);
	g_pCvarEnableMode = CreateConVar(tr("l4d2_%s_enable_mode", prefix), "", "开启插件的模式(相对于 mp_gamemode)使用半角逗号隔开.空=全部", CVAR_FLAGS, true, 0.0, true, 15.0);
	g_pCvarDisableMode = CreateConVar(tr("l4d2_%s_disable_mode", prefix), "", "关闭插件的模式(相对于 mp_gamemode)使用半角逗号隔开.空=没有", CVAR_FLAGS, true, 0.0, true, 15.0);
	HookEvent("round_start", Event_psRoundStart, EventHookMode_PostNoCopy);
	
	ConVarHooked_psOnPluginState(null, "", "");
	g_pCvarAllow.AddChangeHook(ConVarHooked_psOnPluginState);
	g_pCvarAllowMode.AddChangeHook(ConVarHooked_psOnPluginState);
	g_pCvarEnableMode.AddChangeHook(ConVarHooked_psOnPluginState);
	g_pCvarDisableMode.AddChangeHook(ConVarHooked_psOnPluginState);
	
	ConVar gamemode = FindConVar("mp_gamemode");
	if(gamemode)
		gamemode.AddChangeHook(ConVarHooked_psOnGameModeUpdate);
}

stock char[] tr(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);
	return buffer;
}

public void OnConfigsExecuted()
{
	Timer_CheckGameMode(null, 0);
}

public void ConVarHooked_psOnGameModeUpdate(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	static ConVar mp_gamemode;
	if(!mp_gamemode)
		mp_gamemode = FindConVar("mp_gamemode");
	
	g_bAllowByMode = true;
	
	char currentMode[24];
	mp_gamemode.GetString(currentMode, 24);
	
	char enableMode[255];
	g_pCvarEnableMode.GetString(enableMode, 255);
	if(enableMode[0] != EOS)
	{
		char mode[16][24];
		int numMode = ExplodeString(enableMode, ",", mode, 16, 24);
		for(int i = 0; i < numMode; ++i)
		{
			TrimString(mode[i]);
			if(StrEqual(mode[i], currentMode, false))
			{
				g_bAllowByMode = true;
				return;
			}
		}
	}
	
	char disableMode[255];
	g_pCvarDisableMode.GetString(disableMode, 255);
	if(disableMode[0] != EOS)
	{
		char mode[16][24];
		int numMode = ExplodeString(disableMode, ",", mode, 16, 24);
		for(int i = 0; i < numMode; ++i)
		{
			TrimString(mode[i]);
			if(StrEqual(mode[i], currentMode, false))
			{
				g_bAllowByMode = false;
				return;
			}
		}
	}
}

public void ConVarHooked_psOnPluginState(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_bAllowByPlugin = g_pCvarAllow.BoolValue;
	g_iAllowPluginMode = g_pCvarAllowMode.IntValue;
}

public void Event_psRoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	if(g_hTimerCheckGameMode != null)
		KillTimer(g_hTimerCheckGameMode);
	
	g_hTimerCheckGameMode = CreateTimer(1.0, Timer_CheckGameMode);
	ConVarHooked_psOnGameModeUpdate(null, "", "");
}

public Action Timer_CheckGameMode(Handle timer, any unused)
{
	g_hTimerCheckGameMode = null;
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
		case 'o':
			g_iGameModeFlags = GMF_COOP;
		case 'u':
			g_iGameModeFlags = GMF_SURVIVAL;
		case 'e':
			g_iGameModeFlags = GMF_VERSUS;
		case 'c':
			g_iGameModeFlags = GMF_SCAVENGE;
		default:
			g_iGameModeFlags = GMF_NONE;
	}
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
		FakeClientCommand(client, "%s %s", command, fmt);
		SetUserFlagBits(client, adminFlags);
	}
	else
	{
		ServerCommand("%s %s", command, fmt);
	}

	SetCommandFlags(command, cmdFlags);

	return true;
}
