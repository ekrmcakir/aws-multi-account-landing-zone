#!/usr/bin/env python3
"""
Test Suite: Transit Gateway & Central Network Firewall Deterministic Routing Simulator
Simulates and mathematically verifies packet flow trajectories across AWS multi-account landing zone:
- East-West Traffic (Spoke Dev -> Spoke Prod)
- North-South Egress (Spoke -> Internet)
- Security Drop (Unauthorized outbound port via Firewall)
"""

import ipaddress
import unittest

class RouteTable:
    def __init__(self, name, routes):
        """
        routes: list of tuples (cidr_str, target)
        e.g. [("0.0.0.0/0", "tgw"), ("10.0.0.0/8", "tgw")]
        """
        self.name = name
        self.routes = [(ipaddress.ip_network(cidr), target) for cidr, target in routes]

    def lookup(self, dest_ip):
        ip = ipaddress.ip_address(dest_ip)
        best_match = None
        longest_prefix = -1
        for net, target in self.routes:
            if ip in net and net.prefixlen > longest_prefix:
                longest_prefix = net.prefixlen
                best_match = target
        return best_match

class NetworkFirewall:
    def __init__(self, blocked_ports, allowed_domains):
        self.blocked_ports = set(blocked_ports)
        self.allowed_domains = set(allowed_domains)

    def inspect(self, packet):
        dest_port = packet.get("port")
        if dest_port in self.blocked_ports:
            return False, f"DROPPED: Prohibited port {dest_port}"
        return True, "PASSED: Stateful inspection approved"

class LandingZoneNetworkSimulator:
    def __init__(self):
        # Spoke RT (inside Dev or Prod VPC)
        self.spoke_workload_rt = RouteTable("SpokeWorkloadRT", [
            ("0.0.0.0/0", "tgw_attachment"),
            ("10.0.0.0/8", "tgw_attachment")
        ])

        # TGW Spoke Inbound RT (receives traffic from Spokes)
        self.tgw_spoke_inbound_rt = RouteTable("TGWSpokeInboundRT", [
            ("0.0.0.0/0", "inspection_vpc_attachment"),
            ("10.0.0.0/8", "inspection_vpc_attachment")
        ])

        # Central Inspection VPC - TGW Subnet RT
        self.inspection_tgw_subnet_rt = RouteTable("InspectionTGWSubnetRT", [
            ("0.0.0.0/0", "network_firewall_endpoint")
        ])

        # Central Network Firewall Engine
        self.firewall = NetworkFirewall(
            blocked_ports=[22, 23, 25, 445, 1433, 3389],
            allowed_domains=[".amazonaws.com", ".github.com"]
        )

        # Central Inspection VPC - Firewall Subnet RT
        self.inspection_firewall_subnet_rt = RouteTable("InspectionFirewallSubnetRT", [
            ("0.0.0.0/0", "nat_gateway"),
            ("10.0.0.0/8", "tgw_attachment")
        ])

        # TGW Post-Inspection RT (receives traffic leaving Firewall back into TGW)
        self.tgw_post_inspection_rt = RouteTable("TGWPostInspectionRT", [
            ("10.1.0.0/16", "prod_spoke_attachment"),
            ("10.2.0.0/16", "dev_spoke_attachment"),
            ("10.3.0.0/16", "shared_services_attachment")
        ])

        # Central Inspection VPC - Egress Subnet RT
        self.inspection_egress_rt = RouteTable("InspectionEgressRT", [
            ("0.0.0.0/0", "internet_gateway"),
            ("10.0.0.0/8", "network_firewall_endpoint")
        ])

    def trace_packet(self, src_ip, dest_ip, port=443, domain=""):
        packet = {"src": src_ip, "dest": dest_ip, "port": port, "domain": domain}
        hops = []

        # Step 1: Spoke Workload Subnet
        hop1 = self.spoke_workload_rt.lookup(dest_ip)
        hops.append(("SpokeWorkloadRT", hop1))
        if hop1 != "tgw_attachment":
            return False, hops, "Failed at Spoke Route Table"

        # Step 2: TGW Inbound RT
        hop2 = self.tgw_spoke_inbound_rt.lookup(dest_ip)
        hops.append(("TGWSpokeInboundRT", hop2))
        if hop2 != "inspection_vpc_attachment":
            return False, hops, "Bypassed Central Inspection VPC!"

        # Step 3: Inspection VPC TGW Subnet
        hop3 = self.inspection_tgw_subnet_rt.lookup(dest_ip)
        hops.append(("InspectionTGWSubnetRT", hop3))
        if hop3 != "network_firewall_endpoint":
            return False, hops, "Bypassed Network Firewall Endpoint!"

        # Step 4: Network Firewall Inspection
        passed, msg = self.firewall.inspect(packet)
        hops.append(("NetworkFirewall", msg))
        if not passed:
            return False, hops, msg

        # Step 5: Route after firewall
        hop5 = self.inspection_firewall_subnet_rt.lookup(dest_ip)
        hops.append(("InspectionFirewallSubnetRT", hop5))

        if hop5 == "tgw_attachment":
            # East-West flow returning to TGW
            hop6 = self.tgw_post_inspection_rt.lookup(dest_ip)
            hops.append(("TGWPostInspectionRT", hop6))
            return True, hops, f"Delivered to destination spoke via {hop6}"
        elif hop5 == "nat_gateway":
            # North-South Egress flow
            hop6 = self.inspection_egress_rt.lookup(dest_ip)
            hops.append(("InspectionEgressRT", hop6))
            return True, hops, "Egressed to Internet via Central IGW"

        return False, hops, "Unknown routing termination"

