/*

	Created by DJ_WEST
	
	Web: http://amx-x.ru
	AMX Mod X and SourceMod Russian Community
	
*/

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.3"

#define FADE_IN 0x0001
#define CLASS_HUNTER 3
#define CLASS_TANK 8
#define CLASS_NOTINFECTED 9
#define ANIM_STANDING_CRYING 2
#define ANIM_SITTING 4
#define ANIM_WALK 10
#define ANIM_TURN_RIGHT 34
#define ANIM_TURN_LEFT 35
#define ANIM_FALL 54
#define ANIM_JUMP 58
#define ANIM_LADDER_ASCEND 70
#define ANIM_LADDER_DESCEND 71
#define DAY_MIDNIGHT "1"
#define TEAM_INFECTED 3
#define CAMERA_MODEL "models/w_models/weapons/w_eq_pipebomb.mdl"

public Plugin:myinfo = 
{
	name = "Witch Control",
	author = "DJ_WEST",
	description = "Allows infected players to take control of a witch",
	version = PLUGIN_VERSION,
	url = "http://amx-x.ru"
}

new g_b_WitchControl[MAXPLAYERS+1], Float:g_PlayerGameTime[MAXPLAYERS+1], bool:g_b_OnLadder[MAXPLAYERS+1],
	Handle:g_h_SetClass, Handle:g_h_GameConfig, Float:g_WitchLadderOrigin[MAXPLAYERS+1], Handle:g_h_TeleportTimer[MAXPLAYERS+1], 
	Float:g_PlayerTraceTimer[MAXPLAYERS+1], Handle:h_CvarWitchSpeed, Handle:h_CvarMode, Handle:h_CvarMessageType, Float:g_b_WitchJump[MAXPLAYERS+1],
	Handle:h_CvarAttack

