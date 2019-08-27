#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>

#define CURRENT_VERSION "0.62"

ConVar cvarGameMode;
int iFinaleStage, iFinaleSeconds, iFinaleMinutes, iRescueMinutes, iGasPoured, iIceMelted;
bool bInUse[2048], bManualChange, bLostAttempt, bFinaleStarted, bScavengeBegin, bProperFinale,
	bProperEscape;

char sGameMode[16], sMap[64];

char sNeededSounds[9][] =
{
	"level/countdown.wav",
	"ui/beep_error01.wav",
	"ui/beep07.wav",
	"level/loud/gallery_win.wav",
	"level/startwam.wav",
	"level/light_on.wav",
	"level/generator_sputter.wav",
	"level/generator_start_loop.wav",
	"animation/fuel_truck_engage.wav"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evRetVal = GetEngineVersion();
	if (evRetVal != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[RVETA] Plugin Supports L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2] Rescue Vehicle ETA",
	author = "cravenge",
	description = "Notifies All Players The Estimated Time Arrival Of Rescue Vehicles.",
	version = CURRENT_VERSION,
	url = "https://forums.alliedmods.net/forumdisplay.php?f=108"
};

public void OnPluginStart()
{
	cvarGameMode = FindConVar("mp_gamemode");
	cvarGameMode.GetString(sGameMode, sizeof(sGameMode));
	cvarGameMode.AddChangeHook(OnRVETACVarChanged);
	
	CreateConVar("rescue_vehicle_eta-l4d2_version", CURRENT_VERSION, "Rescue Vehicle ETA Version", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	HookEvent("finale_radio_start", OnFinaleRadioStart_Pre, EventHookMode_Pre);
	
	HookEvent("round_start", OnRoundEvents);
	HookEvent("round_end", OnRoundEvents);
	HookEvent("mission_lost", OnRoundEvents);
	HookEvent("finale_win", OnRoundEvents);
	
	HookEvent("gascan_pour_completed", OnGasCanPourCompleted);
	HookEvent("player_death", OnPlayerDeath);
	
	AddCommandListener(OnChangeMapCmd, "changelevel");
	AddCommandListener(OnChangeMapCmd, "map");
}

public void OnRVETACVarChanged(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	cvarGameMode.GetString(sGameMode, sizeof(sGameMode));
}

public Action OnChangeMapCmd(int client, const char[] command, int args)
{
	if (L4D_IsMissionFinalMap())
	{
		if (bManualChange)
		{
			return Plugin_Continue;
		}
		
		bManualChange = true;
	}
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	GetCurrentMap(sMap, sizeof(sMap));
	
	if (L4D_IsMissionFinalMap())
	{
		if (StrEqual(sMap, "c2m5_concert", false) || StrEqual(sMap, "c7m3_port", false) || StrEqual(sMap, "c8m5_rooftop", false) || 
			StrEqual(sMap, "l4d_fairview05_rooftop", false) || StrEqual(sMap, "l4d_reverse_hos05_apartment", false) || StrEqual(sMap, "l4d2_ravenholmwar_4", false) || 
			StrEqual(sMap, "2ee_06", false) || StrEqual(sMap, "wfp4_commstation", false))
		{
			iRescueMinutes = 12;
		}
		else if (StrEqual(sMap, "uf4_airfield", false))
		{
			iRescueMinutes = 5;
		}
		else if (StrEqual(sMap, "c5m5_bridge", false) || StrEqual(sMap, "c5m5_darkbridge", false) || StrEqual(sMap, "c13m4_cutthroatcreek", false) || 
			StrEqual(sMap, "l4d2_wanli03", false))
		{
			iRescueMinutes = 0;
		}
		else
		{
			iRescueMinutes = 10;
		}
		
		for (int i = 0; i < 9; i++)
		{
			if (IsSoundPrecached(sNeededSounds[i]))
			{
				continue;
			}
			
			PrecacheSound(sNeededSounds[i], true);
		}
	}
}

public Action OnFinaleRadioStart_Pre(Event event, const char[] name, bool dontBroadcast)
{
	if (!StrEqual(sMap, "c2m5_concert", false))
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) == 1 || !IsInBugSpot(i))
		{
			continue;
		}
		
		if (GetClientTeam(i) == 2)
		{
			TeleportEntity(i, view_as<float>({-512.63, 3150.83, -255.97}), NULL_VECTOR, NULL_VECTOR);
		}
		ForcePlayerSuicide(i);
	}
	
	return Plugin_Continue;
}

