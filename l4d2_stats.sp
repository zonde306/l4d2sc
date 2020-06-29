#include <sourcemod>
#include <colors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define IsSpectator(%0) (GetClientTeam(%0) == TEAM_SPECTATOR)
#define IsSurvivor(%0) (GetClientTeam(%0) == TEAM_SURVIVOR)
#define IsInfected(%0) (GetClientTeam(%0) == TEAM_INFECTED)
#define IsPouncing(%0) (g_bIsPouncing[%0])	// (GetEntProp(%0, Prop_Send, "m_isAttemptingToPounce"))

#define BOOMER_STAGGER_TIME 4.0 // Amount of time after a boomer has been meleed that we consider the meleer the person who
// shut down the boomer, this is just a guess value..

#define ZC_SMOKER 1 
#define ZC_BOOMER 2 
#define ZC_HUNTER 3 
#define ZC_SPITTER 4 
#define ZC_JOCKEY 5 
#define ZC_CHARGER 6 
#define ZC_WITCH 7 
#define ZC_TANK 8

static g_iAlarmCarClient;

public Plugin:myinfo = 
{
	name = "技能检测精简版",
	author = "Griffin, Philogl, Sir",
	description = "Display Skeets/Etc to Chat to clients",
	version = "1.0",
	url = "<- URL ->"
}

new				g_iSurvivorLimit							= 4;
new		Handle:	g_hCvarSurvivorLimit						= INVALID_HANDLE;
new		bool:	g_bHasRoundEnded							= false;
new				g_iBoomerClient;		// Last player to be boomer (or current boomer)
new				g_iBoomerKiller;									// Client who shot the boomer
new				g_iBoomerShover;									// Client who shoved the boomer
new				g_iLastHealth[MAXPLAYERS + 1];
new		bool:	g_bHasBoomLanded						 	= false;
new		bool:	g_bHasBoomNear						 	= false;
new		bool:	g_bIsPouncing[MAXPLAYERS + 1];
new		Handle:	g_hBoomerShoveTimer							= INVALID_HANDLE;
new     Handle: g_hBoomerKillTimer                          = INVALID_HANDLE;
new 	Float: BoomerKillTime                               = 0.0;
new     String:Boomer[32]               // Name of Boomer

// Player temp stats
new				g_iDamageDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker
new				g_iShotsDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker, count # of shots (not pellets)

new		bool:	g_bShotCounted[MAXPLAYERS + 1][MAXPLAYERS +1];		// Victim - Attacker, used by playerhurt and weaponfired

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("lunge_pounce", Event_LungePounce);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("player_now_it", Event_PlayerBoomed);
	HookEvent("boomer_near", Event_BoomerNear);
	
	// HookEvent("create_panic_event", Event_Panic);
	// HookEvent("triggered_car_alarm", Event_AlarmCar);
	
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	HookConVarChange(g_hCvarSurvivorLimit, Cvar_SurvivorLimit);
	g_iSurvivorLimit = GetConVarInt(g_hCvarSurvivorLimit);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0 || !IsClientInGame(client)) return;
	
	if (IsInfected(client))
	{
		new zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_TANK) return;
		
		if (zombieclass == ZC_BOOMER)
		{
			// Fresh boomer spawning (if g_iBoomerClient is set and an AI boomer spawns, it's a boomer going AI)
			if (!IsFakeClient(client) || !g_iBoomerClient)
			{
				g_bHasBoomLanded = false;
				g_bHasBoomNear = false;
				g_iBoomerClient = client;
				g_iBoomerShover = 0;
				g_iBoomerKiller = 0;
			}
			
			if (g_hBoomerShoveTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerShoveTimer);
				g_hBoomerShoveTimer = INVALID_HANDLE;
			}
			BoomerKillTime = 0.0;
			g_hBoomerKillTimer = CreateTimer(0.1, Timer_KillBoomer, _, TIMER_REPEAT);
		}
		
		g_iLastHealth[client] = GetClientHealth(client);
	}
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	for (new i = 1; i <= MaxClients; i++)
	{
		// [Victim][Attacker]
		g_bShotCounted[i][client] = false;
	}
}

