
new Handle:g_hGangTrailEnabledCookie = INVALID_HANDLE;
new Handle:g_hGangTrailsTrie = INVALID_HANDLE;
new Handle:g_hGangTrailsEnabledTrie = INVALID_HANDLE;

new bool:g_bGangTrailEnabled[MAXPLAYERS + 1];


/* ----- Events ----- */


public Trails_OnPluginStart()
{
    g_hGangTrailEnabledCookie = RegClientCookie("hg_gangs_trail_enabled",
                                                "Enable your gang trail, if your gang has one",
                                                CookieAccess_Public);

    g_hGangTrailsTrie = CreateTrie();
    g_hGangTrailsEnabledTrie = CreateTrie();
}

public Trails_OnConfigsExecuted()
{
    decl String:query[256];

    Format(query, sizeof(query),
           "SELECT trailenabled, name, trail FROM gangs WHERE membercount >= %d AND level >= %d",
           GetConVarInt(hMinMembersForTrails),
           GetConVarInt(hMinLevelForTrails));

    SQL_LockDatabase(hDrugDB);
    new Handle:hndl = SQL_Query(hDrugDB, query);

    if (hndl != INVALID_HANDLE)
    {
        while (SQL_FetchRow(hndl))
        {
            new trailenabled = SQL_FetchInt(hndl, 0);

            decl String:gang[MAX_NAME_LENGTH];
            decl String:trail[PLATFORM_MAX_PATH];

            SQL_FetchString(hndl, 1, gang, sizeof(gang));
            SQL_FetchString(hndl, 2, trail, sizeof(trail));

            SetTrieString(g_hGangTrailsTrie, gang, trail);
            SetTrieValue(g_hGangTrailsEnabledTrie, gang, trailenabled);

            decl String:base[PLATFORM_MAX_PATH];
            Format(base, sizeof(base), trail);

            ReplaceString(base, sizeof(base), ".vmt", "", false);

            decl String:VMT[PLATFORM_MAX_PATH];
            decl String:VTF[PLATFORM_MAX_PATH];

            Format(VMT, sizeof(VMT), "%s.vmt", base);
            Format(VTF, sizeof(VTF), "%s.vtf", base);

            if (FileExists(VMT))
            {
                AddFileToDownloadsTable(VMT);
                AddFileToDownloadsTable(VTF);
            }
        }

        CloseHandle(hndl);
    }

    else
    {
        decl String:error[256];
        SQL_GetError(hDrugDB, error, sizeof(error));

        LogError(error);
    }

    SQL_UnlockDatabase(hDrugDB);
}

public Trails_OnDBConnect()
{
    SQL_TQuery(hDrugDB, EmptyCallback, "ALTER TABLE gangs ADD COLUMN trail TEXT");
    SQL_TQuery(hDrugDB, EmptyCallback, "ALTER TABLE gangs ADD COLUMN trailenabled INTEGER");
}

public Trails_OnClientPutInServer(client)
{
    g_bGangTrailEnabled[client] = false;
}

public Trails_OnClientFullyAuthorized(client)
{
    decl String:cookie[3];
    GetClientCookie(client, g_hGangTrailEnabledCookie, cookie, sizeof(cookie));

    g_bGangTrailEnabled[client] = StrEqual(cookie, "1");
}

public Trails_OnPlayerSpawn(client)
{
    decl String:trail[PLATFORM_MAX_PATH];
    new enabled;

    if (!GetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], enabled))
        return;

    GetTrieString(g_hGangTrailsTrie, sCacheGang[client], trail, sizeof(trail));

    if (StrEqual(trail, "Request Accepted"))
    {
        PrintToChat(client, "%s Your gang's trail request is currently in progress", MSG_PREFIX);
        return;
    }

    else if (!enabled)
    {
        PrintToChat(client, "%s Your gang has a trail, but the leader has chosen to disable it", MSG_PREFIX);
        return;
    }

    else if (!g_bGangTrailEnabled[client])
        return;

    else if (StrEqual(trail, ""))
        return;

    else if (!FileExists(trail))
    {
        LogError("Trail '%s' for gang '%s' is set, but does not exist on the server", trail, sCacheGang[client]);
        return;
    }

    new pointsdrain = GetConVarInt(hTrailDrainGangPoints);
    new repdrain = GetConVarInt(hTrailDrainRep);

    if (GetPoints(client) < repdrain)
    {
        PrintToChat(client,
                    "%s Your gang trail was not enabled this round because you do not have \x04%d\x01 rep",
                    MSG_PREFIX, repdrain);
        return;
    }

    if (GetRepByGang(sCacheGang[client]) < pointsdrain)
    {
        PrintToChat(client,
                    "%s Your gang trail was not enabled because your gang bank is empty",
                    MSG_PREFIX);

        PrintToChat(client,
                    "%s Type \x04!donate <amount>\x01 in chat to top it off",
                    MSG_PREFIX);

        return;
    }

    AddRepByGang(sCacheGang[client], -pointsdrain);
    AddPoints(client, -pointsdrain);

    if (LibraryExists("hg_premium"))
    {
        Premium_OverrideTrail(client, trail);
    }
}


