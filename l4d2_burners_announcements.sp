#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

Handle gascanArray = INVALID_HANDLE, hitterArray = INVALID_HANDLE;
bool isL4D2, isLate, isModifying, mapStarted;

public Plugin myinfo =
{
	name = "纵火提示",
	author = "[ru]In1ernal Error, cravenge",
	description = "Notifies Everyone Who The Burner Is.",
	version = "1.1",
	url = ""
};

public APLRes:AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{
	isLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	char modName[12];
	GetGameFolderName(modName, sizeof(modName));
	if (StrEqual(modName, "left4dead2", false))
	{
		isL4D2 = true;
	}
	else
	{
		if (!StrEqual(modName, "left4dead", false))
		{
			SetFailState("[BA] Plugin Supports L4D and L4D2 Only!");
		}
		else
		{
			isL4D2 = false;
		}
	}
	
	CreateConVar("burners_announcements_version", "1.1", "Burners Announcements Version", FCVAR_NOTIFY);
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("molotov_thrown", OnMolotovThrown);
	
	gascanArray = CreateArray();
	hitterArray = CreateArray();
	
	RefreshThem();
	ModifyThem();
	
	if (isLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnGasCanEquip);
}

public Action OnGasCanEquip(int client, int weapon)
{
	if(gascanArray == INVALID_HANDLE)
		return;
	
	if (IsValidEnt(weapon))
	{
		char weaponClassname[32];
		GetEdictClassname(weapon, weaponClassname, sizeof(weaponClassname));
		if (!StrEqual(weaponClassname, "weapon_gascan"))
		{
			return;
		}
		
		int weaponIndex = FindValueInArray(gascanArray, weapon);
		if (weaponIndex > -1)
		{
			SetArrayCell(hitterArray, weaponIndex, -1);
		}
	}
}

public Action OnGasCansDamaged(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidClient(attacker) || !IsValidEnt(victim))
	{
		return Plugin_Continue;
	}
	
	char victimClass[32];
	GetEdictClassname(victim, victimClass, sizeof(victimClass));
	if (!StrEqual(victimClass, "weapon_gascan"))
	{
		return Plugin_Continue;
	}
	
	int victimIndex = FindValueInArray(gascanArray, victim);
	if (victimIndex != -1)
	{
		if (GetArrayCell(hitterArray, victimIndex) != -1)
		{
			SetArrayCell(hitterArray, victimIndex, -1);
		}
		SetArrayCell(hitterArray, victimIndex, attacker);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	mapStarted = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= 0 || entity > 2048)
	{
		return;
	}
	
	if (StrEqual(classname, "weapon_gascan"))
	{
		RefreshThem();
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (mapStarted)
	{
		RefreshThem();
		ModifyThem();
	}
}

public Action OnMolotovThrown(Event event, const char[] name, bool dontBroadcast)
{
	int thrower = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(thrower))
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
		{
			PrintToChat(i, "\x03[BA]\x04 %N \x01投掷了 \x05火瓶", thrower);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (gascanArray == INVALID_HANDLE || !IsValidEnt(entity))
	{
		return;
	}
	
	char entClass[32];
	GetEdictClassname(entity, entClass, sizeof(entClass));
	if (!StrEqual(entClass, "weapon_gascan"))
	{
		return;
	}
	
	int gascanIndex = FindValueInArray(gascanArray, entity);
	if (gascanIndex != -1)
	{
		int gascanHitter = GetArrayCell(hitterArray, gascanIndex);
		if (IsValidClient(gascanHitter))
		{
			if (isL4D2)
			{
				Event OnScavengeGCDestroyed = CreateEvent("scavenge_gas_can_destroyed", true);
				OnScavengeGCDestroyed.SetInt("userid", GetClientUserId(gascanHitter));
				OnScavengeGCDestroyed.Fire(false);
			}
			else
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
					{
						PrintToChat(i, "\x03[BA]\x04 %N \x01点燃了 \x05油桶", gascanHitter);
					}
				}
			}
		}
		SDKUnhook(entity, SDKHook_OnTakeDamage, OnGasCansDamaged);
		SetArrayCell(gascanArray, gascanIndex, -1);
	}
}

public void OnMapEnd()
{
	mapStarted = false;
	
	CloseHandle(gascanArray);
	gascanArray = INVALID_HANDLE;
	
	CloseHandle(hitterArray);
	hitterArray = INVALID_HANDLE;
}

void RefreshThem()
{
	if (isModifying)
	{
		return;
	}
	
	GasCansHook(false);
	
	ClearArray(gascanArray);
	ClearArray(hitterArray);
	
	GasCansHook(true);
}

void GasCansHook(bool apply)
{
	if(gascanArray == INVALID_HANDLE)
		return;
	
	if (apply)
	{
		for (int i = 0; i <= GetMaxEntities(); i++)
		{
			if (IsValidEntity(i) && IsValidEdict(i))
			{
				char gcClassname[32];
				GetEdictClassname(i, gcClassname, sizeof(gcClassname));
				if (!StrEqual(gcClassname, "weapon_gascan")) 
				{
					continue;
				}
				
				SDKHook(i, SDKHook_OnTakeDamage, OnGasCansDamaged);
				
				PushArrayCell(gascanArray, i);
				PushArrayCell(hitterArray, -1);
			}
		}
	}
	else
	{
		for (int i = 0; i < GetArraySize(gascanArray); i++)
		{
			int entity = GetArrayCell(gascanArray, i);
			if (entity != -1)
			{
				SDKUnhook(entity, SDKHook_OnTakeDamage, OnGasCansDamaged);
			}
		}
	}
}

void ModifyThem()
{
	isModifying = true;
	
	for (int i = 0; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			char gcModel[128], iClassname[32];
			
			gcModel[0] = '\0';
			
			GetEdictClassname(i, iClassname, sizeof(iClassname));
			if (StrEqual(iClassname, "prop_physics"))
			{
				GetEntPropString(i, Prop_Data, "m_ModelName", gcModel, sizeof(gcModel));
				if (StrEqual(gcModel, "models/props_junk/gascan001a.mdl"))
				{
					int replacedGC = CreateEntityByName("weapon_gascan");
					SetEntityModel(replacedGC, gcModel);
					
					float vPos[3], vAng[3];
					
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vPos);
					GetEntPropVector(i, Prop_Send, "m_angRotation", vAng);
					
					DispatchKeyValueVector(replacedGC, "origin", vPos);
					DispatchKeyValueVector(replacedGC, "angles", vAng);
					DispatchSpawn(replacedGC);
					
					AcceptEntityInput(i, "Kill");
				}
			}
		}
	}
	
	isModifying = false;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) > 1);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

