#define PLUGIN_VERSION		"1.8"

/*=======================================================================================
	Plugin Info:

*	Name	:	[ANY] ConVars Anomaly Fixer
*	Author	:	Alex Dragokas
*	Descr.	:	Check in-game ConVars that differ from the cfg-files values (due to the Valve bug) and fix them before map start
*	Link	:	https://forums.alliedmods.net/showthread.php?p=2593843

========================================================================================
	Change Log:

// TODO: log sorting, check performance.

1.8 (18-Dec-2019)
	- Added "sv_cheats" ON/OFF handling, caused some ConVars to reset to its defaults, when administrator (or 3rd party plugin) uses cheats ConVar.
	- Added "exec" and "sm_execcfg" handling, when they are written in server.cfg file. Subsequent files are automatically parsed now.
	- Performance optimizations.

1.7 (22-Nov-2019)
	- Decreased server log size and optimized speed by temporarily removing NOTIFY flag while ConVar is being changed.
	- Log file write access is fixed.

1.6 (12-May-2019)
	- Fixed: log file is created even with logpos != 4 bit.
	- now, by default, plugin is not create log anymore. Otherwise, set "convar_anomaly_logpos" ConVar to what you need.

1.5 (29-Mar-2019)
	- Added support for non-default server.cfg location defined by "servercfgfile" ConVar (thanks to iGANGNAM).

1.4 (24-Jan-2019)
	- I made attempt to reduce conflicts with 3-rd party plugins that specially change global convars to non-default values during the game.
	Such convars will no longer be fixed on map start (with the exception of convars that had been set to its defaults). To force fixing such convars (old behaviour), enable "convar_anomaly_fix_nondefault"
	- Added current map name to the log.
	- Corrected ArrayList buffer size and increased other buffers.
	- Integrated all command list to excludes when evaluating convar that are not exist. No more need to add cmds like "exec", "setmaster" to "convar_cvar_names_exclude".
	- "overflow" area check is expanded to cover: "Command too long" errors, which cause convar is completely ignored by server.
	- added new area to check: "duplicated convars".
	- Fixed the order of cfg files reading (according to Valve rules). 'server.cfg' is go first now. It will not overwrite convars if there are duplicated in cfg/sourcemod/ *.cfg files.
	If you prefer vice versa order (old behaviour of this plugin) to allow server.cfg convars overwrite another convars, set "convar_anomaly_server_last" to 1.
	- server.cfg is now not optional.
	- "convar_cvar_check_areas" for "overflows" is replaced by index 8.
	- Fixed case sensitivity errors like "z_difficulty (Value: Hard, should be: hard)".
	- It is recommended you remove "cfg/sourcemod/sm_convar_anomaly.cfg" file before installing this version.
	
1.3 (13-Jan-2019)
	- Added additional ConVar check on round start.
	(some buggy servers known to change ALL convars to defaults after last player leave the game in the way even "command buffer overflow" Silver's fix doesn't help)
	Be attentive! It can conflict with another plugins. Disable it by "convar_anomaly_roundstart" convar if you ensure your server has no such bug.
	
1.2 (07-Sep-2018)
    - Fixed: log is not created when convar_anomaly_autofix == 0.
    - Removed dependency of <regexp> because it can't be compiled for SM v.1.7.3.

1.1 (27-May-2018)
	- Improved log format for fix/error msg a little bit.
	- Added "convar_cvar_check_areas" ConVar to choose the area you need to check for (1 - difference in values, 2 - nonexistent convars, 3 - overflows, 4 - All {by default}).
	- Little checks, like cfg file presence.

1.0 (25-May-2018)
	- Initial release

========================================================================================
	Description:
	
	Cfg Console Variables anomaly happens time by time, and caused by Valve bug:
	values can not be read from cfg-files and remains by default if you reach some limit
	of the number of lines in server.cfg / or cfg-files in total / or by chance.
	
	Also, this plugin check:
	 - if some cfg files contain wrong values that exceed max/min value allowed or max. length.
	 - unused (non-existent) ConVars.
	 - duplicated ConVars.
	
	Commands:
	 - "sm_convar_anomaly_show"	- to compare values in cfg files with actual in-game Cvar to find anomalies/unused cvars.
	 - "sm_convar_anomaly_fix"	- to attempt to fix Cvar anomalies (log will be short - only info about fixes).
	
	By default, log-file is located at: "addons/sourcemod/logs/CVar_Anomaly.log"
	
	Settings (ConVars):
	 - "convar_anomaly_autofix"			- fix Cvar anomaly automatically before each map start? (0 - off, 1 - on {default}).
	 - "convar_anomaly_roundstart"		- Do additional check/fix on each round start (0 - Disabled, 1 - Enabled)
	 - "convar_anomaly_fix_nondefault"	- Include all convars in fix even those who have non-default value, but different from cfg (0 - Fix default values only, 1 - Fix all)
	 - "convar_anomaly_server_last"		- 0 - process cfg files in default Valve order [server.cfg go first], 
										  1 - broke rules and overwrite convars by server.cfg file). This include files in 'convar_cfg_files_include'
	 - "convar_cvar_check_areas"		- Areas to check for (-1 - All, 1 - difference in values, 2 - nonexistent convars, 8 - overflows, 16 - duplicate convars)
	 - "convar_anomaly_logpos"			- where to write log? (1 - client conlose, 2 - server console, 4 - file, 1+2+4=7 - all places).
	 - "convar_cfg_files_include"		- if you need more cfg-files to process, place them here, separated by star (*)
	 - "convar_cfg_files_exclude"		- if you need exclude some cfg-files from processing, place them here, separated by star (*)
	 - "convar_cvar_names_exclude"		- if you need concrete ConVars to exclude from processing, place them here, separated by star (*)

	Warning: some plugins / game specificially change its ConVars in-game process, so the final report is not necessarily accurate.
	
	Notice:
	
	 - To disable automatic fix completely, set "convar_anomaly_autofix" in cfg/sourcemod/sm_convar_anomaly.cfg file to 0.
	
	 - To minimize the number of cvars required to fix and improve stability, it is recommended to use my plugin
	together with "Command and ConVar - Buffer Overflow Fixer": https://forums.alliedmods.net/showthread.php?t=309656
	
======================================================================================

	Credits:
	
	- SilverShot - for initial version of config files parser and for "sm_cvarlist and sm_cmdlist" plugin.
	https://forums.alliedmods.net/showthread.php?p=1739534
	https://forums.alliedmods.net/showpost.php?p=1717447&postcount=4
	
	- Neuro Toxin - for raw IsNumeric() function.
	https://github.com/ntoxin66/Dynamic/blob/master/scripting/dynamic/system/flatconfigs.sp#L193
	
	- hmmmmm - for floating point operation tips.
	https://forums.alliedmods.net/showthread.php?t=307755
	
======================================================================================
	
	Relationship:
	
	 - Command and ConVar - Buffer Overflow Fixer
	 https://forums.alliedmods.net/showthread.php?t=309656

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
//#include <regex>

#define MAX_CVAR_NAME_LENGTH	100
#define MAX_CVAR_VALUE_LENGTH	512
#define MAX_CVAR_ITEMS			50  // for parsing own .cfg
#define CVAR_FLAGS				FCVAR_NOTIFY

ArrayList g_hArrayCvarList, g_hArrayCvarValues, g_hArrayCfg, g_hArrayCvarExclude, g_hArrayCfgExclude, g_hArrayCvarDuplicates, g_hArrayCmdLen, g_hArrayCmds;
ConVar g_hCvarAutoFix, g_hCvarLogPos, g_hCvarCfgsInclude, g_hCvarCfgsExclude, g_hCvarCVarExclude, g_hCvarAreas, g_hCvarFixOnRoundStart, g_hCvarFixNonDefaults, g_hCvarServerOverwrite, g_hCvarServerCfg, g_hCvarCheats;
int g_iLogPos, g_iCheckAreas;
bool g_bAutoFix, g_bFixOnRoundStart, g_bFixNonDefaults, g_bFixServerLast;
File g_hLog;

char g_sLogPath[PLATFORM_MAX_PATH], g_sServerCfg[PLATFORM_MAX_PATH];

/* ====================================================================================================
					PLUGIN INFO / START / END
   ====================================================================================================*/

