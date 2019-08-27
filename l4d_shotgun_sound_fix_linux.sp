#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

static int L4D2;

static bool bThirdPerson[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "第三人称霰弹枪声音修复",
    author = "MasterMind420, Lux",
    description = "Thirdpersonshoulder Shotgun Sound Fix",
    version = "1.1",
    url = ""
}

public void OnPluginStart()
{
	GameCheck();
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
}

void GameCheck()
{
	static char GameName[16];
	GetGameFolderName(GameName, sizeof(GameName));

	if (StrEqual(GameName, "left4dead2", false))
		L4D2 = true;
	else
		L4D2 = false;
}

public void Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	static int client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsValidClient(client))
		return;

	if(!bThirdPerson[client])
		return;

	if(!IsPlayerAlive(client) || GetClientTeam(client) != 2)
		return;

	static int weapon;
	weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

	if(weapon == -1)
		return;

	static char sWeapon[16];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));

	switch(sWeapon[0])
	{
		case 'a':
		{
			if (StrEqual(sWeapon, "autoshotgun"))
			{
				if(L4D2 && GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") == 1)
					EmitGameSoundToClient(client, "AutoShotgun.FireIncendiary", SOUND_FROM_PLAYER, SND_NOFLAGS);
				else
					EmitGameSoundToClient(client, "AutoShotgun.Fire", SOUND_FROM_PLAYER, SND_NOFLAGS);
			}
		}
		case 'p':
		{
			if (StrEqual(sWeapon, "pumpshotgun"))
			{
				if(L4D2 && GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") == 1)
					EmitGameSoundToClient(client, "Shotgun.FireIncendiary", SOUND_FROM_PLAYER, SND_NOFLAGS);
				else
					EmitGameSoundToClient(client, "Shotgun.Fire", SOUND_FROM_PLAYER, SND_NOFLAGS);
			}
		}
		case 's':
		{
			if(!L4D2)
				return;

			if (StrEqual(sWeapon, "shotgun_spas"))
			{
				if(GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") == 1)
					EmitGameSoundToClient(client, "AutoShotgun_Spas.FireIncendiary", SOUND_FROM_PLAYER, SND_NOFLAGS);
				else
					EmitGameSoundToClient(client, "AutoShotgun_Spas.Fire", SOUND_FROM_PLAYER, SND_NOFLAGS);
			}
			else if (StrEqual(sWeapon, "shotgun_chrome"))
			{
				if(GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") == 1)
					EmitGameSoundToClient(client, "Shotgun_Chrome.FireIncendiary", SOUND_FROM_PLAYER, SND_NOFLAGS);
				else
					EmitGameSoundToClient(client, "Shotgun_Chrome.Fire", SOUND_FROM_PLAYER, SND_NOFLAGS);
			}
		}
	}  
}

public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson)
{
	bThirdPerson[iClient] = bIsThirdPerson;
}

static bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient));
}