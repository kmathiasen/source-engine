public PlVers:__version =
{
    version = 5,
    filevers = "1.5.0-dev+3756",
    date = "07/17/2013",
    time = "09:45:20"
};
new Float:NULL_VECTOR[3];
new String:NULL_STRING[4];
public Extension:__ext_core =
{
    name = "Core",
    file = "core",
    autoload = 0,
    required = 0,
};
new MaxClients;
new g_iConnectTime[66];
new g_iJoinedSpec[66];
new g_iVisibleMaxPlayers = 46;
new Handle:g_hVisibleMaxPlayers;
public __ext_core_SetNTVOptional()
{
    MarkNativeAsOptional("GetFeatureStatus");
    MarkNativeAsOptional("RequireFeature");
    MarkNativeAsOptional("AddCommandListener");
    MarkNativeAsOptional("RemoveCommandListener");
    MarkNativeAsOptional("BfWriteBool");
    MarkNativeAsOptional("BfWriteByte");
    MarkNativeAsOptional("BfWriteChar");
    MarkNativeAsOptional("BfWriteShort");
    MarkNativeAsOptional("BfWriteWord");
    MarkNativeAsOptional("BfWriteNum");
    MarkNativeAsOptional("BfWriteFloat");
    MarkNativeAsOptional("BfWriteString");
    MarkNativeAsOptional("BfWriteEntity");
    MarkNativeAsOptional("BfWriteAngle");
    MarkNativeAsOptional("BfWriteCoord");
    MarkNativeAsOptional("BfWriteVecCoord");
    MarkNativeAsOptional("BfWriteVecNormal");
    MarkNativeAsOptional("BfWriteAngles");
    MarkNativeAsOptional("BfReadBool");
    MarkNativeAsOptional("BfReadByte");
    MarkNativeAsOptional("BfReadChar");
    MarkNativeAsOptional("BfReadShort");
    MarkNativeAsOptional("BfReadWord");
    MarkNativeAsOptional("BfReadNum");
    MarkNativeAsOptional("BfReadFloat");
    MarkNativeAsOptional("BfReadString");
    MarkNativeAsOptional("BfReadEntity");
    MarkNativeAsOptional("BfReadAngle");
    MarkNativeAsOptional("BfReadCoord");
    MarkNativeAsOptional("BfReadVecCoord");
    MarkNativeAsOptional("BfReadVecNormal");
    MarkNativeAsOptional("BfReadAngles");
    MarkNativeAsOptional("BfGetNumBytesLeft");
    MarkNativeAsOptional("PbReadInt");
    MarkNativeAsOptional("PbReadFloat");
    MarkNativeAsOptional("PbReadBool");
    MarkNativeAsOptional("PbReadString");
    MarkNativeAsOptional("PbReadColor");
    MarkNativeAsOptional("PbReadAngle");
    MarkNativeAsOptional("PbReadVector");
    MarkNativeAsOptional("PbReadVector2D");
    MarkNativeAsOptional("PbGetRepeatedFieldCount");
    MarkNativeAsOptional("PbReadRepeatedInt");
    MarkNativeAsOptional("PbReadRepeatedFloat");
    MarkNativeAsOptional("PbReadRepeatedBool");
    MarkNativeAsOptional("PbReadRepeatedString");
    MarkNativeAsOptional("PbReadRepeatedColor");
    MarkNativeAsOptional("PbReadRepeatedAngle");
    MarkNativeAsOptional("PbReadRepeatedVector");
    MarkNativeAsOptional("PbReadRepeatedVector2D");
    MarkNativeAsOptional("PbSetInt");
    MarkNativeAsOptional("PbSetFloat");
    MarkNativeAsOptional("PbSetBool");
    MarkNativeAsOptional("PbSetString");
    MarkNativeAsOptional("PbSetColor");
    MarkNativeAsOptional("PbSetAngle");
    MarkNativeAsOptional("PbSetVector");
    MarkNativeAsOptional("PbSetVector2D");
    MarkNativeAsOptional("PbAddInt");
    MarkNativeAsOptional("PbAddFloat");
    MarkNativeAsOptional("PbAddBool");
    MarkNativeAsOptional("PbAddString");
    MarkNativeAsOptional("PbAddColor");
    MarkNativeAsOptional("PbAddAngle");
    MarkNativeAsOptional("PbAddVector");
    MarkNativeAsOptional("PbAddVector2D");
    MarkNativeAsOptional("PbReadMessage");
    MarkNativeAsOptional("PbReadRepeatedMessage");
    MarkNativeAsOptional("PbAddMessage");
    VerifyCoreVersion();
    return 0;
}

public OnPluginStart()
{
    g_hVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
    g_iVisibleMaxPlayers = GetConVarInt(g_hVisibleMaxPlayers);
    HookConVarChange(g_hVisibleMaxPlayers, OnConVarChanged);
    HookEvent("player_team", OnPlayerTeam, EventHookMode:1);
    CreateTimer(180, Timer_KickAFK, any:0, 1);
    return 0;
}

public OnClientPutInServer(client)
{
    g_iConnectTime[client] = GetTime({0,0});
    g_iJoinedSpec[client] = GetTime({0,0});
    return 0;
}

public OnConVarChanged(Handle:CVar, String:oldv[], String:newv[])
{
    if (g_hVisibleMaxPlayers == CVar)
    {
        g_iVisibleMaxPlayers = GetConVarInt(g_hVisibleMaxPlayers);
    }
    return 0;
}

public OnPlayerTeam(Handle:event, String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetEventInt(event, "team") <= 1)
    {
        g_iJoinedSpec[client] = GetTime({0,0});
    }
    return 0;
}

public Action:Timer_KickAFK(Handle:timer, data)
{
    new kick = -1;

    if (g_iVisibleMaxPlayers + -3 > GetClientCount(false))
    {
        return Action:0;
    }

    new i = 1;
    while (i <= MaxClients)
    {
        if (IsClientInGame(i))
        {
            new adminsubtract;
            new bits = GetUserFlagBits(i);
            if (bits & ADMFLAG_ROOT)
            {
                adminsubtract += 1440;
            }
            else
            {
                if (bits & ADMFLAG_CHANGEMAP)
                {
                    adminsubtract += 720;
                }
                if (bits & ADMFLAG_KICK)
                {
                    adminsubtract += 360;
                }
                if (bits)
                {
                    adminsubtract += 180;
                }
            }
            if (!IsClientInGame(i))
            {
            }
        }
        i++;
    }
    if (0 < kick)
    {
        KickClient(kick, "AFK In Full Server");
    }
    return Action:0;
}

