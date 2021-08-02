#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.2"

bool bLateLoad;

GlobalForward gf_IATH;

DynamicHook dh_IATH = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion ev_RetVal = GetEngineVersion();
	if (ev_RetVal != Engine_Left4Dead && ev_RetVal != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[IATH] Plugin Supports L4D And L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("IATH");
	
	gf_IATH = new GlobalForward("OnAbilityTouch", ET_Event, Param_String, Param_Cell, Param_CellByRef);
	
	bLateLoad = late;
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "Infected Ability Touch Hook",
	author = "cravenge",
	description = "Provides a forward for plugin developers to intercept actions regarding infected abilities.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=331691"
};

public void OnPluginStart()
{
	GameData gd_IATH = FetchGameData("infected_ability_touch_hook");
	if (gd_IATH == null)
	{
		SetFailState("[IATH] Game Data Not Found!");
	}
	
	dh_IATH = DynamicHook.FromConf(gd_IATH, "OnTouch");
	if (dh_IATH == null)
	{
		SetFailState("[IATH] Offset \"OnTouch\" Missing!");
	}
	
	delete gd_IATH;
	
	CreateConVar("iath_version", PLUGIN_VERSION, "Infected Ability Touch Hook Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	if (bLateLoad)
	{
		char sEntityClass[64];
		for (int i = 1; i < 2049; i++)
		{
			if (!IsValidEntity(i))
			{
				continue;
			}
			
			GetEntityClassname(i, sEntityClass, sizeof(sEntityClass));
			OnEntityCreated(i, sEntityClass);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1 || entity > 2048)
	{
		return;
	}
	
	if (strncmp(classname, "ability", 7) == 0)
	{
		dh_IATH.HookEntity(Hook_Pre, entity, dtrOnTouchPre);
	}
}

public MRESReturn dtrOnTouchPre(int pThis, DHookParam hParams)
{
	if (hParams.IsNull(1))
	{
		return MRES_Ignored;
	}
	
	int iParam = hParams.Get(1);
	
	char sThisClass[64];
	GetEntityClassname(pThis, sThisClass, sizeof(sThisClass));
	
	Action a_RetVal = Plugin_Continue;
	Call_StartForward(gf_IATH);
	Call_PushString(sThisClass);
	Call_PushCell(GetEntPropEnt(pThis, Prop_Send, "m_owner"));
	Call_PushCellRef(iParam);
	Call_Finish(a_RetVal);
	
	switch (a_RetVal)
	{
		case Plugin_Handled: return MRES_Supercede;
		case Plugin_Changed:
		{
			hParams.Set(1, iParam);
			return MRES_ChangedHandled;
		}
	}
	
	return MRES_Ignored;
}

GameData FetchGameData(const char[] file)
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", file);
	if (!FileExists(sFilePath))
	{
		File fileTemp = OpenFile(sFilePath, "w");
		if (fileTemp == null)
		{
			SetFailState("[IATH] Game Data Creation Aborted!");
		}
		
		fileTemp.WriteLine("\"Games\"");
		fileTemp.WriteLine("{");
		fileTemp.WriteLine("	\"#default\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Functions\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"OnTouch\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"offset\"		\"OnTouch\"");
		fileTemp.WriteLine("				\"hooktype\"		\"entity\"");
		fileTemp.WriteLine("				\"return\"		\"void\"");
		fileTemp.WriteLine("				\"this\"			\"entity\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"	\"cbaseentity\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("	\"left4dead\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Offsets\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"OnTouch\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"200\"");
		fileTemp.WriteLine("				\"linux\"		\"201\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("	\"left4dead2\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Offsets\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"OnTouch\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"215\"");
		fileTemp.WriteLine("				\"linux\"		\"216\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("}");
		
		fileTemp.Close();
	}
	
	return new GameData(file);
}

