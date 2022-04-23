#define TRADE_CSS           GAMETYPE_CSS
#define TRADE_CSGO          GAMETYPE_CSGO
#define TRADE_TF2           GAMETYPE_TF2
#define TRADE_CREDITS       GAMETYPE_ALL

enum Trade
{
    Trade_None = 0,         /* Player is not selecting any trade */
    Trade_With,             /* Player is selecting an amount to trade with */
    Trade_For,              /* Player is selecting an amount to trade for */
    Trade_ConfirmAmount,    /* Player is confirming trade amounts */
    Trade_AmountConfirmed,  /* Player is waiting for first acceptance from target */
    Trade_ReconfirmAmount,  /* Player is reconfirming their previous selection */
    Trade_Accepted,         /* Player has accepted the trade */
    Trade_FirstAccept,      /* Target player is accepting/declining the first time */
    Trade_SecondAccept,     /* Target player is reconfirming their previous selection */
    Trade_TargetAccepted,   /* Target has accepted the trade */
}

new g_iTradingWith[MAXPLAYERS + 1];
new g_iTradingFor[MAXPLAYERS + 1];
new g_iTradingTarget[MAXPLAYERS + 1];
new g_iTradingWithAmount[MAXPLAYERS + 1];
new g_iTradingForAmount[MAXPLAYERS + 1];
new g_iLastTrade[MAXPLAYERS + 1];
new g_iLastTradeMessage[MAXPLAYERS + 1];
new Trade:g_tTradeType[MAXPLAYERS + 1];

new Handle:g_hRulesMenu = INVALID_HANDLE;

/* ----- Events ----- */


stock Trade_OnPluginStart()
{
    RegConsoleCmd("sm_trade", Command_Trade);
    RegConsoleCmd("sm_tradehelp", Command_TradeHelp);
    RegConsoleCmd("sm_traderules", Command_TradeRules);
    RegConsoleCmd("sm_toggletrade", Command_ToggleTrade);
    RegConsoleCmd("sm_t", Command_TradeChat);
    RegConsoleCmd("sm_canceltrade", Command_CancelTrade);

    CreateTimer(177.29, Timer_TradeAdverts, _, TIMER_REPEAT);
    CreateRulesMenu();
}

stock Trade_OnClientPutInServer(client)
{
    g_tTradeType[client] = Trade_None;
    // debug
    // put this back in for release
    // g_iLastTrade[client] = GetTime();
}

stock Trade_OnClientDisconnect(client)
{
    if (GetClientOfTarget(client) == -1 && g_tTradeType[client] != Trade_None)
    {
        CleanupTrade(g_iTradingTarget[client]);
        CleanupTrade(client);
    }
}

/**
 * @retval true     Allow chat through.
 * @retval false    Block chat.
 */
