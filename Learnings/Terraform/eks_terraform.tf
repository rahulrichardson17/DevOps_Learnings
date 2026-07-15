#create eks cluster using terraform

#EKS Cluster IAM Role
#control plane can manage cluster-related AWS resources.so that why this role is created.

resource "aws_iam_role" "eks_cluster_iam_role" {
  name = "role-eks-cluster"
  assume_role_policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "eks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    }
  )
}

#Attach eks cluster policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
#This policy grants the permissions required for the EKS control plane to operate.

# Create eks cluster
resource "aws_eks_cluster" "create_cluster" {
    name = "demo-cluster"
    role_arn = aws_iam_role.eks_cluster_iam_role.arn
    version = "1.31"

    vpc_config {
      subnet_ids = [
        aws_subnet.private_sn1.id,
        aws_subnet.private_sn2.id
      ]
    }
    depends_on = [ aws_iam_role_policy_attachment.eks_cluster_policy ]

}

#cluster created in private subnet bcz nodes should not be exposed out.
# node group iam role
resource "aws_iam_role" "nodegroup_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
                Allow = "sts:AssumeRole"
            }
        ]
    }
  )
}
# ec2.amazonaws.com is used here why bcz worker nodes are ec2 instances

# attach worker policies
#AmazonEKSWorkerNodePolicy (Allows the EC2 instances to join the cluster.)
resource "aws_iam_role_policy_attachment" "worker_policy_attchment" {
  role = aws_iam_role.nodegroup_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#AmazonEKSContainerRegisteryReadOnly (Allows pulling images from ECR)
resource "aws_iam_role_policy_attachment" "container_policy_attchment" {
  role = aws_iam_role.nodegroup_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#AmazonEKS_CNI_Policy (Allows the VPC CNI plugin to manage ENIs and IP addresses for Pods.)
resource "aws_iam_role_policy_attachment" "cni_policy_attchment" {
  role = aws_iam_role.nodegroup_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# create a managed node group
resource "aws_eks_node_group" "eks_node_group" {
    cluster_name = aws_eks_cluster.create_cluster.name
    node_group_name = "eks-worker-nodes"
    node_role_arn = aws_iam_role.nodegroup_role.arn

    subnet_ids = [
        aws_subnet.private_sn1.id,
        aws_subnet.private_sn2.id
    ]
    instance_types = ["t3.medium"]

    scaling_config {
      desired_size = 2
      min_size = 2
      max_size = 5
    }

    depends_on = [
        aws_iam_role_policy_attachment.worker_policy_attchment,
        aws_iam_role_policy_attachment.container_policy_attchment,
        aws_iam_role_policy_attachment.cni_policy_attchment
    ]
}
#It creates an EKS managed node group. AWS launches EC2 instances, 
# automatically joins them to the cluster, replaces unhealthy nodes, 
# and integrates them with Auto Scaling.
