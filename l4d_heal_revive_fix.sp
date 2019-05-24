#define PLUGIN_VERSION		"1.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Heal Revive Exploit Bug Fix
*	Author	:	SilverShot
*	Descrp	:	Prevents survivors self healing and reviving players at the same time.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=297585
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

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

Handle g_hEndRev;

// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo = {
	name = "打包救人修复",
	author = "SilverShot",
	description = "Prevents survivors self healing and reviving players at the same time.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=297585"
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

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("l4d_revive_end");
	if( hGameConf == null ) SetFailState("Couldn't find the gamedata file. Please, check that it is installed correctly.");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer::StopRevivingSomeone");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hEndRev = EndPrepSDKCall();
	if( g_hEndRev == null ) SetFailState("Unable to find the \"CTerrorPlayer::StopRevivingSomeone\" signature.");

	HookEvent("revive_begin", Event_Revive);

	CreateConVar("l4d_heal_revive_fix", PLUGIN_VERSION, "Heal Revive Exploit Bug Fix version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public Action Event_Revive(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	CreateTimer(0.1, TmrBlock, userid);
}

public Action TmrBlock(Handle timer, any client) {
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		int m_useActionTarget = GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
		if( m_useActionTarget == client ) SDKCall(g_hEndRev, client, true);
	}
}