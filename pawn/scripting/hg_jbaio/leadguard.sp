
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// Lead Guard globals.
new g_iLeadGuard = 0;
new g_iLeadDiedAt = 0;
new g_iLastLead = 0;
new g_iFireCount = 0;
new g_iFireVotes[MAXPLAYERS + 1];                           // Array to hold who voted to fire the lead guard.
new g_iLeadBlockRounds[MAXPLAYERS + 1];                     // Array to hold how many rounds a fired lead is blocked from re-taking lead.
new g_iConsecutiveFires[MAXPLAYERS + 1];                    // How many consecutive rounds someone has voted to fire.
new bool:g_bAlreadyVoted[MAXPLAYERS + 1];                   // Holds if a client has voted to fire someone the current round
new Handle:g_hRegenerateTimer = INVALID_HANDLE;             // Repeating timer for the lead's health regeneration.
new Handle:g_hWantToLead = INVALID_HANDLE;                  // Array to hold who wants lead at round start. We collect everyone who attempts to get lead in the first 2 seconds, and randomly choose 1.
new Handle:g_hSelectLead = INVALID_HANDLE;                  // Timer to select the lead. 
new bool:g_bSuccessfulRound[MAXPLAYERS + 1];                // Tracks lead guards who have had a successful round (gotten to LR).

// Declare commonly used ConVars.
new g_iLeadRegenerateAmount;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

LeadGuard_OnPluginStart()
{
    RegConsoleCmd("lead", Command_SubmitLead, "A command for Guards to become Lead Guard");
    RegConsoleCmd("pass", Command_PassLead, "A command for the Lead Guard to step down as Lead.");
    RegConsoleCmd("fire", Command_VoteFire, "A command for elidgible players to vote to elect a new Lead Guard");

    // Whenver the plugin is reloaded, people no longer have successful days recorded.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_GUARDS)
            g_bSuccessfulRound[i] = true;
    }

    g_hWantToLead = CreateArray();
}

LeadGuard_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_iLeadRegenerateAmount = GetConVarInt(g_hCvLeadRegenerateAmount);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvLeadRegenerateAmount, LeadGuard_OnConVarChange);
}

public LeadGuard_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvLeadRegenerateAmount)
        g_iLeadRegenerateAmount = GetConVarInt(g_hCvLeadRegenerateAmount);
}

LeadGuard_OnRndStrt_General()
{
    if (g_hSelectLead != INVALID_HANDLE)
        CloseHandle(g_hSelectLead);

    g_iLeadGuard = 0;
    g_iLastLead = 0;
    g_iFireCount = 0;
    g_iLeadDiedAt = 0;

    ClearArray(g_hWantToLead);
    g_hSelectLead = CreateTimer(2.0, Timer_SelectRandomLead);

    // Kill and restart the repeating timer for lead's health regeneration.
    // If the frequency ConVar was changed any time during the previous round,
    // the new value will take effect now.
    if (g_hRegenerateTimer != INVALID_HANDLE)
        CloseHandle(g_hRegenerateTimer);
    g_hRegenerateTimer = CreateTimer(GetConVarFloat(g_hCvLeadRegenerateEvery),
                                     Timer_RegenerateHealth, _, TIMER_REPEAT);
}

LeadGuard_OnRndStrt_EachValid(client, team)
{
    // Notify about being Lead Guard.
    if (team == TEAM_GUARDS) PrintToChat(client, "%s Type \x03!\x01lead\x04 to be Lead Guard", MSG_PREFIX);

    // Decrement number of rounds a fired lead is blocked.
    if (g_iLeadBlockRounds[client] > 0) g_iLeadBlockRounds[client]--;

    // Decrement number of consecutive rounds a player has used !fire
    // Only if they haven't already voted to fire someone.
    if (!g_bAlreadyVoted[client] &&
         g_iConsecutiveFires[client] > 0)
         g_iConsecutiveFires[client]--;
    g_bAlreadyVoted[client] = false;
}

LeadGuard_OnClientPutInServer(client)
{
    g_bSuccessfulRound[client] = false;
}

