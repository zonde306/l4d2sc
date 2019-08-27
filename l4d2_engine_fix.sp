#define PLUGIN_VERSION "1.1"

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define debug 0

#define FIRST_RESTORE_TIME 0.3
#define RESTORE_TIME 2.0
#define MAX_HEALTH_PER_RESTORE 10
#define MAX_HEALTH 100
#define CONSTANT_HEALTH 1
#define MAX_TEMP_HEALTH MAX_HEALTH - CONSTANT_HEALTH

public Plugin myinfo =
{
	name = "[L4D & L4D2] Engine Fix",
	author = "raziEiL [disawar1]",
	description = "Blocking ladder speed glitch, no fall damage bug, health boost glitch.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

enum ()
{
	LadderSpeedGlitch = 1,
	NoFallDamageBug,
	HealthBoostGlitch
};

static Handle g_hFixGlitchTimer[MAXPLAYERS+1];
int g_iHealthToRestore[MAXPLAYERS+1];
int g_iLastKnownHealth[MAXPLAYERS+1];
Handle g_hRestoreTimer[MAXPLAYERS+1];
int g_bTempWarnLock[MAXPLAYERS+1];
float g_fCvarDecayRate;
bool g_bCvarWarnEnabled;
int g_iCvarEngineFlags;

public void OnPluginStart()
{
	Handle hCvarDecayRate = FindConVar("pain_pills_decay_rate");

	CreateConVar("engine_fix_version", PLUGIN_VERSION, "Engine Fix plugin version", FCVAR_REPLICATED|FCVAR_NOTIFY);

	Handle hCvarWarnEnabled = CreateConVar("engine_warning", "0", "Display a warning message saying that player using expolit: 1=enable, 0=disable.");
	Handle hCvarEngineFlags = CreateConVar("engine_fix_flags", "14", "Enables what kind of exploit should be fixed/blocked. Flags (add together): 0=disable, 2=ladder speed glitch, 4=no fall damage bug, 8=health boost glitch.");
	//AutoExecConfig(true, "Fix_Engine");

	g_fCvarDecayRate = GetConVarFloat(hCvarDecayRate);
	g_bCvarWarnEnabled = GetConVarBool(hCvarWarnEnabled);
	g_iCvarEngineFlags = GetConVarInt(hCvarEngineFlags);

	if (g_iCvarEngineFlags & (1 << HealthBoostGlitch))
		EF_ToogleEvents(true);

	HookConVarChange(hCvarDecayRate, OnConvarChange_DecayRate);
	HookConVarChange(hCvarWarnEnabled, OnConvarChange_WarnEnabled);
	HookConVarChange(hCvarEngineFlags, OnConvarChange_EngineFlags);

#if debug
	RegConsoleCmd("debug", CmdDebug);
#endif
}

/*                                      +==========================================+
                                        |               LADDER GLITCH              |
                                        |             NO FALL DMG GLITCH           |
                                        +==========================================+
*/
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (g_iCvarEngineFlags && IsPlayerAlive(client) && !IsFakeClient(client)){

		if (g_iCvarEngineFlags & (1 << LadderSpeedGlitch) && GetEntityMoveType(client) == MOVETYPE_LADDER){

			static iUsingBug[MAXPLAYERS+1];

			if (buttons & 8 || buttons & 16){

				if (buttons & 512)
				{
					iUsingBug[client]++;
					buttons &= ~IN_MOVELEFT;
				}

				if (buttons & 1024)
				{
					iUsingBug[client]++;
					buttons &= ~IN_MOVERIGHT;
				}

				if (g_bCvarWarnEnabled && iUsingBug[client] > 48)
				{
					WarningsMsg(client, 1);
					iUsingBug[client] = 0;
				}
			}
			else
				iUsingBug[client] = 0;
		}

		if (g_iCvarEngineFlags & (1 << NoFallDamageBug) && GetClientTeam(client) == 2 && IsFallDamage(client) && buttons & IN_USE)
		{
			buttons &= ~IN_USE;

			if (g_bCvarWarnEnabled && !g_bTempWarnLock[client])
			{
				g_bTempWarnLock[client] = true;
				WarningsMsg(client, 2);
				CreateTimer(5.0, EF_t_UnlockWarnMsg, client);
			}
		}
	}
	return Plugin_Continue;
}

public Action EF_t_UnlockWarnMsg(Handle timer, any client)
{
	g_bTempWarnLock[client] = false;
}