public OnMapStart()
{
	g_bHasRoundEnded = false;
	ClearMapStats();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bHasRoundEnded = false;
	if (g_hBoomerKillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBoomerKillTimer);
		g_hBoomerKillTimer = INVALID_HANDLE;
		BoomerKillTime = 0.0;
	}
	g_iAlarmCarClient = 0;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	g_bHasRoundEnded = true;
	for (new i = 1; i <= MaxClients; i++)
	{
		ClearDamage(i);
	}
}

// Pounce tracking, from skeet announce
public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsClientInGame(client) || !IsInfected(client)) return;
	new zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if (zombieclass == ZC_HUNTER || zombieclass == ZC_JOCKEY)
	{
		g_bIsPouncing[client] = true;
		CreateTimer(0.5, Timer_GroundedCheck, client, TIMER_REPEAT);
	}
}

public Event_LungePounce(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new zombieclass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
	
	if (zombieclass == ZC_HUNTER || zombieclass == ZC_JOCKEY) g_bIsPouncing[attacker] = false;
}

public Action:Timer_GroundedCheck(Handle:timer, any:client)
{
	if (!IsClientInGame(client) || IsGrounded(client))
	{
		g_bIsPouncing[client] = false;
		KillTimer(timer);
	}
}

public Action:Timer_KillBoomer(Handle:timer)
{
	BoomerKillTime += 0.1;
}

