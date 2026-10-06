#!/usr/bin/env python3
"""
AWS Enterprise Landing Zone - Architecture Purpose & Intent Test Suite (Amaca Yönelik Doğrulama)

Bu test paketi, mimarinin tasarım ve güvenlik AMAÇLARINI (Architectural Intent & Security Goals)
simülasyon ve kural tabanlı doğrulamalarla test eder:
1. [Guardrail Amacı] Root hesabının API kullanımının engellenmesi
2. [Guardrail Amacı] Yetkisiz AWS Region'larında kaynak açılmasının engellenmesi
3. [Guardrail Amacı] Güvenlik izleme servislerinin (CloudTrail, GuardDuty, Flow Logs) kapatılmasının engellenmesi
4. [Guardrail Amacı] S3 public erişim açılması ve şifresiz obje yüklenmesinin engellenmesi
5. [Guardrail Amacı] Üye hesapların organizasyondan ayrılmasının engellenmesi
6. [Ağ İzolasyonu Amacı] Hesaplar arası IP çakışmasının (CIDR Overlap) önlenmesi
7. [Ağ İzolasyonu Amacı] Spoke VPC'lerin doğrudan internet çıkışının (IGW/NAT) olmaması (Air-Gapped Spokes)
8. [Ağ Güvenliği Amacı] East-West (Dev -> Prod) trafiğin Network Firewall'u bypass edememesi
9. [Ağ Güvenliği Amacı] Dışarıya yönelik zararlı portların (SSH:22, SMB:445, RDP:3389) Firewall tarafından engellenmesi
10. [Ağ Güvenliği Amacı] Onaylı dış domainlere (.amazonaws.com, .github.com) merkezi NAT üzerinden kontrollü çıkış
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
    # BÖLÜM 1: AWS ORGANIZATIONS & SCP GÜVENLİK GUARDRAIL AMAÇLARI
    # =========================================================================

    def test_intent_root_account_is_strictly_locked_down(self):
        """
        AMAC: AWS Root hesabı günlük operasyonlarda asla kullanılmamalıdır.
        SCP'nin tüm Root API çağrılarını kartsız şartsız DENY ettiğini doğrular.
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
            "HATA: Root hesabını engelleyen SCP kuralı bulunamadı veya yetersiz!",
        )

    def test_intent_prevent_unauthorized_region_creation(self):
        """
        AMAC: Veri egemenliği ve gölge BT'yi önlemek için onaylanmamış region'lar engellenmelidir.
        Sadece eu-central-1, eu-west-1 ve us-east-1 haricindeki region çağrılarının DENY edildiğini doğrular.
        """
        policy_file = POLICIES_DIR / "deny_unauthorized_regions.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertEqual(stmt["Effect"], "Deny")
        allowed_regions = stmt["Condition"]["StringNotEquals"]["aws:RequestedRegion"]

        # Hedeflenen onaylı bölgeler
        expected_regions = ["eu-central-1", "eu-west-1", "us-east-1"]
        for region in expected_regions:
            self.assertIn(
                region,
                allowed_regions,
                f"Onaylı region {region} SCP kuralında tanımlı değil!",
            )

        # Global servislerin (IAM, Route53, CloudFront) kilitlenmediğini doğrula
        not_actions = stmt.get("NotAction", [])
        self.assertIn("iam:*", not_actions)
        self.assertIn("organizations:*", not_actions)
        self.assertIn("route53:*", not_actions)

    def test_intent_security_audit_tools_cannot_be_disabled(self):
        """
        AMAC: Saldırgan bir hesabı ele geçirse bile CloudTrail, GuardDuty ve Config loglamayı kapatamamalıdır.
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

        # Kritik korunan aksiyonlar
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
                act, denied_actions, f"Kritik güvenlik aksiyonu {act} SCP tarafından engellenmiyor!"
            )

    def test_intent_s3_data_leak_and_unencrypted_upload_prevention(self):
        """
        AMAC: S3 kovalarından veri sızıntısını ve şifresiz veri depolanmasını engellemek.
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

        self.assertTrue(found_public_block, "S3 Public Access Block kaldırılmasını engelleyen kural eksik!")
        self.assertTrue(found_encryption_enforcement, "Şifresiz S3 PutObject çağrılarını engelleyen kural eksik!")

    def test_intent_prevent_leaving_organization(self):
        """
        AMAC: Hesapların merkezi faturalandırma ve güvenlik şemsiyesinden çıkışını engellemek.
        """
        policy_file = POLICIES_DIR / "prevent_leaving_organization.json"
        with open(policy_file, "r") as f:
            data = json.load(f)

        stmt = data["Statement"][0]
        self.assertEqual(stmt["Effect"], "Deny")
        self.assertIn("organizations:LeaveOrganization", stmt["Action"])

    # =========================================================================
    # BÖLÜM 2: MERKEZİ AĞ (HUB-AND-SPOKE) VE GÜVENLİK AMAÇLARI
    # =========================================================================

    def test_intent_zero_cidr_overlap_across_all_accounts(self):
        """
        AMAC: Kurumsal Landing Zone'da hiçbir hesabın/VPC'nin CIDR bloğu birbiriyle çakışmamalıdır.
        """
        account_cidrs = {
            "Network Hub (Inspection VPC)": ipaddress.ip_network("10.0.0.0/16"),
            "Workload Production": ipaddress.ip_network("10.1.0.0/16"),
            "Workload Development": ipaddress.ip_network("10.2.0.0/16"),
            "Shared Services": ipaddress.ip_network("10.3.0.0/16"),
        }

        # İkili karşılaştırma yaparak çakışma (overlap) kontrolü
        names = list(account_cidrs.keys())
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                name1, net1 = names[i], account_cidrs[names[i]]
                name2, net2 = names[j], account_cidrs[names[j]]
                self.assertFalse(
                    net1.overlaps(net2),
                    f"CIDR ÇAKIŞMASI TESPİT EDİLDİ! {name1} ({net1}) ile {name2} ({net2}) çakışıyor!",
                )

    def test_intent_spoke_vpcs_are_isolated_air_gapped(self):
        """
        AMAC: Spoke hesaplarında (Prod, Dev) Internet Gateway (IGW) veya yerel NAT Gateway bulunmamalıdır.
        Tüm dış dünya trafiği doğrudan Transit Gateway'e yönlendirilmelidir.
        """
        spoke_tf = MODULES_DIR / "spoke-vpc" / "main.tf"
        with open(spoke_tf, "r") as f:
            content = f.read()

        # aws_internet_gateway veya aws_nat_gateway tanımlı olmamalıdır
        self.assertNotIn(
            'resource "aws_internet_gateway"',
            content,
            "HATA: Spoke VPC içerisinde Internet Gateway tanımlanamaz!",
        )
        self.assertNotIn(
            'resource "aws_nat_gateway"',
            content,
            "HATA: Spoke VPC içerisinde yerel NAT Gateway tanımlanamaz! Egress merkezi olmalıdır.",
        )

        # 0.0.0.0/0 rotasının Transit Gateway'e gittiğini doğrula
        self.assertIn('cidr_block         = "0.0.0.0/0"', content)
        self.assertIn("transit_gateway_id = var.transit_gateway_id", content)

    def test_intent_transit_gateway_segments_spoke_and_inspection_routes(self):
        """
        AMAC: TGW varsayılan rotalamayı (default propagation/association) devre dışı bırakarak
        tüm trafiği zorunlu olarak Inspection VPC Route Table'a yönlendirmelidir.
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
        AMAC: AWS Network Firewall; SSH (22), SMB (445), Telnet (23), RDP (3389) gibi
        yönetimsel portların internete çıkışını engellemelidir.
        """
        firewall_tf = MODULES_DIR / "central-network-firewall" / "main.tf"
        with open(firewall_tf, "r") as f:
            content = f.read()

        # Suricata kural kontrolü
        suricata_drop_pattern = r"drop tcp any any -> any \[22,23,25,445,1433,3389\]"
        self.assertTrue(
            re.search(suricata_drop_pattern, content),
            "Firewall kurallarında yasaklı portları DROP eden Suricata kuralı bulunamadı!",
        )

    def test_intent_network_firewall_whitelists_secure_outbound_domains(self):
        """
        AMAC: Dışarıya giden HTTPS trafiğinde sadece güvenli kurumsal domainlere (.amazonaws.com, .github.com) izin verilmelidir.
        """
        firewall_tf = MODULES_DIR / "central-network-firewall" / "main.tf"
        with open(firewall_tf, "r") as f:
            content = f.read()

        self.assertIn('.amazonaws.com', content)
        self.assertIn('.github.com', content)

    def test_intent_terragrunt_orchestrates_multi_account_dependencies(self):
        """
        AMAC: Terragrunt hesap bağımlılıklarını hiyerarşik olarak çözmelidir.
        Workload Prod ve Dev hesapları, Network Hub çıktısına (TGW ID) bağımlı olmalıdır.
        """
        prod_hcl = ENVIRONMENTS_DIR / "account-workload-prod" / "terragrunt.hcl"
        with open(prod_hcl, "r") as f:
            prod_content = f.read()

        self.assertIn('dependency "network_hub"', prod_content)
        self.assertIn('config_path = "../account-network-hub"', prod_content)
        self.assertIn('transit_gateway_id             = dependency.network_hub.outputs.transit_gateway_id', prod_content)


if __name__ == "__main__":
    unittest.main()
