# EKS and EC2 Terraform

This root configuration provisions a VPC with public and private subnets, an
Amazon EKS control plane, a managed worker node group in the private subnets,
and a private administrative EC2 instance managed through AWS Systems Manager
(SSM) Session Manager. The bastion has no public IP or inbound SSH rule.

## Sizing and cost

- The managed node group uses two `t3.medium` workers by default (2 vCPU and
  4 GiB memory each), with autoscaling between one and two nodes. This is a
  modest burstable starting point for a development/demo cluster. Two desired
  nodes allow workloads to be spread across the configured Availability Zones;
  the minimum of one reduces worker compute cost when scaling down, but reduces
  capacity and resilience.
- The SSM administrative instance uses `t3.micro`, which is sufficient for
  occasional command-line administration. It can be stopped or removed when
  not needed, subject to the desired Terraform state.
- A single NAT Gateway is enabled so private workers and the private admin
  instance can reach AWS services and download required images/updates. One
  gateway is cheaper than one per Availability Zone but is a single-AZ
  dependency. NAT Gateway hourly and data-processing charges can be significant
  for a small development environment.
- EKS has a separate hourly control-plane charge. Worker EC2, NAT Gateway,
  EBS volumes, public IPv4 addresses, and data transfer add to the bill.
  `t3.medium` is a low-cost pilot starting size, not a production capacity
  recommendation. Check current `ap-south-1` prices in the AWS Pricing
  Calculator before applying; stop or destroy test environments when idle.

## Configure and deploy

Use Terraform 1.5 or newer, AWS credentials for the target account, and the
AWS region configured in `terraform.tfvars`. Set the administrator's current
public IPv4 address as a `/32`; this is required and restricts the EKS public
API endpoint:

```sh
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com | tr -d '\n')/32"
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Do not use `0.0.0.0/0` for the admin CIDR. The public API allowlist is tied to
the address supplied during planning; update it if that address changes.

## Verify access and nodes

Use the AWS IAM identity that created the cluster (or an identity granted EKS
cluster access) and install AWS CLI v2 plus `kubectl`:

```sh
aws eks update-kubeconfig --region ap-south-1 --name titanops-dev-eks
kubectl get nodes
```

The nodes should become `Ready` after the managed node group finishes creating.
If they do not, inspect the node-group health issues in the EKS console or with
`aws eks describe-nodegroup`.

The private admin instance is reachable without SSH keys or inbound ports.
Administrators need IAM permission to start an SSM session:

```sh
INSTANCE_ID="$(terraform -chdir=terraform output -raw bastion_instance_id)"
aws ssm start-session --target "$INSTANCE_ID" --region ap-south-1
```

The bastion is intended for private administration. Its security group is
allowed to reach the EKS private API endpoint; direct `kubectl` access from an
administrator's workstation uses the restricted EKS public endpoint.
