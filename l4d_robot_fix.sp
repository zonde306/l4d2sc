#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"1.0"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "悬浮武器修复版",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

new Handle:RobotReactiontime = INVALID_HANDLE;
new Handle:RobotEnergy = INVALID_HANDLE;

public void OnPluginStart()
{
	RobotReactiontime = CreateConVar("l4d_robot_reaction_time", "0.1", "Robot反应时间", CVAR_FLAGS, true, 0.01, true, 1.0);
 	RobotEnergy = CreateConVar("l4d_robot_energy", "5.0", "Robot能量维持时间(分鐘)", CVAR_FLAGS, true, 0.1);
	AutoExecConfig(true, "l4d_robot_fix");
	
	RegAdminCmd("sm_robot", sm_robot, ADMFLAG_CHEATS);
	CreateTimer(1.0, Timer_SetupSpell);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd);
	
	ConVarHooked_OnUpdateSetting(INVALID_HANDLE, "", "");
	HookConVarChange(RobotReactiontime, ConVarHooked_OnUpdateSetting);
	HookConVarChange(RobotEnergy, ConVarHooked_OnUpdateSetting);
}

#define SOUNDCLIPEMPTY	"weapons/ClipEmpty_Rifle.wav"
#define SOUNDRELOAD		"weapons/shotgun/gunother/shotgun_load_shell_2.wav"
#define SOUNDREADY		"weapons/shotgun/gunother/shotgun_pump_1.wav"
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"

#define WEAPONCOUNT 17

#define SOUND0 "weapons/hunting_rifle/gunfire/hunting_rifle_fire_1.wav"
#define SOUND1 "weapons/rifle/gunfire/rifle_fire_1.wav"
#define SOUND2 "weapons/auto_shotgun/gunfire/auto_shotgun_fire_1.wav"
#define SOUND3 "weapons/shotgun/gunfire/shotgun_fire_1.wav"
#define SOUND4 "weapons/SMG/gunfire/smg_fire_1.wav"
#define SOUND5 "weapons/pistol/gunfire/pistol_fire.wav"
#define SOUND6 "weapons/magnum/gunfire/magnum_shoot.wav"
#define SOUND7 "weapons/rifle_ak47/gunfire/rifle_fire_1.wav"
#define SOUND8 "weapons/rifle_desert/gunfire/rifle_fire_1.wav"
#define SOUND9 "weapons/sg552/gunfire/sg552-1.wav"
#define SOUND10 "weapons/shotgun_chrome/gunfire/shotgun_fire_1.wav"
#define SOUND11 "weapons/auto_shotgun_spas/gunfire/shotgun_fire_1.wav"
#define SOUND12 "weapons/sniper_military/gunfire/sniper_military_fire_1.wav"
#define SOUND13 "weapons/scout/gunfire/scout_fire-1.wav"
#define SOUND14 "weapons/awp/gunfire/awp1.wav"
#define SOUND15 "weapons/mp5navy/gunfire/mp5-1.wav"
#define SOUND16 "weapons/smg_silenced/gunfire/smg_fire_1.wav"

#define MODEL0 "weapon_hunting_rifle"
#define MODEL1 "weapon_rifle"
#define MODEL2 "weapon_autoshotgun"
#define MODEL3 "weapon_pumpshotgun"
#define MODEL4 "weapon_smg"
#define MODEL5 "weapon_pistol"
#define MODEL6 "weapon_pistol_magnum"
#define MODEL7 "weapon_rifle_ak47"
#define MODEL8 "weapon_rifle_desert"
#define MODEL9 "weapon_rifle_sg552"
#define MODEL10 "weapon_shotgun_chrome"
#define MODEL11 "weapon_shotgun_spas"
#define MODEL12 "weapon_sniper_military"
#define MODEL13 "weapon_sniper_scout"
#define MODEL14 "weapon_sniper_awp"
#define MODEL15 "weapon_smg_mp5"
#define MODEL16 "weapon_smg_silenced"

/* Particle */
#define PARTICLE_BLOOD	"blood_impact_infected_01"

new String:SOUND[WEAPONCOUNT+3][70]=
{SOUND0, SOUND1, SOUND2, SOUND3, SOUND4, SOUND5, SOUND6, SOUND7,SOUND8,SOUND9, SOUND10, SOUND11,SOUND12,SOUND13,SOUND14, SOUND15,SOUND16,SOUNDCLIPEMPTY, SOUNDRELOAD, SOUNDREADY};

