variable "clsr" {
  default = "terraform-eks-demo"
  type    = "string"
}
variable "az"{
  type = "list"
  default = ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"]
}
variable "cidr"{
  type = "list"
  default = ["10.0.0.0/26","10.0.0.64/26","10.0.0.128/26","10.0.0.192/26"]
}
resource aws_vpc "vpc-1" {
  cidr_block = "10.0.0.0/24"
  tags = 
   name = "vpc-1"
}
