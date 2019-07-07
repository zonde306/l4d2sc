#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo = {
	name = "自动清理地上物品",
	author = "防止刷出过多的物品卡服",
	description = "zonde306",
	version = PLUGIN_VERSION,
	url = ""
};

new bool:g_bPlayerDead = false;
new bool:g_bGameLoadS = false;
new g_iItemCount;

new Handle:g_hCvarItemMax = INVALID_HANDLE;
//new Handle:g_hCvarClanTime = INVALID_HANDLE;
new Handle:g_hCvarPlayer = INVALID_HANDLE;
new Handle:g_hCvarClan = INVALID_HANDLE;

new Handle:g_hTimerGl;
/*
#define ITEMCOUNT 49
static const String:zsItemClassName[ITEMCOUNT][20] = 
{
	"fa_m92fs", "fa_sw686", "fa_1911", "fa_mkiii", "fa_glock17",
	"fa_1022", "fa_sako85", "fa_sks", "fa_m16a4", "fa_winchester1892", "fa_cz858", "bow_deerhunter", "fa_jae700", "fa_fnfal", "fa_m16a4_carryhandle", "fa_1022_25mag",
	"fa_870", "fa_500a", "fa_superx3", "fa_sv10",
	"fa_mp5a3", "fa_mac10",
	"me_machete", "me_axe_fire", "me_crowbar", "me_bat_metal", "me_hatchet", "me_kitknife", "me_pipe_lead", "me_sledge", "me_shovel", "me_wrench", "me_chainsaw", "me_etool", "me_fubar", "me_abrasivesaw",
	"tool_welder", "tool_extinguisher", "tool_flare_gun", "tool_barricade", "item_maglite", "item_walkietalkie",
	"item_bandages", "item_first_aid", "item_pills",
	"exp_molotov", "exp_grenade", "exp_tnt", "item_ammo_box"
};

static const String:zsZombieClassName[3][32] = 
{
	"npc_nmrih_shamblerzombie",
	"npc_nmrih_turnedzombie",
	"npc_nmrih_kidzombie"
};
*/
public OnPluginStart()
{
	CreateConVar("sm_claner_version", PLUGIN_VERSION, "插件版本");
	g_hCvarItemMax = CreateConVar("sm_claner_max", "15", "允许在短时间内创建物品的数量(防止恶意卡服)");
	//g_hCvarClanTime = CreateConVar("sm_claner_time", "30", "当一个物品从玩家身上掉落到地上等多久后自动删除");
	g_hCvarPlayer = CreateConVar("sm_claner_player", "1", "当玩家死亡后是否清理其掉落的物品");
	g_hCvarClan = CreateConVar("sm_claner_auto", "180", "每隔多少秒清理一次武器");
	
	AutoExecConfig(true, "nmp_claner");
	
	RegAdminCmd("sm_clanwpn", Command_Claner, ADMFLAG_CHEATS, "清理地上的武器");
	RegAdminCmd("sm_clanzb", Command_Zombie, ADMFLAG_CHEATS, "清理地上的僵尸");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy|EventHookMode_Post);
	//HookEvent("nmrih_round_begin", Event_RoundStart, EventHookMode_PostNoCopy|EventHookMode_Post);
	HookEvent("game_round_restart", Event_RoundEnd, EventHookMode_Pre);
	//HookEvent("nmrih_reset_map", Event_RoundEnd, EventHookMode_Pre);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bGameLoadS = false;
	PrintToServer("回合结束触发");
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(30.0, Time_GameLoading);
	g_iItemCount = 0;
	PrintToServer("回合开始触发");
}

public OnEntityCreated(iEntity, const String:szClassname[])
{
	if(g_bPlayerDead)
	{
		if(StrContains(szClassname, "fa_", false) == 0 || StrContains(szClassname, "me_", false) == 0 ||
			(StrContains(szClassname, "item_", false) == 0 && strcmp(szClassname, "tool_welder", false) != 0 &&
			strcmp(szClassname, "tool_extinguisher", false) != 0) || StrContains(szClassname, "exp_", false) == 0)
		{
			SDKHook(iEntity, SDKHook_SpawnPost, Hook_OnAmmoBoxSpawn);
		}
	}
	else if(g_bGameLoadS && GetConVarInt(g_hCvarItemMax) > 0)
	{
		g_iItemCount ++;
		new Handle:tmpTime;
		tmpTime = CreateTimer(1.5, Time_CClaner);
		if(g_iItemCount > (GetConVarInt(g_hCvarItemMax) * 2))
		{
			TriggerTimer(tmpTime, false);
		}
	}
}