public OnPluginStart()
{
	decl String:s_Game[12], Handle:h_Version
	
	GetGameFolderName(s_Game, sizeof(s_Game))
	if (!StrEqual(s_Game, "left4dead2"))
		SetFailState("Witch Control supports Left 4 Dead 2 only!")
		
	g_h_GameConfig = LoadGameConfigFile("l4d2_witch_control")

	if (g_h_GameConfig != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetFromConf(g_h_GameConfig, SDKConf_Signature, "SetClass")
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain)
		g_h_SetClass = EndPrepSDKCall()
		
		if (g_h_SetClass == INVALID_HANDLE)
			SetFailState("Don't find SetClass function! Update gamedata/l4d2_witch_control.txt file.")
	}
	else
		SetFailState("Don't find gamedata/l4d2_witch_control.txt file!")
	
	CloseHandle(g_h_GameConfig)
	
	LoadTranslations("witch_control.phrases")
	
	h_Version = CreateConVar("witch_control_version", PLUGIN_VERSION, "Witch Control version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY)
	h_CvarWitchSpeed = CreateConVar("l4d2_witch_speed", "2.0", "Witch speed", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 1.0, true, 5.0)
	h_CvarMode = CreateConVar("l4d2_witch_take_mode", "2", "Mode of taking control of a witch (0 - only alive infected, 1 - only ghost infected, 2 - alive and ghost infected)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 2.0)
	h_CvarMessageType = CreateConVar("l4d2_witch_message_type", "3", "Message type (0 - disable, 1 - chat, 2 - hint, 3 - instructor hint)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 3.0)
	h_CvarAttack = CreateConVar("l4d2_witch_attack", "1", "Witch attack ability (0 - disable, 1 - enable)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0)
	
	HookEvent("witch_spawn", EventWitchSpawn)
	HookEvent("tank_spawn", EventTankSpawn)
	HookEvent("round_end", EventRoundEnd)
	AddNormalSoundHook(NormalSHook:CheckSound)
	
	SetConVarString(h_Version, PLUGIN_VERSION)
}

public OnMapStart()
{
	DispatchKeyValue(0, "timeofday", DAY_MIDNIGHT)

	if (!IsModelPrecached(CAMERA_MODEL))
		PrecacheModel(CAMERA_MODEL)
}

public Action:CheckSound(i_Clients[64], &i_NumClients, String:s_Sound[PLATFORM_MAX_PATH], &i_Entity)
{
	if (1 <= i_Entity <= MaxClients && g_b_WitchControl[i_Entity])
		return Plugin_Handled
		
	return Plugin_Continue
}

public Action:SetWitchControl(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Camera, i_Client, i_Witch, Handle:h_PackData
	
	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	i_Witch = ReadPackCell(h_Pack)
	CloseHandle(h_Pack)
	
	if (g_b_WitchControl[i_Client] || !IsValidEdict(i_Witch) || !IsClientInGame(i_Client))
		return
			
	g_b_WitchControl[i_Client] = i_Witch
	g_WitchLadderOrigin[i_Client] = 0.0
	g_PlayerTraceTimer[i_Client] = 0.0
	g_b_WitchJump[i_Client] = 0.0

	SDKCall(g_h_SetClass, i_Client, CLASS_HUNTER)
	CreateTimer(0.1, ChangeClass, i_Client)
	
	i_Witch = g_b_WitchControl[i_Client]
	SetEntPropEnt(i_Witch, Prop_Data, "m_hOwnerEntity", i_Client)
				
	i_Camera = CreateCamera(i_Witch)
	if (i_Camera)
	{
		SetClientViewEntity(i_Client, i_Camera)
		RemovePlayerItem(i_Client, GetEntPropEnt(i_Client, Prop_Data, "m_hActiveWeapon"))
		AcceptEntityInput(i_Client, "DisableShadow")
		g_h_TeleportTimer[i_Client] = CreateTimer(0.1, TeleportPlayer, i_Client, TIMER_REPEAT)
	}
	
	h_PackData = CreateDataPack()
	WritePackCell(h_PackData, i_Client)
	WritePackString(h_PackData, "Sit witch")
	WritePackString(h_PackData, "+duck")
	CreateTimer(0.1, DisplayHint, h_PackData)
	
	h_PackData = CreateDataPack()
	WritePackCell(h_PackData, i_Client)
	WritePackString(h_PackData, "Lose witch")
	WritePackString(h_PackData, "+use")
	CreateTimer(7.0, DisplayHint, h_PackData)
}

public Action:ChangeClass(Handle:h_Timer, any:i_Client)
{
	if (IsClientInGame(i_Client))
	{
		decl i_Witch
		
		i_Witch = g_b_WitchControl[i_Client]
		
		if (!i_Witch || !IsValidEdict(i_Witch))
			return
			
		SetEntProp(i_Client, Prop_Send, "m_fFlags", GetEntityFlags(i_Client) | FL_GODMODE)
		SetEntProp(i_Client, Prop_Data, "m_takedamage", 0, 1)
		SetEntProp(i_Client, Prop_Send, "m_isGhost", 0)
		SetEntProp(i_Client, Prop_Send, "m_lifeState", 0)
		SDKCall(g_h_SetClass, i_Client, CLASS_NOTINFECTED)
		SetEntProp(i_Client, Prop_Data, "m_iMaxHealth", GetEntProp(i_Witch, Prop_Data, "m_iMaxHealth"))
		SetEntityMoveType(i_Client, MOVETYPE_NONE)
		SetEntityRenderMode(i_Client, RENDER_TRANSCOLOR)
		SetEntityRenderColor(i_Client, 0, 0, 0, 0)
		SetEntProp(i_Client, Prop_Send, "m_iGlowType", 3)
		SetEntProp(i_Client, Prop_Send, "m_glowColorOverride", 1)
		SetEntProp(i_Client, Prop_Send, "m_fEffects", 0)
		AcceptEntityInput(MakeCompatEntRef(GetEntProp(i_Client, Prop_Send, "m_customAbility")), "Kill")
	}
}


public Action:DisplayHint(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Client
	
	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	
	if (GetConVarInt(h_CvarMessageType) == 3 && IsClientInGame(i_Client))
		ClientCommand(i_Client, "gameinstructor_enable 1")
		
	CreateTimer(0.3, DelayDisplayHint, h_Pack)
}

public Action:DelayDisplayHint(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Client, String:s_LanguageKey[16], String:s_Message[256], String:s_Bind[10]

	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	ReadPackString(h_Pack, s_LanguageKey, sizeof(s_LanguageKey))
	ReadPackString(h_Pack, s_Bind, sizeof(s_Bind))
	CloseHandle(h_Pack)
	
	switch (GetConVarInt(h_CvarMessageType))
	{
		case 1:
		{
			FormatEx(s_Message, sizeof(s_Message), "\x03[%t]\x01 %t.", "Information", s_LanguageKey)
			ReplaceString(s_Message, sizeof(s_Message), "\n", " ")
			PrintToChat(i_Client, s_Message)
		}
		case 2: PrintHintText(i_Client, "%t", s_LanguageKey)
		case 3:
		{
			FormatEx(s_Message, sizeof(s_Message), "%t", s_LanguageKey)
			DisplayInstructorHint(i_Client, s_Message, s_Bind)
		}
	}
}

public DisplayInstructorHint(i_Client, String:s_Message[256], String:s_Bind[])
{
	decl i_Ent, String:s_TargetName[32], Handle:h_RemovePack
	
	i_Ent = CreateEntityByName("env_instructor_hint")
	FormatEx(s_TargetName, sizeof(s_TargetName), "hint%d", i_Client)
	ReplaceString(s_Message, sizeof(s_Message), "\n", " ")
	DispatchKeyValue(i_Client, "targetname", s_TargetName)
	DispatchKeyValue(i_Ent, "hint_target", s_TargetName)
	DispatchKeyValue(i_Ent, "hint_timeout", "5")
	DispatchKeyValue(i_Ent, "hint_range", "0.01")
	DispatchKeyValue(i_Ent, "hint_color", "255 255 255")
	DispatchKeyValue(i_Ent, "hint_icon_onscreen", "use_binding")
	DispatchKeyValue(i_Ent, "hint_caption", s_Message)
	DispatchKeyValue(i_Ent, "hint_binding", s_Bind)
	DispatchSpawn(i_Ent)
	AcceptEntityInput(i_Ent, "ShowHint")
	
	h_RemovePack = CreateDataPack()
	WritePackCell(h_RemovePack, i_Client)
	WritePackCell(h_RemovePack, i_Ent)
	CreateTimer(5.0, RemoveInstructorHint, h_RemovePack)
}
	
public Action:RemoveInstructorHint(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Ent, i_Client
	
	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	i_Ent = ReadPackCell(h_Pack)
	CloseHandle(h_Pack)
	
	if (!i_Client || !IsClientInGame(i_Client))
		return Plugin_Handled
	
	if (IsValidEntity(i_Ent))
			RemoveEdict(i_Ent)
	
	ClientCommand(i_Client, "gameinstructor_enable 0")
		
	DispatchKeyValue(i_Client, "targetname", "")
		
	return Plugin_Continue
}

public Action:EventRoundEnd(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
	for (new i_Client = 1; i_Client <= MaxClients; i_Client++)
		if (IsClientInGame(i_Client) && !IsFakeClient(i_Client) && GetClientTeam(i_Client) == TEAM_INFECTED)
		{
			decl i_Witch
			
			i_Witch = g_b_WitchControl[i_Client]
			
			if (i_Witch)
				RemoveWitchControl(i_Client, i_Witch)
		}
}

public Action:EventTankSpawn(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
	decl i_UserID, i_Client, i_Witch, String:s_ClassName[16]
	
	i_UserID = GetEventInt(h_Event, "userid")
	i_Client = GetClientOfUserId(i_UserID)
	
	if (IsClientInGame(i_Client))
	{
		i_Witch = g_b_WitchControl[i_Client]
		GetEdictClassname(i_Client, s_ClassName, sizeof(s_ClassName))
		
		if (StrEqual(s_ClassName, "player") && i_Witch && IsValidEdict(i_Witch))
			RemoveWitchControl(i_Client, i_Witch)
	}
}

public Action:EventWitchSpawn(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
	decl i_Witch, Handle:h_Pack
	
	i_Witch = GetEventInt(h_Event, "witchid")
	
	if (IsValidEdict(i_Witch))
		SetEntProp(i_Witch, Prop_Send, "m_fFlags", GetEntityFlags(i_Witch) | FL_DUCKING)
		
	for (new i_Client = 1; i_Client <= MaxClients; i_Client++)
		if (IsClientInGame(i_Client) && !IsFakeClient(i_Client) && GetClientTeam(i_Client) == TEAM_INFECTED)
		{
			if (GetConVarInt(h_CvarMessageType) == 3)
				ClientCommand(i_Client, "gameinstructor_enable 1")
				
			h_Pack = CreateDataPack()
			WritePackCell(h_Pack, i_Client)
			WritePackString(h_Pack, "Take witch")
			WritePackString(h_Pack, "+use")
			CreateTimer(0.1, DisplayHint, h_Pack)
		}
}

public CreateCamera(i_Witch)
{
	decl i_Camera, Float:f_Origin[3], Float:f_Angles[3], Float:f_Forward[3], String:s_TargetName[32]
	
	GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
	GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
	
	i_Camera = CreateEntityByName("prop_dynamic_override")
	if (IsValidEdict(i_Camera))
	{
		GetAngleVectors(f_Angles, f_Forward, NULL_VECTOR, NULL_VECTOR)
		NormalizeVector(f_Forward, f_Forward)
		ScaleVector(f_Forward, -50.0)
		AddVectors(f_Forward, f_Origin, f_Origin)
		f_Origin[2] += 100.0
		FormatEx(s_TargetName, sizeof(s_TargetName), "witch%d", i_Witch)
		DispatchKeyValue(i_Camera, "model", CAMERA_MODEL)
		DispatchKeyValue(i_Witch, "targetname", s_TargetName)
		DispatchKeyValueVector(i_Camera, "origin", f_Origin)
		f_Angles[0] = 30.0
		DispatchKeyValueVector(i_Camera, "angles", f_Angles)
		DispatchKeyValue(i_Camera, "parentname", s_TargetName)
		DispatchSpawn(i_Camera)
		SetVariantString(s_TargetName)
		AcceptEntityInput(i_Camera, "SetParent")
		AcceptEntityInput(i_Camera, "DisableShadow")
		ActivateEntity(i_Camera)
		SetEntityRenderMode(i_Camera, RENDER_TRANSCOLOR)
		SetEntityRenderColor(i_Camera, 0, 0, 0, 0)
	
		return i_Camera
	}
	
	return 0
}

public OnClientPutInServer(i_Client)
{
	if (IsFakeClient(i_Client))
		return
		
	g_b_OnLadder[i_Client] = false
	g_b_WitchControl[i_Client] = 0
}

public OnClientDisconnected(i_Client)
{
	if (IsFakeClient(i_Client))
		return
		
	if (g_h_TeleportTimer[i_Client] != INVALID_HANDLE)
	{
		KillTimer(g_h_TeleportTimer[i_Client])
		g_h_TeleportTimer[i_Client] = INVALID_HANDLE
	}	
}

public Action:OnPlayerRunCmd(i_Client, &i_Buttons, &i_Impulse, Float:f_PlayerVelocity[3], Float:f_PlayerAngles[3], &i_Weapon)
{
	if (IsFakeClient(i_Client))
		return Plugin_Continue
		
	if (!g_b_WitchControl[i_Client])
	{
		if (i_Buttons & IN_USE && GetClientTeam(i_Client) == TEAM_INFECTED)
		{
			if (GetEntProp(i_Client, Prop_Send, "m_zombieClass") != CLASS_TANK && IsPlayerAlive(i_Client))
			{
				decl i_Target, String:s_ClassName[16]
				
				i_Target = GetClientAimTarget(i_Client, false)
				
				if (i_Target > 0 && IsValidEdict(i_Target))
				{
					GetEdictClassname(i_Target, s_ClassName, sizeof(s_ClassName))

					if (StrEqual(s_ClassName, "witch") && GetEntPropEnt(i_Target, Prop_Data, "m_hOwnerEntity") == -1)
					{
						decl bool:b_IsGhost
						
						b_IsGhost = bool:GetEntProp(i_Client, Prop_Send, "m_isGhost")
						switch (GetConVarInt(h_CvarMode))
						{
							case 0:
								if (b_IsGhost)
									return Plugin_Continue
							case 1:
								if (!b_IsGhost)
									return Plugin_Continue
	
						}
						decl Float:f_TargetOrigin[3], Float:f_PlayerOrigin[3]
						
						GetClientAbsOrigin(i_Client, f_PlayerOrigin)
						GetEntPropVector(i_Target, Prop_Send, "m_vecOrigin", f_TargetOrigin)

						if (GetVectorDistance(f_PlayerOrigin, f_TargetOrigin) <= 100.0)
						{
							decl Float:f_Origin[3]
							
							GetEntPropVector(i_Target, Prop_Send, "m_vecOrigin", f_Origin)
							f_Origin[2] += 10.0
							TeleportEntity(i_Client, f_Origin, NULL_VECTOR, NULL_VECTOR)
							SetEntProp(i_Client, Prop_Send, "m_fFlags", GetEntityFlags(i_Client) | FL_GODMODE)
							SetEntProp(i_Client, Prop_Data, "m_takedamage", 0, 1)
							
							if (IsPlayerOnFire(i_Client))
								ExtinguishEntity(i_Client)
								
							new Handle:h_Pack = CreateDataPack()
							WritePackCell(h_Pack, i_Client)
							WritePackCell(h_Pack, i_Target)
							CreateTimer(0.1, SetWitchControl, h_Pack)
							g_PlayerGameTime[i_Client] = GetGameTime() - 2.0
						}
					}
				}
			
			}
		}
		
		return Plugin_Continue
	}
		
	decl i_Witch, b_WitchMoved, i_Health, Float:f_GameTime, i_Sequence, Float:f_Rage, i_Flags
	
	b_WitchMoved = false
	i_Witch = g_b_WitchControl[i_Client]
	
	if (!IsValidEdict(i_Witch))
	{
		RemoveWitchControl(i_Client, i_Witch)
		
		return Plugin_Continue
	}
	
	i_Health = GetEntProp(i_Witch, Prop_Data, "m_iHealth")
	
	if (i_Health <= 0)
	{
		RemoveWitchControl(i_Client, i_Witch)
		
		return Plugin_Continue
	}
	else
		SetEntProp(i_Client, Prop_Data, "m_iHealth", i_Health)
	
	f_GameTime = GetGameTime()
	i_Sequence = GetEntProp(i_Witch, Prop_Data, "m_nSequence")
	f_Rage = GetEntPropFloat(i_Witch, Prop_Send, "m_rage")
	i_Flags = GetEntityFlags(i_Witch)
		
	if (i_Buttons & IN_USE)
	{
		if (f_GameTime - g_PlayerGameTime[i_Client] > 3.5 || 0.0 < f_GameTime - g_PlayerGameTime[i_Client] < 2.0)
		{
			if (g_b_OnLadder[i_Client])
				return Plugin_Continue
		
			RemoveWitchControl(i_Client, i_Witch)
			g_PlayerGameTime[i_Client] = GetGameTime()
			i_Buttons &= ~IN_USE
			
			return Plugin_Continue
		}
	}
		
	if (f_Rage)
	{
		if (i_Buttons & IN_ATTACK && GetConVarInt(h_CvarAttack))
			WitchAttack(i_Client, i_Witch)
		
		if (g_WitchLadderOrigin[i_Client])
			g_WitchLadderOrigin[i_Client] = 0.0
		
		if (i_Flags & FL_FROZEN)
			SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_FROZEN)
			
		return Plugin_Continue
	}
	
	if (GetEntProp(i_Witch, Prop_Send, "m_bIsBurning"))
		return Plugin_Continue
	
	if (GetEntPropEnt(i_Witch, Prop_Data, "m_hGroundEntity") == -1)
	{
		if (!g_b_OnLadder[i_Client] && !g_b_WitchJump[i_Client])
		{
			decl Float:f_Origin[3], Float:f_Angles[3], Float:f_Up[3]
			
			if (i_Flags & FL_FROZEN)
				SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_FROZEN)
				
			GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
			GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
			
			if (g_WitchLadderOrigin[i_Client])
			{
				f_Origin[2] = g_WitchLadderOrigin[i_Client]
				g_WitchLadderOrigin[i_Client] = 0.0
			}
			
			GetAngleVectors(f_Angles, NULL_VECTOR, NULL_VECTOR, f_Up)
			NormalizeVector(f_Up, f_Up)
			ScaleVector(f_Up, -4.0)
			AddVectors(f_Up, f_Origin, f_Origin)
			SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_FALL)
			TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
				
			return Plugin_Continue
		}
	}
	else
	{ 
		if (!g_b_OnLadder[i_Client] && g_WitchLadderOrigin[i_Client])
			g_WitchLadderOrigin[i_Client] = 0.0
			
		if (i_Flags & FL_FROZEN)
			SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_FROZEN)	
	}
	
	if (0.0 < (f_GameTime - g_PlayerGameTime[i_Client]) < 1.0)
		return Plugin_Continue
		
	if (g_b_WitchJump[i_Client])
		return Plugin_Continue
	
	if (i_Buttons & IN_DUCK && !g_b_OnLadder[i_Client])
	{
		if (i_Sequence != ANIM_SITTING)
		{
			SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags | FL_DUCKING)
			SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_SITTING)
		}
		else
		{
			SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_DUCKING)
			SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_STANDING_CRYING)
		}

		g_PlayerGameTime[i_Client] = f_GameTime
		
		i_Buttons &= ~IN_DUCK
		
		return Plugin_Continue
	}
		
	if (i_Buttons & IN_JUMP && !g_b_OnLadder[i_Client] && !(i_Flags & FL_DUCKING))
	{
		if (f_GameTime - g_PlayerGameTime[i_Client] > 3.5 || f_GameTime - g_PlayerGameTime[i_Client] < 2.0)
		{
			g_b_WitchJump[i_Client] = 2.0
			g_PlayerGameTime[i_Client] = f_GameTime - 2.0
		
			return Plugin_Continue
		}
	}
	
	if (i_Buttons & IN_ATTACK && GetConVarInt(h_CvarAttack))
	{
		WitchAttack(i_Client, i_Witch)
		
		return Plugin_Continue
	}
	
	if (i_Buttons & (IN_LEFT|IN_MOVELEFT))
	{
		decl Float:f_Origin[3], Float:f_Angles[3], Float:f_Left[3], Float:f_TraceOrigin[3], Handle:h_Trace
		
		GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
		GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
		
		if (g_b_OnLadder[i_Client])
		{
			if (g_b_OnLadder[i_Client])
			{
				f_TraceOrigin[0] = f_Origin[0]
				f_TraceOrigin[1] = f_Origin[1]
				f_TraceOrigin[2] = f_Origin[2] + 2.0
			}
	
			h_Trace = TR_TraceRayFilterEx(f_TraceOrigin, f_Angles, MASK_ALL, RayType_Infinite, TraceFilterClients, i_Witch)
			
			if (TR_DidHit(h_Trace))
			{
				decl i_Target
		
				i_Target = TR_GetEntityIndex(h_Trace)
	
				if (i_Target)
				{
					GetAngleVectors(f_Angles, NULL_VECTOR, f_Left, NULL_VECTOR)
					NormalizeVector(f_Left, f_Left)
					ScaleVector(f_Left, -1.0)
					AddVectors(f_Left, f_Origin, f_Origin)
					TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
				}
				else
				{
					g_b_OnLadder[i_Client] = false
					f_Origin[2] = g_WitchLadderOrigin[i_Client]
					TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
				}
			}
				
			CloseHandle(h_Trace)
		}
		else
		{
			if (i_Flags & FL_DUCKING)
			{
				f_Angles[1] += 1.0
				SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_TURN_LEFT)
				TeleportEntity(i_Witch, NULL_VECTOR, f_Angles, NULL_VECTOR)
				
				return Plugin_Continue
			}
			else
				f_Angles[1] += 2.0
			
			TeleportEntity(i_Witch, NULL_VECTOR, f_Angles, NULL_VECTOR)
		}
	}	
	
	if (i_Buttons & (IN_RIGHT|IN_MOVERIGHT))
	{
		decl Float:f_Origin[3], Float:f_Angles[3], Float:f_Right[3], Float:f_TraceOrigin[3], Handle:h_Trace
		
		GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
		GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
		
		if (g_b_OnLadder[i_Client])
		{
			if (g_b_OnLadder[i_Client])
			{
				f_TraceOrigin[0] = f_Origin[0]
				f_TraceOrigin[1] = f_Origin[1]
				f_TraceOrigin[2] = f_Origin[2] + 2.0
			}
	
			h_Trace = TR_TraceRayFilterEx(f_TraceOrigin, f_Angles, MASK_ALL, RayType_Infinite, TraceFilterClients, i_Witch)
			
			if (TR_DidHit(h_Trace))
			{
				decl i_Target
		
				i_Target = TR_GetEntityIndex(h_Trace)
	
				if (i_Target)
				{
					GetAngleVectors(f_Angles, NULL_VECTOR, f_Right, NULL_VECTOR)
					NormalizeVector(f_Right, f_Right)
					ScaleVector(f_Right, 1.0)
					AddVectors(f_Right, f_Origin, f_Origin)
					TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
				}
				else
				{
					g_b_OnLadder[i_Client] = false
					f_Origin[2] = g_WitchLadderOrigin[i_Client]
					TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
				}
			}
			
			CloseHandle(h_Trace)
		}
		else
		{
			if (i_Flags & FL_DUCKING)
			{
				f_Angles[1] -= 1.0
				SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_TURN_RIGHT)
				TeleportEntity(i_Witch, NULL_VECTOR, f_Angles, NULL_VECTOR)
				
				return Plugin_Continue
			}
			else
				f_Angles[1] -= 2.0
				
			TeleportEntity(i_Witch, NULL_VECTOR, f_Angles, NULL_VECTOR)
		}
	}
	
	if (i_Flags & FL_DUCKING)
	{
		SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_SITTING)
		return Plugin_Continue
	}
		
	if (i_Buttons & IN_FORWARD)
	{
		decl Float:f_Origin[3], Float:f_Angles[3], Float:f_Forward[3], Float:f_TraceOrigin[3], Handle:h_Trace, bool:b_LadderTrace
		
		b_WitchMoved = true
		
		GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
		GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
		
		if (g_b_OnLadder[i_Client])
		{
			b_LadderTrace = true
			f_TraceOrigin[0] = f_Origin[0]
			f_TraceOrigin[1] = f_Origin[1]
			f_TraceOrigin[2] = f_Origin[2]
		}
		else
		{
			b_LadderTrace = false
			f_TraceOrigin[0] = f_Origin[0]
			f_TraceOrigin[1] = f_Origin[1]
			f_TraceOrigin[2] = f_Origin[2] + 20.0
		}

		if (b_LadderTrace || !g_PlayerTraceTimer[i_Client] || (f_GameTime - g_PlayerTraceTimer[i_Client] >= 0.5))
		{
			h_Trace = TR_TraceRayFilterEx(f_TraceOrigin, f_Angles, MASK_ALL, RayType_Infinite, TraceFilterClients, i_Witch)
			g_PlayerTraceTimer[i_Client] = f_GameTime
		
			if (TR_DidHit(h_Trace))
			{
				decl Float:f_EndOrigin[3], String:s_ClassName[20], i_Target
	
				i_Target = TR_GetEntityIndex(h_Trace)
				TR_GetEndPosition(f_EndOrigin, h_Trace)

				if (i_Target)
				{
					if (IsValidEdict(i_Target))
					{
						GetEdictClassname(i_Target, s_ClassName, sizeof(s_ClassName))
						if (StrEqual(s_ClassName, "func_simpleladder"))
						{
							if (GetVectorDistance(f_Origin, f_EndOrigin) <= 25.0)
							{
								g_b_OnLadder[i_Client] = true
								SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_LADDER_ASCEND)
								if (!g_WitchLadderOrigin[i_Client])
								{
									f_Origin[2] += 15.0
									g_WitchLadderOrigin[i_Client] = f_Origin[2]
								}
								g_WitchLadderOrigin[i_Client] += 3.0
								
								CloseHandle(h_Trace)
							
								return Plugin_Continue
							}
						}
					}
				}
				else if (g_b_OnLadder[i_Client])
				{
					g_b_OnLadder[i_Client] = false
					SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_FROZEN)
				}
			}
			
			CloseHandle(h_Trace)
		}
		
		GetAngleVectors(f_Angles, f_Forward, NULL_VECTOR, NULL_VECTOR)
		NormalizeVector(f_Forward, f_Forward)
		ScaleVector(f_Forward, GetConVarFloat(h_CvarWitchSpeed))
		AddVectors(f_Forward, f_Origin, f_Origin)
		SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_WALK)
		TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
	}
	
	if (i_Buttons & IN_BACK && g_b_OnLadder[i_Client])
	{
		decl Float:f_Origin[3], Float:f_Angles[3], Handle:h_Trace
		
		b_WitchMoved = true
		
		GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
		GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
		
		h_Trace = TR_TraceRayFilterEx(f_Origin, f_Angles, MASK_ALL, RayType_Infinite, TraceFilterClients, i_Witch)
		
		if (TR_DidHit(h_Trace))
		{
			decl Float:f_EndOrigin[3], String:s_ClassName[20], i_Target
	
			i_Target = TR_GetEntityIndex(h_Trace)
			
			if (i_Target > 0 && IsValidEdict(i_Target))
			{
				GetEdictClassname(i_Target, s_ClassName, sizeof(s_ClassName))
				if (StrEqual(s_ClassName, "func_simpleladder"))
				{
					TR_GetEndPosition(f_EndOrigin, h_Trace)
					if (GetVectorDistance(f_Origin, f_EndOrigin) <= 15.0)
					{
						g_b_OnLadder[i_Client] = true
						SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_LADDER_DESCEND)
						f_Origin[2] = g_WitchLadderOrigin[i_Client]
						g_WitchLadderOrigin[i_Client] -= 3.0
						
						CloseHandle(h_Trace)
						
						return Plugin_Continue
					}
				}
			}
			else if (g_b_OnLadder[i_Client])
			{
				g_b_OnLadder[i_Client] = false
				SetEntProp(i_Witch, Prop_Send, "m_fFlags", i_Flags & ~FL_FROZEN)
			}
		}	
		
		CloseHandle(h_Trace)
	}

	if (!b_WitchMoved && !g_b_OnLadder[i_Client] && !(i_Flags & FL_DUCKING))
		SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_STANDING_CRYING)
		
	return Plugin_Continue
}

