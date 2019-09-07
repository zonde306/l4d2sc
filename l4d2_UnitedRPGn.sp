#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <adminmenu>
//#include <l4d2_InfectedSpawnApi>

#define PLUGIN_VERSION "2.5"

public Plugin:myinfo=
{
	name = "玩家统计",
	author = "zonde306",
	description = "none",
	version = "1.0",
	url = ""
};

#define ENABLE_SQL false		// 是否使用数据库的方式来存档

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY
#define COMMAND_FILTER COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

/* Annonce */
#define MSG_VERSION			"{olive}插件版本版本 {green}%s"
#define MSG_PlayerInfo		"{lightgreen}你当前等级:{green} Lv.%d, {lightgreen}金钱:{green} $%d\n{lightgreen}力量: {green}%d, {lightgreen}敏捷: {green}%d, {lightgreen}生命: {green}%d, {lightgreen}耐力: {green}%d, {lightgreen}智力: {green}%d"
#define MSG_LEVEL_UP_1		"{green}[升级] {lightgreen}你现在的等级是{green}Lv.%d{lightgreen}你获得了{green}%d属性点{lightgreen}, {green}%d技能点{lightgreen}和{green}$%d"
#define MSG_LEVEL_UP_2		"{green}[升级] {lightgreen}输入{olive}!rpg{lightgreen}打开{olive}RPG{lightgreen}主选单增加你的属性/学习技能等"
#define MSG_WELCOME1		"{blue}欢迎{green}%N{blue}进入United RPG Server"
#define MSG_WELCOME2		"{blue}重要指令:!rpg/[小键盘+制] - 打开RPG主选单"
#define MSG_WELCOME3		"{blue}!jointeam1: {green}加入观察者阵营"
#define MSG_WELCOME4		"{blue}!jointeam2: {green}加入幸存者阵营{olive}, {blue}!jointeam3: {green}加入特殊感染者阵营"
/* Admin Gives */
#define MSG_ADMIN_GIVE_LV	"{teamcolor}管理员给予 {olive}%s {teamcolor}等级 {green}%d"
#define MSG_ADMIN_GIVE_EXP	"{teamcolor}管理员给予 {olive}%s {green}%d {teamcolor}EXP"
#define MSG_ADMIN_GIVE_CASH	"{teamcolor}管理员给予 {olive}%s {teamcolor}金钱 {green}$%d"
#define MSG_ADMIN_GIVE_KT	"{teamcolor}管理员给予 {olive}%s {teamcolor}大过 {green}%d"
/* Bind */
#define MSG_BIND_1			"\x03 快捷键已绑定完毕! 详细说明如下:"
#define	MSG_BIND_2			"\x04小键盘+\x05:RPG主选单 \x04小键盘-\x05:购物选单 \x04小键盘*\x05:技能选单 \x04小键盘/\x05:队伍资讯"
#define	MSG_BIND_3			"\x03═══════════\x04技能\x03═══════════"
#define	MSG_BIND_GENERAL	"\x04小键盘4\x05:治疗术 \x04小键盘5\x05:暂无 \x04小键盘6\x05:召唤术 \x04小键盘ENTER\x05:超级特感术"
#define	MSG_BIND_JOB1		"\x04小键盘7\x05:子弹制造术 \x04小键盘8\x05:卫星炮术"
#define	MSG_BIND_JOB2		"\x04小键盘7\x05:加速冲刺术 \x04小键盘8\x05:无限子弹术"
#define	MSG_BIND_JOB3		"\x04小键盘7\x05:无敌术 \x04小键盘8\x05:反伤术 \x04小键盘9\x05:近战嗜血术"
#define	MSG_BIND_JOB4		"\x04小键盘7\x05:选择传送术 \x04小键盘8\x05:目标传送术 \x04小键盘9\x05:心灵传送术"
#define	MSG_BIND_JOB4_1		"\x04小键盘1\x05:治疗光球术"
#define	MSG_BIND_JOB5		"\x04小键盘7\x05:火球术 \x04小键盘8\x05:冰球术 \x04小键盘9\x05:连锁闪电术"
/* Infected Exp */
#define MSG_SPITTER_SPIT				"{olive}Spitter {lightgreen} 酸液攻击 {olive}幸存者 {green}%d{lightgreen} 次获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_ANY_SI_ATTACK_SURVIVOR		"{lightgreen}持续攻击 {olive}幸存者 {green}%d{lightgreen} 次获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_SMOKER_GRABBED				"{olive}Smoker {lightgreen}拉住 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_HUNTER_POUNCED				"{olive}Hunter {lightgreen}突袭 {olive}幸存者 {lightgreen}, 给予了{green}%d{lightgreen}基础伤害, 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_BOOMER_VOMIT				"{olive}Boomer {lightgreen}呕吐物击中 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_CHARGER_GRABBED				"{olive}Charger {lightgreen}抓住 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_CHARGER_IMPACT				"{olive}Charger {lightgreen}撞开其他 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_JOCKEY_RIDE					"{olive}Jockey {lightgreen}骑中 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_TANK_CLAW					"{olive}Tank {lightgreen}爪击 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_TANK_ROCK					"{olive}Tank {lightgreen}投石击中 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_SURVIVOR_INCAPACITATED	"{lightgreen}成功制服 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_SURVIVOR_KILLED			"{lightgreen}成功杀死 {olive}幸存者 {lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_INFECTED_GOT_KILLED		"{lightgreen}给 {olive}幸存者 {lightgreen}击杀扣除{green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_ANY_IS_ATTACK_SURVIVOR		"{lightgreen}你召唤的尸持续攻击 {olive}幸存者 {green}%d次{lightgreen}获得 {green}%d{olive}EXP, {green}%d{olive}$"

/* Survivor Exp */
#define MSG_EXP_KILL_WITCH				"{lightgreen}击杀 {olive}Witch{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SMOKER				"{lightgreen}击杀 {olive}Smoker{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_BOOMER				"{lightgreen}击杀 {olive}Boomer{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_HUNTER				"{lightgreen}击杀 {olive}Hunter{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SPITTER			"{lightgreen}击杀 {olive}Spitter{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_JOCKEY				"{lightgreen}击杀 {olive}Jockey{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_CHARGER			"{lightgreen}击杀 {olive}Charger{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_SMOKER			"{lightgreen}击杀 {olive}超级Smoker{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_BOOMER			"{lightgreen}击杀 {olive}超级Boomer{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_HUNTER			"{lightgreen}击杀 {olive}超级Hunter{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_SPITTER			"{lightgreen}击杀 {olive}超级Spitter{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_JOCKEY			"{lightgreen}击杀 {olive}超级Jockey{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_SI_CHARGER			"{lightgreen}击杀 {olive}超级Charger{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define	MSG_EXP_FRUSTRATED_TANK			"{olive}Tank转手了! {lightgreen}你给予{olive}Tank {green}%d{lightgreen}伤害, 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define	MSG_EXP_KILL_TANK				"{olive}Tank死亡了! {lightgreen}你给予{olive}Tank {green}%d{lightgreen}伤害, 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_TANK_ALL			"{lightgreen}由於你在这场与 {olive}Tank{lightgreen} 的搏斗中得以幸存奖励 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_KILL_ZOMBIES			"{lightgreen}击杀 {green}%d{lightgreen} 丧尸获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_REVIVE					"{olive}拉起队友{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_REVIVE_JOB4				"{olive}拉起队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}, {green}%d{olive}${green}(额外+%d)"
#define MSG_EXP_DEFIBRILLATOR			"{olive}复活队友{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_DEFIBRILLATOR_JOB4		"{olive}复活队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}, {green}%d{olive}${green}(额外+%d)"
#define MSG_EXP_HEAL_SUCCESS			"{olive}治疗队友{lightgreen} 获得 {green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_HEAL_SUCCESS_JOB4		"{olive}治疗队友{lightgreen} 获得 {green}%d{lightgreen}EXP{green}(额外+%d){lightgreen}, {green}%d{olive}${green}(额外+%d)"
#define MSG_EXP_KILL_TEAMMATE			"{green}%N {teamcolor}太惨无人道了,居然残害队友!! 记大过第{green} %d {teamcolor}次,扣除 {green}%d{olive}EXP, {green}%d{olive}$!"
#define MSG_EXP_SURVIVOR_GOT_INCAPPED	"{lightgreen}作为 {olive}幸存者 {lightgreen}的你倒下扣除{green}%d{olive}EXP, {green}%d{olive}$"
#define MSG_EXP_SURVIVOR_GOT_KILLED		"{lightgreen}作为 {olive}幸存者 {lightgreen}的你死亡扣除{green}%d{olive}EXP, {green}%d{olive}$"
/* Kill TeammateKilledExp */
#define MSG_KT_WARNING_1			"{green}警告!! {lightgreen}大过累计达{green} %d {lightgreen}次以上将无法转职!!"
#define MSG_KT_WARNING_2			"{green}警告!! {lightgreen}大过累计已达{green} %d {lightgreen}次,你将无法转职!! 如想洗清罪孽请{green}Lv.20{lightgreen}之后洗点!!"
#define MSG_KT_WARNING_3			"{green}警告!! {lightgreen}大过累计已达{green} %d {lightgreen}次,系统自动帮你降{green}10{lightgreen}级,并初始化属性/技能"
/* Other */
#define MSG_LACK_POINTS				"你已经没有属性点可以使用了!"
#define MSG_LACK_SKILLS				"你已经没有技能点可以使用了!"
#define MSG_PLAYER_DIE				"抱歉,死亡状态下无法使用技能!"
#define MSG_StAtUS_UP_FAIL			"加点失败! 属性点餘额不足!! 当前:%d, 所需:%d"
#define MSG_INVALID_ARG				"{green}参数无效!{olive}请输入一个大于零的正数!"
/* Need Job & Skill */
#define MSG_NEED_JOB1			"你没有转职工程师!"
#define MSG_NEED_JOB2			"你没有转职士兵!"
#define MSG_NEED_JOB3			"你没有转职生物专家!"
#define MSG_NEED_JOB4			"你没有转职心灵医师!"
#define MSG_NEED_JOB5			"你没有转职魔法师!"
#define MSG_NEED_SKILL_1		"你没有学习治疗术!"
#define MSG_NEED_SKILL_2		"你没有学习强化甦醒术!"
#define MSG_NEED_SKILL_3		"你没有学习子弹制造术!"
#define MSG_NEED_SKILL_4		"你没有学习加速冲刺术!"
#define MSG_NEED_SKILL_5		"你没有学习无限子弹术!"
#define MSG_NEED_SKILL_6		"你没有学习无敌术!"
#define MSG_NEED_SKILL_7		"你没有学习选择传送术!"
#define MSG_NEED_SKILL_8		"你没有学习目标传送术!"
#define MSG_NEED_SKILL_9		"你没有学习心灵传送术!"
#define MSG_NEED_SKILL_10		"你没有学习反伤术!"
#define MSG_NEED_SKILL_11		"你没有学习近战嗜血术!"
#define MSG_NEED_SKILL_12		"你没有学习超级特感术!"
#define MSG_NEED_SKILL_13		"你没有学习召唤术!"
#define MSG_NEED_SKILL_14		"你没有学习卫星炮术!"
#define MSG_NEED_SKILL_15		"你没有学习火球术!"
#define MSG_NEED_SKILL_16		"你没有学习冰球术!"
#define MSG_NEED_SKILL_17		"你没有学习连锁闪电术!"
#define MSG_NEED_SKILL_18		"你没有学习治疗光球术!"
/* Skills */
#define MSG_SKILL_LACK_MP				"[技能] 你的MP不足够发动技能!需要MP: %d, 现在MP: %d"
#define MSG_SKILL_HL_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的治疗术!"
#define MSG_SKILL_HL_ENABLED			"{olive}[技能] {green}治疗术{blue}启动中!"
#define MSG_SKILL_HL_END				"{olive}[技能] {green}治疗术{blue}结束了!"
#define MSG_SKILL_AM_ANNOUNCE			"{olive}[技能] 使用了{green}Lv.%d{blue}的子弹制造技术制造了{green}%d发{blue}子弹!"
#define MSG_SKILL_AM_NOGUN				"{olive}[技能] {green}你没有枪械!"
#define MSG_SKILL_SC_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}卫星炮术{blue}!"
#define MSG_SKILL_SC_CHARGED			"{olive}[技能] {green}卫星炮术{blue}冷却完成!"
#define MSG_SKILL_SC_TK					"{olive}[技能] {green}%N{blue}的{green}卫星炮术{blue}杀了队友{green}%N{blue}! 扣除{green}%d{olive}EXP{blue}, {green}%d{olive}$"
#define MSG_SKILL_SP_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}加速冲刺术{blue}!"
#define MSG_SKILL_SP_ENABLED			"{olive}[技能] {green}加速冲刺术{blue}启动中!"
#define MSG_SKILL_SP_END				"{olive}[技能] {green}加速冲刺术{blue}结束了!"
#define MSG_SKILL_IA_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}无限子弹术{blue}!"
#define MSG_SKILL_IA_ENABLED			"{olive}[技能] {green}无限子弹术{blue}启动中!"
#define MSG_SKILL_IA_END				"{olive}[技能] {green}无限子弹术{blue}结束了!"
#define MSG_SKILL_BS_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{green}无敌术{blue},已进入无敌状态!"
#define MSG_SKILL_BS_ENABLED			"{olive}[技能] {green}无敌术{blue}启动中!"
#define MSG_SKILL_BS_END				"{olive}[技能] {green}无敌术{blue}结束了! 无敌效果消失!"
#define MSG_SKILL_BS_CHARGED			"{olive}[技能] {green}无敌术{blue}冷却完成!"
#define MSG_SKILL_BS_NO_SKILL			"{olive}[技能] {green}无敌术{blue}使用期间不能使用其他技能!"
#define MSG_SKILL_BS_NEED_HP			"{olive}[技能] {blue}你的血量不足够用来发动无敌术!"
#define MSG_SKILL_TC_ANNOUNCE			"{olive}[技能] 使用了心灵传输到了队友{green}%N{blue}的身边!"
#define MSG_SKILL_TC_ANNOUNCE2			"{olive}[技能] 使用了心灵传输到了队友{green}%N{blue}的尸体旁!"
#define MSG_SKILL_TC_CHARGED			"{olive}[技能] {green}选择传送术{blue}冷却完成!"
#define MSG_SKILL_AT_ANNOUNCE			"{olive}[技能] 使用了心灵传输到了想去的地方!"
#define MSG_SKILL_TT_ANNOUNCE			"{olive}[技能] 使用了心灵传输使所有队友回到你的身边!"
#define MSG_SKILL_TT_ANNOUNCE_2			"{olive}[技能] 使用了心灵传输使队友{green}%N{blue}回到你的身边!"
#define MSG_SKILL_TT_CHARGED			"{olive}[技能] {green}心灵传送术{blue}冷却完成!"
#define MSG_SKILL_TT_ON_GROUND 			"{olive}[技能] {green}為了防止集体跳河自杀,此技能只能在地面上使用!"
#define MSG_SKILL_HB_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}治疗光球术{blue}!"
#define MSG_SKILL_HB_ENABLED			"{olive}[技能] {green}治疗光球术{blue}启动中!"
#define MSG_SKILL_HB_END				"{olive}[技能] {green}治疗光球术{blue}结束了! 你总共治疗了队友{green}%d{olive}HP, 你获得{green}%d{olive}Exp{blue}, {green}%d{olive}$"
#define MSG_SKILL_DR_ANNOUNCE			"{olive}[技能] 消耗了自身的{green}%dHP{blue}去启动{green}Lv.%d{blue}的{olive}反伤术{blue}!"
#define MSG_SKILL_DR_ENABLED			"{olive}[技能] {green}反伤术{blue}启动中!"
#define MSG_SKILL_DR_NEED_HP			"{olive}[技能] {green}你的血量不足够用来发动反伤术!"
#define MSG_SKILL_DR_END				"{olive}[技能] {green}反伤术{blue}失效了!"
#define MSG_SKILL_MS_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}近战嗜血术{blue}!"
#define MSG_SKILL_MS_ENABLED			"{olive}[技能] {green}近战嗜血术{blue}启动中!"
#define MSG_SKILL_MS_END				"{olive}[技能] {green}近战嗜血术{blue}结束了!"
#define MSG_SKILL_FB_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}火球术{blue}!"
#define MSG_SKILL_IB_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}冰球术{blue}!"
#define MSG_SKILL_CL_ANNOUNCE			"{olive}[技能] 启动了{green}Lv.%d{blue}的{olive}连锁闪电术{blue}!"
#define MSG_SKILL_RG_START				"{olive}[技能] {blue}生命开始再生!"
#define MSG_SKILL_RG_FULLHP				"{olive}[技能] {blue}生命已完全再生!"
#define MSG_SKILL_RG_STOP				"{olive}[技能] {blue}受到攻击，再生停止!"
#define MSG_SKILL_SI_CANNOT_TANK		"{olive}[技能] {blue}Tank不能变超级!"
#define MSG_SKILL_SI_CANNOT_GHOST		"{olive}[技能] {blue}重生后才能变超级!"
#define MSG_SKILL_SI_ALREADY			"{olive}[技能] {blue}你已是超级特感!"
#define MSG_SKILL_SI_ANNOUNCE			"{olive}[技能] 你已变成{olive}超级%s{blue}! 超级特感能力可维持{green}%.2f{blue}秒!"
#define MSG_SKILL_SI_STOP				"{olive}[技能] {blue}你的超级特感能力已用完!"
#define MSG_SKILL_IS_CANNOT_GHOST		"{olive}[技能] {blue}重生后才能召唤!"
#define MSG_SKILL_IS_KILLED				"{olive}[技能] {blue}你的{green}%d{blue}个召唤尸给杀死了!"
#define MSG_SKILL_IS_DISAPPEAR			"{olive}[技能] {blue}你的{green}%d{blue}个召唤尸消失了!"
#define MSG_SKILL_IS_WITCH_ANNOUNCE		"{olive}[技能] 召唤了{green}Witch{blue}!"
#define MSG_SKILL_IS_WITCH_KILLED		"{olive}[技能] {blue}你召唤的{green}Witch{blue}给杀死了!"
#define MSG_SKILL_IS_WITCH_DISAPPEAR	"{olive}[技能] {blue}你召唤的{green}Witch{blue}消失了!"
#define MSG_SKILL_IS_COUNT_MAX			"{olive}[技能] {blue}召唤数量已达%d上限!"
#define MSG_SKILL_USE_SURVIVORS_ONLY	"{olive}[技能] {blue}该技能仅限幸存者使用!"
#define MSG_SKILL_USE_INFECTED_ONLY		"{olive}[技能] {blue}该技能仅限感染者使用!"
#define MSG_SKILL_CHARGING				"{olive}[技能] {blue}技能正在冷却, 请稍后!"
/* Status */
#define MSG_ADD_STATUS_STR			"{lightgreen}[属性] {olive}力量{lightgreen}变为{green}%d{lightgreen}, {olive}伤害{lightgreen}增加:{green}%.2f%%"
#define MSG_ADD_STATUS_AGI			"{lightgreen}[属性] {olive}敏捷{lightgreen}变为{green}%d{lightgreen}, {olive}移动速度{lightgreen}增加:{green}%.2f%%"
#define MSG_ADD_STATUS_HEALTH		"{lightgreen}[属性] {olive}生命{lightgreen}变为{green}%d{lightgreen}, {olive}生命值上限{lightgreen}增加:{green}%.2f%%"
#define MSG_ADD_STATUS_ENDURANCE	"{lightgreen}[属性] {olive}耐力{lightgreen}变为{green}%d{lightgreen}, {olive}伤害{lightgreen}减少:{green}%.2f%%"
#define MSG_ADD_STATUS_INTELLIGENCE	"{lightgreen}[属性] {olive}智力{lightgreen}变为{green}%d{lightgreen}, {olive}MP上限{lightgreen}增加至{green}%d{lightgreen}, 每秒恢复{green}%d{lightgreen}MP\n{lightgreen}[属性] 死亡扣取的经验值和金钱减少!"
#define MSG_ADD_STATUS_MAX			"属性点增加已到达上限 %d!"
/* Learn Skills */
#define MSG_ADD_SKILL_TT_NEED			"目标传送术和选择传送术必须达到满级才能学习此技能!"
#define MSG_ADD_SKILL_HL				"{olive}[技能] {green}治疗术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_HL_LEVEL_MAX		"{olive}[技能] {green}治疗术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_EQ				"{olive}[技能] {green}强化甦醒术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_EQ_LEVEL_MAX		"{olive}[技能] {green}强化甦醒术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_AM				"{olive}[技能] {green}子弹制造术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_AM_LEVEL_MAX		"{olive}[技能] {green}子弹制造术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_SC				"{olive}[技能] {green}卫星炮术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_SC_LEVEL_MAX		"{olive}[技能] {green}卫星炮术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_EE				"{olive}[被动技能] {green}攻防强化术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_EE_LEVEL_MAX		"{olive}[技能] {green}攻防强化术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_SP				"{olive}[技能] {green}加速冲刺术{lightgreen}等级变为 {green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_SP_LEVEL_MAX		"{olive}[技能] {green}加速冲刺术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_IA				"{olive}[技能] {green}无限子弹术{lightgreen}等级变为 {green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_IA_LEVEL_MAX		"{olive}[技能] {green}无限子弹术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_BS				"{olive}[技能] {green}无敌术{lightgreen}等级变为 {green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_BS_LEVEL_MAX		"{olive}[技能] {green}无敌术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_DR				"{olive}[技能] {green}反伤术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_DR_LEVEL_MAX		"{olive}[技能] {green}反伤术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_MS				"{olive}[技能] {green}近战嗜血术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_MS_LEVEL_MAX		"{olive}[技能] {green}近战嗜血术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_FS				"{olive}[被动技能] {green}射速已加强术{lightgreen}等级变为 {green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_FS_LEVEL_MAX		"{olive}[被动技能] {green}射速加强术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_TS				"{olive}[技能] {green}选择传送术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_TS_LEVEL_MAX		"{olive}[技能] {green}选择传送术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_AT				"{olive}[技能] {green}目标传送术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_AT_LEVEL_MAX		"{olive}[技能] {green}目标传送术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_TT				"{olive}[技能] {green}心灵传送术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_TT_LEVEL_MAX		"{olive}[技能] {green}心灵传送术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_HB				"{olive}[技能] {green}治疗光球术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_HB_LEVEL_MAX		"{olive}[技能] {green}治疗光球术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_FB				"{olive}[技能] {green}火球术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_FB_LEVEL_MAX		"{olive}[技能] {green}火球术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_IB				"{olive}[技能] {green}冰球术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_IB_LEVEL_MAX		"{olive}[技能] {green}冰球术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_CL				"{olive}[技能] {green}连锁闪电术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_CL_LEVEL_MAX		"{olive}[技能] {green}连锁闪电术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_RG				"{olive}[被动技能] {green}再生术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_RG_LEVEL_MAX		"{olive}[被动技能] {green}再生术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_SI				"{olive}[被动] {green}超级特感术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_SI_LEVEL_MAX		"{olive}[被动] {green}超级特感术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_IS				"{olive}[技能] {green}召唤术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_IS_LEVEL_MAX		"{olive}[技能] {green}召唤术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_HSP				"{olive}[技能] {green}飞扑爆击术{lightgreen}等级变为{green}Lv.%d{lightgreen}"
#define MSG_ADD_SKILL_HSP_LEVEL_MAX		"{olive}[技能] {green}飞扑爆击术{lightgreen}等级已达上限!"
#define MSG_ADD_SKILL_NeedNewLife		"{olive}[技能] {lightgreen}此技能需要{green}转生{lightgreen}后才能学习!"
/* Choose Jobs */
#define MSG_ZZ_FAIL_KT					"{red}罪孽太深,不允许转职!"
#define MSG_ZZ_FAIL_JCB_TURE 			"{olive}转职失败! {lightgreen}普通玩家只能获得一个职业!"
#define MSG_ZZ_FAIL_NEED_STATUS 		"{olive}转职失败! {lightgreen}所需的属性点不足!"
#define MSG_ZZ_FAIL_NEED_NEWLIFE		"{olive}转职失败! {lightgreen}你需要转生才可选择这个职业!"
#define MSG_ZZ_FAIL_SHOW_STATUS 		"{lightgreen}你当前的: 力量:{green}%d{lightgreen},  敏捷:{green}%d{lightgreen},  生命:{green}%d{lightgreen},  耐力:{green}%d{lightgreen},  智力:{green}%d"
#define MSG_ZZ_FAIL_JOB_NEED			"{olive}转职所需: 力量:{green}%d{olive},  敏捷:{green}%d{olive},  生命:{green}%d{olive},  耐力:{green}%d{olive},  智力:{green}%d"
#define MSG_ZZ_SUCCESS_JOB1_ANNOUNCE	"{olive}[转职] {olive}恭喜玩家{lightgreen}%N{olive}成功转职{green}工程师"
#define MSG_ZZ_SUCCESS_JOB2_ANNOUNCE	"{olive}[转职] {olive}恭喜玩家{lightgreen}%N{olive}成功转职{green}士兵"
#define MSG_ZZ_SUCCESS_JOB3_ANNOUNCE	"{olive}[转职] {olive}恭喜玩家{lightgreen}%N{olive}成功转职{green}生物专家"
#define MSG_ZZ_SUCCESS_JOB4_ANNOUNCE	"{olive}[转职] {olive}恭喜玩家{lightgreen}%N{olive}成功转职{green}心灵医师"
#define MSG_ZZ_SUCCESS_JOB5_ANNOUNCE	"{olive}[转职] {olive}恭喜玩家{lightgreen}%N{olive}成功转职{green}魔法师"
#define MSG_ZZ_SUCCESS_JOB1_REWARD		"{olive}[转职属性奖励] 力量{green} 10 {lightgreen}, 耐力{green} 10 {lightgreen}, 智力{green} 10 {lightgreen}增加↑"
#define MSG_ZZ_SUCCESS_JOB2_REWARD		"{olive}[转职属性奖励] 力量{green} 10 {lightgreen}, 敏捷{green} 10 {lightgreen}, 生命{green} 10 {lightgreen}增加↑"
#define MSG_ZZ_SUCCESS_JOB3_REWARD		"{olive}[转职属性奖励] 力量{green} 10 {lightgreen}, 生命{green} 10 {lightgreen}, 智力{green} 10 {lightgreen}增加↑"
#define MSG_ZZ_SUCCESS_JOB4_REWARD		"{olive}[转职属性奖励] 力量{green} 10 {lightgreen}, 生命{green} 10 {lightgreen}, 耐力{green} 10 {lightgreen}增加↑"
#define MSG_ZZ_SUCCESS_JOB5_REWARD		"{olive}[转职属性奖励] 力量{green} 10 {lightgreen}, 生命{green} 10 {lightgreen}, 智力{green} 10 {lightgreen}增加↑"
/* Reset Status & Jobs & KT */
#define MSG_XD_SUCCESS			"{teamcolor}玩家 {green}%N {teamcolor}已成功洗点!"
#define MSG_XD_SUCCESS_SHOP		"{teamcolor}玩家 {green}%N {teamcolor}使用遗忘河药水成功洗点!"
#define MSG_XD_SUCCESS_ADMIN	"{teamcolor}管理员已帮助玩家 {olive}%N {teamcolor}洗点!"
#define MSG_XD_KT_REMOVE		"{blue}已消除大过,记得以后不要伤害队友喔~"
#define MSG_BUYSUCC				"{olive}购买成功! {lightgreen}支出: {green}%d${lightgreen} 剩余金钱: {green}%d$"
#define MSG_BUYFAIL				"{olive}购买失败! {lightgreen}需要: {green}%d${lightgreen} 现有金钱: {green}%d$"
#define MSG_RecycleSUCC			"{olive}彩票回收成功! {lightgreen}获得: {green}%i${lightgreen}(税:{green}%i{lightgreen}) 剩余金钱: {green}%d$"
#define MSG_ROBOT_UPGRADE_MAX	"{lightgreen}此项Robot升级已达最高等级!"
/* 对抗奖励系统 */
#define MSG_VERSUS_SCORE_CHANGE_TEAM_SECONDLEFT	"{lightgreen}转换队伍时间剩余{green}%d{lightgreen}秒!"
#define MSG_VERSUS_SCORE_CHANGE_TEAM_TIMESUP	"{olive}转换队伍时间够了! {lightgreen}直至下一张地图為止, 你不能转换队伍!"
#define MSG_VERSUS_SCORE_TEAM_A_SRORE			"{lightgreen}你的队伍获得{green}%d{lightgreen}积分, 如你的积分高过敌方队伍, 你将获得一些经验值和金钱!"
#define MSG_VERSUS_SCORE_TEAM_B_SRORE			"{lightgreen}敌方队伍获得{green}%d{lightgreen}积分, 如你的积分高过敌方队伍, 你将获得一些经验值和金钱!"
#define MSG_VERSUS_SCORE_EXPLAIN				"{lightgreen}经验值是根据相方积分差距乘{green}%d{lightgreen}和你在地图参与时间，金钱是经验除{green}10{lightgreen}"
#define MSG_VERSUS_SCORE_TEAM_SRORE				"{lightgreen}你的队伍获得{green}%d{lightgreen}积分, 敌方队伍获得{green}%d{lightgreen}积分"
#define MSG_VERSUS_SCORE_TEAM_SPECTATORS_SRORE	"{lightgreen}幸存者阵营分数為{green}%d{lightgreen}, 特殊感染者阵营分数為{green}%d{lightgreen}"
#define MSG_VERSUS_SCORE_TEAM_WIN				"{olive}恭喜! {lightgreen}你的队伍的积分高於敌方队伍, 你贡献了{green}%.2f%%{lightgreen}时间, 将获得{green}%d{lightgreen}经验值和{green}%d{lightgreen}金钱!"
#define MSG_VERSUS_SCORE_TEAM_LOSS				"{olive}对不起! {lightgreen}你的队伍的积分低於敌方队伍, 敌方将获得一些经验值和金钱!"
#define MSG_VERSUS_SCORE_TEAM_DRAW				"{lightgreen}两队积分打平!"
/* 密码系统 */
#define MSG_PASSWORD_NOTACTIVATED			"{olive}[密码] {blue}你的密码尚未启动! 请打[/rpgpw 密码]设置并启动密码!\n注意: 密码请不要用数字0开头，会被略去的!"
#define MSG_PASSWORD_EXPLAIN				"{olive}[密码] {blue}请打[!rpgpwinfo]查看密码系统说明!"
#define MSG_PASSWORD_NOTCONFIRM				"{olive}[密码] {blue}你尚未输入密码! 请打[/rpgpw 密码]输入密码!"
#define MSG_PASSWORD_INCORRECT				"{olive}[密码] {blue}你输入的密码不正确!"
#define MSG_ENTERPASSWORD_ALREADYCONFIRM	"{olive}[密码] {blue}你已输入密码!"
#define MSG_ENTERPASSWORD_ACTIVATED			"{olive}[密码] {blue}你的密码已成功启动! 你的密码为{green}%s"
#define MSG_ENTERPASSWORD_BLIND				"{olive}[密码] {blue}你不能输入空白的密码!"
#define MSG_ENTERPASSWORD_CORRECT			"{olive}[密码] {blue}密码正确! 记录己读取!"
#define MSG_RESETPASSWORD_RESETED			"{olive}[密码] {blue}密码已经重新设定!"
/* 伤害显示 */
#define MSG_DAMAGEDISPLAY			"造成 %d 伤害"
#define MSG_DAMAGEDISPLAY_DEAD		"造成 %d 伤害 (击杀)"
#define MSG_DAMAGEDISPLAY_HEADSHOT	"造成 %d 伤害 (爆头)"
#define MSG_TANK_HEALTH_REMAIN		"魔王坦克(第%d型态 控制者: %N) 生命值: %d (累积伤害: %d)"
/* Witch尖叫引来尸群 */
#define MSG_WITCH_HARASSERSET_SET_PANIC	"{green}%N{blue}惊吓了{green}Witch{blue}! 尖叫将引来尸群!"
#define MSG_WITCH_KILLED_PANIC			"{green}%N{blue}杀死了{green}Witch{blue}! 尖叫将引来尸群!"
#define MSG_WitchAdd					"幸存者阵营总等级(Lv. %d)多於特殊感染者阵营(Lv. %d), 增加%d隻Witch!"
/* 玩家加入和转队讯息 */
#define MSG_PLAYER_CONNECT				"{green}%N{blue}连接游戏!"
#define MSG_PLAYER_JOIN_TEAM1			"{green}%N{blue}加入观察者阵营!"
#define MSG_PLAYER_JOIN_TEAM2			"{green}%N{blue}加入幸存者阵营!"
#define MSG_PLAYER_JOIN_TEAM3			"{green}%N{blue}加入特殊感染者阵营!"
/* 玩家改名 */
#define MESSAGE_CHANGENAME			"{blue}你的能力被初始化了, 请重新输入密码读取存档(如有)!"
/* 玩家转生 */
#define MSG_NL_SUCCESS				"{olive}[转生] {olive}恭喜玩家{lightgreen}%N{olive}成功{green}转生"
#define MSG_NL_NEED_LV				"{lightgreen}你需要有Lv.{green}%d{lightgreen}或以上才能转生!"
/* 其他 */
#define MSG_VersusMarkerReached		"%s 带领大家完成了{green} %d%% {default}路程!"

/*** 玩家基本资料 ***/
new Lv[MAXPLAYERS+1];
new EXP[MAXPLAYERS+1];
new Cash[MAXPLAYERS+1];
new MP[MAXPLAYERS+1];
#define KTLimit 5	//TK上限
new KTCount[MAXPLAYERS+1];	//误杀队友统计
new NewLifeCount[MAXPLAYERS+1];	//转生次数
new Handle:NewLifeLv;	//转生最低等级要求
#define PasswordRemindSecond 60	//密码提示间隔
#define PasswordLength 64	//最大密码长度
new String:Password[MAXPLAYERS+1][PasswordLength];
new bool:IsPasswordConfirm[MAXPLAYERS+1]	= {	false, ...};
new PasswordRemindTime[MAXPLAYERS+1];
new bool:HasGetBuJi[MAXPLAYERS+1] = true;

/*** 玩家属性 ****/
new Str[MAXPLAYERS+1];
new Agi[MAXPLAYERS+1];
new Health[MAXPLAYERS+1];
new Endurance[MAXPLAYERS+1];
new Intelligence[MAXPLAYERS+1];
new SkillPoint[MAXPLAYERS+1];
new StatusPoint[MAXPLAYERS+1];
/*** 特殊力量 ****/
new Lis[MAXPLAYERS+1];

new Qgl[MAXPLAYERS+1];	//成功率
new Shitou[MAXPLAYERS+1]; //强化石
new Shilv[MAXPLAYERS+1]; //强化等级
new Qstr[MAXPLAYERS+1]; //强化攻击

/*** 背包系统 ****/
new Baoshu[MAXPLAYERS+1]; //腺上激素
new Baoliao[MAXPLAYERS+1]; //医疗包
new Baojia[MAXPLAYERS+1]; //弹夹
new Baozhan[MAXPLAYERS+1]; //棒球棍
new Baoxie[MAXPLAYERS+1]; //AK47
new Baodian[MAXPLAYERS+1]; //电机器
/****** 特感宝盒 ******/
new WLBH[MAXPLAYERS+1]; //特感宝盒
new AXP[MAXPLAYERS+1]; //A芯片系统

/** 属性上限 **/
#define Limit_Str 1000
#define Limit_Agi 500
#define Limit_Health 1000
#define Limit_Endurance 1000
#define Limit_Intelligence 500
/** 属性效能 **/
#define Effect_Str 0.005
#define Effect_Agi 0.0025
#define Effect_Health 0.01
#define Effect_Endurance 0.005
#define Effect_MaxEndurance 0.5
#define BasicIMP 100
#define BasicMaxMP 30000
/** 属性效果 **/
#define StrEffect[%1]				Str[%1]*(1+Lis[%1])*Effect_Str
#define AgiEffect[%1]				Agi[%1]*(1+Lis[%1])*Effect_Agi
#define HealthEffect[%1]			Health[%1]*(1+Lis[%1])*Effect_Health
#define EnduranceEffect[%1]			Endurance[%1]*(1+Lis[%1])*Effect_Endurance
#define IntelligenceEffect_IMP[%1]	BasicIMP + Lv[%1] + Intelligence[%1]/2 *(1+Lis[%1])
#define MaxMP[%1]					BasicMaxMP + 250*(Lv[%1] + Intelligence[%1]) *(1+Lis[%1])

/**** 幸存者职业和技能 ****/

/*** 幸存者通用技能 ***/
/** 治疗术 **/
new HealingLv[MAXPLAYERS+1];
new HealingCounter[MAXPLAYERS+1];
/** 强化甦醒术 **/
new EndranceQualityLv[MAXPLAYERS+1];
/*** 职业基本资料 ***/
new bool:JobChooseBool[MAXPLAYERS+1];
new JD[MAXPLAYERS+1] = {0, ...};

/** 工程师 **/
/* 职业属性需求 */
#define JOB1_Str 15
#define JOB1_Agi 15
#define JOB1_Health 15
#define JOB1_Endurance 15
#define JOB1_Intelligence 40
/* 子弹制造术 */
new AmmoMakingLv[MAXPLAYERS+1];
/* 射速加强术 */
new FireSpeedLv[MAXPLAYERS+1];
/* 卫星炮术 */
new bool:IsSatelliteCannonReady[MAXPLAYERS+1];
new SatelliteCannonLv[MAXPLAYERS+1];
#define SatelliteCannon_Sound_Launch		"animation/bombing_run_01.wav"

/** 士兵 **/
/* 职业属性需求 */
#define JOB2_Str 35
#define JOB2_Agi 10
#define JOB2_Health 10
#define JOB2_Endurance 35
#define JOB2_Intelligence 10
/* 攻防强化术 */
new EnergyEnhanceLv[MAXPLAYERS+1];
/* 加速冲刺术 */
new SprintLv[MAXPLAYERS+1];
new bool:IsSprintEnable[MAXPLAYERS+1];
/* 无限子弹术 */
new bool:IsInfiniteAmmoEnable[MAXPLAYERS+1];
new InfiniteAmmoLv[MAXPLAYERS+1];

/** 生物专家 **/
/* 职业属性需求 */
#define JOB3_Str 10
#define JOB3_Agi 35
#define JOB3_Health 10
#define JOB3_Endurance 10
#define JOB3_Intelligence 35
/* 无敌术 */
new BioShieldLv[MAXPLAYERS+1];
new bool:IsBioShieldEnable[MAXPLAYERS+1];
new bool:IsBioShieldReady[MAXPLAYERS+1];
/* 反伤术 */
new DamageReflectLv[MAXPLAYERS+1];
new bool:IsDamageReflectEnable[MAXPLAYERS+1];
/* 近战嗜血术 */
new MeleeSpeedLv[MAXPLAYERS+1];
new bool:IsMeleeSpeedEnable[MAXPLAYERS+1];


/* 武器速度 */
new WRQ[MAXPLAYERS+1];
new WRQL;
new Float:Multi[MAXPLAYERS+1];

/** 心灵医师 **/
/* 职业属性需求 */
#define JOB4_Str 5
#define JOB4_Agi 30
#define JOB4_Health 30
#define JOB4_Endurance 5
#define JOB4_Intelligence 30
/* 选择传送术 */
new TeleportToSelectLv[MAXPLAYERS+1];
new bool:IsTeleportToSelectEnable[MAXPLAYERS+1];
/* 目标传送术 */
new AppointTeleportLv[MAXPLAYERS+1];
new bool:IsAppointTeleportEnable[MAXPLAYERS+1];
/* 心灵传送术 */
new TeleportTeamLv[MAXPLAYERS+1];
new bool:IsTeleportTeamEnable[MAXPLAYERS+1];
new defibrillator[MAXPLAYERS+1];
/* 心灵传送模式 */
new Handle:TeleportTeam_Mode;
/* 治疗光球术 */
new HealingBallLv[MAXPLAYERS+1];
new HealingBallExp[MAXPLAYERS+1];
new bool:IsHealingBallEnable[MAXPLAYERS+1];
new Handle:HealingBallTimer[MAXPLAYERS+1];
//#define HealingBall_Particle			"st_elmos_fire_cp0"
#define HealingBall_Particle_Effect	"st_elmos_fire_cp0"
#define HealingBall_Sound_Lanuch	"ambient/fire/gascan_ignite1.wav"
#define HealingBall_Sound_Heal		"buttons/bell1.wav"

/** 魔法师 **/
/* 职业属性需求 */
#define JOB5_Str 5
#define JOB5_Agi 5
#define JOB5_Health 5
#define JOB5_Endurance 5
#define JOB5_Intelligence 80
/* 火球术 */
new FireBallLv[MAXPLAYERS+1];
#define FireBall_Model				"models/props_unique/airport/atlas_break_ball.mdl"
#define FireBall_Sound_Impact01		"ambient/fire/gascan_ignite1.wav"
#define FireBall_Sound_Impact02		"ambient/atmosphere/firewerks_burst_01.wav"
#define FireBall_Particle_Fire01	"molotov_explosion"
#define FireBall_Particle_Fire02	"gas_explosion_fireball2"
#define FireBall_Particle_Fire03	"fire_small_03"
/* 冰球术 */
new IceBallLv[MAXPLAYERS+1];
new bool:IsFreeze[MAXPLAYERS+1];
#define IceBall_Sound_Impact01		"animation/van_inside_hit_wall.wav"
#define IceBall_Sound_Impact02		"ambient/explosions/explode_3.wav"
#define IceBall_Sound_Freeze		"physics/glass/glass_pottery_break3.wav"
#define IceBall_Sound_Defrost		"physics/glass/glass_sheet_break1.wav"
#define IceBall_Particle_Ice01		"pillardust_highrise"
/* 连锁闪电术 */
new ChainLightningLv[MAXPLAYERS+1];
new bool:IsChained[MAXPLAYERS+1];
#define ChainLightning_Sound_launch		"ambient/energy/zap1.wav"
#define ChainLightning_Particle_hit		"electrical_arc_01_system"

/**** 特殊感染者职业和技能 ****/
/* 再生术设置 */
new HPRegenerationLv[MAXPLAYERS+1];
/* 超级特感术设置 */
new String:bossname[9][10]={	"", "Smoker", "Boomer", "Hunter", "Spitter", "Jockey", "Charger", "", "Tank"};
new bool:IsSuperInfectedEnable[MAXPLAYERS+1];
new SuperInfectedLv[MAXPLAYERS+1];
#define SuperInfected_Particle		"molotov_explosion_child_streams"
#define SuperInfected_Sound_launch	"animation/bridge_destruct_swt_01.wav"
/* 召唤术设置 */
enum Uncommons {riot, ceda, clown, mudman, roadcrew, jimmy, fallen, witch}
enum UncommonInfo {String:infectedname[10], String:infectedmodel[64]}
static UncommonData[Uncommons][UncommonInfo];
new InfectedSummonLv[MAXPLAYERS+1];
new InfectedSummonCount[MAXPLAYERS+1];
new Handle:Cost_InfectedSummon[8];
/* 飞扑爆击术 */
new SuperPounceLv[MAXPLAYERS+1];
#define SuperPounce_Particle_Hit	"awning_collapse"
#define SuperPounce_Sound_Hit	"player/tank/hithulk_punch_1.wav"

/* 技能等级上限 */
#define LvLimit_Healing				50
#define LvLimit_EndranceQuality		30
#define LvLimit_AmmoMaking			40
#define LvLimit_SatelliteCannon		30
#define LvLimit_FireSpeed			20
#define LvLimit_EnergyEnhance		50
#define LvLimit_Sprint				50
#define LvLimit_BioShield			30
#define LvLimit_DamageReflect		30
#define LvLimit_MeleeSpeed			40
#define LvLimit_InfiniteAmmo		50
#define LvLimit_TeleportToSelect	20
#define LvLimit_AppointTeleport		20
#define LvLimit_TeleportTeam		20
#define LvLimit_HPRegeneration		30
#define LvLimit_SuperInfected		30
#define LvLimit_InfectedSummon		30
#define LvLimit_FireBall			30
#define LvLimit_IceBall				30
#define LvLimit_ChainLightning		30
#define LvLimit_HealingBall			30
#define LvLimit_SuperPounce			20

/* 技能效果范围等 */
#define HealingEffect							5
#define HealingDuration[%1]						10 + HealingLv[%1] *(1+Lis[%1])
#define EndranceQualityEffect[%1]				0.3 + 0.02*EndranceQualityLv[%1] *(1+Lis[%1])
#define AmmoMakingEffect[%1]					5*AmmoMakingLv[%1] *(1+Lis[%1])
#define SatelliteCannonTKExpFactor				10
#define SatelliteCannonLaunchTime				3.0
#define SatelliteCannonDamage[%1]				(2000 + 200*SatelliteCannonLv[%1]) *(1+Lis[%1])
#define SatelliteCannonSurvivorDamage[%1]		0
#define SatelliteCannonCDTime[%1]				25.0 - 0.5*SatelliteCannonLv[%1]*(1+Lis[%1])
#define SatelliteCannonRadius[%1]				300 + 25*SatelliteCannonLv[%1]*(1+Lis[%1])
#define FireSpeedEffect[%1]						0.2*FireSpeedLv[%1]*(1+Lis[%1])
#define EnergyEnhanceEffect_MaxEndurance[%1]	0.004*EnergyEnhanceLv[%1]*(1+Lis[%1])
#define EnergyEnhanceEffect_Endurance[%1]		0.01*EnergyEnhanceLv[%1]*(1+Lis[%1])
#define EnergyEnhanceEffect_Attack[%1]			0.01*EnergyEnhanceLv[%1]*(1+Lis[%1])
#define SprintEffect[%1]						0.5 + 0.01*SprintLv[%1]*(1+Lis[%1])
#define SprintDuration[%1]						5.0 + SprintLv[%1]*(1+Lis[%1])
#define InfiniteAmmoDuration[%1]				20.0 + 2.0*InfiniteAmmoLv[%1]*(1+Lis[%1])
#define BioShieldDuration[%1]					5.0 + 1.0*BioShieldLv[%1]*(1+Lis[%1])
#define BioShieldCDTime[%1]						80.0 - 1.0*BioShieldLv[%1]*(1+Lis[%1])
#define BioShieldSideEffect[%1]					0.2 + 0.01*BioShieldLv[%1]*(1+Lis[%1])
#define DamageReflectEffect[%1]					1.0*DamageReflectLv[%1]*(1+Lis[%1])
#define DamageReflectDuration[%1]				10.0 + 2.0*DamageReflectLv[%1]*(1+Lis[%1])
#define DamageReflectSideEffect[%1]				0.2 + 0.01*DamageReflectLv[%1]*(1+Lis[%1])
#define MeleeSpeedEffect[%1]					MeleeSpeedLv[%1]*0.1*(1+Lis[%1])
#define MeleeSpeedDuration[%1]					20.0 + 1.0*MeleeSpeedLv[%1]*(1+Lis[%1])
#define HPRegeneration_DamageStopTime			3.0
#define HPRegeneration_Rate						1.0
#define HPRegeneration_HPRate[%1]				0.005*HPRegenerationLv[%1]
#define SuperInfectedEffect_Attack[%1]			0.5 + 0.025*SuperInfectedLv[%1]
#define SuperInfectedEffect_Endurance[%1]		0.5 + 0.05*SuperInfectedLv[%1]
#define SuperInfectedEffect_Speed[%1]			1.0 + 0.02*SuperInfectedLv[%1]
#define SuperInfectedDuration[%1]				10.0 + 1.0*SuperInfectedLv[%1]
#define Job4_ExtraReward[%1]					Lv[%1] + TeleportToSelectLv[%1] + AppointTeleportLv[%1] + TeleportTeamLv[%1]
#define InfectedSummonMax[%1]					20 + 2*InfectedSummonLv[%1]
#define FireIceBallLife							10.0
#define FireBallDamageInterval[%1]				0.5
#define FireBallDamage[%1]						10 + FireBallLv[%1]*(1+Lis[%1])
#define FireBallTKDamage[%1]					0
#define FireBallDuration[%1]					2.5 + 0.5*FireBallLv[%1]*(1+Lis[%1])
#define FireBallRadius[%1]						100 + 10*FireBallLv[%1]*(1+Lis[%1])
#define IceBallDamage[%1]						50*(1+Lis[%1])
#define IceBallTKDamage[%1]						1
#define IceBallDuration[%1]						3.0 + 0.3*IceBallLv[%1]*(1+Lis[%1])
#define IceBallRadius[%1]						100 + 5*IceBallLv[%1]*(1+Lis[%1])
#define ChainLightningInterval[%1]				1.0
#define ChainLightningDamage[%1]				20 + ChainLightningLv[%1]*(1+Lis[%1])
#define ChainLightningRadius[%1]				100 + 5*ChainLightningLv[%1]*(1+Lis[%1])
#define ChainLightningLaunchRadius[%1]			150 + 15*ChainLightningLv[%1]*(1+Lis[%1])
#define HealingBallInterval						1.0
#define HealingBallEffect[%1]					5*(1+Lis[%1])
#define HealingBallRadius[%1]					150 + 15*HealingBallLv[%1]*(1+Lis[%1])
#define HealingBallDuration[%1]					10.0 + 1.0*HealingBallLv[%1]*(1+Lis[%1])
#define SuperPounceDamage[%1]					10 + SuperPounceLv[%1]
#define SuperPounceRadius[%1]					100 + 10*SuperPounceLv[%1]

/* 幸存者经验值 */
new Handle:JockeyKilledExp;
new Handle:HunterKilledExp;
new Handle:ChargerKilledExp;
new Handle:SmokerKilledExp;
new Handle:SpitterKilledExp;
new Handle:BoomerKilledExp;
new Handle:SuperInfectedExpFactor;
new Handle:TankKilledExp;
new Handle:WitchKilledExp;
new Handle:ZombieKilledExp;
new Handle:TeammateKilledExp;
new Handle:TankSurvivedExp;
new Handle:ReviveTeammateExp;
new Handle:ReanimateTeammateExp;
new Handle:HealTeammateExp;
new Handle:SurvivorGotIncappedExpFactor;
new Handle:SurvivorGotKilledExpFactor;

/* 幸存者金钱 */
new Handle:JockeyKilledCash;
new Handle:HunterKilledCash;
new Handle:ChargerKilledCash;
new Handle:SmokerKilledCash;
new Handle:SpitterKilledCash;
new Handle:BoomerKilledCash;
new Handle:SuperInfectedCashFactor;
new Handle:TankKilledCash;
new Handle:WitchKilledCash;
new Handle:ZombieKilledCash;
new Handle:TeammateKilledCash;
new Handle:TankSurvivedCash;
new Handle:ReviveTeammateCash;
new Handle:ReanimateTeammateCash;
new Handle:HealTeammateCash;
new Handle:SurvivorGotIncappedCashFactor;
new Handle:SurvivorGotKilledCashFactor;

/* 感染者者经验值 */
new Handle:SurvivorKilledExp;
new Handle:SurvivorIncappedExp;
new Handle:SpitterSpitExp;
new Handle:SmokerGrabbedExp;
new Handle:HunterPouncedExp;
new Handle:HunterPouncedAddExp;
new Handle:BoomerVomitExp;
new Handle:ChargerGrabbedExp;
new Handle:ChargerImpactExp;
new Handle:JockeyRideExp;
new Handle:TankClawExp;
new Handle:TankRockExp;
new Handle:InfectedAttackExp;
new Handle:SummonInfectedAttackExp;
new Handle:InfectedGotKilledExpFactor;

/* 感染者者金钱 */
new Handle:SurvivorKilledCash;
new Handle:SurvivorIncappedCash;
new Handle:SpitterSpitCash;
new Handle:SmokerGrabbedCash;
new Handle:HunterPouncedCash;
new Handle:HunterPouncedAddCash;
new Handle:BoomerVomitCash;
new Handle:ChargerGrabbedCash;
new Handle:ChargerImpactCash;
new Handle:JockeyRideCash;
new Handle:TankClawCash;
new Handle:TankRockCash;
new Handle:InfectedAttackCash;
new Handle:SummonInfectedAttackCash;
new Handle:InfectedGotKilledCashFactor;

new Float:infectedPosition[MAXPLAYERS+1][3];

/* 特殊商店 */
new Handle:RemoveKTCost;//消除大过
new Handle:ResetStatusCost;//遗忘河药水
new Handle:TomeOfExpCost;//经验之书
new Handle:TomeOfExpEffect;

/** 枪械强化率 **/
//#define Qgl[%1] 100 - Shilv[%1]*10
//#define Sbl[%1] 0 + Shilv[%1]*5
//#define Jbl[%1] 0 + Shilv[%1]*5
#define MAXSHITOULV	50		//强化等级最大上限
/*
枪械说明
 pistol_magnum|玛格南手枪
 autoshotgun|1代的连发霰弹枪
 shotgun_spas|2代的连发霰弹枪
 pumpshotgun|1代的单发霰弹枪
 shotgun_chrome|2代的单发霰弹枪
 hunting_rifle|1代的连狙
 sniper_military|2代的连狙
 rifle|M16突击步枪
 rifle_m60|M60突击步枪
 rifle_ak47|AK-47突击步枪
 rifle_desert|SCAR突击步枪(三连发)
 smg|轻型冲锋枪
 smg_silenced|消音轻型冲锋枪
 pistol|手枪
 weapon_grenade_launcher|榴弹发射器
 weapon_sniper_awp|麦格农重型狙击枪
 weapon_sniper_scout|斯太尔轻型狙击枪
 weapon_smg_mp5|MP5冲锋枪
 weapon_rifle_sg552|SIG SG552突击步枪
 */

/* 彩票 */
#define	diceNumMin	1
#define	diceNumMax	35
new Handle:LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
//#define LotteryEvent	3
new Lottery[MAXPLAYERS+1]				=	{0, ...};
new AdminDiceNum[MAXPLAYERS+1]			=	{-1, ...};
new bool:IsGlowClient[MAXPLAYERS+1]		=	{false, ...};
new Handle:LotteryEnable;
new Handle:LotteryCost;
new Handle:LotteryRecycle;
//new LotteryEventDuration[LotteryEvent]	=	{-1, ...};
//static String:LotteryEventName[LotteryEvent][64];

/* 升级奖励 */
new Handle:LvUpSP;
new Handle:LvUpKSP;
new Handle:LvUpCash;

/* 升级成本 */
new Handle:LvUpExpRate;

/* 攻击/击杀/召唤尸消失被击杀次数计算 */
new HurtCount[MAXPLAYERS+1];
new SummonHurtCount[MAXPLAYERS+1];
new SpitCount[MAXPLAYERS+1];
new ZombiesKillCount[MAXPLAYERS+1];
new SummonKilledCount[MAXPLAYERS+1];
new SummonDisappearedCount[MAXPLAYERS+1];

/* Robot升级设置 */
new RobotUpgradeLv[MAXPLAYERS+1][3];

//枪械强化伤害
#define DMG_LVD				6
//枪械伤害 武器伤害
#define DMG_AK47				50 
#define DMG_M60				25 
#define DMG_M16				35
#define DMG_MP5				20 
#define DMG_SPAS				1
#define DMG_CHROME				1
#define DMG_AUTOSHOTGUN			1
#define DMG_HUNTING		    60
#define DMG_SCOUT			    85
#define DMG_AWP				65 
#define DMG_GL				150 
#define DMG_SMG				25 
#define DMG_SMG_S			    23 
#define DMG_MAGNUM				50 

#define NAME_AK47				"weapon_rifle_ak47"
#define NAME_M60				"weapon_rifle_m60"
#define NAME_M16				"weapon_rifle"
#define NAME_MP5				"weapon_smg_mp5"
#define NAME_SPAS				"weapon_shotgun_spas"
#define NAME_CHROME			"weapon_shotgun_chrome"
#define NAME_AUTOSHOTGUN		"weapon_autoshotgun"
#define NAME_HUNTING			"weapon_hunting_rifle"
#define NAME_SCOUT				"weapon_sniper_scout"
#define NAME_AWP				"weapon_sniper_awp"
#define NAME_GL				"weapon_grenade_launcher"
#define NAME_SMG				"weapon_smg"
#define NAME_SMG_S				"weapon_smg_silenced"
#define NAME_MAGNUM			"weapon_pistol_magnum"

/* 技能成本 */
new Handle:Cost_Healing;
new Handle:Cost_AmmoMaking;
new Handle:Cost_SatelliteCannon;
new Handle:Cost_Sprint;
new Handle:Cost_BioShield;
new Handle:Cost_DamageReflect;
new Handle:Cost_MeleeSpeed;
new Handle:Cost_InfiniteAmmo;
new Handle:Cost_SuperInfected;
new Handle:Cost_TeleportToSelect;
new Handle:Cost_AppointTeleport;
new Handle:Cost_TeleportTeammate;
new Handle:Cost_HealingBall;
new Handle:Cost_FireBall;
new Handle:Cost_IceBall;
new Handle:Cost_ChainLightning;

/* Admin选单 */
new Handle:hTopMenu = INVALID_HANDLE;
new TopMenuObject:Admin_GiveExp;
new TopMenuObject:Admin_GiveLv;
new TopMenuObject:Admin_ResetStatus;
new TopMenuObject:Admin_GiveCash;
new TopMenuObject:Admin_GiveKT;
new AdminGiveAmount[MAXPLAYERS+1];
new g_id[MAXPLAYERS+1];

/* 洗点模式 */
#define General	1
#define Shop	2
#define Admin	3
#define NewLife	4

/* 玩家资讯显示模式 */
#define colored	1
#define simple	2

/* 其他 */
new Handle:BindMode				=	INVALID_HANDLE;
new Handle:ShowMode				=	INVALID_HANDLE;
new Handle:GiveAnnonce			=	INVALID_HANDLE;
new Handle:CleanSaveFileDays	=	INVALID_HANDLE;
new Handle:VersusScoreEnable	=	INVALID_HANDLE;
new Handle:VersusScoreMultipler	=	INVALID_HANDLE;
new Handle:BotHP				=	INVALID_HANDLE;
new Handle:WitchBalanceLv		=	INVALID_HANDLE;
new Handle:g_hCvarShow		=	INVALID_HANDLE;

/* 存档和排名 */
new String:SavePath[256];
new String:RankPath[256];
new Handle:RPGSave = INVALID_HANDLE;
new Handle:RPGRank = INVALID_HANDLE;
#define RankNo 100
new String:LevelRankClient[MAXPLAYERS+RankNo][256];
new LevelRank[MAXPLAYERS+RankNo];
new String:CashRankClient[MAXPLAYERS+RankNo][256];
new CashRank[MAXPLAYERS+RankNo];
new bool:IsAdmin[MAXPLAYERS+1]	=	{false, ...};

/* 购物商店 */
new Handle:CfgNormalItemShopEnable;
new Handle:CfgSelectedGunShopEnable;
new Handle:CfgMeleeShopEnable;
/* Number of Normal Items */
#define NORMALITEMMAX 10
/* Number of Selected Guns */
#define SELECTEDGUNMAX 8
/* Number of Selected Melees */
#define SELECTEDMELEEMAX 13
/* Number of Robot */
#define ROBOTMAX 17
static String:WeaponName[ROBOTMAX][]={ "猎枪","M16突击步枪","战术散弹鎗", "散弹鎗", "乌兹衝锋鎗", "手枪", "麦格农手枪","AK47",
"SCAR步枪", "SG552步枪", "铬钢散弹鎗", "战斗散弹鎗", "自动式狙击枪", "SCOUT轻型狙弹枪", "AWP麦格农狙击枪", "MP5衝锋鎗", "灭音衝锋鎗"};

/* 商品价格 */
new Handle:CfgNormalItemCost[NORMALITEMMAX];
new Handle:CfgSelectedGunCost[SELECTEDGUNMAX];
new Handle:CfgMeleeCost[SELECTEDMELEEMAX];
new Handle:CfgRobotCost[ROBOTMAX];
/* 音效 */
#define TSOUND			"ui/critical_event_1.wav"
/* 圈圈顏色 */
new CyanColor[4] 	= {0, 255, 255, 255};
//new PurpleColor[4]	= {255, 0, 255, 255};
new RedColor[4]		= {255, 80, 80, 255};
new BlueColor[4]	= {80, 80, 255, 255};
/* 对抗计分 */
new TeamChangeSecondLeft;
new RoundNo;
new Round1SurvivorScore;
new Round2SurvivorScore;
new StartScore[3];
new SurvivorLogicalTeam;
new InfectedLogicalTeam;
new PlayerAliveTime[MAXPLAYERS+1];
new NextRoundTeam[MAXPLAYERS+1];
new RoundPlayTime;
new Handle:TeamChangeTimer = INVALID_HANDLE;
new Handle:RoundPlayTimer = INVALID_HANDLE;
new Handle:VersusScoreChangeTeamTime = INVALID_HANDLE;
new Handle:gConf = INVALID_HANDLE;
new Handle:fGTS = INVALID_HANDLE;
new Handle:fSHS = INVALID_HANDLE;
new Handle:fTOB = INVALID_HANDLE;
new bool:IsVersus;
//new bool:IsFirstMap;
//new bool:IsMapEnd;

#define SOUND_TRACING	"items/suitchargeok1.wav"

/* Particle */
#define PARTICLE_INFECTEDSUMMON	"electrical_arc_01_parent"
#define PARTICLE_SCEFFECT	"gen_hit_up"
#define PARTICLE_HLEFFECT	"embers_medium_03"
//#define PARTICLE_HLEFFECT	"firework_crate_explosion_01"
//#define PARTICLE_HLEFFECT_1	"firework_crate_explosion_02"
//#define PARTICLE_HLEFFECT_2	"fireworks_explosion_glow_03"
//#define PARTICLE_HLEFFECT_3	"fireworks_explosion_trail_04"
//#define PARTICLE_HLEFFECT_4	"fireworks_explosion_trail_04b"

#define DamageDisplayBuffer 5
#define DamageDisplayLength 64
#define ALIVE 0
#define NORMALDEAD 1
#define HEADSHOT 2
new DamageToTank[MAXPLAYERS+1][MAXPLAYERS+1];
new String:DamageDisplayString[MAXPLAYERS+1][DamageDisplayBuffer][DamageDisplayLength];
//new LastDamage[MAXPLAYERS+1];

/************ Robot设置 ************/
#define SOUNDCLIPEMPTY	"weapons/ClipEmpty_Rifle.wav"
#define SOUNDRELOAD		"weapons/shotgun/gunother/shotgun_load_shell_2.wav"
#define SOUNDREADY		"weapons/shotgun/gunother/shotgun_pump_1.wav"

#define WEAPONCOUNT 17

#define SOUND0 "weapons/hunting_rifle/gunfire/hunting_rifle_fire_1.wav"
#define SOUND1 "weapons/rifle/gunfire/rifle_fire_1.wav"
#define SOUND2 "weapons/auto_shotgun/gunfire/auto_shotgun_fire_1.wav"
#define SOUND3 "weapons/shotgun/gunfire/shotgun_fire_1.wav"
#define SOUND4 "weapons/SMG/gunfire/smg_fire_1.wav"
#define SOUND5 "weapons/pistol/gunfire/pistol_fire.wav"
#define SOUND6 "weapons/magnum/gunfire/magnum_shoot.wav"
#define SOUND7 "weapons/rifle_ak47/gunfire/rifle_fire_1.wav"
#define SOUND8 "weapons/rifle_desert/gunfire/rifle_fire_1.wav"
#define SOUND9 "weapons/sg552/gunfire/sg552-1.wav"
#define SOUND10 "weapons/shotgun_chrome/gunfire/shotgun_fire_1.wav"
#define SOUND11 "weapons/auto_shotgun_spas/gunfire/shotgun_fire_1.wav"
#define SOUND12 "weapons/sniper_military/gunfire/sniper_military_fire_1.wav"
#define SOUND13 "weapons/scout/gunfire/scout_fire-1.wav"
#define SOUND14 "weapons/awp/gunfire/awp1.wav"
#define SOUND15 "weapons/mp5navy/gunfire/mp5-1.wav"
#define SOUND16 "weapons/smg_silenced/gunfire/smg_fire_1.wav"

#define MODEL0 "weapon_hunting_rifle"
#define MODEL1 "weapon_rifle"
#define MODEL2 "weapon_autoshotgun"
#define MODEL3 "weapon_pumpshotgun"
#define MODEL4 "weapon_smg"
#define MODEL5 "weapon_pistol"
#define MODEL6 "weapon_pistol_magnum"
#define MODEL7 "weapon_rifle_ak47"
#define MODEL8 "weapon_rifle_desert"
#define MODEL9 "weapon_rifle_sg552"
#define MODEL10 "weapon_shotgun_chrome"
#define MODEL11 "weapon_shotgun_spas"
#define MODEL12 "weapon_sniper_military"
#define MODEL13 "weapon_sniper_scout"
#define MODEL14 "weapon_sniper_awp"
#define MODEL15 "weapon_smg_mp5"
#define MODEL16 "weapon_smg_silenced"

/* Particle */
#define PARTICLE_BLOOD	"blood_impact_infected_01"

new String:SOUND[WEAPONCOUNT+3][70]=
{SOUND0, SOUND1, SOUND2, SOUND3, SOUND4, SOUND5, SOUND6, SOUND7,SOUND8,SOUND9, SOUND10, SOUND11,SOUND12,SOUND13,SOUND14, SOUND15,SOUND16,SOUNDCLIPEMPTY, SOUNDRELOAD, SOUNDREADY};

new String:MODEL[WEAPONCOUNT][32]=
{MODEL0, MODEL1, MODEL2, MODEL3, MODEL4, MODEL5,MODEL6, MODEL7,MODEL8,MODEL9,MODEL10, MODEL11, MODEL12,MODEL13,MODEL14, MODEL15, MODEL16};

new Float:fireinterval[WEAPONCOUNT]={0.25, 0.068, 0.30, 0.65, 0.060, 0.20, 0.33, 0.145, 0.14, 0.064, 0.65, 0.30, 0.265, 0.9, 1.25, 0.065, 0.055};
new Float:bulletaccuracy[WEAPONCOUNT]={1.15, 1.4, 3.5, 3.5, 1.6, 1.7, 1.7, 1.5, 1.6, 1.5, 3.5, 3.5, 1.15, 1.00, 0.8, 1.6,1.6};
new Float:weaponbulletdamage[WEAPONCOUNT]={90.0, 30.0, 25.0, 30.0, 20.0, 30.0, 60.0, 70.0, 40.0, 40.0, 30.0, 30.0, 90.0, 100.0, 150.0, 35.0, 35.0};
new weaponclipsize[WEAPONCOUNT]={15, 50, 10, 8, 50, 30, 8, 40, 20, 50, 8, 10, 30, 15, 20, 50, 50};
new weaponbulletpershot[WEAPONCOUNT]={1, 1, 7, 7, 1, 1, 1, 1, 1, 1, 7, 7,1, 1, 1,1,1};
new Float:weaponloadtime[WEAPONCOUNT]={2.0, 1.5, 0.3, 0.3, 1.5, 1.5, 1.9, 1.5, 1.5, 1.6, 0.3, 0.3, 2.0,2.0, 2.0, 1.5, 1.5};
new weaponloadcount[WEAPONCOUNT]={15, 50, 1,1, 50, 30, 8, 40, 60, 50, 1, 1, 30, 15, 20, 50, 50};
new bool:weaponloaddisrupt[WEAPONCOUNT]={false,false, true, true,false,false, false, false, false, true, true, false, false, false, false, false};

new robot[MAXPLAYERS+1];
new keybuffer[MAXPLAYERS+1];
new weapontype[MAXPLAYERS+1];
new bullet[MAXPLAYERS+1];
new Float:firetime[MAXPLAYERS+1];
new bool:reloading[MAXPLAYERS+1];
new Float:reloadtime[MAXPLAYERS+1];
new Float:scantime[MAXPLAYERS+1];
new Float:walktime[MAXPLAYERS+1];
new Float:botenerge[MAXPLAYERS+1];

new SIenemy[MAXPLAYERS+1];
new CIenemy[MAXPLAYERS+1];

new Float:robotangle[MAXPLAYERS+1][3];

new Handle:RobotReactiontime = INVALID_HANDLE;
new Handle:RobotEnergy = INVALID_HANDLE;
new Handle:CfgRobotUpgradeCost[3] = INVALID_HANDLE;

new Float:robot_reactiontime;
new Float:robot_energy;

new bool:robot_gamestart = false;

new RobotCount[MAXPLAYERS+1];

/************ 魔王坦克设置 ************/
#define FORMONE			1
#define FORMTWO			2
#define FORMTHREE			3
#define FORMFOUR			4
#define DEAD				-1

#define CLASS_TANK		8
#define MOLOTOV 			0
#define EXPLODE 			1
#define ENTITY_GASCAN	"models/props_junk/gascan001a.mdl"
#define ENTITY_PROPANE	"models/props_junk/propanecanister001a.mdl"

/* Sound */
#define SOUND_EXPLODE	"animation/bombing_run_01.wav"
#define SOUND_SPAWN		"music/pzattack/contusion.wav"
#define SOUND_BCLAW		"weapons/grenade_launcher/grenadefire/grenade_launcher_explode_1.wav"
#define SOUND_GCLAW		"plats/churchbell_end.wav"
#define SOUND_DCLAW		"ambient/random_amb_sounds/randbridgegroan_03.wav"
#define SOUND_QUAKE		"player/charger/hit/charger_smash_02.wav"
#define SOUND_STEEL		"physics/metal/metal_solid_impact_hard5.wav"
#define SOUND_CHANGE	"items/suitchargeok1.wav"
#define SOUND_HOWL		"player/tank/voice/pain/tank_fire_08.wav"
#define SOUND_WARP		"ambient/energy/zap9.wav"

/* Particle */
#define PARTICLE_SPAWN	"electrical_arc_01_system"
#define PARTICLE_DEATH	"gas_explosion_main"
#define PARTICLE_THIRD	"apc_wheel_smoke1"
#define PARTICLE_FORTH	"aircraft_destroy_fastFireTrail"
#define PARTICLE_WARP	"water_splash"

/* Message */
#define MSG_TANK_ADD_LV_DIFFERENCE	"幸存者阵营总等级(Lv. %d)多於特殊感染者阵营(Lv. %d), 增加%d隻魔王变身坦克!"
#define MESSAGE_SPAWN	"{green}<终极魔王变身坦克>{blue}降临!"
#define MESSAGE_SPAWN2	"{olive}此阶段特别技能:\n{olive}爆裂石头 - {blue}当石头投中幸存者时会形强大的衝击波"
#define MESSAGE_SECOND	"{green}%N{blue}己进入第二阶段变身 -> {green}[钢甲坦克]\n{olive}此阶段特别技能:"
#define MESSAGE_SECOND2	"{olive}爆裂石头: {blue}当石头投中幸存者时会形强大的衝击波\n{olive}重力抓击: {blue}被抓中的幸存者周围的重力会减弱，持续数秒\n{olive}钢甲: {blue}近战武器无效"
#define MESSAGE_THIRD	"{green}%N{blue}己进入第三阶段变身 -> {green}[忍者坦克]\n{olive}此阶段特别技能:"
#define MESSAGE_THIRD2	"{olive}爆裂石头: {blue}当石头投中幸存者时会形强大的衝击波\n{olive}隐形皮肤: {blue}释放烟雾, 渐渐消失无踪\n{olive}恐惧抓击: {blue}被抓中的幸存者会致盲数秒"
#define MESSAGE_FORTH	"{green}%N{blue}己进入第四阶段变身 -> {green}[火焰坦克]\n{olive}此阶段特别技能:"
#define MESSAGE_FORTH2	"{olive}彗星撞击: {blue}当石头投中幸存者时会形强大的衝击波，并会著火\n{olive}燃烧抓击: {blue}被抓中的幸存者HP会变成Temp HP，持续减少"
#define MESSAGE_FORTH3	"{olive}火焰涌出: {blue}持近战攻击坦克, 会有爆炸声响, 而坦克周围会有火焰"

/* Parameter */
new Handle:sm_lastboss_basic_number			= INVALID_HANDLE;
new Handle:sm_lastboss_lv_add_enable			= INVALID_HANDLE;
new Handle:sm_lastboss_lv_add_difference		= INVALID_HANDLE;
new Handle:sm_lastboss_enable_announce		= INVALID_HANDLE;
new Handle:sm_lastboss_enable_steel			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_stealth			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_gravity			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_burn			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_jump			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_quake			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_comet			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_dread			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_gush			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_abyss			= INVALID_HANDLE;
new Handle:sm_lastboss_enable_warp			= INVALID_HANDLE;

new Handle:sm_lastboss_health_max	 			= INVALID_HANDLE;
new Handle:sm_lastboss_health_second 			= INVALID_HANDLE;
new Handle:sm_lastboss_health_third	 		= INVALID_HANDLE;
new Handle:sm_lastboss_health_forth	 		= INVALID_HANDLE;

new Handle:sm_lastboss_speed_first 	 		= INVALID_HANDLE;
new Handle:sm_lastboss_speed_second	 		= INVALID_HANDLE;
new Handle:sm_lastboss_speed_third 	 		= INVALID_HANDLE;
new Handle:sm_lastboss_speed_forth	 		= INVALID_HANDLE;

new Handle:sm_lastboss_stealth_third 			= INVALID_HANDLE;
new Handle:sm_lastboss_jumpinterval_forth	= INVALID_HANDLE;
new Handle:sm_lastboss_jumpheight_forth		= INVALID_HANDLE;
new Handle:sm_lastboss_gravityinterval 		= INVALID_HANDLE;
new Handle:sm_lastboss_quake_radius 			= INVALID_HANDLE;
new Handle:sm_lastboss_quake_force	 		= INVALID_HANDLE;
new Handle:sm_lastboss_dreadinterval 			= INVALID_HANDLE;
new Handle:sm_lastboss_dreadrate	 			= INVALID_HANDLE;
new Handle:sm_lastboss_warp_interval			= INVALID_HANDLE;
new Handle:sm_protected_money				= INVALID_HANDLE;
new Handle:sm_protected_exp					= INVALID_HANDLE;
new Handle:sm_givepill_exp					= INVALID_HANDLE;
new Handle:sm_givepill_money					= INVALID_HANDLE;
new Handle:sm_helpofinf_exp					= INVALID_HANDLE;
new Handle:sm_helpofinf_money				= INVALID_HANDLE;
new Handle:sm_opendoor_exp					= INVALID_HANDLE;
new Handle:sm_opendoor_money					= INVALID_HANDLE;
new Handle:sm_helpofledge_exp				= INVALID_HANDLE;
new Handle:sm_helpofledge_money				= INVALID_HANDLE;

/* Timer Handle */
new Handle:TimerUpdate[MAXPLAYERS+1]				=	{	INVALID_HANDLE, ...};
new Handle:GetSurvivorPositionTimer[MAXPLAYERS+1]	=	{	INVALID_HANDLE, ...};
new Handle:FatalMirrorTimer[MAXPLAYERS+1]			=	{	INVALID_HANDLE, ...};
new Handle:AttachParticleTimer[MAXPLAYERS+1]		=	{	INVALID_HANDLE, ...};
new Handle:MadSpringTimer[MAXPLAYERS+1]				=	{	INVALID_HANDLE, ...};
new Handle:fadeoutTimer[MAXPLAYERS+1]				=	{	INVALID_HANDLE, ...};

/* 陨石 */
new Handle:CreateStarFallTimer[MAXPLAYERS+1]	=	{	INVALID_HANDLE, ...};
new StarFallLeft[MAXPLAYERS+1];
#define StarFallNumber		25
#define MinStarFallHight	500.0
#define MaxStarFallHight	1500.0
#define StarFallDamage		100
#define StarFallRadius		500
#define StarFallPushForce	800

/* 投石 */
#define tick 1.0/40.0
new bool:tankpower_gamestart = false;
new Handle:w_pushforce_mode ;
new Handle:w_pushforce_vlimit ;
new Handle:w_pushforce_factor ;
new Handle:w_pushforce_tankfactor ;
new Handle:w_pushforce_survivorfactor ;

new Handle:w_damage_rock ;
new Handle:w_radius_rock ;
new Handle:w_pushforce_rock ;

new Handle:tankpower_trace_factor;
new Handle:tankpower_trace_obstacle;
new Handle:tankpower_predict_factor;
new Handle:tankpower_rock_health;

/* Grobal */
new alpharate;
new visibility;
new form_prev[MAXPLAYERS+1] = {	DEAD, ...};
new g_iVelocity	= -1;
new Float:ftlPos[3];

new TanksSpawned = 0;
new TanksToSpawn=0;
new TanksMustSpawned=0;
new TanksFrustrated = 0;
new TotalTanks = 0;
new bool:IsTank[MAXPLAYERS+1] = {	true, ...};
new bool:IsFrustrated[MAXPLAYERS+1] = {	true, ...};
new DefaultMaxZombies = 0;

new bool:IsRoundStarted;
new bool:IsRoundEnded;

new Handle:SpawnTimer    		= INVALID_HANDLE;
new Handle:CheckTimer    		= INVALID_HANDLE;

/* Timers设置 */
new Handle:HurtCountTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:SummonHurtCountTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:SpitCountTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:ZombiesKillCountTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:SummonKilledCountTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:SummonDisappearedCountTimer[MAXPLAYERS+1]	= {	INVALID_HANDLE, ...};
new Handle:HPRegenTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:DamageStopTimer[MAXPLAYERS+1]				= {	INVALID_HANDLE, ...};
new Handle:CheckExpTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:HealingTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:SuperInfectedLifeTimeTimer[MAXPLAYERS+1]		= {	INVALID_HANDLE, ...};
new Handle:SprinDurationTimer[MAXPLAYERS+1]				= {	INVALID_HANDLE, ...};
new Handle:InfiniteAmmoDurationTimer[MAXPLAYERS+1]		= {	INVALID_HANDLE, ...};
new Handle:BioShieldDurationTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:BioShieldCDTimer[MAXPLAYERS+1]				= {	INVALID_HANDLE, ...};
new Handle:DamageReflectDurationTimer[MAXPLAYERS+1]		= {	INVALID_HANDLE, ...};
new Handle:MeleeSpeedDurationTimer[MAXPLAYERS+1]		= {	INVALID_HANDLE, ...};
new Handle:FadeBlackTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:TCChargingTimer[MAXPLAYERS+1]				= {	INVALID_HANDLE, ...};
new Handle:TTChargingTimer[MAXPLAYERS+1]				= {	INVALID_HANDLE, ...};
new Handle:SatelliteCannonCDTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
//new Handle:DamageDisplayCleanTimer[MAXPLAYERS+1]		= {	INVALID_HANDLE, ...};

/* Sprite */
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO		"materials/sprites/halo01.vmt"
#define SPRITE_GLOW		"materials/sprites/glow01.vmt"

new g_BeamSprite;
new g_HaloSprite;
new g_GlowSprite;

#define LASERMODE_NORMAL	0
#define LASERMODE_VARTICAL	1

static	Handle:	hTimer_ClientTeamChange[MAXPLAYERS+1]		=	{ INVALID_HANDLE, ... };

new String:LogPath[256];

new Handle:g_hDataBase = INVALID_HANDLE;
new Handle:g_hTimerGivePlayerEXP = INVALID_HANDLE;

public OnPluginStart()
{
	decl String:Game_Name[64];
	GetGameFolderName(Game_Name, sizeof(Game_Name));
	if(!StrEqual(Game_Name, "left4dead2", false))
	{
		SetFailState("United RPG%d插件仅支持L4D2!", PLUGIN_VERSION);
	}

	/* 创建Save和Ranking的KeyValues */
	RPGSave = CreateKeyValues("United RPG Save");
	RPGRank = CreateKeyValues("United RPG Ranking");
	/* 设置Save和Ranking位置 */
	BuildPath(Path_SM, SavePath, 255, "data/UnitedRPGSave.txt");
	BuildPath(Path_SM, RankPath, 255, "data/UnitedRPGRanking.txt");
	if (FileExists(SavePath))
	{
		FileToKeyValues(RPGSave, SavePath);
	}
	else
	{
		PrintToServer("[统计] 找不到玩家记录档: %s, 将重新建立!", SavePath);
		KeyValuesToFile(RPGSave, SavePath);
	}
	if (FileExists(RankPath))
	{
		FileToKeyValues(RPGRank, RankPath);
	}
	else
	{
		PrintToServer("[统计] 找不到排名记录档: %s, 将重新建立!", RankPath);
		KeyValuesToFile(RPGRank, RankPath);
	}

	CreateConVar("United_RPG_Version", PLUGIN_VERSION, "United RPG 插件版本", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_DONTRECORD);

	LoadTranslations("common.phrases");

	RegisterCvars();
	RegisterCmds();
	HookEvents();
	GetConVar();
	InitUncommonDataArray();
	
	gConf = LoadGameConfigFile("UnitedRPG");
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "GetTeamScore");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	fGTS = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	fSHS = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	fTOB = EndPrepSDKCall();

	#if !ENABLE_SQL
	/* 清除存档 */
	CreateTimer(1.0, CleanSaveFile);
	#endif

	if (LibraryExists("adminmenu") && ((hTopMenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(hTopMenu);
	}
	
	/* 读取排名 */
	LoadRanking();

	/* 生成CFG */
	AutoExecConfig(true, "l4d2_UnitedRPG");

	HookConVarChange(RobotReactiontime, ConVarChange);
	HookConVarChange(RobotEnergy, ConVarChange);
	robot_gamestart = false;

	if((g_iVelocity = FindSendPropOffs("CBasePlayer", "m_vecVelocity[0]")) == -1)
		LogError("Could not find offset for CBasePlayer::m_vecVelocity[0]");

	tankpower_gamestart = false;
	
	new String:date[21];
	/* Format date for log filename */
	FormatTime(date, sizeof(date), "%d%m%y", -1);
	/* Create name of logfile to use */
	BuildPath(Path_SM, LogPath, sizeof(LogPath), "logs/unitedrpg%s.log", date);
	#if ENABLE_SQL
	ConnectDataBase();
	#endif
}
RegisterCvars()
{
	/* 幸存者经验值 */
	JockeyKilledExp					= CreateConVar("rpg_GainExp_Kill_Jockey",				"200",	"击杀Jockey获得的经验值", CVAR_FLAGS, true, 0.0);
	HunterKilledExp					= CreateConVar("rpg_GainExp_Kill_hunter",				"250",	"击杀Hunter获得的经验值", CVAR_FLAGS, true, 0.0);
	ChargerKilledExp				= CreateConVar("rpg_GainExp_Kill_Charger",				"250",	"击杀Charger获得的经验值", CVAR_FLAGS, true, 0.0);
	SmokerKilledExp					= CreateConVar("rpg_GainExp_Kill_Smoker",				"200",	"击杀Smoker获得的经验值", CVAR_FLAGS, true, 0.0);
	SpitterKilledExp				= CreateConVar("rpg_GainExp_Kill_Spitter",				"200",	"击杀Spitter获得的经验值", CVAR_FLAGS, true, 0.0);
	BoomerKilledExp					= CreateConVar("rpg_GainExp_Kill_Boomer",				"150",	"击杀Boomer获得的经验值", CVAR_FLAGS, true, 0.0);
	SuperInfectedExpFactor			= CreateConVar("rpg_GainExp_Super_Infected",			"2",	"击杀超级特感的经验值系数: 经验值*系数", CVAR_FLAGS, true, 0.0);
	TankKilledExp					= CreateConVar("rpg_GainExp_Kill_Tank",					"1",	"击杀Tank每一伤害获得的经验值", CVAR_FLAGS, true, 0.0);
	TankSurvivedExp					= CreateConVar("rpg_GainExp_TankSurvived",				"500",	"Tank死亡后所有幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	WitchKilledExp					= CreateConVar("rpg_GainExp_Kill_Witch",				"500",	"击杀Witch获得的经验值", CVAR_FLAGS, true, 0.0);
	ZombieKilledExp					= CreateConVar("rpg_GainExp_Kill_Zombie",				"25",	"击杀普通丧尸获得的经验值", CVAR_FLAGS, true, 0.0);
	ReviveTeammateExp				= CreateConVar("rpg_GainExp_Revive_Teammate",			"200",	"拉起队友获得的经验值", CVAR_FLAGS, true, 0.0);
	ReanimateTeammateExp			= CreateConVar("rpg_GainExp_Reanimate_Teammate",		"350",	"电击器复活队友获得的经验值", CVAR_FLAGS, true, 0.0);
	HealTeammateExp					= CreateConVar("rpg_GainExp_Survivor_Heal_Teammate",	"500",	"帮队友治疗获得的经验值", CVAR_FLAGS, true, 0.0);
	TeammateKilledExp				= CreateConVar("rpg_GainExp_Kill_Teammate",				"1000",	"幸存者误杀队友扣除的经验值", CVAR_FLAGS, true, 0.0);
	SurvivorGotIncappedExpFactor	= CreateConVar("rpg_GainExp_Survivor_Got_Incapped",		"0.5",	"幸存者倒下扣除的经验值系数: (现有等级*5 -智力)*系数", CVAR_FLAGS, true, 0.0);
	SurvivorGotKilledExpFactor		= CreateConVar("rpg_GainExp_Survivor_Got_Killed",		"2.5",	"幸存者死亡扣除的经验值系数: (现有等级*5 -智力)*系数", CVAR_FLAGS, true, 0.0);
	sm_protected_exp				= CreateConVar("rpg_gainexp_protect",		"50",	"保护队友获得的经验值", CVAR_FLAGS, true, 0.0);
	sm_givepill_exp				= CreateConVar("rpg_gainexp_givepill",		"75",	"给队友药丸和针获得的经验值", CVAR_FLAGS, true, 0.0);
	sm_opendoor_exp				= CreateConVar("rpg_gainexp_openrdoor",		"50",	"打开复活房获得的经验值", CVAR_FLAGS, true, 0.0);
	sm_helpofinf_exp				= CreateConVar("rpg_gainexp_helponinf",		"100",	"从特感手里救回队友获得的经验值", CVAR_FLAGS, true, 0.0);
	sm_helpofledge_exp				= CreateConVar("rpg_gainexp_helponled",		"25",	"拉起挂边队友获得的经验值", CVAR_FLAGS, true, 0.0);
	
	/* 幸存者金钱 */
	JockeyKilledCash				= CreateConVar("rpg_GainCash_Kill_Jockey",				"20",	"击杀Jockey获得的金钱", CVAR_FLAGS, true, 0.0);
	HunterKilledCash				= CreateConVar("rpg_GainCash_Kill_hunter",				"25",	"击杀Hunter获得的金钱", CVAR_FLAGS, true, 0.0);
	ChargerKilledCash				= CreateConVar("rpg_GainCash_Kill_Charger",				"25",	"击杀Charger获得的金钱", CVAR_FLAGS, true, 0.0);
	SmokerKilledCash				= CreateConVar("rpg_GainCash_Kill_Smoker",				"20",	"击杀Smoker获得的金钱", CVAR_FLAGS, true, 0.0);
	SpitterKilledCash				= CreateConVar("rpg_GainCash_Kill_Spitter",				"20",	"击杀Spitter获得的金钱", CVAR_FLAGS, true, 0.0);
	BoomerKilledCash				= CreateConVar("rpg_GainCash_Kill_Boomer",				"15",	"击杀Boomer获得的金钱", CVAR_FLAGS, true, 0.0);
	SuperInfectedCashFactor			= CreateConVar("rpg_GainCash_Super_Infected",			"2",	"击杀超级特感的金钱系数: 金钱*系数", CVAR_FLAGS, true, 0.0);
	TankKilledCash					= CreateConVar("rpg_GainCash_Kill_Tank",				"0.01",	"击杀Tank每一伤害获得的金钱", CVAR_FLAGS, true, 0.0);
	TankSurvivedCash				= CreateConVar("rpg_GainCash_TankSurvived",				"50",	"Tank死亡后所有幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	WitchKilledCash					= CreateConVar("rpg_GainCash_Kill_Witch",				"50",	"击杀Witch获得的金钱", CVAR_FLAGS, true, 0.0);
	ZombieKilledCash				= CreateConVar("rpg_GainCash_Kill_Zombie",				"1",	"击杀普通丧尸获得的金钱", CVAR_FLAGS, true, 0.0);
	ReviveTeammateCash				= CreateConVar("rpg_GainCash_Revive_Teammate",			"20",	"拉起队友获得的金钱", CVAR_FLAGS, true, 0.0);
	ReanimateTeammateCash			= CreateConVar("rpg_GainCash_Reanimate_Teammate",		"40",	"电击器复活队友获得的金钱", CVAR_FLAGS, true, 0.0);
	HealTeammateCash				= CreateConVar("rpg_GainCash_Survivor_Heal_Teammate",	"60",	"帮队友治疗获得的金钱", CVAR_FLAGS, true, 0.0);
	TeammateKilledCash				= CreateConVar("rpg_GainCash_Kill_Teammate",			"100",	"幸存者误杀队友扣除的金钱", CVAR_FLAGS, true, 0.0);
	SurvivorGotIncappedCashFactor	= CreateConVar("rpg_GainCash_Survivor_Got_Incapped",	"0.25",	"幸存者倒下扣除的金钱系数: 现有等级*系数", CVAR_FLAGS, true, 0.0);
	SurvivorGotKilledCashFactor		= CreateConVar("rpg_GainCash_Survivor_Got_Killed",		"1.25",	"幸存者死亡扣除的金钱系数: 现有等级*系数", CVAR_FLAGS, true, 0.0);
	sm_protected_money				= CreateConVar("rpg_GainCash_protected",		"10",	"保护队友获得的金钱", CVAR_FLAGS, true, 0.0);
	sm_givepill_money				= CreateConVar("rpg_GainCash_givepill",		"25",	"给队友药丸或针获得的金钱", CVAR_FLAGS, true, 0.0);
	sm_opendoor_money				= CreateConVar("rpg_GainCash_opendoor",		"5",	"打开复活房获得的金钱", CVAR_FLAGS, true, 0.0);
	sm_helpofinf_money				= CreateConVar("rpg_GainCash_helponinf",		"15",	"从特感手里救队友获得的金钱", CVAR_FLAGS, true, 0.0);
	sm_helpofledge_money			= CreateConVar("rpg_GainCash_helponinf",		"5",	"拉起挂边队友获得的金钱", CVAR_FLAGS, true, 0.0);
	
	/* 感染者经验值 */
	SurvivorKilledExp				= CreateConVar("rpg_GainExp_Kill_Survivor",				"800",	"感染者成功杀死幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	SurvivorIncappedExp 			= CreateConVar("rpg_GainExp_Survivor_Incapacitated",	"300",	"感染者令幸存者倒下获得的经验值", CVAR_FLAGS, true, 0.0);
	InfectedAttackExp				= CreateConVar("rpg_GainExp_Infected_Attack",			"20",	"感染者持续攻击幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	SummonInfectedAttackExp			= CreateConVar("rpg_GainExp_Summon_Infected_Attack",	"10",	"召唤感染者持续攻击幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	SpitterSpitExp					= CreateConVar("rpg_GainExp_Spitter_Spit",				"10",	"Spitter酸液攻击幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	SmokerGrabbedExp				= CreateConVar("rpg_GainExp_Smoker_Grabbed",			"150",	"Smoker拉扯幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	HunterPouncedExp				= CreateConVar("rpg_GainExp_Hunter_Pounced_Add",		"150",	"Hunter突袭幸存者的经验值", CVAR_FLAGS, true, 0.0);
	HunterPouncedAddExp				= CreateConVar("rpg_GainExp_Hunter_Pounced",			"20",	"Hunter突袭幸存者每一伤害的额外经验值", CVAR_FLAGS, true, 0.0);
	BoomerVomitExp					= CreateConVar("rpg_GainExp_Boomer_Vomit",				"150",	"Boomer吐中幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	JockeyRideExp					= CreateConVar("rpg_GainExp_Jockey_Ride",				"350",	"Jockey骑中幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	ChargerGrabbedExp				= CreateConVar("rpg_GainExp_Charger_Grabbed",			"200",	"Charger抓住幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	ChargerImpactExp				= CreateConVar("rpg_GainExp_Charger_Impact",			"80",	"Charger撞开幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	TankClawExp						= CreateConVar("rpg_GainExp_Tank_Claw",					"200",	"Tank爪击幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	TankRockExp						= CreateConVar("rpg_GainExp_Tank_Rock",					"200",	"Tank用石头投中幸存者获得的经验值", CVAR_FLAGS, true, 0.0);
	InfectedGotKilledExpFactor		= CreateConVar("rpg_GainExp_Infected_Got_Killed",		"0.5",	"给幸存者击杀扣除的经验值系数: (现有等级*5 -智力)*系数", CVAR_FLAGS, true, 0.0);

	/* 感染者金钱 */
	SurvivorKilledCash				= CreateConVar("rpg_GainCash_Kill_Survivor",			"120",	"感染者成功杀死幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	SurvivorIncappedCash			= CreateConVar("rpg_GainCash_Survivor_Incapacitated",	"30",	"感染者令幸存者倒下获得的金钱", CVAR_FLAGS, true, 0.0);
	InfectedAttackCash				= CreateConVar("rpg_GainCash_Infected_Attack",			"2",	"感染者持续攻击幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	SummonInfectedAttackCash		= CreateConVar("rpg_GainCash_Summon_Infected_Attack",	"1",	"召唤感染者持续攻击幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	SpitterSpitCash					= CreateConVar("rpg_GainCash_Spitter_Spit",				"1",	"Spitter酸液攻击幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	SmokerGrabbedCash				= CreateConVar("rpg_GainCash_Smoker_Grabbed",			"15",	"Smoker拉扯幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	HunterPouncedCash				= CreateConVar("rpg_GainCash_Hunter_Pounced",			"15",	"Hunter突袭幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	HunterPouncedAddCash			= CreateConVar("rpg_GainCash_Hunter_Pounced_Add",		"2",	"Hunter突袭幸存者每一伤害获得的额外金钱", CVAR_FLAGS, true, 0.0);
	BoomerVomitCash					= CreateConVar("rpg_GainCash_Boomer_Vomit",				"15",	"Boomer吐中幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	JockeyRideCash					= CreateConVar("rpg_GainCash_Jockey_Ride",				"35",	"Jockey骑中幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	ChargerGrabbedCash				= CreateConVar("rpg_GainCash_Charger_Grabbed",			"20",	"Charger抓住幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	ChargerImpactCash				= CreateConVar("rpg_GainCash_Charger_Impact",			"8",	"Charger撞开幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	TankClawCash					= CreateConVar("rpg_GainCash_Tank_Claw",				"20",	"Tank爪击幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	TankRockCash					= CreateConVar("rpg_GainCash_Tank_Rock",				"20",	"Tank用石头投中幸存者获得的金钱", CVAR_FLAGS, true, 0.0);
	InfectedGotKilledCashFactor		= CreateConVar("rpg_GainCash_Infected_Got_Killed",		"0.25",	"给幸存者击杀扣除的金钱系数: (现有等级*系数)", CVAR_FLAGS, true, 0.0);

	/* 关於升级 */
	LvUpSP		= CreateConVar("rpg_LvUp_SP",		"5",	"升级获得的属性点", CVAR_FLAGS, true, 0.0);
	LvUpKSP		= CreateConVar("rpg_LvUp_KSP",		"2",	"升级获得的技能点", CVAR_FLAGS, true, 0.0);
	LvUpCash	= CreateConVar("rpg_LvUp_Cash",		"1000",	"升级获得的金钱", CVAR_FLAGS, true, 0.0);
	LvUpExpRate	= CreateConVar("rpg_LvUp_Exp_Rate",	"100",	"升级Exp系数: 升级经验=升级系Exp数*(当前等级+1)", CVAR_FLAGS, true, 1.0);
	NewLifeLv	= CreateConVar("rpg_NewLife_Lv",	"100",	"转生所需等级", CVAR_FLAGS, true, 1.0);

	/*  关於属性技能点 */
	Cost_Healing			= CreateConVar("rpg_MPCost_Healing",			"5000",		"使用治疗术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_AmmoMaking			= CreateConVar("rpg_MPCost_MakingAmmo",			"8000",		"使用制造子弹术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SatelliteCannon	= CreateConVar("rpg_MPCost_SatelliteCannon",	"10000",	"使用卫星炮术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_Sprint				= CreateConVar("rpg_MPCost_Sprint",				"8000",		"使用加速冲刺术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_BioShield			= CreateConVar("rpg_MPCost_BionicShield",		"10000",	"使用无敌术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_DamageReflect		= CreateConVar("rpg_MPCost_DamageReflect",		"10000",	"使用反伤术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_MeleeSpeed			= CreateConVar("rpg_MPCost_MeleeSpeed",			"10000",	"使用近战嗜血术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfiniteAmmo		= CreateConVar("rpg_MPCost_InfiniteAmmo",		"8000",		"使用无限子弹术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SuperInfected		= CreateConVar("rpg_MPCost_SI",					"10000",	"使用超级特感加强术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_TeleportToSelect	= CreateConVar("rpg_MPCost_TeleportToSelect",	"8000",		"使用选择传送术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_AppointTeleport	= CreateConVar("rpg_MPCost_AppointTeleport",	"8000",		"使用目标传送术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_TeleportTeammate	= CreateConVar("rpg_MPCost_TeleportTeammate",	"10000",	"使用心灵传送术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_HealingBall		= CreateConVar("rpg_MPCost_HealingBall",		"10000",	"使用治疗光球术所需MP", CVAR_FLAGS, true, 0.0);
	TeleportTeam_Mode		= CreateConVar("rpg_SkillMode_TeleportTeam",	"0",		"心灵传送技能传送队友模式 0=传送单人 1=传送整队", CVAR_FLAGS, true, 0.0, true, 1.0);
	Cost_FireBall			= CreateConVar("rpg_MPCost_FireBall",			"3000",		"使用火球术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_IceBall			= CreateConVar("rpg_MPCost_IceBall",			"3000",		"使用冰球术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_ChainLightning		= CreateConVar("rpg_MPCost_ChainLightning",		"10000",	"使用连锁闪电术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[0]	= CreateConVar("rpg_MPCost_InfectedSummon_01",	"250",		"召唤防暴警察所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[1]	= CreateConVar("rpg_MPCost_InfectedSummon_02",	"100",		"召唤防核CEDA人员所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[2]	= CreateConVar("rpg_MPCost_InfectedSummon_03",	"150",		"召唤小丑所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[3]	= CreateConVar("rpg_MPCost_InfectedSummon_04",	"150",		"召唤泥人所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[4]	= CreateConVar("rpg_MPCost_InfectedSummon_05",	"100",		"召唤地盘工人所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[5]	= CreateConVar("rpg_MPCost_InfectedSummon_06",	"1000",		"召唤赛车手Jimmy Gibbs Jr.所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[6]	= CreateConVar("rpg_MPCost_InfectedSummon_07",	"500",		"召唤军人Fallen Survivor所需MP", CVAR_FLAGS, true, 0.0);
	Cost_InfectedSummon[7]	= CreateConVar("rpg_MPCost_InfectedSummon_08",	"25000",	"召唤Witch所需MP", CVAR_FLAGS, true, 0.0);

	CfgNormalItemShopEnable		= CreateConVar("rpg_Shop_normal_items_enable",		"1",	"是否允许投掷品，药物和子弹盒购物选单 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);
	CfgSelectedGunShopEnable	= CreateConVar("rpg_Shop_selected_gun__enable",		"1",	"是否允许许特选枪械购物商店 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);
	CfgMeleeShopEnable			= CreateConVar("rpg_Shop_selected_melee_enable",	"1",	"是否允许近战武器购物商店 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Normal Items Cost*/
	CfgNormalItemCost[0]	= CreateConVar("rpg_ShopCost_Normal_Items_00","100","补充子弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[1]	= CreateConVar("rpg_ShopCost_Normal_Items_01","450","燃烧瓶的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[2]	= CreateConVar("rpg_ShopCost_Normal_Items_02","420","土製炸弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[3]	= CreateConVar("rpg_ShopCost_Normal_Items_03","430","胆汁的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[4]	= CreateConVar("rpg_ShopCost_Normal_Items_04","1500","药包的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[5]	= CreateConVar("rpg_ShopCost_Normal_Items_05","750","药丸的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[6]	= CreateConVar("rpg_ShopCost_Normal_Items_06","600","肾上腺素针的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[7]	= CreateConVar("rpg_ShopCost_Normal_Items_07","1450","电击器的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[8]	= CreateConVar("rpg_ShopCost_Normal_Items_08","560","高爆子弹盒的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[9]	= CreateConVar("rpg_ShopCost_Normal_Items_09","520","燃烧子弹盒的价钱", CVAR_FLAGS, true, 0.0);

	/* Selected Guns Cost*/
	CfgSelectedGunCost[0]	= CreateConVar("rpg_ShopCost_Selected_Guns_00","125","MP5衝锋鎗的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[1]	= CreateConVar("rpg_ShopCost_Selected_Guns_01","865","Scout轻型狙击枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[2]	= CreateConVar("rpg_ShopCost_Selected_Guns_02","1248","Awp重型狙击枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[3]	= CreateConVar("rpg_ShopCost_Selected_Guns_03","732","Sg552突击步枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[4]	= CreateConVar("rpg_ShopCost_Selected_Guns_04","960","M60重型机枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[5]	= CreateConVar("rpg_ShopCost_Selected_Guns_05","1500","榴弹发射器的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[6]	= CreateConVar("rpg_ShopCost_Selected_Guns_06","840","AK47的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[7]	= CreateConVar("rpg_ShopCost_Selected_Guns_07","850","战斗散弹鎗的价钱", CVAR_FLAGS, true, 0.0);

	/* Selected Melees Cost*/
	CfgMeleeCost[0]		= CreateConVar("rpg_ShopCost_Selected_Melees_00","933","棒球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[1]		= CreateConVar("rpg_ShopCost_Selected_Melees_01","625","板球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[2]		= CreateConVar("rpg_ShopCost_Selected_Melees_02","625","铁撬的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[3]		= CreateConVar("rpg_ShopCost_Selected_Melees_03","700","电结他的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[4]		= CreateConVar("rpg_ShopCost_Selected_Melees_04","888","斧头的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[5]		= CreateConVar("rpg_ShopCost_Selected_Melees_05","233","平底锅的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[6]		= CreateConVar("rpg_ShopCost_Selected_Melees_06","760","高尔夫球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[7]		= CreateConVar("rpg_ShopCost_Selected_Melees_07","998","武士刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[8]		= CreateConVar("rpg_ShopCost_Selected_Melees_08","899","CS小刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[9]		= CreateConVar("rpg_ShopCost_Selected_Melees_09","666","开山刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[10]	= CreateConVar("rpg_ShopCost_Selected_Melees_10","250","盾牌的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[11]	= CreateConVar("rpg_ShopCost_Selected_Melees_11","345","警棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[12]	= CreateConVar("rpg_ShopCost_Selected_Melees_12","1024","电锯的价钱", CVAR_FLAGS, true, 0.0);

	/* Robot成本*/
	CfgRobotCost[0]		= CreateConVar("rpg_ShopCost_Robot_00","2000","[猎枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[1]		= CreateConVar("rpg_ShopCost_Robot_01","2000","[M16突击步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[2]		= CreateConVar("rpg_ShopCost_Robot_02","2000","[战术散弹鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[3]		= CreateConVar("rpg_ShopCost_Robot_03","1500","[散弹鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[4]		= CreateConVar("rpg_ShopCost_Robot_04","1500","[乌兹衝锋鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[5]		= CreateConVar("rpg_ShopCost_Robot_05","1000","[手枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[6]		= CreateConVar("rpg_ShopCost_Robot_06","1500","[麦格农手枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[7]		= CreateConVar("rpg_ShopCost_Robot_07","3000","[AK47]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[8]		= CreateConVar("rpg_ShopCost_Robot_08","3000","[SCAR步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[9]		= CreateConVar("rpg_ShopCost_Robot_09","3000","[SG552步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[10]	= CreateConVar("rpg_ShopCost_Robot_10","3000","[铬钢散弹鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[11]	= CreateConVar("rpg_ShopCost_Robot_11","3000","[战斗散弹鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[12]	= CreateConVar("rpg_ShopCost_Robot_12","3000","[自动式狙击枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[13]	= CreateConVar("rpg_ShopCost_Robot_13","3000","[SCOUT轻型狙弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[14]	= CreateConVar("rpg_ShopCost_Robot_14","2500","[AWP麦格农狙击枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[15]	= CreateConVar("rpg_ShopCost_Robot_15","2500","[MP5衝锋鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[16]	= CreateConVar("rpg_ShopCost_Robot_16","1500","[灭音衝锋鎗]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);

	/* 特殊商店*/
	RemoveKTCost	= CreateConVar("rpg_ShopCost_Special_Remove_KT",	"10000",	"消除一次大过的价钱", CVAR_FLAGS, true, 0.0);
	ResetStatusCost	= CreateConVar("rpg_ShopCost_Special_Reset_Status",	"50000",	"遗忘河药水的价钱", CVAR_FLAGS, true, 0.0);
	TomeOfExpCost	= CreateConVar("rpg_ShopCost_Special_Tome_Of_Exp",	"10000",	"经验之书的价钱", CVAR_FLAGS, true, 0.0);
	TomeOfExpEffect	= CreateConVar("rpg_Special_Tome_Of_Exp_Effect",	"5000",		"使用经验之书增加多少EXP", CVAR_FLAGS, true, 0.0);
	
	/* 彩票卷 */
	LotteryEnable	= CreateConVar("rpg_Lottery_Enable",	"1",	"是否开啟彩票功能(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	LotteryCost		= CreateConVar("rpg_Lottery_Cost",		"2500",	"彩票卷单价", CVAR_FLAGS, true, 0.0);
	LotteryRecycle	= CreateConVar("rpg_Lottery_Recycle",	"0.8",	"回收彩票卷的价钱=售价x倍率(0.0~1.0)", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	/* Robot Config */
	RobotReactiontime		= CreateConVar("rpg_RobotConfig_Reactiontime",	"0.1",	"Robot反应时间", CVAR_FLAGS, true, 0.1);
 	RobotEnergy				= CreateConVar("rpg_RobotConfig_Rnergy", 		"5.0",	"Robot能量维持时间(分鐘)", CVAR_FLAGS, true, 0.1);
	CfgRobotUpgradeCost[0]	= CreateConVar("rpg_RobotUpgradeCost_0",		"6000",	"升级Robot攻击力的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotUpgradeCost[1]	= CreateConVar("rpg_RobotUpgradeCost_1",		"3000",	"升级Robot弹匣系统的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotUpgradeCost[2]	= CreateConVar("rpg_RobotUpgradeCost_2",		"5000",	"升级Robot侦查距离的价钱", CVAR_FLAGS, true, 0.0);

	/* 其他 */
	BindMode					= CreateConVar("rpg_BindMode", 						"2",	"玩家进入服务器是否自动绑定键位 0-不绑定 1-提示绑定 2-不提示自动绑定", CVAR_FLAGS, true, 0.0, true, 2.0);
	ShowMode					= CreateConVar("rpg_ShowMode", 						"0",	"公屏聊天时是否在游戏名前显示等级信息 0-不显示 1-显示", CVAR_FLAGS, true, 0.0, true, 1.0);
	GiveAnnonce					= CreateConVar("rpg_AdminGiveAnnonce", 				"0",	"是否显示管理给予玩家经验值/LV等信息 0-不显示 1-显示", CVAR_FLAGS, true, 0.0, true, 1.0);
	CleanSaveFileDays			= CreateConVar("rpg_CleanSaveDays", 				"0",	"清除多少天未上线非admin玩家的存档 0-不清除", CVAR_FLAGS, true, 0.0);
	VersusScoreEnable			= CreateConVar("rpg_VersusScore_Enable", 			"1",	"启动对抗奖励系统(完场后根据双方分数给予经验和钱)(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	VersusScoreMultipler		= CreateConVar("rpg_VersusScore_Multipler",		 	"5", 	"对抗奖励系统获得的经验值系数(经验值=积分差距*系数*关卡贡献时间)", CVAR_FLAGS, true, 1.0);
	VersusScoreChangeTeamTime	= CreateConVar("rpg_VersusScore_Change_Team_Time",	"120",	"对抗第一回合多少秒内可转队(只有当对抗奖励系统启动)", CVAR_FLAGS, true, 1.0);
	BotHP						= CreateConVar("rpg_BotHPMultipler", 				"1.0",	"电脑的生命值加强倍数", CVAR_FLAGS, true, 1.0);
	WitchBalanceLv				= CreateConVar("rpg_WitchBalanceLv",				"100",	"幸存者每完成四分一路程差多少等级增加一隻Witch", CVAR_FLAGS, true, 1.0);
	g_hCvarShow				= CreateConVar("rpg_ShowInfot", 						"0",	"是否显示提示", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Enable/Disable */
	sm_lastboss_basic_number		= CreateConVar("rpg_LastBoss_Basic_Number",				"0",	"魔王坦克基本数量", CVAR_FLAGS, true, 1.0);
	sm_lastboss_lv_add_enable		= CreateConVar("rpg_LastBoss_LvBalance_Enable",			"0",	"是否根据双方队伍等级差距增加魔王坦克数量.(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_lv_add_difference	= CreateConVar("rpg_LastBoss_LvBalance_LvDifference",	"100",	"差多少等级增加一隻魔王坦克", CVAR_FLAGS, true, 1.0);
	sm_lastboss_enable_announce		= CreateConVar("rpg_LastBoss_Enable_Announce",			"0",	"魔王坦克出现时提示.(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Skills Enable/Disable */
	sm_lastboss_enable_steel	= CreateConVar("rpg_LastBoss_Enable_Steel",		"1",	"魔王坦克能使用钢甲(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_stealth	= CreateConVar("rpg_LastBoss_Enable_Stealth",	"1",	"魔王坦克能使用隐形皮肤(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_gravity	= CreateConVar("rpg_LastBoss_Enable_Gravity",	"1",	"魔王坦克能使用重力抓击(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_burn		= CreateConVar("rpg_LastBoss_Enable_Burn",		"1",	"魔王坦克能使用燃烧抓击(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_quake	= CreateConVar("rpg_LastBoss_Enable_Quake",		"1",	"魔王坦克能使用地震(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_jump		= CreateConVar("rpg_LastBoss_Enable_Jump",		"1",	"魔王坦克能使用疯狂跳跃(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_comet	= CreateConVar("rpg_LastBoss_Enable_Comet",		"1",	"魔王坦克能使用爆裂石头和彗星撞击(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_dread	= CreateConVar("rpg_LastBoss_Enable_Dread",		"1",	"魔王坦克能使用恐惧抓击(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_gush		= CreateConVar("rpg_LastBoss_Enable_Gush",		"1",	"魔王坦克能使用火焰涌出(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	sm_lastboss_enable_abyss	= CreateConVar("rpg_LastBoss_Enable_Abyss",		"1",	"魔王坦克能使用深渊召唤(0:OFF 1:ON(Forth form only) 2:ON(All forms))", CVAR_FLAGS, true, 0.0, true, 2.0);
	sm_lastboss_enable_warp		= CreateConVar("rpg_LastBoss_Enable_Warp",		"1",	"魔王坦克能使用致命镜像(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Health */
	sm_lastboss_health_max	  	= CreateConVar("rpg_LastBoss_Health_1",	"8000",	"魔王坦克第一型态HP",    CVAR_FLAGS, true, 4.0, true, 65535.0);
	sm_lastboss_health_second	= CreateConVar("rpg_LastBoss_Health_2",	"6000",	"魔王坦克第二型态HP", CVAR_FLAGS, true, 3.0, true, 65534.0);
	sm_lastboss_health_third  	= CreateConVar("rpg_LastBoss_Health_3",	"4000",	"魔王坦克第三型态HP",  CVAR_FLAGS, true, 2.0, true, 65533.0);
	sm_lastboss_health_forth 	= CreateConVar("rpg_LastBoss_Health_4",	"2000",	"魔王坦克第四型态HP",  CVAR_FLAGS, true, 1.0, true, 65532.0);

	/* Speed */
	sm_lastboss_speed_first		= CreateConVar("rpg_LastBoss_Speed_1",		"1.0",	"魔王坦克第一型态的速度",  CVAR_FLAGS, true, 0.1);
	sm_lastboss_speed_second		= CreateConVar("rpg_LastBoss_Speed_2",	"1.1",	"魔王坦克第二型态的速度", CVAR_FLAGS, true, 0.1);
	sm_lastboss_speed_third		= CreateConVar("rpg_LastBoss_Speed_3",		"1.2",	"魔王坦克第三型态的速度",  CVAR_FLAGS, true, 0.1);
	sm_lastboss_speed_forth		= CreateConVar("rpg_LastBoss_Speed_4",		"1.3",	"魔王坦克第四型态的速度",  CVAR_FLAGS, true, 0.1);

	/* Skill */
	sm_lastboss_stealth_third		= CreateConVar("rpg_LastBoss_SkillConfig_3_stealth",				"5.0",		"魔王坦克第三型态的隐形皮肤开始时间", CVAR_FLAGS, true, 0.1);
	sm_lastboss_jumpinterval_forth	= CreateConVar("rpg_LastBoss_SkillConfig_4_jumpinterval_forth",		"1.0",		"魔王坦克第四型态的疯狂跳跃间隔", CVAR_FLAGS, true, 0.1);
	sm_lastboss_jumpheight_forth  	= CreateConVar("rpg_LastBoss_SkillConfig_4_jumpheight_forth",		"500.0",	"魔王坦克第四型态的疯狂跳跃高度", CVAR_FLAGS, true, 0.1);
	sm_lastboss_gravityinterval		= CreateConVar("rpg_LastBoss_SkillConfig_2_gravityinterval",		"10.0",		"魔王坦克的第二型态重力抓击持续时间", CVAR_FLAGS, true, 0.1);
	sm_lastboss_quake_radius		= CreateConVar("rpg_LastBoss_SkillConfig_quake_radius",				"1000.0",	"魔王坦克的地震距离", CVAR_FLAGS, true, 0.1);
	sm_lastboss_quake_force			= CreateConVar("rpg_LastBoss_SkillConfig_quake_force",				"200.0",	"魔王坦克的地震力度", CVAR_FLAGS, true, 0.1);
	sm_lastboss_dreadinterval		= CreateConVar("rpg_LastBoss_SkillConfig_3_dreadinterval",			"8.0",		"魔王坦克第三型态的恐惧抓击致盲时间", CVAR_FLAGS, true, 0.1);
	sm_lastboss_dreadrate			= CreateConVar("rpg_LastBoss_SkillConfig_3_dreadrate",				"235",		"魔王坦克第三型态的恐惧抓击致盲强度", CVAR_FLAGS, true, 1.0, true, 255.0);
	sm_lastboss_warp_interval		= CreateConVar("rpg_LastBoss_SkillConfig_warp_interval",			"35.0",		"魔王坦克的致命镜像间隔", CVAR_FLAGS, true, 0.1);

	/* 追踪石头 */
	w_pushforce_mode 			= CreateConVar("rpg_TankPower_PushForce_Mode",				"1", 	"追踪石头爆炸模式 0:disable, 1:mode one, 2:mode two, 3: both", CVAR_FLAGS, true, 0.0, true, 3.0);
	w_pushforce_vlimit 			= CreateConVar("rpg_TankPower_PushForce_Vlimit",			"300",	"速度上限", CVAR_FLAGS, true, 1.0);
	w_pushforce_factor 			= CreateConVar("rpg_TankPower_PushForce_Factor",			"0.8",	"追踪石头爆炸系数", CVAR_FLAGS, true, 0.1);
	w_pushforce_tankfactor 		= CreateConVar("rpg_TankPower_PushForce_TankFactor",		"0.1",	"Tank的追踪石头爆炸系数", CVAR_FLAGS, true, 0.1);
	w_pushforce_survivorfactor	= CreateConVar("rpg_TankPower_PushForce_SurvivorFactor",	"0.5",	"幸存者的追踪石头爆炸系数", CVAR_FLAGS, true, 0.1);

	w_damage_rock		= CreateConVar("rpg_Tankpower_RockConfig_Damage",		"25", "追踪石头的爆炸伤害", CVAR_FLAGS, true, 1.0);
	w_radius_rock		= CreateConVar("rpg_Tankpower_RockConfig_Radius",		"250", "追踪石头的爆炸距离", CVAR_FLAGS, true, 1.0);
	w_pushforce_rock	= CreateConVar("rpg_Tankpower_RockConfig_PushForce",	"800", "追踪石头的爆炸力度", CVAR_FLAGS, true, 1.0);

	tankpower_trace_factor		= CreateConVar("rpg_Tankpower_RockConfig_Trace_Factor",			"0.5", "追踪系数 [0.1-0.5]", CVAR_FLAGS, true, 0.1, true, 0.5);
	tankpower_predict_factor	= CreateConVar("rpg_Tankpower_RockConfig_Trace_Predict_Factor", "5.0", "预测系数 [0.0-10.0]", CVAR_FLAGS, true, 0.0, true, 10.0);
	tankpower_trace_obstacle	= CreateConVar("rpg_Tankpower_RockConfig_Trace_Obstacle",		"0.5", "路径系数 [0.1-0.5]", CVAR_FLAGS, true, 0.1, true, 0.5);
	tankpower_rock_health		= CreateConVar("rpg_Tankpower_RockConfig_RockHealth",			"300", "石头生命值, 0:default");
}
RegisterCmds()
{
	/* RPG主选单 */
	RegConsoleCmd("sm_ripigu",		Menu_RPG);
	RegConsoleCmd("sm_give", MenuFunc_Bugei, "获得武器物品");
	RegConsoleCmd("say",		Command_Say);
	RegConsoleCmd("say_team",	Command_SayTeam);
	RegConsoleCmd("buy", Command_BuyMenu, "购买物品");
	RegConsoleCmd("buyammo1", Command_BuyAmmo1, "快速购买弹药");
	RegConsoleCmd("buyequip", Command_BuyEquip, "快速购买装备");
	RegConsoleCmd("sm_rp", UseLottery, "启动人品事件");
	/* 分配属性 */
	RegConsoleCmd("sm_addattack",	AddStrength);
	RegConsoleCmd("sm_addspeed",	AddAgile);
	RegConsoleCmd("sm_addhelath",	AddHealth);
	RegConsoleCmd("sm_addshield",	AddEndurance);
	RegConsoleCmd("sm_addmagic",	AddIntelligence);
	/* 技能 */
	RegConsoleCmd("sm_useskill",	Menu_UseSkill);
	RegConsoleCmd("sm_heal",			UseHealing, "治疗自己");
	RegConsoleCmd("sm_getammo",			UseAmmoMaking);
	RegConsoleCmd("sm_crlaser",			UseSatelliteCannon);
	RegConsoleCmd("sm_rush",			UseSprint);
	RegConsoleCmd("sm_iammo",			UseInfiniteAmmo);
	RegConsoleCmd("sm_godmode",			UseBioShield);
	RegConsoleCmd("sm_backdmg",			UseDamageReflect);
	RegConsoleCmd("sm_gethelath",			UseMeleeSpeed);
	RegConsoleCmd("sm_telepos",			UseTeleportToSelect);
	RegConsoleCmd("sm_telefir",			UseAppointTeleport);
	RegConsoleCmd("sm_teleteam",			UseTeleportTeam);
	RegConsoleCmd("sm_supi",			UseSuperInfected);
	RegConsoleCmd("sm_summon",			UseInfectedSummon);
	RegConsoleCmd("sm_fireb",			UseFireBall);
	RegConsoleCmd("sm_iceb",			UseIceBall);
	RegConsoleCmd("sm_lighting",			UseChainLightning);
	RegConsoleCmd("sm_halo",			UseHealingBall);
	/* 物品背包 */
	RegConsoleCmd("sm_bag",		Menu_Beibaoxi, "打开备用物品菜单");
	/* 购物商店 */
	//RegConsoleCmd("buymenu",		Menu_Buy);
	//RegConsoleCmd("surbuy",			Menu_SurvivorBuy);
	//RegConsoleCmd("infbuy",			Menu_InfectedShop);
	//RegConsoleCmd("buyitem",		Menu_NormalItemShop);
	//RegConsoleCmd("buygun",	Menu_SelectedGunShop);
	//RegConsoleCmd("buymelee",	Menu_MeleeShop);
	//RegConsoleCmd("buybot",		Menu_RobotShop);
	/*  转队 */
	RegConsoleCmd("sm_jointeam1",	AFKTurnClientToSpectate);
	RegConsoleCmd("sm_jointeam2",	AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam3",	AFKTurnClientToInfected);
	/*  密码 */
	RegConsoleCmd("sm_rpgpw",		EnterPassword,"sm_rpgpw 密码");
	RegConsoleCmd("sm_rpgresetpw",	ResetPassword,"sm_rpgresetpw 原来密码 新的密码");
	RegConsoleCmd("sm_rpgpwinfo",	Passwordinfo);
	/*  队友资讯 */
	RegConsoleCmd("sm_teaminfo",	Menu_TeamInfo);
	/* Admins */
	RegAdminCmd("sm_giveexp",	Command_GiveExp, ADMFLAG_KICK, "sm_giveexp 玩家名字 数量");
	RegAdminCmd("sm_givelv",	Command_GiveLevel, ADMFLAG_KICK, "sm_givelv 玩家名字 数量");
	RegAdminCmd("sm_givecash",	Command_GiveCash, ADMFLAG_KICK, "sm_givecash 玩家名字 数量");
	RegAdminCmd("sm_fullmp",	Command_FullMP, ADMFLAG_KICK, "sm_fullmp");
	RegAdminCmd("sm_givekt",	Command_GiveKT, ADMFLAG_KICK, "sm_givekt 玩家名字 数量");
	RegAdminCmd("sm_rptest",	Command_RpTest, ADMFLAG_KICK, "sm_rptest 编号");
	RegConsoleCmd("callvote",	Callvote_Handler);
	/* Testing */
	//RegConsoleCmd("test",	TestFunction);
}

HookEvents()
{
	/* Event */
	HookEvent("player_hurt",			Event_PlayerHurt,	EventHookMode_Pre);
	HookEvent("witch_killed",			Event_WitchKilled);
	HookEvent("infected_hurt",			Event_InfectedHurt, EventHookMode_Pre);
	HookEvent("round_end",				Event_RoundEnd);
	HookEvent("heal_success",			Event_HealSuccess);
	HookEvent("revive_success",			Event_ReviveSuccess);
	HookEvent("round_start",			Event_RoundStart);
	HookEvent("player_first_spawn",		Event_PlayerFirstSpawn);
	HookEvent("player_death",			Event_PlayerDeath);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("jockey_ride_end",		Event_JockeyRideEnd);
	HookEvent("defibrillator_used",		Event_DefibrillatorUsed);
	HookEvent("tongue_grab",			Event_SmokerGrabbed);
	HookEvent("jockey_ride",			Event_JockeyRide);
	HookEvent("lunge_pounce",			Event_HunterPounced);
	HookEvent("player_now_it",			Event_BoomerAttackEXP);
	HookEvent("player_incapacitated",	Event_IncapacitateEXP);
	HookEvent("charger_pummel_start",	Event_ChargerPummel);
	HookEvent("charger_impact",			Event_ChargerImpact);
	HookEvent("weapon_fire",			Event_WeaponFire,	EventHookMode_Pre);
	HookEvent("player_use",				Event_PlayerUse);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("tank_spawn",				Event_TankSpawn);
	HookEvent("ability_use",			Event_AbilityUse);
	HookEvent("bot_player_replace",		Event_BotPlayerReplace);
	HookEvent("witch_harasser_set",		Event_WitchHarasserSet);
	HookEvent("tank_frustrated", 		Event_TankFrustrated);
	HookEvent("versus_marker_reached",	Event_VersusMarkerReached);
	HookEvent("player_changename",		Event_PlayerChangename,	EventHookMode_Pre);
	HookEvent("award_earned",			Event_AwardEarned);
	HookEvent("player_left_start_area",	Event_LeftSafeRoom);
	HookEvent("infected_death",			Event_InfectedDeath);
	
	//HookEvent("tank_killed", Event_TK);
	//HookEvent("finale_win", Event_RoundEnd);
	//HookEvent("mission_lost", Event_RoundEnd);
	//HookEvent("map_transition", Event_RoundEnd);
	//HookEvent("player_bot_replace",Event_PlayerBotReplace);
}

InitPrecache()
{
	/* Sound Precache */
	PrecacheSound(TSOUND, true);
	PrecacheSound(SatelliteCannon_Sound_Launch, true);
	PrecacheSound(SOUNDCLIPEMPTY, true);
	PrecacheSound(SOUNDRELOAD, true);
	PrecacheSound(SOUNDREADY, true);
	PrecacheSound(FireBall_Sound_Impact01, true);
	PrecacheSound(FireBall_Sound_Impact02, true);
	PrecacheSound(IceBall_Sound_Impact01, true);
	PrecacheSound(IceBall_Sound_Impact02, true);
	PrecacheSound(IceBall_Sound_Freeze, true);
	PrecacheSound(IceBall_Sound_Defrost, true);
	PrecacheSound(ChainLightning_Sound_launch, true);
	PrecacheSound(SuperInfected_Sound_launch, true);
	PrecacheSound(SuperPounce_Sound_Hit, true);

	/* Last Boss Precache sounds */
	PrecacheSound(SOUND_EXPLODE, true);
	PrecacheSound(SOUND_SPAWN, true);
	PrecacheSound(SOUND_BCLAW, true);
	PrecacheSound(SOUND_GCLAW, true);
	PrecacheSound(SOUND_DCLAW, true);
	PrecacheSound(SOUND_QUAKE, true);
	PrecacheSound(SOUND_STEEL, true);
	PrecacheSound(SOUND_CHANGE, true);
	PrecacheSound(SOUND_HOWL, true);
	PrecacheSound(SOUND_WARP, true);
	PrecacheSound(SOUND_TRACING, true);
	
	/* Model Precache */
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		PrecacheModel(MODEL[i], true);
		PrecacheSound(SOUND[i], true) ;
	}
	robot_gamestart = false;

	for(new i = 0; i < sizeof(UncommonData); i++)
	{
		if (!IsModelPrecached(UncommonData[i][infectedmodel]))
		{
			PrecacheModel(UncommonData[i][infectedmodel], true);
		}
	}

	/* Last Boss Precache models */
	PrecacheModel(ENTITY_PROPANE, true);
	PrecacheModel(ENTITY_GASCAN, true);
	
	PrecacheModel(FireBall_Model);

	/* Particles Precache */
	/* Last Boss Precache particles */
	PrecacheParticle(PARTICLE_SPAWN);
	PrecacheParticle(PARTICLE_DEATH);
	PrecacheParticle(PARTICLE_THIRD);
	PrecacheParticle(PARTICLE_FORTH);
	PrecacheParticle(PARTICLE_WARP);

	PrecacheParticle("gas_explosion_pump");
	PrecacheParticle(PARTICLE_BLOOD);
	PrecacheParticle(PARTICLE_INFECTEDSUMMON);
	PrecacheParticle(PARTICLE_SCEFFECT);
	PrecacheParticle(PARTICLE_HLEFFECT);
	
	PrecacheParticle(FireBall_Particle_Fire01);
	PrecacheParticle(FireBall_Particle_Fire02);
	PrecacheParticle(FireBall_Particle_Fire03);
	
	PrecacheParticle(IceBall_Particle_Ice01);
	PrecacheParticle(ChainLightning_Particle_hit);
	
	//PrecacheParticle(HealingBall_Particle);
	PrecacheParticle(HealingBall_Particle_Effect);
	
	PrecacheParticle(SuperInfected_Particle);
	PrecacheParticle(SuperPounce_Particle_Hit);
}
#if ENABLE_SQL
ConnectDataBase()
{
	new String:db[] = "storage-local";
	if(SQL_CheckConfig("l4d2UnitedRPGn"))
	{
		db = "l4d2UnitedRPGn";
	}
	decl String:error[256];
	g_hDataBase = SQL_Connect(db, true, error, sizeof(error));
	if(g_hDataBase == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	
	// 创建数据库
	new String:line[4096];
	Format(line, 4096, "CREATE TABLE IF NOT EXISTS %s (", db);
	Format(line, 4096, "%s name TEXT PRIMARY KEY,", line);
	//Format(line, 4096, "%s UID INTEGER NOT NULL AUTO_INCREMENT,", line);
	Format(line, 4096, "%s LV INTEGER,", line);
	Format(line, 4096, "%s EXP INTEGER,", line);
	Format(line, 4096, "%s Job INTEGER,", line);
	Format(line, 4096, "%s Bshu INTEGER,", line);
	Format(line, 4096, "%s Bliao INTEGER,", line);
	Format(line, 4096, "%s Bjia INTEGER,", line);
	Format(line, 4096, "%s Bzhan INTEGER,", line);
	Format(line, 4096, "%s Bxie INTEGER,", line);
	Format(line, 4096, "%s Bdian INTEGER,", line);
	Format(line, 4096, "%s LIS INTEGER,", line);
	Format(line, 4096, "%s Shitou INTEGER,", line);
	Format(line, 4096, "%s Qgl INTEGER,", line);
	Format(line, 4096, "%s Shilv INTEGER,", line);
	Format(line, 4096, "%s Qstr INTEGER,", line);
	Format(line, 4096, "%s WLBH INTEGER,", line);
	Format(line, 4096, "%s SP INTEGER,", line);
	Format(line, 4096, "%s KSP INTEGER,", line);
	Format(line, 4096, "%s CASH INTEGER,", line);
	Format(line, 4096, "%s AXP INTEGER,", line);
	Format(line, 4096, "%s KTcount INTEGER,", line);
	Format(line, 4096, "%s Str INTEGER,", line);
	Format(line, 4096, "%s Agi INTEGER,", line);
	Format(line, 4096, "%s Hea INTEGER,", line);
	Format(line, 4096, "%s End INTEGER,", line);
	Format(line, 4096, "%s Int INTEGER,", line);
	Format(line, 4096, "%s HealLv INTEGER,", line);
	Format(line, 4096, "%s EQLv INTEGER,", line);
	Format(line, 4096, "%s RegLv INTEGER,", line);
	Format(line, 4096, "%s SILv INTEGER,", line);
	Format(line, 4096, "%s ISLv INTEGER,", line);
	Format(line, 4096, "%s HSPLv INTEGER,", line);
	Format(line, 4096, "%s RUAtLv INTEGER,", line);
	Format(line, 4096, "%s RUAmLv INTEGER,", line);
	Format(line, 4096, "%s RURLv INTEGER,", line);
	Format(line, 4096, "%s Lottery INTEGER,", line);
	Format(line, 4096, "%s NL INTEGER,", line);
	Format(line, 4096, "%s AMLv INTEGER,", line);
	Format(line, 4096, "%s FSLv INTEGER,", line);
	Format(line, 4096, "%s SCLv INTEGER,", line);
	Format(line, 4096, "%s EELv INTEGER,", line);
	Format(line, 4096, "%s SprLv INTEGER,", line);
	Format(line, 4096, "%s IALv INTEGER,", line);
	Format(line, 4096, "%s TCLv INTEGER,", line);
	Format(line, 4096, "%s ATLv INTEGER,", line);
	Format(line, 4096, "%s TTLv INTEGER,", line);
	Format(line, 4096, "%s FBLv INTEGER,", line);
	Format(line, 4096, "%s IBLv INTEGER,", line);
	Format(line, 4096, "%s CLLv INTEGER,", line);
	Format(line, 4096, "%s HBLv INTEGER,", line);
	Format(line, 4096, "%s BSLv INTEGER,", line);
	Format(line, 4096, "%s DRLv INTEGER,", line);
	Format(line, 4096, "%s MSLv INTEGER,", line);
	Format(line, 4096, "%s DATE TEXT,", line);
	Format(line, 4096, "%s PW TEXT", line);
	Format(line, 4096, "%s);", line);
	new Handle:file = OpenFile(LogPath, "a+");
	WriteFileLine(file, "开始创建表：");
	WriteFileLine(file, line);
	SQL_TQuery(g_hDataBase, T_FastQuery, line);
	WriteFileLine(file, "创建结束...");
	CloseHandle(file);
}
#endif
public T_FastQuery(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual(error, ""))
	{
		PrintToServer(error);
		new Handle:file = OpenFile(LogPath, "a+");
		WriteFileLine(file, error);
		CloseHandle(file);
	}
}

public Action:Command_BuyEquip(client, args)
{
	if(client <= 0 || IsFakeClient(client) || GetClientTeam(client) != 2) return Plugin_Continue;
	
	MenuFunc_NormalItemShop(client);
	return Plugin_Continue;
}

public Action:Command_BuyAmmo1(client, args)
{
	new needcash = GetConVarInt(CfgNormalItemCost[0]);
	if(client <= 0 || IsFakeClient(client) || GetPlayerWeaponSlot(client, 0) == -1 || Cash[client] < needcash) return Plugin_Continue;
	
	CheatCommand(client, "give", "ammo");
	Cash[client] -= needcash;
	return Plugin_Continue;
}

public Action:Command_BuyMenu(client, args)
{
	if(client <= 0 || IsFakeClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;
	
	if(GetClientTeam(client) == 2)
	{
		MenuFunc_SurvivorBuy(client, false);
	}
	else if(GetClientTeam(client) == 3)
	{
		MenuFunc_InfectedShop(client, false);
	}
	return Plugin_Continue;
}

GetConVar()
{
  	robot_reactiontime=GetConVarFloat(RobotReactiontime);
 	robot_energy=GetConVarFloat(RobotEnergy)*60.0;
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVar();
}

static InitUncommonDataArray()
{
	Format(UncommonData[riot][infectedname], 		9, 		"riot");
	Format(UncommonData[ceda][infectedname], 		9, 		"ceda");
	Format(UncommonData[clown][infectedname],		9, 		"clown");
	Format(UncommonData[mudman][infectedname],		9, 		"mud");
	Format(UncommonData[roadcrew][infectedname],	9, 		"roadcrew");
	Format(UncommonData[jimmy][infectedname], 		9, 		"jimmy");
	Format(UncommonData[fallen][infectedname], 		9, 		"fallen");
	Format(UncommonData[witch][infectedname], 		9, 		"witch");

	Format(UncommonData[riot][infectedmodel], 		64, 		"models/infected/common_male_riot.mdl");
	Format(UncommonData[ceda][infectedmodel], 		64, 		"models/infected/common_male_ceda.mdl");
	Format(UncommonData[clown][infectedmodel],		64, 		"models/infected/common_male_clown.mdl");
	Format(UncommonData[mudman][infectedmodel], 	64, 		"models/infected/common_male_mud.mdl");
	Format(UncommonData[roadcrew][infectedmodel],	64, 		"models/infected/common_male_roadcrew.mdl");
	Format(UncommonData[jimmy][infectedmodel],		64, 		"models/infected/common_male_jimmy.mdl");
	Format(UncommonData[fallen][infectedmodel],		64, 		"models/infected/common_male_fallen_survivor.mdl");
	Format(UncommonData[witch][infectedmodel],		64, 		"models/infected/witch_bride.mdl");
}

static Initialization(i)
{
	JD[i]=0, Lv[i]=0, EXP[i]=0, Cash[i]=0, KTCount[i]=0, RobotCount[i]=0, WLBH[i]=0, AXP[i]=0, Qstr[i]=0, Shitou[i]=0, Shilv[i]=0,Qgl[i]=0,
	Str[i]=0, Agi[i]=0, Health[i]=0, Endurance[i]=0, Intelligence[i]=0,
	StatusPoint[i]=0, SkillPoint[i]=0, HealingLv[i]=0, EndranceQualityLv[i]=0,
	HPRegenerationLv[i]=0, SuperInfectedLv[i]=0, InfectedSummonLv[i]=0, SuperPounceLv[i]=0,
	Baoshu[i]=0, Baoliao[i]=0, Baojia[i]=0, Baozhan[i]=0, Baoxie[i]=0, Baodian[i]=0, Lis[i]=0,
	AmmoMakingLv[i]=0, FireSpeedLv[i]=0, SatelliteCannonLv[i]=0,
	EnergyEnhanceLv[i]=0, SprintLv[i]=0, InfiniteAmmoLv[i]=0,
	BioShieldLv[i]=0, DamageReflectLv[i]=0, MeleeSpeedLv[i]=0,
	defibrillator[i]=0, TeleportToSelectLv[i]=0, AppointTeleportLv[i]=0, TeleportTeamLv[i]=0, HealingBallLv[i]=0,
	FireBallLv[i]=0, IceBallLv[i]=0, ChainLightningLv[i]=0, 
	RobotUpgradeLv[i][0]=0, RobotUpgradeLv[i][1]=0, RobotUpgradeLv[i][2]=0, Lottery[i]=0,

	JobChooseBool[i]=false,
	IsSuperInfectedEnable[i]=false,
	IsSatelliteCannonReady[i]=true,
	IsSprintEnable[i]=false,
	IsInfiniteAmmoEnable[i]=false,
	IsBioShieldEnable[i]=false,
	IsBioShieldReady[i]=true,
	IsDamageReflectEnable[i]=false,
	IsMeleeSpeedEnable[i]=false,
	IsTeleportTeamEnable[i]=false,
	IsAppointTeleportEnable[i]=false,
	IsTeleportToSelectEnable[i]=false,
	HealingBallExp[i] = 0,
	IsHealingBallEnable[i] = false,
	IsPasswordConfirm[i]=false;
	IsAdmin[i]=false;
	PlayerAliveTime[i] = 0;
	
	/* 停止检查经验Timer */
	if(CheckExpTimer[i] != INVALID_HANDLE)
	{
		KillTimer(CheckExpTimer[i]);
		CheckExpTimer[i] = INVALID_HANDLE;
	}
	KillAllClientSkillTimer(i);
}

KillAllClientSkillTimer(Client)
{
	/* 停止生命再生Timer */
	if (HPRegenTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(HPRegenTimer[Client]);
		HPRegenTimer[Client] = INVALID_HANDLE;
	}
	/* 停止生命再生(受伤)Timer */
	if(DamageStopTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(DamageStopTimer[Client]);
		DamageStopTimer[Client] = INVALID_HANDLE;
	}
	/* 停止特感普通攻击Timer */
	if(HurtCountTimer[Client] != INVALID_HANDLE)
	{
		HurtCount[Client] = 0;
		KillTimer(HurtCountTimer[Client]);
		HurtCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止特感召唤普通攻击Timer */
	if(SummonHurtCountTimer[Client] != INVALID_HANDLE)
	{
		SummonHurtCount[Client] = 0;
		KillTimer(SummonHurtCountTimer[Client]);
		SummonHurtCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止Spitter攻击Timer */
	if(SpitCountTimer[Client] != INVALID_HANDLE)
	{
		SpitCount[Client] = 0;
		KillTimer(SpitCountTimer[Client]);
		SpitCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止击杀丧尸Timer */
	if(ZombiesKillCountTimer[Client] != INVALID_HANDLE)
	{
		ZombiesKillCount[Client] = 0;
		KillTimer(ZombiesKillCountTimer[Client]);
		ZombiesKillCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止召唤尸被击杀Timer */
	if(SummonKilledCountTimer[Client] != INVALID_HANDLE)
	{
		SummonKilledCount[Client] = 0;
		KillTimer(SummonKilledCountTimer[Client]);
		SummonKilledCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止召唤尸消失Timer */
	if(SummonDisappearedCountTimer[Client] != INVALID_HANDLE)
	{
		SummonDisappearedCount[Client] = 0;
		KillTimer(SummonDisappearedCountTimer[Client]);
		SummonDisappearedCountTimer[Client] = INVALID_HANDLE;
	}
	/* 停止超级特感生命週期Timer */
	if(SuperInfectedLifeTimeTimer[Client] != INVALID_HANDLE)
	{
		IsSuperInfectedEnable[Client] = false;
		KillTimer(SuperInfectedLifeTimeTimer[Client]);
		SuperInfectedLifeTimeTimer[Client] = INVALID_HANDLE;
	}
	/*  停止治疗术Timer */
	if(HealingTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(HealingTimer[Client]);
		HealingTimer[Client] = INVALID_HANDLE;
	}

	if(JD[Client] > 0)
	{
		if(JD[Client] == 1)
		{
			/* 停止卫星炮CD Timer */
			if(SatelliteCannonCDTimer[Client] != INVALID_HANDLE)
			{
				IsSatelliteCannonReady[Client] = true;
				KillTimer(SatelliteCannonCDTimer[Client]);
				SatelliteCannonCDTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 2)
		{
			/* 停止加速冲刺术效果Timer */
			if(SprinDurationTimer[Client] != INVALID_HANDLE)
			{
				IsSprintEnable[Client] = false;
				RebuildStatus(Client, false);
				KillTimer(SprinDurationTimer[Client]);
				SprinDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止无限子弹术效果Timer */
			if(InfiniteAmmoDurationTimer[Client] != INVALID_HANDLE)
			{
				IsInfiniteAmmoEnable[Client] = false;
				KillTimer(InfiniteAmmoDurationTimer[Client]);
				InfiniteAmmoDurationTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 3)
		{
			/* 停止无敌术效果Timer */
			if(BioShieldDurationTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldEnable[Client] = false;
				SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
				KillTimer(BioShieldDurationTimer[Client]);
				BioShieldDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止无敌术CD Timer */
			if(BioShieldCDTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldReady[Client] = true;
				KillTimer(BioShieldCDTimer[Client]);
				BioShieldCDTimer[Client] = INVALID_HANDLE;
			}
			/* 停止反伤术效果Timer */
			if(DamageReflectDurationTimer[Client] != INVALID_HANDLE)
			{
				IsDamageReflectEnable[Client] = false;
				KillTimer(DamageReflectDurationTimer[Client]);
				DamageReflectDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 近战嗜血术效果Timer */
			if(MeleeSpeedDurationTimer[Client] != INVALID_HANDLE)
			{
				IsMeleeSpeedEnable[Client] = false;
				KillTimer(MeleeSpeedDurationTimer[Client]);
				MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 4)
		{
			/* 停止选择传送CD Timer */
			if(TCChargingTimer[Client] != INVALID_HANDLE)
			{
				IsTeleportToSelectEnable[Client] = false;
				KillTimer(TCChargingTimer[Client]);
				TCChargingTimer[Client] = INVALID_HANDLE;
			}
			/* 停止心灵传送CD Timer */
			if(TTChargingTimer[Client] != INVALID_HANDLE)
			{
				IsTeleportTeamEnable[Client] = false;
				KillTimer(TTChargingTimer[Client]);
				TTChargingTimer[Client] = INVALID_HANDLE;
			}
			/* 停止黑屏特效Timer */
			if(FadeBlackTimer[Client] != INVALID_HANDLE)
			{
				PerformFade(Client, 0);
				IsAppointTeleportEnable[Client] = false;
				KillTimer(FadeBlackTimer[Client]);
				FadeBlackTimer[Client] = INVALID_HANDLE;
			}
			/* 停止治疗光球Timer */
			if(HealingBallTimer[Client] != INVALID_HANDLE)
			{
				if (IsValidClient(Client) && !IsFakeClient(Client))
				{
					if(HealingBallExp[Client] > 0)
					{
						EXP[Client] += HealingBallExp[Client];
						Cash[Client] += HealingBallExp[Client]/10;
						if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]/10);
						PrintToServer("[统计] %s 的治疗光球术结束了! 总共治疗了队友 %d HP, 获得 %d Exp, %d $", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]/10);					
					}
				}
				HealingBallExp[Client] = 0;
				IsHealingBallEnable[Client] = false;
				KillTimer(HealingBallTimer[Client]);
				HealingBallTimer[Client] = INVALID_HANDLE;
			}
		}
	}

	/* 魔王坦克技能Timers */
	if(TimerUpdate[Client] != INVALID_HANDLE)
	{
		KillTimer(TimerUpdate[Client]);
		TimerUpdate[Client] = INVALID_HANDLE;
	}
	if(GetSurvivorPositionTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(GetSurvivorPositionTimer[Client]);
		GetSurvivorPositionTimer[Client] = INVALID_HANDLE;
	}
	if(FatalMirrorTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(FatalMirrorTimer[Client]);
		FatalMirrorTimer[Client] = INVALID_HANDLE;
	}
	if(AttachParticleTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(AttachParticleTimer[Client]);
		AttachParticleTimer[Client] = INVALID_HANDLE;
	}
	if(MadSpringTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(MadSpringTimer[Client]);
		MadSpringTimer[Client] = INVALID_HANDLE;
	}
	if(fadeoutTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(fadeoutTimer[Client]);
		fadeoutTimer[Client] = INVALID_HANDLE;
	}
	/*  陨石Timers */
	if(CreateStarFallTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(CreateStarFallTimer[Client]);
		CreateStarFallTimer[Client] = INVALID_HANDLE;
	}
	form_prev[Client] = DEAD;
}

/* 地图开始 */
new oldCommonHp;
public OnMapStart()
{
	//IsMapEnd = false;
	new String:map[128];
	GetCurrentMap(map, sizeof(map));
	LogToFileEx(LogPath, "---=================================================================---");
	LogToFileEx(LogPath, "--- 地图开始: %s ---", map);
	LogToFileEx(LogPath, "---=================================================================---");

	InitPrecache();

	RPGSave = CreateKeyValues("United RPG Save");
	RPGRank = CreateKeyValues("United RPG Ranking");
	BuildPath(Path_SM, SavePath, 255, "data/UnitedRPGSave.txt");
	BuildPath(Path_SM, RankPath, 255, "data/UnitedRPGRanking.txt");
	FileToKeyValues(RPGSave, SavePath);
	FileToKeyValues(RPGRank, RankPath);

	decl String:gamemode[64];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, 64);
	if(StrEqual(gamemode, "versus") || StrEqual(gamemode, "mutation12") || StrEqual(gamemode, "teamversus") || StrEqual(gamemode, "mutation11"))
		IsVersus = true;
	else IsVersus = false;

	if(IsVersus)
	{
		RoundNo = 1;
		StartScore[1] = GetTeamRoundScore(1);
		StartScore[2] = GetTeamRoundScore(2);
		if(StartScore[1] == 0 && StartScore[2] == 0)
		{
			//IsFirstMap = true;
			SurvivorLogicalTeam = 1;
			InfectedLogicalTeam = 2;
		}
		else
		{
			//IsFirstMap = false;
		}
		LogToFileEx(LogPath, "--- 地图开始(第1回合开始) - Team 1: %d积分, Team 2: %d积分 ---", StartScore[1], StartScore[2]);
		LogToFileEx(LogPath, "--- SurvivorLogicalTeam: %d, InfectedLogicalTeam: %d", SurvivorLogicalTeam, InfectedLogicalTeam);
		if(GetConVarInt(VersusScoreEnable) == 1)
		{
			Round1SurvivorScore = 0;
			Round2SurvivorScore = 0;
			//转队时间计算
			SetConVarInt(FindConVar("vs_max_team_switches"), 99, true, true);
			TeamChangeSecondLeft = GetConVarInt(VersusScoreChangeTeamTime);
			if(TeamChangeTimer != INVALID_HANDLE)
			{
				KillTimer(TeamChangeTimer);
				TeamChangeTimer = INVALID_HANDLE;
			}
			TeamChangeTimer = CreateTimer(1.0, TeamChangeTimerFunction, _, TIMER_REPEAT);
			
			//玩家贡献时间计算
			RoundPlayTime = 0;
			for (new i = 1; i <= MaxClients; i++)
			{
				PlayerAliveTime[i] = 0;
			}
			if(RoundPlayTimer != INVALID_HANDLE)
			{
				KillTimer(RoundPlayTimer);
				RoundPlayTimer = INVALID_HANDLE;
			}
			RoundPlayTimer = CreateTimer(10.0, RoundPlayTimerFunction, _, TIMER_REPEAT);
		}
	}
	
	SetConVarInt(FindConVar("director_force_tank"), 1, true, true);

	if(GetConVarInt(tankpower_rock_health)>0)
	{
		SetConVarInt(FindConVar("z_tank_throw_health"), GetConVarInt(tankpower_rock_health));
	}
	oldCommonHp = GetConVarInt(FindConVar("z_health"));
}
/* 地图结束 */
public OnMapEnd()
{
	//IsMapEnd = true;
	LogToFileEx(LogPath, "--- 地图结束 ---");
	if(IsVersus)
	{
		if(RoundNo == 2)
		{
			SwapLogicalTeam();
			SwapPlayerTeam();
		} else
		{
			UpdatePlayerTeam();
		}
	}

	CloseHandle(RPGSave);
	CloseHandle(RPGRank);
}

/* 玩家连接游戏 */
public OnClientConnected(Client)
{
	/* 读取玩家记录 */
	if(!IsFakeClient(Client))
	{
		Initialization(Client);
		hTimer_ClientTeamChange[Client] = INVALID_HANDLE;
		/* 读取玩家密码 */
		#if ENABLE_SQL
		ClientSaveToFileLoad(Client);
		if(IsClientAuthorized(Client))
		{
			decl String:auth[64];
			GetClientAuthString(Client, auth, 64);
			if(StrEqual(Password[Client], auth))
			{
				PrintToServer("%s 验证通过", auth);
				IsPasswordConfirm[Client] = true;
			}
			else
			{
				IsPasswordConfirm[Client] = false;
			}
		}
		else if(!StrEqual(Password[Client], ""))
		{
			new String:InfoPassword[PasswordLength];
			GetClientInfo(Client, "unitedrpg", InfoPassword, PasswordLength);
			if(StrEqual(Password[Client], InfoPassword))
			{
				PrintToServer("验证通过");
				IsPasswordConfirm[Client] = true;
			}
			else
			{
				IsPasswordConfirm[Client] = false;
			}
		}
		#else
		decl String:user_name[MAX_NAME_LENGTH]="";
		GetClientName(Client, user_name, sizeof(user_name));
		KvJumpToKey(RPGSave, user_name, false);
		KvGetString(RPGSave, "PW", Password[Client], PasswordLength, "");
		KvGoBack(RPGSave);
		if(StrEqual(Password[Client], "", true))	ClientSaveToFileLoad(Client);
		else
		{
			new String:InfoPassword[PasswordLength];
			GetClientInfo(Client, "unitedrpg", InfoPassword, PasswordLength);
			if(StrEqual(Password[Client], InfoPassword, true))
			{
				ClientSaveToFileLoad(Client);
				IsPasswordConfirm[Client] = true;
			}
		}
		#endif
		
		
		for(new i=1; i<=MaxClients; i++)
		{
			if(IsClientInGame(i) && i != Client && !IsFakeClient(i))	if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_PLAYER_CONNECT, Client);
		}
		LogToFileEx(LogPath, "%s连接游戏!", NameInfo(Client, simple));
		
		if(CheckExpTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(CheckExpTimer[Client]);
			CheckExpTimer[Client] = INVALID_HANDLE;
		}
		CheckExpTimer[Client] = CreateTimer(1.0, PlayerLevelAndMPUp, Client, TIMER_REPEAT);

		/*自动绑定,防止玩家数字键567890不能使用*/
		ClientCommand(Client, "bind 1 slot1");
		ClientCommand(Client, "bind 2 slot2");
		ClientCommand(Client, "bind 3 slot3");
		ClientCommand(Client, "bind 4 slot4");
		ClientCommand(Client, "bind 5 slot5");
		ClientCommand(Client, "bind 6 slot6");
		ClientCommand(Client, "bind 7 slot7");
		ClientCommand(Client, "bind 8 slot8");
		ClientCommand(Client, "bind 9 slot9");
		ClientCommand(Client, "bind 0 slot10");

		if (GetConVarInt(BindMode) == 1)	CreateTimer(30.0, Showbind, Client);
		else if (GetConVarInt(BindMode) == 2)	BindKeyFunction(Client);
	}
}

public OnClientPostAdminCheck(Client)
{
	if(!IsFakeClient(Client))
	{
		new AdminId:admin = GetUserAdmin(Client);
		if(admin != INVALID_ADMIN_ID)
			IsAdmin[Client] = true;
	}
}

/* 玩家离开游戏 */
public OnClientDisconnect(Client)
{
	/* 储存玩家记录 */
	if(!IsFakeClient(Client))
	{
		LogToFileEx(LogPath, "%s离开游戏!", NameInfo(Client, simple));
		if(StrEqual(Password[Client], "", true) || IsPasswordConfirm[Client])
			ClientSaveToFileSave(Client);

		//清除玩家资料
		Initialization(Client);
		
		if (hTimer_ClientTeamChange[Client] != INVALID_HANDLE) {
			KillTimer(hTimer_ClientTeamChange[Client]);
			hTimer_ClientTeamChange[Client] = INVALID_HANDLE;
		}
	}
}

public Action:EnterPassword(Client, args)
{
	if(IsPasswordConfirm[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ENTERPASSWORD_ALREADYCONFIRM);
		return Plugin_Handled;
	}
	else if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法:!sm_rpgpw 密码");
		return Plugin_Handled;
	}

	decl String:arg[PasswordLength];
	GetCmdArg(1, arg, PasswordLength);

	if(StrEqual(arg, "", true))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ENTERPASSWORD_BLIND);
		return Plugin_Handled;
	}

	if(StrEqual(Password[Client], "", true))
	{
		IsPasswordConfirm[Client] = true;
		strcopy(Password[Client], PasswordLength, arg);
		ClientSaveToFileLoad(Client);
		//if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ENTERPASSWORD_ACTIVATED, Password[Client]);
		//if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);
	}
	else
	{
		if(!StrEqual(arg, Password[Client], true))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_INCORRECT);
		}
		else if(StrEqual(arg, Password[Client], true))
		{
			IsPasswordConfirm[Client] = true;
			ClientSaveToFileLoad(Client);
			RebuildStatus(Client, true);
			ClientCommand(Client, "setinfo unitedrpg %s", Password[Client]);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ENTERPASSWORD_CORRECT);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);
		}
	}

	return Plugin_Handled;
}

public Action:ResetPassword(Client, args)
{
	if(!IsPasswordConfirm[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_NOTCONFIRM);
		return Plugin_Handled;
	}
	else if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法:!sm_rpgresetpw 原密码 新密码");
		return Plugin_Handled;
	}

	if(StrEqual(Password[Client], "", true)){
		//if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_NOTACTIVATED);
		//if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);
		FakeClientCommand(Client, "sm_rpgpw 12345");
	} else
	{
		decl String:arg[PasswordLength];
		decl String:arg2[PasswordLength];
		GetCmdArg(1, arg, PasswordLength);
		GetCmdArg(2, arg2, PasswordLength);

		if(!StrEqual(arg, Password[Client], true))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PASSWORD_INCORRECT);
		} else if(StrEqual(arg, Password[Client], true))
		{
			strcopy(Password[Client], PasswordLength, arg2);
			ClientSaveToFileSave(Client);
			ClientCommand(Client, "setinfo unitedrpg %s", Password[Client]);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_RESETPASSWORD_RESETED);
		}
	}

	return Plugin_Handled;
}

public Action:CleanSaveFile(Handle:timer)
{
	decl String:section[256];
	decl String:curDayStr[8] = "";
	decl String:curYearStr[8] = "";

	FormatTime(curDayStr,sizeof(curDayStr),"%j");
	FormatTime(curYearStr,sizeof(curYearStr),"%Y");

	new curDay	= StringToInt(curDayStr);
	new curYear	= StringToInt(curYearStr);
	new delDays	= GetConVarInt(CleanSaveFileDays);


	KvGotoFirstSubKey(RPGSave);

	new statsEntries = 1;
	new statsChecked = 0;

	while (KvGotoNextKey(RPGSave))
	{
		statsEntries++;
	}
	PrintToServer("[统计] 今天是 %d 年的第 %d 天,存档总计: %d个,清理进行中...", curYear, curDay, statsEntries);
	KvRewind(RPGSave);
	KvGotoFirstSubKey(RPGSave);
	while (statsChecked < statsEntries)
	{
		statsChecked++;

		KvGetSectionName(RPGSave, section, 256);

		decl String:lastConnStr[128] = "";
		KvGetString(RPGSave,"DATE",lastConnStr,sizeof(lastConnStr),"Failed");

		if (!StrEqual(lastConnStr, "Failed", false)) //"%j:0-%Y" 000:0-0000
		{
			new String:lastDayStr[8], String:IsAdminStr[8], String:lastYearStr[8];

			lastDayStr[0] = lastConnStr[0];
			lastDayStr[1] = lastConnStr[1];
			lastDayStr[2] = lastConnStr[2];
			new lastDay	= StringToInt(lastDayStr);

			IsAdminStr[0] = lastConnStr[4];
			new isAdmin = StringToInt(IsAdminStr);

			lastYearStr[0] = lastConnStr[6];
			lastYearStr[1] = lastConnStr[7];
			lastYearStr[2] = lastConnStr[8];
			lastYearStr[3] = lastConnStr[9];
			new lastYear = StringToInt(lastYearStr);

			new daysSinceVisit = (curDay+((curYear-lastYear)*365)) - lastDay;
			//PrintToServer("%s, admin:%d, date:%s, %d天未上线", section, isAdmin, lastConnStr, daysSinceVisit);

			if (daysSinceVisit > delDays-1 && delDays != 0)
			{
				if (isAdmin==1)
				{
					KvGotoNextKey(RPGSave);
					PrintToServer("[统计] 略过删除 %s 的存档! (原因: 管理员)", section);
				}
				else if(KvGetNum(RPGSave, "Lv", 0) >= 50 || KvGetNum(RPGSave, "NL", 0) >=1)
				{
					KvGotoNextKey(RPGSave);
					PrintToServer("[统计] 略过删除 %s 的存档! (原因: 等级 >= 50 或 已转生)", section);
				}
				else
				{
					KvDeleteThis(RPGSave);
					PrintToServer("[统计] 删除 %s 的存档! (原因: %d天未上线 且 等级 小于获得等于 50 且 未转生)", section, daysSinceVisit);
				}
			}
			else KvGotoNextKey(RPGSave);
		}
		else KvDeleteThis(RPGSave);
	}

	KvRewind(RPGSave);
	KeyValuesToFile(RPGSave, SavePath);
	return Plugin_Handled;
}
/* 读取存档Function */
ClientSaveToFileLoad(Client)
#if ENABLE_SQL
{
	/* 读取玩家姓名 */
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));
	if(StrContains(user_name, "(1)", false) == 0 || StrContains(user_name, "(2)", false) == 0 || StrContains(user_name, "(3)", false) == 0 || StrEqual(user_name, "百度求生之路吧欢迎您", false)) return;
	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
	ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
	ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
	//SQL_EscapeString(g_hDataBase, user_name, user_name, 64);
	
	// 读数据库
	new String:line[4096];
	Format(line, 4096, "SELECT", line);
	Format(line, 4096, "%s LV,", line);
	Format(line, 4096, "%s EXP,", line);
	Format(line, 4096, "%s Job,", line);
	Format(line, 4096, "%s Bshu,", line);
	Format(line, 4096, "%s Bliao,", line);
	Format(line, 4096, "%s Bjia,", line);
	Format(line, 4096, "%s Bzhan,", line);
	Format(line, 4096, "%s Bxie,", line);
	Format(line, 4096, "%s Bdian,", line);
	Format(line, 4096, "%s LIS,", line);
	Format(line, 4096, "%s Shitou,", line);
	Format(line, 4096, "%s Qgl,", line);
	Format(line, 4096, "%s Shilv,", line);
	Format(line, 4096, "%s Qstr,", line);
	Format(line, 4096, "%s WLBH,", line);
	Format(line, 4096, "%s SP,", line);
	Format(line, 4096, "%s KSP,", line);
	Format(line, 4096, "%s CASH,", line);
	Format(line, 4096, "%s AXP,", line);
	Format(line, 4096, "%s KTcount,", line);
	Format(line, 4096, "%s Str,", line);
	Format(line, 4096, "%s Agi,", line);
	Format(line, 4096, "%s Hea,", line);
	Format(line, 4096, "%s End,", line);
	Format(line, 4096, "%s Int,", line);
	Format(line, 4096, "%s HealLv,", line);
	Format(line, 4096, "%s EQLv,", line);
	Format(line, 4096, "%s RegLv,", line);
	Format(line, 4096, "%s SILv,", line);
	Format(line, 4096, "%s ISLv,", line);
	Format(line, 4096, "%s HSPLv,", line);
	Format(line, 4096, "%s RUAtLv,", line);
	Format(line, 4096, "%s RUAmLv,", line);
	Format(line, 4096, "%s RURLv,", line);
	Format(line, 4096, "%s Lottery,", line);
	Format(line, 4096, "%s NL,", line);
	Format(line, 4096, "%s AMLv,", line);
	Format(line, 4096, "%s FSLv,", line);
	Format(line, 4096, "%s SCLv,", line);
	Format(line, 4096, "%s EELv,", line);
	Format(line, 4096, "%s SprLv,", line);
	Format(line, 4096, "%s IALv,", line);
	Format(line, 4096, "%s TCLv,", line);
	Format(line, 4096, "%s ATLv,", line);
	Format(line, 4096, "%s TTLv,", line);
	Format(line, 4096, "%s FBLv,", line);
	Format(line, 4096, "%s IBLv,", line);
	Format(line, 4096, "%s CLLv,", line);
	Format(line, 4096, "%s HBLv,", line);
	Format(line, 4096, "%s BSLv,", line);
	Format(line, 4096, "%s DRLv,", line);
	Format(line, 4096, "%s MSLv,", line);
	Format(line, 4096, "%s PW", line);
	Format(line, 4096, "%s FROM l4d2UnitedRPGn WHERE name = '%s' LIMIT 1;", line, user_name);
	new Handle:file = OpenFile(LogPath, "a+");
	WriteFileLine(file, "开始读取玩家信息：");
	WriteFileLine(file, line);
	SQL_TQuery(g_hDataBase, T_LoadPlayer, line, Client);
	WriteFileLine(file, "读取玩家信息结束...");
	CloseHandle(file);
}
#else
{
	/* 读取玩家姓名 */
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));
	if(StrContains(user_name, "(1)", false) == 0 || StrContains(user_name, "(2)", false) == 0 || StrContains(user_name, "(3)", false) == 0 || StrEqual(user_name, "百度求生之路吧欢迎您", false)) return;
	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
	ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
	ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
	
	/* 读取玩家资料 */
	KvJumpToKey(RPGSave, user_name, true);

	JD[Client]						=	KvGetNum(RPGSave, "Job", 0);
	Lv[Client]						=	KvGetNum(RPGSave, "LV", 0);
	EXP[Client]					=	KvGetNum(RPGSave, "EXP", 0);
	Cash[Client]					=	KvGetNum(RPGSave, "CASH", 0);
	AXP[Client]					=	KvGetNum(RPGSave, "AXP", 0);
	KTCount[Client]				=	KvGetNum(RPGSave, "KTcount", 0);
	Str[Client]					=	KvGetNum(RPGSave, "Str", 0);
	Agi[Client]					=	KvGetNum(RPGSave, "Agi", 0);
	Health[Client]				=	KvGetNum(RPGSave, "Hea", 0);
	Endurance[Client]				=	KvGetNum(RPGSave, "End", 0);
	Qstr[Client]					=	KvGetNum(RPGSave, "Qstr", 0);
	Agi[Client]					=	KvGetNum(RPGSave, "Agi", 0);
	Qgl[Client]					=	KvGetNum(RPGSave, "Qgl",0);
	Shilv[Client]					=	KvGetNum(RPGSave, "Shilv", 0);
	Shitou[Client]					=	KvGetNum(RPGSave, "Shitou", 0);
	Intelligence[Client]			=	KvGetNum(RPGSave, "Int", 0);
	StatusPoint[Client]			=	KvGetNum(RPGSave, "SP", 0);
	SkillPoint[Client]			=	KvGetNum(RPGSave, "KSP", 0);
	Baoshu[Client]                 =	KvGetNum(RPGSave, "Bshu", 0);
	Baoliao[Client]                 =	KvGetNum(RPGSave, "Bliao", 0);
	Baodian[Client]                 =	KvGetNum(RPGSave, "Bdian", 0);
	Baojia[Client]                 =	KvGetNum(RPGSave, "Bjia", 0);
	Baozhan[Client]                 =	KvGetNum(RPGSave, "Bzhan", 0);
	Baoxie[Client]                 =	KvGetNum(RPGSave, "Bxie", 0);
	Lis[Client]                 =	KvGetNum(RPGSave, "LIS", 0);
	WLBH[Client]                =  KvGetNum(RPGSave, "WLBH", 0);
	HealingLv[Client]				=	KvGetNum(RPGSave, "HealLv", 0);//治癒术等级
	EndranceQualityLv[Client]			=	KvGetNum(RPGSave, "EQLv", 0);//强化甦醒术等级
	HPRegenerationLv[Client]		=	KvGetNum(RPGSave, "RegLv", 0);//再生术等级
	SuperInfectedLv[Client]		=	KvGetNum(RPGSave, "SILv", 0);//超级特感等级
	InfectedSummonLv[Client]		=	KvGetNum(RPGSave, "ISLv", 0);//召唤术感等级
	SuperPounceLv[Client]	=	KvGetNum(RPGSave, "HSPLv", 0);//飞扑爆击术感等级
	RobotUpgradeLv[Client][0]	=	KvGetNum(RPGSave, "RUAtLv", 0);//Robot攻击力等级
	RobotUpgradeLv[Client][1]	=	KvGetNum(RPGSave, "RUAmLv", 0);//Robot弹匣系统等级
	RobotUpgradeLv[Client][2]	=	KvGetNum(RPGSave, "RURLv", 0);//Robot侦查距离等级
	Lottery[Client]				=	KvGetNum(RPGSave, "Lottery", 0);//彩票卷
	NewLifeCount[Client]			=	KvGetNum(RPGSave, "NL", 0);//转生次数
	
	if(JD[Client] > 0)
	{
		JobChooseBool[Client] = true;
		if(JD[Client] == 1)//工程师
		{
			AmmoMakingLv[Client]			=	KvGetNum(RPGSave, "AMLv", 0);//子弹制造术等级
			FireSpeedLv[Client]			=   KvGetNum(RPGSave, "FSLv", 0);//射速加强术等级
			SatelliteCannonLv[Client]		=   KvGetNum(RPGSave, "SCLv", 0);//卫星炮术等级
		} else if(JD[Client] == 2)//士兵
		{
			EnergyEnhanceLv[Client]	=	KvGetNum(RPGSave, "EELv", 0);//攻防强化术等级
			SprintLv[Client]				=	KvGetNum(RPGSave, "SprLv", 0);//加速冲刺术等级
			InfiniteAmmoLv[Client]		=	KvGetNum(RPGSave, "IALv", 0);//无限子弹术等级
		} else if(JD[Client] == 3)//生物专家
		{
			BioShieldLv[Client]			=	KvGetNum(RPGSave, "BSLv", 0);//无敌术等级
			DamageReflectLv[Client]		=	KvGetNum(RPGSave, "DRLv", 0);//反伤术等级
			MeleeSpeedLv[Client]			=	KvGetNum(RPGSave, "MSLv", 0);//近战嗜血术等级
		} else if(JD[Client] == 4)//心灵医师
		{
			defibrillator[Client] = 2;
			TeleportToSelectLv[Client]	=	KvGetNum(RPGSave, "TCLv", 0);//选择传送术等级
			AppointTeleportLv[Client]	=	KvGetNum(RPGSave, "ATLv", 0);//目标传送术等级
			TeleportTeamLv[Client]		=	KvGetNum(RPGSave, "TTLv", 0);//心灵传送术等级
			HealingBallLv[Client]		=	KvGetNum(RPGSave, "HBLv", 0);//治疗光球术等级
		} else if(JD[Client] == 5)//魔法师
		{
			FireBallLv[Client]	=	KvGetNum(RPGSave, "FBLv", 0);//火球术等级
			IceBallLv[Client]	=	KvGetNum(RPGSave, "IBLv", 0);//冰球术等级
			ChainLightningLv[Client]	=	KvGetNum(RPGSave, "CLLv", 0);//连锁闪电术等级
		}
	} else JobChooseBool[Client] = false;

	KvGoBack(RPGSave);
	PrintToServer("[统计] %N的Save已读取!", Client);
}
#endif

public T_LoadPlayer(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	new String:name[64];
	GetClientName(client, name, 64);
	if(IsFakeClient(client) || StrEqual(name, "", false))
	{
		PrintToServer("读取失败...句柄无效或名字为空。");
		return;
	}
	ReplaceString(name, sizeof(name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(name, sizeof(name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(name, sizeof(name), "/*", "{SST}");//SST Slash Star
	ReplaceString(name, sizeof(name), "*/", "{STS}");//STS Star Slash
	ReplaceString(name, sizeof(name), "//", "{DSL}");//DSL Double Slash
	SQL_EscapeString(hndl, name, name, 64);
	
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_FetchRow(hndl))
		{
			PrintToServer("读取开始...");
			Lv[client] = SQL_FetchInt(hndl, 0);
			EXP[client] = SQL_FetchInt(hndl, 1);
			JD[client] = SQL_FetchInt(hndl, 2);
			
			Baoshu[client] = SQL_FetchInt(hndl, 3);
			Baoliao[client] = SQL_FetchInt(hndl, 4);
			Baojia[client] = SQL_FetchInt(hndl, 5);
			Baozhan[client] = SQL_FetchInt(hndl, 6);
			Baoxie[client] = SQL_FetchInt(hndl, 7);
			Baodian[client] = SQL_FetchInt(hndl, 8);
			
			Lis[client] = SQL_FetchInt(hndl, 9);
			Shitou[client] = SQL_FetchInt(hndl, 10);
			Qgl[client] = SQL_FetchInt(hndl, 11);
			Shilv[client] = SQL_FetchInt(hndl, 12);
			Qstr[client] = SQL_FetchInt(hndl, 13);
			
			WLBH[client] = SQL_FetchInt(hndl, 14);
			StatusPoint[client] = SQL_FetchInt(hndl, 15);
			SkillPoint[client] = SQL_FetchInt(hndl, 16);
			Cash[client] = SQL_FetchInt(hndl, 17);
			AXP[client] = SQL_FetchInt(hndl, 18);
			KTCount[client] = SQL_FetchInt(hndl, 19);
			
			Str[client] = SQL_FetchInt(hndl, 20);
			Agi[client] = SQL_FetchInt(hndl, 21);
			Health[client] = SQL_FetchInt(hndl, 22);
			Endurance[client] = SQL_FetchInt(hndl, 23);
			Intelligence[client] = SQL_FetchInt(hndl, 24);
			
			HealingLv[client] = SQL_FetchInt(hndl, 25);
			EndranceQualityLv[client] = SQL_FetchInt(hndl, 26);
			HPRegenerationLv[client] = SQL_FetchInt(hndl, 27);
			SuperInfectedLv[client] = SQL_FetchInt(hndl, 28);
			InfectedSummonLv[client] = SQL_FetchInt(hndl, 29);
			SuperPounceLv[client] = SQL_FetchInt(hndl, 30);
			
			RobotUpgradeLv[client][0] = SQL_FetchInt(hndl, 31);
			RobotUpgradeLv[client][1] = SQL_FetchInt(hndl, 32);
			RobotUpgradeLv[client][2] = SQL_FetchInt(hndl, 33);
			Lottery[client] = SQL_FetchInt(hndl, 34);
			NewLifeCount[client] = SQL_FetchInt(hndl, 35);
			
			AmmoMakingLv[client] = SQL_FetchInt(hndl, 36);
			FireSpeedLv[client] = SQL_FetchInt(hndl, 37);
			SatelliteCannonLv[client] = SQL_FetchInt(hndl, 38);
			EnergyEnhanceLv[client] = SQL_FetchInt(hndl, 39);
			SprintLv[client] = SQL_FetchInt(hndl, 40);
			InfiniteAmmoLv[client] = SQL_FetchInt(hndl, 41);
			TeleportToSelectLv[client] = SQL_FetchInt(hndl, 42);
			AppointTeleportLv[client] = SQL_FetchInt(hndl, 43);
			TeleportTeamLv[client] = SQL_FetchInt(hndl, 44);
			FireBallLv[client] = SQL_FetchInt(hndl, 45);
			IceBallLv[client] = SQL_FetchInt(hndl, 46);
			ChainLightningLv[client] = SQL_FetchInt(hndl, 47);
			BioShieldLv[client] = SQL_FetchInt(hndl, 48);
			DamageReflectLv[client] = SQL_FetchInt(hndl, 49);
			MeleeSpeedLv[client] = SQL_FetchInt(hndl, 50);
			HealingBallLv[client] = SQL_FetchInt(hndl, 51);
			SQL_FetchString(hndl, 52, Password[client], PasswordLength);
		}
		else
		{
			PrintToServer("创建开始...");
			
			Lv[client] = 0;
			EXP[client] = 0;
			JD[client] = 0;
			
			Baoshu[client] = 0;
			Baoliao[client] = 0;
			Baojia[client] = 0;
			Baozhan[client] = 0;
			Baoxie[client] = 0;
			Baodian[client] = 0;
			
			Lis[client] = 0;
			Shitou[client] = 0;
			Qgl[client] = 0;
			Shilv[client] = 0;
			Qstr[client] = 0;
			
			WLBH[client] = 0;
			StatusPoint[client] = 0;
			SkillPoint[client] = 0;
			Cash[client] = 0;
			AXP[client] = 0;
			KTCount[client] = 0;
			
			Str[client] = 0;
			Agi[client] = 0;
			Health[client] = 0;
			Endurance[client] = 0;
			Intelligence[client] = 0;
			
			HealingLv[client] = 0;
			EndranceQualityLv[client] = 0;
			HPRegenerationLv[client] = 0;
			SuperInfectedLv[client] = 0;
			InfectedSummonLv[client] = 0;
			SuperPounceLv[client] = 0;
			
			RobotUpgradeLv[client][0] = 0;
			RobotUpgradeLv[client][1] = 0;
			RobotUpgradeLv[client][2] = 0;
			Lottery[client] = 0;
			NewLifeCount[client] = 0;
			
			AmmoMakingLv[client] = 0;
			FireSpeedLv[client] = 0;
			SatelliteCannonLv[client] = 0;
			EnergyEnhanceLv[client] = 0;
			SprintLv[client] = 0;
			InfiniteAmmoLv[client] = 0;
			TeleportToSelectLv[client] = 0;
			AppointTeleportLv[client] = 0;
			TeleportTeamLv[client] = 0;
			FireBallLv[client] = 0;
			IceBallLv[client] = 0;
			ChainLightningLv[client] = 0;
			BioShieldLv[client] = 0;
			DamageReflectLv[client] = 0;
			MeleeSpeedLv[client] = 0;
			HealingBallLv[client] = 0;
			new String:line[4096];
			Format(line, 4096, "INSERT INTO l4d2UnitedRPGn VALUES ('%s',", name);
			Format(line, 4096, "%s 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,", line);
			decl String:DisconnectDate[128] = "";
			if(IsAdmin[client])
				FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:1-%Y/%m/%d %H:%M:%S");
			else
				FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:0-%Y/%m/%d %H:%M:%S");
			Format(line, 4096, "%s '%s',", line, DisconnectDate);
			if(IsClientAuthorized(client))
			{
				decl String:auth[64];
				GetClientAuthString(client, auth, 64);
				Format(Password[client], PasswordLength, auth);
				Format(line, 4096, "%s '%s'", line, auth);
			}
			else
			{
				Format(Password[client], PasswordLength, "");
				Format(line, 4096, "%s '%s'", line, "");
			}
			new Handle:file = OpenFile(LogPath, "a+");
			WriteFileLine(file, "开始创建玩家信息：");
			//Format(line, 4096, "INSERT INTO l4d2UnitedRPGn (name, DATE, PW) VALUES ('%s', '%s', '%s');", name, DisconnectDate, Password[client]);
			Format(line, 4096, "%s);");
			WriteFileLine(file, line);
			SQL_TQuery(g_hDataBase, T_FastQuery, line);
			WriteFileLine(file, "创建结束...");
			CloseHandle(file);
		}
		PrintToServer("[统计] %s 的 信息 已读取!", NameInfo(client, simple));
	}
}

/* 存档Function */
ClientSaveToFileSave(client)
#if ENABLE_SQL
{
	/* 读取玩家姓名 */
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(client, user_name, sizeof(user_name));
	if(StrContains(user_name, "(1)", false) == 0 || StrContains(user_name, "(2)", false) == 0 || StrContains(user_name, "(3)", false) == 0 || StrEqual(user_name, "百度求生之路吧欢迎您", false)) return;
	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
	ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
	ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
	//SQL_EscapeString(g_hDataBase, user_name, user_name, 64);
	
	new String:line[4096];
	/*
	Format(line, 4096, "UPDATE l4d2UnitedRPGn SET");
	Format(line, 4096, "%s%d, ", line, Lv[client]);
	Format(line, 4096, "%s EXP = %d,", line, EXP[client]);
	Format(line, 4096, "%s Job = %d,", line, JD[client]);
	
	Format(line, 4096, "%s Bshu = %d,", line, Baoshu[client]);
	Format(line, 4096, "%s Bliao = %d,", line, Baoliao[client]);
	Format(line, 4096, "%s Bjia = %d,", line, Baojia[client]);
	Format(line, 4096, "%s Bzhan = %d,", line, Baozhan[client]);
	Format(line, 4096, "%s Bxie = %d,", line, Baoxie[client]);
	Format(line, 4096, "%s Bdian = %d,", line, Baodian[client]);
	
	Format(line, 4096, "%s LIS = %d,", line, Lis[client]);
	Format(line, 4096, "%s Shitou = %d,", line, Shitou[client]);
	Format(line, 4096, "%s Qgl = %d,", line, Qgl[client]);
	Format(line, 4096, "%s Shilv = %d,", line, Shilv[client]);
	Format(line, 4096, "%s Qstr = %d,", line, Qstr[client]);
	
	Format(line, 4096, "%s WLBH = %d,", line, WLBH[client]);
	Format(line, 4096, "%s SP = %d,", line, StatusPoint[client]);
	Format(line, 4096, "%s KSP = %d,", line, SkillPoint[client]);
	Format(line, 4096, "%s CASH = %d,", line, Cash[client]);
	Format(line, 4096, "%s AXP = %d,", line, AXP[client]);
	Format(line, 4096, "%s KTcount = %d,", line, KTCount[client]);
	
	Format(line, 4096, "%s Str = %d,", line, Str[client]);
	Format(line, 4096, "%s Agi = %d,", line, Agi[client]);
	Format(line, 4096, "%s Hea = %d,", line, Health[client]);
	Format(line, 4096, "%s End = %d,", line, Endurance[client]);
	Format(line, 4096, "%s Int = %d,", line, Intelligence[client]);
	
	Format(line, 4096, "%s HealLv = %d,", line, HealingLv[client]);
	Format(line, 4096, "%s EQLv = %d,", line, EndranceQualityLv[client]);
	Format(line, 4096, "%s RegLv = %d,", line, HPRegenerationLv[client]);
	Format(line, 4096, "%s SILv = %d,", line, SuperInfectedLv[client]);
	Format(line, 4096, "%s ISLv = %d,", line, InfectedSummonLv[client]);
	Format(line, 4096, "%s HSPLv = %d,", line, SuperPounceLv[client]);
	
	Format(line, 4096, "%s RUAtLv = %d,", line, RobotUpgradeLv[client][0]);
	Format(line, 4096, "%s RUAmLv = %d,", line, RobotUpgradeLv[client][1]);
	Format(line, 4096, "%s RURLv = %d,", line, RobotUpgradeLv[client][2]);
	Format(line, 4096, "%s Lottery = %d,", line, Lottery[client]);
	Format(line, 4096, "%s NL = %d,", line, NewLifeCount[client]);
	
	Format(line, 4096, "%s AMLv = %d,", line, AmmoMakingLv[client]);
	Format(line, 4096, "%s FSLv = %d,", line, FireSpeedLv[client]);
	Format(line, 4096, "%s SCLv = %d,", line, SatelliteCannonLv[client]);
	Format(line, 4096, "%s EELv = %d,", line, EnergyEnhanceLv[client]);
	Format(line, 4096, "%s SprLv = %d,", line, SprintLv[client]);
	Format(line, 4096, "%s IALv = %d,", line, InfiniteAmmoLv[client]);
	Format(line, 4096, "%s TCLv = %d,", line, TeleportToSelectLv[client]);
	Format(line, 4096, "%s ATLv = %d,", line, AppointTeleportLv[client]);
	Format(line, 4096, "%s TTLv = %d,", line, TeleportTeamLv[client]);
	Format(line, 4096, "%s FBLv = %d,", line, FireBallLv[client]);
	Format(line, 4096, "%s IBLv = %d,", line, IceBallLv[client]);
	Format(line, 4096, "%s CLLv = %d,", line, ChainLightningLv[client]);
	Format(line, 4096, "%s HBLv = %d,", line, HealingBallLv[client]);
	Format(line, 4096, "%s BSLv = %d,", line, BioShieldLv[client]);
	Format(line, 4096, "%s DRLv = %d,", line, DamageReflectLv[client]);
	Format(line, 4096, "%s MSLv = %d,", line, MeleeSpeedLv[client]);
	*/
	Format(line, 4096, "REPLACE INTO l4d2UnitedRPGn (");
	Format(line, 4096, "%sname, LV, EXP, Job, Bshu, Bliao, Bjia, Bzhan, Bxie, Bdian, LIS, Shitou, Qgl, Shilv, Qstr, WLBH, SP, KSP, CASH, AXP, KTcount, Str, Agi, Hea, End, Int, HealLv, EQLv, RegLv, SILv, ISLv, HSPLv, RUAtLv, RUAmLv, RURLv, Lottery, NL, AMLv, FSLv, SCLv, EELv, SprLv, IALv, TCLv, ATLv, TTLv, FBLv, IBLv, CLLv, HBLv, BSLv, DRLv, MSLv, DATE, PW", line);
	Format(line, 4096, "%s) VALUES (", line);
	Format(line, 4096, "%s'%s', ", line, user_name);
	Format(line, 4096, "%s%d, ", line, Lv[client]);
	Format(line, 4096, "%s%d, ", line, EXP[client]);
	Format(line, 4096, "%s%d, ", line, JD[client]);
	Format(line, 4096, "%s%d, ", line, Baoshu[client]);
	Format(line, 4096, "%s%d, ", line, Baoliao[client]);
	Format(line, 4096, "%s%d, ", line, Baojia[client]);
	Format(line, 4096, "%s%d, ", line, Baozhan[client]);
	Format(line, 4096, "%s%d, ", line, Baoxie[client]);
	Format(line, 4096, "%s%d, ", line, Baodian[client]);
	Format(line, 4096, "%s%d, ", line, Lis[client]);
	Format(line, 4096, "%s%d, ", line, Shitou[client]);
	Format(line, 4096, "%s%d, ", line, Qgl[client]);
	Format(line, 4096, "%s%d, ", line, Shilv[client]);
	Format(line, 4096, "%s%d, ", line, Qstr[client]);
	Format(line, 4096, "%s%d, ", line, WLBH[client]);
	Format(line, 4096, "%s%d, ", line, StatusPoint[client]);
	Format(line, 4096, "%s%d, ", line, SkillPoint[client]);
	Format(line, 4096, "%s%d, ", line, Cash[client]);
	Format(line, 4096, "%s%d, ", line, AXP[client]);
	Format(line, 4096, "%s%d, ", line, KTCount[client]);
	Format(line, 4096, "%s%d, ", line, Str[client]);
	Format(line, 4096, "%s%d, ", line, Agi[client]);
	Format(line, 4096, "%s%d, ", line, Health[client]);
	Format(line, 4096, "%s%d, ", line, Endurance[client]);
	Format(line, 4096, "%s%d, ", line, Intelligence[client]);
	Format(line, 4096, "%s%d, ", line, HealingLv[client]);
	Format(line, 4096, "%s%d, ", line, EndranceQualityLv[client]);
	Format(line, 4096, "%s%d, ", line, HPRegenerationLv[client]);
	Format(line, 4096, "%s%d, ", line, SuperInfectedLv[client]);
	Format(line, 4096, "%s%d, ", line, InfectedSummonLv[client]);
	Format(line, 4096, "%s%d, ", line, SuperPounceLv[client]);
	Format(line, 4096, "%s%d, ", line, RobotUpgradeLv[client][0]);
	Format(line, 4096, "%s%d, ", line, RobotUpgradeLv[client][1]);
	Format(line, 4096, "%s%d, ", line, RobotUpgradeLv[client][2]);
	Format(line, 4096, "%s%d, ", line, Lottery[client]);
	Format(line, 4096, "%s%d, ", line, NewLifeCount[client]);
	Format(line, 4096, "%s%d, ", line, AmmoMakingLv[client]);
	Format(line, 4096, "%s%d, ", line, FireSpeedLv[client]);
	Format(line, 4096, "%s%d, ", line, SatelliteCannonLv[client]);
	Format(line, 4096, "%s%d, ", line, EnergyEnhanceLv[client]);
	Format(line, 4096, "%s%d, ", line, SprintLv[client]);
	Format(line, 4096, "%s%d, ", line, InfiniteAmmoLv[client]);
	Format(line, 4096, "%s%d, ", line, TeleportToSelectLv[client]);
	Format(line, 4096, "%s%d, ", line, AppointTeleportLv[client]);
	Format(line, 4096, "%s%d, ", line, TeleportTeamLv[client]);
	Format(line, 4096, "%s%d, ", line, FireBallLv[client]);
	Format(line, 4096, "%s%d, ", line, IceBallLv[client]);
	Format(line, 4096, "%s%d, ", line, ChainLightningLv[client]);
	Format(line, 4096, "%s%d, ", line, HealingBallLv[client]);
	Format(line, 4096, "%s%d, ", line, BioShieldLv[client]);
	Format(line, 4096, "%s%d, ", line, DamageReflectLv[client]);
	Format(line, 4096, "%s%d, ", line, MeleeSpeedLv[client]);
	decl String:DisconnectDate[128] = "";
	if(IsAdmin[client])
		FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:1-%Y/%m/%d %H:%M:%S");
	else
		FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:0-%Y/%m/%d %H:%M:%S");
	Format(line, 4096, "%s'%s', ", line, DisconnectDate);
	Format(line, 4096, "%s'%s'", line, Password[client]);
	//Format(line, 4096, "%s WHERE name = '%s';", line, user_name);
	Format(line, 4096, "%s);", line);
	new Handle:file = OpenFile(LogPath, "a+");
	WriteFileLine(file, "开始写入玩家信息：");
	WriteFileLine(file, line);
	SQL_TQuery(g_hDataBase, T_FastQuery, line);
	PrintToServer("[统计] %s 的 信息 已储存!", NameInfo(client, simple));
	WriteFileLine(file, "写入结束...");
	CloseHandle(file);
}
#else
{
	new Client = client;
	/* 读取玩家姓名 */
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));
	if(StrContains(user_name, "(1)", false) == 0 || StrContains(user_name, "(2)", false) == 0 || StrContains(user_name, "(3)", false) == 0 || StrEqual(user_name, "百度求生之路吧欢迎您", false)) return;
	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
	ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
	ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
	KvJumpToKey(RPGSave, user_name, true);
	
	KvSetNum(RPGSave, "LV", Lv[Client]);
	KvSetNum(RPGSave, "EXP", EXP[Client]);
	KvSetNum(RPGSave, "Job", JD[Client]);
	KvSetNum(RPGSave, "Bshu", Baoshu[Client]);
	KvSetNum(RPGSave, "Bliao", Baoliao[Client]);
	KvSetNum(RPGSave, "Bjia", Baojia[Client]);
	KvSetNum(RPGSave, "Bzhan", Baozhan[Client]);
	KvSetNum(RPGSave, "Bxie",  Baoxie[Client]);
	KvSetNum(RPGSave, "Bdian", Baodian[Client]);
	KvSetNum(RPGSave, "LIS", Lis[Client]);
	KvSetNum(RPGSave, "Shitou", Shitou[Client]);
	KvSetNum(RPGSave, "Qgl", Qgl[Client]);
	KvSetNum(RPGSave, "Shilv", Shilv[Client]);
	KvSetNum(RPGSave, "Qstr", Qstr[Client]);
	KvSetNum(RPGSave, "WLBH", WLBH[Client]);
	KvSetNum(RPGSave, "SP", StatusPoint[Client]);
	KvSetNum(RPGSave, "KSP", SkillPoint[Client]);
	KvSetNum(RPGSave, "CASH", Cash[Client]);
	KvSetNum(RPGSave, "AXP", AXP[Client]);
	KvSetNum(RPGSave, "KTcount", KTCount[Client]);
	KvSetNum(RPGSave, "Str", Str[Client]);
	KvSetNum(RPGSave, "Agi", Agi[Client]);
	KvSetNum(RPGSave, "Hea", Health[Client]);
	KvSetNum(RPGSave, "End", Endurance[Client]);
	KvSetNum(RPGSave, "Int", Intelligence[Client]);
	KvSetNum(RPGSave, "HealLv", HealingLv[Client]);
	KvSetNum(RPGSave, "EQLv", EndranceQualityLv[Client]);
	KvSetNum(RPGSave, "RegLv", HPRegenerationLv[Client]);
	KvSetNum(RPGSave, "SILv", SuperInfectedLv[Client]);
	KvSetNum(RPGSave, "ISLv", InfectedSummonLv[Client]);
	KvSetNum(RPGSave, "HSPLv", SuperPounceLv[Client]);
	KvSetNum(RPGSave, "RUAtLv", RobotUpgradeLv[Client][0]);
	KvSetNum(RPGSave, "RUAmLv", RobotUpgradeLv[Client][1]);
	KvSetNum(RPGSave, "RURLv", RobotUpgradeLv[Client][2]);
	KvSetString(RPGSave, "PW", Password[Client]);
	KvSetNum(RPGSave, "Lottery", Lottery[Client]);
	KvSetNum(RPGSave,  "NL", NewLifeCount[Client]);

	if(JD[Client] == 0)
	{
		KvDeleteKey(RPGSave, "AMLv");
		KvDeleteKey(RPGSave, "FSLv");
		KvDeleteKey(RPGSave, "SCLv");
		KvDeleteKey(RPGSave, "EELv");
		KvDeleteKey(RPGSave, "SprLv");
		KvDeleteKey(RPGSave, "IALv");
		KvDeleteKey(RPGSave, "BSLv");
		KvDeleteKey(RPGSave, "DRLv");
		KvDeleteKey(RPGSave, "MSLv");
		KvDeleteKey(RPGSave, "TCLv");
		KvDeleteKey(RPGSave, "ATLv");
		KvDeleteKey(RPGSave, "TTLv");
		KvDeleteKey(RPGSave, "FBLv");
		KvDeleteKey(RPGSave, "IBLv");
		KvDeleteKey(RPGSave, "CLLv");
		KvDeleteKey(RPGSave, "HBLv");
	} else if(JD[Client] == 1)
	{
		KvDeleteKey(RPGSave, "EELv");
		KvDeleteKey(RPGSave, "SprLv");
		KvDeleteKey(RPGSave, "IALv");
		KvDeleteKey(RPGSave, "BSLv");
		KvDeleteKey(RPGSave, "DRLv");
		KvDeleteKey(RPGSave, "MSLv");
		KvDeleteKey(RPGSave, "TCLv");
		KvDeleteKey(RPGSave, "ATLv");
		KvDeleteKey(RPGSave, "TTLv");
		KvDeleteKey(RPGSave, "FBLv");
		KvDeleteKey(RPGSave, "IBLv");
		KvDeleteKey(RPGSave, "CLLv");
		KvDeleteKey(RPGSave, "HBLv");
		KvSetNum(RPGSave, "AMLv", AmmoMakingLv[Client]);
		KvSetNum(RPGSave, "FSLv", FireSpeedLv[Client]);
		KvSetNum(RPGSave, "SCLv", SatelliteCannonLv[Client]);
	} else if(JD[Client] == 2)
	{
		KvDeleteKey(RPGSave, "AMLv");
		KvDeleteKey(RPGSave, "FSLv");
		KvDeleteKey(RPGSave, "SCLv");
		KvDeleteKey(RPGSave, "BSLv");
		KvDeleteKey(RPGSave, "DRLv");
		KvDeleteKey(RPGSave, "MSLv");
		KvDeleteKey(RPGSave, "TCLv");
		KvDeleteKey(RPGSave, "ATLv");
		KvDeleteKey(RPGSave, "TTLv");
		KvDeleteKey(RPGSave, "FBLv");
		KvDeleteKey(RPGSave, "IBLv");
		KvDeleteKey(RPGSave, "CLLv");
		KvDeleteKey(RPGSave, "HBLv");
		KvSetNum(RPGSave, "EELv", EnergyEnhanceLv[Client]);
		KvSetNum(RPGSave, "SprLv", SprintLv[Client]);
		KvSetNum(RPGSave, "IALv", InfiniteAmmoLv[Client]);
	} else if(JD[Client] == 3)
	{
		KvDeleteKey(RPGSave, "AMLv");
		KvDeleteKey(RPGSave, "FSLv");
		KvDeleteKey(RPGSave, "SCLv");
		KvDeleteKey(RPGSave, "EELv");
		KvDeleteKey(RPGSave, "SprLv");
		KvDeleteKey(RPGSave, "IALv");
		KvDeleteKey(RPGSave, "TCLv");
		KvDeleteKey(RPGSave, "ATLv");
		KvDeleteKey(RPGSave, "TTLv");
		KvDeleteKey(RPGSave, "FBLv");
		KvDeleteKey(RPGSave, "IBLv");
		KvDeleteKey(RPGSave, "CLLv");
		KvDeleteKey(RPGSave, "HBLv");
		KvSetNum(RPGSave, "BSLv", BioShieldLv[Client]);
		KvSetNum(RPGSave, "DRLv", DamageReflectLv[Client]);
		KvSetNum(RPGSave, "MSLv", MeleeSpeedLv[Client]);
	} else if(JD[Client] == 4)
	{
		KvDeleteKey(RPGSave, "AMLv");
		KvDeleteKey(RPGSave, "FSLv");
		KvDeleteKey(RPGSave, "SCLv");
		KvDeleteKey(RPGSave, "EELv");
		KvDeleteKey(RPGSave, "SprLv");
		KvDeleteKey(RPGSave, "IALv");
		KvDeleteKey(RPGSave, "BSLv");
		KvDeleteKey(RPGSave, "DRLv");
		KvDeleteKey(RPGSave, "MSLv");
		KvDeleteKey(RPGSave, "FBLv");
		KvDeleteKey(RPGSave, "IBLv");
		KvDeleteKey(RPGSave, "CLLv");
		KvSetNum(RPGSave, "TCLv", TeleportToSelectLv[Client]);
		KvSetNum(RPGSave, "ATLv", AppointTeleportLv[Client]);
		KvSetNum(RPGSave, "TTLv", TeleportTeamLv[Client]);
		KvSetNum(RPGSave, "HBLv", HealingBallLv[Client]);
	}
	 else if(JD[Client] == 5)
	{
		KvDeleteKey(RPGSave, "AMLv");
		KvDeleteKey(RPGSave, "FSLv");
		KvDeleteKey(RPGSave, "SCLv");
		KvDeleteKey(RPGSave, "EELv");
		KvDeleteKey(RPGSave, "SprLv");
		KvDeleteKey(RPGSave, "IALv");
		KvDeleteKey(RPGSave, "BSLv");
		KvDeleteKey(RPGSave, "DRLv");
		KvDeleteKey(RPGSave, "MSLv");
		KvDeleteKey(RPGSave, "TCLv");
		KvDeleteKey(RPGSave, "ATLv");
		KvDeleteKey(RPGSave, "TTLv");
		KvDeleteKey(RPGSave, "HBLv");
		KvSetNum(RPGSave, "FBLv", FireBallLv[Client]);
		KvSetNum(RPGSave, "IBLv", IceBallLv[Client]);
		KvSetNum(RPGSave, "CLLv", ChainLightningLv[Client]);
	}
	
	decl String:DisconnectDate[128] = "";
	if(IsAdmin[Client])
		FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:1-%Y/%m/%d %H:%M:%S");
	else
		FormatTime(DisconnectDate, sizeof(DisconnectDate), "%j:0-%Y/%m/%d %H:%M:%S");

	KvSetString(RPGSave,"DATE", DisconnectDate);
	
	KvRewind(RPGSave);
	KeyValuesToFile(RPGSave, SavePath);
	PrintToServer("[统计] %s的Save已储存!", NameInfo(Client, simple));
}
#endif
/* 读取排名Function */
LoadRanking()
{
	KvJumpToKey(RPGRank, "LV", true);
	decl String:RankNameClient[256];
	decl String:RankNameLevel[256];
	for(new r = 0; r < RankNo; r++)
	{
		Format(RankNameClient, sizeof(RankNameClient), "第%d名玩家", r+1);
		Format(RankNameLevel, sizeof(RankNameLevel), "第%d名等级", r+1);
		KvGetString(RPGRank, RankNameClient, LevelRankClient[r], 256, "未知");
		LevelRank[r] = KvGetNum(RPGRank, RankNameLevel, 0);
	}
	KvGoBack(RPGRank);
	KvJumpToKey(RPGRank, "CASH", true);
	for(new r = 0; r < RankNo; r++)
	{
		Format(RankNameClient, sizeof(RankNameClient), "第%d名玩家", r+1);
		Format(RankNameLevel, sizeof(RankNameLevel), "第%d名金钱", r+1);
		KvGetString(RPGRank, RankNameClient, CashRankClient[r], 256, "未知");
		CashRank[r] = KvGetNum(RPGRank, RankNameLevel, 0);
	}
	KvGoBack(RPGRank);
	PrintToServer("[统计] 排名已读取!");
}
/* 更新排名Function */
UpdateRanking()
{
	new LevelRankClientNo = RankNo;
	new CashRankClientNo = RankNo;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(!IsFakeClient(i))
			{
				new bool:IsInTopFiveLevel = false;
				new bool:IsInTopFiveCash = false;
				decl String:user_name[MAX_NAME_LENGTH]="";
				GetClientName(i, user_name, sizeof(user_name));
				ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
				ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
				ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
				ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
				ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
				for(new j = 0; j<RankNo; j++)
				{
					if(StrEqual(LevelRankClient[j],user_name,true))
					{
						LevelRank[j]=Lv[i];
						IsInTopFiveLevel = true;
						j = RankNo;
					}
				}
				for(new j = 0; j<RankNo; j++)
				{
					if(StrEqual(CashRankClient[j],user_name,true))
					{
						CashRank[j]=Cash[i];
						IsInTopFiveCash = true;
						j = RankNo;
					}
				}
				if(!IsInTopFiveLevel)
				{
					LevelRank[LevelRankClientNo] = Lv[i];
					strcopy(LevelRankClient[LevelRankClientNo],256,user_name);
					LevelRankClientNo++;
				}
				if(!IsInTopFiveCash)
				{
					CashRank[CashRankClientNo] = Cash[i];
					strcopy(CashRankClient[CashRankClientNo],256,user_name);
					CashRankClientNo++;
				}
			}
		}
	}

	/* Bubble Sort 排序 */
	new	TempLevelRank;
	new	String:TempLevelRankClient[256];
	for(new j = 1; j < LevelRankClientNo; j++)
	{
		for(new r = 0; r < LevelRankClientNo - j; r++)
		{
			if(LevelRank[r] <= LevelRank[r+1])
			{
				TempLevelRank = LevelRank[r];
				LevelRank[r] = LevelRank[r+1];
				LevelRank[r+1] = TempLevelRank;

				strcopy(TempLevelRankClient, 256, LevelRankClient[r]);
				strcopy(LevelRankClient[r], 256, LevelRankClient[r+1]);
				strcopy(LevelRankClient[r+1], 256, TempLevelRankClient);
			}
		}
	}

	new	TempCashlRank;
	new	String:TempCashRankClient[256];
	for(new j = 1; j < CashRankClientNo; j++)
	{
		for(new r = 0; r < CashRankClientNo - j; r++)
		{
			if(CashRank[r] <= CashRank[r+1])
			{
				TempCashlRank = CashRank[r];
				CashRank[r] = CashRank[r+1];
				CashRank[r+1] = TempCashlRank;

				strcopy(TempCashRankClient, 256, CashRankClient[r]);
				strcopy(CashRankClient[r], 256, CashRankClient[r+1]);
				strcopy(CashRankClient[r+1], 256, TempCashRankClient);
			}
		}
	}

	for(new r = 0; r < RankNo; r++)
	{
		KvJumpToKey(RPGRank, "LV", true);
		decl String:RankNameClient[256];
		decl String:RankNameLevel[256];
		Format(RankNameClient, sizeof(RankNameClient), "第%d名玩家", r+1);
		Format(RankNameLevel, sizeof(RankNameLevel), "第%d名等级", r+1);
		KvSetString(RPGRank, RankNameClient, LevelRankClient[r]);
		KvSetNum(RPGRank, RankNameLevel, LevelRank[r]);
		KvGoBack(RPGRank);

		KvJumpToKey(RPGRank, "CASH", true);
		decl String:RankNameCash[256];
		Format(RankNameClient, sizeof(RankNameClient), "第%d名玩家", r+1);
		Format(RankNameCash, sizeof(RankNameCash), "第%d名金钱", r+1);
		KvSetString(RPGRank, RankNameClient, CashRankClient[r]);
		KvSetNum(RPGRank, RankNameCash, CashRank[r]);
		KvGoBack(RPGRank);
	}

	KvJumpToKey(RPGRank, "United RPG", true);
	KvSetString(RPGRank, "Plugin_Version", PLUGIN_VERSION);

	KvRewind(RPGRank);
	KeyValuesToFile(RPGRank, RankPath);
	PrintToServer("[统计] 排名已更新!");
}
/* Admin Functions */
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hTopMenu = INVALID_HANDLE;
	}
}
public OnAdminMenuReady(Handle:topmenu)
{
	// Check ..
	if (topmenu == hTopMenu) return;

	// We save the handle
	hTopMenu = topmenu;
	AddToTopMenu(hTopMenu, "United RPG 选单", TopMenuObject_Category, Menu_CategoryHandler, INVALID_TOPMENUOBJECT);

	// Find admin menu ...
	new TopMenuObject:AdminTopmenu = FindTopMenuCategory(hTopMenu, "United RPG 选单");

	// now we add the function ...
	if (AdminTopmenu == INVALID_TOPMENUOBJECT) return;
	Admin_GiveExp = AddToTopMenu(hTopMenu, "rpg_giveexp", TopMenuObject_Item, Menu_TopItemHandler, AdminTopmenu, "rpg_giveexp", ADMFLAG_KICK);
	Admin_GiveLv = AddToTopMenu(hTopMenu, "rpg_givelv", TopMenuObject_Item, Menu_TopItemHandler, AdminTopmenu, "rpg_givelv", ADMFLAG_KICK);
	Admin_GiveCash = AddToTopMenu(hTopMenu, "rpg_givecash", TopMenuObject_Item, Menu_TopItemHandler, AdminTopmenu, "rpg_givecash", ADMFLAG_KICK);
	Admin_ResetStatus = AddToTopMenu(hTopMenu, "rpg_xidian", TopMenuObject_Item, Menu_TopItemHandler, AdminTopmenu, "rpg_xidian", ADMFLAG_KICK);
	Admin_GiveKT = AddToTopMenu(hTopMenu, "rpg_givekt", TopMenuObject_Item, Menu_TopItemHandler, AdminTopmenu, "rpg_givecash", ADMFLAG_KICK);
}
public Menu_CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, Client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
		Format(buffer, maxlength, "United RPG 选单");
	else if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "United RPG 选单");
}

public Menu_TopItemHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, Client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == Admin_GiveLv)
			Format(buffer, maxlength, "给予玩家等级");
		else if (object_id == Admin_GiveExp)
			Format(buffer, maxlength, "给予玩家经验");
		else if (object_id == Admin_GiveCash)
			Format(buffer, maxlength, "给予玩家金钱");
		else if (object_id == Admin_ResetStatus)
			Format(buffer, maxlength, "给玩家洗点(不扣等级)");
		else if (object_id == Admin_GiveKT)
			Format(buffer, maxlength, "给予玩家大过");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == Admin_GiveLv)
			g_id[Client] = 1, AdminGive(Client);
		else if (object_id == Admin_GiveExp)
			g_id[Client] = 2, AdminGive(Client);
		else if (object_id == Admin_GiveCash)
			g_id[Client] = 3, AdminGive(Client);
		else if (object_id == Admin_ResetStatus)
			g_id[Client] = 4, AdminGive_Handler(Client);
		else if (object_id == Admin_GiveKT)
			g_id[Client] = 5, AdminGive(Client);
	}
}
AdminGive(Client)
{
	new Handle:menu = CreateMenu(AdminGive_MenuHandler);
	SetMenuTitle(menu, "选择数量");

	if (g_id[Client] == 1)
	{
		AddMenuItem(menu, "5", "5");
		AddMenuItem(menu, "10", "10");
		AddMenuItem(menu, "20", "20");
		AddMenuItem(menu, "30", "30");
		AddMenuItem(menu, "40", "40");
		AddMenuItem(menu, "50", "50");
		AddMenuItem(menu, "99", "99");
	}
	else if (g_id[Client] == 2)
	{
		AddMenuItem(menu, "500", "500");
		AddMenuItem(menu, "1000", "1000");
		AddMenuItem(menu, "2000", "2000");
		AddMenuItem(menu, "5000", "5000");
		AddMenuItem(menu, "10000", "10000");
		AddMenuItem(menu, "20000", "20000");
		AddMenuItem(menu, "50000", "50000");
	}
	else if (g_id[Client] == 3)
	{
		AddMenuItem(menu, "100", "100");
		AddMenuItem(menu, "200", "200");
		AddMenuItem(menu, "1000", "1000");
		AddMenuItem(menu, "2500", "2500");
		AddMenuItem(menu, "5000", "5000");
		AddMenuItem(menu, "10000", "10000");
		AddMenuItem(menu, "25000", "25000");
	}
	else if (g_id[Client] == 5)
	{
		AddMenuItem(menu, "1", "1");
		AddMenuItem(menu, "2", "2");
		AddMenuItem(menu, "3", "3");
		AddMenuItem(menu, "4", "4");
		AddMenuItem(menu, "5", "5");
		AddMenuItem(menu, "6", "6");
		AddMenuItem(menu, "7", "7");
	}

	SetMenuExitBackButton(menu, true);

	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public AdminGive_MenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)	CloseHandle(menu);
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];

		GetMenuItem(menu, param2, info, sizeof(info));
		AdminGiveAmount[param1] = StringToInt(info);
		AdminGive_Handler(param1);
	}
}
AdminGive_Handler(Client)
{
	new Handle:menu = CreateMenu(Admingive_MenuHandler2);
	
	if (g_id[Client] == 1)	SetMenuTitle(menu, "给予玩家等级");
	if (g_id[Client] == 2)	SetMenuTitle(menu, "给予玩家经验");
	if (g_id[Client] == 3)	SetMenuTitle(menu, "给予玩家金钱");
	if (g_id[Client] == 4)	SetMenuTitle(menu, "选择洗点玩家");
	if (g_id[Client] == 5)	SetMenuTitle(menu, "给予玩家大过");
		
	SetMenuExitBackButton(menu, true);
	AddTargetsToMenu2(menu, Client, COMMAND_FILTER);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public Admingive_MenuHandler2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)	CloseHandle(menu);
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32], String:targetName[MAX_NAME_LENGTH];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(param1, "{green}[统计] \x01%t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(param1, "{green}[统计] \x01%t", "Unable to target");
		}
		GetClientName(target, targetName, sizeof(targetName));
		if (g_id[param1] == 1)
		{
			Lv[target] += AdminGiveAmount[param1];
			StatusPoint[target] += AdminGiveAmount[param1]*GetConVarInt(LvUpSP);
			SkillPoint[target] += AdminGiveAmount[param1]*GetConVarInt(LvUpKSP);
			if (GetConVarInt(GiveAnnonce))	if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(param1, MSG_ADMIN_GIVE_LV, targetName, AdminGiveAmount[param1]);
		}
		else if (g_id[param1] == 2)
		{
			EXP[target] += AdminGiveAmount[param1];
			if (GetConVarInt(GiveAnnonce))	if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(param1, MSG_ADMIN_GIVE_EXP, targetName, AdminGiveAmount[param1]);
		}
		else if (g_id[param1] == 3)
		{
			Cash[target] += AdminGiveAmount[param1];
			if (GetConVarInt(GiveAnnonce))	if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(param1, MSG_ADMIN_GIVE_CASH, targetName, AdminGiveAmount[param1]);
		}
		else if (g_id[param1] == 4)
		{
			ClinetResetStatus(target, Admin);
		}
		else if (g_id[param1] == 5)
		{
			KTCount[target] += AdminGiveAmount[param1];
			if (GetConVarInt(GiveAnnonce))	if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(param1, MSG_ADMIN_GIVE_KT, targetName, AdminGiveAmount[param1]);

			if(KTLimit >= KTCount[target]) if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_KT_WARNING_1, KTLimit);

			if(KTCount[target] > KTLimit )
			{
				if(!JobChooseBool[target])
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_KT_WARNING_2, KTLimit);
				}
				else
				{
					ClinetResetStatus(target, General);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_KT_WARNING_3, KTLimit);
				}
			}
		}
		AdminGive_Handler(param1);
	}
}

public Action:Command_GiveExp(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_giveexp  <#userid|name> [数量]");
		return Plugin_Handled;
	}

	decl String:arg[MAX_NAME_LENGTH], String:arg2[64];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	new targetClient;

	if ((target_count = ProcessTargetString(arg,Client,target_list,MAXPLAYERS,COMMAND_FILTER,target_name,sizeof(target_name),tn_is_ml)) > 0)
	{
		for (new i = 0; i < target_count; i++)
		{
			targetClient = target_list[i];
			EXP[targetClient] += StringToInt(arg2);
		}
		if (GetConVarInt(GiveAnnonce))
		{
			if(StrEqual(arg, "@all", false)) arg = "所有玩家";
			if(StrEqual(arg, "@humans", false)) arg = "所有幸存者";
			if(StrEqual(arg, "@alive", false)) arg = "所有活著的玩家";
			if(StrEqual(arg, "@dead", false)) arg = "所有死亡的玩家";
			if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(Client, MSG_ADMIN_GIVE_EXP, arg, StringToInt(arg2));
		}
	}
	else
	{
		ReplyToTargetError(Client, target_count);
	}
	return Plugin_Handled;
}
public Action:Command_GiveLevel(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_givelv <#userid|name> [数量]");
		return Plugin_Handled;
	}

	decl String:arg[MAX_NAME_LENGTH], String:arg2[64];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	new targetClient;

	if ((target_count = ProcessTargetString(arg,Client,target_list,MAXPLAYERS,COMMAND_FILTER,target_name,sizeof(target_name),tn_is_ml)) > 0)
	{
		for (new i = 0; i < target_count; i++)
		{
			targetClient = target_list[i];
			Lv[targetClient] += StringToInt(arg2);
			StatusPoint[targetClient] += GetConVarInt(LvUpSP)*StringToInt(arg2);
			SkillPoint[targetClient] += GetConVarInt(LvUpKSP)*StringToInt(arg2);
		}
		if (GetConVarInt(GiveAnnonce))
		{
			if(StrEqual(arg, "@all", false)) arg = "所有玩家";
			if(StrEqual(arg, "@humans", false)) arg = "所有幸存者";
			if(StrEqual(arg, "@alive", false)) arg = "所有活著的玩家";
			if(StrEqual(arg, "@dead", false)) arg = "所有死亡的玩家";
			if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(Client, MSG_ADMIN_GIVE_LV, arg, StringToInt(arg2));
		}
	}
	else
	{
		ReplyToTargetError(Client, target_count);
	}
	return Plugin_Handled;
}
public Action:Command_GiveCash(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_giveexp  <#userid|name> [数量]");
		return Plugin_Handled;
	}

	decl String:arg[MAX_NAME_LENGTH], String:arg2[64];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	new targetClient;
	if ((target_count = ProcessTargetString(arg,Client,target_list,MAXPLAYERS,COMMAND_FILTER,target_name,sizeof(target_name),tn_is_ml)) > 0)
	{
		for (new i = 0; i < target_count; i++)
		{
			targetClient = target_list[i];
			Cash[targetClient] += StringToInt(arg2);
		}
		if (GetConVarInt(GiveAnnonce))
		{
			if(StrEqual(arg, "@all", false)) arg = "所有玩家";
			if(StrEqual(arg, "@humans", false)) arg = "所有幸存者";
			if(StrEqual(arg, "@alive", false)) arg = "所有活著的玩家";
			if(StrEqual(arg, "@dead", false)) arg = "所有死亡的玩家";
			if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(Client, MSG_ADMIN_GIVE_CASH, arg, StringToInt(arg2));
		}
	}
	else
	{
		ReplyToTargetError(Client, target_count);
	}
	return Plugin_Handled;
}

public Action:Command_FullMP(Client, args)
{
	MP[Client] = MaxMP[Client];
	return Plugin_Handled;
}

public Action:Command_GiveKT(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_givekt  <#userid|name> [数量]");
		return Plugin_Handled;
	}

	decl String:arg[MAX_NAME_LENGTH], String:arg2[64];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	new targetClient;
	if ((target_count = ProcessTargetString(arg,Client,target_list,MAXPLAYERS,COMMAND_FILTER,target_name,sizeof(target_name),tn_is_ml)) > 0)
	{
		for (new i = 0; i < target_count; i++)
		{
			targetClient = target_list[i];
			KTCount[targetClient] += StringToInt(arg2);
			
			if(KTLimit >= KTCount[targetClient]) if(GetConVarInt(g_hCvarShow))CPrintToChat(targetClient, MSG_KT_WARNING_1, KTLimit);

			if(KTCount[targetClient] > KTLimit )
			{
				if(!JobChooseBool[targetClient])
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(targetClient, MSG_KT_WARNING_2, KTLimit);
				}
				else
				{
					ClinetResetStatus(targetClient, General);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(targetClient, MSG_KT_WARNING_3, KTLimit);
				}
			}
		}
	}
	else
	{
		ReplyToTargetError(Client, target_count);
	}
	return Plugin_Handled;
}

public Action:Command_RpTest(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_rptest 编号(%d~%d)", diceNumMin, diceNumMax);
		return Plugin_Handled;
	}

	decl String:arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(StringToInt(arg) > diceNumMax || StringToInt(arg) < diceNumMin)
	{
		ReplyToCommand(Client, "[SM] 用法: sm_rptest 编号(%d~%d)", diceNumMin, diceNumMax);
		return Plugin_Handled;
	}
	
	AdminDiceNum[Client] = StringToInt(arg);
	CreateTimer(1.0, UseLotteryFunc, Client);
	//UseLotteryFunc(Client);
	return Plugin_Handled;
}

/* 自动绑定 */
public Action:Showbind(Handle:timer, any:Client)
{
	KillTimer(timer);
	if (IsValidClient(Client)) MenuFunc_BindKeys(Client);
	return Plugin_Handled;
}

public Action:AFKTurnClientToSpectate(client, argCount)
{
	ChangeClientTeam(client, 1);
	return Plugin_Handled;
}

public Action:AFKTurnClientToSurvivors(client, args)
{
	if(TeamChangeSecondLeft > 0)	ClientCommand(client, "jointeam 2");
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_VERSUS_SCORE_CHANGE_TEAM_TIMESUP);
	return Plugin_Handled;
}
public Action:AFKTurnClientToInfected(client, args)
{
	if(TeamChangeSecondLeft > 0)	ClientCommand(client, "jointeam 3");
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_VERSUS_SCORE_CHANGE_TEAM_TIMESUP);
	return Plugin_Handled;
}

public Action:Event_InfectedDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "attacker"));
	new inf = GetEventInt(event, "infected_id");
	if(!player || !inf || !IsClientInGame(player) || IsFakeClient(player) || GetEntProp(inf, Prop_Send, "m_zombieClass") == 7) return Plugin_Continue;
	ZombiesKillCount[player] ++;
	return Plugin_Continue;
}

public Action:Event_LeftSafeRoom(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if(g_hTimerGivePlayerEXP != INVALID_HANDLE)
	{
		KillTimer(g_hTimerGivePlayerEXP);
		g_hTimerGivePlayerEXP = INVALID_HANDLE;
	}
	g_hTimerGivePlayerEXP = CreateTimer(3.0, Timer_GivePlayerEXP, _, TIMER_REPEAT);
	if(!GetConVarInt(FindConVar("director_force_tank"))) SetConVarInt(FindConVar("director_force_tank"), 1);
	if(!GetConVarInt(FindConVar("director_force_witch"))) SetConVarInt(FindConVar("director_force_witch"), 1);
}

/* 玩家第一次出现在游戏 */
public Action:Event_PlayerFirstSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsFakeClient(target))
	{
		PrintToServer("[统计] %s 在这回合第一次在游戏重生!", NameInfo(target, simple));
		//if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_VERSION, PLUGIN_VERSION);
		if(IsPasswordConfirm[target])	if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_PlayerInfo, Lv[target], Cash[target], Str[target], Agi[target], Health[target], Endurance[target], Intelligence[target]);
		/*
		if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_WELCOME1, target);
		if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_WELCOME2);
		if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_WELCOME3);
		if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_WELCOME4);
		FakeClientCommand(target,"rpg");
		*/
		if(IsVersus)
		{
			if(RoundNo == 1)
			{
				CreateTimer(0.1, ChangeTeamTimerFunction, target);
			}
		}
	}
	return Plugin_Continue;
}
public Action:ChangeTeamTimerFunction(Handle:timer, any:target)
{
	ChangeTeam(target, NextRoundTeam[target]);
}
/* 玩家出现在游戏/重生 */
public Action:Event_PlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	new class = GetEntProp(target, Prop_Send, "m_zombieClass");
	new Float:addvalue = GetConVarFloat(BotHP);
	
	if(!IsFakeClient(target))
	{
		if(Lv[target] > 0)
		{
			if(GetClientTeam(target) == TEAM_SURVIVORS)
			{
				RebuildStatus(target, true);
			} else if(GetClientTeam(target) == TEAM_INFECTED)
			{
				//new iclass = GetEntProp(target, Prop_Send, "m_zombieClass");
				if(class != CLASS_TANK)
				{
					RebuildStatus(target, true);
					if(IsSuperInfectedEnable[target])	CreateSuperInfected(target);
				}
			}
		}
		robot[target]=0;
	} else if(IsFakeClient(target) && addvalue && addvalue != 1.0 && class && class != 8)
	{
		SetEntProp(target, Prop_Data, "m_iMaxHealth", RoundToNearest(GetEntProp(target, Prop_Data, "m_iMaxHealth") * addvalue));
		SetEntProp(target, Prop_Data, "m_iHealth", RoundToNearest(GetEntProp(target, Prop_Data, "m_iHealth") * addvalue));
	}
	return Plugin_Continue;
}
public Action:Event_BotPlayerReplace(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));

	if(Lv[player] > 0)
	{
		if(GetClientTeam(player) == TEAM_SURVIVORS)
		{
			RebuildStatus(player, true);
		} else if(GetClientTeam(player) == TEAM_INFECTED)
		{
			new iclass = GetEntProp(player, Prop_Send, "m_zombieClass");
			if(iclass != CLASS_TANK)
			{
				RebuildStatus(player, true);
			}
		}
	} else if(Lv[player] == 0)
	{
		if(GetClientTeam(player) == TEAM_SURVIVORS)
		{
			SetEntProp(player, Prop_Data, "m_iMaxHealth", 100);
			SetEntProp(player, Prop_Data, "m_iHealth", 100);
		}
	}
	robot[player]=0;
	return Plugin_Continue;
}
public Action:Event_AwardEarned(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	new eventid = GetEventInt(event, "award");
	new subject = GetEventInt(event, "subjectentid");
	new String:name[128] = "";
	if(subject && IsClientConnected(subject) && GetClientTeam(subject) == 2)
	{
		GetClientName(subject, name, 128);
	}
	
	if(eventid == 67)
	{
		if(!IsClientConnected(player) || IsFakeClient(player) || GetClientTeam(player) != 2) return Plugin_Continue;
		new getCash = GetConVarInt(sm_protected_money);
		Cash[player] += getCash;
		EXP[player] += GetConVarInt(sm_protected_exp);
		PrintToConsole(player, "[提示] 你保护了 %s ，获得 %d 金钱", name[0] == '\0' ? "队友" : name, getCash);
	}
	
	if(eventid == 68 || eventid == 69)
	{
		if(!IsClientConnected(player) || IsFakeClient(player) || GetClientTeam(player) != 2) return Plugin_Continue;
		new getCash = GetConVarInt(sm_givepill_money);
		Cash[player] += getCash;
		EXP[player] += GetConVarInt(sm_givepill_exp);
		PrintToConsole(player, "[提示] 你给了 %s %s，获得 %d 金钱", name[0] == '\0' ? "队友" : name, eventid == 68 ? "药" : "针", getCash);
	}
	
	if(eventid == 75)
	{
		if(!IsClientConnected(player) || IsFakeClient(player) || GetClientTeam(player) != 2) return Plugin_Continue;
		new getCash = GetConVarInt(sm_helpofledge_money);
		Cash[player] += getCash;
		EXP[player] += GetConVarInt(sm_helpofledge_exp);
		PrintToConsole(player, "[提示] 你拉起挂边的 %s，获得 %d 金钱", name[0] == '\0' ? "队友" : name, getCash);
	}
	
	if(eventid == 76)
	{
		if(!IsClientConnected(player) || IsFakeClient(player) || GetClientTeam(player) != 2) return Plugin_Continue;
		new getCash = GetConVarInt(sm_helpofinf_money);
		Cash[player] += getCash;
		EXP[player] += GetConVarInt(sm_helpofinf_exp);
		PrintToConsole(player, "[提示] 你从特感手里救 %s ，获得 %d 金钱", name[0] == '\0' ? "队友" : name, getCash);
	}
	
	if(eventid == 80)
	{
		if(!IsClientConnected(player) || IsFakeClient(player) || GetClientTeam(player) != 2) return Plugin_Continue;
		new getCash = GetConVarInt(sm_opendoor_money);
		Cash[player] += getCash;
		EXP[player] += GetConVarInt(sm_opendoor_exp);
		PrintToConsole(player, "[提示] 你打开了复活房救出了 %s，获得 %d 金钱", name[0] == '\0' ? "队友" : name, getCash);
	}
	
	return Plugin_Continue;
}

/* 玩家更改名字*/
public Action:Event_PlayerChangename(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:oldname[256];
	decl String:newname[256];
	GetEventString(event, "oldname", oldname, sizeof(oldname));
	GetEventString(event, "newname", newname, sizeof(newname));
	Initialization(target);
	/* 读取玩家密码 */
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(target, user_name, sizeof(user_name));
	ReplaceString(user_name, sizeof(user_name), "\"", "{DQM}");//DQM Double quotation mark"
	ReplaceString(user_name, sizeof(user_name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(user_name, sizeof(user_name), "/*", "{SST}");//SST Slash Star
	ReplaceString(user_name, sizeof(user_name), "*/", "{STS}");//STS Star Slash
	ReplaceString(user_name, sizeof(user_name), "//", "{DSL}");//DSL Double Slash
	#if ENABLE_SQL
	//SQL_EscapeString(g_hDataBase, user_name, user_name, 64);
	new String:line[128];
	Format(line, 128, "UPDATE l4d2UnitedRPGn SET name = '%s' WHERE name = '%s';", newname, user_name);
	#else
	KvJumpToKey(RPGSave, user_name, false);
	KvGetString(RPGSave, "PW", Password[target], PasswordLength, "");
	KvGoBack(RPGSave);
	#endif
	//if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MESSAGE_CHANGENAME);
	FakeClientCommand(target, "sm_rpgpw 12345");
	LogToFileEx(LogPath, " %s 在游戏内改名为 %s !", oldname, newname);
	return Plugin_Continue;
}
/******************************************************
*	Event when Tank has spawned or dead
*******************************************************/
public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new Handle:mwtank = CreateTimer(1.0, TankSpawn, userid);
	userid = GetClientOfUserId(userid);
	if(!GetConVarInt(g_hCvarShow))
	{
		KillTimer(mwtank);
		if(GetConVarInt(FindConVar("sv_maxplayers")) == 1)
		{
			SetEntityHealth(userid, 4000);
		}
		else if(GetConVarInt(FindConVar("sv_maxplayers")) <= 4)
		{
			SetEntityHealth(userid, 8000);
		}
		else if(GetConVarInt(FindConVar("sv_maxplayers")) <= 8)
		{
			SetEntityHealth(userid, 12000);
		}
		else
		{
			SetEntityHealth(userid, 16000);
		}
	}
	return Plugin_Handled;
}

public Action:TankSpawn(Handle:timer, any:userid) 
{
	new client =  GetClientOfUserId(userid);
	
	// Tank instantly change owner, so skip this spawn
	if (client == 0 || GetConVarInt(sm_lastboss_basic_number) <= 0)
		return Plugin_Handled;

	new bool: isNew = true;
	new bool: isTankClient = false;
	new TotalCount = 0;
	for (new i=1 ; i<=MaxClients ; i++)
	{
		isTankClient = false;
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (GetEntProp(i, Prop_Send, "m_zombieClass") == CLASS_TANK)
			{
				isTankClient = true;
				TotalCount++;
			}
		}
		if (IsTank[i] && !isTankClient) // Tank changes owner
		{
			IsTank[i] = false;
			IsFrustrated[i] = false;
			isNew = false;
		}
	}

	if (!IsTank[client])
	{
		IsTank[client] = true;
		if (isNew && GetConVarInt(sm_lastboss_basic_number))
		{
			// NEW TANK
			CreateSuperTank(client, false);

			TanksSpawned++;
			TanksMustSpawned--;

			tankpower_gamestart = true;
			
			IsSuperInfectedEnable[client] = false;

			PrintToServer("[统计] 第 %d 只魔王坦克(控制者: %s)出现!", TanksSpawned, NameInfo(client, simple));

			// If it is first tank, then spawn additional tanks
			if (TanksSpawned == 1)
			{
				if(GetConVarInt(sm_lastboss_enable_announce))
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_SPAWN);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_SPAWN2);
				}
				
				TotalTanks = GetConVarInt(sm_lastboss_basic_number);

				if(GetConVarInt(sm_lastboss_lv_add_enable) == 1)
				{
					new SurvivorTeamLv = 0;
					new InfectedTeamLv = 0;
					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && !IsFakeClient(i))
						{
							if(GetClientTeam(i) == TEAM_SURVIVORS) SurvivorTeamLv += Lv[i];
							else if(GetClientTeam(i) == TEAM_INFECTED) InfectedTeamLv += Lv[i];
						}
					}
					new addedtankno = RoundToNearest(float(SurvivorTeamLv - InfectedTeamLv)/GetConVarInt(sm_lastboss_lv_add_difference));

					if(addedtankno >= 1)
					{
						TotalTanks += addedtankno;
						PrintToServer("[统计] 幸存者阵营总等级(%d)多於特殊感染者阵营(%d), 增加%d只魔王变身坦克!",SurvivorTeamLv,InfectedTeamLv,addedtankno);
						if(GetConVarInt(g_hCvarShow))PrintHintTextToAll(MSG_TANK_ADD_LV_DIFFERENCE,SurvivorTeamLv,InfectedTeamLv,addedtankno);
					}else PrintToServer("[统计] 幸存者阵营总等级(%d), 特殊感染者阵营(%d)",SurvivorTeamLv,InfectedTeamLv);
				}

				SaveAndInreaseMaxZombies(TotalTanks);
				TanksMustSpawned=0;
				TanksToSpawn = TotalTanks - 1;

				SpawnTimer = CreateTimer(0.1, SpawnAdditionalTank, client);
			}
			if (TanksSpawned==TotalTanks)// If it is the last additional tank
			{
				TanksSpawned=0;
				TanksMustSpawned=0;
				RestoreMaxZombies();
				if (SpawnTimer != INVALID_HANDLE) {KillTimer(SpawnTimer); SpawnTimer = INVALID_HANDLE;}
				if (CheckTimer != INVALID_HANDLE) {KillTimer(CheckTimer); CheckTimer = INVALID_HANDLE;}
			} // last tank
		} else if(GetConVarInt(sm_lastboss_basic_number))// new tank
		{
			// Control Transfer
			CreateSuperTank(client, true);
			TanksFrustrated--;
			IsSuperInfectedEnable[client] = false;
			PrintToServer("[统计] 魔王坦克(接管者:%s)因转手出现!", NameInfo(client, simple));
		}
	} // unique tank
	else
	{
		IsTank[client] = false;
		IsSuperInfectedEnable[client] = false;
	}
	return Plugin_Handled;
}

public Action:SpawnAdditionalTank(Handle:timer, any:client)
{
	SpawnTimer = INVALID_HANDLE;
	if ((!IsRoundStarted) || IsRoundEnded) return;
	if (TanksToSpawn <= 0) return;

	TanksToSpawn--;
	TanksMustSpawned++;

	// Spawn NEW TANK

	// We get any client ....
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == 0)
	{
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (anyclient == 0)
		{
			LogError("[L4D] MultiTanks CreateFakeClient returned 0 -- Tank bot was not spawned");
			return;
		}
		temp = true;
	}

	CheatCommand(anyclient, "z_spawn", "tank auto");
	//SpawnInfectedBoss(anyclient, ZC_TANK);

	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1, kickbot, anyclient);

	if (TanksToSpawn==0)
	{
		// Timer for check that all tanks spawned
		CheckTimer = CreateTimer(0.1, CheckAdditionalTanks, client);
	} else SpawnTimer = CreateTimer(0.1, SpawnAdditionalTank, client);
}

public Action:kickbot(Handle:timer, any:value)
{
	KickThis(value);
}

KickThis (client)
{
	if (IsClientConnected(client) && (!IsClientInKickQueue(client)))
	{
		KickClient(client,"Kick");
	}
}

public Action:CheckAdditionalTanks(Handle:timer, any:client)
{
	CheckTimer = INVALID_HANDLE;
	if ((!IsRoundStarted) || IsRoundEnded) return;

	// Check if not all additional tanks successfully spawned
	if (TanksMustSpawned > 0)
	{
		TanksToSpawn = TanksMustSpawned;
		TanksMustSpawned = 0;
		SpawnTimer = CreateTimer(0.1, SpawnAdditionalTank, client);

	} else
	{
		// Check for tanks dissapears

		new bool: isTankClient = false;
		new TanksDissapears=0;
		for (new i=1 ; i<=MaxClients ; i++)
		{	
			isTankClient = false;
			if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == TEAM_INFECTED))
			{
				if (GetEntProp(i, Prop_Send, "m_zombieClass") == CLASS_TANK) isTankClient = true;
			}
			
			if (IsTank[i] && !isTankClient) // Tank dissapear
			{	
				TanksSpawned--;
				TanksDissapears++;
			}
		}

		if (TanksDissapears == 1)
		{
			
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[TANK] {blue}Tank神奇地消失了, 新的tank黎紧!");
		} else
		if (TanksDissapears > 1)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[TANK] {blue} %d Tanks神奇地消失了, 新的tanks黎紧!!", TanksDissapears);
		}

		if (TanksDissapears != 0)
		{
			SaveAndInreaseMaxZombies(TanksDissapears);
			TanksToSpawn = TanksDissapears;
			TanksMustSpawned = 0;
			SpawnTimer = CreateTimer(0.1, SpawnAdditionalTank, client);
		}
	
	}

}

CreateSuperTank(client, bool:OnlyMaxHP)
{
	SetTankHealth(client, OnlyMaxHP);
	
	for (new i = 1; i <= MaxClients; i++)
		DamageToTank[i][client] = 0;

	form_prev[client] = DEAD;

	if(TimerUpdate[client] != INVALID_HANDLE)
	{
		KillTimer(TimerUpdate[client]);
		TimerUpdate[client] = INVALID_HANDLE;
	}
	TimerUpdate[client] = CreateTimer(1.0, TankUpdate, client, TIMER_REPEAT);

	for(new j = 1; j <= MaxClients; j++)
	{
		if(IsClientInGame(j) && !IsFakeClient(j))
		{
			EmitSoundToClient(j, SOUND_SPAWN);
		}
	}
}

public bool:isSuperVersus()
{
	if(FindConVar("sm_superversus_version") != INVALID_HANDLE) return true;
	else return false;
}

public SaveAndInreaseMaxZombies(number)
{
	if (isSuperVersus())
	{
		DefaultMaxZombies = GetConVarInt(FindConVar("l4d_infected_limit")); // Save  max zombies
		UnsetNotifytVar(FindConVar("l4d_infected_limit"));
		SetConVarInt(FindConVar("l4d_infected_limit"), DefaultMaxZombies+number); // and inreases limit
		SetNotifytVar(FindConVar("l4d_infected_limit"));
	} else
	{
		DefaultMaxZombies = GetConVarInt(FindConVar("z_max_player_zombies")); // Save  max zombies
		SetConVarInt(FindConVar("z_max_player_zombies"), DefaultMaxZombies+number); // and inreases limit
	}
}

public RestoreMaxZombies()
{
	if (isSuperVersus())
	{
		UnsetNotifytVar(FindConVar("l4d_infected_limit"));
		SetConVarInt(FindConVar("l4d_infected_limit"), DefaultMaxZombies); // restores limit
		SetNotifytVar(FindConVar("l4d_infected_limit"));
	} else
	{
		SetConVarInt(FindConVar("z_max_player_zombies"), DefaultMaxZombies); // restores limit
	}
}


public UnsetNotifytVar(Handle:hndl)
{
	new flags = GetConVarFlags(hndl);
	flags &= ~FCVAR_NOTIFY;
	SetConVarFlags(hndl, flags);
}

public SetNotifytVar(Handle:hndl)
{
	new flags = GetConVarFlags(hndl);
	flags |= FCVAR_NOTIFY;
	SetConVarFlags(hndl, flags);
}

SetTankHealth(client, bool:OnlyMaxHP)
{
	if(IsValidEntity(client) && IsClientInGame(client))
	{
		if(!OnlyMaxHP)	SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(sm_lastboss_health_max));
		if(GetConVarInt(sm_lastboss_health_max) <= 32768)	SetEntProp(client, Prop_Data, "m_iMaxHealth", GetConVarInt(sm_lastboss_health_max));
		else SetEntProp(client, Prop_Data, "m_iMaxHealth", 32768);
	}
}
/* 玩家转换队伍 */
public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client_id = GetEventInt(event, "userid");
	new Client = GetClientOfUserId(Client_id);
	new oldteam = GetEventInt(event, "oldteam");
	new newteam = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");
	if (IsValidClient(Client) && !disconnect && oldteam != 0)
	{
		KillAllClientSkillTimer(Client);
		if(!IsFakeClient(Client))
		{
			MP[Client] = 0;
			InfectedSummonCount[Client] 	=	0;
			//FakeClientCommand(Client,"rpg");
			
			new Handle:pack;
			// If the player has just changed teams recently..
			if (hTimer_ClientTeamChange[Client] != INVALID_HANDLE)
				KillTimer(hTimer_ClientTeamChange[Client]);
			hTimer_ClientTeamChange[Client] = CreateDataTimer(1.0, _Timer__AnnounceJoining, pack);
			WritePackCell(pack, Client_id);
			WritePackCell(pack, Client);
			WritePackCell(pack, newteam);
			
			PrintToServer("[统计] %s 由Team %d 转去Team %d!", NameInfo(Client, simple), oldteam, newteam);
		}
	}
	return Plugin_Continue;
}
public Action:_Timer__AnnounceJoining(Handle:timer, Handle:pack) {
	ResetPack(pack);
	new Client_id = ReadPackCell(pack);
	new Client = ReadPackCell(pack);
	new team = ReadPackCell(pack);
	if (GetClientOfUserId(Client_id) == Client) {	// if not, then it is somehow a different player
		hTimer_ClientTeamChange[Client] = INVALID_HANDLE;
		if (IsClientInGame(Client)) {		// if the client disconnected during the timer - stop.
			switch (team) {
				case TEAM_SPECTATORS:
				{
					for(new i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i != Client && !IsFakeClient(i)) 
						{
							if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_PLAYER_JOIN_TEAM1, Client);
						}
				}
				case TEAM_SURVIVORS:
				{
					for(new i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i != Client && !IsFakeClient(i)) 
						{
							if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_PLAYER_JOIN_TEAM2, Client);
						}
				}
				case TEAM_INFECTED:
				{
					for(new i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i != Client && !IsFakeClient(i)) 
						{
							if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_PLAYER_JOIN_TEAM3, Client);
							
						}
				}
			}
		}
	}
}
/* 玩家发起投票 */
public Action:Callvote_Handler(client, args)
{

	// return Plugin_Handled;  - to prevent the vote from going through
	// return Plugin_Continue; - to allow the vote to go like normal

	decl String:voteName[32];
	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	GetCmdArg(1,voteName,sizeof(voteName));

	
	// test code
	//decl String:fullCommand[256];
	//GetCmdArgString(fullCommand, sizeof(fullCommand));
	//PrintToChatAll("%s", fullCommand);

	// vote examples:
	// ChangeDifficulty Easy
	// RestartGame
	// ChangeMission Smalltown
	// ChangeChapter 16
	// callvote Kick <client #>
	
	if(GetConVarInt(g_hCvarShow))PrintToChatAll("\x05[投票] \x05%s\x03发起了%s投票", initiatorName, voteName);
	LogToFileEx(LogPath, "[投票] %s发起了%s投票", initiatorName, voteName);
	return Plugin_Continue;
}

public Action:Timer_GivePlayerEXP(Handle:timer, any:data)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1)
		{
			if(IsAdmin[i])
			{
				EXP[i] += 2;
			}
			else
			{
				EXP[i]++;
			}
		}
	}
}

/* 回合开始 */
public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_hTimerGivePlayerEXP = CreateTimer(9.0, Timer_GivePlayerEXP, _, TIMER_REPEAT);
	for (new i = 1; i <= MaxClients; i++)
	{
		form_prev[i] = DEAD;

		if(robot[i]>0)
		{
			Release(i, false);
		}
		botenerge[i]=0.0;

		for(new j = 0; j < DamageDisplayBuffer; j++)
		{
			strcopy(DamageDisplayString[i][j], DamageDisplayLength, "");
		}

		IsSuperInfectedEnable[i] = false;
		IsFreeze[i] = false;
		IsChained[i] = false;
	}

	TanksSpawned=0;
	TanksMustSpawned=0;
	TanksToSpawn = 0;
	TanksFrustrated=0;
	IsRoundStarted = true;
	IsRoundEnded = false;
	if (CheckTimer != INVALID_HANDLE) {KillTimer(CheckTimer); CheckTimer = INVALID_HANDLE;}
	if (SpawnTimer != INVALID_HANDLE) {KillTimer(SpawnTimer); SpawnTimer = INVALID_HANDLE;}
	for (new i=0; i <= MAXPLAYERS; i++)
	{
		IsTank[i] = false;
		IsFrustrated[i] = false;
		HasGetBuJi[i] = true;
	}
	
	if(IsVersus)
	{
		if(RoundNo == 1)
			LogToFileEx(LogPath, "--- 第1回合开始 - Team 1: %d积分, Team 2: %d积分 ---", GetTeamRoundScore(1), GetTeamRoundScore(2));
		else if(RoundNo == 2)
		{
			if(GetConVarInt(VersusScoreEnable) == 1)
			{
				if(RoundPlayTimer != INVALID_HANDLE)
				{
					KillTimer(RoundPlayTimer);
					RoundPlayTimer = INVALID_HANDLE;
				}
				RoundPlayTimer = CreateTimer(10.0, RoundPlayTimerFunction, _, TIMER_REPEAT);
			}

			LogToFileEx(LogPath, "--- 第2回合开始 - Team 1: %d积分, Team 2: %d积分 ---", GetTeamRoundScore(1), GetTeamRoundScore(2));
			LogToFileEx(LogPath, "--- SurvivorLogicalTeam: %d, InfectedLogicalTeam: %d", SurvivorLogicalTeam, InfectedLogicalTeam);
		} else if(RoundNo == 0)
		{
			RoundNo = 1;
			StartScore[1] = GetTeamRoundScore(1);
			StartScore[2] = GetTeamRoundScore(2);
			SurvivorLogicalTeam = 1;
			InfectedLogicalTeam = 2;
			LogToFileEx(LogPath, "--- 第1回合开始(上回合玩家数為0) - Team 1: %d积分, Team 2: %d积分 ---", StartScore[1], StartScore[2]);
			LogToFileEx(LogPath, "--- SurvivorLogicalTeam: %d, InfectedLogicalTeam: %d", SurvivorLogicalTeam, InfectedLogicalTeam);
			if(GetConVarInt(VersusScoreEnable) == 1)
			{
				Round1SurvivorScore = 0;
				Round2SurvivorScore = 0;
				//转队时间计算
				SetConVarInt(FindConVar("vs_max_team_switches"), 99, true, true);
				TeamChangeSecondLeft = GetConVarInt(VersusScoreChangeTeamTime);
				if(TeamChangeTimer != INVALID_HANDLE)
				{
					KillTimer(TeamChangeTimer);
					TeamChangeTimer = INVALID_HANDLE;
				}
				TeamChangeTimer = CreateTimer(1.0, TeamChangeTimerFunction, _, TIMER_REPEAT);
				
				//玩家贡献时间计算
				RoundPlayTime = 0;
				for (new i = 1; i <= MaxClients; i++)
				{
					PlayerAliveTime[i] =0;
				}
				if(RoundPlayTimer != INVALID_HANDLE)
				{
					KillTimer(RoundPlayTimer);
					RoundPlayTimer = INVALID_HANDLE;
				}
				RoundPlayTimer = CreateTimer(10.0, RoundPlayTimerFunction, _, TIMER_REPEAT);
			}
		}
	} else LogToFileEx(LogPath, "--- 回合开始 ---");
	TanksMustSpawned = GetConVarInt(sm_lastboss_basic_number);
	TanksSpawned = 0;
  	return Plugin_Continue;
}
public Action:TeamChangeTimerFunction(Handle:timer)
{
	new bool: IsZeroInGame = true;
	if(IsZeroInGame)
	{
		for (new i=1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i)) IsZeroInGame = false;
		}
	}
	if(IsRoundStarted && !IsZeroInGame)
	{
		TeamChangeSecondLeft -= 1;
		if(TeamChangeSecondLeft%10 == 0 && TeamChangeSecondLeft > 0)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_VERSUS_SCORE_CHANGE_TEAM_SECONDLEFT, TeamChangeSecondLeft);
			PrintToServer("[统计] 转换队伍时间剩余 %d 秒!",TeamChangeSecondLeft);
		} else if(TeamChangeSecondLeft == 0)
		{
			SetConVarInt(FindConVar("vs_max_team_switches"), 0, true, true);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_VERSUS_SCORE_CHANGE_TEAM_TIMESUP);
			PrintToServer("[统计] 转换队伍时间够了!");
			if(TeamChangeTimer != INVALID_HANDLE)
			{
				KillTimer(TeamChangeTimer);
				TeamChangeTimer = INVALID_HANDLE;
			}
		}
	}
	return Plugin_Continue;
}
public Action:RoundPlayTimerFunction(Handle:timer)
{
	RoundPlayTime += 1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				if((GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i)) || GetClientTeam(i) == TEAM_INFECTED) PlayerAliveTime[i] +=1;
			}
		}
	}
	return Plugin_Continue;
}

/* 回合结束 */
public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	LogToFileEx(LogPath, "[统计] Round_End Event Fired!");
	if(g_hTimerGivePlayerEXP != INVALID_HANDLE)
	{
		KillTimer(g_hTimerGivePlayerEXP);
		g_hTimerGivePlayerEXP = INVALID_HANDLE;
	}
	if(!IsRoundEnded)
	{
		/* 更新排名 */
		UpdateRanking();

		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if (!IsFakeClient(i))
				{
					if(robot[i]>0)
					{
						Release(i, false);
					}

					RobotCount[i] = 0;

					InfectedSummonCount[i] 	=	0;
					if(StrEqual(Password[i], "", true) || IsPasswordConfirm[i])	ClientSaveToFileSave(i);
				}
				KillAllClientSkillTimer(i);
			}
			for (new j = 1; j <= MaxClients; j++)
				DamageToTank[i][j] = 0;
		}
		robot_gamestart = false;

		if (TanksMustSpawned > 0)	RestoreMaxZombies();
		TanksSpawned=0;
		TanksMustSpawned=0;
		TanksToSpawn = 0;
		TanksFrustrated=0;
		IsRoundStarted = false;
		IsRoundEnded = true;
		if (CheckTimer != INVALID_HANDLE) {KillTimer(CheckTimer); CheckTimer = INVALID_HANDLE;}
		if (SpawnTimer != INVALID_HANDLE) {KillTimer(SpawnTimer); SpawnTimer = INVALID_HANDLE;}
		for (new i=0; i <= MAXPLAYERS; i++)
		{
			IsTank[i] = false;
			IsFrustrated[i] = false;
		}

		tankpower_gamestart = false;
		
		if(IsVersus)
		{
			LogToFileEx(LogPath, "--- 第%d回合结束 - Team 1: %d积分, Team 2: %d积分 ---", RoundNo, GetTeamRoundScore(1), GetTeamRoundScore(2));
			
			CheckZeroInGameBug();

			if(RoundNo == 0)
			{
				LogToFileEx(LogPath, "--- 游戏内没有玩家了 ---");
			} else if(RoundNo == 1)
			{
				if(GetConVarInt(VersusScoreEnable) == 1)
				{
					//暂时停止计算贡献时间
					if(RoundPlayTimer != INVALID_HANDLE)
					{
						KillTimer(RoundPlayTimer);
						RoundPlayTimer = INVALID_HANDLE;
					}
					Round1SurvivorScore = GetTeamRoundScore(SurvivorLogicalTeam) - StartScore[SurvivorLogicalTeam];
					//获得第1队幸存者积分
					for (new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i))
						{
							if(GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
							{
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_A_SRORE, Round1SurvivorScore);
							} else if(GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
							{
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_B_SRORE, Round1SurvivorScore);
							} else if(!IsFakeClient(i)){
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_SPECTATORS_SRORE, Round1SurvivorScore, 0);
							}
						}
					}
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_VERSUS_SCORE_EXPLAIN, GetConVarInt(VersusScoreMultipler));
					PrintToServer("[统计] 第1队幸存者获得 %d 积分! (总分為 %d)", Round1SurvivorScore, GetTeamRoundScore(SurvivorLogicalTeam));
					LogToFileEx(LogPath, "--- Round1SurvivorScore = %d, Round2SurvivorScore = %d ---", Round1SurvivorScore, Round2SurvivorScore);
				}
				//对调两队的LogicalTeam
				SwapLogicalTeam();
				SwapPlayerTeam();
				if(RoundNo != 0) RoundNo = 2;
			} else if(RoundNo == 2)
			{
				if(GetConVarInt(VersusScoreEnable) == 1)
				{
					//获得第2队幸存者积分
					Round2SurvivorScore = GetTeamRoundScore(SurvivorLogicalTeam) - StartScore[SurvivorLogicalTeam];
					for (new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i))
						{
							if(GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
							{
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_SRORE, Round2SurvivorScore, Round1SurvivorScore);
							} else if(GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
							{
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_SRORE, Round1SurvivorScore, Round2SurvivorScore);
							} else if(!IsFakeClient(i)){
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_SPECTATORS_SRORE, Round1SurvivorScore, Round2SurvivorScore);
							}
						}
					}
					PrintToServer("[统计] 第2队幸存者获得 %d 积分! (总分為 %d)", Round2SurvivorScore, GetTeamRoundScore(SurvivorLogicalTeam));
					LogToFileEx(LogPath, "--- Round1SurvivorScore = %d, Round2SurvivorScore = %d ---", Round1SurvivorScore, Round2SurvivorScore);
					//比较2队积分进行经验值和金钱分配
					if(Round1SurvivorScore > Round2SurvivorScore)
					{
						for (new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i))
							{
								if(GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
								{
									new Float:PlayRatio = float(PlayerAliveTime[i])/RoundPlayTime;
									new RewardEXP = RoundToNearest((Round1SurvivorScore-Round2SurvivorScore)*PlayRatio*GetConVarInt(VersusScoreMultipler));
									new RewardCash = RoundToNearest((Round1SurvivorScore-Round2SurvivorScore)*PlayRatio*GetConVarInt(VersusScoreMultipler)/10);
									if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_WIN, PlayRatio*100.0, RewardEXP, RewardCash);
									EXP[i] += RewardEXP;
									Cash[i] += RewardCash;
								}
								else if(GetClientTeam(i) == TEAM_SURVIVORS)	if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_LOSS);
							}
						}
					}
					else if(Round2SurvivorScore > Round1SurvivorScore)
					{
						for (new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i))
							{
								if(GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
								{
									new Float:PlayRatio = float(PlayerAliveTime[i])/RoundPlayTime;
									new RewardEXP = RoundToNearest((Round2SurvivorScore-Round1SurvivorScore)*PlayRatio*GetConVarInt(VersusScoreMultipler));
									new RewardCash = RoundToNearest((Round2SurvivorScore-Round1SurvivorScore)*PlayRatio*GetConVarInt(VersusScoreMultipler)/10);
									if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_WIN, PlayRatio*100.0, RewardEXP, RewardCash);
									EXP[i] += RewardEXP;
									Cash[i] += RewardCash;
								}
								else if(GetClientTeam(i) == TEAM_INFECTED)	if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_VERSUS_SCORE_TEAM_LOSS);
							}
						}
					}
					else if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_VERSUS_SCORE_TEAM_DRAW);
				}
				//比较2队总积分去分配下关谁是幸存者和谁是特殊感染者
				if(GetTeamRoundScore(InfectedLogicalTeam) > GetTeamRoundScore(SurvivorLogicalTeam))
				{
					SwapLogicalTeam();
					SwapPlayerTeam();
				} else UpdatePlayerTeam();
				LogTeamInfo();
				RoundNo = 3;
			}			
		} else LogToFileEx(LogPath, "--- 回合结束 ---");
	}
  	return Plugin_Continue;
}

CheckZeroInGameBug()
{
	for (new i=1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			return;
	}

	RoundNo = 0;
}

stock GetTeamRoundScore(logical_team)
{
	return SDKCall(fGTS, logical_team, 1);
}

SwapLogicalTeam()
{
	new Temp = SurvivorLogicalTeam;
	SurvivorLogicalTeam = InfectedLogicalTeam;
	InfectedLogicalTeam = Temp;
}

SwapPlayerTeam()
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == TEAM_SURVIVORS)
			{
				NextRoundTeam[i] = TEAM_INFECTED;
			}
			else if(GetClientTeam(i) == TEAM_INFECTED)
			{
				NextRoundTeam[i] = TEAM_SURVIVORS;
			} else
			{
				NextRoundTeam[i] = TEAM_SPECTATORS;
			}
		}
	}
}

UpdatePlayerTeam()
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == TEAM_SURVIVORS)
			{
				NextRoundTeam[i] = TEAM_SURVIVORS;
			}
			else if(GetClientTeam(i) == TEAM_INFECTED)
			{
				NextRoundTeam[i] = TEAM_INFECTED;
			} else
			{
				NextRoundTeam[i] = TEAM_SPECTATORS;
			}
		}
	}
}

LogTeamInfo()
{
	LogToFileEx(LogPath, "--- ### 阵营资讯 ### ---");
	LogToFileEx(LogPath, "### 幸存者阵营 ###");
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == TEAM_SURVIVORS)
			{
				LogToFileEx(LogPath, "%N [UserID: %d, NextRoundTeam: %d]", i, i, NextRoundTeam[i]);
			}
		}
	}
	LogToFileEx(LogPath, "### 特殊感染者阵营 ###");
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == TEAM_INFECTED)
			{
				LogToFileEx(LogPath, "%N [UserID: %d, NextRoundTeam: %d]", i, i, NextRoundTeam[i]);
			}
		}
	}
	LogToFileEx(LogPath, "### 观察者阵营 ###");
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == TEAM_SPECTATORS)
			{
				LogToFileEx(LogPath, "%N [UserID: %d, NextRoundTeam: %d]", i, i, NextRoundTeam[i]);
			}
		}
	}
	LogToFileEx(LogPath, "--- ### 阵营资讯 ### ---");
}

public Action:Event_PlayerUse(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new entity = GetEventInt(hEvent, "targetid");
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		if(robot[i] > 0 && robot[i] == entity)
		{
			if(GetConVarInt(g_hCvarShow))PrintHintText(i, "%N尝试拿下你的Robot!", Client);
			if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "你尝试拿下%N的Robot",i);
			Release(i);
			AddRobot(i);
 		}
	}
	return Plugin_Continue;
}
/* 升级和回复MP代码 */
public Action:PlayerLevelAndMPUp(Handle:timer, any:target)
{
	if(IsClientInGame(target))
	{
		if(!IsPasswordConfirm[target]){
			PasswordRemindTime[target] +=1;
			if(PasswordRemindTime[target] >= PasswordRemindSecond)
			{
				PasswordRemindTime[target] = 0;
				if(StrEqual(Password[target], "", true)){
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_PASSWORD_NOTACTIVATED);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_PASSWORD_EXPLAIN);
				} else {
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_PASSWORD_NOTCONFIRM);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_PASSWORD_EXPLAIN);
				}
			}
		}
		if(EXP[target] >= GetConVarInt(LvUpExpRate)*(Lv[target]+1))
		{
			Lottery[target]++;
			EXP[target] -= GetConVarInt(LvUpExpRate)*(Lv[target]+1);
			Lv[target] ++;
			StatusPoint[target] += GetConVarInt(LvUpSP);
			SkillPoint[target] += GetConVarInt(LvUpKSP);
			Cash[target] += GetConVarInt(LvUpCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_LEVEL_UP_1, Lv[target], GetConVarInt(LvUpSP), GetConVarInt(LvUpKSP), GetConVarInt(LvUpCash));
			if(GetConVarInt(g_hCvarShow))CPrintToChat(target, MSG_LEVEL_UP_2);
			//RandomAddSkill(target);
			CreateTimer(1.0, Timer_AutoAddSkillPoint, target);
			for (new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && i != target)
				{
					if(!IsFakeClient(i))	if(GetConVarInt(g_hCvarShow))CPrintToChat(i,"{green}%N{olive}已升级至{green}%d{olive}!", target, Lv[target]);
				}
			}

			AttachParticle(target, PARTICLE_SPAWN, 3.0);
			LogToFileEx(LogPath, "%N已升级至%d!", target, Lv[target]);
			/* 储存玩家记录 */
			if(StrEqual(Password[target], "", true) || IsPasswordConfirm[target])	ClientSaveToFileSave(target);
		}
		if(GetClientTeam(target) != TEAM_SPECTATORS){
			if(MP[target] + IntelligenceEffect_IMP[target] > MaxMP[target]) MP[target] = MaxMP[target];
			else MP[target] += IntelligenceEffect_IMP[target];
		}
		/* 获取所观察的玩家信息 */
		if(!IsPlayerAlive(target))	GetObserverTargetInfo(target);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

String:NameInfo(Client, mode)
{
	decl String:NameInfoString[192];
	if(StrEqual(Password[Client], "", true))
	{
		if(mode == colored)
		{
			if(IsClientInGame(Client))
			{
				if(GetClientTeam(Client) == TEAM_SURVIVORS)	Format(NameInfoString, sizeof(NameInfoString), "\x05[生还者]\x04%N\x01", Client);
				else if(GetClientTeam(Client) == TEAM_INFECTED)	Format(NameInfoString, sizeof(NameInfoString), "\x05[感染者]\x04%N\x01", Client);
				else	Format(NameInfoString, sizeof(NameInfoString), "\x05[观察者]\x04%N\x01", Client);
			}
		}
		else if(mode == simple) Format(NameInfoString, sizeof(NameInfoString), "[玩家]%N", Client);
	} else if(!IsPasswordConfirm[Client])
	{
		if(mode == colored)
		{
			if(IsClientInGame(Client))
			{
				if(GetClientTeam(Client) == TEAM_SURVIVORS)	Format(NameInfoString, sizeof(NameInfoString), "{green}[未输入密码登入]{blue}%N{default}", Client);
				else if(GetClientTeam(Client) == TEAM_INFECTED)	Format(NameInfoString, sizeof(NameInfoString), "{green}[未输入密码登入]{red}%N{default}", Client);
				else	Format(NameInfoString, sizeof(NameInfoString), "\x05[等待模式]\x04%N\x01", Client);
			}
		}
		else if(mode == simple) Format(NameInfoString, sizeof(NameInfoString), "[等待模式]%N", Client);
	} else
	{
		decl String:job[32];
		if(JD[Client] == 0)			Format(job, sizeof(job), "未转职");
		else if(JD[Client] == 1)	Format(job, sizeof(job), "工程师");
		else if(JD[Client] == 2)	Format(job, sizeof(job), "士兵");
		else if(JD[Client] == 3)	Format(job, sizeof(job), "生物专家");
		else if(JD[Client] == 4)	Format(job, sizeof(job), "心灵医师");
		else if(JD[Client] == 5)	Format(job, sizeof(job), "魔法师");
		if(mode == colored)
		{
			if(IsClientInGame(Client))
			{
				if(GetClientTeam(Client) == TEAM_SURVIVORS)	Format(NameInfoString, sizeof(NameInfoString), "{green}[Lv.%d %s]{blue}%N{default}", Lv[Client], job, Client);
				else if(GetClientTeam(Client) == TEAM_INFECTED)	Format(NameInfoString, sizeof(NameInfoString), "{green}[Lv.%d %s]{red}%N{default}", Lv[Client], job, Client);
				else	Format(NameInfoString, sizeof(NameInfoString), "%N", Lv[Client], job, Client);
			}
		}
		else if(mode == simple) Format(NameInfoString, sizeof(NameInfoString), "%N", Lv[Client], job, Client);
	}
	return NameInfoString;
}

/* 聊天框显示等级信息 */
public Action:Command_Say(Client, args)
{
	if (args < 1)
	{
		return Plugin_Continue;
	}

	decl String:sText[192];
	GetCmdArg(1, sText, sizeof(sText));

	if (Client == 0 || (IsChatTrigger() && sText[0] == '/'))
	{
		return Plugin_Continue;
	}
	/*
	else if(!IsChatTrigger() && sText[0] == '/' && IsAdmin[Client])
	{
		return Plugin_Handled;
	}
	*/
	if(StrContains(sText, "!rpgpw") == 0 || StrContains(sText, "!rpgresetpw") == 0 || StrContains(sText, "!sm_rpgpw") == 0 || StrContains(sText, "!sm_rpgresetpw") == 0 || StrContains(sText, "!pw") == 0 || StrContains(sText, "!mm") == 0)
	{
		return Plugin_Handled;
	}
	
	if(IsAdmin[Client] && sText[0] == '/' && !IsChatTrigger())
	{
		PrintToChat(Client, "\x03[提示]\x01 命令\x05 %s\x01 无效！", sText);
		return Plugin_Handled;
	}
	
	new mode = GetConVarInt(ShowMode);
	new ismode = GetConVarInt(g_hCvarShow);

	if (GetClientTeam(Client) == TEAM_SURVIVORS)
	{
		if (!mode) CPrintToChatAll("{blue}%N{default}：%s", Client, sText);
		else if (mode && ismode) CPrintToChatAll("%s：%s", NameInfo(Client, colored), sText);
		LogToFileEx(LogPath, "(全体)[幸存者]%s：%s", NameInfo(Client, simple), sText);
	}
	else if (GetClientTeam(Client) == TEAM_INFECTED)
	{
		if (!mode) CPrintToChatAll("{red}%N{default}：%s", Client, sText);
		else if (mode && ismode) CPrintToChatAll("%s：%s", NameInfo(Client, colored), sText);
		LogToFileEx(LogPath, "(全体)[感染者]%s：%s", NameInfo(Client, simple), sText);
	}
	else if (GetClientTeam(Client) == TEAM_SPECTATORS)
	{
		if (!mode) CPrintToChatAll("{default}%N：%s", Client, sText);
		else if (mode && ismode) CPrintToChatAll("%s：%s", NameInfo(Client, colored), sText);
		LogToFileEx(LogPath, "(全体)[观察者]%s：%s", NameInfo(Client, simple), sText);
	}
	return Plugin_Handled;
}

public Action:Command_SayTeam(Client, args)
{
	if (args < 1)
	{
		return Plugin_Continue;
	}

	decl String:sText[192];
	GetCmdArg(1, sText, sizeof(sText));

	if (Client == 0 || (IsChatTrigger() && sText[0] == '/'))
	{
		return Plugin_Continue;
	}
	/*
	else if(!IsChatTrigger() && sText[0] == '/' && IsAdmin[Client])
	{
		return Plugin_Handled;
	}
	*/
	if(StrContains(sText, "!rpgpw") == 0 || StrContains(sText, "!rpgresetpw") == 0 || StrContains(sText, "!sm_rpgpw") == 0 || StrContains(sText, "!sm_rpgresetpw") == 0 || StrContains(sText, "!pw") == 0 || StrContains(sText, "!mm") == 0)
	{
		return Plugin_Handled;
	}

	if(IsAdmin[Client] && sText[0] == '/' && !IsChatTrigger())
	{
		PrintToChat(Client, "\x03[提示]\x01 命令\x05 %s\x01 无效！", sText);
		return Plugin_Handled;
	}
	
	new mode = GetConVarInt(ShowMode);
	new imode = GetConVarInt(g_hCvarShow);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(Client) == TEAM_SURVIVORS)
		{
			if (GetClientTeam(i) != TEAM_SURVIVORS) continue;
			if (!mode) CPrintToChat(i, "{default}（幸存者）{blue}%N{default}：%s", Client, sText);
			else if (mode && imode) CPrintToChat(i, "{default}（幸存者）%s：%s", NameInfo(Client, colored), sText);
		}
		else if (GetClientTeam(Client) == TEAM_INFECTED)
		{
			if (GetClientTeam(i) != TEAM_INFECTED) continue;
			if (!mode) CPrintToChat(i, "{default}（感染者）{red}%N{default}：%s", Client, sText);
			else if (mode && imode) CPrintToChat(i, "{default}（特殊感染者）%s：%s", NameInfo(Client, colored), sText);
		}
		else if (GetClientTeam(Client) == TEAM_SPECTATORS)
		{
			if (GetClientTeam(i) != TEAM_SPECTATORS) continue;
			if (!mode) CPrintToChat(i, "{default}（观察者）%N：%s", Client, sText);
			else if (mode && imode) CPrintToChat(i, "{default}（观察者）%s：%s", NameInfo(Client, colored), sText);
		}
	}
	if (IsClientInGame(Client) && GetClientTeam(Client) == TEAM_SURVIVORS) LogToFileEx(LogPath, "(队伍)[幸存者]%s: %s", NameInfo(Client, simple), sText);
	else if (IsClientInGame(Client) && GetClientTeam(Client) == TEAM_INFECTED) LogToFileEx(LogPath, "(队伍)[感染者]%s: %s", NameInfo(Client, simple), sText);
	else if (IsClientInGame(Client) && GetClientTeam(Client) == TEAM_SPECTATORS) LogToFileEx(LogPath, "(队伍)[观察者]%s: %s", NameInfo(Client, simple), sText);
	return Plugin_Handled;
}

KillTankSkillsTimers(client)
{
	if(TimerUpdate[client] != INVALID_HANDLE)
	{
		KillTimer(TimerUpdate[client]);
		TimerUpdate[client] = INVALID_HANDLE;
	}
	if(GetSurvivorPositionTimer[client] != INVALID_HANDLE)
	{
		KillTimer(GetSurvivorPositionTimer[client]);
		GetSurvivorPositionTimer[client] = INVALID_HANDLE;
	}
	if(FatalMirrorTimer[client] != INVALID_HANDLE)
	{
		KillTimer(FatalMirrorTimer[client]);
		FatalMirrorTimer[client] = INVALID_HANDLE;
	}
	if(AttachParticleTimer[client] != INVALID_HANDLE)
	{
		KillTimer(AttachParticleTimer[client]);
		AttachParticleTimer[client] = INVALID_HANDLE;
	}
	if(MadSpringTimer[client] != INVALID_HANDLE)
	{
		KillTimer(MadSpringTimer[client]);
		MadSpringTimer[client] = INVALID_HANDLE;
	}
}

public Action:Event_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	IsFrustrated[client] = true;
	TanksFrustrated++;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)){
			if(GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
			{
				new GetEXP =RoundToNearest(DamageToTank[i][client]*GetConVarFloat(TankKilledExp));
				new GetCash = RoundToNearest(DamageToTank[i][client]*GetConVarFloat(TankKilledCash));
				EXP[i] += GetEXP;
				Cash[i] += GetCash;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_EXP_FRUSTRATED_TANK, DamageToTank[i][client], GetEXP, GetCash);
				DamageToTank[i][client] = 0;
			}
		}
	}

	KillTankSkillsTimers(client);

	PrintToServer("[统计] 魔王坦克 (控制者: %N ) 转手!", NameInfo(client, simple));

	return Plugin_Continue;
}

public Action:Event_VersusMarkerReached(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new marker = GetEventInt(event, "marker");
	PrintToServer("[统计] %s 带领大家完成了 %d %%路程", NameInfo(client, simple), marker);
	if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_VersusMarkerReached, NameInfo(client, colored), marker);
	if(GetConVarInt(WitchBalanceLv) > 0)
	{
		new SurvivorTeamLv = 0;
		new InfectedTeamLv = 0;
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				if(GetClientTeam(i) == TEAM_SURVIVORS) SurvivorTeamLv += Lv[i];
				else if(GetClientTeam(i) == TEAM_INFECTED) InfectedTeamLv += Lv[i];
			}
		}
		new AdditionalWitchNo = RoundToNearest(float(SurvivorTeamLv - InfectedTeamLv)/GetConVarInt(WitchBalanceLv));

		if(AdditionalWitchNo >= 1)
		{
			PrintToServer("[统计] 幸存者阵营总等级(%d)多於特殊感染者阵营(%d), 增加 %d 隻Witch!",SurvivorTeamLv, InfectedTeamLv, AdditionalWitchNo);
			if(GetConVarInt(g_hCvarShow))PrintHintTextToAll(MSG_WitchAdd,SurvivorTeamLv, InfectedTeamLv, AdditionalWitchNo);
		}
		
		new anyclient = GetAnyClient();
		new bool:temp = false;
		if (anyclient == 0)
		{
			anyclient = CreateFakeClient("Bot");
			if (anyclient == 0)
			{
				LogError("[L4D] MultiTanks CreateFakeClient returned 0 -- Tank bot was not spawned");
				return Plugin_Continue;
			}
			temp = true;
		}

		for(new i=0; i < AdditionalWitchNo; i++)
		{
			CheatCommand(anyclient, "z_spawn", "witch auto");
			//SpawnInfectedBoss(anyclient, ZC_WITCH);
		}
		if (temp) CreateTimer(0.1, kickbot, anyclient);
	}
	return Plugin_Continue;
}

/* 各种经验值 */
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));

	if(IsValidClient(victim))
	{
		if(IsGlowClient[victim])
		{
			IsGlowClient[victim] = false;
			PerformGlow(victim, 0, 0, 0);
		}
		if(GetClientTeam(victim) == TEAM_INFECTED)
		{
			new iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if(!IsFakeClient(victim))
			{
				//玩家特殊感染者死后取消回复生命
				if(HPRegenTimer[victim] != INVALID_HANDLE)
				{
					KillTimer(HPRegenTimer[victim]);
					HPRegenTimer[victim] = INVALID_HANDLE;
				}
				/* 停止超级特感生命週期Timer */
				if(SuperInfectedLifeTimeTimer[victim] != INVALID_HANDLE)
				{
					if(AttachParticleTimer[victim] != INVALID_HANDLE)
					{
						KillTimer(AttachParticleTimer[victim]);
						AttachParticleTimer[victim] = INVALID_HANDLE;
					}
					IsSuperInfectedEnable[victim] = false;
					KillTimer(SuperInfectedLifeTimeTimer[victim]);
					SuperInfectedLifeTimeTimer[victim] = INVALID_HANDLE;
				}
				if(IsValidClient(attacker))
				{
					if(GetClientTeam(attacker) == TEAM_SURVIVORS)	//玩家特殊感染者给幸存者杀死
					{
						EXP[victim] -= RoundToNearest((Lv[victim]*5 - Intelligence[victim])*GetConVarFloat(InfectedGotKilledExpFactor));
						Cash[victim] -= RoundToNearest(Lv[victim]*GetConVarFloat(InfectedGotKilledCashFactor));
						if(GetConVarInt(g_hCvarShow))CPrintToChat(victim, MSG_EXP_INFECTED_GOT_KILLED, RoundToNearest((Lv[victim]*5 - Intelligence[victim])*GetConVarFloat(InfectedGotKilledExpFactor)), RoundToNearest(Lv[victim]*GetConVarFloat(InfectedGotKilledCashFactor)));
					}
				}
			}
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == TEAM_SURVIVORS)	//玩家幸存者杀死特殊感染者
				{
					if(!IsFakeClient(attacker))
					{
						switch (iClass)
						{
							case 1: //smoker
							{
								new EXPGain = GetConVarInt(SmokerKilledExp);
								new CashGain = GetConVarInt(SmokerKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_SMOKER, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SMOKER, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Smoker 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
							case 2: //boomer
							{
								new EXPGain = GetConVarInt(BoomerKilledExp);
								new CashGain = GetConVarInt(BoomerKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_BOOMER, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_BOOMER, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Boomer 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
							case 3: //hunter
							{
								new EXPGain = GetConVarInt(HunterKilledExp);
								new CashGain = GetConVarInt(HunterKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_HUNTER, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_HUNTER, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Hunter 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
							case 4: //spitter
							{
								new EXPGain = GetConVarInt(SpitterKilledExp);
								new CashGain = GetConVarInt(SpitterKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_SPITTER, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SPITTER, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Spitter 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
							case 5: //jockey
							{
								new EXPGain = GetConVarInt(JockeyKilledExp);
								new CashGain = GetConVarInt(JockeyKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_JOCKEY, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_JOCKEY, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Jockey 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
							case 6: //charger
							{
								new EXPGain = GetConVarInt(ChargerKilledExp);
								new CashGain = GetConVarInt(ChargerKilledCash);
								if(IsSuperInfectedEnable[victim])
								{
									EXPGain = RoundToNearest(EXPGain*GetConVarFloat(SuperInfectedExpFactor));
									CashGain = RoundToNearest(CashGain*GetConVarFloat(SuperInfectedCashFactor));
									if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_SI_CHARGER, EXPGain, CashGain);
								} else if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_CHARGER, EXPGain, CashGain);
								PrintToConsole(attacker, "[提示] 杀死了 Charger 获得 %d 金钱", CashGain);
								EXP[attacker] += EXPGain;
								Cash[attacker] += CashGain;
							}
						}
					}
				}
			}
			if(iClass == CLASS_TANK)
			{
				// Its just Tank frustrated, or Player which receive tank. I HATE YOU VALVE!
				if (IsFrustrated[victim])
				{
					TanksFrustrated--;
					IsFrustrated[victim] = false;
					IsTank[victim] = false;
					PrintToServer("[统计] 魔王坦克(控制者: %s)因转手而死亡!", NameInfo(victim, simple));
				} else	if (!IsTank[victim])
				{
					IsTank[victim] = true;
				} else
				{
					IsTank[victim] = false;
					/* Tank死亡给予玩家幸存者经验值和金钱 */
					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i)){
							if(GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
							{
								new GetEXP =RoundToNearest(DamageToTank[i][victim]*GetConVarFloat(TankKilledExp));
								new GetCash = RoundToNearest(DamageToTank[i][victim]*GetConVarFloat(TankKilledCash));
								new tanjki = GetRandomInt(1, 6);
								
								if(IsPlayerAlive(i))                                
								{								    
									switch (tanjki)      	                                
									{		    	                                
										case 1:        		                                
										{		    			                                
											Baoshu[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了肾上腺素!", i);							    			                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】腺上激素已放进你的背包!");	  
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：针筒");
										}		                                
										case 2:        		                                
										{		    			                                
											Baoliao[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了医疗包!", i);							    			                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】医疗包已放进你的背包!");
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：医疗包");
										}		                                
										case 3:        	                                
										{		    		                                
											Baojia[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了弹药夹!", i);							    			                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】弹药夹已放进你的背包!");	
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：弹夹");
										}		                                
										case 4:        		                                
										{		    			                                
											Baozhan[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了棒球棍!", i);							    		                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】棒球棍已放进你的背包!");	                                
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：棒球棍");
										}		                                
										case 5:        		                                
										{		    			                                
											Baoxie[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了AK47步枪!", i);							    			                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】AK47步枪已放进你的背包!");		                                
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：AK47");
										}	                                
										case 6:        		                                
										{		    			                                
											Baodian[i]++;      		            		            	        			                                
											if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家%N获得了电击器!", i);							    			                                
											if(GetConVarInt(g_hCvarShow))PrintHintText(i, "【提示】电击器已放进你的背包!");		                                
											PrintToConsole(i, "[提示] Tank 死亡，你获得了：电击器");
										}	                                								
									}								
								}								
								if(Lv[i] >= 100)						        
								{							        
									if(Lis[i] <= 0)							        
									{							    								        
										new heizi = GetRandomInt(1,10);							    								        
										switch (heizi)								        
										{        									        
											case 1:                                     									  									        
											{							    								    										        
												Lis[i]++;                                   								    									        
												if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家 %N 获得英雄的力量!!!", i);																	    								        
											}                            						    							    								        
											case 2:                                  								        
											{                                                              							    								    									        
												Lis[i]+=2; 								    								        
												if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[提示]玩家 %N 获得特感的力量!!!", i);	                                							        
											}    																		        
										}					    						        
									}				        
								}
								EXP[i] += GetEXP;
								Cash[i] += GetCash;
								if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_EXP_KILL_TANK, DamageToTank[i][victim], GetEXP, GetCash);
								PrintToConsole(i, "[提示] 你对 Tank 造成了 %d 的伤害，获得了 %d 的金钱", DamageToTank[i][victim], GetCash);
								DamageToTank[i][victim] = 0;
								if(IsPlayerAlive(i))
								{
									EXP[i] += GetConVarInt(TankSurvivedExp);
									Cash[i] += GetConVarInt(TankSurvivedCash);
									if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_EXP_KILL_TANK_ALL, GetConVarInt(TankSurvivedExp), GetConVarInt(TankSurvivedCash));
									PrintToConsole(i, "[提示] 你现在还活着，获得了 %d 的金钱", GetConVarInt(TankSurvivedCash));
								}
							}
						}
					}

					/* 魔王坦剋死亡爆炸 */
					/* Explode and burn when died */
					/*
					decl Float:Pos[3];
					GetClientAbsOrigin(victim, Pos);
					EmitSoundToAll(SOUND_EXPLODE, victim);
					ShowParticle(Pos, PARTICLE_DEATH, 5.0);
					LittleFlower(Pos, MOLOTOV, victim);
					LittleFlower(Pos, EXPLODE, victim);
					form_prev[victim] = DEAD;
					*/

					KillTankSkillsTimers(victim);
					/* 陨石 */
					if(GetConVarInt(g_hCvarShow))
					{
						StartStarFall(victim);
						PrintToServer("[统计] 魔王坦克(控制者: %s)死亡!", NameInfo(victim, simple));
					}
					if(GetConVarInt(g_hCvarShow) && TanksMustSpawned) CreateTimer(9.0, Timer_SetAllowSpawnTank);
				}
			}
		} else if(GetClientTeam(victim) == TEAM_SURVIVORS)
		{
			if(!IsValidClient(attacker))
			{
				new attackerentid = GetEventInt(event, "attackerentid");
				for(new i=1; i<=MaxClients; i++)
				{
					if(GetEntPropEnt(attackerentid, Prop_Data, "m_hOwnerEntity") == i)
					{
						new Handle:event_death = CreateEvent("player_death");
						SetEventInt(event_death, "userid", GetClientUserId(victim));
						SetEventInt(event_death, "attacker", GetClientUserId(i));
						SetEventString(event_death, "weapon", "summon_killed");
						FireEvent(event_death);
						break;
					}
				}
			}
			if(!IsFakeClient(victim) && attacker != victim && !StrEqual(WeaponUsed,"summon_killed"))	//玩家幸存者死亡
			{
				new ExpGain = RoundToNearest((Lv[victim]*5 - Intelligence[victim])*GetConVarFloat(SurvivorGotKilledExpFactor));
				new CashGain = RoundToNearest(Lv[victim]*GetConVarFloat(SurvivorGotKilledCashFactor));
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED, ExpGain, CashGain);
				PrintToServer("[统计] [幸存者] %s 死亡!", NameInfo(victim, simple));
			}
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == TEAM_INFECTED && !IsFakeClient(attacker))	//玩家特殊感染者杀死幸存者
				{
					EXP[attacker] += GetConVarInt(SurvivorKilledExp);
					Cash[attacker] += GetConVarInt(SurvivorKilledCash);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_SURVIVOR_KILLED, GetConVarInt(SurvivorKilledExp), GetConVarInt(SurvivorKilledCash));
				} else if(GetClientTeam(attacker) == TEAM_SURVIVORS && attacker!=victim  && !IsFakeClient(attacker) && !IsFakeClient(victim))	//玩家幸存者杀死玩家队友
				{
					if(!StrEqual(WeaponUsed,"satellite_cannon"))	//不是用卫星炮术
					{
						EXP[attacker] -= GetConVarInt(TeammateKilledExp);
						Cash[attacker] -= GetConVarInt(TeammateKilledCash);
						KTCount[attacker] += 1;
						if(GetConVarInt(g_hCvarShow))CPrintToChatAllEx(attacker, MSG_EXP_KILL_TEAMMATE, attacker, KTCount[attacker], GetConVarInt(TeammateKilledExp), GetConVarInt(TeammateKilledCash));

						if(KTLimit >= KTCount[attacker]) if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_KT_WARNING_1, KTLimit);

						if(KTCount[attacker] > KTLimit )
						{
							if(!JobChooseBool[attacker])
							{
								if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_KT_WARNING_2, KTLimit);
							}
							else
							{
								ClinetResetStatus(attacker, General);
								if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_KT_WARNING_3, KTLimit);
							}
						}
					} else	//是用卫星炮术
					{
						EXP[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor;
						Cash[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor/10;
						if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_SKILL_SC_TK, attacker, victim, GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor, GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor/10);
					}
				}
			}
		}
	} else if (!IsValidClient(victim))
	{
		new victimentityid = GetEventInt(event, "entityid");
		for(new i=1;i<=MaxClients;i++)
		{
			if(IsCommonInfected(victimentityid) && GetEntPropEnt(victimentityid, Prop_Data, "m_hOwnerEntity") == i && GetClientTeam(i) == TEAM_INFECTED)
			{
				InfectedSummonCount[i] -= 1;
				SetEntPropEnt(victimentityid, Prop_Data, "m_hOwnerEntity", 0);
				if(SummonKilledCountTimer[i] == INVALID_HANDLE)	SummonKilledCountTimer[i] = CreateTimer(3.0, SummonKilledCountFunction, i);
				SummonKilledCount[i] ++;
				break;
			}
		}
		if(IsValidClient(attacker))
		{
			if(GetClientTeam(attacker) == TEAM_SURVIVORS && !IsFakeClient(attacker))	//玩家幸存者杀死普通感染者
			{
				if(ZombiesKillCountTimer[attacker] == INVALID_HANDLE)	ZombiesKillCountTimer[attacker] = CreateTimer(5.0, ZombiesKillCountFunction, attacker);
				ZombiesKillCount[attacker] ++;
			}
		}
	}

	/* 爆头显示 */
	/*
	if(IsValidClient(attacker))
	{
		if(!IsFakeClient(attacker))
		{
			if(GetEventBool(event, "headshot"))	DisplayDamage(LastDamage[attacker], HEADSHOT, attacker);
			else 	DisplayDamage(LastDamage[attacker], NORMALDEAD, attacker);
		}
	}
	*/
	return Plugin_Continue;
}

public Action:Timer_SetAllowSpawnTank(Handle:timer, any:data)
{
	if(!GetConVarInt(FindConVar("director_force_tank"))) SetConVarInt(FindConVar("director_force_tank"), 1);
}

public Action:SummonKilledCountFunction(Handle:timer, any:client)
{
	KillTimer(timer);
	SummonKilledCountTimer[client] = INVALID_HANDLE;

	if (IsValidClient(client))
	{
		if (SummonKilledCount[client] > 0)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_SKILL_IS_KILLED, SummonKilledCount[client]);
		}
		SummonKilledCount[client]=0;
	}
	return Plugin_Handled;
}
public Action:SummonDisappearedCountFunction(Handle:timer, any:client)
{
	KillTimer(timer);
	SummonDisappearedCountTimer[client] = INVALID_HANDLE;

	if (IsValidClient(client))
	{
		if (SummonDisappearedCount[client] > 0)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_SKILL_IS_DISAPPEAR, SummonDisappearedCount[client]);
		}
		SummonDisappearedCount[client]=0;
	}
	return Plugin_Handled;
}
//拉起队友
public Action:Event_ReviveSuccess(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new Reviver = GetClientOfUserId(GetEventInt(event, "userid"));
	new Subject = GetClientOfUserId(GetEventInt(event, "subject"));

	if (IsValidClient(Reviver))
	{
		if(GetConVarInt(g_hCvarShow))
		{
			SetEntityHealth(Subject, RoundToNearest(100*(1.0+HealthEffect[Subject])*EndranceQualityEffect[Subject]));
		}
		else
		{
			//SetEntPropFloat(Subject, Prop_Send, "m_healthBuffer", (100 * (1.0 + HealthEffect[Subject]) * EndranceQualityEffect[Subject]));
			new Float:fhealth = float(GetConVarInt(FindConVar("survivor_revive_health")));
			if(EndranceQualityLv[Subject])
			{
				fhealth += EndranceQualityLv[Subject] * EndranceQualityEffect[Subject] * fhealth;
				new Float:fmax = float(GetEntProp(Subject, Prop_Data, "m_iMaxHealth"));
				if(fhealth > fmax)
				{
					fhealth = fmax;
				}
			}
			SetEntPropFloat(Subject, Prop_Send, "m_healthBuffer", fhealth);
			//SetEntPropFloat(Subject, Prop_Send, "m_healthBuffer", GetEntPropFloat(Subject, Prop_Send, "m_healthBuffer") + (100 * (1.0 + HealthEffect[Subject]) * EndranceQualityEffect[Subject]));
		}
		if(Reviver != Subject && GetClientTeam(Reviver) == TEAM_SURVIVORS && !IsFakeClient(Reviver))
		{
			RebuildStatus(Subject, false);
			new getCash = GetConVarInt(ReviveTeammateCash), getExp = GetConVarInt(ReviveTeammateExp);
			if (JD[Reviver]==4)
			{
				getCash += Job4_ExtraReward[Reviver];
				getExp += Job4_ExtraReward[Reviver];
				/*
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Reviver, MSG_EXP_REVIVE_JOB4, GetConVarInt(ReviveTeammateExp),
				Job4_ExtraReward[Reviver], GetConVarInt(ReviveTeammateCash), Job4_ExtraReward[Reviver]);
				*/
			}
			/*
			else
			{
				EXP[Reviver] += GetConVarInt(ReviveTeammateExp);
				Cash[Reviver] += GetConVarInt(ReviveTeammateCash);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Reviver, MSG_EXP_REVIVE, GetConVarInt(ReviveTeammateExp), GetConVarInt(ReviveTeammateCash));
			}
			*/
			EXP[Reviver] += getExp;
			Cash[Reviver] += getCash;
			decl String:name[128];
			GetClientName(Subject, name, 128);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Reviver, MSG_EXP_REVIVE, getExp, getCash);
			PrintToConsole(Reviver, "[提示] 你救起了 %s 获得了 %d 金钱！", name, getCash);
		}
		if(GetEventBool(event, "lastlife"))
		{
			decl String:targetName[64];
			decl String:targetModel[128]; 
			decl String:charName[32];
			
			GetClientName(Subject, targetName, sizeof(targetName));
			GetClientModel(Subject, targetModel, sizeof(targetModel));
			
			if(StrContains(targetModel, "teenangst", false) > 0) 
			{
				strcopy(charName, sizeof(charName), "Zoey");
			}
			else if(StrContains(targetModel, "biker", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Francis");
			}
			else if(StrContains(targetModel, "manager", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Louis");
			}
			else if(StrContains(targetModel, "namvet", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Bill");
			}
			else if(StrContains(targetModel, "producer", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Rochelle");
			}
			else if(StrContains(targetModel, "mechanic", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Ellis");
			}
			else if(StrContains(targetModel, "coach", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Coach");
			}
			else if(StrContains(targetModel, "gambler", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Nick");
			}
			else{
				strcopy(charName, sizeof(charName), "Unknown");
			}
			
			if(GetConVarInt(g_hCvarShow))PrintHintTextToAll("%s (\x04%s\x01)已进入频死状态(黑白画面)", targetName, charName);
			if(GetConVarInt(g_hCvarShow))PrintToChatAll("%s (\x04%s\x01)已进入频死状态(黑白画面)", targetName, charName);
		}
	}
	return Plugin_Continue;
}
/* 复活队友 */
public Action:Event_DefibrillatorUsed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new UserID = GetClientOfUserId(GetEventInt(event, "userid"));
	new Subject = GetClientOfUserId(GetEventInt(event, "subject"));

	if (IsValidClient(UserID))
	{
		if(GetClientTeam(UserID) == TEAM_SURVIVORS && !IsFakeClient(UserID))
		{
			RebuildStatus(Subject, false);
			new getExp = GetConVarInt(ReanimateTeammateExp), getCash = GetConVarInt(ReanimateTeammateCash);
			if (JD[UserID]==4)
			{
				getExp += Job4_ExtraReward[UserID];
				getCash += Job4_ExtraReward[UserID];
				/*
				if(GetConVarInt(g_hCvarShow))CPrintToChat(UserID, MSG_EXP_DEFIBRILLATOR_JOB4, GetConVarInt(ReanimateTeammateExp),
				Job4_ExtraReward[UserID], GetConVarInt(ReanimateTeammateCash), Job4_ExtraReward[UserID]);
				*/
			}
			/*
			else
			{
				EXP[UserID] += GetConVarInt(ReanimateTeammateExp);
				Cash[UserID] += GetConVarInt(ReanimateTeammateCash);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(UserID, MSG_EXP_DEFIBRILLATOR, GetConVarInt(ReanimateTeammateExp), GetConVarInt(ReanimateTeammateCash));
			}
			*/
			EXP[UserID] += getExp;
			Cash[UserID] += getCash;
			decl String:name[128];
			GetClientName(Subject, name, 128);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(UserID, MSG_EXP_DEFIBRILLATOR, getExp, getCash);
			PrintToConsole(UserID, "[提示] 你使用电击器复活了 %s 获得了 %d 金钱！", name, getCash);
		}
	}
	return Plugin_Continue;
}
/* 幸存者倒下 */
public Action:Event_IncapacitateEXP(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) == TEAM_INFECTED && !IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(SurvivorIncappedExp);
			Cash[attacker] += GetConVarInt(SurvivorIncappedCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_SURVIVOR_INCAPACITATED, GetConVarInt(SurvivorIncappedExp), GetConVarInt(SurvivorIncappedCash));
		}
	} else
	{
		new attackerentid = GetEventInt(event, "attackerentid");
		for(new i=1;i<=MaxClients;i++)
		{
			if(GetEntPropEnt(attackerentid, Prop_Data, "m_hOwnerEntity") == i)
			{
				new Handle:event_incapacitated = CreateEvent("player_incapacitated");
				SetEventInt(event_incapacitated, "userid", GetClientUserId(victim));
				SetEventInt(event_incapacitated, "attacker", GetClientUserId(i));
				SetEventString(event_incapacitated, "weapon", "summon_attack");
				FireEvent(event_incapacitated);
				break;
			}
		}
	}
	if(!IsFakeClient(victim) && GetClientTeam(victim) == TEAM_SURVIVORS  && !StrEqual(WeaponUsed,"summon_attack"))
	{
		EXP[victim] -= RoundToNearest((Lv[victim]*5 - Intelligence[victim])*GetConVarFloat(SurvivorGotIncappedExpFactor));
		Cash[victim] -= RoundToNearest(Lv[victim]*GetConVarFloat(SurvivorGotIncappedCashFactor));
		if(GetConVarInt(g_hCvarShow))CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED, RoundToNearest((Lv[victim]*5 - Intelligence[victim])*GetConVarFloat(SurvivorGotIncappedExpFactor)), RoundToNearest(Lv[victim]*GetConVarFloat(SurvivorGotIncappedCashFactor)));
		PrintToServer("[统计] [幸存者] %s 倒下!", NameInfo(victim, simple));
	}
	return Plugin_Continue;
}
/* Smoker拉扯幸存者 */
public Action:Event_SmokerGrabbed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) != TEAM_SURVIVORS && !IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(SmokerGrabbedExp);
			Cash[attacker] += GetConVarInt(SmokerGrabbedCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_SMOKER_GRABBED, GetConVarInt(SmokerGrabbedExp), GetConVarInt(SmokerGrabbedCash));
		}
	}
	return Plugin_Continue;
}
public Action:Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	//ability_use returns ability = ability_lunge(hunter), ability_toungue(smoker), ability_vomit(boomer)
	//ability_charge(charger and ability_spit(spitter) (weirdly nothing for jockey though ;/)

	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	//Save the location of the player who just pounced as hunter
	GetClientAbsOrigin(Client,infectedPosition[Client]);

	return Plugin_Continue;
}
/* Hunter突袭幸存者 */
public Action:Event_HunterPounced(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) != TEAM_SURVIVORS && !IsFakeClient(attacker))
		{
			///////////////////////////////////////
			/////// CALCULATE INGAME DAMAGE ///////
			///////////////////////////////////////


			//distance supplied isn't the actual 2d vector distance needed for damage calculation. See more about it at
			//http://forums.alliedmods.net/showthread.php?t=93207

			//get hunter-related pounce cvars
			new maxPounceDistance = 1024;
			new minPounceDistance = 300;
			new oldCap = GetConVarInt(FindConVar("z_hunter_max_pounce_bonus_damage"));
			oldCap++;

			new Float:pouncePosition[3];
			//Get current position while pounced
			GetClientAbsOrigin(attacker,pouncePosition);

			//计算2d hunter扑杀的距离
			//Calculate 2d distance between previous position and pounce position
			new distance = RoundToNearest(GetVectorDistance(infectedPosition[attacker], pouncePosition));

			//Get damage using hunter damage formula, done using floats for accuracy then rounded to an int (intDmg)
			new Float:dmg = (((distance - float(minPounceDistance)) / float(maxPounceDistance - minPounceDistance)) * float(oldCap)) + 1;
			new intDmg = RoundToFloor(dmg);
			new gameScoreDmg = intDmg;
			if(intDmg > oldCap)gameScoreDmg = oldCap;
			else if(intDmg < 0) gameScoreDmg = 0;

			EXP[attacker] += gameScoreDmg*GetConVarInt(HunterPouncedAddExp);
			Cash[attacker] += gameScoreDmg*GetConVarInt(HunterPouncedAddCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_HUNTER_POUNCED, gameScoreDmg, GetConVarInt(HunterPouncedExp) + gameScoreDmg*GetConVarInt(HunterPouncedAddExp), GetConVarInt(HunterPouncedCash) + gameScoreDmg*GetConVarInt(HunterPouncedAddCash));
			
			EmitAmbientSound(SuperPounce_Sound_Hit, pouncePosition);
			ShowParticle(pouncePosition, SuperPounce_Particle_Hit, 1.0);
			new Float:Radius = float(SuperPounceRadius[attacker]);
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 顏色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pouncePosition, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 1.0, 5.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			new Float:entpos[3], Float:SurDistance[3];
			PointPush(attacker, pouncePosition, 100, SuperPounceRadius[attacker], 1.0);
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pouncePosition, SurDistance);
						if(GetVectorLength(SurDistance) <= Radius)
						{
							DealDamage(attacker, i, SuperPounceDamage[attacker], 512, "hunter_super_pounce");
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}
/* Boomer呕吐幸存者 */
public Action:Event_BoomerAttackEXP(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) != TEAM_SURVIVORS && !IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(BoomerVomitExp);
			Cash[attacker] += GetConVarInt(BoomerVomitCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_BOOMER_VOMIT, GetConVarInt(BoomerVomitExp), GetConVarInt(BoomerVomitCash));
		}
	}
	return Plugin_Continue;
}
/* Charger撞到并捉住幸存者 */
public Action:Event_ChargerPummel(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) != TEAM_SURVIVORS && !IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(ChargerGrabbedExp);
			Cash[attacker] += GetConVarInt(ChargerGrabbedCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_CHARGER_GRABBED, GetConVarInt(ChargerGrabbedExp), GetConVarInt(ChargerGrabbedCash));
		}
	}
	return Plugin_Continue;
}
/* Charger撞开幸存者 */
public Action:Event_ChargerImpact(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(attacker))
	{
		if (GetClientTeam(attacker) == TEAM_INFECTED && !IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(ChargerImpactExp);
			Cash[attacker] += GetConVarInt(ChargerImpactCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_CHARGER_IMPACT, GetConVarInt(ChargerImpactExp), GetConVarInt(ChargerImpactCash));
		}
	}
	return Plugin_Continue;
}
/* Jockey骑到幸存者 */
public Action:Event_JockeyRide(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new JocTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (IsValidClient(attacker))
	{
		if (!IsFakeClient(attacker))
		{
			EXP[attacker] += GetConVarInt(JockeyRideExp);
			Cash[attacker] += GetConVarInt(JockeyRideCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_JOCKEY_RIDE, GetConVarInt(JockeyRideExp), GetConVarInt(JockeyRideCash));
		}
	}
	if (IsValidClient(JocTarget))
	{
		if (Agi[attacker] != Agi[JocTarget])
		{
			SetEntPropFloat(JocTarget, Prop_Data, "m_flLaggedMovementValue", 1.0 + AgiEffect[attacker]);
			SetEntityGravity(JocTarget, 1.0/(1.0 + AgiEffect[attacker]));
		}
	}
	return Plugin_Continue;
}
/* Witch被惊吓 */
public Action:Event_WitchHarasserSet(Handle: event, const String: name[], bool: dontBroadcast)
{
	new userid	= GetEventInt(event, "userid");
	if (IsValidClient(userid))	if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_WITCH_HARASSERSET_SET_PANIC, userid);
	TriggerPanicEvent();
	return Plugin_Continue;
}
/* Witch死亡 */
public Action:Event_WitchKilled(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new killer = GetClientOfUserId(GetEventInt(event, "userid"));
	new witchid = GetClientOfUserId(GetEventInt(event, "witchid"));
	for(new i=1;i<=MaxClients;i++)
	{
		if(GetEntPropEnt(witchid, Prop_Data, "m_hOwnerEntity") == i && GetClientTeam(i) == TEAM_INFECTED)
		{
			InfectedSummonCount[i] -= 1;
			SetEntPropEnt(witchid, Prop_Data, "m_hOwnerEntity", 0);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_SKILL_IS_WITCH_KILLED);
			break;
		}
	}
	if (IsValidClient(killer))
	{
		if(GetClientTeam(killer) == TEAM_SURVIVORS && !IsFakeClient(killer))
		{
			EXP[killer] += GetConVarInt(WitchKilledExp);
			Cash[killer] += GetConVarInt(WitchKilledCash);
			if(GetConVarInt(g_hCvarShow))CPrintToChat(killer, MSG_EXP_KILL_WITCH, GetConVarInt(WitchKilledExp), GetConVarInt(WitchKilledCash));
		}
	}
	if (IsValidClient(killer))	if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_WITCH_KILLED_PANIC, killer);
	TriggerPanicEvent();
	return Plugin_Continue;
}
/* 玩家受伤 */
public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new dmg = GetEventInt(event, "dmg_health");
	new eventhealth = GetEventInt(event, "health");
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));
	new Float:AddDamage = 0.0;
	new bool:IsBurningClaw = false;
	new bool:IsSteelSkin = false;
	//new bool:IsVictimDead = false;

	//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("Damage: %d, HP: %d/%d", GetEventInt(event, "dmg_health"), GetEntProp(victim, Prop_Data, "m_iHealth"), GetEventInt(event, "health"));

	if(robot_gamestart)
	{
		if(attacker <= 0 )
		{
			new ent= GetEventInt(event, "attackerentid");
			CIenemy[victim]=ent;
		}
		else
		{
			if(attacker!=victim && GetClientTeam(attacker)==3 && !StrEqual(WeaponUsed,"summon_attack") && !StrEqual(WeaponUsed,"satellite_cannon") && !StrEqual(WeaponUsed,"fire_ball") && !StrEqual(WeaponUsed,"chain_lightning"))
			{
				scantime[victim]=GetEngineTime();
				SIenemy[victim]=attacker;
			}
		}
	}

	//if(eventhealth <= 0)	IsVictimDead = true;


	/* 攻击者的计算 */
	if (IsValidClient(attacker))
	{
		if(!IsFakeClient(attacker) && !StrEqual(WeaponUsed,"damage_reflect") && !StrEqual(WeaponUsed,"satellite_cannon") && !StrEqual(WeaponUsed,"robot_attack") && !StrEqual(WeaponUsed,"fire_ball") && !StrEqual(WeaponUsed,"chain_lightning") && !StrEqual(WeaponUsed,"hunter_super_pounce"))
		{
			/* 力量效果 */
			if(!StrEqual(WeaponUsed,"summon_attack"))
			{
				if(GetClientTeam(attacker) == TEAM_SURVIVORS && EnergyEnhanceLv[attacker]>0)//攻防强化术
				{
					AddDamage = dmg*(StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker]);
				}
				else if(IsSuperInfectedEnable[attacker])//超级特感伤害加成效果
				{
					AddDamage = dmg*(StrEffect[attacker] + SuperInfectedEffect_Attack[attacker]);
				}
				else
				{
					AddDamage = dmg*(StrEffect[attacker]);
				}
			}

			/* 计数特感各攻击次数 */
			if(GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVORS)
			{
				if(StrEqual(WeaponUsed,"insect_swarm"))// Spitter用酸液攻击幸存者
				{
					if(SpitCountTimer[attacker] == INVALID_HANDLE) SpitCountTimer[attacker] = CreateTimer(3.0, SpitCountFunction, attacker);
					SpitCount[attacker] ++;
				} else if(GetEntProp(attacker, Prop_Send, "m_zombieClass") == CLASS_TANK)
				{
					if(StrEqual(WeaponUsed,"tank_claw"))// Tank爪击/投石幸存者
					{
						EXP[attacker] += GetConVarInt(TankClawExp);
						Cash[attacker] += GetConVarInt(TankClawCash);
						if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_TANK_CLAW, GetConVarInt(TankClawExp), GetConVarInt(TankClawCash));
					} else if(strcmp(WeaponUsed,"tank_rock") == 0)
					{
						EXP[attacker] += GetConVarInt(TankRockExp);
						Cash[attacker] += GetConVarInt(TankRockCash);
						if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_TANK_ROCK, GetConVarInt(TankRockExp), GetConVarInt(TankRockCash));
					}
				} else //其他特感的攻击
				{
					if(!StrEqual(WeaponUsed,"summon_attack"))
					{
						if(HurtCountTimer[attacker] == INVALID_HANDLE)	HurtCountTimer[attacker] = CreateTimer(3.0, HurtCountFunction, attacker);
						HurtCount[attacker] ++;
					} else
					{
						if(SummonHurtCountTimer[attacker] == INVALID_HANDLE)	SummonHurtCountTimer[attacker] = CreateTimer(3.0, SummonHurtCountFunction, attacker);
						SummonHurtCount[attacker] ++;
					}
				}
			}
		}
		if(GetClientTeam(attacker) == TEAM_INFECTED && GetEntProp(attacker, Prop_Send, "m_zombieClass") == CLASS_TANK)
		{
			/* 魔王坦克技能 */
			if(StrEqual(WeaponUsed, "tank_claw"))
			{
				if(GetConVarInt(sm_lastboss_enable_quake))
				{
					/* Skill:Earth Quake (If victim is incapped) */
					SkillEndranceQuality(victim, attacker);
				}
				if(GetConVarInt(sm_lastboss_enable_gravity))
				{
					if(form_prev[attacker] == FORMTWO)
					{
						/* Skill:Gravity Claw (Second form only) */
						SkillGravityClaw(victim);
					}
				}
				if(GetConVarInt(sm_lastboss_enable_dread))
				{
					if(form_prev[attacker] == FORMTHREE)
					{
						/* Skill:Dread Claw (Third form only) */
						SkillDreadClaw(victim);
					}
				}
				if(GetConVarInt(sm_lastboss_enable_burn))
				{
					if(form_prev[attacker] == FORMFOUR)
					{
						if(GetClientTeam(victim) == TEAM_SURVIVORS)
						{
							/* Skill:Burning Claw (Forth form only) */
							SkillBurnClaw(victim);
							dmg += eventhealth - 1;
							AddDamage = 0.0;
							eventhealth = 1;
							IsBurningClaw = true;
						}
					}
				}
			} else if(StrEqual(WeaponUsed, "tank_rock"))
			{
				if(GetConVarInt(sm_lastboss_enable_comet))
				{
					if(form_prev[attacker] == FORMFOUR)
					{
						/* Skill:Comet Strike (Forth form only) */
						SkillCometStrike(victim, MOLOTOV);
					}
					else
					{
						/* Skill:Blast Rock (First-Third form) */
						SkillCometStrike(victim, EXPLODE);
					}
				}
			}
		}
	} else
	{
		/* 攻击者是Witch */
		new attackerentid = GetEventInt(event, "attackerentid");
		decl String:classname[20];
		if(IsValidEdict(attackerentid))
		{
			GetEdictClassname(attackerentid, classname, 20);
			if(StrEqual(classname, "witch", false))
			{
				AddDamage = dmg*2.0;
			}
		}
	}

	/* 被攻击者的计算*/
	if (IsValidClient(victim))
	{
		//魔王坦克技能
		if(StrEqual(WeaponUsed, "melee") && GetEntProp(victim, Prop_Send, "m_zombieClass") == CLASS_TANK)
		{
			if(GetConVarInt(sm_lastboss_enable_steel))
			{
				if(form_prev[victim] == FORMTWO)
				{
					/* Skill:Steel Skin (Second form only) */
					EmitSoundToClient(attacker, SOUND_STEEL);
					AddDamage = -float(dmg);
					IsSteelSkin = true;
				}
			}
			if(GetConVarInt(sm_lastboss_enable_gush))
			{
				if(form_prev[victim] == FORMFOUR)
				{
					/* Skill:Flame Gush (Forth form only) */
					SkillFlameGush(attacker, victim);
				}
			}
		}

		//被攻击者是玩家
		if (!IsFakeClient(victim))
		{
			/* 防御效果 */
			if(!IsBurningClaw && !IsSteelSkin && !StrEqual(WeaponUsed,"summon_attack") && !IsMeleeSpeedEnable[victim])
			{
				if(GetClientTeam(victim) == TEAM_SURVIVORS && EnergyEnhanceLv[victim]>0)	//攻防强化术
				{
					AddDamage -= dmg*(EnduranceEffect[victim] + EnergyEnhanceEffect_Endurance[victim]);
					if(AddDamage < -dmg*(Effect_MaxEndurance+EnergyEnhanceEffect_MaxEndurance[victim])) AddDamage = -dmg*(Effect_MaxEndurance+EnergyEnhanceEffect_MaxEndurance[victim]);
				} else if(IsSuperInfectedEnable[victim])	//超级特感防御加成效果
				{
					AddDamage -= dmg*(EnduranceEffect[victim] + SuperInfectedEffect_Endurance[victim]);
					if(AddDamage < -dmg*Effect_MaxEndurance) AddDamage = -dmg*Effect_MaxEndurance;
				} else //普通防御效果
				{
					AddDamage -= dmg*(EnduranceEffect[victim]);
					if(AddDamage < -dmg*Effect_MaxEndurance) AddDamage = -dmg*Effect_MaxEndurance;
				}
			}
			if(GetClientTeam(victim) == TEAM_INFECTED && !IsSteelSkin)
			{
				if(HPRegenerationLv[victim]>0)
				{
					/* 特感生命重生 */
					if(HPRegenTimer[victim] != INVALID_HANDLE)
					{
						if(GetConVarInt(g_hCvarShow))CPrintToChat(victim, MSG_SKILL_RG_STOP);
						KillTimer(HPRegenTimer[victim]);
						HPRegenTimer[victim] = INVALID_HANDLE;
					}
					if(DamageStopTimer[victim] != INVALID_HANDLE )	KillTimer(DamageStopTimer[victim]);
					DamageStopTimer[victim] = CreateTimer(HPRegeneration_DamageStopTime, DamageStopFunction, victim);
				}
			}
		}
		if(StrEqual(WeaponUsed,"fire_ball"))
		{
			AttachParticle(victim, FireBall_Particle_Fire03, 0.5);
		}

		if(!StrEqual(WeaponUsed,"summon_attack"))
		{
			if(!IsBurningClaw)
			{
				if((dmg + AddDamage) < 1.0 && !IsSteelSkin) AddDamage = 1.0 - dmg;

				new health = RoundToNearest(eventhealth - AddDamage);
				if (health < 1)
				{
					if(GetClientTeam(victim) == TEAM_SURVIVORS)
					{
						health = 1;
						new Float:HPBuff = GetEntPropFloat(victim, Prop_Send, "m_healthBuffer");
						if(HPBuff > 0.0)
						{
							new Float:HPBuffDamage = AddDamage - eventhealth + 1;
							if(HPBuff < HPBuffDamage)	HPBuffDamage = HPBuff;
							SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", HPBuff - HPBuffDamage);
							AddDamage = eventhealth - 1 + HPBuffDamage;
						} else AddDamage = float(eventhealth - 1);
					} else if(GetClientTeam(victim) == TEAM_INFECTED)
					{
						health = 0;
						//IsVictimDead = true;
					}
				}
				SetEntityHealth(victim, health);
				SetEventInt(event, "health", health);
			} else SetEventInt(event, "health", 1);
			SetEventInt(event, "dmg_health", RoundToNearest(dmg + AddDamage));

			/* 反伤术 */
			if (!IsFakeClient(victim))
			{
				if(IsValidClient(attacker) && !StrEqual(WeaponUsed,"insect_swarm") && !StrEqual(WeaponUsed, "tank_rock")){
					if(IsDamageReflectEnable[victim] && GetClientTeam(attacker) != TEAM_SURVIVORS)
						DealDamage(victim,attacker,RoundToNearest((dmg + AddDamage)*(DamageReflectEffect[victim])),0,"damage_reflect");
				}
				else if(!IsValidClient(attacker)) DealDamage(victim,attacker,RoundToNearest((dmg + AddDamage)*(DamageReflectEffect[victim])),0,"damage_reflect");
			}

			/* 伤害显示 */
			/*
			if(IsValidClient(attacker))
			{
				if(!IsFakeClient(attacker))
				{
					if(!IsVictimDead)
					{
						DisplayDamage(RoundToNearest(dmg + AddDamage), ALIVE, attacker);
						if(GetClientTeam(victim) == TEAM_INFECTED)
						{
							if(GetEntProp(victim, Prop_Send, "m_zombieClass") == CLASS_TANK)
							{
								DamageToTank[attacker][victim] += RoundToNearest(dmg + AddDamage);
								if(GetConVarInt(g_hCvarShow))PrintHintText(attacker, MSG_TANK_HEALTH_REMAIN, form_prev[victim], victim, GetEventInt(event, "health"), DamageToTank[attacker][victim]);
							}
						}
					} else
					{
						LastDamage[attacker] = RoundToNearest(dmg + AddDamage);
					}
				}
			}
			*/
			/* 当幸存者被召唤尸攻击时创造一个player_hurt讯息 */
			if(GetClientTeam(victim) == TEAM_SURVIVORS)
			{
				/* 攻击者是普感 */
				if(!IsValidClient(attacker))
				{
					new attackerentid = GetEventInt(event, "attackerentid");
					for(new i=1;i<=MaxClients;i++)
					{
						if(GetEntPropEnt(attackerentid, Prop_Data, "m_hOwnerEntity") == i && GetClientTeam(i) == TEAM_INFECTED)
						{
							new Handle:event_hurt = CreateEvent("player_hurt");
							SetEventInt(event_hurt, "userid", GetClientUserId(victim));
							SetEventInt(event_hurt, "attacker", GetClientUserId(i));
							SetEventInt(event_hurt, "dmg_health", GetEventInt(event, "dmg_health"));
							SetEventInt(event_hurt, "health", GetEventInt(event, "health"));
							SetEventString(event_hurt, "weapon", "summon_attack");
							FireEvent(event_hurt);
							break;
						}
					}
				}
			}
		}
	}

	return Plugin_Changed;
}
public Action:HurtCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	HurtCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (HurtCount[attacker] > 0)
		{
			EXP[attacker] += GetConVarInt(InfectedAttackExp)*HurtCount[attacker];
			Cash[attacker] += GetConVarInt(InfectedAttackCash)*HurtCount[attacker];
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_ANY_SI_ATTACK_SURVIVOR, HurtCount[attacker], GetConVarInt(InfectedAttackExp)*HurtCount[attacker], GetConVarInt(InfectedAttackCash)*HurtCount[attacker]);
		}
		HurtCount[attacker]=0;
	}
}
public Action:SpitCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	SpitCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (SpitCount[attacker] > 0)
		{
			EXP[attacker] += GetConVarInt(SpitterSpitExp)*SpitCount[attacker];
			Cash[attacker] += GetConVarInt(SpitterSpitCash)*SpitCount[attacker];
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_SPITTER_SPIT, SpitCount[attacker], GetConVarInt(SpitterSpitExp)*SpitCount[attacker], GetConVarInt(SpitterSpitCash)*SpitCount[attacker]);
		}
		SpitCount[attacker]=0;
	}
}
public Action:SummonHurtCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	SummonHurtCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (SummonHurtCount[attacker] > 0)
		{
			EXP[attacker] += GetConVarInt(SummonInfectedAttackExp)*SummonHurtCount[attacker];
			Cash[attacker] += GetConVarInt(SummonInfectedAttackCash)*SummonHurtCount[attacker];
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_ANY_IS_ATTACK_SURVIVOR, SummonHurtCount[attacker], GetConVarInt(SummonInfectedAttackExp)*SummonHurtCount[attacker], GetConVarInt(SummonInfectedAttackCash)*SummonHurtCount[attacker]);
		}
		SummonHurtCount[attacker]=0;
	}
}
public Action:ZombiesKillCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	ZombiesKillCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (ZombiesKillCount[attacker])
		{
			EXP[attacker] += GetConVarInt(ZombieKilledExp)*ZombiesKillCount[attacker];
			Cash[attacker] += GetConVarInt(ZombieKilledCash)*ZombiesKillCount[attacker];
			if(GetConVarInt(g_hCvarShow))CPrintToChat(attacker, MSG_EXP_KILL_ZOMBIES, ZombiesKillCount[attacker], GetConVarInt(ZombieKilledExp)*ZombiesKillCount[attacker], GetConVarInt(ZombieKilledCash)*ZombiesKillCount[attacker]);
		}
		ZombiesKillCount[attacker]=0;
	}
}
public Action:HPRegenFunction(Handle:timer, any:Client)
{
	if (IsValidClient(Client))
	{
		if (!IsFakeClient(Client))
		{
			new HP = GetClientHealth(Client);
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
			new HPRegen;
			if(iClass == CLASS_TANK)
			{
				HPRegen = RoundToNearest(0.1*HPRegeneration_HPRate[Client]*MaxHP);
			} else
			{
				HPRegen = RoundToNearest(HPRegeneration_HPRate[Client]*MaxHP);
			}
			if (HPRegen + HP <= MaxHP)
			{
				SetEntProp(Client, Prop_Data, "m_iHealth", HPRegen + HP);
			} else if ( (HP < MaxHP) && (MaxHP < (HPRegen + HP)) )
			{
				SetEntProp(Client, Prop_Data, "m_iHealth", MaxHP);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_RG_FULLHP);
				KillTimer(timer);
				HPRegenTimer[Client] = INVALID_HANDLE;
			}
		}
	}
	return Plugin_Continue;
}

public Action:DamageStopFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	DamageStopTimer[Client] = INVALID_HANDLE;
	if(IsValidClient(Client))
	{
		if(!IsPlayerOnFire(Client) && IsPlayerAlive(Client))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_RG_START);
			HPRegenTimer[Client] = CreateTimer(HPRegeneration_Rate, HPRegenFunction, Client, TIMER_REPEAT);
		} else if(IsPlayerOnFire(Client))
		{
			DamageStopTimer[Client] = CreateTimer(HPRegeneration_DamageStopTime, DamageStopFunction, Client);
		}
	}
}

public Action:Event_InfectedHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetEventInt(event, "entityid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new dmg = GetEventInt(event, "amount");
	new eventhealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	//new dmgtype = GetEventInt(event, "type");
	//decl String:WeaponUsed[64];
	new Float:AddDamage = 0.0;
	//new bool:IsVictimDead = false;

	if (IsValidClient(attacker))
	{
		new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"), String:wpnname[64];
		Format(wpnname, 64, "");
		if(IsValidEntity(weapon) && IsValidEdict(weapon)) GetEdictClassname(weapon, wpnname, 64);
		/* 力量效果 */
		if(GetClientTeam(attacker) == TEAM_SURVIVORS && EnergyEnhanceLv[attacker]>0)//攻防强化术
		{
			AddDamage = dmg*(StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker]);
		}
		else if(IsSuperInfectedEnable[attacker])//超级特感伤害加成效果
		{
			AddDamage = dmg*(StrEffect[attacker] + SuperInfectedEffect_Attack[attacker]);
		}
		else //普通攻击
		{
			AddDamage = dmg*(StrEffect[attacker]);
		}
		
		if(Shilv[attacker] && StrContains(wpnname, "weapon_", false) > -1)
		{
			// 榴弹除外
			if(StrContains(wpnname, "shotgun", false) > -1 || StrContains(wpnname, "rifle", false) > -1 || StrContains(wpnname, "smg", false) > -1 || StrContains(wpnname, "pistol", false) > -1 || StrContains(wpnname, "sniper", false) > -1)
			{
				Qstr[attacker] = DMG_LVD * Shilv[attacker];
				AddDamage += Qstr[attacker];
				//PrintToConsole(attacker, "dmg++ %.0f form %.0f wpn %s", AddDamage, Qstr[attacker], wpnname);
			}
		}
		new health = RoundToNearest(eventhealth - AddDamage);
		SetEntProp(victim, Prop_Data, "m_iHealth", health);
		SetEventInt(event, "amount", RoundToNearest(dmg + AddDamage));
	}
/*
	if(RoundToNearest(eventhealth - dmg - AddDamage) <= 0)
	{
		IsVictimDead = true;
	}
*/
	/* 伤害显示 */
/*
	if(IsValidClient(attacker))
	{
		if(!IsFakeClient(attacker))
		{
			if(!IsVictimDead)	DisplayDamage(RoundToNearest(dmg + AddDamage), ALIVE, attacker);
			else LastDamage[attacker] = RoundToNearest(dmg + AddDamage);
		}
	}
*/
	return Plugin_Changed;
}
/*
DisplayDamage(const Damage, const DeadType, const attacker)
{
	for(new i = DamageDisplayBuffer-1; i >= 1; i--)
	{
		strcopy(DamageDisplayString[attacker][i], DamageDisplayLength, DamageDisplayString[attacker][i-1]);
	}
	switch (DeadType)
	{
		case ALIVE: Format(DamageDisplayString[attacker][0], DamageDisplayLength, MSG_DAMAGEDISPLAY, Damage);
		case NORMALDEAD: Format(DamageDisplayString[attacker][0], DamageDisplayLength, MSG_DAMAGEDISPLAY_DEAD, Damage);
		case HEADSHOT: Format(DamageDisplayString[attacker][0], DamageDisplayLength, MSG_DAMAGEDISPLAY_HEADSHOT, Damage);
	}
	if(GetConVarInt(g_hCvarShow))PrintCenterText(attacker, "%s\n%s\n%s\n%s\n%s", DamageDisplayString[attacker][4], DamageDisplayString[attacker][3], DamageDisplayString[attacker][2], DamageDisplayString[attacker][1], DamageDisplayString[attacker][0]);
	if(DamageDisplayCleanTimer[attacker] != INVALID_HANDLE)	KillTimer(DamageDisplayCleanTimer[attacker]);
	DamageDisplayCleanTimer[attacker] = CreateTimer(2.5, DamageDisplayCleanTimerFunction, attacker);
}

public Action:DamageDisplayCleanTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	DamageDisplayCleanTimer[Client] = INVALID_HANDLE;
	if(IsValidClient(Client))
	{
		if(!IsFakeClient(Client))
		{
			for(new j = 0; j < DamageDisplayBuffer; j++)
			{
				strcopy(DamageDisplayString[Client][j], DamageDisplayLength, "");
			}
		}
	}
}
*/
/* 快捷指令 */
public Action:AddStrength(Client, args) //力量
{
	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Str[Client] + 1 > Limit_Str)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Str);
				}
				return Plugin_Handled;
			}
			else
			{
				Str[Client] += 1;
				StatusPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_STR, Str[Client], StrEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Str[Client] + StringToInt(arg) > Limit_Str)
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Str);
				return Plugin_Handled;
			}
			else
			{
				Str[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_STR, Str[Client], StrEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else 
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
			}
		}
	}
	else 
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChat(Client, MSG_LACK_POINTS);
		}
	}
	return Plugin_Handled;
}
public Action:AddAgile(Client, args) //敏捷
{
	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Agi[Client] + 1 > Limit_Agi)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Agi);
				}
				return Plugin_Handled;
			}
			else
			{
				Agi[Client] += 1;
				StatusPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_AGI, Agi[Client], AgiEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_INVALID_ARG);
			}
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Agi[Client] + StringToInt(arg) > Limit_Agi)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Agi);
				}
				return Plugin_Handled;
			}
			else
			{
				Agi[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_AGI, Agi[Client], AgiEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddHealth(Client, args) //生命
{
	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Health[Client] + 1 > Limit_Health)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Health);
				}
				return Plugin_Handled;
			}
			else
			{
				Health[Client] += 1;
				StatusPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_HEALTH, Health[Client], HealthEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
				new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
				if(iClass != CLASS_TANK)
				{
					new HealthForStatus = GetClientHealth(Client);
					SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HealthForStatus*(1+Effect_Health)));
				}
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Health[Client] + StringToInt(arg) > Limit_Health)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Health);
				}
				return Plugin_Handled;
			}
			else
			{
				Health[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_HEALTH, Health[Client], HealthEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
				new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
				if(iClass != CLASS_TANK)
				{
					new HealthForStatus = GetClientHealth(Client);
					SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HealthForStatus*(1+Effect_Health*StringToInt(arg))));
				}
			}
		}
		else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddEndurance(Client, args) //耐力
{
	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Endurance[Client] + 1 > Limit_Endurance)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Endurance);
				}
				return Plugin_Handled;
			}
			else
			{
				Endurance[Client] += 1;
				StatusPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_ENDURANCE, Endurance[Client], EnduranceEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_INVALID_ARG);
			}
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Endurance[Client] + StringToInt(arg) > Limit_Endurance)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Endurance);
				}
				return Plugin_Handled;
			}
			else
			{
				Endurance[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_ENDURANCE, Endurance[Client], EnduranceEffect[Client]*100);
				}
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddIntelligence(Client, args) //智力
{
	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Intelligence[Client] + 1 > Limit_Intelligence)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Intelligence);
				}
				return Plugin_Handled;
			}
			else
			{
				Intelligence[Client] += 1;
				StatusPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_INTELLIGENCE, Intelligence[Client], MaxMP[Client], IntelligenceEffect_IMP[Client]);
				}
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_INVALID_ARG);
			}
			return Plugin_Handled;
		}
		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Intelligence[Client] + StringToInt(arg) > Limit_Intelligence)
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Intelligence);
				}
				return Plugin_Handled;
			}
			else
			{
				Intelligence[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_STATUS_INTELLIGENCE, Intelligence[Client], MaxMP[Client], IntelligenceEffect_IMP[Client]);
				}
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else 
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
			}
		}
	}
	else 
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChat(Client, MSG_LACK_POINTS);
		}
	}
	return Plugin_Handled;
}
/* 快捷加点结束 */

/* 技能快捷指令 */
public Action:UseHealing(Client, args) //治疗
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) HealingFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:HealingFunction(Client)
{
	if(HealingLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_1);
		PrintToConsole(Client, MSG_NEED_SKILL_1);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		PrintToConsole(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(HealingTimer[Client] != INVALID_HANDLE)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HL_ENABLED);
		PrintToConsole(Client, MSG_SKILL_HL_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Healing) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Healing), MP[Client]);
		PrintToConsole(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Healing), MP[Client]);
		return Plugin_Handled;
	}
	
	if(IsBioShieldEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		PrintToConsole(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_Healing);

	HealingCounter[Client] = 0;
	HealingTimer[Client] = CreateTimer(1.0, HealingTimerFunction, Client, TIMER_REPEAT);

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HL_ANNOUNCE, HealingLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用治疗术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingTimerFunction(Handle:timer, any:Client)
{
	HealingCounter[Client]++;
	new HP = GetClientHealth(Client);
	if(HealingCounter[Client] <= HealingDuration[Client])
	{
		if (IsPlayerIncapped(Client))
		{
			SetEntProp(Client, Prop_Data, "m_iHealth", HP+HealingEffect);
		} else
		{
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			if(MaxHP > HP+HealingEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iHealth", HP+HealingEffect);
			}
			else if(MaxHP < HP+HealingEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iHealth", MaxHP);
			}
		}
		decl Float:myPos[3];
		GetClientAbsOrigin(Client, myPos);
		ShowParticle(myPos, PARTICLE_HLEFFECT, 1.0);
	} else
	{
		if (IsValidClient(Client))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HL_END);
			PrintToConsole(Client, MSG_SKILL_HL_END);
		}
		KillTimer(timer);
		HealingTimer[Client] = INVALID_HANDLE;
	}
}

/* 制造子弹 */
public Action:UseAmmoMaking(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) AmmoMakingFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:AmmoMakingFunction(Client)
{
	if(JD[Client] != 1)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB1);
		return Plugin_Handled;
	}

	if(AmmoMakingLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_3);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_AmmoMaking) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_AmmoMaking), MP[Client]);
		return Plugin_Handled;
	}

	new gun1 = GetPlayerWeaponSlot(Client, 0);
	new gun2 = GetPlayerWeaponSlot(Client, 1);

	new AddedAmmo;
	decl String:gun1ClassName[64];
	decl String:gun2ClassName[64];

	if(gun1 != -1)
	{
		GetEdictClassname(gun1, gun1ClassName, sizeof(gun1ClassName));
		if(StrContains(gun1ClassName, "shotgun") >= 0 || StrContains(gun1ClassName, "sniper") >= 0 || StrContains(gun1ClassName, "hunting_rifle") >= 0)	AddedAmmo=AmmoMakingLv[Client];
		else if(StrContains(gun1ClassName, "grenade_launcher") >= 0)	AddedAmmo=AmmoMakingLv[Client]/8;
		else AddedAmmo=AmmoMakingEffect[Client];
		new CC1 = GetEntProp(gun1, Prop_Send, "m_iClip1");
		if(CC1+AmmoMakingEffect[Client] <= 255)	SetEntProp(gun1, Prop_Send, "m_iClip1", CC1+AddedAmmo);
		else SetEntProp(gun1, Prop_Send, "m_iClip1", 255);
	}

	if(gun2 != -1)
	{
		GetEdictClassname(gun2, gun2ClassName, sizeof(gun2ClassName));
		if(StrContains(gun2ClassName, "melee") < 0)
		{
			new CC1 = GetEntProp(gun2, Prop_Send, "m_iClip1");
			if(CC1+AmmoMakingEffect[Client] <= 255)	SetEntProp(gun2, Prop_Send, "m_iClip1", CC1+AmmoMakingEffect[Client]);
			else SetEntProp(gun2, Prop_Send, "m_iClip1", 255);
		}
	}

	if(gun1 != -1 || (gun2 != -1 && StrContains(gun2ClassName, "melee") < 0))
	{
		MP[Client] -= GetConVarInt(Cost_AmmoMaking);
		if(AddedAmmo > 0)	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_AM_ANNOUNCE, AmmoMakingLv[Client], AddedAmmo);
		else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_AM_ANNOUNCE, AmmoMakingLv[Client], AmmoMakingEffect[Client]);

		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用子弹制造术!", NameInfo(Client, simple));
	}else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_AM_NOGUN);

	return Plugin_Handled;
}

/* 冲刺 */
public Action:UseSprint(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) SprintFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:SprintFunction(Client)
{
	if(JD[Client] != 2)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB2);
		return Plugin_Handled;
	}

	if(SprintLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_4);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsSprintEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SP_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Sprint) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Sprint), MP[Client]);
		return Plugin_Handled;
	}

	IsSprintEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_Sprint);
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", (1.0 + SprintEffect[Client])*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, (1.0 + SprintEffect[Client])/(1.0 + AgiEffect[Client]));
	SprinDurationTimer[Client] = CreateTimer(SprintDuration[Client], SprinDurationFunction, Client);
	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SP_ANNOUNCE, SprintLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动加速冲刺术!", NameInfo(Client, simple));
	return Plugin_Handled;
}

public Action:SprinDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SprinDurationTimer[Client] = INVALID_HANDLE;
	IsSprintEnable[Client] = false;
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.0*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, 1.0/(1.0 + AgiEffect[Client]));

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SP_END);
	}

	return Plugin_Handled;
}

/* 无限子弹 */
public Action:UseInfiniteAmmo(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) InfiniteAmmoFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:InfiniteAmmoFunction(Client)
{
	if(JD[Client] != 2)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB2);
		return Plugin_Handled;
	}

	if(InfiniteAmmoLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_5);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsInfiniteAmmoEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_IA_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_InfiniteAmmo) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_InfiniteAmmo), MP[Client]);
		return Plugin_Handled;
	}

	IsInfiniteAmmoEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_InfiniteAmmo);

	InfiniteAmmoDurationTimer[Client] = CreateTimer(InfiniteAmmoDuration[Client], InfiniteAmmoDurationFunction, Client);

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_IA_ANNOUNCE, InfiniteAmmoLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动无限子弹术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:InfiniteAmmoDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	InfiniteAmmoDurationTimer[Client] = INVALID_HANDLE;
	IsInfiniteAmmoEnable[Client] = false;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_IA_END);
	}

	return Plugin_Handled;
}

/* 无敌术 */
public Action:UseBioShield(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) BioShieldFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:BioShieldFunction(Client)
{
	if(JD[Client] != 3)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(BioShieldLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_6);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_BS_ENABLED);
		return Plugin_Handled;
	}
	
	if(!IsBioShieldReady[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_BioShield) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_BioShield), MP[Client]);
		return Plugin_Handled;
	}
	
	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*BioShieldSideEffect[Client])
	{
		IsBioShieldEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_BioShield);

		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
		BioShieldDurationTimer[Client] = CreateTimer(BioShieldDuration[Client], BioShieldDurationFunction, Client);
		
		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*BioShieldSideEffect[Client]));
		
		/*  停止治疗术Timer */
		if(HealingTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(HealingTimer[Client]);
			HealingTimer[Client] = INVALID_HANDLE;
		}
		/* 停止反伤术效果Timer */
		if(DamageReflectDurationTimer[Client] != INVALID_HANDLE)
		{
			IsDamageReflectEnable[Client] = false;
			KillTimer(DamageReflectDurationTimer[Client]);
			DamageReflectDurationTimer[Client] = INVALID_HANDLE;
		}
		/* 近战嗜血术效果Timer */
		if(MeleeSpeedDurationTimer[Client] != INVALID_HANDLE)
		{
			IsMeleeSpeedEnable[Client] = false;
			KillTimer(MeleeSpeedDurationTimer[Client]);
			MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
		}

		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_BS_ANNOUNCE, BioShieldLv[Client]);

		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动无敌术!", NameInfo(Client, simple));
	}
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_BS_NEED_HP);

	return Plugin_Handled;
}

public Action:BioShieldDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldDurationTimer[Client] = INVALID_HANDLE;
	IsBioShieldEnable[Client] = false;
	if(IsValidClient(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
	
	IsBioShieldReady[Client] = false;
	BioShieldCDTimer[Client] = CreateTimer(BioShieldCDTime[Client], BioShieldCDTimerFunction, Client);

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_BS_END);
	}

	return Plugin_Handled;
}

public Action:BioShieldCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldCDTimer[Client] = INVALID_HANDLE;
	IsBioShieldReady[Client] = true;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_BS_CHARGED);
	}

	return Plugin_Handled;
}

/* 反伤术 */
public Action:UseDamageReflect(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) DamageReflectFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:DamageReflectFunction(Client)
{
	if(JD[Client] != 3)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(DamageReflectLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_10);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsDamageReflectEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_DR_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_DamageReflect) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_DamageReflect), MP[Client]);
		return Plugin_Handled;
	}
	
	if(IsBioShieldEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*DamageReflectSideEffect[Client])
	{
		IsDamageReflectEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_DamageReflect);

		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*DamageReflectSideEffect[Client]));
		DamageReflectDurationTimer[Client] = CreateTimer(DamageReflectDuration[Client], DamageReflectDurationFunction, Client);

		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_DR_ANNOUNCE, RoundToNearest(MaxHP*DamageReflectSideEffect[Client]),DamageReflectLv[Client]);

		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了反伤术!", NameInfo(Client, simple));
	}
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_DR_NEED_HP);
	return Plugin_Handled;
}

public Action:DamageReflectDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	DamageReflectDurationTimer[Client] = INVALID_HANDLE;
	IsDamageReflectEnable[Client] = false;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_DR_END);
	}

	return Plugin_Handled;
}

/* 近战嗜血术 */
public Action:UseMeleeSpeed(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) MeleeSpeedFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:MeleeSpeedFunction(Client)
{
	if(JD[Client] != 3)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(MeleeSpeedLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_11);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsMeleeSpeedEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_MS_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_MeleeSpeed) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_MeleeSpeed), MP[Client]);
		return Plugin_Handled;
	}
	
	if(IsBioShieldEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}
	
	IsMeleeSpeedEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_MeleeSpeed);

	MeleeSpeedDurationTimer[Client] = CreateTimer(MeleeSpeedDuration[Client], MeleeSpeedDurationFunction, Client);

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_MS_ANNOUNCE, MeleeSpeedLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动近战嗜血术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:MeleeSpeedDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
	IsMeleeSpeedEnable[Client] = false;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_MS_END);
	}

	return Plugin_Handled;
}

/* 卫星炮术 */
public Action:UseSatelliteCannon(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) SatelliteCannonFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:SatelliteCannonFunction(Client)
{
	if(JD[Client] != 1)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB1);
		return Plugin_Handled;
	}

	if(SatelliteCannonLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_14);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsSatelliteCannonReady[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_SatelliteCannon) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SatelliteCannon), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_SatelliteCannon);

	new Float:Radius=float(SatelliteCannonRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACING, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 顏色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonLaunchTime, 5.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, Radius, 0.1, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonLaunchTime, 5.0, 0.0, RedColor, 10, 0);//扩散内圈RedColor
	TE_SendToAll();

	IsSatelliteCannonReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(SatelliteCannonLaunchTime, SatelliteCannonTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SC_ANNOUNCE, SatelliteCannonLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了卫星炮术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:SatelliteCannonTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(SatelliteCannonRadius[Client]);

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	CreateLaserEffect(Client, pos, 230, 230, 80, 230, 6.0, 1.0, LASERMODE_VARTICAL);

	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	ShowParticle(pos, PARTICLE_SCEFFECT, 10.0);
	EmitAmbientSound(SatelliteCannon_Sound_Launch, pos);

	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
			if(GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, SatelliteCannonDamage[Client], 64, "satellite_cannon");
				}
			} else if(GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, SatelliteCannonSurvivorDamage[Client], 64, "satellite_cannon");
				}
			}
		}
	}
	
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(SatelliteCannonDamage[Client]/(1.0 + StrEffect[Client] + EnergyEnhanceEffect_Attack[Client])), 64, "satellite_cannon");
			}
		}
	}
	
	PointPush(Client, pos, SatelliteCannonDamage[Client], SatelliteCannonRadius[Client], 0.5);

	SatelliteCannonCDTimer[Client] = CreateTimer(SatelliteCannonCDTime[Client], SatelliteCannonCDTimerFunction, Client);
}
public Action:SatelliteCannonCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SatelliteCannonCDTimer[Client] = INVALID_HANDLE;
	IsSatelliteCannonReady[Client] = true;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SC_CHARGED);
	}

	return Plugin_Handled;
}

//选择传送
public Action:UseTeleportToSelect(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) TeleportToSelectMenu(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Continue;
}

public Action:TeleportToSelectMenu(Client)
{
	if(JD[Client] != 4)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB4);
		PrintToConsole(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(TeleportToSelectLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_7);
		PrintToConsole(Client, MSG_NEED_SKILL_7);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		PrintToConsole(Client, MSG_PLAYER_DIE);
		
		return Plugin_Handled;
	}

	if(IsTeleportToSelectEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CHARGING);
		PrintToConsole(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_TeleportToSelect) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportToSelect), MP[Client]);
		PrintToConsole(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportToSelect), MP[Client]);
		return Plugin_Handled;
	}

	new Handle:menu = CreateMenu(TeleportToSelectMenu_Handler);

	new incapped=0, dead=0, alive=0;

	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=TEAM_SURVIVORS) continue;
		if (x==Client) continue;
		if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
		if (!IsPlayerIncapped(x)) continue;//过滤没有倒地的玩家
		incapped++;
	}
	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=TEAM_SURVIVORS) continue;
		if (x==Client) continue;
		if (IsPlayerAlive(x)) continue;//过滤活著的玩家
		dead++;
	}
	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=TEAM_SURVIVORS) continue;
		if (x==Client) continue;
		if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
		if (IsPlayerIncapped(x)) continue;//过滤倒地的玩家
		alive++;
	}

	SetMenuTitle(menu, "选择传送至");

	decl String:Incapped[64], String:Dead[64], String:Alive[64];

	if (incapped==0)
		Format(Incapped, sizeof(Incapped), "没有倒下的队友");
	else
		Format(Incapped, sizeof(Incapped), "倒下的队友(%d个)", incapped);
	if (dead==0)
		Format(Dead, sizeof(Dead), "没有死亡的队友");
	else
		Format(Dead, sizeof(Dead), "死亡的队友(%d个)", dead);
	if (alive==0)
		Format(Alive, sizeof(Alive), "没有活著的队友");
	else
		Format(Alive, sizeof(Alive), "活著的队友(%d个)", alive);

	AddMenuItem(menu, "option1", "刷新列表");
	AddMenuItem(menu, "option2", Incapped);
	AddMenuItem(menu, "option3", Dead);
	AddMenuItem(menu, "option4", Alive);

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Continue;
}

public Action:TCCharging(Handle:timer, any:Client)
{
	KillTimer(timer);
	TCChargingTimer[Client] = INVALID_HANDLE;
	IsTeleportToSelectEnable[Client] = false;

	if (IsValidClient(Client) && !IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TC_CHARGED);
	}

	return Plugin_Handled;
}

new t_id[MAXPLAYERS+1];
public TeleportToSelectMenu_Handler(Handle:menu, MenuAction:action, Client, itemNum)
{
	if(action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 0: TeleportToSelectMenu(Client);
			case 1: t_id[Client]=1, TeleportToSelect(Client);
			case 2: t_id[Client]=2, TeleportToSelect(Client);
			case 3: t_id[Client]=3, TeleportToSelect(Client);
		}
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

public Action:TeleportToSelect(Client)
{
	new Handle:menu = CreateMenu(TeleportToSelect_Handler);
	if (t_id[Client]==1) SetMenuTitle(menu, "倒下的队友");
	if (t_id[Client]==2) SetMenuTitle(menu, "死亡的队友");
	if (t_id[Client]==3) SetMenuTitle(menu, "活著的队友");

	decl String:user_id[12];
	decl String:display[MAX_NAME_LENGTH+12];

	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=TEAM_SURVIVORS) continue;
		if (x==Client) continue;
		if (t_id[Client]==1)
		{
			if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
			if (!IsPlayerIncapped(x)) continue;//过滤没有倒地的玩家
			Format(display, sizeof(display), "%N", x);
		}
		if (t_id[Client]==2)
		{
			if (IsPlayerAlive(x)) continue;//过滤活著的玩家
			Format(display, sizeof(display), "%N", x);
		}
		if (t_id[Client]==3)
		{
			if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
			if (IsPlayerIncapped(x)) continue;//过滤倒地的玩家
			Format(display, sizeof(display), "%N", x);
		}

		IntToString(x, user_id, sizeof(user_id));
		AddMenuItem(menu, user_id, display);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public TeleportVFX(Float:Position0, Float:Position1, Float:Position2)
{
	decl Float:Position[3];
	new Float:TEradius=120.0, Float:TEinterval=0.01, Float:TEduration=1.0, Float:TEwidth=5.0, TEMax=30;
	
	Position[0]=Position0;
	Position[1]=Position1;
	
	for(new w=TEMax; w>0; w--)
	{
		Position[2]=Position2+w*TEwidth;
		TE_SetupBeamRingPoint(Position, TEradius, TEradius+0.1, g_BeamSprite, g_HaloSprite, 0, 15,  TEduration, TEwidth, 0.0, CyanColor, 10, 0);
		TE_SendToAll(TEinterval*(TEMax-w));
	}
}

public TeleportToSelect_Handler(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		new String:info[56];
		GetMenuItem(menu, param, info, sizeof(info));
		/* 获得所选择的玩家 */
		new target = StringToInt(info);
		if(target == -1 || !IsClientInGame(target))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[统计] %t", "Player no longer available");
			return;
		}

		decl Float:TeleportOrigin[3],Float:PlayerOrigin[3];
		GetClientAbsOrigin(target, PlayerOrigin);
		TeleportOrigin[0] = PlayerOrigin[0];
		TeleportOrigin[1] = PlayerOrigin[1];
		TeleportOrigin[2] = (PlayerOrigin[2]+0.1);//防止卡人

		//防止重复使用技能使黑屏效果消失
		if(FadeBlackTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[Client]);
			FadeBlackTimer[Client] = INVALID_HANDLE;
		}

		PerformFade(Client, 200);
		FadeBlackTimer[Client] = CreateTimer(10.0, PerformFadeNormal, Client);
		TCChargingTimer[Client] = CreateTimer(230.0 - (TeleportToSelectLv[Client]+AppointTeleportLv[Client])*5, TCCharging, Client);

		TeleportEntity(Client, TeleportOrigin, NULL_VECTOR, NULL_VECTOR);
		EmitSoundToAll(TSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, TeleportOrigin, NULL_VECTOR, true, 0.0);
		
		TeleportVFX(TeleportOrigin[0], TeleportOrigin[1], TeleportOrigin[2]);

		IsTeleportToSelectEnable[Client] = true;

		MP[Client] -= GetConVarInt(Cost_TeleportToSelect);

		if (t_id[Client]==2)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TC_ANNOUNCE2, target);
			if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用心灵传输到了队友 %s 的尸体旁!", NameInfo(Client, simple), NameInfo(target, simple));
		} else
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TC_ANNOUNCE, target);
			if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用心灵传输到了队友 %s 的身边!", NameInfo(Client, simple), NameInfo(target, simple));
		}
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

/* 传送至鼠标所指 */
public Action:UseAppointTeleport(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) AppointTeleport(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

public Action:AppointTeleport(Client)
{
	if(JD[Client] != 4)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(AppointTeleportLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_8);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsAppointTeleportEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_AppointTeleport) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_AppointTeleport), MP[Client]);
		return Plugin_Handled;
	}

	decl Float:position[3], Float:pos[3];
	/* 获得鼠标所指坐标 */
	/*if (GetClientAimedLocationData(Client, position, NULL_VECTOR, NULL_VECTOR) == -1)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{olive}目标不可达!");
		return Plugin_Handled;
	}*/
	GetTracePosition(Client, position);
	/* 黑屏效果 */
	//防止重复使用技能使黑屏效果消失
	if(FadeBlackTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(FadeBlackTimer[Client]);
		FadeBlackTimer[Client] = INVALID_HANDLE;
	}

	PerformFade(Client, 200);
	FadeBlackTimer[Client] = CreateTimer(10.0, PerformFadeNormal, Client);

	pos[0]=position[0];
	pos[1]=position[1];
	pos[2]=position[2]+1.0;
	/* 传送自己至所指坐标 */
	TeleportEntity(Client, pos, NULL_VECTOR, NULL_VECTOR);
	/* 播放Sound */
	EmitSoundToAll(TSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, true, 0.0);

	TeleportVFX(position[0], position[1], position[2]);

	IsAppointTeleportEnable[Client] = true;

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_AT_ANNOUNCE);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用心灵传输到了他想起去的地方!", NameInfo(Client, simple));

	MP[Client] -= GetConVarInt(Cost_AppointTeleport);

	return Plugin_Handled;
}

/* 传送整队 */
public Action:UseTeleportTeam(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) TeleportTeam(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}


public Action:TeleportTeam(Client)
{
	new mode = GetConVarInt(TeleportTeam_Mode);

	if(JD[Client] != 4)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB4);
		PrintToConsole(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(TeleportTeamLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_9);
		PrintToConsole(Client, MSG_NEED_SKILL_9);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		PrintToConsole(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsTeleportTeamEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CHARGING);
		PrintToConsole(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}
	if (mode!=1 && GetConVarInt(Cost_TeleportTeammate) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportTeammate), MP[Client]);
		PrintToConsole(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportTeammate), MP[Client]);
		return Plugin_Handled;
	}
	if (mode==1 && MP[Client] != MaxMP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, MaxMP[Client], MP[Client]);
		PrintToConsole(Client, MSG_SKILL_LACK_MP, MaxMP[Client], MP[Client]);
		return Plugin_Handled;
	}

	if (!IsPlayerOnGround(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TT_ON_GROUND);
		PrintToConsole(Client, MSG_SKILL_TT_ON_GROUND);
		return Plugin_Handled;
	}
	new P;
	if (mode!=1)
	{
		for(new X=1; X<=MaxClients; X++)
		{
			if (!IsValidEntity(X)) continue;
			if (!IsClientInGame(X)) continue;
			if (GetClientTeam(X)!=TEAM_SURVIVORS) continue;
			if (!IsPlayerAlive(X)) continue;
			P = X;
		}

		if(P == -1)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{olive}找不到传送目标!");
			return Plugin_Handled;
		}

		new Handle:menu = CreateMenu(TeleportTeammate_Handler);
		SetMenuTitle(menu, "选择队友");

		decl String:user_id[12];
		decl String:display[MAX_NAME_LENGTH+12];

		for (new x=1; x<=MaxClients; x++)
		{
			if (!IsClientInGame(x)) continue;
			if (GetClientTeam(x)!=TEAM_SURVIVORS) continue;
			if (x==Client) continue;
			if (!IsPlayerAlive(x)) continue;
			Format(display, sizeof(display), "%N", x);
			IntToString(x, user_id, sizeof(user_id));
			AddMenuItem(menu, user_id, display);
		}

		SetMenuExitButton(menu, true);
		DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	}

	if (mode==1)
	{
		for(new X=1; X<=MaxClients; X++)
		{
			if (!IsValidEntity(X)) continue;
			if (!IsClientInGame(X)) continue;
			P = X;
		}

		if(P == -1)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{olive}找不到传送目标!");
			return Plugin_Handled;
		}

		decl Float:position[3];
		for(new Player=1; Player<=P; Player++)
		{
			if (!IsClientInGame(Player)) continue;
			if (GetClientTeam(Player)!=TEAM_SURVIVORS) continue;
			if (!IsPlayerAlive(Player)) continue;

			GetClientAbsOrigin(Client, position);

			//防止重复使用技能使黑屏效果消失
			if(FadeBlackTimer[Client] != INVALID_HANDLE)
			{
				KillTimer(FadeBlackTimer[Client]);
				FadeBlackTimer[Client] = INVALID_HANDLE;
			}

			PerformFade(Player, 230);
			FadeBlackTimer[Player] = CreateTimer(10.0, PerformFadeNormal, Player);

			TeleportEntity(Player, position, NULL_VECTOR, NULL_VECTOR);
			EmitSoundToAll(TSOUND, Player, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, true, 0.0);
		}
		
		TeleportVFX(position[0], position[1], position[2]);

		TTChargingTimer[Client] = CreateTimer(280.0 - TeleportTeamLv[Client]*5, TTCharging, Client);

		IsTeleportTeamEnable[Client] = true;

		MP[Client] = 0;

		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TT_ANNOUNCE);

		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用心灵传输使所有队友回到他身边!", NameInfo(Client, simple));
	}

	return Plugin_Handled;
}

public TeleportTeammate_Handler(Handle:menu, MenuAction:action, Client, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		new target = StringToInt(info);
		if(target == -1 || !IsClientInGame(target))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[统计] %t", "Player no longer available");
			return;
		}

		decl Float:position[3];
		GetClientAbsOrigin(Client, position);

		//防止重复使用技能使黑屏效果消失
		if(FadeBlackTimer[target] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[target]);
			FadeBlackTimer[target] = INVALID_HANDLE;
		}
		if(FadeBlackTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[Client]);
			FadeBlackTimer[Client] = INVALID_HANDLE;
		}

		PerformFade(target, 200);
		PerformFade(Client, 200);
		FadeBlackTimer[target] = CreateTimer(10.0, PerformFadeNormal, target);
		FadeBlackTimer[Client] = CreateTimer(10.0, PerformFadeNormal, Client);

		TeleportEntity(target, position, NULL_VECTOR, NULL_VECTOR);
		EmitSoundToAll(TSOUND, target, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, true, 0.0);
		
		TeleportVFX(position[0], position[1], position[2]);
		
		TTChargingTimer[Client] = CreateTimer(160.0 - TeleportTeamLv[Client]*5, TTCharging, Client);

		IsTeleportTeamEnable[Client] = true;

		MP[Client] -= GetConVarInt(Cost_TeleportTeammate);

		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TT_ANNOUNCE_2, target);

		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 使用心灵传输使队友 %s 回到他身边!", NameInfo(Client, simple), NameInfo(target, simple));
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

public Action:TTCharging(Handle:timer, any:Client)
{
	KillTimer(timer);
	TTChargingTimer[Client] = INVALID_HANDLE;
	IsTeleportTeamEnable[Client] = false;

	if (IsValidClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_TT_CHARGED);
	}
	return Plugin_Handled;
}

public Action:PerformFadeNormal(Handle:timer, any:Client)
{
	KillTimer(timer);
	FadeBlackTimer[Client] = INVALID_HANDLE;
	IsAppointTeleportEnable[Client] = false;
	if(IsClientInGame(Client))	PerformFade(Client, 0);
	return Plugin_Handled;
}

public bool:TraceEntityFilterPlayers(entity, contentsMask, any:data)
{
	return entity > MaxClients && entity != data;
}

/* 黑屏效果 */
public PerformFade(Client, amount)
{
	new Handle:message = StartMessageOne("Fade",Client);
	BfWriteShort(message, 0);
	BfWriteShort(message, 0);
	if (amount == 0)
	{
		BfWriteShort(message, (0x0001 | 0x0010));
	}
	else
	{
		BfWriteShort(message, (0x0002 | 0x0008));
	}
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, amount);
	EndMessage();
}

/* 治疗光球术 */
public Action:UseHealingBall(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) HealingBallFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:HealingBallFunction(Client)
{
	if(JD[Client] != 4)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(HealingBallLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_18);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsHealingBallEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HB_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_HealingBall) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_HealingBall), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_HealingBall);

	new Float:Radius=float(HealingBallRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 50.0;
	EmitAmbientSound(HealingBall_Sound_Lanuch, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 顏色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 5.0, BlueColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();
	
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	IsHealingBallEnable[Client] = true;

	new Handle:pack;
	HealingBallTimer[Client] = CreateDataTimer(HealingBallInterval, HealingBallTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HB_ANNOUNCE, HealingBallLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了治疗光球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingBallTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];
	
	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);
	
	EmitAmbientSound(HealingBall_Sound_Heal, pos);
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}
	
	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=float(HealingBallRadius[Client]);
	
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 顏色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 10.0, 5.0, BlueColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	if(GetEngineTime() - time < HealingBallDuration[Client])
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						new HP = GetClientHealth(i);
						if (IsPlayerIncapped(i))
						{
							SetEntProp(i, Prop_Data, "m_iHealth", HP+HealingBallEffect[Client]);
							HealingBallExp[Client] += GetConVarInt(LvUpExpRate)*HealingBallEffect[Client]/500;
						} else
						{
							new MaxHP = GetEntProp(i, Prop_Data, "m_iMaxHealth");
							if(MaxHP > HP+HealingBallEffect[i])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", HP+HealingBallEffect[Client]);
								HealingBallExp[Client] += GetConVarInt(LvUpExpRate)*HealingBallEffect[Client]/500;
							}
							else if(MaxHP < HP+HealingBallEffect[Client])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", MaxHP);
								HealingBallExp[Client] += GetConVarInt(LvUpExpRate)*(MaxHP - HP)/500;
							}
						}
						ShowParticle(entpos, HealingBall_Particle_Effect, 0.5);
						TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 0.5, BlueColor, 0);
						TE_SendToAll();
					}
				}
			}
		}
	} else
	{
		if (IsValidClient(Client) && !IsFakeClient(Client))
		{
			if(HealingBallExp[Client] > 0)
			{
				EXP[Client] += HealingBallExp[Client];
				Cash[Client] += HealingBallExp[Client]/10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]/10);
				if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 的治疗光球术结束了! 总共治疗了队友 %d HP, 获得 %d Exp, %d $", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]/10);
			}
		}
		HealingBallExp[Client] = 0;
		IsHealingBallEnable[Client] = false;
		KillTimer(HealingBallTimer[Client]);
		HealingBallTimer[Client] = INVALID_HANDLE;
	}
}

/* 火球术 */
public Action:UseFireBall(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) FireBallFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:FireBallFunction(Client)
{
	if(JD[Client] != 5)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(FireBallLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_15);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_FireBall) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_FireBall), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_FireBall);
	
	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FireBall_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl"); 
	DispatchSpawn(ent); 
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:FireBallPos[3];
	GetClientEyePosition(Client, FireBallPos);
	//FireBallPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(FireBallPos, TracePos, angle);
	NormalizeVector(angle, angle);
	
	decl Float:FireBallTempPos[3];
	FireBallTempPos[0] = angle[0]*50.0;
	FireBallTempPos[1] = angle[1]*50.0;
	FireBallTempPos[2] = angle[2]*50.0;
	AddVectors(FireBallPos, FireBallTempPos, FireBallPos);
	
	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;
	
	DispatchKeyValue(ent, "rendercolor", "255 80 80");
	
	TeleportEntity(ent, FireBallPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");
	
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);
	
	new Handle:h;
	CreateDataTimer(0.1, UpdateFireBall, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_FB_ANNOUNCE, FireBallLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了火球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateFireBall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);
	
	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, FireBall_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > FireIceBallLife || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(FireBallRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);
			
			/* Emit impact sound */
			EmitAmbientSound(FireBall_Sound_Impact01, pos);
			EmitAmbientSound(FireBall_Sound_Impact02, pos);
			
			ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
			ShowParticle(pos, FireBall_Particle_Fire02, 5.0);
			
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 顏色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			
			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(FireBallDamage[Client]/(1.0 + StrEffect[Client] + EnergyEnhanceEffect_Attack[Client])), 8, "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client, i, FireBallDamage[Client], 262144, "fire_ball", FireBallDamageInterval[Client], FireBallDuration[Client]);
						}
					} else if(GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client, i, FireBallTKDamage[Client], 262144, "fire_ball", FireBallDamageInterval[Client], FireBallDuration[Client]);
						}
					}
				}
			}
			return Plugin_Stop;	
		}
		return Plugin_Continue;	
	} else return Plugin_Stop;	
}

bool:IsRock(ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);

		if(StrEqual(classname, "tank_rock", true))
		{
			return true;
		}
	}
	return false;
}

/* 冰球术 */
public Action:UseIceBall(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) IceBallFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:IceBallFunction(Client)
{
	if(JD[Client] != 5)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(IceBallLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_16);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_IceBall) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_IceBall), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_IceBall);
	
	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent); 
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:IceBallPos[3];
	GetClientEyePosition(Client, IceBallPos);
	decl Float:angle[3];
	MakeVectorFromPoints(IceBallPos, TracePos, angle);
	NormalizeVector(angle, angle);
	
	decl Float:IceBallTempPos[3];
	IceBallTempPos[0] = angle[0]*50.0;
	IceBallTempPos[1] = angle[1]*50.0;
	IceBallTempPos[2] = angle[2]*50.0;
	AddVectors(IceBallPos, IceBallTempPos, IceBallPos);
	
	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;
	
	DispatchKeyValue(ent, "rendercolor", "80 80 255");
	
	TeleportEntity(ent, IceBallPos, angle, velocity);
	ActivateEntity(ent);
	
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);
	
	new Handle:h;	
	CreateDataTimer(0.1, UpdateIceBall, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_IB_ANNOUNCE, IceBallLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了冰球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateIceBall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);
	
	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > FireIceBallLife || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(IceBallRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);
			
			/* Emit impact sound */
			EmitAmbientSound(IceBall_Sound_Impact01, pos);
			EmitAmbientSound(IceBall_Sound_Impact02, pos);
			
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 顏色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			
			TE_SetupGlowSprite(pos, g_GlowSprite, IceBallDuration[Client], 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, IceBall_Particle_Ice01, 5.0);		
			
			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(IceBallDamage[Client]/(1.0 + StrEffect[Client] + EnergyEnhanceEffect_Attack[Client])), 16, "ice_ball");
						//FreezePlayer(iEntity, entpos, IceBallDuration[Client]);
						EmitAmbientSound(IceBall_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, IceBallDuration[Client], 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, IceBallDamage[Client], 16, "ice_ball");
							FreezePlayer(i, entpos, IceBallDuration[Client]);
						}
					} else if(GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, IceBallTKDamage[Client], 16, "ice_ball");
							FreezePlayer(i, entpos, IceBallDuration[Client]);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, IceBallRadius[Client], 0.5);
			return Plugin_Stop;	
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}
public FreezePlayer(entity, Float:pos[3], Float:time)
{
	if(IsValidClient(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
		SetEntityRenderColor(entity, 0, 128, 255, 135);
		ScreenFade(entity, 0, 128, 255, 192, 2000, 1);
		EmitAmbientSound(IceBall_Sound_Freeze, pos, entity, SNDLEVEL_RAIDSIREN);
		TE_SetupGlowSprite(pos, g_GlowSprite, time, 3.0, 130);
		TE_SendToAll();
		IsFreeze[entity] = true;
	}
	/*else if(IsCommonInfected(entity) || IsWitch(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
		SetEntityRenderColor(entity, 0, 128, 255, 135);
		EmitAmbientSound(IceBall_Sound_Freeze, pos, entity, SNDLEVEL_RAIDSIREN);
		TE_SetupGlowSprite(pos, g_GlowSprite, time, 3.0, 130);
		TE_SendToAll();
	}*/
	CreateTimer(time, DefrostPlayer, entity);
}
public Action:DefrostPlayer(Handle:timer, any:entity)
{
	if(IsValidClient(entity))
	{
		decl Float:entPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
		EmitAmbientSound(IceBall_Sound_Defrost, entPos, entity, SNDLEVEL_RAIDSIREN);
		SetEntityMoveType(entity, MOVETYPE_WALK);
		ScreenFade(entity, 0, 0, 0, 0, 0, 1);
		IsFreeze[entity] = false;
		if(IsValidAliveClient(entity) && GetEntProp(entity, Prop_Send, "m_zombieClass") == CLASS_TANK)
		{
			if(form_prev[entity] == FORMONE)	SetEntityRenderColor(entity, 255, 255, 255, 255);
			else if(form_prev[entity] == FORMTWO)	SetEntityRenderColor(entity, 80, 255, 80, 255);
			else if(form_prev[entity] == FORMTHREE)
			{
				SetEntityRenderColor(entity, 80, 80, 255, 255);
				alpharate = 255;
				Remove(entity);
			}
			else if(form_prev[entity] == FORMFOUR)	SetEntityRenderColor(entity, 255, 80, 80, 255);
		} else SetEntityRenderColor(entity, 255, 255, 255, 255);
	}
	/*else if(IsCommonInfected(entity) || IsWitch(entity))
	{
		decl Float:entPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
		SetEntityMoveType(entity, MOVETYPE_STEP);
		SetEntityRenderColor(entity, 255, 80, 80, 255);
		EmitAmbientSound(IceBall_Sound_Defrost, entPos, entity, SNDLEVEL_RAIDSIREN);
	}*/
}
public Action:OnPlayerRunCmd(client, &buttons)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		/* If freezing, block mouse operation */
		if(IsFreeze[client])
		{
			if(buttons & IN_ATTACK)
				buttons &= ~IN_ATTACK;
			if(buttons & IN_ATTACK2)
				buttons &= ~IN_ATTACK2;
		}
	}
}

/* 连锁闪电术 */
public Action:UseChainLightning(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS) ChainLightningFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:ChainLightningFunction(Client)
{
	if(JD[Client] != 5)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(ChainLightningLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_17);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_ChainLightning) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_ChainLightning), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_ChainLightning);
	
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(ChainLightningLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);
	
	/* Emit impact sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos);
	
	ShowParticle(pos, ChainLightning_Particle_hit, 0.1);
	
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 顏色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, ChainLightningDamage[Client], 1024, "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(ChainLightningDamage[Client]/(1.0 + StrEffect[Client] + EnergyEnhanceEffect_Attack[Client])), 1024, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	
	if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_CL_ANNOUNCE, ChainLightningLv[Client]);

	if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 启动了连锁闪电术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:ChainDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);
	
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(ChainLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChained[victim] = false;
	}
	
	/* Emit impact sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos);	
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();
	
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(ChainLightningDamage[attacker]/(1.0 + StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker])), 1024, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, ChainLightningDamage[attacker], 1024, "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}
public Action:UseSuperInfected(Client, args)
{
	if(GetClientTeam(Client) == TEAM_INFECTED) SuperInfectedFunction(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_USE_INFECTED_ONLY);
	return Plugin_Handled;
}

public Action:SuperInfectedFunction(Client)
{
	new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
	if(iClass == CLASS_TANK)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SI_CANNOT_TANK);
	} else if(IsPlayerGhost(Client) || !IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SI_CANNOT_GHOST);
	} else if(IsSuperInfectedEnable[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SI_ALREADY);
	} else if(SuperInfectedLv[Client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NEED_SKILL_12);
	} else if(GetConVarInt(Cost_SuperInfected) > MP[Client])
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SuperInfected), MP[Client]);
	} else
	{
		IsSuperInfectedEnable[Client]=true;

		CreateSuperInfected(Client);
		
		new Float:NowLocation[3];
		GetClientAbsOrigin(Client, NowLocation);
		
		PointPush(Client, NowLocation, 250, 1000, 1.0);
		EmitAmbientSound(SuperInfected_Sound_launch, NowLocation);
		new Float:SkyLocation[3];
		SkyLocation[0] = NowLocation[0];
		SkyLocation[1] = NowLocation[1];
		SkyLocation[2] = NowLocation[2] + 2000.0;
		TE_SetupBeamPoints(SkyLocation, NowLocation, g_BeamSprite, 0, 0, 0, 3.0, 10.0, 10.0, 10, 10.0, BlueColor, 0);
		TE_SendToAll();
		//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 顏色(Color[4]), (播放速度)10, (标识)0)
		TE_SetupBeamRingPoint(NowLocation, 0.1, 1000.0, g_BeamSprite, g_HaloSprite, 0, 15, 3.0, 5.0, 10.0, BlueColor, 10, 0);//固定外圈BuleColor
		TE_SendToAll();
		AttachParticleTimer[Client] = CreateTimer(1.0, ParticleTimer, Client, TIMER_REPEAT);
		
		new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
		SetEntProp(Client, Prop_Data, "m_iHealth", MaxHP);

		SuperInfectedLifeTimeTimer[Client] = CreateTimer(SuperInfectedDuration[Client], SuperInfectedLifeTimerFunction, Client);

		MP[Client] -= GetConVarInt(Cost_SuperInfected);
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SI_ANNOUNCE, bossname[iClass], SuperInfectedDuration[Client]);
		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 已变成超级 %s!", NameInfo(Client, simple), bossname[iClass]);
	}

	return Plugin_Handled;
}

public Action:CreateSuperInfected(Client)
{
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue",  (1.0 + AgiEffect[Client])*(SuperInfectedEffect_Speed[Client]));

	SetEntityGravity(Client, 1.0/((1.0 + AgiEffect[Client])*(SuperInfectedEffect_Speed[Client])));

	SetEntityRenderColor(Client, 255, 80, 80, 255);

	return;
}

public Action:SuperInfectedLifeTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SuperInfectedLifeTimeTimer[Client] = INVALID_HANDLE;
	
	if(AttachParticleTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(AttachParticleTimer[Client]);
		AttachParticleTimer[Client] = INVALID_HANDLE;
	}

	if(IsValidClient(Client))
	{
		if(IsPlayerAlive(Client) && IsSuperInfectedEnable[Client] && GetEntProp(Client, Prop_Send, "m_zombieClass") != CLASS_TANK)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_SI_STOP);
			IsSuperInfectedEnable[Client] = false;
			SetEntityRenderColor(Client, 255, 255, 255, 255);
			RebuildStatus(Client, false);
		}
	}
	return Plugin_Handled;
}
public Action:UseInfectedSummon(client, args)
{
	if(GetClientTeam(client) == TEAM_INFECTED) InfectedSummonFunction(client);
	else
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_SKILL_USE_INFECTED_ONLY);
	}
	return Plugin_Handled;
}
public Action:InfectedSummonFunction(client)
{
	if(InfectedSummonLv[client] == 0)
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChat(client, MSG_NEED_SKILL_13);
		}
	}
	else
		MenuFunc_InfectedSummon(client);

	return Plugin_Handled;
}
/* 召唤术选单 */
public Action:MenuFunc_InfectedSummon(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "使用技能 MP: %d/%d 生存的召唤感染者: %d/%d", MP[Client], MaxMP[Client], InfectedSummonCount[Client], InfectedSummonMax[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "防暴警察 (%d MP)", GetConVarInt(Cost_InfectedSummon[0]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "防火CEDA人员 (%d MP)", GetConVarInt(Cost_InfectedSummon[1]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "小丑 (%d MP)", GetConVarInt(Cost_InfectedSummon[2]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "泥人 (%d MP)", GetConVarInt(Cost_InfectedSummon[3]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "地盘工人 (%d MP)", GetConVarInt(Cost_InfectedSummon[4]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "赛车手吉米 (%d MP)", GetConVarInt(Cost_InfectedSummon[5]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "被感染的幸存者 [限一次] (%d MP)", GetConVarInt(Cost_InfectedSummon[6]));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "Witch (%d MP)", GetConVarInt(Cost_InfectedSummon[7]));
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_InfectedSummon, MENU_TIME_FOREVER);

	CloseHandle(menu);
	return Plugin_Handled;
}

public MenuHandler_InfectedSummon(Handle:menu, MenuAction:action, client, itemNum)
{
	if (action == MenuAction_Select)
	{
		if(IsPlayerGhost(client) || !IsPlayerAlive(client))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_SKILL_IS_CANNOT_GHOST);
		}
		else if(InfectedSummonCount[client] < InfectedSummonMax[client])
		{
			new mpcost = GetConVarInt(Cost_InfectedSummon[itemNum-1]);
			if(MP[client] >= mpcost)
			{
				decl Float:pos[3];
				GetTracePosition(client, pos);
				pos[2] += 20.0;
				SpawnUncommonInf(client, itemNum-1, pos);
				MP[client] -= mpcost;
			}
			else if(GetConVarInt(g_hCvarShow))PrintHintText(client, MSG_SKILL_LACK_MP, mpcost, MP[client]);
		}
		else if(GetConVarInt(g_hCvarShow))CPrintToChat(client, MSG_SKILL_IS_COUNT_MAX, InfectedSummonMax[client]);
		MenuFunc_InfectedSummon(client);
	}
}
public SpawnUncommonInf(Client, type, Float:location[3])
{
	new zombie;
	if(type < 7)	zombie = CreateEntityByName("infected");
	else if(type == 7)
	{
		zombie = CreateEntityByName("witch");
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_SKILL_IS_WITCH_ANNOUNCE);
		if(GetConVarInt(g_hCvarShow))PrintToServer("[统计] %s 召唤了Witch!", NameInfo(Client, simple));
	}

	SetEntityModel(zombie, UncommonData[type][infectedmodel]);
	new ticktime = RoundToNearest( FloatDiv( GetGameTime(), GetTickInterval() ) ) + 5;
	SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);

	TeleportEntity(zombie, location, NULL_VECTOR, NULL_VECTOR);
	
	DispatchSpawn(zombie);
	ActivateEntity(zombie);
	
	ShowParticle(location, PARTICLE_INFECTEDSUMMON, 1.0);

	SetEntPropEnt(zombie, Prop_Data, "m_hOwnerEntity", Client);
	InfectedSummonCount[Client] +=1;
}
public Action:StatusUp(Handle:timer, any:Client)
{
	if (IsValidClient(Client))
	{
		new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
		if(iClass != CLASS_TANK)	RebuildStatus(Client, false);
	}
	return Plugin_Handled;
}

public Action:RebuildStatus(Client, bool:IsFullHP)
{
	new MaxHP;

	if(GetClientTeam(Client) == TEAM_INFECTED)
	{
		new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
		switch(iClass)
		{
			case 1: MaxHP = GetConVarInt(FindConVar("z_gas_health"));
			case 2: MaxHP = GetConVarInt(FindConVar("z_exploding_health"));
			case 3: MaxHP = GetConVarInt(FindConVar("z_hunter_health"));
			case 4: MaxHP = GetConVarInt(FindConVar("z_spitter_health"));
			case 5: MaxHP = GetConVarInt(FindConVar("z_jockey_health"));
			case 6: MaxHP = GetConVarInt(FindConVar("z_charger_health"));
		}
	} else
	{
		MaxHP = 100;
	}
	SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP*(1.0+HealthEffect[Client])));

	new NewMaxHP = RoundToNearest(MaxHP*(1.0+HealthEffect[Client]));
	new HP = GetClientHealth(Client);

	if(HP > NewMaxHP) SetEntityHealth(Client, NewMaxHP);

	if(IsSprintEnable[Client])
	{
		SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.6*(1.0 + AgiEffect[Client]));
		SetEntityGravity(Client, 1.6/(1.0 + AgiEffect[Client]));
	} else
	{
		SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.0 + AgiEffect[Client]);
		SetEntityGravity(Client, 1.0/(1.0 + AgiEffect[Client]));
	}

	if(IsFullHP)SetEntityHealth(Client, NewMaxHP);
}
public Action:Event_HealSuccess(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	new HealSucTarget = GetClientOfUserId(GetEventInt(event, "subject"));
	new count = GetEventInt(event, "health_restored");
	
	if (GetConVarInt(HealTeammateExp) > 0 && Client != HealSucTarget && !IsFakeClient(Client))
	{
		if(!count) count = 0;
		new getExp = GetConVarInt(HealTeammateExp) + count, getCash = GetConVarInt(HealTeammateCash) + RoundFloat(count / 2.0);
		if (JD[Client]==4)
		{
			getExp += Job4_ExtraReward[Client];
			getCash += Job4_ExtraReward[Client];
			/*
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_EXP_HEAL_SUCCESS_JOB4, GetConVarInt(HealTeammateExp),
			Job4_ExtraReward[Client], GetConVarInt(HealTeammateCash), Job4_ExtraReward[Client]);
			PrintToConsole(Client, "[提示] 你治疗了 %s 获得 %d 金钱！", name, GetConVarInt(HealTeammateCash) + Job4_ExtraReward[Client]);
			*/
		}
		/*
		else
		{
			EXP[Client] += GetConVarInt(HealTeammateExp);
			Cash[Client] += GetConVarInt(HealTeammateCash);
			
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_EXP_HEAL_SUCCESS, GetConVarInt(HealTeammateExp), GetConVarInt(HealTeammateCash));
			PrintToConsole(Client, "[提示] 你治疗了 %s 获得 %d 金钱！", name, GetConVarInt(HealTeammateCash));
			
		}
		*/
		EXP[Client] += getExp;
		Cash[Client] += getCash;
		decl String:name[128];
		GetClientName(HealSucTarget, name, 128);
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_EXP_HEAL_SUCCESS, getExp, getCash);
		PrintToConsole(Client, "[提示] 你治疗了 %s 获得 %d 金钱！", name, getCash);
	}
	/*
	if(GetClientTeam(HealSucTarget) == TEAM_SURVIVORS && !IsFakeClient(HealSucTarget) && Lv[HealSucTarget] > 0)
	{
		SetEntProp(HealSucTarget, Prop_Data, "m_iMaxHealth", RoundToNearest(100*(1+HealthEffect[HealSucTarget])));
		SetEntProp(HealSucTarget, Prop_Data, "m_iHealth", RoundToNearest(100*(1+HealthEffect[HealSucTarget])));
	}
	*/
	return Plugin_Continue;
}

public Action:Event_JockeyRideEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new JocEndTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (IsValidClient(JocEndTarget))
	{
		if(Agi[attacker] != Agi[JocEndTarget])
		{
			SetEntPropFloat(JocEndTarget, Prop_Data, "m_flLaggedMovementValue", 1.0 + AgiEffect[JocEndTarget]);
			SetEntityGravity(JocEndTarget, 1.0/(1.0 + AgiEffect[JocEndTarget]));
		}
	}
	return Plugin_Continue;
}
//使用技能选单
public Action:Menu_UseSkill(Client, args)
{
	MenuFunc_UseSkill(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_UseSkill(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "使用技能 MP: %d / %d", MP[Client], MaxMP[Client]);
	SetPanelTitle(menu, line);
	if(GetClientTeam(Client) == TEAM_SURVIVORS)
	{
		Format(line, sizeof(line), "[通用] 治疗自己 (Lv.%d / MP:%d)", HealingLv[Client], GetConVarInt(Cost_Healing));
		DrawPanelItem(menu, line);
		if(JD[Client] == 1)
		{
			Format(line, sizeof(line), "[工程师] 子弹制造 (Lv.%d / MP:%d)", AmmoMakingLv[Client], GetConVarInt(Cost_AmmoMaking));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[工程师] 卫星炮 (Lv.%d / MP:%d)", SatelliteCannonLv[Client], GetConVarInt(Cost_SatelliteCannon));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 3)
		{
			Format(line, sizeof(line), "[生物专家] 无敌 (Lv.%d / MP:%d)", BioShieldLv[Client], GetConVarInt(Cost_BioShield));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[生物专家] 反伤 (Lv.%d / MP:%d)", DamageReflectLv[Client], GetConVarInt(Cost_DamageReflect));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line),  "[生物专家] 近战嗜血 (Lv.%d / MP:%d)", MeleeSpeedLv[Client], GetConVarInt(Cost_MeleeSpeed));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 2)
		{
			Format(line, sizeof(line), "[士兵] 加速冲刺 (Lv.%d / MP:%d)", SprintLv[Client], GetConVarInt(Cost_Sprint));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[士兵] 无限子弹 (Lv.%d / MP:%d)", InfiniteAmmoLv[Client], GetConVarInt(Cost_InfiniteAmmo));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 4)
		{
			Format(line, sizeof(line), "[心灵医师] 选择传送 (Lv.%d / MP:%d)", TeleportToSelectLv[Client], GetConVarInt(Cost_TeleportToSelect));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[心灵医师] 目标传送 (Lv.%d / MP:%d)", AppointTeleportLv[Client], GetConVarInt(Cost_AppointTeleport));
			DrawPanelItem(menu, line);		
			if(GetConVarInt(TeleportTeam_Mode)==1)
			{
				Format(line, sizeof(line), "[心灵医师] 心灵传送 (Lv.%d / MP:%d)", TeleportTeamLv[Client], MaxMP[Client]);
				DrawPanelItem(menu, line);
			}
			else
			{
				Format(line, sizeof(line), "[心灵医师] 心灵传送 (Lv.%d / MP:%d)", TeleportTeamLv[Client], GetConVarInt(Cost_TeleportTeammate));
				DrawPanelItem(menu, line);
			}
			
			Format(line, sizeof(line), "[心灵医师] 治疗光球术 (Lv.%d / MP:%d)", HealingBallLv[Client], GetConVarInt(Cost_HealingBall));
			DrawPanelItem(menu, line);
			
			if(defibrillator[Client]>0)
			{
				Format(line, sizeof(line), "[心灵医师] 额外的电击器 (剩余:%d个)", defibrillator[Client]);
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 5)
		{
			Format(line, sizeof(line), "[魔法师] 火球 (Lv.%d / MP:%d)", FireBallLv[Client], GetConVarInt(Cost_FireBall));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[魔法师] 冰球 (Lv.%d / MP:%d)", IceBallLv[Client], GetConVarInt(Cost_IceBall));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[魔法师] 连锁闪电 (Lv.%d / MP:%d)", ChainLightningLv[Client], GetConVarInt(Cost_ChainLightning));
			DrawPanelItem(menu, line);
		}
	} else if(GetClientTeam(Client) == TEAM_INFECTED)
	{
		Format(line, sizeof(line), "[通用] 特级特感 (Lv.%d / MP:%d)", SuperInfectedLv[Client], GetConVarInt(Cost_SuperInfected));
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[通用] 召唤 (Lv.%d)", InfectedSummonLv[Client]);
		DrawPanelItem(menu, line);
	}
	DrawPanelItem(menu, "退出", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, DeSkiMenu, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}
public DeSkiMenu(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		if(GetClientTeam(Client) == TEAM_SURVIVORS) {
			switch(param)
			{
				case 1:
				{
					HealingFunction(Client);
					MenuFunc_UseSkill(Client);
				}
			} if(JD[Client]==1) { //工程
				switch(param)
				{
					case 2:
					{
						AmmoMakingFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 3:
					{
						SatelliteCannonFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			} if(JD[Client]==2) { //士兵
				switch(param)
				{
					case 2:
					{
						SprintFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 3:
					{
						InfiniteAmmoFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			} if(JD[Client]==3) { //生物
				switch(param)
				{
					case 2:
					{
						BioShieldFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 3:
					{
						DamageReflectFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 4:
					{
						MeleeSpeedFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			} if(JD[Client]==4) { //医师
				switch(param) {
					case 2:
					{
						TeleportToSelectMenu(Client);
						//MenuFunc_UseSkill(Client);
					}
					case 3:
					{
						AppointTeleport(Client);
						MenuFunc_UseSkill(Client);
					}
					case 4:
					{
						TeleportTeam(Client);
						//MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						HealingBallFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						if(defibrillator[Client]>0)
						{
							CheatCommand(Client, "give", "defibrillator");
							defibrillator[Client] -= 1;
						}
						else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "额外电击器已用完!");
						MenuFunc_UseSkill(Client);
					}
				}
			} if(JD[Client]==5) { //魔法师
				switch(param)
				{
					case 2:
					{
						FireBallFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 3:
					{
						IceBallFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 4:
					{
						ChainLightningFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			}
		} else if(GetClientTeam(Client) == TEAM_INFECTED) {
			switch(param) {
				case 1:
				{
					SuperInfectedFunction(Client);
					MenuFunc_UseSkill(Client);
				}
				case 2: InfectedSummonFunction(Client);
			}
		}
	}
}

/******************************************************
*	United RPG选单
*******************************************************/
public Action:Menu_RPG(Client,args)
{
	MenuFunc_RPG(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_RPG(Client)
{
	new Handle:menu = CreatePanel();

	decl String:job[32];	
	if(JD[Client] == 0)			Format(job, sizeof(job), "未转职");
	else if(JD[Client] == 1)	Format(job, sizeof(job), "工程师");
	else if(JD[Client] == 2)	Format(job, sizeof(job), "士兵");
	else if(JD[Client] == 3)	Format(job, sizeof(job), "生物专家");
	else if(JD[Client] == 4)	Format(job, sizeof(job), "心灵医师");
	else if(JD[Client] == 5)	Format(job, sizeof(job), "魔法师");

	decl String:LIZSA[32];
	if(Lis[Client] == 0)			Format(LIZSA, sizeof(LIZSA), "人类");   
	else if(Lis[Client] == 1)	Format(LIZSA, sizeof(LIZSA), "英雄");   
	else if(Lis[Client] == 2)	Format(LIZSA, sizeof(LIZSA), "特感");
	
	decl String:line[256];
	Format(line, sizeof(line),
	"RPG选单 等级:Lv.%d 金钱:$%d 职业:%s \n经验值:%d/%d MP:%d/%d 大过:%d次 转生:%d次\n属性: 力量:%d 敏捷:%d 生命:%d 耐力:%d 智力:%d \n═══════♡力量属性:%s ♡═══════",
		Lv[Client], Cash[Client], job,
		EXP[Client], GetConVarInt(LvUpExpRate)*(Lv[Client]+1), MP[Client], MaxMP[Client], KTCount[Client], NewLifeCount[Client],
		Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client], LIZSA);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "使用技能 (MP: %d/%d)", MP[Client], MaxMP[Client]);
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "分配面板");
	DrawPanelItem(menu, "商店");
	DrawPanelItem(menu, "排名");
	DrawPanelItem(menu, "插件讯息");
	DrawPanelItem(menu, "战术背包");
	DrawPanelItem(menu, "强化枪械");
	DrawPanelItem(menu, "领取补给");
	DrawPanelItem(menu, "退出", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, RPG_MenuHandler, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}

public RPG_MenuHandler(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_UseSkill(Client);		//使用技能
			case 2: MenuFunc_Xsbz(Client);			//分配面板
			case 3: MenuFunc_Buy(Client);			//赌场|商店
			case 4: MenuFunc_Rank(Client);			//伺服器排名
			case 5: MenuFunc_Info(Client);			//插件讯息
			case 6: MenuFunc_Beibaoxi(Client, true);		//特感战术背包
			case 7: MenuFunc_Qianghua(Client);		//强化枪械
			case 8: MenuFunc_Bugei(Client, 1);		//基础补给
		}
	}
}

//强化枪械
public MenuFunc_Qianghua(Client)
{   
	if(Shilv[Client] == 0){
		Qgl[Client] = 100;
	}
	/*防止玩家数据错误*/
	if(Qgl[Client] == 0 && Shilv[Client] > 0){
		Qgl[Client] = 100 - Shilv[Client] * 10;
	}
	if(Qgl[Client] < 0){
		Qgl[Client] = 0;
	}

	new Handle:menu = CreatePanel();
	decl String:line[1024];	   
	Format(line, sizeof(line),
	"═══【强化枪械】现拥有强化石:%d个═══ \n强化等级:LV.%d \n枪械攻击力:+%d \n成功升级率:%d%", Shitou[Client], Shilv[Client], Qstr[Client], Qgl[Client]);   
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明: 强化可以让自身枪械对 CI 和 Witch 攻击力提高!");    
	DrawPanelText(menu, line);	
   
	Format(line, sizeof(line), "开始强化");    
	DrawPanelItem(menu, line);   
	
	Format(line,sizeof(line), "提高成功率");
	DrawPanelItem(menu,line);
	
	DrawPanelItem(menu, "放弃强化", ITEMDRAW_DISABLED);
    
	SendPanelToClient(menu, Client, MenuHandler_Qianghua, MENU_TIME_FOREVER);  
	return;
}
public MenuHandler_Qianghua(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: KAIQIANG(Client);
			case 2: MenuFunc_UPQGL(Client);
		}
	}
}

//提升强化枪械的成功率MenuHandler_Upcql
public MenuHandler_Upcgl(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: BuyUpCgl(Client);
		}
	}

}
public BuyUpCgl(Client)
{
	if (Qgl[Client] >= 100)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client,"{green}【提示】你的强化成功率不用升级!");
	}else{
		if(Cash[Client] >= 300){
			Cash[Client] -= 300;
			Qgl[Client] += 10;
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client,"{green}【强化】恭喜你成功提升了强化成功率,目前强化成功率为%d%",Qgl[Client]);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜%N成功提升强化成功率!",Client);
			PrintToConsole(Client, "[提示] 成功率增加成功！");
		}else{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client,"{green}【提示】提升失败,你的金钱不足!");
			PrintToConsole(Client, "[提示] 成功率增加失败。");
		}
	}
	MenuFunc_UPQGL(Client);
}
public Action:MenuFunc_UPQGL(Client)
{
	if(Shilv[Client] == 0){
		Qgl[Client] = 100;
	}
	if(Qgl[Client] < 0){
		Qgl[Client] = 0;
	}
	new Handle:menu = CreatePanel();
	decl String:line[256];	   
	Format(line, sizeof(line), "═══【提升强化成功率】现强化成功率:%d%%═══ \n提升价格:3000金钱 \n每次提升10%%的成功率",Qgl[Client]);
	SetPanelTitle(menu, line);
	
	Format(line, sizeof(line), "开始提升");    
	DrawPanelItem(menu, line);  
	
	DrawPanelItem(menu, "放弃提升", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_Upcgl, MENU_TIME_FOREVER);
}
public KAIQIANG(Client)
{   

	if(Shitou[Client] > 0 && Shilv[Client] < MAXSHITOULV)   
	{
		if(Qgl[Client] == 100)   	    //升级率100
		{	            
			Shitou[Client]--;            
			Qstr[Client] += DMG_LVD;            
			Shilv[Client] ++;		
			Qgl[Client] -= 10;
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");      
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);
			PrintToConsole(Client, "[提示] 成功！");
		}		
		else if(Qgl[Client] == 90)   	    
		{			    
			new cgl = GetRandomInt(1, 100);
			if(cgl > 10)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);
			}
		}
		else if(Qgl[Client] == 80)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 20)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);
				PrintToConsole(Client, "[提示] 成功！");				
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}
		}
		else if(Qgl[Client] == 70)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 30)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);				
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 60)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 40)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);				
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 50)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 50)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);				
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 40)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 60)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);	
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 30)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 70)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 20)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 80)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);			
			}		
		}
		else if(Qgl[Client] == 10)
		{
			new cgl = GetRandomInt(1,100);
			if(cgl > 90)
			{
				Shitou[Client]--;
				Qstr[Client] += DMG_LVD;
				Shilv[Client]++;
				Qgl[Client] -= 10;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}【强化】你成功强化枪械!");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}【强化】恭喜 %N 成功强化枪械!",Client);				
				PrintToConsole(Client, "[提示] 成功！");
			}else{
				Shitou[Client]--;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChatAll("{green}【强化】%N 强化枪械失败!",Client);
				}
			}		
		}
		else if(Qgl[Client] <= 0)   	    		
		{			    
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "【提示】你的升级率目前0无法强化!"); 			        
		}
	} 
	else 
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChat(Client, "【提示】你没有强化石无法进行强化或者强化已经达到上限!");
		}
	} 
	MenuFunc_Qianghua(Client); 
	return;
}

/* 分配面板*/
public Action:MenuFunc_Xsbz(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();

	Format(line, sizeof(line), "分配面板");			
	SetPanelTitle(menu, line);
    
	Format(line, sizeof(line), "分配属性");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "学习技能");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "转职|洗点|转生");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "关闭菜单");
	DrawPanelItem(menu, line);
	SendPanelToClient(menu, Client, MenuHandler_Xsbz, MENU_TIME_FOREVER);
}

public MenuHandler_Xsbz(Handle:menu, MenuAction:action, Client, param)//基础菜单	
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_AddStatus(Client);
			case 2: MenuFunc_AddSkill(Client);
			case 3: MenuFunc_Job(Client);
		}
	}
}

/* 开局补给装备 */
public Action:MenuFunc_Bugei(Client, args)
{
	/*
	new Handle:menu = CreatePanel();
	
	decl String:line[1024];
	Format(line, sizeof(line), "【领取基础装备】");
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "领取1号补给[M16+棒球棍]");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "领取2号补给[激光AK47+武士刀]");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "放弃", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Bugei, MENU_TIME_FOREVER);
	return Plugin_Handled;
	*/
	
	if(!HasGetBuJi[Client])
	{
		PrintToChat(Client, "你已经领了补给");
		return;
	}
	
	new Handle:menu = CreateMenu(MenuHandler_Bugji);
	SetMenuTitle(menu, "领取补给");
	new String:line[255];
	Format(line, 255, "领取1号补给 [M16 + 警棍] (%s)", Lv[Client] < 30 ? "可领取" : "已领完");
	AddMenuItem(menu, "1", line);
	Format(line, 255, "领取2号补给 [AK47 + 盾牌] (%s)", Lv[Client] < 20 ? "可领取" : "已领完");
	AddMenuItem(menu, "2", line);
	Format(line, 255, "领取3号补给 [消音冲锋枪 + 止痛药] (%s)", Lv[Client] < 40 ? "可领取" : "已领完");
	AddMenuItem(menu, "3", line);
	Format(line, 255, "领取4号补给 [连喷 + 肾上腺素] (%s)", Lv[Client] > 5 && Lv[Client] < 40 ? "可领取" : "已领完");
	AddMenuItem(menu, "4", line);
	Format(line, 255, "领取5号补给 [单喷 + 燃烧瓶] (%s)", Lv[Client] > 1 && Lv[Client] < 40 ? "可领取" : "已领完");
	AddMenuItem(menu, "5", line);
	Format(line, 255, "领取6号补给 [M60 + 电锯] (%s)", Lv[Client] > 15 && Lv[Client] < 50 ? "可领取" : "已领完");
	AddMenuItem(menu, "6", line);
	if(args > 0) SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_Bugji(Handle:menu, MenuAction:action, client, param)
{
	if (action == MenuAction_End)	
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param == MenuCancel_ExitBack)
		{
			MenuFunc_RPG(client);
		}
	}
	
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 0: GetBuji(client, 1);
			case 1: GetBuji(client, 2);
			case 2: GetBuji(client, 3);
			case 3: GetBuji(client, 4);
			case 4: GetBuji(client, 5);
			case 5: GetBuji(client, 6);
		}
	}
	
}

public GetBuji(Client, index)
{
	switch(index)
	{
		case 1:
		{
			if(Lv[Client] > 0 && Lv[Client] < 30)
			{
				CheatCommand(Client, "give", "rifle");
				CheatCommand(Client, "give", "tonfa");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[M16 + 警棍]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[M16 + 警棍]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
		case 2:
		{
			if(Lv[Client] > 0 && Lv[Client] < 20)
			{
				CheatCommand(Client, "give", "rifle_ak47");
				CheatCommand(Client, "give", "riotshield");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[AK47 + 盾牌]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[AK47 + 盾牌]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
		case 3:
		{
			if(Lv[Client] > 10 && Lv[Client] < 40)
			{
				CheatCommand(Client, "give", "smg_silenced");
				CheatCommand(Client, "give", "pain_pills");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[消音冲锋枪 + 止痛药]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[消音冲锋枪 + 止痛药]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
		case 4:
		{
			if(Lv[Client] > 5 && Lv[Client] < 40)
			{
				CheatCommand(Client, "give", "autoshotgun");
				CheatCommand(Client, "give", "adrenaline");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[连喷 + 肾上腺素]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[连喷 + 肾上腺素]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
		case 5:
		{
			if(Lv[Client] > 1 && Lv[Client] < 40)
			{
				CheatCommand(Client, "give", "autoshotgun");
				CheatCommand(Client, "give", "adrenaline");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[单喷 + 燃烧瓶]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[单喷 + 燃烧瓶]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
		case 6:
		{
			if(Lv[Client] > 15 && Lv[Client] < 50)
			{
				CheatCommand(Client, "give", "rifle_m60");
				CheatCommand(Client, "give", "weapon_chainsaw");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备[M60 + 电锯]", Client);
				//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
				PrintToChat(Client, "\x03[提示]\x01 你领取了补给：\x04[M60 + 电锯]");
				HasGetBuJi[Client] = false;
			}
			else
			{
				PrintToChat(Client, "\x03[提示]\x01 领取补给失败...");
			}
		}
	}
}

/*
public LQIHUANB(Client)
{
	if(Lv[Client] <= 30)
	{
		CheatCommand(Client, "give", "rifle");
		if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备:M16+棒球棍", Client);
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
	}
}	
public LQIHUANA(Client)	
{   if(Lv[Client] <= 20)
	{
		CheatCommand(Client, "give", "rifle_ak47");
		CheatCommand(Client, "give", "katana");
		CheatCommand(Client, "upgrade_add", "laser_sight");
		if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【系统】玩家%N领取了开局补给基础装备:激光AK47+武士刀", Client);
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你领取了开局补给装备!");
	}
}
*/

/* 属性点菜单 */
public Action:MenuFunc_AddStatus(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "属性点剩余: %d", StatusPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "力量 (%d/%d 数量)", Str[Client], Limit_Str);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高伤害! 增加%.2f%%伤害", StrEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "敏捷 (%d/%d 数量)", Agi[Client], Limit_Agi);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高移动速度! 增加%.2f%%移动速度", AgiEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "生命 (%d/%d 数量)", Health[Client], Limit_Health);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高生命最大值! 增加%.2f%%生命最大值", HealthEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "耐力 (%d/%d 数量)", Endurance[Client], Limit_Endurance);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "减少伤害!  减少%.2f%%伤害", EnduranceEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "智力 (%d/%d 数量)", Intelligence[Client], Limit_Intelligence);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高MP上限, 恢复速度及减少扣经! 每秒MP恢复: %d, MP上限: %d", IntelligenceEffect_IMP[Client], MaxMP[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_AddStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(StatusPoint[Client] <= 0)	
		{
			if(GetConVarInt(g_hCvarShow))
			{
				CPrintToChat(Client, MSG_LACK_POINTS);
			}
		}
		else
		{
			switch(param)
			{
				case 1:	AddStrength(Client, 0);
				case 2:	AddAgile(Client, 0);
				case 3:	AddHealth(Client, 0);
				case 4:	AddEndurance(Client, 0);
				case 5:	AddIntelligence(Client, 0);
				case 6: 	MenuFunc_RPG(Client);
			}
		}
		MenuFunc_AddStatus(Client);
	}
}

//物品背包
public Action:Menu_Beibaoxi(Client,args)
{
	MenuFunc_Beibaoxi(Client, false);
	return Plugin_Handled;
}
public Action:MenuFunc_Beibaoxi(Client, bool:isBack)
{   
	new Handle:menu = CreatePanel();
	   
	decl String:line[1024];   
	Format(line, sizeof(line), "═══物品背包═══");   
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "腺上激素: %d 支", Baoshu[Client]);  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "医疗包: %d 个", Baoliao[Client]);  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "电击器: %d 个", Baodian[Client]);  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "棒球棍: %d 个", Baozhan[Client]);  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "弹药夹: %d 组", Baojia[Client]);  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "AK47步枪: %d 支", Baoxie[Client]);    
	DrawPanelItem(menu, line);
	if(isBack) DrawPanelItem(menu, "返回主菜单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
    
	SendPanelToClient(menu, Client, MenuHandler_Beibaoxi, MENU_TIME_FOREVER);   
	return Plugin_Handled;
}
public MenuHandler_Beibaoxi(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select) 
    {
        switch (param)
        {
	        case 1:AANPC(Client);
            case 2:BBNPC(Client);
			case 3:DANPC(Client);
			case 4:CCNPC(Client);
			case 5:DDNPC(Client);
			case 6:EENPC(Client);
			case 7:MenuFunc_RPG(Client);			
        }
    }
}
public DANPC(Client)
{   
	if(IsPlayerAlive(Client))	
	{    
		if(Baodian[Client] > 0)       
		{        
			Baodian[Client]--;         
			CheatCommand(Client, "give", "defibrillator");         
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了电击器!");
			PrintToConsole(Client, "[提示] 你获得了一个电击器！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有电击器!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}
public AANPC(Client)
{   
	if(IsPlayerAlive(Client))	
	{    
		if(Baoshu[Client] > 0)       
		{        
			Baoshu[Client]--;         
			CheatCommand(Client, "give", "adrenaline");          
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了肾上腺素!");
			PrintToConsole(Client, "[提示] 你获得了一根针！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有肾上腺素!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}	
public BBNPC(Client)
{    
	if(IsPlayerAlive(Client))	
	{	    
		if(Baoliao[Client] > 0)        
		{	        
			Baoliao[Client]--;           
			CheatCommand(Client, "give", "first_aid_kit");            
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了医疗包!");
			PrintToConsole(Client, "[提示] 你获得了 一个医疗包！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有医疗包!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}
public CCNPC(Client)
{    
	if(IsPlayerAlive(Client))	
	{	    
		if(Baozhan[Client] > 0)       
		{	        
			Baozhan[Client]--;          
			CheatCommand(Client, "give", "baseball_bat");            
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了棒球棍!");
			PrintToConsole(Client, "[提示] 你获得了一个棒球棒！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有棒球棍!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}
public DDNPC(Client)
{   
	if(IsPlayerAlive(Client))	
	{	    
		if(Baojia[Client] > 0)      
		{	        
			Baojia[Client]--;         
			CheatCommand(Client, "give", "ammo");            
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了弹药夹!");
			PrintToConsole(Client, "[提示] 你获得了补充弹药！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有弹药夹!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}
public EENPC(Client)
{    
	if(IsPlayerAlive(Client))	
	{	    
		if(Baoxie[Client] > 0)       
		{	        
			Baoxie[Client]--;           
			CheatCommand(Client, "give", "rifle_ak47");           
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你拿出了AK47步枪!");
			PrintToConsole(Client, "[提示] 你获得了一把 AK47 步枪！");
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 你的背包没有AK47步枪!");	
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}[提示] 死亡状态下无法使用!");
	MenuFunc_Beibaoxi(Client, false);
}

/* 学习技能 */
public Action:MenuFunc_AddSkill(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "技能点数: %d", SkillPoint[Client]);
	SetPanelTitle(menu, line);

	DrawPanelItem(menu, "幸存者技能");
	DrawPanelItem(menu, "感染者技能");
	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "退出", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_AddSkill, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSkill(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 1: MenuFunc_SurvivorSkill(Client);
			case 2: MenuFunc_InfectedSkill(Client);
			case 3: MenuFunc_RPG(Client);
		}
	}
}
//幸存者技能
public Action:MenuFunc_SurvivorSkill(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "幸存者技能 - 技能点剩余: %d", SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "[通用] 治疗 (目前等级: %d/%d 发动指令: !heal)", HealingLv[Client], LvLimit_Healing);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[通用] 强化甦醒 (目前等级: %d/%d 被动技能)", EndranceQualityLv[Client], LvLimit_EndranceQuality);
	DrawPanelItem(menu, line);
	if(JD[Client] == 1)
	{
		Format(line, sizeof(line), "[工程师] 子弹制造 (目前等级: %d/%d 发动指令: !getammo)", AmmoMakingLv[Client], LvLimit_AmmoMaking);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[工程师] 射速加强 (目前等级: %d/%d 发动指令: !fastshot)", FireSpeedLv[Client], LvLimit_FireSpeed);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[工程师] 卫星炮 (目前等级: %d/%d 发动指令: !sc)", SatelliteCannonLv[Client], LvLimit_SatelliteCannon);
		DrawPanelItem(menu, line);
	} else if(JD[Client] == 2)
	{
		Format(line, sizeof(line), "[士兵] 攻防强化 (目前等级: %d/%d 被动技能)", EnergyEnhanceLv[Client], LvLimit_EnergyEnhance);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[士兵] 加速冲刺 (目前等级: %d/%d 发动指令: !rush)", SprintLv[Client], LvLimit_Sprint);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[士兵] 无限子弹 (目前等级: %d/%d 发动指令: !iammo)", InfiniteAmmoLv[Client], LvLimit_InfiniteAmmo);
		DrawPanelItem(menu, line);
	} else if(JD[Client] == 3)
	{
		Format(line, sizeof(line), "[生物专家] 无敌 (目前等级: %d/%d 发动指令: !god)", BioShieldLv[Client], LvLimit_BioShield);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[生物专家] 反伤 (目前等级: %d/%d 发动指令: !bdmg)", DamageReflectLv[Client], LvLimit_DamageReflect);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[生物专家] 近战嗜血 (目前等级: %d/%d 发动指令: !ms)", MeleeSpeedLv[Client], LvLimit_MeleeSpeed);
		DrawPanelItem(menu, line);
	} else if(JD[Client] == 4)
	{
		Format(line, sizeof(line), "[心灵医师] 选择传送 (目前等级: %d/%d 发动指令: !ts)", TeleportToSelectLv[Client], LvLimit_TeleportToSelect);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师] 目标传送 (目前等级: %d/%d 发动指令: !at)", AppointTeleportLv[Client], LvLimit_AppointTeleport);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师] 心灵传送 (目前等级: %d/%d 发动指令: !tt)", TeleportTeamLv[Client], LvLimit_TeleportTeam);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师] 治疗光球 (需转生 目前等级: %d/%d 发动指令: !hb)", HealingBallLv[Client], LvLimit_HealingBall);
		DrawPanelItem(menu, line);
	} else if(JD[Client] == 5)
	{
		Format(line, sizeof(line), "[魔法师] 火球 (目前等级: %d/%d 发动指令: !fire)", FireBallLv[Client], LvLimit_FireBall);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[魔法师] 冰球 (目前等级: %d/%d 发动指令: !ice)", IceBallLv[Client], LvLimit_IceBall);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[魔法师] 连锁闪电 (目前等级: %d/%d 发动指令: !cl)", ChainLightningLv[Client], LvLimit_ChainLightning);
		DrawPanelItem(menu, line);
	}
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_SurvivorSkill, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}
public MenuHandler_SurvivorSkill(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1:	MenuFunc_AddHealing(Client);
			case 2:	MenuFunc_AddEndranceQuality(Client);
			case 3:
			{
				if(JD[Client] == 1)	MenuFunc_AddAmmoMaking(Client);
				else if(JD[Client] == 2)	MenuFunc_AddEnergyEnhance(Client);
				else if(JD[Client] == 3)	MenuFunc_AddBioShield(Client);
				else if(JD[Client] == 4)	MenuFunc_AddTeleportToSelect(Client);
				else if(JD[Client] == 5)	MenuFunc_AddFireBall(Client);
			}
			case 4:
			{
				if(JD[Client] == 1)	MenuFunc_AddFireSpeed(Client);
				else if(JD[Client] == 2)	MenuFunc_AddSprint(Client);
				else if(JD[Client] == 3)	MenuFunc_AddDamageReflect(Client);
				else if(JD[Client] == 4)	MenuFunc_AddAppointTeleport(Client);
				else if(JD[Client] == 5)	MenuFunc_AddIceBall(Client);
			}
			case 5:
			{
				if(JD[Client] == 1)	MenuFunc_AddSatelliteCannon(Client);
				else if(JD[Client] == 2)	MenuFunc_AddInfiniteAmmo(Client);
				else if(JD[Client] == 3)	MenuFunc_AddMeleeSpeed(Client);
				else if(JD[Client] == 4)	MenuFunc_AddTeleportTeam(Client);
				else if(JD[Client] == 5)	MenuFunc_AddChainLightning(Client);
			}
			case 6:
			{
				if(JD[Client] == 4)	MenuFunc_AddHealingBall(Client);
			}
		}
	}
}
public Action:MenuFunc_AddHealing(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习治疗术 目前等级: %d/%d 发动指令: !hl - 技能点剩余: %d", HealingLv[Client], LvLimit_Healing, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 每秒恢复%dHP", HealingEffect);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %d秒", HealingDuration[Client]);
	DrawPanelText(menu, line);
	
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHealing, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHealing(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(HealingLv[Client] < LvLimit_Healing)
			{
				HealingLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_HL, HealingLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_HL_LEVEL_MAX);
				}
			}
			MenuFunc_AddHealing(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddEndranceQuality(Client)
{
	decl String:line[128];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习强化甦醒术 目前等级: %d/%d 被动技能 - 技能点剩余: %d", EndranceQualityLv[Client], LvLimit_EndranceQuality, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 倒地后再起身的血量");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "生命比率: %.2f%%", EndranceQualityEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddEndranceQuality, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddEndranceQuality(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			if(EndranceQualityLv[Client] < LvLimit_EndranceQuality)
			{
				EndranceQualityLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_EQ, EndranceQualityLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_EQ_LEVEL_MAX);
				}
			}
			MenuFunc_AddEndranceQuality(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddAmmoMaking(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习子弹制造术 目前等级: %d/%d 发动指令: !am - 技能点剩余: %d", AmmoMakingLv[Client], LvLimit_AmmoMaking, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 制造一定数量子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "制造数量: %d", AmmoMakingEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAmmoMaking, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAmmoMaking(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(AmmoMakingLv[Client] < LvLimit_AmmoMaking)
			{
				AmmoMakingLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_AM, AmmoMakingLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_AM_LEVEL_MAX);
				}
			}
			MenuFunc_AddAmmoMaking(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddFireSpeed(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习射速加强术 目前等级: %d/%d 发动指令: !fs - 技能点剩余: %d", FireSpeedLv[Client], LvLimit_FireSpeed, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加子弹的射击速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "速度比率: %.2f%%", FireSpeedEffect[Client]*100);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddFireSpeed, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddFireSpeed(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(FireSpeedLv[Client] < LvLimit_FireSpeed)
			{
				FireSpeedLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_FS, FireSpeedLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_FS_LEVEL_MAX);
				}
			}
			MenuFunc_AddFireSpeed(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddSatelliteCannon(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习卫星炮术 目前等级: %d/%d 发动指令: !sc - 技能点剩余: %d", SatelliteCannonLv[Client], LvLimit_SatelliteCannon, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向準心位置发射卫星炮");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", SatelliteCannonDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %d", SatelliteCannonRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", SatelliteCannonCDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSatelliteCannon, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSatelliteCannon(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(SatelliteCannonLv[Client] < LvLimit_SatelliteCannon)
			{
				SatelliteCannonLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_SC, SatelliteCannonLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_SC_LEVEL_MAX);
				}
			}
			MenuFunc_AddSatelliteCannon(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddEnergyEnhance(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习攻防强化术 目前等级: %d/%d 被动 - 技能点剩余: %d", EnergyEnhanceLv[Client], LvLimit_EnergyEnhance, SkillPoint[Client]);
	SetPanelTitle(menu, line);
	
	Format(line, sizeof(line), "技能说明: 永久增加自身攻击力, 防卫力, 防御上限");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加伤害: %.2f%%", EnergyEnhanceEffect_Attack[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加防卫: %.2f%%", EnergyEnhanceEffect_Endurance[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "防御上限: %.2f%%", EnergyEnhanceEffect_MaxEndurance[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddEnergyEnhance, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddEnergyEnhance(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(EnergyEnhanceLv[Client] < LvLimit_EnergyEnhance)
			{
				EnergyEnhanceLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_EE, EnergyEnhanceLv[Client]);
				}
				CreateTimer(0.1, StatusUp, Client);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_EE_LEVEL_MAX);
				}
			}
			MenuFunc_AddEnergyEnhance(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddSprint(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习加速冲刺术 目前等级: %d/%d 发动指令: !sp - 技能点剩余: %d", SprintLv[Client], LvLimit_Sprint, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "提升移动速度. 持续:%.2f秒", SprintDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "技能说明: 一定时间内提升移动速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加比率: %.2f%%", SprintEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", SprintDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSprint, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSprint(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(SprintLv[Client] < LvLimit_Sprint)
			{
				SprintLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_SP, SprintLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_SP_LEVEL_MAX);
				}
			}
			MenuFunc_AddSprint(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddInfiniteAmmo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习无限子弹术 目前等级: %d/%d 发动指令: !ia - 技能点剩余: %d", InfiniteAmmoLv[Client], LvLimit_InfiniteAmmo, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 一定时间内无限子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", InfiniteAmmoDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddInfiniteAmmo, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddInfiniteAmmo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(InfiniteAmmoLv[Client] < LvLimit_InfiniteAmmo)
			{
				InfiniteAmmoLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_IA, InfiniteAmmoLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_IA_LEVEL_MAX);
				}
			}
			MenuFunc_AddInfiniteAmmo(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddBioShield(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习无敌术 目前等级: %d/%d 发动指令: !bs - 技能点剩余: %d", BioShieldLv[Client], LvLimit_BioShield, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 损耗自身生命去变成无敌, 使用后会清除自身技能效果, 且不能使用其他技能");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: %d%%", BioShieldSideEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", BioShieldDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", BioShieldCDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBioShield, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBioShield(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_LACK_SKILLS);
				}
			}
			else if(BioShieldLv[Client] < LvLimit_BioShield)
			{
				BioShieldLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_BS, BioShieldLv[Client]);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))
				{
					CPrintToChat(Client, MSG_ADD_SKILL_BS_LEVEL_MAX);
				}
			}
			MenuFunc_AddBioShield(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddDamageReflect(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习反伤术 目前等级: %d/%d 发动指令: !dr - 技能点剩余: %d", DamageReflectLv[Client], LvLimit_DamageReflect, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 损耗自身生命在一定时间内去反射一定比率伤害");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: %.2f%%", DamageReflectSideEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", DamageReflectDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "反射比率: %.2f%%", DamageReflectEffect[Client]*100);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddDamageReflect, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddDamageReflect(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(DamageReflectLv[Client] < LvLimit_DamageReflect)
			{
				DamageReflectLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_DR, DamageReflectLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_DR_LEVEL_MAX);
			}
			MenuFunc_AddDamageReflect(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddMeleeSpeed(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习近战嗜血术 目前等级: %d/%d 发动指令: !ms - 技能点剩余: %d", MeleeSpeedLv[Client], LvLimit_MeleeSpeed, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 牺牲所有防御力去提升近战攻速");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", MeleeSpeedDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "提速比率: %.2f%%", 1.0/MeleeSpeedEffect[Client]*100);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddMeleeSpeed, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddMeleeSpeed(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(MeleeSpeedLv[Client] < LvLimit_MeleeSpeed)
			{
				MeleeSpeedLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_MS, MeleeSpeedLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_MS_LEVEL_MAX);
			}
			MenuFunc_AddMeleeSpeed(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddTeleportToSelect(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习选择传送术 目前等级: %d/%d 发动指令: !ts - 技能点剩余: %d", TeleportToSelectLv[Client], LvLimit_TeleportToSelect, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 传送到指定队友身边");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %d秒", 230 - (TeleportToSelectLv[Client]+AppointTeleportLv[Client])*5);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddTeleportToSelect, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddTeleportToSelect(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(TeleportToSelectLv[Client] < LvLimit_TeleportToSelect)
			{
				TeleportToSelectLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_TS, TeleportToSelectLv[Client]);
				if(TeleportToSelectLv[Client]==0) IsTeleportToSelectEnable[Client] = false;
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_TS_LEVEL_MAX);
			}
			MenuFunc_AddTeleportToSelect(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddAppointTeleport(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习目标传送术 目前等级: %d/%d 发动指令: !at - 技能点剩余: %d", AppointTeleportLv[Client], LvLimit_AppointTeleport, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 传送到準心位置");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAppointTeleport, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAppointTeleport(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(AppointTeleportLv[Client] < LvLimit_AppointTeleport)
			{
				AppointTeleportLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_AT, AppointTeleportLv[Client]);
				if(AppointTeleportLv[Client]==0) IsAppointTeleportEnable[Client] = false;
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_AT_LEVEL_MAX);
			}
			MenuFunc_AddAppointTeleport(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddTeleportTeam(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习心灵传送术 目前等级: %d/%d 发动指令: !tt - 技能点剩余: %d", TeleportTeamLv[Client], LvLimit_TeleportTeam, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	if(GetConVarInt(TeleportTeam_Mode)==1)
	{
		Format(line, sizeof(line), "技能说明: 传送所有队友到自己身边.");
		DrawPanelText(menu, line);
	} else
	{
		Format(line, sizeof(line), "技能说明: 传送指定队友到自己身边");
		DrawPanelText(menu, line);
		Format(line, sizeof(line), "冷却时间: %d秒", 160 - TeleportTeamLv[Client]*5);
		DrawPanelText(menu, line);
	}
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddTeleportTeam, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddTeleportTeam(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(TeleportToSelectLv[Client] == LvLimit_TeleportToSelect && AppointTeleportLv[Client] == LvLimit_AppointTeleport)
			{
				if(TeleportTeamLv[Client] < LvLimit_TeleportTeam)
				{
					TeleportTeamLv[Client]++, SkillPoint[Client] -= 1;
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_TT, TeleportTeamLv[Client]);
					if(TeleportTeamLv[Client]==0) IsTeleportTeamEnable[Client] = false;
				}
				else 
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_TT_LEVEL_MAX);
				}
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_TT_NEED);
			}
			MenuFunc_AddTeleportTeam(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddHealingBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习治疗光球术 需转生 目前等级: %d/%d 发动指令: !hb - 技能点剩余: %d", HealingBallLv[Client], LvLimit_HealingBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在準心制造一个光球治疗附近队友");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "每秒回复: %dHP", HealingBallEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", HealingBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "治疗范围: %d", HealingBallRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHealingBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHealingBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(NewLifeCount[Client] >= 1)
			{
				if(SkillPoint[Client] <= 0)	
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
				}
				else if(HealingBallLv[Client] < LvLimit_HealingBall)
				{
					HealingBallLv[Client]++, SkillPoint[Client] -= 1;
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_HB, HealingBallLv[Client]);
				}
				else 
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_HB_LEVEL_MAX);
				}
			} else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_NeedNewLife);
			}
			MenuFunc_AddHealingBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddFireBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习火球术 目前等级: %d/%d 发动指令: !fb - 技能点剩余: %d", FireBallLv[Client], LvLimit_FireBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向準心放出火球, 燃烧范围内敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧持续: %.f秒", FireBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", FireBallDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", FireBallRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddFireBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddFireBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(FireBallLv[Client] < LvLimit_FireBall)
			{
				FireBallLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_FB, FireBallLv[Client], FireBallDamage[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_FB_LEVEL_MAX);
			}
			MenuFunc_AddFireBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddIceBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习冰球术 目前等级: %d/%d 发动指令: !ib - 技能点剩余: %d", IceBallLv[Client], LvLimit_IceBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向準心放出冰球, 冻结范围内敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻持续: %.2f秒", IceBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻伤害: %d", IceBallDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻范围: %d", IceBallRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddIceBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddIceBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(IceBallLv[Client] < LvLimit_IceBall)
			{
				IceBallLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_IB, IceBallLv[Client], IceBallDamage[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_IB_LEVEL_MAX);
			}
			MenuFunc_AddIceBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
public Action:MenuFunc_AddChainLightning(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习连锁闪电术 目前等级: %d/%d 发动指令: !cl - 技能点剩余: %d", ChainLightningLv[Client], LvLimit_ChainLightning, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在周围放出闪电连锁攻击附近敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "闪电伤害: %d", ChainLightningDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "发动范围: %d", ChainLightningLaunchRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "连锁范围: %d", ChainLightningRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddChainLightning, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddChainLightning(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(ChainLightningLv[Client] < LvLimit_ChainLightning)
			{
				ChainLightningLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_CL, ChainLightningLv[Client], ChainLightningDamage[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_CL_LEVEL_MAX);
			}
			MenuFunc_AddChainLightning(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
//感染者技能
public Action:MenuFunc_InfectedSkill(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "特殊感染者技能 - 技能点剩余: %d", SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "[通用]再生术 (目前等级: %d/%d 被动技能)", HPRegenerationLv[Client], LvLimit_HPRegeneration);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[通用]超级特感术 (目前等级: %d/%d 发动指令: !si)", SuperInfectedLv[Client], LvLimit_SuperInfected);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[通用]召唤术 (目前等级: %d/%d 发动指令: !is)", InfectedSummonLv[Client], LvLimit_InfectedSummon);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[Hunter]飞扑爆击术 (目前等级: %d/%d 被动技能)", SuperPounceLv[Client], LvLimit_SuperPounce);
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_InfectedSkill, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_InfectedSkill(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param)
		{
			case 1:	MenuFunc_AddHPRegeneration(Client);
			case 2:	MenuFunc_AddSuperInfected(Client);
			case 3:	MenuFunc_AddInfectedSummon(Client);
			case 4:	MenuFunc_AddSuperPounce(Client);
		}
	}
}
public Action:MenuFunc_AddHPRegeneration(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习再生术 目前等级: %d/%d 被动技能 - 技能点剩余: %d", HPRegenerationLv[Client], LvLimit_HPRegeneration, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在不受攻击后準备特定秒数后回复特定比率生命");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "準备时间: %.2f秒", HPRegeneration_DamageStopTime);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "回复间隔: %.2f秒", HPRegeneration_Rate);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "回复比率: %.2f%%", HPRegeneration_HPRate[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHPRegeneration, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHPRegeneration(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(HPRegenerationLv[Client] < LvLimit_HPRegeneration)
			{
				HPRegenerationLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_RG, HPRegenerationLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_RG_LEVEL_MAX);
			}
			MenuFunc_AddHPRegeneration(Client);
		} else MenuFunc_InfectedSkill(Client);
	}
}
public Action:MenuFunc_AddSuperInfected(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习超级特感术 目前等级: %d/%d 指令: !si - 技能点剩余: %d", SuperInfectedLv[Client], LvLimit_SuperInfected, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 一定时间同提升特定比率的伤害, 生命上限, 移动速度, 防御");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加伤害: %.2f%%", SuperInfectedEffect_Attack[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加速度: %.2f倍", SuperInfectedEffect_Speed[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "额外防御: %.2f%%", SuperInfectedEffect_Endurance[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", SuperInfectedDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSuperInfected, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSuperInfected(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(SuperInfectedLv[Client] < LvLimit_SuperInfected)
			{
				SuperInfectedLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_SI, SuperInfectedLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_SI_LEVEL_MAX);
			}
			MenuFunc_AddSuperInfected(Client);
		} else MenuFunc_InfectedSkill(Client);
	}
}
public Action:MenuFunc_AddInfectedSummon(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习召唤术 目前等级: %d/%d 指令: !is - 技能点剩余: %d", InfectedSummonLv[Client], LvLimit_InfectedSummon, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 可召唤特殊的普感");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "召唤数量: %d", InfectedSummonMax[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddInfectedSummon, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddInfectedSummon(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(InfectedSummonLv[Client] < LvLimit_InfectedSummon)
			{
				InfectedSummonLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_IS, InfectedSummonLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_IS_LEVEL_MAX);
			}
			MenuFunc_AddInfectedSummon(Client);
		} else MenuFunc_InfectedSkill(Client);
	}
}
public Action:MenuFunc_AddSuperPounce(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "飞扑爆击术 目前等级: %d/%d 被动技能 - 技能点剩余: %d", SuperPounceLv[Client], LvLimit_SuperPounce, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: Hunter扑中幸存者时有爆击效果");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆击伤害: %d", SuperPounceDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆击范围: %d", SuperPounceRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSuperPounce, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSuperPounce(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_LACK_SKILLS);
			}
			else if(SuperPounceLv[Client] < LvLimit_SuperPounce)
			{
				SuperPounceLv[Client]++, SkillPoint[Client] -= 1;
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_HSP, SuperPounceLv[Client]);
			}
			else 
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ADD_SKILL_HSP_LEVEL_MAX);
			}
			MenuFunc_AddSuperPounce(Client);
		} else MenuFunc_InfectedSkill(Client);
	}
}
//职业选单
public Action:MenuFunc_Job(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Job);
	SetMenuTitle(menu, "转职|洗点|转生");
	AddMenuItem(menu, "option1", "洗点");
	AddMenuItem(menu, "option2", "转生");
	AddMenuItem(menu, "option3", "转职工程师");
	AddMenuItem(menu, "option4", "转职士兵");
	AddMenuItem(menu, "option5", "转职生物专家");
	AddMenuItem(menu, "option6", "转职心灵医师");
	AddMenuItem(menu, "option7", "转职魔法师 (需转生)");
	AddMenuItem(menu, "option8", "返回RPG选单");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Job(Handle:menu, MenuAction:action, Client, itemNum)
{
	if(action == MenuAction_Select) {
		switch(itemNum)
		{
			case 0: MenuFunc_ResetStatus(Client);
			case 1: MenuFunc_NewLife(Client);
			case 2: ChooseJob(Client, 1);//工程师
			case 3: ChooseJob(Client, 2);//士兵
			case 4: ChooseJob(Client, 3);//生物专家
			case 5: ChooseJob(Client, 4);//心灵医师
			case 6: ChooseJob(Client, 5);//魔法师
			case 7: MenuFunc_RPG(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
public Action:MenuFunc_ResetStatus(Client)
{
	new Handle:menu = CreatePanel();
	SetPanelTitle(menu,"洗点说明:\n按确认之后将会清零当前分配的属性, 所学技能技能及经验\n未转职玩家洗点降1级, 转职过的玩家降5级并变回未转职状态!\n你的真的需要洗点吗?\n════════════");

	DrawPanelItem(menu, "是");
	DrawPanelItem(menu, "否");

	SendPanelToClient(menu, Client, MenuHandler_ResetStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_ResetStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1:	ClinetResetStatus(Client, General);
			case 2: return;
		}
	}
}

ClinetResetStatus(Client, Mode)
{
	if(Mode == NewLife)
	{
		new NewExp = EXP[Client];
		for(new i=151; i<=Lv[Client]; i++)
			NewExp += GetConVarInt(LvUpExpRate)*i;
		NewExp = RoundToNearest(NewExp*0.1);
		new NewLv = 0;
		do
		{
			NewLv++;
			NewExp -= GetConVarInt(LvUpExpRate)*NewLv;
		} while (NewExp>0);
		Lottery[Client] += Lv[Client];
		Lv[Client] = NewLv - 1;
		EXP[Client] = NewExp + GetConVarInt(LvUpExpRate) * NewLv;
		NewLifeCount[Client] ++;
		// 向上取整
		StatusPoint[Client] = RoundToCeil(Lv[Client] / 2.5) * NewLifeCount[Client];
		SkillPoint[Client] = RoundToCeil(Lv[Client] / 10.0) * NewLifeCount[Client];
		Cash[Client] += Lv[Client] * GetConVarInt(LvUpCash) * NewLifeCount[Client];
		Lis[Client] ++;
	}
		
	if(JobChooseBool[Client])
	{
		JD[Client] = 0;
		JobChooseBool[Client] = false;
		if(Mode==General)	Lv[Client] -= 5;	
	}
	else	if(Mode==General)	Lv[Client] -= 1;

	StatusPoint[Client]				= 0;
	SkillPoint[Client]				= 0;
	if(Mode!=NewLife)	EXP[Client]	= 0;
	Str[Client]						= 0;
	Agi[Client]						= 0;
	Health[Client]					= 0;
	Endurance[Client]					= 0;
	Intelligence[Client]				= 0;
	HealingLv[Client]					= 0;
	EndranceQualityLv[Client]				= 0;
	AmmoMakingLv[Client]				= 0;
	SatelliteCannonLv[Client]		= 0;
	EnergyEnhanceLv[Client]			= 0;
	SprintLv[Client]					= 0;
	BioShieldLv[Client]				= 0;
	DamageReflectLv[Client]			= 0;
	MeleeSpeedLv[Client]				= 0;
	InfiniteAmmoLv[Client]			= 0;
	FireSpeedLv[Client]				= 0;
	SuperInfectedLv[Client]			= 0;
	InfectedSummonLv[Client]			= 0;
	SuperPounceLv[Client] 	= 0;
	HPRegenerationLv[Client]			= 0;
	TeleportToSelectLv[Client]		= 0;
	AppointTeleportLv[Client]		= 0;
	TeleportTeamLv[Client]			= 0;
	FireBallLv[Client]				= 0;
	IceBallLv[Client]					= 0;
	ChainLightningLv[Client]			= 0;

	RebuildStatus(Client, false);

	if(Mode != NewLife)
	{
		StatusPoint[Client]	=	Lv[Client]*GetConVarInt(LvUpSP);
		SkillPoint[Client]	=	Lv[Client]*GetConVarInt(LvUpKSP);
	}
	
	if(KTCount[Client] > 0)
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChat(Client, MSG_XD_KT_REMOVE);
		}
		KTCount[Client] -= 5;
		if(KTCount[Client]<0)	KTCount[Client] = 0;
	}

	if(Mode == Admin)
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChatAllEx(Client, MSG_XD_SUCCESS_ADMIN, Client);
		}
	}
	else if(Mode == Shop)
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChatAllEx(Client, MSG_XD_SUCCESS_SHOP, Client);
		}
	}
	else if(Mode == General)
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChatAllEx(Client, MSG_XD_SUCCESS, Client);
		}
	}
	else
	{
		if(GetConVarInt(g_hCvarShow))
		{
			CPrintToChatAll(MSG_NL_SUCCESS, Client);
		}
	}
}
public Action:MenuFunc_NewLife(Client)
{
	if(Lv[Client] < GetConVarInt(NewLifeLv))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_NL_NEED_LV, GetConVarInt(NewLifeLv));
		return Plugin_Handled;
	}
	else
		{
		new Handle:menu = CreatePanel();
		decl String:line[256];
		Format(line, sizeof(line), "转生说明:\n按确认之后将会清零当前分配的属性, 所学技能技能\n玩家会扣除相等於%d级的经验, 剩余的经验值将会除10并变回未转职状态!\n但是可以获得大量的初始技能点\n你的真的决定转生吗?\n════════════", GetConVarInt(NewLifeLv));
		SetPanelTitle(menu, line);

		DrawPanelItem(menu, "转生!");
		DrawPanelItem(menu, "我再考虑下!");

		SendPanelToClient(menu, Client, MenuHandler_NewLife, MENU_TIME_FOREVER);
		CloseHandle(menu);
		return Plugin_Handled;
	}
}
public MenuHandler_NewLife(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1:	ClinetResetStatus(Client, NewLife);
			case 2: return;
		}
	}
}
stock ChooseJob(Client, Jobid)
{
	if (KTCount[Client] > KTLimit)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_KT);
	}
	else if (JobChooseBool[Client])
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JCB_TURE);
	}
	else
	{
		if (Jobid==1)//工程师
		{
			if (Str[Client] >= JOB1_Str && Agi[Client] >= JOB1_Agi && Health[Client] >= JOB1_Health && Endurance[Client] >= JOB1_Endurance && Intelligence[Client] >= JOB1_Intelligence)
			{
				JD[Client] = 1;
				Str[Client] += 10;
				Endurance[Client] += 10;
				Intelligence[Client] += 10;
				JobChooseBool[Client] = true;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_ZZ_SUCCESS_JOB1_ANNOUNCE, Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB1_REWARD);
			}
			else
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB1_Str, JOB1_Agi, JOB1_Health, JOB1_Endurance, JOB1_Intelligence);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==2)//士兵
		{
			if (Str[Client] >= JOB2_Str && Agi[Client] >= JOB2_Agi && Health[Client] >= JOB2_Health && Endurance[Client] >= JOB2_Endurance && Intelligence[Client] >= JOB2_Intelligence)
			{
				JD[Client] = 2;
				Str[Client] += 10;
				Agi[Client] += 10;
				Health[Client] += 10;
				JobChooseBool[Client] = true;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_ZZ_SUCCESS_JOB2_ANNOUNCE, Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB2_REWARD);
			}
			else
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB2_Str, JOB2_Agi, JOB2_Health, JOB2_Endurance, JOB2_Intelligence);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==3)//生物专家
		{
			if (Str[Client] >= JOB3_Str && Agi[Client] >= JOB3_Agi && Health[Client] >= JOB3_Health && Endurance[Client] >= JOB3_Endurance && Intelligence[Client] >= JOB3_Intelligence)
			{
				JD[Client] = 3;
				Str[Client] += 10;
				Health[Client] += 10;
				Intelligence[Client] += 10;
				JobChooseBool[Client] = true;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_ZZ_SUCCESS_JOB3_ANNOUNCE, Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB3_REWARD);
			}
			else
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB3_Str, JOB3_Agi, JOB3_Health, JOB3_Endurance, JOB3_Intelligence);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==4)//心灵医师
		{
			if (Str[Client] >= JOB4_Str && Agi[Client] >= JOB4_Agi && Health[Client] >= JOB4_Health && Endurance[Client] >= JOB4_Endurance && Intelligence[Client] >= JOB4_Intelligence)
			{
				JD[Client] = 4;
				Str[Client] += 10;
				Health[Client] += 10;
				Endurance[Client] += 10;
				JobChooseBool[Client] = true;
				defibrillator[Client] = 2;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_ZZ_SUCCESS_JOB4_ANNOUNCE, Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB4_REWARD);
			}
			else
			{
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB4_Str, JOB4_Agi, JOB4_Health, JOB4_Endurance, JOB4_Intelligence);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==5)//魔法师
		{
			if(NewLifeCount[Client] >= 1)
			{
				if (Str[Client] >= JOB5_Str && Agi[Client] >= JOB5_Agi && Health[Client] >= JOB5_Health && Endurance[Client] >= JOB5_Endurance && Intelligence[Client] >= JOB5_Intelligence)
				{
					JD[Client] = 5;
					Str[Client] += 10;
					Health[Client] += 10;
					Intelligence[Client] += 10;
					JobChooseBool[Client] = true;
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MSG_ZZ_SUCCESS_JOB5_ANNOUNCE, Client);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB5_REWARD);
				}
				else
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB5_Str, JOB5_Agi, JOB5_Health, JOB5_Endurance, JOB5_Intelligence);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
	}
}

/* 购物商店 */
public Action:Menu_Buy(Client,args)
{
	MenuFunc_Buy(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_Buy(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Buy);
	decl String:line[32];
	SetMenuTitle(menu, "金钱: %d$ 记大过: %d次", Cash[Client], KTCount[Client]);
	AddMenuItem(menu, "option1", "幸存者商店");
	AddMenuItem(menu, "option2", "感染者商店");
	AddMenuItem(menu, "option3", "特殊商店");
	AddMenuItem(menu, "option4", "Robot工场");
	AddMenuItem(menu, "option5", "赌场");
	AddMenuItem(menu, "option6", "宝盒");
	AddMenuItem(menu, "option7", "A芯片");
	Format(line, sizeof(line), "彩票卷(%d个)", Lottery[Client]);
	AddMenuItem(menu, "option8", line);
	AddMenuItem(menu, "option9", "返回RPG选单");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_Buy(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select ) {
		switch (itemNum)
		{
			case 0: MenuFunc_SurvivorBuy(Client, true);
			case 1: MenuFunc_InfectedShop(Client, true);
			case 2: MenuFunc_SpecialShop(Client);
			case 3: MenuFunc_RobotWorkShop(Client);
			case 4: MenuFunc_Casino(Client);
			case 5: MenuFunc_WLBHS(Client);
			case 6: MenuFunc_AXPSC(Client);
			case 7: MenuFunc_Lottery(Client);
			case 8: MenuFunc_RPG(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}

/* 强化石购买 */
public Action:MenuFunc_Eqgou(Client)
{   
	new Handle:menu = CreatePanel();	
    
	decl String:line[1024];   
	Format(line, sizeof(line), "═══强化石材料═══");   
	SetPanelTitle(menu, line); 
	Format(line, sizeof(line), "说明: 强化枪械的材料(价格:30000)");   
	DrawPanelText(menu, line);
	
	Format(line, sizeof(line), "购买");    
	DrawPanelItem(menu, line);	
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
   
	SendPanelToClient(menu, Client, MenuHandler_Eqgou, MENU_TIME_FOREVER);   
	return Plugin_Handled;
}

public MenuHandler_Eqgou(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: 
			{
				EQBBX(Client);
				MenuFunc_Eqgou(Client);
			}
		}
	}
}
public EQBBX(Client)
{
    if(Cash[Client] >= 3000)
    {
        Cash[Client] -= 3000;
        Shitou[Client]++;
        if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】你购买了强化石!");	if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05【提示】玩家 %N 通过强化石商店购买了一块强化石!", Client);
    } else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】购买失败,金钱不足!");	 
}


/* A芯片 */
public Action:MenuFunc_AXPSC(Client)
{   
	new Handle:menu = CreatePanel();	
    
	decl String:line[1024];   
	Format(line, sizeof(line), "═══A芯片 (拥有: %d个) ═══", AXP[Client]);   
	SetPanelTitle(menu, line);    
	Format(line, sizeof(line), "说明: 随机获得更加珍贵的物品哦！");   
	DrawPanelText(menu, line);
	
	Format(line, sizeof(line), "购买A芯片(金钱:2000)");    
	DrawPanelItem(menu, line);	
	Format(line, sizeof(line), "使用");   
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
   
	SendPanelToClient(menu, Client, MenuHandler_AXPS, MENU_TIME_FOREVER);   
	return Plugin_Handled;
}

public MenuHandler_AXPS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: GOUMAIA(Client);
            case 2: UseSYSFunc(Client);			
		}
		MenuFunc_AXPSC(Client);
	}
	else if(action == MenuAction_End || MenuAction_Cancel)
	{
		CloseHandle(menu);
	}
}
public Action:UseSYSFunc(Client)
{
	if(Cash[Client] >= 10000)
	{	
		if(AXP[Client]>0)
	    {
			AXP[Client]--;
			new diceNum = GetRandomInt(1, 10), String:name[128];
			GetClientName(Client, name, 128);
			switch(diceNum)
		    {
				case 1:
				{
                    CheatCommand(Client, "give", " weapon_grenade_launcher");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了一把榴弹发射器!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一把榴弹发射器！", name);
                }
				case 2:
			    {
                    CheatCommand(Client, "give", "shotgun_chrome");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了一把2代散弹!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一把 2 代散弹！", name);
                }
				case 3:
			    {
                    CheatCommand(Client, "give", "defibrillator");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了一个电震动器!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一个电震动器！", name);
                }	
				case 4: 
			    {
                    Cash[Client] += 1000000;
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了1000000$!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一百万金钱！", name);
                }
				case 5: 
			    {
                    CheatCommand(Client, "give", "first_aid_kit");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了一个医药包!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一个医药包！", name);
                }
				case 6: 
			    {
                    CheatCommand(Client, "give", "pistol_magnum");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得一把沙漠之鹰!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一把马格南！", name);
                }
				case 7: 
			    {
                    CheatCommand(Client, "give", "pain_pills");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了止痛药1个!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了止痛药 1 个！", name);
                }	
				case 8: 
			    {
                    CheatCommand(Client, "give", "adrenaline");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了肾上腺素针一支!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了肾上腺素针一支！", name);
                }
				case 9: 
			    {
                    CheatCommand(Client, "give", "rifle_m16");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了AK47!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一把 M16！", name);
                }
				case 10: 
			    {
                    CheatCommand(Client, "give", "rifle_m60");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x05[提示]玩家%N使用A芯片获得了M60机枪!", Client);
                    PrintToServer("[提示] 玩家 %s 使用 A芯片 获得了一把 M60 机枪！", name);
                }
		    }
		} else if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你没有A芯片!");
	} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】所需金钱不够, 无法购买!");	
	return Plugin_Handled;
}
public GOUMAIA(Client)
{
    if(Cash[Client] >= 10000)
    {
        Cash[Client] -= 10000;
        AXP[Client]++;
        if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】你购买了A芯片!");
    } else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】购买失败,金钱不足!");	 
}

/* 特感宝盒 */
public Action:MenuFunc_WLBHS(Client)
{   
	new Handle:menu = CreatePanel();	
    
	decl String:line[1024];   
	Format(line, sizeof(line), "═══宝盒 (拥有: %d个)═══", WLBH[Client]);   
	SetPanelTitle(menu, line);    
	Format(line, sizeof(line), "说明: 购买开出宝藏的宝盒!");   
	DrawPanelText(menu, line);
	
	Format(line, sizeof(line), "购买宝盒(金钱:2000)");    
	DrawPanelItem(menu, line);	
	Format(line, sizeof(line), "开启宝盒");   
	DrawPanelItem(menu, line);   
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
   
	SendPanelToClient(menu, Client, MenuHandler_WLBHS, MENU_TIME_FOREVER);   
	return Plugin_Handled;
}

public MenuHandler_WLBHS(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: GOUMAI(Client);
            case 2: UseWLBHSFunc(Client);					
		}
		MenuFunc_WLBHS(Client);
	}
	else if(action == MenuAction_End || action == MenuAction_Cancel)
	{
		CloseHandle(menu);
	}
}
public Action:UseWLBHSFunc(Client)
{
    if(Cash[Client] >= 10000)
	{	
	    if(WLBH[Client]>0)
	    {
            WLBH[Client]--;
            new diceNum = GetRandomInt(1, 10), String:name[128];
            GetClientName(Client, name, 128);
            switch (diceNum)
		    {
			    case 1:
				{
                    CheatCommand(Client, "z_spawn", "tank auto");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了Tank一只!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 Tank 一只！", name);
                }
				case 2: 
			    {
                    CheatCommand(Client, "z_spawn", "witch auto");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得Witch妹子!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 Witch 一只！", name);
				}
                case 3: 
			    {
                    CheatCommand(Client, "director_force_panic_event", "");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了一群丧尸!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 一群丧失！", name);
				}	
                case 4: 
			    {
                    Cash[Client] += 1000;
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了1000$!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 一千刀！", name);
			    }
                case 5: 
			    {
                    CheatCommand(Client, "give", "first_aid_kit");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了一个医药包!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 一个包！", name);
				}
                case 6: 
			    {
                    CheatCommand(Client, "give", "weapon_fireworkcrate");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得一盒烟花!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 一盒炮仗！", name);
				}
                case 7: 
			    {
                    CheatCommand(Client, "give", "molotov");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了燃烧瓶1个!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 红瓶！", name);
				}	
                case 8: 
			    {
                    CheatCommand(Client, "give", "baseball_bat");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了棒球棍!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 棒子！", name);
				}
                case 9: 
			    {
                    CheatCommand(Client, "give", "rifle_ak47");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了AK47!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 抢银行专用！", name);
				}
                case 10: 
			    {
                    CheatCommand(Client, "give", "rifle_m60");
                    if(GetConVarInt(g_hCvarShow))CPrintToChatAll("\x03[提示]\x01 玩家\x04 %N\x01 打开宝盒获得了M60机枪!", Client);
                    PrintToServer("[提示] 玩家 %s 打开盒子获得了 机关枪！", name);
				}
		    }
	    } else if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "【提示】你没有奇迹宝盒!");
    } else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】所需金钱不够, 无法开启!");	
    return Plugin_Handled;
}
public GOUMAI(Client)
{
    if(Cash[Client] >= 2000)
    {
        Cash[Client] -= 2000;
        WLBH[Client]++;
        if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】你购买了宝盒!");
    } else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "\x05【提示】购买失败,金钱不足!");	 
}

/* 幸存者购物商店 */
public Action:Menu_SurvivorBuy(Client, args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS && !IsFakeClient(Client))
	{
		MenuFunc_SurvivorBuy(Client, args ? true : false);
	}
	else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{red}只限幸存者选择!");
	}
	return Plugin_Handled;
}

public Action:MenuFunc_SurvivorBuy(Client, bool:addlist)
{
	new Handle:menu = CreateMenu(MenuHandler_SurvivorBuy);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	AddMenuItem(menu, "option1", "医疗品/投掷/弹药");
	AddMenuItem(menu, "option2", "步枪/霰弹枪/狙击枪");
	AddMenuItem(menu, "option3", "刀/盾/锯/棒/锅");
	if(Lv[Client] >= 50 || JD[Client] || IsAdmin[Client]) AddMenuItem(menu, "option4", "自动攻击武器");
	if(addlist)
	{
		AddMenuItem(menu, "option5", "强化石商店");
		AddMenuItem(menu, "option6", "返回赌场&商店选单");
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_SurvivorBuy(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum)
		{
			case 0: MenuFunc_NormalItemShop(Client);
			case 1: MenuFunc_SelectedGunShop(Client);
			case 2: MenuFunc_MeleeShop(Client);
			case 3: MenuFunc_RobotShop(Client);
			case 4: MenuFunc_Eqgou(Client);
			case 5: MenuFunc_Buy(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
/* 投掷品，药物和子弹盒 */
public Action:Menu_NormalItemShop(Client,args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS && !IsFakeClient(Client) && GetConVarBool(CfgNormalItemShopEnable))
	{
		MenuFunc_NormalItemShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{red}只限幸存者选择!");
	}
	else if(!GetConVarBool(CfgNormalItemShopEnable))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}商店己关闭!");
	}
	return Plugin_Handled;
}

static String:NormalItemName[NORMALITEMMAX][]={ "子弹", "燃烧瓶",
"土製炸弹","胆汁", "药包", "药丸", "肾上腺素", "电击器", "高爆子弹盒", "燃烧子弹盒"};

public Action:MenuFunc_NormalItemShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_NormalItemShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32], itemcost;
	for(new i=0; i<NORMALITEMMAX; i++)
	{
		itemcost = GetConVarInt(CfgNormalItemCost[i]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		Format(line, sizeof(line), "%s($%d)", NormalItemName[i], itemcost);
		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	PrintToConsole("NLC = %d, KTC = %d", NewLifeCount[Client], KTCount[Client]);
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_NormalItemShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)  {
		new targetcash = Cash[Client];
		new itemcost = GetConVarInt(CfgNormalItemCost[itemNum]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		
		if(targetcash >= itemcost  && IsPlayerAlive(Client)) {
			targetcash -= itemcost;
			switch (itemNum)
			{
				case 0: CheatCommand(Client, "give", "ammo");
				case 1: CheatCommand(Client, "give", "molotov");
				case 2: CheatCommand(Client, "give", "pipe_bomb");
				case 3: CheatCommand(Client, "give", "vomitjar");
				case 4: CheatCommand(Client, "give", "first_aid_kit");
				case 5: CheatCommand(Client, "give", "pain_pills");
				case 6: CheatCommand(Client, "give", "adrenaline");
				case 7: CheatCommand(Client, "give", "defibrillator");
				case 8: CheatCommand(Client, "give", "upgradepack_explosive");
				case 9: CheatCommand(Client, "give", "upgradepack_incendiary");
			}
			Cash[Client] = targetcash;
			CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_NormalItemShop(Client);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_ExitBack)
			Menu_SurvivorBuy(Client, 0);
	}
}
/* 特选枪械 */
public Action:Menu_SelectedGunShop(Client,args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS && !IsFakeClient(Client) && GetConVarBool(CfgSelectedGunShopEnable))
	{
		MenuFunc_SelectedGunShop(Client);
	}else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{red}只限幸存者选择!");
	}else if(!GetConVarBool(CfgSelectedGunShopEnable))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}商店己关闭!");
	}
	return Plugin_Handled;
}

static String:GunName[SELECTEDGUNMAX][]={ "MP5冲锋枪","Scout鸟狙",
"Awp大鸟","Sg552放大步枪","M60机关枪","榴弹发射器", "AK47匪徒专用", "spac战术霰弹枪"};

public Action:MenuFunc_SelectedGunShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_SelectedGunShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32], itemcost;
	for(new i=0; i<SELECTEDGUNMAX; i++)
	{
		itemcost = GetConVarInt(CfgSelectedGunCost[i]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		Format(line, sizeof(line), "%s($%d)", GunName[i], itemcost);
		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	PrintToConsole("NLC = %d, KTC = %d", NewLifeCount[Client], KTCount[Client]);
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public MenuHandler_SelectedGunShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = Cash[Client];
		new itemcost = GetConVarInt(CfgSelectedGunCost[itemNum]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);

		if(targetcash >= itemcost && IsPlayerAlive(Client)) {
			targetcash -= itemcost;
			switch (itemNum)
			{
				case 0: CheatCommand(Client, "give", "smg_mp5");
				case 1: CheatCommand(Client, "give", "sniper_scout");
				case 2: CheatCommand(Client, "give", "sniper_awp");
				case 3: CheatCommand(Client, "give", "rifle_sg552");
				case 4: CheatCommand(Client, "give", "rifle_m60");
				case 5: CheatCommand(Client, "give", "grenade_launcher");
				case 6: CheatCommand(Client, "give", "rifle_ak47");
				case 7: CheatCommand(Client, "give", "shotgun_spas");
			}
			Cash[Client] = targetcash;
			CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
			new wpn = GetPlayerWeaponSlot(Client, 0);
			if(wpn && IsValidEdict(wpn) && IsValidEntity(wpn))
			{
				SetEntProp(Client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(wpn, Prop_Send, "m_iPrimaryAmmoType"));
				//SetEntProp(wpn, Prop_Send, "m_iClip1", 0);
				//SetEntProp(wpn, Prop_Send, "m_iSecondaryAmmoType", 0);
			}
		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_SelectedGunShop(Client);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_ExitBack) 
			Menu_SurvivorBuy(Client, 0);
	}
}
/* 近武商店 */
public Action:Menu_MeleeShop(Client,args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS && !IsFakeClient(Client) && GetConVarBool(CfgMeleeShopEnable))
	{
		MenuFunc_MeleeShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{red}只限幸存者选择!");
	}
	else if(!GetConVarBool(CfgMeleeShopEnable))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}商店己关闭!");
	}
	return Plugin_Handled;
}

static String:MeleeName[SELECTEDMELEEMAX][]={ "棒球棍", "船桨", "物理学圣剑", "电音吉他",
"消防斧", "平底锅", "高尔夫球棍", "武士刀", "海豹短刀", "开山刀", "防爆盾", "警棍", "链锯"};

public Action:MenuFunc_MeleeShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_MeleeShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32], itemcost;
	for(new i=0; i<SELECTEDMELEEMAX; i++)
	{
		itemcost = GetConVarInt(CfgMeleeCost[i]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		Format(line, sizeof(line), "%s($%d)", MeleeName[i], itemcost);
		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	PrintToConsole("NLC = %d, KTC = %d", NewLifeCount[Client], KTCount[Client]);
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_MeleeShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = Cash[Client];
		new itemcost = GetConVarInt(CfgMeleeCost[itemNum]);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);

		if(targetcash >= itemcost && IsPlayerAlive(Client)) {
			targetcash -= itemcost;
			switch (itemNum)
			{
				case 0: CheatCommand(Client, "give", "baseball_bat");
				case 1: CheatCommand(Client, "give", "cricket_bat");
				case 2: CheatCommand(Client, "give", "crowbar");
				case 3: CheatCommand(Client, "give", "electric_guitar");
				case 4: CheatCommand(Client, "give", "fireaxe");
				case 5: CheatCommand(Client, "give", "frying_pan");
				case 6: CheatCommand(Client, "give", "golfclub");
				case 7: CheatCommand(Client, "give", "katana");
				case 8: CheatCommand(Client, "give", "hunting_knife");
				case 9: CheatCommand(Client, "give", "machete");
				case 10: CheatCommand(Client, "give", "riotshield");
				case 11: CheatCommand(Client, "give", "tonfa");
				case 12: CheatCommand(Client, "give", "chainsaw");
			}
			Cash[Client] = targetcash;
			CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_MeleeShop(Client);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_ExitBack) 
			Menu_SurvivorBuy(Client, 0);
	}
}
/* Robot商店 */
public Action:Menu_RobotShop(Client,args)
{
	if(GetClientTeam(Client) == TEAM_SURVIVORS && !IsFakeClient(Client))
	{
		MenuFunc_RobotShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{red}暂时只限幸存者选择!");
	}
	return Plugin_Handled;
}

public Action:MenuFunc_RobotShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RobotShop);
	SetMenuTitle(menu, "金钱: %d $ Robot使用次数: %d", Cash[Client], RobotCount[Client]);

	decl String:line[64], String:option[32], itemcost;
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		itemcost = GetConVarInt(CfgRobotCost[i]) * (RobotCount[Client] + 1);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		Format(line, sizeof(line), "全自动 [%s] 武器 ($%d)", WeaponName[i], itemcost);
		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	PrintToConsole("NLC = %d, KTC = %d", NewLifeCount[Client], KTCount[Client]);
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_RobotShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		new targetcash = Cash[Client];
		new itemcost = GetConVarInt(CfgRobotCost[itemNum]) * (RobotCount[Client] + 1);
		if(KTCount[Client]) itemcost += itemcost * RoundToCeil(KTCount[Client] * 0.75);
		else if(NewLifeCount[Client]) itemcost -= itemcost * RoundFloat(NewLifeCount[Client] * 0.25);
		
		if(targetcash >= itemcost && IsPlayerAlive(Client))
		{
			targetcash -= itemcost;
			if(robot[Client] == 0)
			{
				botenerge[Client] = 0.0;
				RobotCount[Client] += 1;
				Cash[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
			}
			sm_robot(Client, itemNum);
		}
		else
		{
			CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		}
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	else if(action == MenuAction_Cancel)
	{
		if(itemNum == MenuCancel_ExitBack) 
			Menu_SurvivorBuy(Client, 0);
	}
}

/* 感染者购物商店 */
public Action:Menu_InfectedShop(Client,args)
{
	if(GetClientTeam(Client) == TEAM_INFECTED && !IsFakeClient(Client))
	{
		MenuFunc_InfectedShop(Client, true);
	}
	else if(!IsFakeClient(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{blue}只限特殊感染者选择!");
	}
	return Plugin_Handled;
}
public Action:MenuFunc_InfectedShop(Client, bool:all)
{
	new Handle:menu = CreateMenu(MenuHandler_InfectedShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[256];
	Format(line, sizeof(line), "自杀(免费)");
	AddMenuItem(menu, "option1", line);
	if(all) AddMenuItem(menu, "option2", "返回赌场&商店选单");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_InfectedShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch(itemNum)
		{
			case 0: ForcePlayerSuicide(Client);
			case 1: MenuFunc_Buy(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
/* 特殊商店 */
public Action:MenuFunc_SpecialShop(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "金钱: %d$ 记大过: %d次", Cash[Client], KTCount[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "经验书 ($%d)", GetConVarInt(TomeOfExpCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "使用一次增加 %d 经验~", GetConVarInt(TomeOfExpEffect));
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "赎罪卷 ($%d)", GetConVarInt(RemoveKTCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "有钱能使鬼推磨~");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "忘情油 ($%d)", GetConVarInt(ResetStatusCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "喝了它的人据说会忘掉一切...");
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "返回赌场&商店选单");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_SpecialShop, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_SpecialShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum) {
			case 1: {
				new itemcost	= GetConVarInt(TomeOfExpCost);
				new itemEffect	= GetConVarInt(TomeOfExpEffect);

				if(Cash[Client] >= itemcost)
				{
					EXP[Client] += itemEffect;
					Cash[Client] -= itemcost;
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else
				{
					CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
				}
				MenuFunc_SpecialShop(Client);
			} case 2: {
				new itemcost	= GetConVarInt(RemoveKTCost);

				if(KTCount[Client]>0)
				{
					if(Cash[Client] >= itemcost)
					{
						Cash[Client] -= itemcost;
						KTCount[Client] -=1;
						CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
					}
					else
					{
						CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
						MenuFunc_SpecialShop(Client);
					}
				} else CPrintToChat(Client, "{green}你暂时不需要购买此物品!");
			} case 3: {
				new itemcost	= GetConVarInt(ResetStatusCost);

				if(Cash[Client] >= itemcost)
				{
					Cash[Client] -= itemcost;
					ClinetResetStatus(Client, Shop);
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else
				{
					CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
				}
			} case 4: MenuFunc_Buy(Client);
		}
	}
}

/* Robot工场*/
static String:RobotUpgradeName[3][]={ "提升Robot攻击力(目前等级: %d/%d, 所需费用: %d)", "提升Robot弹匣系统(目前等级: %d/%d, 所需费用: %d)", "提升Robot侦察距离(目前等级: %d/%d, 所需费用: %d)"};
static String:RobotUpgradeInfo[3][]={ "目前Robot攻击力系数: %.2f", "目前Robot弹匣量系数: %.2f", "目前Robot侦察距离: %d"};
static RobotUpgradeLimit[3]={50, 50, 20};
#define RobotAttackEffect[%1]	0.5 + 0.025*RobotUpgradeLv[%1][0]
#define RobotAmmoEffect[%1]		1.0 + 0.1*RobotUpgradeLv[%1][1]
#define RobotRangeEffect[%1]	500 + 25*RobotUpgradeLv[%1][2]
public Action:MenuFunc_RobotWorkShop(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[64];
	Format(line, sizeof(line), "金钱: %d $", Cash[Client]);
	SetPanelTitle(menu, line);
	
	for(new i=0; i<3; i++)
	{
		Format(line, sizeof(line), RobotUpgradeName[i], RobotUpgradeLv[Client][i], RobotUpgradeLimit[i], GetConVarInt(CfgRobotUpgradeCost[i]));
		DrawPanelItem(menu, line);
		switch (i)
		{
			case 0: Format(line, sizeof(line), RobotUpgradeInfo[0], RobotAttackEffect[Client]);
			case 1: Format(line, sizeof(line), RobotUpgradeInfo[1], RobotAmmoEffect[Client]);
			case 2: Format(line, sizeof(line), RobotUpgradeInfo[2], RobotRangeEffect[Client]);
		}
		DrawPanelText(menu, line);
	}
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	
	SendPanelToClient(menu, Client, MenuHandler_RobotWorkShop, MENU_TIME_FOREVER);
	
	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_RobotWorkShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = Cash[Client];
		new itemcost = GetConVarInt(CfgRobotUpgradeCost[itemNum-1]);

		if(RobotUpgradeLv[Client][itemNum-1] < RobotUpgradeLimit[itemNum-1])
		{
			if(targetcash >= itemcost) {
				targetcash -= itemcost;
				RobotUpgradeLv[Client][itemNum-1] += 1;
				Cash[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				switch (itemNum)
				{
					case 1: if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, RobotUpgradeInfo[0], RobotAttackEffect[Client]);
					case 2: if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, RobotUpgradeInfo[1], RobotAmmoEffect[Client]);
					case 3: if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, RobotUpgradeInfo[2], RobotRangeEffect[Client]);
				}
			}
			else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		} else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_ROBOT_UPGRADE_MAX);
		MenuFunc_RobotWorkShop(Client);
	}
}
/* 赌场 */
public Action:Menu_Casino(Client,args)
{
	MenuFunc_Casino(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_Casino(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Casino);
	SetMenuTitle(menu, "你的金钱: %d $", Cash[Client]);

	AddMenuItem(menu, "Option1", "开口中");
	AddMenuItem(menu, "Option2", "返回赌场&商店选单");

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_Casino(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum)
		{
			case 0: MenuFunc_Casino_OpenMouth(Client);
			case 1: MenuFunc_Buy(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
/*  开口中 */
public Action:Menu_Casino_OpenMouth(Client,args)
{
	if(Cash[Client] > 0)	MenuFunc_Casino_OpenMouth(Client);
	else if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}你没钱了!");
	return Plugin_Handled;
}
public Action:MenuFunc_Casino_OpenMouth(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Casino_OpenMouth);
	SetMenuTitle(menu, "你的金钱: %d $", Cash[Client]);
	decl String:line[256];

	Format(line, sizeof(line), "赌%d$", Cash[Client]*1/10);
	AddMenuItem(menu, "Option1", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*2/10);
	AddMenuItem(menu, "Option2", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*3/10);
	AddMenuItem(menu, "Option3", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*4/10);
	AddMenuItem(menu, "Option4", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*5/10);
	AddMenuItem(menu, "Option5", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*6/10);
	AddMenuItem(menu, "Option6", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*7/10);
	AddMenuItem(menu, "Option7", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*8/10);
	AddMenuItem(menu, "Option8", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]*9/10);
	AddMenuItem(menu, "Option9", line);
	Format(line, sizeof(line), "赌%d$", Cash[Client]);
	AddMenuItem(menu, "Option10", line);


	//SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_Casino_OpenMouth(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new luck = GetRandomInt(1,2);
		if(luck == 1)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client,"{green}赢了! 你获得{lightgreen}%d$",Cash[Client]*(itemNum+1)/10);
			Cash[Client]+=Cash[Client]*(itemNum+1)/10;
		}
		else
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChat(Client,"{green}输了! 你损失{lightgreen}%d$",Cash[Client]*(itemNum+1)/10);
			Cash[Client]-=Cash[Client]*(itemNum+1)/10;
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}

public Action:MenuFunc_Lottery(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "金钱:%d$ 彩票卷:%d个", Cash[Client], Lottery[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "购买($%d)", GetConVarInt(LotteryCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "回收(%d 智商税)", RoundToNearest(GetConVarInt(LotteryCost)*(1-GetConVarFloat(LotteryRecycle))));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "使用(剩余%d个)", Lottery[Client]);
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回赌场&商店选单");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Lottery, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_Lottery(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) 
	{
		new itemcost = GetConVarInt(LotteryCost);
		switch (itemNum)
		{
			case 1:
			{
				if(Cash[Client] >= itemcost)
				{
					Lottery[Client]++, Cash[Client] -= itemcost;
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
			}
			case 2:
			{
				new tax = RoundToNearest(itemcost*(1-GetConVarFloat(LotteryRecycle)));
				if(Lottery[Client]>0)
				{
					Lottery[Client]--, Cash[Client] += itemcost-tax;
					if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, MSG_RecycleSUCC, itemcost-tax, tax, Cash[Client]);
					//PrintToChat(Client, "\x03[提示]\x01 事件将在\x05 30\x01 秒后发生...");
				}
				else 
				{
					if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "你身上没有彩票卷哦~");
					//PrintToChat(Client, "\x03[提示]\x01 你的人品已经用光了...");
				}
			}
			case 3: /*UseLotteryFunc(Client);*/CreateTimer(30.0, UseLotteryFunc, Client);
			case 4: MenuFunc_Buy(Client);
		}
		MenuFunc_Lottery(Client);
	}
}
/* 彩票卷 */
public Action:UseLottery(Client, args)
{
	//UseLotteryFunc(Client);
	CreateTimer(30.0, UseLotteryFunc, Client);
	return Plugin_Handled;
}

public Action:UseLotteryFunc(Handle:timer, any:Client)
{
	if(GetConVarInt(LotteryEnable)!=1)
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}对不起! {blue}服务器没有开啟彩票功能!");
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(Client))
	{
		if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{green}对不起! {blue}死亡状态下无法使用彩票功能!");
		return Plugin_Handled;
	}
	
	if(AdminDiceNum[Client]>0 || Lottery[Client]>0)
	{
		Lottery[Client]--;
		new diceNum;
		if(AdminDiceNum[Client]>0) diceNum = AdminDiceNum[Client];
		else diceNum = GetRandomInt(diceNumMin, diceNumMax);
		
		switch (diceNum)
		{
			case 1: //给予战术散弹鎗
			{
				new Num = GetRandomInt(1, 5);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "autoshotgun");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}把战术散弹鎗!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 在脚下挖到了 %d 把战术霰弹枪！", NameInfo(Client, simple), Num);
			}
			case 2: //冰冻玩家
			{
				new duration = GetRandomInt(10, 30);
				ServerCommand("sm_freeze \"%N\" \"%d\"", Client, duration);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 被冰冻{green}%d{default}秒!", NameInfo(Client, colored), duration);
				PrintToServer("[人品] %s 被冰冻 %d 秒!", NameInfo(Client, simple), duration);
			}
			case 3: //给予M16
			{
				new Num = GetRandomInt(1, 5);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "rifle");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {default}M16-猥琐者的专用, 恭喜 %s 获得{green}%d{default}把!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] M16-猥琐者的专用, 恭喜 %s 获得 %d 把!", NameInfo(Client, simple), Num);
			}
			case 4: //给予土製炸弹
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "pipe_bomb");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}个手雷!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 获得 %d 个手雷!", NameInfo(Client, simple), Num);
			}
			case 5: // 给予药丸
			{
				for(new i=1; i<=MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					if(GetClientTeam(i)==TEAM_SURVIVORS && IsPlayerAlive(i) && GetPlayerWeaponSlot(i, 4) == -1)
						CheatCommand(i, "give", "pain_pills");
				}
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {default}所有人获得药丸, 如果你已随身携带请留心脚下寻找!");
				PrintToServer("[人品] 感染者大发善心，给了所有生还者一瓶药！");
			}			
			case 6: // 获得生命
			{
				CheatCommand(Client, "give", "health");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 恢复全满生命!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 的祈祷得到了回应，血量一下就回满了！", NameInfo(Client, simple));
			}
			case 7: // 召唤Jimmy
			{
				decl Float:pos[3];
				GetClientAbsOrigin(Client, pos);
				pos[2] += 20.0;
				new Num = GetRandomInt(20, 50);
				for(new x=1; x<=Num; x++)
					SpawnUncommonInf(Client, 5, pos);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %d{default}个赛车手{green}Jimmy{default}听说 %s 荣获F1冠军, 特来围观!", Num, NameInfo(Client, colored));
				PrintToServer("[人品] %d个赛车手Jimmy听说 %s 荣获F1冠军, 特来围观!", Num, NameInfo(Client, simple));
			}
			case 8: // 中毒
			{
				new Float:duration = GetRandomFloat(5.0, 10.0);
				ServerCommand("sm_drug \"%N\" \"1\"", Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 乱吃东西而中毒, 将拉肚子{green}%.2f{default}秒", NameInfo(Client, colored), duration);
				PrintToServer("[人品] %s 饥饿难耐，啃了一口丧尸，结果不小心中毒了 %.2f 秒", NameInfo(Client, simple), duration);
				CreateTimer(duration, RestoreSick, Client);
			}
			case 9: // 给予狙击
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "hunting_rifle");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {default}狙击是一门艺术 - 谁也无法阻挡 %s 追求艺术的脚步! 获得{green}%d{default}把猎枪!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] 狙击是一门艺术 - 谁也无法阻挡 %s 追求艺术的脚步! 获得%d把猎枪!", NameInfo(Client, simple), Num);
			}
			case 10: // 变药包
			{
				SetEntityModel(Client, "models/w_models/weapons/w_eq_medkit.mdl");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 被变成药包了!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 总想着要个医疗包，结果把自己变成了医疗包！", NameInfo(Client, simple));
			}
			case 11: // 尸群事件
			{
				decl Float:pos[3];
				GetClientAbsOrigin(Client, pos);
				pos[2] += 100.0;
				new Num = GetRandomInt(50, 100);
				for(new x=1; x<=Num; x++)
					SpawnUncommonInf(Client, 0, pos);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 因很久没洗澡而发出的气味在他的周围引来了一群丧尸!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 发动了准备已久的大召唤术！", NameInfo(Client, simple));
			}
			case 12: // TANK
			{
				CheatCommand(Client, "z_spawn", "tank auto");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 在墙角画圈圈, 结果一不小心把{green}Tank{default}召唤了出来!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 在墙角画圈圈, 结果一不小心把Tank召唤了出来!", NameInfo(Client, simple));
			}
			case 13: // Witch
			{
				new Num = GetRandomInt(1, 10);
				for(new x=1; x<=Num; x++)
					CheatCommand(Client, "z_spawn", "witch auto");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 召唤了他的{green}%d{default}个爱妃{green}Witch{default}!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 召唤了他的%d个爱妃Witch!", NameInfo(Client, simple), Num);
			}
			case 14: // 召唤殭尸
			{
				CheatCommand(Client, "director_force_panic_event", "");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 这位大帅哥, 為大家引来了一群丧尸!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 刚才从地下被挖出来，身后跟着一大群丧失！", NameInfo(Client, simple));
			}
			case 15: // 萤光
			{
				IsGlowClient[Client] = true;
				PerformGlow(Client, 3, 0, 65534);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 的身上发出了萤光!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 为了让别人注意到他，他学会了发光技能！", NameInfo(Client, simple));
			}
			case 16: //给予燃烧炸弹
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "molotov");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}个燃烧瓶!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 获得 %d 个燃烧瓶!", NameInfo(Client, simple), Num);
			}
			case 17: //给予氧气瓶
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "oxygentank");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}个氧气樽!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 获得 %d 个氧气樽!", NameInfo(Client, simple), Num);
			}
			case 18: //给予煤气罐
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "propanetank");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}个煤气罐!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 获得 %d 个煤气罐!", NameInfo(Client, simple), Num);
			}
			case 19: //给予油桶
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "gascan");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得{green}%d{default}个油桶!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 抢劫了加油站，抢到了 %d 个汽油桶！", NameInfo(Client, simple), Num);
			}
			case 20: //给予药包
			{
				CheatCommand(Client, "give", "first_aid_kit");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得一个药包!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 在路上捡到了一个医疗包！", NameInfo(Client, simple));
			}
			case 21: // 无限子弹
			{
				if(GetConVarInt(FindConVar("sv_infinite_ammo")) == 1)
				{
					//LotteryEventDuration[0] = 0;
					SetConVarInt(FindConVar("sv_infinite_ammo"), 0);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 发现子弹库内餘下子弹是BB弹, 无限子弹提前结束了, 全体感谢他吧...", NameInfo(Client, colored));
					PrintToServer("[人品] %s发现子弹库内餘下子弹是BB弹, 无限子弹提前结束了, 全体感谢他吧...", NameInfo(Client, simple));
				}
				else
				{
					new duration = GetRandomInt(10, 30);
					//LotteryEventDuration[0] = duration;
					SetConVarInt(FindConVar("sv_infinite_ammo"), 1);
					CreateTimer(float(duration), LotteryInfiniteAmmo, _, TIMER_FLAG_NO_MAPCHANGE);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 发现子弹库, 全体无限子弹{green}%d{default}秒, 大家感激他吧!", NameInfo(Client, colored), duration);
					PrintToServer("[人品] %s发现子弹库, 全体无限子弹%d秒, 大家感激他吧!", NameInfo(Client, simple), duration);
				}
			}
			case 22: // 黑屏
			{
				PerformFade(Client, 150);
				new Float:duration = GetRandomFloat(5.0, 10.0);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 视力减弱{green}%.2f{default}秒", NameInfo(Client, colored), duration);
				PrintToServer("[人品] %s 因为撸多了导致视力模糊 %.2f 秒", NameInfo(Client, simple), duration);
				CreateTimer(duration, RestoreFade, Client);
			}
			case 23: // 死亡召唤殭尸
			{
				if(GetClientTeam(Client)==2 && IsPlayerIncapped(Client))
				{
					CheatCommand(Client, "director_force_panic_event", "");
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {default}倒下的 %s 因无人救他, 对生还者表示仇视, 大叫而引发尸群攻击!", NameInfo(Client, colored));
					PrintToServer("[人品] 倒下的 %s 因无人救他, 对生还者表示仇视, 大叫而引发尸群攻击!", NameInfo(Client, simple));
				}
				else
				{
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {default}倒下的 %s 使用了彩票, 结果什麼事情都没有发生!", NameInfo(Client, colored));
					PrintToServer("[人品] 倒下的 %s 使用了彩票, 结果什麼事情都没有发生!", NameInfo(Client, simple));
				}
			}
			case 24: // 普感生命值改变
			{
				new value = GetRandomInt(1, 10);
				new mode = GetRandomInt(0, 1);
				if(mode)
				{
					new duration = GetRandomInt(20, 40);
					//LotteryEventDuration[1] = duration;
					SetConVarInt(FindConVar("z_health"), oldCommonHp*value);
					if(LotteryWeakenCommonsHpTimer != INVALID_HANDLE)
					{
						KillTimer(LotteryWeakenCommonsHpTimer);
						LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
					}
					LotteryWeakenCommonsHpTimer = CreateTimer(float(duration), LotteryWeakenCommonsHp, _, TIMER_FLAG_NO_MAPCHANGE);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 因强姦了一隻普感而引发丧尸们的愤怒, 在{green}%d{default}秒内普感生命值加强{green}%d{default}倍!", NameInfo(Client, colored), duration, value);
					PrintToServer("[人品] %s 因强姦了一隻普感而引发丧尸们的愤怒, 在%d秒普感生命值加强%d倍!", NameInfo(Client, simple), duration, value);
				}
				else
				{
					new duration = GetRandomInt(20, 40);
					//LotteryEventDuration[1] = duration;
					SetConVarInt(FindConVar("z_health"), oldCommonHp/value);
					if(LotteryWeakenCommonsHpTimer != INVALID_HANDLE)
					{
						KillTimer(LotteryWeakenCommonsHpTimer);
						LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
					}
					LotteryWeakenCommonsHpTimer = CreateTimer(float(duration), LotteryWeakenCommonsHp, _, TIMER_FLAG_NO_MAPCHANGE);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {blue}丧尸们对 %s 动了点怜悯之心, 在{green}%d{default}秒内普感生命值减弱{green}%d{default}倍!", NameInfo(Client, colored), duration, value);
					PrintToServer("[人品] 丧尸们对 %s 动了点怜悯之心, 在%d秒内普感生命值减弱%d倍!", NameInfo(Client, simple), duration, value);
				}
			}
			case 25: // 无敌事件
			{
				if(GetConVarInt(FindConVar("god"))==1)
				{
					//LotteryEventDuration[2] = 0;
					SetConVarInt(FindConVar("god"), 0);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 发现原来无敌药过期了, 无敌效果提前结束了!", NameInfo(Client, colored));
					PrintToServer("[人品] %s 发现原来无敌药过期了, 无敌效果提前结束了!", NameInfo(Client, simple));
				}
				else
				{
					new duration = GetRandomInt(10, 20);
					//LotteryEventDuration[2] = duration;
					SetConVarInt(FindConVar("god"), 1);
					CreateTimer(float(duration), LotteryGodMode, _, TIMER_FLAG_NO_MAPCHANGE);
					if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 发现了一堆生物专家留下的无敌药，使大家能无敌{green}%d{default}秒, 请尽快裸奔!", NameInfo(Client, colored), duration);
					PrintToServer("[人品] %s 发现了一堆生物专家留下的无敌药，使大家能无敌%d秒, 请尽快裸奔!", NameInfo(Client, simple), duration);
				}
			}
			case 26: // 获得很多手雷
			{
				new Num = GetRandomInt(3, 30);
				for(new x=1; x<=Num; x++)
				{
					CheatCommand(Client, "give", "pipe_bomb");
					CheatCommand(Client, "give", "vomitjar");
					CheatCommand(Client, "give", "molotov");
				}
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 在军火库发现一堆投掷品!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 在军火库发现一堆投掷品!", NameInfo(Client, simple));
			}
			case 27: // 召唤Hunter
			{
				new Num = GetRandomInt(6, 10);
				for(new x=1; x<=Num; x++)
					CheatCommand(Client, "z_spawn", "hunter");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 射中了Hunter巢穴而引来一堆{green}Hunter{default}!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 射中了Hunter巢穴而引来一堆Hunter!", NameInfo(Client, simple));
			}
			case 28: // 玩家加速
			{
				new Float:value = GetRandomFloat(1.1, 1.8);
				SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue")*value);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 在鞋店找到了暴走鞋, 现在跑得很快!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 在鞋店找到了暴走鞋, 现在跑得很快!", NameInfo(Client, simple));
			}
			case 29: // 玩家重力
			{
				new Float:value = GetRandomFloat(0.1, 0.5);
				SetEntityGravity(Client, GetEntityGravity(Client)*value);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 周围的重力变小了!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 周围的重力变小了!", NameInfo(Client, simple));
			}
			case 30: // 变成透明的
			{
				IsGlowClient[Client] = true;
				PerformGlow(Client, 3, 0, 1);
				SetEntityRenderMode(Client, RenderMode:3);
				SetEntityRenderColor(Client, 0, 0, 0, 0);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 变成透明的了,大家小心不要误伤啊!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 变成透明的了,大家小心不要误伤啊!", NameInfo(Client, simple));
			}
			case 31: // 变成TANK
			{
				SetEntityModel(Client, "models/infected/hulk.mdl");
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 在墙角画圈圈, 结果一不小心把自已变成了{green}Tank{default}!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 在墙角画圈圈, 结果一不小心把自已变成了Tank!", NameInfo(Client, simple));
			}
			case 32: // 变成蓝色
			{
				SetEntityRenderMode(Client, RenderMode:3);
				SetEntityRenderColor(Client, 255, 0, 0, 150);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 被油漆溅中了!", NameInfo(Client, colored));
				PrintToServer("[人品] %s 被油漆溅中了!", NameInfo(Client, simple));
			}
			case 33: // 赏钱
			{
				new Num = GetRandomInt(1, 20000);
				Cash[Client] += Num;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 在地上拾到了${green}%d{default}!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] 路边出现了一个发狂的有钱人，把 %d 扔到了 %s 的脚下！", Num, NameInfo(Client, simple));
			}
			case 34: // 扣钱
			{
				new Num = GetRandomInt(1, 10000);
				Cash[Client] -= Num;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 投资失败, 蚀了${green}%d{default}!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 投资失败，失去了 %d 金钱！", NameInfo(Client, simple), Num);
			}
			case 35: // 赏彩票
			{
				new Num = GetRandomInt(1, 5);
				Lottery[Client] += Num;
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] %s 获得额外{green}%d{default}张彩票!", NameInfo(Client, colored), Num);
				PrintToServer("[人品] %s 成功补充了 %d 的人品值！", NameInfo(Client, simple), Num);
			}
		}
		AdminDiceNum[Client] = -1;
	}
	else 
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "你身上没有彩票卷!");
		PrintToConsole(Client, "[人品] 你的人品余额不足...");
	}
	return Plugin_Handled;
}
public Action:RestoreSick(Handle:timer, any: Client)
{
	ServerCommand("sm_drug \"%N\" \"0\"", Client);
	return Plugin_Handled;
}
public Action:RestoreFade(Handle:timer, any: Client)
{
	PerformFade(Client, 0);
	return Plugin_Handled;
}
public Action:LotteryInfiniteAmmo(Handle:timer)
{
	if(GetConVarInt(FindConVar("sv_infinite_ammo")) == 1)
	{
		SetConVarInt(FindConVar("sv_infinite_ammo"), 0);
		if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {blue}无限子弹结束了!");
	}
	return Plugin_Handled;
}
public Action:LotteryWeakenCommonsHp(Handle:timer)
{
	if(GetConVarInt(FindConVar("z_health"))!=oldCommonHp)
	{
		SetConVarInt(FindConVar("z_health"), oldCommonHp);
		if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {blue}普感生命值回复全满!");
		LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
	}
	return Plugin_Handled;
}
public Action:LotteryGodMode(Handle:timer)
{
	if(GetConVarInt(FindConVar("god"))==1)
	{
		SetConVarInt(FindConVar("god"), 0);
		if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}[人品] {blue}无敌门事件结束了!");
	}
	return Plugin_Handled;
}
public PerformGlow(Client, Type, Range, Color)
{
	SetEntProp(Client, Prop_Send, "m_iGlowType", Type);
	SetEntProp(Client, Prop_Send, "m_nGlowRange", Range);
	SetEntProp(Client, Prop_Send, "m_glowColorOverride", Color);
}
	
/* 伺服器排名 */
public Action:MenuFunc_Rank(Client)
{
	new Handle:menu = CreatePanel();
	SetPanelTitle(menu, "伺服器排名");

	DrawPanelItem(menu, "等级排名");
	DrawPanelItem(menu, "金钱排名");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Rank, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}

new rank_id[MAXPLAYERS+1];
public MenuHandler_Rank(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		rank_id[Client] = param;
		#if ENABLE_SQL
		new Handle:data = CreateDataPack();
		WritePackCell(data, Client);
		WritePackCell(data, param);
		if(param == 1)
		{
			SQL_TQuery(g_hDataBase, T_Top10Query, "SELECT name, LV FROM l4d2UnitedRPGn ORDER BY LV DESC LIMIT 100;", data);
		}
		else if(param == 2)
		{
			SQL_TQuery(g_hDataBase, T_Top10Query, "SELECT name, CASH FROM l4d2UnitedRPGn ORDER BY CASH DESC LIMIT 100;", data);
		}
		#else
		MenuFunc_RankDisplay(Client);
		#endif
	}
}

public T_Top10Query(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client = ReadPackCell(data), mode = ReadPackCell(data);
	if(hndl == INVALID_HANDLE || !IsClientInGame(client)) return;
	new Handle:menu = CreateMenu(Menu_ShowRank100);
	new String:user_name[64];
	GetClientName(client, user_name, 64);
	
	new index = 0;
	while(SQL_FetchRow(hndl))
	{
		index++;
		decl String:name[64], String:line[128], String:info[64];
		SQL_FetchString(hndl, 0, name, sizeof(name));
		new count = SQL_FetchInt(hndl, 1);
		Format(info, 64, name);
		ReplaceString(name, sizeof(name), "{DQM}", "\"");//DQM Double quotation mark"
		ReplaceString(name, sizeof(name), "{SQM}", "\'");//SQM Single quotation mark
		ReplaceString(name, sizeof(name), "{SST}", "/*");//SST Slash Star
		ReplaceString(name, sizeof(name), "{STS}", "*/");//STS Star Slash
		ReplaceString(name, sizeof(name), "{DSL}", "//");//DSL Double Slash
		SQL_EscapeString(hndl, name, name, 64);
		Format(line, 128, "%s [%d]", name, count);
		AddMenuItem(menu, info, line);
		if(StrEqual(name, user_name))
		{
			switch(mode)
			{
				case 1: SetMenuTitle(menu, "等级排名 (你在第 %d 名)", index);
				case 2: SetMenuTitle(menu, "金钱排名 (你在第 %d 名)", index);
			}
		}
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_ShowRank100(Handle:menu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Cancel || action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action == MenuAction_Select)
	{
		decl String:user_name[128];
		GetMenuItem(menu, itemNum, user_name, 128);
		new Handle:data = CreateDataPack();
		WritePackString(data, user_name);
		WritePackCell(data, itemNum);
		WritePackCell(data, rank_id[client]);
		WritePackCell(data, client);
		Format(user_name, 128, "SELECT LV, CASH, JOB FORM l4d2UnitedRPGn WHERE name = '%s';", user_name);
		SQL_TQuery(g_hDataBase, T_ShowRankInfo, user_name, data);
	}
}

public T_ShowRankInfo(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE || !SQL_FetchRow(hndl)) return;
	
	new String:name[64], llv = 0, lcash = 0, ljob = 0, index = 0, mode = 0, client = 0;
	ReadPackString(data, name, 64);
	index = ReadPackCell(data);
	mode = ReadPackCell(data);
	client = ReadPackCell(data);
	llv = SQL_FetchInt(hndl, 0);
	lcash = SQL_FetchInt(hndl, 1);
	ljob = SQL_FetchInt(hndl, 2);
	
	new Handle:Panel = CreatePanel();
	decl String:job[32];
	decl String:line[256];
	switch(ljob)
	{
		case 0: Format(job, sizeof(job), "无业游民");
		case 1: Format(job, sizeof(job), "工程师");
		case 2: Format(job, sizeof(job), "士兵");
		case 3: Format(job, sizeof(job), "生物专家");
		case 4: Format(job, sizeof(job), "心灵医师");
		case 5: Format(job, sizeof(job), "膜法师");
	}
	switch(mode)
	{
		case 1: Format(line, sizeof(line), "等级排行榜 = TOP %d =", index);
		case 2: Format(line, sizeof(line), "金钱排行榜 = TOP %d =",index);
	}
	
	DrawPanelText(Panel, line);
	Format(line, sizeof(line), "玩家名字: %s", name);
	DrawPanelText(Panel, line);
	Format(line, sizeof(line), "职业: %s 等级: %d 现金:%d \n ", job, llv, lcash);
	DrawPanelText(Panel, line);
	DrawPanelItem(Panel, "返回");
	DrawPanelItem(Panel, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(Panel, client, Handler_GoBack, MENU_TIME_FOREVER);
}

public Action:MenuFunc_RankDisplay(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RankDisplay);
	if(rank_id[Client]==1)
		SetMenuTitle(menu, "你的等级: %d $", Lv[Client]);
	if(rank_id[Client]==2)
		SetMenuTitle(menu, "你的金钱: %d $", Cash[Client]);

	decl String:rankClient[100], String:rankname[100];

	for(new r=0; r<RankNo; r++)
	{
		if( StrEqual(LevelRankClient[r], "未知", false) ||
			StrEqual(CashRankClient[r], "未知", false)) continue;

		if(rank_id[Client]==1)
			Format(rankClient, sizeof(rankClient), "%s(等级:%d)", LevelRankClient[r], LevelRank[r]);
		if(rank_id[Client]==2)
			Format(rankClient, sizeof(rankClient), "%s(金钱:%d)", CashRankClient[r], CashRank[r]);

		Format(rankname, sizeof(rankname), "第%d名", r+1);
		AddMenuItem(menu, rankname, rankClient);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public MenuHandler_RankDisplay(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		for(new r=0; r<RankNo; r++)
		{
			if(itemNum == r)
			{
				decl String:Name[256];
				if(rank_id[Client]==1)
					Format(Name, sizeof(Name), "%s", LevelRankClient[r]);
				if(rank_id[Client]==2)
					Format(Name, sizeof(Name), "%s", CashRankClient[r]);

				KvJumpToKey(RPGSave, Name, true);
				new targetLv	= KvGetNum(RPGSave, "LV", 0);
				new targetCash	= KvGetNum(RPGSave, "EXP", 0);
				new targetJob	= KvGetNum(RPGSave, "Job", 0);
				KvGoBack(RPGSave);

				new Handle:Panel = CreatePanel();
				decl String:job[32];
				decl String:line[256];
				if(targetJob == 0)			Format(job, sizeof(job), "未转职");
				else if(targetJob == 1)	Format(job, sizeof(job), "工程师");
				else if(targetJob == 2)	Format(job, sizeof(job), "士兵");
				else if(targetJob == 3)	Format(job, sizeof(job), "生物专家");
				else if(targetJob == 4)	Format(job, sizeof(job), "心灵医师");

				if(rank_id[Client]==1)
					Format(line, sizeof(line), "等级排行榜 =TOP%d=", r+1);
				if(rank_id[Client]==2)
					Format(line, sizeof(line), "金钱排行榜 =TOP%d=", r+1);
				DrawPanelText(Panel, line);

				Format(line, sizeof(line), "玩家名字: %s", Name);
				DrawPanelText(Panel, line);

				Format(line, sizeof(line), "职业:%s 等级:Lv.%d 现金:%d$\n ", job, targetLv, targetCash);
				DrawPanelText(Panel, line);

				DrawPanelItem(Panel, "返回");
				DrawPanelItem(Panel, "Exit", ITEMDRAW_DISABLED);

				SendPanelToClient(Panel, Client, Handler_GoBack, MENU_TIME_FOREVER);

				CloseHandle(Panel);
			}
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}

public Handler_GoBack(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
		MenuFunc_Rank(param1);
}

/* 插件讯息 */
public Action:MenuFunc_Info(Client)
{
	new Handle:Panel = CreatePanel();
	SetPanelTitle(Panel, "插件讯息");

	DrawPanelItem(Panel, "密码讯息");
	DrawPanelItem(Panel, "作者讯息");
	DrawPanelItem(Panel, "返回RPG选单");
	DrawPanelItem(Panel, "Exit", ITEMDRAW_DISABLED);
	
	SendPanelToClient(Panel, Client, MenuHandler_Info, MENU_TIME_FOREVER);
	CloseHandle(Panel);
	return Plugin_Handled;
}
public MenuHandler_Info(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: MenuFunc_PasswordInfo(Client);
			case 2:
			{
				MenuFunc_RPGInfo(Client);
				MenuFunc_Info(Client);
			}
			case 3: MenuFunc_RPG(Client);
		}
	}
}
/* 密码资讯 */
public Action:Passwordinfo(Client, args)
{
	MenuFunc_PasswordInfo(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_PasswordInfo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();

	if(IsPasswordConfirm[Client])	Format(line, sizeof(line), "密码资讯 密码状态: 已正确输入 已设密码: %s", Password[Client]);
	else if(StrEqual(Password[Client], "", true))	Format(line, sizeof(line), "密码资讯 密码状态: 未启动");
	else if(!IsPasswordConfirm[Client])	Format(line, sizeof(line), "密码资讯 密码状态: 未输入");

	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明: 启动密码系统后别人便不能用你的名字读取你的记录");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "输入/启动密码指令: /rpgpw 密码");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "重设密码指令: /rpgresetpw 原密码 新密码");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注1: 密码最大长度為%d", PasswordLength);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注2: 密码不要用数字0开头, 会被略去");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注3: 不想每次进入游戏也输入一次:\n - 在left4dead2\\cfg\\autoexec.cfg(没发现请自行创建)加入setinfo unitedrpg 密码");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Passwordinfo, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}
public MenuHandler_Passwordinfo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
		MenuFunc_Info(Client);
}
/* 插件讯息 */
public Action:MenuFunc_RPGInfo(Client)
{
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, "\x03════════════════");
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, "\x04插件名称: \x05United RPG Version %s", PLUGIN_VERSION);
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, "\x03════════════════");
	return Plugin_Handled;
}
/* 队伍资讯 */
public Action:Menu_TeamInfo(Client, args)
{
	MenuFunc_TeamInfo(Client);
	return Plugin_Handled;
}

public Action:MenuFunc_TeamInfo(Client)
{	
	new Handle:downtownrun = FindConVar("l4d_maxplayers");
	new Handle:toolzrun = FindConVar("sv_maxplayers");
	new ServerMaxPlayer;
	new ServerPlayer;
	new SurvivorMaxPlayer = GetConVarInt(FindConVar("survivor_limit"));
	new InfectedMaxPlayer = GetConVarInt(FindConVar("z_max_player_zombies"));
	new SurvivorPlayer = 0;
	new InfectedPlayer = 0;
	new SpectatorPlayer = 0;
	new SurvivorLv = 0;
	new InfectedLv = 0;
	new SpectatorLv = 0;
	
	if (downtownrun != INVALID_HANDLE)
	{
		new downtown = GetConVarInt(FindConVar("l4d_maxplayers"));
		if (downtown >= 1)
		{
			ServerMaxPlayer = downtown;
		}
	}
	else if (toolzrun != INVALID_HANDLE)
	{
		new toolz = GetConVarInt(FindConVar("sv_maxplayers"));
		if (toolz >= 1)
		{
			ServerMaxPlayer = toolz;
		}
	}
	if (downtownrun == INVALID_HANDLE && toolzrun == INVALID_HANDLE)
	{
		ServerMaxPlayer = MaxClients;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			SurvivorLv += Lv[i];
			if(!IsFakeClient(i)) SurvivorPlayer++;
		}
		else if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			InfectedLv += Lv[i];
			if(!IsFakeClient(i)) InfectedPlayer++;
		}
		else if(IsClientInGame(i) && GetClientTeam(i) == 1)
		{
			SpectatorLv += Lv[i];
			if(!IsFakeClient(i)) SpectatorPlayer++;
		}
	}
	ServerPlayer = SurvivorPlayer + InfectedPlayer + SpectatorPlayer;
	new Handle:menu = CreateMenu(MenuHandler_TeamInfo);
	decl String:line[128];
	Format(line, sizeof(line), "队伍资讯 - 总共玩家数: %d/%d 幸存者: %d/%d 特殊感染者: %d/%d 观察者: %d", ServerPlayer, ServerMaxPlayer, SurvivorPlayer, SurvivorMaxPlayer, InfectedPlayer, InfectedMaxPlayer, SpectatorPlayer);
	SetMenuTitle(menu, line);
	Format(line, sizeof(line), "幸存者阵营(总等级: %d, 玩家数: %d/%d):", SurvivorLv, SurvivorPlayer, SurvivorMaxPlayer);
	AddMenuItem(menu, "option1", line);
	Format(line, sizeof(line), "特殊感染者阵营(总等级: %d, 玩家数: %d/%d):", InfectedLv, InfectedPlayer, InfectedMaxPlayer);
	AddMenuItem(menu, "option2", line);
	Format(line, sizeof(line), "观察者阵营(总等级: %d, 玩家数: %d):", SpectatorLv, SpectatorPlayer);
	AddMenuItem(menu, "option3", line);
	AddMenuItem(menu, "option4", "刷新");
	AddMenuItem(menu, "option5", "返回RPG选单");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_TeamInfo(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum)
		{
			case 0: MenuFunc_SurvivorInfo(Client);
			case 1: MenuFunc_InfectedInfo(Client);
			case 2: MenuFunc_SpectatorInfo(Client);
			case 3: MenuFunc_TeamInfo(Client);
			case 4: MenuFunc_RPG(Client);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
public Action:MenuFunc_SurvivorInfo(Client)
{	
	new SurvivorMaxPlayer = GetConVarInt(FindConVar("survivor_limit"));
	new SurvivorPlayer = 0;
	new SurvivorLv = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			SurvivorLv += Lv[i];
			if(!IsFakeClient(i)) SurvivorPlayer++;
		}
	}
	new Handle:TeamPanel = CreatePanel();
	decl String:line[128];
	Format(line, sizeof(line), "幸存者阵营(总等级: %d, 玩家数: %d/%d):", SurvivorLv, SurvivorPlayer, SurvivorMaxPlayer);
	SetPanelTitle(TeamPanel, line);
	new count = 1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			if(IsPlayerIncapped(i))
			{
				new hp = GetClientHealth(i);
				new maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
				Format(line, sizeof(line), "%d. %s (倒下) HP:%d/%d", count, NameInfo(i, simple), hp, maxhp);
			} else if(!IsPlayerAlive(i))
			{
				Format(line, sizeof(line), "%d. %s (死亡)", count, NameInfo(i, simple));
			} else
			{
				new hp = GetClientHealth(i);
				new maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
				Format(line, sizeof(line), "%d. %s HP:%d/%d", count, NameInfo(i, simple), hp, maxhp);
			}
			count++;
			DrawPanelText(TeamPanel, line);
		}
	}
	DrawPanelItem(TeamPanel, "刷新");
	DrawPanelItem(TeamPanel, "返回队伍资讯选单");
	DrawPanelItem(TeamPanel, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(TeamPanel, Client, MenuHandler_SurvivorInfo, MENU_TIME_FOREVER);
	CloseHandle(TeamPanel);
	return Plugin_Handled;
}
public MenuHandler_SurvivorInfo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: MenuFunc_SurvivorInfo(Client);
			case 2: MenuFunc_TeamInfo(Client);
		}
	}
}
public Action:MenuFunc_InfectedInfo(Client)
{	
	new InfectedMaxPlayer = GetConVarInt(FindConVar("z_max_player_zombies"));
	new InfectedPlayer = 0;
	new InfectedLv = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			InfectedLv += Lv[i];
			if(!IsFakeClient(i)) InfectedPlayer++;
		}
	}
	new Handle:TeamPanel = CreatePanel();
	decl String:line[128];
	Format(line, sizeof(line), "特殊感染者阵营(总等级: %d, 玩家数: %d/%d):", InfectedLv, InfectedPlayer, InfectedMaxPlayer);
	SetPanelTitle(TeamPanel, line);
	new count = 1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if(GetClientTeam(Client) == TEAM_INFECTED || GetClientTeam(Client) == 1)
			{
				decl String:classname[100];
				new class = GetEntProp(i, Prop_Send, "m_zombieClass");
				switch (class)
				{
					case 1: Format(classname, sizeof(classname), "Smoker");
					case 2: Format(classname, sizeof(classname), "Boomer");
					case 3: Format(classname, sizeof(classname), "Hunter");
					case 4: Format(classname, sizeof(classname), "Spitter");
					case 5: Format(classname, sizeof(classname), "Jockey");
					case 6: Format(classname, sizeof(classname), "Charger");
					case 8: Format(classname, sizeof(classname), "Tank");
				}
				if(IsPlayerGhost(i))
				{
					Format(line, sizeof(line), "%d. %s %s (灵魂)", count, NameInfo(i, simple), classname);
				} else if(IsPlayerAlive(i))
				{
					Format(line, sizeof(line), "%d. %s %s (死亡)", count, NameInfo(i, simple), classname);
				} else
				{
					new hp = GetClientHealth(i);
					new maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
					Format(line, sizeof(line), "%d. %s %s HP:%d/%d", count, NameInfo(i, simple), classname, hp, maxhp);
				}
			} else
			{
				Format(line, sizeof(line), "%d. %s", count, NameInfo(i, simple));
			}
			count++;
			DrawPanelText(TeamPanel, line);
		}
	}
	DrawPanelItem(TeamPanel, "刷新");
	DrawPanelItem(TeamPanel, "返回队伍资讯选单");
	DrawPanelItem(TeamPanel, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(TeamPanel, Client, MenuHandler_InfectedInfo, MENU_TIME_FOREVER);
	CloseHandle(TeamPanel);
	return Plugin_Handled;
}
public MenuHandler_InfectedInfo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: MenuFunc_InfectedInfo(Client);
			case 2: MenuFunc_TeamInfo(Client);
		}
	}
}
public Action:MenuFunc_SpectatorInfo(Client)
{	
	new SpectatorPlayer = 0;
	new SpectatorLv = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 1)
		{
			SpectatorLv += Lv[i];
			if(!IsFakeClient(i)) SpectatorPlayer++;
		}
	}
	new Handle:TeamPanel = CreatePanel();
	decl String:line[128];
	Format(line, sizeof(line), "观察者阵营(总等级: %d, 总玩家数: %d):", SpectatorLv, SpectatorPlayer);
	SetPanelTitle(TeamPanel, line);
	new count = 1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 1)
		{
			Format(line, sizeof(line), "%d. %s", count, NameInfo(i, simple));
			count++;
			DrawPanelText(TeamPanel, line);
		}
	}
	DrawPanelItem(TeamPanel, "刷新");
	DrawPanelItem(TeamPanel, "返回队伍资讯选单");
	DrawPanelItem(TeamPanel, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(TeamPanel, Client, MenuHandler_SpectatorInfo, MENU_TIME_FOREVER);
	CloseHandle(TeamPanel);
	return Plugin_Handled;
}
public MenuHandler_SpectatorInfo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: MenuFunc_SpectatorInfo(Client);
			case 2: MenuFunc_TeamInfo(Client);
		}
	}
}
/* 提示绑定 */
public Action:MenuFunc_BindKeys(Client)
{
	new Handle:Panel = CreatePanel();
	SetPanelTitle(Panel, "是否需要绑定服务器技能等快捷键?");
	DrawPanelItem(Panel, "需要");
	DrawPanelItem(Panel, "不需要");
	SendPanelToClient(Panel, Client, MenuHandler_BindKeys, MENU_TIME_FOREVER);
	CloseHandle(Panel);
	return Plugin_Handled;
}
public MenuHandler_BindKeys(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: BindMsg(Client), BindKeyFunction(Client);
			case 2: return;
		}
	}
}
public Action:BindMsg(Client)
{
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_1);
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_2);
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_3);
	if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_GENERAL);
	if(JD[Client] == 1) if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB1);
	else if(JD[Client] == 2) if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB2);
	else if(JD[Client] == 3) if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB3);
	else if(JD[Client] == 4)
	{
		if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB4);
		if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB4_1);
	}
	else if(JD[Client] == 5) if(GetConVarInt(g_hCvarShow))PrintToChat(Client, MSG_BIND_JOB5);
	return Plugin_Handled;
}
BindKeyFunction(Client)
{
	/*
	ClientCommand(Client, "bind KP_PLUS \"say /rpg\"");
	ClientCommand(Client, "bind k \"say /bag\"");
	ClientCommand(Client, "bind KP_MINUS \"say /buymenu\"");
	ClientCommand(Client, "bind KP_MULTIPLY \"say /useskill\"");
	ClientCommand(Client, "bind KP_SLASH \"say /teaminfo\"");
	*/
	ClientCommand(Client, "bind o \"say %sbuyequip\"", IsAdmin[Client] ? "/" : "!");
	ClientCommand(Client, "bind , \"say %sbuyammo1\"", IsAdmin[Client] ? "/" : "!");
	ClientCommand(Client, "bind b \"say %sbuy\"", IsAdmin[Client] ? "/" : "!");
	ClientCommand(Client, "bind i \"say %sheal\"", IsAdmin[Client] ? "/" : "!");
/*
	ClientCommand(Client, "bind KP_INS \"say /int\"");
	ClientCommand(Client, "bind KP_DEL \"say /end\"");
	ClientCommand(Client, "bind KP_END \"say /str\"");
	ClientCommand(Client, "bind KP_DOWNARROW \"say /agi\"");
	ClientCommand(Client, "bind KP_PGDN \"say /hea\"");

	ClientCommand(Client, "bind KP_LEFTARROW \"say /hl\"");
	ClientCommand(Client, "bind KP_5 \"say /eq\"");
	ClientCommand(Client, "bind KP_RIGHTARROW \"say /is\"");
	ClientCommand(Client, "bind KP_ENTER \"say /si\"");

	if(JD[Client] == 1){
		ClientCommand(Client, "bind KP_HOME \"say /am\"");
		ClientCommand(Client, "bind KP_UPARROW \"say /sc\"");
	} else if(JD[Client] == 2){
		ClientCommand(Client, "bind KP_HOME \"say /sp\"");
		ClientCommand(Client, "bind KP_UPARROW \"say /ia\"");
	} else if(JD[Client] == 3){
		ClientCommand(Client, "bind KP_HOME \"say /bs\"");
		ClientCommand(Client, "bind KP_UPARROW \"say /dr\"");
		ClientCommand(Client, "bind KP_PGUP \"say /ms\"");
	} else if(JD[Client] == 4){
		ClientCommand(Client, "bind KP_HOME \"say /ts\"");
		ClientCommand(Client, "bind KP_UPARROW \"say /at\"");
		ClientCommand(Client, "bind KP_PGUP \"say /tt\"");
		ClientCommand(Client, "bind KP_END \"say /hb\"");
	}
	 else if(JD[Client] == 5){
		ClientCommand(Client, "bind KP_HOME \"say /fb\"");
		ClientCommand(Client, "bind KP_UPARROW \"say /ib\"");
		ClientCommand(Client, "bind KP_PGUP \"say /cl\"");
	}
*/
}

//地震术震动效果
public Shake_Screen(Client, Float:Amplitude, Float:Duration, Float:Frequency)
{
	new Handle:Bfw;

	Bfw = StartMessageOne("Shake", Client, 1);
	BfWriteByte(Bfw, 0);
	BfWriteFloat(Bfw, Amplitude);
	BfWriteFloat(Bfw, Duration);
	BfWriteFloat(Bfw, Frequency);

	EndMessage();
}
SetWeaponSpeed()
{
	decl ent;

	for(new i = 0; i < WRQL; i++)
	{
		ent = WRQ[i];
		if(IsValidEdict(ent))
		{
			decl String:entclass[65];
			GetEdictClassname(ent, entclass, sizeof(entclass));
			if(StrContains(entclass, "weapon")>=0)
			{
				new Float:MAS = Multi[i];
				SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", MAS);
				new Float:ETime = GetGameTime();
				new Float:time = (GetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack") - ETime)/MAS;
				SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", time + ETime);
				time = (GetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack") - ETime)/MAS;
				SetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack", time + ETime);
				CreateTimer(time, NormalWeapSpeed, ent);
			}
		}
	}
}
public Action:NormalWeapSpeed(Handle:timer, any:ent)
{
	KillTimer(timer);
	timer = INVALID_HANDLE;

	if(IsValidEdict(ent))
	{
		decl String:entclass[65];
		GetEdictClassname(ent, entclass, sizeof(entclass));
		if(StrContains(entclass, "weapon")>=0)
		{
			SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", 1.0);
		}
	}
	return Plugin_Handled;
}
public Action:Event_WeaponFire(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));

	if(GetClientTeam(target) == TEAM_SURVIVORS && !IsFakeClient(target))
	{
		if(IsMeleeSpeedEnable[target])
		{
			new ent = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
			decl String:entclass[65];
			GetEdictClassname(ent, entclass, sizeof(entclass));

			if(ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")>=0)
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = MeleeSpeedEffect[target];
				WRQL++;
			}
		} else if(FireSpeedLv[target]>0)
		{
			new ent = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
			decl String:entclass[65];
			GetEdictClassname(ent, entclass, sizeof(entclass));

			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = FireSpeedEffect[target];
				WRQL++;
			}
		} else if(IsInfiniteAmmoEnable[target])
		{
			new ent = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
			decl String:entclass[65];
			GetEdictClassname(ent, entclass, sizeof(entclass));
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				SetEntProp(ent, Prop_Send, "m_iClip1", GetEntProp(ent, Prop_Send, "m_iClip1")+1);
			}
		}
	}
	return Plugin_Continue;
}
DelRobot(ent)
{
	if (ent > 0 && IsValidEntity(ent))
    {
		decl String:item[65];
		GetEdictClassname(ent, item, sizeof(item));
		if(StrContains(item, "weapon")>=0)
		{
			RemoveEdict(ent);
		}
    }
}
Release(controller, bool:del=true)
{
	new r=robot[controller];
	if(r>0)
	{
		robot[controller]=0;

		if(del)DelRobot(r);
	}
	if(robot_gamestart)
	{
		new count=0;
		for (new i = 1; i <= MaxClients; i++)
		{
			if(robot[i]>0)
			{
				count++;
			}
		}
		if(count==0) robot_gamestart = false;
	}
}

public Action:sm_robot(Client, const arg)
{
	if(!IsValidAliveClient(Client))
		return Plugin_Continue;

	if(robot[Client]>0)
	{
		if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "你已经有一个Robot");
		return Plugin_Handled;
	}
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(arg==i)	weapontype[Client]=i;
	}
	AddRobot(Client);
	return Plugin_Handled;
}

AddRobot(Client)
{
	bullet[Client]=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]);
	new Float:vAngles[3];
	new Float:vOrigin[3];
	new Float:pos[3];
	GetClientEyePosition(Client,vOrigin);
	GetClientEyeAngles(Client, vAngles);
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID,  RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
	}
	CloseHandle(trace);
	decl Float:v1[3];
	decl Float:v2[3];
	SubtractVectors(vOrigin, pos, v1);
	NormalizeVector(v1, v2);
	ScaleVector(v2, 50.0);
	AddVectors(pos, v2, v1);  // v1 explode taget
	new ent=0;
 	ent=CreateEntityByName(MODEL[weapontype[Client]]);
  	DispatchSpawn(ent);
  	TeleportEntity(ent, v1, NULL_VECTOR, NULL_VECTOR);

	SetEntityMoveType(ent, MOVETYPE_FLY);
	SIenemy[Client]=0;
	CIenemy[Client]=0;
	scantime[Client]=0.0;
	keybuffer[Client]=0;
	bullet[Client]=0;
	reloading[Client]=false;
	reloadtime[Client]=0.0;
	firetime[Client]=0.0;
	robot[Client]=ent;

	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(weapontype[Client]==i)
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green}%N{lightgreen}启动了[%s]Robot!", Client, WeaponName[i]);
			PrintToServer("[统计] %s启动了[%s]Robot!", NameInfo(Client, simple), WeaponName[i]);
		}
	}
	robot_gamestart = true;
}
new Float:lasttime=0.0;
new button;
new Float:robotpos[3];
new Float:robotvec[3];
new Float:Clienteyepos[3];
new Float:Clientangle[3];
new Float:enemypos[3];
new Float:infectedorigin[3];
new Float:infectedeyepos[3];
new Float:chargetime;
Do(Client, Float:currenttime, Float:duration)
{
	if(robot[Client]>0)
	{
		if (!IsValidEntity(robot[Client]) || !IsValidAliveClient(Client) || IsFakeClient(Client))
		{
			Release(Client);
		}
		else
		{
			botenerge[Client]+=duration;
			if(botenerge[Client]>robot_energy)
			{
				Release(Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChat(Client, "{blue}你的Robot已用尽能量了!");
				if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "你的Robot已用尽能量了!");
				return;
			}

			button=GetClientButtons(Client);
   		 	GetEntPropVector(robot[Client], Prop_Send, "m_vecOrigin", robotpos);

			if((button & IN_USE) && (button & IN_SPEED) && !(keybuffer[Client] & IN_USE))
			{
				Release(Client);
				if(GetConVarInt(g_hCvarShow))CPrintToChatAll("{green} %N {lightgreen}关闭了Robot", Client);
				return;
			}
			if(currenttime - scantime[Client]>robot_reactiontime)
			{
				scantime[Client]=currenttime;
				new ScanedEnemy = ScanEnemy(Client,robotpos);
				if(ScanedEnemy <= MaxClients)
				{
					SIenemy[Client]=ScanedEnemy;
				} else CIenemy[Client]=ScanedEnemy;
			}
			new targetok=false;
			
			if( CIenemy[Client]>0 && IsCommonInfected(CIenemy[Client]) && GetEntProp(CIenemy[Client], Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(CIenemy[Client], Prop_Send, "m_vecOrigin", enemypos);
				enemypos[2]+=40.0;
				SubtractVectors(enemypos, robotpos, robotangle[Client]);
				GetVectorAngles(robotangle[Client],robotangle[Client]);
				targetok=true;
			}
			else
			{
				CIenemy[Client]=0;
			}		
			if(!targetok)
			{
				if(SIenemy[Client]>0 && IsClientInGame(SIenemy[Client]) && IsPlayerAlive(SIenemy[Client]))
				{

					GetClientEyePosition(SIenemy[Client], infectedeyepos);
					GetClientAbsOrigin(SIenemy[Client], infectedorigin);
					enemypos[0]=infectedorigin[0]*0.4+infectedeyepos[0]*0.6;
					enemypos[1]=infectedorigin[1]*0.4+infectedeyepos[1]*0.6;
					enemypos[2]=infectedorigin[2]*0.4+infectedeyepos[2]*0.6;

					SubtractVectors(enemypos, robotpos, robotangle[Client]);
					GetVectorAngles(robotangle[Client],robotangle[Client]);
					targetok=true;
				}
				else
				{
					SIenemy[Client]=0;
				}
			}
			if(reloading[Client])
			{
				//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f", reloadtime[Client]);
				if(bullet[Client]>=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]) && currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
				{
					reloading[Client]=false;
					reloadtime[Client]=currenttime;
					EmitSoundToAll(SOUNDREADY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
					//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, " ");
				}
				else
				{
					if(currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
					{
						reloadtime[Client]=currenttime;
						bullet[Client]+=RoundToNearest(weaponloadcount[weapontype[Client]]*RobotAmmoEffect[Client]);
						EmitSoundToAll(SOUNDRELOAD, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
						//if(GetConVarInt(g_hCvarShow))PrintHintText(Client, "reloading %d", bullet[Client]);
					}
				}
			}
			if(!reloading[Client])
			{
				if(!targetok)
				{
					if(bullet[Client]<RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]))
					{
						reloading[Client]=true;
						reloadtime[Client]=0.0;
						if(!weaponloaddisrupt[weapontype[Client]])
						{
							bullet[Client]=0;
						}
					}
				}
			}
			chargetime=fireinterval[weapontype[Client]];
			if(!reloading[Client])
			{
				if(currenttime-firetime[Client]>chargetime)
				{

					if( targetok)
					{
						if(bullet[Client]>0)
						{
							bullet[Client]=bullet[Client]-1;

							FireBullet(Client, robot[Client], enemypos, robotpos);

							firetime[Client]=currenttime;
						 	reloading[Client]=false;
						}
						else
						{
							firetime[Client]=currenttime;
						 	EmitSoundToAll(SOUNDCLIPEMPTY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
							reloading[Client]=true;
							reloadtime[Client]=currenttime;
						}

					}

				}

			}
 			GetClientEyePosition(Client,  Clienteyepos);
			Clienteyepos[2]+=30.0;
			GetClientEyeAngles(Client, Clientangle);
			new Float:distance = GetVectorDistance(robotpos, Clienteyepos);
			if(distance>500.0)
			{
				TeleportEntity(robot[Client], Clienteyepos,  robotangle[Client],NULL_VECTOR);
			}
			else if(distance>100.0)
			{

				MakeVectorFromPoints( robotpos, Clienteyepos, robotvec);
				NormalizeVector(robotvec,robotvec);
				ScaleVector(robotvec, 5*distance);
				if (!targetok )
				{
					GetVectorAngles(robotvec, robotangle[Client]);
				}
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client],robotvec);
				walktime[Client]=currenttime;
			}
			else
			{
				robotvec[0]=robotvec[1]=robotvec[2]=0.0;
				if(!targetok && currenttime-firetime[Client]>4.0)robotangle[Client][1]+=5.0;
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client],robotvec);
			}
		 	keybuffer[Client]=button;
		}
	}
	else
	{
		botenerge[Client]=botenerge[Client]-duration*0.5;
		if(botenerge[Client]<0.0)botenerge[Client]=0.0;
	}
}
public OnGameFrame()
{
	if(WRQL>0)
	{
		SetWeaponSpeed();
		WRQL = 0;
	}

	if(!robot_gamestart)	return;
	new Float:currenttime = GetEngineTime();
	new Float:duration = currenttime-lasttime;
	if(duration<0.0 || duration>1.0)	duration=0.0;
	for (new Client = 1; Client <= MaxClients; Client++)
	{
		if(IsClientInGame(Client)) Do(Client, currenttime, duration);
	}
	lasttime = currenttime;
}
ScanEnemy(Client, Float:rpos[3] )
{
	decl Float:infectedpos[3];
	decl Float:vec[3];
	decl Float:angle[3];
	new Float:dis=0.0;
	new iMaxEntities = GetMaxEntities();
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if(IsCommonInfected(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", infectedpos);
			infectedpos[2]+=40.0;
			dis=GetVectorDistance(rpos, infectedpos) ;
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %N",dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndCI, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return iEntity;
				} else CloseHandle(trace);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
		{
			GetClientEyePosition(i, infectedpos);
			dis=GetVectorDistance(rpos, infectedpos) ;
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %N",dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return i;
				} else CloseHandle(trace);
			}
		}
	}
	return 0;
}
FireBullet(controller, bot, Float:infectedpos[3], Float:botorigin[3])
{
	decl Float:vAngles[3];
	decl Float:vAngles2[3];
	decl Float:pos[3];
	SubtractVectors(infectedpos, botorigin, infectedpos);
	GetVectorAngles(infectedpos, vAngles);
	new Float:arr1;
	new Float:arr2;
	arr1=0.0-bulletaccuracy[weapontype[controller]];
	arr2=bulletaccuracy[weapontype[controller]];
	decl Float:v1[3];
	decl Float:v2[3];
	//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %f",arr1, arr2);
	for(new c=0; c<weaponbulletpershot[weapontype[controller]];c++)
	{
		//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("fire");
		vAngles2[0]=vAngles[0]+GetRandomFloat(arr1, arr2);
		vAngles2[1]=vAngles[1]+GetRandomFloat(arr1, arr2);
		vAngles2[2]=vAngles[2]+GetRandomFloat(arr1, arr2);
		new hittarget=0;
		new Handle:trace = TR_TraceRayFilterEx(botorigin, vAngles2, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndSurvivor, bot);
		if(TR_DidHit(trace))
		{
			TR_GetEndPosition(pos, trace);
			hittarget=TR_GetEntityIndex( trace);
		}
		CloseHandle(trace);
		if((hittarget>0 && hittarget<=MaxClients) || IsCommonInfected(hittarget) || IsWitch(hittarget))
		{
			if(IsCommonInfected(hittarget) || IsWitch(hittarget))	DealDamage(controller,hittarget,RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]/(1.0 + StrEffect[controller] + EnergyEnhanceEffect_Attack[controller])),2,"robot_attack");
			else	DealDamage(controller,hittarget,RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]),2,"robot_attack");
			ShowParticle(pos, PARTICLE_BLOOD, 0.5);
		}
		SubtractVectors(botorigin, pos, v1);
		NormalizeVector(v1, v2);
		ScaleVector(v2, 36.0);
		SubtractVectors(botorigin, v2, infectedorigin);
		decl color[4];
		color[0] = 200;
		color[1] = 200;
		color[2] = 200;
		color[3] = 230;
		new Float:life=0.06;
		new Float:width1=0.01;
		new Float:width2=0.08;
		TE_SetupBeamPoints(infectedorigin, pos, g_BeamSprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
		TE_SendToAll();
		//EmitAmbientSound(SOUND[weapontype[controller]], vOrigin, controller, SNDLEVEL_RAIDSIREN);
		EmitSoundToAll(SOUND[weapontype[controller]], 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, botorigin, NULL_VECTOR, false, 0.0);
	}
}
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	return true;
}

public bool:TraceRayDontHitSelfAndLive(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity))
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndSurvivor(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity) && GetClientTeam(entity)==2)
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndCI(entity, mask, any:data)
{
	new iMaxEntities = GetMaxEntities();
	if(entity == data)
	{
		return false;
	}
	else if(entity>MaxClients && entity<=iMaxEntities)
	{
		return false;
	}
	return true;
}

public SkillEndranceQuality(target, attacker)
{
	decl Float:Pos[3], Float:tPos[3];

	if(IsPlayerIncapped(target))
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(i == attacker)
				continue;
			if(!IsClientInGame(i) || GetClientTeam(i) != 2)
				continue;

			GetClientAbsOrigin(attacker, Pos);
			GetClientAbsOrigin(i, tPos);
			if(GetVectorDistance(tPos, Pos) < GetConVarFloat(sm_lastboss_quake_radius))
			{
				EmitSoundToClient(i, SOUND_QUAKE);
				ScreenShake(i, 60.0);
				Smash(attacker, i, GetConVarFloat(sm_lastboss_quake_force), 1.0, 1.5);
			}
		}
	}
}

public SkillDreadClaw(target)
{
	visibility = GetConVarInt(sm_lastboss_dreadrate);
	CreateTimer(GetConVarFloat(sm_lastboss_dreadinterval), DreadTimer, target);
	EmitSoundToAll(SOUND_DCLAW, target);
	ScreenFade(target, 0, 0, 0, visibility, 0, 0);
}

public SkillGravityClaw(target)
{
	SetEntityGravity(target, 0.3);
	CreateTimer(GetConVarFloat(sm_lastboss_gravityinterval), GravityTimer, target);
	EmitSoundToAll(SOUND_GCLAW, target);
	ScreenFade(target, 0, 0, 100, 80, 4000, 1);
	ScreenShake(target, 30.0);
}

public SkillBurnClaw(target)
{
	new health = GetClientHealth(target);
	if(health > 0 && !IsPlayerIncapped(target))
	{
		SetEntityHealth(target, 1);
		new MaxHP = GetEntProp(target, Prop_Data, "m_iMaxHealth");
		if(health <= MaxHP)	SetEntPropFloat(target, Prop_Send, "m_healthBuffer", float(health)-1);
		else SetEntPropFloat(target, Prop_Send, "m_healthBuffer", float(MaxHP)-1);
	}
	EmitSoundToAll(SOUND_BCLAW, target);
	ScreenFade(target, 200, 0, 0, 150, 80, 1);
	ScreenShake(target, 50.0);
}

public SkillCometStrike(target, type)
{
	decl Float:pos[3];
	GetClientAbsOrigin(target, pos);

	if(type == MOLOTOV)
	{
		LittleFlower(pos, EXPLODE, target);
		LittleFlower(pos, MOLOTOV, target);
	}
	else if(type == EXPLODE)
	{
		LittleFlower(pos, EXPLODE, target);
	}
}

public SkillFlameGush(attacker, target)
{
	decl Float:pos[3];

	SkillBurnClaw(attacker);
	GetClientAbsOrigin(target, pos);
	LittleFlower(pos, MOLOTOV, target);
}

public SkillCallOfAbyss(client)
{
	/* Stop moving and prevent all damage for a while */
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsValidEntity(i) || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVORS)
			continue;
		EmitSoundToClient(i, SOUND_HOWL);
		ScreenShake(i, 20.0);
	}
	/* Panic event */
	if((form_prev[client] == FORMFOUR && GetConVarInt(sm_lastboss_enable_abyss) == 1) ||
		GetConVarInt(sm_lastboss_enable_abyss) == 2)
	{
		TriggerPanicEvent();
	}

	/* After 5sec, change form and start moving */
	CreateTimer(5.0, HowlTimer, client);
}

/******************************************************
*	Check Tank condition and update status
*******************************************************/
public Action:TankUpdate(Handle:timer, any:client)
{
	if(IsValidAliveClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		new health = GetClientHealth(client);

		/* First form */
		if(health > GetConVarInt(sm_lastboss_health_second))
		{
			if(form_prev[client] == DEAD)
				SetPrameter(client, FORMONE);
		}
		/* Second form */
		else if(GetConVarInt(sm_lastboss_health_second) >= health && health > GetConVarInt(sm_lastboss_health_third))
		{
			if(form_prev[client] <= FORMONE)
				SetPrameter(client, FORMTWO);
		}
		/* Third form */
		else if(GetConVarInt(sm_lastboss_health_third) >= health && health > GetConVarInt(sm_lastboss_health_forth))
		{
			/* Can't burn */
			ExtinguishEntity(client);
			if(form_prev[client] <= FORMTWO)
				SetPrameter(client, FORMTHREE);
		}
		/* Forth form */
		else if(GetConVarInt(sm_lastboss_health_forth) >= health && health > 0)
		{
			if(form_prev[client] <= FORMTHREE)
				SetPrameter(client, FORMFOUR);
		}
	} else
	{
		form_prev[client] = DEAD;
		KillTimer(TimerUpdate[client]);
		TimerUpdate[client] = INVALID_HANDLE;
	}
}

public SetPrameter(client, form_next)
{
	new Float:speed;
	decl String:color[32];

	form_prev[client] = form_next;

	if(form_next != FORMONE)
	{
		if(GetConVarInt(sm_lastboss_enable_abyss))
		{
			/* Skill:Call of Abyss (Howl and Trigger panic event) */
			SkillCallOfAbyss(client);
		}

		/* Skill:Reflesh (Extinguish if fired) */
		ExtinguishEntity(client);

		/* Show effect when form has changed */
		AttachParticle(client, PARTICLE_SPAWN, 3.0);
		for(new j = 1; j <= MaxClients; j++)
		{
			if(!IsClientInGame(j) || GetClientTeam(j) != 2)
				continue;
			EmitSoundToClient(j, SOUND_CHANGE);
			ScreenFade(j, 200, 200, 255, 255, 100, 1);
		}
	}

	/* Setup status of each form */
	if(form_next == FORMONE)
	{
		speed = GetConVarFloat(sm_lastboss_speed_first);
		strcopy(color, sizeof(color), "255 255 80");

		/* Skill:Fatal Mirror (Teleport near the survivor) */
		if(GetConVarInt(sm_lastboss_enable_warp))
		{
			GetSurvivorPositionTimer[client] = CreateTimer(3.0, GetSurvivorPosition, client, TIMER_REPEAT);
			FatalMirrorTimer[client] = CreateTimer(GetConVarFloat(sm_lastboss_warp_interval), FatalMirror, client, TIMER_REPEAT);
		}
	}
	else if(form_next == FORMTWO)
	{
		if(GetConVarInt(sm_lastboss_enable_announce))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_SECOND, client);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_SECOND2);
		}
		speed = GetConVarFloat(sm_lastboss_speed_second);
		strcopy(color, sizeof(color), "80 255 80");
	}
	else if(form_next == FORMTHREE)
	{
		if(GetConVarInt(sm_lastboss_enable_announce))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_THIRD, client);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_THIRD2);
		}
		speed = GetConVarFloat(sm_lastboss_speed_third);
		strcopy(color, sizeof(color), "80 80 255");
		SetEntityGravity(client, 1.0/speed);

		/* Attach particle */
		AttachParticleTimer[client] = CreateTimer(3.0, ParticleTimer, client, TIMER_REPEAT);

		/* Skill:Stealth Skin */
		if(GetConVarInt(sm_lastboss_enable_stealth))
			CreateTimer(GetConVarFloat(sm_lastboss_stealth_third), StealthTimer, client);
	}
	else if(form_next == FORMFOUR)
	{
		if(GetConVarInt(sm_lastboss_enable_announce))
		{
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_FORTH, client);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_FORTH2);
			if(GetConVarInt(g_hCvarShow))CPrintToChatAll(MESSAGE_FORTH3);
		}
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, _, _, _, 255);

		speed = GetConVarFloat(sm_lastboss_speed_forth);
		strcopy(color, sizeof(color), "255 80 80");
		SetEntityGravity(client, 1.0/speed);

		/* Ignite */
		IgniteEntity(client, 10.0);

		/* Skill:Mad Spring */
		if(GetConVarInt(sm_lastboss_enable_jump))
		{
			MadSpringTimer[client] = CreateTimer(GetConVarFloat(sm_lastboss_jumpinterval_forth), JumpingTimer, client, TIMER_REPEAT);
		}
	}

	/* Set speed */
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);

	/* Set color */
	SetEntityRenderMode(client, RenderMode:0);
	DispatchKeyValue(client, "rendercolor", color);
}

/******************************************************
*	Timer functions
*******************************************************/
public Action:ParticleTimer(Handle:timer, any:client)
{
	if(GetEntProp(client, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		if(form_prev[client] == FORMTHREE)
			AttachParticle(client, PARTICLE_THIRD, 3.0);
		else if(form_prev[client] == FORMFOUR)
			AttachParticle(client, PARTICLE_FORTH, 3.0);
	}
	else if(IsSuperInfectedEnable[client])
	{
		AttachParticle(client, SuperInfected_Particle, 3.0);
	}
	else
	{
		if(AttachParticleTimer[client] != INVALID_HANDLE)
		{
			KillTimer(AttachParticleTimer[client]);
			AttachParticleTimer[client] = INVALID_HANDLE;
		}
	}
}

public Action:GravityTimer(Handle:timer, any:target)
{
	if(IsValidClient(target))	SetEntityGravity(target, 1.0);
	else KillTimer(timer);
}

public Action:JumpingTimer(Handle:timer, any:client)
{
	if(form_prev[client] == FORMFOUR && client)
		AddVelocity(client, GetConVarFloat(sm_lastboss_jumpheight_forth));
	else
	{
		if(MadSpringTimer[client] != INVALID_HANDLE)
		{
			KillTimer(MadSpringTimer[client]);
			MadSpringTimer[client] = INVALID_HANDLE;
		}
	}
}

public Action:StealthTimer(Handle:timer, any:client)
{
	if(form_prev[client] == FORMTHREE && client)
	{
		alpharate = 255;
		Remove(client);
	}
}

public Action:DreadTimer(Handle:timer, any:target)
{
	visibility -= 8;
	if(visibility < 0)  visibility = 0;
	ScreenFade(target, 0, 0, 0, visibility, 0, 1);
	if(visibility <= 0)
	{
		visibility = 0;
		KillTimer(timer);
	}
}

public Action:HowlTimer(Handle:timer, any:clinet)
{
	if(IsValidEntity(clinet) && IsClientInGame(clinet) && IsPlayerAlive(clinet) && GetEntProp(clinet, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		SetEntityMoveType(clinet, MOVETYPE_WALK);
		SetEntProp(clinet, Prop_Data, "m_takedamage", 2, 1);
	} else
	{
		KillTimer(timer);
	}
}

public Action:WarpTimer(Handle:timer, any:clinet)
{
	if(IsValidEntity(clinet) && IsClientInGame(clinet) && IsPlayerAlive(clinet) && GetEntProp(clinet, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		decl Float:pos[3];

		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsValidEntity(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_SURVIVORS)
				continue;
			EmitSoundToClient(i, SOUND_WARP);
		}
		GetClientAbsOrigin(clinet, pos);
		ShowParticle(pos, PARTICLE_WARP, 2.0);
		TeleportEntity(clinet, ftlPos, NULL_VECTOR, NULL_VECTOR);
		ShowParticle(ftlPos, PARTICLE_WARP, 2.0);
		SetEntityMoveType(clinet, MOVETYPE_WALK);
		SetEntProp(clinet, Prop_Data, "m_takedamage", 2, 1);
	} else
	{
		KillTimer(timer);
	}
}

public Action:GetSurvivorPosition(Handle:timer, any:client)
{
	if(IsValidEntity(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		new count = 0;
		new idAlive[MAXPLAYERS+1];

		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsValidEntity(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_SURVIVORS)
				continue;
			idAlive[count] = i;
			count++;
		}
		if(count == 0) return;
		new clientNum = GetRandomInt(0, count-1);
		GetClientAbsOrigin(idAlive[clientNum], ftlPos);
	}
	else
	{
		if(GetSurvivorPositionTimer[client] != INVALID_HANDLE)
		{
			KillTimer(GetSurvivorPositionTimer[client]);
			GetSurvivorPositionTimer[client] = INVALID_HANDLE;
		}
	}
}

public Action:FatalMirror(Handle:timer, any:client)
{
	if(IsValidEntity(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == CLASS_TANK)
	{
		/* Stop moving and prevent all damage for a while */
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);

		/* Teleport to position that survivor exsited 2sec ago */
		CreateTimer(1.5, WarpTimer, client);
	}
	else
	{
		if(FatalMirrorTimer[client] != INVALID_HANDLE)
		{
			KillTimer(FatalMirrorTimer[client]);
			FatalMirrorTimer[client] = INVALID_HANDLE;
		}
	}
}

/******************************************************
*	Gimmick functions
*******************************************************/
public Action:Remove(ent)
{
	if(IsValidEntity(ent))
	{
		fadeoutTimer[ent] = CreateTimer(0.1, fadeout, ent, TIMER_REPEAT);
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	}
}

public Action:fadeout(Handle:Timer, any:ent)
{
	if(!IsValidEntity(ent) || form_prev[ent] != FORMTHREE)
	{
		if(fadeoutTimer[ent] != INVALID_HANDLE)
		{
			KillTimer(fadeoutTimer[ent]);
			fadeoutTimer[ent] = INVALID_HANDLE;
		}
		return;
	}
	alpharate -= 2;
	if (alpharate < 0)  alpharate = 0;
	SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	SetEntityRenderColor(ent, 80, 80, 255, alpharate);
	if(alpharate <= 0)
	{
		if(fadeoutTimer[ent] != INVALID_HANDLE)
		{
			KillTimer(fadeoutTimer[ent]);
			fadeoutTimer[ent] = INVALID_HANDLE;
		}
	}
}

public AddVelocity(client, Float:zSpeed)
{
	if(g_iVelocity == -1) return;

	new Float:vecVelocity[3];
	GetEntDataVector(client, g_iVelocity, vecVelocity);
	vecVelocity[2] += zSpeed;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

public LittleFlower(Float:pos[3], type, activator)
{
	/* Cause fire(type=0) or explosion(type=1) */
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", ENTITY_GASCAN);
		else
			/* explode */
			DispatchKeyValue(entity, "model", ENTITY_PROPANE);
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 0, 0, 0, 0);
		if(IsClientInGame(activator))
		{
			if(IsFakeClient(activator))	AcceptEntityInput(entity, "break", activator, activator);
			else
			{
				new Handle:pack;
				CreateDataTimer(0.1,Break,pack);
				WritePackCell(pack, entity);
				WritePackCell(pack, activator);
			}
		} else 	AcceptEntityInput(entity, "break", -1, -1);
	}
}

public Action:Break(Handle:timer, Handle:pack)
{
	new victim;
	new attacker;

	/* Set to the beginning and unpack it */
	ResetPack(pack);
	victim = ReadPackCell(pack);
	attacker = ReadPackCell(pack);
	DealDamage(attacker,victim,100,2);
}

public Smash(client, target, Float:power, Float:powHor, Float:powVec)
{
	/* Blow off target */
	decl Float:HeadingVector[3], Float:AimVector[3];
	GetClientEyeAngles(client, HeadingVector);

	AimVector[0] = FloatMul(Cosine(DegToRad(HeadingVector[1])),power * powHor);
	AimVector[1] = FloatMul(Sine(DegToRad(HeadingVector[1])),power * powHor);

	decl Float:current[3];
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", current);

	decl Float:resulting[3];
	resulting[0] = FloatAdd(current[0], AimVector[0]);
	resulting[1] = FloatAdd(current[1], AimVector[1]);
	resulting[2] = power * powVec;

	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, resulting);
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	if(IsClientInGame(target)){
		new Handle:msg = StartMessageOne("Fade", target);
		BfWriteShort(msg, 500);
		BfWriteShort(msg, duration);
		if (type == 0)
			BfWriteShort(msg, (0x0002 | 0x0008));
		else
			BfWriteShort(msg, (0x0001 | 0x0010));
		BfWriteByte(msg, red);
		BfWriteByte(msg, green);
		BfWriteByte(msg, blue);
		BfWriteByte(msg, alpha);
		EndMessage();
	}
}

public ScreenShake(target, Float:intensity)
{
	new Handle:msg;
	msg = StartMessageOne("Shake", target);

	BfWriteByte(msg, 0);
 	BfWriteFloat(msg, intensity);
 	BfWriteFloat(msg, 10.0);
 	BfWriteFloat(msg, 3.0);
	EndMessage();
}

public TriggerPanicEvent()
{
	new flager = GetAnyClient();
	if(flager == -1)  return;
	new flag = GetCommandFlags("director_force_panic_event");
	SetCommandFlags("director_force_panic_event", flag & ~FCVAR_CHEAT);
	FakeClientCommand(flager, "director_force_panic_event");
}

/******************************************************
*	Particle control functions
*******************************************************/
public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public AttachParticle(ent, String:particleType[], Float:time)
{
	decl String:tName[64];
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle) && IsValidEdict(ent))
	{
		new Float:pos[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName); 
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString(tName);
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
    if (IsValidEdict(particle) && IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}
}

/******************************************************
*	陨石
*******************************************************/
StartStarFall(Client)
{

	decl Float:pos[3];
	GetClientEyePosition(Client, pos);
	
	decl Float:angle[3];
	angle[0]=0.0+GetRandomFloat(-20.0, 20.0);
	angle[1]=0.0+GetRandomFloat(-20.0, 20.0);
	angle[2]=60.0;
	GetVectorAngles(angle, angle);
	decl Float:StarFallPos[3];

	new Handle:trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndLive, Client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(StarFallPos, trace);
	}
	CloseHandle(trace);
	
	new Float:StarFallHight=GetVectorDistance(pos, StarFallPos);
	if(StarFallHight >= MinStarFallHight)
	{
		if(StarFallHight > MaxStarFallHight)
		{
			StarFallHight = MaxStarFallHight;
		}
		decl Float:temp[3];
		MakeVectorFromPoints(pos, StarFallPos, temp);
		NormalizeVector(temp, temp);
		ScaleVector(temp, StarFallHight-50.0);
		AddVectors(pos, temp, StarFallPos);
		
		StarFallLeft[Client] = StarFallNumber;
		new Handle:h;
		CreateStarFallTimer[Client] = CreateDataTimer(0.5, CreateStarFall, h, TIMER_REPEAT);
		WritePackCell(h, Client);
		WritePackFloat(h, StarFallPos[0]);
		WritePackFloat(h, StarFallPos[1]);
		WritePackFloat(h, StarFallPos[2]);
	}
}

public Action:CreateStarFall(Handle:timer, Handle:h)
{
	ResetPack(h);
	decl Float:StarFallPos[3];
	new userid=ReadPackCell(h);
	StarFallPos[0]=ReadPackFloat(h);
	StarFallPos[1]=ReadPackFloat(h);
	StarFallPos[2]=ReadPackFloat(h);
	
	if(StarFallLeft[userid] > 0)
	{
		StarFallLeft[userid]--;
		new ent=CreateEntityByName("tank_rock");
		DispatchSpawn(ent); 
		decl Float:angle[3], Float:velocity[3];
		angle[0]=GetRandomFloat(-180.0, 180.0);
		angle[1]=GetRandomFloat(-180.0, 180.0);
		angle[2]=GetRandomFloat(-180.0, 180.0);
		velocity[0]=GetRandomFloat(-350.0, 350.0);
		velocity[1]=GetRandomFloat(-350.0, 350.0);
		velocity[2]=GetRandomFloat(-30.0, -10.0);
		TeleportEntity(ent, StarFallPos, angle, velocity);
		ActivateEntity(ent);
		AcceptEntityInput(ent, "Ignite");
		
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
		
		new Handle:newh;	
		CreateDataTimer(0.1, UpdateStarFall, newh, TIMER_REPEAT);
		WritePackCell(newh, userid);
		WritePackCell(newh, ent);
		WritePackFloat(newh, GetEngineTime());
		return Plugin_Continue;
	}
	else
	{
		CreateStarFallTimer[userid] = INVALID_HANDLE;
		return Plugin_Stop;
	}
}

public Action:UpdateStarFall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	
	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		new Float:time=ReadPackFloat(h);
		if(GetEngineTime() - time > FireIceBallLife || DistanceToHit(ent) < 200.0 || v < 50.0)
		{
			decl Float:pos[3];
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);
			DealDamageRange(Client, StarFallDamage, pos, StarFallRadius, 64, "star_fall");
			PointPush(Client, pos, StarFallPushForce, StarFallRadius, 0.5);
			return Plugin_Stop;	
		}
		return Plugin_Continue;	
	} return Plugin_Stop;	
}
public Float:DistanceToHit(ent)
{
	if (!(GetEntityFlags(ent) & (FL_ONGROUND)))
	{
		decl Handle:h_Trace, Float:entpos[3], Float:hitpos[3], Float:angle[3];
		
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", angle);
		GetVectorAngles(angle, angle);
		
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", entpos);
		h_Trace = TR_TraceRayFilterEx(entpos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, ent);

		if (TR_DidHit(h_Trace))
		{
			TR_GetEndPosition(hitpos, h_Trace);

			CloseHandle(h_Trace);

			return GetVectorDistance(entpos, hitpos);
		}

		CloseHandle(h_Trace);
	}

	return 0.0;
}

public DeleteEntity(any:ent, String:name[])
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, name, false))
		{
			AcceptEntityInput(ent, "Kill");
			RemoveEdict(ent);
		}
	}
}

/******************************************************
*	投石
*******************************************************/
public OnEntityCreated(entity, const String:classname[])
{
	if(!tankpower_gamestart)	return;
	if(StrEqual(classname, "tank_rock", true))
	{
		CreateTimer(0.1, StartRockTrace, entity);
	}
}

public Action:StartRockTrace(Handle:timer, any:ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);
		if(StrEqual(classname, "tank_rock", true))
		{
			new team=GetEntProp(ent, Prop_Send, "m_iTeamNum");
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("tag %d", team);
			if(team==3)
			{
				IgniteEntity(ent, 100.0);
				CreateTimer(tick, TraceMission, ent, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

Float:CalRay(Float:posmissile[3], Float:angle[3], Float:offset1, Float:offset2,   Float:force[3], ent, bool:printlaser=true)
{

	new Float:dis=GetRayDistance(posmissile, angle, ent) ;
	decl Float:ang[3];
	CopyVector(angle, ang);
	ang[0]+=offset1;
	ang[1]+=offset2;
	GetAngleVectors(ang, force, NULL_VECTOR,NULL_VECTOR);
	if(printlaser)ShowLarserByAngleAndDistance(posmissile, ang, dis);
	return dis;
}

public Action:TraceMission(Handle:timer, any:ent)
{
	decl String:g_classname[20];
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		GetEdictClassname(ent, g_classname, 128);
		if( StrEqual(g_classname, "grenade_launcher_projectile", true)  || StrEqual(g_classname, "molotov_projectile", true) || StrEqual(g_classname, "tank_rock", true))
		{
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll(" %d", gteam);

			decl Float:posmissile[3];
			decl Float:velocitymissile[3];

			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", posmissile);
			GetEntDataVector(ent, g_iVelocity, velocitymissile);
			//new Float:aaa=velocitymissile[2];


			new a=GetEntProp(ent, Prop_Send, "m_iTeamNum");
			new gteam;
			if(a==2)gteam=3;
			if(a==3)gteam=2;
			new enemy=GetEnemy(posmissile, velocitymissile, gteam);

			if(enemy>0)
			{

				decl Float:posenemy[3];
				GetClientEyePosition(enemy, posenemy);

				new Float:disenemy=GetVectorDistance(posmissile, posenemy);

				//new bool:visible=IfTwoPosVisible(posmissile, posenemy, ent);
				decl Float:missionangle[3];

				decl Float:velocityenemy[3], Float:vtrace[3];
				GetEntDataVector(enemy, g_iVelocity, velocityenemy);
				new Float:Venemy=GetVectorLength(velocityenemy);
				NormalizeVector(velocityenemy, velocityenemy);
				ScaleVector(velocityenemy,  Venemy* tick *GetConVarFloat(tankpower_predict_factor));
				AddVectors(posenemy, velocityenemy, posenemy);
				MakeVectorFromPoints(posmissile, posenemy, vtrace);

				//new Float:factor=GetConVarFloat(tankpower_trace_factor);
				//new Float:Vmissile=GetVectorLength(velocitymissile);
				//new Float:dis;

				////////////////////////////////////////////////////////////////////////////////////
				GetVectorAngles(velocitymissile, missionangle);

				//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("1 %f %f %f", posmissile[0], posmissile[1], posmissile[2]);

				decl Float:vleft[3], Float:vright[3], Float:vup[3], Float:vdown[3], Float:vfront[3];

				new bool:print=false;

				new Float:front=CalRay(posmissile, missionangle, 0.0, 0.0, vfront, ent, print);
				new Float:down=CalRay(posmissile, missionangle, 90.0, 0.0, vdown, ent, print);
				new Float:up=CalRay(posmissile, missionangle, -90.0, 0.0, vup, ent, print);
				new Float:left=CalRay(posmissile, missionangle, 0.0, 90.0, vleft, ent, print);
				new Float:right=CalRay(posmissile, missionangle, 0.0, -90.0, vright, ent, print);

				decl Float:vv1[3], Float:vv2[3], Float:vv3[3], Float:vv4[3], Float:vv5[3], Float:vv6[3], Float:vv7[3], Float:vv8[3];

				new Float:f1=CalRay(posmissile, missionangle, 30.0, 0.0, vv1, ent, print);
				new Float:f2=CalRay(posmissile, missionangle, 30.0, 45.0, vv2, ent, print);
				new Float:f3=CalRay(posmissile, missionangle, 0.0, 45.0, vv3, ent, print);
				new Float:f4=CalRay(posmissile, missionangle, -30.0, 45.0, vv4, ent, print);
				new Float:f5=CalRay(posmissile, missionangle, -30.0, 0.0, vv5, ent, print);
				new Float:f6=CalRay(posmissile, missionangle, -30.0, -45.0, vv6, ent, print);
				new Float:f7=CalRay(posmissile, missionangle, 0.0, -45.0, vv7, ent, print);
				new Float:f8=CalRay(posmissile, missionangle, 30.0, -45.0, vv8, ent, print);

				NormalizeVector(vfront,vfront);
				NormalizeVector(vup,vup);
				NormalizeVector(vdown,vdown);
				NormalizeVector(vleft,vleft);
				NormalizeVector(vright,vright);
				NormalizeVector( vtrace, vtrace);

				NormalizeVector(vv1,vv1);
				NormalizeVector(vv2,vv2);
				NormalizeVector(vv3,vv3);
				NormalizeVector(vv4,vv4);
				NormalizeVector(vv5,vv5);
				NormalizeVector(vv6,vv6);
				NormalizeVector(vv7,vv7);
				NormalizeVector(vv8,vv8);

				new Float:factor2=GetConVarFloat(tankpower_trace_factor);
				new Float:factor1=GetConVarFloat(tankpower_trace_obstacle);

				new Float:base=300.0;

				if(front>base) front=base;
				if(up>base) up=base;
				if(down>base) down=base;
				if(left>base) left=base;
				if(right>base) right=base;

				if(f1>base) f1=base;
				if(f2>base) f2=base;
				if(f3>base) f3=base;
				if(f4>base) f4=base;
				if(f5>base) f5=base;
				if(f6>base) f6=base;
				if(f7>base) f7=base;
				if(f8>base) f8=base;

				new Float:t;
				t=-1.0*factor1*(base-front)/base;
				ScaleVector( vfront, t);

				t=-1.0*factor1*(base-up)/base;
				ScaleVector( vup, t);

				t=-1.0*factor1*(base-down)/base;
				ScaleVector( vdown, t);

				t=-1.0*factor1*(base-left)/base;
				ScaleVector( vleft, t);

				t=-1.0*factor1*(base-right)/base;
				ScaleVector( vright, t);

				t=-1.0*factor1*(base-f1)/f1;
				ScaleVector( vv1, t);

				t=-1.0*factor1*(base-f2)/f2;
				ScaleVector( vv2, t);

				t=-1.0*factor1*(base-f3)/f3;
				ScaleVector( vv3, t);

				t=-1.0*factor1*(base-f4)/f4;
				ScaleVector( vv4, t);

				t=-1.0*factor1*(base-f5)/f5;
				ScaleVector( vv5, t);

				t=-1.0*factor1*(base-f6)/f6;
				ScaleVector( vv6, t);

				t=-1.0*factor1*(base-f7)/f7;
				ScaleVector( vv7, t);

				t=-1.0*factor1*(base-f8)/f8;
				ScaleVector( vv8, t);

				if(disenemy>=500.0)disenemy=500.0;
				t=1.0*factor2*(1000.0-disenemy)/500.0;

				ScaleVector( vtrace, t);
				ScaleVector( vtrace, t);

				AddVectors(vfront, vup, vfront);
				AddVectors(vfront, vdown, vfront);
				AddVectors(vfront, vleft, vfront);
				AddVectors(vfront, vright, vfront);
				AddVectors(vfront, vtrace, vfront);

				AddVectors(vfront, vv1, vfront);
				AddVectors(vfront, vv2, vfront);
				AddVectors(vfront, vv3, vfront);
				AddVectors(vfront, vv4, vfront);
				AddVectors(vfront, vv5, vfront);
				AddVectors(vfront, vv6, vfront);
				AddVectors(vfront, vv7, vfront);
				AddVectors(vfront, vv8, vfront);

				NormalizeVector(velocitymissile, velocitymissile);

				//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%f %f %f", tracevec[0], tracevec[1], tracevec[2]);
				AddVectors(velocitymissile, vfront, velocitymissile);

				NormalizeVector(velocitymissile,velocitymissile);

				SetEntityGravity(ent, 0.01);
				ScaleVector(velocitymissile,340.0);

				TeleportEntity(ent, NULL_VECTOR,  NULL_VECTOR,velocitymissile);

				//GetVectorAngles(velocitymissile, angle);
				//ShowLarserByAngle(posmissile, angle, ent, 1);

				//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%N %d", enemy, gteam);
			} else
			{
				SetEntityGravity(ent, 0.4);
			}

			return Plugin_Continue;
		}
		else
		{
			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}
}
CopyVector(Float:source[3], Float:target[3])
{
	target[0]=source[0];
	target[1]=source[1];
	target[2]=source[2];
}
GetRayHitPos(Float:pos[3], Float: angle[3], Float:hitpos[3], self, bool:nothitsurvivor=true)
{
	new Handle:trace ;
	new hit=0;
	if(nothitsurvivor)
	{
		trace= TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndSurvivor, self);
	}
	else
	{
		trace= TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, self);
	}
	if(TR_DidHit(trace))
	{

		TR_GetEndPosition(hitpos, trace);
		hit=TR_GetEntityIndex( trace);

	}
	CloseHandle(trace);
	return hit;
}
Float:GetRayDistance(Float:pos[3], Float: angle[3], self, bool:nothitsurvivor=true)
{
	decl Float:hitpos[3];
	GetRayHitPos(pos, angle,hitpos, self, nothitsurvivor);
	return GetVectorDistance( pos,  hitpos);
}
Float:GetAngle(Float:x1[3], Float:x2[3])
{
	return ArcCosine(GetVectorDotProduct(x1, x2)/(GetVectorLength(x1)*GetVectorLength(x2)));
}
GetEnemy(Float:pos[3], Float:vec[3], gteam)
{
	new Float:min=4.0;
	decl Float:pos2[3];
	new Float:t;
	new s=0;
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client)==gteam )
		{
			GetClientEyePosition(client, pos2);
			MakeVectorFromPoints(pos, pos2, pos2);
			t=GetAngle(vec, pos2);
			//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("%N %f", client, 360.0*t/3.1415926/2.0);
			if(t<=min)
			{
				min=t;
				s=client;
			}
		}
	}
	return s;
}
ShowLarserByAngleAndDistance(Float:pos1[3], Float:angle[3], Float:dis, flag=0, Float:life=0.06)
{

	new Float:pos2[3];
	GetAngleVectors(angle, pos2, NULL_VECTOR,NULL_VECTOR);
	NormalizeVector(pos2, pos2);
	ScaleVector(pos2, dis);
	AddVectors(pos1, pos2, pos2);
	ShowLarserByPos(pos1, pos2, flag, life);

}
ShowLarserByPos(Float:pos1[3], Float:pos2[3], flag=0, Float:life=0.06)
{
	decl color[4];
	if(flag==0)
	{
		color[0] = 200;
		color[1] = 200;
		color[2] = 200;
		color[3] = 230;
	}
	else
	{
		color[0] = 200;
		color[1] = 0;
		color[2] = 0;
		color[3] = 230;
	}

	new Float:width1=0.3;
	new Float:width2=0.3;

	TE_SetupBeamPoints(pos1, pos2, g_BeamSprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
	TE_SendToAll();
}
public OnEntityDestroyed(entity)
{
	/* 召唤尸消失 */
	decl String:classname[20];
	if(!IsValidEdict(entity))return;
	GetEdictClassname(entity, classname, 20);
	if(StrEqual(classname, "infected", true))
	{
		for(new i=1;i<=MaxClients;i++)
		{
			if(IsClientInGame(i))
			{
				if(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == i && GetClientTeam(i) == TEAM_INFECTED)
				{
					InfectedSummonCount[i] -= 1;
					SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", 0);
					if(SummonDisappearedCountTimer[i] == INVALID_HANDLE)	SummonDisappearedCountTimer[i] = CreateTimer(3.0, SummonDisappearedCountFunction, i);
					SummonDisappearedCount[i] ++;
					break;
				}
			}
		}
	} else if(StrEqual(classname, "witch", true))
	{
		for(new i=1;i<=MaxClients;i++)
		{
			if(IsClientInGame(i)){
				if(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == i && GetClientTeam(i) == TEAM_INFECTED)
				{
					InfectedSummonCount[i] -= 1;
					SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", 0);
					if(GetConVarInt(g_hCvarShow))CPrintToChat(i, MSG_SKILL_IS_WITCH_DISAPPEAR);
					break;
				}
			}
		}
	}

	if(!tankpower_gamestart)return;
	decl String:g_classname[20];
	GetEdictClassname(entity, g_classname, 20);
	//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("d %d %s ", entity, classname);
	if(StrEqual(g_classname, "tank_rock", true))
	{

		//new String:modelname[128];
		//GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, 128);
		//if(GetConVarInt(g_hCvarShow))CPrintToChatAll("grab : %s", modelname);

		new team=GetEntProp(entity, Prop_Send, "m_iTeamNum");
		if(team==2)
		{
			ExplodeRock(entity);
		}

	}
}
ExplodeRock(entity, Float:explodechance=100.0)
{
	new ent1 = 0;
	new ent2 = 0;
	new ent3 = 0;
	new Float:pos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	if(GetRandomFloat(0.0, 100.0)<explodechance)
	{
		new owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
		ent1=CreateEntityByName("prop_physics");

		DispatchKeyValue(ent1, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(ent1);
		TeleportEntity(ent1, pos, NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(ent1);
		SetEntityRenderMode(ent1, RenderMode:3);
		SetEntityRenderColor(ent1, 0, 0, 0, 0);
		AcceptEntityInput(ent1, "Ignite", owner, owner);

		new damage=GetConVarInt(w_damage_rock);
		new radius=GetConVarInt(w_radius_rock);
		new pushforce=GetConVarInt(w_pushforce_rock);

		new Handle:h=CreateDataPack();
		WritePackCell(h, owner);
		WritePackCell(h, ent1);
		WritePackCell(h, ent2);
		WritePackCell(h, ent3);
		WritePackCell(h, 0);
		WritePackCell(h, 1);
		WritePackCell(h, 0);

		WritePackFloat(h, pos[0]);
		WritePackFloat(h, pos[1]);
		WritePackFloat(h, pos[2]);


		WritePackCell(h, damage);
		WritePackCell(h, radius);
		WritePackCell(h, pushforce);

		Explode2(INVALID_HANDLE, h);

	}
}
public Action:Explode2(Handle:timer, Handle:h)
{
	ResetPack(h);
 	new userid=ReadPackCell(h);
	new ent1=ReadPackCell(h);
	new ent2=ReadPackCell(h);
	new ent3=ReadPackCell(h);
	new chaseent=ReadPackCell(h);
	new explode = ReadPackCell(h);
	new shotgun = ReadPackCell(h);
	decl Float:pos[3];
	pos[0]=ReadPackFloat(h);
	pos[1]=ReadPackFloat(h);
	pos[2]=ReadPackFloat(h);
	new damage=ReadPackCell(h);
	new radius=ReadPackCell(h);
	new force=ReadPackCell(h);
	CloseHandle(h);

 	if(ent1>0 && IsValidEntity(ent1))
	{
		decl Float:pos1[3];
		GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", pos1);
		if(shotgun==1)
		{
			pos[0]=pos1[0];
			pos[1]=pos1[1];
			pos[2]=pos1[2];
		}

		if(explode==1)
		{
 			//AcceptEntityInput(ent1, "break", userid);
			if(IsClientInGame(userid))
			{
				if(IsFakeClient(userid))	AcceptEntityInput(ent1, "break", userid, userid);
				else
				{
					new Handle:pack;
					CreateDataTimer(0.1,Break,pack);
					WritePackCell(pack, ent1);
					WritePackCell(pack, userid);
				}
			} else 	AcceptEntityInput(ent1, "break", -1, -1);
			RemoveEdict(ent1);
 			if(ent2>0 && IsValidEntity(ent2))
			{
				AcceptEntityInput(ent2, "break",  userid);
				RemoveEdict(ent2);
			}
 			if(ent3>0 && IsValidEntity(ent3))
			{
				AcceptEntityInput(ent3, "break",  userid);
				RemoveEdict(ent3);
			}

		}
		else
		{
 			AcceptEntityInput(ent1, "kill", userid);
			RemoveEdict(ent1);
 			if(ent2>0 && IsValidEntity(ent2))
			{
				AcceptEntityInput(ent2, "kill",  userid);
				RemoveEdict(ent2);
			}
 			if(ent3>0 && IsValidEntity(ent3))
			{
				AcceptEntityInput(ent3, "kill",  userid);
				RemoveEdict(ent3);
			}
		}
		if(chaseent!=0)
		{
			DeleteEntity(chaseent, "info_goal_infected_chase");
 		}
	}
	//if(explode==0)
	{
		ShowParticle(pos, "gas_explosion_pump", 3.0);
	}

	DealDamageRange(userid,damage,pos,radius,64,"rock_explode");

	new pushmode=GetConVarInt( w_pushforce_mode );

	if(pushmode==1 || pushmode==3)
	{
		PointPush(userid, pos, force, radius, 0.5);
	}
	if(pushmode==2 || pushmode==3)
	{
		PushAway(pos, float(force), float(radius));
	}

	return;
}


PushAway( Float:pos[3], Float:force, Float:radius)
{
	pos[2]-=100;
	new Float:limit=GetConVarFloat(w_pushforce_vlimit);
	new Float:normalfactor=GetConVarFloat(w_pushforce_factor);
	new Float:tankfactor=GetConVarFloat(w_pushforce_tankfactor);
	new Float:survivorfactor=GetConVarFloat(w_pushforce_survivorfactor);
	new Float:factor;
	new Float:r;


	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target))
			{
				decl Float:targetVector[3];
				GetClientEyePosition(target, targetVector);

				new Float:distance = GetVectorDistance(targetVector, pos);

				if(GetClientTeam(target)==2)
				{
					factor=survivorfactor;
					r=radius*0.8;
 				}
				else if(GetClientTeam(target)==3)
				{
 					new class = GetEntProp(target, Prop_Send, "m_zombieClass");
					if(class==5)
					{
						factor=tankfactor;
						r=radius*1.0;
					}
					else
					{
						factor=normalfactor;
						r=radius*1.3;
					}
				}

				if (distance < r )
				{
					decl Float:vector[3];

					MakeVectorFromPoints(pos, targetVector, vector);

					NormalizeVector(vector, vector);
					ScaleVector(vector, force);
					if(vector[2]<0.0)vector[2]=10.0;

					vector[0]*=factor;
					vector[1]*=factor;
					vector[2]*=factor;

					vector[0]*=factor;
					vector[1]*=factor;
					vector[2]*=factor;
					if(vector[0]>limit)
					{
						vector[0]=limit;
					}
					if(vector[1]>limit)
					{
						vector[1]=limit;
					}
					if(vector[2]>limit)
					{
						vector[2]=limit;
					}

					if(vector[0]<-limit)
					{
						vector[0]=-limit;
					}
					if(vector[1]<-limit)
					{
						vector[1]=-limit;
					}
					if(vector[2]<-limit)
					{
						vector[2]=-limit;
					}
 					TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vector);
				}
			}
		}
	}
}
/******************************************************
*	视觉效果Functions
*******************************************************/
public CreateLaserEffect(client, Float:targetpos[3], colRed, colGre, colBlu, alpha, Float:width, Float:duration, mode)
{
	decl color[4];
	color[0] = colRed;
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;

	if(mode == LASERMODE_NORMAL)
	{
		/* Show laser between user and impact position */
		decl Float:myPos[3];

		GetClientEyePosition(client, myPos);
		TE_SetupBeamPoints(myPos, targetpos, g_BeamSprite, 0, 0, 0, duration, width, width, 1, 0.0, color, 0);
		TE_SendToAll();
	}
	else if(mode == LASERMODE_VARTICAL)
	{
		/* Show laser like lightning bolt */
		decl Float:lchPos[3];

		for(new i = 0; i < 3; i++)
			lchPos[i] = targetpos[i];
		lchPos[2] += 1000;
		TE_SetupBeamPoints(lchPos, targetpos, g_BeamSprite, 0, 0, 0, duration, width, width, 1, 2.0, color, 0);
		TE_SendToAll();
		TE_SetupGlowSprite(lchPos, g_GlowSprite, 1.5, 2.8, 230);
		TE_SendToAll();
	}
}
/******************************************************
*	制造伤害Functions
*******************************************************/
DealDamage(attacker=0,victim,damage,dmg_type=0,String:weapon[]="")
{
	if(IsValidEdict(victim) && damage>0)
	{
		new String:victimid[64];
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new PointHurt = CreateEntityByName("point_hurt");
		if(PointHurt)
		{
			Format(victimid, 64, "victim%d", victim);
			DispatchKeyValue(victim,"targetname",victimid);
			DispatchKeyValue(PointHurt,"DamageTarget",victimid);
			DispatchKeyValueFloat(PointHurt,"Damage",float(damage));
			DispatchKeyValue(PointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(PointHurt,"classname",weapon);
			}
			DispatchSpawn(PointHurt);
			if(IsClientInGame(attacker))
			{
				AcceptEntityInput(PointHurt, "Hurt", attacker);
			} else 	AcceptEntityInput(PointHurt, "Hurt", -1);
			RemoveEdict(PointHurt);
		}
	}
}
// 创建一个范围伤害
DealDamageRange(attacker=0,damage,Float:center[3],radius,dmg_type=0,String:weapon[]="")
{
	if(damage>0)
	{
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);

		new PointHurt = CreateEntityByName("point_hurt");

		DispatchKeyValueFloat(PointHurt, "Damage", float(damage));
		DispatchKeyValue(PointHurt,"DamageType",dmg_type_str);
		DispatchKeyValueFloat(PointHurt, "DamageRadius", float(radius));
		DispatchKeyValue(PointHurt, "DamageDelay", "0.0");
		if(!StrEqual(weapon,""))
		{
			DispatchKeyValue(PointHurt,"classname",weapon);
		}
		DispatchSpawn(PointHurt);
		TeleportEntity(PointHurt, center, NULL_VECTOR, NULL_VECTOR);
		if(IsClientInGame(attacker))
		{
			AcceptEntityInput(PointHurt, "Hurt", attacker);
		} else 	AcceptEntityInput(PointHurt, "Hurt", -1);
		RemoveEdict(PointHurt);
	}
}
// 创建一个持续伤害
DealDamageRepeat(attacker=0,victim,damage,dmg_type=0,String:weapon[]="", Float:DamageDelay = 0.1, Float:Duration = 1.0)
{
	if(IsValidEdict(victim) && damage>0)
	{
		new String:victimid[64];
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new PointHurt = CreateEntityByName("point_hurt");
		if(PointHurt)
		{
			Format(victimid, 64, "victim%d", victim);
			DispatchKeyValue(victim,"targetname",victimid);
			DispatchKeyValue(PointHurt,"DamageTarget",victimid);
			DispatchKeyValueFloat(PointHurt,"Damage",float(damage));
			DispatchKeyValue(PointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(PointHurt,"classname",weapon);
			}
			DispatchKeyValueFloat(PointHurt,"DamageDelay",DamageDelay);
			DispatchSpawn(PointHurt);
			if(IsClientInGame(attacker))
			{
				AcceptEntityInput(PointHurt, "TurnOn", attacker);
			} else 	AcceptEntityInput(PointHurt, "TurnOn", -1);
			CreateTimer(Duration, RemoveDealDamageRepeat, PointHurt);
		}
	}
}
public Action:RemoveDealDamageRepeat(Handle:timer, any:PointHurt)
{
	KillTimer(timer);

	if (IsValidEdict(PointHurt))
	{
		RemoveEdict(PointHurt);
	}
	return Plugin_Handled;
}
/******************************************************
*	其他Functions
*******************************************************/
/* 读取任意一个玩家 */
GetAnyClient()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidEntity(i) && IsClientInGame(i))
			return i;
	}
	return -1;
}

/* 读取準心位置 */
public GetTracePosition(client, Float:TracePos[3])
{
	decl Float:clientPos[3], Float:clientAng[3];

	GetClientEyePosition(client, clientPos);
	GetClientEyeAngles(client, clientAng);
	new Handle:trace = TR_TraceRayFilterEx(clientPos, clientAng, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(TracePos, trace);
	}
	CloseHandle(trace);
}
public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

/* 爆炸效果 */
public PointPush(client, Float:center[3], force, radius, Float:duration)
{
	new push = CreateEntityByName("point_push");
	DispatchKeyValueFloat(push, "magnitude", float(force));
	DispatchKeyValueFloat(push, "radius", float(radius));
	DispatchKeyValueFloat(push, "inner_radius", float(force*2));
	DispatchKeyValue(push, "spawnflags", "24");
	DispatchSpawn(push);
	TeleportEntity(push, center, NULL_VECTOR, NULL_VECTOR);
	if(IsClientInGame(client))
	{
		AcceptEntityInput(push, "Enable", client, client);
	} else 	AcceptEntityInput(push, "Enable", -1, -1);
	CreateTimer(duration, DeletePushForce, push);
	
	new exPhys = CreateEntityByName("env_physexplosion");
	DispatchKeyValueFloat(exPhys, "radius", float(radius));
	DispatchKeyValueFloat(exPhys, "inner_radius", float(force));
	DispatchKeyValueFloat(exPhys, "magnitude", force*0.5);
	DispatchKeyValue(exPhys, "spawnflags", "19");
	DispatchSpawn(exPhys);
	TeleportEntity(exPhys, center, NULL_VECTOR, NULL_VECTOR);
	if(IsClientInGame(client))
	{
		AcceptEntityInput(exPhys, "Explode", client, client);
	} else 	AcceptEntityInput(exPhys, "Explode", -1, -1);
}
public Action:DeletePushForce(Handle:timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "point_push", false))
		{
			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill");
			RemoveEdict(ent);
		}
	}
}

stock bool:IsPlayerOnFire(Client)
{
	if (GetEntProp(Client, Prop_Data, "m_fFlags") & FL_ONFIRE)
		return true;
	return false;
}
stock bool:IsPlayerOnGround(Client)
{
	if (GetEntDataEnt2(Client, FindSendPropOffs("CBasePlayer", "m_hGroundEntity")) != -1)
		return true;
	return false;
}

stock bool:IsCommonInfected(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "infected");
	}
	return false;
}

stock bool:IsWitch(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "witch");
	}
	return false;
}

stock bool:IsPlayerGhost(Client)
{
	if (GetEntProp(Client, Prop_Send, "m_isGhost", 1) == 1)
		return true;
	return false;
}

stock bool:IsPlayerIncapped(Client)
{
	if (GetEntProp(Client, Prop_Send, "m_isIncapacitated")==1)
		return true;
	return false;
}

/* Execute Cheat Commads */
stock CheatCommand(Client, const String:command[], const String:arguments[])
{
    if (!Client) return;
    new admindata = GetUserFlagBits(Client);
    SetUserFlagBits(Client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(Client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(Client, admindata);
}

/* 获取所观察的玩家信息 */
public Action:GetObserverTargetInfo(Client)
{
	if(!IsValidEntity(Client) || !IsClientInGame(Client))
		return Plugin_Handled;
		
	new mode	= GetEntPropEnt(Client, Prop_Send, "m_iObserverMode"),
		target	= GetEntPropEnt(Client, Prop_Send, "m_hObserverTarget");
	
	//mode -1未定义 0自己 1刚死亡时 2未知 3未知 4第一视角 5第三视角 6自由视角
	if((mode!=4 && mode!=5) || target==-1)
		return Plugin_Handled;
	
	if(GetConVarInt(g_hCvarShow))PrintCenterText(Client, "正在观察: %s  误杀:%d次 转生:%d次", NameInfo(target, simple), KTCount[target], NewLifeCount[target]);
	return Plugin_Handled;
}

/* 转换队伍 */
ChangeTeam(client, targetteam)
{
	if (!IsClientInGame(client) || !IsClientConnected(client) || targetteam == 0)
	{
		return;
	}
	
	// If teams are the same ...
	if (GetClientTeam(client) == targetteam)
	{
		return;
	}
	
	// We check if target team is full...
	if (IsTeamFull(targetteam))
	{
		return;
	}
	
	// If player was on infected .... 
	if (GetClientTeam(client) == TEAM_INFECTED)
	{
		// ... and he wasn't a tank ...
		new iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (iClass != CLASS_TANK)
			ForcePlayerSuicide(client);	// we kill him
	}
	
	// If target is survivors .... we need to do a little trick ....
	if (targetteam == TEAM_SURVIVORS)
	{
		// first we switch to spectators ..
		ChangeClientTeam(client, TEAM_SPECTATORS); 
		
		// Search for an empty bot
		new bot = 1;
		while !(IsClientConnected(bot) && IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVORS) do bot++;
			
		// force player to spec humans
		SDKCall(fSHS, bot, client); 
		
		// force player to take over bot
		SDKCall(fTOB, client, true); 
	}
	else // We change it's team ...
	{
		ChangeClientTeam(client, targetteam);
	}
}
/* 检查队伍是否已满 */
bool:IsTeamFull(team)
{
	// Spectator's team is never full :P
	if (team == TEAM_SPECTATORS)
		return false;
	
	new SurvivorMaxPlayer = GetConVarInt(FindConVar("survivor_limit"));
	new InfectedMaxPlayer = GetConVarInt(FindConVar("z_max_player_zombies"));
	new max;
	new count;
	new i;
	
	// we count the players in the survivor's team
	if (team == TEAM_SURVIVORS)
	{
		max = SurvivorMaxPlayer;
		count = 0;
		for (i=1; i<=MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS)
				count++;
		}
	else if (team == TEAM_INFECTED) // we count the players in the infected's team
	{
		max = InfectedMaxPlayer;
		count = 0;
		for (i=1; i<=MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==TEAM_INFECTED)
				count++;
		}
	
	// If full ...
	if (count >= max)	return true;
	else	return false;
}
/*
public Action:TestFunction(Client, args)
{
	new Float:Pos[3];
	GetTracePosition(Client, Pos);
	new Float:eyePos[3];
	GetClientEyePosition(Client, eyePos);
	
	new exPhys = CreateEntityByName("env_physexplosion");
	DispatchKeyValue(exPhys, "radius", "500");
	DispatchKeyValue(exPhys, "inner_radius", "1000");
	DispatchKeyValue(exPhys, "magnitude", "500");
	DispatchKeyValue(exPhys, "spawnflags", "19");
	DispatchSpawn(exPhys);
	TeleportEntity(exPhys, Pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(exPhys, "Explode", Client, Client);
	
	new exEntity = CreateEntityByName("env_explosion");
	DispatchKeyValue(exEntity, "fireballsprite", "sprites/muzzleflash4.vmt");
	DispatchKeyValue(exEntity, "iMagnitude", "1000");
	DispatchKeyValue(exEntity, "iRadiusOverride", "1000");
	DispatchKeyValue(exEntity, "spawnflags", "829");
	DispatchSpawn(exEntity);
	TeleportEntity(exEntity, Pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(exEntity, "Explode", Client, Client);
	AcceptEntityInput(exEntity, "Kill");
	
	//StartStarFall(Client);

	decl Float:clientPos[3], Float:clientAng[3], Float:hitpos[3];
	GetClientEyePosition(Client, clientPos);
	GetClientEyeAngles(Client, clientAng);
	new Handle:trace = TR_TraceRayFilterEx(clientPos, clientAng, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, Client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(hitpos, trace);
		if(GetConVarInt(g_hCvarShow))PrintToChatAll("Distance = %.2f", GetVectorDistance(clientPos, hitpos));
	}
	CloseHandle(trace);
	
	return Plugin_Handled;
}*/

public Action:Timer_AutoAddSkillPoint(Handle:timer, any:client)
{
	RandomAddSkill(client);
}
// 自动给升级的玩家加点
public RandomAddSkill(client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}
	
	new tempRandom, LvUpSPs = GetConVarInt(LvUpSP), LvUpKSPs = GetConVarInt(LvUpKSP);
	// 自动分配属性点
	for(new i = 0; i <= LvUpSPs; i ++)
	{
		tempRandom = GetRandomInt(1, 5);
		switch(tempRandom)
		{
			case 1:	AddStrength(client, 0);
			case 2:	AddAgile(client, 0);
			case 3:	AddHealth(client, 0);
			case 4:	AddEndurance(client, 0);
			case 5:	AddIntelligence(client, 0);
		}
	}
	// 自动分配技能点
	for(new x = 0; x <= LvUpKSPs; x ++)
	{
		if(SkillPoint[client] > 0)
		{
			SkillPoint[client]--;
		}
		else
		{
			break;
		}
		/*
		if(JD[client] == 0)
		{
			tempRandom = GetRandomInt(1, 2);
			switch(tempRandom)
			{
				case 1: HealingLv[client]++;
				case 2: EndranceQualityLv[client]++;
			}
		}
		*/
		switch(JD[client])
		{
			case 0: // 没有任何职业
			{
				tempRandom = GetRandomInt(1, 6);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
				}
			}
			case 1: // 攻城狮
			{
				tempRandom = GetRandomInt(1, 9);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
					case 7: AmmoMakingLv[client]++;
					case 8: FireSpeedLv[client]++;
					case 9: SatelliteCannonLv[client]++;
				}
			}
			case 2: // 士兵
			{
				tempRandom = GetRandomInt(1, 9);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
					case 7: EnergyEnhanceLv[client]++;
					case 8: SprintLv[client]++;
					case 9: InfiniteAmmoLv[client]++;
				}
			}
			case 3: // 生物狗
			{
				tempRandom = GetRandomInt(1, 9);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
					case 7: BioShieldLv[client]++;
					case 8: DamageReflectLv[client]++;
					case 9: MeleeSpeedLv[client]++;
				}
			}
			case 4: // 医生
			{
				tempRandom = GetRandomInt(1, 10);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
					case 7: TeleportToSelectLv[client]++;
					case 8: AppointTeleportLv[client]++;
					case 9: TeleportTeamLv[client]++;
					case 10: HealingBallLv[client]++;
				}
			}
			case 5: // 魔法师
			{
				tempRandom = GetRandomInt(1, 9);
				switch(tempRandom)
				{
					case 1: HealingLv[client]++;
					case 2: EndranceQualityLv[client]++;
					case 3: HPRegenerationLv[client]++;
					case 4: SuperInfectedLv[client]++;
					case 5: InfectedSummonLv[client]++;
					case 6: SuperPounceLv[client]++;
					case 7: FireBallLv[client]++;
					case 8: IceBallLv[client]++;
					case 9: ChainLightningLv[client]++;
				}
			}
		}
	}
}

/******************************************************
*	EOF
*******************************************************/