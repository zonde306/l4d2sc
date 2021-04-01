#pragma semicolon 1

#if defined l4d2util_inc_
    #endinput
#endif
#define l4d2util_inc_

#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))

#define TEAM_NONE 0
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

const NUM_OF_SURVIVORS = 4;

enum SurvivorCharacter
{
    SC_NONE=-1,
    SC_COACH=0,
    SC_NICK,
    SC_ROCHELLE,
    SC_ELLIS,
    SC_LOUIS,
    SC_ZOEY,
    SC_BILL,
    SC_FRANCIS
};

char SurvivorNames[8][128] =
{
    "Coach",
    "Nick",
    "Rochelle",
    "Ellis",
    "Louis",
    "Zoey",
    "Bill",
    "Francis"
};

#define ZC_NONE 0
#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_WITCH 7
#define ZC_TANK 8

#define GAMEMODE_UNKNOWN -1
#define GAMEMODE_COOP 0
#define GAMEMODE_VERSUS 1
#define GAMEMODE_SCAVENGE 2
#define GAMEMODE_SURVIVAL 3

static Handle hSurvivorModelsTrie = INVALID_HANDLE;

// Models for each of the characters
char SurvivorModels[8][128] =
{
    "models/survivors/survivor_coach.mdl",
    "models/survivors/survivor_gambler.mdl",
    "models/survivors/survivor_producer.mdl",
    "models/survivors/survivor_mechanic.mdl",
    "models/survivors/survivor_manager.mdl",
    "models/survivors/survivor_teenangst.mdl",
    "models/survivors/survivor_namvet.mdl",
    "models/survivors/survivor_biker.mdl"
};

char L4D2_InfectedNames[9][] =
{
    "",
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Witch",
    "Tank"
};

// Internal array of strings for timer ability timer entity classnames
char L4D2_InfectedTimerEntities[8][128] =
{
    "ability_tongue",
    "ability_vomit",
    "ability_lunge",
    "ability_spit",
    "ability_leap",
    "ability_charge",
    "",
    ""
};

// Internal array of strings for Infected victim netprops
char L4D2_InfectedVictimNetprops[9][128] =
{
	"",
    "m_tongueVictim",
    "",
    "m_pounceVictim",
    "",
    "m_jockeyVictim",
    "m_pummelVictim",
    "",
    ""
};

enum L4D2GlowType 
{ 
	L4D2Glow_None = 0, 
	L4D2Glow_OnUse, 
	L4D2Glow_OnLookAt, 
	L4D2Glow_Constant 
};

/*================================================================
                              PLAYER
================================================================*/

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients;
}

stock bool IsConnectedAndInGame(int client)
{
	return IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsValidInGame(int client)
{
	return IsValidClient(client) && IsConnectedAndInGame(client);
}

stock bool IsSpectator(int client)
{
	return GetClientTeam(client) == TEAM_SPECTATOR;
}

stock bool IsSurvivor(int client)
{
	return GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool IsInfected(int client)
{
	return GetClientTeam(client) == TEAM_INFECTED;
}

stock bool IsValidSpectator(int client)
{
	return IsValidInGame(client) && IsSpectator(client);
}

stock bool IsValidSurvivor(int client)
{
	return IsValidInGame(client) && IsSurvivor(client);
}
stock bool IsValidInfected(int client)
{
	return IsValidInGame(client) && IsInfected(client);
}
stock bool IsSurvivorAlive(int client)
{
	return IsValidSurvivor(client) && IsPlayerAlive(client);
}
stock bool IsInfectedAlive(int client)
{
	return IsValidInfected(client) && IsPlayerAlive(client);
}

stock bool IsClientAdmin(int client)
{
	AdminId id = GetUserAdmin(client);
	if (id == INVALID_ADMIN_ID) return false;
	if (GetAdminFlag(id, Admin_Reservation) || GetAdminFlag(id, Admin_Root) || 	GetAdminFlag(id, Admin_Kick) || GetAdminFlag(id, Admin_Generic)) return true;
	return false;
}

/*================================================================
                              SURVIVORS
================================================================*/
stock int IsPinned(int client)
{
	int attacker;
	attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if (attacker > 0) return attacker;
	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if (attacker > 0) return attacker;
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0) return attacker;
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0) return attacker;
	attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (attacker > 0) return attacker;
	return -1;
}