public void OnRoundEvents(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D_IsMissionFinalMap() || (StrEqual(name, "round_end") && StrContains(sGameMode, "versus", false) == -1))
	{
		return;
	}
	
	iFinaleStage = 0;
	iFinaleSeconds = 0;
	iFinaleMinutes = 0;
	iGasPoured = 0;
	iIceMelted = 0;
	
	bFinaleStarted = false;
	bScavengeBegin = false;
	bProperFinale = false;
	bProperEscape = false;
	
	for (int i = 1; i < 2049; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			bInUse[i - 1] = false;
		}
	}
	if (StrEqual(name, "round_start"))
	{
		if (bManualChange)
		{
			bManualChange = false;
			CreateTimer(5.0, ModifyRescueProperties);
		}
		else
		{
			if (!bLostAttempt)
			{
				CreateTimer(2.5, ModifyRescueProperties);
			}
			else
			{
				bLostAttempt = false;
				CreateTimer(1.25, ModifyRescueProperties);
			}
		}
	}
	else
	{
 		if (StrEqual(name, "mission_lost"))
		{
			if (bLostAttempt)
			{
				return;
			}
			
			bLostAttempt = true;
		}
		
		if (StrEqual(sMap, "c1m4_atrium", false))
		{
			IterateGameEntities("logic_relay", "relay_force_finale_start", false, "OnTrigger", OnScavengeFinales, true);
		}
		else if (StrEqual(sMap, "c5m5_bridge", false) || StrEqual(sMap, "c5m5_darkbridge", false))
		{
			IterateGameEntities("logic_relay", "gate_opened", false, "OnTrigger", OnCustomFinaleStart, true);
			IterateGameEntities("logic_relay", "relay_start_heli", false, "OnTrigger", OnCustomFinaleEnd, true);
		}
		else if (StrEqual(sMap, "c6m3_port", false) || StrEqual(sMap, "c7m3_port", false))
		{
			CommenceScavenging();
			TweakGenerators(true);
			
			IterateGameEntities("logic_relay", "relay_gate_opened", false, "OnTrigger", OnPortBridgeAccessable, true);
		}
		else if (StrEqual(sMap, "c13m4_cutthroatcreek", false))
		{
			IterateGameEntities("func_door", "startbldg_door", false, "OnFullyOpen", OnCustomFinaleStart, true, true);
			IterateGameEntities("logic_relay", "relay_readyvehicle", false, "OnTrigger", OnCustomFinaleEnd, true);
		}
		else if (StrEqual(sMap, "l4d2_stadium5_stadium", false))
		{
			IterateGameEntities("logic_relay", "f18_start_relay", false, "OnTrigger", OnCustomFinaleStart, true);
			IterateGameEntities("logic_relay", "relay_start_heli", false, "OnTrigger", OnCustomFinaleEnd, true);
		}
		else if (StrEqual(sMap, "l4d2_wanli03", false))
		{
			IterateGameEntities("func_breakable", "ice_block", false, "OnBreak", OnWanLiFinale, false, true);
		}
		else if (StrEqual(sMap, "uf4_airfield", false))
		{
			IterateGameEntities("logic_relay", "finale_start_relay", false, "OnTrigger", OnScavengeFinales, true);
			IterateGameEntities("logic_relay", "hanger_door_relay", false, "OnTrigger", OnUrbanFlightFinale, true);
		}
		else if (StrEqual(sMap, "wth_5", false))
		{
			IterateGameEntities("func_door", "Door_finale", false, "OnOpen", OnScavengeFinales, true);
		}
	}
}

public Action ModifyRescueProperties(Handle timer)
{
	if (StrEqual(sMap, "c1m4_atrium", false))
	{
		IterateGameEntities("logic_relay", "relay_force_finale_start", true, "OnTrigger", OnScavengeFinales, true);
	}
	else if (StrEqual(sMap, "c5m5_bridge", false) || StrEqual(sMap, "c5m5_darkbridge", false))
	{
		IterateGameEntities("logic_relay", "gate_opened", true, "OnTrigger", OnCustomFinaleStart, true);
		IterateGameEntities("logic_relay", "relay_start_heli", true, "OnTrigger", OnCustomFinaleEnd, true);
	}
	else if (StrEqual(sMap, "c6m3_port", false) || StrEqual(sMap, "c7m3_port", false))
	{
		CommenceScavenging(true);
		TweakGenerators();
		
		IterateGameEntities("logic_relay", "relay_gate_opened", true, "OnTrigger", OnPortBridgeAccessable, true);
	}
	else if (StrEqual(sMap, "c13m4_cutthroatcreek", false))
	{
		IterateGameEntities("func_door", "startbldg_door", true, "OnFullyOpen", OnCustomFinaleStart, true, true);
		IterateGameEntities("logic_relay", "relay_readyvehicle", true, "OnTrigger", OnCustomFinaleEnd, true);
	}
	else if (StrEqual(sMap, "l4d2_stadium5_stadium", false))
	{
		IterateGameEntities("logic_relay", "f18_start_relay", true, "OnTrigger", OnCustomFinaleStart, true);
		IterateGameEntities("logic_relay", "relay_start_heli", true, "OnTrigger", OnCustomFinaleEnd, true);
	}
	else if (StrEqual(sMap, "l4d2_wanli03", false))
	{
		IterateGameEntities("func_breakable", "ice_block", true, "OnBreak", OnWanLiFinale, false, true);
	}
	else if (StrEqual(sMap, "uf4_airfield", false))
	{
		IterateGameEntities("logic_relay", "finale_start_relay", true, "OnTrigger", OnScavengeFinales, true);
		IterateGameEntities("logic_relay", "hanger_door_relay", true, "OnTrigger", OnUrbanFlightFinale, true);
	}
	else if (StrEqual(sMap, "wth_5", false))
	{
		IterateGameEntities("func_door", "Door_finale", true, "OnOpen", OnScavengeFinales, true);
	}
	
	return Plugin_Stop;
}

