# Put the game on GitHub Pages

This starter bundle contains the exported browser game and a GitHub Actions workflow that publishes it to GitHub Pages. The game build is in `web_upload.zip`; the workflow unpacks it and deploys the site whenever you push to the `main` branch.

## Publish steps

1. Create a **public** repository on GitHub. For example, name it `xd-game`.
2. Upload `web_upload.zip` to the repository root and commit it to the `main` branch.
3. In the repository, open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**.
4. Create a new file with the name `.github/workflows/deploy-pages.yml`. Copy its contents from the `deploy-pages.yml` file in this folder, then commit it to `main`.
5. Open the **Actions** tab and wait for **Deploy browser game to GitHub Pages** to finish.
6. The workflow run will show your public game URL. It will look like `https://YOUR-USERNAME.github.io/REPOSITORY/`.

The browser game is the current bot game; the package does not add network multiplayer. The Dust II model's required attribution is included in the game project's `assets/dust2/MODEL_CREDITS.md` (also retained in the source project).