/**
 * 如果玩家无行为能力, 则返回true. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsPlayerIncap(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

/**
 * Returns the amount of permanent health a survivor has. 
 *
 * @param client client ID
 * @return bool
 */
stock int GetSurvivorPermanentHealth(int client)
{
	// Survivors always have minimum 1 permanent hp
	// so that they don't faint in place just like that when all temp hp run out
	// We'll use a workaround for the sake of fair calculations
	// Edit 2: "Incapped HP" are stored in m_iHealth too; we heard you like workarounds, dawg, so we've added a workaround in a workaround
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

/**
 * Returns the amount of temporary health a survivor has. 
 *
 * @param client client ID
 * @return bool
 */
stock int GetSurvivorTemporaryHealth(int client)
{
    float fDecayRate = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
    float fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    float fHealthBufferTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    int iTempHp = RoundToCeil(fHealthBuffer - ((GetGameTime() - fHealthBufferTime) * fDecayRate)) - 1;
    return iTempHp > 0 ? iTempHp : 0;
}

/**
 * The number of times a survivor has been incapacitated.
 *
 * @param client client ID
 * @return incap count
 */
stock int GetSurvivorIncapCount(int client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

/**
 * 如果幸存者被挂到窗台(或从一个下降到灭亡), 则返回true.
 *
 * @param client client ID
 * @return bool
 */
stock bool IsHangingFromLedge(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

/**
 * Initializes internal structure necessary for IdentifySurvivor() function
 * @remark It is recommended that you run this function on plugin start, but not necessary
 *
 * @noreturn
 */
stock void InitSurvivorModelTrie()
{
    hSurvivorModelsTrie = CreateTrie();
    for (int i = 0; i < 8; i++)
		SetTrieValue(hSurvivorModelsTrie, SurvivorModels[i], i);
}

/**
 * Identifies a client's survivor character based on their current model.
 * @remark SC_NONE on errors
 *
 * @param client                Survivor client to identify
 * @return SurvivorCharacter    index identifying the survivor, or SC_NONE if not identified.
 */
stock SurvivorCharacter IdentifySurvivor(int client)
{
    if (!IsValidSurvivor(client)) return SC_NONE;
    char clientModel[42];
    GetClientModel(client, clientModel, sizeof(clientModel));
    return ClientModelToSC(clientModel);
}

/**
 * Identifies the survivor character corresponding to a player model.
 * @remark SC_NONE on errors, uses SurvivorModelTrie
 *
 * @param model                 Player model to identify
 * @return SurvivorCharacter    index identifying the model, or SC_NONE if not identified.
 */
stock SurvivorCharacter ClientModelToSC(const char[] model)
{
    if (hSurvivorModelsTrie == INVALID_HANDLE) InitSurvivorModelTrie();
    SurvivorCharacter sc;
    if (GetTrieValue(hSurvivorModelsTrie, model, sc)) return sc;
    return SC_NONE;
}

/**
 * Get the name of a survivor character.
 *
 * @param character     SurvivorCharacter to get the name of
 * @param buffer        buffer to store name
 * @param length        length of buffer
 * @return bool         false if SC_NONE, otherwise true
 */
stock bool GetSurvivorName(int character, char[] buffer, int length)
{
    if (character == SC_NONE) return false;
    strcopy(buffer, length, SurvivorNames[view_as<int>(character)]);
    return true;
}

stock bool IsMelee(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char strClassName[64];
		GetEdictClassname(entity, strClassName, sizeof(strClassName));
		return StrContains(strClassName, "melee", false) != -1;
	}
	return false;
}

stock float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + (GetConVarFloat(FindConVar("versus_boss_buffer")) / L4D2Direct_GetMapMaxFlowDistance());
	return MAX(proximity, 0.0);
}

stock float GetMaxSurvivorCompletion()
{
	float flow = 0.0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			flow = MAX(flow, L4D2Direct_GetFlowDistance(index));
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

stock int GetRandomSurvivor()
{
	int survivors[NUM_OF_SURVIVORS];
	int numSurvivors = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
		    survivors[numSurvivors] = index;
		    numSurvivors++;
		}
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

stock void PrintToSurvivors(const char[] Message, any ... )
{
    char sPrint[256];
    VFormat(sPrint, sizeof(sPrint), Message, 2);

    for (int i = 1; i <= MaxClients; i++)
	{
        if (!IsConnectedAndInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) continue;
        PrintToChat(i, "\x01%s", sPrint);
    }
}

/*================================================================
                              SPECIAL INFECTED
================================================================*/
/**
 * Returns the ID of the client's infected class. Use GetInfectedClassName()
 * to convert it to a string.
 *
 * @param client client ID
 * @return class ID
 */
stock int GetInfectedClass(int client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * Return true if the infected is in ghost (spawn) mode.
 *
 * @param client client ID
 * @return bool
 */
stock bool IsInfectedGhost(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

/**
 * Converts an infected type ID to a string.
 *
 * @param iClass infected class ID
 * @param sBuffer buffer to store the class name in
 * @param iBufLen size of sBuffer
 * @noreturn
 */
stock void GetInfectedClassName(int iClass, char[] sBuffer, int iBufLen)
{
    strcopy(sBuffer, iBufLen, L4D2_InfectedNames[iClass]); 
}

/**
 * Internal function for retrieving the game entity associtated with an ability
 *
 * @param owner client ID of the entity's owner
 * @param type classname of entity
 * @return entity ID or -1
 */
stock int GetInfectedAbilityTimerEntity(int owner, const char[] type)
{
    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, type)) != -1)
	{
        if (GetEntPropEnt(iEntity, Prop_Send, "m_owner") == owner) break;
    }
    return iEntity;
}

/**
 * Get the timestamp and duration of an SI's ability timer
 *
 * @param client whose timer to get
 * @param timestamp output parameter for the timestamp
 * @param duration output parameter for the duration
 * @return true if the timer was found otherwise false
 */
stock bool GetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
    int zClass = GetInfectedClass(client);
    int ability = -1;
    if (strlen(L4D2_InfectedTimerEntities[zClass-1]) == 0) return false;
    ability = GetInfectedAbilityTimerEntity(client, L4D2_InfectedTimerEntities[zClass-1]);
    if (ability == -1) return false;
    timestamp = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
    duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
    return true;
}

