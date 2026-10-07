# ---------------------------------------------------------------------------------------------------------------------
# TRANSIT GATEWAY FLOW LOGS (Cross-Account Traffic Telemetry)
# Streams metadata of all packets routed across TGW attachments to CloudWatch for threat hunting
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  name              = "/aws/transitgateway/${var.name}-flow-logs"
  retention_in_days = 90

  tags = var.tags
}

resource "aws_iam_role" "tgw_flow_logs" {
  name = "${var.name}-tgw-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "tgw_flow_logs" {
  name = "${var.name}-tgw-flow-logs-policy"
  role = aws_iam_role.tgw_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.tgw_flow_logs.arn}:*"
      }
    ]
  })
}
