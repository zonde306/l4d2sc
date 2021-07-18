#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_framework>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能：治疗效果",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const int g_iMinLevel = 5;
const float g_fLevelFactor = 1.0;

int g_iSlotHealing;
int g_iLevelPills[MAXPLAYERS+1], g_iLevelAdrenaline[MAXPLAYERS+1], g_iLevelMedical[MAXPLAYERS+1], g_iLevelDefib[MAXPLAYERS+1], g_iLevelPass[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("weapon_given", Event_WeaponGiven);
	
	LoadTranslations("l4d2sf_healing.phrases.txt");
	
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	L4D2SF_RegPerk(g_iSlotHealing, "morepills", 3, 20, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moreadrenaline", 3, 20, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moremedical", 2, 15, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moredefib", 3, 15, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "pillspassfix", 1, 5, g_iMinLevel, g_fLevelFactor);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "morepills"))
		FormatEx(result, maxlen, "%T", "药丸强化", client, level);
	else if(!strcmp(name, "moreadrenaline"))
		FormatEx(result, maxlen, "%T", "针筒强化", client, level);
	else if(!strcmp(name, "moremedical"))
		FormatEx(result, maxlen, "%T", "药包强化", client, level);
	else if(!strcmp(name, "moredefib"))
		FormatEx(result, maxlen, "%T", "电击强化", client, level);
	else if(!strcmp(name, "pillspassfix"))
		FormatEx(result, maxlen, "%T", "递药保护", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "morepills"))
		FormatEx(result, maxlen, "%T", tr("药丸强化%d", IntBound(level, 1, 3)), client, level);
	else if(!strcmp(name, "moreadrenaline"))
		FormatEx(result, maxlen, "%T", tr("针筒强化%d", IntBound(level, 1, 3)), client, level);
	else if(!strcmp(name, "moremedical"))
		FormatEx(result, maxlen, "%T", tr("药包强化%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "moredefib"))
		FormatEx(result, maxlen, "%T", tr("电击强化%d", IntBound(level, 1, 3)), client, level);
	else if(!strcmp(name, "pillspassfix"))
		FormatEx(result, maxlen, "%T", tr("递药保护%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "morepills"))
		g_iLevelPills[client] = level;
	else if(!strcmp(perk, "moreadrenaline"))
		g_iLevelAdrenaline[client] = level;
	else if(!strcmp(perk, "moremedical"))
		g_iLevelMedical[client] = level;
	else if(!strcmp(perk, "moredefib"))
		g_iLevelDefib[client] = level;
	else if(!strcmp(perk, "pillspassfix"))
		g_iLevelPass[client] = level;
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelPills[client] = L4D2SF_GetClientPerk(client, "morepills");
	g_iLevelAdrenaline[client] = L4D2SF_GetClientPerk(client, "moreadrenaline");
	g_iLevelMedical[client] = L4D2SF_GetClientPerk(client, "moremedical");
	g_iLevelDefib[client] = L4D2SF_GetClientPerk(client, "moredefib");
	g_iLevelPass[client] = L4D2SF_GetClientPerk(client, "pillspassfix");
}

public void Event_PillsUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	int buffer = GetPlayerTempHealth(client);
	
	if(g_iLevelPills[client] >= 1)
	{
		buffer += 30;
	}
	if(g_iLevelPills[client] >= 2)
	{
		buffer += 20;
	}
	if(g_iLevelPills[client] >= 3)
	{
		UseAdrenaline(client, 5 * g_iLevelPills[client] - 2);
	}
	
	if(buffer + health > maxHealth)
		buffer = maxHealth - health;
	
	if(g_iLevelPills[client] > 0 && buffer > 0)
	{
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(buffer));
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
}

public void Event_AdrenalineUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	int buffer = GetPlayerTempHealth(client);
	int duration = 0;
	
	if(g_iLevelAdrenaline[client] >= 1)
	{
		buffer += 20;
		duration += 5;
	}
	if(g_iLevelAdrenaline[client] >= 2)
	{
		buffer += 30;
		duration += 5;
	}
	if(g_iLevelAdrenaline[client] >= 3)
	{
		buffer += 20;
		duration += 5;
	}
	if(g_iLevelAdrenaline[client] >= 4)
	{
		duration += 5 * g_iLevelAdrenaline[client] - 3;
	}
	
	if(buffer + health > maxHealth)
		buffer = maxHealth - health;
	
	if(g_iLevelAdrenaline[client] > 0 && buffer > 0)
	{
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(buffer));
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	}
	
	if(g_iLevelAdrenaline[client] > 0 && duration > 0)
	{
		static ConVar adrenaline_duration;
		if(adrenaline_duration == null)
			adrenaline_duration = FindConVar("adrenaline_duration");
		
		UseAdrenaline(client, adrenaline_duration.IntValue + duration);
	}
}

public void Event_HealSuccess(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client) || !IsValidClient(subject))
		return;
	
	if(g_iLevelMedical[client] >= 1 || g_iLevelMedical[subject] >= 1)
	{
		SetEntProp(subject, Prop_Data, "m_iHealth", GetEntProp(subject, Prop_Data, "m_iMaxHealth"));
	}
	
	if(g_iLevelMedical[subject] >= 2)
	{
		UseAdrenaline(subject, g_iLevelMedical[subject] - 1);
	}
	if(g_iLevelMedical[client] >= 2)
	{
		UseAdrenaline(client, g_iLevelMedical[client] - 1);
	}
}

