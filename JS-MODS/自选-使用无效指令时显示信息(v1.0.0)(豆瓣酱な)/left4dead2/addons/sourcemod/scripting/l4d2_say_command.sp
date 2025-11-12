/*
 *
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 */
#pragma semicolon 1				//添加结束符.
#pragma newdecls required		//强制新语法.
#include <sourcemod>			//加载函数库.
#define MAX_LENGTH		32		//字符串大小.
#define PLUGIN_VERSION	"1.0.0"	//插件的版本.
//插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_say_command",
	author 			= "豆瓣酱な",
	description 	= "获取玩家输入的指令是否有效.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
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

		if(!IsCommandExist(sData[0][1]))//获取指令有效性.
			if(!IsCommandExist(StringReplace(sData[0][1])))//获取指令有效性.
				PrintToChat(client, "\x04[提示]\x05你输入的指令无效.");
	}
}
//获取指令有效性.
stock bool IsCommandExist(char[] sData)
{
	bool doSearch;
	char name[128], desc[128];
	CommandIterator cmdIter = new CommandIterator();

	while (cmdIter.Next())
	{
		cmdIter.GetName(name, sizeof(name));//命令名称.
		cmdIter.GetDescription(desc, sizeof(desc));//命令描述.
		
		if (strcmp(name, sData, false) == 0)
		{
			doSearch = true;
			break;
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
	FormatEx(sInfo, sizeof(sInfo),"%s%s", "sm_", sData);
	return sInfo;
}