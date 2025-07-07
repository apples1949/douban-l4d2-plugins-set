
/*
 *
 *	该插件参考作者lakwsh的连服封禁.
 *	这个是他的仓库(https://github.com/lakwsh/sm_bandb).
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *	2:如果要正常使用该插件需要替换平台自带的封禁插件.
 *	3:该插件使用的是平台自带的数据库,门槛更低,但不能跨服使用.
 *	4:有可能第一个玩家加入服务器后数据库会出现查询延迟的问题.
 *
 *	v1.0.1
 *
 *	1:新增玩家加入时ID获取失败的会被踢出游戏.
 *
 *	v1.0.2
 *
 *	1:永久封禁的玩家下次加入游戏时显示被封禁的时间.
 *
 *	v1.1.2
 *
 *	1:新增兼容平台自带的sm_addban封禁指令.
 *
 *	v1.2.2
 *
 *	1:重新包装一下BanClient()封禁玩家函数,用于兼容该插件.
 *
 *	v1.3.2
 *
 *	1:新增聊天窗显示解封提示.
 *
 *	v1.4.2
 *
 *	1:封禁函数类型数量跟官方保持一致.
 *	2:把平台自带的封禁STEAMID的函数也重新封装一下用于适配该插件.
 *
 *	v1.4.3
 *
 *	1:重新封装的封禁函数BanPlayers(BanClient)默认添加禁用踢出玩家的功能.
 *
 *	v1.4.4
 *
 *	1:封禁函数BanClient没有添加禁用踢出玩家功能(BANFLAG_NOKICK)时使用平台自带的封禁功能.
 *	2:加载平台自带的封禁玩家列表(平台一直以来的一个BUG,不手动加载的话重开服后封禁列表就失效了).
 *
 *	v1.5.4
 *
 *	1:非永久封禁提示添加解封时间显示.
 *
 *	v1.6.5
 *
 *	1:添加一个封禁时间显示.
 *	2:修复聊天窗解封时间写成封禁时间.
 *	3:添加封禁数据时如果玩家已经是非永久封禁状态则自动改为追加封禁时长.
 *
 *	v1.7.5
 *
 *	1:新增配置文件选择使用MySQL数据库版本.
 *
 *	v2.7.5
 *
 *	1:新增管理员菜单删除封禁列表功能.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#pragma dynamic 40960	//增加堆栈空间.
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION	"2.7.5"	//插件的版本.
#define MAX_LENGTH		128		//字符串最大值.

Database g_dbSQL;

bool g_bLateLoad;
bool g_bDatabaseType = false;//设置创建配置文件默认使用的数据库类型,false=Sqlite,true=MySQL.
bool g_bButton[MAXPLAYERS+1];

char g_skvPath[PLATFORM_MAX_PATH];
char g_sPlayerData[5][MAXPLAYERS+1][32];

enum struct esBanned 
{
	bool g_bBanStatus;
	char sBanTime[128];
	char sUnBanTime[128];
	char sBanReason[128];
	char sBanDuration[128];
}
esBanned g_eBanned[MAXPLAYERS + 1];

enum struct esBanList 
	{
		char esSteamID[128];
		char esBanReason[128];
		int eiBanTime;
		int eiTimesTamp;
	}

TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	CreateNatives();
	g_bLateLoad = late;
	RegPluginLibrary("l4d2_banned");
	return APLRes_Success;
}
void CreateNatives()
{
	CreateNative("BanPlayers", BanNativePlayers);
}
int BanNativePlayers(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int time = GetNativeCell(2);
	int flags = GetNativeCell(3);
	char[] reason = new char[MAX_LENGTH];
	char[] kick_message = new char[MAX_LENGTH];
	char[] command = new char[MAX_LENGTH];
	GetNativeString(4, reason, MAX_LENGTH);
	GetNativeString(5, kick_message, MAX_LENGTH);
	GetNativeString(6, command, MAX_LENGTH);
	any source = GetNativeCell(7);
	return BanClient(client, time, flags|BANFLAG_NOKICK, reason, kick_message, command, source);//BANFLAG_NOKICK的作用是禁用封禁函数自带的踢出玩家功能.
}
//定义插件信息.
public Plugin myinfo =  
{
	name = "l4d2_banned",
	author = "豆瓣酱な",
	description = "监听平台自带的封禁和解封函数",
	version = PLUGIN_VERSION,
	url = "N/A"
};
//插件开始时.
public void OnPluginStart() 
{
	RegConsoleCmd("sm_banlist", Command_BanList, "封禁列表.");
	
	BuildPath(Path_SM, g_skvPath, sizeof(g_skvPath), "configs/l4d2_banned.cfg");
	IsReadFileValues();
	
	if (!g_dbSQL)
		IniSQLite();

	if (g_bLateLoad)//如果插件是延迟加载.
		SQL_LoadAll();//读取所有玩家数据.

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}
//封禁列表.
public Action Command_BanList(int client, int args)
{
	OpenBanListMenu(client, 0, false);
	return Plugin_Handled;
}
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;
	
	g_hTopMenu = topmenu;
	
	TopMenuObject hTopMenuObject = FindTopMenuCategory(g_hTopMenu, "OtherFeatures");
	if (hTopMenuObject == INVALID_TOPMENUOBJECT)
		hTopMenuObject = AddToTopMenu(g_hTopMenu, "OtherFeatures", TopMenuObject_Category, hMenuHandler, INVALID_TOPMENUOBJECT);
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_banlist",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_banlist",ADMFLAG_ROOT);
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
			Format(buffer, maxlength, "封禁列表", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			OpenBanListMenu(param, 0, true);
		}
	}
}
void IsReadFileValues()
{
	char sDatabaseType[MAX_LENGTH];
	KeyValues kv = new KeyValues("DatabaseType");
	if (!FileExists(g_skvPath))
	{
		File file = OpenFile(g_skvPath, "w");//读取指定文件.
		if (!file)//读取文件失败.
			LogError("无法读取文件: \"%s\"", g_skvPath);//显示错误信息.
		IntToString(g_bDatabaseType, sDatabaseType, sizeof(sDatabaseType));
		kv.SetString("设置数据库类型. 0=Sqlite, 1=MySQL.", sDatabaseType);//写入指定的内容.
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_skvPath);//把数据写入到文件.
		delete file;//删除句柄.
	}
	else if (kv.ImportFromFile(g_skvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		// 获取Kv文本内信息写入变量中.
		IntToString(g_bDatabaseType, sDatabaseType, sizeof(sDatabaseType));
		kv.GetString("设置数据库类型. 0=Sqlite, 1=MySQL.", sDatabaseType, sizeof(sDatabaseType), sDatabaseType);//获取文件里指定的内容.
		g_bDatabaseType = view_as<bool>(StringToInt(sDatabaseType));
	}
	delete kv;//删除句柄.
}
//所有插件加载完成后执行一次(延迟加载插件也会执行一次).
public void OnAllPluginsLoaded()   
{
	ServerCommand("exec banned_user.cfg");//加载服务器封禁列表.
}
//创建数据库或表.
void IniSQLite() 
{	
	char error[1024];
	if(g_bDatabaseType == false)
	{
		if (!(g_dbSQL = SQLite_UseDatabase("l4d2_banned", error, sizeof error)))//创建指定名称的数据库.
			SetFailState("Could not connect to the database \"l4d2_banned\" at the following error:\n%s", error);

		SQL_FastQuery(g_dbSQL, "CREATE TABLE IF NOT EXISTS l4d2_banned\
		(\
		SteamID NVARCHAR(32) NOT NULL DEFAULT '', \
		banreason NVARCHAR(32) NOT NULL DEFAULT '', \
		bantime INT NOT NULL DEFAULT 0, \
		timestamp INT NOT NULL DEFAULT 0);\
		");
	}
	else
	{
		g_dbSQL = SQL_DefConnect(error, sizeof error, true);
		if (g_dbSQL) 
		{
			SQL_FastQuery(g_dbSQL, "CREATE TABLE `l4d2_banned`  (\
									`SteamID` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,\
									`banreason` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,\
									`bantime` int NOT NULL,\
									`timestamp` int NOT NULL,\
									PRIMARY KEY (`SteamID`) USING BTREE\
									) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;");
		}
		if (!g_dbSQL) {
			SetFailState("数据库连接失败: %s", error);
			g_dbSQL.Close();
			return;
		}
		if (!SQL_SetCharset(g_dbSQL, "utf8mb4")) {
			if (SQL_GetError(g_dbSQL, error, sizeof error))
				SetFailState("无法更改为utf8mb4字符集,错误信息: %s", error);
			else
				SetFailState("无法更改为utf8mb4字符集,错误信息: 未知");

			g_dbSQL.Close();
			return;
		}
	}
}
//读取所有玩家数据.
stock void SQL_LoadAll() 
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) 
		{
			char auth[MAX_LENGTH];
			if (GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth))) 
				SQL_Load(0, auth, "", false);//读取玩家数据.
			else
				KickClient(i, "你已被踢出.\n踢出原因:ID获取失败.\n你的ID为:%s.", auth);
		}
	}
}
//地图开始.
public void OnMapStart()
{
	IsReadFileValues();
	ServerCommand("exec banned_user.cfg");//加载服务器封禁列表.
	//PrintToServer("[地图开始](%f)(%d).", GetEngineTime(), g_bAllAllowReadingData);
}
//玩家连接游戏并完全进入游戏时.
public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client) && g_eBanned[client].g_bBanStatus)
	{
		g_eBanned[client].g_bBanStatus = false;
		PrintToChat(client, "\x04[提示]\x05你已解封.");
		PrintToChat(client, "\x04[提示]\x05封禁时长:%s.", g_eBanned[client].sBanDuration);
		PrintToChat(client, "\x04[提示]\x05封禁时间:%s.", g_eBanned[client].sBanTime);
		PrintToChat(client, "\x04[提示]\x05解封时间:%s.", g_eBanned[client].sUnBanTime);
		PrintToChat(client, "\x04[提示]\x05封禁原因:%s.", g_eBanned[client].sBanReason);
	}
}
//玩家成功连接游戏时.
public void OnClientAuthorized(int client, const char[] auth)
{
	if (!IsFakeClient(client))
	{
		char sAuth[MAX_LENGTH];
		g_eBanned[client].g_bBanStatus = false;
		if (GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)))
		{
			SQL_Load(0, auth, "", false);//读取玩家数据.
		}
		else
			KickClient(client, "你已被踢出.\n踢出原因:ID获取失败.\n你的ID为:%s.", auth);//执行踢出玩家并显示原因.
	}
}
//读取玩家数据.
stock void SQL_Load(int time, const char[] auth, const char[] reason, bool write) 
{
	if (!g_dbSQL)
		return;

	char query[1024];
	FormatEx(query, sizeof query, "SELECT * FROM l4d2_banned WHERE SteamId = '%s';", auth);
	DataPack hPack = new DataPack();
	hPack.WriteCell(time);
	hPack.WriteCell(write);
	hPack.WriteString(auth);
	hPack.WriteString(reason);
	g_dbSQL.Query(SQLQueryCallback, query, hPack);
}
//数据库查询回调.
void SQLQueryCallback(Database db, DBResultSet results, const char[] error, DataPack hPack) 
{
	hPack.Reset();
	int time = hPack.ReadCell();
	bool write = view_as<bool>(hPack.ReadCell());

	char auth[MAX_LENGTH];
	hPack.ReadString(auth, sizeof(auth));
	
	char reason[MAX_LENGTH];
	hPack.ReadString(reason, sizeof(reason));

	if (!db || !results) 
	{
		delete hPack;
		LogError(error);
		return;
	}

	int iNowTime = GetTime();

	if (results.FetchRow())
	{	
		char sBanReason[MAX_LENGTH];
		results.FetchString(1, sBanReason, sizeof(sBanReason));
		int iBanTime = results.FetchInt(2);
		int iTimeStamp = results.FetchInt(3);

		if(iBanTime <= 0)
		{
			KickEntity(auth, "你已被封禁.\n封禁时长:永久封禁.\n封禁时间:%s.\n封禁原因:%s", GetDateTime(iTimeStamp), sBanReason);
		}
		else
		{
			if(iBanTime * 60 + iTimeStamp > iNowTime)
			{
				int iSurplus = iBanTime * 60 - (iNowTime - iTimeStamp);
				if(write)
				{
					SQL_Save(time + iBanTime, iTimeStamp, auth, reason[0] == '\0' ? "未填写封禁原因" : reason);//如果已存在数据就更新.
					//PrintToChatAll("\x04[提示]\x05剩余时长(%s),解封时间(%s).", StandardizeTime((time + iBanTime) * 60 - (iNowTime - iTimeStamp)), GetDateTime((time + iBanTime) * 60 + iTimeStamp));
				}
				else
				{
					KickEntity(auth, "你已被封禁.\n剩余时长:%s.\n封禁时长:%s.\n封禁时间:%s.\n解封时间:%s.\n封禁原因:%s", 
					StandardizeTime(iSurplus), StandardizeTime(iBanTime * 60), 
					GetDateTime(iTimeStamp), GetDateTime(iTimeStamp + iBanTime * 60), sBanReason);
				}
			}
			else
			{
				if(write)
					SQL_Save(time, iNowTime, auth, reason[0] == '\0' ? "未填写封禁原因" : reason);//如果已存在数据就更新.
				else
				{
					SQL_Delete(auth);//删除指定的玩家数据.
					int client = GetClientAuthIndex(auth);
	
					if(client != 0)
					{
						g_eBanned[client].g_bBanStatus = true;
						strcopy(g_eBanned[client].sBanTime, sizeof(esBanned::sBanTime), GetDateTime(iTimeStamp));
						strcopy(g_eBanned[client].sBanReason, sizeof(esBanned::sBanReason), sBanReason);
						strcopy(g_eBanned[client].sUnBanTime, sizeof(esBanned::sUnBanTime), GetDateTime(iTimeStamp + iBanTime * 60));
						strcopy(g_eBanned[client].sBanDuration, sizeof(esBanned::sBanDuration), StandardizeTime(iBanTime * 60));
					}
				}
			}
		}
	}
	else 
	{
		if(write)
		{
			char query[1024];
			FormatEx(query, sizeof query, "INSERT INTO l4d2_banned(SteamID, banreason, bantime, timestamp) VALUES ('%s', '%s', %d, %d);", auth, reason[0] == '\0' ? "未填写封禁原因" : reason, time, iNowTime);
			SQL_FastQuery(g_dbSQL, query);

			if(time <= 0)
				KickEntity(auth, "你已被封禁.\n封禁时长:永久封禁.\n封禁时间:%s.\n封禁原因:%s", 
				GetDateTime(iNowTime), reason[0] == '\0' ? "未填写封禁原因" : reason);
			else
				KickEntity(auth, "你已被封禁.\n封禁时长:%s.\n封禁时间:%s.\n解封时间:%s.\n封禁原因:%s", 
				StandardizeTime(time * 60), GetDateTime(iNowTime), GetDateTime(time * 60 + iNowTime), reason[0] == '\0' ? "未填写封禁原因" : reason);
		}
	}
	delete hPack;
}
stock char[] GetDateTime(int stamp = -1)
{
	char sDate[128];
	FormatTime(sDate, sizeof(sDate), "%Y-%m-%d %H:%M:%S", stamp);
	return sDate;
}
stock void KickEntity(const char[] auth, const char[] format="", any ...)
{
	int client = GetClientAuthIndex(auth);
	
	if(client != 0)
	{
		char buffer[255];
		VFormat(buffer, sizeof(buffer), format, 3);//第四个参数表示(any ...)所在的位置.
		KickClient(client, "%s", buffer);
	}
}
//获取Auth对应的玩家索引.
stock int GetClientAuthIndex(const char[] auth) 
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{	
			char Auth[MAX_LENGTH];
			if (GetClientAuthId(i, AuthId_Steam2, Auth, sizeof(Auth)))
				if(strcmp(auth, Auth) == 0)//对比字符串.
					return i;
		}
	}
	return 0;
}
//删除指定的玩家数据.
stock void SQL_Delete(const char[] auth) 
{
	char query[1024];
	FormatEx(query, sizeof query, "DELETE FROM l4d2_banned WHERE SteamID = '%s';", auth);
	g_dbSQL.Query(SQL_CallbackDelOld, query);
}
//删除数据回调.
void SQL_CallbackDelOld(Database db, DBResultSet results, const char[] error, any data) 
{
	if (!db || !results) 
	{
		LogError(error);
		return;
	}
}
//更新玩家数据.
stock void SQL_Save(int time, int iNowTime, char[] auth, char[] reason) 
{
	if (!g_dbSQL)
		return;

	char query[1024];
	FormatEx(query, sizeof query, "UPDATE l4d2_banned SET banreason = '%s', bantime = %d, timestamp = %d WHERE SteamID = '%s';", reason[0] == '\0' ? "无" : reason, time, iNowTime, auth);
	SQL_FastQuery(g_dbSQL, query);

	if(time == 0)
		KickEntity(auth, "你已被封禁.\n封禁时长:永久封禁.\n封禁时间:%s.\n封禁原因:%s.", GetDateTime(iNowTime), reason[0] == '\0' ? "无" : reason);
	else
		KickEntity(auth, "你已被封禁.\n额外时长:%s.\n封禁时间:%s.\n解封时间:%s.\n封禁原因:%s.", StandardizeTime(time * 60), GetDateTime(time * 60 + iNowTime), reason[0] == '\0' ? "无" : reason);
}
//float fTime[] = {31536000.0, 2626560.0, 86400.0, 3600.0, 60.0};
//https://forums.alliedmods.net/showthread.php?t=288686
stock char[] StandardizeTime(int iRunTime)
{
	int iTemp[4];
	char sData[128], sTime[sizeof(iTemp)][32];
	float remainder = float(iRunTime);
	float fTime[] = {86400.0, 3600.0, 60.0};
	char sDate[][] = {"天", "小时", "分钟", "秒"};
	
	iTemp[0] = RoundToFloor(remainder / fTime[0]);
	remainder = remainder - float(iTemp[0]) * fTime[0];

	iTemp[1] = RoundToFloor(remainder / fTime[1]);
	remainder = remainder - float(iTemp[1]) * fTime[1];

	iTemp[2] = RoundToFloor(remainder / fTime[2]);
	remainder = remainder - float(iTemp[2]) * fTime[2];

	iTemp[3] = RoundToFloor(remainder);

	if(iTemp[0] > 0)
		FormatEx(sTime[0], sizeof(sTime[]), "%d%s", iTemp[0], sDate[0]);
	else
	{
		for (int i = 0; i < sizeof(sTime); i++)
			if(iTemp[i] > 0)
				FormatEx(sTime[i], sizeof(sTime[]), "%d%s", iTemp[i], sDate[i]);
	}
	ImplodeStrings(sTime, sizeof(sTime), "", sData, sizeof(sData));//打包字符串.
	return sData;
}
void OpenBanListMenu(int client, int index, bool bButton = false)
{
	char sLine[128], sData[32];
	Menu menu = new Menu(MenuBanListHandler);
	Format(sLine, sizeof(sLine), "封禁列表:\n ");
	IntToString(bButton, sData, sizeof(sData));
	menu.SetTitle("%s", sLine);
	menu.AddItem(sData, "到期封禁");
	menu.AddItem(sData, "临时封禁");
	menu.AddItem(sData, "永久封禁");
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int MenuBanListHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128], sName[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			SQL_QueryBanList(client, 0, view_as<bool>(StringToInt(sItem)), itemNum, sName);
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
//查询封禁列表.
void SQL_QueryBanList(int client, int iIndex, bool bButton, int type, char[] sName)
{
	if (!g_dbSQL)
		return;
	
	char query[1024];

	switch(type)
	{
		case 0:
			FormatEx(query, sizeof(query), "SELECT * FROM l4d2_banned WHERE bantime > 0 ORDER BY timestamp DESC;");//到期封禁.
		case 1:
			FormatEx(query, sizeof(query), "SELECT * FROM l4d2_banned WHERE bantime > 0 ORDER BY timestamp DESC;");//临时封禁.
		case 2:
			FormatEx(query, sizeof(query), "SELECT * FROM l4d2_banned WHERE bantime = 0 ORDER BY timestamp DESC;");//永久封禁.
		
		
	}
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteCell(iIndex);
	hPack.WriteCell(bButton);
	hPack.WriteCell(type);
	hPack.WriteString(sName);
	g_dbSQL.Query(SQL_CallbackAllLoad, query, hPack);
}
//查询结果回调.
void SQL_CallbackAllLoad(Database db, DBResultSet results, const char[] error, DataPack hPack) 
{
	int client;
	hPack.Reset();
	if (!(client = GetClientOfUserId(hPack.ReadCell())))
	{
		delete hPack;
		return;
	}
	if (!db || !results) 
	{
		delete hPack;
		LogError("[错误]%N查询封禁信息时出现错误,原因:%s", client, error);
		return;
	}
	int iIndex = hPack.ReadCell();
	bool bButton = view_as<bool>(hPack.ReadCell());
	g_bButton[client] = bButton;
	int type = hPack.ReadCell();
	char sName[32];
	hPack.ReadString(sName, sizeof(sName));

	esBanList banlist;
	ArrayList ListArray = new ArrayList(sizeof(banlist));

	while (results.FetchRow())
	{
		char sSteamID[128];
		results.FetchString(0, sSteamID, sizeof(sSteamID));
		char sBanReason[128];
		results.FetchString(1, sBanReason, sizeof(sBanReason));
		int iBanTime = results.FetchInt(2);
		int iTimesTamp = results.FetchInt(3);
		int iNowTime = GetTime();

		switch(type)
		{
			case 0:
			{
				if(iBanTime * 60 + iTimesTamp <= iNowTime)
				{
					strcopy(banlist.esSteamID, sizeof(esBanList::esSteamID), sSteamID);
					strcopy(banlist.esBanReason, sizeof(esBanList::esBanReason), sBanReason);
					banlist.eiBanTime = iBanTime;
					banlist.eiTimesTamp = iTimesTamp;
					ListArray.PushArray(banlist);//推送数据到动态数组末尾.
				}
			}
			case 1:
			{
				if(iBanTime * 60 + iTimesTamp > iNowTime)
				{
					strcopy(banlist.esSteamID, sizeof(esBanList::esSteamID), sSteamID);
					strcopy(banlist.esBanReason, sizeof(esBanList::esBanReason), sBanReason);
					banlist.eiBanTime = iBanTime;
					banlist.eiTimesTamp = iTimesTamp;
					ListArray.PushArray(banlist);//推送数据到动态数组末尾.
				}
			}
			case 2:
			{
				strcopy(banlist.esSteamID, sizeof(esBanList::esSteamID), sSteamID);
				strcopy(banlist.esBanReason, sizeof(esBanList::esBanReason), sBanReason);
				banlist.eiBanTime = iBanTime;
				banlist.eiTimesTamp = iTimesTamp;
				ListArray.PushArray(banlist);//推送数据到动态数组末尾.
			}
		}
	}
	delete hPack;
	DisplayBanListMenu(client, iIndex, bButton, type, ListArray, sName);
}
void DisplayBanListMenu(int client, int iIndex, bool bButton, int type, ArrayList ListArray, char[] sName)
{
	if(ListArray.Length == 0)
	{
		delete ListArray;
		PrintToChat(client, "\x04[提示]\x05没有查询到\x03%s\x05.", sName);
		OpenBanListMenu(client, 0, bButton);
		return;
	}

	esBanList banlist;
	char sLine[128], sData[256], sInfo[8][128];
	Menu menu = new Menu(MenuDisplayBanListHandler);
	Format(sLine, sizeof(sLine), "%s:\n ", sName);
	menu.SetTitle("%s", sLine);

	for (int i = 0; i < ListArray.Length; i++)
	{
		ListArray.GetArray(i, banlist);

		Format(sInfo[0], sizeof(sInfo[]), "%s", banlist.esSteamID);
		Format(sInfo[1], sizeof(sInfo[]), "%s", banlist.esBanReason);
		Format(sInfo[2], sizeof(sInfo[]), "%d", banlist.eiBanTime);
		Format(sInfo[3], sizeof(sInfo[]), "%d", banlist.eiTimesTamp);
		Format(sInfo[4], sizeof(sInfo[]), "%d", bButton);
		Format(sInfo[5], sizeof(sInfo[]), "%d", iIndex);
		Format(sInfo[6], sizeof(sInfo[]), "%s", sName);
		Format(sInfo[7], sizeof(sInfo[]), "%d", type);
		ImplodeStrings(sInfo, sizeof(sInfo), "|", sData, sizeof(sData));//打包字符串.

		switch(type)
		{
			case 0:
				Format(sLine, sizeof(sLine), "解封:(%s),玩家:(%s)", GetDateTime(StringToInt(sInfo[2]) * 60 + StringToInt(sInfo[3])), sInfo[0]);
			case 1:
				Format(sLine, sizeof(sLine), "玩家:(%s),剩余:(%s)", sInfo[0], StandardizeTime(StringToInt(sInfo[2]) * 60 - (GetTime() - StringToInt(sInfo[3]))));
			case 2:
				Format(sLine, sizeof(sLine), "封禁:(%s),玩家:(%s)", GetDateTime(StringToInt(sInfo[3])), sInfo[0]);
		}
		menu.AddItem(sData, sLine);
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, iIndex, MENU_TIME_FOREVER);
	delete ListArray;
}
//菜单回调.
int MenuDisplayBanListHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[256], sName[128];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			OpenDeleteBanDataMenu(client, sItem, menu.Selection);
		}
		case MenuAction_Cancel:
			if (itemNum == MenuCancel_ExitBack)
				OpenBanListMenu(client, 0, g_bButton[client]);
	}
	return 0;
}
void OpenDeleteBanDataMenu(int client, char[] sItem, int iIndex)
{
	int iNowTime = GetTime();
	char sLine[128], sInfo[8][128];
	ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.

	Format(g_sPlayerData[0][client], sizeof(g_sPlayerData[][]), "%s", sInfo[0]);
	Format(g_sPlayerData[1][client], sizeof(g_sPlayerData[][]), "%s", sInfo[4]);
	Format(g_sPlayerData[2][client], sizeof(g_sPlayerData[][]), "%d", iIndex);
	Format(g_sPlayerData[3][client], sizeof(g_sPlayerData[][]), "%s", sInfo[6]);
	Format(g_sPlayerData[4][client], sizeof(g_sPlayerData[][]), "%s", sInfo[7]);

	int time = StringToInt(sInfo[2]) * 60 - (iNowTime - StringToInt(sInfo[3]));
	Panel panel = new Panel();

	Format(sLine, sizeof(sLine), "封禁类型:(%s)", StringToInt(sInfo[2]) == 0 ? "永封" : time <= iNowTime ? "临封" : "解封");
	panel.SetTitle(sLine);
	Format(sLine, sizeof(sLine), "剩余时长:(%s)", StringToInt(sInfo[2]) == 0 ? "永封" : StringToInt(sInfo[2]) * 60 + StringToInt(sInfo[3]) > iNowTime ? StandardizeTime(time) : "解封");
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	Format(sLine, sizeof(sLine), "封禁时长:(%s)", StringToInt(sInfo[2]) == 0 ? "永久封禁" : StandardizeTime(StringToInt(sInfo[2]) * 60));
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	Format(sLine, sizeof(sLine), "解封时间:(%s)", StringToInt(sInfo[2]) == 0 ? "永久封禁" : time > iNowTime ? StandardizeTime(time) : GetDateTime(StringToInt(sInfo[2]) * 60 + StringToInt(sInfo[3])));
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	Format(sLine, sizeof(sLine), "封禁时间:(%s)", GetDateTime(StringToInt(sInfo[3])));
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	Format(sLine, sizeof(sLine), "玩家名称:(%s)", sInfo[0]);
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	Format(sLine, sizeof(sLine), "封禁原因:(%s)", sInfo[1]);
	panel.DrawItem(sLine, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);

	panel.DrawText(" \n");
	panel.DrawItem("删除");
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem(" ", ITEMDRAW_SPACER);
	panel.DrawItem("返回");
		
	panel.DrawText(" \n");
	panel.DrawItem("0. 退出", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	panel.Send(client, MenuDeleteBanDataHandler, MENU_TIME_FOREVER);
}
//菜单回调.
int MenuDeleteBanDataHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			switch(itemNum)
			{
				case 1:
					SQL_DeleteBanData(client, g_sPlayerData[0][client]);
				case 8:
					SQL_QueryBanList(client, StringToInt(g_sPlayerData[2][client]), view_as<bool>(StringToInt(g_sPlayerData[1][client])), StringToInt(g_sPlayerData[4][client]), g_sPlayerData[3][client]);//重新打开菜单.
			}
		}
	}
	return 0;
}
//删除指定的密钥数据.
stock void SQL_DeleteBanData(int client, const char[] sSteamID) 
{
	char query[1024];
	FormatEx(query, sizeof query, "DELETE FROM l4d2_banned WHERE SteamID = '%s';", sSteamID);
	g_dbSQL.Query(SQL_CallbackBanData, query, GetClientUserId(client));
}
//删除数据回调.
void SQL_CallbackBanData(Database db, DBResultSet results, const char[] error, any client) 
{
	if ((client = GetClientOfUserId(client)))
		SQL_QueryBanList(client, StringToInt(g_sPlayerData[2][client]), view_as<bool>(StringToInt(g_sPlayerData[1][client])), StringToInt(g_sPlayerData[4][client]), g_sPlayerData[3][client]);//重新打开菜单.
}
//监听封禁函数.
public Action OnBanClient(int client, int time, int flags, const char[] reason, const char[] kick_message, const char[] command, any source)
{
	if(flags & BANFLAG_NOKICK)//封禁玩家函数添加了禁用踢出玩家功能时使用此插件的数据库方式记录封禁信息.
	{
		char auth[128];
		if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
			SQL_Load(time, auth, reason[0] == '\0' ? "无" : reason, true);//读取玩家数据.
		else
			KickClient(client, "你已被踢出.\n踢出原因:ID获取失败.你的ID为:%s.", auth);
		//PrintToChat(client, "\x04[提示]\x05有禁用踢出功能%d|%d.", flags, BANFLAG_NOKICK);
		return Plugin_Handled;//阻止写入封禁信息.
	}
	//PrintToChat(client, "\x04[提示]\x05无禁用踢出功能%d|%d.", flags, BANFLAG_NOKICK);
	return Plugin_Continue;//允许写入封禁信息.
}
//监听封禁函数.
public Action OnBanIdentity(const char[] auth, int time, int flags, const char[] reason, const char[] command, any source)
{
	if (!StrEqual(auth, "STEAM_ID_STOP_IGNORING_RETVALS", false))
		SQL_Load(time, auth, reason[0] == '\0' ? "无" : reason, true);//读取玩家数据.
	else
		KickEntity(auth, "你已被踢出.\n踢出原因:ID获取失败.你的ID为:%s.", auth);//执行踢出玩家并显示原因.
	return Plugin_Handled;//阻止写入封禁信息.
}
//监听解封函数.
public Action OnRemoveBan(const char[] auth, int flags, const char[] command, any source)
{
	SQL_Delete(auth);//删除指定的记录.
	return Plugin_Continue;//允许删除封禁信息.
}