
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_MUTING_CMDTYPE_MUTE 0
#define LOCALDEF_MUTING_CMDTYPE_UNMUTE 1
#define LOCALDEF_MUTING_CMDTYPE_SUPERMUTE 2
#define TALK_INTERVAL 0.25

new g_iMaxClientsTalking = 1;
new g_iMutedRoundsLeft[MAXPLAYERS + 1];
new g_iHatEntity[MAXPLAYERS + 1];
new bool:g_bWasMutedForHLDJ[MAXPLAYERS + 1];
new bool:g_bUsingHLDJ[MAXPLAYERS + 1];
new bool:g_bRegularMute[MAXPLAYERS + 1];
new bool:g_bIsSuperMuted[MAXPLAYERS + 1];
new bool:g_bStaffTeamMute;
new Float:g_fRoundStartMuteEnds;
new Float:g_fTeamUnmutedAt[TEAM_GUARDS + 1];
new Float:g_fLastTalked[MAXPLAYERS + 1];
new MuteReasons:g_MuteReason[MAXPLAYERS + 1];
new Handle:g_hCSGOVoice = INVALID_HANDLE;

new g_iCanSpeakToAll = VOICE_LISTENALL|VOICE_SPEAKALL;
new g_iCanSpeakToNone = VOICE_LISTENALL|VOICE_MUTED;

// Storage.
new Handle:g_hMutedByAdmin = INVALID_HANDLE;                // Trie to hold how many rounds a Steam ID should stay muted.
new Handle:g_hMutedByAdminArray = INVALID_HANDLE;           // Parallel array
new Handle:g_hArrTalkingOrder = INVALID_HANDLE;             // Order in which people started talking

// Timers.
new Handle:g_hRoundStartUnmuteTimer = INVALID_HANDLE;       // Timer (non-repeating) that delays a certain amount each round before unmuting players who should be unmuted.
new Handle:g_hMuteOnDeathTimers[MAXPLAYERS + 1];            // Timer (non-repeating) that delays a certain amount after a player dies before muting him.
new Handle:g_hAdminTUnmuteTimer = INVALID_HANDLE;           // Timer (non-repeating) that delays a certain amount after a an admin mutes a team.
new Handle:g_hAdminCTUnmuteTimer = INVALID_HANDLE;          // Timer (non-repeating) that delays a certain amount after a an admin mutes a team.

// Declare commonly used ConVars.
new Float:g_fDeathMuteDuration;

// Mute Reasons
enum MuteReasons
{
    Muting_Dead = 0,
    Muting_Spectator,
    Muting_RoundStart,
    Muting_Admin,
    Muting_Team,
}

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

forward OnClientSpeaking(client);

Muting_OnPluginStart()
{
    RegAdminCmd("mute", Command_Mute, ADMFLAG_KICK, "Mutes a player by Steam ID (or partial name, if player is in server)");
    RegConsoleCmd("supermute", Command_Mute, "Mutes a player by Steam ID (or partial name, if player is in server)");
    RegAdminCmd("unmute", Command_Mute, ADMFLAG_KICK, "Unmutes a player by Steam ID (or partial name, if player is in server)");

    AddCommandOverride("sm_mute", Override_Command, ADMFLAG_ROOT);
    AddCommandOverride("sm_unmute", Override_Command, ADMFLAG_ROOT);

    g_hMutedByAdmin = CreateTrie();
    g_hMutedByAdminArray = CreateArray(ByteCountToCells(LEN_STEAMIDS));
    g_hArrTalkingOrder = CreateArray();

    // Voice hook for CS:S, TF2
    CreateConVar("sv_voicecodec", "vaudio_speex");
    ServerCommand("meta load addons/voicehook_mm");
    ServerCommand("sm exts load voiceannounce.ext.2.ep2v.so");

    // Voice hook for CS:GO
    if (g_iGame == GAMETYPE_CSGO)
    {
        new offset = GameConfGetOffset(GetConfig(), "OnVoiceTransmit");

        if (offset == -1)
        {
            SetFailState("Failed to find OnVoiceTransmit");
        }

        if (GetFeatureStatus(FeatureType_Native, "DHookCreate") != FeatureStatus_Available)
        {
            LogError("Critical Error: Could not find DHookCreate");
        }

        else
        {
            g_hCSGOVoice = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, CSGOVoicePost);
        }
    }

    CreateTimer(0.15, Timer_MicSpam, _, TIMER_REPEAT);
    CreateTimer(0.50, Timer_CheckHLDJ, _, TIMER_REPEAT);
}

