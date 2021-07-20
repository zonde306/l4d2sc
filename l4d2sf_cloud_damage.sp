#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION 				"2.22"
#define CVAR_FLAGS 					FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION 	FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

#define DEBUG 0

static const float TRACE_TOLERANCE = 25.0;

Handle CloudEnabled 			= INVALID_HANDLE;
Handle CloudDuration 			= INVALID_HANDLE;
Handle CloudRadius 				= INVALID_HANDLE;
Handle CloudDamage 				= INVALID_HANDLE;
Handle CloudShake 				= INVALID_HANDLE;
Handle CloudBlocksRevive 		= INVALID_HANDLE;
Handle SoundPath 				= INVALID_HANDLE;
Handle CloudMeleeSlowEnabled 	= INVALID_HANDLE;
Handle DisplayDamageMessage 	= INVALID_HANDLE;

static Handle cvarGameModeActive 	= INVALID_HANDLE;
static bool isAllowedGameMode 		= false;

int meleeentinfo;
bool isincloud[MAXPLAYERS+1];
bool swappedTeams[MAXPLAYERS+1];
bool MeleeDelay[MAXPLAYERS+1];
int propinfoghost;

public Plugin myinfo = 
{
	name 		= "舌头烟雾伤害",
	author 		= "AtomicStryker",
	description = "The cloud of smoke created when a Smoker dies causes damage to the survivors",
	version 	= PLUGIN_VERSION,
	url 		= "http://forums.alliedmods.net/showthread.php?t=96665"
}

int g_iSlotAbility;
int g_iLevelCloud[MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateConVar("l4d_cloud_damage_version", PLUGIN_VERSION, " Version of L4D Cloud Damage on this server ", CVAR_FLAGS_PLUGIN_VERSION);
	
	CloudEnabled 			= CreateConVar("l4d_cloud_damage_enabled", 		"1", 									" Enable/Disable the Cloud Damage plugin ", CVAR_FLAGS);
	CloudDamage 			= CreateConVar("l4d_cloud_damage_damage", 		"2.5", 									" Amount of damage the cloud deals every half second", CVAR_FLAGS);
	CloudDuration 			= CreateConVar("l4d_cloud_damage_time", 		"10.0", 								"How long the cloud damage persists in seconds. ", CVAR_FLAGS);
	CloudRadius 			= CreateConVar("l4d_cloud_damage_radius", 		"150", 									" Radius of gas cloud damage ", CVAR_FLAGS);
	SoundPath 				= CreateConVar("l4d_cloud_damage_sound", 		"player/survivor/voice/choke_5.wav", 	"Path to the Soundfile being played on each damaging Interval", CVAR_FLAGS);
	CloudMeleeSlowEnabled 	= CreateConVar("l4d_cloud_meleeslow_enabled", 	"0", 									" Enable/Disable the Cloud Melee Slow Effect ", CVAR_FLAGS);
	DisplayDamageMessage 	= CreateConVar("l4d_cloud_message_enabled", 	"0", 									" 0 - Disabled; 1 - small HUD Hint; 2 - big HUD Hint; 3 - Chat Notification ", CVAR_FLAGS);
	CloudShake 				= CreateConVar("l4d_cloud_shake_enabled", 		"0", 									" Enable/Disable the Cloud Damage Shake ", CVAR_FLAGS);
	CloudBlocksRevive 		= CreateConVar("l4d_cloud_blocks_revive", 		"0", 									" Enable/Disable the Cloud Damage Stopping Reviving ", CVAR_FLAGS);
	
	cvarGameModeActive		= CreateConVar("l4d_cloud_gamemodesactive", 	"coop, versus, teamversus, realism", 	" Set the gamemodes for which the plugin should be activated (same usage as sv_gametypes, i.e. add all game modes where you want it active separated by comma) ", CVAR_FLAGS);
	
	HookConVarChange(FindConVar("mp_gamemode"), GameModeChanged);
	CheckGamemode();
	
	AutoExecConfig(true, "l4d_cloud_damage");
	
	AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback));
	
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", PlayerTeam);
	HookEvent("round_start", RoundStart);
	
	meleeentinfo = FindSendPropInfo("CTerrorPlayer", "m_iShovePenalty");
	propinfoghost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	
	char gamename[128];
	GetGameFolderName(gamename, sizeof(gamename));
	if (StrContains(gamename, "left4dead") < 0)
	{
		SetFailState("This Plugin only supports L4D or L4D2");
	}
	
	LoadTranslations("l4d2sf_cloud_damage.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "cloud_damage", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "cloud_damage"))
		FormatEx(result, maxlen, "%T", "云烟伤害", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "cloud_damage"))
		FormatEx(result, maxlen, "%T", tr("云烟伤害%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "cloud_damage"))
		g_iLevelCloud[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelCloud[client] = L4D2SF_GetClientPerk(client, "cloud_damage");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void GameModeChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	CheckGamemode();
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	CheckGamemode();
}

static void CheckGamemode()
{
	char gamemode[PLATFORM_MAX_PATH];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	char convarsetting[PLATFORM_MAX_PATH];
	GetConVarString(cvarGameModeActive, convarsetting, sizeof(convarsetting));
	
	isAllowedGameMode = ListContainsString(convarsetting, ",", gamemode);
}

stock bool ListContainsString(const char[] list, const char[] separator, const char[] string)
{
	char buffer[64][15];
	
	int count = ExplodeString(list, separator, buffer, 14, sizeof(buffer));
	for (int i = 0; i < count; i++)
	{
		if (StrEqual(string, buffer[i], false))
		{
			return true;
		}
	}
	
	return false;
}

public Action PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// We get the client id
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If client is valid
	if (!client || !isAllowedGameMode || !IsClientInGame(client) || GetClientTeam(client) !=3 || IsPlayerSpawnGhost(client))
	{
		return Plugin_Continue;
	}
	
	char class[100];
	GetClientModel(client, class, sizeof(class));
	
	if (StrContains(class, "smoker", false) != -1)
	{
		if (GetConVarBool(CloudEnabled) && g_iLevelCloud[client] >= 1)
		{
			#if DEBUG
			PrintToChatAll("Smokerdeath caught, Plugin running");
			#endif
			
			float g_pos[3];
			GetClientEyePosition(client, g_pos);
			
			CreateGasCloud(client, g_pos);
		}
	}
	return Plugin_Continue;
}

static void CreateGasCloud(int client, float g_pos[3])
{
	#if DEBUG
	PrintToChatAll("Action GasCloud running");
	#endif
	
	float targettime = GetEngineTime() + GetConVarFloat(CloudDuration);
	
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackFloat(data, g_pos[0]);
	WritePackFloat(data, g_pos[1]);
	WritePackFloat(data, g_pos[2]);
	WritePackFloat(data, targettime);
	
	CreateTimer(0.5, Point_Hurt, data, TIMER_REPEAT);
}

public Action PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	swappedTeams[client] = true;
	CreateTimer(0.5, EraseGhostExploit, client);
}

