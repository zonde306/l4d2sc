#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <smlib>
#include <smlib/games/nmrih> //From Infinite Ammo and Everyone Respawns

//SourceMod Forum release Link
//https://forums.alliedmods.net/showthread.php?p=2182786

public Plugin:myinfo = {
	name = "生存模式管理器",
	author = "Tast - SDC",
	description = "生存地图修改工具",
	version = "0.23",
	url = "http://tast.xclub.tw/viewthread.php?tid=118"
};

new zho = 0
new wave = 0
new Endwave = 0
new PluginEnable = 0
new String:MapName[64]
new Float:ExtractTime = 0.0
new Ent_nmrih_extract_point = -1

new Handle:g_nms_Enable = INVALID_HANDLE
new Handle:g_nms_endwave = INVALID_HANDLE
new Handle:g_nms_increase = INVALID_HANDLE
new Handle:g_nms_resupply = INVALID_HANDLE
new Handle:g_nms_initial = INVALID_HANDLE
new Handle:g_nms_runner = INVALID_HANDLE
new Handle:g_nms_child = INVALID_HANDLE
new Handle:g_nms_keypad = INVALID_HANDLE
new Handle:g_nms_health = INVALID_HANDLE
new Handle:g_nms_extract = INVALID_HANDLE
new Handle:g_nms_custom = INVALID_HANDLE
new Handle:g_nms_runner_chance = INVALID_HANDLE

#define WaveEnd 1
#define WaveIncrease 2
#define WaveResupply 3
#define WaveInitial 4
#define WaveRunner 5
#define WaveChild 6
#define WaveCustom 7
#define WaveRunnerChance 8

//To do
//add force map Extraction_Begin , end , win , fail
//command for delete npc supply_chopper
//auto create original map Parameters file (By convar )

public OnPluginStart(){
	//HookEvent("player_extracted", Event_player_extracted);
	
	AddServerTag("SuperNMS");
	
	HookEvent("new_wave", Event_new_wave);
	HookEvent("state_change", state_change,EventHookMode_Pre);
	HookEvent("extraction_begin", Event_Extraction_Begin);
	
	if(GetLanguageByCode("chi") != -1 && GetServerLanguage() == GetLanguageByCode("chi")){
		zho = 1
		
		g_nms_Enable 	= CreateConVar("nms_enable", 		"1",	"是否开启插件")
		g_nms_endwave 	= CreateConVar("nms_endwave", 		"10",	"地图的僵尸波数上限")
		g_nms_increase 	= CreateConVar("nms_increase", 		"10",	"每到下一波增加多少僵尸")
		g_nms_resupply 	= CreateConVar("nms_resupply", 		"3",	"每隔多少波僵尸投放一次补给")
		g_nms_initial 	= CreateConVar("nms_initial", 		"20",	"初始僵尸数量")
		g_nms_runner 	= CreateConVar("nms_runner", 		"5",	"第几波开始出现跑尸")
		g_nms_child 	= CreateConVar("nms_child", 		"4",	"第几波开始出现小孩")
		g_nms_keypad 	= CreateConVar("nms_keypad", 		"0",	"是否自动解开密码锁")
		g_nms_health	= CreateConVar("nms_health",		"1",	"是否自动放置医疗箱")
		g_nms_extract	= CreateConVar("nms_extract",		"0",	"救援到达后是否自动传送到逃脱点")
		g_nms_custom	= CreateConVar("nms_custom",		"1",	"是否在非官方图使用此插件")
		g_nms_runner_chance	= CreateConVar("nms_runner_chance",	"0.1",	"跑尸出现几率") //或許無效
		
		RegAdminCmd("sm_nmb", Command_Test, ADMFLAG_ROOT,"显示生存地图信息");
		RegAdminCmd("sm_win", Command_CustomWinComplete, ADMFLAG_ROOT,"强制获得生存地图胜利");
		RegAdminCmd("sm_lost", Command_CustomWinFailed, ADMFLAG_ROOT,"强制生存地图失败");
	}
	else {
		zho = 0
		
		g_nms_Enable 	= CreateConVar("nms_enable", 		"0",	"NMS Editor Enable / Disable",FCVAR_NOTIFY)
		g_nms_endwave 	= CreateConVar("nms_endwave", 		"0",	"Players win after reaching this wave.")
		g_nms_increase 	= CreateConVar("nms_increase", 		"0",	"Spawn count increases by this much per wave.")
		g_nms_resupply 	= CreateConVar("nms_resupply", 		"0",	"Resupply wave occurs once every this many waves.")
		g_nms_initial 	= CreateConVar("nms_initial", 		"0",	"How much zombie on first wave.")
		g_nms_runner 	= CreateConVar("nms_runner", 		"0",	"Runners don't spawn until this wave.")
		g_nms_child 	= CreateConVar("nms_child", 		"0",	"Children don't spawn until this wave.")
		g_nms_keypad 	= CreateConVar("nms_keypad", 		"0",	"Auto unlock keypad.")
		g_nms_health	= CreateConVar("nms_health",		"0",	"Auto place health station.")
		g_nms_extract	= CreateConVar("nms_extract",		"0",	"Auto transfer players to extraction point.")
		g_nms_custom	= CreateConVar("nms_custom",		"0",	"Use a custom win scenario using I/O rather than directly winning on end wave.")
		g_nms_runner_chance	= CreateConVar("nms_runner_chance",	"0.0",	"Max runner chance") //maybe not work
		
		RegAdminCmd("nms", Command_Test, ADMFLAG_ROOT,"Show NMS map parameters");
		RegAdminCmd("nms_win", Command_CustomWinComplete, ADMFLAG_ROOT,"Force Direct custom Win");
		RegAdminCmd("nms_fail", Command_CustomWinFailed, ADMFLAG_ROOT,"Force Direct custom Failed");
	}
	AutoExecConfig(true, "nmp_SuperNMS");
	AddAmbientSoundHook(AmbientSHook);
}

