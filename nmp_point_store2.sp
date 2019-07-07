#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <regex>
#include <nmrih_status>

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "积分商店 (数据库)",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
};

#define SQL_DRIV	"mysql"
#define SQL_DATA	"source_game"
#define SQL_HOST	"zonde306.site"
#define SQL_USER	"srcgame"
#define SQL_PASS	"abby6382"
#define SQL_PORT	"3306"

#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define MAX_MENU_ITEM			64

Database dbWeapon;
Panel hMenuMain, hMenuDeath;
StringMap tSell, tName, tWeigth, tRemainder;
int iAmmoCost[16] = {-1, ...}, iFuncCount = 0;
ArrayList aPluginList, aCallbackList, aKeepList;
float vecStart[2][3], vecDeath[MAXPLAYERS + 1][2][3];
Menu hMenuPistol, hMenuSMG, hMenuRifle, hMenuShotGun, hMenuSniper, hMenuMelee, hMenuTool, hMenuMedkit, hMenuGreande, hMenuAmmo,
	hMenuOther;
//static const char gPickupSound[3][] = {"player/ammo_pickup_01.wav", "player/ammo_pickup_02.wav", "player/ammo_pickup_03.wav"};
ConVar	gCvarAllow, gCvarCostRespawn[4];

public OnPluginStart()
{
	CreateConVar("nmp_ps2_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllow = CreateConVar("nmp_ps2_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	gCvarCostRespawn[0] = CreateConVar("nmp_ps2_respawn_start", "1250", "复活到出生点 多少硬币一次", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[1] = CreateConVar("nmp_ps2_respawn_death", "1620", "复活到死亡处 多少硬币一次", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[2] = CreateConVar("nmp_ps2_respawn_alive", "1950", "复活到队友旁 多少硬币一次", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[3] = CreateConVar("nmp_ps2_respawn_team", "998", "复活别人 多少硬币一次", CVAR_FLAGS, true, -1.0);
	
	AutoExecConfig(true, "nmp_point_shop2");
	RegConsoleCmd("buy", Cmd_BuyMenu, "买东西");
	RegConsoleCmd("ammo", Cmd_BuyAmmo, "买子弹");
	RegConsoleCmd("sell", Cmd_SellMenu, "卖东西");
	RegAdminCmd("rebuildshop", Cmd_RebulidShopMenu, ADMFLAG_RCON|ADMFLAG_CHEATS, "重建菜单");
	
	HookEvent("nmrih_round_begin", Event_RoundStart);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("game_round_restart", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	
	aPluginList = CreateArray();
	aCallbackList = CreateArray();
	aKeepList = CreateArray();
	
	//ConnectDataBase();
	InitAllMenu();
}

public void Event_RoundStart(Event event, const char[] eventName, bool copy)
{
	InitAllMenu();
	
	int client = GetRandomTeam(_, true);
	if(client <= 0)
		return;
	
	GetClientAbsOrigin(client, vecStart[0]);
	GetClientAbsAngles(client, vecStart[1]);
	
	PrintToServer("[商店] 出发点已重新加载。");
	PrintToServer("[商店] 位置：%.2f | %.2f | %.2f", vecStart[0][0], vecStart[0][1], vecStart[0][2]);
	PrintToServer("[商店] 角度：%.2f | %.2f | %.2f", vecStart[1][0], vecStart[1][1], vecStart[1][2]);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool copy)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!NMS_IsClientValid(client))
		return;
	
	GetClientAbsOrigin(client, vecDeath[client][0]);
	GetClientAbsAngles(client, vecDeath[client][1]);
	
	PrintToServer("[商店] 玩家 %N 的死亡点已更新。", client);
	PrintToServer("[商店] 位置：%.2f | %.2f | %.2f", vecDeath[client][0][0], vecDeath[client][0][1], vecDeath[client][0][2]);
	PrintToServer("[商店] 角度：%.2f | %.2f | %.2f", vecDeath[client][1][0], vecDeath[client][1][1], vecDeath[client][1][2]);
}

public void OnClientPutInServer(client)
{
	if(1 <= client <= MaxClients)
	{
		vecDeath[client][0] = NULL_VECTOR;
		vecDeath[client][1] = NULL_VECTOR;
	}
}

public void OnClientDisconnect(client)
{
	if(1 <= client <= MaxClients)
	{
		vecDeath[client][0] = NULL_VECTOR;
		vecDeath[client][1] = NULL_VECTOR;
	}
}

void InitAllMenu()
{
	delete hMenuMain;
	hMenuMain = CreatePanel();
	hMenuMain.SetTitle("========= 购买菜单 =========");
	hMenuMain.DrawItem("手枪 (Pistols)");
	hMenuMain.DrawItem("冲锋枪/手榴弹 (SMG/Grenade)");
	hMenuMain.DrawItem("步枪 (Rifle)");
	hMenuMain.DrawItem("霰弹枪/狙击枪 (Shotgun/Sniper)");
	// hMenuMain.DrawItem("狙击枪 (Sniper)");
	hMenuMain.DrawItem("工具 (Tools)");
	hMenuMain.DrawItem("医疗品 (Medkit)");
	hMenuMain.DrawItem("弹药 (Ammo)");
	hMenuMain.DrawItem("近战武器 (Melee)");
	// hMenuMain.DrawItem("投掷武器 (Grenade)", ITEMDRAW_DEFAULT);
	hMenuMain.DrawItem("其他 (Other)");
	hMenuMain.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	
	delete hMenuDeath;
	hMenuDeath = CreatePanel();
	hMenuDeath.SetTitle("========= 购买菜单 =========");
	hMenuDeath.DrawItem(fic("复活到出发点", gCvarCostRespawn[0].IntValue));
	hMenuDeath.DrawItem(fic("复活到死亡点", gCvarCostRespawn[1].IntValue));
	hMenuDeath.DrawItem(fic("复活到队友旁", gCvarCostRespawn[2].IntValue));
	hMenuDeath.DrawItem(fic("复活其他人", gCvarCostRespawn[3].IntValue));
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	
	delete hMenuOther;
	hMenuOther = CreateMenu(MF_OtherMenu);
	hMenuOther.SetTitle("购买菜单 - 其他 (Other)");
	hMenuOther.ExitButton = true;
	hMenuOther.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuOther.ExitBackButton = true;
	hMenuOther.AddItem("respawn_other", fic("复活死亡的队友", gCvarCostRespawn[3].IntValue));
	hMenuOther.AddItem("self_check", "查看自身状态");
	hMenuOther.AddItem("self_revive", "更新自身状态");
	
	ConnectMySQLDataBase();
}

void ConnectMySQLDataBase()
{
	static KeyValues kv;
	if(kv == INVALID_HANDLE)
	{
		kv = CreateKeyValues("");
		kv.SetString("driver", SQL_DRIV);
		kv.SetString("host", SQL_HOST);
		kv.SetString("database", SQL_DATA);
		kv.SetString("user", SQL_USER);
		kv.SetString("pass", SQL_PASS);
		kv.SetString("port", SQL_PORT);
	}
	
	char err[255];
	delete dbWeapon;
	dbWeapon = SQL_ConnectCustom(kv, err, 255, true);
	
	if(dbWeapon == INVALID_HANDLE)
	{
		LogError("连接数据库失败：%s", err);
		PrintToServer("\x03[提示]\x01 连接数据库失败...");
		//SetFailState("数据库错误：%s", err);
		CreateTimer(3.0, Timer_ReconnecyDataBase);
		return;
	}
	
	dbWeapon.Query(QCB_LoadMenu, "select * from nmrih_cost;");
}

public Action Timer_ReconnecyDataBase(Handle timer, any data)
{
	PrintToServer("\x03[提示]\x01 正在重新连接数据库...");
	ConnectMySQLDataBase();
	return Plugin_Continue;
}

public void QCB_LoadMenu(Database db, DBResultSet res, const char[] error, any data)
{
	if(res == INVALID_HANDLE || res.RowCount <= 0)
	{
		SetFailState("数据库里没有任何内容，插件无法运行！");
		delete db;
		return;
	}
	
	char weapon[64] = "", name[128];
	int cost = -1, type = 0, ammoType = 0;
	
	// 初始化菜单
	delete hMenuPistol;
	hMenuPistol = CreateMenu(MF_BuyMenu);
	hMenuPistol.SetTitle("购买菜单 - 手枪 (Pistol)");
	hMenuPistol.ExitButton = true;
	hMenuPistol.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuPistol.ExitBackButton = true;
	
	delete hMenuSMG;
	hMenuSMG = CreateMenu(MF_BuyMenu);
	hMenuSMG.SetTitle("购买菜单 - 冲锋枪/手榴弹 (SobMachineGun/Grenade)");
	hMenuSMG.ExitButton = true;
	hMenuSMG.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuSMG.ExitBackButton = true;
	
	delete hMenuRifle;
	hMenuRifle = CreateMenu(MF_BuyMenu);
	hMenuRifle.SetTitle("购买菜单 - 步枪 (Rifle)");
	hMenuRifle.ExitButton = true;
	hMenuRifle.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuRifle.ExitBackButton = true;
	
	delete hMenuShotGun;
	hMenuShotGun = CreateMenu(MF_BuyMenu);
	hMenuShotGun.SetTitle("购买菜单 - 霰弹枪 (Shotgun)");
	hMenuShotGun.ExitButton = true;
	hMenuShotGun.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuShotGun.ExitBackButton = true;
	
	delete hMenuSniper;
	hMenuSniper = CreateMenu(MF_BuyMenu);
	hMenuSniper.SetTitle("购买菜单 - 狙击枪 (Sniper)");
	hMenuSniper.ExitButton = true;
	hMenuSniper.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuSniper.ExitBackButton = true;
	
	delete hMenuTool;
	hMenuTool = CreateMenu(MF_BuyMenu);
	hMenuTool.SetTitle("购买菜单 - 工具 (Tools)");
	hMenuTool.ExitButton = true;
	hMenuTool.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuTool.ExitBackButton = true;
	
	delete hMenuMedkit;
	hMenuMedkit = CreateMenu(MF_BuyMenu);
	hMenuMedkit.SetTitle("购买菜单 - 医疗品 (Medkit)");
	hMenuMedkit.ExitButton = true;
	hMenuMedkit.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuMedkit.ExitBackButton = true;
	
	delete hMenuMelee;
	hMenuMelee = CreateMenu(MF_BuyMenu);
	hMenuMelee.SetTitle("购买菜单 - 近战武器 (Melee)");
	hMenuMelee.ExitButton = true;
	hMenuMelee.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuMelee.ExitBackButton = true;
	
	delete hMenuAmmo;
	hMenuAmmo = CreateMenu(MF_BuyMenu);
	hMenuAmmo.SetTitle("购买菜单 - 弹药 (Ammo)");
	hMenuAmmo.ExitButton = true;
	hMenuAmmo.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuAmmo.ExitBackButton = true;
	
	delete hMenuGreande;
	hMenuGreande = CreateMenu(MF_BuyMenu);
	hMenuGreande.SetTitle("购买菜单 - 投掷武器 (Greande)");
	hMenuGreande.ExitButton = true;
	hMenuGreande.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuGreande.ExitBackButton = true;
	
	// 初始化出售
	delete tSell;
	delete tName;
	delete tWeigth;
	delete tRemainder;
	tSell = CreateTrie();
	tName = CreateTrie();
	tWeigth = CreateTrie();
	tRemainder = CreateTrie();
	
	while(res.FetchRow())
	{
		// 数据库结构：
		// idx, weapon, name, cost, costtype, sell, weigth, ammo, ammotype, type, 	surplus
		// 索引, 类名, 显示名, 价格, 货币, 出售价格, 重量, 弹夹大小, 弹药类型, 分类, 库存数量
		type = res.FetchInt(9);
		cost = res.FetchInt(3);
		ammoType = res.FetchInt(8);
		res.FetchString(1, weapon, 64);
		res.FetchString(2, name, 64);
		
		if(weapon[0] == '\0')
		{
			res.FetchMoreResults();
			continue;
		}
		
		if(type != 10)
		{
			// 出售价格和名字列表
			tSell.SetValue(weapon, res.FetchInt(5), true);
			tName.SetString(weapon, name, true);
			tWeigth.SetValue(weapon, res.FetchInt(6), true);
		}
		tRemainder.SetValue(weapon, res.FetchInt(10), true);
		
		switch(type)
		{
			case 1:		hMenuMelee.AddItem(weapon, fic(name, cost));
			case 2:		hMenuPistol.AddItem(weapon, fic(name, cost));
			case 3, 9:		hMenuSMG.AddItem(weapon, fic(name, cost));		// 将投掷武器与冲锋枪合并
			case 4:		hMenuRifle.AddItem(weapon, fic(name, cost));
			case 5, 6:		hMenuShotGun.AddItem(weapon, fic(name, cost));	// 将狙击枪与霰弹枪合并
			// case 6:		hMenuSniper.AddItem(weapon, fic(name, cost));
			case 7:		hMenuTool.AddItem(weapon, fic(name, cost));
			case 8:		hMenuMedkit.AddItem(weapon, fic(name, cost));
			// case 9:		hMenuGreande.AddItem(weapon, fic(name, cost));
			case 10:
			{
				iAmmoCost[ammoType] = cost;
				// Format(weapon, 64, "AmmoType:%d", ammoType);
				hMenuAmmo.AddItem(tr("%s:%d", weapon, ammoType), fic(name, cost));
			}
		}
		
		res.FetchMoreResults();
	}
}

/*
public void OnMapStart()
{
	PrefetchSound(gPickupSound[0]);
	PrecacheSound(gPickupSound[0], true);
	PrefetchSound(gPickupSound[1]);
	PrecacheSound(gPickupSound[1], true);
	PrefetchSound(gPickupSound[2]);
	PrecacheSound(gPickupSound[2], true);
}
*/

public int MF_OtherMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
		return;
	
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, menu);
	WritePackCell(data, menu.Selection);
	
	if(action != MenuAction_Select)
	{
		if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		{
			hMenuMain.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMain.Send(client, MF_MainMenu, MENU_TIME_FOREVER);
		}
		return;
	}
	
	switch(select)
	{
		case 0:
		{
			if(GetRandomTeam(client) <= 0)
			{
				PrintToChat(client, "\x04[提示]\x01 没有其他死亡的队友。");
				CreateTimer(0.1, Timer_WaitDisplayMenu, data);
				return;
			}
			CreateTeamMenu(client);
		}
		case 1:
			FakeClientCommand(client, "info");
		case 2:
			FakeClientCommand(client, "revive");
		default:
		{
			int idx = select - 3;
			Handle fw = aCallbackList.Get(idx), pug = aPluginList.Get(idx);
			bool keep = aKeepList.Get(idx);
			
			if(pug == INVALID_HANDLE || fw == INVALID_HANDLE)
			{
				PrintToChat(client, "\x04[提示]\x01 这个功能已关闭。");
				CreateTimer(0.1, Timer_WaitDisplayMenu, data);
				return;
			}
			
			char info[255], display[1024];
			menu.GetItem(select, info, 255, _, display, 1024);
			
			Call_StartForward(fw);
			// Call_StartFunction(pug, func);
			Call_PushCell(client);
			Call_PushString(info);
			Call_PushString(display);
			Call_Finish();
			
			if(keep)
				CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		}
	}
}

public int MF_DeathMenu(Menu menu, MenuAction action, int client, int select)
{
	if(action != MenuAction_Select || !NMS_IsClientValid(client))
		return;
	
	if(select > 4 || select < 1)
	{
		//ClosePanel(client);
		return;
	}
	
	int cost = gCvarCostRespawn[select - 1].IntValue;
	if(NMS_GetCoin(client) < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的金币不够，无法选择这个复活方式。");
		hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
		hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
		return;
	}
	
	if(select == 4)
	{
		if(GetRandomTeam(client) <= 0)
		{
			PrintToChat(client, "\x04[提示]\x01 没有其他死亡的队友。");
			hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
			hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
			return;
		}
		
		CreateTeamMenu(client);
		return;
	}
	
	if(IsPlayerAlive(client))
	{
		PrintToChat(client, "\x04[提示]\x01 你还活着，不需要复活。");
		return;
	}
	
	switch(select)
	{
		case 1:
			RespawnPlayer(client, vecStart[0], vecStart[1]);
		case 2:
		{
			if(vecDeath[client][0][0] == NULL_VECTOR[0] && vecDeath[client][0][1] == NULL_VECTOR[1] &&
				vecDeath[client][0][2] == NULL_VECTOR[2] && vecDeath[client][1][0] == NULL_VECTOR[0] &&
				vecDeath[client][1][1] == NULL_VECTOR[1] && vecDeath[client][1][2] == NULL_VECTOR[2])
			{
				PrintToChat(client, "\x04[提示]\x01 你没有死过，无法复活到死亡的位置。");
				hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
				hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
				return;
			}
			
			RespawnPlayer(client, vecDeath[client][0], vecDeath[client][1]);
		}
		case 3:
		{
			int team = GetRandomTeam(client, true);
			if(team <= 0)
			{
				PrintToChat(client, "\x04[提示]\x01 没有其他活着的队友。");
				hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
				hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
				return;
			}
			
			float pos[3], ang[3];
			GetClientAbsOrigin(team, pos);
			GetClientAbsAngles(team, ang);
			RespawnPlayer(client, pos, ang);
		}
	}
	
	NMS_ChangeCoin(client, -cost);
	PrintToChat(client, "\x04[提示]\x01 复活完毕，你花费了 %d 金币，你还剩 %d 金币。", cost, NMS_GetCoin(client));
	PrintToServer("[商店] 玩家 %N 使用了复活功能。", client);
}

public int MF_RespawnTeam(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
	{
		//menu.Close();
		return;
	}
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
	{
		if(IsPlayerAlive(client))
		{
			hMenuMain.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMain.Send(client, MF_MainMenu, MENU_TIME_FOREVER);
		}
		else
		{
			hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 金币 ***", NMS_GetCoin(client)));
			hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
		}
		//menu.Close();
		return;
	}
	
	if(action != MenuAction_Select)
	{
		//menu.Close();
		return;
	}
	
	char info[16];
	menu.GetItem(select, info, 16);
	int target = StringToInt(info);
	if(!NMS_IsClientValid(target) || IsPlayerAlive(target))
	{
		PrintToChat(client, "\x04[提示]\x01 这个玩家无效，或者他已经活过来了。");
		CreateTeamMenu(client);
		//menu.Close();
		return;
	}
	
	int cost = gCvarCostRespawn[3].IntValue;
	if(NMS_GetCoin(client) < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的金币不够，无法复活队友。");
		
		if(IsPlayerAlive(client))
		{
			hMenuOther.SetTitle(tr(" 购买菜单 - 其他 (Other)n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuOther.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 金币 ***", NMS_GetCoin(client)));
			hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
		}
		
		//menu.Close();
		return;
	}
	
	NMS_ChangeCoin(client, -cost);
	RespawnPlayer(target, vecStart[0], vecStart[1]);
	PrintToChat(client, "\x04[提示]\x01 复活完毕，你花费了 %d 金币，你还剩 %d 金币。", cost, NMS_GetCoin(client));
	PrintToServer("[商店] 玩家 %N 买下了复活 %N 的功能。", client, target);
}

Menu CreateTeamMenu(client)
{
	char name[128], info[16];
	static Menu mDeath;	// 防止被回收
	mDeath = CreateMenu(MF_RespawnTeam);
	mDeath.SetTitle(tr("购买菜单 - 复活队友\n\t*** 你有 %d 金币 ***\n\t复活队友需要 %d 金币", NMS_GetCoin(client),
		gCvarCostRespawn[3].IntValue));
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsPlayerAlive(i) || i == client)
			continue;
		
		IntToString(i, info, 16);
		GetClientName(i, name, 128);
		mDeath.AddItem(info, name);
	}
	mDeath.ExitBackButton = true;
	mDeath.ExitButton = true;
	mDeath.OptionFlags |= MENUFLAG_NO_SOUND;
	mDeath.Display(client, MENU_TIME_FOREVER);
	return mDeath;
}

