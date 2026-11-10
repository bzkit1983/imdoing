extends RefCounted
## Swappable MultiplayerPeer factory (multiplayer.md §6.1 / §12.1).
## Only SessionService constructs peers — gameplay never calls this directly.

const DEFAULT_PORT := 7777
## Peer cap only (host + remotes). Seat cap is SessionService.ROOM_MAX_SEATS —
## claim2 can fill 4 seats with fewer peers, so host must refuse extra peers.
const MAX_CLIENTS := 3


static func lan_available() -> bool:
	## Web has no bare ENet UDP.
	return not OS.has_feature("web")


static func create_host(port: int = DEFAULT_PORT) -> Dictionary:
	## Returns {ok: bool, peer: MultiplayerPeer|null, error: String, port: int}.
	if not lan_available():
		return {"ok": false, "peer": null, "error": "web_no_enet", "port": port}
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return {"ok": false, "peer": null, "error": "create_server_%d" % err, "port": port}
	return {"ok": true, "peer": peer, "error": "", "port": port}


static func join_host(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	## Returns {ok: bool, peer: MultiplayerPeer|null, error: String}.
	if not lan_available():
		return {"ok": false, "peer": null, "error": "web_no_enet"}
	var host := address.strip_edges()
	if host.is_empty():
		return {"ok": false, "peer": null, "error": "empty_address"}
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return {"ok": false, "peer": null, "error": "create_client_%d" % err}
	return {"ok": true, "peer": peer, "error": ""}


static func close_peer(peer: MultiplayerPeer) -> void:
	if peer == null:
		return
	peer.close()
