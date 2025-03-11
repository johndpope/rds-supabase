# Supabase EC2 Instance Configuration

# Variable to enable/disable the Supabase server
variable "enable_supabase_server" {
  description = "Enable or disable the Supabase server instance"
  type        = bool
  default     = true
}

variable "supabase_instance_type" {
  description = "The instance type for the Supabase server"
  type        = string
  default     = "t2.medium"  # Recommended for Supabase as it needs more resources than the preprocessing server
}


resource "aws_route53_record" "kong_supabase" {
  count = var.enable_supabase_server ? 1 : 0
  
  zone_id = aws_route53_zone.private.zone_id
  name    = "kong.supabase.internal.${var.root_domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_network_interface.supabase_eni[count.index].private_ip]
}

# Create a static private IP for the Supabase server
resource "aws_network_interface" "supabase_eni" {
  count = var.enable_supabase_server ? 1 : 0

  subnet_id   = aws_subnet.mly_private["private_1"].id
  private_ips = ["10.0.4.15"]  # Assigning a static IP in the private_1 subnet CIDR
  security_groups = [
    aws_security_group.internal_only_container_ingress.id,
    aws_security_group.supabase_sg[0].id
  ]

  tags = {
    Name = "supabase-server-eni"
  }
}


# Security Group for Supabase
# Security Group for Supabase
# Security Group for Supabase
resource "aws_security_group" "supabase_sg" {
  count = var.enable_supabase_server ? 1 : 0
  
  vpc_id      = aws_vpc.mly.id
  name        = "supabase-server-sg"
  description = "Security Group for Supabase Server"

  # PostgreSQL
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "PostgreSQL database access"
  }

  # Kong API Gateway
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "Kong API Gateway"
  }

  # Kong Admin API
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "Kong Admin API"
  }

  # GoTrue Auth
  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "GoTrue Auth service"
  }

  # Supabase Studio and PostgREST (combined since they use the same port)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "Supabase Studio and PostgREST API"
  }

  # Realtime
  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "Realtime API"
  }

  # Storage API
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "Storage API"
  }

  # PgBouncer (Connection Pooler)
  ingress {
    from_port   = 6543
    to_port     = 6543
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    description = "PgBouncer connection pooler"
  }

  # Docker inter-container communication within the security group
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all traffic between containers in the same security group"
  }

  # Allow outbound to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "supabase-server-sg"
    Environment = var.stack_name
    Service     = "Supabase"
  }
}


