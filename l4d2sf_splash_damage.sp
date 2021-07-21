#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

#define PLUGIN_VERSION "1.1"
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY
#pragma newdecls required
#define TEAM_SURVIVOR 2

/*#define DMG_GENERIC			0
#define DMG_CRUSH			(1 << 0)
#define DMG_BULLET			(1 << 1)
#define DMG_SLASH			(1 << 2)
#define DMG_BURN			(1 << 3)
#define DMG_VEHICLE			(1 << 4)
#define DMG_FALL			(1 << 5)
#define DMG_BLAST			(1 << 6)
#define DMG_CLUB			(1 << 7)
#define DMG_SHOCK			(1 << 8)
#define DMG_SONIC			(1 << 9)
#define DMG_ENERGYBEAM			(1 << 10)
#define DMG_PREVENT_PHYSICS_FORCE	(1 << 11)
#define DMG_NEVERGIB			(1 << 12)
#define DMG_ALWAYSGIB			(1 << 13)
#define DMG_DROWN			(1 << 14)
#define DMG_TIMEBASED			(DMG_PARALYZE | DMG_NERVEGAS | DMG_POISON | DMG_RADIATION | DMG_DROWNRECOVER | DMG_ACID | DMG_SLOWBURN)
#define DMG_PARALYZE			(1 << 15)
#define DMG_NERVEGAS			(1 << 16)
#define DMG_POISON			(1 << 17)
#define DMG_RADIATION			(1 << 18)
#define DMG_DROWNRECOVER		(1 << 19)
#define DMG_ACID			(1 << 20)
#define DMG_SLOWBURN			(1 << 21)
#define DMG_REMOVENORAGDOLL		(1 << 22)
#define DMG_PHYSGUN			(1 << 23)
#define DMG_PLASMA			(1 << 24)
#define DMG_AIRBOAT			(1 << 25)
#define DMG_DISSOLVE			(1 << 26)
#define DMG_BLAST_SURFACE		(1 << 27)
#define DMG_DIRECT			(1 << 28)
#define DMG_BUCKSHOT			(1 << 29)*/

#define DMG_GENERIC			0
#define DMG_ACID			(1 << 20)


Handle SplashEnabled = INVALID_HANDLE;
Handle SplashDamageEasy = INVALID_HANDLE;
Handle SplashDamageNormal = INVALID_HANDLE;
Handle SplashDamageHard = INVALID_HANDLE;
Handle SplashDamageExpert = INVALID_HANDLE;
Handle DisplayDamageMessage = INVALID_HANDLE;
bool IsSwappingTeam[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "胖子爆炸伤害",
	author = " AtomicStryker, Axel Juan Nieves",
	description = "Left 4 Dead Boomer Splash Damage",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=98794"
}

