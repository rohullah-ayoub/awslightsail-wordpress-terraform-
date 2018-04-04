output "state_bucket_name" {
  value = "${module.tf_remote_state.state_bucket_name}"
}

output "lock_table_name" {
  value = "${module.tf_remote_state.lock_table_name}"
}
