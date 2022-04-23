
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Regex patterns.
#define REGEX_SIMPLENAME "^[a-z0-9_]+\\z"
#define REGEX_STEAMID "^STEAM_(0|1):(0|1):\\d{1,9}\\z"
new Handle:g_hPatternSteam = INVALID_HANDLE;

// Colors. {R, G, B, A}
new g_iColorRed[LEN_RGBA] = {255, 25, 15, 255};
new g_iColorGreen[LEN_RGBA] = {25, 255, 30, 255};
new g_iColorBlue[LEN_RGBA] = {50, 75, 255, 255};
new g_iColorGray[LEN_RGBA] = {128, 128, 128, 255};
new g_iColorWhite[LEN_RGBA] = {255, 255, 255, 255};

// Models, and sprites (indicies).
new g_iSpriteBeam = INVALID_ENT_REFERENCE;
new g_iSpriteRing = INVALID_ENT_REFERENCE;
new g_iSpriteLightning = INVALID_ENT_REFERENCE;
new g_iSpriteExplosion = INVALID_ENT_REFERENCE;
new g_iSpriteSmoke = INVALID_ENT_REFERENCE;

// Sound files (.wav or .mp3).
// Only .mp3 works in CSGO.
// Use fwd slashes for dirs.
// Make relative to "/cstrike/sound/" for CSS.
// Make relative to "/csgo/sound/music/" for CSGO.
new String:g_sSoundDeny[64] = "buttons/weapon_cant_buy.wav";
new String:g_sSoundBlip[64] = "buttons/blip1.wav";
new String:g_sSoundAlarm[64] = "hg/brassbell.mp3";
new String:g_sSoundExplode[64] = "hg/explosion.mp3";
new String:g_sSoundThunder[64] = "hg/thunderstrike.mp3";
new String:g_sSoundJihad[64] = "hg/rebelyell.mp3";
new String:g_sSoundPowerup[64] = "hg/powerup.mp3";
new String:g_sSoundFail[64] = "hg/fail.mp3";
new String:g_sSoundHaha[64] = "hg/haha.mp3";

// Trie to hold the names and slots of all weapons.  Gunplant uses this information.
new Handle:g_hWepsAndItems = INVALID_HANDLE;

// ####################################################################################
// ################################# STOCK FUNCTIONS ##################################
// ####################################################################################

stock GetClientAuthString2(client, String:authShort[], maxlength)
{
    decl String:authLong[LEN_STEAMIDS];
    GetClientAuthString(client, authLong, sizeof(authLong));

    CopyStringFrom(authShort, maxlength, authLong, sizeof(authLong), 8);
}

stock CopyStringFrom(String:buffer[], bufferLen, const String:source[], sourceLen, startIndex, numCharsToCopy=0)
{
    if (startIndex < 0) startIndex = 0;
    if (startIndex > sourceLen) return 0;
    if (numCharsToCopy <= 0) numCharsToCopy = bufferLen;

    // Ensure we don't try to write more chars than will fit in the buffer.
    if (numCharsToCopy > bufferLen) numCharsToCopy = bufferLen;

    // Ensure we don't try to read more chars than the source has.
    new sourceCharsAvail = sourceLen - startIndex;
    if (startIndex + numCharsToCopy > sourceCharsAvail)
        numCharsToCopy = sourceCharsAvail;

    // Copy from start index.
    new numCopied, chr;
    for (new i = 0; i < numCharsToCopy; i++)
    {
        chr = source[startIndex + i];
        buffer[i] = chr;
        numCopied++;
        if (chr == '\0')
            break;
    }

    // Ensure last char is null terminator.
    buffer[numCopied] = '\0';

    // Return how many chars were copied.
    return numCopied;
}

stock GetClientOfSteam(const String:steam[])
{
    /*
        Returns client or 0 if no client in server matched the supplied Steam ID.
    */

    decl String:this_steam[LEN_STEAMIDS];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientAuthorized(i))
        {
            GetClientAuthString2(i, this_steam, sizeof(this_steam));
            if (strcmp(this_steam, steam, false) == 0)
            {
                // Matching client was found.
                return i;
            }
        }
    }
    return 0; // <--- client
}

