
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Buttons.
new g_iBtn_CellOpener1 = INVALID_ENT_REFERENCE;
new g_iBtn_CellOpener2 = INVALID_ENT_REFERENCE;
new g_iBtn_KnfArnaLzrs_Mid = INVALID_ENT_REFERENCE;
new g_iBtn_KnfArnaLzrs_T = INVALID_ENT_REFERENCE;
new g_iBtn_KnfArnaLzrs_CT = INVALID_ENT_REFERENCE;
new g_iBtn_KnfArnaLzrs_Mstry = INVALID_ENT_REFERENCE;
new g_iBtn_DuckHuntLzrs = INVALID_ENT_REFERENCE;
new g_iBtn_SmallBall = INVALID_ENT_REFERENCE;
new g_iBtn_BigBall = INVALID_ENT_REFERENCE;
new g_iTele_FirstCell = INVALID_ENT_REFERENCE;

// Store when a door was last opened/closed
new Handle:g_hDoorLastUsed = INVALID_HANDLE;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

MapEnts_OnPluginStart()
{
    // Hook func button so we can tell who opened the cells.
    HookEntityOutput("func_button", "OnPressed", MapEnts_OnButtonPressed);
    HookEntityOutput("trigger_teleport", "OnStartTouch", MapEnts_OnTeleported);

    g_hDoorLastUsed = CreateTrie();
}

MapEnts_OnRoundStart()
{
    // It was recommended on the SM forums to give a delay
    // before finding items to ensure they are fully created.
    CreateTimer(1.3, MapEnts_GetEntIndexes);
    CreateTimer(1.5, MapEnts_PreHookEnts);
}

public MapEnts_OnTeleported(const String:output[], entity, activator, Float:delay)
{
    if (activator <= 0 ||
        activator > MaxClients || 
        !IsClientInGame(activator) ||
        !JB_IsPlayerAlive(activator))
        return;

    if (g_iEndGame == ENDGAME_NONE &&
        entity == g_iTele_FirstCell &&
        GetClientTeam(activator) == TEAM_PRISONERS)
        MakeRebelTime(activator, GetConVarFloat(g_hCvRebelTele), REBELTYPE_TELE);
}

public MapEnts_OnButtonPressed(const String:output[], entity, activator, Float:delay)
{
    // debug
    // decl String:pos[3];
    // GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
    // PrintToConsoleAll("%N pressed a buttonn at %f %f %f", pos[0], pos[1], pos[2]);

    // Was it a cell opener button?
    if ((entity == g_iBtn_CellOpener1 || entity == g_iBtn_CellOpener2) && !g_bAreCellsOpened)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
            PrintToChatAll("%s \x03%N%\x04 opened the cells", MSG_PREFIX, activator);
        else
            PrintToChatAll("%s The cells have opened", MSG_PREFIX);
        g_bAreCellsOpened = true;
        CellsOpened();
    }

    // Was it a knife arena button (middle)?
    else if (entity == g_iBtn_KnfArnaLzrs_Mid)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
            PrintToChat(activator, "%s You pressed Knife Arena Lazers button (MID)", MSG_PREFIX);
    }

    // Was it a knife arena button (T)?
    else if (entity == g_iBtn_KnfArnaLzrs_T)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
            PrintToChat(activator, "%s You pressed Knife Arena Lazers button (T)", MSG_PREFIX);
    }

    // Was it a knife arena button (CT)?
    else if (entity == g_iBtn_KnfArnaLzrs_CT)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
            PrintToChat(activator, "%s You pressed Knife Arena Lazers button (CT)", MSG_PREFIX);
    }

    // Was it a knife arena button (Mystery)?
    else if (entity == g_iBtn_KnfArnaLzrs_Mstry)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
        {
            if (activator == g_iLeadGuard)
                Command_300Day(activator, 0);
            else
                PrintToChat(activator, "%s Silly goose!! Only the Lead can use this button!!", MSG_PREFIX);
        }
    }

    // Was it the duck hunt laser control button?
    else if (entity == g_iBtn_DuckHuntLzrs)
    {
        if (activator > 0 && activator <= MaxClients && IsClientInGame(activator))
            PrintToChat(activator, "%s You pressed Duck Hunt Lazers button", MSG_PREFIX);
    }

    // Display who pressed certain buttons such as hurdles, jump rope, and slide kill.
    // Because there's like 8 buttons for jump rope, I opted not to do the method of setting 8 indexes to global variables

    else if (activator > 0 && activator < MaxClients && IsClientInGame(activator))
    {
        new String:button_name[MAX_NAME_LENGTH];
        decl Float:origin[3];

        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

        new x = RoundToZero(origin[0]);
        new y = RoundToZero(origin[1]);
        new z = RoundToZero(origin[2]);

        if (x == -1718 && y == -2678)
            Format(button_name, sizeof(button_name), "Hurdles Start");

        else if (x == -921 && y == -3924)
            Format(button_name, sizeof(button_name), "Dodge Door Toggle");

        else if (x == -869 && y == -3924)
            Format(button_name, sizeof(button_name), "Dodge Toggle");

        else if (x == -1644 && (z == 299 || z == 300) && y < -4900)
            Format(button_name, sizeof(button_name), "Jump Rope Start");

        else if (x == -3312 && y == -5092)
            Format(button_name, sizeof(button_name), "Lava Start");

        if (!StrEqual(button_name, ""))
        {
            decl String:presser_steamid[LEN_STEAMIDS];
            GetClientAuthString(activator, presser_steamid, sizeof(presser_steamid));

            PrintToConsoleAll("%N (%s) [%d] Pressed button \"%s\"",
                              activator, presser_steamid, GetClientUserId(activator), button_name);
        }
    }
}