new String:MODEL[WEAPONCOUNT][32]=
{MODEL0, MODEL1, MODEL2, MODEL3, MODEL4, MODEL5,MODEL6, MODEL7,MODEL8,MODEL9,MODEL10, MODEL11, MODEL12,MODEL13,MODEL14, MODEL15, MODEL16};

new Float:fireinterval[WEAPONCOUNT]={0.25, 0.068, 0.30, 0.65, 0.060, 0.20, 0.33, 0.145, 0.14, 0.064, 0.65, 0.30, 0.265, 0.9, 1.25, 0.065, 0.055};
new Float:bulletaccuracy[WEAPONCOUNT]={1.15, 1.4, 3.5, 3.5, 1.6, 1.7, 1.7, 1.5, 1.6, 1.5, 3.5, 3.5, 1.15, 1.00, 0.8, 1.6,1.6};
new Float:weaponbulletdamage[WEAPONCOUNT]={90.0, 30.0, 25.0, 30.0, 20.0, 30.0, 60.0, 70.0, 40.0, 40.0, 30.0, 30.0, 90.0, 100.0, 150.0, 35.0, 35.0};
new weaponclipsize[WEAPONCOUNT]=		{15, 50, 10, 8, 50, 30, 8, 40, 20, 50, 8, 10, 30, 15, 20, 50, 50};
new weaponbulletpershot[WEAPONCOUNT]=	{1, 1, 11, 10, 1, 1, 1, 1, 1, 1, 8, 9, 1, 1, 1, 1, 1};
new Float:weaponloadtime[WEAPONCOUNT]={2.0, 1.5, 0.3, 0.3, 1.5, 1.5, 1.9, 1.5, 1.5, 1.6, 0.3, 0.3, 2.0,2.0, 2.0, 1.5, 1.5};
new weaponloadcount[WEAPONCOUNT]={15, 50, 1,1, 50, 30, 8, 40, 60, 50, 1, 1, 30, 15, 20, 50, 50};
new bool:weaponloaddisrupt[WEAPONCOUNT]={false,false, true, true,false,false, false, false, false, true, true, false, false, false, false, false};

new robot[MAXPLAYERS+1];
new keybuffer[MAXPLAYERS+1];
new weapontype[MAXPLAYERS+1];
new bullet[MAXPLAYERS+1];
new Float:firetime[MAXPLAYERS+1];
new bool:reloading[MAXPLAYERS+1];
new Float:reloadtime[MAXPLAYERS+1];
new Float:scantime[MAXPLAYERS+1];
new Float:walktime[MAXPLAYERS+1];
new Float:botenerge[MAXPLAYERS+1];
new SIenemy[MAXPLAYERS+1];
new CIenemy[MAXPLAYERS+1];
new Float:robotangle[MAXPLAYERS+1][3];
new Float:robot_reactiontime;
new Float:robot_energy;
new bool:robot_gamestart = false;
new g_BeamSprite;

public Action:Timer_SetupSpell(Handle:timer, any:unused)
{
	SC_CreateSpell("pxh_robot_random", "自动武器 - 随机", 100, 3000, "创建一把悬浮并跟随玩家的武器\n它会自动攻击敌人");
	SC_CreateSpell("pxh_robot_random_shotgun", "自动武器 - 随机霰弹枪", 100, 3750, "创建一把悬浮并跟随玩家的武器\n它会自动攻击敌人");
	SC_CreateSpell("pxh_robot_random_smg", "自动武器 - 随机冲锋枪", 100, 2500, "创建一把悬浮并跟随玩家的武器\n它会自动攻击敌人");
	SC_CreateSpell("pxh_robot_random_rifle", "自动武器 - 随机步枪", 100, 4000, "创建一把悬浮并跟随玩家的武器\n它会自动攻击敌人");
	SC_CreateSpell("pxh_robot_random_sniper", "自动武器 - 随机狙击枪", 100, 4250, "创建一把悬浮并跟随玩家的武器\n它会自动攻击敌人");
}

