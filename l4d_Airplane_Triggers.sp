#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <Airplane>

#define CHAT_TAG			"\x03[Airdrop] \x05"
#define CONFIG_SPAWNS		"data/l4d_airdrop.cfg"

#define MODEL_BOX			"models/props/cs_militia/silo_01.mdl"
#define MAX_ENTITIES		14

Handle g_hTimerBeam[MAX_ENTITIES];
int g_iHaloMaterial, g_iLaserMaterial, g_iMenuSelected[MAXPLAYERS+1], g_iTriggers[MAX_ENTITIES];
bool g_bLoaded, g_bShow[MAX_ENTITIES];
float g_fTargetAng[MAX_ENTITIES], g_vPosAirdrop[MAX_ENTITIES][3], g_vTargetZone[MAX_ENTITIES][3];
Menu g_hMenuMain, g_hMenuPos, g_hMenuSetAirdrop, g_hMenuVMaxs, g_hMenuVMins;


// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "空投物资触发器",
	author = "BHaType",
	description = "Creates AC130 bys which drop airdrop to where they were triggered from.",
	version = "0.1",
	url = "http://forums.alliedmods.net/showthread.php?t=187567"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d_Airplane");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("l4d_Airplane") == false )
	{
		SetFailState("Airplane.Triggers 'l4d_Airplane.smx' plugin not loaded.");
	}
}


public void OnPluginStart()
{
	RegAdminCmd("sm_airdrop_triggers", CmdAirdropMenu, ADMFLAG_ROOT, "Displays a menu with options to show/save a airdrop and triggers.");
	
	g_hMenuVMaxs = new Menu(VMaxsMenuHandler);
	g_hMenuVMaxs.AddItem("", "10 x 10 x 100");
	g_hMenuVMaxs.AddItem("", "25 x 25 x 100");
	g_hMenuVMaxs.AddItem("", "50 x 50 x 100");
	g_hMenuVMaxs.AddItem("", "100 x 100 x 100");
	g_hMenuVMaxs.AddItem("", "150 x 150 x 100");
	g_hMenuVMaxs.AddItem("", "200 x 200 x 100");
	g_hMenuVMaxs.AddItem("", "250 x 250 x 100");
	g_hMenuVMaxs.SetTitle("Airdrop: Trigger - VMaxs");
	g_hMenuVMaxs.ExitBackButton = true;

	g_hMenuVMins = new Menu(VMinsMenuHandler);
	g_hMenuVMins.AddItem("", "-10 x -10 x 0");
	g_hMenuVMins.AddItem("", "-25 x -25 x 0");
	g_hMenuVMins.AddItem("", "-50 x -50 x 0");
	g_hMenuVMins.AddItem("", "-100 x -100 x 0");
	g_hMenuVMins.AddItem("", "-150 x -150 x 0");
	g_hMenuVMins.AddItem("", "-200 x -200 x 0");
	g_hMenuVMins.AddItem("", "-250 x -250 x 0");
	g_hMenuVMins.SetTitle("Airdrop: Trigger - VMins");
	g_hMenuVMins.ExitBackButton = true;

	g_hMenuPos = new Menu(PosMenuHandler);
	g_hMenuPos.AddItem("", "X + 1.0");
	g_hMenuPos.AddItem("", "Y + 1.0");
	g_hMenuPos.AddItem("", "Z + 1.0");
	g_hMenuPos.AddItem("", "X - 1.0");
	g_hMenuPos.AddItem("", "Y - 1.0");
	g_hMenuPos.AddItem("", "Z - 1.0");
	g_hMenuPos.AddItem("", "SAVE");
	g_hMenuPos.SetTitle("Airdrop: Trigger - Origin");
	g_hMenuPos.ExitBackButton = true;
	
	g_hMenuSetAirdrop = new Menu(AirMenuHandler);
	g_hMenuSetAirdrop.AddItem("", "Position");
	g_hMenuSetAirdrop.AddItem("", "Crosshair");
	g_hMenuSetAirdrop.SetTitle("Airdrop: Trigger - Origin - Auto Save");
	g_hMenuSetAirdrop.ExitBackButton = true;
	HookEvent("round_start", Round, EventHookMode_PostNoCopy);
}

public Action Round(Event event, const char[] name, bool dontbroadcast)
{
	for( int i = 0; i < MAX_ENTITIES; i++ )
	{
		if(EntRefToEntIndex(g_iTriggers[i]) != INVALID_ENT_REFERENCE && g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0)
		{
			AcceptEntityInput(EntRefToEntIndex(g_iTriggers[i]), "Enable");
		}
	}
}

