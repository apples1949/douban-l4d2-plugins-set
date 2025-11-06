/*
 *
 *	v1.1.0
 *
 *	1:增加两个炸服指令(!boom)(!crash).
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.1.0"
#define CVAR_FLAGS		FCVAR_NOTIFY
#define GAMEDATA		"l4d2_crash"
//定义全局变量.
int g_iCountdown;
char g_sBuffer[128];
Handle g_hPlayerTimer;

int    g_iEmptyLog, g_iEmptyCrash, g_iEmptyType, g_iEmptyCommand;
ConVar g_hEmptyLog, g_hEmptyCrash, g_hEmptyType, g_hEmptyCommand;
//定义管理员菜单变量.
TopMenu g_hTopMenu_Other;
TopMenuObject g_hOther = INVALID_TOPMENUOBJECT;
//定义插件信息.
public Plugin myinfo = 
{
	name = "l4d2_crash",
	author = "豆瓣酱な",
	version = PLUGIN_VERSION,
	url = "N/A"
}
//插件开始.
public void OnPluginStart()
{
	LoadGameCFG();//签名嫖至(https://github.com/lakwsh).

	RegConsoleCmd("sm_bom", Command_CrashServer, "手动爆炸服务端.");
	RegConsoleCmd("sm_boom", Command_CrashServer, "手动爆炸服务端.");
	RegConsoleCmd("sm_crash", Command_CrashServer, "手动爆炸服务端.");

	g_hEmptyLog 	= CreateConVar("l4d2_crash_Log",	"1", "服务器无人时记录日志内容? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hEmptyCrash 	= CreateConVar("l4d2_crash_System",	"1", "允许什么系统的服务器崩溃? 0=禁用, 1=linux, 2=windows, 3=两者.", CVAR_FLAGS);
	g_hEmptyType 	= CreateConVar("l4d2_crash_type",	"1", "允许什么类型的服务器崩溃? 1=专用服务器, 2=本地服务器, 3=两者.", CVAR_FLAGS);
	g_hEmptyCommand = CreateConVar("l4d2_crash_Command","10", "设置玩家使用(!bom)(!boom)(!crash)指令手动炸服的倒计时时间/秒. 0=禁用.", CVAR_FLAGS);
	
	g_hEmptyLog.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCrash.AddChangeHook(EmptyConVarChanged);
	g_hEmptyType.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCommand.AddChangeHook(EmptyConVarChanged);

	AutoExecConfig(true, "l4d2_crash");

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}
//参数ConVar变量改变时的回调.
void EmptyConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetEmptyCvars();
}
//地图加载完成后.
public void OnConfigsExecuted()
{
	GetEmptyCvars();
}
//参数赋值到全局变量.
void GetEmptyCvars()
{
	g_iEmptyLog = g_hEmptyLog.IntValue;
	g_iEmptyCrash = g_hEmptyCrash.IntValue;
	g_iEmptyType = g_hEmptyType.IntValue;
	g_iEmptyCommand = g_hEmptyCommand.IntValue;
}
//卸载函数库时.
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu_Other = null;
}
//添加管理员菜单时.
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu_Other)
		return;
	
	g_hTopMenu_Other = topmenu;
	
	TopMenuObject objMenu_Other = FindTopMenuCategory(g_hTopMenu_Other, "OtherFeatures");
	if (objMenu_Other == INVALID_TOPMENUOBJECT)
		objMenu_Other = AddToTopMenu(g_hTopMenu_Other, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler_Other, INVALID_TOPMENUOBJECT);
	
	g_hOther = AddToTopMenu(g_hTopMenu_Other,"sm_crash",TopMenuObject_Item, InfectedMenuHandler_Other,objMenu_Other,"sm_crash",ADMFLAG_ROOT);
}
//管理员菜单回调.
void AdminMenuHandler_Other(Handle topmenu_Other, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Other)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength_Other, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength_Other, "其它功能", param);
	}
}
//管理员菜单回调.
void InfectedMenuHandler_Other(Handle topmenu_Other, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Other)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == g_hOther)
			Format(buffer, maxlength_Other, "执行炸服", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == g_hOther)
			vFriedSuitMenu(param, true);
	}
}
//指令回调.
Action Command_CrashServer(int client, int args)
{
	if(bCheckClientAccess(client))
		vFriedSuitMenu(client, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
//判断管理员权限.
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
//打开炸服菜单.
void vFriedSuitMenu(int client, bool bButton = false)
{
	if(g_iEmptyCommand > 0)
	{
		char line[32], sButton[32];
		IntToString(bButton, sButton, sizeof(sButton));
		Menu menu = new Menu(Menu_HandlerFriedSuitMenu);
		Format(line, sizeof(line), "%s炸服?\n ", g_hPlayerTimer == null ? "开启" : "取消");
		SetMenuTitle(menu, "%s", line);
		menu.AddItem(sButton, "确认");
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = bButton;//显示数字8返回上一层.
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		if (bButton == true && g_hTopMenu_Other != null)
			g_hTopMenu_Other.Display(client, TopMenuPosition_LastCategory);
		PrintToChat(client, "\x04[提示]\x05服主未开启手动炸服指令.");
	}
}
//菜单回调.
int Menu_HandlerFriedSuitMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			
			if(g_hPlayerTimer == null)
			{
				vCreateTimer(client);
				PrintHintTextToAll("已开启炸服倒计时.");//屏幕中下提示.
			}
			else
			{
				delete g_hPlayerTimer;
				PrintHintTextToAll("已关闭炸服倒计时.");//屏幕中下提示.
			}
			vFriedSuitMenu(client, view_as<bool>(StringToInt(sItem)));
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu_Other != null)
				g_hTopMenu_Other.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}
//新建计时器.
void vCreateTimer(int client)
{
	DataPack hPack;
	g_iCountdown = g_iEmptyCommand;
	g_hPlayerTimer = CreateDataTimer(1.0, DataTimerCallback, hPack, TIMER_REPEAT);
	hPack.WriteString(WriteFriedSuitWhys(client));
	
}
//计时器回调.
public Action DataTimerCallback(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	char sWhys[64];
	hPack.ReadString(sWhys, sizeof(sWhys)); //读取打包的内容，"ReadString"为字符串变量参数读取
	
	if(g_iCountdown <= 0)
	{
		PrintHintTextToAll("服务器已被爆破!");//屏幕中下提示.
		g_hPlayerTimer = null;
		vDelayExecute(sWhys);
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("服务器将在 %d 秒后被爆破!", g_iCountdown);//屏幕中下提示.
		g_iCountdown -= 1;
	}
	return Plugin_Continue;
}
//新建数据包.
void vDelayExecute(char[] sWhys)
{
	DataPack hPack = new DataPack();
	RequestFrame(vNextFrameFriedSuit, hPack);
	hPack.WriteString(sWhys);
}
//下一个数据包回调.
void vNextFrameFriedSuit(DataPack hPack)
{
	hPack.Reset();
	char sWhys[64];
	hPack.ReadString(sWhys, sizeof(sWhys)); //读取打包的内容，"ReadString"为字符串变量参数读取
	vLoggingAndExecutionCrashes(L4D_GetServerOS(), sWhys);//记录日志和执行崩溃服务器.
	delete hPack;
}
//返回字符串.
char[] WriteFriedSuitWhys(int client)
{
	char sWhys[64], sName[32], sSteamId[32];
	GetClientName(client, sName, sizeof(sName));
	GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
	FormatEx(sWhys, sizeof(sWhys), "(%s)(%s)手动执行炸服", sName, sSteamId);
	return sWhys;
}
//读取签名文件.
void LoadGameCFG()
{
	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData) 
		SetFailState("Failed to load '%s.txt' gamedata.", GAMEDATA);

	CreateDetour(hGameData,	HibernationUpdate_Pre, "HibernationUpdate", false);
	//CreateDetour(hGameData,	HibernationUpdate_Pre, "HibernationUpdate", true);
}
//创建钩子.
void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if(!hDetour)
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if(!DHookEnableDetour(hDetour, post, CallBack))
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}
//DHook回调.
MRESReturn HibernationUpdate_Pre(DHookParam hParams)
{
	bool hibernating = DHookGetParam(hParams, 1);

	if(!hibernating) 
		return MRES_Ignored;

	if(g_iEmptyCrash <= 0) 
		return MRES_Ignored;
		
	vDetermineSystemType(L4D_GetServerOS(), "服务器没人了");//判断系统类型:0=windows,1=linux.
	return MRES_Ignored;
}
//判断系统类型.
void vDetermineSystemType(int iType, char[] sWhys)
{
	switch (iType)
	{
		case 0:
		{
			if(g_iEmptyCrash == 2 || g_iEmptyCrash == 3)
				vDetermineTheServerType(iType, sWhys);//判断服务器类型.
		}
		case 1:
		{
			if(g_iEmptyCrash == 1 || g_iEmptyCrash == 3)
				vDetermineTheServerType(iType, sWhys);//判断服务器类型.
		}
	}
}
//判断服务器类型.
void vDetermineTheServerType(int iType, char[] sWhys)
{
	if(IsDedicatedServer())//判断服务器类型:true=专用服务器,false=本地服务器.
	{
		if(g_iEmptyType == 1 || g_iEmptyType == 3)
			vLoggingAndExecutionCrashes(iType, sWhys);//记录日志和执行崩溃服务器.
	}
	else
	{
		if(g_iEmptyType == 2 || g_iEmptyType == 3)
			vLoggingAndExecutionCrashes(iType, sWhys);//记录日志和执行崩溃服务器.
	}
}
//记录日志和执行崩溃服务器.
void vLoggingAndExecutionCrashes(int iType, char[] sWhys)
{
	UnloadAccelerator();//卸载崩溃记录扩展.
	IsRecordLogContent(iType, sWhys);//写入日志内容到文件.
	IsExecuteCrashServerCode();//执行崩溃服务端代码.
}
//卸载崩溃记录扩展.
void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();//立即执行.
	}
}
//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	
	return -1;
}
//写入日志内容到文件.
void IsRecordLogContent(int iType, char[] sWhys)
{
	//记录日志.
	if (g_iEmptyLog == 1)
	{
		char Msg[256], Time[32];
		vCreateLogFile();//初始化日志文件,如果没有就创建.
		FormatTime(Time, sizeof(Time), "%Y-%m-%d %H:%M:%S", -1);
		Format(Msg, sizeof(Msg), "时间:%s.\n系统类型:%s.\n服务器类型:%s.\n炸服原因:%s.", Time, iType == 0 ? "windows" : iType == 1 ? "linux" : "其它", IsDedicatedServer() ? "专用" : "本地", sWhys);

		IsSaveMessage("--=============================================================--");
		IsSaveMessage(Msg);
		IsSaveMessage("--=============================================================--");
	}
}
//创建日志文件.
void vCreateLogFile()
{
	char sDate[32], sLogs[128];
	FormatTime(sDate, sizeof(sDate), "%y%m%d");
	Format(sLogs, sizeof(sLogs), "/logs/Empty%s.log", sDate);
	BuildPath(Path_SM, g_sBuffer, sizeof(g_sBuffer), sLogs);
}
//把日志内容写入文本里.
void IsSaveMessage(const char[] Message)
{
	File fileHandle = OpenFile(g_sBuffer, "a");
	fileHandle.WriteLine(Message);
	delete fileHandle;
}
//执行崩溃服务端代码.
void IsExecuteCrashServerCode()
{
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") &~ FCVAR_CHEAT);
	ServerCommand("sv_crash");
}
