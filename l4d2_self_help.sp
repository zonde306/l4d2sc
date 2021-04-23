#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
// #include <l4d2_simple_combat>

#define PLUGIN_VERSION "2.83"

enum SelfHelpState
{
	SHS_NONE = 0,
	SHS_START_SELF = 1,
	SHS_START_OTHER = 2,
	SHS_CONTINUE = 3,
	SHS_END = 4
};

ConVar shEnable, shUse, shIncapPickup, shDelay, shKillAttacker, shBot, shBotChance, shHardHP,
	shTempHP;

bool bIsL4D, bEnabled, bIncapPickup, bKillAttacker, bBot;
float fLastPos[MAXPLAYERS+1][3], fDelay, fTempHP;
int iSurvivorClass, iUse, iBotChance, iHardHP, iSHCount[MAXPLAYERS+1][2], iAttacker[MAXPLAYERS+1],
	iBotHelp[MAXPLAYERS+1];

Handle hSHTime[MAXPLAYERS+1] = null, hSHStartForward, hSHPreForward, hSHForward, hSHPostForward,
	hSHInterruptedForward, hSHFinishForward/*, hSHGameData = null, hSHSetTempHP = null, hSHAdrenalineRush = null*/;

SelfHelpState shsStatus[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if (!StrEqual(sGameName, "left4dead", false) && !StrEqual(sGameName, "left4dead2", false))
	{
		strcopy(error, err_max, "[SH] Plugin Supports L4D And L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	bIsL4D = (StrEqual(sGameName, "left4dead", false)) ? true : false;
	iSurvivorClass = (StrEqual(sGameName, "left4dead2", false)) ? 9 : 6;
	
	CreateNative("GetSHStats", SH_GetStats);
	CreateNative("SetSHStats", SH_SetStats);
	CreateNative("SelfHelp_SetAllowedClient", SelfHelp_SetAllowedClient);
	
	RegPluginLibrary("self_help_includes");
	return APLRes_Success;
}

public SH_GetStats(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsSurvivor(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Client!");
		return;
	}
	
	if (!IsPlayerAlive(client))
	{
		SetNativeCellRef(2, 0);
		SetNativeCellRef(3, 0);
	}
	else
	{
		SetNativeCellRef(2, iSHCount[client][0]);
		SetNativeCellRef(3, iSHCount[client][1]);
	}
}

public SH_SetStats(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Client!");
		return;
	}
	
	int iIncapCount = GetNativeCell(2);
	if (iIncapCount < 0 || iIncapCount > FindConVar("survivor_max_incapacitated_count").IntValue)
	{
		for (int i = 0; i < 2; i++)
		{
			iSHCount[client][i] = 0;
		}
		
		ThrowNativeError(SP_ERROR_NATIVE, "Incorrect Incapacitated Count!");
		return;
	}
	
	iSHCount[client][0] = iIncapCount;
	
	int iReviveCount = GetNativeCell(3);
	if (iReviveCount < 0 || iReviveCount > FindConVar("survivor_max_incapacitated_count").IntValue)
	{
		iSHCount[client][1] = iSHCount[client][0];
		ThrowNativeError(SP_ERROR_NATIVE, "Incorrect Revive Count!");
		
		return;
	}
	
	iSHCount[client][1] = iReviveCount;
}

bool g_bAllowedClient[MAXPLAYERS+1];

public int SelfHelp_SetAllowedClient(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int client = GetNativeCell(1);
	bool allow = GetNativeCell(2);
	bool old = g_bAllowedClient[client];
	g_bAllowedClient[client] = allow;
	return view_as<int>(old);
}

public Plugin myinfo =
{
	name = "自救",
	author = "cravenge",
	description = "Lets Players Help Themselves When Troubled.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/forumdisplay.php?f=108"
};

public void OnPluginStart()
{
	/*
	if (!bIsL4D)
	{
		hSHGameData = LoadGameConfigFile("new_ammo_packs-l4d2");
		if (hSHGameData == null)
		{
			SetFailState("[SH] Game Data Missing!");
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "SetHealthBuffer");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		hSHSetTempHP = EndPrepSDKCall();
		if (hSHSetTempHP == null)
		{
			SetFailState("[SH] Signature 'SetHealthBuffer' Broken!");
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "OnAdrenalineUsed");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		hSHAdrenalineRush = EndPrepSDKCall();
		if (hSHAdrenalineRush == null)
		{
			SetFailState("[NAP] Signature 'OnAdrenalineUsed' Broken!");
		}
		
		delete hSHGameData;
	}
	*/
	
	hSHStartForward = CreateGlobalForward("OnSelfHelpStart", ET_Ignore, Param_Cell);
	hSHPreForward = CreateGlobalForward("OnSelfHelpPre", ET_Ignore, Param_Cell, Param_Cell);
	hSHForward = CreateGlobalForward("OnSelfHelp", ET_Ignore, Param_Cell, Param_Cell);
	hSHPostForward = CreateGlobalForward("OnSelfHelpPost", ET_Ignore, Param_Cell, Param_Cell);
	hSHInterruptedForward = CreateGlobalForward("OnSelfHelpInterrupted", ET_Ignore, Param_Cell);
	hSHFinishForward = CreateGlobalForward("OnSelfHelpFinish", ET_Ignore, Param_Cell);
	
	CreateConVar("self_help_version", PLUGIN_VERSION, "插件版本", FCVAR_SPONLY|FCVAR_DONTRECORD);
	shEnable = CreateConVar("self_help_enable", "1", "是否开启插件", FCVAR_SPONLY, true, 0.0, true, 1.0);
	shUse = CreateConVar("self_help_use", "3", "允许自救的物品.1=药物.2=医疗包.3=全部", FCVAR_SPONLY, true, 0.0, true, 3.0);
	shIncapPickup = CreateConVar("self_help_incap_pickup", "1", "是否开启倒地捡东西", FCVAR_SPONLY, true, 0.0, true, 1.0);
	shDelay = CreateConVar("self_help_delay", "1.0", "自救启动延迟", FCVAR_SPONLY);
	shKillAttacker = CreateConVar("self_help_kill_attacker", "1", "是否杀死控制者", FCVAR_SPONLY, true, 0.0, true, 1.0);
	shBot = CreateConVar("self_help_bot", "1", "是否允许机器人自救", FCVAR_SPONLY, true, 0.0, true, 1.0);
	shBotChance = CreateConVar("self_help_bot_chance", "2", "机器人自救几率.1=有时.2=经常.3=很少", FCVAR_SPONLY, true, 1.0, true, 3.0);
	shHardHP = CreateConVar("self_help_hard_hp", "50", "医疗包自救后血量", FCVAR_SPONLY, true, 1.0);
	shTempHP = CreateConVar("self_help_temp_hp", "30", "药物自救后血量", FCVAR_SPONLY, true, 1.0);
	
	iUse = shUse.IntValue;
	iBotChance = shBotChance.IntValue;
	iHardHP = shHardHP.IntValue;
	
	bEnabled = shEnable.BoolValue;
	bIncapPickup = shIncapPickup.BoolValue;
	bKillAttacker = shKillAttacker.BoolValue;
	bBot = shBot.BoolValue;
	
	fDelay = shDelay.FloatValue;
	fTempHP = shTempHP.FloatValue;
	
	shEnable.AddChangeHook(OnSHCVarsChanged);
	shUse.AddChangeHook(OnSHCVarsChanged);
	shIncapPickup.AddChangeHook(OnSHCVarsChanged);
	shDelay.AddChangeHook(OnSHCVarsChanged);
	shKillAttacker.AddChangeHook(OnSHCVarsChanged);
	shBot.AddChangeHook(OnSHCVarsChanged);
	shBotChance.AddChangeHook(OnSHCVarsChanged);
	shHardHP.AddChangeHook(OnSHCVarsChanged);
	shTempHP.AddChangeHook(OnSHCVarsChanged);
	
	AutoExecConfig(true, "l4d2_self_help");
	
	HookEvent("round_start", OnRoundEvents);
	HookEvent("round_end", OnRoundEvents);
	HookEvent("finale_win", OnRoundEvents);
	HookEvent("mission_lost", OnRoundEvents);
	HookEvent("map_transition", OnRoundEvents);
	
	HookEvent("tongue_grab", OnInfectedGrab);
	HookEvent("lunge_pounce", OnInfectedGrab);
	if (!bIsL4D)
	{
		HookEvent("jockey_ride", OnInfectedGrab);
		HookEvent("charger_pummel_start", OnInfectedGrab);
		
		HookEvent("jockey_ride_end", OnInfectedRelease);
		HookEvent("charger_pummel_end", OnInfectedRelease);
	}
	HookEvent("tongue_release", OnInfectedRelease);
	HookEvent("pounce_stopped", OnInfectedRelease);
	
	HookEvent("player_incapacitated", OnPlayerDown);
	HookEvent("player_ledge_grab", OnPlayerDown);
	
	HookEvent("heal_success", OnCountReset);
	HookEvent("player_death", OnCountReset);
	HookEvent("player_bot_replace", OnCountReset);
	HookEvent("bot_player_replace", OnCountReset);
	
	HookEvent("revive_begin", OnReviveBegin);
	HookEvent("revive_end", OnReviveEnd);
	HookEvent("revive_success", OnReviveSuccess);
	
	AddNormalSoundHook(OnAllSoundsFix);
	
	CreateTimer(1.0, RecordLastPosition, _, TIMER_REPEAT);
	// CreateTimer(1.0, Timer_SetupSkill);
}

/*
public Action Timer_SetupSkill(Handle timer, any unused)
{
	SC_CreateSkill("sh_selfhelp", "自救", 0, "倒地被控按住 CTRL(蹲下) 自救");
	return Plugin_Continue;
}
*/

public void OnSHCVarsChanged(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	iUse = shUse.IntValue;
	iBotChance = shBotChance.IntValue;
	iHardHP = shHardHP.IntValue;
	
	bEnabled = shEnable.BoolValue;
	bIncapPickup = shIncapPickup.BoolValue;
	bKillAttacker = shKillAttacker.BoolValue;
	bBot = shBot.BoolValue;
	
	fDelay = shDelay.FloatValue;
	fTempHP = shTempHP.FloatValue;
}

public Action OnAllSoundsFix(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (((StrContains(sample, "puddleofyou", false) != -1 || StrContains(sample, "iamsocold", false) != -1) && !GetEntProp(entity, Prop_Send, "m_isIncapacitated", 1)) || (StrContains(sample, "clingingtohell", false) != -1 && !GetEntProp(entity, Prop_Send, "m_isHangingFromLedge", 1)))
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action RecordLastPosition(Handle timer)
{
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (!bBot && IsFakeClient(i))
			{
				continue;
			}
			
			if (GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1))
			{
				continue;
			}
			
			float fCurrentPos[MAXPLAYERS+1][3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", fCurrentPos[i]);
			
			fLastPos[i] = fCurrentPos[i];
		}
	}
	
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	shEnable.RemoveChangeHook(OnSHCVarsChanged);
	shUse.RemoveChangeHook(OnSHCVarsChanged);
	shIncapPickup.RemoveChangeHook(OnSHCVarsChanged);
	shDelay.RemoveChangeHook(OnSHCVarsChanged);
	shKillAttacker.RemoveChangeHook(OnSHCVarsChanged);
	shBot.RemoveChangeHook(OnSHCVarsChanged);
	shBotChance.RemoveChangeHook(OnSHCVarsChanged);
	shHardHP.RemoveChangeHook(OnSHCVarsChanged);
	shTempHP.RemoveChangeHook(OnSHCVarsChanged);
	
	delete shEnable;
	delete shUse;
	delete shIncapPickup;
	delete shDelay;
	delete shKillAttacker;
	delete shBot;
	delete shBotChance;
	delete shHardHP;
	delete shTempHP;
	
	UnhookEvent("round_start", OnRoundEvents);
	UnhookEvent("round_end", OnRoundEvents);
	UnhookEvent("finale_win", OnRoundEvents);
	UnhookEvent("mission_lost", OnRoundEvents);
	UnhookEvent("map_transition", OnRoundEvents);
	
	UnhookEvent("tongue_grab", OnInfectedGrab);
	UnhookEvent("lunge_pounce", OnInfectedGrab);
	if (!bIsL4D)
	{
		UnhookEvent("jockey_ride", OnInfectedGrab);
		UnhookEvent("charger_pummel_start", OnInfectedGrab);
		
		UnhookEvent("jockey_ride_end", OnInfectedRelease);
		UnhookEvent("charger_pummel_end", OnInfectedRelease);
	}
	UnhookEvent("tongue_release", OnInfectedRelease);
	UnhookEvent("pounce_stopped", OnInfectedRelease);
	
	UnhookEvent("player_incapacitated", OnPlayerDown);
	UnhookEvent("player_ledge_grab", OnPlayerDown);
	
	UnhookEvent("heal_success", OnCountReset);
	UnhookEvent("player_death", OnCountReset);
	UnhookEvent("player_bot_replace", OnCountReset);
	UnhookEvent("bot_player_replace", OnCountReset);
	
	UnhookEvent("revive_begin", OnReviveBegin);
	UnhookEvent("revive_end", OnReviveEnd);
	UnhookEvent("revive_success", OnReviveSuccess);
	
	RemoveNormalSoundHook(OnAllSoundsFix);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearSHData(i);
		}
	}
}

