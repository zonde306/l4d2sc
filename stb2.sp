#include <sourcemod>
#include <SteamWorks>

new Handle:hDatabase = INVALID_HANDLE;
new Handle:fsArray;

new Handle:stb2_leave_srcds_ban = INVALID_HANDLE;
new bool:leave_srcds_ban;

new Handle:stb2_mode = INVALID_HANDLE;
new stb2mode = 0;

new bool:bypass;
new bool:bypass_server_addban;
new bool:event_removeid;
new bool:mysql;

char sUserOwner[MAXPLAYERS+1][32];

// #include "modules/sql_.sp"

public Plugin:myinfo =
{
	name = "保存临时禁令",
	author = "Bacardi, YoNer",
	description = "Storage temporary bans, in order not lose them after server reboot, authID mod by YoNer",
	version = "2.0y",
	url = "https://www.sourcemod.net"
}

public OnPluginStart()
{
	LoadTranslations("stb2.phrases.txt");

	RegAdminCmd("sm_stb2_banlist", admcmd_list, ADMFLAG_BAN , "List STB2 bans in console");
	RegAdminCmd("sm_stb2_unbanlist", admcmd_list, ADMFLAG_BAN , "List STB2 expired bans in console");

	HookEvent("server_addban", server_addban);
	HookEvent("server_removeban", server_removeban);

	AddCommandListener(SrvCmd_removeid, "removeid");

	stb2_leave_srcds_ban = CreateConVar("stb2_leave_srcds_ban", "0", "启用后，将在服务器上保留正常的SRCDS禁令", FCVAR_NONE, true, 0.0, true, 1.0);
	leave_srcds_ban = GetConVarBool(stb2_leave_srcds_ban);
	HookConVarChange(stb2_leave_srcds_ban, ConVarChanged);

	stb2_mode = CreateConVar("stb2_mode", "1", "处理临时禁令\n 0 = 通常在服务器，banid中添加禁令\n 1 = 踢出玩家时显示消息\n 2 = 踢出玩家时显示消息，并且顺手禁IP一分钟", FCVAR_NONE, true, 0.0, true, 2.0);
	stb2mode = GetConVarInt(stb2_mode);
	HookConVarChange(stb2_mode, ConVarChanged);

	AutoExecConfig(true);

	/* http://wiki.alliedmods.net/SQL_%28SourceMod_Scripting%29#Threading
		Threaded connection.
		Connection configuration from ...addons/sourcemod/configs/databases.cfg
	*/
	
	fsArray = CreateArray(65, 0);
	SQL_TConnect(GotDatabase, "stb2");
	CreateTimer(1.0, Timer_CheckBan, 0, TIMER_REPEAT);
}


public ConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	leave_srcds_ban = GetConVarBool(stb2_leave_srcds_ban);
	stb2mode = GetConVarInt(stb2_mode);
}

public SW_OnValidateClient(OwnerSteamID, ClientSteamID)
{    
	if(OwnerSteamID == ClientSteamID)
		return;
	
	decl String:oSteamID[32];
	Format(oSteamID, sizeof(oSteamID),"STEAM_1:%d:%d", (OwnerSteamID & 1), (OwnerSteamID >> 1));
	
	decl String:cSteamID[32];
	Format(cSteamID, sizeof(cSteamID),"STEAM_1:%d:%d", (ClientSteamID & 1), (ClientSteamID >> 1));
	
	new String:SteamIDs[65];
	Format(SteamIDs, sizeof(SteamIDs), "%s-%s", oSteamID, cSteamID);
	PushArrayString(fsArray, SteamIDs);
	
	LogMessage("%s owner is %s", cSteamID, oSteamID);
}

