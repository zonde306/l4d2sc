#pragma semicolon 1

#define PLUGIN_VERSION	"1.0.3"

public Plugin:myinfo = 
{
	name = "禁止快速爬梯",
	author = "RedSword / Bob Le Ponge",
	description = "Prevent people from quickly climbing the ladders",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

new Handle:g_on;
new bool:g_bOn;

new bool:g_bIsPlayerAlive[ MAXPLAYERS + 1 ];
new bool:g_bIsFakeClient[ MAXPLAYERS + 1 ];

public OnPluginStart()
{
	CreateConVar( "preventfastladderclimbversion", PLUGIN_VERSION, "Plugin's version", FCVAR_PLUGIN | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_DONTRECORD );
	
	g_on = CreateConVar( "preventfastladderclimb", "1", "Is the plugin enabled ?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDie );
	
	g_bOn = GetConVarBool( g_on );
	
	HookConVarChange( g_on, ConVarChange_On );
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if ( g_bOn && g_bIsPlayerAlive[ client ] && !g_bIsFakeClient[ client ] )
	{
		if (GetEntityMoveType(client) == MOVETYPE_LADDER)
		{
			if ( buttons & IN_FORWARD || buttons & IN_BACK )
			{
				if ( buttons & IN_MOVELEFT )
				{
					buttons &= ~IN_MOVELEFT;
				}
				if ( buttons & IN_MOVERIGHT )
				{
					buttons &= ~IN_MOVERIGHT;
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsPlayerAlive[ GetClientOfUserId( GetEventInt( event, "userid" ) ) ] = true;
}
public Action:Event_PlayerDie(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsPlayerAlive[ GetClientOfUserId( GetEventInt( event, "userid" ) ) ] = false;
}
public OnClientAuthorized(iClient, const String:auth[])
{
	g_bIsFakeClient[ iClient ] = IsFakeClient( iClient );
}
public OnClientDisconnect_Post(iClient)
{
	g_bIsPlayerAlive[ iClient ] = false;
}

public ConVarChange_On(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bOn = GetConVarBool( convar );
}