public void OnMapStart()
{
	if (!bIsL4D)
	{
		PrefetchSound("weapons/knife/knife_deploy.wav");
		PrecacheSound("weapons/knife/knife_deploy.wav", true);
	}
	
	PrefetchSound("weapons/knife/knife_hitwall1.wav");
	PrecacheSound("weapons/knife/knife_hitwall1.wav", true);
}

public void OnRoundEvents(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearSHData(i);
		}
	}
}

public void OnInfectedGrab(Event event, const char[] name, bool dontBroadcast)
{
	int grabber = GetClientOfUserId(event.GetInt("userid")),
		grabbed = GetClientOfUserId(event.GetInt("victim"));
	
	if (grabber && IsSurvivor(grabbed))
	{
		iAttacker[grabbed] = grabber;
		CreateTimer(shDelay.FloatValue, DelayMechanism, grabbed);
	}
}

public void OnInfectedRelease(Event event, const char[] name, bool dontBroadcast)
{
	int released = GetClientOfUserId(event.GetInt("victim"));
	if (IsSurvivor(released))
	{
		if (bBot && IsFakeClient(released) && iBotHelp[released] == 1)
		{
			iBotHelp[released] = 0;
		}
		
		if (StrEqual(name, "pounce_stopped"))
		{
			iAttacker[released] = 0;
		}
		else
		{
			int releaser = GetClientOfUserId(event.GetInt("userid"));
			if (releaser && iAttacker[released] == releaser)
			{
				iAttacker[released] = 0;
			}
		}
	}
}