// sm_stb2_banlist, sm_stb2_unbanlist
public Action:admcmd_list(client, args)
{
	decl bool:bans, bool:like, String:entersql[300], String:arg[30], value; entersql[0] = '\0', arg[0] = '\0', value = 0;
	like = false;

	GetCmdArg(0, arg, sizeof(arg)); // Get first cmd arg
	bans = StrContains(arg, "unban", false) == -1 ? true:false; // which cmd, sm_stb2_unbanlist or sm_stb2_banlist ?

	if(args > 0) // There more arguments
	{
		GetCmdArg(1, arg, sizeof(arg)); // Grab second arg

		if(args > 1 && StrEqual(arg, "LIKE")) // There 1 more arguments and second arg start LIKE
		{
			GetCmdArgString(arg, sizeof(arg)); // Get whole cmd string
			ReplaceString(arg, sizeof(arg), "\'", ""); // Erase any ' character
			ReplaceString(arg, sizeof(arg), " ", ""); // Erase any space character
			value = StrContains(arg, "LIKE")+4;
			like = true; // Search steamid
		}
		else if((value = StringToInt(arg)) < 0) // Grap second arg and make it number, if less than 0
		{
			value = 0;
		}
	}

	if(like) // Search steamid
	{
		if(mysql)
		{
			Format(entersql, sizeof(entersql), "SELECT `steamid`, `date` FROM `stb2` WHERE `steamid` LIKE '%s' AND `date` %s NOW() ORDER BY `unixtime` DESC LIMIT 0 , 6", arg[value], (bans ? ">":"<"));
		}
		else
		{
			Format(entersql, sizeof(entersql), "SELECT `steamid`, `date` FROM `stb2` WHERE `steamid` LIKE '%s' AND `date` %s datetime('now','localtime') ORDER BY `unixtime` DESC LIMIT 0 , 6", arg[value], (bans ? ">":"<"));
		}
	}
	else // List ban/unban
	{
		if(mysql)
		{
			Format(entersql, sizeof(entersql), "SELECT `steamid`, `date` FROM `stb2` WHERE `date` %s NOW() ORDER BY `unixtime` DESC LIMIT %i , 6", (bans ? ">":"<"), value);
		}
		else
		{
			Format(entersql, sizeof(entersql), "SELECT `steamid`, `date` FROM `stb2` WHERE `date` %s datetime('now','localtime') ORDER BY `unixtime` DESC LIMIT %i , 6", (bans ? ">":"<"), value);
		}
	}

	// Cmd executed by client
	if(client != 0)
	{
		SQL_TQuery(hDatabase, T_ListSteamID, entersql, GetClientUserId(client));
		return Plugin_Handled;
	}

	SQL_LockDatabase(hDatabase);

	new String:error[300], Handle:hndl = SQL_Query(hDatabase, entersql);

	if (hndl == INVALID_HANDLE)
	{
		SQL_UnlockDatabase(hDatabase);

		if(SQL_GetError(hDatabase, error, sizeof(error)))
		{
			LogError(" Query admcmd_list failed! = %s\nerror %s", entersql, error);
		}
		return Plugin_Handled;
	}

	// Count results
	new count = SQL_GetRowCount(hndl);

	if(count > 0)
	{

		decl len, startindex, String:msg[300], String:buffer[50]; msg[0] = '\0', buffer[0] = '\0';

		startindex = 0;

		// Loop results
		for(new i = 1; i <= count; i++)
		{
			if(!SQL_FetchRow(hndl))
			{
				continue;
			}

			if(count > 5 && i == 6)
			{
				Format(msg[startindex], sizeof(msg), "\n There are more results...\0");
				break;
			}

			buffer[0] = '\0';
			len = SQL_FetchString(hndl, 0, buffer, sizeof(buffer));

			Format(buffer[len], 25, "%11i", 0);
			buffer[19] = '=';

			SQL_FetchString(hndl, 1, buffer[21], sizeof(buffer));

			startindex += Format(msg[startindex], sizeof(msg), "%s\n", buffer);

		}
		PrintToServer("\n%s\n", msg); // This would show when use rcon
		LogToGame("[SM] STB2 command executed from server console\n%s\n", msg); // This would show when use rcon and server have log on
	}

	SQL_UnlockDatabase(hDatabase);

	CloseHandle(hndl);

	return Plugin_Handled;
}