Muting_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_fDeathMuteDuration = GetConVarFloat(g_hCvMuteOnDeathDelay);
    g_iMaxClientsTalking = GetConVarInt(g_hCvMaxClientsTalking);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvMuteOnDeathDelay, Muting_OnConVarChange);
    HookConVarChange(g_hCvMaxClientsTalking, Muting_OnConVarChange);
}

public Muting_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvMuteOnDeathDelay)
        g_fDeathMuteDuration = GetConVarFloat(g_hCvMuteOnDeathDelay);

    else if (CVar == g_hCvMaxClientsTalking)
        g_iMaxClientsTalking = GetConVarInt(g_hCvMaxClientsTalking);
}

public MRESReturn:CSGOVoicePost(client, Handle:hReturn) 
{
    OnClientSpeaking(client);
    return MRES_Ignored;
}  

public OnClientSpeaking(client)
{
    if (g_bRegularMute[client])
    {
        switch (g_MuteReason[client])
        {
            case Muting_Dead:
            {
                PrintCenterText(client, "Dead players are muted");
            }

            case Muting_Spectator:
            {
                PrintCenterText(client, "Spectators are muted");
            }

            case Muting_RoundStart:
            {
                PrintCenterText(client, "Round start mute ends in %0.1f seconds", g_fRoundStartMuteEnds - GetGameTime());
            }

            case Muting_Admin:
            {
                PrintCenterText(client, "You were muted by an admin for %d more round(s)", g_iMutedRoundsLeft[client]);
            }

            case Muting_Team:
            {
                PrintCenterText(client, "Your team is muted for another %0.1f seconds", g_fTeamUnmutedAt[GetClientTeam(client)] - GetGameTime());
            }
        }

        return;
    }

    new Float:time = GetEngineTime();

    if (time - g_fLastTalked[client] > TALK_INTERVAL &&
        FindValueInArray(g_hArrTalkingOrder, client) == -1)
    {
        PushArrayCell(g_hArrTalkingOrder, client);
        g_fLastTalked[client] = time;

        QueryClientConVar(client, "voice_inputfromfile", QueryHLDJCallback);
        Timer_MicSpam(INVALID_HANDLE, 0);
    }

    else
    {
        g_fLastTalked[client] = time;
    }
}

Muting_OnClientPutInServer(client, bool:auth=false)
{
    // Mute newly joined players.
    MuteClient(client, Muting_Spectator);

    if (g_iGame == GAMETYPE_CSGO && !auth && !IsFakeClient(client))
    {
        if (GetFeatureStatus(FeatureType_Native, "DHookEntity") != FeatureStatus_Available)
        {
            LogError("Critical Error: Could not find DHookEntity");
        }

        else
        {
            DHookEntity(g_hCSGOVoice, true, client);
        }
    }
}

Muting_OnJoinTeam(client, team)
{
    if (team <= TEAM_SPEC || !JB_IsPlayerAlive(client))
    {
        MuteClient(client, Muting_Spectator);
        return;
    }
}

