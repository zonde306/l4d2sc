/*

ReverseBurn and ThrowableAnnouncer (l4d_ReverseBurn_and_ThrowableAnnouncer) by Mystik Spiral and Marttt

It was created to help mitigate the damage by griefers attempting to kill/incap their teammates by burning them.


Features:

- Burn damage is reversed only if victim(s) are burned instantly (within 0.75 second of ignition) and continuously.
- If burn victim gets out of the fire for more than a second (or fire goes out), burn damage stops being reversed.
- When burn damage is reversed, during each burn cycle:
	* Attacker takes 70% damage for each instantly/continuously burned victim
	* To get victims out of fire, if >1PermHP convert 1PermHP to 2TempHP, otherwise if >1TempHP remove 1TempHP.
	* Already incapped burn victims or burn victims with only 1TotalHP do not take any burn damage.
- Bots do not take burn damage but do move out of the fire as quickly as possible.
- In all other scenarios, burn damage behaves normally.


Common Scenarios:

- Griefer attempts to kill the whole team by burning them. Instead, the griefer takes 210% damage (70% per victim x 3 victims) plus possibly additional self-damage.
Usual end result: Griefer is killed or incapped and everyone else takes only minor damage.

- Player starts fire and griefer runs into it.
Usual end result: Griefer takes 100% damage and player that started fire takes none, which is normal behavior.


Suggestion:

To minimize griefer impact, use this plugin along with...

"ReverseBurn and ExplosionAnnouncer" (l4d_ReverseBurn_and_ExplosionAnnouncer)
...and...
"Reverse Friendly-Fire" (l4d_reverse_ff)

When these plugins are combined, griefers cannot inflict friendly-fire, molotov (throwable burns), or gascan (explosion type burns) damage, yet skilled players will likely not notice any difference in game play.


Credits:

This plugin began life as "Throwable Announcer" by Marttt.  None of the original code was changed, I just added the Reverse Burn feature to it since it already kept track of when an entity was exploded and announced who did it.  I hooked on to that announcement to track whether that explosion burned other players.

Want to contribute code enhancements?
Create a pull request using this GitHub repository: https://github.com/Mystik-Spiral/l4d_ReverseBurn_and_ThrowableAnnouncer

Plugin discussion: https://forums.alliedmods.net/showthread.php?t=331166

*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "放火烧队友反伤"
#define PLUGIN_AUTHOR                 "Mystik Spiral and Marttt"
#define PLUGIN_DESCRIPTION            "Reverses damage when victim burned instantly and continuously"
#define PLUGIN_VERSION                "1.0"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=331166"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Cvar Flags
// ====================================================================================================
#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

// ====================================================================================================
// Filenames
// ====================================================================================================
#define CONFIG_FILENAME               "l4d_ReverseBurn_and_ThrowableAnnouncer"			//MS
#define TRANSLATION_FILENAME          "l4d_ReverseBurn_and_ThrowableAnnouncer.phrases"	//MS

// ====================================================================================================
// Defines
// ====================================================================================================
#define CLASSNAME_MOLOTOV             "molotov_projectile"
#define CLASSNAME_PIPEBOMB            "pipe_bomb_projectile"
#define CLASSNAME_VOMITJAR            "vomitjar_projectile"

#define TEAM_SPECTATOR                1
#define TEAM_SURVIVOR                 2
#define TEAM_INFECTED                 3
#define TEAM_HOLDOUT                  4

#define FLAG_TEAM_NONE                (0 << 0) // 0 | 0000
#define FLAG_TEAM_SURVIVOR            (1 << 0) // 1 | 0001
#define FLAG_TEAM_INFECTED            (1 << 1) // 2 | 0010
#define FLAG_TEAM_SPECTATOR           (1 << 2) // 4 | 0100
#define FLAG_TEAM_HOLDOUT             (1 << 3) // 8 | 1000

#define L4D1_WEPID_MOLOTOV            9
#define L4D1_WEPID_PIPE_BOMB          10

#define L4D2_WEPID_MOLOTOV            13
#define L4D2_WEPID_PIPE_BOMB          14
#define L4D2_WEPID_VOMITJAR           25

#define TYPE_NONE                     0
#define TYPE_MOLOTOV                  1
#define TYPE_PIPEBOMB                 2
#define TYPE_VOMITJAR                 3

#define MAXENTITIES                   2048

#define DM_ONENTITYCREATED            0
#define DM_WEAPON_FIRE                1

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
static ConVar g_hCvar_Enabled;
static ConVar g_hCvar_Team;
static ConVar g_hCvar_Self;
static ConVar g_hCvar_DetectionMethod;
static ConVar g_hCvar_Molotov;
static ConVar g_hCvar_Pipebomb;
static ConVar g_hCvar_Vomitjar;

static ConVar g_hCvar_PillsDecayRate;	//MS

// ====================================================================================================
// Handles
// ====================================================================================================
Handle g_hBeginBurn[MAXPLAYERS + 1];	//MS
Handle g_hFinishBurn[MAXPLAYERS + 1];	//MS

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bL4D2;
static bool   g_bConfigLoaded;
static bool   g_bEventsHooked;
static bool   g_bCvar_Enabled;
static bool   g_bCvar_Team;
static bool   g_bCvar_Self;
static bool   g_bCvar_Molotov;
static bool   g_bCvar_Pipebomb;
static bool   g_bCvar_Vomitjar;

static bool g_bFirstBurn[MAXPLAYERS + 1];		//MS
static bool g_bReverseBurnAtk[MAXPLAYERS + 1];	//MS
static bool g_bReverseBurnVic[MAXPLAYERS + 1];	//MS
static bool g_bBothRBPlugins;					//MS

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
static int    g_iCvar_Team;
static int    g_iCvar_DetectionMethod;

static int g_iBurnVictim[MAXPLAYERS + 1];	//MS

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
static float g_fLastRevBurnTime[MAXPLAYERS + 1];	//MS
static float g_fPillsDecayRate;						//MS

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
static int    ge_iType[MAXENTITIES+1];

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead && engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead\" and \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    g_bL4D2 = (engine == Engine_Left4Dead2);

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    LoadPluginTranslations();
    
    //MS (ConVar names)

    CreateConVar("RBaTA_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled         = CreateConVar("RBaTA_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Team            = CreateConVar("RBaTA_team", "1", "显示提示信息给哪个队伍.\n0 = 无, 1 = 幸存者, 2 = 感染者, 4 = 观察者, 8 = 非玩家幸存者.\n数字相加", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_Self            = CreateConVar("RBaTA_self", "1", "是否给加害者显示提示", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_DetectionMethod = CreateConVar("RBaTA_detection_method", "1", "显示提示的方法.0=OnEntityCreated.1=weapon_fire/molotov_thrown.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Molotov         = CreateConVar("RBaTA_molotov", "1", "是否显示有人扔火瓶", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Pipebomb        = CreateConVar("RBaTA_pipebomb", "1", "是否显示有人扔土雷", CVAR_FLAGS, true, 0.0, true, 1.0);
    if (g_bL4D2)
        g_hCvar_Vomitjar    = CreateConVar("RBaTA_vomitjar", "1", "是否显示有人扔胆汁", CVAR_FLAGS, true, 0.0, true, 1.0);
        
    g_hCvar_PillsDecayRate = FindConVar("pain_pills_decay_rate");	//MS

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Team.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Self.AddChangeHook(Event_ConVarChanged);
    g_hCvar_DetectionMethod.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Molotov.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Pipebomb.AddChangeHook(Event_ConVarChanged);
    if (g_bL4D2)
        g_hCvar_Vomitjar.AddChangeHook(Event_ConVarChanged);
        
    g_hCvar_PillsDecayRate.AddChangeHook(Event_ConVarChanged);		//MS

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_throwable_announcer", CmdPrintCvars, ADMFLAG_ROOT, "Prints the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void LoadPluginTranslations()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "translations/%s.txt", TRANSLATION_FILENAME);
    if (FileExists(path))
        LoadTranslations(TRANSLATION_FILENAME);
    else
        SetFailState("Missing required translation file on \"translations/%s.txt\", please re-download.", TRANSLATION_FILENAME);
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    g_bConfigLoaded = true;

    LateLoad();

    HookEvents(g_bCvar_Enabled);

}

/****************************************************************************************************/

