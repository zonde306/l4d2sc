/**
 * Time: 2015/05/27
 * Version: 1.1
 * - Support all game mode.
 * - Remake some auto trigger. Now it's auto trigger is simpler than before.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3"

new bool:MapTrigger;
new bool:MapTriggerTwo;
new bool:MapTriggerThree;
new bool:MapTriggerFourth;
new bool:WarpTrigger;
new bool:WarpTriggerTwo;
new bool:WarpTriggerThree;
new bool:WarpTriggerFour;
new TriggeringBot;

new bool:GameRunning;

new bool:FinaleHasStarted;

public Plugin:myinfo =
{
	name = "机器人自动开机关",
	author = "Xanaguy",
	description = "An improved version of ijj's variant of the L4D2 Survivor AI Auto Trigger",
	version = PLUGIN_VERSION,
	url = "NONE"
};

public OnPluginStart()
{
	CreateConVar("l4d2_survivoraitriggerfix_version", PLUGIN_VERSION, " Version of L4D2 Survivor AI Auto Trigger on this server ", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	CreateTimer(3.0, CheckAroundTriggers, 0, TIMER_REPEAT);
	
	HookEvent("finale_start", FinaleBegins);
	HookEvent("round_end", GameEnds);
	HookEvent("map_transition", GameEnds);
	HookEvent("mission_lost", GameEnds);
	HookEvent("finale_win", GameEnds);
}

public OnMapStart()
{
	MapTrigger = false;
	MapTriggerTwo = false;
	MapTriggerThree = false;
	MapTriggerFourth = false;
	WarpTrigger = false;
	WarpTriggerTwo = false;
	WarpTriggerThree = false;
	WarpTriggerFour = false;
	FinaleHasStarted = false;
}

public OnMapEnd()
{
	MapTrigger = false;
	MapTriggerTwo = false;
	MapTriggerThree = false;
	MapTriggerFourth = false;
	WarpTrigger = false;
	WarpTriggerTwo = false;
	WarpTriggerThree = false;
	WarpTriggerFour = false;
}

public OnClientConnected(client)
{
	if (IsFakeClient(client)) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				GameRunning = true;
				return;
			}
		}
	}
	GameRunning = false;
}

public OnClientPutInServer(client)
{
	if (!IsFakeClient(client))
	{
		GameRunning = true;
	}
}

public OnClientDisconnect_Post(client)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				GameRunning = true;
				return;
			}
		}
	}
	GameRunning = false;
}

public Action:GameEnds(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(7.0, DelayedBoolReset, 0);
	FinaleHasStarted = false;
}

public Action:FinaleBegins(Handle:event, const String:name[], bool:dontBroadcast)
{
	FinaleHasStarted = true;
}

public Action:DelayedBoolReset(Handle:Timer)
{
	MapTrigger = false;
	MapTriggerTwo = false;
	MapTriggerThree = false;
	MapTriggerFourth = false;
	WarpTrigger = false;
	WarpTriggerTwo = false;
	WarpTriggerThree = false;
	WarpTriggerFour = false;
}

public Action:CheckAroundTriggers(Handle:timer)
{
	if (!GameRunning) return Plugin_Continue;
		
	if (!AllBotTeam()) return Plugin_Continue;
	

	decl String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	
	// Dead Center 1 is fine in Coop

	if (StrContains(mapname, "c1m2_streets", false) != -1)
	{
		// Dead Center 02
		// pos -6698.6 -962.6 448.4
		
		decl Float:pos1[3];
		pos1[0] = -6698.6;
		pos1[1] = -962.6;
		pos1[2] = 448.4;
		
		if (CheckforBots(pos1, 400.0) && !WarpTrigger)
		{
			//PrintToServer("[AutoTrigger] Bot found stuck near supermarket, initiating in 10 seconds.");
			//PrintToServer("[AutoTrigger] Crescendo will end 60 seconds after that.");
			PrintToServer("[AutoTrigger] The bots will deliver Whitaker's Cola...");

			// position cola: -7377.6 -1372.1 427.2
			new Handle:posonedata = CreateDataPack();
			WritePackFloat(posonedata, -7377.6);
			WritePackFloat(posonedata, -1372.1);
			WritePackFloat(posonedata, 427.2);
			CreateTimer(10.0, WarpAllBots, posonedata);
			CreateTimer(10.0, CallSuperMarket);
			
			// position give cola: -5375.4 -2016.0 678.0
			new Handle:postwodata = CreateDataPack();
			WritePackFloat(postwodata, -5375.4);
			WritePackFloat(postwodata, -2016.0);
			WritePackFloat(postwodata, 678.0);
			CreateTimer(65.0, WarpAllBots, postwodata);
			CreateTimer(70.0, CallTankerBoom);
			
			WarpTrigger = true;
		}
		
		new gunshop = FindEntityByName("gunshop_door_button", -1);
		
		decl Float:posx[3];
		
		if (gunshop > 0)
		{
			GetEntityAbsOrigin(gunshop, posx);
			if (CheckforBots(posx, 200.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Just in case the bots fail to call Whitaker the first time...");
				
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "gunshop_door_button", "Press");
				
				MapTrigger = true;
			}
		}
	}
	
	if (StrContains(mapname, "c1m3_mall", false) != -1)
	{
		// Dead Center 03 - emergency door or windows
		// name door_hallway_lower4a, class prop_door_rotating, Input "Open"
		// they do the rest veeery slowly, but by themselves
		
		new door = FindEntityByName("door_hallway_lower4a", -1);
		
		decl Float:pos1[3];
		
		if (door > 0)
		{
			GetEntityAbsOrigin(door, pos1);
			if (CheckforBots(pos1, 200.0) && !MapTrigger)
			{
				//PrintToServer("[AutoTrigger] Bot found close to the Emergency Door, open sesame...");
				//PrintToServer("[AutoTrigger] Warping them all ahead in 30 seconds.");
				PrintToServer("[AutoTrigger] They open the door...");

				AcceptEntityInput(door, "Open");

				new Handle:posxdata = CreateDataPack();
				WritePackFloat(posxdata, 1207.4);
				WritePackFloat(posxdata, -3180.1);
				WritePackFloat(posxdata, 598.0);
				CreateTimer(30.0, WarpAllBots, posxdata);
				MapTrigger = true;
			}
		}
		
		new glass = FindEntityByName("breakble_glass_minifinale", -1);
		
		decl Float:pos2[3];
		
		if (glass > 0)
		{
			GetEntityAbsOrigin(glass, pos2);
			if (CheckforBots(pos2, 500.0) && !MapTrigger)
			{
				//PrintToServer("[AutoTrigger] Bot found close to the Alarmed Windows, open sesame...");
				//PrintToServer("[AutoTrigger] Warping them all ahead in 30 seconds.");
				PrintToServer("[AutoTrigger] They shoot out the store window...");

				new Handle:posxdata = CreateDataPack();
				WritePackFloat(posxdata, 1207.4);
				WritePackFloat(posxdata, -3180.1);
				WritePackFloat(posxdata, 598.0);
				CreateTimer(30.0, WarpAllBots, posxdata);
				MapTrigger = true;
			}
		}
		
		new escalator = FindEntityByName("escalator_upper_03-lift", -1);
		
		decl Float:pos3[3];
		
		if (escalator > 0)
		{
			GetEntityAbsOrigin(escalator, pos3);
			if (CheckforBots(pos3, 500.0) && !WarpTrigger)
			{
				//PrintToServer("[AutoTrigger] Bot found close to the Alarmed Windows, open sesame...");
				//PrintToServer("[AutoTrigger] Warping them all ahead in 30 seconds.");
				PrintToServer("[AutoTrigger] They can't go up that escalator thanks to nav... Warping...");

				new Handle:posxdata = CreateDataPack();
				WritePackFloat(posxdata, -537.854309);
				WritePackFloat(posxdata, -4196.386230);
				WritePackFloat(posxdata, 536.031250);
				CreateTimer(7.0, WarpAllBots, posxdata);
				WarpTrigger = true;
			}
		}
	}
	
	// Dead Center 4 - use ScavengeBots plugin
	if (StrContains(mapname, "c1m4_atrium", false) != -1)
	{
		//new button = FindEntityByName("button_elev_3rdfloor", -1);
		
		decl Float:pos1[3];
		pos1[0] = -4037.9;
		pos1[1] = -3411.3;
		pos1[2] = 598.0;
		//GetEntityAbsOrigin(button, pos1);
			
		if (CheckforBots(pos1, 200.0) && !MapTrigger)
		{
			//PrintToServer("[AutoTrigger] TEST01.");
			CreateTimer(5.0, BotsUnstick);
			MapTrigger = true;
		}
		
		decl Float:pos2[3];
		pos2[0] = -4033.6;
		pos2[1] = -3415.1;
		pos2[2] = 66.0;
		
		if (CheckforBots(pos2, 200.0) && !MapTriggerTwo)
		{
			//PrintToServer("[AutoTrigger] TEST02.");
			CreateTimer(10.0, BotsStick);
			MapTriggerTwo = true;
		}
	}
	// Dark Carnival 1 is fine in Coop
	
	// Dark Carnival 2 is fine in Coop
	
	if (StrContains(mapname, "c2m3_coaster", false) != -1)
	{
		// Dark Carnival 03 - coaster buttons
		
		// Go: name minifinale_button, class func_button, Input "Press"
		// they do the rest veeery slowly, but by themselves
		
		new button = FindEntityByName("minifinale_button", -1);
		
		if (!IsValidEntity(button))
		{
			MapTrigger = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(button, pos1);
			
			if (CheckforBots(pos1, 250.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] They activate The Screaming Oak...");
				AcceptEntityInput(button, "Press");
				
				if (!IsVersus())
				{
					PrintToServer("[AutoTrigger] Campaign Survivor Bots suck at traversing the coaster. They will be warped in 3 minutes...");
					new Handle:postwodata = CreateDataPack();
					WritePackFloat(postwodata, -3572.179443);
					WritePackFloat(postwodata, 1450.377319);
					WritePackFloat(postwodata, 160.031250);
					CreateTimer(180.0, WarpAllBots, postwodata);
				}
				MapTrigger = true;

				//CreateTimer(250.0, C2M3WarpAllBotToThere, 0);
			}
		}
	
		// c2m3 - after shut off the rollercoaster, warp them to the special spot
		decl Float:posx[3];
		posx[0] = -4029.9;
		posx[1] = 1428.9;
		posx[2] = 222.0;
		// confusion spot -4029.9 1428.9 222.0, teleport them off
		// to: -4315.1 2311.4 313.2
		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The coaster alarm has been disabled!");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -4315.1);
			WritePackFloat(posdata, 2311.4);
			WritePackFloat(posdata, 313.2);
			CreateTimer(50.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}

	}
	
	// Dark Carnival 4 is fine in Coop
	
	if (StrContains(mapname, "c2m5_concert", false) != -1)
	{
		if (MapTrigger) return Plugin_Continue;
		// map is Dark Carnival 5

		decl Float:pos1[3];
		pos1[0] = -3406.7;
		pos1[1] = 3003.2;
		pos1[2] = -193.9;
		
		if (CheckforBots(pos1, 200.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Lights...");
			//AcceptEntityInput(lightsbutton, "Press");
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "stage_lights_button", "Use");
			MapTrigger = true;
		}
	}
	
	if (StrContains(mapname, "c3m1_plankcountry", false) != -1)
	{
		// Swamp Fever 01 - classic crescendo
		// they freakin KILL THEMSELVES by teleporting into the river, yay
		// name: ferry_button, func_button
		
		new button = FindEntityByName("ferry_button", -1);
		
		if (!IsValidEntity(button) && !MapTrigger)
		{
			SetConVarInt(FindConVar("sb_unstick"), 0);
			MapTrigger = true;

			PrintToServer("[AutoTrigger] The ferry was called...");
	
			CreateTimer(150.0, BotsUnstick);
		}
		/*
		decl Float:posx[3];
		posx[0] = -4340.6;
		posx[1] = 6068.1;
		posx[2] = 60.2;
		// confusion spot -4340.6 6068.1 60.2
		if (CheckforBots(posx, 100.0) && !MapTriggerTwo)
		{
			SetConVarInt(FindConVar("sb_unstick"), 1);
			MapTriggerTwo = true;
		}
		*/
	}
	
	// Swamp Fever 2 is fine in Coop

	if (StrContains(mapname, "c3m3_shantytown", false) != -1)
	{	
		decl Float:pos1[3];	
		
		pos1[0] = 198.193573;
		pos1[1] = -2813.822266;
		pos1[2] = -21.995037;
		
		if (CheckforBots(pos1, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The plank will be lowered...");
				
			new Handle:posonedata = CreateDataPack();
			WritePackFloat(posonedata, -358.478455);
			WritePackFloat(posonedata, -4138.272461);
			WritePackFloat(posonedata, 79.031250);
			CreateTimer(15.0, WarpAllBots, posonedata);
			CreateTimer(15.0, BridgeMiniFinale);
				
			new Handle:postwodata = CreateDataPack();
			WritePackFloat(postwodata, -40.596180);
			WritePackFloat(postwodata, -4241.562500);
			WritePackFloat(postwodata, 110.183243);
			CreateTimer(30.0, WarpAllBots, postwodata);
				
			WarpTrigger = true;
		}

	}
	if (StrContains(mapname, "c3m4_plantation", false) != -1)
	{
		// map is Swamp Fever 4
		
		// getpos 1667.1 -114.4 286.0
		decl Float:pos1[3];
		pos1[0] = 1667.1;
		pos1[1] = -114.4;
		pos1[2] = 286.0;

		//new button = FindEntityByName("escape_gate_button", -1);
		
		// finale balcony coordinates - getpos 1524.9 1937.5 188.1	
		if (CheckforBots(pos1, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Virgil has been contacted...");
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "escape_gate_button", "Press");
			//AcceptEntityInput(button, "Press");
			MapTrigger = true;

			CreateTimer(30.0, C3M4FinaleStart);
		}
	}
	
	//Hard Rain 1 - is fine in Coop
	
	if (StrContains(mapname, "c4m2_sugarmill_a", false) != -1)
	{
		// Hard Rain 02  -1413.3 -9390.2 671.1
		decl Float:pos1[3];
		pos1[0] = -1413.3;
		pos1[1] = -9390.2;
		pos1[2] = 671.1;
		// confusion spot -1413.3 -9390.2 671.1
		if (CheckforBots(pos1, 200.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Here comes the elevator...");
			SetConVarInt(FindConVar("sb_unstick"), 0);
			MapTrigger = true;
		}

		decl Float:pos2[3];
		pos2[0] = -1370.9;
		pos2[1] = -9549.0;
		pos2[2] = 190.2;
		// confusion spot -1370.9 -9549.0 190.2
		if (CheckforBots(pos2, 200.0) && !MapTriggerTwo)
		{
			SetConVarInt(FindConVar("sb_unstick"), 1);
			CreateTimer(1.0, C4M2BotsActions);
			CreateTimer(11.0, ResumeBotsActions);
			MapTriggerTwo = true;
		}
	}
	
	//Hard Rain 3 - is fine in Coop
	
	//Hard Rain 4 - is fine in Coop
	
	//Hard Rain 5 - is fine in Coop, astonishingly
	
	//The Parish 1 - is fine in Coop
	
	if (StrContains(mapname, "c5m2_park", false) != -1)
	{
		// c5m2_park - name finale_cleanse_entrance_door class prop_door_rotating "close"
		// huddle -9654.8 -5962.8 -166.8 -9645.740234 -5970.330566 -151.945755;
		// name finale_cleanse_exit_door, class prop_door_rotating "open" - a few secs later
		
		// -9614.2 -5981.5 -151.9;
		// ready into the trailer
		decl Float:pos1[3];
		pos1[0] = -9614.2;
		pos1[1] = -5981.5;
		pos1[2] = -151.9;
		
		if (CheckforBots(pos1, 100.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] They are ready to run for the tower...");
			/*
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, pos1[0]);
			WritePackFloat(posdata, pos1[1]);
			WritePackFloat(posdata, pos1[2]);
			CreateTimer(0.5, WarpAllBots, posdata);
			*/
			CreateTimer(10.0, RunBusStationEvent);
			MapTrigger = true;
		}
	}
	
	//The Parish 3 - is fine in Coop
	
	if (StrContains(mapname, "c5m4_quarter", false) != -1)
	{
		//c5m4_quarter - huddle after crescendo -1487.0 684.0 109.0
		// teleport to -2179.3,389.3,302.0;
		// -2019.551636 494.859070 302.031250;
		// 70sec
		
		new button = FindEntityByName("tractor_button", -1);
		
		//decl Float:pos1[3];
		//pos1[0] = -1487.0;
		//pos1[1] = 684.0;
		//pos1[2] = 109.0;
		
		if (!IsValidEntity(button) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The tractor has started!");
			//CreateTimer(100.0, C5M4BotsActions);
			MapTrigger = true;
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -1864.4);
			WritePackFloat(posdata, 474.3);
			WritePackFloat(posdata, 302.0);
			CreateTimer(100.0, WarpAllBots, posdata);
		}
		/*
		decl Float:pos1[3];
		pos1[0] = -2179.3;
		pos1[1] = 389.3;
		pos1[2] = 302.0;
		if (CheckforBots(pos1, 100.0) && !MapTriggerTwo)
		{
			PrintToServer("[AutoTrigger] 15秒后恢复。");
			CreateTimer(5.0, ResumeBotsActions);
			MapTriggerTwo = true;
		}
		*/
	}

	if (StrContains(mapname, "c5m5_bridge", false) != -1)
	{
		// c5m5_bridge   pos -11591.227539 6172.690430 518.031250;
		// name radio_fake_button, class func_button "Press"
		// a little later standard finale call
		
		new button = FindEntityByName("radio_fake_button", -1);
		
		if (!IsValidEntity(button) && !MapTrigger)
		{
			MapTrigger = true;
			CreateTimer(13.0, C5M5FinaleStart);
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(button, pos1);
			
			if (CheckforBots(pos1, 200.0) && !MapTrigger)
			{
				//PrintToServer("[AutoTrigger] C5M5FinaleTrigger.");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "radio_fake_button", "Use");
				//AcceptEntityInput(button, "Press");
				
				CreateTimer(13.0, C5M5FinaleStart);
				MapTrigger = true;
			}
		}
	}

	//The Passing 01 - is fine in Coop

	if (StrContains(mapname, "c6m2_bedlam", false) != -1)
	{
		// The Passing 02
		decl Float:posx[3];
		posx[0] = 439.9;
		posx[1] = 1689.4;
		posx[2] = -125.1;
		// confusion spot 439.9 1689.4 -125.1, teleport them off
		// to: 36.9 1888.7 -1.9;
		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The bots proceed...");

			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 36.9);
			WritePackFloat(posdata, 1888.7);
			WritePackFloat(posdata, -1.9);
			CreateTimer(10.0, WarpAllBots, posdata);

			WarpTrigger = true;
		}
	}

	//The Passing 03 - use ScavengeBots plugin

	if (StrContains(mapname, "c7m1_docks", false) != -1)
	{
		// The Sacrifice 01
		
		decl Float:pos3[3];
		pos3[0] = 7889.744141;
		pos3[1] = -68.818085;
		pos3[2] = 27.752344;		
		
		if (CheckforBots(pos3, 200.0) && !WarpTriggerTwo && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] A fail-safe has been activated.");

			new Handle:postwodata = CreateDataPack();
			WritePackFloat(postwodata, 7106.062012);
			WritePackFloat(postwodata, 675.531921);
			WritePackFloat(postwodata, 129.438416);
			CreateTimer(10.0, WarpAllBots, postwodata);
			CreateTimer(0.1, BotsStopMove);
			CreateTimer(3.0, BotsStartMove);
			WarpTrigger = true;
		}
		
		new button = FindEntityByName("tankdoorin_button", -1);
		
		if (!IsValidEntity(button))
		{
			MapTrigger = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(button, pos1);
			
			if (CheckforBots(pos1, 150.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Someone opens the door...");
				AcceptEntityInput(button, "Press");
				if (!IsVersus())
				CreateTimer(5.0, TankDoor01COOP, 0);
				else if (!IsCoop())
				CreateTimer(5.0, TankDoor01VERSUS, 0);

				MapTrigger = true;
			}
		}

		if (!IsValidEntity(FindEntityByName("tankdoorout_button", -1)))
		{
			MapTriggerTwo = true;
		}
		else
		{
			decl Float:pos2[3];
			GetEntityAbsOrigin(FindEntityByName("tankdoorout_button", -1), pos2);
			
			if (CheckforBots(pos2, 100.0) && !MapTriggerTwo)
			{
				PrintToServer("[AutoTrigger] The bots move on...");
				AcceptEntityInput(FindEntityByName("tankdoorout_button", -1), "Press");
				CreateTimer(5.0, TankDoor02, 0);
				MapTriggerTwo = true;
			}
		}
	
		decl Float:posx[3];
		posx[0] = 4729.166016;
		posx[1] = 1270.755005;
		posx[2] = 200.843201;
		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The bots must go around these barrels...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 5030.492676);
			WritePackFloat(posdata, 1304.330444);
			WritePackFloat(posdata, 144.031250);
			CreateTimer(7.5, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}

	if (StrContains(mapname, "c7m2_barge", false) != -1)
	{
		// The Sacrifice 02
		decl Float:posx[3];
		posx[0] = -4355.0;
		posx[1] = -62.0;
		posx[2] = 62.0;
		// confusion spot -4355.0 -62.0 62.0, teleport them off
		// to: -5408.7 858.6 696.4
		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] Thanks to the Scavenge exclusive ladder on the ship, the bots will instead be warped to the top of the pile of crap. This will result in the panic event.\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -5408.7);
			WritePackFloat(posdata, 858.6);
			WritePackFloat(posdata, 696.4);
			CreateTimer(10.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}
	
	if (StrContains(mapname, "c7m3_port", false) != -1)
	{
		// The Sacrifice 03

		if (!IsValidEntity(FindEntityByName("finale_start_button", -1)) && !MapTrigger)
		{
			MapTrigger = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(FindEntityByName("finale_start_button", -1), pos1);
			
			if (CheckforBots(pos1, 300.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Bot found close to the first generator button, pressing...");
				AcceptEntityInput(FindEntityByName("finale_start_button", -1), "Press");
				CreateTimer(5.0, C7M3GeneratorStart);
				MapTrigger = true;

				CreateTimer(20.0, C7M3WarpBotsToGenerator1);
			}
		}

		if (!IsValidEntity(FindEntityByName("finale_start_button1", -1)) && MapTrigger && !MapTriggerTwo)
		{
			MapTriggerTwo = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(FindEntityByName("finale_start_button1", -1), pos1);
			
			if (CheckforBots(pos1, 300.0) && !MapTriggerTwo)
			{
				PrintToServer("[AutoTrigger] Bot found close to the second generator button, pressing...");
				AcceptEntityInput(FindEntityByName("finale_start_button1", -1), "Press");
				CreateTimer(5.0, C7M3GeneratorStart1);
				MapTriggerTwo = true;

				CreateTimer(20.0, C7M3WarpBotsToGenerator2);
			}
		}
		
		if (!IsValidEntity(FindEntityByName("finale_start_button2", -1)) && MapTrigger && MapTriggerTwo && !MapTriggerThree)
		{
			MapTriggerThree = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(FindEntityByName("finale_start_button2", -1), pos1);
			
			if (CheckforBots(pos1, 300.0) && !MapTriggerThree)
			{
				PrintToServer("[AutoTrigger] Bot found close to the third generator button, pressing...");
				AcceptEntityInput(FindEntityByName("finale_start_button2", -1), "Press");
				CreateTimer(5.0, C7M3GeneratorStart2);
				MapTriggerThree = true;
			}
		}

		decl Float:pos1[3];
		pos1[0] = -0.8;
		pos1[1] = -1360.1;
		pos1[2] = 56.5;

		if (CheckforBots(pos1, 100.0) && !MapTriggerFourth)
		{
			PrintToServer("[AutoTrigger] Bot found at a stuck spot, warping them all ahead in 10 seconds");
		
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -123.2);
			WritePackFloat(posdata, -1747.9);
			WritePackFloat(posdata, 314.0);
			CreateTimer(10.0, WarpAllBots, posdata);
			CreateTimer(12.0, C7M3BridgeStartButton, 0);

			MapTriggerFourth = true;

			CreateTimer(30.0, C7M3GeneratorFinaleButtonStart, 0);
		}
	}
	
	if (StrContains(mapname, "c9m2_lots", false) != -1)
	{
		// Crash Course 02
		
		// Go: name finaleswitch_initial, class func_button_timed, Input "Press"
		// they do the rest veeery slowly, but by themselves
		
		new button = FindEntityByName("finaleswitch_initial", -1);
		
		if (!IsValidEntity(button))
		{
			MapTrigger = true;
		}
		else
		{
			decl Float:pos1[3];
			GetEntityAbsOrigin(button, pos1);
			
			if (CheckforBots(pos1, 500.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Starting the generator...");
				AcceptEntityInput(button, "Press");
				CreateTimer(5.0, GeneratorStart, 0);
				MapTrigger = true;

				// Crash Cause 02 - Generator Second Start
				CreateTimer(205.0, GeneratorStartTwoReady, 0);
				CreateTimer(210.0, GeneratorStartTwo, 0);
			}
		}
	}
	
	if (StrContains(mapname, "c10m3_ranchhouse", false) != -1)
	{
		// The Sacrifice 02
		decl Float:posx[3];
		posx[0] = -7451.890137;
		posx[1] = -2112.419922;
		posx[2] = -16.402706;

		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] Just in case the bots are trying to get in through the window...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -7326.758301);
			WritePackFloat(posdata, -2100.379150);
			WritePackFloat(posdata, 8.031250);
			CreateTimer(5.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}

	if (StrContains(mapname, "c10m4_mainstreet", false) != -1)
	{
		// map is Death Toll 4

		new button = FindEntityByName("button", -1);

		decl Float:pos1[3];
		GetEntityAbsOrigin(button, pos1);

		if (CheckforBots(pos1, 200.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The forklift lowers...");
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "button", "Use");
			MapTrigger = true;
		}
	}

	if (StrContains(mapname, "c10m5_houseboat", false) != -1)
	{
		// map is Death Toll 5
		// 3884.3 -4144.5 -89.9
		//new button = FindEntityByName("radio_button", -1);

		decl Float:pos1[3];
		pos1[0] = 3884.3;
		pos1[1] = -4144.5;
		pos1[2] = -89.9;
		//GetEntityAbsOrigin(button, pos1);

		if (CheckforBots(pos1, 400.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] John Slater has been contacted...");
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "radio_button", "Use");
			//UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "orator_boat_radio", "Kill");

			MapTrigger = true;

			CreateTimer(20.0, C10M5FinaleStart, 0);
		}
	}

	if (StrContains(mapname, "c11m3_garage", false) != -1)
	{
		// map is Dead Air 3.

		new gascans = FindEntityByName("barricade_gas_can", -1);
		
		if (gascans == -1) // has it been destroyed already? continue without doing anything.
		{
			MapTrigger = true;
			return Plugin_Continue;
		}
			
		decl Float:pos1[3];
		GetEntityAbsOrigin(gascans, pos1);
	
		if (CheckforBots(pos1, 900.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The barricade is burning...");
			AcceptEntityInput(gascans, "Ignite");
			MapTrigger = true;
		}
	}

	if (StrContains(mapname, "c11m5_runway", false) != -1)
	{
		// map is Dead Air 5
		// pos -5033.4 9164.0 -129.9
		
		new button = FindEntityByName("radio_fake_button", -1);

		if (!IsValidEntity(button) && !MapTrigger)
		{
			//PrintToServer("[AutoTrigger] Preparing to fuel the plane...");
			CreateTimer(20.0, C11M5FinaleStart, 0);
			MapTrigger = true;
		}
	}

	if (StrContains(mapname, "c12m2_traintunnel", false) != -1)
	{
		// map is BH2
		//decl Float:posdoor[3], Float:postriggerer[3], Float:anglestriggerer[3];
		decl Float:posdoor[3];
		
		posdoor[0] = -8605.0;
		posdoor[1] = -7530.0;
		posdoor[2] = -21.0;
		/*
		postriggerer[0] = -8600.0;
		postriggerer[1] = -7504.0;
		postriggerer[2] = -60.0;
		
		anglestriggerer[0] = 8.0;
		anglestriggerer[1] = -90.0;
		anglestriggerer[2] = 0.0;
		*/
		if (CheckforBots(posdoor, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Opening the door...");
			MapTrigger = true;
			
			//TeleportEntity(TriggeringBot, postriggerer, anglestriggerer, NULL_VECTOR); // move bot infront of the door, facing it
			
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "emergency_door", "open");
		}
	}
	
	if (StrContains(mapname, "c12m3_bridge", false) != -1)
	{
		decl Float:posx[3];
		posx[0] = 5949.163086;
		posx[1] = -13298.776367;
		posx[2] = -72.499367;

		if (CheckforBots(posx, 200.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] Bots are going to derail the train car...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 8254.743164);
			WritePackFloat(posdata, -13578.223633);
			WritePackFloat(posdata, 0.031250);
			CreateTimer(20.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}
	
	if (StrContains(mapname, "c13m1_alpinecreek", false) != -1)
	{
		// Cold Stream 01
		
		decl Float:posx[3];
		posx[0] = 1068.9;
		posx[1] = 251.4;
		posx[2] = 766.0;

		if (CheckforBots(posx, 100.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The bunker opens...");
			AcceptEntityInput(FindEntityByName("bunker_button", -1), "Press");
			MapTrigger = true;
		}
	}
	
	if (StrContains(mapname, "c13m2_southpinestream", false) != -1)
	{
		// Cold Stream 02
		
		decl Float:posx[3];
		posx[0] = 119.1;
		posx[1] = 5574.1;
		posx[2] = 334.0;

		if (CheckforBots(posx, 600.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The bots have shot the barrels...");
			
			CreateTimer(1.0, BotsStopMove);
			CreateTimer(7.0, C13M2Trigger);
			CreateTimer(11.0, BotsStartMove);
			MapTrigger = true;
		}
		
		decl Float:pos1[3];
		pos1[0] = 7894.451660;
		pos1[1] = 3310.191895;
		pos1[2] = 531.832458;
		
		if (CheckforBots(pos1, 500.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] To make sure the bots don't shortcut past the first road part, they will be teleported past the ladder in 30 seconds...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 6080.580078);
			WritePackFloat(posdata, 2591.295654);
			WritePackFloat(posdata, 767.495178);
			CreateTimer(30.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
		
		decl Float:pos2[3];
		pos2[0] = -339.385284;
		pos2[1] = 8027.178711;
		pos2[2] = 46.031250;
		
		if (CheckforBots(pos2, 500.0) && !MapTriggerTwo)		
		{
			if (!IsVersus())
			{
				PrintToServer("[AutoTrigger] Poor bots will get swept up in the current...\x01");
			
				new Handle:postwodata = CreateDataPack();
				WritePackFloat(postwodata, 127.612053);
				WritePackFloat(postwodata, 8530.405273);
				WritePackFloat(postwodata, 82.031250);
				CreateTimer(10.0, WarpAllBots, postwodata);
				MapTriggerTwo = true;
			}
		}
		
	}

	if (StrContains(mapname, "c13m4_cutthroatcreek", false) != -1)
	{
		// Cold Stream 04
		// getpos -4127.968750 -7866.249023 433.031250;
		decl Float:posx[3];
		posx[0] = -4127.9;
		posx[1] = -7866.2;
		posx[2] = 433.0;

		if (CheckforBots(posx, 100.0))
		{
			new button = FindEntityByClassname(-1, "startbldg_door_button");
			
			if (!IsValidEntity(button) && !MapTrigger)
			{
				MapTrigger = true;
				CreateTimer(1.0, BotsStick, 0);
				CreateTimer(20.0, FinaleStart, 0);
				CreateTimer(23.0, BotsUnstick, 0);
			}
		}
	}

	if (StrEqual(mapname, "wth_1", true))
	{
		new gauntletdoor = FindEntityByName("finale_cleanse_exit_door", -1);
		
		decl Float:posx[3];
		
		if (gauntletdoor > 0)
		{
			GetEntityAbsOrigin(gauntletdoor, posx);
			if (CheckforBots(posx, 100.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Initiating gauntlet...");
				
				CreateTimer(5.0, RunBusStationEvent);
				
				MapTrigger = true;
			}
		}
	}
	
	if (StrEqual(mapname, "WTH_4", true))
	{
		new wthfourdoor = FindEntityByName("emergency_door", -1);
		
		decl Float:posx[3];
		
		if (wthfourdoor > 0)
		{
			GetEntityAbsOrigin(wthfourdoor, posx);
			if (CheckforBots(posx, 150.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] The alarm goes off...");
				
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "emergency_door", "Open");
				if (IsVersus())
				{
					new Handle:posthreedata = CreateDataPack();
					WritePackFloat(posthreedata, 7816.887695);
					WritePackFloat(posthreedata, 3431.855957);
					WritePackFloat(posthreedata, -1.536017);
					CreateTimer(45.0, WarpAllBots, posthreedata);
				}
				MapTrigger = true;
			}
		}
		
		new brushone = FindEntityByName("passing1", -1);
		
		decl Float:pos1[3];
		
		if (brushone > 0)
		{
			GetEntityAbsOrigin(brushone, pos1);
			if (CheckforBots(pos1, 150.0) && !WarpTrigger)
			{
				PrintToServer("[AutoTrigger] A board bars the way...\x01");
			
				new Handle:posonedata = CreateDataPack();
				WritePackFloat(posonedata, 7816.887695);
				WritePackFloat(posonedata, 3431.855957);
				WritePackFloat(posonedata, -1.536017);
				CreateTimer(15.0, WarpAllBots, posonedata);
				WarpTrigger = true;
			}
		}
		
		new brushtwo = FindEntityByName("passing2", -1);
		
		decl Float:pos2[3];
		
		if (brushtwo > 0)
		{
			GetEntityAbsOrigin(brushtwo, pos2);
			if (CheckforBots(pos2, 150.0) && !WarpTrigger)
			{
				PrintToServer("[AutoTrigger] A board bars the way...\x01");
			
				new Handle:postwodata = CreateDataPack();
				WritePackFloat(postwodata, 7816.887695);
				WritePackFloat(postwodata, 3431.855957);
				WritePackFloat(postwodata, -1.536017);
				CreateTimer(20.0, WarpAllBots, postwodata);
				WarpTrigger = true;
			}
		}
		
		decl Float:pos3[3];
		pos3[0] = 6800.031250;
		pos3[1] = -2137.921387;
		pos3[2] = -134.081757;

		if (CheckforBots(pos3, 200.0) && !WarpTriggerTwo && IsVersus())
		{
			PrintToServer("[AutoTrigger] The team moves through the alley...x01");
			
			new Handle:posfourdata = CreateDataPack();
			WritePackFloat(posfourdata, 6870.991699);
			WritePackFloat(posfourdata, 194.725510);
			WritePackFloat(posfourdata, -64.766510);
			CreateTimer(20.0, WarpAllBots, posfourdata);
			WarpTriggerTwo = true;
		}
	}
	
	if (StrEqual(mapname, "WTH_5", true))
	{
		new truck = FindEntityByName("prop_coop", -1);
		
		decl Float:posx[3];
		
		if (truck > 0)
		{
			GetEntityAbsOrigin(truck, posx);
			if (CheckforBots(posx, 1000.0) && !WarpTrigger)
			{
				PrintToServer("[AutoTrigger] A vehicle bars the way...\x01");
			
				new Handle:posonedata = CreateDataPack();
				WritePackFloat(posonedata, -2985.330811);
				WritePackFloat(posonedata, 1508.161499);
				WritePackFloat(posonedata, -254.925522);
				CreateTimer(10.0, WarpAllBots, posonedata);
				WarpTrigger = true;
			}
		}
		
		decl Float:pos1[3];
		pos1[0] = 6800.031250;
		pos1[1] = -2137.921387;
		pos1[2] = -134.081757;

		if (CheckforBots(pos1, 200.0) && !WarpTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The team approaches the radio...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 6870.991699);
			WritePackFloat(posdata, 194.725510);
			WritePackFloat(posdata, -64.766510);
			CreateTimer(20.0, WarpAllBots, posdata);
			WarpTriggerTwo = true;
		}
	}
	
	if (StrEqual(mapname, "uf1_boulevard", true))
	{
		new barrier = FindEntityByName("gateRestaurantRear", -1);
		
		decl Float:posx[3];
		
		if (barrier > 0)
		{
			GetEntityAbsOrigin(barrier, posx);
			if (CheckforBots(posx, 400.0) && !WarpTrigger)
			{
				PrintToServer("[AutoTrigger] The team moves out...\x01");
			
				new Handle:posdata = CreateDataPack();
				WritePackFloat(posdata, -209.543518);
				WritePackFloat(posdata, -2331.296875);
				WritePackFloat(posdata, 0.031250);
				CreateTimer(15.0, WarpAllBots, posdata);
				WarpTrigger = true;
			}
		}
		
		decl Float:pos1[3];
		pos1[0] = -1722.503174;
		pos1[1] = 4220.973633;
		pos1[2] = -5.968750;

		if (CheckforBots(pos1, 200.0) && !WarpTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The team enters the bar...\x01");
			
			new Handle:posonedata = CreateDataPack();
			WritePackFloat(posonedata, -5.968750);
			WritePackFloat(posonedata, 4097.378418);
			WritePackFloat(posonedata, 8.031250);
			CreateTimer(15.0, WarpAllBots, posonedata);
			WarpTriggerTwo = true;
		}
		
		decl Float:pos2[3];
		pos2[0] = 834.767578;
		pos2[1] = 5349.852539;
		pos2[2] = 0.031250;

		if (CheckforBots(pos2, 1000.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The team moves on...\x01");
			
			new Handle:postwodata = CreateDataPack();
			WritePackFloat(postwodata, -1751.634888);
			WritePackFloat(postwodata, 4555.818848);
			WritePackFloat(postwodata, 0.178804);
			CreateTimer(20.0, WarpAllBots, postwodata);
			MapTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "uf2_rooftops", true))
	{
		decl Float:posx[3];
		posx[0] = -2257.292969;
		posx[1] = -1573.922485;
		posx[2] = 0.031250;
		
		if (CheckforBots(posx, 50.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The team ascends to the roof...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -1363.125000);
			WritePackFloat(posdata, -53.750000);
			WritePackFloat(posdata, 395.500000);
			CreateTimer(30.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
		
		decl Float:pos1[3];
		pos1[0] = -2059.250000;
		pos1[1] = 2464.000000;
		pos1[2] = 456.000000;
		
		if (CheckforBots(pos1, 200.0) && !WarpTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The team ascends to the roof...\x01");
			
			new Handle:posonedata = CreateDataPack();
			WritePackFloat(posonedata, -977.075439);
			WritePackFloat(posonedata, 3398.486816);
			WritePackFloat(posonedata, 815.158508);
			CreateTimer(20.0, WarpAllBots, posonedata);
			WarpTriggerTwo = true;
		}
	
		new bomb = FindEntityByName("crescendo_button", -1);
		
		decl Float:pos2[3];
		
		if (bomb > 0)
		{
			GetEntityAbsOrigin(bomb, pos2);
			if (CheckforBots(pos2, 500.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] The fuse is lit...\x01");
				CreateTimer(9.0, UrbanFlightJoke);
				CreateTimer(10.0, TowerGoesBoom);
				CreateTimer(12.0, NeverMind);
				MapTrigger = true;
			}
		}
	}
	
	if (StrEqual(mapname, "uf3_harbor", true))
	{	
		new shelves = FindEntityByName("harbor_basement_shelves", -1);
		
		decl Float:posx[3];
		
		if (shelves > 0)
		{
			GetEntityAbsOrigin(shelves, posx);
			if (CheckforBots(posx, 400.0) && !WarpTrigger)
			{
				PrintToServer("[AutoTrigger] I'll just pretend those shelves do not exist...\x01");
			
				new Handle:posdata = CreateDataPack();
				WritePackFloat(posdata, 1004.188477);
				WritePackFloat(posdata, -9064.051758);
				WritePackFloat(posdata, -188.726166);
				CreateTimer(5.0, WarpAllBots, posdata);
				WarpTrigger = true;
			}
		}
		
		new fence = FindEntityByName("gateFenceB", -1);
		
		decl Float:pos1[3];
		
		if (fence > 0)
		{
			GetEntityAbsOrigin(fence, pos1);
			if (CheckforBots(pos1, 350.0) && !WarpTriggerTwo)
			{
				PrintToServer("[AutoTrigger] I'll just pretend this fence doesn't exist either...\x01");
			
				new Handle:posonedata = CreateDataPack();
				WritePackFloat(posonedata, 2691.872559);
				WritePackFloat(posonedata, -5233.146484);
				WritePackFloat(posonedata, -335.968750);
				CreateTimer(30.0, WarpAllBots, posonedata);
				WarpTriggerTwo = true;
			}
		}
		
		decl Float:pos2[3];
		
		pos2[0] = -15.383742;
		pos2[1] = -4634.599121;
		pos2[2] = 54.753826;
		
		if (CheckforBots(pos2, 400.0) && !WarpTriggerThree)
		{
			PrintToServer("[AutoTrigger] A walk in the park...\x01");
			
			new Handle:postwodata = CreateDataPack();
			WritePackFloat(postwodata, -514.125793);
			WritePackFloat(postwodata, -7851.909180);
			WritePackFloat(postwodata, 65.430542);
			CreateTimer(60.0, WarpAllBots, postwodata);
			WarpTriggerThree = true;
		}
		
		decl Float:pos3[3];
		
		pos3[0] = -1131.593750;
		pos3[1] = -7105.576172;
		pos3[2] = 57.446472;
		
		if (CheckforBots(pos3, 400.0) && !WarpTriggerFour)
		{
			PrintToServer("[AutoTrigger] The team moves through the alley...\x01");
			
			new Handle:posthreedata = CreateDataPack();
			WritePackFloat(posthreedata, -2723.947266);
			WritePackFloat(posthreedata, -7346.039063);
			WritePackFloat(posthreedata, 51.546051);
			CreateTimer(10.0, WarpAllBots, posthreedata);
			WarpTriggerFour = true;
		}
	}
	
	if (StrEqual(mapname, "uf4_airfield", true))
	{
		new finaledoor = FindEntityByName("gas_storage_door", -1);
		
		decl Float:posx[3];
		
		if (finaledoor > 0)
		{
			GetEntityAbsOrigin(finaledoor, posx);
			if (CheckforBots(posx, 200.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] The door opens...\x01");
				AcceptEntityInput(FindEntityByName("gas_storage_door", -1), "Open");
				MapTrigger = true;
			}
		}
		
		decl Float:pos1[3];
		
		pos1[0] = -234.250000;
		pos1[1] = 561.125000;
		pos1[2] = 26.250000;
		
		if (CheckforBots(pos1, 100.0) && MapTrigger && !WarpTrigger && !WarpTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The fail safe has been activated. Bots will warp to key points to activate objectives in complete order.\x01");
			CreateTimer(60.0, UF4FailSafeOne);
			CreateTimer(75.0, UF4FailSafeTwo);
			CreateTimer(135.0, UF4FailSafeThree);
			CreateTimer(165.0, UF4FailSafeFour);
			WarpTriggerTwo = true;
		}
		
		decl Float:pos2[3];
		
		pos2[0] = -687.250000;
		pos2[1] = 1059.625000;
		pos2[2] = 0.000000;
		
		if (CheckforBots(pos2, 100.0) && MapTrigger && !WarpTrigger && !WarpTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The fail safe has been activated. Bots will warp to key points to activate objectives in complete order.\x01");
			CreateTimer(60.0, UF4FailSafeOne);
			CreateTimer(75.0, UF4FailSafeTwo);
			CreateTimer(135.0, UF4FailSafeThree);
			CreateTimer(165.0, UF4FailSafeFour);
			WarpTriggerTwo = true;
		}
		
		decl Float:pos3[3];
		
		pos3[0] = -1944.317749;
		pos3[1] = 3049.523682;
		pos3[2] = 260.031250;
		
		if (CheckforBots(pos3, 500.0) && WarpTriggerThree)
		{
			PrintToServer("[AutoTrigger] The game/round will end in 30 seconds.\x01");
			CreateTimer(30.0, UFFinish);
			WarpTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_ff01_woods", true))
	{
		decl Float:posx[3];
		
		posx[0] = -4813.489258;
		posx[1] = 2435.072266;
		posx[2] = -23.968750;
		
		if (CheckforBots(posx, 300.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The team goes through the warehouse...\x01");
			
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -3140.874756);
			WritePackFloat(posdata, 2651.445801);
			WritePackFloat(posdata, -23.968744);
			CreateTimer(10.0, WarpAllBots, posdata);
			
			WarpTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_ff02_factory", true))
	{
		new ffm2button = FindEntityByName("m2_panic_button", -1);
		
		decl Float:posx[3];
		
		if (ffm2button > 0)
		{
			GetEntityAbsOrigin(ffm2button, posx);
			if (CheckforBots(posx, 250.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Someone pushed the button...\x01");
				AcceptEntityInput(FindEntityByName("m2_panic_button", -1), "Press");
				MapTrigger = true;
			}
		}
	}
	
	if (StrEqual(mapname, "l4d2_ff03_highway", true))
	{
		decl Float:posx[3];
		
		posx[0] = 8680.014648;
		posx[1] = 1706.183350;
		posx[2] = -271.365356;
		
		if (CheckforBots(posx, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The elevator starts...\x01");
			AcceptEntityInput(FindEntityByName("m3_panic_button", -1), "Press");
			MapTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_ff04_plant", true))
	{
		new caboosedoor = FindEntityByName("m4_panicdoor3", -1);
		
		decl Float:posx[3];
		
		if (caboosedoor > 0)
		{
			GetEntityAbsOrigin(caboosedoor, posx);
			if (CheckforBots(posx, 175.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] They gather in the caboose.\x01");
				CreateTimer(0.1, BotsStick);
				
				new Handle:posdata = CreateDataPack();
				WritePackFloat(posdata, -7009.856934);
				WritePackFloat(posdata, 2644.745361);
				WritePackFloat(posdata, -1569.218994);
				CreateTimer(0.2, WarpAllBots, posdata);
				
				CreateTimer(30.0, BotsUnstick);
				AcceptEntityInput(FindEntityByName("m4_panicdoor2", -1), "Close");
				MapTrigger = true;
			}
		}
	}
	
	if (StrEqual(mapname, "l4d2_ff05_station", true))
	{
		new fffinaleprep = FindEntityByName("coop_finale_button1", -1);
		
		decl Float:posx[3];
		
		if (fffinaleprep > 0)
		{
			GetEntityAbsOrigin(fffinaleprep, posx);
			if (CheckforBots(posx, 175.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] The train conductor has been contacted...\x01");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "coop_finale_button1", "Use");
				MapTrigger = true;
			}
		}
	}
	
	if (StrEqual(mapname, "p84m3_tunnel", true))
	{
		new p83switch = FindEntityByName("garagepower_btn", -1);
		
		decl Float:posx[3];
		
		if (p83switch > 0)
		{
			GetEntityAbsOrigin(p83switch, posx);
			if (CheckforBots(posx, 500.0) && !MapTrigger)
			{
				AcceptEntityInput(FindEntityByName("garagepower_btn", -1), "Press");
				MapTrigger = true;
			}
		}
	}

	if (StrEqual(mapname, "p84m4_station", true))
	{
		decl Float:posx[3];
		
		posx[0] = -1619.330933;
		posx[1] = 398.351776;
		posx[2] = 294.317841;
		
		if (CheckforBots(posx, 100.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The cop needs their help.\x01");
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -2881.040771);
			WritePackFloat(posdata, 165.394073);
			WritePackFloat(posdata, 188.076096);
			CreateTimer(10.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_daybreak02_coastline", true))
	{
		new gascans = FindEntityByName("barricade_gas_can", -1);
		
		if (gascans == -1) // has it been destroyed already? continue without doing anything.
		{
			MapTrigger = true;
			return Plugin_Continue;
		}
			
		decl Float:pos1[3];
		GetEntityAbsOrigin(gascans, pos1);
	
		if (CheckforBots(pos1, 900.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The barricade is burning...");
			AcceptEntityInput(gascans, "Ignite");
			MapTrigger = true;
		}
		
		new daybreakdoor = FindEntityByName("emergency_door", -1);
		
		decl Float:posx[3];
		
		if (daybreakdoor > 0)
		{
			GetEntityAbsOrigin(daybreakdoor, posx);
			if (CheckforBots(posx, 150.0) && !MapTriggerTwo)
			{
				PrintToServer("[AutoTrigger] The alarm goes off...");
				
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "emergency_door", "Open");

				MapTriggerTwo = true;
			}
		}
	}
	
	if (StrEqual(mapname, "l4d2_wanli01", true))
	{
		new planecheckpoint = FindEntityByName("b_airplane_door_exit", -1);
		
		decl Float:posx[3];
		
		if (planecheckpoint > 0)
		{
			GetEntityAbsOrigin(planecheckpoint, posx);
			if (CheckforBots(posx, 300.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] The team has collected all of their parachutes.");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para01A", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para01B", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para01C", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para01D", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para02A", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para02B", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para02C", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para02D", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para03A", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para03B", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para03C", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para03D", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para04A", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para04B", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para04C", "Use");
				UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "b_para04D", "Use");
				MapTrigger = true;
			}
		}
		
		decl Float:pos1[3];
		
		pos1[0] = -161.166092;
		pos1[1] = 1113.764648;
		pos1[2] = -47.968750;
		
		if (CheckforBots(pos1, 100.0) && !MapTriggerTwo)
		{
			AcceptEntityInput(FindEntityByName("b_airplane_door_exit", -1), "Use");
			MapTriggerTwo = true;
		}
	}	
	
	if (StrEqual(mapname, "l4d2_wanli02", true))
	{
		new fireworksbutton = FindEntityByName("fireworks_event_button", -1);
		
		decl Float:posx[3];
		
		if (fireworksbutton > 0)
		{
			GetEntityAbsOrigin(fireworksbutton, posx);
			if (CheckforBots(posx, 300.0) && !MapTrigger)
			{
				PrintToServer("[AutoTrigger] Hey, I wonder what these things do.");
				AcceptEntityInput(fireworksbutton, "Use");
			}
		}
	}
	
	if (StrEqual(mapname, "l4d2_wanli03", true))
	{
		decl Float:posx[3];
		
		posx[0] = -4120.485840;
		posx[1] = 2709.216064;
		posx[2] = 379.552490;

		if (CheckforBots(posx, 1500.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The ice melts... You have 7 minutes...");
			AcceptEntityInput(FindEntityByName("rescueboat_triggerfinale", -1), "ForceFinaleStart");
			CreateTimer(0.1, BotsStick);
			CreateTimer(60.0, IceMelt1);
			CreateTimer(120.0, IceMelt2);
			CreateTimer(180.0, IceMelt3);
			CreateTimer(240.0, IceMelt4);
			CreateTimer(300.0, IceMelt5);
			CreateTimer(360.0, IceMelt6);
			CreateTimer(420.0, IceMelt7);
			CreateTimer(420.1, BotsUnstick);
			MapTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_roadtonowhere_route02", true))
	{
		new tankdoor = FindEntityByName("tankdoorin_button", -1);
	
		decl Float:pos1[3];
		GetEntityAbsOrigin(tankdoor, pos1);
		
		if (CheckforBots(pos1, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Someone opens the door...");
			AcceptEntityInput(tankdoor, "Press");
			if (!IsVersus())
			{
				CreateTimer(5.0, TankDoor01COOP, 0);
			}
			else if (!IsCoop())
			{
				CreateTimer(5.0, TankDoor01VERSUS, 0);
			}
			MapTrigger = true;
		}

		new tankotherdoor = FindEntityByName("tankdoorout_button", -1);
		
		decl Float:pos2[3];
		GetEntityAbsOrigin(tankotherdoor, pos2);
			
		if (CheckforBots(pos2, 100.0) && !MapTriggerTwo)
		{
			PrintToServer("[AutoTrigger] The bots move on...");
			AcceptEntityInput(FindEntityByName("tankdoorout_button", -1), "Press");
			CreateTimer(5.0, TankDoor02, 0);
			MapTriggerTwo = true;
		}
	}

	if (StrEqual(mapname, "l4d2_roadtonowhere_route03", true))
	{
		new alarmdoor = FindEntityByName("emergency_door", -1);
		
		decl Float:posx[3];
		GetEntityAbsOrigin(alarmdoor, posx);
		
		if (CheckforBots(posx, 250.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Someone opens the door...");
			if (IsCoop())
			{
				PrintToServer("[AutoTrigger] The alarm will be disabled in 60 seconds.");
				CreateTimer(60.0, RoadToNoWhereFix);
			}
			if (IsVersus())
			{
				PrintToServer("[AutoTrigger] The alarm will be disabled in 40 seconds.");
				CreateTimer(60.0, RoadToNoWhereFix);
			}
		}
	}
		
	if (StrEqual(mapname, "l4d2_roadtonowhere_route04", true))
	{
		new alarmwindow = FindEntityByName("window_breakglass", -1);
		
		decl Float:posx[3];
		GetEntityAbsOrigin(alarmwindow, posx);
		
		if (CheckforBots(posx, 250.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] They break an alarmed window...");
			if (IsCoop())
			{
				PrintToServer("[AutoTrigger] The alarm will be disabled in 30 seconds.");
				CreateTimer(30.0, RoadToNoWhereFix2);
			}
			if (IsVersus())
			{
				PrintToServer("[AutoTrigger] The alarm will be disabled in 10 seconds.");
				CreateTimer(10.0, RoadToNoWhereFix2);
			}
		}
	}
	
	if (StrEqual(mapname, "l4d2_stadium1_apartment", true))
	{	
		decl Float:pos1[3];
		pos1[0] = 340.527100;
		pos1[1] = 520.226379;
		pos1[2] = -2130.968750;
		
		if (CheckforBots(pos1, 500.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] They must get the power back on...");
			CreateTimer(0.1, BotsStick);
			CreateTimer(60.0, SuicideBlitz2PowerSwitch);
			CreateTimer(75.0, SuicideBlitz2ReturnToElevator);
			MapTrigger = true;
		}
		
		decl Float:pos2[3];
		pos2[0] = 342.217285;
		pos2[1] = 508.724915;
		pos2[2] = -3743.968750;
		
		if (CheckforBots(pos2, 300.0) && !MapTriggerTwo)
		{
			CreateTimer(0.1, BotsUnstick);
			MapTriggerTwo = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_stadium2_riverwalk", true))
	{
		decl Float:posx[3];
		posx[0] = 2213.667725;
		posx[1] = 6103.937988;
		posx[2] = -129.337051;
		
		if (CheckforBots(posx, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] Someone shoots the gas can...");
			CreateTimer(10.0, SuicideBlitz2Gascan);
			MapTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_stadium3_city1", true))
	{
		new sbprisonbutton = FindEntityByName("button_model", -1);
		
		decl Float:posx[3];
		GetEntityAbsOrigin(sbprisonbutton, posx);
		
		if (CheckforBots(posx, 300.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] The alarm has been disabled.");
			UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "alarm_off_relay", "trigger");
			MapTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_stadium4_city2", true))
	{
		decl Float:posx[3];
		posx[0] = -5330.817871;
		posx[1] = 5056.894531;
		posx[2] = -10.968750;
		
		if (CheckforBots(posx, 300.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] The team crosses the plank... (60 seconds)");
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, -5803.865234);
			WritePackFloat(posdata, 5366.454590);
			WritePackFloat(posdata, 397.031250);
			CreateTimer(60.0, WarpAllBots, posdata);
			WarpTrigger = true;
		}
	}
	
	if (StrEqual(mapname, "l4d2_stadium5_stadium", true))
	{
		new sbradio = FindEntityByName("radio_btn", -1);
		
		decl Float:posx[3];
		GetEntityAbsOrigin(sbradio, posx);
		
		if (CheckforBots(posx, 250.0) && !MapTrigger)
		{
			PrintToServer("[AutoTrigger] They call for help...");
			AcceptEntityInput(FindEntityByName("radio_btn", -1), "Press");
			CreateTimer(0.1, BotsStick);
			CreateTimer(60.0, SuicideBlitz2FinaleRelay);
			CreateTimer(60.0, BotsUnstick);
			MapTrigger = true;
		}
		
		decl Float:pos1[3];
		pos1[0] = 8031.500000;
		pos1[1] = -4761.375000;
		pos1[2] = -12.000000;
		
		if (CheckforBots(pos1, 250.0) && !WarpTrigger)
		{
			PrintToServer("[AutoTrigger] A fail-safe has been activated.");
			new Handle:posdata = CreateDataPack();
			WritePackFloat(posdata, 7245.513672);
			WritePackFloat(posdata, -5023.473633);
			WritePackFloat(posdata, 152.031250);
			CreateTimer(10.0, WarpAllBots, posdata);
			
			WarpTrigger = true;
		}
	}
	return Plugin_Continue;
}

public Action:WarpAllBots(Handle:Timer, Handle:posdata)
{
	ResetPack(posdata);
	decl Float:position[3];
	position[0] = ReadPackFloat(posdata);
	position[1] = ReadPackFloat(posdata);
	position[2] = ReadPackFloat(posdata);
	CloseHandle(posdata);
	
	PrintToServer("[AutoTrigger] Bots have been repositioned.");
	
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target) && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				TeleportEntity(target, position, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public Action:BotsStopMove(Handle:Timer)
{
	// Dead Center 02 - Go In The Market
	SetConVarInt(FindConVar("sb_move"), 0);
}

public Action:BotsStartMove(Handle:Timer)
{
	// Dead Center 02 - Out Off The Market
	SetConVarInt(FindConVar("sb_move"), 1);
}

public Action:BotsStick(Handle:Timer)
{
	// Cold Stream 04 - Finale Started
	SetConVarInt(FindConVar("sb_unstick"), 0);
}

public Action:BotsUnstick(Handle:Timer)
{
	// Cold Stream 04 - Finale Started
	SetConVarInt(FindConVar("sb_unstick"), 1);
}

public Action:BotsOffFire(Handle:Timer)
{
	// Cold Stream 04 - Finale Started
	SetConVarInt(FindConVar("sb_open_fire"), 0);
}

public Action:BotsOpenFire(Handle:Timer)
{
	// Cold Stream 04 - Finale Started
	SetConVarInt(FindConVar("sb_open_fire"), 1);
}

public Action:CallSuperMarket(Handle:Timer)
{
	// name store_doors, class prop_door_rotating - input "Open"
	AcceptEntityInput(FindEntityByName("store_doors", -1), "Open");
}

public Action:CallTankerBoom(Handle:Timer)
{
	// ent_fire tanker_destroy_relay trigger
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "tanker_destroy_relay", "trigger");
}

public Action:BridgeMiniFinale(Handle:Timer)
{
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "bridge_button", "Use");
}

public Action:C4M2BotsActions(Handle:Timer)
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target) && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				L4D2_RunScript("CommandABot({cmd=1,pos=Vector(-1125.9,-10181.1,179.6),bot=GetPlayerFromUserID(%i)})", GetClientUserId(target));
			}
		}
	}
}

public Action:C5M4BotsActions(Handle:Timer)
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target) && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				L4D2_RunScript("CommandABot({cmd=1,pos=Vector(-2179.3,389.3,302.0),bot=GetPlayerFromUserID(%i)})", GetClientUserId(target));
			}
		}
	}
}

public Action:C6M2BotsActions(Handle:Timer)
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target) && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				L4D2_RunScript("CommandABot({cmd=1,pos=Vector(36.9,1888.7,-1.9),bot=GetPlayerFromUserID(%i)})", GetClientUserId(target));
			}
		}
	}
}

public Action:ResumeBotsActions(Handle:Timer)
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target) && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(target));
			}
		}
	}
}

public Action:RunBusStationEvent(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("finale_cleanse_entrance_door", -1), "Close");
	//PrintToServer("[AutoTrigger] They gather in the CEDA Trailer...");
	CreateTimer(5.0, RunBusStationEvent2);
}

public Action:RunBusStationEvent2(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("finale_cleanse_exit_door", -1), "Open");
	//PrintToServer("[AutoTrigger] They run for it...");
}
/*
public Action:C2M3WarpAllBotToThere(Handle:Timer)
{
	// c2m3 - after shut off the rollercoaster, warp them to the special spot
	decl Float:posx[3];
	posx[0] = -4029.9;
	posx[1] = 1428.9;
	posx[2] = 222.0;
	// confusion spot -4029.9 1428.9 222.0, teleport them off
	// to: -4315.1 2311.4 313.2
	if (CheckforBots(posx, 300.0) && !WarpTrigger)
	{
		PrintToServer("[AutoTrigger] Bot found at a stuck spot, warping them all ahead in 50 seconds");
		
		new Handle:posdata = CreateDataPack();
		WritePackFloat(posdata, -4315.1);
		WritePackFloat(posdata, 2311.4);
		WritePackFloat(posdata, 313.2);
		CreateTimer(50.0, WarpAllBots, posdata);
		WarpTrigger = true;
	}
}
public Action:C3M3WarpAllBotToThere(Handle:Timer)
{
	decl1 Float:posx[3];
	posx[0] = ;
	posx[1] = ;
	posx[2] = ;
	if (CheckForBots(posx, 2000.0) && !WarpTrigger)
	{
		PrintToServer("[AutoTrigger] Bots can't seem to simply lower the plank... I'll have to do it for them...");
		
		new Handle:posdata = CreateDataPack();
		WritePackFloat(posdata, -4315.1);
		WritePackFloat(posdata, 2311.4);
		WritePackFloat(posdata, 313.2);
		CreateTimer(50.0, WarpAllBots, posdata);
		WarpTrigger = true;
	}
}
*/
public Action:C3M4FinaleStart(Handle:Timer)
{
	PrintToServer("[AutoTrigger] Virgil is on his way!");
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "escape_gate_triggerfinale", "Use");
}

