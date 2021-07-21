#if defined __l4d2_skill_framework__
#endinput
#endif

#define __l4d2_skill_framework__

public SharedPlugin __pl_skillframework =
{
	name = "l4d2_skill_framework",
	file = "l4d2_skill_framework.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

enum struct PerkData_t
{
	int maxLevel;				// 该技能有几个级别
	int slot;					// 技能树ID
	int baseLevel;				// 选取技能所需等级
	int baseSkillLevel;			// 选取技能所需技能树等级
	float levelFactor;			// 每个级别所需技能树等级因素
}

// 技能访问权限(按位处理)
enum PerkPerm_t
{
	NO_ACCESS = 0,				// 禁止访问
	CAN_VIEW = (1 << 0),		// 可以查看
	CAN_FETCH = (1 << 2),		// 可以选取
	FREE_FETCH = (1 << 3),		// 允许无限制选取(选取时仍然会消耗技能点)
}

/**
 * @brief 注册一个技能树(技能类型)
 * @remarks name 必须是唯一的；无法重复注册
 *
 * @param name					技能树类名，只允许使用英文字母和数字
 *
 * @see							L4D2SF_OnGetSlotName
 *
 * @return						技能树ID；不存在时创建，存在时直接返回现有的。
 */
native int L4D2SF_RegSlot(const char[] name);

/**
 * @brief 注册一个技能树
 * @remaining name 必须是唯一的；无法重复注册
 *
 * @param slotId				技能树ID
 * @param name					技能类名，只允许使用英文字母和数字
 * @param maxLevel				技能有多少个级别
 * @param baseSkillLevel		选取该技能最少需要技能树达到多少级(L4D2SF_GetSkillLevel)
 * @param baseLevel				选取该技能最少需要达到多少级(L4D2SF_GetLevel)
 * @param factor				提升技能级别需要的槽位等级倍率(下一级要求=baseSkillLevel+baseSkillLevel*factor*当前等级)
 *
 * @see							L4D2SF_OnGetPerkName
 * @see							L4D2SF_OnGetPerkDescription
 *
 * @return						技能树ID；不存在时创建，存在时直接返回现有的。
 */
native bool L4D2SF_RegPerk(int slotId, const char[] name, int maxLevel, int baseSkillLevel, int baseLevel, float factor = 1.0);

/**
 * @brief 根据技能类名获取技能数据
 *
 * @param name					技能类名
 * @param data					返回的技能数据(PerkData_t)
 *
 * @return						找到时返回 true 并填充传入的 data，否则返回 false
 */
native bool L4D2SF_FindPerk(const char[] name, any[] data);

/**
 * @brief 给玩家一个技能
 *
 * @param client				玩家索引
 * @param name					技能类名
 * @param level					技能级别
 *
 * @return						成功返回 true，否则返回 false
 */
native bool L4D2SF_GivePerk(int client, const char[] name, int level = 0);

/**
 * @brief 获取玩家相关技能的级别
 *
 * @param client				玩家索引
 * @param name					技能类名
 *
 * @return						技能级别，未学习返回 0，失败返回 -1
 */
native int L4D2SF_GetClientPerk(int client, const char[] name);

/**
 * @brief 给予玩家一些技能树经验
 * @remarks 经验足够时可提升技能树等级
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param amount				数量；可传递负数，但不会降级
 */
native void L4D2SF_GiveSkillExperience(int client, int slotId, int amount);

/**
 * @brief 给予玩家一些经验
 * @remarks 经验足够时可提升等级
 *
 * @param client				玩家索引
 * @param amount				数量；可传递负数，但不会降级
 */
native void L4D2SF_GiveExperience(int client, int amount);

/**
 * @brief 获取玩家技能树现有经验
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 *
 * @return						经验值，失败返回 -1
 */
native int L4D2SF_GetSkillExperience(int client, int slotId);

/**
 * @brief 获取玩家现有经验
 *
 * @param client				玩家索引
 *
 * @return						经验值，失败返回 -1
 */
native int L4D2SF_GetExperience(int client);

/**
 * @brief 获取玩家技能树当前等级
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 *
 * @return						技能树等级，失败返回 -1
 */
native int L4D2SF_GetSkillLevel(int client, int slotId);

/**
 * @brief 获取玩家当前等级
 *
 * @param client				玩家索引
 *
 * @return						玩家等级，失败返回 -1
 */
native int L4D2SF_GetLevel(int client);

/**
 * @brief 给予玩家技能树等级
 * @remarks 此操作不会获得经验
 *
 * @param client				玩家索引
 * @param slotId				技能树ID，可通过 L4D2SF_RegSlot 获取
 * @param level					等级数量，可传负数来降级
 *
 * @return						玩家等级，失败返回 -1
 */
native int L4D2SF_GiveSkillLevel(int client, int slotId, int level);

/**
 * @brief 给予玩家等级
 * @remarks 此操作不会给玩家技能点
 *
 * @param client				玩家索引
 * @param slotId				技能树ID，可通过 L4D2SF_RegSlot 获取
 * @param level					等级数量，可传负数来降级
 *
 * @return						玩家等级，失败返回 -1
 */
native int L4D2SF_GiveLevel(int client, int level);

/**
 * @brief 获取全部技能
 *
 * @return						技能列表，具体使用方法查看 SourceMOD 的文档
 */
native StringMapSnapshot L4D2SF_GetAllPerks();

/**
 * @brief 给予玩家技能点
 *
 * @param client				玩家索引
 * @param amount				技能点数量；可以传负数来减少
 */
native void L4D2SF_GivePoint(int client, int amount);

/**
 * @brief 获取玩家技能点数量
 *
 * @param client				玩家索引
 *
 * @return						玩家现有技能点数量
 */
native int L4D2SF_GetPoint(int client);

/**
 * @brief 获取所有技能树列表
 *
 * @return						技能树列表
 */
native StringMapSnapshot L4D2SF_GetAllSlots();

/**
 * @brief 将技能树类名转换为技能树ID
 * @remaining 不存在时不会创建
 *
 * @param name					技能树类名
 *
 * @return						技能树ID；失败返回 -1
 */
native int L4D2SF_SlotNameToSlotId(const char[] name);

/**
 * @brief 将技能树ID转换为技能树类名
 * @remaining 不存在时不会创建
 *
 * @param slotId				技能树ID
 * @param result				返回的技能树类名
 * @param maxlen				返回的技能树类名可写入大小
 *
 * @return						成功返回 true；不存在返回 false
 */
native bool L4D2SF_SlotIdToSlotName(int slotId, char[] result, int maxlen);

/**
 * @brief 获取技能树显示名(翻译后的)
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param result				返回的技能树显示名
 * @param maxlen				返回的技能树显示名可写入大小
 *
 * @return						成功返回 true；否则返回 false
 */
native bool L4D2SF_GetSlotName(int client, int slotId, char[] result, int maxlen);

/**
 * @brief 获取技能显示名(翻译后的)
 *
 * @param client				玩家索引
 * @param perk					技能类名
 * @param result				返回的技能显示名
 * @param maxlen				返回的技能显示名可写入大小
 * @param level					技能等级
 *
 * @return						成功返回 true；否则返回 false
 */
native bool L4D2SF_GetPerkName(int client, const char[] perk, char[] result, int maxlen, int level = 0);

/**
 * @brief 获取技能说明(翻译后的)
 *
 * @param client				玩家索引
 * @param perk					技能类名
 * @param result				返回的技能显示名
 * @param maxlen				返回的技能显示名可写入大小
 * @param level					技能等级
 *
 * @return						成功返回 true；否则返回 false
 */
native bool L4D2SF_GetPerkDescription(int client, const char[] perk, char[] result, int maxlen, int level = 0);

/**
 * @brief 检查玩家是否可访问指定技能
 *
 * @param client				玩家索引
 * @param perk					技能类名
 *
 * @return						玩家访问指定技能的权限
 */
native PerkPerm_t L4D2SF_GetPerkAccess(int client, const char[] perk);

/**
 * @brief 当玩家获得技能(树)经验时调用
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param amount				经验数量
 * @param cap					需要多少经验才能升级
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止经验获得
 */
forward Action L4D2SF_OnSkillExperiencePre(int client, int& slotId, int& amount, int& cap);

/**
 * @brief 当玩家获得技能(树)经验后调用
 * @remarks 如果获得经验后导致升级，cap 提供的是旧的值(即上一级的cap)
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param amount				经验数量
 * @param cap					需要多少经验才能升级
 */
forward void L4D2SF_OnSkillExperiencePost(int client, int slotId, int amount, int cap);

/**
 * @brief 当玩家获得经验时调用
 *
 * @param client				玩家索引
 * @param amount				经验数量
 * @param cap					需要多少经验才能升级
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止经验获得
 */
forward Action L4D2SF_OnExperiencePre(int client, int& amount, int& cap);

/**
 * @brief 当玩家获得技能(树)经验后调用
 * @remarks 如果获得经验后导致升级，cap 提供的是旧的值(即上一级的cap)
 *
 * @param client				玩家索引
 * @param amount				经验数量
 * @param cap					需要多少经验才能升级
 */
forward void L4D2SF_OnExperiencePost(int client, int amount, int cap);

/**
 * @brief 当玩家技能(树)等级提升时调用
 * @remarks 降级也会触发
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param nextLevel				升级后的等级
 * @param remaining				升级后剩余的经验值
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止等级提升
 */
forward Action L4D2SF_OnSkillLevelUpPre(int client, int& slotId, int& nextLevel, int& remaining);

/**
 * @brief 当玩家技能(树)等级提升后调用
 * @remarks 降级也会触发
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param nextLevel				升级后的等级
 * @param remaining				升级后剩余的经验值
 */
forward void L4D2SF_OnSkillLevelUpPost(int client, int slotId, int nextLevel, int remaining);

/**
 * @brief 当玩家等级提升时调用
 * @remarks 降级也会触发
 *
 * @param client				玩家索引
 * @param nextLevel				升级后的等级
 * @param remaining				升级后剩余的经验值
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止等级提升
 */
forward Action L4D2SF_OnLevelUpPre(int client, int& nextLevel, int& remaining);

/**
 * @brief 当玩家等级提升后调用
 * @remarks 降级也会触发
 *
 * @param client				玩家索引
 * @param nextLevel				升级后的等级
 * @param remaining				升级后剩余的经验值
 */
forward void L4D2SF_OnLevelUpPost(int client, int nextLevel, int remaining);

/**
 * @brief 获取技能名字(用于显示)
 * @remarks 如果注册了技能，需要监听它来显示名字
 *
 * @param client				玩家索引
 * @param name					技能类名
 * @param level					技能等级
 * @param result				要返回的名字
 * @param maxlen				返回名字可用字节数
 *
 * @return						修改 result 后提供 Plugin_Changed，否则提供 Plugin_Continue
 */
forward Action L4D2SF_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen);

