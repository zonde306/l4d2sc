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

native int Dynamic_GetCollectionSize();

native Dynamic Dynamic_Initialise(int blocksize=64, int startsize=0, bool persistent=false);
native bool Dynamic_IsValid(int index, bool throwerror=false);
native bool Dynamic_Dispose(int index, bool disposemembers=true);
native bool Dynamic_ResetObject(int index, bool disposemembers=true, int blocksize=0, int startsize=0);
native Handle Dynamic_GetOwnerPlugin(Dynamic obj);

native bool Dynamic_SetName(Dynamic obj, const char[] objectname, bool replace=false);
native Dynamic Dynamic_FindByName(const char[] objectname);
native Dynamic Dynamic_GetParent(Dynamic obj);
native bool Dynamic_GetName(Dynamic obj, char[] buffer, int length);

native bool Dynamic_GetPersistence(Dynamic obj);
native bool Dynamic_SetPersistence(Dynamic obj, bool value);

native bool Dynamic_ReadConfig(Dynamic obj, const char[] path, bool use_valve_fs=false, int valuelength=256);
native bool Dynamic_WriteConfig(Dynamic obj, const char[] path);

native bool Dynamic_ReadKeyValues(Dynamic obj, const char[] path, int valuelength, Dynamic_HookType callback=INVALID_FUNCTION);
native bool Dynamic_WriteKeyValues(Dynamic obj, const char[] path, const char[] basekey);

native int Dynamic_GetMemberCount(Dynamic obj);
native DynamicOffset Dynamic_GetMemberOffset(Dynamic obj, const char[] membername);
native DynamicOffset Dynamic_GetMemberOffsetByIndex(Dynamic obj, int index);
native bool Dynamic_GetMemberNameByIndex(Dynamic obj, int index, char[] buffer, int length);
native bool Dynamic_GetMemberNameByOffset(Dynamic obj, DynamicOffset offset, char[] buffer, int length);
native Dynamic_MemberType Dynamic_GetMemberType(Dynamic obj, const char[] membername);
native Dynamic_MemberType Dynamic_GetMemberTypeByOffset(Dynamic obj, DynamicOffset offset);
native bool Dynamic_SortMembers(Dynamic obj, SortOrder order);
native ArrayList Dynamic_FindByMemberValue(Dynamic obj, Dynamic params);

native int Dynamic_CallbackCount(Dynamic obj);
native bool Dynamic_HookChanges(Dynamic obj, Dynamic_HookType callback);
native bool Dynamic_UnHookChanges(Dynamic obj, Dynamic_HookType callback);

native int Dynamic_GetInt(Dynamic obj, const char[] membername, int defaultvalue=-1);
native DynamicOffset Dynamic_SetInt(Dynamic obj, const char[] membername, int value);
native int Dynamic_GetIntByOffset(Dynamic obj, DynamicOffset offset, int defaultvalue=-1);
native bool Dynamic_SetIntByOffset(Dynamic obj, DynamicOffset offset, int value);
native int Dynamic_PushInt(Dynamic obj, int value, const char[] name="");
native int Dynamic_GetIntByIndex(Dynamic obj, int index, int defaultvalue=-1);

native float Dynamic_GetFloat(Dynamic obj, const char[] membername, float defaultvalue=-1.0);
native DynamicOffset Dynamic_SetFloat(Dynamic obj, const char[] membername, float value);
native float Dynamic_GetFloatByOffset(Dynamic obj, DynamicOffset offset, float defaultvalue=-1.0);
native bool Dynamic_SetFloatByOffset(Dynamic obj, DynamicOffset offset, float value);
native int Dynamic_PushFloat(Dynamic obj, float value, const char[] name="");
native float Dynamic_GetFloatByIndex(Dynamic obj, int index, float defaultvalue=-1.0);

native bool Dynamic_GetString(Dynamic obj, const char[] membername, char[] buffer, int length);
native DynamicOffset Dynamic_SetString(Dynamic obj, const char[] membername, const char[] value, int length=0);
native bool Dynamic_GetStringByOffset(Dynamic obj, DynamicOffset offset, char[] buffer, int length);
native bool Dynamic_SetStringByOffset(Dynamic obj, DynamicOffset offset, const char[] value, int length=0);
native int Dynamic_PushString(Dynamic obj, const char[] value, int length=0, const char[] name="");
native bool Dynamic_GetStringByIndex(Dynamic obj, int index, char[] buffer, int length);
native int Dynamic_GetStringLength(Dynamic obj, const char[] membername);
native int Dynamic_GetStringLengthByOffset(Dynamic obj, DynamicOffset offset);
native bool Dynamic_CompareString(Dynamic obj, const char[] membername, const char[] value, bool casesensitive=true);

