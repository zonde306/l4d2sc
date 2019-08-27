#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#if SOURCEMOD_V_MINOR < 7
	#error Old version sourcemod!
#endif

#pragma newdecls required

#define PARTICLE_FUSE       "weapon_pipebomb_fuse"
#define PARTICLE_LIGHT      "weapon_pipebomb_blinking_light"

#define iMedkit		"models/w_models/weapons/w_eq_medkit.mdl"
#define iPills	"models/w_models/weapons/w_eq_painpills.mdl"
#define iAdrenaline		"models/w_models/weapons/w_eq_adrenaline.mdl"
#define iMoDefib 		"models/w_models/weapons/w_eq_defibrillator.mdl"
#define iDwarf		"models/props_junk/gnome.mdl"

#define BEAMSPRITE		"materials/sprites/laserbeam.vmt"
#define BEAMHALO		"materials/sprites/halo01.vmt"

#define iTake	"ui/bigreward.wav"

public Plugin myinfo=
{
	name = "[Skills]",
	author = "BHaType",
	description = "Выжившие могу покупать скилы и перки.",
	version = "6.6.9",
	url = "https://steamcommunity.com/id/fallinourblood/"
};

/*
new const String:Electables[][] = 
{	
	"weapon_smg_mp5",
	"weapon_smg",
	"weapon_smg_silenced",
	"weapon_shotgun_chrome",
	"weapon_gascan"
};
*/

ConVar iColorDefib, iColorDwarf, iColorAdrenalineCraft, iColorPillsCraft, iYourColor, yourColor, ResetEveryMap;

ConVar NeedToCraftPills, NeedToCraftAdrenaline, CostEpicMoli, CostEpicMoliUpgrade, CostHelpingHand, CostDoubleJump, CostSpeedUp, CostUpgradePipe, 
	   CostUltraPipe, CostPipeIndixite, CostShoveDamage, CostAntiDamage, CostMeleeDamage, CostFastReload, CostExpAmmo, CostIncAmmo, CostLaserSight, 
	   CostExpAmmoPack, CostIncAmmoPack, CostMinecraft, NeedToCraftMedkit, ChanceMedkit, ChancePills, ChanceAdrenaline, NeedToCraftDefib, NeedToCraftGnome,
	   ChanceToDropDefib, ChanceToDropGnome;

int iSprite;
int iHalo;

int Cash[MAXPLAYERS + 1] = 0;
int TeamCash = 5000;
int Target[MAXPLAYERS + 1] = 0;

//For Double Jump
int g_fLastButtons[MAXPLAYERS + 1];
int	g_fLastFlags[MAXPLAYERS + 1];
int g_iJumps[MAXPLAYERS + 1];
int g_iJumpMax = 1;
// count of killed CommonInfecteds
int CI[MAXPLAYERS+1] = 0;
//

//For perk PipeDealer
bool pPipeDealer[MAXPLAYERS + 1] = false;
int vAlreadyPipes[MAXPLAYERS + 1] = 0;
int vLvLPipes[MAXPLAYERS + 1] = 1;
int vMaxLvLPipes = 5;
Handle vTimeResetPipe[MAXPLAYERS + 1];
Handle hTimerResetPipe[MAXPLAYERS + 1];
bool vPipeIndixite[MAXPLAYERS + 1] = false;
//

//Helping Hand
float m_flReviveTime;
float m_flHealTime;
//

//Craft And Scav
bool iMinecraft[MAXPLAYERS + 1] = false;
int iCountMedkits[MAXPLAYERS + 1];
int iCraftedMedkits[MAXPLAYERS+1];
Handle vKillTimer[2048+1] = null;
int iKittyCat[2048+1]

int iCountAdrenalins[MAXPLAYERS + 1] = 0;
int iCraftedAdrenalins[MAXPLAYERS + 1] = 0;

int iCountPills[MAXPLAYERS + 1] = 0;
int iCraftedPills[MAXPLAYERS + 1] = 0;

int iCountDebifs[MAXPLAYERS + 1] = 0;
int iCraftedDebifs[MAXPLAYERS + 1] = 0;

int iCountGnomes[MAXPLAYERS + 1] = 0;
int iCraftedGnomes[MAXPLAYERS + 1] = 0;

//for Fast Reload(thanks to Alaina & tPoncho)
bool FastReload[MAXPLAYERS + 1] = false;
int iPlayRate, iTimeIdle, iNextAt, iNextPrimaryAt, iVMStartTime, iViewModel, iActiveW, iShotStart, iShotInsert, iShotEndDur, iReloadState;
static float g_flSoHAutoS = 0.666666;
static float g_flSoHAutoI = 0.4;
static float g_flSoHAutoE = 0.675;
static float g_flSoHSpasS = 0.5;
static float g_flSoHSpasI = 0.375;
static float g_flSoHSpasE = 0.699999;
static float g_flSoHPumpS = 0.5;
static float g_flSoHPumpI = 0.5;
static float g_flSoHPumpE = 0.6;
int iWeaponData[MAXPLAYERS + 1];
float flRate = 0.6;
//

bool ShoveDamage[MAXPLAYERS + 1] = false;

//Epic Molik
bool TripleMolotov[MAXPLAYERS + 1] = false;
int iMaxLevelMolo = 6;
int iCountOfMoliks[MAXPLAYERS + 1] = 1;
Handle vCoolDown[MAXPLAYERS + 1] = null;
//

bool FakeAdrenaline[MAXPLAYERS + 1] = false;
bool SpeedUp[MAXPLAYERS + 1] = false;
bool DoubleJump[MAXPLAYERS + 1] = false;
bool AntiDamage[MAXPLAYERS + 1] = false;
bool MeleeDamageUp[MAXPLAYERS + 1] = false;

Handle vHealUpTeam = null;
Handle vPoisonTeam = null;
Handle vTimerAdver[MAXPLAYERS+1] = null;

Handle vRoatation = null;

Handle sdkActivatePipe;

int g_iHookCreate;

char sMap[64];

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("pipe_bomb");
	if( hGameConf == null )
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CPipeBombProjectile_Create") == false )
		SetFailState("Could not load the \"CPipeBombProjectile_Create\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkActivatePipe = EndPrepSDKCall();
	if( sdkActivatePipe == null )
		SetFailState("Could not prep the \"CPipeBombProjectile_Create\" function.");
	
	RegConsoleCmd("sm_up", BuyMenu);
	RegAdminCmd("sm_gm", Gm, ADMFLAG_ROOT);
	
	iPlayRate	=	FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
	iTimeIdle	=	FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
	iNextAt	=	FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
	iNextPrimaryAt	=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	iVMStartTime	=	FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
	iViewModel	=	FindSendPropInfo("CTerrorPlayer","m_hViewModel");
	iActiveW	=	FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	iShotStart	=	FindSendPropInfo("CBaseShotgun","m_reloadStartDuration");
	iShotInsert	=	FindSendPropInfo("CBaseShotgun","m_reloadInsertDuration");
	iShotEndDur		=	FindSendPropInfo("CBaseShotgun","m_reloadEndDuration");
	iReloadState = FindSendPropInfo("CBaseShotgun","m_reloadState");
	
	HookEvent("player_spawn", EventPlayerSpawn);
	HookEvent("survivor_rescued", EventRescue);
	HookEvent("infected_death", EventInfDeath);
	HookEvent("player_death", EventDeath);
	HookEvent("defibrillator_used", EventDefib);
	HookEvent("player_shoved", EventPlayerShove);
	HookEvent("entity_shoved", EventShove);
	HookEvent("revive_begin", EventRevieve, EventHookMode_Pre);
	HookEvent("heal_begin", EventHeal, EventHookMode_Pre);
	HookEvent("witch_killed", EventWitchKill);
	HookEvent("grenade_bounce", EventBounce);
	HookEvent("weapon_reload", EventReload,  EventHookMode_Pre);
	HookEvent("molotov_thrown", EventThrow);

	m_flReviveTime = GetConVarFloat(FindConVar("survivor_revive_duration"));
	m_flHealTime = GetConVarFloat(FindConVar("first_aid_kit_use_duration"));
	
	ResetEveryMap = CreateConVar("vHardReset","0",	"Каждую карту будет сброс перков и денег? (>1 - Да, 0 - Нет)", FCVAR_NONE);
	
	CostHelpingHand = CreateConVar("vCostHelpHand","16000",	"Стоимость перка Helping Hand", FCVAR_NONE);
	CostDoubleJump = CreateConVar("vCostDoubleJump","14000",	"Стоимость перка Double Jump", FCVAR_NONE);
	CostSpeedUp = CreateConVar("vCostSpeedUp","18000",	"Стоимость перка Speed Up", FCVAR_NONE);
	CostAntiDamage = CreateConVar("vCostAntiDamage","10000",	"Стоимость перка Anti Damage", FCVAR_NONE);
	CostMeleeDamage = CreateConVar("vCostMeleeDamage","14000",	"Стоимость перка Melee Damage", FCVAR_NONE);
	CostFastReload = CreateConVar("vCostFastReload","17500",	"Стоимость перка Fast Reload", FCVAR_NONE);
	
	CostExpAmmoPack = CreateConVar("vCostExpAmmoPack","3500",	"Стоимость осколочных патронов Pack", FCVAR_NONE);
	CostIncAmmoPack = CreateConVar("vCostIncAmmoPack","3500",	"Стоимость зажигательных патронов Pack", FCVAR_NONE);
	CostExpAmmo = CreateConVar("vCostExpAmmo","3000",	"Стоимость осколочных патронов", FCVAR_NONE);
	CostIncAmmo = CreateConVar("vCostIncAmmo","3000",	"Стоимость зажигательных патронов", FCVAR_NONE);
	CostLaserSight = CreateConVar("vCostLaserSight","2000",	"Стоимость лазера", FCVAR_NONE);

	CostEpicMoli = CreateConVar("vCostEpicMolo","17000",	"Стоимость перка Epic Moli", FCVAR_NONE);
	CostEpicMoliUpgrade = CreateConVar("vCostEpicMoloUpgrade","3500",	"Стоимость апгрейда перка Epic Moli", FCVAR_NONE);

	NeedToCraftGnome = CreateConVar("vNumberToCraftGnome","60",	"Сколько нужно частей чтобы скрафтить дефиб", FCVAR_NONE);
	NeedToCraftDefib = CreateConVar("vNumberToCraftDefib","30",	"Сколько нужно частей чтобы скрафтить дефиб", FCVAR_NONE);
	NeedToCraftAdrenaline = CreateConVar("vNumberToCraftAdrenaline","10",	"Сколько нужно частей чтобы скрафтить адреналин", FCVAR_NONE);
	NeedToCraftPills = CreateConVar("vNumberToCraftPills","10",	"Сколько нужно частей чтобы скрафтить таблетки", FCVAR_NONE);
	NeedToCraftMedkit = CreateConVar("vNumberToCraftMedkit","20",	"Сколько нужно частей чтобы скрафтить аптечку", FCVAR_NONE);
	ChanceMedkit = CreateConVar("vChanceToDropPart","20",	"Шанс выпадения частицы аптечки из заражённного ", FCVAR_NONE);
	ChancePills = CreateConVar("vChanceToDropPills","20",	"Шанс выпадения частицы таблеток из заражённного ", FCVAR_NONE);
	ChanceAdrenaline = CreateConVar("vChanceToDropAdrenaline","20",	"Шанс выпадения частицы адреналина из заражённного ", FCVAR_NONE);
	ChanceToDropDefib = CreateConVar("vChanceToDropDefib","20",	"Шанс выпадения частицы дефиба из заражённного ", FCVAR_NONE);
	ChanceToDropGnome = CreateConVar("vChanceToDropDwarf","20",	"Шанс выпадения частицы гнома из заражённного ", FCVAR_NONE);

	CostMinecraft = CreateConVar("vCostCraftPerk","11000",	"Стоимость перка Craft", FCVAR_NONE);
	CostUpgradePipe = CreateConVar("vCostUpgradePipe","2500",	"Стоимость апгрейда перка Ultra Pipe Bomb", FCVAR_NONE);
	CostUltraPipe = CreateConVar("vCostUltraPipe","20000",	"Стоимость перка Ultra Pipe", FCVAR_NONE);
	CostPipeIndixite = CreateConVar("vCostStickyPipes","250",	"Стоимость перка Sticky Pipes", FCVAR_NONE);
	CostShoveDamage = CreateConVar("vCostPerfectDamage","12999",	"Стоимость перка Perfect Shove", FCVAR_NONE);
	
	iColorDefib = CreateConVar("vGlowCraftDefibColor","66 66 66",	"Цвет глоу для выпадаемых предметов из заражённых", FCVAR_NONE);
	iColorDwarf = CreateConVar("vGlowCraftDwatfColor","0 0 255",	"Цвет глоу для выпадаемых предметов из заражённых", FCVAR_NONE);

	iColorAdrenalineCraft = CreateConVar("vGlowCraftAdrenalineColor","93 2 240",	"Цвет глоу для выпадаемых предметов из заражённых", FCVAR_NONE);
	iColorPillsCraft = CreateConVar("vGlowCraftPillsColor","242 27 235",	"Цвет глоу для выпадаемых предметов из заражённых", FCVAR_NONE);
	iYourColor = CreateConVar("vGlowCraftThingsColor","255 0 0",	"Цвет глоу для выпадаемых предметов из заражённых", FCVAR_NONE);
	yourColor = CreateConVar("vGlowPipeColor","255 255 255",	"Цвет глоу для пайпы", FCVAR_NONE);
	AutoExecConfig(true, "[L4D2]Skills");
	LoadTranslations("[L4D2]SkillTr.phrases");
}

