# GitOps Assurance

This repository declares Argo CD Applications for Lightning IT clusters. It
does not publish a software package or container image. The immutable release
candidate is therefore the exact Git commit promoted from protected `develop`
to protected `main`, together with the rendered manifests produced by the
required checks for that commit.

## Governing decisions and standards

Lightning IT's governing engineering decisions are maintained in the internal
architecture decision record system. Internal knowledge-base locations are not
published in this public repository.

The implementation also applies the relevant controls from
[NIST SP 800-218 (SSDF)](https://csrc.nist.gov/pubs/sp/800/218/final),
[OpenSSF Scorecard](https://scorecard.dev/), and the
[OpenSSF OSPS Baseline](https://baseline.openssf.org/).

## Promotion evidence

Normal changes enter `develop` through a pull request. A separate pull request
promotes the reviewed `develop` commit to `main`. The promotion evidence is:

1. the exact promotion PR head SHA;
2. successful required `repository / quality` and `helm / quality` checks
   bound to the GitHub Actions App;
3. no unresolved review thread;
4. the resulting immutable `main` commit SHA.

`helm / quality` lints and renders the chart with every
`cluster/*/values.yaml` file and builds every Kustomize overlay without cluster
access. It fails closed when a cluster renders no Argo CD
Application, when a source uses implicit `HEAD` or `latest`, or when automated
pruning and self-healing are missing.

## Revision policy

- External Helm dependencies use explicit chart versions.
- `main` is the stable repository revision.
- `develop` is the integration revision used by explicitly identified
  non-production clusters.
- `ovh` is a legacy environment promotion branch still referenced by existing
  declarations. Replacing it requires a coordinated cluster migration and is
  tracked as a temporary exception below.
- Implicit `HEAD`, `latest`, and an omitted source revision are prohibited.

Argo CD records the resolved commit of a branch-backed source in application
status. Operational evidence must always record that resolved commit, not only
the mutable branch name.

## Drift detection and rollback

Every rendered Application enables Argo CD automated reconciliation with
`selfHeal: true` and `prune: true`. `ApplyOutOfSyncOnly=true` limits writes to
detected drift. The quality gate asserts these settings for every cluster
render.

Rollback is performed by reverting the responsible Git commit through a pull
request and promoting the revert through the same required checks. Operators
record the affected Application, previous and restored Git SHAs, Argo CD sync
operation, health result, and timestamps in the operational change record.
Direct live edits are break-glass recovery only and must be followed by a Git
reconciliation change.

## Kubernetes security applicability

The chart produces Argo CD Application declarations; workload security
contexts, RBAC, resources, probes, and secret references are validated in the
referenced workload repositories or in the checked-in Kustomize sources.
Cluster-scoped RBAC and privileged workloads are permitted only where required
by their function:

- Whereabouts requires privileged host-network CNI installation.
- KubeVirt, OLM, MetalLB, and storage operators require documented
  cluster-scoped controllers.

These components remain visible in rendered Kustomize output for review.
Credentials are not stored here. Runtime secrets are obtained through
External Secrets or referenced Kubernetes Secrets; the public configuration
boundary in `README.md` applies.

## Temporary exception

| Control gap | Owner | Compensating control | Expiry |
|---|---|---|---|
| Existing `ovh` and `develop` Git source revisions are mutable rather than immutable commit or tag references. | `@lightning-it/lightning-it-security-and-compliance-maintainers` | Protected branches, required app-bound checks, explicit revision allowlist, Argo CD resolved-commit evidence, and fail-closed rejection of `HEAD`/`latest`. | 2026-10-31 |

The exception expires automatically. Before expiry, each cluster owner must
either move the source to an immutable tag or commit, or document a renewed
exception through the accepted governance process.
