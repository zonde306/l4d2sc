#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4downtown>

char sStockCamp[13][] =
{
	"c1m1_hotel",
	"c2m1_highway",
	"c3m1_plankcountry",
	"c4m1_milltown_a",
	"c5m1_waterfront",
	"c6m1_riverbank",
	"c7m1_docks",
	"c8m1_apartment",
	"c9m1_alleys",
	"c10m1_caves",
	"c11m1_greenhouse",
	"c12m1_hilltop",
	"c13m1_alpinecreek"
};

char sStockCampNames[13][] =
{
	"Dead Center",
	"Dark Carnival",
	"Swamp Fever",
	"Hard Rain",
	"The Parish",
	"The Passing",
	"The Sacrifice",
	"No Mercy",
	"Crash Course",
	"Death Toll",
	"Dead Air",
	"Blood Harvest",
	"Cold Stream"
};

char sCustomCamp[3][] =
{
	"l4d2_stadium1_apartment",
	"l4d_reverse_hos01_rooftop",
	"l4d_farm05_cornfield_rev"
};

char sCustomCampNames[3][] =
{
	"Suicide Blitz 2",
	"Reverse No Mercy",
	"Reverse Blood Harvest"
};

char sCurrentMap[64], sNextCamp[64], sNextMap[64], sLastVotedCamp[64], sLastVotedMap[64],
	sVotedCamp[64], sVotedMap[64], sFirstMap[64], sGameMode[16];

int iFMCVoteDuration;
bool voteInitiated, bFMCEnabled, bFMCIgnoreFail, bFMCAnnounce, bFMCIncludeCurrent, bFMCIncludeLast;
ConVar hFMCEnabled, hFMCIgnoreFail, hFMCAnnounce, hFMCIncludeCurrent, hFMCIncludeLast,
	hFMCVoteDuration;

public Plugin myinfo = 
{
	name = "[L4D2] Force Mission Changer + Voting System",
	author = "cravenge",
	description = "Forcefully Changes To Voted Campaign After Winning Finale.",
	version = "2.4",
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("fmc+vs-l4d2_version", "2.4", "Force Mission Changer + Voting System Version", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCEnabled = CreateConVar("fmc+vs-l4d2_enable", "1", "Enable/Disable Plugin", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCIgnoreFail = CreateConVar("fmc+vs-l4d2_ignore_fail", "1", "Ignore/Mind Fail When Forcing Campaign Changes", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCAnnounce = CreateConVar("fmc+vs-l4d2_announce", "1", "Enable/Disable Announcements", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCVoteDuration = CreateConVar("fmc+vs-l4d2_vote_duration", "60", "Duration Of Campaign Voting", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCIncludeCurrent = CreateConVar("fmc+vs-l4d2_include_current", "0", "Include/Exclude Current Campaign From Being Voted", FCVAR_NOTIFY|FCVAR_SPONLY);
	hFMCIncludeLast = CreateConVar("fmc+vs-l4d2_include_last", "0", "Include/Exclude Last Campaign From Being Voted", FCVAR_NOTIFY|FCVAR_SPONLY);
	
	bFMCEnabled = hFMCEnabled.BoolValue;
	bFMCIgnoreFail = hFMCIgnoreFail.BoolValue;
	bFMCAnnounce = hFMCAnnounce.BoolValue;
	bFMCIncludeCurrent = hFMCIncludeCurrent.BoolValue;
	bFMCIncludeLast = hFMCIncludeLast.BoolValue;
	
	iFMCVoteDuration = hFMCVoteDuration.IntValue;
	
	HookConVarChange(hFMCEnabled, OnFMCCVarsChanged);
	HookConVarChange(hFMCIgnoreFail, OnFMCCVarsChanged);
	HookConVarChange(hFMCAnnounce, OnFMCCVarsChanged);
	HookConVarChange(hFMCIncludeCurrent, OnFMCCVarsChanged);
	HookConVarChange(hFMCIncludeLast, OnFMCCVarsChanged);
	HookConVarChange(hFMCVoteDuration, OnFMCCVarsChanged);
	
	AutoExecConfig(true, "l4d2_fmcvs");
	
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("finale_win", OnFinaleWin);
	HookEvent("mission_lost", OnMissionLost);
	HookEvent("round_end", OnRoundEnd);
	
	RegConsoleCmd("sm_fmc+vs_menu", ShowVoteMenu, "Shows Menu Of Available And Vote-able Campaigns");
	RegConsoleCmd("sm_fmc+vs_menu_custom", ShowVoteMenuCustom, "Shows Menu Of Available And Vote-able Custom Campaigns");
}

public void OnFMCCVarsChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bFMCEnabled = hFMCEnabled.BoolValue;
	bFMCIgnoreFail = hFMCIgnoreFail.BoolValue;
	bFMCAnnounce = hFMCAnnounce.BoolValue;
	bFMCIncludeCurrent = hFMCIncludeCurrent.BoolValue;
	bFMCIncludeLast = hFMCIncludeLast.BoolValue;
	
	iFMCVoteDuration = hFMCVoteDuration.IntValue;
}

public Action ShowVoteMenu(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if (!L4D_IsMissionFinalMap())
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Finales Only!");
		return Plugin_Handled;
	}
	
	if (StrContains(sGameMode, "versus", false) != -1 && !GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Second Round Only!");
		return Plugin_Handled;
	}
	
	AdminId clientId = GetUserAdmin(client);
	if (clientId == INVALID_ADMIN_ID)
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Invalid Access!");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Vote In Progress!");
		return Plugin_Handled;
	}
	
	FMCMenu();
	return Plugin_Handled;
}

public Action ShowVoteMenuCustom(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if (!L4D_IsMissionFinalMap())
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Finales Only!");
		return Plugin_Handled;
	}
	
	if (StrEqual(sGameMode, "versus", false) && !GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Second Round Only!");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		PrintToChat(client, "\x04[FMC+VS]\x03 Vote In Progress!");
		return Plugin_Handled;
	}
	
	FMCMenu(true);
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (!bFMCEnabled || !bFMCAnnounce || IsFakeClient(client) || !L4D_IsMissionFinalMap())
	{
		return;
	}
	
	CreateTimer(1.0, InformOfCC, client, TIMER_REPEAT);
}

