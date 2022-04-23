
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Warday types.

enum WardayType
{
    WT_Vanilla = 0,
    WT_SuddenDeath,
    WT_Reinforcements,
    WT_Rambo,
    WT_ScoutsKnives,
    WT_Invis,
    WT_ThrowingKnives,
    WT_HeadlessHorseMan,
    WT_DontTazeMeBro,
}

new WardayType:g_iWardayType = WT_Vanilla;
new g_iWardayTypeEnabledOn[WardayType];
new String:g_sWardayTypeName[WardayType][MAX_NAME_LENGTH];
new String:g_sWardayTypeDescription[WardayType][512];

// Trackers.
new g_iPreviousWardays;
new bool:g_bIsSND = false;
new bool:g_bCountingDown = false;
new Handle:g_hAreaMenu = INVALID_HANDLE;
new Handle:g_hWardayTypeMenu = INVALID_HANDLE;
new Handle:g_hCountDownSND = INVALID_HANDLE;
new Handle:g_hReplenishAmmoTimer = INVALID_HANDLE;

// Cached variables for super fast lookup.
new Float:g_fRoomCenterPoint[3];
new Float:g_fRoomDimensions[3];
new String:g_sCachedLocation[LEN_MAPCOORDS];

// Declare commonly used ConVars.
new Float:g_fWardaySndTimeAfter;
new g_iCallSNDEarly;

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

stock Warday_OnPluginStart()
{
    g_hWardayTypeMenu = CreateMenu(WardayTypeMenuSelect);
    SetMenuTitle(g_hWardayTypeMenu, "Choose Warday Type");

    g_sWardayTypeName[WT_Vanilla] = "Vanilla";
    g_sWardayTypeName[WT_SuddenDeath] = "Sudden Death";
    g_sWardayTypeName[WT_Reinforcements] = "Reinforcements";
    g_sWardayTypeName[WT_Rambo] = "Rambo";
    g_sWardayTypeName[WT_ScoutsKnives] = "Scoutz Knives";
    g_sWardayTypeName[WT_Invis] = "Invisibru";
    g_sWardayTypeName[WT_ThrowingKnives] = "Throwing Knives";
    g_sWardayTypeName[WT_HeadlessHorseMan] = "Headless Horseman";
    g_sWardayTypeName[WT_DontTazeMeBro] = "DON'T TAZE ME BRO";

    g_sWardayTypeDescription[WT_Vanilla] = "Kill all your enemies!";
    g_sWardayTypeDescription[WT_SuddenDeath] = "Every bullet kills on impact";
    g_sWardayTypeDescription[WT_Reinforcements] = "If the Ts have not won by 3:00\nreinforcements will arrive for CTs.\nSo act fast!\nS&D will NOT come early.";
    g_sWardayTypeDescription[WT_Rambo] = "CTs have to fight off the Ts... Rambo style";
    g_sWardayTypeDescription[WT_ScoutsKnives] = "Classic ScoutzKnives style warday\nOnly the sniper rifle you're given and your knife do damage";
    g_sWardayTypeDescription[WT_Invis] = "Invisibru warday\nYou can't see shit";
    g_sWardayTypeDescription[WT_ThrowingKnives] = "Throw all the knives";
    g_sWardayTypeDescription[WT_HeadlessHorseMan] = "You get a horse, you get a horse, everyone gets a horse!";
    g_sWardayTypeDescription[WT_DontTazeMeBro] = "Just Kidding, Taze everyone you see.";
    
    g_iWardayTypeEnabledOn[WT_Vanilla] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_SuddenDeath] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_Reinforcements] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_Rambo] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_ScoutsKnives] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_Invis] = GAMETYPE_CSS|GAMETYPE_TF2;
    g_iWardayTypeEnabledOn[WT_ThrowingKnives] = GAMETYPE_ALL;
    g_iWardayTypeEnabledOn[WT_HeadlessHorseMan] = GAMETYPE_TF2;
    // debug
    // VALVe broke shit
    // Should be GAMETYPE_CSGO
    g_iWardayTypeEnabledOn[WT_DontTazeMeBro] = GAMETYPE_NONE;

    decl String:sType[3];
    for (new i = 0; i < _:WardayType; i++)
    {
        // Warday not enabled on this game
        if (!(g_iWardayTypeEnabledOn[i] & g_iGame))
            continue;

        IntToString(i, sType, sizeof(sType));
        AddMenuItem(g_hWardayTypeMenu, sType, g_sWardayTypeName[i]);
    }

    RegConsoleCmd("warday", Command_Warday, "Allows lead to call a warday");
}

