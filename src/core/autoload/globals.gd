extends Node

#Enum
enum GameType { CAMPAIGN, CUSTOM } 

enum RaceType { HUMANS, ORCS, MAP_DEFAULT, RANDOM }
enum FactionType { ALLIANCE, HORDE, NEUTRAL }
enum UnitType { LAND, AIR, SEA }
enum DamageType { NORMAL, PIERCING, SIEGE, MAGIC, HERO }
enum ArmorType { UNARMORED, LIGHT, MEDIUM, HEAVY, FORTIFIED, HERO }
enum MapResourcesType { MAP_DEFAULT, LOW, MEDIUM, HIGH }
enum StartUnitsType { MAP_DEFAULT, ONE_PEASANT_ONLY }
enum MapTilesetType { MAP_DEFAULT, RANDOM, FOREST }

enum ColorType { RED, BLUE, GRAY, ORANGE, PINK, GREEN, WHITE, YELLOW }

enum ResourceType { NONE, WOOD, GOLD, OIL }

# Costante del bonus descritto dal manuale
const ELVEN_MILL_WOOD_BONUS: int = 25
# Costande della texture NoImage
const NO_IMAGE = preload("uid://dibevppt5yrf2")
