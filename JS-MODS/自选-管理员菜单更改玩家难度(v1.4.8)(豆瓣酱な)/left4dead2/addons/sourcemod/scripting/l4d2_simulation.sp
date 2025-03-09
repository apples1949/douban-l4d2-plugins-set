/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *	2:女巫对生还者的伤害只修改了倒地后的持续攻击伤害.
 *	3:目前插件只适用于未修改特感对生还者伤害的服务器使用,并且只适用于战役模式.
 *
 *	v1.1.0
 *
 *	1:新增Native用于获取和设置玩家自定义难度.
 *
 *	v1.1.1
 *
 *	1:修复载图后客户端难度设置不正确的问题.
 *
 *	v1.1.2
 *
 *	1:修复使用命令打开菜单时会显示返回上一层的问题.
 *
 *	v1.1.3
 *
 *	1:修复是默认难度时数据库回调里数组报错的问题.
 *	2:新增是默认难度或数据库值不正确时删除对应的玩家数据.
 *
 *	v1.1.4
 *
 *	1:函数CacheSteamID()里某个变量多写了个[0].
 *
 *	v1.1.5
 *
 *	1:修复函数SetCustomizeDifficulty()设置为默认难度无效和报错的问题.
 *
 *	v1.2.6
 *
 *	1:修复更改游戏难度后TAB状态栏的自定义难度显示异常的问题.
 *	2:新增女巫秒杀更改,专家难度下使用临时更改为高级难度解决秒杀生还者的问题,非专家时使用参数解决不能秒杀生还者问题.
 *
 *	v1.2.7
 *
 *	1:修复二级菜单返回位置错误的问题.
 *
 *	v1.3.7
 *
 *	1:优化一些细节方面的问题.
 *
 *	v1.4.8
 *
 *	1:新增使用MySQL数据库类型.
 *	2:设置为默认难度时连接立即删除对应的数据库数据.
 *
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdkhooks>

#define DEBUG	0	//0=禁用调试信息,1=显示调试信息.
#define PLUGIN_VERSION	"1.4.8"
#define MAX_LENGTH		128		//字符串最大值.

Database g_dbSQL;

bool 
	g_bLateLoad, 
	g_bDatabaseLoaded[MAXPLAYERS+1], 
	g_bDatabaseInitial[MAXPLAYERS+1];

ConVar g_hDifficulty;

int g_iDatabaseType = 0;//设置插件配置文件时默认使用的数据库类型. 0=Sqlite, 1=MySQL.
int g_iPlayerMenuvalue[2][MAXPLAYERS + 1];
int g_iDamageMultiple[MAXPLAYERS + 1] = {-1,...};

char g_skvPath[PLATFORM_MAX_PATH];
char g_sAuthId[MAXPLAYERS + 1][128];
char g_sDifficultyName[][] = {"简单", "普通", "高级", "专家"};
char g_sDifficultyCode[][] = {"Easy", "Normal", "Hard", "Impossible"};

float g_fSmokerDamageMultiple[][] = 
{
	{1.0,2.0,5.0,20.0},
	{10.0,10.0,20.0,30.0}
};
float g_fBoomerDamageMultiple[][] = 
{
	{1.0,2.0,5.0,20.0},
	{1.0,2.0,5.0,20.0}
};
float g_fHunterDamageMultiple[][] = 
{
	{10.0,10.0,20.0,40.0},
	{5.0,5.0,10.0,15.0}
};
float g_fSpitterDamageMultiple[][] = 
{
	{1.0,2.0,5.0,20.0},
	{0.5,1.0,1.0,1.0}
};
float g_fJockeyDamageMultiple[][] = 
{
	{1.0,2.0,5.0,20.0},
	{4.0,4.0,8.0,12.0}
};
float g_fChargerDamageMultiple[][] = 
{
	{10.0,20.0,30.0,40.0},
	{10.0,10.0,15.0,20.0}
};
float g_fTankDamageMultiple[][] = 
{
	{24.0,24.0,33.0,100.0},
	{75.0,75.0,75.0,150.0}
};
float g_fWitchDamageMultiple[][] = 
{
	{15.0,30.0,60.0,300.0},
	{100.0,100.0,100.0,100.0}
};
float g_fInfectedDamageMultiple[][] = 
{
	{1.0,2.0,5.0,20.0},
	{10.0,10.0,10.0,10.0}
};

TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();
	g_bLateLoad = late;
	RegPluginLibrary("l4d2_simulation");
	return APLRes_Success;
}
//定义插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_simulation",
	author 			= "豆瓣酱な",
	description 	= "在当前游戏难度下模拟其它游戏难度,适用于未修改特感,丧尸,女巫对生还者伤害的普通战役服务器使用.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
public void OnPluginStart()
{
	if (!g_dbSQL)
		IniSQLite();

	if (g_bLateLoad)
		SQL_LoadAll();
	
	g_hDifficulty = FindConVar("z_Difficulty");
	
	RegConsoleCmd("sm_difficulty", Command_DifficultyMenu, "打开难度菜单.");
	HookEvent("player_disconnect", Event_PlayerDisconnect);//玩家离开.
	HookEvent("difficulty_changed", Event_DifficultyChanged);

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}
//插件被卸载时.
public void OnPluginEnd() 
{
	g_dbSQL.Close();//断开数据库连接.
}
void IniSQLite() 
{	
	char error[1024];
	IsReadFileValues();//获取需要使用的数据库类型.
	if(g_iDatabaseType == 0)
	{
		if (!(g_dbSQL = SQLite_UseDatabase("playerdifficulty", error, sizeof error)))
			SetFailState("Could not connect to the database \"playerdifficulty\" at the following error:\n%s", error);

		SQL_FastQuery(g_dbSQL, "CREATE TABLE IF NOT EXISTS playerdifficulty(SteamID NVARCHAR(32) NOT NULL DEFAULT '', Difficulty INT NOT NULL DEFAULT -1);");
	}
	else
	{
		g_dbSQL = SQL_DefConnect(error, sizeof error, true);
		if (g_dbSQL) 
		{
			SQL_FastQuery(g_dbSQL, "CREATE TABLE IF NOT EXISTS `playerdifficulty` (\
											`SteamID` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,\
											`Difficulty` int NOT NULL,\
											PRIMARY KEY (`SteamID`) USING BTREE) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;");
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
//获取要使用的数据库类型.
stock void IsReadFileValues()
{
	char sDatabaseType[32];
	BuildPath(Path_SM, g_skvPath, sizeof(g_skvPath), "configs/l4d2_simulation.cfg");

	KeyValues kv = new KeyValues("DatabaseTypeValues");
	if (!FileExists(g_skvPath))
	{
		File file = OpenFile(g_skvPath, "w");//读取指定文件.
		if (!file)//读取文件失败.
			LogError("无法读取文件: \"%s\"", g_skvPath);//显示错误信息.

		IntToString(g_iDatabaseType, sDatabaseType, sizeof(sDatabaseType));

		kv.SetString("设置使用的数据库类型. 0=Sqlite, 1=MySQL.", sDatabaseType);//写入指定的内容.
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_skvPath);//把数据写入到文件.

		delete file;//删除句柄.
	}
	else if (kv.ImportFromFile(g_skvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		// 获取Kv文本内信息写入变量中.
		IntToString(g_iDatabaseType, sDatabaseType, sizeof(sDatabaseType));

		kv.GetString("设置使用的数据库类型. 0=Sqlite, 1=MySQL.", sDatabaseType, sizeof(sDatabaseType), sDatabaseType);//获取文件里指定的内容.

		g_iDatabaseType = StringToInt(sDatabaseType);
	}
	delete kv;//删除句柄.
}
//读取所有玩家数据.
stock void SQL_LoadAll() 
{
	for (int i = 1; i <= MaxClients; i++) 
		if (IsClientInGame(i) && !IsFakeClient(i)) 
			SQL_Load(i, false);//读取玩家数据.
}
//玩家完全加入游戏时.
public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client) && g_bDatabaseInitial[client] == true)
		g_hDifficulty.ReplicateToClient(client, g_iDamageMultiple[client] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[client]]);
}
//玩家加入游戏时.
public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client))
	{
		ResetClientData(client);//重置玩家数据.
		SQL_Load(client, false);//读取玩家数据.
	}
}
//重置玩家数据.
stock void ResetClientData(int client) 
{
	g_sAuthId[client][0] = '\0';
	g_iDamageMultiple[client] = -1;
	g_bDatabaseLoaded[client] = false;
	g_bDatabaseInitial[client] = false;
}
//读取玩家数据.
void SQL_Load(int client, bool write) 
{
	if (!g_dbSQL)
		return;

	if (!CacheSteamID(client))
		return;

	char query[256];
	FormatEx(query, sizeof query, "SELECT * FROM playerdifficulty WHERE SteamId = '%s';", g_sAuthId[client]);
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteCell(write);
	g_dbSQL.Query(SQL_CallbackLoad, query, hPack);
}
//数据库查询回调.
void SQL_CallbackLoad(Database db, DBResultSet results, const char[] error, DataPack hPack) 
{
	hPack.Reset();
	int client = GetClientOfUserId(hPack.ReadCell());
	bool write = view_as<bool>(hPack.ReadCell());

	if (!client)
	{
		delete hPack;
		return;
	}

	if (!db || !results) 
	{
		delete hPack;
		LogError("[错误]查询(%N)的数据时发生错误,原因:(%s)", client, error);
		return;
	}

	if (results.FetchRow())
	{	
		if(write)
		{
			if (g_iDamageMultiple[client] == -1)
			{
				g_bDatabaseInitial[client] = false;//设置布尔值.
				SQL_Delete(g_sAuthId[client]);//删除指定的玩家数据.
			}
			else
			{
				g_bDatabaseInitial[client] = true;//设置布尔值.
				SQL_Save(client, g_sAuthId[client], g_iDamageMultiple[client]);//如果已存在数据就更新.
			}
		}
		else
		{
			g_iDamageMultiple[client] = results.FetchInt(1);
			if (g_iDamageMultiple[client] == -1)
				SQL_Delete(g_sAuthId[client]);//删除指定的玩家数据.
			else
				g_bDatabaseInitial[client] = true;//设置布尔值.
		}
	}
	else 
	{
		if(write)
		{
			if(g_iDamageMultiple[client] != -1)
			{
				char query[256];
				FormatEx(query, sizeof query, "INSERT INTO playerdifficulty(SteamID, Difficulty) VALUES ('%s', %d);", g_sAuthId[client], g_iDamageMultiple[client]);
				g_dbSQL.Query(SQL_QueryCallInsert, query);
				g_bDatabaseInitial[client] = true;//设置布尔值.
			}
		}
	}
	delete hPack;
	g_bDatabaseLoaded[client] = true;
}
//异步查询回调.
void SQL_QueryCallInsert(Database db, DBResultSet results, const char[] error, any data) {}
//删除指定的玩家数据.
stock void SQL_Delete(const char[] auth) 
{
	char query[1024];
	FormatEx(query, sizeof query, "DELETE FROM playerdifficulty WHERE SteamID = '%s';", auth);
	g_dbSQL.Query(SQL_CallbackDelOld, query);
}
//删除数据回调.
void SQL_CallbackDelOld(Database db, DBResultSet results, const char[] error, any data) {}
//更新玩家数据.
stock void SQL_Save(int client, char[] auth, int difficulty) 
{
	if (!g_dbSQL)
		return;

	char query[256];
	FormatEx(query, sizeof query, "UPDATE playerdifficulty SET Difficulty = %d WHERE SteamID = '%s';", difficulty, auth);
	SQL_FastQuery(g_dbSQL, query);
	g_dbSQL.Query(SQL_CallbackUpdate, query);
}
//数据库查询回调.
void SQL_CallbackUpdate(Database db, DBResultSet results, const char[] error, any data) {}
stock bool CacheSteamID(int client) 
{
	if (g_sAuthId[client][0])
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_sAuthId[client][0], sizeof(g_sAuthId[])))
		return true;

	g_sAuthId[client][0] = '\0';
	return false;
}
//玩家离开.
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (client > 0 && !IsFakeClient(client))
		g_iDamageMultiple[client] = -1;
}
//难度更改.
public void Event_DifficultyChanged(Event event, const char[] name, bool dontBroadcast)
{
	RequestFrame(IsDifficultyChanged);//延迟一帧设置自定义难度.
}
//延迟一帧设置自定义难度.
void IsDifficultyChanged()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			g_hDifficulty.ReplicateToClient(i, g_iDamageMultiple[i] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[i]]);
}
//打开难度菜单.
public Action Command_DifficultyMenu(int client, int args)
{
	if(bCheckClientAccess(client))
		OpenPlayerMenu(client, 0, false);
	else
		ReplyToCommand(client, "\x04[提示]\x05你无权使用该指令.");
	
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
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_difficulty",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_difficulty",ADMFLAG_ROOT);
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
			Format(buffer, maxlength, "玩家难度", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			OpenPlayerMenu(param, 0, true);
		}
	}
}
void OpenPlayerMenu(int client, int index, bool bButton = false)
{
	char line[32];
	char sInfo[128];
	char sName[64];
	char sData[4][64];
	Menu menu = new Menu(MenuOpenPlayerHandler);
	Format(line, sizeof(line), "选择玩家:(%s)", GetCustomGameDifficulty());
	SetMenuTitle(menu, "%s", line);

	IntToString(-1, sData[0], sizeof(sData[]));
	strcopy(sData[1], sizeof(sData[]), "全部玩家");
	IntToString(index, sData[2], sizeof(sData[]));
	IntToString(bButton, sData[3], sizeof(sData[]));
	ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
	menu.AddItem(sInfo, sData[1]);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int Bot = IsClientIdle(i);
			GetClientName(Bot != 0 ? Bot : i, sData[1], sizeof(sData[]));
			FormatEx(sName, sizeof(sName), "(%s)%s", g_iDamageMultiple[Bot != 0 ? Bot : i] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[Bot != 0 ? Bot : i]], sData[1]);
			IntToString(GetClientUserId(Bot != 0 ? Bot : i), sData[0], sizeof(sData[]));
			IntToString(bButton, sData[3], sizeof(sData[]));
			IntToString(index, sData[2], sizeof(sData[]));
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, sName);
		}
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}
char[] GetCustomGameDifficulty()
{
	char sName[128] = "默认";
	char sDifficulty[32];
	GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));
	for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
		if(strcmp(sDifficulty, g_sDifficultyCode[i]) == 0)
			strcopy(sName, sizeof(sName), g_sDifficultyName[i]);

	return sName;
}
int MenuOpenPlayerHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128], sName[32], sInfo[4][64];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			IntToString(menu.Selection, sInfo[2], sizeof(sInfo[]));
			g_iPlayerMenuvalue[0][client] = StringToInt(sInfo[2]);
			g_iPlayerMenuvalue[1][client] = StringToInt(sInfo[3]);
			OpenDifficultyMenu(client, sInfo[0], sInfo[1], sInfo[2], sInfo[3]);
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
void OpenDifficultyMenu(int client, char[] sItem, char[] sName, char[] sIndex, char[] sButton)
{
	int victim = GetClientOfUserId(StringToInt(sItem));
	if(StringToInt(sItem) == -1 || IsValidClient(victim))
	{
		char line[32];
		char Item[32];
		char sInfo[128];
		char sData[7][32];
		Menu menu = new Menu(MenuOpenDifficultyHandler);
		Format(line, sizeof(line), "选择难度:(%s)\n ", sName);
		SetMenuTitle(menu, "%s", 	line);
		IntToString(-1, sData[0], sizeof(sData[]));
		strcopy(sData[1], sizeof(sData[]), sItem);
		strcopy(sData[2], sizeof(sData[]), sName);
		strcopy(sData[4], sizeof(sData[]), "默认");
		strcopy(sData[5], sizeof(sData[]), sButton);
		strcopy(sData[6], sizeof(sData[]), sIndex);
		if(StringToInt(sItem) == -1)
			Format(Item, sizeof(Item), "%s", "默认");
		else
			Format(Item, sizeof(Item), "[%s]%s", g_iDamageMultiple[victim] == -1 ? "●" : "○", "默认");
		ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
		menu.AddItem(sInfo, Item);

		for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
		{
			IntToString(i, sData[0], sizeof(sData[]));
			strcopy(sData[1], sizeof(sData[]), sItem);
			strcopy(sData[2], sizeof(sData[]), sName);
			strcopy(sData[3], sizeof(sData[]), g_sDifficultyCode[i]);
			strcopy(sData[4], sizeof(sData[]), g_sDifficultyName[i]);
			strcopy(sData[5], sizeof(sData[]), sButton);
			strcopy(sData[6], sizeof(sData[]), sIndex);
			if(StringToInt(sItem) == -1)
				Format(Item, sizeof(Item), "%s", g_sDifficultyName[i]);
			else
				Format(Item, sizeof(Item), "[%s]%s", g_iDamageMultiple[victim] == i ? "●" : "○", g_sDifficultyName[i]);
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, Item);
		}

		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = view_as<bool>(StringToInt(sButton));
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
		OpenPlayerMenu(client, StringToInt(sIndex), view_as<bool>(StringToInt(sButton)));
}
int MenuOpenDifficultyHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				char sInfo[7][32];
				ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
				if(StringToInt(sInfo[1]) == -1)
				{
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && GetClientTeam(i) == 2)
						{
							int Bot = IsClientIdle(i);
							
							if(Bot != 0)
							{
								g_iDamageMultiple[Bot] = StringToInt(sInfo[0]);
								SQL_Load(Bot, true);//读取玩家数据.
								if(Bot != client)
									PrintToChat(i, "\x04[提示]\x05已设置你的难度为\x03%s\x05难度.", sInfo[4]);
								else
									PrintToChat(client, "\x04[提示]\x05已设置\x03%s\x05为\x04%s\x05难度.", sInfo[2], sInfo[4]);
								g_hDifficulty.ReplicateToClient(Bot, g_iDamageMultiple[Bot] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[Bot]]);
							}
							else
							{
								g_iDamageMultiple[i] = StringToInt(sInfo[0]);

								if(!IsFakeClient(i))
								{
									SQL_Load(i, true);//读取玩家数据.
									if(i != client)
										PrintToChat(i, "\x04[提示]\x05已设置你的难度为\x03%s\x05难度.", sInfo[4]);
									else
										PrintToChat(client, "\x04[提示]\x05已设置\x03%s\x05为\x04%s\x05难度.", sInfo[2], sInfo[4]);
									g_hDifficulty.ReplicateToClient(i, g_iDamageMultiple[i] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[i]]);
								}
							}
						}
					}
				}
				else
				{
					int victim = GetClientOfUserId(StringToInt(sInfo[1]));
					if(IsValidClient(victim))
					{
						g_iDamageMultiple[victim] = StringToInt(sInfo[0]);
						
						if(!IsFakeClient(victim))
						{
							SQL_Load(victim, true);//读取玩家数据.
							if(victim != client)
								PrintToChat(client, "\x04[提示]\x05已设置\x03%s\x05为\x04%s\x05难度.", sInfo[2], sInfo[4]);
							PrintToChat(victim, "\x04[提示]\x05已设置你的难度为\x03%s\x05难度.", sInfo[4]);
							g_hDifficulty.ReplicateToClient(victim, g_iDamageMultiple[victim] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[victim]]);
						}
					}
				}
				OpenDifficultyMenu(client, sInfo[1], sInfo[2], sInfo[6], sInfo[5]);
				//OpenPlayerMenu(client, StringToInt(sInfo[6]), view_as<bool>(StringToInt(sInfo[5])));
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu != null)
			{
				//g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
				OpenPlayerMenu(client, g_iPlayerMenuvalue[0][client], view_as<bool>(g_iPlayerMenuvalue[1][client]));//重新打开菜单.
			}
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}
//玩家加入游戏时.
public void OnClientPutInServer(int client)
{
	//钩住玩家受伤.
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
//玩家受伤钩子回调.
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{ 
	if(IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		int Bot = IsClientIdle(victim);
		int value = g_iDamageMultiple[Bot != 0 ? Bot : victim];

		if(value == -1)
		{
			#if DEBUG
			PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05当前是默认难度不执行任何操作.");
			#endif
			return Plugin_Continue;//不执行任何操作.
		}

		if(g_bDatabaseInitial[Bot != 0 ? Bot : victim] == false)
		{
			#if DEBUG
			PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05数据未写入或未读取成功.");
			#endif
			return Plugin_Continue;//不执行任何操作.
		}
			
		if(GetGameDifficultyIndex() == value)
		{
			#if DEBUG
			PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05选择的难度与当前难度相同.");
			#endif
			return Plugin_Continue;//不执行任何操作.
		}

		if(IsValidClient(attacker) && GetClientTeam(attacker) == 3)
		{
			int iHLZClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");

			switch(iHLZClass)
			{
				case 1:
				{
					if (GetEntPropEnt(victim, Prop_Send, "m_tongueOwner") > 0)
					{
						damage = g_fSmokerDamageMultiple[1][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
					else
					{
						damage = g_fSmokerDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
				}
				case 2:
				{
					damage = g_fBoomerDamageMultiple[0][value];
					#if DEBUG
					PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
					#endif
					return Plugin_Changed;
				}
				case 3:
				{
					if (GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") > 0)
					{
						damage = g_fHunterDamageMultiple[1][value] * (IsPlayerFallen(victim) ? 3.0 : 1.0);//猎人对倒地的三倍伤害.
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
					else
					{
						damage = g_fHunterDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
				}
				case 4:
				{
					if(IsValidEntity(inflictor))
					{
						char classname[32];
						GetEntityClassname(inflictor, classname, sizeof classname);
						if (strcmp(classname, "insect_swarm") != 0)
						{
							damage = g_fSpitterDamageMultiple[0][value];
							#if DEBUG
							PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
							#endif
							return Plugin_Changed;
						}
						else
						{
							if(value == 0 && GetGameDifficultyIndex() > 0)
							{
								damage *= g_fSpitterDamageMultiple[1][value];
								#if DEBUG
								PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示1]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
								#endif
								return Plugin_Changed;
							}
						}
					}
				}
				case 5:
				{
					if (GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker") > 0)
					{
						damage = g_fJockeyDamageMultiple[1][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
					else
					{
						damage = g_fJockeyDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
				}
				case 6:
				{
					if(GetEntPropEnt(victim, Prop_Send, "m_carryAttacker") > 0)
					{
						damage = g_fChargerDamageMultiple[1][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示1]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
					else if(GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker") > 0)
					{
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示2]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Continue;//不执行任何操作.
					}
					else
					{
						damage = g_fChargerDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示3]\x05%s受到了%f点伤害(%d).", GetTrueName(victim), damage, iHLZClass);
						#endif
						return Plugin_Changed;
					}
				}
				case 8:
				{
					int Weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
					if(IsValidEntity(Weapon))
					{
						char classname[32];
						GetEntityClassname(Weapon, classname, sizeof classname);
						if (strcmp(classname, "weapon_tank_claw") == 0)//坦克拳头(坦克石头也可以触发这个类名,而且伤害是一样的).
						{
							if(IsPlayerFallen(victim))
							{
								damage = g_fTankDamageMultiple[1][value];
								#if DEBUG
								PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d)(%s).", GetTrueName(victim), damage, iHLZClass, classname);
								#endif
								return Plugin_Changed;
							}
							else
							{
								damage = g_fTankDamageMultiple[0][value];
								#if DEBUG
								PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害(%d)(%s).", GetTrueName(victim), damage, iHLZClass, classname);
								#endif
								return Plugin_Changed;
							}
						}
					}
				}
			}
		}
		else
		{
			if (IsValidEntity(attacker)) 
			{
				char classname[32];
				GetEntityClassname(attacker, classname, sizeof classname);

				if (strcmp(classname, "insect_swarm") == 0)
				{
					if(value == 0 && GetGameDifficultyIndex() > 0)
					{
						damage *= g_fSpitterDamageMultiple[1][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示1]\x05%s受到了%f点伤害.", GetTrueName(victim), damage);
						#endif
						return Plugin_Changed;
					}
				}
				else if (strcmp(classname, "infected") == 0)
				{
					if(IsPlayerState(victim))
					{
						damage = g_fInfectedDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害.", GetTrueName(victim), damage);
						#endif
						return Plugin_Changed;
					}
					//else//伤害好像全是一样的,不需要改.
					//{
					//	damage = g_fInfectedDamageMultiple[1][value];
					//	PrintToChat(victim, "\x04[提示]\x05%s受到了%f点伤害.", GetTrueName(victim), damage);
					//	return Plugin_Changed;
					//}
				}
				else if (strcmp(classname, "witch") == 0)
				{
					if(!IsPlayerState(victim))
					{
						damage = g_fWitchDamageMultiple[0][value];
						#if DEBUG
						PrintToChat(Bot != 0 ? Bot : victim, "\x04[提示]\x05%s受到了%f点伤害%d.", GetTrueName(victim), damage, damagetype);
						#endif
						return Plugin_Changed;
					}
					else
					{
						if(damage >= 100.0)//判断血量大于或等于100伤害.
						{
							bool bAlwaysKills = false;
							if(value != 3 && GetGameDifficultyIndex() == 3)//自定义难度为非专家实际难度为专家.
							{
								damage = g_fWitchDamageMultiple[1][value];
								if (GetConVarInt(FindConVar("z_witch_always_kills")) == 1)
								{
									bAlwaysKills = true;
									SetConVarInt(FindConVar("z_witch_always_kills"), 0);//开启女巫秒杀生还者? 0=关闭, 1=开启.
								}
									
								SetConVarString(FindConVar("z_Difficulty"), "Hard");//更改为高级难度.
								SDKHooks_TakeDamage(victim, inflictor, attacker, damage);//设置指定的伤害(专家难度下设置女巫对生还者的伤害也会秒杀生还者).
								SetConVarString(FindConVar("z_Difficulty"), "Impossible");//恢复为专家难度.
								if (bAlwaysKills == true)
									SetConVarInt(FindConVar("z_witch_always_kills"), 1);//开启女巫秒杀生还者? 0=关闭, 1=开启.
								return Plugin_Handled;
							}
							if(value == 3 && GetGameDifficultyIndex() != 3)//自定义难度为专家实际难度为非专家.
							{
								damage = g_fWitchDamageMultiple[1][value];
								if (GetConVarInt(FindConVar("z_witch_always_kills")) == 0)
								{
									bAlwaysKills = true;
									SetConVarInt(FindConVar("z_witch_always_kills"), 1);//开启女巫秒杀生还者? 0=关闭, 1=开启.
								}
								SDKHooks_TakeDamage(victim, inflictor, attacker, damage);//设置指定的伤害(专家难度下设置女巫对生还者的伤害也会秒杀生还者).
								if (bAlwaysKills == true)
									SetConVarInt(FindConVar("z_witch_always_kills"), 0);//开启女巫秒杀生还者? 0=关闭, 1=开启.
								return Plugin_Handled;
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;//不执行任何操作.
}
//倒地状态.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
//返回当前游戏难度索引.
stock int GetGameDifficultyIndex()
{
	char sDifficulty[32];
	GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));

	for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
		if(strcmp(g_sDifficultyCode[i], sDifficulty, false) == 0)
			return i;
	return -1;
}
//返回当前游戏难度名称.
stock char[] GetGameDifficultyName()
{
	char sDifficulty[32];
	GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));
	return sDifficulty;
}
//判断管理员权限.
stock bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
//玩家有效.
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
//返回玩家名称.
stock char[] GetTrueName(int client)
{
	char sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(sName, sizeof(sName), "闲置:%N", Bot);
	else
		GetClientName(client, sName, sizeof(sName));
	return sName;
}
//返回闲置玩家的电脑生还者.
int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}
//返回电脑生还者的所有者.
int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
void CreateNatives()
{
	CreateNative("GetCustomizeDifficulty",	GetNativeCustomizeDifficulty);
	CreateNative("SetCustomizeDifficulty",	SetNativeCustomizeDifficulty);
}
int GetNativeCustomizeDifficulty(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(IsValidClient(client))
	{
		switch(GetClientTeam(client))
		{
			case 1:
			{
				int iBot = iGetBotOfIdlePlayer(client);
				if(iBot != 0)
					return g_iDamageMultiple[client];
			}
			case 2:
			{
				int Bot = IsClientIdle(client);
				return g_iDamageMultiple[Bot != 0 ? Bot : client];
			}
		}
	}
	return 0;
}
int SetNativeCustomizeDifficulty(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);
	char[] sName = new char[MAX_LENGTH];
	char[] error = new char[MAX_LENGTH];
	
	if(value >= -1 && value <= 3)
	{
		if(IsValidClient(client))
		{
			switch(GetClientTeam(client))
			{
				case 1:
				{
					if(!IsFakeClient(client))
					{
						int iBot = iGetBotOfIdlePlayer(client);
						if(iBot != 0)
						{
							g_iDamageMultiple[client] = value;
							SQL_Load(client, true);//读取玩家数据.
							strcopy(sName, MAX_LENGTH, g_iDamageMultiple[client] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[client]]);
							SetNativeString(3, sName, MAX_LENGTH);
							//PrintToChat(client, "\x04[提示]\x05已设置\x03%N\x05为\x04%s\x05难度.", client, g_iDamageMultiple[client] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[client]]);
							g_hDifficulty.ReplicateToClient(client, g_iDamageMultiple[client] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[client]]);
							return 1;
						}
						else
						{
							strcopy(error, MAX_LENGTH, "旁观者禁止使用更改难度");
							SetNativeString(4, error, MAX_LENGTH);
							return 0;
						}
					}
				}
				case 2:
				{
					int iBot = IsClientIdle(client);
			
					if(iBot != 0)
					{
						g_iDamageMultiple[iBot] = value;
						SQL_Load(iBot, true);//读取玩家数据.
						strcopy(sName, MAX_LENGTH, g_iDamageMultiple[iBot] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[iBot]]);
						SetNativeString(3, sName, MAX_LENGTH);
						//PrintToChat(iBot, "\x04[提示]\x05已设置\x03%N\x05为\x04%s\x05难度.", iBot, g_iDamageMultiple[iBot] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[iBot]]);
						g_hDifficulty.ReplicateToClient(iBot, g_iDamageMultiple[iBot] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[iBot]]);
						return 1;
					}
					else
					{
						g_iDamageMultiple[client] = value;

						if(!IsFakeClient(client))
						{
							SQL_Load(client, true);//读取玩家数据.
							strcopy(sName, MAX_LENGTH, g_iDamageMultiple[client] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[client]]);
							SetNativeString(3, sName, MAX_LENGTH);
							//PrintToChat(client, "\x04[提示]\x05已设置\x03%N\x05为\x04%s\x05难度.", client, g_iDamageMultiple[client] == -1 ? "默认" : g_sDifficultyName[g_iDamageMultiple[client]]);
							g_hDifficulty.ReplicateToClient(client, g_iDamageMultiple[client] == -1 ? GetGameDifficultyName() : g_sDifficultyCode[g_iDamageMultiple[client]]);
						}
						return 1;
					}
				}
				case 3:
				{
					strcopy(error, MAX_LENGTH, "感染者禁止使用更改难度");
					SetNativeString(4, error, MAX_LENGTH);
					return 0;
				}
			}
		}
	}
	else
	{
		strcopy(error, MAX_LENGTH, "自定义难度值的范围是-1~3的整数");
		SetNativeString(4, error, MAX_LENGTH);
	}
	return 0;
}