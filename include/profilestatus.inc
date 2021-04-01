/*
**
*/
#if defined _profilestatus_included
 #endinput
#endif
#define _profilestatus_included

/**
 * Gets player's hours from the API response body.
 *
 * @param responseBody           API response body.
 */

stock int GetPlayerHours(const char[] responseBody) {
	
	char str[8][64];
	
	ExplodeString(responseBody, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 8; i++) {
		
		if (StrContains(str[i], "playtime_forever") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' days since their last VAC Ban from the API response body.
 *
 * @param responseBodyBans          API response body.
 */

stock int GetDaysSinceLastVAC(const char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "DaysSinceLastBan") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' VAC Ban amount from the API response body.
 *
 * @param responseBodyBans          API response body.
 */

stock int GetVACAmount(const char[] responseBodyBans) {
	
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfVACBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' amount of Game Bans from the API response body.
 *
 * @param responseBodyBans          API response body.
 */

stock int GetGameBans(char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfGameBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' Steam level from the API response body.
 *
 * @param responseBodyLevel          API response body.
 */

stock int GetSteamLevel(const char[] responseBodyLevel) {
	
	char str[10][64];
	
	ExplodeString(responseBodyLevel, "_level\":", str, sizeof(str), sizeof(str[]));
	
	char str2[2][64];
	
	ExplodeString(str[1], "}", str2, sizeof(str2), sizeof(str2[]));
	
	if (str2[0][0] == '\0')
		return -1;
	else
		return (StringToInt(str2[0]));
	}

/**
 * Gets players' Community Visibility State from the API response body.
 *
 * @param responseBodyPrivate          API response body.
 */

stock int GetCommVisibState(const char[] responseBodyPrivate) {
	
	char str[10][512];
	
	ExplodeString(responseBodyPrivate, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 10; i++) {
		
		if (StrContains(str[i], "communityvisibilitystate", false) != -1) {
			
			char str2[3][32];
			
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			return (StringToInt(str2[1]));
		}
		
	}
	return -1;
}

/**
 * Returns true if player is VAC Banned, false otherwise.
 *
 * @param responseBodyBans          API response body.
 */

stock bool IsVACBanned(const char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "VACBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
}

/**
 * Returns true if player is Community Banned, false otherwise.
 *
 * @param responseBodyBans          API response body.
 */

stock bool IsCommunityBanned(const char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "CommunityBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
}

/**
 * Returns players' Economy Ban status.
 *
 * @param responseBodyBans          API response body.
 * @param EcBan          Variable to store the type of Economy Ban.
 */

stock void GetEconomyBans(const char[] responseBodyBans, char[] EcBan) { 
    char str[7][64];
    
    ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
    
    for (int i = 0; i < 7; i++) {
        
        if (StrContains(str[i], "EconomyBan") != -1) {
            
            char str2[2][32];
            ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
            strcopy(EcBan, 15, str2[1]);
            
        }
    }
    
}

/**
 * Returns true if API Key matches regex, false otherwise.
 *
 * @param responseBody          API response body.
 */

stock bool IsAPIKeyCorrect(char[] cAPIKey) {
	return (cAPIKey[0] == '\0' || !SimpleRegexMatch(cAPIKey, "^[0-9A-Z]*$")) ? false : true;
}