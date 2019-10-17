#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Melee Range
*	Author	:	SilverShot
*	Descrp	:	Adjustable melee range for each melee weapon.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=318958
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (03-Oct-2019)
	- Increased string size to fix the plugin not working. Thanks to "xZk" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2_simple_combat>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define	MAX_MELEE			11
#define WEAPON_RADIUS		(1.0 + ((SC_GetClientLevel(client) / 10) * 0.15))

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarMeleeRange, g_hCvarRange[MAX_MELEE];
bool g_bCvarAllow;
int g_iFrameCount;
int g_iStockRange;

char g_sScripts[MAX_MELEE][] =
{
	"baseball_bat",
	"cricket_bat",
	"crowbar",
	"electric_guitar",
	"fireaxe",
	"frying_pan",
	"golfclub",
	"katana",
	"knife",
	"machete",
	"tonfa"
	// "riotshield"
};



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "近战武器攻击范围",
	author = "SilverShot",
	description = "Adjustable melee range for each melee weapon.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318958"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarAllow = CreateConVar(		"l4d2_melee_range_allow",					"1",			"是否开启插件", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d2_melee_range_modes",					"",				"开启插件的模式.空=全部", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d2_melee_range_modes_off",				"",				"关闭插件的模式.空=没有", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_melee_range_modes_tog",				"0",			"开启插件的模式. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge.", CVAR_FLAGS );
	g_hCvarRange[0] = CreateConVar(		"l4d2_melee_range_weapon_baseball_bat",		"100",			"棒球棒攻击范围", CVAR_FLAGS );
	g_hCvarRange[1] = CreateConVar(		"l4d2_melee_range_weapon_cricket_bat",		"100",			"船桨攻击范围", CVAR_FLAGS );
	g_hCvarRange[2] = CreateConVar(		"l4d2_melee_range_weapon_crowbar",			"90",			"撬棍攻击范围", CVAR_FLAGS );
	g_hCvarRange[3] = CreateConVar(		"l4d2_melee_range_weapon_electric_guitar",	"150",			"吉他攻击范围", CVAR_FLAGS );
	g_hCvarRange[4] = CreateConVar(		"l4d2_melee_range_weapon_fireaxe",			"130",			"消防斧攻击范围", CVAR_FLAGS );
	g_hCvarRange[5] = CreateConVar(		"l4d2_melee_range_weapon_frying_pan",		"70",			"平底锅攻击范围", CVAR_FLAGS );
	g_hCvarRange[6] = CreateConVar(		"l4d2_melee_range_weapon_golfclub",			"140",			"高尔夫球棍攻击范围", CVAR_FLAGS );
	g_hCvarRange[7] = CreateConVar(		"l4d2_melee_range_weapon_katana",			"140",			"武士刀攻击范围", CVAR_FLAGS );
	g_hCvarRange[8] = CreateConVar(		"l4d2_melee_range_weapon_knife",			"70",			"小刀攻击范围", CVAR_FLAGS );
	g_hCvarRange[9] = CreateConVar(		"l4d2_melee_range_weapon_machete",			"120",			"开山刀攻击范围", CVAR_FLAGS );
	g_hCvarRange[10] = CreateConVar(	"l4d2_melee_range_weapon_tonfa",			"120",			"警棍攻击范围", CVAR_FLAGS );
	CreateConVar(						"l4d2_melee_range_version",					PLUGIN_VERSION,	"插件版本", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_melee_range");

	g_hCvarMeleeRange = FindConVar("melee_range");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	
	CreateTimer(1.0, Timer_SkillRegister);
}

public Action Timer_SkillRegister(Handle timer, any unused)
{
	SC_CreateSkill("sl_melee_range", "近战攻击范围", 0, "近战武器攻击范围增加");
	return Plugin_Continue;
}

public Action SC_OnSkillGetInfo(int client, const char[] classname,
	char[] display, int displayMaxLength, char[] description, int descriptionMaxLength)
{
	if(StrEqual(classname, "sl_melee_range", false))
		FormatEx(description, descriptionMaxLength, "近战武器攻击范围 ＋%.2f％", (WEAPON_RADIUS - 1.0) * 100);
	else
		return Plugin_Continue;
	
	return Plugin_Changed;
}

// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		HookEvent("weapon_fire", Event_WeaponFire);
		g_iStockRange = g_hCvarMeleeRange.IntValue;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		UnhookEvent("weapon_fire", Event_WeaponFire);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}

// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	char sTemp[16];
	event.GetString("weapon", sTemp, sizeof sTemp);

	if( sTemp[0] == 'm' && sTemp[1] == 'e' && sTemp[2] == 'l' )
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if( client && IsClientInGame(client) )
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if( weapon != -1 )
			{
				GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof sTemp);

				for( int i = 0; i < MAX_MELEE; i++ )
				{
					if( strcmp(sTemp, g_sScripts[i]) == 0 )
					{
						if( !g_iFrameCount )
						{
							g_iFrameCount = 1;
							
							if(SC_IsClientHaveSkill(client, "sl_melee_range"))
								SetConVarInt(g_hCvarMeleeRange, RoundToCeil(g_hCvarRange[i].IntValue * WEAPON_RADIUS));
							else
								SetConVarInt(g_hCvarMeleeRange, g_hCvarRange[i].IntValue);
							
							RequestFrame(OnNextFrame);
						}
						break;
					}
				}
			}
		}
	}
}

public void OnNextFrame(int na)
{
	if( g_iFrameCount++ <= 5 ) // 5 frames.
	{
		RequestFrame(OnNextFrame);
	} else {
		SetConVarInt(g_hCvarMeleeRange, g_iStockRange);
		g_iFrameCount = 0;
	}
}