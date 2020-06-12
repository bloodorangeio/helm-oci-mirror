package util

import (
	"fmt"
	"io/ioutil"
	"os"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart"
	"helm.sh/helm/v3/pkg/chart/loader"
	helmcli "helm.sh/helm/v3/pkg/cli"
	"helm.sh/helm/v3/pkg/experimental/registry"
)

var (
	Settings = helmcli.New()
)

type (
	IndexFile struct {
		Repositories []Repo
	}

	Repo struct {
		Name string
		URL  string
	}
)

func CreatePullAction(dir, version string) (string, *action.Pull, error) {
	newTmpDir, err := ioutil.TempDir(dir, "helm-oci-mirror")
	if err != nil {
		return "", nil, err
	}

	pull := &action.Pull{
		ChartPathOptions: action.ChartPathOptions{
			Version: version,
		},
		Settings:    Settings,
		Untar:       true,
		VerifyLater: false,
		UntarDir:    newTmpDir,
		DestDir:     dir,
	}

	return newTmpDir, pull, nil
}

func GrabChart(baseRef, tmpDir, reponame, chartName, chartVersion string) (*chart.Chart, *registry.Reference, error) {
	dir, pull, err := CreatePullAction(tmpDir, chartVersion)
	if err != nil {
		return nil, nil, err
	}
	defer os.RemoveAll(dir)

	refname := fmt.Sprintf("%s/%s:%s", baseRef, chartName, chartVersion)

	_, err = pull.Run(fmt.Sprintf("%s/%s", reponame, chartName))
	if err != nil {
		return nil, nil, err
	}

	ch, err := loader.Load(dir + "/" + chartName)
	if err != nil {
		return nil, nil, err
	}

	ref, err := registry.ParseReference(refname)
	if err != nil {
		return nil, nil, err
	}
	return ch, ref, nil
}

func Cleanup(tmpDir string) {
	os.RemoveAll(tmpDir)
}
