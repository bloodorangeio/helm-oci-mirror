# helm oci-mirror plugin

[![GitHub Actions status](https://github.com/bloodorangeio/helm-oci-mirror/workflows/build/badge.svg)](https://github.com/bloodorangeio/helm-oci-mirror/actions?query=workflow%3Abuild)

![](https://raw.githubusercontent.com/bloodorangeio/helm-oci-mirror/master/helm-oci-mirror.png)

Helm plugin to mirror a chart repository to an OCI registry.

*For more information on Helm's OCI support, please see [the docs](https://helm.sh/docs/topics/registries/).*

## Install
Based on the version in `plugin.yaml`, release binary will be downloaded from GitHub:

```
helm plugin install https://github.com/bloodorangeio/helm-oci-mirror.git
```

## Usage

You must first already have a chart repository added locally:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Update your repos, if necessary, to ensure the latest version of the index:
```
helm repo update
```

Next, if your registry requires authentication, log in:
```
export HELM_EXPERIMENTAL_OCI=1
helm registry login -u <username> -p <password> localhost:5000
```

Finally, run the plugin to mirror the repo:
```
helm oci-mirror bitnami localhost:5000/helm/hub/bitnami
```

The first argument is the name of chart repository you wish to mirror (added previously), and the second argument is the root namespace on the registry you wish to use (which you should have write access to).


## How it works

Every single chart and each of its versions will be pushed into the registry, using the name of the chart as the basename (e.g. `wordpress`) and the version of the chart as the tag (e.g. `9.3.11`).

The resulting chart references will resemble the following:
```
localhost:5000/helm/hub/bitnami/wordpress:9.3.11
localhost:5000/helm/hub/bitnami/wordpress:9.3.10
localhost:5000/helm/hub/bitnami/wordpress:9.3.9
localhost:5000/helm/hub/bitnami/zookeeper:5.16.0
localhost:5000/helm/hub/bitnami/zookeeper:5.15.1
localhost:5000/helm/hub/bitnami/zookeeper:5.15.0
```

These can then be downloaded later by other Helm clients (which are properly authenticated):
```
export HELM_EXPERIMENTAL_OCI=1
helm chart pull localhost:5000/helm/hub/bitnami/wordpress:9.3.11
```

## Additional options

### Debug mode

If you wish to see the output of HTTP requests to the registry, you can use the `--log-debug` flag:
```
helm oci-mirror --log-debug bitnami localhost:5000/helm/hub/bitnami
```

### Timeout between downloads

During the mirroring process, charts will be downloaded from the repo and uploaded to the registry one at a time. If needed, you can use the flag `--interval=<seconds>` to add a timeout between each chart version:

```
helm oci-mirror --interval=10 bitnami localhost:5000/helm/hub/bitnami
```
