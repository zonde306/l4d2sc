/************************************************************************
  [L4D] Pet Witch (v1.0.0, 2018-08-08)

  DESCRIPTION: 
  
    This plugin allows an admin to spawn a "pet witch" and attack a 
    selected player.

    Only admins with the slay flag can use it.

    I will explain how the menu works.

    In option 1 of the menu you can spawn one or more pet witches. The 
    pet is totally harmless (unless you or another player shoves her). 
    Other players cannot cause damage to the pet (but you, the owner, 
    can). This prevents other players from killing your pet witch, 
    unless, of course, she is ordered to attack. If you shove, shoot 
    or burn your own pet witch, this will cause damage to her, but you 
    will not suffer any damage when she attacks you.

    In option 2 you can select the target (only survivors) and 
    immediately start the attack.

    Finally, in option 3, you can kill all your pets at once.

    As an admin, you can use this plugin to apply a differentiated and 
    yet fun punishment to some other badly behaved player.

    This project is also available on my github:

    https://github.com/samuelviveiros/l4d_pet_witch

    And there is a demo video here:

    https://www.youtube.com/watch?v=59huDdHSRXc&feature=youtu.be


  COMMAND:

    sm_petwitch - Opens the plugin menu.


  CVARS:

    // Enable or disable this plugin.
    // -
    // Default: "1"
    // Minimum: "0.000000"
    // Maximum: "1.000000"
    l4d_pet_witch_enable "1"

    // [L4D] Pet Witch version
    // -
    // Default: "1.0.0"
    l4d_pet_witch_version "1.0.0"


  COMPILATION ISSUE:

    This plugin uses functions like SDKHook, SDKUnhook and HasEntProp 
    which cause compilation errors with the web compiler. You must to 
    compile this source code by yourself using the latest sourcemod 
    compiler version.


 ************************************************************************/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

/**
 * Compiler requires semicolons and the new syntax.
 */
#pragma semicolon 1
#pragma newdecls required

/**
 * Semantic versioning <https://semver.org/>
 */
#define PLUGIN_VERSION  "1.0.0"

#define PLUGIN_INITIALS "\x03[PW]\x01"

public Plugin myinfo = {
    name = "呼叫萌妹",
    author = "samuelviveiros a.k.a Dartz8901",
    description = "Allows an admin to spawn a Pet Witch and attack a selected player",
    version = PLUGIN_VERSION,
    url = "https://github.com/samuelviveiros/l4d_pet_witch"
};

#define TEAM_SURVIVORS              2
#define MAXEDICTS                   2048
#define WITCH_SEQUENCE_RUN_RETREAT  6
#define SAFE_RAGE                   0.5

int  g_TargetOfInvoker[MAXPLAYERS + 1]          = {-1, ...};
bool g_HasInvokerDamageHandler[MAXPLAYERS + 1]  = {false, ...};
int  g_InvokerOfPetWitch[MAXEDICTS + 1]         = {-1, ...};
int  g_SpawnerOfPetWitch[MAXEDICTS + 1]         = {-1, ...};
bool g_StartledByTriggerHurt[MAXEDICTS + 1]     = {false, ...};


