
/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.3.7
 *
 *	1:优化了一些代码,指令更改人数时写入文件合并到一起.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.3.7"	//定义插件版本.

char g_sWrite[][][] = 
{
	{"指令设置人数时写入文件. 0=禁用, 1=启用.", "1"},
	{"设置服务器的最大最大人数. 0=禁用(最大值:31).", "8"}
};

int g_iMaxPlayers;
bool g_bMaxPlayers;
ConVar g_hMaxPlayers;
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
	g_hMaxPlayers = FindConVar("sv_maxplayers");
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_sv_maxplayers.cfg");

	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	vCreateReadFile();//新建或读取文件内容.
}
//地图加载后调用.
public void OnConfigsExecuted()
{
	vCreateReadFile();//新建或读取文件内容.
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
void vCreateReadFile()
{
	KeyValues kv = new KeyValues("maxplayers");

	if (!FileExists(g_sKvPath))
	{
		//写入默认内容.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.SetString(g_sWrite[i][0], g_sWrite[i][1]);
		
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_sKvPath);//把数据写入到文件.
	}
	else if (kv.ImportFromFile(g_sKvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		if (g_hMaxPlayers == null)//设置人数ConVar有效.
			LogError("设置人数ConVar无效:\"sv_maxplayers\".");//显示错误信息.
		
		char sData[sizeof(g_sWrite)][128];
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.GetString(g_sWrite[1][0], sData[i], sizeof(sData[]), g_sWrite[i][1]);//获取文件里指定的内容.

		int iPlayers = StringToInt(sData[1]);

		//if(StringToInt(sData[0]) != 0)
		//{
		//	if(g_bMaxPlayers == true)
		//	{
		//		g_bMaxPlayers = false;
		//		
		//		if(g_iMaxPlayers != iPlayers)
		//		{
		//			char sInfo[32];
		//			IntToString(g_iMaxPlayers, sInfo, sizeof(sInfo));
		//			kv.SetString(g_sWrite[1][0], sInfo);//写入指定的内容.
		//			kv.Rewind();//返回上一层.
		//			kv.ExportToFile(g_sKvPath);//把数据写入到文件.
		//		}
		//	}
		//}
		
		if(iPlayers != 0)
			SetMaxPlayers(GetMaxPlayersNumber(g_bMaxPlayers == false ? iPlayers : g_iMaxPlayers));//设置服务器最大人数.
	}
	delete kv;//删除句柄.
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
	char sData[128], sInfo[3][32], sNumber[32];
	Menu menu = new Menu(SLMenuHandler);
	menu.SetTitle("设置人数:");
	
	int i = 1;
	int iNumber = !IsDedicatedServer() ? 8 : g_hMaxPlayers != null ? MaxClients : 18;
	IntToString(iNumber, sNumber, sizeof(sNumber));
	IntToString(-1, sInfo[0], sizeof(sInfo[]));
	IntToString(bButton, sInfo[1], sizeof(sInfo[]));
	ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.
	menu.AddItem(sData, "默认");
	while (i <= iNumber)
	{
		IntToString(i, sInfo[0], sizeof(sInfo[]));
		int iMax = strlen(sNumber) - strlen(sInfo[0]);
		IntToString(bButton, sInfo[1], sizeof(sInfo[]));
		FormatEx(sInfo[2], sizeof(sInfo[]), "%s%s人", cAlignDisplay(iMax, "0"), sInfo[0]);
		ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.
		menu.AddItem(sData, sInfo[2]);
		i++;
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
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
			SetMaxPlayers(GetMaxPlayersNumber(StringToInt(sInfo[0])));//设置服务器最大人数.
			PrintToChat(client, "\x04[提示]\x05更改最大人数为\x04:\x03%s.", sInfo[2]);
			VUpdateConfigurationFile(sInfo[0]);//把新值写入到文件.
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
void VUpdateConfigurationFile(char[] sMaxPlayers)
{
	g_iMaxPlayers = StringToInt(sMaxPlayers);
	KeyValues kv = new KeyValues("maxplayers");
	
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		//写入默认内容.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.SetString(g_sWrite[i][0], g_sWrite[i][1]);
			
		// 返回上一页.
		kv.Rewind();
		// 把内容写入文件.
		if(kv.ExportToFile(g_sKvPath))//写入文件成功.
			VUpdateConfigurationFile(sMaxPlayers);
	}
	else if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
	{
		char sData[sizeof(g_sWrite)][128];
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.GetString(g_sWrite[i][0], sData[i], sizeof(sData[]), g_sWrite[i][1]);//获取文件里指定的内容.

		if(StringToInt(sData[0]) == 0)
		{
			g_bMaxPlayers = StringToInt(sMaxPlayers) == StringToInt(sData[1]) ? false : true;
		}
		else
		{
			g_bMaxPlayers = false;
			kv.SetString(g_sWrite[1][0], sMaxPlayers);//写入指定的内容.
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sKvPath);//把数据写入到文件.
		}
		//PrintToChatAll("\x04[提示]\x05值\x03(%s)\x05(%s)(%s)(%d).", sData[0], sData[1], sMaxPlayers, g_bMaxPlayers);
	}
	else{}//文件读取失败.
	delete kv;
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
//获取最大玩家数量.
stock int GetMaxPlayersNumber(int iMaxplayers)
{
	if (iMaxplayers > MaxClients)//设置的人数大于最大人数时执行.
		iMaxplayers = MaxClients;//重新赋值最大人数.
	return iMaxplayers;
}
//设置服务器最大人数.
void SetMaxPlayers(int iMaxplayers)
{
	SetConVarInt(FindConVar("sv_maxplayers"), iMaxplayers, false, false);//设置服务器最大人数.
	SetConVarInt(FindConVar("sv_visiblemaxplayers"), iMaxplayers, false, false);//设置服务器显示的最大人数(这个值不影响实际人数,该值为-1时服务器没人加入前会显示为0-4).
}
//获取服务器最大人数.
stock char[] GetMaxPlayers()
{
	char sNumber[32];
	IntToString(g_hMaxPlayers == null ? 0 : g_hMaxPlayers.IntValue, sNumber, sizeof(sNumber));
	return sNumber;
}
