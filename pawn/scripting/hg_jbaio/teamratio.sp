
// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

bool:TeamRatio_OnJoinTeam(client, team)
{
    /* This function returns true to allow the player to join the team, false to deny */

    switch(team)
    {
        case TEAM_PRISONERS:
        {
            return true;
        }

        case TEAM_GUARDS:
        {
            if (!CTSlotOpen(GetClientTeam(client) == TEAM_PRISONERS))
            {
                //ChangeClientTeam(client, TEAM_PRISONERS);
                EmitSoundToClient(client, g_sSoundDeny);
                PrintToChat(client, "%s There are currently too many Guards!", MSG_PREFIX);
                return false;
            }
            return true;
        }
    }
    return true;
}

bool:CTSlotOpen(bool:from_t, admin_add=0)
{
    // Get current number of Prisoners and Guards.
    new total_prisoners = 0;
    new total_guards = 0;
    new this_team = TEAM_SPEC;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            this_team = GetClientTeam(i);
            switch(this_team)
            {
                case TEAM_PRISONERS:
                {
                    total_prisoners += 1;
                }
                case TEAM_GUARDS:
                {
                    total_guards += 1;
                }
            }
        }
    }

    total_guards += 1;
    if (from_t)
        total_prisoners -= 1;

    total_prisoners += admin_add;

    // Are there enough players to enforce?
    new minplayers = GetConVarInt(g_hCvRatioMinPlayers);
    new Float:ratio = GetConVarFloat(g_hCvRatioPrisonersToGuards);

    if (total_prisoners + total_guards >= minplayers &&
       total_guards > total_prisoners / ratio)
       return false;
    return true;
}