/**
 * @brief 获取技能说明(用于显示)
 * @remarks 如果注册了技能，需要监听它来显示说明
 *
 * @param client				玩家索引
 * @param name					技能类名
 * @param level					技能等级
 * @param result				要返回的说明
 * @param maxlen				返回名字可用字节数
 *
 * @return						修改 result 后提供 Plugin_Changed，否则提供 Plugin_Continue
 */
forward Action L4D2SF_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen);

/**
 * @brief 当玩家获得技能点时触发
 * @remarks 减少时不会触发
 *
 * @param client				玩家索引
 * @param amount				技能点数量
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止等级提升
 */
forward Action L4D2SF_PointPre(int client, int& amount);

/**
 * @brief 当玩家获得技能点后触发
 * @remarks 减少时不会触发
 *
 * @param client				玩家索引
 * @param amount				技能点数量
 */
forward void L4D2SF_PointPost(int client, int amount);

/**
 * @brief 确认玩家是否可以访问某个技能
 * @remarks 用于处理以特殊方式获得的技能
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param perk					技能类名
 * @param result				访问权限
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止等级提升
 */
forward Action L4D2SF_CanAccessPerk(int client, int slotId, const char[] perk, PerkPerm_t& result);

/**
 * @brief 获取技能树名字(用于显示)
 * @remarks 如果注册了技能树，需要监听它来显示名字
 *
 * @param client				玩家索引
 * @param slotId				技能树ID
 * @param result				要返回的说明
 * @param maxlen				返回名字可用字节数
 *
 * @return						修改 result 后提供 Plugin_Changed，否则提供 Plugin_Continue
 */
