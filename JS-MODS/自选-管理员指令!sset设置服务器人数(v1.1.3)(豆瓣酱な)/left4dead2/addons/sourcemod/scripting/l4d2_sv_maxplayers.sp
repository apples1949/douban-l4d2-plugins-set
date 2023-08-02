#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.1.3"

#define DefaultPlayers	"8"
#define MAX_PLAYERS		31	//此游戏最多只能支持31人.
#define NUMBER_PLAYERS	15	//菜单设置玩家的最大数量.

char g_sMaxPlayers[32], g_skvPath[PLATFORM_MAX_PATH];

//对抗模式.
char g_sModeVersus[][] = 
{
	"versus",		//对抗模式
	"teamversus ",	//团队对抗
	"scavenge",		//团队清道夫
	"teamscavenge",	//团队清道夫
	"community3",	//骑师派对
	"community6",	//药抗模式
	"mutation11",	//没有救赎
	"mutation12",	//写实对抗
	"mutation13",	//清道肆虐
	"mutation15",	//生存对抗
	"mutation18",	//失血对抗
	"mutation19"	//坦克派对?
};

//单人模式.
char g_sModeSingle[][] = 
{
	"mutation1", //孤身一人
	"mutation17" //孤胆枪手
};

TopMenu hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;

public Plugin myinfo = 
{
	name 			= "l4d2_sv_maxplayers",
	author 			= "豆瓣酱な",
	description 	= "设置服务器最大人数.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	BuildPath(Path_SM, g_skvPath, sizeof(g_skvPath), "configs/l4d2_sv_maxplayers.cfg");
	IsReadFileValues(DefaultPlayers);
	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu)
		return;
	
	hTopMenu = topmenu;
	
	TopMenuObject objDifficultyMenu = FindTopMenuCategory(hTopMenu, "OtherFeatures");
	if (objDifficultyMenu == INVALID_TOPMENUOBJECT)
		objDifficultyMenu = AddToTopMenu(hTopMenu, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler, INVALID_TOPMENUOBJECT);
	
	hAddToTopMenu= AddToTopMenu(hTopMenu,"sm_sset",TopMenuObject_Item,InfectedMenuHandler,objDifficultyMenu,"sm_sset",ADMFLAG_ROOT);
}

public void AdminMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
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

public void InfectedMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hAddToTopMenu)
			Format(buffer, maxlength, "设置人数", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			DisplaySLMenu(param, 0, true);
	}
}

public void OnMapStart()
{
	IsReadFileValues(DefaultPlayers);
}

void IsReadFileValues(char[] sDefault)
{
	KeyValues kv = new KeyValues("maxplayers");
	if (!FileExists(g_skvPath))
	{
		File file = OpenFile(g_skvPath, "w");
		if (!file)
			LogError("无法读取文件: \"%s\"", g_skvPath);
		// 写出默认值内容
		kv.SetString("设置人数", sDefault);
		// 返回树顶部
		kv.Rewind();
		// 从当前树位置导出内容到文件
		kv.ExportToFile(g_skvPath);
		delete file;
	}
	else if (kv.ImportFromFile(g_skvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		// 获取Kv文本内信息写入变量中.
		kv.GetString("设置人数", g_sMaxPlayers, sizeof(g_sMaxPlayers), GetMaxPlayers());
		int iMaxplayers = StringToInt(g_sMaxPlayers);
		
		if (iMaxplayers > MAX_PLAYERS)
		{
			iMaxplayers = MAX_PLAYERS;
			IntToString(iMaxplayers, g_sMaxPlayers, sizeof(g_sMaxPlayers));
			DataPack hPack = new DataPack();
			hPack.WriteString(g_sMaxPlayers);
			RequestFrame(IsWriteData, hPack);
		}
		SetConVarInt(FindConVar("sv_maxplayers"), iMaxplayers == -1 ? GetDefaultNumber() : iMaxplayers == 0 ? 1 : iMaxplayers, false, false);
		SetConVarInt(FindConVar("sv_visiblemaxplayers"), iMaxplayers == -1 ? GetDefaultNumber() : iMaxplayers == 0 ? 1 : iMaxplayers, false, false);
	}
	delete kv;
}

int GetDefaultNumber()
{
	for (int i = 0; i < sizeof(g_sModeVersus); i++)
		if(strcmp(GetGameMode(), g_sModeVersus[i]) == 0)
			return 8;
	for (int i = 0; i < sizeof(g_sModeSingle); i++)
		if(strcmp(GetGameMode(), g_sModeSingle[i]) == 0)
			return 1;
	return 4;
}

char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}

public Action Command_sset(int client, int args)
{
	if(bCheckClientAccess(client))
		DisplaySLMenu(client, 0, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

void DisplaySLMenu(int client, int index, bool bButton = false)
{
	char sNumber[32];
	Menu menu = new Menu(SLMenuHandler);
	menu.SetTitle("设置人数:");
	
	int i = 1;
	int iMax = !IsDedicatedServer() ? 8 : NUMBER_PLAYERS;

	while (i <= iMax)
	{
		IntToString(i,	sNumber, sizeof(sNumber));
		AddMenuItem(menu, sNumber, sNumber);
		i++;
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int SLMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char sInfos[32];
			GetMenuItem(menu, itemNum, sInfos, sizeof(sInfos));
			int iMaxplayers = StringToInt(sInfos);
			SetConVarInt(FindConVar("sv_maxplayers"), iMaxplayers, false, false);
			SetConVarInt(FindConVar("sv_visiblemaxplayers"), iMaxplayers, false, false);
			PrintToChatAll("\x04[提示]\x05更改服务器的最大人数为\x04:\x03%s\x05人.", GetMaxPlayers());
			//重新写入新值.
			DataPack hPack = new DataPack();
			hPack.WriteString(sInfos);
			RequestFrame(IsWriteData, hPack);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}

void IsWriteData(DataPack hPack)
{
	hPack.Reset();
	char sData[32];
	hPack.ReadString(sData, sizeof(sData));
	KeyValues kv = new KeyValues("maxplayers");
	if (FileExists(g_skvPath))
	{
		File file = OpenFile(g_skvPath, "w");
		if (!file)
			LogError("无法读取文件: \"%s\"", g_skvPath);
		// 写出默认值内容
		kv.SetString("设置人数", sData);
		// 返回树顶部
		kv.Rewind();
		// 从当前树位置导出内容到文件
		kv.ExportToFile(g_skvPath);
		delete file;
	}
	delete kv;
	delete hPack;
}

char[] GetMaxPlayers()
{
	char sNumber[32];
	IntToString(GetConVarInt(FindConVar("sv_maxplayers")), sNumber, sizeof(sNumber));
	return sNumber;
}