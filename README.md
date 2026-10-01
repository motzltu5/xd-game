# Counter Ops — Dust II

[Play the browser game](https://motzltu5.github.io/xd-game/).

GitHub Actions exports the Godot source project and deploys the web build to GitHub Pages after each push to `main`. The Godot project and Dust II model sources are included in this repository; the model attribution is in `assets/dust2/MODEL_CREDITS.md`.

Practice and the offline modes run against bots. Online 5v5 and Deathmatch use the WebSocket match server in `server/`.

## Enable online matches

1. Import this repository as a Blueprint at [Render](https://dashboard.render.com/blueprints). Render reads `render.yaml` and creates the Node.js match server.
2. Wait for the service to finish deploying. Its address will look like `https://counter-ops-match-server.onrender.com`.
3. Open the game, choose an online mode, and set the WebSocket URL to `wss://counter-ops-match-server.onrender.com/ws`. If Render assigns a different hostname, use that hostname instead. Players join the same room by entering the same room code.

The room server assigns 5v5 players to the smaller team. With one human in a 5v5 room, local bots fill the sides; when another human joins, those bots are removed. The Render free plan can sleep after 15 minutes without requests, so a first connection after idle may take time to wake it.
