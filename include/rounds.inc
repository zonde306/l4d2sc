
#if defined __rounds__
#endinput
#endif
#define __rounds__

/* Global Vars */
Handle hFwdRoundStart;
Handle hFwdRoundEnd;

bool bFirstRound = true;
bool bInRound;

void Rounds_OnRoundStart_Update()
{
	if(!bInRound)
	{
		bInRound=true;
		Call_StartForward(hFwdRoundStart);
		Call_Finish();
	}
}

void Rounds_OnRoundEnd_Update()
{
	if(bInRound)
	{
		bInRound=false;
		bFirstRound = false;
		Call_StartForward(hFwdRoundEnd);
		Call_Finish();
	}
}

void Rounds_OnMapStart_Update()
{
	bFirstRound = true;
}

void Rounds_OnMapEnd_Update()
{
	bFirstRound = true;
	bInRound = false;
}

bool IsFirstRound()
{
	return bFirstRound;
}

bool CurrentlyInRound()
{
	return bInRound;
}
