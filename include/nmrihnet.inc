/*
* 这个文件是设置 NMRIH 的 NetProps 的
* 只是一个参考而已
*/

public FindNetProps()
{
	// 以下为玩家的属性
	new viewtarget = FindSendPropInfo("CNMRiH_Player", "m_viewtarget");				// 玩家瞄准的坐标
	new weapon = FindSendPropInfo("CNMRiH_Player", "m_hActiveWeapon");					// 玩家手持的武器
	new infection = FindSendPropInfo("CNMRiH_Player", "m_flInfectionDeathTime");		// 玩家受感染后剩余的死亡时间
	new infectiont = FindSendPropInfo("CNMRiH_Player", "m_flInfectionTime");			// 玩家感染后经过的时间
	new life = FindSendPropInfo("CNMRiH_Player", "m_lifeState");						// 玩家生命状态
	new bonus = FindSendPropInfo("CNMRiH_Player", "m_iBonusProgress");					// 玩家获取复活令牌的进展
	new speed = FindSendPropInfo("CNMRiH_Player", "m_flMaxspeed");					// 玩家的最大移动速度
	new observer = FindSendPropInfo("CNMRiH_Player", "m_hObserverTarget");				// 玩家正在观察的目标
	new place = FindSendPropInfo("CNMRiH_Player", "m_szLastPlaceName");				// 玩家最后到达的地方 (可用于显示玩家死在里)
	new hud = FindSendPropInfo("CNMRiH_Player", "m_iHideHUD");						// 玩家的 HUD 是否隐藏 (显示弹药数的那个)
	new duck = FindSendPropInfo("CNMRiH_Player", "m_bDucking");						// 玩家是否处于蹲下状态 (可用于蹲下恢复等)
	new fall = FindSendPropInfo("CNMRiH_Player", "m_flFallVelocity");					// 玩家的从高处掉落的速度 (修改可防止摔伤)
	new poisoned = FindSendPropInfo("CNMRiH_Player", "m_bPoisoned");					// 玩家是否中毒 (这啥)
	new step = FindSendPropInfo("CNMRiH_Player", "m_flStepSize");						// 玩家的步伐大小 (可以修改移动速度)
	new last = FindSendPropInfo("CNMRiH_Player", "m_hLastWeapon");					// 玩家的最后一把武器
	new ground = FindSendPropInfo("CNMRiH_Player", "m_hGroundEntity");					// 玩家的地面实体 (玩家站在什么东西上)
	new water = FindSendPropInfo("CNMRiH_Player", "m_nWaterLevel");					// 玩家的被水淹等级 (修改可防止淹死)
	new sequence = FindSendPropInfo("CNMRiH_Player", "m_nSequence");					// 玩家排在记分板的第几名
	new stamina = FindSendPropInfo("CNMRiH_Player", "m_flStamina");					// 玩家的体力状态 (没体力不能跑不能挥近战不能跳)
	new sprin = FindSendPropInfo("CNMRiH_Player", "m_bIsSprinting");					// 玩家是否在奔跑 (可以打断玩家跑步)
	new armor = FindSendPropInfo("CNMRiH_Player", "m_ArmorValue");					// 玩家的护甲值 (可以防僵尸抓么？)
	new ragdoll = FindSendPropInfo("CNMRiH_Player", "m_hRagdoll");					// 玩家的布娃娃实体 (这没啥用吧？)
	new walk = FindSendPropInfo("CNMRiH_Player", "m_bHasWalkieTalkie");				// 玩家是否有对讲机
	new sprint = FindSendPropInfo("CNMRiH_Player", "m_bSprintEnabled");				// 玩家是否可以奔跑
	new Grab = FindSendPropInfo("CNMRiH_Player", "m_bGrabbed");						// 玩家抓起的东西
	new Token = FindSendPropInfo("CNMRiH_Player", "m_iTokens");						// 玩家的复活令牌的数量
	new suicide = FindSendPropInfo("CNMRiH_Player", "_contemplatingSuicide");			// 玩家是否打算自杀 (把枪对准自己但还没有开枪)
	new respawnt = FindSendPropInfo("CNMRiH_Player", "_nextRespawnTime");				// 玩家下一次复活的时间
	
	// 武器的属性
	new name = FindSendPropInfo("CWeaponSDKBase", "m_iName");						// 武器的名字
	new clip1 = FindSendPropInfo("CWeaponSDKBase", "m_iClip1");						// 武器的弹夹 1
	new clip2 = FindSendPropInfo("CWeaponSDKBase", "m_iClip2");						// 武器的弹夹 2
	new ammotype1 = FindSendPropInfo("CWeaponSDKBase", "m_iPrimaryAmmoType");			// 武器的弹药类型 1
	new ammotype2 = FindSendPropInfo("CWeaponSDKBase", "m_iSecondaryAmmoType");			// 武器的弹药类型 1
	
}