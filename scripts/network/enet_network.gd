extends Node

signal network_client_connected
signal network_server_disconnected

const SERVER_PORT = 8080

# func _ready():
	# Leaving note for clarity...
	# No connection exists when this _ready runs, it has yet to be established. 
	# You cannot rely on authority checks until the connection has been made.

func create_server_peer(network_connection_configs: NetworkConnectionConfigs):
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	enet_network_peer.create_server(SERVER_PORT)
	_install_peer(enet_network_peer)

func create_client_peer(network_connection_configs: NetworkConnectionConfigs):
	setup_client_connection_signals()

	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	enet_network_peer.create_client(network_connection_configs.host_ip, network_connection_configs.host_port)
	_install_peer(enet_network_peer)

# Wrap the real peer in the debug lag simulator before installing it. The wrapper
# is a no-op while LagPeer.enabled is false, so it's safe to leave in always; the
# in-game debug menu tweaks LagPeer's static config live. See lag_peer.gd.
func _install_peer(peer: MultiplayerPeer):
	var lag_peer := LagPeer.new()
	lag_peer.setup(peer)
	multiplayer.multiplayer_peer = lag_peer

func _connected_to_server():
	# Once our peer has a confirmed connection to the server/host, emit the connected signals
	# to prepare for game play. Right now it just loads the game scene on the client.
	print("Client connected to server/host, on peer %s with auth: %s" % [multiplayer.get_unique_id(), get_multiplayer_authority()])
	if not is_multiplayer_authority():
		network_client_connected.emit()

func _server_disconnected():
	print("Server disconnected!")
	network_server_disconnected.emit()

func setup_client_connection_signals():
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.server_disconnected.connect(_server_disconnected)
	#multiplayer.peer_connected.connect(_client_connected) # Right now there's no reason to use this...
