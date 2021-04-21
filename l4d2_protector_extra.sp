#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
// #include <l4d2_simple_combat>

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6



#define MODEL_GUN_M60 "models/w_models/weapons/w_m60.mdl"
#define MODEL_GUN_FOOT "models/props_equipment/oxygentank01.mdl"


#define PARTICLE_MUZZLE_FLASH		"weapon_muzzle_flash_autoshotgun"
#define PARTICLE_WEAPON_TRACER		"weapon_tracers"
#define PARTICLE_WEAPON_TRACER2		"weapon_tracers_50cal"//weapon_tracers_50cal" //"weapon_tracers_explosive" weapon_tracers_50cal

#define PARTICLE_BLOOD		"blood_impact_red_01"
#define PARTICLE_BLOOD2		"blood_impact_headshot_01"

#define SOUND_IMPACT1		"physics/flesh/flesh_impact_bullet1.wav"
#define SOUND_IMPACT2		"physics/concrete/concrete_impact_bullet1.wav"
// #define SOUND_FIRE		"weapons/50cal/50cal_shoot.wav"
#define SOUND_FIRE		"weapons/machinegun_m60/gunfire/machinegun_fire_1.wav"

#define state_none 0
#define state_carry 1
#define state_work 2
#define state_sleep 3

new ZOMBIECLASS_TANK=	5;
new GameMode;
new L4D2Version;

enum struct GunInfo_t
{
	int GunModelHead;
	int GunModelFoot;
	int GunModelOnBack;
	int GunEnemy;
	int GunOwner;
	int ProtectorState;
	int BulletRemain;
	float NextShotTime;
	// float LastTime;
	float ProtectorPosition[3];
	float ProtectorAngle[3];
}

ArrayList g_hArrayGunList;

new bool:HaveProtector[MAXPLAYERS+1];
int g_iProtectorUsed[MAXPLAYERS+1];

new LastButton[MAXPLAYERS+1];
new Float:LastTime[MAXPLAYERS+1];

new Float:ScanTime=0.0;
ArrayList g_hArrayEnemyList;

new Handle:l4d_protector_bullet_count;
new Handle:l4d_protector_bullet_damage;
new Handle:l4d_protector_attack_distance;
new Handle:l4d_protector_attack_intervual;
new Handle:l4d_protector_attack_special_infected;
new Handle:l4d_protector_attack_common_infected;
new Handle:l4d_protector_bullet_damage_max;

public Plugin:myinfo =
{
	name = "机枪小炮台扩展版",
	author = " pan xiao hai",
	description = " ",
	version = "1.2",
	url = "http://forums.alliedmods.net"
}

bool g_bAllowCreator[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 and Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	// g_bLeft4Dead2 = (test == Engine_Left4Dead2);

	CreateNative("Protector_SetAllowedClient", NATIVE_Protector_SetAllowedClient);
	RegPluginLibrary("protector_helpers");
	return APLRes_Success;
}

public int NATIVE_Protector_SetAllowedClient(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int client = GetNativeCell(1);
	bool allow = GetNativeCell(2);
	bool old = g_bAllowCreator[client];
	g_bAllowCreator[client] = allow;
	return view_as<int>(old);
}

public OnPluginStart()
{
	GameCheck();
	// CreateTimer(1.0, Timer_SetupSpell);

	if(!L4D2Version)return;

	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	HookEvent("player_bot_replace", player_bot_replace );
	HookEvent("bot_player_replace", bot_player_replace );

	HookEvent("round_start", round_end);
	HookEvent("round_end", round_end);
	HookEvent("finale_win", round_end);
	HookEvent("mission_lost", round_end);
	HookEvent("map_transition", round_end);

	l4d_protector_bullet_count = CreateConVar("l4d_protector2_bullet_count", "1000", "炮台子弹数量", FCVAR_PLUGIN);
	l4d_protector_bullet_damage = CreateConVar("l4d_protector2_bullet_damage", "25", "炮台子弹伤害", FCVAR_PLUGIN);
	l4d_protector_attack_distance = CreateConVar("l4d_protector2_attack_distance", "1500.0", "炮台攻击范围", FCVAR_PLUGIN);
	l4d_protector_attack_intervual = CreateConVar("l4d_protector2_attack_intervual", "0.1", "炮台射击间隔", FCVAR_PLUGIN);
	l4d_protector_bullet_damage_max = CreateConVar("l4d_protector2_bullet_damage_max", "200", "炮台伤害上限", FCVAR_PLUGIN);

	l4d_protector_attack_special_infected = CreateConVar("l4d_protector2_attack_special_infected", "1", "炮台是否攻击特感", FCVAR_PLUGIN);
	l4d_protector_attack_common_infected = CreateConVar("l4d_protector2_attack_common_infected", "1", "炮台是否攻击普感", FCVAR_PLUGIN);

	AutoExecConfig(true, "l4d_protector2");
	RegConsoleCmd("sm_gun", sm_protector2, "创建哨塔");
	RegAdminCmd("sm_protector", sm_protector, ADMFLAG_CHEATS);
	RegAdminCmd("sm_removegun", sm_removeprotector, ADMFLAG_CHEATS);
	
	g_hArrayEnemyList = CreateArray();
	g_hArrayGunList = CreateArray(sizeof(GunInfo_t));
	
	HookConVar_OnUpdate(INVALID_HANDLE, "", "");
	HookConVarChange(l4d_protector_attack_intervual, HookConVar_OnUpdate);
	HookConVarChange(l4d_protector_attack_special_infected, HookConVar_OnUpdate);
	HookConVarChange(l4d_protector_attack_common_infected, HookConVar_OnUpdate);
}

