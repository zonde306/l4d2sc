#define PLUGIN_VERSION "1.13"

#pragma newdecls required
#pragma semicolon 1

#define DEBUG 0

#include <sourcemod>
#include <geoip>

#define MAXLENGTH_MESSAGE		128
#define MAX_CVAR_NAME_LENGTH	100
#define MAX_EXCLUDE_CMD_LENGTH	16
#define CVAR_FLAGS				FCVAR_NOTIFY

#if DEBUG
	#pragma tabsize 0
	#define DBG(%0) DBG_Print(%0);
#else
	#define DBG(%0)
#endif

#define CMD_EXCLUSION_PATH 	"data/sm_eater_exclude.txt"
#define CMD_UNKNOWN_PATH	"logs/cmd_unknown.log"
#define DEBUG_LOG_PATH 		"logs/cmd_eater_debug.log"

enum // CMDType
{
	CMDType_Plain 		= 1,
	CMDType_SM 			= 2,
	CMDType_Exclusion 	= 4,
	CMDType_Game		= 8
}

enum // TriggerType
{
	TriggerType_Public,
	TriggerType_Silent
}

public Plugin myinfo =
{
    name = "聊天命令接收器",
    author = "Dragokas",
    description = "Allows to accept commands entered in chat in uppercase or cyrillic",
    version = PLUGIN_VERSION,
    url = "https://github.com/dragokas"
}

/*
	Credits:
	
	- SilverShot - for "Commands enumerator" code and SMC Parser example.
	- hmmmmm - for solution to my new debug code style
	- Bacardi - for suggesting me ReadCommandIterator() to differentiate sm commands.
	- Balimbanana - for suggesting me OnClientCommand() to catch unrecognized console commands.
	
	Compatible with:
	
	- Simple Chat Processor (Redux) by Mini (minimoney1).
	- Chat processor by Keith Warren (Shaders Allen).
	
	Limitations:
	- Listen servers are limited to "eat" the chat only, "eating" the console will not work there, use Dedicated server.
	- You cannot compile it with SM v.1.11. Wait for sourcepawn parser fix: https://github.com/alliedmodders/sourcepawn/issues/471
	
	Changelog:
	
	1.0 (18-Nov-2019)
	 - First release
	 
	1.1 (20-Nov-2019)
	 - Added ability to log unknown commands to logs/cmd_unknown.log (identical commands will not be repeated in log)
	 
	1.2 (20-Dec-2019)
	 - Fixed bug: color tag is not parsed
	 - Added ability to remove <chat-processor> dependency with reduced functionality (by SilverShot request).
	To make so, change #define USE_CHAT_PROCESSOR to 0 and recompile the plugin.
	
	1.3 (20-Dec-2019)
	 - Extended debug version
	
	1.4 (28-Dec-2019)
	 - (dot) .command is now alias to /command, so you can write commands beginning with . (dot)
	 - Added "sm_eater_nokey_allow" ConVar - ability to enter commands without prepending key trigger at all, e.g. ADMIN, not !ADMIN (1 - Enable, 0 - Disable, for better performance).
	 - Added "sm_eater_nokey_silent" ConVar - Commands entered without key trigger should be silent? (1 - Yes / 0 - No).
	 - "sm_unknown_logging" ConVar is renamed to "sm_eater_unknown_logging" to follow naming convention better.
	 - Added "Simple Chat Processor (Redux)" support. No need to re-compile the plugin. Processor is detected automatically.
	 Note: remove chat-processor.smx from server if you don't use it anymore.
	 - Chat processors are stored now in separate "Chat_Processors" folder (use it just in emergency case, e.g. when source code is lost or new version break compatibility...).
	 - Fixed color tag bug caused by dependency on plugins load order.
	 - potential fix: multiple starting color tags are supported now.
	 - unknown command is logged now without normalization, exactly same as it was written by user.
	 - in case some problems still persist, you can enable extended debug by #define DEBUG 1 (will be written in "logs/cmd_eater_debug.log")
	 
	1.6 (12-Feb-2020)
	
	Features:
	 - Added support for !sm_ /sm_ sm_ prefixes entered in chat, including misprinted (wrong letter case and cyrillic).
	 - Added "sm_eater_enable" ConVar - to disable plugin in runtime (just in case).
	 - Added "sm_eater_eat_cyrillic" ConVar instead of "#define EAT_CYRILLIC".
	 - Added "sm_eater_nokey_minlength" ConVar to decrease false positives.
	 You can define here minimal length of command (entered without key trigger "!","/") allowed to be handled by "eater". By default: 2.
	 
	 - added commands exclusion file: "addons/sourcemod/data/sm_eater_exclude.txt":
	 enter each command on the new line you may want to exclude from handling by this plugin to prevent false positives.
	 
	 - now, unknown commands are not checked for duplicates anymore (useless thing). Instead, player name, steamid, country, ip are prepended in log.
	 - "eater" is now handling ALL in-game commands, registered with sm_ and without. However, YOU can "misprint" them using any variant.
	 
	 Other:
	 - New dependency: <geoip>
	 - RegConsoleCmd() replaced by AddCommandListener() to handle it in correct way and order.
	 - Fixed missing CloseHandle of commands enumerator (not critical).
	 - Fixed missing ConVar version notify flag.
	 - fixed cmd-arg parser is not worked properly with multiple tags of color specified.
	 - Added additional check preventing "say" / "say_team" commands to be registered twice.
	 - Some simplifications and optimizations:
		* thanks to hmmmmm for helping with my new debug code style.
		* thanks to SilverShot for profiler sample.
	 
	1.7 (15-Feb-2020)
	 - FakeClientCommand() is replaced by -Ex variant to prevent beeing networked and fix further issues with some recurse reported.
	
	1.8 (16-Feb-2020)
	 - Some optimizations (thanks to Crasher for remark).
	 - Replicate GetCmdReplySource() to allow plugins understand that command came from chat (thanks to Ilusion9 for solution).
	 - appended some debugging code.
	 - fixed some mistakes with "." prefix trigger.
	 
	1.9 (17-Feb-2020)
	 - prevented very strange bug with chat procesor when he duplicates forward calling multiple times (skip flood coming < 300 ms.).
	 - Added "sm_eater_ignore_chat_proc" ConVar - set 1 if you want ignore handling messages coming from chat processor and use 'say' hook instead (just in case some problems still persists).
	
	1.11 (18-Feb-2020)
	 - Added support for multiple (or empty) defined chat triggers in core.cfg.
	 - Fixed "sm_eater_nokey_minlength" ConVar incorrectly handled when calculated multi-byte characters.
	 
	1.12 (20-Apr-2020)
	 - Added a little delay before loading list of commands to support one loaded with a frame delay or so.
	 - Added reloading command list on map start to support commands registered with late loaded plugins.
	 
	1.13 (26-Apr-2020)
	 - Fixed false positives for default game commands, like "bind" when they are entered in chat (thanks for help to Bacardi).
	 - Added ability to "eat" console commands (thanks for help to Balimbanana):
		* New ConVar added "sm_eater_eat_console" - default: 1 - to enable "eating" commands entered in console.
	 - Added ability of reverse Russian transliteration (like replacing "шоп" => "shop", "админ" => "admin" ):
		* New ConVar added "sm_eater_transliteration" - default: 1 - allow to substitute English analogues for Russian letters.
*/