bool IsFallDamage(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flFallVelocity") > 440;
}

/*                                      +==========================================+
                                        |               DROWN GLITCH               |
                                        +==========================================+
*/
public void OnClientDisconnect(int client)
{
	if (client && g_iCvarEngineFlags & (1 << HealthBoostGlitch))
		EF_ClearAllVars(client);
}

public void EF_ev_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		EF_ClearAllVars(i);

		if (IsClientInGame(i) && IsDrownPropNotEqual(i))
			ForceEqualDrownProp(i);
	}
}

public void EF_ev_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (GetEventInt(event, "type") & DMG_DROWN)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (IsIncapacitated(client)) return;

		if (GetEventInt(event, "health") == CONSTANT_HEALTH){

			int damage = GetEventInt(event, "dmg_health");
			if (g_iLastKnownHealth[client] && damage >= g_iLastKnownHealth[client])
			{
				damage -= g_iLastKnownHealth[client];
				g_iLastKnownHealth[client] -= CONSTANT_HEALTH;
			}

			if (g_iHealthToRestore[client] < 0)
				g_iHealthToRestore[client] = 0;

			if (!g_iHealthToRestore[client])
			{
				EF_KillRestoreTimer(client);
				CreateTimer(FIRST_RESTORE_TIME, EF_t_CheckRestoring, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}

			g_iHealthToRestore[client] += damage;
#if debug
			PrintToChatAll("m_idrowndmg = %d, dmg = %d, temp hp to restote = %d", GetEntProp(client, Prop_Data, "m_idrowndmg"), damage, g_iHealthToRestore[client]);
#endif
			Handle hdataPack;
			CreateDataTimer(0.1, EF_t_SetDrownDmg, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(hdataPack, client);
			WritePackCell(hdataPack, GetEntProp(client, Prop_Data, "m_idrowndmg") + g_iLastKnownHealth[client]);

			g_iLastKnownHealth[client] = 0;
		}
		else
			g_iLastKnownHealth[client] = GetEventInt(event, "health");
	}
}

public Action EF_t_SetDrownDmg(Handle timer, Handle datapack)
{
	ResetPack(datapack, false);
	int client = ReadPackCell(datapack);

	if (!IsSurvivor(client)) return;

	int drowndmg = ReadPackCell(datapack);

	SetEntProp(client, Prop_Data, "m_idrowndmg", drowndmg);
}