public void OnGasCanPourCompleted(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D_IsMissionFinalMap() || !bFinaleStarted || !bScavengeBegin)
	{
		return;
	}
	
	iGasPoured += 1;
	
	if (StrEqual(sMap, "c1m4_atrium", false))
	{
		switch (iGasPoured)
		{
			case 1,2,4,5,7,8,9,11,12:
			{
				int iRandClient = GetRandomClient();
				ExecuteSpawn2(iRandClient, "mob auto", 1);
			}
			case 3:
			{
				L4D2_ChangeFinaleStage(8, "Forcing 1st Tank Stage!");
				
				PrintHintTextToAll("Current Car Fuel: 25％ Refueled!");
				EmitSoundToAll(sNeededSounds[4]);
			}
			case 6:
			{
				L4D2_ChangeFinaleStage(7, "Forcing 2nd Horde Stage!");
				
				PrintHintTextToAll("Current Car Fuel: 50％ Refueled!");
				EmitSoundToAll(sNeededSounds[4]);
			}
			case 10:
			{
				if (L4D2_GetTankCount() < 1)
				{
					L4D2_ChangeFinaleStage(8, "Forcing 2nd Tank Stage!");
				}
				
				PrintHintTextToAll("Current Car Fuel: 75％ Refueled!");
				EmitSoundToAll(sNeededSounds[4]);
			}
			case 13:
			{
				L4D2_ChangeFinaleStage(6, "Forcing Rescue Stage!");
				
				PrintHintTextToAll("Car Has Been Fully Refueled!");
				EmitSoundToAll(sNeededSounds[5]);
				
				bScavengeBegin = false;
			}
		}
	}
	else if (StrEqual(sMap, "c6m3_port", false))
	{
		switch (iGasPoured)
		{
			case 1,2,3,5,6,7,9,10,11,13,14,15:
			{
				int iRandClient = GetRandomClient();
				ExecuteSpawn2(iRandClient, "mob auto", 1);
			}
			case 4:
			{
				L4D2_ChangeFinaleStage(8, "Forcing 1st Tank Stage!");
				
				PrintHintTextToAll("Current Generator Fuel: 25％ Filled!");
				EmitSoundToAll(sNeededSounds[6]);
			}
			case 8:
			{
				L4D2_ChangeFinaleStage(7, "Forcing 2nd Horde Stage!");
				
				PrintHintTextToAll("Current Generator Fuel: 50％ Filled!");
				EmitSoundToAll(sNeededSounds[6]);
			}
			case 12:
			{
				if (L4D2_GetTankCount() < 1)
				{
					L4D2_ChangeFinaleStage(8, "Forcing 2nd Tank Stage!");
				}
				
				PrintHintTextToAll("Current Generator Fuel: 75％ Filled!");
				EmitSoundToAll(sNeededSounds[6]);
			}
			case 16:
			{
				CreateTimer(1.0, CheckDangerSigns);
				
				PrintHintTextToAll("Generator Has Been Filled Up!");
				EmitSoundToAll(sNeededSounds[7]);
				
				bScavengeBegin = false;
			}
		}
	}
	else if (StrEqual(sMap, "uf4_airfield", false))
	{
		switch (iGasPoured)
		{
			case 1,2,3,5,6,7:
			{
				int iRandClient = GetRandomClient();
				ExecuteSpawn2(iRandClient, "mob auto", 1);
			}
			case 4:
			{
				L4D2_ChangeFinaleStage(7, "Forcing 1st Horde Stage!");
				
				PrintHintTextToAll("4 More Cans To Go!");
				EmitSoundToAll(sNeededSounds[6]);
			}
			case 8:
			{
				L4D2_ChangeFinaleStage(8, "Commencing 1st Tank Stage!");
				
				PrintHintTextToAll("It's Possible To Turn The\nPower Back On Now!");
				bScavengeBegin = false;
			}
		}
	}
	else if (StrEqual(sMap, "wth_5", false))
	{
		switch (iGasPoured)
		{
			case 1,2,3,5,6,7,9,10,11,13,14,15:
			{
				int iRandClient = GetRandomClient();
				ExecuteSpawn2(iRandClient, "mob auto", 1);
			}
			case 4:
			{
				L4D2_ChangeFinaleStage(8, "Forcing 1st Tank Stage!");
				
				PrintHintTextToAll("Current Train Fuel: 25％ Pumped!");
				EmitSoundToAll(sNeededSounds[8]);
			}
			case 8:
			{
				L4D2_ChangeFinaleStage(7, "Forcing 2nd Horde Stage!");
				
				PrintHintTextToAll("Current Train Fuel: 50％ Pumped!");
				EmitSoundToAll(sNeededSounds[8]);
			}
			case 12:
			{
				if (L4D2_GetTankCount() < 1)
				{
					L4D2_ChangeFinaleStage(8, "Forcing 2nd Tank Stage!");
				}
				
				PrintHintTextToAll("Current Train Fuel: 75％ Pumped!");
				EmitSoundToAll(sNeededSounds[8]);
			}
			case 16:
			{
				L4D2_ChangeFinaleStage(6, "Forcing Rescue Stage!");
				
				PrintHintTextToAll("Train's Been Pumped With Fuel!");
				EmitSoundToAll(sNeededSounds[3]);
				
				bScavengeBegin = false;
			}
		}
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D_IsMissionFinalMap() || !bFinaleStarted || bProperEscape)
	{
		return;
	}
	
	int died = GetClientOfUserId(event.GetInt("userid"));
	if (IsTank(died))
	{
		CreateTimer(5.0, CheckDangerSigns);
	}
}