/**
 * Set the timestamp and duration of an SI's ability timer
 *
 * @param client whose timer to set
 * @param timestamp
 * @param duration
 * @return true if the timer was found otherwise false
 */
stock bool SetInfectedAbilityTimer(int client, float timestamp, float duration)
{
    int zClass = GetInfectedClass(client);
    int ability = -1;
    if (strlen(L4D2_InfectedTimerEntities[zClass-1]) == 0) return false;
    ability = GetInfectedAbilityTimerEntity(client, L4D2_InfectedTimerEntities[zClass-1]);
    if (ability == -1) return false;
    SetEntPropFloat(ability, Prop_Send, "m_timestamp", timestamp);
    SetEntPropFloat(ability, Prop_Send, "m_duration", duration);
    return true;
}

/**
 * 获取受感染的受害者. 受害者是一名幸存者, 目前正在被控制, 即吸烟, 被控, 狩猎或骑师.
 *
 * @param client whose victim to get
 * @return client ID or -1 on error
 */
stock bool GetInfectedVictim(int client)
{
    int zClass = GetInfectedClass(client);
    if (strlen(L4D2_InfectedVictimNetprops[zClass]) == 0) return false;
    int victim = GetEntPropEnt(client, Prop_Send, L4D2_InfectedVictimNetprops[zClass]);
	return (IsValidSurvivor(victim) && IsPlayerAlive(victim));
}

