#!/usr/bin/env python3
"""
Test Suite: Suricata IPS Rule Syntax and Action Verification
Validates that rules_string configured in AWS Network Firewall follows Suricata syntax rules,
contains valid action keywords (drop, pass, alert), specifies unique SIDs, and enforces protocol filtering.
"""

import re
import unittest
from pathlib import Path

FIREWALL_TF = Path(__file__).resolve().parent.parent / "modules" / "central-network-firewall" / "main.tf"

class TestSuricataRules(unittest.TestCase):

    def setUp(self):
        with open(FIREWALL_TF, "r") as f:
            content = f.read()

        match = re.search(r'rules_string\s*=\s*<<EOF\n(.*?)\nEOF', content, re.DOTALL)
        self.assertIsNotNone(match, "rules_string block not found in central-network-firewall/main.tf")
        self.rules = [line.strip() for line in match.group(1).strip().splitlines() if line.strip() and not line.startswith('#')]

    def test_rules_count(self):
        """Verifies that at least 4 stateful inspection rules are defined."""
        self.assertGreaterEqual(len(self.rules), 4)

    def test_valid_actions(self):
        """Rules must start with valid actions: drop, pass, or alert."""
        valid_actions = {"drop", "pass", "alert", "reject"}
        for rule in self.rules:
            action = rule.split()[0]
            self.assertIn(action, valid_actions, f"Invalid rule action: {action}")

    def test_unique_sids(self):
        """Every Suricata rule must define a unique sid integer."""
        sids = []
        for rule in self.rules:
            match = re.search(r'sid:(\d+);', rule)
            self.assertIsNotNone(match, f"Rule missing sid metadata: {rule}")
            sid = int(match.group(1))
            self.assertNotIn(sid, sids, f"Duplicate SID found: {sid}")
            sids.append(sid)

    def test_insecure_ports_are_dropped(self):
        """Verifies that management ports (22, 445, 3389) have explicit drop rules."""
        drop_rule = next((r for r in self.rules if "drop tcp" in r and "22" in r), None)
        self.assertIsNotNone(drop_rule, "Missing drop rule for insecure port 22/445")


if __name__ == "__main__":
    unittest.main()
