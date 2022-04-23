
CopyStringFrom(String:buffer[], bufferLen, const String:source[], sourceLen, startIndex, numCharsToCopy=0)
{
    if(startIndex < 0) startIndex = 0;
    if(startIndex > sourceLen) return 0;
    if(numCharsToCopy <= 0) numCharsToCopy = bufferLen;

    // Ensure we don't try to write more chars than will fit in the buffer.
    if(numCharsToCopy > bufferLen) numCharsToCopy = bufferLen;

    // Ensure we don't try to read more chars than the source has.
    new sourceCharsAvail = sourceLen - startIndex;
    if(startIndex + numCharsToCopy > sourceCharsAvail)
        numCharsToCopy = sourceCharsAvail;

    // Copy from start index.
    new numCopied, chr;
    for(new i = 0; i < numCharsToCopy; i++)
    {
        chr = source[startIndex + i];
        buffer[i] = chr;
        numCopied++;
        if(chr == '\0')
            break;
    }

    // Ensure last char is null terminator.
    buffer[numCopied] = '\0';

    // Return how many chars were copied.
    return numCopied;
}

GetClientOfSteam(const String:steam[])
{
    /*
        Returns client or -1 if no client in server matched the supplied Steam ID.
    */

    decl String:this_steam[LEN_STEAMIDS];
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientAuthorized(i))
        {
            GetClientAuthString(i, this_steam, sizeof(this_steam));
            if(strcmp(this_steam, steam, false) == 0)
            {
                // Matching client was found.
                return i;
            }
        }
    }
    return -1; // <--- client
}

GetClientOfPartialName(const String:name[], targets[MAXPLAYERS + 1], &numFound)
{
    // Let's see if it's a partial match for someone currently in the server.
    decl String:this_name[MAX_NAME_LENGTH];
    for(new i = 1; i <= MaxClients; i++)
    {
        //is player still in game?
        if(IsClientInGame(i))
        {
            GetClientName(i, this_name, sizeof(this_name));
            if(StrContains(this_name, name, false) >= 0)
                targets[numFound++] = i;
        }
    }
}

NetAddr2Long(const String:ip[])
{
    decl String:pieces[4][16];
    new nums[4];

    if(ExplodeString(ip, ".", pieces, 4, 16) != 4)
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
    if(client && IsClientInGame(client))
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

    if(withDashes)
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

stock GetApprovedState(adminClient)
{
    // Should the ban start off as "approved"? (trusted+ only)
    new approvedState = APPROVED_STATE_SERVERBAN;
    if(!adminClient)
        approvedState = APPROVED_STATE_APPROVED;
    else
    {
        if(IsClientInGame(adminClient))
        {
            new adminFlags = GetUserFlagBits(adminClient);
            if((adminFlags & ADMFLAG_CHANGEMAP) || (adminFlags & ADMFLAG_ROOT))
                approvedState = APPROVED_STATE_APPROVED;
        }
        else // The admin banned himself. He's not in-game. Can't get his flags.
            approvedState = APPROVED_STATE_SERVERBAN;
    }
    return approvedState;
}

stock GetActualDuration(durationMins, adminClient)
{
    // If duration is not specified, set it to default.
    new defaultMins = g_iDefaultBan;
    if(durationMins < 0)
        return defaultMins;

    // If the duration is more than the default, the admin must be trusted (or RCON).
    if(durationMins > defaultMins || durationMins <= 0)
    {
        if(adminClient)
        {
            new adminFlags = GetUserFlagBits(adminClient);
            if(!(adminFlags & ADMFLAG_CHANGEMAP) && !(adminFlags & ADMFLAG_ROOT))
            {
                return defaultMins;
            }
        }
    }
    return durationMins;
}

public EmptyMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    // pass
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

    // If It's CS:GO, the 9 key is exit. If it's any other game, the 0 key is exit.
    SetPanelCurrentKey(panel, (g_iGame == GAMETYPE_CSGO ? 9 : 10));
    DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);

    SendPanelToClient(panel, client, EmptyMenuSelect, time);
    CloseHandle(panel);
}

stock DisplayMSayAll(const String:title[], time, const String:format[], any:...)
{
    decl String:message[255];
    VFormat(message, sizeof(message), format, 4);

    for(new i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i) || IsFakeClient(i))
            continue;

        new Handle:panel = CreatePanel();

        SetPanelTitle(panel, title);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER);

        DrawPanelText(panel, message);
        DrawPanelItem(panel, "", ITEMDRAW_SPACER);

        SetPanelCurrentKey(panel, (g_iGame == GAMETYPE_CSGO ? 9 : 10));
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

stock GetPlayerUnsignedIp(client)
{
    // Get admin's IP.
    new unsignedIp = g_iIP;
    if(client)
    {
        if(IsClientInGame(client))
        {
            decl String:adminIpString[LEN_IPSTRING];
            GetClientIP(client, adminIpString, sizeof(adminIpString));
            unsignedIp = NetAddr2Long(adminIpString);
        }
        else // The admin banned himself. He's not in-game. Can't get his IP.
            unsignedIp = 0;
    }
    return unsignedIp;
}
