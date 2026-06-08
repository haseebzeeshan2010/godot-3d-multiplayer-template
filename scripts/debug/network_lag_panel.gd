extends PanelContainer

# Controller for the network lag debug panel.

# Settings affect THIS instance's inbound packets only. Enable on the client to
# simulate one-way server->client latency, or on both host and client for
# symmetric round-trip delay.

@export var enabled_check: CheckButton
@export var latency_spin: SpinBox   # milliseconds
@export var jitter_spin: SpinBox    # milliseconds
@export var loss_spin: SpinBox      # whole-percent value (0-100)

func _ready() -> void:
	if enabled_check:
		enabled_check.set_pressed_no_signal(LagPeer.enabled)
		enabled_check.toggled.connect(func(pressed: bool): LagPeer.enabled = pressed)
		
	if latency_spin:
		latency_spin.set_value_no_signal(LagPeer.latency_ms)
		latency_spin.value_changed.connect(func(v: float): LagPeer.latency_ms = int(v))
	if jitter_spin:
		jitter_spin.set_value_no_signal(LagPeer.jitter_ms)
		jitter_spin.value_changed.connect(func(v: float): LagPeer.jitter_ms = int(v))
	if loss_spin:
		loss_spin.set_value_no_signal(LagPeer.packet_loss * 100.0)
		loss_spin.value_changed.connect(func(v: float): LagPeer.packet_loss = v / 100.0)


func _on_enabled_check_pressed() -> void:
	print(enabled_check.pressed)


func _on_enabled_check_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	if toggled_on:
		enabled_check.text = "Enabled"
	else:
		enabled_check.text = "Disabled"
	pass # Replace with function body.
