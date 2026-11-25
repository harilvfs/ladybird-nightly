#!/usr/bin/env python3
import argparse
import functools
import http.server
import socket
import sys
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SITE = ROOT / "site"


def find_port(port):
    while port <= 65535:
        with socket.socket() as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("127.0.0.1", port))
            except OSError:
                port += 1
                continue
            return port
    return None


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description="Preview the Ladybird Nightly site locally.")
    parser.add_argument("port", nargs="?", type=int, default=8000)
    parser.add_argument("-n", "--no-open", action="store_true", help="do not open a browser")
    args = parser.parse_args()

    if not SITE.is_dir():
        sys.exit("site/ not found next to serve.py")
    if not 1 <= args.port <= 65535:
        sys.exit("port must be between 1 and 65535")

    port = find_port(args.port)
    if port is None:
        sys.exit(f"no free port above {args.port}")
    if port != args.port:
        print(f"port {args.port} is busy, using {port}", flush=True)

    url = f"http://localhost:{port}"
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", port), functools.partial(Handler, directory=str(SITE))
    )

    print(
        f"\n  Ladybird Nightly preview\n  serving  {SITE}\n  open     {url}\n"
        f"  stop     Ctrl+C\n  refresh  Ctrl+Shift+R if edits do not show\n",
        flush=True,
    )
    if not args.no_open:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