public APLRes AskPluginLoad2(Handle myself,
                             bool late,
                             char[] error,
                             int err_max)
{
    EngineVersion engine = GetEngineVersion();
    if (engine != Engine_Left4Dead)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    CreateConVar("l4d_pet_witch_version", PLUGIN_VERSION, "[L4D] Pet Witch version", FCVAR_REPLICATED | FCVAR_NOTIFY);
    CreateConVar("l4d_pet_witch_enable", "1", "Enable or disable this plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    AutoExecConfig(true, "l4d_pet_witch");

    RegAdminCmd ("sm_petwitch", Command_ShowMenu, ADMFLAG_SLAY);

    HookEvent("witch_spawn", Event_WitchSpawn);
    HookEvent("witch_harasser_set", Event_WitchHarasserSet);
}

public void OnEntityDestroyed(int entity)
{
    char classname[128];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (StrEqual(classname, "witch"))
    {
        PetWitch_FreeResources(entity);
    }
}

public Action Event_WitchHarasserSet(Event event,
                                     const char[] sName,
                                     bool bDontBroadcast)
{
    int witch = event.GetInt("witchid");

    PetWitch_RemoveHooks(witch);
}

public Action Event_WitchSpawn(Event event,
                               const char[] sName,
                               bool bDontBroadcast)
{
    int witch = event.GetInt("witchid");

    SDKHook(witch, SDKHook_ThinkPost, PetWitch_ThinkHandler);
}


//----------------------------//
//    PET WITCH "METHODS"     //
//----------------------------//

public Action PetWitch_DamageHandler(int     petWitch,
                                     int&    attacker,
                                     int&    inflictor,
                                     float&  damage,
                                     int&    damagetype,
                                     int&    weapon,
                                     float   damageForce[3],
                                     float   damagePosition[3])
{
    // Only the invoker can cause direct damage.
    if (attacker == PetWitch_GetInvoker(petWitch))
    {
        return Plugin_Continue;
    }

    if (PetWitch_IsAttackerTriggerHurt(attacker))
    {
        PetWitch_StartledByTriggerHurt(petWitch, true);
        AcceptEntityInput(attacker, "Kill");
        PetWitch_RemoveHooks(petWitch);

        attacker = PetWitch_GetTarget(petWitch);
        inflictor = PetWitch_GetTarget(petWitch);

        return Plugin_Changed;
    }

    return Plugin_Handled;
}

void PetWitch_PerformSpawn(int invoker)
{
    float pos[3];
    GetClientAimPosition(invoker, pos);

    int spawner = SpawnWitchAt(pos);
    if (spawner != -1)
    {
        SetEntPropEnt(spawner, Prop_Send, "m_hOwnerEntity", invoker);
    }
    else
    {
        PrintToChat(invoker, "Could not spawn pet witch.");
    }
}

void PetWitch_ThinkHandler(int witch)
{
    if (!PetWitch_WasInitialized(witch))
    {
        if (PetWitch_IsValid(witch))
        {
            PetWitch_Init(witch);
        }
        else
        {
            // Ignore witch not spawned by commentary_zombie_spawner.
            SDKUnhook(witch, SDKHook_ThinkPost, PetWitch_ThinkHandler);
            return;
        }
    }

    PetWitch_KeepAngerLow(witch);

    if (PetWitch_IsRunningRetreated(witch))
    {
        PetWitch_RemoveHooks(witch);
    }
}

bool PetWitch_WasInitialized(int petWitch)
{
    return PetWitch_GetInvoker(petWitch) != -1;
}

bool PetWitch_IsValid(int witch)
{
    if (!IsValidWitch(witch))
    {
        return false;
    }

    if (!HasEntityOwner(witch))
    {
        return false;
    }

    int owner = GetEntityOwner(witch);

    if (!PetWitch_IsValidSpawner(owner))
    {
        return false;
    }

    return true;
}

bool PetWitch_IsValidSpawner(int owner)
{
    if (!HasEntProp(owner, Prop_Data, "m_iName"))
    {
        return false;
    }

    char targetname[128];
    GetEntPropString(
        owner,
        Prop_Data,
        "m_iName",
        targetname,
        sizeof(targetname)
    );

    if (!StrEqual(targetname, "pet_witch_spawner"))
    {
        return false;
    }

    return true;
}

void PetWitch_Init(int petWitch)
{
    PetWitch_SetSpawner(petWitch, GetEntityOwner(petWitch));
    PetWitch_SetupDamageHandler(petWitch);
    PetWitch_SetInvoker(petWitch, GetEntityOwner(GetEntityOwner(petWitch)));
}

int PetWitch_GetSpawner(int petWitch)
{
    return g_SpawnerOfPetWitch[petWitch];
}

void PetWitch_SetSpawner(int petWitch, int spawner)
{
    g_SpawnerOfPetWitch[petWitch] = spawner;
}

void PetWitch_SetupDamageHandler(int petWitch)
{
    SDKHook(petWitch, SDKHook_OnTakeDamage, PetWitch_DamageHandler);
}

int PetWitch_GetInvoker(int petWitch)
{
    return g_InvokerOfPetWitch[petWitch];
}

int PetWitch_SetInvoker(int petWitch, int invoker)
{
    g_InvokerOfPetWitch[petWitch] = invoker;
}

void PetWitch_KeepAngerLow(int petWitch)
{
    if (PetWitch_GetRage(petWitch) > SAFE_RAGE)
    {
        PetWitch_SetRage(petWitch, SAFE_RAGE);
    }
}

float PetWitch_GetRage(int petWitch)
{
    return GetEntPropFloat(petWitch, Prop_Send, "m_rage");
}

void PetWitch_SetRage(int petWitch, float rage)
{
    SetEntPropFloat(petWitch, Prop_Send, "m_rage", rage);
}

bool PetWitch_IsRunningRetreated(int petWitch)
{
    // The sequence 6 (Run_Retreat) will occur, for example, when a "closing 
    // door" collides with the Witch while in sequence 2 (Idle_Sitting).
    int currentSequence = PetWitch_GetCurrentSequence(petWitch);
    return (currentSequence == WITCH_SEQUENCE_RUN_RETREAT);
}

int PetWitch_GetCurrentSequence(int petWitch)
{
    return GetEntProp(petWitch, Prop_Send, "m_nSequence");
}

void PetWitch_FreeResources(int petWitch)
{
    PetWitch_RemoveHooks(petWitch);
    PetWitch_StartledByTriggerHurt(petWitch, false);
    PetWitch_SetInvoker(petWitch, -1);
    PetWitch_FreeSpawner(petWitch);
}

int PetWitch_RemoveHooks(int petWitch)
{
    SDKUnhook(petWitch, SDKHook_ThinkPost, PetWitch_ThinkHandler);
    SDKUnhook(petWitch, SDKHook_OnTakeDamage, PetWitch_DamageHandler);
}

void PetWitch_FreeSpawner(int petWitch)
{
    if (IsValidCommentaryZombieSpawner(PetWitch_GetSpawner(petWitch)))
    {
        AcceptEntityInput(PetWitch_GetSpawner(petWitch), "Kill");
        PetWitch_SetSpawner(petWitch, -1);
    }
}

int PetWitch_GetTarget(int petWitch)
{
    int invoker = PetWitch_GetInvoker(petWitch);
    int target = Invoker_GetTarget(invoker);

    return target;
}

void PetWitch_ForceAttack(int petWitch)
{
    float origin[3];
    GetEntityOrigin(petWitch, origin);
    SpawnTriggerHurtAt(origin);
}

void PetWitch_KillPet(int petWitch)
{
    //SetEntProp(witch, Prop_Data, "m_iMaxHealth", 1);
    SetEntProp(petWitch, Prop_Data, "m_iHealth", 1);

    float position[3];
    GetEntityOrigin(petWitch, position);

    SpawnTriggerHurtAt(position);
}

bool PetWitch_IsAttackerTriggerHurt(int attacker)
{
    if (attacker <= GetMaxClients())
    {
        return false;
    }

    if (!IsValidEntity(attacker))
    {
        return false;
    }

    char classname[128];
    GetEdictClassname(attacker, classname, sizeof(classname));

    if (!StrEqual(classname, "trigger_hurt"))
    {
        return false;
    }

    char targetname[128];
    GetEntPropString(
        attacker,
        Prop_Data,
        "m_iName",
        targetname,
        sizeof(targetname)
    );

    if (!StrEqual(targetname, "pet_witch_hurter"))
    {
        return false;
    }

    return true;
}

bool PetWitch_WasStartledByTriggerHurt(int petWitch)
{
    return g_StartledByTriggerHurt[petWitch];
}

void PetWitch_StartledByTriggerHurt(int petWitch, bool value)
{
    g_StartledByTriggerHurt[petWitch] = value;
}

stock bool PetWitch_WasStartled(int petWitch)
{
    int sequence = PetWitch_GetCurrentSequence(petWitch);
    return (
        sequence != 0
        && sequence != 2
        && sequence != 20
        && sequence != 22
    );
}


//----------------------------//
//    INVOKER "METHODS"       //
//----------------------------//

int Invoker_GetTarget(int invoker)
{
    return g_TargetOfInvoker[invoker];
}

int Invoker_SetTarget(int invoker, int target)
{
    g_TargetOfInvoker[invoker] = target;
}

int Invoker_ForcePetsToAttack(int invoker)
{
    int witch = -1;
    while ((witch = FindEntityByClassname(witch, "witch")) != -1)
    {
        if (PetWitch_IsValid(witch) && PetWitch_GetInvoker(witch) == invoker)
        {
            PetWitch_ForceAttack(witch);
        }
    }
}

void Invoker_KillAllPets(int invoker)
{
    int witch = -1;
    while ((witch = FindEntityByClassname(witch, "witch")) != -1)
    {
        if (PetWitch_IsValid(witch) && PetWitch_GetInvoker(witch) == invoker)
        {
            PetWitch_RemoveHooks(witch);
            PetWitch_KillPet(witch);
        }
    }
}

void Invoker_SetupDamageHandler(int invoker)
{
    g_HasInvokerDamageHandler[invoker] = true;
    SDKHook(invoker, SDKHook_OnTakeDamage, Invoker_DamageHandler);
}

bool Invoker_HasDamageHandler(int client)
{
    return g_HasInvokerDamageHandler[client];
}

void Invoker_FreeResources(int invoker)
{
    g_HasInvokerDamageHandler[invoker] = false;
    SDKUnhook(invoker, SDKHook_OnTakeDamage, Invoker_DamageHandler);
}

public Action Invoker_DamageHandler(int     invoker,
                                  int&    attacker,
                                  int&    inflictor,
                                  float&  damage,
                                  int&    damagetype,
                                  int&    weapon,
                                  float   damageForce[3],
                                  float   damagePosition[3])
{
    if (PetWitch_IsValid(attacker)
        && !PetWitch_WasStartledByTriggerHurt(attacker))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    if (Invoker_HasDamageHandler(client))
    {
        Invoker_FreeResources(client);
    }
}


//----------------------------//
//            MENU            //
//----------------------------//

public Action Command_ShowMenu(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "%s Command is in-game only.", PLUGIN_INITIALS);
        return Plugin_Handled;
    }

    ConVar cvarPluginEnable = FindConVar("l4d_pet_witch_enable");
    if (cvarPluginEnable != null && GetConVarFloat(cvarPluginEnable) == 0.0)
    {
        ReplyToCommand(client, "%s Plugin disabled. See the config file.", PLUGIN_INITIALS);
        return Plugin_Handled;
    }

    Menu_DisplayOptions(client);

    return Plugin_Handled;
}

