
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Player targeting types.
#define TARGET_TYPE_MAGICWORD 0
#define TARGET_TYPE_USERID 1
#define TARGET_TYPE_STEAM 2
#define TARGET_TYPE_NAME 3

// ####################################################################################
// ################################# MAIN FUNCTION ####################################
// ####################################################################################

bool:TryGetArgs(const String:argString[], argStringMaxLen, String:target[], targetMaxLen, &targetType, &duration, String:reason[], reasonMaxLen)
{
    /*
        Returns TRUE if success getting a target.  Otherwise FALSE.
        If no duration could be found, it will be -1.
        If no reason could be found, it will be an empty string.
    */

    /************************ Prepare return values **********************/

    target[0] = '\0';
    duration = -1;
    reason[0] = '\0';

    /*********************** Validate function call **********************/

    if (argStringMaxLen < targetMaxLen + reasonMaxLen)
    {
        LogMessage("Programming error: targetMaxLen + reasonMaxLen together are larger than argStringMaxLen");
        return false;
    }

    /**************************** Find target ****************************/

    // Length of first argument.
    new targetLen;

    // Get first char.
    new firstChr = argString[0];
    if (firstChr == '\0')
        return false;

    // Check if first char is '@'.
    else if (firstChr == '@')
    {
        // Looks like a MAGIC WORD.
        targetLen = GetMagicWord(argString, argStringMaxLen, target, targetMaxLen);
        if (targetLen > 0)
            targetType = TARGET_TYPE_MAGICWORD;
        else
        {
            // It could still be a partial name.
            targetLen = GetPartialName(argString, argStringMaxLen, target, targetMaxLen);
            if (targetLen > 0)
                targetType = TARGET_TYPE_NAME;
            else
                return false;
        }
    }

    // Check if first char is a number.
    else if (firstChr == '#' || IsCharNumeric(firstChr))
    {
        // Looks like a USER ID.
        targetLen = GetUserId(argString, argStringMaxLen, target, targetMaxLen);
        if (targetLen > 0)
            targetType = TARGET_TYPE_USERID;
        else
        {
            // It could still be a PARTIAL NAME.
            targetLen = GetPartialName(argString, argStringMaxLen, target, targetMaxLen);
            if (targetLen > 0)
                targetType = TARGET_TYPE_NAME;
            else
                return false;
        }
    }

    // Do a QUICK check on the arg string to see if starts with a Steam ID.
    else if (argStringMaxLen >= 11 && (strncmp(argString, "STEAM_", 6, false) == 0) && (argString[7] == ':') && (argString[9] == ':'))
    {
        // Looks like a STEAM ID.
        targetLen = GetSteam(argString, argStringMaxLen, target, targetMaxLen);
        if (targetLen > 0)
            targetType = TARGET_TYPE_STEAM;
        else
            return false;
    }

    // Check if first char a quote.
    else if (firstChr == '"')
    {
        // Looks like an QUOTED NAME.
        targetLen = GetQuotedName(argString, argStringMaxLen, target, targetMaxLen);
        if (targetLen > 0)
            targetType = TARGET_TYPE_NAME;
        else
        {
            // It could still be a PARTIAL NAME.
            targetLen = GetPartialName(argString, argStringMaxLen, target, targetMaxLen);
            if (targetLen > 0)
                targetType = TARGET_TYPE_NAME;
            else
                return false;
        }
    }

    // The target is probably a PARTIAL NAME.
    else
    {
        // Looks like a PARTIAL NAME.
        targetLen = GetPartialName(argString, argStringMaxLen, target, targetMaxLen);
        if (targetLen > 0)
            targetType = TARGET_TYPE_NAME;
        else
            return false;
    }


    /**
     *
     *
     If we have to return from this point on, at least we found a target, so return TRUE.
     *
     *
    **/


    /*************************** Find duration ***************************/
    // Is there more room in the argString to look-ahead for the duration?
    if (argStringMaxLen < (targetLen + 3)) // 3 is completely arbirtrary.  Just need enough room to have a duration, which could be like 9 or 99 or 999 or 9999.
        return true;

    // Does it look like there is more data in the argString after the target?
    if (argString[targetLen] != ' ')
        return true;

    // Try to find duration.
    new durStartPos = targetLen + 1;
    new durLen = GetDuration(argString, argStringMaxLen, duration, durStartPos);
    if (durLen <= 0)
        return true;

    /**************************** Find reason ****************************/

    // Is there more room in the argString to look-ahead for the reason?
    if (argStringMaxLen < (durStartPos + durLen + 3)) // 3 is completely arbitrary.  Just need enough room to have a reason.
        return true;

    // Does it look like there is more data in the argString after the duration?
    if (argString[durStartPos + durLen] != ' ')
        return true;

    // Try to find reason.
    new reasonStartPos = durStartPos + durLen + 1;
    GetReason(argString, argStringMaxLen, reason, reasonMaxLen, reasonStartPos);
    return true;
}

