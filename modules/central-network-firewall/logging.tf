# ---------------------------------------------------------------------------------------------------------------------
# AWS NETWORK FIREWALL LOGGING CONFIGURATION
# Captures Alert and Flow logs from the stateful Suricata inspection engine into CloudWatch Log Groups
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "firewall_alerts" {
  name              = "/aws/network-firewall/${var.name}-alerts"
  retention_in_days = 90

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "firewall_flows" {
  name              = "/aws/network-firewall/${var.name}-flows"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alerts.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flows.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