stock bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }
    return false;
}

/*================================================================
                              TANK
================================================================*/

/**
 * Tanks frustation level in the range 0-100, where 100 is when the rage meter
 * is full.
 *
 * @param iTankClient tank's client ID
 * @return frustration level
 */
stock int GetTankFrustration(int iTankClient)
{
    return (100 - GetEntProp(iTankClient, Prop_Send, "m_frustration"));
}

/**
 * Sets the tank's frustration level.
 *
 * @param iTankClient tank's client ID
 * @param iFrustration frustration level (0-100)
 * @noreturn
 */
stock void SetTankFrustration(int iTankClient, int iFrustration)
{
    if (iFrustration < 0 || iFrustration > 100) return;
    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}

/**
 * Returns true if the tank is on fire.
 * @remarks This should work for any client ID, even if they are not the tank 
 *
 * @param iTankClient tank's client ID
 * @param bool
 */
stock bool IsTankOnFire(int iTankClient)
{
    return view_as<bool>(GetEntityFlags(iTankClient) & FL_ONFIRE);
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindTank()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsConnectedAndInGame(i) && GetClientTeam(i) == 3 && GetInfectedClass(i) == ZC_TANK && IsPlayerAlive(i)) return i;
	}
	return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool IsTankInPlay()
{
    return view_as<bool>(FindTank() != -1);
}

/**
 * Counts the number of tanks currently in play.
 *
 * @return number of tanks in play
 */
stock int NumTanksInPlay()
{
    int count = 0;
    int client = -1;
    while ((client = FindTankClient(client)) != -1) ++count;
    return count;
}

stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) - view_as<float>(GetConVarInt(FindConVar("versus_boss_buffer"))) / L4D2Direct_GetMapMaxFlowDistance();
}

stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - view_as<float>(GetConVarInt(FindConVar("versus_boss_buffer"))) / L4D2Direct_GetMapMaxFlowDistance();
}


/**
 * Is the tank able to punch the entity with the tank for instant incaps? 
 *
 * @param iEntity entity ID
 * @return bool
 */

stock bool IsTankHittable(int iEntity)
{
	if (!IsValidEntity(iEntity)) return false;
	
	char className[64];
	GetEdictClassname(iEntity, className, sizeof(className));
	if (StrEqual(className, "prop_physics"))
	{
		if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) return true;
	}
	else if (StrEqual(className, "prop_car_alarm")) return true;
	
	return false;
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Type(int entity, L4D2GlowType type)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", _:type);
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Range(int entity, int range)
{
	SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange        Glow min range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_MinRange(int entity, int minRange)
{
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride    Glow color, RGB.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_ColorOverride(int entity, int colorOverride[3])
{
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing        Whether glow will be flashing.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Flashing(int entity, bool flashing)
{
	SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
stock bool L4D2_SetEntGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1)
	{
		return false;    
	}

	L4D2_SetEntGlow_Type(entity, type);
	L4D2_SetEntGlow_Range(entity, range);
	L4D2_SetEntGlow_MinRange(entity, minRange);
	L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
	L4D2_SetEntGlow_Flashing(entity, flashing);
	return true;
}

stock bool L4D2_SetEntGlowOverride(int entity, int colorOverride[3])
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1)
	{
		return false;    
	}

	L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
	return true;
}

/*================================================================
                              MISC
================================================================*/

stock void GetEntityName(int entity, char[] name, int size)
{
    GetEntPropString(entity, Prop_Data, "m_iName", name, size);
}

stock void GetEntityModelName(int entity, char[] name, int size)
{
	GetEntPropString(entity, Prop_Data, "m_ModelName", name, size);
}

