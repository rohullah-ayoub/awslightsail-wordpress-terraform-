output "aws_lightsail_instance_id" {
  value = "${aws_lightsail_instance.instance.id}"
}

output "aws_lightsail_instance_ip" {
  value = "${aws_lightsail_static_ip.static_ip.ip_address}"
}

output "readme" {
  value = <<EOF
In order to use a custom domain for this instance, please use the public IP(${aws_lightsail_static_ip.static_ip.ip_address}) when changing the DNS configuration with your provider.
EOF
}
