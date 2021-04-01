
#if defined __mapinfo__
#endinput
#endif
#define __mapinfo__

Handle kvData = INVALID_HANDLE;

bool g_bHasStart = false;
bool g_bHasStartExtra = false;
float g_fStartLocA[3];                                                            // coordinates of 1 corner of the start saferoom box
float g_fStartLocB[3];                                                            // and its opposite corner
float g_fStartLocC[3];                                                            // second box for saferoom?
float g_fStartLocD[3];
float g_fStartRotate = 0.0;

bool g_bHasEnd = false;
bool g_bHasEndExtra = false;
float g_fEndLocA[3];
float g_fEndLocB[3];
float g_fEndLocC[3];
float g_fEndLocD[3];
float g_fEndRotate = 0.0;

char g_sMapname[64];

void MapInfo_Init()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	kvData = CreateKeyValues("MapInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/l4d2lib/mapinfo.txt");
	if (!FileToKeyValues(kvData, sNameBuff))
	{
		LogError("[MI] 找不到 mapinfo.txt 文件信息");
		MapInfo_OnPluginEnd();
	}
}

void MapInfo_OnPluginEnd()
{
	if(kvData == INVALID_HANDLE)
		return;
	CloseHandle(kvData);
	kvData = INVALID_HANDLE;
}

void MapInfo_OnMapStart_Update()
{
    // defaults
    g_bHasStart = false;        g_bHasStartExtra = false;
    g_bHasEnd = false;          g_bHasEndExtra = false;
    g_fStartLocA = NULL_VECTOR; g_fStartLocB = NULL_VECTOR; g_fStartLocC = NULL_VECTOR; g_fStartLocD = NULL_VECTOR;
    g_fEndLocA = NULL_VECTOR;   g_fEndLocB = NULL_VECTOR;   g_fEndLocC = NULL_VECTOR;   g_fEndLocD = NULL_VECTOR;
    g_fStartRotate = 0.0;       g_fEndRotate = 0.0;
    
    // get and store map data for this round
    GetCurrentMap(g_sMapname, sizeof(g_sMapname));
    SI_KV_UpdateSaferoomInfo();
}

void MapInfo_OnMapEnd_Update()
{
	KvRewind(kvData);
}

void SI_KV_UpdateSaferoomInfo()
{
    if (kvData == INVALID_HANDLE) {
        LogError("[SI] No saferoom keyvalues loaded!");
        return;
    }
	
    // get keyvalues
    if (KvJumpToKey(kvData, g_sMapname))
    {
        KvGetVector(kvData, "start_loc_a", g_fStartLocA);
        KvGetVector(kvData, "start_loc_b", g_fStartLocB);
        KvGetVector(kvData, "start_loc_c", g_fStartLocC);
        KvGetVector(kvData, "start_loc_d", g_fStartLocD);
        g_fStartRotate = KvGetFloat(kvData, "start_rotate", g_fStartRotate);
        KvGetVector(kvData, "end_loc_a", g_fEndLocA);
        KvGetVector(kvData, "end_loc_b", g_fEndLocB);
        KvGetVector(kvData, "end_loc_c", g_fEndLocC);
        KvGetVector(kvData, "end_loc_d", g_fEndLocD);
        g_fEndRotate = KvGetFloat(kvData, "end_rotate", g_fEndRotate);
        
        // check data:
        if (g_fStartLocA[0] != 0.0 && g_fStartLocA[1] != 0.0 && g_fStartLocA[2] != 0.0 && g_fStartLocB[0] != 0.0 && g_fStartLocB[1] != 0.0 && g_fStartLocB[2] != 0.0) { g_bHasStart = true; }
        if (g_fStartLocC[0] != 0.0 && g_fStartLocC[1] != 0.0 && g_fStartLocC[2] != 0.0 && g_fStartLocD[0] != 0.0 && g_fStartLocD[1] != 0.0 && g_fStartLocD[2] != 0.0) { g_bHasStartExtra = true; }
        if (g_fEndLocA[0] != 0.0 && g_fEndLocA[1] != 0.0 && g_fEndLocA[2] != 0.0 && g_fEndLocB[0] != 0.0 && g_fEndLocB[1] != 0.0 && g_fEndLocB[2] != 0.0) { g_bHasEnd = true; }
        if (g_fEndLocC[0] != 0.0 && g_fEndLocC[1] != 0.0 && g_fEndLocC[2] != 0.0 && g_fEndLocD[0] != 0.0 && g_fEndLocD[1] != 0.0 && g_fEndLocD[2] != 0.0) { g_bHasEndExtra = true; }
        
        // rotate if necessary:
        if (g_fStartRotate != 0.0) {
            RotatePoint(g_fStartLocA, g_fStartLocB[0], g_fStartLocB[1], g_fStartRotate);
            if (g_bHasStartExtra) {
                RotatePoint(g_fStartLocA, g_fStartLocC[0], g_fStartLocC[1], g_fStartRotate);
                RotatePoint(g_fStartLocA, g_fStartLocD[0], g_fStartLocD[1], g_fStartRotate);
            }
        }
        if (g_fEndRotate != 0.0) {
            RotatePoint(g_fEndLocA, g_fEndLocB[0], g_fEndLocB[1], g_fEndRotate);
            if (g_bHasEndExtra) {
                RotatePoint(g_fEndLocA, g_fEndLocC[0], g_fEndLocC[1], g_fEndRotate);
                RotatePoint(g_fEndLocA, g_fEndLocD[0], g_fEndLocD[1], g_fEndRotate);
            }
        }
        
        return;
    }
    else
    {
        LogMessage("[SI] SaferoomInfo for %s is missing.", g_sMapname);
        
        return;
    }
}

