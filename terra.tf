
variable "az"{
  type = "list"
  default = ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"]
}
variable "cidr"{
  type = "list"
  default = ["10.0.0.0/26","10.0.0.64/26","10.0.0.128/26","10.0.0.192/26"]
}
resource aws_vpc "vpc-1"{
  cidr_block = "10.0.0.0/24"
  tags = {
     name = "vpc-1"
   }
}
resource aws_subnet "sbn" {
  count = 3
  availability_zone = var.az[count.index]
  cidr_block        = var.cidr[count.index]
  vpc_id            = aws_vpc.vpc-1.id
  map_public_ip_on_launch = "true"
  tags = {
    name = "sbn"
  }
}
resource aws_internet_gateway "igw" {
  vpc_id = aws_vpc.vpc-1.id
  tags = {
    name = "igw"
  }
}
resource aws_route_table "rout" {
  vpc_id = aws_vpc.vpc-1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource aws_route_table_association "routatach" {
  count = 3
  subnet_id      = aws_subnet.sbn.*.id[count.index]
  route_table_id = aws_route_table.rout.id
}

resource aws_security_group "eks-sg" {
  name        = "eks-sg"
  description = "jenkis and ansible"
  vpc_id      = aws_vpc.vpc-1.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-sg"
  }
}
resource "aws_key_pair" "eks" {
  key_name   = "eks"
  public_key = file("./eks.sh") 
}

    resource aws_instance "i1" {
	ami           = "ami-0567f647e75c7bc05"
	instance_type = "t2.micro"
		   count =3
    subnet_id      = aws_subnet.sbn.*.id[count.index]
    vpc_security_group_ids = [aws_security_group.eks-sg.id]
	key_name      = "eks"
	
 }
 