stock Warday_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_fWardaySndTimeAfter = GetConVarFloat(g_hCvWardaySndTimeAfter);
    g_iCallSNDEarly = GetConVarInt(g_hCvWardayStartEarly);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvWardaySndTimeAfter, Warday_OnConVarChange);
    HookConVarChange(g_hCvWardayStartEarly, Warday_OnConVarChange);
}

public Warday_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvWardaySndTimeAfter)
        g_fWardaySndTimeAfter = GetConVarFloat(g_hCvWardaySndTimeAfter);
    else if (CVar == g_hCvWardayStartEarly)
        g_iCallSNDEarly = GetConVarInt(g_hCvWardayStartEarly);
}

stock Warday_OnPlayerDeath()
{
    CheckSND();
}

stock Warday_OnClientDisconnect()
{
    CheckSND();
}

stock Warday_OnRndStrt_General()
{
    if (g_hCountDownSND != INVALID_HANDLE)
    {
        CloseHandle(g_hCountDownSND);
        g_hCountDownSND = INVALID_HANDLE;
    }

    if (g_iPreviousWardays > 0)
        g_iPreviousWardays--;

    g_bIsSND = false;
    g_hCountDownSND = CreateTimer(g_fWardaySndTimeAfter - 10.0, Timer_CountDownSND, 10);
}

stock Warday_OnRoundEnd()
{
    if (g_hReplenishAmmoTimer != INVALID_HANDLE)
    {
        CloseHandle(g_hReplenishAmmoTimer);
        g_hReplenishAmmoTimer = INVALID_HANDLE;
    }
}