public Action:C5M5FinaleStart(Handle:Timer)
{
	PrintToServer("[AutoTrigger] The bridge lowers...");
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "finale", "Use");
}

public Action:C10M5FinaleStart(Handle:Timer)
{
	// c10m5 - finale start
	if (MapTrigger && !MapTriggerTwo)
	{
		PrintToServer("[AutoTrigger] John Slater is on his way!");
		UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "radio", "Use");
		MapTriggerTwo = true;
	}
}

public Action:C11M5FinaleStart(Handle:Timer)
{
	// c11m5 - finale start
	if (MapTrigger && !MapTriggerTwo)
	{
		PrintToServer("[AutoTrigger] The plane is fueling up!");
		UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "radio", "Use");
		MapTriggerTwo = true;
	}
}

public Action:GeneratorStart(Handle:Timer)
{
	// Crash Cause 02 - Generator Start
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finaleswitch_initial", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_lever", "Enable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event_pre", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event", "GenerateGameEvent", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_start", "StopSound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_start_particles", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_light_switchable", "TurnOn", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_lights", "LightOn", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_run", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_switch_spark", "SparkOnce", "", "1");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_lever", "SetDefaultAnimation", "IDLE_DOWN", "0.1");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_lever", "SetAnimation", "DOWN", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_spark02", "SparkOnce", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_spark01", "SparkOnce", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "survivalmode_exempt", "Trigger", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_break_timer", "Enable", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_lever", "ForceFinaleStart", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_hint", "EndHint", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "survival_start_relay", "Trigger", "", "0");
}