stock GetClientOfPartialName(const String:name[], targets[MAXPLAYERS + 1], &numFound)
{
    // Let's see if it's a partial match for someone currently in the server.
    decl String:this_name[MAX_NAME_LENGTH];
    for (new i = 1; i <= MaxClients; i++)
    {
        //is player still in game?
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientName(i, this_name, sizeof(this_name));
            if (StrContains(this_name, name, false) >= 0)
                targets[numFound++] = i;
        }
    }
}

stock NetAddr2Long(const String:ip[])
{
    decl String:pieces[4][16];
    new nums[4];

    if (ExplodeString(ip, ".", pieces, 4, 16) != 4)
        return 0;

    nums[0] = StringToInt(pieces[0]);
    nums[1] = StringToInt(pieces[1]);
    nums[2] = StringToInt(pieces[2]);
    nums[3] = StringToInt(pieces[3]);

    return ((nums[0] << 24) | (nums[1] << 16) | (nums[2] << 8) | nums[3]);
}

stock ReplyToCommandGood(client, const String:format[], any:...)
{
    decl String:message[255];
    VFormat(message, sizeof(message), format, 3);
    if (client && IsClientInGame(client))
        PrintToChat(client, message);
    else
    {
        ReplaceString(message, sizeof(message), "\x01", "");
        ReplaceString(message, sizeof(message), "\x03", "");
        ReplaceString(message, sizeof(message), "\x04", "");
        ReplaceString(message, sizeof(message), "\x05", "");
        ReplyToCommand(client, message);
    }
}

stock GetUUID(String:buffer[LEN_HEXUUID], bool:withDashes)
{
    new set1 = GetURandomInt();
    new set2 = GetURandomInt();
    new set3 = GetURandomInt();
    new set4 = GetURandomInt();

    // for convenience... kinda
    new byte1  = set1 & 0x000000FF;
    new byte2  = ( set1 & 0x0000FF00 ) >> 8;
    new byte3  = ( set1 & 0x00FF0000 ) >> 16;
    new byte4  = ( set1 & 0xFF000000 ) >> 24;
    new byte5  = set2 & 0x000000FF;
    new byte6  = ( set2 & 0x0000FF00 ) >> 8;
    new byte7  = ( set2 & 0x00FF0000 ) >> 16;
    new byte8  = ( set2 & 0xFF000000 ) >> 24;
    new byte9  = set3 & 0x000000FF;
    new byte10 = ( set3 & 0x0000FF00 ) >> 8;
    new byte11 = ( set3 & 0x00FF0000 ) >> 16;
    new byte12 = ( set3 & 0xFF000000 ) >> 24;
    new byte13 = set4 & 0x000000FF;
    new byte14 = ( set4 & 0x0000FF00 ) >> 8;
    new byte15 = ( set4 & 0x00FF0000 ) >> 16;
    new byte16 = ( set4 & 0xFF000000 ) >> 24;

    new version = ( byte7 & 0x0F ) | 0x40;

    new variant = ( byte9 & 0x3F ) | 0x80;

    if (withDashes)
        Format(buffer, sizeof(buffer),
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            byte1, byte2, byte3, byte4,
            byte5, byte6,
            version, byte8,
            variant, byte10,
            byte11, byte12, byte13, byte14, byte15, byte16
            );
    else
        Format(buffer, sizeof(buffer),
            "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            byte1, byte2, byte3, byte4,
            byte5, byte6,
            version, byte8,
            variant, byte10,
            byte11, byte12, byte13, byte14, byte15, byte16
            );
}

