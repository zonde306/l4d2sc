#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"0.1"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "连锁闪电",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define ChainLightning_Sound_launch		"ambient/energy/zap1.wav"
#define ChainLightning_Particle_hit		"electrical_arc_01_system"
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO		"materials/sprites/halo01.vmt"
#define SPRITE_GLOW		"materials/sprites/glow01.vmt"

new bool:IsChained[MAXPLAYERS+1];
new BlueColor[4] = {80, 80, 255, 255};
new g_BeamSprite, g_HaloSprite, g_GlowSprite;

new Float:ChainLightningInterval[MAXPLAYERS+1], Float:ChainLightningDamage[MAXPLAYERS+1],
	Float:ChainLightningRadius[MAXPLAYERS+1], Float:ChainLightningLaunchRadius[MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateTimer(1.0, Timer_SetupSpell);
}

public Action Timer_SetupSpell(Handle timer, any data)
{
	SC_CreateSpell("ss_chainlightning", "连锁闪电", 100, 6000);
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	if(!StrEqual(classname, "ss_chainlightning", false))
		return;
	
	ChainLightningInterval[client] = 1.0;
	ChainLightningDamage[client] = 20.0 + ((SC_GetClientLevel(client) + 1) * 5);
	ChainLightningRadius[client] = 100.0 + ((SC_GetClientLevel(client) + 1) * 3);
	ChainLightningLaunchRadius[client] = 200.0 + ((SC_GetClientLevel(client) + 1) * 5);
	ChainLightningFunction(client);
	PrintToChat(client, "\x03[提示]\x01 你启动了 \x04连锁闪电\x01 范围 \x05%.0f\x01。", ChainLightningLaunchRadius[client]);
}

public void OnMapStart()
{
	PrecacheSound(ChainLightning_Sound_launch, true);
	PrecacheParticle(ChainLightning_Particle_hit);
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);
}

public Action:ChainLightningFunction(Client)
{
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=ChainLightningLaunchRadius[Client];
	GetClientAbsOrigin(Client, pos);
	
	/* Emit impact sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos);
	
	ShowParticle(pos, ChainLightning_Particle_hit, 0.1);
	
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 顏色(Color[4]),(播放速度)10,(标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();
	
	new team = GetClientTeam(Client);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) != team && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					// DealDamage(Client, i, ChainLightningDamage[Client], 1024, "chain_lightning");
					
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
					
					SDKHooks_TakeDamage(i, 0, Client, ChainLightningDamage[Client], DMG_SHOCK);
				}
			}
		}
	}
	
	if(team == 3)
		return Plugin_Stop;
	
	for(new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				// DealDamage(Client, iEntity, RoundToNearest(ChainLightningDamage[Client]/(1.0 + StrEffect[Client] + EnergyEnhanceEffect_Attack[Client])), 1024, "chain_lightning");
				
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
				
				SDKHooks_TakeDamage(iEntity, 0, Client, ChainLightningDamage[Client], DMG_SHOCK);
			}
		}
	}
	
	return Plugin_Handled;
}
public Action:ChainDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);
	
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=ChainLightningRadius[attacker];
	
	if(victim >= MaxClients + 1)
	{
		if((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		
		if((IsCommonInfected(victim) || IsWitch(victim)))
			SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	}
	else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))
			GetClientAbsOrigin(victim, pos);
		
		IsChained[victim] = false;
	}
	
	/* Emit impact sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos);	
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();
	
	new team = GetClientTeam(attacker);
	
	for(new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				// DealDamage(attacker, iEntity, RoundToNearest(ChainLightningDamage[attacker]/(1.0 + StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker])), 1024, "chain_lightning");
				
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
				
				SDKHooks_TakeDamage(iEntity, 0, attacker, ChainLightningDamage[attacker], DMG_SHOCK);
			}
		}
	}
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) != team && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					// DealDamage(attacker, i, ChainLightningDamage[attacker], 1024, "chain_lightning");
					
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
					
					SDKHooks_TakeDamage(i, 0, attacker, ChainLightningDamage[attacker], DMG_SHOCK);
				}
			}
		}
	}
	//return Plugin_Handled;
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
stock bool:IsPlayerGhost(Client)
{
	if(GetEntProp(Client, Prop_Send, "m_isGhost", 1) == 1)
		return true;
	return false;
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
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

public AttachParticle(ent, String:particleType[], Float:time)
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

public PrecacheParticle(String:particlename[])
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
