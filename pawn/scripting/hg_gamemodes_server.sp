#include <sourcemod>

#pragma semicolon 1

#define MAX_MAP_NAME_LENGTH 48

new String:g_sGameModes_Server[PLATFORM_MAX_PATH] = "/GameModes_Server.txt";
new String:g_sGameModes_Base[PLATFORM_MAX_PATH] = "/gamemodes_server_base.txt";
new String:g_sMapList[PLATFORM_MAX_PATH] = "/maplist.txt";
new String:g_sMapCycle[PLATFORM_MAX_PATH] = "/mapcycle.txt";
new String:g_sMapList_Custom[PLATFORM_MAX_PATH] = "/maplist_only_edit_this_one.txt";

public OnPluginStart()
{
    WriteMapFile(g_sMapList);
    WriteMapFile(g_sMapCycle);

    CreateTimer(1.0, Timer_UpdateFiles);
    CreateTimer(1800.0, Timer_UpdateFiles, _, TIMER_REPEAT);
}

stock WriteMapFile(const String:filepath[])
{
    new Handle:hMaps = GenerateMapArray();
    new Handle:iFile = OpenFile(filepath, "w");

    decl String:sMap[MAX_MAP_NAME_LENGTH];

    for (new i = 0; i < GetArraySize(hMaps); i++)
    {
        GetArrayString(hMaps, i, sMap, sizeof(sMap));
        WriteFileLine(iFile, sMap);
    }

    CloseHandle(hMaps);
    CloseHandle(iFile);
}

public Action:Timer_UpdateFiles(Handle:timer, any:data)
{
    new Handle:hMaps = GenerateMapArray();
    new Handle:iFile = OpenFile(g_sGameModes_Server, "w");
    new Handle:oFile = OpenFile(g_sGameModes_Base, "r");

    decl String:line[256];

    while (!IsEndOfFile(oFile) && ReadFileLine(oFile, line, sizeof(line)))
        WriteFileLine(iFile, line);

    for (new i = 0; i < GetArraySize(hMaps); i++)
    {
        GetArrayString(hMaps, i, line, sizeof(line));
        WriteFileLine(iFile, "        \"%s\"    \"\"", line);
    }

    WriteFileLine(iFile, "      }");
    WriteFileLine(iFile, "   }");
    WriteFileLine(iFile, "  }\n");

    WriteFileLine(iFile, "  \"maps\"");
    WriteFileLine(iFile, "  {");

    for (new i = 0; i < GetArraySize(hMaps); i++)
    {
        GetArrayString(hMaps, i, line, sizeof(line));

        WriteFileLine(iFile, "    \"%s\"", line);
        WriteFileLine(iFile, "    {");
        WriteFileLine(iFile, "      \"nameID\"    \"#SFUI_Map_%s\"", line);
        WriteFileLine(iFile, "      \"name\"      \"%s\"", line);
        WriteFileLine(iFile, "      \"imagename\"    \"map-custom2-overall\"");
        WriteFileLine(iFile, "      \"t_arms\"    \"models/weapons/t_arms_phoenix.mdl\"");
        WriteFileLine(iFile, "      \"t_models\"");
        WriteFileLine(iFile, "      {");
        WriteFileLine(iFile, "        \"tm_phoenix\"    \"\"");
        WriteFileLine(iFile, "        \"tm_phoenix_variantA\"    \"\"");
        WriteFileLine(iFile, "        \"tm_phoenix_variantB\"    \"\"");
        WriteFileLine(iFile, "        \"tm_phoenix_variantC\"    \"\"");
        WriteFileLine(iFile, "        \"tm_phoenix_variantD\"    \"\"");
        WriteFileLine(iFile, "      }");
        WriteFileLine(iFile, "      \"ct_arms\"    \"models/weapons/ct_arms_st6.mdl\"");
        WriteFileLine(iFile, "      \"ct_models\"");
        WriteFileLine(iFile, "      {");
        WriteFileLine(iFile, "        \"ctm_st6\"    \"\"");
        WriteFileLine(iFile, "        \"ctm_st6_variantA\"    \"\"");
        WriteFileLine(iFile, "        \"ctm_st6_variantB\"    \"\"");
        WriteFileLine(iFile, "        \"ctm_st6_variantC\"    \"\"");
        WriteFileLine(iFile, "        \"ctm_st6_variantD\"    \"\"");
        WriteFileLine(iFile, "      }");
        WriteFileLine(iFile, "    }\n");
    }

    WriteFileLine(iFile, "  }");
    WriteFileLine(iFile, "}");

    CloseHandle(iFile);
    CloseHandle(oFile);
    CloseHandle(hMaps);

    return Plugin_Continue;
}


Handle:GenerateMapArray()
{
    new Handle:oFile = OpenFile(g_sMapList_Custom, "r");
    new Handle:hMaps = CreateArray(ByteCountToCells(MAX_MAP_NAME_LENGTH));

    new String:line[MAX_MAP_NAME_LENGTH];

    while (!IsEndOfFile(oFile) && ReadFileLine(oFile, line, sizeof(line)))
    {
        TrimString(line);

        ReplaceString(line, sizeof(line), "\n", "");
        ReplaceString(line, sizeof(line), "\r", "");
        ReplaceString(line, sizeof(line), "\t", "");
        ReplaceString(line, sizeof(line), " ", "");

        if (!StrEqual(line, ""))
            PushArrayString(hMaps, line);
    }

    CloseHandle(oFile);
    return hMaps;
}