public void OnMapStart()
{
	iSprite = PrecacheModel(BEAMSPRITE)
	iHalo = PrecacheModel(BEAMHALO);
	PrecacheModel(iMedkit);
	if(GetConVarInt(ResetEveryMap) == 0)
	{
		GetCurrentMap(sMap, sizeof(sMap))
		if(StrContains(sMap, "m1_", true) > 1)
		{
			for(int i = 1; i <= MaxClients; ++i)
			{
				Cash[i] = 0;
				TeamCash = 5000;
				CI[i] = 0;
	
				if(vTimerAdver[i] != null)
				{
					KillTimer(vTimerAdver[i])
					vTimerAdver[i] = null;
				}
				iCountAdrenalins[i] = 0;
				iCraftedAdrenalins[i] = 0;
				iCountPills[i] = 0;
				iCraftedPills[i] = 0;
				iCountMedkits[i] = 0;
				iCraftedMedkits[i] = 0;
				FastReload[i] = false;
				vLvLPipes[i] = 1;
				vPipeIndixite[i] = false;
				pPipeDealer[i] = false;
				ShoveDamage[i] = false;
				FakeAdrenaline[i] = false;
				DoubleJump[i] = false;
				SpeedUp[i] = false;
				AntiDamage[i] = false
				MeleeDamageUp[i] = false;
				iMinecraft[i] = false;
				TripleMolotov[i] = false
			}
			if(vHealUpTeam != null)
			{
				KillTimer(vHealUpTeam)
				vHealUpTeam = null;
			}
		}
	}
	else
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			Cash[i] = 0;
			TeamCash = 5000;
			CI[i] = 0;
	
			if(vTimerAdver[i] != null)
			{
				KillTimer(vTimerAdver[i])
				vTimerAdver[i] = null;
			}
			iCountAdrenalins[i] = 0;
			iCraftedAdrenalins[i] = 0;
			iCountPills[i] = 0;
			iCraftedPills[i] = 0;
			TripleMolotov[i] = false;
			iCraftedMedkits[i] = 0;
			iCountMedkits[i] = 0;
			iMinecraft[i] = false;
			FastReload[i] = false;
			vLvLPipes[i] = 1;
			vPipeIndixite[i] = false;
			pPipeDealer[i] = false;
			ShoveDamage[i] = false;
			FakeAdrenaline[i] = false;
			DoubleJump[i] = false;
			SpeedUp[i] = false;
			AntiDamage[i] = false
			MeleeDamageUp[i] = false;
		}
		if(vHealUpTeam != null)
		{
			KillTimer(vHealUpTeam)
			vHealUpTeam = null;
		}
	}
	if(vPoisonTeam != null)
	{
		KillTimer(vPoisonTeam)
		vPoisonTeam = null;
	}
}

public Action EventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(bIsSurvivor(client) && SpeedUp[client])
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.2)
		SetEntityGravity(client, 0.8);
	}
}

//Thanks to Silvers!
public Action EventThrow(Handle event, const char[] name, bool dontBroadcast)
{
	// Only capture 1 throw per frame, do not capture our secondary created grenades.
	if( g_iHookCreate == 0)
	{
		// Validate client
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if( client && IsClientInGame(client) && TripleMolotov[client] && vCoolDown[client] == null)
		{
			// Find projectile
			int entity = INVALID_ENT_REFERENCE;
			while( (entity = FindEntityByClassname(entity, "molotov_projectile")) != INVALID_ENT_REFERENCE )
			{
				// Verify we have not already created multiple grenades for this and belongs to our thrower
				if( GetEntProp(entity, Prop_Data, "m_iHammerID") == 0 && GetEntPropEnt(entity, Prop_Data, "m_hThrower") == client )
				{
					// To show this grenade has been handled, prevent handling wrong ones.
					SetEntProp(entity, Prop_Data, "m_iHammerID", 1);

					// Position to create
					float vPos[3];
					GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

					// Listen for projectile creations, set as master projectile entity
					g_iHookCreate = EntIndexToEntRef(entity);
					iCountOfMoliks[client]++
					// Number of projectiles we're creating.
					for( int i = 1; i <= iCountOfMoliks[client]; i++ )
					{
						// Create molotov projectile with VScript. SDKCall fails, signature too long, CreateEntityByName doesn't 'Activate' the grenade.
						L4D2_RunScript("DropFire(Vector(%f %f %f))", vPos[0], vPos[1], vPos[2]);
					}
					vCoolDown[client] = CreateTimer(20.0, iCoolDown, client)
					iCountOfMoliks[client]--;
					g_iHookCreate = 0;
				}
			}
		}
	}
}

public Action iCoolDown(Handle timer, int client)
{
	Client_PrintToChat(client, true, "%t", "MolotovCoolDownFinished")
	vCoolDown[client] = null;
}

//Thanks to Silvers!
public void SpawnPost(int entity)
{
	// Must wait for frame after spawn to teleport
	RequestFrame(nextFrame, EntIndexToEntRef(entity));
}

//Thanks to Silvers!
public void nextFrame(int entity)
{
	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
	{
		// Get our master projectile entity index
		int grenade = GetEntProp(entity, Prop_Data, "m_iHammerID");
		if( grenade != INVALID_ENT_REFERENCE )
		{
			float vPos[3], vAng[3], vVel[3];
			GetEntPropVector(grenade, Prop_Data, "m_angRotation", vAng);
			GetEntPropVector(grenade, Prop_Data, "m_vecAbsOrigin", vPos);
			GetEntPropVector(grenade, Prop_Send, "m_vInitialVelocity", vVel);
			int client = GetEntPropEnt(grenade, Prop_Data, "m_hThrower");

			float vDir[3];
			GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
			vAng[0] += GetRandomFloat(-20.0, 20.0);
			vAng[1] += GetRandomFloat(-20.0, 20.0);
			vAng[2] += GetRandomFloat(-20.0, 20.0);
			vPos[0] += GetRandomFloat(-20.0, 20.0);
			vPos[1] += GetRandomFloat(-20.0, 20.0);
			vPos[2] += GetRandomFloat(-20.0, 20.0);
			vVel[0] += GetRandomFloat(-100.0, 100.0);
			vVel[1] += GetRandomFloat(-100.0, 100.0);
			vVel[2] += GetRandomFloat(-100.0, 100.0);
			TeleportEntity(entity, vPos, vAng, vVel);
			SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);
		}
	}
}

//Thanks to Silvers!
/**
* Runs a single line of VScript code.
* NOTE: Dont use the "script" console command, it starts a new instance and leaks memory. Use this instead!
*
* @param sCode        The code to run.
* @noreturn
*/
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

    char sBuffer[64];
    VFormat(sBuffer, sizeof(sBuffer), sCode, 2);

    SetVariantString(sBuffer);
    AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

public Action EventReload(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(FastReload[client])
	{
		char sWeaponName[64];
		int iWeapon = GetEntDataEnt2(client, iActiveW);
		GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
		iWeaponData[client] = iWeapon;
		if(StrContains(sWeaponName, "shotgun") < 1)
		{
			MagStart(iWeapon, client)
		}
		else if (StrContains(sWeaponName,"autoshotgun",false) != -1)
		{
			CreateTimer(0.1, Autoshotgun, client);
		}
		else if (StrContains(sWeaponName,"shotgun_spas",false) != -1)
		{
			CreateTimer(0.1, SpasShotgun, client);
		}
		else if (StrContains(sWeaponName,"pumpshotgun",false) != -1
				|| StrContains(sWeaponName,"shotgun_chrome",false) != -1)
		{
			CreateTimer(0.1, Pumpshotgun, client);
		}
	}
	return Plugin_Continue;
}

public Action Autoshotgun(Handle timer, int iClient)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
		return Plugin_Stop;

	int iWeapon = iWeaponData[iClient];
	if (iClient <= 0
		|| iWeapon <= 0
		|| IsValidEntity(iClient)==false
		|| IsValidEntity(iWeapon)==false
		|| IsClientInGame(iClient)==false)
		return Plugin_Stop;

	SetEntDataFloat(iWeapon,	iShotStart,	g_flSoHAutoS*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotInsert,	g_flSoHAutoI*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotEndDur,		g_flSoHAutoE*flRate,	true);
	
	SetEntDataFloat(iWeapon, iPlayRate, 1.0/flRate, true);

	CreateTimer(0.3, ShotgunEnd, iClient, TIMER_REPEAT);

	return Plugin_Stop;
}

public Action Pumpshotgun (Handle timer, int iClient)
{
	KillTimer(timer);
	if (!IsServerProcessing())
		return Plugin_Stop;

	int iWeapon = iWeaponData[iClient];

	if (iClient <= 0
		|| iWeapon <= 0
		|| IsValidEntity(iClient)==false
		|| IsValidEntity(iWeapon)==false
		|| IsClientInGame(iClient)==false)
		return Plugin_Stop;

	SetEntDataFloat(iWeapon,	iShotStart,	g_flSoHPumpS*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotInsert,	g_flSoHPumpI*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotEndDur,		g_flSoHPumpE*flRate,	true);

	SetEntDataFloat(iWeapon, iPlayRate, 1.0/flRate, true);


	CreateTimer(0.3, ShotgunEnd, iClient, TIMER_REPEAT);
	return Plugin_Stop;
}

public Action SpasShotgun (Handle timer, int iClient)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
		return Plugin_Stop;

	int iWeapon = iWeaponData[iClient];

	if (iClient <= 0
		|| iWeapon <= 0
		|| IsValidEntity(iClient)==false
		|| IsValidEntity(iWeapon)==false
		|| IsClientInGame(iClient)==false)
		return Plugin_Stop;

	SetEntDataFloat(iWeapon,	iShotStart,	g_flSoHSpasS*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotInsert,	g_flSoHSpasI*flRate,	true);
	SetEntDataFloat(iWeapon,	iShotEndDur,		g_flSoHSpasE*flRate,	true);

	SetEntDataFloat(iWeapon, iPlayRate, 1.0/flRate, true);

	CreateTimer(0.3, ShotgunEnd, iClient, TIMER_REPEAT);

	return Plugin_Stop;
}

public Action ShotgunEnd (Handle timer, int iClient)
{
	int iWeapon = iWeaponData[iClient];
	
	if (iWeapon < 0)return Plugin_Stop;
	
	if (!IsServerProcessing() && !bIsSurvivor(iClient))
	{
		KillTimer(timer);
		return Plugin_Stop;
	}

	if (GetEntData(iWeapon, iReloadState) == 0)
	{
		SetEntDataFloat(iWeapon, iPlayRate, 1.0, true);

		float flTime=GetGameTime()+0.2;
		SetEntDataFloat(iClient, iNextAt, flTime, true);
		SetEntDataFloat(iWeapon, iTimeIdle, flTime, true);
		SetEntDataFloat(iWeapon, iNextPrimaryAt, flTime, true);

		KillTimer(timer);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action EventRescue(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "subject"));

	if(SpeedUp[client])
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.2)
		SetEntityGravity(client, 0.8);
	}
}
 
