# GitHub Actions Runner

Self hosted GitHub Actions Runner.

GitHub Actions allows you to [host your own runners for actions](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners). This project presents a docker container capable of setup, run and [register](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/adding-self-hosted-runners) itself on a Organization or Repository, being available to execute workflows.

**This image depends on [sysbox](https://github.com/nestybox/sysbox)**, an alternative OCI runtime. In that way we can have the Docker in a Docker (DinD) mechanism (since GitHub Actions can run containers) without [all the serious issues](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/) of the traditional `privileged` approach. You can [install sysbox](https://github.com/nestybox/sysbox#installing-sysbox) using stable packages/binaries or [building from the source](https://github.com/nestybox/sysbox/blob/master/docs/developers-guide/build.md). In the later case do not forget do initialize it (`/usr/local/sbin/sysbox`) or create a service do start it automatically every time you start your machine.

This image is available public at [Docker Hub](https://hub.docker.com/r/passeidireto/gh-runner). To run it, you just need to:

```shell script
cp .env-exemple .env # modify with your custom configuration, such as the PAT, Repostitory and Organization.

docker run --runtime sysbox-runc --name=gh-runner --rm  --env-file=.env passeidireto/gh-runner
```

Note that the `runtime` option is needed only if you do not have sysbox as your default runtime. Just wait while it registers itself. You will see this output shortly:

![](./docs/img/runner.png)

You can also see the runner registered at the repository on `repo > settings > actions`:

![](./docs/img/registered-runners.png)

After you kill the container (with ctrl+C or `docker stop gh-runner`) you will see as it deregisters itself and stops:

![](./docs/img/removal.png)

Note that it won't be able to unregisters nicely if you `docker kill` it or somehow send a `SIGKILL`.

If you want it registered at organization level, just let the `GITHUB_REPOSITORY` variable empty. See more about configuration variables at [Environment Variables](#environment-variables) section.  Also, keep in mind that you will need organization privilege levels to perform this action. More details are provided at [Personal Access Token (PAT)](#personal-access-token-pat).

If you intend to use this image with ECS, be aware that [they do not officially support custom runtimes yet](https://github.com/aws/containers-roadmap/issues/673). However, it is possible to use a [custom AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html). You can use our public AMI with ECS Agent and sysbox installed:

```shell script
aws ec2 describe-images --filters "Name=name,Values=passeidireto-ecs-sysbox*"
```

For a detailed example of how to use this image, you can check our [CDK stack repository](https://github.com/PasseiDireto/gh-runner-ecs-ec2-stack).


## Features
1. You can set arbitrary names and register at organization or repository level
1. The runner executes just one workflow and then it stops and unregisters itself
1. You can have multiple runners in the same host
1. Docker in a Docker (Dind) with sysbox
1. ECS and Kubernetes Ready
1. [Label](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners) customization


## Personal Access Token (PAT)

The following scopes are necessary in order to register a runner at organization level:

- `admin:org`

The following scopes are necessary in order to register at repository level:

- `repo` (all)
- `read:public_key` (on `admin:public_key`)
- `read:repo_hook` (on `admin:repo_hook`)
- `admin:org_hook`
- `notifications`
- `workflow`

## Environment Variables

| Name | Description |
|----------|-----------|
|RUNNER_NAME| Runner name. A random suffix will be generated to assert the uniqueness |
|GITHUB_PERSONAL_TOKEN| Yours (or bot's) [PAT](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token)|
|GITHUB_OWNER|Organization's name (e.g. PasseiDireto).|
|GITHUB_REPOSITORY| Repository's name (optional).|
|RUNNER_LABELS| Comma separated list of [labels](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners). They will be passed to runner on setup time.|

## Implementation details

The image has three basic components: the docker engine, runner dependencies and the runner listener:

![](./docs/img/runner-model.png)


Users of this approach should bear in mind that technically the GHA Runner does not even support container execution, although that's something they (and the community) want and are [working into](https://github.com/actions/runner/labels/Runner%20%3Aheart%3A%20Container). The `--ephemeral` flag [recently added](https://github.com/actions/runner/releases/tag/v2.282.0) allows that runners configure themselves as available for one and just one job execution, making it easier to remove (and unconfigure) the container right after its execution.


Finally, we use [dumb-init](https://engineeringblog.yelp.com/2016/01/dumb-init-an-init-for-docker.html) to manage the service execution. The most important feature is to deal with the `SIGINT/SIGKILL` signals and [how docker reacts to them](https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/). With this approach we properly stop and unregister the listener in most of the scenarios, such as scale in and out, to work with platforms like (ECS/Fargate/EC2) and Kubernetes. Otherwise, the runner would hang forever as Offline on the repository/organization.

### Container's Lifecycle

We can resume the container's lifecycle as:

- Init (`docker run`)
- Authentication (with the PAT and receiving a runner token)
- Runner repo/organization registration
- Waiting for taks (as long as needed)
- Workflow execution
- Interruption (`docker stop` or workflow conclusion )
    - Listener stop
    - Unsregisters the container (using a new runner token, as the old one [might be expired for long running tasks](https://github.com/actions/runner/issues/845))
- Container removal

## Inspirations

Some projects are trying to fill the lack of a official GHA Self Hosted Runners for containers and ephemeral approaches, such as ECS and Kubernetes. We can list some of them:

- https://github.com/myoung34/docker-github-actions-runner
- https://github.com/summerwind/actions-runner-controller
- https://dev.to/jimmydqv/github-self-hosted-runners-in-aws-part-1-fargate-39hi
- https://github.com/evryfs/github-actions-runner-operator/
