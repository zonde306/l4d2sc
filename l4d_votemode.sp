#define PLUGIN_VERSION		"1.2"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Vote Mode
*	Author	:	SilverShot
*	Descrp	:	Allows players to vote change the game mode. Admins can force change the game mode.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=179279
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (10-May-2012)
	- Fixed votes potentially not displaying to everyone.

1.0 (28-Feb-2012)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "N3wton" for "[L4D2] Pause" - Used to make the voting system.
	http://forums.alliedmods.net/showthread.php?t=137765

*	Thanks to "chundo" for "Custom Votes" - Used to load the config via SMC Parser.
	http://forums.alliedmods.net/showthread.php?p=633808

*	Thanks to "Rayman1103" for the "All Mutations Unlocked" addon.
	http://forums.steampowered.com/forums/showthread.php?t=1529433

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>

#define CVAR_FLAGS				FCVAR_NOTIFY
#define CHAT_TAG				"\x04[\x01Vote Mode\x04]\x01 "
#define CONFIG_VOTEMODE			"data/l4d_votemode.cfg"


// Cvar handles and variables
ConVar g_hCvarAdmin, g_hCvarMenu, g_hCvarRestart, g_hCvarTimeout;
int g_iCvarAdmin, g_iCvarRestart;
float g_fCvarTimeout;

// Other handles
ConVar g_hCvarMPGameMode, g_hRestartGame;
TopMenu g_hCvarMenuMenu;

// Voting variables
bool g_bAllVoted, g_bVoteInProgress;
int g_iNoCount, g_iVoters, g_iYesCount;

// Distinguishes mode selected and if admin forced
bool g_bAdmin[MAXPLAYERS+1];
int g_iChangeModeTo, g_iSelected[MAXPLAYERS+1];

// Strings to hold the gamemodes and titles
char g_sModeCommands[256][64], g_sModeNames[256][64], g_sModeTitles[256][64];

// Store where the different titles are within the commands list
int g_iConfigCount, g_iConfigLevel, g_iModeIndex[64];



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Vote Mode",
	author = "SilverShot",
	description = "Allows players to vote change the game mode. Admins can force change the game mode.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=179279"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	if( (g_hCvarMPGameMode = FindConVar("mp_gamemode")) == null )
		SetFailState("Failed to find convar handle 'mp_gamemode'. Cannot load plugin.");

	if( (g_hRestartGame = FindConVar("mp_restartgame")) == null )
		SetFailState("Failed to find convar handle 'mp_restartgame'. Cannot load plugin.");

	LoadTranslations("votemode.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	g_hCvarMenu =		CreateConVar(	"l4d_votemode_admin_menu",		"1", 			"0=No, 1=Display in the Server Commands of admin menu.", CVAR_FLAGS );
	g_hCvarAdmin =		CreateConVar(	"l4d_votemode_admin_flag",		"", 			"Players with these flags can vote to change the game mode.", CVAR_FLAGS );
	g_hCvarRestart =	CreateConVar(	"l4d_votemode_restart",			"1",			"0=No restart, 1=With 'changelevel' command, 2=Restart map with 'mp_restartgame' cvar.", CVAR_FLAGS );
	g_hCvarTimeout =	CreateConVar(	"l4d_votemode_timeout",			"30.0",			"How long the vote should be visible.", CVAR_FLAGS, true, 5.0, true, 60.0 );
	CreateConVar(						"l4d_votemode_version",			PLUGIN_VERSION, "Vote Mode plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true, 				"l4d_votemode");

	GetCvars();
	g_hCvarAdmin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRestart.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd(	"sm_vetomode",		CommandVeto,	ADMFLAG_ROOT,	"Allows admins to veto a current vote.");
	RegAdminCmd(	"sm_passmode",		CommandPass,	ADMFLAG_ROOT,	"Allows admins to pass a current vote.");
	RegAdminCmd(	"sm_forcemode",		CommandForce,	ADMFLAG_ROOT,	"Allows admins to force the game into a different mode.");
	RegConsoleCmd(	"sm_votemode",		CommandVote,					"Displays a menu to vote the game into a different mode.");

	Handle topmenu = GetAdminTopMenu();
	if( LibraryExists("adminmenu") && (topmenu != null) )
		OnAdminMenuReady(topmenu);

	LoadConfig();
}



// ====================================================================================================
//					ADD TO ADMIN MENU
// ====================================================================================================
public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "adminmenu") == 0 )
		g_hCvarMenuMenu = null;
}

