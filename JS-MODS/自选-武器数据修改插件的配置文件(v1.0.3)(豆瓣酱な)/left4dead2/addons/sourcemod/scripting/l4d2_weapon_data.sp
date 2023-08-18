#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION	"1.0.3"

char sKvPath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name        = "l4d2_weapon_data",
	author      = "豆瓣酱な",
	description = "设置武器伤害插件的配置文件.",
	version     = "PLUGIN_VERSION",
	url         = "N/A"
};

char g_sRegCmd[] = "sm_weapon";

//枪械类.
char g_sAttrShortName[][][] = 
{
	{"damage", "设置伤害"},
	{"clipsize", "弹夹数量"}
};

//枪械类.
char g_sWeaponFirearms[][][] = 
{
	{"小手枪", "pistol", "36", "15"},
	{"马格南", "pistol_magnum", "80", "8"},
	{"UZI微冲", "smg", "20", "50"},
	{"MP5微冲", "smg_mp5", "26", "50"},
	{"MAC微冲", "smg_silenced", "25", "50"},
	{"M16步枪", "rifle", "33", "50"},
	{"三连发步枪", "rifle_desert", "44", "60"},
	{"AK47步枪", "rifle_ak47", "58", "40"},
	{"SG552步枪", "rifle_sg552", "33", "50"},
	{"连发木狙", "hunting_rifle", "90", "15"},
	{"军用狙击枪", "sniper_military", "90", "30"},
	{"单发鸟狙", "sniper_scout", "375", "15"},
	{"AWP大狙", "sniper_awp", "425", "20"},
	{"M60机关枪", "rifle_m60", "50", "150"},
	{"榴弹发射器", "grenade_launcher", "33", "3"},
	{"单发木喷", "pumpshotgun", "25", "8"},
	{"单发铁喷", "shotgun_chrome", "31", "8"},
	{"一代连喷", "autoshotgun", "23", "10"},
	{"二代连喷", "shotgun_spas", "28", "10"}
};

public void OnPluginStart()
{
	BuildPath(Path_SM, sKvPath, sizeof(sKvPath), "configs/l4d2_weapon_data.cfg");
	IsReadFileValues();
	RegConsoleCmd("sm_load", Command_Loadweapondata, "加载武器配置.");
}

public Action Command_Loadweapondata(int client, int args) 
{
	IsReadFileValues();
	return Plugin_Handled;
}

//加载地图时调用.
public void OnMapStart()
{
	IsReadFileValues();
}

void IsReadFileValues()
{
	KeyValues kv = new KeyValues("WeaponData");
	if (!FileExists(sKvPath))
	{
		File file = OpenFile(sKvPath, "w");
		if (!file)
		{
			LogError("无法读取文件: \"%s\"", sKvPath);
			return;
		}
		for (int i = 0; i < sizeof(g_sWeaponFirearms); i++)
		{
			// 写入内容.
			if (kv.JumpToKey(g_sWeaponFirearms[i][1], true))
				for (int x = 0; x < sizeof(g_sAttrShortName); x++)
					kv.SetString(g_sAttrShortName[x][0], g_sWeaponFirearms[i][x + 2]);
			// 返回上一页.
			kv.Rewind();
			// 把内容写入文件.
			kv.ExportToFile(sKvPath);
		}
		delete file;
		RequestFrame(IsFrameReadFile);//创建文件后下一帧执行读取.
		
	}
	// 文件存在则加载原有文件
	else if(kv.ImportFromFile(sKvPath))
	{
		ServerCommand("sm_weapon_attributes_reset");//重置所有武器属性.
		for (int i = 0; i < sizeof(g_sWeaponFirearms); i++)
		{
			if (kv.JumpToKey(g_sWeaponFirearms[i][1], true))
			{
				char sData[128], sInfo[4][128];
				for (int x = 0; x < sizeof(g_sAttrShortName); x++)
				{
					strcopy(sInfo[0], sizeof(sInfo[]), g_sRegCmd);
					strcopy(sInfo[1], sizeof(sInfo[]), g_sWeaponFirearms[i][1]);
					strcopy(sInfo[2], sizeof(sInfo[]), g_sAttrShortName[x][0]);
					kv.GetString(g_sAttrShortName[x][0], sInfo[3], sizeof(sInfo[]), g_sWeaponFirearms[i][x + 2]);
					ImplodeStrings(sInfo, sizeof(sInfo), " ", sData, sizeof(sData));//打包字符串.
					ServerCommand(sData);
					//PrintToChatAll("\x04[提示]\x05当前值为:%s.", sData);
				}
			}
			kv.Rewind();
		}
	}
	delete kv;
}
//下一帧读取武器配置.
void IsFrameReadFile()
{
	IsReadFileValues();
}