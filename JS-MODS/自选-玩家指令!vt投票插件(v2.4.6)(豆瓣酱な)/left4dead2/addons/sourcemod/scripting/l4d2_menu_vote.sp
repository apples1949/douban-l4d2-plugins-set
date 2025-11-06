/*
 *	
 *
 *	v1.2.5
 *
 *	1:修复踢出玩家前玩家离开游戏导致随机踢出一个倒霉蛋的问题.
 *
 *	v1.3.5
 *
 *	1:更改设置投票同意和反对为官方方法.
 *
 *	v1.4.5
 *
 *	1:更改设置投票同意和反对为官方方法.
 *
 *	v2.4.5
 *
 *	1:新增投票更改难度只更改发起者的难度(需要l4d2_simulation.smx插件支持).
 *
 *	v2.4.6
 *
 *	1:修复BanIdentity()函数里的flags类型填错导致的函数报错.
 
 *
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#undef REQUIRE_PLUGIN		//标记为可选开始.
#include <l4d2_banned>		//数据库封禁玩家.
#include <l4d2_simulation>	//自定义玩家难度.
#define REQUIRE_PLUGIN		//标记为可选结束.
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote

#define PLUGIN_VERSION "2.4.6"

bool g_bLibraries[2];
Handle g_hChangelevel;

char g_sGameDifficulty[][][] = 
{
	{"简单", "Easy"}, 
	{"普通", "Normal"}, 
	{"高级", "Hard"}, 
	{"专家", "Impossible"}
};

int    g_iBanTime, g_iPercent, g_iMenuTime, g_iDifficulty, g_iTargetPlayer;
ConVar g_hBanTime, g_hPercent, g_hMenuTime, g_hDifficulty, g_hTargetPlayer;

public Plugin myinfo =  
{
	name = "l4d2_menu_vote", 
	author = "豆瓣酱な", 
	description = "投票更改难度,踢出玩家,重启当前章节.", 
	version = PLUGIN_VERSION,
	url = "N/A"
};

//所有插件加载完成后执行一次(延迟加载插件也会执行一次).
public void OnAllPluginsLoaded()   
{
	g_bLibraries[0] = LibraryExists("l4d2_banned");
	g_bLibraries[1] = LibraryExists("l4d2_simulation");
}
//库被加载时.
public void OnLibraryAdded(const char[] name) 
{
	if (strcmp(name, "l4d2_banned") == 0)
		g_bLibraries[0] = true;
	if (strcmp(name, "l4d2_simulation") == 0)
		g_bLibraries[1] = true;
}
//库被卸载时.
public void OnLibraryRemoved(const char[] name) 
{
	if (strcmp(name, "l4d2_banned") == 0)
		g_bLibraries[0] = false;
	if (strcmp(name, "l4d2_simulation") == 0)
		g_bLibraries[1] = false;
}

public void OnPluginStart()   
{
	RegConsoleCmd("sm_vt", Command_VoteMenu);

	g_hBanTime = CreateConVar("l4d2_vote_BanTime", "10080", "设置被投票踢出玩家的封禁时间/分钟. -1=仅踢出, 0=永久封禁.", FCVAR_NOTIFY);
	g_hPercent = CreateConVar("l4d2_vote_Percent", "60", "设置通过投票所需的百分比(1/100).", FCVAR_NOTIFY);
	g_hMenuTime = CreateConVar("l4d2_vote_menuTime", "25", "设置同意或反对菜单的显示时间/秒.", FCVAR_NOTIFY);
	g_hDifficulty = CreateConVar("l4d2_vote_difficulty", "15", "启用投票更改难度(把需要启用的数字加起来). 0=禁用, 1=简单, 2=普通, 4=高级, 8=专家, 15=全部.", FCVAR_NOTIFY);
	g_hTargetPlayer = CreateConVar("l4d2_vote_target_player", "0", "投票更改什么难度时只更改投票发起者的(需要l4d2_simulation.smx插件支持). 0=禁用, 1=简单, 2=普通, 4=高级, 8=专家, 15=全部.", FCVAR_NOTIFY);
	g_hBanTime.AddChangeHook(CvarChanged);
	g_hPercent.AddChangeHook(CvarChanged);
	g_hMenuTime.AddChangeHook(CvarChanged);
	g_hDifficulty.AddChangeHook(CvarChanged);
	g_hTargetPlayer.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "l4d2_menu_vote");
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iBanTime = g_hBanTime.IntValue;
	g_iPercent = g_hPercent.IntValue;
	g_iMenuTime = g_hMenuTime.IntValue;
	g_iDifficulty = g_hDifficulty.IntValue;
	g_iTargetPlayer = g_hTargetPlayer.IntValue;

	if (g_iPercent < 1)
		g_iPercent = 1;
	if (g_iPercent > 100)
		g_iPercent = 100;
	if (g_iMenuTime < 1)
		g_iMenuTime = 1;
}

//开局提示.
public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
		CreateTimer(7.5, g_hTimerAnnounce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action g_hTimerAnnounce(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client))
		PrintToChat(client, "\x04[提示]\x05聊天窗输入指令\x03!vt\x05打开投票菜单.");//聊天窗提示.
	return Plugin_Continue;
}
//地图开始.
public void OnMapStart()
{
	GetCvars();
	delete g_hChangelevel;
}
//地图结束.
public void OnMapEnd()
{
	delete g_hChangelevel;
}

public Action Command_VoteMenu(int client, int args)
{
	IsChooseFunction(client);
	return Plugin_Handled;
}

void IsChooseFunction(int client)
{
	char line[32];
	Menu menu = new Menu(Menu_HandlerFunction);
	FormatEx(line, sizeof(line), "投票菜单:");
	SetMenuTitle(menu, "%s", line);
	if (g_iDifficulty > 0)
		menu.AddItem("0", "更改难度");
	menu.AddItem("1", "重启章节");
	menu.AddItem("2", "踢出玩家");
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	//menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerFunction(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32];
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				switch(StringToInt(sItem))
				{
					case 0:
						MenuVoteChangeDifficulty(client, sItem);
					case 1:
						MenuVoteReopenTheChapter(client, sItem);
					case 2:
						MenuVoteKickThePlayer(client, sItem);
				}
			}
		}
	}
	return 0;
}

void MenuVoteChangeDifficulty(int client, char[] g_sItem)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (g_iDifficulty <= 0)
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05难度投票功能未开启.");
		return;
	}
	char line[32], sInfo[128], sData[6][32];
	Menu menu = new Menu(Menu_HandlerDifficulty);
	FormatEx(line, sizeof(line), "选择难度:");
	SetMenuTitle(menu, "%s", line);
	for (int i = 0; i < sizeof(g_sGameDifficulty); i++)
	{
		if (strcmp(GetDifficulty(), g_sGameDifficulty[i][1]) == 0)//不显示当前难度.
			continue;
		
		if(g_iDifficulty & (1 << i))
		{
			strcopy(sData[0], sizeof(sData[]), g_sItem);
			strcopy(sData[1], sizeof(sData[]), g_sGameDifficulty[i][1]);
			strcopy(sData[2], sizeof(sData[]), g_sGameDifficulty[i][0]);
			IntToString(i, sData[3], sizeof(sData[]));
			IntToString(g_iTargetPlayer > 0 ? ((g_iTargetPlayer & (1 << i)) ? 1 : 0) : 0, sData[5], sizeof(sData[]));
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, g_sGameDifficulty[i][0]);
		}
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
int Menu_HandlerDifficulty(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[128], auth[32], sName[32], sInfo[6][32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			
			if (strcmp(GetDifficulty(), sInfo[2]) == 0)
				PrintToChat(client, "\x04[提示]\x05选择的难度与当前难度相同.");
			else
			{
				if(GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
				{
					strcopy(sInfo[4], sizeof(sInfo[]), auth);
					ImplodeStrings(sInfo, sizeof(sInfo), "|", sItem, sizeof(sItem));//打包字符串.
					vVoteChangeDifficulty(client, sItem, sName);
					
					if(g_bLibraries[1] == false)
					{
						//PrintToChatAll("1 %N发起更改全部难度为:%s.", client, sName);
						PrintToChatAll("\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, sName);
					}
					else
					{
						if(g_iTargetPlayer > 0)
						{
							if(g_iTargetPlayer & (1 << StringToInt(sInfo[3])))
							{
								//PrintToChatAll("%N发起更改自己难度为:%s.", client, sName);
								PrintToChat(client, "\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, sName);

								for (int i = 1; i <= MaxClients; i++)
									if (IsClientInGame(i) && i != client)
										PrintToChat(i, "\x04[提示]\x03%N\x05发起投票更换自己难度为\x04:\x03%s", client, sName);
							}
							else
							{
								//PrintToChatAll("2 %N发起更改全部难度为:%s.", client, sName);
								PrintToChatAll("\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, sName);
							}
						}
						else
						{
							//PrintToChatAll("3 %N发起更改全部难度为:%s.", client, sName);
							PrintToChatAll("\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, sName);
						}
					}
				}
				else
				{
					PrintToChat(client, "\x04[提示]\x05你的steamId无效,发起投票失败.");
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				IsChooseFunction(client);
		}
	}
	return 0;
}
void vVoteChangeDifficulty(int client, char[] sItem, char[] sName)
{
	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sItem);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("更改难度为:%s?", sName);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void MenuVoteReopenTheChapter(int client, char[] sItem)
{
	if (g_hChangelevel != null)
	{
		ReplyToCommand(client, "\x04[提示]\x05当前也存在重启章节的计时器.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	char sInfo[128], sData[6][32];
	strcopy(sData[0], sizeof(sData[]), sItem);
	strcopy(sData[1], sizeof(sData[]), "内容");//这个里的内容用不着.
	strcopy(sData[2], sizeof(sData[]), "内容");//这个里的内容用不着.
	strcopy(sData[3], sizeof(sData[]), "内容");//这个里的内容用不着.
	strcopy(sData[4], sizeof(sData[]), "内容");//这个里的内容用不着.
	ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.

	PrintToChatAll("\x04[提示]\x03%N\x05发起投票重启当前章节.", client);

	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sInfo);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("重启当前章节?");

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void MenuVoteKickThePlayer(int client, char[] sItem)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		IsChooseFunction(client);
		ReplyToCommand(client, "\x04[提示]\x05当前正在进行投票.");
		return;
	}
	if (TestVoteDelay(client))
	{
		IsChooseFunction(client);
		return;
	}
	if (!GetplayerTarget(client))
	{
		IsChooseFunction(client);
		PrintToChat(client, "\x04[提示]\x05当前有效玩家不足.");
		return;
	}
	char line[32], sInfo[32], auth[32], sData[6][32];
	Menu menu = new Menu(Menu_HandlerKickPlayer);
	FormatEx(line, sizeof(line), "踢出玩家?");
	menu.SetTitle("%s", line);
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && client != i)
		{ 
			if (!CanUserTarget(client, i) && CanUserTarget(i, client))
				continue;

			if(!GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
				continue;

			strcopy (sData[0], sizeof(sData[]), sItem);
			FormatEx(sData[1], sizeof(sData[]), "%N", i);
			FormatEx(sData[2], sizeof(sData[]), "%s", auth);
			strcopy(sData[3], sizeof(sData[]), "内容");//这个里的内容用不着.
			strcopy(sData[4], sizeof(sData[]), "内容");//这个里的内容用不着.
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, sData[1]);
		}		
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_HandlerKickPlayer(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[128], sName[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			IsVoteKickThePlayer(client, sItem, sName);
			PrintToChatAll("\x04[提示]\x03%N\x05发起投票踢出玩家\x04:\x03%s", client, sName);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				IsChooseFunction(client);
		}
	}
	return 0;
}

void IsVoteKickThePlayer(int client, char[] sItem, char[] sName)
{
	L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerGetVotes);
	vote.Initiator = client;
	vote.SetInfo(sItem);

	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		vote.SetTitle("踢出玩家:%s?", sName);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, g_iMenuTime);
}

void Menu_HandlerGetVotes(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_PlayerVoted:
		{
			switch(param2)
			{
				case 1: 
					PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
				case 2: 
					PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
			}
		}
		case VoteAction_End:
		{
			char sItem[128], sInfo[6][32];
			vote.GetInfo(sItem, sizeof sItem);
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.

			switch(param1)
			{
				case VOTEEND_FULLVOTED: 
					PrintToChatAll("\x04[提示]\x05所有玩家已投票.");
				case VOTEEND_TIMEEND: 
					PrintToChatAll("\x04[提示]\x05本次投票结束.");
			}

			int iPercent = RoundToNearest(float(vote.YesCount) / float(vote.YesCount + vote.NoCount) * 100.0);
			if (FloatCompare(float(iPercent), float(g_iPercent)) < 0)
			{
				vote.SetFail();
				PrintToChatAll("\x04[提示]\x05投票失败\x04.\x05至少需要\x03%d%%\x05支持\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", g_iPercent, iPercent, vote.YesCount + vote.NoCount);
			}
			else
			{
				switch(StringToInt(sInfo[0]))
				{
					case 0:
					{
						if(g_bLibraries[1] == false)
						{
							vote.SetPass("投票通过...");
							//PrintToChatAll("1 更改全部玩家的难度成功.");
							ServerCommand("z_difficulty %s", sInfo[1]);
							PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[2], iPercent, vote.YesCount + vote.NoCount);
						}
						else
						{
							if(StringToInt(sInfo[5]) == 1)
							{
								int client = GetPlayerAuthIdIndex(sInfo[4]);
								if (client != -1)
								{
									vote.SetPass("投票通过...");
									//PrintToChatAll("2 更改%N的难度成功.", client);

									char sName[32];
									GetClientName(client, sName, sizeof(sName));
									ReplaceString(sName, sizeof(sName), "\n", "");//把换行符替换为空.
									ReplaceString(sName, sizeof(sName), "\r", "");//把换行符替换为空.
									GetDealName(sName, sizeof(sName));
									SetCustomizeDifficulty(client, StringToInt(sInfo[3]));
									PrintToChat(client, "\x04[提示]\x05投票通过\x04.\x05难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[2], iPercent, vote.YesCount + vote.NoCount);

									for (int i = 1; i <= MaxClients; i++)
										if (IsClientInGame(i) && i != client)
											PrintToChat(i, "\x04[提示]\x05投票通过\x04.\x05%s的难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sName, sInfo[2], iPercent, vote.YesCount + vote.NoCount);
								}
								else
								{
									vote.SetFail();
									//PrintToChatAll("3 更改%N的难度失败.", client);
									PrintToChatAll("\x04[提示]\x05投票失败\x04.\x05投票发起者SteamI的无效\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[2], iPercent, vote.YesCount + vote.NoCount);
								}
							}
							else
							{
								vote.SetPass("投票通过...");
								//PrintToChatAll("4 更改全部玩家的难度成功.");
								ServerCommand("z_difficulty %s", sInfo[1]);
								PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[2], iPercent, vote.YesCount + vote.NoCount);
							}
						}
					}
					case 1:
					{
						vote.SetPass("投票通过...");
						delete g_hChangelevel;
						g_hChangelevel = CreateTimer(8.0, ChangelevelMap);
						PrintHintTextToAll("[提示] 投票通过,将在 8秒 后重启当前章节.");
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x038\x05秒后重启当前章节\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", iPercent, vote.YesCount + vote.NoCount);
					}
					case 2:
					{
						vote.SetPass("投票通过...");
						char g_sBanTime[64];
						FormatEx(g_sBanTime, sizeof(g_sBanTime), "你被投票踢出,并被封禁%d分钟", g_iBanTime);

						int client = GetPlayerAuthIdIndex(sInfo[2]);
						if (client != -1)
						{
							if (g_iBanTime <= -1)
								KickClient(client, "你被投票踢出");
							else
							{
								if(g_bLibraries[0])
									BanPlayers(client, g_iBanTime, BANFLAG_AUTO, "被投票踢出", g_sBanTime, "sm_ban", client);
								else
									BanClient(client, g_iBanTime, BANFLAG_AUTO, "被投票踢出", g_sBanTime, "sm_ban", client);
							}
						}
						else
							if (g_iBanTime > -1)
								BanIdentity(sInfo[2], g_iBanTime, BANFLAG_AUTHID, g_sBanTime, "sm_ban", client);
						
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05玩家\x03%s\x05已被踢出.\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", sInfo[1], iPercent, vote.YesCount + vote.NoCount);
					}
				}
			}
		}
	}
}

int GetPlayerAuthIdIndex(char[] steamid)
{
	char auth[32];
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if(GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
				if(strcmp(auth, steamid) == 0)
					return i;
	return -1;
}

//返回处理的内容.
char[] GetDealName(char[] buffer, int minlength)
{
	char sName[64];//定义最大显示字符数量(不建议设置太大或太小,建议最小14最大32即可).
	Format(sName, sizeof(sName), "%s", IsSplitStrings(buffer, minlength));
	//PrintToChatAll("测试信息:当前字符数(%d)", minlength);
	return sName;//新增防止玩家名字被截断时出现乱码.
}
//防止玩家名字被截断时出现乱码(部分符号可能会有点小问题)(此代码嫖至QAQ大佬！！！！！)
char[] IsSplitStrings(char[] src, int maxsize)
{
	ArrayList hData = new ArrayList(ByteCountToCells(32));
	int lengthsize;
	char sInfo[32];

	for(int i=0;i<strlen(src);)
	{
		if(0x00<=src[i] && src[i]<=0x7f)
		{
			sInfo[0] = '\0';
			lengthsize += strcopy(sInfo, sizeof(sInfo), GetSplitString(src,i,1));
			if(lengthsize > maxsize)
				break;
			hData.PushString(sInfo);
			i+=1;
		}
		else if(0xC0<=src[i] && src[i]<=0xDf)
		{
			sInfo[0] = '\0';
			lengthsize += strcopy(sInfo, sizeof(sInfo), GetSplitString(src,i,2));
			if(lengthsize > maxsize)
				break;
			hData.PushString(sInfo);
			i+=2;
		}
		else if(0xE0<=src[i] && src[i]<=0xEf)
		{
			sInfo[0] = '\0';
			lengthsize += strcopy(sInfo, sizeof(sInfo), GetSplitString(src,i,3));
			if(lengthsize > maxsize)
				break;
			hData.PushString(sInfo);
			i+=3;
		}
		else if(0xF0<=src[i] && src[i]<=0xF7)
		{
			sInfo[0] = '\0';
			lengthsize += strcopy(sInfo, sizeof(sInfo), GetSplitString(src,i,4));
			if(lengthsize > maxsize)
				break;
			hData.PushString(sInfo);
			i+=4;
		}
	}
	
	char sString[256];

	if(hData.Length > 0)
	{
		char[][] sTemp = new char[hData.Length][32];
		for(int i = 0; i < hData.Length; i++)
			hData.GetString(i, sTemp[i], 32);

		ImplodeStrings(sTemp, hData.Length, "", sString, sizeof(sString));//打包字符串.
	}

	delete hData;
	return sString;
}

char[] GetSplitString(char[] src, int srcindex, int length)
{
	char temp[10];
	for(int i = 0; i < length; i++)
	{
		temp[i] = src[i + srcindex];
		if(i + srcindex >= strlen(src))
			break;
	}
	return temp;
	//PrintToChatAll("\x04[提示]\x05当前内容:(%s).", temp);
}

public Action ChangelevelMap(Handle Timer)
{
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	ServerCommand("changelevel %s", sMap);
	g_hChangelevel = null;
	return Plugin_Stop;
}

char[] GetDifficulty()
{
	char sDifficulty[16];
	GetConVarString(FindConVar("z_difficulty"), sDifficulty, sizeof(sDifficulty));
	return sDifficulty;
}

bool GetplayerTarget(int client)
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && client != i)
		{
			if (!CanUserTarget(client, i) && CanUserTarget(i, client))
				continue;
			return true;
		}
	}	
	return false;
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	
 	if (delay > 0)
	{
 		PrintToChat(client, "\x04[提示]\x05您必须再等待\x03%s\x05后才能发起新的投票.", StandardizeTime(delay));
 		return true;
 	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=288686
char[] StandardizeTime(int remainder)
{
	char str[32], sD[32], sH[32], sM[32], sS[32];

	int D = RoundToFloor(float(remainder) / 86400.0);
	remainder = remainder - (D * 86400);
	int H = RoundToFloor(float(remainder) / 3600.0);
	remainder = remainder - (H * 3600);
	int M = RoundToFloor(float(remainder) / 60.0);
	remainder = remainder - (M * 60);
	int S = RoundToFloor(float(remainder));

	FormatEx(sD, sizeof(sD), "%d天", D);
	FormatEx(sH, sizeof(sH), "%d%s", H, !D && !M && !S ? "小时" : "时");
	FormatEx(sM, sizeof(sM), "%d%s", M, !D && !H && !S ? "分钟" : "分");
	FormatEx(sS, sizeof(sS), "%d秒", S);
	FormatEx(str, sizeof(str), "%s%s%s%s", !D ? "" : sD, !H ? "" : sH, !M ? "" : sM, !S ? "" : sS);
	return str;
}