public void OnEntityCreated(int entity, const char[] classname)
{
	if(IsPipe(entity))
	{
		CreateTimer(0.1, OnHeSpawned, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
	if( g_iHookCreate && strcmp(classname, "molotov_projectile") == 0)
	{
		// Save master projectile entity index for position, angle, velocity.
		int grenade = EntRefToEntIndex(g_iHookCreate);
		if( grenade != INVALID_ENT_REFERENCE )
		{
			SetEntProp(entity, Prop_Data, "m_iHammerID", g_iHookCreate);

			// Have to wait for the projectile to be fully spawned before we can teleport.
			SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
		}
	}
}

public Action OnHeSpawned(Handle timer, any ent)
{
	int client;
	if((ent = EntRefToEntIndex(ent)) > 0 && (client = GetEntPropEnt(ent, Prop_Data, "m_hThrower")) > 0)
	{
		if(vPipeIndixite[client])
		{
			SDKHook(ent, SDKHook_Touch, OnTouchPost);
		}
	}
}

public Action OnTouchPost(int iGrenade, int iOther)
{
    if (!iOther)
    {
        SetEntityMoveType(iGrenade, MOVETYPE_NONE);
    }
    else if ((iOther > MaxClients) && (GetEntProp(iOther, Prop_Send, "m_nSolidType", 1) && !(GetEntProp(iOther, Prop_Send, "m_usSolidFlags", 2) & 0x0004)))
    {
        SetEntityMoveType(iGrenade, MOVETYPE_NONE);
    }
}

public bool Trace_Filter_Not_Self(int entity,int mask, any data) 
{
    if(entity == data)
        return false;
    return true;
}  

public Action EventBounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int grenade = GetGrenade(client);

	if(IsPipe(grenade))
	{	
		float vAng[3], vec[3], HeadingVector[3], AimVector[3], current[3] , gPos[3];
		float power = 250.0;
		if(pPipeDealer[client])
		{
			if(bIsSurvivor(client))
			{
				if(vTimeResetPipe[client] == null)
				{
					if(vAlreadyPipes[client] < vLvLPipes[client])
					{
						GetEntPropVector(grenade, Prop_Send, "m_vecOrigin", gPos);
						GetEntPropVector(grenade, view_as<PropType>(1), "m_vecVelocity", vec, 0);
						GetClientEyeAngles(client, HeadingVector);
						AimVector[0] = Cosine(DegToRad(HeadingVector[1])) * power * GetRandomInt(1, 5);
						AimVector[1] = Sine(DegToRad(HeadingVector[1])) * power * GetRandomInt(1, 5);
						gPos[2] += 15.0;
						vec[2] += 40.0;
						vec[0] += 30.0;
						vec[1] += 5.0;
						current[0] = vec[0] + AimVector[0];
						current[1] = vec[1] + AimVector[1];
						current[2] = power * 2;
						int entity = SDKCall(sdkActivatePipe, gPos, vAng, vAng, vAng, client, 15.0);
						SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
						TeleportEntity(entity, gPos, NULL_VECTOR, current);
						int ParticleEntity = CreateEntityByName("info_particle_system");
						DispatchKeyValueFloat(entity, "fademindist", -1.0); 
						DispatchKeyValueFloat(entity, "fademindist", 999.0); 
						DispatchKeyValue(ParticleEntity, "effect_name", PARTICLE_LIGHT);
						DispatchKeyValue(ParticleEntity, "effect_name", PARTICLE_FUSE);
						DispatchSpawn(ParticleEntity);
						SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
						SetEntProp(entity, Prop_Send, "m_nGlowRange", 2000);
						SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
						SetEntProp(entity, Prop_Send, "m_glowColorOverride", GetColor(yourColor));
						
						SetEntProp(grenade, Prop_Send, "m_CollisionGroup", 0);
						SetEntProp(grenade, Prop_Send, "m_nGlowRange", 2000);
						SetEntProp(grenade, Prop_Send, "m_iGlowType", 3);
						SetEntProp(grenade, Prop_Send, "m_glowColorOverride", GetColor(yourColor));
						ActivateEntity(ParticleEntity);
						AcceptEntityInput(ParticleEntity, "Start");
						vAlreadyPipes[client]++;
					}
					else
					{
						if(hTimerResetPipe[client] == null)
						{
							hTimerResetPipe[client] = CreateTimer(20.0, vTimerResetPipe, client)
						}
					}
				}
			}
		}
	}
}

public Action vTimerResetPipe(Handle timer, int client)
{
	Client_PrintToChat(client, true, "%t", "UltraPipeBombCooldownFinish")
	//Client_PrintToChat(client, true, "{O}Ваш{G} перк{R}(Пайпо Мёт){BLA}откуладунился.")
	vAlreadyPipes[client] = 0;
	KillTimer(hTimerResetPipe[client])
	hTimerResetPipe[client] = null;
}

public Action vTimeCashTeam(Handle timer)
{
	int ForwardingCash = RoundToCeil(TeamCash * 1.1);
	TeamCash = ForwardingCash;
}

public Action EventWitchKill(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event,"userid"));

	if(bIsSurvivor(attacker))
	{
		int random = GetRandomInt(250, 2500) * 2;
		Cash[attacker] +=  random
		Client_PrintToChat(attacker, true, "%t", "WitchKilled", random)
		for(int i = 1; i <= MaxClients; ++i)
		{
			if(IsClientInGame(i) && i != attacker)
			{
				Client_PrintToChat(i, true, "%t", "WhoWitchKilled", attacker, random)
			}
		}
		//Client_PrintToChat(attacker, true, "{BLA}Вы {R}получили {OG}%i {R}за убийство {OG}бабы.", random)
	}
}


public Action EventInfDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event,"attacker"));

	if(vTimerAdver[attacker] == null)
	{
		vTimerAdver[attacker] = CreateTimer(70.0, Advertisement, attacker)
	}
	CI[attacker]++;        
}

public Action Advertisement(Handle timer, int attacker)
{
	int total = GetRandomInt(0, 30) * CI[attacker] * GetRandomInt(1, 3)
	if(bIsSurvivor(attacker) && total != 1702257729 && CI[attacker] != 1702257729)
	{
		Client_PrintToChat(attacker, true, "%t", "AdvertisementHowManyCommonsKilled", total, CI[attacker])
		//Client_PrintToChat(attacker, true, "{BLA}Вы {R}получили {OG}%i {R}за убийство {OG}%i {R}обычных заражённых.", total, CI[attacker])
	}
	Cash[attacker] += total;
	CI[attacker] = 0;
	KillTimer(vTimerAdver[attacker])
	vTimerAdver[attacker] = null;

}

public Action EventHeal(Event event, const char[] name, bool dontBroadcast)
{
	int i = GetClientOfUserId(GetEventInt(event,"userid"));
	if(FakeAdrenaline[i])
	{
		SetEntProp(i, Prop_Send, "m_bAdrenalineActive", 1, 1)
		SetConVarFloat(FindConVar("first_aid_kit_use_duration"), m_flHealTime * 0.5, false, false);
	}
	else
	{
		SetConVarFloat(FindConVar("first_aid_kit_use_duration"), m_flHealTime, false, false);
	}
}

public Action EventRevieve (Event event, const char[] name, bool dontBroadcast)
{
	int i = GetClientOfUserId(GetEventInt(event,"userid"));
	if(FakeAdrenaline[i])
	{
		SetEntProp(i, Prop_Send, "m_bAdrenalineActive", 1, 1)
		SetConVarFloat(FindConVar("survivor_revive_duration"), m_flReviveTime * 0.5, false, false);
	}
	else
	{
		SetConVarFloat(FindConVar("survivor_revive_duration"), m_flReviveTime, false, false);
	}
}

public Action EventDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(bIsSurvivor(client))
	{
		if(SpeedUp[client])
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0)
			SetEntityGravity(client, 1.0);
		}
	}
	if(IsValidInfected(client))
	{
		if(bIsSurvivor(attacker))
		{
			int iCase = GetRandomInt(0, 4)
			{
				switch(iCase)
				{
					case 0:
					{
						if(GetRandomInt(0, 100) <= GetConVarInt(ChanceMedkit))
						{
							float vPos[3]
							GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos)
							vPos[2] += 20.0;
							int iKit = CreateEntityByName("prop_dynamic_override")
							if(IsValidEntity(iKit))
							{
								DispatchKeyValueVector(iKit, "origin", vPos );
								DispatchKeyValue(iKit, "model", iMedkit);
								DispatchSpawn(iKit);
								
								int iTrigger = CreateEntityByName("trigger_multiple");
								DispatchKeyValue(iTrigger, "spawnflags", "1"); 
								DispatchKeyValue(iTrigger, "wait", "0");
								DispatchSpawn(iTrigger); 
								ActivateEntity(iTrigger); 
								TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-25.0, -25.0, -25.0})); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({25.0, 25.0, 25.0})); 
								SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2); 
								HookSingleEntityOutput(iTrigger, "OnStartTouch", OnStartTouch); 
								
								iKittyCat[iTrigger] = EntIndexToEntRef(iKit)
								vRoatation = CreateTimer(0.05, vRotation, EntIndexToEntRef(iKit), TIMER_REPEAT)
								
								int iYourColorRing[4];
								iYourColorRing[0] = GetRandomInt(0, 255)
								iYourColorRing[1] = GetRandomInt(0, 255)
								iYourColorRing[2] = GetRandomInt(0, 255)
								iYourColorRing[3] = 255;
									
								TE_SetupBeamRingPoint(vPos, 120.0, 0.1, iSprite, iHalo, 0, 66, 25.0, 1.7, 2.0, iYourColorRing, 20, 0)
								TE_SendToAll();

								SetEntProp(iKit, Prop_Send, "m_nGlowRange", 500);
								SetEntProp(iKit, Prop_Send, "m_iGlowType", 3);
								SetEntProp(iKit, Prop_Send, "m_glowColorOverride", GetColor(iYourColor));
								
								DataPack iPack;
								vKillTimer[iKit] = CreateDataTimer(25.0, vKill, iPack, TIMER_DATA_HNDL_CLOSE)
								WritePackCell(iPack, EntIndexToEntRef(iTrigger));
								WritePackCell(iPack, EntIndexToEntRef(iKit));
							}
						}
					}
					case 1:
					{
						if(GetRandomInt(0, 100) <= GetConVarInt(ChancePills))
						{
							float vPos[3]
							GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos)
							vPos[2] += 20.0;
							int iPill = CreateEntityByName("prop_dynamic_override")
							if(IsValidEntity(iPill))
							{
								DispatchKeyValueVector(iPill, "origin", vPos );
								DispatchKeyValue(iPill, "model", iPills);
								DispatchSpawn(iPill);
								
								int iTrigger = CreateEntityByName("trigger_multiple");
								DispatchKeyValue(iTrigger, "spawnflags", "1"); 
								DispatchKeyValue(iTrigger, "wait", "0");
								DispatchSpawn(iTrigger); 
								ActivateEntity(iTrigger); 
								TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-25.0, -25.0, -25.0})); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({25.0, 25.0, 25.0})); 
								SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2); 
								HookSingleEntityOutput(iTrigger, "OnStartTouch", OnStartTouchPills); 
								
								iKittyCat[iTrigger] = EntIndexToEntRef(iPill)
								vRoatation = CreateTimer(0.05, vRotation, EntIndexToEntRef(iPill), TIMER_REPEAT)
								
								int iYourColorRing[4];
								iYourColorRing[0] = GetRandomInt(0, 255)
								iYourColorRing[1] = GetRandomInt(0, 255)
								iYourColorRing[2] = GetRandomInt(0, 255)
								iYourColorRing[3] = 255;
									
								TE_SetupBeamRingPoint(vPos, 120.0, 0.1, iSprite, iHalo, 0, 66, 25.0, 1.7, 2.0, iYourColorRing, 20, 0)
								TE_SendToAll();

								SetEntProp(iPill, Prop_Send, "m_nGlowRange", 500);
								SetEntProp(iPill, Prop_Send, "m_iGlowType", 3);
								SetEntProp(iPill, Prop_Send, "m_glowColorOverride", GetColor(iColorPillsCraft));
								
								DataPack iPack;
								vKillTimer[iPill] = CreateDataTimer(25.0, vKill, iPack, TIMER_DATA_HNDL_CLOSE)
								WritePackCell(iPack, EntIndexToEntRef(iTrigger));
								WritePackCell(iPack, EntIndexToEntRef(iPill));
							}
						}
					}
					case 2:
					{
						if(GetRandomInt(0, 100) <= GetConVarInt(ChanceAdrenaline))
						{
							float vPos[3]
							GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos)
							vPos[2] += 20.0;
							int iA = CreateEntityByName("prop_dynamic_override")
							if(IsValidEntity(iA))
							{
								DispatchKeyValueVector(iA, "origin", vPos );
								DispatchKeyValue(iA, "model", iAdrenaline);
								DispatchSpawn(iA);
								
								int iTrigger = CreateEntityByName("trigger_multiple");
								DispatchKeyValue(iTrigger, "spawnflags", "1"); 
								DispatchKeyValue(iTrigger, "wait", "0");
								DispatchSpawn(iTrigger); 
								ActivateEntity(iTrigger); 
								TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-25.0, -25.0, -25.0})); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({25.0, 25.0, 25.0}));  
								SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2); 
								HookSingleEntityOutput(iTrigger, "OnStartTouch", OnStartTouchAdrenaline); 
								
								iKittyCat[iTrigger] = EntIndexToEntRef(iA)
								vRoatation = CreateTimer(0.05, vRotation, EntIndexToEntRef(iA), TIMER_REPEAT)
								
								int iYourColorRing[4];
								iYourColorRing[0] = GetRandomInt(0, 255)
								iYourColorRing[1] = GetRandomInt(0, 255)
								iYourColorRing[2] = GetRandomInt(0, 255)
								iYourColorRing[3] = 255;
									
								TE_SetupBeamRingPoint(vPos, 120.0, 0.1, iSprite, iHalo, 0, 66, 25.0, 1.7, 2.0, iYourColorRing, 20, 0)
								TE_SendToAll();

								SetEntProp(iA, Prop_Send, "m_nGlowRange", 500);
								SetEntProp(iA, Prop_Send, "m_iGlowType", 3);
								SetEntProp(iA, Prop_Send, "m_glowColorOverride", GetColor(iColorAdrenalineCraft));
								
								DataPack iPack;
								vKillTimer[iA] = CreateDataTimer(25.0, vKill, iPack, TIMER_DATA_HNDL_CLOSE)
								WritePackCell(iPack, EntIndexToEntRef(iTrigger));
								WritePackCell(iPack, EntIndexToEntRef(iA));
							}
						}

					}
					case 3:
					{
						if(GetRandomInt(0, 100) <= GetConVarInt(ChanceToDropDefib))
						{
							float vPos[3]
							GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos)
							vPos[2] += 20.0;
							int iDefib = CreateEntityByName("prop_dynamic_override")
							if(IsValidEntity(iDefib))
							{
								DispatchKeyValueVector(iDefib, "origin", vPos );
								DispatchKeyValue(iDefib, "model", iMoDefib);
								DispatchSpawn(iDefib);
								SetEntityModel(iDefib, iMoDefib)

								int iTrigger = CreateEntityByName("trigger_multiple");
								DispatchKeyValue(iTrigger, "spawnflags", "1"); 
								DispatchKeyValue(iTrigger, "wait", "0");
								DispatchSpawn(iTrigger); 
								ActivateEntity(iTrigger); 
								TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-25.0, -25.0, -25.0})); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({25.0, 25.0, 25.0})); 
								SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2); 
								HookSingleEntityOutput(iTrigger, "OnStartTouch", OnStartTouchDefib); 
								
								iKittyCat[iTrigger] = EntIndexToEntRef(iDefib)
								vRoatation = CreateTimer(0.05, vRotation, EntIndexToEntRef(iDefib), TIMER_REPEAT)
								
								int iYourColorRing[4];
								iYourColorRing[0] = GetRandomInt(0, 255)
								iYourColorRing[1] = GetRandomInt(0, 255)
								iYourColorRing[2] = GetRandomInt(0, 255)
								iYourColorRing[3] = 255;
									
								TE_SetupBeamRingPoint(vPos, 120.0, 0.1, iSprite, iHalo, 0, 66, 25.0, 1.7, 2.0, iYourColorRing, 20, 0)
								TE_SendToAll();

								SetEntProp(iDefib, Prop_Send, "m_nGlowRange", 500);
								SetEntProp(iDefib, Prop_Send, "m_iGlowType", 3);
								SetEntProp(iDefib, Prop_Send, "m_glowColorOverride", GetColor(iColorDefib));
								
								DataPack iPack;
								vKillTimer[iDefib] = CreateDataTimer(25.0, vKill, iPack, TIMER_DATA_HNDL_CLOSE)
								WritePackCell(iPack, EntIndexToEntRef(iTrigger));
								WritePackCell(iPack, EntIndexToEntRef(iDefib));
							}
						}
					}
					case 4:
					{
						if(GetRandomInt(0, 100) <= GetConVarInt(ChanceToDropGnome))
						{
							float vPos[3]
							GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos)
							vPos[2] += 20.0;
							int iGnome = CreateEntityByName("prop_dynamic_override")
							if(IsValidEntity(iGnome))
							{
								DispatchKeyValueVector(iGnome, "origin", vPos );
								DispatchKeyValue(iGnome, "model", iDwarf);
								DispatchSpawn(iGnome);
								
								int iTrigger = CreateEntityByName("trigger_multiple");
								DispatchKeyValue(iTrigger, "spawnflags", "1"); 
								DispatchKeyValue(iTrigger, "wait", "0");
								DispatchSpawn(iTrigger); 
								ActivateEntity(iTrigger); 
								TeleportEntity(iTrigger, vPos, NULL_VECTOR, NULL_VECTOR); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", view_as<float>({-25.0, -25.0, -25.0})); 
								SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", view_as<float>({25.0, 25.0, 25.0}));  
								SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2); 
								HookSingleEntityOutput(iTrigger, "OnStartTouch", OnStartTouchGnome); 
								
								iKittyCat[iTrigger] = EntIndexToEntRef(iGnome)
								vRoatation = CreateTimer(0.05, vRotation, EntIndexToEntRef(iGnome), TIMER_REPEAT)
								
								int iYourColorRing[4];
								iYourColorRing[0] = GetRandomInt(0, 255)
								iYourColorRing[1] = GetRandomInt(0, 255)
								iYourColorRing[2] = GetRandomInt(0, 255)
								iYourColorRing[3] = 255;
									
								TE_SetupBeamRingPoint(vPos, 120.0, 0.1, iSprite, iHalo, 0, 66, 25.0, 1.7, 2.0, iYourColorRing, 20, 0)
								TE_SendToAll();

								SetEntProp(iGnome, Prop_Send, "m_nGlowRange", 500);
								SetEntProp(iGnome, Prop_Send, "m_iGlowType", 3);
								SetEntProp(iGnome, Prop_Send, "m_glowColorOverride", GetColor(iColorDwarf));
								
								DataPack iPack;
								vKillTimer[iGnome] = CreateDataTimer(25.0, vKill, iPack, TIMER_DATA_HNDL_CLOSE)
								WritePackCell(iPack, EntIndexToEntRef(iTrigger));
								WritePackCell(iPack, EntIndexToEntRef(iGnome));
							}
						}
					}
				}
			}
			int vClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if (vClass == 1)
			{
				float rFloat = GetRandomFloat(1.0, 2.5);
				int Number = GetRandomInt(200, 625);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledSmoker", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}куры", Total)
				TeamCash += Number;
			}
			else if (vClass == 2)
			{
				float rFloat = GetRandomFloat(1.0, 4.0);
				int Number = GetRandomInt(200, 300);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledBoomer", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}толстого", Total)
				TeamCash += Number;
			}
			else if (vClass == 3)
			{
				float rFloat = GetRandomFloat(1.0, 3.0);
				int Number = GetRandomInt(350, 475);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledHunter", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}кузнечика", Total)
				TeamCash += Number;
			}
			else if (vClass == 4)
			{
				float rFloat = GetRandomFloat(1.0, 3.5);
				int Number = GetRandomInt(150, 175);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledSpitter", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}какой-то дичи", Total)
				TeamCash += Number;
			}
			else if (vClass == 5)
			{
				float rFloat = GetRandomFloat(1.0, 2.5);
				int Number = GetRandomInt(200, 350);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledJockey", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {BLA}урода", Total)
				TeamCash += Number;
			}
			else if (vClass == 6)
			{
				float rFloat = GetRandomFloat(1.0, 3.5);
				int Number = GetRandomInt(300, 650);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledCharger", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}родственника", Total)
				TeamCash += Number;
			}
			else if (vClass == 8)
			{
				float rFloat = GetRandomFloat(1.0, 2.1);
				int Number = GetRandomInt(2100, 2850);
				int Total = RoundToCeil(Number * rFloat)
				Cash[attacker] += Total;
				Client_PrintToChat(attacker, true, "%t", "KilledTank", Total)
				//Client_PrintToChat(attacker, true, "{R}Вы {B}получили {O}%i {B}за убийство {OG}тупого качка", Total)
				TeamCash += Number;
			}
		}
	}
}