StringMap g_hMapCmds;

char g_sLog[PLATFORM_MAX_PATH];
char g_sCmdPrefix[2][16];

ConVar g_hCvarEnable;
ConVar g_hCvarLogUnkn;
ConVar g_hCvarNoKeyAllow;
ConVar g_hCvarNoKeySilent;
ConVar g_hCvarNoKeyMinLength;
ConVar g_hCvarEatConsole;
ConVar g_hCvarEatCyrillic;
ConVar g_hCvarEatTranslit;
ConVar g_hCvarIgnoreChatProc;

bool g_bLoadedLibKW;
bool g_bLoadedLibSCP;
bool g_bHookCmd;
bool g_bPluginsLoaded;
bool g_bEnabled;
bool g_bMapStarted;
//bool g_bSkipFrame;

float g_fLastTime[MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateConVar("sm_command_eater", PLUGIN_VERSION, "Plugin version", FCVAR_DONTRECORD | CVAR_FLAGS);
	
	g_hCvarEnable = CreateConVar(			"sm_eater_enable",				"1",		"Enable plugin? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarLogUnkn = CreateConVar(			"sm_eater_unknown_logging",		"1",		"Do you want to log not recognized commands? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarNoKeyAllow = CreateConVar(		"sm_eater_nokey_allow",			"1",		"Do you want ability to enter commands without prepending key trigger? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarNoKeySilent = CreateConVar(		"sm_eater_nokey_silent",		"0",		"Commands entered without key trigger should be silent? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarNoKeyMinLength = CreateConVar(	"sm_eater_nokey_minlength",		"2",		"Minimum allowed length of command entered without key trigger", CVAR_FLAGS );
	g_hCvarEatConsole = CreateConVar(		"sm_eater_eat_console",			"1",		"Enable 'eating' commands entered in console? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarEatCyrillic = CreateConVar(		"sm_eater_eat_cyrillic",		"1",		"Do we need handle cyrillic letters? (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarEatTranslit = CreateConVar(		"sm_eater_transliteration",		"1",		"Allow to substitute English analogues for Russian letters, e.g. админ -> admin (1 - Yes / 0 - No)", CVAR_FLAGS );
	g_hCvarIgnoreChatProc = CreateConVar(	"sm_eater_ignore_chat_proc",	"0",		"Ignore chat processor and intercept 'say' command instead? (1 - Yes / 0 - No)", CVAR_FLAGS );
	
	AutoExecConfig(true,				"sm_command_eater");
	
	char sCore[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sCore, sizeof(sCore), "configs/core.cfg");
	ParseCoreConfigFile(sCore);

	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), CMD_UNKNOWN_PATH);
	
																	DBG("prefix public: %s", g_sCmdPrefix[TriggerType_Public])
																	DBG("prefix silent: %s", g_sCmdPrefix[TriggerType_Silent])
	
	g_hMapCmds = new StringMap();
	
	g_hCvarEnable.AddChangeHook(CVar_Changed);
	g_hCvarIgnoreChatProc.AddChangeHook(CVar_Changed);
	GetCvars();
	
	//if (g_bLateLoad) // no late check need since plugin can be loaded after chat processor, so OnLibraryAdded() does not fire.
	{
		g_bLoadedLibSCP = LibraryExists("scp");
		g_bLoadedLibKW = LibraryExists("chat-processor");
	}
	
	#if DEBUG
	RegAdminCmd("sm_codes", CmdCodes, ADMFLAG_ROOT);
	#endif
}

public void CVar_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	SetHooks();
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "scp") == 0)
	{
		g_bLoadedLibSCP = true;
		SetHooks();
	}
	else if (strcmp(name, "chat-processor") == 0)
	{
		g_bLoadedLibKW = true;
		SetHooks();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "scp") == 0)
	{
		g_bLoadedLibSCP = false;
		SetHooks();
	}
	else if (strcmp(name, "chat-processor") == 0)
	{
		g_bLoadedLibKW = false;
		SetHooks();
	}
}