public void Event_ConVarChanged(Handle convar, const char[] sOldValue, const char[] sNewValue)
{
    GetCvars();

    HookEvents(g_bCvar_Enabled);
}

/****************************************************************************************************/

public void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_iCvar_Team = g_hCvar_Team.IntValue;
    g_bCvar_Team = (g_iCvar_Team > 0);
    g_bCvar_Self = g_hCvar_Self.BoolValue;
    g_iCvar_DetectionMethod = g_hCvar_DetectionMethod.IntValue;
    g_bCvar_Molotov = g_hCvar_Molotov.BoolValue;
    g_bCvar_Pipebomb = g_hCvar_Pipebomb.BoolValue;
    if (g_bL4D2)
        g_bCvar_Vomitjar = g_hCvar_Vomitjar.BoolValue;
        
    g_fPillsDecayRate = g_hCvar_PillsDecayRate.FloatValue;		//MS
}

/****************************************************************************************************/

public void HookEvents(bool hook)
{
    if (hook && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        if (g_bL4D2)
        {
            HookEvent("molotov_thrown", Event_MolotovThrown_L4D2);
            HookEvent("weapon_fire", Event_WeaponFire_L4D2);
        }
        else
        {
            //L4D1 doesn't have "molotov_thrown" event
            HookEvent("weapon_fire", Event_WeaponFire_L4D1);
        }

        return;
    }

    if (!hook && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        if (g_bL4D2)
        {
            UnhookEvent("molotov_thrown", Event_MolotovThrown_L4D2);
            UnhookEvent("weapon_fire", Event_WeaponFire_L4D2);
        }
        else
        {
            UnhookEvent("weapon_fire", Event_WeaponFire_L4D1);
        }

        return;
    }
}

