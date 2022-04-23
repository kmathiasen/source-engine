
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

new Handle:hStatsMenu = INVALID_HANDLE;
new Handle:hCurrentPlayers = INVALID_HANDLE;
new Handle:hTopTen = INVALID_HANDLE;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

Stats_OnPluginStart()
{
    RegConsoleCmd("repstats", Command_ShowStatsMenu, "Shows the 'stats menu'");
    RegConsoleCmd("toprep", Command_ShowTopMenu, "Shows the Top Players rep menu");
    RegConsoleCmd("playerrep", Command_ShowPlayersMenu, "Shows everyone's rep");
}

Stats_OnDBConnect(Handle:conn)
{
    /***** This func is called roughly once per round (right after LR or Last Guard) *****/

    // Create a default styled, main stats menu.
    hStatsMenu = CreateMenu(StatsMenuSelect);
    SetMenuTitle(hStatsMenu, "Rep Stats");

    // Populate the menu with our options.
    AddMenuItem(hStatsMenu, "", "Top Players");
    AddMenuItem(hStatsMenu, "", "Current Players");

    /***** Create all the stats menu. *****/

    // Avoid constant memory leaks
    if (hCurrentPlayers != INVALID_HANDLE)
        CloseHandle(hCurrentPlayers);

    if (hTopTen != INVALID_HANDLE)
        CloseHandle(hTopTen);

    hCurrentPlayers = CreateMenu(CurrentPlayersSelect);
    SetMenuTitle(hCurrentPlayers, "Current Players Rep");

    // Create a back (option 8) button, that will take the client back to the main menu.
    SetMenuExitBackButton(hCurrentPlayers, true);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        new rep = PrisonRep_GetPoints(i);
        decl String:display[MAX_NAME_LENGTH + LEN_INTSTRING + 3];

        // Format in the form of name - rep
        Format(display, sizeof(display), "%N - %d", i, rep);

        // Add the player to the current players menu, and pass no data.
        AddMenuItem(hCurrentPlayers, "", display);
    }

    hTopTen = CreateMenu(TopTenSelect);
    SetMenuTitle(hTopTen, "Top Players");
    SetMenuExitBackButton(hTopTen, true);

    // Select the top X players (based on points).
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT points, ingamename FROM %s ORDER BY points DESC LIMIT %i",
           g_sRepTableName, GetConVarInt(g_hCvTopRepPlayersToQuery));
    SQL_TQuery(conn, PopulateTopPlayers_Finish, query);
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_ShowStatsMenu(client, args)
{
    DisplayMenu(hStatsMenu, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Continue;
}

public Action:Command_ShowTopMenu(client, args)
{
    DisplayMenu(hTopTen, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Continue;
}

public Action:Command_ShowPlayersMenu(client, args)
{
    DisplayMenu(hCurrentPlayers, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Continue;
}

// ####################################################################################
// ################################# MENU CALLBACKS ###################################
// ####################################################################################

public StatsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    // They selected a valid option (not 0/exit).
    if (action == MenuAction_Select)
    {
        switch (selected + 1)
        {
            // Top 10
            case 1:
                DisplayMenu(hTopTen, client, MENU_TIMEOUT_NORMAL);

            // Current Players
            case 2:
                DisplayMenu(hCurrentPlayers, client, MENU_TIMEOUT_NORMAL);
        }
    }
}

public CurrentPlayersSelect(Handle:menu, MenuAction:action, client, selected)
{
    // They pressed 8 (back), so resend the main menu.
    if  (selected == MenuCancel_ExitBack)
        DisplayMenu(hStatsMenu, client, MENU_TIMEOUT_NORMAL);

    // They pressed a valid option (not exit or back)
    else if (action == MenuAction_Select)
    {
        // Currently I have no plans to display anything, so just resend the menu.
        DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
    }
}

public TopTenSelect(Handle:menu, MenuAction:action, client, selected)
{
    if  (selected == MenuCancel_ExitBack)
        DisplayMenu(hStatsMenu, client, MENU_TIMEOUT_NORMAL);

    else if (action == MenuAction_Select)
        DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public PopulateTopPlayers_Finish(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Exit if unsuccessful.
    if ((conn == INVALID_HANDLE) || (fetch == INVALID_HANDLE))
    {
        LogMessage("ERROR in PopulateTopPlayers_Finish: %s", error);
        AddMenuItem(hTopTen, "", "No Players Found", ITEMDRAW_DISABLED);
        return;
    }

    // Did the DB return results?
    if (SQL_GetRowCount(fetch) <= 0)
    {
        LogMessage("NOTICE: No Top Players returned from DB");
        AddMenuItem(hTopTen, "", "No Players Found", ITEMDRAW_DISABLED);
    }
    else
    {
        while (SQL_FetchRow(fetch))
        {
            decl String:name[MAX_NAME_LENGTH];
            decl String:display[MAX_NAME_LENGTH + LEN_INTSTRING + 3];

            new rep = SQL_FetchInt(fetch, 0);
            SQL_FetchString(fetch, 1, name, sizeof(name));

            Format(display, sizeof(display), "%s - %d", name, rep);
            AddMenuItem(hTopTen, "", display);
        }
    }
}
