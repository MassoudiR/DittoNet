import os
import json
import time
import requests
from urllib.parse import urlparse
from collections import OrderedDict
from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO

from .database import Database
from .engine import InterceptEngine

class DittoServer:
    def __init__(self, port=5000, db_path="rules.db", max_logs=1000):
        self.port = port
        self.max_logs = max_logs
        
        # Determine paths for templates and static files relative to this file
        base_dir = os.path.dirname(os.path.abspath(__file__))
        template_dir = os.path.join(base_dir, 'templates')
        static_dir = os.path.join(base_dir, 'static')
        self.mobile_workspace_path = os.path.join(base_dir, 'mobile_workspace.json')
        
        self.app = Flask(__name__, template_folder=template_dir, static_folder=static_dir)
        # Let Flask-SocketIO auto-detect the best available async mode
        self.socketio = SocketIO(self.app, cors_allowed_origins="*")
        
        self.db = Database(db_path)
        self.plugins = {}
        self.inspectors = []
        self.engine = InterceptEngine(self.db, self.plugins, self.inspectors)
        
        # In-memory log cache (rolling window)
        self.active_logs = OrderedDict()
        
        self._setup_routes()

    def plugin(self, name):
        def decorator(func):
            self.plugins[name] = func
            return func
        return decorator

    def inspector(self, pattern, method="ANY", phase="Both"):
        def decorator(func):
            self.inspectors.append({
                "pattern": pattern,
                "method": method,
                "phase": phase,
                "func": func
            })
            return func
        return decorator

    def _add_log(self, flow_id, log_data):
        self.active_logs[flow_id] = log_data
        if len(self.active_logs) > self.max_logs:
            self.active_logs.popitem(last=False)

    def _setup_routes(self):
        app = self.app

        @app.route("/")
        def index():
            return render_template("index.html")

        @app.route("/docs")
        def docs():
            return render_template("docs.html")

        @app.route("/mobile-workspace")
        def mobile_workspace():
            return render_template("mobile_workspace.html")

        @app.route("/api/sync/workspace", methods=["GET", "POST"])
        def sync_mobile_workspace():
            if request.method == "GET":
                if not os.path.exists(self.mobile_workspace_path):
                    default_workspace = {
                        "timestamp": int(time.time() * 1000),
                        "local_rules": [],
                        "js_hooks": []
                    }
                    try:
                        with open(self.mobile_workspace_path, "w", encoding="utf-8") as f:
                            json.dump(default_workspace, f, indent=2)
                    except Exception as e:
                        print(f"[!] Failed to create default mobile workspace: {e}")
                    return jsonify(default_workspace)
                
                try:
                    with open(self.mobile_workspace_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    return jsonify(data)
                except Exception as e:
                    return jsonify({"error": f"Failed to read workspace: {str(e)}"}), 500

            elif request.method == "POST":
                payload = request.json or {}
                required_keys = {"timestamp", "local_rules", "js_hooks"}
                if not required_keys.issubset(payload.keys()):
                    return jsonify({"error": f"Invalid schema. Must contain keys: {required_keys}"}), 400
                
                try:
                    with open(self.mobile_workspace_path, "w", encoding="utf-8") as f:
                        json.dump(payload, f, indent=2)
                    return jsonify({"status": "SUCCESS"})
                except Exception as e:
                    return jsonify({"error": f"Failed to save workspace: {str(e)}"}), 500

        @app.route("/api/health", methods=["GET"])
        def health_check():
            active_rules_count = len(self.db.get_active_rules())
            return jsonify({
                "status": "ok",
                "version": "1.0",
                "active_rules": active_rules_count
            })


        @app.route("/api/intercept/request", methods=["POST"])
        def intercept_request():
            payload = request.json or {}
            flow_id = payload.get("flowId")
            
            # 1. Evaluate rules
            result = self.engine.process_request(payload)
            
            # 2. Log it — use MODIFIED headers/body from result, not raw payload
            if flow_id:
                log_entry = {
                    "flowId": flow_id,
                    "url": payload.get("url"),
                    "method": payload.get("method"),
                    "requestHeaders": result.get("headers", payload.get("headers", {})),
                    "requestBody": result.get("body", payload.get("body", "")),
                    "modified": result.get("modified", False),
                    "action": result.get("action", "ALLOW"),
                    "timestamp": "now"
                }
                self._add_log(flow_id, log_entry)
                self.socketio.emit("new_request", log_entry)
                
            return jsonify(result)

        @app.route("/api/intercept/response", methods=["POST"])
        def intercept_response():
            payload = request.json or {}
            flow_id = payload.get("flowId")
            
            # 1. Evaluate rules
            result = self.engine.process_response(payload)
            
            # 2. Update existing log — use MODIFIED headers/body from result
            if flow_id and flow_id in self.active_logs:
                log_entry = self.active_logs[flow_id]
                log_entry["statusCode"] = payload.get("statusCode")
                log_entry["responseHeaders"] = result.get("headers", payload.get("headers", {}))
                log_entry["responseBody"] = result.get("body", payload.get("body", ""))
                
                # If modified in response phase, update flag
                if result.get("modified"):
                    log_entry["modified"] = True
                    log_entry["action"] = result.get("action", "MODIFIED")
                    
                self.socketio.emit("update_response", log_entry)
                
            # Ensure action is always present in result
            if "action" not in result:
                result["action"] = "ALLOW"
                
            return jsonify(result)

        @app.route("/api/replay", methods=["POST"])
        def replay_request():
            data = request.json or {}
            url = data.get("url")
            method = data.get("method", "GET").upper()
            headers = data.get("headers", {})
            body = data.get("body", "")
            
            if not url:
                return jsonify({"error": "URL is required"}), 400
                
            # STRIP Host and Content-Length to avoid CORS/Proxy errors
            headers_to_remove = ["host", "content-length"]
            clean_headers = {k: v for k, v in headers.items() if k.lower() not in headers_to_remove}
            
            # Requests will dynamically calculate them
            try:
                # Dispatch the real request
                resp = requests.request(
                    method=method,
                    url=url,
                    headers=clean_headers,
                    data=body if body else None,
                    timeout=10
                )
                
                return jsonify({
                    "statusCode": resp.status_code,
                    "headers": dict(resp.headers),
                    "body": resp.text
                })
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        # --- Dashboard CRUD Routes ---
        @app.route("/api/logs", methods=["GET"])
        def get_logs():
            # Return last N logs for dashboard init
            return jsonify(list(self.active_logs.values()))

        @app.route("/api/rules", methods=["GET", "POST"])
        def manage_rules():
            if request.method == "GET":
                return jsonify(self.db.get_all_rules())
            elif request.method == "POST":
                new_rule = self.db.create_rule(request.json)
                return jsonify(new_rule), 201

        @app.route("/api/rules/<rule_id>", methods=["PUT", "DELETE"])
        def manage_rule(rule_id):
            if request.method == "PUT":
                updated_rule = self.db.update_rule(rule_id, request.json)
                return jsonify(updated_rule)
            elif request.method == "DELETE":
                self.db.delete_rule(rule_id)
                return '', 204

        @app.route("/api/plugins", methods=["GET"])
        def get_plugins():
            return jsonify(list(self.plugins.keys()))

    def run(self):
        # Starts the Flask-SocketIO server
        self.socketio.run(self.app, host="0.0.0.0", port=self.port, debug=True, use_reloader=False )
