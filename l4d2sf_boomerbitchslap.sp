#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#define PLUGIN_VERSION "1.0.1"

#define CVAR_FLAGS 									FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

#define CHARACTER_NICK			0
#define CHARACTER_ROCHELLE		1
#define CHARACTER_COACH			2
#define CHARACTER_ELLIS		    3
#define CHARACTER_BILL          4
#define CHARACTER_ZOEY          5
#define CHARACTER_FRANCIS       6
#define CHARACTER_LOUIS         7

#define STRING_LENGHT								56

static const String:GAMEDATA_FILENAME[]				= "l4d2addresses";
static const String:INCAP_ENTPROP[]					= "m_isIncapacitated";
static const String:HANGING_ENTPROP[]				= "m_isHangingFromLedge";
static const String:LEDGEFALLING_ENTPROP[]			= "m_isFallingFromLedge";
static const String:VELOCITY_ENTPROP[]				= "m_vecVelocity";
static const String:BOOMER_WEAPON[]					= "boomer_claw";
static const String:CHARACTER_ENTPROP[]			    = "m_survivorCharacter";

static const Float:SLAP_VERTICAL_MULTIPLIER			= 1.5;
static const TEAM_SURVIVOR							= 2;

static Handle:cvar_enabled							= INVALID_HANDLE;
static Handle:cvar_slapPower						= INVALID_HANDLE;
static Handle:cvar_slapCooldownTime					= INVALID_HANDLE;
static Handle:cvar_slapAnnounceMode					= INVALID_HANDLE;
static Handle:cvar_slapOffLedges					= INVALID_HANDLE;

static Float:lastSlapTime[MAXPLAYERS+1]				= 0.0;

public Plugin:myinfo = 
{
	name = "胖子大巴掌",
	author = " AtomicStryker",
	description = "Left 4 Dead 2 Boomer Bitch Slap",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=97952"
}

int g_iSlotAbility;
int g_iLevelSlap[MAXPLAYERS+1];

public OnPluginStart()
{
	Require_L4D2();

	CreateConVar("l4d2_boomerbitchslap_version", PLUGIN_VERSION, " L4D2 Boomer Bitch Slap Plugin Version ", CVAR_FLAGS|FCVAR_DONTRECORD);
	
	cvar_enabled = CreateConVar("l4d2_boomerbitchslap_enabled", "1", " Enable/Disable the Boomer Bitch Slap Plugin ", CVAR_FLAGS);
	cvar_slapPower = CreateConVar("l4d2_boomerbitchslap_power", "150.0", " How much Force is applied to the victim ", CVAR_FLAGS);
	cvar_slapCooldownTime = CreateConVar("l4d2_boomerbitchslap_cooldown", "1.0", " How many seconds before Boomer can Slap again ", CVAR_FLAGS);
	cvar_slapAnnounceMode = CreateConVar("l4d2_boomerbitchslap_announce", "0", " Do Slaps get announced in the Chat Area ", CVAR_FLAGS);
	cvar_slapOffLedges = CreateConVar("l4d2_boomerbitchslap_ledgeslap", "0", " Enable/Disable Slapping hanging people off ledges ", CVAR_FLAGS);
	
	AutoExecConfig(true, "l4d2_boomerbitchslap");
	
	HookEvent("player_hurt", ePlayer_Hurt);
	
	LoadTranslations("l4d2sf_claw_slap.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "claw_slap", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "claw_slap"))
		FormatEx(result, maxlen, "%T", "大巴掌", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "claw_slap"))
		FormatEx(result, maxlen, "%T", tr("大巴掌%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "claw_slap"))
		g_iLevelSlap[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelSlap[client] = L4D2SF_GetClientPerk(client, "claw_slap");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public Action:ePlayer_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new slapper = GetClientOfUserId(GetEventInt(event, "attacker"));
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:weapon[STRING_LENGHT];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (!slapper) slapper = 1;
	if (!target || !IsClientInGame(target)) return;
	if(!IsValidClient(slapper) || g_iLevelSlap[slapper] < 1) return;

	// PrintToChat(slapper, weapon);
	
	// char client_model[64];
	// GetClientModel(slapper, client_model, sizeof(client_model));
	
	// if (StrContains(client_model, "models/infected/boomette.mdl", false) != -1)
	if(GetEntProp(slapper, Prop_Send, "m_zombieClass") == Z_BOOMER)
	{		
		if (GetConVarInt(cvar_enabled) && GetClientTeam(target) == TEAM_SURVIVOR && StrEqual(weapon, BOOMER_WEAPON) && CanSlapAgain(slapper))
		{
			if (!GetEntProp(target, Prop_Send, INCAP_ENTPROP))
			{
				if (!IsFakeClient(target)) 
				{				
					if (GetConVarInt(cvar_slapAnnounceMode)) PrintToChatAll("\x04%N\x01 was \x02Bitch Slapped\x01 by \x04%N\x01!", target, slapper);
				
					decl String:painSound[STRING_LENGHT];
					GetSurvivorPainSound(target, painSound);
				
					for (new i=1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i))
						{
							EmitSoundToClient(i, painSound, target, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
						}
					}
				}			
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvar_slapPower);

				GetClientEyeAngles(slapper, HeadingVector);
		
				AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
				AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
			
				decl Float:current[3];
				GetEntPropVector(target, Prop_Data, VELOCITY_ENTPROP, current);
			
				decl Float:resulting[3];
				resulting[0] = FloatAdd(current[0], AimVector[0]);	
				resulting[1] = FloatAdd(current[1], AimVector[1]);
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
			
				// L4D2_Fling(target, resulting, slapper);
				L4D2_CTerrorPlayer_Fling(target, slapper, resulting);
				PrintCenterText(slapper, "slapping");
			
				lastSlapTime[slapper] = GetEngineTime();
			}
			else if (GetEntProp(target, Prop_Send, HANGING_ENTPROP) && GetConVarBool(cvar_slapOffLedges))
			{
				SetEntProp(target, Prop_Send, INCAP_ENTPROP, 0);
				SetEntProp(target, Prop_Send, HANGING_ENTPROP, 0);
				SetEntProp(target, Prop_Send, LEDGEFALLING_ENTPROP, 0);
		
				StopFallingSounds(target);
			
				// PrintCenterText(slapper, "YOU BITCHSLAPPED %N", target);
				// PrintCenterText(target, "Got Bitch Slapped by %N!!!", slapper);
			}	
		}
	}
}

static bool:CanSlapAgain(client)
{
	return ((GetEngineTime() - lastSlapTime[client]) > GetConVarFloat(cvar_slapCooldownTime));
}

/*
stock L4D2_Fling(target, Float:vector[3], attacker, Float:incaptime = 3.0)
{
	new Handle:MySDKCall = INVALID_HANDLE;
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	StartPrepSDKCall(SDKCall_Player);
	new bool:bFlingFuncLoaded = PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	if(!bFlingFuncLoaded)
	{
		LogError("Could not load the Fling signature");
	}
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

	MySDKCall = EndPrepSDKCall();
	if(MySDKCall == INVALID_HANDLE)
	{
		LogError("Could not prep the Fling function");
	}
	
	SDKCall(MySDKCall, target, vector, 76, attacker, incaptime); 
}
*/

stock Require_L4D2()
{
	decl String:game[32];
	GetGameFolderName(game, sizeof(game));
	if (!StrEqual(game, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}
}

stock StopFallingSounds(client)
{
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangTwoHands");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangOneHand");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFingers");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangAboutToFall");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFalling");
}

