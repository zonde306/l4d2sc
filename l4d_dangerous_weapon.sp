#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
 
#define SOUND_FLAME		"weapons/molotov/fire_loop_1.wav"
 
#define Pai 3.14159265358979323846 
#define Particle_jet_01_flame "fire_jet_01_flame" 
#define Particle_gas_explosion_pump "gas_explosion_pump"
#define Particle_gas_explosion_main "gas_explosion_main"
#define Particle_st_elmos_fire "st_elmos_fire"
#define Particle_electrical_arc_01_system "electrical_arc_01_system"

#define MODEL_MISSILE "models/w_models/weapons/w_HE_grenade.mdl"
#define MODEL_W_PIPEBOMB "models/w_models/weapons/w_eq_pipebomb.mdl"

#define Type_Pistol	5
#define Type_Rifle	1
#define Type_Shotgun 2
#define Type_Sniper	3
#define Type_Smg	4

#define GetClassName

#define g_iBlockDamage

new ZOMBIECLASS_TANK=	5; 

new Bullet[MAXPLAYERS+1];

new Cannon[MAXPLAYERS+1];
new Flame[MAXPLAYERS+1][3];
new Float:FlameDamage[MAXPLAYERS+1];
new Float:FlameLength[MAXPLAYERS+1];
new Float:FlameTick[MAXPLAYERS+1];
new Float:LastTime[MAXPLAYERS+1];
new Float:FlameStartTime[MAXPLAYERS+1];
new ShowMsg[MAXPLAYERS+1]; 
new Float:ShotTime[MAXPLAYERS+1]; 
new GameMode;
new L4D2Version;
new g_sprite;

public Plugin:myinfo = 
{
	name = "Dangerous Weapons",
	author = "Pan Xiaohai",
	description = "",
	version = "1.1",	
}
new Handle:l4d_dangerous_enable;
new Handle:l4d_dangerous_message;
new Handle:l4d_dangerous_safe;
new Handle:l4d_dangerous_particle;
new Handle:l4d_dangerous_power[6];

new Handle:l4d_dangerous_drop_ci;
new Handle:l4d_dangerous_drop_si;
 
new Handle:l4d_dangerous_damage_hit;
new Handle:l4d_dangerous_damage_explode;
new Handle:l4d_dangerous_damage_radius;
new Handle:l4d_dangerous_drop_pickupcount;
new Handle:l4d_dangerous_cannon_catchfire;

new Handle:l4d_dangerous_flame_damage;
new Handle:l4d_dangerous_flame_length;
new Handle:l4d_dangerous_flame_duration;

new Handle:l4d_dangerous_pickup_mode;

new Handle:l4d_dangerous_mode_cannon;
new Handle:l4d_dangerous_mode_electromagnetic;
new Handle:l4d_dangerous_mode_flamethrower;

public OnPluginStart()
{
	GameCheck(); 	
 	l4d_dangerous_enable = CreateConVar("l4d_dangerous_enable", "1", "  0:disable, 1:enable in coop mode, 2: enable in all mode ", FCVAR_NOTIFY);
 	l4d_dangerous_message=CreateConVar("l4d_dangerous_message", "3", "how many times to display usage information ,0 disable  ", FCVAR_NOTIFY);	
 	l4d_dangerous_safe=CreateConVar("l4d_dangerous_safe", "1", "1:more safe to use", FCVAR_NOTIFY);

	l4d_dangerous_power[Type_Rifle] = CreateConVar("l4d_dangerous_power_rifle", "1.1", "power of rifle 0.0: disable [0.0, 3.0]", FCVAR_NOTIFY);
	l4d_dangerous_power[Type_Sniper] = CreateConVar("l4d_dangerous_power_sniper", "1.8", " ", FCVAR_NOTIFY);
	l4d_dangerous_power[Type_Shotgun] = CreateConVar("l4d_dangerous_power_shotgun", "0.8", " ", FCVAR_NOTIFY);
	l4d_dangerous_power[Type_Pistol]  = CreateConVar("l4d_dangerous_power_magnum", "1.5", " ", FCVAR_NOTIFY);	
	l4d_dangerous_power[Type_Smg]  = CreateConVar("l4d_dangerous_power_smg", "0.5", "", FCVAR_NOTIFY);	

	l4d_dangerous_drop_ci  = CreateConVar("l4d_dangerous_drop_ci", "10.0", "drop chance for common infected", FCVAR_NOTIFY);	
	l4d_dangerous_drop_si  = CreateConVar("l4d_dangerous_drop_si", "30.0", "drop chance for special infected", FCVAR_NOTIFY);
	l4d_dangerous_drop_pickupcount  = CreateConVar("l4d_dangerous_drop_pickupcount", "5", "bullet count for every pick up", FCVAR_NOTIFY);
	
	l4d_dangerous_damage_hit  = CreateConVar("l4d_dangerous_damage_hit", "300.0", "direct hit damage", FCVAR_NOTIFY);	
	l4d_dangerous_damage_explode  = CreateConVar("l4d_dangerous_damage_explode", "300.0", "explode damage", FCVAR_NOTIFY);
	l4d_dangerous_damage_radius  = CreateConVar("l4d_dangerous_damage_radius", "10.0", "explode radius", FCVAR_NOTIFY);
	l4d_dangerous_particle  = CreateConVar("l4d_dangerous_particle", "1", "1:show particle , 0: disable", FCVAR_NOTIFY);
	l4d_dangerous_cannon_catchfire  = CreateConVar("l4d_dangerous_cannon_catchfire", "0", "1:firing cannon, 0: disable", FCVAR_NOTIFY);

	l4d_dangerous_flame_damage  = CreateConVar("l4d_dangerous_flame_damage", "20.0", "flame damage", FCVAR_NOTIFY);	
	l4d_dangerous_flame_length  = CreateConVar("l4d_dangerous_flame_length", "200.0", "flame length", FCVAR_NOTIFY);	
	l4d_dangerous_flame_duration  = CreateConVar("l4d_dangerous_flame_duration", "5.0", "flame duration", FCVAR_NOTIFY);
	
	l4d_dangerous_pickup_mode  = CreateConVar("l4d_dangerous_pickup_mode", "1", "1: pick up mode (l4d2) 2:direct give mode", FCVAR_NOTIFY);	

	l4d_dangerous_mode_cannon  = CreateConVar("l4d_dangerous_mode_cannon", "1", "1: enable Mini Cannon, 0: disable", FCVAR_NOTIFY);	
	l4d_dangerous_mode_electromagnetic  = CreateConVar("l4d_dangerous_mode_electromagnetic", "1", "1: enable Electromagnetic Cannon, 0: disable", FCVAR_NOTIFY);	
	l4d_dangerous_mode_flamethrower  = CreateConVar("l4d_dangerous_mode_flamethrower", "1", "1: enable Flamethrower, 0: disable", FCVAR_NOTIFY);	

	AutoExecConfig(true, "l4d_dangerous_weapon");   
	
	HookEvent("player_death", player_death); 
	HookEvent("weapon_fire", weapon_fire);
	if(!L4D2Version)HookEvent("grenade_bounce", grenade_bounce); 
	
	HookEvent("round_start", round_end);
	HookEvent("round_end", round_end);
	HookEvent("finale_win", round_end);
	HookEvent("mission_lost", round_end);
	HookEvent("map_transition", round_end);
 	
	ResetAllState();
}
ResetAllState()
{
	for(new i=1; i<=MaxClients; i++)
	{
		ShowMsg[i]=0;
		ShotTime[i]=0.0;
		Bullet[i]=0;
		Cannon[i]=0;
		Flame[i][0]=Flame[i][1]=Flame[i][2]=0;
		FlameStartTime[i]=0.0;
		 
		SDKUnhook(i, SDKHook_PreThink,  PreThinkFlame);  
	}
}
StartElec(client, type)
{
	new Float:pos[3];
	new Float:angle[3];
	new Float:hitpos[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client , angle);	 
	new victim=GetEnt(client, hitpos ,MASK_SHOT); 
	if(victim==-1)return;
	new Float:distance=GetVectorDistance(pos, hitpos);
	if(GetConVarInt(l4d_dangerous_safe)==1 && distance<GetConVarFloat(l4d_dangerous_damage_radius)*GetConVarFloat(l4d_dangerous_power[type]))
	{
		PrintHintText(client, "It is too dangerous to shoot");
		return;
	}
	CreateElec(client, pos, hitpos, angle); 
	 
	if(victim>0)
	{ 
		DoPointHurtForInfected(victim, client, GetConVarFloat(l4d_dangerous_damage_hit)*GetConVarFloat(l4d_dangerous_power[type]));
	} 
	new Handle:h=CreateDataPack();

	WritePackCell(h, type);
	WritePackFloat(h, hitpos[0]);
	WritePackFloat(h, hitpos[1]);
	WritePackFloat(h, hitpos[2]);
	CreateTimer(0.2, DelayExplode, h);
	Bullet[client]--;
	PrintHintText(client, "Special Bullet Remain: %d", Bullet[client] );
}
public Action:DelayExplode(Handle:timer, Handle:h)
{
	ResetPack(h);
 	new Float:pos[3];
	new type=ReadPackCell(h);
	pos[0]=ReadPackFloat(h);
	pos[1]=ReadPackFloat(h);
	pos[2]=ReadPackFloat(h);	
	CloseHandle(h);
	Explode(pos, type);
}
 
