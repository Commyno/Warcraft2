@abstract
class_name BaseLevel
extends Node2D
#Abstract class for levels

#Providers a player spawn location
@abstract func get_default_player_spawn() -> Vector2

#Providers the camera used in the level
@abstract func get_camera() -> Camera2D
