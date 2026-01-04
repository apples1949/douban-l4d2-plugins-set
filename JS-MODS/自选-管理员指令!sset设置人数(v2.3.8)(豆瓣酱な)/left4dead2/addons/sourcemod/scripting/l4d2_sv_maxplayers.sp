
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.3.7
 *
 *	1:优化了一些代码,指令更改人数时写入文件合并到一起.
 *
 *	v1.3.8
 *
 *	1:修复了没有安装多人破解扩展导致插件报错被自动卸载的问题.
 *
 *	v2.3.8
 *
 *	1:更改为根据游戏端口设置人数,单个服务端更改default里的值即可.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"2.3.8"	//定义插件版本.

char g_sKey[][][] = 
{
	{"设置人数时写入文件. 0=禁用, 1=启用.", "1"},
	{"设置服务器的最大人数(1~31). -1=默认.", "8"}
};

bool g_bMaxPlayers;
ConVar g_hHostPort;
ConVar g_hMaxPlayers;
ConVar g_hVisibleMax;
char g_sKvPath[PLATFORM_MAX_PATH];

TopMenu hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;
//定义插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_sv_maxplayers",
	author 			= "豆瓣酱な",
	description 	= "设置服务器最大人数.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始.
public void OnPluginStart()
{
	g_hHostPort = FindConVar("hostport");
	g_hMaxPlayers = FindConVar("sv_maxplayers");
	g_hVisibleMax = FindConVar("sv_visiblemaxplayers");
	
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_sv_maxplayers.txt");

	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	ReadFileContent(GetHostPort());//新建或读取文件内容.
}
//地图加载后调用.
public void OnConfigsExecuted()
{
	ReadFileContent(GetHostPort());//新建或读取文件内容.
}
//卸载函数库.
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}
//添加管理员菜单.
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

void AdminMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
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

void InfectedMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
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
//新建或读取文件内容.
void ReadFileContent(char[] sHostPort)
{
	if (g_hMaxPlayers == null)//设置人数ConVar有效.
	{
		if(g_bMaxPlayers == false)
		{
			g_bMaxPlayers = true;
			LogError("设置人数功能无效,请确认多人破解扩展已安装并加载.");//显示错误信息.
			LogError("文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.so.");
			LogError("文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.dll.");
			LogError("文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.vdf.");
		}
	}
	else
	{
		if (!FileExists(g_sKvPath))
		{
			KeyValues kv = new KeyValues("maxplayers");

			if (kv.JumpToKey("default", true))
			{
				//写入默认内容.
				for (int i = 0; i < sizeof(g_sKey); i++)
					kv.SetString(g_sKey[i][0], g_sKey[i][1]);

				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.

				SetMaxPlayers(GetMaxNumber(StringToInt(g_sKey[1][1])));//设置服务器最大人数.
			}

			delete kv;//删除句柄.
		}
		else
		{
			KeyValues kv = new KeyValues("maxplayers");

			if (kv.ImportFromFile(g_sKvPath))//导入kv数据成功.
			{
				int iPlayers;
				char sData[2][128];

				iPlayers = StringToInt(g_sKey[1][1]);

				if (kv.JumpToKey("default", false))
				{
					kv.GetString(g_sKey[1][0], sData[0], sizeof(sData[]), g_sKey[1][1]);//获取文件里指定的内容.
					iPlayers = StringToInt(sData[0]);
					kv.Rewind();//返回上一层.
				}
				if (kv.JumpToKey(sHostPort, false)) 
				{
					kv.GetString(g_sKey[1][0], sData[1], sizeof(sData[]), g_sKey[1][1]);//获取文件里指定的内容.
					iPlayers = StringToInt(sData[1]);
					kv.Rewind();//返回上一层.
				}

				SetMaxPlayers(GetMaxNumber(GetMinNumber(iPlayers)));//设置服务器最大人数.
			}

			delete kv;//删除句柄.
		}
	}
}
//指令回调.
Action Command_sset(int client, int args)
{
	if(bCheckClientAccess(client))
		DisplaySLMenu(client, 0, false);
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
//设置人数菜单.
void DisplaySLMenu(int client, int index, bool bButton = false)
{
	if(g_hMaxPlayers == null)
	{
		PrintToChat(client, "\x04[提示]\x05设置人数功能无效,请确认多人破解扩展已安装并加载.");
		PrintToChat(client, "\x04[提示]\x05文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.so.");
		PrintToChat(client, "\x04[提示]\x05文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.dll.");
		PrintToChat(client, "\x04[提示]\x05文件路径*/Left 4 Dead 2/left4dead2/addons/l4dtoolz.vdf.");
	}
	else
	{
		char sData[128], sInfo[3][32], sValue[32];
		Menu menu = new Menu(SLMenuHandler);
		menu.SetTitle("设置人数:");
		
		int i = 1;
		int iNumber = !IsDedicatedServer() ? 8 : MaxClients;
		IntToString(iNumber, sValue, sizeof(sValue));

		IntToString(-1, sInfo[0], sizeof(sInfo[]));
		IntToString(bButton, sInfo[1], sizeof(sInfo[]));
		FormatEx(sInfo[2], sizeof(sInfo[]), "默认");
		ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.
		menu.AddItem(sData, "默认");

		while (i <= iNumber)
		{
			IntToString(i, sInfo[0], sizeof(sInfo[]));
			int iMax = strlen(sValue) - strlen(sInfo[0]);
			IntToString(bButton, sInfo[1], sizeof(sInfo[]));
			FormatEx(sInfo[2], sizeof(sInfo[]), "%s人", sInfo[0]);
			ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.
			FormatEx(sInfo[2], sizeof(sInfo[]), "%s%s人", cAlignDisplay(iMax, "0"), sInfo[0]);
			menu.AddItem(sData, sInfo[2]);
			i++;
		}
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
		menu.DisplayAt(client, index, MENU_TIME_FOREVER);
	}
	
}
//菜单回调.
int SLMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char sItem[128], sName[32], sInfo[3][32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			SetMaxPlayers(GetMaxNumber(StringToInt(sInfo[0])));//设置服务器最大人数.
			PrintToChat(client, "\x04[提示]\x05更改最大人数为\x04:\x03%s.", sInfo[2]);
			WriteFileContent(GetHostPort(), sInfo[0]);//把新值写入到文件.
			DisplaySLMenu(client, menu.Selection, view_as<bool>(StringToInt(sInfo[1])));//重新打开菜单.
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}
//写入到文件.
void WriteFileContent(char[] sHostPort, char[] sMaxPlayers)
{
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		KeyValues kv = new KeyValues("maxplayers");

		if (kv.JumpToKey("default", true))
		{
			//写入默认内容.
			kv.SetString(g_sKey[0][0], g_sKey[0][1]);
			kv.SetString(g_sKey[1][0], sMaxPlayers);
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sKvPath);//把数据写入到文件.
		}

		delete kv;//删除句柄.
	}
	else
	{
		KeyValues kv = new KeyValues("maxplayers");
		
		if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
		{
			if (kv.JumpToKey(sHostPort, false))
			{
				char sData[2][128];
				kv.GetString(g_sKey[0][0], sData[0], sizeof(sData[]), g_sKey[0][1]);//获取文件里指定的内容.
				kv.GetString(g_sKey[1][0], sData[1], sizeof(sData[]), g_sKey[1][1]);//获取文件里指定的内容.

				kv.SetString(g_sKey[0][0], sData[0]);//写入指定的内容.
				if(StringToInt(sData[0]) != 0)
					kv.SetString(g_sKey[1][0], sMaxPlayers);//写入指定的内容.
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
			}
			else if (kv.JumpToKey("default", false))
			{
				char sData[2][128];
				kv.GetString(g_sKey[0][0], sData[0], sizeof(sData[]), g_sKey[0][1]);//获取文件里指定的内容.
				kv.GetString(g_sKey[1][0], sData[1], sizeof(sData[]), g_sKey[1][1]);//获取文件里指定的内容.

				kv.SetString(g_sKey[0][0], sData[0]);//写入指定的内容.
				if(StringToInt(sData[0]) != 0)
					kv.SetString(g_sKey[1][0], sMaxPlayers);//写入指定的内容.
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
			}
			else if (kv.JumpToKey("default", true))
			{
				char sData[2][128];
				kv.GetString(g_sKey[0][0], sData[0], sizeof(sData[]), g_sKey[0][1]);//获取文件里指定的内容.
				kv.GetString(g_sKey[1][0], sData[1], sizeof(sData[]), g_sKey[1][1]);//获取文件里指定的内容.

				kv.SetString(g_sKey[0][0], sData[0]);//写入指定的内容.
				if(StringToInt(sData[0]) != 0)
					kv.SetString(g_sKey[1][0], sMaxPlayers);//写入指定的内容.
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
			}
		}
		else//文件读取失败.
		{}

		delete kv;
	}
}
//获取最大玩家数量.
stock int GetMaxNumber(int iMaxplayers)
{
	if (iMaxplayers > MaxClients)//设置的人数大于最大人数时执行.
		iMaxplayers = MaxClients;//重新赋值最大人数.
	return iMaxplayers;
}
//获取最大玩家数量.
stock int GetMinNumber(int iMaxplayers)
{
	if (iMaxplayers <= 0)//设置的人数大于最大人数时执行.
		iMaxplayers = -1;//重新赋值最大人数.
	return iMaxplayers;
}
//填入对应数量的内容.
stock char[] cAlignDisplay(int iNumber, char[] sValue)
{
	char sInfo[128];
	if(iNumber > 0)
	{
		int iLength = strlen(sValue) + 1;
		char[][] sData = new char[iNumber][iLength];//动态数组.
		for (int i = 0; i < iNumber; i++)
			strcopy(sData[i], iLength, sValue);
		ImplodeStrings(sData, iNumber, "", sInfo, sizeof(sInfo));//打包字符串.
	}
	return sInfo;
}
//设置服务器最大人数.
stock void SetMaxPlayers(int iMaxplayers)
{
	g_hMaxPlayers.IntValue = iMaxplayers;//设置服务器最大人数.
	g_hVisibleMax.IntValue = iMaxplayers;//设置服务器显示的最大人数(这个值不影响实际人数,该值为-1时服务器没人加入前会显示为0-4).
}
//获取端口名称.
stock char[] GetHostPort()
{
	char sPort[32];
	g_hHostPort.GetString(sPort, sizeof(sPort));
	return sPort;
}