Muting_OnRndStrt_General()
{
    // Ensure proper cvars are set.
    ServerCommand("sv_alltalk 1");
    g_bStaffTeamMute = false;

    // Cancel pending timers.
    if (g_hRoundStartUnmuteTimer != INVALID_HANDLE)
    {
        CloseHandle(g_hRoundStartUnmuteTimer);
        g_hRoundStartUnmuteTimer = INVALID_HANDLE;
    }
    if (g_hAdminTUnmuteTimer != INVALID_HANDLE)
    {
        g_fTeamUnmutedAt[TEAM_PRISONERS] = 0.0;
        CloseHandle(g_hAdminTUnmuteTimer);
        g_hAdminTUnmuteTimer = INVALID_HANDLE;
    }

    if (g_hAdminCTUnmuteTimer != INVALID_HANDLE)
    {
        g_fTeamUnmutedAt[TEAM_GUARDS] = 0.0;
        CloseHandle(g_hAdminCTUnmuteTimer);
        g_hAdminCTUnmuteTimer = INVALID_HANDLE;
    }

    // Notify all about the mute, and unmute a short time seconds later.
    new Float:startMuteDuration = GetConVarFloat(g_hCvStartMuteLength);
    g_fRoundStartMuteEnds = GetGameTime() + startMuteDuration;
    PrintToChatAll("%s Prisoners may not speak for %i seconds", MSG_PREFIX, RoundToNearest(startMuteDuration));
    g_hRoundStartUnmuteTimer = CreateTimer(startMuteDuration, Muting_UnmutePrisoners, _);

    // Reduce mutes by one round.
    decl String:thisSteam[LEN_STEAMIDS];
    for (new i = 0; i < GetArraySize(g_hMutedByAdminArray); i++)
    {
        new muted_rounds_left;
        GetArrayString(g_hMutedByAdminArray, i, thisSteam, sizeof(thisSteam));
        if (!GetTrieValue(g_hMutedByAdmin, thisSteam, muted_rounds_left) ||
            --muted_rounds_left <= 0)
        {
            new matching_client = GetClientOfSteam(thisSteam);
            if (matching_client > 0)
                g_bIsSuperMuted[matching_client] = false;

            RemoveFromTrie(g_hMutedByAdmin, thisSteam);
            RemoveFromArray(g_hMutedByAdminArray, i--);
            continue;
        }
        SetTrieValue(g_hMutedByAdmin, thisSteam, muted_rounds_left);

        new matching_client = GetClientOfSteam(thisSteam);
        if (matching_client > 0 && g_bIsSuperMuted[matching_client])
        {
            Muting_AttachBubble(matching_client);
            g_iMutedRoundsLeft[matching_client] = muted_rounds_left;
        }
    }

    // Reset clients.
    new dummy;
    for (new i = 1; i <= MaxClients; i++)
    {
        // Cancel pending timers.
        if (g_hMuteOnDeathTimers[i] != INVALID_HANDLE)
        {
            CloseHandle(g_hMuteOnDeathTimers[i]);
            g_hMuteOnDeathTimers[i] = INVALID_HANDLE;
        }

        // Mute or unmute.
        if (!IsClientInGame(i))
            continue;
        new team = GetClientTeam(i);
        switch(team)
        {
            case TEAM_PRISONERS:
            {
                // Mute at beginning of round.
                MuteClient(i, Muting_RoundStart);
            }
            case TEAM_GUARDS:
            {
                // Unmute now (unless they have been muted by admin).
                GetClientAuthString2(i, thisSteam, sizeof(thisSteam));
                if (!GetTrieValue(g_hMutedByAdmin, thisSteam, dummy))
                {
                    if (JB_IsPlayerAlive(i))
                        UnmuteClient(i);
                    else
                    {
                        // There is no combination of flags I can think of that will allow players to talk to dead players only.
                        // So they will stay muted for now, and will be unmuted next time they are alive during a round-start.
                    }
                }

                else
                {
                    PrintToChat(i,
                                "%s You have \x03%d\x04 rounds left in your mute",
                                MSG_PREFIX, dummy);
                }
            }
        }
    }
}

Muting_OnPlayerSpawn(client)
{
    // Has everyone only spawned once?
    // We only want to unmute people if they've already spawned once.
    g_iHatEntity[client] = -1;

    if (!g_bHasRoundStarted)
        return;

    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, sizeof(steam));

    new mute_rounds_left;
    GetTrieValue(g_hMutedByAdmin, steam, mute_rounds_left);

    // They're muted by admin, so we don't want to unmute them.
    // However, decreasing this value is done in Muting_OnRndStrt_EachValid
    if (mute_rounds_left > 0)
    {
        PrintToChat(client,
                    "%s You have \x03%d\x04 rounds left in your mute",
                    MSG_PREFIX, mute_rounds_left);

        g_iMutedRoundsLeft[client] = mute_rounds_left;
        if (g_bIsSuperMuted[client])
            Muting_AttachBubble(client);
        return;
    }

    // No need to check the team, because this isn't a round start unmute.
    UnmuteClient(client);
}

Muting_OnLeadDeath()
{
    if (g_iEndGame == ENDGAME_NONE)
    {
        new dur = 5;
        Muting_DoTeam(0, TEAM_PRISONERS, LOCALDEF_MUTING_CMDTYPE_MUTE, dur, false);
        PrintToChatAll("%s Lead is dead, terrorists are muted for \x03%d\x04 seconds", MSG_PREFIX, dur);
    }
}

Muting_OnPlayerDeath(client)
{
    // Mute on death (after a short delay).
    g_hMuteOnDeathTimers[client] = CreateTimer(g_fDeathMuteDuration, Muting_MuteOnDeath, client);

    KillBubble(client);
}

Muting_OnClientDisconnect(client)
{
    KillBubble(client);
    g_bIsSuperMuted[client] = false;

    new index = FindValueInArray(g_hArrTalkingOrder, client);

    if (index > -1)
    {
        RemoveFromArray(g_hArrTalkingOrder, index);
    }
}

