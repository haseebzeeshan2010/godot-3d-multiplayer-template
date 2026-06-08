class_name LagPeer extends MultiplayerPeerExtension

# A debug MultiplayerPeer wrapper that simulates network latency, jitter and
# packet loss on top of a real peer (e.g. ENetMultiplayerPeer), for testing
# locally without a real network.
#
# Outgoing packets are forwarded straight through. Incoming packets are held in
# a delay queue and released after `latency_ms + random(0..jitter_ms)`. Only
# UNRELIABLE packets are eligible for simulated loss: reliable packets have
# already been acknowledged by the underlying transport, so dropping them here
# would break high-level reliability with no chance of retransmission.
#
# Config is static (process-global), so it persists across reconnects and is
# read live each poll. Each running game instance delays its OWN inbound
# traffic, so enabling this on the client alone simulates one-way server->client
# latency; enable it on both host and client for symmetric round-trip delay.

# --- Live, process-global config (read every poll) ---
static var enabled: bool = false
static var latency_ms: int = 0       # base one-way delay added to inbound packets
static var jitter_ms: int = 0        # extra random delay in [0, jitter_ms]
static var packet_loss: float = 0.0  # chance [0..1] to drop an unreliable packet

var _inner: MultiplayerPeer

# Inbound packets waiting for their release time, ordered by release (FIFO).
var _incoming: Array[Dictionary] = []
# Inbound packets that have been released and are ready to hand to the engine.
var _ready: Array[Dictionary] = []
# Monotonic release clock so we never reorder packets (keeps reliable-ordered
# channels intact); jitter can only delay a packet, never overtake an earlier one.
var _last_release: int = 0

# Wrap an already-created peer. Call before assigning to multiplayer_peer.
func setup(inner: MultiplayerPeer) -> void:
	_inner = inner
	_inner.peer_connected.connect(func(id: int): peer_connected.emit(id))
	_inner.peer_disconnected.connect(func(id: int): peer_disconnected.emit(id))

# --- Polling / packet flow ---

func _poll() -> void:
	if _inner == null:
		return

	_inner.poll()

	# Drain everything the inner peer received this poll into the delay queue.
	while _inner.get_available_packet_count() > 0:
		# Metadata refers to the next packet, so read it before get_packet().
		var from: int = _inner.get_packet_peer()
		var channel: int = _inner.get_packet_channel()
		var mode: int = _inner.get_packet_mode()
		var data: PackedByteArray = _inner.get_packet()

		if enabled and packet_loss > 0.0 and mode != MultiplayerPeer.TRANSFER_MODE_RELIABLE:
			if randf() < packet_loss:
				continue

		var delay := 0
		if enabled:
			delay = latency_ms
			if jitter_ms > 0:
				delay += randi() % (jitter_ms + 1)

		var now := Time.get_ticks_msec()
		var release: int = max(now + delay, _last_release)
		_last_release = release

		_incoming.append({
			"data": data,
			"from": from,
			"channel": channel,
			"mode": mode,
			"release": release,
		})

	# Release any packets whose time has come (queue is release-ordered).
	var now_ms := Time.get_ticks_msec()
	while not _incoming.is_empty() and _incoming[0]["release"] <= now_ms:
		_ready.append(_incoming.pop_front())

func _get_available_packet_count() -> int:
	return _ready.size()

func _get_packet_script() -> PackedByteArray:
	if _ready.is_empty():
		return PackedByteArray()
	var data: PackedByteArray = _ready.pop_front()["data"]
	return data

# Metadata getters describe the packet that the next _get_packet_script() returns.
func _get_packet_peer() -> int:
	return int(_ready[0]["from"]) if not _ready.is_empty() else 1

func _get_packet_channel() -> int:
	return int(_ready[0]["channel"]) if not _ready.is_empty() else 0

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	if _ready.is_empty():
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var mode: int = _ready[0]["mode"]
	return mode as MultiplayerPeer.TransferMode

# Outgoing packets pass straight through to the inner peer.
func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	return _inner.put_packet(p_buffer)

func _get_max_packet_size() -> int:
	return 1 << 24

# --- Everything else delegates to the inner peer ---

func _set_transfer_channel(p_channel: int) -> void:
	_inner.transfer_channel = p_channel

func _get_transfer_channel() -> int:
	return _inner.transfer_channel

func _set_transfer_mode(p_mode: MultiplayerPeer.TransferMode) -> void:
	_inner.transfer_mode = p_mode

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _inner.transfer_mode

func _set_target_peer(p_peer: int) -> void:
	_inner.set_target_peer(p_peer)

func _get_unique_id() -> int:
	return _inner.get_unique_id()

func _is_server() -> bool:
	return _inner.is_server()

func _is_server_relay_supported() -> bool:
	return _inner.is_server_relay_supported()

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _inner.get_connection_status() if _inner != null else MultiplayerPeer.CONNECTION_DISCONNECTED

func _set_refuse_new_connections(p_enable: bool) -> void:
	_inner.refuse_new_connections = p_enable

func _is_refusing_new_connections() -> bool:
	return _inner.refuse_new_connections

func _disconnect_peer(p_peer: int, p_force: bool) -> void:
	_inner.disconnect_peer(p_peer, p_force)

func _close() -> void:
	_incoming.clear()
	_ready.clear()
	_last_release = 0
	if _inner != null:
		_inner.close()