public Action:GeneratorStartTwoReady(Handle:Timer)
{
	// Crash Cause 02 - Generator Second Start
	PrintToServer("[AutoTrigger] The generator has been restarted!");
	AcceptEntityInput(FindEntityByName("generator_switch", -1), "Press");
}

public Action:GeneratorStartTwo(Handle:Timer)
{
	// Crash Cause 02 - Generator Second Start
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_switch", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_lever", "Enable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_start", "StopSound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_start_particles", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_light_switchable", "TurnOn", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_lights", "LightOn", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_run", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_switch_spark", "SparkOnce", "", "1");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_lever", "SetDefaultAnimation", "IDLE_DOWN", "0.1");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_lever", "SetAnimation", "DOWN", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_spark02", "SparkOnce", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "lift_spark01", "SparkOnce", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "survivalmode_exempt", "Trigger", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_lever", "ForceFinaleStart", "", "5");
}

public Action:TankDoor01COOP(Handle:Timer)
{
	// The Sacrifice 01 - Tank Door - In
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin_button", "UnLock", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "coop_tank", "Trigger", "", "0+5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin", "Open", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin_button", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_sound_timer", "Disable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "panic_event_relay", "Trigger", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "doorsound", "PlaySound", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_fog", "Enable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_fog", "Disable", "", "5+0.5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "big_splash", "Stop", "", "5+2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "big_splash", "Start", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_door_clip", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "director", "EnableTankFrustration", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "battlefield_cleared", "UnblockNav", "", "5+60");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_car_camera_clip", "Kill", "", "5");
}

