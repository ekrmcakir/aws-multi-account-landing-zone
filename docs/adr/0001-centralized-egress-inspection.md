# ADR 0001: Centralized Egress & East-West Network Inspection via Transit Gateway and AWS Network Firewall

## Status
Accepted

## Context
In a multi-account AWS architecture, hosting independent NAT Gateways and Internet Gateways within every workload Spoke VPC creates severe security and operational challenges:
1. **Lack of Traffic Visibility:** Egress traffic is uninspected by a unified stateful firewall, allowing data exfiltration risks.
2. **Cost Inefficiency:** Each Availability Zone with a NAT Gateway incurs static hourly charges (~$32/month per NAT GW) plus data processing fees. Across 10+ accounts, this results in significant unnecessary spend.
3. **Lateral Movement Risk:** Spokes connected via VPC peering can easily bypass centralized inspection.

## Decision
We enforce a **Centralized Hub-and-Spoke Topology**:
- Workload Spoke VPCs (Production, Development, Shared Services) have **zero Internet Gateways** and **zero local NAT Gateways** (Air-gapped spokes).
- All outbound internet traffic (`0.0.0.0/0`) and internal RFC1918 traffic (`10.0.0.0/8`) are routed to the central AWS Transit Gateway.
- A dedicated **Central Inspection VPC** hosts **AWS Network Firewall** endpoints across multiple Availability Zones.
- Segmented TGW Route Tables strictly steer all ingress spoke traffic to the Inspection VPC attachment before returning to target spokes or centralized NAT Gateways.

## Consequences
- **Positive:** Single pane of glass for network telemetry and IDS/IPS enforcement; complete elimination of spoke-to-spoke bypass; centralized FinOps egress control.
- **Negative:** Extra TGW data processing fee ($0.02 per GB); requires careful symmetric routing table maintenance.
