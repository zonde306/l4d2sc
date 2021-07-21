#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <sourcescramble>

public Plugin myinfo =
{
    name = "[L4D2] Tickrate Enabler",
    author = "BHaType & Satanic Spirit"
};

enum struct IContext
{
	ConVar l4d2_tickrate_enabler_tick;
	ConVar l4d2_tickrate_enabler_auto_rates;
	
	Address interval_per_tick;
	Address sv_tick;
}

IContext context;

MemoryBlock gGlobals, gpGlobals;
MemoryPatch set_data_rate, clamp_client_rate, net_channel_rate;

public void OnPluginStart()
{
	FindConVar("sv_maxrate").SetBounds(ConVarBound_Upper, false, 0.0);
	FindConVar("sv_minrate").SetBounds(ConVarBound_Upper, false, 0.0);
	FindConVar("net_splitpacket_maxrate").SetBounds(ConVarBound_Upper, false, 0.0);
	
	GameData data = new GameData("l4d2_tickrate_enabler");
	
	set_data_rate = MemoryPatch.CreateFromConf(data, "set_data_rate"); 			
	clamp_client_rate = MemoryPatch.CreateFromConf(data, "clamp_client_rate"); 	
	net_channel_rate = MemoryPatch.CreateFromConf(data, "net_channel_rate");
	
	set_data_rate.Enable();
	clamp_client_rate.Enable();	
	net_channel_rate.Enable();
	
	context.interval_per_tick = data.GetAddress("interval_per_tick");
	context.sv_tick = data.GetAddress("sv_tick");
	
	FixBoomer(data);
	
	delete data;
	
	context.l4d2_tickrate_enabler_auto_rates = CreateConVar("l4d2_tickrate_enabler_auto_rates", "1", "Enable auto rates updater", FCVAR_NONE, true, 0.0, true, 1.0);
	
	context.l4d2_tickrate_enabler_tick = CreateConVar("l4d2_tickrate_enabler_tick", "67.0", "Desired server tickrate.", FCVAR_NONE, true, 0.0);
	context.l4d2_tickrate_enabler_tick.AddChangeHook(OnTickrateChanged);
	
	AutoExecConfig(true, "l4d2_tickrate_enabler");
	
	SetTickrate(context.l4d2_tickrate_enabler_tick.FloatValue);
}

public void OnTickrateChanged (ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetTickrate(StringToFloat(newValue));
}

void FixBoomer(GameData data)
{
	static int offs[2][3] =
	{
		{ 0x1E5, 0x377, 0x544 },
		{ 0x13E, 0x5FF, 0 }
	};
	
	gGlobals = new MemoryBlock(0x14);
	gGlobals.StoreToOffset(16, view_as<int>(0.033333333), NumberType_Int32);
	
	gpGlobals = new MemoryBlock(4);
	gpGlobals.StoreToOffset(0, view_as<int>(gGlobals.Address), NumberType_Int32);
	
	Address vomit = data.GetAddress("CVomit::UpdateAbility");
	
	int os = data.GetOffset("OS");
	
	for (int i; i < os >> 2; i++)
	{
		StoreToAddress(vomit + view_as<Address>(offs[os & 1][i]), view_as<int>(gpGlobals.Address), NumberType_Int32);
	}
}

void SetTickrate (float tickrate)
{
	float final_tickrate = 1.0 / tickrate;
	
	StoreToAddress(context.interval_per_tick, view_as<int>(final_tickrate), NumberType_Int32);
	StoreToAddress(context.sv_tick, view_as<int>(final_tickrate), NumberType_Int32);
	
	if ( context.l4d2_tickrate_enabler_auto_rates.BoolValue )
	{
		UpdateRates(tickrate);
	}
}

void UpdateRates (float tickrate)
{
	FindConVar("sv_minrate").FloatValue = tickrate * 1000.0;
	FindConVar("sv_maxrate").FloatValue = tickrate * 1000.0;
	FindConVar("sv_minupdaterate").FloatValue = tickrate;
	FindConVar("sv_maxupdaterate").FloatValue = tickrate;
	FindConVar("sv_mincmdrate").FloatValue = tickrate;
	FindConVar("sv_maxcmdrate").FloatValue = tickrate;
	FindConVar("net_splitpacket_maxrate").FloatValue = tickrate / 2.0 * 1000;
}