public Action SC_OnUseSpellPre(int client, char[] classname, int classnameMax)
{
	if(StrContains(classname, "pxh_robot_", false) != 0)
		return Plugin_Continue;
	
	if(robot[client]>0)
	{
		PrintToChat(client, "\x03[武器]\x01 你已经有一个了。");
		return Plugin_Handled;
	}
	
	/*
	new count=0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(robot[i]>0)
		{
			count++;
		}
	}

	if(count+1>GetConVarInt(l4d_robot_limit))
	{
		PrintToChat(client, "\x03[武器]\x01 已经达到上限了。");
		return Plugin_Handled;
	}
	*/
	
	return Plugin_Continue;
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	if(StrContains(classname, "pxh_robot_", false) != 0)
		return;
	
	char arg[64];
	strcopy(arg, 64, classname);
	ReplaceString(arg, 64, "pxh_robot_", "", false);
	weapontype[client] = GetRobotType(arg);
	botenerge[client] = 0.0;
	
	UpdateRobotData(client);
	AddRobot(client);
	PrintToChat(client, "\x03[武器]\x01 你启动了一个 \x04自动武器\x01 持续 \x05%.0f\x01 秒。", robot_energy);
}

int GetRobotType(const char[] arg)
{
	if(StrEqual(arg, "hunting", false)) return 0;
	else if(StrEqual(arg, "rifle", false)) return 1;
	else if(StrEqual(arg, "auto", false)) return 2;
	else if(StrEqual(arg, "pump", false)) return 3;
	else if(StrEqual(arg, "smg", false)) return 4;
	else if(StrEqual(arg, "pistol", false)) return 5;
	else if(StrEqual(arg, "magnum", false)) return 6;
	else if(StrEqual(arg, "ak47", false)) return 7;
	else if(StrEqual(arg, "desert", false)) return 8;
	else if(StrEqual(arg, "sg552", false)) return 9;
	else if(StrEqual(arg, "chrome", false)) return 10;
	else if(StrEqual(arg, "spas", false)) return 11;
	else if(StrEqual(arg, "military", false)) return 12;
	else if(StrEqual(arg, "scout", false)) return 13;
	else if(StrEqual(arg, "awp", false)) return 14;
	else if(StrEqual(arg, "mp5", false)) return 15;
	else if(StrEqual(arg, "silenced", false)) return 16;
	else if(StrEqual(arg, "random_shotgun", false))
	{
		switch(GetRandomInt(1, 4))
		{
			case 1: return 3;
			case 2: return 10;
			case 3: return 2;
			case 4: return 11;
		}
	}
	else if(StrEqual(arg, "random_smg", false))
	{
		switch(GetRandomInt(1, 3))
		{
			case 1: return 4;
			case 2: return 15;
			case 3: return 16;
		}
	}
	else if(StrEqual(arg, "random_rifle", false))
	{
		switch(GetRandomInt(1, 4))
		{
			case 1: return 1;
			case 2: return 7;
			case 3: return 8;
			case 4: return 9;
		}
	}
	else if(StrEqual(arg, "random_sniper", false))
	{
		switch(GetRandomInt(1, 4))
		{
			case 1: return 0;
			case 2: return 12;
			case 3: return 13;
			case 4: return 14;
		}
	}
	
	return GetRandomInt(0, WEAPONCOUNT - 1);
}

public ConVarHooked_OnUpdateSetting(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	robot_reactiontime = GetConVarFloat(RobotReactiontime);
 	robot_energy = GetConVarFloat(RobotEnergy) * 60.0;
}

public OnMapStart()
{
	PrecacheSound(SOUNDCLIPEMPTY);
	PrecacheSound(SOUNDREADY);
	PrecacheSound(SOUNDRELOAD);
	
	for(new i = 0; i < WEAPONCOUNT; ++i)
	{
		PrecacheModel(MODEL[i]);
		PrecacheSound(SOUND[i]);
	}
	
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	PrecacheParticle(PARTICLE_BLOOD);
}

#define IsValidClient(%1)				(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)			(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))
#define IsPlayerIncapacitated(%1)		(GetEntProp(%1, Prop_Send, "m_isIncapacitated", 1) != 0)
#define IsPlayerHanging(%1)				(GetEntProp(%1, Prop_Send, "m_isHangingFromLedge", 1) != 0)
#define IsPlayerFalling(%1)				(GetEntProp(%1, Prop_Send, "m_isFallingFromLedge", 1) != 0)
#define IsPlayerGhost(%1)				(GetEntProp(%1, Prop_Send, "m_isGhost", 1) != 0)

