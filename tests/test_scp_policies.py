#!/usr/bin/env python3
"""
Test Suite: Service Control Policy (SCP) Syntax and Guardrail Validation
Ensures all SCP policies adhere to AWS Organizations strict JSON schemas,
mandatory effect rules, sid formatting, and condition key requirements.
"""

import json
import os
import unittest
from pathlib import Path

POLICIES_DIR = Path(__file__).resolve().parent.parent / "modules" / "aws-organizations" / "policies"

REQUIRED_GLOBAL_SERVICES = [
    "iam:*",
    "organizations:*",
    "route53:*",
    "cloudfront:*",
    "sts:*",
    "support:*"
]

class TestServiceControlPolicies(unittest.TestCase):

    def setUp(self):
        self.policy_files = list(POLICIES_DIR.glob("*.json"))
        self.assertTrue(len(self.policy_files) > 0, "No policy files found in policies directory.")

    def test_json_validity_and_syntax(self):
        """Verifies that each policy file is valid JSON with proper Version and Statement keys."""
        for policy_file in self.policy_files:
            with self.subTest(file=policy_file.name):
                with open(policy_file, "r") as f:
                    data = json.load(f)
                self.assertIn("Version", data, f"Missing Version in {policy_file.name}")
                self.assertEqual(data["Version"], "2012-10-17")
                self.assertIn("Statement", data, f"Missing Statement in {policy_file.name}")
                self.assertIsInstance(data["Statement"], list)

    def test_all_statements_are_deny(self):
        """Guardrail SCPs should only contain explicit Deny statements."""
        for policy_file in self.policy_files:
            with open(policy_file, "r") as f:
                data = json.load(f)
            for stmt in data["Statement"]:
                with self.subTest(file=policy_file.name, sid=stmt.get("Sid")):
                    self.assertEqual(stmt.get("Effect"), "Deny", f"Statement in {policy_file.name} must have Effect: Deny")
                    self.assertIn("Sid", stmt, "Statement missing Sid")

    def test_region_restriction_exempts_global_services(self):
        """Verifies that the region lockdown SCP properly exempts critical global AWS services."""
        region_policy_path = POLICIES_DIR / "deny_unauthorized_regions.json"
        with open(region_policy_path, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertIn("NotAction", stmt, "Region restriction must use NotAction to exempt global services")
        not_actions = stmt["NotAction"]

        for service in REQUIRED_GLOBAL_SERVICES:
            self.assertIn(service, not_actions, f"Global service {service} must be in NotAction list")

    def test_root_account_lockdown_policy(self):
        """Verifies that the root account policy matches arn:aws:iam::*:root."""
        root_policy_path = POLICIES_DIR / "deny_root_account_usage.json"
        with open(root_policy_path, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertEqual(stmt["Action"], "*")
        condition = stmt.get("Condition", {})
        principal_arns = condition.get("StringLike", {}).get("aws:PrincipalArn", [])
        self.assertIn("arn:aws:iam::*:root", principal_arns, "Root policy must target arn:aws:iam::*:root")

    def test_prevent_leave_org_statement(self):
        """Verifies that organizations:LeaveOrganization is blocked without bypass."""
        policy_path = POLICIES_DIR / "prevent_leaving_organization.json"
        with open(policy_path, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        actions = stmt.get("Action", [])
        if isinstance(actions, str):
            actions = [actions]
        self.assertIn("organizations:LeaveOrganization", actions)


if __name__ == "__main__":
    unittest.main()