public Action InformOfCC(Handle timer, any client)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	PrintToChat(client, "\x04[FMC+VS]\x03 To Vote For Custom Campaigns, Type \x05!fmc+vs_menu_custom");
	return Plugin_Stop;
}

public void OnMapStart()
{
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	
	voteInitiated = false;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!bFMCEnabled || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	if ((StrContains(sGameMode, "versus", false) != -1 && GameRules_GetProp("m_bInSecondHalfOfRound") && !voteInitiated) || ((StrEqual(sGameMode, "coop", false) || StrEqual(sGameMode, "realism", false)) && !voteInitiated))
	{
		ClearNextCampaign();
		
		CreateTimer(30.0, AnnounceNextCamp);
		CreateTimer(60.0, VoteCampaignDelay);
	}
	
	return Plugin_Continue;
}

public Action AnnounceNextCamp(Handle timer)
{
	PrintToChatAll("\x04[FMC+VS]\x03 This Is The Finale!");
	if (!StrEqual(sVotedMap, "", false))
	{
		PrintToChatAll("\x04[FMC+VS]\x03 Next Map: %s |%s|", sVotedMap, sVotedCamp);
	}
	else
	{
		FMC_GetNextCampaign(sCurrentMap);
		PrintToChatAll("\x04[FMC+VS]\x03 Next Map: %s |%s|", sNextMap, sNextCamp);
	}
	return Plugin_Stop;
}

public Action VoteCampaignDelay(Handle timer)
{
	if (voteInitiated)
	{
		return Plugin_Stop;
	}
	
	voteInitiated = true;
	
	CreateTimer(5.0, ReadyVoteMenu);
	PrintToChatAll("\x04[FMC+VS]\x03 Campaign Vote In 5..");
	
	return Plugin_Stop;
}

public Action ReadyVoteMenu(Handle timer)
{
	PrintToChatAll("\x04[FMC+VS]\x03 Starting Campaign Vote!");
	FMCMenu();
	
	return Plugin_Stop;
}

void FMCMenu(bool bCustom = false)
{
	Menu voteMenu = new Menu(voteMenuHandler);
	voteMenu.SetTitle("Next Campaign Vote:");
	
	if (StrEqual(sVotedMap, "", false))
	{
		voteMenu.AddItem(sNextMap, sNextCamp);
	}
	else
	{
		voteMenu.AddItem(sVotedMap, sVotedCamp);
	}
	
	if (!bCustom)
	{
		for (int i = 0; i < 13; i++)
		{
			if (StrEqual(sNextMap, sStockCamp[i], false) || (!bFMCIncludeCurrent && StrEqual(sFirstMap, sStockCamp[i], false)) || (!bFMCIncludeLast && StrEqual(sLastVotedMap, sStockCamp[i], false)))
			{
				continue;
			}
			
			voteMenu.AddItem(sStockCamp[i], sStockCampNames[i]);
		}
	}
	else
	{
		for (int i = 0; i < 3; i++)
		{
			if (!IsMapValid(sCustomCamp[i]) || (!bFMCIncludeCurrent && StrEqual(sFirstMap, sCustomCamp[i], false)) || (!bFMCIncludeLast && StrEqual(sLastVotedMap, sCustomCamp[i], false)))
			{
				continue;
			}
			
			voteMenu.AddItem(sCustomCamp[i], sCustomCampNames[i]);
		}
	}
	
	voteMenu.ExitButton = false;
	voteMenu.VoteResultCallback = voteMenuResult;
	voteMenu.DisplayVoteToAll(iFMCVoteDuration);
}

