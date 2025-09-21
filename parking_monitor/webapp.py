"""Simple web app that links to the parking lot search page."""

from __future__ import annotations

import argparse
import logging
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Tuple

_SEARCH_URL = "http://skdtcsf.sdust.edu.cn/pms/carParkMobile/carpayment/search"

INDEX_HTML = """<!DOCTYPE html>
<html lang=\"zh-CN\">
  <head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>停车场车牌快速查询</title>
    <style>
      :root {
        color-scheme: light dark;
        --bg: #f7f7f9;
        --card-bg: #ffffffcc;
        --border: #d0d5dd;
        --accent: #0057ff;
        --accent-dark: #0040c1;
        --text: #222;
        --text-dim: #555;
        --success: #16a34a;
        --error: #dc2626;
      }

      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #0f172a;
          --card-bg: #1e293bcc;
          --border: #334155;
          --accent: #3b82f6;
          --accent-dark: #1d4ed8;
          --text: #f8fafc;
          --text-dim: #cbd5f5;
        }
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          "Helvetica Neue", Arial, "Noto Sans", sans-serif;
        background: var(--bg);
        color: var(--text);
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        align-items: center;
      }

      header {
        width: 100%;
        padding: 24px 16px 8px;
        text-align: center;
      }

      header h1 {
        margin: 0;
        font-size: 1.75rem;
      }

      header p {
        margin: 12px auto 0;
        max-width: 720px;
        font-size: 1rem;
        color: var(--text-dim);
        line-height: 1.6;
      }

      main {
        width: min(960px, 100%);
        padding: 0 16px 40px;
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
        gap: 20px;
      }

      .card {
        background: var(--card-bg);
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 24px;
        box-shadow: 0 10px 30px -18px rgba(15, 23, 42, 0.45);
        backdrop-filter: blur(6px);
      }

      .card h2 {
        margin-top: 0;
        font-size: 1.5rem;
      }

      .card p {
        line-height: 1.6;
        margin-bottom: 18px;
        color: var(--text-dim);
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
      }

      button,
      a.button {
        cursor: pointer;
        border-radius: 999px;
        border: none;
        padding: 12px 22px;
        font-size: 1rem;
        font-weight: 600;
        transition: transform 0.15s ease, box-shadow 0.15s ease,
          background 0.15s ease;
        text-decoration: none;
        display: inline-flex;
        align-items: center;
        justify-content: center;
      }

      button.copy {
        background: var(--accent);
        color: white;
        box-shadow: 0 8px 20px -12px rgba(0, 87, 255, 0.8);
      }

      button.copy:hover,
      button.copy:focus-visible {
        background: var(--accent-dark);
        transform: translateY(-1px);
      }

      a.button {
        background: transparent;
        border: 1px solid var(--border);
        color: var(--text);
      }

      a.button:hover,
      a.button:focus-visible {
        border-color: var(--accent);
        color: var(--accent-dark);
        transform: translateY(-1px);
      }

      .status {
        margin-top: 24px;
        padding: 14px 18px;
        border-radius: 12px;
        border: 1px solid var(--border);
        background: var(--card-bg);
        font-size: 0.95rem;
        color: var(--text-dim);
        transition: opacity 0.3s ease;
      }

      .status.success {
        color: var(--success);
        border-color: color-mix(in srgb, var(--success) 60%, transparent);
      }

      .status.error {
        color: var(--error);
        border-color: color-mix(in srgb, var(--error) 60%, transparent);
      }

      footer {
        margin-top: auto;
        padding: 24px 16px 32px;
        text-align: center;
        font-size: 0.85rem;
        color: var(--text-dim);
      }

      footer a {
        color: inherit;
      }
    </style>
  </head>
  <body>
    <header>
      <h1>停车场车牌快速查询</h1>
      <p>
        点击下方卡片即可复制对应的车牌号，并在新的浏览器页面打开学校停车缴费查询网址
        (<code>skdtcsf.sdust.edu.cn</code>)。
        我们不会替您请求或抓取任何数据，您可在官方页面中自行查询。
      </p>
    </header>
    <main>
      <section class=\"card\">
        <h2>鲁BFF6505</h2>
        <p>复制车牌号并打开官方页面即可立即进行查询。</p>
        <div class=\"actions\">
          <button class=\"copy\" data-plate=\"鲁BFF6505\">复制车牌号</button>
          <a
            class=\"button\"
            href=\"{url}\"
            target=\"_blank\"
            rel=\"noopener noreferrer\"
          >打开查询页面</a>
        </div>
      </section>
      <section class=\"card\">
        <h2>鲁B2290L</h2>
        <p>复制车牌号并打开官方页面即可立即进行查询。</p>
        <div class=\"actions\">
          <button class=\"copy\" data-plate=\"鲁B2290L\">复制车牌号</button>
          <a
            class=\"button\"
            href=\"{url}\"
            target=\"_blank\"
            rel=\"noopener noreferrer\"
          >打开查询页面</a>
        </div>
      </section>
    </main>
    <div id=\"status\" class=\"status\">
      支持通过本地浏览器访问：http://127.0.0.1:8000
    </div>
    <footer>
      提示：若复制失败，请手动选择车牌文本并使用 <kbd>Ctrl</kbd> + <kbd>C</kbd>
      复制。
    </footer>
    <script>
      (function () {
        const statusEl = document.getElementById("status");
        const searchUrl = "{url}";

        function showStatus(message, kind) {
          statusEl.textContent = message;
          statusEl.classList.remove("success", "error");
          if (kind) {
            statusEl.classList.add(kind);
          }
        }

        async function copyPlate(plate) {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(plate);
            return true;
          }

          const textarea = document.createElement("textarea");
          textarea.value = plate;
          textarea.style.position = "fixed";
          textarea.style.opacity = "0";
          document.body.appendChild(textarea);
          textarea.focus();
          textarea.select();
          try {
            const ok = document.execCommand("copy");
            return ok;
          } finally {
            textarea.remove();
          }
        }

        async function handleCopy(event) {
          const button = event.currentTarget;
          const plate = button.dataset.plate || "";
          try {
            const success = await copyPlate(plate);
            if (success) {
              showStatus(`已复制 ${plate} 到剪贴板，点击“打开查询页面”即可粘贴使用。`, "success");
            } else {
              throw new Error("无法复制");
            }
          } catch (error) {
            console.error(error);
            showStatus(`复制失败，请手动复制：${plate}`, "error");
          }
        }

        document
          .querySelectorAll("button.copy")
          .forEach((button) => button.addEventListener("click", handleCopy));

        showStatus(
          "点击“复制车牌号”后再打开查询页面，可直接粘贴到官网进行查询。",
          null,
        );

        window.addEventListener("pageshow", () => {
          if (performance && performance.getEntriesByType) {
            const nav = performance.getEntriesByType("navigation")[0];
            if (nav && nav.type === "back_forward") {
              showStatus(
                "浏览器返回到本页面，可再次复制车牌号或重新打开官网页面。",
                null,
              );
            }
          }
        });
      })();
    </script>
  </body>
</html>
""".format(url=_SEARCH_URL)


