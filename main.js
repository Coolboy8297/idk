const { app, BrowserWindow } = require("electron");
const http = require("http");
const fs = require("fs");
const path = require("path");

let server;

const gameRoot = path.join(__dirname, "games", "new-game");
const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".json": "application/json"
};

function startLocalServer() {
  return new Promise((resolve, reject) => {
    server = http.createServer((req, res) => {
      const requestPath = decodeURIComponent((req.url || "/").split("?")[0]);
      const relativePath = requestPath === "/" ? "Game.html" : requestPath.replace(/^\/+/, "");
      const filePath = path.resolve(gameRoot, relativePath);

      if (!filePath.startsWith(gameRoot + path.sep) && filePath !== path.join(gameRoot, "Game.html")) {
        res.writeHead(403);
        return res.end("Forbidden");
      }

      fs.readFile(filePath, (error, data) => {
        if (error) {
          res.writeHead(error.code === "ENOENT" ? 404 : 500);
          return res.end("Unable to load game file");
        }

        res.writeHead(200, {
          "Content-Type": mimeTypes[path.extname(filePath).toLowerCase()] || "application/octet-stream",
          "Cross-Origin-Opener-Policy": "same-origin",
          "Cross-Origin-Embedder-Policy": "require-corp",
          "Cache-Control": "no-store"
        });
        res.end(data);
      });
    });

    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve(address.port);
    });
  });
}

async function createWindow() {
  const port = await startLocalServer();
  const window = new BrowserWindow({
    width: 1280,
    height: 720,
    minWidth: 800,
    minHeight: 500,
    backgroundColor: "#000000",
    title: "New Game",
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  await window.loadURL(`http://127.0.0.1:${port}/`);
}

app.whenReady().then(createWindow).catch((error) => {
  console.error("Could not start game:", error);
  app.quit();
});

app.on("window-all-closed", () => {
  if (server) server.close();
  app.quit();
});