public Action EF_t_CheckRestoring(Handle timer, any client)
{
	if (g_iHealthToRestore[client] <= 0 || !IsSurvivor(client))
	{
		g_iHealthToRestore[client] = 0;
		return Plugin_Stop;
	}

	if (IsUnderWater(client))
		return Plugin_Continue;

	float fHealthToRestore = float(GetEntProp(client, Prop_Data, "m_idrowndmg") - GetEntProp(client, Prop_Data, "m_idrownrestored"));

	if (fHealthToRestore <= 0)
	{
#if debug
		PrintToChatAll("restoring started (player using glitch while have 1-10hp");
#endif
		g_hRestoreTimer[client] = CreateTimer(RESTORE_TIME, EF_t_RestoreTempHealth, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}

	int iRestoreCount = RoundToCeil(fHealthToRestore / MAX_HEALTH_PER_RESTORE);
	float fRestoreTimeEnd = RESTORE_TIME * float(iRestoreCount);
#if debug
	PrintToChatAll("restore count = %d (beginning in %.0f sec.)", iRestoreCount, fRestoreTimeEnd);
#endif
	CreateTimer(fRestoreTimeEnd, EF_t_StartRestoreTempHealth, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action EF_t_StartRestoreTempHealth(Handle timer, any client)
{
	if (g_iHealthToRestore[client] <= 0 || !IsSurvivor(client)) return;
#if debug
	PrintToChatAll("restoring started");
#endif
	g_hRestoreTimer[client] = CreateTimer(RESTORE_TIME, EF_t_RestoreTempHealth, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action EF_t_RestoreTempHealth(Handle timer, any client)
{
	if (g_iHealthToRestore[client] <= 0 || !IsSurvivor(client))
	{
		EF_ClearVars(client);
		return Plugin_Stop;
	}

	if (!IsUnderWater(client) && !IsDrownPropNotEqual(client))
	{
		float fTemp = GetTempHealth(client);
		int iLimit = MAX_TEMP_HEALTH - (GetClientHealth(client) + RoundToFloor(fTemp));
		int iTempToRestore = g_iHealthToRestore[client] >= MAX_HEALTH_PER_RESTORE ? MAX_HEALTH_PER_RESTORE : g_iHealthToRestore[client];
		if (iTempToRestore > iLimit)
		{
#if debug
			PrintToChatAll("temp health limit is exceeded");
#endif
			iTempToRestore = iLimit;
			g_iHealthToRestore[client] = 0;

			if (iTempToRestore <= 0)
				return Plugin_Continue;
		}

		SetTempHealth(client, fTemp + iTempToRestore);
		g_iHealthToRestore[client] -= MAX_HEALTH_PER_RESTORE;

		EF_GlitchWarnFunc(client);
	}

	return Plugin_Continue;
}

public void EF_ev_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, StrEqual(name, "player_incapacitated") ? "userid" : "subject"));
	if (IsDrownPropNotEqual(client))
	{
#if debug
		PrintToChatAll("reset drownrestored prop %N", client);
#endif
		EF_ClearVars(client);
		ForceEqualDrownProp(client);
	}
}

public void EF_ev_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsDrownPropNotEqual(client))
	{
		EF_KillFixGlitchTimer(client);
		g_hFixGlitchTimer[client] = CreateTimer(0.0, EF_t_FixTempHpGlitch, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action EF_t_FixTempHpGlitch(Handle timer, any client)
{
	if (IsSurvivor(client) && !IsIncapacitated(client))
	{
		float fTemp = GetTempHealth(client);
		if (fTemp)
		{
			int iHealth = GetClientHealth(client);
			if ((iHealth + RoundToFloor(fTemp)) > MAX_TEMP_HEALTH)
			{
				SetTempHealth(client, float(MAX_HEALTH - iHealth));

				EF_GlitchWarnFunc(client);
#if debug
				PrintToChatAll("temp glitch fixed");
#endif
			}
		}
		if (IsDrownPropNotEqual(client))
			return Plugin_Continue;
	}
#if debug
	PrintToChatAll("stopped temp glich fix timer");
#endif
	g_hFixGlitchTimer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

void EF_GlitchWarnFunc(int client)
{
	if (g_bCvarWarnEnabled && !g_bTempWarnLock[client])
	{
		g_bTempWarnLock[client] = true;
		WarningsMsg(client, 3);
		CreateTimer(15.0, EF_t_UnlockWarnMsg, client);
	}
}

void EF_KillRestoreTimer(int client)
{
	if (g_hRestoreTimer[client] != INVALID_HANDLE)
	{
#if debug
		PrintToChatAll("restoring stopped");
#endif
		KillTimer(g_hRestoreTimer[client]);
		g_hRestoreTimer[client] = INVALID_HANDLE;
	}
}

void EF_KillFixGlitchTimer(int client)
{
	if (g_hFixGlitchTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hFixGlitchTimer[client]);
		g_hFixGlitchTimer[client] = INVALID_HANDLE;
	}
}

void EF_ClearVars(int client)
{
	EF_KillRestoreTimer(client);
	g_iHealthToRestore[client] = 0;
	g_iLastKnownHealth[client] = 0;
}

void EF_ClearAllVars(int client)
{
	EF_ClearVars(client);
	EF_KillFixGlitchTimer(client);
}

bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsUnderWater(int client)
{
	return GetEntProp(client, Prop_Send, "m_nWaterLevel") == 3;
}

int IsIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool IsDrownPropNotEqual(int client)
{
	return GetEntProp(client, Prop_Data, "m_idrowndmg") != GetEntProp(client, Prop_Data, "m_idrownrestored");
}

void ForceEqualDrownProp(int client)
{
	SetEntProp(client, Prop_Data, "m_idrownrestored", GetEntProp(client, Prop_Data, "m_idrowndmg"));
}

void SetTempHealth(int client, float health)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health);
}
// Code by SilverShot aka Silvers (Healing Gnome plugin https://forums.alliedmods.net/showthread.php?p=1658852)
float GetTempHealth(int client)
{
	float fTempHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fTempHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fCvarDecayRate;
	return fTempHealth < 0.0 ? 0.0 : fTempHealth;
}

void WarningsMsg(int client, int msg)
{
	char STEAM_ID[32];
	GetClientAuthId(client, AuthId_Steam2, STEAM_ID, sizeof(STEAM_ID));
	switch (msg)
	{
		case 1:
			PrintToChatAll("%N (%s) attempted to use a ladder speed glitch.", client, STEAM_ID);
		case 2:
			PrintToChatAll("%N (%s) is suspected of using a no fall damage bug.", client, STEAM_ID);
		case 3:
			PrintToChatAll("%N (%s) attempted to use a health boost glitch.", client, STEAM_ID);
	}
}

public void OnConvarChange_DecayRate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fCvarDecayRate = GetConVarFloat(convar);
}

