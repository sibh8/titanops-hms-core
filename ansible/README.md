# TitanOps HMS — Ansible Configuration Management

This directory contains Ansible playbooks, roles, and configuration management scripts for the TitanOps HMS platform.

## Architecture

In the hands-off CI/CD trigger chain:
`Code Change -> Build -> Terraform -> Ansible -> Deploy -> (Monitoring already live)`

Ansible executes **after Terraform provisions the infrastructure** and **before Helm deploys the microservices**.

### Roles & Responsibilities
- **`environment-config`**: Prepares and validates the target Kubernetes namespace (`hms`), validates client tooling (`kubectl`, `helm`), and asserts environment parameters.
- **`cis-hardening`**: Asserts CIS Benchmark (Level 1) baseline security controls, ensuring containers run as non-root and conform to runtime security profiles.

## Running Locally

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -e "env=dev"
```
