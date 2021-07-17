#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <regex>

#define PLUGIN_VERSION			"0.0.1"
#include "modules/l4d2ps.sp"

public Plugin myinfo =
{
	name = "技能树(技能框架)",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

bool g_bLateLoad = false;
Database g_Database = null;
ConVar g_cvExpP, g_cvExpB, g_cvExpM, g_cvMaxLevel, g_cvMaxSklLevel, g_cvPoint, g_cvConnection;

public OnPluginStart()
{
	InitPlugin("sf");
	g_cvExpP = CreateConVar("l4d2_sf_exp_p", "1.95", "等级参数P(技能升级经验=M*技能等级^P+B)", CVAR_FLAGS, true, 0.0, true, 5.0);
	g_cvExpB = CreateConVar("l4d2_sf_exp_b", "75", "等级参数B(升级经验=M*上一级经验+B+M*等级)", CVAR_FLAGS, true, 0.0, true, 500.0);
	g_cvExpM = CreateConVar("l4d2_sf_exp_m", "25", "等级参数M(升级经验=M*上一级经验+B+M*等级)", CVAR_FLAGS, true, 0.0, true, 250.0);
	g_cvMaxLevel = CreateConVar("l4d2_sf_level_max", "100", "等级上限", CVAR_FLAGS, true, 0.0);
	g_cvMaxSklLevel = CreateConVar("l4d2_sf_skill_level_max", "100", "技能等级上限", CVAR_FLAGS, true, 0.0);
	g_cvPoint = CreateConVar("l4d2_sf_levelup_points", "1", "升级获得技能点数量", CVAR_FLAGS, true, 0.0);
	g_cvConnection = CreateConVar("l4d2_sf_db", "storage-local", "数据库连接名", CVAR_FLAGS);
	AutoExecConfig(true, "l4d2_skill_framework");
	
	OnConVarChanged_UpdateCache(null, "", "");
	g_cvExpP.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvExpB.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvExpM.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvMaxLevel.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvMaxSklLevel.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvPoint.AddChangeHook(OnConVarChanged_UpdateCache);
	g_cvConnection.AddChangeHook(OnConVarChanged_ConnectDatabase);
	
	// sm_admin 菜单
	TopMenu tm = GetAdminTopMenu();
	if(LibraryExists("adminmenu") && tm != null)
		OnAdminMenuReady(tm);
	
	LoadTranslations("l4d2_skill_framework.phrases.txt");
	LoadTranslations("core.phrases.txt");
	LoadTranslations("common.phrases.txt");
	
	if(g_bLateLoad)
		OnMapStart();
	
	RegConsoleCmd("sm_skill", Cmd_SkillMenu, "");
	
	HookEventEx("player_spawn", Event_PlayerSpawn);
	HookEventEx("player_first_spawn", Event_PlayerSpawn);
	HookEventEx("player_death", Event_PlayerDeath);
	HookEventEx("server_shutdown", Event_ServerShutdown, EventHookMode_PostNoCopy);
	HookEventEx("round_end", Event_ServerShutdown, EventHookMode_PostNoCopy);
	HookEventEx("map_transition", Event_ServerShutdown, EventHookMode_PostNoCopy);
	HookEventEx("mission_lost", Event_ServerShutdown, EventHookMode_PostNoCopy);
	// HookEventEx("round_start_pre_entity", Event_ServerShutdown, EventHookMode_PostNoCopy);
	// HookEventEx("round_start_post_nav", Event_ServerShutdown, EventHookMode_PostNoCopy);
	HookEventEx("finale_vehicle_leaving", Event_ServerShutdown, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	OnMapEnd();
}

int g_iExpP, g_iExpB, g_iExpM, g_iMaxLevel, g_iMaxSkill, g_iSkillPoint;

public void OnConVarChanged_UpdateCache(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iExpP = g_cvExpP.IntValue;
	g_iExpB = g_cvExpB.IntValue;
	g_iExpM = g_cvExpM.IntValue;
	g_iMaxLevel = g_cvMaxLevel.IntValue;
	g_iMaxSkill = g_cvMaxSklLevel.IntValue;
	g_iSkillPoint = g_cvPoint.IntValue;
}

public void OnConVarChanged_ConnectDatabase(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(g_Database != null)
		delete g_Database;
	g_Database = null;
	
	if(!SQL_CheckConfig(newValue))
		return;
	
	/*
	char error[255];
	// g_Database = SQL_Connect(newValue, true, error, sizeof(error));
	if(g_Database == null)
		LogError("[l4d2_skill_framework] 连接数据库 %s 失败：%s", newValue, error);
	*/
	
	Database.Connect(ConnectResult_Init, newValue);
}

public void ConnectResult_Init(Database db, const char[] error, any data)
{
	if(db != null)
	{
		char ident[8];
		db.Driver.GetIdentifier(ident, sizeof(ident));
		if(ident[0] == 'm')
		{
			db.SetCharset("utf8mb4");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_info (id int NOT NULL AUTO_INCREMENT, sid varchar(20) NOT NULL, level integer NOT NULL DEFAULT 0, experience integer NOT NULL DEFAULT 0, prevCap integer NOT NULL DEFAULT 0, points integer NOT NULL DEFAULT 0, PRIMARY KEY (id), UNIQUE INDEX sid_unique (sid))");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_slots (id int NOT NULL AUTO_INCREMENT, uid int NOT NULL, name varchar(64) NOT NULL, level integer NOT NULL DEFAULT 0, experience integer NOT NULL DEFAULT 0, PRIMARY KEY (id), UNIQUE INDEX unique_slot (uid, name), FOREIGN KEY (uid) REFERENCES l4d2sf_info (id) ON DELETE CASCADE ON UPDATE CASCADE)");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_perks (id int NOT NULL AUTO_INCREMENT, uid int NOT NULL, name varchar(64) NOT NULL, level integer NOT NULL DEFAULT 0, PRIMARY KEY (id), UNIQUE INDEX unique_perk (uid, name), FOREIGN KEY (uid) REFERENCES l4d2sf_info (id) ON DELETE CASCADE ON UPDATE CASCADE)");
		}
		else if(ident[0] == 's')
		{
			db.SetCharset("utf8");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_info (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sid CHAR(20) NOT NULL, level integer NOT NULL DEFAULT 0, experience integer NOT NULL DEFAULT 0, prevCap integer NOT NULL DEFAULT 0, points integer NOT NULL DEFAULT 0)");
			db.Query(QueryResult_Naked, "CREATE UNIQUE INDEX IF NOT EXISTS sid_unique ON l4d2sf_info (sid)");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_slots (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL, name CHAR(64) NOT NULL, level integer NOT NULL DEFAULT 0, experience integer NOT NULL DEFAULT 0, FOREIGN KEY (uid) REFERENCES l4d2sf_info (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED)");
			db.Query(QueryResult_Naked, "CREATE UNIQUE INDEX IF NOT EXISTS unique_slot ON l4d2sf_slots (uid, name)");
			db.Query(QueryResult_Naked, "CREATE TABLE IF NOT EXISTS l4d2sf_perks (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL, name CHAR(64) NOT NULL, level integer NOT NULL DEFAULT 0, FOREIGN KEY (uid) REFERENCES l4d2sf_info (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED)");
			db.Query(QueryResult_Naked, "CREATE UNIQUE INDEX IF NOT EXISTS skl_slot ON l4d2sf_perks (uid, name)");
		}
		
		g_Database = db;
	}
	else if(error[0] != EOS)
	{
		LogError("[l4d2_skill_framework] 连接数据库失败：%s", error);
	}
}

public void QueryResult_Naked(Database db, DBResultSet results, const char[] error, any data)
{
	
}

StringMap g_AllPerks, g_SlotPerks;
StringMap g_MenuData[MAXPLAYERS+1];
ArrayList g_SlotIndexes;

enum struct PerkData_t
{
	int maxLevel;
	int slot;
	int baseLevel;
	int baseSkillLevel;
	float levelFactor;
}

enum struct PlayerData_t
{
	int level;
	int experience;
	StringMap lvSkills;
	StringMap expSkills;
	StringMap perks;
	int prevCap;
	int points;
	
	void Reset()
	{
		this.level = 1;
		this.experience = 0;
		this.prevCap = g_iExpB;
		this.lvSkills = CreateTrie();
		this.expSkills = CreateTrie();
		this.perks = CreateTrie();
		
		char buffer[64];
		for(int i = 0; i < g_SlotIndexes.Length; ++i)
		{
			StringMap slot = g_SlotIndexes.Get(i);
			if(!slot.GetString("#slotName", buffer, sizeof(buffer)))
				continue;
			
			this.lvSkills.SetValue(buffer, 1);
			this.expSkills.SetValue(buffer, 0);
		}
	}
	
	int GetSklExp(int slotId)
	{
		char buffer[64] = "";
		SlotIdToSlotClassname(slotId, buffer, sizeof(buffer));
		if(buffer[0] == EOS)
			return 0;
		
		// 为避免技能槽位失踪，这里使用比较稳定的 name 作为 key
		int result = 0;
		if(!this.expSkills.GetValue(buffer, result))
			return 0;
		
		return result;
	}
	
	bool SetSklExp(int slotId, int value)
	{
		char buffer[64] = "";
		SlotIdToSlotClassname(slotId, buffer, sizeof(buffer));
		if(buffer[0] == EOS)
			return false;
		
		this.expSkills.SetValue(buffer, value);
		return true;
	}
	
	int GetSklLv(int slotId)
	{
		char buffer[64] = "";
		SlotIdToSlotClassname(slotId, buffer, sizeof(buffer));
		if(buffer[0] == EOS)
			return 1;
		
		// 为避免技能槽位失踪，这里使用比较稳定的 name 作为 key
		int result = 1;
		if(!this.lvSkills.GetValue(buffer, result))
			return 1;
		
		return result;
	}
	
	bool SetSklLv(int slotId, int value)
	{
		char buffer[64] = "";
		SlotIdToSlotClassname(slotId, buffer, sizeof(buffer));
		if(buffer[0] == EOS)
			return false;
		
		this.lvSkills.SetValue(buffer, value);
		return true;
	}
	
	int GetPerk(const char[] name)
	{
		int result = 0;
		if(!this.perks.GetValue(name, result))
			return 0;
		
		return result;
	}
	
	bool SetPerk(const char[] name, int value)
	{
		PerkData_t data;
		if(!FindPerk(name, data))
			return false;
		
		if(value < 0)
			value = 0;
		else if(value > data.maxLevel)
			value = data.maxLevel;
		
		if(value == this.GetPerk(name))
			return false;
		
		if(value == 0)
			this.perks.Remove(name);
		else
			this.perks.SetValue(name, value);
		
		return true;
	}
}

enum PerkPerm_t
{
	NO_ACCESS = 0,			// 禁止访问
	CAN_VIEW = (1 << 0),	// 可以查看
	CAN_FETCH = (1 << 2),	// 可以选取
	FREE_FETCH = (1 << 3),	// 允许无限制选取
}

PlayerData_t g_PlayerData[MAXPLAYERS+1];

/*
********************************************
*                管理员菜单                *
********************************************
*/

public void OnAdminMenuReady(Handle tm)
{
	if(tm == null)
		return;
	
	TopMenuObject tmo = AddToTopMenu(tm, "l4d2sf_adminmenu", TopMenuObject_Category, TopMenuCategory_MainMenu, INVALID_TOPMENUOBJECT, "l4d2sf_adminmenu", ADMFLAG_GENERIC);
	if(tmo == INVALID_TOPMENUOBJECT)
		return;
	
	AddToTopMenu(tm, "l4d2sf_GiveExperience", TopMenuObject_Item, TopMenuItem_GiveExperience, tmo, "l4d2sf_GiveExperience", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sf_GiveSkillExperience", TopMenuObject_Item, TopMenuItem_GiveSkillExperience, tmo, "l4d2sf_GiveSkillExperience", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sf_GiveLevel", TopMenuObject_Item, TopMenuItem_GiveLevel, tmo, "l4d2sf_GiveLevel", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sf_GiveSkillLevel", TopMenuObject_Item, TopMenuItem_GiveSkillLevel, tmo, "l4d2sf_GiveSkillLevel", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sf_GivePoint", TopMenuObject_Item, TopMenuItem_GivePoint, tmo, "l4d2sf_GivePoint", ADMFLAG_CHEATS);
	AddToTopMenu(tm, "l4d2sf_GivePerk", TopMenuObject_Item, TopMenuItem_GivePerk, tmo, "l4d2sf_GivePerk", ADMFLAG_CHEATS);
}

public void TopMenuCategory_MainMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption || action == TopMenuAction_DisplayTitle)
		FormatEx(buffer, maxlength, "%T", "技能系统", client);
	
	// 希望这玩意不会泄漏吧。。。
	g_MenuData[client] = CreateTrie();
}

