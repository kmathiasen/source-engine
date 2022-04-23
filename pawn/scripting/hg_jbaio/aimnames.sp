#define PLAYER_HALFWIDTH 15.0

stock AimNames_OnPluginStart()
{
    if (g_iGame != GAMETYPE_TF2)
    {
        CreateTimer(0.111, Timer_ShowPlayerNames, _, TIMER_REPEAT);
    }
}

public Action:Timer_ShowPlayerNames(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        // Don't use JB_IsPlayerAlive here
        new bool:alive = IsPlayerAlive(i);

        if (!alive || IsHoldingNonGun(i))
        {
            new ghost = -1;
            new target = -1;
            decl Float:eyePos[3];
            decl Float:eyeAngConst[3];

            GetClientEyePosition(i, eyePos);
            GetClientEyeAngles(i, eyeAngConst);

            // If they're not alive, find the ghost they're looking at
            if (!alive)
            {
                decl Float:eyeAng[3];
                eyeAng[0] = eyeAngConst[0] + 180.0;
                eyeAng[1] = eyeAngConst[1] + 180.0;
                eyeAng[2] = eyeAngConst[2];

                for (new j = 1; j <= MaxClients; j++)
                {
                    if (i == j || !g_bIsGhost[j] || !IsClientInGame(j))
                        continue;

                    decl Float:tEyePos[3];
                    GetClientEyePosition(j, tEyePos);

                    new Float:yTheta = float(RoundToNearest(RadToDeg(ArcTangent2(-(tEyePos[0] - eyePos[0]), (tEyePos[1] - eyePos[1]))) + 270.0) % 360);
                    new Float:yThetaTolerance = FloatAbs(RadToDeg(ArcTangent(PLAYER_HALFWIDTH / SquareRoot(Pow(tEyePos[0] - eyePos[0], 2.0) + Pow(tEyePos[1] - eyePos[1], 2.0)))));

                    // It's a hit on the Y Axis...
                    if (FloatAbs(eyeAng[1] - yTheta) <= yThetaTolerance ||
                        FloatAbs(eyeAng[1] - yTheta) >= 360.0 - yThetaTolerance)
                    {
                        decl Float:tFeetPos[3];
                        GetClientAbsOrigin(j, tFeetPos);

                        new Float:xThetaFeet = float(RoundToNearest(RadToDeg(ArcTangent2((SquareRoot(Pow(tFeetPos[1] - eyePos[1], 2.0) + Pow(tFeetPos[0] - eyePos[0], 2.0))), (tFeetPos[2] - eyePos[2]))) + 450.0) % 360);
                        new Float:xThetaEye = float(RoundToNearest(RadToDeg(ArcTangent2((SquareRoot(Pow(tEyePos[1] - eyePos[1], 2.0) + Pow(tEyePos[0] - eyePos[0], 2.0))), (tEyePos[2] - eyePos[2]))) + 450.0) % 360);
                        new Float:xThetaTolerance = FloatAbs(xThetaEye - xThetaFeet);

                        if (xThetaFeet - eyeAng[0] <= xThetaTolerance &&
                            eyeAng[0] - xThetaEye <= xThetaTolerance)
                        {
                            ghost = j;
                            break;
                        }
                    }
                }
            }

            if (g_iGame == GAMETYPE_CSS)
            {
                if (ghost > 0)
                {
                    PrintHintText(i, "Ghost Target: %N", ghost);
                }
            }
    
            else
            {
                TR_TraceRayFilter(eyePos, eyeAngConst, MASK_ALL, RayType_Infinite, Trace_NoSelf, i);

                if (TR_DidHit())
                {
                    target = TR_GetEntityIndex();

                    if (target <= 0 || target > MaxClients)
                    {
                        target = -1;
                    }
                }

                if (target > 0 && ghost > 0)
                {
                    KeyHintText(i, "Alive Target: %N\nGhost Target: %N", target, ghost);
                }

                else if (ghost > 0)
                {
                    KeyHintText(i, "Ghost Target: %N", ghost);
                }

                else if (target > 0)
                {
                    KeyHintText(i, "Alive Target: %N", target);
                }
            }
        }
    }
}

public bool:Trace_NoSelf(entity, contentsMask, any:client)
{
    if (entity == client)
        return false;

    if (entity <= MaxClients && g_bIsGhost[entity])
        return false;

    return true;
}