public Plugin myinfo =
{
	name = "控制台变量异常检测",
	author = "Dragokas",
	description = "Check in-game ConVars that differ from the cfg-files values (due to the Valve bug) and fix them before each map start",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2593843"
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/CVar_Anomaly.log");
	
	// Commands
	//
	RegAdminCmd("sm_convar_anomaly_show",	CmdConfigsCompare2,	ADMFLAG_ROOT,	"Compares cfg files values with actual Cvar values to find anomalies and print difference/missing/overflow Cvars.");
	RegAdminCmd("sm_convar_anomaly_fix",	CmdConfigsFix,		ADMFLAG_ROOT,	"Attempting to overwrite anomalous ConVars by cfg files values.");
	
	// CVars
	//
	g_hCvarAutoFix = CreateConVar(			"convar_anomaly_autofix",		"1",					"Fix Cvar anomaly automatically before each map start? (0 - OFF [plugin will be read only = inform mode only], 1 - ON)", CVAR_FLAGS );
	g_hCvarFixOnRoundStart = CreateConVar(	"convar_anomaly_roundstart",	"1",					"Do additional check/fix on each round start (0 - Disabled, 1 - Enabled)", CVAR_FLAGS );
	g_hCvarFixNonDefaults = CreateConVar(	"convar_anomaly_fix_nondefault","0",					"Include all convars in fix even those who have non-default value, but different from cfg (0 - Fix default values only, 1 - Fix all)", CVAR_FLAGS );
	g_hCvarServerOverwrite = CreateConVar(	"convar_anomaly_server_last",	"0",					"(0 - process cfg files in default Valve order [server.cfg go first], 1 - broke rules and overwrite convars by server.cfg file). This include files in 'convar_cfg_files_include'", CVAR_FLAGS );
	g_hCvarAreas = CreateConVar(			"convar_cvar_check_areas",		"-1",					"Areas to check for (-1 - All, 1 - difference in values, 2 - nonexistent convars, 8 - overflows, 16 - duplicate convars).", CVAR_FLAGS );
	g_hCvarLogPos = CreateConVar(			"convar_anomaly_logpos",		"0",					"Where to write log? (1 - client console, 2 - server console, 4 - file, 1+2+4=7 - all places)", CVAR_FLAGS );
	g_hCvarCfgsInclude = CreateConVar(		"convar_cfg_files_include",		"cfg/autoexec.cfg",		"List of additional cfg-files to process, separated by star (*)", CVAR_FLAGS );
	g_hCvarCfgsExclude = CreateConVar(		"convar_cfg_files_exclude",		"",						"List of cfg-files to exclude from processing, separated by star (*)", CVAR_FLAGS );
	g_hCvarCVarExclude = CreateConVar(		"convar_cvar_names_exclude",	"",						"List of ConVar names (or commands from server.cfg) to exclude from processing, separated by star (*)", CVAR_FLAGS );
	
	CreateConVar(							"convar_anomaly_version",		PLUGIN_VERSION,						"ConVars Anomaly Fixer plugin version", FCVAR_DONTRECORD);
	
	g_hCvarServerCfg = FindConVar("servercfgfile");
	g_hCvarCheats = FindConVar("sv_cheats");
	
	// Init ArrayLists
	//
	if (g_hArrayCfg != null) delete g_hArrayCfg;
	if (g_hArrayCfgExclude != null) delete g_hArrayCfgExclude;
	if (g_hArrayCvarExclude != null) delete g_hArrayCvarExclude;
	if (g_hArrayCvarList != null) delete g_hArrayCvarList;
	if (g_hArrayCvarDuplicates != null) delete g_hArrayCvarDuplicates;
	if (g_hArrayCvarValues != null) delete g_hArrayCvarValues;
	if (g_hArrayCmdLen != null) delete g_hArrayCmdLen;
	
	g_hArrayCfg = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hArrayCfgExclude = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hArrayCvarExclude = new ArrayList(ByteCountToCells(MAX_CVAR_NAME_LENGTH));
	g_hArrayCmds = new ArrayList(ByteCountToCells(MAX_CVAR_NAME_LENGTH));
	g_hArrayCvarList = new ArrayList(ByteCountToCells(MAX_CVAR_NAME_LENGTH));
	g_hArrayCvarDuplicates = new ArrayList(ByteCountToCells(MAX_CVAR_NAME_LENGTH));
	g_hArrayCvarValues = new ArrayList(ByteCountToCells(MAX_CVAR_VALUE_LENGTH));
	g_hArrayCmdLen = new ArrayList(ByteCountToCells(4));
	
	AutoExecConfigSmart(true,				"sm_convar_anomaly");
	
	g_hCvarAutoFix.AddChangeHook(ConVarChanged);
	g_hCvarFixOnRoundStart.AddChangeHook(ConVarChanged);
	g_hCvarFixNonDefaults.AddChangeHook(ConVarChanged);
	g_hCvarServerOverwrite.AddChangeHook(ConVarChanged);
	g_hCvarAreas.AddChangeHook(ConVarChanged);
	g_hCvarLogPos.AddChangeHook(ConVarChanged);
	g_hCvarCfgsInclude.AddChangeHook(ConVarChanged);
	g_hCvarCfgsExclude.AddChangeHook(ConVarChanged);
	g_hCvarCVarExclude.AddChangeHook(ConVarChanged);
	g_hCvarServerCfg.AddChangeHook(ConVarChanged);
	
	g_hCvarCheats.AddChangeHook(ConVarChanged_Cheats);
	
	GetCvars();
	FillCmds();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	if (g_bFixOnRoundStart)
		OnAutoConfigsBuffered();
}

