/*******************************************************
*
* 		L4D2: Lethal Weapon v2.1
*
* 		      Author: ztar
* 		   Edited: M249-M4A1
* http://forums.alliedmods.net/showthread.php?p=1121995
*
********************************************************
* CHANGELOG:
*
* - Added several ConVars to customize effects
*   - Enable/disable sounds
*   - Enable/disable use of extra ammo
*   - Enable/disable some effects (to be discreet)
*   - Enable/disable charging while crouched and moving
*
* - Renamed ConVars and CFG to be more uniform
* - Fixed some grammar and spelling issues
* - Removed text gauge as it was kinda annoying
* - Made it easier to change sounds (#define)
* - Updated some sounds
* - Fixed bug where Survivors would be launched away
*   and killed unless "l4d2_lw_ff" is enabled
* - Fixed bug where if you were limited to 1 lethal
*   charged shot, you fired, then the limit was
*   removed, you wouldn't be able to charge again
* - Added screen shake
*
*******************************************************/
#include <sourcemod>
#include <sdktools>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION "2.1"
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define MOLOTOV 0
#define EXPLODE 1

new ChargeLock[65];
new ReleaseLock[65];
new CurrentWeapon;
new ClipSize;
new ChargeEndTime[65];
new Handle:ClientTimer[65];
new g_sprite;
new Float:myPos[3], Float:trsPos[3], Float:trsPos002[3];

/* Sound */
#define CHARGESOUND 	"ambient/spacial_loops/lights_flicker.wav"
#define CHARGEDUPSOUND	"level/startwam.wav"
#define AWPSHOT			"weapons/awp/gunfire/awp1.wav"
#define EXPLOSIONSOUND	"animation/bombing_run_01.wav"

/* Sprite */
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"

new Handle:l4d2_lw_lethalweapon		= INVALID_HANDLE;
new Handle:l4d2_lw_lethaldamage		= INVALID_HANDLE;
new Handle:l4d2_lw_lethalforce		= INVALID_HANDLE;
new Handle:l4d2_lw_chargetime		= INVALID_HANDLE;
new Handle:l4d2_lw_shootonce		= INVALID_HANDLE;
new Handle:l4d2_lw_ff				= INVALID_HANDLE;
new Handle:l4d2_lw_scout			= INVALID_HANDLE;
new Handle:l4d2_lw_awp				= INVALID_HANDLE;
new Handle:l4d2_lw_huntingrifle		= INVALID_HANDLE;
new Handle:l4d2_lw_g3sg1			= INVALID_HANDLE;
new Handle:l4d2_lw_flash			= INVALID_HANDLE;
new Handle:l4d2_lw_chargingsound	= INVALID_HANDLE;
new Handle:l4d2_lw_chargedsound		= INVALID_HANDLE;
new Handle:l4d2_lw_moveandcharge	= INVALID_HANDLE;
new Handle:l4d2_lw_chargeparticle	= INVALID_HANDLE;
new Handle:l4d2_lw_useammo			= INVALID_HANDLE;
new Handle:l4d2_lw_shake			= INVALID_HANDLE;
new Handle:l4d2_lw_shake_intensity	= INVALID_HANDLE;
new Handle:l4d2_lw_shake_shooteronly= INVALID_HANDLE;
new Handle:l4d2_lw_laseroffset		= INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "狙击枪大炮",
	author = "ztar, fix dmg by raziEiL[disawar], Fixed ParticleRemoval[Ludastar]",
	description = "Sniper rifles can be charged up and fired to create a huge explosion",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1121995"
}