// Jacked from skeet announce
bool:IsGrounded(client)
{
	return (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0;
}


public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim == 0 || !IsClientInGame(victim)) return;
	if (!attacker || !IsClientInGame(attacker)) return;
	
	new damage = GetEventInt(event, "dmg_health");
	
	if (IsSurvivor(attacker) && IsInfected(victim))
	{
		new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_TANK) return; // We don't care about tank damage
		
		if (!g_bShotCounted[victim][attacker])
		{
			g_iShotsDealt[victim][attacker]++;
			g_bShotCounted[victim][attacker] = true;
		}
		
		new remaining_health = GetEventInt(event, "health");
		
		// Let player_death handle remainder damage (avoid overkill damage)
		if (remaining_health <= 0) return;
		
		// remainder health will be awarded as damage on kill
		g_iLastHealth[victim] = remaining_health;
		
		g_iDamageDealt[victim][attacker] += damage;
		
		if (zombieclass == ZC_BOOMER)
		{ /* Boomer Shit Here */ }
		else if (zombieclass == ZC_HUNTER)
		{ /* Hunter Shit Here */ }
		else if (zombieclass == ZC_SMOKER)
		{ /* Smoker Shit Here */ }
		else if (zombieclass == ZC_JOCKEY)
		{ /* Jockey Shit Here */ }
		else if (zombieclass == ZC_CHARGER)
		{ /* Charger Shit Here */ }
		else if (zombieclass == ZC_SPITTER)
		{ /* Spitter Shit Here */ }
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim <= 0 || !IsClientInGame(victim)) return;
	
	if (attacker <= 0) return;
	
	if (!IsClientInGame(attacker))
	{
		if (IsInfected(victim)) ClearDamage(victim);
		return;
	}
	
	if (IsSurvivor(attacker) && IsInfected(victim))
	{
		new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_TANK) return; // We don't care about tank damage
		
		new lasthealth = g_iLastHealth[victim];
		g_iDamageDealt[victim][attacker] += lasthealth;
		
		/*
		if (zombieclass == ZC_BOOMER)
		{
			// Only happens on mid map plugin load when a boomer is up
			if (!g_iBoomerClient || !IsClientInGame(g_iBoomerClient)) g_iBoomerClient = victim;

			if (!IsFakeClient(g_iBoomerClient)) GetClientName(g_iBoomerClient, Boomer, sizeof(Boomer));
			else Boomer = "AI";
			
			CreateTimer(0.2, Timer_BoomerKilledCheck, victim);
			g_iBoomerKiller = attacker;
			
			if (g_hBoomerKillTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerKillTimer);
				g_hBoomerKillTimer = INVALID_HANDLE;
			}
		}
		else */
		if (zombieclass == ZC_HUNTER && IsPouncing(victim))
		{ // Skeet!
			decl assisters[g_iSurvivorLimit][2];
			new assister_count, i;
			new damage = g_iDamageDealt[victim][attacker];
			new shots = g_iShotsDealt[victim][attacker];
			for (i = 1; i <= MaxClients; i++)
			{
				if (i == attacker) continue;
				if (g_iDamageDealt[victim][i] > 0 && IsClientInGame(i))
				{
					assisters[assister_count][0] = i;
					assisters[assister_count][1] = g_iDamageDealt[victim][i];
					assister_count++;
				}
			}
			
			// Used GetClientWeapon because Melee Damage is known to be broken
			// Use l4d2_melee_fix.smx in order to make this work properly. :)
			new String:weapon[64];
			GetClientWeapon(attacker, weapon, sizeof(weapon));
			
			if (StrEqual(weapon, "weapon_melee"))
			{
				CPrintToChat(victim, "{blue}★ {default}你被 {olive}%N {default}使用 {blue}近战武器 {default}秒了", attacker);
				CPrintToChat(attacker, "{blue}★ {default}你使用 {blue}近战武器 {default}秒了 {olive}%N", victim);
				
				for (new b = 1; b <= MaxClients; b++)
				{
					//Print to Specs!
					if ((victim != b) && (attacker != b) && IsClientInGame(b))
					{
						CPrintToChat(b, "{blue}★ {olive}%N {default}使用 {blue}近战武器{default}秒了 {default}飞扑的 {olive}%N", attacker, victim)
					}
				}
			}
			// Scout Headshot
			else if (GetEventBool(event, "headshot") &&
				(StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_awp")))
			{
				CPrintToChat(victim, "{blue}★ {default}你被 {olive}%N {default}使用 {blue}%s {default}空爆 {default}了", attacker, (weapon[14] == 's' ? "鸟狙" : "大狙"));
				CPrintToChat(attacker, "{blue}★ {default}你使用 {blue}%s {default}空爆了 {olive}%N", (weapon[14] == 's' ? "鸟狙" : "大狙"), victim);
				
				for (new b = 1; b <= MaxClients; b++)
				{
					//Print to Specs!
					if ((victim != b) && (attacker != b) && IsClientInGame(b))
					{
						CPrintToChat(b, "{blue}★ {olive}%N {default}使用 {blue}%s {default}空爆了 {olive}%N", attacker, (weapon[14] == 's' ? "鸟狙" : "大狙"), victim);
					}
				}
			}
			else if (assister_count)
			{
				// Sort by damage, descending
				SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
				decl String:assister_string[128];
				decl String:buf[MAX_NAME_LENGTH + 8];
				new assist_shots = g_iShotsDealt[victim][assisters[0][0]];
				// Construct assisters string
				Format(assister_string, sizeof(assister_string), "{olive}%N{default} (射击 {blue}%d{default} 次, 伤害 {blue}%d{default})",
				assisters[0][0],
				g_iShotsDealt[victim][assisters[0][0]],
				assisters[0][1]);
				for (i = 1; i < assister_count; i++)
				{
					assist_shots = g_iShotsDealt[victim][assisters[i][0]];
					Format(buf, sizeof(buf), ", {olive}%N{default} (射击 {blue}%d{default} 次, 伤害 {blue}%d{default})",
					assisters[i][0],
					assist_shots,
					assisters[i][1]);
					StrCat(assister_string, sizeof(assister_string), buf);
				}
				
				// Print to assisters
				/*
				for (i = 0; i < assister_count; i++)
				{
					CPrintToChat(assisters[i][0], "{blue}★ {olive}%N {default}射死了飞扑的 {olive}%N {default}(射击 {blue}%d{default} 次, 伤害 {blue}%d{default}). 助攻: %s",
						attacker, victim, shots, damage, assister_string);
				}
				*/
				
				// Print to victim
				CPrintToChat(victim, "{blue}☆ {default}你在飞扑时被 {olive}%N {default}射死了 {default}(射击 {blue}%d{default} 次, 伤害 {blue}%d{default}). 助攻: %s",
					attacker, shots, damage, assister_string);
				
				// print to attacker
				CPrintToChat(attacker, "{blue}☆ {default}你射死了飞扑的 {olive}%N {default}(射击 {blue}%d{default} 次, 伤害 {blue}%d{default}). 助攻: %s",
					victim, shots, damage, assister_string);
				
				//Print to Specs!
				for (new b = 1; b <= MaxClients; b++)
				{
					if (b != attacker && b != victim && IsClientInGame(b))
					{
						CPrintToChat(b, "{blue}☆ {olive}%N {default}射死了飞扑的 {olive}%N {default}(射击 {blue}%d{default} 次, 伤害 {blue}%d{default}). 助攻: %s",
							attacker, victim, shots, damage, assister_string);
					}
				}
			}
			else
			{
				CPrintToChat(victim, "{blue}%s {default}你在飞扑时被 {olive}%N {default}射死了 (射击 {blue}%d{default} 次)",
					(shots > 1 ? "☆" : "★"), attacker, shots);
				
				CPrintToChat(attacker, "{blue}%s {default}你射死了飞扑的 {olive}%N {default}(射击 {blue}%d{default} 次)",
					(shots > 1 ? "☆" : "★"), victim, shots);
				
				for (new b = 1; b <= MaxClients; b++)
				{
					//Print to Everyone Else!
					if ((victim != b) && attacker != b && IsClientInGame(b))
					{
						CPrintToChat(b, "{blue}%s {olive}%N {default}在飞扑时被 {olive}%N {default}射死了 (射击 {blue}%d{default} 次)",
							(shots > 1 ? "☆" : "★"), victim, attacker, shots);
					}
				}
			}
		}
	}
	if (IsInfected(victim)) ClearDamage(victim);
}