stock Warday_CellsOpened()
{
    if (g_iEndGame != ENDGAME_WARDAY)
        return;

    if (g_iGame == GAMETYPE_TF2 && g_iWardayType != WT_Invis)
        TF2_WallHacks();

    // Teleport all guards.
    Tele_DoTeam(0, TEAM_GUARDS, g_sCachedLocation, false);

    // Teleport all Prisoners.
    if (!StrEqual(g_sCachedLocation, "Armory", false))
        Tele_DoTeam(0, TEAM_PRISONERS, "Armory", false);

    // Spam people to let them know warday has begun.
    for (new i = 0; i < 4; i++)
        PrintToChatAll("%s \x03IT'S A WARDAY. \x04CTs who are outside of \x03%s\x04 can not hurt Ts until Search And Destroy",
                       MSG_PREFIX, g_sCachedLocation);

    //new snd_time = (60 * GetConVarInt(FindConVar(g_iGame == GAMETYPE_TF2 ? "tf_arena_round_time" : "mp_roundtime"))) - RoundToNearest(g_fWardaySndTimeAfter);
    new snd_time = 185;
    new minutes = snd_time / 60;
    new seconds = snd_time % 60;

    PrintCenterTextAll("IT'S A WARDAY. Search and Destroy at %d:%02d or bad ratio", minutes, seconds);
    PrintHintTextToAll("IT'S A WARDAY. Search and Destroy at %d:%02d or bad ratio", minutes, seconds);

    decl String:title[64];
    Format(title, sizeof(title), "It's a %s warday", g_sWardayTypeName[g_iWardayType]);

    DisplayMSayAll(title, 30, g_sWardayTypeDescription[g_iWardayType]);

    if (g_iGame == GAMETYPE_CSGO)
    {
        CreateWall(Float:{649.0, -3100.0, 80.0}, NULL_VECTOR);
        CreateWall(Float:{649.0, -3100.0, 215.0}, NULL_VECTOR);
        CreateWall(Float:{649.0, -2900.0, 80.0}, NULL_VECTOR);
        CreateWall(Float:{649.0, -2900.0, 215.0}, NULL_VECTOR);
    }

    else
    {
        CreateWall(Float:{649.0, -3110.0, 160.0}, Float:{0.0, 0.0, 90.0});
        CreateWall(Float:{649.0, -3003.0, 160.0}, Float:{0.0, 0.0, 90.0});
        CreateWall(Float:{649.0, -2896.0, 160.0}, Float:{0.0, 0.0, 90.0});
        CreateWall(Float:{649.0, -2789.0, 160.0}, Float:{0.0, 0.0, 90.0});
        CreateWall(Float:{649.0, -3110.0, 240.0}, NULL_VECTOR);
        CreateWall(Float:{649.0, -2920.0, 240.0}, NULL_VECTOR);
    }

    CreateWall(Float:{649.0, -3043.0, 0.0}, NULL_VECTOR);

    if (g_iGame == GAMETYPE_CSGO)
    {
        CreateWall(Float:{647.0, -3043.0, 0.0}, NULL_VECTOR);
        CreateWall(Float:{645.0, -3043.0, 0.0}, NULL_VECTOR);
        CreateWall(Float:{643.0, -3043.0, 0.0}, NULL_VECTOR);
    }

    else
    {
        CreateWall(Float:{645.0, -3043.0, 0.0}, NULL_VECTOR);
        CreateWall(Float:{641.0, -3043.0, 0.0}, NULL_VECTOR);
        CreateWall(Float:{637.0, -3043.0, 0.0}, NULL_VECTOR);
        CreateWall(Float:{633.0, -3043.0, 0.0}, NULL_VECTOR);
    }

    switch (g_iWardayType)
    {
        case WT_Rambo:
        {
            g_hReplenishAmmoTimer = CreateTimer(10.0, Timer_ReplenishWardayAmmo, _, TIMER_REPEAT);

            new bool:isDungeon = StrEqual(g_sCachedLocation, "Dungeon");
            for (new i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || !JB_IsPlayerAlive(i))
                    continue;

                if (GetClientTeam(i) == TEAM_GUARDS)
                {
                    if (g_iGame == GAMETYPE_TF2)
                    {
                        TF2_SetPlayerClass(i, TFClass_Heavy, true, false);
                        TF2_SetProperModel(i);

                        SetEntityHealth(i, 500);

                        TF2_GivePlayerWeapon(i, "tf_weapon_minigun", TF2_BRASS_BEAST, WEPSLOT_PRIMARY);
                        TF2_GivePlayerWeapon(i, "tf_weapon_shotgun", TF2_SHOTGUN, WEPSLOT_SECONDARY);
                        TF2_GivePlayerWeapon(i, "tf_weapon_fists", TF2_APOCO_FISTS, WEPSLOT_KNIFE);

                        SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY), i, 200, 200);
                        SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY), i, 9999, 9999);
                    }

                    else
                    {
                        StripWeps(i);
                        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.666);

                        if (isDungeon)
                            SetEntityHealth(i, (g_iGame == GAMETYPE_CSS) ? 315 : 300);
                        else
                            SetEntityHealth(i, 333);

                        SetWeaponAmmo(GivePlayerItem(i, (g_iGame == GAMETYPE_CSS) ? "weapon_m249" : "weapon_negev"), i, 200, 100);
                        SetWeaponAmmo(GivePlayerItem(i, "weapon_hegrenade"), i, 5, 5);

                        if (g_iGame == GAMETYPE_CSGO)
                            SetWeaponAmmo(GivePlayerItem(i, "weapon_molotov"), i, 5, 5);
                    }
                }

                else if (GetClientTeam(i) == TEAM_PRISONERS)
                {
                    if (isDungeon && g_iGame != GAMETYPE_TF2)
                    {
                        // The T's are crackheads with super cracky health and speed.
                        // They're highly motivated to get into their crackdungeon.
                        SetEntityHealth(i, 125);
                        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.25);
                    }

                    if (g_iGame == GAMETYPE_TF2)
                        TF2_GiveFullAmmo(i);
                }
            }
        }

        case WT_ScoutsKnives:
        {
            CreateTimer(0.5, Warday_GravityLoop, _, TIMER_REPEAT);

            for (new i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || !JB_IsPlayerAlive(i))
                    continue;

                new team = GetClientTeam(i);

                if (g_iGame == GAMETYPE_TF2)
                {
                    TF2_SetPlayerClass(i, TFClass_Scout, true, false);
                    TF2_SetProperModel(i);

                    SetEntityHealth(i, 140);

                    TF2_GivePlayerWeapon(i, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY);
                    TF2_GivePlayerWeapon(i, "tf_weapon_bat_fish", TF2_MACKEREL, WEPSLOT_KNIFE);

                    if (team == TEAM_PRISONERS)
                        TF2_GivePlayerWeapon(i, "tf_weapon_pistol", TF2_SCOUT_PISTOL, WEPSLOT_SECONDARY);

                    else
                    {
                        TF2_GivePlayerWeapon(i, "tf_weapon_cleaver", TF2_FLYING_GUILLOTINE, WEPSLOT_SECONDARY);
                        SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY), i, -1, 3);
                    }

                    SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY), i, 0, 0);
                }

                else
                {
                    StripWeps(i);
                    SetWeaponAmmo(GivePlayerItem(i, (g_iGame == GAMETYPE_CSS) ? "weapon_scout" : "weapon_ssg08"), i, 10, 30);
                }
            }
        }

        case WT_Invis:
        {
            ServerCommand("invis @all");
        }

        case WT_ThrowingKnives:
        {
            if (g_iGame != GAMETYPE_TF2)
                CreateTimer(3.0, Timer_ReplenishThrowingKnives, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

            for (new i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || !JB_IsPlayerAlive(i))
                    continue;

                if (g_iGame == GAMETYPE_TF2)
                {
                    TF2_SetPlayerClass(i, TFClass_Scout, true, false);
                    TF2_SetProperModel(i);

                    SetEntityHealth(i, 140);

                    TF2_GivePlayerWeapon(i, "tf_weapon_scattergun", TF2_SCATTERGUN, WEPSLOT_PRIMARY);
                    TF2_GivePlayerWeapon(i, "tf_weapon_bat_fish", TF2_MACKEREL, WEPSLOT_KNIFE);
                    TF2_GivePlayerWeapon(i, "tf_weapon_cleaver", TF2_FLYING_GUILLOTINE, WEPSLOT_SECONDARY);

                    SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY), i, -1, 999);
                    SetWeaponAmmo(GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY), i, 0, 0);
                }

                else
                {
                    StripWeps(i, true);
                    SetClientThrowingKnives(i, 2);
                }
            }
        }

        case WT_HeadlessHorseMan:
        {
            ServerCommand("sm_behhh @all");
        }

        case WT_DontTazeMeBro:
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && JB_IsPlayerAlive(i))
                {
                    StripWeps(i, true);

                    new taser = GivePlayerItem(i, "weapon_taser");
                    SetWeaponAmmo(taser, i, 1, 999);
                }
            }
        }

        default:
        {
            // pass
        }
    }
}

public WardayTypeMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    if (!CanCallWarday(client))
        return;

    decl String:sType[3];
    GetMenuItem(menu, selected, sType, sizeof(sType));

    g_iWardayType = WardayType:StringToInt(sType);
    DisplayMenu(g_hAreaMenu, client, 60);
}

public AreaMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (selected == MenuCancel_ExitBack)
    {
        DisplayMenu(g_hWardayTypeMenu, client, 60);
        return;
    }

    if (action != MenuAction_Select)
        return;

    // Check to see if they can still call a warday.
    if (!CanCallWarday(client))
        return;

    // Do they have enough rep to call a warday?
    new cost = GetConVarInt(g_hCvRepCostWarday);
    if (PrisonRep_GetPoints(client) < cost)
    {
        PrintToChat(client,
                    "%s You need \x03%d\x04 rep to call a warday",
                    MSG_PREFIX, cost);
        return;
    }

    // Get location name
    decl String:roomName[LEN_MAPCOORDS];
    GetMenuItem(menu, selected, roomName, sizeof(roomName));

    if (StrContains(g_sCachedLocation, "infirm", false) > -1 &&
        (g_iWardayType == WT_Rambo || g_iWardayType == WT_SuddenDeath))
    {
        Format(g_sCachedLocation, sizeof(g_sCachedLocation), "Dungeon");
        DisplayMSay(g_iLeadGuard, "Invalid Area", 30, "The area you chose is not valid for this warday\nDefaulted to Dungeon.");
    }

    else if (StrContains(g_sCachedLocation, "jjk", false) > -1 &&
             g_iWardayType == WT_Rambo)
    {
        Format(g_sCachedLocation, sizeof(g_sCachedLocation), "Dungeon");
        DisplayMSay(g_iLeadGuard, "Invalid Area", 30, "The area you chose is not valid for this warday\nDefaulted to Dungeon.");
    }

    // Check if we have tele and room info for this selected location.
    new Float:teleData[4];
    if (!GetTrieArray(g_hDbCoords, roomName, teleData, sizeof(teleData)))
    {
        PrintToChat(client, "%s Sorry, location data is not available for \x01%s", MSG_PREFIX, roomName);
        LogMessage("ERROR: No tele data for %s", roomName);
        return;
    }
    if (!MapCoords_CacheRoomInfo(roomName, g_fRoomCenterPoint, g_fRoomDimensions))
    {
        PrintToChat(client, "%s Sorry, location data is not available for \x01%s", MSG_PREFIX, roomName);
        LogMessage("ERROR in AreaMenuSelect: No room data for %s", roomName);
        return;
    }

    // Looks like everything is good to go for this warday to start.  Time to do it.  Deduct the cost from the lead's points.
    PrisonRep_AddPoints(client, -cost);
    g_iEndGame = ENDGAME_WARDAY;
    for (new i = 0; i < 3; i++)
        PrintToChatAll("%s \x03%N\x04 has selected a warday in \x03%s\x04, Guards will be teleported when cells open",
                       MSG_PREFIX, client, roomName);

    g_iPreviousWardays += 2;
    g_bCountingDown = false;

    Format(g_sCachedLocation, sizeof(g_sCachedLocation), roomName);
}

