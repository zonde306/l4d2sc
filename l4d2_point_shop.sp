#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>
#include <l4d2_simple_combat>

#define PLUGIN_VERSION	"0.1"
#define CVAR_FLAGS		FCVAR_NONE

public Plugin myinfo =
{
	name = "简单商店系统",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

ConVar g_pCvarAllow;
ConVar g_pCvarUZI, g_pCvarTMP, g_pCvarMP5, g_pCvarChrome, g_pCvarPump,
	g_pCvarM16, g_pCvarAK47, g_pCvarDesert, g_pCvarSG552, g_pCvarXM1014, g_pCvarSpas,
	g_pCvarHunting, g_pCvarG3SG1, g_pCvarScout, g_pCvarAWP, g_pCvarMagnum, g_pCvarM60,
	g_pCvarFire, g_pCvarExplode, g_pCvarAidKit, g_pCvarPills, g_pCvarAdren, g_pCvarDefib,
	g_pCvarMolotov, g_pCvarBile, g_pCvarPipe, g_pCvarPistol, g_pCvarLaser, g_pCvarAmmo,
	g_pCvarBaseball, g_pCvarCricket, g_pCvarCrowbar, g_pCvarGuitar, g_pCvarFireaxe, g_pCvarPan,
	g_pCvarGolfclub, g_pCvarKatana, g_pCvarKnife, g_pCvarMachete, g_pCvarShield, g_pCvarTonfa,
	g_pCvarMob, g_pCvarSmoker, g_pCvarBoomer, g_pCvarHunter, g_pCvarSpitter, g_pCvarJockey, g_pCvarCharger,
	g_pCvarWitch, g_pCvarTank;

Menu g_hMenuMain, g_hMenuTier1, g_hMenuTier2, g_hMenuTier3, g_hMenuItem, g_hMenuMelee, g_hMenuUpgrade,
	g_hMenuZombie;

public void OnPluginStart()
{
	CreateConVar("ps_version", PLUGIN_VERSION, "插件版本", CVAR_FLAGS);
	g_pCvarAllow = CreateConVar("ps_allow", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	g_pCvarUZI = CreateConVar("ps_cost_smg", "1000", "冲锋枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarTMP = CreateConVar("ps_cost_smg_slienced", "1150", "消音冲锋枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarMP5 = CreateConVar("ps_cost_smg_mp5", "1250", "MP5冲锋枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarPump = CreateConVar("ps_cost_shotgun_pump", "1500", "木单喷 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarChrome = CreateConVar("ps_cost_shotgun_pump", "1650", "铁单喷 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarM16 = CreateConVar("ps_cost_rifle_m16", "3000", "M16步枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarDesert = CreateConVar("ps_cost_rifle_desert", "3600", "三连发步枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarAK47 = CreateConVar("ps_cost_rifle_ak47", "4000", "AK47步枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarSG552 = CreateConVar("ps_cost_rifle_sg552", "3400", "SG552步枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarXM1014 = CreateConVar("ps_cost_shotgun_auto", "4200", "一代连喷 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarSpas = CreateConVar("ps_cost_shotgun_spas", "4500", "二代连喷 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarHunting = CreateConVar("ps_cost_sniper_hunting", "3200", "15发连狙 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarG3SG1 = CreateConVar("ps_cost_sniper_military", "3800", "30发连狙 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarScout = CreateConVar("ps_cost_sniper_scout", "4200", "Scout狙击枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarAWP = CreateConVar("ps_cost_sniper_awp", "5000", "AWP狙击枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarMagnum = CreateConVar("ps_cost_pistol_magnum", "1500", "马格南 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarM60 = CreateConVar("ps_cost_rifle_m60", "2000", "机枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarFire = CreateConVar("ps_cost_item_fire", "1250", "燃烧子弹包 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarExplode = CreateConVar("ps_cost_item_explode", "1750", "高爆子弹包 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarAidKit = CreateConVar("ps_cost_item_aidkit", "6000", "医疗包 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarPills = CreateConVar("ps_cost_item_pills", "2000", "止痛药 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarAdren = CreateConVar("ps_cost_item_adren", "1750", "肾上腺素 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarDefib = CreateConVar("ps_cost_item_defib", "4000", "电击器 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarMolotov = CreateConVar("ps_cost_grenade_molotov", "3500", "燃烧瓶 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarBile = CreateConVar("ps_cost_grenade_vomitjar", "4000", "胆汁 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarPipe = CreateConVar("ps_cost_grenade_pipe", "2000", "土雷 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarPistol = CreateConVar("ps_cost_pistol", "500", "小手枪 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarLaser = CreateConVar("ps_cost_laser", "1500", "激光瞄准 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarAmmo = CreateConVar("ps_cost_ammo", "250", "补充弹药 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarBaseball = CreateConVar("ps_cost_melee_baseball", "1500", "棒球棒 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarCricket = CreateConVar("ps_cost_melee_cricket", "1250", "船桨 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarCrowbar = CreateConVar("ps_cost_melee_crowbar", "1750", "撬棍 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarGuitar = CreateConVar("ps_cost_melee_guitar", "1300", "吉他 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarFireaxe = CreateConVar("ps_cost_melee_fireaxe", "2000", "消防斧 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarPan = CreateConVar("ps_cost_melee_fryingpan", "1000", "平底锅 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarGolfclub = CreateConVar("ps_cost_melee_golfclub", "1500", "高尔夫球棍 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarKatana = CreateConVar("ps_cost_melee_katana", "2000", "武士刀 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarKnife = CreateConVar("ps_cost_melee_knife", "2050", "小刀 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarMachete = CreateConVar("ps_cost_melee_machete", "2100", "开山刀 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarShield = CreateConVar("ps_cost_melee_shield", "700", "盾牌 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarTonfa = CreateConVar("ps_cost_melee_tonfa", "955", "警棍 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	
	g_pCvarMob = CreateConVar("ps_cost_zombie_mob", "500", "暴动尸群 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarSmoker = CreateConVar("ps_cost_zombie_smoke", "1500", "舌头 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarBoomer = CreateConVar("ps_cost_zombie_boomer", "1000", "胖子 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarHunter = CreateConVar("ps_cost_zombie_hunter", "1750", "猎人 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarSpitter = CreateConVar("ps_cost_zombie_hunter", "1250", "口水 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarJockey = CreateConVar("ps_cost_zombie_jockey", "1400", "猴子 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarCharger = CreateConVar("ps_cost_zombie_charger", "2000", "牛 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarWitch = CreateConVar("ps_cost_zombie_witch", "2500", "萌妹 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	g_pCvarTank = CreateConVar("ps_cost_zombie_tank", "3250", "坦克 价格.-1=禁用", CVAR_FLAGS, true, -1.0);
	AutoExecConfig(true, "l4d2_point_shop");
	
	RegConsoleCmd("sm_buy", Cmd_BuyMenu);
	RegConsoleCmd("sm_shop", Cmd_BuyMenu);
	
	BuildMenu();
	// SC_AddMainMenuItem("simple_shop", "商店菜单");
	CreateTimer(1.0, Timer_SetupMenuItem);
}

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

public Action Timer_SetupMenuItem(Handle timer, any data)
{
	SC_AddMainMenuItem("simple_shop", "商店菜单");
}

public void SC_OnMenuItemClickPost(int client, const char[] info, const char[] display)
{
	if(StrEqual(info, "simple_shop", false))
		Cmd_BuyMenu(client, -1);
}

public Action Cmd_BuyMenu(int client, int argc)
{
	if(!IsValidAliveClient(client))
		return Plugin_Continue;
	
	if(!g_pCvarAllow.BoolValue)
	{
		PrintToChat(client, "\x03[提示]\x01 此功能未开启。");
		return Plugin_Continue;
	}
	
	if(g_hMenuMain == null)
		BuildMenu();
	
	int team = GetClientTeam(client);
	if(team == 2)
	{
		g_hMenuMain.ExitBackButton = (argc == -1);
		g_hMenuMain.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuMain), SC_GetClientCash(client)));
		g_hMenuMain.Display(client, MENU_TIME_FOREVER);
	}
	else if(team == 3)
	{
		g_hMenuZombie.ExitBackButton = (argc == -1);
		g_hMenuZombie.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuZombie), SC_GetClientCash(client)));
		g_hMenuZombie.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Continue;
}

void BuildMenu()
{
	if(g_hMenuMain != null)
		delete g_hMenuMain;
	
	g_hMenuMain = CreateMenu(MenuHandler_MainMenu);
	g_hMenuMain.SetTitle("========= 商店菜单 =========");
	g_hMenuMain.AddItem("1", "冲锋枪/单喷");
	g_hMenuMain.AddItem("2", "步枪/连喷");
	g_hMenuMain.AddItem("3", "狙击/机枪/手枪");
	g_hMenuMain.AddItem("4", "近战武器");
	g_hMenuMain.AddItem("5", "投掷/医疗/弹药");
	g_hMenuMain.AddItem("6", "武器升级");
	g_hMenuMain.ExitBackButton = true;
	g_hMenuMain.ExitButton = true;
	
	if(g_hMenuTier1 != null)
		delete g_hMenuTier1;
	
	g_hMenuTier1 = CreateMenu(MenuHandler_BuyMenu);
	g_hMenuTier1.SetTitle("商店菜单 - 冲锋枪/单喷");
	g_hMenuTier1.AddItem("smg", MakeItemCost("冲锋枪", g_pCvarUZI));
	g_hMenuTier1.AddItem("smg_silenced", MakeItemCost("消音冲锋枪", g_pCvarTMP));
	g_hMenuTier1.AddItem("smg_mp5", MakeItemCost("MP5锋枪", g_pCvarMP5));
	g_hMenuTier1.AddItem("pumpshotgun", MakeItemCost("木单喷", g_pCvarPump));
	g_hMenuTier1.AddItem("shotgun_chrome", MakeItemCost("铁单喷", g_pCvarChrome));
	g_hMenuTier1.ExitBackButton = true;
	g_hMenuTier1.ExitButton = true;
	
	if(g_hMenuTier2 != null)
		delete g_hMenuTier2;
	
	g_hMenuTier2 = CreateMenu(MenuHandler_BuyMenu);
	g_hMenuTier2.SetTitle("商店菜单 - 步枪/连喷");
	g_hMenuTier2.AddItem("rifle", MakeItemCost("M16步枪", g_pCvarM16));
	g_hMenuTier2.AddItem("rifle_desert", MakeItemCost("三连发步枪", g_pCvarDesert));
	g_hMenuTier2.AddItem("rifle_ak47", MakeItemCost("AK47步枪", g_pCvarAK47));
	g_hMenuTier2.AddItem("rifle_sg552", MakeItemCost("SG552步枪", g_pCvarSG552));
	g_hMenuTier2.AddItem("autoshotgun", MakeItemCost("一代连喷", g_pCvarXM1014));
	g_hMenuTier2.AddItem("shotgun_spas", MakeItemCost("二代连喷", g_pCvarSpas));
	g_hMenuTier2.ExitBackButton = true;
	g_hMenuTier2.ExitButton = true;
	
	if(g_hMenuTier3 != null)
		delete g_hMenuTier3;
	
	g_hMenuTier3 = CreateMenu(MenuHandler_BuyMenu);
	g_hMenuTier3.SetTitle("商店菜单 - 狙击/机枪/手枪");
	g_hMenuTier3.AddItem("hunting_rifle", MakeItemCost("15发连狙", g_pCvarHunting));
	g_hMenuTier3.AddItem("sniper_military", MakeItemCost("30发连狙", g_pCvarG3SG1));
	g_hMenuTier3.AddItem("sniper_scout", MakeItemCost("Scout狙击枪", g_pCvarScout));
	g_hMenuTier3.AddItem("sniper_awp", MakeItemCost("AWP狙击枪", g_pCvarAWP));
	g_hMenuTier3.AddItem("rifle_m60", MakeItemCost("机枪", g_pCvarM60));
	g_hMenuTier3.AddItem("pistol", MakeItemCost("小手枪", g_pCvarPistol));
	g_hMenuTier3.AddItem("pistol_magnum", MakeItemCost("马格南", g_pCvarMagnum));
	g_hMenuTier3.ExitBackButton = true;
	g_hMenuTier3.ExitButton = true;
	
	if(g_hMenuMelee != null)
		delete g_hMenuMelee;
	
	g_hMenuMelee = CreateMenu(MenuHandler_BuyMenu);
	g_hMenuMelee.SetTitle("商店菜单 - 近战武器");
	g_hMenuMelee.AddItem("baseball_bat", MakeItemCost("棒球棒", g_pCvarBaseball));
	g_hMenuMelee.AddItem("cricket_bat", MakeItemCost("船桨", g_pCvarCricket));
	g_hMenuMelee.AddItem("crowbar", MakeItemCost("撬棍", g_pCvarCrowbar));
	g_hMenuMelee.AddItem("electric_guitar", MakeItemCost("吉他", g_pCvarGuitar));
	g_hMenuMelee.AddItem("fireaxe", MakeItemCost("消防斧", g_pCvarFireaxe));
	g_hMenuMelee.AddItem("frying_pan", MakeItemCost("平底锅", g_pCvarPan));
	g_hMenuMelee.AddItem("golfclub", MakeItemCost("高尔夫球棍", g_pCvarGolfclub));
	g_hMenuMelee.AddItem("katana", MakeItemCost("武士刀", g_pCvarKatana));
	g_hMenuMelee.AddItem("hunting_knife", MakeItemCost("小刀", g_pCvarKnife));
	g_hMenuMelee.AddItem("machete", MakeItemCost("开山刀", g_pCvarMachete));
	g_hMenuMelee.AddItem("riotshield", MakeItemCost("盾牌", g_pCvarShield));
	g_hMenuMelee.AddItem("tonfa", MakeItemCost("警棍", g_pCvarTonfa));
	g_hMenuMelee.ExitBackButton = true;
	g_hMenuMelee.ExitButton = true;
	
	if(g_hMenuItem != null)
		delete g_hMenuItem;
	
	g_hMenuItem = CreateMenu(MenuHandler_BuyMenu);
	g_hMenuItem.SetTitle("商店菜单 - 投掷/医疗");
	g_hMenuItem.AddItem("molotov", MakeItemCost("燃烧瓶", g_pCvarMolotov));
	g_hMenuItem.AddItem("pipe_bomb", MakeItemCost("土制炸弹", g_pCvarPipe));
	g_hMenuItem.AddItem("vomitjar", MakeItemCost("胆汁", g_pCvarBile));
	g_hMenuItem.AddItem("pain_pills", MakeItemCost("止痛药", g_pCvarPills));
	g_hMenuItem.AddItem("adrenaline", MakeItemCost("肾上腺素", g_pCvarAdren));
	g_hMenuItem.AddItem("first_aid_kit", MakeItemCost("医疗包", g_pCvarAidKit));
	g_hMenuItem.AddItem("defibrillator", MakeItemCost("电击器", g_pCvarDefib));
	g_hMenuItem.ExitBackButton = true;
	g_hMenuItem.ExitButton = true;
	
	if(g_hMenuUpgrade != null)
		delete g_hMenuUpgrade;
	
	g_hMenuUpgrade = CreateMenu(MenuHandler_UpgradeMenu);
	g_hMenuUpgrade.SetTitle("商店菜单 - 武器升级");
	g_hMenuUpgrade.AddItem("LASER_SIGHT", MakeItemCost("激光瞄准", g_pCvarLaser));
	g_hMenuUpgrade.AddItem("INCENDIARY_AMMO", MakeItemCost("燃烧子弹", g_pCvarFire));
	g_hMenuUpgrade.AddItem("EXPLOSIVE_AMMO", MakeItemCost("高爆子弹", g_pCvarExplode));
	g_hMenuUpgrade.AddItem("ammo", MakeItemCost("补充弹药", g_pCvarAmmo));
	g_hMenuUpgrade.ExitBackButton = true;
	g_hMenuUpgrade.ExitButton = true;
	
	if(g_hMenuZombie != null)
		delete g_hMenuZombie;
	
	g_hMenuZombie = CreateMenu(MenuHandler_Zombie);
	g_hMenuZombie.SetTitle("商店菜单 - 刷怪");
	g_hMenuZombie.AddItem("mob", MakeItemCost("暴动尸群", g_pCvarMob));
	g_hMenuZombie.AddItem("smoker", MakeItemCost("舌头（Smoker）", g_pCvarSmoker));
	g_hMenuZombie.AddItem("boomer", MakeItemCost("胖子（Boomer）", g_pCvarBoomer));
	g_hMenuZombie.AddItem("hunter", MakeItemCost("猎人（Hunter）", g_pCvarHunter));
	g_hMenuZombie.AddItem("spitter", MakeItemCost("口水（Spitter）", g_pCvarSpitter));
	g_hMenuZombie.AddItem("jockey", MakeItemCost("猴子（Jockey）", g_pCvarJockey));
	g_hMenuZombie.AddItem("charger", MakeItemCost("牛（Charger）", g_pCvarCharger));
	g_hMenuZombie.AddItem("witch", MakeItemCost("萌妹（Witch）", g_pCvarWitch));
	g_hMenuZombie.AddItem("tank", MakeItemCost("克（Tank）", g_pCvarTank));
	g_hMenuZombie.ExitBackButton = true;
	g_hMenuZombie.ExitButton = true;
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!IsValidAliveClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			SC_ShowMainMenu(client);
		
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	switch(select)
	{
		case 0:
		{
			g_hMenuTier1.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuTier1), SC_GetClientCash(client)));
			g_hMenuTier1.Display(client, MENU_TIME_FOREVER);
		}
		case 1:
		{
			g_hMenuTier2.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuTier2), SC_GetClientCash(client)));
			g_hMenuTier2.Display(client, MENU_TIME_FOREVER);
		}
		case 2:
		{
			g_hMenuTier3.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuTier3), SC_GetClientCash(client)));
			g_hMenuTier3.Display(client, MENU_TIME_FOREVER);
		}
		case 3:
		{
			g_hMenuMelee.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuMelee), SC_GetClientCash(client)));
			g_hMenuMelee.Display(client, MENU_TIME_FOREVER);
		}
		case 4:
		{
			g_hMenuItem.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuItem), SC_GetClientCash(client)));
			g_hMenuItem.Display(client, MENU_TIME_FOREVER);
		}
		case 5:
		{
			g_hMenuUpgrade.SetTitle(tr("%s\n当前金钱：%d", GetMenuTitleNaked(g_hMenuUpgrade), SC_GetClientCash(client)));
			g_hMenuUpgrade.Display(client, MENU_TIME_FOREVER);
		}
		default:
		{
			Cmd_BuyMenu(client, menu.ExitBackButton ? -1 : 0);
			PrintToChat(client, "\x03[提示]\x01 无效的选项。");
		}
	}
	
	return 0;
}

public int MenuHandler_BuyMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!IsValidAliveClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			Cmd_BuyMenu(client, g_hMenuMain.ExitBackButton ? -1 : 0);
		
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	int cash = SC_GetClientCash(client);
	
	char display[255];
	GetMenuTitleNaked(menu, display, 255);
	menu.SetTitle(tr("%s\n当前金钱：%d", display, cash));
	
	int cost = GetMenuItemCost(menu, select, display, 255);
	if(cost == -1)
	{
		PrintToChat(client, "\x03[提示]\x04%s 暂时缺货。", display);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	if(cost > 0 && cost > cash)
	{
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 失败，金钱不足。需要：\x05%d\x01，现有：\x05%d\x01。",
			display, cost, cash);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	char info[64];
	menu.GetItem(select, info, 64);
	
	CheatCommand(client, "give", info);
	
	if(cost > 0)
	{
		SC_SetClientCash(client, cash - cost);
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 完成，花费：\x05%d\x01，剩余 \x05%d\x01 金钱。",
			display, cost, SC_GetClientCash(client));
	}
	else
	{
		PrintToChat(client, "\x03[提示]\x01 获取 \x04%s\x01 完成。", display);
	}
	
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	return 0;
}

public int MenuHandler_UpgradeMenu(Menu menu, MenuAction action, int client, int select)
{
	if(!IsValidAliveClient(client))
		return 0;
	
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
			Cmd_BuyMenu(client, g_hMenuMain.ExitBackButton ? -1 : 0);
		
		return 0;
	}
	
	if(action != MenuAction_Select)
		return 0;
	
	int cash = SC_GetClientCash(client);
	
	char display[255];
	GetMenuTitleNaked(menu, display, 255);
	menu.SetTitle(tr("%s\n当前金钱：%d", display, cash));
	
	int cost = GetMenuItemCost(menu, select, display, 255);
	if(cost == -1)
	{
		PrintToChat(client, "\x03[提示]\x04%s 暂时缺货。", display);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	if(cost > 0 && cost > cash)
	{
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 失败，金钱不足。需要：\x05%d\x01，现有：\x05%d\x01。",
			display, cost, cash);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	char info[64];
	menu.GetItem(select, info, 64);
	
	if(!StrEqual(info, "ammo", false))
		CheatCommand(client, "upgrade_add", info);
	else
		CheatCommand(client, "give", info);
	
	if(cost > 0)
	{
		SC_SetClientCash(client, cash - cost);
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 完成，剩余 \x05%d\x01 金钱。",
			display, SC_GetClientCash(client));
	}
	else
	{
		PrintToChat(client, "\x03[提示]\x01 获取 \x04%s\x01 完成。", display);
	}
	
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	return 0;
}

public int MenuHandler_Zombie(Menu menu, MenuAction action, int client, int select)
{
	if(!IsValidAliveClient(client))
		return 0;
	
	if(action != MenuAction_Select)
		return 0;
	
	int cash = SC_GetClientCash(client);
	
	char display[255];
	GetMenuTitleNaked(menu, display, 255);
	menu.SetTitle(tr("%s\n当前金钱：%d", display, cash));
	
	int cost = GetMenuItemCost(menu, select, display, 255);
	if(cost == -1)
	{
		PrintToChat(client, "\x03[提示]\x04%s 暂时缺货。", display);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	if(cost > 0 && cost > cash)
	{
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 失败，金钱不足。需要：\x05%d\x01，现有：\x05%d\x01。",
			display, cost, cash);
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		return 0;
	}
	
	char info[64];
	menu.GetItem(select, info, 64);
	CheatCommand(client, "z_spawn", info);
	
	if(cost > 0)
	{
		SC_SetClientCash(client, cash - cost);
		PrintToChat(client, "\x03[提示]\x01 购买 \x04%s\x01 完成，剩余 \x05%d\x01 金钱。",
			display, SC_GetClientCash(client));
	}
	else
	{
		PrintToChat(client, "\x03[提示]\x01 获取 \x04%s\x01 完成。", display);
	}
	
	menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	return 0;
}

char GetMenuTitleNaked(Menu menu, char[] buffer = "", int len = 0)
{
	char text[255], exp[2][128];
	
	if(menu == null)
		return exp[0];
	
	menu.GetTitle(text, 255);
	ExplodeString(text, "\n", exp, 2, 255);
	TrimString(exp[0]);
	
	if(len > 0)
		strcopy(buffer, len, exp[0]);
	
	return exp[0];
}

int GetMenuItemCost(Menu menu, int item, char[] buffer = "", int len = 0)
{
	if(menu == null)
		return -1;
	
	static Regex re;
	if(re == null)
		re = CompileRegex("\\[(缺货|免费|\\d+)\\]", PCRE_UTF8|PCRE_CASELESS);
	
	char text[255], display[255];
	menu.GetItem(item, text, 255, _, display, 255);
	
	int count = re.Match(display);
	if(count <= -1)
		return -1;
	
	re.GetSubString(count - 1, text, 255);
	ReplaceString(display, 255, text, "");
	ReplaceString(display, 255, "[", "", false);
	ReplaceString(display, 255, "]", "", false);
	TrimString(text);
	TrimString(display);
	
	if(len > 0)
		strcopy(buffer, len, display);
	
	if(StrEqual(text, "缺货", false))
		return -1;
	
	if(StrEqual(text, "免费", false))
		return 0;
	
	return StringToInt(text);
}

stock char tr(const char[] text, any ...)
{
	char buffer[255];
	VFormat(buffer, 255, text, 2);
	return buffer;
}

void CheatCommand(int client, const char[] command, const char[] buffer = "", any ...)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	
	char args[255];
	VFormat(args, 255, tr("%s \"%s\"", command, buffer), 4);
	
	if(IsValidClient(client))
		FakeClientCommand(client, args);
	else
		ServerCommand(args);
	
	SetCommandFlags(command, flags);
}

char MakeItemCost(const char[] text, ConVar cvar)
{
	char buffer[255];
	strcopy(buffer, 255, text);
	
	int cost = cvar.IntValue;
	if(cost <= -1)
		StrCat(buffer, 255, " [缺货]");
	else if(cost == 0)
		StrCat(buffer, 255, " [免费]");
	else
		StrCat(buffer, 255, tr(" [%d]", cost));
	
	return buffer;
}
