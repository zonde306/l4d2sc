#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.0"

#define MAXWEAPON 1

new aaa[MAXPLAYERS+1] = 0;

static String:WeaponNames[MAXWEAPON][] = {"rifle" };

new Float:weapon_strengh[MAXWEAPON];
new Float:weapon_cl_strenght[MAXWEAPON][MAXPLAYERS];

public Plugin:myinfo = 
{
	name = "Weapon push infected",
	author = "AK978",
	description = "Weapon push infected",
	version = PLUGIN_VERSION,
};

public OnPluginStart()
{
	HookEvent("player_hurt", DamageEvent);
	
	CreateConVar("sm_kickbabk_version", PLUGIN_VERSION, "Kickback Version", 0|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegConsoleCmd("sm_weapon_push", push_infected, "sm_kickback_add <#weaponname> [Float:strengh:150.0]");
	RegConsoleCmd("sm_weapon_push2", push_infected_2, "sm_kickback_add <#weaponname> [Float:strengh:150.0]");
	RegConsoleCmd("sm_kickback_add", Command_add_weapon, "sm_kickback_add <#weaponname> [Float:strengh:150.0]");
	RegConsoleCmd("sm_kickback_remove", Command_remove_weapon, "sm_kickback_remove <#weaponname>");
	
	RegAdminCmd("sm_client_kickback_add", Command_AddClient_KickBack, ADMFLAG_KICK, "sm_kickback_add <#weaponname> [Float:strengh:150.0]");
	//RegAdminCmd("sm_client_kickback_remove", Command_RemClient_KickBack, ADMFLAG_KICK, "sm_kickback_remove <#weaponname>");

	HookEvent("round_start", RoundStart);
	HookEvent("finale_vehicle_leaving", Event_FinalWin);
	HookEvent("mission_lost", Event_FinalWin);
}

public Action:Event_FinalWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllState5();
	return Plugin_Continue;
}

ResetAllState5()
{	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (aaa[i] == 1 && IsValidClient(i))
		{
			FakeClientCommand(i,"sm_kickback_remove %s","rifle");
		}
	}
}

public OnMapStart()
{
	ResetAllState4();
}

public Action:RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllState4();
	return Plugin_Continue;
}

ResetAllState4()
{	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (aaa[i] == 2 && IsValidClient(i))
		{
			FakeClientCommand(i,"sm_kickback_remove %s","rifle");
		}
	}
}

public Action:push_infected(client, args)
{
	aaa[client] = 1;
	FakeClientCommand(client,"sm_kickback_add %s 500","rifle");
	//PrintToChatAll("玩家 %N 已開啟 M16 特感擊退效果,地圖結束後關閉", client);
}

public Action:push_infected_2(client, args)
{
	aaa[client] = 2;
	FakeClientCommand(client,"sm_kickback_add %s 500","rifle");
	//PrintToChatAll("玩家 %N 抽獎開啟 M16 特感擊退效果,關卡結束後關閉", client);
}

public OnClientConnected( client )
{
	for(new i = 0; i < MAXWEAPON; i++){
		weapon_cl_strenght[ i ][ client ] = 0.0;
	}
}

public Action:Command_remove_weapon(client, args){
	new String:weaponname[32];
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] sm_kickback_remove <#weaponname>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, weaponname, sizeof(weaponname));
	
	new id = GetWeaponId(weaponname);
	if(id >= 0){
		weapon_strengh[id] = 0.0;
	} else
		ReplyToCommand(client, "[SM] Weapon %s not found", weaponname);
	return Plugin_Handled;
}

public Action:Command_add_weapon(client, args){
	new Float:stren, String:weaponname[32];
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] sm_kickback_add <#weaponname> [Float:strengh:150.0]");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, weaponname, sizeof(weaponname));
	
	if(args == 1)
	{
		stren = 150.0;
	}
	else 
	{
	 	decl String:strenstring[32];
	 	GetCmdArg(2, strenstring, sizeof(strenstring));
		stren = StringToFloat(strenstring);		
	}
	
	new id = GetWeaponId(weaponname);
	
	if(id >= 0){
		weapon_strengh[id] = stren;
		LogMessage("Weapon Kick: Weapon %s (%d) with force %f", weaponname, id, stren );
	} else
		ReplyToCommand(client, "[SM] Weapon %s not found", weaponname);
	
	return Plugin_Handled;
}

