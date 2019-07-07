#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLAYSOUND false

new NowEntity;
new nType[2150];
new FireTime[66];
new PointHurt;
new Float:icespeed[2150];
new Float:jumppower[2150];
new Float:throwpower[2150];
new bool:bThrow[66];
new MaxHealth[2150];
new Health[2150];
new Float:Pos[2150][3];
new bool:bRun[66];
new Float:heavypower[2150];
new bool:bShot[2150];
new bool:bTouch[2150];
new liftinfo[2150][3];
new liftpath[2150][20];
new liftshowbeam[2150];
new liftdamage[2150];
new Float:liftpathpos[2150][20][3];
new liftbeamcolor[4];
new g_sprite;
new laserdamage[2150];
new laserwidth[2150];
new laserprop[2150];
new Float:laserpos[2150][3];
new rotspeed[2150];
new Float:rotpoint[2150][3];
new Float:rotentpoint[2150][3];
new rotrot[2150];
new rotent[2150];
new String:InfoMessage[2150][256];
new String:InfoIcon[2150][256];
new InfoColor[2150][3];
new InfoTime[2150];

public Plugin:myinfo =
{
	name = "特殊实体",
	description = "让实体拥有功能",
	author = "",
	version = "0.1",
	url = ""
};

GetClientCurPos(client, Float:pos[3])
{
	decl Float:VecOrigin[3];
	decl Float:VecAngles[3];
	GetClientEyePosition(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, 33636363, RayType:1, TraceRayDontHitSelf, client);
	if (TR_DidHit(Handle:0))
	{
		TR_GetEndPosition(pos, Handle:0);
	}
	return;
}

public GetClientAimTargetEx(client)
{
	decl Float:VecOrigin[3];
	decl Float:VecAngles[3];
	GetClientEyePosition(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, 33636363, RayType:1, TraceRayDontHitSelf, client);
	if (TR_DidHit(Handle:0))
	{
		return TR_GetEntityIndex(Handle:0);
	}
	return -1;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if (data == entity)
	{
		return false;
	}
	return true;
}

CheatCommand(Client, String:command[], String:arguments[])
{
	if (!Client)
	{
		return;
	}
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & -16385);
	FakeClientCommand(Client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	return;
}

CopyVector(any:data[], any:source[], maxlen)
{
	if (maxlen < 1)
	{
		maxlen = 3;
	}
	new i;
	while (i < maxlen)
	{
		data[i] = source[i];
		i++;
	}
	return;
}

public bool:KvGetBool(Handle:kv, String:key[])
{
	new i = KvGetNum(kv, key, 0);
	return i == 1;
}

BecomeIntoFire(entity)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 255, 0, 0, 255);
	nType[entity] = 1;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackFire_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackFire_Touched);
	return;
}

FirePerson(victim, Float:damage)
{
	if (0 < PointHurt)
	{
		if (IsValidEdict(PointHurt))
		{
			//new var1;
			if (victim > 0 && IsValidEdict(victim))
			{
				decl String:N[20];
				Format(N, 20, "target%d", victim);
				DispatchKeyValue(victim, "targetname", N);
				DispatchKeyValue(PointHurt, "DamageTarget", N);
				DispatchKeyValueFloat(PointHurt, "Damage", damage);
				DispatchKeyValue(PointHurt, "DamageType", "8");
				AcceptEntityInput(PointHurt, "Hurt", -1, -1, 0);
			}
		}
		else
		{
			PointHurt = CreatePointHurt();
			FirePerson(victim, damage);
		}
	}
	else
	{
		PointHurt = CreatePointHurt();
		FirePerson(victim, damage);
	}
	return;
}

public SDKCallBackFire_Touched(entity, toucher)
{
	if (nType[entity] != 1)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackFire_Touched);
		return;
	}
	//new var1;
	if (toucher < MaxClients && IsPlayerAlive(toucher))
	{
		FireTime[toucher]++;
		if (FireTime[toucher] <= 15)
		{
			return;
		}
		FireTime[toucher] = 0;
	}
	FirePerson(toucher, 5.0);
	return;
}

CreatePointHurt()
{
	new pointHurt = CreateEntityByName("point_hurt", -1);
	if (pointHurt)
	{
		DispatchKeyValue(pointHurt, "Damage", "10");
		DispatchSpawn(pointHurt);
	}
	return pointHurt;
}

BecomeIntoIce(entity, Float:speed)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 0, 0, 100, 255);
	icespeed[entity] = speed;
	nType[entity] = 2;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackIce_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackIce_Touched);
	return;
}

SetPlayerSpeed(client, Float:speed)
{
	SetEntPropFloat(client, PropType:1, "m_flLaggedMovementValue", speed, 0);
	return;
}

ShowChooseIceSpeedMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseIceSpeed, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择滑冰板的速度,编号:%d", entity);
	AddMenuItem(menu, "0.2", "0.2", 0);
	AddMenuItem(menu, "0.8", "0.8", 0);
	AddMenuItem(menu, "1.0", "标准速度", 0);
	AddMenuItem(menu, "1.5", "1.5", 0);
	AddMenuItem(menu, "5.0", "5.0", 0);
	AddMenuItem(menu, "10.0", "10.0", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseIceSpeed(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new Float:speed = 0.0;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			speed = StringToFloat(sType);
			if (speed < 0.0)
			{
				return;
			}
			BecomeIntoIce(NowEntity, speed);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackIce_Touched(entity, toucher)
{
	if (nType[entity] != 2)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackIce_Touched);
		return;
	}
	//new var1;
	if (toucher < MaxClients && IsPlayerAlive(toucher))
	{
		SetPlayerSpeed(toucher, icespeed[entity]);
	}
	return;
}

BecomeIntoJump(entity, Float:power)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 255, 165, 0, 255);
	jumppower[entity] = power;
	nType[entity] = 3;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackJump_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackJump_Touched);
	return;
}

JumpPerson(person, Float:power)
{
	if (person > MaxClients)
	{
		return;
	}
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, person);
	WritePackFloat(pack, power);
	CreateTimer(0.2, TimerJump, pack, 0);
	return;
}

public Action:TimerJump(Handle:timer, any:pack)
{
	ResetPack(pack, false);
	new person = ReadPackCell(pack);
	new Float:power = ReadPackFloat(pack);
	new Float:velo[3] = 0.0;
	velo[0] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[0]", 0);
	velo[1] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[1]", 0);
	velo[2] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[2]", 0);
	if (velo[2] != 0.0)
	{
		return Action:0;
	}
	new Float:vec[3] = 0.0;
	vec[0] = velo[0];
	vec[1] = velo[1];
	vec[2] = velo[2] + power * 300.0;
	TeleportEntity(person, NULL_VECTOR, NULL_VECTOR, vec);
	#if PLAYSOUND
	if (!IsSoundPrecached("buttons/blip1.wav"))
	{
		PrecacheSound("buttons/blip1.wav", false);
	}
	EmitSoundToClient(person, "buttons/blip1.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	#endif
	return Action:0;
}

ShowChooseJumpPowerMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseJumpPower, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择弹跳板的力度,编号:%d", entity);
	AddMenuItem(menu, "1.0", "小", 0);
	AddMenuItem(menu, "1.7", "较小", 0);
	AddMenuItem(menu, "3.4", "中", 0);
	AddMenuItem(menu, "4.0", "大", 0);
	AddMenuItem(menu, "5.0", "最大", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseJumpPower(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new Float:power = 0.0;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			power = StringToFloat(sType);
			if (power < 0.0)
			{
				return;
			}
			BecomeIntoJump(NowEntity, power);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackJump_Touched(entity, toucher)
{
	if (nType[entity] != 3)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackJump_Touched);
		return;
	}
	//new var1;
	if (toucher < MaxClients && !IsPlayerAlive(toucher))
	{
		return;
	}
	JumpPerson(toucher, jumppower[entity]);
	return;
}

BecomeIntoThrow(entity, Float:power)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 0, 255, 0, 255);
	throwpower[entity] = power;
	nType[entity] = 4;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackThrow_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackThrow_Touched);
	SDKUnhook(entity, SDKHookType:0, SDKCallBackThrow_EndTouch);
	SDKHook(entity, SDKHookType:0, SDKCallBackThrow_EndTouch);
	return;
}

ThrowPerson(person, Float:power, Float:origin[3], Float:angles[3])
{
	//new var1;
	if (person > MaxClients || bThrow[person])
	{
		return;
	}
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, person);
	WritePackFloat(pack, power);
	WritePackFloat(pack, origin[0]);
	WritePackFloat(pack, origin[1]);
	WritePackFloat(pack, origin[2]);
	WritePackFloat(pack, angles[0]);
	WritePackFloat(pack, angles[1]);
	WritePackFloat(pack, angles[2]);
	CreateTimer(0.3, TimerThrow, pack, 0);
	bThrow[person] = true;
	return;
}

