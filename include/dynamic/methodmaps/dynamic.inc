/**
 * =============================================================================
 * Dynamic for SourceMod (C)2016 Matthew J Dunn.   All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

methodmap Dynamic
{
#if defined dynamic_persistent
	public Dynamic(int blocksize=64, int startsize=0, bool persistent=true)
#else
	public Dynamic(int blocksize=64, int startsize=0, bool persistent=false)
	{
		return Dynamic_Initialise(blocksize, startsize, persistent);
	}
#endif
	
	public static bool IsLoaded()
	{
		return GetFeatureStatus(FeatureType_Native, "Native_Dynamic_Initialise") == FeatureStatus_Available;
	}
	
	property int IsValid
	{
		public get()
		{
			return Dynamic_IsValid(view_as<int>(this), false);
		}
	}
	
	property bool Persistent
	{
		public get()
		{
			return Dynamic_GetPersistence(this);
		}
		public set(bool value)
		{
			Dynamic_SetPersistence(this, value);
		}
	}
	
	property Dynamic Parent
	{
		public get()
		{
			return Dynamic_GetParent(this);
		}
	}
	
	public bool GetName(char[] buffer, int length)
	{
		return Dynamic_GetName(this, buffer, length);
	}
	
	property int MemberCount
	{
		public get()
		{
			return Dynamic_GetMemberCount(this);
		}
	}
	
	public void Dispose(bool disposemembers=true)
	{
		Dynamic_Dispose(view_as<int>(this), disposemembers);
	}
	
	public bool Reset(bool disposemembers=true, int blocksize=0, int startsize=0)
	{
		return Dynamic_ResetObject(view_as<int>(this), disposemembers, blocksize, startsize);
	}
	
	property Handle OwnerPlugin
	{
		public get()
		{
			return Dynamic_GetOwnerPlugin(this);
		}
	}
	
	public bool SetName(const char[] objectname, bool replace=false)
	{
		return Dynamic_SetName(this, objectname, replace);
	}
	
	public static Dynamic FindByName(const char[] objectname)
	{
		return Dynamic_FindByName(objectname);
	}
	
	public bool ReadConfig(const char[] path, bool use_valve_fs = false, int valuelength=256)
	{
		return Dynamic_ReadConfig(this, path, use_valve_fs, valuelength);
	}
	
	public bool WriteConfig(const char[] path)
	{
		return Dynamic_WriteConfig(this, path);
	}
	
	public bool ReadKeyValues(const char[] path, int valuelength = 256, Dynamic_HookType callback = INVALID_FUNCTION)
	{
		return Dynamic_ReadKeyValues(this, path, valuelength, callback);
	}
	
	public bool WriteKeyValues(const char[] path, const char[] basekey="")
	{
		return Dynamic_WriteKeyValues(this, path, basekey);
	}
	
	public static Dynamic GetSettings()
	{
		return view_as<Dynamic>(0);
	}
	
	public static Dynamic GetPlayerSettings(int client)
	{
		return view_as<Dynamic>(client);
	}
	
	public int GetInt(const char[] membername, int defaultvalue=-1)
	{
		return Dynamic_GetInt(this, membername, defaultvalue);
	}
	
	public DynamicOffset SetInt(const char[] membername, int value)
	{
		return Dynamic_SetInt(this, membername, value);
	}
	
	public int GetIntByOffset(DynamicOffset offset, int defaultvalue=-1)
	{
		return Dynamic_GetIntByOffset(this, offset, defaultvalue);
	}
	
	public void SetIntByOffset(DynamicOffset offset, int value)
	{
		Dynamic_SetIntByOffset(this, offset, value);
	}
	
	public int PushInt(int value, const char[] name="")
	{
		return Dynamic_PushInt(this, value, name);
	}
	
	public int GetIntByIndex(int index, int defaultvalue=-1)
	{
		return Dynamic_GetIntByIndex(this, index, defaultvalue);
	}
	
	public bool GetBool(const char[] membername, bool defaultvalue = false)
	{
		return Dynamic_GetBool(this, membername, defaultvalue);
	}
	
	public DynamicOffset SetBool(const char[] membername, bool value)
	{
		return Dynamic_SetBool(this, membername, value);
	}
	
	public bool GetBoolByOffset(DynamicOffset offset, bool defaultvalue = false)
	{
		return Dynamic_GetBoolByOffset(this, offset, defaultvalue);
	}
	
	public void SetBoolByOffset(DynamicOffset offset, bool value)
	{
		Dynamic_SetBoolByOffset(this, offset, value);
	}
	
	public int PushBool(bool value, const char[] name="")
	{
		return Dynamic_PushBool(this, value, name);
	}
	
	public bool GetBoolByIndex(int index, bool defaultvalue = false)
	{
		return Dynamic_GetBoolByIndex(this, index, defaultvalue);
	}
	
	public float GetFloat(const char[] membername, float defaultvalue=-1.0)
	{
		return Dynamic_GetFloat(this, membername, defaultvalue);
	}
	
	public DynamicOffset SetFloat(const char[] membername, float value)
	{
		return Dynamic_SetFloat(this, membername, value);
	}
	
	public float GetFloatByOffset(DynamicOffset offset, float defaultvalue=-1.0)
	{
		return Dynamic_GetFloatByOffset(this, offset, defaultvalue);
	}
	
	public void SetFloatByOffset(DynamicOffset offset, float value)
	{
		Dynamic_SetFloatByOffset(this, offset, value);
	}
	
	public int PushFloat(float value, const char[] name="")
	{
		return Dynamic_PushFloat(this, value, name);
	}
	
	public float GetFloatByIndex(int index, float defaultvalue=-1.0)
	{
		return Dynamic_GetFloatByIndex(this, index, defaultvalue);
	}
	
	public bool GetString(const char[] membername, char[] buffer, int length)
	{
		return Dynamic_GetString(this, membername, buffer, length);
	}
	
	public DynamicOffset SetString(const char[] membername, const char[] value, int length=0)
	{
		return Dynamic_SetString(this, membername, value, length);
	}
	
	public int GetStringByOffset(DynamicOffset offset, char[] buffer, int length)
	{
		return Dynamic_GetStringByOffset(this, offset, buffer, length);
	}
	
	public void SetStringByOffset(const DynamicOffset offset, const char[] value, int length=0)
	{
		Dynamic_SetStringByOffset(this, offset, value, length);
	}
	
	public int PushString(const char[] value, int length=0, const char[] name="")
	{
		return Dynamic_PushString(this, value, length, name);
	}
	
	public bool GetStringByIndex(int index, char[] buffer, int length)
	{
		return Dynamic_GetStringByIndex(this, index, buffer, length);
	}
	
	public int GetStringLength(const char[] membername)
	{
		return Dynamic_GetStringLength(this, membername);
	}
	
	public int GetStringLengthByOffset(DynamicOffset offset)
	{
		return Dynamic_GetStringLengthByOffset(this, offset);
	}
	
	public bool CompareString(const char[] membername, const char[] value, bool casesensitive=true)
	{
		return Dynamic_CompareString(this, membername, value, casesensitive);
	}
	
	#pragma deprecated Use .GetDynamic() instead
	public Dynamic GetObject(const char[] membername)
	{
		return Dynamic_GetDynamic(this, membername);
	}
	
	#pragma deprecated Use .SetDynamic() instead
	public DynamicOffset SetObject(const char[] membername, Dynamic value)
	{
		return Dynamic_SetDynamic(this, membername, value);
	}
	
	#pragma deprecated Use .SetDynamicByOffset() instead
	public Dynamic GetObjectByOffset(DynamicOffset offset)
	{
		return Dynamic_GetDynamicByOffset(this, offset);
	}
	
	#pragma deprecated Use .SetDynamicByOffset() instead
	public void SetObjectByOffset(DynamicOffset offset, Dynamic value)
	{
		Dynamic_SetDynamicByOffset(this, offset, value);
	}
	
	#pragma deprecated Use .PushDynamic() instead
	public int PushObject(Dynamic value, const char[] name="")
	{
		return Dynamic_PushDynamic(this, value, name);
	}
	
	#pragma deprecated Use .GetDynamicByIndex() instead
	public Dynamic GetObjectByIndex(int index)
	{
		return Dynamic_GetDynamicByIndex(this, index);
	}
	
	#pragma deprecated Use .SetDynamicByIndex() instead
	public bool SetObjectByIndex(int index, Dynamic value)
	{
		return Dynamic_SetDynamicByIndex(this, index, value);
	}
	
	public Dynamic GetDynamic(const char[] membername)
	{
		return Dynamic_GetDynamic(this, membername);
	}
	
	public DynamicOffset SetDynamic(const char[] membername, Dynamic value)
	{
		return Dynamic_SetDynamic(this, membername, value);
	}
	
	public Dynamic GetDynamicByOffset(DynamicOffset offset)
	{
		return Dynamic_GetDynamicByOffset(this, offset);
	}
	
	public void SetDynamicByOffset(DynamicOffset offset, Dynamic value)
	{
		Dynamic_SetDynamicByOffset(this, offset, value);
	}
	
	public int PushDynamic(Dynamic value, const char[] name="")
	{
		return Dynamic_PushDynamic(this, value, name);
	}
	
	public Dynamic GetDynamicByIndex(int index)
	{
		return Dynamic_GetDynamicByIndex(this, index);
	}
	
	public bool SetDynamicByIndex(int index, Dynamic value)
	{
		return Dynamic_SetDynamicByIndex(this, index, value);
	}
	
	public Handle GetHandle(const char[] membername)
	{
		return Dynamic_GetHandle(this, membername);
	}
	
	public DynamicOffset SetHandle(const char[] membername, Handle value)
	{
		return Dynamic_SetHandle(this, membername, value);
	}
	
	public Handle GetHandleByOffset(DynamicOffset offset)
	{
		return Dynamic_GetHandleByOffset(this, offset);
	}
	
	public void SetHandleByOffset(DynamicOffset offset, Handle value)
	{
		Dynamic_SetHandleByOffset(this, offset, value);
	}
	
	public int PushHandle(Handle value, const char[] name="")
	{
		return Dynamic_PushHandle(this, value, name);
	}
	
	public Handle GetHandleByIndex(int index)
	{
		return Dynamic_GetHandleByIndex(this, index);
	}
	
	public bool GetVector(const char[] membername, float value[3])
	{
		return Dynamic_GetVector(this, membername, value);
	}
	
	public DynamicOffset SetVector(const char[] membername, const float value[3])
	{
		return Dynamic_SetVector(this, membername, value);
	}
	
	public bool GetVectorByOffset(DynamicOffset offset, float[3] value)
	{
		return Dynamic_GetVectorByOffset(this, offset, value);
	}
	
	public void SetVectorByOffset(DynamicOffset offset, const float[3] value)
	{
		Dynamic_SetVectorByOffset(this, offset, value);
	}
	
	public int PushVector(const float value[3], const char[] name="")
	{
		return Dynamic_PushVector(this, value, name);
	}
	
	public bool GetVectorByIndex(int index, float[3] value)
	{
		return Dynamic_GetVectorByIndex(this, index, value);
	}
	
	public void HookChanges(Dynamic_HookType callback)
	{
		Dynamic_HookChanges(this, callback);	
	}
	
	public void UnHookChanges(Dynamic_HookType callback)
	{
		Dynamic_UnHookChanges(this, callback);
	}
	
	public int CallbackCount()
	{
		return Dynamic_CallbackCount(this);
	}
	
	public DynamicOffset GetMemberOffset(const char[] membername)
	{
		return Dynamic_GetMemberOffset(this, membername);
	}
	
	public Dynamic_MemberType GetMemberType(DynamicOffset offset)
	{
		return Dynamic_GetMemberTypeByOffset(this, offset);
	}
	
	public bool GetMemberNameByIndex(int index, char[] buffer, int length)
	{
		return Dynamic_GetMemberNameByIndex(this, index, buffer, length);
	}
	
	public DynamicOffset GetMemberOffsetByIndex(int index)
	{
		return Dynamic_GetMemberOffsetByIndex(this, index);
	}
	
	public bool GetMemberNameByOffset(DynamicOffset offset, char[] buffer, int length)
	{
		return Dynamic_GetMemberNameByOffset(this, offset, buffer, length);
	}
	
	public bool SortMembers(SortOrder order = Sort_Ascending)
	{
		return Dynamic_SortMembers(this, order);
	}
	
	public ArrayList FindByMemberValue(Dynamic params)
	{
		return Dynamic_FindByMemberValue(this, params);
	}
	
	public void CloseHandleByOffset(DynamicOffset offset)
	{
		Handle handle = this.GetHandleByOffset(offset);
		delete handle;
		this.SetHandleByOffset(offset, null);
	}
	
	public void CloseHandle(const char[] membername)
	{
		DynamicOffset offset = this.GetMemberOffset(membername);
		if (offset == INVALID_DYNAMIC_OFFSET)
			return;
			
		this.CloseHandleByOffset(offset);		
	}
}