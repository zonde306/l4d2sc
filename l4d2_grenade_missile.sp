#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION			"0.2"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "榴弹跟踪导弹",
	author = "zonde306",
	description = "火瓶/土雷/胆汁/榴弹 可以 跟踪敌人/拖尾",
	version = PLUGIN_VERSION,
	url = ""
};

enum MissileInfo_t
{
	MissileEntity,
	MissileEnemy,
	MissileOwner,
	Float:MissileStartTime,
	Float:MissileTime,
	MissileType,
};

// 拖尾颜色
#define COLOR_MOLOTOV			{255, 0, 0, 255}
#define COLOR_PIPEBOMB			{255, 255, 255, 255}
#define COLOR_VOMITJAR			{0, 255, 0, 255}
#define COLOR_GRENADE			{255, 0, 255, 255}

bool g_bRoundStarted = false;
float g_fMissileFlySpeed, g_fMissileScanRadius;
ArrayList g_hArrayEnemyList, g_hArrayMissileList;
int g_iOffsetVelocity, g_iSpriteLaser, g_iSpriteBream;
bool g_bMissileScanSpecial, g_bMissileScanCommon, g_bMissileFollowCrosshair;
Handle g_pfnMolotovDetonate, g_pfnPipeBombDetonate, g_pfnVomitjarDetonate, g_pfnGrenadeTouch;
ConVar g_pCvarAllowMolotov, g_pCvarAllowPipeBomb, g_pCvarAllowBile, g_pCvarAllowGrenade,
	g_pCvarDetonateMolotov, g_pCvarDetonatePipeBomb, g_pCvarDetonateBile, g_pCvarDetonateGrenade,
	g_pCvarTrailMolotov, g_pCvarTrailPipeBomb, g_pCvarTrailBile, g_pCvarTrailGrenade,
	g_pCvarFlySpeed, g_pCvarSearchRadius, g_pCvarScanSpecial, g_pCvarScanCommon, g_pCvarFollow;

