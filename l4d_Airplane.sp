/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2 & L4D] Airdop
*	Author	:	BHaType
*	Descrp	:	Admin can call airdrop.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=317108
*	Plugins	:	https://www.sourcemod.net/plugins.php?cat=0&mod=6&title=&author=BHaType&description=&search=1

========================================================================================
	Change Log:
1.4 (7 - 07 - 19):
	- maybe fixed crash
	- Added voice for pilot
	
1.3 (5 - 07 - 19):
	- Fixed crash (Ehhh)

1.2 (5 - 07 - 19):
	- Fixed bugs (Thanks phoenix0001 for reporting)

1.1 (5 - 07 - 19):
	- Added cvars
	- Some optimization

1.0 (4 - 07 - 19)
	- Added cvar & command
	- Update by Aya Supay
	- Thanks Aya Supay for adding support different languages and support l4d1 also vocalize for l4d1.

0.9 (3 - 07 - 19)
	- Full optimize
	- Fixed memory leak
	- Fixed weapon drop
	- Removed cvar to change count of items for L4D2.

0.8 (3 - 07 - 19)
	- Removed cvar 
	- New system of spawn weapons

0.7 (3 - 07 - 19)
	- Fixed error (Which cause to crash the server)
	- Thanks disawar1 for improve my code
	- Added cvar to disable messages
	- Added new system of chances
	- Removed bad cvars
	- Added config to setting a chances of weapons (data/weapon_chances.cfg)
	- Fixed spawn weapons

0.6 (29 - 06 - 19)
	- Added module to create a triggers for airdrops (Need test)
	- Fixed errors (Need tests)

0.5 (29 - 06 - 19)
	- Now you can use the parachute (Thanks Aya Supay for his model)
	- Fixed some maps
	- Added cvars
	- New method for obtaining coordinates

0.4 (27 - 06 - 19)
	- Fixed ammo
	- Added vocalize (Only for L4D2 survivors)
	- Added flare (Thanks to Silver)
	- Added a lot of cvars.
	- Admin can choose which weapons should be in airdrop.
	- Fixed error (String formatted incorrectly - parameter 2 (total 1))
	- Fixed map c5m1

0.3 (29 - 06 - 19)
	- Added some cvars
	- Added support l4d1
	- Fixed ammo

0.2 (28 - 06 - 19)
	- Airdrop may fall when killing the tank with some chance

0.1 (27 - 06 - 19)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Silvers", "Aya Supay" for helping me made this plugin.
	https://forums.alliedmods.net/showthread.php?t=317108

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define SOUND_PASS1			"animation/c130_flyby.wav"
#define CONFIG_CHANCE		"data/weapon_chances.cfg"

#define PARTICLE_FLARE		"flare_burning"
#define PARTICLE_FUSE		"weapon_pipebomb_fuse"
#define SOUND_CRACKLE		"ambient/fire/fire_small_loop2.wav"
#define MODEL_FLARE			"models/props_lighting/light_flares.mdl"

#define MAXLIST 26
#define MAXENTITIES 128
#define USE_SIMPLECOMBAT	true

#if defined(USE_SIMPLECOMBAT) && USE_SIMPLECOMBAT
#include <l4d2_simple_combat>
#endif

// ====================================================================================================
//					VARIEBLES
// ====================================================================================================

int gIndexCrate[2048+1], g_iFlares[2048+1][5], g_iParachute[2048+1];
ConVar 	cTankChance, cCountAirdrops, cTimeOpen, cColorFlare, cFlare, cFlareLenght, 
		cFlareAplha, cGlowRange, cVocalize, cCustomModel, cParachuteSpeed, cMessages, 
		cAirHeight, cRemoveCrate, cRemoveItems, cTimerPlane, cItemsCount;
bool IsLeft4Dead2, gFlares[2048+1], bKill[2048+1];
Handle hTimer[2048], hTimerPlane;

public Plugin myinfo =
{
	name = "空投物资",
	author = "BHaType",
	description = "Admin can call airdrop.",
	version = "1.5",
	url = "https://www.sourcemod.net/plugins.php?cat=0&mod=-1&title=&author=BHaType&description=&search=1"
}

static const char gModeList[3][] =
{
    "models/props_vehicles/c130.mdl",
    "models/props_crates/supply_crate02.mdl",
    "models/props_crates/supply_crate02_gib1.mdl"
};

static const char gSoundsPilot[][] =
{
	"npc/planepilot/RadioCombatColor28.wav",
	"npc/planepilot/RadioCombatColor29.wav",
	"npc/planepilot/RadioCombatColor08.wav"
};

static int gItemsChances[MAXLIST + 11] =
{
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0
};

