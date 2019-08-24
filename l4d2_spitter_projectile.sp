#define PLUGIN_VERSION 		"1.0"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Spitter Projectile Creator
*	Author	:	SilverShot
*	Descrp	:	Provides two commands to creates the Spitter projectile and drop the Spitter goo.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=316763
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0 (09-Jun-2019)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint function.
	http://forums.alliedmods.net/showthread.php?t=109659

*	"Timocop" for "L4D2_RunScript" function.
	https://forums.alliedmods.net/showpost.php?p=2585717&postcount=2

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define GAMEDATA		"l4d2_spitter_projectile"



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Spitter Projectile Creator",
	author = "SilverShot",
	description = "Provides two commands to creates the Spitter projectile and drop the Spitter goo.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=316763"
}

Handle sdkActivateSpit, g_hSpitVelocity;

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile(GAMEDATA);
	if( hGameConf == null )
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CSpitterProjectile_Create") == false )
		SetFailState("Could not load the \"CSpitterProjectile_Create\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkActivateSpit = EndPrepSDKCall();
	if( sdkActivateSpit == null )
		SetFailState("Could not prep the \"CSpitterProjectile_Create\" function.");

	CreateConVar("l4d2_spitter_projectile_version", PLUGIN_VERSION, "Spitter Projectile plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hSpitVelocity = FindConVar("z_spit_velocity");

	RegAdminCmd("sm_spitter_prj", Command_SpitterPrj, ADMFLAG_ROOT, "Shoots the Spitter projectile from yourself to where you're aiming.");
	RegAdminCmd("sm_spitter_goo", Command_SpitterGoo, ADMFLAG_ROOT, "Drops Spitter goo where you're aiming the crosshair.");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action Command_SpitterPrj(int client, int args)
{
	if( !client ) return Plugin_Handled;

	float vPos[3], vAng[3];
	GetClientEyeAngles(client, vAng);
	GetClientEyePosition(client, vPos);
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAng, vAng);
	ScaleVector(vAng, GetConVarFloat(g_hSpitVelocity));

	SDKCall(sdkActivateSpit, vPos, vAng, vAng, vAng, client);

	// If you want the projectile entity index, for example to set the owner.
	// int entity = SDKCall(sdkActivateSpit, vPos, vAng, vAng, vAng, client);
	// SetEntPropEnt(entity, Prop_Data, "m_hThrower", -1);
	return Plugin_Handled;
}

public Action Command_SpitterGoo(int client, int args)
{
	if( !client ) return Plugin_Handled;

	float vPos[3], vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		PrintToChat(client, "Cannot place Spitter Goo, please try again.");
		return Plugin_Handled;
	}

	L4D2_RunScript("DropSpit(Vector(%f %f %f))", vPos[0], vPos[1], vPos[2]);
	return Plugin_Handled;
}



// ====================================================================================================
//					STOCKS
// ====================================================================================================
bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if(TR_DidHit(trace))
	{
		float vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		float angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		vPos[2] += 5.0;

		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += angle;
		}
		else
		{
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
		}
	}
	else
	{
		delete trace;
		return false;
	}
	delete trace;
	return true;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}



/**
* Runs a single line of VScript code.
* NOTE: Dont use the "script" console command, it starts a new instance and leaks memory. Use this instead!
*
* @param sCode        The code to run.
* @noreturn
*/
stock void L4D2_RunScript(char[] sCode, any ...)
{
    static int iScriptLogic = INVALID_ENT_REFERENCE;
    if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
	{
        iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
        if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
            SetFailState("Could not create 'logic_script'");

        DispatchSpawn(iScriptLogic);
    }

    char sBuffer[64];
    VFormat(sBuffer, sizeof(sBuffer), sCode, 2);

    SetVariantString(sBuffer);
    AcceptEntityInput(iScriptLogic, "RunScriptCode");
}