public Action EraseGhostExploit(Handle timer, any client)
{	
	swappedTeams[client] = false;
}

public Action Point_Hurt(Handle timer, Handle hurt)
{
	ResetPack(hurt);
	int client = ReadPackCell(hurt);
	float g_pos[3];
	g_pos[0] = ReadPackFloat(hurt);
	g_pos[1] = ReadPackFloat(hurt);
	g_pos[2] = ReadPackFloat(hurt);
	float targettime = ReadPackFloat(hurt);
	
	if (targettime - GetEngineTime() < 0)
	{
		#if DEBUG
		PrintToChatAll("Target Time reached Action PointHurter killing itself");
		#endif
	
		CloseHandle(hurt);
		return Plugin_Stop;
	}
	
	#if DEBUG
	PrintToChatAll("Action PointHurter running");
	#endif
	
	if (!IsClientInGame(client)) client = -1;
	// dummy line to prevent compiling errors. the client data has to be read or the datapack becomes corrupted
	
	float targetVector[3];
	float distance;
	float radiussetting = GetConVarFloat(CloudRadius);
	char soundFilePath[256];
	GetConVarString(SoundPath, soundFilePath, sizeof(soundFilePath));
	bool shakeenabled = GetConVarBool(CloudShake);
	int damage = GetConVarInt(CloudDamage);
	bool slowenabled = GetConVarBool(CloudMeleeSlowEnabled);
	
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!target || !IsClientInGame(target) || !IsPlayerAlive(target) || GetClientTeam(target) != 2)
		{
			continue;
		}

		GetClientEyePosition(target, targetVector);
		distance = GetVectorDistance(targetVector, g_pos);
		
		if (distance > radiussetting || !IsVisibleTo(g_pos, targetVector)) continue;

		EmitSoundToClient(target, soundFilePath);
		switch (GetConVarInt(DisplayDamageMessage))
		{
			case 1: PrintCenterText(target, "You are taking damage from standing in a Smoker Cloud");
			
			case 2: PrintHintText(target, "You are taking damage from standing in a Smoker Cloud");
			
			case 3: PrintToChat(target, "You are taking damage from standing in a Smoker Cloud");
		}
		
		if (shakeenabled)
		{
			Handle hBf = StartMessageOne("Shake", target);
			BfWriteByte(hBf, 0);
			BfWriteFloat(hBf,6.0);
			BfWriteFloat(hBf,1.0);
			BfWriteFloat(hBf,1.0);
			EndMessage();
			CreateTimer(0.5, StopShake, target);
		}
		
		if (slowenabled && !IsFakeClient(target))
		{
			isincloud[target] = true;
			CreateTimer(0.5, ClearMeleeBlock, target);
		}
		
		applyDamage(damage, target, client);
	}
	
	return Plugin_Continue;
}