public void OnStartTouchDefib(const char[] output, int caller, int activator, float delay)
{
	if (bIsSurvivor(activator) && iMinecraft[activator])
	{
		if(vKillTimer[EntRefToEntIndex(iKittyCat[caller])] != null)
		{
			KillTimer(vKillTimer[EntRefToEntIndex(iKittyCat[caller])])
			vKillTimer[EntRefToEntIndex(iKittyCat[caller])] = null;
		}
		if(vRoatation != null)
		{
			KillTimer(vRoatation)
			vRoatation = null;
		}
		AcceptEntityInput(caller, "kill")
		AcceptEntityInput(EntRefToEntIndex(iKittyCat[caller]), "kill")
		iCountDebifs[activator]++;
		EmitSoundToAll(iTake, activator, SNDCHAN_AUTO );
	}
	else
	{
		Client_PrintToChat(activator, true, "%t", "YouNeedPerkCraft")
	}
}

public void OnStartTouchGnome(const char[] output, int caller, int activator, float delay)
{
	if (bIsSurvivor(activator) && iMinecraft[activator])
	{
		if(vKillTimer[EntRefToEntIndex(iKittyCat[caller])] != null)
		{
			KillTimer(vKillTimer[EntRefToEntIndex(iKittyCat[caller])])
			vKillTimer[EntRefToEntIndex(iKittyCat[caller])] = null;
		}
		if(vRoatation != null)
		{
			KillTimer(vRoatation)
			vRoatation = null;
		}
		AcceptEntityInput(caller, "kill")
		AcceptEntityInput(EntRefToEntIndex(iKittyCat[caller]), "kill")
		iCountGnomes[activator]++;
		EmitSoundToAll(iTake, activator, SNDCHAN_AUTO );
	}
	else
	{
		Client_PrintToChat(activator, true, "%t", "YouNeedPerkCraft")
	}
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (bIsSurvivor(activator) && iMinecraft[activator])
	{
		if(vKillTimer[EntRefToEntIndex(iKittyCat[caller])] != null)
		{
			KillTimer(vKillTimer[EntRefToEntIndex(iKittyCat[caller])])
			vKillTimer[EntRefToEntIndex(iKittyCat[caller])] = null;
		}
		if(vRoatation != null)
		{
			KillTimer(vRoatation)
			vRoatation = null;
		}
		AcceptEntityInput(caller, "kill")
		AcceptEntityInput(EntRefToEntIndex(iKittyCat[caller]), "kill")
		iCountMedkits[activator]++;
		EmitSoundToAll(iTake, activator, SNDCHAN_AUTO );
	}
	else
	{
		Client_PrintToChat(activator, true, "%t", "YouNeedPerkCraft")
	}
}

public void OnStartTouchPills(const char[] output, int caller, int activator, float delay)
{
	if (bIsSurvivor(activator) && iMinecraft[activator])
	{
		if(vKillTimer[EntRefToEntIndex(iKittyCat[caller])] != null)
		{
			KillTimer(vKillTimer[EntRefToEntIndex(iKittyCat[caller])])
			vKillTimer[EntRefToEntIndex(iKittyCat[caller])] = null;
		}
		if(vRoatation != null)
		{
			KillTimer(vRoatation)
			vRoatation = null;
		}
		AcceptEntityInput(caller, "kill")
		AcceptEntityInput(EntRefToEntIndex(iKittyCat[caller]), "kill")
		iCountPills[activator]++;
		EmitSoundToAll(iTake, activator, SNDCHAN_AUTO );
	}
	else
	{
		Client_PrintToChat(activator, true, "%t", "YouNeedPerkCraft")
	}
}

public void OnStartTouchAdrenaline(const char[] output, int caller, int activator, float delay)
{
	if (bIsSurvivor(activator) && iMinecraft[activator])
	{
		if(vKillTimer[EntRefToEntIndex(iKittyCat[caller])] != null)
		{
			KillTimer(vKillTimer[EntRefToEntIndex(iKittyCat[caller])])
			vKillTimer[EntRefToEntIndex(iKittyCat[caller])] = null;
		}
		if(vRoatation != null)
		{
			KillTimer(vRoatation)
			vRoatation = null;
		}
		AcceptEntityInput(caller, "kill")
		AcceptEntityInput(EntRefToEntIndex(iKittyCat[caller]), "kill")
		iCountAdrenalins[activator]++;
		EmitSoundToAll(iTake, activator, SNDCHAN_AUTO );
	}
	else
	{
		Client_PrintToChat(activator, true, "%t", "YouNeedPerkCraft")
	}
}

public Action vRotation(Handle timer, int iKit)
{
	iKit = EntRefToEntIndex(iKit)
	if(IsValidEntity(iKit))
	{
		float flAngles[3]
		GetEntPropVector(iKit, Prop_Send, "m_angRotation", flAngles);

		flAngles[1] += 3.0;
		TeleportEntity(iKit, NULL_VECTOR, flAngles, NULL_VECTOR);
	}
}

public Action vKill(Handle timer, Handle iPack)
{	
	ResetPack(iPack)
	int iTrigger = ReadPackCell(iPack)
	int iKit = ReadPackCell(iPack)
	
	iTrigger = EntRefToEntIndex(iTrigger)
	iKit = EntRefToEntIndex(iKit)
	
	if(vRoatation != null)
	{
		KillTimer(vRoatation)
		vRoatation = null;
	}
	if(IsValidEntity(iKit))
	{
		float desPos[3];
		GetEntPropVector(iKit, Prop_Send, "m_vecOrigin", desPos );

		desPos[2] += 5000.0;
		
		TeleportEntity(iKit, desPos, NULL_VECTOR, NULL_VECTOR);
		RemoveEdict(iTrigger)
		RemoveEdict(iKit)
	}
}

public Action EventDefib(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	
	if(bIsSurvivor(client))
	{
		if(SpeedUp[client])
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.2)
			SetEntityGravity(client, 0.8);
		}
	}
}

public Action EventPlayerShove(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(bIsSurvivor(attacker))
	{
		if(IsValidInfected(client))
		{
			int vClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if(vClass != 4 && vClass != 2)
			{
				if(ShoveDamage[attacker])
				{
					ForceDamageEntity(attacker, 200, client)
				}
			}
		}
	}
}

public Action EventShove(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("entityid"); 
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if(bIsSurvivor(attacker))
	{
		if(IsCommonInfected(client))
		{
			if(ShoveDamage[attacker])
			{
				ForceDamageEntity(attacker, 40, client)
			}
		}
	}
}

public Action Gm(int client,int args)
{
	Cash[client] += 100000;
}

public Action BuyMenu(int client,int args)
{
	if(bIsSurvivor(client))
	{
		DisplayMainMenu(client)
	}
}

public int MainBox(Handle DontLook, MenuAction action, int client, int symbol)
{
	if (action == MenuAction_End) 
	{ 
		CloseHandle(DontLook); 
		return; 
	} 
	if (action == MenuAction_Select)
	{
		if(symbol == 0)
		{
			DisplayStatisticMenu(client)
		}
		else if(symbol == 1)
		{
			DisplayPerksPassiveMenu(client)
		}
		else if(symbol == 2)
		{
			DisplayPerksMenu(client);
		}
		else if(symbol == 3)
		{
			DisplayTransfer(client);
		}
		else if(symbol == 4)
		{
			DisplayBankTo(client);
		}
		else if(symbol == 5)
		{
			DisplayTeamHelp(client)
		}
		else if(symbol == 6)
		{
			DisplayShop(client)
		}	
		else if(symbol == 7)
		{
			DisplayCraftMenu(client)
		}
		else if(symbol == 8)
		{
			DisplayInvectory(client)
		}
		else if(symbol == 9)
		{
			DisplayBag(client)
		}
	}
}

