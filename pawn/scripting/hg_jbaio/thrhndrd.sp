
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_THRHNDRD_MENUCHOICE_KNIFEARENA 1111
#define LOCALDEF_THRHNDRD_MENUCHOICE_DUCKHUNT 2222
#define LOCALDEF_THRHNDRD_MENUCHOICE_OBSTACLE 3333
#define LOCALDEF_THRHNDRD_MENUCHOICE_DUNGEON 4444

#define LOCALDEF_THRHNDRD_MENUCHOICE_OPTRESPAWN 111
#define LOCALDEF_THRHNDRD_MENUCHOICE_OPTNEWLOC 222
#define LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEIN 333
#define LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEOUT 444

#define LOCALDEF_THRHNDRD_MIN_SECONDS_BETWEEN_RESPAWNS 50.0

// Trackers.
new g_i300ChosenLocation;
new bool:g_b300LeadParticipating;
new bool:g_b300CriteriaMet;
new Float:g_f300LastRespawnTime;
new Handle:g_h300WallEntityArr = INVALID_HANDLE;

// Menu & timer globals.
new Handle:g_h300MenuChooseLocation = INVALID_HANDLE;
new Handle:g_h300MenuLeadCtrlPnl = INVALID_HANDLE;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

ThrHndrd_OnPluginStart()
{
    RegConsoleCmd("300day", Command_300Day, "Sets up a 300 day.");

    // Array to hold indices of 300 day wall entities.
    g_h300WallEntityArr = CreateArray();

    // Create 300-day location menu.
    g_h300MenuChooseLocation = CreateMenu(ThrHndrd_MenuSelect_Location);
    SetMenuTitle(g_h300MenuChooseLocation, "Select Location for 300 Day");
    decl String:locationChoice[LEN_INTSTRING];
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_KNIFEARENA, locationChoice, sizeof(locationChoice));
    AddMenuItem(g_h300MenuChooseLocation, locationChoice, "Knife Arena");
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_DUCKHUNT, locationChoice, sizeof(locationChoice));
    AddMenuItem(g_h300MenuChooseLocation, locationChoice, "Duck Hunt");
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_OBSTACLE, locationChoice, sizeof(locationChoice));
    AddMenuItem(g_h300MenuChooseLocation, locationChoice, "Obstacle");
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_DUNGEON, locationChoice, sizeof(locationChoice));
    AddMenuItem(g_h300MenuChooseLocation, locationChoice, "Dungeon");

    // Create Lead's control panel menu.
    g_h300MenuLeadCtrlPnl = CreateMenu(ThrHndrd_MenuSelect_CtrlPnl);
    SetMenuTitle(g_h300MenuLeadCtrlPnl, "300 Day Lead Options");
    SetMenuExitButton(g_h300MenuLeadCtrlPnl, false);
}

ThrHndrd_OnRoundEnd()
{
    g_i300ChosenLocation = 0;
    g_b300LeadParticipating = false;
    g_b300CriteriaMet = false;

    Kill300Walls();
}

stock ThrHndrd_EndGameTime()
{
    Kill300Walls();
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_300Day(admin, args)
{
    if (admin > 0 && admin != g_iLeadGuard)
    {
        new bits = GetUserFlagBits(admin);
        if (!(bits & ADMFLAG_CHANGEMAP) && !(bits & ADMFLAG_ROOT))
        {
            ReplyToCommandGood(admin, "%s You must be the lead to use this command", MSG_PREFIX);
            return Plugin_Handled;
        }
    }

    // There must be a Lead Guard.
    if (g_iLeadGuard <= 0)
    {
        ReplyToCommandGood(admin, "%s There is no Lead Guard", MSG_PREFIX);
        return Plugin_Handled;
    }

    // A 300-day may only be initiated during a normal day.
    if (g_iEndGame != ENDGAME_NONE)
    {
        if (g_iEndGame == ENDGAME_300DAY)
        {
            if (g_b300CriteriaMet)
            {
                ThrHndrd_ReDisplayLeadCtrlPnl(INVALID_HANDLE, GetClientUserId(g_iLeadGuard));
                return Plugin_Handled;
            }
        }

        else
        {
            ReplyToCommandGood(admin, "%s It must be a normal day for a 300-day to start", MSG_PREFIX);
            return Plugin_Handled;
        }
    }

    // The "admin" (calling client) for this command is now the Lead Guard.
    // We need to do this in case the Lead dies and g_iLeadGuard gets reset.
    admin = g_iLeadGuard;

    // All Prisoners must be inside knife arena room.
    decl Float:RoomCenterPoint[3], Float:RoomDimensions[3];
    if (!MapCoords_CacheRoomInfo("Knife Arena", RoomCenterPoint, RoomDimensions))
    {
        ReplyToCommandGood(admin, "%s ERROR: room was not found", MSG_PREFIX);
        LogMessage("ERROR in Command_300Day: No room found for [Knife Arena]");
        return Plugin_Handled;
    }
    decl Float:TestLocation[3];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !JB_IsPlayerAlive(i) || GetClientTeam(i) != TEAM_PRISONERS)
            continue;
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", TestLocation);
        if (!MapCoords_IsInRoom(TestLocation, RoomCenterPoint, RoomDimensions))
        {
            ReplyToCommandGood(admin, "%s All Prisoners must be in Knife Arena room", MSG_PREFIX);
            return Plugin_Handled;
        }
    }

    // At this point, the criteria to have a 300-day has been met.  This bool is reset at end of round.
    g_b300CriteriaMet = true;

    // Provide menu to Lead Guard so he can choose which room to have the 300 day in.
    DisplayMenu(g_h300MenuChooseLocation, admin, MENU_TIMEOUT_NORMAL);

    // Done.
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