public OnGameFrame()
{
	decl i_Client, i_Witch, Float:f_Angles[3], Float:f_Origin[3], Float:f_Forward[3], Float:f_Up[3]
	
	for (i_Client = 1; i_Client <= MaxClients; i_Client++)
	{
		i_Witch = g_b_WitchControl[i_Client]
		
		if (g_b_WitchJump[i_Client])
		{
			if (i_Witch && IsValidEdict(i_Witch))
			{
				g_b_WitchJump[i_Client] += 0.1
				
				GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
				GetEntPropVector(i_Witch, Prop_Send, "m_angRotation", f_Angles)
				GetAngleVectors(f_Angles, f_Forward, NULL_VECTOR, f_Up)
				NormalizeVector(f_Forward, f_Forward)
				NormalizeVector(f_Up, f_Up)

				if (g_b_WitchJump[i_Client] <= 3.0)
				{
					ScaleVector(f_Forward, g_b_WitchJump[i_Client])
					ScaleVector(f_Up, g_b_WitchJump[i_Client] * 3.0)
				}
				else if (g_b_WitchJump[i_Client] <= 4.0)
				{
					ScaleVector(f_Forward, g_b_WitchJump[i_Client])
					ScaleVector(f_Up, g_b_WitchJump[i_Client] / 3.0)
				}
				else
						g_b_WitchJump[i_Client] = 0.0			
				
				AddVectors(f_Forward, f_Origin, f_Origin)
				AddVectors(f_Up, f_Origin, f_Origin)
				SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_JUMP)
				
				TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
			}
		}
		else if	(g_b_OnLadder[i_Client])
		{
			if (i_Witch && IsValidEdict(i_Witch))
			{
				GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
				if (f_Origin[2] == g_WitchLadderOrigin[i_Client])
					SetEntProp(i_Witch, Prop_Send, "m_fFlags", GetEntityFlags(i_Witch) | FL_FROZEN)
				else
					SetEntProp(i_Witch, Prop_Send, "m_fFlags", GetEntityFlags(i_Witch) & ~FL_FROZEN)
					
				f_Origin[2] = g_WitchLadderOrigin[i_Client]
				TeleportEntity(i_Witch, f_Origin, NULL_VECTOR, NULL_VECTOR)
			}
		}
	}
}