new Float:g_fDamage[MAXPLAYERS+1], Float:g_fRadius[MAXPLAYERS+1];

/*
public Action:Timer_SetupSpell(Handle:timer, any:unused)
{
	SC_CreateSpell("pxh_protector2", "固定小机枪炮台", 150, 6000);
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	if(!StrEqual(classname, "pxh_protector2", false))
		return;
	
	float minDamage = GetConVarFloat(l4d_protector_bullet_damage);
	g_fRadius[client] = SC_GetClientMaxMagic(client) + GetConVarFloat(l4d_protector_attack_distance);
	g_fDamage[client] = minDamage + SC_GetClientLevel(client);

	float maxDamage = GetConVarFloat(l4d_protector_bullet_damage_max);
	if(g_fDamage[client] > maxDamage)
		g_fDamage[client] = maxDamage;
	if(g_fDamage[client] < GetConVarFloat(l4d_protector_bullet_damage))
		g_fDamage[client] = GetConVarFloat(l4d_protector_bullet_damage);

	CreateProtector(client, SC_GetClientMaxStamina(client) + GetConVarInt(l4d_protector_bullet_count));
}
*/

new Float:g_fAttackInterval, bool:g_bAttackSpecial, bool:g_bAttackCommon;

public HookConVar_OnUpdate(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	g_fAttackInterval = GetConVarFloat(l4d_protector_attack_intervual);
	g_bAttackSpecial = GetConVarBool(l4d_protector_attack_special_infected);
	g_bAttackCommon = GetConVarBool(l4d_protector_attack_common_infected);
}

public OnMapStart()
{
	ResetAllState();

	if(L4D2Version)
	{
		PrecacheSound(SOUND_IMPACT1);
		PrecacheSound(SOUND_IMPACT2);
		PrecacheSound(SOUND_FIRE);

		PrecacheParticle(PARTICLE_BLOOD);
		PrecacheParticle(PARTICLE_BLOOD2);

		PrecacheParticle(PARTICLE_MUZZLE_FLASH);
		PrecacheParticle(PARTICLE_WEAPON_TRACER);
		PrecacheParticle(PARTICLE_WEAPON_TRACER2);

		PrecacheModel(MODEL_GUN_M60, true);
		PrecacheModel(MODEL_GUN_FOOT, true);
	}

}

public Action:round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllState();
}

public Action:round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllState();
}
ResetAllState()
{
	ScanTime = 0.0;
	for(new i=1; i<=MaxClients; i++)
	{
		RemoveProtector(i);
		g_iProtectorUsed[i] = 0;
	}
}

public Action sm_protector2(int client, int argc)
{
	if(client>0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(g_bAllowCreator[client] && g_iProtectorUsed[client] <= 0)
		{
			CreateProtector(client);
			PrintToChat(client, "\x03[炮台]\x04 你\x01 建造了一个小炮台。");
		}
		else
		{
			PrintToChat(client, "\x03[炮台]\x04 你\x01 没有「哨塔」天赋或已经使用过了。");
		}
	}
}

public Action:sm_protector(client,args)
{
	if(client>0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(!HaveProtector[client])
		{
			g_fDamage[client] = GetConVarFloat(l4d_protector_bullet_damage);
			g_fRadius[client] = GetConVarFloat(l4d_protector_attack_distance);
		}
		
		CreateProtector(client);
		PrintToChat(client, "\x03[炮台]\x04 你\x01 建造了一个小炮台。");
	}
	
	return Plugin_Continue;
}

public Action sm_removeprotector(int client, int argc)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(!HaveProtector[client])
			return Plugin_Continue;
		
		int index = -1;
		int aiming = GetClientAimTarget(client, false);
		
		// 拆除瞄准的炮台
		if(aiming > MaxClients)
			index = FindGunEx(aiming);
		
		// 拆除最先建造的炮台
		if(index == -1)
			index = FindClientGunEx(client);
		
		if(index > -1)
		{
			RemoveProtector(client, index);
			PrintToChat(client, "\x03[炮台]\x04 你\x01 拆除了一个小炮台。");
		}
	}
	
	return Plugin_Continue;
}

public player_bot_replace(Handle:Spawn_Event, const String:Spawn_Name[], bool:Spawn_Broadcast)
{
	new client = GetClientOfUserId(GetEventInt(Spawn_Event, "player"));
	// new bot = GetClientOfUserId(GetEventInt(Spawn_Event, "bot"));
	if(HaveProtector[client])
	{
		RemoveProtector(client);
	}
	RemoveProtector(client);
	// RemoveProtector(bot);
}
public bot_player_replace(Handle:Spawn_Event, const String:Spawn_Name[], bool:Spawn_Broadcast)
{
	new client = GetClientOfUserId(GetEventInt(Spawn_Event, "player"));
	// new bot = GetClientOfUserId(GetEventInt(Spawn_Event, "bot"));
	if(HaveProtector[client])
	{
		RemoveProtector(client);
	}
	RemoveProtector(client);
	// RemoveProtector(bot);

}
public Action:player_spawn(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client > 0)
		RemoveProtector(client);
}

