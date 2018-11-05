#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION		"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "连跳/多重跳/降落伞",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define DOUBJEJMP_MAXCOUNT		((SC_GetClientLevel(client) / 19) + 1)
#define AUTOBHOP_MAXCOUNT		((SC_GetClientLevel(client) / 12) + 1)
#define FALLSLOW_MAXSPEED		(g_fParachuteSpeed + (SC_GetClientLevel(client) * 3))

bool g_bHasSpaceReleased[MAXPLAYERS+1];
int g_iOffsetVelocity, g_iJumpStopTick;
float g_fDoubleJumpHeight, g_fBunnyHopHeight, g_fParachuteSpeed;
ConVar g_pCvarDoubleJumpHeight, g_pCvarBunnyHopHeight, g_pCvarParachuteSpeed, g_pCvarJumpTick;
int g_iDoubleJumpCount[MAXPLAYERS+1], g_iOnGroundTick[MAXPLAYERS+1], g_iBhopCount[MAXPLAYERS+1];
bool g_bAllowAutoBHop[MAXPLAYERS+1], g_bAllowDoubleJump[MAXPLAYERS+1], g_bAllowParachute[MAXPLAYERS+1];

public void OnPluginStart()
{
	InitPlugin("abh");
	g_pCvarDoubleJumpHeight = CreateConVar("l4d2_abh_double_jump_height", "300.0", "多重跳高度", CVAR_FLAGS, true, 0.0, true, 900.0);
	g_pCvarJumpTick = CreateConVar("l4d2_abh_jump_tick", "3", "跳越恢复需要多少 tick", CVAR_FLAGS, true, 0.0, true, 30.0);
	g_pCvarBunnyHopHeight = CreateConVar("l4d2_abh_bhop_height", "275.0", "连跳高度", CVAR_FLAGS, true, 0.0, true, 900.0);
	g_pCvarParachuteSpeed = CreateConVar("l4d2_abh_parachute_speed", "-300.0", "降落伞落地速度", CVAR_FLAGS, true, -1000.0, true, 0.0);
	AutoExecConfig(true, "l4d2_autobhop");
	
	ConVarHooked_OnSettingChanged(null, "", "");
	g_pCvarDoubleJumpHeight.AddChangeHook(ConVarHooked_OnSettingChanged);
	g_pCvarBunnyHopHeight.AddChangeHook(ConVarHooked_OnSettingChanged);
	g_pCvarParachuteSpeed.AddChangeHook(ConVarHooked_OnSettingChanged);
	g_pCvarJumpTick.AddChangeHook(ConVarHooked_OnSettingChanged);
	
	// SetupTimerQuery(1.0, Timer_QueryClientSkill);
	g_iOffsetVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	CreateTimer(1.0, Timer_SetupSkill);
}

public void ConVarHooked_OnSettingChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fDoubleJumpHeight = g_pCvarDoubleJumpHeight.FloatValue;
	g_fBunnyHopHeight = g_pCvarBunnyHopHeight.FloatValue;
	g_fParachuteSpeed = g_pCvarParachuteSpeed.FloatValue;
	g_iJumpStopTick = g_pCvarJumpTick.IntValue;
}

public Action Timer_SetupSkill(Handle timer, any unused)
{
	SC_CreateSkill("abh_autobhop", "自动连跳", 0, "按住空格键自动连跳");
	SC_CreateSkill("abh_doublejump", "多重跳", 0, "在空中可以多次起跳");
	SC_CreateSkill("abh_parachute", "降落伞", 0, "按住 E 降低下坠速度");
	return Plugin_Continue;
}

/*
public Action Timer_QueryClientSkill(Handle timer, any unused)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			g_bAllowAutoBHop[i] = SC_IsClientHaveSkill(i, "abh_autobhop");
			g_bAllowDoubleJump[i] = SC_IsClientHaveSkill(i, "abh_doublejump");
			g_bAllowParachute[i] = SC_IsClientHaveSkill(i, "abh_parachute");
		}
		else
		{
			g_bAllowAutoBHop[i] = false;
			g_bAllowDoubleJump[i] = false;
			g_bAllowParachute[i] = false;
		}
	}
	
	return Plugin_Continue;
}
*/

