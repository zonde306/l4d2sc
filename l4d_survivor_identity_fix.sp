#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define TEAM_SURVIVOR 2

Handle hSetModel;
char g_Models[MAXPLAYERS+1][128];

public Plugin myinfo =
{
	name        = "幸存者闲置模式修复",
	author      = "Merudo",
	description = "Fix bug where a survivor will change identity when a player connects/disconnects if there are 5+ survivors",
	version     = PLUGIN_VERSION,
	url         = "https://forums.alliedmods.net/showthread.php?p=2403731#post2403731"
}

public void OnPluginStart()
{
	CreateConVar("l4d_survivor_identity_fix_version", PLUGIN_VERSION, "Survivor Change Fix Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	Handle gamedata = LoadGameConfigFile("l4d_survivor_identity_fix");
	if(gamedata == INVALID_HANDLE)
	{
		SetFailState("Survivor Identity Fix cannot find SetModel offset. Make sure l4d_survivor_identity_fix.txt is in /gamedata/");
	}

	int offset = GameConfGetOffset(gamedata, "SetModel");
	hSetModel = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, SetModel);
	DHookAddParam(hSetModel, HookParamType_CharPtr);
	CloseHandle(gamedata);
	
	HookEvent("player_bot_replace", Event_PlayerToBot, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_BotToPlayer, EventHookMode_Post);
}

public void OnClientPutInServer(int client)
{
    DHookEntity(hSetModel, true, client);
}

// ------------------------------------------------------------------------
//  Stores the client of each survivor each time it is changed
//  Needed because when Event_PlayerToBot fires, it's hunter model instead
// ------------------------------------------------------------------------
public MRESReturn SetModel(int client, Handle hParams)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR) 
	{
		g_Models[client][0] = '\0' ;
		return;
	}
	
	char model[128];
	DHookGetParamString(hParams, 1, model, sizeof(model));
	if (strcmp("models/infected/hunter.mdl", model)) strcopy(g_Models[client], 128, model); 
}

// ------------------------------------------------------------------------
//  Models & survivor names so bots can be renamed
// ------------------------------------------------------------------------
char survivor_names[8][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis"};
char survivor_models[8][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

// --------------------------------------
// Bot replaced by player
// --------------------------------------
public Action Event_BotToPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot"));
	
	char model[128];
	
	if (IsFakeClient(player)) return;  // ignore fake players (side product of creating bots)

	if(player > 0 && IsClientInGame(player)) 
	{
		GetClientModel(bot, model, sizeof(model));
		SetEntityModel(player, model);
		SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));
	}
}

// --------------------------------------
// Player -> Bot
// --------------------------------------
public Action Event_PlayerToBot(Handle event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot")); 

	if (IsFakeClient(player)) return;  // ignore fake players (side product of creating bots)
	
	if(player > 0 && IsClientInGame(player) && GetClientTeam(player)==TEAM_SURVIVOR && g_Models[player][0] != '\0') 
	{
		SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
		SetEntityModel(bot, g_Models[player]); // Restore saved model. Player model is hunter at this point
		for (int i = 0; i < 8; i++)
		{
			if (StrEqual(g_Models[player], survivor_models[i])) SetClientInfo(bot, "name", survivor_names[i]);
		}
	}
}
