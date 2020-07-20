// Special Infected constants (for spawning)
#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

#define UNINITIALISED -1

// Settings upon load
ConVar hSILimitServerCap;
ConVar hSILimit;
ConVar hSpawnWeights[NUM_TYPES_INFECTED], hScaleWeights;
ConVar hSpawnLimits[NUM_TYPES_INFECTED];
ConVar hSpawnSize;

// Customised settings; cache
new SILimitCache = UNINITIALISED;
new SpawnWeightsCache[NUM_TYPES_INFECTED] = { UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED };
new SpawnLimitsCache[NUM_TYPES_INFECTED] = { UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED };
new SpawnSizeCache = UNINITIALISED;

public SpawnQuantities_OnModuleStart() {
	// Server SI max (marked FCVAR_CHEAT; admin only)
	hSILimitServerCap = CreateConVar("ss_server_si_limit", "16", "特感数量最大上限", FCVAR_CHEAT, true, 1.0);
	// Spawn limits
	hSILimit = CreateConVar("ss_si_limit", "4", "最大存活特感上限", FCVAR_PLUGIN, true, 1.0, true, float(GetConVarInt(hSILimitServerCap)) );
	HookConVarChange(hSILimit, ConVarChanged:CalculateSpawnTimes);
	hSpawnSize = CreateConVar("ss_spawn_size", "3", "每次刷多少个特感", FCVAR_PLUGIN, true, 1.0, true, float(GetConVarInt(hSILimitServerCap)) );
	hSpawnLimits[SI_SMOKER]		= CreateConVar("ss_smoker_limit",	"1", "舌头存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_BOOMER]		= CreateConVar("ss_boomer_limit",	"2", "胖子存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_HUNTER]		= CreateConVar("ss_hunter_limit",	"2", "猎人存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SPITTER]	= CreateConVar("ss_spitter_limit",	"2", "口水存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_JOCKEY]		= CreateConVar("ss_jockey_limit",	"2", "猴子存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_CHARGER]	= CreateConVar("ss_charger_limit",	"1", "牛存活上限", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	// Weights
	hSpawnWeights[SI_SMOKER]	= CreateConVar("ss_smoker_weight",	"50", "刷舌头几率", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_BOOMER]	= CreateConVar("ss_boomer_weight",	"125", "刷胖子几率", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_HUNTER]	= CreateConVar("ss_hunter_weight",	"150", "刷猎人几率", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_SPITTER]	= CreateConVar("ss_spitter_weight", "200", "刷口水几率", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_JOCKEY]	= CreateConVar("ss_jockey_weight",	"150", "刷猴子几率", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_CHARGER]	= CreateConVar("ss_charger_weight", "75", "刷牛几率", FCVAR_PLUGIN, true, 0.0);
	hScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = OFF | 1 = ON ] 根据存活数量动态降低几率", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}


/***********************************************************************************************************************************************************************************

                                                                       LIMIT/WEIGHT UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

LoadCacheSpawnLimits() {
	if( SILimitCache != UNINITIALISED ) SetConVarInt( hSILimit, SILimitCache );
	if( SpawnSizeCache != UNINITIALISED ) SetConVarInt( hSpawnSize, SpawnSizeCache );
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {		
		if( SpawnLimitsCache[i] != UNINITIALISED ) {
			SetConVarInt( hSpawnLimits[i], SpawnLimitsCache[i] );
		}
	}
}

LoadCacheSpawnWeights() {
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {		
		if( SpawnWeightsCache[i] != UNINITIALISED ) {
			SetConVarInt( hSpawnWeights[i], SpawnWeightsCache[i] );
		}
	}
}

ResetWeights() {
	for (new i = 0; i < NUM_TYPES_INFECTED; i++) {
		ResetConVar(hSpawnWeights[i]);
	}
}