static const char gItemsList[MAXLIST + 11][] =
{
	"weapon_autoshotgun", 		//0
	"weapon_first_aid_kit",		//1
	"weapon_pipe_bomb",			//2
	"weapon_molotov",			//3
	"weapon_rifle",				//4
	"weapon_hunting_rifle",		//5
	"weapon_pain_pills",		//6
	"weapon_pistol",			//7
    "weapon_adrenaline",		//8
	"weapon_smg_mp5",			//9
	"weapon_smg",				//10
    "weapon_smg_silenced",		//11
	"weapon_pumpshotgun",		//12
    "weapon_shotgun_chrome",	//13
    "weapon_rifle_m60",			//14
	"weapon_shotgun_spas",		//15
    "weapon_sniper_military",	//16
	"weapon_rifle_ak47",		//17
	"weapon_rifle_desert",		//18
	"weapon_sniper_awp",		//19
	"weapon_rifle_sg552",		//20
	"weapon_sniper_scout",		//21
	"weapon_grenade_launcher",	//22
	"weapon_pistol_magnum",		//23
	"weapon_vomitjar",			//24
	"weapon_defibrillator",		//25
	"fireaxe",
	"frying_pan",
	"machete",
	"baseball_bat",
	"crowbar",
	"cricket_bat",
	"tonfa",
	"katana",
	"electric_guitar",
	"golfclub",
	"knife"
};

static const char gModelsItemsList[MAXLIST + 11][] =
{
	"models/w_models/weapons/w_autoshot_m4super.mdl", 	//0
	"models/w_models/weapons/w_eq_Medkit.mdl", 			//1
	"models/w_models/weapons/w_eq_pipebomb.mdl", 		//2
	"models/w_models/weapons/w_eq_molotov.mdl", 		//3
	"models/w_models/weapons/w_rifle_m16a2.mdl", 		//4
	"models/w_models/weapons/w_sniper_mini14.mdl", 		//5
	"models/w_models/weapons/w_eq_painpills.mdl", 		//6
	"models/w_models/weapons/w_pistol_a.mdl", 			//7
	"models/w_models/weapons/w_eq_adrenaline.mdl", 		//8
	"models/w_models/weapons/w_smg_mp5.mdl", 			//9
	"models/w_models/weapons/w_smg_uzi.mdl", 			//10
	"models/w_models/weapons/w_smg_a.mdl",				//11
	"models/w_models/weapons/w_shotgun.mdl", 			//12
	"models/w_models/weapons/w_pumpshotgun_a.mdl",		//13
	"models/w_models/weapons/w_m60.mdl", 				//14
	"models/w_models/weapons/w_shotgun_spas.mdl",		//15
	"models/w_models/weapons/w_sniper_military.mdl", 	//16
	"models/w_models/weapons/w_rifle_ak47.mdl",			//17
	"models/w_models/weapons/w_desert_rifle.mdl", 		//18
	"models/w_models/weapons/w_sniper_awp.mdl", 		//19
	"models/w_models/weapons/w_rifle_sg552.mdl", 		//20
	"models/w_models/weapons/w_sniper_scout.mdl", 		//21
	"models/w_models/weapons/w_grenade_launcher.mdl", 	//22
	"models/w_models/weapons/w_desert_eagle.mdl", 		//23
	"models/w_models/weapons/w_eq_bile_flask.mdl", 		//24
	"models/w_models/weapons/w_eq_defibrillator.mdl",	//25
	"models/weapons/melee/v_fireaxe.mdl",				//26
	"models/weapons/melee/v_frying_pan.mdl",			//27
	"models/weapons/melee/v_machete.mdl",				//28
	"models/weapons/melee/v_bat.mdl",					//29
	"models/weapons/melee/v_crowbar.mdl",				//30
	"models/weapons/melee/v_cricket_bat.mdl",			//31
	"models/weapons/melee/v_tonfa.mdl",					//32
	"models/weapons/melee/v_katana.mdl",				//33
	"models/weapons/melee/v_electric_guitar.mdl",		//34
	"models/weapons/melee/v_golfclub.mdl",				//35
	"models/v_models/v_knife_t.mdl"						//36
};

static int gAmmoList[MAXLIST + 11] =
{
	90,
	-1,
	-1,
	-1,
	360,
	150,
	-1,
	-1,
	-1,
	650,
	650,
	650,
	56,
	56,
	-1,
	90,
	180,
	360,
	360,
	180,
	360,
	180,
	30,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1
};

static char gStringTable[2][] =
{
	"flare_burning",
	"weapon_pipebomb_fuse"
};

// ====================================================================================================
//					NATIVES
// ====================================================================================================

public int CallAirdrop_NAT(Handle plugin, int numParams)
{
	float vPos[3];
	GetNativeArray(2, vPos, sizeof vPos);
	AirPlane(GetNativeCell(1), vPos);
}

// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2) {
		IsLeft4Dead2 = true;		
	}
	else if (test != Engine_Left4Dead) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("Airdrop", CallAirdrop_NAT);
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d_airdrop.phrases"); // Aya Supay
	
	RegAdminCmd("sm_ac130", CallAirdrop, ADMFLAG_ROOT);
	RegAdminCmd("sm_reload_config", ReloadConfig, ADMFLAG_ROOT);
	HookEvent("tank_killed", EventTank);
	HookEvent("round_start", RoundS);
	HookEvent("round_end", RoundE);
	//HookEvent("round_end", RoundE);
	
	cFlare 				=		CreateConVar("airdrop_flare"			, 	"1"			, "照明弹"												, FCVAR_NONE);
	cColorFlare 		=  		CreateConVar("airdrop_flare_color"		, 	"25 25 255"	, "照明弹颜色"												, FCVAR_NONE);
	cFlareLenght 		=  		CreateConVar("airdrop_flare_length"		, 	"75"		, "照明弹烟雾高度"								, FCVAR_NONE);
	cFlareAplha 		=  		CreateConVar("airdrop_flare_alpha"		, 	"255"		, "照明弹烟雾透明度"									, FCVAR_NONE);
	cTimeOpen 			= 		CreateConVar("airdrop_open_time"		, 	"2.5"		, "开箱时间"												, FCVAR_NONE);
	cCountAirdrops 		= 		CreateConVar("airdrop_count_airdrops"	, 	"3"			, "空投数量"										, FCVAR_NONE);
	cTankChance 		= 		CreateConVar("airdrop_tank_chance"		, 	"50"		, "开箱开出克几率"									, FCVAR_NONE);
	cVocalize 			=		CreateConVar("airdrop_vocalize_chance"	, 	"40"		, "开箱说话几率"										, FCVAR_NONE);	
	cGlowRange			=		CreateConVar("airdrop_glow_range"		, 	"500"		, "光圈范围"						, FCVAR_NONE);
	cCustomModel		=		CreateConVar("airdrop_use_custom_model"	, 	"0"			, "是否使用降落伞模型"	, FCVAR_NONE);
	cParachuteSpeed 	=		CreateConVar("airdrop_parachute_speed"	, 	"60.0"		, "落地速度(降落伞)"		, FCVAR_NONE);
	cMessages 			=		CreateConVar("airdrop_enable_message"	, 	"0"			, "显示提示"										, FCVAR_NONE);
	cAirHeight 			=		CreateConVar("airdrop_height"			, 	"400"		, "空投起始高度"											, FCVAR_NONE);
	cRemoveCrate 		=		CreateConVar("airdrop_remove_time"		, 	"60"		, "箱子多少秒后消失"					, FCVAR_NONE);
	cTimerPlane			=		CreateConVar("airdrop_plane_time"		, 	"120"		, "空投间隔"									, FCVAR_NONE);
	cItemsCount			=		CreateConVar("airdrop_count_items"		, 	"6"			, "空投物品数量"								, FCVAR_NONE);
	cRemoveItems		=		CreateConVar("airdrop_delete_item_time"	, 	"60"		, "空投物品多少秒后消失"					, FCVAR_NONE);
	
	AutoExecConfig(true, "l4d_Airplane");
	HookConVarChange(cCustomModel, CvarChanged);
	LoadPercents();
	
#if defined(USE_SIMPLECOMBAT) && USE_SIMPLECOMBAT
	CreateTimer(1.0, Timer_RegisterSimpleCombat);
#endif
}

#if defined(USE_SIMPLECOMBAT) && USE_SIMPLECOMBAT
public Action Timer_RegisterSimpleCombat(Handle timer, any unused)
{
	SC_CreateSpell("airdrop_ac130", "呼叫空投", 100, 5000, "在瞄准位置呼叫空投补给\nsm_ac130");
	return Plugin_Continue;
}

public void SC_OnUseSpellPost(int client, const char[] classname)
{
	if(StrEqual(classname, "airdrop_ac130", false))
		CallAirdrop(client, 0);
}
#endif

public void CvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	if (!IsModelPrecached("models/props_crates/supply_crate02_custom.mdl")) PrecacheModel("models/props_crates/supply_crate02_custom.mdl");
}

public void OnMapStart()
{
	for (int i = 0; i < 3; i++)
		PrecacheModel(gModeList[i], true);

	int max = MAXLIST - 18;
	if( IsLeft4Dead2 ) max = MAXLIST + 11;

	for( int i = 0; i < max; i++ )
		PrecacheModel(gModelsItemsList[i], true);

	PrecacheSound(SOUND_CRACKLE);
	PrecacheModel(MODEL_FLARE);

	if(cCustomModel.IntValue)
		if (!IsModelPrecached("models/props_crates/supply_crate02_custom.mdl")) PrecacheModel("models/props_crates/supply_crate02_custom.mdl");

	for(int i = 0; i < 2; i++)
		PrecacheParticle(gStringTable[i]);
	for(int i; i < sizeof gItemsList; i++)
		PrecacheSound(gItemsList[i], true);
		
	for(int i; i < sizeof gSoundsPilot; i++)
		PrecacheSound(gSoundsPilot[i], true);
		
	int iEntity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(iEntity, "model", "models/props_vehicles/c130.mdl");
	DispatchSpawn(iEntity); 
	ActivateEntity(iEntity); 
     
	SetVariantString("OnUser1 !self:Kill::0.1:-1"); 
	AcceptEntityInput(iEntity, "AddOutput"); 
	AcceptEntityInput(iEntity, "FireUser1");
}