void Menu_DisplayOptions(int client)
{
    Menu menu = new Menu(Menu_OptionsHandler);
    menu.SetTitle("刷 Witch");

    menu.AddItem("spawn", "刷一个 Witch");
    menu.AddItem("attack", "发动攻击");
    menu.AddItem("kill", "干掉刷出的 Witch");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_OptionsHandler(Menu menu,
                               MenuAction action,
                               int param1,
                               int param2)
{
    int invoker = param1;

    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
            {
                PetWitch_PerformSpawn(invoker);

                if (!Invoker_HasDamageHandler(invoker))
                {
                    Invoker_SetupDamageHandler(invoker);
                }

                Menu_DisplayOptions(invoker);
            }
            case 1:
            {
                Menu_DisplayTargets(invoker);
            }
            case 2:
            {
                Invoker_KillAllPets(invoker);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void Menu_AddSurvivorAsItem(Menu menu, int survivor)
{
    char indexAsString[8];
    IntToString(survivor, indexAsString, sizeof(indexAsString));

    char survivorName[MAX_NAME_LENGTH];
    GetClientName(survivor, survivorName, sizeof(survivorName));

    menu.AddItem(indexAsString, survivorName);
}

void Menu_DisplayTargets(int client)
{
    Menu menu = new Menu(Menu_TargetsHandler);
    menu.SetTitle("选择受害者:");

    for (int survivor = 1; survivor <= GetMaxClients(); survivor++)
    {
        if (IsSurvivorConnectedAndAlive(survivor))
        {
            Menu_AddSurvivorAsItem(menu, survivor);
        }
    }

    menu.ExitButton = false;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_TargetsHandler(Menu menu,
                               MenuAction action,
                               int param1,
                               int param2)
{
    int invoker = param1;

    if (action == MenuAction_Select)
    {
        char indexAsString[8];
        menu.GetItem(param2, indexAsString, sizeof(indexAsString));

        int target = StringToInt(indexAsString);
        Invoker_SetTarget(invoker, target);
        Invoker_ForcePetsToAttack(invoker);
    }
    else if (action == MenuAction_Cancel)
    {
        Menu_DisplayOptions(invoker);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}


//----------------------------//
//      USEFUL FUNCTIONS      //
//----------------------------//

bool IsValidWitch(int witch)
{
    if (witch <= GetMaxClients())
    {
        return false;
    }

    if (!IsValidEdict(witch))
    {
        return false;
    }

    char classname[128];
    GetEdictClassname(witch, classname, sizeof(classname));

    if (!StrEqual(classname, "witch"))
    {
        return false;
    }

    return true;
}

bool HasEntityOwner(int entity)
{
    int owner = GetEntityOwner(entity);
    return owner != -1 && IsValidEntity(owner);
}

int GetEntityOwner(int entity)
{
    return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

void GetEntityOrigin(int entity, float origin[3])
{
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
}

bool IsValidCommentaryZombieSpawner(int entity)
{
    if (!IsValidEntity(entity))
    {
        return false;
    }

    char classname[128];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (!StrEqual(classname, "commentary_zombie_spawner"))
    {
        return false;
    }

    return true;
}

int SpawnWitchAt(float position[3])
{
    int spawner = CreateEntityByName("commentary_zombie_spawner");
    if (spawner == -1)
    {
        return -1;
    }

    DispatchSpawn(spawner);
    ActivateEntity(spawner);
    DispatchKeyValue(spawner, "targetname", "pet_witch_spawner");
    TeleportEntity(spawner, position, NULL_VECTOR, NULL_VECTOR);
    SetVariantString("OnSpawnedZombieDeath !self:Kill::5:-1");
    AcceptEntityInput(spawner, "AddOutput");
    SetVariantString("witch");
    AcceptEntityInput(spawner, "SpawnZombie");

    return spawner;
}

int SpawnTriggerHurtAt(float origin[3])
{
    int hurter = CreateEntityByName("trigger_hurt");
    if (hurter == -1)
    {
        return -1;
    }

    DispatchSpawn(hurter);
    ActivateEntity(hurter);

    DispatchKeyValue(hurter, "targetname", "pet_witch_hurter");
    DispatchKeyValue(hurter, "damage", "2");          // Must be greater than 1
    DispatchKeyValue(hurter, "damagetype", "2");      // BULLET
    DispatchKeyValue(hurter, "spawnflags", "2");      // Only NPCs

    SetVariantString("OnHurt !self:Kill::5:-1");   // OnHurt works only on NPCs
    AcceptEntityInput(hurter, "AddOutput");

    SetEntProp(hurter, Prop_Send, "m_nSolidType", 2); // 2 = Bounding Box

    float mins[3] = {-5.0, -5.0, -5.0};
    float maxs[3] = {5.0, 5.0, 5.0};
    SetEntPropVector(hurter, Prop_Send, "m_vecMins", mins);
    SetEntPropVector(hurter, Prop_Send, "m_vecMaxs", maxs);

    TeleportEntity(hurter, origin, NULL_VECTOR, NULL_VECTOR);

    return hurter;
}

stock bool GetClientAimPosition(int client, float aimPosition[3])
{
    float angles[3];
    float origin[3];
    float buffer[3];
    float start[3];
    float distance;

    GetClientEyePosition(client, origin);
    GetClientEyeAngles(client, angles);

    // Get endpoint.
    Handle trace = TR_TraceRayFilterEx(
        origin,
        angles,
        MASK_SHOT,
        RayType_Infinite,
        Callback_TraceEntityFilter
    );
        
    if (TR_DidHit(trace))
    {   	 
        TR_GetEndPosition(start, trace);
        GetVectorDistance(origin, start, false);
        distance = -35.0;
        GetAngleVectors(angles, buffer, NULL_VECTOR, NULL_VECTOR);
        aimPosition[0] = start[0] + (buffer[0] * distance);
        aimPosition[1] = start[1] + (buffer[1] * distance);
        aimPosition[2] = start[2] + (buffer[2] * distance);
    }
    else
    {
        // Could not get end point.
        CloseHandle(trace);
        return false;
    }

    CloseHandle(trace);
    return true;
}
public bool Callback_TraceEntityFilter(int entity, int contentsMask)
{
	return entity > GetMaxClients() || !entity;
}

bool IsSurvivorConnectedAndAlive(int survivor)
{
    return (
        IsClientConnected(survivor)
        && IsClientInGame(survivor)
        && IsPlayerAlive(survivor)
        && GetClientTeam(survivor) == TEAM_SURVIVORS
    );
}