public int AirMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		float vAng[3];
		Handle hTrace;
		int cfgindex = g_iMenuSelected[client];
		if(index == 0)
		{
			float vPos[3];
			GetClientEyePosition(client, vPos);
			vAng[0] = -89.00; vAng[1] = 0.0; vAng[2] = 0.0;
			hTrace = TR_TraceRayFilterEx(vPos, vAng, CONTENTS_SOLID, RayType_Infinite, TraceDontHitSelf, client);

			if( TR_DidHit(hTrace) )
			{
				float vEndPos[3];
				TR_GetEndPosition(vEndPos, hTrace);
				SaveTrigger(client, cfgindex, "airdrop", vPos);
				TE_SendBeam(vPos, vEndPos, 6.0);
			}
			delete hTrace;
		}
		else
		{
			float vPos[3];
			GetClientEyePosition(client, vPos);
			GetClientEyeAngles(client, vAng);
			hTrace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, TraceFilter);
			if( TR_DidHit(hTrace) )
			{
				float vEndPos[3];
				TR_GetEndPosition(vEndPos, hTrace);
				delete hTrace;
				SaveTrigger(client, cfgindex, "airdrop", vEndPos);
				PrintToChat(client, "%s Air drop position for Trigger %i has been set.", CHAT_TAG, cfgindex);
				TE_SendBeam(vPos, vEndPos, 6.0);
			}
			delete hTrace;
		}

		g_hMenuSetAirdrop.Display(client, MENU_TIME_FOREVER);
	}
}

public bool TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients;
}

public bool TraceDontHitSelf(int entity, int mask, any data)
{
    if(entity == data || IsValidEntity(entity))
    {
        return false;
    }
    return true;
}

public int VMaxsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		float vVec[3];

		if( index == 0 )
			vVec = view_as<float>({ 10.0, 10.0, 100.0 });
		else if( index == 1 )
			vVec = view_as<float>({ 25.0, 25.0, 100.0 });
		else if( index == 2 )
			vVec = view_as<float>({ 50.0, 50.0, 100.0 });
		else if( index == 3 )
			vVec = view_as<float>({ 100.0, 100.0, 100.0 });
		else if( index == 4 )
			vVec = view_as<float>({ 150.0, 150.0, 100.0 });
		else if( index == 5 )
			vVec = view_as<float>({ 200.0, 200.0, 100.0 });
		else if( index == 6 )
			vVec = view_as<float>({ 300.0, 300.0, 100.0 });

		int cfgindex = g_iMenuSelected[client];
		int trigger = g_iTriggers[cfgindex];

		SaveTrigger(client, cfgindex, "vmax", vVec);

		if( IsValidEntRef(trigger) )
			SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vVec);

		g_hMenuVMaxs.Display(client, MENU_TIME_FOREVER);
	}
}

public int VMinsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		float vVec[3];

		if( index == 0 )
			vVec = view_as<float>({ -10.0, -10.0, -100.0 });
		else if( index == 1 )
			vVec = view_as<float>({ -25.0, -25.0, -100.0 });
		else if( index == 2 )
			vVec = view_as<float>({ -50.0, -50.0, -100.0 });
		else if( index == 3 )
			vVec = view_as<float>({ -100.0, -100.0, -100.0 });
		else if( index == 4 )
			vVec = view_as<float>({ -150.0, -150.0, -100.0 });
		else if( index == 5 )
			vVec = view_as<float>({ -200.0, -200.0, -100.0 });
		else if( index == 6 )
			vVec = view_as<float>({ -300.0, -300.0, -100.0 });

		int cfgindex = g_iMenuSelected[client];
		int trigger = g_iTriggers[cfgindex];

		SaveTrigger(client, cfgindex, "vmin", vVec);

		if( IsValidEntRef(trigger) )
			SetEntPropVector(trigger, Prop_Send, "m_vecMins", vVec);


		g_hMenuVMins.Display(client, MENU_TIME_FOREVER);
	}
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		int cfgindex = g_iMenuSelected[client];
		int trigger = g_iTriggers[cfgindex];

		float vPos[3];
		GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);

		if( index == 0 )
			vPos[0] += 1.0;
		else if( index == 1 )
			vPos[1] += 1.0;
		else if( index == 2 )
			vPos[2] += 1.0;
		else if( index == 3 )
			vPos[0] -= 1.0;
		else if( index == 4 )
			vPos[1] -= 1.0;
		else if( index == 5 )
			vPos[2] -= 1.0;

		if( index != 6 )
			TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);
		else
			SaveTrigger(client, cfgindex + 1, "vpos", vPos);
		

		g_hMenuPos.Display(client, MENU_TIME_FOREVER);
	}
}