// This can be removed at some point in the future
#pragma deprecated Use Dynamic_GetDynamic() instead
native Dynamic Dynamic_GetObject(Dynamic obj, const char[] membername);
#pragma deprecated Use Dynamic_SetDynamic() instead
native DynamicOffset Dynamic_SetObject(Dynamic obj, const char[] membername, Dynamic value);
#pragma deprecated Use Dynamic_GetDynamicByOffset() instead
native Dynamic Dynamic_GetObjectByOffset(Dynamic obj, DynamicOffset offset);
#pragma deprecated Use Dynamic_SetDynamicByOffset() instead
native bool Dynamic_SetObjectByOffset(Dynamic obj, DynamicOffset offset, Dynamic value);
#pragma deprecated Use Dynamic_PushDynamic() instead
native int Dynamic_PushObject(Dynamic obj, Dynamic value, const char[] name="");
#pragma deprecated Use Dynamic_GetDynamicByIndex() instead
native Dynamic Dynamic_GetObjectByIndex(Dynamic obj, int index);
#pragma deprecated Use Dynamic_SetDynamicByIndex() instead
native bool Dynamic_SetObjectByIndex(Dynamic obj, int index, Dynamic value);

native Dynamic Dynamic_GetDynamic(Dynamic obj, const char[] membername);
native DynamicOffset Dynamic_SetDynamic(Dynamic obj, const char[] membername, Dynamic value);
native Dynamic Dynamic_GetDynamicByOffset(Dynamic obj, DynamicOffset offset);
native bool Dynamic_SetDynamicByOffset(Dynamic obj, DynamicOffset offset, Dynamic value);
native int Dynamic_PushDynamic(Dynamic obj, Dynamic value, const char[] name="");
native Dynamic Dynamic_GetDynamicByIndex(Dynamic obj, int index);
native bool Dynamic_SetDynamicByIndex(Dynamic obj, int index, Dynamic value);

native bool Dynamic_GetBool(Dynamic obj, const char[] membername, bool defaultvalue=false);
native DynamicOffset Dynamic_SetBool(Dynamic obj, const char[] membername, bool value);
native bool Dynamic_GetBoolByOffset(Dynamic obj, DynamicOffset offset, bool defaultvalue=false);
native bool Dynamic_SetBoolByOffset(Dynamic obj, DynamicOffset offset, bool value);
native int Dynamic_PushBool(Dynamic obj, bool value, const char[] name="");
native bool Dynamic_GetBoolByIndex(Dynamic obj, int index, bool defaultvalue=false);

native Handle Dynamic_GetHandle(Dynamic obj, const char[] membername);
native DynamicOffset Dynamic_SetHandle(Dynamic obj, const char[] membername, Handle value);
native Handle Dynamic_GetHandleByOffset(Dynamic obj, DynamicOffset offset);
native bool Dynamic_SetHandleByOffset(Dynamic obj, DynamicOffset offset, Handle value);
native int Dynamic_PushHandle(Dynamic obj, Handle value, const char[] name="");
native Handle Dynamic_GetHandleByIndex(Dynamic obj, int index);

native bool Dynamic_GetVector(Dynamic obj, const char[] membername, float value[3]);
native DynamicOffset Dynamic_SetVector(Dynamic obj, const char[] membername, const float value[3]);
native bool Dynamic_GetVectorByOffset(Dynamic obj, DynamicOffset offset, float value[3]);
native bool Dynamic_SetVectorByOffset(Dynamic obj, DynamicOffset offset, const float value[3]);
native int Dynamic_PushVector(Dynamic obj, const float value[3], const char[] name="");
native bool Dynamic_GetVectorByIndex(Dynamic obj, int index, float value[3]);