public int MF_MainMenu(Menu menu, MenuAction action, int client, int select)
{
	if(action != MenuAction_Select || !NMS_IsClientValid(client))
		return;
	
	// 只会执行一个的，不会占用多少 cpu 的吧...
	switch(select)
	{
		case 1:
		{
			hMenuPistol.SetTitle(tr("购买菜单 - 手枪 (Pistols)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuPistol.Display(client, MENU_TIME_FOREVER);
		}
		case 2:
		{
			hMenuSMG.SetTitle(tr("购买菜单 - 冲锋枪/手榴弹 (SMG/Grenade)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuSMG.Display(client, MENU_TIME_FOREVER);
		}
		case 3:
		{
			hMenuRifle.SetTitle(tr("购买菜单 - 步枪 (Rifle)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuRifle.Display(client, MENU_TIME_FOREVER);
		}
		case 4:
		{
			hMenuShotGun.SetTitle(tr("购买菜单 - 霰弹枪/狙击枪 (Shotgun/Sniper)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuShotGun.Display(client, MENU_TIME_FOREVER);
		}
/*
		case 5:
		{
			hMenuSniper.SetTitle(tr("购买菜单 - 狙击枪 (Sniper)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuSniper.Display(client, MENU_TIME_FOREVER);
		}
*/
		case 5:
		{
			hMenuTool.SetTitle(tr("购买菜单 - 工具 (Tools)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuTool.Display(client, MENU_TIME_FOREVER);
		}
		case 6:
		{
			hMenuMedkit.SetTitle(tr("购买菜单 - 医疗品 (Medkit)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMedkit.Display(client, MENU_TIME_FOREVER);
		}
		case 7:
		{
			hMenuAmmo.SetTitle(tr("购买菜单 - 子弹 (Ammo)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuAmmo.Display(client, MENU_TIME_FOREVER);
		}
		case 8:
		{
			hMenuMelee.SetTitle(tr("购买菜单 - 近战武器 (Melee)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMelee.Display(client, MENU_TIME_FOREVER);
		}
		case 9:
		{
			hMenuOther.SetTitle(tr("购买菜单 - 其他 (Other)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuOther.Display(client, MENU_TIME_FOREVER);
		}
		case 10:
		{
			/*
			hMenuGreande.SetTitle(tr("购买菜单 - 投掷武器 (Greande)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuGreande.Display(client, MENU_TIME_FOREVER);
			*/
			//ClosePanel(client);
			return;
		}
	}
}
/*
public int MF_AmmoMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
		return;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			hMenuMain.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMain.Send(client, MF_MainMenu, MENU_TIME_FOREVER);
		}
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	int cost = GetDisplayCost(menu, select);
	
	if(cost <= -1)
	{
		PrintToChat(client, "\x04[提示]\x01 这个子弹暂时缺货！");
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return;
	}
	
	int money = NMS_GetPoint(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的积分不足以购买它。现有：%d 需要：%d", money, cost);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return;
	}
	
	NMS_ChangePoint(client, -cost);
	
	char item[16];
	menu.GetItem(select, item, 16);
	int type = StringToInt(item), count = GetRandomInt(5, 15);
	if(type == 13)
		count = 20;
	if(type == 15)
		count = 2;
	
	if(GivePlayerAmmo(client, count, type, false) == count)
	{
		PrintToChat(client, "\x04[提示]\x01 你花费了 %d 买下了 %d 颗子弹，你还剩下 %d 积分。", cost, count, money);
		PrintToChat(client, "\x04[提示]\x01 如果你没有在背包里找到它，请在你的脚下寻找。");
	}
	
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, menu);
	WritePackCell(data, menu.Selection);
	CreateTimer(0.1, Timer_WaitDisplayMenu, data);
	//menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
}
*/
public int MF_BuyMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!NMS_IsClientValid(client))
		return;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			hMenuMain.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
			hMenuMain.Send(client, MF_MainMenu, MENU_TIME_FOREVER);
		}
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	int cost = GetDisplayCost(menu, select), surplus = -1;
	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, menu);
	WritePackCell(data, menu.Selection);
	
	char item[64] = "", cAmmoBreak[2][64] = {"", ""};
	menu.GetItem(select, item, 64);
	if(item[0] == '\0')
	{
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	if(StrContains(item, "ammobox_", false) == 0)
	{
		ExplodeString(item, ":", cAmmoBreak, 2, 64);
		tRemainder.GetValue(cAmmoBreak[0], surplus);
	}
	else
		tRemainder.GetValue(item, surplus);
	
	if(cost <= -1 || surplus == 0)
	{
		PrintToChat(client, "\x04[提示]\x01 这个物品暂时缺货！");
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	int money = NMS_GetPoint(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的积分不足以购买它。现有：%d 需要：%d", money, cost);
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	if(cAmmoBreak[1][0] == '\0' && GetPlayerWeapon(client, item) > MaxClients)
	{
		PrintToChat(client, "\x04[提示]\x01 你已经有这个武器了，不需要购买。");
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	NMS_ChangePoint(client, -cost);
	money -= cost;
	
	if(cAmmoBreak[1][0] != '\0')
	{
		SetRandomSeed(RoundFloat(GetEngineTime()));
		int type = StringToInt(cAmmoBreak[1]), count = GetRandomInt(5, 15);
		if(type < 1 || type > 15)
		{
			PrintToChat(client, "\x04[提示]\x01 我们不认识这种弹药 (%d)，无法提供。", type);
			CreateTimer(0.1, Timer_WaitDisplayMenu, data);
			return;
		}
		
		if(type == 13)
			count = 20;
		if(type == 15)
			count = 2;
		
		if(ChangePlayerAmmo(client, count, type) > 0)
			PrintToChat(client, "\x04[提示]\x01 你花费了 %d 买下了 %d 颗子弹，你还剩下 %d 积分。", cost, count, money);
		PrintToServer("[商店] 玩家 %N 购买了 %d 颗子弹。", client, count);
		
		tRemainder.SetValue(cAmmoBreak[0], --surplus);
		dbWeapon.Query(QCB_FastQuery, tr("update nmrih_cost set surplus = surplus - 1 where weapon = '%s' and surplus > -1;", cAmmoBreak[0]));
	}
	else
	{
		int weapon = GivePlayerItem(client, item);
		if(IsValidEntity(weapon))
		{
			EquipPlayerWeapon(client, weapon);
			PrintToChat(client, "\x04[提示]\x01 你花费了 %d 买下了这个物品，你还剩下 %d 积分。", cost, money);
			PrintToChat(client, "\x04[提示]\x01 如果你没有在背包里找到它，请在你的脚下寻找。");
			PrintToServer("[商店] 玩家 %N 购买了一些东西。", client);
			
			tRemainder.SetValue(item, --surplus);
			dbWeapon.Query(QCB_FastQuery, tr("update nmrih_cost set surplus = surplus - 1 where weapon = '%s' and surplus > -1;", item));
		}
	}
	
	if(surplus == 0)
	{
		InitAllMenu();
		Cmd_BuyMenu(client, 0);
	}
	else
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
	//menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
}

void RespawnPlayer(int client, float pos[3] = NULL_VECTOR, float ang[3] = NULL_VECTOR)
{
	int ent = CreateEntityByName("info_player_nmrih");
	
	if(pos[0] != NULL_VECTOR[0] || pos[1] != NULL_VECTOR[1] || pos[2] != NULL_VECTOR[2])
		DispatchKeyValueVector(ent, "origin", pos);
	
	if(ang[0] != NULL_VECTOR[0] || ang[1] != NULL_VECTOR[1] || ang[2] != NULL_VECTOR[2])
		DispatchKeyValueVector(ent, "angles", ang);
	
	DispatchSpawn(ent);
	SetVariantString("OnUser1 !self:Kill::3:1");	// 可能无效，因为这个游戏里的 ent_fire 命令存在但没有任何效果
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");
	CreateTimer(4.0, Timer_RemoveEntity, ent);		// 防止上面的代码没有生效
	
	DispatchSpawn(client);
	SetEntProp(client, Prop_Send, "m_iPlayerState", 0);
	SetEntProp(client, Prop_Send, "m_iHideHUD", 2050);
	TeleportEntity(client, pos, ang, NULL_VECTOR);
}

public Action Timer_RemoveEntity(Handle timer, any entity)
{
	if(!IsValidEntity(entity) || !IsValidEdict(entity))
		return Plugin_Continue;
	
	AcceptEntityInput(entity, "Kill");
	PrintToServer("[复活] 手动删除 info_player_nmrih 实体。");
	
	return Plugin_Continue;
}

public Action Timer_WaitDisplayMenu(Handle timer, any data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	Menu menu = ReadPackCell(data);
	int first = ReadPackCell(data);
	CloseHandle(data);
	
	if(!IsValidClient(client) || menu == INVALID_HANDLE || first < 0)
		return;
	
	char title[255], text[2][255];
	menu.GetTitle(title, 255);
	ExplodeString(title, "\n", text, 2, 255);
	TrimString(text[0]);
	menu.SetTitle(tr("%s\n\t*** 你有 %d 积分 ***", text[0], NMS_GetPoint(client)));
	
	menu.DisplayAt(client, first, MENU_TIME_FOREVER);
}

stock char fic(const char[] text, int cost = -1, char[] weapon = "")
{
	// 格式化显示物品和价格
	char line[255];
	int surplus = -1;
	
	if(weapon[0] != '\0')
		tRemainder.GetValue(weapon, surplus);
	
	if(cost < 0 || surplus == 0)
		Format(line, 255, "%s [缺货]", text);
	else if(cost == 0)
		Format(line, 255, "%s [免费]", text);
	else
		Format(line, 255, "%s [%d]", text, cost);
	
	return line;
}

stock void FormatItemCost(char[] line, int len, const char[] str, int cost = -1)
{
	// 格式化合并字符串
	if(cost < 0)
		Format(line, len, "%s [缺货]", str);
	else if(cost == 0)
		Format(line, len, "%s [免费]", str);
	else
		Format(line, len, "%s [%d]", str, cost);
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

public Action Cmd_BuyMenu(int client, int args)
{
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client))
		return Plugin_Continue;
	
	if(IsPlayerAlive(client))
	{
		hMenuMain.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
		hMenuMain.Send(client, MF_MainMenu, MENU_TIME_FOREVER);
		PrintToServer("[商店] 玩家 %N 打开了购买菜单。", client);
	}
	else
	{
		hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
		hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
		PrintToServer("[商店] 玩家 %N 打开了复活菜单。", client);
	}
	
	return Plugin_Handled;
}

public Action Cmd_BuyAmmo(int client, int args)
{
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon <= MaxClients || !IsValidEntity(weapon))
	{
		PrintToChat(client, "\x04[提示]\x01 你手上没有武器！");
		return Plugin_Continue;
	}
	
	int type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if(type < 1 || type > 15)
	{
		PrintToChat(client, "\x04[提示]\x01 这个武器不需要弹药！");
		return Plugin_Continue;
	}
	
	int cost = iAmmoCost[(type >= 12 ? type - 4 : type - 1)];
	if(cost == -1)
	{
		PrintToChat(client, "\x04[提示]\x01 这种弹药已经卖完了。");
		return Plugin_Continue;
	}
	
	int money = NMS_GetPoint(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的钱不够，你有：%d | 需要：%d", money, cost);
		return Plugin_Continue;
	}
	
	SetRandomSeed(RoundFloat(GetEngineTime()));
	int amount = GetRandomInt(5, 15);
	if(type == 13)
		amount = GetRandomInt(15, 25);
	if(type == 15)
		amount = GetRandomInt(1, 4);
	
	NMS_ChangePoint(client, -cost);
	ChangePlayerAmmo(client, amount, type);
	PrintToChat(client, "\x04[提示]\x01 你花费了 %d 买下了 %d 颗子弹，你还剩下 %d 积分。", cost, amount, money);
	
	dbWeapon.Query(QCB_FastQuery, tr("update nmrih_cost set surplus = surplus - 1 where weapon like 'ammobox_%%' and ammotype = %d and surplus > -1;", type));
	
	return Plugin_Handled;
}

stock int ChangePlayerAmmo(int client, int amount, int worat = -1, bool clip = false, bool sound = true)
{
	if(!IsValidClient(client))
		ThrowError("这个玩家无效！");
	
	int weapon = -1, ammoType = 0;
	if(worat == -1)
		weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	else if(worat > 0 && worat < 16)
		ammoType = worat;
	else if(worat > MaxClients && IsValidEntity(worat))
		weapon = worat;
	
	if(ammoType <= 0 && IsValidEntity(weapon))
		ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	
	if(weapon <= MaxClients && (ammoType < 1 || ammoType > 15))
		ThrowError("无效的武器或弹药类型");
	
	int newCount = -1;
	if(clip)
	{
		if(weapon <= MaxClients || !IsValidEntity(weapon))
			ThrowError("武器无效！");
		
		newCount = GetEntProp(weapon, Prop_Send, "m_iClip1") + amount;
		if(newCount < 0)
			newCount = 0;
		
		SetEntProp(weapon, Prop_Send, "m_iClip1", newCount);
	}
	else
	{
		newCount = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType) + amount;
		if(newCount < 0)
			newCount = 0;
		
		SetEntProp(client, Prop_Send, "m_iAmmo", newCount, _, ammoType);
		//SetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo", newCount);
	}
	
	if(sound && amount > 0)
	{
		SetRandomSeed(RoundFloat(GetEngineTime()));
		//EmitSoundToAll(gPickupSound[GetRandomInt(0, 2)], client, SNDCHAN_ITEM);
		ClientCommand(client, tr("play \"player/ammo_pickup_0%d.wav\"", GetRandomInt(1, 3)));
	}
	
	return newCount;
}

public Action Cmd_RebulidShopMenu(int client, int args)
{
	if(!NMS_IsClientValid(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	InitAllMenu();
	return Plugin_Handled;
}

public Action Cmd_SellMenu(int client, int args)
{
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	CreateSellMenu(client);
	return Plugin_Handled;
}

Menu CreateSellMenu(int client, bool print = true)
{
	Menu menu = CreateMenu(MF_SellMenu);
	menu.SetTitle(tr("========= 回收菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)));
	menu.OptionFlags |= MENUFLAG_NO_SOUND;
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	
	int entity = -1, cost = -1;
	char selectName[128], className[128];
	int max = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for(int i = 0; i < max; i++)
	{
		entity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(entity < MaxClients || !IsValidEntity(entity))
			continue;
		
		GetEntityClassname(entity, className, 128);
		if(!tSell.GetValue(className, cost) || !tName.GetString(className, selectName, 128))
			continue;
		
		if(cost <= 0 || selectName[0] == '\0')
			continue;
		
		menu.AddItem(className, tr("%s [%d]", selectName, cost));
	}
	
	if(menu.ItemCount <= 0)
	{
		if(print)
			PrintToChat(client, "\x04[提示]\x01 你并没有携带有什么值钱的东西。");
		
		delete menu;
		return menu;
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	return menu;
}

public int MF_SellMenu(Menu menu, MenuAction action, int client, int select)
{
	if(action != MenuAction_Select || !NMS_IsClientValid(client))
	{
		//delete menu;
		return;
	}
	
	int cost = -1;
	char weapon[128];
	menu.GetItem(select, weapon, 128);
	if(weapon[0] == '\0' || !tSell.GetValue(weapon, cost) || cost <= 0)
	{
		PrintToChat(client, "\x04[提示]\x01 这个东西无法回收。");
		CreateSellMenu(client, false);
		return;
	}
	
	int entity = GetPlayerWeapon(client, weapon);
	if(entity < MaxClients || !IsValidEntity(entity) || GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != client)
	{
		PrintToChat(client, "\x04[提示]\x01 你并没携带这个东西。");
		CreateSellMenu(client, false);
		return;
	}
	
	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int weigth = GetEntProp(client, Prop_Send, "_carriedWeight"), sub = 0;
	if(tWeigth.GetValue(weapon, sub) && sub > 0)
		weigth -= sub;
	
	if(active == entity)
	{
		int fists = GetPlayerWeapon(client, "me_fists");
		if(fists < MaxClients || !IsValidEntity(fists))
			FakeClientCommand(client, "lastinv");
		else
			EquipPlayerWeapon(client, fists);
	}
	
	NMS_ChangePoint(client, cost);
	SDKHooks_DropWeapon(client, entity, _, Float:{0.0, 0.0, 0.0});
	RemoveEdict(entity);
	SetEntProp(client, Prop_Send, "_carriedWeight", weigth);
	CreateSellMenu(client, false);
	PrintToChat(client, "\x04[提示]\x01 回收成功，你获得了 %d 积分。", cost);
	
	dbWeapon.Query(QCB_FastQuery, tr("update nmrih_cost set surplus = surplus + 1 where weapon = '%s' and surplus > -1;", weapon));
}

public void QCB_FastQuery(Database db, DBResultSet res, const char[] error, any data)
{
	if(error[0] != '\0')
		PrintToServer("数据库错误：%s", error);
}

stock char tr(const char[] text, any ...)
{
	char result[1024];
	VFormat(result, 1024, text, 2);
	return result;
}
/*
void UpdateLimitSetting()
{
	dbWeapon.Query(QCB_FastQuery, "update nmrih_cost set surplus = if(weapon regexp '^ammobox_+',
		floor(25 + rand() * (100 - 25 + 1)), if(weapon regexp '^exp_+',
		floor(5 + rand() * (10 - 5 + 1)), floor(10 + rand() * (30 - 10 + 1)))) where surplus > -1;");
}
*/
stock int GetRandomTeam(int client = 0, bool alive = false)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!NMS_IsClientValid(i) || i == client)
			continue;
		
		if(IsPlayerAlive(i) == alive)
			return i;
	}
	
	return 0;
}
/*
stock void ClosePanel(int client)
{
	Menu cp = CreateMenu(MF_DeathMenu);
	cp.Display(client, 1);
	cp.Close();
	delete cp;
}
*/
stock int GetPlayerWeapon(int client, const char[] weapon)
{
	/*
	static int offs;
	if(offs <= 0)
		offs = FindSendPropOffs("CNMRiH_Player", "m_hMyWeapons");
	if(offs <= 0)
		return -1;
	*/
	int entity = -1;
	char classname[128];
	int len = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for(int i = 0; i < len; ++i)
	{
		//entity = GetEntDataEnt2(client, offs + i);
		entity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(entity < MaxClients || !IsValidEntity(entity))
			continue;
		
		GetEntityClassname(entity, classname, 128);
		if(strcmp(classname, weapon, false) == 0)
			return entity;
	}
	
	return -1;
}
/*
void ArrayMoveToForward(Handle[] array, int begin = 0, const int max_len = -1)
{
	if(max_len > -1 && begin == max_len)
		return;
	
	// 使用递归将数组的位置逐次向前移动一格
	if(max_len > -1 && begin + 1 >= max_len)
		array[begin] = INVALID_HANDLE;
	else
		array[begin] = array[begin + 1];
	if(array[begin] != INVALID_HANDLE)
		ArrayMoveToForward(array, begin + 1);
}

void ArrayMoveToForward2(Function[] array, int begin = 0, const int max_len = -1)
{
	if(max_len > -1 && begin == max_len)
		return;
	
	// 使用递归将数组的位置逐次向前移动一格
	if(max_len > -1 && begin + 1 >= max_len)
		array[begin] = INVALID_FUNCTION;
	else
		array[begin] = array[begin + 1];
	if(array[begin] != INVALID_FUNCTION)
		ArrayMoveToForward2(array, begin + 1);
}
*/
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("nmrih_point_store");
	CreateNative("NMS_AddMenuSelect", Native_AddMenuSelect);
	CreateNative("NMS_RemoveMenuSelect", Native_RemoveMenuSelect);
}

public int Native_AddMenuSelect(Handle plugin, int param)
{
	char info[255], text[1024];
	GetNativeString(1, info, 255);
	GetNativeString(2, text, 1024);
	
	if(iFuncCount >= MAX_MENU_ITEM || !hMenuOther.AddItem(info, text))
		ThrowNativeError(SP_ERROR_PARAMS_MAX, "已达到添加的上限！");
	
	/*
	fwOnMenuSelect[iFuncCount] = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
	if(!AddToForward(fwOnMenuSelect[iFuncCount++], plugin, GetNativeFunction(3)))
	{
		hMenuOther.RemoveItem(hMenuOther.ItemCount - 1);
		--iFuncCount;
		ThrowNativeError(SP_ERROR_NOT_RUNNABLE, "无效的回调函数！");
	}
	*/
	
	Function func = GetNativeFunction(3);
	Handle fw = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
	if(func == INVALID_FUNCTION || fw == INVALID_HANDLE || !AddToForward(fw, plugin, func))
	{
		hMenuOther.RemoveItem(hMenuOther.ItemCount - 1);
		--iFuncCount;
		ThrowNativeError(SP_ERROR_NOT_RUNNABLE, "无效的回调函数！");
	}
	
	aCallbackList.Push(fw);
	aPluginList.Push(plugin);
	aKeepList.Push(GetNativeCell(4));
	++iFuncCount;
	/*
	funCallback[iFuncCount] = GetNativeFunction(3);
	hPluginCall[iFuncCount] = plugin;
	iKeep[iFuncCount++] = GetNativeCell(4);
	*/
	return hMenuOther.ItemCount;
}

public int Native_RemoveMenuSelect(Handle plugin, int param)
{
	int pos = GetNativeCell(1);
	if(pos < 0 || pos >= hMenuOther.ItemCount)
		ThrowNativeError(SP_ERROR_NOT_FOUND, "找不到指定的选项！");
	
	hMenuOther.RemoveItem(pos);
	pos -= 3;
	/*
	RemoveFromForward(fwOnMenuSelect[pos], plugin, GetNativeFunction(2));
	delete fwOnMenuSelect[pos];
	*/
	
	aCallbackList.Erase(pos);
	aPluginList.Erase(pos);
	aKeepList.Erase(pos);
	--iFuncCount;
	
	/*
	funCallback[pos] = INVALID_FUNCTION;
	hPluginCall[pos] = INVALID_HANDLE;
	iKeep[pos] = 0;
	ArrayMoveToForward(hPluginCall, pos, iFuncCount);
	ArrayMoveToForward2(funCallback, pos, iFuncCount--);
	*/
	return 0;
}
