
//////////////////////////
//  thanks for code     //
//      shanapu         //
//////////////////////////

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#define SOUND_HELICOPTER "vehicles/airboat/fan_blade_fullthrottle_loop1.wav"
#define CVAR_FLAGS FCVAR_NOTIFY

bool g_bParachute[MAXPLAYERS+1], g_bLeft4Dead2;
int g_iVelocity = -1, g_iParaEntRef[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};

static char g_sModels[2][] =
{
	"models/props_swamp/parachute01.mdl",
	"models/props/de_inferno/ceiling_fan_blade.mdl"
};

public Plugin myinfo = {
	name = "降落伞",
	author = "Joshe Gatito",
	description = "Adds support for parachutes",
	version = "1.2",
	url = "https://steamcommunity.com/id/joshegatito/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

int g_iSlotSpecial;
int g_iLevelParachute[MAXPLAYERS+1];

public void OnPluginStart()
{	
	g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	LoadTranslations("l4d2sf_parachute.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotSpecial = L4D2SF_RegSlot("special");
	L4D2SF_RegPerk(g_iSlotSpecial, "parachute", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "parachute"))
		FormatEx(result, maxlen, "%T", "降落伞", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "parachute"))
		FormatEx(result, maxlen, "%T", tr("降落伞%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "parachute"))
		g_iLevelParachute[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelParachute[client] = L4D2SF_GetClientPerk(client, "parachute");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void OnMapStart()
{
	for (int i = 0; i < 2; i++)
		PrecacheModel(g_sModels[i]);
	PrecacheSound(SOUND_HELICOPTER);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_iLevelParachute[client] < 1)
	    return Plugin_Continue;
		
	if(g_bParachute[client])
	{
		if(!(buttons & IN_USE) || !IsPlayerAlive(client))
		{
			DisableParachute(client);
			return Plugin_Continue;
		}

		float fVel[3];
		GetEntDataVector(client, g_iVelocity, fVel);

		if(fVel[2] >= 0.0)
		{
			DisableParachute(client);
			return Plugin_Continue;
		}

		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			DisableParachute(client);
			return Plugin_Continue;
		}
		
		float fOldSpeed = fVel[2];

		if(fVel[2] < 100.0 * -1.0) fVel[2] = 100.0 * -1.0;

		if(fOldSpeed != fVel[2])
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
	}
	else
	{
		if(!(buttons & IN_USE) || !IsPlayerAlive(client))
			return Plugin_Continue;

		if(GetEntityFlags(client) & FL_ONGROUND)
			return Plugin_Continue;

		float fVel[3];
		GetEntDataVector(client, g_iVelocity, fVel);

		if(fVel[2] >= 0.0)
			return Plugin_Continue;

		int iEntity = CreateEntityByName("prop_dynamic_override"); 
		DispatchKeyValue(iEntity, "model", g_bLeft4Dead2 ? g_sModels[0] : g_sModels[1]);
		DispatchSpawn(iEntity);
		
		SetEntityMoveType(iEntity, MOVETYPE_NOCLIP);

		float ParachutePos[3], ParachuteAng[3];
		GetClientAbsOrigin(client, ParachutePos);
		GetClientAbsAngles(client, ParachuteAng);
		ParachutePos[2] += 80.0;
		ParachuteAng[0] = 0.0;
		
		TeleportEntity(iEntity, ParachutePos, ParachuteAng, NULL_VECTOR);
		
		if( g_bLeft4Dead2 )
		{		
		    int R = GetRandomInt(0, 255), G = GetRandomInt(0, 255), B = GetRandomInt(0, 255); 
		    SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 1000);
		    SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
		    SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", R + (G * 256) + (B * 65536));
			
		    SetEntPropFloat(iEntity, Prop_Data, "m_flModelScale", 0.3);

		    SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		    SetEntityRenderColor(iEntity, 255, 255, 255, 2);
		}
		
		if( !g_bLeft4Dead2 ) CreateTimer(0.1, Timer_Parachute, EntIndexToEntRef(iEntity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		if( !g_bLeft4Dead2 ) EmitSoundToClient(client, SOUND_HELICOPTER, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_LOW, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		
		SetVariantString("!activator");
		AcceptEntityInput(iEntity, "SetParent", client);

		g_iParaEntRef[client] = EntIndexToEntRef(iEntity);
		g_bParachute[client] = true;
	}

	return Plugin_Continue;
}

public Action Timer_Parachute( Handle timer, any iEntity)
{
	int iParachute = EntRefToEntIndex(iEntity);
	if (IsValidEntity(iParachute))
	{
		RotateParachute(iParachute, 100.0, 1);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void RotateParachute(int index, float value, int axis)
{
	if (IsValidEntity(index))
	{
		float s_rotation[3];
		GetEntPropVector(index, Prop_Data, "m_angRotation", s_rotation);
		s_rotation[axis] += value;
		TeleportEntity( index, NULL_VECTOR, s_rotation, NULL_VECTOR);
	}
}

void DisableParachute(int client)
{
	int iEntity = EntRefToEntIndex(g_iParaEntRef[client]);
	if(iEntity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iEntity, "ClearParent");
		AcceptEntityInput(iEntity, "kill");
	}

	ParachuteDrop(client);
	g_bParachute[client] = false;
	g_iParaEntRef[client] = INVALID_ENT_REFERENCE;
}

void ParachuteDrop(int client)
{
	if (!IsClientInGame(client))
		return;
	
	if( !g_bLeft4Dead2 ) StopSound(client, SNDCHAN_STATIC, SOUND_HELICOPTER);	
}

stock bool IsClientRootAdmin(int client)
{
	return (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0 
	|| (GetUserFlagBits(client) & ADMFLAG_RESERVATION) != 0;
}