class TestRoutingSimulator(unittest.TestCase):
    def setUp(self):
        self.sim = LandingZoneNetworkSimulator()

    def test_east_west_routing_dev_to_prod_must_pass_inspection(self):
        """Validates that East-West packet from Dev (10.2.1.10) to Prod (10.1.1.20) traverses Firewall."""
        success, hops, summary = self.sim.trace_packet(src_ip="10.2.1.10", dest_ip="10.1.1.20", port=443)
        self.assertTrue(success)
        hop_names = [h[0] for h in hops]
        self.assertIn("InspectionTGWSubnetRT", hop_names)
        self.assertIn("NetworkFirewall", hop_names)
        self.assertIn("TGWPostInspectionRT", hop_names)
        self.assertEqual(hops[-1][1], "prod_spoke_attachment")
        self.assertEqual(summary, "Delivered to destination spoke via prod_spoke_attachment")

    def test_north_south_internet_egress_must_pass_inspection(self):
        """Validates that outbound internet traffic from Dev to 54.239.28.85 traverses Firewall and Central NAT."""
        success, hops, summary = self.sim.trace_packet(src_ip="10.2.1.10", dest_ip="54.239.28.85", port=443)
        self.assertTrue(success)
        hop_names = [h[0] for h in hops]
        self.assertIn("NetworkFirewall", hop_names)
        self.assertIn("InspectionEgressRT", hop_names)
        self.assertEqual(hops[-1][1], "internet_gateway")
        self.assertEqual(summary, "Egressed to Internet via Central IGW")

    def test_firewall_blocks_prohibited_outbound_ports(self):
        """Validates that insecure egress ports (e.g. port 22 or 445) are intercepted and dropped."""
        success, hops, summary = self.sim.trace_packet(src_ip="10.2.1.10", dest_ip="54.239.28.85", port=22)
        self.assertFalse(success)
        self.assertIn("DROPPED: Prohibited port 22", summary)

    def test_no_direct_spoke_bypass(self):
        """Verifies mathematically that Spoke Inbound RT cannot route directly to Spoke VPC without Inspection."""
        target = self.sim.tgw_spoke_inbound_rt.lookup("10.1.1.20")
        self.assertEqual(target, "inspection_vpc_attachment", "Direct spoke-to-spoke bypass detected!")


if __name__ == "__main__":
    unittest.main()