public Action:player_death(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	new dead_player = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(dead_player > 0)
	{
		if(HaveProtector[dead_player])
		{
			RemoveProtector(dead_player);
		}
	}
	else
	{
		dead_player= GetEventInt(hEvent, "entityid") ;
	}

	if(dead_player>0)
	{
		int index = g_hArrayEnemyList.FindValue(dead_player);
		if(index > -1)
			g_hArrayEnemyList.Erase(index);
		
		GunInfo_t GunData;
		int maxLength = g_hArrayGunList.Length;
		for(new i = 0; i < maxLength; ++i)
		{
			g_hArrayGunList.GetArray(i, GunData, sizeof(GunInfo_t));
			if(GunData.GunEnemy != dead_player)
				continue;
			
			GunData.GunEnemy = 0;
			g_hArrayGunList.SetArray(i, GunData, sizeof(GunInfo_t));
		}
	}
}

RemoveProtector(client, index = -1)
{
	if(!HaveProtector[client])return;
	GunInfo_t GunData;
	
	if(index == -1)
	{
		while((index = FindClientGun(client, GunData, -1)) > -1)
		{
			SDKUnhook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
			SDKUnhook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
			RemoveEnt((GunData.GunModelFoot));
			RemoveEnt((GunData.GunModelHead));
			RemoveEnt((GunData.GunModelOnBack));
			
			g_hArrayGunList.Erase(index);
		}
		
		HaveProtector[client] = false;
	}
	else
	{
		g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
		
		SDKUnhook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
		SDKUnhook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
		RemoveEnt((GunData.GunModelFoot));
		RemoveEnt((GunData.GunModelHead));
		RemoveEnt((GunData.GunModelOnBack));
		
		g_hArrayGunList.Erase(index);
		HaveProtector[client] = (FindClientGun(client, GunData, -1) != -1);
	}
	
	// if(client>0 && IsClientInGame(client))PrintToChatAll("Remove %N 's protector", client);
}

FindClientGun(client, GunInfo_t GunData, start = -1)
{
	int maxLength = g_hArrayGunList.Length;
	for(int i = start + 1; i < maxLength; ++i)
	{
		g_hArrayGunList.GetArray(i, GunData, sizeof(GunInfo_t));
		if(GunData.GunOwner == client)
			return i;
	}
	
	return -1;
}

stock FindClientGunEx(client, start = -1)
{
	GunInfo_t GunData;
	return FindClientGun(client, GunData, start);
}

FindGun(ent, GunInfo_t GunData, start = -1)
{
	int maxLength = g_hArrayGunList.Length;
	ent = EntIndexToEntRef(ent);
	for(int i = start + 1; i < maxLength; ++i)
	{
		g_hArrayGunList.GetArray(i, GunData, sizeof(GunInfo_t));
		if(GunData.GunModelFoot == ent || GunData.GunModelHead == ent || GunData.GunModelOnBack == ent)
			return i;
	}
	
	return -1;
}

stock FindGunEx(client, start = -1)
{
	GunInfo_t GunData;
	return FindGun(client, GunData, start);
}