public void OnPluginEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	g_bLoaded = false;

	for( int i = 0; i < MAX_ENTITIES; i++ )
	{
		g_vTargetZone[i] = view_as<float>({0.0, 0.0, 0.0});
		g_fTargetAng[i] = 0.0;

		if( IsValidEntRef(g_iTriggers[i]) )
			AcceptEntityInput(g_iTriggers[i], "Kill");
		g_iTriggers[i] = 0;
	}
}

public void OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheModel(MODEL_BOX, true);
	g_bLoaded = false;
	LoadAirdrops();
}

void LoadAirdrops()
{
	if(g_bLoaded)
		return;
	g_bLoaded = true;
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	KeyValues hFile = new KeyValues("airdrop");
	hFile.ImportFromFile(sPath);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		delete hFile;
		return;
	}

	char sTemp[16];
	float fAng, vPos[3], vMax[3], vMin[3], vAirPos[3];

	for( int i = 0; i <= MAX_ENTITIES; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp, false) )
		{
			fAng = hFile.GetFloat("ang");
			hFile.GetVector("vpos", vPos);
			hFile.GetVector("Airdrop", vAirPos);
			g_vTargetZone[i] = vPos;
			g_fTargetAng[i] = fAng;
			g_vPosAirdrop[i] = vAirPos;
			if( vPos[0] != 0.0 && vPos[1] != 0.0 && vPos[2] != 0.0 )
			{
				hFile.GetVector("vmin", vMin);
				hFile.GetVector("vmax", vMax);
				
				CreateTriggerMultiple(i, vPos, vMax, vMin);
			}

			hFile.GoBack();
		}
	}

	delete hFile;
}

public Action CmdAirdropMenu(int client, int args)
{
	ShowMenuMain(client);
	return Plugin_Handled;
}

void ShowMenuMain(int client)
{
	g_hMenuMain = new Menu(MainMenuHandler);
	g_hMenuMain.AddItem("1", "Create | Remove");
	g_hMenuMain.AddItem("2", "Set VMins");
	g_hMenuMain.AddItem("3", "Set VMaxs");
	g_hMenuMain.AddItem("4", "Set Pos");
	g_hMenuMain.AddItem("5", "Set Airdrop pos");
	g_hMenuMain.AddItem("6", "Set Trigger");
	g_hMenuMain.AddItem("7", "Show | Hide Trigger");
	g_hMenuMain.SetTitle("Airdrop - Main Menu");
	g_hMenuMain.Display(client, MENU_TIME_FOREVER);
}

void SetTriggerIndex(int client)
{
	Menu g_hMenuVectors = new Menu(SetTrigger);
	char sTemp[24], sInt[3];
	for( int i = 0; i < MAX_ENTITIES; i++ )
	{
		if( g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0 )
		{
			Format(sTemp, sizeof(sTemp), "Trigger %d", i+1);
			IntToString(i, sInt, sizeof sInt);
			g_hMenuVectors.AddItem(sInt, sTemp);
		}
	}
	g_hMenuVectors.Display(client, MENU_TIME_FOREVER);
}

void SetTriggerVectors(int client, int action)
{
	if(action == 1)
		g_hMenuVMins.Display(client, MENU_TIME_FOREVER);
	if(action == 2)
		g_hMenuVMaxs.Display(client, MENU_TIME_FOREVER);
	if(action == 3)
		g_hMenuPos.Display(client, MENU_TIME_FOREVER);
	if(action == 4)
		g_hMenuSetAirdrop.Display(client, MENU_TIME_FOREVER);
}