int g_iSlotAbility;
int g_iLevelSplash[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_team", PlayerTeam);
	HookEvent("player_now_it", event_player_now_it);
	
	CreateConVar("l4d_splash_damage_version", PLUGIN_VERSION, " Version of L4D Boomer Splash Damage on this server ", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	SplashEnabled = CreateConVar("l4d_splash_damage_enabled", "1", " Enable/Disable the Splash Damage plugin ", CVAR_FLAGS);
	SplashDamageEasy = CreateConVar("l4d_splash_damage_dmg_easy", "5.0", " Amount of damage the Boomer Explosion deals in easy difficulty", CVAR_FLAGS);
	SplashDamageNormal = CreateConVar("l4d_splash_damage_dmg_normal", "10.0", " Amount of damage the Boomer Explosion deals in normal difficulty", CVAR_FLAGS);
	SplashDamageHard = CreateConVar("l4d_splash_damage_dmg_hard", "15.0", " Amount of damage the Boomer Explosion deals in hard difficulty", CVAR_FLAGS);
	SplashDamageExpert = CreateConVar("l4d_splash_damage_dmg_expert", "20.0", " Amount of damage the Boomer Explosion deals in expert difficulty", CVAR_FLAGS);
	DisplayDamageMessage = CreateConVar("l4d_splash_damage_notification", "0", " 0 - Disabled; 1 - small HUD Hint; 2 - big HUD Hint; 3 - Chat Notification ", CVAR_FLAGS);
	
	AutoExecConfig(true, "l4d_splash_damage");
	LoadTranslations("l4d_splash_damage.phrases");
	
	LoadTranslations("l4d2sf_splash_damage.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotAbility = L4D2SF_RegSlot("ability");
	L4D2SF_RegPerk(g_iSlotAbility, "splash_damage", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "splash_damage"))
		FormatEx(result, maxlen, "%T", "爆炸伤害", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "splash_damage"))
		FormatEx(result, maxlen, "%T", tr("爆炸伤害%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "splash_damage"))
		g_iLevelSplash[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelSplash[client] = L4D2SF_GetClientPerk(client, "splash_damage");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelSplash[client] = L4D2SF_GetClientPerk(client, "splash_damage");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void PlayerTeam(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( !IsValidClientInGame(client) ) return;
	
	IsSwappingTeam[client] = true;
	CreateTimer(2.0, EraseGhostExploit, client);
}

public void event_player_now_it(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if ( !GetConVarInt(SplashEnabled) ) return;
	if ( !IsValidClientInGame(client) || g_iLevelSplash[client] < 1 ) return;
	if ( GetClientTeam(client) != TEAM_SURVIVOR) return;
	if ( !IsPlayerAlive(client) ) return;
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	char z_difficulty[16];
	GetConVarString(FindConVar("z_difficulty"), z_difficulty, sizeof(z_difficulty));
	
	switch ( GetConVarInt(DisplayDamageMessage) )
	{
		case 1:
			PrintCenterText(client, "%t", "splash_dmg");
		
		case 2:
			PrintHintText(client, "%t", "splash_dmg");
		
		case 3:
			PrintToChat(client, "\x03[SPASH DAMAGE]:\x01 %t", "splash_dmg");
	}
	
	/*
	if ( StrEqual(z_difficulty, "Normal", false) )
		DealDamage(client, GetConVarInt(SplashDamageNormal), attacker, DMG_ACID);
	else if ( StrEqual(z_difficulty, "Hard", false) )
		DealDamage(client, GetConVarInt(SplashDamageHard), attacker, DMG_ACID);
	else if ( StrEqual(z_difficulty, "Expert", false) )
		DealDamage(client, GetConVarInt(SplashDamageExpert), attacker, DMG_ACID);
	else if ( StrEqual(z_difficulty, "Impossible", false) )
		DealDamage(client, GetConVarInt(SplashDamageExpert), attacker, DMG_ACID);
	else
		DealDamage(client, GetConVarInt(SplashDamageEasy), attacker, DMG_ACID);
	*/
	
	DealDamage(client, GetConVarInt(SplashDamageNormal), attacker, DMG_ACID);
}

stock void DealDamage(int victim, int damage, int attacker=0, int dmg_type=DMG_GENERIC, char[] weapon="")
{
	if ( !IsValidClientInGame(victim) ) return;
	if ( !IsPlayerAlive(victim) ) return;
	if ( damage<=0 ) return;
	
	char dmg_str[16];
	IntToString(damage, dmg_str, 16);
	char dmg_type_str[32];
	IntToString(dmg_type, dmg_type_str, 32);
	int pointHurt = CreateEntityByName("point_hurt");
	if (!pointHurt) return;
	
	DispatchKeyValue(victim, "targetname", "war3_hurtme");
	DispatchKeyValue(pointHurt, "DamageTarget", "war3_hurtme");
	DispatchKeyValue(pointHurt, "Damage", dmg_str);
	DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
	if(!StrEqual(weapon,""))
		DispatchKeyValue(pointHurt, "classname", weapon);
	
	DispatchSpawn(pointHurt);
	AcceptEntityInput(pointHurt, "Hurt", (attacker>0)?attacker:-1);
	DispatchKeyValue(pointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "war3_donthurtme");
	RemoveEdict(pointHurt);
}

public Action EraseGhostExploit(Handle timer, any client)
{	
	IsSwappingTeam[client] = false;
	return Plugin_Handled;
}

stock int IsValidClientInGame(int client)
{
	if (IsValidClientIndex(client))
	{
		if (IsClientInGame(client))
			return 1;
	}
	return 0;
}

stock int IsValidClientIndex(int index)
{
	if (index>0 && index<=MaxClients)
	{
		return 1;
	}
	return 0;
}