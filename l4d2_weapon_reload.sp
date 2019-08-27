#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4"
#define DEFAULT_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY
#undef REQUIRE_EXTENSIONS
#define WEAPON_LENGTH 19
#define DEBUG 0
new m_debug = 0;

static const	ASSAULT_RIFLE_OFFSET_IAMMO		= 12;
static const	SMG_OFFSET_IAMMO				= 20;
static const	PUMPSHOTGUN_OFFSET_IAMMO		= 28;
static const	AUTO_SHOTGUN_OFFSET_IAMMO		= 32;
static const	HUNTING_RIFLE_OFFSET_IAMMO		= 36;
static const	MILITARY_SNIPER_OFFSET_IAMMO	= 40;
static const	GRENADE_LAUNCHER_OFFSET_IAMMO	= 68;

new Handle:smgClip;
new Handle:smgSilencedClip;
new Handle:smgMp5Clip;
new Handle:pumpClip;
new Handle:chromeClip;
new Handle:huntClip;
new Handle:rifleClip;
new Handle:rifleAk47Clip;
new Handle:rifleDesertClip;
new Handle:rifleSg552Clip;
new Handle:militaryClip;
new Handle:awpClip;
new Handle:scoutClip;
new Handle:granedeClip;
new Handle:m60Clip;
new Handle:autoClip;
new Handle:spasClip;
//faster reload
new Handle:g_h_reload_rate;
new Float:g_fl_reload_rate;
new g_iNextPAttO		= -1;
new g_iActiveWO			= -1;
new g_iPlayRateO		= -1;
new g_iNextAttO			= -1;
new g_iTimeIdleO		= -1;
new g_iVMStartTimeO		= -1;
new g_iViewModelO		= -1;
//new CountTimer = 1;
new ValueLastClip[MAXPLAYERS+1];
new ValueLastAmmo[MAXPLAYERS+1];
new ValueNewClip[MAXPLAYERS+1];
new ClipOffset[MAXPLAYERS+1];
new Handle:TimerPlayerReload[MAXPLAYERS+1];
new weaponClipSize[WEAPON_LENGTH] = {};
/*
new nextPrimaryAttack = -1;
new nextAttack =  -1;
new timeIdle =  -1;
new reloadState =  -1;
*/

new const String:weaponsClass[WEAPON_LENGTH][] = {
	{"weapon_smg"}, {"weapon_smg_silenced"}, {"weapon_smg_mp5"}, {"weapon_pumpshotgun"}, {"weapon_shotgun_chrome"}, {"weapon_hunting_rifle"},
	{"weapon_rifle"}, {"weapon_rifle_ak47"}, {"weapon_rifle_desert"}, {"weapon_rifle_sg552"}, {"weapon_sniper_military"},
	{"weapon_sniper_scout"}, {"weapon_sniper_awp"}, {"weapon_grenade_launcher"}, {"weapon_rifle_m60"},
	{"weapon_autoshotgun"}, {"weapon_shotgun_spas"}, {"weapon_pistol"}, {"weapon_pistol_magnum"}
};

public Plugin:myinfo = 
{
	name = "L4D2 Weapon Reload System",
	author = "ghosthunterfool & Alaina",
	description = "Modern FPS Style Reload",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=238125"
}

