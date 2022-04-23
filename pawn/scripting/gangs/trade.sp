
new Handle:g_hTradeEnabledCookie = INVALID_HANDLE;
new bool:bTradeChatEnabled[MAXPLAYERS + 1];

/* ----- Events ----- */


stock Trade_OnPluginStart()
{
    RegConsoleCmd("sm_trade", Command_Trade);
    RegConsoleCmd("sm_tradehelp", Command_TradeHelp);
    RegConsoleCmd("sm_toggletrade", Command_ToggleTrade);
    RegConsoleCmd("sm_t", Command_TradeChat);

    CreateTimer(127.29, Timer_TradeAdverts, _, TIMER_REPEAT);

    g_hTradeEnabledCookie = RegClientCookie("hg_gangs_tradechat_enabled", "Enable/Disable trade chat", CookieAccess_Public);
}

stock Trade_OnClientPutInServer(client)
{
    bTradeChatEnabled[client] = false;
}

stock Trade_OnClientCookiesCached(client)
{
    decl String:enabled[2];
    GetClientCookie(client, g_hTradeEnabledCookie, enabled, sizeof(enabled));

    bTradeChatEnabled[client] = StrEqual(enabled, "1");
}


/* ----- Commands ----- */


public Action:Command_TradeChat(client, args)
{
    if (client <= 0)
    {
        return Plugin_Continue;
    }

    decl String:text[255];
    decl String:msg[255];

    GetCmdArgString(text, sizeof(text));
    Format(msg, sizeof(msg), "\x01(\x0\4Trade\x01) \x03%N\x01: %s", client, text);
    new bool:clientAlive = JB_IsPlayerAlive(client);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && bTradeChatEnabled[client])
        {
            if (clientAlive || !JB_IsPlayerAlive(i))
            {
                PrintToChat(i, msg);
            }
        }
    }

    return Plugin_Stop;
}
public Action:Command_Trade(client, args)
{
    new Handle:menu = CreateMenu(TradeMainMenu_Select);
    SetMenuTitle(menu, "Trade Menu");

    AddMenuOption(menu, "", "Trade With Players");
    AddMenuOption(menu, "", btradeChatEnabled[client] ? "Disable Trade Chat" : "Enable Trade Chat");
    AddMenuOption(menu, "", "Show Trade Help");

    DisplayMenu(menu, client, DEFAULT_TIMEOUT);
}

public Action:Command_TradeHelp(client, args)
{
    if (!client)
        return Plugin_Continue;

    PrintToChat(client,
                "%s All trade chat is currently \x04%s\x01 to you.",
                MSG_PREFIX, bTradeChatEnabled[client] ? "visible" : "invisible");

    PrintToChat(client,
                "%s To %s it, type \x04!toggletrade\x01 in chat",
                MSG_PREFIX, bTradeChatEnabled[client] ? "disabled" : "enable");

    PrintToChat(client,
                "%s To type in trade chat, type /t <message> in regular chat",
                MSG_PREFIX);

    PrintToChat(client,
                "%s All regular rules apply to this chat. Ghosting, racism, disrespect will result in punishment",
                MSG_PREFIX);

    return Plugin_Handled;
}

public Action:Command_ToggleTrade(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (bTradeChatEnabled[client])
    {
        SetClientCookie(client, g_hTradeEnabledCookie, "0");
        bTradeChatEnabled[client] = false;
        PrintToChat(client, "%s You have \x03disabled\x04 trade chat. Type \x03!toggletrade\x04 to enable it again", MSG_PREFIX);
    }

    else
    {
        SetClientCookie(client, g_hTradeEnabledCookie, "1");
        bTradeChatEnabled[client] = true;
        PrintToChat(client, "%s You have \x03enabled\x04 trade chat. Type \x03!toggletrade\x04 to disable it", MSG_PREFIX);
    }

    return Plugin_Handled;
}


/* ----- Callbacks ----- */


public Action:Timer_TradeAdverts(Handle:timer, any:data)
{
    PrintToChatAll("%s All trading/begging of rep/credits/brazzers accounts must be done through Trade Chat. Type \x04!trade\x01 for more info", MSG_PREFIX);
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
                // Trade With Players
                case 0:
                {
                    
                }

                // Toggle Trade Chat
                case 1:
                {
                    FakeClinetCommand(client, "sm_toggletrade");
                }

                // Show Trade Help
                case 2:
                {
                    FakeClientCommand(client, "sm_tradehelp");
                }
            }
        }
    }
}
