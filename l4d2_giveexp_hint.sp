#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "显示经验获得",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

float g_fShowDuration;
int g_iAllowDamageType, g_iMaxLine;
ArrayList g_hDamageMessage[MAXPLAYERS+1], g_hDamageTotal[MAXPLAYERS+1];
bool g_bAllowCommonDamage, g_bAllowCommonKilled, g_bAllowSpecialDamage, g_bAllowSpecialKilled, g_bAllowHealth;
ConVar g_pCvarCommonDamage, g_pCvarCommonKilled, g_pCvarSpecialDamage, g_pCvarSpecialKilled,
	g_pCvarDamageType, g_pCvarShowHealth, g_pCvarShowDuration, g_pCvarMaxLine;

public void OnPluginStart()
{
	InitPlugin("geh");
	g_pCvarCommonDamage = CreateConVar("l4d2_geh_common_damage", "1", "是否显示普感伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarCommonKilled = CreateConVar("l4d2_geh_common_killed", "1", "是否显示普感击杀", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSpecialDamage = CreateConVar("l4d2_geh_special_damage", "1", "是否显示特感伤害", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarSpecialKilled = CreateConVar("l4d2_geh_special_killed", "1", "是否显示特感击杀", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarShowHealth = CreateConVar("l4d2_geh_show_health", "1", "是否显示目标血量", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_pCvarShowDuration = CreateConVar("l4d2_geh_show_duration", "5.0", "显示保留时间", CVAR_FLAGS, true, 0.0, true, 60.0);
	g_pCvarMaxLine = CreateConVar("l4d2_geh_show_line", "5", "显示行数", CVAR_FLAGS, true, 1.0, true, 10.0);
	g_pCvarDamageType = CreateConVar("l4d2_geh_damage_type", "1652557767", "显示的伤害类型", CVAR_FLAGS);
	AutoExecConfig(true, "l4d2_sc_exp_hint");
	
	ConVarHooked_OnUpdateSetting(null, "", "");
	g_pCvarCommonDamage.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarCommonKilled.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarSpecialDamage.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarSpecialKilled.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarDamageType.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarShowHealth.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarShowDuration.AddChangeHook(ConVarHooked_OnUpdateSetting);
	g_pCvarMaxLine.AddChangeHook(ConVarHooked_OnUpdateSetting);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("infected_hurt", Event_InfectedHurt);
}

public void ConVarHooked_OnUpdateSetting(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_bAllowCommonDamage = g_pCvarCommonDamage.BoolValue;
	g_bAllowCommonKilled = g_pCvarCommonKilled.BoolValue;
	g_bAllowSpecialDamage = g_pCvarSpecialDamage.BoolValue;
	g_bAllowSpecialKilled = g_pCvarSpecialKilled.BoolValue;
	g_iAllowDamageType = g_pCvarDamageType.IntValue;
	g_bAllowHealth = g_pCvarShowHealth.BoolValue;
	g_fShowDuration = g_pCvarShowDuration.FloatValue;
	g_iMaxLine = g_pCvarMaxLine.IntValue;
}

public void Event_PlayerHurt(Event event, const char[] eventName, bool unknown)
{
	int damageType = event.GetInt("type");
	int damage = event.GetInt("dmg_health");
	if(!(damageType & g_iAllowDamageType) || damage <= 0)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker < 1 || victim < 1 || !IsClientInGame(attacker) || IsFakeClient(attacker) || !IsClientInGame(victim))
		return;
	
	bool death = (event.GetInt("health") <= 0);
	if(death)
	{
		if(!g_bAllowSpecialKilled)
			death = false;
	}
	if(!death)
	{
		if(!g_bAllowSpecialDamage)
			return;
	}
	
	ProccessDamageInfo(attacker, victim, damage, !!(damageType & DMG_BUCKSHOT),
		death, event.GetInt("hitgroup") == HITGROUP_HEAD);
}

public void Event_InfectedHurt(Event event, const char[] eventName, bool unknown)
{
	int damage = event.GetInt("amount");
	int damageType = event.GetInt("type");
	if(!(damageType & g_iAllowDamageType) || damage <= 0)
		return;
	
	int victim = event.GetInt("entityid");
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker < 1 || victim <= MaxClients || !IsClientInGame(attacker) || IsFakeClient(attacker) ||
		!IsValidEdict(victim) || !IsValidEntity(victim))
		return;
	
	bool death = (GetEntProp(victim, Prop_Data, "m_iHealth") - damage <= 0);
	if(death)
	{
		if(!g_bAllowCommonKilled)
			death = false;
	}
	if(!death)
	{
		if(!g_bAllowCommonDamage)
			return;
	}
	
	ProccessDamageInfo(attacker, victim, damage, !!(damageType & DMG_BUCKSHOT),
		death, event.GetInt("hitgroup") == HITGROUP_HEAD);
}

