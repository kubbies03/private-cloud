# Private Cloud Lab — Bản triển khai nâng cấp mạnh hơn (CV-ready)

Dự án này đi theo hướng gần với môi trường Infrastructure/System Engineer thực tế hơn bản trước, bổ sung:

* centralized logging
* reverse proxy multi-service
* internal DNS
* IAM cơ bản
* automation
* monitoring đầy đủ
* backup lifecycle
* container orchestration mức mini
* security hardening cơ bản

Phù hợp để apply:

* System Engineer Intern
* Infrastructure Intern
* Cloud Intern
* DevOps Intern
* AI Infrastructure Intern

Thậm chí đủ tốt để nói chuyện technical trong interview junior-level.
Dựa trên nền tảng triển khai trước đó. 

---

# Project Name

**Enterprise Private Cloud Lab — Self-Hosted Infrastructure Environment**

---

# 1. Mục tiêu dự án

Xây dựng một mini enterprise infrastructure mô phỏng:

* On-premise private cloud
* Multi-server environment
* Internal enterprise networking
* Monitoring & logging stack
* Backup & storage workflow
* Reverse proxy gateway
* Containerized infrastructure
* Basic identity & access management

---

# 2. Kiến trúc tổng thể

```text
                     INTERNET
                         │
                    Host Machine
                         │
                VMware / VirtualBox
                         │
────────────────────────────────────────────
            PRIVATE CLOUD LAB
────────────────────────────────────────────

 ┌─────────────────────────────────────┐
 │ Ubuntu Infra Server                │
 │-------------------------------------│
 │ Docker Engine                       │
 │ Nginx Reverse Proxy                 │
 │ FastAPI Services                    │
 │ Internal DNS                        │
 │ SSH                                 │
 │ Backup Automation                   │
 └─────────────────────────────────────┘

 ┌─────────────────────────────────────┐
 │ Windows Server                      │
 │-------------------------------------│
 │ Active Directory                    │
 │ SMB File Sharing                    │
 │ User & Permission Management        │
 └─────────────────────────────────────┘

 ┌─────────────────────────────────────┐
 │ Monitoring & Logging VM             │
 │-------------------------------------│
 │ Prometheus                          │
 │ Grafana                             │
 │ Loki                                │
 │ Promtail                            │
 │ Node Exporter                       │
 │ cAdvisor                            │
 └─────────────────────────────────────┘

 ┌─────────────────────────────────────┐
 │ Storage Services                    │
 │-------------------------------------│
 │ Docker Volumes                      │
 │ Shared Folder                       │
 │ SMB Storage                         │
 └─────────────────────────────────────┘
```

---

# 3. Công nghệ sử dụng

## Virtualization

* VMware Workstation Pro
* Oracle VirtualBox

---

## Operating Systems

* Ubuntu Server
* Windows Server

---

## Infrastructure

| Component      | Purpose                  |
| -------------- | ------------------------ |
| Docker         | Container runtime        |
| Docker Compose | Multi-service deployment |
| Nginx          | Reverse proxy            |
| SSH            | Remote management        |
| SMB            | Shared storage           |
| Cron           | Automation               |
| UFW            | Firewall                 |
| Fail2Ban       | SSH protection           |

---

## Monitoring & Logging

| Component     | Purpose            |
| ------------- | ------------------ |
| Prometheus    | Metrics collection |
| Grafana       | Dashboard          |
| Loki          | Centralized logs   |
| Promtail      | Log shipping       |
| Node Exporter | Host metrics       |
| cAdvisor      | Container metrics  |

---

# 4. VM Specifications

## Ubuntu Infra VM

| Resource | Value     |
| -------- | --------- |
| CPU      | 2–4 cores |
| RAM      | 8 GB      |
| Storage  | 50 GB     |

---

## Windows Server VM

| Resource | Value   |
| -------- | ------- |
| CPU      | 2 cores |
| RAM      | 4–8 GB  |
| Storage  | 60 GB   |

---

## Monitoring VM

| Resource | Value   |
| -------- | ------- |
| CPU      | 2 cores |
| RAM      | 4 GB    |
| Storage  | 30 GB   |

---

# 5. Network Topology

```text
192.168.159.0/24

Gateway:
192.168.159.1

Ubuntu Infra:
192.168.159.130

Windows Server:
192.168.159.131

Monitoring:
192.168.159.132
```

---

# 6. Infrastructure Features

# 6.1 Reverse Proxy Gateway

Nginx xử lý:

* reverse proxy
* load balancing cơ bản
* SSL termination
* routing nội bộ

Flow:

```text
Client
   ↓
Nginx Gateway
   ↓
Docker Services
```

---

# 6.2 Internal Services

Ví dụ deploy:

| Service     | Port |
| ----------- | ---- |
| FastAPI API | 8000 |
| Grafana     | 3000 |
| Prometheus  | 9090 |
| Loki        | 3100 |

---

# 6.3 Dockerized Infrastructure

Ví dụ:

```yaml
services:
  nginx:
  api:
  prometheus:
  grafana:
  loki:
  promtail:
```

---

# 7. Monitoring & Logging System

# 7.1 Metrics Monitoring

Thu thập:

* CPU
* RAM
* Disk
* Network
* Container metrics
* VM resource usage

---

# 7.2 Centralized Logging

Log pipeline:

```text
Docker Containers
      ↓
Promtail
      ↓
Loki
      ↓
Grafana
```

Chứng minh được:

* log aggregation
* observability
* troubleshooting workflow

---

# 8. Windows Server Features

## Active Directory

Có thể cấu hình:

* domain users
* permissions
* groups

---

## SMB File Sharing

Shared storage:

```text
\\192.168.159.131\shared
```

---

# 9. Security Hardening

## Linux Firewall

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

---

## Fail2Ban

Protect SSH brute-force.

---

## SSH Hardening

```text
PermitRootLogin no
PasswordAuthentication no
```

---

# 10. Backup Workflow

## Automated Backup

Cronjob:

```bash
0 2 * * * /opt/scripts/backup.sh
```

---

## Backup Targets

* Docker volumes
* Nginx configs
* Prometheus configs
* Application configs

---

## Compression

```bash
tar -czf backup.tar.gz /opt/projects
```

---

# 11. Automation

## Cron Jobs

| Task           | Schedule |
| -------------- | -------- |
| Backup         | Daily    |
| Docker cleanup | Weekly   |
| Log rotation   | Weekly   |

---

# 12. Storage Architecture

## Persistent Volumes

```text
/opt/data
/opt/backups
/opt/logs
```

---

## Docker Volumes

```bash
docker volume ls
```

---

# 13. SSH & Remote Operations

## Remote Management

```bash
ssh admin@192.168.159.130
```

---

## VSCode Remote SSH

* Remote development
* Infrastructure management
* Container debugging

---

# 14. Demo Checklist

## Infrastructure

* [ ] Multi-VM networking works
* [ ] SSH works
* [ ] Docker services running
* [ ] Reverse proxy works
* [ ] Windows file sharing works

---

## Monitoring

* [ ] Grafana dashboards active
* [ ] Prometheus scraping metrics
* [ ] Loki log aggregation working

---

## Security

* [ ] Firewall active
* [ ] Fail2Ban active
* [ ] SSH hardened

---

## Backup

* [ ] Automated backup works
* [ ] Restore test successful

---

# 15. Screenshot Checklist

## Infrastructure

* VMware topology
* docker compose ps
* Nginx configs
* SSH session

---

## Monitoring

* Grafana dashboards
* Loki logs
* Container metrics
* CPU/RAM charts

---

## Windows Server

* Active Directory
* SMB sharing
* Shared folder access

---

# 16. README Structure

```text
1. Project Overview
2. Architecture Diagram
3. VM Specifications
4. Network Topology
5. Docker Deployment
6. Monitoring Stack
7. Logging Stack
8. Security Hardening
9. Backup Workflow
10. Troubleshooting
11. Future Improvements
```

---

# 17. CV Description (mạnh hơn bản trước)

```text
Enterprise Private Cloud Lab — Self-Hosted Infrastructure Environment

- Built a multi-VM private cloud lab using VMware with Ubuntu Server and Windows Server environments.
- Designed internal VM networking, reverse proxy routing, centralized logging, and infrastructure monitoring systems.
- Deployed containerized services using Docker Compose with Prometheus, Grafana, Loki, and Nginx.
- Configured SSH hardening, firewall policies, backup automation, and SMB shared storage services.
- Implemented observability workflows for infrastructure troubleshooting and container monitoring.
```

---

# 18. Kỹ năng chứng minh được

| Skill                     | Level  |
| ------------------------- | ------ |
| Linux Server              | Strong |
| Windows Server            | Strong |
| Docker                    | Strong |
| Networking                | Strong |
| Monitoring                | Strong |
| Logging                   | Strong |
| Infrastructure Operations | Strong |
| Virtualization            | Strong |
| Reverse Proxy             | Strong |
| Backup Systems            | Strong |
| SSH Administration        | Strong |
| Storage Management        | Medium |
| Security Hardening        | Medium |

---

# 19. Điểm mạnh cực lớn của project này

Project này có lợi thế hơn project AI đơn thuần ở CV System:

| AI Project                       | Private Cloud Lab    |
| -------------------------------- | -------------------- |
| khó chứng minh infra             | infra nhìn thấy rõ   |
| recruiter khó verify             | dễ demo              |
| khó thấy networking              | networking rõ        |
| thiên research                   | thiên operations     |
| ít giống môi trường doanh nghiệp | gần doanh nghiệp hơn |

---

# 20. Future Improvements

## Có thể nâng cấp tiếp

* Kubernetes
* Proxmox VE
* Ansible
* CI/CD pipeline
* GitLab self-hosted
* VPN server
* MinIO object storage
* ELK Stack
* Harbor Registry
* K3s cluster