static GetSurvivorPainSound(target, String:painSound[STRING_LENGHT-1])
{
	switch (GetEntProp(target, Prop_Send, CHARACTER_ENTPROP))
	{
		case CHARACTER_NICK:
		{
			switch (GetRandomInt(1,7))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical06.wav");
				case 7:		Format(painSound, sizeof(painSound), "player/survivor/voice/gambler/hurtcritical07.wav");
			}
		}
		case CHARACTER_ROCHELLE:
		{
			switch (GetRandomInt(1,4))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/producer/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/producer/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/producer/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/producer/hurtcritical04.wav");
			}
		}
		case CHARACTER_COACH:
		{
			switch (GetRandomInt(1,8))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical06.wav");
				case 7:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical07.wav");
				case 8:		Format(painSound, sizeof(painSound), "player/survivor/voice/coach/hurtcritical08.wav");
			}
		}
		case CHARACTER_ELLIS:
		{
			switch (GetRandomInt(1,6))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/mechanic/hurtcritical06.wav");
			}
		}
		case CHARACTER_BILL:
		{
			switch (GetRandomInt(1,9))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical06.wav");
				case 7:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical07.wav");
				case 8:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical08.wav");
				case 9:		Format(painSound, sizeof(painSound), "player/survivor/voice/namvet/hurtcritical09.wav");				
			}
		}
		case CHARACTER_ZOEY:
		{
			switch (GetRandomInt(1,7))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical06.wav");
				case 7:		Format(painSound, sizeof(painSound), "player/survivor/voice/teengirl/hurtcritical07.wav");
			}
		}		
		case CHARACTER_FRANCIS:
		{
			switch (GetRandomInt(1,11))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical05.wav");
				case 6:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical06.wav");
				case 7:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical07.wav");
				case 8:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical08.wav");
				case 9:		Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical09.wav");
				case 10:    Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical10.wav");
				case 11:    Format(painSound, sizeof(painSound), "player/survivor/voice/biker/hurtcritical11.wav");				
			}
		}
		case CHARACTER_LOUIS:
		{
			switch (GetRandomInt(1,5))
			{
				case 1:		Format(painSound, sizeof(painSound), "player/survivor/voice/manager/hurtcritical01.wav");
				case 2:		Format(painSound, sizeof(painSound), "player/survivor/voice/manager/hurtcritical02.wav");
				case 3:		Format(painSound, sizeof(painSound), "player/survivor/voice/manager/hurtcritical03.wav");
				case 4:		Format(painSound, sizeof(painSound), "player/survivor/voice/manager/hurtcritical04.wav");
				case 5:		Format(painSound, sizeof(painSound), "player/survivor/voice/manager/hurtcritical05.wav");
			}
		}				
	}
}