public Action CheckDangerSigns(Handle timer)
{
	int iTankCount = L4D2_GetTankCount();
	if (iTankCount > 0)
	{
		if (!StrEqual(sMap, "c6m3_port", false) && !StrEqual(sMap, "c7m3_port", false))
		{
			if (iRescueMinutes - iFinaleMinutes > 0)
			{
				return Plugin_Stop;
			}
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || GetClientTeam(i) == 1 || IsFakeClient(i))
				{
					continue;
				}
				
				if (GetClientTeam(i) == 2)
				{
					EmitSoundToClient(i, sNeededSounds[1]);
					
					if (StrEqual(sMap, "c11m5_runway", false) || StrEqual(sMap, "l4d_farm01_hilltop_rev"))
					{
						PrintHintText(i, "Kill %s Before The\nPlane Starts Its Engines!", (iTankCount != 1) ? "All Tanks" : "The Tank");
					}
					else if (StrEqual(sMap, "uf4_airfield", false))
					{
						PrintHintText(i, "The Pilot Wants Survivors To\nClear Any Signs Of Danger First!");
					}
					else
					{
						PrintHintText(i, "Defeat %s Before The\nRescue Vehicle Appears!", (iTankCount != 1) ? "All Tanks" : "The Tank");
					}
				}
				else
				{
					EmitSoundToClient(i, sNeededSounds[2]);
					PrintHintText(i, "Wreak All Havoc As Long\nAs %s In Play!", (iTankCount == 1) ? "A Tank Is" : "The Tanks Are");
				}
			}
		}
		else
		{
			if (StrEqual(sMap, "c6m3_port", false) && (bScavengeBegin || iGasPoured < 16))
			{
				return Plugin_Stop;
			}
			else if (StrEqual(sMap, "c7m3_port", false) && iRescueMinutes - iFinaleMinutes > 0)
			{
				return Plugin_Stop;
			}
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || GetClientTeam(i) == 1 || IsFakeClient(i))
				{
					continue;
				}
				
				if (GetClientTeam(i) == 2)
				{
					EmitSoundToClient(i, sNeededSounds[1]);
					PrintHintText(i, "Wipe The Area From Any\n%s Present!", (iTankCount != 1) ? "Tanks" : "Tank");
				}
				else
				{
					EmitSoundToClient(i, sNeededSounds[2]);
					PrintHintText(i, "Help The %s Destroy Survivors\nWhile They're Busy With %s", (iTankCount == 1) ? "Tank" : "Tanks", (iTankCount != -1) ? "Them" : "It");
				}
			}
		}
	}
	else
	{
		if (bProperEscape)
		{
			return Plugin_Stop;
		}
		
		if (StrEqual(sMap, "c6m3_port", false))
		{
			if (bScavengeBegin || iGasPoured < 16)
			{
				return Plugin_Stop;
			}
			
			char sFinaleName[128];
			
			int iFinaleEnt = -1, iFinaleEnt2 = -1;
			while ((iFinaleEnt = FindEntityByClassname(iFinaleEnt, "func_elevator")) != -1)
			{
				if (!IsValidEntity(iFinaleEnt) || !IsValidEdict(iFinaleEnt))
				{
					continue;
				}
				
				GetEntPropString(iFinaleEnt, Prop_Data, "m_iName", sFinaleName, sizeof(sFinaleName));
				if (StrEqual(sFinaleName, "bridge_elevator", false))
				{
					SetVariantString("bottom");
					AcceptEntityInput(iFinaleEnt, "MoveToFloor");
					
					break;
				}
			}
			
			while ((iFinaleEnt2 = FindEntityByClassname(iFinaleEnt2, "ambient_generic")) != -1)
			{
				if (!IsValidEntity(iFinaleEnt2) || !IsValidEdict(iFinaleEnt2))
				{
					continue;
				}
				
				GetEntPropString(iFinaleEnt2, Prop_Data, "m_iName", sFinaleName, sizeof(sFinaleName));
				if (StrEqual(sFinaleName, "bridge_move_sound", false))
				{
					AcceptEntityInput(iFinaleEnt2, "PlaySound");
					break;
				}
			}
		}
		else if (StrEqual(sMap, "c7m3_port", false))
		{
			if (iRescueMinutes - iFinaleMinutes > 0)
			{
				return Plugin_Stop;
			}
			
			char sFinaleName[128];
			
			int iFinaleEnt = -1;
			while ((iFinaleEnt = FindEntityByClassname(iFinaleEnt, "ambient_generic")) != -1)
			{
				GetEntPropString(iFinaleEnt, Prop_Data, "m_iName", sFinaleName, sizeof(sFinaleName));
				if (!StrEqual(sFinaleName, "bridge_move_sound", false))
				{
					continue;
				}
				
				AcceptEntityInput(iFinaleEnt, "PlaySound");
				break;
			}
			
			int iFinaleEnt2 = -1;
			while ((iFinaleEnt2 = FindEntityByClassname(iFinaleEnt2, "func_elevator")) != -1)
			{
				if (!IsValidEntity(iFinaleEnt2) || !IsValidEdict(iFinaleEnt2))
				{
					continue;
				}
				
				GetEntPropString(iFinaleEnt2, Prop_Data, "m_iName", sFinaleName, sizeof(sFinaleName));
				if (StrEqual(sFinaleName, "bridge_elevator", false))
				{
					SetVariantString("bottom");
					AcceptEntityInput(iFinaleEnt2, "MoveToFloor");
					
					break;
				}
			}
		}
		else
		{
			if (iRescueMinutes - iFinaleMinutes > 0)
			{
				return Plugin_Stop;
			}
			
			bProperEscape = true;
			L4D2_SendInRescueVehicle();
			
			if (!bProperFinale)
			{
				bProperFinale = true;
				L4D2_ChangeFinaleStage(6, "Commencing Rescue Stage!");
			}
		}
	}
	
	return Plugin_Stop;
}