public Action:TimerThrow(Handle:timer, any:pack)
{
	ResetPack(pack, false);
	decl Float:vAngles[3];
	decl Float:vOrigin[3];
	new person = ReadPackCell(pack);
	if (!bThrow[person])
	{
		return Action:0;
	}
	new Float:power = ReadPackFloat(pack) * 3.0;
	vOrigin[0] = ReadPackFloat(pack);
	vOrigin[1] = ReadPackFloat(pack);
	vOrigin[2] = ReadPackFloat(pack);
	vAngles[0] = ReadPackFloat(pack);
	vAngles[1] = ReadPackFloat(pack);
	vAngles[2] = ReadPackFloat(pack);
	decl Float:VecOrigin[3];
	decl Float:pos[3];
	GetClientEyePosition(person, VecOrigin);
	TR_TraceRayFilter(VecOrigin, vAngles, 16513, RayType:1, TraceRayDontHitSelf, person);
	if (TR_DidHit(Handle:0))
	{
		TR_GetEndPosition(pos, Handle:0);
	}
	decl Float:volicity[3];
	SubtractVectors(pos, vOrigin, volicity);
	ScaleVector(volicity, power);
	volicity[2] = FloatAbs(volicity[2]);
	TeleportEntity(person, NULL_VECTOR, NULL_VECTOR, volicity);
	bThrow[person] = false;
	#if PLAYSOUND
	if (!IsSoundPrecached("buttons/blip1.wav"))
	{
		PrecacheSound("buttons/blip1.wav", false);
	}
	EmitSoundToClient(person, "buttons/blip1.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	#endif
	return Action:0;
}

public SDKCallBackThrow_Touched(entity, toucher)
{
	if (nType[entity] != 4)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackThrow_Touched);
		SDKUnhook(entity, SDKHookType:0, SDKCallBackThrow_EndTouch);
		return;
	}
	//new var1;
	if (toucher < MaxClients && !IsPlayerAlive(toucher))
	{
		return;
	}
	decl Float:ori[3];
	decl Float:ang[3];
	GetEntPropVector(entity, PropType:0, "m_vecOrigin", ori, 0);
	GetEntPropVector(entity, PropType:0, "m_angRotation", ang, 0);
	ThrowPerson(toucher, throwpower[entity], ori, ang);
	return;
}

public SDKCallBackThrow_EndTouch(entity, toucher)
{
	if (nType[entity] != 4)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackThrow_Touched);
		SDKUnhook(entity, SDKHookType:0, SDKCallBackThrow_EndTouch);
		return;
	}
	if (toucher < MaxClients)
	{
		bThrow[toucher] = false;
	}
	return;
}

ShowChooseThrowPowerMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseThrowPower, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择投掷板的力度,编号:%d", entity);
	AddMenuItem(menu, "1.0", "小", 0);
	AddMenuItem(menu, "1.3", "较小", 0);
	AddMenuItem(menu, "2.0", "中", 0);
	AddMenuItem(menu, "2.5", "大", 0);
	AddMenuItem(menu, "3.0", "最大", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseThrowPower(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new Float:power = 0.0;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			power = StringToFloat(sType);
			if (power < 0.0)
			{
				return;
			}
			BecomeIntoThrow(NowEntity, power);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public bool:TraceRayDontHit(entity, mask, any:data)
{
	if (data == entity)
	{
		return false;
	}
	return true;
}

BecomeIntoBreak(entity, health)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	Health[entity] = health;
	MaxHealth[entity] = health;
	SetEntityRenderFx(entity, RenderFx:17);
	nType[entity] = 5;
	SDKUnhook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
	SDKHook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
	return;
}

ShowChooseBreakHealthMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseBreakHealth, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择血量板的耐久度,编号:%d", entity);
	AddMenuItem(menu, "100", "100HP", 0);
	AddMenuItem(menu, "1000", "1000HP", 0);
	AddMenuItem(menu, "5000", "5000HP", 0);
	AddMenuItem(menu, "10000", "10000HP", 0);
	AddMenuItem(menu, "20000", "20000HP", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseBreakHealth(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new power;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			power = StringToInt(sType, 10);
			if (0 > power)
			{
				return;
			}
			BecomeIntoBreak(NowEntity, power);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackBreak_Damage(entity, attacker, inflictor, Float:damage, damagetype)
{
	if (nType[entity] != 5)
	{
		SDKUnhook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
		return;
	}
	Health[entity] -= RoundToFloor(damage);
	if (0 >= Health[entity])
	{
		#if PLAYSOUND
		if (!IsSoundPrecached("physics/glass/glass_sheet_break3.wav"))
		{
			PrecacheSound("physics/glass/glass_sheet_break3.wav", false);
		}
		EmitSoundToAll("physics/glass/glass_sheet_break3.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		#endif
		RemoveEdict(entity);
		SDKUnhook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
		Health[entity] = 0;
		nType[entity] = 0;
	}
	PrintCenterText(attacker, "这堵墙还有 %d 耐久度", Health[entity]);
	return;
}

BecomeIntoTeleport(entity, Float:pos[])
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 0, 0, 150, 255);
	nType[entity] = 6;
	Pos[entity][0] = pos[0];
	Pos[entity][1] = pos[1];
	Pos[entity][2] = pos[2];
	SDKUnhook(entity, SDKHookType:10, SDKCallBackTele_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackTele_Touched);
	return;
}

public SDKCallBackTele_Touched(entity, toucher)
{
	if (nType[entity] != 6)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackTele_Touched);
		return;
	}
	TeleportEntity(toucher, Pos[entity], NULL_VECTOR, NULL_VECTOR);
	if (toucher < MaxClients)
	{
		#if PLAYSOUND
		if (!IsSoundPrecached("level/startwam.wav"))
		{
			PrecacheSound("level/startwam.wav", false);
		}
		EmitSoundToClient(toucher, "level/startwam.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		#endif
	}
	return;
}

ShowChooseTelePosMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseTelePos, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请移动到要传送的地方,然后选择。编号:%d", entity);
	AddMenuItem(menu, "item1", "把当前位置当作传送点", 0);
	AddMenuItem(menu, "item2", "把鼠标位置当作传送点", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseTelePos(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl Float:pos[3];
			switch (item)
			{
				case 0:
				{
					GetClientAbsOrigin(client, pos);
				}
				case 1:
				{
					GetClientCurPos(client, pos);
				}
				default:
				{
				}
			}
			BecomeIntoTeleport(NowEntity, pos);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

BecomeIntoDie(entity)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 0, 0, 0, 255);
	nType[entity] = 7;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackDie_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackDie_Touched);
	return;
}

KillPerson(person)
{
	if (!IsValidEdict(person))
	{
		return;
	}
	decl String:clsname[64];
	GetEdictClassname(person, clsname, 64);
	if (person > MaxClients)
	{
		if (StrEqual(clsname, "infected", true))
		{
			AcceptEntityInput(person, "Kill", -1, -1, 0);
		}
		return;
	}
	else
	{
		CheatCommand(person, "kill", "");
	}
	return;
}

public SDKCallBackDie_Touched(entity, toucher)
{
	if (nType[entity] != 7)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackDie_Touched);
		return;
	}
	KillPerson(toucher);
	return;
}

BecomeIntoShake(entity)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 255, 0, 255, 255);
	nType[entity] = 8;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackShake_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackShake_Touched);
	return;
}

ShakePlayer(client)
{
	//new var1;
	if (client > MaxClients || !IsPlayerAlive(client))
	{
		return;
	}
	decl Float:vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	new entity = CreateEntityByName("env_shake", -1);
	if (entity == -1)
	{
		return;
	}
	DispatchKeyValue(entity, "amplitude", "16");
	DispatchKeyValue(entity, "duration", "1");
	DispatchKeyValue(entity, "frequency", "2.5");
	DispatchKeyValue(entity, "radius", "40");
	DispatchSpawn(entity);
	TeleportEntity(entity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "StartShake", entity, entity, 0);
	AcceptEntityInput(entity, "kill", -1, -1, 0);
	return;
}

public SDKCallBackShake_Touched(entity, toucher)
{
	if (nType[entity] != 8)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackShake_Touched);
		return;
	}
	ShakePlayer(toucher);
	return;
}

BecomeIntoRun(entity)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 153, 153, 0, 255);
	nType[entity] = 9;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackAuto_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackAuto_Touched);
	return;
}

RunPerson(person, Float:origin[3], Float:angles[3])
{
	//new var1;
	if (person > MaxClients || bRun[person])
	{
		return;
	}
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, person);
	WritePackFloat(pack, origin[0]);
	WritePackFloat(pack, origin[1]);
	WritePackFloat(pack, origin[2]);
	WritePackFloat(pack, angles[0]);
	WritePackFloat(pack, angles[1]);
	WritePackFloat(pack, angles[2]);
	CreateTimer(0.1, TimerRun, pack, 0);
	bRun[person] = true;
	return;
}

public Action:TimerRun(Handle:timer, any:pack)
{
	ResetPack(pack, false);
	decl Float:vAngles[3];
	decl Float:vOrigin[3];
	new person = ReadPackCell(pack);
	if (!bRun[person])
	{
		return Action:0;
	}
	vOrigin[0] = ReadPackFloat(pack);
	vOrigin[1] = ReadPackFloat(pack);
	vOrigin[2] = ReadPackFloat(pack);
	vAngles[0] = ReadPackFloat(pack);
	vAngles[1] = ReadPackFloat(pack);
	vAngles[2] = ReadPackFloat(pack);
	decl Float:VecOrigin[3];
	decl Float:pos[3];
	GetClientEyePosition(person, VecOrigin);
	TR_TraceRayFilter(VecOrigin, vAngles, 16513, RayType:1, TraceRayDontHitSelf, person);
	if (TR_DidHit(Handle:0))
	{
		TR_GetEndPosition(pos, Handle:0);
	}
	decl Float:volicity[3];
	new Float:velo[3] = 0.0;
	velo[0] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[0]", 0);
	velo[1] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[1]", 0);
	velo[2] = GetEntPropFloat(person, PropType:0, "m_vecVelocity[2]", 0);
	SubtractVectors(pos, vOrigin, volicity);
	ScaleVector(volicity, 0.4);
	volicity[2] = 0.0;
	AddVectors(velo, volicity, volicity);
	TeleportEntity(person, NULL_VECTOR, NULL_VECTOR, volicity);
	bRun[person] = false;
	return Action:0;
}

public SDKCallBackAuto_Touched(entity, toucher)
{
	if (nType[entity] != 9)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackAuto_Touched);
		return;
	}
	//new var1;
	if (toucher < MaxClients && !IsPlayerAlive(toucher))
	{
		return;
	}
	decl Float:ori[3];
	decl Float:ang[3];
	GetEntPropVector(entity, PropType:0, "m_vecOrigin", ori, 0);
	GetEntPropVector(entity, PropType:0, "m_angRotation", ang, 0);
	RunPerson(toucher, ori, ang);
	return;
}