void DisplayInvectory(int client)
{	
	Handle BagDisplay = CreateMenu(MyInvMenu);
	//char sTitle[56];
	SetMenuTitle(BagDisplay, "%t", "InvectoryMenuTitle");
	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "InvCountMedkits", iCountMedkits[client], GetConVarInt(NeedToCraftMedkit))
	AddMenuItem(BagDisplay, "0", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "InvCountPills", iCountPills[client], GetConVarInt(NeedToCraftPills))
	AddMenuItem(BagDisplay, "1", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "InvCountAdrenalins", iCountAdrenalins[client], GetConVarInt(NeedToCraftAdrenaline))
	AddMenuItem(BagDisplay, "2", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "InvCountDefibs", iCountDebifs[client], GetConVarInt(NeedToCraftDefib))
	AddMenuItem(BagDisplay, "3", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "InvCountDwarfs", iCountGnomes[client], GetConVarInt(NeedToCraftGnome))
	AddMenuItem(BagDisplay, "4", sStringEx, ITEMDRAW_DISABLED);

	SetMenuExitButton(BagDisplay, true)
	DisplayMenu(BagDisplay, client, MENU_TIME_FOREVER);
}

public int MyInvMenu(Handle MinecraftCallback, MenuAction action, int client, int symbol) 
{ 

	if (action == MenuAction_End) 
	{ 
		CloseHandle(MinecraftCallback); 
		return; 
	} 
	if (action != MenuAction_Select) return; 

}

public int MyBagMenu(Handle BagCallback, MenuAction action, int client, int symbol) 
{ 

	if (action == MenuAction_End) 
	{ 
		CloseHandle(BagCallback); 
		return; 
	} 
	if (action != MenuAction_Select) return; 

	if(symbol == 0)
	{
		if(iCraftedMedkits[client] > 0)
		{
			iCraftedMedkits[client]--
			GiveFunction(client, "first_aid_kit")
			Client_PrintToChat(client, true, "%t", "YouTakeFromBagMedkit", iCraftedMedkits[client])
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "YouDontHaveCraftedMedkits")
		}
	}
	if(symbol == 1)
	{
		if(iCraftedPills[client] > 0)
		{
			iCraftedPills[client]--
			GiveFunction(client, "pain_pills")
			Client_PrintToChat(client, true, "%t", "YouTakeFromBagPills", iCraftedPills[client])
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "YouDontHaveCraftedPills")
		}
	}
	if(symbol == 2)
	{
		if(iCraftedAdrenalins[client] > 0)
		{
			iCraftedAdrenalins[client]--
			GiveFunction(client, "adrenaline")
			Client_PrintToChat(client, true, "%t", "YouTakeFromBagAdrenaline", iCraftedAdrenalins[client])
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "YouDontHaveCraftedAdrenaline")
		}
	}
	if(symbol == 3)
	{
		if(iCraftedDebifs[client] > 0)
		{
			iCraftedDebifs[client]--
			GiveFunction(client, "defibrillator")
			Client_PrintToChat(client, true, "%t", "YouTakeFromBagDefib", iCraftedDebifs[client])
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "YouDontHaveCraftedDefibs")
		}
	}
	if(symbol == 4)
	{
		if(iCraftedGnomes[client] > 0)
		{
			iCraftedAdrenalins[client]--
			GiveFunction(client, "gnome")
			Client_PrintToChat(client, true, "%t", "YouTakeFromBagDwarf", iCraftedGnomes[client])
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "YouDontHaveCraftedDwarfs")
		}
	}
}

void DisplayBag(int client)
{	
	Handle MainMenuDisplay = CreateMenu(MyBagMenu);
	//char sTitle[56];
	SetMenuTitle(MainMenuDisplay, "%t", "MyBagTitle");
	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "BagMedkitsCount", iCraftedMedkits[client])
	AddMenuItem(MainMenuDisplay, "0", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "BagPillsCount", iCraftedPills[client])
	AddMenuItem(MainMenuDisplay, "1", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "BagAdrenalineCount", iCraftedAdrenalins[client])
	AddMenuItem(MainMenuDisplay, "2", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "BagDefibsCount", iCraftedDebifs[client])
	AddMenuItem(MainMenuDisplay, "3", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "BagDwarfCount", iCraftedGnomes[client])
	AddMenuItem(MainMenuDisplay, "4", sStringEx);

	SetMenuExitButton(MainMenuDisplay, true)
	DisplayMenu(MainMenuDisplay, client, MENU_TIME_FOREVER);
}

void DisplayCraftMenu(int client)
{	
	Handle MainMenuDisplay = CreateMenu(Minecraft);
	//char sTitle[56];
	SetMenuTitle(MainMenuDisplay, "%t", "CraftMenuTitle");
	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "CraftMedkit", iCountMedkits[client], GetConVarInt(NeedToCraftMedkit))
	AddMenuItem(MainMenuDisplay, "0", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "CraftPills", iCountPills[client], GetConVarInt(NeedToCraftPills))
	AddMenuItem(MainMenuDisplay, "1", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "CraftAdrenaline", iCountAdrenalins[client], GetConVarInt(NeedToCraftAdrenaline))
	AddMenuItem(MainMenuDisplay, "2", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "CraftDefib", iCountDebifs[client], GetConVarInt(NeedToCraftDefib))
	AddMenuItem(MainMenuDisplay, "3", sStringEx);

	Format(sStringEx, sizeof(sStringEx), "%t", "CraftGnome", iCountGnomes[client], GetConVarInt(NeedToCraftGnome))
	AddMenuItem(MainMenuDisplay, "4", sStringEx);

	SetMenuExitButton(MainMenuDisplay, true)
	DisplayMenu(MainMenuDisplay, client, MENU_TIME_FOREVER);
}

public int Minecraft(Handle MinecraftCallback, MenuAction action, int client, int symbol) 
{ 

	if (action == MenuAction_End) 
	{ 
		CloseHandle(MinecraftCallback); 
		return; 
	} 
	if (action != MenuAction_Select) return; 

	if(bIsSurvivor(client))
	{
		if(symbol == 0)
		{
			if(iCountMedkits[client] >= GetConVarInt(NeedToCraftMedkit))
			{
				iCountMedkits[client] -= GetConVarInt(NeedToCraftMedkit);
				iCraftedMedkits[client]++;
				Client_PrintToChat(client, true, "%t", "YouCraftedMedkit")
			}
			else
			{
				Client_PrintToChat(client, true, "%t", "YouNeedMorePiecesOfMedkits", GetConVarInt(NeedToCraftMedkit) - iCountMedkits[client])
			}
		}
		else if(symbol == 1)
		{
			if(iCountPills[client] >= GetConVarInt(NeedToCraftPills))
			{
				iCountPills[client] -= GetConVarInt(NeedToCraftPills);
				iCraftedPills[client]++;
				Client_PrintToChat(client, true, "%t", "YouCraftedPills")
			}
			else
			{
				Client_PrintToChat(client, true, "%t", "YouNeedMorePiecesOfPills", GetConVarInt(NeedToCraftPills) - iCountPills[client])
			}
		}
		else if(symbol == 2)
		{
			if(iCountAdrenalins[client] >= GetConVarInt(NeedToCraftAdrenaline))
			{
				iCountAdrenalins[client] -= GetConVarInt(NeedToCraftAdrenaline);
				iCraftedAdrenalins[client]++;
				Client_PrintToChat(client, true, "%t", "YouCraftedAdrenaline")
			}
			else
			{
				Client_PrintToChat(client, true, "%t", "YouNeedMorePiecesOfAdrenaline", GetConVarInt(NeedToCraftAdrenaline) - iCountAdrenalins[client])
			}
		}
		else if(symbol == 3)
		{
			if(iCountDebifs[client] >= GetConVarInt(NeedToCraftDefib))
			{
				iCountDebifs[client] -= GetConVarInt(NeedToCraftDefib);
				iCraftedDebifs[client]++;
				Client_PrintToChat(client, true, "%t", "YouCraftedDefib")
			}
			else
			{
				Client_PrintToChat(client, true, "%t", "YouNeedMorePiecesOfDefib", GetConVarInt(NeedToCraftDefib) - iCountDebifs[client])
			}
		}
		else if(symbol == 4)
		{
			if(iCountGnomes[client] >= GetConVarInt(NeedToCraftGnome))
			{
				iCountAdrenalins[client] -= GetConVarInt(NeedToCraftGnome);
				iCraftedGnomes[client]++;
				Client_PrintToChat(client, true, "%t", "YouCraftedGnome")
			}
			else
			{
				Client_PrintToChat(client, true, "%t", "YouNeedMorePiecesOfGnome", GetConVarInt(NeedToCraftAdrenaline) - iCountGnomes[client])
			}
		}
	}
}

void DisplayMainMenu(int client)
{	
	Handle MainMenuDisplay = CreateMenu(MainBox);
	//char sTitle[56];
	SetMenuTitle(MainMenuDisplay, "%t", "MainMenuTitle");
	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "Stats")
	AddMenuItem(MainMenuDisplay, "0", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "Passive Perks")
	AddMenuItem(MainMenuDisplay, "1", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "Perks")
	AddMenuItem(MainMenuDisplay, "2", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "TrasferOfMoney")
	AddMenuItem(MainMenuDisplay, "3", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "TransferToTeamBank")
	AddMenuItem(MainMenuDisplay, "4", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamImprovements")
	AddMenuItem(MainMenuDisplay, "5", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "ShopMainMenu")
	AddMenuItem(MainMenuDisplay, "6", sStringEx);
	
	if(iMinecraft[client])
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "CrafMainMenu")
		AddMenuItem(MainMenuDisplay, "7", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "CrafMainMenu")
		AddMenuItem(MainMenuDisplay, "7", sStringEx, ITEMDRAW_DISABLED);
	}
	
	Format(sStringEx, sizeof(sStringEx), "%t", "InventoryMainMenu")
	AddMenuItem(MainMenuDisplay, "8", sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "BagMainMenu")
	AddMenuItem(MainMenuDisplay, "9", sStringEx);
	
	SetMenuExitButton(MainMenuDisplay, true)
	DisplayMenu(MainMenuDisplay, client, MENU_TIME_FOREVER);
}

void DisplayPerksPassiveMenu(int client)
{	
	Handle MainPassivePerks = CreateMenu(MainPerksPassiveMenu);	
	SetMenuTitle(MainPassivePerks, "%t", "TitleMenuPassivePerks");
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "PerkHelpingHand", GetConVarInt(CostHelpingHand));
	
	if(FakeAdrenaline[client])
	{
		AddMenuItem(MainPassivePerks, "0", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "0", sStringEx);
	}

	Format(sStringEx, sizeof(sStringEx), "%t", "PerkSpeedUp", GetConVarInt(CostSpeedUp));
	if(SpeedUp[client])
	{
		AddMenuItem(MainPassivePerks, "1", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "1", sStringEx);
	}
	
	Format(sStringEx, sizeof(sStringEx), "%t", "PerkDoubleJump", GetConVarInt(CostDoubleJump));
	if(DoubleJump[client])
	{
		AddMenuItem(MainPassivePerks, "2", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "2", sStringEx);
	}
	
	Format(sStringEx, sizeof(sStringEx), "%t", "PerkAntiDamage", GetConVarInt(CostAntiDamage));
	if(AntiDamage[client])
	{
		AddMenuItem(MainPassivePerks, "3", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "3", sStringEx);
	}
	
	Format(sStringEx, sizeof(sStringEx), "%t", "MeleeDamage", GetConVarInt(CostMeleeDamage));
	if(MeleeDamageUp[client])
	{
		AddMenuItem(MainPassivePerks, "4", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "4", sStringEx);
	}
	
	Format(sStringEx, sizeof(sStringEx), "%t", "FastRealodPerk", GetConVarInt(CostFastReload));
	if(FastReload[client])
	{
		AddMenuItem(MainPassivePerks, "5", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(MainPassivePerks, "5", sStringEx);
	}
	SetMenuExitButton(MainPassivePerks, true);
	DisplayMenu(MainPassivePerks, client, MENU_TIME_FOREVER);
}

