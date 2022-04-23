
// ###################### GLOBALS ######################

new Handle:g_hFreeCreditsEnabled = INVALID_HANDLE;
new Handle:g_hFreeCreditsPlaying = INVALID_HANDLE;
new Handle:g_hFreeCreditsIdling = INVALID_HANDLE;
new Handle:g_hFreeCreditsInterval = INVALID_HANDLE;

new g_bFreeCreditsEnabled = 1;

new g_iFreeCreditsIdling = 3;
new g_iFreeCreditsPlaying = 10;
new g_iWhatTheFuck;

new Float:g_fFreeCreditsInterval = 180.0;

new Handle:g_hCreditQueueArray = INVALID_HANDLE;
new Handle:g_hCreditQueueCredits = INVALID_HANDLE;
new Handle:g_hCreditQueueNames = INVALID_HANDLE;

new g_iToGiveTarget[MAXPLAYERS + 1];
new g_iToGiveAmount[MAXPLAYERS + 1];
new g_iLastGiveCredits[MAXPLAYERS + 1];

// ###################### EVENTS ######################


stock Credits_OnPluginStart()
{
    CreateTimer(300.0, Timer_SaveCredits, true, TIMER_REPEAT);

    g_hFreeCreditsEnabled = CreateConVar("hg_premium_credits_free", "1", "Enable or Disable giving free credits for playing");
    g_hFreeCreditsPlaying = CreateConVar("hg_premium_credits_for_playing", "10", "How much credits a VIP member gets every interval for playing");
    g_hFreeCreditsIdling = CreateConVar("hg_premium_credits_for_idling", "5", "How many credits a VIP member gets every interval for idling");
    g_hFreeCreditsInterval = CreateConVar("hg_premium_credits_interval", "180.0", "How often to give players credits for playing/idling");

    HookConVarChange(g_hFreeCreditsEnabled, Credits_OnConVarChanged);
    HookConVarChange(g_hFreeCreditsPlaying, Credits_OnConVarChanged);
    HookConVarChange(g_hFreeCreditsIdling, Credits_OnConVarChanged);
    HookConVarChange(g_hFreeCreditsInterval, Credits_OnConVarChanged);

    g_hCreditQueueArray = CreateArray(ByteCountToCells(32));
    g_hCreditQueueCredits = CreateTrie();
    g_hCreditQueueNames = CreateTrie();

    RegConsoleCmd("sm_give", Command_GiveCredits);
    RegConsoleCmd("sm_givecredits", Command_GiveCredits);
    RegConsoleCmd("sm_givebux", Command_GiveCredits);

    RegServerCmd("dontusethiscommandwithoutasking", Command_AdminGiveCredits);
}

stock Credits_OnConfigsExecuted()
{
    g_bFreeCreditsEnabled = GetConVarBool(g_hFreeCreditsEnabled);
    g_iFreeCreditsPlaying = GetConVarInt(g_hFreeCreditsPlaying);
    g_iFreeCreditsIdling = GetConVarInt(g_hFreeCreditsIdling);
    g_fFreeCreditsInterval = GetConVarFloat(g_hFreeCreditsInterval);

    if (g_fFreeCreditsInterval < 120.0)
    {
        g_fFreeCreditsInterval = 120.0;
    }

    CreateTimer(g_fFreeCreditsInterval, Timer_GiveCredits);
}

stock Credits_OnPluginEnd()
{
    Timer_SaveCredits(INVALID_HANDLE, false);
}

public Credits_OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hFreeCreditsEnabled)
        g_bFreeCreditsEnabled = GetConVarBool(CVar);
        
    else if (CVar == g_hFreeCreditsPlaying)
        g_iFreeCreditsPlaying = GetConVarInt(CVar);

    else if (CVar == g_hFreeCreditsIdling)
        g_iFreeCreditsIdling = GetConVarInt(CVar);

    else if (CVar == g_hFreeCreditsInterval)
        g_fFreeCreditsInterval = GetConVarFloat(CVar);

    if (g_fFreeCreditsInterval < 120.0)
    {
        g_fFreeCreditsInterval = 120.0;
    }
}

// ###################### NATIVES ######################


public Native_Premium_GetPoints(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    return Shop_GetCredits(client);
}