bool:Warday_ModifyDamage(victim, attacker, &Float:damage, damagetype)
{
    switch (g_iWardayType)
    {
        // Replenish ammo when they do damage to reward them
        case WT_Rambo:
        {
            new wep = GetPlayerWeaponSlot(attacker, WEPSLOT_PRIMARY);

            if (wep > -1 && 
                victim > 0 &&
                victim <= MaxClients && 
                IsClientInGame(victim) &&
                GetClientTeam(victim) != GetClientTeam(attacker) &&
                GetClientTeam(attacker) == TEAM_GUARDS)
                SetWeaponAmmo(wep, attacker, GetWeaponClip(wep) + 15, GetWeaponAmmo(wep, attacker) + 20);
        }

        case WT_SuddenDeath:
        {
            if ((damagetype & DMG_BULLET) || (damagetype & DMG_SLASH) || (damagetype & DMG_BUCKSHOT))
            {
                damage = float(GetClientHealth(victim)) + 101.0;
                SetEntityHealth(victim, 1);

                return true;
            }
        }

        case WT_ScoutsKnives:
        {
            decl String:weapon[LEN_ITEMNAMES];
            GetClientWeapon(attacker, weapon, sizeof(weapon));

            if (!StrEqual(weapon, "weapon_knife") &&
                !StrEqual(weapon, "weapon_scout") &&
                !StrEqual(weapon, "weapon_ssg08") &&
                !StrEqual(weapon, "tf_weapon_bat_fish") &&
                !StrEqual(weapon, "tf_weapon_cleaver") &&
                !StrEqual(weapon, "cleaver", false))
            {
                PrintToChat(attacker, "%s Silly, that weapon is not allowed in this warday.", MSG_PREFIX);
                damage = 0.0;

                return true;
            }
        }

        case WT_ThrowingKnives:
        {
            decl String:weapon[LEN_ITEMNAMES];
            GetClientWeapon(attacker, weapon, sizeof(weapon));

            if (!StrEqual(weapon, "weapon_knife") &&
                !StrEqual(weapon, "tf_weapon_bat_fish") &&
                !StrEqual(weapon, "tf_weapon_cleaver") &&
                !StrEqual(weapon, "point_hurt") &&
                !StrEqual(weapon, "tknife") &&
                !StrEqual(weapon, "ctknife") &&
                !StrEqual(weapon, "cleaver", false))
            {
                PrintToChat(attacker, "%s Silly, that weapon is not allowed in this warday.", MSG_PREFIX);
                damage = 0.0;

                return true;
            }

            else if (g_iGame != GAMETYPE_TF2 &&
                     victim > 0 &&
                     victim <= MaxClients && 
                     IsClientInGame(victim) &&
                     GetClientTeam(victim) != GetClientTeam(attacker))
            {
                SetClientThrowingKnives(attacker, GetClientThrowingKnives(attacker) + 3);
            }
        }

        case WT_DontTazeMeBro:
        {
            decl String:weapon[LEN_ITEMNAMES];
            GetClientWeapon(attacker, weapon, sizeof(weapon));

            if (!StrEqual(weapon, "weapon_knife") &&
                !StrEqual(weapon, "weapon_taser"))
            {
                PrintToChat(attacker, "%s Silly, that weapon is not allowed in this warday.", MSG_PREFIX);
                damage = 0.0;

                return true;
            }
        }

        default:
            return false;
    }

    return false;
}