public void OnPlayerDown(Event event, const char[] name, bool dontBroadcast)
{
	int wounded = GetClientOfUserId(event.GetInt("userid"));
	if (IsSurvivor(wounded) && GetEntProp(wounded, Prop_Send, "m_zombieClass") == iSurvivorClass)
	{
		CreateTimer(fDelay, DelayMechanism, wounded);
		
		if (StrEqual(name, "player_incapacitated"))
		{
			// PrintHintText(wounded, "按住 R(换弹夹) 救助队友");
			if (iSHCount[wounded][0] < FindConVar("survivor_max_incapacitated_count").IntValue)
			{
				iSHCount[wounded][0] += 1;
				
				/*
				PrintToChat(wounded, "\x03[SH] \x01你倒下了 [\x04%d\x01/\x04%i\x01]", iSHCount[wounded][0], FindConVar("survivor_max_incapacitated_count").IntValue);
				
				if (iSHCount[wounded][0] == FindConVar("survivor_max_incapacitated_count").IntValue)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i) && i != wounded)
						{
							PrintHintText(i, "[SH] %N Will Be B/W After Revive/Self Help!", wounded);
						}
					}
				}
				*/
			}
		}
	}
}

public void OnCountReset(Event event, const char[] name, bool dontBroadcast)
{
	int client, iOther = 0;
	if (StrEqual(name, "heal_success"))
	{
		client = GetClientOfUserId(event.GetInt("subject"));
		if (!IsSurvivor(client))
		{
			return;
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		iOther = GetClientOfUserId(event.GetInt("player"));
		client = GetClientOfUserId(event.GetInt("bot"));
		
		if (iOther < 1 || !IsClientInGame(iOther) || IsFakeClient(iOther))
		{
			return;
		}
	}
	else if (StrEqual(name, "bot_player_replace"))
	{
		client = GetClientOfUserId(event.GetInt("player"));
		iOther = GetClientOfUserId(event.GetInt("bot"));
		
		if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		{
			return;
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		client = GetClientOfUserId(event.GetInt("userid"));
		if (!IsSurvivor(client))
		{
			return;
		}
	}
	
	for (int i = 0; i < 2; i++)
	{
		if (iOther == 0)
		{
			iSHCount[client][i] = 0;
		}
		else
		{
			iSHCount[client][i] = iSHCount[iOther][i];
			iSHCount[iOther][i] = 0;
		}
	}
}

public void OnReviveBegin(Event event, const char[] name, bool dontBroadcast)
{
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (!IsSurvivor(revived) || hSHTime[revived] == null)
	{
		return;
	}
	
	if (!bIsL4D)
	{
		KillTimer(hSHTime[revived]);
	}
	hSHTime[revived] = null;
}

public void OnReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (!IsSurvivor(revived) || !IsPlayerAlive(revived) || !GetEntProp(revived, Prop_Send, "m_isIncapacitated", 1))
	{
		return;
	}
	
	CreateTimer(fDelay, DelayMechanism, revived);
}

public void OnReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid")),
		revived = GetClientOfUserId(event.GetInt("subject"));
	
	if (!IsSurvivor(reviver) || !IsSurvivor(revived))
	{
		return;
	}
	
	if (bBot && IsFakeClient(revived) && iBotHelp[revived] == 1)
	{
		iBotHelp[revived] = 0;
	}
	
	if (event.GetBool("ledge_hang"))
	{
		/*
		if (reviver != revived)
		{
			PrintToChat(reviver, "\x03[SH] \x01你救起了 \x05%N\x01。", revived);
			PrintToChat(revived, "\x03[SH] \x05%N\x01 救起了你。", reviver);
		}
		else
		{
			PrintToChat(revived, "\x03[SH] \x01你救起了自己。");
		}
		*/
	}
	else
	{
		if (iSHCount[revived][1] < FindConVar("survivor_max_incapacitated_count").IntValue)
		{
			iSHCount[revived][1] += 1;
			
			/*
			if (reviver == revived)
			{
				PrintToChat(revived, "\x03[SH] \x01你救起了自己 [\x04%d\x01/\x04%i\x01]", iSHCount[revived][1], FindConVar("survivor_max_incapacitated_count").IntValue);
			}
			else
			{
				PrintToChat(reviver, "\x03[SH] \x01你救起了 \x05%N\x01! [\x04%d\x01/\x04%i\x01]", revived, iSHCount[revived][1], FindConVar("survivor_max_incapacitated_count").IntValue);
				PrintToChat(revived, "\x03[SH] \x05%N\x01 救起了你! [\x04%d\x01/\x04%i\x01]", reviver, iSHCount[revived][1], FindConVar("survivor_max_incapacitated_count").IntValue);
			}
			*/
		}
	}
	
	if (hSHTime[revived] != null)
	{
		if (!bIsL4D)
		{
			KillTimer(hSHTime[revived]);
		}
		hSHTime[revived] = null;
	}
}

