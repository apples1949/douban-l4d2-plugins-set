#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 4

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION	"1.1"
#define GAMEDATA "l4d2_parseline_fix"

Address com_token;
bool g_bBlockComment;

public Plugin myinfo =
{
	name = "[L4D2] Parse Line Fix",
	author = "xiaolinRM",
	description = "Fix non ASCII characters in cfg file that cannot be executed.",
	version = PLUGIN_VERSION,
	url = "https://github.com/xiaolinRM/L4D2Plugins/tree/main/l4d2_parseline_fix"
};

public void OnPluginStart()
{
    GameData hGameData = new GameData(GAMEDATA);
    if (!hGameData) SetFailState("Failed to load gamedata: \"%s.txt\"", GAMEDATA);

    com_token = hGameData.GetAddress("com_token");
    if (!com_token) SetFailState("Failed to load address: \"com_token\"");

    DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, "COM_ParseLine");
    if(!hDetour || !hDetour.Enable(Hook_Pre, COM_ParseLine))
        SetFailState("Failed to create hook: \"COM_ParseLine\"");

    delete hGameData;
    
	CreateConVar("l4d2_parseline_fix_version", PLUGIN_VERSION, "Parse Line Fix Plugin Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	ConVar convar = CreateConVar("l4d2_parseline_fix_blockcomment", "1", "Interpret /* */ as a comment block");
    convar.AddChangeHook(OnConVarChanged);
    g_bBlockComment = convar.BoolValue;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_bBlockComment = convar.BoolValue;
}

// my shitty code :(
public MRESReturn COM_ParseLine(DHookReturn hReturn, DHookParam hParams)
{
    Address string = hParams.GetAddress(1);
    if (!string)
    {
        StoreToAddress(com_token, 0, NumberType_Int8);
        hReturn.Value = 0;
        return MRES_Supercede;
    }
    int c;
    bool quotation;
    for (int index = 0;;index++)
    {
        c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
        if (!c)
        {
            StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
            hReturn.Value = 0;
            return MRES_Supercede;
        }
        if (!quotation)
        {
            if (c == 47)
            {
                int next = LoadFromAddress(string + view_as<Address>(index + 1), NumberType_Int8);
                if (next == 47)
                {
                    if (index) StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
                    else
                    {
                        StoreToAddress(com_token + view_as<Address>(index), 32, NumberType_Int8);
                        StoreToAddress(com_token + view_as<Address>(index + 1), 0, NumberType_Int8);
                    }
                    for (index += 2;;index++)
                    {
                        c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
                        if (!c)
                        {
                            hReturn.Value = 0;
                            return MRES_Supercede;
                        }
                        if (c == 10 || c == 13)
                        {
                            hReturn.Value = view_as<int>(string) + index + 1;
                            return MRES_Supercede;
                        }
                    }
                }
                else if (g_bBlockComment && next == 42)
                {
                    if (index) StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
                    else
                    {
                        StoreToAddress(com_token + view_as<Address>(index), 32, NumberType_Int8);
                        StoreToAddress(com_token + view_as<Address>(index + 1), 0, NumberType_Int8);
                    }
                    for (index += 2;;index++)
                    {
                        c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
                        if (!c)
                        {
                            hReturn.Value = 0;
                            return MRES_Supercede;
                        }
                        if (c == 42 && LoadFromAddress(string + view_as<Address>(index + 1), NumberType_Int8) == 47)
                        {
                            hReturn.Value = view_as<int>(string) + index + 2;
                            return MRES_Supercede;
                        }
                    }
                }
            }
            else if (c == 59)
            {
                if (index) StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
                else
                {
                    StoreToAddress(com_token + view_as<Address>(index), 32, NumberType_Int8);
                    StoreToAddress(com_token + view_as<Address>(index + 1), 0, NumberType_Int8);
                }
                hReturn.Value = view_as<int>(string) + index + 1;
                return MRES_Supercede;
            }
        }
        if (c == 10 || c == 13)
        {
            if (index) StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
            else
            {
                StoreToAddress(com_token + view_as<Address>(index), 32, NumberType_Int8);
                StoreToAddress(com_token + view_as<Address>(index + 1), 0, NumberType_Int8);
            }
            hReturn.Value = view_as<int>(string) + index + 1;
            return MRES_Supercede;
        }
        if (index >= 1023)
        {
            StoreToAddress(com_token + view_as<Address>(index), 0, NumberType_Int8);
            for (;;index++)
            {
                c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
                if (!c)
                {
                    hReturn.Value = 0;
                    return MRES_Supercede;
                }
                if (!quotation)
                {
                    if (c == 47)
                    {
                        int next = LoadFromAddress(string + view_as<Address>(index + 1), NumberType_Int8);
                        if (next == 47)
                        {
                            for (index += 2;;index++)
                            {
                                c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
                                if (!c)
                                {
                                    hReturn.Value = 0;
                                    return MRES_Supercede;
                                }
                                if (c == 10 || c == 13)
                                {
                                    hReturn.Value = view_as<int>(string) + index + 1;
                                    return MRES_Supercede;
                                }
                            }
                        }
                        else if (g_bBlockComment && next == 42)
                        {
                            for (index += 2;;index++)
                            {
                                c = LoadFromAddress(string + view_as<Address>(index), NumberType_Int8);
                                if (!c)
                                {
                                    hReturn.Value = 0;
                                    return MRES_Supercede;
                                }
                                if (c == 42 && LoadFromAddress(string + view_as<Address>(index + 1), NumberType_Int8) == 47)
                                {
                                    hReturn.Value = view_as<int>(string) + index + 2;
                                    return MRES_Supercede;
                                }
                            }
                        }
                    }
                    else if (c == 59)
                    {
                        hReturn.Value = view_as<int>(string) + index + 1;
                        return MRES_Supercede;
                    }
                }
                if (c == 10 || c == 13)
                {
                    hReturn.Value = view_as<int>(string) + index + 1;
                    return MRES_Supercede;
                }
                if (c == 34) quotation = !quotation;
            }
        }
        if (c == 34) quotation = !quotation;
        StoreToAddress(com_token + view_as<Address>(index), c, NumberType_Int8);
    }
}
