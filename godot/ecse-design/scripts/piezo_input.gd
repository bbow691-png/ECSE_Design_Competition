extends Node

# Listens for piezo hit packets forwarded by stream_audio.py (the channel
# number only, e.g. "1" - hit velocity isn't used by the game) and injects
# them as real input events so drum_pad.gd's existing
# is_action_pressed(input_action) checks fire exactly as if the matching key
# had been pressed.

const UDP_PORT := 5005

# Which physical piezo channel maps to which InputMap action. Adjust to match
# how the piezos are actually wired/placed on the cabinet.
const CHANNEL_TO_ACTION := {
	1: "upp_left",
	2: "upp_righ",
	3: "low_left",
	4: "low_righ",
}

var _socket := PacketPeerUDP.new()

func _ready() -> void:
	var err := _socket.bind(UDP_PORT)
	if err != OK:
		push_error("piezo_input: failed to bind UDP port %d (error %d)" % [UDP_PORT, err])

func _process(_delta: float) -> void:
	while _socket.get_available_packet_count() > 0:
		_handle_packet(_socket.get_packet().get_string_from_utf8())

func _handle_packet(text: String) -> void:
	if not text.is_valid_int():
		return

	var action: String = CHANNEL_TO_ACTION.get(int(text), "")
	if action.is_empty():
		return

	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
