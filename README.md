# Project 3: React E-commerce Application Deployment (CI/CD on AWS)

**Author:** Kannan Sudalai
**Repository:** `ksheregit/p1-devops-build` (the repo name says p1, the submission is Project 3)

A pre-built React e-commerce app ("OnlineShop") taken to a production-ready state: containerised with Docker, built and published by a Jenkins multibranch pipeline, deployed automatically to an AWS EC2 instance, and watched by an open-source monitoring stack that sends an alert when the app goes down.

## Quick links

| Item | Value |
|---|---|
| GitHub repo | https://github.com/ksheregit/p1-devops-build |
| Deployed site | http://15.252.121.175/ (reachable while the EC2 instance is running) |
| Docker Hub, dev image (public) | `kannansudalai/dev` |
| Docker Hub, prod image (private) | `kannansudalai/prod` |
| Source of the app files | https://github.com/sriram-R-krishnan/devops-build (pre-built `build/` folder) |
| Full evidence with screenshots | [`docs/Kannan_Sudalai_Project3_ReactJS_Deployment.pdf`](docs/Kannan_Sudalai_Project3_ReactJS_Deployment.pdf) (26 steps) |

## Architecture and flow

```
                 push to dev / merge to master
Developer ─────────────────────────────────────► GitHub (ksheregit/p1-devops-build)
                                                         │  webhook (push event)
                                                         ▼
                                   Jenkins (tools server, EC2 t2.medium)
                                   Multibranch Pipeline: Set repo → Build → Push → Deploy
                                        │                              │
                       docker push      │                              │  SSH (app-ssh key)
                                        ▼                              ▼
                              Docker Hub                      App server (EC2 t2.micro)
                       dev  (public)  ← from dev             pull image + restart container
                       prod (private) ← from master          nginx serving React on port 80
                                                                       ▲
                                                                       │ HTTP probe every 15s
                          Prometheus + Blackbox Exporter ──────────────┘
                                        │
                                        ▼
                          Grafana dashboard + alert rule ──► Discord notification (only when DOWN)
```

| Branch | Target Docker Hub repo | Deployed image on the app server |
|---|---|---|
| `dev` | `kannansudalai/dev` | `kannansudalai/dev:latest` |
| `master` | `kannansudalai/prod` (private) | `kannansudalai/prod:latest` |

## Tech stack

Docker and Docker Compose, nginx (alpine), Bash, Git and GitHub, Docker Hub, Jenkins (Multibranch Pipeline, GitHub webhook), AWS EC2 (Amazon Linux 2023) and Security Groups, Prometheus, Blackbox Exporter, Grafana (alerting), Discord (webhook notifications).

## Repository structure

```
p1-devops-build/
├── build/               # pre-built React production files (from the source repo)
├── Dockerfile           # nginx:alpine image that serves the build folder on port 80
├── docker-compose.yml   # runs the image as the react-app container
├── build.sh             # builds the Docker image
├── deploy.sh            # pulls the image and (re)starts the container on the server
├── Jenkinsfile          # declarative pipeline: Set repo → Build → Push → Deploy
├── .gitignore           # files Git should not track
├── .dockerignore        # files not sent to the Docker build context
├── .gitattributes       # keeps *.sh files on LF line endings
└── docs/                # evidence document (PDF) with screenshots of every step
```

## Requirements checklist

| Requirement | Status | Where to look |
|---|---|---|
| Dockerfile and docker-compose file; app on port 80 | Done | Steps 2 to 4 |
| `build.sh` and `deploy.sh` | Done | Step 6 |
| Code pushed to the `dev` branch using Git CLI only, with `.gitignore` and `.dockerignore` | Done | Steps 7 and 8 |
| Docker Hub: `dev` (public) and `prod` (private) repos | Done | Steps 2, 5 and 12 |
| Jenkins build, push and deploy steps | Done | Steps 9 to 12, 17 and 18 |
| Auto build triggered by commits on `dev` and `master` | Done | Steps 14, 19 to 21 |
| `dev` push builds and pushes to the dev repo | Done | Steps 12 and 19 |
| `dev` merged into `master` pushes to the prod repo | Done | Steps 12 and 21 |
| t2.micro instance; app open to everyone, SSH only from my IP | Done | Steps 13 to 16 |
| Open-source health monitoring | Done | Steps 22 and 23 |
| Notification only when the app goes down | Done | Steps 24 to 26 |