public int MainPerksPassiveMenu(Handle TeamUpgradeMenu, MenuAction action, int client, int symbol) 
{ 

	if (action == MenuAction_End) 
	{ 
		CloseHandle(TeamUpgradeMenu); 
		return; 
	} 
	if (action != MenuAction_Select) return; 

	if(bIsSurvivor(client))
	{
		if(symbol == 0)
		{
			if(Cash[client] >= GetConVarInt(CostHelpingHand))
			{
				DisplayMainMenu(client)
				FakeAdrenaline[client] = true;
				Cash[client] -= GetConVarInt(CostHelpingHand)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostHelpingHand))
			}
				
		}
		else if(symbol == 1)
		{
			if(Cash[client] >= GetConVarInt(CostSpeedUp))
			{
				DisplayMainMenu(client)
				SpeedUp[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.2)
				SetEntityGravity(client, 0.8);
				Cash[client] -= GetConVarInt(CostSpeedUp)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostSpeedUp))
			}
		}
		else if(symbol == 2)
		{
			if(Cash[client] >= GetConVarInt(CostDoubleJump))
			{
				DisplayMainMenu(client)
				DoubleJump[client] = true;
				Cash[client] -= GetConVarInt(CostDoubleJump)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostDoubleJump))
			}
		}
		else if(symbol == 3)
		{
			if(Cash[client] >= GetConVarInt(CostAntiDamage))
			{
				DisplayMainMenu(client)
				AntiDamage[client] = true;
				Cash[client] -= GetConVarInt(CostAntiDamage)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostAntiDamage))
			}
		}
		else if(symbol == 4)
		{
			if(Cash[client] >= GetConVarInt(CostMeleeDamage))
			{
				DisplayMainMenu(client)
				MeleeDamageUp[client] = true;
				Cash[client] -= GetConVarInt(CostMeleeDamage)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostMeleeDamage))
			}
		}
		else if(symbol == 5)
		{
			if(Cash[client] >= GetConVarInt(CostFastReload))
			{
				DisplayMainMenu(client)
				FastReload[client] = true;
				Cash[client] -= GetConVarInt(CostFastReload)
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostFastReload))
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)  
{
	if(bIsSurvivor(attacker))
	{
		if(MeleeDamageUp[attacker])
		{
			char sWeaponEx[32];
			int iCurrentWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
			if(IsValidEntity(iCurrentWeapon) && iCurrentWeapon > 1)
			{
				GetEntityClassname(iCurrentWeapon, sWeaponEx, sizeof(sWeaponEx));
				if(StrContains(sWeaponEx, "melee") > 1)
				{
					damage *= 1.25;
					return Plugin_Changed;
				}
			}
		}
	}
	if(bIsSurvivor(victim))
	{
		if(AntiDamage[victim])
		{
			damage *= 0.5;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

void ShowPerksPanelUpgradePipe(int client)
{
	Handle PerksUpgrade = CreatePanel();
	if(vLvLPipes[client] < vMaxLvLPipes)
	{
		char sStringEx[128];
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkNameOfUpgradePipeBomb");
		
		char sPanelEx[32];
		Format(sPanelEx, sizeof(sPanelEx), "%t", "TitleOfUpgradePipeBomb");
		SetPanelTitle(PerksUpgrade, sPanelEx);
		
		DrawPanelItem(PerksUpgrade, sStringEx, ITEMDRAW_DISABLED);
		
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkPipeBomblvl", vLvLPipes[client]);
		DrawPanelItem(PerksUpgrade, sStringEx, ITEMDRAW_DISABLED);
	
		Format(sStringEx, sizeof(sStringEx), "%t", "CostOfUpgradePipeBomb", GetConVarInt(CostUpgradePipe));
		DrawPanelItem(PerksUpgrade, sStringEx, ITEMDRAW_DISABLED);
		
		Format(sStringEx, sizeof(sStringEx), "%t", "CountOfPipesOfPerkPipeBomb", vLvLPipes[client]);
		DrawPanelItem(PerksUpgrade, sStringEx, ITEMDRAW_DISABLED);

		DrawPanelItem(PerksUpgrade, "Прокачать");
		DrawPanelItem(PerksUpgrade, "Выйти");
		
/*		
		DrawPanelItem(PerksUpgrade, "Перк: Пайпо Мёт", ITEMDRAW_DISABLED);
		char sItemEx[32];
		Format(sItemEx, sizeof(sItemEx), "Уровень перка: %i", vLvLPipes[client]);
		DrawPanelItem(PerksUpgrade, sItemEx, ITEMDRAW_DISABLED);

		DrawPanelItem(PerksUpgrade, "Стоимость прокачки: 1000 ", ITEMDRAW_DISABLED);
		char sItemExPipes[64];
		Format(sItemExPipes, sizeof(sItemExPipes), "Кол-во вылетаемых пайп: %i", vLvLPipes[client]);
		DrawPanelItem(PerksUpgrade, sItemExPipes, ITEMDRAW_DISABLED);

		DrawPanelItem(PerksUpgrade, "Прокачать");
		DrawPanelItem(PerksUpgrade, "Выйти");
	
*/
		SendPanelToClient(PerksUpgrade, client, PerksUpgradeCallback, 0);
		CloseHandle(PerksUpgrade);
	}
	else
	{
		Client_PrintToChat(client, true, "{R}Вы {L}достигли макс. уровня перка(Пайпо Мёт)");
	}
}

public int PerksUpgradeCallback(Handle panel, MenuAction action, int client, int symbol) 
{ 
	if (action == MenuAction_End) 
	{ 
		CloseHandle(panel); 
		return; 
	} 
	if (action != MenuAction_Select) return;

	if(symbol == 5)
	{
		if(Cash[client] >= GetConVarInt(CostUpgradePipe))
		{
			Cash[client] -= GetConVarInt(CostUpgradePipe);
			vLvLPipes[client]++;
			Client_PrintToChat(client, true, "%t", "YouHasBeenUpgradedPipeBomb");
			Client_PrintToChat(client, true, "%t", "CountOfPipesPerk", vLvLPipes[client]);
			
			//Client_PrintToChat(client, true, "{R}Вы {L}прокачали перк(Пайпо Мёт)");
			//Client_PrintToChat(client, true, "{R}Кол-во пайп:%i", vLvLPipes[client]);
			DisplayMainMenu(client);
		}
	}
}

void DisplayPerksMenu(int client)
{	
	Handle MainPerks = CreateMenu(MainPerksMenu);	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "TitleNameOfMenuPerks");
	SetMenuTitle(MainPerks, sStringEx);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "PerkPipeBombUpgrade++", GetConVarInt(CostUpgradePipe));
	if(pPipeDealer[client])
	{
		AddMenuItem(MainPerks, "0", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkPipeBomb", GetConVarInt(CostUltraPipe));
		AddMenuItem(MainPerks, "0", sStringEx);
	}
	if(!vPipeIndixite[client])
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "StickyPipeBomb", GetConVarInt(CostPipeIndixite));
		AddMenuItem(MainPerks, "1", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "StickyPipeBomb", GetConVarInt(CostPipeIndixite));
		AddMenuItem(MainPerks, "1", sStringEx, ITEMDRAW_DISABLED);
	}
	if(!ShoveDamage[client])
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "ShoveDamage", GetConVarInt(CostShoveDamage));
		AddMenuItem(MainPerks, "2", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "ShoveDamage", GetConVarInt(CostShoveDamage));
		AddMenuItem(MainPerks, "2", sStringEx, ITEMDRAW_DISABLED);
	}
	if(!iMinecraft[client])
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkCrafting", GetConVarInt(CostMinecraft));
		AddMenuItem(MainPerks, "3", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkCrafting", GetConVarInt(CostMinecraft));
		AddMenuItem(MainPerks, "3", sStringEx, ITEMDRAW_DISABLED);
	}
	if(!TripleMolotov[client])
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkEpicMolotov", GetConVarInt(CostEpicMoli));
		AddMenuItem(MainPerks, "4", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "PerkEpicMolotov++", GetConVarInt(CostEpicMoliUpgrade));
		AddMenuItem(MainPerks, "4", sStringEx);
	}
	
	SetMenuExitButton(MainPerks, true);
	DisplayMenu(MainPerks, client, MENU_TIME_FOREVER);
}

public int MainPerksMenu(Handle TransferMenu, MenuAction action, int client, int symbol) 
{ 
	if (action == MenuAction_End)
	{ 
		CloseHandle(TransferMenu); 
		return; 
	} 
	if (action != MenuAction_Select) return;

	if(symbol == 0)
	{
		if(!pPipeDealer[client])
		{
			if(Cash[client] >= GetConVarInt(CostUltraPipe))
			{
				Cash[client] -= GetConVarInt(CostUltraPipe);
				pPipeDealer[client] = true;
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostUltraPipe));
				DisplayMainMenu(client);
			}
		}
		else
		{
			ShowPerksPanelUpgradePipe(client);
		}
	}
	else if(symbol == 1)
	{
		if(Cash[client] >= GetConVarInt(CostPipeIndixite))
		{
			Cash[client] -= GetConVarInt(CostPipeIndixite);
			vPipeIndixite[client] = true;
			Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostPipeIndixite));
			DisplayMainMenu(client);
		}
	}
	else if(symbol == 2)
	{
		if(Cash[client] >= GetConVarInt(CostShoveDamage))
		{
			Cash[client] -= GetConVarInt(CostShoveDamage);
			ShoveDamage[client] = true;
			Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostShoveDamage));
			DisplayMainMenu(client);
		}
	}
	else if(symbol == 3)
	{
		if(Cash[client] >= GetConVarInt(CostMinecraft))
		{
			Cash[client] -= GetConVarInt(CostMinecraft);
			iMinecraft[client] = true;
			Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostMinecraft));
			DisplayMainMenu(client);
		}
	}
	else if(symbol == 4)
	{
		if(!TripleMolotov[client])
		{
			if(Cash[client] >= GetConVarInt(CostEpicMoli))
			{
				Cash[client] -= GetConVarInt(CostEpicMoli);
				TripleMolotov[client] = true;
				Client_PrintToChat(client, true, "{B}-%i", GetConVarInt(CostEpicMoli));
				DisplayMainMenu(client);
			}
		}
		else
		{
			DisplayUpgradeMolotov(client);
		}
	}
}

void DisplayUpgradeMolotov(int client)
{	
	Handle MolikUp = CreateMenu(UpgradeMoloCall);

	int iLevel = iCountOfMoliks[client];
	int iLevelM = iCountOfMoliks[client] + 1;
	//char sTitle[56];
	SetMenuTitle(MolikUp, "%t", "UpgradeMolotovTitle");
	
	char sStringEx[128];
	Format(sStringEx, sizeof(sStringEx), "%t", "NameOfPerkMolotov");
	AddMenuItem(MolikUp, "0", sStringEx, ITEMDRAW_DISABLED);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "CostUpgradeMolotov", GetConVarInt(CostEpicMoliUpgrade));
	AddMenuItem(MolikUp, "1", sStringEx, ITEMDRAW_DISABLED);
	
	Format(sStringEx, sizeof(sStringEx), "%t", "CountOfMolotovs", iLevel, iMaxLevelMolo);
	AddMenuItem(MolikUp, "2", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "CountOfMolotovsOnNextLevel", iLevelM);
	AddMenuItem(MolikUp, "3", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "LevelOfPerk", iLevel);
	AddMenuItem(MolikUp, "4", sStringEx, ITEMDRAW_DISABLED);

	Format(sStringEx, sizeof(sStringEx), "%t", "UpgradeMolikButton");
	AddMenuItem(MolikUp, "5", sStringEx);

	SetMenuExitButton(MolikUp, true);
	DisplayMenu(MolikUp, client, MENU_TIME_FOREVER);
}

public int UpgradeMoloCall(Handle Shop, MenuAction action, int client, int symbol) 
{ 
	if (action == MenuAction_End) 
	{ 
		CloseHandle(Shop); 
		return; 
	} 
	if (action != MenuAction_Select) return; 
	
	if(symbol == 5)
	{
		if(iCountOfMoliks[client] < iMaxLevelMolo)
		{
			if(Cash[client] >= GetConVarInt(CostEpicMoliUpgrade))
			{
				Cash[client] -= GetConVarInt(CostEpicMoliUpgrade);
				iCountOfMoliks[client]++;
				Client_PrintToChat(client, true, "%t", "YouUpgradedMolotov", iCountOfMoliks[client], iMaxLevelMolo);
				Client_PrintToChat(client, true, "%t", "CountOfMolotovUpgraded", iCountOfMoliks[client]);
				DisplayMainMenu(client);
			}
		}
		else
		{
			Client_PrintToChat(client, true, "%t", "MaxLevelOfMolotov");
			DisplayMainMenu(client);
		}
	}
}

void DisplayStatisticMenu(int client)
{	
	Handle MainStats = CreateMenu(MainStatsMenu);
	char sItemEx[56];
	Format(sItemEx, sizeof(sItemEx), "%t", "TitleOfMenuStatistic");
	SetMenuTitle(MainStats, sItemEx);

	Format(sItemEx, sizeof(sItemEx), "%t", "YourMoney", Cash[client]);
	AddMenuItem(MainStats, sItemEx, sItemEx, ITEMDRAW_DISABLED);

	Format(sItemEx, sizeof(sItemEx), "%t", "TeamCash", TeamCash);
	AddMenuItem(MainStats, sItemEx, sItemEx, ITEMDRAW_DISABLED);
	
	SetMenuExitButton(MainStats, true);
	DisplayMenu(MainStats, client, MENU_TIME_FOREVER);
}

public int MainStatsMenu(Handle menu, MenuAction action, int client, int symbol){}

void DisplayBankTo(int client)
{	
	Handle BankTo = CreateMenu(MenuBankTransfer);	
	SetMenuTitle(BankTo, "Ваш вклад:");
	AddMenuItem(BankTo, "0", "10%");
	AddMenuItem(BankTo, "1", "20%");
	AddMenuItem(BankTo, "2", "30%");
	AddMenuItem(BankTo, "3", "40%");
	AddMenuItem(BankTo, "4", "50%");
	AddMenuItem(BankTo, "5", "60%");
	AddMenuItem(BankTo, "6", "70%");
	AddMenuItem(BankTo, "7", "80%");
	AddMenuItem(BankTo, "8", "90%");
	AddMenuItem(BankTo, "9", "100%");

	SetMenuExitButton(BankTo, true);
	DisplayMenu(BankTo, client, MENU_TIME_FOREVER);
}