# Supabase EC2 Cloud-Init Configuration
data "template_cloudinit_config" "supabase_config" {
  gzip          = true
  base64_encode = true



  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      runcmd:
        - mkdir -p /opt/setup /etc/zsh
        - chmod 755 /opt/setup /etc/zsh
        - chmod +x /var/lib/cloud/instance/scripts/*.sh
        - echo "Contents of 01a_setup_git.sh:" >> /var/log/cloud-init-debug.log
        - cat /var/lib/cloud/instance/scripts/01a_setup_git.sh >> /var/log/cloud-init-debug.log
        - /var/lib/cloud/instance/scripts/setup_zsh.sh
        - /var/lib/cloud/instance/scripts/refresh_credentials.sh
        - /var/lib/cloud/instance/scripts/remove_apache.sh
        - /var/lib/cloud/instance/scripts/01_install_docker.sh
        - /var/lib/cloud/instance/scripts/01a_setup_git.sh
        - echo "Contents of clone_mly_supabase.sh:" >> /var/log/cloud-init-debug.log
        - cat /var/lib/cloud/instance/scripts/clone_mly_supabase.sh >> /var/log/cloud-init-debug.log
        - /var/lib/cloud/instance/scripts/clone_mly_supabase.sh
        - /var/lib/cloud/instance/scripts/03_setup_cloudwatch.sh
        - /var/lib/cloud/instance/scripts/04_setup_motd.sh

        # Wait for cloud-init to complete before starting services
        - cloud-init status --wait
        
        # Start services
        - systemctl enable amazon-cloudwatch-agent
        - systemctl start amazon-cloudwatch-agent
 
        # Final permissions
        - chown -R ec2-user:ec2-user /home/ec2-user

        # Additional configuration for Docker
        - systemctl enable docker
        - systemctl start docker

        
    EOF
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "remove_apache.sh"
    content      = file("${path.module}/scripts/setup/remove_apache.sh")
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "setup_zsh.sh"
    content      = file("${path.module}/scripts/setup/setup_zsh.sh")
  }



  # Part 2: Docker Installation Script
  part {
    content_type = "text/x-shellscript"
    filename     = "01_install_docker.sh"
    content      = file("${path.module}/scripts/setup/install_docker.sh")
  }

  # Part 6: Git repository setup
  part {
    content_type = "text/x-shellscript"
    filename     = "01a_setup_git.sh"
    content      = templatefile("${path.module}/scripts/setup/git_setup.sh.tpl", {
      github_token = var.github_token
      repos = []
    })
  }
  part {
    content_type = "text/x-shellscript"
    filename     = "refresh_credentials.sh"
    content = templatefile("${path.module}/scripts/setup/supabase-credentials.sh.tpl", {
      aws_region          = var.aws_region
      account_id          = data.aws_caller_identity.current.account_id
      stack_name          = local.stack_name
      database_name       = local.database_name
      s3_bucket           = var.s3_db_dump_bucket
      s3_key              = var.s3_db_dump_key
      github_token        = var.github_token
      db_writer_endpoint = local.db_writer_endpoint
      db_reader_endpoint = local.db_reader_endpoint
      
      # Supabase PostgreSQL variables (only used when use_postgres is true)
      use_postgres        = var.use_postgres
      pg_endpoint         = var.use_postgres ? aws_db_instance.mly_pg_database[0].endpoint : ""
      pg_database_name    = var.use_postgres ? aws_db_instance.mly_pg_database[0].db_name : ""
      root_domain_name    = var.root_domain_name
    })

  }





  # Part 3: Supabase Setup Script
  part {
    content_type = "text/x-shellscript"
    filename     = "clone_mly_supabase.sh"
    content      = <<-EOF
      #!/bin/bash
    
    # Install required packages
      dnf update -y
      dnf install -y nginx zsh git util-linux-user 

      # install postgresql17 manually - https://github.com/amazonlinux/amazon-linux-2023/issues/860
      sudo dnf install -y gcc readline-devel libicu-devel zlib-devel openssl-devel
      sudo dnf install -y bison flex perl-FindBin perl-File-Compare
      wget https://ftp.postgresql.org/pub/source/v17.4/postgresql-17.4.tar.gz
      tar -xvzf postgresql-17.4.tar.gz
      cd postgresql-17.4
      ./configure --bindir=/usr/bin --with-openssl
      sudo make -C src/bin install
      sudo make -C src/include install
      sudo make -C src/interfaces install


      export GH_TOKEN="${var.github_token}"
      rm -rf /home/ec2-user/mly-supabase   

      source /etc/profile.d/mly_env.sh # get the Postgres credentials
      gh repo clone Mailopoly/mly-supabase /home/ec2-user/mly-supabase
      /home/ec2-user/mly-supabase/cloud_init.sh # this should bootstrap db / user / supabase admin 
      cd /home/ec2-user/mly-supabase/docker 
      docker-compose up -d
      # Additional command to verify the service status
      docker-compose ps
      
    EOF
  }


  # Part 4: CloudWatch Agent Configuration
  part {
    content_type = "text/x-shellscript"
    filename     = "03_setup_cloudwatch.sh"
    content      = file("${path.module}/scripts/setup/cloudwatch_agent_supabase.sh")
  }

  # Part 5: MOTD setup script
  part {
    content_type = "text/x-shellscript"
    filename     = "04_setup_motd.sh"
    content      = file("${path.module}/scripts/motd/supabase_motd.sh")
  }
}

# EC2 Instance for Supabase
resource "aws_instance" "supabase_server" {
  count = var.enable_supabase_server ? 1 : 0

  ami           = "ami-0523420044a1cd2b1"  # Amazon Linux 2023
  instance_type = var.supabase_instance_type
  
  # Use the same IAM role as the preprocessor for consistency
  iam_instance_profile = aws_iam_instance_profile.ssh_profile.name
  user_data_base64     = data.template_cloudinit_config.supabase_config.rendered

  # Attach the ENI to the instance
  network_interface {
    network_interface_id = aws_network_interface.supabase_eni[count.index].id
    device_index         = 0
  }

  # Larger root volume for Supabase (database storage)
  root_block_device {
    volume_size = 200  # GB - larger for Supabase databases
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "supabase-server"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_network_interface.supabase_eni,
    aws_db_instance.mly_pg_database 
  ]
}

# Instance health check
resource "null_resource" "supabase_instance_ready" {
  count = var.enable_supabase_server ? 1 : 0

  depends_on = [aws_instance.supabase_server]

  provisioner "local-exec" {
    command = <<-EOF
      aws ec2 wait instance-status-ok \
        --instance-ids ${aws_instance.supabase_server[count.index].id} \
        --region ${var.aws_region}
      
      # Verify cloud-init completion
      aws ssm send-command \
        --instance-ids ${aws_instance.supabase_server[count.index].id} \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cloud-init status --wait --long", "cat /var/log/cloud-init-output.log"]' \
        --region ${var.aws_region}
    EOF
  }
}


resource "aws_route53_record" "supabase_a_record" {
  zone_id = aws_route53_zone.root_domain.zone_id
  name    = "supabase.${var.root_domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.proxy.public_ip]
}

# # DNS record for Supabase server using the static IP
# resource "aws_route53_record" "supabase" {
#   count = var.enable_supabase_server ? 1 : 0
  
#   zone_id = aws_route53_zone.private.zone_id
#   name    = "supabase." # will create supabase.prod.aws.mailopoly.com
#   type    = "A"
#   ttl     = "300"
#   records = [aws_network_interface.supabase_eni[count.index].private_ip]
# }

# Output the Supabase server information
output "supabase_static_ip" {
  description = "Static private IP address of the Supabase server"
  value       = var.enable_supabase_server ? aws_network_interface.supabase_eni[0].private_ip : null
}

output "supabase_dns" {
  description = "Internal DNS name of the Supabase server"
  value       = var.enable_supabase_server ? aws_route53_record.supabase_a_record.fqdn : null
}