// ####################################################################################
// ############################ INTERNAL HELPER FUNCTIONS #############################
// ####################################################################################

GetMagicWord(const String:argString[], argStringMaxLen, String:target[], targetMaxLen)
{
    /*
        Try to find end position of MAGIC WORD by looking for either:
            * A space.
            * End of string.

        The MAGIC WORD (NOT including '@') will be in target.

        Returns an integer -- the end position of the MAGIC WORD within argString (so we know where the next arg starts).

        If characters other than a-z are encountered, we consider it not a valid MAGIC WORD so -1 will be returned.
    */

    new chr, targetLen;
    for (new i = 1; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0' || chr == ' ')
            break;
        else if (chr < 97 || chr > 122)
            return -1;
        targetLen++;
    }

    // Copy target to output buffer.
    if (targetLen > 0)
    {
        CopyStringFrom(target, targetMaxLen, argString, argStringMaxLen, 1, targetLen);
        return targetLen + 1; // (+1 for @)
    }
    else
        return -1;
}

GetUserId(const String:argString[], argStringMaxLen, String:target[], targetMaxLen)
{
    /*
        Try to find end of USER ID by looking for either:
            * A space.
            * End of string.

        The USER ID will be in target.

        Returns an integer -- the end position of the USER ID within argString (so we know where the next arg starts).

        If a non-numeric character is encountered, we consider it not a valid USER ID so -1 will be returned.
    */

    new bool:startsWithHash = (argString[0] == '#');
    new chr, targetLen;
    for (new i = (startsWithHash ? 1 : 0); i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0' || chr == ' ')
            break;
        else if (!IsCharNumeric(chr))
            return -1;
        targetLen++;
    }

    // We don't need to check that the length is greater than zero because we already know it is at least one.
    // Otherwise this function would not have been called.

    // Copy target to output buffer.
    CopyStringFrom(target, targetMaxLen, argString, argStringMaxLen, (startsWithHash ? 1 : 0), targetLen);
    return (startsWithHash ? targetLen + 1 : targetLen);
}

GetSteam(const String:argString[], argStringMaxLen, String:target[], targetMaxLen)
{
    /*
        Try to find end of STEAM ID by looking for either:
            * A space.
            * End of string.

        The STEAM ID will be in target.

        Returns an integer -- the end position of the STEAM ID within argString (so we know where the next arg starts).

        If it is a non-valid STEAM ID, -1 will be returned.
    */

    new chr, targetLen;
    for (new i = 0; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0' || chr == ' ')
            break;
        targetLen++;
    }

    // Copy target to output buffer.
    CopyStringFrom(target, targetMaxLen, argString, argStringMaxLen, 0, targetLen);

    // Perform a RegEx evaluation to be sure if it's a valid Steam ID.
    if (MatchRegex(g_hPatternSteam, target) > 0)
    {
        // The Steam ID is valid, but ensure it's uppercase.
        for (new i = 0; i <= 6; i++)
            target[i] = CharToUpper(target[i]);
        return targetLen;
    }
    else
        return -1;
}