public Action L4D_OnSpawnTank(float vector[3], float qangle[3])
{
	if (!L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	if (bFinaleStarted)
	{
		if (iFinaleStage != 6 && iFinaleStage != 8)
		{
			return Plugin_Handled;
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public Action L4D_OnMobRushStart()
{
	if (!L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	if (bFinaleStarted)
	{
		if (iFinaleStage != 6 && iFinaleStage != 7)
		{
			return Plugin_Handled;
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public Action L4D2_OnChangeFinaleStage(int &finaleType, const char[] arg)
{
	if (StrEqual(sMap, "c1m4_atrium", false) || StrEqual(sMap, "c5m5_bridge", false) || StrEqual(sMap, "c5m5_darkbridge", false) || 
		StrEqual(sMap, "c6m3_port", false) || StrEqual(sMap, "c11m4_cutthroatcreek", false) || StrEqual(sMap, "l4d2_stadium5_stadium", false) || 
		StrEqual(sMap, "l4d2_pasiri4", false) || StrEqual(sMap, "l4d2_wanli03", false) || StrEqual(sMap, "uf4_airfield", false) || 
		StrEqual(sMap, "wth_5", false))
	{
		return Plugin_Continue;
	}
	
	if (finaleType == 1)
	{
		if (!bFinaleStarted)
		{
			bFinaleStarted = true;
		}
		
		if (!StrEqual(sMap, "c11m5_runway", false) && !StrEqual(sMap, "l4d_farm01_hilltop_rev", false))
		{
			if (StrEqual(sMap, "c7m3_port", false))
			{
				PrintHintTextToAll("The Bridge Is Lowering In\n%i Minutes!", iRescueMinutes);
			}
			else if (StrEqual(sMap, "rmstitanic_m4", false))
			{
				PrintHintTextToAll("Lifeboat Will Soon Be Ready\nIn %i Minutes!", iRescueMinutes);
			}
			else
			{
				PrintHintTextToAll("Rescue Vehicle Will Arrive In\n%i Minutes!", iRescueMinutes);
			}
		}
		else
		{
			PrintHintTextToAll("Current Plane Fuel: 0％");
		}
		EmitSoundToAll(sNeededSounds[0]);
		
		CreateTimer(1.0, CheckEscapeETA, _, TIMER_REPEAT);
		CreateTimer(3.0, RestoreFinaleBehavior);
		
		return Plugin_Continue;
	}
	
	if (bProperFinale)
	{
		iFinaleStage = finaleType;
		
		CreateTimer(1.5, ForcePluginBehavior);
	}
	
	return Plugin_Continue;
}

public Action CheckEscapeETA(Handle timer)
{
	if (bManualChange || bLostAttempt || !bFinaleStarted || bProperEscape)
	{
		return Plugin_Stop;
	}
	
	if (iFinaleSeconds > 59)
	{
		iFinaleSeconds = 0;
		iFinaleMinutes += 1;
		
		int iMinutesLeft = iRescueMinutes - iFinaleMinutes;
		if (iMinutesLeft < 1)
		{
			CreateTimer(0.1, CheckDangerSigns);
			return Plugin_Stop;
		}
		
		int iTankCount = L4D2_GetTankCount();
		
		if (iMinutesLeft == 10)
		{
			if (bProperFinale)
			{
				return Plugin_Continue;
			}
			
			bProperFinale = true;
			
			if (StrEqual(sMap, "c7m3_port", false))
			{
				if (iTankCount > 0)
				{
					if (iFinaleStage != 7)
					{
						L4D2_ChangeFinaleStage(7, "Commencing First Horde Stage!");
					}
				}
				else
				{
					if (iFinaleStage != 8)
					{
						L4D2_ChangeFinaleStage(8, "Commencing First Tank Stage!");
					}
				}
				
				PrintHintTextToAll("The Next Generator Starts In\n3 Minutes!");
			}
			else
			{
				if (iFinaleStage != 10)
				{
					L4D2_ChangeFinaleStage(10, "Commencing Combat Respite Stage!");
				}
				
				CreateTimer(15.0, PostCRMob);
				CreateTimer(30.0, PostCRMob);
				CreateTimer(45.0, PostCRMob);
			}
		}
		else if (iMinutesLeft == 7)
		{
			if (bProperFinale)
			{
				return Plugin_Continue;
			}
			
			bProperFinale = true;
			
			if (StrEqual(sMap, "c7m3_port", false))
			{
				PrintHintTextToAll("The Second Generator Was Started!");
				
				int iRandGenerator = GetRandomGenerator();
				AcceptEntityInput(iRandGenerator, "Press");
				
				CreateTimer(5.0, PostGeneratorStartUp, iRandGenerator);
				CreateTimer(8.0, SacrificeBehaviorFix);
			}
			else
			{
				if (iFinaleStage != 8)
				{
					L4D2_ChangeFinaleStage(8, "Commencing 1st Tank Stage!");
				}
				
				if (StrEqual(sMap, "c11m5_runway", false) || StrEqual(sMap, "l4d_farm01_hilltop_rev", false))
				{
					EmitSoundToAll(sNeededSounds[0]);
					PrintHintTextToAll("Current Plane Fuel: 25％");
				}
			}
		}
		else if (iMinutesLeft == 5)
		{
			if (bProperFinale)
			{
				return Plugin_Continue;
			}
			
			bProperFinale = true;
			
			if (StrEqual(sMap, "c7m3_port", false))
			{
				if (iTankCount < 1)
				{
					if (iFinaleStage != 8)
					{
						L4D2_ChangeFinaleStage(8, "Commencing 2nd Tank Stage!");
					}
				}
				else
				{
					if (iFinaleStage != 7)
					{
						L4D2_ChangeFinaleStage(7, "Commencing 2nd Horde Stage!");
					}
				}
				
				PrintHintTextToAll("The Last Generator Starts In\n2 Minutes!");
			}
			else
			{
				if (iFinaleStage != 7)
				{
					L4D2_ChangeFinaleStage(7, "Commencing 2nd Horde Stage!");
				}
				
				if (StrEqual(sMap, "c11m5_runway", false) || StrEqual(sMap, "l4d_farm01_hilltop_rev", false))
				{
					EmitSoundToAll(sNeededSounds[0]);
					PrintHintTextToAll("Current Plane Fuel: 50％");
				}
				else if (StrEqual(sMap, "uf4_airfield", false))
				{
					EmitSoundToAll(sNeededSounds[0]);
					PrintHintTextToAll("The Pilot Is Making Preparations!\nHold Out For 5 Minutes!");
				}
			}
		}
		else if (iMinutesLeft == 3)
		{
			if (bProperFinale)
			{
				return Plugin_Continue;
			}
			
			bProperFinale = true;
			
			if (StrEqual(sMap, "c7m3_port", false))
			{
				PrintHintTextToAll("The Third Generator Was Started!");
				
				int iRandGenerator = GetRandomGenerator();
				AcceptEntityInput(iRandGenerator, "Press");
				
				CreateTimer(5.0, PostGeneratorStartUp, iRandGenerator);
				CreateTimer(8.0, SacrificeBehaviorFix);
			}
			else
			{
				if (iFinaleStage != 8)
				{
					L4D2_ChangeFinaleStage(8, "Commencing 2nd Tank Stage!");
				}
				
				if (StrEqual(sMap, "c11m5_runway", false) || StrEqual(sMap, "l4d_farm01_hilltop_rev", false))
				{
					EmitSoundToAll(sNeededSounds[0]);
					PrintHintTextToAll("Current Plane Fuel: 75％");
				}
				else if (StrEqual(sMap, "uf4_airfield", false))
				{
					EmitSoundToAll(sNeededSounds[0]);
					PrintHintTextToAll("Survive For 3 Minutes More\nAs The Pilot Checks Everything In Place!");
				}
			}
		}
		else
		{
			if (StrEqual(sMap, "c7m3_port", false))
			{
				switch (iMinutesLeft)
				{
					case 1,2,11: PrintHintTextToAll("The Bridge Is Lowering In\n%d %s", iMinutesLeft, (iMinutesLeft != 1) ? "Minutes" : "Minute");
					case 4: PrintHintTextToAll("The Last Generator Starts In\n1 Minute!");
					case 6: PrintHintTextToAll("The Last Generator Starts In\n3 Minutes!");
					case 8: PrintHintTextToAll("The Next Generator Starts In\n1 Minute!");
					case 9: PrintHintTextToAll("The Next Generator Starts In\n2 Minutes!");
				}
			}
			
			int iRandClient = GetRandomClient();
			ExecuteSpawn2(iRandClient, "mob auto", 3);
		}
		
		if (!StrEqual(sMap, "c11m5_runway", false) && !StrEqual(sMap, "l4d_farm01_hilltop_rev", false) && !StrEqual(sMap, "uf4_airfield", false))
		{
			EmitSoundToAll(sNeededSounds[0]);
			
			if (!StrEqual(sMap, "c7m3_port", false))
			{
				if (StrEqual(sMap, "rmstitanic_m4", false))
				{
					PrintHintTextToAll("Lifeboat Will Soon Be Ready\nIn %d %s", iMinutesLeft, (iMinutesLeft == 1) ? "Minute" : "Minutes");
				}
				else
				{
					PrintHintTextToAll("Rescue Vehicle Will Arrive In\n%d %s", iMinutesLeft, (iMinutesLeft == 1) ? "Minute" : "Minutes");
				}
			}
		}
	}
	else
	{
		iFinaleSeconds += 1;
	}
	
	return Plugin_Continue;
}

public Action RestoreFinaleBehavior(Handle timer)
{
	if (bManualChange || bLostAttempt || !bFinaleStarted || bProperEscape)
	{
		return Plugin_Stop;
	}
	
	if (!bProperFinale)
	{
		bProperFinale = true;
		
		if (StrEqual(sMap, "c7m3_port", false))
		{
			if (iFinaleStage != 10)
			{
				L4D2_ChangeFinaleStage(10, "Commencing Pre-Finale Combat Respite Stage!");
			}
			
			CreateTimer(2.0, SacrificeBehaviorFix);
		}
		else
		{
			if (iFinaleStage != 7)
			{
				L4D2_ChangeFinaleStage(7, "Commencing Pre-Finale Horde Stage!");
			}
		}
	}
	
	return Plugin_Stop;
}

public Action SacrificeBehaviorFix(Handle timer)
{
	if (bManualChange || bLostAttempt || !bFinaleStarted || bProperEscape)
	{
		return Plugin_Stop;
	}
	
	if (!bProperFinale)
	{
		bProperFinale = true;
		
		switch (GetRandomInt(1, 2))
		{
			case 1:
			{
				if (iFinaleStage != 8 && L4D2_GetTankCount() < 1)
				{
					L4D2_ChangeFinaleStage(8, "Commencing Pre-Finale Tank Stage!");
				}
			}
			case 2:
			{
				if (iFinaleStage != 7)
				{
					L4D2_ChangeFinaleStage(7, "Commencing Pre-Finale Horde Stage!");
				}
			}
		}
	}
	
	return Plugin_Stop;
}

public Action PostCRMob(Handle timer)
{
	if (!bFinaleStarted || bManualChange || bLostAttempt || bProperEscape)
	{
		return Plugin_Stop;
	}
	
	if (iFinaleStage == 10)
	{
		int iRandClient = GetRandomClient();
		ExecuteSpawn2(iRandClient, "mob auto", 2);
	}
	
	return Plugin_Stop;
}

public Action PostGeneratorStartUp(Handle timer, any entity)
{
	if (!IsValidEnt(entity))
	{
		return Plugin_Stop;
	}
	
	int iGeneratorID = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if (iGeneratorID != 1651732)
	{
		SDKUnhook(entity, SDKHook_Use, OnGeneratorUse);
		
		UnhookSingleEntityOutput(entity, "OnPressed", OnGeneratorPressed);
		
		UnhookSingleEntityOutput(entity, "OnUnPressed", OnGeneratorFinish);
		UnhookSingleEntityOutput(entity, "OnTimeUp", OnGeneratorFinish);
		
		int iStartUpEnt = -1;
		char sGeneratorNames[9][128] =
		{
			"finale_start_button",
			"sound_generator_start",
			"sound_generator_run",
			"generator_start_particles",
			"generator_model",
			"radio_game_event_pre",
			"mob_spawner_finale",
			"relay_advance_finale_state",
			""
		};
		
		for (int i = 0; i < 8; i++)
		{
			switch (iGeneratorID)
			{
				case 1512662:
				{
					if (i == 4)
					{
						StrCat(sGeneratorNames[i], 128, "2");
					}
					else if (i == 8)
					{
						strcopy(sGeneratorNames[i], 128, "generator2_tankmessage_templated");
					}
				}
				case 2052608:
				{
					if (i == 8)
					{
						break;
					}
					else
					{
						StrCat(sGeneratorNames[i], 128, "1");
					}
				}
				case 2054672:
				{
					if (i != 4)
					{
						if (i != 8)
						{
							StrCat(sGeneratorNames[i], 128, "2");
						}
						else
						{
							strcopy(sGeneratorNames[i], 128, "generator3_tankmessage_templated");
						}
					}
					else
					{
						StrCat(sGeneratorNames[i], 128, "3");
					}
				}
			}
			
			iStartUpEnt = FindEntityByName(sGeneratorNames[i]);
			if (iStartUpEnt == -1)
			{
				if (i == 8)
				{	
					break;
				}
				else
				{
					continue;
				}
			}
			
			switch (i)
			{
				case 0,5,8: AcceptEntityInput(iStartUpEnt, "Kill");
				case 1: AcceptEntityInput(iStartUpEnt, "StopSound");
				case 2: AcceptEntityInput(iStartUpEnt, "PlaySound");
				case 3: AcceptEntityInput(iStartUpEnt, "Start");
				case 4: AcceptEntityInput(iStartUpEnt, "StopGlowing");
				case 6: AcceptEntityInput(iStartUpEnt, "Enable");
				case 7: AcceptEntityInput(iStartUpEnt, "Trigger");
			}
		}
	}
	
	return Plugin_Stop;
}

public Action ForcePluginBehavior(Handle timer)
{
	if (!bProperFinale)
	{
		return Plugin_Stop;
	}
	
	bProperFinale = false;
	return Plugin_Stop;
}

public Action L4D2_OnSendInRescueVehicle()
{
	if (StrEqual(sMap, "c1m4_atrium", false) || StrEqual(sMap, "c5m5_bridge", false) || StrEqual(sMap, "c5m5_darkbridge", false) || 
		StrEqual(sMap, "c11m4_cutthroatcreek", false) || StrEqual(sMap, "l4d2_pasiri4", false) || StrEqual(sMap, "l4d2_stadium5_stadium", false) || 
		StrEqual(sMap, "l4d2_wanli03", false) || StrEqual(sMap, "wth_5", false))
	{
		return Plugin_Continue;
	}
	
	if (bProperEscape)
	{
		if (StrEqual(sMap, "c6m3_port", false) || StrEqual(sMap, "c7m3_port", false))
		{
			PrintHintTextToAll("The Bridge Has Been Lowered!");
		}
		else if (StrEqual(sMap, "c11m5_runway", false) || StrEqual(sMap, "l4d_farm01_hilltop_rev", false))
		{
			PrintHintTextToAll("The Plane's Ready To Depart!");
		}
		else if (StrEqual(sMap, "rmstitanic_m4", false))
		{
			PrintHintTextToAll("Lifeboat Is Fully Prepared To Lower!");
		}
		else if (StrEqual(sMap, "uf4_airfield", false))
		{
			PrintHintTextToAll("The Pilot Gave A Thumbs-Up!\nSurvivors Are Now Able To Be Safe!");
		}
		else
		{
			PrintHintTextToAll("Rescue Vehicle Arrives!\nSurvivors Can Escape Now!");
		}
		
		EmitSoundToAll(sNeededSounds[3]);
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

void IterateGameEntities(char[] sClassname, char[] sName, bool bHook, char[] sOutputName, EntityOutput eoCallback, bool bOneInstanceOnly, bool bValidCheck = false)
{
	int iGameEnt = -1;
	while ((iGameEnt = FindEntityByClassname(iGameEnt, sClassname)) != -1)
	{
		if (bValidCheck && (!IsValidEntity(iGameEnt) || !IsValidEdict(iGameEnt)))
		{
			continue;
		}
		
		char sGameEntName[128];
		GetEntPropString(iGameEnt, Prop_Data, "m_iName", sGameEntName, sizeof(sGameEntName));
		if (StrContains(sGameEntName, sName, false) != -1)
		{
			if (bHook)
			{
				HookSingleEntityOutput(iGameEnt, sOutputName, eoCallback);
			}
			else
			{
				UnhookSingleEntityOutput(iGameEnt, sOutputName, eoCallback);
			}
			
			if (bOneInstanceOnly)
			{
				break;
			}
		}
	}
}

public void OnScavengeFinales(const char[] output, int caller, int activator, float delay)
{
	if (bFinaleStarted)
	{
		return;
	}
	
	bFinaleStarted = true;
	if (!bScavengeBegin)
	{
		bScavengeBegin = true;
		EmitSoundToAll(sNeededSounds[0]);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) == 1 || IsFakeClient(i))
			{
				continue;
			}
			
			if (GetClientTeam(i) == 3)
			{
				PrintHintText(i, "Make It Harder For Survivors\nTo Collect Gas Cans!");
			}
			else
			{
				if (StrEqual(sMap, "c1m4_atrium", false))
				{
					PrintHintText(i, "Refuel Jimmy Gibbs's Car Before\nAchieving Safety!");
				}
				else if (StrEqual(sMap, "c6m3_port", false))
				{
					PrintHintText(i, "Fill Up The Generator To\nLower The Bridge!");
				}
				else if (StrEqual(sMap, "uf4_airfield", false))
				{
					PrintHintText(i, "Bring The Airfield's Power Back\nBy Gassing Up The Generator!");
				}
				else if (StrEqual(sMap, "wth_5", false))
				{
					PrintHintText(i, "Pump The Truck With Gas\nTo Fill Up The Train's Fuel!");
				}
			}
		}
	}
}

public void OnCustomFinaleStart(const char[] output, int caller, int activator, float delay)
{
	if (bFinaleStarted)
	{
		return;
	}
	
	bFinaleStarted = true;
	EmitSoundToAll(sNeededSounds[0]);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		
		if (GetClientTeam(i) == 3)
		{
			PrintHintText(i, "Ambush The Survivors Before They\nCan Reach The End Safely!");
		}
		else
		{
			PrintHintText(i, "Survivors Must Rush Towards The\nRescue Vehicle Waiting In The End!");
		}
	}
}

public void OnCustomFinaleEnd(const char[] output, int caller, int activator, float delay)
{
	if (!bFinaleStarted)
	{
		return;
	}
	
	EmitSoundToAll(sNeededSounds[3]);
	PrintHintTextToAll("Survivors Are Nearing Towards Escape!\nThere's A Chance They Can Be Rescued!");
}

public void OnPortBridgeAccessable(const char[] output, int caller, int activator, float delay)
{
	if (!bFinaleStarted)
	{
		return;
	}
	
	if (!bProperEscape)
	{
		bProperEscape = true;
		L4D2_SendInRescueVehicle();
		
		if (StrEqual(sMap, "c7m3_port", false))
		{
			if (bProperFinale)
			{
				return;
			}
			
			bProperFinale = true;
		}
		L4D2_ChangeFinaleStage(6, "Commencing Rescue Stage!");
	}
}

public void OnWanLiFinale(const char[] output, int caller, int activator, float delay)
{
	iIceMelted += 1;
	if (iIceMelted > 6)
	{
		EmitSoundToAll(sNeededSounds[3]);
		PrintHintTextToAll("All Ice Have Been Melted!\nThe Boat's Now Free And Able To Sail!");
	}
	else
	{
		PrintHintTextToAll("No. Of Ice Melted: %d / 7", iIceMelted);
		EmitSoundToAll(sNeededSounds[0]);
	}
	
	UnhookSingleEntityOutput(caller, "OnBreak", OnWanLiFinale);
}

public void OnUrbanFlightFinale(const char[] output, int caller, int activator, float delay)
{
	if (!bFinaleStarted || bScavengeBegin)
	{
		return;
	}
	
	iFinaleSeconds = 60;
	iFinaleMinutes = -1;
	
	CreateTimer(1.0, CheckEscapeETA, _, TIMER_REPEAT);
}

bool IsInBugSpot(int client)
{
	float fPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
	
	if (fPos[2] < -120.0)
	{
		if ((fPos[0] > -1151.9 && fPos[1] > 2653.9) || (fPos[0] > -3344.9 && fPos[1] > 2479.9) || 
			(fPos[1] < 2674.9 && fPos[0] > -3325.9) || (fPos[1] < 3423.9 && fPos[1] > -3512.9))
		{
			return false;
		}
		
		return true;
	}
	
	return false;
}

int GetRandomGenerator()
{
	int iSelected = 0;
	
	for (int i = 1; i < 2049; i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i))
		{
			continue;
		}
		
		char sEntityClass[64];
		GetEdictClassname(i, sEntityClass, sizeof(sEntityClass));
		if (StrEqual(sEntityClass, "func_button_timed"))
		{
			if (GetEntProp(i, Prop_Data, "m_iHammerID") == 1651732)
			{
				continue;
			}
			
			iSelected = i;
			break;
		}
	}
	
	return iSelected;
}

int FindEntityByName(const char[] sGivenName)
{
	int iEntityMatch = -1;
	
	for (int i = 1; i < 2049; i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i) || FindDataMapInfo(i, "m_iName") == -1)
		{
			continue;
		}
		
		char sEntityName[128];
		GetEntPropString(i, Prop_Data, "m_iName", sEntityName, sizeof(sEntityName));
		if (StrEqual(sEntityName, sGivenName, false))
		{
			iEntityMatch = i;
			break;
		}
	}
	
	return iEntityMatch;
}

int GetRandomClient()
{
	int iClient = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iClient = i;
			break;
		}
	}
	return iClient;
}

