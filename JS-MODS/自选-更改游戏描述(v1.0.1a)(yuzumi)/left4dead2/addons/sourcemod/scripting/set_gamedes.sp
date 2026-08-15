#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define CVAR_FLAGS	FCVAR_NOTIFY
#define GAMEDATA	"set_gamedes"
#define DEFAULT_DESCRIPTION 	"Left 4 Dead 3" //定义写入文件的默认描述.

MemoryPatch g_mGameDesPatch;	//记录内存修补数据
bool g_bPatchEnable;			//记录内存补丁状态
int g_iOS;						//记录不同系统下的修改位置起始点
char g_cGameDes[128];			//最大128长度, 中文占3字节(UTF8), 全中文最多42(服务器文件函数里写死0x80(128)长度)
char g_sPath[PLATFORM_MAX_PATH];
ConVar g_hHostPort;

public Plugin myinfo =
{
	name = "Set Game Description",
	author = "yuzumi",
	version	= "1.0.1a",
	description	= "Change Description at any time!",
	url = "https://github.com/joyrhyme/L4D2-Plugins/tree/main/Set_GameDescription"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion != Engine_Left4Dead2 && !IsDedicatedServer())
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2 and Dedicated Server!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}
//插件开始.
public void OnPluginStart()
{
	InitGameData();//加载签名文件.
	g_hHostPort = FindConVar("hostport");
	RegConsoleCmd("sm_set", cmdSetGameDes, "更改游戏描述 - Change Game Description");
	RegAdminCmd("sm_setgamedes", cmdSetGameDes, ADMFLAG_ROOT, "更改游戏描述 - Change Game Description");

	ReadFileContent(DEFAULT_DESCRIPTION, GetHostPort());//新建或读取文件内容.
}
public void OnConfigsExecuted()
{
	ReadFileContent(DEFAULT_DESCRIPTION, GetHostPort());//新建或读取文件内容.
}
//读取文件内容.
void ReadFileContent(char[] sDescription, char[] sHostPort)
{
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/set_gamedes.txt");
	
	if (!FileExists(g_sPath))//没有配置文件.
	{
		KeyValues kv = new KeyValues("hostport");

		if (kv.JumpToKey("default", true))
		{
			//写入默认内容.
			kv.SetString("kDescription", sDescription);
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sPath);//把数据写入到文件.
			strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
		}
		
		delete kv;
	}
	else
	{
		KeyValues kv = new KeyValues("hostport");
		
		if (kv.ImportFromFile(g_sPath))//文件读取成功.
		{
			if (kv.JumpToKey(sHostPort, false))
			{
				kv.GetString("kDescription", g_cGameDes, sizeof(g_cGameDes), sDescription);
				kv.Rewind();//返回上一层.
			}
			else if (kv.JumpToKey("default", false))
			{
				kv.GetString("kDescription", g_cGameDes, sizeof(g_cGameDes), sDescription);
				kv.Rewind();//返回上一层.
			}
			else if (kv.JumpToKey("default", true))
			{
				//写入默认内容.
				kv.SetString("kDescription", sDescription);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sPath);//把数据写入到文件.
				strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
			}
		}
		else//文件读取失败.
		{
			strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
		}

		delete kv;
	}
}
//写入内容到文件里.
void WriteFileContent(char[] sDescription, char[] sHostPort)
{
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/set_gamedes.txt");
	
	if (!FileExists(g_sPath))//没有配置文件.
	{
		KeyValues kv = new KeyValues("hostport");

		if (kv.JumpToKey("default", true))
		{
			//写入默认内容.
			kv.SetString("kDescription", sDescription);
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_sPath);//把数据写入到文件.
			strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
		}
		delete kv;
	}
	else
	{
		KeyValues kv = new KeyValues("hostport");
		
		if (kv.ImportFromFile(g_sPath))//文件读取成功.
		{
			if (kv.JumpToKey(sHostPort, false))
			{
				kv.SetString("kDescription", sDescription);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sPath);//把数据写入到文件.
				strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
			}
			else if (kv.JumpToKey("default", false))
			{
				kv.SetString("kDescription", sDescription);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sPath);//把数据写入到文件.
				strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
			}
			else if (kv.JumpToKey("default", true))
			{
				kv.SetString("kDescription", sDescription);
				kv.Rewind();//返回上一层.
				kv.ExportToFile(g_sPath);//把数据写入到文件.
				strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
			}
		}
		else//文件读取失败.
		{
			strcopy(g_cGameDes, sizeof(g_cGameDes), sDescription);
		}

		delete kv;
	}
}
//加载签名文件.
void InitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_mGameDesPatch = MemoryPatch.CreateFromConf(hGameData, "GetGameDescription::GameDescription");
	if (!g_mGameDesPatch.Validate())
		SetFailState("Failed to verify patch: \"GetGameDescription::GameDescription\"");
	else if (g_mGameDesPatch.Enable()) {
		g_iOS = hGameData.GetOffset("OS") ? 4 : 1; //Linux从第5位开始,Win从第2位开始(从0开始算)
		StoreToAddress(g_mGameDesPatch.Address + view_as<Address>(g_iOS), view_as<int>(GetAddressOfString(g_cGameDes)), NumberType_Int32);
		PrintToServer("[%s] Enabled patch: \"GetGameDescription::GameDescription\"", GAMEDATA);
		g_bPatchEnable = true; //上面校验不通过的话应该不会Enable,所以记录这个就行?
	}

	delete hGameData;
}

Action cmdSetGameDes(int client, int args)
{
	if(IsCheckClientAccess(client))
	{
		switch(args)
		{
			case 0:
			{
				ReplyToCommand(client, "%s", "Usage: sm_setgamedes <DescriptionText>");
			}
			default:
			{
				if (g_bPatchEnable)
				{
					char buffer[128];
					GetCmdArgString(buffer, sizeof(buffer));
					WriteFileContent(buffer, GetHostPort());//文件不存在则创建文件并写入指定内容.
					PrintToChat(client, "\x04[提示]\x05已设置游戏描述设置为\x04:\x05(\x03%s\x05)\x04.", buffer);
				}
				else
					ReplyToCommand(client, "%s", "游戏补丁已禁用或无法验证!");
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05只限管理员使用该指令.");
	return Plugin_Handled;
}
//获取端口名称.
stock char[] GetHostPort()
{
	char sPort[32];
	g_hHostPort.GetString(sPort, sizeof(sPort));
	return sPort;
}
//判断管理员权限.
stock bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}