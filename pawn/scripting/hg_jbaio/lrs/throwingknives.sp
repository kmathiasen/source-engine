
/* ----- Events ----- */


public TK_OnLRStart(t, ct, const String:arg[])
{
    StripWeps(t, true);
    StripWeps(ct, true);

    TeleportToS4S(t, ct);

    SetClientThrowingKnives(t, 999);
    SetClientThrowingKnives(ct, 999);
}

public TK_OnLREnd(t, ct)
{
    SetClientThrowingKnives(t, 0);
    SetClientThrowingKnives(ct, 0);
}