void CommenceScavenging(bool bStart = false)
{
	if (!StrEqual(sMap, "c6m3_port", false))
	{
		return;
	}
	
	IterateGameEntities("logic_relay", "relay_force_finale_start", bStart, "OnTrigger", OnScavengeFinales, true);
}

void TweakGenerators(bool bUndo = false)
{
	if (!StrEqual(sMap, "c7m3_port", false))
	{
		return;
	}
	
	int iGeneratorEnt = -1;
	while ((iGeneratorEnt = FindEntityByClassname(iGeneratorEnt, "func_button_timed")) != -1)
	{
		if (!IsValidEntity(iGeneratorEnt) || !IsValidEdict(iGeneratorEnt))
		{
			continue;
		}
		
		if (GetEntProp(iGeneratorEnt, Prop_Data, "m_iHammerID") != 1651732)
		{
			if (bUndo)
			{
				SDKUnhook(iGeneratorEnt, SDKHook_Use, OnGeneratorUse);
				
				UnhookSingleEntityOutput(iGeneratorEnt, "OnPressed", OnGeneratorPressed);
				
				UnhookSingleEntityOutput(iGeneratorEnt, "OnUnPressed", OnGeneratorFinish);
				UnhookSingleEntityOutput(iGeneratorEnt, "OnTimeUp", OnGeneratorFinish);
			}
			else
			{
				SDKHook(iGeneratorEnt, SDKHook_Use, OnGeneratorUse);
				
				HookSingleEntityOutput(iGeneratorEnt, "OnPressed", OnGeneratorPressed);
				
				HookSingleEntityOutput(iGeneratorEnt, "OnUnPressed", OnGeneratorFinish);
				HookSingleEntityOutput(iGeneratorEnt, "OnTimeUp", OnGeneratorFinish);
			}
		}
	}
}

