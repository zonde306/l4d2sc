#include <sourcemod>

#define VERSION "0.2"

//Plugin Info
public Plugin:myinfo = 
{
	name = "Sourcemod Config AutoLoader",
	author = "crasx",
	description = "Executes configs based on plugins loaded",
	version = VERSION,
	url = "No URL available"
}


public OnPluginStart()
{
	CreateConVar("sm_configauto_loader_version", VERSION, "Version of Sourcemod Config Loader plugin", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_configauto_exec", CmdReExecute, ADMFLAG_RCON, "Execute all sourcemod configs");
}

public Action:CmdReExecute(client, args)
{
	ExecuteAllConfigs();
	return Plugin_Handled;
}

public OnMapStart()
{
	ExecuteAllConfigs();
}

stock ExecuteAllConfigs()
{
	new Handle:plugins=GetPluginIterator();
	decl String:pname[255];
	decl String:fullpath[255];

	//iterate plugins
	new Float:time=1.0;

	while(MorePlugins(plugins)){
		new Handle:plugin=ReadPlugin(plugins);		
		GetPluginFilename(plugin, pname, 255);
		
		new String:text[8][64];
		ReplaceString(pname, 255, "\\", "/");
		new count = ExplodeString(pname, "/", text, 8, 64);
		if(count > 0)
			strcopy(pname, 255, text[count-1]);

		//change name to .cfg
		new sl=strlen(pname);
		if(sl>4){
			pname[sl-4]='\0'; //issues a warning, but I tried multiple formats (0x0, 0) and ended up using format from https://wiki.alliedmods.net/Introduction_to_SourcePawn#Caveats
			Format(fullpath, 255, "cfg/sourcemod/%s.cfg", pname);
			//check if cfg exists
			if(FileExists(fullpath)){
				//run it
				new Handle:pack = CreateDataPack();
				WritePackString(pack, pname);
				LogMessage("Create timer for  %s", pname);
				CreateTimer(time, ExecuteConfig, pack, TIMER_FLAG_NO_MAPCHANGE);
				time += 0.1;
			}else{
				LogError("No config file for %s", fullpath);
			}
		}
	}
}

public Action:ExecuteConfig(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	decl String:config[256];
	ReadPackString(pack, config, sizeof(config));
	ServerCommand("exec \"sourcemod/%s\"", config);
	LogMessage("Executed %s", config);
}