public OnPluginStart()
{
	// Requires Left 4 Dead 2
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
		SetFailState("Error: This plugin only supports Left 4 Dead 2. Plugin unloading.");
	
	CreateConVar("l4d2_wepreload_version", PLUGIN_VERSION, "The version of the weapon reload plugin", DEFAULT_FLAGS|FCVAR_SPONLY|FCVAR_DONTRECORD);
	smgClip = CreateConVar("AMMO_TYPE_SMG", "50", "50", DEFAULT_FLAGS);
	smgSilencedClip = CreateConVar("AMMO_TYPE_SMG", "50", "50", DEFAULT_FLAGS);
	smgMp5Clip = CreateConVar("AMMO_TYPE_SMG_MP5", "50", "50", DEFAULT_FLAGS);
	pumpClip = CreateConVar("AMMO_TYPE_SHOTGUN", "8", "8", DEFAULT_FLAGS);
	chromeClip = CreateConVar("AMMO_TYPE_SHOTGUN", "8", "8", DEFAULT_FLAGS);
	huntClip = CreateConVar("AMMO_TYPE_HUNTINGRIFLE_HUNT", "15", "15", DEFAULT_FLAGS);
	rifleClip = CreateConVar("AMMO_TYPE_ASSAULTRIFLE", "50", "50", DEFAULT_FLAGS);
	rifleAk47Clip = CreateConVar("AMMO_TYPE_ASSAULTRIFLE_AK47", "40", "40", DEFAULT_FLAGS);
	rifleDesertClip = CreateConVar("AMMO_TYPE_ASSAULTRIFLE_DESERT", "60", "60", DEFAULT_FLAGS);
	rifleSg552Clip = CreateConVar("AMMO_TYPE_ASSAULTRIFLE_SG552", "50", "50", DEFAULT_FLAGS);
	militaryClip = CreateConVar("AMMO_TYPE_SNIPERRIFLE_MILITARY", "30", "30", DEFAULT_FLAGS);
	awpClip = CreateConVar("AMMO_TYPE_SNIPERRIFLE_AWP", "20", "20", DEFAULT_FLAGS);
	scoutClip = CreateConVar("AMMO_TYPE_SNIPERRIFLE_SCOUT", "15", "15", DEFAULT_FLAGS);
	granedeClip = CreateConVar("AMMO_TYPE_GRENADELAUNCHER", "1", "1", DEFAULT_FLAGS);
	m60Clip = CreateConVar("AMMO_TYPE_ASSAULTRIFLE_M60", "150", "150", DEFAULT_FLAGS);
	autoClip = CreateConVar("AMMO_TYPE_AUTOSHOTGUN", "10", "10", DEFAULT_FLAGS);
	spasClip = CreateConVar("AMMO_TYPE_AUTOSHOTGUN", "10", "10", DEFAULT_FLAGS);
	g_h_reload_rate = CreateConVar("l4d_powerups_weaponreload_rate", "0.8", "The interval incurred by reloading is multiplied by this value (clamped between 0.2 < 0.9)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.2, true, 0.9);
	HookConVarChange(g_h_reload_rate, Convar_Reload);
	g_fl_reload_rate = 0.8;
	
	
	g_iPlayRateO		=	FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
	g_iTimeIdleO		=	FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
	g_iNextAttO			=	FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
	g_iNextPAttO		=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	g_iVMStartTimeO		=	FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
	g_iViewModelO		=	FindSendPropInfo("CTerrorPlayer","m_hViewModel");
	g_iActiveWO			=	FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	
	HookEvent("weapon_fire", Event_Weapon_Fired);
	HookEvent("item_pickup", Event_Weapon_Pickup);
	HookEvent("weapon_reload", Event_Weapon_Reload,  EventHookMode_Pre);
	HookEvent("ammo_pickup", Event_AmmoPickUp);
	
	AutoExecConfig(true, "l4d2_weapon_reload");
}

public OnMapStart()
{
	for(new i=1; i <= MaxClients; i++)
	{
		ValueLastClip[i] = 0;
		ValueLastAmmo[i] = 0;
		ValueNewClip[i] = 0;
		ClipOffset[i] = 0;
		TimerPlayerReload[i] = INVALID_HANDLE;
	}
}

public Convar_Reload (Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:flF=StringToFloat(newValue);
	if (flF<0.02)
		flF=0.02;
	else if (flF>0.9)
		flF=0.9;
	g_fl_reload_rate = flF;
}

public Action:Event_Weapon_Fired(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new h_mPrimary = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	new h_mPrimary = GetPlayerWeaponSlot(client, 0);
	if(!IsValidEntity(h_mPrimary) || IsFakeClient(client)) return Plugin_Handled;
	
	new String:classname[256];
	GetEntityClassname(h_mPrimary, classname, sizeof(classname));
	if((StrContains(classname, "weapon_smg", false) != -1) ||
	(StrContains(classname, "weapon_smg_silenced", false) != -1) ||
	(StrContains(classname, "weapon_smg_mp5", false) != -1))
	{
		ClipOffset[client] = SMG_OFFSET_IAMMO;
		
	}
	else if((StrContains(classname, "weapon_pumpshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_chrome", false) != -1))
	{
		ClipOffset[client] = PUMPSHOTGUN_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_rifle", false) != -1) ||
	(StrContains(classname, "weapon_rifle_ak47", false) != -1) ||
	(StrContains(classname, "weapon_rifle_desert", false) != -1) ||
	(StrContains(classname, "weapon_rifle_sg552", false) != -1) 
	)
	{
		ClipOffset[client] = ASSAULT_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_autoshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_spas", false) != -1))
	{
		ClipOffset[client] = AUTO_SHOTGUN_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_hunting_rifle", false) != -1)
	{
		ClipOffset[client] = HUNTING_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_sniper_military", false) != -1) ||
	(StrContains(classname, "weapon_sniper_scout", false) != -1) ||
	(StrContains(classname, "weapon_sniper_awp", false) != -1))
	{
		ClipOffset[client] = MILITARY_SNIPER_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_grenade_launcher", false) != -1)
	{
		ClipOffset[client] = GRENADE_LAUNCHER_OFFSET_IAMMO;
	}
	
	new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo");
	ValueLastAmmo[client] = GetEntData(client, (iAmmoOffset + ClipOffset[client]));
	ValueLastClip[client] = GetEntProp(h_mPrimary, Prop_Data, "m_iClip1", 1);
	ValueLastClip[client] = ValueLastClip[client] - 1;

	if(m_debug == 1)
	{
		PrintToChatAll("Event Weapon Fired");
		PrintToChatAll("ValueLastAmmo: %d", ValueLastAmmo[client]);
		PrintToChatAll("ValueLastClip: %d", ValueLastClip[client]);
		PrintToChatAll("---------------------------");
	}
	return Plugin_Handled;
}

public Action:Event_AmmoPickUp(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new h_mPrimary = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	new h_mPrimary = GetPlayerWeaponSlot(client, 0);
	if(!IsValidEntity(h_mPrimary) || IsFakeClient(client)) return Plugin_Handled;
	
	new String:classname[256];
	GetEntityClassname(h_mPrimary, classname, sizeof(classname));
	if((StrContains(classname, "weapon_smg", false) != -1) ||
	(StrContains(classname, "weapon_smg_silenced", false) != -1) ||
	(StrContains(classname, "weapon_smg_mp5", false) != -1))
	{
		ClipOffset[client] = SMG_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_pumpshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_chrome", false) != -1))
	{
		ClipOffset[client] = PUMPSHOTGUN_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_rifle", false) != -1) ||
	(StrContains(classname, "weapon_rifle_ak47", false) != -1) ||
	(StrContains(classname, "weapon_rifle_desert", false) != -1) ||
	(StrContains(classname, "weapon_rifle_sg552", false) != -1)
	)
	{
		ClipOffset[client] = ASSAULT_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_autoshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_spas", false) != -1))
	{
		ClipOffset[client] = AUTO_SHOTGUN_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_hunting_rifle", false) != -1)
	{
		ClipOffset[client] = HUNTING_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_sniper_military", false) != -1) ||
	(StrContains(classname, "weapon_sniper_scout", false) != -1) ||
	(StrContains(classname, "weapon_sniper_awp", false) != -1))
	{
		ClipOffset[client] = MILITARY_SNIPER_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_grenade_launcher", false) != -1)
	{
		ClipOffset[client] = GRENADE_LAUNCHER_OFFSET_IAMMO;
	}
	
	new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo");
	ValueLastAmmo[client] = GetEntData(client, (iAmmoOffset + ClipOffset[client]));

	if(m_debug == 1) PrintToChatAll("Event Ammo Pickup");
	return Plugin_Handled;
}

public Action:Event_Weapon_Pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new h_mPrimary = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	new h_mPrimary = GetPlayerWeaponSlot(client, 0);
	if(!IsValidEntity(h_mPrimary) || IsFakeClient(client)) return Plugin_Handled;
	
	new String:classname[256];
	GetEntityClassname(h_mPrimary, classname, sizeof(classname));
	if((StrContains(classname, "weapon_smg", false) != -1) ||
	(StrContains(classname, "weapon_smg_silenced", false) != -1) ||
	(StrContains(classname, "weapon_smg_mp5", false) != -1))
	{
		ClipOffset[client] = SMG_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_pumpshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_chrome", false) != -1))
	{
		ClipOffset[client] = PUMPSHOTGUN_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_rifle", false) != -1) ||
	(StrContains(classname, "weapon_rifle_ak47", false) != -1) ||
	(StrContains(classname, "weapon_rifle_desert", false) != -1) ||
	(StrContains(classname, "weapon_rifle_sg552", false) != -1) 
	)
	{
		ClipOffset[client] = ASSAULT_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_autoshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_spas", false) != -1))
	{
		ClipOffset[client] = AUTO_SHOTGUN_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_hunting_rifle", false) != -1)
	{
		ClipOffset[client] = HUNTING_RIFLE_OFFSET_IAMMO;
	}
	else if((StrContains(classname, "weapon_sniper_military", false) != -1) ||
	(StrContains(classname, "weapon_sniper_scout", false) != -1) ||
	(StrContains(classname, "weapon_sniper_awp", false) != -1))
	{
		ClipOffset[client] = MILITARY_SNIPER_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_grenade_launcher", false) != -1)
	{
		ClipOffset[client] = GRENADE_LAUNCHER_OFFSET_IAMMO;
	}
	
	new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo");
	ValueLastAmmo[client] = GetEntData(client, (iAmmoOffset + ClipOffset[client]));
	ValueLastClip[client] = GetEntProp(h_mPrimary, Prop_Data, "m_iClip1", 1);

	if(m_debug == 1)
	{
		PrintToChatAll("Event weapon pickup");
		PrintToChatAll("ValueLastAmmo: %d", ValueLastAmmo[client]);
		PrintToChatAll("ValueLastClip: %d", ValueLastClip[client]);
		PrintToChatAll("---------------------------");
	}
	return Plugin_Handled;
}

public Action:Event_Weapon_Reload(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Debugging log: Pistol is also weapon slot 0 (even when having a main weapon, wtf valve?)
	new String:classname[256];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	new ActiveWeapon = GetPlayerWeaponSlot(client, 0);
	if(!IsClientInGame(client))
		return Plugin_Handled;
		
	//Pistol workaround.
	new String:sWeaponName[64];
	GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
	if (StrEqual(sWeaponName, "weapon_pistol")) 
		return Plugin_Handled;
	
	new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo");
	GetEntityClassname(ActiveWeapon, classname, sizeof(classname));
	for(new i=0; i < sizeof(weaponsClass); i++)
	{
		if((StrContains(classname, weaponsClass[i], false) != -1))
		{
			ValueNewClip[client] = weaponClipSize[i];
			if(m_debug == 1)
			{
				PrintToChatAll( "---------------------------");
				PrintToChatAll("what weapon we reloading");
				PrintToChatAll("clipSet: %s", weaponsClass[i]);
				PrintToChatAll("clipSet: %d", weaponClipSize[i]);
				PrintToChatAll("---------------------------");
			}
		}
	}

	
	// what is our clip offset
	if((StrContains(classname, "weapon_smg", false) != -1) ||
	(StrContains(classname, "weapon_smg_silenced", false) != -1) ||
	(StrContains(classname, "weapon_smg_mp5", false) != -1))
	{
		ClipOffset[client] = SMG_OFFSET_IAMMO;	
	}
	else if((StrContains(classname, "weapon_pumpshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_chrome", false) != -1))
	{
		ClipOffset[client] = PUMPSHOTGUN_OFFSET_IAMMO;
		
	}
	else if((StrContains(classname, "weapon_rifle", false) != -1) ||
	(StrContains(classname, "weapon_rifle_ak47", false) != -1) ||
	(StrContains(classname, "weapon_rifle_desert", false) != -1) ||
	(StrContains(classname, "weapon_rifle_sg552", false) != -1)
	)
	{
		ClipOffset[client] = ASSAULT_RIFLE_OFFSET_IAMMO;
		
	}
	else if((StrContains(classname, "weapon_autoshotgun", false) != -1) ||
	(StrContains(classname, "weapon_shotgun_spas", false) != -1))
	{
		ClipOffset[client] = AUTO_SHOTGUN_OFFSET_IAMMO;
	}
	else if(StrContains(classname, "weapon_hunting_rifle", false) != -1)
	{
		ClipOffset[client] = HUNTING_RIFLE_OFFSET_IAMMO;
		
	}
	else if((StrContains(classname, "weapon_sniper_military", false) != -1) ||
	(StrContains(classname, "weapon_sniper_scout", false) != -1) ||
	(StrContains(classname, "weapon_sniper_awp", false) != -1))
	{
		ClipOffset[client] = MILITARY_SNIPER_OFFSET_IAMMO;
		
	}
	else if(StrContains(classname, "weapon_grenade_launcher", false) != -1)
	{
		ClipOffset[client] = GRENADE_LAUNCHER_OFFSET_IAMMO;
	}

	// we have zero stock ammo but we just pick from the ammo pile
	if(ValueLastAmmo[client] <= 0) ValueLastAmmo[client] = GetEntData(client, (iAmmoOffset + ClipOffset[client]));
	
	
	if((ValueLastClip[client] < ValueNewClip[client]))
	{
		
		TimerPlayerReload[client] = CreateTimer(0.1, Timer_InsertClip, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		if(ValueLastClip[client]>=1){
			AdrenReload(client);
		}
	}
	updateConVar();
	return Plugin_Continue;
}
public Action:Timer_InsertClip(Handle:timer, any:client)
{
	//new ActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsClientInGame(client))
		return Plugin_Handled;
	new String:classname[256];
	new ActiveWeapon = GetPlayerWeaponSlot(client, 0);
	GetEntityClassname(ActiveWeapon, classname, sizeof(classname));
	
	
	if((GetEntProp(ActiveWeapon, Prop_Data, "m_bInReload") == 0))
	{
		KillTimer(TimerPlayerReload[client]);

		new clipSet = ValueNewClip[client];
		
		// total clip to subtract from our total stock ammo
		new clip =  (clipSet - ValueLastClip[client]);
		
		new clip2 = (ValueLastAmmo[client] + ValueLastClip[client]);
		
		// incase we run low on stock ammo
		//
		
		// balance of our ammo
		new ammo = (ValueLastAmmo[client] - clip);
		
		// not sure why i need this but i still put him here xD
		if(ammo <= 0) ammo = 0;
		
		
		
		if(m_debug == 1)
		{
			PrintToChatAll("clipSet: %i", clipSet);
			PrintToChatAll("clip: %i", clip);
			PrintToChatAll("clip2: %i", clip2);
			PrintToChatAll("ammo: %i", ammo);
		}
		//if(ValueLastClip[client]>=1 && ActiveWeapon == GetPlayerWeaponSlot(client, 1)){
		//	SetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_iClip1", clipSet+1);
		//}
		if(ValueLastClip[client]>=1 && ActiveWeapon == GetPlayerWeaponSlot(client, 0) && (ClipOffset[client] == SMG_OFFSET_IAMMO || ClipOffset[client] == ASSAULT_RIFLE_OFFSET_IAMMO
		|| ClipOffset[client] == HUNTING_RIFLE_OFFSET_IAMMO || ClipOffset[client] == MILITARY_SNIPER_OFFSET_IAMMO))
		{
			if(clip2 < clipSet) clipSet = clip2;
			new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo");
			//SetEntData(client, (iAmmoOffset + ClipOffset[client]), ammo);
			//SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_iClip1", clipSet);
			SetEntData(client, (iAmmoOffset + ClipOffset[client]), ammo-1);
			SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_iClip1", clipSet+1);
		}
		if(m_debug == 1)
		{
			PrintToChatAll("ValueLastClip[client]: %d", ValueLastClip[client]);
			//PrintToChatAll("Count stoped at: %i", CountTimer);
		}
		
		
		return Plugin_Continue;
	}


}


updateConVar()
{
	weaponClipSize[0] = GetConVarInt(smgClip);
	weaponClipSize[1] = GetConVarInt(smgSilencedClip);
	weaponClipSize[2] = GetConVarInt(smgMp5Clip);
	weaponClipSize[3] = GetConVarInt(pumpClip);
	weaponClipSize[4] = GetConVarInt(chromeClip);
	weaponClipSize[5] = GetConVarInt(huntClip);
	weaponClipSize[6] = GetConVarInt(rifleClip);
	weaponClipSize[7] = GetConVarInt(rifleAk47Clip);
	weaponClipSize[8] = GetConVarInt(rifleDesertClip);
	weaponClipSize[9] = GetConVarInt(rifleSg552Clip);
	weaponClipSize[10] = GetConVarInt(militaryClip);
	weaponClipSize[11] = GetConVarInt(scoutClip);
	weaponClipSize[12] = GetConVarInt(awpClip);
	weaponClipSize[13] = GetConVarInt(granedeClip);
	weaponClipSize[14] = GetConVarInt(m60Clip);
	weaponClipSize[15] = GetConVarInt(autoClip);
	weaponClipSize[16] = GetConVarInt(spasClip);
}
// ////////////////////////////////////////////////////////////////////////////
//On the start of a reload
AdrenReload (client)
{
	if (GetClientTeam(client) == 2)
	{
		#if DEBUG
		PrintToChatAll("\x03Client \x01%i\x03; start of reload detected",client );
		#endif
		new iEntid = GetEntDataEnt2(client, g_iActiveWO);
		if (IsValidEntity(iEntid)==false) return;
	
		decl String:stClass[32];
		GetEntityNetClass(iEntid,stClass,32);
		#if DEBUG
		PrintToChatAll("\x03-class of gun: \x01%s",stClass );
		#endif

		//for non-shotguns
		if (StrContains(stClass,"shotgun",false) == -1)
		{
			MagStart(iEntid, client);
			return;
		}
	}
}
// ////////////////////////////////////////////////////////////////////////////
//called for mag loaders
MagStart (iEntid, client)
{
	#if DEBUG
	PrintToChatAll("\x05-magazine loader detected,\x03 gametime \x01%f", GetGameTime());
	#endif
	new Float:flGameTime = GetGameTime();
	new Float:flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
	#if DEBUG
	PrintToChatAll("\x03- pre, gametime \x01%f\x03, retrieved nextattack\x01 %i %f\x03, retrieved time idle \x01%i %f",
		flGameTime,
		g_iNextAttO,
		GetEntDataFloat(client,g_iNextAttO),
		g_iTimeIdleO,
		GetEntDataFloat(iEntid,g_iTimeIdleO)
		);
	#endif

	//this is a calculation of when the next primary attack will be after applying reload values
	//NOTE: at this point, only calculate the interval itself, without the actual game engine time factored in
	new Float:flNextTime_calc = ( flNextTime_ret - flGameTime ) * g_fl_reload_rate ;
	//we change the playback rate of the gun, just so the player can "see" the gun reloading faster
	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/g_fl_reload_rate, true);
	//create a timer to reset the playrate after time equal to the modified attack interval
	CreateTimer( flNextTime_calc, Timer_MagEnd, iEntid);
	//experiment to remove double-playback bug
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, client);
	//this calculates the equivalent time for the reload to end
	new Float:flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - g_fl_reload_rate ) ;
	WritePackFloat(hPack, flStartTime_calc);
	//now we create the timer that will prevent the annoying double playback
	if ( (flNextTime_calc - 0.4) > 0 )
		CreateTimer( flNextTime_calc - 0.4 , Timer_MagEnd2, hPack);
	//and finally we set the end reload time into the gun so the player can actually shoot with it at the end
	flNextTime_calc += flGameTime;
	SetEntDataFloat(iEntid, g_iTimeIdleO, flNextTime_calc, true);
	SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
	SetEntDataFloat(client, g_iNextAttO, flNextTime_calc, true);
	#if DEBUG
	PrintToChatAll("\x03- post, calculated nextattack \x01%f\x03, gametime \x01%f\x03, retrieved nextattack\x01 %i %f\x03, retrieved time idle \x01%i %f",
		flNextTime_calc,
		flGameTime,
		g_iNextAttO,
		GetEntDataFloat(client,g_iNextAttO),
		g_iTimeIdleO,
		GetEntDataFloat(iEntid,g_iTimeIdleO)
		);
	#endif
}

// ////////////////////////////////////////////////////////////////////////////
//this resets the playback rate on non-shotguns
public Action:Timer_MagEnd (Handle:timer, any:iEntid)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
		return Plugin_Stop;

	#if DEBUG
	PrintToChatAll("\x03Reset playback, magazine loader");
	#endif

	if (iEntid <= 0
		|| IsValidEntity(iEntid)==false)
		return Plugin_Stop;

	SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

	return Plugin_Stop;
}

public Action:Timer_MagEnd2 (Handle:timer, Handle:hPack)
{
	KillTimer(timer);
	if (IsServerProcessing()==false)
	{
		CloseHandle(hPack);
		return Plugin_Stop;
	}

	#if DEBUG
	PrintToChatAll("\x03Reset playback, magazine loader");
	#endif

	ResetPack(hPack);
	new iCid = ReadPackCell(hPack);
	new Float:flStartTime_calc = ReadPackFloat(hPack);
	CloseHandle(hPack);

	if (iCid <= 0
		|| IsValidEntity(iCid)==false
		|| IsClientInGame(iCid)==false)
		return Plugin_Stop;

	//experimental, remove annoying double-playback
	new iVMid = GetEntDataEnt2(iCid,g_iViewModelO);
	SetEntDataFloat(iVMid, g_iVMStartTimeO, flStartTime_calc, true);

	#if DEBUG
	PrintToChatAll("\x03- end mag loader, icid \x01%i\x03 starttime \x01%f\x03 gametime \x01%f", iCid, flStartTime_calc, GetGameTime());
	#endif

	return Plugin_Stop;
}