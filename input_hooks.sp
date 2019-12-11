#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[ANY] Input Hooks - DevTools
*	Author	:	SilverShot
*	Descrp	:	Prints entity inputs, with classname filtering.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=319141
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (15-Nov-2019)
	- Fixed multiple classnames not working for the watch command and cvars.

1.0 (14-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"input_hooks.games"
#define MAX_ENTS			4096
#define LEN_CLASS			64



ConVar g_hCvarFilter, g_hCvarListen;
ArrayList g_aFilter, g_aListen, g_aWatch;
Handle gAcceptInput;
bool g_bWatch[MAXPLAYERS+1];
int g_iHookID[MAX_ENTS];
int g_iInputHookID[MAX_ENTS];
int g_iListenInput;

// char USE_TYPE[][] =
// {
	// "USE_OFF",
	// "USE_ON",
	// "USE_SET",
	// "USE_TOG"
// };



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[ANY] Input Hooks - DevTools",
	author = "SilverShot",
	description = "Prints entity inputs, with classname filtering.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=319141"
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if( hGamedata == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	int offset = GameConfGetOffset(hGamedata, "AcceptInput");
	if( offset == 0 ) SetFailState("Failed to load \"AcceptInput\", invalid offset.");

	gAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
	DHookAddParam(gAcceptInput, HookParamType_CharPtr);
	DHookAddParam(gAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(gAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(gAcceptInput, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP); //varaint_t is a union of 12 (float[3]) plus two int type params 12 + 8 = 20
	DHookAddParam(gAcceptInput, HookParamType_Int);



	// ====================================================================================================
	// CVARS CMDS ARRAYS
	// ====================================================================================================
	g_hCvarFilter = CreateConVar(	"sm_input_hooks_filter",		"",						"Do not hook and show input data from these classnames, separate by commas (no spaces). Only works for sm_input_listen command.", CVAR_FLAGS );
	g_hCvarListen = CreateConVar(	"sm_input_hooks_listen",		"",						"Only hook and display input data from these classnames, separate by commas (no spaces). Only works for sm_input_listen command.", CVAR_FLAGS );
	CreateConVar(					"sm_input_hooks_version",		PLUGIN_VERSION,			"Input Hooks plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"sm_input_hooks");

	g_hCvarFilter.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarListen.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd("sm_input_listen",		CmdListen,					ADMFLAG_ROOT,	 		"Starts listening to all inputs. Filters or listens for classnames from the filter and listen cvars.");
	RegAdminCmd("sm_input_stop",		CmdStop,					ADMFLAG_ROOT,	 		"Stop printing entity inputs.");
	RegAdminCmd("sm_input_watch",		CmdWatch,					ADMFLAG_ROOT,	 		"Start printing entity inputs. Usage: sm_input_watch <classnames to watch, separate by commas>");

	g_aFilter = new ArrayList(ByteCountToCells(LEN_CLASS));
	g_aListen = new ArrayList(ByteCountToCells(LEN_CLASS));
	g_aWatch = new ArrayList(ByteCountToCells(LEN_CLASS));

	GetCvars();
}



// ====================================================================================================
// CVARS
// ====================================================================================================
public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	if( g_iListenInput == 1 )
	{
		UnhookAll();
		ListenAll();
	}
}

void GetCvars()
{
	int pos, last;
	char sCvar[4096];
	g_aFilter.Clear();
	g_aListen.Clear();

	// Filter list
	g_hCvarFilter.GetString(sCvar, sizeof(sCvar));
	if( sCvar[0] != 0 )
	{
		StrCat(sCvar, sizeof sCvar, ",");

		while( (pos = FindCharInString(sCvar[last], ',')) != -1 )
		{
			sCvar[pos + last] = 0;
			g_aFilter.PushString(sCvar[last]);
			last += pos + 1;
		}
	}

	// Listen list
	g_hCvarListen.GetString(sCvar, sizeof(sCvar));
	if( sCvar[0] != 0 )
	{
		StrCat(sCvar, sizeof sCvar, ",");

		pos = 0;
		last = 0;
		while( (pos = FindCharInString(sCvar[last], ',')) != -1 )
		{
			sCvar[pos + last] = 0;
			g_aListen.PushString(sCvar[last]);
			last += pos + 1;
		}
	}
}



// ====================================================================================================
// COMMANDS
// ====================================================================================================
public Action CmdListen(int client, int args)
{
	g_bWatch[client] = true;
	g_iListenInput = 1;
	UnhookAll();
	ListenAll();
	return Plugin_Handled;
}

public Action CmdStop(int client, int args)
{
	g_aWatch.Clear();
	g_bWatch[client] = false;
	g_iListenInput = 0;
	UnhookAll();
	return Plugin_Handled;
}

public Action CmdWatch(int client, int args)
{
	if( args != 1 )
	{
		ReplyToCommand(client, "Usage: sm_input_watch <classnames to watch, separate by commas>");
		return Plugin_Handled;
	}

	// Watch list
	int pos, last;
	char sCvar[4096];
	GetCmdArg(1, sCvar, sizeof sCvar);
	g_aWatch.Clear();

	if( sCvar[0] != 0 )
	{
		StrCat(sCvar, sizeof sCvar, ",");

		while( (pos = FindCharInString(sCvar[last], ',')) != -1 )
		{
			sCvar[pos + last] = 0;
			g_aWatch.PushString(sCvar[last]);
			last += pos + 1;
		}
	}

	// Find
	UnhookAll();
	g_bWatch[client] = true;
	g_iListenInput = 2;

	int i = -1;
	for( int index = 0; index < g_aWatch.Length; index++ )
	{
		g_aWatch.GetString(index, sCvar, sizeof sCvar);

		while( (i = FindEntityByClassname(i, sCvar)) != INVALID_ENT_REFERENCE )
		{
			g_iHookID[i] = DHookEntity(gAcceptInput, false, i);
		}
	}

	return Plugin_Handled;
}



// ====================================================================================================
// LISTEN
// ====================================================================================================
void ListenAll()
{
	char classname[LEN_CLASS];
	for( int i = 0; i < MAX_ENTS; i++ )
	{
		if( IsValidEdict(i) )
		{
			GetEntPropString(i, Prop_Data, "m_iClassname", classname, sizeof classname); // Because GetEdictClassname fails for non-networked entities.
			OnEntityCreated(i, classname);
		}
	}
}

void UnhookAll()
{
	for( int i = 0; i < MAX_ENTS; i++ )
	{
		if( g_iHookID[i] )
		{
			DHookRemoveHookID(g_iHookID[i]);
			g_iHookID[i] = 0;
		}
		if( g_iInputHookID[i] )
		{
			DHookRemoveHookID(g_iInputHookID[i]);
			g_iInputHookID[i] = 0;
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_iListenInput == 0 )													return;
	if( g_iListenInput == 1 )
	{
		if( g_aFilter.Length != 0 && g_aFilter.FindString(classname) != -1 )	return;
		if( g_aListen.Length != 0 && g_aListen.FindString(classname) == -1 )	return;
	} else {
		if( g_aWatch.FindString(classname) == -1 )								return;
	}

	if( entity < 0 )
		entity = EntRefToEntIndex(entity);

	g_iHookID[entity] = DHookEntity(gAcceptInput, false, entity);
}

public MRESReturn AcceptInput(int pThis, Handle hReturn, Handle hParams)
{
	// Get args
	char command[128];
	DHookGetParamString(hParams, 1, command, sizeof(command));

	char param[128];
	DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, param, sizeof(param));

	char classname[LEN_CLASS];
	GetEntPropString(pThis, Prop_Data, "m_iClassname", classname, sizeof classname);

	if( pThis < 0 )
		pThis = EntRefToEntIndex(pThis);

	int entity = -1;
	if( DHookIsNullParam(hParams, 2) == false )
		entity = DHookGetParam(hParams, 2);

	// Activator + classname
	char activator[LEN_CLASS];
	if( entity != -1 )
	{
		if( entity > 0 && entity <= MaxClients )
			Format(activator, sizeof activator, "%N", entity);
		else
		{
			GetEntPropString(entity, Prop_Data, "m_iClassname", activator, sizeof activator);
			if( entity < 0 )
				entity = EntRefToEntIndex(entity);
		}
	}

	// Print
	// int type = DHookGetParamObjectPtrVar(hParams, 4, 16, ObjectValueType_Int); // USE_TYPE[type]
	for( int i = 0; i <= MaxClients; i++ )
	{
		if( g_bWatch[i] )
		{
			if( i )
			{
				if( IsClientInGame(i) )
					PrintToChat(i, "\x01Ent %4d% \x04%20s \x01Cmd \x05%20s. \x01Param \x03%12s. \x01Act \x01%4d \x04%s", pThis, classname, command, param, entity, activator);
				else
					g_bWatch[i] = false;
			}
			else
				PrintToServer("%4d% %s. (%s). (%s). %d %s", pThis, classname, param, command, entity, activator);
		}
	}

	return MRES_Ignored;
}