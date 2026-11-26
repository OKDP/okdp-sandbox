# The demo project (layers 2 and 3)

The sandbox reads as three layers, each optional and building on the previous
one:

1. **The platform** (`clusters/sandbox/`): OKDP on kind, usable on its own.
2. **A project** (this directory): a namespace, its secrets, its PostgreSQL,
   its Connections and its data services, the same shape the Control Plane
   deploys from the service catalog.
3. **Example workloads** (`examples/`): the
   [okdp-examples](https://github.com/OKDP/okdp-examples) NYC-taxi medallion
   lakehouse, seeded by one Job.

Layer 2 requires the optional [storage component](../optional/README.md)
installed first.

Once deployed, the `demo` project appears in the OKDP console: it is managed
directly in the default Kubernetes mode, or imported into Git in
[GitOps mode](#running-in-gitops-mode).

## Layer 2: the project (Kubernetes mode)

```sh
kubectl apply -f clusters/sandbox/project-demo/00-namespace.yaml
kubectl apply -f clusters/sandbox/project-demo/10-secrets.yaml
kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY release/demo-secrets --timeout=5m
kubectl apply -f clusters/sandbox/project-demo/20-storage-demo.yaml
kubectl -n kubocd-system wait --for=jsonpath='{.status.phase}'=READY release/storage --timeout=10m
kubectl apply -f clusters/sandbox/project-demo/30-postgres.yaml
kubectl -n demo wait --for=condition=Ready cluster/demo-pg --timeout=10m
kubectl -n demo wait --for=jsonpath='{.status.applied}'=true \
        database/demo-pg-hive database/demo-pg-superset database/demo-pg-superset-examples database/demo-pg-polaris database/demo-pg-airflow \
        --timeout=10m
kubectl apply -f clusters/sandbox/project-demo/40-connections.yaml
kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY \
         connection/demo-db-hive connection/demo-db-superset connection/demo-db-superset-examples connection/demo-db-polaris connection/demo-db-airflow connection/demo-storage \
        --timeout=10m
kubectl apply -f clusters/sandbox/project-demo/50-services.yaml
kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY release -l okdp.io/project=demo --timeout=30m
kubectl apply -f clusters/sandbox/project-demo/60-polaris-catalog-job.yaml
kubectl -n demo wait --for=condition=complete job/demo-polaris-catalog --timeout=10m
```

`20-storage-demo.yaml` extends the storage Release with the project buckets
and one grant per service. Re-apply `optional/storage/storage.yaml` to return
to the platform-only store.

The services follow the medallion layout of okdp-examples: `bronze` is the
hive catalog of Trino, `silver` and `gold` are Polaris warehouses that exist
once layer 3 has run. The `demo` Polaris catalog (job `demo-polaris-catalog`)
and the `iceberg` Trino catalog work without layer 3.

## Layer 3: okdp-examples

```sh
kubectl apply -f clusters/sandbox/project-demo/examples/okdp-examples.yaml
kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY release/demo-okdp-examples --timeout=30m
```

One seed Job: bronze parquet data into S3, external tables on the `bronze`
catalog, `silver` and `gold` warehouses and their roles through polaris-admin.
Notebooks arrive through the JupyterHub welcome notebook, DAGs through the
Airflow git-sync, both pointed at the upstream okdp-examples repository.

## Running in GitOps mode

When the Control Plane runs in [GitOps mode](../../../docs/gitops.md), apply the infrastructure prerequisites (`storage`, `demo-secrets` and PostgreSQL) on the cluster with `kubectl`, and commit the OKDP project manifests (Namespace, Connections and service Releases) to Git with [import-gitops.sh](import-gitops.sh):

1. Apply the storage backend and project infrastructure prerequisites:

   ```sh
   kubectl -n default get secret creds-seaweedfs-s3 >/dev/null 2>&1 \
     || kubectl apply -f clusters/sandbox/optional/storage/storage.yaml
   kubectl apply -f clusters/sandbox/project-demo/00-namespace.yaml
   kubectl apply -f clusters/sandbox/project-demo/10-secrets.yaml
   kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY release/demo-secrets --timeout=5m
   kubectl apply -f clusters/sandbox/project-demo/20-storage-demo.yaml
   kubectl -n kubocd-system wait --for=jsonpath='{.status.phase}'=READY release/storage --timeout=10m
   kubectl apply -f clusters/sandbox/project-demo/30-postgres.yaml
   kubectl -n demo wait --for=condition=Ready cluster/demo-pg --timeout=10m
   kubectl -n demo wait --for=jsonpath='{.status.applied}'=true database --all --timeout=10m
   ```

2. Clone the repository into a temporary checkout, export `project-demo` with `import-gitops.sh` *(for an external Git server, clone your Control Plane repository instead and pass `/tmp/okdp-cp` when `gitPath` is empty)*, and push:

   ```sh
   kubectl -n git port-forward svc/git 3000:80 >/tmp/okdp-git-pf.log 2>&1 &
   PF_PID=$!
   until curl -fs http://localhost:3000/api/healthz >/dev/null; do kill -0 "$PF_PID" 2>/dev/null || { cat /tmp/okdp-git-pf.log >&2; exit 1; }; sleep 1; done
   rm -rf /tmp/okdp-cp
   git clone http://okdp:okdp-sandbox@localhost:3000/okdp/okdp-sandbox.git /tmp/okdp-cp
   ./clusters/sandbox/project-demo/import-gitops.sh /tmp/okdp-cp/clusters/sandbox/control-plane
   git -C /tmp/okdp-cp add -A
   git -C /tmp/okdp-cp diff --cached --quiet || git -C /tmp/okdp-cp commit -m "Import demo project"
   git -C /tmp/okdp-cp push origin main
   rm -rf /tmp/okdp-cp
   kill "$PF_PID" 2>/dev/null || true
   ```

3. Wait for Flux and KuboCD to reconcile the `demo` connections and services, then run the Polaris bootstrap Job:

   ```sh
   flux -n okdp-system reconcile kustomization okdp-control-plane-server-main --with-source
   kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY connection --all --timeout=10m
   kubectl -n demo wait --for=jsonpath='{.status.phase}'=READY release -l okdp.io/project=demo --timeout=30m
   kubectl -n demo delete job demo-polaris-catalog --ignore-not-found
   kubectl apply -f clusters/sandbox/project-demo/60-polaris-catalog-job.yaml
   kubectl -n demo wait --for=condition=complete job/demo-polaris-catalog --timeout=10m
   ```

*(To add Layer 3 through Git as well, copy `clusters/sandbox/project-demo/examples/okdp-examples.yaml` into `projects/demo/releases/demo-okdp-examples.yaml` under your Control Plane Git path, commit and push. Deleting `demo` in the console prunes its namespace unless annotation `kustomize.toolkit.fluxcd.io/prune: disabled` is added to `projects/demo/namespace.yaml`.)*