public int SetTrigger(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Select )
	{
		g_iMenuSelected[client] = index;
		PrintToChat(client, "%s Trigger %i has been selected", CHAT_TAG, index+1);
		ShowMenuMain(client);
	}
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			ShowMenuTriggersList(client);
		else if(index == 1)
		{
			if(g_iMenuSelected[client] < 0)
				SetTriggerIndex(client);
			else
				SetTriggerVectors(client, 1);
		}
		else if(index == 2)
		{
			if(g_iMenuSelected[client] < 0)
				SetTriggerIndex(client);
			else
				SetTriggerVectors(client, 2);
		}
		else if(index == 3)
		{
			if(g_iMenuSelected[client] < 0)
				SetTriggerIndex(client);
			else
				SetTriggerVectors(client, 3);
		}
		else if(index == 4)
		{
			if(g_iMenuSelected[client] < 0)
				SetTriggerIndex(client);
			else
				SetTriggerVectors(client, 4);
		}
		else if(index == 5)
			SetTriggerIndex(client);
		else if(index == 6)
			ShowMenuTriggersList(client, false);
	}
}

void ShowMenuTriggersList(int client, bool need = true)
{
	Menu hMenu = new Menu(TargetListMenuHandler);
	char sIndex[8], sTemp[32];
	
	for( int i = 0; i < MAX_ENTITIES; i++ )
	{
		if(g_vTargetZone[i][0] != 0.0 && g_vTargetZone[i][1] != 0.0 && g_vTargetZone[i][2] != 0.0)
		{
			if(need)
			{
				Format(sTemp, sizeof(sTemp), "Trigger %i", i + 1);
				IntToString(i, sIndex, sizeof sIndex + 1);
			}
			else
			{
				Format(sTemp, sizeof(sTemp), "Trigger %i", i + 1);
				IntToString(i + 25, sIndex, sizeof sIndex);
			}
			hMenu.AddItem(sIndex, sTemp);
		}
	}
	if(need)
	{
		for( int i = 0; i < MAX_ENTITIES; i++ )
		{
			if( g_vTargetZone[i][0] == 0.0 && g_vTargetZone[i][1] == 0.0 && g_vTargetZone[i][2] == 0.0 )
			{
				hMenu.AddItem("-1", "NEW");
				break;
			}
		}
	}
	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int TargetListMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		//int type = g_iMenuSelected[client];
		char sTemp[4];
		menu.GetItem(index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);
		if(index < 15 && index != -1)
			DeleteTrigger(client, index+1);
		else if(index > 14)
		{
			if(g_bShow[index - 25])
			{
				g_bShow[index - 25] = false;
				PrintToChat(client, "%s Hide %i trigger", CHAT_TAG, index - 25);
			}
			else
			{
				g_hTimerBeam[index - 25] = CreateTimer(0.1, TimerBeam, index - 25, TIMER_REPEAT);
				g_bShow[index - 25] = true;
				PrintToChat(client, "%s Show %i trigger", CHAT_TAG, index - 25);
			}
		}
		else
			CreateTrigger(index, client);
		ShowMenuMain(client);
	}
}

void CreateTrigger(int index = -1, int client)
{
	if( index == -1 )
	{
		for( int i = 0; i < MAX_ENTITIES; i++ )
		{
			if( g_vTargetZone[i][0] == 0.0 && g_vTargetZone[i][1] == 0.0 && g_vTargetZone[i][2] == 0.0 && IsValidEntRef(g_iTriggers[i]) == false )
			{
				index = i;
				break;
			}
		}
	}
	if( index == -1 )
	{
		PrintToChat(client, "%s Error: Cannot create a new group", CHAT_TAG);
		return;
	}

	float vPos[3];
	GetClientAbsOrigin(client, vPos);

	CreateTriggerMultiple(index, vPos, view_as<float>({ 25.0, 25.0, 100.0}), view_as<float>({ -25.0, -25.0, 0.0 }));

	SaveTrigger(client, index, "vpos", vPos);
	SaveTrigger(client, index, "vmax", view_as<float>({ 25.0, 25.0, 100.0}));
	SaveTrigger(client, index, "vmin", view_as<float>({ -25.0, -25.0, 0.0 }));
	SaveTrigger(client, index, "Airdrop", vPos);
	g_vTargetZone[index] = vPos;
}

void CreateTriggerMultiple(int index, float vPos[3], float vMaxs[3], float vMins[3])
{
	int trigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(trigger, "StartDisabled", "0");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "entireteam", "0");
	DispatchKeyValue(trigger, "allowincap", "0");
	DispatchKeyValue(trigger, "allowghost", "0");

	DispatchSpawn(trigger);
	SetEntityModel(trigger, MODEL_BOX);

	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
	TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);

	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	g_iTriggers[index] = EntIndexToEntRef(trigger);
}

