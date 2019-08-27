/********************************************************************************************
* Plugin	: L4DNoSmoking
* Version	: 1.0.5
* Game		: Left 4 Dead 
* Author	: Finishlast
* Parts taken from:
* [L4D, L4D2] No Death Check Until Dead 
* https://forums.alliedmods.net/showthread.php?t=142432
* [L4D & L4D2] Survivor Bot Takeover v0.8
* https://forums.alliedmods.net/showthread.php?p=1192594
* xZk TeleportEntity suggestion to break tongue
* Aya Supay code cleanup and added language support 
* Lux for different approach on tongue_grab and code cleanup
* Testers	: Myself
* Website	: www.l4d.com
* Purpose	: Prevents smoker from smoking last survivor.
********************************************************************************************/

#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS FCVAR_NONE
#define PLUGIN_NAME "L4DNoSmoking"
#define PLUGIN_VERSION "1.0.5"

// ====================================================================================================
//					VARIEBLES
// ====================================================================================================

ConVar cvar_killorslap, cvar_displaykillmessage;
bool IsLeft4Dead2;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Finishlast",
	description = "Prevents smoker from smoking last survivor.",
	version = PLUGIN_VERSION,
	url = "www.l4d.com"
}

// ====================================================================================================
//                    PLUGIN INFO / START / END
// ====================================================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2) {
		IsLeft4Dead2 = true;		
	}
	else if (test != Engine_Left4Dead) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d_nosmoking.phrases"); 

	CreateConVar("L4DNoSmoking_version", PLUGIN_VERSION, "L4DNoSmoking_version", CVAR_FLAGS);

	cvar_killorslap = CreateConVar("killorslap", "1", "1 kill smoker or 2 slap smoker", CVAR_FLAGS, true, 1.0, true, 2.0); 
	cvar_displaykillmessage = CreateConVar("displaykillmessage", "3", " 0 - Disabled; 1 - small HUD Hint; 2 - big HUD Hint; 3 - Chat Notification ", CVAR_FLAGS, true, 0.0, true, 3.0);

	HookEvent("tongue_grab", tongue_grab);
	AutoExecConfig(true, "L4DNoSmoking");
}

// ====================================================================================================
//					EVENTS / CONFIG 
// ====================================================================================================

public void tongue_grab(Event event, const char[] name, bool dontBroadcast)
{ 
	int victim = GetClientOfUserId(event.GetInt("victim")); 
	int id = GetClientOfUserId(event.GetInt("userid"));

	if (victim > 0 && victim <= MaxClients && !IsClientInGame(victim) && GetClientTeam(victim) == 2) return; 
	
	if (id > 0 && id <= MaxClients && IsClientInGame(id) && GetClientTeam(id) == 3 && IsPlayerAlive(id))
	{ 
	for (int i = 1; i <= MaxClients; i++)  
	{  
		if (i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2)
		{ 
			if(!IsPlayerAlive(i)) 
			{ 
			continue; 
			} 
			if (IsLeft4Dead2)
			{ 
				if (IsClientIncapacitatedl4d2(i) == false) 
				{ 
				return; 
				} 
			} 
			else 
			{ 
				if (IsClientIncapacitatedl4d1(i) == false) 
				{ 
				return;
				} 
			} 
                 
		} 
	} 
	switch(cvar_killorslap.IntValue)
	{ 
		case 1: 
		PerformKill(id, cvar_displaykillmessage.IntValue); 
             
		case 2: 
		PerformSlap(id, cvar_displaykillmessage.IntValue); 
	}     
	} 
	return; 
}

void PerformKill(int id, int displaykillmessage)
{
	ForcePlayerSuicide(id);	
	switch (displaykillmessage)
	{
		case 1:
		{
			CPrintCenterTextAll("%t", "CENTER_KILLER_SMOKER", id);
		}
		case 2:
		{
			CPrintHintTextToAll("%t", "HINT_KILLER_SMOKER", id);
		}
		case 3:
		{
			CPrintToChatAll("%t", "CHAT_KILLER_SMOKER", id);
		}
	}
}

void PerformSlap(int id, int displaykillmessage)
{
	float vpos[3]; 
	GetEntPropVector(id, Prop_Data, "m_vecOrigin", vpos); 
	vpos[2] += 30.0; 
	     
	TeleportEntity(id, vpos, NULL_VECTOR, NULL_VECTOR);   	
	switch (displaykillmessage)
	{
		case 1:
		{
			CPrintCenterTextAll("%t", "CENTER_SLAP_SMOKER", id);
		}
		case 2:
		{
			CPrintHintTextToAll("%t", "HINT_SLAP_SMOKER", id);
		}
		case 3:
		{
			CPrintToChatAll("%t", "CHAT_SLAP_SMOKER", id);
		}
	}
}

// ====================================================================================================
//					STOCKS
// ====================================================================================================

stock bool IsClientIncapacitatedl4d1(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0 ||	// incap
	GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0 ||		// incap ledge
	GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0 ||		// incap fall
	GetEntProp(client, Prop_Send, "m_isHangingFromTongue") != 0 ||		// smoker ledge
	GetEntProp(client, Prop_Send, "m_tongueOwner") > 0 ||			// smoker 
	GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0 ;			// hunter
}

stock bool IsClientIncapacitatedl4d2(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0 ||	// incap
	GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0 ||		// incap ledge
	GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0 ||		// incap fall
	GetEntProp(client, Prop_Send, "m_isHangingFromTongue") != 0 ||		// smoker ledge
	GetEntProp(client, Prop_Send, "m_carryAttacker") > 0 ||			// charger 
	GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0 ||		// charger 
	GetEntProp(client, Prop_Send, "m_jockeyAttacker") > 0 ||		// jockey
	GetEntProp(client, Prop_Send, "m_tongueOwner") > 0 ||			// smoker 
	GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0 ;			// hunter
}

/**
*   @note Used for in-line string translation.
*
*   @param  iClient     Client Index, translation is apllied to.
*   @param  format      String formatting rules. By default, you should pass at least "%t" specifier.
*   @param  ...         Variable number of format parameters.
*   @return char[192]   Resulting string. Note: output buffer is hardly limited.
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

/**
*   @note Prints a hint message to all clients. Supports individual string translation for each client.
*
*   @param  format        Formatting rules.
*   @param  ...            Variable number of format parameters.
*   @no return
*/
stock void CPrintHintTextToAll(const char[] format, any ...)
{
	char buffer[192];
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		PrintHintText(i, buffer);
		}
	}
}

/**
*   @note Prints a center screen message to all clients. Supports individual string translation for each client.
*
*   @param  format        Formatting rules.
*   @param  ...            Variable number of format parameters.
*   @no return
*/
stock void CPrintCenterTextAll(const char[] format, any ...)
{
	char buffer[192];
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		PrintCenterText(i, buffer);
		}
	}
}
