#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2_saferoom_detect>
#include <weapons>

#define DEBUG 0

public Plugin:myinfo = 
{
	name = "武器替换",
	author = "",
	description = "",
	version = "0.1",
	url = ""
}

new g_GlobalWeaponRules[WeaponId]={-1, ...};
new Handle:g_pWeaponRules[_:WeaponId] = {INVALID_HANDLE, ...};

// state tracking for roundstart looping
new g_bRoundStartHit=false;
new g_bConfigsExecuted=false;
new bool:g_bIsFirstRound=false;
new bool:g_bIsUseCalled=false;

ArrayList g_arrConvertItem;
Handle g_pSafeRoomWeapon, g_pSafeRoomHealth, g_pSafeRoomItem;

public OnPluginStart()
{
	g_pWeaponRules[_:WEPID_NONE] = CreateConVar("l4d2_weaponrule_count", "1", "默认武器数量.0=原来的", FCVAR_NONE, true, 0.0);
	g_pWeaponRules[_:WEPID_PISTOL] = GenerateConVar(WeaponNames[_:WEPID_PISTOL]);
	g_pWeaponRules[_:WEPID_SMG] = GenerateConVar(WeaponNames[_:WEPID_SMG]);
	g_pWeaponRules[_:WEPID_PUMPSHOTGUN] = GenerateConVar(WeaponNames[_:WEPID_PUMPSHOTGUN]);
	g_pWeaponRules[_:WEPID_AUTOSHOTGUN] = GenerateConVar(WeaponNames[_:WEPID_AUTOSHOTGUN]);
	g_pWeaponRules[_:WEPID_RIFLE] = GenerateConVar(WeaponNames[_:WEPID_RIFLE]);
	g_pWeaponRules[_:WEPID_HUNTING_RIFLE] = GenerateConVar(WeaponNames[_:WEPID_HUNTING_RIFLE]);
	g_pWeaponRules[_:WEPID_SMG_SILENCED] = GenerateConVar(WeaponNames[_:WEPID_SMG_SILENCED]);
	g_pWeaponRules[_:WEPID_SHOTGUN_CHROME] = GenerateConVar(WeaponNames[_:WEPID_SHOTGUN_CHROME]);
	g_pWeaponRules[_:WEPID_RIFLE_DESERT] = GenerateConVar(WeaponNames[_:WEPID_RIFLE_DESERT]);
	g_pWeaponRules[_:WEPID_SNIPER_MILITARY] = GenerateConVar(WeaponNames[_:WEPID_SNIPER_MILITARY]);
	g_pWeaponRules[_:WEPID_SHOTGUN_SPAS] = GenerateConVar(WeaponNames[_:WEPID_SHOTGUN_SPAS]);
	g_pWeaponRules[_:WEPID_FIRST_AID_KIT] = GenerateConVar(WeaponNames[_:WEPID_FIRST_AID_KIT]);
	g_pWeaponRules[_:WEPID_MOLOTOV] = GenerateConVar(WeaponNames[_:WEPID_MOLOTOV]);
	g_pWeaponRules[_:WEPID_PIPE_BOMB] = GenerateConVar(WeaponNames[_:WEPID_PIPE_BOMB]);
	g_pWeaponRules[_:WEPID_PAIN_PILLS] = GenerateConVar(WeaponNames[_:WEPID_PAIN_PILLS]);
	g_pWeaponRules[_:WEPID_MELEE] = GenerateConVar(WeaponNames[_:WEPID_MELEE]);
	g_pWeaponRules[_:WEPID_CHAINSAW] = GenerateConVar(WeaponNames[_:WEPID_CHAINSAW]);
	g_pWeaponRules[_:WEPID_GRENADE_LAUNCHER] = GenerateConVar(WeaponNames[_:WEPID_GRENADE_LAUNCHER]);
	g_pWeaponRules[_:WEPID_AMMO_PACK] = GenerateConVar(WeaponNames[_:WEPID_AMMO_PACK]);
	g_pWeaponRules[_:WEPID_ADRENALINE] = GenerateConVar(WeaponNames[_:WEPID_ADRENALINE]);
	g_pWeaponRules[_:WEPID_DEFIBRILLATOR] = GenerateConVar(WeaponNames[_:WEPID_DEFIBRILLATOR]);
	g_pWeaponRules[_:WEPID_VOMITJAR] = GenerateConVar(WeaponNames[_:WEPID_VOMITJAR]);
	g_pWeaponRules[_:WEPID_RIFLE_AK47] = GenerateConVar(WeaponNames[_:WEPID_RIFLE_AK47]);
	g_pWeaponRules[_:WEPID_FIREWORKS_BOX] = GenerateConVar(WeaponNames[_:WEPID_FIREWORKS_BOX]);
	g_pWeaponRules[_:WEPID_GASCAN] = GenerateConVar(WeaponNames[_:WEPID_GASCAN]);
	g_pWeaponRules[_:WEPID_PROPANE_TANK] = GenerateConVar(WeaponNames[_:WEPID_PROPANE_TANK]);
	g_pWeaponRules[_:WEPID_OXYGEN_TANK] = GenerateConVar(WeaponNames[_:WEPID_OXYGEN_TANK]);
	g_pWeaponRules[_:WEPID_INCENDIARY_AMMO] = GenerateConVar(WeaponNames[_:WEPID_INCENDIARY_AMMO]);
	g_pWeaponRules[_:WEPID_FRAG_AMMO] = GenerateConVar(WeaponNames[_:WEPID_FRAG_AMMO]);
	g_pWeaponRules[_:WEPID_PISTOL_MAGNUM] = GenerateConVar(WeaponNames[_:WEPID_PISTOL_MAGNUM]);
	g_pWeaponRules[_:WEPID_SMG_MP5] = GenerateConVar(WeaponNames[_:WEPID_SMG_MP5]);
	g_pWeaponRules[_:WEPID_RIFLE_SG552] = GenerateConVar(WeaponNames[_:WEPID_RIFLE_SG552]);
	g_pWeaponRules[_:WEPID_SNIPER_AWP] = GenerateConVar(WeaponNames[_:WEPID_SNIPER_AWP]);
	g_pWeaponRules[_:WEPID_SNIPER_SCOUT] = GenerateConVar(WeaponNames[_:WEPID_SNIPER_SCOUT]);
	g_pWeaponRules[_:WEPID_RIFLE_M60] = GenerateConVar(WeaponNames[_:WEPID_RIFLE_M60]);
	g_pWeaponRules[_:WEPID_AMMO] = GenerateConVar(WeaponNames[_:WEPID_AMMO]);
	g_pWeaponRules[_:WEPID_UPGRADE_ITEM] = GenerateConVar(WeaponNames[_:WEPID_UPGRADE_ITEM]);
	g_pSafeRoomWeapon = GenerateConVar("weapon_saferoom_weapon");
	g_pSafeRoomHealth = GenerateConVar("weapon_saferoom_health");
	g_pSafeRoomItem = GenerateConVar("weapon_saferoom_item");
	AutoExecConfig(true, "l4d2_weaponrules");
	
	RegServerCmd("l4d2_addweaponrule", AddWeaponRuleCb);
	RegServerCmd("l4d2_resetweaponrules", ResetWeaponRulesCb);
	RegServerCmd("l4d2_executeweaponrules", ExecuteWeaponRulesCb);
	
	HookEvent("round_start", RoundStartCb, EventHookMode_PostNoCopy);
	HookEvent("player_use", PlayerUseCb, EventHookMode_PostNoCopy);
	HookEvent("use_target", PlayerUseCb, EventHookMode_PostNoCopy);
	HookEvent("player_footstep", PlayerUseCb, EventHookMode_PostNoCopy);
	HookEvent("player_jump", PlayerUseCb, EventHookMode_PostNoCopy);
	
	L4D2Weapons_Init();
	ResetWeaponRules();
	g_arrConvertItem = CreateArray();
}

