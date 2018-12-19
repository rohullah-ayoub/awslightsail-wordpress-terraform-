terraform {
  required_version = ">= 0.11.5"
  backend          "s3"             {}
}

provider "aws" {
  region = "${var.aws_region}"
}

provider "archive" {}

resource "aws_lightsail_static_ip_attachment" "static_ip_attachment" {
  static_ip_name = "${aws_lightsail_static_ip.static_ip.name}"
  instance_name  = "${aws_lightsail_instance.instance.name}"
}

resource "aws_lightsail_static_ip" "static_ip" {
  name = "static_ip"
}

resource "aws_lightsail_key_pair" "key_pair" {
  name       = "ImportedKey"
  public_key = "${file("${var.publickey_path}")}"
}

resource "aws_lightsail_instance" "instance" {
  name              = "${var.instance_name}"
  availability_zone = "${var.availability_zone}"
  blueprint_id      = "wordpress_4_8_0"
  bundle_id         = "${var.bundle_id}"
  key_pair_name     = "${aws_lightsail_key_pair.key_pair.name}"
}

resource "aws_iam_role" "lamda_role" {
  name = "LamdbaModifyLightsailSnapshotsRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lamda_role_policy" {
  name = "LamdbaModifyLightsailSnapshotsPolicy"
  role = "${aws_iam_role.lamda_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Sid": "LightsailFullAccess",
          "Effect": "Allow",
          "Action": [
              "lightsail:*"
          ],
          "Resource": "*"
        },
        {
            "Sid": "LogsFullAccess",
            "Effect": "Allow",
            "Action": "logs:*",
            "Resource": "*"
        }
    ]
}
EOF
}

data "archive_file" "create_snapshots_lambda_zip" {
  type        = "zip"
  source_dir  = "lightsail-create-instance-snapshots"
  output_path = "lightsail-create-instance-snapshots.zip"
}

data "archive_file" "prune_snapshots_lambda_zip" {
  type        = "zip"
  source_dir  = "lightsail-prune-instance-snapshots"
  output_path = "lightsail-prune-instance-snapshots.zip"
}

resource "aws_lambda_function" "create_instance_snapshot_lambda" {
  filename         = "lightsail-create-instance-snapshots.zip"
  function_name    = "createLightSailSnapshots"
  role             = "${aws_iam_role.lamda_role.arn}"
  handler          = "index.handler"
  source_code_hash = "${data.archive_file.create_snapshots_lambda_zip.output_base64sha256}"
  runtime          = "nodejs6.10"

  environment {
    variables = {
      INSTANCE_NAME = "${var.instance_name}"
    }
  }
}

resource "aws_lambda_function" "prune_instance_snapshot_lambda" {
  filename         = "lightsail-prune-instance-snapshots.zip"
  function_name    = "pruneLightSailSnapshots"
  role             = "${aws_iam_role.lamda_role.arn}"
  handler          = "index.handler"
  source_code_hash = "${data.archive_file.prune_snapshots_lambda_zip.output_base64sha256}"
  runtime          = "nodejs6.10"

  environment {
    variables = {
      RETENTION_PERIOD = "${var.snapshot_retention_days}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "cloudwatch_scheduled_event" {
  name        = "LightsailSnapshotSchedule"
  description = "Trigger the createLightSailSnapshots and pruneLightSailSnapshots light to modify snapshots."

  schedule_expression = "rate(${var.snapshot_event_rate_days} day)"
}

resource "aws_lambda_permission" "create_snapshots_allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.create_instance_snapshot_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cloudwatch_scheduled_event.arn}"
}

resource "aws_lambda_permission" "prune_snapshots_allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.prune_instance_snapshot_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cloudwatch_scheduled_event.arn}"
}

resource "aws_cloudwatch_event_target" "create_lightsail_snapshots_cloudwatch_event_target" {
  rule      = "${aws_cloudwatch_event_rule.cloudwatch_scheduled_event.name}"
  target_id = "TriggerCreateLightsailSnapshots"
  arn       = "${aws_lambda_function.create_instance_snapshot_lambda.arn}"
}

resource "aws_cloudwatch_event_target" "prune_lightsail_snapshots_cloudwatch_event_target" {
  rule      = "${aws_cloudwatch_event_rule.cloudwatch_scheduled_event.name}"
  target_id = "TriggerPruneLightsailSnapshots"
  arn       = "${aws_lambda_function.prune_instance_snapshot_lambda.arn}"
}

resource "aws_sns_topic" "lambda_lightsail_snapshots_sns_topic" {
  name = "LambdaLightSailSnapshotsSnsTopic"
}

resource "aws_sns_topic_subscription" "lambda_lightsail_snapshots_sns_subscription" {
  topic_arn = "${aws_sns_topic.lambda_lightsail_snapshots_sns_topic.arn}"
  protocol  = "sms"
  endpoint  = "${var.notification_phone}"
}

resource "aws_cloudwatch_metric_alarm" "create_lightsail_snapshots_cloudwatch_invocation_alarm" {
  alarm_name          = "CreateLightSailSnapshotsCloudWatchInvocationAlarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "${var.snapshot_event_rate_days * 24 * 3600}"                               // Seconds
  statistic           = "Sum"
  threshold           = "1"
  alarm_actions       = ["${aws_sns_topic.lambda_lightsail_snapshots_sns_topic.arn}"]
  alarm_description   = "This metric triggers if the Lamdba function is not triggered as expected."

  dimensions {
    FunctionName = "createLightSailSnapshots"
  }
}

resource "aws_cloudwatch_metric_alarm" "create_lightsail_snapshots_cloudwatch_error_alarm" {
  alarm_name          = "CreateLightSailSnapshotsCloudWatchErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "${var.snapshot_event_rate_days * 24 * 3600}"
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = ["${aws_sns_topic.lambda_lightsail_snapshots_sns_topic.arn}"]
  alarm_description   = "This metric triggers if there are any errors logged by Lamdba function"

  dimensions {
    FunctionName = "createLightSailSnapshots"
  }
}

resource "aws_cloudwatch_metric_alarm" "prune_lightsail_snapshots_cloudwatch_invocation_alarm" {
  alarm_name          = "PruneLightSailSnapshotsCloudWatchInvocationAlarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "${var.snapshot_event_rate_days * 24 * 3600}"                               // Seconds
  statistic           = "Sum"
  threshold           = "1"
  alarm_actions       = ["${aws_sns_topic.lambda_lightsail_snapshots_sns_topic.arn}"]
  alarm_description   = "This metric triggers if the Lamdba function is not triggered as expected."

  dimensions {
    FunctionName = "pruneLightSailSnapshots"
  }
}

resource "aws_cloudwatch_metric_alarm" "prune_lightsail_snapshots_cloudwatch_error_alarm" {
  alarm_name          = "PruneLightSailSnapshotsCloudWatchErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "${var.snapshot_event_rate_days * 24 * 3600}"
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = ["${aws_sns_topic.lambda_lightsail_snapshots_sns_topic.arn}"]
  alarm_description   = "This metric triggers if there are any errors logged by Lamdba function"

  dimensions {
    FunctionName = "pruneLightSailSnapshots"
  }
}