CreateProtector(client, bullet = 0)
{
	GunInfo_t GunData;
	GunData.GunModelFoot = INVALID_ENT_REFERENCE;
	GunData.GunModelHead = INVALID_ENT_REFERENCE;
	GunData.GunModelOnBack = INVALID_ENT_REFERENCE;
	GunData.GunEnemy = INVALID_ENT_REFERENCE;
	GunData.GunOwner = client;
	GunData.ProtectorState = state_none;
	CopyVector(Float:{0.0, 0.0, 0.0}, GunData.ProtectorPosition);
	CopyVector(Float:{0.0, 0.0, 0.0}, GunData.ProtectorAngle);
	
	g_fRadius[client] = GetConVarFloat(l4d_protector_attack_distance);
	g_fDamage[client] = GetConVarFloat(l4d_protector_bullet_damage);
	
	if(bullet > 0)
		GunData.BulletRemain = bullet;
	else
		GunData.BulletRemain = GetConVarInt(l4d_protector_bullet_count);
	
	GunData.NextShotTime = GetEngineTime();
	// GunData.LastTime = GetEngineTime();
	
	HaveProtector[client]=true;
	LastButton[client]=0;
	
	GoWork(client, g_hArrayGunList.PushArray(GunData, sizeof(GunInfo_t)));
	g_iProtectorUsed[client] += 1;
}
GoBack(client, index = -1)
{
	GunInfo_t GunData;
	
	if(index == -1)
	{
		while((index = FindClientGun(client, GunData, index)) > -1)
		{
			GunData.ProtectorState = state_carry;
			SDKUnhook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
			SDKUnhook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
			RemoveEnt((GunData.GunModelFoot));
			RemoveEnt((GunData.GunModelHead));
			GunData.GunModelFoot = INVALID_ENT_REFERENCE;
			GunData.GunModelHead = INVALID_ENT_REFERENCE;
			GunData.GunModelOnBack = EntIndexToEntRef(CreateOnBack(client));
			
			g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
		}
	}
	else
	{
		g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
		
		GunData.ProtectorState = state_carry;
		SDKUnhook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
		SDKUnhook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
		RemoveEnt((GunData.GunModelFoot));
		RemoveEnt((GunData.GunModelHead));
		GunData.GunModelFoot = INVALID_ENT_REFERENCE;
		GunData.GunModelHead = INVALID_ENT_REFERENCE;
		GunData.GunModelOnBack = EntIndexToEntRef(CreateOnBack(client));
		
		g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
	}
}
GoWork(client, index = -1)
{
	GunInfo_t GunData;
	
	new Float:gun_pos[3];
	GetClientAbsOrigin(client, gun_pos);
	
	new Float:gun_angle[3];
	GetClientEyeAngles(client, gun_angle);

	new Float:vec[3];
	CopyVector(gun_angle,vec);
	vec[0]=0.0;
	GetAngleVectors(vec, vec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vec,vec);
	ScaleVector(vec,20.0);
	AddVectors(gun_pos,vec,gun_pos);
	
	if(index == -1)
	{
		while((index = FindClientGun(client, GunData, index)) > -1)
		{
			GunData.ProtectorState = state_work;
			RemoveEnt((GunData.GunModelOnBack));
			GunData.GunModelOnBack = INVALID_ENT_REFERENCE;
			
			GunData.GunModelFoot = EntIndexToEntRef(CreateFoot(gun_pos, client));
			GunData.GunModelHead = EntIndexToEntRef(CreateHead(GunData.GunModelFoot, client));
			
			CopyVector(gun_pos, GunData.ProtectorPosition);
			GunData.ProtectorPosition[2] += 28.0;
			
			SDKHook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
			SDKHook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
			
			g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
			TrunGun(index, gun_angle);
		}
	}
	else
	{
		g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
		
		GunData.ProtectorState = state_work;
		RemoveEnt((GunData.GunModelOnBack));
		GunData.GunModelOnBack = INVALID_ENT_REFERENCE;
		
		GunData.GunModelFoot = EntIndexToEntRef(CreateFoot(gun_pos, client));
		GunData.GunModelHead = EntIndexToEntRef(CreateHead(GunData.GunModelFoot, client));
		
		CopyVector(gun_pos, GunData.ProtectorPosition);
		GunData.ProtectorPosition[2] += 28.0;
		
		SDKHook(GunData.GunModelFoot, SDKHook_Use, SDKHooked_OnUse);
		SDKHook(GunData.GunModelHead, SDKHook_Use, SDKHooked_OnUse);
		
		g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
		TrunGun(index, gun_angle);
	}
}
TrunGun(index, Float:target_angle[3])
{
	if(index == -1)
		return;
	
	GunInfo_t GunData;
	g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
	
	// new Float:pos[3];
	new Float:ang[3];
	
	CopyVector(target_angle,ang);
	ang[0]=0.0;
	//ang[1]=0.0;
	ang[2]=0.0;
	TeleportEntity(GunData.GunModelFoot, NULL_VECTOR,ang,NULL_VECTOR);

	CopyVector(target_angle,ang);

	//ang[0]=0.0;
	ang[1]=0.0;
	ang[2]=0.0;
	TeleportEntity(GunData.GunModelHead, NULL_VECTOR,ang,NULL_VECTOR);

	CopyVector(target_angle, GunData.ProtectorAngle);
	
	g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
}

