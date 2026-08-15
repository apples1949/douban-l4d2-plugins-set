/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
//定义插件版本.
#define PLUGIN_VERSION	"1.0.0"	
#define MAX_PLAYERS		32
#define COUNTDOWN_TIME	5	//倒计时时间.
//定义全局变量.
Handle g_hPauseGame;
Handle g_hCountdown;
bool g_bPauseGame = false;
int g_iCountdown[MAX_PLAYERS+1];
//定义菜单全局变量.
TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;
//定义插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_pause_game",
	author 			= "豆瓣酱な",
	description 	= "管理员!pause暂停游戏",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始.
public void OnPluginStart()
{
	RegConsoleCmd("sm_pause", Command_ServerPause, "管理员强制暂停游戏,再次输入指令开始游戏.");
	AddCommandListener(Listener_spec_next, "unpause");
	g_hPauseGame = FindConVar("sv_pausable");
	SetConVarInt(g_hPauseGame, 0);

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
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
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_pause",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_pause",ADMFLAG_ROOT);
}

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

void hHandlerMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hOtherFeatures)
			Format(buffer, maxlength, "暂停游戏", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			OpenPauseFunction(param, true);
		}
	}
}
//监听指令回调.
Action Listener_spec_next(int client, char[] command, int argc) 
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (strcmp(command, "unpause") == 0 && g_bPauseGame == true)//阻止单人打开控制台会自动取消暂停.
		return Plugin_Handled;

	return Plugin_Continue;
}
//地图开始.
public void OnMapStart()
{
	g_bPauseGame = false;
	delete g_hCountdown;
	SetConVarInt(g_hPauseGame, 1);
	ServerCommand("unpause");
	SetConVarInt(g_hPauseGame, 0);
}
//指令回调.
Action Command_ServerPause(int client, int args)
{
	if(bCheckClientAccess(client))
		OpenPauseFunction(client, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
//暂停或继续游戏.
void OpenPauseFunction(int client, bool bButton = false)
{
	if(g_hCountdown == null)
	{
		if (g_bPauseGame)
		{
			g_iCountdown[client] = COUNTDOWN_TIME;
			PrintToChatAll("\x04[提示]\x05游戏被管理员取消暂停.");
			g_hCountdown = CreateTimer(1.0, UnPauseCountdown, client, TIMER_REPEAT);
		}
		else
		{
			PauseGame(client);
			g_bPauseGame = true;
			PrintToChatAll("\x04[提示]\x05管理员暂停了游戏.");
		}
	}
	else
		PrintToChatAll("\x04[提示]\x05正在取消暂停倒计时.");

	if (bButton == true)
		g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
}
//判断管理员权限.
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
//计时器回调.
Action UnPauseCountdown(Handle timer, any client)
{
	if (g_iCountdown[client] >= COUNTDOWN_TIME)
	{
		PrintToChatAll("\x04[提示]\x05游戏将在\x03%d秒\x05之后开始.", g_iCountdown[client]);
		g_iCountdown[client]--;
		return Plugin_Continue;
	}
	if(g_iCountdown[client] > 0)
	{
		PrintToChatAll("\x04[提示]\x05游戏开始还剩\x03%d\x05秒.", g_iCountdown[client]);
		g_iCountdown[client]--;
		return Plugin_Continue;
	}
	
	g_bPauseGame = false;
	UnPauseGame(client);
	g_hCountdown = null;
	PrintHintTextToAll("→ 游戏继续 ←");
	PrintToChatAll("\x04[提示]\x05游戏继续.");
	return Plugin_Stop;
}
//暂停游戏.
void PauseGame(int client)
{
	SetConVarInt(g_hPauseGame, 1);
	FakeClientCommand(client, "setpause");
	SetConVarInt(g_hPauseGame, 0);
}
//继续游戏.
void UnPauseGame(int client)
{
	SetConVarInt(g_hPauseGame, 1);
	FakeClientCommand(client, "unpause");
	SetConVarInt(g_hPauseGame, 0);
}
