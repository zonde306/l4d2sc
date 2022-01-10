/*============================================================================================
							[L4D & L4D2] Surivor Utilities (API).
----------------------------------------------------------------------------------------------
*	Author	:	Eärendil
*	Descrp	:	Modify survivor speeds and add custom effects.
*	Version :	1.0.3
*	Link	:	https://forums.alliedmods.net/showthread.php?t=335683
----------------------------------------------------------------------------------------------
*	IMPORTANT:
		- Don't mess much with player speeds, if you try to put extreme values bugs will appear.
		- Very low values causes weird movements in players (run speed shouldn't be lower than 100, walk speeds cannot go under 65)
		- Very high values causes the effect in players when they jump they accelerate.
		- I think this is caused because server changes speeds but players sets the default value in their respective
			engines, and until next packet send with new speed values there is a small gap where the strange
			stuff happens.
		- Increasing server tickrate seems to decrease the time bewteen packets and this effect.
		- I have clamped the minimum speeds(to prevent plugins to stop players), but the max speed is up to you.
		- Safe speed values are 65-400
*	Special thanks:
		- Silvers: for postprocess and fog helping; also for advices with Natives and GlobalForwards.
==============================================================================================*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <survivorutilities>

#define PLUGIN_VERSION "1.0.3"

#define SND_BLEED1		"player/survivor/splat/blood_spurt1.wav"
#define SND_BLEED2		"player/survivor/splat/blood_spurt2.wav"
#define SND_BLEED3		"player/survivor/splat/blood_spurt3.wav"
#define SND_CHOKE		"player/survivor/voice/choke_5.wav"
#define SND_FREEZE		"physics/glass/glass_impact_bullet4.wav"
#define EXHAUST_TOKEN	140

public Plugin myinfo =
{
	name = "[L4D & L4D2] Surivor Utilities (API)",
	author = "Eärendil",
	description = "Modify survivor speeds and add custom effects.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=335683",
};

enum
{
	STATUS_INCAP,
	STATUS_NORMAL,
	STATUS_LIMP,
	STATUS_CRITICAL
};

// Player Speeds
float g_fRunSpeed[MAXPLAYERS+1];		// Normal player speed (default = 220.0)
float g_fWaterSpeed[MAXPLAYERS+1];		// Player speed on water (default = 115.0)
float g_fLimpSpeed[MAXPLAYERS+1];		// Player speed while limping (default = 150.0)
float g_fCritSpeed[MAXPLAYERS+1];		// Player speed when 1 HP after 1 incapacitation (default = 85.0)
float g_fWalkSpeed[MAXPLAYERS+1];		// Player speed while walking (default = 85.0)
float g_fCrouchSpeed[MAXPLAYERS+1];		// Player speed while crouching (default = 75.0)
float g_fExhaustSpeed[MAXPLAYERS+1];	// Player speed while exhaust

// Player conditions
bool g_bIsFrozen[MAXPLAYERS+1];			// Store if player is frozen
int g_iExhaustToken[MAXPLAYERS+1];		// Player exhaust tokens
int g_iToxicToken[MAXPLAYERS+1];		// Player intoxication tokens
int g_iBleedToken[MAXPLAYERS+1];		// Player bleeding tokens
float g_fFreezeTime[MAXPLAYERS+1];		// Player frozen lifetime (this value is needed to stack times)
float g_fRecoilStack[MAXPLAYERS+1];		// Stacked recoil

ConVar	g_hRunSpeed, g_hWaterSpeed, g_hLimpSpeed, g_hCritSpeed, g_hWalkSpeed, g_hCrouchSpeed, g_hExhaustSpeed, g_hTempDecay,
		g_hToxicDmg, g_hToxicDelay, g_hBleedDmg, g_hBleedDelay, g_hLimpHealth, g_hFreezeOverride,
		g_hToxicOverride, g_hBleedOverride;
		
float g_fTempDecay, g_fLimpHealth;
		
// Timer Handles
Handle g_hToxicTimer[MAXPLAYERS+1], g_hBleedTimer[MAXPLAYERS+1], g_hFreezeTimer[MAXPLAYERS+1], g_hExhaustTimer[MAXPLAYERS+1], g_hRecoilTimer[MAXPLAYERS+1];

GlobalForward ForwardFreeze, ForwardBleed, ForwardToxic, ForwardExhaust, ForwardFreezeEnd, ForwardBleedEnd, ForwardToxicEnd, ForwardExhaustEnd;

int g_iPostProcess, g_iFogVolume, g_iEntMustDie;		// Postprocess and fog related

// Instead of making a list with all weapons, use keywords to find the weapon
static char g_sWeaponRecoils[20][] = {
	"shotgun",	"18.5",
	"hunting",	"14.5",
	"sniper",	"14.5",
	"smg",		"3.0",
	"magnum",	"7.5",	// When looping if we reach magnum(before pistols), loop will stop
	"pistol",	"2.5",
	"ak47",		"4.2",
	"desert",	"3.2",
	"m60",		"4.5",
	"rifle",	"4.0"	// Similar case as with magnum but with the "rifle_" family
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 && GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;
	}
	
	// Natives to call functions on players
	CreateNative("SU_AddFreeze",		Native_AddFreeze);
	CreateNative("SU_RemoveFreeze",		Native_RemoveFreeze);
	CreateNative("SU_AddBleed",			Native_AddBleed);
	CreateNative("SU_RemoveBleed",		Native_RemoveBleed);
	CreateNative("SU_AddToxic",			Native_AddToxic);
	CreateNative("SU_RemoveToxic",		Native_RemoveToxic);
	CreateNative("SU_SetSpeed",			Native_SetSpeed);
	CreateNative("SU_AddExhaust",		Native_AddExhaust);
	CreateNative("SU_RemoveExhaust",	Native_RemoveExhaust);
	// Natives to get player status
	CreateNative("SU_IsFrozen",			Native_GetFreeze);
	CreateNative("SU_IsBleeding",		Native_GetBleed);
	CreateNative("SU_IsToxic",			Native_GetToxic);
	CreateNative("SU_GetSpeed",			Native_GetSpeed);
	CreateNative("SU_IsExhausted",		Native_GetExhaust);

	// Forwards when survivor conditions are being set (can be modified)
	ForwardFreeze =		new GlobalForward("SU_OnFreeze",		ET_Event, Param_Cell, Param_FloatByRef);
	ForwardBleed =		new GlobalForward("SU_OnBleed",			ET_Event, Param_Cell, Param_CellByRef);
	ForwardToxic =		new GlobalForward("SU_OnToxic",			ET_Event, Param_Cell, Param_CellByRef);
	ForwardExhaust =	new GlobalForward("SU_OnExhaust",		ET_Event, Param_Cell);
	// Forwards when survivor conditions end (can't be modified)
	ForwardFreezeEnd =	new GlobalForward("SU_OnFreezeEnd",		ET_Ignore, Param_Cell);
	ForwardBleedEnd	=	new GlobalForward("SU_OnBleedEnd",		ET_Ignore, Param_Cell);
	ForwardToxicEnd =	new GlobalForward("SU_OnToxicEnd",		ET_Ignore, Param_Cell);
	ForwardExhaustEnd =	new GlobalForward("SU_OnExhaustEnd",	ET_Ignore, Param_Cell);
		
	RegPluginLibrary("survivorutilities");
	
	return APLRes_Success;
}

public void OnPluginStart()
{	
	CreateConVar("survivor_utilities_version", PLUGIN_VERSION,	"L4D Survivor Utilities Version", 	FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Speed convars (I wish There could be some convars that control speeds)
	// The default values are the game original values
	g_hRunSpeed =		CreateConVar("sm_su_run_speed",			"220.0", 	"Default survivor run speed.",							FCVAR_NOTIFY, true, 110.0);	// When survivor should be running, dont go below 110.0 or players will see weird movements
	g_hWaterSpeed =		CreateConVar("sm_su_water_speed",		"115.0",	"Survivor speed while in water.",						FCVAR_NOTIFY, true, 80.0);
	g_hLimpSpeed =		CreateConVar("sm_su_limp_speed",		"150.0",	"Survivor limping speed (HP below 40).",				FCVAR_NOTIFY, true, 65.0);	// Under 65 player speed is not linear and falls rapidly to 0 around 50 speed value
	g_hCritSpeed =		CreateConVar("sm_su_critical_speed",	"85.0",		"Survivor speed when 1 HP afer one incapacitation.",	FCVAR_NOTIFY, true, 65.0);
	g_hWalkSpeed =		CreateConVar("sm_su_walk_speed",		"85.0",		"Survivor walk speed.",									FCVAR_NOTIFY, true, 65.0);
	g_hCrouchSpeed =	CreateConVar("sm_su_crouch_speed",		"75.0",		"Survivor speed while crouching.",						FCVAR_NOTIFY, true, 65.0);
	g_hExhaustSpeed =	CreateConVar("sm_su_exhaust_speed",		"115.0",	"Survivor speed when exhausted by plugin.",				FCVAR_NOTIFY, true, 110.0);
	// Intoxicate convars
	g_hToxicDmg =		CreateConVar("sm_su_toxic_damage",		"1.0",		"Amount of toxic damage dealed to survivors.",			FCVAR_NOTIFY, true, 1.0);
	g_hToxicDelay =		CreateConVar("sm_su_toxic_delay",		"5.0",		"Delay in seconds between toxic damages.",				FCVAR_NOTIFY, true, 0.1);
	g_hToxicOverride =	CreateConVar("sm_su_toxic_override",	"2",		"What should plugin do with toxic amount if a player is intoxicated again?\n0 = Don't override amount.\n1 = Override if new amount are higher. \n2 = Add new amount to the remaining amount.\n3 = Allways override amount.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	// Bleeding convars
	g_hBleedDmg = 		CreateConVar("sm_su_bleed_damage",		"1.0",		"Amount of bleeding damage dealed to survivors.",		FCVAR_NOTIFY, true, 1.0);
	g_hBleedDelay =		CreateConVar("sm_su_bleed_delay",		"5.0",		"Delay in seconds between bleed damages.",				FCVAR_NOTIFY, true, 0.1);
	g_hBleedOverride =	CreateConVar("sm_su_bleed_override",	"2",		"What should plugin do with bleed amount if a player is bleeding again?\n0 = Don't override amount.\n1 = Override if new amount is higher. \n2 = Add new amount to the original one.\n3 = Allways override amount.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	// Freeze convars
	g_hFreezeOverride =	CreateConVar("sm_su_freeze_override",	"2",		"What should plugin do with freeze time if a player is frozen again?\n0 = Don't change original freeze time.\n1 = Change original freeze time if new time is higher.\n2 = Add the new freeze time to the original time.\n3 = Override original time.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	// Get server convars	
	g_hTempDecay =	 	FindConVar("pain_pills_decay_rate");
	g_hLimpHealth =		FindConVar("survivor_limp_health");

	g_hRunSpeed.AddChangeHook(CVarChange_Speeds);
	g_hWaterSpeed.AddChangeHook(CVarChange_Speeds);
	g_hLimpSpeed.AddChangeHook(CVarChange_Speeds);
	g_hCritSpeed.AddChangeHook(CVarChange_Speeds);
	g_hWalkSpeed.AddChangeHook(CVarChange_Speeds);
	g_hCrouchSpeed.AddChangeHook(CVarChange_Speeds);
	
	g_hTempDecay.AddChangeHook(CVarChange_Game);
	g_hLimpHealth.AddChangeHook(CVarChange_Game);
		
	HookEvent("pills_used",			Event_Pills_Used);
	HookEvent("adrenaline_used",	Event_Adren_Used);
	HookEvent("heal_success",		Event_Heal);
	HookEvent("player_death",		Event_Player_Death);
	HookEvent("round_end",			Event_Round_End, EventHookMode_PostNoCopy);
	HookEvent("weapon_fire",		Event_Weapon_Fire);
	
	AutoExecConfig(true, "l4d_survivor_utilities");
}

public void OnMapStart()
{
	SoundPrecache();
	for( int i = 0; i <= MaxClients; i++ )
		SetClientData(i, true);
}

public void OnClientPutInServer(int client)
{
	SetClientData(client, true);
}

public void OnConfigsExecuted()
{
	SetSpeeds();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
	
	if( g_bIsFrozen[client] == true && buttons & IN_RELOAD )
	{
		buttons &= ~IN_RELOAD;
		return Plugin_Changed;
	}
	if( g_iExhaustToken[client] > 0 && buttons & IN_ATTACK2 )
		SetEntProp(client, Prop_Send, "m_iShovePenalty", 8);	// 8 seems to be the max fatigue that surivors can have
	
	return Plugin_Continue;
}

//==========================================================================================
//									ConVar Logic
//==========================================================================================

public void CVarChange_Speeds(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetSpeeds();
}

public void CVarChange_Game(Handle convar, const char[] oldValue, const char[] newValue)
{
	GameConVars();
}

void SetSpeeds()	// I need to change this to prevent override custom player speeds when convar changes
{
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_fRunSpeed[i] = g_hRunSpeed.FloatValue;
		g_fWaterSpeed[i] = g_hWaterSpeed.FloatValue;
		g_fLimpSpeed[i] = g_hLimpSpeed.FloatValue;
		g_fCritSpeed[i] = g_hCritSpeed.FloatValue;
		g_fWalkSpeed[i] = g_hWalkSpeed.FloatValue;
		g_fCrouchSpeed[i] = g_hCrouchSpeed.FloatValue;
	}
}

void GameConVars()
{
	g_fTempDecay = g_hTempDecay.FloatValue;
	g_fLimpHealth = g_hLimpHealth.FloatValue;
}

//==========================================================================================
//									Events
//==========================================================================================

public void Event_Pills_Used(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( g_iToxicToken[client] > 0) SU_RemoveToxic(client);
}

public void Event_Adren_Used(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( g_iExhaustToken[client] > 0 ) SU_RemoveExhaust(client);
	if( g_iToxicToken[client] > 0) SU_RemoveToxic(client);
}

public void Event_Heal(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "subject"));
	if( g_iBleedToken[client] > 0) SU_RemoveBleed(client);
}

public void Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	// !client because Common Infected trigger this event, wtf!
	if( !client || !IsValidClient(client) ) return;
		
	if( g_bIsFrozen[client] == true )	// In case client is frozen disable the weapon switch hook
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		BlockPlayerAttacks(client, false);
	}
		
	SetClientData(client, false); // Removes all effects without calling API events
}

public void Event_Round_End(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i < MaxClients; i++ )
	{
		if( IsClientInGame(i) )
			SetClientData(i, false);
	}
}

public Action Event_Weapon_Fire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( IsAliveSurvivor(client) && g_iExhaustToken[client] > 0 )
	{
		char sBuffer[32];
		event.GetString("weapon", sBuffer, sizeof(sBuffer));
		for( int i = 0; i < sizeof(g_sWeaponRecoils); i += 2 )
		{
			if( StrContains(sBuffer, g_sWeaponRecoils[i], false) != -1 )
			{
				g_fRecoilStack[client] -= StringToFloat(g_sWeaponRecoils[i+1]); // Increase the stacked recoil
				break; // Stop loop because string is readed in a way it could find another match with some weapon, so first match is always the desired weapon
				
			}
		}
		if( g_fRecoilStack[client] == 0 )
			return Plugin_Continue;	// Because the loop didn't found a weapon, so is not listed, not a weapon and we don't need to do anything more
			
		if( g_fRecoilStack[client] < -50.0 ) g_fRecoilStack[client] = -50.0; // Clamp recoil to -50 value to prevent insane recoils
		
		// I'm not sure if I use g_fRecoilStack[client] directly it could be changed by timer before the Callback is executed, so I use DataPack for safety
		DataPack hPack = new DataPack();
		RequestFrame(WeaponFire_Frame, hPack);
		hPack.WriteCell(client);
		hPack.WriteFloat(g_fRecoilStack[client]);
		if( g_hRecoilTimer[client] == null )
			g_hRecoilTimer[client] = CreateTimer(0.5, Recoil_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

//==========================================================================================
//									DHooks & SDKHooks
//==========================================================================================

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue; // Ignore infected and dead survivors
		
	float fBaseSpeed = GetPlayerSpeed(client, GetSurvivorStatus(client), g_fRunSpeed[client]);
	if( fBaseSpeed < 0.0 ) return Plugin_Continue; // Ignore negative speeds
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed ) // In case survivor is exhausted and exhaust speed is lower than current speed...
		fBaseSpeed = g_fExhaustSpeed[client];

	retVal = fBaseSpeed;
	return Plugin_Handled;
}

public Action L4D_OnGetWalkTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
		
	float fBaseSpeed = GetPlayerSpeed(client, GetSurvivorStatus(client), g_fWalkSpeed[client]);
	if( fBaseSpeed < 0.0 ) return Plugin_Continue;
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed )
		fBaseSpeed = g_fExhaustSpeed[client];

	retVal = fBaseSpeed;
	return Plugin_Handled;
}	

public Action L4D_OnGetCrouchTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
	
	float fBaseSpeed = GetPlayerSpeed(client, GetSurvivorStatus(client), g_fCrouchSpeed[client]);
	if( fBaseSpeed < 0.0 ) return Plugin_Continue;
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed )
		fBaseSpeed = g_fExhaustSpeed[client];

	retVal = fBaseSpeed;
	return Plugin_Handled;
}

// If an exhaust postprocess is active, display only to exhausted players
public Action PostProcess_STransmit(int entity, int client)
{
	// Kill entity on SetTransmit and wait a frame to respawn if needed (this prevents bugs)
	if( g_iEntMustDie == 1)
	{
		g_iEntMustDie = 0;
		KillPostProcess();
		RequestFrame(Exhaust_PostCheck);
		return Plugin_Continue;
	}
	if( GetEdictFlags(entity) & FL_EDICT_ALWAYS )
		SetEdictFlags(entity, GetEdictFlags(entity) &~ FL_EDICT_ALWAYS);
		
	if( !IsAliveSurvivor(client) )
		return Plugin_Handled;	
	
	if( g_iExhaustToken[client] < 1 )
		return Plugin_Handled;

	return Plugin_Continue;
}

// Hook weapon switch to block attack and shoot correctly
public Action OnWeaponSwitch(int client, int weapon)
{
	if( !IsValidEntity(weapon) )
		return Plugin_Continue;
		
	BlockPlayerAttacks(client, true);
	return Plugin_Continue;
}

//==========================================================================================
//									Functions
//==========================================================================================

int GetSurvivorStatus(int client)
{
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1 ) return STATUS_INCAP;

	float fAbsHealth = GetAbsHealth(client);
	if( fAbsHealth >= 1.0 && fAbsHealth < g_fLimpHealth )
	{
		if( fAbsHealth == 1.0 && GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ) return STATUS_CRITICAL;
			
		else return STATUS_LIMP;
	}
	else return STATUS_NORMAL;
}

// Function from drug effect, modifyed
void ScreenColor(int client, int color[4], int flags)
{
	if( !client || IsFakeClient(client) ) return;
	UserMsg FadeUserMsgId = GetUserMessageId("Fade");
	int clients[2];
	clients[0] = client;

	int duration = 196;
	int holdtime = 512;
//	int flags = (0x0002 | 0x0008);

	Handle message = StartMessageEx(FadeUserMsgId, clients, 1);
	if( GetUserMessageType() == UM_Protobuf )
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else 
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(flags);
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}

// Compare speeds and get the lowest speed in the player situation
float GetPlayerSpeed(int client, int playerStatus, float fSpeed)
{
	if( GetEntityFlags(client) & FL_INWATER ) // This is the only way to check properly if a survivor is on water
	{
		if( fSpeed > g_fWaterSpeed[client] )
			fSpeed = g_fWaterSpeed[client];
	}
	switch( playerStatus )
	{
		case STATUS_INCAP: return -1.0; // If this function returns a negative value, the DHook will do nothing, which is logical if survivor is incapped
		case STATUS_NORMAL: return fSpeed;
		case STATUS_LIMP: return fSpeed < g_fLimpSpeed[client] ? fSpeed : g_fLimpSpeed[client];	 // I just learned ternary operators, they are great :D
		case STATUS_CRITICAL: return fSpeed < g_fCritSpeed[client] ? fSpeed : g_fCritSpeed[client];
	}
	return -1.0;
}

bool IsValidAliveSurvivor(int client)
{
	if( !IsValidClient(client) )
		return false;
	return IsAliveSurvivor(client);
}

bool IsAliveSurvivor(int client)
{
	if( GetClientTeam(client) != 2 )
		return false;
	return IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	if( client < 1 || client > MaxClients )
		return false;
	return IsClientInGame(client);
}

// Resets all the client related variables on death/round restart/mapchange
void SetClientData(int client, bool fullReset) // FullReset is only called when player connects or mapchanges (prevents speed heritage from other player)
{
	delete g_hToxicTimer[client];
	delete g_hBleedTimer[client];
	delete g_hFreezeTimer[client];
	g_bIsFrozen[client] = false;
	g_iExhaustToken[client] = 0;
	g_iBleedToken[client] = 0;
	g_iToxicToken[client] = 0;
	if( fullReset )
	{
		g_fRunSpeed[client] = g_hRunSpeed.FloatValue;
		g_fCrouchSpeed[client] = g_hCrouchSpeed.FloatValue;
		g_fWalkSpeed[client] = g_hWalkSpeed.FloatValue;
		g_fCritSpeed[client] = g_hCritSpeed.FloatValue;
		g_fWaterSpeed[client] = g_hWalkSpeed.FloatValue;
		g_fExhaustSpeed[client] = g_hExhaustSpeed.FloatValue;
	}
	else ScreenColor(client, { 0, 0, 0, 0 }, (0x0001 | 0x0010));
}

void SoundPrecache()
{
	PrecacheSound(SND_BLEED1, false);
	PrecacheSound(SND_BLEED2, false);
	PrecacheSound(SND_BLEED3, false);
	PrecacheSound(SND_CHOKE, false);
	PrecacheSound(SND_FREEZE, false);
}

void KillPostProcess()
{
	if( IsValidEntRef(g_iPostProcess) )
		AcceptEntityInput(g_iPostProcess, "Kill");

	g_iPostProcess = 0;

	if( IsValidEntRef(g_iFogVolume) )
		AcceptEntityInput(g_iFogVolume, "Kill");

	g_iFogVolume = 0;
}

// Function by Silvers
float GetAbsHealth(int client)
{
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fTempDecay;
	fHealth = fHealth < 0.0 ? 0.0 : fHealth;
	return float(GetClientHealth(client)) + fHealth;
}

void BlockPlayerAttacks(int client, const bool isBlock)
{
	float fTime;
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	fTime = isBlock ? 9999.0 : 0.25;

	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fTime);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", fTime);	
}

//==========================================================================================
//									Timers & Request Frames
//==========================================================================================

public Action ToxicDmg_Timer(Handle timer, int client)
{
	g_hToxicTimer[client] = null;
	if( !IsValidAliveSurvivor(client) ) // In case survivor disconnects or changes teams, remove the effect
	{
		g_iToxicToken[client] = 0;
		return;
	}
	
	g_iToxicToken[client]--;
	ScreenColor(client, { 255, 127, 0, 130 }, 0x0001);
	SDKHooks_TakeDamage(client, client, client, g_hToxicDmg.FloatValue, 0);
	EmitSoundToClient(client, SND_CHOKE);

	if( g_iToxicToken[client] > 0 )
		g_hToxicTimer[client] = CreateTimer(g_hToxicDelay.FloatValue, ToxicDmg_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	
	else SU_RemoveToxic(client);
}

public Action BleedDmg_Timer(Handle timer, int client)
{
	g_hBleedTimer[client] = null;
	if( !IsValidAliveSurvivor(client) )
	{
		g_iBleedToken[client] = 0;
		return;
	}
	
	g_iBleedToken[client]--;
	ScreenColor(client, { 255, 22, 0, 140 }, 0x0001);
	SDKHooks_TakeDamage(client, client, client, g_hBleedDmg.FloatValue, 0);
	
	switch( GetRandomInt(1,3) )
	{
		case 1: EmitSoundToClient(client, SND_BLEED1);
		case 2: EmitSoundToClient(client, SND_BLEED2);
		case 3: EmitSoundToClient(client, SND_BLEED3);
	}
	 // I don't like to use TIMER_REPEAT, it causes bugs, I prefer to do this manually to have more control and less errors
	if( g_iBleedToken[client] > 0)
		g_hBleedTimer[client] = CreateTimer(g_hBleedDelay.FloatValue, BleedDmg_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	
	else
	{
		Call_StartForward(ForwardBleedEnd);
		Call_PushCell(client);
		Call_Finish();
	}
}

public Action Recoil_Timer(Handle timer, int client)
{
	g_hRecoilTimer[client] = null;
	if( g_fRecoilStack[client] <= -8 )
	{
		g_fRecoilStack[client] += 8.0;
		g_hRecoilTimer[client] = CreateTimer(0.5, Recoil_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	g_fRecoilStack[client] = 0.0;
}

// Removes exhaust tokens over time (removes faster if the player isn't moving)
public Action Exhaust_Timer(Handle timer, int client)
{
	g_hExhaustTimer[client] = null;
	if( !IsValidAliveSurvivor(client) )
	{
		g_iExhaustToken[client] = 0;
		g_iEntMustDie = 1;
		return;
	}

	if( g_iExhaustToken[client] < 1 )
	{
		SU_RemoveExhaust(client);
		return;
	}

	int iButton = GetEntProp(client, Prop_Data, "m_nButtons");
	if( iButton & IN_FORWARD || iButton & IN_LEFT || iButton & IN_RIGHT || iButton & IN_BACK )
		g_iExhaustToken[client]--;
		
	else g_iExhaustToken[client] -= 2;
	
	g_hExhaustTimer[client] = CreateTimer(0.2, Exhaust_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Freeze_Timer(Handle timer, int client)
{
	g_hFreezeTimer[client] = null;
	if( !IsValidAliveSurvivor(client) ) return;

	SU_RemoveFreeze(client);
}

// Check if another player is on exhaust mode and set again the postprocess and fog
public void Exhaust_PostCheck()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsValidAliveSurvivor(i) && g_iExhaustToken[i] > 0 )
		{
			CreatePostProcess();
			break; // Don't create multiple instances!
		}
	}
}

public void WeaponFire_Frame(DataPack pack)
{
	pack.Reset();
	int iClient = pack.ReadCell();
	float fPower = pack.ReadFloat();
	delete pack;
	float vForce[3];
	vForce[0] = fPower, vForce[1] = GetRandomFloat(15.0, -15.0) * fPower / 50.0;
	SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngle", vForce);
}

// ====================================================================================================
//										POST PROCESS By Silvers
// ====================================================================================================

void CreatePostProcess()
{
//	float vPos[3];
	int client;

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			client = i;
			break;
		}
	}

	if( client == 0 )
		return;

//	GetClientAbsOrigin(client, vPos);	// No need to teleport entities to players in this scenario

	g_iPostProcess = CreateEntityByName("postprocess_controller");
	if( g_iPostProcess == -1 )
	{
		LogError("Failed to create 'postprocess_controller'");
		return;
	}
	else
	{
		DispatchKeyValue(g_iPostProcess, "targetname", "silver_fx_settings_storm");
		DispatchKeyValue(g_iPostProcess, "vignettestart", "0.15");
		DispatchKeyValue(g_iPostProcess, "vignetteend", "0.8");
		DispatchKeyValue(g_iPostProcess, "vignetteblurstrength", "0.75");
		DispatchKeyValue(g_iPostProcess, "topvignettestrength", "1");
		DispatchKeyValue(g_iPostProcess, "spawnflags", "1");
		DispatchKeyValue(g_iPostProcess, "localcontraststrength", "3.5");
		DispatchKeyValue(g_iPostProcess, "localcontrastedgestrength", "0");
		DispatchKeyValue(g_iPostProcess, "grainstrength", "1");
		DispatchKeyValue(g_iPostProcess, "fadetime", "3");

		DispatchSpawn(g_iPostProcess);
		ActivateEntity(g_iPostProcess);
//		TeleportEntity(g_iPostProcess, vPos, NULL_VECTOR, NULL_VECTOR);	// Don't need to teleport that type of entity
		g_iPostProcess = EntIndexToEntRef(g_iPostProcess);
		SDKHook(g_iPostProcess, SDKHook_SetTransmit, PostProcess_STransmit);
	}

	ToggleFogVolume(false);

	g_iFogVolume = CreateEntityByName("fog_volume");
	if( g_iFogVolume == -1 )
	{
		LogError("Failed to create 'fog_volume'");
	}
	else
	{
		DispatchKeyValue(g_iFogVolume, "PostProcessName", "silver_fx_settings_storm");
		DispatchKeyValue(g_iFogVolume, "spawnflags", "0");

		DispatchSpawn(g_iFogVolume);
		ActivateEntity(g_iFogVolume);

		float vMins[3]; vMins = view_as<float>({ -16384.0, -16384.0, -16384.0 });	// I will use the Hammer limits to make sure no one gets out of the volume
		float vMaxs[3]; vMaxs = view_as<float>({ 16384.0, 16384.0, 16384.0 });
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMaxs", vMaxs);
//		TeleportEntity(g_iFogVolume, vPos, NULL_VECTOR, NULL_VECTOR);	// Don't teleport, let fog_volume stay at center since it covers all the map
	}

	ToggleFogVolume(true);
}

// We have to disable fog_volume when we create ours, so it has priority. Thankfully this works.
// Also saves the enabled/disabled state of fog_volume's we change to prevent visual corruption!
void ToggleFogVolume(bool enable)
{
	if( enable == true )
	{
		if( IsValidEntRef(g_iFogVolume) )
		{
			AcceptEntityInput(g_iFogVolume, "Disable");
			AcceptEntityInput(g_iFogVolume, "Enable");
		}
	}

	int m_bDisabled, entity = -1;

	while( (entity = FindEntityByClassname(entity, "fog_volume")) != INVALID_ENT_REFERENCE )
	{
		if( g_iFogVolume == entity )
		{
			break;
		}

		if( enable == true )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			if( m_bDisabled == 0 )
				AcceptEntityInput(entity, "Enable");
		}
		else if( enable == false )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			SetEntProp(entity, Prop_Data, "m_iHammerID", m_bDisabled);
			AcceptEntityInput(entity, "Disable");
		}
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

//==========================================================================================
//									Natives
//==========================================================================================

public int Native_AddFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Client %i is invalid.", client); // Prevent to freeze invalid clients
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Client %i must be an alive survivor.", client); // Prevent to freeze infected or dead survivors
	
	float fTime = GetNativeCell(2);
	float fCurrTime = 0.0;	// This stores the remaining freeze time of survivor if needed, its taken apart to preserve it from changing it via hook
	float fHookTime = fTime;

	if( fTime < 0.1 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Time value %f is invalid.", fTime); 	// Return error if invalid time!
	
	// First check if the player is frozen to stop silently the function (avoid unnecesary calls if nothing has to happen!)
	if( g_bIsFrozen[client] == true ) 
	{ // Survivor is frozen
		// If ConVar forbiddens increase or change freeze time while placer is frozen
		if( g_hFreezeOverride.IntValue == 0) return;
		// If ConVar forbiddens replace freezetime if new time is lower than current freeze time
		else if( g_hFreezeOverride.IntValue == 1 && fTime + GetGameTime() <= g_fFreezeTime[client] ) return;
		// If ConVar allows to stack freeze time
		else if( g_hFreezeOverride.IntValue == 2 ) fCurrTime =  g_fFreezeTime[client] - GetGameTime();
		// Value 3 means replace allways, not need to do anything here
	}
	
	// Hook function
	Action aResult = Plugin_Continue;
	Call_StartForward(ForwardFreeze);
	Call_PushCell(client);
	Call_PushFloatRef(fHookTime);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Changed && fHookTime >= 0.1) fTime = fHookTime; // If someone puts a bad time throug a hook, ignore it, continue.
	
	else if( aResult == Plugin_Handled ) return;
		
	if( g_bIsFrozen[client] == false ) // Not frozen client, play sound, change state, freeze player, screen color.
	{
		g_bIsFrozen[client] = true;
		EmitSoundToClient(client, SND_FREEZE);
		ScreenColor(client, { 0, 61, 255, 67 }, (0x0002 | 0x0008 | 0x0010));
		SetEntityMoveType(client, MOVETYPE_NONE);
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		BlockPlayerAttacks(client, true);
	}

	delete g_hFreezeTimer[client];
	g_fFreezeTime[client] = fTime + fCurrTime + GetGameTime();
	g_hFreezeTimer[client] = CreateTimer(fTime + fCurrTime, Freeze_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	return;
}

public int Native_RemoveFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveFreeze Error: Client %i is invalid.", client);
	// Nobody should try to unfreeze a dead player, since the plugin does it automatically when player dies
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveFreeze Error: Client %i must be an alive survivor.", client);
	
	delete g_hFreezeTimer[client];
	
	g_bIsFrozen[client] = false;
	ScreenColor(client, { 0, 61, 255, 67}, (0x0001 | 0x0010));
	SetEntityMoveType(client, MOVETYPE_WALK);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	BlockPlayerAttacks(client, false);
	
	Call_StartForward(ForwardFreezeEnd);
	Call_PushCell(client);
	Call_Finish();
	
}

public int Native_AddBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed Error: Client %i must be an alive survivor.", client);
	
	int hits = GetNativeCell(2);
	int currHits = 0;
	if( hits < 0 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed error: Invalid amount: %i", hits);
	int hookHits = hits;
	Action aResult = Plugin_Continue;
		
	if( g_iBleedToken[client] > 0 )
	{
		switch( g_hBleedOverride.IntValue )
		{
			case 0: return;
			case 1: if( hits < g_iBleedToken[client] ) return;
			case 2: currHits = g_iBleedToken[client];
		}
	}
	
	Call_StartForward(ForwardBleed);
	Call_PushCell(client);
	Call_PushCellRef(hookHits);
	Call_Finish(aResult);	

	if( aResult == Plugin_Changed && hookHits > 0 ) hits = hookHits;
	if( aResult == Plugin_Handled ) return;

	g_iBleedToken[client] = hits + currHits;
	
	delete g_hBleedTimer[client];
	g_hBleedTimer[client] = CreateTimer(g_hBleedDelay.FloatValue, BleedDmg_Timer, client, TIMER_FLAG_NO_MAPCHANGE);

	return;
}

public int Native_RemoveBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveBleed Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveBleed Error: Client %i must be an alive survivor.", client);
	
	if( g_hBleedTimer[client] != INVALID_HANDLE )
		delete g_hBleedTimer[client];
		
	g_iBleedToken[client] = 0;
	
	Call_StartForward(ForwardBleedEnd);
	Call_PushCell(client);
	Call_Finish();
}

public int Native_AddToxic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Client %i must be an alive survivor.", client);
	
	int hits = GetNativeCell(2);
	int currHits = 0;
	int hookHits = hits;
	Action aResult = Plugin_Continue;
			
	if( g_iToxicToken[client] > 0 )	// Player is already intoxicated
	{
		switch( g_hToxicOverride.IntValue )
		{
			case 0: return;
			case 1: if( hits < g_iToxicToken[client] ) return;
			case 2: currHits = g_iToxicToken[client];
		}
	}

	Call_StartForward(ForwardToxic);
	Call_PushCell(client);
	Call_PushCellRef(hookHits);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Changed && hookHits > 0 ) hits = hookHits;
	if( aResult == Plugin_Handled ) return;
	
	g_iToxicToken[client] = hits + currHits;
	delete g_hToxicTimer[client];
	g_hToxicTimer[client] = CreateTimer(g_hToxicDelay.FloatValue, ToxicDmg_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	
	return;
}

public int Native_RemoveToxic(Handle plugin, int numParams) 
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveToxic Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveToxic Error: Client %i must be an alive survivor.", client);
	
	if( g_hToxicTimer[client] != INVALID_HANDLE ) // Need to check first if timer handle has been closed...
		delete g_hToxicTimer[client];
		
	g_iToxicToken[client] = 0;
	
	Call_StartForward(ForwardToxicEnd);
	Call_PushCell(client);
	Call_Finish();
}


public int Native_SetSpeed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Client %i is invalid.", client);
	// Since survivor speeds are not reset on player death, they can be modified and accesed while dead
//	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Client %i must be an alive survivor.", client);
	
	int iSpeedType = GetNativeCell(2);
	float fSpeed = GetNativeCell(3);

	switch( iSpeedType )
	{
		case SPEED_RUN:{
			if( fSpeed < 100.0 ) fSpeed = 110.0;
			g_fRunSpeed[client] = fSpeed;
		}
		case SPEED_WALK:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fWalkSpeed[client] = fSpeed;
		}
		case SPEED_CROUCH:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fCrouchSpeed[client] = fSpeed;
		}
		case SPEED_LIMP:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fLimpSpeed[client] = fSpeed;
		}
		case SPEED_CRITICAL:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fCritSpeed[client] = fSpeed;
		}
		case SPEED_WATER:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fWaterSpeed[client] = fSpeed;
		}
		case SPEED_EXHAUST:{
			if( fSpeed < 100.0 ) fSpeed = 110.0;
			g_fExhaustSpeed[client] = fSpeed;
		}
		default: ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Invalid speed type.");
	}
	
	return;
}

public int Native_AddExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Client %i must be an alive survivor.", client);
	
	Action aResult = Plugin_Continue;
	Call_StartForward(ForwardExhaust);
	Call_PushCell(client);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Handled ) return;
	
	if( !IsValidEntRef(g_iPostProcess) ) CreatePostProcess();

	g_iExhaustToken[client] = EXHAUST_TOKEN;
	g_hExhaustTimer[client] = CreateTimer(0.2, Exhaust_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
	return;
}

public int Native_RemoveExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveExhaust Error: Client %i is invalid.", client);
	if( !IsAliveSurvivor(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveExhaust Error: Client %i must be an alive survivor.", client);
	
	if( g_hExhaustTimer[client] != INVALID_HANDLE )
		delete g_hExhaustTimer[client];

	g_iExhaustToken[client] = 0;
	g_iEntMustDie = 1;
	
	Call_StartForward(ForwardExhaustEnd);
	Call_PushCell(client);
	Call_Finish();
}

public int Native_GetFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsFrozen Error: Client %i is invalid.", client);
	// Here is not needed to throw an error with dead survivor, since you only try to get the player stats, this will report that the player is not freeze BECAUSE IT'S DEAD
	// But throw a Native Error if client is not a survivor, this will thell the prograrmer it's trying to get info from wrong client
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);

	return g_bIsFrozen[client];
}

public any Native_GetSpeed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not in game.", client);
	// Basically if someone is doing something wrong and trying to get an infected speed this will be printed
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	

	switch( GetNativeCell(2) )
	{
		case SPEED_RUN:			return g_fRunSpeed[client];
		case SPEED_WALK:		return g_fWalkSpeed[client];
		case SPEED_CROUCH:		return g_fCrouchSpeed[client];
		case SPEED_LIMP:		return g_fLimpSpeed[client];
		case SPEED_CRITICAL:	return g_fCritSpeed[client];
		case SPEED_WATER:		return g_fWaterSpeed[client];
		case SPEED_EXHAUST:		return g_fExhaustSpeed[client];
	}
	
	ThrowNativeError(SP_ERROR_PARAM, "SU_GetSurvivorGetSpeed Error: Invalid speed type.");
	return 0.0;
}

public int Native_GetBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsBleeding Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	
		
	return g_iBleedToken[client] > 0 ? true : false;
}

public int Native_GetToxic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsToxic Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	

	return g_iToxicToken[client] > 0 ? true : false;
}

public int Native_GetExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsExhausted Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	
		
	return g_iExhaustToken[client] > 0 ? true : false;
}

/*============================================================================================
									Changelog
----------------------------------------------------------------------------------------------
* 1.0	(25-Dec-2021)
		- Initial release.
* 1.0.1	(25-Dec-2021)
		- Fixed missing config file.
* 1.0.2 (25-Dec-2021)
		- Changed default override values from 1 to 2.
		- Fixed ConVar descriptions.
* 1.0.3 (25-Dec-2021)
		- Removed debugging messages.
*/