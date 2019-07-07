#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "补给箱和医疗箱",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
};

#define MAX_INVENTORY		32
#define MAX_STATION			32
#define MAX_LOCATION		32
#define MAX_SUPPLY			32

#define MAX_RANDOM			64

#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define IsValidEntRef(%1)	(%1 > 0 && EntRefToEntIndex(%1) != INVALID_ENT_REFERENCE)
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define CMD_FLAGS			ADMFLAG_RCON|ADMFLAG_CHEATS

Panel pPosition, pAngles;
int iInventory[MAX_INVENTORY][2], iStation[MAX_STATION][2], iLocation[MAX_LOCATION][3], iSupply[MAX_SUPPLY][3];
ConVar	gCvarAllowInv, gCvarAllowSta, gCvarAllowLoc, gCvarRandInv, gCvarRandSta, gCvarRandLoc, gCvarHealth, gCvarMove, gCvarRoll,
		gCvarAllowSup, gCvarRandSup, gCvarCount, gCvarModel;

public OnPluginStart()
{
	CreateConVar("nmp_invsta_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllowInv = CreateConVar("nmp_inventory_enable", "1", "是否开启 补给箱", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarAllowSta = CreateConVar("nmp_station_enable", "1", "是否开启 医疗箱", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarAllowLoc = CreateConVar("nmp_location_enable", "1", "是否开启 医疗箱放置点", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarAllowSup = CreateConVar("nmp_supply_enable", "1", "是否开启 修复箱", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	gCvarRandInv = CreateConVar("nmp_inventory_rendom", "32", "补给箱 随机刷出的数量", CVAR_FLAGS, true, 0.0);
	gCvarRandSta = CreateConVar("nmp_station_rendom", "32", "医疗箱 随机刷出的数量", CVAR_FLAGS, true, 0.0);
	gCvarRandLoc = CreateConVar("nmp_location_rendom", "32", "放置点 随机刷出的数量", CVAR_FLAGS, true, 0.0);
	gCvarRandSup = CreateConVar("nmp_supply_rendom", "32", "修复箱 随机刷出的数量", CVAR_FLAGS, true, 0.0);
	
	gCvarHealth = CreateConVar("nmp_location_health", "300", "放置点 默认血量", CVAR_FLAGS, true, 0.0);
	gCvarCount = CreateConVar("nmp_supply_count", "10", "修复箱 默认数量", CVAR_FLAGS, true, 0.0);
	gCvarModel = CreateConVar("nmp_inventory_model", "models/items/ammocrate/ammocrate.mdl", "补给箱 的模型", CVAR_FLAGS);
	
	gCvarMove = CreateConVar("nmp_move_amount", "5", "移动位置 改变的范围", CVAR_FLAGS, true, 0.0);
	gCvarRoll = CreateConVar("nmp_roll_amount", "5", "旋转角度 改变的范围", CVAR_FLAGS, true, 0.0);
	
	AutoExecConfig(true, "nmp_inventory");
	HookConVarChange(gCvarMove, CVC_ReloadMenu);
	HookConVarChange(gCvarRoll, CVC_ReloadMenu);
	InitMoveMenu();
	
	RegAdminCmd("sm_bjx", Cmd_Inventory, CMD_FLAGS, "刷出一个临时的补给箱");
	RegAdminCmd("sm_bjxyc", Cmd_InventoryRemove, CMD_FLAGS, "移除一个补给箱");
	RegAdminCmd("sm_bjxbc", Cmd_InventorySave, CMD_FLAGS, "刷出并保存一个补给箱");
	RegAdminCmd("sm_bjxsc", Cmd_InventoryDelete, CMD_FLAGS, "删除保存的补给箱");
	RegAdminCmd("sm_bjxqc", Cmd_InventoryClean, CMD_FLAGS, "清除地图上所有的补给箱");
	RegAdminCmd("sm_bjxcz", Cmd_InventoryReload, CMD_FLAGS, "重置地图上所有的补给箱");
	
	RegAdminCmd("sm_ylx", Cmd_Station, CMD_FLAGS, "刷出一个临时的医疗箱");
	RegAdminCmd("sm_ylxyc", Cmd_StationRemove, CMD_FLAGS, "移除一个医疗箱");
	RegAdminCmd("sm_ylxbc", Cmd_StationSave, CMD_FLAGS, "刷出并保存一个医疗箱");
	RegAdminCmd("sm_ylxsc", Cmd_StationDelete, CMD_FLAGS, "删除保存的医疗箱");
	RegAdminCmd("sm_ylxqc", Cmd_StationClean, CMD_FLAGS, "清除地图上所有的医疗箱");
	RegAdminCmd("sm_ylxcz", Cmd_StationReload, CMD_FLAGS, "重置地图上所有的医疗箱");
	
	RegAdminCmd("sm_yld", Cmd_Location, CMD_FLAGS, "刷出一个临时的放置点");
	RegAdminCmd("sm_yldyc", Cmd_LocationRemove, CMD_FLAGS, "移除一个放置点");
	RegAdminCmd("sm_yldbc", Cmd_LocationSave, CMD_FLAGS, "刷出并保存一个放置点");
	RegAdminCmd("sm_yldsc", Cmd_LocationDelete, CMD_FLAGS, "删除保存的放置点");
	RegAdminCmd("sm_yldqc", Cmd_LocationClean, CMD_FLAGS, "清除地图上所有的放置点");
	RegAdminCmd("sm_yldcz", Cmd_LocationReload, CMD_FLAGS, "重置地图上所有的放置点");
	
	RegAdminCmd("sm_xfx", Cmd_Supply, CMD_FLAGS, "刷出一个临时的修复箱");
	RegAdminCmd("sm_xfxyc", Cmd_SupplyRemove, CMD_FLAGS, "移除一个修复箱");
	RegAdminCmd("sm_xfxbc", Cmd_SupplySave, CMD_FLAGS, "刷出并保存一个修复箱");
	RegAdminCmd("sm_xfxsc", Cmd_SupplyDelete, CMD_FLAGS, "删除保存的修复箱");
	RegAdminCmd("sm_xfxqc", Cmd_SupplyClean, CMD_FLAGS, "清除地图上所有的修复箱");
	RegAdminCmd("sm_xfxcz", Cmd_SupplyReload, CMD_FLAGS, "重置地图上所有的修复箱");
	
	RegAdminCmd("sm_ibp", Cmd_MoveEntity, CMD_FLAGS, "修改保存的位置");
	RegAdminCmd("sm_iba", Cmd_RollEntity, CMD_FLAGS, "修改保存的角度");
	
	HookEvent("nmrih_round_begin", Event_RoundStart);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("game_round_restart", Event_RoundStart);
}

public void OnMapStart()
{
	char mdl[255];
	gCvarModel.GetString(mdl, 255);
	if(mdl[0] != '\0')
		PrecacheModel(mdl);
}

public void Event_RoundStart(Event event, const char[] eventName, bool copy)
{
	if(gCvarAllowInv.IntValue > 0)
		ReloadEntity(1);
	if(gCvarAllowSta.IntValue > 0)
		ReloadEntity(2);
	if(gCvarAllowLoc.IntValue > 0)
		ReloadEntity(3);
	if(gCvarAllowSup.IntValue > 0)
		ReloadEntity(4);
}

public Action Cmd_InventoryReload(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(gCvarAllowInv.IntValue > 0)
		ReloadEntity(1);
	
	PrintToChat(client, "\x04[提示]\x01 重新加载完毕。");
	return Plugin_Handled;
}

public Action Cmd_StationReload(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(gCvarAllowSta.IntValue > 0)
		ReloadEntity(2);
	
	PrintToChat(client, "\x04[提示]\x01 重新加载完毕。");
	return Plugin_Handled;
}

public Action Cmd_LocationReload(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(gCvarAllowLoc.IntValue > 0)
		ReloadEntity(3);
	
	PrintToChat(client, "\x04[提示]\x01 重新加载完毕。");
	return Plugin_Handled;
}

public Action Cmd_SupplyReload(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(gCvarAllowSup.IntValue > 0)
		ReloadEntity(4);
	
	PrintToChat(client, "\x04[提示]\x01 重新加载完毕。");
	return Plugin_Handled;
}

public Action Cmd_MoveEntity(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	pPosition.Send(client, Menu_MoveEntity, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Cmd_RollEntity(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	pAngles.Send(client, Menu_MoveEntity, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void CVC_ReloadMenu(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	InitMoveMenu();
}

void InitMoveMenu()
{
	float move = gCvarMove.FloatValue, roll = gCvarRoll.FloatValue;
	pPosition = CreatePanel();
	pPosition.SetTitle("移动位置");
	pPosition.DrawItem(tr("横坐标 + %.1f", move));
	pPosition.DrawItem(tr("纵坐标 + %.1f", move));
	pPosition.DrawItem(tr("高度 + %.1f", move));
	pPosition.DrawItem(tr("横坐标 - %.1f", move));
	pPosition.DrawItem(tr("纵坐标 - %.1f", move));
	pPosition.DrawItem(tr("高度 - %.1f", move));
	pPosition.DrawItem("", ITEMDRAW_IGNORE);
	pPosition.DrawItem("", ITEMDRAW_IGNORE);
	pPosition.DrawItem("保存");
	pPosition.DrawItem("退出", ITEMDRAW_DISABLED);
	
	pAngles = CreatePanel();
	pAngles.SetTitle("改变角度");
	pAngles.DrawItem(tr("上下倾斜 + %.1f", roll));
	pAngles.DrawItem(tr("左右旋转 + %.1f", roll));
	pAngles.DrawItem(tr("左右倾斜 + %.1f", roll));
	pAngles.DrawItem(tr("上下倾斜 - %.1f", roll));
	pAngles.DrawItem(tr("左右旋转 - %.1f", roll));
	pAngles.DrawItem(tr("左右倾斜 - %.1f", roll));
	pAngles.DrawItem("", ITEMDRAW_IGNORE);
	pAngles.DrawItem("", ITEMDRAW_IGNORE);
	pAngles.DrawItem("保存");
	pAngles.DrawItem("退出", ITEMDRAW_DISABLED);
}

public int Menu_MoveEntity(Menu menu, MenuAction action, int client, int select)
{
	if(action != MenuAction_Select || !IsValidClient(client) || select == 10)
		return 0;
	
	bool move;
	char title[64];
	menu.GetTitle(title, 64);
	if(strcmp(title, "移动位置", false) == 0)
		move = true;
	else if(strcmp(title, "改变角度", false) == 0)
		move = false;
	else
	{
		PrintToChat(client, "\x04[提示]\x01 无效的选择。");
		//menu.Display(client, MENU_TIME_FOREVER);
		return 0;
	}
	
	int target = GetClientAimTarget(client, false);
	if(!IsValidEntity(target))
	{
		PrintToChat(client, "\x04[提示]\x01 你瞄准的目标无效。");
		menu.Display(client, MENU_TIME_FOREVER);
		return -1;
	}
	
	int idx = FindEntityByArray(target, iInventory, MAX_INVENTORY), mode = 1;
	if(idx == -1)
	{
		idx = FindEntityByArray(target, iStation, MAX_STATION);
		mode = 2;
	}
	if(idx == -1)
	{
		idx = FindEntityByArray(target, iLocation, MAX_LOCATION);
		mode = 3;
	}
	if(idx == -1)
	{
		idx = FindEntityByArray(target, iSupply, MAX_SUPPLY);
		mode = 4;
	}
	
	if(idx == -1 || mode == 0)
	{
		PrintToChat(client, "\x04[提示]\x01 你瞄准的物体不是保存的东西。");
		menu.Display(client, MENU_TIME_FOREVER);
		return 0;
	}
	
	if(select == 9)
	{
		SaveToFile(mode, idx);
		PrintToChat(client, "\x04[提示]\x01 保存完毕。");
		menu.Display(client, MENU_TIME_FOREVER);
		return 0;
	}
	
	float newVector[3], pos = gCvarMove.FloatValue, ang = gCvarRoll.FloatValue;
	if(move)
	{
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", newVector);
		switch(select)
		{
			case 1:		newVector[0] += pos;
			case 2:		newVector[1] += pos;
			case 3:		newVector[2] += pos;
			case 4:		newVector[0] -= pos;
			case 5:		newVector[1] -= pos;
			case 6:		newVector[2] -= pos;
		}
		SetEntPropVector(target, Prop_Send, "m_vecOrigin", newVector);
		PrintToChat(client, "\x04[提示]\x01 物体(%d)新的位置：X=%.2f|Y=%.2f|Z=%.2f", target, newVector[0], newVector[1], newVector[2]);
	}
	else
	{
		GetEntPropVector(target, Prop_Send, "m_angRotation", newVector);
		switch(select)
		{
			case 1:		newVector[0] += ang;
			case 2:		newVector[1] += ang;
			case 3:		newVector[2] += ang;
			case 4:		newVector[0] -= ang;
			case 5:		newVector[1] -= ang;
			case 6:		newVector[2] -= ang;
		}
		SetEntPropVector(target, Prop_Send, "m_angRotation", newVector);
		PrintToChat(client, "\x04[提示]\x01 物体(%d)新的角度：X=%.2f|Y=%.2f|Z=%.2f", target, newVector[0], newVector[1], newVector[2]);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	return 0;
}

public Action Cmd_SupplyClean(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	int entity, count = 0;
	for(int i = 0; i < MAX_STATION; i++)
	{
		entity = EntRefToEntIndex(iSupply[i][0]);
		if(IsValidEntRef(iSupply[i][0]) && IsValidEdict(entity))
		{
			count++;
			//RemoveEdict(entity);
			AcceptEntityInput(entity, "Kill");
		}
	}
	
	PrintToChat(client, "\x04[提示]\x01 成功删除 %d 个补给箱。", count);
	return Plugin_Handled;
}

public Action Cmd_SupplyDelete(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveFromFile(4, RemoveEntity(client, 4)))
		PrintToChat(client, "\x04[提示]\x01 成功删除保存的修复箱。");
	
	return Plugin_Handled;
}

public Action Cmd_SupplyRemove(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveEntity(client, 4) > -1)
		PrintToChat(client, "\x04[提示]\x01 成功删除修复箱。");
	
	return Plugin_Handled;
}

public Action Cmd_SupplySave(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	char value[16] = "0";
	if(args >= 1)
		GetCmdArg(1, value, 16);
	
	if(SaveToFile(4, SetupEntity(client, 4, StringToInt(value))))
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_Supply(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	char value[16] = "0";
	if(args >= 1)
		GetCmdArg(1, value, 16);
	
	if(SetupEntity(client, 4, StringToInt(value)) > MaxClients)
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_LocationClean(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	int entity, count = 0;
	for(int i = 0; i < MAX_STATION; i++)
	{
		entity = EntRefToEntIndex(iLocation[i][0]);
		if(IsValidEntRef(iLocation[i][0]) && IsValidEdict(entity))
		{
			count++;
			//RemoveEdict(entity);
			AcceptEntityInput(entity, "Kill");
		}
	}
	
	PrintToChat(client, "\x04[提示]\x01 成功删除 %d 个补给箱。", count);
	return Plugin_Handled;
}

public Action Cmd_LocationDelete(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveFromFile(3, RemoveEntity(client, 3)))
		PrintToChat(client, "\x04[提示]\x01 成功删除保存的补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_LocationRemove(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveEntity(client, 3) > -1)
		PrintToChat(client, "\x04[提示]\x01 成功删除补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_LocationSave(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	char value[16] = "0";
	if(args >= 1)
		GetCmdArg(1, value, 16);
	
	if(SaveToFile(3, SetupEntity(client, 3, StringToInt(value))))
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_Location(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	char value[16] = "0";
	if(args >= 1)
		GetCmdArg(1, value, 16);
	
	if(SetupEntity(client, 3, StringToInt(value)) > MaxClients)
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_StationClean(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	int entity, count = 0;
	for(int i = 0; i < MAX_STATION; i++)
	{
		entity = EntRefToEntIndex(iStation[i][0]);
		if(IsValidEntRef(iStation[i][0]) && IsValidEdict(entity))
		{
			count++;
			//RemoveEdict(entity);
			AcceptEntityInput(entity, "Kill");
		}
	}
	
	PrintToChat(client, "\x04[提示]\x01 成功删除 %d 个补给箱。", count);
	return Plugin_Handled;
}

public Action Cmd_StationDelete(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveFromFile(2, RemoveEntity(client, 2)))
		PrintToChat(client, "\x04[提示]\x01 成功删除保存的补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_StationRemove(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveEntity(client, 2) > -1)
		PrintToChat(client, "\x04[提示]\x01 成功删除补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_StationSave(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(SaveToFile(2, SetupEntity(client, 2)))
		PrintToChat(client, "\x04[提示]\x01 保存完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_Station(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(SetupEntity(client, 2) > MaxClients)
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_InventoryClean(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	int entity, count = 0;
	for(int i = 0; i < MAX_INVENTORY; i++)
	{
		entity = EntRefToEntIndex(iInventory[i][0]);
		if(IsValidEntRef(iInventory[i][0]) && IsValidEdict(entity))
		{
			count++;
			//RemoveEdict(entity);
			AcceptEntityInput(entity, "Kill");
		}
	}
	
	PrintToChat(client, "\x04[提示]\x01 成功删除 %d 个补给箱。", count);
	return Plugin_Handled;
}

public Action Cmd_InventoryDelete(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveFromFile(1, RemoveEntity(client, 1)))
		PrintToChat(client, "\x04[提示]\x01 成功删除保存的补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_InventoryRemove(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(RemoveEntity(client, 1) > -1)
		PrintToChat(client, "\x04[提示]\x01 成功删除补给箱。");
	
	return Plugin_Handled;
}

public Action Cmd_InventorySave(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(SaveToFile(1, SetupEntity(client, 1)))
		PrintToChat(client, "\x04[提示]\x01 保存完毕。");
	
	return Plugin_Handled;
}

public Action Cmd_Inventory(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	if(SetupEntity(client, 1) > MaxClients)
		PrintToChat(client, "\x04[提示]\x01 刷出完毕。");
	
	return Plugin_Handled;
}

bool RemoveFromFile(int mode, int idx)
{
	char path[255];
	GetFilePath(mode, path, 255);
	if(!FileExists(path))
		return false;
	
	KeyValues kv = CreateKeyValues("SpawnSaved");
	kv.ImportFromFile(path);
	int number = kv.GetNum("number", 0);
	if(number == 0)
	{
		kv.Close();
		return false;
	}
	
	int entity = 0, last = 0;
	switch(mode)
	{
		case 1:
		{
			entity = EntRefToEntIndex(iInventory[idx][0]);
			last = iInventory[idx][1];
			iInventory[idx][1] = 0;
			for(int i = idx; i < MAX_INVENTORY - 1; i++)
			{
				iInventory[idx][0] = iInventory[idx + 1][0];
				iInventory[idx][1] = iInventory[idx + 1][1];
			}
		}
		case 2:
		{
			entity = EntRefToEntIndex(iStation[idx][0]);
			last = iStation[idx][1];
			iStation[idx][1] = 0;
			for(int i = idx; i < MAX_STATION - 1; i++)
			{
				iStation[idx][0] = iStation[idx + 1][0];
				iStation[idx][1] = iStation[idx + 1][1];
			}
		}
		case 3:
		{
			entity = EntRefToEntIndex(iLocation[idx][0]);
			last = iLocation[idx][1];
			iLocation[idx][1] = 0;
			for(int i = idx; i < MAX_STATION - 1; i++)
			{
				iLocation[idx][0] = iLocation[idx + 1][0];
				iLocation[idx][1] = iLocation[idx + 1][1];
				iLocation[idx][2] = iLocation[idx + 1][2];
			}
		}
		case 4:
		{
			entity = EntRefToEntIndex(iSupply[idx][0]);
			last = iSupply[idx][1];
			iSupply[idx][1] = 0;
			for(int i = idx; i < MAX_SUPPLY - 1; i++)
			{
				iSupply[idx][0] = iSupply[idx + 1][0];
				iSupply[idx][1] = iSupply[idx + 1][1];
				iSupply[idx][2] = iSupply[idx + 1][2];
			}
		}
		default:
		{
			kv.Close();
			return false;
		}
	}
	
	if(last <= 0 || entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
	{
		kv.Close();
		return false;
	}
	
	float pos[3];
	char key[16];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	IntToString(last, key, 16);
	if(kv.JumpToKey(key, false))
		kv.DeleteThis();
	kv.Rewind();
	
	for(int i = last + 1; i <= number; i++)
	{
		IntToString(i, key, 16);
		if(!kv.JumpToKey(key, false))
			continue;
		
		IntToString(i - 1, key, 16);
		kv.SetSectionName(key);
		kv.Rewind();
	}
	
	kv.SetNum("number", number - 1);
	kv.ExportToFile(path);
	kv.Close();
	return true;
}

bool SaveToFile(int mode, int idx)
{
	if(idx <= -1)
		return false;
	
	char path[255];
	GetFilePath(mode, path, 255);
	if(!FileExists(path))
	{
		Handle file = OpenFile(path, "a+");
		WriteFileLine(file, "");
		CloseHandle(file);
	}
	
	KeyValues kv = CreateKeyValues("SpawnSaved");
	kv.ImportFromFile(path);
	int number = kv.GetNum("number", 0);
	
	int max = 0, entity = 0, last = 0;
	switch(mode)
	{
		case 1:
		{
			max = MAX_INVENTORY;
			entity = EntRefToEntIndex(iInventory[idx][0]);
			last = iInventory[idx][1];
			if(last <= 0)
			{
				iInventory[idx][1] = ++number;
				last = number;
			}
		}
		case 2:
		{
			max = MAX_STATION;
			entity = EntRefToEntIndex(iStation[idx][0]);
			last = iStation[idx][1];
			if(last <= 0)
			{
				iStation[idx][1] = ++number;
				last = number;
			}
		}
		case 3:
		{
			max = MAX_LOCATION;
			entity = EntRefToEntIndex(iLocation[idx][0]);
			last = iLocation[idx][1];
			if(last <= 0)
			{
				iLocation[idx][1] = ++number;
				last = number;
			}
		}
		case 4:
		{
			max = MAX_SUPPLY;
			entity = EntRefToEntIndex(iSupply[idx][0]);
			last = iSupply[idx][1];
			if(last <= 0)
			{
				iSupply[idx][1] = ++number;
				last = number;
			}
		}
		default:
		{
			kv.Close();
			return false;
		}
	}
	
	if(number >= max)
	{
		kv.Close();
		return false;
	}
	
	if(entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
	{
		kv.Close();
		return false;
	}
	
	float pos[3], ang[3];
	char key[16];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
	IntToString(last, key, 16);
	kv.JumpToKey(key, true);
	kv.SetNum("hammerId", GetEntProp(entity, Prop_Data, "m_iHammerID"));
	kv.SetVector("origin", pos);
	kv.SetVector("angles", ang);
	
	if(mode == 3)
		kv.SetNum("health", iLocation[idx][2]);
	
	if(mode == 4)
		kv.SetNum("count", iSupply[idx][2]);
	
	kv.Rewind();
	
	kv.SetNum("number", number);
	kv.ExportToFile(path);
	kv.Close();
	return true;
}

void GetFilePath(int mode, char[] path, int len)
{
	char map[64], dir[32];
	switch(mode)
	{
		case 1:		strcopy(dir, 32, "inventory");
		case 2:		strcopy(dir, 32, "station");
		case 3:		strcopy(dir, 32, "location");
		case 4:		strcopy(dir, 32, "supply");
		default:	return;
	}
	
	GetCurrentMap(map, 64);
	BuildPath(Path_SM, path, len, "data/box/%s/%s.conf", dir, map);
}

int FindEntityByArray(int entity, int[][] arr, int len)
{
	int ent = -1;
	for(int i = 0; i < len; i++)
	{
		ent = EntRefToEntIndex(arr[i][0]);
		if(ent != INVALID_ENT_REFERENCE && IsValidEntity(ent) && ent == entity)
			return i;
	}
	
	return -1;
}

int RemoveEntity(int client, int mode)
{
	int target = GetClientAimTarget(client, false);
	if(!IsValidEntity(target))
	{
		PrintToChat(client, "\x04[提示]\x01 你瞄准的目标无效。");
		return -1;
	}
	
	int idx = -1;
	switch(mode)
	{
		case 1:		idx = FindEntityByArray(target, iInventory, MAX_INVENTORY);
		case 2:		idx = FindEntityByArray(target, iStation, MAX_STATION);
		case 3:		idx = FindEntityByArray(target, iLocation, MAX_LOCATION);
		case 4:		idx = FindEntityByArray(target, iSupply, MAX_SUPPLY);
		default:
		{
			PrintToChat(client, "\x04[提示]\x01 无效的选择。");
			return -1;
		}
	}
	
	if(idx == -1)
	{
		PrintToChat(client, "\x04[提示]\x01 你瞄准的物体不是保存的东西。");
		return -1;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	switch(mode)
	{
		case 1:		entity = EntRefToEntIndex(iInventory[idx][0]);
		case 2:		entity = EntRefToEntIndex(iStation[idx][0]);
		case 3:		entity = EntRefToEntIndex(iLocation[idx][0]);
		case 4:		entity = EntRefToEntIndex(iSupply[idx][0]);
		default:
		{
			PrintToChat(client, "\x04[提示]\x01 无效的选择。");
			return -1;
		}
	}
	
	if(entity > 0 && entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
	{
		//RemoveEdict(entity);
		AcceptEntityInput(entity, "Kill");
	}
	
	switch(mode)
	{
		case 1:		iInventory[idx][0] = 0;
		case 2:		iStation[idx][0] = 0;
		case 3:		iLocation[idx][0] = 0;
		case 4:		iSupply[idx][0] = 0;
	}
	
	return idx;
}

int SetupEntity(int client = 0, int mode, int health = 0, float origin[3] = {0.0, 0.0, 0.0},
	float angles[3] = {0.0, 0.0 ,0.0}, int hammer = 0)
{
	int empty = -1
	switch(mode)
	{
		case 1:		empty = FindArrayEmpty(iInventory, MAX_INVENTORY);
		case 2:		empty = FindArrayEmpty(iStation, MAX_STATION);
		case 3:		empty = FindArrayEmpty(iLocation, MAX_LOCATION);
		case 4:		empty = FindArrayEmpty(iSupply, MAX_SUPPLY);
		default:
		{
			ReplyToCommand(client, "\x04[提示]\x01 无效的选择。");
			return -1;
		}
	}
	
	if(empty == -1)
	{
		ReplyToCommand(client, "\x04[提示]\x01 已经达到刷出上限，无法继续刷出。");
		return -1;
	}
	
	float pos[3], ang[3];
	
	if(IsValidClient(client))
	{
		if(!GetSpawnLocation(client, pos, ang))
		{
			ReplyToCommand(client, "\x04[提示]\x01 当前瞄准的位置无法刷出，请换一个位置。");
			return -1;
		}
	}
	else
	{
		pos[0] = origin[0];
		pos[1] = origin[1];
		pos[2] = origin[2];
		ang[0] = angles[0];
		ang[1] = angles[1];
		ang[2] = angles[2];
	}
	
	int entity = 0;
	switch(mode)
	{
		case 1:
		{
			pos[2] += 15.0;
			entity = CreateInventory(pos, ang);
		}
		case 2:		entity = CreateHealBox(pos, ang);
		case 3:		entity = CreateHealLocation(pos, ang, health);
		case 4:		entity = CreateSupply(pos, ang, health);
		default:
		{
			ReplyToCommand(client, "\x04[提示]\x01 无效的选择。");
			return -1;
		}
	}
	
	if(!IsValidEntity(entity))
	{
		ReplyToCommand(client, "\x04[提示]\x01 刷出失败，原因未知。");
		return -1;
	}
	
	switch(mode)
	{
		case 1:		iInventory[empty][0] = EntIndexToEntRef(entity);
		case 2:		iStation[empty][0] = EntIndexToEntRef(entity);
		case 3:
		{
			iLocation[empty][0] = EntIndexToEntRef(entity);
			if(health > 0)
				iLocation[empty][2] = health;
			else
				iLocation[empty][2] = gCvarHealth.IntValue;
		}
		case 4:
		{
			iSupply[empty][0] = EntIndexToEntRef(entity);
			if(health > 0)
				iSupply[empty][2] = health;
			else
				iSupply[empty][2] = gCvarCount.IntValue;
		}
		default:
		{
			PrintToChat(client, "\x04[提示]\x01 无效的选择。");
			return -1;
		}
	}
	
	if(hammer > 0)
		SetEntProp(entity, Prop_Data, "m_iHammerID", hammer);
	
	/*
	if(mode == 1)
	{
		char mdl[255];
		gCvarModel.GetString(mdl, 255);
		if(mdl[0] != '\0')
		{
			// SetEntityModel(entity, mdl);
			DispatchKeyValue(entity, "model", mdl);
			
			// 设置实体的碰撞
			SetEntPropVector(entity, Prop_Send, "m_vecMins", Float:{-28.22, -27.95, -16.25});
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", Float:{28.22, 27.95, 17.84});
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", -CG_PLAYER);
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", -CG_NPC);
			SetEntProp(entity, Prop_Send, "m_usSolidFlags", SF_TRIGGER);
			SetEntProp(entity, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
			
			SetEntProp(entity, Prop_Data, "m_iEFlags", GetEntProp(entity, Prop_Data, "m_iEFlags")|(1 << 14));
			SetEntPropFloat(entity, Prop_Data, "m_flRadius", 43.221553);
		}
	}
	*/
	
	return empty;
}

int FindArrayEmpty(int[][] arr, int len)
{
	for(int i = 0; i < len; i++)
	{
		if(arr[i][0] < MaxClients)
			return i;
	}
	
	return -1;
}

void ReloadEntity(int mode)
{
	char file[255], key[16];
	float angles[3], origin[3];
	KeyValues kv = CreateKeyValues("SpawnSaved");
	int entity, hammer, number, health, count, idx;
	switch(mode)
	{
		case 1:
		{
			for(int i = 0; i < MAX_INVENTORY; i++)
			{
				entity = EntRefToEntIndex(iInventory[idx][0]);
				if(IsValidEntRef(iInventory[idx][0]) && IsValidEntity(entity))
				{
					//RemoveEdict(entity);
					AcceptEntityInput(entity, "Kill");
				}
			}
			
			idx = 1;
			GetFilePath(1, file, 255);
			kv.ImportFromFile(file);
			number = kv.GetNum("number", 0);
			int rand[MAX_INVENTORY + 1];
			if(number > MAX_INVENTORY)
				number = MAX_INVENTORY;
			count = gCvarRandInv.IntValue;
			if(count == -1 || count > number)
				count = number;
			if(count != -1)
			{
				for(int i = 1; i <= count; i++)
					rand[i - 1] = i;
				
				SortIntegers(rand, number, Sort_Random);
				number = count;
			}
			for(int i = 1; i <= number; i++)
			{
				if(count != -1)
					idx = rand[i - 1];
				else
					idx = i;
				
				IntToString(idx, key, 16);
				if(!kv.JumpToKey(key, false))
					continue;
				
				hammer = kv.GetNum("hammerId", 0);
				kv.GetVector("origin", origin);
				kv.GetVector("angles", angles);
				kv.Rewind();
				
				SetupEntity(_, 1, _, origin, angles, hammer)
				PrintToServer("[箱子] 刷出补给箱在：X:%.2f|Y:%.2f|Z:%.2f", origin[0], origin[1], origin[2]);
			}
		}
		case 2:
		{
			for(int i = 0; i < MAX_STATION; i++)
			{
				entity = EntRefToEntIndex(iStation[idx][0]);
				if(IsValidEntRef(iStation[idx][0]) && IsValidEntity(entity))
				{
					//RemoveEdict(entity);
					AcceptEntityInput(entity, "Kill");
				}
			}
			
			idx = 1;
			GetFilePath(2, file, 255);
			kv.ImportFromFile(file);
			number = kv.GetNum("number", 0);
			int rand[MAX_STATION + 1];
			if(number > MAX_STATION)
				number = MAX_STATION;
			count = gCvarRandSta.IntValue;
			if(count == -1 || count > number)
				count = number;
			if(count != -1)
			{
				for(int i = 1; i <= count; i++)
					rand[i - 1] = i;
				
				SortIntegers(rand, number, Sort_Random);
				number = count;
			}
			for(int i = 1; i <= number; i++)
			{
				if(count != -1)
					idx = rand[i - 1];
				else
					idx = i;
				
				IntToString(idx, key, 16);
				if(!kv.JumpToKey(key, false))
					continue;
				
				hammer = kv.GetNum("hammerId", 0);
				kv.GetVector("origin", origin);
				kv.GetVector("angles", angles);
				kv.Rewind();
				
				SetupEntity(_, 2, _, origin, angles, hammer);
				PrintToServer("[箱子] 刷出医疗箱在：X:%.2f|Y:%.2f|Z:%.2f", origin[0], origin[1], origin[2]);
			}
		}
		case 3:
		{
			for(int i = 0; i < MAX_LOCATION; i++)
			{
				entity = EntRefToEntIndex(iLocation[idx][0]);
				if(IsValidEntRef(iLocation[idx][0]) && IsValidEntity(entity))
				{
					//RemoveEdict(entity);
					AcceptEntityInput(entity, "Kill");
				}
			}
			
			idx = 1;
			GetFilePath(3, file, 255);
			kv.ImportFromFile(file);
			number = kv.GetNum("number", 0);
			int rand[MAX_LOCATION + 1];
			if(number > MAX_LOCATION)
				number = MAX_LOCATION;
			count = gCvarRandLoc.IntValue;
			if(count == -1 || count > number)
				count = number;
			if(count != -1)
			{
				for(int i = 1; i <= count; i++)
					rand[i - 1] = i;
				
				SortIntegers(rand, number, Sort_Random);
				number = count;
			}
			for(int i = 1; i <= number; i++)
			{
				if(count != -1)
					idx = rand[i - 1];
				else
					idx = i;
				
				IntToString(idx, key, 16);
				if(!kv.JumpToKey(key, false))
					continue;
				
				health = kv.GetNum("health", 0);
				hammer = kv.GetNum("hammerId", 0);
				kv.GetVector("origin", origin);
				kv.GetVector("angles", angles);
				kv.Rewind();
				
				SetupEntity(_, 3, health, origin, angles, hammer);
				PrintToServer("[箱子] 刷出医疗点(%d)在：X:%.2f|Y:%.2f|Z:%.2f", health, origin[0], origin[1], origin[2]);
			}
		}
		case 4:
		{
			for(int i = 0; i < MAX_SUPPLY; i++)
			{
				entity = EntRefToEntIndex(iSupply[idx][0]);
				if(IsValidEntRef(iSupply[idx][0]) && IsValidEntity(entity))
				{
					//RemoveEdict(entity);
					AcceptEntityInput(entity, "Kill");
				}
			}
			
			idx = 1;
			GetFilePath(4, file, 255);
			kv.ImportFromFile(file);
			number = kv.GetNum("number", 0);
			int rand[MAX_SUPPLY + 1];
			if(number > MAX_SUPPLY)
				number = MAX_SUPPLY;
			count = gCvarRandSup.IntValue;
			if(count == -1 || count > number)
				count = number;
			if(count != -1)
			{
				for(int i = 1; i <= count; i++)
					rand[i - 1] = i;
				
				SortIntegers(rand, number, Sort_Random);
				number = count;
			}
			for(int i = 1; i <= number; i++)
			{
				if(count != -1)
					idx = rand[i - 1];
				else
					idx = i;
				
				IntToString(idx, key, 16);
				if(!kv.JumpToKey(key, false))
					continue;
				
				health = kv.GetNum("count", 0);
				hammer = kv.GetNum("hammerId", 0);
				kv.GetVector("origin", origin);
				kv.GetVector("angles", angles);
				kv.Rewind();
				
				SetupEntity(_, 4, health, origin, angles, hammer);
				PrintToServer("[箱子] 刷出修复箱(%d)在：X:%.2f|Y:%.2f|Z:%.2f", health, origin[0], origin[1], origin[2]);
			}
		}
	}
	
	kv.Close();
}

int CreateInventory(float pos[3], float ang[3])
{
	int ent = CreateEntityByName("item_inventory_box");
	DispatchKeyValueVector(ent, "origin", pos);
	DispatchKeyValueVector(ent, "angles", ang);
	// DispatchKeyValue(ent, "disableshadows", "1");
	
	char model[255];
	gCvarModel.GetString(model, 255);
	if(model[0] != '\0')
	{
		DispatchKeyValue(ent, "model", model);
		DispatchKeyValueFloat(ent, "modelscale", 1.0);
		
		SetEntPropVector(ent, Prop_Send, "m_vecMins", Float:{-28.22, -27.95, -16.25});
		SetEntPropVector(ent, Prop_Send, "m_vecMaxs", Float:{28.22, 27.95, 17.84});
		
		// AcceptEntityInput(ent, "DisableCollision", _, ent);
		// SetEntProp(ent, Prop_Send, "m_CollisionGroup", -CG_PLAYER);
		// SetEntProp(ent, Prop_Send, "m_CollisionGroup", -CG_NPC);
		// SetEntProp(ent, Prop_Send, "m_usSolidFlags", SF_TRIGGER);
		// SetEntProp(ent, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
		
		SetEntProp(ent, Prop_Data, "m_iEFlags", GetEntProp(ent, Prop_Data, "m_iEFlags")|(1 << 14));
		SetEntPropFloat(ent, Prop_Data, "m_flRadius", 43.221553);
	}
	
	DispatchSpawn(ent);
	return ent;
}

int CreateHealBox(float pos[3], float ang[3])
{
	int ent = CreateEntityByName("nmrih_health_station");
	DispatchKeyValueVector(ent, "origin", pos);
	DispatchKeyValueVector(ent, "angles", ang);
	
	DispatchSpawn(ent);
	return ent;
}

int CreateHealLocation(float pos[3], float ang[3], int health = 0)
{
	int ent = CreateEntityByName("nmrih_health_station_location");
	DispatchKeyValueVector(ent, "origin", pos);
	DispatchKeyValueVector(ent, "angles", ang);
	
	if(health > 0)
		SetEntPropFloat(ent, Prop_Send, "_health", float(health));
	else
		SetEntPropFloat(ent, Prop_Send, "_health", gCvarHealth.FloatValue);
	
	DispatchSpawn(ent);
	return ent;
}

int CreateSupply(float pos[3], float ang[3], int count = 0)
{
	int ent = CreateEntityByName("nmrih_safezone_supply");
	DispatchKeyValueVector(ent, "origin", pos);
	DispatchKeyValueVector(ent, "angles", ang);
	
	if(count > 0)
		SetEntProp(ent, Prop_Data, "_remainingUses", count);
	else
		SetEntProp(ent, Prop_Data, "_remainingUses", gCvarCount.IntValue);
	
	DispatchSpawn(ent);
	return ent;
}

char tr(char[] text, any ...)
{
	char result[1024];
	VFormat(result, 1024, text, 2);
	return result;
}

bool GetSpawnLocation(int client, float vPos[3], float vAng[3])
{
	float vAngles[3], vOrigin[3], vBuffer[3], vStart[3], Distance;

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TF_DonotHitPlayer);

	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(vStart, trace);
		Distance = -15.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		vPos[0] = vStart[0] + (vBuffer[0] * Distance);
		vPos[1] = vStart[1] + (vBuffer[1] * Distance);
		vPos[2] = vStart[2] + (vBuffer[2] * Distance);
		vPos[2] = GetGroundHeight(vPos);
		if(vPos[2] == 0.0)
		{
			CloseHandle(trace);
			return false;
		}

		vAng = vAngles;
		vAng[0] = 0.0;
		vAng[1] += 180.0;
		vAng[2] = 0.0;
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

float GetGroundHeight(float vPos[3])
{
	float vAng[3]
	Handle trace = TR_TraceRayFilterEx(vPos, Float:{90.0, 0.0, 0.0}, MASK_ALL, RayType_Infinite, TF_DonotHitPlayer);
	if(TR_DidHit(trace))
		TR_GetEndPosition(vAng, trace);
	CloseHandle(trace);
	return vAng[2];
}

public bool TF_DonotHitPlayer(int entity, int mask, any data)
{
	return (entity > MaxClients || entity <= 0);
}
