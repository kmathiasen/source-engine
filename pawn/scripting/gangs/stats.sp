
enum _:TopMenus
{
    /* Special Case */
    TM_OldestGangs = 0,

    /* Gang Based */
    TM_TopTotalGangSpent,
    TM_TopGangLevel,
    TM_TopGangPoints,
    TM_MostPerkChanges,
    TM_MostGangMembers,

    /* Player Based */
    TM_TopContributer,
    TM_TopCollector,
    TM_MostPointsSpent,
    TM_TopPoints
}

new iTopMenuStatus[TopMenus];
new Handle:hTopMenus[TopMenus];

new String:sTopMenuQuery[TopMenus][64];
new String:sTopMenuName[TopMenus][MAX_NAME_LENGTH];

/* ----- Events ----- */


stock Stats_OnPluginStart()
{
    sTopMenuName[TM_OldestGangs] = "Oldest Gangs";
    sTopMenuName[TM_TopTotalGangSpent] = "Most Points Spent (Gangs)";
    sTopMenuName[TM_TopGangLevel] = "Top Gang Level";
    sTopMenuName[TM_TopGangPoints] = "Top Gang Points";
    sTopMenuName[TM_MostPerkChanges] = "Most Perk Changes";
    sTopMenuName[TM_MostGangMembers] = "Most Gang Members";
    sTopMenuName[TM_TopContributer] = "Top Contributers";
    sTopMenuName[TM_TopCollector] = "Most Drugs Found";
    sTopMenuName[TM_MostPointsSpent] = "Most Points Spent";

    // Points and rep have been merged.
    //sTopMenuName[TM_TopPoints] = "Top Player Points";
    sTopMenuName[TM_TopPoints] = "Top Player Rep";

    sTopMenuQuery[TM_OldestGangs] = "created ASC";
    sTopMenuQuery[TM_TopTotalGangSpent] = "totalspent DESC";
    sTopMenuQuery[TM_TopGangLevel] = "level DESC";
    sTopMenuQuery[TM_TopGangPoints] = "rep DESC";
    sTopMenuQuery[TM_MostPerkChanges] = "perkschanged DESC";
    sTopMenuQuery[TM_MostGangMembers] = "membercount DESC";
    sTopMenuQuery[TM_TopContributer] = "contributed DESC";
    sTopMenuQuery[TM_TopCollector] = "totaldrugs DESC";
    sTopMenuQuery[TM_MostPointsSpent] = "totalspent DESC";
    sTopMenuQuery[TM_TopPoints] = "points DESC";

    RegConsoleCmd("sm_top", Command_TopMenu);

    GetTotalSQLKeys();
    
    /* Global Stats Menu */
    hGlobalStatsMenu = CreateMenu(GlobalStatsMenuSelect);
    SetMenuTitle(hGlobalStatsMenu, "Global Stats");
    
    for (new i = 0; i < TopMenus; i++)
        AddMenuItem(hGlobalStatsMenu, "", sTopMenuName[i]);

    SetMenuExitBackButton(hGlobalStatsMenu, true);
}

Stats_OnRoundStart()
{
    for (new i = 0; i < TopMenus; i++)
    {
        if (hTopMenus[i] != INVALID_HANDLE)
        {
            CloseHandle(hTopMenus[i]);
            hTopMenus[i] = INVALID_HANDLE;
        }

        if (iTopMenuStatus[i] == MENU_CREATED)
            iTopMenuStatus[i] = MENU_NOT_CREATED;
    }
}

/* ----- Functions ----- */


stock CreateGangInfoMenus()
{
    if (hGangByNameInfo != INVALID_HANDLE)
        CloseHandle(hGangByNameInfo);

    if (hGangByOwnerInfo != INVALID_HANDLE)
        CloseHandle(hGangByOwnerInfo);

    hGangByNameInfo = CreateMenu(TellGangInfoSelect);
    SetMenuTitle(hGangByNameInfo, "Gangs By Name");
    SetMenuExitBackButton(hGangByNameInfo, true);

    hGangByOwnerInfo = CreateMenu(TellGangInfoSelect);
    SetMenuTitle(hGangByOwnerInfo, "Gangs By Owner");
    SetMenuExitBackButton(hGangByOwnerInfo, true);

    SQL_TQuery(hDrugDB, AddGangToInfoCallback,
               "SELECT ownersteamid, name FROM gangs ORDER BY name", 0);

    SQL_TQuery(hDrugDB, AddGangToInfoCallback,
               "SELECT ownersteamid, ownername FROM gangs ORDER BY ownername",
               1);    
}