public void Event_DefibrillatorUsed(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if(!IsValidClient(client) || !IsValidClient(subject))
		return;
	
	int health = GetEntProp(subject, Prop_Data, "m_iHealth");
	int maxHealth = GetEntProp(subject, Prop_Data, "m_iMaxHealth");
	
	if(g_iLevelDefib[client] >= 1 || g_iLevelDefib[subject] >= 1)
	{
		health += 30;
	}
	if(g_iLevelDefib[client] >= 2 || g_iLevelDefib[subject] >= 2)
	{
		health += 20;
	}
	
	if(health > maxHealth)
		health = maxHealth;
	
	SetEntProp(subject, Prop_Data, "m_iHealth", health, 2);
	
	if(g_iLevelDefib[subject] >= 3)
	{
		UseAdrenaline(subject, g_iLevelDefib[subject] - 2);
	}
	if(g_iLevelDefib[client] >= 3)
	{
		UseAdrenaline(client, g_iLevelDefib[client] - 2);
	}
}

public void Event_WeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	int receiver = GetClientOfUserId(event.GetInt("userid"));
	int giver = GetClientOfUserId(event.GetInt("giver"));
	if(!IsValidClient(receiver) || !IsValidClient(giver))
		return;
	
	if(g_iLevelPass[receiver] <= 0 && g_iLevelPass[giver] <= 0)
		return;
	
	char item[32];
	GetEventString(event, "weapon", item, sizeof(item));
	
	if(StrEqual(item, "15") || StrEqual(item, "23"))
		SDKHook(receiver, SDKHook_WeaponSwitch, EntHook_OnWeaponSwitch);
}

public Action EntHook_OnWeaponSwitch(int client, int weapon)
{
	if(!IsValidClient(client) || !IsValidEdict(weapon))
		return Plugin_Continue;
	
	char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname)))
		return Plugin_Continue;
	
	if(!strcmp(classname, "weapon_adrenaline", false) || !strcmp(classname, "weapon_pain_pills", false))
	{
		SDKUnhook(client, SDKHook_WeaponSwitch, EntHook_OnWeaponSwitch);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

int GetPlayerTempHealth(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
		return 0;
	
	ConVar painPillsDecayCvar;
	if (painPillsDecayCvar == null)
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
	
	int tempHealth = RoundToCeil(
		GetEntPropFloat(client, Prop_Send, "m_healthBuffer") -
		((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) *
		painPillsDecayCvar.FloatValue)) - 1;
	
	return tempHealth < 0 ? 0 : tempHealth;
}

void L4D2_RunScript(char[] sCode, any ...)
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static char sBuffer[8192];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

void UseAdrenaline(int client, int duration)
{
	DataPack data = CreateDataPack();
	data.WriteCell(client);
	data.WriteCell(duration);
	RequestFrame(DelayUseAdrenaline, data);
}

public void DelayUseAdrenaline(any pack)
{
	DataPack data = view_as<DataPack>(pack);
	data.Reset();
	
	int client = data.ReadCell();
	int duration = data.ReadCell();
	
	L4D2_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%d)", GetClientUserId(client), duration);
}
