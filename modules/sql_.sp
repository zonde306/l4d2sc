
new bool:mysql;

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