// ====================================================================================================
//					COMMANDS
// ====================================================================================================

public Action CallAirdrop(int client, int args)
{
	float vPos[3];
	AirPlane(client, vPos);
	if(cMessages.IntValue) CPrintToChatAll("%t", "call_airdrop", client);
	return Plugin_Handled;
}

public Action ReloadConfig(int client, int args)
{
	LoadPercents();
	return Plugin_Handled;

}

// ====================================================================================================
//					EVENTS / CONFIG / PRECACHE
// ====================================================================================================

public Action RoundS(Event event, const char[] name, bool dontbroadcast)
{	
	hTimerPlane = CreateTimer(cTimerPlane.FloatValue, Starting, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundE(Event event, const char[] name, bool dontbroadcast)
{	
	if(hTimerPlane != null)
		delete hTimerPlane;
}

public Action EventTank(Event event, const char[] name, bool dontbroadcast)
{
	if(GetRandomInt(1, 100) <= cTankChance.IntValue)
	{
		float vPos[3];
		int client = GetClientOfUserId(event.GetInt("userid"));
		AirPlane(client, vPos);
	}
}

void LoadPercents()
{	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_CHANCE);
	KeyValues hFile = new KeyValues("drop_weapons");
	if(!FileExists(sPath))
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
		
		if(IsLeft4Dead2)
		{
		    if(KvJumpToKey(hFile, "weapons", true))
		    {
			    for( int i = 0; i < MAXLIST + 11; i++ )
				    hFile.SetNum(gItemsList[i], 0);
			    hFile.Rewind();
			    hFile.ExportToFile(sPath);
			}
		}
		else
		{
		    if(KvJumpToKey(hFile, "weapons_l4d1", true))
		    {
			    for( int i = 0; i < MAXLIST - 18; i++ )
				    hFile.SetNum(gItemsList[i], 0);
			    hFile.Rewind();
			    hFile.ExportToFile(sPath);
			}
		}
		ReloadConfig(0, 0);
	}
	else
	{
	    if(IsLeft4Dead2)
		{
		    if(hFile.ImportFromFile(sPath))
		    {
			    if(KvJumpToKey(hFile, "weapons", true))
				    for( int i = 0; i < MAXLIST + 11; i++ )
					    gItemsChances[i] = hFile.GetNum(gItemsList[i]);
			}
		}
		else
		{
		    if(hFile.ImportFromFile(sPath))
		    {
			    if(KvJumpToKey(hFile, "weapons_l4d1", true))
				    for( int i = 0; i < MAXLIST - 18; i++ )
					    gItemsChances[i] = hFile.GetNum(gItemsList[i]);
			}
		}
	}
	delete hFile;
}

void PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}

// ====================================================================================================
//					TIMERS
// ====================================================================================================

public Action Starting(Handle timer)
{
	int index = -1;
	float vPos[3];
	for (int i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			index = i;
			break;
		}
	}
	if(index != -1)
		AirPlane(index, vPos);
}

public Action TimerDropAirDrop(Handle timer, int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity != INVALID_ENT_REFERENCE)
	{
		float vPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		CreateCrates(vPos);
	}
}

public Action tToDeleteItems(Handle timer, any entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity != INVALID_ENT_REFERENCE)
	{
		if(GetEntProp(entity, Prop_Send, "m_hOwner") < 1)
			AcceptEntityInput(entity, "kill");
	}
}

public Action tSetGravity(Handle timer, any entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity != INVALID_ENT_REFERENCE)
	{
		float vSpeed[3], vPos[3], vAng[3], vEndPos[3];
		int iGravity;
		char sColor[12];
		vAng[0] = 89.0;
		Handle hTrace;
		vSpeed[2] = float(cParachuteSpeed.IntValue) * -1;
		if(cCustomModel.IntValue)
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vSpeed);
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		hTrace = TR_TraceRayFilterEx(vPos, vAng, CONTENTS_SOLID, RayType_Infinite, TraceDontHitSelf, entity);
		if(TR_DidHit(hTrace))
		{
			TR_GetEndPosition(vEndPos, hTrace);
			float vDistance = GetVectorDistance(vPos, vEndPos);
			if(vDistance < 20.5)
			{
				if(cFlare.IntValue)
				{
					GetConVarString(cColorFlare, sColor, sizeof sColor);
					vAng[0] = 0.0;
					vPos[0] += 25.0;
					vPos[2] -= 12.0;
					MakeFlare(entity, vAng, vPos, sColor, sColor);
					gFlares[entity] = true;
				}
				if(cCustomModel.IntValue)
				{
					iGravity = EntRefToEntIndex(g_iParachute[entity]);	
					if(iGravity != INVALID_ENT_REFERENCE)
						AcceptEntityInput(iGravity, "kill");
				}
				hTimer[entity] = null;
				bKill[entity] = true;
				return Plugin_Stop;
			}
		}
		delete hTrace;
	}
	else
		return Plugin_Stop;
	return Plugin_Continue;
}

