#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define L4D2 Nightmarish Common
#define PLUGIN_VERSION "1.1"
#define DEBUG 0

ConVar cvarNightmareChance;

ConVar cvarType1Size;
ConVar cvarType1HPMin;
ConVar cvarType1HPMax;
ConVar cvarType1SpeedMin;
ConVar cvarType1SpeedMax;
ConVar cvarType1Damage;
ConVar cvarType1Armor;

ConVar cvarType2Size;
ConVar cvarType2HPMin;
ConVar cvarType2HPMax;
ConVar cvarType2SpeedMin;
ConVar cvarType2SpeedMax;
ConVar cvarType2Damage;
ConVar cvarType2Armor;

ConVar cvarType3Size;
ConVar cvarType3HPMin;
ConVar cvarType3HPMax;
ConVar cvarType3SpeedMin;
ConVar cvarType3SpeedMax;
ConVar cvarType3Damage;
ConVar cvarType3Armor;

ConVar cvarType4Size;
ConVar cvarType4HPMin;
ConVar cvarType4HPMax;
ConVar cvarType4SpeedMin;
ConVar cvarType4SpeedMax;
ConVar cvarType4Damage;
ConVar cvarType4Armor;

int CommonType[4097];
bool isMapRunning = false;
Handle PluginStartTimer = null;

public Plugin myinfo = 
{
    name = "噩梦感染者",
    author = "Mortiegama",
    description = "随机调整普感大小、血量、伤害、速度",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=239492"
}

	//AtomicStryker - Damage Mod (SDK Hooks):
	//https://forums.alliedmods.net/showthread.php?p=1184761
	
	//Bacardi - Cleaning up code:
	//https://forums.alliedmods.net/showpost.php?p=2128853&postcount=4

