
new bool:g_bInRPS[MAXPLAYERS + 1];
new Handle:g_hRPSTimers[MAXPLAYERS + 1];

new String:g_sChose[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:g_sRPSOptions[3][MAX_NAME_LENGTH] = {"Rock", "Paper", "Scissors"};

/* ----- Events ----- */


public RPS_OnLRStart(t, ct, const String:arg[])
{
    g_bInRPS[t] = true;
    g_bInRPS[ct] = true;

    ShowRPSMenu(t);
    ShowRPSMenu(ct);
}

public RPS_OnLREnd(t, ct)
{
    if (g_hRPSTimers[t] != INVALID_HANDLE)
        CloseHandle(g_hRPSTimers[t]);
    g_hRPSTimers[t] = INVALID_HANDLE;

    if (g_hRPSTimers[ct] != INVALID_HANDLE)
        CloseHandle(g_hRPSTimers[ct]);
    g_hRPSTimers[ct] = INVALID_HANDLE;

    g_bInRPS[t] = false;
    g_bInRPS[ct] = false;
}

/* ----- Functions ----- */


stock ShowRPSMenu(client)
{
    g_sChose[client][0] = '\0';
    new Handle:menu = CreateMenu(RPSMenuSelect);

    SetMenuTitle(menu, "Choose Your Weapon");
    SetMenuExitButton(menu, false);

    AddMenuItem(menu, "Rock", "Rock");
    AddMenuItem(menu, "Paper", "Paper");
    AddMenuItem(menu, "Scissors", "Scissors");

    if (GetRandomFloat() <= GetConVarFloat(g_hCvLrRpsLaserswordChange))
        AddMenuItem(menu, "", "LASER SWORD!!");

    g_hRPSTimers[client] = CreateTimer(10.0, Timer_ForceRPSChoice, client);
    DisplayMenu(menu, client, 10);
}


stock CheckRPSWinner(client)
{
    new partner = GetPartner(client);
    new winner, loser;

    if (g_sChose[client][0] == '\0' || g_sChose[partner][0] == '\0')
        return;

    if (StrEqual(g_sChose[client], g_sChose[partner]))
    {
        PrintToChatAll("%s \x03%N\x04 and \x03%N\x04 both chose \x03%s\x04 Let's try again!",
                       MSG_PREFIX, client, partner, g_sChose[client]);

        ShowRPSMenu(client);
        ShowRPSMenu(partner);

        return;
    }

    else if (StrEqual(g_sChose[client], "Rock"))
    {
        if (StrEqual(g_sChose[partner], "Paper"))
            winner = partner;

        else
            winner = client;
    }

    else if (StrEqual(g_sChose[client], "Paper"))
    {
        if (StrEqual(g_sChose[partner], "Rock"))
            winner = client;

        else
            winner = partner;
    }

    else
    {
        if (StrEqual(g_sChose[partner], "Rock"))
            winner = partner;

        else
            winner = client;
    }

    loser = winner == client ? partner : client;
    PrintToChatAll("%s \x03%N\x04 won against \x03%N\x04's \x05%s\x04 with \x05%s",
                   MSG_PREFIX, winner, loser, g_sChose[loser], g_sChose[winner]);

    SlapPlayer(loser, GetClientHealth(loser) + 101, false);
}

/* ----- Callbacks ----- */


public RPSMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Cancel || action == MenuAction_Select)
    {
        if (g_hRPSTimers[client] != INVALID_HANDLE)
            CloseHandle(g_hRPSTimers[client]);
        g_hRPSTimers[client] = INVALID_HANDLE;
    }

    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (g_bInRPS[client])
            {
                Format(g_sChose[client], MAX_NAME_LENGTH, g_sRPSOptions[GetRandomInt(0, 2)]);
                CheckRPSWinner(client);
            }
        }

        case MenuAction_Select:
        {
            if (g_bInRPS[client])
            {
                // lol lasersword
                if (selected == 3)
                {
                    new partner = GetPartner(client);
                    SlapPlayer(partner, GetClientHealth(partner) + 101, false);

                    PrintToChatAll("\x01Laser \x03Sword \x04beats\x05 everything\x01!\x03!\x04!\x05! \x04LASERSWORD\x01!\x03!\x04!\x05!\x01!\x03!\x04!\x05!");
                    return;
                }

                GetMenuItem(menu, selected, g_sChose[client], MAX_NAME_LENGTH);
                CheckRPSWinner(client);
            }
        }
    }
}

public Action:Timer_ForceRPSChoice(Handle:timer, any:client)
{
    g_hRPSTimers[client] = INVALID_HANDLE;

    if (IsClientInGame(client) && GetIndex(client) > -1)
    {
        PrintToChat(client, "%s Too slow! Forcing you to pick a weapon...", MSG_PREFIX);

        Format(g_sChose[client], MAX_NAME_LENGTH, g_sRPSOptions[GetRandomInt(0, 2)]);
        CheckRPSWinner(client);
    }
}
