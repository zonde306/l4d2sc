#define PLUGIN_VERSION 		"1.0"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Unvomit
*	Author	:	SilverShot
*	Descrp	:	Removes the vomit effect from a survivor.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=185653

========================================================================================
	Change Log:

1.0 (20-May-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_simple_combat>

#define CVAR_FLAGS				FCVAR_PLUGIN|FCVAR_NOTIFY
#define SKILL_UNVOMIT_DURATION	(1.0 - (SC_GetClientLevel(client) / 5 * 0.05))

new Handle:g_hVomit;
int g_iOffsetVomitDuration = -1;

public Plugin:myinfo =
{
	name = "取消呕吐效果",
	author = "SilverShot",
	description = "Removes the vomit effect from a survivor .",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=185653"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead2", false) )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	new Handle:hGameConf = LoadGameConfigFile("l4d2_unvomit");
	if( hGameConf == INVALID_HANDLE )
	{
		SetFailState("Failed to load gamedata: l4d2_unvomit.txt");
	}

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer::OnITExpired") == false )
		SetFailState("Failed to find signature: CTerrorPlayer::OnITExpired");
	g_hVomit = EndPrepSDKCall();
	if( g_hVomit == INVALID_HANDLE )
		SetFailState("Failed to create SDKCall: CTerrorPlayer::OnITExpired");

	HookEvent("player_now_it", Event_BoomerVomit);
	RegAdminCmd("sm_unvomit", sm_unvomit, ADMFLAG_ROOT);
	CreateTimer(1.0, Timer_SkillRegister);
	
	g_iOffsetVomitDuration = FindSendPropInfo("CTerrorPlayer", "m_itTimer");
	if(g_iOffsetVomitDuration > -1)
		g_iOffsetVomitDuration += 8;
}

public Action Timer_SkillRegister(Handle timer, any unused)
{
	SC_CreateSkill("uv_vomit", "防化服", 0, "减少受到胆汁效果的持续时间");
	return Plugin_Continue;
}

public void Event_BoomerVomit(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!SC_IsClientHaveSkill(client, "uv_vomit"))
		return;
	
	static ConVar cvSurvivor, cvInfected;
	if(cvSurvivor == null)
	{
		cvSurvivor = FindConVar("survivor_it_duration");
		cvInfected = FindConVar("vomitjar_duration_infected_pz");
	}
	
	float duration = 20.0;
	if(GetClientTeam(client) == 2)
		duration = cvSurvivor.FloatValue;
	else
		duration = cvInfected.FloatValue;
	
	duration *= SKILL_UNVOMIT_DURATION;
	CreateTimer(duration, Timer_StopVomit, client);
	
	if(g_iOffsetVomitDuration > -1)
		SetEntDataFloat(client, g_iOffsetVomitDuration, GetGameTime() + duration);
	else
		SetEntPropFloat(client, Prop_Send, "m_itTimer", GetGameTime() + duration, 2);
}

public Action Timer_StopVomit(Handle timer, any client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
		SDKCall(g_hVomit, client);
	
	return Plugin_Continue;
}

public Action:sm_unvomit(client, args)
{
	if( client && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		SDKCall(g_hVomit, client);
	}
	return Plugin_Handled;
}