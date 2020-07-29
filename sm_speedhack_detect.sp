#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name =          "加速检测",
    author =        "zonde306",
    description =   "Prevents speedhack cheats from working",
    version =       "1.0",
    url =           ""
};

/* Globals */
int g_iTicksLeft[MAXPLAYERS+1];
int g_iMaxTicks;

#define MAX_DETECTIONS 30
int g_iDetections[MAXPLAYERS+1];
float g_fDetectedTime[MAXPLAYERS+1];
float g_fPrevLatency[MAXPLAYERS+1];
ConVar g_pCvarAction, g_pCvarBanDuration;

/* Plugin Functions */
public void OnPluginStart()
{
    g_pCvarAction = CreateConVar("speedhack_action", "3", "对于被检测到的玩家进行的操作.0=没有.1=踢出.2=封禁.3=封禁并踢出", FCVAR_NONE, true, 0.0, true, 3.0);
    g_pCvarBanDuration = CreateConVar("speedhack_ban_duration", "0", "对于被检测到的玩家进行封禁的持续时间.0=永久", FCVAR_NONE, true, 0.0);
	
    // The server's tickrate * 2.0 as a buffer zone.
    g_iMaxTicks = RoundToCeil(1.0 / GetTickInterval() * 2.0);

    for (int i = 0; i < sizeof(g_iTicksLeft); i++)
    {
        g_iTicksLeft[i] = g_iMaxTicks;
    }

    CreateTimer(0.1, Timer_AddTicks, _, TIMER_REPEAT);
}

public void OnClientConnected(int client)
{
    g_iTicksLeft[client] = g_iMaxTicks;
    g_iDetections[client] = 0;
    g_fDetectedTime[client] = 0.0;
    g_fPrevLatency[client] = 0.0;
}

public Action Timer_AddTicks(Handle timer)
{
    static float fLastProcessed;
    int iNewTicks = RoundToCeil((GetEngineTime() - fLastProcessed) / GetTickInterval());

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            // Make sure latency didn't spike more than 5ms.
            // We want to avoid writing a lagging client to logs.
            float fLatency = GetClientLatency(i, NetFlow_Outgoing);

            if (!g_iTicksLeft[i] && FloatAbs(g_fPrevLatency[i] - fLatency) <= 0.005)
            {
                if (++g_iDetections[i] >= MAX_DETECTIONS && GetGameTime() > g_fDetectedTime[i])
                {
                    OnSpeedHackDetected(i);
                    g_fDetectedTime[i] = GetGameTime() + 30.0;
                }
            }
            else if (g_iDetections[i])
            {
                g_iDetections[i]--;
            }

            g_fPrevLatency[i] = fLatency;
        }

        if ((g_iTicksLeft[i] += iNewTicks) > g_iMaxTicks)
        {
            g_iTicksLeft[i] = g_iMaxTicks;
        }
    }

    fLastProcessed = GetEngineTime();
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{   
    if (!IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if (!g_iTicksLeft[client])
    {
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client))
    {
        g_iTicksLeft[client]--;
    }

    return Plugin_Continue;
}

void OnSpeedHackDetected(int client)
{
	int action = g_pCvarAction.IntValue;
	int flags = BANFLAG_AUTO;
	if(!(action & 1))
		flags |= BANFLAG_NOKICK;
	
	if(action & 2)
		BanClient(client, g_pCvarBanDuration.IntValue, flags, "SpeedHack", "移动速度过快\nSpeed Hack Detected");
	else if(action & 1)
		KickClient(client, "移动速度过快\nSpeed Hack Detected");
}