/****************************************************************************************************/

public void Event_MolotovThrown_L4D2(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_Team)
        return;

    if (g_iCvar_DetectionMethod != DM_WEAPON_FIRE)
        return;

    if (!g_bCvar_Molotov)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(client))
        return;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (i == client)
        {
            if (!g_bCvar_Self)
                continue;
        }
        else
        {
            if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                continue;
        }

        CPrintToChat(i, "%T", "Thrown a molotov", i, client);
    }
    g_bFirstBurn[client] = true;															//MS
    g_hBeginBurn[client] = CreateTimer(0.75, BeginBurnTimer, client);						//MS
}

/****************************************************************************************************/

public void Event_WeaponFire_L4D2(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_Team)
        return;

    if (g_iCvar_DetectionMethod != DM_WEAPON_FIRE)
        return;

    int weaponid = event.GetInt("weaponid");

    switch (weaponid)
    {
        case L4D2_WEPID_PIPE_BOMB, L4D2_WEPID_VOMITJAR:
        {
            int client = GetClientOfUserId(event.GetInt("userid"));

            if (!IsValidClient(client))
                return;

            switch (weaponid)
            {
                case L4D2_WEPID_PIPE_BOMB:
                {
                    if (!g_bCvar_Pipebomb)
                        return;

                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (!IsClientInGame(i))
                            continue;

                        if (IsFakeClient(i))
                            continue;

                        if (i == client)
                        {
                            if (!g_bCvar_Self)
                                continue;
                        }
                        else
                        {
                            if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                                continue;
                        }

                        CPrintToChat(i, "%T", "Thrown a pipe bomb", i, client);
                    }
                }

                case L4D2_WEPID_VOMITJAR:
                {
                    if (!g_bCvar_Vomitjar)
                        return;

                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (!IsClientInGame(i))
                            continue;

                        if (IsFakeClient(i))
                            continue;

                        if (i == client)
                        {
                            if (!g_bCvar_Self)
                                continue;
                        }
                        else
                        {
                            if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                                continue;
                        }

                        CPrintToChat(i, "%T", "Thrown a vomit jar", i, client);
                    }
                }
            }
        }
    }
}

/****************************************************************************************************/

