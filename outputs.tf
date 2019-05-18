#output "elb_dns_name" {
#  value = "${aws_elb.nginx_elb.dns_name}"
#}

output "public_ip_address" {
  value = "${aws_instance.nginx.public_ip}"
}

output "private_ip_address" {
  value = "${aws_instance.nginx.private_ip}"
}

output "dns_zone_id" {
  value = "${aws_route53_zone.private.id}"
}


output "vpc_endpoint_id" {
  value = "${aws_vpc_endpoint.endpoint_s3.id}"
}

output "vpc_endpoint_api_id" {
  value = "${aws_vpc_endpoint.endpoint_api.id}"
}

