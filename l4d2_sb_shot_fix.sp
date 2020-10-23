#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION			"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "修复机器人瞄准不开枪",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

ConVar g_hCvarMeleeRange, g_hCvarShovRange;
#define IsSurvivorHeld(%1)		(GetEntPropEnt(%1, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(%1, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(%1, Prop_Send, "m_carryAttacker") > 0)

public void OnPluginStart()
{
	InitPlugin("ssf");
	AutoExecConfig(true, "l4d2_sb_shot_fix");
	
	g_hCvarShovRange = FindConVar("z_gun_range");
	g_hCvarMeleeRange = FindConVar("melee_range");
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsValidAliveClient(client) || GetClientTeam(client) != 2 || weapon <= MaxClients)
		return Plugin_Continue;
	
	static char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname)))
		return Plugin_Continue;
	
	float range = 0.0;
	int mode = 0;
	if(CanPrimaryAttack(weapon))
	{
		mode = IN_ATTACK;
		
		if(IsValidMeleeWeapon(classname))
			range = g_hCvarMeleeRange.FloatValue;
		else if(IsValidShotWeapon(classname))
			range = L4D2_GetFloatWeaponAttribute(classname, L4D2FWA_Range);
		else
			mode = 0;
	}
	if(range <= 0.0)
	{
		if(CanSecondryAttack(weapon))
		{
			mode = IN_ATTACK2;
			range = g_hCvarShovRange.FloatValue;
		}
	}
	if(mode == 0)
		return Plugin_Continue;
	
	float vEye[3];
	GetClientEyePosition(client, vEye);
	
	Handle trace = TR_TraceRayFilterEx(vEye, angles, MASK_SHOT, RayType_Infinite, TraceRayFilter_HitShotable, client);
	if(TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if(IsValidEnemy(entity))
		{
			float vPos[3];
			TR_GetEndPosition(vPos, trace);
			if(GetVectorDistance(vEye, vPos, false) < range)
			{
				buttons |= mode;
				
				// 强制连发模式，避免手枪打不出来
				if(HasEntProp(weapon, Prop_Send, "m_isHoldingFireButton"))
					SetEntProp(weapon, Prop_Send, "m_isHoldingFireButton", 0);
			}
		}
	}
	
	delete trace;
	return Plugin_Changed;
}

bool IsValidEnemy(int entity)
{
	if(IsValidAliveClient(entity))
	{
		if(GetClientTeam(entity) == 3 && !GetEntProp(entity, Prop_Send, "m_isGhost", 1))
		{
			// 检查 Tank 是否为沮丧状态
			if(GetEntProp(entity, Prop_Send, "m_zombieClass") != 8 ||
				!GetEntProp(entity, Prop_Send, "m_isIncapacitated", 1))
				return true;
		}
		
		if(GetClientTeam(entity) == 2 && IsSurvivorHeld(entity))
			return true;
	}
	
	if(entity > MaxClients && IsValidEdict(entity) && GetEntProp(entity, Prop_Data, "m_iHealth") > 0)
	{
		static char classname[64];
		GetEdictClassname(entity, classname, 64);
		
		// 检查 Witch 愤怒和 普感 燃烧状态
		if((StrEqual(classname, "infected", false) && !GetEntProp(entity, Prop_Send, "m_bIsBurning", 1)) ||
			(StrEqual(classname, "witch", false) && GetEntPropFloat(entity, Prop_Send, "m_rage") >= 1.0))
			return true;
	}
	
	return false;
}

bool IsValidShotWeapon(const char[] classname)
{
	return (StrContains(classname, "shotgun", false) != -1 || StrContains(classname, "smg", false) != -1 ||
		StrContains(classname, "rifle", false) != -1 || StrContains(classname, "sniper", false) != -1 ||
		StrContains(classname, "pistol", false) != -1 || StrContains(classname, "launcher", false) != -1
	);
}

bool IsValidMeleeWeapon(const char[] classname)
{
	return (StrContains(classname, "melee", false) != -1);
}

bool CanPrimaryAttack(int entity, int owner = -1)
{
	if(!HasEntProp(entity, Prop_Send, "m_flNextPrimaryAttack"))
		return false;
	
	float time = GetGameTime();
	if(GetEntPropFloat(entity, Prop_Send, "m_flNextPrimaryAttack") > time)
		return false;
	
	if(owner > -1 && GetEntPropFloat(owner, Prop_Send, "m_flNextAttack") > time)
		return false;
	
	if(!HasEntProp(entity, Prop_Data, "m_strMapSetScriptName") && GetEntProp(entity, Prop_Send, "m_iClip1") <= 0)
		return false;
	
	return true;
}

bool CanSecondryAttack(int entity)
{
	if(!HasEntProp(entity, Prop_Send, "m_flNextSecondaryAttack"))
		return false;
	
	float time = GetGameTime();
	if(GetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack") > time)
		return false;
	
	return true;
}

public bool TraceRayFilter_HitShotable(int entity, int mask, any myself)
{
	if(entity <= 0 || !IsValidEdict(entity))
		return true;
	
	if(entity == myself)
		return false;
	
	if(IsValidAliveClient(entity))
	{
		if(GetClientTeam(entity) == 3 && !GetEntProp(entity, Prop_Send, "m_isGhost"))
			return true;
		
		if(GetClientTeam(entity) == 2 && IsSurvivorHeld(entity))
			return true;
		
		return false;
	}
	
	static char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	if(StrContains(classname, "env_", false) == 0 || StrContains(classname, "info_", false) == 0 ||
		StrContains(classname, "func_", false) == 0 || StrContains(classname, "weapon_", false) == 0)
		return false;
	
	return true;
}
