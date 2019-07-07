#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BaljeeT"
#define PLUGIN_VERSION "1.00"
#define PREFIX " \x01[SM]\x01"
#include <sourcemod>

#pragma newdecls required

bool nsenabled = false;

public Plugin myinfo = 
{
	name = "No-Spread Menu",
	author = PLUGIN_AUTHOR,
	description = "Menu of No-Spread",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/BaljeeTo/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_nospread", Command_I, ADMFLAG_GENERIC);
}


public Action Command_I(int client, int args)
{
	Menu menu = new Menu(MenuCallBack);
	menu.SetTitle("No-Spread Menu");
    	if (nsenabled == false)
    {
   	 menu.AddItem("on", "Enable");
   	 menu.AddItem("off", "Disable", ITEMDRAW_DISABLED);
	}
	else
	{
	menu.AddItem("on", "Enable", ITEMDRAW_DISABLED);
	menu.AddItem("off", "Disable");
	}
   	menu.ExitButton = true;
   	menu.Display(client, 200);
	
	return Plugin_Handled;
}

public int MenuCallBack(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{	
		char info[32];
		char name[32];
		GetClientName(param1, name, sizeof(name));		
		menu.GetItem(param2, info, sizeof(info));
		
		if(StrEqual(info, "on"))
		{	
			ServerCommand("weapon_accuracy_nospread 1");
			ServerCommand("weapon_debug_spread_gap 1");
			ServerCommand("weapon_recoil_decay2_exp 99999");
			ServerCommand("weapon_recoil_decay2_lin 99999");
			ServerCommand("weapon_recoil_scale 0");
			ServerCommand("weapon_recoil_suppression_shots 500");
			ServerCommand("weapon_recoil_view_punch_extra 0");
			PrintToChatAll("%s \x02%s\x01 \x06enabled No-Spread!", PREFIX, name);
			nsenabled = true;
		} else if(StrEqual(info, "off"))
		{
			ServerCommand("weapon_accuracy_nospread 0");
			ServerCommand("weapon_debug_spread_gap 0");
			ServerCommand("weapon_recoil_decay2_exp 0");
			ServerCommand("weapon_recoil_decay2_lin 0");
			ServerCommand("weapon_recoil_scale 0");
			ServerCommand("weapon_recoil_suppression_shots 0");
			ServerCommand("weapon_recoil_view_punch_extra 0");
			PrintToChatAll("%s \x02%s\x01 \x06disabled No-Spread!", PREFIX, name);
			nsenabled = false;
		}
	}
}