## Implementation summary

### 1. Containerise the app

The source repo contains only the compiled `build/` folder, so no Node build stage is needed; nginx serves the static files.

`Dockerfile`
```dockerfile
FROM nginx:alpine
COPY build/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

`docker-compose.yml`
```yaml
services:
  app:
    build: .
    image: kannansudalai/dev:latest
    container_name: react-app
    ports:
      - "80:80"
    restart: always
```

Run locally: `docker compose up -d --build`, then open `http://localhost`.

### 2. Scripts

| Script | Usage | What it does |
|---|---|---|
| `build.sh` | `./build.sh <image> [tag]` | `set -e`, then `docker build -t <image>:<tag> .` (defaults: `kannansudalai/dev`, `latest`) |
| `deploy.sh` | `./deploy.sh <image> [tag]` | Pulls the image, removes the old `react-app` container, starts a new one with `-p 80:80 --restart always` |

Both scripts are committed with the executable bit (`git update-index --chmod=+x build.sh deploy.sh`, mode `100755`) and use LF line endings (`.gitattributes`: `*.sh text eol=lf`).

### 3. Git workflow (CLI only)

```bash
git init
git checkout -b dev
git add .
git commit -m "Add Dockerfile, compose, build and deploy scripts"
git remote add origin https://github.com/ksheregit/p1-devops-build.git
git push -u origin dev
git checkout -b master && git push -u origin master
```

Changes go to `dev` first. Merging `dev` into `master` is what promotes an image to the prod repo.

### 4. Jenkins pipeline

The Jenkins server (t2.medium, Amazon Linux 2023) has Docker and Git installed. Required plugins: Git, GitHub, GitHub Branch Source, Pipeline, Docker Pipeline, SSH Agent.

Credentials stored in Jenkins (never in the repo):

| Credential ID | Kind | Used for |
|---|---|---|
| `dockerhub` | Username with password (Docker Hub access token, Read and Write) | `docker login` and `docker push` |
| `app-ssh` | SSH username with private key (`ec2-user`) | SSH and `scp` to the app server |

A **Multibranch Pipeline** job (`p1-devops-build`) points to the GitHub repo, discovers the `dev` and `master` branches, and reads the `Jenkinsfile`. A GitHub webhook (`http://<jenkins-ip>:8080/github-webhook/`, push events) starts a build on every push.

`Jenkinsfile`
```groovy
pipeline {
  agent any

  stages {

    stage('Set repo') {
      steps {
        script {
          // master -> prod repo, any other branch (dev) -> dev repo
          env.IMAGE_REPO = (env.BRANCH_NAME == 'master') ? 'kannansudalai/prod' : 'kannansudalai/dev'
        }
        echo "Branch: ${env.BRANCH_NAME}  ->  Image repo: ${env.IMAGE_REPO}"
      }
    }

    stage('Build') {
      steps {
        sh './build.sh ${IMAGE_REPO} latest'
        sh 'docker tag ${IMAGE_REPO}:latest ${IMAGE_REPO}:${BUILD_NUMBER}'
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          // --password-stdin avoids exposing the password as a command-line argument
          sh 'echo $DH_PASS | docker login -u $DH_USER --password-stdin'
          sh 'docker push ${IMAGE_REPO}:latest'
          sh 'docker push ${IMAGE_REPO}:${BUILD_NUMBER}'
        }
      }
    }

    stage('Deploy') {
      steps {
        sshagent(credentials: ['app-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh '''
              scp -o StrictHostKeyChecking=no deploy.sh ec2-user@172.31.14.85:/home/ec2-user/deploy.sh
              echo $DH_PASS | ssh -o StrictHostKeyChecking=no ec2-user@172.31.14.85 "docker login -u $DH_USER --password-stdin && chmod +x deploy.sh && ./deploy.sh ${IMAGE_REPO} latest"
            '''
          }
        }
      }
    }

  }

  post {
    always {
      sh 'docker logout || true'
    }
  }
}
```

