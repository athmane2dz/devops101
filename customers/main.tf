provider "aws" {
  region = "us-east-1"
}

terraform {
    backend "s3" {
        bucket = "YOU_S3_BUCKET"
        key = "NEW_CUSTOMER/terraform.tfstate"
        region = "us-east-1"
        encrypt = true
#        depends_on = "${aws_s3_bucket.terraform_state.bucket}"
    }
}



data "terraform_remote_state" "main" {  
        backend = "s3"  
        config {    
        bucket = "YOU_S3_BUCKET"
        key    = "global/terraform.tfstate"
        region = "us-east-1"
        } 
}

resource "aws_route53_record" "customer" {
  zone_id = "${data.terraform_remote_state.main.dns_zone_id}"
  name = "${var.customer_name}.tradewindmarkets.com"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_api_gateway_rest_api.customers.id}.execute-api.us-east-1.amazonaws.com"]
}


#resource "aws_s3_bucket" "terraform_state" {
#         bucket = "YOU_S3_BUCKET"
#         versioning {
#              enabled = true  }
#         lifecycle {
#              prevent_destroy = false  } 
#} 

#module "shared_infra" {
#  source = "../"
#}


resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.customer_name}tradewindmarkets2018"
website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_s3_bucket_object" "object" {
  bucket = "${aws_s3_bucket.website_bucket.id}"
  key    = "index.html"
  content = "<!DOCTYPE html>
<html>
<body>

<h1 style="color:blue;">My AWSome website</h1>

</body>
</html>"
  content_type = "text/plain"
}


resource "aws_s3_bucket_object" "page404" {
  bucket = "${aws_s3_bucket.website_bucket.id}"
  key    = "404.html"
  content = "Sorry. This page doesn't exist."
  content_type = "text/plain"
}

resource "aws_s3_bucket_policy" "website_bucket" {
  bucket = "${aws_s3_bucket.website_bucket.id}"
policy =<<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
        },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${var.customer_name}tradewindmarkets2018/*",
      "Condition": {
         "StringEquals": {
           "aws:UserAgent": "${var.customer_name}tradewindmarkets",
           "aws:sourceVpce": "${data.terraform_remote_state.main.vpc_endpoint_id}" }
      }
    }
  ]
}
POLICY
}

#resource "aws_api_gateway_rest_api" "customers" {
#  name = "customers"
#}

resource "aws_api_gateway_rest_api" "customers" {
  name = "${var.customer_name}"
#  policy =<<POLICY
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Effect": "Allow",
#            "Principal": "*",
#            "Action": "execute-api:Invoke",
#            "Resource": [
#                "arn:aws:execute-api:us-east-1:465024359360:*/*"
#            ]
#        },
#        {
#            "Effect": "Deny",
#            "Principal": "*",
#            "Action": "execute-api:Invoke",
#            "Resource": [
#                "arn:aws:execute-api:us-east-1:465024359360:*/*"
#            ],
#            "Condition" : {
#                "StringNotEquals": {
#                    "aws:sourceVpce": "${data.terraform_remote_state.main.vpc_endpoint_api_id}"
#                }
#            }
#        }
#    ]
#}
#
#POLICY

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "null_resource" "new_api_gateway" {
  triggers = {
         file_sha1 = "${sha1(file("templates/nginx/fake"))}"
  }
  provisioner "local-exec" {
    command = <<EOT
       sed 's/server_name customer-.*/server_name ${var.customer_name}-api.devops101.wiki;/' templates/nginx/customer  > templates/nginx/${var.customer_name}
       sed -i 's/proxy_set_header Host \".*/proxy_set_header Host \"${aws_api_gateway_rest_api.customers.id}.execute-api.us-east-1.amazonaws.com";/' templates/nginx/${var.customer_name}
       cp templates/nginx/${var.customer_name} templates/nginx/fake
       sed 's/customer_var/${var.customer_name}/g' customer.yml > customer_playbook.yml
       ansible-playbook -i ${data.terraform_remote_state.main.public_ip_address}, -u ec2-user --private-key ${var.ssh_key} customer_playbook.yml

   EOT
  }
}



resource "aws_api_gateway_resource" "resource" {
  rest_api_id = "${aws_api_gateway_rest_api.customers.id}"
  parent_id   = "${aws_api_gateway_rest_api.customers.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.customers.id}"
  resource_id   = "${aws_api_gateway_resource.resource.id}"
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}


#########

resource "aws_api_gateway_method" "method_main" {
  rest_api_id   = "${aws_api_gateway_rest_api.customers.id}"
  resource_id   = "${aws_api_gateway_rest_api.customers.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "integration_main" {
  rest_api_id = "${aws_api_gateway_rest_api.customers.id}"
  resource_id = "${aws_api_gateway_rest_api.customers.root_resource_id}"
  http_method = "${aws_api_gateway_method.method_main.http_method}"
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://petstore-demo-endpoint.execute-api.com/petstore/pets/"
  connection_type         = "INTERNET"

}





resource "aws_api_gateway_integration" "integration" {
  rest_api_id = "${aws_api_gateway_rest_api.customers.id}"
  resource_id = "${aws_api_gateway_resource.resource.id}"
  http_method = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://petstore-demo-endpoint.execute-api.com/petstore/pets/{proxy}"
  connection_type         = "INTERNET"
    
}

resource "aws_api_gateway_deployment" "live" {
  depends_on = ["aws_api_gateway_integration.integration"]

  rest_api_id = "${aws_api_gateway_rest_api.customers.id}"
  stage_name  = "live"
}