public void OnClientDisconnect_Post(int client)
{
	if(g_hDamageTotal[client] != null)
	{
		delete g_hDamageTotal[client];
		g_hDamageTotal[client] = null;
	}
	if(g_hDamageMessage[client] != null)
	{
		delete g_hDamageMessage[client];
		g_hDamageMessage[client] = null;
	}
}

void ProccessDamageInfo(int attacker, int victim, int damage, bool multiple, bool death, bool headshot)
{
	if(g_hDamageTotal[attacker] == null)
		g_hDamageTotal[attacker] = CreateArray(3);
	
	int state = 0;
	if(death)
		state |= 1;
	if(headshot)
		state |= 2;
	
	any data[3];
	data[0] = damage;
	data[1] = victim;
	data[2] = state;
	
	if(multiple)
	{
		int index = FindValueInArrayList(g_hDamageTotal[attacker], victim, 1);
		data[2] |= 4;
		
		if(index == -1)
		{
			g_hDamageTotal[attacker].PushArray(data, 3);
			RequestFrame(PaintDamageInfo, attacker);
		}
		else
		{
			g_hDamageTotal[attacker].GetArray(index, data, 3);
			data[0] += damage;
			data[2] |= state;
			g_hDamageTotal[attacker].SetArray(index, data, 3);
		}
	}
	else
	{
		g_hDamageTotal[attacker].PushArray(data, 3);
		PaintDamageInfo(attacker);
	}
}

public void PaintDamageInfo(any client)
{
	if(g_hDamageMessage[client] == null)
		g_hDamageMessage[client] = CreateArray(33);
	
	int maxLength, i;
	any data[3], msgData[33];
	float time = GetGameTime();
	char msg[32], healthMsg[32];
	if(g_hDamageTotal[client] != null && (maxLength = g_hDamageTotal[client].Length) > 0)
	{
		for(i = 0; i < maxLength; ++i)
		{
			g_hDamageTotal[client].GetArray(i, data, 3);
			if(g_bAllowHealth && !(data[2] & 1) && IsValidEdict(data[1]))
			{
				int health = GetEntProp(data[1], Prop_Data, "m_iHealth");
				if(!(data[2] & 4))
					health -= view_as<int>(data[0]);
				
				if(health > 0)
				{
					FormatEx(healthMsg, 32, " (%d/%d)", health,
						GetEntProp(data[1], Prop_Data, "m_iMaxHealth"));
				}
				else
				{
					healthMsg[0] = EOS;
				}
			}
			else
			{
				healthMsg[0] = EOS;
			}
			
			if((data[2] & 3) == 3)
				FormatEx(msg, 32, "－%d丨爆头", data[0]);
			else if(data[2] & 1)
				FormatEx(msg, 32, "－%d丨击杀", data[0]);
			else
				FormatEx(msg, 32, "－%d%s", data[0], healthMsg);
			
			CopyStrSafe(msgData, 32, msg, 32);
			msgData[32] = time + g_fShowDuration;
			g_hDamageMessage[client].PushArray(msgData, 33);
		}
		
		g_hDamageTotal[client].Clear();
	}
	
	maxLength = g_hDamageMessage[client].Length;
	for(i = 0; i < maxLength; ++i)
	{
		g_hDamageMessage[client].GetArray(i, msgData, 33);
		if(maxLength <= g_iMaxLine && view_as<float>(msgData[32]) > time)
			break;
		
		maxLength -= 1;
		g_hDamageMessage[client].Erase(i--);
	}
	
	char message[255];
	for(i = 0; i < maxLength; ++i)
	{
		g_hDamageMessage[client].GetArray(i, msgData, 33);
		StrCopySafe(msg, 32, msgData, 32);
		Format(message, 255, "%s%s%s", message, (i == 0 ? "" : "\n"), msg);
	}
	
	if(message[0] != EOS)
		PrintCenterText(client, message);
}

stock int StrCopySafe(char[] output, int outputMax, const any[] input, int inputMax)
{
	int i = 0;
	for(; i < outputMax && i < inputMax; ++i)
	{
		output[i] = view_as<char>(input[i]);
		if(output[i] == EOS)
			return i;
	}
	
	return i;
}

stock int CopyStrSafe(any[] output, int outputMax, const char[] input, int inputMax)
{
	int i = 0;
	for(; i < outputMax && i < inputMax; ++i)
	{
		output[i] = view_as<any>(input[i]);
		if(input[i] == EOS)
			return i;
	}
	
	return i;
}

stock int FindValueInArrayList(ArrayList array, any value, int slot)
{
	int maxLength = array.Length;
	any[] tmp = new any[slot + 1];
	for(int i = 0; i < maxLength; ++i)
	{
		array.GetArray(i, tmp, slot + 1);
		if(tmp[slot] == value)
			return i;
	}
	
	return -1;
}

public void SC_OnGainExperiencePost(int client, int amount)
{
	if(!IsPluginAllow())
		return;
	
	if(IsFakeClient(client) || !IsPlayerAlive(client))
		return;
	
	PrintCenterText(client, "＋%d", amount);
}