/* NATIVE FUNCTIONS */
// New Super Awesome Functions!!!
// ------
public bool IsEntityInSaferoom(int entity)
{
    if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
    
    // get entity location
    float location[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
    
    return (IsPointInStartSaferoom(location) || IsPointInEndSaferoom(location));
}

public bool IsEntityInStartSaferoom(int entity)
{
    if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
    
    // get entity location
    float location[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
    
    return IsPointInStartSaferoom(location);
}

public bool IsEntityInEndSaferoom(int entity)
{
    if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
    
    // get entity location
    float location[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
    
    return IsPointInEndSaferoom(location);
}


public bool IsPlayerInSaferoom(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return false;
    
    // get client location
    float locationA[3], locationB[3];
    
    // try both abs & eye
    GetClientAbsOrigin(client, locationA);
    GetClientEyePosition(client, locationB);
    
    return view_as<bool>(IsPointInStartSaferoom(locationA) || IsPointInStartSaferoom(locationB) || IsPointInEndSaferoom(locationA) || IsPointInEndSaferoom(locationB));
}

public bool IsPlayerInStartSaferoom(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return false;
    
    // get client location
    float locationA[3], locationB[3];
    
    // try both abs & eye
    GetClientAbsOrigin(client, locationA);
    GetClientEyePosition(client, locationB);
    
    return view_as<bool>(IsPointInStartSaferoom(locationA) || IsPointInStartSaferoom(locationB));
}

public bool IsPlayerInEndSaferoom(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return false;
    
    // get client location
    float locationA[3], locationB[3];
    
    // try both abs & eye
    GetClientAbsOrigin(client, locationA);
    GetClientEyePosition(client, locationB);
    
    return view_as<bool>(IsPointInEndSaferoom(locationA) || IsPointInEndSaferoom(locationB));
}

stock bool IsPointInStartSaferoom(float location[3], int entity = -1)
{
	if (!g_bHasStart) return false;
	
	bool inSaferoom = false;
	
	// rotate point if necessary
	if (g_fStartRotate)
	{
		RotatePoint(g_fStartLocA, location[0], location[1], g_fStartRotate);
	}
	
	// check if the point is inside the box (end or start)
	float xMin, xMax, yMin, yMax, zMin, zMax;
	
	if (g_fStartLocA[0] < g_fStartLocB[0]) { xMin = g_fStartLocA[0]; xMax = g_fStartLocB[0]; } else { xMin = g_fStartLocB[0]; xMax = g_fStartLocA[0]; }
	if (g_fStartLocA[1] < g_fStartLocB[1]) { yMin = g_fStartLocA[1]; yMax = g_fStartLocB[1]; } else { yMin = g_fStartLocB[1]; yMax = g_fStartLocA[1]; }
	if (g_fStartLocA[2] < g_fStartLocB[2]) { zMin = g_fStartLocA[2]; zMax = g_fStartLocB[2]; } else { zMin = g_fStartLocB[2]; zMax = g_fStartLocA[2]; }
	
	//PrintDebug("dimensions checked: %f - %f (%f) -- %f - %f (%f) -- %f - %f (%f)", xMin, xMax, location[0], yMin, yMax, location[1], zMin, zMax, location[2]);
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
		
	// two-part saferooms:
	if (!inSaferoom && g_bHasStartExtra)
	{
		if (g_fStartLocC[0] < g_fStartLocD[0]) { xMin = g_fStartLocC[0]; xMax = g_fStartLocD[0]; } else { xMin = g_fStartLocD[0]; xMax = g_fStartLocC[0]; }
		if (g_fStartLocC[1] < g_fStartLocD[1]) { yMin = g_fStartLocC[1]; yMax = g_fStartLocD[1]; } else { yMin = g_fStartLocD[1]; yMax = g_fStartLocC[1]; }
		if (g_fStartLocC[2] < g_fStartLocD[2]) { zMin = g_fStartLocC[2]; zMax = g_fStartLocD[2]; } else { zMin = g_fStartLocD[2]; zMax = g_fStartLocC[2]; }
		
		//PrintDebug("extra dimensions checked: %f - %f (%f) -- %f - %f (%f) -- %f - %f (%f)", xMin, xMax, location[0], yMin, yMax, location[1], zMin, zMax, location[2]);
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	return inSaferoom;
}

stock bool IsPointInEndSaferoom(float location[3], int entity = -1)
{    
	if (!g_bHasEnd) return false;
	
	bool inSaferoom = false;
	
	// rotate point if necessary
	if (g_fEndRotate)
	{
		RotatePoint(g_fEndLocA, location[0], location[1], g_fEndRotate);
	}
	
	// check if the point is inside the box (end or start)
	float xMin, xMax,	yMin, yMax, zMin, zMax;
	
	if (g_fEndLocA[0] < g_fEndLocB[0]) { xMin = g_fEndLocA[0]; xMax = g_fEndLocB[0]; } else { xMin = g_fEndLocB[0]; xMax = g_fEndLocA[0]; }
	if (g_fEndLocA[1] < g_fEndLocB[1]) { yMin = g_fEndLocA[1]; yMax = g_fEndLocB[1]; } else { yMin = g_fEndLocB[1]; yMax = g_fEndLocA[1]; }
	if (g_fEndLocA[2] < g_fEndLocB[2]) { zMin = g_fEndLocA[2]; zMax = g_fEndLocB[2]; } else { zMin = g_fEndLocB[2]; zMax = g_fEndLocA[2]; }
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	
	// two-part saferooms:
	if (!inSaferoom && g_bHasEndExtra)
	{
		if (g_fEndLocC[0] < g_fEndLocD[0]) { xMin = g_fEndLocC[0]; xMax = g_fEndLocD[0]; } else { xMin = g_fEndLocD[0]; xMax = g_fEndLocC[0]; }
		if (g_fEndLocC[1] < g_fEndLocD[1]) { yMin = g_fEndLocC[1]; yMax = g_fEndLocD[1]; } else { yMin = g_fEndLocD[1]; yMax = g_fEndLocC[1]; }
		if (g_fEndLocC[2] < g_fEndLocD[2]) { zMin = g_fEndLocC[2]; zMax = g_fEndLocD[2]; } else { zMin = g_fEndLocD[2]; zMax = g_fEndLocC[2]; }
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	return inSaferoom;
}

// Support functions
// -----------------

// rotate a point (x,y) over an angle, with ref. to an origin (x,y plane only)
stock void RotatePoint(float SD_origin[3], float &pointX, float &pointY, float angle)
{
    // translate angle to radians:
    float newPoint[2];
    angle = angle / 57.2957795130823;
    newPoint[0] = (Cosine(angle) * (pointX - SD_origin[0])) - (Sine(angle) * (pointY - SD_origin[1]))   + SD_origin[0];
    newPoint[1] = (Sine(angle) * (pointX - SD_origin[0]))   + (Cosine(angle) * (pointY - SD_origin[1])) + SD_origin[1];
    pointX = newPoint[0];
    pointY = newPoint[1];
    return;
}

stock int GetMapValueInt(const char[] key, const int defvalue = 0) 
{
	return KvGetNum(kvData, key, defvalue); 
}
stock float GetMapValueFloat(const char[] key, const float defvalue = 0.0) 
{
	return KvGetFloat(kvData, key, defvalue); 
}
stock void GetMapValueVector(const char[] key, float vector[3], const float defvalue[3] = NULL_VECTOR) 
{
	KvGetVector(kvData, key, vector, defvalue);
}

stock void GetMapValueString(const char[] key, char[] value, int maxlength, const char[] defvalue="")
{
	KvGetString(kvData, key, value, maxlength, defvalue);
}

stock void CopyMapSubsection(Handle kv, const char[] section)
{
	if(KvJumpToKey(kvData, section, false))
	{
		KvCopySubkeys(kvData, kv);
		KvGoBack(kvData);
	}
}