// Smart version of AutoExecConfig() that not depends on bugged valve functions
//
void AutoExecConfigSmart(bool autoCreate, const char[] name, const char[] folder = ".")
{
	static char sFile[PLATFORM_MAX_PATH];
	FormatEx(sFile, sizeof(sFile), "cfg/sourcemod/%s/%s.cfg", folder, name);
	
	if (FileExists(sFile))
		CheckCfgAnomaly(0, sFile, true);
	else {
		if (strcmp(folder, ".") == 0)
			AutoExecConfig(autoCreate, name);
		else
			AutoExecConfig(autoCreate, name, folder);
	}
}

public void ConVarChanged_Cheats(ConVar convar, const char[] oldValue, const char[] newValue)
{
	 // 1 -> 0
	if (strcmp(newValue, "0") == 0 && strcmp(oldValue, "1") == 0)
	{
		//RequestFrame(OnNextFrameFixCvars);
		CreateTimer(1.0, Timer_FixCvars, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_FixCvars(Handle timer)
{
	OnAutoConfigsBuffered();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iLogPos = g_hCvarLogPos.IntValue;
	g_bAutoFix = g_hCvarAutoFix.BoolValue;
	g_bFixNonDefaults = g_hCvarFixNonDefaults.BoolValue;
	g_bFixOnRoundStart = g_hCvarFixOnRoundStart.BoolValue;
	g_bFixServerLast = g_hCvarServerOverwrite.BoolValue;
	g_iCheckAreas = g_hCvarAreas.IntValue;
	g_hCvarServerCfg.GetString(g_sServerCfg, sizeof(g_sServerCfg));
	Format(g_sServerCfg, sizeof(g_sServerCfg), "cfg/%s", g_sServerCfg);
	
	if (g_iCheckAreas == 0 || g_iCheckAreas == 4) // old version compatibility
		g_iCheckAreas = -1;
	
	SplitCvarToArrayList(g_hCvarCfgsInclude, "*", g_hArrayCfg);
	SplitCvarToArrayList(g_hCvarCfgsExclude, "*", g_hArrayCfgExclude);
	SplitCvarToArrayList(g_hCvarCVarExclude, "*", g_hArrayCvarExclude);
}

void SplitCvarToArrayList(ConVar cvar, char[] delim, ArrayList al)
{
	static char aItem[MAX_CVAR_ITEMS][PLATFORM_MAX_PATH];
	static char sValue[MAX_CVAR_VALUE_LENGTH];
	int iCount;

	al.Clear();
	cvar.GetString(sValue, sizeof(sValue));
	if (strlen(sValue) != 0) {
		iCount = ExplodeString(sValue, delim, aItem, MAX_CVAR_ITEMS, PLATFORM_MAX_PATH);
		for (int i = 0; i < iCount; i++) {
			al.PushString(aItem[i]);
		}
	}
}

// retrieving the list of commands
//
void FillCmds() // thanks to SilverShot
{
	static char name[MAX_CVAR_NAME_LENGTH];
	Handle hCmd;
	bool isCommand;
	
	g_hArrayCmds.Clear();
	
	hCmd = FindFirstConCommand(name, sizeof(name), isCommand);
	if(hCmd != INVALID_HANDLE)
	{
		do {
			if( isCommand )
			{
				ReplaceString(name, sizeof(name), "\n", "");
				g_hArrayCmds.PushString(name);
			}
		} while( FindNextConCommand(hCmd, name, sizeof(name), isCommand) );
	}
}

// apply ConVar fix before OnMapStart() forward, so another plugins will be able to precache objects with correct (fixed) names.
//
public void OnAutoConfigsBuffered()
{
	CompareConfigs2(0, g_bAutoFix);
}

public Action CmdConfigsCompare2(int client, int args)
{
	CompareConfigs2(client, false);
	return Plugin_Handled;
}

public Action CmdConfigsFix(int client, int args)
{
	CompareConfigs2(client, true);
	return Plugin_Handled;
}

// Check anomaly in all cfg-files and optionally make in-game fix
//
bool CompareConfigs2(int client, bool doFix)
{
	static char sLine[100], sMap[100];
	
	FormatTime(sLine, sizeof(sLine), "%F, %X", GetTime());
	GetCurrentMap(sMap, sizeof(sMap));
	Format(sLine, sizeof(sLine), "\n\n\n%s - Map: %s - %s\n", sLine, sMap, doFix ? "FIX" : "show");
	StringToLog(sLine);
	
	static char sFile[PLATFORM_MAX_PATH];
	int pos, iFiles, iCvars = 0;
	
	if (!g_bFixServerLast) {
		iCvars += CheckCfgAnomaly(client, g_sServerCfg, doFix);
		
		// process additional cfgs
		for (int i = 0; i < g_hArrayCfg.Length; i++) {
			g_hArrayCfg.GetString(i, sFile, sizeof(sFile));
			if (strcmp(sFile, g_sServerCfg, false) != 0) { // backward compatibility
				iFiles++;
				iCvars += CheckCfgAnomaly(client, sFile, doFix);
			}
		}
	}
	
	static char sDir[PLATFORM_MAX_PATH] = "cfg/sourcemod/";
	FileType filetype;
	DirectoryListing hDir = OpenDirectory(sDir);
	if( hDir == null )
	{
		PrintConsoles(client, "Could not open the directory \"cfg/sourcemod\".");
		return false;
	}
	
	while( hDir.GetNext(sFile, sizeof(sFile), filetype) )
	{
		if( filetype == FileType_File )
		{
			pos = FindCharInString(sFile, '.', true);
			if( pos != -1 && strcmp(sFile[pos], ".cfg", false) == 0 )
			{
				Format(sFile, sizeof(sFile), "cfg/sourcemod/%s", sFile);

				if (g_hArrayCfgExclude.FindString(sFile) == -1) {
					iFiles++;					
					iCvars += CheckCfgAnomaly(client, sFile, doFix);
				}
			}
		}
	}
	
	if (g_bFixServerLast) {
		iCvars += CheckCfgAnomaly(client, g_sServerCfg, doFix);
		
		// process additional cfgs
		for (int i = 0; i < g_hArrayCfg.Length; i++) {
			g_hArrayCfg.GetString(i, sFile, sizeof(sFile));
			if (strcmp(sFile, g_sServerCfg, false) != 0) { // backward compatibility
				iFiles++;
				iCvars += CheckCfgAnomaly(client, sFile, doFix);
			}
		}
	}
	
	PrintConsoles(client, "Total Files: %i (ConVars: %i)", iFiles, iCvars);
	
	g_hArrayCvarList.Clear();
	g_hArrayCvarValues.Clear();
	g_hArrayCvarDuplicates.Clear();
	g_hArrayCmdLen.Clear();
	delete hDir;
	
	CloseLog();
	return true;
}

// Check anomaly by specified file and optionally make in-game fix
//
int CheckCfgAnomaly(int client, const char sFile[PLATFORM_MAX_PATH], bool doFix)
{
	int iCount, iTotal, iCmdLen, iFlags;
	static char sCvarName[MAX_CVAR_NAME_LENGTH];
	static char sCfgValue[MAX_CVAR_VALUE_LENGTH];
	static char sCvarValueOld[MAX_CVAR_VALUE_LENGTH];
	static char sCvarValueCur[MAX_CVAR_VALUE_LENGTH];
	static char sCvarValueDef[MAX_CVAR_VALUE_LENGTH];
	ConVar hCvar;
	float min, max, fCfgValue;
	bool hasMin, hasMax;

	g_hArrayCvarList.Clear();
	g_hArrayCvarValues.Clear();
	g_hArrayCmdLen.Clear();
	
	// parse cfg
	if (!ProcessConfigA(client, ".", sFile))
		return 0;

	// enum list of cvar names
	for (int i = 0; i < g_hArrayCvarList.Length; i++) {
		iTotal++;
		g_hArrayCvarList.GetString(i, sCvarName, sizeof(sCvarName));

		// check excludes
		if (g_hArrayCvarExclude.FindString(sCvarName) != -1)
			continue;

		// check for duplicates
		if (!doFix && (g_iCheckAreas & 16)) {
			if (g_hArrayCvarDuplicates.FindString(sCvarName) != -1) {
				g_hArrayCvarValues.GetString(i, sCfgValue, sizeof(sCfgValue));
				PrintConsoles(client, "ConVar is duplicated. Cfg: %s, Cvar: %s, CfgValue: %s", sFile, sCvarName, sCfgValue);
			}
			else {
				g_hArrayCvarDuplicates.PushString(sCvarName);
			}
		}
		
		// check the convar exist (registered)
		if ((hCvar = FindConVar(sCvarName)) != null) {
			iCount++;
			g_hArrayCvarValues.GetString(i, sCfgValue, sizeof(sCfgValue));
			hCvar.GetString(sCvarValueCur, sizeof(sCvarValueCur));
			hCvar.GetDefault(sCvarValueDef, sizeof(sCvarValueDef));
			
			// check for min/max value excess
			if (!doFix && (g_iCheckAreas & 8)) {
				
				hasMin = hCvar.GetBounds(ConVarBound_Lower, min);
				hasMax = hCvar.GetBounds(ConVarBound_Upper, max);
			
				if (hasMin || hasMax) {
					if (!IsNumeric(sCfgValue)) {
						PrintConsoles(client, "Cfg value should be numeric. Cfg: %s, Cvar: %s, CfgValue: %s", sFile, sCvarName, sCfgValue);
					} else {
						fCfgValue = StringToFloat(sCfgValue);
						if (hasMin && fCfgValue < min)
							PrintConsoles(client, "Cfg value is too small. Cfg: %s, Cvar: %s, CfgValue: %s (min: %f)", sFile, sCvarName, sCfgValue, min);
						if (hasMax && fCfgValue > max)
							PrintConsoles(client, "Cfg value is too big. Cfg: %s, Cvar: %s, CfgValue: %s (max: %f)", sFile, sCvarName, sCfgValue, max);
					}
				}
				if (strcmp(sCfgValue, "-2147483648") == 0) {
					PrintConsoles(client, "Cfg value is too big. Cfg: %s, Cvar: %s, Value: %s, CfgValue: %s (max: 2147483647)", sFile, sCvarName, sCvarValueCur, sCfgValue);
				}
				
				iCmdLen = g_hArrayCmdLen.Get(i);
				if (iCmdLen > 511) {
					PrintConsoles(client, "Command is too long (current length: %i, max: 511). Cfg: %s, Cvar: %s, Value: %s, CfgValue: %s", iCmdLen, sFile, sCvarName, sCvarValueCur, sCfgValue);
				}
			}
			
			// check for value not match cfg
			if ((g_iCheckAreas & 1) && !IsCvarValuesEqual(sCvarValueCur, sCfgValue)) {
				
				// do fix if only the value equal to its defaults (some values can be changed by 3-rd party plugins specially)
				if (g_bFixNonDefaults || IsSpecificDefaultsCvar(sCvarName) || IsCvarValuesEqual(sCvarValueCur, sCvarValueDef)) {
					if (!doFix)
						PrintConsoles(client, "ConVar value is different. Cfg: %s, Cvar: %s, Value: %s (default: %s), should be: %s", 
							sFile, sCvarName, sCvarValueCur, sCvarValueDef, sCfgValue);

					if (doFix) {
						strcopy(sCvarValueOld, sizeof(sCvarValueOld), sCvarValueCur);
						iFlags = hCvar.Flags;
						hCvar.Flags = hCvar.Flags &~ FCVAR_NOTIFY;
						hCvar.SetString(sCfgValue, true, false);
						hCvar.Flags = iFlags;
						
						// check result again
						hCvar.GetString(sCvarValueCur, sizeof(sCvarValueCur));
						if (strcmp(sCvarValueCur, sCfgValue, false) != 0 && !IsSpecificAssignmentCvar(sCvarName)) {
							PrintConsoles(client, "FAILURE. Unable to fix value of convar: %s (Value: %s, should be: %s)", sCvarName, sCvarValueCur, sCfgValue);
						} else {
							PrintConsoles(client, "Successfully changed convar: %s (Old value: %s, New value: %s)", sCvarName, sCvarValueOld, sCvarValueCur);
						}
					}
				}
				else {
					PrintConsoles(client, "WARNING. Possibly, convar changed by 3-rd party plugin. It will not be fixed. Cfg: %s, Cvar: %s, Value: %s (default: %s), should be: %s", 
						sFile, sCvarName, sCvarValueCur, sCvarValueDef, sCfgValue);
				}
			}
		} else {
			if (!doFix && (g_iCheckAreas & 2) && g_hArrayCmds.FindString(sCvarName) == -1 )
				PrintConsoles(client, "ConVar is not used: %s, cfg: %s", sCvarName, sFile);
		}
	}
	return iTotal;
}

// some specific excludes (e.g. it have default value that cannot be read via GetDefault())
bool IsSpecificDefaultsCvar(char[] sCvarName)
{
	// Cvar: sv_gametypes, Value: coop,survival,versus,teamversus (default: ), should be: coop
	return (strcmp(sCvarName, "sv_gametypes") == 0);
}

// some specific assignment rules cvar (e.g. alphabetical order of values after assignment)
bool IsSpecificAssignmentCvar(char[] sCvarName)
{
	// (Value: addons,bloody,fun,no-steam,witch, should be: no-steam,addons,bloody,witch,fun)
	return (strcmp(sCvarName, "sv_tags") == 0 ||
			strcmp(sCvarName, "sv_steamgroup") == 0);
}

// compare two string values by float rules
//
bool IsCvarValuesEqual(char[] sValue1, char[] sValue2)
{
	bool err1, err2;
	float fValue1, fValue2;
	fValue1 = ParseFloat(sValue1, err1);
	fValue2 = ParseFloat(sValue2, err2);
	
	if (!err1 && !err2)
		if (AreFloatAlmostEqual(fValue1, fValue2))
			return (true);
	
	if (err1 ^ err2)
		return (false);

	return (strcmp(sValue1, sValue2, false) == 0);
}

// compare two float numbers (thanks to @hmmmmm {alliedmods.net})
//
bool AreFloatAlmostEqual(float a, float b, float precision = 0.001)
{
    return FloatAbs( a - b ) <= precision;
}

// convert string to float and return err == false on success.
//
float ParseFloat(char[] Str, bool &err)
{
	if (IsNumeric(Str)) {
		err = false;
		return (StringToFloat(Str));
	} else {
		err = true;
	}
	return 0.0;
}

// parse cfg file and save Cvar names and values to ArrayLists: g_hArrayCvarList / g_hArrayCvarValues (thanks @SilverShot for initial parser work)
//
bool ProcessConfigA(int client, const char sFolder[PLATFORM_MAX_PATH], const char sFile[PLATFORM_MAX_PATH])
{
	static char sPath[PLATFORM_MAX_PATH];
	Format(sPath, sizeof(sPath), "%s/%s", sFolder, sFile); // not FormatEx !!!
	
	if (!FileExists(sPath))
	{
		PrintConsoles(client, "Can't process cfg file. Not exist: \"%s\".", sPath);
		return false;
	}

	File hFile = OpenFile(sPath, "r");
	if( hFile == null )
	{
		PrintConsoles(client, "Failed to open \"%s\".", sPath);
		return false;
	}

	static char sValue[1024];
	static char sLine[1024];
	int pos, iCmdLen;
	
	while( !hFile.EndOfFile() && hFile.ReadLine(sLine, sizeof(sLine)) )
	{
		iCmdLen = strlen(sLine);
		TrimString(sLine);

		if( sLine[0] != '\x0' && sLine[0] != '/' && sLine[1] != '/' )
		{
			if( strlen(sLine) > 5 )
			{
				pos = FindCharInString(sLine, ' ');			// Format: CVAR VALUE
				if( pos != -1 )
				{
					strcopy(sValue, sizeof(sValue), sLine[pos + 1]);
					sLine[pos] = '\x0';

					if (strcmp(sLine, "sm_cvar") == 0) {	// Format: sm_cvar CVAR VALUE
						strcopy(sLine, sizeof(sLine), sValue); // value => initial line
						pos = FindCharInString(sLine, ' ');    // repeat same parsing
						if( pos == -1 ) {
							continue; // empty VALUE
						} else {
							strcopy(sValue, sizeof(sValue), sLine[pos + 1]);
							sLine[pos] = '\x0';
						}
					}
					sValue = UnQuote(sValue); // strip spaces and comments, aware quotation
					g_hArrayCvarList.PushString(sLine);
					g_hArrayCvarValues.PushString(sValue);
					g_hArrayCmdLen.Push(iCmdLen);
					
					if (strcmp(sLine, "exec") == 0)
					{
						FormatEx(sPath, sizeof(sPath), "./cfg/%s", sValue);
						if (!FileExists(sPath))
						{
							StrCat(sPath, sizeof(sPath), ".cfg");
							if (!FileExists(sPath))
								sPath[strlen(sPath) - 4] = '\0'; // revert
						}
						ProcessConfigA(client, ".", sPath);	// recurse!
					}
					else if (strcmp(sLine, "sm_execcfg") == 0)
					{
						FormatEx(sPath, sizeof(sPath), "./cfg/%s", sValue);
						{
							ProcessConfigA(client, ".", sPath);	// recurse!
						}
					}
					
				}
			}
		}
	}
	delete hFile;
	return true;
}

// value for cvar can be quoted (CvarName "value") or not quoted (CvarName Value).
//
char[] UnQuote(char[] Str)
{
	int pos;
	static char EndChar;
	static char buf[MAX_CVAR_VALUE_LENGTH];
	strcopy(buf, sizeof(buf), Str);
	TrimString(buf);
	if (buf[0] == '\"') {
		EndChar = '\"';
		strcopy(buf, sizeof(buf), buf[1]);
	} else {
		EndChar = ' ';
	}
	pos = FindCharInString(buf, EndChar);
	if( pos != -1 ) {
		buf[pos] = '\x0';
	}
	return buf;
}

// fix issue with trying to display in colsole cvar value with % specifier, or escape character
//
char[] EscapeString(char[] Str)
{
	static char buf[MAX_CVAR_VALUE_LENGTH];
	strcopy(buf, sizeof(buf), Str);
	ReplaceString(buf, sizeof(buf), "%", "%%");
	ReplaceString(buf, sizeof(buf), "\\", "\\\\");
	return buf;
}

// check if string is a valid number
//
bool IsNumeric(char[] value)
{
/*
	static Regex regex;
	if (regex == null)
		regex = new Regex("^(((\\+|-)?\\d+(\\.\\d+)?)|((\\+|-)?\\.\\d+))(e(\\+|-)\\d+)?$", PCRE_CASELESS);
	if (strlen(Str) == 0) return (false);
	return (regex.Match(Str) > 0);
*/

	// thanks to @Neuro Toxin

	bool canbeint = true;
	bool canbefloat = false;
	int byte;
	//int val;
	
	for (int i = 0; (byte = value[i]) != 0; i++)
	{
		// 48 = `0`, 57 = `9`, 46 = `.`, 45 = `-`
		if (byte < 48 || byte > 57)
		{
			// allow negative
			if (i == 0 && byte == 45)
				continue;
			
			// cant be an int anymore
			canbeint = false;
			
			// allow floats
			if (byte == 46)
			{
				// dont allow multiple periods
				if (canbefloat)
				{
					canbefloat = false;
					break;
				}
				canbeint = false;
				canbefloat = true;
			}
		}
		
		if (!canbeint && !canbefloat)
			break;
	}
	
	if (canbeint)
	{
		//val = StringToInt(value);
		return true;
	}
	else if (canbefloat)
	{
		// StringToFloat(value)
		return true;
	}
	return false;
}

// print log to rcon/client consoles and file
//
void PrintConsoles(int client, const char[] format, any ...)
{
	if (g_iLogPos == 0)
		return;
	static char buffer[1024], buf2[1024];
	VFormat(buffer, sizeof(buffer), format, 3);
	FormatEx(buf2, sizeof(buf2), "[CVar_Anomaly]: %s", buffer);
	if ((g_iLogPos & 1) && client != 0 && IsClientInGame(client))
		PrintToConsole(client, EscapeString(buf2));
	if (g_iLogPos & 2)
		PrintToServer(EscapeString(buf2));
	if (g_iLogPos & 4)
		StringToLog(buf2);
}
void OpenLog(char[] access)
{
	if ((g_iLogPos & 4 == 0) || g_hLog != null) return;
	g_hLog = OpenFile(g_sLogPath, access);
	if( g_hLog == null )
	{
		LogError("[CVar_Anomaly] Failed to open or create log file: %s (access: %s)", g_sLogPath, access);
		return;
	}
}
void CloseLog()
{
	if (g_hLog) {
		g_hLog.Close();
		g_hLog = null;
	}
}
void StringToLog(char[] Str)
{
	if (g_hLog == null) {
		OpenLog("a+");
	}
	if (g_hLog) {
		g_hLog.WriteLine(Str);
		FlushFile(g_hLog);
	}
}