// #define RobotAttackEffect[%1]	0.5 + 0.025 * RobotUpgradeLv[%1][0]
new Float:RobotAttackEffect[MAXPLAYERS+1];		// 最大 50
// #define RobotAmmoEffect[%1]		1.0 + 0.1 * RobotUpgradeLv[%1][1]
new Float:RobotAmmoEffect[MAXPLAYERS+1];		// 最大 50
// #define RobotRangeEffect[%1]	500 + 25 * RobotUpgradeLv[%1][2]
new Float:RobotRangeEffect[MAXPLAYERS+1];		// 最大 20

void UpdateRobotData(int client)
{
	int attackFactor = SC_GetClientLevel(client) / 2;
	int ammoFactor = SC_GetClientMaxStamina(client) / 20;
	int rangeFactor = SC_GetClientMaxMagic(client) / 50;
	if(attackFactor > 50)
		attackFactor = 50;
	if(ammoFactor > 50)
		ammoFactor = 50;
	if(rangeFactor > 20)
		rangeFactor = 20;
	
	RobotAttackEffect[client] = 0.5 + 0.025 * attackFactor;
	RobotAmmoEffect[client] = 1.0 + 0.1 * ammoFactor;
	RobotRangeEffect[client] = 500.0 + 25.0 * rangeFactor;
}

public Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(robot[i]>0)
			Release(i, false);
		
		botenerge[i] = 0.0;
	}
	
	robot_gamestart = false;
}

public Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(robot[i]>0)
			Release(i, false);
		
		botenerge[i] = 0.0;
	}
	
	robot_gamestart = false;
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0)
	{
		if(robot[client] > 0)
			Release(client, false);
		
		botenerge[client] = 0.0;
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0)
	{
		if(robot[client] > 0)
			Release(client, false);
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0)
	{
		if(robot[client] > 0)
			Release(client, false);
		
		UpdateRobotData(client);
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!robot_gamestart)
		return;
	
	new  victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(victim <= 0)
		return;
	
	new  attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(attacker>0 )
	{
		if(attacker!=victim && GetClientTeam(attacker)==3)
		{
			scantime[victim]=GetEngineTime();
			SIenemy[victim]=attacker;
		}
	}
	else if((attacker = GetEventInt(event, "attackerentid")) > MaxClients)
	{
		if(IsCommonInfected(attacker) || IsWitch(attacker))
			CIenemy[victim]=attacker;
	}
}

DelRobot(ent)
{
	if(ent > 0 && IsValidEntity(ent))
    {
		decl String:item[65];
		GetEdictClassname(ent, item, sizeof(item));
		if(StrContains(item, "weapon")>=0)
		{
			// RemoveEdict(ent);
			SDKUnhook(ent, SDKHook_Use, SDKHooked_OnTakeRobot);
			AcceptEntityInput(ent, "Kill");
		}
    }
}
Release(controller, bool:del=true)
{
	new r=robot[controller];
	if(r>0)
	{
		robot[controller]=0;

		if(del)DelRobot(r);
	}
	if(robot_gamestart)
	{
		new count=0;
		for(new i = 1; i <= MaxClients; i++)
		{
			if(robot[i]>0)
			{
				count++;
			}
		}
		if(count==0) robot_gamestart = false;
	}
}

public Action:sm_robot(Client, arg)
{
	if(!IsValidAliveClient(Client))
		return Plugin_Continue;

	if(robot[Client]>0)
	{
		PrintHintText(Client, "你已经有一个 Robot 了！");
		return Plugin_Handled;
	}
	
	char args[32] = "";
	if(arg >= 1)
		GetCmdArg(1, args, 32);
	weapontype[Client] = GetRobotType(args);
	
	/*
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(arg==i)	weapontype[Client]=i;
	}
	*/
	
	AddRobot(Client);
	return Plugin_Handled;
}

