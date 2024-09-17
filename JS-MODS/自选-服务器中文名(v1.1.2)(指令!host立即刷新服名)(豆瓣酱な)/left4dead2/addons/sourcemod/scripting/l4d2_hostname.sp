#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION	"1.1.2"

char g_sPath[PLATFORM_MAX_PATH], g_sFileLine[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name 			= "l4d2_hostname",
	author 			= "豆瓣酱な",
	description 	= "管理员!host重载服名或设置新服名",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	IsGetSetHostName();//获取文件里的内容.
}

//玩家连接成功.
public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		CreateTimer(1.0, IsDelayOpeningMenu, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
	}
}
//计时器回调.
public Action IsDelayOpeningMenu(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && IsValidClient(client))
	{
		IsDisplayContent(client, "{green}[提示]{blue}欢迎加入此服务器.");
	}
	return Plugin_Stop;
}
stock void IsDisplayContent(int client, const char[] format, any ...)
{
	char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 3);
	C_PrintToChat(client, "%s", buffer);
}
public void OnConfigsExecuted()
{
	IsGetSetHostName();//获取文件里的内容.
}
//获取文件里的服名.
void IsGetSetHostName()
{
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/l4d2_hostname.txt");
	if(FileExists(g_sPath))//判断文件是否存在.
		IsSetSetHostName();//文件已存在,获取文件里的内容.
	else
		IsWriteServerName("{green}[提示]{blue}欢迎加入此服务器.");//文件不存在,创建文件并写入默认内容.
}

//获取文件里的内容.
void IsSetSetHostName()
{
	File file = OpenFile(g_sPath, "rb");

	if(file)
	{
		while(!file.EndOfFile())
			file.ReadLine(g_sFileLine, sizeof(g_sFileLine));
		TrimString(g_sFileLine);//整理获取到的字符串.
	}
	delete file;
	g_hHostName.SetString(g_sFileLine);//重新设置服名.
}

//写入内容到文件里.
void IsWriteServerName(char[] sName)
{
	File file = OpenFile(g_sPath, "w");
	strcopy(g_sFileLine, sizeof(g_sFileLine), sName);
	TrimString(g_sFileLine);//写入内容前整理字符串.

	if(file)
	{
		WriteFileString(file, g_sFileLine, false);//这个方法写入内容不会自动添加换行符.
		g_hHostName.SetString(g_sFileLine);//设置新服名.
	}
	delete file;
}

bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}