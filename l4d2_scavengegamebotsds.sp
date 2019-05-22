#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION		"1.0"
#define CVAR_FLAGS		FCVAR_PLUGIN|FCVAR_NOTIFY
#define CONFIG_DATA		"data/scavengegamebotsds.cfg"

static Handle:hScavengeBots = INVALID_HANDLE;
static bool:bScavengeBots = false;

static BotAction[MAXPLAYERS+1];
static BotTarget[MAXPLAYERS+1];
static BotAIUpdate[MAXPLAYERS+1];
static Float:BotCheckPos[MAXPLAYERS+1][3];
static BotAbortTick[MAXPLAYERS+1];
static BotUseGasCan[MAXPLAYERS+1];

static GasNozzle;
static Float:NozzleOrigin[3];
static Float:NozzleAngles[3];
static bool:bScavengeGameInProgress = false;

public Plugin:myinfo =
{
	name = "机器人清道夫倒油",
	author = "Machine/Xanaguy",
	description = "Survivor Bots Scavenging in the Scavenge Game Mode",
	version = PLUGIN_VERSION,
	url = ""
}
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (strcmp(game, "left4dead2", false))
	{
		strcopy(error, err_max, "ScavengeBots only supports Left4Dead2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}
public OnPluginStart()
{
	hScavengeBots = CreateConVar("scavengebots_on", "1", "Enable ScavengeBots? 0=off, 1=on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	bScavengeBots = GetConVarBool(hScavengeBots);

	HookEvent("round_start", Round_Start);
	HookEvent("scavenge_round_start", Scavenge_Round_Start);
	HookEvent("weapon_drop", Weapon_Drop);

	HookConVarChange(hScavengeBots, ConVarChanged);

	CreateTimer(0.1, BotUpdate, _, TIMER_REPEAT);
}

public ConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == hScavengeBots)
	{
		bScavengeBots = GetConVarBool(hScavengeBots);
		new oldval = StringToInt(oldValue);
		new newval = StringToInt(newValue);
		if (oldval != newval)
		{
			if (newval == 0)
			{
				for (new i=1; i<=MaxClients; i++)
				{
					if (IsBot(i))
					{
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(i));
					}
				}
			}
			else
			{
				if (GetConVarInt(FindConVar("sb_unstick")) == 1)
				{
					SetConVarInt(FindConVar("sb_unstick"), 0);
				}
			}
		}
	}
}
public Action:Round_Start(Handle:event, String:event_name[], bool:dontBroadcast)
{
	ResetVariables();
	for (new i=1; i<=MaxClients; i++)
	{
		ResetClientArrays(i);
	}
}
public Action:Scavenge_Round_Start(Handle:event, String:event_name[], bool:dontBroadcast)
{
	bScavengeGameInProgress = true;
	LoadConfig();
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "point_prop_use_target")) != INVALID_ENT_REFERENCE)
	{
		GasNozzle = entity;
		HookSingleEntityOutput(entity, "OnUseStarted", OnUseStarted);
		HookSingleEntityOutput(entity, "OnUseCancelled", OnUseCancelled);
		HookSingleEntityOutput(entity, "OnUseFinished", OnUseFinished);
	}
}
public Action:Weapon_Drop(Handle:event, const String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new entity = GetEventInt(event,"propid");

	if (bScavengeGameInProgress)
	{
		if (entity > 0 && IsValidEntity(entity))
		{
			decl String:classname[24];
			GetEdictClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_gascan", false))
			{
				SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
				new glowcolor = RGB_TO_INT(255, 150, 0);
				SetEntProp(entity, Prop_Send, "m_glowColorOverride", glowcolor);
				if (IsBot(client))
				{
					if (BotTarget[client] == entity)
					{
						BotTarget[client] = -1;
					}
				}
			}
		}
	}
}
public OnClientPostAdminCheck(client)
{
	ResetClientArrays(client);
	SDKHook(client, SDKHook_PreThink, OnPreThink);
}
public OnClientDisconnect(client)
{
	ResetClientArrays(client);
}
stock ResetVariables()
{
	bScavengeGameInProgress = false;
}
stock ResetClientArrays(client)
{
	BotAction[client] = -1;
	BotTarget[client] = -1;
	BotAIUpdate[client] = -1;
	BotUseGasCan[client] = -1;
	BotAbortTick[client] = -1;
	for (new i=0; i<=2; i++)
	{
		BotCheckPos[client][i] = 0.0;
	}
}
stock LoadConfig()
{
	decl String:Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "%s", CONFIG_DATA);
	if (!FileExists(Path))
	{
		PrintToServer("ScavengeBots Error: Cannot read the config %s", Path);
		bScavengeGameInProgress = false;
		return;
	}
	new Handle:File = CreateKeyValues("maps");
	if (!FileToKeyValues(File, Path))
	{
		PrintToServer("ScavengeBots Error: Failed to get maps from %s", Path);
		bScavengeGameInProgress = false;
		CloseHandle(File);
		return;
	}
	decl String:Map[PLATFORM_MAX_PATH];
	GetCurrentMap(Map, sizeof(Map));
	if (!KvJumpToKey(File, Map))
	{
		PrintToServer("ScavengeBots Error: Failed to get map from %s", Path);
		bScavengeGameInProgress = false;
		CloseHandle(File);
		return;
	}
	KvGetVector(File, "origin", NozzleOrigin);
	KvGetVector(File, "angles", NozzleAngles);
	CloseHandle(File);
}
public Action:BotUpdate(Handle:timer)
{
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}
	if (bScavengeBots)
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsBot(i))
			{
				BotAI(i);
			}
		}
	}

	return Plugin_Continue;
}
stock BotAI(client)
{
	if (IsBot(client) && bScavengeGameInProgress)
	{
		//PrintToChatAll("client %N, action %i, target %i", client, BotAction[client], BotTarget[client]);
		if (BotAction[client] == -1)
		{
			new entity = -1;
			while ((entity = FindEntityByClassname(entity, "weapon_gascan")) != INVALID_ENT_REFERENCE)
			{
				if (IsValidGasCan(entity) && !IsGasCanOwned(entity))
				{
					BotTarget[client] = -1;
					BotAction[client] = 0;
					BotAIUpdate[client] = -1;
					BotUseGasCan[client] = -1;
					BotAbortTick[client] = -1;
					for (new i=0; i<=2; i++)
					{
						BotCheckPos[client][i] = 0.0;
					}
				}
			}
		}
		else if (BotAction[client] == 0)
		{
			if (!IsPlayerHeld(client) && !IsPlayerIncap(client))
			{
				if (BotTarget[client] > 0)
				{
					new entity = BotTarget[client];
					if (IsGasCan(entity))
					{
						decl Float:TOrigin[3];
						GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TOrigin);
						L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", TOrigin[0], TOrigin[1], TOrigin[2], GetClientUserId(client));
						BotAction[client] = 1;
						BotAIUpdate[client] = 10;
						BotUseGasCan[client] = -1;
						BotAbortTick[client] = 50;
						GetClientAbsOrigin(client, BotCheckPos[client]);
					}
					else
					{
						BotTarget[client] = -1;
					}
				}
				else
				{
					new Float:Origin[3], Float:TOrigin[3], Float:SOrigin[3], Float:distance = 0.0, Float:storeddist = 0.0, storedent = 0;
					GetEntPropVector(client, Prop_Send, "m_vecOrigin", Origin);
					new entity = -1;
					while ((entity = FindEntityByClassname(entity, "weapon_gascan")) != INVALID_ENT_REFERENCE)
					{
						if (IsValidGasCan(entity) && !IsGasCanOwned(entity))
						{
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TOrigin);
							distance = GetVectorDistance(Origin, TOrigin);
							if (storeddist == 0.0 || storeddist > distance)
							{
								storedent = entity;
								storeddist = distance;
								GetEntPropVector(entity, Prop_Send, "m_vecOrigin", SOrigin);
							}
						}
					}
					if (storedent > 0 && IsValidGasCan(storedent) && !IsGasCanOwned(storedent))
					{
						BotTarget[client] = storedent;
						L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", SOrigin[0], SOrigin[1], SOrigin[2], GetClientUserId(client));
						BotAction[client] = 1;
						BotAIUpdate[client] = 10;
						BotUseGasCan[client] = -1;
						BotAbortTick[client] = 50;
						GetClientAbsOrigin(client, BotCheckPos[client]);
					}
					else
					{
						BotAction[client] = -1;
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
					}
				}
			}
		}
		else if (BotAction[client] == 1)
		{
			decl Float:Origin[3], Float:TOrigin[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", Origin);
			new entity = BotTarget[client];
			if (IsGasCan(entity) && !IsGasCanOwned(entity))
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TOrigin);
			}
			else
			{
				BotTarget[client] = -1;
				BotAction[client] = 0;
			}
			if (IsPlayerHeld(client) || IsPlayerIncap(client))
			{
				BotAction[client] = 0;	
			}
			if (BotAbortTick[client] > 0)
			{
				new Float:distance = GetVectorDistance(Origin, BotCheckPos[client]);
				if (distance < 15.0)
				{
					BotAbortTick[client] -= 1;
					if (BotAbortTick[client] == 0)
					{
						BotTarget[client] = -1;
						BotAction[client] = 6;
						BotAIUpdate[client] = 50;
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
					}
				}
				else
				{
					GetClientAbsOrigin(client, BotCheckPos[client]);
					BotAbortTick[client] = 60;
				}
			}
			if (BotAIUpdate[client] > 0)
			{
				BotAIUpdate[client] -= 1;
				if (BotAIUpdate[client] == 0)
				{
					if (entity > 0 && IsValidEntity(entity))
					{
						L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", TOrigin[0], TOrigin[1], TOrigin[2], GetClientUserId(client));
						BotAIUpdate[client] = 10;
					}
				}
			}
			new Float:distance = GetVectorDistance(Origin, TOrigin);
			if (distance < 50.0)
			{
				PickupGasCan(client, entity);
			}
			else
			{
				decl Float:ZOrigin[3];
				ZOrigin[0] = Origin[0];
				ZOrigin[1] = Origin[1];
				ZOrigin[2] = Origin[2] + 40.0;
				distance = GetVectorDistance(ZOrigin, TOrigin);
				if (distance < 50.0)
				{
					PickupGasCan(client, entity);
				}
				else
				{
					ZOrigin[2] = Origin[2] - 40.0;
					distance = GetVectorDistance(ZOrigin, TOrigin);
					if (distance < 50.0)
					{
						PickupGasCan(client, entity);
					}
				}
			}
		}
		else if (BotAction[client] == 2)
		{
			if (!IsPlayerHeld(client) && !IsPlayerIncap(client) && IsGasCan(IsHoldingGasCan(client)))
			{
				L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", NozzleOrigin[0], NozzleOrigin[1], NozzleOrigin[2], GetClientUserId(client));
				BotAction[client] = 3;
				BotAIUpdate[client] = 10;
				BotAbortTick[client] = 50;
				GetClientAbsOrigin(client, BotCheckPos[client]);
			}
			else
			{
				BotAction[client] = 0;
			}
		}
		else if (BotAction[client] == 3)
		{
			if (IsPlayerHeld(client) || IsPlayerIncap(client) || IsHoldingGasCan(client) == 0)
			{
				BotAction[client] = 0;	
			}
			if (BotAbortTick[client] > 0)
			{
				decl Float:Origin[3];
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", Origin);
				new Float:distance = GetVectorDistance(Origin, BotCheckPos[client]);
				if (distance < 15.0)
				{
					BotAbortTick[client] -= 1;
					if (BotAbortTick[client] == 0)
					{
						BotTarget[client] = -1;
						BotAction[client] = 6;
						BotAIUpdate[client] = 50;
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
					}
				}
				else
				{
					GetClientAbsOrigin(client, BotCheckPos[client]);
					BotAbortTick[client] = 60;
				}
			}
			if (BotAIUpdate[client] > 0)
			{
				BotAIUpdate[client] -= 1;
				if (BotAIUpdate[client] == 0)
				{
					L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})", NozzleOrigin[0], NozzleOrigin[1], NozzleOrigin[2], GetClientUserId(client));
					BotAIUpdate[client] = 10;
				}
			}
			decl Float:Origin[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", Origin);
			new Float:distance = GetVectorDistance(Origin, NozzleOrigin);
			if (distance < 50.0)
			{
				if (BotUseGasCan[client] == -1)
				{
					BotUseGasCan[client] = 1;
				}
			}
		}
		else if (BotAction[client] == 4)
		{
			if (!IsAssistNeeded())
			{
				BotTarget[client] = -1;
				BotAction[client] = 0;
			}
		}
		else if (BotAction[client] == 5)
		{
			new threats = GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
			if (threats <= 0)
			{
				BotTarget[client] = -1;
				BotAction[client] = 0;
			}
		}
		else if (BotAction[client] == 6)
		{
			if (BotAIUpdate[client] > 0)
			{
				BotAIUpdate[client] -= 1;
				if (BotAIUpdate[client] == 0)
				{
					BotAction[client] = 0;
				}
			}
		}
	}
}
stock PickupGasCan(client, entity)
{
	if (IsBot(client) && entity > 0 && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Use", client);
		BotAction[client] = 2;
	}
}
stock bool:IsAssistNeeded()
{
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsSurvivor(i))
		{
			if (IsPlayerIncap(i) || IsPlayerHeld(i))
			{
				return true;
			}
		}
	}
	return false;
}
public OnPreThink(client)
{
	if (bScavengeBots)
	{
		if (IsBot(client))
		{
			if (BotAction[client] == 1)
			{
				new threats = GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
				if (threats > 0)
				{
					BotAction[client] = 5;
					L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
				}
			}
			else if (BotAction[client] == 2)
			{
				if (IsGasCan(IsHoldingGasCan(client)) && !IsPlayerHeld(client) && !IsPlayerIncap(client))
				{
					new threats = GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
					if (threats > 0)
					{
						new buttons = GetClientButtons(client);
						SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK2);
					}
					if (IsAssistNeeded())
					{
						new buttons = GetClientButtons(client);
						SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
						BotAction[client] = 4;
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
					}
				}
			}
			else if (BotAction[client] == 3)
			{
				if (BotUseGasCan[client] == 1)
				{
					if (IsGasCan(IsHoldingGasCan(client)) && !IsPlayerHeld(client) && !IsPlayerIncap(client))
					{
						new owner = GetEntPropEnt(GasNozzle, Prop_Send, "m_useActionOwner");
						if (owner <= 0)
						{
							TeleportEntity(client, NozzleOrigin, NozzleAngles, NULL_VECTOR);
							new buttons = GetClientButtons(client);
							SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
						}
						else
						{
							new entity = GetEntPropEnt(owner, Prop_Send, "m_hOwner");
							if (entity == client)
							{
								new buttons = GetClientButtons(client);
								SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
							}
						}
					}
				}
				else
				{
					new threats = GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
					if (threats > 0)
					{
						new buttons = GetClientButtons(client);
						SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK2);
					}
					if (IsAssistNeeded())
					{
						new buttons = GetClientButtons(client);
						SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
						BotAction[client] = 4;
						L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(client));
					}
				}
			}
			else if (BotAction[client] == 6)
			{
				if (IsGasCan(IsHoldingGasCan(client)) && !IsPlayerHeld(client) && !IsPlayerIncap(client))
				{
					new buttons = GetClientButtons(client);
					SetEntProp(client, Prop_Data, "m_nButtons", buttons|IN_ATTACK);
				}
			}
		}
	}
}
public OnUseStarted(const String:output[], entity, activator, Float:delay)
{
	new gascan = GetEntPropEnt(entity, Prop_Send, "m_useActionOwner");
	if (gascan > 0 && IsValidEntity(gascan))
	{
		new client = GetEntPropEnt(gascan, Prop_Send, "m_hOwner");
		if (client > 0 && IsValidEntity(client))
		{
			SetEntProp(entity, Prop_Data, "m_iHammerID", client);
		}
	}
}
public OnUseCancelled(const String:output[], entity, activator, Float:delay)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		new client = GetEntProp(entity, Prop_Data, "m_iHammerID");
		if (IsBot(client))
		{
			BotUseGasCan[client] = -1;
			//PrintToChatAll("client %N cancel", client);
		}
	}
}
public OnUseFinished(const String:output[], entity, activator, Float:delay)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		new client = GetEntProp(entity, Prop_Data, "m_iHammerID");
		if (IsBot(client))
		{
			BotTarget[client] = -1;
			BotAction[client] = 0;
			BotAIUpdate[client] = -1;
			BotUseGasCan[client] = -1;
			//PrintToChatAll("client %N finish", client);
		}
	}
}
stock bool:IsPlayerIncap(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}
stock bool:IsPlayerHeld(client)
{
	new jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	new charger = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	new hunter = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	new smoker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (jockey > 0 || charger > 0 || hunter > 0 || smoker > 0)
	{
		return true;
	}
	return false;
}
stock bool:IsSurvivor(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}
stock bool:IsBot(client)
{
	if (IsSurvivor(client) && IsFakeClient(client) && IsPlayerAlive(client))
	{
		new String:classname[16];
		GetEntityNetClass(client, classname, sizeof(classname));
    		if (StrEqual(classname, "SurvivorBot", false))
		{
			return true;
		}
	}
	return false;
}
stock bool:IsGasCan(entity)
{
	if (entity > 32 && IsValidEntity(entity))
	{
		decl String: classname[16];
		GetEdictClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "weapon_gascan", false))
			return true;
	}
	return false;
}
stock bool:IsValidGasCan(entity)
{
	for (new i=1; i<=MaxClients; i++)
	{
		if (BotTarget[i] > 0)
		{
			if (BotTarget[i] == entity)
			{
				return false;
			}
		}
	}
	return true;
}
stock bool:IsGasCanOwned(entity)
{
	if (IsGasCan(entity))
	{
		new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
		if (owner > 0)
		{
			return true;
		}
	}
	return false;
}
stock IsHoldingGasCan(client)
{
	if (IsBot(client))
	{
		new entity = GetPlayerWeaponSlot(client, 5);
		if (entity > 0 && IsValidEntity(entity))
		{
			decl String:classname[24];
			GetEdictClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_gascan", false))
			{
				return entity;
			}
		}
	}
	return 0;
}
stock RGB_TO_INT(red, green, blue) 
{
	return (blue * 65536) + (green * 256) + red;
}
stock ScriptCommand(client, const String:command[], const String:arguments[], any:...)
{
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 4);	

	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, vscript);
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}