public void Event_WeaponFire_L4D1(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_Team)
        return;

    if (g_iCvar_DetectionMethod != DM_WEAPON_FIRE)
        return;

    int weaponid = event.GetInt("weaponid");

    switch (weaponid)
    {
        case L4D1_WEPID_MOLOTOV, L4D1_WEPID_PIPE_BOMB:
        {
            int client = GetClientOfUserId(event.GetInt("userid"));

            if (!IsValidClient(client))
                return;

            switch (weaponid)
            {
                case L4D1_WEPID_MOLOTOV:
                {
                    if (!g_bCvar_Molotov)
                        return;

                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (!IsClientInGame(i))
                            continue;

                        if (IsFakeClient(i))
                            continue;

                        if (i == client)
                        {
                            if (!g_bCvar_Self)
                                continue;
                        }
                        else
                        {
                            if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                                continue;
                        }

                        CPrintToChat(i, "%T", "Thrown a molotov", i, client);
                    }
                    g_bFirstBurn[client] = true;															//MS
                    g_hBeginBurn[client] = CreateTimer(0.75, BeginBurnTimer, client);						//MS
                }

                case L4D1_WEPID_PIPE_BOMB:
                {
                    if (!g_bCvar_Pipebomb)
                        return;

                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (!IsClientInGame(i))
                            continue;

                        if (IsFakeClient(i))
                            continue;

                        if (i == client)
                        {
                            if (!g_bCvar_Self)
                                continue;
                        }
                        else
                        {
                            if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                                continue;
                        }

                        CPrintToChat(i, "%T", "Thrown a pipe bomb", i, client);
                    }
                }
            }
        }
    }
}

/****************************************************************************************************/

public void LateLoad()
{
    int entity;

    if (g_bL4D2)
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, CLASSNAME_VOMITJAR)) != INVALID_ENT_REFERENCE)
        {
            OnSpawnPost(entity);
        }
    }
    else
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, CLASSNAME_MOLOTOV)) != INVALID_ENT_REFERENCE)
        {
            OnSpawnPost(entity);
        }
    }

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, CLASSNAME_PIPEBOMB)) != INVALID_ENT_REFERENCE)
    {
        OnSpawnPost(entity);
    }
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (!g_bConfigLoaded)
        return;

    if (!IsValidEntityIndex(entity))
        return;

    ge_iType[entity] = TYPE_NONE;
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bConfigLoaded)
        return;

    if (!IsValidEntityIndex(entity))
        return;

    if (!HasEntProp(entity, Prop_Send, "m_bIsLive")) // *_projectile
        return;

    if (StrEqual(classname, CLASSNAME_PIPEBOMB))
    {
        ge_iType[entity] = TYPE_PIPEBOMB;
        SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
        return;
    }

    if (g_bL4D2)
    {
        if (StrEqual(classname, CLASSNAME_VOMITJAR))
        {
            ge_iType[entity] = TYPE_VOMITJAR;
            SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
            return;
        }
    }
    else
    {
        if (StrEqual(classname, CLASSNAME_MOLOTOV))
        {
            ge_iType[entity] = TYPE_MOLOTOV;
            SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
            return;
        }
    }
}

/****************************************************************************************************/

