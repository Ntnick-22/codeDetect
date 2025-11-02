# ============================================================================
# VPC - VIRTUAL PRIVATE CLOUD
# ============================================================================
# This creates your own isolated network in AWS
# Think of it as your own private section of AWS infrastructure
# ============================================================================

# ----------------------------------------------------------------------------
# VPC - Main Network
# ----------------------------------------------------------------------------
# Creates a Virtual Private Cloud - your own isolated network in AWS
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr  # IP range: 10.0.0.0/16 (65,536 IPs)

  # Enable DNS support (allows using domain names instead of IPs)
  enable_dns_hostnames = true  # Instances get public DNS names
  enable_dns_support   = true  # DNS resolution works in VPC

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

# ----------------------------------------------------------------------------
# INTERNET GATEWAY
# ----------------------------------------------------------------------------
# This allows your VPC to communicate with the internet
# Without this, your EC2 instance can't send/receive internet traffic
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # Attach to our VPC

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# ----------------------------------------------------------------------------
# PUBLIC SUBNETS
# ----------------------------------------------------------------------------
# Subnets are subdivisions of your VPC
# Public subnets = can access internet directly (for EC2)
# We create 2 subnets in different Availability Zones for redundancy

# Public Subnet 1 (Availability Zone A)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"  # 256 IPs (10.0.1.0 - 10.0.1.255)
  availability_zone = data.aws_availability_zones.available.names[0]  # First AZ

  # Automatically assign public IP to instances in this subnet
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-subnet-1"
      Type = "Public"
    }
  )
}

# Public Subnet 2 (Availability Zone B)
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"  # 256 IPs (10.0.2.0 - 10.0.2.255)
  availability_zone = data.aws_availability_zones.available.names[1]  # Second AZ

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-subnet-2"
      Type = "Public"
    }
  )
}

# ----------------------------------------------------------------------------
# ROUTE TABLE - PUBLIC
# ----------------------------------------------------------------------------
# Route tables control where network traffic is directed
# This route table sends internet traffic to the Internet Gateway

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route all internet traffic (0.0.0.0/0) to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"  # All IPs (the entire internet)
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
    }
  )
}

# Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# NETWORK EXPLANATION
# ============================================================================

# WHAT IS A VPC?
# - Your own isolated network in AWS
# - Like having your own private data center
# - Controls which resources can talk to each other

# WHAT IS A SUBNET?
# - A subdivision of your VPC
# - Typically one per Availability Zone (data center)
# - Public subnet = can access internet
# - Private subnet = can't access internet directly (more secure)

# WHAT IS AN INTERNET GATEWAY?
# - The door between your VPC and the internet
# - Allows EC2 instances to send/receive internet traffic
# - Required for any public-facing services

# WHAT IS A ROUTE TABLE?
# - Like a GPS for network traffic
# - Defines where traffic goes
# - 0.0.0.0/0 = "everything else" goes to internet

# WHY TWO SUBNETS?
# - High availability - if one data center fails, other continues
# - Required for some AWS services (like RDS, ALB)
# - Professional practice

# CIDR NOTATION EXPLAINED:
# - 10.0.0.0/16 = 65,536 IPs (entire VPC)
# - 10.0.1.0/24 = 256 IPs (one subnet)
# - /16, /24 are subnet masks (how many IPs)

# ============================================================================