// Cmd removeid
public Action:SrvCmd_removeid(client, const String:command[], argc)
{
	event_removeid = false; // Reset

	// Skip unban or there not connection yet to db
	if(bypass || hDatabase == INVALID_HANDLE)
	{
		bypass = false; //reset
		return Plugin_Continue;
	}

	if(argc == 5) // There enough arguments
	{
		decl len, startindex, String:buffer[23]; buffer[0] = '\0';
		startindex = 0,	len = 0;

		GetCmdArgString(buffer, sizeof(buffer));
		len = strlen(buffer);

		if(len > 10) // There enough text in string
		{
			if(StrContains(buffer[startindex], "\'") == -1 && StrContains(buffer[startindex], "[U:") == 0)
			{
				len -= ReplaceString(buffer, sizeof(buffer), " ", ""); // Remove spaces, when send command via rcon, srcds add extra spaces every colon(:) character.

				if(len > 10) // Still enough text in string
				{
					if(buffer[startindex + 2] == ':' && buffer[startindex + 4] == ':') // STEAM_x:x:xxx
					{
						decl String:query[300]; query[0] = '\0';

						Format(query, sizeof(query), "DELETE FROM `stb2` WHERE `steamid` = '%s'", buffer);

						SQL_LockDatabase(hDatabase);

						if(!SQL_FastQuery(hDatabase, query))
						{
							if(SQL_GetError(hDatabase, query, sizeof(query)))
							{
								LogError(" Query SrvCmd_removeid failed! %s", query);
							}
						}

						SQL_UnlockDatabase(hDatabase);

					}
					else
					{
						LogMessage("removeid = Steam id %s not valid", buffer[startindex]);
					}
				}
			}
		}
	}
	else // Not valid steamid, maybe steamid removed from server ban slot
	{
		event_removeid = true; // Look from event server_removeban
	}
	return Plugin_Continue;
}

// SM cmd Ban add
public Action:OnBanIdentity(const String:identity[], time, flags, const String:reason[], const String:command[], any:source)
{
	// Not permanent, steamid ban, there's not extra '
	if(time > 0 && flags == BANFLAG_AUTHID && StrContains(identity, "\'") == -1)
	{
		// Ban time longer than year
		if(time > 525600)
		{
			time = 525600; // 1 year
		}
		
		// Look first steamid from db
		decl String:query[300]; query[0] = '\0';
		Format(query, sizeof(query), "SELECT `steamid` FROM `stb2` WHERE `steamid` = '%s'", identity);
		
		// DataPack
		new Handle:pack = CreateDataPack();
		WritePackString(pack, identity);
		WritePackCell(pack, time);
		
		//...stb2inc/sql_.sp, T_SaveSteamID
		SQL_TQuery(hDatabase, T_SaveSteamID, query, pack);
		
		// Cvars stb2_mode, stb2_leave_srcds_ban
		if(stb2mode != 0 && !leave_srcds_ban)
		{
			return Plugin_Handled; // to block the actual server banning (banid).
		}
	}
	return Plugin_Continue;
}

// SM cmd ban
public Action:OnBanClient(client, time,  flags,  const String:reason[],  const String:kick_message[],  const String:command[], any:source)
{
	// Not permanent
	if(time > 0)
	{
		if(time > 525600) // Over year
		{
			time = 525600; // 1 year
		}

		decl String:auth[32], String:query[300]; auth[0] = '\0', query[0] = '\0';
		
		if(sUserOwner[client][0] != EOS)
		{
			Format(query, sizeof(query), "SELECT `steamid` FROM `stb2` WHERE `steamid` = '%s'", sUserOwner[client]);
			
			new Handle:pack = CreateDataPack();
			WritePackString(pack, sUserOwner[client]);
			WritePackCell(pack, time);
			
			SQL_TQuery(hDatabase, T_SaveSteamID, query, pack);
			LogMessage("client %N owner is %s, banned", client, sUserOwner[client]);
		}
		
		//if(GetClientAuthString(client, auth, sizeof(auth))) // Client steamid
		if(GetClientAuthId(client,AuthId_Steam2,auth,sizeof(auth),true))
		{
			ReplaceString(auth, sizeof(auth), "STEAM_0", "STEAM_1", false);
			
			// Check id
			// if(StrContains(auth, "[U:") == 0 && StrContains(auth, "ID") == -1 && StrContains(auth, "STEAM_") == -1)
			{
				Format(query, sizeof(query), "SELECT `steamid` FROM `stb2` WHERE `steamid` = '%s'", auth);

				new Handle:pack = CreateDataPack();
				WritePackString(pack, auth);
				WritePackCell(pack, time);

				SQL_TQuery(hDatabase, T_SaveSteamID, query, pack);

				if(stb2mode != 0 && !leave_srcds_ban)
				{
					return Plugin_Handled;// to block the actual server banning.
				}
			}
		}
		else
		{
			LogError(" Failed OnBanClient->GetClientAuthId, client %i", client);
		}
	}

	return Plugin_Continue;
}