public void OnSpawnPost(int entity)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_Team)
        return;

    if (g_iCvar_DetectionMethod != DM_ONENTITYCREATED)
        return;

    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

    if (!IsValidClient(client))
        return;

    switch (ge_iType[entity])
    {
        case TYPE_MOLOTOV:
        {
            if (!g_bCvar_Molotov)
                return;

            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i))
                    continue;

                if (IsFakeClient(i))
                    continue;

                if (i == client)
                {
                    if (!g_bCvar_Self)
                        continue;
                }
                else
                {
                    if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                        continue;
                }

                CPrintToChat(i, "%T", "Thrown a molotov", i, client);
            }
            g_bFirstBurn[client] = true;															//MS
            g_hBeginBurn[client] = CreateTimer(0.75, BeginBurnTimer, client);						//MS

            return;
        }

        case TYPE_PIPEBOMB:
        {
            if (!g_bCvar_Pipebomb)
                return;

            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i))
                    continue;

                if (IsFakeClient(i))
                    continue;

                if (i == client)
                {
                    if (!g_bCvar_Self)
                        continue;
                }
                else
                {
                    if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                        continue;
                }

                CPrintToChat(i, "%T", "Thrown a pipe bomb", i, client);
            }

            return;
        }

        case TYPE_VOMITJAR:
        {
            if (!g_bCvar_Vomitjar)
                return;

            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i))
                    continue;

                if (IsFakeClient(i))
                    continue;

                if (i == client)
                {
                    if (!g_bCvar_Self)
                        continue;
                }
                else
                {
                    if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
                        continue;
                }

                CPrintToChat(i, "%T", "Thrown a vomit jar", i, client);
            }

            return;
        }
    }
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------- Plugin Cvars (l4d_throwable_announcer) ---------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_throwable_announcer_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_throwable_announcer_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_throwable_announcer_team : %i", g_iCvar_Team, g_bCvar_Team ? "true" : "false");
    PrintToConsole(client, "l4d_throwable_announcer_self : %i", g_bCvar_Self);
    PrintToConsole(client, "l4d_throwable_announcer_detection_method : %i", g_iCvar_DetectionMethod);
    PrintToConsole(client, "l4d_throwable_announcer_molotov : %b (%s)", g_bCvar_Molotov, g_bCvar_Molotov ? "true" : "false");
    PrintToConsole(client, "l4d_throwable_announcer_pipebomb : %b (%s)", g_bCvar_Pipebomb, g_bCvar_Pipebomb ? "true" : "false");
    if (g_bL4D2)
        PrintToConsole(client, "l4d_throwable_announcer_vomitjar : %b (%s)", g_bCvar_Vomitjar, g_bCvar_Vomitjar ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if is a valid client index.
 *
 * @param client        Client index.
 * @return              True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client        Client index.
 * @return              True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

/**
 * Validates if is a valid entity index (between MaxClients+1 and 2048).
 *
 * @param entity        Entity index.
 * @return              True if entity index is valid, false otherwise.
 */
bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

/****************************************************************************************************/

/**
 * Returns the team flag from a team.
 *
 * @param team          Team index.
 * @return              Team flag.
 */
int GetTeamFlag(int team)
{
    switch (team)
    {
        case TEAM_SURVIVOR:
            return FLAG_TEAM_SURVIVOR;
        case TEAM_INFECTED:
            return FLAG_TEAM_INFECTED;
        case TEAM_SPECTATOR:
            return FLAG_TEAM_SPECTATOR;
        case TEAM_HOLDOUT:
            return FLAG_TEAM_HOLDOUT;
        default:
            return FLAG_TEAM_NONE;
    }
}

// ====================================================================================================
// colors.inc replacement (Thanks to Silvers)
// ====================================================================================================
/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client        Client index.
 * @param message       Message (formatting rules).
 * @return              No return.
 *
 * On error/Errors:     If the client is not connected an error will be thrown.
 */
public void CPrintToChat(int client, char[] message, any ...)
{
    static char buffer[512];
    VFormat(buffer, sizeof(buffer), message, 3);

    ReplaceString(buffer, sizeof(buffer), "{default}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{white}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{cyan}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{lightgreen}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{orange}", "\x04");
    ReplaceString(buffer, sizeof(buffer), "{green}", "\x04"); // Actually orange in L4D1/L4D2, but replicating colors.inc behaviour
    ReplaceString(buffer, sizeof(buffer), "{olive}", "\x05");

    PrintToChat(client, buffer);
}

/****************************************************************************************************/
// Reverse Burn additional functions by Mystik Spiral
/****************************************************************************************************/

public void OnAllPluginsLoaded()
{
	if (FindConVar("l4d_throwable_announcer_version") != null)
	{
		SetFailState("The \"l4d_ReverseBurn_and_ThrowableAnnouncer\" plugin cannot be used with the \"l4d_throwable_announcer\" plugin, use only one of these plugins, not both");
	}
	if (FindConVar("RBaEA_version") != null)
	{
		g_bBothRBPlugins = true;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_Player);
}

public Action OnTakeDamage_Player(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	//check valid victim and attacker and not self damage
	if (IsValidClientAndInGameAndSurvivor(victim) && IsValidClientAndInGameAndSurvivor(attacker) && victim != attacker)
	{
		//PrintToServer("PlyrDmg - Vic: %i %N, Atk: %i %N, FrstBurn: %b, RvsBurnAtk: %b, RvsBurnVic: %b, Dmg: %f", victim, victim, attacker, attacker, g_bFirstBurn[attacker], g_bReverseBurnAtk[attacker], g_bReverseBurnVic[victim], damage);
		//check for burn damage
		if (damagetype & DMG_BURN)
		{
			//check if burnable ignited in the last second by the current attacker
			if (g_bFirstBurn[attacker])
			{
				//set burn victim id to the attacker id
				g_iBurnVictim[victim] = attacker;
				//no damage dealt during first second of burn
				return Plugin_Handled;
			}
			float fGameTime = GetGameTime();
			//was victim damage last reversed more than a second ago
			if ((fGameTime - g_fLastRevBurnTime[victim] > 1.0) && (g_fLastRevBurnTime[victim] != 0))
			{
				//if victim not burned in last second then handle normal, not reversed
				g_bReverseBurnVic[victim] = false;
			}
			//if both attacker and victim reverse burn flags match then reverse burn
			if (g_bReverseBurnAtk[attacker] && g_bReverseBurnVic[victim])
			{
				//set the percent amount of damage for attacker and victim
				float fAttackerDamage = damage * 0.7;
				int iVictimPermHealth = GetClientHealth(victim);
				int iVictimTempHealth = GetClientTempHealth(victim);
				int iVictimTotalHealth = iVictimPermHealth + iVictimTempHealth;
				//PrintToServer("Vic: %N, Perm: %i, Temp: %i, Totl: %i", victim, iVictimPermHealth, iVictimTempHealth, iVictimTotalHealth);
				//do not burn victim if incapped or with only 1 health
				if ((IsClientIncapped(victim)) || (iVictimTotalHealth < 2))
				{
					SDKHooks_TakeDamage(victim, inflictor, attacker, 0.0, damagetype, weapon, damageForce, damagePosition);
					SDKHooks_TakeDamage(attacker, inflictor, attacker, fAttackerDamage, damagetype, weapon, damageForce, damagePosition);
					g_fLastRevBurnTime[victim] = GetGameTime();
					return Plugin_Handled;
				}
				//give standing bot victim 1 health then burn them for 1 health so they move out of fire
				if  (IsFakeClient(victim))
				{
					SetEntityHealth(victim, iVictimPermHealth + 1);
					SDKHooks_TakeDamage(victim, inflictor, attacker, 1.0, damagetype, weapon, damageForce, damagePosition);
					SDKHooks_TakeDamage(attacker, inflictor, attacker, fAttackerDamage, damagetype, weapon, damageForce, damagePosition);
					g_fLastRevBurnTime[victim] = GetGameTime();
					return Plugin_Handled;
				}
				//as incentive for standing victims to get out of the fire quickly...
				//if >1 PermHP remove 1PermHP and add 2TempHP, otherwise if >1 TempHP remove 1TempHP
				if (iVictimPermHealth > 1)
				{
					SetEntityHealth(victim, iVictimPermHealth - 1);
					if (iVictimPermHealth < 99 && iVictimTempHealth < 99 && iVictimTotalHealth < 100)
					{
						SetClientTempHealth(victim, iVictimTempHealth + 2);
					}
					else
					{
						SetClientTempHealth(victim, iVictimTempHealth + 1);
					}
				}
				else if (iVictimTempHealth > 1)
				{
					SetClientTempHealth(victim, iVictimTempHealth - 1);
				}
				SDKHooks_TakeDamage(victim, inflictor, attacker, 0.0, damagetype, weapon, damageForce, damagePosition);
				SDKHooks_TakeDamage(attacker, inflictor, attacker, fAttackerDamage, damagetype, weapon, damageForce, damagePosition);
				g_fLastRevBurnTime[victim] = GetGameTime();
				return Plugin_Handled;
			}
			if (IsFakeClient(victim))
			{
				//even if burn damage is not being reversed do not burn stupid bots
				//give bots 1 health then damage them for 1 health so they move out of fire
				int iVictimPermHealth = GetClientHealth(victim);
				SetEntityHealth(victim, iVictimPermHealth + 1);
				SDKHooks_TakeDamage(victim, inflictor, attacker, 1.0, damagetype, weapon, damageForce, damagePosition);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action BeginBurnTimer(Handle timer, int client)
{
	//loop through all clients to see if OnTakeDamage_Player function marked any burn victims in the first second
	for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
	{
		//if victim was burned in the first second the value is the attacker
		if (g_iBurnVictim[iVictim] > 0)
		{
			int iAttacker = g_iBurnVictim[iVictim];
			//turn on reverse burn flags for the attacker and victim
			g_bReverseBurnAtk[iAttacker] = true;
			g_bReverseBurnVic[iVictim] = true;
			//pack both the attacker and victim so it can be passed to FinishBurnTimer
			DataPack pack;
			g_hFinishBurn[iAttacker] = CreateDataTimer(15.25, FinishBurnTimer, pack);
			pack.WriteCell(iAttacker);
			pack.WriteCell(iVictim);
			//clear the burn victim set by OnTakeDamage_Player
			g_iBurnVictim[iVictim] = 0;
			//clear the time burn damage was last reversed for victim
			g_fLastRevBurnTime[iVictim] = 0.0;
		}
	}
	//clear flag that indicates first second of burnable being ignited
	g_bFirstBurn[client] = false;
	//clear handle for this timer
	g_hBeginBurn[client] = null;
}

public Action FinishBurnTimer(Handle timer, DataPack pack)
{
	int iAttacker;
	int iVictim;
	pack.Reset();
	iAttacker = pack.ReadCell();
	iVictim = pack.ReadCell();
	//fire is out so clear reverse burn flags for attacker and victim and clear timer handle
	g_bReverseBurnAtk[iAttacker] = false;
	g_bReverseBurnVic[iVictim] = false;
	g_hFinishBurn[iAttacker] = null;
	//to prevent message spam wait until fire is out to display message to attacker
	if (IsValidClientAndInGameAndSurvivor(iAttacker))
	{
		if (IsValidClientAndInGameAndSurvivor(iVictim))
		{
			if (g_bBothRBPlugins)
			{
				char sPluginName[13] = "[ReverseBurn]";
				CPrintToChat(iAttacker, "%T", "BurnVictimName", iAttacker, sPluginName, iVictim);
			}
			else
			{
				char sPluginName[7] = "[RBaTA]";
				CPrintToChat(iAttacker, "%T", "BurnVictimName", iAttacker, sPluginName, iVictim);
			}
		}
		else
		{
			if (g_bBothRBPlugins)
			{
				char sPluginName[13] = "[ReverseBurn]";
				CPrintToChat(iAttacker, "%T", "BurnVictimName", iAttacker, sPluginName);
			}
			else
			{
				char sPluginName[7] = "[RBaTA]";
				CPrintToChat(iAttacker, "%T", "BurnVictimName", iAttacker, sPluginName);
			}
		}
	}
}

stock bool IsValidClientAndInGameAndSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsClientIncapped(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}

int GetClientTempHealth(int client)
{
	int iTempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fPillsDecayRate));
	return iTempHealth < 0 ? 0 : iTempHealth;
}

public void SetClientTempHealth(int client, int iTempHealth)
{
	float fTempHealth = iTempHealth * 1.0;
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fTempHealth);
}

/*
public void OnClientPostAdminCheck(int client)
{
	CreateTimer(16.0, AnnouncePlugin, client);
}

public Action AnnouncePlugin(Handle timer, int client)
{
	if (IsClientInGame(client) && g_bCvar_Enabled)
	{
		//if both ReverseBurn plugins loaded, do not announce anything (announced in RBaEA)
		if (!g_bBothRBPlugins)
		{
			PrintToChat(client, "%t", "Announce");
		}
	}
}
*/

/****************************************************************************************************/