#include <sourcemod>
#include <sdktools>
#include "left4downtown.inc"

#define UNRESERVE_VERSION "1.1.2"

#define UNRESERVE_DEBUG 0
#define UNRESERVE_DEBUG_LOG 0

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)

#define L4D_MAXHUMANS_LOBBY_VERSUS 8
#define L4D_MAXHUMANS_LOBBY_OTHER 4

new Handle:cvarGameMode = INVALID_HANDLE;
new Handle:cvarFixEmpty = INVALID_HANDLE;
new Handle:cvarPutinLobby = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "修复无法从大厅加入服务器",
	author = "Downtown1",
	description = "Removes lobby reservation when server is full",
	version = UNRESERVE_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

new Handle:cvarUnreserve = INVALID_HANDLE;

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_unreserve", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
	RegAdminCmd("sm_lobby", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
	
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_NONE);
	cvarUnreserve = CreateConVar("l4d_lobby_full", "1", "满人时移除大厅预定", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarFixEmpty = CreateConVar("l4d_lobby_empty", "120", "修复空服务器被预定时间", FCVAR_NONE, true, 10.0, true, 300.0);
	cvarPutinLobby = CreateConVar("l4d_lobby_putin", "0", "加入时移除大厅预定", FCVAR_NONE, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d_lobby");
	
	cvarGameMode = FindConVar("mp_gamemode");
}

bool:IsScavengeMode()
{
	decl String:sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "scavenge") > -1)
	{
		return true;
	}
	else
	{
		return false;
	}	
}

bool:IsVersusMode()
{
	decl String:sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "versus") > -1)
	{
		return true;
	}
	else
	{
		return false;
	}	
}

IsServerLobbyFull()
{
	new humans = GetHumanCount();
	DebugPrintToAll("IsServerLobbyFull : humans = %d", humans);
	
	if(IsVersusMode() || IsScavengeMode())
	{
		return humans >= L4D_MAXHUMANS_LOBBY_VERSUS;
	}
	return humans >= L4D_MAXHUMANS_LOBBY_OTHER;
}

public OnClientPostAdminCheck(client)
{
	if(IsFakeClient(client) || GetSteamAccountID(client) <= 0)
		return;
	
	DebugPrintToAll("Client put in server %N", client);
	if(GetConVarBool(cvarPutinLobby) || (GetConVarBool(cvarUnreserve) && IsServerLobbyFull()))
	{
		PrintToServer("[SM] A full lobby has connected, automatically unreserving the server.");
		L4D_LobbyUnreserve();
	}
}

public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
		CreateTimer(3.0, Timer_FixLobbyReservation);
}

public OnMapStart()
{
	// CreateTimer(120.0, Timer_FixLobbyReservation);
	CreateTimer(GetConVarFloat(cvarFixEmpty), Timer_FixLobbyReservation);
}

public Action Timer_FixLobbyReservation(Handle:timer, any:unused)
{
	if(GetHumanCount() <= 0)
	{
		L4D_LobbyUnreserve();
		PrintToServer("[SM] Lobby reservation has been removed.");
	}
	
	return Plugin_Continue;
}

public Action:Command_Unreserve(client, args)
{
	/*if(!L4D_LobbyIsReserved())
	{
		ReplyToCommand(client, "[SM] Server is already unreserved.");
	}*/
	
	L4D_LobbyUnreserve();
	PrintToServer("[SM] Lobby reservation has been removed.");
	
	return Plugin_Handled;
}

//client is in-game and not a bot
stock bool:IsClientInGameHuman(client)
{
	return (IsClientConnected(client) && !IsFakeClient(client));
}

stock GetHumanCount()
{
	new humans = 0;
	
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			humans++
		}
	}
	
	return humans;
}

DebugPrintToAll(const String:format[], any:...)
{
	#if UNRESERVE_DEBUG	|| UNRESERVE_DEBUG_LOG
	decl String:buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	#if UNRESERVE_DEBUG
	PrintToChatAll("[UNRESERVE] %s", buffer);
	PrintToConsole(0, "[UNRESERVE] %s", buffer);
	#endif
	
	LogMessage("%s", buffer);
	#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
	#endif
}