LeadGuard_OnClientDisconnect(client)
{
    // If this was the lead guard who disconnected, reset lead.
    if (client == g_iLeadGuard)
    {
        // Reset lead.
        g_iLeadGuard = 0;
        g_iLeadDiedAt = GetTime();

        // Notify.
        if (g_iEndGame == ENDGAME_NONE)
        {
            PrintToChatAll("%s Lead Guard disconnected!!!", MSG_PREFIX);
            PrintToChatAll("%s Lead Guard disconnected!!!", MSG_PREFIX);
            PrintToChatAll("%s Lead Guard disconnected!!!", MSG_PREFIX);
            PrintToChatAll("%s \x03Guards:\x04 type \x03!\x01lead\x04 to compete for lead", MSG_PREFIX);
            EmitSoundToAll(g_sSoundFail);
        }
    }

    // Clear out the number of rounds this client may be blocked for taking lead.
    g_iLeadBlockRounds[client] = 0;

    // Reset the consecutive fires trackers.
    g_iConsecutiveFires[client] = 0;
    g_bAlreadyVoted[client] = false;
}

LeadGuard_OnPlayerDeath(client)
{
    // If this was the lead guard who died, reset lead.
    if (client == g_iLeadGuard)
    {
        // Reset lead.
        g_iLeadGuard = 0;
        g_iLeadDiedAt = GetTime();

        // Notify.
        if (g_iEndGame == ENDGAME_NONE)
        {
            PrintToChatAll("%s Lead Guard is Dead!!!", MSG_PREFIX);
            PrintToChatAll("%s Lead Guard is Dead!!!", MSG_PREFIX);
            PrintToChatAll("%s Lead Guard is Dead!!!", MSG_PREFIX);
            PrintToChatAll("%s \x03Guards:\x04 type \x03!\x01lead\x04 to compete for lead", MSG_PREFIX);
            EmitSoundToAll(g_sSoundFail);
        }

        OnLeadDeath(client);
    }
}

