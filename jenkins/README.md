# Self-study: the same pipeline in Jenkins

In the session you built the pipeline with GitHub Actions. Many companies run
**Jenkins** (open source, self-hosted) instead. This exercise rebuilds the same
five steps in a `Jenkinsfile`, so you can compare the two and talk about both
in interviews.

| Step | GitHub Actions (`pipeline/4-promote.yaml`) | Jenkins (`jenkins/Jenkinsfile`) |
| --- | --- | --- |
| Trigger | `on: push / pull_request` (GitHub calls Actions) | `pollSCM` (Jenkins asks Git every ~2 min) |
| Where it runs | GitHub-hosted runner, fresh VM each run | Your Jenkins server, reused workspace |
| Test | `setup-node` + `npm test` | `npm test` on the controller (Node installed in the image) |
| Build | `docker/build-push-action` (multi-arch) | `docker build` (your laptop's architecture only) |
| Scan | `trivy-action` | `aquasec/trivy` container |
| Secrets | `secrets.GITHUB_TOKEN`, `secrets.GITOPS_TOKEN` | Jenkins credentials `ghcr`, `gitops` |
| Promote | `sed` + `git push` to todo-gitops | the same `sed` + `git push` |

Time needed: about 45 minutes.

## 1. Avoid double deploys

Both systems would promote every commit. While you try Jenkins, disable the
GitHub workflow: todo-app on GitHub → **Actions** → `ci` → `...` → **Disable workflow**.
Re-enable it when you finish.

## 2. Start Jenkins

```bash
make personalize GITHUB_USER=<you>   # also fills GITHUB_USER in jenkins/Jenkinsfile
git commit -am "chore: set GitHub user in Jenkinsfile" && git push
make jenkins-up                      # builds and starts Jenkins on http://localhost:8090
make jenkins-password                # initial admin password
```

Open `http://localhost:8090`, paste the password, choose **Select plugins to
install → None** (the image already has them), and create your admin user.

## 3. Add two credentials

Manage Jenkins → Credentials → System → Global credentials → Add credentials,
kind **Username with password**:

| ID | Username | Password |
| --- | --- | --- |
| `ghcr` | your GitHub username | a **classic** token with the `write:packages` scope (GitHub Packages does not accept fine-grained tokens for pushes) |
| `gitops` | your GitHub username | the fine-grained token you made for `todo-gitops` |

## 4. Create the pipeline job

New Item → name `todo-app` → **Pipeline** → OK, then under *Pipeline*:

- Definition: **Pipeline script from SCM**
- SCM: **Git**, Repository URL: `https://github.com/<you>/todo-app.git`
- Branch Specifier: `*/main`
- Script Path: `jenkins/Jenkinsfile`

Save, then **Build Now**. The first build also activates the `pollSCM` trigger.

## 5. Things to try

1. Open the build's **Stage View** and match each stage to a Jenkinsfile block.
2. Push a commit with a failing test and watch the pipeline stop at *Test*.
3. Compare: how long did Jenkins take vs GitHub Actions for the same commit? Why?
4. Write down three differences you would mention in an interview
   (hosting, scaling, security of the Docker socket, plugin maintenance, cost).

## 6. Clean up

```bash
make jenkins-down        # stops Jenkins and deletes its data volume
```

Re-enable the `ci` workflow on GitHub.

## Security note

This setup mounts the host's Docker socket into Jenkins and runs it as root.
That is acceptable on your own laptop for a lab and **never** acceptable on a
shared server: anyone who can edit a Jenkinsfile could control the host.
Production Jenkins uses separate build agents (VMs or Kubernetes pods).
