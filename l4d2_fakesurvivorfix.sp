#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "生还者模型修复",
	author = "zonde306",
	description = "",
	version = "0.1",
	url = ""
}

#define MAX_CHARACTOR 8

char g_szName[MAX_CHARACTOR][] = {
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis"
};

char g_szModel[MAX_CHARACTOR][] = {
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

char g_szVoice[MAX_CHARACTOR][] = {
	"Gambler",
	"Producer",
	"Coach",
	"Mechanic",
	"NamVet",
	"TeenGirl",
	"Biker",
	"Manager"
};

int g_iCharactor[MAX_CHARACTOR] = {
	0,
	1,
	2,
	3,
	4,
	5,
	6,
	7
};

int g_iModelIndex[MAX_CHARACTOR];
int g_iModelOrder[MAX_CHARACTOR];
bool g_bRoundStart = false;

public void OnPluginStart()
{
	HookEvent("player_first_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	for(int i = 0; i < MAX_CHARACTOR; ++i)
		g_iModelIndex[i] = PrecacheModel(g_szModel[i]);
	g_bRoundStart = false;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bRoundStart = true;
	RemoveFakeSurvivors(0);
	RequestFrame(CheckSurvivorCharacter);
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBoardcast)
{
	if(g_bRoundStart)
		return;
	
	RemoveFakeSurvivors(0);
	RequestFrame(CheckSurvivorCharacter);
}

public Action L4D_OnGetSurvivorSet(int &retVal)
{
	if(retVal == 1)
	{
		for(int i = 0; i < MAX_CHARACTOR / 2; ++i)
			g_iModelOrder[i] = i + 4;
		for(int i = MAX_CHARACTOR / 2; i < MAX_CHARACTOR; ++i)
			g_iModelOrder[i] = i;
	}
	else if(retVal == 2)
	{
		for(int i = 0; i < MAX_CHARACTOR; ++i)
			g_iModelOrder[i] = i;
	}
	
	return Plugin_Continue;
}

public Action L4D_OnFastGetSurvivorSet(int &retVal)
{
	return L4D_OnGetSurvivorSet(retVal);
}

public void RemoveFakeSurvivors(any unused)
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "info_transitioning_player")) != -1)
	{
		RemoveEntity(entity);
		AddSurvivorBot();
	}
}

bool AddSurvivorBot()
{
	int client = CreateFakeClient("Bot");
	if(!client || !IsClientInGame(client))
		return false;
	
	bool success = DispatchKeyValue(client, "classname", "SurvivorBot");
	if(success)
	{
		ChangeClientTeam(client, 2);
		success = DispatchSpawn(client);
	}
	KickClient(client);
	
	return success;
}

void UpdateSurvivorInfo(int sets[MAX_CHARACTOR])
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;
		
		int model = GetEntProp(i, Prop_Send, "m_nModelIndex");
		for(int j = 0; j < MAX_CHARACTOR; ++j)
		{
			if(g_iModelIndex[j] != model)
				continue;
			
			sets[j] += 1;
			break;
		}
	}
}

int FindFreeSurvivor(int sets[MAX_CHARACTOR])
{
	for(int i = 0; i < MAX_CHARACTOR; ++i)
	{
		int idx = g_iModelOrder[i];
		if(sets[idx] <= 0)
			return idx;
	}
	
	return -1;
}

public void CheckSurvivorCharacter(any unused)
{
	int sets[MAX_CHARACTOR];
	UpdateSurvivorInfo(sets);
	
	for(int i = 0; i < MAX_CHARACTOR; ++i)
	{
		int changed = 0;
		for(int j = 1; j < sets[i]; ++j)
		{
			int client = FindClientByCharactor(i);
			if(client < 1)
				break;
			
			int charactor = FindFreeSurvivor(sets);
			if(charactor == -1)
				return;
			
			AssignCharactor(client, charactor);
			changed += 1;
		}
		
		sets[i] -= changed;
	}
}

int FindClientByCharactor(int charactor)
{
	for(int i = 1; i <= MaxClients; ++i)
		if(IsClientInGame(i) && GetClientTeam(i) && GetEntProp(i, Prop_Send, "m_nModelIndex") == g_iModelIndex[charactor])
			return i;
	return -1;
}

void AssignCharactor(int client, int charactor)
{
	SetEntProp(client, Prop_Send, "m_survivorCharacter", g_iCharactor[charactor]);
	SetEntityModel(client, g_szModel[charactor]);
	
	char who[64];
	FormatEx(who, sizeof(who), "who:%s:0", g_szVoice[charactor]);
	DispatchKeyValue(client, "targetname", g_szVoice[charactor]);
	SetVariantString(who);
	AcceptEntityInput(client, "AddContext");
	
	if(IsFakeClient(client))
		SetClientName(client, g_szName[charactor]);
}
