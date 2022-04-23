
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define INVIS_ALPHA_NORMAL 30 // Arbitrary low number (0-255)
#define INVIS_ALPHA_CROUCHING 25 // Arbitrary low number (0-255)
#define INVIS_ALPHA_SHOOTING 200 // Arbitrary high number (0-255)
#define LOCALDEF_INVIS_MENUCHOICE_ALL -1111
#define LOCALDEF_INVIS_MENUCHOICE_ALLT -2222
#define LOCALDEF_INVIS_MENUCHOICE_ALLCT -3333
#define LOCALDEF_INVIS_CMDTYPE_INVIS 0
#define LOCALDEF_INVIS_CMDTYPE_VIS 1

// Track if players are crouching or walking.
new Handle:g_hInvisButtonCheckTimers[MAXPLAYERS + 1];
new bool:g_bInvisIsCrouching[MAXPLAYERS + 1];
new bool:g_bInvisIsWalking[MAXPLAYERS + 1];
new bool:g_bInvisIsShooting[MAXPLAYERS + 1];
new bool:g_bIsActuallyInvisible[MAXPLAYERS + 1];

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

public Invis_OnPostThinkPost(client)
{
    // https://forums.alliedmods.net/showthread.php?t=152165
    // There is a netprop, m_iAddonBits, that controls which items to show on a player. It seems that entities are then
    // created for them clientside and attached, which is why people always had trouble finding them serverside.
    // m_iAddonBits gets reset on every PostThink so the PostThinkPost hook in SDK Hooks is needed.

    /*
    #define CSAddon_NONE            0
    #define CSAddon_Flashbang1      (1<<0)
    #define CSAddon_Flashbang2      (1<<1)
    #define CSAddon_HEGrenade       (1<<2)
    #define CSAddon_SmokeGrenade    (1<<3)
    #define CSAddon_C4              (1<<4)
    #define CSAddon_DefuseKit       (1<<5)
    #define CSAddon_PrimaryWeapon   (1<<6)
    #define CSAddon_SecondaryWeapon (1<<7)
    #define CSAddon_Holster         (1<<8)
    */

    if (g_bIsInvisible[client])
        SetEntProp(client, Prop_Send, "m_iAddonBits", 0); // 0 is CSAddon_NONE
}

Invis_OnPluginStart()
{
    RegAdminCmd("invis", Command_VisToggle, ADMFLAG_CHANGEMAP, "Makes a player invisible");
    RegAdminCmd("vis", Command_VisToggle, ADMFLAG_CHANGEMAP, "Makes a player visible");
}

Invis_OnRoundStart()
{
    for(new i = 1; i <= MaxClients; i++)
    {
        g_bIsInvisible[i] = false;
        g_bIsActuallyInvisible[i] = false;
    }
}

Invis_OnPlayerSpawn(client)
{
    MakeTotalPlayerVisible(client);
    g_bInvisIsCrouching[client] = false;
    g_bInvisIsWalking[client] = false;
}

Invis_OnPlayerDeath(client)
{
    MakeTotalPlayerVisible(client);
}

Invis_OnItemPickup(client, wepid)
{
    if (g_bIsInvisible[client])
    {
        SetEntityRenderMode(wepid, RENDER_TRANSCOLOR);
        SetEntityRenderColor(wepid, 255, 255, 255, ((GetClientButtons(client) & IN_DUCK) ? INVIS_ALPHA_CROUCHING : INVIS_ALPHA_NORMAL));
    }
}

Invis_OnWeaponDrop(wepid)
{
    // If the weapon that was dropped is invisible, we need to set this item back to visible
    // so it can be seen when on the ground.
    if (GetEntityRenderMode(wepid) == RENDER_TRANSCOLOR)
    {
        SetEntityRenderColor(wepid, 255, 255, 255, 255);
        SetEntityRenderMode(wepid, RENDER_NORMAL);
    }
}

Invis_OnWeaponSwitch(client, weapon)
{
    // Sometimes an invisible player's weapon becomes visible when it's switched.
    if (g_bIsInvisible[client])
    {
        if (GetEntityRenderMode(weapon) != RENDER_TRANSCOLOR)
        {
            SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
            SetEntityRenderColor(weapon, 255, 255, 255, ((GetClientButtons(client) & IN_DUCK) ? INVIS_ALPHA_CROUCHING : INVIS_ALPHA_NORMAL));
        }
    }
}