stock ConstructTopGangMenu(menukey,
                           const String:select[], const String:orderby[],
                           client, bool:exception=false)
{
    decl String:query[256];
    new Handle:hData = CreateDataPack();

    decl String:newSelect[128];
    strcopy(newSelect, sizeof(newSelect), select);

    ReplaceString(newSelect, sizeof(newSelect), " DESC", "", false);
    ReplaceString(newSelect, sizeof(newSelect), " ASC", "", false);

    WritePackCell(hData, menukey);
    WritePackCell(hData, client);
    WritePackCell(hData, exception);

    Format(query, sizeof(query),
           "SELECT name, ownername, level, membercount, %s FROM gangs ORDER BY %s LIMIT 10",
           newSelect, orderby);

    SQL_TQuery(hDrugDB, ConstructTopGangMenuCallback, query, hData);
}

stock ConstructTopPlayerMenu(menukey,
                             const String:select[], const String:orderby[],
                             client)
{
    decl String:query[256];
    new Handle:hData = CreateDataPack();

    decl String:newSelect[128];
    strcopy(newSelect, sizeof(newSelect), select);

    ReplaceString(newSelect, sizeof(newSelect), " DESC", "", false);
    ReplaceString(newSelect, sizeof(newSelect), " ASC", "", false);

    WritePackCell(hData, menukey);
    WritePackCell(hData, client);

    Format(query, sizeof(query),
           "SELECT gang, name, %s FROM playerdata ORDER BY %s LIMIT 10",
           newSelect, orderby);

    SQL_TQuery(hDrugDB, ConstructTopPlayerMenuCallback, query, hData);
}

stock TellPlayerStats(client, const String:steamid[])
{
    new data[PlayerData];
    if (!GetTrieArray(hPlayerData, steamid, data, PlayerData))
    {
        TellPlayerStatsOffline(client, steamid);
        return;
    }

    new target = FindClientFromSteamid(steamid);
    new Handle:hTempStatsMenu = CreatePanel();

    decl String:temp[64];
    GetClientName(target, temp, sizeof(temp));

    Format(temp, sizeof(temp), "Stats for %s", temp);
    SetPanelTitle(hTempStatsMenu, temp);

    Format(temp, sizeof(temp),
           "Total Points Spent - %d", data[PD_TotalSpent]);
    DrawPanelItem(hTempStatsMenu, temp);

    Format(temp, sizeof(temp),
           "Total Drugs Found - %d", data[PD_TotalDrugs]);
    DrawPanelItem(hTempStatsMenu, temp);

    Format(temp, sizeof(temp),
           "Points To Current Gang - %d", data[PD_Contributed]);
    DrawPanelItem(hTempStatsMenu, temp);

    Format(temp, sizeof(temp),
           //"Current Points - %i", data[PD_Points]);
           "Current Points - %d", PrisonRep_GetPoints(target));
    DrawPanelItem(hTempStatsMenu, temp);

    Format(temp, sizeof(temp), "Gang - %s", sCacheGang[target]);
    DrawPanelItem(hTempStatsMenu, temp);

    SendPanelToClient(hTempStatsMenu, client, emptyMenuSelect, DEFAULT_TIMEOUT);

    CloseHandle(hTempStatsMenu);
    hTempStatsMenu = INVALID_HANDLE;

    TellPlayerRank(client, steamid, data[PD_Points] + data[PD_TotalSpent]);
}

stock TellPlayerStatsOffline(client, const String:steamid[])
{
    decl String:query[256];

    Format(query, sizeof(query),
           "SELECT totalspent, totaldrugs, contributed, points, name, steamid, gang, totalspent FROM playerdata WHERE STEAMID = '%s'",
           steamid);

    SQL_TQuery(hDrugDB,
               TellPlayerStatsCallback, query, GetClientUserIdSafe(client));
}

stock TellPlayerRank(client, const String:steamid[], minPoints)
{
    new Handle:pack = CreateDataPack();
    decl String:query[256];

    WritePackCell(pack, GetClientUserIdSafe(client));
    WritePackString(pack, steamid);

    Format(query, sizeof(query),
           "SELECT steamid FROM playerdata WHERE (points + totalspent) >= %i ORDER BY points + totalspent DESC",
           minPoints);

    SQL_TQuery(hDrugDB, TellPlayerRankCallback, query, pack);
}

