/* Plugin Template generated by Pawn Studio */
#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_framework>
#include "modules/l4d2ps.sp"

new IMPULS_FLASHLIGHT 						= 100;
new Float:PressTime[MAXPLAYERS+1];
 
new Mode; 
new bool:EnableSuvivor; 
new bool:EnableInfected; 
new Handle:l4d_nt_team;

public Plugin:myinfo = 
{
	name = "夜视仪",
	author = "Pan Xiaohai & Mr. Zero",
	description = "<- Description ->",
	version = "1.0",
	url = "<- URL ->"
}

int g_iSlotSpecial;
int g_iLevelNVG[MAXPLAYERS+1];

public OnPluginStart()
{
	RegConsoleCmd("sm_nightvision", sm_nightvision);
	l4d_nt_team = CreateConVar("l4d_nt_team", "1", " 0:disable, 1:enable for survivor and infected, 2:enable for survivor, 3:enable for infected ", FCVAR_PLUGIN);	
	AutoExecConfig(true, "l4d_nightvision"); 
	HookConVarChange(l4d_nt_team, ConVarChange);
	GetConVar();
	
	LoadTranslations("l4d2sf_night_vision.phrases.txt");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	
	g_iSlotSpecial = L4D2SF_RegSlot("special");
	L4D2SF_RegPerk(g_iSlotSpecial, "night_vision", 1, 25, 5, 2.0);
}

public Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "night_vision"))
		FormatEx(result, maxlen, "%T", "夜视仪", client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "night_vision"))
		FormatEx(result, maxlen, "%T", tr("夜视仪%d", IntBound(level, 1, 1)), client, level);
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "night_vision"))
		g_iLevelNVG[client] = level;
}

public void L4D2SF_OnLoad(int client)
{
	g_iLevelNVG[client] = L4D2SF_GetClientPerk(client, "night_vision");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelNVG[client] = L4D2SF_GetClientPerk(client, "night_vision");
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVar(); 
}
GetConVar()
{
	Mode=GetConVarInt(l4d_nt_team);
	EnableSuvivor=(Mode==1 || Mode==2);
	EnableInfected=(Mode==1 || Mode==3);
}
public Action:sm_nightvision(client,args)
{
	if(IsClientInGame(client))SwitchNightVision(client);
}
//code from "Block Flashlight",
public Action:OnPlayerRunCmd(client, &buttons, &impuls, Float:vel[3], Float:angles[3], &weapon)
{
	if(Mode==0 || g_iLevelNVG[client] < 1)return;	
	if(impuls==IMPULS_FLASHLIGHT)
	{
		new team=GetClientTeam(client);
		if(team==2 && EnableSuvivor )
		{		 	
			new Float:time=GetEngineTime();
			if(time-PressTime[client]<0.3)
			{
				SwitchNightVision(client); 				 
			}
			PressTime[client]=time; 
			 
		}	 
		if(team==3 && EnableInfected)
		{				
			new Float:time=GetEngineTime();
			if(time-PressTime[client]>0.1)
			{
				SwitchNightVision(client); 
			}
			PressTime[client]=time;			 
		}
	}
}
SwitchNightVision(client)
{
	new d=GetEntProp(client, Prop_Send, "m_bNightVisionOn");
	if(d==0)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn",1); 
		PrintHintText(client, "%T", "夜视仪开启", client);
		
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn",0);
		PrintHintText(client, "%T", "夜视仪关闭", client);	
	}

}