stock void RemoveEntityLog(int entity)
{
	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	if (!AcceptEntityInput(entity, "kill")) LogError("[Entity] 删除物品实例 %s 错误", classname);
}

/**
 * 目前正在玩这张地图的第二轮?
 *
 * @return int
 */
stock int InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

//DDRKhat thanks http://forums.alliedmods.net/showpost.php?p=811533&postcount=76
stock int Gamemode() // 0 = Co-Op, 1 = Versus, 2 = Survival. False on anything else.
{
	char gmode[20];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));
	
	if( StrEqual(gmode, "coop") || StrEqual(gmode, "realism") || StrEqual(gmode, "mutation1") 
		|| StrEqual(gmode, "mutation2") || StrEqual(gmode, "mutation3") || StrEqual(gmode, "mutation4") 
		|| StrEqual(gmode, "mutation5") || StrEqual(gmode, "mutation7") || StrEqual(gmode, "mutation8") 
		|| StrEqual(gmode, "mutation9") || StrEqual(gmode, "mutation10") || StrEqual(gmode, "mutation14") 
		|| StrEqual(gmode, "mutation16") || StrEqual(gmode, "mutation17") || StrEqual(gmode, "mutation20") 
		|| StrEqual(gmode, "community1") || StrEqual(gmode, "community2") || StrEqual(gmode, "community5") )
		return GAMEMODE_COOP;
	else if( StrEqual(gmode,"versus") || StrEqual(gmode, "teamversus") || StrEqual(gmode, "mutation11") 
		|| StrEqual(gmode, "mutation12") || StrEqual(gmode, "mutation18") || StrEqual(gmode, "mutation19") 
		|| StrEqual(gmode, "community3") )
		return GAMEMODE_VERSUS;
	else if( StrEqual(gmode, "scavenge") || StrEqual(gmode, "teamscavenge") || StrEqual(gmode, "mutation13") )
		return GAMEMODE_SCAVENGE;
	else if( StrEqual(gmode, "survival") || StrEqual(gmode, "mutation15") || StrEqual(gmode, "community4") )
		return GAMEMODE_SURVIVAL;
	else
		return GAMEMODE_UNKNOWN;
}

stock int ClientCheatCommand(int client, const char[] command, const char[] arguments="")
{
	if (!IsValidInGame(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsConnectedAndInGame(i)) client = i;
		}
	}
	if (!IsValidInGame(client)) return;
	
	int admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

stock void CheatCommand(char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    int flags = GetCommandFlags(commandName);       
    if (flags != INVALID_FCVAR_FLAGS)
	{
		int commandDummy = -1;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsConnectedAndInGame(i) && IsFakeClient(i))
			{
				char clientName[32];
				GetClientName(i, clientName, sizeof(clientName));
				if (StrContains(clientName, "[CommandBot]") != -1) commandDummy = i;
			}  		
		}
		if (!IsValidInGame(commandDummy) || IsClientInKickQueue(commandDummy))
		{
		    commandDummy = CreateFakeClient("[CommandBot]");
		    if (IsValidInGame(commandDummy)) ChangeClientTeam(commandDummy, 1);
			else commandDummy = GetRandomSurvivor();			
		}
		
		if (IsValidInGame(commandDummy))
		{
		    int originalUserFlags = GetUserFlagBits(commandDummy);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(commandDummy, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(commandDummy, originalUserFlags);            
		}
		else
		{
			char pluginName[128];
			GetPluginFilename( INVALID_HANDLE, pluginName, sizeof(pluginName) );        
			LogError( "%s could not find or create a client through which to execute cheat command %s", pluginName, commandName );
		}   
		
		if (IsValidInGame(commandDummy) && !IsClientInKickQueue(commandDummy) && 
		IsFakeClient(commandDummy) && IsValidSpectator(commandDummy)) CreateTimer(0.1, Timer_KickBot, commandDummy, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_KickBot(Handle timer, any client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}