public void OnAllPluginsLoaded()
{
	g_bPluginsLoaded = true;
	CreateTimer(1.0, Timer_LoadDelayed);
}

public Action Timer_LoadDelayed(Handle timer)
{
	SetHooks();
	FillCmds();
}

public void OnMapStart()
{
	FillCmds();
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

void SetHooks()
{
	static bool bRegCmd;

	if ( !g_bPluginsLoaded )
		return;
	
	if ( !g_hCvarIgnoreChatProc.BoolValue && ( g_bLoadedLibSCP || g_bLoadedLibKW ) )
	{
		g_bHookCmd = false;
	}
	else {
		g_bHookCmd = true;
		if ( !bRegCmd )
		{
			bRegCmd = true;
			AddCommandListener(ListenSay, "say");
			AddCommandListener(ListenSayTeam, "say_team");
		}
	}
}

#if DEBUG
Action CmdCodes(int client, int args)
{
	char sCyr[] = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯабвгдеёжзийклмнопрстуфхцчшщьыъэюяіІїЇ";
	//char sCyr[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890!@#$%%^&*()-_=+/?";
	
	int lb, ub;
	char sCh[3];
	
	for (int i = 0; i < sizeof(sCyr)-1; i+=2)
	{
		ub = sCyr[i];
		lb = sCyr[i+1];
		strcopy(sCh, sizeof(sCh), sCyr[i]);
		
		LogToFileEx("addons/sourcemod/logs/_cyr.log", "%s - UB: %i, LB: %i", sCh, ub, lb);
	}
	PrintToChat(client, "Codes are saved to: logs/_cyr.log");
	return Plugin_Handled;
}
#endif

void FillCmds()
{
	// read commands exclusion list
	static char sLine[MAX_EXCLUDE_CMD_LENGTH];
	static char sExcludeFile[PLATFORM_MAX_PATH];
	
	ArrayList hArrayExclude = new ArrayList(ByteCountToCells(MAX_EXCLUDE_CMD_LENGTH));
	
	BuildPath(Path_SM, sExcludeFile, sizeof(sExcludeFile), CMD_EXCLUSION_PATH);
	
	File hFile = OpenFile(sExcludeFile, "r");
	if( hFile != null)
	{
		while( !hFile.EndOfFile() && hFile.ReadLine(sLine, sizeof(sLine)) )
		{
			TrimString(sLine);
			
			if ( strncmp(sLine, "sm_", 3, false) != 0 )
			{
				Format(sLine, sizeof sLine, "sm_%s", sLine);
			}
			hArrayExclude.PushString(sLine);
		}
		hFile.Close();
	}

	// read full commands list
	static char name[MAX_CVAR_NAME_LENGTH], sDesc[255];
	Handle hCmd;
	bool isCommand;
	int iCmdType;
	int flags, v;
	
	StringMap g_hMapCmdsSM = new StringMap();
	
	Handle hCmdIter = GetCommandIterator();
	if ( hCmdIter != INVALID_HANDLE )
	{
		while ( ReadCommandIterator(hCmdIter, name, sizeof name, flags, sDesc, sizeof sDesc) )
		{
			g_hMapCmdsSM.SetValue(name, 0);
		}
	}
	
	g_hMapCmds.Clear();
	
	hCmd = FindFirstConCommand(name, sizeof(name), isCommand, flags); // thanks to SilverShot
	if ( hCmd != INVALID_HANDLE )
	{
		do {
			if( isCommand )
			{
				ReplaceString(name, sizeof(name), "\n", "");
																DBG("cmd added: %s - flag: %i", name, flags)
				if ( strncmp(name, "sm_", 3, false) == 0 )
				{
					iCmdType = CMDType_SM;
				}
				else {
					if ( g_hMapCmdsSM.GetValue(name, v) )
					{
						iCmdType = CMDType_Plain;
					}
					else {
						iCmdType = CMDType_Game;
					}
					Format(name, sizeof name, "sm_%s", name);
				}
				if ( hArrayExclude.FindString(name) != -1 )
				{
					iCmdType |= CMDType_Exclusion;
				}
				g_hMapCmds.SetValue(name, iCmdType);
			}
		} while( FindNextConCommand(hCmd, name, sizeof(name), isCommand) );
		CloseHandle(hCmd);
	}
	delete hArrayExclude;
	delete g_hMapCmdsSM;
																DBG("total cmds found: %i", g_hMapCmds.Size)
}

bool CommandExistsEx(char[] cmd, bool bConsoleCmd, int &CmdType = 0) // Case sensitive alternate of CommandExists()
{
	if ( !g_hMapCmds.GetValue(cmd, CmdType) )
	{
		return false;
	}
	if( !bConsoleCmd && (CmdType & CMDType_Game) )
	{
		return false;
	}
	return true;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors) // Forward of CP by Keith Warren
{
	if ( g_hCvarIgnoreChatProc.BoolValue )
		return Plugin_Continue;
		
	return ProcessCmd(author, message, false);
}

public Action OnChatMessage(int &author, ArrayList recipients, char[] name, char[] message) // Forward of SCP
{
	if ( g_hCvarIgnoreChatProc.BoolValue )
		return Plugin_Continue;

	return ProcessCmd(author, message, false);
}

public Action ListenSayTeam(int client, char[] command, int args)
{
	return ProcessSayChat(client, true);
}

public Action ListenSay(int client, char[] command, int args)
{
	return ProcessSayChat(client, false);
}

public Action OnClientCommand(int client, int args) // for unrecognized console commands
{
	if ( !g_bMapStarted || !g_hCvarEatConsole.BoolValue )
		return Plugin_Continue;
	
	static char cmd[MAXLENGTH_MESSAGE];
	static char arg[MAXLENGTH_MESSAGE];
	
	if ( !client || !IsClientInGame(client) || GetCmdReplySource() == SM_REPLY_TO_CHAT )
	{
		return Plugin_Continue;
	}
	
	GetCmdArg(0, cmd, sizeof cmd);
	
	if ( args )
	{
		GetCmdArgString(arg, sizeof arg);
	
		if( (cmd[0] & 0x80) && (strlen(cmd) == 1) ) // fix sm (or valve?) bug
		{
			Format(cmd, sizeof cmd, "%s%s", cmd, arg);
		}
		else {
			Format(cmd, sizeof cmd, "%s %s", cmd, arg);
		}
	}
	return ProcessCmd(client, cmd, true);
}

/*
Action CmdSayTeam(int client, int args)
{
	return g_bHookCmd ? ProcessSayChat(client, true) : Plugin_Continue;
}

Action CmdSay(int client, int args)
{
	return g_bHookCmd ? ProcessSayChat(client, false) : Plugin_Continue;
}
*/

/* Alternate
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(command, "say") == 0)
		return ProcessSayChat(client, false, sArgs);
		
	if (strcmp(command, "say_team") == 0)
		return ProcessSayChat(client, true, sArgs);
		
	return Plugin_Continue;
}
*/

Action ProcessSayChat(int client, bool bTeamChat)
{
	if ( !g_bHookCmd || !g_bEnabled )
		return Plugin_Continue;
	
	if( 1 <= client <= MaxClients && IsClientInGame(client))
	{
		static char message[MAXLENGTH_MESSAGE];
		GetCmdArgString(message, sizeof(message));
																DBG("CmdSay: %s", message)
		UnQuoteEx(message);
		Action action = ProcessCmd(client, message, false);
		if (action == Plugin_Stop)
			return Plugin_Handled;
		if (action == Plugin_Changed) {
			if (bTeamChat)
			{
				int iTeam = GetClientTeam(client);
				
				for (int i = 1; i <= MaxClients; i++)
					if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
						PrintToChat(i, "\x01(队伍) \x03%N :\x01  %s", client, message);
			}
			else {
				PrintToChatAll("\x03%N :\x01  %s", client, message);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

Action ProcessCmd(int client, char[] message, bool bConsoleCmd)
{
																DBG("jmp0. message: %s", message)
	/*
	// disabled, because chat processor (randomly) identify that 'say' coming from Fake,
	// and does not fire forward for it //^.^\\ what a mess.
	
	if ( g_bSkipFrame ) // no need to handle our fixed command
	{
																DBG("skip frame")
		g_bSkipFrame = false;
		return Plugin_Continue;
	}
	*/

	if ( !g_bEnabled )
		return Plugin_Continue;
	
	float fNowTime = GetEngineTime();
	
	if ( fNowTime - g_fLastTime[client] > 0.3 ) // prevents exploit with chat flood & fix chat processor bug with multiple forward call duplicates
	{
		g_fLastTime[client] = fNowTime;
	}
	else {
																DBG("skip flood. client: %i, now: %f, Last: %f", client, fNowTime, g_fLastTime[client])
		return Plugin_Continue;
	}
	
	if ( !client || !IsClientInGame(client) )
		return Plugin_Continue;
	
	static char cmd[64], cmdsave[64], arg[MAXLENGTH_MESSAGE], exec[MAXLENGTH_MESSAGE];
	bool bSilent, bEaten, bSourceSM;
	int CmdType;
	int offset = 0; 	// color tag offset
	int offset_k = 1; 	// key trigger offset
																DBG("jmp1")
	if ( message[0] == '\0' )
		return Plugin_Continue;
																DBG("jmp2. message: %s", message)
	while ( message[offset] < 32 ) // color tags
	{
		offset++;
		if ( offset == MAXLENGTH_MESSAGE )
			return Plugin_Continue;
	}
																DBG("jmp4. offset: %i", offset)
																
	if ( IsPrefix(message[offset], TriggerType_Public) )		// "!"
	{
		bSilent = false;
	}
	else if ( IsPrefix(message[offset], TriggerType_Silent) ) 	// "/"
	{
		bSilent = true;
	}
	else if ( message[offset] == '.' ) 							// "."
	{
		bSilent = true;
	}
	else {
		if ( !g_hCvarNoKeyAllow.BoolValue )
			return Plugin_Continue;
		offset_k = 0;
	}
																DBG("jmp4.1. offset_k: %i. Silent? %b", offset_k, bSilent)
	if ( strlen(message) <= (offset_k + offset) )
		return Plugin_Continue;
																DBG("jmp5")
	int pos = StrContains(message, " "); // split arg
	if ( pos == -1 )
	{
		strcopy(cmd, sizeof(cmd), message[offset_k + offset]);
		arg[0] = '\0';
	}
	else {
		strcopy(cmd, pos - offset - offset_k + 1, message[offset_k + offset]);
		strcopy(arg, sizeof(arg), message[pos+1]);
	}
	
	if ( !offset_k )
	{
																DBG("len of cmd: %i. Allowed: %i", strlen_mb(cmd), g_hCvarNoKeyMinLength.IntValue)
		if ( strlen_mb(cmd) < g_hCvarNoKeyMinLength.IntValue )
			return Plugin_Continue;
	}
	
	if ( strncmp(cmd, "sm_", 3, false) != 0 ) // support !sm_cmd
	{
		Format(cmd, sizeof(cmd), "sm_%s", cmd);
	}
	else {
		bSourceSM = true; // command entered with "sm_" prefix
	}
																DBG("jmp6. cmd: %s, arg: %s", cmd, arg)
	if ( CommandExistsEx(cmd, bConsoleCmd, CmdType) )
	{
		if ( CmdType & CMDType_Exclusion )
			return Plugin_Continue;
		
		if ( bConsoleCmd )
		{
			if ( offset_k == 0 ) // no key prefix
			{
				// NOT XOR
				if ( bSourceSM ) // sm_
				{
					if ( CmdType & CMDType_SM )
						return Plugin_Continue;	// valid "sm_cmd" for console => exit
				}
				else { // no sm_
					if ( 0 == ( CmdType & CMDType_SM ) )
						return Plugin_Continue;	// valid "cmd" for console => exit
				}
			}
		}
		else { // chat
			if ( offset_k != 0 ) // has prefix
				return Plugin_Continue;	// valid "!cmd" for chat => exit
		}
		
		bEaten = true;
	}
																DBG("jmp7")
	if ( !bEaten )
	{
		StringToLowerEx(cmd, sizeof(cmd));
																DBG("cmd: %s", cmd)
		if ( CommandExistsEx(cmd, bConsoleCmd, CmdType) )
		{
			if ( CmdType & CMDType_Exclusion )
				return Plugin_Continue;
				
			bEaten = true;
		}
	}
																DBG("jmp8. Con? %b. CMDType: %i", bConsoleCmd, CmdType)
	if ( g_hCvarEatCyrillic.BoolValue )
	{
		if ( !bEaten )
		{
			if ( g_hCvarEatTranslit.BoolValue )
			{
				strcopy(cmdsave, sizeof cmdsave, cmd); // save buffer
			}
		
			StringCyrToEng(cmd, sizeof(cmd));
																DBG("cmd uncyr: %s", cmd)
																
			if ( strncmp(cmd, "sm_sm_", 6, true) == 0 ) // remove double sm_
			{
				strcopy(cmd, sizeof(cmd), cmd[3]);
				bSourceSM = true;
			}
			
			if ( CommandExistsEx(cmd, bConsoleCmd, CmdType) )
			{
				if ( CmdType & CMDType_Exclusion )
					return Plugin_Continue;
					
				bEaten = true;
			}
			else {
				if ( g_hCvarEatTranslit.BoolValue )
				{
					StringCyrDeTranslit(cmdsave, sizeof cmdsave);
					
					if ( strncmp(cmdsave, "sm_sm_", 6, true) == 0 ) // remove double sm_
					{
						strcopy(cmdsave, sizeof(cmdsave), cmdsave[3]);
						bSourceSM = true;
					}
					
					if ( CommandExistsEx(cmdsave, bConsoleCmd, CmdType) )
					{
						if ( CmdType & CMDType_Exclusion )
							return Plugin_Continue;
						
						strcopy(cmd, sizeof cmd, cmdsave); // copy back
						
						bEaten = true;
					}
				}
			}
		}
	}
																DBG("jmp9")
	if ( bEaten && !bConsoleCmd )
	{
																DBG("jmp10. Eaten: yes")
		if ( offset_k == 0 && g_hCvarNoKeySilent.BoolValue )
		{
			bSilent = true;
		}
		
		int trigger = g_sCmdPrefix[TriggerType_Silent][0];
		
		if ( trigger )
		{
			FormatEx(exec, sizeof(exec), "say %c%s %s", trigger, cmd[CmdType & CMDType_SM ? 0 : 3], arg); // cut sm_ if required, add arg and execute
		}
		else {
			FormatEx(exec, sizeof(exec), "%s %s", cmd[CmdType & CMDType_SM ? 0 : 3], arg); // cut sm_ if required, add arg and execute
		}
		
		//g_bSkipFrame = true;
		FakeClientCommandEx(client, exec); // delay a frame
																DBG("exec: %s", exec)
																
		trigger = g_sCmdPrefix[bSilent ? TriggerType_Silent : TriggerType_Public][0];
		
		if ( !trigger )
		{
			trigger = 32; // space
		}
		
		FormatEx(message[offset], MAXLENGTH_MESSAGE - offset, "%c%s %s", trigger, cmd[bSourceSM && (CmdType & CMDType_SM) ? 0 : 3], arg); // cut sm_ if user didn't print it
		
																DBG("fixed msg: %s", message[offset])
		return bSilent ? Plugin_Stop : Plugin_Changed;
	}
	else if ( bEaten && bConsoleCmd )
	{	
		FormatEx(exec, sizeof(exec), "%s %s", cmd[CmdType & CMDType_SM ? 0 : 3], arg);
		
		FakeClientCommandEx(client, exec); // delay a frame
																DBG("exec: %s", exec)
		return Plugin_Handled;
	}
	else {
		if ( offset_k != 0 && g_hCvarLogUnkn.BoolValue )
		{
																DBG("jmp11. Eaten: no")
			if ( !CommandExists(cmd) ) // just ensure in case late registered
			{
				LogUnknownCmd(client, bConsoleCmd, message[offset]);
			}
			else {
				FillCmds();
			}
		}
	}
	return Plugin_Continue;
}

void LogUnknownCmd(int client, bool bConsoleCmd, const char[] format, any ...)
{
	static char sSteam[64];
	static char sIP[32];
	static char sCountry[4];
	static char sName[MAX_NAME_LENGTH];
	static char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 4);
	
	GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam));
	GetClientName(client, sName, sizeof(sName));
	GetClientIP(client, sIP, sizeof(sIP));
	GeoipCode3(sIP, sCountry);
	
	File hFile = OpenFile(g_sLog, "a+");
	if( hFile != null )
	{
		hFile.WriteLine("[%s] %s - %s (%s | [%s] %s)", bConsoleCmd ? "con" : "chat", buffer, sName, sSteam, sCountry, sIP);
		hFile.Close();
	}
}

bool IsPrefix(int ch, int TriggerType)
{
	for (int i = 0; i < sizeof(g_sCmdPrefix[]) && g_sCmdPrefix[TriggerType][i] != 0; i++)
	{
		if ( ch == g_sCmdPrefix[TriggerType][i] )
			return true;
	}
	return false;
}

int strlen_mb(char[] s) // returns number of characters with respect to multi-byte
{
	int cnt;
	for (int i = 0; i < strlen(s); i += GetCharBytes(s[i]))
	{
		cnt ++;
	}
	return cnt;
}

stock void UnQuoteEx(char[] Str)
{
	if (Str[0] == '\"') {
		int iLen;
		iLen = strlen(Str);
		Str[iLen-1] = '\0';
		strcopy(Str, iLen, Str[1]);
	}
}

// Walkaround, since sm is natively doesn't support Cyrillic letters insensitive search and conversion
stock void StringToLowerEx(char[] buf, int iLen)
{
	static int i, hb, lb;
	for (i = 0; i < iLen && buf[i] != 0; i++)
	{
		if (buf[i] == 208) {
			if (i + 1 < iLen) {
				hb = 208;
				lb = buf[i+1];
				if (CharToLowerEx(hb, lb)) {
					buf[i] = hb;
					buf[i+1] = lb;
				}
				i++;
			}
		}
		else {
			hb = 0;
			lb = buf[i];
			if (CharToLowerEx(hb, lb))
				buf[i] = lb;
		}
	}
}

stock bool CharToLowerEx(int& hb, int& lb)
{
	// RU
	// 144 ... 159 (208) => 176 ... 191 (208)
	// 160 ... 175 (208) => 128 ... 143 (209)
	// 129 (208) => 145 (209)
	// UA
	// 134 (208) => 150 (209)
	// 135 (208) => 151 (209)
	
	if (hb == 208) {
		if (144 <= lb <= 159) {
			lb += 32;
			return true;
		}	
		if (160 <= lb <= 175) {
			lb -= 32;
			hb = 209;
			return true;
		}
		if (lb == 129) { // Ё
			lb = 145;
			hb = 209;
			return true;
		}
		if (lb == 134) { // І
			lb = 150;
			hb = 209;
			return true;
		}
		if (lb == 135) { // Ї
			lb = 151;
			hb = 209;
			return true;
		}
		return false;
	}
	
	// EN
	// 65 ... 90 => 97 ... 122
	if (65 <= lb <= 90) {
		lb += 32;
		return true;
	}
	
	return false;
}

stock void StringCyrToEng(char[] buf, int iLen)
{
	static int c[256][256], i, j, n, cb, init;
	static char dest[MAXLENGTH_MESSAGE];
	
	if (init == 0) {
		char sCyr[] = "абвгдеёжзийклмнопрстуфхцчшщьыъэюяії";
		char sEng[] = "f,dult`;pbqrkvyjghcnea[wxioms]'.zs]";
		
		for (i = 0; i < sizeof(sCyr); i+=2)
		{
			c[ sCyr[i] ][ sCyr[i+1] ] = sEng[i/2];
		}
		init = 1;
	}
	
	// Lower-case RU / UA:
	// 176 ... 191 (208)
	// 128 ... 143, 145, 150, 151 (209)
	
	for (i = 0, j = 0; i < iLen && buf[i] != 0; i++) {
		cb = GetCharBytes(buf[i]);
		if (cb == 2) {
			if ((buf[i] == 208 && ( 176 <= buf[i+1] <= 191 )) ||
				(buf[i] == 209 && ( (128 <= buf[i+1] <= 143) || buf[i+1] == 145 || buf[i+1] == 150 || buf[i+1] == 151 )))
			{
				dest[j++] = c[ buf[i] ][ buf[i+1] ];
			}
			else {
				dest[j++] = buf[i];
				dest[j++] = buf[i+1];
			}
			if (j >= MAXLENGTH_MESSAGE - 2)
				break;
		}
		else {
			for (n = i; n < i + cb; n++) {
				dest[j++] = buf[n];
				if (j >= MAXLENGTH_MESSAGE - 1) {
					i = iLen;
					break;
				}
			}
		}
		i += cb - 1;
	}
	strcopy(buf, iLen, dest);
	StringInsertNull(buf, iLen, j);
}

stock void StringCyrDeTranslit(char[] buf, int iLen)
{
	static int c[256][256], i, j, n, cb, init;
	static char dest[MAXLENGTH_MESSAGE];
	
	if (init == 0) {
		char sCyr[] = "абвгдеёжзийклмнопрстуфхцчшщьыъэюяії";
		char sEng[] = "abvgde gziyklmnoprstufhc      e  ii";
		
		for (i = 0; i < sizeof(sCyr); i+=2)
		{
			c[ sCyr[i] ][ sCyr[i+1] ] = sEng[i/2];
		}
		init = 1;
	}
	
	ReplaceString(buf, iLen, "ё", "yo");
	ReplaceString(buf, iLen, "ч", "ch");
	ReplaceString(buf, iLen, "ш", "sh");
	ReplaceString(buf, iLen, "щ", "sch");
	ReplaceString(buf, iLen, "ю", "yu");
	ReplaceString(buf, iLen, "я", "ya");
	
	// Lower-case RU / UA:
	// 176 ... 191 (208)
	// 128 ... 143, 145, 150, 151 (209)
	
	for (i = 0, j = 0; i < iLen && buf[i] != 0; i++) {
		cb = GetCharBytes(buf[i]);
		if (cb == 2) {
			if ((buf[i] == 208 && ( 176 <= buf[i+1] <= 191 )) ||
				(buf[i] == 209 && ( (128 <= buf[i+1] <= 143) || buf[i+1] == 145 || buf[i+1] == 150 || buf[i+1] == 151 )))
			{
				dest[j++] = c[ buf[i] ][ buf[i+1] ];
			}
			else {
				dest[j++] = buf[i];
				dest[j++] = buf[i+1];
			}
			if (j >= MAXLENGTH_MESSAGE - 2)
				break;
		}
		else {
			for (n = i; n < i + cb; n++) {
				dest[j++] = buf[n];
				if (j >= MAXLENGTH_MESSAGE - 1) {
					i = iLen;
					break;
				}
			}
		}
		i += cb - 1;
	}
	strcopy(buf, iLen, dest);
	StringInsertNull(buf, iLen, j);
}

stock void StringInsertNull(char[] buf, int iLen, int iPos)
{
	// null terminator with respect to multi-byte characters
	if (iLen <= iPos && iLen != 0) {
		if (iLen >= 2 && (buf[iLen-2] == 208 || buf[iLen-2] == 209))
			buf[iLen-2] = 0;
			
		buf[iLen-1] = 0;
	}
	else {
		if (iPos != 0 && (buf[iPos-1] == 208 || buf[iPos-1] == 209))
			buf[iPos-1] = 0;
	
		buf[iPos] = 0;
	}
}

bool ParseCoreConfigFile(const char[] sFile) // Thanks to SilverShot
{
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, INVALID_FUNCTION, CoreConfig_KeyValue, INVALID_FUNCTION);
	
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(sFile, line, col);
	delete parser;
	
	if( result != SMCError_Okay )
	{
		char error[128];
		SMC_GetErrorString(result, error, sizeof error);
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, sFile, result);
	}
	return (result == SMCError_Okay);
}

public SMCResult CoreConfig_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (strcmp(key, "PublicChatTrigger") == 0)
	{
		strcopy(g_sCmdPrefix[TriggerType_Public], sizeof(g_sCmdPrefix[]), value);
	}
	else if (strcmp(key, "SilentChatTrigger") == 0)
	{
		strcopy(g_sCmdPrefix[TriggerType_Silent], sizeof(g_sCmdPrefix[]), value);
	}
	return SMCParse_Continue;
}

stock void DBG_Print(const char[] format, any ...)
{
    static char buffer[192];
	static char g_sLogDebug[PLATFORM_MAX_PATH];
	if (g_sLogDebug[0] == '\0')
		BuildPath(Path_SM, g_sLogDebug, sizeof(g_sLogDebug), DEBUG_LOG_PATH);
    VFormat(buffer, sizeof(buffer), format, 2);
    LogToFileEx(g_sLogDebug, buffer);
}