stock KillBubble(client)
{
    if (g_iHatEntity[client] > 0 && IsValidEntity(g_iHatEntity[client]))
        AcceptEntityInput(g_iHatEntity[client], "kill");
    g_iHatEntity[client] = -1;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Mute(admin, args)
{
    // The command itself could be different things (mute, unmute, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType;
    if ((cmd[0] == 'u' || cmd[0] == 'U') && (cmd[1] == 'n' || cmd[1] == 'N'))
        cmdType = LOCALDEF_MUTING_CMDTYPE_UNMUTE;

    else if (cmd[0] == 's')
        cmdType = LOCALDEF_MUTING_CMDTYPE_SUPERMUTE;

    else
        cmdType = LOCALDEF_MUTING_CMDTYPE_MUTE;

    if (cmdType == LOCALDEF_MUTING_CMDTYPE_SUPERMUTE)
    {
        new bits = GetUserFlagBits(admin);
        if (!(bits & (ADMFLAG_CUSTOM5|ADMFLAG_CHANGEMAP|ADMFLAG_ROOT)))
        {
            PrintToChat(admin, "%s Y'all ain't authorized to run his command", MSG_PREFIX);
            return Plugin_Handled;
        }
    }

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Mute_MenuSelect);
        SetMenuTitle(menu, (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE ?
                            "Select Player To Mute" :
                            "Select Player To Unmute"));
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = 1;
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, "");
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];
        new cnt;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i))
                continue;
            if (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE || cmdType == LOCALDEF_MUTING_CMDTYPE_SUPERMUTE)
            {
                if (GetClientListeningFlags(i) == g_iCanSpeakToNone && g_bRegularMute[i])
                    continue;
            }
            else // if (cmdType == LOCALDEF_MUTING_CMDTYPE_UNMUTE)
            {
                if (GetClientListeningFlags(i) == g_iCanSpeakToAll)
                    continue;
            }
            cnt++;
            GetClientName(i, name, sizeof(name));
            IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name);
        }
        if (cnt)
            DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
        else
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin,
                               "%s There is nobody %s",
                               MSG_PREFIX,
                               (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE
                                    ? "Unmuted to Mute"
                                    : "Muted to Unmute"));
            CloseHandle(menu);
        }
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
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                Muting_DoClient(admin, admin, iExtractedDuration, cmdType); // <--- target is admin himself
                return Plugin_Handled;
            }

            else
            {
                if (!(GetUserFlagBits(admin) & ADMFLAG_ROOT))
                    iExtractedDuration = -1;

                // They're not root, and they're not trusted
                // And there's currently a staff mute
                else if (!(GetUserFlagBits(admin) & ADMFLAG_CHANGEMAP|ADMFLAG_ROOT) &&
                         g_bStaffTeamMute)
                {
                    EmitSoundToClient(admin, g_sSoundDeny);
                    ReplyToCommandGood(admin, "%s There is currently a team mute in progress which was initiated by a staff member", MSG_PREFIX);
                    return Plugin_Handled;
                }

                if (strcmp(sExtractedTarget, "t", false) == 0)
                {
                    Muting_DoTeam(admin, TEAM_PRISONERS, cmdType, iExtractedDuration);
                    return Plugin_Handled;
                }
                else if (strcmp(sExtractedTarget, "ct", false) == 0)
                {
                    Muting_DoTeam(admin, TEAM_GUARDS, cmdType, iExtractedDuration);
                    return Plugin_Handled;
                }
                else if (strcmp(sExtractedTarget, "all", false) == 0)
                {
                    Muting_DoTeam(admin, TEAM_PRISONERS, cmdType, iExtractedDuration);
                    Muting_DoTeam(admin, TEAM_GUARDS, cmdType, iExtractedDuration);
                    return Plugin_Handled;
                }
                else
                {
                    EmitSoundToClient(admin, g_sSoundDeny);
                    ReplyToCommandGood(admin, "%s Target identifier \x03@%s\x04 is not valid for this command", MSG_PREFIX, sExtractedTarget);
                    return Plugin_Handled;
                }
            }
        }
        case TARGET_TYPE_USERID:
        {
            new target = GetClientOfUserId(StringToInt(sExtractedTarget));
            if (!target)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            }
            else
                Muting_DoClient(admin, target, iExtractedDuration, cmdType);
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            }
            else
                Muting_DoClient(admin, target, iExtractedDuration, cmdType);
        }
        case TARGET_TYPE_NAME:
        {
            decl targets[MAXPLAYERS + 1];
            new numFound;
            GetClientOfPartialName(sExtractedTarget, targets, numFound);
            if (numFound <= 0)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, sExtractedTarget);
            }
            else if (numFound == 1)
            {
                new target = targets[0];
                if (!IsClientInGame(target))
                {
                    EmitSoundToClient(admin, g_sSoundDeny);
                    ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
                }
                else
                    Muting_DoClient(admin, target, iExtractedDuration, cmdType);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Mute_MenuSelect);
                    SetMenuTitle(menu, (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE ?
                                        "Select Player To Mute" :
                                        "Select Player To Unmute"));
                    g_iCmdMenuCategories[admin] = cmdType;
                    g_iCmdMenuDurations[admin] = iExtractedDuration;
                    Format(g_sCmdMenuReasons[admin], LEN_CONVARS, sExtractedReason);
                    decl String:sUserid[LEN_INTSTRING];
                    decl String:name[MAX_NAME_LENGTH];
                    for (new i = 0; i < numFound; i++)
                    {
                        new t = targets[i];
                        GetClientName(t, name, sizeof(name));
                        IntToString(GetClientUserId(t), sUserid, sizeof(sUserid));
                        AddMenuItem(menu, sUserid, name);
                    }
                    DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
                }
            }
        }
        default:
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

