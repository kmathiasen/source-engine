
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

PrisonDice_OnRoundStart()
{
    g_iNumRolled = 0;
    g_iNumRollsAllowed = RoundToCeil(GetTeamClientCount(TEAM_PRISONERS) * g_fRollsAllowedFrac);
    if (g_iNumRollsAllowed < 5)
        g_iNumRollsAllowed = 5;
    new thisTeam;
    for(new i = 1; i <= MaxClients; i++)
    {
        g_bSuperKnife[i] = false;
        g_bHasRolled[i] = false;
        if (IsClientInGame(i))
        {
            thisTeam = GetClientTeam(i);
            if (thisTeam == TEAM_PRISONERS)
                PrintToChat(i, "%s Type \x03!\x01pd\x04 or \x03!\x01rtd\x04 to roll Prison Dice", MSG_PREFIX);
        }
    }
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
    if (!JB_IsPlayerAlive(client))
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

    if (g_iGame == GAMETYPE_TF2)
    {
        new delay = 7 - (GetTime() - g_iRoundStartTime);
        delay = delay > 0 ? delay : 0;

        CreateTimer(float(delay), Timer_DoRoll, GetClientUserId(client));
    }

    else
        Timer_DoRoll(INVALID_HANDLE, GetClientUserId(client));

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

public Action:Timer_DoRoll(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (client <= 0 || !JB_IsPlayerAlive(client))
        return Plugin_Continue;

    // GetRandomFloat() with no parameters returns a random float between 0.0 and 1.0.
    new Float:randnum = GetRandomFloat();
    new bool:goodtogo = true;

    if (g_iGame != GAMETYPE_TF2 && randnum <= 0.205)
    {
        goodtogo = false;

        // Give Flashbang.
        if (randnum <= 0.105)
        {
            GivePlayerItem(client, "weapon_flashbang");
            PrintToChat(client, "%s You got a flashbang.", MSG_PREFIX);
        }

        // Give smoke.
        else if (randnum <= 0.205)
        {
            GivePlayerItem(client, "weapon_smokegrenade");
            PrintToChat(client, "%s You got a smoke.", MSG_PREFIX);
        }
    }

    else if (g_iGame == GAMETYPE_TF2 &&
             (randnum <= 0.205 || randnum >= 0.8))
    {
        goodtogo = false;

        if (randnum <= 0.06)
            PrintToChat(client, "%s You didn't win anything this roll", MSG_PREFIX);

        if (randnum <= 0.09)
        {
            TF2_AddCondition(client, TFCond_Kritzkrieged, 120.0);
            g_bHasKritz[client] = true;

            PrintToChat(client, "%s You got 2 minutes of \x03Unlimited Kritz\x04!", MSG_PREFIX);
        }

        else if (randnum <= 0.11)
        {
            g_bHasUber[client] = true;

            PrintToChat(client,
                        "%s You got an \x03uber\x04 for yourself. Press your \x03taunt\x04 key with a melee to use it!",
                        MSG_PREFIX);
        }

        else if (randnum <= 0.15)
        {
            SetEntData(client, m_flModelScale, 0.5);
            PrintToChat(client, "%s You rolled \x03tiny man\x04!", MSG_PREFIX);
        }

        else if (randnum <= 0.205)
        {
            TF2_MakeBleed(client, client, 12.0);

            PrintToChat(client,
                        "%s You're \x03BLEEEEEEEEEEDING OUT\x04, if it's the last thing that you'll do!",
                        MSG_PREFIX);
        }

        else if (randnum >= 0.8 && randnum <= 0.85)
        {
            TF2_AddCondition(client, TFCond_RestrictToMelee, 300.0);

            PrintToChat(client,
                        "%s For the next \x035\x04 minutes, you can \x03only use melee",
                        MSG_PREFIX);
        }

        else if (randnum > 0.85)
            PrintToChat(client, "%s You didn't win anything this roll", MSG_PREFIX);
    }

    if (goodtogo)
    {
        // Teleport to electric chair.
        if (randnum <= 0.296)
        {
            // Try to tele client to electric chair.
            if (Tele_DoClient(0, client, "Electric Chair", false))
            {
                PrintToChatAll("%s \x03%N\x04 was teleported to \x03the electric chair", MSG_PREFIX, client);

                g_bShouldTrackDisconnect[client] = true;
                g_bIsRebelFromEChair[client] = true;
            }

            else
                PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
        }

        // Teleport to admin room.
        else if (randnum <= 0.3)
        {
            // Try to tele client to admin room.
            if (Tele_DoClient(0, client, "Admin Room", false))
                PrintToChatAll("%s \x03%N\x04 was teleported to \x03the admin room", MSG_PREFIX, client);
            else
                PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
        }

        // Become a rebel for a short time.
        else if (randnum <= 0.41)
        {
            // How many ticks to be a rebel for?  We'll go with arbitrary 5.
            new ticks = 5;

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
            MakeTotalPlayerInvisible(client, true);
        }

        // Give bomb.
        else if (randnum <= 0.6)
        {
            PrintToChat(client, "%s You got the bomb", MSG_PREFIX);

            if (g_iGame == GAMETYPE_TF2)
                GivePlayerBombTF2(client);

            else
                GivePlayerItem(client, "weapon_c4");
        }

        // Give rep.
        else if (randnum <= 0.75)
        {
            // Give rep to player.
            PrisonRep_AddPoints(client, GetConVarInt(g_hCvRepWinDice));
        }

        // Instant kill knife.
        else if (randnum <= 0.8)
        {
            DisplayMSay(client, "You got a Super Knife", MENU_TIMEOUT_QUICK, "The next CT you knife will die");
            PrintToChat(client, "%s You've won a super knife, the next CT you melee will die", MSG_PREFIX);

            g_bSuperKnife[client] = true;
        }

        // Do nothing.  (Add more ideas for PD?)
        else
        {
            PrintToChat(client, "%s Sorry, you did not win anything this roll", MSG_PREFIX);
        }
    }

    return Plugin_Continue;
}
