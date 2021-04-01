/*
	This program is free software: you can redistribute it and/or modify it under
	the terms of the GNU General Public License as published by the Free Software
	Foundation, either version 3 of the License, or (at your option) any later
	version.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
	PARTICULAR PURPOSE.  See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with
	this program.  If not, see <http://www.gnu.org/licenses/>.

	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved. 
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved. 
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase. 
	Source is Copyright (C) Valve Corporation. 

	Valve, the Valve logo, Left 4 Dead, Left 4 Dead 2, Steam, and the Steam
	logo are trademarks and/or registered trademarks of Valve Corporation.
	All other trademarks are property of their respective owners.
*/

/**
 * @brief Returns the current round number
 * @remarks Updated on round_start events
 * 
 * @return 	0 for pre first round, round number otherwise
 */
native bool L4D2_IsFirstRound();

/**
 * @brief Tells if we're actually in a round or in between rounds
 * @remarks Updated on first round_start/end
 * 
 * @return 	True if within an actual round, false otherwise.
 */
native bool L4D2_CurrentlyInRound();

/**
 * Called on a real L4D2 round_start
 *
 * @noreturn
 */
forward void L4D2_OnRealRoundStart();

/**
 * Called on a real L4D2 round_end
 *
 * @noreturn
 */
forward void L4D2_OnRealRoundEnd();

/**
 * @brief Returns the number of alive survivors
 * @remarks Includes all living human and bot survivors
 * 
 * @return The number of alive survivors
 */
native int L4D2_GetSurvivorCount();

/**
 * @brief Returns the survivor of a specific index
 * @remarks returns 0 if a survivor doesn't exist at the specified index
 * @params	index	the index to retrieve the client number from
 * 
 * @return Client number of a survivor stored at the given index.
 */
native int L4D2_GetSurvivorOfIndex(int index);

/**
 * @Called when a tank is first spawned into the game
 * 
 * @param tankClient		The client index of the tank
 * @noreturn
 */
forward void L4D2_OnTankFirstSpawn(int tankClient);

/**
 * @Called when a tank passes from one client to another
 * 
 * @param oldTank			The client index of the previous tank
 * @param newTank			The client index of the new tank
 * @param passCount			The number of times this tank has been passed
 * @noreturn
 */
forward void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount);

/**
 * @Called 0.5s after a tank death
 * 
 * @param tankClient		The client index of the tank that died
 * @noreturn
 */
forward void L4D2_OnTankDeath(int tankClient, int attacker);

/**
 * @brief Get an Int value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0)
 * @return			Integer value for given key, or defvalue if key is not found
 */
native int L4D2_GetMapValueInt(const char[] key, const int defvalue = 0);

/**
 * @brief Get a Float value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0.0)
 * @return			Float value for given key, or defvalue if key is not found
 */
native float L4D2_GetMapValueFloat(const char[] key, const float defvalue = 0.0);

/**
 * @brief Get a Vector from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param vector	Vector to store the result in
 * @param defvalue	Default value to use if key is not found (default NULL_VECTOR)
 * @noreturn
 */
native void L4D2_GetMapValueVector(const char[] key, float vector[3], const float defvalue[3]=NULL_VECTOR);

/**
 * @brief Get a String from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param value		String to store the result in
 * @param maxlength Maximum length to write to the value String buffer
 * @param defvalue	Default value to use if key is not found (default "")
 * @noreturn
 */
native void L4D2_GetMapValueString(const char[] key, char[] value, int maxlength, const char[] defvalue = "");

/**
 * @brief Copy a Subsection from the MapInfo keyvalues for the current map
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param kv		KeyValues Handle to copy to
 * @param section	Name of the section to copy
 * @noreturn
 */
native void L4D2_CopyMapSubsection(Handle kv, const char[] section);

/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool L4D2_IsEntityInSaferoom(int entity);

native bool L4D2_IsEntityInStartSaferoom(int entity);

native bool L4D2_IsEntityInEndSaferoom(int entity);

/*
  Check if player (client) is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool L4D2_IsPlayerInSaferoom(int client);

native bool L4D2_IsPlayerInStartSaferoom(int client);

native bool L4D2_IsPlayerInEndSaferoom(int client);

forward void L4D2_OnPlayerHurtPre(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype, int hitgroup);

forward void L4D2_OnPlayerHurtPost(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype, int hitgroup);

forward void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam);

public SharedPlugin __pl_l4d2lib = 
{
	name = "l4d2lib",
	file = "l4d2lib.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
 
public void __pl_l4d2lib_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_GetCurrentRound");
	MarkNativeAsOptional("L4D2_CurrentlyInRound");
	MarkNativeAsOptional("L4D2_GetSurvivorCount");
	MarkNativeAsOptional("L4D2_GetSurvivorOfIndex");
	MarkNativeAsOptional("L4D2_GetMapValueInt");
	MarkNativeAsOptional("L4D2_GetMapValueFloat");
	MarkNativeAsOptional("L4D2_GetMapValueVector");
	MarkNativeAsOptional("L4D2_GetMapValueString");
	MarkNativeAsOptional("L4D2_CopyMapSubsection");
	MarkNativeAsOptional("L4D2_IsEntityInSaferoom");
	MarkNativeAsOptional("L4D2_IsEntityInStartSaferoom");
	MarkNativeAsOptional("L4D2_IsEntityInEndSaferoom");
	MarkNativeAsOptional("L4D2_IsPlayerInSaferoom");
	MarkNativeAsOptional("L4D2_IsPlayerInStartSaferoom");
	MarkNativeAsOptional("L4D2_IsPlayerInEndSaferoom");
}

