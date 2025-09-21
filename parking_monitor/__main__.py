"""Command line entry point for the web application."""

from .webapp import main

if __name__ == "__main__":  # pragma: no cover - CLI entry point
    raise SystemExit(main())
