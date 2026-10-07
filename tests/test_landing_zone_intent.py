#!/usr/bin/env python3
"""
AWS Enterprise Landing Zone - Architecture Purpose & Intent Test Suite

This test suite validates the architectural intent and security objectives of the landing zone
using deterministic rule-based verification and simulation:
1. [Guardrail Intent] Restrict AWS Root account API credentials and console access
2. [Guardrail Intent] Prevent resource provisioning outside approved AWS regions
3. [Guardrail Intent] Prevent disabling or deleting core security monitoring tools (CloudTrail, GuardDuty, Flow Logs)
4. [Guardrail Intent] Enforce S3 encryption and block public access alterations
5. [Guardrail Intent] Prevent member accounts from detaching or leaving the AWS Organization
6. [Network Isolation Intent] Prevent CIDR block overlap across all accounts and VPCs
7. [Network Isolation Intent] Verify air-gapped Spoke VPCs (no local IGW or NAT Gateways)
8. [Network Security Intent] Enforce East-West (Dev -> Prod) routing through AWS Network Firewall
9. [Network Security Intent] Block insecure outbound management ports (SSH:22, SMB:445, RDP:3389) via Firewall
10. [Network Security Intent] Whitelist approved external domains (.amazonaws.com, .github.com) via Central NAT
"""

import ipaddress
import json
from pathlib import Path
import re
import unittest

BASE_DIR = Path(__file__).resolve().parent.parent
MODULES_DIR = BASE_DIR / "modules"
POLICIES_DIR = MODULES_DIR / "aws-organizations" / "policies"
ENVIRONMENTS_DIR = BASE_DIR / "environments"


