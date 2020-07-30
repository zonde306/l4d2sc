#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "自动隐藏服务器",
	author = "zonde306",
	description = "",
	version = "0.1",
	url = ""
};

Handle g_Timer_AutoRestart = null;
ConVar g_CV_ConfigPath, g_CV_AutoRestart, g_CV_RestartWait, g_CV_AdminEnable, g_CV_AdminTimeout, g_CV_RestartMode, g_CV_AdminRestart, g_CV_Accelerator, g_CV_AutoHidden;

public void OnPluginStart()
{
	g_CV_ConfigPath = CreateConVar("l4d2_auto_hidden_config", "/cfg/hidden.cfg", "文件输出路径");
	g_CV_RestartMode = CreateConVar("l4d2_auto_hidden_mode", "0", "重启模式.0=_restart.1=crash", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_AutoRestart = CreateConVar("l4d2_auto_hidden_restart", "1", "空服自动重启服务器", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_RestartWait = CreateConVar("l4d2_auto_hidden_wait", "10", "最后一个玩家离开后等待多少秒重启", FCVAR_NONE, true, 0.0, true, 3600.0);
	g_CV_AdminEnable = CreateConVar("l4d2_auto_hidden_enable", "1", "管理员加入可以解除隐藏", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_AdminRestart = CreateConVar("l4d2_auto_hidden_timeout_restart", "1", "临时解除隐藏超时重启", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_AutoHidden = CreateConVar("l4d2_auto_hidden_non_empty", "1", "服务器有人时自动隐藏", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CV_AdminTimeout = CreateConVar("l4d2_auto_hidden_timeout", "600", "解除隐藏超时时间(秒)", FCVAR_NONE, true, 0.0, true, 3600.0);
	g_CV_Accelerator = CreateConVar("l4d2_auto_hidden_accelerator", "", "要卸载的扩展");
	
	AutoExecConfig(true, "l4d2_auto_hidden");
}

public void OnConfigsExecuted()
{
	char path[PLATFORM_MAX_PATH];
	g_CV_ConfigPath.GetString(path, sizeof(path));
	
	if(!FileExists(path))
		WriteHidden(true);
}

public void OnMapStart()
{
	if(!IsServerEmpty())
		return;
	
	if(g_CV_AdminRestart.BoolValue && !GetHidden())
	{
		g_Timer_AutoRestart = CreateTimer(g_CV_AdminTimeout.FloatValue, Timer_RestartServer, 1, TIMER_FLAG_NO_MAPCHANGE);
		LogMessage("wait players at %ds", g_CV_AdminTimeout.IntValue);
	}
}

public void OnMapEnd()
{
	g_Timer_AutoRestart = null;
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;
	
	Handle timer = g_Timer_AutoRestart;
	g_Timer_AutoRestart = null;
	
	if(g_CV_AutoHidden.BoolValue)
	{
		static ConVar sv_tags;
		if(sv_tags == null)
			sv_tags = FindConVar("sv_tags");
		if(sv_tags != null)
		{
			char tags[64];
			sv_tags.GetString(tags, 64);
			if(StrContains(tags, "hidden", false) == -1)
				sv_tags.SetString("hidden");
		}
	}
	
	if(timer)
		KillTimer(timer);
}

public void OnClientDisconnect(int client)
{
	if(!IsServerEmpty(client))
		return;
	
	int mode = 0;
	AdminId admin = GetUserAdmin(client);
	if(	g_CV_AdminEnable.BoolValue &&
		admin != INVALID_ADMIN_ID && (
		admin.HasFlag(Admin_Reservation, Access_Real) ||
		admin.HasFlag(Admin_Reservation, Access_Effective))
	)
	{
		mode = -1;
	}
	else
	{
		mode = 1;
	}
	
	if(g_CV_AutoRestart.BoolValue)
	{
		g_Timer_AutoRestart = CreateTimer(g_CV_RestartWait.FloatValue, Timer_RestartServer, mode, TIMER_FLAG_NO_MAPCHANGE);
		LogMessage("restart at %ds", g_CV_RestartWait.IntValue);
	}
}

public Action Timer_RestartServer(Handle timer, any hidden)
{
	if(hidden != 0)
	{
		if(hidden > 0)
			WriteHidden(true);
		else
			WriteHidden(false);
	}
	
	char unload[32];
	g_CV_Accelerator.GetString(unload, 32);
	if(unload[0] != EOS)
	{
		LogMessage("sm exts unload %s", unload);
		ServerCommand("sm exts unload %s", unload);
	}
	
	if(g_CV_RestartMode.BoolValue)
	{
		SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
		LogMessage("restart with crash");
		ServerCommand("crash");
	}
	else
	{
		LogMessage("restart with _restart");
		ServerCommand("_restart");
	}
}

stock bool IsServerEmpty(int ignore = -1)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == ignore || !IsClientConnected(i) || IsFakeClient(i))
			continue;
		
		return false;
	}
	
	return true;
}

stock bool GetHidden()
{
	char path[PLATFORM_MAX_PATH];
	g_CV_ConfigPath.GetString(path, sizeof(path));
	if(!FileExists(path))
		return false;
	
	File f = OpenFile(path, "rt");
	f.Seek(0, SEEK_SET);
	
	char line[255];
	f.ReadLine(line, sizeof(line));
	f.Close();
	
	return StrContains(line, "hidden", false) > -1;
}

stock void WriteHidden(bool hidden)
{
	char path[PLATFORM_MAX_PATH];
	g_CV_ConfigPath.GetString(path, sizeof(path));
	File f = OpenFile(path, "wt");
	f.Seek(0, SEEK_SET);
	
	if(hidden)
		f.WriteLine("sv_tags \"hidden\"");
	else
		f.WriteLine("sv_tags \"\"");
	
	f.Close();
}
