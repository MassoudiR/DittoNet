import sqlite3
import json
import uuid

class Database:
    def __init__(self, db_path="rules.db"):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS rules (
                    id TEXT PRIMARY KEY,
                    targetPattern TEXT NOT NULL,
                    method TEXT NOT NULL,
                    phase TEXT NOT NULL,
                    actionType TEXT NOT NULL,
                    matchStr TEXT,
                    replaceStr TEXT,
                    pluginName TEXT,
                    isActive INTEGER DEFAULT 1
                )
            ''')
            conn.commit()
            
            try:
                cursor.execute("ALTER TABLE rules ADD COLUMN pluginName TEXT")
                conn.commit()
            except sqlite3.OperationalError:
                pass

    def get_all_rules(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rules")
            rows = cursor.fetchall()
            return [dict(row) for row in rows]

    def get_active_rules(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rules WHERE isActive = 1")
            rows = cursor.fetchall()
            return [dict(row) for row in rows]

    def get_rule(self, rule_id):
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rules WHERE id = ?", (rule_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    def create_rule(self, rule_data):
        rule_id = str(uuid.uuid4())
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO rules (id, targetPattern, method, phase, actionType, matchStr, replaceStr, pluginName, isActive)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                rule_id,
                rule_data.get("targetPattern", "*"),
                rule_data.get("method", "ANY"),
                rule_data.get("phase", "Both"),
                rule_data.get("actionType", "ALLOW"),
                rule_data.get("matchStr", ""),
                rule_data.get("replaceStr", ""),
                rule_data.get("pluginName", ""),
                1 if rule_data.get("isActive", True) else 0
            ))
            conn.commit()
        return self.get_rule(rule_id)

    def update_rule(self, rule_id, rule_data):
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE rules
                SET targetPattern = ?, method = ?, phase = ?, actionType = ?, matchStr = ?, replaceStr = ?, pluginName = ?, isActive = ?
                WHERE id = ?
            ''', (
                rule_data.get("targetPattern", "*"),
                rule_data.get("method", "ANY"),
                rule_data.get("phase", "Both"),
                rule_data.get("actionType", "ALLOW"),
                rule_data.get("matchStr", ""),
                rule_data.get("replaceStr", ""),
                rule_data.get("pluginName", ""),
                1 if rule_data.get("isActive", True) else 0,
                rule_id
            ))
            conn.commit()
        return self.get_rule(rule_id)

    def delete_rule(self, rule_id):
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM rules WHERE id = ?", (rule_id,))
            conn.commit()