Why the Deploy stage exists: Build and Push run on the Jenkins server, but the app runs on a different machine. The Deploy stage connects to the app server over SSH, logs in to Docker Hub there (needed to pull the private `prod` image), and runs `deploy.sh` so the container is replaced with the image that was just pushed.

### 5. AWS

| Server | Type | Role |
|---|---|---|
| Tools server | t2.medium | Jenkins, Docker, Prometheus, Grafana, Blackbox Exporter |
| App server `ecom-app-server-p1` | t2.micro | Runs the `react-app` container on port 80 |

Security group of the app server:

| Port | Source | Purpose |
|---|---|---|
| 80 (HTTP) | `0.0.0.0/0` | Anyone with the address can open the app |
| 22 (SSH) | My IP `/32` only | Administrator login |
| 22 (SSH) | Tools server security group | Lets Jenkins deploy |
| 9100 (TCP) | Tools server security group | Metrics scraping |

### 6. Monitoring and alerting

Blackbox Exporter runs on the tools server and probes the app from outside, so monitoring keeps working even if the app server goes down.

```bash
docker run -d --name blackbox --restart always -p 9115:9115 prom/blackbox-exporter
```

Added to `/etc/prometheus/prometheus.yml` (validated with `promtool check config`):

```yaml
  - job_name: "blackbox-app"
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets: ["http://172.31.14.85"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115
```

Grafana:
- **Dashboard:** a Stat panel on `probe_success{job="blackbox-app"}` with value mappings 1 = UP and 0 = DOWN.
- **Contact point:** `discord-alerts` (Discord webhook, "Disable resolved message" ticked, so only DOWN alerts are sent).
- **Alert rule:** `Online-shopping App down`, query `probe_success{job="blackbox-app"}`, condition IS BELOW 1, evaluated every 1 minute with a 1 minute pending period; no-data and error states are set to Alerting.

## Verification results

| Test | Result |
|---|---|
| Local run with `docker compose up -d --build` | App loads at `http://localhost` |
| `dev` build #1 and `master` build #1 | Both passed; images pushed to `kannansudalai/dev` and `kannansudalai/prod` |
| Push to `dev` (Jenkinsfile with Deploy stage) | Webhook delivered; build #2 started automatically ("Push event to branch dev") and replaced the container on the app server |
| Merge `dev` into `master` | `master` build #2 started automatically and deployed `kannansudalai/prod:latest` |
| Stop the container on the app server | Grafana rule went to Firing and a Discord alert arrived |
| Start the container again | Rule returned to Normal |

All screenshots are in the evidence PDF under `docs/`.

## How to reproduce

1. Clone this repo and run `docker compose up -d --build` to test locally.
2. Create the `dev` (public) and `prod` (private) repos on Docker Hub, plus an access token.
3. Launch a tools server with Jenkins, Docker, Git, Prometheus, Grafana and Blackbox Exporter, and an app server (t2.micro) with Docker. Apply the security groups described above.
4. In Jenkins, add the `dockerhub` and `app-ssh` credentials, create the Multibranch Pipeline for this repo, and add the GitHub webhook.
5. Push to `dev`, then merge `dev` into `master`, and watch the builds and deployments.
6. Add the `blackbox-app` job to Prometheus and create the Grafana alert rule and contact point.

## Security notes

- No passwords, tokens or keys are stored in this repository. Docker Hub and SSH credentials live only in the Jenkins credential store, and the pipeline uses `--password-stdin` for `docker login`.
- The prod image is in a private Docker Hub repository.
- SSH access to the app server is limited to my IP address and the Jenkins server.
- Jenkins prints a warning that the Docker login is stored unencrypted on the app server; a `docker logout` at the end of the remote deploy command would remove it.
- Jenkins logs "Could not update commit status" because the GitHub token has no `repo:status` scope. It does not affect the build.
