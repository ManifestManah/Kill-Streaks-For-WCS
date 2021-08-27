// List of Includes
#include <sourcemod>
#include <clientprefs>
#include <multicolors>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Kill Streak Experience",
	author		= "Manifest @Road To Glory",
	description	= "Players on kill streaks gains bonus experience.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


// Config Convars
Handle cvar_RequiredKillsForStreak;
Handle cvar_KillStreakBaseExperience;
Handle cvar_KillStreakBonusExperience;
Handle cvar_KillStreakMaximumExperience;

// Integers
int KillStreak[MAXPLAYERS + 1] = {1};

// Cookie Variables
bool option_killstreak_announcemessage[MAXPLAYERS + 1] = {true,...};
Handle cookie_killstreak_announcemessage = INVALID_HANDLE;


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Hooks the events that we intend to use in our plugin
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	// Our list of Convars
	cvar_RequiredKillsForStreak = CreateConVar("Mani_MinimumKillsForKillStreak", "3", "The minimum amount of players a player must kill in a row to have an experience bounty put on his head - [Default = 3]");
	cvar_KillStreakBaseExperience = CreateConVar("Mani_KillStreakBaseExperience", "50", "The base amount of experience that a bounty starts at - [Default = 50 | Disable = 0]");
	cvar_KillStreakBonusExperience = CreateConVar("Mani_KillStreakBonusExperience", "10", "The amount of bonus experience to add to the bounty for each additional kill that surpasses the Mani_MinimumKillsForKillStreak amount - [Default = 10 | Disable = 0]");
	cvar_KillStreakMaximumExperience = CreateConVar("Mani_KillStreakMaximumExperience", "125", "The maximum amount of experience a bounty can ever reach, a bounty cannot exceed this value - [Default = 125 | Disable = 0] ");

	// Cookie Stuff
	cookie_killstreak_announcemessage = RegClientCookie("Kill Streak Messages On/Off 1", "killst1337", CookieAccess_Private);
	SetCookieMenuItem(CookieMenuHandler_killstreak_announcemessage, cookie_killstreak_announcemessage, "Kill Streak Messages");

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_WCS_KillStreaks");

	// Loads the multi-language translation file
	LoadTranslations("custom_WCS_KillStreaks.phrases");
}


public void OnClientDisconnect(int client)
{
	// Changes the player's kill streak to 0
	KillStreak[client] = 0;
}


// This happens every time a player spawns
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the victim and attacker's userids and store them within the respective variables: client and attacker
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	// If Both the client and the attacker meets our criteria of client validation then execute this section
	if(IsValidClient(client) && IsValidClient(attacker))
	{
		// If the attacker is dead when he kills someone e.g. with a molotov then this should not count towards his streak
		if(IsPlayerAlive(attacker))
		{
			// Adds a kill to the killstreak of the player that killed the opponent
			KillStreak[attacker] += 1;
			
			// Obtains the value of our attackers kill streak and store the value inside of KillStreakAttackerCheck
			int KillStreakAttackerCheck = KillStreak[attacker];

			// Creates an integer variable matching our cvar_RequiredKillsForStreak convar's value
			int MinimumKillsForKillStreak = GetConVarInt(cvar_RequiredKillsForStreak);

			// If the attacker has killed more than 3 people in a row without dying or the map changing then execute this section
			if(KillStreakAttackerCheck >= MinimumKillsForKillStreak)
			{
				// Creates an integer variable matching our cvar_KillStreakBaseExperience convar's value
				int KillStreakBaseExperience = GetConVarInt(cvar_KillStreakBaseExperience);

				// Creates an integer variable matching our cvar_KillStreakBonusExperience convar's value
				int KillStreakBonusExperience = GetConVarInt(cvar_KillStreakBonusExperience);

				// Creates an integer variable matching our cvar_KillStreakMaximumExperience convar's value
				int KillStreakMaximumExperience = GetConVarInt(cvar_KillStreakMaximumExperience);

				// Finds out how many additional kills the player has acquired
				int KillDifference = KillStreakAttackerCheck - MinimumKillsForKillStreak;
				
				// Multiplies the bonus experience value by the amount of additional kills beyond the minimum amount of kills
				int KillStreakTotalExperience = KillStreakBaseExperience + (KillStreakBonusExperience * KillDifference);

				// If the maximum amount of experience is not set to 0 then execute this section
				if (KillStreakMaximumExperience != 0)
				{
					// If the total experience bounty exceeds the maximum amount of experience a player's bounty is allowed to become, then execute this section
					if(KillStreakTotalExperience > KillStreakMaximumExperience)
					{
						// Changes the total experience to the maximum experience allowed to be acquired from a bounty
						KillStreakTotalExperience = KillStreakMaximumExperience;
					}
				}

				// We create a variable named attackerid which we need as Source-Python commands uses userid's instead of indexes
				int attackerid = GetEventInt(event, "attacker");

				// Creates a variable named ServerCommandMessage which we'll store our message data within
				char ServerCommandMessage[128];

				// Formats a message and store it within our ServerCommandMessage variable
				FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_givexp %i %i", attackerid, KillStreakTotalExperience);

				// Executes our GiveLevel server command on the player, to award them with levels
				ServerCommand(ServerCommandMessage);

				// If the player is not a bot then execute this section
				if (!IsFakeClient(attacker))
				{
					// If the player has the bounty announcement messages enabled then execute this section
					if (option_killstreak_announcemessage[attacker])
					{
						// Prints a message to the chat announcing the bounty
						CPrintToChat(attacker, "%t", "Killstreak Experience Message", KillStreakTotalExperience);
					}
				}
			}
		}

		// Changes the kill streak of the player that died to 0 
		KillStreak[client] = 0;
	}
}


// We call upon this true and false statement whenever we wish to validate our player
bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


// Cookie stuff below
public void OnClientCookiesCached(int client)
{
	option_killstreak_announcemessage[client] = GetCookiekillstreak_announcemessage(client);
}


bool GetCookiekillstreak_announcemessage(int client)
{
	char buffer[10];

	GetClientCookie(client, cookie_killstreak_announcemessage, buffer, sizeof(buffer));
	
	return !StrEqual(buffer, "Off");
}


public void CookieMenuHandler_killstreak_announcemessage(int client, CookieMenuAction action, any killstreak_announcemessage, char[] buffer, int maxlen)
{	
	if (action == CookieMenuAction_DisplayOption)
	{
		char status[16];
		if (option_killstreak_announcemessage[client])
		{
			Format(status, sizeof(status), "%s", "[ON]", client);
		}
		else
		{
			Format(status, sizeof(status), "%s", "[OFF]", client);
		}
		
		Format(buffer, maxlen, "EXP Kill Streak Messages: %s", status);
	}
	else
	{
		option_killstreak_announcemessage[client] = !option_killstreak_announcemessage[client];
		
		if (option_killstreak_announcemessage[client])
		{
			SetClientCookie(client, cookie_killstreak_announcemessage, "On");
			CPrintToChat(client, "%t", "Kill Streak Messages Enabled");
		}
		else
		{
			SetClientCookie(client, cookie_killstreak_announcemessage, "Off");
			CPrintToChat(client, "%t", "Kill Streak Messages Disabled");
		}
		
		ShowCookieMenu(client);
	}
}