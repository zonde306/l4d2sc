#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "禁止自动返回大厅",
	author = "MasterMind420",
	description = "Prevents all return to lobby requests other than from votes",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("VotePass"), OnDisconnectToLobby, true);
	HookUserMessage(GetUserMessageId("DisconnectToLobby"), OnDisconnectToLobby, true);
}

public Action OnDisconnectToLobby(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	static bool bAllowDisconnect;

    char sBuffer[64];
    BfReadString(bf, sBuffer, sizeof(sBuffer));

	if (StrContains(sBuffer, "vote_passed_return_to_lobby") > -1)
	{
		bAllowDisconnect = true;
		return Plugin_Continue;
	}
	else if (StrContains(sBuffer, "vote_passed") > -1)
		return Plugin_Continue;

	if (bAllowDisconnect)
	{
		bAllowDisconnect = false;
		return Plugin_Continue;
	}

	return Plugin_Handled;
}