#include <sourcemod>
#include <sdktools>
#include <regex>
#include <nmrih_status>

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "积分商店",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
}

#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

Panel hMenuMain, hMenuDeath;
float vecStart[2][3], vecDeath[MAXPLAYERS + 1][2][3];
Menu hMenuPistol, hMenuSMG, hMenuRifle, hMenuShotGun, hMenuSniper, hMenuMelee, hMenuTool, hMenuMedkit, hMenuGreande, hMenuAmmo;
//static const char gPickupSound[3][] = {"player/ammo_pickup_01.wav", "player/ammo_pickup_02.wav", "player/ammo_pickup_03.wav"};
ConVar	gCvarAllow, gCvarCostPistol[5], gCvarCostSMG[2], gCvarCostRifle[10], gCvarCostShotgun[4], gCvarCostSnipe[3], gCvarCostAmmo[12],
		gCvarCostMelee[16], gCvarCostTool[6], gCvarCostMedkit[4], gCvarCostGrenade[3], gCvarCostRespawn[4];

public OnPluginStart()
{
	CreateConVar("nmp_ps_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllow = CreateConVar("nmp_ps_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	gCvarCostPistol[0] = CreateConVar("nmp_ps_m92fs", "150", "M9手枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostPistol[1] = CreateConVar("nmp_ps_sw686", "180", "左轮手枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostPistol[2] = CreateConVar("nmp_ps_1911", "-1", "1911手枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostPistol[3] = CreateConVar("nmp_ps_mkiii", "120", "BB枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostPistol[4] = CreateConVar("nmp_ps_glock17", "180", "cs土匪手枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostSMG[0] = CreateConVar("nmp_ps_mp5a4", "580", "MP5冲锋枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostSMG[1] = CreateConVar("nmp_ps_mac10", "500", "MAC冲锋枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostRifle[0] = CreateConVar("nmp_ps_1022", "580", "鸟枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[1] = CreateConVar("nmp_ps_1892", "625", "多子弹小枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[2] = CreateConVar("nmp_ps_sks", "-1", "刺刀步枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[3] = CreateConVar("nmp_ps_m16a4", "-1", "M16步枪带瞄准 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[4] = CreateConVar("nmp_ps_cz858", "750", "AK47步枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[5] = CreateConVar("nmp_ps_deerhunter", "-1", "弓 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[6] = CreateConVar("nmp_ps_fnfal", "675", "点射用步枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[7] = CreateConVar("nmp_ps_m16a1", "725", "M16步枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[8] = CreateConVar("nmp_ps_1022a1", "600", "鸟枪大弹夹版 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRifle[9] = CreateConVar("nmp_ps_sks2", "650", "刺刀步枪没刀版 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostShotgun[0] = CreateConVar("nmp_ps_870", "-1", "连发霰弹枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostShotgun[1] = CreateConVar("nmp_ps_500a", "540", "小喷 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostShotgun[2] = CreateConVar("nmp_ps_superx3", "545", "小霰弹枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostShotgun[3] = CreateConVar("nmp_ps_sv10", "560", "双管 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostSnipe[0] = CreateConVar("nmp_ps_sako85", "890", "猎枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostSnipe[1] = CreateConVar("nmp_ps_jae700", "980", "AWP狙击枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostSnipe[2] = CreateConVar("nmp_ps_sako852", "475", "猎枪没镜版 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostTool[0] = CreateConVar("nmp_ps_welder", "2000", "焊枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostTool[1] = CreateConVar("nmp_ps_extinguisher", "450", "灭火器 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostTool[2] = CreateConVar("nmp_ps_flare_gun", "3000", "叫补给的枪 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostTool[3] = CreateConVar("nmp_ps_barricade", "98", "木板锤 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostTool[4] = CreateConVar("nmp_ps_maglite", "50", "手电筒 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostTool[5] = CreateConVar("nmp_ps_walkietalkie", "15", "对讲机 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostMedkit[0] = CreateConVar("nmp_ps_bandages", "800", "绷带 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMedkit[1] = CreateConVar("nmp_ps_first_aid", "1350", "医疗包 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMedkit[2] = CreateConVar("nmp_ps_pills", "1000", "抗感染药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMedkit[3] = CreateConVar("nmp_ps_gene_therapy", "-1", "感染疫苗 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostGrenade[0] = CreateConVar("nmp_ps_molotov", "360", "燃烧瓶 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostGrenade[1] = CreateConVar("nmp_ps_grenade", "320", "手榴弹 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostGrenade[2] = CreateConVar("nmp_ps_tnt", "-1", "超级炸弹 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostAmmo[0] = CreateConVar("nmp_ps_9mm", "45", "低伤害武器弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[1] = CreateConVar("nmp_ps_45acp", "65", "破甲弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[2] = CreateConVar("nmp_ps_357", "60", ".357 左轮弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[3] = CreateConVar("nmp_ps_12gauge", "59", "霰弹枪弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[4] = CreateConVar("nmp_ps_22lr", "35", "鸟枪弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[5] = CreateConVar("nmp_ps_308", "50", "狙击枪弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[6] = CreateConVar("nmp_ps_556", "54", "M16弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[7] = CreateConVar("nmp_ps_762mm", "56", "AK47弹药 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[8] = CreateConVar("nmp_ps_arrow", "100", "弓箭 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[9] = CreateConVar("nmp_ps_fuel", "-1", "电锯的燃料 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[10] = CreateConVar("nmp_ps_board", "5", "木板 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostAmmo[11] = CreateConVar("nmp_ps_flare", "-1", "信号弹 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostMelee[0] = CreateConVar("nmp_ps_machete", "200", "开山刀 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[1] = CreateConVar("nmp_ps_axe_fire", "225", "消防斧 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[2] = CreateConVar("nmp_ps_crowbar", "180", "物理学圣剑 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[3] = CreateConVar("nmp_ps_bat", "120", "棒球棒 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[4] = CreateConVar("nmp_ps_hatchet", "205", "劈柴斧 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[5] = CreateConVar("nmp_ps_kitknife", "75", "水果刀 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[6] = CreateConVar("nmp_ps_pipe", "200", "水管 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[7] = CreateConVar("nmp_ps_sledge", "265", "大锤子 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[8] = CreateConVar("nmp_ps_shovel", "150", "铁铲 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[9] = CreateConVar("nmp_ps_wrench", "100", "扳手 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[10] = CreateConVar("nmp_ps_etool", "150", "工兵铲 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[11] = CreateConVar("nmp_ps_fubar", "240", "大扳手 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[12] = CreateConVar("nmp_ps_chainsaw", "-1", "电锯 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[13] = CreateConVar("nmp_ps_abrasivesaw", "-1", "锯木锯 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[14] = CreateConVar("nmp_ps_cleaver", "95", "菜刀 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostMelee[15] = CreateConVar("nmp_ps_pickaxe", "150", "稿子 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	gCvarCostRespawn[0] = CreateConVar("nmp_ps_respawn_start", "180", "复活到出生点 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[1] = CreateConVar("nmp_ps_respawn_death", "200", "复活到死亡处 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[2] = CreateConVar("nmp_ps_respawn_alive", "225", "复活到队友旁 多少积分一只", CVAR_FLAGS, true, -1.0);
	gCvarCostRespawn[3] = CreateConVar("nmp_ps_respawn_team", "175", "复活别人 多少积分一只", CVAR_FLAGS, true, -1.0);
	
	AutoExecConfig(true, "nmp_point_shop");
	RegConsoleCmd("buy", Cmd_BuyMenu, "买东西");
	RegConsoleCmd("ammo", Cmd_BuyAmmo, "买子弹");
	InitAllMenu();
	
	HookEvent("nmrih_round_begin", Event_RoundStart);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("game_round_restart", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
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
	hMenuMain = CreatePanel();
	hMenuMain.SetTitle("========= 购买菜单 =========");
	hMenuMain.DrawItem("手枪 (Pistols)");
	hMenuMain.DrawItem("冲锋枪/手榴弹 (SMG/Grenade)");
	hMenuMain.DrawItem("步枪 (Rifle)");
	hMenuMain.DrawItem("霰弹枪 (Shotgun)");
	hMenuMain.DrawItem("狙击枪 (Sniper)");
	hMenuMain.DrawItem("工具 (Tools)");
	hMenuMain.DrawItem("医疗品 (Medkit)");
	hMenuMain.DrawItem("弹药 (Ammo)");
	hMenuMain.DrawItem("近战武器 (Melee)");
	//hMenuMain.DrawItem("投掷武器 (Grenade)", ITEMDRAW_DEFAULT);
	hMenuMain.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
	
	hMenuPistol = CreateMenu(MF_BuyMenu);
	hMenuPistol.SetTitle("购买菜单 - 手枪 (Pistol)");
	hMenuPistol.AddItem("fa_m92fs", fic("Beretta M9", gCvarCostPistol[0].IntValue));
	hMenuPistol.AddItem("fa_sw686", fic("Smith & Wesson 686", gCvarCostPistol[1].IntValue));
	hMenuPistol.AddItem("fa_1911", fic("Colt M1911", gCvarCostPistol[2].IntValue));
	hMenuPistol.AddItem("fa_mkiii", fic("Ruger MkIII", gCvarCostPistol[3].IntValue));
	hMenuPistol.AddItem("fa_glock17", fic("Glock 17", gCvarCostPistol[4].IntValue));
	hMenuPistol.ExitButton = true;
	hMenuPistol.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuPistol.ExitBackButton = true;
	
	hMenuSMG = CreateMenu(MF_BuyMenu);
	hMenuSMG.SetTitle("购买菜单 - 冲锋枪/手榴弹 (SobMachineGun/Grenade)");
	hMenuSMG.AddItem("fa_mp5a3", fic("Heckler & Koch MP5A4", gCvarCostSMG[0].IntValue));
	hMenuSMG.AddItem("fa_mac10", fic("Ingram Mac-10", gCvarCostSMG[1].IntValue));
	hMenuSMG.AddItem("exp_molotov", fic("燃烧瓶 (Molotov)", gCvarCostGrenade[0].IntValue));
	hMenuSMG.AddItem("exp_grenade", fic("手榴弹 (Grenade)", gCvarCostGrenade[1].IntValue));
	hMenuSMG.AddItem("exp_tnt", fic("高爆炸弹 (TNT)", gCvarCostGrenade[2].IntValue));
	hMenuSMG.ExitButton = true;
	hMenuSMG.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuSMG.ExitBackButton = true;
	
	hMenuRifle = CreateMenu(MF_BuyMenu);
	hMenuRifle.SetTitle("购买菜单 - 步枪 (Rifle)");
	hMenuRifle.AddItem("fa_1022", fic("Ruger 10/22", gCvarCostRifle[0].IntValue));
	hMenuRifle.AddItem("fa_sks", fic("Simonov SKS", gCvarCostRifle[1].IntValue));
	hMenuRifle.AddItem("fa_m16a4", fic("M16 A4", gCvarCostRifle[2].IntValue));
	hMenuRifle.AddItem("fa_winchester1892", fic("Winchester 1892", gCvarCostRifle[3].IntValue));
	hMenuRifle.AddItem("fa_cz858", fic("CZech 858", gCvarCostRifle[4].IntValue));
	hMenuRifle.AddItem("fa_deerhunter", fic("PSE Deer Hunter", gCvarCostRifle[5].IntValue));
	hMenuRifle.AddItem("fa_fnfal", fic("FN FAL", gCvarCostRifle[6].IntValue));
	hMenuRifle.AddItem("fa_m16a4_carryhandle", fic("M16A4 Carry Handle", gCvarCostRifle[7].IntValue));
	hMenuRifle.AddItem("fa_1022_25mag", fic("Ruger 10/22 Extended", gCvarCostRifle[8].IntValue));
	hMenuRifle.AddItem("fa_sks_nobayo", fic("Simonov SKS No Bayonet", gCvarCostRifle[9].IntValue));
	hMenuRifle.ExitButton = true;
	hMenuRifle.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuRifle.ExitBackButton = true;
	
	hMenuShotGun = CreateMenu(MF_BuyMenu);
	hMenuShotGun.SetTitle("购买菜单 - 霰弹枪 (Shotgun)");
	hMenuShotGun.AddItem("fa_870", fic("Remington 870", gCvarCostShotgun[0].IntValue));
	hMenuShotGun.AddItem("fa_500a", fic("Mossberg 500A", gCvarCostShotgun[1].IntValue));
	hMenuShotGun.AddItem("fa_superx3", fic("Winchester Super X3", gCvarCostShotgun[2].IntValue));
	hMenuShotGun.AddItem("fa_sv10", fic("Beretta Perennia SV10", gCvarCostShotgun[3].IntValue));
	hMenuShotGun.ExitButton = true;
	hMenuShotGun.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuShotGun.ExitBackButton = true;
	
	hMenuSniper = CreateMenu(MF_BuyMenu);
	hMenuSniper.SetTitle("购买菜单 - 狙击枪 (Sniper)");
	hMenuSniper.AddItem("fa_sako85", fic("Sako 85", gCvarCostSnipe[0].IntValue));
	hMenuSniper.AddItem("fa_jae700", fic("JAE 700", gCvarCostSnipe[1].IntValue));
	hMenuSniper.AddItem("fa_sako85_ironsights", fic("Sako 85 Ironsights", gCvarCostSnipe[2].IntValue));
	hMenuSniper.ExitButton = true;
	hMenuSniper.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuSniper.ExitBackButton = true;
	
	hMenuTool = CreateMenu(MF_BuyMenu);
	hMenuTool.SetTitle("购买菜单 - 工具 (Tools)");
	hMenuTool.AddItem("tool_welder", fic("焊枪 (Cutting Torch)", gCvarCostTool[0].IntValue));
	hMenuTool.AddItem("tool_extinguisher", fic("灭火器 (Fire Extinguisher)", gCvarCostTool[1].IntValue));
	hMenuTool.AddItem("tool_flare_gun", fic("信号枪 (Flaregun)", gCvarCostTool[2].IntValue));
	hMenuTool.AddItem("tool_barricade", fic("钉板锤 (Barricade Hammer)", gCvarCostTool[3].IntValue));
	hMenuTool.AddItem("item_maglite", fic("手电筒 (Maglite)", gCvarCostTool[4].IntValue));
	hMenuTool.AddItem("item_walkietalkie", fic("对讲机 (Walkie Talkie)", gCvarCostTool[5].IntValue));
	hMenuTool.ExitButton = true;
	hMenuTool.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuTool.ExitBackButton = true;
	
	hMenuMedkit = CreateMenu(MF_BuyMenu);
	hMenuMedkit.SetTitle("购买菜单 - 医疗品 (Medkit)");
	hMenuMedkit.AddItem("item_bandages", fic("绷带 (Bandages)", gCvarCostMedkit[0].IntValue));
	hMenuMedkit.AddItem("item_first_aid", fic("医疗包 (First Aid Kit)", gCvarCostMedkit[1].IntValue));
	hMenuMedkit.AddItem("item_pills", fic("缓和药 (Phalanx Pills)", gCvarCostMedkit[2].IntValue));
	hMenuMedkit.AddItem("item_gene_therapy", fic("抗生素 (Gene Therapy)", gCvarCostMedkit[3].IntValue));
	hMenuMedkit.ExitButton = true;
	hMenuMedkit.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuMedkit.ExitBackButton = true;
	
	hMenuMelee = CreateMenu(MF_BuyMenu);
	hMenuMelee.SetTitle("购买菜单 - 近战武器 (Melee)");
	hMenuMelee.AddItem("me_machete", fic("开山刀 (Machete)", gCvarCostMelee[0].IntValue));
	hMenuMelee.AddItem("me_axe_fire", fic("消防斧 (Fire Axe)", gCvarCostMelee[1].IntValue));
	hMenuMelee.AddItem("me_crowbar", fic("撬棍 (Crowbar)", gCvarCostMelee[2].IntValue));
	hMenuMelee.AddItem("me_bat_metal", fic("棒球棒 (Batmetal)", gCvarCostMelee[3].IntValue));
	hMenuMelee.AddItem("me_hatchet", fic("小斧头 (Hatchet)", gCvarCostMelee[4].IntValue));
	hMenuMelee.AddItem("me_kitknife", fic("水果刀 (Kit Knife)", gCvarCostMelee[5].IntValue));
	hMenuMelee.AddItem("me_pipe_lead", fic("水管 (Lead Pipe)", gCvarCostMelee[6].IntValue));
	hMenuMelee.AddItem("me_sledge", fic("大锤子 (Sledge)", gCvarCostMelee[7].IntValue));
	hMenuMelee.AddItem("me_cleaver", fic("菜刀 (Cleaver)", gCvarCostMelee[14].IntValue));
	hMenuMelee.AddItem("me_pickaxe", fic("稿子 (Pickaxe)", gCvarCostMelee[15].IntValue));
	hMenuMelee.AddItem("me_shovel", fic("铁铲 (Shovel)", gCvarCostMelee[8].IntValue));
	hMenuMelee.AddItem("me_wrench", fic("扳手 (Wrench)", gCvarCostMelee[9].IntValue));
	hMenuMelee.AddItem("me_etool", fic("工兵铲 (Etool)", gCvarCostMelee[10].IntValue));
	hMenuMelee.AddItem("me_fubar", fic("大扳手 (Fubar)", gCvarCostMelee[11].IntValue));
	hMenuMelee.AddItem("me_chainsaw", fic("电锯 (Chainsaw)", gCvarCostMelee[12].IntValue));
	hMenuMelee.AddItem("me_abrasivesaw", fic("木板锯 (Abrasivesaw)", gCvarCostMelee[13].IntValue));
	hMenuMelee.ExitButton = true;
	hMenuMelee.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuMelee.ExitBackButton = true;
	
	//hMenuAmmo = CreateMenu(MF_AmmoMenu);
	hMenuAmmo = CreateMenu(MF_BuyMenu);
	hMenuAmmo.SetTitle("购买菜单 - 弹药 (Ammo)");
	hMenuAmmo.AddItem("AmmoType:1", fic("9mm", gCvarCostAmmo[0].IntValue));
	hMenuAmmo.AddItem("AmmoType:2", fic(".45 ACP", gCvarCostAmmo[1].IntValue));
	hMenuAmmo.AddItem("AmmoType:3", fic(".357", gCvarCostAmmo[2].IntValue));
	hMenuAmmo.AddItem("AmmoType:4", fic("12 Gauge", gCvarCostAmmo[3].IntValue));
	hMenuAmmo.AddItem("AmmoType:5", fic(".22 LR", gCvarCostAmmo[4].IntValue));
	hMenuAmmo.AddItem("AmmoType:6", fic(".308", gCvarCostAmmo[5].IntValue));
	hMenuAmmo.AddItem("AmmoType:7", fic("5.56mm", gCvarCostAmmo[6].IntValue));
	hMenuAmmo.AddItem("AmmoType:8", fic("7.62x39", gCvarCostAmmo[7].IntValue));
	hMenuAmmo.AddItem("AmmoType:12", fic("Arrow 弓箭", gCvarCostAmmo[8].IntValue));
	hMenuAmmo.AddItem("AmmoType:13", fic("Fuel 燃料", gCvarCostAmmo[9].IntValue));
	hMenuAmmo.AddItem("AmmoType:14", fic("Boards 木板", gCvarCostAmmo[10].IntValue));
	hMenuAmmo.AddItem("AmmoType:15", fic("Flares 信号弹", gCvarCostAmmo[11].IntValue));
	hMenuAmmo.ExitButton = true;
	hMenuAmmo.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuAmmo.ExitBackButton = true;
	
	hMenuGreande = CreateMenu(MF_BuyMenu);
	hMenuGreande.SetTitle("购买菜单 - 投掷武器 (Greande)");
	hMenuGreande.AddItem("exp_molotov", fic("燃烧瓶 (Molotov)", gCvarCostGrenade[0].IntValue));
	hMenuGreande.AddItem("exp_grenade", fic("手榴弹 (Grenade)", gCvarCostGrenade[1].IntValue));
	hMenuGreande.AddItem("exp_tnt", fic("高爆炸弹 (TNT)", gCvarCostGrenade[2].IntValue));
	hMenuGreande.ExitButton = true;
	hMenuGreande.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenuGreande.ExitBackButton = true;
	
	hMenuDeath = CreatePanel();
	hMenuDeath.SetTitle("========= 购买菜单 =========");
	hMenuDeath.DrawItem(fic("复活到出发点", gCvarCostRespawn[0].IntValue));
	hMenuDeath.DrawItem(fic("复活到死亡点", gCvarCostRespawn[1].IntValue));
	hMenuDeath.DrawItem(fic("复活到队友旁", gCvarCostRespawn[2].IntValue));
	hMenuDeath.DrawItem(fic("复活到其他人", gCvarCostRespawn[3].IntValue));
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("", ITEMDRAW_NOTEXT);
	hMenuDeath.DrawItem("退出 (Exit)", ITEMDRAW_CONTROL);
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
		case 1:		RespawnPlayer(client, vecStart[0], vecStart[1]);
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
		hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
		hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
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
		hMenuDeath.SetTitle(tr("========= 购买菜单 =========\n\t*** 你有 %d 积分 ***", NMS_GetCoin(client)));
		hMenuDeath.Send(client, MF_DeathMenu, MENU_TIME_FOREVER);
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
			hMenuPistol.SetTitle(tr("购买菜单 - 手枪 (Pistols)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuPistol.Display(client, MENU_TIME_FOREVER);
		}
		case 2:
		{
			hMenuSMG.SetTitle(tr("购买菜单 - 冲锋枪/手榴弹 (SMG/Grenade)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuSMG.Display(client, MENU_TIME_FOREVER);
		}
		case 3:
		{
			hMenuRifle.SetTitle(tr("购买菜单 - 步枪 (Rifle)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuRifle.Display(client, MENU_TIME_FOREVER);
		}
		case 4:
		{
			hMenuShotGun.SetTitle(tr("购买菜单 - 霰弹枪 (Shotgun)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuShotGun.Display(client, MENU_TIME_FOREVER);
		}
		case 5:
		{
			hMenuSniper.SetTitle(tr("购买菜单 - 狙击枪 (Sniper)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuSniper.Display(client, MENU_TIME_FOREVER);
		}
		case 6:
		{
			hMenuTool.SetTitle(tr("购买菜单 - 工具 (Tools)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuTool.Display(client, MENU_TIME_FOREVER);
		}
		case 7:
		{
			hMenuMedkit.SetTitle(tr("购买菜单 - 医疗品 (Medkit)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuMedkit.Display(client, MENU_TIME_FOREVER);
		}
		case 8:
		{
			hMenuAmmo.SetTitle(tr("购买菜单 - 子弹 (Ammo)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuAmmo.Display(client, MENU_TIME_FOREVER);
		}
		case 9:
		{
			hMenuMelee.SetTitle(tr("购买菜单 - 近战武器 (Melee)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
			hMenuMelee.Display(client, MENU_TIME_FOREVER);
		}
		case 10:
		{
			/*
			hMenuGreande.SetTitle(tr("购买菜单 - 投掷武器 (Greande)\n\t*** 你有 %d 积分 ***", NMS_GetPoint(client)))
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
	
	int money = NMS_GetPoint(client);
	if(money < cost)
	{
		PrintToChat(client, "\x04[提示]\x01 你的积分不足以购买它。现有：%d 需要：%d", money, cost);
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	char item[64];
	menu.GetItem(select, item, 64);
	if(item[0] == '\0')
	{
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	if(StrContains(item, "AmmoType:", false) == -1 && GetPlayerWeapon(client, item) > MaxClients)
	{
		PrintToChat(client, "\x04[提示]\x01 你已经有这个武器了，不需要购买。");
		CreateTimer(0.1, Timer_WaitDisplayMenu, data);
		return;
	}
	
	NMS_ChangePoint(client, -cost);
	money -= cost;
	
	if(StrContains(item, "AmmoType:", false) == 0)
	{
		char ammo[2][32];
		ExplodeString(item, ":", ammo, 2, 32);
		SetRandomSeed(RoundFloat(GetEngineTime()));
		int type = StringToInt(ammo[1]), count = GetRandomInt(5, 15);
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
		}
	}
	
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
	SetVariantString("OnUser1 !self:Kill::3:1");
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
	if(gCvarAllow.IntValue < 1 || !NMS_IsClientValid(client))
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
	
	int cost = gCvarCostAmmo[(type >= 12 ? type - 4 : type - 1)].IntValue;
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
stock char tr(const char[] text, any ...)
{
	char result[1024];
	VFormat(result, 1024, text, 2);
	return result;
}

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
stock int GetPlayerWeapon(client, const char[] weapon)
{
	static int offs;
	if(offs <= 0)
		offs = FindSendPropOffs("CNMRiH_Player", "m_hMyWeapons");
	if(offs <= 0)
		return -1;
	
	int entity = -1;
	char classname[128] = "";
	for(int i = 0; i <= 192; i += 4)
	{
		entity = GetEntDataEnt2(client, offs + i);
		if(!IsValidEntity(entity))
			continue;
		
		GetEntityClassname(entity, classname, 128);
		if(strcmp(classname, weapon, false) == 0)
			return entity;
	}
	
	return 0;
}