public Action:TankDoor01VERSUS(Handle:Timer)
{
	// The Sacrifice 01 - Tank Door - In
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin_button", "UnLock", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "versus_tank", "Trigger", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin", "Open", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorin_button", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_sound_timer", "Disable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "panic_event_relay", "Trigger", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "doorsound", "PlaySound", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_fog", "Enable", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_fog", "Disable", "", "5+0.5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "big_splash", "Stop", "", "5+2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "big_splash", "Start", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_door_clip", "Kill", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "director", "EnableTankFrustration", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "battlefield_cleared", "UnblockNav", "", "5+60");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tank_car_camera_clip", "Kill", "", "5");
}

public Action:TankDoor02(Handle:Timer)
{
	// The Sacrifice 01 - Tank Door - Out
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorout_button", "UnLock", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorout", "Open", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "tankdoorout_button", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "battlefield_cleared", "UnblockNav", "", "0");
}

public Action:TimedButtonTest(Handle:Timer)
{
	// The Sacrifice 01 - Tank Door - In
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "gnomebutton", "UnLock", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "gnomebutton", "Press", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "gnomebutton", "Kill", "", "0");
} 

public Action:C7M3GeneratorStart(Handle:Timer)
{
	// The Sacrifice 03 - Generator Start
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_start_button", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_start", "StopSound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_run", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_start_particles", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_model2", "StopGlowing", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event_pre", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "mob_spawner_finale", "Enable", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator2_tankmessage_templated", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "relay_advance_finale_state", "Trigger", "", "2");
	//UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "", "", "", "0");
}