// ====================================================================================================
//					MAIN SYSTEM / CREATE AC130 / CREATE CRATES / RANDOM WEAPONS
// ====================================================================================================

void AirPlane(int client, float vPos[3])
{
	if(!client) return;
	float vAng[3], vEndPos[3], direction[3];
	vAng[0] = -89.00;
	Handle hTrace;
	if(vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0)
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
		vPos[2] += 90;
	}
	
	hTrace = TR_TraceRayFilterEx(vPos, vAng, CONTENTS_SOLID, RayType_Infinite, TraceDontHitSelf, client);
	if(TR_DidHit(hTrace))
	{
		GetClientAbsAngles(client, vAng);
		GetAngleVectors(vAng, direction, NULL_VECTOR, NULL_VECTOR);
		TR_GetEndPosition(vEndPos, hTrace);
		vEndPos[2] += cAirHeight.IntValue;
		int entity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(entity, "targetname", "ac130");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "model", gModeList[0]);
		TeleportEntity(entity, vEndPos, vAng, NULL_VECTOR);
		DispatchSpawn(entity);
		
		EmitSoundToAll(SOUND_PASS1, entity, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);
		SetVariantString("airport_intro_flyby");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");

		SetVariantString("OnUser1 !self:Kill::20.19:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		CreateTimer(6.4, TimerDropAirDrop, EntIndexToEntRef(entity));
	}
	delete hTrace;
}

void CreateCrates(float vPos[3])
{
	char sUseString[56], sTimeOpen[16], sOutput[24];
	int entity, iTrigger, iGravity, count;
	float vAng[3];
	vAng[0] = 89.0;
	vPos[2] -= cAirHeight.IntValue;
	Format(sUseString, sizeof sUseString, "%t", "use_string");
	GetConVarString(cTimeOpen, sTimeOpen, sizeof sTimeOpen);
		
	count = cCountAirdrops.IntValue;
	for(int i; i < count; i++)
	{
		vPos[1] += GetRandomInt(-120, 120);
		vPos[0] += GetRandomInt(-120, 120);
		entity = CreateEntityByName("prop_physics_override");
		DispatchKeyValue(entity, "targetname", "SupplyDrop");
		DispatchKeyValueVector(entity, "origin", vPos);
		SetEntityModel(entity, gModeList[1]);
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchSpawn(entity);
		EmitSoundToAll(gSoundsPilot[GetRandomInt(0, sizeof gSoundsPilot - 1)], entity, SNDCHAN_AUTO, SNDLEVEL_NONE, view_as<int>(5.0));
		
		Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
		SetVariantString(sOutput);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		
		if(cFlare.IntValue || cCustomModel.IntValue)
		{
			for(int v = MaxClients; v < 2049; v++)
			{
				if(hTimer[v] == null)
				{
					hTimer[v] = CreateTimer(0.1, tSetGravity, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					break;
				}
			}
		}
		
		if(cCustomModel.IntValue)
		{	
			iGravity = CreateEntityByName("prop_dynamic_override");
			SetEntityModel(iGravity, "models/props_crates/supply_crate02_custom.mdl");
			TeleportEntity(iGravity, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(iGravity);
			SetVariantString("!activator");
			AcceptEntityInput(iGravity, "SetParent", entity);
			g_iParachute[entity] = EntIndexToEntRef(iGravity);
		}
	
		iTrigger = CreateEntityByName("func_button_timed");
		DispatchKeyValueVector(iTrigger, "origin", vPos);
		DispatchKeyValue(iTrigger, "use_string", sUseString);
		DispatchKeyValue(iTrigger, "use_time", sTimeOpen);
		DispatchKeyValue(iTrigger, "auto_disable", "1");
		TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iTrigger);
		ActivateEntity(iTrigger);
			
		SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-225.0, -225.0, -225.0}));
		SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({225.0, 225.0, 225.0}));
		HookSingleEntityOutput(iTrigger, "OnTimeUp", OnTimeUp);
		//HookSingleEntityOutput(iTrigger, "OnPressed", OnPressed);
		//HookSingleEntityOutput(iTrigger, "OnUnPressed", OnUnPressed);
		SetEntityModel(iTrigger, gModeList[2]);
		SetEntityRenderMode(iTrigger, RENDER_NONE);
		SetVariantString("!activator");
		AcceptEntityInput(iTrigger, "SetParent", entity);
		if(IsLeft4Dead2)
		{
		    char sColor[16];
		    Format(sColor, sizeof sColor, "255 255 255");
		    SetEntProp(entity, Prop_Send, "m_nGlowRange", cGlowRange.IntValue);
		    SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		    SetEntProp(entity, Prop_Send, "m_glowColorOverride", GetColor(sColor));
		}
		SetEntProp(iTrigger, Prop_Data, "m_takedamage", 0, 1);
		SetEntProp(entity, Prop_Data, "m_takedamage", 0, 1);
		gIndexCrate[iTrigger] = EntIndexToEntRef(entity);
	}
	if(cMessages.IntValue) CPrintToChatAll("%t {white}%.2f %.2f %.2f", "airdrop_coordinates" , vPos[0], vPos[1], vPos[2]);
}