public Action:Timer_BoomerKilledCheck(Handle:timer)
{
	BoomerKillTime = BoomerKillTime - 0.2;
	
	if (g_bHasBoomLanded || BoomerKillTime > 2.0 || !g_bHasBoomNear)
	{
		g_iBoomerClient = 0;
		BoomerKillTime = 0.0;
		return;
	}
	
	if (IsClientInGame(g_iBoomerKiller))
	{
		if (IsClientInGame(g_iBoomerClient))
		{
			//Boomer was Shoved before he was Killed!
			if (g_iBoomerShover != 0 && IsClientInGame(g_iBoomerShover))
			{
				// Shover is Killer
				if (g_iBoomerShover == g_iBoomerKiller)
				{
					CPrintToChatAll("{blue}★ {olive}%N {default}在 %.1f 秒内推开并打死了 {olive}%s {blue}Boomer", g_iBoomerKiller, BoomerKillTime, Boomer);
				}
				// Someone Shoved and Someone Killed
				else
				{
					CPrintToChatAll("{blue}★ {olive}%N {default}在 %.1f 秒内推开 {olive}%s {blue}Boomer {default}并被 {olive}%N {default} 打死了", g_iBoomerShover, BoomerKillTime, Boomer, g_iBoomerKiller);
				}
			}
			//Boomer got Popped without Shove
			else
			{
				CPrintToChatAll("{blue}★ {olive}%N {default}在 %.1f 秒内打死了 {olive}%s {blue}Boomer", g_iBoomerKiller, BoomerKillTime, Boomer);
			}
		}
	}
	
	g_iBoomerClient = 0;
	BoomerKillTime = 0.0;
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim == 0 ||
	!IsClientInGame(victim) ||
	!IsInfected(victim)
	) return;
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker == 0 ||				// World dmg?
	!IsClientInGame(attacker) ||	// Unsure
	!IsSurvivor(attacker)
	) return;
	
	new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if (zombieclass == ZC_BOOMER)
	{
		if (g_hBoomerShoveTimer != INVALID_HANDLE)
		{
			KillTimer(g_hBoomerShoveTimer);
			if (!g_iBoomerShover || !IsClientInGame(g_iBoomerShover)) g_iBoomerShover = attacker;
		}
		else
		{
			g_iBoomerShover = attacker;
		}
		g_hBoomerShoveTimer = CreateTimer(BOOMER_STAGGER_TIME, Timer_BoomerShove);
	}
}

