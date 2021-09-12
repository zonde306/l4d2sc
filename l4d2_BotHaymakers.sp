#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.0" 


public Plugin:myinfo =
{
    name = "机器人 Tank 二连击",
    author = "ConnerRia",
    description = "Makes AI Tanks pull off haymakers, doing a punch and rock attack simultaneously. ",
    version = PLUGIN_VERSION,
    url = "N/A"
}

int iHaymakerChanceFactor;
ConVar hHaymakerChanceFactor;
int g_iSpawnStuck[MAXPLAYERS+1];

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false) && !StrEqual(game_name, "left4dead", false))
	{		
		SetFailState("Plugin supports Left 4 Dead series only.");
	}
	
	CreateConVar("BotHaymakers_Version", PLUGIN_VERSION, "BotHaymakers Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	hHaymakerChanceFactor = CreateConVar("200IQBots_HaymakerChanceFactor", "1", "Factor the chance of tanks doing haymakers on each punch by this value. A value of one (default) means all AI tank punches are haymakers. A value of 2 means 50% of punches are haymakers, 4 means 25% of punches are haymakers, etc. ", FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	AutoExecConfig(true, "l4d2_BotHaymakers");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;
	
	g_iSpawnStuck[client] = 5;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
    if (IsClientInGame(client) && IsPlayerAlive(client) && (GetClientTeam(client) == 3) && IsFakeClient(client) && (GetEntProp(client, Prop_Send, "m_zombieClass") == 8))
    {
		if (buttons & IN_ATTACK)
        {
			iHaymakerChanceFactor = hHaymakerChanceFactor.IntValue;
			switch(GetRandomInt(1, iHaymakerChanceFactor))
			{		
				case 1:
				{
					buttons |= IN_ATTACK2;
				}
			}
		}
		if(g_iSpawnStuck[client] > 0)
		{
			g_iSpawnStuck[client] -= 1;
			buttons |= IN_ATTACK2;
		}
    }
    
    return Plugin_Continue;
}