public Action:C7M3GeneratorStart1(Handle:Timer)
{
	// The Sacrifice 03 - Generator1 Start
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_start_button1", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_start1", "StopSound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_run1", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_start_particles1", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_model1", "StopGlowing", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "mob_spawner_finale", "Enable", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "relay_advance_finale_state", "Trigger", "", "2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event_pre1", "Kill", "", "0");
}

public Action:C7M3GeneratorStart2(Handle:Timer)
{
	// The Sacrifice 03 - Generator2 Start
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "finale_start_button2", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_start2", "StopSound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "sound_generator_run2", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_start_particles2", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_model3", "StopGlowing", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "mob_spawner_finale", "Enable", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator3_tankmessage_templated", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "relay_advance_finale_state", "Trigger", "", "2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "radio_game_event_pre2", "Kill", "", "0");
}

public Action:C7M3WarpBotsToGenerator1(Handle:Timer)
{
	// The Sacrifice 03 - Warp Bots to Generator1
	// c7m3 - after they start the first generator, warp them to the special spot,
	// there has an another generator
	// teleport them off to -1224.8 814.7 222.0
	PrintToServer("[AutoTrigger] Start c7m3 trigger1-1.");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -1224.8);
	WritePackFloat(posdata, 814.7);
	WritePackFloat(posdata, 222.0);
	CreateTimer(10.0, WarpAllBots, posdata);
}

