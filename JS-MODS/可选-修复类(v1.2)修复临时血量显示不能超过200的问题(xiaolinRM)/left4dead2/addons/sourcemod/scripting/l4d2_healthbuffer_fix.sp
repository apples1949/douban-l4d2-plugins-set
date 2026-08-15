#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 4

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
    name = "[L4D & L4D2] Health Buffer Fix",
    author = "xiaolinRM",
    description = "Fix the issue where health buffer display cannot exceed 200.",
    version = PLUGIN_VERSION,
    url = "https://github.com/xiaolinRM/L4D2Plugins/tree/main/l4d2_healthbuffer_fix"
};

bool g_bLeft4Dead2;
float pain_pills_decay_rate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();
    if (engine == Engine_Left4Dead) g_bLeft4Dead2 = false;
    else if (engine == Engine_Left4Dead2) g_bLeft4Dead2 = true;
    else
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    CreateConVar("l4d2_healthbuffer_fix_version", PLUGIN_VERSION, "Health Buffer Fix Plugin Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

    ConVar convar = FindConVar("pain_pills_decay_rate");
    convar.AddChangeHook(OnConVarChanged);
    pain_pills_decay_rate = convar.FloatValue;
    if (!pain_pills_decay_rate)
    {
        PrintToServer("The value of pain_pills_decay_rate is 0, Health buffer display fix is now disabled.");
        return;
    }

    HookEvent("player_hurt", Event_CheckEvent);
    HookEvent("pills_used", Event_CheckEvent);
    if (g_bLeft4Dead2) HookEvent("adrenaline_used", Event_CheckEvent);
    for (int client = 1; client <= MaxClients; client++)
        if (IsClientInGame(client))
            SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnPluginEnd()
{
    UpdateHealthBuffer();
}

public void OnClientPutInServer(int client)
{
    if (pain_pills_decay_rate)
        SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnPostThinkPost(int client)
{
    CheckPlayerHealthBuffer(client);
}

public void Event_CheckEvent(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client) CheckPlayerHealthBuffer(client);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    float value = convar.FloatValue;
    if (value == pain_pills_decay_rate) return;
    UpdateHealthBuffer(value);
    float old = pain_pills_decay_rate;
    pain_pills_decay_rate = value;
    if (!old && pain_pills_decay_rate)
    {
        HookEvent("player_hurt", Event_CheckEvent);
        HookEvent("pills_used", Event_CheckEvent);
        if (g_bLeft4Dead2) HookEvent("adrenaline_used", Event_CheckEvent);
        for (int client = 1; client <= MaxClients; client++)
            if (IsClientInGame(client))
                SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        PrintToServer("Health buffer display fix is now enabled.");
    }
    else if (old && !pain_pills_decay_rate)
    {
        UnhookEvent("player_hurt", Event_CheckEvent);
        UnhookEvent("pills_used", Event_CheckEvent);
        if (g_bLeft4Dead2) UnhookEvent("adrenaline_used", Event_CheckEvent);
        for (int client = 1; client <= MaxClients; client++)
            if (IsClientInGame(client))
                SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        PrintToServer("The value of pain_pills_decay_rate is 0, Health buffer display fix is now disabled.");
    }
}

void CheckPlayerHealthBuffer(int client)
{
    if (!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client)) return;
    float health = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    if (!health) return;
    if (health < 0.0)
    {
        SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
        return;
    }
    if (health <= 200.0) return;
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 200.0);
    float time = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    time += (health - 200.0) / pain_pills_decay_rate;
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", time);
}

void UpdateHealthBuffer(float newValue = 0.0)
{
    float gameTime = GetGameTime();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client)) continue;
        float health = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
        if (!health) continue;
        if (health < 0.0)
        {
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
            continue;
        }
        float time = gameTime;
        health -= (gameTime - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * pain_pills_decay_rate;
        if (health < 0.0) health = 0.0;
        else if (newValue && health > 200.0)
        {
            time += (health - 200.0) / newValue;
            health = 200.0;
        }
        SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health);
        SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", time);
    }
}