public Action SDKHooked_OnUse(int entity, int activator, int caller, UseType type, float value)
{
	if(activator != GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
		return Plugin_Handled;
	
	GoBack(activator, FindGunEx(entity));
	PrintHintText(activator, "你捡起了你的炮台，按住 E 然后按一下 鼠标中键 放下");
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(!HaveProtector[client])return Plugin_Continue;
	
	new Float:engine_time= GetEngineTime();
	new Float:duration=engine_time-LastTime[client];
	if(duration>1.0)duration=1.0;
	else if(duration<=0.0)duration=0.01;

	new last_button=LastButton[client];

	new Float:client_eye_position[3];
	GetClientEyePosition(client, client_eye_position);

	new Float:client_eye_angle[3];
	GetClientEyeAngles(client, client_eye_angle);

	int index = -1;
	GunInfo_t GunData;
	bool proccessed = false;
	float protectorPosition[3];
	while((index = FindClientGun(client, GunData, index)) != -1)
	{
		if(GunData.ProtectorState == state_work )
			ScanAllEnemy(engine_time);
		
		if(!proccessed && (buttons & IN_USE) && (buttons & IN_DUCK) && !(last_button & IN_USE))
		{
			if(GunData.ProtectorState==state_carry &&
				(GetEntityFlags(client) & FL_ONGROUND))
			{
				proccessed = true;
				GoWork(client, index);
				PrintHintText(client, "炮台还有 %d 发弹药", GunData.BulletRemain);
			}
			else if(GunData.ProtectorState==state_work)
			{
				CopyVector(GunData.ProtectorPosition, protectorPosition);
				if(GetVectorDistance(client_eye_position, protectorPosition) < 70.0)
				{
					proccessed = true;
					GoBack(client, index);
					PrintHintText(client, "炮台还有 %d 发弹药", GunData.BulletRemain);
				}
			}
		}
		
		if(GunData.ProtectorState==state_work)
			TrackGun(index,engine_time,duration);
		
		if(GunData.BulletRemain<=0)
			RemoveProtector(client, index);
	}
	
	LastButton[client]=buttons;
	LastTime[client]=engine_time;

	return Plugin_Continue;
}
TrackGun(index, Float:engine_time, Float:duration)
{
	GunInfo_t GunData;
	g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
	
	decl Float:gun_angle[3], Float:gun_pos[3];
	CopyVector(GunData.ProtectorAngle, gun_angle);
	
	float protectorPosition[3];
	CopyVector(GunData.ProtectorPosition, protectorPosition);
	
	GetAngleVectors(gun_angle, gun_pos, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(gun_pos, 20.0);
	
	AddVectors(protectorPosition, gun_pos, gun_pos);
	
	GunData.GunEnemy = GetBestTarget(index, gun_pos, gun_angle);
	if(IsValidEnemy(GunData.GunEnemy))
	{
		decl Float:target_angle[3], Float:enemy_pos[3];
		GetEnemyPostion(GunData.GunEnemy, enemy_pos);
		SubtractVectors(enemy_pos, gun_pos, target_angle);
		GetVectorAngles(target_angle, target_angle);

		new Float:diff0 = AngleDiff(target_angle[0], gun_angle[0]);
		new Float:diff1 = AngleDiff(target_angle[1], gun_angle[1]);

		new Float:turn0 = 45.0 * Sign(diff0) * duration;
		new Float:turn1 = 90.0 * Sign(diff1) * duration;
		if(FloatAbs(turn0) >= FloatAbs(diff0))
			turn0 = diff0;
		if(FloatAbs(turn1) >= FloatAbs(diff1))
			turn1 = diff1;

		target_angle[0] = gun_angle[0] + turn0;
		target_angle[1] = gun_angle[1] + turn1;
		target_angle[2] = 0.0;

		if(FloatAbs(diff1) < 50.0 && FloatAbs(diff0) < 50.0 && GunData.NextShotTime <= engine_time)
		{
			GunData.NextShotTime = engine_time + g_fAttackInterval;
			Shot(index, gun_pos, gun_angle);
			GunData.BulletRemain -= 1;
		}
		
		g_hArrayGunList.SetArray(index, GunData, sizeof(GunInfo_t));
		TrunGun(index, target_angle);
	}
}

int GetBestTarget(int index, float gunPos[3], float gunAng[3])
{
	GunInfo_t GunData;
	g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
	
	DataPack data = CreateDataPack();
	data.WriteCell(EntRefToEntIndex(GunData.GunOwner));
	data.WriteCell(EntRefToEntIndex(GunData.GunModelFoot));
	data.WriteCell(EntRefToEntIndex(GunData.GunModelHead));
	// data.WriteCell(GunData.GunModelOnBack);
	
	Handle trace = TR_TraceRayFilterEx(gunPos, gunAng, MASK_SHOT, RayType_Infinite,
		TraceRayFilter_NoGunAndSelf, data);
	
	int entity = -1;
	if(TR_DidHit(trace))
		entity = TR_GetEntityIndex(trace);
	delete trace;
	
	if(IsValidEnemy(entity) && IsEntityInRange(entity, gunPos, GunData.GunOwner))
		return entity;
	
	float endPos[3];
	int hitTarget = -1;
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
		
		GetEnemyPostion(entity, endPos);
		if(!IsInRange(endPos, gunPos, GunData.GunOwner))
			continue;
		
		trace = TR_TraceRayFilterEx(gunPos, endPos, MASK_SHOT, RayType_EndPoint,
			TraceRayFilter_NoGunAndSelf, data);
		
		if(TR_DidHit(trace))
			hitTarget = TR_GetEntityIndex(trace);
		else
			hitTarget = -1;
		delete trace;
		
		if(hitTarget == entity || IsValidEnemy(hitTarget))
			return hitTarget;
	}
	
	delete data;
	return -1;
}

bool TraceRayFilter_NoGunAndSelf(int entity, int mask, any unknown)
{
	DataPack data = view_as<DataPack>(unknown);
	data.Reset();
	
	return (entity != data.ReadCell() && entity != data.ReadCell() && entity != data.ReadCell());
}

bool IsEntityInRange(int entity, float position[3], int client)
{
	float origin[3];
	GetEnemyPostion(entity, origin);
	return (GetVectorDistance(position, origin) <= g_fRadius[client]);
}

bool IsInRange(float origin[3], float position[3], int client)
{
	return (GetVectorDistance(position, origin) <= g_fRadius[client]);
}

Shot(index, Float:gunpos[3],  Float:shotangle[3])
{
	GunInfo_t GunData;
	g_hArrayGunList.GetArray(index, GunData, sizeof(GunInfo_t));
	
	decl Float:temp[3];
	decl Float:ang[3];
	GetAngleVectors(shotangle, temp, NULL_VECTOR,NULL_VECTOR);
	NormalizeVector(temp, temp);

	new Float:acc=0.020;
	temp[0] += GetRandomFloat(-1.0, 1.0)*acc;
	temp[1] += GetRandomFloat(-1.0, 1.0)*acc;
	temp[2] += GetRandomFloat(-1.0, 1.0)*acc;
	GetVectorAngles(temp, ang);

	DataPack data = CreateDataPack();
	data.WriteCell(EntRefToEntIndex(GunData.GunOwner));
	data.WriteCell(EntRefToEntIndex(GunData.GunModelFoot));
	data.WriteCell(EntRefToEntIndex(GunData.GunModelHead));
	// data.WriteCell(GunData.GunModelOnBack);
	
	new Handle:trace= TR_TraceRayFilterEx(gunpos, ang, MASK_SHOT, RayType_Infinite,
		TraceRayFilter_NoGunAndSelf, data);
	
	new enemy=0;
	if(TR_DidHit(trace))
	{
		decl Float:hitpos[3];
		TR_GetEndPosition(hitpos, trace);
		enemy = TR_GetEntityIndex(trace);
		
		// new bool:blood=false;
		if(IsValidEnemy(enemy))
		{
			SDKHooks_TakeDamage(enemy, GunData.GunModelFoot, GunData.GunOwner, g_fDamage[GunData.GunOwner],
				DMG_BULLET, GunData.GunModelHead, _, hitpos);
			
			/*
			decl Float:Direction[3];
			GetAngleVectors(ang, Direction, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(Direction, -1.0);
			GetVectorAngles(Direction,Direction);
			ShowParticle(hitpos, Direction, PARTICLE_BLOOD, g_fAttackInterval);
			*/
			
			EmitSoundToAll(SOUND_IMPACT1, 0,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,hitpos, NULL_VECTOR,true, 0.0);
		}
		else
		{
			/*
			decl Float:Direction[3];
			Direction[0] = GetRandomFloat(-1.0, 1.0);
			Direction[1] = GetRandomFloat(-1.0, 1.0);
			Direction[2] = GetRandomFloat(-1.0, 1.0);
			TE_SetupSparks(hitpos, Direction, 1, 3);
			TE_SendToAll();
			*/
			
			EmitSoundToAll(SOUND_IMPACT2, 0,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,hitpos, NULL_VECTOR,true, 0.0);
		}
		
		ShowMuzzleFlash(gunpos, ang);
		ShowTrack(gunpos, hitpos);
		EmitSoundToAll(SOUND_FIRE, 0,  SNDCHAN_WEAPON, SNDLEVEL_GUNFIRE, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,gunpos, NULL_VECTOR,true, 0.0);
	}

	CloseHandle(trace);
	delete data;
}

ShowMuzzleFlash(Float:pos[3],  Float:angle[3])
{
	new Float:vec[3];
	GetAngleVectors(angle, vec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vec,vec);
	ScaleVector(vec, 30.0);
	AddVectors(vec, pos, vec);

	new particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "effect_name", PARTICLE_MUZZLE_FLASH);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	TeleportEntity(particle, vec, angle, NULL_VECTOR);
	AcceptEntityInput(particle, "start");
	CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
}
ShowTrack(  Float:pos[3], Float:endpos[3] )
{
	decl String:temp[32];
	new target =0;
	if(L4D2Version)target=CreateEntityByName("info_particle_target");
	else target=CreateEntityByName("info_target");
	Format(temp, 32, "cptarget%d", target);
	DispatchKeyValue(target, "targetname", temp);
	TeleportEntity(target, endpos, NULL_VECTOR, NULL_VECTOR);
	ActivateEntity(target);

	new particle = CreateEntityByName("info_particle_system");
	if(L4D2Version)	DispatchKeyValue(particle, "effect_name", PARTICLE_WEAPON_TRACER2);
	else DispatchKeyValue(particle, "effect_name", PARTICLE_WEAPON_TRACER);
	DispatchKeyValue(particle, "cpoint1", temp);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(particle, "start");
	CreateTimer(0.01, DeleteParticletargets, target, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
}

CreateHead(foot, owner=-1)
{
	new ent= CreateEntityByName("prop_dynamic_override");
	SetEntityModel(ent, MODEL_GUN_M60);
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
	// DispatchKeyValue(ent, "solid", "0");
	DispatchKeyValue(ent, "spawnflags", "256");
	SetEntProp(ent, Prop_Data, "m_usSolidFlags", 14);
	SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 11);
	
	DispatchSpawn(ent);
	DispatchKeyValue(ent, "classname", "protector_head");

	decl String:tName[128];
	Format(tName, sizeof(tName), "protector_%d",foot );
	DispatchKeyValue(foot , "targetname", tName);

	SetVariantString(tName);
	AcceptEntityInput(ent, "SetParent", ent, ent, 0);

	new Float:vec_pos[3];
	new Float:vec_ang[3];

	SetVector(vec_pos, 0.0, 0.0, 28.0);
	SetVector(vec_ang, 0.0, 0.0, 0.0);

	TeleportEntity(ent, vec_pos,vec_ang,NULL_VECTOR);
	DispatchKeyValueFloat(ent, "fademindist", 10000.0);
	DispatchKeyValueFloat(ent, "fademaxdist", 20000.0);
	DispatchKeyValueFloat(ent, "fadescale", 0.0);

	AcceptEntityInput(ent, "TurnOn");
	AcceptEntityInput(ent, "DisableShadow");
	AcceptEntityInput(ent, "DisableCollision");
	
	Glow(foot, true);
	Glow(ent, true);
	return ent;
}
CreateFoot(Float:pos[3], owner = -1)
{
	new jetpack=CreateEntityByName("prop_dynamic_override");
	SetEntityModel(jetpack, MODEL_GUN_FOOT);
	// DispatchKeyValue(jetpack, "solid", "0");
	DispatchKeyValue(jetpack, "spawnflags", "256");
	SetEntProp(jetpack, Prop_Data, "m_usSolidFlags", 14);
	SetEntProp(jetpack, Prop_Data, "m_nSolidType", 0);
	SetEntProp(jetpack, Prop_Data, "m_CollisionGroup", 1);
	
	DispatchSpawn(jetpack);
	SetEntProp(jetpack, Prop_Data, "m_takedamage", 0, 1);
	DispatchKeyValue(jetpack, "classname", "protector_foot");

	new Float:ang[3];
	SetVector(ang, 0.0, 0.0, 0.0);

	TeleportEntity(jetpack, pos,ang, NULL_VECTOR);
	SetEntPropEnt(jetpack, Prop_Send, "m_hOwnerEntity", owner);

	SetEntProp(jetpack, Prop_Send, "m_iGlowType", 3 ); //3
	SetEntProp(jetpack, Prop_Send, "m_nGlowRange", 0 ); //0
	SetEntProp(jetpack, Prop_Send, "m_glowColorOverride", 1); //1

	AcceptEntityInput(jetpack, "TurnOn");
	AcceptEntityInput(jetpack, "DisableShadow");
	AcceptEntityInput(jetpack, "DisableCollision");
	
	DispatchKeyValueFloat(jetpack, "fademindist", 10000.0);
	DispatchKeyValueFloat(jetpack, "fademaxdist", 20000.0);
	DispatchKeyValueFloat(jetpack, "fadescale", 0.0);
	return 	jetpack;
}

