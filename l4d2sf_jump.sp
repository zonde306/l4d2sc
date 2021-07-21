#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：连跳/多重跳",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

int g_iSlotAbility;
int g_iLevelBHop[MAXPLAYERS+1], g_iLevelDouble[MAXPLAYERS+1];
ConVar g_hCvarGravity, g_pCvarJumpHeight, g_pCvarDuckHeight, g_pCvarCalmTime;
int g_iOffVelocity;

public OnPluginStart()
{
	InitPlugin("sfj");
	g_hCvarGravity = FindConVar("sv_gravity");
	g_pCvarJumpHeight = CreateConVar("l4d2_sfj_height", "35.0", "跳跃高度", CVAR_FLAGS, true, 0.0);
	g_pCvarDuckHeight = CreateConVar("l4d2_sfj_duck_height", "52.0", "蹲下跳跃高度", CVAR_FLAGS, true, 0.0);
	g_pCvarCalmTime = CreateConVar("l4d2_sfj_calm_time", "1.0", "重置计数时间", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfj");
	
	UpdateCache(null, "", "");
	g_hCvarGravity.AddChangeHook(UpdateCache);
	g_pCvarJumpHeight.AddChangeHook(UpdateCache);
	g_pCvarDuckHeight.AddChangeHook(UpdateCache);
	g_pCvarCalmTime.AddChangeHook(UpdateCache);
	
	LoadTranslations("l4d2sf_jump.phrases.txt");
	
	g_iOffVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_jump_apex", Event_PlayerJumpApex);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "bunnyhop", 3, 70, 5, 0.1);
	L4D2SF_RegPerk(g_iSlotAbility, "doublejump", 1, 80, 5, 0.1);
}

float g_fGravity, g_fJumpHeight, g_fDuckHeight, g_fCalmTime;

public void UpdateCache(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fGravity = g_hCvarGravity.FloatValue;
	g_fJumpHeight = g_pCvarJumpHeight.FloatValue;
	g_fDuckHeight = g_pCvarDuckHeight.FloatValue;
	g_fCalmTime = g_pCvarCalmTime.FloatValue;
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "bunnyhop"))
		FormatEx(result, maxlen, "%T", "连跳", client, level);
	else if(!strcmp(name, "doublejump"))
		FormatEx(result, maxlen, "%T", "多重跳", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "bunnyhop"))
		FormatEx(result, maxlen, "%T", tr("连跳%d", IntBound(level, 1, 3)), client, level);
	else if(!strcmp(name, "doublejump"))
		FormatEx(result, maxlen, "%T", tr("多重跳%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "bunnyhop"))
		g_iLevelBHop[client] = level;
	else if(!strcmp(perk, "doublejump"))
		g_iLevelDouble[client] = level;
}

bool g_bJumpReleased[MAXPLAYERS+1], g_bFirstJump[MAXPLAYERS+1];
int g_iCountBHop[MAXPLAYERS+1], g_iCountMulJmp[MAXPLAYERS+1];

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelBHop[client] = L4D2SF_GetClientPerk(client, "bunnyhop");
	g_iLevelDouble[client] = L4D2SF_GetClientPerk(client, "doublejump");
}

public void Event_PlayerJump(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	// 此时即将起跳(但是还在地面上)
	g_bFirstJump[client] = true;
	g_bJumpReleased[client] = false;
	g_iCountBHop[client] = 0;
	g_iCountMulJmp[client] = 0;
	
	// PrintToChat(client, "player_jump");
}

public void Event_PlayerJumpApex(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	// 此时达到最高点
	g_bFirstJump[client] = false;
	
	// PrintToChat(client, "player_jump_apex");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3],
	int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsValidAliveClient(client) ||
		GetEntProp(client, Prop_Send, "m_isIncapacitated") ||
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge") ||
		IsTrapped(client) || IsGettingUp(client) || IsStaggering(client))
		return;
	
	bool inWalk = (GetEntityMoveType(client) == MOVETYPE_WALK);
	bool inWater = (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1);
	bool inGround = (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1);
	bool canJump = (inWalk && !inWater);
	
	if(!inGround && !(buttons & IN_JUMP))
	{
		// 在空中放开了跳跃键，准备进行多重跳
		g_bJumpReleased[client] = true;
		
		// PrintToChat(client, "JumpReleased");
	}
	
	// 多重跳
	else if(!inGround && canJump && (buttons & IN_JUMP) && g_bJumpReleased[client] && g_iCountMulJmp[client] < g_iLevelDouble[client])
	{
		float velocity[3];
		GetEntDataVector(client, g_iOffVelocity, velocity);
		// velocity[0] = vel[0]; velocity[1] = vel[1]; velocity[2] = vel[2];
		
		float upVel = CaclJumpVelocity(client);
		if(velocity[2] < upVel)
			velocity[2] = upVel;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		
		g_bJumpReleased[client] = false;
		g_iCountMulJmp[client] += 1;
		
		// PrintToChat(client, "DoubleJump");
	}
	
	// 连跳
	else if(inGround && canJump && (buttons & IN_JUMP) && !g_bFirstJump[client] && g_iCountBHop[client] < g_iLevelBHop[client])
	{
		float velocity[3];
		GetEntDataVector(client, g_iOffVelocity, velocity);
		// velocity[0] = vel[0]; velocity[1] = vel[1]; velocity[2] = vel[2];
		
		float upVel = CaclJumpVelocity(client);
		if(velocity[2] < upVel)
			velocity[2] = upVel;
		
		// 因为引擎的问题，必须要把 m_hGroundEntity 设置为 -1 才能在地面上设置向上速度
		// 否则会被摩擦力阻止小于 300.0 的向上速度，即使玩家是完全静止的
		SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		
		g_bJumpReleased[client] = false;
		g_iCountBHop[client] += 1;
		
		// PrintToChat(client, "BunnyHop");
	}
	
	if(inGround && canJump)
	{
		g_iCountMulJmp[client] = 0;
	}
}

float CaclJumpVelocity(int client)
{
	bool ducking = ((GetClientButtons(client) & IN_DUCK) && (GetEntityFlags(client) & FL_DUCKING));
	
	// GetEntityGravity 返回 0.0，好像用不了
	float height = SquareRoot(2.0 * g_fGravity * (ducking ? g_fDuckHeight : g_fJumpHeight)/* / GetEntityGravity(client)*/);
	// PrintToChat(client, "d=%d, gg=%d, pg=%.2f, h=%.0f, jh=%.0f", ducking, g_hCvarGravity.IntValue, GetEntityGravity(client), height, (ducking ? g_fJumpHeightDucking : g_fJumpHeight));
	
	return height;
}

bool IsTrapped(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsDominatedBySpecialInfected()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsGettingUp(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsGettingUp()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsStaggering(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsStaggering()", client), result, sizeof(result));
	return !strcmp(result, "true");
}