/* ----- Menus ----- */


stock Trails_OwnerTrailMainMenu(client)
{
    new Handle:menu = CreateMenu(OwnerTrailMainMenuSelect);
    new enabled;

    new String:trail[PLATFORM_MAX_PATH];

    SetMenuTitle(menu, "Trails Menu");
    SetMenuExitBackButton(menu, true);

    if (GetTrieString(g_hGangTrailsTrie, sCacheGang[client], trail, sizeof(trail)) &&
        StrEqual(trail, "Request Accepted"))
        AddMenuItem(menu, "", "REQUEST IN PROGRESS", ITEMDRAW_DISABLED);

    else if (GetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], enabled) && enabled)
        AddMenuItem(menu, "disable", "Disable Trails For Your Gang");

    else
        AddMenuItem(menu, "enable", "Enable Trails For Your Gang");

    if (StrEqual(trail, "Request Accepted"))
        AddMenuItem(menu, "", "REQUEST IN PROGRESS", ITEMDRAW_DISABLED);

    else
        AddMenuItem(menu, "request", "Request Trail");

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public OwnerTrailMainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                DisplayMenu(hGangOptionsMenu, client, DEFAULT_TIMEOUT);
        }

        case MenuAction_Select:
        {
            decl String:choice[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, choice, sizeof(choice));

            decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
            SQL_EscapeString(hDrugDB, sCacheGang[client], sNewName, sizeof(sNewName));

            /* Enable Trails For Your Gang */
            if (StrEqual(choice, "enable"))
            {
                decl String:dummy[2];
                decl String:query[256];

                if (GetTrieString(g_hGangTrailsTrie, sCacheGang[client], dummy, sizeof(dummy)) && !StrEqual(dummy, ""))
                {
                    Format(query, sizeof(query), "UPDATE gangs SET trailenabled = 1 WHERE name = '%s'", sNewName);
                    SetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], 1);
                    SQL_TQuery(hDrugDB, EmptyCallback, query);

                    PrintToChat(client, "%s You have \x04enabled\x01 your gang trail", MSG_PREFIX);
                    Trails_OwnerTrailMainMenu(client);
                }

                else
                {
                    PrintToChat(client, "%s Your gang does not own a trail", MSG_PREFIX);
                    PrintToChat(client, "%s Select \x04Request Trail\x01 for information on elligibility", MSG_PREFIX);

                    Trails_OwnerTrailMainMenu(client);
                }
            }

            /* Disable Trails For Your Gang */
            else if (StrEqual(choice, "disable"))
            {
                decl String:query[256];
                Format(query, sizeof(query), "UPDATE gangs SET trailenabled = 0 WHERE name = '%s'", sNewName);

                SetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], 0);
                SQL_TQuery(hDrugDB, EmptyCallback, query);

                PrintToChat(client, "%s You have \x04disabled\x01 your gang trail", MSG_PREFIX);
                Trails_OwnerTrailMainMenu(client);
            }

            /* Request Trail */
            else if (StrEqual(choice, "request"))
            {
                new dummy;
                if (!GetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], dummy))
                {
                    PrintToChat(client, "%s Your gang is not elligible for a gang trail", MSG_PREFIX);
                    PrintToChat(client,
                                "%s You must be level \x04%d\x01 and have at least \x04%d\x01 members",
                                MSG_PREFIX, GetConVarInt(hMinLevelForTrails), GetConVarInt(hMinMembersForTrails));

                    Trails_OwnerTrailMainMenu(client);
                    return;
                }

                new Handle:menu2 = CreateMenu(Trails_ConfirmRequest1);
                decl String:display[32];

                SetMenuTitle(menu2, "Trail Costs");
                SetMenuExitBackButton(menu, true);

                AddMenuItem(menu2, "", "Per Round = PR", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", "Per Person = PP", ITEMDRAW_DISABLED);

                Format(display, sizeof(display), "    %d", GetConVarInt(hTrailDrainRep));

                AddMenuItem(menu2, "", "Player Rep Drain (PR)", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", display, ITEMDRAW_DISABLED);

                Format(display, sizeof(display), "    %d", GetConVarInt(hTrailDrainGangPoints));

                AddMenuItem(menu2, "", "Gang Points Drain (PP PR)", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", display, ITEMDRAW_DISABLED);

                Format(display, sizeof(display), "    %d", GetConVarInt(hTrailRequestCost));

                AddMenuItem(menu2, "", "Cost (Gang Points) To Request", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", display, ITEMDRAW_DISABLED);

                AddMenuItem(menu2, "", "Typical Request Time", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", "   1-14 Days", ITEMDRAW_DISABLED);

                AddMenuItem(menu2, "", "Read First", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", "   http://goo.gl/bcIIoB", ITEMDRAW_DISABLED);

                AddMenuItem(menu2, "", " ", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "purchase", "Purchase Trail");

                DisplayMenu(menu2, client, DEFAULT_TIMEOUT);
            }
        }
    }
}

public Trails_ConfirmRequest1(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                Trails_OwnerTrailMainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:chosen[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, chosen, sizeof(chosen));

            if (StrEqual(chosen, "purchase"))
            {
                new Handle:menu2 = CreateMenu(Trails_ConfirmRequest2);

                SetMenuTitle(menu2, "Are You Sure?");
                SetMenuExitBackButton(menu2, true);

                decl String:display[32];
                Format(display, sizeof(display), "Cost = %d Gang Points", GetConVarInt(hTrailRequestCost));

                AddMenuItem(menu2, "", display, ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "no", "No");
                AddMenuItem(menu2, "yes", "Yes");

                DisplayMenu(menu2, client, DEFAULT_TIMEOUT);
            }
        }
    }
}