public void OnPluginStart()
{
	CreateConVar("l4d_ncm_version", PLUGIN_VERSION, "插件版本", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvarNightmareChance = CreateConVar("l4d_ncm_nightmarechance", "90", "普通感染者转变几率", 0, true, 0.0, false, _);

	cvarType1Size= CreateConVar("l4d_ncm_type1size", "0.7", "类型1大小", 0, true, 0.0, false, _);
	cvarType1HPMin= CreateConVar("l4d_ncm_type1hpmin", "20", "类型1血量最小值", 0, true, 0.0, false, _);
	cvarType1HPMax= CreateConVar("l4d_ncm_type1hpmax", "40", "类型1血量最大值", 0, true, 0.0, false, _);
	cvarType1SpeedMin= CreateConVar("l4d_ncm_type1speedmin", "1.5", "类型1速度最小值", 0, true, 0.0, false, _);
	cvarType1SpeedMax= CreateConVar("l4d_ncm_type1speedmax", "1.8", "类型1速度最大值", 0, true, 0.0, false, _);
	cvarType1Damage= CreateConVar("l4d_ncm_type1damage", "1.5", "类型1伤害倍率", 0, true, 0.0, false, _);
	cvarType1Armor= CreateConVar("l4d_ncm_type1armor", "1.8", "类型1受伤倍率", 0, true, 0.0, false, _);

	cvarType2Size= CreateConVar("l4d_ncm_type1size", "0.9", "类型2大小", 0, true, 0.0, false, _);
	cvarType2HPMin= CreateConVar("l4d_ncm_type2hpmin", "65", "类型2血量最小值", 0, true, 0.0, false, _);
	cvarType2HPMax= CreateConVar("l4d_ncm_type2hpmax", "85", "类型2血量最大值", 0, true, 0.0, false, _);
	cvarType2SpeedMin= CreateConVar("l4d_ncm_type2speedmin", "1.2", "类型2速度最小值", 0, true, 0.0, false, _);
	cvarType2SpeedMax= CreateConVar("l4d_ncm_type2speedmax", "1.6", "类型2速度最大值", 0, true, 0.0, false, _);
	cvarType2Damage= CreateConVar("l4d_ncm_type2damage", "0.8", "类型2伤害倍率", 0, true, 0.0, false, _);
	cvarType2Armor= CreateConVar("l4d_ncm_type2armor", "0.7", "类型2受伤倍率", 0, true, 0.0, false, _);

	cvarType3Size= CreateConVar("l4d_ncm_type3size", "1.1", "类型3大小", 0, true, 0.0, false, _);	
	cvarType3HPMin= CreateConVar("l4d_ncm_type3hpmin", "30", "类型3血量最小值", 0, true, 0.0, false, _);
	cvarType3HPMax= CreateConVar("l4d_ncm_type3hpmax", "60", "类型3血量最大值", 0, true, 0.0, false, _);
	cvarType3SpeedMin= CreateConVar("l4d_ncm_type3speedmin", "1.1", "类型3速度最小值", 0, true, 0.0, false, _);
	cvarType3SpeedMax= CreateConVar("l4d_ncm_type3speedmax", "1.5", "类型3速度最大值", 0, true, 0.0, false, _);
	cvarType3Damage= CreateConVar("l4d_ncm_type3damage", "1.3", "类型3伤害倍率", 0, true, 0.0, false, _);
	cvarType3Armor= CreateConVar("l4d_ncm_type3armor", "1.1", "类型3受伤倍率", 0, true, 0.0, false, _);

	cvarType4Size= CreateConVar("l4d_ncm_type4size", "1.2", "类型4大小", 0, true, 0.0, false, _);	
	cvarType4HPMin= CreateConVar("l4d_ncm_type4hpmin", "80", "类型4血量最小值", 0, true, 0.0, false, _);
	cvarType4HPMax= CreateConVar("l4d_ncm_type4hpmax", "110", "类型4血量最大值", 0, true, 0.0, false, _);
	cvarType4SpeedMin= CreateConVar("l4d_ncm_type4speedmin", "0.4", "类型4速度最小值", 0, true, 0.0, false, _);
	cvarType4SpeedMax= CreateConVar("l4d_ncm_type4speedmax", "0.7", "类型4速度最大值", 0, true, 0.0, false, _);
	cvarType4Damage= CreateConVar("l4d_ncm_type4damage", "0.6", "类型4伤害倍率", 0, true, 0.0, false, _);
	cvarType4Armor= CreateConVar("l4d_ncm_type4armor", "0.5", "类型4受伤倍率", 0, true, 0.0, false, _);

	AutoExecConfig(true, "L4D2_NightmarishCommon");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
}

public Action OnPluginStart_Delayed(Handle timer)
{
	if(PluginStartTimer != null)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = null;
	}
	return Plugin_Stop;
}

public void OnMapStart()
{
	isMapRunning = true;
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_Survivor);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!isMapRunning || IsServerProcessing() == false) return;

	if (StrEqual(classname, "infected", false))
	{
		// CreateTimer(0.5, Timer_CommonSpawn, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		SDKHook(entity, SDKHook_SpawnPost, CommonSpawn);
	}
}

public void OnEntityDestroyed(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, CommonSpawn);
	SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage_Infected);
}

