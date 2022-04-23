// ###################### GLOBALS ######################

new Handle:g_hLaserAimEnabled;
new bool:g_bLaserAimEnabled;

new m_iFOV;

// ###################### EVENTS ######################

public Laser_Aim_OnPluginStart()
{
    g_hLaserAimEnabled = CreateConVar("hg_premium_laser_aim", "1.0", "Enables/Disables sniper laser aim.", FCVAR_NONE, true, 0.0, true, 1.0);

    m_iFOV = FindSendPropOffs("CBasePlayer","m_iFOV");
}

public Laser_Aim_OnMapStart()
{
    g_bLaserAimEnabled = GetConVarInt(g_hLaserAimEnabled) ? true : false;
    
    if(g_hGetWeaponPosition == INVALID_HANDLE)
    {
        LogError("Error: Weapon_ShootPosition signature appears to be invalid; Laser sight disabled.");
        g_bLaserAimEnabled = false;
    }
}

public Laser_Aim_OnGameFrame()
{
    if (g_bLaserAimEnabled)
    {
        for (new i=1; i<=MaxClients; i++)
        {
            if(g_bClientEquippedItem[i][Item_LaserAim] &&
               !g_bClientEquippedItem[i][Item_StealthMode] &&
               IsClientInGame(i) && IsPlayerAlive(i))
            {
                new String:s_playerWeapon[32];
                GetClientWeapon(i, s_playerWeapon, sizeof(s_playerWeapon));

                new i_playerFOV;
                i_playerFOV = GetEntData(i, m_iFOV);

                if(StrEqual("awp", s_playerWeapon[7]) ||
                   StrEqual("sg550", s_playerWeapon[7]) ||
                   StrEqual("g3sg1", s_playerWeapon[7]) ||
                   StrEqual("ssg08", s_playerWeapon[7]) ||
                   StrEqual("scar20", s_playerWeapon[7]) ||
                   StrEqual("scout", s_playerWeapon[7]))
                    if((i_playerFOV == 15) || (i_playerFOV == 40) || (i_playerFOV == 10))
                        Laser_Aim_CreateBeam(i);
            }
        }
    }
}

stock Laser_Aim_OnPlayerSpawn(client)
{
    g_iPlayerLaserColor[client] = _:GetColorIndex(g_sClientSubValue[client][Item_LaserAim]);
}

// ###################### ACTIONS ######################

public Action:Laser_Aim_CreateBeam(any:client)
{
    new Float:f_playerViewOrigin[3];
    SDKCall( g_hGetWeaponPosition, client, f_playerViewOrigin );

    new Float:f_playerViewDestination[3];		
    Laser_Aim_GetPlayerEye(client, f_playerViewDestination);

    new Float:distance = GetVectorDistance( f_playerViewOrigin, f_playerViewDestination );
    new Float:percentage = 0.4 / ( distance / 100 );
    new Float:f_newPlayerViewOrigin[3];
    f_newPlayerViewOrigin[0] = f_playerViewOrigin[0] + ( ( f_playerViewDestination[0] - f_playerViewOrigin[0] ) * percentage );
    f_newPlayerViewOrigin[1] = f_playerViewOrigin[1] + ( ( f_playerViewDestination[1] - f_playerViewOrigin[1] ) * percentage ) - 0.08;
    f_newPlayerViewOrigin[2] = f_playerViewOrigin[2] + ( ( f_playerViewDestination[2] - f_playerViewOrigin[2] ) * percentage );

    TE_SetupBeamPoints( f_newPlayerViewOrigin, f_playerViewDestination, g_iSpriteLaser, 0, 0, 0, 0.1, 0.1, 0.1, 1, 0.0, g_iColors[g_iPlayerLaserColor[client]], 0);
    new clients[MAXPLAYERS+1];
    new x = 0;

    for (new i=1; i<=MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && (i != client))
        {
            clients[x] = i;
            x++;
        }
    }

    TE_Send(clients, x);
    
    TE_SetupGlowSprite( f_playerViewDestination, g_iGlowSprites[g_iPlayerLaserColor[client]], 0.1, 0.1, g_iColors[g_iPlayerLaserColor[client]][3] );
    TE_SendToAll();

    return Plugin_Continue;
}

// ###################### FUNCTIONS ######################

bool:Laser_Aim_GetPlayerEye(client, Float:pos[3])
{
    new Float:vAngles[3], Float:vOrigin[3];
    GetClientEyePosition(client,vOrigin);
    GetClientEyeAngles(client, vAngles);

    new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, Laser_Aim_TraceEntityFilter);

    if(TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        CloseHandle(trace);
        return true;
    }
    CloseHandle(trace);
    return false;
}

public bool:Laser_Aim_TraceEntityFilter(entity, contentsMask, any:client)
{
    return entity > MaxClients;
}