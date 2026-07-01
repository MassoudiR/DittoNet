import os
import json
from ditto_interceptor.database import Database
from ditto_interceptor.engine import InterceptEngine

def run_tests():
    print("[*] Running DittoNet V1 Tests...")
    
    # 1. DB setup
    if os.path.exists("test_rules.db"):
        os.remove("test_rules.db")
    
    db = Database("test_rules.db")
    
    # 2. Setup Plugin
    plugins = {}
    def my_plugin(flow_id, phase, headers, body_json):
        if phase == "Request":
            body_json["injected"] = "yes"
        return headers, body_json
    plugins["Test_Plugin"] = my_plugin
    
    engine = InterceptEngine(db, plugins)
    
    # 3. Create Rule
    rule_data = {
        "targetPattern": "*api.example.com*",
        "method": "POST",
        "phase": "Both",
        "actionType": "EXECUTE_PLUGIN",
        "pluginName": "Test_Plugin",
        "isActive": True
    }
    created_rule = db.create_rule(rule_data)
    print(f"[*] Created Rule: {created_rule['id']}")
    
    # 4. Test Request Interception
    req_payload = {
        "flowId": "1234",
        "url": "https://api.example.com/login",
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": '{"token": "old_token", "user": "admin"}'
    }
    
    res = engine.process_request(req_payload)
    print(f"[*] Request Intercept Result: modified={res['modified']}")
    assert res['modified'] == True
    assert '"injected": "yes"' in res['body']
    
    # 4. Test Response Interception
    resp_payload = {
        "flowId": "1234",
        "url": "https://api.example.com/login",
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": '{"auth_token": "old_token"}'
    }
    
    res_resp = engine.process_response(resp_payload)
    print(f"[*] Response Intercept Result: modified={res_resp['modified']}")
    assert res_resp['modified'] == True
    
    # 5. Test HEADER_INJECT
    header_rule_data = {
        "targetPattern": "*",
        "method": "ANY",
        "phase": "Both",
        "actionType": "HEADER_INJECT",
        "matchStr": "X-Injected-Header: 12345",
        "isActive": True
    }
    db.create_rule(header_rule_data)
    
    req_payload2 = {
        "flowId": "1235",
        "url": "https://api.example.com/test",
        "method": "GET",
        "headers": {"Content-Type": "text/html"},
        "body": "Hello World"
    }
    res_header = engine.process_request(req_payload2)
    assert res_header["headers"]["X-Injected-Header"] == "12345"
    assert res_header["modified"] == True
    print("[*] HEADER_INJECT Result: SUCCESS")
    
    print("[+] All Engine Tests Passed!")

if __name__ == '__main__':
    run_tests()
