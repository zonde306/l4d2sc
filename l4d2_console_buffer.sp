#define PLUGIN_VERSION 		"1.10"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Linux Console - Buffer Overflow Fix
*	Author	:	SilverShot
*	Descrp	:	Fixes the 'Cbuf_AddText: buffer overflow' console error on Linux servers.
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0 (27-Jun-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "[L4D2] Linux Console - Buffer Overflow Fix",
	author = "SilverShot",
	description = "Fixes the 'Cbuf_AddText: buffer overflow' console error on Linux servers.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=308483"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_linux_console_fix_version", PLUGIN_VERSION, "Linux Console Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// ====================================================================================================
	// Write GameData
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/l4d2_console_buffer.txt");
	if( !FileExists(sPath) )
	{
		File hFile = OpenFile(sPath, "w+");

		if( hFile == null )
			SetFailState("Error: Couldn't create gamedata file.");

		hFile.WriteLine("\"Games\"");
		hFile.WriteLine("{");
		hFile.WriteLine("	\"left4dead2\"");
		hFile.WriteLine("	{");
		hFile.WriteLine("		\"Addresses\"");
		hFile.WriteLine("		{");
		hFile.WriteLine("			\"Cbuf_AddText_Fix\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"signature\"	\"Cbuf_AddText_Sig\"");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		hFile.WriteLine("		}");
		hFile.WriteLine("		\"Offsets\"");
		hFile.WriteLine("		{");
		hFile.WriteLine("			\"Cbuf_AddText_Offset\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"		\"167\"");
		hFile.WriteLine("			}");
		hFile.WriteLine("		}");
		hFile.WriteLine("		\"Signatures\"");
		hFile.WriteLine("		{");
		hFile.WriteLine("			/*");
		hFile.WriteLine("			*  int __cdecl sub_34B2C0(int, void *src, int)");
		hFile.WriteLine("			*/");
		hFile.WriteLine("			\"Cbuf_AddText_Sig\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"		\"engine\"");
		hFile.WriteLine("				\"linux\"		\"\\x55\\x89\\x2A\\x83\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x89\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x39\\x2A\\x74\\x2A\\x31\\x2A\\xF0\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x75\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x01\\xA3\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x2A\\x89\\x2A\\x2A\\x2A\\x8B\\x2A\\x2A\\x89\\x2A\\x2A\\x2A\\x69\"");
		hFile.WriteLine("				/* 55 89 ? 83 ? ? E8 ? ? ? ? 89 ? A1 ? ? ? ? 39 ? 74 ? 31 ? F0 ? ? ? ? ? ? ? 75 ? A1 ? ? ? ? 83 ? 01 A3 ? ? ? ? 8B ? ? 89 ? ? ? 8B ? ? 89 ? ? ? 69 */");
		hFile.WriteLine("				/* Search: \"Cbuf_AddText: buffer overflow\\n\" */");
		hFile.WriteLine("			}");
		hFile.WriteLine("		}");
		hFile.WriteLine("	}");
		hFile.WriteLine("}");

		delete hFile;
	}



	// ====================================================================================================
	// GameData
	// ====================================================================================================
	Handle hGameConf = LoadGameConfigFile("l4d2_console_buffer");
	if( hGameConf == null ) SetFailState("Failed to load gamedata/l4d2_console_buffer.");
	int offset = GameConfGetOffset(hGameConf, "Cbuf_AddText_Offset");
	if( offset == -1 ) SetFailState("Plugin is for Linux only.");
	Address patch = GameConfGetAddress(hGameConf, "Cbuf_AddText_Fix");
	delete hGameConf;
	if( !patch ) SetFailState("Error finding the 'Cbuf_AddText_Fix' signature.");

	int byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + view_as<Address>(offset + i), 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the 'Cbuf_AddText_Offset' is incorrect.");
	}
}