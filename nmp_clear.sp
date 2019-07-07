#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.1"
public Plugin myinfo = 
{
	name = "清理物品",
	author = "zonde306",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/"
}

#define MAX_EDICT			2048
#define IsValidClient(%1)	((1 <= %1 <= MaxClients) && IsClientInGame(%1))
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

bool gAllowThink = false;
Handle hTimerStart = INVALID_HANDLE;
ConVar gCvarAllow, gCvarMax, gCvarThink, gCvarDeath, gCvarDrop, gCvarKiller, gCvarLoot;

public void OnPluginStart()
{
	CreateConVar("nmp_claer_version", PLUGIN_VERSION, "插件版本",
		FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gCvarAllow = CreateConVar("nmp_claer_enable", "1", "是否开启插件", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarMax = CreateConVar("nmp_claer_max", "16", "单次刷出最大物品的数量.0=无限制", CVAR_FLAGS, true, 0.0);
	gCvarThink = CreateConVar("nmp_claer_time", "600", "没隔多少秒清理一次物品.0=不清理", CVAR_FLAGS, true, 0.0);
	gCvarDeath = CreateConVar("nmp_claer_death", "60", "清理死亡的玩家的遗物的延迟.0=不清理", CVAR_FLAGS, true, 0.0);
	gCvarDrop = CreateConVar("nmp_claer_drop", "180", "清理玩家扔掉的物品的延迟.0=不清理", CVAR_FLAGS, true, 0.0);
	gCvarKiller = CreateConVar("nmp_claer_killer", "0", "杀死过玩家的僵尸着火时间.0=不着火", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarLoot = CreateConVar("nmp_claer_loot", "0", "僵尸死亡掉落物品的几率", CVAR_FLAGS, true, 0.0, true, 100.0);
	
	RegAdminCmd("clanwpn", Cmd_ClearWeapon, ADMFLAG_CHEATS, "清理地上的武器");
	RegAdminCmd("clanzb", Cmd_ClearZombie, ADMFLAG_CHEATS, "清理地上的僵尸");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("npc_killed", Event_ZombieDeath);
	HookEvent("zombie_killed_by_fire", Event_ZombieDeath);
}

public void Event_ZombieDeath(Event event, const char[] event_name, bool send)
{
	int prob = gCvarLoot.IntValue;
	if(prob <= 0)
		return;
	
	int zombi = event.GetInt("entidx");
	if(!IsValidEntity(zombi))
		return;
	
	
}

public void Event_PlayerDeath(Event event, const char[] event_name, bool send)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	
	float fire = gCvarKiller.FloatValue;
	float clear = gCvarDeath.FloatValue;
	
	if(clear > 0.0)
	{
		DataPack pack = CreateDataPack();
		pack.WriteFloat(pos[0]);
		pack.WriteFloat(pos[1]);
		pack.WriteFloat(pos[2]);
		
		CreateTimer(clear, Timer_ClearDeathItem, pack);
	}
	
	if(fire <= 0.0)
		return;
	
	ArrayList array = CreateArray();
	TR_TraceHullFilter(pos, pos, Float:{3.0, 3.0, 3.0}, Float:{3.0, 3.0, 3.0}, MASK_NPCSOLID, THF_Zombie, array);
	
	int entity = -1;
	int size = array.GetSize();
	if(int i = 0; i < size; ++i)
	{
		entity = array.GetCell(i);
		if(!IsValidEntity(entity))
			continue;
		
		IgniteEntity(entity, fire, true);
	}
}

public bool THF_Zombie(int entity, int mask, any array)
{
	if(entity <= MaxClients || !IsValidEntity(entity))
		return false;
	
	char classname[128];
	GetEdictClassname(entity, classname, 128);
	if(StrContains(classname, "npc_nmrih_", false) == 0)
		array.PushCell(entity);
	
	return false;
}

public Action Timer_ClearDeathItem(Handle timer, any data)
{
	data.Reset();
	float pos[3];
	pos[0] = ReadFloat();
	pos[1] = ReadFloat();
	pos[2] = ReadFloat();
	delete data;
	
	TR_TraceHullFilter(pos, pos, Float:{25.0, 25.0, 25.0}, Float:{25.0, 25.0, 25.0}, MASK_SHOT_HULL, THF_Weapon);
}

public bool THF_Weapon(int entity, int mask, any data)
{
	if(entity <= MaxClients || !IsValidEntity(entity))
		return false;
	
	static int count;
	char classname[128];
	GetEdictClassname(entity, classname, 128);
	if(	GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == -1 && (StrContains(wpn, "bow_", false) == 0 ||
		StrContains(wpn, "me_", true) == 0 || StrEqual(wpn, "projectile_arrow", false) ||
		StrContains(wpn, "exp_", true) == 0 || StrContains(wpn, "fa_", true) == 0 ||
		(StrContains(wpn, "tool_", true) == 0 && !StrEqual(wpn, "tool_extinguisher", false) &&
		!StrEqual(wpn, "tool_welder", false)) || (StrContains(wpn, "item_", true) == 0 &&
		!StrEqual(wpn, "item_inventory_box", false))))
	{
		count++;
		AcceptEntityInput(entity, "Kill");
	}
	
	PrintToServer("[清理] 清理死亡的玩家的物品 %d 个。", count);
	count = 0;
	return false;
}

public void Event_RoundStart(Event event, const char[] event_name, bool send)
{
	gAllowThink = false;
	if(hTimerStart != INVALID_HANDLE)
		KillTimer(hTimerStart, true);
	CreateTimer(45.0, Timer_StartDelete);
}

public void Event_RoundEnd(Event event, const char[] event_name, bool send)
{
	gAllowThink = false;
	if(hTimerStart != INVALID_HANDLE)
	{
		KillTimer(hTimerStart, true);
		hTimerStart = INVALID_HANDLE;
	}
}

public Action Timer_StartDelete(Handle timer, any data)
{
	gAllowThink = true;
	hTimerStart = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action Cmd_ClearZombie(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	char classname[128], info[32];
	int count = 0, hurt = CreateEntityByName("point_hurt");
	for(int i = MaxClients + 1; i < MAX_EDICT; i++)
	{
		if(!IsValidEntity(i) || !IsValidEdict(i))
			continue;
		
		GetEdictClassname(i, wpn, 128);
		if(StrContains(wpn, "npc_nmrih_", false) == 0)
		{
			count++;
			//AcceptEntityInput(i, "Kill");
			Format(info, 32, "victim%d", i);
			DispatchKeyValue(i, "targetname", info);
			DispatchKeyValue(hurt, "DamageTarget", info);
			DispatchKeyValueFloat(hurt, "Damage", 3000.0);
			DispatchKeyValue(hurt, "DamageType", "268435456");
			AcceptEntityInput(hurt, "Hurt", 0);
		}
	}
	
	AcceptEntityInput(hurt, "Kill");
	PrintToChat(client, "\x04[提示]\x01 一共清理了 %d 只丧尸。", count);
	return Plugin_Handled;
}

public Action Cmd_ClearWeapon(int client, int args)
{
	if(!IsValidClient(client) || GetUserFlagBits(client) <= 0)
		return Plugin_Continue;
	
	int count = 0;
	char classname[128];
	for(int i = MaxClients + 1; i < MAX_EDICT; i++)
	{
		if(!IsValidEntity(i) || !IsValidEdict(i))
			continue;
		
		GetEdictClassname(i, wpn, 128);
		if(	GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1 && (StrContains(wpn, "bow_", false) == 0 ||
			StrContains(wpn, "me_", true) == 0 || StrEqual(wpn, "projectile_arrow", false) ||
			StrContains(wpn, "exp_", true) == 0 || StrContains(wpn, "fa_", true) == 0 ||
			(StrContains(wpn, "tool_", true) == 0 && !StrEqual(wpn, "tool_extinguisher", false) &&
			!StrEqual(wpn, "tool_welder", false)) || (StrContains(wpn, "item_", true) == 0 &&
			!StrEqual(wpn, "item_inventory_box", false))))
		{
			count++;
			AcceptEntityInput(i, "Kill");
		}
	}
	
	PrintToChat(client, "\x04[提示]\x01 一共清理了 %d 个物品。", count);
	return Plugin_Handled;
}

public OnGameFrame()
{
	if(!gAllowThink)
		return;
	
	static float time;
	float next = GetEngineTime(), wait = gCvarThink.FloatValue;
	if(wait <= 0.0 || next - time < wait)
		return;
	time = next;
	
	int count = 0;
	char wpn[128];
	for(int i = MaxClients + 1; i < MAX_EDICT; i++)
	{
		if(!IsValidEntity(i) || !IsValidEdict(i))
			continue;
		
		GetEdictClassname(i, wpn, 128);
		if(	GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1 && (StrContains(wpn, "bow_", false) == 0 ||
			StrContains(wpn, "me_", true) == 0 || StrEqual(wpn, "projectile_arrow", false) ||
			StrContains(wpn, "exp_", true) == 0 || StrContains(wpn, "fa_", true) == 0 ||
			(StrContains(wpn, "tool_", true) == 0 && !StrEqual(wpn, "tool_extinguisher", false) &&
			!StrEqual(wpn, "tool_welder", false)) || (StrContains(wpn, "item_", true) == 0 &&
			!StrEqual(wpn, "item_inventory_box", false))))
		{
			count++;
			AcceptEntityInput(i, "Kill");
		}
	}
	
	PrintToServer("[清理] 清理完毕，一共清理了 %d 个实体。", count);
}
