#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

native bool IsClientSpeaking(int client);

public Extension:__ext_voice = 
{
	name = "VoiceHook",
	file = "voicehook.ext",
	autoload = 1,
	required = 1,
}

Handle g_hSpeakingList = INVALID_HANDLE;

int ClientSpeakingList[MAXPLAYERS+1] = {-1, ...};

ConVar va_default_speaklist;
ConVar va_teamfilter_speaklist;

int iCount;
int iCountTeam[3];
char SpeakingPlayers[3][128];
int team;
Handle g_hTimerSpeaking;

public Plugin myinfo = 
{
	name = "SpeakingList",
	author = "Accelerator",
	description = "Voice Announce. Print To Center Message who Speaking. With cookies",
	version = "1.5",
	url = "http://core-ss.org"
}

public void OnPluginStart()
{
	g_hSpeakingList = RegClientCookie("speaking-list", "SpeakList", CookieAccess_Protected);
	
	va_default_speaklist = CreateConVar("va_default_speaklist", "1", "Default setting for Speak List [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_teamfilter_speaklist = CreateConVar("va_teamfilter_speaklist", "0", "Use Team Filter for Speak List [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_speaklist", Command_SpeakList);

	IsShowVoiceList();
}

public void OnMapStart()
{
	IsShowVoiceList();
}
void IsShowVoiceList()
{
	delete g_hTimerSpeaking;
	g_hTimerSpeaking = CreateTimer(0.7, UpdateSpeaking, _, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		if (AreClientCookiesCached(client))
		{
			char cookie[2];
			GetClientCookie(client, g_hSpeakingList, cookie, sizeof(cookie));
			ClientSpeakingList[client] = StringToInt(cookie);
			
			if (ClientSpeakingList[client] == 0)
				ClientSpeakingList[client] = GetConVarInt(va_default_speaklist);
		}
	}
}

public void OnClientDisconnect(int client)
{
	ClientSpeakingList[client] = -1;
}

public Action Command_SpeakList(int client, int args)
{
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	if (ClientSpeakingList[client] == 1)
	{
		ClientSpeakingList[client] = -1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "-1");
		}
		PrintToChat(client, "[SM] Speaking List is disable for you");
	}
	else
	{
		ClientSpeakingList[client] = 1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "1");
		}
		PrintToChat(client, "[SM] Speaking List is enable for you");
	}
	return Plugin_Continue;
}

public Action UpdateSpeaking(Handle timer)
{
	iCount = 0;
	iCountTeam[0] = 0;
	iCountTeam[1] = 0;
	iCountTeam[2] = 0;
	SpeakingPlayers[0][0] = '\0';
	SpeakingPlayers[1][0] = '\0';
	SpeakingPlayers[2][0] = '\0';
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (IsClientSpeaking(i))
			{
				if (GetClientListeningFlags(i) & VOICE_MUTED) continue;
				
				team = GetClientTeam(i)-1;
				if (team < 0 || team > 2) continue;
				
				Format(SpeakingPlayers[team], sizeof(SpeakingPlayers[]), "%s\n%N", SpeakingPlayers[team], i);
				iCount++;
				iCountTeam[team]++;
			}
		}
	}
	if (iCount > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (ClientSpeakingList[i] > 0)
			{
				if (GetConVarInt(va_teamfilter_speaklist))
				{
					team = GetClientTeam(i)-1;
					if (team < 0 || team > 2) continue;
					
					if (iCountTeam[team] > 0)
					{
						PrintCenterText(i, "正在语音:%s", SpeakingPlayers[team]);
					}
				}
				else
					PrintCenterText(i, "正在语音:%s%s%s", SpeakingPlayers[0], SpeakingPlayers[1], SpeakingPlayers[2]);
			}
		}
	}
	return Plugin_Continue;
}