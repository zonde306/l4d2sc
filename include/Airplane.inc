#if defined _airdrop_included
  #endinput
#endif
#define _airdrop_included

/**
 * @brief Creates an Airdrop at the location and from the direction specified.
 *
 * @param		client   Client.
 * @param		vPos1    Position 1.
 * @param		vPos2    Position 2.
 * @param		vPos3    Position 3.
 * @return		none.
 */
native void Airdrop(int client = 0, float vPos[3]);