/*
- _max_runner_chance (Save|Key)(4 Bytes) - max_runner_chance
- _useCustomWinScenario (Save|Key)(1 Bytes) - use_custom_win
- InputStartWaves (Input)(0 Bytes) - InputStartWaves
- InputCustomWinComplete (Input)(0 Bytes) - InputCustomWinComplete
- InputCustomWinFailed (Input)(0 Bytes) - InputCustomWinFailed
- _OnCustomWinBegin (Save|Key|Output)(0 Bytes) - OnCustomWinBegin
*/

public Action:Command_CustomWinComplete(id, Args){
	if(!IsMapNMS()){
		if(zho) PrintToChat(id,"这个地图不是生存模式")
		else	PrintToChat(id,"Not nms map.")
		return
	}
	
	AcceptEntityInput(Entity_FindByClassName(-1, "overlord_wave_controller"), "InputCustomWinComplete");
}

public Action:Command_CustomWinFailed(id, Args){
	if(!IsMapNMS()){
		if(zho) PrintToChat(id,"这个地图不是生存模式")
		else	PrintToChat(id,"Not nms map.")
		return
	}
	
	AcceptEntityInput(Entity_FindByClassName(-1, "overlord_wave_controller"), "InputCustomWinFailed");
}

public Event_Extraction_Begin(Handle:hEvent, const String:name[], bool:dontBroadcast){
	new entity = Entity_FindByClassName(-1, "nmrih_extract_point")
	if(!IsMapNMS() || !GetConVarInt(g_nms_extract) || entity == -1) return;
	decl Float:ClientOrigin[3];
	Entity_GetAbsOrigin(entity, ClientOrigin);
	
	for(new i = 1; i <= GetMaxClients(); i++){
		if(IsClientInGame(i) && IsPlayerAlive(i)){
			//SetEntityMoveType(i, MOVETYPE_NONE);
			if(zho) PrintToChat(i,"开始传送到逃脱点")
			else 	PrintToChat(i,"transfer starting..")
			//SetEntityHealth(i, 255)
			TeleportEntity(i, ClientOrigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action:AmbientSHook(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay){
	//PrintToChatAll(sample)
	if(StrContains(sample,"ambient",false) != -1){ 
		return Plugin_Stop
	}
	return Plugin_Continue
}

public Action:Command_Test(id, Args){
	if(!IsMapNMS()){
		if(zho) PrintToChat(id,"这个地图不是生存模式")
		else	PrintToChat(id,"Not nms map.")
		return
	}
	
	PrintToConsole(id,"=======================================================================")
	new EntOWC = Entity_FindByClassName(-1, "overlord_wave_controller")
	if(zho){
		PrintToConsole(id,"生存地图信息")
		
		PrintToConsole(id,"直升机出现频率 : %d",GetEntProp(EntOWC, Prop_Data, "m_iNGFreq")) 
			//National Guard drop occurs once every this many waves.
		PrintToConsole(id,"补给投放频率 : %d",GetEntProp(EntOWC, Prop_Data, "m_iResupplyFreq")) 		
			//resupply_freq//
		PrintToConsole(id,"初始僵尸数量 : %d",GetEntProp(EntOWC, Prop_Data, "m_iInitialSpawn")) 		
			//initial_spawn//
		PrintToConsole(id,"每波僵尸增加数 : %d",GetEntProp(EntOWC, Prop_Data, "m_iZombieIncrement")) 	
			//zombie_increment//
		PrintToConsole(id,"跑尸第几波出现 : %d",GetEntProp(EntOWC, Prop_Data, "m_iFirstRunnerWave")) 	
			//first_runner_wave//
		PrintToConsole(id,"小孩第几波出现 : %d",GetEntProp(EntOWC, Prop_Data, "m_iFirstChildWave")) 	
			//first_child_wave//
		PrintToConsole(id,"在第三方图启用 : %d",GetEntProp(EntOWC, Prop_Data, "_useCustomWinScenario")) 
			//use_custom_win
		PrintToConsole(id,"僵尸波数上限 : %d",GetEntProp(EntOWC, Prop_Data, "m_iEndWave")) 			
			//ending_wave//
		PrintToConsole(id,"跑尸出现几率 : %f",GetEntPropFloat(EntOWC, Prop_Data, "_max_runner_chance")) 
			//_max_runner_chance//
		PrintToChat(id,"地图信息已显示在控制台")
	}
	else {
		PrintToConsole(id,"NMS Map Parameters")
		
		PrintToConsole(id,"National Guard drop frequence:%d",GetEntProp(EntOWC, Prop_Data, "m_iNGFreq")) 
			//?  National Guard drop occurs once every this many waves.
		PrintToConsole(id,"resupply frequence:%d"	,GetEntProp(EntOWC, Prop_Data, "m_iResupplyFreq")) 
			//resupply_freq//
		PrintToConsole(id,"Zombie initial spawn:%d"	,GetEntProp(EntOWC, Prop_Data, "m_iInitialSpawn")) 
			//initial_spawn//
		PrintToConsole(id,"Zombie increment:%d"		,GetEntProp(EntOWC, Prop_Data, "m_iZombieIncrement")) 
			//zombie_increment//
		PrintToConsole(id,"first runner wave:%d"	,GetEntProp(EntOWC, Prop_Data, "m_iFirstRunnerWave")) 
			//first_runner_wave//
		PrintToConsole(id,"first child wave:%d"		,GetEntProp(EntOWC, Prop_Data, "m_iFirstChildWave")) 
			//first_child_wave//
		PrintToConsole(id,"use custom win:%d"		,GetEntProp(EntOWC, Prop_Data, "_useCustomWinScenario")) 
			//use_custom_win
		PrintToConsole(id,"ending wave:%d"			,GetEntProp(EntOWC, Prop_Data, "m_iEndWave")) 
			//ending_wave//
		PrintToConsole(id,"max runner chance:%f"	,GetEntPropFloat(EntOWC, Prop_Data, "_max_runner_chance")) 
			//_max_runner_chance//
		PrintToChat(id,"NMS Parameters on console Printed.")
	}
	PrintToConsole(id,"=======================================================================")
}
//new Old_Chooper = -1
public OnEntityCreated(entityin, const String:classname[]){
	if(StrEqual(classname,"item_inventory_box",false)){
		//CreateTimer(2.0, Timer_item_inventory_box,entityin);
		//PrintToChatAll(classname)
	}
	if(StrEqual(classname,"npc_supply_chopper",false)){
		//PrintToChatAll(classname)
		//if(Old_Chooper != entityin) Entity_Kill(Old_Chooper)
		//Old_Chooper = entityin
		//CreateTimer(2.0, Timer_npc_supply_chopper,entityin);
		/*
		new entity = -1
		new counter = 0
		new entid = -1
		while((entity = Entity_FindByClassName(entity, "npc_supply_chopper")) != INVALID_ENT_REFERENCE){
			counter++
			entid = entity
		}
		
		if(counter >= 2){
			new entity2 = -1
			while((entity2 = Entity_FindByClassName(entity2, "npc_supply_chopper")) != INVALID_ENT_REFERENCE){
				if(entity2 != entid) Entity_Kill(entity2)
			}
		}
		*/
	}
	/*
	if(!Nmrih_Zombie_IsValid(entity)){
		new String:ModelName[128]
		Entity_GetModel(entity, ModelName, sizeof(ModelName));
		PrintToServer("%s - %s",classname,ModelName)
	}
	*/
}

public Action:Timer_item_inventory_box(Handle:timer, any:entityin) {
	//new String:buffer[64]
	//Entity_GetModel(entityin, buffer, sizeof(buffer));
	//PrintToChatAll(buffer)
	//models/props/army/heli_supplycrate.mdl
	/*
	new entity = -1
	while((entity = Entity_FindByClassName(entity, "npc_supply_chopper")) != INVALID_ENT_REFERENCE){
		Entity_Kill(entity)
	}
	*/
	/*
	decl Float:ClientOrigin[3];
	//new entity = Entity_FindByClassName(-1, "nmrih_safezone_supply") //Uses uses <integer> Number of uses before this supply disappears
	new entity = Entity_FindByClassName(-1, "wave_resupply_point")
	Entity_GetAbsOrigin(entity, ClientOrigin);
	TeleportEntity(entityin, ClientOrigin, NULL_VECTOR, NULL_VECTOR);
	*/
}

public Action:Timer_npc_supply_chopper(Handle:timer, any:entityin) {
	if(!IsClassName(entityin,"npc_supply_chopper")) return;
	decl Float:ClientOrigin[3];
	GetEntPropVector(entityin, Prop_Data, "m_vecDropLocation", ClientOrigin);
	//GetEntPropVector(entityin, Prop_Data, "m_vecDesiredPosition", ClientOrigin);
	TeleportEntity(entityin, ClientOrigin, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(Entity_FindByClassName(-1, "chopper_entryexit_point"), ClientOrigin, NULL_VECTOR, NULL_VECTOR);
	
	//AcceptEntityInput(entityin, "InputDisableRotorSound") //關閉螺懸槳聲音
	//AcceptEntityInput(entityin, "InputGunOn")				//開啟槍火
	//AcceptEntityInput(entityin, "InputMissileOn")			//開啟火箭
	//AcceptEntityInput(entityin, "InputDisableRotorWash")	//關閉風翼排開效果
	SetEntProp(entityin, Prop_Send, "m_nSolidType", 0 );
	SetEntProp(entityin, Prop_Data, "m_CollisionGroup", 0); //http://forums.alliedmods.net/showpost.php?p=715655&postcount=6
	SetEntProp(entityin, Prop_Send, "m_CollisionGroup", 0);
	//AcceptEntityInput( entityin, "EnableCollision" );
	AcceptEntityInput( entityin, "DisableCollision" );
}

public OnMapStart(){
	//LogToFile("state.log","mapstart")
	wave = 0
	Endwave = 0
	ExtractTime = 0.0
	Ent_nmrih_extract_point = -1
	
	if(IsMapNMS()) PluginEnable = 1
	else return
	
	Ent_nmrih_extract_point = Entity_FindByClassName(-1, "nmrih_extract_point")
	
	if(Ent_nmrih_extract_point == -1){
		PluginEnable = 0
		return
	}
	
	ExtractTime = GetEntPropFloat(Ent_nmrih_extract_point, Prop_Data, "m_flExtractionTime")
	
	HookEntityOutput("nmrih_extract_point", "OnAllPlayersExtracted", OnAllPlayersExtracted);
	HookEntityOutput("nmrih_extract_point", "OnExtractionExpired", OnExtractionExpired);
	
	/*
	new entity = -1
	while((entity = Entity_FindByClassName(entity, "nmrih_extract_point")) != INVALID_ENT_REFERENCE){
		HookSingleEntityOutput(entity, "OnAllPlayersExtracted", OnAllPlayersExtracted, false);
		HookSingleEntityOutput(entity, "OnExtractionExpired", OnExtractionExpired, false);
	}
	*/
}

public state_change(Handle:event, const String:name[], bool:dontBroadcast){
	//PrintToChatAll("%s:state%d , game_type%d",name,GetEventInt(event, "state"),GetEventInt(event, "game_type"))
	//game_type 0 = NMO ; 1 = NMS
	//state 2 Practice End Freeze
	//state 3 Round Start
	//state 4 Wave All Complete
	//state 5 All Extracted
	//state 6 freeze end?
	//state 7 Direct Map End
	//state 8 Round End?
	
	if(IsMapNMS()) PluginEnable = 1
	else return
	
	new game_type = GetEventInt(event, "game_type")
	new states = GetEventInt(event, "state")
	
	if(states == 3) OnStates3()
	
	if(states == 1 || states == 0){
		//LogToFile("state.log","States:%d",states)
	}
	if(!game_type) PluginEnable = 0
}

public OnStates3(){
	if(GetConVarInt(g_nms_keypad)){
		new entity = -1
		while((entity = Entity_FindByClassName(entity, "trigger_keypad")) != INVALID_ENT_REFERENCE){
			new String:Code[16]
			GetEntPropString(entity, Prop_Data, "m_pszCode", Code, sizeof(Code));
			new Handle:event = CreateEvent("keycode_enter");
			SetEventInt(event, "player",0)
			SetEventInt(event, "keypad_idx",entity)
			SetEventString(event, "code", Code);
			FireEvent(event, true);
		}
	}
	
	if(GetConVarInt(g_nms_health)){
		new nmrih_health_station_location = -1
		new nmrih_health_station = -1
		while((nmrih_health_station_location = Entity_FindByClassName(nmrih_health_station_location, "nmrih_health_station_location")) != INVALID_ENT_REFERENCE){
			nmrih_health_station = Entity_FindByClassName(nmrih_health_station, "nmrih_health_station")
			if(GetEntPropFloat(nmrih_health_station_location, Prop_Send, "_health") != 0.0) return
			decl Float:ClientOrigin[3]
			Entity_GetAbsOrigin(nmrih_health_station_location, ClientOrigin);
			if(nmrih_health_station != -1) TeleportEntity(nmrih_health_station, ClientOrigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	new Ent_overlord_wave_controller = Entity_FindByClassName(-1, "overlord_wave_controller")
	Endwave = GetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iEndWave")
	
	if(GetConVarInt(g_nms_Enable)){
		SetWaveParm(GetConVarInt(g_nms_endwave),WaveEnd)
		SetWaveParm(GetConVarInt(g_nms_increase),WaveIncrease)
		SetWaveParm(GetConVarInt(g_nms_resupply),WaveResupply)
		SetWaveParm(GetConVarInt(g_nms_initial),WaveInitial)
		SetWaveParm(GetConVarInt(g_nms_runner),WaveRunner)
		SetWaveParm(GetConVarInt(g_nms_child),WaveChild)
		SetWaveParm(GetConVarInt(g_nms_custom),WaveCustom)
		SetWaveParm(1,WaveRunnerChance)
	}
}

public Event_new_wave(Handle:event, const String:name[], bool:dontBroadcast){
	if(!PluginEnable) return
	new resupply = GetEventInt(event, "resupply")
	if(!resupply){
		wave++
		//PrintToChatAll("%s:%d/%d",name,wave,Endwave)
		if(wave == Endwave) CreateTimer(2.0, Timer_OnWaveComplete, _ , TIMER_REPEAT);
	}
}

public Action:Timer_OnWaveComplete(Handle:timer, any:data) {
	if(!PluginEnable){
		KillTimer(timer)
		return
	}
	
	if(!Nmrih_Zombie_GetCount()){
		OnWaveComplete()
		KillTimer(timer)
	}
}

public OnWaveComplete(){
	if(!PluginEnable) return
	AcceptEntityInput(Entity_FindByClassName(-1, "nmrih_extract_point"), "Start")
	CreateTimer(ExtractTime + 1.0, Timer_OnWaveEnd);
}

public Action:Timer_OnWaveEnd(Handle:timer, any:data) {
	if(!PluginEnable) return
	AcceptEntityInput(Entity_FindByClassName(-1, "overlord_wave_controller"), "InputCustomWinFailed");
}

public OnAllPlayersExtracted(const String:output[], caller, activator, Float:delay){
	//PrintToChatAll(output)
	PluginEnable = 0
}

public OnExtractionExpired(const String:output[], caller, activator, Float:delay){
	//PrintToChatAll(output)
	PluginEnable = 0
}

stock SetWaveParm(num = 0,const type = 0){
	new Ent_overlord_wave_controller = Entity_FindByClassName(-1, "overlord_wave_controller")
	if(!type || !num || Ent_overlord_wave_controller == -1) return
	
	if(type == WaveEnd){
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iEndWave",num, 4);
		Endwave = GetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iEndWave")
	}
	if(type == WaveIncrease)
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iZombieIncrement",num, 4);
	if(type == WaveResupply){
		if(num == 1){
			SetConVarInt(g_nms_resupply, 2);
			num = 2
		}
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iResupplyFreq",num, 4);
	}
	if(type == WaveInitial)
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iInitialSpawn",num, 4);
	if(type == WaveRunner)
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iFirstRunnerWave",num, 4);
	if(type == WaveChild)
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iFirstChildWave",num, 4);
	if(type == WaveCustom)
		SetEntProp(Ent_overlord_wave_controller, Prop_Data, "m_iFirstChildWave",num, 4);
	if(type == WaveRunnerChance /*&& GetConVarFloat(g_nms_runner_chance) != 0.0*/)
		SetEntPropFloat(Ent_overlord_wave_controller, Prop_Data, "_max_runner_chance",GetConVarFloat(g_nms_runner_chance), 4);
}

stock IsClassName(const ent,const String:classname[]){
	new String:EntClass[128]
	GetEntityClassname(ent, EntClass, sizeof(EntClass))
	if(StrEqual(classname,EntClass,false)) return true
	return false
}

stock IsMapNMS(){
	GetCurrentMap(MapName, sizeof(MapName));
	if(strncmp(MapName, "nms", strlen("nms"), false) == 0)
			return true
	else 	return false
}

/*
public Action:Event_player_extracted(Handle:hEvent, const String:name[], bool:dontBroadcast){
	//PrintToChatAll(name)
}

public Event_Extraction_Begin(Handle:hEvent, const String:name[], bool:dontBroadcast){
	PrintToChatAll(name)
}
*/