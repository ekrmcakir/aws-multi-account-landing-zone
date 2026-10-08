# 🛠️ Operational Runbook: Transit Gateway & Network Firewall Troubleshooting

## Diagnostic Workflow

```
[Spoke Workload Packet Dropped]
             │
             ▼
Check 1: Spoke Workload Subnet Route Table
  - Is 0.0.0.0/0 or target CIDR directed to the TGW attachment ID?
             │
             ▼
Check 2: TGW Spoke Inbound Route Table
  - Is target route pointing to the Inspection VPC attachment?
             │
             ▼
Check 3: AWS Network Firewall Flow Logs
  - Query CloudWatch: /aws/network-firewall/network-hub-alerts
  - Was rule SID:1000001 (prohibited port) or domain filter triggered?
             │
             ▼
Check 4: Central NAT Gateway / IGW
  - Are Elastic IPs healthy and routes symmetric?
```

## Common Issues & Remediation

### 1. Asymmetric Routing Packet Loss
**Symptom:** SYN packet reaches destination, but ACK packet is dropped by stateful Network Firewall.
**Cause:** Return route in destination spoke bypassed the Firewall.
**Remedy:** Ensure both TGW Spoke Inbound RT and Inspection Firewall RT have symmetric route entries.

### 2. SCP Denies API Call for Admin
**Symptom:** `AccessDeniedException` with message `explicit deny in a service control policy`.
**Remedy:** Check if the action is targeted by `deny_unauthorized_regions.json` or `protect_security_services.json`. Remember: Administrator privileges cannot bypass SCPs.
