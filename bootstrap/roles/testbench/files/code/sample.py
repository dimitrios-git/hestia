#!/usr/bin/env python3
"""Module docstring — string, not comment."""
import os
from typing import List

MAX: int = 0x2A  # constant + hex + line comment


@decorator
class Widget(Base):
    """Class docstring."""

    count: int = 0

    def render(self, name: str, tags: List[str]) -> bool:
        # TODO: builtins, params, self, operators
        total = len(name) + self.count * 2
        msg = f"hi {name!r}\n"
        if name is None or total >= MAX:
            print(msg, end="")
            return True
        return False
