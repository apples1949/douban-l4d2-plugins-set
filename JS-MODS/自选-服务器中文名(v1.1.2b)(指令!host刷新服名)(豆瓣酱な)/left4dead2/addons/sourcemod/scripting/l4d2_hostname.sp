/*
 *	v1.0.0
 *
 *	1:初始版本发布.
 *
 *	v1.1.2a
 *
 *	1:增加根据端口设置服务器名称.
 *
 *	v1.1.2b
 *
 *	1:更改指令设置人数的写入方式.
 *
 */
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
//定义插件版本.
#define PLUGIN_VERSION	"1.1.2b"	
#define MAX_SIZEOF		128	//定义字符串大小.
#define DEFAULT_NAME 	"猜猜这个是谁的萌新服?" //定义写入文件的默认服名.
//定义全局变量.
ConVar g_hHostName, g_hHostPort;
char g_sKvPath[PLATFORM_MAX_PATH];
//定义插件信息.
public Plugin myinfo = 
{
	name 			= "l4d2_hostname",
	author 			= "豆瓣酱な",
	description 	= "管理员!host重载服名或设置新服名",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
//插件开始.
public void OnPluginStart()
{
	g_hHostName = FindConVar("hostname");
	g_hHostPort = FindConVar("hostport");

	RegConsoleCmd("sm_host", Command_UpdateHostName, "重载服名或设置新服名");
	
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_hostname.txt");

	ReadFileContent(DEFAULT_NAME, GetHostPort());//读取文件内容.
}
//配置文件(server.cfg)加载完调用.
public void OnConfigsExecuted()
{
	ReadFileContent(DEFAULT_NAME, GetHostPort());//读取文件内容.
}
//指令回调.
Action Command_UpdateHostName(int client, int args)
{
	if(IsCheckClientAccess(client))
	{
		switch(args)
		{
			case 0:
			{
				ReadFileContent(DEFAULT_NAME, GetHostPort());//读取文件内容.
				PrintToChat(client, "\x04[提示]\x05已刷新当前服务器的名称.");
			}
			default:
			{
				char buffer[128];
				GetCmdArgString(buffer, sizeof(buffer));
				WriteFileContent(buffer, GetHostPort());//文件不存在则创建文件并写入指定内容.
				PrintToChat(client, "\x04[提示]\x05已设置新服名为\x04:\x05(\x03%s\x05)\x04.", buffer);
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05只限管理员使用该指令.");
	return Plugin_Handled;
}
//读取文件内容.
void ReadFileContent(char[] sHostName, char[] sHostPort)
{
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		KeyValues kv = new KeyValues("hostport");

		if (kv.JumpToKey("default", true))
		{
			//写入默认内容.
			kv.SetString("ServerName", sHostName);
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sKvPath);//把数据写入到文件.
			g_hHostName.SetString(sHostName);//设置服务器名称.
		}
		
		delete kv;
	}
	else
	{
		KeyValues kv = new KeyValues("hostport");
		
		if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
		{
			if (kv.JumpToKey(sHostPort, false))
			{
				char sData[128];
				kv.GetString("ServerName", sData, sizeof(sData), sHostName);
				kv.Rewind();//返回上一层.
				g_hHostName.SetString(sData);//设置服务器名称.
			}
			else if (kv.JumpToKey("default", false))
			{
				char sData[128];
				kv.GetString("ServerName", sData, sizeof(sData), sHostName);
				kv.Rewind();//返回上一层.
				g_hHostName.SetString(sData);//设置服务器名称.
			}
			else if (kv.JumpToKey("default", true))
			{
				//写入默认内容.
				kv.SetString("ServerName", sHostName);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
				g_hHostName.SetString(sHostName);//设置服务器名称.
			}
		}
		else//文件读取失败.
		{
			g_hHostName.SetString(sHostName);//设置服务器名称.
		}

		delete kv;
	}
}
//写入内容到文件里.
void WriteFileContent(char[] sHostName, char[] sHostPort)
{
	if (!FileExists(g_sKvPath))//没有配置文件.
	{
		KeyValues kv = new KeyValues("hostport");

		if (kv.JumpToKey("default", true))
		{
			//写入默认内容.
			kv.SetString("ServerName", sHostName);
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sKvPath);//把数据写入到文件.
			g_hHostName.SetString(sHostName);//设置服务器名称.
		}
		delete kv;
	}
	else
	{
		KeyValues kv = new KeyValues("hostport");
		
		if (kv.ImportFromFile(g_sKvPath))//文件读取成功.
		{
			if (kv.JumpToKey(sHostPort, false))
			{
				kv.SetString("ServerName", sHostName);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
				g_hHostName.SetString(sHostName);//设置服务器名称.
			}
			else if (kv.JumpToKey("default", false))
			{
				kv.SetString("ServerName", sHostName);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
				g_hHostName.SetString(sHostName);//设置服务器名称.
			}
			else if (kv.JumpToKey("default", true))
			{
				kv.SetString("ServerName", sHostName);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sKvPath);//把数据写入到文件.
				g_hHostName.SetString(sHostName);//设置服务器名称.
			}
		}
		else//文件读取失败.
		{
			g_hHostName.SetString(sHostName);//设置服务器名称.
		}

		delete kv;
	}
}
//判断管理员权限.
stock bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}
//获取端口名称.
stock char[] GetHostPort()
{
	char sPort[32];
	g_hHostPort.GetString(sPort, sizeof(sPort));
	return sPort;
}
//判断字符串是纯数字.
stock bool IsNumericChar(char[] chr)
{
	for (int i = 0; i < strlen(chr); i++)//创建循环.
		if(!IsCharNumeric(chr[i]))
			return false;
	return true;
}