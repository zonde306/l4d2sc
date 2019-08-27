#if defined _nmrih_point_store_include_
	#endinput
#endif
#define _nmrih_point_store_include_

typedef nmps_cb = function void(int client, char[] info, char[] display)

// 注册一个菜单选项
native int NMS_AddMenuSelect(char[] info, char[] display, nmps_cb callback, bool keep = false);

// 撤销一个已注册的菜单选项
native void NMS_RemoveMenuSelect(int index);

public SharedPlugin:__pl_store = 
{
	name = "nmrih_point_store",
	file = "nmp_point_store2.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_store_SetNTVOptional()
{
    MarkNativeAsOptional("NMS_AddMenuSelect");
    MarkNativeAsOptional("NMS_RemoveMenuSelect");
}
#endif 
