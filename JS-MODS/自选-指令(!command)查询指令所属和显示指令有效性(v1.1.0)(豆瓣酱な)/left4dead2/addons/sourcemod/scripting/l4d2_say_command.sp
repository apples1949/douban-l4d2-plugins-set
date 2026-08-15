/*
 *	已知问题:如果多个插件注册同一个指令只能获取到第一个注册的.
 * 
 *	v1.0.0
 *
 *	1:初始版本发布.
 * 
 *	v1.1.0
 *
 *	1:增加一个指令查询指令所属的插件名称.
 *
 */
#pragma semicolon 1				//添加结束符.
#pragma newdecls required		//强制新语法.
#include <sourcemod>			//加载函数库.
#define MAX_LENGTH		32		//字符串大小.
#define PLUGIN_VERSION	"1.1.0"	//插件的版本.
//插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_say_command",
	author 			= "豆瓣酱な",
	description 	= "获取玩家输入的指令是否有效.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始.
public void OnPluginStart()
{
	RegConsoleCmd("sm_command", QueryCommand, "查询指令所属的插件文件名称.");
}
//指令回调.
public Action QueryCommand(int client, int args)
{
	if(IsCheckClientAccess(client))
	{
		switch (args)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05指令用法:sm_command空格+需要查询的指令.");
				PrintToChat(client, "\x04[提示]\x05同样的指令多个插件注册时只能获取到先注册的.");
			}
			case 1:
			{
				char arg[128];
				GetCmdArgString(arg, sizeof(arg));
				
				if(arg[0] == '!' || arg[0] == '/')
				{
					int iCount = GetReplaceCount(ConstString(arg));//通过计算分隔符获取内容数量.
					char[][] sData = new char[iCount][MAX_LENGTH];
					ExplodeString(arg, " ", sData, iCount, MAX_LENGTH);//拆分字符串.
					
					if(!IsCommandExists(client, StringReplace(sData[0][1]), true))//获取指令有效性.
						PrintToChat(client, "\x04[提示]\x05未找到注册了该指令的插件.");
				}
				else
					PrintToChat(client, "\x04[提示]\x05请确保指令以!或/开头.");
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
//监听玩家聊天窗输入的内容.
public void OnClientSayCommand_Post(int client, const char[] commnad, const char[] args)
{
	if(strlen(args) <= 1 || strncmp(commnad, "say", 3, false) != 0)
		return;

	if(args[0] == '!' || args[0] == '/')
	{
		int iCount = GetReplaceCount(ConstString(args));//通过计算分隔符获取内容数量.
		char[][] sData = new char[iCount][MAX_LENGTH];
		ExplodeString(args, " ", sData, iCount, MAX_LENGTH);//拆分字符串.

		if(!IsCommandExists(client, StringReplace(sData[0][1])))//获取指令有效性.
			PrintToChat(client, "\x04[提示]\x05你输入的指令无效.");
	}
}
/* 函数 CommandExists 可以获取命令有效性.*/
//获取指令有效性.
stock bool IsCommandExists(int client, char[] sData, bool display = false)
{
	bool doSearch;
	
	CommandIterator cmdIter = new CommandIterator();

	while (cmdIter.Next())
	{
		char name[128], desc[128], iter[128];
		cmdIter.GetName(name, sizeof(name));//命令名称.
		cmdIter.GetDescription(desc, sizeof(desc));//命令描述.
		GetPluginFilename(cmdIter.Plugin, iter, sizeof(iter));//插件名称.
		
		if (strcmp(name, sData, false) == 0)
		{
			doSearch = true;

			if(display == true)
				PrintToChat(client, "\x04[提示]\x05指令(%s),名称(%s).", name, iter);
		}
	}
	delete cmdIter;
	return doSearch;
}
//获取字符串替换次数.
stock int GetReplaceCount(char[] sData)
{
	return ReplaceString(sData, strlen(sData)+1, " ", " ", false) + 1;//通过计算分隔符获取内容数量.;
}
//格式化字符串.
stock char[] ConstString(const char[] sData)
{
	char sInfo[MAX_LENGTH];
	strcopy(sInfo, sizeof(sInfo), sData);
	return sInfo;
}
//在字符串前面添加指定的字符.
stock char[] StringReplace(char[] sData)
{
	char sInfo[MAX_LENGTH];
	if(strncmp(sData, "sm_", 3, false) != 0)
		FormatEx(sInfo, sizeof(sInfo),"%s%s", "sm_", sData);
	return sInfo;
}
//判断玩家权限.
stock bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}