/*
* Internal Functions
* Credits go to GoD-Tony
*/
stock Handle:GetConfig()
{
    static Handle:hGameConf = INVALID_HANDLE;

    if (hGameConf == INVALID_HANDLE)
    {
        hGameConf = LoadGameConfigFile("hgjb.games");
    }

    return hGameConf;
}


stock MuteClient(client, MuteReasons:reason)
{
    SetClientListeningFlags(client, g_iCanSpeakToNone);
    g_bRegularMute[client] = true;
    g_MuteReason[client] = reason;
}

stock UnmuteClient(client)
{
    SetClientListeningFlags(client, g_iCanSpeakToAll);
    g_bRegularMute[client] = false;
}

public Action:Timer_CheckHLDJ(Handle:timer, any:data)
{
    for (new i = 0; i < GetArraySize(g_hArrTalkingOrder); i++)
    {
        new client = GetArrayCell(g_hArrTalkingOrder, i);

        if (GetClientListeningFlags(client) == g_iCanSpeakToAll)
        {
            QueryClientConVar(client, "voice_inputfromfile", QueryHLDJCallback);
        }
    }

    return Plugin_Continue;
}

public QueryHLDJCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
    if (StringToInt(cvarValue) != 0)
    {
        g_bUsingHLDJ[client] = true;
    }
    
    else
    {
        g_bUsingHLDJ[client] = false;
    }
}