public int voteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void voteMenuResult(
	Menu menu,
	int num_votes,
	int num_clients,
	const int[][] client_info,
	int num_items,
	const int[][] item_info
)
{
	int majorityItem = 0;
	if (num_items >= 2)
	{
		int i = 1;
		while (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[i][VOTEINFO_ITEM_VOTES])
		{
			i += 1;
		}
		
		if (i >= 2)
		{
			majorityItem = GetRandomInt(0, i - 1);
		}
	}
	
	menu.GetItem(item_info[majorityItem][VOTEINFO_ITEM_INDEX], sVotedMap, sizeof(sVotedMap), _, sVotedCamp, sizeof(sVotedCamp));
	PrintToChatAll("\x04[FMC+VS]\x03 Most Voted Campaign: %s (%s) \x05[%d Votes]", sVotedCamp, sVotedMap, item_info[majorityItem][VOTEINFO_ITEM_VOTES]);
	
	strcopy(sLastVotedCamp, sizeof(sLastVotedCamp), sVotedCamp);
	strcopy(sLastVotedMap, sizeof(sLastVotedMap), sVotedMap);
	
	if (bFMCAnnounce)
	{
		CreateTimer(5.0, AnnounceNextCamp);
	}
}

public Action OnFinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	if (!bFMCEnabled || !StrEqual(sGameMode, "coop", false) || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	CreateTimer(9.0, ForceNextCampaign);
	return Plugin_Continue;
}

public Action OnMissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if (!bFMCEnabled || bFMCIgnoreFail || !StrEqual(sGameMode, "coop", false) || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	CreateTimer(5.0, ForceNextCampaign);
	return Plugin_Continue;
}

public Action ForceNextCampaign(Handle timer)
{
	if (StrEqual(sVotedMap, "", false))
	{
		FMC_GetNextCampaign(sCurrentMap);
		ServerCommand("changelevel %s", sNextMap);
	}
	else
	{
		ServerCommand("changelevel %s", sVotedMap);
	}
	return Plugin_Stop;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!bFMCEnabled || StrContains(sGameMode, "versus", false) == -1 || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	if (GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		CreateTimer(15.0, ForceNextCampaign);
	}
	return Plugin_Continue;
}

void ClearNextCampaign()
{
	sNextCamp[0] = '\0';
	sNextMap[0] = '\0';
	
	sVotedCamp[0] = '\0';
	sVotedMap[0] = '\0';
}

void FMC_GetNextCampaign(const char[] sMap)
{
	if (StrEqual(sMap, "c1m4_atrium", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[5]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[5]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[0]);
	}
	else if (StrEqual(sMap, "c6m3_port", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[1]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[1]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[5]);
	}
	else if (StrEqual(sMap, "c2m5_concert", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[2]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[2]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[1]);
	}
	else if (StrEqual(sMap, "c3m4_plantation", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[3]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[3]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[2]);
	}
	else if (StrEqual(sMap, "c4m5_milltown_escape", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[4]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[4]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[3]);
	}
	else if (StrEqual(sMap, "c5m5_bridge", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[12]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[12]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[4]);
	}
	else if (StrEqual(sMap, "c13m4_cutthroatcreek", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[12]);
	}
	else if (StrEqual(sMap, "c8m5_rooftop", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[8]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[8]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[7]);
	}
	else if (StrEqual(sMap, "c9m2_lots", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[9]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[9]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[8]);
	}
	else if (StrEqual(sMap, "c10m5_houseboat", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[10]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[10]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[9]);
	}
	else if (StrEqual(sMap, "c11m5_runway", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[11]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[11]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[10]);
	}
	else if (StrEqual(sMap, "c12m5_cornfield", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[6]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[6]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[11]);
	}
	else if (StrEqual(sMap, "c7m3_port", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[7]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[7]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[6]);
	}
	else if (StrEqual(sMap, "l4d2_stadium5_stadium", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sCustomCamp[1]);
	}
	else if (StrEqual(sMap, "l4d_reverse_hos05_apartment", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sCustomCamp[2]);
	}
}