// Playe connect
public OnClientPostAdminCheck(client)
{
	// cvar stb2_mode not status 0, Is not BOT, not have immunity
	if(stb2mode != 0 && !IsFakeClient(client) && !CheckCommandAccess(client, "stb2_immunity", ADMFLAG_UNBAN))
	{
		decl String:auth[32], String:query[255]; auth[0] = '\0', query[0] = '\0';

		if(GetClientAuthId(client,AuthId_Steam2,auth,sizeof(auth),true))
		{
			Format(query, sizeof(query), "SELECT `unixtime` , `duration` , `date` FROM `stb2` WHERE `steamid` = '%s'", auth);
			SQL_TQuery(hDatabase, T_CheckSteamID, query, GetClientUserId(client));
		}
		else
		{
			LogError(" Failed OnClientPostAdminCheck, GetClientAuthString, client %i", client);
		}
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	sUserOwner[client][0] = EOS;
	return true;
}

public Action Timer_CheckBan(Handle timer, any data)
{
	for(int i = 0; i < GetArraySize(fsArray); ++i)
	{
		static char steamId[2][32], query[255];
		GetArrayString(fsArray, i, query, sizeof(query));
		
		// steamId[0] is owner, steamId[1] is client
		ExplodeString(query, "-", steamId, sizeof(steamId), sizeof(steamId[]));
		
		for(int i2 = 1; i2 <= MaxClients; ++i2)
		{
			if(!IsClientConnected(i2) || IsFakeClient(i2))
				continue;
			
			static char auth[32];
			if(GetClientAuthId(i2, AuthId_Steam2, auth, sizeof(auth), true))
			{
				ReplaceString(auth, sizeof(auth), "STEAM_0", "STEAM_1", false);
				if(StrEqual(steamId[1], auth, false))
				{
					Format(query, sizeof(query), "SELECT `unixtime` , `duration` , `date` FROM `stb2` WHERE `steamid` = '%s'", steamId[0]);
					SQL_TQuery(hDatabase, T_CheckSteamID, query, GetClientUserId(i2));
					
					strcopy(sUserOwner[i2], sizeof(sUserOwner[]), steamId[0]);
					
					// 下一个被忽略的等下次再处理吧
					RemoveFromArray(fsArray, i);
					
					LogMessage("Client %N SteamID is %s, Owner SteamID is %s.", i2, steamId[1], steamId[0]);
					break;
				}
			}
		}
	}
}

// Server event add ban
public server_addban(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bypass_server_addban) // When plugin start in stb2_mode = 0, it add bans from db to srcds first, after this it start look new bans
	{
		return;
	}

	decl String:duration[25]; duration[0] = '\0';
	GetEventString(event, "duration", duration, sizeof(duration));

	// Not permanent
	if(StrContains(duration, "permanently") == -1)
	{
		decl String:networkid[32]; networkid[0] = '\0';
		GetEventString(event, "networkid", networkid, sizeof(networkid));
		ReplaceString(networkid, sizeof(networkid), "STEAM_0", "STEAM_1", false);

		// Check id
		// if(networkid[0] != '\0' && StrContains(networkid, "ID") == -1 && StrContains(networkid, "\'") == -1)
		if(networkid[0] != EOS && strcmp(networkid, "BOT", false) && StrContains(networkid, "\'") == -1)
		{
			decl startindex, time; startindex = 0, time = 0;
			ReplaceString(networkid, sizeof(networkid), "STEAM_0", "STEAM_1", false);

			startindex = StrContains(duration, " "); // Find first space

			if((time = StringToInt(duration[startindex+1])) > 525600) // Get duration, if over year
			{
				time = 525600; // 1 year
			}

			BanId(networkid, time);
			
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			if(client > 0 && client <= MaxClients && sUserOwner[client][0] != EOS)
			{
				BanId(sUserOwner[client], time);
				LogMessage("client %N owner is %s, banned.", client, sUserOwner[client]);
			}
		}
	}
}

