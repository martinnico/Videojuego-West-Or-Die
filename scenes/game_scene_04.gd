# game_scene_04.gd
# Escena del patio de la taberna (enfrentamiento final).
# El protagonista corre a esconderse detrás de los barriles.
# Se activa un QTE de doble objetivo: el jugador debe cliquear en ambos forajidos a tiempo.
# Si lo logra, lanza una dinamita que explota y derrota a los enemigos.
# Si falla, los enemigos disparan y el jugador muere.

extends Control

# ---------- Nodos ----------
@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var player_tira_dinamita: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_muere: AnimatedSprite2D = $AnimatedSprite2D2

@onready var enemy1_hitbox: Area2D = $Enemy1Hitbox
@onready var enemy1_levanta: AnimatedSprite2D = $Enemy1Hitbox/AnimatedSprite2D
@onready var enemy1_dispara: AnimatedSprite2D = $Enemy1Hitbox/AnimatedSprite2D2
@onready var enemy1_muere: AnimatedSprite2D = $Enemy1Hitbox/AnimatedSprite2D3

@onready var enemy2_hitbox: Area2D = $Enemy2Hitbox
@onready var enemy2_levanta: AnimatedSprite2D = $Enemy2Hitbox/AnimatedSprite2D
@onready var enemy2_dispara: AnimatedSprite2D = $Enemy2Hitbox/AnimatedSprite2D2
@onready var enemy2_muere: AnimatedSprite2D = $Enemy2Hitbox/AnimatedSprite2D3

@onready var dinamita: AnimatedSprite2D = $Dinamita
@onready var lives_container: HBoxContainer = $LivesContainer
@onready var narrative_label: Label = $NarrativeLabel
@onready var qte_prompt: Control = $QTEPrompt

# ---------- Configuración Exportada ----------
## Centro de la cámara para encuadrar la escena completa en pantalla.
@export var camera_center: Vector2 = Vector2(1750, 1000)
## Nivel de escala/zoom de la cámara (valores bajos como 0.6 alejan la cámara).
@export var camera_zoom: float = 0.6
## Escala del cartel "Pensa rapido" para hacerlo más grande.
@export var qte_scale: float = 1.5

## Duración en segundos de la corrida de entrada del protagonista.
@export var run_duration: float = 2.0
## Tiempo límite en segundos para cliquear ambos enemigos.
@export var qte_time_limit: float = 3.0
## Retraso en segundos tras la explosión para completar la escena.
@export var win_transition_delay: float = 2.5

# ---------- Control de Estado ----------
var _camera: Camera2D
var _fade_overlay: ColorRect
var _run_target_x: float

var _enemy1_clicked: bool = false
var _enemy2_clicked: bool = false
var _qte_resolved: bool = false


func _ready() -> void:
	# 1. Guardar la posición de destino del jugador detrás de los barriles.
	_run_target_x = player_sprite.position.x

	# 2. Crear e instanciar la cámara dinámicamente con zoom configurable para encuadrar todo.
	_camera = Camera2D.new()
	_camera.position = camera_center
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_camera.enabled = true
	add_child(_camera)

	# 3. Crear el overlay de fade-out de forma dinámica.
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0) # Inicia transparente.
	_fade_overlay.size = Vector2(1920, 1080)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(_fade_overlay)

	# 4. Configurar la visualización de vidas y señales.
	_update_lives_display()
	GameManager.lives_changed.connect(_on_lives_changed)
	qte_prompt.qte_success.connect(_on_qte_success)
	qte_prompt.qte_failure.connect(_on_qte_failure)

	# 5. Desactivar mouse_filter en todos los Control para no bloquear clics físicos de Area2D.
	_set_mouse_filter_ignore(self)

	# 6. Configurar la escala y el posicionamiento centrado del cartel "Pensa rapido".
	qte_prompt.prompt_text = "Pensa rapido"
	qte_prompt.time_limit = qte_time_limit
	qte_prompt.scale = Vector2(qte_scale, qte_scale)
	qte_prompt.pivot_offset = qte_prompt.size / 2.0
	# Posicionarlo en el centro del encuadre de la cámara
	qte_prompt.position = camera_center - (qte_prompt.size / 2.0)

	# 7. Iniciar secuencia del patio.
	_iniciar_escena()


# -------------------- Control de Escena --------------------

