#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION	"1.2.3"

#define CVAR_FLAGS	FCVAR_NOTIFY

int g_iBlockCmdsCount;

char g_sPassword[64], g_sSteamId[512], g_sAdminList[32][128], g_sBlockCmds[16][32], g_sAuthority[32] = "99:z";//添加管理员时的权限.

ConVar g_hPassword, g_hSteamId;

public Plugin myinfo = 
{
	name        = "admins_simple",
	author      = "豆瓣酱な",
	description = "添加或删除admins_simple.ini文件里的SteamId.",
	version     = "PLUGIN_VERSION",
	url         = "N/A"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_root", Command_AddRemoveAdmin);

	g_hPassword = CreateConVar("l4d2_admins_simple", "123456", "设置!root指令的密码(指令和密码不会显示到聊天窗).", FCVAR_NOTIFY);
	g_hSteamId = CreateConVar("l4d2_admins_steamId", "", "设置指定SteamId的玩家使用.\n设置多个SteamId用符号;分隔(留空=使用指令+密码).\n例如:(STEAM_1:1:123456789;STEAM_1:1:987654321).", FCVAR_NOTIFY);
	g_hPassword.AddChangeHook(SetConVarChanged);
	g_hSteamId.AddChangeHook(SetConVarChanged);
	AutoExecConfig(true, "l4d2_admins_simple");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	GetConVarChanged();
}

public void SetConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarChanged();
}

void GetConVarChanged()
{
	g_hPassword.GetString(g_sPassword, sizeof(g_sPassword));
	g_hSteamId.GetString(g_sSteamId, sizeof(g_sSteamId));

	if(g_sSteamId[0] != '\0')
	{
		g_iBlockCmdsCount = ReplaceString(g_sSteamId, sizeof(g_sSteamId), ";", ";", false);
		ExplodeString(g_sSteamId, ";", g_sBlockCmds, g_iBlockCmdsCount + 1, sizeof(g_sBlockCmds[]));
	}
}

public Action OnClientSayCommand(int client, const char[] commnad, const char[] args)
{
	if(strlen(args) <= 1 || strncmp(commnad, "say", 3, false) != 0)
		return Plugin_Continue;

	if(StrContains(args, g_sPassword) != -1 || StrContains(args, "root") != -1)
		return Plugin_Handled;//阻止玩家输入的指令显示出来,预防憨憨萌新把密码显示到聊天窗.
	
	return Plugin_Continue;
}

public Action Command_AddRemoveAdmin(int client, int args)
{
	GetPlayersContent(client, args);
	return Plugin_Handled;
}

void GetPlayersContent(int client, int args)
{
	if(g_sSteamId[0] != '\0')
	{
		if(AcquirePlayerRights(GetPlayersSteamId(client)))
			IsListRealSurvivor(client, 0);
		else
			PrintToChat(client, "\x04[提示]\x05你无权使用该指令.");
	}
	else
	{
		switch (args)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05用法:!root空格+密码(密码在配置文件l4d2_admins_simple.cfg里查看或修改).");
			}
			case 1:
			{
				char arg[64];
				GetCmdArgString(arg, sizeof(arg));
				if (StrEqual(arg, g_sPassword, false))
					IsListRealSurvivor(client, 0);
				else
					PrintToChat(client, "\x04[提示]\x05你输入的密码有误,请重新输入.");
			}
		}
	}
}