CreateOnBack(client)
{
	new ent= CreateEntityByName("prop_dynamic_override");
	SetEntityModel(ent, MODEL_GUN_M60);
	DispatchSpawn(ent);

	decl String:tName[128];
	Format(tName, sizeof(tName), "target%d",client );
	DispatchKeyValue(client , "targetname", tName);

	SetVariantString(tName);
	AcceptEntityInput(ent, "SetParent", ent, ent, 0);
	SetVariantString("medkit");
	AcceptEntityInput(ent, "SetParentAttachment");

	new Float:vec_pos[3];
	new Float:vec_ang[3];

	SetVector(vec_pos, 0.0, 0.0, 10.0);
	SetVector(vec_ang, 90.0, 90.0, 0.0);


	TeleportEntity(ent, vec_pos,vec_ang,NULL_VECTOR);
	Glow(ent, true);
	return ent;
}

GetEnemyPostion(entity, Float:position[3])
{
	if(entity<=MaxClients) GetClientAbsOrigin(entity, position);
	else GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=35.0;
}
ScanAllEnemy(Float:time)
{
	if(time-ScanTime>1.0)
	{
		ScanTime=time;
		g_hArrayEnemyList.Clear();
		new maxEntity = GetMaxEntities();
		for(new i = 1; i <= maxEntity; ++i)
		{
			if(IsValidEnemy(i))
				g_hArrayEnemyList.Push(i);
		}
	}
}

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

