/*  
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define GAMEDATA "witch_target_patch"
#define PLUGIN_VERSION	"1.1"

bool bDidPatch;

Address GetVictim = Address_Null;
Address OnStart = Address_Null;
Address OnAnimationEvent = Address_Null;
Address Update = Address_Null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "修复 Witch 追错人",
	author = "Lux",
	description = "Fixes witch targeting wrong person",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647014"
};

public void OnPluginStart()
{
	CreateConVar("witch_target_patch_version", PLUGIN_VERSION, "", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
		
	Address patch;
	int offset;
	int byte;
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::GetVictim");
	if(patch) 
	{
		offset = GameConfGetOffset(hGamedata, "WitchAttack::GetVictim");
		if(offset != -1) 
		{
			byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
			if(byte == 0x74)
			{
				GetVictim = patch + view_as<Address>(offset);
				StoreToAddress(GetVictim, 0x7E, NumberType_Int8);
				PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
				bDidPatch = true;
				return;
			}
			else if(byte == 0x75)
			{
				GetVictim = patch + view_as<Address>(offset);
				StoreToAddress(GetVictim, 0x7F, NumberType_Int8);
				PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
				bDidPatch = true;
			}
			else
			{
				LogError("Incorrect offset for 'WitchAttack::GetVictim'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'WitchAttack::GetVictim'.");
		}
	}
	else
	{
		LogError("Error finding the 'WitchAttack::GetVictim' signature.");
	}
	
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnStart");
	if(patch) 
	{
		offset = GameConfGetOffset(hGamedata, "WitchAttack::OnStart");
		if(offset != -1) 
		{
			byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
			if(byte == 0x75)
			{
				OnStart = patch + view_as<Address>(offset);
				StoreToAddress(OnStart, 0x7F, NumberType_Int8);
				PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnStart'");
				bDidPatch = true;
			}
			else
			{
				LogError("Incorrect offset for 'WitchAttack::OnStart'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'WitchAttack::OnStart'.");
		}
	}
	else
	{
		LogError("Error finding the 'WitchAttack::OnStart' signature.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnAnimationEvent");
	if(patch)
	{
		offset = GameConfGetOffset(hGamedata, "WitchAttack::OnAnimationEvent");
		if(offset != -1) 
		{
			byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
			if(byte == 0x75)
			{
				OnAnimationEvent = patch + view_as<Address>(offset);
				StoreToAddress(OnAnimationEvent, 0x7F, NumberType_Int8);
				PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnAnimationEvent'");
				bDidPatch = true;
			}
			else
			{
				LogError("Incorrect offset for 'WitchAttack::OnAnimationEvent'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'WitchAttack::OnAnimationEvent'.");
		}
	}
	else
	{
		LogError("Error finding the 'WitchAttack::OnAnimationEvent' signature.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::Update");
	if(patch) 
	{
		offset = GameConfGetOffset(hGamedata, "WitchAttack::Update");
		if(offset != -1) 
		{
			byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
			if(byte == 0x75)
			{
				Update = patch + view_as<Address>(offset);
				StoreToAddress(Update, 0x7F, NumberType_Int8);
				PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::Update'");
				bDidPatch = true;
			}
			else
			{
				LogError("Incorrect offset for 'WitchAttack::Update'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'WitchAttack::Update'.");
		}
	}
	else
	{
		LogError("Error finding the 'WitchAttack::Update' signature.");
	}
	delete hGamedata;
}

public void OnPluginEnd()
{
	if(!bDidPatch)
		return;
	
	int byte;
	
	if(GetVictim != Address_Null)
	{
		byte = LoadFromAddress(view_as<Address>(GetVictim), NumberType_Int8);
		if(byte == 0x7E)
		{
			StoreToAddress(view_as<Address>(GetVictim), 0x74, NumberType_Int8);
			PrintToServer("WitchPatch restored 'WitchAttack::GetVictim'");
			return;
		}
		else if(byte == 0x7F)
		{
			StoreToAddress(view_as<Address>(GetVictim), 0x75, NumberType_Int8);
			PrintToServer("WitchPatch restored 'WitchAttack::GetVictim'");
		}
	}
	
	if(OnStart != Address_Null)
	{
		byte = LoadFromAddress(OnStart, NumberType_Int8);
		if(byte == 0x7F)
		{
			StoreToAddress(OnStart, 0x75, NumberType_Int8);
			PrintToServer("WitchPatch restored 'WitchAttack::OnStart'");
		}
	}
	
	if(OnAnimationEvent != Address_Null)
	{
		byte = LoadFromAddress(OnAnimationEvent, NumberType_Int8);
		if(byte == 0x7F)
		{
			StoreToAddress(OnAnimationEvent, 0x75, NumberType_Int8);
			PrintToServer("WitchPatch restored 'WitchAttack::OnAnimationEvent'");
		}
	}
	
	if(Update != Address_Null)
	{
		byte = LoadFromAddress(Update, NumberType_Int8);
		if(byte == 0x7F)
		{
			StoreToAddress(Update, 0x75, NumberType_Int8);
			PrintToServer("WitchPatch restored 'WitchAttack::Update'");
		}
	}
}
