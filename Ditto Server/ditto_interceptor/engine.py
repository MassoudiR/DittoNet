import re
import json
import ast

class InterceptEngine:
    def __init__(self, db, plugins=None, inspectors=None):
        self.db = db
        self.plugins = plugins if plugins is not None else {}
        self.inspectors = inspectors if inspectors is not None else []

    def _match_pattern(self, pattern, url):
        if not pattern:
            return True
        regex_pattern = pattern.replace("*", ".*")
        try:
            return re.search(regex_pattern, url) is not None
        except re.error:
            return pattern in url

    def _get_matching_rules(self, url, method, phase):
        matched = []
        rules = self.db.get_active_rules()
        for rule in rules:
            if rule['phase'] not in (phase, 'Both'):
                continue
            rule_method = rule.get('method', 'ANY')
            if rule_method not in ('ANY', '*') and method not in ('ANY', '*'):
                if method != rule_method:
                    continue
            if self._match_pattern(rule['targetPattern'], url):
                print(f"[*] Rule matched: pattern='{rule['targetPattern']}' method='{rule_method}' phase='{rule['phase']}' action='{rule['actionType']}'")
                matched.append(rule)
        return matched

    def _apply_match_replace(self, body, match_str, replace_str):
        if not match_str or not body:
            return body
            
        match_str = match_str.replace('\r\n', '\n')
            
        if isinstance(body, str):
            body = body.replace('\r\n', '\n')
            result = body.replace(match_str, replace_str)
            if result != body:
                print(f"[*] MATCH_REPLACE success: found '{match_str[:40]}' and replaced.")
            else:
                print(f"[!] MATCH_REPLACE: pattern NOT found in body.")
            return result
            
        try:
            body_str = json.dumps(body)
            body_str = body_str.replace('\r\n', '\n')
            body_str = body_str.replace(match_str, replace_str)
            return json.loads(body_str)
        except Exception:
            if isinstance(body, dict):
                body_str = json.dumps(body).replace('\r\n', '\n')
            else:
                body_str = str(body).replace('\r\n', '\n')
            return body_str.replace(match_str, replace_str)

    def _execute_plugin(self, plugin_name, flow_id, phase, headers, body):
        print(f"[*] Engine looking for '{plugin_name}'. Available Plugins: {list(self.plugins.keys())}")
        if plugin_name not in self.plugins:
            print(f"[!] Plugin '{plugin_name}' not found in Engine registry!")
            return False, headers, body

        plugin_func = self.plugins[plugin_name]
        
        try:
            new_headers, new_body = plugin_func(flow_id, phase, headers, body)
            return True, new_headers, new_body
        except Exception as e:
            print(f"[!] Plugin execution failed: {e}")
            return False, headers, body

    def process_request(self, payload):
        url = payload.get("url", "")
        method = payload.get("method", "")
        headers = dict(payload.get("headers", {}) or {})
        body = payload.get("body", "")
        flow_id = payload.get("flowId")
        
        body_len = len(str(body)) if body is not None else 0
        print(f"[DEBUG] Processing Phase: Request | URL: {url} | Body Length: {body_len}")
        
        modified = False
        applied_actions = []

        # Apply Programmatic Inspectors First
        for insp in self.inspectors:
            if insp['phase'] not in ('Request', 'Both'): continue
            if insp['method'] not in ('ANY', '*') and method not in ('ANY', '*'):
                if method != insp['method']: continue
            if self._match_pattern(insp['pattern'], url):
                print(f"[*] Applying Inspector to URL: {url}")
                try:
                    old_headers = headers.copy()
                    old_body = body
                    result = insp['func'](flow_id, "Request", headers, body)
                    if result and isinstance(result, tuple) and len(result) == 2:
                        new_headers, new_body = result
                        if new_headers != old_headers or new_body != old_body:
                            headers = new_headers
                            body = new_body
                            modified = True
                            applied_actions.append("MODIFIED")
                        else:
                            headers = new_headers
                            body = new_body
                except Exception as e:
                    print(f"[!] Inspector failed: {e}")

        rules = self._get_matching_rules(url, method, "Request")

        if not rules:
            return {"modified": modified, "action": "MODIFIED" if modified else "ALLOW", "headers": headers, "body": body}
            
        is_json_body = False
        content_type = next((v for k, v in headers.items() if k.lower() == 'content-type'), '')
        if 'application/json' in content_type and isinstance(body, str):
            try:
                body = json.loads(body)
                is_json_body = True
            except Exception:
                pass
        elif isinstance(body, dict):
            is_json_body = True

        for rule in rules:
            action = rule.get("actionType", "ALLOW")
            applied_actions.append(action)
            print(f"[*] Applying Rule: {action} to URL: {url}")

            if action == "BLOCK":
                return {"modified": True, "action": "BLOCK", "headers": headers, "body": body}
            
            elif action == "REDIRECT":
                return {"modified": True, "action": "REDIRECT", "headers": headers, "body": body, "redirectUrl": rule.get("replaceStr", "")}

            elif action == "MATCH_REPLACE":
                new_body = self._apply_match_replace(body, rule.get("matchStr"), rule.get("replaceStr"))
                if new_body != body:
                    modified = True
                    body = new_body

            elif action == "EXECUTE_PLUGIN":
                plugin_name = rule.get("pluginName")
                if plugin_name:
                    success, new_headers, new_body = self._execute_plugin(plugin_name, flow_id, "Request", headers, body)
                    if success:
                        modified = True
                        headers = new_headers
                        body = new_body

            elif action == "HEADER_INJECT":
                inject_str = rule.get("matchStr", "")
                if ":" in inject_str:
                    k, v = inject_str.split(":", 1)
                    headers[k.strip()] = v.strip()
                    modified = True

            elif action == "BODY_REPLACE":
                new_body_str = rule.get("replaceStr", "")
                if is_json_body:
                    try:
                        body = json.loads(new_body_str)
                        modified = True
                    except Exception:
                        try:
                            parsed_dict = ast.literal_eval(new_body_str)
                            if isinstance(parsed_dict, dict):
                                body = parsed_dict
                                modified = True
                            else:
                                body = new_body_str
                                modified = True
                        except Exception:
                            body = new_body_str
                            modified = True
                else:
                    body = new_body_str
                    modified = True

        if is_json_body and isinstance(body, dict):
            try:
                body = json.dumps(body)
            except Exception:
                pass

        if "BLOCK" in applied_actions: final_action = "BLOCK"
        elif "REDIRECT" in applied_actions: final_action = "REDIRECT"
        elif "EXECUTE_PLUGIN" in applied_actions: final_action = "EXECUTE_PLUGIN"
        elif "BODY_REPLACE" in applied_actions: final_action = "BODY_REPLACE"
        elif "MATCH_REPLACE" in applied_actions: final_action = "MATCH_REPLACE"
        elif "HEADER_INJECT" in applied_actions: final_action = "HEADER_INJECT"
        else: final_action = applied_actions[0] if applied_actions else "ALLOW"

        return {"modified": modified, "action": final_action, "headers": headers, "body": body}

    def process_response(self, payload):
        url = payload.get("url", "")
        method = payload.get("method", "")
        headers = dict(payload.get("headers", {}) or {})
        body = payload.get("body", "")
        flow_id = payload.get("flowId")
        
        body_len = len(str(body)) if body is not None else 0
        print(f"[DEBUG] Processing Phase: Response | URL: {url} | Body Length: {body_len}")
        
        modified = False
        applied_actions = []

        # Apply Programmatic Inspectors First
        for insp in self.inspectors:
            if insp['phase'] not in ('Response', 'Both'): continue
            if insp['method'] not in ('ANY', '*') and method not in ('ANY', '*'):
                if method != insp['method']: continue
            if self._match_pattern(insp['pattern'], url):
                print(f"[*] Applying Inspector to URL: {url}")
                try:
                    old_headers = headers.copy()
                    old_body = body
                    result = insp['func'](flow_id, "Response", headers, body)
                    if result and isinstance(result, tuple) and len(result) == 2:
                        new_headers, new_body = result
                        if new_headers != old_headers or new_body != old_body:
                            headers = new_headers
                            body = new_body
                            modified = True
                            applied_actions.append("MODIFIED")
                        else:
                            headers = new_headers
                            body = new_body
                except Exception as e:
                    print(f"[!] Inspector failed: {e}")

        rules = self._get_matching_rules(url, method if method else 'ANY', "Response")

        if not rules:
            return {"modified": modified, "headers": headers, "body": body, "action": "MODIFIED" if modified else "ALLOW"}

        is_json_body = False
        content_type = next((v for k, v in headers.items() if k.lower() == 'content-type'), '')
        if 'application/json' in content_type and isinstance(body, str):
            try:
                body = json.loads(body)
                is_json_body = True
            except Exception:
                pass
        elif isinstance(body, dict):
            is_json_body = True

        for rule in rules:
            action = rule.get("actionType", "ALLOW")
            applied_actions.append(action)
            print(f"[*] Applying Rule: {action} to URL: {url}")

            if action == "BLOCK":
                return {"modified": True, "action": "BLOCK", "headers": headers, "body": body}

            elif action == "REDIRECT":
                return {"modified": True, "action": "REDIRECT", "headers": headers, "body": body, "redirectUrl": rule.get("replaceStr", "")}

            elif action == "MATCH_REPLACE":
                new_body = self._apply_match_replace(body, rule.get("matchStr"), rule.get("replaceStr"))
                if new_body != body:
                    modified = True
                    body = new_body

            elif action == "EXECUTE_PLUGIN":
                plugin_name = rule.get("pluginName")
                if plugin_name:
                    success, new_headers, new_body = self._execute_plugin(plugin_name, flow_id, "Response", headers, body)
                    if success:
                        modified = True
                        headers = new_headers
                        body = new_body

            elif action == "HEADER_INJECT":
                inject_str = rule.get("matchStr", "")
                if ":" in inject_str:
                    k, v = inject_str.split(":", 1)
                    headers[k.strip()] = v.strip()
                    modified = True
                    
            elif action == "BODY_REPLACE":
                new_body_str = rule.get("replaceStr", "")
                if is_json_body:
                    try:
                        body = json.loads(new_body_str)
                        modified = True
                    except Exception:
                        try:
                            parsed_dict = ast.literal_eval(new_body_str)
                            if isinstance(parsed_dict, dict):
                                body = parsed_dict
                                modified = True
                            else:
                                body = new_body_str
                                modified = True
                        except Exception:
                            body = new_body_str
                            modified = True
                else:
                    body = new_body_str
                    modified = True

        if is_json_body and isinstance(body, dict):
            try:
                body = json.dumps(body)
            except Exception:
                pass

        if "BLOCK" in applied_actions: final_action = "BLOCK"
        elif "REDIRECT" in applied_actions: final_action = "REDIRECT"
        elif "EXECUTE_PLUGIN" in applied_actions: final_action = "EXECUTE_PLUGIN"
        elif "BODY_REPLACE" in applied_actions: final_action = "BODY_REPLACE"
        elif "MATCH_REPLACE" in applied_actions: final_action = "MATCH_REPLACE"
        elif "HEADER_INJECT" in applied_actions: final_action = "HEADER_INJECT"
        else: final_action = applied_actions[0] if applied_actions else "ALLOW"

        return {"modified": modified, "action": final_action, "headers": headers, "body": body}