## Restablece los sprites, visibilidades y posiciona al jugador para iniciar la escena.
func _iniciar_escena() -> void:
	_enemy1_clicked = false
	_enemy2_clicked = false
	_qte_resolved = false
	qte_prompt.visible = false
	narrative_label.text = "¡Llegaron más refuerzos!"

	# Configurar cámara a valores iniciales de encuadre
	if _camera:
		_camera.position = camera_center
		_camera.zoom = Vector2(camera_zoom, camera_zoom)

	# Control estricto de visibilidades del jugador (solo se muestra sprite de corrida base)
	player_sprite.visible = true
	player_sprite.modulate.a = 1.0
	player_tira_dinamita.visible = false
	player_muere.visible = false

	# Control estricto de visibilidades de los enemigos (solo se muestra levantar)
	enemy1_levanta.visible = true
	enemy1_dispara.visible = false
	enemy1_muere.visible = false
	enemy1_levanta.frame = 0

	enemy2_levanta.visible = true
	enemy2_dispara.visible = false
	enemy2_muere.visible = false
	enemy2_levanta.frame = 0

	# Ocultar dinamita
	dinamita.visible = false
	dinamita.stop()

	# Reproducir la animación en su posición original del editor.
	# Los fotogramas ya contienen todo el movimiento del cowboy corriendo hacia los barriles.
	player_sprite.frame = 0
	player_sprite.play("main corre")

	# Iniciar animación de levantarse en ambos enemigos al mismo tiempo
	enemy1_levanta.play("Enemigo se levanta")
	enemy2_levanta.play("enemigo 2 levanta")

	# Esperar a que termine la animación del jugador corriendo
	await player_sprite.animation_finished
	# Quedarse en el último frame (cowboy agachado detrás de los barriles)
	var _last_run_frame := player_sprite.sprite_frames.get_frame_count("main corre") - 1
	player_sprite.stop()
	player_sprite.frame = _last_run_frame

	# Conectar señal de fin de animación de enemigos para que queden en su último frame
	if not enemy1_levanta.animation_finished.is_connected(_on_enemy1_levanta_finished):
		enemy1_levanta.animation_finished.connect(_on_enemy1_levanta_finished)
	if not enemy2_levanta.animation_finished.is_connected(_on_enemy2_levanta_finished):
		enemy2_levanta.animation_finished.connect(_on_enemy2_levanta_finished)

	if not _qte_resolved:
		narrative_label.text = "¡Pensa rápido!"
		qte_prompt.start_qte()


# -------------------- Callbacks de Animaciones de Enemigos --------------------

## Congela el enemigo 1 en su último frame al terminar la animación "levanta".
func _on_enemy1_levanta_finished() -> void:
	enemy1_levanta.stop()
	enemy1_levanta.frame = enemy1_levanta.sprite_frames.get_frame_count(enemy1_levanta.animation) - 1


## Congela el enemigo 2 en su último frame al terminar la animación "levanta".
func _on_enemy2_levanta_finished() -> void:
	enemy2_levanta.stop()
	enemy2_levanta.frame = enemy2_levanta.sprite_frames.get_frame_count(enemy2_levanta.animation) - 1


# -------------------- Entrada del Jugador --------------------

## Detecta los clics en las hitboxes de forma sincrónica.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed):
		return
	if not qte_prompt.is_active or qte_prompt.is_resolved or _qte_resolved:
		return

	# Chequeo sincrónico de colisiones físicas en el punto de clic
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	var result = space_state.intersect_point(query)

	for hit in result:
		if hit["collider"] == enemy1_hitbox:
			_enemy1_clicked = true
		elif hit["collider"] == enemy2_hitbox:
			_enemy2_clicked = true

	# Si se clickearon ambas hitboxes, resolver el QTE como éxito
	if _enemy1_clicked and _enemy2_clicked:
		_qte_resolved = true
		qte_prompt.is_active = false
		qte_prompt._resolve_success()


# -------------------- Éxito (Dinamita) --------------------

