module github.com/bloodorangeio/helm-oci-mirror

go 1.14

require (
	github.com/urfave/cli/v2 v2.2.0
	helm.sh/helm/v3 v3.2.3
	rsc.io/letsencrypt v0.0.3 // indirect
)

replace helm.sh/helm/v3 v3.2.3 => github.com/bloodorangeio/helm v0.0.0-20200612211528-374bd1da6567