#if !defined REQUIRE_PLUGIN
public __pl_dynamic_SetNTVOptional()
{
	MarkNativeAsOptional("Dynamic_Initialise");
	MarkNativeAsOptional("Dynamic_IsValid");
	MarkNativeAsOptional("Dynamic_Dispose");
	MarkNativeAsOptional("Dynamic_ResetObject");
	MarkNativeAsOptional("Dynamic_GetOwnerPlugin");
	MarkNativeAsOptional("Dynamic_SetName");
	MarkNativeAsOptional("Dynamic_FindByName");
	MarkNativeAsOptional("Dynamic_GetParent");
	MarkNativeAsOptional("Dynamic_GetName");
	MarkNativeAsOptional("Dynamic_GetPersistence");
	MarkNativeAsOptional("Dynamic_SetPersistence");
	MarkNativeAsOptional("Dynamic_ReadConfig");
	MarkNativeAsOptional("Dynamic_WriteConfig");
	MarkNativeAsOptional("Dynamic_ReadKeyValues");
	MarkNativeAsOptional("Dynamic_WriteKeyValues");
	MarkNativeAsOptional("Dynamic_GetInt");
	MarkNativeAsOptional("Dynamic_SetInt");
	MarkNativeAsOptional("Dynamic_GetIntByOffset");
	MarkNativeAsOptional("Dynamic_SetIntByOffset");
	MarkNativeAsOptional("Dynamic_PushInt");
	MarkNativeAsOptional("Dynamic_GetIntByIndex");
	MarkNativeAsOptional("Dynamic_GetBool");
	MarkNativeAsOptional("Dynamic_SetBool");
	MarkNativeAsOptional("Dynamic_GetBoolByOffset");
	MarkNativeAsOptional("Dynamic_SetBoolByOffset");
	MarkNativeAsOptional("Dynamic_PushBool");
	MarkNativeAsOptional("Dynamic_GetBoolByIndex");
	MarkNativeAsOptional("Dynamic_GetFloat");
	MarkNativeAsOptional("Dynamic_SetFloat");
	MarkNativeAsOptional("Dynamic_GetFloatByOffset");
	MarkNativeAsOptional("Dynamic_SetFloatByOffset");
	MarkNativeAsOptional("Dynamic_PushFloat");
	MarkNativeAsOptional("Dynamic_GetFloatByIndex");
	MarkNativeAsOptional("Dynamic_GetString");
	MarkNativeAsOptional("Dynamic_SetString");
	MarkNativeAsOptional("Dynamic_GetStringByOffset");
	MarkNativeAsOptional("Dynamic_SetStringByOffset");
	MarkNativeAsOptional("Dynamic_PushString");
	MarkNativeAsOptional("Dynamic_GetStringByIndex");
	MarkNativeAsOptional("Dynamic_GetStringLength");
	MarkNativeAsOptional("Dynamic_GetStringLengthByOffset");
	MarkNativeAsOptional("Dynamic_CompareString");
	MarkNativeAsOptional("Dynamic_GetDynamic");
	MarkNativeAsOptional("Dynamic_SetDynamic");
	MarkNativeAsOptional("Dynamic_GetDynamicByOffset");
	MarkNativeAsOptional("Dynamic_SetDynamicByOffset");
	MarkNativeAsOptional("Dynamic_PushDynamic");
	MarkNativeAsOptional("Dynamic_GetDynamicByIndex");
	MarkNativeAsOptional("Dynamic_SetDynamicByIndex");
	MarkNativeAsOptional("Dynamic_GetHandle");
	MarkNativeAsOptional("Dynamic_SetHandle");
	MarkNativeAsOptional("Dynamic_GetHandleByOffset");
	MarkNativeAsOptional("Dynamic_SetHandleByOffset");
	MarkNativeAsOptional("Dynamic_PushHandle");
	MarkNativeAsOptional("Dynamic_GetHandleByIndex");
	MarkNativeAsOptional("Dynamic_GetVector");
	MarkNativeAsOptional("Dynamic_SetVector");
	MarkNativeAsOptional("Dynamic_GetVectorByOffset");
	MarkNativeAsOptional("Dynamic_SetVectorByOffset");
	MarkNativeAsOptional("Dynamic_PushVector");
	MarkNativeAsOptional("Dynamic_GetVectorByIndex");
	MarkNativeAsOptional("Dynamic_GetCollectionSize");
	MarkNativeAsOptional("Dynamic_GetMemberCount");
	MarkNativeAsOptional("Dynamic_HookChanges");
	MarkNativeAsOptional("Dynamic_UnHookChanges");
	MarkNativeAsOptional("Dynamic_CallbackCount");
	MarkNativeAsOptional("Dynamic_GetMemberOffset");
	MarkNativeAsOptional("Dynamic_GetMemberOffsetByIndex");
	MarkNativeAsOptional("Dynamic_GetMemberType");
	MarkNativeAsOptional("Dynamic_GetMemberTypeByOffset");
	MarkNativeAsOptional("Dynamic_GetMemberNameByIndex");
	MarkNativeAsOptional("Dynamic_GetMemberNameByOffset");
	MarkNativeAsOptional("Dynamic_SortMembers");
	MarkNativeAsOptional("Dynamic_FindByMemberValue");
	
	// These are marked as deprecated
	MarkNativeAsOptional("Dynamic_GetObject");
	MarkNativeAsOptional("Dynamic_SetObject");
	MarkNativeAsOptional("Dynamic_GetObjectByOffset");
	MarkNativeAsOptional("Dynamic_SetObjectByOffset");
	MarkNativeAsOptional("Dynamic_PushObject");
	MarkNativeAsOptional("Dynamic_GetObjectByIndex");
	MarkNativeAsOptional("Dynamic_SetObjectByIndex");
}
#endif