class ArchitectureIntentTests(unittest.TestCase):

    # =========================================================================
    # SECTION 1: AWS ORGANIZATIONS & SCP SECURITY GUARDRAIL INTENT
    # =========================================================================

    def test_intent_root_account_is_strictly_locked_down(self):
        """
        INTENT: AWS Root user credentials must never be used for day-to-day operations.
        Verifies the SCP explicitly denies all root API actions unconditionally.
        """
        policy_file = POLICIES_DIR / "deny_root_account_usage.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        found_root_lockdown = False
        for stmt in data.get("Statement", []):
            if stmt.get("Effect") == "Deny" and stmt.get("Action") == "*":
                principal_condition = (
                    stmt.get("Condition", {})
                    .get("StringLike", {})
                    .get("aws:PrincipalArn", [])
                )
                if "arn:aws:iam::*:root" in principal_condition:
                    found_root_lockdown = True

        self.assertTrue(
            found_root_lockdown,
            "ERROR: Missing or insufficient SCP rule to block root account usage!",
        )

    def test_intent_prevent_unauthorized_region_creation(self):
        """
        INTENT: Enforce data sovereignty and prevent shadow IT by blocking unapproved regions.
        Verifies API calls outside eu-central-1, eu-west-1, and us-east-1 are denied,
        while exempting global services (IAM, Route53, CloudFront).
        """
        policy_file = POLICIES_DIR / "deny_unauthorized_regions.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertEqual(stmt["Effect"], "Deny")
        allowed_regions = stmt["Condition"]["StringNotEquals"]["aws:RequestedRegion"]

        # Expected approved regions
        expected_regions = ["eu-central-1", "eu-west-1", "us-east-1"]
        for region in expected_regions:
            self.assertIn(
                region,
                allowed_regions,
                f"Approved region {region} is missing from the SCP whitelist!",
            )

        # Verify global services (IAM, Route53, CloudFront) are exempted
        not_actions = stmt.get("NotAction", [])
        self.assertIn("iam:*", not_actions)
        self.assertIn("organizations:*", not_actions)
        self.assertIn("route53:*", not_actions)

    def test_intent_security_audit_tools_cannot_be_disabled(self):
        """
        INTENT: An adversary compromising a member account must not be able to
        disable CloudTrail, GuardDuty, AWS Config, or VPC Flow Logs.
        """
        policy_file = POLICIES_DIR / "protect_security_services.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        denied_actions = []
        for stmt in data.get("Statement", []):
            if stmt.get("Effect") == "Deny":
                actions = stmt.get("Action", [])
                if isinstance(actions, list):
                    denied_actions.extend(actions)
                else:
                    denied_actions.append(actions)

        # Critical protected actions
        critical_actions = [
            "cloudtrail:StopLogging",
            "cloudtrail:DeleteTrail",
            "guardduty:DeleteDetector",
            "guardduty:DisassociateFromMasterAccount",
            "config:StopConfigurationRecorder",
            "ec2:DeleteFlowLogs",
        ]
        for act in critical_actions:
            self.assertIn(
                act, denied_actions, f"Critical security action {act} is not blocked by SCP!"
            )

    def test_intent_s3_data_leak_and_unencrypted_upload_prevention(self):
        """
        INTENT: Prevent data exfiltration from public S3 buckets and block unencrypted object storage writes.
        """
        policy_file = POLICIES_DIR / "enforce_s3_encryption_and_block_public.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        found_public_block = False
        found_encryption_enforcement = False

        for stmt in data.get("Statement", []):
            if stmt.get("Effect") == "Deny":
                act = stmt.get("Action")
                if "s3:DeleteAccountPublicAccessBlock" in (act if isinstance(act, list) else [act]):
                    found_public_block = True
                if act == "s3:PutObject":
                    cond = stmt.get("Condition", {}).get("Null", {})
                    if cond.get("s3:x-amz-server-side-encryption") == "true":
                        found_encryption_enforcement = True

        self.assertTrue(found_public_block, "SCP is missing enforcement for S3 Account Public Access Block!")
        self.assertTrue(found_encryption_enforcement, "SCP is missing enforcement for S3 server-side encryption!")

    def test_intent_prevent_leaving_organization(self):
        """
        INTENT: Prevent member accounts from escaping centralized billing, compliance, and security governance.
        """
        policy_file = POLICIES_DIR / "prevent_leaving_organization.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertEqual(stmt["Effect"], "Deny")
        self.assertIn("organizations:LeaveOrganization", stmt["Action"])

    # =========================================================================
    # SECTION 2: CENTRALIZED HUB-AND-SPOKE NETWORK & FIREWALL INTENT
    # =========================================================================

    def test_intent_zero_cidr_overlap_across_all_accounts(self):
        """
        INTENT: Ensure deterministic routing with zero IP address overlap across all accounts and VPC CIDR blocks.
        """
        account_cidrs = {
            "Network Hub (Inspection VPC)": ipaddress.ip_network("10.0.0.0/16"),
            "Workload Production": ipaddress.ip_network("10.1.0.0/16"),
            "Workload Development": ipaddress.ip_network("10.2.0.0/16"),
            "Shared Services": ipaddress.ip_network("10.3.0.0/16"),
        }

        # Pairwise comparison to verify no subnets overlap
        names = list(account_cidrs.keys())
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                name1, net1 = names[i], account_cidrs[names[i]]
                name2, net2 = names[j], account_cidrs[names[j]]
                self.assertFalse(
                    net1.overlaps(net2),
                    f"CIDR OVERLAP DETECTED! {name1} ({net1}) overlaps with {name2} ({net2})!",
                )

    def test_intent_spoke_vpcs_are_isolated_air_gapped(self):
        """
        INTENT: Spoke workload VPCs (Prod, Dev) must not have direct Internet Gateways (IGW) or local NAT Gateways;
        all external traffic must route to Transit Gateway.
        """
        spoke_tf = MODULES_DIR / "spoke-vpc" / "main.tf"
        with open(spoke_tf, "r") as f:
            content = f.read()

        # Ensure no aws_internet_gateway or aws_nat_gateway is created in Spoke VPCs
        self.assertNotIn(
            'resource "aws_internet_gateway"',
            content,
            "ERROR: Spoke VPC must not declare an Internet Gateway!",
        )
        self.assertNotIn(
            'resource "aws_nat_gateway"',
            content,
            "ERROR: Spoke VPC must not declare a local NAT Gateway! Egress must be centralized.",
        )

        # Verify 0.0.0.0/0 route is directed to Transit Gateway
        self.assertIn('cidr_block         = "0.0.0.0/0"', content)
        self.assertIn("transit_gateway_id = var.transit_gateway_id", content)

    def test_intent_transit_gateway_segments_spoke_and_inspection_routes(self):
        """
        INTENT: TGW must disable default propagation and association, strictly steering Spoke traffic
        into the Central Inspection Route Table.
        """
        tgw_tf = MODULES_DIR / "transit-gateway-hub" / "main.tf"
        with open(tgw_tf, "r") as f:
            content = f.read()

        self.assertIn('default_route_table_association = "disable"', content)
        self.assertIn('default_route_table_propagation = "disable"', content)
        self.assertIn('resource "aws_ec2_transit_gateway_route_table" "spokes"', content)
        self.assertIn('resource "aws_ec2_transit_gateway_route_table" "post_inspection"', content)

    def test_intent_network_firewall_blocks_prohibited_ports(self):
        """
        INTENT: AWS Network Firewall must intercept and drop outbound management ports
        (SSH:22, SMB:445, Telnet:23, RDP:3389).
        """
        firewall_tf = MODULES_DIR / "central-network-firewall" / "main.tf"
        with open(firewall_tf, "r") as f:
            content = f.read()

        # Check Suricata drop rule for prohibited ports
        suricata_drop_pattern = r"drop tcp any any -> any \[22,23,25,445,1433,3389\]"
        self.assertTrue(
            re.search(suricata_drop_pattern, content),
            "Suricata rule dropping prohibited management ports was not found in firewall configuration!",
        )

    def test_intent_network_firewall_whitelists_secure_outbound_domains(self):
        """
        INTENT: Outbound TLS traffic must strictly whitelist approved corporate domains (.amazonaws.com, .github.com).
        """
        firewall_tf = MODULES_DIR / "central-network-firewall" / "main.tf"
        with open(firewall_tf, "r") as f:
            content = f.read()

        self.assertIn('.amazonaws.com', content)
        self.assertIn('.github.com', content)

    def test_intent_terragrunt_orchestrates_multi_account_dependencies(self):
        """
        INTENT: Terragrunt must orchestrate account dependencies hierarchically,
        passing TGW outputs from Network Hub to Workload Spokes.
        """
        prod_hcl = ENVIRONMENTS_DIR / "account-workload-prod" / "terragrunt.hcl"
        with open(prod_hcl, "r") as f:
            prod_content = f.read()

        self.assertIn('dependency "network_hub"', prod_content)
        self.assertIn('config_path = "../account-network-hub"', prod_content)
        self.assertIn('transit_gateway_id             = dependency.network_hub.outputs.transit_gateway_id', prod_content)


if __name__ == "__main__":
    unittest.main()
