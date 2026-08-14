#if defined _EvilChangeClientName
 #endinput
#endif
#define _EvilChangeClientName

public SharedPlugin __pl_l4d2_change_name = 
{
	name = "l4d2_change_name",
	file = "l4d2_change_name.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

/**
 * 更改玩家名称时调用.
 *
 * @param client		玩家的索引
 * @param oldname		更改前旧名称
 * @param newname		更改后新名称
 *
 * @return				Plugin_Handled 阻止更改名称, Plugin_Continue 允许更改名称.
 */
forward Action OnChangeClientName(int client, char[] oldname, char[] newname);