/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v2.1.5
 *
 *	1:参数nb_update_frequency新增根据tick自动设置(该方法嫖至:fdxx).
 *	2:修复IsWriteValues函数回调里忘记删除句柄.
 *
 *	v2.1.6
 *
 *	1:因为扩展新增支持tick最大值,但是插件忘记改成128了.
 *
 *	v2.1.7
 *
 *	1:修复nb_update_frequency参数自动设置错误的问题(手抖多按了个0).
 *
 *	v2.1.8
 *
 *	1:好家伙,上一个版本的问题源码改了没编译替换.
 *
 *	v2.2.8
 *
 *	1:增加管理员菜单更改服务器tick值.
 *	2:第二个值是根据启动项值锁的,这是tick解锁扩展作者这样设计的.
 *
 *	v2.2.9
 *
 *	1:插件开始函数里的新建或读取文件内容函数位置顺序好像不太对.
 *
 *	v2.3.9
 *
 *	1:修复管理员更改服务器tick后客户端显示的最大tick值不正确的问题.
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION	"2.3.9"
#define CVAR_FLAGS		FCVAR_NOTIFY
#define MIN_TICK_RATE		20			//定义启动项最小值.
#define MAX_TICK_RATE		128			//定义启动项最大值.
#define MAX_PLAYERS		32

int 
	g_iTickRate,
	g_iTickValue,
	g_iTickInterval;

char g_sKvPath[PLATFORM_MAX_PATH];

bool g_bShouldIgnore[MAX_PLAYERS+1];

TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;

Handle 
	g_hMinRate,
	g_hMaxRate,
	g_hMinCmdRate,
	g_hMaxCmdRate,
	g_hMinUpDateRate,
	g_hMaxUpDateRate;

