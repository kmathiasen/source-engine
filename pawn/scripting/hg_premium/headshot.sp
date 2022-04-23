// ###################### GLOBALS ######################


new Handle:g_hHeadshotEnabled;
new bool:g_bHeadshotEnabled;

new g_HeadshotExplosionSprite;
new g_HeadshotSmokeSprite;

new String:g_iExplodeSound[PLATFORM_MAX_PATH];

new Float:iHeadshotNormal[3] = {0.0, 0.0, 1.0};

// ###################### EVENTS ######################

public Headshot_OnPluginStart()
{
    g_hHeadshotEnabled = CreateConVar("hg_premium_incendiary_ammo", "1.0", "Enables/Disables headshot explosions.", FCVAR_NONE, true, 0.0, true, 1.0);
}

public Headshot_OnMapStart() 
{
    g_bHeadshotEnabled = GetConVarInt(g_hHeadshotEnabled) ? true : false;
    
    Format(g_iExplodeSound, sizeof(g_iExplodeSound), (g_iGame == GAMETYPE_CSS) ? "ambient/explosions/explode_8.wav" : "weapons/hegrenade/explode5.wav");
    PrecacheSound(g_iExplodeSound, true);
    
    g_HeadshotExplosionSprite = PrecacheModel("sprites/blueglow1.vmt");
    g_HeadshotSmokeSprite = PrecacheModel("sprites/steam1.vmt");
}


// ###################### ACTIONS ######################

stock Headshot_OnPlayerDeath(victim, attacker, bool:headshot)
{
    if(g_bHeadshotEnabled &&
       g_bClientEquippedItem[attacker][Item_ExplosiveHeadShot] &&
       !g_bClientEquippedItem[attacker][Item_StealthMode])
    {
        if(victim == attacker)
            return;

        new Float:iVec[3];
        GetClientAbsOrigin(victim, Float:iVec);

        if(headshot)
        {
            TE_SetupExplosion(iVec, g_HeadshotExplosionSprite, 5.0, 1, 0, 50, 40, iHeadshotNormal);
            TE_SendToAll();

            TE_SetupSmoke(iVec, g_HeadshotSmokeSprite, 10.0, 3);
            TE_SendToAll();

            EmitAmbientSound(g_iExplodeSound, iVec, victim, SNDLEVEL_NORMAL);
        }
    }

    return;
}
