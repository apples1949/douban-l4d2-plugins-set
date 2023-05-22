#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION	"2.0.2"
#define CVAR_FLAGS		FCVAR_NOTIFY

int    g_iTickSwitch, g_iTickRate, g_iTickFPS;
ConVar g_hTickSwitch, g_hTickRate, g_hTickFPS;

int g_iMinRate, g_iMaxRate, g_iMinCmdRate, g_iMaxCmdRate, g_iMinUpdateRate, g_iMaxUpdateRate, g_iNetMaxRate;

public Plugin myinfo = 
{
	name = "设置服务器tick",
	author = "豆瓣酱な",
	description = "根据启动项的值自动设置tick参数",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("l4d_tickrate_version", PLUGIN_VERSION, "设置服务器tick插件的版本.(注意:启动项的值决定服务器的最大tick,没有设置启动项则使用默认值30.)", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);

	g_hTickSwitch	= CreateConVar("l4d2_tickrate", 		"1",	"启用自动设置服务器tick插件? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hTickRate		= CreateConVar("l4d2_tickrate_enabler", "100",	"设置服务器的tick(最大值:100).\n注意:必须安装tick解锁扩展才能设置30tick以上.", CVAR_FLAGS);
	g_hTickFPS		= CreateConVar("l4d2_tickrate_fps_max", "0", 	"设置服务器的FPS(必须大于tick). 0=不限制.", CVAR_FLAGS);

	g_hTickSwitch.AddChangeHook(ConVarChangedTickRate);
	g_hTickRate.AddChangeHook(ConVarChangedTickRate);
	g_hTickFPS.AddChangeHook(ConVarChangedTickRate);

	AutoExecConfig(true, "l4d2_tickrate_enabler");
}

public void OnMapStart()
{
	IsTickCvars();
}

public void ConVarChangedTickRate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsTickCvars();
}

void IsTickCvars()
{
	g_iTickSwitch = g_hTickSwitch.IntValue;

	if (g_iTickSwitch <= 0)
		return;
	
	g_iTickRate = g_hTickRate.IntValue;

	if (g_iTickRate > 100)
		g_iTickRate = 100;

	g_iTickFPS = g_hTickFPS.IntValue;

	if (g_iTickFPS > 0)
		if (g_iTickFPS < 100)
			g_iTickFPS = 100;
}

public void OnConfigsExecuted()
{
	if (g_iTickSwitch <= 0)
		return;
		
	IsSetTickRate();
}

//获取启动项-tickrate的值.
void IsSetTickRate()
{
	int g_iStartupItem = GetCommandLineParamInt("-tickrate", 30);//没有获取到启动项的值则使用这里的默认值:30.
	
	if(g_iStartupItem < g_iTickRate)
		g_iTickRate = g_iStartupItem;
	
	IsSetServerTick();//设置tick参数.
}

//设置tick参数.
void IsSetServerTick()
{
	g_iMinRate			= g_iTickRate * 1000;
	g_iMaxRate			= g_iTickRate * 1000;
	g_iMinCmdRate		= g_iTickRate;
	g_iMaxCmdRate		= g_iTickRate;
	g_iMinUpdateRate	= g_iTickRate;
	g_iMaxUpdateRate	= g_iTickRate;
	g_iNetMaxRate		= RoundFloat((float(g_iTickRate) / 2.0) * 1000.0);
	
	SetConVarInt(FindConVar("fps_max"), g_iTickFPS, false, false);
	SetConVarInt(FindConVar("sv_minrate"), g_iMinRate, false, false);
	SetConVarInt(FindConVar("sv_maxrate"), g_iMaxRate, false, false);
	SetConVarInt(FindConVar("sv_mincmdrate"), g_iMinCmdRate, false, false);
	SetConVarInt(FindConVar("sv_maxcmdrate"), g_iMaxCmdRate, false, false);
	SetConVarInt(FindConVar("sv_minupdaterate"), g_iMinUpdateRate, false, false);
	SetConVarInt(FindConVar("sv_maxupdaterate"), g_iMaxUpdateRate, false, false);
	SetConVarInt(FindConVar("net_splitpacket_maxrate"), g_iNetMaxRate, false, false);
	SetConVarInt(FindConVar("net_splitrate"), 2, false, false);
	SetConVarFloat(FindConVar("net_maxcleartime"), 0.0001, false, false);
	SetConVarFloat(FindConVar("nb_update_frequency"), 0.024, false, false);

	if (g_iTickRate > 30)//设置的tick大于30,所以这里验证下设置tick成功没有
		RequestFrame(IsVerifyServerTick);//延迟一帧获取服务器的tick值.
}

//获取服务器的tick值.
void IsVerifyServerTick()
{
	int g_iGetTick = RoundToNearest(1.0 / GetTickInterval());//如果没有安装tick解锁扩展的话这个值最大为:30.

	if (g_iTickRate > g_iGetTick)//需要设置的tick大于服务器当前的tick,可能是设置30tick以上失败.
	{
		g_iTickRate = g_iGetTick;//把当前获取到的服务器tick值用来重新设置tick.
		IsSetServerTick();//使用新值重新设置服务器tick.
	}
}