public WitchAttack(i_Client, i_Witch)
{
	if (g_b_OnLadder[i_Client])
		g_b_OnLadder[i_Client] = false
		
	SetEntPropFloat(i_Witch, Prop_Send, "m_rage", 1.0)
	SetEntProp(i_Witch, Prop_Send, "m_mobRush", 1)
}

public Action:TeleportPlayer(Handle:h_Timer, any:i_Client)
{
	decl i_Witch, Float:f_Origin[3]
	
	i_Witch = g_b_WitchControl[i_Client]
	
	if (!IsValidEdict(i_Witch) || !IsClientInGame(i_Client))
	{
		if (g_h_TeleportTimer[i_Client] != INVALID_HANDLE)
		{
			KillTimer(g_h_TeleportTimer[i_Client])
			g_h_TeleportTimer[i_Client] = INVALID_HANDLE
		}	
		
		return Plugin_Handled
	}
	
	GetEntPropVector(i_Witch, Prop_Send, "m_vecOrigin", f_Origin)
	f_Origin[2] += 10.0
	TeleportEntity(i_Client, f_Origin, NULL_VECTOR, NULL_VECTOR)
	
	return Plugin_Continue
}

public bool:TraceFilterClients(i_Entity, i_Mask, any:i_Data)
{
	if (i_Entity == i_Data)
		return false
		
	if (1 <= i_Entity <= MaxClients)
		return false
		
	return true
}