public Action:Timer_MicSpam(Handle:timer, any:data)
{
    new leadIndex = FindValueInArray(g_hArrTalkingOrder, g_iLeadGuard);
    new playingHLDJ = 0;

    // Lead has priority to play HLDJ
    if (leadIndex > -1 && g_bUsingHLDJ[g_iLeadGuard])
    {
        playingHLDJ = g_iLeadGuard;
    }

    for (new i = 0; i < GetArraySize(g_hArrTalkingOrder); i++)
    {
        new client = GetArrayCell(g_hArrTalkingOrder, i);

        if (!IsClientTalking(client))
        {
            RemoveFromArray(g_hArrTalkingOrder, i--);
            leadIndex = FindValueInArray(g_hArrTalkingOrder, g_iLeadGuard);

            if (g_bWasMutedForHLDJ[client])
            {
                g_bWasMutedForHLDJ[client] = false;
                PrintCenterText(client, " \n");
            }

            if (!g_bRegularMute[client])
            {
                SetClientListeningFlags(client, g_iCanSpeakToAll);
            }
        }

        if (i != leadIndex)
        {
            // Only allow g_iMaxTalkingCount players to talk at once, but always let the lead.
            if (i >= g_iMaxClientsTalking - (leadIndex >= g_iMaxClientsTalking ? 1 : 0) &&
                GetClientListeningFlags(client) != g_iCanSpeakToNone)
            {
                SetClientListeningFlags(client, g_iCanSpeakToNone);
                PrintHintText(client,
                              "%d People are already talking (%d max)\nTemporarily muted",
                              GetArraySize(g_hArrTalkingOrder), g_iMaxClientsTalking);
            }

            // They're one of the # of allowed people to talk
            else
            {
                // They're playing HLDJ over lead
                if (g_bUsingHLDJ[client] &&
                    leadIndex > -1 && 
                    g_iEndGame == ENDGAME_NONE)
                {
                    PrintCenterText(client, "You are temporarily muted for playing HLDJ while lead is talking");

                    if (GetClientListeningFlags(client) != g_iCanSpeakToNone)
                    {
                        SetClientListeningFlags(client, g_iCanSpeakToNone);
                        g_bWasMutedForHLDJ[client] = true;
                    }
                }

                // Someone is already playing HLDJ (no more need for "one or none")
                else if (g_bUsingHLDJ[client] && playingHLDJ > 0)
                {
                    PrintCenterText(client, "%N is already playing HLDJ.\nYou are muted until you turn yours off", playingHLDJ);

                    if (GetClientListeningFlags(client) != g_iCanSpeakToNone)
                    {
                        SetClientListeningFlags(client, g_iCanSpeakToNone);
                        g_bWasMutedForHLDJ[client] = true;
                    }
                }

                // They were just playing HLDJ over lead, or someone else who was playing HLDJ before them but aren't any more
                else if (g_bWasMutedForHLDJ[client])
                {
                    g_bWasMutedForHLDJ[client] = false;

                    if (!g_bRegularMute[client])
                    {
                        if (g_bUsingHLDJ[client])
                        {
                            playingHLDJ = client;
                        }

                        PrintHintText(client, "Unmuted after playing HLDJ over lead\nor someone else playing HLDJ before you");
                        SetClientListeningFlags(client, g_iCanSpeakToAll);
                    }
                }

                // They're talking regularily. Unmute
                else
                {
                    if (!g_bRegularMute[client])
                    {
                        if (g_bUsingHLDJ[client])
                        {
                            playingHLDJ = client;
                        }

                        SetClientListeningFlags(client, g_iCanSpeakToAll);
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}

public bool:IsClientTalking(client)
{
    return GetEngineTime() - g_fLastTalked[client] < TALK_INTERVAL;
}

stock Muting_AttachBubble(client)
{
    CreateTimer(0.01, Timer_AttachBubble, client);
}

public Action:Timer_AttachBubble(Handle:timer, any:client)
{
    Muting_OnClientDisconnect(client);

    g_iHatEntity[client] = CreateEntityByName("prop_dynamic_override");
    decl String:hatname[MAX_NAME_LENGTH];

    Format(hatname, sizeof(hatname), "bubble_%d", GetClientUserId(client));

    DispatchKeyValue(client, "targetname", hatname);
    DispatchKeyValue(g_iHatEntity[client], "parentname", hatname);
    DispatchKeyValue(g_iHatEntity[client], "model", "models/extras/muted/muted.mdl");
    DispatchKeyValue(g_iHatEntity[client], "Solid", "0");
    DispatchSpawn(g_iHatEntity[client]);

    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    origin[2] += 22.5;

    TeleportEntity(g_iHatEntity[client], origin, NULL_VECTOR, NULL_VECTOR);

    SetVariantString(hatname);
    AcceptEntityInput(g_iHatEntity[client], "SetParent");
    AcceptEntityInput(g_iHatEntity[client], "TurnOn");

    SetVariantString("idle");
    AcceptEntityInput(g_iHatEntity[client] , "SetAnimation");

    SetVariantString("forward");
    AcceptEntityInput(g_iHatEntity[client], "SetParentAttachmentMaintainOffset");
}

Muting_DoClient(admin, target, duration, cmdType)
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Get admin info
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    // Get target info.
    decl String:targetSteam[LEN_STEAMIDS];
    GetClientAuthString2(target, targetSteam, sizeof(targetSteam));

    if (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE || cmdType == LOCALDEF_MUTING_CMDTYPE_SUPERMUTE)
    {
        // Ensure duration is within limits.
        new max_rounds = GetConVarInt(g_hCvAdminMaxMuteRounds);
        new flags = GetUserFlagBits(admin);
        new current_rounds;
        GetTrieValue(g_hMutedByAdmin, targetSteam, current_rounds);
        if (duration <= 0) duration = 1;
        if (flags & ADMFLAG_ROOT)
            max_rounds *= 3;
        else if (flags & ADMFLAG_CHANGEMAP)
            max_rounds *= 2;
        if (duration > max_rounds)
            duration = max_rounds;
        if (max_rounds < current_rounds)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s That player has been muted by a HG staff member.", MSG_PREFIX);
            ReplyToCommandGood(admin, "%s You can not change their mute.", MSG_PREFIX);
            return;
        }

        if (cmdType == LOCALDEF_MUTING_CMDTYPE_SUPERMUTE)
        {
            EmitSoundToAll(g_sSoundHaha);
            g_bIsSuperMuted[target] = true;
            Muting_AttachBubble(target);
        }

        // Set mute status in trie.
        SetTrieValue(g_hMutedByAdmin, targetSteam, duration);
        g_iMutedRoundsLeft[target] = duration;

        // Add them to the parallel array.
        if (FindStringInArray(g_hMutedByAdminArray, targetSteam) == -1)
            PushArrayString(g_hMutedByAdminArray, targetSteam);

        // Mute.
        MuteClient(target, Muting_Admin);

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was muted by \x03%s\x04 for \x03%i\x04 rounds", MSG_PREFIX, target, adminName, duration);
        LogAction(admin, target, "\"%L\" muted \"%L\" (rounds \"%d\")", admin, target, duration);
    }

    else // if (cmdType == LOCALDEF_MUTING_CMDTYPE_UNMUTE)
    {
        new rounds_left = 0;
        new max_rounds = GetConVarInt(g_hCvAdminMaxMuteRounds);
        new flags = GetUserFlagBits(admin);

        GetTrieValue(g_hMutedByAdmin, targetSteam, rounds_left);

        if (rounds_left > max_rounds &&
            !(flags & ADMFLAG_ROOT) &&
            !(flags & ADMFLAG_CHANGEMAP))
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s That player has been muted by a HG staff member.", MSG_PREFIX);
            ReplyToCommandGood(admin, "%s You can not unmute them.", MSG_PREFIX);
            return;
        }

        // Set mute status in trie.
        RemoveFromTrie(g_hMutedByAdmin, targetSteam);

        // No longer super muted!
        g_bIsSuperMuted[target] = false;
        KillBubble(target);

        // Remove them from the parallel trie.
        new index = FindStringInArray(g_hMutedByAdminArray, targetSteam);
        if (index > -1)
            RemoveFromArray(g_hMutedByAdminArray, index);

        // Unmute.
        UnmuteClient(target);

        // Display messages.
        PrintToChatAll("%s \x03%N\x04 was unmuted by \x03%s\x04", MSG_PREFIX, target, adminName);
        LogAction(admin, target, "\"%L\" unmuted \"%L\"", admin, target);
    }
}

Muting_DoTeam(admin, team, cmdType, duration=-1, bool:msg=true)
{
    // Get admin info
    decl String:adminName[MAX_NAME_LENGTH];
    if ((admin <= 0) || (!IsClientInGame(admin)))
        Format(adminName, sizeof(adminName), "CONSOLE");
    else
        GetClientName(admin, adminName, sizeof(adminName));

    if (cmdType == LOCALDEF_MUTING_CMDTYPE_MUTE)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && (GetClientTeam(i) == team) && i != g_iLeadGuard)
            {
                MuteClient(i, Muting_Team);
            }
        }

        // Get duration to mute.
        new Float:dur;

        if (duration > 0)
            dur = float(duration);

        else
        {
            dur = GetConVarFloat(g_hCvAdminTeamMuteSeconds);

            if (admin > 0)
            {
                new bits = GetUserFlagBits(admin);
                if (bits & ADMFLAG_ROOT)
                    dur *= 6;

                else if (bits & ADMFLAG_CHANGEMAP)
                    dur *= 3;
            }
        }

        if (GetGameTime() + dur >= g_fTeamUnmutedAt[team])
        {
            g_fTeamUnmutedAt[team] = GetGameTime() + dur;

            if (dur > GetConVarFloat(g_hCvAdminTeamMuteSeconds))
                g_bStaffTeamMute = true;

            // Display messages.
            if (msg)
            {
                PrintToChatAll("%s \x03%s\x04 were muted for \x03%i seconds\x04 by \x03%s\x04",
                               MSG_PREFIX,
                               team == TEAM_GUARDS ? "Counter-Terrorists" : "Terrorists",
                               RoundToNearest(dur), adminName);
            }

            if (msg || admin > 0)
            {
                LogAction(admin, -1, "\"%L\" muted \"%s\" (seconds \"%d\")", admin, team == TEAM_GUARDS ? "Counter-Terrorists" : "Terrorists", RoundToNearest(dur));
            }

            // Start timer to unmute in a few seconds (kill pending unmute timer first).
            if (team == TEAM_PRISONERS)
            {
                if (g_hAdminTUnmuteTimer != INVALID_HANDLE)
                    CloseHandle(g_hAdminTUnmuteTimer);
                g_hAdminTUnmuteTimer = CreateTimer(dur, Muting_UnmuteTeamMute, team);
            }

            else
            {
                if (g_hAdminCTUnmuteTimer != INVALID_HANDLE)
                    CloseHandle(g_hAdminCTUnmuteTimer);
                g_hAdminCTUnmuteTimer = CreateTimer(dur, Muting_UnmuteTeamMute, team);
            }
        }

        else if (admin > 0)
        {
            PrintToChat(admin, "%s Muting this team would result in a shorter mute than currently active", MSG_PREFIX);
        }
    }

    else // if (cmdType == LOCALDEF_MUTING_CMDTYPE_UNMUTE)
    {
        decl String:thisSteam[LEN_STEAMIDS];
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && (GetClientTeam(i) == team))
            {
                if (JB_IsPlayerAlive(i))
                {
                    // Is this person muted by an admin?
                    new mute_rounds_left = 0;
                    GetClientAuthString2(i, thisSteam, sizeof(thisSteam));
                    GetTrieValue(g_hMutedByAdmin, thisSteam, mute_rounds_left);
                    if (mute_rounds_left <= 0)
                    {
                        UnmuteClient(i);
                    }
                }
            }
        }
        // Display messages.
        PrintToChatAll("%s \x03%s\x04 were unmuted by \x03%s\x04",
                       MSG_PREFIX,
                       team == TEAM_GUARDS ? "Counter-Terrorists" : "Terrorists",
                       adminName);
        LogAction(admin, -1, "\"%L\" unmuted \"%s\"", admin, team == TEAM_GUARDS ? "Counter-Terrorists" : "Terrorists");
    }
}