void IsListRealSurvivor(int client, int index)
{
	DumpAdminCache(AdminCache_Admins, true);//刷新管理员.
	int iLists = GetSteamIdLists();
	char SteamId[32], sMerge[128], sName[128], sData[4][128];
	Menu menu = new Menu(MenuHandler_ListRealSurvivor);
	menu.SetTitle("编辑管理员\n▬▬▬▬▬▬▬▬▬▬▬▬▬");

	for (int i = 0; i < iLists; i++)
	{
		char sInfo[4][128];
		ExplodeString(g_sAdminList[i], "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
		FormatEx(sName, sizeof(sName), "%s|%s|%s", GetAdministratorStatus(sInfo[0]) ? "在线" : "离线", sInfo[1], 
		GetAdministratorStatus(sInfo[0]) ? GetPlayersName(sInfo[0]) : sInfo[2][0] == '\0' ? sInfo[0] : sInfo[2]);
		strcopy(sInfo[3], sizeof(sInfo[]), GetAdministratorStatus(sInfo[0]) ? "在线" : "离线");
		ImplodeStrings(sInfo, 4, "|", sMerge, sizeof(sMerge));//打包字符串.
		menu.AddItem(sMerge, sName);
	}
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientAuthId(i, AuthId_Steam2, SteamId, sizeof(SteamId)))
		{
			char sInfo[4][128];
			ExplodeString(g_sAdminList[i], "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			if(GetAdminStatus(SteamId, iLists))
				continue;
			FormatEx(sName, sizeof(sName), "添加|%N", i);
			FormatEx(sData[0], sizeof(sData[]), SteamId);
			strcopy( sData[1], sizeof(sData[]), g_sAuthority);
			FormatEx(sData[2], sizeof(sData[]), "%N", i);
			strcopy( sData[3], sizeof(sData[]), "添加");
			ImplodeStrings(sData, 4, "|", sMerge, sizeof(sMerge));//打包字符串.
			menu.AddItem(sMerge, sName);
		}
	}
	
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int GetSteamIdLists()
{
	int array;
	char g_Filename[PLATFORM_MAX_PATH], line[256], sBlock[8][128], sInfo[128], sData[4][128], sMerge[2][128];
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), "configs/admins_simple.ini");
	
	File file = OpenFile(g_Filename, "rt");
	if (file)
	{
		while (!file.EndOfFile())
		{
			if (!file.ReadLine(line, sizeof(line)))
				break;

			if(strncmp(line, "\"", 1, false) != 0 || strncmp(line, "/", 1, false) == 0 || strncmp(line, "/", 2, false) == 0)
				continue;

			int g_iCount = ReplaceString(line, sizeof(line), "\"", "\"", false);
			ExplodeString(line, "\"", sBlock, g_iCount + 1, sizeof(sBlock[]));
			for (int i = 0; i <= g_iCount; i++)
				TrimString(sBlock[i]);
			
			ExplodeString(sBlock[4], "//", sMerge, sizeof(sMerge), sizeof(sMerge[]));//拆分字符串.
			strcopy(sData[0], sizeof(sData[]), sBlock[1]);
			strcopy(sData[1], sizeof(sData[]), sBlock[3]);
			strcopy(sData[2], sizeof(sData[]), sMerge[1]);
			strcopy(sData[3], sizeof(sData[]), "内容");
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			strcopy(g_sAdminList[array], sizeof(g_sAdminList[]), sInfo);
			array += 1;
		}
	}
	file.Close();
	return array;
}