public RemoveWitchControl(i_Client, i_Witch)
{
	decl Float:f_Origin[3], i_Sequence, Float:f_Rage
	
	if (g_h_TeleportTimer[i_Client] != INVALID_HANDLE)
	{
		KillTimer(g_h_TeleportTimer[i_Client])
		g_h_TeleportTimer[i_Client] = INVALID_HANDLE
	}	

	g_b_WitchControl[i_Client] = 0
	g_b_OnLadder[i_Client] = false
	
	if (IsValidEdict(i_Witch))
	{
		i_Sequence = GetEntProp(i_Witch, Prop_Data, "m_nSequence")
		f_Rage = GetEntPropFloat(i_Witch, Prop_Send, "m_rage")
	
		if (i_Sequence != ANIM_SITTING && !f_Rage)
		{
			SetEntProp(i_Witch, Prop_Send, "m_fFlags", GetEntityFlags(i_Witch) | FL_DUCKING)
			
			if (!GetEntProp(i_Witch, Prop_Send, "m_bIsBurning"))
				SetEntProp(i_Witch, Prop_Data, "m_nSequence", ANIM_SITTING)
		}
			
		SetEntPropEnt(i_Witch, Prop_Data, "m_hOwnerEntity", -1)
	}
	
	GetClientAbsOrigin(i_Client, f_Origin)
	f_Origin[2] += 50.0
	
	DispatchKeyValue(i_Client, "parentname", "")
	SetVariantString("")
	AcceptEntityInput(i_Client, "SetParent")
	
	if (GetEntProp(i_Client, Prop_Send, "m_zombieClass") != CLASS_TANK)
	{
		ScreenFade(i_Client, 1, 1, {0, 0, 0, 255})
		
		TeleportEntity(i_Client, Float:{0.0, 0.0, 0.0}, NULL_VECTOR, NULL_VECTOR)
		ForcePlayerSuicide(i_Client)
		
		new Handle:h_Pack = CreateDataPack()
		WritePackCell(h_Pack, i_Client)
		WritePackFloat(h_Pack, f_Origin[0])
		WritePackFloat(h_Pack, f_Origin[1])
		WritePackFloat(h_Pack, f_Origin[2])
	
		CreateTimer(1.0, ReturnCamera, h_Pack)
	}
	
	SetClientViewEntity(i_Client, i_Client)
}

