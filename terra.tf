

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
  description = "Cluster communication with worker nodes"
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
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}
resource "aws_eks_cluster" "aws_eks" {
  depends_on = [aws_cloudwatch_log_group.eks-cw]
  name     = "aws_eks"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
     subnet_ids      = aws_subnet.sbn.*.id
     vpc_id      = aws_vpc.vpc-1.id
	 security_group_ids = [aws_security_group.eks-sg.id]

  }

  tags = {
    Name = "aws_eks"
  }
}
resource aws_iam_role "eks_nodes" {
  name = "eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource aws_iam_role_policy_attachment "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource aws_iam_role_policy_attachment "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource aws_iam_role_policy_attachment "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}
resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = file("./eks.sh") 
}
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = "ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.sbn[*].id
  disk_size       = 20
  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }
}


data "aws_eks_cluster" "cluster" {
  name = "aws_eks"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "aws_eks"
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate =        base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  
}
output "identity-oidc-issuer" {
  value = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
resource "kubernetes_pod" "nginx" {
  metadata {
    name = "pod1"
    labels ={
      App = "nginx"
     }
 }
  spec {
    container {
      image = "nginx"
      name  = "c1"

      port {
        container_port = 80
      }
    }
  }
 }
resource "kubernetes_service" "nginx" {
  metadata {
    name = "sv1"
  }
  spec {
    selector = {
      App = kubernetes_pod.nginx.metadata.0.labels.App
     }
    port {
      port = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
resource "aws_cloudwatch_log_group" "eks-cw" {
  name = "eks-cw"
}
resource "aws_cloudwatch_log_metric_filter" "cw-m" {
  name           = "cw-m"
  pattern        = "Error"
  log_group_name = aws_cloudwatch_log_group.eks-cw.name

  metric_transformation {
    name      = "ErrorCount"
    namespace = "ms"
    value     = "1"
  }
}
resource "aws_iam_policy" "eks-metric-policy" {
  name   = "eks-metric-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "eks-cw-policy" {
   policy_arn = aws_iam_policy.eks-metric-policy.arn
   role       = aws_iam_role.eks_cluster.name
}
resource "aws_cloudwatch_log_stream" "log-sterem" {
  name           = "SampleLogStream1234"
  log_group_name = aws_cloudwatch_log_group.eks-cw.name
}

resource "aws_sns_topic" "user_updates" {
  name            = "user-updates-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}
resource "aws_sns_topic_subscription" "user_updates_sns_target" {
  topic_arn = "arn:aws:sns:ap-southeast-1:537012884892:user-updates-topic"
  protocol  = "email"
  endpoint  = "malleshdonadula122@gmail.com"
}
resource "aws_cloudwatch_metric_alarm" "app-health-alarm" {
  alarm_name                = "app-health-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "ApplicationComponetHealthRequestFailing"
  namespace                 = "ApplicationComponetHealth"
  period                    = "300"
  statistic                 = "Average"
  dimensions                = {
            node_group_name = "ng"
                     }
  threshold                 = "1"
  alarm_description         = "Checks the health of the app"
  datapoints_to_alarm       = "2"
  alarm_actions             = ["arn:aws:sns:ap-southeast-1:537012884892:user-updates-topic"]
}                      
 