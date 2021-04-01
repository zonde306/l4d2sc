
native float SMPlus_GetHealthBonus();

native float SMPlus_GetDamageBonus();

native float SMPlus_GetPillsBonus();

native float SMPlus_GetMaxHealthBonus();

native float SMPlus_GetMaxDamageBonus();

native float SMPlus_GetMaxPillsBonus();

public SharedPlugin __pl_l4d2_hybrid_scoremod =
{
        name = "l4d2_hybrid_scoremod",
        file = "l4d2_hybrid_scoremod.smx",
#if defined REQUIRE_PLUGIN
        required = 1,
#else
        required = 0,
#endif
};

public void __pl_l4d2_hybrid_scoremod_SetNTVOptional()
{
    MarkNativeAsOptional("SMPlus_GetHealthBonus");
    MarkNativeAsOptional("SMPlus_GetDamageBonus");
    MarkNativeAsOptional("SMPlus_GetPillsBonus");
    MarkNativeAsOptional("SMPlus_GetMaxHealthBonus");
    MarkNativeAsOptional("SMPlus_GetMaxDamageBonus");
    MarkNativeAsOptional("SMPlus_GetMaxPillsBonus");
}