public Action DelayMechanism(Handle timer, any client)
{
	if (!bEnabled || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	shsStatus[client] = SHS_NONE;
	if (hSHTime[client] == null)
	{
		if (bBot && IsFakeClient(client) && iBotHelp[client] == 0 && GetRandomInt(1, 3) == iBotChance)
		{
			iBotHelp[client] = 1;
		}
		
		if (IsSelfHelpAble(client) && !IsFakeClient(client))
		{
			PrintToChat(client, "\x03[SH]\x01 按住 \x04CTRL(蹲下)\x01 可以自救。");
		}
		hSHTime[client] = CreateTimer(0.1, CheckPlayerState, client, TIMER_REPEAT);
	}
	
	return Plugin_Stop;
}

public Action CheckPlayerState(Handle timer, any client)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || (!shBot.BoolValue && IsFakeClient(client)) || shsStatus[client] == SHS_END)
	{
		shsStatus[client] = SHS_NONE;
		RemoveSHProgressBar(client);
		
		if (hSHTime[client] != null)
		{
			if (!bIsL4D)
			{
				KillTimer(hSHTime[client]);
			}
			hSHTime[client] = null;
		}
		return Plugin_Stop;
	}
	
	if (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		if (iAttacker[client] == 0 || (iAttacker[client] != 0 && (!IsClientInGame(iAttacker[client]) || !IsPlayerAlive(iAttacker[client]))))
		{
			shsStatus[client] = SHS_NONE;
			RemoveSHProgressBar(client);
			
			iAttacker[client] = 0;
			
			if (hSHTime[client] != null)
			{
				if (!bIsL4D)
				{
					KillTimer(hSHTime[client]);
				}
				hSHTime[client] = null;
			}
			return Plugin_Stop;
		}
	}
	
	if (hSHTime[client] == null)
	{
		shsStatus[client] = SHS_NONE;
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(client, Prop_Send, "m_reviveOwner") < 1 && iAttacker[client] == 0)
		{
			RemoveSHProgressBar(client);
		}
		return Plugin_Stop;
	}
	
	int iButtons = GetClientButtons(client);
	char sSHMessage[128];
	
	if (bEnabled && IsSelfHelpAble(client))
	{
		if (iButtons & IN_DUCK)
		{
			if (shsStatus[client] == SHS_NONE || shsStatus[client] == SHS_CONTINUE)
			{
				Call_StartForward(hSHStartForward);
				Call_PushCell(client);
				Call_Finish();
				
				shsStatus[client] = SHS_START_SELF;
				if (!IsFakeClient(client))
				{
					strcopy(sSHMessage, sizeof(sSHMessage), "自救");
					DisplaySHProgressBar(client, FindConVar("survivor_revive_duration").IntValue, sSHMessage);
					
					if (!bIsL4D)
					{
						PrintHintText(client, "你正在自救");
					}
				}
				
				Call_StartForward(hSHPreForward);
				Call_PushCell(client);
				Call_PushCell(client);
				Call_Finish();
				
				DataPack dpSHRevive = new DataPack();
				dpSHRevive.WriteCell(GetClientUserId(client));
				CreateTimer(FindConVar("survivor_revive_duration").FloatValue + 0.1, SHReviveCompletion, dpSHRevive, TIMER_DATA_HNDL_CLOSE);
			}
		}
		else
		{
			if (shsStatus[client] == SHS_START_SELF)
			{
				Call_StartForward(hSHInterruptedForward);
				Call_PushCell(client);
				Call_Finish();
				
				shsStatus[client] = SHS_NONE;
				if (!IsFakeClient(client))
				{
					RemoveSHProgressBar(client);
				}
			}
		}
	}
	
	if (bEnabled && (iButtons & IN_RELOAD))
	{
		float fPos[3], fOtherPos[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
		
		int iTarget = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && i != client)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOtherPos);
				
				if (GetVectorDistance(fOtherPos, fPos) <= 50.0)
				{
					iTarget = i;
					break;
				}
			}
		}
		if (IsSurvivor(iTarget) && IsPlayerAlive(iTarget) && GetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(iTarget, Prop_Send, "m_reviveOwner") < 1)
		{
			if (shsStatus[client] == SHS_NONE || shsStatus[client] == SHS_CONTINUE)
			{
				Call_StartForward(hSHStartForward);
				Call_PushCell(client);
				Call_Finish();
				
				shsStatus[client] = SHS_START_OTHER;
				if (!IsFakeClient(client))
				{
					strcopy(sSHMessage, sizeof(sSHMessage), "救起队友");
					DisplaySHProgressBar(client, FindConVar("survivor_revive_duration").IntValue, sSHMessage);
					
					if (!bIsL4D)
					{
						PrintHintText(client, "你正在救助 %N", iTarget);
					}
				}
				
				if (!IsFakeClient(iTarget))
				{
					Format(sSHMessage, sizeof(sSHMessage), "被 %N 救起", client);
					DisplaySHProgressBar(iTarget, FindConVar("survivor_revive_duration").IntValue, sSHMessage);
					
					/*
					if (!bIsL4D)
					{
						PrintHintText(client, "%N 正在救你", client);
					}
					*/
				}
				
				Call_StartForward(hSHPreForward);
				Call_PushCell(client);
				Call_PushCell(iTarget);
				Call_Finish();
				
				DataPack dpSHReviveOther = new DataPack();
				dpSHReviveOther.WriteCell(GetClientUserId(client));
				dpSHReviveOther.WriteCell(GetClientUserId(iTarget));
				CreateTimer(FindConVar("survivor_revive_duration").FloatValue + 0.1, SHReviveOtherCompletion, dpSHReviveOther, TIMER_DATA_HNDL_CLOSE);
			}
		}
		else
		{
			iTarget = 0;
			
			if (shsStatus[client] == SHS_START_OTHER)
			{
				Call_StartForward(hSHInterruptedForward);
				Call_PushCell(client);
				Call_Finish();
				
				shsStatus[client] = SHS_NONE;
				if (!IsFakeClient(client))
				{
					RemoveSHProgressBar(client);
				}
			}
		}
	}
	else
	{
		if (shsStatus[client] == SHS_START_OTHER || shsStatus[client] == SHS_CONTINUE)
		{
			Call_StartForward(hSHInterruptedForward);
			Call_PushCell(client);
			Call_Finish();
			
			shsStatus[client] = SHS_NONE;
			if (!IsFakeClient(client))
			{
				RemoveSHProgressBar(client);
			}
		}
	}
	
	if ((iButtons & IN_USE) && bIncapPickup)
	{
		int iItemEnt = -1;
		float fPos[3], fItemPos[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
		
		if (!CheckPlayerSupply(client, 3))
		{
			while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_first_aid_kit")) != -1)
			{
				if (IsValidEntity(iItemEnt) && IsValidEdict(iItemEnt))
				{
					GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
					
					if (GetVectorDistance(fPos, fItemPos) <= 100.0)
					{
						ExecuteCommand(client, "give", "first_aid_kit");
						PrintHintText(client, "捡到了医疗包");
						
						AcceptEntityInput(iItemEnt, "Kill");
						RemoveEdict(iItemEnt);
						
						break;
					}
				}
			}
		}
		else if (!CheckPlayerSupply(client, 4))
		{
			while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_pain_pills")) != -1)
			{
				if (IsValidEntity(iItemEnt) && IsValidEdict(iItemEnt))
				{
					GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
					
					if (GetVectorDistance(fPos, fItemPos) <= 100.0)
					{
						ExecuteCommand(client, "give", "pain_pills");
						PrintHintText(client, "捡到了药丸");
						
						AcceptEntityInput(iItemEnt, "Kill");
						RemoveEdict(iItemEnt);
						
						break;
					}
				}
			}
			
			if (!bIsL4D)
			{
				while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_adrenaline")) != -1)
				{
					if (IsValidEntity(iItemEnt) && IsValidEdict(iItemEnt))
					{
						GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
						
						if (GetVectorDistance(fPos, fItemPos) <= 100.0)
						{
							ExecuteCommand(client, "give", "adrenaline");
							PrintHintText(client, "捡到了针筒");
							
							AcceptEntityInput(iItemEnt, "Kill");
							RemoveEdict(iItemEnt);
							
							break;
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action SHReviveCompletion(Handle timer, Handle dpSHRevive)
{
	ResetPack(dpSHRevive);
	
	int client = GetClientOfUserId(ReadPackCell(dpSHRevive));
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || hSHTime[client] == null || !(GetClientButtons(client) & IN_DUCK) || shsStatus[client] == SHS_NONE)
	{
		return Plugin_Stop;
	}
	
	if (!IsFakeClient(client))
	{
		RemoveSHProgressBar(client);
	}
	
	if (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		Event ePlayerIncapacitated = CreateEvent("player_incapacitated");
		ePlayerIncapacitated.SetInt("userid", GetClientUserId(client));
		ePlayerIncapacitated.SetInt("attacker", GetClientUserId(iAttacker[client]));
		ePlayerIncapacitated.Fire();
	}
	
	DoSelfHelp(client, _, (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false);
	
	Event eReviveSuccess = CreateEvent("revive_success");
	eReviveSuccess.SetInt("userid", GetClientUserId(client));
	eReviveSuccess.SetInt("subject", GetClientUserId(client));
	eReviveSuccess.SetBool("ledge_hang", (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false);
	eReviveSuccess.SetBool("lastlife", (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) && iSHCount[client][0] == FindConVar("survivor_max_incapacitated_count").IntValue) ? true : false);
	eReviveSuccess.Fire();
	
	return Plugin_Stop;
}

public Action SHReviveOtherCompletion(Handle timer, Handle dpSHReviveOther)
{
	ResetPack(dpSHReviveOther);
	
	int reviver = GetClientOfUserId(ReadPackCell(dpSHReviveOther));
	if (!IsSurvivor(reviver) || !IsPlayerAlive(reviver) || hSHTime[reviver] == null || !(GetClientButtons(reviver) & IN_RELOAD) || shsStatus[reviver] == SHS_NONE)
	{
		return Plugin_Stop;
	}
	
	int revived = GetClientOfUserId(ReadPackCell(dpSHReviveOther));
	if (!IsSurvivor(revived) || !IsPlayerAlive(revived) || !GetEntProp(revived, Prop_Send, "m_isIncapacitated", 1))
	{
		return Plugin_Stop;
	}
	
	if (!IsFakeClient(reviver))
	{
		RemoveSHProgressBar(reviver);
	}
	
	if (!IsFakeClient(revived))
	{
		RemoveSHProgressBar(revived);
	}
	
	Event eReviveSuccess = CreateEvent("revive_success");
	eReviveSuccess.SetInt("userid", GetClientUserId(reviver));
	eReviveSuccess.SetInt("subject", GetClientUserId(revived));
	eReviveSuccess.SetBool("ledge_hang", (GetEntProp(revived, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false);
	eReviveSuccess.SetBool("lastlife", (!GetEntProp(revived, Prop_Send, "m_isHangingFromLedge", 1) && iSHCount[revived][0] == FindConVar("survivor_max_incapacitated_count").IntValue) ? true : false);
	eReviveSuccess.Fire();
	
	DoSelfHelp(reviver, revived, (GetEntProp(revived, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false);
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!bEnabled || !bBot)
	{
		return Plugin_Continue;
	}
	
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || !IsFakeClient(client) || iBotHelp[client] == 0)
	{
		return Plugin_Continue;
	}
	
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		int iTarget = 0;
		float fPlayerPos[2][3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPlayerPos[0]);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && i != client)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fPlayerPos[1]);
				
				if (GetVectorDistance(fPlayerPos[0], fPlayerPos[1]) > 50.0)
				{
					continue;
				}
				
				iTarget = i;
				break;
			}
		}
		if (IsSurvivor(iTarget) && IsPlayerAlive(iTarget) && GetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(iTarget, Prop_Send, "m_reviveOwner") < 1)
		{
			buttons |= IN_RELOAD;
		}
		else
		{
			buttons |= IN_DUCK;
		}
	}
	else if (iAttacker[client] != 0)
	{
		buttons |= IN_DUCK;
	}
	
	return Plugin_Continue;
}

void ClearSHData(int client)
{
	shsStatus[client] = SHS_NONE;
	
	iAttacker[client] = 0;
	iBotHelp[client] = 0;
	for (int i = 0; i < 2; i++)
	{
		iSHCount[client][i] = 0;
	}
	if (hSHTime[client] != null)
	{
		if (!bIsL4D)
		{
			KillTimer(hSHTime[client]);
		}
		hSHTime[client] = null;
	}
}

bool IsSelfHelpAble(int client)
{
	if(!g_bAllowedClient[client])
		return false;
	
	bool bHasPA = CheckPlayerSupply(client, 4), bHasMedkit = CheckPlayerSupply(client, 3);
	
	if ((iUse == 1 || iUse == 3) && bHasPA)
	{
		return true;
	}
	else if ((iUse == 2 || iUse == 3) && bHasMedkit)
	{
		return true;
	}
	
	return false;
}

bool CheckPlayerSupply(int client, int iSlot, int &iItem = 0, char sItemName[64] = "")
{
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return false;
	}
	
	int iSupply = GetPlayerWeaponSlot(client, iSlot);
	if (IsValidEnt(iSupply))
	{
		char sSupplyClass[64];
		GetEdictClassname(iSupply, sSupplyClass, sizeof(sSupplyClass));
		
		if (iSlot == 3 && StrEqual(sSupplyClass, "weapon_first_aid_kit", false))
		{
			iItem = iSupply;
			strcopy(sItemName, sizeof(sItemName), sSupplyClass);
			
			return true;
		}
		else if (iSlot == 4 && (StrEqual(sSupplyClass, "weapon_pain_pills", false) || (!bIsL4D && StrEqual(sSupplyClass, "weapon_adrenaline", false))))
		{
			iItem = iSupply;
			strcopy(sItemName, sizeof(sItemName), sSupplyClass);
			
			return true;
		}
	}
	
	return false;
}

void DisplaySHProgressBar(int client, int iDuration, char[] sMsg)
{
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	if (bIsL4D)
	{
		SetEntProp(client, Prop_Send, "m_iProgressBarDuration", iDuration);
		
		SetEntPropString(client, Prop_Send, "m_progressBarText", sMsg);
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", float(iDuration));
	}
}

void RemoveSHProgressBar(int client)
{
	if (!IsValidEntity(client))
	{
		return;
	}
	
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	if (bIsL4D)
	{
		SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
		
		SetEntPropString(client, Prop_Send, "m_progressBarText", "");
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0.0);
	}
}

void DoSelfHelp(int client, int other = 0, bool bLedge)
{
	if (shsStatus[client] == SHS_START_SELF)
	{
		shsStatus[client] = SHS_END;
	}
	else if (shsStatus[client] == SHS_START_OTHER)
	{
		shsStatus[client] = SHS_CONTINUE;
	}
	
	if (other != 0)
	{
		Call_StartForward(hSHForward);
		Call_PushCell(client);
		Call_PushCell(other);
		Call_Finish();
		
		SelfHelpFixer(other, bLedge, client, _, true);
	}
	else
	{
		int iUsedItem;
		int bFirstAidUsed = 0;
		char sUsedItemName[64];
		
		if ((iUse == 1 || iUse == 3) && CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName))
		{
			if (RemovePlayerItem(client, iUsedItem))
			{
				AcceptEntityInput(iUsedItem, "Kill");
				RemoveEdict(iUsedItem);
				
				if (!bIsL4D && StrEqual(sUsedItemName, "weapon_adrenaline", false))
				{
					static ConVar cvDuration;
					if(cvDuration == null)
						cvDuration = FindConVar("adrenaline_duration");
					
					// SDKCall(hSHAdrenalineRush, client, cvDuration.FloatValue);
					L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(client), cvDuration.IntValue);
					
					// bFirstAidUsed = 3;
					PrintToChatAll("\x03[SH] \x05%N\x01 使用 \x04针筒\x01 自救成功。", client);
					
					Event eAdrenalineUsed = CreateEvent("adrenaline_used");
					eAdrenalineUsed.SetInt("userid", GetClientUserId(client));
					eAdrenalineUsed.Fire();
				}
				else
				{
					bFirstAidUsed = 2;
					PrintToChatAll("\x03[SH] \x05%N\x01 使用 \x04药丸\x01 自救成功。", client);
					
					Event ePillsUsed = CreateEvent("pills_used");
					ePillsUsed.SetInt("userid", GetClientUserId(client));
					ePillsUsed.SetInt("subject", GetClientUserId(client));
					ePillsUsed.Fire();
				}
			}
		}
		else if ((iUse == 2 || iUse == 3) && CheckPlayerSupply(client, 3, iUsedItem))
		{
			if (RemovePlayerItem(client, iUsedItem))
			{
				AcceptEntityInput(iUsedItem, "Kill");
				RemoveEdict(iUsedItem);
				
				bFirstAidUsed = 1;
				PrintToChatAll("\x03[SH] \x05%N\x01 使用 \x04药包\x01 自救成功。", client);
				
				Event eHealSuccess = CreateEvent("heal_success");
				eHealSuccess.SetInt("userid", GetClientUserId(client));
				eHealSuccess.SetInt("subject", GetClientUserId(client));
				eHealSuccess.SetInt("health_restored", 80);
				eHealSuccess.Fire();
			}
		}
		
		if (bKillAttacker)
		{
			int dominator = iAttacker[client];
			iAttacker[client] = 0;
			
			if (dominator != 0 && IsClientInGame(dominator) && GetClientTeam(dominator) == 3 && IsPlayerAlive(dominator))
			{
				switch (GetEntProp(dominator, Prop_Send, "m_zombieClass"))
				{
					case 1:
					{
						Event eTonguePullStopped = CreateEvent("tongue_pull_stopped", true);
						eTonguePullStopped.SetInt("userid", GetClientUserId(client));
						eTonguePullStopped.SetInt("victim", GetClientUserId(client));
						eTonguePullStopped.Fire();
					}
					case 3:
					{
						Event ePounceStopped = CreateEvent("pounce_stopped");
						ePounceStopped.SetInt("userid", GetClientUserId(client));
						ePounceStopped.SetInt("victim", GetClientUserId(client));
						ePounceStopped.Fire();
					}
					case 5:
					{
						if (!bIsL4D)
						{
							Event eJockeyRideEnd = CreateEvent("jockey_ride_end");
							eJockeyRideEnd.SetInt("userid", GetClientUserId(dominator));
							eJockeyRideEnd.SetInt("victim", GetClientUserId(client));
							eJockeyRideEnd.SetInt("rescuer", GetClientUserId(client));
							eJockeyRideEnd.Fire();
						}
					}
					case 6:
					{
						if (!bIsL4D)
						{
							Event eChargerPummelEnd = CreateEvent("charger_pummel_end");
							eChargerPummelEnd.SetInt("userid", GetClientUserId(dominator));
							eChargerPummelEnd.SetInt("victim", GetClientUserId(client));
							eChargerPummelEnd.SetInt("rescuer", GetClientUserId(client));
							eChargerPummelEnd.Fire();
						}
					}
				}
				
				ForcePlayerSuicide(dominator);
				
				Event ePlayerDeath = CreateEvent("player_death");
				ePlayerDeath.SetInt("userid", GetClientUserId(dominator));
				ePlayerDeath.SetInt("attacker", GetClientUserId(client));
				ePlayerDeath.Fire();
				
				if (bIsL4D)
				{
					EmitSoundToAll("weapons/knife/knife_hitwall1.wav", client, SNDCHAN_WEAPON);
				}
				else
				{
					int iRandSound = GetRandomInt(1, 2);
					switch (iRandSound)
					{
						case 1: EmitSoundToAll("weapons/knife/knife_deploy.wav", client, SNDCHAN_WEAPON);
						case 2: EmitSoundToAll("weapons/knife/knife_hitwall1.wav", client, SNDCHAN_WEAPON);
					}
				}
			}
		}
		else
		{
			int dominator = iAttacker[client];
			iAttacker[client] = 0;
			if (dominator != 0 && IsClientInGame(dominator) && GetClientTeam(dominator) == 3 && IsPlayerAlive(dominator))
			{
				L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(GetPlayerFromUserID(%d).GetOrigin())", GetClientUserId(dominator), GetClientUserId(client));
			}
		}
		
		Call_StartForward(hSHForward);
		Call_PushCell(client);
		Call_PushCell(client);
		Call_Finish();
		
		SelfHelpFixer(client, bLedge, _, bFirstAidUsed);
	}
}

