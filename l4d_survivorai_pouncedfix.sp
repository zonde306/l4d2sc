#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1.1"
#define PLUGIN_NAME "幸存者见死不救修复"

#pragma semicolon 1;                // Force strict semicolon mode.
#pragma newdecls required;			// Force new style syntax.

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = " AtomicStryker, edits by Merudo",
	description = " Fixes Survivor Bots neglecting Teammates in need ",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=99664"
};

bool   IsL4D2 = false;
ConVar Cvar_Range;
ConVar Cvar_Delay;
float  TimeLastOrder[MAXPLAYERS+1];


public void OnPluginStart()
{
	CheckGame();
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	HookEvent("choke_start", Event_Dominated, EventHookMode_PostNoCopy);	
	HookEvent("lunge_pounce", Event_Dominated, EventHookMode_PostNoCopy);	
	HookEvent("jockey_ride", Event_Dominated, EventHookMode_PostNoCopy);
	HookEvent("charger_pummel_start", Event_Dominated, EventHookMode_PostNoCopy);
	//HookEvent("charger_carry_start", Event_Dominated, EventHookMode_PostNoCopy);	
	
	CreateConVar("l4d_survivoraipouncedfix_version", PLUGIN_VERSION, " Version of L4D Survivor AI Pounced Fix on this server ", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	Cvar_Range = CreateConVar("l4d_survivoraipouncedfix_range", "800", "Maximum range the survivor bots will go after infected", FCVAR_NOTIFY);
	Cvar_Delay = CreateConVar("l4d_survivoraipouncedfix_delay", "0.5", "Delay, in seconds, before survivor bot takes another order", FCVAR_NOTIFY);	
	
	AutoExecConfig(true, "l4d_survivorai_pouncedfix");
	
}

// ------------------------------------------------------------------------
// When a player is hurt and getting dominated, call the bots
// ------------------------------------------------------------------------
public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!victim || !attacker || !IsClientInGame(attacker) || !IsClientInGame(victim) || GetClientTeam(attacker) != 3 || GetClientTeam(victim) != 2) return;
	
	int dominater = FindDominator(victim);
	if (dominater == attacker)
		CallBots();
	else if(dominater == -1 && IsFakeClient(victim))
		L4D2_RunScript("CommandABot({cmd=0,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(victim), GetClientUserId(attacker));
}

public Action Event_Dominated(Event event, const char[] name, bool dontBroadcast)
{
	CallBots();
}

// ------------------------------------------------------------------------
// Each time a survivor is getting damaged by a infected & is dominated, call bots
// Each bot will aim at the closest infected that is dominating a survivor
// ------------------------------------------------------------------------
static void CallBots()
{
	for (int bot = 1; bot <= MaxClients; bot++)
	{
		if (IsClientInGame(bot) && GetClientHealth(bot) > 0 && GetClientTeam(bot) == 2 && IsFakeClient(bot) && GetEntPropEnt(bot, Prop_Send, "m_reviveTarget") <= 0) // make sure bot is a live Survivor Bot that isn't reviving
		{
			if (( GetGameTime() - TimeLastOrder[bot] ) > Cvar_Delay.FloatValue)
			{
				int target = FindClosestDominator(bot);
				if (!target) continue ; // if no target, no command
				
				TimeLastOrder[bot] =  GetGameTime();
				// ScriptCommand(bot, "script",  "CommandABot({cmd=0,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(bot), GetClientUserId(target));
				L4D2_RunScript("CommandABot({cmd=0,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(bot), GetClientUserId(target));
				//PrintToChatAll("Bot %d commanded to kill %d", bot, target);
			}
		}
	}
}

// ------------------------------------------------------------------------
// Find the infected currently dominating that's the closest to the client
// ------------------------------------------------------------------------
static int FindClosestDominator(int client)
{
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	
	float dominatorPos[3];
	
	int target = 0;
	float dist = Cvar_Range.FloatValue;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
		{
			continue;
		}
		
		int dominator = FindDominator(i);
		
		if (dominator > 0 && IsClientInGame(dominator) && IsPlayerAlive(dominator) && GetClientTeam(dominator) == 3)
		{
			GetClientAbsOrigin(dominator, dominatorPos);
			if (GetVectorDistance(clientPos, dominatorPos) < dist)
			{
				target = dominator;
				dist   = GetVectorDistance(clientPos, dominatorPos);
			}
		}
	}
	return target;
}

// ------------------------------------------------------------------------
// Return infected that is dominating the client (-1 if not happening)
// ------------------------------------------------------------------------
static int FindDominator(int client)
{
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner")    > 0) return GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) return GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (IsL4D2 && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) return GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (IsL4D2 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) return GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if (IsL4D2 && GetEntPropEnt(client, Prop_Send, "m_carryAttacker" ) > 0) return GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	return -1;
}


stock void L4D2_RunScript(char[] sCode, any ...)
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static char sBuffer[8192];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

stock void ScriptCommand(int client, const char[] command, const char[] arguments, any ...)
{
    char vscript[PLATFORM_MAX_PATH];
    VFormat(vscript, sizeof(vscript), arguments, 4);
    
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags^FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, vscript);
    SetCommandFlags(command, flags | FCVAR_CHEAT);
}

static void CheckGame()
{
	char game[32];	GetGameFolderName(game, sizeof(game));
	
	if 		(StrEqual(game, "left4dead",  false))	IsL4D2 = false;	
	else if (StrEqual(game, "left4dead2", false))	IsL4D2 = true;
	else SetFailState("Plugin is for Left For Dead 1/2 only");
}