stock DisplayMSay(client, const String:title[], time, const String:format[], any:...)
{
    decl String:message[255];
    VFormat(message, sizeof(message), format, 4);

    new Handle:panel = CreatePanel();

    SetPanelTitle(panel, title);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

    DrawPanelText(panel, message);
    DrawPanelItem(panel, "", ITEMDRAW_SPACER);

    SetPanelCurrentKey(panel, (g_iGame == GAMETYPE_CSS ? 10 : 9));
    DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, EmptyMenuSelect, time);
    CloseHandle(panel);
}

stock DisplayMSayAll(const String:title[], time, const String:format[], any:...)
{
    decl String:message[255];
    VFormat(message, sizeof(message), format, 4);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        new Handle:panel = CreatePanel();

        SetPanelTitle(panel, title);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER);

        DrawPanelText(panel, message);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER);

        SetPanelCurrentKey(panel, (g_iGame == GAMETYPE_CSS ? 10 : 9));
        DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);

        SendPanelToClient(panel, i, EmptyMenuSelect, time);
        CloseHandle(panel);
    }
}

stock KeyHintText(client, const String:message[], any:...)
{
    decl String:formatted[256];
    VFormat(formatted, sizeof(formatted), message, 3);

    new Handle:hBuffer = StartMessageOne("KeyHintText", client);
    BfWriteByte(hBuffer, 1);
    BfWriteString(hBuffer, formatted);
    EndMessage();
}

stock CreateBeaconBlip(client, rgba[LEN_RGBA])
{
    if (client <= 0)
        return;

    decl Float:vec[LEN_VEC];

    GetClientAbsOrigin(client, vec);
    vec[2] += 10;

    TE_SetupBeamRingPoint(vec, 10.0, 350.0, g_iSpriteBeam, g_iSpriteRing, 0, 15, 0.5, 5.0, 0.0, g_iColorGray, 10, 0);
    TE_SendToAll();

    TE_SetupBeamRingPoint(vec, 10.0, 350.0, g_iSpriteBeam, g_iSpriteRing, 0, 15, 0.5, 5.0, 0.0, rgba, 10, 0);
    TE_SendToAll();

    GetClientEyePosition(client, vec);
    EmitAmbientSound(g_sSoundBlip, vec, client, SNDLEVEL_RAIDSIREN);
}

stock CreateStandardBeam(Float:start[LEN_VEC], Float:end[LEN_VEC], rgba[LEN_RGBA], client=0)
{
    TE_SetupBeamPoints(start, end, g_iSpriteBeam, g_iSpriteRing, 1, 1, 30.0, 5.0, 5.0, 0, 10.0, rgba, 255);
    if (client < 0)
        TE_SendToClient(client);
    else
        TE_SendToAll();
}

public Action:CreateStandardBeamDelayed(Handle:timer, any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new client;
    decl Float:start[LEN_VEC];
    decl Float:end[LEN_VEC];
    decl rgba[LEN_RGBA];
    client = ReadPackCell(Handle:data);
    ReadPackArrayF(Handle:data, start, sizeof(start));
    ReadPackArrayF(Handle:data, end, sizeof(end));
    ReadPackArrayC(Handle:data, rgba, sizeof(rgba));
    CloseHandle(Handle:data);

    // Draw.
    CreateStandardBeam(start, end, rgba, client);

    // Done.
    return Plugin_Stop;
}

/*
    // Debug draw dashed lines.
    decl Float:start[LEN_VEC], Float:end[LEN_VEC];

    PopulateVector(start, 929.0, -988.0, 133.0);
    PopulateVector(end, 300.0, -256.0, 20.0);
    CreateDashedBeam(start, end, g_iColorGray);

    PopulateVector(start, 706.0, -1172.0, 20.0);
    PopulateVector(end, 479.0, -1419.0, 20.0);
    CreateDashedBeam(start, end, g_iColorGray);

    PopulateVector(start, 1402.0, -1408.0, 0.0);
    PopulateVector(end, 1286.0, -1004.0, 192.0);
    CreateDashedBeam(start, end, g_iColorGray);

    PopulateVector(start, 1286.0, -1004.0, 192.0);
    PopulateVector(end, 1813.0, -734.0, -20.0);
    CreateDashedBeam(start, end, g_iColorGray);
*/

