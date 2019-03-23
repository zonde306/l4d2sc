#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_stocks>
#include <l4d2_simple_combat>

#define CVAR_FLAGS FCVAR_NONE
#define SKILLCLIP_SIZE			(1.0 + ((SC_GetClientLevel(client) / 10) * 0.25))
#define SKILLAMMO_SIZE			(1.0 + ((SC_GetClientLevel(client) / 10) * 0.5))
#define SKILLUPGRADE_SIZE		(1.0 + ((SC_GetClientLevel(client) / 10) * 0.25))

#define TEAM_SURVIVORS 2

new const String:WeaponNames[][] =
{
	// AMMOTYPE_ASSAULTRIFLE = 3
	"weapon_rifle",										/*clip: 50*/
	"weapon_rifle_ak47",								/*clip: 40*/
	"weapon_rifle_desert",								/*clip: 60*/
	"weapon_rifle_sg552",			//0~3 offset: +12		/*clip: 50*/
	
	// AMMOTYPE_SMG = 5
	"weapon_smg",										/*clip: 50*/
	"weapon_smg_silenced",								/*clip: 50*/
	"weapon_smg_mp5",				//4~6 offset: +20		/*clip: 50*/
	
	// AMMOTYPE_SHOTGUN = 7
	"weapon_pumpshotgun",								/*clip: 8*/
	"weapon_shotgun_chrome",		//7~8 offset: +28		/*clip: 8*/
	
	// AMMOTYPE_AUTOSHOTGUN = 8
	"weapon_autoshotgun",								/*clip: 10*/
	"weapon_shotgun_spas",			//9~10 offset: +32		/*clip: 10*/
	
	// AMMOTYPE_HUNTINGRIFLE = 9
	"weapon_hunting_rifle",			//11 offset: +36		/*clip: 15*/
	
	// AMMOTYPE_SNIPERRIFLE = 10
	"weapon_sniper_military",							/*clip: 30*/
	"weapon_sniper_awp",								/*clip: 20*/
	"weapon_sniper_scout",			//12~14 offset: +40		/*clip: 15*/
	
	// AMMOTYPE_GRENADELAUNCHER = 17
	"weapon_grenade_launcher",		//15 offset: +68		/*clip: 1*/
	
	// AMMOTYPE_M60 = 6
	"weapon_rifle_m60",				//16 NoOffSet		/*clip: 150*/
	
	// AMMOTYPE_PISTOL = 1
	"weapon_pistol",									/*clip: 15*/
	
	// AMMOTYPE_MAGNUM = 2
	"weapon_pistol_magnum"								/*clip: 8*/

};

static 	Handle:Plugin_Enabled,
		Handle:Gun_ExtraPrimaryAmmo[17],
		Handle:ControlAmmo_Enable[19],
		Handle:Gun_ClipAmmo[19],
		Handle:M60_AmmoPickup_Enabled,
		Handle:GL_AmmoPickup_Enabled,
		iAmmoOffset,
		bool:IsReload[33],
		Handle:Upgrade_Ammo_Explosive,
		Handle:Upgrade_Ammo_Incendiary,
		ShotGunData[33][2],
		bool:IsPickupPistol_2[33],
		Handle:PickupPistol_TimerIndex[33];