forward Action L4D2SF_OnGetSlotName(int client, int slotId, char[] result, int maxlen);

/**
 * @brief 玩家获得技能时触发
 * @remarks 失去技能也会触发
 *
 * @param client				玩家索引
 * @param level					技能等级
 * @param perk					技能类名
 * @param maxlen				技能类名字符上限
 *
 * @return						Plugin_Continue 不做任何事情；Plugin_Changed 修改参数；Plugin_Handled 阻止等级提升
 */
forward Action L4D2SF_OnPerkPre(int client, int& level, char[] perk, int maxlen);

/**
 * @brief 但玩家获得技能后触发
 * @remarks 失去技能也会触发
 *
 * @param client				玩家索引
 * @param level					技能等级
 * @param perk					技能类名
 */
forward void L4D2SF_OnPerkPost(int client, int level, const char[] perk);

/**
 * @brief 玩家加载完成后触发
 *
 * @param client				玩家索引
 */
forward void L4D2SF_OnLoad(int client);

/**
 * @brief 玩家准备保存时触发
 *
 * @param client				玩家索引
 */
forward void L4D2SF_OnSave(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_skillframework_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2SF_RegSlot");
	MarkNativeAsOptional("L4D2SF_RegPerk");
	MarkNativeAsOptional("L4D2SF_FindPerk");
	MarkNativeAsOptional("L4D2SF_GivePerk");
	MarkNativeAsOptional("L4D2SF_GetClientPerk");
	MarkNativeAsOptional("L4D2SF_GiveSkillExperience");
	MarkNativeAsOptional("L4D2SF_GetSkillExperience");
	MarkNativeAsOptional("L4D2SF_GetExperience");
	MarkNativeAsOptional("L4D2SF_GetSkillLevel");
	MarkNativeAsOptional("L4D2SF_GetLevel");
	MarkNativeAsOptional("L4D2SF_GiveSkillLevel");
	MarkNativeAsOptional("L4D2SF_GiveLevel");
	MarkNativeAsOptional("L4D2SF_GetAllPerks");
	MarkNativeAsOptional("L4D2SF_GivePoint");
	MarkNativeAsOptional("L4D2SF_GetPoint");
	MarkNativeAsOptional("L4D2SF_GetAllSlots");
	MarkNativeAsOptional("L4D2SF_SlotNameToSlotId");
	MarkNativeAsOptional("L4D2SF_SlotIdToSlotName");
	MarkNativeAsOptional("L4D2SF_GetSlotName");
	MarkNativeAsOptional("L4D2SF_GetPerkName");
	MarkNativeAsOptional("L4D2SF_GetPerkDescription");
	MarkNativeAsOptional("L4D2SF_GetPerkAccess");
}
#endif // REQUIRE_PLUGIN