public Action:Invis_Transmit_CSGO(client, viewer)
{
    // We have to use g_bIsActuallyInvisible here because some times
    // to set a player a "permanent" rebel we just set g_bIsInvisible to true

    if (g_bIsActuallyInvisible[client] &&
        viewer &&
        viewer <= MaxClients &&
        client != viewer &&
        GetRandomInt(0, 7500) > 1)
        return Plugin_Handled;

    return Plugin_Continue;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_VisToggle(admin, args)
{
    // The command itself could be different things (invis, vis, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if ((cmd[0] == 'i' || cmd[0] == 'I') && (cmd[1] == 'n' || cmd[1] == 'N'))
        cmdType = LOCALDEF_INVIS_CMDTYPE_INVIS;
    else
        cmdType = LOCALDEF_INVIS_CMDTYPE_VIS;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Invis_MenuSelect);
        SetMenuTitle(menu, (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS ?
                            "Select Player To Make Invisible" :
                            "Select Player To Make Visible"));
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = -1; // Duration not applicable
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, ""); // Reason not applicable
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];

        // Add team choices.
        IntToString(LOCALDEF_INVIS_MENUCHOICE_ALL, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All");
        IntToString(LOCALDEF_INVIS_MENUCHOICE_ALLT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All Prisoners");
        IntToString(LOCALDEF_INVIS_MENUCHOICE_ALLCT, sUserid, sizeof(sUserid));
        AddMenuItem(menu, sUserid, "All Guards");

        // Add spacer.
        AddMenuItem(menu, "9999", "~~~~~~~~~~~~~~~~~", ITEMDRAW_DISABLED);

        // Add individual player choices.
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
                continue;
            if (!JB_IsPlayerAlive(i))
                continue;

            if (g_bIsInvisible[i])
                Format(name, sizeof(name), "[INV] %N", i);
            else
                Format(name, sizeof(name), "[VIS] %N", i);
            IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name);
        }
        DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
        return Plugin_Handled;
    }

    // Get arguments.
    decl String:argString[LEN_CONVARS * 2];
    GetCmdArgString(argString, sizeof(argString));

    // Analyse arg string.
    decl String:sExtractedTarget[LEN_CONVARS];
    decl String:sExtractedReason[LEN_CONVARS];
    new iExtractedDuration = -1;
    new iAssumedTargetType = -1;
    if (!TryGetArgs(argString, sizeof(argString),
                   sExtractedTarget, sizeof(sExtractedTarget),
                   iAssumedTargetType, iExtractedDuration,
                   sExtractedReason, sizeof(sExtractedReason)))
    {
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                Invis_DoClient(admin, admin, cmdType, (iExtractedDuration != 0)); // <--- target is admin himself
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "t", false) == 0)
            {
                Invis_DoTeam(admin, TEAM_PRISONERS, cmdType, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "ct", false) == 0)
            {
                Invis_DoTeam(admin, TEAM_GUARDS, cmdType, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            if (strcmp(sExtractedTarget, "all", false) == 0)
            {
                Invis_DoTeam(admin, TEAM_PRISONERS, cmdType, (iExtractedDuration != 0));
                Invis_DoTeam(admin, TEAM_GUARDS, cmdType, (iExtractedDuration != 0));
                return Plugin_Handled;
            }
            else
            {
                ReplyToCommandGood(admin, "%s Target identifier \x03@%s\x04 is not valid for this command", MSG_PREFIX, sExtractedTarget);
                return Plugin_Handled;
            }
        }
        case TARGET_TYPE_USERID:
        {
            new target = GetClientOfUserId(StringToInt(sExtractedTarget));
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Invis_DoClient(admin, target, cmdType, (iExtractedDuration != 0));
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Invis_DoClient(admin, target, cmdType, (iExtractedDuration != 0));
        }
        case TARGET_TYPE_NAME:
        {
            decl targets[MAXPLAYERS + 1];
            new numFound;
            GetClientOfPartialName(sExtractedTarget, targets, numFound);
            if (numFound <= 0)
                ReplyToCommandGood(admin, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, sExtractedTarget);
            else if (numFound == 1)
            {
                new target = targets[0];
                if (!IsClientInGame(target))
                    ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
                else
                    Invis_DoClient(admin, target, cmdType, (iExtractedDuration != 0));
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Invis_MenuSelect);
                    SetMenuTitle(menu, (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS ?
                                        "Select Player To Make Invisible" :
                                        "Select Player To Make Visible"));
                    g_iCmdMenuCategories[admin] = cmdType;
                    g_iCmdMenuDurations[admin] = iExtractedDuration;
                    Format(g_sCmdMenuReasons[admin], LEN_CONVARS, sExtractedReason); // Reason not applicable
                    decl String:sUserid[LEN_INTSTRING];
                    decl String:name[MAX_NAME_LENGTH];
                    for (new i = 0; i < numFound; i++)
                    {
                        new t = targets[i];
                        if (!IsClientInGame(t))
                            continue;
                        if (!JB_IsPlayerAlive(t))
                            continue;

                        if (g_bIsInvisible[t])
                            Format(name, sizeof(name), "[INV] %N", t);
                        else
                            Format(name, sizeof(name), "[VIS] %N", t);
                        IntToString(GetClientUserId(t), sUserid, sizeof(sUserid));
                        AddMenuItem(menu, sUserid, name);
                    }
                    DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
                }
            }
        }
        default:
        {
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################


Invis_DoClient(admin, target, cmdType, bool:message=true)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Ensure target is alive.
    if (!JB_IsPlayerAlive(target))
    {
        ReplyToCommandGood(admin, "%s ERROR: %N is not alive", MSG_PREFIX, target);
        return;
    }

    // Ensure target is not already visible or invisible.
    if (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS)
    {
        if (g_bIsInvisible[target])
        {
            ReplyToCommandGood(admin, "%s ERROR: %N is already invisible", MSG_PREFIX, target);
            return;
        }
        MakeTotalPlayerInvisible(target, true);
    }
    else
    {
        if (!g_bIsInvisible[target])
        {
            ReplyToCommandGood(admin, "%s ERROR: %N is already visible", MSG_PREFIX, target);
            return;
        }
        MakeTotalPlayerVisible(target, true);
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Display messages.
    if (message)
        PrintToChatAll("%s \x03%N\x04 was made %s by \x03%s",
                       MSG_PREFIX,
                       target,
                       (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS ? "invisible" : "visible"),
                       adminName);
}

Invis_DoTeam(admin, team, cmdType, bool:message=true)
{
    // Make invisible or visible.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        if (!JB_IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != team)
            continue;

        if (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS)
            MakeTotalPlayerInvisible(i, true);
        else
            MakeTotalPlayerVisible(i, true);
    }

    // Get admin info.
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Display messages.
    if (message)
        PrintToChatAll("%s All \x03%s\x04 were made %s by \x03%s",
                       MSG_PREFIX,
                       (team == TEAM_PRISONERS ? "prisoners" : "guards"),
                       (cmdType == LOCALDEF_INVIS_CMDTYPE_INVIS ? "invisible" : "visible"),
                       adminName);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Invis_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new iUserid = StringToInt(sUserid);
        if (iUserid < 0)
        {
            if (iUserid == LOCALDEF_INVIS_MENUCHOICE_ALL)
            {
                Invis_DoTeam(admin, TEAM_PRISONERS, g_iCmdMenuCategories[admin], (g_iCmdMenuDurations[admin] != 0));
                Invis_DoTeam(admin, TEAM_GUARDS, g_iCmdMenuCategories[admin], (g_iCmdMenuDurations[admin] != 0));
            }
            else if (iUserid == LOCALDEF_INVIS_MENUCHOICE_ALLT)
                Invis_DoTeam(admin, TEAM_PRISONERS, g_iCmdMenuCategories[admin], (g_iCmdMenuDurations[admin] != 0));
            else if (iUserid == LOCALDEF_INVIS_MENUCHOICE_ALLCT)
                Invis_DoTeam(admin, TEAM_GUARDS, g_iCmdMenuCategories[admin], (g_iCmdMenuDurations[admin] != 0));
            else
                ReplyToCommandGood(admin, "%s Invalid selection for toggling visibility", MSG_PREFIX);
        }
        else
        {
            new target = GetClientOfUserId(iUserid);
            if (!target)
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            else
                Invis_DoClient(admin, target, g_iCmdMenuCategories[admin], (g_iCmdMenuDurations[admin] != 0));
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// ###################################### STOCKS ######################################
// ####################################################################################


stock GlowFollow(client)
{
    CreateTimer(0.02, Timer_CreateGlowEffect, client, TIMER_REPEAT);
}

stock MakeTotalPlayerInvisible(client, bool:message=false)
{
    // Cancel pending timer.
    if (g_hInvisButtonCheckTimers[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hInvisButtonCheckTimers[client]);
        g_hInvisButtonCheckTimers[client] = INVALID_HANDLE;
    }

    // Update tracker.
    g_bIsInvisible[client] = true;
    g_bIsActuallyInvisible[client] = true;

    // If they are not in the server, stop.
    if (!IsClientInGame(client) || !JB_IsPlayerAlive(client))
        return;

    // Define color.
    decl rgba[LEN_RGBA];
    rgba[0] = 255;
    rgba[1] = 255;
    rgba[2] = 255;
    rgba[3] = ((GetClientButtons(client) & IN_DUCK) ? INVIS_ALPHA_CROUCHING : INVIS_ALPHA_NORMAL);

    // Player's body.
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);

    // Player's weapons.
    SetPlayerWeaponColor(client, rgba);

    // Player's hat & stowed/holstered items.
    SetPlayerAttachmentColor(client, rgba);

    // Notify player.
    if (message)
    {
        for (new i = 0; i < 6; i++)
        {
            PrintToChat(client, "%s You have turned INVISIBLE (mostly)", MSG_PREFIX);
        }
        DisplayMSay(client, "You are invisible!", MENU_TIMEOUT_QUICK, "You are also a rebel\nSo don't complain if you get shot!");
    }

    // Create repeating timer to check their button presses.
    g_hInvisButtonCheckTimers[client] = CreateTimer(0.2, Invis_ButtonPressCheck, any:client, TIMER_REPEAT);

    // Invisible doesn't work in CS:GO using the traditional method.
    if (g_iGame == GAMETYPE_CSGO)
        GlowFollow(client);
}

stock MakeTotalPlayerVisible(client, bool:message=false)
{
    // Cancel pending timer.
    if (g_hInvisButtonCheckTimers[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hInvisButtonCheckTimers[client]);
        g_hInvisButtonCheckTimers[client] = INVALID_HANDLE;
    }

    // Update tracker.
    g_bIsInvisible[client] = false;
    g_bIsActuallyInvisible[client] = false;

    // If they are not in the server, stop.
    if (!IsClientInGame(client) || !JB_IsPlayerAlive(client))
        return;

    // Is he a rebel or not?
    // So we know whether to set him back to rebel color or normal color.
    new bool:isRebel = (g_hMakeNonRebelTimers[client] != INVALID_HANDLE);

    // Define color.
    decl rgba[LEN_RGBA];
    if (isRebel)
    {
        rgba[0] = g_iColorRed[0];
        rgba[1] = g_iColorRed[1];
        rgba[2] = g_iColorRed[2];
    }
    else
    {
        rgba[0] = 255;
        rgba[1] = 255;
        rgba[2] = 255;
    }
    rgba[3] = 255; // 0 would be completely invisible.

    // Player's body.
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);

    // Player's weapons.
    SetPlayerWeaponColor(client, rgba);

    // Player's hat & stowed/holstered items.
    SetPlayerAttachmentColor(client, rgba);

    // Notify player.
    if (message)
    {
        for (new i = 0; i < 6; i++)
        {
            PrintToChat(client, "%s You have turned VISIBLE", MSG_PREFIX);
        }
        DisplayMSay(client, "You are visible!", MENU_TIMEOUT_QUICK, "People can see you!!!");
    }

    // In case player was 3rd person.
    SetThirdPersonView(client, false);
}

