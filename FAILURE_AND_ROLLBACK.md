# Failure and Rollback Operations Guide

This document outlines standard operating procedures (SOPs), emergency incident responses, recovery mechanisms, and disaster scenarios for the **Todo Summary Assistant** platform.

---

## Scenario 1: A Faulty Version is Deployed. How Do You Roll Back?

### 1. Automated Pipeline Rollback (Immediate)
The GitHub Actions CI/CD deployment job includes an automated post-deployment HTTP health check (`curl -f http://localhost:8080/actuator/health`).
- If the health check fails within the 60-second grace window, the pipeline triggers `docker compose rollback` or re-deploys the previous image tag (`IMAGE_TAG=$PREVIOUS_SHA`).
- The pipeline aborts with exit code `1`, notifying the engineering team via GitHub Actions and Slack alerts.

### 2. Manual Emergency Rollback (SSH Access)
If a non-fatal logic bug is discovered post-deployment that passes synthetic health checks:
1. Connect to the EC2 host via SSH or AWS SSM Session Manager:
   ```bash
   aws ssm start-session --target i-0123456789abcdef0
   ```
2. Navigate to the application root:
   ```bash
   cd /opt/todo-app
   ```
3. Update `IMAGE_TAG` to the previous known stable Git commit SHA:
   ```bash
   export IMAGE_TAG=a1b2c3d4  # Known good commit SHA
   docker compose up -d backend frontend
   ```
4. Confirm application container health:
   ```bash
   docker compose ps
   curl http://localhost:8080/actuator/health
   ```

---

## Scenario 2: The Application Crashes After Deployment. What Happens?

1. **Docker Container Auto-Restart Policy**:
   All container definitions in `docker-compose.yml` specify `restart: always`. Docker Daemon automatically attempts to restart crashed container processes up to system limits.
2. **Prometheus Monitoring & Alert Trigger**:
   - Prometheus scrapes `/actuator/prometheus` every 10 seconds.
   - If the backend crashes, `up{job="spring-boot-backend"}` drops to `0`.
   - The `BackendServiceDown` alert fires within 60 seconds, sending notifications to PagerDuty/Slack.
3. **Log Extraction & Incident Diagnosis**:
   Operations engineers extract container logs to diagnose runtime exceptions:
   ```bash
   docker logs --tail 200 todo-backend
   ```
4. **Rollback Execution**:
   If the crash is unrecoverable (e.g. fatal `NullPointerException` or database schema mismatch), the on-call engineer executes the manual rollback procedure detailed in Scenario 1.

---

## Scenario 3: The CI/CD Tool is Unavailable. Can You Still Deploy?

**Yes.** Deployments can be performed manually via Emergency Direct Deployment:

1. **Local Container Image Build**:
   Developer builds and tags multi-stage Docker images locally:
   ```bash
   docker build -t your-dockerhub-user/todo-backend:v1.0.1 ./Backend/todo-summary-assistant
   docker build -t your-dockerhub-user/todo-frontend:v1.0.1 ./Frontend/todo
   ```
2. **Push to Container Registry**:
   Push images to Docker Hub / AWS ECR manually:
   ```bash
   docker push your-dockerhub-user/todo-backend:v1.0.1
   docker push your-dockerhub-user/todo-frontend:v1.0.1
   ```
3. **Execute Deployment on EC2**:
   Connect to EC2 via AWS SSM Session Manager and apply the new image tag:
   ```bash
   cd /opt/todo-app
   export IMAGE_TAG=v1.0.1
   docker compose pull
   docker compose up -d
   ```

---

## Scenario 4: Secrets are Leaked. What Steps Do You Take?

If credentials (database password, Cohere API key, AWS keys, Slack webhook) are exposed:

1. **Immediate Credential Revocation & Rotation**:
   - **Cohere API Key**: Revoke the leaked API key immediately in the Cohere dashboard and generate a new key.
   - **Database Passwords**: Update MySQL user password on AWS RDS:
     ```sql
     ALTER USER 'todouser'@'%' IDENTIFIED BY 'NewUltraSecurePassword2026!';
     FLUSH PRIVILEGES;
     ```
   - **Slack Webhook**: Delete the exposed webhook URL in Slack App settings and regenerate a new incoming webhook.
2. **Update AWS SSM Parameter Store / Secrets Manager**:
   Store the newly rotated secrets in AWS SSM Parameter Store:
   ```bash
   aws ssm put-parameter --name "/todo-app/prod/SPRING_DATASOURCE_PASSWORD" --value "NewUltraSecurePassword2026!" --type "SecureString" --overwrite
   ```
3. **Redeploy Application Containers**:
   Restart containers with updated environment variables to reload active credentials:
   ```bash
   docker compose up -d --force-recreate
   ```
4. **Git Repository Sanitization**:
   - Purge commit history containing leaked credentials using `git-filter-repo` or BFG Repo Cleaner:
     ```bash
     bfg --replace-text bad-passwords.txt
     git push origin --force --all
     ```
5. **Audit Logs Verification**:
   Inspect CloudWatch, AWS CloudTrail, Cohere API logs, and database access logs for unauthorized access during the breach window.

---

## Scenario 5: The EC2 Instance Fails. How Do You Recover?

1. **Hardware / Hypervisor Failure Recovery**:
   If the AWS underlying hardware fails:
   - AWS EC2 Auto-Recovery automatically moves the instance to a healthy physical host preserving IP address and EBS volume.
2. **Infrastructure as Code (IaC) Re-provisioning**:
   If the instance is permanently corrupted or deleted:
   - Re-provision the entire application host using Terraform in minutes:
     ```bash
     cd aws/iac
     terraform apply -auto-approve
     ```
   - Terraform launches a new EC2 instance, attaches the IAM role, executes User Data scripts installing Docker/Compose, and pulls container images.
3. **Application Restore**:
   SSH into the newly created EC2 instance and trigger container launch:
   ```bash
   cd /opt/todo-app
   docker compose up -d
   ```

---

## Scenario 6: The RDS Database Becomes Unavailable. What is the Impact and Recovery Plan?

### Impact Assessment
- The Spring Boot backend enters degraded state (`/actuator/health` returns `DOWN`).
- REST endpoints returning or storing todo items return HTTP `500 Internal Server Error`.
- Frontend displays friendly error banners to users.
- Database connection pool (HikariCP) retries connection asynchronously.

### Recovery Plan & High Availability Strategy

1. **Multi-AZ Automatic Failover (Zero Downtime)**:
   - In production, AWS RDS is deployed in a **Multi-AZ** configuration.
   - AWS automatically detects primary database failure and fails over to a synchronous Standby Replica in private subnet 2 within 60-120 seconds.
   - The DB CNAME endpoint (`todo-mysql-rds.xxx.rds.amazonaws.com`) automatically points to the new primary. No code or container configuration changes required.

2. **Point-In-Time Recovery (PITR) from Automated Snapshots**:
   - AWS RDS performs automated daily backups and continuous transaction logging (write-ahead logs).
   - In the event of catastrophic data corruption, restore the database to any millisecond within the last 7 days:
     ```bash
     aws rds restore-db-instance-to-point-in-time \
       --source-db-instance-identifier todo-mysql-rds \
       --target-db-instance-identifier todo-mysql-rds-restored \
       --restore-time 2026-10-08T06:00:00.000Z
     ```
3. **Database Point Re-connection**:
   Update backend `SPRING_DATASOURCE_URL` to point to the restored DB endpoint and restart backend container.
