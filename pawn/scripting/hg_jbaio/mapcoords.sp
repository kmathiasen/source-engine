
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

new Handle:g_hDbCoords = INVALID_HANDLE;                    // Trie to hold map coordinates and angles of locations queried from the DB.
new Handle:g_hDbRooms = INVALID_HANDLE;                     // Trie to hold map centerpoints and dimensions of rooms queried from the DB.

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

MapCoords_OnPluginStart()
{
    g_hDbCoords = CreateTrie();
    g_hDbRooms = CreateTrie();
    RegAdminCmd("addroom", Command_AddRoom, ADMFLAG_ROOT, "Add a map room. Syntax -- addroom \"<room>\" <warday room 1/0> <length (x)> <width (y)> <height (z)>");
    RegAdminCmd("getcoord", Command_GetCoord, ADMFLAG_CHANGEMAP, "Gets current coordinates where the player is currently standing and prints them to chat & console");
    RegAdminCmd("setcoord", Command_SetCoord, ADMFLAG_ROOT, "Gets current coordinates where the player is currently standing and sets it in database");
    RegAdminCmd("setroomcenter", Command_SetRoomCenter, ADMFLAG_ROOT, "Sets center of existing room. Syntax -- setroomcenter <room> <x> [y] [z]");
    RegAdminCmd("setroomsize", Command_SetRoomSize, ADMFLAG_ROOT, "Sets center of existing room. Syntax -- setroomsize <room> <length (x)> [width (y)] [height (z)]");
    RegAdminCmd("showcoord", Command_ShowCoord, ADMFLAG_CHANGEMAP, "Shows a given coordinate");
    RegAdminCmd("showroom", Command_ShowRoom, ADMFLAG_CHANGEMAP, "Shows a cube of a given room");
    RegAdminCmd("reloadcoords", Command_ReloadCoord, ADMFLAG_CHANGEMAP, "Reloads all map coords from database");
    RegAdminCmd("reloadrooms", Command_ReloadRooms, ADMFLAG_CHANGEMAP, "Reloads all map rooms from database");
}