public Action:C7M3WarpBotsToGenerator2(Handle:Timer)
{
	// The Sacrifice 03 - Warp Bots to Generator2
	// c7m3 - after they start the second generator, warp them to the special spot,
	// there has the last generator
	// teleport them off to 1781.9 678.1 -33.9
	PrintToServer("[AutoTrigger] Start c7m3 trigger2-1.");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, 1781.9);
	WritePackFloat(posdata, 678.1);
	WritePackFloat(posdata, -33.9);
	CreateTimer(10.0, WarpAllBots, posdata);
}

public Action:C7M3BridgeStartButton(Handle:Timer)
{
	// The Sacrifice 03 - C7M3 Bridge Start Button
	PrintToServer("[AutoTrigger] The bridge goes up...");
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "bridge_start_button", "Use");
}

public Action:C7M3GeneratorFinaleButtonStart(Handle:Timer)
{
	// The Sacrifice 03 - Generator final button start
	PrintToServer("[AutoTrigger] Rest in peace, Survivor Bot...");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "generator_final_button_relay", "Trigger", "", "0");
}

public Action:C13M2Trigger(Handle:Timer)
{
	//PrintToServer("[AutoTrigger] Start c13m2 trigger.");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_barrels", "StopGlowing", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_barrels", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_button", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_explosion", "Explode", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_fire", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_fire", "Stop", "", "10");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_fire_sound", "PlaySound", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_fire_sound", "StopSound", "", "11");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_shake", "StartShake", "", "2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_shake", "StopShake", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_murette", "Break", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_impact", "Explode", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_explosion_sound", "PlaySound", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "barrier", "EnableMotion", "", "2.5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_smoke", "Start", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_smoke", "Stop", "", "10");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_dummy", "Kill", "", "0");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "director", "BeginScript", "event_alarme", "3.2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_new_particle", "Start", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_new_particle1", "Start", "", "3.2");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_new_particle1", "Stop", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_new_particle", "Stop", "", "5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "ceda_truck_alarm", "PlaySound", "", "3.5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_nav_blocker", "UnblockNav", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "scene_relay", "Trigger", "", "4.5");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_barrels_hurt_trigger", "Enable", "", "3");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "bridge_barrels_hurt_trigger", "Disable", "", "10");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "barrier", "DisableMotion", "", "8");
	UnflagAndExecuteCommandTwo(TriggeringBot, "ent_fire", "template_onslaught_hint", "ForceSpawn", "", "4");
}

