provider "aws" {
  region     = "ap-south-1"
  profile    = "bhavan"
}


resource "aws_key_pair" "deployer" {
  key_name   = "key444"
  public_key = file("C:/Users/user/key1.pub")
}

resource "aws_security_group" "ssh_http_allowed" {
  name        = "ssh_http_allowed"
  vpc_id      = "vpc-7dd0cc15"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh_http_allowed"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "key444"
  security_groups = ["ssh_http_allowed"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/user/key1")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "bhavanos1"
  }

}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "bhavanebs1"
  }
}

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "bhavanos1_ip" {
  value = aws_instance.web.public_ip
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/user/key1")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/BhavanKumar05/cloud.git   /var/www/html/"
    ]
  }
}


resource "aws_s3_bucket" "taskbucket" {
  bucket = "bhavanbucket444"
  acl    = "private"
  region = "ap-south-1"
  force_destroy = "true"
  versioning {
          enabled = true
}
  tags = {
    Name        = "bhavanbucket444"
  }
}

resource "null_resource" "local-1"  {
	depends_on = [aws_s3_bucket.taskbucket,]
	provisioner "local-exec" {
              command = "git clone https://github.com/BhavanKumar05/cloud.git"
  	}
}



resource "aws_s3_bucket_object" "file_upload" {
	depends_on = [aws_s3_bucket.taskbucket , null_resource.local-1]
	bucket = aws_s3_bucket.taskbucket.id
        key = "cloudtask.png"    
	source = "C:/Users/user/Desktop/terra/cloud/cloudtask.png"
    	acl = "public-read"
}

locals {
 s3_origin_id = "s3-bhavanbucket444-id"
}


resource "aws_cloudfront_distribution" "terra_cloudfront" {
	depends_on = [aws_s3_bucket.taskbucket , null_resource.local-1 ]
	origin {
		domain_name = aws_s3_bucket.taskbucket.bucket_regional_domain_name
		origin_id   = local.s3_origin_id


		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}
 
	enabled = true
        is_ipv6_enabled = true


	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = local.s3_origin_id
 
		forwarded_values {
			query_string = false
 
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
	}
 
	restrictions {
		geo_restriction {
 
			restriction_type = "none"
		}
	}
 
	viewer_certificate {
		cloudfront_default_certificate = true
	}
}


output "domain-name" {
	value = aws_cloudfront_distribution.terra_cloudfront.domain_name
}


resource "null_resource" "nulllocal1"  {


depends_on = [aws_cloudfront_distribution.terra_cloudfront,]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web.public_ip}"
  	}
}



