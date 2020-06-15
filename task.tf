provider "aws" {
  region = "ap-south-1"
  profile = "default"
}



resource "aws_security_group" "http_sg" {
  name        = "http_sg"
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "http_sg"
  }
}



resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name 	=  "arunawskey"
  security_groups = [ "http_sg" ]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Downloads/arunawskey.pem")
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
    Name = "TaskOS"
  }
}



resource "aws_ebs_volume" "EBS" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "myEBS"
  }
}



resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.EBS.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}



output "instance_ip" {
	value = aws_instance.web.public_ip
}



resource "null_resource" "nulllocal"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote"  {
 depends_on = [
    aws_volume_attachment.ebs_attach,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Downloads/arunawskey.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/notarunkumar/terraform-aws.git /var/www/html/"
    ]
  }
}



output "ebs_name" {
	value = aws_ebs_volume.EBS.id
}



resource "null_resource" "nulllocal2"  {
  provisioner "local-exec" {
      command = "git clone https://github.com/notarunkumar/terraform-aws.git ./gitcode"
    }
}  



resource "aws_s3_bucket" "corruptgenius" {
  bucket = "corruptbucket"
  acl    = "public-read"
  tags = {
      Name = "corruptgenius"
      Environment = "Dev"
  }
}



output "bucket" {
  value = aws_s3_bucket.corruptgenius
}



resource "aws_s3_bucket_object" "bucket_obj" {
  bucket = "${aws_s3_bucket.corruptgenius.id}"
  key    = "Arun.jpg"
  source = "./gitcode/Arun.jpg"
  acl	 = "public-read"
}



resource "aws_cloudfront_distribution" "cfd" {
  origin {
    domain_name = "${aws_s3_bucket.corruptgenius.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.corruptgenius.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.corruptgenius.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_s3_bucket.corruptgenius
  ]
}



resource "aws_ebs_snapshot" "ebs_snapshot" {
  volume_id   = "${aws_ebs_volume.EBS.id}"
  
  tags = {
    Name = "EBS_Snapshot"
    env = "Production"
  }

  depends_on = [
    aws_volume_attachment.ebs_attach
  ]
}