int MenuHandler_ListRealSurvivor(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[128];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
				IsAddSteamIdAdmin(client, sItem, menu.Selection);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void IsAddSteamIdAdmin(int client, char[] sItem, int g_iSelection)
{
	char sInfo[4][128];
	ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
	char szFilePath[PLATFORM_MAX_PATH], szFileCopyPath[PLATFORM_MAX_PATH], szLine[256];
	BuildPath(Path_SM, szFilePath, sizeof(szFilePath), "configs/admins_simple.ini");
	
	if(strcmp(sInfo[3], "添加", false) == 0)
	{
		//用户可能会把文件最后一行的空行删除,所以写入管理员之前重新写一遍该文件.
		FormatEx(szFileCopyPath, sizeof(szFileCopyPath), "%s.copy", szFilePath);
		File fFile 		= OpenFile(szFilePath, "rt");
		File fTempFile	= OpenFile(szFileCopyPath, "wt");
		
		while(!fFile.EndOfFile())
		{
			if(!fFile.ReadLine(szLine, sizeof(szLine)))
				continue;

			TrimString(szLine);//整理字符串前后的空格.

			if(szLine[0] == '\0')//如果当前行是空行.
				continue;//如果是空行则不写入.
				
			fTempFile.WriteLine(szLine);
		}
		delete fFile;
		delete fTempFile;
		DeleteFile(szFilePath);//删除指定的文件
		RenameFile(szFilePath, szFileCopyPath);//重新命名文件
		//这里使用下一帧写入管理员.
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(g_iSelection);
		hPack.WriteString(sInfo[0]);
		hPack.WriteString(sInfo[1]);
		hPack.WriteString(sInfo[2]);
		RequestFrame(IsWriteLine, hPack);
	}
	else
	{
		FormatEx(szFileCopyPath, sizeof(szFileCopyPath), "%s.copy", szFilePath);
		File fFile 		= OpenFile(szFilePath, "rt");
		File fTempFile	= OpenFile(szFileCopyPath, "wt");
		int target = GetPlayersClient(sInfo[0]);

		while(!fFile.EndOfFile())
		{
			if(!fFile.ReadLine(szLine, sizeof(szLine)))
				continue;

			TrimString(szLine);

			if(StrContains(szLine, sInfo[0]) == -1)//对比字符串.
			{
				fTempFile.WriteLine(szLine);
				if(IsValidClient(target) && client != target)
					PrintHintText(target, "删除了你的管理员.");
			}
		}
		delete fFile;
		delete fTempFile;
		DeleteFile(szFilePath);//删除指定的文件
		RenameFile(szFilePath, szFileCopyPath);//重新命名文件
		IsListRealSurvivor(client, g_iSelection);
	}
}

void IsWriteLine(DataPack hPack)
{
	char sInfo[3][128];
	hPack.Reset();
	int  client = hPack.ReadCell();
	int  g_iSelection = hPack.ReadCell();
	hPack.ReadString(sInfo[0], sizeof(sInfo[]));
	hPack.ReadString(sInfo[1], sizeof(sInfo[]));
	hPack.ReadString(sInfo[2], sizeof(sInfo[]));
	char szFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFilePath, sizeof(szFilePath), "configs/admins_simple.ini");
	File fFile = OpenFile(szFilePath, "at");
	fFile.WriteLine("\"%s\"	\"%s\"	//%s", sInfo[0], sInfo[1], sInfo[2]);
	int target = GetPlayersClient(sInfo[0]);
	if(IsValidClient(target) && client != target)
		PrintHintText(target, "添加你为管理员[%s].", sInfo[1]);
	delete fFile;
	delete hPack;
	IsListRealSurvivor(client, g_iSelection);
}

bool AcquirePlayerRights(char[] SteamId)
{
	for (int i = 0; i <= g_iBlockCmdsCount; i++)
		if (StrEqual(g_sBlockCmds[i], SteamId, false))
			return true;
	return false;
}

bool GetAdministratorStatus(char[] sSteamId)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if(strcmp(sSteamId, GetPlayersSteamId(i), false) == 0)
				return true;
	
	return false;
}

char[] GetPlayersName(char[] sSteamId)
{
	char sName[32];
	FormatEx(sName, sizeof(sName), "%N", GetPlayersClient(sSteamId));
	return sName;
}

int GetPlayersClient(char[] sSteamId)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if(strcmp(sSteamId, GetPlayersSteamId(i), false) == 0)
				return i;
			
	return 0;
}

bool GetAdminStatus(char[] sSteamId, int Lists)
{
	char sInfo[4][128];
	for (int i = 0; i < Lists; i++)
	{
		ExplodeString(g_sAdminList[i], "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
		if(strcmp(sSteamId, sInfo[0], false) == 0)
			return true;
	}
	return false;
}

char[] GetPlayersSteamId(int client)
{
	char SteamId[32];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	return SteamId;
}

//判断玩家有效.
bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}