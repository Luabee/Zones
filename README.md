# ZONES - by Bobbleheadbob #
**WARNING: If you edit any of these files, make them use a different namespace. Multiple scripts may depend on this library so modifying it can break other scripts.**
If you have a universially beneficial change, please consider making a pull request. :)

## Purpose: ##
For easy in-game designation of persistent polygonal zones which are used by any script.
https://www.youtube.com/watch?v=Cht0jQBcVL8

## Installation: ##
- This is a shared file so include it in any shared environment. Also include ent_zone_point and weapon_zone_designator as a shared ent and weapon.
- You should not put this file directly in lua/autorun.

## How to Use: ##
- All zones are saved in zones.List as tables.
- Zone creation is handled with weapon_zone_designator and ent_zone_point, but can be in code as well.
- When a zone is created, changed, or removed all zones are synced to clients. When clients join they are also synced.
- Any extra details can be saved to a zone. Everything is written to a txt file and is persistent to the map.

- Since multiple scripts might use the zones system, don't assume that every zone is related to your script.
- To register a zone class, use zones.RegisterClass(class, color); use a unique string like "Scriptname Room".
- When a new zone is created, the "OnZoneCreated" hook is called serverside.
- When a player edits a zone's properties, the "ShowZoneOptions" hook is called clientside.

- Use zones.FindByClass() to find all zones which are of a given class.
- Use ply:GetCurrentZone() to find the zone that a player is standing in.

*Enjoy! ~Bobbleheadbob*