public OnPluginStart()
{
	// ConVars
	l4d2_lw_lethalweapon	= CreateConVar("l4d2_lw_lethalweapon","1", "是否开启狙击炮.0=关闭.1=开启.2=开启精简版", CVAR_FLAGS);
	l4d2_lw_lethaldamage	= CreateConVar("l4d2_lw_lethaldamage","3000.0", "狙击炮伤害", CVAR_FLAGS);
	l4d2_lw_lethalforce		= CreateConVar("l4d2_lw_lethalforce","500.0", "狙击炮推力", CVAR_FLAGS);
	l4d2_lw_chargetime		= CreateConVar("l4d2_lw_chargetime","7", "狙击炮充能时间", CVAR_FLAGS);
	l4d2_lw_shootonce		= CreateConVar("l4d2_lw_shootonce","0", "狙击炮回合限制多少次", CVAR_FLAGS);
	l4d2_lw_ff				= CreateConVar("l4d2_lw_ff","0", "狙击炮有队友伤害", CVAR_FLAGS);
	l4d2_lw_scout			= CreateConVar("l4d2_lw_scout","1", "可以用 Scout 发射", CVAR_FLAGS);
	l4d2_lw_awp				= CreateConVar("l4d2_lw_awp","1", "可以用 AWP 发射", CVAR_FLAGS);
	l4d2_lw_huntingrifle	= CreateConVar("l4d2_lw_huntingrifle","1", "可以用 15发猎枪 发射", CVAR_FLAGS);
	l4d2_lw_g3sg1			= CreateConVar("l4d2_lw_g3sg1","1", "可以用 30发连狙 发射", CVAR_FLAGS);
	l4d2_lw_laseroffset		= CreateConVar("l4d2_lw_laseroffset", "36", "激光偏移", FCVAR_NOTIFY);
	
	// Additional ConVars
	l4d2_lw_flash				= CreateConVar("l4d2_lw_flash", "1", "是否开启闪光");
	l4d2_lw_chargingsound		= CreateConVar("l4d2_lw_chargingsound", "1", "充能是否有声音");
	l4d2_lw_chargedsound		= CreateConVar("l4d2_lw_chargedsound", "1", "充能完毕是否有声音");
	l4d2_lw_moveandcharge		= CreateConVar("l4d2_lw_moveandcharge", "1", "充能时是否允许移动");
	l4d2_lw_chargeparticle		= CreateConVar("l4d2_lw_chargeparticle", "1", "充能时是否有粒子效果");
	l4d2_lw_useammo				= CreateConVar("l4d2_lw_useammo", "1", "使用狙击炮需要消耗额外弹药");
	l4d2_lw_shake				= CreateConVar("l4d2_lw_shake", "1", "狙击炮爆炸会有屏幕晃动效果");
	l4d2_lw_shake_intensity		= CreateConVar("l4d2_lw_shake_intensity", "50.0", "屏幕晃动效果强度");
	l4d2_lw_shake_shooteronly	= CreateConVar("l4d2_lw_shake_shooteronly", "0", "只有发射者才会屏幕晃动");
	
	// Hooks
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("weapon_fire", Event_Weapon_Fire);
	HookEvent("bullet_impact", Event_Bullet_Impact);
	HookEvent("player_incapacitated", Event_Player_Incap, EventHookMode_Pre);
	HookEvent("player_hurt", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("player_death", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("infected_death", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("infected_hurt", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("round_end", Event_Round_End, EventHookMode_Pre);
	
	// Weapon stuff
	CurrentWeapon	= FindSendPropOffs ("CTerrorPlayer", "m_hActiveWeapon");
	ClipSize	= FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	
	InitCharge();
	CreateTimer(1.0, Timer_SetupSkill);
	
	AutoExecConfig(true, "l4d2_lethal_weapon");
}

public Action Timer_SetupSkill(Handle timer, any unused)
{
	SC_CreateSkill("lw_lethalweapon", "狙击枪大炮", 0, "手持狙击枪蹲下充能发射大炮");
	return Plugin_Continue;
}

public OnMapStart()
{
	InitPrecache();
}

public OnConfigsExecuted()
{
	InitPrecache();
}

InitCharge()
{
	/* Initalize charge parameter */
	new i;
	for (i = 1; i <= GetMaxClients(); i++)
	{
		ChargeEndTime[i] = 0;
		ReleaseLock[i] = 0;
		ChargeLock[i] = 0;
		ClientTimer[i] = INVALID_HANDLE;
	}
	for (i = 1; i <= GetMaxClients(); i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2)
				ClientTimer[i] = CreateTimer(0.5, ChargeTimer, i, TIMER_REPEAT);
		}
	}
}

InitPrecache()
{
	/* Precache models */
	PrecacheModel("models/props_junk/propanecanister001a.mdl", true);
	PrecacheModel("models/props_junk/gascan001a.mdl", true);
	
	/* Precache sounds */
	PrecacheSound(CHARGESOUND, true);
	PrecacheSound(CHARGEDUPSOUND, true);
	PrecacheSound(AWPSHOT, true);
	PrecacheSound(EXPLOSIONSOUND, true);
	
	/* Precache particles */
	PrecacheParticle("gas_explosion_main");
	PrecacheParticle("electrical_arc_01_cp0");
	PrecacheParticle("electrical_arc_01_system");
	
	g_sprite = PrecacheModel(SPRITE_BEAM);
}

public Action:Event_Round_End(Handle:event, String:event_name[], bool:dontBroadcast)
{
	/* Timer end */
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (ClientTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(ClientTimer[i]);
			ClientTimer[i] = INVALID_HANDLE;
		}
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			ChargeEndTime[i] = 0;
			ReleaseLock[i] = 0;
			ChargeLock[i] = 0;
		}
	}
}