public void OnAdminMenuReady(Handle topmenu)
{
	if( topmenu == g_hCvarMenuMenu || g_hCvarMenu.BoolValue == false )
		return;

	g_hCvarMenuMenu = view_as<TopMenu>(topmenu);

	TopMenuObject player_commands = FindTopMenuCategory(g_hCvarMenuMenu, ADMINMENU_SERVERCOMMANDS);
	if( player_commands == INVALID_TOPMENUOBJECT ) return;

	AddToTopMenu(g_hCvarMenuMenu, "sm_forcemode_menu", TopMenuObject_Item, Handle_Category, player_commands, "sm_forcemode_menu", ADMFLAG_GENERIC);
}

public int Handle_Category(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch( action )
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "%T", "VoteMode_Force", param);
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "VoteMode_Force", param);
		case TopMenuAction_SelectOption:
		{
			g_bAdmin[param] = true;
			VoteMenu_Select(param);
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sTemp[16];
	g_hCvarAdmin.GetString(sTemp, sizeof(sTemp));
	g_iCvarAdmin = ReadFlagString(sTemp);
	g_iCvarRestart = g_hCvarRestart.IntValue;
	g_fCvarTimeout = g_hCvarTimeout.FloatValue;
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
void LoadConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_VOTEMODE);

	if( !FileExists(sPath) )
	{
		SetFailState("Error: Cannot find the Votemode config '%s'", sPath);
		return;
	}

	ParseConfigFile(sPath);
}

bool ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);
	delete parser;

	if( result != SMCError_Okay )
	{
		SMC_GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	// Section strings, used for the first menu ModeTitles
	g_iConfigLevel++;
	if( g_iConfigLevel > 1 )
	{
		strcopy(g_sModeTitles[g_iConfigLevel -2], 64, section);
		g_iModeIndex[g_iConfigLevel -2] = g_iConfigCount;
	}
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// Key and value strings, used for the ModeNames and ModeCommands
	strcopy(g_sModeNames[g_iConfigCount], 64, key);
	strcopy(g_sModeCommands[g_iConfigCount], 64, value);
	g_iConfigCount++;
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	// Config finished loading
	g_iModeIndex[g_iConfigLevel -1] = g_iConfigCount;
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Votemode config.");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CommandVeto(int client, int args)
{
	if( g_bAllVoted == false && g_bVoteInProgress == true )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SetGlobalTransTarget(i);
				PrintToChat(i, "%s%T", CHAT_TAG, "VoteMode_Veto", client);
			}
		}
	}

	g_bAllVoted = true;
	g_bVoteInProgress = false;
	return Plugin_Handled;
}

public Action CommandPass(int client, int args)
{
	if( g_bAllVoted == false && g_bVoteInProgress == true )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SetGlobalTransTarget(i);
				PrintToChat(i, "%s%t", CHAT_TAG, "VoteMode_Pass");
			}
		}

		g_bAllVoted = true;
		g_bVoteInProgress = false;

		ChangeGameModeTo(g_iChangeModeTo);
	}
	return Plugin_Handled;
}

public Action CommandForce(int client, int args)
{
	if( args == 1 )
	{
		char sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		for( int i = 0; i < g_iConfigCount; i++ )
		{
			if( strcmp(g_sModeCommands[i], sTemp, false) == 0 )
			{
				ChangeGameModeTo(i);
				return Plugin_Handled;
			}
		}
	}

	g_bAdmin[client] = true;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

public Action CommandVote(int client, int args)
{
	// Admins only
	if( CheckCommandAccess(client, "", g_iCvarAdmin) == false )
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	// Don't allow multiple votes
	if( g_bVoteInProgress )
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_InProgress");
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		char sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		for( int i = 0; i < g_iConfigCount; i++ )
		{
			if( strcmp(g_sModeCommands[i], sTemp, false) == 0 )
			{
				StartVote(client, i);
				return Plugin_Handled;
			}
		}
	}

	g_bAdmin[client] = false;
	VoteMenu_Select(client);
	return Plugin_Handled;
}



// ====================================================================================================
//					DISPLAY MENU
// ====================================================================================================
void VoteMenu_Select(int client)
{
	Menu menu = new Menu(VoteMenuHandler_Select);
	if( g_bAdmin[client] )
		menu.SetTitle("%T", "VoteMode_Force", client);
	else
		menu.SetTitle("%T", "VoteMode_Vote", client);

	// Build menu
	for( int i = 0; i < g_iConfigLevel -1; i++ )
		menu.AddItem("", g_sModeTitles[i]);

	// Display menu
	if( g_bAdmin[client] )
		menu.ExitBackButton = true;
	else
		menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuHandler_Select(Menu menu, MenuAction action, int client, int param2)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack && g_bAdmin[client] && g_hCvarMenuMenu != null )
				g_hCvarMenuMenu.Display(client, TopMenuPosition_LastCategory); //TopMenuPosition_Start
		}
		case MenuAction_Select:
		{
			g_iSelected[client] = param2;
			VoteTwoMenu_Select(client, param2);
		}
	}
}