bool:Trade_OnSay(client)
{
    if (g_tTradeType[client] != Trade_With &&
        g_tTradeType[client] != Trade_For)
        return true;

    new target = g_iTradingTarget[client];

    if (!IsValidTradeTarget(target, client))
    {
        CleanupTrade(client);
        return false;
    }

    decl String:argstring[32];
    GetCmdArgString(argstring, sizeof(argstring));

    if (StrEqual(argstring, "") || StrEqual(argstring, "\"\""))
        return true;

    StripQuotes(argstring);

    new val = StringToInt(argstring);

    if (val <= 0)
    {
        PrintToChat(client, "%s Please enter a valid integer greater than 0", MSG_PREFIX);
        SelectTradeAmount(client, g_tTradeType[client]);
        return false;
    }

    if (g_tTradeType[client] == Trade_With)
    {
        if (g_iTradingWith[client] == TRADE_CREDITS)
        {
            new credits = Premium_GetPoints(client);

            if (credits < 1)
            {
                PrintToChat(client, "%s Yo dawg, you gots no credits", MSG_PREFIX);
                CleanupTrade(client);
                return false;
            }

            if (val > credits)
            {
                PrintToChat(client, "%s You only have \x03%d\x04 credits", MSG_PREFIX, credits);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            g_iTradingWithAmount[client] = val;
            SelectTradeAmount(client, Trade_For);
        }

        else
        {
            new maxval = PrisonRep_TransferLimit(client);
            new rep = PrisonRep_GetPoints(client, g_iTradingWith[client]);

            if (val > maxval)
            {
                PrintToChat(client, "%s You may only transfer \x03%d\x04 more rep today", MSG_PREFIX, maxval);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            if (rep < 1)
            {
                PrintToChat(client, "%s Yo dawg, you gots no rep", MSG_PREFIX);
                CleanupTrade(client);
                return false;
            }
    
            if (val > rep)
            {
                PrintToChat(client, "%s You only have \x03%d\x04 rep", MSG_PREFIX, rep);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            g_iTradingWithAmount[client] = val;
            SelectTradeAmount(client, Trade_For);
        }
    }

    else if (g_tTradeType[client] == Trade_For)
    {
        if (g_iTradingFor[client] == TRADE_CREDITS)
        {
            new credits = Premium_GetPoints(target);

            if (credits < 1)
            {
                PrintToChat(client, "%s Yo dawg, \x03%N\x04 gots no credits", MSG_PREFIX, target);
                CleanupTrade(client);
                return false;
            }

            if (val > credits)
            {
                PrintToChat(client, "%s \x03%N\x04 only has \x03%d\x04 credits", MSG_PREFIX, target, credits);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            g_iTradingForAmount[client] = val;
            ConfirmTradeAmount(client, Trade_ConfirmAmount);
        }

        else
        {
            new maxval = PrisonRep_TransferLimit(target);
            new rep = PrisonRep_GetPoints(target, g_iTradingFor[client]);

            if (val > maxval)
            {
                PrintToChat(client, "%s \x03%N\x04 may only transfer \x03%d\x04 more rep today", MSG_PREFIX, target, maxval);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            if (rep < 1)
            {
                PrintToChat(client, "%s Yo dawg, \x03%N\x04 gots no rep", MSG_PREFIX, target);
                CleanupTrade(client);
                return false;
            }
    
            if (val > rep)
            {
                PrintToChat(client, "%s \x03%N\x04 only has \x03%d\x04 rep", MSG_PREFIX, target, rep);
                SelectTradeAmount(client, g_tTradeType[client]);
                return false;
            }

            g_iTradingForAmount[client] = val;
            ConfirmTradeAmount(client, Trade_ConfirmAmount);
        }
    }

    return false;
}


/* ----- Functions ----- */


stock CleanupTrade(client)
{
    g_tTradeType[client] = Trade_None;
    g_tTradeType[g_iTradingTarget[client]] = Trade_None;
    g_iTradingTarget[client] = 0;
}

stock CreateRulesMenu()
{
    g_hRulesMenu = CreateMenu(EmptyMenuSelect);
    SetMenuTitle(g_hRulesMenu, "Trade Rules");

    AddMenuItem(g_hRulesMenu, "", "Do not repeat ANY variation of the same message more than once every 2 minutes");
    AddMenuItem(g_hRulesMenu, "", "Do not put any trade related messages in chat/over mic. Mutes and gags will be given");
    AddMenuItem(g_hRulesMenu, "", "Do not start trades with those who do not want to");
    AddMenuItem(g_hRulesMenu, "", "Trade at your own risk. Trades will NOT be reversed");
    AddMenuItem(g_hRulesMenu, "", "All regular chat rules apply");
    AddMenuItem(g_hRulesMenu, "", "No spamming of any kind");
}

bool:IsValidTradeTarget(target, client)
{
    if (target <= 0)
        return false;

    if (g_hDbConn_Main == INVALID_HANDLE)
    {
        PrintToChat(client, "%s Something went wrong with the database connection...", MSG_PREFIX);
        return false;
    }

    if (!IsClientInGame(target))
    {
        PrintToChat(client, "%s Your trade target has left the game...", MSG_PREFIX);
        return false;
    }

    // Are they a trade owner
    if (g_tTradeType[target] != Trade_None &&
        g_tTradeType[target] != Trade_FirstAccept &&
        g_tTradeType[target] != Trade_SecondAccept &&
        g_tTradeType[target] != Trade_TargetAccepted)
    {
        PrintToChat(client, "%s Your target has started a trade with another player...", MSG_PREFIX);
        return false;
    }

    // Are they someone elses target
    new owner = GetClientOfTarget(target);
    if (owner > 0 && owner != client)
    {
        PrintToChat(client, "%s That player is already someone elses target", MSG_PREFIX);
        return false;
    }

    return true;
}

GetClientOfTarget(target)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iTradingTarget[i] == target &&
            g_tTradeType[i] > Trade_ConfirmAmount)
            return i;
    }

    return -1;
}

stock GetCurrencyName(currencyType, String:currency[], maxlength)
{
    if (currencyType == TRADE_CREDITS)
    {
        Format(currency, maxlength, "HG Bux");
    }

    else
    {
        GameToAcronym(currencyType, currency, maxlength);
        StrCat(currency, maxlength, " Rep");
    }
}

stock CheckTradeComplete(client)
{
    new owner = GetClientOfTarget(client);
    new target = g_iTradingTarget[client];

    // Client is the owner
    if (owner == -1)
    {
        owner = client;
    }

    else
    {
        target = client;
    }

    new bool:ownerAccepted = g_tTradeType[owner] == Trade_Accepted;
    new bool:targetAccepted = g_tTradeType[target] == Trade_TargetAccepted;

    // Complete the trade.
    if (ownerAccepted && targetAccepted)
    {
        CompleteTrade(owner);
    }

    else if (ownerAccepted)
    {
        DisplayMSay(owner, "Awaiting Confirmation", 60, "Waiting for %N to accept", target);
    }

    else if (targetAccepted)
    {
        DisplayMSay(target, "Awaiting Confirmation", 60, "Waiting for %N to accept", owner);
    }
}

stock CompleteTrade(client)
{
    new target = g_iTradingTarget[client];
    new bool:trade = true;
    new valClient = g_iTradingWithAmount[client];
    new valTarget = g_iTradingForAmount[client];

    if (!IsValidTradeTarget(target, client) || !IsClientInGame(client))
    {
        CleanupTrade(client);
        CleanupTrade(target);
        return;
    }

    decl String:giveCurrency[12];
    decl String:getCurrency[12];

    GetCurrencyName(g_iTradingWith[client], giveCurrency, sizeof(giveCurrency));
    GetCurrencyName(g_iTradingFor[client], getCurrency, sizeof(getCurrency));

    // Do the final checks
    if (g_iTradingWith[client] == TRADE_CREDITS)
    {
        new credits = Premium_GetPoints(client);
        if (valClient > credits)
        {
            PrintToChat(client, "%s You do not have \x03%d\x04 credits", MSG_PREFIX, valClient);
            PrintToChat(target, "%s \x03%N\x04 does not have enough funds to complete the trade", MSG_PREFIX, client);
            trade = false;
        }
    }

    else
    {
        new maxval = PrisonRep_TransferLimit(client);
        new rep = PrisonRep_GetPoints(client, g_iTradingWith[client]);

        if (valClient > maxval)
        {
            PrintToChat(client, "%s You may only transfer \x03%d\x04 more rep today", MSG_PREFIX, maxval);
            PrintToChat(target, "%s \x03%N\x04's rep transfer limit has been exceeded", MSG_PREFIX, client);
            trade = false;
        }

        else if (valClient > rep)
        {
            PrintToChat(client, "%s You do not have \x03%d \x05%s", MSG_PREFIX, valClient, giveCurrency);
            PrintToChat(target, "%s \x03%N\x04 does not have enough funds to complete the trade", MSG_PREFIX, client);
            trade = false;
        }
    }

    if (trade)
    {
        if (g_iTradingFor[client] == TRADE_CREDITS)
        {
            new credits = Premium_GetPoints(target);
            if (valTarget > credits)
            {
                PrintToChat(target, "%s You do not have \x03%d\x04 credits", MSG_PREFIX, valTarget);
                PrintToChat(client, "%s \x03%N\x04 does not have enough funds to complete the trade", MSG_PREFIX, target);
                trade = false;
            }
        }

        else
        {
            new maxval = PrisonRep_TransferLimit(target);
            new rep = PrisonRep_GetPoints(target, g_iTradingFor[client]);

            if (valTarget > maxval)
            {
                PrintToChat(target, "%s You may only transfer \x03%d\x04 more rep today", MSG_PREFIX, maxval);
                PrintToChat(client, "%s \x03%N\x04's rep transfer limit has been exceeded", MSG_PREFIX, target);
                trade = false;
            }

            else if (valTarget > rep)
            {
                PrintToChat(target, "%s You do not have \x03%d \x05%s", MSG_PREFIX, valTarget, getCurrency);
                PrintToChat(client, "%s \x03%N\x04 does not have enough funds to complete the trade", MSG_PREFIX, target);
                trade = false;
            }
        }
    }

    // Complete the actual trade
    if (trade)
    {
        decl String:clientSteam[LEN_STEAMIDS];
        decl String:targetSteam[LEN_STEAMIDS];

        GetClientAuthString2(client, clientSteam, sizeof(clientSteam));
        GetClientAuthString2(target, targetSteam, sizeof(targetSteam));

        if (g_iTradingWith[client] == g_iGame)
        {
            PrisonRep_AddPoints(client, -valClient);
            PrisonRep_AddPoints(target, valClient);
        }

        else if (g_iTradingWith[client] == TRADE_CREDITS)
        {
            Premium_AddPoints(client, -valClient);
            Premium_AddPoints(target, valClient);
        }

        else
        {
            PrisonRep_AddPoints_Offline(clientSteam, -valClient, g_iTradingWith[client]);
            PrisonRep_AddPoints_Offline(targetSteam, valClient, g_iTradingWith[client]);
        }

        if (g_iTradingFor[client] == g_iGame)
        {
            PrisonRep_AddPoints(target, -valTarget);
            PrisonRep_AddPoints(client, valTarget);
        }

        else if (g_iTradingFor[client] == TRADE_CREDITS)
        {
            Premium_AddPoints(target, -valTarget);
            Premium_AddPoints(client, valTarget);
        }

        else
        {
            PrisonRep_AddPoints_Offline(targetSteam, -valTarget, g_iTradingFor[client]);
            PrisonRep_AddPoints_Offline(clientSteam, valTarget, g_iTradingFor[client]);
        }

        decl String:path[PLATFORM_MAX_PATH];
        decl String:client_steamid[32];
        decl String:target_steamid[32];

        BuildPath(Path_SM, path, sizeof(path), "scripting/trade.log");
        GetClientAuthString(client, client_steamid, sizeof(client_steamid));
        GetClientAuthString(target, target_steamid, sizeof(target_steamid));

        new Handle:iFile = OpenFile(path, "a");

        LogToOpenFile(iFile, "%N (%s) traded %d %s for %d %s with %N (%s)", client, client_steamid, valClient, giveCurrency, valTarget, getCurrency, target, target_steamid);
        CloseHandle(iFile);

        BuildPath(Path_SM, path, sizeof(path), "logs/trade.log");
        iFile = OpenFile(path, "a");

        LogToOpenFile(iFile, "%N (%s) traded %d %s for %d %s with %N (%s)", client, client_steamid, valClient, giveCurrency, valTarget, getCurrency, target, target_steamid);
        CloseHandle(iFile);

        PrintToChat(client, "%s You completed a trade with \x03%N", MSG_PREFIX, target);
        PrintToChat(client, "%s You sent \x03%d %s", MSG_PREFIX, g_iTradingWithAmount[client], giveCurrency);
        PrintToChat(client, "%s You recieved \x03%d %s", MSG_PREFIX, g_iTradingForAmount[client], getCurrency);

        PrintToChat(target, "%s You completed a trade with \x03%N", MSG_PREFIX, client);
        PrintToChat(target, "%s You sent \x03%d %s", MSG_PREFIX, g_iTradingForAmount[client], getCurrency);
        PrintToChat(target, "%s You recieved \x03%d %s", MSG_PREFIX, g_iTradingWithAmount[client], giveCurrency);

        DisplayMSay(client, "Trade Completed", 60, "You sent %d %s\nYou recieved %d %s", g_iTradingWithAmount[client], giveCurrency, g_iTradingForAmount[client], getCurrency);
        DisplayMSay(target, "Trade Completed", 60, "You sent %d %s\nYou recieved %d %s", g_iTradingForAmount[client], getCurrency, g_iTradingWithAmount[client], giveCurrency);
    }

    CleanupTrade(client);
    CleanupTrade(target);
}

stock TradeWithPlayers(client)
{
    new tradeDelay = GetConVarInt(g_hCvTradeDelay);

    if (GetTime() - g_iLastTrade[client] < tradeDelay)
    {
        PrintToChat(client,
                    "%s You may not start another/your first trade for another \x03%d\x04 second(s)",
                    MSG_PREFIX,
                    tradeDelay - (GetTime() - g_iLastTrade[client]));
        return;
    }

    new Handle:panel = CreatePanel();

    new String:cssrep[64] = "CS:S Rep: ERROR";
    new String:csgorep[64] = "CS:GO Rep: ERROR";
    new String:tf2rep[64] = "TF2 Rep: ERROR";
    new String:credits[64] = "HG Bux: ERROR";

    if (g_bGotRepFromDB[client][PR_CSS])
    {
        Format(cssrep, sizeof(cssrep), "CS:S Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_CSS));
    }

    if (g_bGotRepFromDB[client][PR_CSGO])
    {
        Format(csgorep, sizeof(csgorep), "CS:GO Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_CSGO));
    }

    if (g_bGotRepFromDB[client][PR_TF2])
    {
        Format(tf2rep, sizeof(tf2rep), "TF2 Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_TF2));
    }

    Format(credits, sizeof(credits), "HG Bux: %d", Premium_GetPoints(client));

    SetPanelTitle(panel, "Select What To Give");
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    DrawPanelText(panel, cssrep);
    DrawPanelText(panel, csgorep);
    DrawPanelText(panel, tf2rep);
    DrawPanelText(panel, credits);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    SetPanelCurrentKey(panel, 1);
    DrawPanelItem(panel, "Trade using CS:S Rep");
    DrawPanelItem(panel, "Trade using CS:GO Rep");
    DrawPanelItem(panel, "Trade using TF2 Rep");
    DrawPanelItem(panel, "Trade using HG Bux");
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    SetPanelCurrentKey(panel, 8);
    DrawPanelItem(panel, "Back", ITEMDRAW_CONTROL);

    if (g_iGame != GAMETYPE_CSGO)
    {
        SetPanelCurrentKey(panel, 10);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelItem(panel, "Cancel", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, TradeWithPlayersMenuSelect, MENU_TIMEOUT_NORMAL);
    CloseHandle(panel);
}

stock SelectTradeTarget(client)
{
    new Handle:menu = CreateMenu(SelectTradeTargetMenuSelect);

    SetMenuTitle(menu, "Choose Trade Target");
    SetMenuExitBackButton(menu, true);

    new Handle:arr = CreateArray(ByteCountToCells(MAX_NAME_LENGTH + 2));

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && i != client)
        {
            decl String:name[MAX_NAME_LENGTH + 2];

            GetClientName(i, name, MAX_NAME_LENGTH);
            StringToLower(name, sizeof(name));

            // Store the client's index at the end of the string
            // This way we don't have to_do a reverse NameToClientId function
            new len = strlen(name);
            name[len] = i;
            name[len + 1] = '\0';

            PushArrayString(arr, name);
        }
    }

    SortADTArray(arr, Sort_Ascending, Sort_String);

    for (new i = 0; i < GetArraySize(arr); i++)
    {
        decl String:name[MAX_NAME_LENGTH + 2];
        GetArrayString(arr, i, name, sizeof(name));

        new len = strlen(name);
        new id = name[len - 1];

        // What in the holy effervescent fuck.
        if (!IsClientInGame(id))
        {
            LogError("Something went wrong in SelectTradeTarget(). Id %d (%s) is not in game", id, name);
            continue;
        }

        decl String:sId[LEN_INTSTRING];
        decl String:realName[MAX_NAME_LENGTH];

        // We did StringToLower, so the "name" variable is now invalid.
        IntToString(GetClientUserId(id), sId, sizeof(sId));
        GetClientName(id, realName, sizeof(realName));

        AddMenuItem(menu, sId, realName);
    }

    CloseHandle(arr);
    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
}

stock SelectTargetCurrency(client)
{
    new Handle:panel = CreatePanel();
    new target = g_iTradingTarget[client];

    if (!IsValidTradeTarget(target, client))
        return;

    new String:cssrep[64] = "Your CS:S Rep: ERROR";
    new String:csgorep[64] = "Your CS:GO Rep: ERROR";
    new String:tf2rep[64] = "Your TF2 Rep: ERROR";
    new String:credits[64] = "Your HG Bux: ERROR";
    new String:targetcssrep[64] = "Their CS:S Rep: ERROR";
    new String:targetcsgorep[64] = "Their CS:GO Rep: ERROR";
    new String:targettf2rep[64] = "Their TF2 Rep: ERROR";
    new String:targetcredits[64] = "Their HG Bux: ERROR";

    if (g_bGotRepFromDB[client][PR_CSS])
    {
        Format(cssrep, sizeof(cssrep), "Your CS:S Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_CSS));
    }

    if (g_bGotRepFromDB[target][PR_CSS])
    {
        Format(targetcssrep, sizeof(targetcssrep), "Their CS:S Rep: %d", PrisonRep_GetPoints(target, GAMETYPE_CSS));
    }

    if (g_bGotRepFromDB[client][PR_CSGO])
    {
        Format(csgorep, sizeof(csgorep), "Your CS:GO Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_CSGO));
    }

    if (g_bGotRepFromDB[target][PR_CSGO])
    {
        Format(targetcsgorep, sizeof(targetcsgorep), "Their CS:GO Rep: %d", PrisonRep_GetPoints(target, GAMETYPE_CSGO));
    }

    if (g_bGotRepFromDB[client][PR_TF2])
    {
        Format(tf2rep, sizeof(tf2rep), "Your TF2 Rep: %d", PrisonRep_GetPoints(client, GAMETYPE_TF2));
    }

    if (g_bGotRepFromDB[target][PR_TF2])
    {
        Format(targettf2rep, sizeof(targettf2rep), "Their TF2 Rep: %d", PrisonRep_GetPoints(target, GAMETYPE_TF2));
    }

    Format(credits, sizeof(credits), "Your HG Bux: %d", Premium_GetPoints(client));
    Format(targetcredits, sizeof(targetcredits), "Their HG Bux: %d", Premium_GetPoints(target));

    SetPanelTitle(panel, "Select What To Get");
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    DrawPanelText(panel, cssrep);
    DrawPanelText(panel, csgorep);
    DrawPanelText(panel, tf2rep);
    DrawPanelText(panel, credits);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    SetPanelCurrentKey(panel, 1);
    DrawPanelItem(panel, targetcssrep, g_iTradingWith[client] == TRADE_CSS ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    DrawPanelItem(panel, targetcsgorep, g_iTradingWith[client] == TRADE_CSGO ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    DrawPanelItem(panel, targettf2rep, g_iTradingWith[client] == TRADE_TF2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    DrawPanelItem(panel, targetcredits, g_iTradingWith[client] == TRADE_CREDITS ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    SetPanelCurrentKey(panel, 8);
    DrawPanelItem(panel, "Back", ITEMDRAW_CONTROL);

    if (g_iGame != GAMETYPE_CSGO)
    {
        SetPanelCurrentKey(panel, 10);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelItem(panel, "Cancel", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, SelectTargetCurrencyMenuSelect, MENU_TIMEOUT_NORMAL);
    CloseHandle(panel);
}

stock AwaitingFirstConfirmation(client)
{
    new target = g_iTradingTarget[client];

    if (IsValidTradeTarget(target, client))
    {
        g_tTradeType[client] = Trade_AmountConfirmed;
        DisplayMSay(client, "Awaiting Confirmation", 60, "Asking %N to accept your trade...\nType /canceltrade to cancel", target);
    }
}

stock AskCancelTrade(client)
{
    new Handle:panel = CreatePanel();
    SetPanelTitle(panel, "Cancel Trade?");

    DrawPanelItem(panel, "Yes");
    DrawPanelItem(panel, "No");

    SendPanelToClient(panel, client, CancelTradeMenuSelect, MENU_TIMEOUT_NORMAL);
    CloseHandle(panel);
}

stock ConfirmWithTarget(target, Trade:stage)
{
    new client = GetClientOfTarget(target);
    new Handle:panel = CreatePanel();

    decl String:giveCurrency[16];
    decl String:getCurrency[16];
    decl String:giveMsg[42];
    decl String:getMsg[42];

    g_tTradeType[target] = stage;

    GetCurrencyName(g_iTradingFor[client], giveCurrency, sizeof(giveCurrency));
    GetCurrencyName(g_iTradingWith[client], getCurrency, sizeof(getCurrency));

    Format(giveMsg, sizeof(giveMsg), "You will give: %d %s", g_iTradingForAmount[client], giveCurrency);
    Format(getMsg, sizeof(getMsg), "You will get: %d %s", g_iTradingWithAmount[client], getCurrency);

    if (stage == Trade_FirstAccept)
    {
        decl String:title[64];
        Format(title, sizeof(title), "%N would like to trade", client);

        SetPanelTitle(panel, title);
    }

    else
    {
        SetPanelTitle(panel, "Are you sure? LAST CHANCE");
    }

    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (stage == Trade_SecondAccept)
    {
        DrawPanelText(panel, "Trades after this point will NOT be reversed");
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelText(panel, giveMsg);
    DrawPanelText(panel, getMsg);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (stage == Trade_SecondAccept)
    {
        SetPanelCurrentKey(panel, 5);
        DrawPanelItem(panel, "Press to accept. All trades are final.");
    }

    else
    {
        SetPanelCurrentKey(panel, 4);
        DrawPanelItem(panel, "Accept");
    }

    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    SetPanelCurrentKey(panel, 9);
    DrawPanelItem(panel, "Cancel", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, target, ConfirmWithTargetMenuSelect, PERM_DURATION);
    CloseHandle(panel);
}

stock ConfirmTradeAmount(client, Trade:stage)
{
    new target = g_iTradingTarget[client];

    if (!IsValidTradeTarget(target, client))
    {
        CleanupTrade(client);
        return;
    }

    new Handle:panel = CreatePanel();

    decl String:giveCurrency[16];
    decl String:getCurrency[16];
    decl String:giveMsg[42];
    decl String:getMsg[42];

    GetCurrencyName(g_iTradingWith[client], giveCurrency, sizeof(giveCurrency));
    GetCurrencyName(g_iTradingFor[client], getCurrency, sizeof(getCurrency));

    Format(giveMsg, sizeof(giveMsg), "You will give: %d %s", g_iTradingWithAmount[client], giveCurrency);
    Format(getMsg, sizeof(getMsg), "You will get: %d %s", g_iTradingForAmount[client], getCurrency);

    SetPanelTitle(panel, stage == Trade_ReconfirmAmount ? "Final Confirmation" : "Confirm Trade Amount");
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (stage == Trade_ReconfirmAmount)
    {
        DrawPanelText(panel, "Trades after this point will NOT be reversed");
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelText(panel, giveMsg);
    DrawPanelText(panel, getMsg);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (stage == Trade_ReconfirmAmount)
    {
        SetPanelCurrentKey(panel, 5);
        DrawPanelItem(panel, "Press to accept. All trades are final.");
    }

    else
    {
        SetPanelCurrentKey(panel, 4);
        DrawPanelItem(panel, "Confirm");
    }

    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    SetPanelCurrentKey(panel, 8);
    DrawPanelItem(panel, "Back", ITEMDRAW_CONTROL);

    if (g_iGame != GAMETYPE_CSGO)
    {
        SetPanelCurrentKey(panel, 10);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelItem(panel, "Cancel", ITEMDRAW_CONTROL);

    g_tTradeType[client] = stage;
    SendPanelToClient(panel, client, ConfirmTradeAmountMenuSelect, PERM_DURATION);
    CloseHandle(panel);
}

stock SelectTradeAmount(client, Trade:tradeType)
{
    new target = g_iTradingTarget[client];

    if (!IsValidTradeTarget(target, client))
    {
        CleanupTrade(client);
        return;
    }

    new Handle:panel = CreatePanel();
    new String:currency[16] = "    HG Bux";
    new bool:rep = false;

    decl String:yourbalance[64];
    decl String:theirbalance[64];
    decl String:trademsg[32];
    decl String:maxamount[32];
    decl String:giveCurrency[12];
    decl String:getCurrency[12];

    GetCurrencyName(g_iTradingWith[client], giveCurrency, sizeof(giveCurrency));
    GetCurrencyName(g_iTradingFor[client], getCurrency, sizeof(getCurrency));

    g_tTradeType[client] = tradeType;

    SetPanelTitle(panel, "Select Amount To Trade");
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (tradeType == Trade_With)
    {
        Format(trademsg, sizeof(trademsg), "You would like to give");
        Format(currency, sizeof(currency), "    %s", giveCurrency);
    }

    else
    {
        Format(trademsg, sizeof(trademsg), "You would like to get");
        Format(currency, sizeof(currency), "    %s", getCurrency);
    }

    if ((tradeType == Trade_With && g_iTradingWith[client] != TRADE_CREDITS) ||
        (tradeType == Trade_For && g_iTradingFor[client] != TRADE_CREDITS))
    {
        Format(maxamount, sizeof(maxamount),
               "%s Max Daily: %d",
               tradeType == Trade_With ? "Your" : "Their",
               tradeType == Trade_With ? PrisonRep_TransferLimit(client) : PrisonRep_TransferLimit(target));
        rep = true;
    }

    if (g_iTradingWith[client] == TRADE_CREDITS)
    {
        Format(yourbalance, sizeof(yourbalance), "Your HG Bux: %d", Premium_GetPoints(client));
    }

    else
    {
        Format(yourbalance, sizeof(yourbalance), "Your %s: %d", giveCurrency, PrisonRep_GetPoints(client, g_iTradingWith[client]));
    }

    if (g_iTradingFor[client] == TRADE_CREDITS)
    {
        Format(theirbalance, sizeof(theirbalance), "Their HG Bux: %d", Premium_GetPoints(target));
    }

    else
    {
        Format(theirbalance, sizeof(theirbalance), "Their %s: %d", getCurrency, PrisonRep_GetPoints(target, g_iTradingFor[client]));
    }

    DrawPanelText(panel, yourbalance);
    DrawPanelText(panel, theirbalance);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    DrawPanelText(panel, "Type into chat the amount of");
    DrawPanelText(panel, currency);
    DrawPanelText(panel, trademsg);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (rep || tradeType == Trade_For)
    {
        if (tradeType == Trade_For)
        {
            decl String:youaregiving[42];
            Format(youaregiving, sizeof(youaregiving), "You are giving: %d %s", g_iTradingWithAmount[client], giveCurrency);
            DrawPanelText(panel, youaregiving);
        }

        if (rep)
        {
            DrawPanelText(panel, maxamount);
        }

        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    SetPanelCurrentKey(panel, 8);
    DrawPanelItem(panel, "Back", ITEMDRAW_CONTROL);

    if (g_iGame != GAMETYPE_CSGO)
    {
        SetPanelCurrentKey(panel, 10);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    }

    DrawPanelItem(panel, "Cancel", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, SelectTradeAmountMenuSelect, 0);
    CloseHandle(panel);
}

/* ----- Commands ----- */


public Action:Command_TradeChat(client, args)
{
    if (client <= 0)
    {
        return Plugin_Continue;
    }

    if (!Gag_AllowedToUseChat(client))
    {
        PrintToChat(client, "%s You may not use trade chat while gagged", MSG_PREFIX);
        return Plugin_Stop;
    }

    if (!IsClientCookieFlagSet(client, COOKIE_TRADE_CHAT_ENABLED))
    {
        PrintToChat(client, "%s You have trade chat \x03disabled\x04.", MSG_PREFIX);
        PrintToChat(client, "%s Type \x03!trade\x04 to re-enable", MSG_PREFIX);
        return Plugin_Stop;
    }

    if (GetTime() - g_iLastTradeMessage[client] < 3)
    {
        PrintToChat(client, "%s Wo there buddy, slow down!", MSG_PREFIX);
        return Plugin_Stop;
    }

    decl String:text[255];
    decl String:msg[255];

    GetCmdArgString(text, sizeof(text));
    Format(msg, sizeof(msg), "\x01(\x04Trade\x01) \x03%N\x01: %s", client, text);
    new bool:clientAlive = JB_IsPlayerAlive(client);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientCookieFlagSet(i, COOKIE_TRADE_CHAT_ENABLED))
        {
            if (clientAlive || !JB_IsPlayerAlive(i))
            {
                PrintToChat(i, msg);
            }
        }
    }

    g_iLastTradeMessage[client] = GetTime();
    return Plugin_Stop;
}

public Action:Command_CancelTrade(client, args)
{
    new target = g_iTradingTarget[client];

    if (IsClientInGame(target) && g_tTradeType[client] >= Trade_AmountConfirmed)
    {
        PrintToChat(target, "%s %N has cancelled the trade", MSG_PREFIX, client);
    }

    CleanupTrade(client);
    CleanupTrade(target);

    PrintToChat(client, "%s You have cancelled your currently active trade", MSG_PREFIX);
    return Plugin_Handled;
}

public Action:Command_Trade(client, args)
{
    new Handle:menu = CreateMenu(TradeMainMenu_Select);
    SetMenuTitle(menu, "Trade Menu");

    AddMenuItem(menu, "", g_tTradeType[client] == Trade_None ? "Trade With Players" : "Resume Current Trade");
    AddMenuItem(menu, "", IsClientCookieFlagSet(client, COOKIE_TRADE_CHAT_ENABLED) ? "Disable Trade Chat" : "Enable Trade Chat");
    AddMenuItem(menu, "", "Show Trade Help");
    AddMenuItem(menu, "", "Show Trade Rules");

    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Handled;
}

public Action:Command_TradeHelp(client, args)
{
    if (!client)
        return Plugin_Continue;

    PrintToChat(client,
                "%s All trade chat is currently \x04%s\x01 to you.",
                MSG_PREFIX, IsClientCookieFlagSet(client, COOKIE_TRADE_CHAT_ENABLED) ? "visible" : "invisible");

    PrintToChat(client,
                "%s To %s it, type \x04!toggletrade\x01 in chat",
                MSG_PREFIX, IsClientCookieFlagSet(client, COOKIE_TRADE_CHAT_ENABLED) ? "disabled" : "enable");

    PrintToChat(client,
                "%s To type in trade chat, type /t <message> in regular chat",
                MSG_PREFIX);

    PrintToChat(client,
                "%s All regular rules apply to this chat. Ghosting, racism, disrespect will result in punishment",
                MSG_PREFIX);

    return Plugin_Handled;
}

public Action:Command_TradeRules(client, args)
{
    if (!client)
        return Plugin_Continue;

    DisplayMenu(g_hRulesMenu, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Handled;
}

public Action:Command_ToggleTrade(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (IsClientCookieFlagSet(client, COOKIE_TRADE_CHAT_ENABLED))
    {
        UnsetClientCookieFlag(client, COOKIE_TRADE_CHAT_ENABLED);
        PrintToChat(client, "%s You have \x03disabled\x04 trade chat. Type \x03!toggletrade\x04 to enable it again", MSG_PREFIX);
    }

    else
    {
        SetClientCookieFlag(client, COOKIE_TRADE_CHAT_ENABLED);
        PrintToChat(client, "%s You have \x03enabled\x04 trade chat. Type \x03!toggletrade\x04 to disable it", MSG_PREFIX);
    }

    return Plugin_Handled;
}


/* ----- Callbacks ----- */


public Action:Timer_TradeAdverts(Handle:timer, any:data)
{
    PrintToChatAll("%s All trading/begging of rep/credits/brazzers accounts must be done through \x03Trade Chat\x04. Type \x03!trade\x04 for more info", MSG_PREFIX);
    return Plugin_Continue;
}

public TradeMainMenu_Select(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
        {
            CloseHandle(menu);
        }

        case MenuAction_Select:
        {
            switch (selected)
            {
                // Trade With Players/Resume Current Trade
                case 0:
                {
                    switch (g_tTradeType[client])
                    {
                        case Trade_None:
                        {
                            TradeWithPlayers(client);
                        }

                        case Trade_With:
                        {
                            SelectTradeAmount(client, Trade_With);
                        }

                        case Trade_For:
                        {
                            SelectTradeAmount(client, Trade_For);
                        }

                        case Trade_ConfirmAmount:
                        {
                            ConfirmTradeAmount(client, Trade_ConfirmAmount);
                        }

                        case Trade_AmountConfirmed:
                        {
                            new target = g_iTradingTarget[client];

                            if (IsValidTradeTarget(target, client))
                            {
                                AwaitingFirstConfirmation(client);
                                ConfirmWithTarget(target, Trade_FirstAccept);
                            }
                        }
    
                        case Trade_ReconfirmAmount:
                        {
                            ConfirmTradeAmount(client, Trade_ReconfirmAmount);
                        }

                        case Trade_Accepted:
                        {
                            AskCancelTrade(client);
                        }

                        case Trade_FirstAccept:
                        {
                            ConfirmWithTarget(client, Trade_FirstAccept);
                        }

                        case Trade_SecondAccept:
                        {
                            ConfirmWithTarget(client, Trade_SecondAccept);
                        }

                        case Trade_TargetAccepted:
                        {
                            AskCancelTrade(client);
                        }
                    }
                }

                // Toggle Trade Chat
                case 1:
                {
                    FakeClientCommand(client, "sm_toggletrade");
                }

                // Show Trade Help
                case 2:
                {
                    FakeClientCommand(client, "sm_tradehelp");
                }

                // Show Trade Rules
                case 3:
                {
                    FakeClientCommand(client, "sm_traderules");
                }
            }
        }
    }
}

public CancelTradeMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    // Confirm Cancel
    if (action == MenuAction_Select && selected == 1)
    {
        new owner = GetClientOfTarget(client);
        new target = g_iTradingTarget[client];

        if (owner > 0)
        {
            PrintToChat(owner, "%s %N has cancelled the trade", MSG_PREFIX, client);
            CleanupTrade(owner);
        }

        else
        {
            if (IsClientInGame(target))
            {
                PrintToChat(target, "%s %N has cancelled the trade", MSG_PREFIX, client);
            }

            CleanupTrade(client);
        }
    }
}

public ConfirmWithTargetMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            // Menu left over after a cancelled trade
            if (g_tTradeType[client] != Trade_FirstAccept &&
                g_tTradeType[client] != Trade_SecondAccept)
            {
                return;
            }

            switch (selected)
            {
                // Confirm
                case 4:
                {
                    new owner = GetClientOfTarget(client);
                    if (owner <= 0)
                    {
                        PrintToChat(client, "%s The trade requester has left the server", MSG_PREFIX);
                        CleanupTrade(client);
                    }

                    else
                    {
                        ConfirmTradeAmount(owner, Trade_ReconfirmAmount);
                        ConfirmWithTarget(client, Trade_SecondAccept);
                    }
                }

                // Final Confirmation
                case 5:
                {
                    new owner = GetClientOfTarget(client);

                    if (owner <= 0)
                    {
                        PrintToChat(client, "%s The trade requester has left the server", MSG_PREFIX);
                        CleanupTrade(client);
                    }

                    else
                    {
                        g_tTradeType[client] = Trade_TargetAccepted;
                        CheckTradeComplete(client);
                    }
                }

                // Cancel
                case 9:
                {
                    new owner = GetClientOfTarget(client);

                    if (owner > 0 && IsClientInGame(owner))
                    {
                        DisplayMSay(owner, "Request Denied", 60, "%N has declined your trade", client);
                        CleanupTrade(owner);
                    }

                    CleanupTrade(client);
                }
            }
        }
    }
}

public ConfirmTradeAmountMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            // Trade menu left over after a cancelled trade.
            if (g_tTradeType[client] != Trade_ConfirmAmount &&
                g_tTradeType[client] != Trade_ReconfirmAmount)
                return;

            switch (selected)
            {
                // Confirm
                case 4:
                {
                    new target = g_iTradingTarget[client];

                    if (IsValidTradeTarget(target, client))
                    {
                        AwaitingFirstConfirmation(client);
                        ConfirmWithTarget(target, Trade_FirstAccept);
                    }
                }

                // Final Confirmation
                case 5:
                {
                    g_tTradeType[client] = Trade_Accepted;
                    CheckTradeComplete(client);
                }

                // Back
                case 8:
                {
                    SelectTradeAmount(client, Trade_For);
                }

                default:
                {
                    new target = g_iTradingTarget[client];

                    if (g_tTradeType[client] == Trade_ReconfirmAmount)
                    {
                        if (IsClientInGame(target))
                        {
                            DisplayMSay(target, "Trade Ended", 60, "%N has backed out of the trade", client);
                        }

                        CleanupTrade(target);
                    }

                    CleanupTrade(client);
                }
            }
        }
    }
}

public TradeWithPlayersMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (selected)
            {
                // Trade using cs:s rep
                case 1:
                {
                    g_iTradingWith[client] = TRADE_CSS;
                }

                // Trade using cs:go rep
                case 2:
                {
                    g_iTradingWith[client] = TRADE_CSGO;
                }

                // Trade using tf2 rep
                case 3:
                {
                    g_iTradingWith[client] = TRADE_TF2;
                }

                // Trade using hg bux
                case 4:
                {
                    g_iTradingWith[client] = TRADE_CREDITS;
                }

                // Back
                case 8:
                {
                    FakeClientCommand(client, "sm_trade");
                    return;
                }

                default:
                {
                    return;
                }
            }

            SelectTradeTarget(client);
        }
    }
}

public SelectTradeAmountMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        switch (selected)
        {
            // Back
            case 8:
            {
                if (g_tTradeType[client] == Trade_With)
                {
                    g_tTradeType[client] = Trade_None;
                    SelectTargetCurrency(client);
                }

                else
                {
                    SelectTradeAmount(client, Trade_With);
                }
            }

            // Cancel
            default:
            {
                CleanupTrade(client);
            }
        }
    }
}

public SelectTargetCurrencyMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (selected)
            {
                // Trade using cs:s rep
                case 1:
                {
                    g_iTradingFor[client] = TRADE_CSS;
                }

                // Trade using cs:go rep
                case 2:
                {
                    g_iTradingFor[client] = TRADE_CSGO;
                }

                // Trade using tf2 rep
                case 3:
                {
                    g_iTradingFor[client] = TRADE_TF2;
                }

                // Trade using hg bux
                case 4:
                {
                    g_iTradingFor[client] = TRADE_CREDITS;
                }

                // Back
                case 8:
                {
                    g_iTradingTarget[client] = 0;
                    SelectTradeTarget(client);
                    return;
                }

                default:
                {
                    CleanupTrade(client);
                    return;
                }
            }

            SelectTradeAmount(client, Trade_With);
        }
    }
}

public SelectTradeTargetMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
        {
            CloseHandle(menu);
        }

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
            {
                TradeWithPlayers(client);
            }
        }

        case MenuAction_Select:
        {
            decl String:id[LEN_INTSTRING];
            GetMenuItem(menu, selected, id, sizeof(id));

            new target = GetClientOfUserId(StringToInt(id));

            if (target < 1)
            {
                PrintToChat(client, "%s That player has left the server", MSG_PREFIX);
                SelectTradeTarget(client);
                return;
            }

            g_iTradingTarget[client] = target;
            SelectTargetCurrency(client);
        }
    }
}
