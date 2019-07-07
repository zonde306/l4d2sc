#include <sourcemod>
#include <sdktools>
#include <regex>
#include <nmrih_status>
#include <nmrih_point_store>
#include <nmrih>

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "信息查看商店",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
};

#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

Menu hMainMenu, hReviveMenu;
ConVar gCvarAllow, gCvarCostHealth, gCvarCostWeigth, gCvarCostStamina, gCvarCostBlood, gCvarCostToken, gCvarCostInfected,
	gCvarCostHeal, gCvarCostRest, gCvarCostWrap, gCvarCostVaccine, gCvarCostWash, gCvarMaxInv, gCvarMaxSta;

public OnPluginStart()
{
	CreateConVar("nmp_info_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllow = CreateConVar("nmp_info_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarCostHealth = CreateConVar("nmp_info_health", "2", "查看血量 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostWeigth = CreateConVar("nmp_info_weigth", "1", "查看重量 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostStamina = CreateConVar("nmp_info_stamina", "2", "查看体力 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostInfected = CreateConVar("nmp_info_infected", "2", "查看感染 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostBlood = CreateConVar("nmp_info_blood", "1", "武器血液 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostToken = CreateConVar("nmp_info_token", "255", "复活币 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostRest = CreateConVar("nmp_info_rest", "25", "恢复体力 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostWrap = CreateConVar("nmp_info_wrap", "95", "包扎伤口 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostHeal = CreateConVar("nmp_info_heal", "128", "恢复生命值 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostVaccine = CreateConVar("nmp_info_vaccine", "165", "治疗感染 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	gCvarCostWash = CreateConVar("nmp_info_wash", "10", "清洗武器 需要多少硬币.-1=不允许", CVAR_FLAGS, true, -1.0);
	
	AutoExecConfig(true, "nmp_info_shop");
	
	HookConVarChange(gCvarCostHealth, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostWeigth, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostStamina, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostInfected, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostBlood, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostToken, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostRest, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostWrap, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostHeal, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostVaccine, HCVC_RebuildMenu);
	HookConVarChange(gCvarCostWash, HCVC_RebuildMenu);
	
	gCvarMaxInv = FindConVar("inv_maxcarry");
	gCvarMaxSta = FindConVar("sv_max_stamina");
	RegConsoleCmd("info", Cmd_ShowInfo, "显示信息");
	RegConsoleCmd("revive", Cmd_ReviveInfo, "显示信息");
	InitMenu();
	
	// CreateTimer(3.0, Timer_CreateMenu);
}

public void NMS_OnMenuBuilding(Menu menu)
{
	Timer_CreateMenu(INVALID_HANDLE, 0);
}

public Action Timer_CreateMenu(Handle timer, any data)
{
	NMS_AddMenuSelect("nmrih_info_show", "显示信息", MenuCallback_ShowInfo);
	NMS_AddMenuSelect("nmrih_info_change", "更改信息", MenuCallback_ChangeInfo);
	
	return Plugin_Continue;
}

public Action MenuCallback_ShowInfo(int client, int index, const char[] info, const char[] display)
{
	if(!NMS_IsClientValid(client) || index < 0 || !StrEqual(info, "nmrih_info_show", false))
		return Plugin_Continue;
	
	return (Cmd_ShowInfo(client, 0) == Plugin_Handled ? Plugin_Continue : Plugin_Handled);
}

public Action MenuCallback_ChangeInfo(int client, int index, const char[] info, const char[] display)
{
	if(!NMS_IsClientValid(client) || index < 0 || !StrEqual(info, "nmrih_info_show", false))
		return Plugin_Continue;
	
	return (Cmd_ReviveInfo(client, 0) == Plugin_Handled ? Plugin_Continue : Plugin_Handled);
}

public void HCVC_RebuildMenu(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	InitMenu();
}

public Action Cmd_ReviveInfo(int client, int args)
{
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client))
		return Plugin_Continue;
	
	hReviveMenu.SetTitle(tr("========= 功能菜单 =========\n\t*** 你有 %d 硬币 ***", NMS_GetCoin(client)));
	//hReviveMenu.Send(client, MenuFunc_ChangeInfo, MENU_TIME_FOREVER);
	hReviveMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Cmd_ShowInfo(int client, int args)
{
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client))
		return Plugin_Continue;
	
	hMainMenu.SetTitle(tr("========= 信息菜单 =========\n\t*** 你有 %d 硬币 ***", NMS_GetCoin(client)));
	//hMainMenu.Send(client, MenuFunc_ShowInfo, MENU_TIME_FOREVER);
	hMainMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

void InitMenu()
{
	/*
	hMainMenu = CreatePanel();
	hMainMenu.SetTitle("========= 信息菜单 =========");
	hMainMenu.DrawItem(fic("查看血量", gCvarCostHealth.IntValue));
	hMainMenu.DrawItem(fic("查看感染", gCvarCostInfected.IntValue));
	hMainMenu.DrawItem(fic("查看重量", gCvarCostWeigth.IntValue));
	hMainMenu.DrawItem(fic("查看体力", gCvarCostStamina.IntValue));
	hMainMenu.DrawItem(fic("查看血液", gCvarCostBlood.IntValue));
	hMainMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hMainMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hMainMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hMainMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hMainMenu.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	
	hReviveMenu = CreatePanel();
	hReviveMenu.SetTitle("========= 功能菜单 =========");
	hReviveMenu.DrawItem(fic("恢复生命", gCvarCostHeal.IntValue));
	hReviveMenu.DrawItem(fic("治疗感染", gCvarCostVaccine.IntValue));
	hReviveMenu.DrawItem(fic("包扎伤口", gCvarCostWrap.IntValue));
	hReviveMenu.DrawItem(fic("恢复体力", gCvarCostRest.IntValue));
	hReviveMenu.DrawItem(fic("清洗武器", gCvarCostWash.IntValue));
	hReviveMenu.DrawItem(fic("复活令牌", gCvarCostToken.IntValue));
	hReviveMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hReviveMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hReviveMenu.DrawItem("", ITEMDRAW_NOTEXT);
	hReviveMenu.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	*/
	
	hMainMenu = CreateMenu(MenuFunc_ShowInfo);
	hMainMenu.SetTitle("========= 信息菜单 =========");
	hMainMenu.AddItem("", fic("查看当前血量", gCvarCostHealth.IntValue));
	hMainMenu.AddItem("", fic("查看感染时间", gCvarCostInfected.IntValue));
	hMainMenu.AddItem("", fic("查看背包重量", gCvarCostWeigth.IntValue));
	hMainMenu.AddItem("", fic("查看体力剩余", gCvarCostStamina.IntValue));
	hMainMenu.AddItem("", fic("查看武器是否沾血", gCvarCostBlood.IntValue));
	hMainMenu.OptionFlags |= MENUFLAG_NO_SOUND;
	hMainMenu.ExitButton = true;
	
	hReviveMenu = CreateMenu(MenuFunc_ChangeInfo);
	hReviveMenu.SetTitle("========= 功能菜单 =========");
	hReviveMenu.AddItem("", fic("恢复生命", gCvarCostHeal.IntValue));
	hReviveMenu.AddItem("", fic("治疗感染", gCvarCostVaccine.IntValue));
	hReviveMenu.AddItem("", fic("包扎伤口", gCvarCostWrap.IntValue));
	hReviveMenu.AddItem("", fic("恢复体力", gCvarCostRest.IntValue));
	hReviveMenu.AddItem("", fic("清洗武器", gCvarCostWash.IntValue));
	hReviveMenu.AddItem("", fic("复活令牌", gCvarCostToken.IntValue));
	hReviveMenu.OptionFlags |= MENUFLAG_NO_SOUND;
	hReviveMenu.ExitButton = true;
}

public int MenuFunc_ChangeInfo(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
		return;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			NMS_GetSelectMenu().Display(client, MENU_TIME_FOREVER);
		
		return;
	}
	
	int cost = GetDisplayCost(menu, select);
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, menu);
	WritePackCell(data, menu.Selection);
	
	if(cost <= -1)
	{
		PrintToChat(client, "\x04[提示]\x01 这个物品暂时缺货！");
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	int money = NMS_GetCoin(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的硬币不足以购买它。现有：%d 需要：%d", money, cost);
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	int target = client;
	if(!IsPlayerAlive(target))
		target = GetClientAimTarget(client, true);
	if(!NMS_IsClientValid(target))
	{
		ReplyToCommand(client, "\x04[提示]\x01 目标无效。");
		return;
	}
	
	NMS_ChangeCoin(client, -cost);
	switch(select)
	{
		case 0:
		{
			SetEntProp(target, Prop_Data, "m_iHealth", GetEntProp(target, Prop_Data, "m_iMaxHealth"));
			PrintToChat(client, "\x04[提示]\x01 生命值恢复完毕。");
			SetEntProp(client, Prop_Send, "m_iHideHUD", 2050);
		}
		case 1:
		{
			SetPlayerPoisoned(target, false);
			SetPlayerInfectedTime(target, -1.0);
			SetPlayerInfectedDeathTime(target, -1.0);
			PrintToChat(client, "\x04[提示]\x01 感染治疗完毕。");
			SetEntProp(client, Prop_Send, "m_iHideHUD", 2050);
		}
		case 2:
		{
			SetPlayerLeedingOut(target, false);
			PrintToChat(client, "\x04[提示]\x01 伤口包扎完毕。");
			SetEntProp(client, Prop_Send, "m_iHideHUD", 2050);
		}
		case 3:
		{
			SetPlayerStamina(target, gCvarMaxSta.FloatValue);
			PrintToChat(client, "\x04[提示]\x01 体力恢复完毕。");
		}
		case 4:
		{
			SetPlayerBlood(target, false);
			
			int entity = -1;
			int len = GetEntPropArraySize(target, Prop_Send, "m_hMyWeapons");
			for(int i = 0; i < len; ++i)
			{
				//entity = GetEntDataEnt2(client, offs + i);
				entity = GetEntPropEnt(target, Prop_Send, "m_hMyWeapons", i);
				if(entity < MaxClients || !IsValidEntity(entity))
					continue;
				SetWeaponBlood(entity, false);
			}
			
			PrintToChat(client, "\x04[提示]\x01 武器清洗完毕。");
		}
		case 5:
		{
			SetPlayerRespawnCount(target, GetPlayerRespawnCount(target) + 1);
			PrintToChat(client, "\x04[提示]\x01 你获得了一个复活币。");
		}
	}
	
	CreateTimer(0.1, Timer_WaitDisplayMenu, data);
}

public int MenuFunc_ShowInfo(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
		return;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			NMS_GetSelectMenu().Display(client, MENU_TIME_FOREVER);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	int cost = GetDisplayCost(menu, select);
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, menu);
	WritePackCell(data, menu.Selection);
	
	if(cost <= -1)
	{
		PrintToChat(client, "\x04[提示]\x01 这个物品暂时缺货！");
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	int money = NMS_GetCoin(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的硬币不足以购买它。现有：%d 需要：%d", money, cost);
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	int target = client;
	if(!IsPlayerAlive(target))
		target = GetClientAimTarget(client, true);
	if(!NMS_IsClientValid(target))
	{
		ReplyToCommand(client, "\x04[提示]\x01 目标无效。");
		return;
	}
	
	NMS_ChangeCoin(client, -cost);
	switch(select)
	{
		case 0:
			PrintToChat(client, "\x04[提示]\x01 你的血量为：%d", GetEntProp(client, Prop_Data, "m_iHealth"));
		case 1:
		{
			if(GetPlayerImmunity(target))
				PrintToChat(client, "\x04[提示]\x01 你已经打过疫苗了，现在免疫感染。");
			else
			{
				float infTime = GetPlayerInfectedTime(target), dieTime = GetPlayerInfectedDeathTime(target);
				if(infTime <= -1.0 && dieTime <= -1.0)
					PrintToChat(client, "\x04[提示]\x01 你没有被感染！");
				else
				{
					PrintToChat(client, "\x04[提示]\x01 你现在已经被感染了 %.1f 秒。", infTime);
					PrintToChat(client, "\x04[提示]\x01 再过 %.1f 秒你就会因为感染而死亡。", dieTime);
				}
			}
		}
		case 2:
		{
			PrintToChat(client, "\x04[提示]\x01 负重上限：%d", gCvarMaxInv.IntValue);
			PrintToChat(client, "\x04[提示]\x01 你当前的负重：%d", GetPlayerWeigth(target));
		}
		case 3:
		{
			PrintToChat(client, "\x04[提示]\x01 体力上限：%.1f", gCvarMaxSta.FloatValue);
			PrintToChat(client, "\x04[提示]\x01 你当前的体力：%.1f", GetPlayerStamina(target));
		}
		case 4:
		{
			int entity = GetActiveWeapon(target);
			PrintToChat(client, "\x04[提示]\x01 你的手上 %s有 血液。", (GetPlayerBlood(target) ? "沾" : "没"));
			PrintToChat(client, "\x04[提示]\x01 你的武器 %s有 血液。",
				(IsValidEntity(entity) && GetWeaponBlood(entity) ? "沾" : "没"));
		}
	}
	
	CreateTimer(0.1, Timer_WaitDisplayMenu, data);
}

public Action Timer_WaitDisplayMenu(Handle timer, any data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	Menu menu = ReadPackCell(data);
	int first = ReadPackCell(data);
	CloseHandle(data);
	
	if(!NMS_IsClientValid(client) || menu == INVALID_HANDLE || first < 0)
		return;
	
	char title[255], text[2][255];
	menu.GetTitle(title, 255);
	ExplodeString(title, "\n", text, 2, 255);
	TrimString(text[0]);
	menu.SetTitle(tr("%s\n\t*** 你有 %d 硬币 ***", text[0], NMS_GetCoin(client)));
	
	menu.DisplayAt(client, first, MENU_TIME_FOREVER);
}

stock int GetDisplayCost(Menu menu, int select)
{
	int match, cost = -1;
	char item[64], line[1024];
	menu.GetItem(select, item, 64, _, line, 1024);
	//PrintToServer("*debug* idx = %d | item = %s | title = %s", select, item, line);
	
	Regex re = CompileRegex("\\[.+\\]", PCRE_UTF8);
	match = re.Match(line);
	if(match > 0 && re.GetSubString(match - 1, line, 1024))
	{
		// 正则比 ExplodeString 要好
		ReplaceString(line, 1024, "[", "");
		ReplaceString(line, 1024, "]", "");
		TrimString(line);
		
		if(StrEqual(line, "免费", false))
			cost = 0;
		else if(StrEqual(line, "缺货", false))
			cost = -1;
		else
		{
			cost = StringToInt(line);
			if(cost <= 0)
			{
				PrintToServer("*debug* cost error: %s", line);
				cost = -1;
			}
		}
		
		//PrintToServer("*debug* sub string = %s", line);
	}
	
	//PrintToServer("*debug* match = %d", match);
	
	return cost;
}

stock char fic(const char[] text, int cost = -1)
{
	// 格式化显示物品和价格
	char line[255];
	if(cost < 0)
		Format(line, 255, "%s [缺货]", text);
	else if(cost == 0)
		Format(line, 255, "%s [免费]", text);
	else
		Format(line, 255, "%s [%d]", text, cost);
	
	return line;
}

stock char tr(const char[] text, any ...)
{
	char result[1024];
	VFormat(result, 1024, text, 2);
	return result;
}