Handle:GenerateConVar(const String:name[])
{
	new String:buffer[255];
	strcopy(buffer, 255, name);
	if(StrContains(buffer, "weapon_", false) == 0)
		ReplaceString(buffer, 255, "weapon_", "", false);
	
	TrimString(buffer);
	Format(buffer, 255, "l4d2_weaponrule_%s", buffer);
	return CreateConVar(buffer, "", "武器替换/修改数量.数字=数量.类名=替换.类名<等号>数量=替换并设置数量", FCVAR_NONE);
}

GetWeapon(WeaponId:weapon, String:classname[] = "", len = 0)
{
	if(g_pWeaponRules[weapon] == INVALID_HANDLE)
		return -1;
	
	return ParseWeapon(g_pWeaponRules[weapon], classname, len);
}

ParseWeapon(Handle:cvar, String:classname[] = "", len = 0)
{
	decl String:strValue[255];
	GetConVarString(cvar, strValue, 255);
	TrimString(strValue);
	
	if(strValue[0] == EOS)
		return -1;
	
	if(StrContains(strValue, ",", false) > 0)
		return ProccessMultipleRules(strValue, classname, len);
	
	return ProccessSimpleRules(strValue, classname, len);
}

bool:ProccessWeaponRules(const String:strValue[])
{
	decl String:buffer[64];
	strcopy(buffer, 64, strValue);
	TrimString(buffer);
	
	new WeaponId:weapon = WeaponNameToId(strValue);
	if(weapon == WEPID_NONE)
		return false;
	
	return true;
}

