# Production Observability and Operations Strategy

This document details the architectural monitoring framework, metrics taxonomy, logging standards, alerting noise-reduction policies, and proactive operational practices for the **Todo Summary Assistant** platform.

---

## 1. Metrics Selection & Justification

Observability is structured around the **Four Golden Signals** of SRE (Latency, Traffic, Errors, and Saturation):

### A. Application Metrics (Spring Boot Actuator & Micrometer)

| Metric | Source / PromQL | Rationale & Operational Value |
| :--- | :--- | :--- |
| **Request Rate (RPS)** | `sum(rate(http_server_requests_seconds_count[1m]))` | Measures incoming user demand and load trends across API endpoints. |
| **HTTP Error Rates** | `sum(rate(http_server_requests_seconds_count{status=~"5..|4.."}[5m]))` | Isolates backend application crashes (5xx) vs client input errors (4xx). |
| **Latency Percentiles** | `histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le))` | P95 and P99 latency reveal performance degradation before standard averages disguise slowness. |
| **JVM Heap Memory** | `jvm_memory_used_bytes{area="heap"}` | Prevents `OutOfMemoryError` (OOM) by tracking Garbage Collection efficiency and memory leaks. |
| **DB Connection Pool** | `hikaricp_connections_active` / `hikaricp_connections_pending` | Detects connection leaks, slow queries, and database query starvation. |

### B. Infrastructure & Host Metrics (Node Exporter)

| Metric | Source / PromQL | Rationale & Operational Value |
| :--- | :--- | :--- |
| **CPU Utilization** | `100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Tracks host compute saturation and thread contention. |
| **Memory Saturation** | `node_memory_MemAvailable_bytes` | Prevents Linux OOM Killer from terminating Docker container processes. |
| **Disk Space Available** | `node_filesystem_avail_bytes{mountpoint="/"}` | Ensures disk capacity is available for Docker logs, build artifacts, and system logs. |

---

## 2. Critical Log Management

Logs are categorized into four severity tiers and aggregated centrally:

### A. Crucial Operational Logs
1. **Spring Boot Application Logs**:
   - Location: Standard stdout / Docker logs (`/var/lib/docker/containers/...`)
   - Critical Indicators: Unhandled `Exception` stack traces, HikariCP timeout logs, Cohere/Slack API connection errors, CORS failures.
2. **Nginx Web Server Logs**:
   - Location: `/var/log/nginx/access.log` and `error.log`
   - Critical Indicators: High frequency HTTP 502 Bad Gateway / 504 Gateway Timeout responses indicating backend container unreachability.
3. **MySQL Database Engine Logs**:
   - Location: AWS CloudWatch RDS Error Logs
   - Critical Indicators: Deadlock detections, slow query logs (>2 seconds), max connection limit exhausted (`Too many connections`).
4. **Host & OS System Security Logs**:
   - Location: `/var/log/messages`, `/var/log/secure`
   - Critical Indicators: Unauthorized SSH access attempts, Docker daemon crashes, system out-of-memory events.

---

## 3. Alert Design & Noise Elimination Policy

Alert fatigue causes operational burnout and missed outages. Alerts are strictly split into **Critical (Page immediately)** and **Warning (Ticket / Slack notification)**, suppressing transient spikes.

### A. High-Value Actionable Alerts

| Alert Name | Severity | Threshold | Condition / Duration | Action Required |
| :--- | :--- | :--- | :--- | :--- |
| `BackendServiceDown` | `Critical` | `up == 0` | 1 minute | Immediate page. Restart container or perform rollback. |
| `HighBackendErrorRate` | `Critical` | 5xx Errors > 5% | 2 minutes | Inspect application error logs and DB connection pool. |
| `LowDiskSpace` | `Warning` | Free Disk < 15% | 5 minutes | Purge unused Docker images (`docker system prune -a`). |
| `HighHostCpuUsage` | `Warning` | CPU > 85% | 5 minutes | Check process CPU consumers (`top`/`htop`) or scale EC2 size. |
| `DatabaseConnectionFailed` | `Critical` | HikariCP Active == 0 | 2 minutes | Check RDS database availability and security group access. |

### B. Anti-Patterns: What Should NOT Alert
- **Single HTTP 4xx Request Spikes**: 401 Unauthorized or 404 Not Found errors caused by invalid client requests should not alert on-call engineers.
- **Short Transient CPU Spikes (< 2 mins)**: Spikes during container startup or batch execution are expected. The `for: 5m` clause suppresses false alarms.
- **Garbage Collection Minor Pauses**: Short GC pauses under 500ms are normal in Java applications.

---

## 4. Early Detection & Proactive Operational Workflow

Operational failures are caught before end-users experience degradation through proactive automated loops:

1. **Synthetic Health Check Polling**:
   Prometheus continuously polls `/actuator/health` every 10 seconds. Synthetic HTTP probes test end-to-end service availability.
2. **Automated CI/CD Verification**:
   Every deployment undergoes automated integration testing and immediate post-deployment health verification. Faulty releases are auto-rolled back before traffic shifts.
3. **Predictive Capacity Planning**:
   Disk and memory consumption rates are calculated using PromQL linear trend prediction (`predict_linear(node_filesystem_avail_bytes[1h], 86400)`), alerting engineers 24 hours before a disk fills up completely.
