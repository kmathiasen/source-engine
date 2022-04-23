
/* ----- Events ----- */


stock GangInfo_OnPluginStart()
{
    hGangInfo = CreateMenu(GangInfoSelect);
    SetMenuTitle(hGangInfo, "Select Gang Order Type");
    SetMenuExitBackButton(hGangInfo, true);

    AddMenuItem(hGangInfo, "", "Order By Gang");
    AddMenuItem(hGangInfo, "", "Order By Owner");
}

/* ----- Functions ----- */


stock DisplayGangInfo(client, const String:steamid[])
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT name, rep, level, membercount, perk, totalspent, created, perkschanged, ownername FROM gangs WHERE ownersteamid = '%s'",
           steamid);

    SQL_TQuery(hDrugDB,
               DisplayGangInfoCallback, query, GetClientUserIdSafe(client));
}


/* ----- Menus ----- */


public GangInfoSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
        DisplayMenu(hMainMenu, client, DEFAULT_TIMEOUT);

    if (action != MenuAction_Select)
        return;

    switch (selected + 1)
    {
        /* Order By Gang */
        case 1:
            DisplayMenu(hGangByNameInfo, client, DEFAULT_TIMEOUT);

        /* Order By Owner */
        case 2:
            DisplayMenu(hGangByOwnerInfo, client, DEFAULT_TIMEOUT);
    }
}

public TempGangInfoSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hGangInfo, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:name[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, name, sizeof(name));

            if (StrEqual("", name))
                return;

            decl String:query[256];
            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];

            SQL_EscapeString(hDrugDB, name, sNewName, sizeof(sNewName));
            Format(query, sizeof(query),
                   "SELECT name, steamid FROM playerdata WHERE gang = '%s' ORDER BY name",
                   sNewName);

            SQL_TQuery(hDrugDB, ShowMemberListCallback, query, GetClientUserIdSafe(client));
        }
    }
}

public GangMembersSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hGangInfo, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:steamid[32];
            GetMenuItem(menu, selected, steamid, sizeof(steamid));

            TellPlayerStats(client, steamid);
        }
    }
}


/* ----- Callbacks ---- */


public ShowMemberListCallback(Handle:hGang,
                              Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    new Handle:menu = CreateMenu(GangMembersSelect);

    SetMenuTitle(menu, "Gang Members");
    SetMenuExitBackButton(menu, true);

    while (SQL_FetchRow(hndl))
    {
        decl String:steamid[32];
        decl String:name[MAX_NAME_LENGTH];

        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 1, steamid, sizeof(steamid));

        AddMenuItem(menu, steamid, name);
    }

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public DisplayGangInfoCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    if (SQL_FetchRow(hndl))
    {
        decl String:perk[64];
        decl String:ownername[MAX_NAME_LENGTH];
        decl String:name[MAX_NAME_LENGTH];
        decl String:display[MAX_NAME_LENGTH * 2];
        decl String:date[MAX_NAME_LENGTH];

        new rep = SQL_FetchInt(hndl, 1);
        new level = SQL_FetchInt(hndl, 2);
        new membercount = SQL_FetchInt(hndl, 3);
        new totalspent = SQL_FetchInt(hndl, 5);
        new created = SQL_FetchInt(hndl, 6);
        new perkschanged = SQL_FetchInt(hndl, 7);

        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 4, perk, sizeof(perk));
        SQL_FetchString(hndl, 8, ownername, sizeof(ownername));

        new Handle:menu = CreateMenu(TempGangInfoSelect);
        SetMenuExitBackButton(menu, true);

        Format(display, sizeof(display), "Gang Info For %s", name);
        SetMenuTitle(menu, display);

        Format(display, sizeof(display), "Gang Points - %d", rep);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Level - %d", level);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Member Count - %d", membercount);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Total Spent - %d", totalspent);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Perk - %s", perk);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Owner - %s", ownername);
        AddMenuItem(menu, "", display);

        Format(display, sizeof(display), "Perks Changed - %d", perkschanged);
        AddMenuItem(menu, "", display);

        FormatTime(date, sizeof(date), "%c", created);
        Format(display, sizeof(display), "Created - %s", date);
        AddMenuItem(menu, "", display);

        AddMenuItem(menu, name, "Members");
        DisplayMenu(menu, client, DEFAULT_TIMEOUT);
    }
}