// public Action Timer_CommonSpawn(Handle timer, any ref)
public void CommonSpawn(int entity)
{
	// int entity = EntRefToEntIndex(ref);
	SDKUnhook(entity, SDKHook_SpawnPost, CommonSpawn);
	if(/*entity == INVALID_ENT_REFERENCE || */!IsValidEntity(entity) || !IsValidEdict(entity))
	{ return/* Plugin_Stop*/; }

	int NightmareChance = GetRandomInt(0, 99);
	int NightmarePercent = (GetConVarInt(cvarNightmareChance));

	if (NightmareChance < NightmarePercent)
	{
		int integer = GetRandomInt(1, 4); 

		#if DEBUG
		PrintToChatAll("Entity is a common infected, type %i.", integer);
		#endif

		int iHP;
		float iSpeed;
		float iScale;

		switch (integer)
		{
			case 1:
			{
				#if DEBUG
				PrintToChatAll("Zombie type small strong fast low.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType1HPMin), GetConVarInt(cvarType1HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType1SpeedMin), GetConVarFloat(cvarType1SpeedMax));
				iScale = GetConVarFloat(cvarType1Size);
				CommonType[entity] = 1;
			}
			case 2:
			{
				#if DEBUG
				PrintToChatAll("Zombie type small weak quick sturdy.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType2HPMin), GetConVarInt(cvarType2HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType2SpeedMin), GetConVarFloat(cvarType2SpeedMax));
				iScale = GetConVarFloat(cvarType2Size);
				CommonType[entity] = 2;
			}
			case 3:
			{
				#if DEBUG
				PrintToChatAll("Zombie type big tough quick weak.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType3HPMin), GetConVarInt(cvarType3HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType3SpeedMin), GetConVarFloat(cvarType3SpeedMax));
				iScale = GetConVarFloat(cvarType3Size);
				CommonType[entity] = 3;
			}
			case 4:
			{
				#if DEBUG
				PrintToChatAll("Zombie type large titanic slow titanic.");
				#endif

				iHP = GetRandomInt(GetConVarInt(cvarType4HPMin), GetConVarInt(cvarType4HPMax));
				iSpeed = GetRandomFloat(GetConVarFloat(cvarType4SpeedMin), GetConVarFloat(cvarType4SpeedMax));
				iScale = GetConVarFloat(cvarType4Size);
				CommonType[entity] = 4;
			}
		}

		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage_Infected);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", iScale);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", iHP);//Set max and 
		SetEntProp(entity, Prop_Data, "m_iHealth", iHP); //current health of witch to defined health.
		AcceptEntityInput(entity, "Disable"); 
		SetEntPropFloat(entity, Prop_Data, "m_flSpeed", 1.0*iSpeed);
		AcceptEntityInput(entity, "Enable");
	}

	// return Plugin_Continue;
}

public Action OnTakeDamage_Infected(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!isMapRunning || IsServerProcessing() == false) return Plugin_Stop;

	if (IsValidCommon(victim))
	{
		switch (CommonType[victim])
		{
			case 1:
			{
				float damagemod = GetConVarFloat(cvarType1Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif

				if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
			}
			case 2:
			{
				float damagemod = GetConVarFloat(cvarType2Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif

				if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
			}
			case 3:
			{
				float damagemod = GetConVarFloat(cvarType3Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif

				if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
			}
			case 4:
			{
				float damagemod = GetConVarFloat(cvarType4Armor);

				#if DEBUG
				PrintToChatAll("Damage Caught: %f damage times %f mod.", damage, damagemod);
				#endif

				if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
			}
		}
	}

	return Plugin_Changed;
}

public Action OnTakeDamage_Survivor(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!isMapRunning || IsServerProcessing() == false) return Plugin_Stop;

	if (IsValidCommon(attacker))
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == 2)
		{
			switch (CommonType[attacker])
			{
				case 1:
				{
					float damagemod = GetConVarFloat(cvarType1Damage);

					#if DEBUG
					PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
					#endif

					if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
				}
				case 2:
				{
					float damagemod = GetConVarFloat(cvarType2Damage);

					#if DEBUG
					PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
					#endif

					if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
				}
				case 3:
				{
					float damagemod = GetConVarFloat(cvarType3Damage);

					#if DEBUG
					PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
					#endif

					if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
				}
				case 4:
				{
					float damagemod = GetConVarFloat(cvarType4Damage);

					#if DEBUG
					PrintToChatAll("Survivor damage Caught: %f damage times %f mod.", damage, damagemod);
					#endif

					if (FloatCompare(damagemod, 1.0) != 0) { damage = damage * damagemod; }
				}
			}
		}
	}

	return Plugin_Changed;
}

public void OnMapEnd()
{
	isMapRunning = false;
}

int IsValidCommon(int common)
{
	if(common > MaxClients && IsValidEdict(common) && IsValidEntity(common))
	{
		char classname[32];
		GetEdictClassname(common, classname, sizeof(classname));
		if(StrEqual(classname, "infected")) { return true; }
	}
	return false;
}

public int IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (!IsPlayerAlive(client)) return false;
	return true;
}