public Action:Time_CClaner(Handle:timer, Handle:dataPack)
{
	if(g_iItemCount > GetConVarInt(g_hCvarItemMax))
	{
		/*new iEntity = -1;
		for(new i = 0; i <= g_iItemCount; i ++)
		{
			while((iEntity = FindEntityByClassname(iEntity, zsItemClassName[GetRandomInt(0, ITEMCOUNT)])) != INVALID_ENT_REFERENCE)
			{
				if(GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
				{
					AcceptEntityInput(iEntity, "Kill");
				}
			}
			
		}*/
		new maxent = GetMaxEntities(), String:item[64];
		for (new i = GetMaxClients(); i < maxent; i++)
		{
			if(IsValidEdict(i) && IsValidEntity(i))
			{
				GetEdictClassname(i, item, sizeof(item));
				if ((StrEqual("bow_deerhunter", item) || StrEqual("item_ammo_box", item) ||
				StrContains(item, "exp_", true) == 0 || StrContains(item, "fa_", true) == 0 ||
				StrContains(item, "item_", true) == 0 || (StrContains(item, "item_", false) == 0 &&
				strcmp(item, "tool_welder", false) != 0 && strcmp(item, "tool_extinguisher", false) != 0) ||
				StrContains(item, "me_", true) == 0 || StrEqual("projectile_arrow", item) ||
				StrContains(item, "tool_", true) == 0) && GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1)
				{
					RemoveEdict(i);
				}
			}
			if(g_iItemCount <= i)
			{
				break;
			}
		}
	}
	PrintToServer("在短时间内创建了：%d　个物品", g_iItemCount);
	g_iItemCount = 0;
}

public Hook_OnAmmoBoxSpawn(iEntity)
{
	AcceptEntityInput(iEntity, "Kill");
}

public Action:Command_Claner(client, arg)
{
	ClanAllItem(false);
}

public Action:Command_Zombie(client, arg)
{
	/*new iEntity = -1;
	PrintToServer("正在清理地上的僵尸中...");
	for(new i = 0; i <= 3; i ++)
	{
		if(GetRandomInt(1, 5) == 1)
		{
			continue;
		}
		
		while((iEntity = FindEntityByClassname(iEntity, zsZombieClassName[i])) != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(iEntity, "Kill");
		}
	}*/
	
	decl String:temp[32];
	new ent = CreateEntityByName("point_hurt");
	new maxent = GetMaxEntities(), String:item[64], num = 0;
	for (new i = GetMaxClients(); i < maxent; i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, item, sizeof(item));
			if (StrContains(item, "npc_nmrih_", true) == 0)
			{
				num++;
				//RemoveEdict(i);
				//SetEntityHealth(i, 0);
				//DispatchKeyValue(i, "health", "0");
				Format(temp, 32, "victim%d", i);
				DispatchKeyValue(i, "targetname", temp);
				DispatchKeyValue(ent, "DamageTarget", temp);
				DispatchKeyValueFloat(ent, "Damage", 65535.0);
				DispatchKeyValue(ent, "DamageType", "1");
				AcceptEntityInput(ent, "Hurt", -1);
			}
		}
	}
	
	AcceptEntityInput(ent, "Kill");
	PrintToServer("清理了：%d个僵尸", num);
}

public ClanAllItem(bool:brandom)
{
	/*new iEntity = -1;
	PrintToServer("正在清理地上的武器中...");
	for(new i = 0; i <= ITEMCOUNT; i ++)
	{
		if(brandom && GetRandomInt(1, 3) == 1)
		{
			continue;
		}
		
		while((iEntity = FindEntityByClassname(iEntity, zsItemClassName[i])) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
			{
				AcceptEntityInput(iEntity, "Kill");
			}
		}
	}*/
	new maxent = GetMaxEntities(), String:item[64], num = 0;
	for (new i = GetMaxClients(); i < maxent; i++)
	{
		if(brandom && GetRandomInt(1, 3) > 1)
		{
			continue;
		}
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, item, sizeof(item));
			if ((StrEqual("bow_deerhunter", item) || StrEqual("item_ammo_box", item) || StrContains(item, "exp_", true) == 0
			|| StrContains(item, "fa_", true) == 0 || (StrContains(item, "item_", true) == 0 &&
			strcmp(item, "tool_welder", false) != 0 && strcmp(item, "tool_extinguisher", false) != 0) ||
			StrContains(item, "me_", true) == 0 || StrEqual("projectile_arrow", item) ||
			StrContains(item, "tool_", true) == 0) && GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1)
			{
				num++;
				RemoveEdict(i);
			}
		}
	}
	PrintToServer("清理了：%d个物品", num);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(g_hCvarPlayer))
	{
		g_bPlayerDead = true;
		CreateTimer(1.0, Time_PlayerDeadClaner);
	}
}

public Action:Time_PlayerDeadClaner(Handle:timer, Handle:dataPack)
{
	g_bPlayerDead = false;
}

public OnMapEnd()
{
	g_bGameLoadS = false;
}

public OnMapStart()
{
	if(g_hTimerGl)
	{
		KillTimer(g_hTimerGl);
	}
	
	char maps[64];
	GetCurrentMap(maps, 64);
	if(GetConVarInt(g_hCvarClan) > 0 && StrContains(maps, "nmo_", false) != 0)
	{
		g_hTimerGl = CreateTimer(GetConVarFloat(g_hCvarClan), Time_AutoClanItem, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Time_GameLoading(Handle:timer, Handle:dataPack)
{
	g_bGameLoadS = true;
}

public Action:Time_AutoClanItem(Handle:timer, Handle:dataPack)
{
	ClanAllItem(true);
}