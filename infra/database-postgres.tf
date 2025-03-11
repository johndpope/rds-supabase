# Define the variable (assumed to be defined elsewhere, e.g., in variables.tf)
variable "use_postgres" {
  description = "Whether to deploy PostgreSQL resources"
  type        = bool
  default     = false # Optional default; set to false if you want it off by default
}

# Single RDS Instance for non-cluster environments
# Generate random password for database
resource "random_password" "sp_pg_database_password" {
  count            = var.use_postgres ? 1 : 0 # Only create if use_postgres is true
  length           = 41
  special          = false
  override_special = "!@#$%^&*()_+-=[]{}|;:,.<>?"
}

# Create Secrets Manager secret for database credentials
resource "aws_secretsmanager_secret" "sp_pg_database_creds" {
  count                   = var.use_postgres ? 1 : 0
  name                    = "sp_pg_database_creds"
  description             = "PostgreSQL database credentials for sp-${local.stack_name}"
  recovery_window_in_days = 0
  
  tags = {
    Name = "sp-${local.stack_name}-pg-creds"
  }
}

# Create secret version with initial credentials
resource "aws_secretsmanager_secret_version" "sp_pg_database_creds" {
  count         = var.use_postgres ? 1 : 0
  secret_id     = aws_secretsmanager_secret.sp_pg_database_creds[0].id # Index 0 since count is used
  secret_string = jsonencode({
    username = "sppg_admin"
    password = random_password.sp_pg_database_password[0].result
  })
}

# Data source to read the secret
data "aws_secretsmanager_secret_version" "sp_pg_database_creds" {
  count      = var.use_postgres ? 1 : 0
  secret_id  = aws_secretsmanager_secret.sp_pg_database_creds[0].id
  depends_on = [aws_secretsmanager_secret_version.sp_pg_database_creds]
}

# Create a custom parameter group for PostgreSQL with replication settings
resource "aws_db_parameter_group" "sp_pg_params_ok" {
  count       = var.use_postgres ? 1 : 0
  name        = "sp-pg-params"
  family      = "postgres17"
  description = "Custom parameter group for PostgreSQL with replication and pg_stat_statements enabled"

  # Add pglogical and pg_stat_statements to shared_preload_libraries
  parameter {
    name         = "shared_preload_libraries"
    value        = "pglogical,pg_stat_statements"  # Comma-separated list
    apply_method = "pending-reboot"
  }

  # Set logical replication parameter
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Disable forced SSL connections (if needed)
  parameter {
    name         = "rds.force_ssl"
    value        = "0"
    apply_method = "immediate"
  }

  # Maximum number of WAL sender processes
  parameter {
    name         = "max_wal_senders"
    value        = "10"
    apply_method = "pending-reboot"
  }

  # Maximum number of replication slots
  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "pending-reboot"
  }

  # Logging parameters
  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  # Optional pg_stat_statements tuning parameters
  parameter {
    name         = "pg_stat_statements.max"
    value        = "10000"  # Max number of statements tracked
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pg_stat_statements.track"
    value        = "all"  # Track all statements (top, all, none)
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pg_stat_statements.track_utility"
    value        = "on"  # Track utility commands (e.g., VACUUM)
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "sp-pg-params-${local.stack_name}"
  }
}

# Ensure the extension is created after the RDS instance is ready
resource "null_resource" "enable_pg_stat_statements" {
  count = var.use_postgres ? 1 : 0

  depends_on = [aws_db_instance.sp_pg_database]

  provisioner "local-exec" {
    command = <<-EOF
      # Wait for RDS instance to be available
      aws rds wait db-instance-available \
        --db-instance-identifier sp-pg-${local.stack_name} \
        --region ${var.aws_region}

      # Create the pg_stat_statements extension
      psql "postgresql://${jsondecode(data.aws_secretsmanager_secret_version.sp_pg_database_creds[0].secret_string)["username"]}:${jsondecode(data.aws_secretsmanager_secret_version.sp_pg_database_creds[0].secret_string)["password"]}@${aws_db_instance.sp_pg_database[0].endpoint}/${local.database_name}" \
        -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    EOF
  }
}