void SelfHelpFixer(int client, bool bDoNotTamper, int other = 0, int bMedkitUsed = 0, bool bAnnounce = false)
{
	/*
	if (!bDoNotTamper)
	{
		int iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
		if (iReviveCount >= FindConVar("survivor_max_incapacitated_count").IntValue - 1)
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", FindConVar("survivor_max_incapacitated_count").IntValue);
			if (!bIsL4D)
			{
				SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1);
			}
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 1);
			
			// UpdateGlow(client, true);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", iReviveCount + 1);
			if (!bIsL4D)
			{
				SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			}
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
		}
	}
	*/
	
	L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
	
	/*
	SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0);
		SetEntProp(client, Prop_Send, "m_isFallingFromLedge", 0);
	}
	*/
	
	TeleportEntity(client, fLastPos[client], NULL_VECTOR, NULL_VECTOR);
	
	float health = 0.0;
	switch(bMedkitUsed)
	{
		case 0:
		{
			static ConVar cvHealth;
			if(cvHealth == null)
				cvHealth = FindConVar("survivor_revive_health");
			
			health = cvHealth.FloatValue;
		}
		case 1:
		{
			static ConVar cvHealth;
			if(cvHealth == null)
				cvHealth = FindConVar("first_aid_heal_percent");
			
			health = cvHealth.FloatValue * GetEntProp(client, Prop_Data, "m_iMaxHealth");
		}
		case 2:
		{
			static ConVar cvHealth;
			if(cvHealth == null)
				cvHealth = FindConVar("pain_pills_health_value");
			
			health = cvHealth.FloatValue;
		}
		case 3:
		{
			static ConVar cvHealth;
			if(cvHealth == null)
				cvHealth = FindConVar("adrenaline_health_buffer");
			
			health = cvHealth.FloatValue;
		}
	}
	
	SetEntProp(client, Prop_Data, "m_iHealth", 1);
	
	/*
	if (!bIsL4D)
	{
		SDKCall(hSHSetTempHP, client, health);
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	*/
	
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	
	/*
	if (bMedkitUsed == 1)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iMaxHealth"), 1);
		if (!bIsL4D)
		{
			SDKCall(hSHSetTempHP, client, 0.0);
		}
		else
		{
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
			SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		}
	}
	else if(bMedkitUsed == 2 || bMedkitUsed == 3)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", iHardHP, 1);
		if (!bIsL4D)
		{
			SDKCall(hSHSetTempHP, client, fTempHP);
		}
		else
		{
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fTempHP);
			SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		}
	}
	*/
	
	if (bAnnounce && IsSurvivor(other))
	{
		PrintToChatAll("\x03[SH] \x05%N\x01 在倒地时救起了 \x05%N\x01", other, client);
	}
	
	Call_StartForward(hSHPostForward);
	Call_PushCell(client);
	if (other == 0)
	{
		Call_PushCell(client);
	}
	else
	{
		Call_PushCell(other);
	}
	Call_Finish();
	
	CreateTimer(0.5, CompleteSelfHelp, other);
}

public Action CompleteSelfHelp(Handle timer, any client)
{
	Call_StartForward(hSHFinishForward);
	Call_PushCell(client);
	Call_Finish();
	
	return Plugin_Stop;
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

stock void ExecuteCommand(int client, const char[] sCommand, const char[] sArguments)
{
	int iFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetCommandFlags(sCommand, iFlags);
}

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
	
	static char sBuffer[8192];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}