void UpdatePlayerSkill()
{
	static float nextTime;
	float time = GetEngineTime();
	if(nextTime > time)
		return;
	
	nextTime = time + 1.0;
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			g_bAllowAutoBHop[i] = SC_IsClientHaveSkill(i, "abh_autobhop");
			g_bAllowDoubleJump[i] = SC_IsClientHaveSkill(i, "abh_doublejump");
			g_bAllowParachute[i] = SC_IsClientHaveSkill(i, "abh_parachute");
		}
		else
		{
			g_bAllowAutoBHop[i] = false;
			g_bAllowDoubleJump[i] = false;
			g_bAllowParachute[i] = false;
		}
	}
}

public Action SC_OnSkillGetInfo(int client, const char[] classname,
	char[] display, int displayMaxLength, char[] description, int descriptionMaxLength)
{
	if(StrEqual(classname, "abh_doublejump", false))
		FormatEx(description, descriptionMaxLength, "在空中可以跳跃 %d 次", DOUBJEJMP_MAXCOUNT);
	else if(StrEqual(classname, "abh_autobhop", false))
		FormatEx(description, descriptionMaxLength, "自动连跳 %d 次强制崴脚\n手动跳不影响", AUTOBHOP_MAXCOUNT);
	else
		return Plugin_Continue;
	
	return Plugin_Changed;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3],
	const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsPluginAllow() || !IsValidAliveClient(client))
		return;
	
	UpdatePlayerSkill();
	
	// 检查是否可以跳跃
	if(GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
		return;
	
	float velocity[3];
	GetEntDataVector(client, g_iOffsetVelocity, velocity);
	bool hasChanged = false;
	bool onGround = (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1);
	if(!onGround && (buttons & IN_USE) && g_bAllowParachute[client])
	{
		float speed = FALLSLOW_MAXSPEED;
		if(speed > -100.0)
			speed = -100.0;
		
		if(velocity[2] < speed)
			velocity[2] = speed;
		
		// 降落，减少掉落速度
		// TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		// return Plugin_Changed;
		hasChanged = true;
	}
	
	if(!onGround && !(buttons & IN_JUMP))
	{
		// 按住空格键是连跳，按一下是多重跳
		g_bHasSpaceReleased[client] = true;
	}
	
	if(onGround)
	{
		if((buttons & IN_JUMP) && g_iBhopCount[client] > 0 && g_bAllowAutoBHop[client])
		{
			// 每级增加 1 连跳高度
			velocity[2] = g_fBunnyHopHeight/* + SC_GetClientLevel(client)*/;
			g_iBhopCount[client] -= 1;
			
			// 因为引擎的问题，必须要把 m_hGroundEntity 设置为 -1 才能在地面上设置向上速度
			// 否则会被摩擦力阻止小于 300.0 的向上速度，即使玩家是完全静止的
			SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
			// TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
			
			// 通知其他插件
			Event event = CreateEvent("player_jump");
			event.SetInt("userid", GetClientUserId(client));
			event.Fire();
			
			hasChanged = true;
		}
		
		if(++(g_iOnGroundTick[client]) >= g_iJumpStopTick)
		{
			// 每 15 级获得一次额外的多重跳的机会
			g_iDoubleJumpCount[client] = DOUBJEJMP_MAXCOUNT;
			g_iBhopCount[client] = AUTOBHOP_MAXCOUNT;
			g_iOnGroundTick[client] = 0;
		}
		
		g_bHasSpaceReleased[client] = false;
	}
	else
	{
		if(g_iDoubleJumpCount[client] > 0 && g_bHasSpaceReleased[client] &&
			(buttons & IN_JUMP) && g_bAllowDoubleJump[client])
		{
			g_iDoubleJumpCount[client] -= 1;
			g_bHasSpaceReleased[client] = false;
			
			// 每级增加 2 多重跳高度
			velocity[2] = g_fDoubleJumpHeight/* + (SC_GetClientLevel(client) * 2)*/;
			// TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
			
			// 通知其他插件
			Event event = CreateEvent("player_jump");
			event.SetInt("userid", GetClientUserId(client));
			event.Fire();
			
			hasChanged = true;
		}
		
		g_iOnGroundTick[client] = 0;
	}
	
	if(hasChanged)
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}
