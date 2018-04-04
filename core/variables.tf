variable "aws_region" {
  description = "AWS region to provision resources in."
}

variable "availability_zone" {
  description = "AWS availability zone to provision resources in. Available values: us-east-1, us-east-2, us-west-2, eu-west-1, eu-west-2, eu-central-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, ap-south-1"
}

variable "instance_name" {
  description = "The name of the Lightsail instance."
}

variable "bundle_id" {
  description = "ID of the Lightsail bundle to be used. Available values: nano_1_0, micro_1_0, small_1_0, medium_1_0, large_1_0"
}

variable "publickey_path" {
  description = "Path to the public key to use when creating Lightsail instance"
}

variable "snapshot_retention_days" {
  description = "The number of days to retain snapshots of the lightsail instance"
}

variable "snapshot_event_rate" {
  description = "The number of days after which to trigger a snapshot creation. 1 day = create snapshot every day, 3 days = create snapshot every 3 days, 10 minutes = create snapshot every 10 minutes"
}
