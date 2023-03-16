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



//////////////////////////
// - Global Variables - //
//////////////////////////


// Global Convars
Handle cvar_RequiredKillsForStreak;
Handle cvar_KillStreakBaseExperience;
Handle cvar_KillStreakBonusExperience;
Handle cvar_KillStreakMaximumExperience;

// Global Integers
int KillStreak[MAXPLAYERS + 1] = {0, ...};

// Global Cookie Variables
bool option_killstreak_announcemessage[MAXPLAYERS + 1] = {true,...};
Handle cookie_killstreak_announcemessage = INVALID_HANDLE;



//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


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
	cookie_killstreak_announcemessage = RegClientCookie("KS Messages On/Off 1", "ksmsg1337", CookieAccess_Private);
	SetCookieMenuItem(CookieMenuHandler_killstreak_announcemessage, cookie_killstreak_announcemessage, "KS Messages");

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_WCS_KillStreaks");

	// Loads the multi-language translation file
	LoadTranslations("custom_WCS_KillStreaks.phrases");
}


public void OnClientDisconnect(int client)
{
	// If the client meets our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Changes the player's kill streak to 0
	KillStreak[client] = 0;
}


public void OnClientCookiesCached(int client)
{
	// If the client meets our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// If the player is a bot then execute this section
	if(IsFakeClient(attacker))
	{
		return;
	}

	option_killstreak_announcemessage[client] = GetCookiekillstreak_announcemessage(client);
}



////////////////
// - Events - //
////////////////


// This happens every time a player spawns
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the victim and attacker's userids and store them within the respective variables: client and attacker
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client meets our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	// If the attacker meets our validation criteria then execute this section
	if(!IsValidClient(attacker))
	{
		return;
	}

	// If the attacker is not alive then execute this section
	if(!IsPlayerAlive(attacker))
	{
		return;
	}

	// If the attacker is the same person as the victim then execute this section
	if(attacker == client)
	{
		return;
	}

	// Changes the kill streak of the player that died to 0 
	KillStreak[client] = 0;

	// Adds a kill to the killstreak of the player that killed the opponent
	KillStreak[attacker] += 1;

	// If the attacker has killed less than (Default: 3) enemies without dying, then execute this section
	if(KillStreak[attacker] < GetConVarInt(cvar_RequiredKillsForStreak))
	{
		return;
	}

	// Multiplies the bonus experience value by the amount of additional kills beyond the minimum amount of kills
	int KillStreakTotalExperience = GetConVarInt(cvar_KillStreakBaseExperience) + (GetConVarInt(cvar_KillStreakBonusExperience) * (KillStreak[attacker] - GetConVarInt(cvar_RequiredKillsForStreak)));

	// If the maximum amount of experience is not set to 0 then execute this section
	if(GetConVarInt(cvar_KillStreakMaximumExperience) != 0)
	{
		// If the total experience bounty exceeds the maximum amount of experience a player's bounty is allowed to be, then execute this section
		if(KillStreakTotalExperience > GetConVarInt(cvar_KillStreakMaximumExperience))
		{
			// Changes the total experience to the maximum experience allowed to be acquired from a bounty
			KillStreakTotalExperience = GetConVarInt(cvar_KillStreakMaximumExperience);
		}
	}

	// Creates a variable named ServerCommandMessage which we'll store our message data within
	char ServerCommandMessage[128];

	// Formats a message and store it within our ServerCommandMessage variable
	FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_givexp %i %i", GetEventInt(event, "attacker"), KillStreakTotalExperience);

	// Executes our GiveLevel server command on the player, to award them with experience
	ServerCommand(ServerCommandMessage);

	// If the player is a bot then execute this section
	if(IsFakeClient(attacker))
	{
		return;
	}

	// If the player has the bounty announcement messages disabled then execute this section
	if(!option_killstreak_announcemessage[attacker])
	{
		return;
	}

	// Prints a message to the chat announcing the bounty
	CPrintToChat(attacker, "%t", "Killstreak Experience Message", KillStreakTotalExperience);
}



///////////////////////////
// - Regular Functions - //
///////////////////////////


public void CookieMenuHandler_killstreak_announcemessage(int client, CookieMenuAction action, any killstreak_announcemessage, char[] buffer, int maxlen)
{	
	if(action == CookieMenuAction_DisplayOption)
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



////////////////////////////////
// - Return Based Functions - //
////////////////////////////////


// We call upon this true and false statement whenever we wish to validate our player
bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


bool GetCookiekillstreak_announcemessage(int client)
{
	char buffer[10];

	GetClientCookie(client, cookie_killstreak_announcemessage, buffer, sizeof(buffer));
	
	return !StrEqual(buffer, "Off");
}