stock CreateDashedBeam(Float:start[LEN_VEC], Float:end[LEN_VEC], rgba[LEN_RGBA], Float:dashLength=100.0, Float:gapLength=10.0, client=0)
{
    /* NOTE:
        X is stored in index [0]
        Y is stored in index [1]
        Z is stored in index [2]
    */

    /* NOTE:
        To create a dashed beam, we need to draw a bunch of segments along the line of the beam.
        Each segment should be a particular length (dashLength).
        The segments should be separated by gaps of a particular length (gapLength).
    */

    // What is the length of the overall beam from start to end?
    new Float:beamLength = GetVectorDistance(start, end);

    // What are the legs in each dimension of the overall beam?
    decl Float:beamOffsets[LEN_VEC];
    for (new i = 0; i < LEN_VEC; i++)
    {
        beamOffsets[i] = FloatAbs(start[i] > end[i] ? start[i] - end[i] : end[i] - start[i]);
        if (start[i] > end[i])
            beamOffsets[i] = 0.0 - beamOffsets[i];
    }

    // Scale the legs of the overall beam to get the dash and gap legs.
    new Float:scaleFactor;
    scaleFactor = dashLength / beamLength;
    decl Float:dashOffsets[LEN_VEC];
    for (new i = 0; i < LEN_VEC; i++)
        dashOffsets[i] = beamOffsets[i] * scaleFactor;
    scaleFactor = gapLength / beamLength;
    decl Float:gapOffsets[LEN_VEC];
    for (new i = 0; i < LEN_VEC; i++)
        gapOffsets[i] = beamOffsets[i] * scaleFactor;

    // Hold the starting XYZ and ending XYZ of each dash to draw.
    decl Float:dashStart[LEN_VEC], Float:dashEnd[LEN_VEC];

    // The starting XYZ of the first dash is that of the beam's line itself.
    PopulateVector(dashStart, start[0], start[1], start[2]);

    // Calculate & draw each dash on this line.
    new Float:currentPos; // 0.0
    new Float:delay = 0.1;
    while (currentPos < beamLength)
    {
        // The end point of the dash will be the start point offset by the legs of a dash.
        for (new i = 0; i < LEN_VEC; i++)
            dashEnd[i] = dashStart[i] + dashOffsets[i];

      //CreateStandardBeam(dashStart, dashEnd, rgba);
        // Schedule this dash to be drawn in the next gameframe.
        new Handle:data = CreateDataPack();
        WritePackCell(data, client);
        WritePackArrayF(data, dashStart, sizeof(dashStart));
        WritePackArrayF(data, dashEnd, sizeof(dashEnd));
        WritePackArrayC(data, rgba, sizeof(rgba));
        CreateTimer(delay, CreateStandardBeamDelayed, any:data);
        delay += 0.1;

        // Increment the position counter, which keeps track of how many more dashes we need to do.
        currentPos += (dashLength + gapLength);

        // Now we need to update the next dash's starting XYZ by adding the legs of a gap.
        for (new i = 0; i < LEN_VEC; i++)
            dashStart[i] = dashEnd[i] + gapOffsets[i];
    }
}

