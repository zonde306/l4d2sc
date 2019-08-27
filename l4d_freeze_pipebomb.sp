
/*=======================================================================================
	Change Log:

1.0 (21-07-2019)
	- Initial release.	

========================================================================================*/

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_INFECTED  3
#define TEAM_SURVIVOR  2
#define DEBUG 0
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY   

// ConVars
ConVar l4d_freeze, l4d_freeze_time, l4d_freeze_speed;
bool g_freeze = true;

public Plugin myinfo =
{
	name = "冰冻土制炸弹",
	author = "JOSHE GATITO SPARTANSKII >>>",
	description = "freezing infected for some time",
	version = "1.0",
	url = "https://github.com/JosheGatitoSpartankii09"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d_freeze_pipebomb.phrases");
	l4d_freeze = CreateConVar("l4d_freeze", "1", "是否开启插件", CVAR_FLAGS);
	l4d_freeze_time = CreateConVar("l4d_freeze_time", "10.0", "冰冻时间", CVAR_FLAGS);
	l4d_freeze_speed = CreateConVar("l4d_freeze_speed", "0.5", "冰冻移动速度", CVAR_FLAGS);

	l4d_freeze.AddChangeHook(ConVarChanged);

	AutoExecConfig(true, "l4d_freeze_pipebomb");	
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_freeze = l4d_freeze.BoolValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(!g_freeze)
	return Plugin_Continue;
		
	if(victim != 0 && victim <= MaxClients && IsClientInGame(victim) && IsPlayerAlive(victim) && GetClientTeam(victim) == TEAM_INFECTED)
	{
		char classname[32];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		
		#if DEBUG
			PrintToChatAll("classname: %s", classname);
		#endif		
		
		if(StrEqual(classname, "pipe_bomb_projectile"))
		{			
			SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", l4d_freeze_speed.FloatValue);
			SetEntityRenderColor(victim, 0, 0, 255, 170);
			
			CreateTimer(l4d_freeze_time.FloatValue, timer_frozen, victim);
			CPrintToChatAll("%t", "FREEZE", victim);
		}
	}
	
	return Plugin_Continue;
}

public Action timer_frozen(Handle timer, any victim)  
{  
	if(victim != 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED)
	{
		SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", 1.0);
		SetEntityRenderColor(victim, 255, 255, 255, 255);
	} 
}

// ====================================================================================================
//					STOCKS
// ====================================================================================================

/**
*   @note Used for in-line string translation.
*
*   @param  iClient     Client Index, translation is apllied to.
*   @param  format      String formatting rules. By default, you should pass at least "%t" specifier.
*   @param  ...            Variable number of format parameters.
*   @return char[192]    Resulting string. Note: output buffer is hardly limited.
*/
stock char[] Translate(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    return buffer;
}

/**
*   @note Prints a message to all clients in the chat area. Supports named colors in translation file.
*
*   @param  format        Formatting rules.
*   @param  ...            Variable number of format parameters.
*   @no return
*/
stock void CPrintToChatAll(const char[] format, any ...)
{
    char buffer[192];
    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            ReplaceColor(buffer, sizeof(buffer));
            PrintToChat(i, "\x01%s", buffer);
        }
    }
}

/**
*   @note Converts named color to control character. Used internally by string translation functions.
*
*   @param  char[]        Input/Output string for convertion.
*   @param  maxLen        Maximum length of string buffer (includes NULL terminator).
*   @no return
*/

stock void ReplaceColor(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{white}", "\x01", false);
    ReplaceString(message, maxLen, "{cyan}", "\x03", false);
    ReplaceString(message, maxLen, "{orange}", "\x04", false);
    ReplaceString(message, maxLen, "{green}", "\x05", false);
}