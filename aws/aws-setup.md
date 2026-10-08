# AWS Infrastructure & Security Architecture Setup

This document details the architectural design, networking layout, security group definitions, IAM role permissions, and database connectivity for hosting the **Todo Summary Assistant** application on AWS.

---

## 1. Network Topology & VPC Design

The infrastructure is provisioned within a dedicated **Virtual Private Cloud (VPC)** (`10.0.0.0/16`) spanning across two Availability Zones (AZs) for high availability and fault isolation.

```
+-----------------------------------------------------------------------------------+
| AWS VPC (10.0.0.0/16)                                                             |
|                                                                                   |
|  +-------------------------------------+   +-----------------------------------+  |
|  | Public Subnet 1 (10.0.1.0/24) AZ-a    |   | Public Subnet 2 (10.0.2.0/24) AZ-b|  |
|  |  +-------------------------------+  |   |                                   |  |
|  |  | EC2 Instance (t3.micro)       |  |   |  Internet Gateway (IGW)           |  |
|  |  | - Frontend (React / Port 3000)|  |   |  Routes 0.0.0.0/0 to Internet     |  |
|  |  | - Backend (Spring / Port 8080)|  |   |                                   |  |
|  |  | - Prometheus (Port 9090)      |  |   +-----------------------------------+  |
|  |  | - Grafana (Port 3001)         |  |                                          |
|  |  +-------------------------------+  |                                          |
|  +-------------------------------------+                                          |
|                                                                                   |
|  +-------------------------------------+   +-----------------------------------+  |
|  | Private Subnet 1 (10.0.10.0/24) AZ-a  |   | Private Subnet 2 (10.0.11.0/24)AZ-b|  |
|  |  +-------------------------------+  |   |  +-----------------------------+  |
|  |  | AWS RDS MySQL (Primary)       |<=====>|  | AWS RDS Standby Replica    |  |
|  |  | (port 3306, non-public)       |  |   |  | (Multi-AZ failover target)  |  |
|  |  +-------------------------------+  |   |  +-----------------------------+  |
|  +-------------------------------------+   +-----------------------------------+  |
+-----------------------------------------------------------------------------------+
```

### Subnet Breakdown
1. **Public Subnets (`10.0.1.0/24` & `10.0.2.0/24`)**:
   - Attached to an Internet Gateway (`igw`).
   - Hosts the EC2 instance running application and monitoring containers.
   - Assigns automatic public IPv4 address for ingress web traffic.

2. **Private Subnets (`10.0.10.0/24` & `10.0.11.0/24`)**:
   - Has **no** route to the Internet Gateway.
   - Hosts the AWS RDS MySQL database cluster.
   - Prevents external accessibility to database endpoints.

---

## 2. Security Groups & Network Access Control

Network access control is enforced through two restrictive stateful Security Groups:

### A. EC2 Application Security Group (`todo-ec2-sg`)
Restricts inbound traffic strictly to required ports and administrative IP ranges:

| Direction | Port / Protocol | Source CIDR / Target | Purpose |
| :--- | :--- | :--- | :--- |
| Inbound | `TCP / 22` | Admin Public IP (e.g. `203.0.113.50/32`) | Restricted SSH Management |
| Inbound | `TCP / 80` | `0.0.0.0/0` | Public Web Traffic (HTTP) |
| Inbound | `TCP / 443` | `0.0.0.0/0` | Public Web Traffic (HTTPS) |
| Inbound | `TCP / 8080` | `0.0.0.0/0` | Spring Boot REST API & Healthchecks |
| Inbound | `TCP / 3000` | `0.0.0.0/0` | React Web Application |
| Inbound | `TCP / 9090` | Admin IP / VPN | Prometheus UI |
| Inbound | `TCP / 3001` | Admin IP / VPN | Grafana Dashboards |
| Outbound | `ALL` | `0.0.0.0/0` | Outbound updates & Cohere/Slack API calls |

### B. RDS Database Security Group (`todo-rds-sg`)
Enforces strict multi-tier access isolation:

| Direction | Port / Protocol | Source | Purpose |
| :--- | :--- | :--- | :--- |
| Inbound | `TCP / 3306` | `todo-ec2-sg` (Security Group ID) | MySQL traffic ONLY from EC2 |
| Outbound | `N/A` | `0.0.0.0/0` | Blocked / Disabled |

> **Key Security Guarantee**: The RDS database is **not** assigned a public IP (`publicly_accessible = false`) and rejects all requests originating outside the EC2 security group.

---

## 3. IAM Configuration (Zero Hardcoded Keys)

To adhere to the principle of least privilege, the EC2 host does **not** use static AWS Access Keys (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). Instead, an IAM Role and Instance Profile are attached directly to the EC2 instance:

- **IAM Role Name**: `todo-ec2-instance-role`
- **IAM Instance Profile**: `todo-ec2-instance-profile`
- **Managed Policies Attached**:
  - `AmazonSSMManagedInstanceCore`: Enables AWS Systems Manager Session Manager for secure, keyless terminal access over HTTPS.
  - `CloudWatchAgentServerPolicy`: Allows pushing container metrics and application logs to AWS CloudWatch.
  - `AmazonEC2ContainerRegistryReadOnly`: Allows pulling container images from AWS ECR if used as registry.

---

## 4. DB Credentials & Secrets Management

Application secrets (Database passwords, Cohere API Key, Slack Webhook URL) are managed outside source code:

1. **Local & Staging**: Injected at container runtime via `.env` / environment variables.
2. **Production on AWS**:
   - Stored securely in **AWS Systems Manager Parameter Store** (SecureString) or **AWS Secrets Manager**:
     - `/todo-app/prod/SPRING_DATASOURCE_URL`
     - `/todo-app/prod/SPRING_DATASOURCE_USERNAME`
     - `/todo-app/prod/SPRING_DATASOURCE_PASSWORD`
     - `/todo-app/prod/COHERE_API_KEY`
     - `/todo-app/prod/SLACK_WEBHOOK_URL`
   - Retrieved by the EC2 startup script or CI/CD deployment runner via IAM permissions.

---

## 5. Deployment Instructions via Terraform

1. Change directory to IaC directory:
   ```bash
   cd aws/iac
   ```
2. Initialize Terraform modules and providers:
   ```bash
   terraform init
   ```
3. Create `terraform.tfvars` from example file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit db_password and admin_ssh_cidr in terraform.tfvars
   ```
4. Preview infrastructure deployment plan:
   ```bash
   terraform plan
   ```
5. Apply and provision resources on AWS:
   ```bash
   terraform apply -auto-approve
   ```
6. Note down the outputs (`ec2_public_ip`, `rds_endpoint`).

---

## 6. Resource Cleanup & Cost Management (Post-Review Teardown)

To avoid incurring unexpected charges after reviewing or testing the infrastructure:

1. Navigate to the IaC directory:
   ```bash
   cd aws/iac
   ```
2. Destroy all provisioned AWS resources (VPC, EC2, RDS instance, Security Groups, IAM Roles):
   ```bash
   terraform destroy -auto-approve
   ```
3. Verify in the AWS Management Console that the EC2 instance and RDS database are fully terminated.