void DeleteTrigger(int client, int cfgindex)
{
	KeyValues hFile = ConfigOpen();
	
	if( hFile != null )
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( hFile.JumpToKey(sMap) )
		{
			char sTemp[16];
			IntToString(cfgindex - 1, sTemp, sizeof(sTemp));
			if( hFile.JumpToKey(sTemp) )
			{
				if( IsValidEntRef(g_iTriggers[cfgindex-1]) )
					AcceptEntityInput(g_iTriggers[cfgindex-1], "Kill");
				g_iTriggers[cfgindex-1] = 0;

				hFile.DeleteKey("vpos");
				hFile.DeleteKey("vmax");
				hFile.DeleteKey("vmin");
				hFile.DeleteKey("Airdrop");
				
				float vPos[3];
				hFile.GetVector("vpos", vPos);

				hFile.GoBack();

				if( vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0 )
				{
					for( int i = cfgindex; i < MAX_ENTITIES; i++ )
					{
				//		if(!IsValidEntRef(g_iTriggers[cfgindex-1]) )
				//			i++;
						g_iTriggers[i-1] = g_iTriggers[i];
						g_iTriggers[i] = 0;

						g_fTargetAng[i-1] = g_fTargetAng[i];
						g_fTargetAng[i] = 0.0;

						g_vTargetZone[i-1] = g_vTargetZone[i];
						g_vTargetZone[i] = view_as<float>({ 0.0, 0.0, 0.0 });
				

						IntToString(i, sTemp, sizeof(sTemp));

						if( hFile.JumpToKey(sTemp) )
						{
							IntToString(i-1, sTemp, sizeof(sTemp));
							hFile.SetSectionName(sTemp);
							hFile.GoBack();
						}
					}
				}
				ConfigSave(hFile);

				PrintToChat(client, "%s Trigger [%i] - removed from config.", CHAT_TAG, cfgindex);
			}
		}

		delete hFile;
	}
}

void SaveTrigger(int client, int index, char[] sKey, float vVec[3])
{
	KeyValues hFile = ConfigOpen();

	if( hFile != null )
	{
		char sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));
		if( hFile.JumpToKey(sTemp, true) )
		{
			IntToString(index, sTemp, sizeof(sTemp));

			if( hFile.JumpToKey(sTemp, true) )
			{
				hFile.SetVector(sKey, vVec);

				ConfigSave(hFile);

				if( client )
					PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Saved trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
			}
			else if( client )
			{
				PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
			}
		}
		else if( client )
		{
			PrintToChat(client, "%s\x01(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, index, MAX_ENTITIES, sKey);
		}

		delete hFile;
	}
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 )
	{
		caller = EntIndexToEntRef(caller);

		for( int i = 0; i < MAX_ENTITIES; i++ )
		{
			if( caller == g_iTriggers[i] )
			{
				AcceptEntityInput(caller, "Disable");
				Airdrop(activator, g_vPosAirdrop[i]);
				break;
			}
		}
	}
}

public Action TimerBeam(Handle timer, any i)
{
	int entity = EntRefToEntIndex(g_iTriggers[i]);
	if(g_bShow[i] && entity != INVALID_ENT_REFERENCE)
	{
		float vMaxs[3], vMins[3], vPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
		AddVectors(vPos, vMaxs, vMaxs);
		AddVectors(vPos, vMins, vMins);
		TE_SendBox(vMins, vMaxs);
		return Plugin_Continue;
	}
	else
	{
		g_hTimerBeam[i] = null;
		return Plugin_Stop;
	}
}

void TE_SendBox(float vMins[3], float vMaxs[3])
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

void TE_SendBeam(const float vMins[3], const float vMaxs[3], float fTime = 0.2)
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, fTime, 1.0, 1.0, 1, 0.0, { 255, 155, 0, 255 }, 0);
	TE_SendToAll();
}

// ====================================================================================================
//					CONFIG - OPEN
// ====================================================================================================
KeyValues ConfigOpen()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	KeyValues hFile = new KeyValues("airdrop");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		return null;
	}

	return hFile;
}



// ====================================================================================================
//					CONFIG - SAVE
// ====================================================================================================
void ConfigSave(KeyValues hFile)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);

	if( !FileExists(sPath) )
		return;

	hFile.Rewind();
	hFile.ExportToFile(sPath);
}



// ====================================================================================================
//					OTHER
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}