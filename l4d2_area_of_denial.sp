#define PLUGIN_VERSION		"1.2"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Area of Denial
*	Author	:	SilverShot
*	Descrp	:	Removes spitter acid and damage from players in restricted areas or slays them.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=157053
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (10-May-2012)
	- Limited the plugin to all survival modes only.
	- Fixed a rare bug which could crash the server.
	- Debug logging turned off. Set DEBUG 1 in source to turn on.

1.0 (15-May-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS		FCVAR_NOTIFY
#define DEBUG			0

ConVar g_hCvarEnable, g_hCvarMPGameMode, g_hCvarPrint;
int g_iCvarEnable, g_iSurvivalMode;
bool g_bAllow;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "生存删除限制区口水",
	author = "SilverShot",
	description = "Removes spitter acid and damage from players in restricted areas or slays them.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=157053"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarEnable =		CreateConVar(	"l4d2_area_of_denial_enable",	"2",			"0=Off, 1=Remove spit and prevent damage to player, 2=Slay player.", CVAR_FLAGS);
	g_hCvarPrint =		CreateConVar(	"l4d2_area_of_denial_print",	"1",			"Show in chat when someone is slayed. 0=Off, 1=To all. 2=To victim.", CVAR_FLAGS);
	CreateConVar(						"l4d2_area_of_denial_version",	PLUGIN_VERSION,	"Area of Denial plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true, 				"l4d2_area_of_denial");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allows);
	g_hCvarEnable.AddChangeHook(ConVarChanged_Allows);
}

public void ConVarChanged_Allows(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	g_iCvarEnable = g_hCvarEnable.IntValue;
	g_iSurvivalMode = 0;

	int entity = CreateEntityByName("info_gamemode");
	DispatchSpawn(entity);
	HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "PostSpawnActivate");
	AcceptEntityInput(entity, "Kill");

	if( g_bAllow == false && g_iCvarEnable && g_iSurvivalMode == 1 )
	{
		g_bAllow = true;
		HookPlayers(true);
	}

	else if( g_bAllow == true && (g_iCvarEnable == 0 || g_iSurvivalMode == 0) )
	{
		g_bAllow = false;
		HookPlayers(false);
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	g_iSurvivalMode = 1;
}

void HookPlayers(bool hook)
{
	for( int i = 1; i <= MaxClients; i++ )
		if( IsClientInGame(i) )
			if( hook )
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			else
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientPostAdminCheck(int client)
{
	if( g_bAllow )
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( victim == attacker && damagetype == 0 && damage == 10 && IsValidClient(victim) )
	{
		#if DEBUG == 1
			if( g_iCvarEnable == 2 )
			{
				float vPos[3];
				GetClientAbsOrigin(victim, vPos);
				LogCustom("Slayed player %d) %N @{ %0.1f %0.1f %0.1f }", victim, victim, vPos[0], vPos[1], vPos[2]);
			}
		#endif

		if( g_iCvarEnable == 2 )
		{
			ForcePlayerSuicide(victim);

			int print = g_hCvarPrint.IntValue;
			if( print == 1 )
				PrintToChatAll("\x03[Area Of Denial] \x01Slayed \x05'%N' \x01for being out of bounds.", victim);
			else if( print == 2 )
				PrintToChat(victim, "\x03[Area Of Denial] \x01Slayed for being out of bounds.");
		}
		else
			damage = 0.0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bAllow && g_iCvarEnable == 1 && strcmp(classname, "spitter_projectile") == 0 )
		CreateTimer(0.1, tmrSpit, EntIndexToEntRef(entity));
}

public Action tmrSpit(Handle timer, any entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if( IsValidClient(client) )
		{
			#if DEBUG == 1
				float vPos[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
				LogCustom("Removed spit from %d) %N @{ %0.1f %0.1f %0.1f }", client, client, vPos[0], vPos[1], vPos[2]);
			#endif
			AcceptEntityInput(entity, "kill");
		}
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock void LogCustom(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);

	Handle file;
	char FileName[PLATFORM_MAX_PATH], sTime[32];
	BuildPath(Path_SM, FileName, sizeof(FileName), "logs/area_of_denial.log");
	file = OpenFile(FileName, "a+");
	FormatTime(sTime, sizeof(sTime), "%d-%b-%Y %H:%M:%S");
	file.WriteLine("%s: %s", sTime, buffer);
	PrintToServer("%s: %s", sTime, buffer);
	FlushFile(file);
	delete file;
}