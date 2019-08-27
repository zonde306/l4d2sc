#define PLUGIN_VERSION		"1.0.3"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Helms Deep Patch (VPK Maker)
*	Author	:	SilverShot
*	Descrp	:	Restores files overwritten by Helms Deep map. Creates a VPK addon to store the files.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318094
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0.3 (18-Aug-2019)
	- Increased MAX_FILE_SIZE to 32 KB for packaging.

1.0.2 (16-Aug-2019)
	- Added "cfg/banned_user.cfg" to list of fixes.
	- Converted source to use MethodMaps.

1.0.1 (14-Aug-2019)
	- Added "host.txt" and "motd.txt" to list of fixes. Thanks to "Xanaguy" for reporting.

1.0 (14-Aug-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>



#define VPK_FILE_NAME_1			"addons/sm_helms_patch1.vpk"
#define VPK_FILE_NAME_2			"addons/sm_helms_patch2.vpk"
#define MAX_FILE_SIZE			32768		// Maximum size of any file to package 32 KB (1024 * 32)
#pragma dynamic MAX_FILE_SIZE

ArrayList g_aFiles;

// OVERWRITTEN FILES by HELMS DEEP
static const char g_sFiles[][] =
{
	"addons/sourcemod/configs/admin_groups.cfg",
	"addons/sourcemod/configs/admin_levels.cfg",
	"addons/sourcemod/configs/admin_overrides.cfg",
	"addons/sourcemod/configs/adminmenu_cfgs.txt",
	"addons/sourcemod/configs/adminmenu_custom.txt",
	"addons/sourcemod/configs/adminmenu_grouping.txt",
	"addons/sourcemod/configs/adminmenu_sorting.txt",
	"addons/sourcemod/configs/admins.cfg",
	"addons/sourcemod/configs/admins_simple.ini",
	"addons/sourcemod/configs/banreasons.txt",
	"addons/sourcemod/configs/core.cfg",
	"addons/sourcemod/configs/databases.cfg",
	"addons/sourcemod/configs/languages.cfg",
	"addons/sourcemod/configs/maplists.cfg",
	"cfg/sourcemod/sm_warmode_off.cfg",
	"cfg/sourcemod/sm_warmode_on.cfg",
	"cfg/sourcemod/sourcemod.cfg",
	"cfg/banned_user.cfg",
	"cfg/listenserver.cfg",
	"missions/holdoutchallenge.txt",
	"missions/holdouttraining.txt",
	"missions/parishdash.txt",
	"missions/shootzones.txt",
	"host.txt",
	"motd.txt"
};



// ====================================================================================================
//					PLUGIN INFO
// ====================================================================================================
public Plugin myinfo =
{
	name = "圣盔谷反屏蔽 SourceMod",
	author = "SilverShot",
	description = "Restores files overwritten by Helms Deep map. Creates a VPK addon to store the files.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318094"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2  )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}



