
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Trackers.
new g_iNumRolled = 0;
new bool:g_bHasRolled[MAXPLAYERS + 1];
new bool:g_bSuperKnife[MAXPLAYERS + 1];

// Declare commonly used ConVars.
new Float:g_fRollsAllowedFrac;
new g_iNumRollsAllowed;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

PrisonDice_OnPluginStart()
{
    RegConsoleCmd("pd", Command_PrisonDice, "A command for Prisoners to roll Prison Dice");
    RegConsoleCmd("rtd", Command_PrisonDice, "A command for Prisoners to roll Prison Dice");
}

PrisonDice_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_fRollsAllowedFrac = GetConVarFloat(g_hCvPrisonDiceRollsFrac);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvPrisonDiceRollsFrac, PrisonDice_OnConVarChange);
}

public PrisonDice_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvPrisonDiceRollsFrac)
        g_fRollsAllowedFrac = GetConVarFloat(g_hCvPrisonDiceRollsFrac);
}

PrisonDice_OnRndStrt_General()
{
    g_iNumRolled = 0;
    g_iNumRollsAllowed = RoundToCeil(GetTeamClientCount(TEAM_PRISONERS) * g_fRollsAllowedFrac);
    if (g_iNumRollsAllowed < 5)
        g_iNumRollsAllowed = 5;
}

PrisonDice_OnRndStrt_EachValid(client, team)
{
    // Notify about playing Prison Dice, and reset their state to "not rolled".
    if (team == TEAM_PRISONERS)
    {
        PrintToChat(client, "%s Type \x03!\x01pd\x04 or \x03!\x01rtd\x04 to roll Prison Dice", MSG_PREFIX);
        g_bHasRolled[client] = false;
    }
}

PrisonDice_OnRndStrt_EachClient(client)
{
    g_bSuperKnife[client] = false;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_PrisonDice(client, args)
{
    if (GetCmdReplySource() != SM_REPLY_TO_CHAT)
        return Plugin_Continue;

    // Player must be in-game and alive.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }
    if (!IsPlayerAlive(client))
    {
        PrintToChat(client, "%s This command requires you to be alive", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Roller must be a T.
    new team = GetClientTeam(client);
    if (team != TEAM_PRISONERS)
    {
        PrintToChat(client, "%s Only Prisoners can roll for prison dice", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Has the total allowed rolls happened already?
    if (g_iNumRolled >= g_iNumRollsAllowed)
    {
        PrintToChat(client, "%s Sorry, there has already been %i rolls this round", MSG_PREFIX, g_iNumRollsAllowed);
        return Plugin_Handled;
    }

    // Have they already rolled?
    if (g_bHasRolled[client])
    {
        PrintToChat(client, "%s You have already rolled this round", MSG_PREFIX);
        return Plugin_Handled;
    }

    // set their state to already rolled.
    g_bHasRolled[client] = true;

    // GetRandomFloat() with no parameters returns a random float between 0.0 and 1.0.
    new Float:randnum = GetRandomFloat();

    // Teleport to electric chair.
    if (randnum <= 0.091)
    {
        // Try to tele client to electric chair.
        if (Tele_DoClient(0, client, "Electric Chair", false))
        {
            PrintToChatAll("%s \x03%N\x04 was teleported to \x03the electric chair", MSG_PREFIX, client);
            g_bShouldTrackDisconnect[client] = true;
        }

        else
            PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
    }

    // Teleport to admin room.
    else if (randnum <= 0.095)
    {
        // Try to tele client to admin room.
        if (Tele_DoClient(0, client, "Admin Room", false))
            PrintToChatAll("%s \x03%N\x04 was teleported to \x03the admin room", MSG_PREFIX, client);
        else
            PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
    }

    // Give flashbang.
    else if (randnum <= 0.2)
    {
        GivePlayerItem(client, "weapon_flashbang");
        PrintToChat(client, "%s You got a flashbang.", MSG_PREFIX);
    }

    // Give smoke.
    else if (randnum <= 0.3)
    {
        GivePlayerItem(client, "weapon_smokegrenade");
        PrintToChat(client, "%s You got a smoke.", MSG_PREFIX);
    }

    // Become a rebel for a short time.
    else if (randnum <= 0.41)
    {
        // How many ticks to be a rebel for?  We'll go with arbitrary 3.
        new ticks = 4;

        // Set rebel status and turn player red.
        if (g_hMakeNonRebelTimers[client] != INVALID_HANDLE)
            CloseHandle(g_hMakeNonRebelTimers[client]);

        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], 255);

        // Notify.
        new Float:rebel_tick_timespan = GetConVarFloat(g_hCvRebelSecondsPerTick);

        g_hMakeNonRebelTimers[client] = CreateTimer(ticks * rebel_tick_timespan, RebelTrk_ResetRebelStatus, GetClientUserId(client));

        for (new i = 0; i < 3; i++)
        {
            PrintToChat(client, "%s You turned red for \x03%i\x04 seconds", MSG_PREFIX, RoundToNearest(ticks * rebel_tick_timespan));
            PrintToChat(client, "%s If someone shoots you while red, it's not freekilling", MSG_PREFIX);
        }

        PrintCenterText(client, "You became a rebel from Prison Dice");
        PrintHintText(client, "You became a rebel from Prison Dice");

        decl String:display[255];
        Format(display, sizeof(display),
               "You turned red for %d seconds\nYou are classified as a rebel!",
               RoundToNearest(ticks * rebel_tick_timespan));

        DisplayMSay(client, "You Turned Red", MENU_TIMEOUT_QUICK, display);
    }

    // Teleport to 1st cell.
    else if (randnum <= 0.45)
    {
        // Try to tele client to first cell.
        if (Tele_DoClient(0, client, "First Cell", false))
            PrintToChatAll("%s \x03%N\x04 was teleported to \x03the first cell", MSG_PREFIX, client);
        else
            PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
    }

    // Turn invisible.
    else if (randnum <= 0.49)
    {
        MakeTotalPlayerInvisible(client);
    }

    // Give bomb.
    else if (randnum <= 0.6)
    {
        PrintToChat(client, "%s You got the bomb", MSG_PREFIX);
        GivePlayerItem(client, "weapon_c4");
    }

    // Give rep.
    else if (randnum <= 0.75)
    {
        // Give rep to player.
        PrisonRep_AddPoints(client, GetConVarInt(g_hCvRepWinDice));
    }

    // Instant kill knife
    else if (randnum <= 0.8)
    {
        DisplayMSay(client, "You got a Super Knife", MENU_TIMEOUT_QUICK, "The next CT you knife will die");
        PrintToChat(client, "%s You've won a super knife, the next CT you knife will die", MSG_PREFIX);

        g_bSuperKnife[client] = true;
    }

    // Do nothing.  (Add more ideas for PD?)
    else
    {
        PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
    }

    // Increment number of rolls that have happened.
    g_iNumRolled += 1;

    // Let other people have a chance to roll.
    if (g_iCommandDelay[client] > 0 && (GetTime() - g_iRoundStartTime) < g_iCommandDelay[client])
    {
        PrintToChat(client,
                    "%s Give others a chance. You can use this command again in \x03%d\x04 seconds",
                    MSG_PREFIX, g_iCommandDelay[client] - (GetTime() - g_iRoundStartTime));
        return Plugin_Handled;
    }

    g_iCommandDelay[client] = 4;

    return Plugin_Handled;
}