void BanId(char[] networkid, int time)
{
	decl String:query[255]; query[0] = '\0';
	Format(query, sizeof(query), "SELECT `steamid` FROM `stb2` WHERE `steamid` = '%s'", networkid);

	new Handle:pack = CreateDataPack();
	WritePackString(pack, networkid);
	WritePackCell(pack, time);

	SQL_TQuery(hDatabase, T_SaveSteamID, query, pack);
	
	LogMessage("%s banned of %s second", networkid, time);
}

// Server event remove ban
public server_removeban(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Skip
	if(!event_removeid)
	{
		return;
	}

	event_removeid = false; // Reset

	decl String:networkid[32]; networkid[0] = '\0';
	GetEventString(event, "networkid", networkid, sizeof(networkid));

	// if(networkid[0] != '\0' && StrContains(networkid, "ID", false) == -1)
	if(networkid[0] != EOS && strcmp(networkid, "BOT", false) && StrContains(networkid, "\'") == -1)
	{
		// if(/*networkid[0] != '\0' && StrContains(networkid, "ID") == -1 && */StrContains(networkid, "\'") == -1)
		{
			ReplaceString(networkid, sizeof(networkid), "STEAM_0", "STEAM_1", false);
			UnbanId(networkid);
		}
	}
}

void UnbanId(char[] networkid)
{
	decl String:query[300]; query[0] = '\0';
	
	Format(query, sizeof(query), "DELETE FROM `stb2` WHERE `steamid` = '%s'", networkid);

	SQL_LockDatabase(hDatabase);

	if(!SQL_FastQuery(hDatabase, query))
	{
		if(SQL_GetError(hDatabase, query, sizeof(query)))
		{
			LogError(" Query server_removeban failed! %s", query);
		}
	}

	SQL_UnlockDatabase(hDatabase);
	
	LogMessage("%s unbanned", networkid);
}

/*
***************************************
*				_sql.sp
***************************************
*/

