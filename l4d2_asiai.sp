/*
 * L4D2特殊感染者BOTのプレイスタイルをカスタマイズする実験的なプラグイン
 *
 * 出現する特殊感染者BOTの2/3のだけ改変します
 *
 * キー入力をシミュレートすることでBOTを操作するため
 * システムはデフォルトのまま!!
 *
 *   addons/sourcemod/scripting
 * において
 *   ./compile.sh l4d2_asiai.sp
 * でコンパイル
 *   cp ./compiled/l4d2_asiai.smx ../plugins
 * でインストール
 *
 * ./srcds_run -nomaster -game left4dead2 +sv_gametypes "community1" +mp_gamemode "community1" +map "c2m1_highway community1"
 *
 * でSpecial Delivaryのサーバーを起動して接続すると違いが分かりやすいと思います
 */
#include <sourcemod>
#include <sdktools>
//#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "特感 AI 加强",
	author = "def075",
	description = "Advanced Special Infected AI",
	version = "0.4",
	url = ""
}

#define DEBUG_SPEED 0
#define DEBUG_EYE   0
#define DEBUG_KEY   0
#define DEBUG_ANGLE 0
#define DEBUG_VEL   0
#define DEBUG_AIM	0
#define DEBUG_POS	0

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_WITCH        7
#define ZC_TANK         8

#define MAXPLAYERS1     (MAXPLAYERS+1)

#define VEL_MAX          450.0
#define MOVESPEED_TICK     1.0
#define EYEANGLE_TICK      0.2
#define TEST_TICK          2.0
#define MOVESPEED_MAX     1000

enum AimTarget
{
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

public OnPluginStart()
{
	CreateConVar("asiai_version", "0.1", "Advanced Special Infected AI Version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	HookEvent("round_start", onRoundStart);
	HookEvent("player_spawn", onPlayerSpawn);
}
public OnMapStart()
{
	CreateTimer(MOVESPEED_TICK, timerMoveSpeed, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

new bool:g_ai_enable[MAXPLAYERS1];
public Action:onRoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for (new i = 0; i < MAXPLAYERS1; ++i) {
		g_ai_enable[i] = false;
	}
	initStatus();
}

public Action:onPlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isSpecialInfectedBot(client)) {
		
		/*
		// AI適用の有効無効を切り替える（タンクはこのフラグを無視する）
		if (GetRandomInt(0, 2) != 0) {
			// 2/3だけ改変
			g_ai_enable[client] = true;
		} else {
			// 1/3はデフォルトのAI
			g_ai_enable[client] = false;
		}
		*/
		
		g_ai_enable[client] = true;
	}
}

/* クライアントのキー入力処理
 *
 * ここでbotのキー入力を監視して書き換えることでbotをコントロールする
 *
 * buttons: 入力されたキー (enumはinclude/entity_prop_stock.inc参照)
 * vel: プレーヤーの速度？
 *      実プレーヤーだと
 *      [0]が↑↓入力で-450～+450.
 *      [1]が←→入力で-450～+450.
 *      botだと230
 *
 * angles: 視線の方向(マウスカーソルを向けている方向)？
 *      [0]がpitch(上下) -89～+89
 *      [1]がyaw(自分を中心に360度回転) -180～+180 
 *
 *      これを変更しても視線は変わらないがIN_FORWARDに対する移動方向が変わる
 *
 * impulse: impules command なぞ
 *
 * buttons, vel, anglesは書き換えてPlugin_Changedを返せば操作に反映される.
 * ただ処理順の問題があってたとえばIN_USEのビットを落としてUSE Keyが使えないようにすると
 * 武器は取れないけどドアは開くみたいな事が起こりえる.
 *
 * ゲームフレームから呼ばれるようなのでできるだけ軽い処理にする.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse,
							 Float:vel[3], Float:angles[3], &weapon)
{
	// 確認用...
#if (DEBUG_SPEED || DEBUG_KEY || DEBUG_EYE || DEBUG_ANGLE || DEBUG_VEL || DEBUG_AIM || DEBUG_POS)
	debugPrint(client, buttons, vel, angles);
#endif	
	// 特殊のBOTのみ処理
	if (isSpecialInfectedBot(client)) {
		// versusだとゴースト状態のBotがいるけど
		// Coopだとゴーストなしでいきなり沸いてる?
		// 今回ゴーストは考慮しない
		if (!isGhost(client)) {
			// 種類ごとの処理
			new zombie_class = getZombieClass(client);
			new Action:ret = Plugin_Continue;
			
			if (zombie_class == ZC_TANK) {
				ret = onTankRunCmd(client,  buttons, vel, angles);
			} else if (g_ai_enable[client]) {
				switch (zombie_class) {
				case ZC_SMOKER: { ret = onSmokerRunCmd(client, buttons, vel, angles); }
				case ZC_HUNTER: { ret = onHunterRunCmd(client, buttons, vel, angles); }
				case ZC_JOCKEY: { ret =  onJockeyRunCmd(client, buttons, vel, angles); }
				case ZC_BOOMER: { ret = onBoomerRunCmd(client, buttons, vel, angles); }
				case ZC_SPITTER: { ret = onSpitterRunCmd(client, buttons, vel, angles); }
				case ZC_CHARGER: { ret = onChargerRunCmd(client, buttons, vel, angles); }
				}
			}
			// 最近のメイン攻撃時間を保存
			if (buttons & IN_ATTACK) {
				updateSIAttackTime();
			}
			return ret;
		}
	}
	return Plugin_Continue;
}

/**
 * スモーカーの処理
 *
 * チャンスがあれば舌を飛ばす
 */
#define SMOKER_ATTACK_SCAN_DELAY     0.5 
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE           300.0
stock Action:onSmokerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	static Float:s_tounge_range = -1.0;
	new Action:ret = Plugin_Continue;