void VoteTwoMenu_Select(int client, int param2)
{
	Menu menu = new Menu(VoteMenuTwoMenur_Select);
	if( g_bAdmin[client] )
		menu.SetTitle("%T", "VoteMode_Force", client);
	else
		menu.SetTitle("%T", "VoteMode_Vote", client);

	// Build menu
	int param1 = g_iModeIndex[param2];
	param2 = g_iModeIndex[param2 +1];

	for (int i = param1; i < param2; i++)
		menu.AddItem("", g_sModeNames[i]);

	// Display menu
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuTwoMenur_Select(Menu menu, MenuAction action, int client, int param2)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack )
				VoteMenu_Select(client);
		}
		case MenuAction_Select:
		{
			// Work out the mode command index
			int iSelected;
			iSelected = g_iSelected[client];
			iSelected = g_iModeIndex[iSelected];
			iSelected += param2;

			// Admin force
			if( g_bAdmin[client] )
				ChangeGameModeTo(iSelected);
			else
				StartVote(client, iSelected);
		}
	}
}



// ====================================================================================================
//					VOTING STUFF
// ====================================================================================================
void StartVote(int client, int iMode)
{
	// Don't allow multipule votes
	if( g_bVoteInProgress )
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_InProgress");
		return;
	}

	// Setup vote
	g_iYesCount = 0;
	g_iNoCount = 0;
	g_iVoters = 0;
	g_bAllVoted = false;
	g_bVoteInProgress = true;
	g_iChangeModeTo = iMode;

	char sTitle[128];
	Panel panel;

	// Display vote
	for (int i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
			panel = new Panel();
			SetGlobalTransTarget(i);

			Format(sTitle, sizeof(sTitle), "%T %s?", "VoteMode_Change", i, g_sModeNames[iMode]);
			panel.SetTitle(sTitle);
			Format(sTitle, sizeof(sTitle), "%T", "Yes", i);
			panel.DrawItem(sTitle);
			Format(sTitle, sizeof(sTitle), "%T", "No", i);
			panel.DrawItem(sTitle);

			Format(sTitle, sizeof(sTitle), "%s", g_sModeNames[iMode]);
			PrintToChat(i, "%s\x05%N \x01%t \x04%s?", CHAT_TAG, client, "VoteMode_Started", sTitle);

			panel.Send(i, VoteMenuHandler, RoundToCeil(g_fCvarTimeout));
			g_iVoters++;
			g_iNoCount++;
			delete panel;
		}
	}

	CreateTimer(g_fCvarTimeout + 1.0, Timer_VoteCheck);
}

public int VoteMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if( action == MenuAction_Select )
	{
		if(choice == 1) //yes
		{
			g_iNoCount--;
			g_iYesCount++;
			g_iVoters--;
		}
		else //No
			g_iVoters--;

		if( g_iVoters == 0 ) //Everyone Has Voted
			VoteCompleted();
	}
}

public Action Timer_VoteCheck(Handle timer)
{
	if( !g_bAllVoted )
		VoteCompleted();
}

void VoteCompleted()
{
	if( g_bAllVoted == true && g_bVoteInProgress == false ) return;

	g_bAllVoted = true;
	g_bVoteInProgress = false;

	if( g_iYesCount > g_iNoCount )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SetGlobalTransTarget(i);
				PrintToChat(i, "%s'%t' %t", CHAT_TAG, "Yes", "VoteMode_Voted");
			}
		}
		ChangeGameModeTo(g_iChangeModeTo);
	}
	else
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SetGlobalTransTarget(i);
				PrintToChat(i, "%s'%t' %t", CHAT_TAG, "No", "VoteMode_Voted");
			}
		}
	}
}



// ====================================================================================================
//					SET GAME MODE
// ====================================================================================================
void ChangeGameModeTo(int type)
{
	CreateTimer(3.0, tmrChangeMode, type);

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			SetGlobalTransTarget(i);
			PrintToChat(i, "%s%t \x04%s.", CHAT_TAG, "VoteMode_Changing", g_sModeNames[type]);
			PrintToChat(i, "%s%t", CHAT_TAG, "VoteMode_Restarting");
		}
	}
}

public Action tmrChangeMode(Handle timer, any i)
{
	g_hCvarMPGameMode.SetString(g_sModeCommands[i]);

	if( g_iCvarRestart == 1 )
	{
		char sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));
		ServerCommand("changelevel %s", sTemp);
	}
	else if( g_iCvarRestart == 2 )
	{
		g_hRestartGame.IntValue = 1;
		CreateTimer(0.1, tmrRestartGame);
	}
}

public Action tmrRestartGame(Handle timer)
{
	g_hRestartGame.IntValue = 1;
}