public void TopMenuItem_GiveExperience(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家经验", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveExperience);
	menu.SetTitle("%T", "给玩家经验-选择数量", client);
	menu.AddItem("10", "10");
	menu.AddItem("20", "20");
	menu.AddItem("50", "50");
	menu.AddItem("100", "100");
	menu.AddItem("200", "200");
	menu.AddItem("500", "500");
	menu.AddItem("1000", "1000");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GiveExperience(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	Menu menu2 = CreateMenu(MenuHandler_GiveExperience2);
	menu2.SetTitle("%T", "给玩家经验-选择目标", client, info);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GiveExperience2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	int target = GetClientOfUserId(StringToInt(info));
	int amount = 0;
	
	if(!IsValidClient(target) || !g_MenuData[client].GetValue("amount", amount) || !amount)
	{
		TopMenuItem_GiveExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GiveExperience(client, amount);
	return 0;
}

public void TopMenuItem_GiveSkillExperience(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家技能经验", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveSkillExperience);
	menu.SetTitle("%T", "给玩家技能经验-选择类型", client);
	
	char slotName[64];
	for(int i = 0; i < g_SlotIndexes.Length; ++i)
	{
		GetSlotName(client, i, slotName, sizeof(slotName));
		menu.AddItem(tr("%d", i), slotName);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GiveSkillExperience(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], display[64];
	menu.GetItem(selected, info, sizeof(info), _, display, sizeof(display));
	
	Menu menu2 = CreateMenu(MenuHandler_GiveSkillExperience2);
	menu2.SetTitle("%T", "给玩家技能经验-选择数量", client, display);
	menu2.AddItem("10", "10");
	menu2.AddItem("20", "20");
	menu2.AddItem("50", "50");
	menu2.AddItem("100", "100");
	menu2.AddItem("200", "200");
	menu2.AddItem("500", "500");
	menu2.AddItem("1000", "1000");
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("slot", StringToInt(info));
	g_MenuData[client].SetString("name", display);
	return 0;
}

public int MenuHandler_GiveSkillExperience2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveSkillExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], display[64];
	menu.GetItem(selected, info, sizeof(info));
	if(!g_MenuData[client].GetString("name", display, sizeof(display)))
		return 0;
	
	Menu menu2 = CreateMenu(MenuHandler_GiveSkillExperience3);
	menu2.SetTitle("%T", "给玩家技能经验-选择目标", client, display, info);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GiveSkillExperience3(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveSkillExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	int target = GetClientOfUserId(StringToInt(info));
	int slot;
	int amount = 0;
	
	if(!IsValidClient(target) ||
		!g_MenuData[client].GetValue("amount", amount) || !amount ||
		!g_MenuData[client].GetValue("slot", slot))
	{
		TopMenuItem_GiveSkillExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GiveSkillExperience(client, slot, amount);
	return 0;
}

public void TopMenuItem_GiveLevel(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家等级", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveLevel);
	menu.SetTitle("%T", "给玩家等级-选择数量", client);
	menu.AddItem("1", "1");
	menu.AddItem("2", "2");
	menu.AddItem("5", "5");
	menu.AddItem("10", "10");
	menu.AddItem("20", "20");
	menu.AddItem("50", "50");
	menu.AddItem("100", "100");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GiveLevel(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	Menu menu2 = CreateMenu(MenuHandler_GiveLevel2);
	menu2.SetTitle("%T", "给玩家等级-选择目标", client, info);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GiveLevel2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveLevel(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	int target = GetClientOfUserId(StringToInt(info));
	int amount = 0;
	
	if(!IsValidClient(target) || !g_MenuData[client].GetValue("amount", amount) || !amount)
	{
		TopMenuItem_GiveExperience(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GiveLevel(client, amount);
	return 0;
}

public void TopMenuItem_GiveSkillLevel(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家技能等级", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GiveSkillLevel);
	menu.SetTitle("%T", "给玩家技能等级-选择类型", client);
	
	char slotName[64];
	for(int i = 0; i < g_SlotIndexes.Length; ++i)
	{
		GetSlotName(client, i, slotName, sizeof(slotName));
		menu.AddItem(tr("%d", i), slotName);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GiveSkillLevel(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], display[64];
	menu.GetItem(selected, info, sizeof(info), _, display, sizeof(display));
	
	Menu menu2 = CreateMenu(MenuHandler_GiveSkillLevel2);
	menu2.SetTitle("%T", "给玩家技能等级-选择数量", client, display);
	menu2.AddItem("10", "1");
	menu2.AddItem("20", "2");
	menu2.AddItem("50", "5");
	menu2.AddItem("100", "10");
	menu2.AddItem("200", "20");
	menu2.AddItem("500", "50");
	menu2.AddItem("1000", "100");
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("slot", StringToInt(info));
	g_MenuData[client].SetString("name", display);
	return 0;
}

public int MenuHandler_GiveSkillLevel2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveSkillLevel(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], display[64];
	menu.GetItem(selected, info, 8);
	if(!g_MenuData[client].GetString("name", display, sizeof(display)))
		return 0;
	
	Menu menu2 = CreateMenu(MenuHandler_GiveSkillLevel3);
	menu2.SetTitle("%T", "给玩家技能等级-选择目标", client, display, info);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GiveSkillLevel3(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GiveSkillLevel(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, 8);
	
	int target = GetClientOfUserId(StringToInt(info));
	int slot;
	int amount = 0;
	
	if(!IsValidClient(target) ||
		!g_MenuData[client].GetValue("amount", amount) || !amount ||
		!g_MenuData[client].GetValue("slot", slot))
	{
		TopMenuItem_GiveSkillLevel(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GiveSkillLevel(client, slot, amount);
	return 0;
}

public void TopMenuItem_GivePoint(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家技能点", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GivePoint);
	menu.SetTitle("%T", "给玩家技能点-选择数量", client);
	menu.AddItem("1", "1");
	menu.AddItem("2", "2");
	menu.AddItem("5", "5");
	menu.AddItem("10", "10");
	menu.AddItem("20", "20");
	menu.AddItem("50", "50");
	menu.AddItem("100", "100");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GivePoint(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			GetAdminTopMenu().Display(client, TopMenuPosition_LastCategory);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	
	Menu menu2 = CreateMenu(MenuHandler_GivePoint2);
	menu2.SetTitle("%T", "给玩家技能点-选择目标", client, info);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GivePoint2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GivePoint(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, 8);
	
	int target = GetClientOfUserId(StringToInt(info));
	int amount = 0;
	
	if(!IsValidClient(target) || !g_MenuData[client].GetValue("amount", amount) || !amount)
	{
		TopMenuItem_GivePoint(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GivePoint(client, amount);
	return 0;
}

public void TopMenuItem_GivePerk(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "%T", "给玩家技能", client);
	if(action != TopMenuAction_SelectOption)
		return;
	
	Menu menu = CreateMenu(MenuHandler_GivePerk);
	menu.SetTitle("%T", "给玩家技能-选择类型", client);
	
	char slotName[64];
	for(int i = 0; i < g_SlotIndexes.Length; ++i)
	{
		GetSlotName(client, i, slotName, sizeof(slotName));
		menu.AddItem(tr("%d", i), slotName);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].Clear();
}

public int MenuHandler_GivePerk(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GivePerk(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[64], display[128];
	menu.GetItem(selected, info, sizeof(info), _, display, sizeof(display));
	
	Menu menu2 = CreateMenu(MenuHandler_GivePerk2);
	menu2.SetTitle("%T", "给玩家技能-选择技能", client, display);
	int slotId = StringToInt(info);
	g_MenuData[client].SetValue("slot", slotId);
	g_MenuData[client].SetString("slotName", display);
	
	StringMap perks = g_SlotIndexes.Get(slotId);
	StringMapSnapshot iter = perks.Snapshot();
	for(int i = 0; i < iter.Length; ++i)
	{
		iter.GetKey(i, info, sizeof(info));
		GetPerkName(client, info, 1, display, sizeof(display));
		menu2.AddItem(info, display);
	}
	
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	return 0;
}

public int MenuHandler_GivePerk2(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GivePerk(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[64], display[128];
	menu.GetItem(selected, info, sizeof(info), _, display, sizeof(display));
	
	Menu menu2 = CreateMenu(MenuHandler_GiveSkillLevel2);
	menu2.SetTitle("%T", "给玩家技能-选择数量", client, display);
	menu2.AddItem("10", "1");
	menu2.AddItem("20", "2");
	menu2.AddItem("50", "5");
	menu2.AddItem("100", "10");
	menu2.AddItem("200", "20");
	menu2.AddItem("500", "50");
	menu2.AddItem("1000", "100");
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetString("skill", info);
	g_MenuData[client].SetString("skillName", display);
	return 0;
}

public int MenuHandler_GivePerk3(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GivePerk(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], display[128];
	menu.GetItem(selected, info, sizeof(info));
	
	if(!g_MenuData[client].GetString("skillName", display, sizeof(display)))
		return 0;
	
	Menu menu2 = CreateMenu(MenuHandler_GivePerk4);
	menu2.SetTitle("%T", "给玩家技能-选择目标", client, display);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	g_MenuData[client].SetValue("amount", StringToInt(info));
	return 0;
}

public int MenuHandler_GivePerk4(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack && GetAdminTopMenu() != null)
			TopMenuItem_GivePerk(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8], name[64];
	menu.GetItem(selected, info, 8);
	
	int target = GetClientOfUserId(StringToInt(info));
	int amount = 0;
	
	if(!IsValidClient(target) ||
		!g_MenuData[client].GetValue("amount", amount) || !amount ||
		!g_MenuData[client].GetString("skill", name, sizeof(name)))
	{
		TopMenuItem_GivePerk(null, TopMenuAction_SelectOption, INVALID_TOPMENUOBJECT, client, "", 0);
		return 0;
	}
	
	GivePerk(client, name, amount);
	return 0;
}

/*
********************************************
*                 玩家菜单                 *
********************************************
*/

StringMap g_AccessCache[MAXPLAYERS+1];

void RefreshAccessCache(int client, bool force = false)
{
	if(!IsValidClient(client))
		return;
	
	if(g_AccessCache[client] != null && !force)
	{
		float time = 0.0;
		g_AccessCache[client].GetValue("#time", time);
		if(GetEngineTime() - time < 1.0)
			return;
	}
	
	g_AccessCache[client] = CreateTrie();
	
	char buffer[64];
	PerkData_t data;
	int level = g_PlayerData[client].level;
	int[] sklLevel = new int[g_SlotIndexes.Length];
	for(int i = 0; i < g_SlotIndexes.Length; ++i)
	{
		StringMap slot = g_SlotIndexes.Get(i);
		sklLevel[i] = g_PlayerData[client].GetSklLv(i);
		
		int count = 0, used = 0;
		StringMapSnapshot iter = slot.Snapshot();
		for(int j = 0; j < iter.Length; ++j)
		{
			iter.GetKey(j, buffer, sizeof(buffer));
			if(buffer[0] == '#')
				continue;
			
			PerkPerm_t perm = NO_ACCESS;
			int perkLevel = g_PlayerData[client].GetPerk(buffer);
			slot.GetArray(buffer, data, sizeof(data));
			if(data.baseLevel >= level && data.baseSkillLevel >= sklLevel[i])
			{
				perm |= CAN_VIEW;
				
				if(data.baseSkillLevel * data.levelFactor * (perkLevel + 1))
					perm |= CAN_FETCH;
			}
			
			perm = GetPerkAccess(client, i, buffer, perm);
			g_AccessCache[client].SetValue(buffer, perm);
			
			count += 1;
			if(perkLevel)	// 或者检查 perm
				used += 1;
		}
		
		g_AccessCache[client].SetValue(tr("#%d_count", i), count);
		g_AccessCache[client].SetValue(tr("#%d_used", i), used);
	}
	
	g_AccessCache[client].SetValue("#time", GetEngineTime());
}

public Action Cmd_SkillMenu(int client, int argc)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	ShowMainMenu(client);
	return Plugin_Continue;
}

void ShowMainMenu(int client)
{
	if(!IsValidClient(client))
		return;
	
	Menu menu = CreateMenu(MenuHandler_MainMenu);
	int level = g_PlayerData[client].level;
	int levelCap = g_iExpM * g_PlayerData[client].prevCap + g_iExpB * level;
	
	menu.SetTitle("%T", "主菜单", client,
		level,
		g_PlayerData[client].experience,
		levelCap,
		g_PlayerData[client].points
	);
	RefreshAccessCache(client);
	
	char slotName[64];
	for(int i = 0; i < g_SlotIndexes.Length; ++i)
	{
		int count = 0, used = 0;
		GetSlotName(client, i, slotName, sizeof(slotName));
		g_AccessCache[client].GetValue(tr("#%d_count", i), count);
		g_AccessCache[client].GetValue(tr("#%d_used", i), used);
		menu.AddItem(tr("%d", i), tr("%T", "技能分类项", client, g_PlayerData[client].GetSklLv(i), slotName, used, count));
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		// if(selected == MenuCancel_ExitBack)
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[8];
	menu.GetItem(selected, info, sizeof(info));
	ShowSlotMenu(client, StringToInt(info));
	return 0;
}

void ShowSlotMenu(int client, int slotId)
{
	if(!IsValidClient(client) || slotId < 0 || slotId >= g_SlotIndexes.Length)
		return;
	
	char buffer[64];
	GetSlotName(client, slotId, buffer, sizeof(buffer));
	
	Menu menu = CreateMenu(MenuHandler_SlotMenu);
	int sklLevel = g_PlayerData[client].GetSklLv(slotId);
	int sklCap = RoundFloat(g_iExpM * Pow(float(sklLevel), float(g_iExpP)) + g_iExpB);
	
	menu.SetTitle("%T", "技能菜单", client,
		buffer,
		g_PlayerData[client].level,
		sklLevel,
		g_PlayerData[client].GetSklExp(slotId),
		sklCap,
		g_PlayerData[client].points
	);
	
	PerkData_t data;
	char perkName[64];
	StringMap slot = g_SlotIndexes.Get(slotId);
	StringMapSnapshot iter = slot.Snapshot();
	for(int i = 0; i < iter.Length; ++i)
	{
		iter.GetKey(i, buffer, sizeof(buffer));
		if(buffer[0] == '#' || !FindPerk(buffer, data))
			continue;
		
		PerkPerm_t perm = NO_ACCESS;
		g_AccessCache[client].GetValue(buffer, perm);
		if(!(perm & (CAN_VIEW|FREE_FETCH)))
			continue;
		
		int perkLevel = g_PlayerData[client].GetPerk(buffer);
		GetPerkName(client, buffer, perkLevel, perkName, sizeof(perkName));
		menu.AddItem(buffer, tr("%T", "技能列表选项", client, perkName, perkLevel, data.maxLevel, (perm & (CAN_FETCH|FREE_FETCH)) ? "⭐" : ""));
	}
	
	if(menu.ItemCount <= 0)
		menu.AddItem("", tr("%T", "无选项", client), ITEMDRAW_DISABLED);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SlotMenu(Menu menu, MenuAction action, int client, int selected)
{
	if(action == MenuAction_End)
		return 0;
	if(action == MenuAction_Cancel)
	{
		if(selected == MenuCancel_ExitBack)
			ShowMainMenu(client);
		return 0;
	}
	if(action != MenuAction_Select)
		return 0;
	
	char info[64];
	menu.GetItem(selected, info, sizeof(info));
	ShowPerkMenu(client, info);
	return 0;
}

void ShowPerkMenu(int client, const char[] perk)
{
	if(!IsValidClient(client))
		return;
	
	PerkData_t data;
	if(!FindPerk(perk, data))
		return;
	
	int perkLevel = g_PlayerData[client].GetPerk(perk);
	Panel menu = CreatePanel();
	menu.SetTitle(tr("%T", "技能详情", client,
		g_PlayerData[client].level,
		g_PlayerData[client].GetSklLv(data.slot),
		g_PlayerData[client].GetSklExp(data.slot),
		g_PlayerData[client].points
	));
	
	char perkName[64], perkDesc[128];
	menu.DrawText("\n");
	
	if(perkLevel <= 0)
	{
		menu.DrawText(tr("%T", "当前：(无)", client));
	}
	else
	{
		GetPerkName(client, perk, perkLevel, perkName, sizeof(perkName));
		menu.DrawText(tr("%T", "当前：", client, perkName, perkLevel));
		
		GetPerkDescription(client, perk, perkLevel, perkDesc, sizeof(perkDesc));
		menu.DrawText(perkDesc);
	}
	
	menu.DrawText("\n");
	
	if(perkLevel < data.maxLevel)
	{
		GetPerkName(client, perk, perkLevel + 1, perkName, sizeof(perkName));
		menu.DrawText(tr("%T", "下一级：", client, perkName, perkLevel + 1));
		
		int level = g_PlayerData[client].level;
		int sklLevel = g_PlayerData[client].GetSklLv(data.slot);
		menu.DrawText(tr("%T", "要求：", client, data.baseLevel, level, data.baseSkillLevel * data.levelFactor * (perkLevel + 1), sklLevel));
		
		GetPerkDescription(client, perk, perkLevel + 1, perkDesc, sizeof(perkDesc));
		menu.DrawText(perkDesc);
	}
	
	menu.DrawText("\n");
	
	PerkPerm_t perm = NO_ACCESS;
	g_AccessCache[client].GetValue(perk, perm);
	
	if((perm & (CAN_FETCH|FREE_FETCH)) && g_PlayerData[client].points > 0)
		menu.DrawItem(tr("%T", "Yes", client), ITEMDRAW_DEFAULT);
	else
		menu.DrawItem(tr("%T", "Yes", client), ITEMDRAW_DISABLED);
	
	menu.DrawItem(tr("%T", "No", client), ITEMDRAW_DEFAULT);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem(tr("%T", "Back", client), ITEMDRAW_CONTROL);
	menu.DrawItem("", ITEMDRAW_IGNORE);
	menu.DrawItem(tr("%T", "Exit", client), ITEMDRAW_CONTROL);
	menu.Send(client, MenuHandler_PerkMenu, MENU_TIME_FOREVER);
	
	g_AccessCache[client].SetValue("#slotId", data.slot);
	g_AccessCache[client].SetString("#perk", perk);
}

public int MenuHandler_PerkMenu(Menu menu, MenuAction action, int client, int selected)
{
	if(action != MenuAction_Select)
		return 0;
	
	switch(selected)
	{
		case 1:
		{
			char perk[64];
			g_AccessCache[client].GetString("#perk", perk, sizeof(perk));
			
			if(g_PlayerData[client].points > 0)
			{
				g_PlayerData[client].points -= 1;
				GivePerk(client, perk, 1);
				RefreshAccessCache(client, true);
			}
			
			ShowPerkMenu(client, perk);
		}
		case 2, 8:
		{
			int slotId = -1;
			if(g_AccessCache[client].GetValue("#slotId", slotId))
				ShowSlotMenu(client, slotId);
		}
	}
	
	return 0;
}

/*
********************************************
*                 玩家数据                 *
********************************************
*/

int g_iUserId[MAXPLAYERS+1];
StringMap g_UserSlotId[MAXPLAYERS+1], g_UserPerkId[MAXPLAYERS+1];

void LoadPlayerData(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	g_iUserId[client] = 0;
	g_UserSlotId[client] = CreateTrie();
	g_UserPerkId[client] = CreateTrie();
	
	char sid[20];
	if(!GetClientAuthId(client, AuthId_Steam2, sid, sizeof(sid), true))
		return;
	
	g_Database.Escape(sid, sid, sizeof(sid));
	
	char ident[8];
	g_Database.Driver.GetIdentifier(ident, sizeof(ident));
	if(ident[0] == 'm')
	{
		g_Database.Query(QueryResult_LoadPlayerData, tr("SELECT id, level, experience, prevCap, points FROM l4d2sf_info WHERE sid = '%s'", sid), client);
	}
	else if(ident[0] == 's')
	{
		g_Database.Query(QueryResult_LoadPlayerData, tr("SELECT id, level, experience, prevCap, points FROM l4d2sf_info WHERE sid = '%s'", sid), client);
	}
}

void SavePlayerData(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	
	char sid[20];
	if(!GetClientAuthId(client, AuthId_Steam2, sid, sizeof(sid), true))
		return;
	
	g_Database.Escape(sid, sid, sizeof(sid));
	
	char ident[8];
	g_Database.Driver.GetIdentifier(ident, sizeof(ident));
	
	int uid = 0;
	int level = g_PlayerData[client].level;
	int experience = g_PlayerData[client].experience;
	int prevCap = g_PlayerData[client].prevCap;
	int points = g_PlayerData[client].points;
	
	if(!g_iUserId[client])
	{
		DBResultSet results = null;
		if(ident[0] == 'm')
		{
			SQL_Query(g_Database, tr("INSERT IGNORE INTO l4d2sf_info (sid) VALUES ('%s')", sid));
			results = SQL_Query(g_Database, tr("SELECT id FROM l4d2sf_info WHERE sid = '%s'", sid));
		}
		else if(ident[0] == 's')
		{
			SQL_Query(g_Database, tr("INSERT OR IGNORE INTO l4d2sf_info (sid) VALUES ('%s')", sid));
			results = SQL_Query(g_Database, tr("SELECT id FROM l4d2sf_info WHERE sid = '%s'", sid));
		}
		
		if(results == null || results.RowCount <= 0 || results.FieldCount <= 0 || !results.FetchRow())
		{
			LogError("[l4d2_skill_framework] 无法获取玩家 %N (%s) 的 uid。", client, sid);
			return;
		}
		
		uid = g_iUserId[client] = results.FetchInt(0);
	}
	else
	{
		uid = g_iUserId[client];
	}
	
	Transaction trans = SQL_CreateTransaction();
	
	if(ident[0] == 'm')
	{
		trans.AddQuery(tr("UPDATE l4d2sf_info SET level = %d, experience = %d, prevCap = %d, points = %d WHERE id = %d", level, experience, prevCap, points, uid));
	}
	else if(ident[0] == 's')
	{	
		trans.AddQuery(tr("UPDATE l4d2sf_info SET level = %d, experience = %d, prevCap = %d, points = %d WHERE id = %d", level, experience, prevCap, points, uid));
	}
	
	char name[64];
	StringMapSnapshot iter = g_PlayerData[client].lvSkills.Snapshot();
	for(int i = 0; i < iter.Length; ++i)
	{
		iter.GetKey(i, name, sizeof(name));
		
		int lv = 0, exp = 0;
		if(!g_PlayerData[client].lvSkills.GetValue(name, lv) || !g_PlayerData[client].expSkills.GetValue(name, exp))
			continue;
		
		if(!lv)
			continue;
		
		int id = 0;
		if(g_UserSlotId[client] && g_UserSlotId[client].GetValue(name, id) && id)
		{
			if(ident[0] == 'm')
			{
				trans.AddQuery(tr("UPDATE l4d2sf_slots SET level = %d, experience = %d WHERE id = %d", lv, exp, id));
			}
			else if(ident[0] == 's')
			{
				trans.AddQuery(tr("UPDATE l4d2sf_slots SET level = %d, experience = %d WHERE id = %d", lv, exp, id));
			}
		}
		else
		{
			g_Database.Escape(name, name, sizeof(name));
			
			if(ident[0] == 'm')
			{
				trans.AddQuery(tr("INSERT IGNORE INTO l4d2sf_slots (uid, name, level, experience) VALUES (%d, '%s', %d, %d)", uid, name, lv, exp));
			}
			else if(ident[0] == 's')
			{
				trans.AddQuery(tr("INSERT OR IGNORE INTO l4d2sf_slots (uid, name, level, experience) VALUES (%d, '%s', %d, %d)", uid, name, lv, exp));
			}
		}
	}
	
	iter = g_PlayerData[client].perks.Snapshot();
	for(int i = 0; i < iter.Length; ++i)
	{
		iter.GetKey(i, name, sizeof(name));
		
		int lv = 0;
		if(!g_PlayerData[client].perks.GetValue(name, lv))
			continue;
		
		if(!lv)
			continue;
		
		int id = 0;
		if(g_UserPerkId[client] && g_UserPerkId[client].GetValue(name, id) && id)
		{
			if(ident[0] == 'm')
			{
				trans.AddQuery(tr("UPDATE l4d2sf_perks SET level = %d WHERE id = %d", lv, id));
			}
			else if(ident[0] == 's')
			{
				trans.AddQuery(tr("UPDATE l4d2sf_perks SET level = %d WHERE id = %d", lv, id));
			}
		}
		else
		{
			g_Database.Escape(name, name, sizeof(name));
			
			if(ident[0] == 'm')
			{
				trans.AddQuery(tr("INSERT IGNORE INTO l4d2sf_perks (uid, name, level) VALUES (%d, '%s', %d)", uid, name, lv));
			}
			else if(ident[0] == 's')
			{
				trans.AddQuery(tr("INSERT OR IGNORE INTO l4d2sf_perks (uid, name, level) VALUES (%d, '%s', %d)", uid, name, lv));
			}
		}
	}
	
	g_Database.Execute(trans, QueryResults_SuccessNaked, QueryResults_FailedNaked, client);
}

public void QueryResult_LoadPlayerData(Database db, DBResultSet results, const char[] error, any client)
{
	if(results == null || results.RowCount != 1 || !results.FetchRow())
	{
		g_iUserId[client] = 0;
		return;
	}
	
	int id = results.FetchInt(0);
	g_PlayerData[client].level = results.FetchInt(1);
	g_PlayerData[client].experience = results.FetchInt(2);
	g_PlayerData[client].prevCap = results.FetchInt(3);
	g_PlayerData[client].points = results.FetchInt(4);
	g_iUserId[client] = id;
	
	char ident[8];
	db.Driver.GetIdentifier(ident, sizeof(ident));
	
	if(ident[0] == 'm')
	{
		db.Query(QueryResult_LoadPlayerSlots, tr("SELECT id, name, level, experience FROM l4d2sf_slots WHERE uid = %d", id), client);
		db.Query(QueryResult_LoadPlayerPerks, tr("SELECT id, name, level FROM l4d2sf_perks WHERE uid = %d", id), client);
	}
	else if(ident[0] == 's')
	{
		db.Query(QueryResult_LoadPlayerSlots, tr("SELECT id, name, level, experience FROM l4d2sf_slots WHERE uid = %d", id), client);
		db.Query(QueryResult_LoadPlayerPerks, tr("SELECT id, name, level FROM l4d2sf_perks WHERE uid = %d", id), client);
	}
	
	PrintToServer("读取 %d 信息完成", client);
}

public void QueryResult_LoadPlayerSlots(Database db, DBResultSet results, const char[] error, any client)
{
	if(results == null || results.RowCount <= 0 || !results.FetchRow())
		return;
	
	char name[64];
	
	do
	{
		results.FetchString(1, name, sizeof(name));
		g_PlayerData[client].lvSkills.SetValue(name, results.FetchInt(2));
		g_PlayerData[client].expSkills.SetValue(name, results.FetchInt(3));
		g_UserSlotId[client].SetValue(name, results.FetchInt(0));
	}
	while(results.FetchRow());
	
	PrintToServer("读取 %d 技能完成", client);
}

public void QueryResult_LoadPlayerPerks(Database db, DBResultSet results, const char[] error, any client)
{
	if(results == null || results.RowCount <= 0 || !results.FetchRow())
		return;
	
	char name[64];
	
	do
	{
		results.FetchString(1, name, sizeof(name));
		g_PlayerData[client].perks.SetValue(name, results.FetchInt(2));
		g_UserPerkId[client].SetValue(name, results.FetchInt(0));
	}
	while(results.FetchRow());
	
	PrintToServer("读取 %d 能力完成", client);
}

public void QueryResults_SuccessNaked(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	PrintToServer("玩家 %d 保存完成", data);
}

public void QueryResults_FailedNaked(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	PrintToServer("玩家 %d 保存失败：%s", data, error);
}

public void OnClientDisconnect(int client)
{
	SavePlayerData(client);
	g_PlayerData[client].Reset();
}

public void OnClientPutInServer(int client)
{
	g_iUserId[client] = 0;
	g_PlayerData[client].Reset();
	LoadPlayerData(client);
}

public void OnMapStart()
{
	if(g_Database == null)
	{
		char config[64];
		g_cvConnection.GetString(config, sizeof(config));
		OnConVarChanged_ConnectDatabase(g_cvConnection, "", config);
	}
	
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidClient(i))
			LoadPlayerData(i);
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidClient(i))
			SavePlayerData(i);
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	LoadPlayerData(client);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	SavePlayerData(client);
}

public void Event_ServerShutdown(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; ++i)
		if(IsValidClient(i))
			SavePlayerData(i);
}

/*
********************************************
*               玩家经验获得               *
********************************************
*/

bool GiveSkillExperience(int client, int slot, int amount)
{
	int lvSkill = g_PlayerData[client].GetSklLv(slot);
	int skillCap = RoundFloat(g_iExpM * Pow(float(lvSkill), float(g_iExpP)) + g_iExpB);
	if(!NotifySkillExperiencePre(client, slot, amount, skillCap))
		return false;
	
	// PrintToChat(client, "slot %d, exp %d/%d, lv %d", slot, amount, skillCap, lvSkill);
	int expSkill = g_PlayerData[client].GetSklExp(slot);
	g_PlayerData[client].SetSklExp(slot, expSkill += amount);
	
	if(expSkill >= skillCap && lvSkill < g_iMaxSkill)
	{
		if(GiveSkillLevel(client, slot, 1, expSkill - skillCap))
			GiveExperience(client, skillCap);
	}
	
	NotifySkillExperiencePost(client, slot, amount, skillCap);
	// PrintToServer("client %N skill %d experience %d of %d", client, slot, amount, skillCap);
	return true;
}

bool GiveSkillLevel(int client, int slot, int level, int remaining = 0)
{
	level += g_PlayerData[client].GetSklLv(slot);
	if(!NotifySkillLevelUpPre(client, slot, level, remaining))
		return false;
	
	// PrintToChat(client, "slot %d, lv %d, rem %d", slot, level, remaining);
	g_PlayerData[client].SetSklLv(slot, level);
	g_PlayerData[client].SetSklExp(slot, remaining);
	
	NotifySkillLevelUpPost(client, slot, level, remaining);
	// PrintToServer("client %N skill %d level %d remaining %d", client, slot, level, remaining);
	return true;
}

bool GiveExperience(int client, int amount)
{
	int level = g_PlayerData[client].level;
	int levelCap = g_iExpM * g_PlayerData[client].prevCap + g_iExpB * level;
	// int levelCap = RoundFloat(g_iExpM * Pow(float(level), float(g_iExpP)) + g_iExpB);
	if(!NotifyExperiencePre(client, amount, levelCap))
		return false;
	
	// PrintToChat(client, "exp %d/%d, lv %d", amount, levelCap, level);
	int experience = g_PlayerData[client].experience;
	g_PlayerData[client].experience = experience += amount;
	
	if(experience >= levelCap && level < g_iMaxLevel)
	{
		if(GiveLevel(client, 1, experience - levelCap))
			GivePoint(client, g_iSkillPoint);
	}
	
	NotifyExperiencePost(client, amount, levelCap);
	// PrintToServer("client %N experience %d of %d", client, experience, levelCap);
	return true;
}

bool GiveLevel(int client, int level, int remaining = 0)
{
	int nextLevel = g_PlayerData[client].level + level;
	if(!NotifyLevelUpPre(client, nextLevel, remaining))
		return false;
	
	// PrintToChat(client, "lv %d, rem %d", level, remaining);
	g_PlayerData[client].level = nextLevel;
	g_PlayerData[client].experience = remaining;
	
	int prevCap = g_iExpB;
	for(int i = 2; i <= nextLevel; ++i)
		prevCap = g_iExpM * prevCap + g_iExpB * i;
	g_PlayerData[client].prevCap = prevCap;
	// g_PlayerData[client].prevCap = RoundFloat(g_iExpM * Pow(float(nextLevel - 1), float(g_iExpP)) + g_iExpB);
	
	NotifyLevelUpPost(client, nextLevel, remaining);
	// PrintToServer("client %N level %d remaining %d", client, nextLevel, remaining);
	return true;
}

bool FindPerk(const char[] perk, PerkData_t data)
{
	return g_AllPerks.GetArray(perk, data, sizeof(data));
}

bool GivePerk(int client, const char[] perk, int level)
{
	char buffer[64];
	strcopy(buffer, sizeof(buffer), perk);
	if(!NotifyPerkPre(client, level, buffer, sizeof(buffer)))
		return false;
	
	// PrintToChat(client, "skill %s, lv %d", buffer, level);
	bool result = g_PlayerData[client].SetPerk(buffer, g_PlayerData[client].GetPerk(buffer) + level);
	
	NotifyPerkPost(client, level, buffer);
	
	// PrintToServer("client %N perk %s of %d", client, buffer, level);
	return result;
}

bool GivePoint(int client, int amount)
{
	if(!NotifyPointPre(client, amount))
		return false;
	
	// PrintToChat(client, "point %d", amount);
	g_PlayerData[client].points += amount;
	
	NotifyPointPost(client, amount);
	// PrintToServer("client %N points %d", client, amount);
	return true;
}

char SlotIdToSlotClassname(int slotId, char[] result, int maxlen)
{
	char buffer[64] = "";
	if(slotId < 0 || slotId >= g_SlotIndexes.Length)
		return buffer;
	
	StringMap slot = g_SlotIndexes.Get(slotId);
	if(!slot.GetString("#slotName", buffer, sizeof(buffer)))
		return buffer;
	
	strcopy(result, maxlen, buffer);
	return buffer;
}

int SlotClassnameToSlotId(const char[] classname)
{
	StringMap slot = null;
	if(!g_SlotPerks.GetValue(classname, slot))
		return -1;
	
	int slotId = -1;
	if(!slot.GetValue("#slotId", slotId))
		return -1;
	
	return slotId;
}

/*
********************************************
*               外部调用函数               *
********************************************
*/

GlobalForward g_fwSkillExperiencePre, g_fwSkillExperiencePost, g_fwExperiencePre, g_fwExperiencePost, g_fwSkillLevelUpPre, g_fwSkillLevelUpPost,
	g_fwLevelUpPre, g_fwLevelUpPost, g_fwPerkName, g_fwPerkDescription, g_fwPointPre, g_fwPointPost, g_fwCanAccessPerk, g_fwSlotName,
	g_fwPerkPre, g_fwPerkPost;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_skill_framework");
	
	g_AllPerks = CreateTrie();
	g_SlotPerks = CreateTrie();
	g_SlotIndexes = CreateArray();
	g_bLateLoad = late;
	
	// Action L4D2SF_OnSkillExperiencePre(int client, int& slotId, int& amount, int& cap)
	g_fwSkillExperiencePre = CreateGlobalForward("L4D2SF_OnSkillExperiencePre", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	// void L4D2SF_OnSkillExperiencePost(int client, int slotId, int amount, int cap)
	g_fwSkillExperiencePost = CreateGlobalForward("L4D2SF_OnSkillExperiencePost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	// Action L4D2SF_OnExperiencePre(int client, int& amount, int& cap)
	g_fwExperiencePre = CreateGlobalForward("L4D2SF_OnExperiencePre", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef);
	// void L4D2SF_OnExperiencePost(int client, int amount, int cap)
	g_fwExperiencePost = CreateGlobalForward("L4D2SF_OnExperiencePost", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	// Action L4D2SF_OnSkillLevelUpPre(int client, int& slotId, int& nextLevel, int& remaining)
	g_fwSkillLevelUpPre = CreateGlobalForward("L4D2SF_OnSkillLevelUpPre", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	// void L4D2SF_OnSkillLevelUpPost(int client, int slotId, int nextLevel, int remaining)
	g_fwSkillLevelUpPost = CreateGlobalForward("L4D2SF_OnSkillLevelUpPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	// Action L4D2SF_OnLevelUpPre(int client, int& nextLevel, int& remaining)
	g_fwLevelUpPre = CreateGlobalForward("L4D2SF_OnLevelUpPre", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef);
	// void L4D2SF_OnLevelUpPost(int client, int nextLevel, int remaining)
	g_fwLevelUpPost = CreateGlobalForward("L4D2SF_OnLevelUpPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	// Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
	g_fwPerkName = CreateGlobalForward("L4D2SF_OnGetPerkName", ET_Event, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);
	// Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
	g_fwPerkDescription = CreateGlobalForward("L4D2SF_OnGetPerkDescription", ET_Event, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);
	// Action L4D2SF_PointPre(int client, int& amount)
	g_fwPointPre = CreateGlobalForward("L4D2SF_PointPre", ET_Hook, Param_Cell, Param_CellByRef);
	// void L4D2SF_PointPost(int client, int amount)
	g_fwPointPost = CreateGlobalForward("L4D2SF_PointPost", ET_Ignore, Param_Cell, Param_Cell);
	// Action L4D2SF_CanAccessPerk(int client, int slotId, const char[] perk, int& result)
	g_fwCanAccessPerk = CreateGlobalForward("L4D2SF_CanAccessPerk", ET_Event, Param_Cell, Param_String, Param_CellByRef);
	// Action L4D2SF_OnGetSlotName(int client, int slotId, char[] result, int maxlen)
	g_fwSlotName = CreateGlobalForward("L4D2SF_OnGetSlotName", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	// Action L4D2SF_OnPerkPre(int client, int& level, char[] perk, int maxlen)
	g_fwPerkPre = CreateGlobalForward("L4D2SF_OnPerkPre", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Cell);
	// void L4D2SF_OnPerkPost(int client, int level, const char[] perk)
	g_fwPerkPost = CreateGlobalForward("L4D2SF_OnPerkPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	
	// int L4D2SF_RegSlot(const char[] name)
	CreateNative("L4D2SF_RegSlot", Native_RegSlot);
	// bool L4D2SF_RegPerk(int slotId, const char[] name, int maxLevel, int baseSkillLevel, int baseLevel, float factor)
	CreateNative("L4D2SF_RegPerk", Native_RegPerk);
	// bool L4D2SF_FindPerk(const char[] name, PerkData_t data)
	CreateNative("L4D2SF_FindPerk", Native_FindPerk);
	// bool L4D2SF_GivePerk(int client, const char[] name, int level)
	CreateNative("L4D2SF_GivePerk", Native_GivePerk);
	// int L4D2SF_GetClientPerk(int client, const char[] name)
	CreateNative("L4D2SF_GetClientPerk", Native_GetPerk);
	// void L4D2SF_GiveSkillExperience(int client, int slotId, int amount)
	CreateNative("L4D2SF_GiveSkillExperience", Native_GiveSkillExperience);
	// void L4D2SF_GiveExperience(int client, int amount)
	CreateNative("L4D2SF_GiveExperience", Native_GiveExperience);
	// int L4D2SF_GetSkillExperience(int client, int slotId)
	CreateNative("L4D2SF_GetSkillExperience", Native_GetSkillExperience);
	// int L4D2SF_GetExperience(int client)
	CreateNative("L4D2SF_GetExperience", Native_GetExperience);
	// int L4D2SF_GetSkillLevel(int client, int slotId)
	CreateNative("L4D2SF_GetSkillLevel", Native_GetSkillLevel);
	// int L4D2SF_GetLevel(int client)
	CreateNative("L4D2SF_GetLevel", Native_GetLevel);
	// int L4D2SF_GiveSkillLevel(int client, int slotId, int level)
	CreateNative("L4D2SF_GiveSkillLevel", Native_GiveSkillLevel);
	// int L4D2SF_GiveLevel(int client, int level)
	CreateNative("L4D2SF_GiveLevel", Native_GiveLevel);
	// StringMapSnapshot L4D2SF_GetAllPerks()
	CreateNative("L4D2SF_GetAllPerks", Native_GetAllPerks);
	// void L4D2SF_GivePoint(int client, int amount)
	CreateNative("L4D2SF_GivePoint", Native_GivePoint);
	// int L4D2SF_GetPoint(int client)
	CreateNative("L4D2SF_GetPoint", Native_GetPoint);
	// StringMapSnapshot L4D2SF_GetAllSlots()
	CreateNative("L4D2SF_GetAllSlots", Native_GetAllSlots);
	// int L4D2SF_SlotNameToSlotId(const char[] name)
	CreateNative("L4D2SF_SlotNameToSlotId", Native_FindSlotByName);
	// bool L4D2SF_SlotIdToSlotName(int slotId, char[] result, int maxlen)
	CreateNative("L4D2SF_SlotIdToSlotName", Native_FindSlotById);
	// bool L4D2SF_GetSlotName(int client, int slotId, char[] result, int maxlen)
	CreateNative("L4D2SF_GetSlotName", Native_GetSlotName);
	// bool L4D2SF_GetPerkName(int client, const char[] perk, char[] result, int maxlen, int level = 0)
	CreateNative("L4D2SF_GetPerkName", Native_GetPerkName);
	// bool L4D2SF_GetPerkDescription(int client, const char[] perk, char[] result, int maxlen, int level = 0)
	CreateNative("L4D2SF_GetPerkDescription", Native_GetPerkDescription);
	// PerkPerm_t L4D2SF_GetPerkAccess(int client, const char[] perk)
	CreateNative("L4D2SF_GetPerkAccess", Native_GetPerkAccess);
}

public any Native_RegSlot(Handle plugin, int argc)
{
	char name[255];
	GetNativeString(1, name, sizeof(name));
	
	/*
	static Regex re;
	if(re == null)
		re = CompileRegex("^[a-zA-Z0-9]+[a-zA-Z0-9_\\-]*[a-zA-Z0-9]+$", PCRE_CASELESS|PCRE_UTF8|PCRE_NOTEMPTY|PCRE_DOLLAR_ENDONLY);
	if(re.Match(name) < 1)
		return -1;
	*/
	
	StringMap slot;
	int slotId = -1;
	if(g_SlotPerks.GetValue(name, slot) && slot.GetValue("#slotId", slotId))
		return slotId;
	
	slot = CreateTrie();
	slot.SetValue("#slotId", slotId);
	slot.SetString("#slotName", name);
	
	slotId = g_SlotIndexes.Length;
	g_SlotIndexes.Push(slot);
	g_SlotPerks.SetValue(name, slot);
	
	return slotId;
}

public any Native_RegPerk(Handle plugin, int argc)
{
	char name[255];
	GetNativeString(2, name, sizeof(name));
	
	/*
	static Regex re;
	if(re == null)
		re = CompileRegex("^[a-zA-Z0-9]+[a-zA-Z0-9_\\-]*[a-zA-Z0-9]+$", PCRE_CASELESS|PCRE_UTF8|PCRE_NOTEMPTY|PCRE_DOLLAR_ENDONLY);
	if(re.Match(name) < 1)
		return false;
	*/
	
	PerkData_t data;
	if(FindPerk(name, data))
		return false;
	
	data.slot = GetNativeCell(1);
	if(data.slot < 0 || data.slot >= g_SlotIndexes.Length)
		return false;
	
	data.maxLevel = GetNativeCell(3);
	data.baseSkillLevel = GetNativeCell(4);
	data.baseLevel = GetNativeCell(5);
	data.levelFactor = GetNativeCell(6);
	
	g_AllPerks.SetArray(name, data, sizeof(data));
	
	// 这是 reference，所以不需要设置回去
	StringMap slot = g_SlotIndexes.Get(data.slot);
	slot.SetArray(name, data, sizeof(data));
	
	return true;
}

public any Native_FindPerk(Handle plugin, int argc)
{
	char name[255];
	GetNativeString(1, name, sizeof(name));
	
	PerkData_t data;
	if(FindPerk(name, data))
		return false;
	
	SetNativeArray(2, data, sizeof(data));
	return true;
}

public any Native_GivePerk(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int level = GetNativeCell(3);
	
	char name[255];
	GetNativeString(2, name, sizeof(name));
	
	return GivePerk(client, name, level);
}

public any Native_GetPerk(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	
	char name[255];
	GetNativeString(2, name, sizeof(name));
	
	return g_PlayerData[client].GetPerk(name);
}

public any Native_GiveSkillExperience(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	int amount = GetNativeCell(3);
	
	GiveSkillExperience(client, slot, amount);
}

public any Native_GiveExperience(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	
	GiveExperience(client, amount);
}

public any Native_GetSkillExperience(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	
	return g_PlayerData[client].GetSklExp(slot);
}

public any Native_GetExperience(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	
	return g_PlayerData[client].experience;
}

public any Native_GetSkillLevel(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	
	return g_PlayerData[client].GetSklLv(slot);
}

public any Native_GetLevel(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	
	return g_PlayerData[client].level;
}

public any Native_GiveSkillLevel(Handle plugin, any argc)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	int amount = GetNativeCell(3);
	int remaining = g_PlayerData[client].GetSklExp(slot);
	
	GiveSkillLevel(client, slot, amount, remaining);
}

public any Native_GiveLevel(Handle plugin, any argc)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	int remaining = g_PlayerData[client].experience;
	
	GiveLevel(client, amount, remaining);
}

public any Native_GetAllPerks(Handle plugin, any argc)
{
	return CloneHandle(g_AllPerks.Snapshot(), plugin);
}

public any Native_GivePoint(Handle plugin, any argc)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	
	GivePoint(client, amount);
}

public any Native_GetPoint(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	
	return g_PlayerData[client].points;
}

public any Native_GetAllSlots(Handle plugin, int argc)
{
	return CloneHandle(g_SlotPerks.Snapshot(), plugin);
}

public any Native_FindSlotByName(Handle plugin, int argc)
{
	char name[64];
	GetNativeString(1, name, sizeof(name));
	return SlotClassnameToSlotId(name);
}

public any Native_FindSlotById(Handle plugin, int argc)
{
	int slotId = GetNativeCell(1);
	
	char name[64];
	SlotIdToSlotClassname(slotId, name, sizeof(name));
	
	SetNativeString(2, name, GetNativeCell(3));
	return name[0] != EOS;
}

public any Native_GetSlotName(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int slotId = GetNativeCell(2);
	
	char name[128];
	GetSlotName(client, slotId, name, sizeof(name));
	
	SetNativeString(3, name, GetNativeCell(4), true);
	return name[0] != EOS;
}

public any Native_GetPerkName(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int level = GetNativeCell(5);
	
	char name[128];
	GetNativeString(2, name, sizeof(name));
	GetPerkName(client, name, level, name, sizeof(name));
	
	SetNativeString(3, name, GetNativeCell(4), true);
	return name[0] != EOS;
}

public any Native_GetPerkDescription(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int level = GetNativeCell(5);
	
	char name[128];
	GetNativeString(2, name, sizeof(name));
	GetPerkDescription(client, name, level, name, sizeof(name));
	
	SetNativeString(3, name, GetNativeCell(4), true);
	return name[0] != EOS;
}

public any Native_GetPerkAccess(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	
	char name[64];
	GetNativeString(2, name, sizeof(name));
	
	PerkData_t data;
	if(!FindPerk(name, data))
		return false;
	
	return GetPerkAccess(client, data.slot, name);
}

/*
********************************************
*               事件触发通知               *
********************************************
*/

bool NotifySkillExperiencePre(int client, int& slot, int& amount, int& cap)
{
	int cloneSlot = slot;
	int cloneAmount = amount;
	int cloneCap = cap;
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwSkillExperiencePre);
	Call_PushCell(client);
	Call_PushCellRef(cloneSlot);
	Call_PushCellRef(cloneAmount);
	Call_PushCellRef(cloneCap);
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifySkillExperiencePre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		// PrintToChat(client, "NotifySkillExperiencePre, state=%d, slot=%d|%d, amount=%d|%d, cap=%d|%d", state, slot, cloneSlot, amount, cloneAmount, cap, cloneCap);
		slot = cloneSlot;
		amount = cloneAmount;
		cap = cloneCap;
	}
	
	return true;
}

void NotifySkillExperiencePost(int client, int slot, int amount, int cap)
{
	Call_StartForward(g_fwSkillExperiencePost);
	Call_PushCell(client);
	Call_PushCell(slot);
	Call_PushCell(amount);
	Call_PushCell(cap);
	Call_Finish();
}

bool NotifyExperiencePre(int client, int& amount, int& cap)
{
	int cloneAmount = amount;
	int cloneCap = cap;
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwExperiencePre);
	Call_PushCell(client);
	Call_PushCellRef(cloneAmount);
	Call_PushCellRef(cloneCap);
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifyExperiencePre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		// PrintToChat(client, "NotifyExperiencePre, state=%d, amount=%d|%d, cap=%d|%d", state, amount, cloneAmount, cap, cloneCap);
		amount = cloneAmount;
		cap = cloneCap;
	}
	
	return true;
}

void NotifyExperiencePost(int client, int amount, int cap)
{
	Call_StartForward(g_fwExperiencePost);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_PushCell(cap);
	Call_Finish();
}

bool NotifySkillLevelUpPre(int client, int& slot, int& nextLevel, int& remaining)
{
	int cloneSlot = slot;
	int cloneNextLevel = nextLevel;
	int cloneRemaining = remaining;
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwSkillLevelUpPre);
	Call_PushCell(client);
	Call_PushCellRef(cloneSlot);
	Call_PushCellRef(cloneNextLevel);
	Call_PushCellRef(cloneRemaining);
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifySkillLevelUpPre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		// PrintToChat(client, "NotifySkillLevelUpPre, state=%d, slot=%d|%d, nextLevel=%d|%d, remaining=%d|%d", state, slot, cloneSlot, nextLevel, cloneNextLevel, remaining, cloneRemaining);
		slot = cloneSlot;
		nextLevel = cloneNextLevel;
		remaining = cloneRemaining;
	}
	
	return true;
}

void NotifySkillLevelUpPost(int client, int slot, int nextLevel, int remaining)
{
	Call_StartForward(g_fwSkillLevelUpPost);
	Call_PushCell(client);
	Call_PushCell(slot);
	Call_PushCell(nextLevel);
	Call_PushCell(remaining);
	Call_Finish();
}

bool NotifyLevelUpPre(int client, int& nextLevel, int& remaining)
{
	int cloneNextLevel = nextLevel;
	int cloneRemaining = remaining;
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwLevelUpPre);
	Call_PushCell(client);
	Call_PushCellRef(cloneNextLevel);
	Call_PushCellRef(cloneRemaining);
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifyLevelUpPre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		// PrintToChat(client, "NotifyLevelUpPre, state=%d, nextLevel=%d|%d, remaining=%d|%d", state, nextLevel, cloneNextLevel, remaining, cloneRemaining);
		nextLevel = cloneNextLevel;
		remaining = cloneRemaining;
	}
	
	return true;
}

void NotifyLevelUpPost(int client, int nextLevel, int remaining)
{
	Call_StartForward(g_fwLevelUpPost);
	Call_PushCell(client);
	Call_PushCell(nextLevel);
	Call_PushCell(remaining);
	Call_Finish();
}

bool NotifyPointPre(int client, int& amount)
{
	int cloneAmount = amount;
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwPointPre);
	Call_PushCell(client);
	Call_PushCellRef(cloneAmount);
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifyPointPre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		// PrintToChat(client, "NotifyPointPre, state=%d, amount=%d|%d", state, amount, cloneAmount);
		amount = cloneAmount;
	}
	
	return true;
}

void NotifyPointPost(int client, int amount)
{
	Call_StartForward(g_fwPointPost);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
}

bool GetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	Action state = Plugin_Changed;
	
	Call_StartForward(g_fwPerkName);
	Call_PushCell(client);
	Call_PushString(name);
	Call_PushCell(level);
	Call_PushStringEx(result, maxlen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	if(Call_Finish(state) != SP_ERROR_NONE)
		return false;
	
	return state == Plugin_Changed;
}

bool GetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	Action state = Plugin_Changed;
	
	Call_StartForward(g_fwPerkDescription);
	Call_PushCell(client);
	Call_PushString(name);
	Call_PushCell(level);
	Call_PushStringEx(result, maxlen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	if(Call_Finish(state) != SP_ERROR_NONE)
		return false;
	
	return state == Plugin_Changed;
}

PerkPerm_t GetPerkAccess(int client, int slot, const char[] perk, PerkPerm_t perm = (CAN_FETCH | CAN_VIEW))
{
	Action state = Plugin_Continue;
	
	Call_StartForward(g_fwCanAccessPerk);
	Call_PushCell(client);
	Call_PushCell(slot);
	Call_PushString(perk);
	Call_PushCellRef(perm);
	
	if(Call_Finish(state) != SP_ERROR_NONE || state == Plugin_Continue)
		return (CAN_FETCH | CAN_VIEW);
	
	if(state >= Plugin_Handled)
		return NO_ACCESS;
	
	return perm;
}

bool GetSlotName(int client, int slot, char[] result, int maxlen)
{
	Action state = Plugin_Changed;
	
	Call_StartForward(g_fwSlotName);
	Call_PushCell(client);
	Call_PushCell(slot);
	Call_PushStringEx(result, maxlen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	if(Call_Finish(state) != SP_ERROR_NONE)
		return false;
	
	return state == Plugin_Changed;
}

bool NotifyPerkPre(int client, int& level, char[] perk, int maxlen)
{
	int cloneLevel = level;
	char clonePerk[64];
	Action state = Plugin_Continue;
	strcopy(clonePerk, sizeof(clonePerk), perk);
	
	Call_StartForward(g_fwPerkPre);
	Call_PushCell(client);
	Call_PushCell(level);
	Call_PushStringEx(clonePerk, sizeof(clonePerk), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(clonePerk));
	if(Call_Finish(state) != SP_ERROR_NONE)
		state = Plugin_Continue;
	
	if(state >= Plugin_Handled)
	{
		// PrintToChat(client, "NotifyPerkPre, state=%d", state);
		return false;
	}
	
	if(state == Plugin_Changed)
	{
		level = cloneLevel;
		strcopy(perk, maxlen, clonePerk);
	}
	
	return true;
}

void NotifyPerkPost(int client, int level, const char[] perk)
{
	Call_StartForward(g_fwPerkPost);
	Call_PushCell(client);
	Call_PushCell(level);
	Call_PushString(perk);
	Call_Finish();
}
