"""
DittoNet V1 - Quickstart Deployment Script
==========================================
Run this script to start the DittoServer instance. Access the interactive
dashboard at http://0.0.0.0:5000
"""

from ditto_interceptor import DittoServer

# Initialize the DittoNet Server
server = DittoServer(port=5000, db_path="rules.db")


@server.inspector(pattern="*api*", method="ANY", phase="Both")
def log_api_traffic(flow_id, phase, headers, body):
    """
    Example Inspector:
    Automatically triggers on any traffic matching '*api*'.
    Logs request/response phases and adds a custom header.
    """
    print(f"[*] [Inspector] Flow ID: {flow_id} | Phase: {phase}")
    
    # Example: Inject a custom security/debugging header into responses
    if phase == "Response" and isinstance(headers, dict):
        headers["X-Ditto-Inspected"] = "true"
        
    return headers, body


@server.plugin(name="MockUserCoins")
def mock_user_coins(flow_id, phase, headers, body):
    """
    Example Plugin:
    Can be assigned to specific URLs via the UI Rules Engine.
    Overrides JSON fields in real-time.
    """
    if phase == "Response" and isinstance(body, dict):
        if "coins" in body:
            print(f"[*] [Plugin] Overriding coins for Flow ID: {flow_id}")
            body["coins"] = 999999
            
    return headers, body


if __name__ == "__main__":
    print("==================================================")
    print("🚀 Starting DittoNet V1 Gateway Server...")
    print("📊 Dashboard: http://localhost:5000")
    print("==================================================")
    server.run()