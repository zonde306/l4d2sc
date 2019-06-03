#if defined _smac_included
  #endinput
#endif
#define _smac_included

#include <smac_stocks>

/* Globals */
#define SMAC_VERSION	"0.8.5.1"
#define SMAC_URL		"http://smac.sx"
#define SMAC_AUTHOR		"SMAC Development Team"
#define SMAC_MOD_ERROR	"This module will not work for this mod and should be removed."

enum GameType {
	Game_Unknown = 0,
	Game_CSS,
	Game_TF2,
	Game_DODS,
	Game_INSMOD,
	Game_L4D,
	Game_L4D2,
	Game_HL2DM,
	Game_FOF,
	Game_GMOD,
	Game_HL2CTF,
	Game_HIDDEN,
	Game_ND,
	Game_CSGO,
};

enum DetectionType {
	Detection_Unknown = 0,
	
	Detection_Aimbot,
	Detection_AutoTrigger,
	Detection_NameChangeSpam,
	Detection_CommandSpamming,
	Detection_BannedCommand,
	Detection_CvarPlugin,
	Detection_CvarNotEqual,
	Detection_CvarNotGreater,
	Detection_CvarNotLess,
	Detection_CvarNotBound,
	Detection_UserCmdReuse,
	Detection_UserCmdTamperingTickcount,
	Detection_UserCmdTamperingButtons,
	Detection_Eyeangles,
	Detection_Speedhack,
	Detection_Spinhack,
	
	// ban lists
	Detection_GlobalBanned_EAC,
	Detection_GlobalBanned_ESEA,
	Detection_GlobalBanned_KAC,
	
	// game specific
	Detection_GravityGunExploit, // hl2dm
};

/* Natives */
native GameType:SMAC_GetGameType();
native SMAC_Log(const String:format[], any:...);
native SMAC_LogAction(client, const String:format[], any:...);
native SMAC_Ban(client, const String:reason[], any:...);
native SMAC_PrintAdminNotice(const String:format[], any:...);
native Handle:SMAC_CreateConVar(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0);
native Action:SMAC_CheatDetected(client, DetectionType:type = Detection_Unknown, Handle:info = INVALID_HANDLE);

/* Forwards */
forward Action:SMAC_OnCheatDetected(client, const String:module[], DetectionType:type, Handle:info);


public SharedPlugin:__pl_smac = 
{
	name = "smac",
	file = "smac.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_smac_SetNTVOptional()
{
	MarkNativeAsOptional("SMAC_GetGameType");
	MarkNativeAsOptional("SMAC_Log");
	MarkNativeAsOptional("SMAC_LogAction");
	MarkNativeAsOptional("SMAC_Ban");
	MarkNativeAsOptional("SMAC_PrintAdminNotice");
	MarkNativeAsOptional("SMAC_CreateConVar");
	MarkNativeAsOptional("SMAC_CheatDetected");
}
#endif
