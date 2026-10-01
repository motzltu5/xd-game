import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";

const port = Number(process.env.PORT || 8080);
const rooms = new Map();
const http = createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    return;
  }
  res.writeHead(200, { "content-type": "text/plain" });
  res.end("Counter Ops match server is running.\n");
});
const wss = new WebSocketServer({ server: http, path: "/ws", maxPayload: 4096 });

function send(peer, value) {
  if (peer.readyState === WebSocket.OPEN) peer.send(JSON.stringify(value));
}

function roster(room) {
  return [...room.players.values()].map(({ id, name, team }) => ({ id, name, team }));
}

function broadcast(room, value, except = null) {
  const packet = JSON.stringify(value);
  for (const peer of room.players.values()) {
    if (peer !== except && peer.readyState === WebSocket.OPEN) peer.send(packet);
  }
}

function publishRoster(room) {
  const players = roster(room);
  broadcast(room, {
    type: "roster",
    players,
    player_count: players.length,
    bot_fill: room.mode === "5v5" && players.length < 2,
  });
}

function rebalance(room) {
  const members = [...room.players.values()];
  room.tCount = 0;
  room.ctCount = 0;
  if (room.mode !== "5v5") return;
  for (const [index, member] of members.entries()) {
    member.team = index % 2 === 0 ? "t" : "ct";
    if (member.team === "t") room.tCount++;
    else room.ctCount++;
  }
}

function remove(peer) {
  const room = peer.room;
  if (!room) return;
  room.players.delete(peer.id);
  peer.room = null;
  if (room.players.size === 0) rooms.delete(room.key);
  else { rebalance(room); publishRoster(room); }
}

wss.on("connection", peer => {
  peer.id = randomUUID();
  peer.isAlive = true;
  peer.on("pong", () => { peer.isAlive = true; });
  peer.on("message", raw => {
    let message;
    try { message = JSON.parse(raw.toString()); } catch { return; }
    if (!message || typeof message.type !== "string") return;

    if (message.type === "join") {
      remove(peer);
      const mode = message.mode === "5v5" ? "5v5" : "deathmatch";
      const roomName = String(message.room || "public").trim().toLowerCase().slice(0, 24) || "public";
      const key = `${mode}:${roomName}`;
      const capacity = mode === "5v5" ? 10 : 16;
      let room = rooms.get(key);
      if (room && room.players.size >= capacity) {
        send(peer, { type: "error", message: "That room is full. Try another room code." });
        return;
      }
      if (!room) {
        room = { key, mode, roomName, players: new Map(), tCount: 0, ctCount: 0 };
        rooms.set(key, room);
      }
      const team = mode === "5v5" ? (room.tCount <= room.ctCount ? "t" : "ct") : "dm";
      if (team === "t") room.tCount++;
      if (team === "ct") room.ctCount++;
      peer.room = room;
      peer.team = team;
      peer.name = String(message.name || "Player").replace(/[<>\u0000-\u001f]/g, "").slice(0, 18) || "Player";
      peer.health = 100;
      peer.alive = true;
      room.players.set(peer.id, peer);
      send(peer, { type: "joined", id: peer.id, team, mode, room: roomName });
      rebalance(room);
      publishRoster(room);
      return;
    }

    const room = peer.room;
    if (!room) return;
    if (message.type === "state") {
      const p = message.position;
      if (!Array.isArray(p) || p.length !== 3 || !p.every(Number.isFinite)) return;
      // Discard corrupt/teleport-sized packets instead of relaying them.
      if (p[0] < -220 || p[0] > 220 || p[1] < -30 || p[1] > 180 || p[2] < -220 || p[2] > 220) return;
      const nowAlive = message.alive !== false;
      if (nowAlive && !peer.alive) peer.health = 100;
      peer.alive = nowAlive;
      broadcast(room, {
        type: "state",
        id: peer.id,
        position: p,
        yaw: Number.isFinite(message.yaw) ? message.yaw : 0,
        pitch: Number.isFinite(message.pitch) ? Math.max(-1.55, Math.min(1.55, message.pitch)) : 0,
        weapon: String(message.weapon || "rifle").slice(0, 16),
        alive: nowAlive,
      }, peer);
      return;
    }
    if (message.type === "hit") {
      const target = room.players.get(String(message.target || ""));
      if (!target || target === peer) return;
      if (peer.alive === false || target.alive === false) return;
      if (room.mode === "5v5" && target.team === peer.team) return;
      const weapon = String(message.weapon || "rifle").slice(0, 16);
      const damage = weapon === "awp" || weapon === "knife" || message.headshot === true ? 100 : weapon === "pistol" ? 35 : 50;
      target.health = Math.max(0, (target.health ?? 100) - damage);
      target.alive = target.health > 0;
      broadcast(room, {
        type: "hit",
        shooter: peer.id,
        target: target.id,
        damage,
        target_health: target.health,
        killed: target.health <= 0,
        weapon,
        headshot: message.headshot === true,
      });
    }
  });
  peer.on("close", () => remove(peer));
  peer.on("error", () => remove(peer));
});

const heartbeat = setInterval(() => {
  for (const peer of wss.clients) {
    if (!peer.isAlive) { peer.terminate(); continue; }
    peer.isAlive = false;
    peer.ping();
  }
}, 30000);

http.listen(port, "0.0.0.0", () => console.log(`Counter Ops match server listening on ${port}`));
for (const signal of ["SIGINT", "SIGTERM"]) process.on(signal, () => {
  clearInterval(heartbeat);
  for (const peer of wss.clients) peer.close();
  http.close(() => process.exit(0));
});