class _LandingHandler(BaseHTTPRequestHandler):
    """Serve the static landing page."""

    server_version = "ParkingMonitor/1.0"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path in {"/", "/index.html", ""}:
            body = INDEX_HTML.encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path == "/favicon.ico":
            self.send_response(HTTPStatus.NO_CONTENT)
            self.end_headers()
            return

        self.send_error(HTTPStatus.NOT_FOUND, "Not Found")

    def log_message(self, fmt: str, *args: object) -> None:  # noqa: D401
        """Route access logs through the standard logging module."""

        logging.getLogger("parking_monitor.webapp").info(
            "%s - - %s", self.address_string(), fmt % args
        )


def run_server(host: str = "127.0.0.1", port: int = 8000) -> None:
    """Start the local HTTP server."""

    server_address: Tuple[str, int] = (host, port)
    httpd = ThreadingHTTPServer(server_address, _LandingHandler)
    log = logging.getLogger("parking_monitor.webapp")
    log.info("启动本地服务：http://%s:%s", host, port)
    log.info("官方查询地址：%s", _SEARCH_URL)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        log.info("收到中断信号，正在关闭服务……")
    finally:
        httpd.server_close()
        log.info("服务已关闭。")


def main() -> int:
    """Command-line entry for the web app."""

    parser = argparse.ArgumentParser(
        description="启动本地 Web 页面，用于快速跳转至学校停车查询官网。"
    )
    parser.add_argument("--host", default="127.0.0.1", help="监听地址，默认 127.0.0.1")
    parser.add_argument("--port", type=int, default=8000, help="监听端口，默认 8000")
    parser.add_argument(
        "--log-level",
        default="INFO",
        help="日志等级，例如 INFO、DEBUG。",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    run_server(args.host, args.port)
    return 0


if __name__ == "__main__":  # pragma: no cover - manual execution
    raise SystemExit(main())