public Action:MapEnts_BlockRegularCTUse(entity, activator, caller, UseType:type, Float:value)
{
    if (g_iEndGame != ENDGAME_NONE ||
        activator < 1 ||
        activator > MaxClients ||
        !IsClientInGame(activator))
        return Plugin_Continue;

    if (GetClientTeam(activator) == TEAM_GUARDS &&
        activator != g_iLeadGuard)
    {
        PrintToChat(activator, "%s This button is designated lead only", MSG_PREFIX);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:MapEnts_OnTeleportStartTouch(teleporter, client)
{
    if (client > 0 &&
        client <= MaxClients &&
        IsClientInGame(client) &&
        JB_IsPlayerAlive(client) &&
        IsInLR(client, "Hot Potato"))
    {
        if (GetRandomInt(0, 3) == 0)
            PrintToChat(client, "%s Oh no! You have angered the teleport gods!", MSG_PREFIX);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:MapEnts_OnRotatingDoorUse(entity, activator, caller, UseType:type, Float:value)
{
    new lastused;
    decl String:sEntity[8];

    IntToString(entity, sEntity, sizeof(sEntity));
    GetTrieValue(g_hDoorLastUsed, sEntity, lastused);

    if (GetTime() - lastused < 2)
    {
        PrintToChat(activator,
                    "%s You can't use this door for another \x03%d\x04 seconds",
                    MSG_PREFIX, (2 - (GetTime() - lastused)));
        return Plugin_Handled;
    }

    SetTrieValue(g_hDoorLastUsed, sEntity, GetTime());
    return Plugin_Continue;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################



// ####################################################################################
// ################################## TIMER CALLBACKS #################################
// ####################################################################################

public Action:MapEnts_PreHookEnts(Handle:timer)
{
    new index = INVALID_ENT_REFERENCE;
    while ((index = FindEntityByClassname(index, "prop_door_rotating")) != INVALID_ENT_REFERENCE)
        SDKHook(index, SDKHook_Use, MapEnts_OnRotatingDoorUse);

    if (g_iGame != GAMETYPE_TF2)
    {
        while ((index = FindEntityByClassname(index, "func_door")) != INVALID_ENT_REFERENCE)
            SDKHook(index, SDKHook_StartTouch, Redie_OnDoorTouch);

        while ((index = FindEntityByClassname(index, "func_door_rotating")) != INVALID_ENT_REFERENCE)
            SDKHook(index, SDKHook_StartTouch, Redie_OnDoorTouch);

        while ((index = FindEntityByClassname(index, "prop_door_rotating")) != INVALID_ENT_REFERENCE)
        {
            HookSingleEntityOutput(index, "OnBlockedOpening", Redie_OnRotatingDoorBlocked);
            HookSingleEntityOutput(index, "OnBlockedClosing", Redie_OnRotatingDoorBlocked);
            SDKHook(index, SDKHook_StartTouch, Redie_OnDoorTouch);
        }

        while ((index = FindEntityByClassname(index, "trigger_push")) != INVALID_ENT_REFERENCE)
            SDKHook(index, SDKHook_StartTouch, Redie_OnTriggerTouch);

        while ((index = FindEntityByClassname(index, "trigger_teleport")) != INVALID_ENT_REFERENCE)
            SDKHook(index, SDKHook_StartTouch, Redie_OnTeleportTouch);
    }

    while ((index = FindEntityByClassname(index, "trigger_teleport")) != INVALID_ENT_REFERENCE)
        SDKHook(index, SDKHook_Touch, MapEnts_OnTeleportStartTouch);

    if (g_iBtn_BigBall != INVALID_ENT_REFERENCE)
        SDKHook(g_iBtn_BigBall, SDKHook_Use, MapEnts_BlockRegularCTUse);

    if (g_iBtn_SmallBall != INVALID_ENT_REFERENCE)
        SDKHook(g_iBtn_SmallBall, SDKHook_Use, MapEnts_BlockRegularCTUse);

}

public Action:MapEnts_GetEntIndexes(Handle:timer)
{
    // Local buffers.
    new entity = INVALID_ENT_REFERENCE;
    decl Float:fLocation[3];

    /************************************ BUTTONS ************************************/

    // Clear previously stored entity indexes.
    g_iBtn_CellOpener1 = INVALID_ENT_REFERENCE;
    g_iBtn_CellOpener2 = INVALID_ENT_REFERENCE;
    g_iBtn_KnfArnaLzrs_Mid = INVALID_ENT_REFERENCE;
    g_iBtn_KnfArnaLzrs_Mid = INVALID_ENT_REFERENCE;
    g_iBtn_KnfArnaLzrs_T = INVALID_ENT_REFERENCE;
    g_iBtn_KnfArnaLzrs_CT = INVALID_ENT_REFERENCE;
    g_iBtn_KnfArnaLzrs_Mstry = INVALID_ENT_REFERENCE;
    g_iBtn_DuckHuntLzrs = INVALID_ENT_REFERENCE;
    g_iTele_FirstCell = INVALID_ENT_REFERENCE;
    g_iBtn_SmallBall = INVALID_ENT_REFERENCE;
    g_iBtn_BigBall = INVALID_ENT_REFERENCE;

    while ((entity = FindEntityByClassname(entity, "trigger_teleport")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fLocation);

        if (g_iTele_FirstCell == INVALID_ENT_REFERENCE &&
            FloatAbs(fLocation[0] + 137.0) < 15.0 &&
            FloatAbs(fLocation[1] + 2003.0) < 15.0)
        {
            g_iTele_FirstCell = entity;
            entity = -1;

            break;
        }
    }

    // Get new entity indexes.
    while ((entity = FindEntityByClassname(entity, "func_button")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fLocation);

        // Test location for [g_iBtn_CellOpener1]
        if (g_iBtn_CellOpener1 == INVALID_ENT_REFERENCE &&
            fLocation[0] == (g_iGame == GAMETYPE_TF2 ? 66.0 : 23.0) &&
            fLocation[1] == (g_iGame == GAMETYPE_TF2 ? -2118.0 : -2082.0))
        {
            g_iBtn_CellOpener1 = entity;
            continue;
        }

        // Test location for [g_iBtn_CellOpener2]
        else if (g_iBtn_CellOpener2 == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 77.0 &&
                 fLocation[1] == -2082.0)
        {
            g_iBtn_CellOpener2 = entity;
            continue;
        }

        // Test location for [g_iBtn_KnfArnaLzrs_Mid]
        else if (g_iBtn_KnfArnaLzrs_Mid == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 2048.0 &&
                 fLocation[1] == -1820.01)
        {
            g_iBtn_KnfArnaLzrs_Mid = entity;
            continue;
        }

        // Test location for [g_iBtn_KnfArnaLzrs_T]
        else if (g_iBtn_KnfArnaLzrs_T == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 2066.0 &&
                 fLocation[1] == -1820.01)
        {
            g_iBtn_KnfArnaLzrs_T = entity;
            continue;
        }

        // Test location for [g_iBtn_KnfArnaLzrs_CT]
        else if (g_iBtn_KnfArnaLzrs_CT == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 2030.0 &&
                 fLocation[1] == -1820.01)
        {
            g_iBtn_KnfArnaLzrs_CT = entity;
            continue;
        }

        // Test location for [g_iBtn_KnfArnaLzrs_Mstry]
        else if (g_iBtn_KnfArnaLzrs_Mstry == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 1572.0 &&
                 fLocation[1] == -1596.0)
        {
            g_iBtn_KnfArnaLzrs_Mstry = entity;
            continue;
        }

        // Test location for [g_iBtn_DuckHuntLzrs]
        else if (g_iBtn_DuckHuntLzrs == INVALID_ENT_REFERENCE &&
                 fLocation[0] == 766.0 &&
                 fLocation[1] == 1466.0)
        {
            g_iBtn_DuckHuntLzrs = entity;
            continue;
        }

        else if (g_iBtn_SmallBall == INVALID_ENT_REFERENCE &&
                 RoundToNearest(fLocation[0]) == -2001 && 
                 RoundToNearest(fLocation[1]) == -1404)
        {
            g_iBtn_SmallBall = entity;
            continue;
        }

        else if (g_iBtn_BigBall == INVALID_ENT_REFERENCE &&
                 RoundToNearest(fLocation[0]) == -1973 &&
                 RoundToNearest(fLocation[1]) == -1404)
        {
            g_iBtn_BigBall = entity;
            continue;
        }

        // Just another thing salsa snuck into the map.
        else if (fLocation[0] == -1999.12 && 
                 fLocation[1] == -4846.7)
            AcceptEntityInput(entity, "kill");
    }

    /*************************************  DOORS ************************************/

    // This is just informational for future use...

    // Actual rotating door locations in the map:
    // {532.000000,-2339.000000,54.000000}  // Sauna
    // {492.000000,-2715.000000,54.281299}  // Infirm
    // {63.000000,-2335.000000,54.000000}   // Solitary
    // {788.000000,-1679.000000,54.000000}
    // {788.000000,-1585.000000,54.000000}

    // Actual sliding door locations in the map:
    // {264.000000,-275.730010,58.000000}
    // {264.000000,-235.729995,58.000000}
    // {576.000000,48.000000,76.000000}     // Pool
    // {816.000000,-3072.000000,76.000000}  // Armory
    // {144.000000,-3264.000000,76.000000}  // Kitchen
    // {-176.000000,-2656.000000,76.000000} // First obs
    // {1616.000000,-110.500000,23.000000}
    // {-607.000000,-2656.000000,76.000000} // Second obs
    // {1968.000000,-360.000000,64.000000}
    // {-1376.000000,-1535.000000,76.000000}
    // {1864.000000,-168.000000,64.000000}
    // {1616.000000,-808.000000,8.000000}
    // {1616.000000,-808.000000,8.000000}
    // {-2192.000000,-3232.000000,64.000000}
    // {-2192.000000,-2080.000000,64.000000}
    // {-2192.000000,-2464.000000,64.000000}
    // {-2192.000000,-2848.000000,64.000000}
}