	if (s_tounge_range < 0.0) {
		// 舌が届く範囲
		s_tounge_range = GetConVarFloat(FindConVar("tongue_range"));
	}
	if (buttons & IN_ATTACK) {
		// botのトリガーはそのまま処理する
	} else if (delayExpired(client, 0, SMOKER_ATTACK_SCAN_DELAY)
			   && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		delayStart(client, 0);
		/* 他のSIが攻撃しているかターゲットからAIMを受けている場合に
		   舌が届く距離にターゲットがいたら即攻撃する */

		// botがターゲットしている生存者を取得
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
			// 生存者で見えてたら
			new Float:target_pos[3];
			new Float:self_pos[3];
			new Float:dist;
			
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			// ターゲットとの距離を計算
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < SMOKER_MELEE_RANGE) {
				// ターゲットと近すぎる場合もうダメなので即攻撃する
				buttons |= IN_ATTACK|IN_ATTACK2; // 舌がないことがあるので殴りも入れる
				ret = Plugin_Changed;
			} else if (dist < s_tounge_range) {
				// 舌が届く範囲にターゲットがいる場合
				if (GetGameTime() - getSIAttackTime() < SMOKER_ATTACK_TOGETHER_LIMIT) {
					// 最近SIが攻撃してたらチャンスっぽいので即攻撃する
					buttons |= IN_ATTACK;
					ret = Plugin_Changed;
				} else {
					new target_aim = GetClientAimTarget(target, true);
					if (target_aim == client) {
						// ターゲットがこっちにAIMを向けてたら即攻撃する
						buttons |= IN_ATTACK;
						ret = Plugin_Changed;
					}
				}
				// 他はbotに任せる
			}
		}
	}
	
	return ret;
}

/**
 * ジョッキーの処理
 *
 * たまにジャンプするのと生存者の近くで荒ぶる
 */