public void OnPluginStart()
{
	InitPlugin("gm");
	g_pCvarAllowMolotov = CreateConVar("l4d2_gm_molotov_allow", "1", "是否允许跟踪火瓶", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDetonateMolotov = CreateConVar("l4d2_gm_molotov_explode", "1", "是否允许跟踪火瓶自动爆炸", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarTrailMolotov = CreateConVar("l4d2_gm_molotov_trails", "1", "是否允许跟踪火瓶显示轨迹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarAllowPipeBomb = CreateConVar("l4d2_gm_pipebomb_allow", "1", "是否允许跟踪土雷", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDetonatePipeBomb = CreateConVar("l4d2_gm_pipebomb_explode", "1", "是否允许跟踪土雷自动爆炸", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarTrailPipeBomb = CreateConVar("l4d2_gm_pipebomb_trails", "1", "是否允许跟踪土雷显示轨迹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarAllowBile = CreateConVar("l4d2_gm_vomitjar_allow", "1", "是否允许跟踪胆汁", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDetonateBile = CreateConVar("l4d2_gm_vomitjar_explode", "1", "是否允许跟踪胆汁自动爆炸", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarTrailBile = CreateConVar("l4d2_gm_vomitjar_trails", "1", "是否允许跟踪胆汁显示轨迹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarAllowGrenade = CreateConVar("l4d2_gm_glp_allow", "1", "是否允许跟踪榴弹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarDetonateGrenade = CreateConVar("l4d2_gm_glp_explode", "1", "是否允许跟踪榴弹自动爆炸", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarTrailGrenade = CreateConVar("l4d2_gm_glp_trails", "1", "是否允许跟踪榴弹显示轨迹", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarFlySpeed = CreateConVar("l4d2_gm_fly_speed", "800.0", "跟踪导弹飞行速度", CVAR_FLAGS, true, 100.0, true, 3000.0);
	g_pCvarSearchRadius = CreateConVar("l4d2_gm_radius", "1000.0", "跟踪导弹搜索敌人范围", CVAR_FLAGS, true, 100.0, true, 8192.0);
	g_pCvarScanSpecial = CreateConVar("l4d2_gm_special", "1", "跟踪导弹搜索特感", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarScanCommon = CreateConVar("l4d2_gm_common", "1", "跟踪导弹搜索普感", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarFollow = CreateConVar("l4d2_gm_follow", "1", "跟踪导弹跟随准星", CVAR_FLAGS, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_grenade_missile");
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_left_start_area", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd);
	
	ConVarHooked_OnSettingUpdated(null, "", "");
	g_pCvarFlySpeed.AddChangeHook(ConVarHooked_OnSettingUpdated);
	g_pCvarSearchRadius.AddChangeHook(ConVarHooked_OnSettingUpdated);
	g_pCvarScanSpecial.AddChangeHook(ConVarHooked_OnSettingUpdated);
	g_pCvarScanCommon.AddChangeHook(ConVarHooked_OnSettingUpdated);
	g_pCvarFollow.AddChangeHook(ConVarHooked_OnSettingUpdated);
	
	g_hArrayEnemyList = CreateArray();
	g_hArrayMissileList = CreateArray(MissileInfo_t);
	g_iOffsetVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	// 要不 Hook 这些函数来检查销毁？
	Handle file = LoadGameConfigFile("l4d2_grenade_missile");
	if(file != null)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(file, SDKConf_Signature, "CMolotovProjectile::Detonate");
		g_pfnMolotovDetonate = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(file, SDKConf_Signature, "CPipeBombProjectile::Detonate");
		g_pfnPipeBombDetonate = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(file, SDKConf_Signature, "CVomitJarProjectile::Detonate");
		g_pfnVomitjarDetonate = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(file, SDKConf_Signature, "CGrenadeLauncher_Projectile::ExplodeTouch");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_pfnGrenadeTouch = EndPrepSDKCall();
	}
	else
	{
		g_pfnMolotovDetonate = null;
		g_pfnPipeBombDetonate = null;
		g_pfnVomitjarDetonate = null;
		g_pfnGrenadeTouch = null;
	}
}

public void OnMapStart()
{
	g_iSpriteLaser = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iSpriteBream = PrecacheModel("materials/sprites/glow.vmt");
}

public void ConVarHooked_OnSettingUpdated(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fMissileFlySpeed = g_pCvarFlySpeed.FloatValue;
	g_fMissileScanRadius = g_pCvarSearchRadius.FloatValue;
	g_bMissileScanSpecial = g_pCvarScanSpecial.BoolValue;
	g_bMissileScanCommon = g_pCvarScanCommon.BoolValue;
	g_bMissileFollowCrosshair = g_pCvarFollow.BoolValue;
}

public void Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	g_bRoundStarted = true;
}

public void Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
	g_bRoundStarted = false;
	
	int entity = -1;
	new data[MissileInfo_t];
	int maxLength = g_hArrayMissileList.Length;
	for(int i = 0; i < maxLength; ++i)
	{
		g_hArrayMissileList.GetArray(i, data, MissileInfo_t);
		SDKUnhook(data[MissileEntity], SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
		SDKUnhook(data[MissileEntity], SDKHook_Think, SDKHooked_ProjectileThinking);
		SDKUnhook(data[MissileEntity], SDKHook_StartTouchPost, SDKHooked_ProjectileTouching);
	}
	
	g_hArrayEnemyList.Clear();
	g_hArrayMissileList.Clear();
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!g_bRoundStarted)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(victim))
		victim = event.GetInt("entityid");
	if(!IsValidEdict(victim))
		return;
	
	int index = g_hArrayEnemyList.FindValue(victim);
	if(index > -1)
		g_hArrayEnemyList.Erase(index);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsPluginAllow() || !g_bRoundStarted)
		return;
	
	if(entity <= MaxClients || StrContains(classname, "_projectile", false) == -1)
		return;
	
	if(StrEqual("molotov_projectile", classname, false))
	{
		if(g_pCvarAllowMolotov.BoolValue)
			SDKHook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
		
		if(g_pCvarTrailMolotov.BoolValue)
		{
			if(GetRandomInt(0, 1))
				TE_SetupBeamFollow(entity, g_iSpriteLaser, 0, 2.0, 2.0, 10.0, 5, COLOR_MOLOTOV);
			else
				TE_SetupBeamFollow(entity, g_iSpriteBream, 0, 2.0, 2.0, 10.0, 5, COLOR_MOLOTOV);
			TE_SendToAll();
		}
	}
	else if(StrEqual("pipe_bomb_projectile", classname, false))
	{
		if(g_pCvarAllowPipeBomb.BoolValue)
			SDKHook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
		
		if(g_pCvarTrailPipeBomb.BoolValue)
		{
			if(GetRandomInt(0, 1))
				TE_SetupBeamFollow(entity, g_iSpriteLaser, 0, 2.0, 2.0, 10.0, 5, COLOR_PIPEBOMB);
			else
				TE_SetupBeamFollow(entity, g_iSpriteBream, 0, 2.0, 2.0, 10.0, 5, COLOR_PIPEBOMB);
			TE_SendToAll();
		}
	}
	else if(StrEqual("vomitjar_projectile", classname, false))
	{
		if(g_pCvarAllowBile.BoolValue)
			SDKHook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
		
		if(g_pCvarTrailBile.BoolValue)
		{
			if(GetRandomInt(0, 1))
				TE_SetupBeamFollow(entity, g_iSpriteLaser, 0, 2.0, 2.0, 10.0, 5, COLOR_VOMITJAR);
			else
				TE_SetupBeamFollow(entity, g_iSpriteBream, 0, 2.0, 2.0, 10.0, 5, COLOR_VOMITJAR);
			TE_SendToAll();
		}
	}
	else if(StrEqual("grenade_launcher_projectile", classname, false))
	{
		if(g_pCvarAllowGrenade.BoolValue)
			SDKHook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
		
		if(g_pCvarTrailGrenade.BoolValue)
		{
			if(GetRandomInt(0, 1))
				TE_SetupBeamFollow(entity, g_iSpriteLaser, 0, 2.0, 2.0, 10.0, 5, COLOR_GRENADE);
			else
				TE_SetupBeamFollow(entity, g_iSpriteBream, 0, 2.0, 2.0, 10.0, 5, COLOR_GRENADE);
			TE_SendToAll();
		}
	}
	
	/*
	if(StrEqual("molotov_projectile", classname, false) ||
		StrEqual("pipe_bomb_projectile", classname, false) ||
		StrEqual("vomitjar_projectile", classname, false) ||
		StrEqual("grenade_launcher_projectile", classname, false))
		SDKHook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
	*/
}

// TODO: 使用更好的方法来检查，否则可能会卡
public void OnEntityDestroyed(int entity)
{
	int index = FindGrenade(entity);
	if(index != -1)
		g_hArrayMissileList.Erase(index);
}

public void SDKHooked_ProjectileSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, SDKHooked_ProjectileSpawned);
	
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	
#if defined PLUGIN_DEBUG
	PrintToChatAll("[DBG] 玩家 %N 发射了 %s 导弹 (%d)", client, classname, entity);
#endif
	
	new data[MissileInfo_t];
	data[MissileEntity] = entity;
	data[MissileOwner] = client;
	data[MissileEnemy] = -1;
	data[MissileStartTime] = GetGameTime() + 0.1;
	data[MissileTime] = GetGameTime();
	
	if(StrEqual("molotov_projectile", classname, false))
		data[MissileType] = 1;
	else if(StrEqual("pipe_bomb_projectile", classname, false))
		data[MissileType] = 2;
	else if(StrEqual("vomitjar_projectile", classname, false))
		data[MissileType] = 3;
	else if(StrEqual("grenade_launcher_projectile", classname, false))
		data[MissileType] = 4;
	else
		data[MissileType] = 0;
	
	SetEntityGravity(entity, 0.01);
	g_hArrayMissileList.PushArray(data, MissileInfo_t);
	// SDKHook(entity, SDKHook_Think, SDKHooked_ProjectileThinking);
	SDKHook(entity, SDKHook_StartTouchPost, SDKHooked_ProjectileTouching);
}

int FindGrenade(int entity)
{
	new data[MissileInfo_t];
	int maxLength = g_hArrayMissileList.Length;
	for(int i = 0; i < maxLength; ++i)
	{
		g_hArrayMissileList.GetArray(i, data, MissileInfo_t);
		if(data[MissileEntity] == entity)
			return i;
	}
	
	return -1;
}

public void SDKHooked_ProjectileTouching(int entity, int toucher)
{
	SDKUnhook(entity, SDKHook_Think, SDKHooked_ProjectileThinking);
	SDKUnhook(entity, SDKHook_StartTouchPost, SDKHooked_ProjectileTouching);
	
	int index = FindGrenade(entity);
	if(index == -1)
		return;
	
	new data[MissileInfo_t];
	g_hArrayMissileList.GetArray(index, data, MissileInfo_t);
	g_hArrayMissileList.Erase(index);
	
	// 强制引爆手榴弹
	// 榴弹发射器的榴弹会自己引爆的
	switch(data[MissileType])
	{
		case 1:
		{
			if(g_pCvarDetonateMolotov.BoolValue && g_pfnMolotovDetonate != null)
				SDKCall(g_pfnMolotovDetonate, entity);
		}
		case 2:
		{
			if(g_pCvarDetonatePipeBomb.BoolValue && g_pfnPipeBombDetonate != null)
				SDKCall(g_pfnPipeBombDetonate, entity);
		}
		case 3:
		{
			if(g_pCvarDetonateBile.BoolValue && g_pfnVomitjarDetonate != null)
				SDKCall(g_pfnVomitjarDetonate, entity);
		}
		case 4:
		{
			// 不知道会不会炸...
			if(g_pCvarDetonateGrenade.BoolValue && g_pfnGrenadeTouch != null && toucher > 0)
				SDKCall(g_pfnGrenadeTouch, entity, toucher);
		}
	}
}

public Action SDKHooked_ProjectileThinking(int entity)
{
	UpdateEnemyList();
	
	int index = FindGrenade(entity);
	if(index == -1)
	{
		SDKUnhook(entity, SDKHook_Think, SDKHooked_ProjectileThinking);
		SDKUnhook(entity, SDKHook_StartTouchPost, SDKHooked_ProjectileTouching);
		return Plugin_Continue;
	}
	
	TrackMissile(index);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsPluginAllow() || !g_bRoundStarted)
		return Plugin_Continue;
	
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;
	
	new data[MissileInfo_t];
	int maxLength = g_hArrayMissileList.Length;
	UpdateEnemyList();
	
	for(int i = 0; i < maxLength; ++i)
	{
		g_hArrayMissileList.GetArray(i, data, MissileInfo_t);
		if(data[MissileOwner] != client)
			continue;
		
		TrackMissile(i);
	}
	
	return Plugin_Continue;
}

void TrackMissile(int index)
{
	new data[MissileInfo_t];
	g_hArrayMissileList.GetArray(index, data, MissileInfo_t);
	
	float time = GetGameTime();
	float duration = time - data[MissileTime];
	if(duration > 1.0)
		duration = 1.0;
	else if(duration < 0.01)
		duration = 0.01;
	
	float pos[3], ang[3], vel[3];
	int entity = data[MissileEntity];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
	
	float moveToPos[3], moveToDir[3];
	int owner = data[MissileOwner];
	int enemy = GetBestTarget(index, pos, ang);
	if(enemy > -1)
	{
		// 跟随敌人
		GetEnemyPostion(enemy, moveToPos);
	}
	else if(g_bMissileFollowCrosshair)
	{
		// 跟随准星
		GetClientEyePosition(owner, moveToPos);
		GetClientEyeAngles(owner, moveToDir);
		GetRayEndPosition(moveToPos, moveToDir, moveToPos, data[MissileOwner]);
	}
	else
	{
		// 什么也不做，让它自然移动
		data[MissileTime] = time;
		data[MissileEnemy] = -1;
		g_hArrayMissileList.SetArray(index, data, MissileInfo_t);
		return;
	}
	
	GetEntDataVector(entity, g_iOffsetVelocity, vel);
	NormalizeVector(vel, vel);
	
	SubtractVectors(moveToPos, pos, moveToDir);
	NormalizeVector(moveToDir, moveToDir);
	ScaleVector(moveToDir, duration * 8.0);
	AddVectors(vel, moveToDir, moveToDir);
	
	// 给一个初始向上的速度，防止瞄准地面时无法跟踪
	if(data[MissileStartTime] > time)
	{
		static float up[3];
		if(up[2] == 0.0)
			up[2] = 1.0;
		
		ScaleVector(up, duration * 10.0);
		AddVectors(moveToDir, up, moveToDir);
	}
	
	NormalizeVector(moveToDir, vel);
	
	if(data[MissileType] == 4)
	{
		// 修复榴弹发射器不受控制的问题
		GetVectorAngles(vel, ang);
	}
	
	ScaleVector(vel, g_fMissileFlySpeed);
	TeleportEntity(entity, NULL_VECTOR, ang, vel);
	
#if defined PLUGIN_DEBUG
	if(enemy > 0 && data[MissileEnemy] != enemy)
	{
		char classname[64];
		if(enemy <= MaxClients)
			GetClientName(enemy, classname, 64);
		else
			GetEntityClassname(enemy, classname, 64);
		
		// PrintToChat(owner, "\x03[提示]\x01 导弹瞄准了敌人 \x04%s\x01。", classname);
		PrintCenterText(owner, "导弹瞄准了 %s", classname);
	}
#endif
	
	data[MissileTime] = time;
	data[MissileEnemy] = enemy;
	g_hArrayMissileList.SetArray(index, data, MissileInfo_t);
}

void GetRayEndPosition(float origin[3], float angles[3], float output[3], int ignore = -1)
{
	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite,
		TraceRayFilter_NoHitSelf, ignore);
	
	if(TR_DidHit(trace))
		TR_GetEndPosition(output, trace);
	
	delete trace;
}

int GetBestTarget(int index, float gunPos[3], float gunAng[3])
{
	new data[MissileInfo_t];
	g_hArrayMissileList.GetArray(index, data, MissileInfo_t);
	
	int entity = -1;
	Handle trace = null;
	float endPos[3], dist;
	
	/*
	trace = TR_TraceRayFilterEx(gunPos, gunAng, MASK_SHOT, RayType_Infinite,
		TraceRayFilter_NoHitSelf, data[MissileEntity]);
	
	if(TR_DidHit(trace))
		entity = TR_GetEntityIndex(trace);
	delete trace;
	
	if(IsValidEnemy(entity))
	{
		GetEnemyPostion(entity, endPos);
		dist = GetVectorDistance(gunPos, endPos, false);
		if(dist <= g_fMissileScanRadius)
			return entity;
	}
	*/
	
	int bestTarget = -1, hitTarget = -1;
	float nearDist = g_fMissileScanRadius;
	int maxLength = g_hArrayEnemyList.Length;
	for(int i = 0; i < maxLength; ++i)
	{
		entity = g_hArrayEnemyList.Get(i);
		if(!IsValidEnemy(entity))
		{
			g_hArrayEnemyList.Erase(i);
			--i;
			--maxLength;
			continue;
		}
		
		// 优先攻击特感
		// g_hArrayEnemyList 是有序的
		if(entity > MaxClients && bestTarget > 0)
			return bestTarget;
		
		GetEnemyPostion(entity, endPos);
		dist = GetVectorDistance(gunPos, endPos, false);
		if(dist > nearDist)
			continue;
		
		trace = TR_TraceRayFilterEx(gunPos, endPos, MASK_SHOT, RayType_EndPoint,
			TraceRayFilter_NoHitSelf, data[MissileEntity]);
		
		if(TR_DidHit(trace))
			hitTarget = TR_GetEntityIndex(trace);
		else
			hitTarget = -1;
		delete trace;
		
		/*
		if(hitTarget == entity || IsValidEnemy(hitTarget))
			return hitTarget;
		*/
		
		if(hitTarget != entity)
			continue;
		
		// 选择最接近的敌人
		nearDist = dist;
		bestTarget = entity;
	}
	
	return bestTarget;
}

void GetEnemyPostion(int entity, float position[3])
{
	if(entity <= MaxClients)
		GetClientAbsOrigin(entity, position);
	else
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	
	position[2] += 35.0;
}

bool TraceRayFilter_NoHitSelf(int entity, int mask, any other)
{
	return (entity != other);
}

void UpdateEnemyList()
{
	static float nextScanTime;
	float time = GetEngineTime();
	if(nextScanTime > time)
		return;
	
	nextScanTime = time + 1.0;
	int maxEntity = GetMaxEntities();
	g_hArrayEnemyList.Clear();
	
	for(int i = 1; i <= maxEntity; ++i)
	{
		if(IsValidEnemy(i))
			g_hArrayEnemyList.Push(i);
	}
}

stock bool IsValidEnemy(int entity)
{
	if(g_bMissileScanSpecial)
	{
		if(IsValidAliveClient(entity) && GetClientTeam(entity) == 3 && !GetEntProp(entity, Prop_Send, "m_isGhost", 1))
		{
			// 检查 Tank 是否为沮丧状态
			if(GetEntProp(entity, Prop_Send, "m_zombieClass") != 8 ||
				!GetEntProp(entity, Prop_Send, "m_isIncapacitated", 1))
				return true;
		}
	}
	
	if(g_bMissileScanCommon)
	{
		if(entity > MaxClients && IsValidEdict(entity) && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
		{
			decl String:classname[64];
			GetEntityClassname(entity, classname, 64);
			
			// 检查 Witch 愤怒和 普感 燃烧状态
			if((StrEqual(classname, "infected", false) && !GetEntProp(entity, Prop_Send, "m_bIsBurning", 1)) ||
				(StrEqual(classname, "witch", false) && GetEntPropFloat(entity, Prop_Send, "m_rage") >= 1.0))
				return true;
		}
	}
	
	return false;
}
