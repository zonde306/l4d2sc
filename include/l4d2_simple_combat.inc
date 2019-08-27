#if defined __l4d2_simple_combat__
#endinput
#endif
#define __l4d2_simple_combat__

public SharedPlugin __pl_simplecombat =
{
	name = "l4d2_simple_combat",
	file = "l4d2_simple_combat2.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

// 耐力变动回调
// 参数 2 可以更改
forward Action SC_OnStaminaIncreasePre(int client, int& amount);
forward void SC_OnStaminaIncreasePost(int client, int amount);
forward Action SC_OnStaminaDecreasePre(int client, int& amount);
forward void SC_OnStaminaDecreasePost(int client, int amount);

// 魔力变动回调
// 参数 2 可以更改
forward Action SC_OnMagicIncreasePre(int client, int& amount);
forward void SC_OnMagicIncreasePost(int client, int amount);
forward Action SC_OnMagicDecreasePre(int client, int& amount);
forward void SC_OnMagicDecreasePost(int client, int amount);

// 精力变动回调
// 参数 2 可以更改
forward Action SC_OnWillpowerIncreasePre(int client, int& amount);
forward void SC_OnWillpowerIncreasePost(int client, int amount);
forward Action SC_OnWillpowerDecreasePre(int client, int& amount);
forward void SC_OnWillpowerDecreasePost(int client, int amount);

// 升级回调
// 参数 2 可以更改
forward Action SC_OnLevelUpPre(int client, int level, int& experience, int& nextLevel);
forward Action SC_OnLevelUpPost(int client, int level, int& experience, int& nextLevel);

// 获得经验回调
// 参数 2 可以更改
forward Action SC_OnGainExperiencePre(int client, int& amount);
forward void SC_OnGainExperiencePost(int client, int amount);

// 获得金钱回调
// 参数 2 可以更改
forward Action SC_OnGainCashPre(int client, int& amount);
forward void SC_OnGainCashPost(int client, int amount);

// 战斗状态回调
forward Action SC_OnCombatStartPre(int client);
forward void SC_OnCombatStartPost(int client);
forward Action SC_OnCombatEndPre(int client);
forward void SC_OnCombatEndPost(int client);
forward Action SC_OnDamagePre(int attacker, int victim, float& damage, int& damageType, float& plusDamage, float& minusDamage);
forward void SC_OnDamagePost(int attacker, int victim, float damage, int damageType, float plusDamage, float minusDamage);

// 保存读取回调
forward Action SC_OnSavePre(int client, int userId, bool mysql);
forward void SC_OnSavePost(int client, int userId, bool mysql);
forward Action SC_OnLoadPre(int client, int userId, bool mysql);
forward void SC_OnLoadPost(int client, int userId, bool mysql);
forward void SC_OnDataBaseReady(Database db, bool mysql);

// 获取玩家数据库 uid
native int SC_GetClientUserID(int client);

// 获取数据库句柄
// 注意：需要自己手动 delete 或 CloseHandle 否则会内存泄漏
native Database SC_GetDataBase();

// 主菜单选项回调
forward Action SC_OnMenuItemClickPre(int client, const char[] info, const char[] display);
forward void SC_OnMenuItemClickPost(int client, const char[] info, const char[] display);

// 菜单显示回调
// 参数 3 可以更改，用于翻译支持
#pragma deprecated 使用 SC_OnSpellGetInfo 代替
forward Action SC_OnSpellDisplay(int client, const char[] classname, char[] display, int displayMaxLength);
#pragma deprecated 使用 SC_OnSpellGetInfo 代替
forward Action SC_OnSkillDisplay(int client, const char[] classname, char[] display, int displayMaxLength);
#pragma deprecated 使用 SC_OnSkillGetInfo 代替
forward Action SC_OnSpellDescription(int client, const char[] classname, char[] description, int descriptionMaxLength);
#pragma deprecated 使用 SC_OnSkillGetInfo 代替
forward Action SC_OnSkillDescription(int client, const char[] classname, char[] description, int descriptionMaxLength);
forward Action SC_OnSpellGetInfo(int client, const char[] classname, char[] display, int displayMaxLength, char[] description, int descriptionMaxLength);
forward Action SC_OnSkillGetInfo(int client, const char[] classname, char[] display, int displayMaxLength, char[] description, int descriptionMaxLength);

// 主菜单项目
native int SC_AddMainMenuItem(const char[] info, const char[] display);
native int SC_RemoveMainMenuItem(const char[] info);
native bool SC_ShowMainMenu(int client, int menu = 1);

// 玩家耐力
native int SC_GetClientStamina(int client);
native int SC_SetClientStamina(int client, int amount);

// 玩家魔力
native int SC_GetClientMagic(int client);
native int SC_SetClientMagic(int client, int amount);

// 玩家精力
native int SC_GetClientWillpower(int client);
native int SC_SetClientWillpower(int client, int amount);

// 玩家魔力上限
native int SC_GetClientMaxMagic(int client);
native int SC_SetClientMaxMagic(int client, int amount);

// 玩家耐力上限
native int SC_GetClientMaxStamina(int client);
native int SC_SetClientMaxStamina(int client, int amount);

// 玩家生命上限
native int SC_GetClientMaxHealth(int client);
native int SC_SetClientMaxHealth(int client, int amount);

// 玩家精力上限
native int SC_GetClientMaxWillpower(int client);
native int SC_SetClientMaxWillpower(int client, int amount);

// 玩家金钱
native int SC_GetClientCash(int client);
native int SC_SetClientCash(int client, int amount);

// 玩家经验
native int SC_GetClientExperience(int client);
native int SC_SetClientExperience(int client, int amount);

// 玩家等级
native int SC_GetClientLevel(int client);
native int SC_SetClientLevel(int client, int amount);

// 玩家升级所需经验
native int SC_GetClientNextLevelExperience(int client);
native int SC_SetClientNextLevelExperience(int client, int amount);

// 玩家技能点
native int SC_GetClientSkillPoint(int client);
native int SC_SetClientSkillPoint(int client, int amount);

// 玩家技能槽
native int SC_GetClientSkillSlot(int client);
native int SC_SetClientSkillSlot(int client, int amount);

// 给玩家经验
native int SC_GiveClientExperience(int client, int amount);

// 给玩家资金
native int SC_GiveClientCash(int client, int amount);

// 法术使用回调
// 参数 2 可以更改
forward Action SC_OnUseSpellPre(int client, char[] classname, int cln_max);
forward void SC_OnUseSpellPost(int client, const char[] classname);

// 法术获得回调
// 参数 2 可以更改
forward Action SC_OnGainSpellPre(int client, char[] classname, int cln_max);
forward void SC_OnGainSpellPost(int client, const char[] classname);

// 创建法术，索引不保证长期有效
// 参数 1 = 类名，需要保证唯一
// 参数 2 = 显示的名字
// 参数 3 = 使用(释放)消耗多少魔力
// 参数 4 = 购买价格
// 参数 5 = 介绍
native int SC_CreateSpell(const char[] classname, const char[] display, int consume, int cost, const char[] description="");

// 搜索法术，索引不保证长期有效
native int SC_FindSpell(const char[] classname);

// 遍历法术用，索引不保证长期有效
native int SC_GetSpellCount();

// 获取法术信息，返回值需要自行 CloseHandle
native StringMap SC_GetSpell(int index);

// 删除已创建的法术
native void SC_RemoveSpell(int index);

// 法术名字(display)
native bool SC_GetSpellName(int index, char[] buffer, int buf_size);
native bool SC_SetSpellName(int index, const char[] display);

// 法术类名(classname)
native bool SC_GetSpellClass(int index, char[] buffer, int buf_size);
native bool SC_SetSpellClass(int index, const char[] display);

// 法术购买价格
native int SC_GetSpellCost(int index);
native int SC_SetSpellCost(int index, int amount);

// 法术释放消耗
native int SC_GetSpellConsume(int index);
native int SC_SetSpellConsume(int index, int amount);

// 法术介绍
native bool SC_GetSpellDescription(int index, char[] buffer, int buf_size);
native bool SC_SetSpellDescription(int index, const char[] display);

// 搜索玩家法术，索引不保证长期有效
native int SC_FindClientSpell(int client, const char[] classname);
native bool SC_IsClientHaveSpell(int client, const char[] classname);

// 遍历玩家法术，索引不保证长期有效
native int SC_GetClientSpellCount(int client);
native StringMap SC_GetClientSpell(int client);

// 丢弃玩家法术
native bool SC_RemoveClientSpell(int client, int index);

// 给玩家法术，索引不保证长期有效
native int SC_GiveClientSpell(int client, const char[] classname);

// 模拟法术释放，无消耗
native bool SC_FakeUseSpell(int client, const char[] classname);

// 技能获得回调
// 参数 2 可以更改
forward Action SC_OnGainSkillPre(int client, char[] classname, int cls_max);
forward void SC_OnGainSkillPost(int client, const char[] classname);

// 技能 失去/更换 回调
// 参数 2 = 将要失去的技能(可以更改，但必须要保证玩家拥有)
// 参数 3 = 将要获得的技能(被更换为)
// 如果需要修改更换后的技能，可以在 SC_OnGainSkillPre 里修改参数 2
forward Action SC_OnLostSkillPre(int client, char[] oldClassname, int cls_max, const char[] newClassname);
forward void SC_OnLostSkillPost(int client, const char[] oldClassname, const char[] newClassname);

// 创建技能
// 参数 1 = 类名，需要保证唯一
// 参数 2 = 显示的名字
// 参数 3 = 适用的 m_zombieClass 范围，不知道就给 0
// 参数 4 = 介绍
native int SC_CreateSkill(const char[] classname, const char[] display, int zombieType, const char[] description);

// 寻找技能
native int SC_FindSkill(const char[] classname);

// 删除技能
native bool SC_RemoveSkill(int index);

// 获取已注册的技能数量
native int SC_GetSkillCount();

// 获取技能信息，返回值需要自行 CloneHandle
native StringMap SC_GetSkill();

native int SC_GetClientSkillCount(int client);
native StringMap SC_GetClientSkill(int client, int index);

// 给玩家技能，如果已拥有则返回已拥有的索引，否则返回新的索引
native int SC_GiveClientSkill(int client, const char[] classname);

// 删除玩家已拥有的技能
native bool SC_RemoveClientSkill(int client, int index);

// 获取玩家的技能的索引，找不到返回 -1
native int SC_FindClientSkill(int client, const char[] classname);
native bool SC_IsClientHaveSkill(int client, const char[] classname);

// 技能显示名(display)
native bool SC_GetSkillName(int index, char[] buffer, int buf_size);
native bool SC_SetSkillName(int index, const char[] buffer);

// 技能类名(classname)
native bool SC_GetSkillClass(int index, char[] buffer, int buf_size);
native bool SC_SetSkillClass(int index, const char[] buffer);

// 技能介绍
native bool SC_GetSkillDescription(int index, char[] buffer, int buf_size);
native bool SC_SetSkillDescription(int index, const char[] buffer);

// 技能适配角色
native int SC_GetSkillZombieType(int index);
native bool SC_SetSkillZombieType(int index, int zombieType);

#if !defined REQUIRE_PLUGIN
public void __pl_simplecombat_SetNTVOptional()
{
	// 主菜单项目
	MarkNativeAsOptional("SC_AddMainMenuItem");
	MarkNativeAsOptional("SC_RemoveMainMenuItem");

	// 属性
	MarkNativeAsOptional("SC_GetClientStamina");
	MarkNativeAsOptional("SC_SetClientStamina");
	MarkNativeAsOptional("SC_GetClientMagic");
	MarkNativeAsOptional("SC_SetClientMagic");
	MarkNativeAsOptional("SC_GetClientWillpower");
	MarkNativeAsOptional("SC_SetClientWillpower");
	MarkNativeAsOptional("SC_GetClientMaxMagic");
	MarkNativeAsOptional("SC_SetClientMaxMagic");
	MarkNativeAsOptional("SC_GetClientMaxStamina");
	MarkNativeAsOptional("SC_SetClientMaxStamina");
	MarkNativeAsOptional("SC_GetClientMaxHealth");
	MarkNativeAsOptional("SC_SetClientMaxHealth");
	MarkNativeAsOptional("SC_GetClientMaxWillpower");
	MarkNativeAsOptional("SC_SetClientMaxWillpower");

	// 等级相关
	MarkNativeAsOptional("SC_GetClientCash");
	MarkNativeAsOptional("SC_SetClientCash");
	MarkNativeAsOptional("SC_GetClientExperience");
	MarkNativeAsOptional("SC_SetClientExperience");
	MarkNativeAsOptional("SC_GetClientLevel");
	MarkNativeAsOptional("SC_SetClientLevel");
	MarkNativeAsOptional("SC_GetClientNextLevelExperience");
	MarkNativeAsOptional("SC_SetClientNextLevelExperience");
	MarkNativeAsOptional("SC_GiveClientExperience");
	MarkNativeAsOptional("SC_GiveClientCash");

	// 法术操作
	MarkNativeAsOptional("SC_CreateSpell");
	MarkNativeAsOptional("SC_FindSpell");
	MarkNativeAsOptional("SC_RemoveSpell");
	MarkNativeAsOptional("SC_GetSpellCount");
	MarkNativeAsOptional("SC_GetSpell");
	
	MarkNativeAsOptional("SC_GetClientSpellCount");
	MarkNativeAsOptional("SC_GetClientSpell");
	MarkNativeAsOptional("SC_GiveClientSpell");
	MarkNativeAsOptional("SC_RemoveClientSpell");
	MarkNativeAsOptional("SC_FindClientSpell");
	MarkNativeAsOptional("SC_FakeUseSpell");
	
	MarkNativeAsOptional("SC_GetSpellName");
	MarkNativeAsOptional("SC_SetSpellName");
	MarkNativeAsOptional("SC_GetSpellClass");
	MarkNativeAsOptional("SC_SetSpellClass");
	MarkNativeAsOptional("SC_GetSpellCost");
	MarkNativeAsOptional("SC_SetSpellCost");
	MarkNativeAsOptional("SC_GetSpellConsume");
	MarkNativeAsOptional("SC_SetSpellConsume");
	
	MarkNativeAsOptional("SC_GetClientUserID");
	MarkNativeAsOptional("SC_GetDataBase");
	
	MarkNativeAsOptional("SC_CreateSkill");
	MarkNativeAsOptional("SC_FindSkill");
	MarkNativeAsOptional("SC_RemoveSkill");
	MarkNativeAsOptional("SC_GetSkillCount");
	MarkNativeAsOptional("SC_GetSkill");
	MarkNativeAsOptional("SC_GetClientSkillCount");
	MarkNativeAsOptional("SC_GetClientSkill");
	MarkNativeAsOptional("SC_GiveClientSkill");
	MarkNativeAsOptional("SC_RemoveClientSkill");
	MarkNativeAsOptional("SC_FindClientSkill");
	MarkNativeAsOptional("SC_GetClientSkillSlot");
	MarkNativeAsOptional("SC_SetClientSkillSlot");
	MarkNativeAsOptional("SC_GetSkillName");
	MarkNativeAsOptional("SC_SetSkillName");
	MarkNativeAsOptional("SC_GetSkillClass");
	MarkNativeAsOptional("SC_SetSkillClass");
	MarkNativeAsOptional("SC_GetSkillDescription");
	MarkNativeAsOptional("SC_SetSkillDescription");
	MarkNativeAsOptional("SC_GetSkillZombieType");
	MarkNativeAsOptional("SC_SetSkillZombieType");
}
#endif