stock FindPlayerClump(team)
{
    // Get list of all clients on specified team.
    new candidateCount = 0;
    decl candidates[MAXPLAYERS + 1];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        if (!IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != team)
            continue;
        candidates[candidateCount] = i;
        candidateCount++;
    }

    // How many candidates?
    if (candidateCount <= 0)
        return 0;
    else if (candidateCount == 1)
        return candidates[0];
    else if (candidateCount <= 8) // An arbitrary low number where it's not worth finding the center because spawning on any of them would be fine.
        return candidates[GetRandomInt(0, candidateCount - 1)];

    // Record all their X and Y positions.
    decl Float:posListX[candidateCount];
    decl Float:posListY[candidateCount];
    decl Float:orig[LEN_VEC];
    for (new i = 0; i < candidateCount; i++)
    {
        GetClientAbsOrigin(candidates[i], orig);
        posListX[i] = orig[0];
        posListY[i] = orig[1];
    }

    // Let's test 5 random players and see if these guys have other players close to them.
    new numTested;
    while(numTested < 5)
    {
        new candidateToTest = GetRandomInt(0, candidateCount - 1);
        new Float:clientX = posListX[candidateToTest];
        new Float:clientY = posListY[candidateToTest];
        new Float:thisX, Float:thisY;
        new Float:diffX, Float:diffY;
        new numClose;
        for (new i = 0; i < candidateCount; i++)
        {
            if (i == candidateToTest)
                continue;
            thisX = posListX[i];
            thisY = posListY[i];
            diffX = (clientX > thisX ? clientX - thisX : thisX - clientX);
            diffY = (clientY > thisY ? clientY - thisY : thisY - clientY);
            if (diffX < 100.0 && diffY < 100.0)
                numClose++;
            if (numClose >= 2) // If the candidate being tested has at least 2 people next to him...
                return candidates[candidateToTest];
        }
        numTested++;
    }

    // None of the 5 players we tested have close people, so let's just pick a random person to spawn on.
    return candidates[GetRandomInt(0, candidateCount - 1)];
}

stock PopulateVector(Float:arr[LEN_VEC], Float:x, Float:y, Float:z)
{
    arr[0] = x;
    arr[1] = y;
    arr[2] = z;
}

stock WritePackArrayC(Handle:data, arr[], size)
{
    for (new i = 0; i < size; i++)
        WritePackCell(data, arr[i]);
}

stock WritePackArrayF(Handle:data, Float:arr[], size)
{
    for (new i = 0; i < size; i++)
        WritePackFloat(data, arr[i]);
}

stock ReadPackArrayC(Handle:data, buffer[], size)
{
    for (new i = 0; i < size; i++)
        buffer[i] = ReadPackCell(data);
}

stock ReadPackArrayF(Handle:data, Float:buffer[], size)
{
    for (new i = 0; i < size; i++)
        buffer[i] = ReadPackFloat(data);
}

stock TeamSwitchSlay(client, switchTo)
{
    // Is player in-game?
    if (IsClientInGame(client))
    {
        // If he is on the CT team, slay & switch him.
        if (GetClientTeam(client) != switchTo)
        {
            // Slay.
            if (IsPlayerAlive(client))
                SlapPlayer(client, GetClientHealth(client) + 101);

            // Switch.
            CS_SwitchTeam(client, switchTo);
        }
    }
}

public EmptyCallback(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    Db_QueryFailed(conn, fetch, error);
}

bool:Db_QueryFailed(Handle:conn, Handle:fetch, const String:error[])
{
    if (conn == INVALID_HANDLE || fetch == INVALID_HANDLE)
    {
        Db_Disconnect(conn);
        LogError(error);
        return true;
    }
    return false;
}

public Db_Disconnect(Handle:conn)
{
    if (conn != INVALID_HANDLE)
    {
        CloseHandle(conn);
        conn = INVALID_HANDLE;
    }
}

public EmptyMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    // pass
}

stock CompileCommonRegexes()
{
    new flags = PCRE_CASELESS;
    g_hPatternSteam = CompileRegex(REGEX_STEAMID, flags);
}