public Action:Muting_MuteOnDeath(Handle:timer, any:client)
{
    g_hMuteOnDeathTimers[client] = INVALID_HANDLE;
    if (IsClientInGame(client)) MuteClient(client, Muting_Dead);
}

public Action:Muting_UnmutePrisoners(Handle:timer, any:data)
{
    g_hRoundStartUnmuteTimer = INVALID_HANDLE;
    decl String:thisSteam[LEN_STEAMIDS];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            if (GetClientTeam(i) == TEAM_PRISONERS)
            {
                GetClientAuthString2(i, thisSteam, sizeof(thisSteam));
                new mute_rounds_left = 0;
                GetTrieValue(g_hMutedByAdmin, thisSteam, mute_rounds_left);
                if (mute_rounds_left <= 0)
                {
                    if (JB_IsPlayerAlive(i))
                    {
                        UnmuteClient(i);
                    }
                    else
                    {
                        MuteClient(i, Muting_Dead);
                    }
                }

                else
                {
                    PrintToChat(i,
                                "%s You have \x03%d\x04 rounds left in your mute",
                                MSG_PREFIX, mute_rounds_left);
                }
            }
        }
    }
    PrintToChatAll("%s Prisoners may speak now", MSG_PREFIX);
}

public Action:Muting_UnmuteTeamMute(Handle:timer, any:team)
{
    g_bStaffTeamMute = false;
    g_fTeamUnmutedAt[team] = 0.0;

    if (team == TEAM_PRISONERS)
        g_hAdminTUnmuteTimer = INVALID_HANDLE;

    else
        g_hAdminCTUnmuteTimer = INVALID_HANDLE;

    decl String:thisSteam[LEN_STEAMIDS];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && (GetClientTeam(i) == team))
        {
            if (JB_IsPlayerAlive(i))
            {
                // Is this person muted by an admin?
                new mute_rounds_left = 0;
                GetClientAuthString2(i, thisSteam, sizeof(thisSteam));
                GetTrieValue(g_hMutedByAdmin, thisSteam, mute_rounds_left);
                if (mute_rounds_left <= 0)
                {
                    UnmuteClient(i);
                }
            }
        }
    }
    // Display messages.
    PrintToChatAll("%s \x03Team\x04 mute expired", MSG_PREFIX);
}

// ####################################################################################
// ####################################### MENUS ######################################
// ####################################################################################

public Mute_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new target = GetClientOfUserId(StringToInt(sUserid));
        if (!target)
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
        }
        else
            Muting_DoClient(admin,
                            target,
                            g_iCmdMenuDurations[admin],
                            g_iCmdMenuCategories[admin]);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}