public Action HookSound_Callback(Clients[64], int &NumClients, char StrSample[PLATFORM_MAX_PATH], int &Entity)
{
	//to work only on melee sounds, its 'swish' or 'weaponswing'
	if (StrContains(StrSample, "Swish", false) == -1) return Plugin_Continue;
	//so the client has the melee sound playing. OMG HES MELEEING!
	
	if (Entity > MAXPLAYERS) return Plugin_Continue; // bugfix for some people on L4D2
	
	//add in a 1 second delay so this doesnt fire every frame
	if (MeleeDelay[Entity]) return Plugin_Continue; //note 'Entity' means 'client' here
	MeleeDelay[Entity] = true;
	CreateTimer(0.5, ResetMeleeDelay, Entity);
	
	#if DEBUG
	PrintToChatAll("Melee detected via soundhook.");
	#endif
	
	if (isincloud[Entity]) SetEntData(Entity, meleeentinfo, 1.5, 4);	
	
	return Plugin_Continue;
}

public Action ResetMeleeDelay(Handle timer, any client)
{
	MeleeDelay[client] = false;
}

public Action ClearMeleeBlock(Handle timer, any target)
{
	isincloud[target] = false;
}

public Action StopShake(Handle timer, any target)
{
	if (!target || !IsClientInGame(target)) return;
	
	Handle hBf = StartMessageOne("Shake", target);
	BfWriteByte(hBf, 0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	EndMessage();
}

stock bool IsPlayerSpawnGhost(int client)
{
	if (GetEntData(client, propinfoghost, 1)) return true;
	return false;
}

stock bool IsPlayerIncapped(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}

// timer idea by dirtyminuth, damage dealing by pimpinjuice http://forums.alliedmods.net/showthread.php?t=111684
// added some L4D specific checks
static void applyDamage(int damage, int victim, int attacker)
{ 
	Handle dataPack = CreateDataPack();
	WritePackCell(dataPack, damage);  
	WritePackCell(dataPack, victim);
	WritePackCell(dataPack, attacker);
	
	CreateTimer(0.10, timer_stock_applyDamage, dataPack);
}

public Action timer_stock_applyDamage(Handle timer, Handle dataPack)
{
	ResetPack(dataPack);
	int damage = ReadPackCell(dataPack);  
	int victim = ReadPackCell(dataPack);
	int attacker = ReadPackCell(dataPack);
	CloseHandle(dataPack);
	
	float victimPos[3];
	char strDamage[16], strDamageTarget[16];
	
	if (!IsClientInGame(victim)) return;
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	int entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;
	
	bool reviveblock = GetConVarBool(CloudBlocksRevive);

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", reviveblock ? "65536" : "263168");
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker > 0 && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
}

static bool IsVisibleTo(float position[3], float targetposition[3])
{
	float vAngles[3], vLookAt[3];
	
	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace
	
	// execute Trace
	Handle trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, _TraceFilter);
	
	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint
		
		if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	else
	{
		LogError("Tracer Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);
	
	return isVisible;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	if (!entity || !IsValidEntity(entity)) // dont let WORLD, or invalid entities be hit
	{
		return false;
	}
	
	return true;
}