public void OnConvarChange_WarnEnabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCvarWarnEnabled = GetConVarBool(convar);
}

public void OnConvarChange_EngineFlags(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarEngineFlags = GetConVarInt(convar);
	EF_ToogleEvents(view_as<bool>((g_iCvarEngineFlags & (1 << HealthBoostGlitch))));
}

void EF_ToogleEvents(bool bHook)
{
	static bool bIsHooked;
	if (!bIsHooked && bHook)
	{
		for (int i = 1; i <= MAXPLAYERS; i++)
			EF_ClearAllVars(i);

		HookEvent("round_start", EF_ev_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("pills_used", EF_ev_PillsUsed);
		HookEvent("player_hurt", EF_ev_PlayerHurt);
		HookEvent("heal_success", EF_ev_HealSuccess);
		HookEvent("revive_success", EF_ev_HealSuccess);
		HookEvent("player_incapacitated", EF_ev_HealSuccess);
	}
	else if (bIsHooked && !bHook)
	{
		UnhookEvent("round_start", EF_ev_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("pills_used", EF_ev_PillsUsed);
		UnhookEvent("player_hurt", EF_ev_PlayerHurt);
		UnhookEvent("heal_success", EF_ev_HealSuccess);
		UnhookEvent("revive_success", EF_ev_HealSuccess);
		UnhookEvent("player_incapacitated", EF_ev_HealSuccess);
	}
}

/*                                      +==========================================+
                                        |               Debug Stuff                |
                                        +==========================================+
*/
#if debug
static bool g_bDebugEnabled[MAXPLAYERS+1];
Handle g_hDebugTimer[MAXPLAYERS+1];

public Action CmdDebug(int client, int agrs)
{
	g_bDebugEnabled[client] = !g_bDebugEnabled[client];

	if (g_bDebugEnabled[client])
	{
		PrintHintText(client, "LOADING...");
		CreateTimer(1.0, EF_t_LoadDebug, client);
	}
	else
	{
		DisableDebug(client);
		PrintHintText(client, "Developers Stuff by raziEiL", client);
	}
	return Plugin_Handled;
}

public Action EF_t_LoadDebug(Handle timer, any client)
{
	g_hDebugTimer[client] = CreateTimer(0.1, EF_t_DebugMe, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action EF_t_DebugMe(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		float speed = GetEntPropFloat(client, Prop_Data, "m_flGroundSpeed");
		float fall = GetEntPropFloat(client, Prop_Send, "m_flFallVelocity");

		PrintCenterText(client, "%d/%d", GetEntProp(client, Prop_Data, "m_idrownrestored"), GetEntProp(client, Prop_Data, "m_idrowndmg"));

		if (GetEntityMoveType(client) == MOVETYPE_LADDER)
		{
			if (speed > 130)
				PrintHintText(client, "Ground Speed %f WARNING!!!!", speed);
			else
				PrintHintText(client, "Ground Speed %f", speed);
		}
		else
		{
			if (fall != 0)
			{
				PrintHintText(client, "Move type %d | Flags %d\n Fall Speed: %f\n Health %d(%f)", GetEntityMoveType(client), GetEntityFlags(client), fall, GetClientHealth(client), GetTempHealth(client));
				if (fall > 500)
					PrintCenterText(client, "FALL DMG!");
			}
			else
				PrintHintText(client, "Move type %d | Flags %d\n Ground Speed %f\n Health %d(%f)", GetEntityMoveType(client), GetEntityFlags(client), speed, GetClientHealth(client), GetTempHealth(client));
		}
	}
	else
		DisableDebug(client);
}

void DisableDebug(int client)
{
	if (g_hDebugTimer[client] != INVALID_HANDLE){

		KillTimer(g_hDebugTimer[client]);
		g_hDebugTimer[client] = INVALID_HANDLE;
	}
}
#endif