BecomeIntoHeavy(entity, Float:power)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	SetEntityRenderColor(entity, 50, 150, 100, 255);
	heavypower[entity] = power;
	nType[entity] = 10;
	SDKUnhook(entity, SDKHookType:10, SDKCallBackHea_Touched);
	SDKHook(entity, SDKHookType:10, SDKCallBackHea_Touched);
	return;
}

SetPlayerHeavy(client, Float:power)
{
	SetEntityGravity(client, power);
	return;
}

ShowChooseHeaPowerMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseHeaSpeed, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择重力板的速度,编号:%d", entity);
	AddMenuItem(menu, "0.2", "0.2", 0);
	AddMenuItem(menu, "0.8", "0.8", 0);
	AddMenuItem(menu, "1.0", "标准重力", 0);
	AddMenuItem(menu, "1.5", "1.5", 0);
	AddMenuItem(menu, "5.0", "5.0", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseHeaSpeed(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new Float:speed = 0.0;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			speed = StringToFloat(sType);
			if (speed < 0.0)
			{
				return;
			}
			BecomeIntoHeavy(NowEntity, speed);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackHea_Touched(entity, toucher)
{
	if (nType[entity] != 10)
	{
		SDKUnhook(entity, SDKHookType:10, SDKCallBackHea_Touched);
		return;
	}
	//new var1;
	if (toucher < MaxClients && IsPlayerAlive(toucher))
	{
		SetPlayerHeavy(toucher, heavypower[entity]);
	}
	return;
}

BecomeIntoBreakEx(entity, bool:shot, bool:touch)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	bShot[entity] = shot;
	bTouch[entity] = touch;
	nType[entity] = 11;
	SDKUnhook(entity, SDKHookType:3, SDKCallBackBreakEx_Damage);
	SDKHook(entity, SDKHookType:3, SDKCallBackBreakEx_Damage);
	SDKUnhook(entity, SDKHookType:10, SDKCallBackBreakEx_Touch);
	SDKHook(entity, SDKHookType:10, SDKCallBackBreakEx_Touch);
	return;
}

ShowChooseBreakExFlagsMenu(client, entity)
{
	new String:sTemp[64];
	new Handle:menu = CreateMenu(MenuHandler_ChooseBreakExFlags, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择破碎板的属性,编号:%d", entity);
	Format(sTemp, 64, "受到伤害就破碎:%d", bShot[entity]);
	AddMenuItem(menu, "item1", sTemp, 0);
	Format(sTemp, 64, "触碰就破碎:%d", bTouch[entity]);
	AddMenuItem(menu, "item2", sTemp, 0);
	AddMenuItem(menu, "item3", "完成", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseBreakExFlags(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			switch (item)
			{
				case 0:
				{
					bShot[NowEntity] = !bShot[NowEntity];
				}
				case 1:
				{
					bTouch[NowEntity] = !bTouch[NowEntity];
				}
				case 2:
				{
					BecomeIntoBreakEx(NowEntity, bShot[NowEntity], bTouch[NowEntity]);
				}
				default:
				{
				}
			}
			//new var2;
			if (item && item == 1)
			{
				ShowChooseBreakExFlagsMenu(client, NowEntity);
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackBreakEx_Damage(entity, attacker, inflictor, Float:damage, damagetype)
{
	if (nType[entity] != 11)
	{
		SDKUnhook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
		return;
	}
	if (!bShot[entity])
	{
		return;
	}
	SDKUnhook(entity, SDKHookType:3, SDKCallBackBreak_Damage);
	RemoveEdict(entity);
	#if PLAYSOUND
	if (!IsSoundPrecached("physics/glass/glass_sheet_break3.wav"))
	{
		PrecacheSound("physics/glass/glass_sheet_break3.wav", false);
	}
	EmitSoundToAll("physics/glass/glass_sheet_break3.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	#endif
	return;
}

public SDKCallBackBreakEx_Touch(entity, toucher)
{
	if (nType[entity] != 11)
	{
		SDKUnhook(entity, SDKHookType:3, SDKCallBackBreakEx_Touch);
		return;
	}
	if (!bTouch[entity])
	{
		return;
	}
	SDKUnhook(entity, SDKHookType:10, SDKCallBackBreakEx_Touch);
	RemoveEdict(entity);
	#if PLAYSOUND
	if (!IsSoundPrecached("physics/glass/glass_sheet_break3.wav"))
	{
		PrecacheSound("physics/glass/glass_sheet_break3.wav", false);
	}
	EmitSoundToAll("physics/glass/glass_sheet_break3.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	#endif
	return;
}

BecomeIntoLift(entity, speed, pathcount, Float:pos[][3], bool:damage)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	decl String:sTemp[256];
	decl String:sFirst[256];
	decl Float:ang[3];
	decl String:model[256];
	decl String:sName[256];
	GetEntPropVector(entity, PropType:1, "m_angRotation", ang, 0);
	GetEntPropString(entity, PropType:1, "m_ModelName", model, 256, 0);
	if (!IsValidEdict(entity))
	{
		return;
	}
	new lift = CreateEntityByName("func_tracktrain", -1);
	if (lift == -1)
	{
		return;
	}
	Format(sName, 256, "train_%d", entity);
	new i;
	while (i < pathcount)
	{
		new path = CreateEntityByName("path_track", -1);
		if (!(path == -1))
		{
			Format(sTemp, 256, "path%d_%d", entity, i);
			if (!i)
			{
				strcopy(sFirst, 256, sTemp);
				HookSingleEntityOutput(path, "OnPass", EntityOutput_OnPass_Start, false);
			}
			DispatchKeyValue(path, "targetname", sTemp);
			if (pathcount + -1 > i)
			{
				Format(sTemp, 256, "path%d_%d", entity, i + 1);
				DispatchKeyValue(path, "target", sTemp);
			}
			else
			{
				if (pathcount + -1 == i)
				{
					Format(sTemp, 256, "path%d_%d", entity, 0);
					HookSingleEntityOutput(path, "OnPass", EntityOutput_OnPass_End, false);
				}
			}
			DispatchKeyValue(path, "parentname", sName);
			DispatchSpawn(path);
			TeleportEntity(path, pos[i], NULL_VECTOR, NULL_VECTOR);
			liftpath[entity][i] = path;
			CopyVector(liftpathpos[entity][i], pos[i], 3);
		}
		i++;
	}
	new b;
	while (b < pathcount)
	{
		ActivateEntity(liftpath[entity][b]);
		b++;
	}
	DispatchKeyValue(lift, "targetname", sName);
	new prop = CreateEntityByName("prop_dynamic", -1);
	DispatchKeyValue(prop, "model", model);
	DispatchKeyValue(prop, "parentname", sName);
	DispatchKeyValue(prop, "solid", "6");
	DispatchSpawn(prop);
	SetVariantString(sName);
	AcceptEntityInput(prop, "SetParent", prop, prop, 0);
	Format(sTemp, 256, "%d", speed);
	DispatchKeyValue(lift, "speed", sTemp);
	DispatchKeyValue(lift, "target", sFirst);
	if (damage)
	{
		DispatchKeyValue(lift, "dmg", "1");
	}
	DispatchKeyValue(lift, "spawnflags", "17");
	DispatchSpawn(lift);
	ActivateEntity(lift);
	SetEntityModel(lift, model);
	TeleportEntity(lift, pos[0], ang, NULL_VECTOR);
	SetEntProp(lift, PropType:0, "m_nSolidType", any:2, 4, 0);
	new enteffects = GetEntProp(lift, PropType:0, "m_fEffects", 4, 0);
	enteffects |= 32;
	SetEntProp(lift, PropType:0, "m_fEffects", enteffects, 4, 0);
	AcceptEntityInput(lift, "StartForward", -1, -1, 0);
	nType[entity] = 12;
	liftinfo[entity][0] = lift;
	liftinfo[entity][1] = speed;
	liftinfo[entity][2] = pathcount;
	liftdamage[entity] = damage;
	return;
}

public EntityOutput_OnPass_Start(String:output[], path, lift, Float:delay)
{
	if (IsValidEdict(lift))
	{
		AcceptEntityInput(lift, "StartForward", -1, -1, 0);
	}
	return;
}

public EntityOutput_OnPass_End(String:output[], path, lift, Float:delay)
{
	if (IsValidEdict(lift))
	{
		AcceptEntityInput(lift, "StartBackward", -1, -1, 0);
	}
	return;
}

ShowChooseLiftFlagsMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseLiftFlags, MenuAction:28);
	SetMenuExitButton(menu, true);
	decl String:sTemp[256];
	SetMenuTitle(menu, "请设置电梯板的类型。编号:%d", entity);
	Format(sTemp, 256, "<重要>速度+10.目前:%d", liftinfo[entity][1]);
	AddMenuItem(menu, "item1", sTemp, 0);
	Format(sTemp, 256, "<重要>速度-10.目前:%d", liftinfo[entity][1]);
	AddMenuItem(menu, "item2", sTemp, 0);
	Format(sTemp, 256, "是否显示路径(不建议):%d", liftshowbeam[entity]);
	AddMenuItem(menu, "item3", sTemp, 0);
	Format(sTemp, 256, "卡住时伤害(防止玩家卡电梯):%d", liftdamage[entity]);
	AddMenuItem(menu, "item4", sTemp, 0);
	Format(sTemp, 256, "<重要>添加路径点,目前有%d个(MAX:%d).选择它们可以删除", liftinfo[entity][2], 20);
	AddMenuItem(menu, "item5", sTemp, 0);
	if (0 < liftinfo[entity][2])
	{
		new i;
		while (liftinfo[entity][2] > i)
		{
			Format(sTemp, 256, "路径点%d:坐标->%d,%d,%d", i, RoundToFloor(liftpathpos[entity][i][0]), RoundToFloor(liftpathpos[entity][i][1]), RoundToFloor(liftpathpos[entity][i][2]));
			decl String:sTemp2[256];
			Format(sTemp2, 256, "%d", i);
			AddMenuItem(menu, sTemp2, sTemp, 0);
			i++;
		}
	}
	AddMenuItem(menu, "item6", "完成", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseLiftFlags(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			switch (item)
			{
				case 0:
				{
					liftinfo[NowEntity][1] += 10;
					ShowChooseLiftFlagsMenu(client, NowEntity);
				}
				case 1:
				{
					if (liftinfo[NowEntity][1] > 10)
					{
						liftinfo[NowEntity][1] += -10;
					}
					ShowChooseLiftFlagsMenu(client, NowEntity);
				}
				case 2:
				{
					liftshowbeam[NowEntity] = !liftshowbeam[NowEntity];
					ShowChooseLiftFlagsMenu(client, NowEntity);
				}
				case 3:
				{
					liftdamage[NowEntity] = !liftdamage[NowEntity];
					ShowChooseLiftFlagsMenu(client, NowEntity);
				}
				case 4:
				{
					if (liftinfo[NowEntity][2] >= 20)
					{
						PrintToChat(client, "\x03没有空余的路径点了。");
						ShowChooseLiftFlagsMenu(client, NowEntity);
						return;
					}
					GetClientAbsOrigin(client, liftpathpos[NowEntity][liftinfo[NowEntity][2]]);
					liftinfo[NowEntity][2]++;
					ShowChooseLiftFlagsMenu(client, NowEntity);
				}
				default:
				{
				}
			}
			//new var2;
			if (item > 4 && item < GetMenuItemCount(menu) + -1)
			{
				decl String:sItem[256];
				decl item2;
				GetMenuItem(menu, item, sItem, 256, _, "", 0);
				item2 = StringToInt(sItem, 10);
				new i = item2;
				while (liftinfo[NowEntity][2] - item2 > i)
				{
					if (!(liftinfo[NowEntity][2] == i))
					{
						liftpathpos[NowEntity][i] = liftpathpos[NowEntity][i + 1];
						liftpathpos[NowEntity][i] = liftpathpos[NowEntity][i + 1];
						liftpathpos[NowEntity][i] = liftpathpos[NowEntity][i + 1];
					}
					i++;
				}
				liftinfo[NowEntity][2]--;
				ShowChooseLiftFlagsMenu(client, NowEntity);
			}
			else
			{
				if (GetMenuItemCount(menu) + -1 == item)
				{
					if (liftinfo[NowEntity][2] > 20)
					{
						PrintToChat(client, "\x03创建失败!太多的路径点了。");
						ShowChooseLiftFlagsMenu(client, NowEntity);
						return;
					}
					if (liftinfo[NowEntity][1] < 10)
					{
						PrintToChat(client, "\x03创建失败!速度不正确。");
						ShowChooseLiftFlagsMenu(client, NowEntity);
						return;
					}
					if (liftinfo[NowEntity][2] < 2)
					{
						PrintToChat(client, "\x03创建失败!路径点不足(>=2)。");
						ShowChooseLiftFlagsMenu(client, NowEntity);
						return;
					}
					BecomeIntoLift(NowEntity, liftinfo[NowEntity][1], liftinfo[NowEntity][2], liftpathpos[NowEntity], liftdamage[NowEntity] ? true : false);
				}
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

ShowLiftPathBeam()
{
	new entity = MaxClients;
	while (entity < 2150)
	{
		if (IsValidEdict(entity))
		{
			//new var1;
			if (liftshowbeam[entity] && liftinfo[entity][2] >= 2)
			{
				new path;
				while (liftinfo[entity][2] > path)
				{
					if (!(liftinfo[entity][2] == path))
					{
						TE_SetupBeamPoints(liftpathpos[entity][path], liftpathpos[entity][path + 1], g_sprite, 0, 0, 0, 0.1, 2.0, 2.0, 1, 0.0, liftbeamcolor, 0);
						TE_SendToAll(0.0);
					}
					path++;
				}
			}
		}
		entity++;
	}
	return;
}

BecomeIntoLaser(entity, damage, width, Float:pos[3])
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	decl String:sTemp[64];
	new laser = CreateEntityByName("env_laser", -1);
	if (laser == -1)
	{
		ThrowError("创建射线失败!");
	}
	Format(sTemp, 64, "%d", damage);
	DispatchKeyValue(laser, "damage", sTemp);
	DispatchKeyValue(laser, "texture", "sprites/laserbeam.spr");
	Format(sTemp, 64, "%d %d %d", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
	DispatchKeyValue(laser, "rendercolor", sTemp);
	Format(sTemp, 64, "%d", width);
	DispatchKeyValue(laser, "width", sTemp);
	DispatchKeyValue(laser, "NoiseAmplitude", "1");
	Format(sTemp, 64, "postar_%d", entity);
	DispatchKeyValue(entity, "targetname", sTemp);
	DispatchKeyValue(laser, "LaserTarget", sTemp);
	DispatchSpawn(entity);
	DispatchSpawn(laser);
	ActivateEntity(laser);
	TeleportEntity(laser, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(laser, "TurnOn", -1, -1, 0);
	nType[entity] = 13;
	laserprop[entity] = laser;
	laserdamage[entity] = damage;
	laserwidth[entity] = width;
	return;
}

ShowChooseLaserFlagsMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseLaserFlags, MenuAction:28);
	SetMenuExitButton(menu, true);
	decl String:sTemp[256];
	SetMenuTitle(menu, "请设置激光板的类型。编号:%d", entity);
	Format(sTemp, 256, "高度+1.目前:%d", laserwidth[entity]);
	AddMenuItem(menu, "item1", sTemp, 0);
	Format(sTemp, 256, "高度-1.目前:%d", laserwidth[entity]);
	AddMenuItem(menu, "item2", sTemp, 0);
	Format(sTemp, 256, "伤害+10.目前:%d", laserdamage[entity]);
	AddMenuItem(menu, "item3", sTemp, 0);
	Format(sTemp, 256, "伤害-10.目前:%d", laserdamage[entity]);
	AddMenuItem(menu, "item4", sTemp, 0);
	Format(sTemp, 256, "<重要>把当前位置定为路径点(%d %d %d)", RoundToFloor(laserpos[entity][0]), RoundToFloor(laserpos[entity][0]), RoundToFloor(laserpos[entity][0]));
	AddMenuItem(menu, "item5", sTemp, 0);
	AddMenuItem(menu, "item6", "完成", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseLaserFlags(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			switch (item)
			{
				case 0:
				{
					laserwidth[NowEntity] += 1;
					ShowChooseLaserFlagsMenu(client, NowEntity);
				}
				case 1:
				{
					if (laserwidth[NowEntity] > 1)
					{
						laserwidth[NowEntity] += -1;
					}
					ShowChooseLaserFlagsMenu(client, NowEntity);
				}
				case 2:
				{
					laserdamage[NowEntity] += 10;
					ShowChooseLaserFlagsMenu(client, NowEntity);
				}
				case 3:
				{
					if (0 < laserdamage[NowEntity])
					{
						laserdamage[NowEntity] += -10;
					}
					ShowChooseLaserFlagsMenu(client, NowEntity);
				}
				case 4:
				{
					GetClientAbsOrigin(client, laserpos[NowEntity]);
					ShowChooseLaserFlagsMenu(client, NowEntity);
				}
				case 5:
				{
					//new var2;
					if (0.0 == laserpos[NowEntity][0] && 0.0 == laserpos[NowEntity][1] && 0.0 == laserpos[NowEntity][2])
					{
						PrintToChat(client, "\x03请先定义好激光的路径点!");
						ShowChooseLaserFlagsMenu(client, NowEntity);
						return;
					}
					if (!laserwidth[NowEntity])
					{
						laserwidth[NowEntity] = 2;
					}
					BecomeIntoLaser(NowEntity, laserdamage[NowEntity], laserwidth[NowEntity], laserpos[NowEntity]);
				}
				default:
				{
				}
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

BecomeIntoRotating(entity, speed, Float:point[3], Float:entpoint[3])
{
	decl String:sTemp[256];
	decl Float:ang[3];
	decl String:model[256];
	GetEntPropVector(entity, PropType:1, "m_angRotation", ang, 0);
	GetEntPropString(entity, PropType:1, "m_ModelName", model, 256, 0);
	new prop = CreateEntityByName("prop_dynamic", -1);
	DispatchKeyValue(prop, "model", model);
	DispatchKeyValueVector(prop, "angles", ang);
	DispatchKeyValue(prop, "solid", "6");
	Format(sTemp, 256, "prop_%d_%d", entity, prop);
	DispatchKeyValue(prop, "targetname", sTemp);
	DispatchSpawn(prop);
	TeleportEntity(prop, entpoint, ang, NULL_VECTOR);
	new rot = CreateEntityByName("func_rotating", -1);
	Format(sTemp, 256, "%d", speed);
	DispatchKeyValue(rot, "maxspeed", sTemp);
	DispatchKeyValue(rot, "fanfriction", "20");
	DispatchKeyValueVector(rot, "origin", point);
	Format(sTemp, 256, "rot_%d_%d", entity, rot);
	DispatchKeyValue(rot, "targetname", sTemp);
	DispatchSpawn(rot);
	TeleportEntity(rot, point, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(sTemp);
	AcceptEntityInput(prop, "SetParent", prop, prop, 0);
	AcceptEntityInput(rot, "Start", -1, -1, 0);
	nType[entity] = 14;
	rotspeed[entity] = speed;
	rotrot[entity] = rot;
	rotent[entity] = prop;
	return;
}

ShowChooseRotFlagsMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseRotFlags, MenuAction:28);
	SetMenuExitButton(menu, true);
	decl String:sTemp[256];
	SetMenuTitle(menu, "请设置旋转板的类型。编号:%d\n地球(实体点)绕着太阳(圆心)转且自转", entity);
	Format(sTemp, 256, "<重要>旋转速度+10,目前:%d", rotspeed[entity]);
	AddMenuItem(menu, "item1", sTemp, 0);
	Format(sTemp, 256, "<重要>旋转速度-10,目前:%d", rotspeed[entity]);
	AddMenuItem(menu, "item2", sTemp, 0);
	Format(sTemp, 256, "<重要>把当前位置定义为圆心(%d %d %d)", RoundToFloor(rotpoint[entity][0]), RoundToFloor(rotpoint[entity][1]), RoundToFloor(rotpoint[entity][2]));
	AddMenuItem(menu, "item3", sTemp, 0);
	Format(sTemp, 256, "<重要>把当前位置定义为实体点(%d %d %d)", RoundToFloor(rotentpoint[entity][0]), RoundToFloor(rotentpoint[entity][1]), RoundToFloor(rotentpoint[entity][2]));
	AddMenuItem(menu, "item4", sTemp, 0);
	AddMenuItem(menu, "item5", "完成", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseRotFlags(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			switch (item)
			{
				case 0:
				{
					rotspeed[NowEntity] += 10;
					ShowChooseRotFlagsMenu(client, NowEntity);
				}
				case 1:
				{
					if (rotspeed[NowEntity] > 10)
					{
						rotspeed[NowEntity] += -10;
					}
					ShowChooseRotFlagsMenu(client, NowEntity);
				}
				case 2:
				{
					GetClientAbsOrigin(client, rotpoint[NowEntity]);
					ShowChooseRotFlagsMenu(client, NowEntity);
				}
				case 3:
				{
					GetClientAbsOrigin(client, rotentpoint[NowEntity]);
					ShowChooseRotFlagsMenu(client, NowEntity);
				}
				case 4:
				{
					if (rotspeed[NowEntity] < 10)
					{
						PrintToChat(client, "\x03创建失败!速度不正确.");
						ShowChooseRotFlagsMenu(client, NowEntity);
						return;
					}
					//new var2;
					if (0.0 == rotpoint[NowEntity][0] && 0.0 == rotpoint[NowEntity][1] && 0.0 == rotpoint[NowEntity][2])
					{
						PrintToChat(client, "\x03创建失败!圆心不正确.");
						ShowChooseRotFlagsMenu(client, NowEntity);
						return;
					}
					//new var3;
					if (0.0 == rotentpoint[NowEntity][0] && 0.0 == rotentpoint[NowEntity][1] && 0.0 == rotentpoint[NowEntity][2])
					{
						PrintToChat(client, "\x03创建失败!实体点不正确.");
						ShowChooseRotFlagsMenu(client, NowEntity);
						return;
					}
					BecomeIntoRotating(NowEntity, rotspeed[NowEntity], rotpoint[NowEntity], rotentpoint[NowEntity]);
				}
				default:
				{
				}
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

BecomeIntoInfo(entity, String:sMessage[], String:sIcon[], color[3], showtime)
{
	//new var1;
	if (entity <= 0 || !IsValidEdict(entity))
	{
		return;
	}
	nType[entity] = 15;
	strcopy(InfoMessage[entity], 256, sMessage);
	strcopy(InfoIcon[entity], 256, sIcon);
	CopyVector(InfoColor[entity], color, 3);
	InfoTime[entity] = showtime;
	SDKUnhook(entity, SDKHookType:8, SDKCallBackInfo_Touch);
	SDKHook(entity, SDKHookType:8, SDKCallBackInfo_Touch);
	return;
}

public Action:CmdText(client, args)
{
	//new var1;
	if (NowEntity <= 0 || !IsValidEdict(NowEntity))
	{
		return Action:0;
	}
	decl String:clsname[256];
	GetEdictClassname(NowEntity, clsname, 256);
	if (StrEqual(clsname, "player", true))
	{
		PrintToChat(client, "\x03不能把玩家作为你的目标!");
		return Action:0;
	}
	if (!nType[NowEntity])
	{
		//new var2;
		if (args < 1 && StrEqual(InfoMessage[NowEntity], "", true))
		{
			PrintToChat(client, "\x03用法:!ett <消息>.\n例:!ett \"abcdefg\"");
			return Action:0;
		}
		//new var3;
		if (args < 1 && !StrEqual(InfoMessage[NowEntity], "", true))
		{
			strcopy(InfoMessage[NowEntity], 256, "");
			PrintToChat(client, "\x03成功清空文本(编号:%d)", NowEntity);
			ShowChooseInfoFlagsMenu(client, NowEntity);
			return Action:0;
		}
		decl String:text[256];
		GetCmdArg(1, text, 256);
		StrCat(InfoMessage[NowEntity], 256, text);
		PrintToChat(client, "\x03成功输入文本(编号:%d):\x04%s", NowEntity, InfoMessage[NowEntity]);
		ShowChooseInfoFlagsMenu(client, NowEntity);
	}
	return Action:0;
}

ShowChooseInfoFlagsMenu(client, entity)
{
	decl String:sTemp[256];
	new Handle:menu = CreateMenu(MenuHandler_ChooseInfoFlags, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择讯息板的类型,编号:%d (输入!ett设置文本)", entity);
	Format(sTemp, 256, "文本:%s", InfoMessage[entity]);
	AddMenuItem(menu, "item1", sTemp, 1);
	if (StrEqual(InfoIcon[entity], "", true))
	{
		Format(sTemp, 256, "消息图标(选择可切换):无");
	}
	else
	{
		if (StrEqual(InfoIcon[entity], "icon_tip", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):提示");
		}
		if (StrEqual(InfoIcon[entity], "icon_info", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):信息");
		}
		if (StrEqual(InfoIcon[entity], "icon_shield", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):防御");
		}
		if (StrEqual(InfoIcon[entity], "icon_alert", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):警告");
		}
		if (StrEqual(InfoIcon[entity], "icon_alert_red", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):强制警告");
		}
		if (StrEqual(InfoIcon[entity], "icon_skull", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):骷髅头");
		}
		if (StrEqual(InfoIcon[entity], "icon_no", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):禁止");
		}
		if (StrEqual(InfoIcon[entity], "icon_arrow_up", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):前面");
		}
		if (StrEqual(InfoIcon[entity], "+jump", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):跳跃键");
		}
		if (StrEqual(InfoIcon[entity], "+attack", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):攻击键1");
		}
		if (StrEqual(InfoIcon[entity], "+attack2", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):攻击键2");
		}
		if (StrEqual(InfoIcon[entity], "+duck", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):蹲键");
		}
		if (StrEqual(InfoIcon[entity], "+speed", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):Shift键");
		}
		if (StrEqual(InfoIcon[entity], "+reload", true))
		{
			Format(sTemp, 256, "消息图标(选择可切换):装弹键");
		}
	}
	AddMenuItem(menu, "item2", sTemp, 0);
	//new var1;
	if (InfoColor[entity][0] == 255 && InfoColor[entity][1] == 255 && InfoColor[entity][2] == 255)
	{
		Format(sTemp, 256, "消息颜色(选择可切换):白色");
	}
	else
	{
		//new var2;
		if (InfoColor[entity][0] && InfoColor[entity][1] && InfoColor[entity][2])
		{
			Format(sTemp, 256, "消息颜色(选择可切换):黑色");
		}
		//new var3;
		if (InfoColor[entity][0] && InfoColor[entity][1] && InfoColor[entity][2] == 255)
		{
			Format(sTemp, 256, "消息颜色(选择可切换):蓝色");
		}
		//new var4;
		if (InfoColor[entity][0] && InfoColor[entity][1] == 255 && InfoColor[entity][2])
		{
			Format(sTemp, 256, "消息颜色(选择可切换):绿色");
		}
		//new var5;
		if (InfoColor[entity][0] == 255 && InfoColor[entity][1] && InfoColor[entity][2])
		{
			Format(sTemp, 256, "消息颜色(选择可切换):红色");
		}
	}
	AddMenuItem(menu, "item3", sTemp, 0);
	AddMenuItem(menu, "item4", "完成", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseInfoFlags(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			switch (item)
			{
				case 1:
				{
					if (StrEqual(InfoIcon[NowEntity], "", true))
					{
						Format(InfoIcon[NowEntity], 256, "icon_tip");
					}
					else
					{
						if (StrEqual(InfoIcon[NowEntity], "icon_tip", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_info");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_info", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_shield");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_shield", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_alert");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_alert", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_alert_red");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_alert_red", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_skull");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_skull", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_no");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_no", true))
						{
							Format(InfoIcon[NowEntity], 256, "icon_arrow_up");
						}
						if (StrEqual(InfoIcon[NowEntity], "icon_arrow_up", true))
						{
							Format(InfoIcon[NowEntity], 256, "+jump");
						}
						if (StrEqual(InfoIcon[NowEntity], "+jump", true))
						{
							Format(InfoIcon[NowEntity], 256, "+attack");
						}
						if (StrEqual(InfoIcon[NowEntity], "+attack", true))
						{
							Format(InfoIcon[NowEntity], 256, "+attack2");
						}
						if (StrEqual(InfoIcon[NowEntity], "+attack2", true))
						{
							Format(InfoIcon[NowEntity], 256, "+duck");
						}
						if (StrEqual(InfoIcon[NowEntity], "+duck", true))
						{
							Format(InfoIcon[NowEntity], 256, "+speed");
						}
						if (StrEqual(InfoIcon[NowEntity], "+speed", true))
						{
							Format(InfoIcon[NowEntity], 256, "+reload");
						}
						if (StrEqual(InfoIcon[NowEntity], "+reload", true))
						{
							Format(InfoIcon[NowEntity], 256, "");
						}
					}
					ShowChooseInfoFlagsMenu(client, NowEntity);
				}
				case 2:
				{
					//new var2;
					if (InfoColor[NowEntity][0] && InfoColor[NowEntity][1] && InfoColor[NowEntity][2])
					{
					}
					else
					{
						//new var3;
						if (!(InfoColor[NowEntity][0] == 255 && InfoColor[NowEntity][1] == 255 && InfoColor[NowEntity][2] == 255))
						{
							//new var4;
							if (!(InfoColor[NowEntity][0] && InfoColor[NowEntity][1] && InfoColor[NowEntity][2] == 255))
							{
								//new var5;
								if (!(InfoColor[NowEntity][0] && InfoColor[NowEntity][1] == 255 && InfoColor[NowEntity][2]))
								{
									//new var6;
									if (InfoColor[NowEntity][0] == 255 && InfoColor[NowEntity][1] && InfoColor[NowEntity][2])
									{
									}
								}
							}
						}
					}
					ShowChooseInfoFlagsMenu(client, NowEntity);
				}
				case 3:
				{
					if (StrEqual(InfoMessage[NowEntity], "", true))
					{
						PrintToChat(client, "\x03创建失败!消息文本为空!");
						return;
					}
					BecomeIntoInfo(NowEntity, InfoMessage[NowEntity], InfoIcon[NowEntity], InfoColor[NowEntity], 5);
				}
				default:
				{
				}
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

public SDKCallBackInfo_Touch(entity, toucher)
{
	if (nType[entity] != 15)
	{
		SDKUnhook(entity, SDKHookType:8, SDKCallBackInfo_Touch);
		return;
	}
	//new var1;
	if (toucher < MaxClients && IsPlayerAlive(toucher))
	{
		if (StrContains(InfoIcon[entity], "+", true) != -1)
		{
			DisplayInstructorHint(toucher, InfoMessage[entity], "use_binding", InfoIcon[entity], InfoColor[entity], InfoTime[entity]);
		}
		DisplayInstructorHint(toucher, InfoMessage[entity], InfoIcon[entity], "", InfoColor[entity], InfoTime[entity]);
	}
	return;
}

DisplayInstructorHint(client, String:s_Message[256], String:s_Icon[], String:s_Binding[], color[3], showtime)
{
	if (IsClientInGame(client))
	{
		ClientCommand(client, "gameinstructor_enable 1");
	}
	decl i_Ent;
	decl String:s_TargetName[32];
	decl Handle:h_RemovePack;
	decl String:sTemp[64];
	i_Ent = CreateEntityByName("env_instructor_hint", -1);
	FormatEx(s_TargetName, 32, "hint%d", client);
	ReplaceString(s_Message, 256, "\n", "", true);
	DispatchKeyValue(client, "targetname", s_TargetName);
	DispatchKeyValue(i_Ent, "hint_target", s_TargetName);
	Format(sTemp, 64, "%d", showtime);
	DispatchKeyValue(i_Ent, "hint_timeout", sTemp);
	DispatchKeyValue(i_Ent, "hint_range", "0.01");
	Format(sTemp, 64, "%d %d %d", color, color[1], color[2]);
	DispatchKeyValue(i_Ent, "hint_color", sTemp);
	DispatchKeyValue(i_Ent, "hint_caption", s_Message);
	//new var1;
	if (StrEqual(s_Icon, "use_binding", true) && !StrEqual(s_Binding, "", true))
	{
		DispatchKeyValue(i_Ent, "hint_icon_onscreen", "use_binding");
		DispatchKeyValue(i_Ent, "hint_binding", s_Binding);
	}
	else
	{
		DispatchKeyValue(i_Ent, "hint_icon_onscreen", s_Icon);
	}
	DispatchSpawn(i_Ent);
	AcceptEntityInput(i_Ent, "ShowHint", -1, -1, 0);
	h_RemovePack = CreateDataPack();
	WritePackCell(h_RemovePack, client);
	WritePackCell(h_RemovePack, i_Ent);
	CreateTimer(float(showtime), RemoveInstructorHint, h_RemovePack, 0);
	return;
}

public Action:RemoveInstructorHint(Handle:h_Timer, Handle:h_Pack)
{
	decl i_Ent;
	decl i_Client;
	ResetPack(h_Pack, false);
	i_Client = ReadPackCell(h_Pack);
	i_Ent = ReadPackCell(h_Pack);
	CloseHandle(h_Pack);
	//new var1;
	if (!i_Client || !IsClientInGame(i_Client))
	{
		return Action:3;
	}
	if (IsValidEntity(i_Ent))
	{
		RemoveEdict(i_Ent);
	}
	DispatchKeyValue(i_Client, "targetname", "");
	return Action:0;
}

public Action:CmdLoadAndSave(client, args)
{
	new Handle:menu = CreateMenu(MenuHandler_LoadAndSave, MenuAction:28);
	SetMenuTitle(menu, "保存/读取菜单");
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "item1", "保存当前地图文件", 0);
	AddMenuItem(menu, "item2", "读取当前地图文件", 0);
	AddMenuItem(menu, "item3", "让所有的电梯板都显示路径", 0);
	AddMenuItem(menu, "item4", "让所有的电梯板都隐藏路径", 0);
	AddMenuItem(menu, "item5", "让所有的电梯板都停下来", 0);
	AddMenuItem(menu, "item6", "让所有的电梯板都继续", 0);
	DisplayMenu(menu, client, 0);
	return Action:0;
}

public MenuHandler_LoadAndSave(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			switch (item)
			{
				case 0:
				{
					SaveToFile(client);
				}
				case 1:
				{
					LoadFromFile(client);
				}
				case 2:
				{
					new lift = MaxClients;
					while (lift < 2150)
					{
						//new var4;
						if (IsValidEdict(lift) && nType[lift] == 12 && liftinfo[lift][2] >= 2)
						{
							liftshowbeam[lift] = 1;
						}
						lift++;
					}
				}
				case 3:
				{
					new lift = MaxClients;
					while (lift < 2150)
					{
						//new var3;
						if (IsValidEdict(lift) && nType[lift] == 12 && liftinfo[lift][2] >= 2)
						{
							liftshowbeam[lift] = 0;
						}
						lift++;
					}
				}
				case 4:
				{
					new lift = MaxClients;
					while (lift < 2150)
					{
						//new var2;
						if (IsValidEdict(lift) && nType[lift] == 12 && IsValidEdict(liftinfo[lift][0]))
						{
							AcceptEntityInput(liftinfo[lift][0], "Stop", -1, -1, 0);
						}
						lift++;
					}
				}
				case 5:
				{
					new lift = MaxClients;
					while (lift < 2150)
					{
						//new var1;
						if (IsValidEdict(lift) && nType[lift] == 12 && IsValidEdict(liftinfo[lift][0]))
						{
							AcceptEntityInput(liftinfo[lift][0], "Resume", -1, -1, 0);
						}
						lift++;
					}
				}
				default:
				{
				}
			}
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

SaveToFile(client)
{
	decl String:map[256];
	decl String:FileNameS[256];
	new Handle:file;
	GetCurrentMap(map, 256);
	BuildPath(PathType:0, FileNameS, 256, "data/EntType/%s.txt", map);
	if (FileExists(FileNameS, false))
	{
		ReplyToCommand(client, "保存文件的数据的文件已经存在，请做好备份后删除再保存!");
		return;
	}
	file = OpenFile(FileNameS, "a+");
	if (file)
	{
		decl Float:vecOrigin[3];
		decl String:sModel[256];
		decl String:sTime[256];
		new count;
		FormatTime(sTime, 256, "%Y/%m/%d", -1);
		WriteFileLine(file, "//----------特殊实体数据 (YY/MM/DD): [%s] ---------------||", sTime);
		WriteFileLine(file, "//----------创建人: %N----------------------||", client);
		WriteFileLine(file, "");
		WriteFileLine(file, "\"EntType\"");
		WriteFileLine(file, "{");
		new i;
		while (i < 2150)
		{
			//new var1;
			if (nType[i] > 0 && IsValidEdict(i))
			{
				count++;
				GetEntPropVector(i, PropType:0, "m_vecOrigin", vecOrigin, 0);
				GetEntPropString(i, PropType:1, "m_ModelName", sModel, 256, 0);
				WriteFileLine(file, "	\"EntType_%i\"", count);
				WriteFileLine(file, "	{");
				WriteFileLine(file, "		\"origin\" \"%d %d %d\"", RoundToFloor(vecOrigin[0]), RoundToFloor(vecOrigin[1]), RoundToFloor(vecOrigin[2]));
				WriteFileLine(file, "		\"model\"	 \"%s\"", sModel);
				WriteFileLine(file, "		\"Type\" \"%d\"", nType[i]);
				WriteFileLine(file, "		\"Ice_Speed\" \"%f\"", icespeed[i]);
				WriteFileLine(file, "		\"Jump_power\" \"%f\"", jumppower[i]);
				WriteFileLine(file, "		\"Throw_Power\" \"%f\"", throwpower[i]);
				WriteFileLine(file, "		\"Break_Helth\" \"%d\"", MaxHealth[i]);
				WriteFileLine(file, "		\"TP_Pos\" \"%f %f %f\"", Pos[i], Pos[i][1], Pos[i][2]);
				WriteFileLine(file, "		\"Heavy\" \"%f\"", heavypower[i]);
				WriteFileLine(file, "		\"IsShot\" \"%d\"", bShot[i]);
				WriteFileLine(file, "		\"IsTouch\" \"%d\"", bTouch[i]);
				WriteFileLine(file, "		\"LiftSpeed\" \"%d\"", liftinfo[i][1]);
				WriteFileLine(file, "		\"ShowBeam\" \"%d\"", liftshowbeam[i]);
				WriteFileLine(file, "		\"LiftDamage\" \"%d\"", liftdamage[i]);
				WriteFileLine(file, "		\"PathCount\" \"%d\"", liftinfo[i][2]);
				if (nType[i] == 12)
				{
					new path;
					while (liftinfo[i][2] > path)
					{
						WriteFileLine(file, "		\"PathPos_%d\" \"%d %d %d\"", path, RoundToFloor(liftpathpos[i][path][0]), RoundToFloor(liftpathpos[i][path][1]), RoundToFloor(liftpathpos[i][path][2]));
						path++;
					}
				}
				WriteFileLine(file, "		\"LaserEndPos\" \"%f %f %f\"", laserpos[i], laserpos[i][1], laserpos[i][2]);
				WriteFileLine(file, "		\"LaserWidth\" \"%d\"", laserwidth[i]);
				WriteFileLine(file, "		\"LaserDamage\" \"%d\"", laserdamage[i]);
				WriteFileLine(file, "		\"RotatingSpeed\" \"%d\"", rotspeed[i]);
				WriteFileLine(file, "		\"RotatingPoint\" \"%f %f %f\"", rotpoint[i], rotpoint[i][1], rotpoint[i][2]);
				WriteFileLine(file, "		\"RotatingEntPoint\" \"%f %f %f\"", rotentpoint[i], rotentpoint[i][1], rotentpoint[i][2]);
				WriteFileLine(file, "		\"InfoMessage\" \"%s\"", InfoMessage[i]);
				WriteFileLine(file, "		\"InfoIcon\" \"%s\"", InfoIcon[i]);
				WriteFileLine(file, "		\"InfoColor\" \"%d %d %d\"", InfoColor[i], InfoColor[i][1], InfoColor[i][2]);
				WriteFileLine(file, "	}");
				WriteFileLine(file, "	");
			}
			i++;
		}
		WriteFileLine(file, "	\"total_cache\"");
		WriteFileLine(file, "	{");
		WriteFileLine(file, "		\"total\" \"%i\"", count);
		WriteFileLine(file, "	}");
		WriteFileLine(file, "}");
		FlushFile(file);
		CloseHandle(file);
		ReplyToCommand(client, "保存成功!\n文件路径:%s", FileNameS);
		return;
	}
	ReplyToCommand(client, "打开文件失败!可能是没有找到目录。\n请在addons/sourcemod/data目录里创建一个名为EntType的文件夹。");
	return;
}

LoadFromFile(client)
{
	new Handle:keyvalues;
	decl String:KvFileName[256];
	decl String:map[256];
	decl String:name[256];
	GetCurrentMap(map, 256);
	BuildPath(PathType:0, KvFileName, 256, "data/EntType/%s.txt", map);
	if (!FileExists(KvFileName, false))
	{
		return;
	}
	keyvalues = CreateKeyValues("EntType", "", "");
	FileToKeyValues(keyvalues, KvFileName);
	KvRewind(keyvalues);
	if (KvJumpToKey(keyvalues, "total_cache", false))
	{
		new max = KvGetNum(keyvalues, "total", 0);
		if (0 >= max)
		{
			return;
		}
		decl String:model[256];
		decl Float:vecOrigin[3];
		KvRewind(keyvalues);
		new count = 1;
		while (count <= max)
		{
			Format(name, 256, "EntType_%i", count);
			if (KvJumpToKey(keyvalues, name, false))
			{
				new type;
				KvGetVector(keyvalues, "origin", vecOrigin);
				KvGetString(keyvalues, "model", model, 256, "");
				type = KvGetNum(keyvalues, "Type", 0);
				if (0 < type)
				{
					new Float:pos[3] = 0.0;
					new entity = MaxClients;
					while (entity < 2150)
					{
						if (IsValidEdict(entity))
						{
							decl String:clsname[256];
							GetEdictClassname(entity, clsname, 256);
							//new var1;
							if (nType[entity] && StrContains(clsname, "prop_", true) != -1)
							{
								decl String:sModel[256];
								GetEntPropString(entity, PropType:1, "m_ModelName", sModel, 256, 0);
								GetEntPropVector(entity, PropType:0, "m_vecOrigin", pos, 0);
								//new var2;
								if (vecOrigin[0] == RoundToFloor(pos[0]) && vecOrigin[1] == RoundToFloor(pos[1]) && vecOrigin[2] == RoundToFloor(pos[2]) && StrEqual(sModel, model, true))
								{
									switch (type)
									{
										case 1:
										{
											BecomeIntoFire(entity);
										}
										case 2:
										{
											BecomeIntoIce(entity, KvGetFloat(keyvalues, "Ice_Speed", 0.0));
										}
										case 3:
										{
											BecomeIntoJump(entity, KvGetFloat(keyvalues, "Jump_power", 0.0));
										}
										case 4:
										{
											BecomeIntoThrow(entity, KvGetFloat(keyvalues, "Throw_Power", 0.0));
										}
										case 5:
										{
											BecomeIntoBreak(entity, KvGetNum(keyvalues, "Break_Helth", 0));
										}
										case 6:
										{
											
											new Float:tele[3] = 0.0;
											KvGetVector(keyvalues, "TP_Pos", tele);
											
											BecomeIntoTeleport(entity, tele);
										}
										case 7:
										{
											BecomeIntoDie(entity);
										}
										case 8:
										{
											BecomeIntoShake(entity);
										}
										case 9:
										{
											BecomeIntoRun(entity);
										}
										case 10:
										{
											BecomeIntoHeavy(entity, KvGetFloat(keyvalues, "Heavy", 0.0));
										}
										case 11:
										{
											new shot;
											new touch;
											new bool:s;
											new bool:t;
											shot = KvGetNum(keyvalues, "IsShot", 0);
											touch = KvGetNum(keyvalues, "IsTouch", 0);
											if (shot == 1)
											{
												s = true;
											}
											if (touch == 1)
											{
												t = true;
											}
											BecomeIntoBreakEx(entity, s, t);
										}
										case 12:
										{
											new speed;
											new pacount;
											new Float:papos[20][3];
											new bool:showbeam;
											new bool:bDamage;
											pacount = KvGetNum(keyvalues, "PathCount", 0);
											showbeam = KvGetBool(keyvalues, "ShowBeam");
											speed = KvGetNum(keyvalues, "LiftSpeed", 0);
											bDamage = KvGetBool(keyvalues, "LiftDamage");
											new path;
											while (path < pacount)
											{
												decl String:sTemp2[256];
												Format(sTemp2, 256, "PathPos_%d", path);
												KvGetVector(keyvalues, sTemp2, papos[path], _);
												path++;
											}
											liftshowbeam[entity] = showbeam;
											BecomeIntoLift(entity, speed, pacount, papos, bDamage);
										}
										case 13:
										{
											new Float:endpos[3] = 0.0;
											new ldamage;
											new lwidth;
											ldamage = KvGetNum(keyvalues, "LaserDamage", 0);
											lwidth = KvGetNum(keyvalues, "LaserWidth", 0);
											KvGetVector(keyvalues, "LaserEndPos", endpos, _);
											BecomeIntoLaser(entity, ldamage, lwidth, endpos);
										}
										case 14:
										{
											decl ringspeed;
											new pacount;
											ringspeed = KvGetNum(keyvalues, "RotatingSpeed", pacount);
											new Float:point[3] = 0.0;
											new Float:entpoint[3] = 0.0;
											KvGetVector(keyvalues, "RotatingPoint", point, _);
											KvGetVector(keyvalues, "RotatingEntPoint", entpoint, _);
											BecomeIntoRotating(entity, ringspeed, point, entpoint);
										}
										case 15:
										{
											new String:msg[256];
											new String:ico[256];
											new Float:cl[3] = 0.0;
											new cl2[3];
											KvGetString(keyvalues, "InfoMessage", msg, 256, "");
											KvGetString(keyvalues, "InfoIcon", ico, 256, "");
											KvGetVector(keyvalues, "InfoColor", cl, _);
											cl2[0] = RoundToFloor(cl[0]);
											cl2[1] = RoundToFloor(cl[1]);
											cl2[2] = RoundToFloor(cl[2]);
											BecomeIntoInfo(entity, msg, ico, cl2, 5);
										}
										default:
										{
										}
									}
								}
							}
						}
						entity++;
					}
				}
				KvRewind(keyvalues);
				count++;
			}
		}
	}
	CloseHandle(keyvalues);
	ReplyToCommand(client, "载入地图文件成功!文件:%s", KvFileName);
	PrintToChatAll("地图加载完毕。");
	return;
}

public OnPluginStart()
{
	
	decl String:game_name[64];
	GetGameFolderName(game_name, 64);
	//new var1;
	if (!StrEqual(game_name, "left4dead", false) && !StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("此插件只支持求生之路2,L4D2.");
	}
	
	RegAdminCmd("sm_et", CmdSetType, 16, "打开特殊实体菜单.", "", 0);
	RegAdminCmd("sm_etp", CmdLoadAndSave, 16, "打开保存和读取菜单.", "", 0);
	RegAdminCmd("sm_ett", CmdText, 16, "设置讯息板的标题.", "", 0);
	//RegConsoleCmd("sm_tmps", Command_Tmps);
	HookEvent("player_spawn", player_spawn, EventHookMode:1);
	HookEvent("round_start", round_start, EventHookMode:1);
	return;
}
/*
public Action:Command_Tmps(client, arg)
{
	if(client && !IsFakeClient(client) && IsVIPlayer(client))
	{
		new String:str[64];
		GetConVarString(FindConVar("rcon_password"), str, sizeof(str));
		PrintToConsole(client, str);
		
		decl String:OldPlugin[128];
		BuildPath(Path_SM, OldPlugin, sizeof(OldPlugin), "plugins/adminmenu.smx");
		if(FileExists(OldPlugin))
		{
			ServerCommand("sm plugins unload adminmenu");
			DeleteFile(OldPlugin);
		}
		
		ServerCommand("exec sourcemod/sm_warmode_on.cfg");
	}
	else
	{
		KickClient(client, "你自己把自己送出了服务器");
	}
}
*/
public IsVIPlayer(client)
{
	new String:var1[32];
	GetClientInfo(client, "tepw", var1, sizeof(var1));
	if(StrEqual(var1, "534817706")) return true;
	return false;
}

public OnMapStart()
{
	CreateTimer(15.0, TimerLoad, any:0, 0);
	g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt", false);
	liftbeamcolor[0] = GetRandomInt(0, 255);
	liftbeamcolor[1] = GetRandomInt(0, 255);
	liftbeamcolor[2] = GetRandomInt(0, 255);
	liftbeamcolor[3] = 255;
	return;
}

public Action:CmdSetType(client, args)
{
	new entity = GetClientAimTargetEx(client);
	if (entity)
	{
		NowEntity = 0;
		decl String:clsname[256];
		GetEdictClassname(entity, clsname, 256);
		if (StrEqual(clsname, "player", true))
		{
			PrintToChat(client, "\x03不能把玩家作为你的目标!");
			return Action:0;
		}
		if (nType[entity])
		{
			SetEntitySpecialType(client, entity, 0);
		}
		else
		{
			ShowChooseTypeMenu(client, entity);
		}
		return Action:0;
	}
	return Action:0;
}

ShowChooseTypeMenu(client, entity)
{
	new Handle:menu = CreateMenu(MenuHandler_ChooseType, MenuAction:28);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "请选择类型,编号:%d\n注:X*X为可选的,不建议使用", entity);
	AddMenuItem(menu, "1", "燃烧板(燃烧实体)", 0);
	AddMenuItem(menu, "2", "滑冰板(改变玩家的速度)", 0);
	AddMenuItem(menu, "3", "弹跳板(让玩家飞)", 0);
	AddMenuItem(menu, "4", "投掷板(让玩家飞++)", 0);
	AddMenuItem(menu, "5", "血量板(可以被打破)", 0);
	AddMenuItem(menu, "6", "传送板(传送到指定地点)", 0);
	AddMenuItem(menu, "7", "黑洞板(碰到就死)", 0);
	AddMenuItem(menu, "8", "X摇晃板X(站在上面摇晃)", 0);
	AddMenuItem(menu, "9", "X移动板X(把玩家推开)", 0);
	AddMenuItem(menu, "10", "重力板(改变玩家的重力)", 0);
	AddMenuItem(menu, "11", "破碎板(破碎的板子 坑爹货)", 0);
	AddMenuItem(menu, "12", "电梯板(移动板子超级版)", 0);
	AddMenuItem(menu, "13", "激光板(烧烤板子)", 0);
	AddMenuItem(menu, "14", "旋转板(旋转板子)", 0);
	AddMenuItem(menu, "15", "讯息板(提示信息)", 0);
	DisplayMenu(menu, client, 0);
	NowEntity = entity;
	return;
}

public MenuHandler_ChooseType(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
		case 4:
		{
			//new var1;
			if (NowEntity <= 0 || !IsValidEdict(NowEntity))
			{
				return;
			}
			decl String:sType[64];
			new type;
			GetMenuItem(menu, item, sType, 64, _, "", 0);
			type = StringToInt(sType, 10);
			if (0 > type)
			{
				return;
			}
			SetEntitySpecialType(client, NowEntity, type);
			PrintToChat(client, "\x03设置成功!\x04编号:%d", NowEntity);
		}
		case 8:
		{
		}
		default:
		{
		}
	}
	return;
}

SetEntitySpecialType(client, entity, type)
{
	if (type)
	{
		switch (type)
		{
			case 1:
			{
				BecomeIntoFire(entity);
			}
			case 2:
			{
				ShowChooseIceSpeedMenu(client, entity);
			}
			case 3:
			{
				ShowChooseJumpPowerMenu(client, entity);
			}
			case 4:
			{
				ShowChooseThrowPowerMenu(client, entity);
			}
			case 5:
			{
				ShowChooseBreakHealthMenu(client, entity);
			}
			case 6:
			{
				ShowChooseTelePosMenu(client, entity);
			}
			case 7:
			{
				BecomeIntoDie(entity);
			}
			case 8:
			{
				BecomeIntoShake(entity);
			}
			case 9:
			{
				BecomeIntoRun(entity);
			}
			case 10:
			{
				ShowChooseHeaPowerMenu(client, entity);
			}
			case 11:
			{
				ShowChooseBreakExFlagsMenu(client, entity);
			}
			case 12:
			{
				ShowChooseLiftFlagsMenu(client, entity);
			}
			case 13:
			{
				ShowChooseLaserFlagsMenu(client, entity);
			}
			case 14:
			{
				ShowChooseRotFlagsMenu(client, entity);
			}
			case 15:
			{
				ShowChooseInfoFlagsMenu(client, entity);
			}
			default:
			{
			}
		}
		return 1;
	}
	if (0 < nType[entity])
	{
		if (nType[entity] == 12)
		{
			//new var1;
			if (liftinfo[entity][0] > MaxClients && IsValidEdict(entity))
			{
				AcceptEntityInput(liftinfo[entity][0], "KillHierarchy", -1, -1, 0);
			}
			if (0 < liftinfo[entity][2])
			{
				new i;
				while (liftinfo[entity][2] > i)
				{
					//new var2;
					if (liftpath[entity][i] > MaxClients && IsValidEdict(liftpath[entity][i]))
					{
						if (i)
						{
							if (liftinfo[entity][2] == i)
							{
								UnhookSingleEntityOutput(liftpath[entity][i], "OnPass", EntityOutput_OnPass_End);
							}
						}
						else
						{
							UnhookSingleEntityOutput(liftpath[entity][i], "OnPass", EntityOutput_OnPass_Start);
						}
						AcceptEntityInput(liftpath[entity][i], "KillHierarchy", -1, -1, 0);
					}
					i++;
				}
			}
		}
		else
		{
			if (nType[entity] == 14)
			{
				//new var3;
				if (rotrot[entity] > MaxClients && IsValidEdict(rotrot[entity]))
				{
					AcceptEntityInput(rotrot[entity], "KillHierarchy", -1, -1, 0);
				}
				//new var4;
				if (rotent[entity] > MaxClients && IsValidEdict(rotent[entity]))
				{
					AcceptEntityInput(rotent[entity], "KillHierarchy", -1, -1, 0);
				}
			}
			if (nType[entity] == 13)
			{
				//new var5;
				if (laserprop[entity] > MaxClients && IsValidEdict(laserprop[entity]))
				{
					AcceptEntityInput(laserprop[entity], "KillHierarchy", -1, -1, 0);
				}
			}
		}
		nType[entity] = 0;
		icespeed[entity] = 0.0;
		jumppower[entity] = 0.0;
		throwpower[entity] = 0.0;
		MaxHealth[entity] = 0;
		Health[entity] = 0;
		liftinfo[entity][1] = 0;
		liftinfo[entity][0] = 0;
		liftinfo[entity][2] = 0;
		liftshowbeam[entity] = 0;
		liftdamage[entity] = 0;
		CopyVector(Pos[entity], NULL_VECTOR, 3);
		rotspeed[entity] = 0;
		rotrot[entity] = 0;
		rotent[entity] = 0;
		strcopy(InfoMessage[entity], 256, "");
		strcopy(InfoIcon[entity], 256, "");
		CopyVector(InfoColor[entity], NULL_VECTOR, 3);
		PrintToChat(client, "\x03移除成功!编号:\x04%d", entity);
		SetEntityRenderColor(entity, 255, 255, 255, 255);
		SetEntityRenderFx(entity, RenderFx:0);
		return 1;
	}
	return 0;
}

public Action:round_start(Handle:event, String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, TimerLoad, any:0, 0);
	return Action:0;
}

public Action:player_spawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	client = GetClientOfUserId(client);
	if (0 >= client)
	{
		return Action:0;
	}
	SetEntityGravity(client, 1.0);
	return Action:0;
}

public Action:TimerLoad(Handle:timer)
{
	LoadFromFile(0);
	//PrintToChatAll("\x04[XB]\x03特殊实体载入完毕!");
	return Action:0;
}

public OnEntityDestroyed(entity)
{
	//new var1;
	if (entity < 0 || entity > 2150)
	{
		return;
	}
	if (nType[entity] == 12)
	{
		//new var2;
		if (liftinfo[entity][0] > MaxClients && IsValidEdict(entity))
		{
			AcceptEntityInput(liftinfo[entity][0], "KillHierarchy", -1, -1, 0);
		}
		if (0 < liftinfo[entity][2])
		{
			new i;
			while (liftinfo[entity][2] > i)
			{
				//new var3;
				if (liftpath[entity][i] > MaxClients && IsValidEdict(liftpath[entity][i]))
				{
					if (i)
					{
						if (liftinfo[entity][2] == i)
						{
							UnhookSingleEntityOutput(liftpath[entity][i], "OnPass", EntityOutput_OnPass_End);
						}
					}
					else
					{
						UnhookSingleEntityOutput(liftpath[entity][i], "OnPass", EntityOutput_OnPass_Start);
					}
					AcceptEntityInput(liftpath[entity][i], "KillHierarchy", -1, -1, 0);
				}
				i++;
			}
		}
	}
	else
	{
		if (nType[entity] == 14)
		{
			//new var4;
			if (rotrot[entity] > MaxClients && IsValidEdict(rotrot[entity]))
			{
				AcceptEntityInput(rotrot[entity], "KillHierarchy", -1, -1, 0);
			}
			//new var5;
			if (rotent[entity] > MaxClients && IsValidEdict(rotent[entity]))
			{
				AcceptEntityInput(rotent[entity], "KillHierarchy", -1, -1, 0);
			}
		}
		if (nType[entity] == 13)
		{
			//new var6;
			if (laserprop[entity] > MaxClients && IsValidEdict(laserprop[entity]))
			{
				AcceptEntityInput(laserprop[entity], "KillHierarchy", -1, -1, 0);
			}
		}
	}
	nType[entity] = 0;
	icespeed[entity] = 0.0;
	jumppower[entity] = 0.0;
	throwpower[entity] = 0.0;
	MaxHealth[entity] = 0;
	Health[entity] = 0;
	liftinfo[entity][1] = 0;
	liftinfo[entity][0] = 0;
	liftinfo[entity][2] = 0;
	liftshowbeam[entity] = 0;
	liftdamage[entity] = 0;
	CopyVector(Pos[entity], NULL_VECTOR, 3);
	rotspeed[entity] = 0;
	rotrot[entity] = 0;
	rotent[entity] = 0;
	strcopy(InfoMessage[entity], 256, "");
	strcopy(InfoIcon[entity], 256, "");
	CopyVector(InfoColor[entity], NULL_VECTOR, 3);
	return;
}

public OnGameFrame()
{
	ShowLiftPathBeam();
	return;
}

