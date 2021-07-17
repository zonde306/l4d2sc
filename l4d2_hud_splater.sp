#define PLUGIN_VERSION		"1.2"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Hud Splatter
*	Author	:	SilverShot
*	Descp	:	Splat effects on players screen.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=137445
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (10-May-2020)
	- Added PrecacheParticle function.
	- Various changes to tidy up code.

1.1 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.0 (05-Sep-2010)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "L. Duke" for " TF2 Particles via TempEnts" tutorial
	https://forums.alliedmods.net/showthread.php?t=75102

*	Thanks to "Muridias" for updating "L. Duke"s code
	https://forums.alliedmods.net/showpost.php?p=836836&postcount=28

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

char g_Particles[19][] =
{
	"screen_adrenaline",					//Adrenaline
	"screen_adrenaline_b",
	"screen_hurt",
	"screen_hurt_b",
	"screen_blood_splatter",				//Blood
	"screen_blood_splatter_a",
	"screen_blood_splatter_b",
	"screen_blood_splatter_melee_b",
	"screen_blood_splatter_melee",
	"screen_blood_splatter_melee_blunt",
	"smoker_screen_effect",					//Infected
	"smoker_screen_effect_b",
	"screen_mud_splatter",
	"screen_mud_splatter_a",
	"screen_bashed",						//Misc
	"screen_bashed_b",
	"screen_bashed_d",
	"burning_character_screen",
	"storm_lightning_screenglow"
};

ConVar g_hEnable;
bool g_bCvarAllow;
int g_iType;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2] Hud Splatter",
	author = "SilverShot",
	description = "Splat effects on players screen.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=137445"
}

public void OnPluginStart()
{
	// Cvars
	g_hEnable = CreateConVar("l4d2_hud_splatter", "1", "0=Disables plugin, 1=Enables plugin", FCVAR_NOTIFY);
	AutoExecConfig(true, "l4d2_hud_splatter");

	g_hEnable.AddChangeHook(ConVarChanged_Enable);
	g_bCvarAllow = g_hEnable.BoolValue;

	// Console Commands
	RegConsoleCmd("sm_splat_menu", Command_SplatMenu, "Splat menu.", ADMFLAG_KICK);
	RegConsoleCmd("sm_splat", Command_Splatter, "Usage: sm_splat [1-19]", ADMFLAG_KICK);
}

public void ConVarChanged_Enable(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_bCvarAllow = g_hEnable.BoolValue;
}

public void OnMapStart()
{
	for( int i = 0; i < sizeof(g_Particles); i++ )
	{
		PrecacheParticle(g_Particles[i]);
	}
}



// ====================================================================================================
//					COMMAND
// ====================================================================================================
void SplatPlayer(int client, int type)
{
	AttachParticle(client, g_Particles[type]);
}

public Action Command_SplatMenu(int client, int args)
{
	if( g_bCvarAllow ) Menu_Select(client);
	return Plugin_Handled;
}

public Action Command_Splatter(int client, int args)
{
	if( !g_bCvarAllow ) return Plugin_Handled;

	char arg1[4];
	int type;

	GetCmdArg(1, arg1, sizeof(arg1));

	if( args != 1 )
	{
		ReplyToCommand(client, "Usage: sm_splat [1-19]");
		return Plugin_Handled;
	}

	type = StringToInt(arg1);
	if( type < 0 || type > 19)  return Plugin_Handled;
	SplatPlayer(client, type -1);

	return Plugin_Handled;
}



// ====================================================================================================
//					MENU HANDLER
// ====================================================================================================
// 1. Menu_Select
void Menu_Select(int client)
{
	Menu menu = new Menu(MenuHandler_Select);
	menu.SetTitle("Select Splatter:");

	menu.AddItem("1", "Adrenaline");
	menu.AddItem("2", "Blood");
	menu.AddItem("3", "Infected");
	menu.AddItem("4", "Miscellaneous");

	menu.ExitButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_Select(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_End ) return;

	if( action == MenuAction_Select )
	{
		switch( param2 )
		{
			case 0: Menu_Adren(param1);
			case 1: Menu_Blood(param1);
			case 2: Menu_Infected(param1);
			case 3: Menu_Misc(param1);
		}
	}
}



// ====================================================================================================
//					BUILD MENUS
// ====================================================================================================
// Adrenaline
void Menu_Adren(int client)
{
	Menu menu = new Menu(MenuHandler_Adren);
	menu.SetTitle("Adrenaline Edges");

	menu.AddItem("1", "Adrenaline (red)");
	menu.AddItem("2", "Adrenaline (dark)");
	menu.AddItem("3", "Hurt (red)");
	menu.AddItem("4", "Hurt (dark)");

	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_Adren(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		Menu_Select(param1);
	}
	else if( action == MenuAction_Select )
	{
		g_iType = param2;
		Menu_Adren(param1);
		SplatPlayer(param1, g_iType);
	}
}

// Blood
void Menu_Blood(int client)
{
	Menu menu = new Menu(MenuHandler_Blood);
	menu.SetTitle("Blood Splatter");

	menu.AddItem("1", "Edge Faded");
	menu.AddItem("2", "Center Big");
	menu.AddItem("3", "Center Small");
	menu.AddItem("4", "Center (melee)");
	menu.AddItem("5", "Edge Big (melee)");
	menu.AddItem("6", "Edge Small (melee)");

	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_Blood(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		Menu_Select(param1);
	}
	else if( action == MenuAction_Select )
	{
		g_iType = param2 + 4;
		Menu_Blood(param1);
		SplatPlayer(param1, g_iType);
	}
}

// Infected
void Menu_Infected(int client)
{
	Menu menu = new Menu(MenuHandler_Infected);
	menu.SetTitle("Infected");

	menu.AddItem("1", "Water (Smoker FX)");
	menu.AddItem("2", "Flakes (Smoker FX)");
	menu.AddItem("3", "Mud Splatter 1");
	menu.AddItem("4", "Mud Splatter 2");

	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_Infected(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		Menu_Select(param1);
	}
	else if( action == MenuAction_Select )
	{
		g_iType = param2 + 10;
		Menu_Infected(param1);
		SplatPlayer(param1, g_iType);
	}
}

// Misc
void Menu_Misc(int client)
{
	Menu menu = new Menu(MenuHandler_Misc);
	menu.SetTitle("Miscellaneous");

	menu.AddItem("1", "Big Bash");
	menu.AddItem("2", "Bashed");
	menu.AddItem("3", "Stars");
	menu.AddItem("4", "Flames");
	menu.AddItem("5", "Lightning Flash");

	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

public int MenuHandler_Misc(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		Menu_Select(param1);
	}
	else if( action == MenuAction_Select )
	{
		g_iType = param2 + 14;
		Menu_Misc(param1);
		SplatPlayer(param1, g_iType);
	}
}



// ====================================================================================================
//					PARTICLES
// ====================================================================================================
void AttachParticle(int client, char[] particleType)
{
    int entity = CreateEntityByName("info_particle_system");

    if( IsValidEdict(entity) )
    {
		DispatchKeyValue(entity, "effect_name", particleType);
		DispatchSpawn(entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);

		ActivateEntity(entity);
		AcceptEntityInput(entity, "start");

		SetVariantString("OnUser1 !self:Kill::10.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
    }
}

int PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	int index = FindStringIndex(table, sEffectName);
	if( index == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
		index = FindStringIndex(table, sEffectName);
	}

	return index;
}