stock CacheModelsAndSounds()
{
    // Pre-cache materials, models, and sprites.
    if (g_iGame == GAMETYPE_CSS)
    {
        g_iSpriteBeam = PrecacheModel("materials/sprites/laser.vmt");
        g_iSpriteRing = PrecacheModel("materials/sprites/halo01.vmt");
        g_iSpriteLightning = PrecacheModel("materials/sprites/lgtning.vmt");
        g_iSpriteExplosion = PrecacheModel("materials/sprites/blueglow2.vmt");
        g_iSpriteSmoke = PrecacheModel("materials/sprites/steam1.vmt");
    }

    else
    {
        g_iSpriteBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
        g_iSpriteRing = PrecacheModel("materials/sprites/glow01.vmt");
        g_iSpriteLightning = PrecacheModel("materials/sprites/laserbeam.vmt");
        g_iSpriteExplosion = PrecacheModel("materials/sprites/blueglow2.vmt");
        g_iSpriteSmoke = PrecacheModel("materials/sprites/smoke.vmt");
    }

    PrecacheModel("models/extras/muted/muted.mdl");
    PrecacheModel("models/props_lab/blastdoor001c.mdl");

    AddFileToDownloadsTable("models/extras/muted/muted.dx80.vtx");
    AddFileToDownloadsTable("models/extras/muted/muted.dx90.vtx");
    AddFileToDownloadsTable("models/extras/muted/muted.mdl");
    AddFileToDownloadsTable("models/extras/muted/muted.sw.vtx");
    AddFileToDownloadsTable("models/extras/muted/muted.vvd");
    AddFileToDownloadsTable("materials/models/extras/muted/speech_info.vmt");
    AddFileToDownloadsTable("materials/models/extras/muted/speech_info.vtf");

    // Pre-cache sounds.
    if (g_iGame == GAMETYPE_CSGO && StrContains(g_sSoundDeny, "music/") == -1)
    {
        Format(g_sSoundDeny, sizeof(g_sSoundDeny), "music/%s", g_sSoundDeny);
        Format(g_sSoundBlip, sizeof(g_sSoundBlip), "music/%s", g_sSoundBlip);
        Format(g_sSoundAlarm, sizeof(g_sSoundAlarm), "music/%s", g_sSoundAlarm);
        Format(g_sSoundExplode, sizeof(g_sSoundExplode), "music/%s", g_sSoundExplode);
        Format(g_sSoundThunder, sizeof(g_sSoundThunder), "music/%s", g_sSoundThunder);
        Format(g_sSoundJihad, sizeof(g_sSoundJihad), "music/%s", g_sSoundJihad);
        Format(g_sSoundPowerup, sizeof(g_sSoundPowerup), "music/%s", g_sSoundPowerup);
        Format(g_sSoundFail, sizeof(g_sSoundFail), "music/%s", g_sSoundFail);
        Format(g_sSoundHaha, sizeof(g_sSoundHaha), "music/%s", g_sSoundHaha);
    }
    PrecacheSound(g_sSoundDeny, true);
    PrecacheSound(g_sSoundBlip, true);
    PrecacheSound(g_sSoundAlarm, true);
    PrecacheSound(g_sSoundExplode, true);
    PrecacheSound(g_sSoundThunder, true);
    PrecacheSound(g_sSoundJihad, true);
    PrecacheSound(g_sSoundPowerup, true);
    PrecacheSound(g_sSoundFail, true);
    PrecacheSound(g_sSoundHaha, true);
    decl String:sFullSoundPath[72];
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundDeny);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundBlip);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundAlarm);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundExplode);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundThunder);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundJihad);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundPowerup);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundFail);
    AddFileToDownloadsTable(sFullSoundPath);
    Format(sFullSoundPath, sizeof(sFullSoundPath), "sound/%s", g_sSoundHaha);
    AddFileToDownloadsTable(sFullSoundPath);
}