public void OnTimeUp(const char[] output, int caller, int activator, float delay)
{
	if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
	{
		int entity;
		entity = gIndexCrate[caller];
		if((entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
		{
			int OpenedCrate, iFlare;
			float vPos[3], vAng[3];
			AcceptEntityInput(caller, "kill");
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			OpenedCrate = CreateEntityByName("prop_physics_override");
			DispatchKeyValueVector(OpenedCrate, "origin", vPos);
			DispatchKeyValueVector(OpenedCrate, "angles", vAng);
			SetEntityModel(OpenedCrate, gModeList[2]);
			DispatchSpawn(OpenedCrate);
			AcceptEntityInput(entity, "kill");
			RandomWeapon(vPos);
			for(int i = 0; i <= 4; i++)
			{
				if(gFlares[entity])
				{
					iFlare = EntRefToEntIndex(g_iFlares[entity][i]);
					if(iFlare != INVALID_ENT_REFERENCE)
					{
						AcceptEntityInput(iFlare, "kill");
					}
				}
			}
			//int iFlareSound = EntRefToEntIndex(g_iFlares[entity][0]);
			//if(iFlareSound != INVALID_ENT_REFERENCE)
			//	StopSound(iFlareSound, SNDCHAN_AUTO, SOUND_CRACKLE);
			if(cMessages.IntValue)
				for(int i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i)) CPrintToChat(i, "%t", "open_airdrop", activator);
			if(IsLeft4Dead2) 
			    Vocalize(activator, false);
			else
				Vocalize(activator, true);
		}
	}
}

// ====================================================================================================
//					RANDOM ITEM
// ====================================================================================================

void RandomWeapon(float vPos[3])
{
	int iRandom, iWeight, iItem, count;
	float vAng[3];
	vPos[2] += 2.5; vAng[1] = 90.0;
	
	count = cItemsCount.IntValue;
	for (int i = 0; i <= count; i++)
	{
		if(!IsLeft4Dead2) iRandom = GetRandomInt(0, MAXLIST - 18);
		else iRandom = GetRandomInt(0, sizeof gItemsList - 1);
		iWeight = GetRandomInt(1, 100);
		if (iWeight <= gItemsChances[iRandom])
		{
			if (iRandom > 25)
			{
				SpawnMelee(gItemsList[iRandom], vPos);
			}
			else 
			{
				iItem = CreateEntityByName(gItemsList[iRandom]);
				TeleportEntity(iItem, vPos, vAng, NULL_VECTOR);
				DispatchSpawn(iItem);

				SetEntityModel(iItem, gModelsItemsList[iRandom]);
				CreateTimer(cRemoveItems.FloatValue, tToDeleteItems, EntIndexToEntRef(iItem), TIMER_FLAG_NO_MAPCHANGE);
				
				if(gAmmoList[iRandom] != -1)
					SetEntProp(iItem, Prop_Send, "m_iExtraPrimaryAmmo", gAmmoList[iRandom], 4);
			}
		}
	}
}

void SpawnMelee(const char[] Melee, float origin[3])
{
	int iWeapon = CreateEntityByName("weapon_melee");

	if (IsValidEntity(iWeapon))
	{
		DispatchKeyValue(iWeapon, "melee_script_name", Melee);

		DispatchSpawn(iWeapon);

		TeleportEntity(iWeapon, origin, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(cRemoveItems.FloatValue, tToDeleteItems, EntIndexToEntRef(iWeapon), TIMER_FLAG_NO_MAPCHANGE);
		
		char ModelName[128];
		GetEntPropString(iWeapon, Prop_Data, "m_ModelName", ModelName, sizeof ModelName); 
		
		if (StrContains( ModelName, "hunter", false ) != -1)
			AcceptEntityInput(iWeapon, "kill");
	}
}

// ====================================================================================================
//					MAKING FLARE / THANKS TO SILVERS
// ====================================================================================================

int MakeFlare(int client, float vAngles[3], float vOrigin[3], const char[] sColorL, const char[] sColorS)
{
	int entity;
	char sOutput[26];
	
	entity = CreateEntityByName("prop_dynamic");
	if(entity == INVALID_ENT_REFERENCE) return 0;
	
	Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
	SetVariantString(sOutput);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
		
	SetEntityModel(entity, MODEL_FLARE);
	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	DispatchSpawn(entity);
	
	//PlaySound(entity);
	
	g_iFlares[client][0] = EntIndexToEntRef(entity);
	vOrigin[2] += 15.0;
	entity = MakeLightDynamic(vOrigin, view_as<float>({ 90.0, 0.0, 0.0 }), sColorL, 255);
	vOrigin[2] -= 15.0;
	if(entity == INVALID_ENT_REFERENCE) return 0;
	
	Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
	SetVariantString(sOutput);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	g_iFlares[client][1] = EntIndexToEntRef(entity);
	// Position particles / smoke
	entity = 0;
	vAngles[1] = GetRandomFloat(1.0, 360.0);
	vAngles[0] = -80.0;
	vOrigin[0] += (1.0 * (Cosine(DegToRad(vAngles[1]))));
	vOrigin[1] += (1.5 * (Sine(DegToRad(vAngles[1]))));
	vOrigin[2] += 1.0;

	// Flare particles
	entity = DisplayParticle(PARTICLE_FLARE, vOrigin, vAngles);
	if(entity == INVALID_ENT_REFERENCE) return 0;
	
	Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
	SetVariantString(sOutput);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	g_iFlares[client][2] = EntIndexToEntRef(entity);
	// Fuse particles
	entity = DisplayParticle(PARTICLE_FUSE, vOrigin, vAngles);
	if(entity == INVALID_ENT_REFERENCE) return 0;
	
	Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
	SetVariantString(sOutput);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	g_iFlares[client][3] = EntIndexToEntRef(entity);
	// Smoke
	vAngles[0] = -85.0;
	entity = MakeEnvSteam(vOrigin, vAngles, sColorS, cFlareAplha.IntValue, cFlareLenght.IntValue);
	if(entity == INVALID_ENT_REFERENCE) return 0;
	
	Format(sOutput, sizeof(sOutput), "OnUser1 !self:kill::%f:1", cRemoveCrate.FloatValue);
	SetVariantString(sOutput);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	g_iFlares[client][4] = EntIndexToEntRef(entity);
	return 1;
}

int DisplayParticle(const char[] sParticle, const float vPos[3], const float vAng[3])
{
	int entity = CreateEntityByName("info_particle_system");
	if( entity != -1 )
	{
		DispatchKeyValue(entity, "effect_name", sParticle);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "start");
		return entity;
	}
	return 0;
}

int MakeEnvSteam(const float vOrigin[3], const float vAngles[3], const char[] sColor, int iAlpha, int iLength)
{
	int entity = CreateEntityByName("env_steam");
	char sTemp[5];
	DispatchKeyValue(entity, "SpawnFlags", "1");
	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "SpreadSpeed", "1");
	DispatchKeyValue(entity, "Speed", "15");
	DispatchKeyValue(entity, "StartSize", "1");
	DispatchKeyValue(entity, "EndSize", "3");
	DispatchKeyValue(entity, "Rate", "10");
	IntToString(iLength, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "JetLength", sTemp);
	IntToString(iAlpha, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "renderamt", sTemp);
	DispatchKeyValue(entity, "InitialState", "1");
	DispatchKeyValueVector(entity, "origin", vOrigin);
	DispatchKeyValueVector(entity, "angles", vAngles);
	//TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	AcceptEntityInput(entity, "TurnOn");
	DispatchSpawn(entity);
	return entity;
}

