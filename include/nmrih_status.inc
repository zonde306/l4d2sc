#if defined _nmrih_status_include_
	#endinput
#endif
#define _nmrih_status_include_

// 获取玩家的积分
native int NMS_GetPoint(int client);

// 设置玩家的积分
native void NMS_SetPoint(int client, int count);

// 修改玩家的积分
native void NMS_ChangePoint(int client, int count);

// 获取玩家的所有属性
native StringMap NMS_GetStatus(int client);

// 修改玩家的属性
native void NMS_ChangeStatus(int client, int type, int count);

// 获取玩家的硬币
native int NMS_GetCoin(int client);

// 修改玩家的硬币
native void NMS_ChangeCoin(int client, int count);

// 玩家是否有效
native bool NMS_IsClientValid(int client);

public SharedPlugin:__pl_status = 
{
	name = "nmrih_status",
	file = "nmp_status.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_status_SetNTVOptional()
{
    MarkNativeAsOptional("NMS_GetPoint");
    MarkNativeAsOptional("NMS_SetPoint");
    MarkNativeAsOptional("NMS_ChangePoint");
    MarkNativeAsOptional("NMS_GetStatus");
    MarkNativeAsOptional("NMS_ChangeStatus");
    MarkNativeAsOptional("NMS_GetCoin");
    MarkNativeAsOptional("NMS_ChangeCoin");
	MarkNativeAsOptional("NMS_IsClientValid");
}
#endif 
