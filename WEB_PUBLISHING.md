# Publish the browser build

GitHub Actions exports the Godot project to the `site` artifact whenever code is pushed to `main`, then publishes that artifact to GitHub Pages. The project uses Godot 4.7.2's single-threaded Web template and Compatibility renderer.

The game supports browser WebSocket clients. Online rooms also need the Node service in `server/`; deploy it using the root `render.yaml`, then enter its secure WebSocket URL (`wss://<service-host>/ws`) in the game's online menu. GitHub Pages only serves the game files and does not host that live match service. Render's free service can sleep while idle, so a first connection may take time to wake it.

Mouse capture and audio start after the player interacts with the page, as required by browser security rules.

The Dust II model attribution is in `assets/dust2/MODEL_CREDITS.md`; include that credit in the published game's credits.

To export again from Godot, install the matching 4.7.2 export templates from **Editor → Manage Export Templates**, then use the **Web** preset and export to `web/index.html`.
