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
int g_iLevelPills[MAXPLAYERS+1], g_iLevelAdrenaline[MAXPLAYERS+1], g_iLevelMedical[MAXPLAYERS+1], g_iLevelDefib[MAXPLAYERS+1],
	g_iLevelPass[MAXPLAYERS+1], g_iLevelHealth[MAXPLAYERS+1], g_iLevelCure[MAXPLAYERS+1], g_iLevelIncapCount[MAXPLAYERS+1],
	g_iLevelRevive[MAXPLAYERS+1], g_iLevelIncapHealth[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("weapon_given", Event_WeaponGiven);
	HookEvent("map_transition", Event_MapEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("start_holdout", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_pre_entity", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start_post_nav", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	
	LoadTranslations("l4d2sf_healing.phrases.txt");
	
	g_iSlotHealing = L4D2SF_RegSlot("healing");
	L4D2SF_RegPerk(g_iSlotHealing, "morepills", 3, 20, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moreadrenaline", 3, 20, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moremedical", 2, 15, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moredefib", 3, 15, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "pillspassfix", 1, 5, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "fullhealth", 1, 25, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "curedying", 2, 50, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moreincap", 2, 40, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "morerevive", 4, 30, g_iMinLevel, g_fLevelFactor);
	L4D2SF_RegPerk(g_iSlotHealing, "moreincaphealth", 4, 30, g_iMinLevel, g_fLevelFactor);
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
	else if(!strcmp(name, "fullhealth"))
		FormatEx(result, maxlen, "%T", "开局回血", client, level);
	else if(!strcmp(name, "curedying"))
		FormatEx(result, maxlen, "%T", "治疗黑白", client, level);
	else if(!strcmp(name, "moreincap"))
		FormatEx(result, maxlen, "%T", "倒地次数", client, level);
	else if(!strcmp(name, "morerevive"))
		FormatEx(result, maxlen, "%T", "救起血量", client, level);
	else if(!strcmp(name, "moreincaphealth"))
		FormatEx(result, maxlen, "%T", "倒地血量", client, level);
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
	else if(!strcmp(name, "fullhealth"))
		FormatEx(result, maxlen, "%T", tr("开局回血%d", IntBound(level, 1, 1)), client, level);
	else if(!strcmp(name, "curedying"))
		FormatEx(result, maxlen, "%T", tr("治疗黑白%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "moreincap"))
		FormatEx(result, maxlen, "%T", tr("倒地次数%d", IntBound(level, 1, 2)), client, level);
	else if(!strcmp(name, "morerevive"))
		FormatEx(result, maxlen, "%T", tr("救起血量%d", IntBound(level, 1, 4)), client, level);
	else if(!strcmp(name, "moreincaphealth"))
		FormatEx(result, maxlen, "%T", tr("倒地血量%d", IntBound(level, 1, 4)), client, level);
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
	else if(!strcmp(perk, "fullhealth"))
		g_iLevelHealth[client] = level;
	else if(!strcmp(perk, "curedying"))
		g_iLevelCure[client] = level;
	else if(!strcmp(perk, "moreincap"))
		g_iLevelIncapCount[client] = level;
	else if(!strcmp(perk, "morerevive"))
		g_iLevelRevive[client] = level;
	else if(!strcmp(perk, "moreincaphealth"))
		g_iLevelIncapHealth[client] = level;
}

bool g_bGameStarted = false;
int g_iCureUsed[MAXPLAYERS+1], g_iIncapUsed[MAXPLAYERS+1];

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
	g_iLevelHealth[client] = L4D2SF_GetClientPerk(client, "fullhealth");
	g_iLevelCure[client] = L4D2SF_GetClientPerk(client, "curedying");
	g_iLevelIncapCount[client] = L4D2SF_GetClientPerk(client, "moreincap");
	g_iLevelRevive[client] = L4D2SF_GetClientPerk(client, "morerevive");
	g_iLevelIncapHealth[client] = L4D2SF_GetClientPerk(client, "moreincaphealth");
	
	if(!g_bGameStarted)
		if(g_iLevelHealth[client] >= 1)
			RequestFrame(GiveHealth, client);
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
		UseAdrenaline(client, 5 * (g_iLevelPills[client] - 2));
	}
	
	if(buffer + health > maxHealth)
		buffer = maxHealth - health;
	
	if(g_iLevelPills[client] > 0 && buffer > 0)
	{
		SetHealthBuffer(client, buffer);
	}
	
	if(g_iLevelCure[client] >= 2 && g_iCureUsed[client] < g_iLevelCure[client] && GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1))
	{
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0, 1);
		int incap = GetEntProp(client, Prop_Send, "m_currentReviveCount");
		if(incap > 0)
			SetEntProp(client, Prop_Send, "m_currentReviveCount", incap - 1);
		
		g_iCureUsed[client] += 1;
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
		SetHealthBuffer(client, buffer);
	}
	
	if(g_iLevelAdrenaline[client] > 0 && duration > 0)
	{
		static ConVar adrenaline_duration;
		if(adrenaline_duration == null)
			adrenaline_duration = FindConVar("adrenaline_duration");
		
		UseAdrenaline(client, adrenaline_duration.IntValue + duration);
	}
	
	if(g_iLevelCure[client] >= 1 && g_iCureUsed[client] < g_iLevelCure[client] && GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1))
	{
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0, 1);
		int incap = GetEntProp(client, Prop_Send, "m_currentReviveCount");
		if(incap > 0)
			SetEntProp(client, Prop_Send, "m_currentReviveCount", incap - 1);
		
		g_iCureUsed[client] += 1;
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
		UseAdrenaline(subject, 5 * (g_iLevelMedical[subject] - 1));
	}
	if(g_iLevelMedical[client] >= 2)
	{
		UseAdrenaline(client, 5 * (g_iLevelMedical[client] - 1));
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
		UseAdrenaline(subject, 5 * (g_iLevelDefib[subject] - 2));
	}
	if(g_iLevelDefib[client] >= 3)
	{
		UseAdrenaline(client, 5 * (g_iLevelDefib[client] - 2));
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

public void Event_MapEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
		if(g_iLevelHealth[i] >= 1 && IsValidAliveClient(i) && GetClientTeam(i) == 2)
			GiveHealth(i);
}