stock SetPlayerWeaponColor(client, const rgba[LEN_RGBA])
{
    new iItems = FindSendPropOffs("CBaseCombatCharacter", "m_hMyWeapons");
    if (iItems != -1)
    {
        for (new i = 0; i <= 128; i += 4)
        {
            new nEntityID = GetEntDataEnt2(client, (iItems + i));
            if (!IsValidEdict(nEntityID))
                continue;
            SetEntityRenderMode(nEntityID, RENDER_TRANSCOLOR);
            SetEntityRenderColor(nEntityID, rgba[0], rgba[1], rgba[2], rgba[3]);
        }
    }
}

stock SetPlayerAttachmentColor(client, const rgba[LEN_RGBA])
{
    // Most attachments (like stowed guns), we cannot find them from the server because they're added client-side.
    // We can only only set a player property that signal's the client not to draw the attachments.
    // Except on TF2, it's different.

    if (g_iGame != GAMETYPE_TF2)
    {
        Invis_OnPostThinkPost(client);
    }

    else
    {
        new ent = -1;

        while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
        {
            if (GetEntDataEnt2(ent, FindSendPropOffs("CTFWearable", "m_hOwnerEntity")) == client)
            {
                SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
                SetEntityRenderColor(ent, rgba[0], rgba[1], rgba[2], rgba[3]);
            }
        }
    }

    // Experimental -- Finding hat attachments.
    /*
    new String:prop_test[6][32];
    prop_test[0] = "prop_dynamic";
    prop_test[1] = "prop_dynamic_multiplayer";
    prop_test[2] = "prop_physics";
    prop_test[3] = "prop_physics_multiplayer";
    prop_test[4] = "prop_static";
    prop_test[5] = "prop_ragdoll";
    for (new i = 0; i < sizeof(prop_test); i++)
    {
        new ent = -1;
        while ((ent = FindEntityByClassname(ent, prop_test[i])) != -1)
        {
            if (GetEntProp(ent, Prop_Send, "m_hOwnerEntity") == client)
            {
                SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
                SetEntityRenderColor(ent, rgba[0], rgba[1], rgba[2], rgba[3]);
            }
        }
    }
    */
}