public Native_Premium_AddPoints(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    new amount = GetNativeCell(2);
    new bool:message = true;

    if (args > 2)
        message = GetNativeCellRef(3);

    // Make sure this client is in-game and has a Steam ID.
    if (!IsClientInGame(client) || !IsClientAuthorized(client)) return;

    if (amount >= 4200 || amount <= -4200)
    {
        Shop_AddCredits(client, amount);
    }

    else
    {
        GivePlayerCredits(client, amount);
    }

    if (message)
    {
        PrintToChat(client, "%s You received \x03%d \x05premium credits \x01(\x04total: \x03%d\x01)", MSG_PREFIX, amount, Shop_GetCredits(client));
    }
}

// ###################### FUNCTIONS ######################


// This differse from Shop_AddCredits because this is used for small transactions.
// We don't really care about a few missing credits here and there.

stock GivePlayerCredits(client, credits)
{
    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    GetClientName(client, name, sizeof(name));

    new old;
    new current;

    GetTrieValue(g_hCreditQueueCredits, steamid, old);
    if (FindStringInArray(g_hCreditQueueArray, steamid) == -1)
        PushArrayString(g_hCreditQueueArray, steamid);

    SetTrieValue(g_hCreditQueueCredits, steamid, old + credits);
    SetTrieString(g_hCreditQueueNames, steamid, name);

    GetTrieValue(g_hPlayerCredits, steamid, current);
    SetTrieValue(g_hPlayerCredits, steamid, current + credits);
}


// ###################### COMMANDS ######################


public Action:Command_AdminGiveCredits(args)
{
    if (args != 2)
    {
        ReplyToCommand(0, "Invalid syntax -- dontusethiscommandwithoutasking <password to not get banned> \"<steamid>\" <amount>");
        return Plugin_Handled;
    }

    decl String:steamid[32];
    decl String:sAmount[8];
    decl String:password[8];

    GetCmdArg(1, password, sizeof(password));
    GetCmdArg(2, steamid, sizeof(steamid));
    GetCmdArg(3, sAmount, sizeof(steamid));

    if (!StrEqual(password, "xyzzy"))
    {
        ReplyToCommand(0, "Using this command without authorization will result in demotion.");
        return Plugin_Handled;
    }

    new credits = StringToInt(sAmount);

    if (!credits)
    {
        ReplyToCommand(0, "Invalid amount");
        return Plugin_Handled;
    }

    if (SimpleRegexMatch(steamid, REGEX_STEAMID) <= 0)
    {
        ReplyToCommand(0, "Invalid Steamid");
        return Plugin_Handled;
    }

    decl String:query[256];

    Format(query, sizeof(query),
           "INSERT INTO players (steamid, credits, ipaddr) VALUES ('%s', %d, '%s') ON DUPLICATE KEY UPDATE credits = credits + %d",
           steamid, credits, "127.0.0.0", credits);

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/hg_premium_admingive.log");

    LogToFile(path, query);
    SQL_TQuery(g_hDbConn, EmptyCallback, query);

    return Plugin_Handled;
}

public Action:Command_GiveCredits(client, args)
{
    if (!IsAuthed(client))
        return Plugin_Handled;

    decl String:sTarget[MAX_NAME_LENGTH];
    decl String:sAmount[8];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new target = FindTarget(client, sTarget, false, false);
    if (target <= 0)
        return Plugin_Handled;

    if (target == client)
    {
        PrintToChat(client, "%s Yeah... Good luck with that.", MSG_PREFIX);
        return Plugin_Handled;
    }

    new amount = StringToInt(sAmount);
    if (amount < 1)
    {
        PrintToChat(client, "%s Invalid amount", MSG_PREFIX);
        return Plugin_Handled;
    }

    new credits = Shop_GetCredits(client);
    if (credits < amount)
    {
        PrintToChat(client,
                    "%s You only have \x03%d\x04 credits.",
                    MSG_PREFIX, credits);
        return Plugin_Handled;
    }

    if (GetTime() - g_iLastGiveCredits[client] < 10)
    {
        PrintToChat(client,
                    "%s You can not use this command for another \x04%d\x01 second(s)",
                    MSG_PREFIX, 10 - (GetTime() - g_iLastGiveCredits[client]));
        return Plugin_Handled;
    }

    new Handle:menu = CreateMenu(ConfirmGiveCreditsSelect);
    SetMenuTitle(menu, "Give %N %d credits?", target, amount);

    AddMenuItem(menu, "", "No");
    AddMenuItem(menu, "", "Yes");

    g_iToGiveTarget[client] = GetClientUserId(target);
    g_iToGiveAmount[client] = amount;

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}


