
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// When this variable is zero, Sungod can be used.
new g_iDidSungod;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Sungod_OnPluginStart()
{
    RegConsoleCmd("sungod", Command_Sungod, "Sacrifice yourself for the pleasure of the Sungod");
}

Sungod_OnRoundStart()
{
    if (g_iDidSungod > 0)
        g_iDidSungod--;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Sungod(client, args)
{
    // Sungod can be started by the server, trusted admins, or lead.
    if (client != 0)
    {
        // Get trusted status.
        new bool:isTrusted = false;
        new flags = GetUserFlagBits(client);
        if ((flags & ADMFLAG_CHANGEMAP) || (flags & ADMFLAG_ROOT))
            isTrusted = true;

        // Check if client is lead or trusted.
        else if (!isTrusted &&
                 (!IsClientInGame(client) ||
                  !IsPlayerAlive(client) ||
                  GetClientTeam(client) != TEAM_GUARDS ||
                  client != g_iLeadGuard))
        {
            PrintToChat(client, "%s You must be Lead Guard to activate this command", MSG_PREFIX);
            return Plugin_Handled;
        }

        // Can Sungod command be used?
        if (g_iDidSungod != 0)
        {
            PrintToChat(client, "%s This command may only be called every other round", MSG_PREFIX);
            return Plugin_Handled;
        }
    }

    // Set Sungod command to "used".  It will decrement over the next 2 rounds.
    g_iDidSungod = 2;

    // Send sungod question (menu) to all alive terrorists.
    for (new i = 1; i <= MaxClients; i++)
    {
        // Is this client an in-game & alive terrorist?
        if (!IsClientInGame(i))
            continue;
        if (!IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != TEAM_PRISONERS)
            continue;

        // Send him a menu with the question.
        new Handle:menu = CreateMenu(SungodChoiceSelect);
        SetMenuTitle(menu, "Sacrifice yourself to the Sungod?");
        AddMenuItem(menu, "0", "No");
        AddMenuItem(menu, "1", "Yes");
        SetMenuExitButton(menu, false);
        DisplayMenu(menu, i, MENU_TIMEOUT_NORMAL);
    }

    // Done.
    ReplyToCommandGood(client, "%s The prisoners have been asked if they want to sacrifice themselves to the Sungod", MSG_PREFIX);
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

Sungod_SacrificePlayer(client)
{
    // Is this client an in-game & alive terrorist?
    if (!IsClientInGame(client))
        return;
    if (!IsPlayerAlive(client))
        return;
    if (GetClientTeam(client) != TEAM_PRISONERS)
        return;

    // Get client's position.
    decl Float:eyePos[3];
    decl Float:feetPos[3];
    GetClientEyePosition(client, eyePos);
    GetClientAbsOrigin(client, feetPos);

    // Sounds.
    EmitAmbientSound(g_sSoundExplode, eyePos, client, SNDLEVEL_RAIDSIREN);
    EmitAmbientSound(g_sSoundThunder, eyePos, client, SNDLEVEL_RAIDSIREN, _, _, _, 1.5);

    // Lightning bolt (starts from overhead at a little angle).
    decl Float:lightningSource[3];
    lightningSource[ 0 ] = eyePos[ 0 ] + 150;
    lightningSource[ 1 ] = eyePos[ 1 ] + 150;
    lightningSource[ 2 ] = eyePos[ 2 ] + 800;
    TE_SetupBeamPoints(lightningSource, feetPos, g_iSpriteLightning, 0, 0, 0, 2.0, 10.0, 10.0, 0, 1.0, g_iColorWhite, 3);
    TE_SendToAll();

    // Explosion & smoke.
    new Float:normalVec[3] = {0.0, 0.0, 1.0};
    TE_SetupExplosion(eyePos, g_iSpriteExplosion, 5.0, 1, 0, 50, 40, normalVec);
    TE_SendToAll();
    TE_SetupSmoke(feetPos, g_iSpriteSmoke, 10.0, 3);
    TE_SendToAll();

    // Slay.
    SlapPlayer(client, GetClientHealth(client) + 101);
    PrintToChat(client, "%s Your sacrifice helps to deminish the Sungod's wrath", MSG_PREFIX);

    // Spawn X number of drugs at client's position.
    ServerCommand("gang_spawndrugs %i %i %i %i",
                  GetConVarInt(g_hCvSungodNumDrugsEach),
                  eyePos[0],
                  eyePos[1],
                  eyePos[2]);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public SungodChoiceSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sChoiceValue[LEN_INTSTRING];
        GetMenuItem(menu, selected, sChoiceValue, sizeof(sChoiceValue));
        new choice = StringToInt(sChoiceValue);

        // Player chose yes.
        if (choice == 1)
            Sungod_SacrificePlayer(client);

        // Player chose no.
        else
        {
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
