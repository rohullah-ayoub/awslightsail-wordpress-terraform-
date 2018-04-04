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
            "Sid": "ModifyLightsailSnapshots",
            "Effect": "Allow",
            "Action": [
                "lightsail:GetInstanceSnapshot",
                "lightsail:DeleteInstanceSnapshot",
                "lightsail:GetInstanceSnapshots",
                "lightsail:CreateInstanceSnapshot"
            ],
            "Resource": [
                "arn:aws:lightsail:*:*:Instance/*",
                "arn:aws:lightsail:*:*:InstanceSnapshot/*"
            ]
        }
    ]
}
EOF
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lightsail-instance-snapshots"
  output_path = "lightsail-instance-snapshots.zip"
}

resource "aws_lambda_function" "instance_snapshot_lambda" {
  filename         = "lightsail-instance-snapshots.zip"
  function_name    = "modifyLightSailSnapshots"
  role             = "${aws_iam_role.lamda_role.arn}"
  handler          = "index.handler"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "nodejs6.10"

  environment {
    variables = {
      INSTANCE_NAME    = "${var.instance_name}"
      RETENTION_PERIOD = "${var.snapshot_retention_days}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "cloudwatch_scheduled_event" {
  name        = "LightsailSnapshotSchedule"
  description = "Trigger the modifyLightSailSnapshots to modify snapshots."

  schedule_expression = "rate(${var.snapshot_event_rate})"
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_target" {
  rule      = "${aws_cloudwatch_event_rule.cloudwatch_scheduled_event.name}"
  target_id = "TriggerModifyLightsailSnapshots"
  arn       = "${aws_lambda_function.instance_snapshot_lambda.arn}"
}
