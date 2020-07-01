/****************************************************************************************************
[ANY] EDICT OVERFLOW PREVENTION
*****************************************************************************************************/

#define PLUGIN_VERSION "2.9"
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "实体字典溢出保护", 
	author = "SM9 (xCoderx)", 
	version = PLUGIN_VERSION, 
	url = "www.fragdeluxe.com"
};

public void OnPluginStart() {
	CreateConVar("eop_version", PLUGIN_VERSION, "Edict Overflow Prevention", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
}

public void OnGameFrame()
{
	for (int iEntity = 2044; iEntity <= 2048; iEntity++) {
		if (!IsValidEntity(iEntity) || !IsValidEdict(iEntity)) {
			continue;
		}
		
		AcceptEntityInput(iEntity, "Kill");
	}
}

public void OnEntityCreated(int iEntity)
{
	if(iEntity >= 2044) {
		SDKHookEx(iEntity, SDKHook_Spawn, OnEntitySpawn);
	}
}

public Action OnEntitySpawn(int iEntity) {
	// AcceptEntityInput(iEntity, "Kill");
	if(IsValidEntity(iEntity) && IsValidEdict(iEntity))
		RemoveEntity(iEntity);
	return Plugin_Handled;
}