/*
void PlaySound(int entity)
{
	EmitSoundToAll(SOUND_CRACKLE, entity, SNDCHAN_AUTO, SNDLEVEL_DISHWASHER, SND_SHOULDPAUSE, SNDVOL_NORMAL, SNDPITCH_HIGH, -1, NULL_VECTOR, NULL_VECTOR);
}
*/

int MakeLightDynamic(const float vOrigin[3], const float vAngles[3], const char[] sColor, int iDist)
{
	int entity = CreateEntityByName("light_dynamic");
	char sTemp[16];
	Format(sTemp, sizeof(sTemp), "6");
	DispatchKeyValue(entity, "style", sTemp);
	Format(sTemp, sizeof(sTemp), "%s 255", sColor);
	DispatchKeyValue(entity, "_light", sTemp);
	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", float(iDist));
	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");
	return entity;
}

// ====================================================================================================
//					VOCALIZE / THANKS TO SILVERS & Aya Supay
// ====================================================================================================

static const char g_sVocalize[][] =
{
	"scenes/Coach/dlc1_c6m1_alarmdoor01.vcd", 			//0
	"scenes/Coach/dlc1_golfclub07.vcd", 				//1
	"scenes/Coach/thanks02.vcd", 						//2
	"scenes/Coach/reactionnegative02.vcd", 				//3
	"scenes/Coach/no02.vcd", 							//4
	"scenes/Gambler/dlc1_c6m1_alarmdoor02.vcd", 		//5
	"scenes/Gambler/dlc1_c6m1_alarmdoor01.vcd", 		//6
	"scenes/Gambler/dlc1_c6m2_phase2jumpinwater02.vcd", //7
	"scenes/Mechanic/dlc1_c6m3_finalebridgerun02.vcd", 	//8
	"scenes/Mechanic/dlc1_m6007.vcd", 					//9
	"scenes/Producer/heardspecialc104.vcd", 			//10
	"scenes/Producer/hurrah01.vcd",						//11
	"scenes/Biker/thanks02.vcd", 						//12 l4d1
	"scenes/Biker/reactionnegative02.vcd", 				//13
	"scenes/Biker/no02.vcd", 							//14
	"scenes/Namvet/help01.vcd", 						//15
	"scenes/Namvet/hurrah02.vcd", 						//16
	"scenes/Namvet/look03.vcd",							//17
	"scenes/Manager/incoming01.vcd", 					//18
	"scenes/Manager/hurrah01.vcd", 						//19
	"scenes/TeenGirl/help01.vcd",						//20
	"scenes/TeenGirl/hurrah01.vcd", 					//21
};