AddRobot(Client)
{
	bullet[Client]=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]);
	new Float:vAngles[3];
	new Float:vOrigin[3];
	new Float:pos[3];
	GetClientEyePosition(Client,vOrigin);
	GetClientEyeAngles(Client, vAngles);
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID,  RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
	}
	CloseHandle(trace);
	decl Float:v1[3];
	decl Float:v2[3];
	SubtractVectors(vOrigin, pos, v1);
	NormalizeVector(v1, v2);
	ScaleVector(v2, 50.0);
	AddVectors(pos, v2, v1);  // v1 explode taget
	new ent=0;
 	ent=CreateEntityByName(MODEL[weapontype[Client]]);
	AcceptEntityInput(ent, "DisableShadow");
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", Client);
  	DispatchSpawn(ent);
  	TeleportEntity(ent, v1, NULL_VECTOR, NULL_VECTOR);

	SetEntityMoveType(ent, MOVETYPE_FLY);
	SIenemy[Client]=0;
	CIenemy[Client]=0;
	scantime[Client]=0.0;
	keybuffer[Client]=0;
	bullet[Client]=0;
	reloading[Client]=false;
	reloadtime[Client]=0.0;
	firetime[Client]=0.0;
	robot[Client]=ent;
	
	robot_gamestart = true;
	SDKHook(ent, SDKHook_Use, SDKHooked_OnTakeRobot);
}