stock bool:IsValidEnemy(entity)
{
	if(g_bAttackSpecial)
	{
		if(IsValidAliveClient(entity) && GetClientTeam(entity) == 3 && !GetEntProp(entity, Prop_Send, "m_isGhost"))
		{
			if(GetEntProp(entity, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK ||
				!GetEntProp(entity, Prop_Send, "m_isIncapacitated", 1))
				return true;
		}
	}
	
	if(g_bAttackCommon)
	{
		if(entity > MaxClients && IsValidEdict(entity) && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
		{
			decl String:classname[64];
			GetEntityClassname(entity, classname, 64);
			if((StrEqual(classname, "infected", false) && !GetEntProp(entity, Prop_Send, "m_bIsBurning", 1)) ||
				(StrEqual(classname, "witch", false) && GetEntPropFloat(entity, Prop_Send, "m_rage") >= 1.0))
				return true;
		}
	}
	
	return false;
}

stock bool:IsPlayerGhost(Client)
{
	if(GetEntProp(Client, Prop_Send, "m_isGhost", 1) == 1)
		return true;
	return false;
}

stock IsEnemyVisible(client, infected, Float:client_position[3])
{

	new Float:angle[3];
	new Float:enemy_position[3];
	if(infected<=MaxClients) GetClientAbsOrigin(infected, enemy_position);
	else GetEntPropVector(infected, Prop_Send, "m_vecOrigin", enemy_position);
	enemy_position[2]+=35.0;
	if(GetVectorDistance(enemy_position, client_position)>g_max_attack_distance)return 0;

	SubtractVectors(enemy_position, client_position, angle);
	GetVectorAngles(angle, angle);
	new Handle:trace=TR_TraceRayFilterEx(client_position, angle, MASK_ALL, RayType_Infinite, TraceRayDontHitSelf, client);

	new newenemy=0;

	if(TR_DidHit(trace))
	{

		newenemy=TR_GetEntityIndex(trace);
	}
	CloseHandle(trace);
	if(newenemy==0)return 0;
	if(newenemy == infected)return infected;

	if(IsValidEnemy(newenemy))
	{
		return newenemy;
	}
	return 0;
}

stock GetClientFrontEnemy(client, Float:client_postion[3], Float:range)
{
	new enemy_id=GetClientAimTarget(client, false);

	if(IsValidEnemy(enemy_id))
	{
		// new Float:enemy_position[3];
		// GetEntPropVector(enemy_id, Prop_Send, "m_vecOrigin", enemy_position);
		return enemy_id;
	}
	return 0;
}
stock Float:GetRange(enemy_id, Float:human_position[3], Float:enemy_position[3])
{
	GetEntPropVector(enemy_id, Prop_Send, "m_vecOrigin", enemy_position);
	enemy_position[2]+=50.0;
	new Float:dis=GetVectorDistance(enemy_position, human_position);

	return dis;
}
stock PrintVector(String:s[], Float:target[3])
{
	PrintToChatAll("%s - %f %f %f", s, target[0], target[1], target[2]);
}
CopyVector(Float:source[], Float:target[])
{
	target[0]=source[0];
	target[1]=source[1];
	target[2]=source[2];
}
SetVector(Float:target[3], Float:x, Float:y, Float:z)
{
	target[0]=x;
	target[1]=y;
	target[2]=z;
}

GameCheck()
{
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	PrintToChatAll("mp_gamemode = %s", GameName);

	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false))
		GameMode = 1;
	else
	{
		GameMode = 0;
	}


	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2", false))
	{
		ZOMBIECLASS_TANK=8;
		L4D2Version=true;
	}
	else
	{
		ZOMBIECLASS_TANK=5;
		L4D2Version=false;
	}
	L4D2Version=!!L4D2Version;
}