// database connect callback
public GotDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	// Can't connect database
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("Database failure: %s", error);
		return;
	}

	// Save db connection to global Handle:hDatabase
	hDatabase = hndl;

	// http://wiki.alliedmods.net/SQL_(SourceMod_Scripting)#Locking
	SQL_LockDatabase(hDatabase);

	/* Create table in database
		CREATE TABLE IF NOT EXISTS `stb2` (
		`steamid` VARCHAR( 20 ) NOT NULL ,
		`unixtime` INT NOT NULL ,
		`duration` INT NOT NULL ,
		`date` DATETIME NOT NULL,
		PRIMARY KEY ( `steamid` ))
	*/
	if(!SQL_FastQuery(hDatabase, "CREATE TABLE IF NOT EXISTS `stb2` (`steamid` VARCHAR( 32 ) NOT NULL , `unixtime` INT NOT NULL , `duration` INT NOT NULL , `date` DATETIME NOT NULL, PRIMARY KEY ( `steamid` ))"))
	{
		decl String:err[300]; err[0] = '\0';
		SQL_GetError(hDatabase, err, sizeof(err));
		SetFailState(" Query CREATE TABLE failed! %s", err);
	}

	// Unlock db
	SQL_UnlockDatabase(hDatabase);

	decl String:ident[9], String:query[100]; ident[0] = '\0', query[0] = '\0';

	SQL_ReadDriver(hndl, ident, sizeof(ident));
	mysql = StrEqual(ident, "mysql"); // SQLite or MySQL ?

	/*
		When plugin load/reload
		Database clear expired bans, checking by database current time, not server time
	*/

	if(mysql)
	{
		Format(query, sizeof(query), "DELETE FROM `stb2` WHERE `date` < NOW()");
	}
	else
	{
		Format(query, sizeof(query), "DELETE FROM `stb2` WHERE `date` < datetime('now', 'localtime');");
	}

	SQL_LockDatabase(hDatabase);

	if(!SQL_FastQuery(hDatabase, query))
	{
		decl String:err[300]; err[0] = '\0';
		SQL_GetError(hDatabase, err, sizeof(err));
		LogError(" Query DELETE expired bans failed! %s", err);
	}

	SQL_UnlockDatabase(hDatabase);

	if(stb2mode == 0) // Add temporary bans in srcds
	{
		if(mysql)
		{
			Format(query, sizeof(query), "SELECT `steamid`, `unixtime`, `duration` FROM `stb2` WHERE `date` > NOW()");
		}
		else
		{
			Format(query, sizeof(query), "SELECT `steamid`, `unixtime`, `duration` FROM `stb2` WHERE `date` > datetime('now', 'localtime');");
		}

		SQL_LockDatabase(hDatabase);

		new Handle:hndl1 = SQL_Query(hDatabase, query);

		if (hndl1 == INVALID_HANDLE) //Fail
		{
			SQL_UnlockDatabase(hDatabase);

			if(SQL_GetError(hDatabase, query, sizeof(query)))
			{
				LogError(" Query SELECT bans failed! %s", query);
			}
			return;
		}

		SQL_UnlockDatabase(hDatabase);

		new count = SQL_GetRowCount(hndl1);

		decl time, currenttime, String:buffer[25];

		currenttime = GetTime(); // Get server current unixtime

		for(new i = 1; i <= count; i++)
		{
			buffer[0] = '\0';

			if(!SQL_FetchRow(hndl1))
			{
				continue;
			}

			// convert ban time to minutes = (unixtime from db - current unixtime + (duration from db * 60))/60
			if((time = (SQL_FetchInt(hndl1, 1) - currenttime + (SQL_FetchInt(hndl1, 2)*60))/60) > 0)
			{
				SQL_FetchString(hndl1, 0, buffer, sizeof(buffer)); // grab steamid
				InsertServerCommand("banid %i %s", time, buffer); //Collect list server commands
			}
		}
		CloseHandle(hndl1);

		bypass_server_addban = true; // Don't record these bans
		ServerExecute(); // Execute list server commands
		bypass_server_addban = false; // Start record new bans
	}
}

// save ban
public T_SaveSteamID(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError(" Query T_SaveSteamID failed! %s", error);
		CloseHandle(data); // DataPack
		return;
	}

	decl String:entersql[300], String:auth[32], timestamp, duration; entersql[0] = '\0', auth[0] = '\0';

	ResetPack(data);
	ReadPackString(data, auth, sizeof(auth));
	duration = ReadPackCell(data);
	CloseHandle(data);

	// Server current unixtime
	timestamp = GetTime();

	if(!SQL_GetRowCount(hndl)) // No results from database with given steamid
	{
		// Save ban
		if(mysql)
		{
			Format(entersql, sizeof(entersql), "INSERT INTO `stb2` VALUES ('%s', '%i', '%i', DATE_ADD(NOW(), INTERVAL `duration` MINUTE));", auth, timestamp, duration);
		}
		else
		{
			Format(entersql, sizeof(entersql), "INSERT INTO `stb2` VALUES ('%s', '%i', '%i', datetime('now', '+%i MINUTE', 'localtime'));", auth, timestamp, duration, duration);
		}
	}
	else
	{
		// Update ban
		if(mysql)
		{
			Format(entersql, sizeof(entersql), "UPDATE `stb2` SET `unixtime` = '%i', `duration` = '%i', `date` = DATE_ADD(NOW(), INTERVAL `duration` MINUTE) WHERE `steamid` = '%s';", timestamp, duration, auth);
		}
		else
		{
			Format(entersql, sizeof(entersql), "UPDATE `stb2` SET `unixtime` = '%i', `duration` = '%i', `date` = datetime('now', 'localtime', '+%i MINUTE') WHERE `steamid` = '%s';", timestamp, duration, duration, auth);
		}
	}


	SQL_LockDatabase(hDatabase);

	if(!SQL_FastQuery(hDatabase, entersql))
	{
		SQL_GetError(hDatabase, entersql, sizeof(entersql));
		LogError(" Query T_SaveSteamID add ban in db failed! %s", entersql);
		SQL_UnlockDatabase(hDatabase);
		return;
	}

	SQL_UnlockDatabase(hDatabase);

	// stb2_mode not 0, don't leave srcds ban after banning
	if(stb2mode != 0 && !leave_srcds_ban)
	{
		bypass = true; // To skip cmd removeid from forward
		ServerCommand("removeid %s", auth);
		LogToGame("[SM] Save Temporary Bans 2: Removed %s from SRCDS bans and start handle from database", auth); // Add note in game logs
	}
}

