"""Checks the place Rojo builds, using the sourcemap (every instance with its class and source file).

1. Every string require in our code ("./X", "../X", "@self/X", "@game/Service/...") resolves to an
   instance that exists in the built place. Roblox's rules: "./" and "../" start from the requiring
   script's parent, "@self" from the script itself, "@game" from the DataModel.
2. Exactly one server Script and one client LocalScript (the game boots from main.server/main.client).
3. No classes that break automated publishing or the art bible (unions, SurfaceAppearance, ...).

Run: rojo sourcemap default.project.json -o sourcemap.json && python3 -I tools/place_lint.py
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BANNED = {"UnionOperation", "NegateOperation", "SurfaceAppearance", "PackageLink"}
REQUIRE = re.compile(r'require\("([^"]+)"\)')
SCRIPT_EXT = (".luau", ".lua")


class Node:
    def __init__(self, data, parent):
        self.name = data["name"]
        self.cls = data["className"]
        self.files = data.get("filePaths", [])
        self.parent = parent
        self.children = [Node(c, self) for c in data.get("children", [])]

    def child(self, name):
        for c in self.children:
            if c.name == name:
                return c
        return None

    def path(self):
        parts, node = [], self
        while node:
            parts.append(node.name)
            node = node.parent
        return ".".join(reversed(parts))

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()


def resolve(script: Node, spec: str, root: Node):
    segments = spec.split("/")
    head = segments[0]
    if head == "@game":
        node, rest = root, segments[1:]
    elif head == "@self":
        node, rest = script, segments[1:]
    elif head in (".", ".."):
        node, rest = script.parent, segments
        if rest[0] == ".":
            rest = rest[1:]
    elif head.startswith("@"):
        return "alias"  # e.g. @frktest, only used by Lune tests
    else:
        return None
    for seg in rest:
        if node is None:
            return None
        if seg == "..":
            node = node.parent
        elif seg in ("", "."):
            continue
        else:
            node = node.child(seg)
    return node


def main() -> None:
    sourcemap = ROOT / "sourcemap.json"
    if not sourcemap.exists():
        sys.exit("sourcemap.json missing: run `rojo sourcemap default.project.json -o sourcemap.json` first")
    root = Node(json.loads(sourcemap.read_text()), None)
    problems = []
    scripts = {"Script": [], "LocalScript": []}

    for node in root.walk():
        if node.cls in BANNED:
            problems.append(f"{node.path()}: banned class {node.cls}")
        if node.cls in scripts:
            scripts[node.cls].append(node.path())
        source = next((f for f in node.files if f.endswith(SCRIPT_EXT)), None)
        if not source or "vendor/" in source.replace("\\", "/"):
            continue
        text = (ROOT / source).read_text()
        for lineno, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("--"):
                continue
            for spec in REQUIRE.findall(line):
                target = resolve(node, spec, root)
                if target is None:
                    problems.append(f'{source}:{lineno}: require("{spec}") does not resolve in the place')

    for cls, expected in (("Script", 1), ("LocalScript", 1)):
        if len(scripts[cls]) != expected:
            problems.append(f"expected {expected} {cls}, found {len(scripts[cls])}: {scripts[cls]}")

    if problems:
        print("\n".join(problems))
        sys.exit(1)
    count = sum(1 for _ in root.walk())
    print(f"Place lint OK ({count} instances)")


if __name__ == "__main__":
    main()
