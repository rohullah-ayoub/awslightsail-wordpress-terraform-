module "tf_remote_state" {
  source         = "../modules/state"
  aws_region     = "${var.aws_region}"
  project_prefix = "${var.project_prefix}"
}