// ####################################################################################
// ################################# TIMER CALLBACKS ##################################
// ####################################################################################

public Action:Timer_CreateGlowEffect(Handle:timer, any:client)
{
    if (!g_bIsInvisible[client] ||
        !IsClientInGame(client) ||
        !JB_IsPlayerAlive(client))
        return Plugin_Handled;

    new Float:origin[3];
    GetClientAbsOrigin(client, origin);
    origin[2] += 40.0;

    TE_SetupGlowSprite(origin, g_iSpriteGlow, 0.111, 1.4, 30);
    TE_SendToAll();

    return Plugin_Continue;
}

public Action:Invis_ButtonPressCheck(Handle:timer, any:data)
{
    // Extract passed data.
    new client = _:data;

    // Set global handle to invalid first, so we don't forget.
    if (!g_bIsInvisible[client] || !IsClientInGame(client))
    {
        g_bIsInvisible[client] = false;
        g_bIsActuallyInvisible[client] = false;

        g_hInvisButtonCheckTimers[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    // Define color for later use.
    decl rgba[LEN_RGBA];
    rgba[0] = 255;
    rgba[1] = 255;
    rgba[2] = 255;
    rgba[3] = 255;

    // Get client buttons.
    new iButtons = GetClientButtons(client);
    new bool:isWalking = ((iButtons & IN_SPEED) > 0);
    new bool:isShooting = ((iButtons & IN_ATTACK) > 0);
    new bool:isCrouching = ((iButtons & IN_DUCK) > 0);

    // Record player's walking state.
    if (g_bInvisIsWalking[client] != isWalking)
    {
        g_bInvisIsWalking[client] = isWalking;
        SetThirdPersonView(client, isWalking);
    }

    // Is player shooting?
    if (g_bInvisIsShooting[client] != isShooting)
    {
        g_bInvisIsShooting[client] = isShooting;
        rgba[3] = (isShooting ? INVIS_ALPHA_SHOOTING : (isCrouching ? INVIS_ALPHA_CROUCHING : INVIS_ALPHA_NORMAL));
        SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);   // Player's body
        SetPlayerWeaponColor(client, rgba);                                 // Player's weapons

        if (g_iGame != GAMETYPE_TF2)
        {
            SetPlayerAttachmentColor(client, rgba);                             // Player's hat & stowed/holstered items
        }

        return Plugin_Continue;
    }

    // Is player crouching?
    if (g_bInvisIsCrouching[client] != isCrouching)
    {
        g_bInvisIsCrouching[client] = isCrouching;
        rgba[3] = (isCrouching ? INVIS_ALPHA_CROUCHING : INVIS_ALPHA_NORMAL);
        SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);   // Player's body
        SetPlayerWeaponColor(client, rgba);                                 // Player's weapons

        if (g_iGame != GAMETYPE_TF2)
        {
            SetPlayerAttachmentColor(client, rgba);                             // Player's hat & stowed/holstered items
        }

        PrintHintText(client, "SUPER STEALTH MODE %s", (isCrouching ? "[ON] CUZ UR CROUCHING" : "[OFF] CUZ UR STANDING"));
        return Plugin_Continue;
    }

    // Done.
    return Plugin_Continue;
}