stock Kill300Walls()
{
    for (new i = 0; i < GetArraySize(g_h300WallEntityArr); i++)
    {
        new wall = GetArrayCell(g_h300WallEntityArr, i);

        if (IsValidEntity(wall))
        {
            decl String:classname[MAX_NAME_LENGTH];
            GetEntityClassname(wall, classname, sizeof(classname));

            if (StrContains(classname, "prop", false) > -1)
            {
                AcceptEntityInput(wall, "kill");
            }
        }
    }

    ClearArray(g_h300WallEntityArr);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public ThrHndrd_MenuSelect_Location(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        // This menu can only be used during a normal day and again during a 300-day.
        if (g_iEndGame != ENDGAME_NONE && g_iEndGame != ENDGAME_300DAY)
        {
            ReplyToCommandGood(admin, "%s You cannot use this option after 300-day has ended", MSG_PREFIX);
            return;
        }

        // This menu can only be used if the criteria to start a 300-day have been met.
        if (!g_b300CriteriaMet)
        {
            ReplyToCommandGood(admin, "%s The criteria to start a 300-day has not been met yet this round", MSG_PREFIX);
            return;
        }

        new Float:nowTime = GetGameTime();
        if ((g_f300LastRespawnTime + LOCALDEF_THRHNDRD_MIN_SECONDS_BETWEEN_RESPAWNS) > nowTime)
        {
            ReplyToCommandGood(admin,
                               "%s Please wait another %i seconds",
                               MSG_PREFIX,
                               RoundToNearest((g_f300LastRespawnTime + LOCALDEF_THRHNDRD_MIN_SECONDS_BETWEEN_RESPAWNS) - nowTime));
        }

        // Make it an official 300 day so there is no rebelling or rebel tracking.
        g_iEndGame = ENDGAME_300DAY;

        // Messages.
        PrintToChatAll("%s %N started a 300 day!", MSG_PREFIX, admin);
        decl String:startMsg[64];
        Format(startMsg, sizeof(startMsg), "%N started a 300 day!", admin);

        // Get passed choice.
        decl String:sLocationChoice[LEN_INTSTRING];
        GetMenuItem(menu, selected, sLocationChoice, sizeof(sLocationChoice));
        new iLocationChoice = StringToInt(sLocationChoice);

        // Record chosen location for later use.
        g_i300ChosenLocation = iLocationChoice;

        // Record this time as new last time.
        g_f300LastRespawnTime = GetGameTime();

        // Respawn all Guards.
        Respawn_DoTeam(0, TEAM_GUARDS, false, false);

        // Determine how many Guards are alive now.
        new numLivingGuards;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || !JB_IsPlayerAlive(i) || GetClientTeam(i) != TEAM_GUARDS)
                continue;
            numLivingGuards++;

            if (g_iGame == GAMETYPE_TF2)
                SetEntityHealth(i, TF2_GetMaxHealth(i));

            else
                SetEntityHealth(i, 196); // Why not :)
        }

        // Respawn an amount of Prisoners so that the teams are even.
        new numRespawnedPrisoners;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || JB_IsPlayerAlive(i) || GetClientTeam(i) != TEAM_PRISONERS)
                continue;

            RespawnPlayer(i);

            // So they can't get perks from gangs
            CreateTimer(1.0, Timer_StripWeps, i);

            if (g_iGame == GAMETYPE_TF2)
                SetEntityHealth(i, TF2_GetMaxHealth(i) - 60);

            else
                SetEntityHealth(i, 131); // Why not :)

            numRespawnedPrisoners++;
            if (numRespawnedPrisoners >= numLivingGuards)
                break;
        }

        // Strip weapons except knives.
        Strip_DoTeam(0, TEAM_GUARDS, true, false);
        Strip_DoTeam(0, TEAM_PRISONERS, true, false);

        // Give lead weapons back (if he's not participating in the fighting).
        if (!g_b300LeadParticipating)
        {
            if (g_iGame == GAMETYPE_TF2)
                TF2_GiveFullAmmo(admin);

            else
            {
                GivePlayerItem(admin, "weapon_m4a1");
                GivePlayerItem(admin, "weapon_deagle");
            }
        }

        // Teleport to the chosen location.
        switch(iLocationChoice)
        {
            case LOCALDEF_THRHNDRD_MENUCHOICE_KNIFEARENA:
            {
                Tele_DoTeam(0, TEAM_GUARDS, "Knife Arena (CT side)", false);
                Tele_DoTeam(0, TEAM_PRISONERS, "Knife Arena (T side)", false);
                if (!g_b300LeadParticipating)
                    Tele_DoClient(0, admin, "Knife Arena (Control station)", false);
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_DUCKHUNT:
            {
                Tele_DoTeam(0, TEAM_GUARDS, "Duck Hunt (CT side)", false);
                Tele_DoTeam(0, TEAM_PRISONERS, "Duck Hunt (T side)", false);
                if (!g_b300LeadParticipating)
                    Tele_DoClient(0, admin, "Duck Hunt (Control station)", false);

                // Try to close the duck hunt laser doors.
                if (g_iBtn_DuckHuntLzrs != INVALID_ENT_REFERENCE)
                    AcceptEntityInput(g_iBtn_DuckHuntLzrs, "Press");
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_OBSTACLE:
            {
                // Create walls to block people exiting the obstacle area.
                PushArrayCell(g_h300WallEntityArr, CreateWall(Float:{-894.4, -2625.0, 100.0}, Float:{0.0, 0.0, 0.0}));
                PushArrayCell(g_h300WallEntityArr, CreateWall(Float:{-894.4, -2458.0, 100.0}, Float:{0.0, 0.0, 0.0}));

                // Teleport players.
                Tele_DoTeam(0, TEAM_GUARDS, "OR CT", false);
                Tele_DoTeam(0, TEAM_PRISONERS, "OR T", false);
                if (!g_b300LeadParticipating)
                    Tele_DoClient(0, admin, "Roof 1", false);
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_DUNGEON:
            {
                // Create walls to block people exiting the obstacle area.
                PushArrayCell(g_h300WallEntityArr, CreateWall(Float:{-851.0, -1370.0, 20.0}, Float:{0.0, 0.0, 0.0}));
                PushArrayCell(g_h300WallEntityArr, CreateWall(Float:{-591.0, -1331.0, 20.0}, Float:{0.0, 90.0, 0.0}));

                // Teleport players.
                Tele_DoTeam(0, TEAM_GUARDS, "Dungeon", false);

                // Wong name
                decl Float:teledata[4];
                if (GetTrieArray(g_hDbCoords, "Dungeon Entrance", Float:teledata, 4))
                    Tele_DoTeam(0, TEAM_PRISONERS, "Dungeon Entrance", false);

                else
                    Tele_DoTeam(0, TEAM_PRISONERS, "Dungeon Enterance", false);

                if (!g_b300LeadParticipating)
                    Tele_DoClient(0, admin, "Blue Room", false);
            }
            default:
            {
                //pass
            }
        }

        // Freeze players, display countdown, and then unfreeze players.
        decl String:endMsg[64];
        new randMsg = GetRandomInt(0, 3);
        switch(randMsg)
        {
            case(0):
            {
                Format(endMsg, sizeof(endMsg), "THIS IS SPARTAAAAAA!");
            }
            case(1):
            {
                Format(endMsg, sizeof(endMsg), "TONIGHT WE DINE IN HELL!!!!!");
            }
            case(2):
            {
                Format(endMsg, sizeof(endMsg), "IMMORTALS... WE PUT THEIR NAME TO THE TEST!");
            }
            case(3):
            {
                Format(endMsg, sizeof(endMsg), "Come back WITH your shield... or ON it!");
            }
            default:
            {
                //pass
            }
        }
        DisplayCountdown(_, _, true, startMsg, endMsg);

        // Rebuild and display options menu to Lead Guard.
        CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));
    }
    else if (action == MenuAction_End)
    {
        //pass
    }
}