// Check player
public T_CheckSteamID(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}

	if (hndl == INVALID_HANDLE)
	{
		LogError(" Query T_CheckSteamID failed! %s", error);
		return;
	}

	if(SQL_FetchRow(hndl)) // Found results from db given steamid
	{
		// Grab unixtime from db - get server current unixtime + (grap ban duration_minutes from db * 60)
		new timeleft = SQL_FetchInt(hndl, 0) - GetTime() + (SQL_FetchInt(hndl, 1)*60);

		if(timeleft > 0) // There time left
		{
			decl String:msg[300], String:buffer[25], String:IP[16], bool:bIP; msg[0] = '\0', buffer[0] = '\0', IP[0] = '\0';

			SQL_FetchString(hndl, 2, buffer, sizeof(buffer)); // Grap ban expired `date` from db

			// Kick reason msg, use translation file stb2.phrases.txt
			Format(msg, sizeof(msg), "%t", "Banned", buffer, "\n", timeleft/86400, (timeleft/3600)%24, (timeleft/60)%60, timeleft%60);

			// Get client IP, in stb2_mode status 2
			bIP = stb2mode == 2 ? GetClientIP(client, IP, sizeof(IP)):false;

			//PrintToChatAll("\x01Dropped %N from server (Banned)\n\x03%i\x01d \x03%i\x01h \x03%i\x01m \x03%i\x01s \x04= \x03%s", client, timeleft/86400, (timeleft/3600)%24, (timeleft/60)%60, timeleft%60, buffer);
			// PrintToChatAll("\x01\n%t\n ", "Banned chat", client, buffer, "\n", timeleft/86400, (timeleft/3600)%24, (timeleft/60)%60, timeleft%60);

			KickClient(client, msg);

			// Add 1 minute IP ban
			if(bIP)
			{
				BanIdentity(IP, 1, BANFLAG_IP, "STB2 kick and add IP ban 1 minute to banned player", "stb2_banip");
			}
		}
	}
}

// Cmd ban list by player, not server/rcon
public T_ListSteamID(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client;

	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(userid)) == 0)
	{
		return;
	}

	if (hndl == INVALID_HANDLE)
	{
		LogError(" Query T_ListSteamID failed! %s", error);
		return;
	}

	// Count results
	new count = SQL_GetRowCount(hndl);

	if(count > 0)
	{

		decl len, startindex, String:msg[300], String:buffer[50]; msg[0] = '\0', buffer[0] = '\0';

		startindex = 0;

		// Loop rows
		for(new i = 1; i <= count; i++)
		{
			// Fetch row
			if(!SQL_FetchRow(hndl))
			{
				continue;
			}

			// There more rows than 5 and this is sixth loop
			if(count > 5 && i == 6)
			{
				Format(msg[startindex], sizeof(msg), "\n There are more results...\0");
				break;
			}

			buffer[0] = '\0'; // erase crap
			len = SQL_FetchString(hndl, 0, buffer, sizeof(buffer)); // Fetch first column

			Format(buffer[len], 25, "%11i", 0); // This make extra spaces after first text, "STEAM_x:x:xxx           0", maybe not good way to do this
			buffer[19] = '='; // Place (=) in string "STEAM_x:x:xxx      =     0"

			SQL_FetchString(hndl, 1, buffer[21], sizeof(buffer)); // Grab ban expired date from db in string "STEAM_x:x:xxx      = 2011-06-08 18:39:15"

			// Build output string
			startindex += Format(msg[startindex], sizeof(msg), "%s\n", buffer);
		}
		// Show output string msg
		PrintToConsole(client, "\n%s\n", msg);
	}
}
