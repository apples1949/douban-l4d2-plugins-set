#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
//定义插件版本.
#define PLUGIN_VERSION	"1.1.2"	
//定义全局变量.
ConVar g_hHostName;
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
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_hostname.txt");
	RegConsoleCmd("sm_host", Command_UpdateHostName, "重载服名或设置新服名");
	g_hHostName = FindConVar("hostname");
	GetFileExists();//获取文件里的内容.
}
//地图加载后调用.
public void OnConfigsExecuted()
{
	GetFileExists();//新建或读取文件内容.
}
//指令回调.
Action Command_UpdateHostName(int client, int args)
{
	if(IsCheckClientAccess(client))
	{
		if(args == 0)
		{
			GetFileExists();//获取文件里的内容.
			PrintToChat(client, "\x04[提示]\x05已重新加载配置文件(使用指令!host空格+内容设置新服名).");
		}
		else
		{
			char arg[64];
			GetCmdArgString(arg, sizeof(arg));
			SetServerHostName(arg);//写入内容到文件里.
			PrintToChat(client, "\x04[提示]\x05已设置新服名为\x04:\x05(\x03%s\x05)\x04.", arg);
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05只限管理员使用该指令.");
	return Plugin_Handled;
}
//获取文件里的服名.
void GetFileExists()
{
	if(FileExists(g_sKvPath))//判断文件是否存在.
		GetServerHostName();//文件已存在,获取文件里的内容.
	else
		SetServerHostName("猜猜这个是谁的萌新服?");//文件不存在,创建文件并写入默认内容.
}
//获取文件里的内容.
void GetServerHostName()
{
	char sName[128];
	File file = OpenFile(g_sKvPath, "rb");

	if (!file)
		LogError("无法读取文件: \"%s\"", g_sKvPath);

	while(!file.EndOfFile())//测试是否已到达文件末尾.
		file.ReadLine(sName, sizeof(sName));//读取一行的内容.
	
	TrimString(sName);//整理获取到的字符串.
	g_hHostName.SetString(sName);//重新设置服名.
	delete file;
}
//写入内容到文件里.
void SetServerHostName(char[] sName)
{
	File file = OpenFile(g_sKvPath, "w");

	if (!file)
		LogError("无法读取文件: \"%s\"", g_sKvPath);

	TrimString(sName);//写入内容前整理字符串.
	file.WriteString(sName, false);//这个方法写入内容不会自动添加换行符.
	g_hHostName.SetString(sName);//设置新服名.
	delete file;
}
//判断管理员权限.
bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}