public ThrHndrd_MenuSelect_CtrlPnl(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        if (admin <= 0 || !IsClientInGame(admin))
            return;

        // Cancel if it's no longer a 300-Day (i.e. it's LR, LastCT, or next round).
        if (g_iEndGame != ENDGAME_300DAY)
        {
            ReplyToCommandGood(admin, "%s You cannot use this option after 300-day has ended", MSG_PREFIX);
            return;
        }

        // Get passed choice.
        decl String:sOptChoice[LEN_INTSTRING];
        GetMenuItem(menu, selected, sOptChoice, sizeof(sOptChoice));
        new iOptChoice = StringToInt(sOptChoice);

        // Ensure no spam.
        new Float:nowTime = GetGameTime();
        if ((g_f300LastRespawnTime + LOCALDEF_THRHNDRD_MIN_SECONDS_BETWEEN_RESPAWNS) > nowTime &&
            iOptChoice != LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEIN)
        {
            ReplyToCommandGood(admin,
                               "%s Please wait another %i seconds",
                               MSG_PREFIX,
                               RoundToNearest((g_f300LastRespawnTime + LOCALDEF_THRHNDRD_MIN_SECONDS_BETWEEN_RESPAWNS) - nowTime));

            // Rebuild and display options menu to Lead Guard.
            CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));

            return;
        }

        else if (iOptChoice == LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEOUT)
        {
            if (GetAlivePlayers(TEAM_GUARDS) <= 1)
            {
                PrintToChat(admin, "%s You are the last of your kind alive! No one can teleport you now.", MSG_PREFIX);
            }

            return;
        }
        
        else if (iOptChoice != LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEIN &&
                 iOptChoice != LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEOUT)
        {
            // Record this time as new last time.
            g_f300LastRespawnTime = nowTime;
        }

        // Perform passed options.
        switch(iOptChoice)
        {
            case LOCALDEF_THRHNDRD_MENUCHOICE_OPTRESPAWN:
            {
                // Holders for teleport data.
                decl Float:teledata_T[4], Float:teledata_CT[4];
                /*
                    teledata[0] = pos_x
                    teledata[1] = pos_y
                    teledata[2] = pos_z
                    teledata[3] = horiz_angle
                */

                // Grab location specific teleport data.
                new bool:errorFindingCoord;
                switch(g_i300ChosenLocation)
                {
                    case LOCALDEF_THRHNDRD_MENUCHOICE_KNIFEARENA:
                    {
                        if (!GetTrieArray(g_hDbCoords, "Knife Arena (T side)", Float:teledata_T, 4))
                            errorFindingCoord = true;
                        if (!GetTrieArray(g_hDbCoords, "Knife Arena (CT side)", Float:teledata_CT, 4))
                            errorFindingCoord = true;
                        if (!g_b300LeadParticipating && !JB_IsPlayerAlive(admin))
                        {
                            RespawnPlayer(admin);
                            Tele_DoClient(0, admin, "Knife Arena (Control station)", false);
                        }
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_DUCKHUNT:
                    {
                        if (!GetTrieArray(g_hDbCoords, "Duck Hunt (T side)", Float:teledata_T, 4))
                            errorFindingCoord = true;
                        if (!GetTrieArray(g_hDbCoords, "Duck Hunt (CT side)", Float:teledata_CT, 4))
                            errorFindingCoord = true;
                        if (!g_b300LeadParticipating && !JB_IsPlayerAlive(admin))
                        {
                            RespawnPlayer(admin);
                            Tele_DoClient(0, admin, "Duck Hunt (Control station)", false);
                        }
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_OBSTACLE:
                    {
                        if (!GetTrieArray(g_hDbCoords, "OR T", Float:teledata_T, 4))
                            errorFindingCoord = true;
                        if (!GetTrieArray(g_hDbCoords, "OR CT", Float:teledata_CT, 4))
                            errorFindingCoord = true;
                        if (!g_b300LeadParticipating && !JB_IsPlayerAlive(admin))
                        {
                            RespawnPlayer(admin);
                            Tele_DoClient(0, admin, "Roof 1", false);
                        }
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_DUNGEON:
                    {
                        if (!GetTrieArray(g_hDbCoords, "Dungeon Enterance", Float:teledata_T, 4))
                            errorFindingCoord = true;
                        if (!GetTrieArray(g_hDbCoords, "Dungeon", Float:teledata_CT, 4))
                            errorFindingCoord = true;
                        if (!g_b300LeadParticipating && !JB_IsPlayerAlive(admin))
                        {
                            RespawnPlayer(admin);
                            Tele_DoClient(0, admin, "Blue Room", false);
                        }
                    }
                    default:
                    {
                        //pass
                    }
                }

                // Was there an error?
                if (errorFindingCoord)
                {
                    LogMessage("ERROR in ThrHndrd_MenuSelect_CtrlPnl: No coords found for teleport destination");
                    ReplyToCommandGood(admin, "%s ERROR: coord was not found", MSG_PREFIX);
                    return;
                }

                // Convert teleport data into useful vectors for teleportation.
                decl Float:pos_T[3], Float:ang_T[3];
                pos_T[0] = teledata_T[0];
                pos_T[1] = teledata_T[1];
                pos_T[2] = teledata_T[2] + 5.0; // Adjust hight (Z coord) so its slightly above the floor level.
                ang_T[0] = 0.0;
                ang_T[1] = teledata_T[3];
                ang_T[2] = 0.0;
                decl Float:pos_CT[3], Float:ang_CT[3];
                pos_CT[0] = teledata_CT[0];
                pos_CT[1] = teledata_CT[1];
                pos_CT[2] = teledata_CT[2] + 5.0; // Adjust hight (Z coord) so its slightly above the floor level.
                ang_CT[0] = 0.0;
                ang_CT[1] = teledata_CT[3];
                ang_CT[2] = 0.0;

                // Iterate the players and respawn & tele all the ones that are currently dead.
                new thisTeam;
                for (new i = 1; i <= MaxClients; i++)
                {
                    // We only want to respawn & re-tele the dead players.
                    // This is so we don't interfear with the live players.
                    if (!IsClientInGame(i) || JB_IsPlayerAlive(i))
                        continue;

                    // If the Lead is not participating, he will have already been tele'd outside
                    // the fighting area in the switch case block above.  So don't tele him back in
                    // with his team now.
                    if (i == admin && !g_b300LeadParticipating)
                        continue;

                    // We only want to respawn people who hare on a team (not SPEC).
                    thisTeam = GetClientTeam(i);
                    if (thisTeam != TEAM_PRISONERS && thisTeam != TEAM_GUARDS)
                        continue;

                    // Respawn player and give him the normal 300-day health buff
                    RespawnPlayer(i);

                    // So they can't get perks from gangs
                    CreateTimer(1.0, Timer_StripWeps, i);

                    if (g_iGame == GAMETYPE_TF2)
                        SetEntityHealth(i, TF2_GetMaxHealth(i) - (thisTeam == TEAM_PRISONERS ? 60 : 0));

                    else
                        SetEntityHealth(i, thisTeam == TEAM_PRISONERS ? 131 : 196);

                    // Tele player to his respective team start location.
                    if (thisTeam == TEAM_PRISONERS)
                        TeleportEntity(i, pos_T, ang_T, NULL_VECTOR);
                    else if (thisTeam == TEAM_GUARDS)
                        TeleportEntity(i, pos_CT, ang_CT, NULL_VECTOR);

                    // Freeze player for a quick count-down.
                    DisplayCountdown(2, i, true, "", "FIGHT AGAIN!");
                }

                // Give Lead his weapons back if he's not participating.
                if (!g_b300LeadParticipating)
                {
                    if (GetPlayerWeaponSlot(admin, WEPSLOT_PRIMARY) == -1)
                        GivePlayerItem(admin, "weapon_m4a1");
                    if (GetPlayerWeaponSlot(admin, WEPSLOT_SECONDARY) == -1)
                        GivePlayerItem(admin, "weapon_deagle");
                }

                // Rebuild and display options menu to Lead Guard.
                CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_OPTNEWLOC:
            {
                // Provide menu to Lead Guard so he can choose which room to have the 300 day in.
                DisplayMenu(g_h300MenuChooseLocation, admin, MENU_TIMEOUT_NORMAL);
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEIN:
            {
                if (!g_b300LeadParticipating)
                {
                    // Record Lead participation choice.
                    g_b300LeadParticipating = true;

                    // Strip & teleport Lead to his team if he's alive.
                    if (JB_IsPlayerAlive(admin))
                    {
                        // Strip.
                        Strip_DoClient(0, admin, true, false);

                        // Get teleport location and direction.
                        new spawnOn = FindPlayerClump(TEAM_GUARDS, admin);
                        if (spawnOn > 0 && IsClientInGame(spawnOn) && JB_IsPlayerAlive(spawnOn))
                        {
                            // Teleport Lead to his team.
                            decl Float:pos[LEN_VEC];
                            decl Float:ang[LEN_VEC];
                            GetClientAbsOrigin(spawnOn, pos);
                            GetClientAbsAngles(spawnOn, ang);
                            TeleportEntity(admin, pos, ang, NULL_VECTOR);
                        }
                    }

                    // Respawn Lead to his team.
                    else
                    {
                        Respawn_DoClient(0, admin, false, false);
                    }
                }

                // Rebuild and display options menu to Lead Guard.
                CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));
            }
            case LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEOUT:
            {
                // Record Lead participation choice.
                g_b300LeadParticipating = false;

                // Teleport Lead out to the chosen location.
                switch(g_i300ChosenLocation)
                {
                    case LOCALDEF_THRHNDRD_MENUCHOICE_KNIFEARENA:
                    {
                        Tele_DoClient(0, admin, "Knife Arena (Control station)", false);
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_DUCKHUNT:
                    {
                        Tele_DoClient(0, admin, "Duck Hunt (Control station)", false);
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_OBSTACLE:
                    {
                        Tele_DoClient(0, admin, "Roof 1", false);
                    }
                    case LOCALDEF_THRHNDRD_MENUCHOICE_DUNGEON:
                    {
                        Tele_DoClient(0, admin, "Blue Room", false);
                    }
                    default:
                    {
                        //pass
                    }
                }

                // Give Lead his weapons back.
                if (GetPlayerWeaponSlot(admin, WEPSLOT_PRIMARY) == -1)
                    GivePlayerItem(admin, "weapon_m4a1");
                if (GetPlayerWeaponSlot(admin, WEPSLOT_SECONDARY) == -1)
                    GivePlayerItem(admin, "weapon_deagle");

                // Rebuild and display options menu to Lead Guard.
                CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));
            }
            default:
            {
                //pass
            }
        }
    }
    else if (action == MenuAction_End)
    {
        if (g_iEndGame == ENDGAME_300DAY &&
            admin > 0 &&
            IsClientInGame(admin))
        {
            // Rebuild and display options menu to Lead Guard.
            CreateTimer(1.0, ThrHndrd_ReDisplayLeadCtrlPnl, any:GetClientUserId(admin));
        }
    }
}

// ####################################################################################
// ################################# TIMER CALLBACKS ##################################
// ####################################################################################

public Action:ThrHndrd_ReDisplayLeadCtrlPnl(Handle:timer, any:userid)
{
    // Extract passed data.
    new admin = GetClientOfUserId(_:userid);
    if (!admin || !IsClientInGame(admin))
    {
        ReplyToCommandGood(admin, "%s ERROR: could not re-display Lead menu due to invalid client", MSG_PREFIX);
        return Plugin_Continue;
    }

    // Cancel if it's no longer a 300-Day (i.e. it's LR, LastCT, or next round).
    if (g_iEndGame != ENDGAME_300DAY)
    {
        ReplyToCommandGood(admin, "%s ERROR: could not re-display Lead menu due not in 300-day", MSG_PREFIX);
        return Plugin_Continue;
    }

    // Rebuild and display options menu to Lead Guard.
    RemoveAllMenuItems(g_h300MenuLeadCtrlPnl);
    decl String:optChoice[LEN_INTSTRING];
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_OPTRESPAWN, optChoice, sizeof(optChoice));
    AddMenuItem(g_h300MenuLeadCtrlPnl, optChoice, "Respawn All");
    IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_OPTNEWLOC, optChoice, sizeof(optChoice));
    AddMenuItem(g_h300MenuLeadCtrlPnl, optChoice, "Choose New Location");
    if (g_b300LeadParticipating)
    {
        IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEOUT, optChoice, sizeof(optChoice));
        AddMenuItem(g_h300MenuLeadCtrlPnl, optChoice, "Tele Yourself Out");
    }
    else
    {
        IntToString(LOCALDEF_THRHNDRD_MENUCHOICE_OPTTELEIN, optChoice, sizeof(optChoice));
        AddMenuItem(g_h300MenuLeadCtrlPnl, optChoice, "Tele Yourself In");
    }
    DisplayMenu(g_h300MenuLeadCtrlPnl, admin, PERM_DURATION);

    // Done.
    return Plugin_Continue;
}