void DisplayShop(int client)
{	
	Handle Shop = CreateMenu(MenuShop);	
	char sItemEx[96];
	Format(sItemEx, sizeof(sItemEx), "%t", "TitleOfMenuShop");
	SetMenuTitle(Shop, sItemEx);
	
	Format(sItemEx, sizeof(sItemEx), "%t", "ShopExplosiveAmmo", GetConVarInt(CostExpAmmo));
	AddMenuItem(Shop, "0", sItemEx);
	
	Format(sItemEx, sizeof(sItemEx), "%t", "ShopIncendiaryAmmo", GetConVarInt(CostIncAmmo));
	AddMenuItem(Shop, "1", sItemEx);
	
	Format(sItemEx, sizeof(sItemEx), "%t", "ShopLaserSight", GetConVarInt(CostLaserSight));
	AddMenuItem(Shop, "2", sItemEx);
	
	Format(sItemEx, sizeof(sItemEx), "%t", "ShopExplosiveAmmoPack", GetConVarInt(CostExpAmmoPack));
	AddMenuItem(Shop, "3", sItemEx);
	
	Format(sItemEx, sizeof(sItemEx), "%t", "ShopIncendiaryAmmoPack", GetConVarInt(CostIncAmmoPack));
	AddMenuItem(Shop, "4", sItemEx);
	//AddMenuItem(Shop, "3", "40%");
	//AddMenuItem(Shop, "4", "50%");
	//AddMenuItem(Shop, "5", "60%");
	//AddMenuItem(Shop, "6", "70%");
	//AddMenuItem(Shop, "7", "80%");
	//AddMenuItem(Shop, "8", "90%");
	//AddMenuItem(Shop, "9", "100%");

	SetMenuExitButton(Shop, true);
	DisplayMenu(Shop, client, MENU_TIME_FOREVER);
}

public int MenuShop(Handle Shop, MenuAction action, int client, int symbol) 
{ 
	if (action == MenuAction_End) 
	{
		CloseHandle(Shop); 
		return; 
	} 
	if (action != MenuAction_Select) return; 
	
	if(symbol == 0)
	{
		if(Cash[client] >= GetConVarInt(CostExpAmmo))
		{
			Cash[client] -= GetConVarInt(CostExpAmmo);
			GiveUpgrade(client, 1);
			Client_PrintToChat(client, true, "%t", "BoughtExpAmmo");
		}
	}
	else if(symbol == 1)
	{
		if(Cash[client] >= GetConVarInt(CostIncAmmo))
		{
			Cash[client] -= GetConVarInt(CostIncAmmo);
			GiveUpgrade(client, 2);
			Client_PrintToChat(client, true, "%t", "BoughtIncAmmo");
		}
	}
	else if(symbol == 2)
	{
		if(Cash[client] >= GetConVarInt(CostLaserSight))
		{
			Cash[client] -= GetConVarInt(CostLaserSight);
			GiveUpgrade(client, 3);
			Client_PrintToChat(client, true, "%t", "BoughtLaserSight");
		}
	}
	else if(symbol == 3)
	{
		if(Cash[client] >= GetConVarInt(CostExpAmmoPack))
		{
			Cash[client] -= GetConVarInt(CostExpAmmoPack);
			GiveFunction(client, "upgradepack_explosive");
			Client_PrintToChat(client, true, "%t", "BoughtExpAmmo");
		}
	}
	else if(symbol == 4)
	{
		if(Cash[client] >= GetConVarInt(CostIncAmmoPack))
		{
			Cash[client] -= GetConVarInt(CostIncAmmoPack);
			GiveFunction(client, "upgradepack_incendiary");
			Client_PrintToChat(client, true, "%t", "BoughtIncAmmo");
		}
	}
}

public int MenuBankTransfer(Handle TransferMenu, MenuAction action, int client, int symbol) 
{ 
	if (action == MenuAction_End) 
	{ 
		CloseHandle(TransferMenu);
		return; 
	} 
	if (action != MenuAction_Select) return; 

	int TrasferCash = Cash[client];
	int NumCash = 0;
	int Procents = 0;
	if(bIsSurvivor(client))
	{
		if(symbol == 0)
		{
			NumCash = RoundToCeil(TrasferCash * 0.1);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 10;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 1)
		{
			NumCash = RoundToCeil(TrasferCash * 0.2);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 20;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 2)
		{
			NumCash = RoundToCeil(TrasferCash * 0.3);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 30;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 3)
		{
			NumCash = RoundToCeil(TrasferCash * 0.4);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 40;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 4)
		{
			NumCash = RoundToCeil(TrasferCash * 0.5);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 50;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 5)
		{
			NumCash = RoundToCeil(TrasferCash * 0.6);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 60;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 6)
		{
			NumCash = RoundToCeil(TrasferCash * 0.7);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 70;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 7)
		{
			NumCash = RoundToCeil(TrasferCash * 0.8);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 80;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 8)
		{
			NumCash = RoundToCeil(TrasferCash * 0.9);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 90;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
		else if(symbol == 9)
		{
			NumCash = RoundToCeil(TrasferCash * 1.0);
			Cash[client] -= NumCash;
			TeamCash += NumCash;
			Procents = 100;
			Client_PrintToChat(client, true, "%t", "ProcentsInBank", NumCash, Procents);
			//Client_PrintToChat(client, true, "{B}Вы положили в банк {BLA}%i", NumCash);
		}
	}
}

void DisplayTeamHelp(int client)
{	
	Handle TeamUp = CreateMenu(MenuTeamUpgrade);	
	char sStringEx[64];
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradesTitle");
	
	SetMenuTitle(TeamUp, sStringEx);
	if(vHealUpTeam == null)
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeRegeneration");
		AddMenuItem(TeamUp, "0", sStringEx);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeRegeneration");
		AddMenuItem(TeamUp, "0", sStringEx, ITEMDRAW_DISABLED);
	}
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeKillAllCommons");
	AddMenuItem(TeamUp, "1", sStringEx);
	if(vPoisonTeam != null)
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradePoisonForSpecialInfected");
		AddMenuItem(TeamUp, "2", sStringEx, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradePoisonForSpecialInfected");
		AddMenuItem(TeamUp, "2", sStringEx);
	}
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeIgniteAssForAllSpecials");
	AddMenuItem(TeamUp, "3", sStringEx);
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeHealAllSurvivorFor50Hp");
	AddMenuItem(TeamUp, "4", sStringEx);
	Format(sStringEx, sizeof(sStringEx), "%t", "TeamUpgradeBuyAmmoForAllSurvivors");
	AddMenuItem(TeamUp, "5", sStringEx);
	SetMenuExitButton(TeamUp, true);
	DisplayMenu(TeamUp, client, MENU_TIME_FOREVER);
}

public int MenuTeamUpgrade(Handle TeamUpgradeMenu, MenuAction action, int client, int symbol) 
{
	if (action == MenuAction_End)
	{ 
		CloseHandle(TeamUpgradeMenu); 
		return; 
	} 
	if (action != MenuAction_Select) return; 

	if(bIsSurvivor(client))
	{
		if(symbol == 0)
		{
			if(TeamCash >= 50000)
			{
				vHealUpTeam = CreateTimer(2.0, vTeamHealUp, _, TIMER_REPEAT);
				//TeamHeal = true;
				TeamCash -= 50000;
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t", "ChatWhoBoughtRegeneration", client);
							//Client_PrintToChat(i, true, "{B}%N {R}купил регенерацию хп для выживших.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t", "YouBuyRegeneration");
							//Client_PrintToChat(i, true, "{B}Вы {R}купили регенерацию хп.");
						}
					}
				}
			}
		}
		else if(symbol == 1)
		{
			if(TeamCash >= 30000)
			{
				TeamCash -= 30000;
				for(int i = 33; i <= 2048; ++i)
				{
					if(IsCommonInfected(i))
					{
						ForceDamageEntity(client, 1000, i);
					}
				}
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t", "WhoKilledAllCommonForTeamCash", client);
							//Client_PrintToChat(i, true, "{B}%N {R}убил всех мобов за командные очки.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t", "YouKilledAllCommonsForTeamCash");
						}
					}
				}
			}
		}
		else if(symbol == 2)
		{
			if(TeamCash >= 30000)
			{
				vPoisonTeam = CreateTimer(2.0, vTeamPoison, client, TIMER_REPEAT);
				CreateTimer(30.0, vTeamPoisonKill);
				TeamCash -= 30000;
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "WhoPoisonedInf", client);
							//Client_PrintToChat(i, true, "{B}%N {R}отравил заражённых за командные очки.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "YouPoisonedInf", client);
							Client_PrintToChat(i, true, "{B}Вы {R}отравили заражённых.");
						}
					}
				}
			}
		}
		else if(symbol == 3)
		{
			if(TeamCash >= 10000)
			{
				TeamCash -= 10000;
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "WhoIgnitedTheHearts", client);
							//Client_PrintToChat(i, true, "{B}%N {R}поджог пукан заражённых.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "YouIgnitedTheHearts", client);
							Client_PrintToChat(i, true, "{B}Вы {R}воспламенили очаг.");
						}
					}
					if(IsValidInfected(i))
					{
						float vPos[3];
						GetClientAbsOrigin(i, vPos);
						LittleFlower(vPos, 0);
						LittleFlower(vPos, 1);
					}
				}
			}
		}
		else if(symbol == 4)
		{
			if(TeamCash >= 15000)
			{
				TeamCash -= 15000;
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "WhoHealedSurvivors", client);
							//Client_PrintToChat(i, true, "{B}%N {R}вылечил всех на 50 хп за командные очки.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "YouHealedSurvivors");
							//Client_PrintToChat(i, true, "{B}Вы {R}полечили всех выживших.");
						}
					}
					if(bIsSurvivor(i) && !IsPlayerIncaped(i))
					{
						int vHeal = GetClientHealth(i);
						float vHealthBuffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");
						
						if(vHeal + 50 + RoundToCeil(vHealthBuffer) > 100 || vHeal > 100 || vHealthBuffer > 100 || vHeal + vHealthBuffer > 100) 
						{
							SetEntityHealth(i, 100);
							SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
						}
						else if(RoundToCeil(vHeal + vHealthBuffer) < 100)
						{
							float vForward = vHeal - vHealthBuffer;
							if(vForward < 0)
							{
								SetEntityHealth(i, vHeal + 50);
								SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
							}
							else
							{
								float vTransitPoint = 50 - vHealthBuffer;
								SetEntityHealth(i, RoundToCeil(vHeal + vTransitPoint));
								SetEntPropFloat(client, Prop_Send, "m_healthBuffer", vHealthBuffer - vTransitPoint);
							}
						}
					}
				}
			}
		}
		else if(symbol == 5)
		{
			if(TeamCash >= 3000)
			{
				TeamCash -= 3000;
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(client != i)
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "WhoBuyAmmo", client);
							//Client_PrintToChat(i, true, "{B}%N {R}купил всем патроны за командные очки.", client);
						}
					}
					else
					{
						if(IsInGame(i))
						{
							Client_PrintToChat(i, true, "%t.", "YouBuyAmmo");
							//Client_PrintToChat(i, true, "{B}Вы {R}купили патроны всем выжившим.");
						}
					}
					if(bIsSurvivor(i))
					{
						GiveFunction(i, "ammo");
					}
				}
			}
		}
	}
}

public Action vTeamHealUp(Handle timer)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(bIsSurvivor(i) && !IsPlayerIncaped(i))
		{
			int iHeal = GetClientHealth(i);
			float vHealthBuffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");

			if(RoundToCeil(vHealthBuffer) > 0 && iHeal < 100)
			{
				SetEntityHealth(i, iHeal + 1);
				SetEntPropFloat(i, Prop_Send, "m_healthBuffer", vHealthBuffer - 1);
			}
			else if(iHeal < 100 && vHealthBuffer < 1)
			{
				SetEntityHealth(i, iHeal + 1);
			}
		}
	}
}

public Action vTeamPoison(Handle timer, int client)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsValidInfected(i))
		{
			ForceDamageEntity(client, 25, i);
		}
	}
}

public Action vTeamPoisonKill(Handle timer)
{
	KillTimer(vPoisonTeam);
	vPoisonTeam = null;
}

void DisplayTransfer(int client)
{
	Handle MainTransfer = CreateMenu(MenuTrasnfer);
	char sStringEx[32];
	Format(sStringEx, sizeof(sStringEx), "%t", "MenuTitleOfTransferPlayersList");
	SetMenuTitle(MainTransfer, sStringEx);
	
	char userid[15];
	char name[32];
	
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if (bIsSurvivor(i) && !IsFakeClient(i) && client != i) 
		{
			IntToString(GetClientUserId(i), userid, 15); 
			GetClientName(i, name, 32); 
			AddMenuItem(MainTransfer, userid, name);
		} 
	}
	SetMenuExitButton(MainTransfer, true);
	DisplayMenu(MainTransfer, client, MENU_TIME_FOREVER);
}

