
#if defined __players__
#endinput
#endif
#define __players__

Handle hFwdPlayerHurtPre;
Handle hFwdPlayerHurtPost;
Handle hFwdTeamChanged;

int iSurvivorIndex[NUM_OF_SURVIVORS] = 0;
int iSurvivorCount = 0;

Action Players_PlayerHurt_Event_Pre(Event event)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int currentPerm = event.GetInt("health");
	char Weapon[256];  
	event.GetString("weapon", Weapon, sizeof(Weapon));
	int damage = event.GetInt("dmg_health");
	int dmgtype = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	
	Call_StartForward(hFwdPlayerHurtPre);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(currentPerm);
	Call_PushString(Weapon);
	Call_PushCell(damage);
	Call_PushCell(dmgtype);
	Call_PushCell(hitgroup);
	Call_Finish();
}

Action Players_PlayerHurt_Event_Post(Event event)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int currentPerm = event.GetInt("health");
	char Weapon[256];  
	event.GetString("weapon", Weapon, sizeof(Weapon));
	int damage = event.GetInt("dmg_health");
	int dmgtype = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	
	Call_StartForward(hFwdPlayerHurtPost);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(currentPerm);
	Call_PushString(Weapon);
	Call_PushCell(damage);
	Call_PushCell(dmgtype);
	Call_PushCell(hitgroup);
	Call_Finish();
}

Action Players_TeamChange_Event(Event event)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int nowteam = event.GetInt("team");
	
	Call_StartForward(hFwdTeamChanged);
	Call_PushCell(client);
	Call_PushCell(oldteam);
	Call_PushCell(nowteam);
	Call_Finish();
}


void Survivors_RebuildArray_Delay()
{
	CreateTimer(0.3, BuildArray_Timer);
}

public Action BuildArray_Timer(Handle timer)
{
	Survivors_RebuildArray();
}

void Survivors_RebuildArray()
{
	if (!IsServerProcessing()) return;
	
	iSurvivorCount = 0;
	int ifoundsurvivors = 0;
	int ichar;
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++) iSurvivorIndex[i] = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (ifoundsurvivors == NUM_OF_SURVIVORS) break;
		if (!IsClientInGame(client) || GetClientTeam(client) != 2) continue;
		ichar = GetEntProp(client, Prop_Send, "m_survivorCharacter");
		ifoundsurvivors++;
		if (ichar > 3 || ichar < 0) continue;
		if (!IsPlayerAlive(client)) continue;
		iSurvivorIndex[ichar] = client;
		iSurvivorCount++;
	}
}

int GetSurvivorOfIndex(int index)
{
	if (index < 0 || index > 3) return 0;
	return iSurvivorIndex[index];
}

int GetSurvivorCount()
{
	return iSurvivorCount;
}