Handle g_hFindUseEntity = null;
int g_iLastUpgradeType[MAXPLAYERS+1], g_iLastUpgradeCount[MAXPLAYERS+1];
float g_fLastFired[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "武器弹药控制",
	author = "MicroLeo",
	description = "<- Description ->",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	// Add your own code here...
	if(!GameCheck())SetFailState("Use this in Left4Dead2 only!");
	iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	HookEvent("item_pickup", Event_ItemPickup, EventHookMode_Post);
	HookEvent("ammo_pickup", Event_AmmoPickup, EventHookMode_Post);
	HookEvent("upgrade_pack_added", Event_SpecialAmmo, EventHookMode_Post);
	HookEvent("player_spawn", Event_Player_Spawn,EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire,EventHookMode_Post);
	// HookEvent("weapon_reload", Event_WeaponReload,EventHookMode_Post);
	
	Plugin_Enabled =			CreateConVar("controlammo_enabled","1","插件開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	
	ControlAmmo_Enable[0]	=	CreateConVar("ControlAmmo_rifle_enable","1","M16彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[0] =	CreateConVar("ControlAmmo_rifle_ammo","410","M16储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[0] =			CreateConVar("ControlAmmo_rifle_clip","50","M16弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);

	ControlAmmo_Enable[1]	=	CreateConVar("ControlAmmo_rifle_ak47_enable","1","AK47彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[1] =	CreateConVar("ControlAmmo_rifle_ak47_Ammo","400","AK47储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[1] =			CreateConVar("ControlAmmo_rifle_ak47_Clip","40","AK47弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[2]	=	CreateConVar("ControlAmmo_rifle_desert_enable","1","SCAR步槍彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[2] =	CreateConVar("ControlAmmo_rifle_desert_Ammo","420","SCAR步槍储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[2] =			CreateConVar("ControlAmmo_rifle_desert_Clip","60","SCAR步槍弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[3]	=	CreateConVar("ControlAmmo_rifle_sg552_enable","1","sg552彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[3] =	CreateConVar("ControlAmmo_rifle_sg552_Ammo","410","SG552储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[3] =			CreateConVar("ControlAmmo_rifle_sg552_Clip","50","SG552弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[4]	=	CreateConVar("ControlAmmo_smg_enable","1","衝鋒槍彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[4] =	CreateConVar("ControlAmmo_smg_Ammo","700","冲锋枪储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[4] =			CreateConVar("ControlAmmo_smg_Clip","50","冲锋枪弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[5]	=	CreateConVar("ControlAmmo_smg_silenced_enable","1","消声冲锋枪彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[5] =	CreateConVar("ControlAmmo_smg_silenced_Ammo","700","消声冲锋枪储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[5] =			CreateConVar("ControlAmmo_smg_silenced_Clip","50","消声冲锋枪弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[6]	=	CreateConVar("ControlAmmo_smg_mp5_enable","1","MP5彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[6] =	CreateConVar("ControlAmmo_smg_mp5_Ammo","700","MP5储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[6] =			CreateConVar("ControlAmmo_smg_mp5_Clip","50","MP5弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[7]	=	CreateConVar("ControlAmmo_pumpshotgun_enable","1","泵动霰弹彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[7] =	CreateConVar("ControlAmmo_pumpshotgun_Ammo","64","泵动霰弹储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[7] =			CreateConVar("ControlAmmo_pumpshotgun_Clip","8","泵动霰弹弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[8]	=	CreateConVar("ControlAmmo_shotgun_chrome_enable","1","合金霰弹彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[8] =	CreateConVar("ControlAmmo_shotgun_chrome_Ammo","64","合金霰弹储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[8] =			CreateConVar("ControlAmmo_shotgun_chrome_Clip","8","合金霰弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[9]	=	CreateConVar("ControlAmmo_autoshotgun_enable","1","M4连霰彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[9] =	CreateConVar("ControlAmmo_autoshotgun_Ammo","100","M4连霰储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[9] =			CreateConVar("ControlAmmo_autoshotgun_Clip","10","M4连霰弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[10]	=	CreateConVar("ControlAmmo_shotgun_spas_enable","1","SPA12连霰彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[10] =	CreateConVar("ControlAmmo_shotgun_spas_Ammo","100","SPA12连霰储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[10] =			CreateConVar("ControlAmmo_shotgun_spas_Clip","10","SPA12连霰弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[11]	 =	CreateConVar("ControlAmmo_hunting_rifle_enable","1","猎狙彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[11] =	CreateConVar("ControlAmmo_hunting_rifle_Ammo","165","猎狙储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[11] =			CreateConVar("ControlAmmo_hunting_rifle_Clip","15","猎狙弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[12]	 =	CreateConVar("ControlAmmo_sniper_military_enable","1","军用狙彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[12] =	CreateConVar("ControlAmmo_sniper_military_Ammo","210","军用狙储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[12] =			CreateConVar("ControlAmmo_sniper_military_Clip","30","军用狙弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[13]	 =	CreateConVar("ControlAmmo_sniper_awp_enable","1","AWP彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[13] =	CreateConVar("ControlAmmo_sniper_awp_Ammo","200","AWP储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[13] =			CreateConVar("ControlAmmo_sniper_awp_Clip","20","AWP弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[14]	 =	CreateConVar("ControlAmmo_sniper_scout_enable","1","輕狙彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[14] =	CreateConVar("ControlAmmo_sniper_scout_Ammo","195","輕狙储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[14] =			CreateConVar("ControlAmmo_sniper_scout_Clip","15","輕狙弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[15]	 =	CreateConVar("ControlAmmo_grenade_launcher_enable","1","榴弹彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[15] =	CreateConVar("ControlAmmo_grenade_launcher_Ammo","31","榴弹储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[15] =			CreateConVar("ControlAmmo_grenade_launcher_Clip","1","榴弹弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	GL_AmmoPickup_Enabled =		CreateConVar("ControlAmmo_grenade_launcher_ammopickup_Enabled","1","開啟榴弹補彈 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	
	ControlAmmo_Enable[16]	 =	CreateConVar("ControlAmmo_m60_enable","1","M60彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ExtraPrimaryAmmo[16] =	CreateConVar("ControlAmmo_m60_Ammo","300","M60储备弹药数量",CVAR_FLAGS,true,1.0,true,1023.0);
	Gun_ClipAmmo[16] =			CreateConVar("ControlAmmo_rifle_m60_Clip","150","M60弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	M60_AmmoPickup_Enabled =	CreateConVar("ControlAmmo_m60_ammopickup_Enabled","1","開啟M60補彈 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	
	ControlAmmo_Enable[17]	 =	CreateConVar("ControlAmmo_pistol_enable","1","格洛克彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ClipAmmo[17] =			CreateConVar("ControlAmmo_pistol_Clip","15","格洛克弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	ControlAmmo_Enable[18]	 =	CreateConVar("ControlAmmo_pistol_magnum_enable","1","麥格南彈藥控制開關 1/0",CVAR_FLAGS,true,0.0,true,1.0);
	Gun_ClipAmmo[18] =			CreateConVar("ControlAmmo_pistol_magnum_Clip","8","麥格南弹夹弹药数量",CVAR_FLAGS,true,1.0,true,254.0);
	
	Upgrade_Ammo_Explosive	=	CreateConVar("ammo_explosive_Clip","1","高爆彈弹药数量_倍數",CVAR_FLAGS,true,1.0,true,10.0);
	
	Upgrade_Ammo_Incendiary	=	CreateConVar("ammo_incendiary_Clip","1","燃燒彈弹药数量_倍數",CVAR_FLAGS,true,1.0,true,10.0);
	
	AutoExecConfig(true,"l4d2_ControlAmmo");
	
	InitFindEntity();
	CreateTimer(1.0, Timer_SetupSkill);
}

public Action Timer_SetupSkill(Handle timer, any unused)
{
	SC_CreateSkill("ca_maxammo", "更多弹药", 0, "备用弹药更多");
	SC_CreateSkill("ca_maxclip", "更大弹夹", 0, "弹夹大小更大");
	SC_CreateSkill("upf_moreupgrade", "更多升级弹药", 0, "弹药升级包加量");
	return Plugin_Continue;
}

public Action SC_OnSkillGetInfo(int client, const char[] classname,
	char[] display, int displayMaxLength, char[] description, int descriptionMaxLength)
{
	if(StrEqual(classname, "ca_maxammo", false))
		FormatEx(description, descriptionMaxLength, "备用弹药 ＋%.2f％", (SKILLAMMO_SIZE - 1.0) * 100);
	else if(StrEqual(classname, "ca_maxclip", false))
		FormatEx(description, descriptionMaxLength, "武器弹夹 ＋%.2f％", (SKILLCLIP_SIZE - 1.0) * 100);
	else if(StrEqual(classname, "upf_moreupgrade", false))
		FormatEx(description, descriptionMaxLength, "弹药升级 ＋%.2f％\n弹药升级同类型可以叠加\n换弹夹保留子弹", (SKILLUPGRADE_SIZE - 1.0) * 100);
	else
		return Plugin_Continue;
	
	return Plugin_Changed;
}

void InitFindEntity()
{
	new Handle:gConf = LoadGameConfigFile("upgradepackfix");
	if(gConf == null)
		return;
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "CTerrorPlayer::FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool,SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity,SDKPass_Pointer);
	g_hFindUseEntity = EndPrepSDKCall();
	
	CloseHandle(gConf);
}

int FindUseEntity(int client)
{
	if(g_hFindUseEntity == null)
		return GetClientAimTarget(client, false);
	
	static ConVar cvUseRadius;
	if(cvUseRadius == null)
		cvUseRadius = FindConVar("player_use_radius");
	
	return SDKCall(g_hFindUseEntity,client,cvUseRadius.FloatValue,0.0,0.0,0,false);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(GetConVarBool(Plugin_Enabled) && IsValidPlayer(client,TEAM_SURVIVORS) && !IsFakeClient(client))
	{
	/**************************************************************************************************************************************************/
		new weapon_index_1 = GetPlayerWeaponSlot(client,1);
		if(IsValidEdict(weapon_index_1))//if pickup 2 pistol gun. 
		{
			if(!IsPickupPistol_2[client])
			{
				new String:weapon_name[64];
				GetEdictClassname(weapon_index_1,weapon_name,sizeof(weapon_name));
				if(IsPistolGun(weapon_name,WeaponNames) && GetEntProp(weapon_index_1, Prop_Send, "m_isDualWielding")==1)
				{
					new customclip 		= GetCustomClipAmmo(weapon_name,WeaponNames,sizeof(WeaponNames),client);
					if(customclip>0)
					{
						SetEntProp(weapon_index_1, Prop_Send, "m_iClip1", customclip*2);

						if(PickupPistol_TimerIndex[client]==INVALID_HANDLE)
						{
							new Handle:data = CreateDataPack();
							WritePackCell(data,client);
							WritePackCell(data,customclip*2);
							WritePackCell(data,weapon_index_1);
							PickupPistol_TimerIndex[client] = CreateTimer(0.3,ResetPistolData,data,TIMER_FLAG_NO_MAPCHANGE);
						}
					}
				}
				else
				{
					IsPickupPistol_2[client] = false;
				}
			}
		}
		else
		{
			IsPickupPistol_2[client] = false;
		}
	/**************************************************************************************************************************************************/
	
		if(!IsReload[client])
		{
			new weapon_index 	= GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(IsValidEdict(weapon_index))
			{
				new String:weapon_name[64];
				GetEdictClassname(weapon_index,weapon_name,sizeof(weapon_name));
				new clip 				= GetEntProp(weapon_index, Prop_Send, "m_iClip1");
				if(GetEntProp(weapon_index, Prop_Send, "m_bInReload")==1 || buttons&IN_RELOAD)
				{
					if(IsValidWeapon(weapon_name,WeaponNames,sizeof(WeaponNames)) && IsControlAmmoEnabled(weapon_name,WeaponNames,ControlAmmo_Enable,19))
					{
						new customclip 			= GetCustomClipAmmo(weapon_name,WeaponNames,sizeof(WeaponNames),client);
						new offset 				= FindWeaponOffSet(weapon_name,WeaponNames,sizeof(WeaponNames));
						// new defclip			= GetDefaultClipAmmo(weapon_name,WeaponNames,sizeof(WeaponNames));
						new ExtraPrimaryAmmo	= GetPlayerAmmo(client, offset);
						if(!IsShotGun(weapon_name,WeaponNames))
						{
							if(offset<=68 && offset>-1)
							{
								if(clip<customclip && ExtraPrimaryAmmo > 0)
								{
									// new ExtraPrimaryAmmo 		= GetEntData(client,iAmmoOffset+offset);
									// new ExtraPrimaryAmmo 		= GetPlayerAmmo(client,offset);
									ShotGunData[client][0]		= clip;
									ShotGunData[client][1]		= ExtraPrimaryAmmo;
									SetEntProp(weapon_index, Prop_Send, "m_iClip1",0);
									// SetEntData(client,iAmmoOffset+offset,ExtraPrimaryAmmo+clip);
									SetPlayerAmmo(client,offset,ExtraPrimaryAmmo+clip);
									
									IsReload[client] = true;
								}
								else if(buttons&IN_RELOAD)
									buttons &= ~IN_RELOAD;
							}
							else if(IsPistolGun(weapon_name,WeaponNames) && clip<customclip)
							{
								SetEntProp(weapon_index, Prop_Send, "m_iClip1",0);
								ShotGunData[client][0] = clip;
								IsReload[client] = true;
							}
							else if(buttons&IN_RELOAD)
								buttons &= ~IN_RELOAD;
						}
						else
						{
							if(clip<customclip&&ExtraPrimaryAmmo>0&&GetEntProp(weapon_index, Prop_Send, "m_bInReload")==0)
							{
								ShotGunData[client][0] = GetEntProp(weapon_index, Prop_Send, "m_iClip1");
								ShotGunData[client][1] = customclip-ShotGunData[client][0];
								// new reload_clip_num = ShotGunData[client][0]<defclip ? ShotGunData[client][0] : defclip-1;
								SetEntProp(weapon_index, Prop_Send, "m_iClip1", 0);		// 强制进入换弹夹状态
								IsReload[client] = true;
							}
							else if(GetEntProp(weapon_index, Prop_Send, "m_bInReload")==1&&GetEntProp(weapon_index, Prop_Send, "m_reloadFromEmpty")==1)
							{
								ShotGunData[client][0] = 0;
								ShotGunData[client][1] = customclip;
								IsReload[client] = true;
							}
							else if(buttons&IN_RELOAD)
								buttons &= ~IN_RELOAD;
						}
						
						if(IsReload[client])
						{
							SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
							SDKHook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
						}
					}
				}
				/*
				else if((buttons & IN_ATTACK) && IsShotGun(weapon_name,WeaponNames) && clip > 0 && GetEngineTime() - g_fLastFired[client] > 3.0)
				{
					// 修复霰弹枪无法开枪 bug
					SetEntPropFloat(weapon_index, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
				}
				*/
			}
			else
			{
				IsReload[client] = false;
			}
			
			if(IsReload[client])
			{
				SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
				SDKHook(client, SDKHook_PreThink, GunPreThinkPostHook);
			}
		}
		
	/**************************************************************************************************************************************************/
		if(buttons&IN_USE && IsValidPlayer(client,TEAM_SURVIVORS))
		{
			new weapon_index0 = GetPlayerWeaponSlot(client,0);
			new AmmoPile = FindUseEntity(client);
			
			if(IsValidEdict(weapon_index0) && IsValidEdict(AmmoPile) && AmmoPile>32)
			{
				new String:pile_name[64];
				GetEdictClassname(AmmoPile, pile_name, sizeof(pile_name)); 		
				new String:WeaponName[32];
				GetEdictClassname(weapon_index0,WeaponName,sizeof(WeaponName));		
				new offset = FindWeaponOffSet(WeaponName,WeaponNames,sizeof(WeaponNames));
				if(offset>-1 && StrEqual(pile_name,"weapon_ammo_spawn") && ((offset < 68 && offset != 24) ||
					(offset==24 && GetConVarBool(M60_AmmoPickup_Enabled)) ||
					(offset==68 && GetConVarBool(GL_AmmoPickup_Enabled))))
				{
					new CustomExtraPrimaryAmmo 	= GetCustomExtraPrimaryAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
					// new ExtraPrimaryAmmo = GetEntData(client, iAmmoOffset+offset);
					new ExtraPrimaryAmmo = GetPlayerAmmo(client,offset);
					new clip = GetEntProp(weapon_index0, Prop_Send, "m_iClip1");
					if(clip+ExtraPrimaryAmmo<CustomExtraPrimaryAmmo)
					{
						new d_value = CustomExtraPrimaryAmmo-(clip+ExtraPrimaryAmmo);
						// SetEntData(client,iAmmoOffset+offset,ExtraPrimaryAmmo+d_value);
						SetPlayerAmmo(client,offset,ExtraPrimaryAmmo+d_value);
					}
				}
				/*
				else if(((offset==24 && GetConVarBool(M60_AmmoPickup_Enabled)) ||
					(offset==68 && GetConVarBool(GL_AmmoPickup_Enabled))) &&
					StrEqual(pile_name,"weapon_ammo_spawn"))
				{
					new clip = GetEntProp(weapon_index0, Prop_Send, "m_iClip1");
					new customclip = GetCustomClipAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
					if(clip<customclip)
					{
						SetEntProp(weapon_index0, Prop_Send, "m_iClip1", customclip);
					}
				}
				*/
				else if(StrContains(pile_name, "upgrade_ammo_", false) == 0)
				{
					new upgrade = GetEntProp(weapon_index0, Prop_Send, "m_upgradeBitVec");
					if((upgrade & 3) && (!(upgrade & 1) || !(upgrade & 2)) &&
						SC_IsClientHaveSkill(client, "upf_moreupgrade"))
					{
						g_iLastUpgradeType[client] = ((upgrade & 1) ? 1 : 2);
						g_iLastUpgradeCount[client] = GetEntProp(weapon_index0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 1);
					}
					else
					{
						g_iLastUpgradeType[client] = 0;
						g_iLastUpgradeCount[client] = 0;
					}
				}
				else if(StrContains(pile_name, "weapon_", false) == 0 &&
					StrContains(pile_name, "_spawn", false) > 0 &&
					StrContains(pile_name, WeaponName, false) == 0)
				{
					new customClip = GetCustomClipAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
					new customAmmo = GetCustomExtraPrimaryAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
					if(GetEntProp(weapon_index0, Prop_Send, "m_iClip1") < customClip ||
						GetPlayerAmmo(client, offset) < customAmmo)
					{
						// 丢掉武器来捡新的武器
						// SDKHooks_DropWeapon(client, weapon_index0);
						// AcceptEntityInput(AmmoPile, "Use", client, AmmoPile);
						SetEntProp(weapon_index0, Prop_Send, "m_iClip1", customClip);
						SetPlayerAmmo(client, offset, customAmmo);
					}
				}
			}
		}
	}
}

public Action:Event_ItemPickup(Handle:event, const String:strName[], bool:DontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:weapon_name[64] = "weapon_" , String:tempname[64];
	GetEventString(event,"item",tempname,sizeof(tempname));
	StrCat(weapon_name,sizeof(weapon_name),tempname);
	if(GetConVarBool(Plugin_Enabled) && IsControlAmmoEnabled(weapon_name,WeaponNames,ControlAmmo_Enable, 19))
	{
		new Handle:data = CreateDataPack();
		WritePackCell(data,client);
		WritePackString(data,weapon_name);
		CreateTimer(0.0,SetWeaponData,data);
		
		IsReload[client] = false;
		ShotGunData[client][0] = 0;
		ShotGunData[client][1] = 0;
		g_iLastUpgradeType[client] = 0;
		g_iLastUpgradeCount[client] = 0;
		SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
	}
}

public Action:Event_AmmoPickup(Handle:event, const String:strName[], bool:DontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new weapon_index = GetPlayerWeaponSlot(client,0);
	if(IsValidPlayer(client,TEAM_SURVIVORS)&&!IsFakeClient(client)&&IsValidEdict(weapon_index))
	{
		decl String:WeaponName[32];
		GetEdictClassname(weapon_index,WeaponName,sizeof(WeaponName));
		new offset = FindWeaponOffSet(WeaponName,WeaponNames,sizeof(WeaponNames));
		if(offset<=68&&offset>-1)
		{
			new clip = GetEntProp(weapon_index, Prop_Send, "m_iClip1");
			new CustomExtraPrimaryAmmo 	= GetCustomExtraPrimaryAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
			// SetEntData(client,iAmmoOffset+offset,CustomExtraPrimaryAmmo-clip);
			SetPlayerAmmo(client,offset,CustomExtraPrimaryAmmo-clip);
		}
	}
}

public Action:Event_SpecialAmmo(Handle:event, const String:strName[], bool:DontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new upgradeid = GetEventInt(event, "upgradeid");
	decl String:class[256];
	GetEdictClassname(upgradeid, class, sizeof(class));
	new weapon_index = GetPlayerWeaponSlot(client,0);
	if(IsValidPlayer(client,TEAM_SURVIVORS)&&IsValidEdict(weapon_index))
	{
		decl String:WeaponName[64];
		GetEdictClassname(weapon_index,WeaponName,sizeof(WeaponName));
		new offset = FindWeaponOffSet(WeaponName,WeaponNames,sizeof(WeaponNames));
		if(offset<=68 && offset>-1)
		{
			new clip = GetCustomClipAmmo(WeaponName,WeaponNames,sizeof(WeaponNames),client);
			new new_clip = 0, upgrade = 0;
			if (StrEqual(class, "upgrade_ammo_incendiary"))
			{
				upgrade = 1;
				new_clip = clip*GetConVarInt(Upgrade_Ammo_Incendiary);
			}
			else if(StrEqual(class, "upgrade_ammo_explosive"))
			{
				upgrade = 2;
				new_clip = clip*GetConVarInt(Upgrade_Ammo_Explosive);
			}
			if(new_clip > 0)
			{
				if(SC_IsClientHaveSkill(client, "upf_moreupgrade"))
				{
					new_clip = RoundToZero(new_clip * SKILLUPGRADE_SIZE);
					if(upgrade > 0 && g_iLastUpgradeType[client] == upgrade && g_iLastUpgradeCount[client] > 0)
						new_clip += g_iLastUpgradeCount[client];
				}
				
				if(new_clip > 255)
					new_clip = 255;
				
				SetEntProp(weapon_index, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", new_clip);
			}
		}
		
		g_iLastUpgradeType[client] = 0;
		g_iLastUpgradeCount[client] = 0;
	}
}

public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Target = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidPlayer(Target,TEAM_SURVIVORS))
	{
		IsPickupPistol_2[Target] = false;
		IsReload[Target] = false;
	}
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidPlayer(client,TEAM_SURVIVORS))
		return;
	
	g_fLastFired[client] = GetEngineTime();
	if(!GetConVarBool(M60_AmmoPickup_Enabled))
		return;
	
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon))
		return;
	
	new String:classname[64];
	GetEntityClassname(weapon, classname, 64);
	if(!StrEqual(classname, "weapon_rifle_m60", false))
		return;
	
	new clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if(clip > 1 || GetEntProp(weapon, Prop_Data, "m_bInReload", 1) == 1)
		return;
	
	new ammo = GetPlayerAmmo(client, 24);
	new upgrade = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
	
	AcceptEntityInput(weapon, "Kill");
	weapon = GivePlayerItem(client, "weapon_rifle_m60");
	SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
	SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrade);
	SetPlayerAmmo(client, 24, ammo);
}

public Event_WeaponReload(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidPlayer(client,TEAM_SURVIVORS))
		return;
	
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(weapon))
		return;
	
	new String:classname[64];
	GetEntityClassname(weapon, classname, 64);
	// new bool:fromEmpty = GetEventBool(event, "manual");
	if(IsControlAmmoEnabled(classname,WeaponNames,ControlAmmo_Enable,19))
	{
		IsReload[client] = true;
		SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
		SDKHook(client, SDKHook_PreThink, GunPreThinkPostHook);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
		SDKHook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
	}
}

public Action:ResetPistolData(Handle:timer,Handle:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	new clip = ReadPackCell(data);
	new entity = ReadPackCell(data);
	if(IsValidPlayer(client,TEAM_SURVIVORS) && IsValidEdict(entity) && GetEntProp(entity, Prop_Send, "m_isDualWielding")==1)
	{
		if(GetEntProp(entity, Prop_Send, "m_iClip1")==clip)
		{
			IsPickupPistol_2[client] = true;
			KillTimer(timer);
			PickupPistol_TimerIndex[client] = INVALID_HANDLE;
		}
	}
	else
	{
		KillTimer(timer);
		PickupPistol_TimerIndex[client] = INVALID_HANDLE;
		IsPickupPistol_2[client] = false;
	}
}

public Action:SetWeaponData(Handle:timer,Handle:data)
{
	ResetPack(data,false);
	new client = ReadPackCell(data);
	new String:classname[64];
	ReadPackString(data,classname,sizeof(classname));
	new entity = -1;
	
	if(IsValidWeapon(classname,WeaponNames,sizeof(WeaponNames)) && IsValidPlayer(client,TEAM_SURVIVORS) && !IsFakeClient(client))
	{
		new OffSet			= FindWeaponOffSet(classname,WeaponNames,sizeof(WeaponNames));
		new CustomEPAmmo 	= GetCustomExtraPrimaryAmmo(classname,WeaponNames,sizeof(WeaponNames),client);
		new CustomClipAmmo 	= GetCustomClipAmmo(classname,WeaponNames,sizeof(WeaponNames),client);
		if(CustomClipAmmo>=0)
		{
			if(OffSet<84)
			{
				CustomEPAmmo = CustomEPAmmo>=0 ? CustomEPAmmo : 0;
				entity = GetPlayerWeaponSlot(client,0);
				if(IsValidEdict(entity))
				{
					if(!CustomEPAmmo)
					{
						if(OffSet == 76)
						{
							SetEntProp(entity, Prop_Send, "m_iClip1", CustomClipAmmo);
						}
						else
						{
							SetEntProp(entity, Prop_Send, "m_iClip1", CustomClipAmmo);
							// SetEntData(client,iAmmoOffset+OffSet,0);
							SetPlayerAmmo(client,OffSet,0);
						}
					}
					else if(CustomEPAmmo-CustomClipAmmo<0)
					{
						SetEntProp(entity, Prop_Send, "m_iClip1", CustomEPAmmo);
						// SetEntData(client,iAmmoOffset+OffSet,0);
						SetPlayerAmmo(client,OffSet,0);
					}
					else
					{
						SetEntProp(entity, Prop_Send, "m_iClip1", CustomClipAmmo);
						// SetEntData(client,iAmmoOffset+OffSet,CustomEPAmmo-CustomClipAmmo);
						SetPlayerAmmo(client,OffSet,CustomEPAmmo-CustomClipAmmo);
					}
				}
			}
			else
			{
				entity = GetPlayerWeaponSlot(client,1);
				if(IsValidEdict(entity))
				{
					SetEntProp(entity, Prop_Send, "m_iClip1", CustomClipAmmo);
				}
			}
		}
	}
}

stock bool:HasReloadFailure(client)
{
	if(L4D2_GetPlayerUseAction(client) == L4D2UseAction_Button ||			// 按按钮
		GetEntityMoveType(client) == MOVETYPE_LADDER ||						// 爬梯子
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) > 0 ||		// 挂边
		GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0 ||		// 倒地
		GetEntPropEnt(client, Prop_Send, "m_reviveTarget") > 0 ||			// 救倒地队友
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||			// 被舌头拉
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||			// 被猴骑
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ||			// 被牛带走
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||			// 被牛锤
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)			// 被猎人扑
		return true;
	
	return false;
}

public Action:OnPlayerSwitchWeapon(client, weapon)
{
	if(!IsReload[client])
	{
		SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
		return Plugin_Continue;
	}
	
	new weapon_index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEdict(weapon_index))
	{
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
		return Plugin_Continue;
	}
	
	new String:weapon_name[64];
	GetEdictClassname(weapon_index,weapon_name,sizeof(weapon_name));
	if(!IsValidWeapon(weapon_name,WeaponNames,sizeof(WeaponNames)))
	{
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
		return Plugin_Continue;
	}
	
	// 恢复换子弹瞬间切枪导致子弹数不正确
	if(GetEntProp(weapon_index, Prop_Send, "m_iClip1") == 0 && ShotGunData[client][0] > 0)
	{
		// 手枪和霰弹枪在填装时都不会丢弃弹夹的
		if(IsShotGun(weapon_name,WeaponNames) || IsPistolGun(weapon_name,WeaponNames) || SC_IsClientHaveSkill(client, "upf_moreupgrade"))
			SetEntProp(weapon_index, Prop_Send, "m_iClip1", ShotGunData[client][0]);
	}
	
	IsReload[client] = false;
	ShotGunData[client][0] = 0;
	ShotGunData[client][1] = 0;
	SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
	SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
	
	return Plugin_Continue;
}

public Action:GunPreThinkPostHook(client)
{
	if(IsValidPlayer(client,TEAM_SURVIVORS)&&!IsFakeClient(client)&&IsReload[client])
	{
		new weapon_index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(IsValidEdict(weapon_index))
		{
			new String:weapon_name[64];
			GetEdictClassname(weapon_index,weapon_name,sizeof(weapon_name));
			if(IsValidWeapon(weapon_name,WeaponNames,sizeof(WeaponNames)))
			{
				new customclip 			= GetCustomClipAmmo(weapon_name,WeaponNames,sizeof(WeaponNames),client);
				new defclip				= GetDefaultClipAmmo(weapon_name,WeaponNames,sizeof(WeaponNames));
				new clip				= GetEntProp(weapon_index, Prop_Send, "m_iClip1");
				new bool:inReloading	= (GetEntProp(weapon_index, Prop_Send, "m_bInReload", 1) == 1);
				if(!IsShotGun(weapon_name,WeaponNames))
				{
					new offset 				= FindWeaponOffSet(weapon_name,WeaponNames,sizeof(WeaponNames));
					// new ExtraPrimaryAmmo = GetEntData(client,iAmmoOffset+offset);
					new ExtraPrimaryAmmo 	= GetPlayerAmmo(client,offset);
					// new bool:haveFakeClip= (ShotGunData[client][0] == clip && clip != defclip);
					// new bool:hasFakeClip	= (ShotGunData[client][0] == clip);
					
					if(!IsPistolGun(weapon_name,WeaponNames) && ExtraPrimaryAmmo > 0 && !inReloading && clip == defclip)
					{
						// 修复弹药丢失 bug
						if(ShotGunData[client][0] > 0 && SC_IsClientHaveSkill(client, "upf_moreupgrade"))
							ExtraPrimaryAmmo += ShotGunData[client][0] - clip;
						
						if(customclip>clip)
						{
							if(ExtraPrimaryAmmo>=customclip-clip)
							{
								SetEntProp(weapon_index, Prop_Send, "m_iClip1",customclip);
								// SetEntData(client,iAmmoOffset+offset,ExtraPrimaryAmmo-(customclip-clip));
								SetPlayerAmmo(client,offset,ExtraPrimaryAmmo-(customclip-clip));
							}
							else
							{
								SetEntProp(weapon_index, Prop_Send, "m_iClip1",clip+ExtraPrimaryAmmo);
								// SetEntData(client,iAmmoOffset+offset,0);
								SetPlayerAmmo(client,offset,0);
							}
						}
						else if(clip != defclip)
						{
							SetEntProp(weapon_index, Prop_Send, "m_iClip1",customclip);
							// SetEntData(client,iAmmoOffset+offset,ExtraPrimaryAmmo+(clip-customclip));
							SetPlayerAmmo(client,offset,ExtraPrimaryAmmo+(clip-customclip));
						}
						
						IsReload[client] = false;
					}
					else if(IsPistolGun(weapon_name,WeaponNames) && !inReloading)
					{
						if(GetEntProp(weapon_index, Prop_Send, "m_isDualWielding")==0 && clip == defclip)
						{
							SetEntProp(weapon_index, Prop_Send, "m_iClip1",customclip);
							IsReload[client] = false;
						}
						else if(clip == defclip * 2)
						{
							SetEntProp(weapon_index, Prop_Send, "m_iClip1",customclip*2);
							IsReload[client] = false;
						}
					}
					
					// 换子弹保留弹夹内弹药
					if(ShotGunData[client][0] > 0 && ExtraPrimaryAmmo > ShotGunData[client][1] &&
						clip == 0 && inReloading && SC_IsClientHaveSkill(client, "upf_moreupgrade"))
					{
						SetEntProp(weapon_index, Prop_Send, "m_iClip1",ShotGunData[client][0]);
						
						if(!IsPistolGun(weapon_name,WeaponNames))
							SetPlayerAmmo(client, offset, ShotGunData[client][1]);
					}
				}
				else
				{
					new offset 	= FindWeaponOffSet(weapon_name,WeaponNames,sizeof(WeaponNames));
					// new ExtraPrimaryAmmo = GetEntData(client,iAmmoOffset+offset);
					new ExtraPrimaryAmmo = GetPlayerAmmo(client,offset);
					if(inReloading&&GetEntProp(weapon_index, Prop_Send, "m_reloadFromEmpty")==0)
					{
						SetEntProp(weapon_index, Prop_Send, "m_iClip1",ShotGunData[client][0]);
						ShotGunData[client][1] = ExtraPrimaryAmmo>ShotGunData[client][1] ? ShotGunData[client][1] : ExtraPrimaryAmmo;
						SetEntProp(weapon_index, Prop_Send, "m_reloadNumShells",ShotGunData[client][1]);
						IsReload[client] = false;
					}
					else if(inReloading&&GetEntProp(weapon_index, Prop_Send, "m_reloadFromEmpty")==1)
					{
						SetEntProp(weapon_index, Prop_Send, "m_reloadFromEmpty",0);
						ShotGunData[client][1] = ExtraPrimaryAmmo>ShotGunData[client][1] ? ShotGunData[client][1] : ExtraPrimaryAmmo;
						SetEntProp(weapon_index, Prop_Send, "m_reloadNumShells",ShotGunData[client][1]);
						IsReload[client] = false;
					}
					
					/*
					if(!IsReload[client])
						SetEntPropFloat(weapon_index, Prop_Send, "m_flNextPrimaryAttack", GetGameTime());
					*/
				}
			}
			else
			{
				IsReload[client] = false;
			}
		}
		else
		{
			IsReload[client] = false;
		}
	}
	
	if(!IsReload[client])
	{
		ShotGunData[client][0] = 0;
		ShotGunData[client][1] = 0;
		SDKUnhook(client, SDKHook_PreThink, GunPreThinkPostHook);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon);
	}
	
	return Plugin_Continue;
}

GetDefaultClipAmmo(String:weapon_name[],const String:sequence[][],maxlen)
{
	for(new i=0;i<maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			switch(i)
			{
				case 0:		return 50;		
				case 1:		return 40;		
				case 2:		return 60;
				case 3:		return 50;		
				case 4:		return 50;		
				case 5:		return 50;
				case 6:		return 50;		
				case 7:		return 8;		
				case 8:		return 8;
				case 9:		return 10;		
				case 10:	return 10;		
				case 11:	return 15;
				case 12:	return 30;		
				case 13:	return 20;		
				case 14:	return 15;
				case 15:	return 1;		
				case 16:	return 150;		
				case 17:	return 15;
				case 18:	return 8;
			}
		}
	}
	return -1;
}

FindWeaponOffSet(String:weapon_name[],const String:sequence[][],maxlen)
{
	for(new i=0;i<maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			switch(i)
			{
				case 0, 1, 2, 3:
					return 12;	// AMMOTYPE_ASSAULTRIFLE * 4
				case 4, 5, 6:
					return 20;	// AMMOTYPE_SMG * 4
				case 7, 8:
					return 28;	// AMMOTYPE_SHOTGUN * 4
				case 9, 10:
					return 32;	// AMMOTYPE_AUTOSHOTGUN * 4
				case 11:
					return 36;	// AMMOTYPE_HUNTINGRIFLE * 4
				case 12, 13, 14:
					return 40;	// AMMOTYPE_SNIPERRIFLE * 4
				case 15:
					return 68;	// AMMOTYPE_GRENADELAUNCHER * 4
				case 16:
					return 24;	// AMMOTYPE_M60 * 4;
				
				/*
				case 17:
					return 4;	// AMMOTYPE_PISTOL * 4
				case 18:
					return 8;	// AMMOTYPE_MAGNUM * 4
				*/
				
				// 手枪不需要弹药
				case 17, 18:
					return 124;
			}
			
			/*
			if(i>-1 && i<4)			{ return 12; }	// AMMOTYPE_ASSAULTRIFLE
			else if(i>3 && i<7)		{ return 20; }	// AMMOTYPE_SMG
			else if(i>6 && i<9)		{ return 28; }	// AMMOTYPE_SHOTGUN
			else if(i>8 && i<11)	{ return 32; }	// AMMOTYPE_AUTOSHOTGUN
			else if(i==11)			{ return 36; }	// AMMOTYPE_HUNTINGRIFLE
			else if(i>11 && i<15)	{ return 40; }	// AMMOTYPE_SNIPERRIFLE
			else if(i==15)			{ return 68; }	// AMMOTYPE_GRENADELAUNCHER
			
			
			else if(i==16)			{ return 72; }//this is custom offset
			else if(i>16)			{ return 84; }// this is custom offset
			*/
		}
	}
	return -1;
}

GetCustomExtraPrimaryAmmo(String:weapon_name[],const String:sequence[][],maxlen,client=-1)
{
	// maxlen = maxlen<=16 ? maxlen : 16;
	if(maxlen > sizeof(Gun_ExtraPrimaryAmmo))
		maxlen = sizeof(Gun_ExtraPrimaryAmmo);
	
	for(new i=0;i<maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			int ammo = GetConVarInt(Gun_ExtraPrimaryAmmo[i]);
			if(SC_IsClientHaveSkill(client, "ca_maxammo"))
				ammo = RoundToZero(ammo * SKILLAMMO_SIZE);
			
			// 备弹超过 1023 会变成 0
			if(ammo > 1023)
				ammo = 1023;
			
			return ammo;
		}
	}
	return -1;
}

GetCustomClipAmmo(String:weapon_name[],const String:sequence[][],maxlen,client=-1)
{
	for(new i=0;i<maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			int ammo = GetConVarInt(Gun_ClipAmmo[i]);
			if(SC_IsClientHaveSkill(client, "ca_maxclip"))
				ammo = RoundToZero(ammo * SKILLCLIP_SIZE);
			
			// 弹夹超过 254 会变成 0
			if(ammo > 254)
				ammo = 254;
			
			return ammo;
		}
	}
	return -1;
}

SetPlayerAmmo(client,offset,ammo)
{
	if(ammo > 1023)
		ammo = 1023;
	
	// SetEntData(client,iAmmoOffset+offset,ammo);
	new weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon <= MaxClients || !IsValidEntity(weapon))
	{
		SetEntData(client,iAmmoOffset+offset,ammo);
		return;
	}
	
	new ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if(ammoType < 1 || ammoType > 19)
	{
		SetEntData(client,iAmmoOffset+offset,ammo);
		return;
	}
	
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammoType);
}

GetPlayerAmmo(client,offset)
{
	// return GetEntData(client,iAmmoOffset+offset);
	new weapon = GetPlayerWeaponSlot(client, 0);
	if(weapon <= MaxClients || !IsValidEntity(weapon))
		return GetEntData(client,iAmmoOffset+offset);
	
	new ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if(ammoType < 1 || ammoType > 19)
		return GetEntData(client,iAmmoOffset+offset);
	
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
}

bool:IsValidClient(client)
{
	if(client>0&&client<=MaxClients)
	{
		if(IsValidEntity(client))
		{
			if(IsClientConnected(client))
			{
				if(IsClientInGame(client))
				{
					return true;
				}
			}
		}
	}
	return false;
}

bool:IsValidPlayer(client,team)
{
	if(IsValidClient(client))
	{
		if(GetClientTeam(client)==team)
		{
			return true;
		}
	}
	return false;
}

bool:IsValidWeapon(String:weapon_name[],const String:sequence[][],maxlen)
{
	for(new i=0;i<maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			return true;
		}
	}
	return false;
}

GameCheck()
{
	new String:GameName[16];
	GetGameFolderName(GameName, sizeof(GameName));
	return StrEqual(GameName, "left4dead2") ? true : false;
}

bool:IsShotGun(String:weapon_name[],const String:sequence[][])
{
	for(new i=7;i<11;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			return true;
		}
	}
	return false;
}

bool:IsPistolGun(String:weapon_name[],const String:sequence[][])
{
	for(new i=17;i<=18;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			return true;
		}
	}
	return false;
}

bool:IsControlAmmoEnabled(String:weapon_name[], const String:sequence[][], Handle:Enabled[], h_Maxlen)
{
	for(new i=0;i<h_Maxlen;i++)
	{
		if(StrEqual(weapon_name,sequence[i]))
		{
			return GetConVarBool(Enabled[i]);
		}
	}
	return false;
}