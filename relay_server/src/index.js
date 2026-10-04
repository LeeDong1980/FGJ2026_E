// FGJ2026 遠端連線中繼：兩位玩家都只對這裡做出站 wss 連線，由房間（Durable Object）互相轉送封包。
// 協定說明見 docs/relay.md。

import { DurableObject } from "cloudflare:workers";

// 去掉容易看錯的 I、O、0、1，剛好 32 個字元（32 整除 256，隨機取字不會有偏差）。
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const MAX_MESSAGE_BYTES = 64 * 1024;
const HOST_RETRIES = 5;

const CLOSE_HOST_LEFT = 4001;
const CLOSE_KICKED = 4002;
const CLOSE_ROOM_NOT_FOUND = 4004;
const CLOSE_ROOM_FULL = 4009;

function randomCode() {
	const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
	return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

function normalizeCode(text) {
	return text.toUpperCase().replace(/[\s-]/g, "");
}

function isWebSocketRequest(request) {
	return request.headers.get("Upgrade")?.toLowerCase() === "websocket";
}

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (url.pathname === "/health") {
			return Response.json({ ok: true, time: Date.now() }, { headers: { "Access-Control-Allow-Origin": "*" } });
		}
		if (!isWebSocketRequest(request)) {
			return new Response("Expected a WebSocket connection", { status: 426 });
		}

		if (url.pathname === "/echo") {
			return echo();
		}
		if (url.pathname === "/host") {
			return openRoom(request, env);
		}
		const join = url.pathname.match(/^\/join\/([A-Za-z0-9 -]{1,16})$/);
		if (join) {
			return joinRoom(request, env, normalizeCode(join[1]));
		}
		return new Response("Not found", { status: 404 });
	},
};

// 連線診斷用：收到什麼就原樣送回。
function echo() {
	const [client, server] = Object.values(new WebSocketPair());
	server.accept();
	server.addEventListener("message", (event) => server.send(event.data));
	return new Response(null, { status: 101, webSocket: client });
}

async function openRoom(request, env) {
	for (let i = 0; i < HOST_RETRIES; i++) {
		const code = randomCode();
		const response = await roomStub(env, code).fetch(forward(request, "host", code));
		if (response.status !== 409) {
			return response;
		}
	}
	return new Response("No room code available", { status: 503 });
}

function joinRoom(request, env, code) {
	if (code.length !== CODE_LENGTH) {
		return rejected(CLOSE_ROOM_NOT_FOUND, "room_not_found");
	}
	return roomStub(env, code).fetch(forward(request, "client", code));
}

function roomStub(env, code) {
	return env.ROOMS.get(env.ROOMS.idFromName(code));
}

function forward(request, role, code) {
	const headers = new Headers(request.headers);
	headers.set("X-Room-Role", role);
	headers.set("X-Room-Code", code);
	return new Request(request.url, { headers });
}

// 先完成握手再用關閉碼說明原因，Godot 端才讀得到原因（握手失敗只會看到一般錯誤）。
function rejected(code, reason) {
	const [client, server] = Object.values(new WebSocketPair());
	server.accept();
	server.close(code, reason);
	return new Response(null, { status: 101, webSocket: client });
}

// 一個房間一個 Durable Object：最多 1 個 host 加 1 個 client，只轉送，不理解遊戲內容。
// 使用 Hibernation API：房間沒有訊息時不計運算時間。ping／pong 由 runtime 自動回覆，不會喚醒。
export class Room extends DurableObject {
	constructor(ctx, env) {
		super(ctx, env);
		this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
	}

	async fetch(request) {
		const role = request.headers.get("X-Room-Role");
		const code = request.headers.get("X-Room-Code");
		return role === "host" ? this.#accept_host(code) : this.#accept_client();
	}

	#accept_host(code) {
		if (this.#socket("host")) {
			return new Response("Room code in use", { status: 409 });
		}
		const [client, server] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(server, ["host"]);
		server.send(JSON.stringify({ type: "hosted", code }));
		return new Response(null, { status: 101, webSocket: client });
	}

	#accept_client() {
		const host = this.#socket("host");
		if (!host) {
			return rejected(CLOSE_ROOM_NOT_FOUND, "room_not_found");
		}
		if (this.#socket("client")) {
			return rejected(CLOSE_ROOM_FULL, "room_full");
		}
		const [client, server] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(server, ["client"]);
		server.send(JSON.stringify({ type: "joined" }));
		host.send(JSON.stringify({ type: "peer_joined" }));
		return new Response(null, { status: 101, webSocket: client });
	}

	#socket(tag) {
		return this.ctx.getWebSockets(tag)[0] ?? null;
	}

	#other(ws) {
		return this.#socket(this.ctx.getTags(ws).includes("host") ? "client" : "host");
	}

	webSocketMessage(ws, message) {
		if (typeof message === "string") {
			// 唯一的文字控制訊息：房主踢掉沒回應的 client（讓下一位可以加入）。
			if (message.includes('"kick"') && this.ctx.getTags(ws).includes("host")) {
				safely(() => this.#socket("client")?.close(CLOSE_KICKED, "kicked"));
			}
			return;
		}
		if (message.byteLength > MAX_MESSAGE_BYTES) {
			safely(() => ws.close(1009, "too_big"));
			return;
		}
		safely(() => this.#other(ws)?.send(message));
	}

	webSocketClose(ws) {
		this.#left(ws);
	}

	webSocketError(ws) {
		this.#left(ws);
	}

	// 對已經關閉中的連線送訊息會丟例外，而例外會讓關閉流程中斷，所以每個動作都單獨保護。
	#left(ws) {
		const isHost = this.ctx.getTags(ws).includes("host");
		safely(() => ws.close(1000, "bye"));
		if (isHost) {
			safely(() => this.#socket("client")?.close(CLOSE_HOST_LEFT, "host_left"));
		} else {
			safely(() => this.#socket("host")?.send(JSON.stringify({ type: "peer_left" })));
		}
	}
}

function safely(action) {
	try {
		action();
	} catch {
		// 對方已經關閉，不需要處理
	}
}