bool:Warday_PlayerHurt(attacker)
{
    if (g_bIsSND || !JB_IsPlayerAlive(attacker))
        return true;

    // Allow damage to be done if the attacker is in the warday area.
    decl Float:origin[3];
    GetClientAbsOrigin(attacker, origin);
    if (MapCoords_IsInRoom(origin, g_fRoomCenterPoint, g_fRoomDimensions))
        return true;

    // Not in warday area!
    PrintToChat(attacker,
                "%s For this warday, you can not damage people outside of \x03%s",
                MSG_PREFIX, g_sCachedLocation);
    return false;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Warday(client, args)
{
    if (CanCallWarday(client))
    {
        // Only display it for 60 seconds, 'cause cells open at 5:00.
        DisplayMenu(g_hWardayTypeMenu, client, 60);
    }

    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

CheckSND()
{
    if (g_iEndGame != ENDGAME_WARDAY)
        return;

    if (g_bCountingDown || g_bIsSND || g_iWardayType == WT_Reinforcements)
        return;

    new alive_ts;
    new alive_cts;

    for (new i = 1; i < MaxClients; i++)
    {
        if (!IsClientInGame(i) || !JB_IsPlayerAlive(i))
            continue;

        new team = GetClientTeam(i);
        if (team == TEAM_GUARDS)
            alive_cts++;

        else if (team == TEAM_PRISONERS)
            alive_ts++;
    }

    if (alive_ts <= g_iCallSNDEarly ||
        alive_cts <= g_iCallSNDEarly)
    {
        if (g_hCountDownSND != INVALID_HANDLE)
            CloseHandle(g_hCountDownSND);

        PrintToChatAll("%s There are only a few Ts/CTs left", MSG_PREFIX);
        PrintToChatAll("%s Get ready for an early \x03Search and Destroy!", MSG_PREFIX);

        Timer_CountDownSND(INVALID_HANDLE, 10);
    }

}

Warday_RecreateRoomsMenu()
{
    if (g_hAreaMenu != INVALID_HANDLE)
    {
        RemoveAllMenuItems(g_hAreaMenu);
        CloseHandle(g_hAreaMenu);
        g_hAreaMenu = INVALID_HANDLE;
    }

    g_hAreaMenu = CreateMenu(AreaMenuSelect);
    SetMenuTitle(g_hAreaMenu, "Select Warday Area");
    SetMenuExitBackButton(g_hAreaMenu, true);
}

Warday_RegisterRoom(const String:room[])
{
    AddMenuItem(g_hAreaMenu, room, room);
}

public Action:Warday_GravityLoop(Handle:timer, any:data)
{
    if (g_iEndGame != ENDGAME_WARDAY || g_iWardayType != WT_ScoutsKnives)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && JB_IsPlayerAlive(i))
                SetEntityGravity(i, 1.0);
        }

        return Plugin_Stop;
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !JB_IsPlayerAlive(i))
            continue;

        SetEntityGravity(i, 0.222);
    }

    return Plugin_Continue;
}


