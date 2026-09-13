import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    state_path = None

    def do_POST(self):
        length = int(self.headers.get("content-length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        with open(self.state_path, "w", encoding="utf-8") as handle:
            json.dump({"path": self.path, "request": payload}, handle)
        response = {
            "id": "resp_test",
            "status": "completed",
            "error": None,
            "output": [{
                "type": "message",
                "content": [{
                    "type": "output_text",
                    "text": json.dumps({
                        "source_summary": "一页课堂英语笔记。",
                        "items": [{
                            "raw_text": "look up = 查",
                            "term": "look up",
                            "inferred_meaning": "查找信息",
                            "suggested_definition": "to search for information",
                            "suggested_example": "I looked up the word.",
                            "chinese_hint": "查词典",
                            "scenario": "阅读时遇到生词",
                            "correction_reason": "根据中文批注补全短语",
                            "uncertainty": "",
                            "confidence": 0.91
                        }]
                    }, ensure_ascii=False)
                }]
            }]
        }
        encoded = json.dumps(response, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, *_):
        return


parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, required=True)
parser.add_argument("--state", required=True)
args = parser.parse_args()
Handler.state_path = args.state
HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