LeadGuard_EndGameTime()
{
    // Record a successful round for lead.
    if (g_iLeadGuard && JB_IsPlayerAlive(g_iLeadGuard))
    {
        if (!g_bSuccessfulRound[g_iLeadGuard])
            PrintToChat(g_iLeadGuard,
                        "%s You made a successful round, and can now use \x03!warday",
                        MSG_PREFIX);
        g_bSuccessfulRound[g_iLeadGuard] = true;
    }

    // Give rep to lead.
    if (g_iLeadGuard && IsClientInGame(g_iLeadGuard) && JB_IsPlayerAlive(g_iLeadGuard))
    {
        PrintToChat(g_iLeadGuard, "%s Here's some rep for making it to LR", MSG_PREFIX);
        PrisonRep_AddPoints(g_iLeadGuard, GetConVarInt(g_hCvRepMakeItToLr));
    }
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################


public Action:Command_SubmitLead(client, args)
{
    // Submitter must be in-game.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }

    // If player is dead...
    if (!JB_IsPlayerAlive(client))
    {
        // If there is a lead, say who it is.
        if (g_iLeadGuard > 0)
        {
            if (IsClientInGame(g_iLeadGuard))
            {
                PrintToChat(client, "%s \x03%N\x04 is the Lead Guard", MSG_PREFIX, g_iLeadGuard);
                return Plugin_Handled;
            }
        }

        // Else, say there is no lead.
        PrintToChat(client, "%s There is currently no Lead Guard", MSG_PREFIX);
        return Plugin_Handled;
    }

    // If lead is already taken (greater than zero), deny this submitter lead.
    if (g_iLeadGuard > 0)
    {
        if (IsClientInGame(g_iLeadGuard))
        {
            PrintToChat(client, "%s \x03%N\x04 is the Lead Guard", MSG_PREFIX, g_iLeadGuard);
            return Plugin_Handled;
        }
    }

    // Lead must be a Guard.
    new team = GetClientTeam(client);
    if (team != TEAM_GUARDS)
    {
        PrintToChat(client, "%s Only Guards can be lead", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Submitter must be unmuted (the Lead needs to be able to speak; otherwise he can't give orders).
    if (GetClientListeningFlags(client) & VOICE_MUTED)
    {
        PrintToChat(client, "%s Sorry, you are in a muted state", MSG_PREFIX);
        return Plugin_Handled;
    }

    // People have been doing pass;lead in order to reset their fire amount
    if (g_iLastLead == client)
    {
        PrintToChat(client, "%s You can not step down and then take lead", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Is client currently blocked from becoming lead for a few rounds (due to being fired)?
    new blocked_rounds = g_iLeadBlockRounds[client];
    if (blocked_rounds > 0)
    {
        PrintToChat(client, "%s You are blocked from taking Lead for %i round(s) due to being fired/passing.", MSG_PREFIX, blocked_rounds);
        return Plugin_Handled;
    }

    // Let other people have a chance to lead.
    if (g_iCommandDelay[client] > 0 && (GetTime() - g_iRoundStartTime) < g_iCommandDelay[client])
    {
        PrintToChat(client,
                    "%s Give others a chance. You can use this command again in \x03%d\x04 seconds",
                    MSG_PREFIX, g_iCommandDelay[client] - (GetTime() - g_iRoundStartTime));
        return Plugin_Handled;
    }

    // There can only be a lead if it's currently a normal day.
    if (g_iEndGame != ENDGAME_NONE)
    {
        PrintToChat(client, "%s There can only be a Lead during a normal day", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (g_hSelectLead == INVALID_HANDLE)
        MakeLead(client);

    else if (FindValueInArray(g_hWantToLead, client) == -1)
    {
        PrintToChat(client, "%s You have submitted your application to be lead", MSG_PREFIX);
        PrintToChat(client, "%s Lead is randomly chosen from all applicants \x03two\x04 seconds after round start", MSG_PREFIX);

        PushArrayCell(g_hWantToLead, client);
    }

    else
    {
        PrintToChat(client, "%s You have already submitted your application to be lead", MSG_PREFIX);
        PrintToChat(client, "%s Lead is randomly chosen from all applicants \x03two\x04 seconds after round start", MSG_PREFIX);
    }

    return Plugin_Handled;
}

public Action:Command_VoteFire(client, args)
{
    // Voter must be in-game.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }

    // Don't let people troll, and fire during warday, lr, last CT.
    if (g_iEndGame != ENDGAME_NONE)
    {
        PrintToChat(client, "%s You can only fire when there is no endgame", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Is there a even lead guard assigned yet?
    if (g_iLeadGuard <= 0)
    {
        PrintToChat(client, "%s Nobody is Lead Guard right now", MSG_PREFIX, g_iLeadGuard);

        // Reset just to be safe (incase, the lead D/C'd).
        g_iFireCount = 0;
        for (new i = 1; i <= MaxClients; i++)
        {
            g_iFireVotes[i] = 0;
        }
        return Plugin_Handled;
    }

    // Has this voter already cast a vote?
    if (g_iFireVotes[client] != 0)
    {
        PrintToChat(client, "%s You have already cast a vote to fire this Lead Guard", MSG_PREFIX);
        return Plugin_Handled;
    }

    // The lead himself can't fire himself.
    if (client == g_iLeadGuard)
    {
        PrintToChat(client, "%s You can't vote to fire yourself", MSG_PREFIX);
        PrintToChat(client, "%s Type \x03!\x01pass\x04 to pass lead", MSG_PREFIX);
        return Plugin_Handled;
    }

    // The lead can only be fired when it's a normal day (since otherwise there is no lead anyway).
    if (g_iEndGame != ENDGAME_NONE)
    {
        PrintToChat(client, "%s There is no Lead to fire when it's a special day", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Grab how much it costs for them to fire, based on how many times they've used the command.
    new fireRepCost = GetConVarInt(g_hCvRepCostFire);
    new temp_cost = fireRepCost + (g_iConsecutiveFires[client] * fireRepCost);

    // Does he have the required prison rep?
    new rep = PrisonRep_GetPoints(client);
    if (rep < temp_cost)
    {
        PrintToChat(client, "%s Voting costs \x01%i\x04 prison rep, but you only have \x01%i", MSG_PREFIX, temp_cost, rep);
        return Plugin_Handled;
    }

    // Deduct the rep cost.
    PrisonRep_AddPoints(client, -temp_cost);

    // Record vote.
    g_iFireVotes[client] = 1;
    g_iFireCount += 1;

    // Count all players.
    new total_players = GetTotalPlayers();

    // How many votes needed to fire?
    new needed_to_fire = RoundToNearest(total_players * GetConVarFloat(g_hCvLeadFireRatio));

    // Notify everyone of this vote.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (i == client)
            PrintToChat(i, "%s You voted to fire \x03%N\x04 (\x01%i\x04 / \x01%i\x04)", MSG_PREFIX, g_iLeadGuard, g_iFireCount, needed_to_fire);

        else if (client != g_iLeadGuard)
            PrintToChat(i, "%s \x03%N\x04 voted to fire \x03%N", MSG_PREFIX, client, g_iLeadGuard);
    }

    // Increment how many consecutive rounds they've fired.
    // And make sure not to decrease this amount on round start (by setting g_bAlreadyVoted[client] to true)
    g_iConsecutiveFires[client]++;
    g_bAlreadyVoted[client] = true;

    // Notify them how much it now costs to fire.
    // And use good grammars... ;)

    if (g_iConsecutiveFires[client] == 1)
        PrintToChat(client,
                    "%s This is your \x031\x01st\x04 round using fire. It now costs you \x03%d\x04 rep to fire",
                    MSG_PREFIX, temp_cost + fireRepCost);

    else
        PrintToChat(client,
                    "%s This is your \x03%d\x01th\x04 round using fire. It now costs you \x03%d\x04 rep to fire",
                    MSG_PREFIX, g_iConsecutiveFires[client],
                    temp_cost +  fireRepCost);

    // Should we fire?
    if (g_iFireCount >= needed_to_fire)
    {
        // Try to tele client to electric chair.
        if (Tele_DoClient(0, g_iLeadGuard, "Electric Chair", false))
        {
            decl String:lead_name[MAX_NAME_LENGTH];
            GetClientName(g_iLeadGuard, lead_name, sizeof(lead_name));
            PrintToChatAll("%s \x03%s\x04 was fired and sent to \x03the electric chair", MSG_PREFIX, lead_name);
            PrintToChatAll("%s \x03%s\x04 was fired and sent to \x03the electric chair", MSG_PREFIX, lead_name);
            PrintToChatAll("%s \x03%s\x04 was fired and sent to \x03the electric chair", MSG_PREFIX, lead_name);
        }
        else
        {
            decl String:lead_name[MAX_NAME_LENGTH];
            GetClientName(g_iLeadGuard, lead_name, sizeof(lead_name));
            ForcePlayerSuicide(g_iLeadGuard);
            PrintToChatAll("%s \x03%s\x04 was fired and slayed", MSG_PREFIX, lead_name);
            PrintToChatAll("%s \x03%s\x04 was fired and slayed", MSG_PREFIX, lead_name);
            PrintToChatAll("%s \x03%s\x04 was fired and slayed", MSG_PREFIX, lead_name);
        }

        // Play sound.
        EmitSoundToAll(g_sSoundFail);

        // For each person who voted to fire...
        g_iFireCount = 0;
        new Float:fireRepGiveBackPercent = GetConVarFloat(g_hCvRepFireGiveBackPercent);
        for (new i = 1; i <= MaxClients; i++)
        {
            // Did they vote?
            if (g_iFireVotes[i] == 0) continue;

            temp_cost = fireRepCost + ((g_iConsecutiveFires[client] - 1) * fireRepCost);

            // The fire worked so it was probably a legitimately bad lead.
            // So give back the rep they spent.
            // No need to check if he is in-game or authorized, or to notify him that he is getting rep.
            //    PrisonRep_AddPoints() does those thigns.
            PrisonRep_AddPoints(i, RoundToNearest(temp_cost * fireRepGiveBackPercent));

            // Reset their vote.
            g_iFireVotes[i] = 0;
        }


        // Set him to be blocked for a certain number of rounds from claiming Lead.
        g_iLeadBlockRounds[g_iLeadGuard] = GetConVarInt(g_hCvLeadFiredRoundsToBlock);

        // Fire.
        g_iLeadGuard = 0;
        g_iLeadDiedAt = GetTime();

        // Notify.
        PrintToChatAll("%s \x03Guards:\x04 type \x03!\x01lead\x04 to compete for lead", MSG_PREFIX);
    }

    // Done.
    return Plugin_Handled;
}

public Action:Command_PassLead(client, args)
{
    // Submitter must be in-game and alive.
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

    // Is this person the Lead or not?
    if (client != g_iLeadGuard)
    {
        PrintToChat(client, "%s Only the Lead Guard can pass the Lead", MSG_PREFIX, client);
        return Plugin_Handled;
    }

    // The lead can only be passed when it's a normal day (since otherwise there is no lead anyway).
    if (g_iEndGame != ENDGAME_NONE)
    {
        PrintToChat(client, "%s There is no Lead to pass when it's a special day", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Pass it.
    g_iLeadGuard = 0;
    g_iLeadDiedAt = GetTime();

    // Make it so they can't actually lead again this round.
    g_iLeadBlockRounds[client] = 1;

    for (new i = 1; i <= MaxClients; i++)
    {
        g_iFireVotes[i] = 0;
    }

    // Notify everyone that he stepped down.
    decl String:lead_name[MAX_NAME_LENGTH];
    GetClientName(client, lead_name, sizeof(lead_name));

    PrintToChatAll("%s \x03%s\x04 stepped down", MSG_PREFIX, lead_name);
    PrintToChatAll("%s \x03%s\x04 stepped down", MSG_PREFIX, lead_name);
    PrintToChatAll("%s \x03%s\x04 stepped down", MSG_PREFIX, lead_name);
    PrintToChatAll("%s \x03Guards:\x04 type \x03!\x01lead\x04 to compete for lead", MSG_PREFIX);

    // Play sound.
    EmitSoundToAll(g_sSoundFail);

    // Prevent abusing of becoming lead, then stepping down, by taking away the health bonus when they step down.
    // But make sure their health never goes below 10, just to be nice.
    if (g_iGame == GAMETYPE_TF2)
    {
        TF2_SetHealthBonus(client, 0);
        g_fPlayerSpeed[client] -= 25.0;
    }

    new iSetHealth = GetClientHealth(client) - GetConVarInt(g_hCvLeadHpBonus);

    if (iSetHealth < 10)
        SetEntityHealth(client, 10);
    else
        SetEntityHealth(client, iSetHealth);

    if (g_iGame != GAMETYPE_TF2)
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);

    PrintToChat(client, "%s You have lost your health bonus", MSG_PREFIX);

    // How many votes needed to fire?
    new Float:ratio = GetConVarFloat(g_hCvLeadFireRatio);
    new needed_to_fire = RoundToNearest(GetTotalPlayers() * ratio);

    // If they have a lot of votes, let's teleport them anyways.
    if ((float(g_iFireCount) / needed_to_fire) >= GetConVarFloat(g_hCvLeadPassPercent))
    {
        // Error in finding the coordinates.
        if (!Tele_DoClient(0, client, "Electric Chair", false))
        {
            ForcePlayerSuicide(client);
            PrintToChatAll("%s \x03%N\x04 has high fire votes, and was slayed anyways",
                           MSG_PREFIX, client);
        }
        else
        {
            PrintToChatAll("%s \x03%N\x04 has high fire votes, and was sent to electric chair anyways",
                           MSG_PREFIX, client);
        }

        // Set him to be blocked for a certain number of rounds from claiming Lead.
        g_iLeadBlockRounds[client] = GetConVarInt(g_hCvLeadFiredRoundsToBlock);
    }

    // Reset votes.
    g_iFireCount = 0;

    // Done.
    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

stock MakeLead(client)
{
    g_iCommandDelay[client] = 3;

    g_iLeadGuard = client;
    g_iLastLead = client;

    // Notify.
    decl String:name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    PrintToChatAll("%s \x03%s\x04 is Lead Guard!!!", MSG_PREFIX, name);
    PrintToChatAll("%s \x03%s\x04 is Lead Guard!!!", MSG_PREFIX, name);
    PrintToChatAll("%s \x03%s\x04 is Lead Guard!!!", MSG_PREFIX, name);
    PrintToChat(client, "%s Type \x03!\x01pass\x04 to pass Lead", MSG_PREFIX);

    // Notify how much rep it costs that player to fire.
    // It's different for everyone so can't just do a PrintToChatAll.
    new fireRepCost = GetConVarInt(g_hCvRepCostFire);
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            PrintToChat(i,
                        "%s Prisoners may type \x03!\x01fire\x04 to fire (costs %i rep)",
                        MSG_PREFIX, fireRepCost + (g_iConsecutiveFires[i] * fireRepCost));
    }

    PrintCenterTextAll("%s is Lead", name);
    PrintHintTextToAll("%s is Lead", name);

    // Play sound.
    EmitSoundToAll(g_sSoundPowerup);

    // Give the lead a health bonus
    PrintToChat(client, "%s You've obtained a health bonus", MSG_PREFIX);

    if (g_iGame == GAMETYPE_TF2)
    {
        new bonus = RoundToNearest(GetTeamClientCount(TEAM_PRISONERS) * GetConVarFloat(g_hCvCtHealthBonusPerT)) + GetConVarInt(g_hCvLeadHpBonus);

        TF2_SetHealthBonus(client, bonus);
        SetEntityHealth(client, GetClientHealth(client) + bonus);

        g_fPlayerSpeed[client] += 25.0;
    }

    else
        SetEntityHealth(client, GetClientHealth(client) + GetConVarInt(g_hCvLeadHpBonus));

    // give them a helmet, to protect from headshots
    if (g_iGame != GAMETYPE_TF2)
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);

    // Reset fire vote count.
    g_iFireCount = 0;

    // Reset everyone's votes to fire the lead, so they can vote again.
    for (new i = 1; i <= MaxClients; i++)
        g_iFireVotes[i] = 0;
}

LeadGuard_CheckLead(client)
{
    if (GetClientTeam(client) != TEAM_GUARDS ||
        !JB_IsPlayerAlive(client))
        return;

    decl String:command[2];
    GetCmdArg(1, command, sizeof(command));

    // They want lead. Make them execute the "lead" command.
    if (command[0] == '!')
        FakeClientCommand(client, "lead");
}

GetTotalPlayers()
{
    return GetTeamClientCount(TEAM_GUARDS) + GetTeamClientCount(TEAM_PRISONERS);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################


public Action:Timer_SelectRandomLead(Handle:timer, any:data)
{
    g_hSelectLead = INVALID_HANDLE;

    while (GetArraySize(g_hWantToLead))
    {
        new index = GetRandomInt(0, GetArraySize(g_hWantToLead) - 1);
        new client = GetArrayCell(g_hWantToLead, index);

        if (!IsClientInGame(client) ||
            !JB_IsPlayerAlive(client) ||
            GetClientTeam(client) != TEAM_GUARDS || 
            GetClientListeningFlags(client) & VOICE_MUTED ||
            g_iLeadBlockRounds[client] > 0)
            RemoveFromArray(g_hWantToLead, index);

        else
        {
            MakeLead(client);
            break;
        }
    }
}

public Action:Timer_RegenerateHealth(Handle:timer, any:data)
{
    if (g_iLeadGuard &&
        g_iEndGame == ENDGAME_NONE &&
        IsClientInGame(g_iLeadGuard) &&
        JB_IsPlayerAlive(g_iLeadGuard) &&
        GetClientHealth(g_iLeadGuard) < 100)
        SetEntityHealth(g_iLeadGuard,
                        GetClientHealth(g_iLeadGuard) + g_iLeadRegenerateAmount);

    return Plugin_Continue;
}
