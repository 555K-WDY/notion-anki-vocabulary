#!/usr/bin/env python3
import argparse
import base64
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class State:
    def __init__(self, path: Path):
        self.path = path
        self.decks = []
        self.models = {}
        self.notes = {}
        self.media = {}
        self.next_note_id = 1000
        self.save()

    def save(self):
        self.path.write_text(
            json.dumps(
                {
                    "decks": self.decks,
                    "models": self.models,
                    "notes": self.notes,
                    "media_names": sorted(self.media),
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )


def result(value=None, error=None):
    return {"result": value, "error": error}


class Handler(BaseHTTPRequestHandler):
    server_version = "MockAnkiConnect/1.0"

    def log_message(self, *_args):
        return

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        action = payload.get("action")
        params = payload.get("params") or {}
        state = self.server.state
        try:
            response = self.dispatch(state, action, params)
            state.save()
        except Exception as exc:  # pragma: no cover - exercised as API error output
            response = result(None, str(exc))
        body = json.dumps(response, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    @staticmethod
    def dispatch(state, action, params):
        if action == "version":
            return result(6)
        if action == "deckNames":
            return result(state.decks)
        if action == "createDeck":
            deck = params["deck"]
            if deck not in state.decks:
                state.decks.append(deck)
            return result(len(state.decks))
        if action == "modelNames":
            return result(list(state.models))
        if action == "createModel":
            name = params["modelName"]
            state.models[name] = {
                "fields": params["inOrderFields"],
                "templates": params.get("cardTemplates", []),
            }
            return result({"id": len(state.models), "name": name})
        if action == "modelFieldNames":
            return result(state.models[params["modelName"]]["fields"])
        if action == "findNotes":
            query = params.get("query", "")
            deck = query.split('deck:"', 1)[1].split('"', 1)[0] if 'deck:"' in query else None
            ids = [int(note_id) for note_id, note in state.notes.items() if deck is None or note["deckName"] == deck]
            return result(ids)
        if action == "notesInfo":
            notes = []
            for note_id in params["notes"]:
                note = state.notes[str(note_id)]
                notes.append(
                    {
                        "noteId": int(note_id),
                        "fields": {key: {"value": value, "order": index} for index, (key, value) in enumerate(note["fields"].items())},
                        "tags": note["tags"],
                    }
                )
            return result(notes)
        if action == "storeMediaFile":
            name = params["filename"]
            base64.b64decode(params["data"], validate=True)
            state.media[name] = True
            return result(name)
        if action == "getMediaFilesNames":
            pattern = params.get("pattern", "")
            return result([name for name in state.media if name == pattern])
        if action == "addNote":
            note = params["note"]
            state.next_note_id += 1
            note_id = state.next_note_id
            state.notes[str(note_id)] = {
                "deckName": note["deckName"],
                "modelName": note["modelName"],
                "fields": note["fields"],
                "tags": note.get("tags", []),
            }
            return result(note_id)
        if action == "updateNoteFields":
            note = params["note"]
            state.notes[str(note["id"])]["fields"].update(note["fields"])
            return result(None)
        if action == "addTags":
            tags = params["tags"].split()
            for note_id in params["notes"]:
                current = state.notes[str(note_id)]["tags"]
                state.notes[str(note_id)]["tags"] = sorted(set(current + tags))
            return result(None)
        if action == "sync":
            return result(None)
        raise RuntimeError(f"Unsupported mock action: {action}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.state = State(args.state)
    server.serve_forever()


if __name__ == "__main__":
    main()