GetEnt(client,  Float:hitpos[3],  flag,Float:offset=-50.0)
{
	new Float:pos[3];
	new Float:angle[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client , angle);
	new Handle:trace=TR_TraceRayFilterEx(pos, angle, flag, RayType_Infinite, TraceRayDontHitSelf, client); 
	new ent=-1; 
	if(TR_DidHit(trace))
	{		 
		TR_GetEndPosition(hitpos, trace);
		ent=TR_GetEntityIndex(trace); 
		decl Float:vec[3];
		GetAngleVectors(angle, vec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vec, vec);
		ScaleVector(vec,  offset);
		AddVectors(hitpos, vec, hitpos);
	}
	CloseHandle(trace);  
	return ent;
}
GetEnt2(client, Float:pos[3], Float:angle[3], Float:hitpos[3],  flag ,Float:offset=-50.0)
{
 
	new Handle:trace=TR_TraceRayFilterEx(pos, angle, flag, RayType_Infinite, TraceRayDontHitSelf, client); 
	new ent=-1; 
	if(TR_DidHit(trace))
	{		 
		TR_GetEndPosition(hitpos, trace);
		ent=TR_GetEntityIndex(trace); 
		decl Float:vec[3];
		GetAngleVectors(angle, vec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vec, vec);
		ScaleVector(vec,  offset);
		AddVectors(hitpos, vec, hitpos);
	}
	CloseHandle(trace);  
	return ent;
}
StartFlame(client, type)
{ 
	StopFlame(client);
	FlameStartTime[client]=GetEngineTime();
	FlameTick[client]=0.0;
 	FlameDamage[client]= GetConVarFloat(l4d_dangerous_flame_damage) * GetConVarFloat(l4d_dangerous_power[type]);	
	FlameLength[client]= GetConVarFloat(l4d_dangerous_flame_length) * GetConVarFloat(l4d_dangerous_power[type]);	

	decl String:tName[32];

	Format(tName, sizeof(tName), "target%d", client);
	DispatchKeyValue(client, "targetname", tName);
	 
	new flame = CreateEntityByName("env_steam");			
	DispatchKeyValue(flame, "parentname", tName);
	DispatchKeyValue(flame,"SpawnFlags", "1");
	DispatchKeyValue(flame,"Type", "0");		 
	DispatchKeyValue(flame,"InitialState", "1");
	DispatchKeyValue(flame,"Spreadspeed", "10");  
	DispatchKeyValue(flame,"Speed", "1000");
	DispatchKeyValue(flame,"Startsize", "4");
	DispatchKeyValue(flame,"EndSize", "100");
	DispatchKeyValue(flame,"Rate", "20");
	DispatchKeyValue(flame,"RenderColor", "255 0 0");

	decl String:strFlameLength[32];
	IntToString(RoundFloat(FlameLength[client]), strFlameLength, 32);
	DispatchKeyValue(flame,"JetLength", strFlameLength); 
	DispatchKeyValue(flame,"RenderAmt", "180");
	DispatchSpawn(flame);


	SetVariantString(tName);
	AcceptEntityInput(flame, "SetParent", flame, flame, 0);
	SetVariantString("forward");
	AcceptEntityInput(flame, "SetParentAttachment", flame, flame, 0);
	AcceptEntityInput(flame, "TurnOn");

	new Float:pos[3];
	new Float:ang[3]; 	
	SetVector(pos,  22.0, 0.0, -15.0);	
	SetVector(ang, -3.0, 8.0,0.0);	
	TeleportEntity(flame, pos, ang, NULL_VECTOR);


	new flame2 = CreateEntityByName("env_steam");
	DispatchKeyValue(flame2, "parentname", tName);
	DispatchKeyValue(flame2,"SpawnFlags", "1");
	DispatchKeyValue(flame2,"Type", "0");		 
	DispatchKeyValue(flame2,"InitialState", "1");
	DispatchKeyValue(flame2,"Spreadspeed", "10"); 
	DispatchKeyValue(flame2,"Speed", "1000");
	DispatchKeyValue(flame2,"Startsize", "10");
	DispatchKeyValue(flame2,"EndSize", "140");
	DispatchKeyValue(flame2,"Rate", "95");
	DispatchKeyValue(flame2,"RenderColor", "16 85 160");

	DispatchKeyValue(flame2,"JetLength", strFlameLength); 
	DispatchKeyValue(flame2,"RenderAmt", "180");
	DispatchSpawn(flame2); 

	SetVariantString(tName);
	AcceptEntityInput(flame2, "SetParent", flame2, flame2, 0);
	SetVariantString("forward");
	AcceptEntityInput(flame2, "SetParentAttachment", flame2, flame2, 0);
	AcceptEntityInput(flame2, "TurnOn");	 

	TeleportEntity(flame2, pos, ang, NULL_VECTOR);

	Flame[client][0]=flame;
	Flame[client][1]=flame2;
	
	EmitSoundToAll(SOUND_FLAME, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	SDKUnhook(client, SDKHook_PreThink,  PreThinkFlame);  
	SDKHook(client, SDKHook_PreThink,  PreThinkFlame);  
	Bullet[client]--;
	PrintHintText(client, "Special Bullet Remain: %d", Bullet[client] );
}
StopFlame(client)
{  
	if(client==0)return;
	SDKUnhook(client, SDKHook_PreThink,  PreThinkFlame);  
	StopSound(client, SNDCHAN_AUTO, SOUND_FLAME);
	if(IsValidEntS(Flame[client][0], "env_steam"))
	{
		AcceptEntityInput(Flame[client][0], "ClearParent");
		AcceptEntityInput(Flame[client][0], "TurnOff");
		AcceptEntityInput(Flame[client][0], "kill");
		 
	}
	if(IsValidEntS(Flame[client][1], "env_steam"))
	{
		AcceptEntityInput(Flame[client][1], "ClearParent");
		AcceptEntityInput(Flame[client][1], "TurnOff");
		AcceptEntityInput(Flame[client][1], "kill");
	}
	Flame[client][0]=Flame[client][1]=0;
 
}
bool:IsValidEntS(ent, String:classname[64])
{
	if(IsValidEnt(ent))
	{ 
		decl String:name[64]; 
		GetEdictClassname(ent, name, 64); 
		if(StrEqual(classname, name) )
		{
			return true;
		}
	}
	return false;
}
bool:IsValidEnt(ent)
{
	if(ent>0 && IsValidEdict(ent) && IsValidEntity(ent))
	{
		return true;		 
	}
	return false;
}
new Float:g_flame_radius=50.0;
public PreThinkFlame(client)
{
 
	if(client>0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		new Float:time=GetEngineTime();
		new button=GetClientButtons(client);
		if(FlameStartTime[client]+GetConVarFloat(l4d_dangerous_flame_duration)<time )
		{
			StopFlame(client);
			return;
		}
		decl Float:eyepos[3];
		decl Float:startpos[3];
		decl Float:endpos[3];
		decl Float:angle[3];
		decl Float:dir[3];
		decl Float:temp[3];
		GetClientEyePosition(client, eyepos);
		GetClientEyeAngles(client, angle);	 
		GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(dir, dir);
		CopyVector(dir, temp);
		ScaleVector(temp, g_flame_radius/2.0+20.0);
		AddVectors(eyepos, temp, startpos);
		
		CopyVector(dir, temp);
		ScaleVector(temp, FlameLength[client]);
		AddVectors(startpos, temp, endpos);
		
		
		new Handle:trace = TR_TraceRayFilterEx(startpos, endpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitLive, client);
		if(TR_DidHit(trace))
		{		 
			TR_GetEndPosition(endpos, trace);  
		}
		CloseHandle(trace); 
		new Float:len=GetVectorDistance(endpos, startpos);
		if(FlameTick[client]>len)FlameTick[client]=0.0;
		
		CopyVector(dir, temp);
		ScaleVector(temp, FlameTick[client]);
		AddVectors(startpos, temp, temp);
		
		new fire=0;
		if(button & IN_ATTACK)fire=1;
		
		if(FlameTick[client]==0.0)	HurtPositon(client, temp, g_flame_radius/2.0, FlameDamage[client], fire);
		else 	HurtPositon(client, temp, g_flame_radius, FlameDamage[client],fire);
		
		new Float:up[3];
		up[2]=1.0;
		//ShowDir(0, temp, up, 0.06);
		
		FlameTick[client]+=g_flame_radius/2.0;
	}
	else StopFlame(client);
}
HurtPositon(client, Float:pos[3], Float:radius, Float:damage, fire)
{
	new pointHurt = CreateEntityByName("point_hurt"); 
	DispatchKeyValueFloat(pointHurt, "DamageRadius", radius); 
	 
	if(fire==1)
	{
		DispatchKeyValueFloat(pointHurt, "Damage", damage); 
		DispatchKeyValue(pointHurt, "DamageType", "8"); 
	}
	else
	{
		DispatchKeyValueFloat(pointHurt, "Damage", damage*2.0); 
		DispatchKeyValue(pointHurt, "DamageType", "64"); 
	}
	DispatchKeyValue(pointHurt, "DamageDelay", "0.0"); 
	DispatchSpawn(pointHurt);
	TeleportEntity(pointHurt, pos, NULL_VECTOR, NULL_VECTOR); 
	AcceptEntityInput(pointHurt, "Hurt", client); 
	AcceptEntityInput(pointHurt, "Kill"); 	
}
StartCannon(client, type)
{
	decl Float:pos[3];
	decl Float:hitpos[3];
	decl Float:dir[3];
	decl Float:angle[3];
	decl Float:temp[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client , angle);	
	
	decl Float:newpos[3];
	decl Float:right[3];
	GetAngleVectors(angle, NULL_VECTOR, right, NULL_VECTOR);
	NormalizeVector(right, right);
	ScaleVector(right, 9.0);
	AddVectors(pos, right, newpos);	

	GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(dir, dir);
	CopyVector(dir,temp);
	ScaleVector(temp, 40.0);
	AddVectors(newpos, temp,newpos);
	
	new victim=GetEnt2(client, newpos, angle, hitpos, MASK_ALL); 
	if(victim!=-1 && GetConVarInt(l4d_dangerous_safe)==1)
	{
		new Float:distance=GetVectorDistance(pos, hitpos);
		if(distance<GetConVarFloat(l4d_dangerous_damage_radius)*GetConVarFloat(l4d_dangerous_power[type]))
		{
			PrintHintText(client, "It is too dangerous to shoot");
			return;
		}	
	}   
	new ent=CreateGLprojectile(client, type, newpos, dir, 300.0);
	if(L4D2Version)	SDKHook(ent, SDKHook_StartTouch , GLprojectileTouch);  
	else 
	{
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client)	;
		if(Cannon[client]>0 && IsValidEdict(Cannon[client]) && IsValidEntity(Cannon[client]))
		{
			AcceptEntityInput(Cannon[client], "kill");
		}
		Cannon[client]=ent;
	}
	
	Bullet[client]--;
	PrintHintText(client, "Special Bullet Remain: %d", Bullet[client] );
}
public Action:grenade_bounce(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{ 
	new client = GetClientOfUserId(GetEventInt(h_Event, "userid"));
	if(client<=0)return;
	if(Cannon[client]>0 && IsValidEdict(Cannon[client]) && IsValidEntity(Cannon[client]))
	{
		decl Float:pos[3];
		GetEntPropVector(Cannon[client], Prop_Send, "m_vecOrigin", pos); 		
		AcceptEntityInput(Cannon[client], "kill");
		
		new Float:f=GetEntPropFloat(Cannon[client], Prop_Send, "m_fadeMaxDist");
		new data=RoundFloat(f);
		new type=data/10000; 
		Explode(pos, type );  
	}
	Cannon[client]=0;
}
public GLprojectileTouch(ent, other)
{ 
  	new Float:f=GetEntPropFloat(ent, Prop_Send, "m_fadeMaxDist");
	new data=RoundFloat(f);
	new type=data/10000;
	new client=data%10000;
	
	new bool:explode=true;
	if(other>0 && IsValidEdict(other) && IsValidEntity(other))
	{		
		DoPointHurtForInfected(other, client,  GetConVarFloat(l4d_dangerous_damage_hit)*GetConVarFloat(l4d_dangerous_power[type]));
	}
	if(explode || other==0)
	{
		SDKUnhook(ent, SDKHook_StartTouch, GLprojectileTouch);
		decl Float:pos[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos); 
		AcceptEntityInput(ent, "kill");
		Explode(pos, type );  
	}
}
CreateElec(client, Float:pos[3], Float:endpos[3], Float:angle[3])
{   
	if(L4D2Version)
	{
		decl String:tname1[10];
		decl String:tname2[10]; 
		 
		for(new i=0; i<1; i++)
		{
			new ent = CreateEntityByName("info_particle_target"); 
			DispatchSpawn(ent);  
			TeleportEntity(ent, endpos, NULL_VECTOR, NULL_VECTOR); 
			
			Format(tname1, sizeof(tname1), "target%d", client);
			Format(tname2, sizeof(tname1), "target%d", ent);
			DispatchKeyValue(client, "targetname", tname1);
			DispatchKeyValue(ent, "targetname", tname2);
			
			new particle = CreateEntityByName("info_particle_system");
		 
			DispatchKeyValue(particle, "effect_name",  Particle_st_elmos_fire ); //st_elmos_fire fire_jet_01_flame
			DispatchKeyValue(particle, "cpoint1", tname2);
			DispatchKeyValue(particle, "parentname", tname1);
			DispatchSpawn(particle);
			ActivateEntity(particle); 
				
			SetVariantString(tname1);
			AcceptEntityInput(particle, "SetParent",particle, particle, 0);   
			SetVariantString("muzzle_flash"); 
			AcceptEntityInput(particle, "SetParentAttachment");
			new Float:v[3];
			SetVector(v, 0.0,  0.0,  0.0);  
			TeleportEntity(particle, v, NULL_VECTOR, NULL_VECTOR); 
			AcceptEntityInput(particle, "start");  
			CreateTimer(1.0, DeleteParticles, particle);
			CreateTimer(0.5, DeleteParticletargets, ent);
			
			ShowParticle(endpos, NULL_VECTOR, Particle_electrical_arc_01_system, 3.0);
		}
	}
	else
	{
		decl Float:newpos[3];
		decl Float:right[3];
		GetAngleVectors(angle, NULL_VECTOR, right, NULL_VECTOR);
		NormalizeVector(right, right);
		ScaleVector(right, 7.0);
		AddVectors(pos, right, newpos);	
		new color[4];
		color[0]=255;
		color[3]=255;
		 
		TE_SetupBeamPoints(newpos, endpos, g_sprite, 0, 0, 0, 0.1, 5.0, 5.0, 1, 0.0, color, 0);
		TE_SendToAll();
	}
 
}
CreateGLprojectile(client, type, Float:pos[3] , Float:dir[3], Float:velocity=1000.0, Float:gravity=0.01, Float:modelScale=3.5)
{
	if(type==Type_Pistol)velocity=700.0;
	else if(type==Type_Rifle)velocity=600.0;
	else if(type==Type_Shotgun)velocity=460.0;
	else if(type==Type_Sniper)velocity=1000.0;
	else if(type==Type_Smg)velocity=500.0;
	 
	decl Float:v[3];
	CopyVector(dir, v);
	NormalizeVector(v,v);
	ScaleVector(v, velocity);
	new ent=0;
	if(L4D2Version)
	{
		ent=CreateEntityByName("grenade_launcher_projectile");	
		DispatchKeyValue(ent, "model", MODEL_MISSILE); 
	}
	else
	{
		ent=CreateEntityByName("molotov_projectile");	
		DispatchKeyValue(ent, "model", "models/w_models/weapons/w_eq_molotov.mdl"); 
	}
	gravity=0.5;
	SetEntityGravity(ent, gravity);  
	DispatchSpawn(ent);
	ActivateEntity(ent);
	//new camera=CreateCamera(ent ,client);
	decl Float:ang[3];
	GetVectorAngles(dir, ang);
	ang[0]+=90.0;
	TeleportEntity(ent, pos, ang, v);
	
	if(L4D2Version)
	{
		SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
		SetEntProp(ent, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(ent, Prop_Send, "m_nGlowRangeMin", 10);
		SetEntProp(ent, Prop_Send, "m_glowColorOverride", 255);
		SetEntPropFloat(ent, Prop_Send,"m_flModelScale",modelScale*GetConVarFloat(l4d_dangerous_power[type]));	
	}
	else
	{
		 
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client)	;
 	}
	
	SetEntPropFloat(ent, Prop_Send, "m_fadeMinDist", 20000.0); 
	new Float:data= (client+type*10000) * 1.0;
	SetEntPropFloat(ent, Prop_Send, "m_fadeMaxDist", data);   
	
	if(L4D2Version && GetConVarInt(l4d_dangerous_cannon_catchfire)==1)
	{
		decl String:tname2[20]; 
		Format(tname2, sizeof(tname2), "missile%d", ent);
		DispatchKeyValue(ent, "targetname", tname2); 	
		new particle = CreateEntityByName("info_particle_system");
		DispatchKeyValue(particle, "effect_name", Particle_jet_01_flame); //st_elmos_fire fire_jet_01_flame
		DispatchKeyValue(particle, "parentname", tname2);
		DispatchSpawn(particle);
		ActivateEntity(particle); 
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString(tname2);
		AcceptEntityInput(particle, "SetParent",particle, particle, 0);   
		AcceptEntityInput(particle, "start"); 
	}
	
	return ent;
}
DropBullet(victim, attacker)
{ 
 
	if(victim>0 && IsValidEdict(victim) && IsValidEntity(victim))
	{ 
		decl Float:pos[3];
		decl Float:vel[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos); 
		pos[2]+=50.0;
	 
		new ent=CreateEntityByName("grenade_launcher_projectile");	
		DispatchKeyValue(ent, "model", MODEL_MISSILE); 
		SetEntityGravity(ent, 0.1); 
		SetEntityMoveType(ent, MOVETYPE_NONE);
		DispatchSpawn(ent);  
		SetEntPropFloat(ent, Prop_Send,"m_flModelScale",3.0);	 
		
		SetVector(vel, GetRandomFloat(-10.0, 10.0),GetRandomFloat(-10.0, 10.0),GetRandomFloat(-10.0, 10.0));
		SetVector(vel, 0.0,0.0, 20.0);
		TeleportEntity(ent, pos, NULL_VECTOR, vel);
		
		SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
		SetEntProp(ent, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(ent, Prop_Send, "m_nGlowRangeMin", 10);
		SetEntProp(ent, Prop_Send, "m_glowColorOverride", 0+200*256);
		
		SetEntPropFloat(ent, Prop_Send, "m_fadeMinDist", 20000.0); 
		new Float:data= (attacker+10000) * 1.0;
		SetEntPropFloat(ent, Prop_Send, "m_fadeMaxDist", data);  
		//SetEntProp(ent, Prop_Send, "m_bFlashing", 1);
		new button=CreateButton(ent);
		SetEntPropFloat(button, Prop_Send, "m_fadeMaxDist", ent*1.0);   
		CreateTimer(60.0, TimerKillDrop, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
	}
} 
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(damagetype & DMG_BLAST || DMG_GENERIC)
	{
		damage /= 0.0;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}
public Action:TimerKillDrop(Handle:timer, any:ent)
{
	if(ent!=0 && ent!=INVALID_ENT_REFERENCE && IsValidEntity(ent) && IsValidEdict(ent))
	{
		AcceptEntityInput(ent, "kill");
	}
} 
 
Explode(Float:pos[3], type )
{
		new Float:power=GetConVarFloat(l4d_dangerous_power[type]);
		new Float:radius= GetConVarFloat(l4d_dangerous_damage_radius)*power;
		new Float:damage=GetConVarFloat(l4d_dangerous_damage_explode)*power;

		new ent1=0;		
		new ent2=0;
		new ent3=0;
		{
			ent1=CreateEntityByName("prop_physics"); 
			DispatchKeyValue(ent1, "model", "models/props_junk/propanecanister001a.mdl"); 
			DispatchSpawn(ent1); 
			TeleportEntity(ent1, pos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(ent1, "break");
		}
		if(power>=1.3)
		{
			ent2=CreateEntityByName("prop_physics"); 	
			DispatchKeyValue(ent2, "model", "models/props_junk/propanecanister001a.mdl"); 
			DispatchSpawn(ent2); 
			TeleportEntity(ent2, pos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(ent2, "break");
		}
		if(power>=1.5)
		{
			ent3=CreateEntityByName("prop_physics"); 
			DispatchKeyValue(ent3, "model", "models/props_junk/propanecanister001a.mdl"); 
			DispatchSpawn(ent3); 
			TeleportEntity(ent3, pos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(ent3, "break");
		}	
	
		new pointHurt = CreateEntityByName("point_hurt");    	
 		DispatchKeyValueFloat(pointHurt, "Damage", damage);        
		DispatchKeyValueFloat(pointHurt, "DamageRadius", radius);   
		if(L4D2Version)	DispatchKeyValue(pointHurt, "DamageType", "64"); 
		else DispatchKeyValue(pointHurt, "DamageType", "64"); 
 		DispatchKeyValue(pointHurt, "DamageDelay", "0.0");   
		DispatchSpawn(pointHurt);
		TeleportEntity(pointHurt, pos, NULL_VECTOR, NULL_VECTOR);  
		AcceptEntityInput(pointHurt, "Hurt");    
		CreateTimer(0.1, DeletePointHurt, pointHurt); 
 
		new push = CreateEntityByName("point_push");         
  		DispatchKeyValueFloat (push, "magnitude",damage*2.0);                     
		DispatchKeyValueFloat (push, "radius", radius);                     
  		SetVariantString("spawnflags 24");                     
		AcceptEntityInput(push, "AddOutput");
 		DispatchSpawn(push);   
		TeleportEntity(push, pos, NULL_VECTOR, NULL_VECTOR);  
 		AcceptEntityInput(push, "Enable");
		CreateTimer(0.5, DeletePushForce, push);   
	
		if(GetConVarInt(l4d_dangerous_particle)==1)
	{
		if(power<1.7)ShowParticle(pos, NULL_VECTOR,Particle_gas_explosion_pump  , 1.0);	
		else ShowParticle(pos, NULL_VECTOR, Particle_gas_explosion_main , 1.0);	//gas_explosion_main
	}
}
public Action:weapon_fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!CanUse())return Plugin_Continue;
 	new client = GetClientOfUserId(GetEventInt(event, "userid")); 
	 
	if(GetClientTeam(client)==2)
	{
		new button=GetClientButtons(client);
		if(button & IN_USE )
		{
			new Float:time=GetEngineTime();
			if(time>= ShotTime[client]+1.0)
			{

			new bool:ok=false;
			decl String:item[65];
			new type=0;
			GetEventString(event, "weapon", item, 65);	
				
			if(GetConVarFloat(l4d_dangerous_power[Type_Shotgun])>0.0 && StrContains(item, "shot")>=0 )type=Type_Shotgun;
			else if(GetConVarFloat(l4d_dangerous_power[Type_Smg])>0.0 && StrContains(item, "smg")>=0 )type=Type_Smg;
			else if(GetConVarFloat(l4d_dangerous_power[Type_Sniper])>0.0 && (StrContains(item, "sniper")>=0 || StrContains(item, "hunting")>=0))type=Type_Sniper;
			else if(GetConVarFloat(l4d_dangerous_power[Type_Rifle])>0.0 && StrContains(item, "rifle")>=0 )type=Type_Rifle ; 				
			else if(GetConVarFloat(l4d_dangerous_power[Type_Pistol])>0.0 && StrContains(item, "magnum")>=0 )type=Type_Pistol ;
				 
			if(type>0)				
				{  
					new cannon=GetConVarInt(l4d_dangerous_mode_cannon);
					new ecannon=GetConVarInt(l4d_dangerous_mode_electromagnetic);
					new flame=GetConVarInt(l4d_dangerous_mode_flamethrower);
				
					if(Bullet[client]>0  )
					{
						if((button & IN_DUCK))
						{
							if(ecannon==1)StartElec(client, type);
						}
						else if((button & IN_SPEED))
						{
							if(flame==1)StartFlame(client, type);
						}
						else
						{
							if(cannon==1) StartCannon(client, type);
						}
					} 
					else
					{
						PrintHintText(client, "Please kill infected to get more bullets");
					}
				}
			ShotTime[client]=time; 
			}
		}
		 
	}
	else
	{
		//PrintToChatAll("%N use %s", client, name);
	}
	return Plugin_Continue;
}
 
public Action:player_death(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{ 
	if(!CanUse())return Plugin_Continue;	
	new victim = GetClientOfUserId(GetEventInt(hEvent, "userid")); 
	new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker")); 
	if(attacker>MaxClients || attacker<0)attacker=0;
	new entityid = GetEventInt(hEvent, "entityid") ; 
	if(victim>0)
	{		
		if(GetRandomFloat(0.0, 100.0)<GetConVarFloat(l4d_dangerous_drop_si))
		{
			if(L4D2Version && GetConVarInt(l4d_dangerous_pickup_mode)==1)DropBullet(victim, attacker);
			else GiveBullet(victim, attacker);
		}
		Bullet[victim]=3.0;
		
		StopFlame(victim);
		
		ResetPlayer(victim);
	}
	else if(entityid>0)
	{
		if(GetRandomFloat(0.0, 100.0)<GetConVarFloat(l4d_dangerous_drop_ci))
		{
			if(L4D2Version && GetConVarInt(l4d_dangerous_pickup_mode)==1)DropBullet(entityid, attacker);
			else GiveBullet(entityid, attacker);
		}
	}
	return Plugin_Continue;	 
}
new Kills[MAXPLAYERS+1]; 
 
ClipAdd(ent)
{
	new clip=GetEntProp(ent, Prop_Send, "m_iClip1")+1;
	SetEntProp(ent, Prop_Send, "m_iClip1", clip); 
}
public Action:round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllState();
}
public infected_ablility(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!CanUse())
	return Plugin_Continue;
	GetClientOfUserId(GetEventInt(event, "victim"));  
	return Plugin_Continue;
}
public player_bot_replace(Handle:Spawn_Event, const String:Spawn_Name[], bool:Spawn_Broadcast)
{
	if(!CanUse())
	return Plugin_Continue;
	new client = GetClientOfUserId(GetEventInt(Spawn_Event, "player"));
	new bot = GetClientOfUserId(GetEventInt(Spawn_Event, "bot"));
	ResetPlayer(client);
	ResetPlayer(bot);
	return 0;
} 
ResetPlayer(client)
{
	Bullet[client]=0;
	Cannon[client]=0;
	Flame[client][0]=Flame[client][1]=Flame[client][2]=0;
	Kills[client]=0;
}
public Action:player_spawn(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	if(!CanUse())
	return Plugin_Continue;
	new victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	ResetPlayer(victim);
	return Plugin_Continue;
}
GameCheck()
{
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	
	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false))
		GameMode = 1;
	else
	{
		GameMode = 0;
 	}
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2", false))
	{
		ZOMBIECLASS_TANK=8;
		L4D2Version=true;
	}	
	else
	{
		ZOMBIECLASS_TANK=5;
		L4D2Version=false;
	}
 
}
public OnMapStart()
{
	PrecacheModel(MODEL_W_PIPEBOMB);
	PrecacheModel("models/props_junk/propanecanister001a.mdl", true);
	PrecacheParticle(Particle_gas_explosion_pump);
	PrecacheParticle(Particle_gas_explosion_main);
	PrecacheSound(SOUND_FLAME, true);
	if(L4D2Version)
	{
		g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");	
		PrecacheModel(MODEL_MISSILE);
		
		PrecacheParticle(Particle_jet_01_flame);

		PrecacheParticle(Particle_st_elmos_fire);
		PrecacheParticle(Particle_electrical_arc_01_system);
	}
	else
	{
		g_sprite = PrecacheModel("materials/sprites/laser.vmt");	
		 
	}
	g_sprite=g_sprite+0;
}
bool:CanUse(client=0)
{
 	new mode=GetConVarInt(l4d_dangerous_enable);
	if(mode==0)return false;
	if(mode==1 && GameMode==2)return false;
	return true; 
}
CopyVector(Float:source[3], Float:target[3])
{
	target[0]=source[0];
	target[1]=source[1];
	target[2]=source[2];
}
SetVector(Float:target[3], Float:x, Float:y, Float:z)
{
	target[0]=x;
	target[1]=y;
	target[2]=z;
}
public Action:DeletePointHurt(Handle:timer, any:ent)
{
	 if (ent> 0 && IsValidEntity(ent) && IsValidEdict(ent))
	 {
		 decl String:classname[64];
		 GetEdictClassname(ent, classname, sizeof(classname));
		 if (StrEqual(classname, "point_hurt", false))
				{
					AcceptEntityInput(ent, "Kill"); 
					RemoveEdict(ent);
				}
		 }
}
public Action:DeletePushForce(Handle:timer, any:ent)
{
	 if (ent> 0 && IsValidEntity(ent) && IsValidEdict(ent))
	 {
		 decl String:classname[64];
		 GetEdictClassname(ent, classname, sizeof(classname));
		 if (StrEqual(classname, "point_push", false))
				{
 					AcceptEntityInput(ent, "Disable");
					AcceptEntityInput(ent, "Kill"); 
					RemoveEdict(ent);
				}
	 }
}
public PrecacheParticle(String:particlename[])
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	} 
}
public Action:DeleteParticles(Handle:timer, any:particle)
{
	 if (IsValidEntity(particle))
	 {
		 decl String:classname[64];
		 GetEdictClassname(particle, classname, sizeof(classname));
		 if (StrEqual(classname, "info_particle_system", false))
			{
				AcceptEntityInput(particle, "stop");
				AcceptEntityInput(particle, "kill");
				RemoveEdict(particle);
			}
	 }
}
public ShowParticle(Float:pos[3], Float:ang[3],String:particlename[], Float:time)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		
		DispatchKeyValue(particle, "effect_name", particlename); 
		DispatchSpawn(particle);
		ActivateEntity(particle);
		
		
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		AcceptEntityInput(particle, "start");		
		CreateTimer(time, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
		return particle;
	}  
	return 0;
}
public Action:DeleteParticletargets(Handle:timer, any:target)
{
	 if (IsValidEntity(target))
	 {
		 decl String:classname[64];
		 GetEdictClassname(target, classname, sizeof(classname));
		 if (StrEqual(classname, "info_particle_target", false))
			{
				AcceptEntityInput(target, "stop");
				AcceptEntityInput(target, "kill");
				RemoveEdict(target);
				 
			}
	 }
}
//code from "DJ_WEST"
CreateCamera(i_Witch ,client)
{
	decl i_Camera, Float:f_Origin[3], Float:f_Angles[3], Float:f_Forward[3], String:s_TargetName[32];
	
	GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin);
	GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles);
	
	i_Camera = CreateEntityByName("prop_dynamic_override");
	if (IsValidEdict(i_Camera))
	{
		GetAngleVectors(f_Angles, f_Forward, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(f_Forward, f_Forward);
		ScaleVector(f_Forward,  45.0 ); //-25
		AddVectors(f_Forward, f_Origin, f_Origin);
		f_Origin[2] += 6.0 ; //6.0
		FormatEx(s_TargetName, sizeof(s_TargetName), "camera%d", i_Witch);
		DispatchKeyValue(i_Camera, "model", MODEL_W_PIPEBOMB);
		DispatchKeyValue(i_Witch, "targetname", s_TargetName);
		DispatchKeyValueVector(i_Camera, "origin", f_Origin);
		//f_Angles[0] = 45.0;
		//f_Angles[1] = -0.0;
		//f_Angles[2] = 0.0;
		GetClientEyeAngles(client, f_Angles);
		DispatchKeyValueVector(i_Camera, "angles", f_Angles);
		DispatchKeyValue(i_Camera, "parentname", s_TargetName);
		DispatchSpawn(i_Camera);
		SetVariantString(s_TargetName);
		AcceptEntityInput(i_Camera, "SetParent");
		AcceptEntityInput(i_Camera, "DisableShadow");
		ActivateEntity(i_Camera);
		SetEntityRenderMode(i_Camera, RENDER_TRANSCOLOR);
		SetEntityRenderColor(i_Camera, 0, 0, 0, 0);
		SetEntityMoveType(i_Camera, MOVETYPE_NOCLIP);   
		return i_Camera;
	}
	return 0;
}//code modify from  "[L4D & L4D2] Extinguisher and Flamethrower", SilverShot;
CreateButton(entity )
{ 
	decl String:sTemp[16];
	new button;
	new bool:type=false;
	if(type)button = CreateEntityByName("func_button");
	else button = CreateEntityByName("func_button_timed"); 

	Format(sTemp, sizeof(sTemp), "target%d",  button );
	DispatchKeyValue(entity, "targetname", sTemp);
	DispatchKeyValue(button, "glow", sTemp);
	DispatchKeyValue(button, "rendermode", "3");
 
	if(type )
	{
		DispatchKeyValue(button, "spawnflags", "1025");
		DispatchKeyValue(button, "wait", "1");
	}
	else
	{
		DispatchKeyValue(button, "spawnflags", "0");
		DispatchKeyValue(button, "auto_disable", "1");
		Format(sTemp, sizeof(sTemp), "%f", 1.0);
		DispatchKeyValue(button, "use_time", sTemp);
	}
	DispatchSpawn(button);
	AcceptEntityInput(button, "Enable");
	ActivateEntity(button);

	Format(sTemp, sizeof(sTemp), "ft%d", button);
	DispatchKeyValue(entity, "targetname", sTemp);
	SetVariantString(sTemp);
	AcceptEntityInput(button, "SetParent", button, button, 0);
	TeleportEntity(button, Float:{0.0, 0.0, 0.0}, NULL_VECTOR, NULL_VECTOR);

	SetEntProp(button, Prop_Send, "m_nSolidType", 0, 1);
	SetEntProp(button, Prop_Send, "m_usSolidFlags", 4, 2);

	new Float:vMins[3] = {-5.0, -5.0, -5.0}, Float:vMaxs[3] = {5.0, 5.0, 5.0};
	SetEntPropVector(button, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(button, Prop_Send, "m_vecMaxs", vMaxs);

	if( L4D2Version )
	{
		SetEntProp(button, Prop_Data, "m_CollisionGroup", 1);
		SetEntProp(button, Prop_Send, "m_CollisionGroup", 1);
	}
	 
	//SetEntProp(entity, Prop_Data, "m_iMinHealthDmg", 99999);
	//HookSingleEntityOutput(entity, "OnHealthChanged", OnHealthChanged, true);

	if( type )
	{	
		HookSingleEntityOutput(button, "OnPressed", OnPressed);
	}
	else
	{
		SetVariantString("OnTimeUp !self:Enable::1:-1");
		AcceptEntityInput(button, "AddOutput");
		HookSingleEntityOutput(button, "OnTimeUp", OnPressed);
	}
	return button;
}
public OnPressed(const String:output[], caller, activator, Float:delay)
{ 
	//PrintToChatAll("%N pick up", activator);
	new Float:f=GetEntPropFloat(caller, Prop_Send, "m_fadeMaxDist");	
	new ent=RoundFloat(f); 
	f=GetEntPropFloat(ent, Prop_Send, "m_fadeMaxDist");	
	new owner=RoundFloat(f)-10000;
	//PrintToChatAll("pick up ent %d onwer %N", ent, owner); 
	AcceptEntityInput(ent, "kill");  
	if(activator>0 && activator<=MaxClients && IsClientInGame(activator))
	{ 
		Bullet[activator]+=GetConVarInt(l4d_dangerous_drop_pickupcount);
		PrintHintText(activator,"You pick up some special bullets, Total:%d", Bullet[activator]);
		if(ShowMsg[activator]<GetConVarInt(l4d_dangerous_message))
		{
			PrintUsageMessage(activator);
			ShowMsg[activator]++;
		}
	}
}
stock GiveBullet(victim, attacker)
{
	if(attacker>0 && attacker<=MaxClients && IsClientInGame(attacker))
	{
		Bullet[attacker]+=GetConVarInt(l4d_dangerous_drop_pickupcount);
		PrintHintText(attacker,"You get some special bullets, Total:%d", Bullet[attacker]);
		if(ShowMsg[attacker]<GetConVarInt(l4d_dangerous_message))
		{
			PrintUsageMessage(attacker);
			ShowMsg[attacker]++;
		}
	}
}
PrintUsageMessage(client)
{
	decl String:buffer[320]="";
	if(GetConVarFloat(l4d_dangerous_power[Type_Shotgun])>0.0)Format(buffer, sizeof(buffer), "%s Shotgun", buffer) ;
	if(GetConVarFloat(l4d_dangerous_power[Type_Rifle])>0.0)Format(buffer, sizeof(buffer), "%s Rifle", buffer) ;
	if(GetConVarFloat(l4d_dangerous_power[Type_Sniper])>0.0)Format(buffer, sizeof(buffer), "%s Sniper", buffer) ;
	if(GetConVarFloat(l4d_dangerous_power[Type_Pistol])>0.0)Format(buffer, sizeof(buffer), "%s Magnum", buffer) ;
	if(GetConVarFloat(l4d_dangerous_power[Type_Smg])>0.0)Format(buffer, sizeof(buffer), "%s Smg", buffer) ;
	PrintToChat(client, "\x01Use \x04E%s \x03 to shot special bullets", buffer);
	if(GetConVarInt(l4d_dangerous_mode_cannon))PrintToChat(client, "\x01Mini Cannon: \x04E+Fire");
	if(GetConVarInt(l4d_dangerous_mode_electromagnetic))PrintToChat(client, "\x01Electromagnetic Cannon: \x04Duck+E+Fire ");
	if(GetConVarInt(l4d_dangerous_mode_flamethrower))PrintToChat(client, "\x01Flamethrower:\x04Walk+E+Fire ");
}
CreatePointHurt()
{
	new pointHurt=CreateEntityByName("point_hurt");
	if(pointHurt)
	{		
		DispatchKeyValue(pointHurt,"Damage","10");
		if(L4D2Version)	DispatchKeyValue(pointHurt,"DamageType","-2130706430"); 
		DispatchSpawn(pointHurt);
	}
	return pointHurt;
}
new String:N[10];
DoPointHurtForInfected(victim, attacker=0, Float:FireDamage)
{
	new g_PointHurt=CreatePointHurt();	 
			
	Format(N, 20, "target%d", victim);
	DispatchKeyValue(victim,"targetname", N);
	DispatchKeyValue(g_PointHurt,"DamageTarget", N); 
 	DispatchKeyValueFloat(g_PointHurt,"Damage", FireDamage);
	if(L4D2Version)
	{					
		DispatchKeyValueFloat(g_PointHurt,"Damage", FireDamage); 
	}
	else
	{
		new h=GetEntProp(victim, Prop_Data, "m_iHealth"); 
		if(h*1.0<=FireDamage)  DispatchKeyValue(g_PointHurt, "DamageType", "64");
		else  DispatchKeyValue(g_PointHurt, "DamageType", "-1073741822"); 
	}
	AcceptEntityInput(g_PointHurt,"Hurt",(attacker>0)?attacker:-1);
	AcceptEntityInput(g_PointHurt,"kill" ); 
}
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data) 
	{
		return false; 
	} 
	return true;
}
public bool:TraceRayDontHitLive(entity, mask, any:data)
{
	if(entity>0 && entity <= GetMaxClients())
	{
		return false;
	}
	if(entity == data) 
	{
		return false; 
	}
	decl String:edictname[128];
	GetEdictClassname(entity, edictname, 128);
	if(StrEqual(edictname, "infected"))
	{
		return false;
	}
	return true;
}
stock ShowLaser(colortype,Float:pos1[3], Float:pos2[3], Float:life=10.0,  Float:width1=1.0, Float:width2=11.0)
{
	decl color[4];
	if(colortype==1)
	{
		color[0] = 200; 
		color[1] = 0;
		color[2] = 0;
		color[3] = 230; 
	}
	else if(colortype==2)
	{
		color[0] = 0; 
		color[1] = 200;
		color[2] = 0;
		color[3] = 230; 
	}
	else if(colortype==3)
	{
		color[0] = 0; 
		color[1] = 0;
		color[2] = 200;
		color[3] = 230; 
	}
	else 
	{
		color[0] = 200; 
		color[1] = 200;
		color[2] = 200;
		color[3] = 230; 		
	}

	TE_SetupBeamPoints(pos1, pos2, g_sprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
	TE_SendToAll();
}
//draw line between pos1 and pos2
stock ShowPos(color, Float:pos1[3], Float:pos2[3],Float:life=10.0, Float:length=200.0, Float:width1=1.0, Float:width2=11.0)
{
	decl Float:t[3];
	if(length!=0.0)
	{
		SubtractVectors(pos2, pos1, t);	 
		NormalizeVector(t,t);
		ScaleVector(t, length);
		AddVectors(pos1, t,t);
	}
	else 
	{
		CopyVector(pos2,t);
	}
	ShowLaser(color,pos1, t, life,   width1, width2);
}
//draw line start from pos, the line's drection is dir.
stock ShowDir(color,Float:pos[3], Float:dir[3],Float:life=10.0, Float:length=200.0, Float:width1=1.0, Float:width2=11.0)
{
	decl Float:pos2[3];
	CopyVector(dir, pos2);
	NormalizeVector(pos2,pos2);
	ScaleVector(pos2, length);
	AddVectors(pos, pos2,pos2);
	ShowLaser(color,pos, pos2, life,   width1, width2);
}
//draw line start from pos, the line's angle is angle.
stock ShowAngle(color,Float:pos[3], Float:angle[3],Float:life=10.0, Float:length=200.0, Float:width1=1.0, Float:width2=11.0)
{
	decl Float:pos2[3];
	GetAngleVectors(angle, pos2, NULL_VECTOR, NULL_VECTOR);
 
	NormalizeVector(pos2,pos2);
	ScaleVector(pos2, length);
	AddVectors(pos, pos2,pos2);
	ShowLaser(color,pos, pos2, life, width1, width2);
} 
stock IsInfected(client, type)
{
	new class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(type==class)return true;
	else return false;
}