MapCoords_OnDbConnect(Handle:conn)
{
    MapCoords_GetCoords(conn);
    MapCoords_GetRooms(conn);
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_ReloadCoord(client, args)
{
    if (g_hDbConn_Main != INVALID_HANDLE)
    {
        MapCoords_GetCoords(g_hDbConn_Main, client > 0 ? GetClientUserId(client) : 0);
        ReplyToCommandGood(client, "Reloading coords...", MSG_PREFIX);
    }
    else
        ReplyToCommandGood(client, "Could not reload coords (no DB connection)", MSG_PREFIX);
    return Plugin_Handled;
}

public Action:Command_ReloadRooms(client, args)
{
    if (g_hDbConn_Main != INVALID_HANDLE)
    {
        MapCoords_GetRooms(g_hDbConn_Main, client > 0 ? GetClientUserId(client) : 0);
        ReplyToCommandGood(client, "Reloading rooms...", MSG_PREFIX);
    }
    else
        ReplyToCommandGood(client, "Could not reload rooms (no DB connection)", MSG_PREFIX);
    return Plugin_Handled;
}

public Action:Command_ShowCoord(client, args)
{
    // Get room name from command arg.
    decl String:coordname[LEN_CONVARS];
    GetCmdArgString(coordname, LEN_CONVARS);

    // Re-get this one map coord from DB and update it in trie.
    MapCoords_ReGetCoord(coordname);

    // Pull room data from trie.
    decl Float:teledata[3];
    /*
        teledata[0] = pos_x
        teledata[1] = pos_y
        teledata[2] = pos_z
        teledata[3] = horiz_angle
    */
    if (!GetTrieArray(g_hDbCoords, coordname, Float:teledata, 3))
    {
        ReplyToCommandGood(client, "%s invalid room name \"%s\"", MSG_PREFIX, coordname);
        return Plugin_Handled;
    }

    // Draw ring around coord.
    TE_SetupBeamRingPoint(teledata, 50.0, 51.0, g_iSpriteBeam, g_iSpriteRing, 0, 15, 20.0, 7.0, 0.0, g_iColorGreen, 1, 0);
    if (client > 0 && IsClientInGame(client))
        TE_SendToClient(client);
    else
        TE_SendToAll();

    // Notify player of coordinates.
    ReplyToCommandGood(client, "%s %s: \x03X\x01: \x04%f\x01, \x03Y\x01: \x04%f\x01, \x03Z\x01: \x04%f\x01", MSG_PREFIX, coordname, teledata[0], teledata[1], teledata[2]);

    return Plugin_Handled;
}

public Action:Command_ShowRoom(client, args)
{
    // Get room name from command arg.
    decl String:roomname[LEN_CONVARS];
    GetCmdArgString(roomname, LEN_CONVARS);

    // Re-get this one map room from DB and put update it in trie.
    MapCoords_ReGetRoom(roomname);

    // Pull room data from trie.
    decl Float:roomdata[6];
    if (!GetTrieArray(g_hDbRooms, roomname, Float:roomdata, 6))
    {
        ReplyToCommandGood(client, "%s invalid room name \"%s\"", MSG_PREFIX, roomname);
        return Plugin_Handled;
    }

    // Up is +
    // Top is +
    // Left is +

    new Float:x = roomdata[0];              // x corresponds to length
    new Float:y = roomdata[1];              // y corresponds to width
    new Float:z = roomdata[2];              // z corresponds to height

    new Float:hl = roomdata[3] / 2.0;       // Half Length
    new Float:hw = roomdata[4] / 2.0;       // Half Width
    new Float:hh = roomdata[5] / 2.0;       // Half Height

    // Notify player of coordinates.
    ReplyToCommandGood(client, "%s %s: \x03X\x01: \x04%f\x01, \x03Y\x01: \x04%f\x01, \x03Z\x01: \x04%f\x01, \x03L\x01: \x04%f\x01, \x03W\x01: \x04%f\x01, \x03H\x01: \x04%f", MSG_PREFIX, roomname, x, y, z, hl * 2, hw * 2, hh * 2);

    decl Float:TopLeftUp[3];
    PopulateVector(TopLeftUp, x + hl, y + hw, z + hh);
    decl Float:BottomLeftUp[3];
    PopulateVector(BottomLeftUp, x + hl, y + hw, z - hh);
    decl Float:TopRightUp[3];
    PopulateVector(TopRightUp, x + hl, y - hw, z + hh);
    decl Float:BottomRightUp[3];
    PopulateVector(BottomRightUp, x + hl, y - hw, z - hh);
    decl Float:TopLeftDown[3];
    PopulateVector(TopLeftDown, x - hl, y + hw, z + hh);
    decl Float:BottomLeftDown[3];
    PopulateVector(BottomLeftDown, x - hl, y + hw, z - hh);
    decl Float:TopRightDown[3];
    PopulateVector(TopRightDown, x - hl, y - hw, z + hh);
    decl Float:BottomRightDown[3];
    PopulateVector(BottomRightDown, x - hl, y - hw, z - hh);

    // Outline beams.
    CreateStandardBeam(TopLeftUp, BottomLeftUp, g_iColorBlue, client);
    CreateStandardBeam(TopRightUp, BottomRightUp, g_iColorBlue, client);
    CreateStandardBeam(TopLeftDown, BottomLeftDown, g_iColorBlue, client);
    CreateStandardBeam(TopRightDown, BottomRightDown, g_iColorBlue, client);
    CreateStandardBeam(TopLeftUp, TopRightUp, g_iColorBlue, client);
    CreateStandardBeam(BottomLeftUp, BottomRightUp, g_iColorBlue, client);
    CreateStandardBeam(TopLeftDown, TopRightDown, g_iColorBlue, client);
    CreateStandardBeam(BottomLeftDown, BottomRightDown, g_iColorBlue, client);
    CreateStandardBeam(TopLeftUp, TopLeftDown, g_iColorBlue, client);
    CreateStandardBeam(BottomLeftUp, BottomLeftDown, g_iColorBlue, client);
    CreateStandardBeam(TopRightUp, TopRightDown, g_iColorBlue, client);
    CreateStandardBeam(BottomRightUp, BottomRightDown, g_iColorBlue, client);

    // Beams crossing thru middle.
    CreateStandardBeam(TopLeftUp, BottomRightDown, g_iColorGreen, client);
    CreateStandardBeam(TopRightUp, BottomLeftDown, g_iColorGreen, client);
    CreateStandardBeam(TopLeftDown, BottomRightUp, g_iColorGreen, client);
    CreateStandardBeam(TopRightDown, BottomLeftUp, g_iColorGreen, client);

    // Beams crossing on sides.
    CreateStandardBeam(TopLeftUp, BottomRightUp, g_iColorRed, client);
    CreateStandardBeam(TopRightUp, BottomLeftUp, g_iColorRed, client);
    CreateStandardBeam(TopLeftDown, BottomRightDown, g_iColorRed, client);
    CreateStandardBeam(TopRightDown, BottomLeftDown, g_iColorRed, client);
    CreateStandardBeam(TopLeftUp, TopRightUp, g_iColorRed, client);
    CreateStandardBeam(TopRightUp, TopLeftUp, g_iColorRed, client);
    CreateStandardBeam(TopLeftDown, TopRightDown, g_iColorRed, client);
    CreateStandardBeam(TopRightDown, TopLeftDown, g_iColorRed, client);
    CreateStandardBeam(TopLeftUp, BottomLeftUp, g_iColorRed, client);
    CreateStandardBeam(TopRightUp, BottomRightUp, g_iColorRed, client);
    CreateStandardBeam(TopLeftDown, BottomLeftDown, g_iColorRed, client);
    CreateStandardBeam(TopRightDown, BottomRightDown, g_iColorRed, client);

    return Plugin_Handled;
}

public Action:Command_AddRoom(client, args)
{
    if (client <= 0)
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }

    if (args < 5)
    {
        ReplyToCommandGood(client, "%s Invalid syntax -- addroom \x03\"<room>\" <warday room 1/0> <length (x)> <width (y)> <height (z)>", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:sRoomName[MAX_NAME_LENGTH];
    decl String:sEscapeName[MAX_NAME_LENGTH * 2 + 1];
    decl String:sWarday[4];
    decl String:sLength[16];
    decl String:sWidth[16];
    decl String:sHeight[16];
    decl String:sMapName[MAX_NAME_LENGTH];
    decl Float:origin[3];

    GetCmdArg(1, sRoomName, sizeof(sRoomName));
    GetCmdArg(2, sWarday, sizeof(sWarday));
    GetCmdArg(3, sLength, sizeof(sLength));
    GetCmdArg(4, sWidth, sizeof(sWidth));
    GetCmdArg(5, sHeight, sizeof(sHeight));
    GetCurrentMap(sMapName, sizeof(sMapName));

    GetClientAbsOrigin(client, origin);
    SQL_EscapeString(g_hDbConn_Main, sRoomName, sEscapeName, sizeof(sEscapeName));

    decl String:query[512];
    Format(query, sizeof(query),
           "INSERT INTO maprooms (roomname, cp_x, cp_y, cp_z, length, width, height, warday, mapname) VALUES ('%s', %f, %f, %f, %f, %f, %f, %d, '%s') ON DUPLICATE KEY UPDATE mapname = '%s', warday = %d",
            sEscapeName,
            origin[0], origin[1], origin[2],
            StringToFloat(sLength), StringToFloat(sWidth), StringToFloat(sHeight),
            StringToInt(sWarday) == 0 ? 0 : 1,
            sMapName, sMapName,
            StringToInt(sWarday) == 0 ? 0 : 1);

    SQL_TQuery(g_hDbConn_Main, EmptyCallback, query, 14);

    PrintToChat(client, "%s Created map room \x03%s", MSG_PREFIX, sRoomName);
    PrintToChat(client, "%s Center: \x01x: \x03%0.2f \x01y: \x03%0.2f \x01z: \x03%0.f", MSG_PREFIX, origin[0], origin[1], origin[2]);
    PrintToChat(client, "%s Dimensions: \x01Length: \x03%0.2f \x01Width: \x03%0.2f \x01Height: \x03%0.2f", MSG_PREFIX, StringToFloat(sLength), StringToFloat(sWidth), StringToFloat(sHeight));

    return Plugin_Handled;
}

public Action:Command_GetCoord(client, args)
{
    // Player must be in-game and alive.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }
    if (!IsPlayerAlive(client)) // Don't use JB_IsPlayerAlive
    {
        PrintToChat(client, "%s This command requires you to be alive", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Get player's current coordinates.
    new Float:vec[3];
    GetClientAbsOrigin(client, vec);

    // Get player's angle.
    new Float:ang[3];
    GetClientEyeAngles(client, ang);

    // Notify player of coordinates.
    PrintToChat(client, "%s Position \x01X: \x03%i\x04, \x01Y: \x03%i\x04, \x01Z: \x03%i\x04, \x01Horiz. Angle: \x03%i", MSG_PREFIX,
                RoundToNearest(vec[0]), RoundToNearest(vec[1]), RoundToNearest(vec[2]), RoundToNearest(ang[1]));

    // Done.
    return Plugin_Handled;
}

public Action:Command_SetCoord(client, args)
{
    // Player must be in-game and alive.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }
    if (!IsPlayerAlive(client)) // Don't use JB_IsPlayerAlive
    {
        PrintToChat(client, "%s This command requires you to be alive", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Get player's current coordinates.
    new Float:vec[3];
    GetClientAbsOrigin(client, vec);

    // Get player's angle.
    new Float:ang[3];
    GetClientEyeAngles(client, ang);

    // Notify player of coordinates.
    PrintToChat(client, "%s Position \x01X: \x03%i\x04, \x01Y: \x03%i\x04, \x01Z: \x03%i\x04, \x01Horiz. Angle: \x03%i", MSG_PREFIX,
        RoundToNearest(vec[0]), RoundToNearest(vec[1]), RoundToNearest(vec[2]), RoundToNearest(ang[1]));

    // Get the arg string for the current command (this command).
    new String:argstring[LEN_CONVARS];
    GetCmdArgString(argstring, LEN_CONVARS);

    // Check length of argument.
    if (strlen(argstring) <= 0)
    {
        PrintToChat(client, "%s ERROR: Must include name; example:", MSG_PREFIX);
        PrintToChat(client, "%s setcoord COORD_NAME_HERE", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (strlen(argstring) >= LEN_MAPCOORDS)
    {
        PrintToChat(client, "%s ERROR: Name must be less than %i characters", MSG_PREFIX, LEN_MAPCOORDS);
        return Plugin_Handled;
    }

    // Check if argstring is a simple name (only letters, numbers, underscore) for inserting into database.
    //new flags;
    //if (SimpleRegexMatch(argstring, REGEX_SIMPLENAME, flags) > 0)

    // The argstring is a valid name for coordinates.
    decl String:mapname[LEN_MAPCOORDS];
    GetCurrentMap(mapname, LEN_MAPCOORDS);

    // Escape the coord name
    decl String:esc_argstring[LEN_CONVARS * 2 + 1];
    SQL_EscapeString(g_hDbConn_Main, argstring, esc_argstring, sizeof(esc_argstring));

    // Sanitize mapname.
    decl String:esc_mapname[(LEN_MAPCOORDS * 2) + 1];
    SQL_EscapeString(g_hDbConn_Main, mapname, esc_mapname, sizeof(esc_mapname));

    // Gather all info that we will need to pass to the callback in order to finish up.
    new Handle:data = CreateDataPack();
    WritePackCell(data, client);
    WritePackString(data, esc_argstring);
    WritePackFloat(data, vec[0]);
    WritePackFloat(data, vec[1]);
    WritePackFloat(data, vec[2]);
    WritePackFloat(data, ang[1]);

    // Create and execute SQL statement to insert these coordinates.
    decl String:columns[] = "mapname, coordname, pos_x, pos_y, pos_z, horiz_angle";
    decl String:values[576];
    Format(values, sizeof(values), "'%s', '%s', %f, %f, %f, %f", esc_mapname, esc_argstring, vec[0], vec[1], vec[2], ang[1]);
    decl String:q[640];
    Format(q, sizeof(q), "REPLACE INTO mapcoords (%s) VALUES (%s)", columns, values);
    SQL_TQuery(g_hDbConn_Main, MapCoords_Insert_Finish, q, data);

    // Done.
    return Plugin_Handled;
}

public Action:Command_SetRoomCenter(client, args)
{
    if (args < 2)
    {
        ReplyToCommandGood(client, "%s Invalid Syntax -- setroomcenter \"<\x03room\x04>\" <\x03x\x04> [\x03y\x04] [\x03z\x04]", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:roomName[MAX_NAME_LENGTH];
    decl String:sEscapedRoomName[MAX_NAME_LENGTH * 2 + 1];
    decl String:cp_x[LEN_INTSTRING];
    decl String:update[128];
    decl String:query[512];

    GetCmdArg(1, roomName, sizeof(roomName));
    GetCmdArg(2, cp_x, sizeof(cp_x));

    SQL_EscapeString(g_hDbConn_Main, roomName, sEscapedRoomName, sizeof(sEscapedRoomName));
    Format(update, sizeof(update), "cp_x = '%f' ", StringToFloat(cp_x));

    // Check to make sure the room already exists
    decl Float:roomdata[6];
    if (!GetTrieArray(g_hDbRooms, roomName, Float:roomdata, 6))
    {
        ReplyToCommandGood(client, "%s invalid room name \"%s\"", MSG_PREFIX, roomName);
        return Plugin_Handled;
    }

    if (args > 2)
    {
        decl String:add[64];
        decl String:cp_y[LEN_INTSTRING];

        GetCmdArg(3, cp_y, sizeof(cp_y));
        Format(add, sizeof(add), ", cp_y = '%f' ", StringToFloat(cp_y));

        StrCat(update, sizeof(update), add);
    }

    if (args > 3)
    {
        decl String:add[64];
        decl String:cp_z[LEN_INTSTRING];

        GetCmdArg(4, cp_z, sizeof(cp_z));
        Format(add, sizeof(add), ", cp_z = '%f' ", StringToFloat(cp_z));

        StrCat(update, sizeof(update), add);
    }

    Format(query, sizeof(query), "UPDATE maprooms SET %s WHERE roomname = '%s' AND mapname LIKE '%s%%'", update, sEscapedRoomName, g_sMapPrefix);

    new Handle:data = CreateDataPack();

    WritePackCell(data, GetClientUserId(client));
    WritePackString(data, roomName);
    WritePackString(data, update);

    SQL_TQuery(g_hDbConn_Main, MapCoords_SetRoomData_Finish, query, data);
    return Plugin_Handled;
}

public Action:Command_SetRoomSize(client, args)
{
    if (args < 2)
    {
        ReplyToCommandGood(client, "%s Invalid Syntax -- setroomsize \"<\x03room\x04>\" <\x03length (x)\x04> [\x03width (y)\x04] [\x03height (z)\x04]", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:roomName[MAX_NAME_LENGTH];
    decl String:sEscapedRoomName[MAX_NAME_LENGTH * 2 + 1];
    decl String:cp_x[LEN_INTSTRING];
    decl String:update[128];
    decl String:query[512];

    GetCmdArg(1, roomName, sizeof(roomName));
    GetCmdArg(2, cp_x, sizeof(cp_x));

    SQL_EscapeString(g_hDbConn_Main, roomName, sEscapedRoomName, sizeof(sEscapedRoomName));
    Format(update, sizeof(update), "length = '%f' ", StringToFloat(cp_x));

    // Check to make sure the room already exists
    decl Float:roomdata[6];
    if (!GetTrieArray(g_hDbRooms, roomName, Float:roomdata, 6))
    {
        ReplyToCommandGood(client, "%s invalid room name \"%s\"", MSG_PREFIX, roomName);
        return Plugin_Handled;
    }

    if (args > 2)
    {
        decl String:add[64];
        decl String:cp_y[LEN_INTSTRING];

        GetCmdArg(3, cp_y, sizeof(cp_y));
        Format(add, sizeof(add), ", width = '%f' ", StringToFloat(cp_y));

        StrCat(update, sizeof(update), add);
    }

    if (args > 3)
    {
        decl String:add[64];
        decl String:cp_z[LEN_INTSTRING];

        GetCmdArg(4, cp_z, sizeof(cp_z));
        Format(add, sizeof(add), ", height = '%f' ", StringToFloat(cp_z));

        StrCat(update, sizeof(update), add);
    }

    Format(query, sizeof(query), "UPDATE maprooms SET %s WHERE roomname = '%s' AND mapname LIKE '%s%%'", update, sEscapedRoomName, g_sMapPrefix);

    new Handle:data = CreateDataPack();

    WritePackCell(data, GetClientUserId(client));
    WritePackString(data, roomName);
    WritePackString(data, update);

    SQL_TQuery(g_hDbConn_Main, MapCoords_SetRoomData_Finish, query, data);
    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

MapCoords_GetCoords(Handle:conn, adminUserId=0)
{
    // Get mapname.
    decl String:mapname[LEN_MAPCOORDS];
    GetCurrentMap(mapname, sizeof(mapname));

    // Sanitize mapname.
    decl String:esc_mapname[(sizeof(mapname) * 2) + 1];
    SQL_EscapeString(conn, mapname, esc_mapname, sizeof(esc_mapname));

    // Create and execute SQL statement to get coords.
    decl String:q[256];
    Format(q, sizeof(q), "SELECT coordname, pos_x, pos_y, pos_z, horiz_angle FROM mapcoords WHERE mapname LIKE '%s%%' ORDER BY coordname", g_sMapPrefix);
    SQL_TQuery(conn, MapCoords_GetCoords_CB, q, adminUserId);
}

MapCoords_GetRooms(Handle:conn, adminUserId=0)
{
    // Get mapname.
    decl String:mapname[LEN_MAPCOORDS];
    GetCurrentMap(mapname, sizeof(mapname));

    // Sanitize mapname.
    decl String:esc_mapname[(sizeof(mapname) * 2) + 1];
    SQL_EscapeString(conn, mapname, esc_mapname, sizeof(esc_mapname));

    // Create and execute SQL statement to get coords.
    decl String:q[256];
    Format(q, sizeof(q), "SELECT roomname, cp_x, cp_y, cp_z, length, width, height, warday FROM maprooms WHERE mapname LIKE '%s%%' ORDER BY roomname", g_sMapPrefix);
    SQL_TQuery(conn, MapCoords_GetRooms_CB, q, adminUserId);
}

MapCoords_ReGetCoord(const String:coordname[])
{
    // Make sure db is connected.
    if (g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in MapCoords_ReGetCoord: DB handle was invalid");
        return;
    }

    // Hold error.
    new String:error[255];

    // Lock database because using non-threaded query.
    SQL_LockDatabase(g_hDbConn_Main);

    // Prepare update statement.
    decl String:sql[] = "SELECT pos_x, pos_y, pos_z, horiz_angle FROM mapcoords WHERE mapname = ? AND coordname = ? LIMIT 1";
    new Handle:stmnt = INVALID_HANDLE;
    stmnt = SQL_PrepareQuery(g_hDbConn_Main, sql, error, sizeof(error));
    if (stmnt == INVALID_HANDLE)
    {
        SQL_UnlockDatabase(g_hDbConn_Main);
        LogMessage("ERROR in MapCoords_ReGetCoord: %s", error);
        return;
    }

    // Get mapname.
    decl String:mapname[LEN_MAPCOORDS];
    GetCurrentMap(mapname, sizeof(mapname));

    // Bind parametrized input values into prepared statement(s).
    SQL_BindParamString(stmnt, 0, mapname, false);
    SQL_BindParamString(stmnt, 1, coordname, false);

    // Try executing prepared statement.
    if (!SQL_Execute(stmnt))
    {
        SQL_GetError(stmnt, error, sizeof(error));
        LogMessage("ERROR: Problem querying map coord for %s: %s", coordname, error);
        if (stmnt != INVALID_HANDLE)
            CloseHandle(stmnt);
        SQL_UnlockDatabase(g_hDbConn_Main);
        return;
    }

    // Do we have fetched results?
    if (stmnt == INVALID_HANDLE)
    {
        SQL_GetError(g_hDbConn_Main, error, sizeof(error));
        LogMessage("ERROR: The query statement handle was invalid for %s: %s", coordname, error);
        if (stmnt != INVALID_HANDLE)
            CloseHandle(stmnt);
        SQL_UnlockDatabase(g_hDbConn_Main);
        return;
    }

    // Get fetched row(s).
    new bool:gotRow = false;
    while(SQL_FetchRow(stmnt))
    {
        // Only 1 row should be returned.
        if (gotRow)
            continue;
        else
            gotRow = true;

        // Store the retrieved data.
        decl Float:teledata[4];
        /*
            teledata[0] = pos_x
            teledata[1] = pos_y
            teledata[2] = pos_z
            teledata[3] = horiz_angle
        */

        // Get pos_x
        teledata[0] = SQL_FetchFloat(stmnt, 0);

        // Get pos_y
        teledata[1] = SQL_FetchFloat(stmnt, 1);

        // Get pos_z
        teledata[2] = SQL_FetchFloat(stmnt, 2);

        // Get horiz_angle
        teledata[3] = SQL_FetchFloat(stmnt, 3);

        // Insert into coords Trie.
        SetTrieArray(g_hDbCoords, coordname, _:teledata, 4);
    }

    // Close handles and unlock DB.
    CloseHandle(stmnt);
    SQL_UnlockDatabase(g_hDbConn_Main);
    return;
}

MapCoords_ReGetRoom(const String:roomname[])
{
    // Make sure db is connected.
    if (g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in MapCoords_ReGetRoom: DB handle was invalid");
        return;
    }

    // Hold error.
    new String:error[255];

    // Lock database because using non-threaded query.
    SQL_LockDatabase(g_hDbConn_Main);

    // Prepare update statement.
    decl String:sql[] = "SELECT cp_x, cp_y, cp_z, length, width, height FROM maprooms WHERE mapname = ? AND roomname = ? LIMIT 1";
    new Handle:stmnt = INVALID_HANDLE;
    stmnt = SQL_PrepareQuery(g_hDbConn_Main, sql, error, sizeof(error));
    if (stmnt == INVALID_HANDLE)
    {
        SQL_UnlockDatabase(g_hDbConn_Main);
        LogMessage("ERROR in MapCoords_ReGetRoom: %s", error);
        return;
    }

    // Get mapname.
    decl String:mapname[LEN_MAPCOORDS];
    GetCurrentMap(mapname, sizeof(mapname));

    // Bind parametrized input values into prepared statement(s).
    SQL_BindParamString(stmnt, 0, mapname, false);
    SQL_BindParamString(stmnt, 1, roomname, false);

    // Try executing prepared statement.
    if (!SQL_Execute(stmnt))
    {
        SQL_GetError(stmnt, error, sizeof(error));
        LogMessage("ERROR: Problem querying map room for %s: %s", roomname, error);
        if (stmnt != INVALID_HANDLE) CloseHandle(stmnt);
        SQL_UnlockDatabase(g_hDbConn_Main);
        return;
    }

    // Do we have fetched results?
    if (stmnt == INVALID_HANDLE)
    {
        SQL_GetError(g_hDbConn_Main, error, sizeof(error));
        LogMessage("ERROR: The query statement handle was invalid for %s: %s", roomname, error);
        if (stmnt != INVALID_HANDLE)
            CloseHandle(stmnt);
        SQL_UnlockDatabase(g_hDbConn_Main);
        return;
    }

    // Get fetched row(s).
    new bool:gotRow = false;
    while(SQL_FetchRow(stmnt))
    {
        // Only 1 row should be returned.
        if (gotRow)
            continue;
        else
            gotRow = true;

        // Store the retrieved data.
        decl Float:roomdata[6];
        /*
            roomdata[0] = cp_x
            roomdata[1] = cp_y
            roomdata[2] = cp_z
            roomdata[3] = length
            roomdata[4] = width
            roomdata[5] = height
        */

        // Get cp_x
        roomdata[0] = SQL_FetchFloat(stmnt, 0);

        // Get cp_y
        roomdata[1] = SQL_FetchFloat(stmnt, 1);

        // Get cp_z
        roomdata[2] = SQL_FetchFloat(stmnt, 2);

        // Get length
        roomdata[3] = SQL_FetchFloat(stmnt, 3);

        // Get width
        roomdata[4] = SQL_FetchFloat(stmnt, 4);

        // Get Height
        roomdata[5] = SQL_FetchFloat(stmnt, 5);

        // Insert into rooms Trie.
        SetTrieArray(g_hDbRooms, roomname, _:roomdata, 6);
    }

    // Close handles and unlock DB.
    CloseHandle(stmnt);
    SQL_UnlockDatabase(g_hDbConn_Main);
    return;
}

bool:MapCoords_IsInRoomEz(entity, const String:RoomName[])
{
    // Using this over GetClientAbsOrigin because the entity to be tested
    // is probably going to be a gun, not a client.
    // But this will also work for clients.
    decl Float:TestLocation[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TestLocation);

    // Get location data for specified room.
    new Float:roomdata[6];
    if (!GetTrieArray(g_hDbRooms, RoomName, Float:roomdata, 6))
    {
        LogMessage("ERROR in in MapCoords_IsInRoomEz: No room data for %s", RoomName);
        return false;
    }
    else
    {
        // Room data.
        /*
            roomdata[0] = cp_x
            roomdata[1] = cp_y
            roomdata[2] = cp_z
            roomdata[3] = length
            roomdata[4] = width
            roomdata[5] = height
        */
        new Float:RoomCenterPoint[3];
        new Float:RoomDimensions[3];
        RoomCenterPoint[0] = roomdata[0];
        RoomCenterPoint[1] = roomdata[1];
        RoomCenterPoint[2] = roomdata[2];
        RoomDimensions[0] = roomdata[3];
        RoomDimensions[1] = roomdata[4];
        RoomDimensions[2] = roomdata[5];
        return MapCoords_IsInRoom(TestLocation, RoomCenterPoint, RoomDimensions);
    }
}

bool:MapCoords_CacheRoomInfo(const String:RoomName[], Float:RoomCenterPoint[3], Float:RoomDimensions[3])
{
    /*
        For checking lots of people, whether they are in a room, you *COULD* use
        MapCoords_IsInRoomEz() in a loop, but it would be bad for performance because
        it has to look up the same roomdata over and over again from the rooms Trie.

        Instead, for loops, use MapCoords_IsInRoom() directly for better performance.
        MapCoords_IsInRoom() expects a certain args to be passed to it containing the
        room's data.  This function will get those args for you.

        Usage:  Create two Float arrays, each 3 elements long.  Pass them to this
        function (along with the name of the room in question), and they will get
        filled with the right room data.

        Example usage:
        // Get test location.
        decl Float:TestLocation[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TestLocation);

        // Get and use room info.
        decl Float:RoomCenterPoint[3], Float:RoomDimensions[3];
        if (MapCoords_CacheRoomInfo("Room Name", RoomCenterPoint, RoomDimensions))
        {
            if (MapCoords_IsInRoom(TestLocation, RoomCenterPoint, RoomDimensions))
                // Entity is in room...
            else
                // Entity is not in room...
        }
        else
        {
            // Sorry, room info was not found...
        }
    */

    // Get location data for specified room.
    new Float:roomData[6];
    if (!GetTrieArray(g_hDbRooms, RoomName, Float:roomData, sizeof(roomData)))
    {
        LogMessage("ERROR in MapCoords_CacheRoomInfo: No room data for %s", RoomName);
        return false;
    }
    else
    {
        // Room data.
        /*
            roomData[0] = cp_x
            roomData[1] = cp_y
            roomData[2] = cp_z
            roomData[3] = length
            roomData[4] = width
            roomData[5] = height
        */
        PopulateVector(RoomCenterPoint, roomData[0], roomData[1], roomData[2]);
        PopulateVector(RoomDimensions, roomData[3], roomData[4], roomData[5]);
        return true;
    }
}

bool:MapCoords_IsInRoom(const Float:TestLocation[], const Float:RoomCenterPoint[], const Float:RoomDimensions[])
{
    /*
        Returns TRUE if TestLocation is inside the room.  Otherwise, FALSE.

        TestLocation needs to be a 3-element array:
            [0] = X
            [1] = Y
            [2] = Z
        RoomCenterPoint needs to be a 3-element array:
            [0] = X
            [1] = Y
            [2] = Z
        RoomDimensions needs to be a 3-element array:
            [0] = Length
            [1] = Width
            [2] = Height

        So if (for example) RoomCenterPoint[2] ("Z") was 0.0
        and RoomDimensions[2] ("Height") was 512.0,
        then you know the top of the room would be 256.0
        and the bottom of the room would be -256.0
    */

    // Hold common var.
    new Float:HalfDistance;

    // Compare X's
    HalfDistance = RoomDimensions[0] / 2;
    if (TestLocation[0] > (RoomCenterPoint[0] + HalfDistance)) return false;
    if (TestLocation[0] < (RoomCenterPoint[0] - HalfDistance)) return false;

    // Compare Y's
    HalfDistance = RoomDimensions[1] / 2;
    if (TestLocation[1] > (RoomCenterPoint[1] + HalfDistance)) return false;
    if (TestLocation[1] < (RoomCenterPoint[1] - HalfDistance)) return false;

    // Compare Z's
    // And apply a fix for TF2, because the map is 8 units down
    new Float:zAdd = g_iGame == GAMETYPE_TF2 ? 9.0 : 0.0;

    HalfDistance = RoomDimensions[2] / 2;
    if (TestLocation[2] > (RoomCenterPoint[2] + HalfDistance + zAdd)) return false;
    if (TestLocation[2] < (RoomCenterPoint[2] - HalfDistance - zAdd)) return false;

    // Test location is inside room.
    return true;
}

// ####################################################################################
// ################################## SQL CALLBACKS ###################################
// ####################################################################################

public MapCoords_GetCoords_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 10))
    {
        LogMessage("ERROR in MapCoords_GetFromDb_CB");
        return;
    }

    // Did the DB return results?
    new cnt;
    if (SQL_GetRowCount(fetch) <= 0)
    {
        LogMessage("NOTICE: No coordinates returned from DB for this map");
    }
    else
    {
        // Clear any existing coords.
        ClearTrie(g_hDbCoords);

        // (Re)Create the teleport destinations menu.
        Tele_RecreateDestinationsMenu();

        // Holders.
        decl String:coordname[LEN_MAPCOORDS];
        decl Float:teledata[4];
        /*
            teledata[0] = pos_x
            teledata[1] = pos_y
            teledata[2] = pos_z
            teledata[3] = horiz_angle
        */

        // Fetch each row.
        while(SQL_FetchRow(fetch))
        {
            cnt++;

            // Grab [coordname].
            SQL_FetchString(fetch, 0, coordname, sizeof(coordname));

            // Grab [pos_x].
            teledata[0] = SQL_FetchFloat(fetch, 1);

            // Grab [pos_y].
            teledata[1] = SQL_FetchFloat(fetch, 2);

            // Grab [pos_z].
            teledata[2] = SQL_FetchFloat(fetch, 3);

            // Grab [horiz_angle].
            teledata[3] = SQL_FetchFloat(fetch, 4);

            // Insert into coords Trie.
            SetTrieArray(g_hDbCoords, coordname, _:teledata, 4);

            // Debug.
            //LogMessage("COORD LOADED [%s]: X=%f, Y=%f, Z=%f, Ang=%f", coordname, teledata[0], teledata[1], teledata[2], teledata[3]);

            // Register it as a teleport destination.
            Tele_RegisterDestination(coordname);
        }
    }

    // This function can be called independently of initial db_connect by an admin in-game.
    new adminClient = GetClientOfUserId(_:data);
    if (adminClient > 0)
        PrintToChat(adminClient, "%s %i coords reloaded", MSG_PREFIX, cnt);
}

public MapCoords_GetRooms_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 11))
    {
        LogMessage("ERROR in MapCoords_GetRooms_CB");
        return;
    }

    // Did the DB return results?
    new cnt;
    if (SQL_GetRowCount(fetch) <= 0)
    {
        LogMessage("NOTICE: No rooms returned from DB for this map");
    }
    else
    {
        // Clear any existing coords.
        ClearTrie(g_hDbRooms);

        // (Re)Create the warday rooms menu.
        Warday_RecreateRoomsMenu();

        decl String:roomname[LEN_MAPCOORDS];
        decl Float:roomdata[6];
        /*
            roomdata[0] = cp_x
            roomdata[1] = cp_y
            roomdata[2] = cp_z
            roomdata[3] = length
            roomdata[4] = width
            roomdata[5] = height
        */

        // Fetch each row.
        while(SQL_FetchRow(fetch))
        {
            cnt++;

            // Get the name of the room
            SQL_FetchString(fetch, 0, roomname, sizeof(roomname));

            // Get cp_x
            roomdata[0] = SQL_FetchFloat(fetch, 1);

            // Get cp_y
            roomdata[1] = SQL_FetchFloat(fetch, 2);

            // Get cp_z
            roomdata[2] = SQL_FetchFloat(fetch, 3);

            // Get length
            roomdata[3] = SQL_FetchFloat(fetch, 4);

            // Get width
            roomdata[4] = SQL_FetchFloat(fetch, 5);

            // Get Height
            roomdata[5] = SQL_FetchFloat(fetch, 6);

            // Insert into rooms Trie.
            SetTrieArray(g_hDbRooms, roomname, _:roomdata, 6);

            // Register it as a warday area.
            new warday = SQL_FetchInt(fetch, 7);
            if (warday == 1)
                Warday_RegisterRoom(roomname);

            // Debug.
            //PrintToConsoleAll("ROOM LOADED [%s]: Warday: %d X=%f, Y=%f, Z=%f, L=%f, W=%f, H=%f", roomname, warday, roomdata[0], roomdata[1], roomdata[2], roomdata[3], roomdata[4], roomdata[5]);
        }

        // Cache admin room data for buy menu.
        BuyMenu_CacheAdminRoom();
    }

    // This function can be called independently of initial db_connect by an admin in-game.
    new adminClient = GetClientOfUserId(_:data);
    if (adminClient > 0)
        PrintToChat(adminClient, "%s %i Rooms reloaded", MSG_PREFIX, cnt);
}

public MapCoords_SetRoomData_Finish(Handle:main, Handle:hndl, const String:error[], any:data)
{
    decl String:roomName[MAX_NAME_LENGTH];
    decl String:update[128];

    ResetPack(data);

    new client = GetClientOfUserId(ReadPackCell(data));
    ReadPackString(data, roomName, sizeof(roomName));
    ReadPackString(data, update, sizeof(update));

    CloseHandle(data);

    if (StrEqual(error, ""))
    {
        if (client > 0)
        {
            PrintToChat(client, "%s Successfully updated room data for \x03%s", MSG_PREFIX, roomName);
            PrintToChat(client, "%s Updated: \x03%s", MSG_PREFIX, update);
        }
    }

    else
    {
        LogError(error);

        if (client > 0)
        {
            PrintToChat(client, "%s Error updating room data for \x03%s \x04 with update string \x03%s", MSG_PREFIX, roomName, update);
            PrintToChat(client, "%s Error String: \x03%s", MSG_PREFIX, error);
        }
    }
}

public MapCoords_Insert_Finish(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Holders.
    new client;
    decl String:coordname[LEN_MAPCOORDS * 2 + 1];
    new Float:teledata[4];
    /*
        teledata[0] = pos_x
        teledata[1] = pos_y
        teledata[2] = pos_z
        teledata[3] = horiz_angle
    */

    // Unpack data-pack.
    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, coordname, sizeof(coordname));
    teledata[0] = ReadPackFloat(data);
    teledata[1] = ReadPackFloat(data);
    teledata[2] = ReadPackFloat(data);
    teledata[3] = ReadPackFloat(data);

    // Finished with data-pack.
    CloseHandle(data);

    // Exit if unsuccessful.
    if ((conn == INVALID_HANDLE) || (fetch == INVALID_HANDLE))
    {
        LogMessage("ERROR in MapCoords_Insert_Finish: %s", error);
        return;
    }

    // Insert this successful coord into the Trie.
    SetTrieArray(g_hDbCoords, coordname, _:teledata, 4);

    // Success.
    PrintToChat(client, "%s Successfully inserted coord into DB", MSG_PREFIX);
}
