# game_manager.gd
# Autoload singleton managing global game state.
# Tracks player lives, scene progression, and game results.

extends Node

## Emitted when the player's life count changes.
signal lives_changed(new_lives: int)
## Emitted when the player runs out of lives.
signal game_over

## Current number of lives.
var lives: int = 3
## Maximum lives the player can have.
var max_lives: int = 3
## Index into scene_order for the current scene.
## NOTA DE TESTING: seteado en 3 para arrancar directo en game_scene_04.
var current_scene_index: int = 3
## Result of the game: "victory", "defeat", or "" (in progress).
var game_result: String = ""

## Ruta a la cinemática introductoria (se reproduce antes de la primera escena).
var intro_cinematic_path: String = "res://scenes/intro_cinematic.tscn"

## Ordered list of gameplay scene paths.
var scene_order: Array[String] = [
	"res://scenes/game_scene_01.tscn",
	"res://scenes/game_scene_02.tscn",
	"res://scenes/game_scene_03.tscn",
	"res://scenes/game_scene_04.tscn",
]


func _ready() -> void:
	reset_game()


## Resets all game state to starting values.
func reset_game() -> void:
	lives = max_lives
	# NOTA DE TESTING: arrancar directo en la última escena (game_scene_04, índice 3).
	# Cambiar a 0 para jugar desde el inicio.
	current_scene_index = 3
	game_result = ""
	lives_changed.emit(lives)


## Removes one life. Emits game_over if lives reach zero.
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_result = "defeat"
		game_over.emit()


## Returns true if the player has no lives left.
func is_game_over() -> bool:
	return lives <= 0


## Changes to the given scene file path.
func go_to_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


## Advances to the next scene in scene_order, or victory if done.
func go_to_next_scene() -> void:
	current_scene_index += 1
	if current_scene_index < scene_order.size():
		go_to_scene(scene_order[current_scene_index])
	else:
		game_result = "victory"
		go_to_result()


## Transitions to the result screen.
func go_to_result() -> void:
	go_to_scene("res://scenes/result_screen.tscn")


## Transitions to the main menu.
func go_to_main_menu() -> void:
	go_to_scene("res://scenes/main_menu.tscn")


## Resets state and starts the game (cinemática intro → primera escena).
func start_game() -> void:
	reset_game()
	go_to_scene(intro_cinematic_path)


## Llamada por la cinemática al terminar. Inicia la primera escena de juego.
func start_first_scene() -> void:
	if scene_order.size() > 0:
		go_to_scene(scene_order[0])