# RDS instance with replication enabled
resource "aws_db_instance" "sp_pg_database" {
  count                  = var.use_postgres ? 1 : 0
  identifier             = "sp-pg-${local.stack_name}"
  engine                 = "postgres"
  engine_version         = "17"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100

  db_name                = local.database_name
  username               = var.use_postgres ? jsondecode(data.aws_secretsmanager_secret_version.sp_pg_database_creds[0].secret_string)["username"] : null
  password               = var.use_postgres ? jsondecode(data.aws_secretsmanager_secret_version.sp_pg_database_creds[0].secret_string)["password"] : null

  db_subnet_group_name   = var.use_postgres ? aws_db_subnet_group.sp_pg_database[0].name : null
  vpc_security_group_ids = var.use_postgres ? [aws_security_group.sp_pg_database[0].id] : []
  
  # Apply the custom parameter group
  parameter_group_name   = var.use_postgres ? aws_db_parameter_group.sp_pg_params_ok[0].name : null

  skip_final_snapshot    = true
  backup_retention_period = 7
  backup_window          = "02:00-03:00"

  storage_type          = "gp2"
  multi_az              = false  # Consider setting to true for production for high availability
  publicly_accessible   = true

  # Disable performance insights to reduce costs
  performance_insights_enabled = false

  # Enable replication from this instance
  # This allows the instance to be a source for replication
  allow_major_version_upgrade = true

  
  # Set master username and password through already defined parameters

  tags = {
    Name = "sp-pg-${local.stack_name}"
  }

  lifecycle {
    create_before_destroy = true
    # Trigger a reboot when the parameter group changes
    ignore_changes = [parameter_group_name]  # Prevents recreation, but allows manual reboot
  }
}

# Subnet group for RDS
resource "aws_db_subnet_group" "sp_pg_database" {
  count      = var.use_postgres ? 1 : 0
  name       = "sp-${local.stack_name}-pg-subnet-group"
  subnet_ids = values(aws_subnet.sp_private)[*].id

  tags = {
    Name = "sp-${local.stack_name}-pg-subnet-group"
  }
}

# Security group for RDS with replication port allowed
resource "aws_security_group" "sp_pg_database" {
  count       = var.use_postgres ? 1 : 0
  vpc_id      = aws_vpc.sp.id
  name        = "sp_${local.stack_name}-pg-db"
  description = "Permits public access to PostgreSQL database with replication enabled"
  
  # Allow standard PostgreSQL access from anywhere (typical for dev environments)
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    description = "PostgreSQL standard port access"
  }
  
  # Specific ingress rule for the Supabase EC2 instance
  ingress {
    description = "PostgreSQL access from Supabase EC2 instance"
    cidr_blocks = ["10.0.4.15/32"]  # The IP of your Supabase EC2 instance
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
  }

  # Specific ingress rule for the entire VPC CIDR
  ingress {
    description = "PostgreSQL access from VPC"
    cidr_blocks = [aws_vpc.sp.cidr_block]  # The CIDR block of your VPC
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 1024
    to_port     = 65535
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "sp-${local.stack_name}-pg"
  }
}

# Outputs (conditional to avoid errors when resources aren't created)
output "db_endpoint" {
  description = "The endpoint of the PostgreSQL database"
  value       = var.use_postgres ? aws_db_instance.sp_pg_database[0].endpoint : null
}

output "db_port" {
  description = "The port of the PostgreSQL database"
  value       = var.use_postgres ? aws_db_instance.sp_pg_database[0].port : null
}

output "db_name" {
  description = "The name of the PostgreSQL database"
  value       = var.use_postgres ? aws_db_instance.sp_pg_database[0].db_name : null
}

# Commented username output (kept as-is)
# output "db_username" {
#   description = "The username for the PostgreSQL database"
#   value       = var.use_postgres ? aws_db_instance.sp_pg_database[0].username : null
# }

output "db_credentials_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing database credentials"
  value       = var.use_postgres ? aws_secretsmanager_secret.sp_pg_database_creds[0].arn : null
}

output "db_connection_string" {
  description = "PostgreSQL connection string (excluding password)"
  value       = var.use_postgres ? "postgresql://${aws_db_instance.sp_pg_database[0].username}@${aws_db_instance.sp_pg_database[0].endpoint}/${aws_db_instance.sp_pg_database[0].db_name}" : null
  sensitive   = true
}