public Action:Timer_ReplenishWardayAmmo(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) &&
            JB_IsPlayerAlive(i) &&
            GetClientTeam(i) == TEAM_GUARDS)
        {
            new wep = GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY);

            if (wep > -1)
                SetWeaponAmmo(wep, i, -1, GetWeaponAmmo(wep, i) + 20);
        }
    }

    return Plugin_Continue;
}

public Action:Timer_ReplenishThrowingKnives(Handle:timer, any:data)
{
    if (g_iEndGame != ENDGAME_WARDAY ||
        g_iWardayType != WT_ThrowingKnives)
        return Plugin_Handled;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && JB_IsPlayerAlive(i))
        {
            new knives = GetClientThrowingKnives(i);
            if (knives < 2)
                SetClientThrowingKnives(i, knives + 1);
        }
    }

    return Plugin_Continue;
}

public Action:Timer_CountDownSND(Handle:timer, any:time)
{
    // Timer has ticked.  First thing... invalidate this global handle.
    g_hCountDownSND = INVALID_HANDLE;

    // Let the script know we're counting down.
    g_bCountingDown = true;

    // no longer a warday
    if (g_iEndGame != ENDGAME_WARDAY)
        return Plugin_Stop;

    PrintCenterTextAll("Search and Destroy in %d", time--);
    if (time < 0)
    {
        PrintToChatAll("%s It is now a Search and Destroy", MSG_PREFIX);
        PrintToChatAll("%s CTs may go anywhere to find, and kill all but the last two prisoners", MSG_PREFIX);

        if (g_iWardayType == WT_Reinforcements)
        {
            PrintToChatAll("%s As well, Ts have failed to kill all the CTs fast enough. \x03Reinforcements have arrived!",
                           MSG_PREFIX);
            Respawn_DoTeam(0, TEAM_GUARDS, false, true);
        }

        g_bIsSND = true;
        return Plugin_Stop;
    }

    // Re call this timer, but call it with parameter 0, as to not reset the static variable.
    g_hCountDownSND = CreateTimer(1.0, Timer_CountDownSND, time);
    return Plugin_Stop;
}

bool:CanCallWarday(client)
{
    // can't call warday if cells are opened.
    if (g_bAreCellsOpened)
    {
        PrintToChat(client,
                    "%s You can not call a warday when cells are open",
                    MSG_PREFIX);
        return false;
    }

    // Or if they pass lead, but try to call one.
    if (client != g_iLeadGuard)
    {
        PrintToChat(client,
                    "%s Only the lead can call a warday", MSG_PREFIX);
        return false;
    }

    if (!g_bSuccessfulRound[client])
    {
        DisplayMSay(client,
                    "Can not call warday", MENU_TIMEOUT_QUICK,
                    "You can not call a warday until you have lead a successful day\nEither lead now, pass lead, or be tlisted");
        return false;
    }

    // Or if there's already a warday, LR or last CT.
    if (g_iEndGame > ENDGAME_NONE)
    {
        PrintToChat(client,
                    "%s You can only call a warday when there is no endgame",
                    MSG_PREFIX);
        return false;
    }

    // Or if there's been too many wardays in the past few rounds.
    new max_consecutive = GetConVarInt(g_hCvWardayMaxConsecutive);
    if (g_iPreviousWardays >= max_consecutive)
    {
        PrintToChat(client,
                    "%s There have already been \x03%d\x04 wardays in the past few rounds",
                    MSG_PREFIX, max_consecutive);
        return false;
    }

    return true;
}
