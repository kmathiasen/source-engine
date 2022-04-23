
new bool:g_bAlreadyDisplayedRadarMessage = false;
new bool:g_bRadarHacksEnabled = false;


/* ----- Events ----- */


stock Radar_OnMapStart()
{
    // Hook the radar, so we can stop people from camping all day.
    new index = FindEntityByClassname(0, "cs_player_manager");

    if (index > -1)
    {
        if (g_iGame == GAMETYPE_CSS)
            SDKHook(index, SDKHook_ThinkPost, Radar_OnThinkPost_CSS);

        else
            SDKHook(index, SDKHook_ThinkPost, Radar_OnThinkPost_CSGO);
    }
}

stock Radar_OnRoundStart()
{
    g_bAlreadyDisplayedRadarMessage = false;
    g_bRadarHacksEnabled = false;
}

stock Radar_OnPlayerDeath(alive_ts)
{
    if (alive_ts <= g_iRadarHackStartAfterTs)
    {
        g_bRadarHacksEnabled = true;

        if  (!g_bAlreadyDisplayedRadarMessage &&
             g_iEndGame != ENDGAME_WARDAY)
        {
            g_bAlreadyDisplayedRadarMessage = true;

            PrintToChatAll("%s There are only \x03%d \x04prisoners... tracking devices enabled...", MSG_PREFIX, alive_ts);

            if (g_iGame == GAMETYPE_TF2)
                TF2_WallHacks();

            else
                PrintToChatAll("%s Guards can now see prisoners on their radars", MSG_PREFIX);
        }
    }
}


/* ----- Hooks and Callbacks ----- */


public Radar_OnThinkPost_CSS(entity)
{
    new past = GetTime() - g_iRoundStartTime;
    if (past < g_iRadarHackStartAfterTime &&
        g_iEndGame != ENDGAME_WARDAY &&
        !g_bRadarHacksEnabled ||
        g_bIsThursday)
        return;

    else if (past == g_iRadarHackStartAfterTime &&
             !g_bAlreadyDisplayedRadarMessage)
    {
        g_bAlreadyDisplayedRadarMessage = true;

        PrintToChatAll("%s Prisoner tracking devices enabled...", MSG_PREFIX);
        PrintToChatAll("%s Guards can now see prisoners on their radars", MSG_PREFIX);
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            if (JB_IsPlayerAlive(i))
            {
                if (GetClientTeam(i) == TEAM_PRISONERS && (!g_bIsInvisible[i] || !(GetTime() % 7)))
                {
                    SetEntData(entity, m_bPlayerSpotted + i, true, 4, true);
                }
            }

            else
            {
                SetEntData(entity, m_bPlayerSpotted + i, false, 4, true);
            }
        }
    }

    SetEntData(entity, m_bBombSpotted, true, 4, true);
}

public Radar_OnThinkPost_CSGO(entity)
{
    new past = GetTime() - g_iRoundStartTime;
    if (past < g_iRadarHackStartAfterTime && 
        g_iEndGame != ENDGAME_WARDAY &&
        !g_bRadarHacksEnabled ||
        g_bIsThursday)
        return;

    else if (past == g_iRadarHackStartAfterTime &&
             !g_bAlreadyDisplayedRadarMessage &&
             g_iEndGame != ENDGAME_WARDAY)
    {
        g_bAlreadyDisplayedRadarMessage = true;

        PrintToChatAll("%s Prisoner tracking devices enabled...", MSG_PREFIX);
        PrintToChatAll("%s Guards can now see prisoners on their radars", MSG_PREFIX);
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            if (JB_IsPlayerAlive(i))
            {
                if (GetClientTeam(i) == TEAM_PRISONERS)
                {
                    SetEntData(i, m_bPlayerSpotted, true, 4, true);
                }
            }

            else
            {
                SetEntData(i, m_bPlayerSpotted, false, 4, true);
            }
        }
    }
}
