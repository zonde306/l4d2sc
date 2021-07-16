/*
*	Heal Revive Exploit Bug Fix
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.4a"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Heal Revive Exploit Bug Fix
*	Author	:	SilverShot
*	Descrp	:	Prevents survivors self healing and reviving players at the same time.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=297585
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.4a (09-Jul-2021)
	- L4D2: GameData file updated. Thanks to "Crasher_3637" for updating.

1.4 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Various changes to tidy up code.

1.3 (26-Jun-2018)
	- Fixed invalid entity error - Thanks to "midnight9" for reporting.

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (28-Jun-2017)
	- Converted to new syntax.
	- Now only supports L4D2.

1.0 (18-May-2017)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define GAMEDATA			"l4d_revive_end"

Handle g_hEndRev;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Heal Revive Exploit Bug Fix",
	author = "SilverShot",
	description = "Prevents survivors self healing and reviving players at the same time.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=297585"
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
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::StopRevivingSomeone");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hEndRev = EndPrepSDKCall();
	if( g_hEndRev == null ) SetFailState("Unable to find the \"CTerrorPlayer::StopRevivingSomeone\" signature.");

	delete hGameData;

	HookEvent("revive_begin", Event_Revive);

	CreateConVar("l4d_heal_revive_fix", PLUGIN_VERSION, "Heal Revive Exploit Bug Fix version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public Action Event_Revive(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	CreateTimer(0.1, TimerBlock, userid);
}

public Action TimerBlock(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		int m_useActionTarget = GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
		if( m_useActionTarget == client ) SDKCall(g_hEndRev, client, true);
	}
}