stock GetLookPosition(client, Float:pos[3], Float:angle[3], Float:hitpos[3])
{

	new Handle:trace=TR_TraceRayFilterEx(pos, angle, MASK_ALL, RayType_Infinite, TraceRayDontHitSelf, client);

	if(TR_DidHit(trace))
	{

		TR_GetEndPosition(hitpos, trace);

	}
	CloseHandle(trace);

}

stock ScanEnemy(client, infected, Float:client_postion[3], Float:angle)
{

	new Float:angle_vec[3] ;
	new Float:postion[3];
	CopyVector(client_postion,postion);
	postion[2]-=20.0;

	angle_vec[0]=angle_vec[1]=angle_vec[2]=0.0;
	angle_vec[1]=angle;
	//GetEntPropVector(ent, Prop_Send, "m_vecOrigin", hitpos);
	//PrintToChatAll("%f %f", dir[0], dir[1]);
	new Handle:trace=TR_TraceRayFilterEx(postion, angle_vec, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelfAndHuman, infected);

	new newenemy=0;
	if(TR_DidHit(trace))
	{
		newenemy=TR_GetEntityIndex(trace);
	}
	CloseHandle(trace);
	if(!IsInfectedTeam(newenemy))newenemy=0;
	return newenemy;
}
stock bool:IsInfectedTeam(ent)
{
	if(ent>0)
	{
		if(ent<=MaxClients)
		{
			if(IsClientInGame(ent) && IsPlayerAlive(ent) && GetClientTeam(ent)==3)
			{
				return true;
			}
		}
		else if(IsValidEntity(ent) && IsValidEdict(ent))
		{

			decl String:classname[32];
			GetEdictClassname(ent, classname,32);

			if(StrEqual(classname, "infected", true) || StrEqual(classname, "witch", true) )
			{
				return true;
			}
		}
	}
	return false;
}
public bool:TraceRayDontHitSelfAndHuman(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	if(entity<=MaxClients && entity>0)
	{
		if(IsClientInGame(entity) && IsPlayerAlive(entity) && GetClientTeam(entity)==2)
		{
			return false;
		}
	}
	return true;
}
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}

	return true;
}

public bool:TraceRayDontHitAlive(entity, mask, any:data)
{
	if(entity==0)return false;
	if(entity == data)
	{
		return false;
	}
	if(entity<=MaxClients && entity>0)
	{
		return false;
	}
	else
	{
		decl String:classname[32];
		GetEdictClassname(entity, classname,32);
		if(StrEqual(classname, "infected", true) || StrEqual(classname, "witch", true) )
		{
			return false;
		}
	}
	return true;
}

public PrecacheParticle(String:particlename[])
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:DeleteParticles(Handle:timer, any:particle)
{
	 if (IsValidEntity(particle))
	 {
		 decl String:classname[64];
		 GetEdictClassname(particle, classname, sizeof(classname));
		 if (StrEqual(classname, "info_particle_system", false))
			{
				AcceptEntityInput(particle, "stop");
				AcceptEntityInput(particle, "kill");
				RemoveEdict(particle);

			}
	 }
}
public Action:DeleteParticletargets(Handle:timer, any:target)
{
	 if (IsValidEntity(target))
	 {
		 decl String:classname[64];
		 GetEdictClassname(target, classname, sizeof(classname));
		 if (StrEqual(classname, "info_particle_target", false))
			{
				AcceptEntityInput(target, "stop");
				AcceptEntityInput(target, "kill");
				RemoveEdict(target);

			}
	 }
}
public ShowParticle(Float:pos[3], Float:ang[3],String:particlename[], Float:time)
{
 new particle = CreateEntityByName("info_particle_system");
 if (IsValidEdict(particle))
 {

		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);


		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
		return particle;
 }
 return 0;
}

RemoveEnt(ent)
{

	if(ent!=0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		RemoveEdict(ent);
	}
}



Float:Sign(Float:v)
{
	if(v==0.0)return 0.0;
	else if(v>0.0)return 1.0;
	else return -1.0;
}
Float:AngleDiff(Float:a, Float:b)
{
	new Float:d=0.0;
	if(a>=b)
	{
		d=a-b;
		if(d>=180.0)d=d-360.0;
	}
	else
	{
		d=a-b;
		if(d<=-180.0)d=360+d;
	}
	return d;
}

Glow(ent, bool:glow)
{
	if(L4D2Version)
	{
		if (ent>0 && IsValidEdict(ent) && IsValidEntity(ent))
		{
			if(glow)
			{
				SetEntProp(ent, Prop_Send, "m_iGlowType", 3 ); //3
				SetEntProp(ent, Prop_Send, "m_nGlowRange", 0 ); //0
				SetEntProp(ent, Prop_Send, "m_glowColorOverride", 256*100); //1
			}
			else
			{
				SetEntProp(ent, Prop_Send, "m_iGlowType", 0 ); //3
				SetEntProp(ent, Prop_Send, "m_nGlowRange", 0 ); //0
				SetEntProp(ent, Prop_Send, "m_glowColorOverride", 0); //1
			}


		}

	}
}
