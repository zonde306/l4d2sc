#if defined _shop_included_
 #endinput
#endif
#define _shop_included_

/**
* 获取主插件的版本
*
* @return				主插件版本号
*/
native Float:NMShop_GetVersion();

/**
* 获取玩家的积分数量
*
* @param client		玩家的索引
* @return				玩家的积分数量, 如果失败或真的没有为 0
*/
native NMShop_GetClientPoint(client)

/**
* 设置玩家的积分数量
*
* @param client		玩家的索引
* @param point		设置的积分数量
* @return				如果为 true 则成功, 否则 false
*/
native bool:NMShop_SetClientPoint(client, point)

/**
* 注册一个菜单项
*
* @param name		注册的名字
* @return				菜单项的索引, 用于 forward 的调用
*/
native NMShop_RegisterNewItem(String:name[])

/**
* 暂停已注册的一个菜单项
*
* @param index		菜单项索引
* @return				如果 true 为成功, 否则 false
*/
native bool:NMShop_UnRegisterNewItem(index)

/**
* 解除暂停已注册的一个菜单项
*
* @param index		菜单项索引
* @return				如果 true 为成功, 否则 false
*/
native bool:NMShop_ResetRegisterNewItem(index)

/**
* 获取目前已注册的菜单项的数量
*
* @return				菜单项的数量
*/
native NMShop_GetRgeisterCount()

/**
* 当玩家选择一个菜单项的时候触发
*
* @param client		玩家索引
* @param index		菜单索引
* @return				没有
*/
forward NMShop_OnClientMenuItem(client, index)

/**
* 当主插件开始时触发
*
* @return				没有
*/
forward NMShop_OnPluginStart()

public SharedPlugin:__pl_shop = 
{
	name = "NMShop",
	file = "nmp_shop+.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};