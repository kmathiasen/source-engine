/*
 * In the database:
 *  filepath - The name(s) of the command(s) to register, seperated by |
 *      ex. $|cash|money will register the commands "!$", "!cash" and "!money"
 *
 *  filepath_ct - The command to run
 *      For the command to run, #userid will be replaced by the player's userid.
 *      Valid commands are:
 *          hg_items_setcash #userid <amount>
 *          hg_items_give #userid <weapon_weaponname>
 *
 *  NOTE: The maximum characters for both fields is 255.
 */


// ###################### GLOBALS ######################

new Handle:g_hCommandExecuteTries = INVALID_HANDLE;
new Handle:g_hCommandNames = INVALID_HANDLE;
new Handle:g_hCommands = INVALID_HANDLE;

new Handle:g_hPlayerCommands[MAXPLAYERS + 1];

new Handle:g_hGiveWeaponDelay;

new g_iMoneyAccount = -1;
new g_iGiveWeaponDelay = 120;
new g_iLastGive[MAXPLAYERS + 1];


// ###################### EVENTS ######################

public ChatCmd_OnPluginStart()
{
    g_hCommands = CreateArray(ByteCountToCells(LEN_NAMES));
    g_hCommandNames = CreateTrie();
    g_hCommandExecuteTries = CreateTrie();

    RegServerCmd("hg_items_give", Server_GiveItem);
    RegServerCmd("hg_items_setcash", Server_SetCash);

    RegConsoleCmd("sm_commands", Command_Commands, "View the HG Items commands");

    g_hGiveWeaponDelay = CreateConVar("hg_premium_weapons_delay", "120", "The wait time in seconds after using a weapon command.", FCVAR_NONE, true, 0.0);

    HookConVarChange(g_hGiveWeaponDelay, ChatCmd_OnConVarChanged);

    g_iMoneyAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
}

stock ChatCmd_OnDBConnect()
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT name, filepath, filepath_ct FROM items WHERE (servertype & %d) and (type = %d) and (servertype > 0)",
           g_iServerType, ITEMTYPE_COMMAND);

    SQL_TQuery(g_hDbConn, GrabCommandsCallback, query);
}

stock ChatCmd_OnClientPutInServer(client)
{
    if (g_hPlayerCommands[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hPlayerCommands[client]);
        g_hPlayerCommands[client] = INVALID_HANDLE;
    }

    g_iLastGive[client] = 0;
}

public ChatCmd_OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hGiveWeaponDelay)
        g_iGiveWeaponDelay = GetConVarInt(CVar);
}

// ###################### ACTIONS ######################


public Action:Command_Commands(client, args)
{
    if (IsAuthed(client))
        CommandsMenu(client);

    return Plugin_Handled;
}

public Action:Server_GiveItem(args)
{
    if (args < 2)
    {
        LogError("Invalid Syntax -- hg_items_give <userid> <weapon_weaponname>");
        return Plugin_Handled;
    }

    decl String:sTarget[8];
    decl String:item[MAX_NAME_LENGTH];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    GetCmdArg(2, item, sizeof(item));

    new target = GetClientOfUserId(StringToInt(sTarget));
    if (!target)
        return Plugin_Handled;

    if (!IsPlayerAlive(target))
    {
        PrintToChat(target,
                    "%s you must be alive to use this command", MSG_PREFIX);

        return Plugin_Handled;
    }

    new left = g_iGiveWeaponDelay - (GetTime() - g_iLastGive[target]);
    if (left > 0)
    {
        PrintToChat(target,
                    "%s You must wait another \x03%02d:%02d\x04 to use this command",
                    MSG_PREFIX, left / 60, left % 60);

        return Plugin_Handled;
    }

    g_iLastGive[target] = GetTime();
    GivePlayerItem(target, item);

    ReplaceString(item, sizeof(item), "weapon_", "", false);
    item[0] = CharToUpper(item[0]);

    PrintToChat(target, "%s You got a \x03%s", MSG_PREFIX, item);
    return Plugin_Handled;
}

public Action:Server_SetCash(args)
{
    if (args < 2)
    {
        LogError("Invalid Syntax -- hg_items_setcash <userid> <amount>");
        return Plugin_Handled;
    }

    decl String:sTarget[8];
    decl String:amount[MAX_NAME_LENGTH];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    GetCmdArg(2, amount, sizeof(amount));

    new target = GetClientOfUserId(StringToInt(sTarget));
    if (!target)
        return Plugin_Handled;

    SetEntData(target, g_iMoneyAccount, StringToInt(amount));
    PrintToChat(target, "%s You got \x03%s\x04 cash!", MSG_PREFIX, amount);

    return Plugin_Handled;
}

