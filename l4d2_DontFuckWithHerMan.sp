#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.1" 

public Plugin:myinfo =
{
    name = "生还者机器人躲 Witch",
    author = "ConnerRia",
    description = "Stops survivor bots from blocking the witch's path.",
    version = PLUGIN_VERSION,
    url = "N/A"
}

new bool: bIsWitchStartled = false;
int WitchID;
float fWitchDangerDistance;
ConVar hWitchDangerDistance;

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false) && !StrEqual(game_name, "left4dead", false))
	{		
		SetFailState("Plugin supports Left 4 Dead series only.");
	}
	
	CreateConVar("DontFuckWithHer_Version", PLUGIN_VERSION, "DontFuckWithHer Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	hWitchDangerDistance = CreateConVar("200IQBots_WitchDangerRange", "500.0", "The range by which survivors bots will detect the presence of witch and retreat. ", FCVAR_NOTIFY|FCVAR_REPLICATED);	
	
	HookEvent("witch_harasser_set", Event_WitchStartled);   
	HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("witch_killed", Event_WitchDeath);
	
	AutoExecConfig(true, "l4d2_DontFuckWithHerMan");
	
}

public OnMapStart()
{	
	bIsWitchStartled = false;
}	

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsWitchStartled = false;
}

public Action:Event_MapTransition(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsWitchStartled = false;
}

public Action:Event_WitchStartled(Handle:event, String:event_name[], bool:dontBroadcast)
{
	bIsWitchStartled = true;
	new WitchIndex = GetEventInt(event, "witchid");  
	WitchID = EntIndexToEntRef(WitchIndex);
	CreateTimer(0.1, BotControlTimer, _, TIMER_REPEAT);
}  

public Action:Event_WitchDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	bIsWitchStartled = false;
}  

public Action:BotControlTimer(Handle:Timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == 2) && IsFakeClient(i))
		{	
			new TheWitch = EntRefToEntIndex(WitchID);
			if (IsValidWitch(TheWitch))
			{
				fWitchDangerDistance = hWitchDangerDistance.FloatValue;
				new Float:WitchPosition[3];
				GetEntPropVector(TheWitch, Prop_Send, "m_vecOrigin", WitchPosition);
				new Float:BotPosition[3];
				GetClientAbsOrigin(i, BotPosition);
				if (GetVectorDistance(BotPosition, WitchPosition) < fWitchDangerDistance)
				{
					L4D2_RunScript("CommandABot({cmd=2,bot=GetPlayerFromUserID(%i),target=EntIndexToHScript(%i)})", GetClientUserId(i), TheWitch);
				}
			}
		}
	}	  
	
	if (!bIsWitchStartled)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

IsValidWitch(TheWitch)
{
	if(TheWitch> 32 && IsValidEdict(TheWitch) && IsValidEntity(TheWitch))
	{
		decl String:classname[32];
		GetEdictClassname(TheWitch, classname, sizeof(classname));
		if(StrEqual(classname, "witch"))
		{
			return true;
		}
	}
	
	return false;
}

//Credits to Timocop for the stock :D
/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}