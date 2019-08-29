#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required


#define PLUGIN_VERSION "1.0"

Handle hCvar_TurnRate = null;

Handle hCvar_FaceFrontTime 		= null;
Handle hCvar_FeetMaxYawRate 	= null;
Handle hCvar_FeetYawRate 		= null;
Handle hCvar_FeetYawRate_Max 	= null;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}
// this fixes bug in versus where tanks can curve rocks around the walls when set to high values
public Plugin myinfo =
{
	name = "幸存者模型转动速度",
	author = "Lux",
	description = "By default restores l4d1 world model turnrate.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2641104"
};

public void OnPluginStart()
{
	CreateConVar("worldmodel_turnrate_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_TurnRate = CreateConVar("worldmodel_turnrate", "2160", "Speed at which worldmodel turns to match viewmodel pitch angle, default l4d2 speed is [100], default of [2160] closely matches l4d1,", FCVAR_NOTIFY, true, 1.0, true, 9999999.0);
	hCvar_FaceFrontTime = FindConVar("mp_facefronttime");
	hCvar_FeetMaxYawRate = FindConVar("mp_feetmaxyawrate");
	hCvar_FeetYawRate = FindConVar("mp_feetyawrate");
	hCvar_FeetYawRate_Max = FindConVar("mp_feetyawrate_max");
	
	HookConVarChange(hCvar_TurnRate, eConvarChanged);
	HookConVarChange(hCvar_FaceFrontTime, eConvarChanged);
	HookConVarChange(hCvar_FeetMaxYawRate, eConvarChanged);
	HookConVarChange(hCvar_FeetYawRate, eConvarChanged);
	HookConVarChange(hCvar_FeetYawRate_Max, eConvarChanged);
	
	AutoExecConfig(true, "L4D2_WorldModel_Turnrate");
	
	CvarsChanged();
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	int iTurnRate = GetConVarInt(hCvar_TurnRate);
	SetConVarInt(hCvar_FaceFrontTime, -1, true);
	SetConVarInt(hCvar_FeetMaxYawRate, iTurnRate, true);
	SetConVarInt(hCvar_FeetYawRate, iTurnRate, true);
	SetConVarInt(hCvar_FeetYawRate_Max, iTurnRate, true);
}