stock PopulateWeaponsAndItems()
{
    if (g_hWepsAndItems != INVALID_HANDLE)
        return;
    g_hWepsAndItems = CreateTrie();

    // The value is which slot it goes in.
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */

    /* ----- CSGO Specific ----- */

    // Rifles
    SetTrieValue(g_hWepsAndItems, "galilar", 0);
    SetTrieValue(g_hWepsAndItems, "scar20", 0);
    SetTrieValue(g_hWepsAndItems, "sg556", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sg556", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_scar20", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_galilar", 0);

    // Snipers
    SetTrieValue(g_hWepsAndItems, "ssg08", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_ssg08", 0);

    // SMGs
    SetTrieValue(g_hWepsAndItems, "bizon", 0);
    SetTrieValue(g_hWepsAndItems, "mp7", 0);
    SetTrieValue(g_hWepsAndItems, "mp9", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mp9", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mp7", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_bizon", 0);

    // Shotguns Guns
    SetTrieValue(g_hWepsAndItems, "mag7", 0);
    SetTrieValue(g_hWepsAndItems, "nova", 0);
    SetTrieValue(g_hWepsAndItems, "sawedoff", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sawedoff", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_nova", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mag7", 0);

    // Machine Guns
    SetTrieValue(g_hWepsAndItems, "negev", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_negev", 0);

    // Pistols
    SetTrieValue(g_hWepsAndItems, "hkp2000", 1);
    SetTrieValue(g_hWepsAndItems, "p250", 1);
    SetTrieValue(g_hWepsAndItems, "taser", 1);
    SetTrieValue(g_hWepsAndItems, "tec9", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_tec9", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_taser", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_p250", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_hkp2000", 1);

    // Grenades
    SetTrieValue(g_hWepsAndItems, "decoy", 3);
    SetTrieValue(g_hWepsAndItems, "incgrenade", 3);
    SetTrieValue(g_hWepsAndItems, "molotov", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_molotov", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_incgrenade", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_decoy", 3);

    /* ----- End CSGO Specific ----- */

    // Shotguns.
    SetTrieValue(g_hWepsAndItems, "m3", 0);
    SetTrieValue(g_hWepsAndItems, "xm1014", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m3", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_xm1014", 0);

    // Submachine guns.
    SetTrieValue(g_hWepsAndItems, "mac10", 0);
    SetTrieValue(g_hWepsAndItems, "tmp", 0);
    SetTrieValue(g_hWepsAndItems, "mp5navy", 0);
    SetTrieValue(g_hWepsAndItems, "ump45", 0);
    SetTrieValue(g_hWepsAndItems, "p90", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mac10", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_tmp", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_mp5navy", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_ump45", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_p90", 0);

    // Rifles.
    SetTrieValue(g_hWepsAndItems, "galil", 0);
    SetTrieValue(g_hWepsAndItems, "ak47", 0);
    SetTrieValue(g_hWepsAndItems, "scout", 0);
    SetTrieValue(g_hWepsAndItems, "sg552", 0);
    SetTrieValue(g_hWepsAndItems, "awp", 0);
    SetTrieValue(g_hWepsAndItems, "g3sg1", 0);
    SetTrieValue(g_hWepsAndItems, "famas", 0);
    SetTrieValue(g_hWepsAndItems, "m4a1", 0);
    SetTrieValue(g_hWepsAndItems, "aug", 0);
    SetTrieValue(g_hWepsAndItems, "sg550", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_galil", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_ak47", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_scout", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sg552", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_awp", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_g3sg1", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_famas", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m4a1", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_aug", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_sg550", 0);

    // Machine guns.
    SetTrieValue(g_hWepsAndItems, "m249", 0);
    SetTrieValue(g_hWepsAndItems, "weapon_m249", 0);

    // Pistols.
    SetTrieValue(g_hWepsAndItems, "glock", 1);
    SetTrieValue(g_hWepsAndItems, "usp", 1);
    SetTrieValue(g_hWepsAndItems, "p228", 1);
    SetTrieValue(g_hWepsAndItems, "deagle", 1);
    SetTrieValue(g_hWepsAndItems, "elite", 1);
    SetTrieValue(g_hWepsAndItems, "fiveseven", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_glock", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_usp", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_p228", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_deagle", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_elite", 1);
    SetTrieValue(g_hWepsAndItems, "weapon_fiveseven", 1);

    // Knife.
    SetTrieValue(g_hWepsAndItems, "knife", 2);
    SetTrieValue(g_hWepsAndItems, "weapon_knife", 2);

    // Nades.
    SetTrieValue(g_hWepsAndItems, "flashbang", 3);
    SetTrieValue(g_hWepsAndItems, "hegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "smokegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_flashbang", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_hegrenade", 3);
    SetTrieValue(g_hWepsAndItems, "weapon_smokegrenade", 3);

    // Bomb.
    SetTrieValue(g_hWepsAndItems, "c4", 4);
    SetTrieValue(g_hWepsAndItems, "weapon_c4", 4);

    // Items.
    SetTrieValue(g_hWepsAndItems, "vest", 5);
    SetTrieValue(g_hWepsAndItems, "vesthelm", 5);
    SetTrieValue(g_hWepsAndItems, "defuser", 5);
    SetTrieValue(g_hWepsAndItems, "nvgs", 5);
    SetTrieValue(g_hWepsAndItems, "item_vest", 5);
    SetTrieValue(g_hWepsAndItems, "item_vesthelm", 5);
    SetTrieValue(g_hWepsAndItems, "item_defuser", 5);
    SetTrieValue(g_hWepsAndItems, "item_nvgs", 5);
}

stock DisplayCountdown(count=3, client=0, bool:freezeAndUnfreeze=false, const String:startMsg[64]="", const String:endMsg[64]="")
{
    // Show a start message?
    new bool:showStartMsg = (!StrEqual(startMsg, ""));
    if (showStartMsg)
    {
        if (client == 0)
            PrintCenterTextAll(startMsg);
        else
        {
            if (IsClientInGame(client))
                PrintCenterText(client, startMsg);
        }
    }

    // Freeze players?
    if (freezeAndUnfreeze)
    {
        if (client == 0)
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                    SetEntityMoveType(i, MOVETYPE_NONE);
            }
        }
        else
        {
            if (IsClientInGame(client) && IsPlayerAlive(client))
                SetEntityMoveType(client, MOVETYPE_NONE);
        }
    }

    // Pack up data to send into callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, count);
    WritePackCell(data, client);
    WritePackCell(data, _:freezeAndUnfreeze);
    WritePackString(data, endMsg);
    CreateTimer((showStartMsg ? 3.0 : 1.0), Timer_DisplayCountdown, any:data);  // The varying time here just allows the
                                                                                // start message enought time to be read
                                                                                // (if there is a start message) before
                                                                                // it starts displaying the countdown
                                                                                // text.
}

public Action:Timer_DisplayCountdown(Handle:timer, any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new count = ReadPackCell(Handle:data);
    new client = ReadPackCell(Handle:data);
    new bool:freezeAndUnfreeze = bool:ReadPackCell(Handle:data);
    decl String:endMsg[64];
    ReadPackString(Handle:data, endMsg, sizeof(endMsg));
    CloseHandle(Handle:data);

    // Is this the last tick of this countdown?
    if (count <= 0)
    {
        // Unfreeze players?
        if (freezeAndUnfreeze)
        {
            if (client == 0)
            {
                for (new i = 1; i <= MaxClients; i++)
                {
                    if (IsClientInGame(i) && IsPlayerAlive(i))
                        SetEntityMoveType(i, MOVETYPE_WALK);
                }
            }
            else
            {
                if (IsClientInGame(client) && IsPlayerAlive(client))
                    SetEntityMoveType(client, MOVETYPE_WALK);
            }
        }

        // Display end message to players?
        if (!StrEqual(endMsg, ""))
        {
            if (client == 0)
                PrintCenterTextAll(endMsg);
            else
            {
                if (IsClientInGame(client))
                    PrintCenterText(client, endMsg);
            }
        }
    }
    else /* This is NOT the last tick */
    {
        // Display countdown to player(s).
        if (client == 0)
            PrintCenterTextAll("---%i---", count);
        else
        {
            if (IsClientInGame(client))
                PrintCenterText(client, "---%i---", count);
        }

        // Pack up data to send into callback.
        new Handle:nextData = CreateDataPack();
        WritePackCell(nextData, (--count));
        WritePackCell(nextData, client);
        WritePackCell(nextData, _:freezeAndUnfreeze);
        WritePackString(nextData, endMsg);
        CreateTimer(1.0, Timer_DisplayCountdown, any:nextData);
    }

    return Plugin_Continue;
}
