#define JOCKEY_JUMP_DELAY 2.0
#define JOCKEY_JUMP_NEAR_DELAY 0.1
#define JOCKEY_JUMP_NEAR_RANGE 400.0 // この範囲に生存者がいたら荒ぶる
#define JOCKEY_JUMP_MIN_SPEED 130.0
stock Action:onJockeyRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{

	if (
		// 速度がついてて↑入力があり地面の上で
		// ハシゴ中じゃないときはたまにジャンプする
		// さらに生存者がかなり近くにいるときは飛び跳ねまくる
		(getMoveSpeed(client)  > JOCKEY_JUMP_MIN_SPEED
		 && (buttons & IN_FORWARD)
		 && (GetEntityFlags(client) & FL_ONGROUND)
		 && GetEntityMoveType(client) != MOVETYPE_LADDER)
		&& ((nearestSurvivorDistance(client) < JOCKEY_JUMP_NEAR_RANGE
			 && delayExpired(client, 0, JOCKEY_JUMP_NEAR_DELAY))
			|| delayExpired(client, 0, JOCKEY_JUMP_DELAY)))
	{
		// ジャンプと飛び乗り(PrimaryAttack)を交互に繰り返す
		vel[0] = VEL_MAX;
		if (getState(client, 0) == IN_JUMP) {
			// 上のほうに飛び乗る動きをする
			// anglesを変更しても視線が動かないので
			// TeleportEntityで視線を変更する

			// 上方向(ある程度ランダム)に視線を変更
			if (angles[2] == 0.0) {
				angles = angles;
				angles[0] = GetRandomFloat(-50.0,-10.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			// 飛び乗り
			buttons |= IN_ATTACK;
			setState(client, 0, IN_ATTACK);
		} else {
			// 通常ジャンプ
			// 殴りジャンプ
			// ダッグジャンプ // しゃがみ押しっぱなしにしないとできないかも？
			// をランダムに使う
			if (angles[2] == 0.0) {
				angles[0] = GetRandomFloat(-10.0, 0.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			buttons |= IN_JUMP;
			switch (GetRandomInt(0, 2)) {
			case 0: { buttons |= IN_DUCK; }
			case 1: { buttons |= IN_ATTACK2; }
			}
			setState(client, 0, IN_JUMP);
		}
		delayStart(client, 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

/**
 * チャージャーの処理
 *
 * なぐりまくる
 */
#define CHARGER_MELEE_DELAY     0.2
#define CHARGER_MELEE_RANGE 400.0
stock Action:onChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	// ハシゴ中以外で生存者近くにいるとき
	if (!(buttons & IN_ATTACK)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER
		&& (GetEntityFlags(client) & FL_ONGROUND)
		&& delayExpired(client, 0, CHARGER_MELEE_DELAY)
		&& nearestSurvivorDistance(client) < CHARGER_MELEE_RANGE)
	{
		// 適当な間隔で殴りをいれる
		delayStart(client, 0);
		buttons |= IN_ATTACK2;
		return Plugin_Changed;
	}
	return Plugin_Continue;	
}

/**
 * ハンターの処理
 *
 * 次のようにする
 * - 最初の飛び掛りのトリガーはBOTが自発的に行う
 * - BOTが飛び掛ったら一定の間攻撃モードをONにする
 * - 攻撃モードがONの場合さまざまな角度で連続的に飛びまくる動きと
 *   ターゲットを狙った飛びかかり（デフォルトの動き）を混ぜて飛び回る
 *
 * あと hunter_pounce_ready_range というCVARをを2000くらいに変更すると
 * 遠くにいるときでもしゃがむようになるの変更するとよい
 *
 * あと撃たれたときに後ろに飛んで逃げるっぽい動きに移行するのをやめさせたい
 */
#define HUNTER_FLY_DELAY             0.2
#define HUNTER_ATTACK_TIME           4.0
#define HUNTER_COOLDOWN_DELAY        2.0
#define HUNTER_FALL_DELAY            0.2
#define HUNTER_STATE_FLY_TYPE        0
#define HUNTER_STATE_FALL_FLAG       1
#define HUNTER_STATE_FLY_FLAG        2

#define HUNTER_REPEAT_SPEED          4
#define HUNTER_NEAR_RANGE          1000

stock Action:onHunterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	new Action:ret = Plugin_Continue;
	new bool:internal_trigger = false;
	
	if (!delayExpired(client, 1, HUNTER_ATTACK_TIME)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		// 攻撃モード中はDUCK押しっぱなしかつATTACK連打する
		buttons |= IN_DUCK;
		if (GetRandomInt(0, HUNTER_REPEAT_SPEED) == 0) {
			// ATTACKは離さないと効果がないので
			// ランダムな間隔で押した状態を作る
			buttons |= IN_ATTACK;
			internal_trigger = true;
		}
		ret = Plugin_Changed;
	}
	if (!(GetEntityFlags(client) & FL_ONGROUND)
		&& getState(client, HUNTER_STATE_FLY_FLAG) == 0)
	{
		// ジャンプ開始
		delayStart(client, 2);
		setState(client, HUNTER_STATE_FALL_FLAG, 0);
		setState(client, HUNTER_STATE_FLY_FLAG, 1);
	} else if (!(GetEntityFlags(client) & FL_ONGROUND)) {
		// 空中にいる場合
		if (getState(client, HUNTER_STATE_FLY_TYPE) == IN_FORWARD) {
			// 角度を変えて飛ぶときは空中で↑入力を入れる
			buttons |= IN_FORWARD;
			vel[0] = VEL_MAX;
			if (getState(client, HUNTER_STATE_FALL_FLAG) == 0
				&& delayExpired(client, 2, HUNTER_FALL_DELAY))
			{
				// 飛び始めてから少しして視線を変える
				if (angles[2] == 0.0) {
					angles[0] = GetRandomFloat(-50.0, 20.0);
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				setState(client, HUNTER_STATE_FALL_FLAG, 1);
			}
			ret = Plugin_Changed;
		}
	} else if (getState(client, 2) == 1) {
		// 着地
	} else {
		setState(client, HUNTER_STATE_FLY_FLAG, 0);
	}
	if (delayExpired(client, 0, HUNTER_FLY_DELAY)
		&& (buttons & IN_ATTACK)
		&& (GetEntityFlags(client) & FL_ONGROUND))
	{
		// 飛びかかり開始
		new Float:dist = nearestSurvivorDistance(client);
		
		delayStart(client, 0);
		if (!internal_trigger
			&& !(buttons & IN_BACK)
			&& dist < HUNTER_NEAR_RANGE
			&& delayExpired(client, 1, HUNTER_ATTACK_TIME + HUNTER_COOLDOWN_DELAY))
		{
			// BOTがトリガーを入れて生存者に近い場合は攻撃モードに移行する
			delayStart(client, 1); // このdelayが切れるまで攻撃モード
		}
		// ランダムな飛び方と
		// ターゲットを狙ったデフォルトの飛び方をランダムに繰り返す.
		if (GetRandomInt(0, 1) == 0) {
			// ランダムで飛ぶ
			if (dist < HUNTER_NEAR_RANGE) {
				if (angles[2] == 0.0) {
					if (GetRandomInt(0, 4) == 0) {
						// 高めに飛ぶ 1/5
						angles[0] = GetRandomFloat(-50.0, -30.0);
					} else {
						// 低めに飛ぶ
						angles[0] = GetRandomFloat(-10.0, 20.0);
					}
					// 視線を変更
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				// 空中で前入力を入れるフラグをセット
				setState(client, HUNTER_STATE_FLY_TYPE, IN_FORWARD);
			} else {
				// デフォルトの飛び掛り
				setState(client, HUNTER_STATE_FLY_TYPE, 0);
			}
		} else {
			// デフォルトの飛び掛り
			setState(client, HUNTER_STATE_FLY_TYPE, 0);
		}
		ret = Plugin_Changed;
	}
	
	return ret;	
}

/**
 * ブーマーの処理
 * 
 * Coopブーマーは積極的にゲロを吐かないというか
 * ゲロのリチャージができていないことがある？（要確認）
 * でウロウロしているだけなので
 * ゲロがかけれそうなら即かけるようにする
 */
#define BOMMER_SCAN_DELAY 0.5
stock Action:onBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	static Float:s_vomit_range = -1.0;
	if (s_vomit_range < 0.0) {
		// ゲロの飛距離
		s_vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));
	}
	if (buttons & IN_ATTACK) {
		// BOTのトリガーは無視する
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	} else if (delayExpired(client, 0, BOMMER_SCAN_DELAY)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		delayStart(client, 0);
		// ゲロが届く距離にターゲットがいればとにかくかける
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
			new Float:target_pos[3];
			new Float:self_pos[3];
			new Float:dist;
			
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < s_vomit_range) {
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;	
}

/**
 * スピッターの処理
 * 
 * スピッターはなんか特に意味なくジャンプしたりする
 */
#define SPITTER_RUN 200.0
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.1
stock Action:onSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (getMoveSpeed(client) > SPITTER_RUN
		&& delayExpired(client, 0, SPITTER_JUMP_DELAY)
		&& (GetEntityFlags(client) & FL_ONGROUND))
	{
		// 逃げてるっぽいときジャンプする
		delayStart(client, 0);
		buttons |= IN_JUMP;
		if (getState(client, 0) == IN_MOVERIGHT) {
			setState(client, 0, IN_MOVELEFT);
			buttons |= IN_MOVERIGHT;
			vel[1] = VEL_MAX;
		} else {
			setState(client, 0, IN_MOVERIGHT);
			buttons |= IN_MOVELEFT;
			vel[1] = -VEL_MAX;
		}
		return Plugin_Changed;
	}
	
	if (buttons & IN_ATTACK) {
		// 吐くときついでにジャンプする
		if (delayExpired(client, 1, SPITTER_SPIT_DELAY)) {
			delayStart(client, 1);
			buttons |= IN_JUMP;
			return Plugin_Changed;
			// 吐く角度を変えたいけど
			// 視線を真上にteleportさせても横に吐いてて
			// 変更できなかった TODO
		}
	}
	
	return Plugin_Continue;
}

/**
 * タンクの処理
 *
 * - 近くに生存者がいればとにかく殴る
 * - 走っているときに直線的なジャンプで加速する
 * - 岩投げ中にターゲットしている人が見えなくなったらターゲットを変更する
 *   （投げる瞬間にターゲットが変わるとモーションと違う軌道に投げる）
 */
#define TANK_MELEE_SCAN_DELAY 0.3
#define TANK_BHOP_SCAN_DELAY  2.0
#define TANK_BHOP_TIME        1.0
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25
stock Action:onTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	static Float:s_tank_attack_range = -1.0;
	static Float:s_tank_speed = -1.0;
	
	if (s_tank_attack_range < 0.0) {
		// 殴りの範囲
		s_tank_attack_range = GetConVarFloat(FindConVar("tank_attack_range"));
	}
	if (s_tank_speed < 0.0) {
		// タンクの速さ
		s_tank_speed = GetConVarFloat(FindConVar("z_tank_speed"));
	}
	
	/*
	// 岩投げ
	if ((buttons & IN_ATTACK2)) {
		// 岩投げしない
		buttons &= ~IN_ATTACK2;
		return Plugin_Changed;
		// BOTが岩投げ開始
		// この時間が切れるまでターゲットを探してAutoAimする
		//delayStart(client, 3);
		//delayStart(client, 4);
	}
	*/
	
	// 岩投げ中
	if (delayExpired(client, 4, TANK_ROCK_AIM_DELAY)
		&& !delayExpired(client, 3, TANK_ROCK_AIM_TIME))
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client, target)) {
			// BOTが狙っているターゲットが見えている場合
		} else {
			// 見えて無い場合はタンクから見える範囲で一番近い生存者を検索
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) {
				if (isSurvivor(i)
					&& IsPlayerAlive(i)
					&& !isIncapacitated(i)
					&& isVisibleTo(client, i))
				{
					new Float:dist;
					
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) {
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) {
				// 新たなターゲットに照準を合わせる
				if (angles[2] == 0.0) {
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	
	// 殴り
	if (GetEntityMoveType(client) != MOVETYPE_LADDER
		&& (GetEntityFlags(client) & FL_ONGROUND)
		&& IsPlayerAlive(client))
	{
		if (delayExpired(client, 0, TANK_MELEE_SCAN_DELAY)) {
			// 殴りの当たる範囲に立っている生存者がいたら方向は関係なく殴る
			delayStart(client, 0);
			if (nearestActiveSurvivorDistance(client) < s_tank_attack_range * 0.95) {
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	
	// 加速ジャンプ
	if (delayExpired(client, 1, TANK_BHOP_SCAN_DELAY)
		&& delayExpired(client, 2, TANK_BHOP_TIME)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER
		&& (GetEntityFlags(client) & FL_ONGROUND)
		&& getMoveSpeed(client) > s_tank_speed * 0.9)
	{
		// 90%以上のスピードが出ていたら加速開始
		delayStart(client, 1);
		delayStart(client, 2);
	}
	if (!delayExpired(client, 2, TANK_BHOP_TIME)
		&& getMoveSpeed(client) > s_tank_speed * 0.85
		&& GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		// 加速ジャンプ
		// カーソル入力は減速してしまうので使わせないけど
		// 通り過ぎてしまうことがある..
		buttons &= ~(IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT);
		vel[0] = 0.0;
		vel[1] = 0.0;
		if ((GetEntityFlags(client) & FL_ONGROUND)) {
			buttons |= IN_JUMP|IN_DUCK;
		} else {
			buttons &= ~(IN_DUCK|IN_JUMP);
		}
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

// clientの一番近くにいる生存者の距離を取得
// 
// 今はトレースしていないので1階と2階とか隣の部屋とか
// 遮るものがあっても近くになってしまう
stock any:nearestSurvivorDistance(client)
{
	new Float:self[3];
	new Float:min_dist = 100000.0;
	
	GetClientAbsOrigin(client, self);
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i)) {
			new Float:target[3];
			GetClientAbsOrigin(i, target);
			new Float:dist = GetVectorDistance(self, target);
			if (dist < min_dist) {
				min_dist = dist;
			}
		}
	}
	return min_dist;
}
stock any:nearestActiveSurvivorDistance(client)
{
	new Float:self[3];
	new Float:min_dist = 100000.0;
	
	GetClientAbsOrigin(client, self);
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i)
			&& isSurvivor(i)
			&& IsPlayerAlive(i)
			&& !isIncapacitated(client))
		{
			new Float:target[3];
			GetClientAbsOrigin(i, target);
			new Float:dist = GetVectorDistance(self, target);
			if (dist < min_dist) {
				min_dist = dist;
			}
		}
	}
	return min_dist;
}

// clientから見える範囲で一番近い生存者を取得
stock any:nearestVisibleSurvivor(client)
{
	new Float:self[3];
	new Float:min_dist = 100000.0;
	new min_i = -1;
	GetClientAbsOrigin(client, self);
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i)
			&& isSurvivor(i)
			&& IsPlayerAlive(i)
			&& isVisibleTo(client, i))
		{
			new Float:target[3];
			GetClientAbsOrigin(i, target);
			new Float:dist = GetVectorDistance(self, target);
			if (dist < min_dist) {
				min_dist = dist;
				min_i = i;
			}
		}
	}
	return min_i;
}