ProccessCountRules(const String:strValue[])
{
	decl String:buffer[11];
	strcopy(buffer, 11, strValue);
	TrimString(buffer);
	
	if(strValue[0] == '-' || strValue[0] == '.')
		return 0;
	
	if(strValue[0] < '0' && strValue[0] > '9')
		return -1;
	
	return StringToInt(strValue);
}

ProccessSimpleRules(const String:strValue[], String:classname[] = "", len = 0)
{
	// new bool:success = false;
	new amount = GetConVarInt(g_pWeaponRules[_:WEPID_NONE]);
	if(StrContains(strValue, "=", false) == -1)
	{
		new count = ProccessCountRules(strValue);
		if(count >= 0)
			return count;
		
		if(ProccessWeaponRules(strValue))
		{
			decl String:buffer[64];
			strcopy(buffer, 64, strValue);
			TrimString(buffer);
			strcopy(classname, len, buffer);
			return amount;
		}
	}
	else
	{
		new String:pair[2][64];
		if(ExplodeString(strValue, "=", pair, 2, 64) >= 2)
		{
			amount = ProccessCountRules(pair[1]);
			if(ProccessWeaponRules(pair[0]))
			{
				TrimString(pair[0]);
				strcopy(classname, len, pair[0]);
				return amount;
			}
		}
	}
	
	return -1;
}

ProccessMultipleRules(const String:strValue[], String:classname[] = "", len = 0)
{
	decl String:tuple[4][64], count[4];
	new max = ExplodeString(strValue, ",", tuple, 4, 64);
	for(new i = 0; i < max; ++i)
		count[i] = ProccessSimpleRules(tuple[i], tuple[i], 64);
	
	max = GetRandomInt(0, max - 1);
	if(ProccessWeaponRules(tuple[max]))
		strcopy(classname, len, tuple[max]);
	
	return count[max];
}

public Action:ResetWeaponRulesCb(args)
{
	ResetWeaponRules();
	return Plugin_Handled;
}

public Action:ExecuteWeaponRulesCb(args)
{
	WeaponSearchLoop();
	return Plugin_Handled;
}

ResetWeaponRules()
{
	for(new i=0; i < _:WeaponId; i++) g_GlobalWeaponRules[i]=-1;
}

public RoundStartCb(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bIsFirstRound)
		CreateTimer(0.4, RoundStartDelay, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	else
		CreateTimer(0.1, RoundStartDelay, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	
	g_arrConvertItem.Clear();
	g_bIsUseCalled=false;
}

public PlayerUseCb(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bIsFirstRound && !g_bIsUseCalled)
	{
		WeaponSearchLoop();
		g_bIsUseCalled = true;
	}
}

public OnMapStart()
{
	g_bRoundStartHit=false;
	g_bConfigsExecuted=false;
	g_bIsFirstRound=true;
	g_bIsUseCalled=false;
	
	for(new i = 0; i < _:WeaponId; ++i)
	{
		if(WeaponModels[i][0] != EOS)
			PrecacheModel(WeaponModels[i], true);
	}
}

public OnConfigsExecuted()
{
	g_bConfigsExecuted=true;
	g_bIsFirstRound=true;
	if(g_bRoundStartHit)
	{
		WeaponSearchLoop();
	}
}
public Action:RoundStartDelay(Handle:timer)
{
	g_bRoundStartHit=true;
	if(g_bConfigsExecuted)
	{
		WeaponSearchLoop();
	}
}

public Action:AddWeaponRuleCb(args)
{
	if(args < 2)
	{
		LogMessage("Usage: l4d2_addweaponrule <match> <replace>");
		return Plugin_Handled;
	}
	decl String:weaponbuf[64];

	GetCmdArg(1, weaponbuf, sizeof(weaponbuf));
	new WeaponId:match = WeaponNameToId2(weaponbuf);

	GetCmdArg(2, weaponbuf, sizeof(weaponbuf));
	new WeaponId:to = WeaponNameToId2(weaponbuf);
	//6 is hr, 10 is military 
	if ((_:to) == 6)
		{
			if (GetRandomInt(1, 2) == 1) 
				{ 
					(_:to) = 6;
					AddWeaponRule(match, _:to);
				}
			else
				{
					(_:to) = 35;
					AddWeaponRule(match, _:to);
				}
		}
	else if ((_:to) == 10)
		{ 
			if (GetRandomInt(1, 2) == 1) 
				{ 
					(_:to) = 10;
					AddWeaponRule(match, _:to);
				}
			else
				{
					(_:to) = 36;
					AddWeaponRule(match, _:to);
				}
		}
	AddWeaponRule(match, _:to);
	return Plugin_Handled;
}