stock ShowTopMenu(client, menukey)
{
    switch (iTopMenuStatus[menukey])
    {
        case MENU_NOT_CREATED:
        {
            if (menukey == TM_OldestGangs)
                ConstructTopGangMenu(menukey,
                                     sTopMenuQuery[menukey],
                                     sTopMenuQuery[menukey],
                                     GetClientUserIdSafe(client),
                                     true);

            else if (menukey <= TM_MostGangMembers)
                ConstructTopGangMenu(menukey,
                                     sTopMenuQuery[menukey],
                                     sTopMenuQuery[menukey],
                                     GetClientUserIdSafe(client));

            else
                ConstructTopPlayerMenu(menukey,
                                       sTopMenuQuery[menukey],
                                       sTopMenuQuery[menukey],
                                       GetClientUserIdSafe(client));

            iTopMenuStatus[menukey] = MENU_BEING_CREATED;
        }

        // To do
        // debug
        // Create a timer for that player to continuously try and send that menu

        case MENU_BEING_CREATED:
        {
        
        }

        case MENU_CREATED:
            DisplayMenu(hTopMenus[menukey], client, DEFAULT_TIMEOUT);
    }
}

stock GetTotalSQLKeys()
{
    SQL_TQuery(hDrugDB,
               GetTotalSQLKeysCallback, "SELECT steamid FROM playerdata");
}


/* ----- Menus ----- */


public TellGangInfoSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    if (action != MenuAction_Select)
        return;

    decl String:steamid[32];
    GetMenuItem(menu, selected, steamid, sizeof(steamid));

    DisplayGangInfo(client, steamid);
}

public GlobalStatsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    if (action != MenuAction_Select)
        return;

    // points and rep have been merged.
    // So use JB AIO's top menu if they select "top player points".
    if (selected == TM_TopPoints)
        FakeClientCommand(client, "repstats");

    else
        ShowTopMenu(client, selected);
}

public TopMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hGlobalStatsMenu, client, DEFAULT_TIMEOUT);

    if (action == MenuAction_Select)
    {
        decl String:text[256];
        GetMenuItem(menu, selected, text, sizeof(text));

        PrintToChat(client, text);
    }
}

/* ----- Commands ----- */


public Action:Command_TopMenu(client, args)
{
    ShowTopMenu(client, TM_TopPoints);
    return Plugin_Handled;
}


/* ----- Callbacks ----- */


public TellPlayerStatsCallback(Handle:hGang, Handle:hndl,
                               const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl) && IsClientInGame(client))
    {
        new Handle:hTempStatsMenu = CreatePanel();
        new points = SQL_FetchInt(hndl, 3);
        new totalspent = SQL_FetchInt(hndl, 7);

        decl String:steamid[32];
        decl String:temp[64];
        decl String:sGangName[MAX_NAME_LENGTH];

        SQL_FetchString(hndl, 5, steamid, sizeof(steamid));
        SQL_FetchString(hndl, 4, temp, sizeof(temp));
        SQL_FetchString(hndl, 6, sGangName, sizeof(sGangName));

        Format(temp, sizeof(temp), "Stats for %s", temp);
        SetPanelTitle(hTempStatsMenu, temp);

        Format(temp, sizeof(temp),
               "Total Points Spent - %d", SQL_FetchInt(hndl, 0));
        DrawPanelItem(hTempStatsMenu, temp);

        Format(temp, sizeof(temp),
               "Total Drugs Found - %d", SQL_FetchInt(hndl, 1));
        DrawPanelItem(hTempStatsMenu, temp);

        Format(temp, sizeof(temp),
               "Points To Current Gang - %d", SQL_FetchInt(hndl, 2));
        DrawPanelItem(hTempStatsMenu, temp);

        Format(temp, sizeof(temp),
               "Current Points - %d", points);
        DrawPanelItem(hTempStatsMenu, temp);

        Format(temp, sizeof(temp), "Gang - %s", sGangName);
        DrawPanelItem(hTempStatsMenu, temp);

        SendPanelToClient(hTempStatsMenu, client, emptyMenuSelect, DEFAULT_TIMEOUT);

        CloseHandle(hTempStatsMenu);
        hTempStatsMenu = INVALID_HANDLE;

        TellPlayerRank(client, steamid, points + totalspent);
    }

    else
        PrintToChat(client,
                    "\x03[Gangs]:\x01 That player hasn't found any drugs yet");
}

public AddGangToInfoCallback(Handle:hGang,
                             Handle:hndl, const String:error[], any:menu)
{
    while (SQL_FetchRow(hndl))
    {
        decl String:steamid[32];
        SQL_FetchString(hndl, 0, steamid, sizeof(steamid));

        decl String:name[MAX_NAME_LENGTH];
        SQL_FetchString(hndl, 1, name, sizeof(name));

        AddMenuItem(menu ? hGangByOwnerInfo : hGangByNameInfo, steamid, name);
    }
}

