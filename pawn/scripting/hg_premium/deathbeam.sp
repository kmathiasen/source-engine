// ###################### GLOBALS ######################

new bool:g_bDeathBeamEnabled;
new Handle:g_hDeathBeamEnabled = INVALID_HANDLE;

// ###################### EVENTS ######################

public DeathBeam_OnPluginStart()
{
    g_hDeathBeamEnabled = CreateConVar("hg_premium_deathbeam", "1.0", "Enables/Disables death beam.", FCVAR_NONE, true, 0.0, true, 1.0);
}

public DeathBeam_OnMapStart()
{
    g_bDeathBeamEnabled = GetConVarInt(g_hDeathBeamEnabled) ? true : false;

    if (g_hGetWeaponPosition == INVALID_HANDLE)
    {
        LogError("Error: Weapon_ShootPosition signature appears to be invalid; Death Beam disabled.");
        g_bDeathBeamEnabled = false;
    }
}

// ###################### ACTIONS ######################

stock DeathBeam_OnPlayerDeath(victim, attacker)
{
    if(g_bDeathBeamEnabled &&
      (g_bClientEquippedItem[victim][Item_DeathBeam] ||
       g_bClientEquippedItem[attacker][Item_DeathBeam]))
    {
        new Float:victimOrigin[3];
        new Float:attackerOrigin[3];

        new color[4]={250,250,250,200};

        // We only want to show a death beam in the case of kills where there was a real attacker and a real victim and it was not a self kill.
        if(victim && attacker && attacker != victim && IsClientInGame(victim) && !IsFakeClient(victim))
        {
            SDKCall(g_hGetWeaponPosition, attacker, attackerOrigin);
            GetClientEyePosition(victim, victimOrigin);

            TE_SetupBeamPoints(victimOrigin, attackerOrigin, g_iSpriteLaser, 0, 0, 0, 10.0, 3.0, 3.0, 10, 0.0, color, 0);
            TE_SendToClient(victim);
        }
    }
}