public Action:SDKHooked_OnTakeRobot(int entity, int activator, int caller, UseType type, float value)
{
	// 防止机器人被抢走
	return Plugin_Handled;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

new Float:lasttime=0.0;
new button;
new Float:robotpos[3];
new Float:robotvec[3];
new Float:Clienteyepos[3];
new Float:Clientangle[3];
new Float:enemypos[3];
new Float:infectedorigin[3];
new Float:infectedeyepos[3];
new Float:chargetime;
Do(Client, Float:currenttime, Float:duration)
{
	if(robot[Client]>0)
	{
		if(!IsValidEntity(robot[Client]) || !IsValidAliveClient(Client) || IsFakeClient(Client))
		{
			Release(Client);
		}
		else
		{
			botenerge[Client]+=duration;
			if(botenerge[Client] > robot_energy)
			{
				Release(Client);
				PrintHintText(Client, "你的 自动武器 损坏了");
				return;
			}

			button=GetClientButtons(Client);
   		 	GetEntPropVector(robot[Client], Prop_Send, "m_vecOrigin", robotpos);

			if((button & IN_USE) &&(button & IN_SPEED) && !(keybuffer[Client] & IN_USE))
			{
				Release(Client);
				return;
			}
			if(currenttime - scantime[Client]>robot_reactiontime)
			{
				scantime[Client]=currenttime;
				new ScanedEnemy = ScanEnemy(Client,robotpos);
				if(ScanedEnemy <= MaxClients)
				{
					SIenemy[Client]=ScanedEnemy;
				} else CIenemy[Client]=ScanedEnemy;
			}
			new targetok=false;
			
			if( CIenemy[Client]>0 && IsCommonInfected(CIenemy[Client]) && GetEntProp(CIenemy[Client], Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(CIenemy[Client], Prop_Send, "m_vecOrigin", enemypos);
				enemypos[2]+=40.0;
				SubtractVectors(enemypos, robotpos, robotangle[Client]);
				GetVectorAngles(robotangle[Client],robotangle[Client]);
				targetok=true;
			}
			else
			{
				CIenemy[Client]=0;
			}		
			if(!targetok)
			{
				if(SIenemy[Client]>0 && IsClientInGame(SIenemy[Client]) && IsPlayerAlive(SIenemy[Client]))
				{

					GetClientEyePosition(SIenemy[Client], infectedeyepos);
					GetClientAbsOrigin(SIenemy[Client], infectedorigin);
					enemypos[0]=infectedorigin[0]*0.4+infectedeyepos[0]*0.6;
					enemypos[1]=infectedorigin[1]*0.4+infectedeyepos[1]*0.6;
					enemypos[2]=infectedorigin[2]*0.4+infectedeyepos[2]*0.6;

					SubtractVectors(enemypos, robotpos, robotangle[Client]);
					GetVectorAngles(robotangle[Client],robotangle[Client]);
					targetok=true;
				}
				else
				{
					SIenemy[Client]=0;
				}
			}
			if(reloading[Client])
			{
				//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f", reloadtime[Client]);
				if(bullet[Client]>=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]) && currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
				{
					reloading[Client]=false;
					reloadtime[Client]=currenttime;
					EmitSoundToAll(SOUNDREADY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
					//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, " ");
				}
				else
				{
					if(currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
					{
						reloadtime[Client]=currenttime;
						bullet[Client]+=RoundToNearest(weaponloadcount[weapontype[Client]]*RobotAmmoEffect[Client]);
						EmitSoundToAll(SOUNDRELOAD, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
						//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "reloading %d", bullet[Client]);
					}
				}
			}
			if(!reloading[Client])
			{
				if(!targetok)
				{
					if(bullet[Client]<RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]))
					{
						reloading[Client]=true;
						reloadtime[Client]=0.0;
						if(!weaponloaddisrupt[weapontype[Client]])
						{
							bullet[Client]=0;
						}
					}
				}
			}
			chargetime=fireinterval[weapontype[Client]];
			if(!reloading[Client])
			{
				if(currenttime-firetime[Client]>chargetime)
				{

					if( targetok)
					{
						if(bullet[Client]>0)
						{
							bullet[Client]=bullet[Client]-1;

							FireBullet(Client, robot[Client], enemypos, robotpos);

							firetime[Client]=currenttime;
						 	reloading[Client]=false;
						}
						else
						{
							firetime[Client]=currenttime;
						 	EmitSoundToAll(SOUNDCLIPEMPTY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
							reloading[Client]=true;
							reloadtime[Client]=currenttime;
						}

					}

				}

			}
 			GetClientEyePosition(Client,  Clienteyepos);
			Clienteyepos[2]+=30.0;
			GetClientEyeAngles(Client, Clientangle);
			new Float:distance = GetVectorDistance(robotpos, Clienteyepos);
			if(distance>500.0)
			{
				TeleportEntity(robot[Client], Clienteyepos,  robotangle[Client],NULL_VECTOR);
			}
			else if(distance>100.0)
			{

				MakeVectorFromPoints( robotpos, Clienteyepos, robotvec);
				NormalizeVector(robotvec,robotvec);
				ScaleVector(robotvec, 5*distance);
				if(!targetok )
				{
					GetVectorAngles(robotvec, robotangle[Client]);
				}
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client],robotvec);
				walktime[Client]=currenttime;
			}
			else
			{
				robotvec[0]=robotvec[1]=robotvec[2]=0.0;
				if(!targetok && currenttime-firetime[Client]>4.0)robotangle[Client][1]+=5.0;
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client],robotvec);
			}
		 	keybuffer[Client]=button;
		}
	}
	else
	{
		botenerge[Client]=botenerge[Client]-duration*0.5;
		if(botenerge[Client]<0.0)botenerge[Client]=0.0;
	}
}
public OnGameFrame()
{
	if(!robot_gamestart)	return;
	new Float:currenttime = GetEngineTime();
	new Float:duration = currenttime-lasttime;
	if(duration<0.0 || duration>1.0)	duration=0.0;
	for(new Client = 1; Client <= MaxClients; Client++)
	{
		if(IsClientInGame(Client)) Do(Client, currenttime, duration);
	}
	lasttime = currenttime;
}
ScanEnemy(Client, Float:rpos[3] )
{
	/*
	decl Float:infectedpos[3];
	decl Float:vec[3];
	decl Float:angle[3];
	new Float:dis=0.0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
		{
			GetClientEyePosition(i, infectedpos);
			dis=GetVectorDistance(rpos, infectedpos) ;
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %N",dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return i;
				} else CloseHandle(trace);
			}
		}
	}
	
	new iMaxEntities = GetMaxEntities();
	for(new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if(IsCommonInfected(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", infectedpos);
			infectedpos[2]+=40.0;
			dis=GetVectorDistance(rpos, infectedpos) ;
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %N",dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndCI, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return iEntity;
				} else CloseHandle(trace);
			}
		}
	}
	*/
	
	decl Float:infectedpos[3];
	decl Float:vec[3];
	decl Float:angle[3];
	new find=0;
	new Float:mindis=RobotRangeEffect[Client];
	new Float:dis=0.0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerAlive(i))
		{
			GetClientEyePosition(i, infectedpos);
			dis=GetVectorDistance(rpos, infectedpos) ;
			//PrintToChatAll("%f %N" ,dis, i);
			
			if(GetEntProp(i, Prop_Send, "m_zombieClass") == 8 &&
				GetEntProp(i, Prop_Send, "m_isIncapacitated", 1))
				continue;
			
			if(dis<=mindis)
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[Client]);

				if(TR_DidHit(trace))
				{
					
				}
				else
				{
					find=i;
					mindis=dis;
				}
				CloseHandle(trace);
			}
		}
	}

	if(find > 0)
		return find;
	
	new String:classname[64];
	new iMaxEntities = GetMaxEntities();
	for(new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if(!IsValidEdict(iEntity) || GetEntProp(iEntity, Prop_Data, "m_iHealth") <= 0)
			continue;
		
		GetEntityClassname(iEntity, classname, 64);
		if((StrEqual(classname, "infected", false) && !GetEntProp(iEntity, Prop_Send, "m_bIsBurning", 1)) ||
			(StrEqual(classname, "witch", false) && GetEntPropFloat(iEntity, Prop_Send, "m_rage") >= 1.0))
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", infectedpos);
			infectedpos[2]+=40.0;
			dis=GetVectorDistance(rpos, infectedpos) ;
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %N",dis, i);
			if(dis<=mindis)
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndCI, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return iEntity;
				} else CloseHandle(trace);
			}
		}
	}
	
	return find;
}
FireBullet(controller, bot, Float:infectedpos[3], Float:botorigin[3])
{
	decl Float:vAngles[3];
	decl Float:vAngles2[3];
	decl Float:pos[3];
	SubtractVectors(infectedpos, botorigin, infectedpos);
	GetVectorAngles(infectedpos, vAngles);
	new Float:arr1;
	new Float:arr2;
	arr1=0.0-bulletaccuracy[weapontype[controller]];
	arr2=bulletaccuracy[weapontype[controller]];
	decl Float:v1[3];
	decl Float:v2[3];
	//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %f",arr1, arr2);
	for(new c=0; c<weaponbulletpershot[weapontype[controller]];c++)
	{
		//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("fire");
		vAngles2[0]=vAngles[0]+GetRandomFloat(arr1, arr2);
		vAngles2[1]=vAngles[1]+GetRandomFloat(arr1, arr2);
		vAngles2[2]=vAngles[2]+GetRandomFloat(arr1, arr2);
		new hittarget=0;
		new Handle:trace = TR_TraceRayFilterEx(botorigin, vAngles2, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndSurvivor, bot);
		if(TR_DidHit(trace))
		{
			TR_GetEndPosition(pos, trace);
			hittarget=TR_GetEntityIndex( trace);
		}
		CloseHandle(trace);
		if((hittarget>0 && hittarget<=MaxClients) || IsCommonInfected(hittarget) || IsWitch(hittarget))
		{
			/*
			if(IsCommonInfected(hittarget) || IsWitch(hittarget))
				DealDamage(controller, hittarget, RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]/(1.0 + StrEffect[controller] + EnergyEnhanceEffect_Attack[controller])), DMG_BULLET, "robot_attack");
			else
				DealDamage(controller, hittarget, RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]), DMG_BULLET, "robot_attack");
			*/
			
			SDKHooks_TakeDamage(hittarget, 0, controller, weaponbulletdamage[weapontype[controller]] *
				RobotAttackEffect[controller], DMG_BULLET, bot, _, pos);
			
			ShowParticle(pos, PARTICLE_BLOOD, 0.5);
		}
		SubtractVectors(botorigin, pos, v1);
		NormalizeVector(v1, v2);
		ScaleVector(v2, 36.0);
		SubtractVectors(botorigin, v2, infectedorigin);
		decl color[4];
		color[0] = 200;
		color[1] = 200;
		color[2] = 200;
		color[3] = 230;
		new Float:life=0.06;
		new Float:width1=0.01;
		new Float:width2=0.08;
		TE_SetupBeamPoints(infectedorigin, pos, g_BeamSprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
		TE_SendToAll();
		//EmitAmbientSound(SOUND[weapontype[controller]], vOrigin, controller, SNDLEVEL_RAIDSIREN);
		EmitSoundToAll(SOUND[weapontype[controller]], 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, botorigin, NULL_VECTOR, false, 0.0);
	}
}
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	return true;
}

public bool:TraceRayDontHitSelfAndLive(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity))
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndSurvivor(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity) && GetClientTeam(entity)==2)
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndCI(entity, mask, any:data)
{
	new iMaxEntities = GetMaxEntities();
	if(entity == data)
	{
		return false;
	}
	else if(entity>MaxClients && entity<=iMaxEntities)
	{
		return false;
	}
	return true;
}

stock bool:IsCommonInfected(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "infected");
	}
	return false;
}

stock bool:IsWitch(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "witch");
	}
	return false;
}

stock ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

stock AttachParticle(ent, String:particleType[], Float:time)
{
	decl String:tName[64];
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle) && IsValidEdict(ent))
	{
		new Float:pos[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName); 
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString(tName);
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
    if(IsValidEdict(particle) && IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

stock PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}
}