// 感染者か
stock bool:isInfected(i)
{
	return GetClientTeam(i) == 3;
}
// ゴーストか
stock bool:isGhost(i)
{
	return isInfected(i) && GetEntProp(i, Prop_Send, "m_isGhost");
}
// 特殊感染者ボットか
stock bool:isSpecialInfectedBot(i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && isInfected(i);
}
// 生存者か
// 死んでるとかダウンしてるとか拘束されてるとかも見たほうがいいでしょう..
stock bool:isSurvivor(i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
// 感染者の種類を取得
stock any:getZombieClass(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * キー入力処理内でビジーループと状態維持に使っている変数
 *
 * 死んだときにクリアしないと前の情報が残ってるけど
 * あまり気にならないような作りにしてる
 */
// 1 client 8delayを持っとく
new Float:g_delay[MAXPLAYERS1][8]; 
stock delayStart(client, no)
{
	g_delay[client][no] = GetGameTime();
}
stock bool:delayExpired(client, no, Float:delay)
{
	return GetGameTime() - g_delay[client][no] > delay;
}
// 1 player 8state を持っとく
new g_state[MAXPLAYERS1][8]; 
stock setState(client, no, value)
{
	g_state[client][no] = value;
}
stock any:getState(client, no)
{
	return g_state[client][no];
}
stock initStatus()
{
	new Float:time = GetGameTime();
	for (new i = 0; i < MAXPLAYERS+1; ++i) {
		for (new j = 0; j < 8; ++j) {
			g_delay[i][j] = time;
			g_state[i][j] = 0;
		}
	}
}

// 特殊がメイン攻撃した時間
new Float:g_si_attack_time;
stock any:getSIAttackTime()
{
	return g_si_attack_time;
}
stock updateSIAttackTime()
{
	g_si_attack_time = GetGameTime();
}

/**
 * TODO: 主攻撃の準備ができているか（リジャージ中じゃないか）調べたいけど
 *       どうすればいいのか分からない
 */
stock bool:readyAbility(client)
{
	/*
	new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	new String:name[256];
	GetClientName(client, name, 256);
	
	if (ability > 0) {
	    //new Float:time = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
		//new used = GetEntProp(ability, Prop_Send, "m_hasBeenUsed");
		//new Float:duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
		return time < GetGameTime();
	} else {
		// なぜかここにくることがある
	}
	*/
	return true;
}

// 入力がどうなっているの確認に使ってるやつ
stock debugPrint(client, buttons, Float:vel[3], Float:angles[3])
{
	// 条件でフィルタしないと出すぎてやばいので適当に書き換えてデバッグしてる
	if (IsFakeClient(client)) {
		return; // 自分だけ表示
	}
	
	new String:name[256];
	GetClientName(client, name, 256);
	
#if DEBUG_KEY
	// キー入力
	new String:command[1024];
	if (buttons & IN_DUCK) {
		StrCat(command, sizeof(command), "DUCK ");
	}
	if (buttons & IN_ATTACK) {
		StrCat(command, sizeof(command), "ATTACK ");
	}
	if (buttons & IN_ATTACK2) {
		StrCat(command, sizeof(command), "ATTACK2 ");
	}
	if (buttons & IN_MOVELEFT) {
		StrCat(command, sizeof(command), "MOVELEFT ");
	}
	if (buttons & IN_MOVERIGHT) {
		StrCat(command, sizeof(command), "MOVERIGHT ");
	}
	if (buttons & IN_FORWARD) {
		StrCat(command, sizeof(command), "FORWARD ");
	}
	if (buttons & IN_BACK) {
		StrCat(command, sizeof(command), "BACK ");
	}
	if (buttons & IN_USE) {
		StrCat(command, sizeof(command), "USE ");
	}
	if (buttons & IN_JUMP) {
		StrCat(command, sizeof(command), "JUMP ");
	}
	if (buttons != 0) {PrintToChatAll("%s: %s", name, command);}
#endif
#if DEBUG_ANGLE
	// angles
	PrintToChatAll("%s: angles(%f,%f,%f)", name, angles[0], angles[1], angles[2]);
#endif
#if DEBUG_VEL
	// vel
	if (vel[0] != 0.0 || vel[1] != 0.0) {
		PrintToChatAll("%s: vel(%f,%f,%f)", name, vel[0], vel[1], vel[2]);
	}
#endif
#if DEBUG_AIM
    // GetClientAimTargetで
	// AIMが向いてる方向にあるクライアントを取得後に
	// 見えてるか判定
	new entity = GetClientAimTarget(client, true); 
	if (entity > 0) {
		new String:target[256];
		new visible = isVisibleTo(client, entity);
		// クライアントのエンティティ
		GetClientName(entity, target, 256);
		PrintToChatAll("%s aimed to %s (%s)", name, target, (visible ? "visible" : "invisible"));
	}
#endif
#if DEBUG_POS
	new Float:org[3], Float:eye[3];
	GetClientAbsOrigin(client, org);
	GetClientEyePosition(client, eye);
	PrintToChatAll("----");
	PrintToChatAll("AbsOrigin: (%f,%f,%f)", org[0], org[1], org[2]);
	PrintToChatAll("EyePosition: (%f,%f,%f)", eye[0], eye[1], eye[2]);
#endif
}

/**
 * 各クライアントの現在の移動速度を計算する
 *
 * g_move_speedは生存者が直線に走ったときが220くらい
 * 走っているとか止まっている判定できる
 */
new Float:g_move_grad[MAXPLAYERS1][3];
new Float:g_move_speed[MAXPLAYERS1];
new Float:g_pos[MAXPLAYERS1][3];
public Action:timerMoveSpeed(Handle:timer)
{
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			new team = GetClientTeam(i);
			if (team == 2 || team == 3) { // survivor or infected
				new Float:pos[3];
				
				GetClientAbsOrigin(i, pos);
				g_move_grad[i][0] = pos[0] - g_pos[i][0];
				 // yジャンプしてるときにおかしくなる..
				g_move_grad[i][1] = pos[1] - g_pos[i][1];
				g_move_grad[i][2] = pos[2] - g_pos[i][2];
				// スピードに高さ方向は考慮しない
				g_move_speed[i] =
					SquareRoot(g_move_grad[i][0] * g_move_grad[i][0] +
							   g_move_grad[i][1] * g_move_grad[i][1]);
				if (g_move_speed[i] > MOVESPEED_MAX) {
					// ワープやリスポンしたっぽいときはクリア
					g_move_speed[i] = 0.0;
					g_move_grad[i][0] = 0.0;
					g_move_grad[i][1] = 0.0;
					g_move_grad[i][2] = 0.0;
				}
				g_pos[i] = pos;
#if DEBUG_SPEED
				if (!IsFakeClient(i)) {
					// 俺
					PrintToChat(i, "speed: %f(%f,%f,%f)",
								g_move_speed[i],
								g_move_grad[i][0], g_move_grad[i][1], g_move_grad[i][2]
						);
				}
#endif
			}
		}
	}
	return Plugin_Continue;
}

