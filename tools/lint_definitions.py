#!/usr/bin/env python3
"""Validate task-definition files against the Swale platform contract.

Run locally:  python tools/lint_definitions.py
CI runs this on every pull request.
"""
from __future__ import annotations

import glob
import os
import re
import sys

import yaml

NAME_RE = re.compile(r"^[A-Za-z0-9_-]{1,100}$")
IDENT_RE = re.compile(r"^[a-z0-9_]+$")  # snake_case identifiers
DIGEST_RE = re.compile(r"@sha256:[0-9a-f]{64}$")

TOP_KEYS = {"name", "description", "inputs", "outputs", "exec"}
EXEC_KEYS = {"image", "args"}
INPUT_KEYS = {"description", "required", "default"}
OUTPUT_KEYS = {"description"}


def split_frontmatter(text: str):
    if not text.startswith("---"):
        return None, None
    end = text.find("\n---", 3)
    if end == -1:
        return None, None
    fm = text[3:end].lstrip("\n")
    body = text[end + 4 :].lstrip("\n\r")
    return fm, body


def lint_file(path: str) -> list[str]:
    errors: list[str] = []
    rel = os.path.relpath(path).replace("\\", "/")

    parts = rel.split("/")
    if len(parts) != 3 or parts[0] != "tasks" or parts[2] != "task.md":
        errors.append(f"{rel}: must live at tasks/<name>/task.md (versions are git tags '<name>/<version>')")
        return errors
    name = parts[1]

    if not NAME_RE.match(name):
        errors.append(f"{rel}: task name '{name}' must match {NAME_RE.pattern} (no dots)")

    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()

    if len(text.encode("utf-8")) > 1024 * 1024:
        errors.append(f"{rel}: file exceeds 1 MiB")

    fm, body = split_frontmatter(text)
    if fm is None:
        errors.append(f"{rel}: missing YAML frontmatter starting at byte 0")
        return errors
    if not body:
        errors.append(f"{rel}: body must be non-empty")

    try:
        data = yaml.safe_load(fm)
    except yaml.YAMLError as exc:
        errors.append(f"{rel}: frontmatter is not valid YAML: {exc}")
        return errors
    if not isinstance(data, dict):
        errors.append(f"{rel}: frontmatter must be a mapping")
        return errors

    unknown = set(data) - TOP_KEYS
    if unknown:
        errors.append(f"{rel}: unknown top-level keys: {sorted(unknown)}")

    exec_block = data.get("exec")
    if not isinstance(exec_block, dict):
        errors.append(f"{rel}: 'exec' is required and must be a mapping")
    else:
        unknown_exec = set(exec_block) - EXEC_KEYS
        if unknown_exec:
            errors.append(f"{rel}: unknown exec keys: {sorted(unknown_exec)}")
        image = exec_block.get("image")
        if not isinstance(image, str) or not image.strip():
            errors.append(f"{rel}: exec.image is required and must be a non-empty string")
        elif not DIGEST_RE.search(image):
            errors.append(f"{rel}: exec.image must be digest-pinned (…@sha256:<64 hex>): '{image}'")
        args = exec_block.get("args")
        if args is not None and not isinstance(args, list):
            errors.append(f"{rel}: exec.args must be a list of strings")

    for section, allowed in (("inputs", INPUT_KEYS), ("outputs", OUTPUT_KEYS)):
        block = data.get(section)
        if block is None:
            continue
        if not isinstance(block, dict):
            errors.append(f"{rel}: '{section}' must be a mapping")
            continue
        for ident, spec in block.items():
            if not IDENT_RE.match(str(ident)):
                errors.append(f"{rel}: {section} identifier '{ident}' must be snake_case ({IDENT_RE.pattern})")
            if spec is not None and not isinstance(spec, dict):
                errors.append(f"{rel}: {section}.{ident} must be a mapping or empty")
                continue
            if isinstance(spec, dict):
                unknown_field = set(spec) - allowed
                if unknown_field:
                    errors.append(f"{rel}: {section}.{ident} has unknown keys: {sorted(unknown_field)}")

    return errors


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(root, "tasks", "**", "*.md"), recursive=True))
    if not files:
        print("No task definitions found under tasks/.")
        return 0

    all_errors: list[str] = []
    for path in files:
        all_errors.extend(lint_file(path))

    if all_errors:
        for error in all_errors:
            print(f"::error::{error}")
        print(f"\n{len(all_errors)} problem(s) in {len(files)} file(s).")
        return 1

    print(f"OK: {len(files)} task definition(s) valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