public Action OnGeneratorUse(int entity, int activator, int caller, UseType type, float value)
{
	if (!IsValidEnt(entity))
	{
		return Plugin_Continue;
	}
	
	if (IsSurvivor(activator))
	{
		if (!IsPlayerAlive(activator))
		{
			return Plugin_Continue;
		}
		
		if (bFinaleStarted)
		{
			PrintHintText(activator, "The Generators Will Automatically Start\nAs Time Passes By!");
			return Plugin_Handled;
		}
		
		if (IsTooOccupied(entity))
		{
			PrintHintText(activator, "It's Forbidden To Run All Generators At Once!\nOnly One Is Allowed!");
			return Plugin_Handled;
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public void OnGeneratorPressed(const char[] output, int caller, int activator, float delay)
{
	if (!IsSurvivor(activator) || !IsPlayerAlive(activator))
	{
		return;
	}
	
	if (!bInUse[caller])
	{
		bInUse[caller] = true;
	}
}

public void OnGeneratorFinish(const char[] output, int caller, int activator, float delay)
{
	if (!bInUse[caller])
	{
		return;
	}
	
	bInUse[caller] = false;
}

bool IsTooOccupied(int entity)
{
	bool bConfirm = false;
	
	for (int i = 1; i < 2049; i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i) || i == entity)
		{
			continue;
		}
		
		if (bInUse[i - 1])
		{
			bConfirm = true;
			break;
		}
	}
	
	return bConfirm;
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

stock bool IsTank(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}

stock void ExecuteSpawn2(int client, char[] sInfected, int iCount)
{
	if (iCount < 1)
	{
		return;
	}
	
	char sCommand[16];
	if (StrContains(sInfected, "mob", false) != -1)
	{
		strcopy(sCommand, sizeof(sCommand), "z_spawn");
	}
	else
	{
		strcopy(sCommand, sizeof(sCommand), "z_spawn_old");
	}
	
	int iFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iFlags & ~FCVAR_CHEAT);
	for (int i = 0; i < iCount; i++)
	{
		FakeClientCommand(client, "%s %s", sCommand, sInfected);
	}
	SetCommandFlags(sCommand, iFlags);
}

