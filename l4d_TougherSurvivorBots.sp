#include <sourcemod> 
#include <sdkhooks> 

float sbDamageMult = 0.0;
float sbDamageSpecialMult = 0.0;
float sbDamageCommonMult = 0.0;

public Plugin:myinfo =  
{ 
    name = "幸存者机器人强化", 
    author = "xQd", 
    description = "Makes the survivor bots deal more damage against SIs and commons and be more resistant to damage.", 
    version = "1.3", 
    url = "https://forums.alliedmods.net/showpost.php?p=2547549&postcount=10" 
}; 

ConVar g_hDifficulty;
ConVar g_cvTsbEnable;

public OnPluginStart(){ 

	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("round_start", Event_RoundStart);
	
	g_hDifficulty = FindConVar("z_difficulty");
	if (g_hDifficulty != null)
	{
		g_hDifficulty.AddChangeHook(OnDifficultyCvarChange);
	}
	g_cvTsbEnable = CreateConVar("l4d_tsb_enable", "1", "1 = Enable Tougher Survivor Bots plugin effects, 0 = Disable the plugin's effects", _, true, 0.0, true, 1.0);
	
	SetMultipliersBasedOnDifficulty();
	
} 

public OnMapStart()
{
	SetMultipliersBasedOnDifficulty();
}

public OnClientPutInServer(client){ 
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage); 
} 

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (g_cvTsbEnable.IntValue > 0)
	{
		if(attacker > 0 && attacker <= MaxClients && IsClientConnected(attacker) && IsClientInGame(attacker) &&
			GetClientTeam(attacker) == 2 && IsFakeClient(attacker) &&
			GetEntProp(attacker, Prop_Send, "m_humanSpectatorUserID") < 1)
		{
			damage *= sbDamageSpecialMult; 
			return Plugin_Changed; 
		}
		if (victim > 0 && victim <= MaxClients && IsClientConnected(victim) && IsClientInGame(victim) &&
			GetClientTeam(victim) == 2 && IsFakeClient(victim) && !IsClientIncapacitated(victim) &&
			!(damagetype & DMG_BULLET) && GetEntProp(victim, Prop_Send, "m_humanSpectatorUserID") < 1) 
		{
			if (damagetype & DMG_BURN)
				damage /= 1.5;
			
			damage *= sbDamageMult;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue; 
}  

public Action Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{

	if (g_cvTsbEnable.IntValue > 0)
	{
		int attackerId = event.GetInt("attacker");
		int attacker = GetClientOfUserId(attackerId);
		//char name[64];
		//GetClientName(attacker, name, sizeof(name));
		if(attacker > 0 && attacker <= MaxClients && IsClientConnected(attacker) && IsClientInGame(attacker) &&
			GetClientTeam(attacker) == 2 && IsFakeClient(attacker) && GetEntProp(attacker, Prop_Send, "m_humanSpectatorUserID") < 1)
		{
			int amount = event.GetInt("amount");
			int client = event.GetInt("entityid");
			int cur_health = GetEntProp(client, Prop_Data, "m_iHealth");
			int dmg_health = RoundToNearest(cur_health - amount*sbDamageCommonMult);	
			if(cur_health > 0)
			{
				SetEntProp(client, Prop_Data, "m_iHealth", dmg_health);
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{

	PrintToServer("[l4d_TougherSurvivorBots] Round Start");
	SetMultipliersBasedOnDifficulty();
	
	return Plugin_Continue;
}

public void OnDifficultyCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{	
	SetMultipliersBasedOnDifficulty();
}	

public void SetMultipliersBasedOnDifficulty()
{
	char sDifficulty[128];
 
	g_hDifficulty.GetString(sDifficulty, 128);
 
	if (strcmp(sDifficulty, "easy", false) == 0)
	{
		PrintToServer("[l4d_TougherSurvivorBots] damage multipliers changed to easy mode.");
		sbDamageMult = 1.0
		sbDamageSpecialMult = 1.0
		sbDamageCommonMult = 1.25
	}
	else if (strcmp(sDifficulty, "normal", false) == 0)
	{
		PrintToServer("[l4d_TougherSurvivorBots] damage multipliers changed to normal mode.");
		sbDamageMult = 0.75
		sbDamageSpecialMult = 1.10
		sbDamageCommonMult = 1.50
	}
	else if (strcmp(sDifficulty, "hard", false) == 0)
	{
		PrintToServer("[l4d_TougherSurvivorBots] damage multipliers changed to advanced mode.");
		sbDamageMult = 0.50
		sbDamageSpecialMult = 1.20
		sbDamageCommonMult = 1.75
	}
	else if (strcmp(sDifficulty, "impossible", false) == 0)
	{
		PrintToServer("[l4d_TougherSurvivorBots] damage multipliers changed to expert mode.");
		sbDamageMult = 0.25
		sbDamageSpecialMult = 1.30
		sbDamageCommonMult = 2.0
	}
	else
	{
		PrintToServer("[l4d_TougherSurvivorBots] damage multipliers changed to normal mode.");
		sbDamageMult = 0.75
		sbDamageSpecialMult = 1.10
		sbDamageCommonMult = 1.50
	}
}

public bool:IsClientIncapacitated(client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0 || GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0;
}