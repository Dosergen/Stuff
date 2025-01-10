#if defined _connecthook_included
 #endinput
#endif
#define _connecthook_included

/**
 * @brief Called very early in the client connect process
 *
 * @param name          Client's name.
 * @param password      Connection password (or the most recently used one).
 * @param ip            Client's IP address.
 * @param steamID       Client's SteamId.  (This is before authentication so it is not guaranteed.)
 * @param rejectReason  Client's connection reject reason. Will be used only if returned action is Plugin_Handled or above.
 */
forward Action OnClientPreConnect(const char[] name, const char[] password, const char[] ip, const char[] steamID, char rejectReason[255]);


/**
 * Do not edit below this line!
 */
public Extension __ext_connecthook =
{
    name = "ConnectHook",
    file = "connecthook.ext",
    autoload = 1,
#if defined REQUIRE_EXTENSIONS
    required = 1,
#else
    required = 0,
#endif
};
