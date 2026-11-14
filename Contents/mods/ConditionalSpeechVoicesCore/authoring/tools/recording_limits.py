"""Authoring limits, not claims about the game engine."""
import re
MAX_CAPTION = 240
MAX_SECONDS = 20

def steam_profile(value):
    if not isinstance(value, str): raise ValueError("Steam profile must be a URL")
    value = value.strip()
    if value:
        if not re.fullmatch(r"https://steamcommunity\.com/(?:id/[A-Za-z0-9_-]+|profiles/[0-9]{17})/?", value):
            raise ValueError("Use https://steamcommunity.com/id/name or /profiles/ followed by a 17-digit Steam ID")
    return value