AddWeaponRule(WeaponId:match, to)
{
	if(IsValidWeaponId(match) && (to == -1 || IsValidWeaponId(WeaponId:to)))
	{
		g_GlobalWeaponRules[match] = _:to;
#if DEBUG
		LogMessage("Added weapon rule: %d to %d", match, to);
#endif

	}
}

bool:IsQE2()
{
	new String:map[64];
	GetCurrentMap(map, 64);
	return (StrContains(map, "qe2_", false) == 0);
}

WeaponSearchLoop()
{
	new entcnt = GetMaxEntities();
	decl String:buffer[64], count;
	new bool:qe2 = IsQE2();
	
	PrintToServer("========= warp weapon start =========");
	for(new ent = MaxClients + 1; ent < entcnt; ++ent)
	{
		if(!IsValidEntity(ent) || !HasEntProp(ent, Prop_Send, "m_hOwnerEntity") ||
			GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") > 0)
			continue;
		
		new WeaponId:source = IdentifyWeapon(ent);
		if(source == WEPID_NONE || g_arrConvertItem.FindValue(ent) > -1)
			continue;
		
		// 修复
		if(qe2 && source == WEPID_GRENADE_LAUNCHER)
			continue;
		
		if(g_GlobalWeaponRules[source] != -1)
		{
			if(g_GlobalWeaponRules[source] == _:WEPID_NONE)
			{
				AcceptEntityInput(ent, "kill");
				PrintToServer("%s was cleared (stage1).", WeaponNames[source]);
			}
			else
			{
				ConvertWeaponSpawn(ent, WeaponId:g_GlobalWeaponRules[source]);
				PrintToServer("%s was convert to %s (stage1).", WeaponNames[source], WeaponNames[g_GlobalWeaponRules[source]]);
			}
			
			continue;
		}
		
		count = -1;
		buffer[0] = EOS;
		if(SAFEDETECT_IsEntityInStartSaferoom(ent) || SAFEDETECT_IsEntityInEndSaferoom(ent))
		{
			if(source == WEPID_FIRST_AID_KIT || source == WEPID_PAIN_PILLS || source == WEPID_ADRENALINE)
			{
				count = ParseWeapon(g_pSafeRoomHealth, buffer, 64);
				PrintToServer("%s detected for saferoom.", WeaponNames[source]);
			}
			else if(source == WEPID_MOLOTOV || source == WEPID_PIPE_BOMB || source == WEPID_VOMITJAR ||
				source == WEPID_INCENDIARY_AMMO || source == WEPID_FRAG_AMMO)
			{
				count = ParseWeapon(g_pSafeRoomItem, buffer, 64);
				PrintToServer("%s detected for saferoom.", WeaponNames[source]);
			}
			else if(source == WEPID_RIFLE_AK47 || source == WEPID_GRENADE_LAUNCHER ||
				(source >= WEPID_PISTOL && source <= WEPID_SHOTGUN_SPAS) ||
				(source >= WEPID_PISTOL_MAGNUM && source <= WEPID_RIFLE_M60))
			{
				count = ParseWeapon(g_pSafeRoomWeapon, buffer, 64);
				PrintToServer("%s detected for saferoom.", WeaponNames[source]);
			}
		}
		
		if(count == -1 && buffer[0] == EOS)
		{
			count = GetWeapon(source, buffer, 64);
		}
		
		if(count > -1)
		{
			if(buffer[0] != EOS)
			{
				g_arrConvertItem.Push(ConvertWeaponSpawn(ent, WeaponNameToId(buffer), count));
				PrintToServer("%s was convert to %s (stage2).", WeaponNames[source], buffer);
			}
			else if(count > 0)
			{
				IntToString(count, buffer, 64);
				DispatchKeyValue(ent, "count", buffer);
				PrintToServer("%s was count %s (stage2).", WeaponNames[source], buffer);
			}
			else
			{
				AcceptEntityInput(ent, "kill");
				PrintToServer("%s was cleared (stage2).", WeaponNames[source]);
			}
		}
	}
	PrintToServer("========= warp weapon end =========");
}

// Tries the given weapon name directly, and upon failure,
// tries prepending "weapon_" to the given name
stock WeaponId:WeaponNameToId2(const String:name[])
{
	static String:namebuf[64]="weapon_";
	new WeaponId:wepid = WeaponNameToId(name);
	if(wepid == WEPID_NONE)
	{
		strcopy(namebuf[7], sizeof(namebuf)-7, name);
		wepid=WeaponNameToId(namebuf);
	}
	return wepid;
}
