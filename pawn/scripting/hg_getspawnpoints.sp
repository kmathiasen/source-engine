// ###################### PREPROCESSOR MACROS AND GLOBALS ######################

    // Includes.
    #pragma semicolon 1
    #include <sourcemod>
    #include <sdktools>
    #include <cstrike>

    // Plugin definitions.
    #define MSG_PREFIX "\x01\x03"
    #define PLUGIN_NAME "hg_getspawnpoints"
    #define PLUGIN_VERSION "0.01"
    #define SERVER_MOD "css"

    // Team definitions.
    #define TEAM_SPEC 1
    #define TEAM_T 2
    #define TEAM_CT 3

    new String:g_sFilePath[PLATFORM_MAX_PATH];

    // Plugin display info.
    public Plugin:myinfo =
    {
        name = PLUGIN_NAME,
        author = "HeLLsGamers",
        description = "HG Get Spawn Points",
        version = PLUGIN_VERSION,
        url = "http://www.hellsgamers.com/"
    };

// ###################### EVENTS, FORWARDS, AND COMMANDS ######################

    public OnPluginStart()
    {
        RegConsoleCmd("getpoint", Command_GetPoint, "Gets coordinates and angle of the location where the player is currently standing");
        BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "data/spawnpoints.txt");
    }

    public Action:Command_GetPoint(client, args)
    {
        // Player must be in-game and alive.
        if(client < 1)
        {
            PrintToConsole(client, "This command requires you to be in-game");
            return Plugin_Handled;
        }
        if(!IsPlayerAlive(client))
        {
            PrintToChat(client, "This command requires you to be alive");
            return Plugin_Handled;
        }

        // Get player's position.
        new Float:pos[3];
        GetClientAbsOrigin(client, pos);

        // Get player's angle.
        new Float:ang[3];
        GetClientEyeAngles(client, ang);

        new Handle:iFile = OpenFile(g_sFilePath, "a");

        // Print position and angle in console.
        PrintToConsole(client, "ORIGIN: X = [%f], Y = [%f], Z = [%f]", pos[0], pos[1], pos[2]);
        PrintToConsole(client, "ANGLES: X = [%f], Y = [%f], Z = [%f]", ang[0], ang[1], ang[2]);
        WriteFileLine(iFile, "add:");
        WriteFileLine(iFile, "{");
        WriteFileLine(iFile, "\"classname\" \"info_player_xxxxx\"");
        WriteFileLine(iFile, "\"origin\" \"%i %i %i\"", RoundToNearest(pos[0]), RoundToNearest(pos[1]), RoundToNearest(pos[2]) + 5);
        WriteFileLine(iFile, "\"angles\" \"%i %i %i\"", RoundToNearest(ang[0]), RoundToNearest(ang[1]), RoundToNearest(ang[2]));
        WriteFileLine(iFile, "}");

        // Done.
        CloseHandle(iFile);
        return Plugin_Handled;
    }