public Action:Timer_BoomerShove(Handle:timer)
{
	// PrintToChatAll("[DEBUG] BoomerShove timer expired, credit for boomer shutdown is available to anyone at this point!");
	g_hBoomerShoveTimer = INVALID_HANDLE;
	g_iBoomerShover = 0;
}

public Event_PlayerBoomed(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasBoomLanded) return;
	g_bHasBoomLanded = true;
	
	// Doesn't matter if we log stats to an out of play client, won't affect anything
	// if (!IsClientInGame(g_iBoomerClient) || IsFakeClient(g_iBoomerClient)) return;
	
	// We credit the person who spawned the boomer with booms even if it went AI
	if (GetEventBool(event, "exploded"))
	{
		// Proxy Boom!
		if (g_iBoomerShover != 0)
		{
			/*if (g_iBoomerKiller == g_iBoomerShover)
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						if (IsSurvivor(i) || (IsSpectator(i))) CPrintToChat(i, "{blue}★ {olive}%N {default}shoved {olive}%s{default}'s Boomer, but popped it too early", g_iBoomerShover, Boomer);
					}
				}
			}
			else
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						if (IsSurvivor(i) || (IsSpectator(i))) CPrintToChat(i, "{blue}★ {olive}%N {default}shoved {olive}%s{default}'s Boomer, but {olive}%N {default}popped it too early", g_iBoomerShover, Boomer, g_iBoomerKiller);
					}
				}
			}
			*/
		}
	}
	else
	{
		// Boomer > Survivor Skills.
	}
}

public Event_BoomerNear(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bHasBoomNear = true;
}

// Car Alarm Stuff!
public Event_Panic(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iAlarmCarClient = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.5, Clear, g_iAlarmCarClient);
}

// g_iAlarmCarClient cleared.
public Action:Clear(Handle:timer) g_iAlarmCarClient = 0;

// Found you..! Sneaky Car Shooter.
public Action:Event_AlarmCar(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_iAlarmCarClient && IsClientInGame(g_iAlarmCarClient) && GetClientTeam(g_iAlarmCarClient) == 2)
	{
		CPrintToChatAll("{blue}× {olive}%N {default}触发了 {olive}警报车", g_iAlarmCarClient);
		g_iAlarmCarClient = 0;
	}
}

public Cvar_SurvivorLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSurvivorLimit = StringToInt(newValue);
}

ClearMapStats()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		ClearDamage(i);
	}
	g_iAlarmCarClient = 0;
}

ClearDamage(client)
{
	g_iLastHealth[client] = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}

public ClientValue2DSortDesc(x[], y[], const array[][], Handle:data)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

stock bool:IsLeaping(jockey)
{
	new abilityEnt = GetEntPropEnt( jockey, Prop_Send, "m_customAbility" );
	if ( IsValidEntity(abilityEnt) && HasEntProp(abilityEnt, Prop_Send, "m_isLeaping") &&
		GetEntProp(abilityEnt, Prop_Send, "m_isLeaping") )
		return true;
	
	return false;
}