public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Timer start */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client > 0 && client <= GetMaxClients())
	{
		if (IsValidEntity(client) && IsClientInGame(client))
		{
			if (GetClientTeam(client) == 2)
			{
				if (ClientTimer[client] != INVALID_HANDLE)
					CloseHandle(ClientTimer[client]);
				ChargeLock[client] = 0;
				ClientTimer[client] = CreateTimer(0.5, ChargeTimer, client, TIMER_REPEAT);
			}
		}
	}
}

public Action:Event_Player_Incap(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Reset client condition */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ReleaseLock[client] = 0;
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_lw_chargetime);
}

public Action:Event_Bullet_Impact(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (ReleaseLock[client])
	{
		decl Float:TargetPosition[3];
		
		TargetPosition[0] = GetEventFloat(event,"x");
		TargetPosition[1] = GetEventFloat(event,"y");
		TargetPosition[2] = GetEventFloat(event,"z");
		
		/* Explode effect */
		ExplodeMain(TargetPosition);
	}
	return Plugin_Continue;
}

public Action:Event_Infected_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (ReleaseLock[client])
	{
		decl Float:TargetPosition[3];
		new target = GetClientAimTarget(client, false);
		if (target < 0)
			return Plugin_Continue;
		GetEntityAbsOrigin(target, TargetPosition);
		
		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
		
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;
	}
	return Plugin_Continue;
}

public Action:Event_Player_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	new dtype = GetEventInt(event, "type");
	
	if (client && target && ReleaseLock[client] && dtype != 268435464)
	{	
		decl Float:AttackPosition[3];
		decl Float:TargetPosition[3];
		GetClientAbsOrigin(client, AttackPosition);
		GetClientAbsOrigin(target, TargetPosition);
		
		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
		
		/* Smash target */
		if (GetConVarInt(l4d2_lw_lethalweapon) != 2)
			Smash(client, target, GetConVarFloat(l4d2_lw_lethalforce), 1.5, 2.0);
		
		/* Deal lethal damage */
		if ((GetClientTeam(client) != GetClientTeam(target)) || GetConVarInt(l4d2_lw_ff))
			CreateTimer(0.01, dmg, target)
		
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;
	}
	return Plugin_Continue;
}

public Action:dmg(Handle:timer, any:target)
{
	if (IsClientInGame(target) && IsPlayerAlive(target)){
		new health = GetClientHealth(target)
		new damage = GetConVarInt(l4d2_lw_lethaldamage);
		SetEntProp(target, Prop_Data, "m_iHealth", health - damage);
	}
}

public Action:Event_Weapon_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_lw_chargetime);
	
	if (ReleaseLock[client])
	{
		/* Flash screen */
		if (GetConVarInt(l4d2_lw_flash))
		{
			ScreenFade(client, 200, 200, 255, 255, 100, 1);
		}

		if (GetConVarInt(l4d2_lw_shake))
		{
			ScreenShake(client);
		}
		
		/* Laser effect */
		GetTracePosition(client);
		CreateLaserEffect(client, 0, 0, 200, 230, 2.0, 1.00);
		
		/* Emit sound */
		EmitSoundToAll(
			AWPSHOT, client,
			SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL,
			125, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		
		/* Reset client condition */
		CreateTimer(0.2, ReleaseTimer, client);
		
		new maxCount = GetConVarInt(l4d2_lw_shootonce);
		if (maxCount > 0)
		{
			ChargeLock[client] += 1;
			
			new count = maxCount - ChargeLock[client];
			if(count > 0)
				PrintHintText(client, "狙击炮剩余 %d 次", count);
			else
				PrintHintText(client, "狙击炮次数消耗完毕");
		}
		else
		{
			// Enable shooting more than once per round again
			ChargeLock[client] = 0;
		}
	}
}

