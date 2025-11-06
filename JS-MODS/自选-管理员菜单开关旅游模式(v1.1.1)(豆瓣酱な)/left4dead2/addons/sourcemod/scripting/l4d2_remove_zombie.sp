/*
 *
 *	v1.1.0
 *
 *	1:新增阻止特感出现.
 *	2:新增删除所有女巫.
 *	3:菜单名称更改为旅游模式.
 *
 *	v1.1.1
 *
 *	1:新增菜单选项1开关全部功能.
 *
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
//定义全局变量.
bool g_bAllSpawningSwitch, g_bSpawningSwitch[4];
//定义菜单变量.
TopMenu g_hTopMenu;
TopMenuObject hOtherFeatures = INVALID_TOPMENUOBJECT;
//定义插件版本.
#define PLUGIN_VERSION	"1.1.1"
//定义插件信息.
public Plugin myinfo =
{
	name = "l4d2_remove_zombie", 
	author = "豆瓣酱な", 
	description = "删除所有丧尸,阻止特感和女巫出现(插件创建的可能无法阻止).", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};
//插件开始时.
public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	RegConsoleCmd("sm_zombie", MenuRemoveZombie, "管理员打开旅游模式菜单.");
}
//指令回调.
public Action MenuRemoveZombie(int client, int args)
{
	if(bCheckClientAccess(client))//判断管理员权限.
		DisplayOtherFeaturesMenu(client);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
//卸载函数库时.
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu = null;
}
//添加管理员菜单时.
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;
	
	g_hTopMenu = topmenu;
	
	TopMenuObject hTopMenuObject = FindTopMenuCategory(g_hTopMenu, "OtherFeatures");
	if (hTopMenuObject == INVALID_TOPMENUOBJECT)
		hTopMenuObject = AddToTopMenu(g_hTopMenu, "OtherFeatures", TopMenuObject_Category, hMenuHandler, INVALID_TOPMENUOBJECT);
	
	hOtherFeatures = AddToTopMenu(g_hTopMenu,"sm_zombie",TopMenuObject_Item, hHandlerMenu, hTopMenuObject,"sm_zombie",ADMFLAG_ROOT);
}
//管理员菜单回调.
void hMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);//主菜单名称.
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);//二级菜单名称.
	}
}
//管理员菜单回调.
void hHandlerMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hOtherFeatures)
			Format(buffer, maxlength, "旅游模式", param);//二级菜单标题.
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hOtherFeatures)
		{
			DisplayOtherFeaturesMenu(param);
		}
	}
}
//功能开关菜单.
void DisplayOtherFeaturesMenu(int client)
{
	char line[32], item[32];
	Menu menu = new Menu(MenuOtherFeaturesHandler);
	Format(line, sizeof(line), "旅游模式:\n ");
	SetMenuTitle(menu, "%s", line);
	Format(item, sizeof(item), "[%s] 开关全部功能", IsAllWitchState() == false ? "○" : "●");
	menu.AddItem("0", item);
	Format(item, sizeof(item), "[%s] 阻止特感出现", g_bSpawningSwitch[0] == false ? "○" : "●");
	menu.AddItem("1", item);
	Format(item, sizeof(item), "[%s] 阻止坦克出现", g_bSpawningSwitch[1] == false ? "○" : "●");
	menu.AddItem("2", item);
	Format(item, sizeof(item), "[%s] 阻止女巫出现", g_bSpawningSwitch[2] == false ? "○" : "●");
	menu.AddItem("3", item);
	Format(item, sizeof(item), "[%s] 删除所有丧尸", g_bSpawningSwitch[3] == false ? "○" : "●");
	menu.AddItem("4", item);
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
//菜单回调.
int MenuOtherFeaturesHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem));

			switch(sItem[0])
			{
				case '0':
				{
					g_bAllSpawningSwitch = !g_bAllSpawningSwitch;
					for(int i = 0; i < sizeof(g_bSpawningSwitch); i++)
						g_bSpawningSwitch[i] = g_bAllSpawningSwitch;
				}
				case '1':
					g_bSpawningSwitch[0] = !g_bSpawningSwitch[0];
				case '2':
					g_bSpawningSwitch[1] = !g_bSpawningSwitch[1];
				case '3':
					g_bSpawningSwitch[2] = !g_bSpawningSwitch[2];
				case '4':
					g_bSpawningSwitch[3] = !g_bSpawningSwitch[3];
			}
			if(g_bSpawningSwitch[0] == true)
				IsForcePlayerSuicide(true);
			if(g_bSpawningSwitch[1] == true)
				IsForcePlayerSuicide(false);
			if(g_bSpawningSwitch[2] == true)
				IsRemoveAllZombie("witch");
			if(g_bSpawningSwitch[3] == true)
				IsRemoveAllZombie("infected");
			DisplayOtherFeaturesMenu(client);
		}
		//按下数字8时返回上一层.
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
//特感出现时.
public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
	if(g_bSpawningSwitch[0] == true)
		return Plugin_Handled;
	return Plugin_Continue;
}
//坦克出现时.
public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	if(g_bSpawningSwitch[1] == true)
		return Plugin_Handled;
	return Plugin_Continue;
}
//普通女巫出现时.
public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	if(g_bSpawningSwitch[2] == true)
		return Plugin_Handled;
	return Plugin_Continue;
}
//新娘女巫出现时.
public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3])
{
	if(g_bSpawningSwitch[2] == true)
		return Plugin_Handled;
	return Plugin_Continue;
}
//创建实体时(删除丧尸).
public void OnEntityCreated(int entity, const char[] name)
{
	if(IsValidEntity(entity))
		if((g_bSpawningSwitch[3] == true && strcmp(name, "infected") == 0))
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}
//钩子回调.
void OnSpawnPost(int entity)
{	
	if(entity > MaxClients && IsValidEntity(entity))
		RemoveEntity(entity);//删除实体.
}
//删除指定类型的全部实体.
void IsRemoveAllZombie(char[] typename)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, typename)) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
}
//处死全部电脑特感.
void IsForcePlayerSuicide(bool zombietype)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			if(zombietype == true)
			{
				if(GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
					ForcePlayerSuicide(i);//强制玩家自杀.
			}
			else
			{
				if(GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
					ForcePlayerSuicide(i);//强制玩家自杀.
			}
		}
	}
}
//根据所以功能开关赋值.
bool IsAllWitchState()
{
	return g_bAllSpawningSwitch = IsAllSpawningSwitch();
}
//获取全部类型开关状态.
bool IsAllSpawningSwitch()
{
	for(int i = 0; i < sizeof(g_bSpawningSwitch); i++)
		if(g_bSpawningSwitch[i] == false)
			return false;
	
	return true;
}
//判断管理员权限.
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}