stock GetWeaponId(const String:weapon[]){
	for(new i = 0; i < MAXWEAPON; i++){
		if(StrEqual(weapon, WeaponNames[i],false)){
			return i;
		}
	}
	return -1;	
}

Float:GetWeaponStrenght( weaponid, client )
{
	if( weapon_cl_strenght[ weaponid ][ client ] > 0.0 )
		return weapon_cl_strenght[ weaponid ][ client ];

	return weapon_strengh[weaponid];
}

public Action:DamageEvent(Handle:event, const String:name[], bool:dontBroadcat)
{

	new String:Weapon[16];	
	GetEventString(event, "weapon", Weapon, 15);
	
	new id = GetWeaponId(Weapon);
	
	//LogMessage("WeaponKick: Damage event called: %s", Weapon);
	
	if(id == -1)
		return Plugin_Continue;
		
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		
	if(GetClientTeam(client) == 2)
		return Plugin_Continue;
		
	new Float:stren = GetWeaponStrenght( id, attacker );
		
	if(stren == 0.0)
		return Plugin_Continue;
	
	new Float:vAngles[3], Float:vReturn[3];	
	//Sinse m_angEyeAngles or m_angEyeAngles[0] works, I am using the harsh number
	GetClientEyeAngles(attacker, vAngles);
	
	vReturn[0] = FloatMul( Cosine( DegToRad(vAngles[1])  ) , stren);
	vReturn[1] = FloatMul( Sine( DegToRad(vAngles[1])  ) , stren);
	vReturn[2] = FloatMul( Sine( DegToRad(vAngles[0])  ) , stren);
		
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vReturn);
	
	//LogMessage("Throwing player: %N with strenght: %f", client, stren );
	
	return Plugin_Continue;
}

public Action:Command_AddClient_KickBack(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_client_kickback_add <#userid|name> <Weapon> <Float:stren=150>");
		return Plugin_Handled;
	}

	decl String:Player[64], String:Weapon[64];
	new Float:stren;
	
	GetCmdArg( 1, Player, sizeof( Player ) );
	GetCmdArg( 2, Weapon, sizeof( Weapon ) );
	
	if(args == 2)
	{
		stren = 150.0;
	}
	else {
	 	decl String:strenstring[32];
	 	GetCmdArg(3, strenstring, sizeof(strenstring));
		stren = StringToFloat(strenstring);		
	}
	
	new id = GetWeaponId(Weapon);
	if(id == 0){
		ReplyToCommand(client, "[SM] Weapon %s not found", Weapon);
		return Plugin_Handled;
	}

	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			Player,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		
		for (new i = 0; i < target_count; i++)
		{
			weapon_cl_strenght[ id ][ target_list[i] ] = stren;
			ReplyToCommand(client, "[SM] Set player: \"%N\" weaponID: %d to strenght %f", target_list[i], id, stren );
		}
		
	}

	return Plugin_Handled;
}

public Action:Command_RemClient_KickBack(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_client_kickback_remove <#userid|name> <Weapon>");
		return Plugin_Handled;
	}

	decl String:Player[64], String:Weapon[64];
	
	GetCmdArg( 1, Player, sizeof( Player ) );
	GetCmdArg( 2, Weapon, sizeof( Weapon ) );
	
	new id = GetWeaponId(Weapon);
	if(id == 0){
		ReplyToCommand(client, "[SM] Weapon %s not found", Weapon);
		return Plugin_Handled;
	}

	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			Player,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		
		for (new i = 0; i < target_count; i++)
		{
			weapon_cl_strenght[ id ][ target_list[i] ] = 0.0;
			ReplyToCommand(client, "[SM] Removed player: \"%N\" weaponID: %d", target_list[i], id );
		}
		
	}

	return Plugin_Handled;
}

stock bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}