public ConstructTopGangMenuCallback(Handle:hGang, Handle:hndl,
                                    const String:error[], any:hData)
{
    ResetPack(hData);

    new menukey = ReadPackCell(hData);
    new client = GetClientOfUserId(ReadPackCell(hData));
    new exception = ReadPackCell(hData);

    hTopMenus[menukey] = CreateMenu(TopMenuSelect);
    SetMenuTitle(hTopMenus[menukey], sTopMenuName[menukey]);
    SetMenuExitBackButton(hTopMenus[menukey], true);

    decl String:sGangName[MAX_NAME_LENGTH];
    decl String:sOwnerName[MAX_NAME_LENGTH];
    decl String:sDisplay[48];
    decl String:sChatMessage[256];

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(hTopMenus[menukey], "",
                    "No Stats For This Key", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));
        SQL_FetchString(hndl, 1, sOwnerName, sizeof(sOwnerName));

        new last = SQL_FetchInt(hndl, 4);
        decl String:lastDisplay[32];

        if (exception)
        {
            new minutes = (GetTime() - last) / 60;
            new hours = minutes / 60;
            new days = hours / 24;

            minutes %= 60;
            hours %= 24;

            Format(lastDisplay, sizeof(lastDisplay),
                   "%02d:%02d:%02d", days, hours, minutes);
        }

        else
            Format(lastDisplay, sizeof(lastDisplay), "%d", last);

        Format(sDisplay, sizeof(sDisplay), "%s - %s", sGangName, lastDisplay);
        Format(sChatMessage, sizeof(sChatMessage),
               "%s \x04%s\x01 is owned by \x04%s\x01 has \x04%i\x01 member(s) and is level \x04%i",
               MSG_PREFIX, sGangName, sOwnerName,
               SQL_FetchInt(hndl, 3), SQL_FetchInt(hndl, 2));

        AddMenuItem(hTopMenus[menukey], sChatMessage, sDisplay);
    }

    if (client)
        DisplayMenu(hTopMenus[menukey], client, DEFAULT_TIMEOUT);

    CloseHandle(hData);
    iTopMenuStatus[menukey] = MENU_CREATED;
}

public ConstructTopPlayerMenuCallback(Handle:hGang, Handle:hndl,
                                      const String:error[], any:hData)
{
    new points;
    ResetPack(hData);

    new menukey = ReadPackCell(hData);
    new client = GetClientOfUserId(ReadPackCell(hData));

    hTopMenus[menukey] = CreateMenu(TopMenuSelect);
    SetMenuTitle(hTopMenus[menukey], sTopMenuName[menukey]);
    SetMenuExitBackButton(hTopMenus[menukey], true);

    decl String:sGangName[32];
    decl String:name[MAX_NAME_LENGTH];
    decl String:text[128];
    decl String:display[40];

    if (!SQL_GetRowCount(hndl))
        AddMenuItem(hTopMenus[menukey], "",
                    "No Stats For This Key", ITEMDRAW_DISABLED);

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, sGangName, sizeof(sGangName));
        SQL_FetchString(hndl, 1, name, sizeof(name));
        points = SQL_FetchInt(hndl, 2);

        if (StrEqual(sGangName, "None"))
            Format(text, sizeof(text),
                   "%s \x04%s\x01 is not part of a gang", MSG_PREFIX, name);

        else
            Format(text, sizeof(text),
                   "%s \x04%s\x01 is part of the \x04%s\x01 gang",
                   MSG_PREFIX, name, sGangName);

        Format(display, sizeof(display), "%s - %i", name, points);
        AddMenuItem(hTopMenus[menukey], text, display);
    }

    if (client)
        DisplayMenu(hTopMenus[menukey], client, DEFAULT_TIMEOUT);

    CloseHandle(hData);
    iTopMenuStatus[menukey] = MENU_CREATED;
}

public TellPlayerRankCallback(Handle:hGang, Handle:hndl,
                              const String:error[], any:pack)
{
    new client, i;
    decl String:steamid[32];
    decl String:compareSteamid[32];

    ResetPack(pack);
    client = GetClientOfUserId(ReadPackCell(pack));

    ReadPackString(pack, steamid, sizeof(steamid));
    CloseHandle(pack);

    if (!client)
        return;

    while (SQL_FetchRow(hndl))
    {
        i++;
        SQL_FetchString(hndl, 0, compareSteamid, sizeof(compareSteamid));

        if (StrEqual(steamid, compareSteamid))
        {
            PrintToChat(client,
                        "\x03[Gangs]: \x01Player is ranked \x03[%i/%i]", 
                        i, totalSQLKeys);
            break;
        }
    }
}

public GetTotalSQLKeysCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:data)
{
    totalSQLKeys = SQL_GetRowCount(hndl);
}
