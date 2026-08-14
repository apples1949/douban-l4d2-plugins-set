//更改玩家名称时.
public Action OnChangeClientName(int client, char[] oldname, char[] newname)
{
	if(IsFakeClient(client))//玩家是电脑.
		return Plugin_Continue;//允许更改玩家名称.
	
	//PrintToChatAll("\x04[提示]\x05(%N)旧名称(%s)新名称(%s).", client, oldname, newname);
	return Plugin_Handled;//阻止更改玩家名称.
}