#!/usr/bin/env python3
"""Builds HollowSignal.rbxlx (a Roblox XML place file) straight from src/, for
anyone who does not have Rojo installed. Mirrors default.project.json.

    python3 tools/build_place.py            # writes HollowSignal.rbxlx

`rojo build -o HollowSignal.rbxl` produces the same tree and is the supported route."""
import os, sys
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "src")
counter = 0

def ref():
    global counter
    counter += 1
    return f"RBX{counter:08X}"

def prop(kind, name, value):
    return f'<{kind} name="{name}">{value}</{kind}>'

def item(cls, name, props=(), children=()):
    body = "".join([prop("string", "Name", escape(name)), *props])
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{body}</Properties>{"".join(children)}</Item>'

def source(text):
    # CDATA cannot contain "]]>", so split it across two sections if it ever appears
    return '<ProtectedString name="Source"><![CDATA[' + text.replace("]]>", "]]]]><![CDATA[>") + "]]></ProtectedString>"

def tree(directory):
    """Folders become Folder instances; *.server.luau -> Script, *.client.luau -> LocalScript, *.luau -> ModuleScript."""
    out = []
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            out.append(item("Folder", entry, children=tree(path)))
        elif entry.endswith(".luau"):
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
            if entry.endswith(".server.luau"):
                out.append(item("Script", entry[: -len(".server.luau")], [source(text)]))
            elif entry.endswith(".client.luau"):
                out.append(item("LocalScript", entry[: -len(".client.luau")], [source(text)]))
            else:
                out.append(item("ModuleScript", entry[: -len(".luau")], [source(text)]))
    return out

def build():
    services = [
        item("Workspace", "Workspace", [prop("bool", "StreamingEnabled", "false")]),
        item("ReplicatedStorage", "ReplicatedStorage", children=[item("Folder", "Shared", children=tree(os.path.join(SRC, "shared")))]),
        item("ServerScriptService", "ServerScriptService", children=[item("Folder", "Server", children=tree(os.path.join(SRC, "server")))]),
        item("StarterPlayer", "StarterPlayer", [
            prop("float", "CameraMaxZoomDistance", "12"), prop("float", "CameraMinZoomDistance", "0.5"),
            prop("float", "CharacterWalkSpeed", "12"), prop("float", "CharacterJumpHeight", "0"),
            prop("bool", "CharacterUseJumpPower", "false"), prop("float", "NameDisplayDistance", "0"),
            prop("float", "HealthDisplayDistance", "0"),
        ], [item("StarterPlayerScripts", "StarterPlayerScripts", children=[item("Folder", "Client", children=tree(os.path.join(SRC, "client")))])]),
        item("Lighting", "Lighting"),
        item("SoundService", "SoundService", [prop("bool", "RespectFilteringEnabled", "true")]),
    ]
    header = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    return header + "".join(services) + "</roblox>\n"

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "HollowSignal.rbxlx")
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(build())
    print(f"wrote {os.path.relpath(out)} ({os.path.getsize(out) // 1024} KB, {counter} instances)")