char g_sWrite[][][] = 
{
	{"启用设置服务器tick插件? 0=禁用, 1=启用.", "1"},
	{"设置服务器的最大tick(最大值:100)(注意:需要安装tick解锁扩展).", "100"},
	{"设置服务器的最大FPS帧率(需要注意FPS必须大于tick). 0=不限制.", "0"},
	{"设置客户端的sv_client_min_interp_ratio值(lerp). -1=客户端自行设置.", "-1"},
	{"设置客户端的sv_client_max_interp_ratio值(lerp),当sv_client_min_interp_ratio的值为-1时此参数无效.", "0"},
	{"设置每帧可发送的拆分数据包的片段数(默认值:1).", "2"},
	{"设置服务器世界的更新频率(默认值:0.1),数值越低丧尸和女巫的更新频率越高,非常耗费CPU. 0=自动设置", "0"},
	{"根据速率设置,等待发送下一个数据包的最大秒数(默认值:4). 0=无限制.", "0.0001"}
	
};
//定义插件信息.
public Plugin myinfo = 
{
	name = "设置服务器tick参数",
	author = "豆瓣酱な",
	description = "根据启动项的值自动设置tick相关参数",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始.
public void OnPluginStart()
{
	HookEvent("player_team", Event_PlayerTeam);//玩家转换队伍.
	
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_tickrate_enabler.cfg");

	g_iTickRate = GetCommandLineParamInt("-tickrate", MIN_TICK_RATE);//没有获取到启动项的值则使用这里的默认值:20.
	g_iTickRate = GetTickValue(g_iTickRate, MIN_TICK_RATE, MAX_TICK_RATE);
	g_iTickInterval = RoundToNearest(1.0 / GetTickInterval());//如果没有安装tick解锁扩展的话这个值最大为:30.
	
	RegConsoleCmd("sm_tick", Command_TickMenu, "更改tick菜单.");
	RegConsoleCmd("sm_tickcvar", Command_PrintCvar, "查询tick参数.");
	CreateConVar("l4d2_tickrate_version", PLUGIN_VERSION, "设置服务器tick插件的版本.", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);

	g_hMinRate = FindConVar("sv_minrate");//设置允许的最小带宽速率. 0=无限制.
	g_hMaxRate = FindConVar("sv_maxrate");//设置允许的最大带宽速率(这个设置0即可). 0=无限制.
	g_hMinUpDateRate = FindConVar("sv_minupdaterate");//设置服务器每秒允许的最小更新数(默认值:10).
	g_hMaxUpDateRate = FindConVar("sv_maxupdaterate");//设置服务器每秒允许的最大更新数(默认值:60).
	g_hMinCmdRate = FindConVar("sv_mincmdrate");//不清楚有什么用.
	g_hMaxCmdRate = FindConVar("sv_maxcmdrate");//不清楚有什么用.

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	//新建或读取文件内容.
	vCreateReadFile();
}
//地图加载后调用.
public void OnConfigsExecuted()
{
	vCreateReadFile();
}
//新建或读取文件内容.
void vCreateReadFile()
{
	KeyValues kv = new KeyValues("Values");
	
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		//写入默认内容.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.SetString(g_sWrite[i][0], g_sWrite[i][1]);
			
		// 返回上一页.
		kv.Rewind();
		// 把内容写入文件.
		kv.ExportToFile(g_sKvPath);
	}
	else if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
	{
		char sData[sizeof(g_sWrite)][128];
		// 获取Kv文本内信息写入变量中.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.GetString(g_sWrite[i][0], sData[i], sizeof(sData[]), g_sWrite[i][1]);
			
		g_iTickValue = StringToInt(sData[1]);

		if (StringToInt(sData[0]) > 0)
			SetServerTickConVar(GetMaxTickInterval(GetTickValue(StringToInt(sData[1]), MIN_TICK_RATE, MAX_TICK_RATE)), 
			GetMaxFps(StringToInt(sData[2])), StringToInt(sData[3]), StringToInt(sData[4]), StringToInt(sData[5]), StringToFloat(sData[6]), StringToFloat(sData[7]));
	}
	else{}//文件读取失败.
	delete kv;
}
//根据启动项值设置最大tick(嫖至fdxx大佬的方法).
int GetTickValue(int value, int min, int max)
{
	if (value < min)
		return min;
	if (value > max)
		return max;
	return value;
}
//获取服务器最大tick值.
int GetMaxTickInterval(int value)
{
	if (value > g_iTickInterval)
		value = g_iTickInterval;
	return value;
}
//PFS必须大于或等于Tick.
int GetMaxFps(int iMaxFps)
{
	if (iMaxFps == 0)
		return iMaxFps;
	if (iMaxFps < g_iTickRate)
		iMaxFps = g_iTickRate;
	return iMaxFps;
}
//设置tick相关参数.
void SetServerTickConVar(int iMaxTick, int iMaxFps, int iMinRatio, int iMaxRatio, int iSplitrate, float fFrequency, float fMaxcleartime)
{
	int iMinRate		= iMaxTick * 1000;
	//int iMaxRate		= iMaxTick * 1000;
	int iMinCmdRate		= iMaxTick;
	int iMaxCmdRate		= iMaxTick;
	int iMinUpDateRate	= iMaxTick;
	int iMaxUpDateRate	= iMaxTick;
	int iNetMaxRate		= RoundFloat((float(iMaxTick) / 2.0) * 1000.0);

	SetConVarInt(FindConVar("fps_max"), iMaxFps, false, false);//设置服务器的最大帧率. 0=无限制.
	SetConVarInt(FindConVar("sv_minrate"), iMinRate, false, false);//设置允许的最小带宽速率. 0=无限制.
	SetConVarInt(FindConVar("sv_maxrate"), 0, false, false);//设置允许的最大带宽速率(这个设置0即可). 0=无限制.
	SetConVarInt(FindConVar("sv_mincmdrate"), iMinCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_maxcmdrate"), iMaxCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_minupdaterate"), iMinUpDateRate, false, false);//设置服务器每秒允许的最小更新数(默认值:10).
	SetConVarInt(FindConVar("sv_maxupdaterate"), iMaxUpDateRate, false, false);//设置服务器每秒允许的最大更新数(默认值:60).
	SetConVarInt(FindConVar("net_splitpacket_maxrate"), iNetMaxRate, false, false);//排队拆分数据包块时每秒的最大字节数.
	SetConVarInt(FindConVar("net_splitrate"), iSplitrate, false, false);//设置每帧可发送的拆分数据包的片段数(默认值:1).
	SetConVarInt(FindConVar("sv_client_min_interp_ratio"), iMinRatio, false, false);//设置客户端的最小lerp值(仅当客户端已连接时). -1 = 客户端自行设置.
	SetConVarInt(FindConVar("sv_client_max_interp_ratio"), iMaxRatio, false, false);//设置客户端的最大lerp值(仅当客户端已连接时),当sv_client_min_interp_ratio设为-1时此cvar无效.
	SetConVarFloat(FindConVar("net_maxcleartime"), fMaxcleartime, false, false);//根据速率设置,等待发送下一个数据包的最大秒数(默认值:4). 0=无限制.
	SetConVarFloat(FindConVar("nb_update_frequency"), GetMaxClearTime(iMaxTick, fFrequency), false, false);//设置服务器世界的更新频率(默认值:0.1),数值越低丧尸和女巫的更新频率越高,非常耗费CPU. 0=自动设置.
}
//根据tick自动设置(嫖至fdxx大佬的方法).
float GetMaxClearTime(int iMaxTick, float fFrequency)
{
	if(fFrequency <= 0)//这里使用自动设置.
	{
		if(iMaxTick <= 30)
			return fFrequency = 0.1;
		else if(iMaxTick <= 60)
			return fFrequency = 0.024;
		else if(60 < iMaxTick < 100)
			return fFrequency = 0.024 - (0.00035 * (iMaxTick - 60));
		else if(iMaxTick >= 100)
			return fFrequency = 0.01;
	}
	return fFrequency;
}
//指令回调.
Action Command_PrintCvar(int client, int args)
{
	ReplyToCommand(client, "---------- %s ----------", PLUGIN_VERSION);

	ReplyToCommand(client, "%-28s = %i",	"fps_max",						GetConVarInt(FindConVar("fps_max")));
	ReplyToCommand(client, "%-28s = %i",	"tickrate",						g_iTickRate);
	ReplyToCommand(client, "%-28s = %i",	"tickinterval",					g_iTickInterval);
	ReplyToCommand(client, "%-28s = %i",	"sv_minrate",					GetConVarInt(FindConVar("sv_minrate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_maxrate",					GetConVarInt(FindConVar("sv_maxrate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_mincmdrate",				GetConVarInt(FindConVar("sv_mincmdrate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_maxcmdrate",				GetConVarInt(FindConVar("sv_maxcmdrate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_minupdaterate",				GetConVarInt(FindConVar("sv_minupdaterate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_maxupdaterate",				GetConVarInt(FindConVar("sv_maxupdaterate")));
	ReplyToCommand(client, "%-28s = %i",	"net_splitpacket_maxrate",		GetConVarInt(FindConVar("net_splitpacket_maxrate")));
	ReplyToCommand(client, "%-28s = %i",	"net_splitrate",				GetConVarInt(FindConVar("net_splitrate")));
	ReplyToCommand(client, "%-28s = %i",	"sv_client_min_interp_ratio",	GetConVarInt(FindConVar("sv_client_min_interp_ratio")));
	ReplyToCommand(client, "%-28s = %i",	"sv_client_max_interp_ratio",	GetConVarInt(FindConVar("sv_client_max_interp_ratio")));
	ReplyToCommand(client, "%-28s = %.6f",	"net_maxcleartime",				GetConVarFloat(FindConVar("net_maxcleartime")));
	ReplyToCommand(client, "%-28s = %.5f",	"nb_update_frequency",			GetConVarFloat(FindConVar("nb_update_frequency")));

	return Plugin_Handled;
}
//卸载函数库.
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu = null;
}
//添加管理员菜单.
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;
	
	g_hTopMenu = topmenu;
	
	TopMenuObject hTopMenuObject = FindTopMenuCategory(g_hTopMenu, "OtherFeatures");
	if (hTopMenuObject == INVALID_TOPMENUOBJECT)
		hTopMenuObject = AddToTopMenu(g_hTopMenu, "OtherFeatures", TopMenuObject_Category, hMenuHandler, INVALID_TOPMENUOBJECT);
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_tick",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_tick",ADMFLAG_ROOT);
}
//管理员菜单回调.
void hMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);
	}
}
//管理员菜单回调.
void hHandlerMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hOtherFeatures)
			Format(buffer, maxlength, "更改tick", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			OpenTickMenu(param, 0, true);
		}
	}
}
//更改tick菜单.
Action Command_TickMenu(int client, int args)
{
	if(bCheckClientAccess(client))
		OpenTickMenu(client, 0, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用该指令.");
	return Plugin_Handled;
}
//判断管理员权限.
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
//打开tick选择菜单.
void OpenTickMenu(int client, int index, bool bButton = false)
{
	char sLine[128], sData[128], sInfo[2][32];
	Menu menu = new Menu(MenuBanListHandler);
	Format(sLine, sizeof(sLine), "选择tick:\n ");
	menu.SetTitle("%s", sLine);

	for (int i = g_iTickRate > g_iTickInterval ? g_iTickInterval : g_iTickRate; i >= MIN_TICK_RATE; i--)
	{
		IntToString(i, sInfo[0], sizeof(sInfo[]));
		IntToString(bButton, sInfo[1], sizeof(sInfo[]));
		ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.
		menu.AddItem(sData, sInfo[0]);
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}
//菜单回调.
int MenuBanListHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128], sName[32], sInfo[2][32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			PrintToChat(client, "\x04[提示]\x05已更改全部玩家为\x03%s\x05tick值.", sInfo[0]);
			VUpdateConfigurationFile(client, sInfo[0]);
			g_iTickValue = StringToInt(sInfo[0]);
			OpenTickMenu(client, menu.Selection, view_as<bool>(StringToInt(sInfo[1])));
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}
//更新文件内容.
void VUpdateConfigurationFile(int client, char[] sMaxTick)
{
	KeyValues kv = new KeyValues("Values");
	
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		//写入默认内容.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.SetString(g_sWrite[i][0], g_sWrite[i][1]);
			
		// 返回上一页.
		kv.Rewind();
		// 把内容写入文件.
		if(kv.ExportToFile(g_sKvPath))//写入文件成功.
			VUpdateConfigurationFile(client, sMaxTick);
	}
	else if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
	{
		char sData[sizeof(g_sWrite)][128];
		// 获取Kv文本内信息写入变量中.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.GetString(g_sWrite[i][0], sData[i], sizeof(sData[]), g_sWrite[i][1]);
		
		strcopy(sData[1], sizeof(sData[]), sMaxTick);

		kv.SetString(g_sWrite[1][0], sMaxTick);//写入指定的内容.
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_sKvPath);//把数据写入到文件.
		
		if (StringToInt(sData[0]) > 0)
		{
			UpdateServerTickConVar(GetMaxTickInterval(GetTickValue(StringToInt(sData[1]), MIN_TICK_RATE, MAX_TICK_RATE)), StringToFloat(sData[6]));
			SetAllClientTick(StringToInt(sMaxTick));//设置全部玩家tick.
		}
	}
	else//文件读取失败.
	{
		PrintToChat(client, "\x04[提示]\x05读取文件失败,设置tick失败.");
		//SetAllClientTick(MIN_TICK_RATE);//设置全部玩家tick.
	}
	delete kv;
}
//更新tick相关参数.
void UpdateServerTickConVar(int iMaxTick, float fFrequency)
{
	int iMinRate		= iMaxTick * 1000;
	//int iMaxRate		= iMaxTick * 1000;
	int iMinCmdRate		= iMaxTick;
	int iMaxCmdRate		= iMaxTick;
	int iMinUpDateRate	= iMaxTick;
	int iMaxUpDateRate	= iMaxTick;
	int iNetMaxRate		= RoundFloat((float(iMaxTick) / 2.0) * 1000.0);

	SetConVarInt(FindConVar("sv_minrate"), iMinRate, false, false);//设置允许的最小带宽速率. 0=无限制.
	SetConVarInt(FindConVar("sv_maxrate"), 0, false, false);//设置允许的最大带宽速率(这个设置0即可). 0=无限制.
	SetConVarInt(FindConVar("sv_mincmdrate"), iMinCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_maxcmdrate"), iMaxCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_minupdaterate"), iMinUpDateRate, false, false);//设置服务器每秒允许的最小更新数(默认值:10).
	SetConVarInt(FindConVar("sv_maxupdaterate"), iMaxUpDateRate, false, false);//设置服务器每秒允许的最大更新数(默认值:60).
	SetConVarInt(FindConVar("net_splitpacket_maxrate"), iNetMaxRate, false, false);//排队拆分数据包块时每秒的最大字节数.
	SetConVarFloat(FindConVar("nb_update_frequency"), GetMaxClearTime(iMaxTick, fFrequency), false, false);//设置服务器世界的更新频率(默认值:0.1),数值越低丧尸和女巫的更新频率越高,非常耗费CPU. 0=自动设置.
}
//设置全部玩家tick.
stock void SetAllClientTick(int value)
{
	for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && !IsFakeClient(i))
            SetClientTickConVar(i, value);
}
//玩家连接游戏时.
public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client))
		g_bShouldIgnore[client] = true;
}
//玩家转换队伍.
void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int iTeam = event.GetInt("team");
	
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		if(oldteam == 0 && iTeam != 0 && g_bShouldIgnore[client] == true)
		{
			g_bShouldIgnore[client] = false;
			SetClientTickConVar(client, g_iTickValue);
			//PrintToChatAll("\x04[换队]\x05(%d)(%N)团队(%d).", client, client, iTeam);
		}
	}
}
//设置玩家tick值.
stock void SetClientTickConVar(int client, int value)
{
	char sData[2][32];
	IntToString(value, sData[0], sizeof(sData[]));
	IntToString(value * 1000, sData[1], sizeof(sData[]));
	//设置tick相关值.
	SendConVarValue(client, g_hMinCmdRate, sData[0]);
	SendConVarValue(client, g_hMaxCmdRate, sData[0]);
	SendConVarValue(client, g_hMinUpDateRate, sData[0]);
	SendConVarValue(client, g_hMaxUpDateRate, sData[0]);

	SendConVarValue(client, g_hMinRate, sData[1]);
	SendConVarValue(client, g_hMaxRate, "0");//这里必须设置为:0.
	//这个是必须的.
	SetClientInfo(client, "cl_updaterate", sData[0]);
	SetClientInfo(client, "cl_cmdrate", sData[0]);
}
//判断玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
