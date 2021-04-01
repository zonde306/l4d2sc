
#if defined __tanks__
#endinput
#endif
#define __tanks__

/* Global Vars */
Handle hFwdFirstTankSpawn;
Handle hFwdTankPassControl;
Handle hFwdTankDeath;
Handle hTankDeathTimer;

static bool bIsTankActive;
static int iTank = -1;
static int iTankPassCount = 0;

static bool bExpectTankSpawn = false;

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (L4D2Direct_GetTankCount() > 0) return Plugin_Handled;
	bExpectTankSpawn = true;
	return Plugin_Continue;
}

void ResetStatus()
{
	bExpectTankSpawn = false;
	bIsTankActive = false;
	iTank = -1;
	iTankPassCount = 0;
	
	if (hTankDeathTimer != INVALID_HANDLE)
	{
		KillTimer(hTankDeathTimer);
		hTankDeathTimer = INVALID_HANDLE;
	}
}

void Tanks_OnMapStart()
{
	ResetStatus();
}

void Tanks_RoundStart()
{
	ResetStatus();
}

Action Tanks_TankSpawn(Event event)
{
	if (!bExpectTankSpawn) return;
	bExpectTankSpawn = false;
	if (bIsTankActive) return;
	bIsTankActive = true;
	
	iTank = GetClientOfUserId(event.GetInt("userid"));
	
	Call_StartForward(hFwdFirstTankSpawn);
	Call_PushCell(iTank);
	Call_Finish();
}

Action Tanks_ItemPickup(Event event)
{
	if (!bIsTankActive) return;
	
	char item[64];
	event.GetString("item", item, sizeof(item));
	
	if (StrEqual(item, "tank_claw"))
	{
		int iPrevTank = iTank;
		iTank = GetClientOfUserId(event.GetInt("userid"));
		if (hTankDeathTimer != INVALID_HANDLE)
		{
			KillTimer(hTankDeathTimer);
			hTankDeathTimer = INVALID_HANDLE;
		}
		Call_StartForward(hFwdTankPassControl);
		Call_PushCell(iPrevTank);
		Call_PushCell(iTank);
		Call_PushCell(iTankPassCount);
		Call_Finish();
		iTankPassCount++;
	}
}

Action Tanks_PlayerDeath(Event event)
{
	if (!bIsTankActive) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (client != iTank) return;
	hTankDeathTimer = CreateTimer(0.5, TankDeath_Timer, attacker);
}

public Action TankDeath_Timer(Handle timer, any attacker)
{
	Call_StartForward(hFwdTankDeath);
	Call_PushCell(iTank);
	Call_PushCell(attacker);
	Call_Finish();
	ResetStatus();
}
