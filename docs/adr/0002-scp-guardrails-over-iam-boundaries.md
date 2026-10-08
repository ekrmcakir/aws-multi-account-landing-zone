# ADR 0002: Preventive Guardrails via AWS Organizations Service Control Policies (SCPs)

## Status
Accepted

## Context
Individual member accounts within an enterprise need administrative autonomy to provision compute, databases, and microservices without central IT bottlenecking routine operations. However, granting local administrators IAM access creates the risk of disabling security monitoring (CloudTrail, GuardDuty), creating unencrypted public S3 buckets, or spinning up unauthorized resources in unmonitored geographic regions.

## Decision
We utilize **AWS Organizations Service Control Policies (SCPs)** as preventative guardrails at the Root and Organizational Unit (OU) levels rather than relying exclusively on IAM Permission Boundaries or reactive AWS Config rules:
1. **SCPs act as filters:** SCPs do not grant permissions; they define the maximum available permissions across an account.
2. **Administrator Immunity:** Even a principal with full `AdministratorAccess` (`*:*`) or the root account cannot override an explicit `Deny` in an SCP.
3. **Core Rules Enforced:**
   - Universal Root credential lockout (`arn:aws:iam::*:root`).
   - Regional data sovereignty lockdown (Europe & US East approved only).
   - Tamper-proofing of CloudTrail, GuardDuty, AWS Config, and VPC Flow Logs.
   - S3 public access block alteration prevention.

## Consequences
- **Positive:** Mathematically guaranteed compliance across all current and future accounts; decentralized teams cannot accidentally compromise security baselines.
- **Negative:** SCP size is limited to 5,120 bytes per policy, requiring concise statement grouping and JSON optimization.