void DisplayTransferSecondPart(int client)
{	
	Handle MainTransferSecond = CreateMenu(MenuTrasnferSecond);	
	char sStringEx[32];
	Format(sStringEx, sizeof(sStringEx), "%t", "MenuTitleOfTransfer");
	SetMenuTitle(MainTransferSecond, sStringEx);
	
	AddMenuItem(MainTransferSecond, "0", "10%");
	AddMenuItem(MainTransferSecond, "1", "20%");
	AddMenuItem(MainTransferSecond, "2", "30%");
	AddMenuItem(MainTransferSecond, "3", "40%");
	AddMenuItem(MainTransferSecond, "4", "50%");
	AddMenuItem(MainTransferSecond, "5", "60%");
	AddMenuItem(MainTransferSecond, "6", "70%");
	AddMenuItem(MainTransferSecond, "7", "80%");
	AddMenuItem(MainTransferSecond, "8", "90%");
	AddMenuItem(MainTransferSecond, "9", "100%");
	
	SetMenuExitButton(MainTransferSecond, true);
	DisplayMenu(MainTransferSecond, client, MENU_TIME_FOREVER);
}

public int MenuTrasnferSecond(Handle MenuTrasnferCallback, MenuAction action, int client, int symbol) 
{
	if(bIsSurvivor(client))
	{
		if (action == MenuAction_End)
		{ 
			CloseHandle(MenuTrasnferCallback); 
			return; 
		} 
		if (action != MenuAction_Select) return;
		
		int TrasferCash = Cash[client];
		int Victim = Target[client];
		int NumCash = 0;
		int Percents = 0;
		if(symbol == 0)
		{
			NumCash = RoundToCeil(TrasferCash * 0.1);
			Cash[client] -= NumCash;
			Cash[Victim] += NumCash;
			Percents = 10;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 1)
		{
			NumCash = RoundToCeil(TrasferCash * 0.2);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 20;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 2)
		{
			NumCash = RoundToCeil(TrasferCash * 0.3);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 30;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 3)
		{
			NumCash = RoundToCeil(TrasferCash * 0.4);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 40;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 4)
		{
			NumCash = RoundToCeil(TrasferCash * 0.5);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 50;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 5)
		{
			NumCash = RoundToCeil(TrasferCash * 0.6);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 60;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 6)
		{
			NumCash = RoundToCeil(TrasferCash * 0.7);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 70;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 7)
		{
			NumCash = RoundToCeil(TrasferCash * 0.8);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 80;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 8)
		{
			NumCash = RoundToCeil(TrasferCash * 0.9);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 90;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
		else if(symbol == 9)
		{
			NumCash = RoundToCeil(TrasferCash * 1.0);
			Cash[client] -= NumCash;
			Cash[Target[client]] += NumCash;
			Percents = 100;
			Client_PrintToChat(client, true, "%t", "YouGaveTheTeammate", Victim, NumCash, Percents);
			Client_PrintToChat(Victim, true, "%t", "YouReceivedFromTeammate", client, NumCash, Percents);
		}
	}
}

/*
void DisplayMuneBought(int client)
{
	Handle MenuBought = CreateMenu(MenuBoughtD);
	char sExternalString[32];
	Format(sExternalString, sizeof(sExternalString), "%t", "TitleNameOfMyPurchase");
	SetMenuTitle(MenuBought, sExternalString);
	if(ShoveDamage[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "ShoveDamage");
		AddMenuItem(MenuBought, "1", sExternalString, ITEMDRAW_DISABLED);
	}
	if(FakeAdrenaline[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "PerkHelpingHand");
		AddMenuItem(MenuBought, "2", sExternalString, ITEMDRAW_DISABLED);
	}
	if(SpeedUp[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "PerkSpeedUp");
		AddMenuItem(MenuBought, "3", sExternalString, ITEMDRAW_DISABLED);
	}
	if(pPipeDealer[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "PerkPipeBomb");
		AddMenuItem(MenuBought, "4", sExternalString, ITEMDRAW_DISABLED);
	}
	if(vPipeIndixite[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "StickyPipeBomb");
		AddMenuItem(MenuBought, "4", sExternalString, ITEMDRAW_DISABLED);
	}
	if(DoubleJump[client])
	{
		Format(sExternalString, sizeof(sExternalString), "%t", "PerkDoubleJump");
		AddMenuItem(MenuBought, "5", sExternalString, ITEMDRAW_DISABLED);
	}
	SetMenuExitButton(MenuBought, true);
	DisplayMenu(MenuBought, client, MENU_TIME_FOREVER);
}

public int MenuBoughtD(Handle NotNeeddeed, MenuAction action, int client, int symbol){}
*/
public int MenuTrasnfer(Handle CallBackTransfer, MenuAction action, int client, int option) 
{ 
	if(bIsSurvivor(client))
	{
		if (action == MenuAction_End) 
		{ 
			CloseHandle(CallBackTransfer); 
			return; 
		} 
		if (action != MenuAction_Select) return; 
		char userid[15]; 
		GetMenuItem(CallBackTransfer, option, userid, 15); 
		int target = GetClientOfUserId(StringToInt(userid)); 
		if (bIsSurvivor(target)) 
		{
			DisplayTransferSecondPart(client); 
			Target[client] = target;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(bIsSurvivor(client))
	{
		if(DoubleJump[client])
		{
			Jump(client);
		}
	}
}

stock bool IsValidInfected(int client)
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( GetClientTeam( client ) != 3 ) return false;
	return true;
}

stock bool IsWitch(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char entType[64];
		GetEdictClassname(entity, entType, sizeof(entType));
		return StrEqual(entType, "witch");
	}
	return false;
}

stock void Jump(int client)
{
	int fCurFlags = GetEntityFlags(client);
	int fCurButtons	= GetClientButtons(client);

	if (g_fLastFlags[client] & FL_ONGROUND) 
	{
		if (!(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP) 
		{
			OriginalJump(client);
		}
	} 
	else if (fCurFlags & FL_ONGROUND) 
	{
		Landed(client);
	} 
	else if (!(g_fLastButtons[client] & IN_JUMP) &&	fCurButtons & IN_JUMP) 
	{
		ReJump(client);
	}
	
	g_fLastFlags[client] = fCurFlags;
	g_fLastButtons[client] = fCurButtons;
}

stock void OriginalJump(const any client) 
{
	g_iJumps[client]++;
}

stock void Landed(const any client) 
{
	g_iJumps[client] = 0;
}

stock void ReJump(const any client)
{
	if ( 1 <= g_iJumps[client] <= g_iJumpMax) 
	{						
		g_iJumps[client]++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		
		vVel[2] = 300.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

stock void ForceDamageEntity(int causer, int damage, int victim) // thanks to 达斯*维达
{
	float victim_origin[3];
	char rupture[32];
	char damage_victim[32];
	IntToString(damage, rupture, sizeof(rupture));
	Format(damage_victim, sizeof(damage_victim), "hurtme%d", victim);
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victim_origin);
	int entity = CreateEntityByName("point_hurt");
	DispatchKeyValue(victim, "targetname", damage_victim);
	DispatchKeyValue(entity, "DamageTarget", damage_victim);
	DispatchKeyValue(entity, "Damage", rupture);
	DispatchSpawn(entity);
	TeleportEntity(entity, victim_origin, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "Hurt", (causer > 0 && causer <= MaxClients) ? causer : -1);
	DispatchKeyValue(entity, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	AcceptEntityInput(entity, "Kill");
}

stock bool IsPlayerIncaped(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock bool bIsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && !IsClientInKickQueue(client) && IsPlayerAlive(client);
}

stock bool IsCommonInfected(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char entType[64];
		GetEdictClassname(entity, entType, sizeof(entType));
		return StrEqual(entType, "infected");
	}
	return false;
}

/*
bool IsRock(int entity)
{
    if (IsValidEntity(entity)) 
    {
        char sClass[36];
        GetEntityClassname(entity, sClass, sizeof(sClass));
        return StrEqual(sClass, "tank_rock");
    }
    return false;
}
*/
/*
public void ScreenFade(int target, int red, int green, int blue, int alpha, int duration, int type)
{
	Handle msg = StartMessageOne("Fade", target);
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

public void ScreenShake(int target, float power)
{
	Handle msg;
	msg = StartMessageOne("Shake", target);
	BfWriteByte(msg, 0);
 	BfWriteFloat(msg, power);
 	BfWriteFloat(msg, 10.0);
 	BfWriteFloat(msg, 3.0);
	EndMessage();
}
*/

public void LittleFlower(float pos[3], int type) //thanks to ztar
{
	int entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
		else
			DispatchKeyValue(entity, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

void GiveFunction(int client, char[] name)
{
	char sBuf[32];
	int flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FormatEx(sBuf, sizeof sBuf, "give %s", name);
	FakeClientCommand(client, sBuf);
}

stock bool IsInGame(int client)
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	return true;
}

stock bool IsPipe(int entity)
{
	if(IsValidEntity(entity))
	{
		char sWeaponEx[32];
		GetEntityClassname(entity, sWeaponEx, sizeof(sWeaponEx));
		return StrEqual(sWeaponEx, "pipe_bomb_projectile");
	}
	return false;
}

int GetGrenade(int iClient)
{
    char sClass[32] = {"pipe_bomb_projectile"};
    for(int i = 0, iGrenade = -1; i < sizeof(sClass); i++)
    {
        while((iGrenade = FindEntityByClassname(iGrenade, sClass[i])) != -1)
        {
        	if(IsPipe(iGrenade) && iGrenade > 0)
        	{
	            if(GetEntPropEnt(iGrenade, Prop_Send, "m_hThrower") == iClient)
	                return iGrenade;
			}
        }
    }
    return 0;
}

stock bool IsValidClient(int client)
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( GetClientTeam( client ) != 2 ) return false;
	if ( !IsPlayerAlive( client )) return false;
	return true;
}

int GetColor(Handle hCvar)
{
	char sTemp[12];
	GetConVarString(hCvar, sTemp, sizeof(sTemp));
	
	if( StrEqual(sTemp, "") )
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

void MagStart(int iEntid, int client)
{
	float flGameTime = GetGameTime();
	float flNextTime_ret = GetEntDataFloat(iEntid,iNextPrimaryAt);
	float flNextTime_calc = ( flNextTime_ret - flGameTime ) * flRate ;
	SetEntDataFloat(iEntid, iPlayRate, 1.0/flRate, true);
	CreateTimer( flNextTime_calc, Timer_MagEnd, iEntid);
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, client);
	float flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - flRate );
	WritePackFloat(hPack, flStartTime_calc);
	if ( (flNextTime_calc - 0.4) > 0 )
		CreateTimer( flNextTime_calc - 0.4 , Timer_MagEnd2, hPack);
	flNextTime_calc += flGameTime;
	SetEntDataFloat(iEntid, iTimeIdle, flNextTime_calc, true);
	SetEntDataFloat(iEntid, iNextPrimaryAt, flNextTime_calc, true);
	SetEntDataFloat(client, iNextAt, flNextTime_calc, true);
}

public Action Timer_MagEnd(Handle timer, any iEntid)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
		return Plugin_Stop;

	if (iEntid <= 0
		|| IsValidEntity(iEntid)==false)
		return Plugin_Stop;

	SetEntDataFloat(iEntid, iPlayRate, 1.0, true);

	return Plugin_Stop;
}

public Action Timer_MagEnd2(Handle timer, Handle hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
	{
		CloseHandle(hPack);
		return Plugin_Stop;
	}

	ResetPack(hPack);
	int iCid = ReadPackCell(hPack);
	float flStartTime_calc = ReadPackFloat(hPack);
	CloseHandle(hPack);

	if (iCid <= 0
		|| IsValidEntity(iCid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	int iVMid = GetEntDataEnt2(iCid,iViewModel);
	SetEntDataFloat(iVMid, iVMStartTime, flStartTime_calc, true);

	return Plugin_Stop;
}

void GiveUpgrade(int client, int iType)
{
	int flags = GetCommandFlags("upgrade_add");
	SetCommandFlags("upgrade_add", flags & ~FCVAR_CHEAT);
	if(iType == 1)
	{
		FakeClientCommand(client, "upgrade_add explosive_ammo");
	}
	else if(iType == 2)
	{
		FakeClientCommand(client, "upgrade_add incendiary_ammo");
	}
	else if(iType == 3)
	{
		FakeClientCommand(client, "upgrade_add laser_sight");
	}
	SetCommandFlags("upgrade_add", flags|FCVAR_CHEAT);
}

/* I will need this soon
stock void CreateParticle(int client, char[] Particle_Name, bool Parent, float duration)
{
	float pos[3]; char sName[64], sTargetName[64];
	int Particle = CreateEntityByName("info_particle_system");
	GetClientAbsOrigin(client, pos);
	TeleportEntity(Particle, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(Particle, "effect_name", Particle_Name);
	
	if(Parent)
	{
		int userid = GetClientUserId(client);
		Format(sName, sizeof(sName), "%d", userid+25);
		DispatchKeyValue(client, "targetname", sName);
		GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
		
		Format(sTargetName, sizeof(sTargetName), "%d", userid+1000);
		DispatchKeyValue(Particle, "targetname", sTargetName);
		DispatchKeyValue(Particle, "parentname", sName);
	}
	DispatchSpawn(Particle);
	DispatchSpawn(Particle);
	if(Parent)
	{
		SetVariantString(sName);
		AcceptEntityInput(Particle, "SetParent", Particle, Particle);
	}
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	CreateTimer(duration, timerStopAndRemoveParticle, Particle, TIMER_FLAG_NO_MAPCHANGE);
}

public Action timerStopAndRemoveParticle(Handle timer, any entity)
{
	if(entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}
*/