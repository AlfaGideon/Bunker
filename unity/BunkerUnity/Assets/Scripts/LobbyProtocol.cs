using System;

namespace Bunker.UnityPort
{
    // JsonUtility DTOs intentionally mirror the existing aiohttp server.
    // Hidden cards arrive without value; never derive or invent their contents.
    [Serializable] public sealed class Command
    {
        public string type;
        public string name;
        public string skin;
        public string title;
        public string room_id;
        public int capacity;
        public string action;
        public string value;
    }
    [Serializable] public sealed class BooleanCommand
    {
        public string type = "game_action";
        public string action;
        public bool value;
    }
    [Serializable] public sealed class SessionResponse { public string session; public int protocol; }
    [Serializable] public sealed class Envelope { public LobbyEvent[] events; }
    [Serializable] public sealed class LobbyEvent
    {
        public string type;
        public string code;
        public string reason;
        public string player_id;
        public Room room;
        public Room[] rooms;
        public MatchState state;
    }
    [Serializable] public sealed class Room
    {
        public string id;
        public string title;
        public string host_id;
        public int capacity;
        public int count;
        public bool started;
        public Member[] players;
    }
    [Serializable] public sealed class Member
    {
        public string id;
        public string name;
        public string skin;
        public bool bot;
        public bool away;
    }
    [Serializable] public sealed class Card
    {
        public string id;
        public string label;
        public string value;
        public bool revealed;
    }
    [Serializable] public sealed class Player
    {
        public string id;
        public string name;
        public string appearance;
        public bool bot;
        public bool away;
        public int seat;
        public Card[] cards;
    }
    [Serializable] public sealed class Scenario { public string id; public string title; public string brief; public string weather; }
    [Serializable] public sealed class MatchState
    {
        public int revision;
        public int seed;
        public int capacity;
        public int round;
        public string phase;
        public string speaker;
        public bool revealed_this_turn;
        public float remaining;
        public string[] active;
        public string[] candidates;
        public string my_vote;
        public bool second_ballot;
        public Player[] players;
        public Scenario scenario;
        public VoteResult result;
        public StationState stations;
    }
    [Serializable] public sealed class VoteResult { public string status; public string player; public string[] leaders; public bool random; }
    [Serializable] public sealed class Stock { public int water; public int food; public int medicine; public int filters; }
    [Serializable] public sealed class StationState
    {
        public int meals;
        public int medicines;
        public bool medical_open;
        public bool warehouse_open;
        public bool shortage;
        public bool systems_ready;
        public int warehouse_votes;
        // Populated only by the offline simulation; the server sends a map instead.
        public int local_stamina;
        public Stock stock;
        public RadioState radio;
    }
    [Serializable] public sealed class RadioState
    {
        public bool powered;
        public string station;
        public int track_index;
        public int internet_index;
        public int scan_round;
        public int signal_index;
        public int message_id;
        public RadioMessage[] received;
    }
    [Serializable] public sealed class RadioMessage { public int id; public string from; public string text; }
}
