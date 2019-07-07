#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"0.0"
#define CVAR_FLAGS		FCVAR_NEVER_AS_STRING|FCVAR_PROTECTED
#define CMD_FLAGS		ADMFLAG_GENERIC|ADMFLAG_CHEATS|ADMFLAG_CONVARS

public Plugin myinfo =
{
	name = "保存物品",
	description = "",
	author = "",
	version = PLUGIN_VERSION,
	url = ""
};
