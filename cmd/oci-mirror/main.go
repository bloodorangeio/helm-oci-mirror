package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"syscall"
	"time"

	"github.com/urfave/cli/v2"
	"helm.sh/helm/v3/pkg/experimental/registry"
	"helm.sh/helm/v3/pkg/helmpath"
	"helm.sh/helm/v3/pkg/repo"

	"github.com/bloodorangeio/helm-oci-mirror/pkg/util"
)

var (
	tmpDir   string
	reponame string
	baseRef  string
)

func main() {
	app := &cli.App{
		Name:  "oci-mirror",
		Usage: "mirror a helm repository on OCI storage",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:     "log-debug",
				Aliases:  []string{"d"},
				Required: false,
			},
			&cli.Int64Flag{
				Name:     "interval",
				Usage:    "Delay, in seconds, between fetching each chart version. Defaults to zero",
				Required: false,
				Value:    0,
			},
			&cli.BoolFlag{
				Name:     "fail-fast",
				Usage:    "Exit on the first encountered error",
				Required: false,
				Value:    false,
			},
		},
		Action: ociMirror,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}

func ociMirror(ctx *cli.Context) error {
	var err error
	interval := ctx.Int64("interval")
	failFast := ctx.Bool("fail-fast")

	if ctx.Args().Len() < 2 {
		return fmt.Errorf("need 2 arguments")
	}

	reponame = ctx.Args().Get(0)
	baseRef = ctx.Args().Get(1)

	if _, err = os.Stat("/tmp"); err != nil {
		return err
	}

	tmpDir, err = ioutil.TempDir("/tmp", "helm-oci-mirror")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	// clean up if user executes Ctrl-C
	c := make(chan os.Signal)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		util.Cleanup(tmpDir)
		os.Exit(1)
	}()

	f := filepath.Join(util.Settings.RepositoryCache, helmpath.CacheIndexFile(reponame))
	index, err := repo.LoadIndexFile(f)
	if err != nil {
		return err
	}

	debug := ctx.Bool("log-debug")
	registryClient, err := registry.NewClient(
		registry.ClientOptDebug(debug),
		registry.ClientOptWriter(os.Stdout),
	)
	if err != nil {
		return err
	}

	keys := make([]string, len(index.Entries))
	for k := range index.Entries {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, key := range keys {
		for _, thisChart := range index.Entries[key] {
			chartName := thisChart.Name
			chartVersion := thisChart.Version

			log.Printf("Downloading %s version %s ...\n", chartName, chartVersion)
			ch, ref, err := util.GrabChart(baseRef, tmpDir, reponame, chartName, chartVersion)
			if err != nil {
				if failFast {
					return err
				}

				log.Printf("[ERROR] %s", err.Error())
			}

			log.Printf("Pushing %s version %s to %s ...\n", chartName, chartVersion, ref.FullName())
			err = registryClient.SaveChart(ch, ref)
			if err != nil {
				if failFast {
					return err
				}

				log.Printf("[ERROR] %s", err.Error())
			}

			err = registryClient.PushChart(ref)
			if err != nil {
				if failFast {
					return err
				}

				log.Printf("[ERROR] %s", err.Error())
			}

			time.Sleep(time.Duration(interval) * time.Second)
		}
	}

	return nil
}