public Action:ReturnCamera(Handle:h_Timer, Handle:h_Pack)
{
	decl Float:f_Origin[3], Float:f_Angles[3], i_Client
	
	ResetPack(h_Pack, false)
	i_Client = ReadPackCell(h_Pack)
	f_Origin[0] = ReadPackFloat(h_Pack)
	f_Origin[1] = ReadPackFloat(h_Pack)
	f_Origin[2] = ReadPackFloat(h_Pack)
	CloseHandle(h_Pack)
		
	f_Angles[0] = 0.0
	f_Angles[1] = GetRandomFloat(-180.0, 180.0)
	f_Angles[2] = 0.0
	
	if (IsClientInGame(i_Client))
		TeleportEntity(i_Client, f_Origin, f_Angles, NULL_VECTOR)
}

public ScreenFade(i_Client, i_Duration, i_Time, const i_Color[4])
{
	new Handle:h_Screen = StartMessageOne("Fade", i_Client)
	
	if (h_Screen != INVALID_HANDLE)
	{
		BfWriteShort(h_Screen, i_Duration*400)
		BfWriteShort(h_Screen, i_Time*400)
		BfWriteShort(h_Screen, FADE_IN)
		BfWriteByte(h_Screen, i_Color[0])
		BfWriteByte(h_Screen, i_Color[1])
		BfWriteByte(h_Screen, i_Color[2])
 		BfWriteByte(h_Screen, i_Color[3])
		EndMessage()
	}
}

public bool:IsPlayerOnFire(i_Client)
{
	if (GetEntityFlags(i_Client) & FL_ONFIRE)
		return true
	
	return false
}