// ###################### CALLBACKS ######################


public ConfirmGiveCreditsSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Select:
        {
            if (selected == 1)
            {
                new target = GetClientOfUserId(g_iToGiveTarget[client]);
                new amount = g_iToGiveAmount[client];

                if (!target)
                    PrintToChat(client,
                                "%s Sorry, that client has left the server.",
                                MSG_PREFIX);

                else
                {
                    // Note we use Shop_AddCredits because these credits are srs bsness.
                    Shop_AddCredits(target, amount);
                    Shop_AddCredits(client, -amount);

                    PrintToChat(client,
                                "%s You sent \x03%N \x05%d\x04 credits",
                                MSG_PREFIX, target, amount);

                    PrintToChat(target,
                                "%s \x03%N \x04sent you \x05%d\x04 credits",
                                MSG_PREFIX, client, amount);

                    decl String:path[PLATFORM_MAX_PATH];
                    BuildPath(Path_SM, path, sizeof(path), "scripting/hg_premium_give.log");

                    decl String:client_steamid[32];
                    decl String:target_steamid[32];
    
                    GetClientAuthString(client, client_steamid, sizeof(client_steamid));
                    GetClientAuthString(target, target_steamid, sizeof(target_steamid));

                    LogToFile(path, "%N (%s) sent %N (%s) %d credits", client, client_steamid, target, target_steamid, amount);
                    g_iLastGiveCredits[client] = GetTime();
                }
            }
        }
    }
}

public Action:Timer_SaveCredits(Handle:timer, any:threaded)
{
    if (g_hDbConn == INVALID_HANDLE)
    {
        LogError("Invalid handle in save credits.");
        return Plugin_Continue;
    }

    new credits;

    decl String:query[512];
    decl String:steamid[32];
    decl String:name[MAX_NAME_LENGTH];
    decl String:sEscapedName[MAX_NAME_LENGTH * 2 + 1];

    if (!threaded)
    {
        SQL_LockDatabase(g_hDbConn);
    }

    for (new i = 0; i < GetArraySize(g_hCreditQueueArray); i++)
    {
        GetArrayString(g_hCreditQueueArray, i, steamid, sizeof(steamid));
        GetTrieString(g_hCreditQueueNames, steamid, name, sizeof(name));
        GetTrieValue(g_hCreditQueueCredits, steamid, credits);

        SQL_EscapeString(g_hDbConn, name, sEscapedName, sizeof(sEscapedName));
        Format(query, sizeof(query),
               "INSERT INTO players (steamid, name, credits, ipaddr) VALUES ('%s', '%s', %d, '127.0.0.0') ON DUPLICATE KEY UPDATE name = '%s', credits = credits + %d",
               steamid, sEscapedName, credits, sEscapedName, credits);

        if (threaded)
        {
            SQL_TQuery(g_hDbConn, EmptyCallback, query);
        }

        else
        {
            SQL_FastQuery(g_hDbConn, query);
        }
    }

    if (!threaded)
    {
        SQL_UnlockDatabase(g_hDbConn);
    }

    ClearArray(g_hCreditQueueArray);
    ClearTrie(g_hCreditQueueCredits);
    ClearTrie(g_hCreditQueueNames);

    return Plugin_Continue;
}

public Action:Timer_GiveCredits(Handle:timer)
{
    if (g_bFreeCreditsEnabled && (GetTime() - g_iWhatTheFuck) >= 120.0)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i))
                continue;
    
            if (GetClientTeam(i) <= 1)
            {
                GivePlayerCredits(i, g_iFreeCreditsIdling);
                PrintToChat(i,
                            "%s You recieved \x03%d\x05 premium credits \x04for idling in spectate",
                            MSG_PREFIX, g_iFreeCreditsIdling);
            }

            else
            {
                GivePlayerCredits(i, g_iFreeCreditsPlaying);
                KeyHintText(i, "+%d credits", g_iFreeCreditsPlaying);
            }
        }

        g_iWhatTheFuck = GetTime();
    }
    
    CreateTimer(g_fFreeCreditsInterval, Timer_GiveCredits);
    return Plugin_Stop;
}