GetQuotedName(const String:argString[], argStringMaxLen, String:target[], targetMaxLen)
{
    /*
        Try to find end position of QUOTED NAME by looking for:
            * End quote.

        The QUOTED NAME (NOT including quotes) will be in target.

        Returns an integer -- the end position of the QUOTED NAME (including quotes) within argString (so we know where the next arg starts).

        If there is no matching end quote, we consider it not a valid QUOTED NAME so -1 will be returned.
    */

    new endQuoteFound = false;
    new chr, targetLen;
    for (new i = 1; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0')
            break;
        if (chr == '"')
        {
            endQuoteFound = true;
            break;
        }
        targetLen++;
    }

    // Copy target to output buffer.
    if (endQuoteFound && targetLen > 0)
    {
        CopyStringFrom(target, targetMaxLen, argString, argStringMaxLen, 1, targetLen);
        return targetLen + 2; // +2 for two quotes)
    }
    else
        return -1;
}

GetPartialName(const String:argString[], argStringMaxLen, String:target[], targetMaxLen)
{
    /*
        Try to find end position of PARTIAL NAME by making looking for:
            * A space.
            * End of string.

        The PARTIAL NAME will be in target.

        Returns an integer -- the end position of the PARTIAL NAME within argString (so we know where the next arg starts).
    */

    new chr, targetLen;
    for (new i = 0; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0' || chr == ' ')
            break;
        targetLen++;
    }

    // Copy target to output buffer.
    if (targetLen > 0)
    {
        CopyStringFrom(target, targetMaxLen, argString, argStringMaxLen, 0, targetLen);
        return targetLen;
    }
    else
        return -1;
}

GetDuration(const String:argString[], argStringMaxLen, &duration, durStartPos)
{
    /*
        Try to find end of DURATION by looking for either:
            * A space.
            * A period (in case they used a float).
            * End of string.

        The DURATION will be in duration.

        It also accepts one period for floats.

        Returns an integer -- the end position of the DURATION within argString (so we know where the next arg starts).

        If a non-numeric character is encountered, we consider it not a valid DURATION so -1 will be returned.
    */

    new bool:periodFound;
    new chr, durLen;
    for (new i = durStartPos; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '.')
        {
            periodFound = true;
            break;
        }
        if (chr == '\0' || chr == ' ')
            break;
        else if (!IsCharNumeric(chr))
            return -1;
        durLen++;
    }

    // If period was found, keep reading until space or end of string.
    new additionalLen;
    if (periodFound)
    {
        for (new i = durStartPos + durLen; i < argStringMaxLen; i++)
        {
            chr = argString[i];
            if (chr == '\0' || chr == ' ')
                break;
            additionalLen++;
        }
    }

    // Place duration in output buffer.
    if (durLen > 0)
    {
        decl String:numBuff[LEN_INTSTRING];
        new copied = CopyStringFrom(numBuff, sizeof(numBuff), argString, argStringMaxLen, durStartPos, durLen);
        if (copied > 0)
        {
            new dur = StringToInt(numBuff);
            if (dur < 0) dur = -1;
            if (dur > 99999) dur = 99999;
            duration = dur;
            return durLen + additionalLen;
        }
        else
            return -1;
    }
    else
        return -1;
}

GetReason(const String:argString[], argStringMaxLen, String:reason[], reasonMaxLen, reasonStartPos)
{
    /*
        Try to find end of REASON by looking for:
            * End of string.

        The REASON will be in reason.

        Returns an integer -- the end position of the REASON within argString (so we know where the next arg starts).
    */

    new chr, reasonLen;
    for (new i = reasonStartPos; i < argStringMaxLen; i++)
    {
        chr = argString[i];
        if (chr == '\0')
            break;
        reasonLen++;
    }

    // Place reason in output buffer.
    if (reasonLen > 0)
    {
        CopyStringFrom(reason, reasonMaxLen, argString, argStringMaxLen, reasonStartPos, reasonLen);
        StripQuotes(reason);
        return reasonLen;
    }
    else
        return -1;
}