public Action:UF4FailSafeOne(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, 128.350266);
	WritePackFloat(posdata, -42.504993);
	WritePackFloat(posdata, 512.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:UF4FailSafeTwo(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, 316.117584);
	WritePackFloat(posdata, 1012.142151);
	WritePackFloat(posdata, 60.612732);
	CreateTimer(0.1, WarpAllBots, posdata);
	AcceptEntityInput(FindEntityByName("garage_elevator_trigger", -1), "Press");
}

public Action:UF4FailSafeThree(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -213.626831);
	WritePackFloat(posdata, 3271.414551);
	WritePackFloat(posdata, 0.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:UF4FailSafeFour(Handle:Timer)
{
	WarpTriggerThree = true;
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -1944.317749);
	WritePackFloat(posdata, 3049.523682);
	WritePackFloat(posdata, 260.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
	AcceptEntityInput(FindEntityByName("hanger_door_trigger", -1), "Press");
}

public Action:UFFinish(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -1024.538818);
	WritePackFloat(posdata, 4051.666504);
	WritePackFloat(posdata, 53.531250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:UrbanFlightJoke(Handle:Timer)
{
	PrintToServer("[AutoTrigger] Huh. I guess this is a du-\x01");
}

public Action:TowerGoesBoom(Handle:Timer)
{
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "crescendo_relay", "Trigger");
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "crescendo_button", "Kill");
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "crescendo_suitcasebomb", "Kill");
}