public Action:ChatCmd_CommandHandler(client, args)
{
    if (!IsAuthed(client))
        return Plugin_Handled;

    decl String:executed_command[MAX_NAME_LENGTH];
    GetCmdArg(0, executed_command, sizeof(executed_command));

    for (new i = 0; i < GetArraySize(g_hCommands); i++)
    {
        decl String:command[MAX_NAME_LENGTH];
        decl Handle:hCommandArray;

        GetArrayString(g_hCommands, i, command, sizeof(command));
        GetTrieValue(g_hCommandNames, command, hCommandArray);

        if (FindStringInArray(hCommandArray, executed_command) > -1)
        {
            if (g_hPlayerCommands[client] == INVALID_HANDLE)
            {
                PrintToChat(client,
                            "%s Sorry, there's been an error drawing your items from the DB",
                            MSG_PREFIX);

                PrintToChat(client,
                            "%s If this problem persists for more than a day, post on \x03hellsgamers.com",
                            MSG_PREFIX);

                return Plugin_Handled;
            }

            if (!IsAuthed(client, command))
                return Plugin_Handled;

            if (FindStringInArray(g_hPlayerCommands[client], command) == -1)
            {
                PrintToChat(client, "%s You do not own this item", MSG_PREFIX);
                PrintToChat(client, "%s Type \x03!shop\x04 to purchase it", MSG_PREFIX);

                return Plugin_Handled;
            }

            decl String:to_execute[PLATFORM_MAX_PATH];
            GetTrieString(g_hCommandExecuteTries, command,
                          to_execute, sizeof(to_execute));

            decl String:sUserid[8];
            IntToString(GetClientUserId(client), sUserid, sizeof(sUserid));

            decl String:sArgs[255];
            GetCmdArgString(sArgs, sizeof(sArgs));

            ReplaceString(to_execute, sizeof(to_execute),
                          "#userid", sUserid, false);

            ReplaceString(sArgs, sizeof(sArgs), ";", "");
            ReplaceString(to_execute, sizeof(to_execute),
                          "#args", sArgs, false);

            ServerCommand(to_execute);
            return Plugin_Handled;
        }
    }

    PrintToChat(client, "%s Uhh... Something messed up. Sorry.", MSG_PREFIX);
    return Plugin_Handled;
}

// ###################### CALLBACKS ######################


public GrabCommandsCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    decl String:command[LEN_NAMES];
    decl String:to_register[PLATFORM_MAX_PATH];
    decl String:to_execute[PLATFORM_MAX_PATH];
    decl String:to_register_parts[8][MAX_NAME_LENGTH];

    decl Handle:hCommandArray;

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, command, sizeof(command));
        SQL_FetchString(hndl, 1, to_register, sizeof(to_register));
        SQL_FetchString(hndl, 2, to_execute, sizeof(to_execute));

        if (!GetTrieValue(g_hCommandNames, command, hCommandArray))
            hCommandArray = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));

        new found = ExplodeString(to_register, "|",
                                  to_register_parts,
                                  8, MAX_NAME_LENGTH);

        for (new i = 0; i < found; i++)
        {
            if (FindStringInArray(hCommandArray, to_register_parts[i]) == -1)
            {
                PushArrayString(hCommandArray, to_register_parts[i]);
                RegConsoleCmd(to_register_parts[i],
                              ChatCmd_CommandHandler, command);
            }
        }

        SetTrieValue(g_hCommandNames, command, hCommandArray);
        SetTrieString(g_hCommandExecuteTries, command, to_execute);
    }
}

public CommandsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                MainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:command[32];
            GetMenuItem(menu, selected, command, sizeof(command));

            FakeClientCommand(client, command);
        }
    }
}


// ###################### FUNCTIONS ######################


stock CommandsMenu(client)
{
    new Handle:menu = CreateMenu(CommandsMenuSelect);
    new bool:found;

    SetMenuTitle(menu, "HG Commands");
    SetMenuExitBackButton(menu, true);

    for (new i = 0; i < GetArraySize(g_hPlayerCommands[client]); i++)
    {
        decl String:command[LEN_NAMES];
        GetArrayString(g_hPlayerCommands[client], i, command, sizeof(command));

        decl Handle:hCommands;
        GetTrieValue(g_hCommandNames, command, hCommands);

        decl String:to_execute[MAX_NAME_LENGTH];
        GetArrayString(hCommands, 0, to_execute, sizeof(to_execute));

        decl String:display[64];
        Format(display, sizeof(display), "%s - /%s", command, to_execute);

        AddMenuItem(menu, to_execute, display);
        found = true;
    }

    // They don't have any items bought; let's tell 'em how to get some.
    if (!found)
    {
        AddMenuItem(menu, "", "You have no items", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Please type !shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Or press back", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "To purchase items", ITEMDRAW_DISABLED);
    }

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