public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	g_bGameStarted = true;
	
	for(int i = 1; i <= MaxClients; ++i)
		g_iCureUsed[i] = g_iIncapUsed[i] = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bGameStarted = false;
	
	for(int i = 1; i <= MaxClients; ++i)
		g_iCureUsed[i] = g_iIncapUsed[i] = 0;
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	// int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revivee = GetClientOfUserId(event.GetInt("subject"));
	bool hanging = event.GetBool("ledge_hang");
	bool dying = event.GetBool("lastlife");
	if(hanging || !IsValidAliveClient(revivee))
		return;
	
	int buffer = GetPlayerTempHealth(revivee);
	if(g_iLevelRevive[revivee] >= 1)
	{
		buffer += 20;
	}
	if(g_iLevelRevive[revivee] >= 2)
	{
		buffer += 30;
	}
	if(g_iLevelRevive[revivee] >= 3)
	{
		buffer += 20;
	}
	if(g_iLevelRevive[revivee] >= 4)
	{
		UseAdrenaline(revivee, 5 * (g_iLevelRevive[revivee] - 3));
	}
	
	if(g_iLevelRevive[revivee] >= 1 && buffer > 0)
	{
		SetHealthBuffer(revivee, buffer);
	}
	
	if(dying && g_iLevelIncapCount[revivee] >= 1 && g_iIncapUsed[revivee] < g_iLevelIncapCount[revivee])
	{
		SetEntProp(revivee, Prop_Send, "m_bIsOnThirdStrike", 0, 1);
		int incap = GetEntProp(revivee, Prop_Send, "m_currentReviveCount");
		if(incap > 0)
			SetEntProp(revivee, Prop_Send, "m_currentReviveCount", incap - 1);
		
		g_iIncapUsed[revivee] += 1;
	}
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	// int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(victim))
		return;
	
	// 为了和坦克拍倒幸存者时可以拍飞兼容
	if(g_iLevelIncapHealth[victim] >= 1)
		RequestFrame(OnPlayerIncapEnded, victim);
}

public void OnMapEnd()
{
	g_bGameStarted = false;
}

public void OnMapStart()
{
	g_bGameStarted = false;
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

public void GiveHealth(any client)
{
	SetEntProp(client, Prop_Data, "m_iHealth", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
	SetHealthBuffer(client, 0);
}

void SetHealthBuffer(int client, int amount)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", amount > 0.0 ? float(amount) : 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

public void OnPlayerIncapEnded(any client)
{
	if(!IsValidAliveClient(client) || g_iLevelIncapHealth[client] < 1)
		return;
	
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		int health = GetEntProp(client, Prop_Data, "m_iHealth");
		// int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		int amount = 50 * g_iLevelIncapHealth[client];
		SetEntProp(client, Prop_Data, "m_iHealth", health + amount);
		// SetEntProp(client, Prop_Data, "m_iMaxHealth", maxHealth + amount);
		// PrintToChat(client, "incap health %d", health + amount);
	}
	else
	{
		CreateTimer(0.25, Timer_PlayerIncapEnded, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_PlayerIncapEnded(Handle timer, any client)
{
	if(!IsValidAliveClient(client) || g_iLevelIncapHealth[client] < 1)
		return Plugin_Continue;
	
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		int health = GetEntProp(client, Prop_Data, "m_iHealth");
		// int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		int amount = 50 * g_iLevelIncapHealth[client];
		SetEntProp(client, Prop_Data, "m_iHealth", health + amount);
		// SetEntProp(client, Prop_Data, "m_iMaxHealth", maxHealth + amount);
		// PrintToChat(client, "incap2 health %d", health + amount);
	}
	else
	{
		PrintToServer("无法为 %N 设置倒地血量，因为他没有倒地。", client);
	}
	
	return Plugin_Continue;
}
