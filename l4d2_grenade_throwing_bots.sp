#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4downtown>

bool bChill[2], bTongueOwned[MAXPLAYERS+1];
int chosenThrower, chosenTarget, shootOrder[MAXPLAYERS+1], failedTimes[MAXPLAYERS+1],
	lastChosen[3];

float throwerPos[3], targetPos[3];
ArrayList throwablesFound;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char sGame[16];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		strcopy(error, err_max, "[GTB] Plugin Supports L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "机器人扔雷",
	author = "cravenge, Edison1318, Windy Wind, Lux",
	description = "Allows Bots To Throw Grenades Themselves.",
	version = "1.7",
	url = ""
};

public void OnPluginStart()
{
	HookEvent("round_start", OnRoundStart);
	HookEvent("tongue_grab", OnTongueGrab);
	HookEvent("tongue_release", OnTongueRelease);
	
	HookEvent("player_hurt", OnPlayerHurt);
	
	CreateTimer(1.0, CheckForDanger, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	throwablesFound = new ArrayList();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= 0 || entity > 2048 || classname[0] != 'w' || classname[1] != 'e' || classname[2] != 'a')
	{
		return;
	}
	
	CreateTimer(2.0, LookForGrenades, entity);
}

public Action LookForGrenades(Handle timer, any entity)
{
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	char sEntityClass[64];
	GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
	if (StrContains(sEntityClass, "weapon_", false) != -1)
	{
		if (IsGrenade(entity))
		{
			if (!IsEquipped(entity))
			{
				for (int i = 0; i < throwablesFound.Length; i++)
				{
					if (entity == throwablesFound.Get(i))
					{
						return Plugin_Stop;
					}
					else if (!IsValidEntity(throwablesFound.Get(i)))
					{
						throwablesFound.Erase(i);
					}
				}
				throwablesFound.Push(entity);
			}
		}
	}
	
	return Plugin_Stop;
}

public void OnEntityDestroyed(int entity)
{
	if (throwablesFound != null && IsGrenade(entity))
	{
		if (!IsEquipped(entity))
		{
			for (int i = 0; i < throwablesFound.Length; i++)
			{
				if (entity == throwablesFound.Get(i))
				{
					throwablesFound.Erase(i);
				}
			}
		}
	}
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	chosenThrower = 0;
	chosenTarget = 0;
	
	bChill[0] = false;
	bChill[1] = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			shootOrder[i] = 0;
			failedTimes[i] = 0;
			
			bTongueOwned[i] = false;
		}
	}
	
	for (int i = 0; i < 3; i++)
	{
		lastChosen[i] = 0;
		
		throwerPos[i] = 0.0;
		targetPos[i] = 0.0;
	}
	
	return Plugin_Continue;
}