stock Float:getMoveSpeed(client)
{
	return g_move_speed[client];
}
stock Float:getMoveGradient(client, ax)
{
	return g_move_grad[client][ax];
}

public bool:traceFilter(entity, mask, any:self)
{
	return entity != self;
}

/* clientからtargetの頭あたりが見えているか判定 */
stock bool:isVisibleTo(client, target)
{
	new bool:ret = false;
	new Float:angles[3];
	new Float:self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, angles);
	new Handle:trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		new hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

// clientからtargetへのアングルを計算
stock computeAimAngles(client, target, Float:angles[3], AimTarget:type = AimTarget_Eye)
{
	new Float:target_pos[3];
	new Float:self_pos[3];
	new Float:lookat[3];
	
	GetClientEyePosition(client, self_pos);
	switch (type) {
	case AimTarget_Eye: {
		GetClientEyePosition(target, target_pos);
	}
	case AimTarget_Body: {
		GetClientAbsOrigin(target, target_pos);
	}
	case AimTarget_Chest: {
		GetClientAbsOrigin(target, target_pos);
		target_pos[2] += 45.0; // このくらい
	}
	}
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}
// 生存者の場合ダウンしてるか？
stock bool:isIncapacitated(client)
{
	return isSurvivor(client)
		&& GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1
}
