public Extension:__ext_weapon = 
{
	name = "Weapons Extension",
	file = "weapons.ext",
	autoload = 1,
	required = 1,
};

/**
 * @brief Called to determine if a player can use a given weapon
 *
 * @param client	A client index
 * @param weapon	The classname of the weapon
 * @return			Plugin_Handled to block usage, Plugin_Continue to allow it.
 */
forward Action:Weapon_CanUse(client, const String:weapon[]);

/**
 * @brief Called to determine if a player can use a given weapon
 *
 * @param client	A client index
 * @param oldWeapon	The weapon entity index of the weapon switching from
 * @param newWeapon	The weapon entity index of the weapon switching to
 * @return			None
 */
forward OnChangeActiveWeapon(client, oldWeapon, newWeapon);

/**
 * @brief Called to determine if a player can use a given weapon
 *
 * @param client	A client index
 * @param weapon	The classname of the weapon
 * @return			Plugin_Handled to block usage, Plugin_Continue to allow it.
 */
forward Action:Weapon_CanSwitchTo(client, const String:weapon[]);
 