public Trails_ConfirmRequest2(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                Trails_OwnerTrailMainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:chosen[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, chosen, sizeof(chosen));

            if (StrEqual(chosen, "yes"))
            {
                new Handle:menu2 = CreateMenu(Trails_ConfirmRequest3);

                SetMenuTitle(menu2, "Last Confirmation");
                SetMenuExitBackButton(menu2, true);

                AddMenuItem(menu2, "", "Have you read ALL of", ITEMDRAW_DISABLED);
                AddMenuItem(menu2, "", " http://goo.gl/bcIIoB ?", ITEMDRAW_DISABLED);

                AddMenuItem(menu2, "", "No");
                AddMenuItem(menu2, "yes", "Yes");

                DisplayMenu(menu2, client, DEFAULT_TIMEOUT);
            }
        }
    }
}

public Trails_ConfirmRequest3(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                Trails_OwnerTrailMainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:chosen[MAX_NAME_LENGTH];
            GetMenuItem(menu, selected, chosen, sizeof(chosen));

            if (StrEqual(chosen, "yes"))
            {
                new gangpoints = GetRepByGang(sCacheGang[client]);
                new cost = GetConVarInt(hTrailRequestCost);

                if (gangpoints < cost)
                {
                    PrintToChat(client,
                                "%s You only have \x04%d\x01 Gang Points \x04(%d Required)",
                                MSG_PREFIX, gangpoints, cost);

                    return;
                }

                decl String:query[256];
                decl String:sEscapedName[MAX_NAME_LENGTH * 2 + 1];

                SQL_EscapeString(hDrugDB, sCacheGang[client], sEscapedName, sizeof(sEscapedName));

                Format(query, sizeof(query),
                       "UPDATE gangs SET trail = 'Request Accepted' WHERE name = '%s'",
                       sEscapedName);

                SQL_TQuery(hDrugDB, EmptyCallback, query);
                AddRepByGang(sCacheGang[client], -cost);

                SetTrieString(g_hGangTrailsTrie, sCacheGang[client], "Request Accepted");
                SetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], 1);

                PrintToChat(client, "%s Your request has been accepted", MSG_PREFIX);
                PrintToChat(client, "%s It is important you do \x04NOT\x01 do another request", MSG_PREFIX);
                PrintToChat(client, "%s Visit \x04http://goo.gl/bcIIoB\x01 for more info", MSG_PREFIX);
            }
        }
    }
}


/* ----- Functions ----- */


stock Trails_EnableDisableTrailForOne(client)
{
    decl String:dummy[3];
    new enabled;

    if (!GetTrieString(g_hGangTrailsTrie, sCacheGang[client], dummy, sizeof(dummy)) ||
        StrEqual(dummy, ""))
    {
        PrintToChat(client, "%s Your gang does not own a trail", MSG_PREFIX);
        PrintToChat(client, "%s Ask your gang leader for more information", MSG_PREFIX);

        return;
    }

    if (g_bGangTrailEnabled[client])
    {
        g_bGangTrailEnabled[client] = false;
        SetClientCookie(client, g_hGangTrailEnabledCookie, "0");

        PrintToChat(client, "%s You have \x04disabled\x01 your gang trail", MSG_PREFIX);
    }

    else
    {
        g_bGangTrailEnabled[client] = true;
        SetClientCookie(client, g_hGangTrailEnabledCookie, "1");

        PrintToChat(client, "%s You have \x04enabled\x01 your gang trail, which will override any premium trail", MSG_PREFIX);
        PrintToChat(client, "%s Trails must be enabled in the \x04!premium\x01 menu as well as stealth mode disabled", MSG_PREFIX);

        GetTrieValue(g_hGangTrailsEnabledTrie, sCacheGang[client], enabled);

        if (!enabled)
        {
            PrintToChat(client, "%s However, your gang leader has chosen to disable the trail for your gang", MSG_PREFIX);
            PrintToChat(client, "%s Trails drain gang rep as well as your rep each round, remember to donate to your gang to encourage your leader to enable trails", MSG_PREFIX);
        }
    }
}