void Vocalize(int client, bool l4d1)
{
	if(GetRandomInt(1, 100) > cVocalize.IntValue)
		return;

	char sTemp[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sTemp, 64);

	int random;
	if(!l4d1)
	{
		if( sTemp[26] == 'c' )							// c = Coach
			random = GetRandomInt(0, 4);
		else if( sTemp[26] == 'g' )						// g = Gambler
			random = GetRandomInt(5, 7);
		else if( sTemp[26] == 'm' && sTemp[27] == 'e' )	// me = Mechanic
			random = GetRandomInt(8, 9);
		else if( sTemp[26] == 'p' )						// p = Producer
			random = GetRandomInt(10, 11);
		else
			return;
	}
	else
	{
		if( sTemp[26] == 'b' )							// b = biker
			random = GetRandomInt(12, 14);
		else if( sTemp[26] == 'n' )						// n = namvet
			random = GetRandomInt(15, 17);
		else if( sTemp[26] == 'm' && sTemp[27] == 'a' )	// m = manager
			random = GetRandomInt(18, 19);
		else if( sTemp[26] == 't' )						// t = teengirl
			random = GetRandomInt(20, 21);
		else
			return;
	}
	int entity = CreateEntityByName("instanced_scripted_scene");
	DispatchKeyValue(entity, "SceneFile", g_sVocalize[random]);
	DispatchSpawn(entity);
	SetEntPropEnt(entity, Prop_Data, "m_hOwner", client);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start", client, client);
}

// ====================================================================================================
//					TRACE FILTERS / GET COLOR
// ====================================================================================================

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

int GetColor(char[] sTemp)
{
	if(strcmp(sTemp, "") == 0)
		return 0;
 
	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, 3, 4);
 
	if( color != 3 )
		return 0;
 
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
 
	return color;
}

// ====================================================================================================
//					THANKS Aya Supay
// ====================================================================================================

/**
*   @note Used for in-line string translation.
*
*   @param  iClient     Client Index, translation is apllied to.
*   @param  format      String formatting rules. By default, you should pass at least "%t" specifier.
*   @param  ...            Variable number of format parameters.
*   @return char[192]    Resulting string. Note: output buffer is hardly limited.
*/
stock char[] Translate(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    return buffer;
}

/**
*   @note Prints a message to a specific client in the chat area. Supports named colors in translation file.
*
*   @param  iClient     Client Index.
*   @param  format        Formatting rules.
*   @param  ...            Variable number of format parameters.
*   @no return
*/
stock void CPrintToChat(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    ReplaceColor(buffer, sizeof(buffer));
    PrintToChat(iClient, "\x01%s", buffer);
}

/**
*   @note Prints a message to all clients in the chat area. Supports named colors in translation file.
*
*   @param  format        Formatting rules.
*   @param  ...            Variable number of format parameters.
*   @no return
*/
stock void CPrintToChatAll(const char[] format, any ...)
{
    char buffer[192];
    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            ReplaceColor(buffer, sizeof(buffer));
            PrintToChat(i, "\x01%s", buffer);
        }
    }
}

/**
*   @note Converts named color to control character. Used internally by string translation functions.
*
*   @param  char[]        Input/Output string for convertion.
*   @param  maxLen        Maximum length of string buffer (includes NULL terminator).
*   @no return
*/
stock void ReplaceColor(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{white}", "\x01", false);
    ReplaceString(message, maxLen, "{cyan}", "\x03", false);
    ReplaceString(message, maxLen, "{orange}", "\x04", false);
    ReplaceString(message, maxLen, "{green}", "\x05", false);
}