func _on_qte_success() -> void:
	narrative_label.text = "¡Toma esto!"

	# 1. PlayerSprite DESAPARECE POR COMPLETO
	player_sprite.visible = false
	player_sprite.modulate.a = 0.0
	player_sprite.position.x = -9999
	player_tira_dinamita.visible = true
	player_muere.visible = false

	# 2. Los dos enemigos se quedan parados (visibles pero quietos en su último frame)
	enemy1_levanta.visible = true
	enemy1_dispara.visible = false
	enemy1_muere.visible = false
	var _e1_last_frame := enemy1_levanta.sprite_frames.get_frame_count("Enemigo se levanta") - 1
	enemy1_levanta.stop()
	enemy1_levanta.frame = _e1_last_frame

	enemy2_levanta.visible = true
	enemy2_dispara.visible = false
	enemy2_muere.visible = false
	var _e2_last_frame := enemy2_levanta.sprite_frames.get_frame_count("enemigo 2 levanta") - 1
	enemy2_levanta.stop()
	enemy2_levanta.frame = _e2_last_frame

	# 3. El jugador ejecuta la animación de tirar la dinamita
	player_tira_dinamita.play("main tira dinamita")

	# 4. Esperamos a que la animación de tirar dinamita termine de ejecutarse
	await player_tira_dinamita.animation_finished

	# 5. En la explosión, los enemigos levantados desaparecen y se activan los de muerte por explosión
	enemy1_levanta.visible = false
	enemy1_muere.visible = true
	enemy1_muere.play("enemigo 1 patio muere")

	enemy2_levanta.visible = false
	enemy2_muere.visible = true
	enemy2_muere.play("enemigo 2 patio muere")

	# Activar la animación de la explosión
	dinamita.visible = true
	dinamita.play("Explosion")

	# Esperar a que terminen las animaciones de muerte y explosión
	await get_tree().create_timer(win_transition_delay).timeout

	# 6. Fade-out e ir a la siguiente escena (pantalla de resultados / victoria final)
	await _play_fade_out(1.0)
	GameManager.game_result = "victory"
	GameManager.go_to_next_scene()


# -------------------- Fallo (Disparo Cruzado) --------------------

func _on_qte_failure() -> void:
	_qte_resolved = true
	narrative_label.text = "¡Te acorralaron!"

	# 1. Desaparecen los 3 sprites anteriores del jugador y enemigos
	player_sprite.visible = false
	player_sprite.modulate.a = 0.0
	player_sprite.position.x = -9999
	player_tira_dinamita.visible = false
	
	enemy1_levanta.visible = false
	enemy1_dispara.visible = false
	enemy1_muere.visible = false

	enemy2_levanta.visible = false
	enemy2_dispara.visible = false
	enemy2_muere.visible = false

	# 2. Solo aparecen AnimatedSprite2D2 del jugador y los disparos enemigos (AnimatedSprite2D2)
	# Resetear la animación de muerte al frame 0 antes de reproducir
	player_muere.stop()
	player_muere.frame = 0
	player_muere.visible = true
	player_muere.play()

	enemy1_dispara.visible = true
	enemy1_dispara.play("enemigo 1 dispara")

	enemy2_dispara.visible = true
	enemy2_dispara.play("enemigo 2 patio dispara")

	# Esperar a que las animaciones de disparo y muerte concluyan
	await get_tree().create_timer(2.0).timeout

	# 3. Descontar vida y evaluar flujo
	GameManager.lose_life()
	if GameManager.is_game_over():
		narrative_label.text = "El patio de la taberna fue tu tumba..."
		await get_tree().create_timer(1.5).timeout
		GameManager.go_to_result()
	else:
		# Reiniciar nivel
		await _play_fade_out(0.5)
		_iniciar_escena()
		# Fade-in suave de retorno
		var fade_in = create_tween()
		fade_in.tween_property(_fade_overlay, "color:a", 0.0, 0.5)


# -------------------- Utilidades y UI --------------------

## Reconstruye el contenedor de vidas de corazones.
func _update_lives_display() -> void:
	for child in lives_container.get_children():
		child.queue_free()
	for i in GameManager.lives:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", 32)
		heart.add_theme_color_override("font_color", Color.RED)
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lives_container.add_child(heart)


func _on_lives_changed(_new_lives: int) -> void:
	_update_lives_display()


## Fundido a negro (fade-out) dinámico.
func _play_fade_out(duration: float) -> void:
	if not _fade_overlay:
		return
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await tween.finished


## Configura recursivamente MOUSE_FILTER_IGNORE en todos los Controles para no obstruir las colisiones.
func _set_mouse_filter_ignore(node: Node) -> void:
	if node is Control and node != qte_prompt:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_ignore(child)