public Action:ReleaseTimer(Handle:timer, any:client)
{
	/* Set ammo after using */
	if (GetConVarInt(l4d2_lw_useammo))
	{
		new Weapon = GetEntDataEnt2(client, CurrentWeapon);
		new iAmmo = FindDataMapOffs(client,"m_iAmmo");
		SetEntData(Weapon, ClipSize, 0);
		SetEntData(client, iAmmo+8,  RoundToFloor(GetEntData(client, iAmmo+8)  / 2.0));
		SetEntData(client, iAmmo+36, RoundToFloor(GetEntData(client, iAmmo+36) / 2.0));
		SetEntData(client, iAmmo+40, RoundToFloor(GetEntData(client, iAmmo+40) / 2.0));
	}

	/* Reset flags */
	ReleaseLock[client] = 0;
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_lw_chargetime);
}

public Action:ChargeTimer(Handle:timer, any:client)
{
	// Make sure we remove the lock if this ConVar is later disabled
	new maxCount = GetConVarInt(l4d2_lw_shootonce);
	if (maxCount < 1)
	{
		ChargeLock[client] = 0;
	}

	StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
	if (!GetConVarInt(l4d2_lw_lethalweapon) || ChargeLock[client] > maxCount ||
		!SC_IsClientHaveSkill(client, "lw_lethalweapon"))
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsValidEntity(client) || !IsClientInGame(client))
	{
		ClientTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	/* Get data */
	new gt = RoundToCeil(GetGameTime());
	new ct = GetConVarInt(l4d2_lw_chargetime);
	new buttons = GetClientButtons(client);
	new WeaponClass = GetEntDataEnt2(client, CurrentWeapon);
	new String:weapon[32];
	GetClientWeapon(client, weapon, 32);
	
	/* These weapons allow you to start charging */
	/* Now allowed: Hunting Rifle, G3SG1, Scout, AWP */
	if (!(StrEqual(weapon, "weapon_sniper_military") && GetConVarInt(l4d2_lw_g3sg1)) &&
		!(StrEqual(weapon, "weapon_sniper_awp") && GetConVarInt(l4d2_lw_awp)) &&
		!(StrEqual(weapon, "weapon_sniper_scout") && GetConVarInt(l4d2_lw_scout)) &&
		!(StrEqual(weapon, "weapon_hunting_rifle") && GetConVarInt(l4d2_lw_huntingrifle)))
	{
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
		return Plugin_Continue;
	}

	// Base case to be overridden, just in case someone messes with the ConVar
	new inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
	
        if (GetConVarInt(l4d2_lw_moveandcharge) < 1)
        {
		/* Ducked, not moving, not attacking, not incapaciated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_FORWARD) &&
					!(buttons & IN_MOVERIGHT) &&
					!(buttons & IN_MOVELEFT) &&
					!(buttons & IN_BACK) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
        else
        {
		/* Ducked, moving, not attacking, not incapaciated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
	
	/* If in charging, display charge bar */
	if (inCharge && GetEntData(WeaponClass, ClipSize))
	{
		if (ChargeEndTime[client] < gt)
		{
			/* Charge end, ready to fire */
			PrintCenterText(client, "***************** 充能中 *****************");
			if (ReleaseLock[client] != 1)
			{
				decl Float:pos[3];
				GetClientAbsOrigin(client, pos);
				if (GetConVarInt(l4d2_lw_chargedsound))
				{
					EmitSoundToAll(CHARGEDUPSOUND, client);
				}
				if (GetConVarInt(l4d2_lw_chargeparticle))
				{
					ShowParticle(pos, "electrical_arc_01_system", 5.0);
				}
			}
			ReleaseLock[client] = 1;
		}
		else
		{
			/* Not charged yet. Display charge gauge */
			new i, j;
			new String:ChargeBar[50];
			new String:Gauge1[2] = "|";
			new String:Gauge2[2] = " ";
			new Float:GaugeNum = (float(ct) - (float(ChargeEndTime[client] - gt))) * (100.0/float(ct))/2.0;
			ReleaseLock[client] = 0;
			if(GaugeNum > 50.0)
				GaugeNum = 50.0;
			
			for(i=0; i<GaugeNum; i++)
				ChargeBar[i] = Gauge1[0];
			for(j=i; j<50; j++)
				ChargeBar[j] = Gauge2[0];
			if (GaugeNum >= 15)
			{
				/* Gauge meter is 30% or more */
				decl Float:pos[3];
				GetClientAbsOrigin(client, pos);
				pos[2] += 45;
				if (GetConVarInt(l4d2_lw_chargeparticle))
				{
					ShowParticle(pos, "electrical_arc_01_cp0", 5.0);
				}
				if (GetConVarInt(l4d2_lw_chargingsound))
				{
					EmitSoundToAll(CHARGESOUND, client);
				}
			}
			/* Display gauge */
			PrintCenterText(client, "           << 充能进度 >>\n0%% %s %3.0f%%", ChargeBar, GaugeNum*2);
		}
	}
	else
	{
		/* Not matching condition */
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
	}
	return Plugin_Continue;
}

public ExplodeMain(Float:pos[3])
{
	/* Main effect when hit */
	if (GetConVarInt(l4d2_lw_chargeparticle))
	{
		ShowParticle(pos, "electrical_arc_01_system", 5.0);
	}
	LittleFlower(pos, EXPLODE);
	
	if (GetConVarInt(l4d2_lw_lethalweapon) == 1)
	{
		ShowParticle(pos, "gas_explosion_main", 5.0);
		LittleFlower(pos, MOLOTOV);
	}
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle) || IsValidEdict(particle))
	{
		decl String:sBuffer[32];
		sBuffer[0] = 0;
		
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		
		Format(sBuffer, sizeof(sBuffer), "OnUser1 !self:Kill::%f:-1", time);
		SetVariantString(sBuffer);
		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");
	}  
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle) || IsValidEdict(particle))
	{		
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		SetVariantString("OnUser1 !self:Kill::0.01:-1");
		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");
	}  
}