public Action CheckForDanger(Handle timer)
{
	if (!IsServerProcessing() || bChill[0])
	{
		return Plugin_Continue;
	}
	
	if (chosenThrower == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i) && IsInShape(i) && i != lastChosen[0])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", throwerPos);
				
				chosenThrower = i;
				lastChosen[0] = i;
				
				break;
			}
		}
	}
	else
	{
		if (!IsClientInGame(chosenThrower) || GetClientTeam(chosenThrower) != 2 || !IsPlayerAlive(chosenThrower))
		{
			chosenThrower = 0;
			failedTimes[chosenThrower] = 0;
			
			return Plugin_Continue;
		}
		
		if (chosenTarget == 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && !GetEntProp(i, Prop_Send, "m_isGhost", 1))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
					chosenTarget = i;
					
					break;
				}
			}
		}
		else
		{
			if (!IsClientInGame(chosenTarget) || GetClientTeam(chosenTarget) != 3 || !IsPlayerAlive(chosenTarget) || GetEntProp(chosenTarget, Prop_Send, "m_zombieClass") != 8)
			{
				chosenTarget = 0;
				failedTimes[chosenThrower] = 0;
				
				bChill = true;
				CreateTimer(7.5, FireAgain);
				
				return Plugin_Continue;
			}
			
			if (ChangeToGrenade(chosenThrower, true, _, true) && CanBeSeen(chosenThrower, chosenTarget, 750.0))
			{
				bChill[0] = true;
				CreateTimer(15.0, FireAgain);
				
				float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];
				
				GetClientEyePosition(chosenThrower, fEyePos);
				MakeVectorFromPoints(fEyePos, targetPos, fTargetTrajectory);
				GetVectorAngles(fTargetTrajectory, fEyeAngles);
				
				fEyeAngles[2] -= 7.5;
				TeleportEntity(chosenThrower, NULL_VECTOR, fEyeAngles, NULL_VECTOR);
				
				shootOrder[chosenThrower] = 1;
				CreateTimer(2.0, DelayThrow, chosenThrower);
				CreateTimer(3.0, ChooseAnother);
			}
			else
			{
				if (failedTimes[chosenThrower] >= 10)
				{
					failedTimes[chosenThrower] = 0;
					
					chosenThrower = 0;
					chosenTarget = 0;
				}
				else
				{
					failedTimes[chosenThrower] += 1;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action FireAgain(Handle timer)
{
	if (!bChill[0])
	{
		return Plugin_Stop;
	}
	
	bChill[0] = false;
	return Plugin_Stop;
}

public Action ChooseAnother(Handle timer)
{
	if (chosenThrower == 0 && chosenTarget == 0)
	{
		return Plugin_Stop;
	}
	
	chosenThrower = 0;
	chosenTarget = 0;
	
	return Plugin_Stop;
}

public Action DelayThrow(Handle timer, any client)
{
	if (shootOrder[client] == 0)
	{
		return Plugin_Stop;
	}
	
	shootOrder[client] = 0;
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && IsFakeClient(client))
	{
		int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != -1 && IsValidEntity(iActiveWeapon))
		{
			char sActiveWeapon[64];
			GetEntityClassname(iActiveWeapon, sActiveWeapon, sizeof(sActiveWeapon));
			if (iActiveWeapon == GetPlayerWeaponSlot(client, 2) && (StrEqual(sActiveWeapon, "weapon_molotov") || StrEqual(sActiveWeapon, "weapon_pipe_bomb") || StrEqual(sActiveWeapon, "weapon_vomitjar")))
			{
				if (shootOrder[client] == 1)
				{
					buttons |= IN_ATTACK;
				}
				else
				{
					buttons &= ~IN_ATTACK;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action L4D2_OnFindScavengeItem(int client, int &item)
{
	if (!item)
	{
		float itemOrigin[3], scavengerOrigin[3];
		
		int throwable = GetPlayerWeaponSlot(client, 2);
		if (!IsValidEdict(throwable))
		{
			for (int i = 0; i < throwablesFound.Length; i++)
			{
				int entity = throwablesFound.Get(i);
				if (!IsValidEntity(entity) || !HasEntProp(entity, Prop_Send, "m_vecOrigin"))
				{
					return Plugin_Continue;
				}
				
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", itemOrigin);
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", scavengerOrigin);
				
				float distance = GetVectorDistance(scavengerOrigin, itemOrigin);
				if (distance < 250.0)
				{
					item = entity;
					return Plugin_Changed;
				}
			}
		}
	}
	else if (IsGrenade(item))
	{
		int throwable = GetPlayerWeaponSlot(client, 2);
		if (throwable > 0 && IsValidEntity(throwable) && IsValidEdict(throwable))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int grabbed = GetClientOfUserId(event.GetInt("victim"));
	if (grabbed <= 0 || grabbed > MaxClients || !IsClientInGame(grabbed) || GetClientTeam(grabbed) != 2 || !IsFakeClient(grabbed))
	{
		return Plugin_Continue;
	}
	
	if (!bTongueOwned[grabbed])
	{
		bTongueOwned[grabbed] = true;
	}
	return Plugin_Continue;
}

public Action OnTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int released = GetClientOfUserId(event.GetInt("victim"));
	if (released <= 0 || released > MaxClients || !IsClientInGame(released) || GetClientTeam(released) != 2 || !IsFakeClient(released))
	{
		return Plugin_Continue;
	}
	
	if (bTongueOwned[released])
	{
		bTongueOwned[released] = false;
	}
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (bChill[1])
	{
		return Plugin_Continue;
	}
	
	int damaged = GetClientOfUserId(event.GetInt("userid"));
	if (damaged <= 0 || damaged > MaxClients || !IsClientInGame(damaged) || GetClientTeam(damaged) != 2 || !IsFakeClient(damaged) || !IsInShape(damaged) || damaged == chosenThrower || damaged == lastChosen[1])
	{
		return Plugin_Continue;
	}
	
	int dangerousEnt = 0;
	
	float fDangerPos[3];
	GetEntPropVector(damaged, Prop_Send, "m_vecOrigin", fDangerPos);
	
	for (int damager = 1; damager < 2049; damager++)
	{
		if (!IsCommonInfected(damager) && !IsSpecialInfected(damager))
		{
			continue;
		}
		
		float fDamagerPos[3];
		GetEntPropVector(damager, Prop_Send, "m_vecOrigin", fDamagerPos);
		
		if (GetVectorDistance(fDangerPos, fDamagerPos) > 150.0)
		{
			continue;
		}
		
		dangerousEnt += 1;
	}
	if (dangerousEnt >= 15 && ChangeToGrenade(damaged, true))
	{
		bChill[1] = true;
		CreateTimer(5.0, ApplyCooldown);
		
		lastChosen[1] = damaged;
		
		float fLookAngles[3];
		GetClientEyeAngles(damaged, fLookAngles);
		fLookAngles[2] += 90.0;
		
		shootOrder[damaged] = 1;
		CreateTimer(2.0, DelayThrow, damaged);
	}
	
	return Plugin_Continue;
}

public Action ApplyCooldown(Handle timer)
{
	if (!bChill[1])
	{
		return Plugin_Stop;
	}
	
	bChill[1] = false;
	return Plugin_Stop;
}

public Action L4D_OnSpawnMob(int &amount)
{
	float fMobPos[3];
	
	for (int i = 1; i < 2049; i++)
	{
		if (!IsCommonInfected(i))
		{
			continue;
		}
		
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", fMobPos);
		break;
	}
	
	if (fMobPos[0] != 0.0 || fMobPos[1] != 0.0 || fMobPos[2] != 0.0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i) && IsInShape(i) && i != chosenThrower && i != lastChosen[2])
			{
				if (!ChangeToGrenade(i, _, true, true))
				{
					continue;
				}
				
				lastChosen[2] = i;
				
				float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];
				
				GetClientEyePosition(lastChosen[2], fEyePos);
				MakeVectorFromPoints(fEyePos, fMobPos, fTargetTrajectory);
				GetVectorAngles(fTargetTrajectory, fEyeAngles);
				
				fEyeAngles[2] += 5.0;
				TeleportEntity(lastChosen[2], NULL_VECTOR, fEyeAngles, NULL_VECTOR);
				
				shootOrder[lastChosen[2]] = 1;
				CreateTimer(5.0, DelayThrow, lastChosen[2]);
				
				break;
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnMapEnd()
{
	throwablesFound.Clear();
}

bool CanBeSeen(int client, int other, float distance = 0.0)
{
	float fPos[2][3];
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos[0]);
	fPos[0][2] += 50.0;
	
	GetClientEyePosition(other, fPos[1]);
	
	if (distance == 0.0 || GetVectorDistance(fPos[0], fPos[1], false) < distance)
	{
		Handle trace = TR_TraceRayFilterEx(fPos[0], fPos[1], MASK_SOLID_BRUSHONLY, RayType_EndPoint, EntityChecker);
		if (TR_DidHit(trace))
		{
			delete trace;
			return false;
		}
		
		delete trace;
		return true;
	}
	
	return false;
}

public bool EntityChecker(int entity, int contentsMask, any data)
{
	return (entity == data);
}

bool ChangeToGrenade(int client, bool incFire = false, bool incPipe = false, bool incBile = false)
{
	int grenade = GetPlayerWeaponSlot(client, 2);
	if (grenade != -1 && IsValidEntity(grenade) && IsValidEdict(grenade))
	{
		char sGrenade[32];
		GetEdictClassname(grenade, sGrenade, sizeof(sGrenade));
		if (StrEqual(sGrenade, "weapon_molotov") && incFire)
		{
			FakeClientCommand(client, "use weapon_molotov");
			return true;
		}
		else if (StrEqual(sGrenade, "weapon_pipe_bomb") && incPipe)
		{
			FakeClientCommand(client, "use weapon_pipe_bomb");
			return true;
		}
		else if (StrEqual(sGrenade, "weapon_vomitjar") && incBile)
		{
			FakeClientCommand(client, "use weapon_vomitjar");
			return true;
		}
	}
	
	return false;
}

bool IsInShape(int client)
{
	return (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !bTongueOwned[client] && GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") <= 0) ? true : false;
}

bool IsEquipped(int grenade)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (GetPlayerWeaponSlot(i, 2) == grenade)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool IsGrenade(int entity)
{
	if (entity > 0 && entity < 2048 && IsValidEntity(entity))
	{
		char sEntityClass[64], sEntityModel[128];
		
		GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
		GetEntPropString(entity, Prop_Data, "m_ModelName", sEntityModel, sizeof(sEntityModel));
		
		if (StrEqual(sEntityClass, "weapon_molotov") || StrEqual(sEntityClass, "weapon_molotov_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_molotov.mdl") || 
			StrEqual(sEntityClass, "weapon_pipe_bomb") || StrEqual(sEntityClass, "weapon_pipe_bomb_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_pipebomb.mdl") || 
			StrEqual(sEntityClass, "weapon_vomitjar") || StrEqual(sEntityClass, "weapon_vomitjar_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_bile_flask.mdl"))
		{
			return true;
		}
	}
	
	return false;
}

stock bool IsCommonInfected(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char entType[64];
		GetEdictClassname(entity, entType, sizeof(entType));
		return StrEqual(entType, "infected");
	}
	return false;
}

stock bool IsSpecialInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") < 7);
}

