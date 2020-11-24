# GitHub Actions Runner

Self hosted GitHub Actions Runner.

O GitHub Actions permite a [configuração de instâncias dedicadas](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners) para a execução das pipelines. Este projeto consiste em uma imagem docker que configura, executa e [registra](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/adding-self-hosted-runners) um runner dedicado para determinado projeto ou organização dentro de um container Docker.

**Vantagens** do uso de runners dedicados:
1. Os minutos de execução pipeline não são cobrados.
1. Você pode criar imagens especializadas com requisitos especiais (evitando instalação durante a execução)
1. Aderência a requisitos especiais de segurança e caching.


**Desvantagens** do uso de runners dedicados:
1. Maior tempo para inicialização (bootstraping)
1. Não é possível [desligar todos os runners quando estão ociosos](https://sanderknape.com/2020/03/self-hosted-github-actions-runner-kubernetes/)

## Funcionalidades
1. Personalização de hostname e registro em repositórios ou organizações
1. Remoção do runner quando o container é parado
1. Execução de vários runners no mesmo host (com ou sem autoscaling)
1. Docker in a Docker (Dind)
1. Kubernetes Ready

## Utilização
* Copie e configure o arquivo de exemplo de configuração. Você precisará de um [token de acesso](https://github.com/settings/tokens).
```sh
cp .env-exemple .env
```
* Faça o build da imagem
```sh
docker build . -t gh-runner
```
* Execute o runner:
```sh
docker run --name=gh-runner --rm  --privileged --env-file=.env gh-runner
```
* Aguarde a criação e o registro do container. Pronto! Você deve ver a seguinte saída no Terminal:

![](./docs/img/runner.png)

Para ver o(s) runner(s) registrado(s) no repositório, é só acessar `projeto > configurações > actions`:

![](./docs/img/registered-runners.png)

Ao parar/matar o container, o runners será removido antes de terminar o processo:
![](./docs/img/removal.png)


**Importante!** Para configurar o runner na organização, basta deixar a variável `GITHUB_OWNER` vazia. Mas para isso você precisa de privilégios de administrador na organização alvo.

## Varáveis de Ambiente

| Variável | Descrição |
|----------|-----------|
|RUNNER_NAME| Nome de registro do container. O container ID será concatenado no final do nome escolhido para garantir unicidade.|
|GITHUB_PERSONAL_TOKEN| Seu token pessoal (ou do bot)|
|GITHUB_OWNER| Nome da organização (e.g. PasseiDireto|
|GITHUB_REPOSITORY|Repositório de registro (opcional)|
|RUNNER_WORKDIR|pasta de output do container padrão `_work`. Pode ser alterada por requisitos de espaço em disco, por exemplo.|

## Arquitetura

A imagem padrão contém três componentes básicos: A engine docker, as dependências de runtime to runner e o listener do runner:

![](./docs/img/runner-model.png)

A engine Docker roda dentro do container, padrão conhecido como Docker in a Docker ou Dind. Existe a [imagem oficial Docker](https://hub.docker.com/_/docker/) para essa finalidade, mas ela só tem suporte para o [linux Alpine](https://github.com/docker-library/docker/issues/127), enquanto o [GHA Runner](https://github.com/actions/runner/) só tem suporte para [outras distribuições](https://github.com/actions/runner/blob/main/docs/start/envlinux.md#supported-distributions-and-versions). Por isso fizemos uma imagem inspirada na oficial, mas utilizando esta [outra iniciativa](https://hub.docker.com/r/teracy/ubuntu) que nasceu de [necessidades próximas às nossas](http://blog.teracy.com/2017/09/11/how-to-use-docker-in-docker-dind-and-docker-outside-of-docker-dood-for-local-ci-testing/). Na prática o GHA Runner nem suporta execução em containers, apesar de ser um [desejo antigo](https://github.com/actions/runner/labels/Runner%20%3Aheart%3A%20Container) da comunidade e dos mantenedores do projeto.

Outra modificação no funcionamento padrão da imagem foi realizada para sanar outro problema da execução em containers. O update automático padrão do GHA faz com que o runner reinicie após o update, matando o container. Seguindo sugestões dos [mantenedores do projeto](https://github.com/actions/runner/issues/246#issuecomment-568638572) nós utilizamos o `runsvc.sh` para incializar o listener. Essa substituição é feita com os arquivos da pasta `/patched`.

Utilização do [dumb-init](https://engineeringblog.yelp.com/2016/01/dumb-init-an-init-for-docker.html) para gerenciar a execução do script. A funcionalidade desejada é que os [sinais de finalização do `docker stop`](https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/) (`SIGINT/SIGKILL`) sejam corretamente tratados, possibilitando o desregistro do runner seja realizado. Isso possibilita o funcionamento autonomo em plataformas como o ECS (Fargate/EC2) ou Kubernetes.


### Ciclo de vida
O ciclo de vida do container pode ser resumido como:
- Inicialização (`docker run`)
- Autenticação (passando o token PAT e recebendo o runner token)
- Registro do runner na organização/repositórios
- Aguardando por tarefas [indefinidamente]
- Interrupção (`docker stop`)
    - Stop do listener
    - Desregistro do runner no GHA
- Finalização do container

## Inspirações

Alguns projetos estão tentando suprir a falta de suporte dos GHA Self Hosted Runners para containers, abordagens efêmeras, ECS e Kubernetes. Entre eles podemos destacar:

- https://github.com/myoung34/docker-github-actions-runner
- https://github.com/summerwind/actions-runner-controller
- https://dev.to/jimmydqv/github-self-hosted-runners-in-aws-part-1-fargate-39hi
- https://github.com/evryfs/github-actions-runner-operator/