public Action:NeverMind(Handle:Timer)
{
	PrintToServer("[AutoTrigger] Never mind...\x01");
}

public Action:IceMelt1(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block01", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -3031.389893);
	WritePackFloat(posdata, 2597.083252);
	WritePackFloat(posdata, 496.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt2(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block02", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -3286.694092);
	WritePackFloat(posdata, 390.235321);
	WritePackFloat(posdata, 249.449005);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt3(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block03", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -1385.912109);
	WritePackFloat(posdata, 2924.836914);
	WritePackFloat(posdata, 237.437546);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt4(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block04", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -5834.841309);
	WritePackFloat(posdata, 4019.392334);
	WritePackFloat(posdata, 760.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt5(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block05", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -3031.389893);
	WritePackFloat(posdata, 2597.083252);
	WritePackFloat(posdata, 496.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt6(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block06", -1), "Break");
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -3286.694092);
	WritePackFloat(posdata, 390.235321);
	WritePackFloat(posdata, 249.449005);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:IceMelt7(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("ice_block07", -1), "Break");
}

public Action:RoadToNoWhereFix(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, 7176.283691);
	WritePackFloat(posdata, -11124.616211);
	WritePackFloat(posdata, 263.031250);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:RoadToNoWhereFix2(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -2984.835938);
	WritePackFloat(posdata, 1130.597778);
	WritePackFloat(posdata, 293.519775);
	CreateTimer(0.1, WarpAllBots, posdata);
}

public Action:SuicideBlitz2PowerSwitch(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, -587.908386);
	WritePackFloat(posdata, 703.629517);
	WritePackFloat(posdata, -2086.968750);
	CreateTimer(0.1, WarpAllBots, posdata);
	
	AcceptEntityInput(FindEntityByName("power restore floor cons", -1), "Press");
}

public Action:SuicideBlitz2ReturnToElevator(Handle:Timer)
{
	new Handle:posdata = CreateDataPack();
	WritePackFloat(posdata, 375.483673);
	WritePackFloat(posdata, 503.492798);
	WritePackFloat(posdata, -2130.968750);
	CreateTimer(0.1, WarpAllBots, posdata);
	
	AcceptEntityInput(FindEntityByName("elevator button2", -1), "Press"); 
}

public Action:SuicideBlitz2FinaleRelay(Handle:Timer)
{
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "grate_open_relay", "Trigger");
}

public Action:SuicideBlitz2Gascan(Handle:Timer)
{
	AcceptEntityInput(FindEntityByName("event_gascan", -1), "Ignite");
}

public Action:FinaleStart(Handle:Timer)
{
	if (FinaleHasStarted) return Plugin_Continue;
	
	if (!TriggeringBot) TriggeringBot = GetAnyValidClient();
	else if (!IsClientInGame(TriggeringBot)) TriggeringBot = GetAnyValidClient();
	
	if (!TriggeringBot) return Plugin_Continue;
	UnflagAndExecuteCommand(TriggeringBot, "ent_fire", "trigger_finale", "");
	PrintToServer("[AutoTrigger] The finale has started!");
	return Plugin_Continue;
}

// this bool return true if a Bot was found in a radius around the given position, and sets TriggeringBot to it.
bool:CheckforBots(Float:position[3], Float:distancesetting)
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (GetClientHealth(target)>1 && GetClientTeam(target) == 2 && IsFakeClient(target)) // make sure target is a Survivor Bot
			{
				if (IsPlayerIncapped(target)) // incapped doesnt count
					return false;
				
				decl Float:targetPos[3];
				GetClientAbsOrigin(target, targetPos);
				new Float:distance = GetVectorDistance(targetPos, position); // check Survivor Bot Distance from checking point
				
				if (distance < distancesetting)
				{
					TriggeringBot = target;
					return true;
				}
				else
				{
					continue;
				}
			}
		}
	}
	return false;
}

stock FindEntityByName(String:name[], any:startcount)
{
	decl String:classname[128];
	new maxentities = GetMaxEntities();
	
	for (new i = startcount; i <= maxentities; i++)
	{
		if (!IsValidEntity(i)) continue; // exclude invalid entities.
		
		GetEdictClassname(i, classname, 128);
		
		if (FindDataMapOffs(i, "m_iName") == -1) continue;
		
		decl String:iname[128];
		GetEntPropString(i, Prop_Data, "m_iName", iname, sizeof(iname));
		if (strcmp(name, iname, false) == 0) return i;
	}
	return -1;
}

stock UnflagAndExecuteCommand(client, String:command[], String:parameter1[]="", String:parameter2[]="")
{
	if (!client || !IsClientInGame(client)) client = GetAnyValidClient();
	if (!client || !IsClientInGame(client)) return;
	
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, parameter1, parameter2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}

stock UnflagAndExecuteCommandTwo(client, String:command[], String:parameter1[]="", String:parameter2[]="", String:parameter3[]="", String:parameter4[]="")
{
	if (!client || !IsClientInGame(client)) client = GetAnyValidClient();
	if (!client || !IsClientInGame(client)) return;
	
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s %s %s", command, parameter1, parameter2, parameter3, parameter4);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}

//entity abs origin code from here
//http://forums.alliedmods.net/showpost.php?s=e5dce96f11b8e938274902a8ad8e75e9&p=885168&postcount=3
stock GetEntityAbsOrigin(entity,Float:origin[3])
{
	if (entity > 0 && IsValidEntity(entity))
	{
		decl Float:mins[3], Float:maxs[3];
		GetEntPropVector(entity,Prop_Send,"m_vecOrigin",origin);
		GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
		GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
		
		origin[0] += (mins[0] + maxs[0]) * 0.5;
		origin[1] += (mins[1] + maxs[1]) * 0.5;
		origin[2] += (mins[2] + maxs[2]) * 0.5;
	}
}

stock bool:IsVersus()
{
	decl String:gamemode[56];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	if (StrContains(gamemode, "versus", false) > -1)
		return true;
	return false;
}

stock bool:IsCoop()
{
	decl String:gamemode[56];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	if (StrContains(gamemode, "coop", false) > -1)
		return true;
	return false;
}

stock bool:AllBotTeam()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			if (!IsFakeClient(client)) return false;
		}
	}
	return true;
}

stock bool:IsPlayerIncapped(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;
	return false;
}

stock GetAnyValidClient()
{
	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target)) return target;
	}
	return -1;
}

stock AutoCommand(client, const String:command[], const String:arguments[], any:...)
{
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 4);	

	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, vscript);
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}

// Thanks to Lux's advice and Timocop's implementation

stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}