// ====================================================================================================
//					PLUGIN START
// ====================================================================================================
public void OnPluginStart()
{
	// Refresh addons
	// We cannot unload addons, re-write AddonList.txt and reload addons.
	// AddonList.txt doesn't flush to disk before attempting to load addons, causing an error and not loading any.
	WriteAddonList();
	CmdReload(0,0);
	// So we have to write AddonList.txt some frames after, then unload addons, compile VPK and reload addons.
	// CreateTimer(0.1, OnTimer);
	// RequestFrame(OnFrame);
	// This also doesn't work, the double restart will take care of it. Left here if anyone wants to test.



	// Commands etc
	RegAdminCmd("sm_vpk",	CmdReload,	ADMFLAG_ROOT,	"Unloads all VPK addons, creates the Helms Deep Patch VPK and reloads VPK addons.");
	RegAdminCmd("sm_vpkb",	CmdReasons,	ADMFLAG_ROOT,	"Prints the valve file system and local file system versions of sourcemod/configs/banreasons.txt.");
	RegAdminCmd("sm_vpks",	CmdOrder,	ADMFLAG_ROOT,	"Shows the VPK addon load order. Shorter wrapper command to show_addon_load_order.");

	CreateConVar("sm_helms_patch_version",	PLUGIN_VERSION, "Helms Deep Patch plugin version.");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdOrder(int client, int args)
{
	ServerCommand("show_addon_load_order");
	return Plugin_Handled;
}

public Action CmdReasons(int client, int args)
{
	char sBuffer[MAX_FILE_SIZE];
	File hTemp = OpenFile("addons/sourcemod/configs/banreasons.txt", "rb", true);
	if( hTemp != null )
	{
		hTemp.ReadString(sBuffer, sizeof sBuffer);
		PrintToServer("Valve [%s]", sBuffer);
		delete hTemp;
	}

	PrintToServer("");

	hTemp = OpenFile("addons/sourcemod/configs/banreasons.txt", "rb", false);
	if( hTemp != null )
	{
		hTemp.ReadString(sBuffer, sizeof sBuffer);
		PrintToServer("SourceMod [%s]", sBuffer);
		delete hTemp;
	}
	return Plugin_Handled;
}

public Action CmdReload(int client, int args)
{
	ServerCommand("unload_all_addons");
	ServerExecute();

	CheckFilesForVPK();

	ServerCommand("update_addon_paths; mission_reload"); // Reload addons and Mission files, since Helms Deep corrupted 4 of Valves files.
	ServerExecute();

	return Plugin_Handled;
}



// ====================================================================================================
//					PREP FILES FOR VPK
// ====================================================================================================
// public Action OnTimer(Handle timer)
// public void OnFrame(int na)
// {
	// CmdReload(0,0);
// }



// =========================
// Modify AddonsList.txt
// =========================
public void WriteAddonList()
{
	// Exists
	if( FileExists("addonlist.txt") == false )
	{
		SetFailState("Missing file: \"addonlist.txt\". You don't have Helms Deep installed???");
	}



	// Open to Read
	File hTemp;

	hTemp = OpenFile("addonlist.txt", "rb");

	if( hTemp == null )
	{
		SetFailState("Failed to read: \"addonlist.txt\"");
	}



	// Verify patch missing
	int iWrite;
	char sBuffer[MAX_FILE_SIZE];

	hTemp.ReadString(sBuffer, sizeof sBuffer);
	delete hTemp;

	if( StrContains(sBuffer, "sm_helms_patch1.vpk") == -1 )
		iWrite = 1;
	if( StrContains(sBuffer, "sm_helms_patch2.vpk") == -1 )
		iWrite += 2;



	// Write
	if( iWrite )
	{
		// Backup
		if( FileExists("addonlist_old.txt") )
			DeleteFile("addonlist_old.txt");

		RenameFile("addonlist_old.txt", "addonlist.txt");



		// Open to Write
		File hSave = OpenFile("addonlist.txt", "wb");

		if( hSave == null )
		{
			SetFailState("Failed to write: \"addonlist.txt\"");
		}



		// Loop
		hTemp = OpenFile("addonlist_old.txt", "rb");

		while( !hTemp.EndOfFile() )
		{
			hTemp.ReadLine(sBuffer, sizeof sBuffer);

			if( iWrite & (1<<0) && sBuffer[0] == '{' )
			{
				hSave.WriteLine("{");
				hSave.WriteLine("	\"sm_helms_patch1.vpk\"		\"1\"");
			}
			else if( iWrite & (1<<1) && sBuffer[0] == '}' )
			{
				hSave.WriteLine("	\"sm_helms_patch2.vpk\"		\"1\"");
				hSave.WriteLine("}");
			}
			else
			{
				sBuffer[strlen(sBuffer) - 1] = 0x00; // Remove new line
				hSave.WriteLine(sBuffer);
			}
		}

		FlushFile(hSave); // In case it's required.

		delete hSave;
		delete hTemp;
	}
}

void CheckFilesForVPK()
{
	char sBuff[1024];
	File hTemp;



	// =========================
	// Extract the overwritten mission files.
	// =========================
	char sMission[][] =
	{
		"missions/holdoutchallenge.txt",
		"missions/holdouttraining.txt",
		"missions/parishdash.txt",
		"missions/shootzones.txt"
	};

	if( !DirExists("missions") )
	{
		CreateDirectory("missions", 511);
	}

	for( int i = 0; i < sizeof sMission; i++ )
	{
		if( FileExists(sMission[i], true) && !FileExists(sMission[i], false) )
		{
			// Read
			hTemp = OpenFile(sMission[i], "rb", true);
			if( hTemp != null )
			{
				hTemp.ReadString(sBuff, sizeof sBuff);
				delete hTemp;
			}

			// Write
			hTemp = OpenFile(sMission[i], "wb");
			if( hTemp != null )
			{
				hTemp.WriteLine(sBuff, false);
				delete hTemp;
			}
		}
	}



	// =========================
	// Setup array
	// =========================
	g_aFiles = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	// Validate files
	for( int i = 0; i < sizeof g_sFiles; i++ )
	{
		if( FileExists(g_sFiles[i]) )
		{
			g_aFiles.PushString(g_sFiles[i]);
		// } else {
			// LogError("VPK Maker: Failed to find file: \"%s\".", g_sFiles[i]);
		}
	}



	// =========================
	// Sort
	// VPKs file trees are ordered by extension type, each unique filetype only appears once, organise the list for this case.
	// =========================
	SortADTArray(g_aFiles, Sort_Ascending, Sort_String);

	// Sort by extension
	ArrayList aSortList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	char sTempBuff[PLATFORM_MAX_PATH];
	int iDir;
	int iExt;



	// Loop main list
	for( int i = 0; i < g_aFiles.Length; i++ )
	{
		g_aFiles.GetString(i, sBuff, sizeof sBuff);
		strcopy(sTempBuff, sizeof sTempBuff, sBuff);



		// Move extension to front, add to sort list
		iDir = FindCharInString(sTempBuff, '/', true);
		iExt = FindCharInString(sTempBuff, '.', true);
		if( iDir != -1 ) sTempBuff[iDir] = '\x0';
		if( iExt != -1 ) sTempBuff[iExt] = '\x0';

		if( iDir != -1 && iExt != -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s.%s/%s", sTempBuff[iExt + 1], sTempBuff, sTempBuff[iDir + 1]);
		else if( iDir == -1 && iExt != -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s.%s", sTempBuff[iExt + 1], sTempBuff);
		else if( iDir != -1 && iExt == -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s/%s", sTempBuff, sTempBuff[iDir + 1]);

		aSortList.PushString(sTempBuff);
	}



	// Order by extension, then folder names.
	SortADTArray(aSortList, Sort_Ascending, Sort_String);



	// Move extensions back, add to main list
	g_aFiles.Clear();

	for( int i = 0; i < aSortList.Length; i++ )
	{
		aSortList.GetString(i, sTempBuff, sizeof sTempBuff);

		iDir = FindCharInString(sTempBuff, '/');
		iExt = FindCharInString(sTempBuff, '.');

		if( iExt != -1 )
			sTempBuff[iExt] = '\x0';
		if( iDir != -1 )
			sTempBuff[iDir] = '\x0';

		if( iDir != -1 && iExt != -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s/%s.%s", sTempBuff[iExt + 1], sTempBuff[iDir + 1],sTempBuff);
		else if( iDir == -1 && iExt != -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s.%s", sTempBuff[iExt + 1], sTempBuff);
		else if( iDir != -1 && iExt == -1 )
			Format(sTempBuff, sizeof sTempBuff, "%s/%s", sTempBuff, sTempBuff[iDir + 1]);

		g_aFiles.PushString(sTempBuff);
	}



	// =========================
	// Pack
	// =========================
	if( FileExists(VPK_FILE_NAME_1) )
		DeleteFile(VPK_FILE_NAME_1);
	if( FileExists(VPK_FILE_NAME_2) )
		DeleteFile(VPK_FILE_NAME_2);

	PackFilesToVPK();



	// =========================
	// Duplicate VPK
	// =========================
	int iTemp[32];
	int index;

	File hVPK1 = OpenFile(VPK_FILE_NAME_1, "rb");
	File hVPK2 = OpenFile(VPK_FILE_NAME_2, "wb");

	// Copy
	while( !hVPK1.EndOfFile() )
	{
		index = hVPK1.Read(iTemp, sizeof iTemp, 1);
		hVPK2.Write(iTemp, index, 1);
	}

	delete hVPK1;
	delete hVPK2;



	// =========================
	// Clean up
	// =========================
	PrintToServer("Helms Deep Patch wrote %s & %s", VPK_FILE_NAME_1, VPK_FILE_NAME_2);

	delete aSortList;
	delete g_aFiles;
}



// ====================================================================================================
// Structure from: https://developer.valvesoftware.com/wiki/VPK_File_Format
// Written by SilverShot.
// Write files in VPK version 1 format.
// ====================================================================================================
void PackFilesToVPK()
{
	// =========================
	// Number files, length
	// =========================
	char sFilePath[PLATFORM_MAX_PATH];
	char sLastDir[PLATFORM_MAX_PATH];
	char sLastExt[PLATFORM_MAX_PATH];
	char sTempBuff[PLATFORM_MAX_PATH];
	int iTreeBytes;
	int iDir;
	int iExt;
	int iPush;



	// =========================
	// Open + Write header
	// =========================
	File hVPK = OpenFile(VPK_FILE_NAME_1, "wb");

	if( hVPK == null )
	{
		return; // Already created and loaded by the server.
	}

	WriteFileCell(hVPK, 0x55AA1234, 4);		// Signature
	WriteFileCell(hVPK, 0x01, 4);			// Version

	// Writing null for now, calculated and written later.
	WriteFileCell(hVPK, 0x00, 4);			// The size, in bytes, of the directory tree



	// =========================
	// Write tree
	// =========================
	int crc32;
	int iEntry;
	int iSize;

	for( int i = 0; i < g_aFiles.Length; i++ )
	{
		g_aFiles.GetString(i, sFilePath, sizeof sFilePath);
		strcopy(sTempBuff, sizeof sTempBuff, sFilePath);

		iDir = FindCharInString(sFilePath, '/', true);
		iExt = FindCharInString(sFilePath, '.', true);
		iPush = 0;



		// New ext
		if( iExt == -1 || strcmp(sLastExt, sFilePath[iExt + 1]) )
		{
			iPush = 1;

			if( iExt == -1 )
				strcopy(sLastExt, sizeof sLastExt, "");
			else
				strcopy(sLastExt, sizeof sLastExt, sFilePath[iExt + 1]);
		}



		// New dir
		if( iDir != -1 )
			sTempBuff[iDir] = '\x0';

		if( iDir == -1 || strcmp(sLastDir, sTempBuff) )
		{
			iPush += 2;
			strcopy(sLastDir, sizeof sLastDir, sTempBuff);
		}



		// =========================
		// Write Extension
		// =========================
		if( iPush & (1<<0) )
		{
			if( i > 0 )
			{
				WriteFileCell(hVPK, 0x00, 2);
				iTreeBytes += 2;
			}

			if( iExt == -1 )
			{
				WriteFileCell(hVPK, 0x20, 1); // Space for no ext
				iTreeBytes += 2;
			} else {
				sTempBuff[iExt] = 0x00;
				WriteFileString(hVPK, sTempBuff[iExt + 1], false);
				iTreeBytes += strlen(sTempBuff[iExt + 1]) + 1;
			}
			WriteFileCell(hVPK, 0x00, 1);
		}



		// =========================
		// Write Folders
		// =========================
		if( iPush )
		{
			if( i > 0 && iPush == 2 )
			{
				WriteFileCell(hVPK, 0x00, 1);
				iTreeBytes += 1;
			}

			if( iDir == -1 )
			{
				WriteFileCell(hVPK, 0x20, 1); // Space for root dir
				iTreeBytes += 2;
			} else {
				sTempBuff[iDir] = '\x0';
				WriteFileString(hVPK, sTempBuff, false);
				iTreeBytes += strlen(sTempBuff) + 1;
			}
			WriteFileCell(hVPK, 0x00, 1);
		}



		// =========================
		// Filenames
		// =========================
		if( iExt != -1 )
			sFilePath[iExt] = 0x00;
		WriteFileString(hVPK, sFilePath[iDir + 1], false);
		WriteFileCell(hVPK, 0x00, 1);
		iTreeBytes += strlen(sFilePath[iDir + 1]);



		// =========================
		// File data
		// =========================
		// A 32bit CRC of the file's data.
		g_aFiles.GetString(i, sFilePath, sizeof sFilePath);
		crc32 = CRC32_File(sFilePath);
		WriteFileCell(hVPK, crc32, 4);

		// PreloadBytes
		// The number of bytes contained in the index file.
		WriteFileCell(hVPK, 0x00, 2);

		// ArchiveIndex
		// A zero based index of the archive this file's data is contained in.
		// If 0x7fff, the data follows the directory.
		WriteFileCell(hVPK, 0x7FFF, 2);

		iSize = FileSize(sFilePath);

		// EntryOffset
		WriteFileCell(hVPK, iSize ? iEntry : 0, 4);
		iEntry += iSize;

		// EntryLength
		WriteFileCell(hVPK, iSize, 4);

		// Terminator
		WriteFileCell(hVPK, 0xFFFF, 2);

		// Last file terminator? FIXME: TODO: Check required
		if( iPush != 0 && i == g_aFiles.Length )
		{
			WriteFileCell(hVPK, 0x00, 2);
			iTreeBytes += 2;
		}

		// Data section bytes
		iTreeBytes += 19;
	}

	// 2 null bytes end of tree header
	WriteFileCell(hVPK, 0x00, 2);
	iTreeBytes += 2;

	// Sometimes 3?
	WriteFileCell(hVPK, 0x00, 1);
	iTreeBytes += 1;



	// =========================
	// Concatenate files
	// =========================
	char sBuffer[MAX_FILE_SIZE];
	File hFile;

	for( int i = 0; i < g_aFiles.Length; i++ )
	{
		// Read file
		g_aFiles.GetString(i, sFilePath, sizeof sFilePath);
		hFile = OpenFile(sFilePath, "rb");
		if( hFile.ReadString(sBuffer, sizeof sBuffer) > 0 )
		{
			// Write to VPK
			WriteFileString(hVPK, sBuffer, false);
		}

		// Close read
		delete hFile;
	}



	// Set tree bytes count in header
	hVPK.Seek(8, SEEK_SET);
	WriteFileCell(hVPK, iTreeBytes, 4);



	// =========================
	// Close
	// =========================
	delete hVPK;
}
// ====================================================================================================



// ====================================================================================================
// CRC-32 Source code by: "GoD-Tony"
// https://forums.alliedmods.net/showthread.php?t=206640
// ====================================================================================================
#define CRC_BUFFER_SIZE		2048

int g_CRC32_Table[] = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
	0xe963a535, 0x9e6495a3,	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
	0xf3b97148, 0x84be41de,	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
	0xfa0f3d63, 0x8d080df5,	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
	0xdbbbc9d6, 0xacbcf940,	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
	0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
	0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
	0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
	0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
	0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
	0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
	0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
	0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
	0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
	0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
	0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
	0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
	0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
	0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
	0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
	0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
	0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};

/**
 * Produces a CRC-32 checksum for a given file.
 *
 * @param path		Path to the file.
 * @return			CRC-32 checksum as an integer.
 * @error			Failed to open file or file does not exist.
 */
stock int CRC32_File(const char[] path)
{
	File hFile = OpenFile(path, "rb");
	
	if (hFile == INVALID_HANDLE)
		ThrowError("Failed to open file: %s", path);
	
	int crc = 0xFFFFFFFF;
	char data[CRC_BUFFER_SIZE], bytesread, i;
	
	while ((bytesread = hFile.ReadString(data, sizeof(data), sizeof(data))) > 0)
	{
		for (i = 0; i < bytesread; i++)
		{
			crc = g_CRC32_Table[(crc ^ data[i]) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF);
		}
	}
	
	delete hFile;
	
	return crc ^ 0xFFFFFFFF;
}