public LittleFlower(Float:pos[3], type)
{
	/* Cause fire(type=0) or explosion(type=1) */
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
		else
			/* explode */
			DispatchKeyValue(entity, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

public Action:GetEntityAbsOrigin(entity,Float:origin[3])
{
	/* Get target posision */
	decl Float:mins[3], Float:maxs[3];
	GetEntPropVector(entity,Prop_Send,"m_vecOrigin",origin);
	GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
	GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
	
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
}

Smash(client, target, Float:power, Float:powHor, Float:powVec)
{
	/* Smash target */
	// Check so that we don't "smash" other Survivors (only if "l4d2_lw_ff" is 0)
	if (GetConVarInt(l4d2_lw_ff) || GetClientTeam(target) != 2)
	{
		decl Float:HeadingVector[3], Float:AimVector[3];
		GetClientEyeAngles(client, HeadingVector);
	
		AimVector[0] = FloatMul(Cosine(DegToRad(HeadingVector[1])) ,power * powHor);
		AimVector[1] = FloatMul(Sine(DegToRad(HeadingVector[1])) ,power * powHor);
	
		decl Float:current[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", current);
	
		decl Float:resulting[3];
		resulting[0] = FloatAdd(current[0], AimVector[0]);	
		resulting[1] = FloatAdd(current[1], AimVector[1]);
		resulting[2] = power * powVec;
	
		TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, resulting);
	}
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	new Handle:msg = StartMessageOne("Fade", target);
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
	{
		BfWriteShort(msg, (0x0002 | 0x0008));
	}
	else
	{
		BfWriteShort(msg, (0x0001 | 0x0010));
	}
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public ScreenShake(target)
{
	new Handle:msg;
	if (GetConVarInt(l4d2_lw_shake_shooteronly))
	{
		msg = StartMessageAll("Shake");
	}
	else
	{
		msg = StartMessageOne("Shake", target);
	}
	BfWriteByte(msg, 0);
 	BfWriteFloat(msg, GetConVarFloat(l4d2_lw_shake_intensity));
 	BfWriteFloat(msg, 10.0);
 	BfWriteFloat(msg, 3.0);
	EndMessage();
}

public GetTracePosition(client)
{
	decl Float:myAng[3];
	GetClientEyePosition(client, myPos);
	GetClientEyeAngles(client, myAng);
	new Handle:trace = TR_TraceRayFilterEx(myPos, myAng, CONTENTS_SOLID|CONTENTS_MOVEABLE, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(trsPos, trace);
	CloseHandle(trace);
	for(new i = 0; i < 3; i++)
		trsPos002[i] = trsPos[i];
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > GetMaxClients() || !entity;
}

public CreateLaserEffect(client, colRed, colGre, colBlu, alpha, Float:width, Float:duration)
{
	decl Float:tmpVec[3];
	SubtractVectors(myPos, trsPos, tmpVec);
	NormalizeVector(tmpVec, tmpVec);
	ScaleVector(tmpVec, GetConVarFloat(l4d2_lw_laseroffset));
	SubtractVectors(myPos, tmpVec, trsPos);
	
	decl color[4];
	color[0] = colRed; 
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;
	TE_SetupBeamPoints(myPos, trsPos002, g_sprite, 0, 0, 0, duration, width, width, 1, 0.0, color, 0);
	TE_SendToAll();
}
