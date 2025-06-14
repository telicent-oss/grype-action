# Grype Action

This repository provides a GitHub Action that wraps our standard patterns of usage of the [Anchore Grype][1] and the
[Anchore Scan Action][2] into a composite action so we can simplify our workflows and standardise improvements to how
we surface Grype scan information in our builds.

# Usage

At its most basic the action is used as follows:

```yaml
name: Grype Scan Example
on: 
  push:
  workflow_dispatch:

jobs:
  example:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # Normal Job setup steps happen...
     
      # Run a Grype Filesystem Scan
      - name: Grype Filesystem Scan
        uses: telicent-oss/grype-action@v1
        with:
          scan-type: fs
          scan-ref: .
          scan-name: maven-poms

      # Some more build steps that generate a Docker image...

      # Run a Grype Image Scan
      - name: Grype Image Scan
        uses: telicent-oss/grype-action@v1
        with:
          scan-type: image
          scan-ref: telicent/some-image@1.2.3
          scan-name: some-image
```

In the above example we invoke the action twice, once to do a `fs` scan and another to do an `image` scan.

## GitHub Token Permissions

This action needs a GitHub Token in order to query the GitHub Releases API to discover the release binaries for
installing the necessary `grype` and `vexctl` tools.  By default we take the default GitHub Token for the workflow from
the `github.token` context.  If you have restricted the `permissions` in your Workflow file then you **MAY** need to
provide a custom token rather than relying on the default.

If your build fails with the following error:

> You need at least read:packages scope to get a package's versions.

Then your token does not have correct permissions, either amend the `permissions` you are requesting for the token in
your workflow configuration, or use an Actions secret to provide a token for this purpose.

### Permissions for Remote VEX

Also, if you are using the [Remote VEX](#remote-vex-statements) feature then you **MUST** provide a token that has
permissions to read all the repositories you want to retrieve Remote VEX statements from otherwise some repositories
**MAY** be ignored, and you **MAY** not get the desired vulnerability suppressions you are expecting.

In this scenario the minimum permissions required for this feature to work correctly are `read:packages` and `repo`, and
for the `repo` permission it **MUST** pertain to all repositories you wish to access.  This means that the default
GitHub token permissions are generally **NOT** sufficient to use this feature, **UNLESS** all the referenced
repositories are public repositories.

If you provide a custom GitHub token then you **MUST** also customise the `gh-user` input to match the username of the
user who generated the GitHub token.

## VEX Support

This action now includes built-in support for processing of Vulnerability Exploitability Exchange (VEX) statements in
OpenVEX JSON format.  OpenVEX statements may be provided in two ways:

- Local statements from a `.vex/` directory in the working directory.
- Remote statements from a `.vex/` directory in one/more remote repositories configured via the optional `remote-vex`
  input, see [Remote VEX Statements](#remote-vex-statements)

All discovered OpenVEX statements are merged together using the [`vexctl`][4] tool to create a single VEX statements
file for the scan, this will be attached to the build as an artifact named `<scan-name>-merged-vex-statements` so it can
be reviewed if needed.

Note that the way Grype implements VEX support differs from Trivy so we don't pass the merged OpenVEX statements to
Grype directly, rather we use them to generate a `.grype.yaml` file with ignore rules for each VEX statement that
indicates a vulnerability is not applicable.  If your repository also has a `.grype.yaml` file then the generated file
will be merged with your existing file for the scan, and then your original file restored afterwards.

Any HIGH/CRITICAL severity vulnerabilities that are suppressed as a result will be displayed in the GitHub Build Summary
and listed in the full Grype JSON Report:

![Example Suppressed Vulnerabilities Report](vex-suppression-example.png)

### Remote VEX Statements

When the `remote-vex` input is given, it is a new line separated list of repository references in the form
`<owner>/<repo>`, optionally with an `@<branch>` suffix if the VEX statements are not on the `main` branch e.g. you use
a different default branch name.

For each remote repository reference the action will do a sparse git clone of the `.vex/` directory, copy those files
into a shared `.remote-vex/` directory, and then merge those with any local VEX statements.  The following example shows
this in action:

```yaml
name: Remote VEX Example
on: 
  push:
  workflow_dispatch:

jobs:
  example:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # Normal Job setup steps happen...
     
      # Run a Grype Image Scan
      - name: Grype Image Scan
        uses: telicent-oss/grype-action@v1
        with:
          scan-type: image
          scan-ref: telicent/some-image@1.2.3
          scan-name: some-image
          remote-vex: |
            telicent-oss/telicent-base-images
            telicent-oss/smart-caches-core
          gh-user: ${{ secrets.REMOTE_VEX_USER }}
          gh-token: ${{ secrets.REMOTE_VEX_TOKEN }}
```

Here we are configuring the action to retrieve remote VEX statements from the `telicent-oss/telicent-base-images` and
`telicent-oss/smart-caches-core` repositories `main` branches.

Notice that for this to work you **MAY** need to set the `gh-user` and `gh-token` inputs to custom values, in this
example these reference some Action secrets that have been created.  The token passed in as the `gh-token` input
**MUST** have the ability to read the contents of this repository, it **MUST** also have the ability to read packages
from repositories as the `grype` and `vexctl` command line tools needed are installed via querying the GitHub Releases
API, see [Token Permissions](#github-token-permissions) for more information on this.

Note that if any of the specified repositories does not exist, does not have the referenced branch, or no `.vex/`
directory exists on that branch then a build warning is issued e.g.

![No Remote VEX Warning example](no-remote-vex-warning.png)

This warning is issued regardless of the reason for failure e.g. bad [Token Permissions](#github-token-permissions), no
`.vex/` directory in remote repository etc.

# Inputs

| Input | Required? | Default | Purpose |
|-------|-----------|---------|---------|
| `scan-type` | Yes | N/A | Specifies the kind of Grype scan to run, one of `fs`, `image`, `config` or `sbom` |
| `scan-ref` | Yes | N/A | Specifies what to scan, for `scan-type` of `fs`/`sbom` this is a file system path, for `image` this is a reference to a container image, for `config` this is a reference to a Dockerfile |
| `scan-name` | Yes | N/A | A unique name (within the calling workflow) for this scan used to disambiguate the scan artifacts when they are attached as artifacts to the build. |
| `remote-vex` | No | `null` | If your scans involved building atop of libraries/base images provided in other repositories you can supply one/more references to repositories here from which VEX statements will be retrieved, see [VEX Support](#vex-support). |
| `allow-unfixed` | No | `false` | Sets the `only-fixed` input passed on to the [`anchore/scan-action`][1] that controls whether unfixed HIGH/CRITICAL severity vulnerabilities fail the build. |
| `gh-token` | No | `github.token` | Sets the GitHub token used to authenticate to GitHub to fetch Grype release metadata. |

# Outputs

| Output | Description |
|--------|-------------|
| `scan-results` | Name of a GitHub Actions artifact that has been uploaded and contains the full Grype JSON results. |
| `scan-results-file` | Name of the Grype JSON file within the uploaded GitHub Actions artifact. |
| `scan-results-url` | Full URL to the uploaded artifact. |

# License

This Action is licensed under the Apache License 2.0, see [LICENSE](LICENSE) and [NOTICE](NOTICE) for more information.

[1]: https://github.com/anchore/grype
[2]: https://github.com/anchore/scan-action
[4]: https://github.com/openvex/vexctl

# Related Work

See also our equivalent [`telicent-oss/trivy-action`](https://github.com/telicent-oss/trivy-action) which was developed
first, this action represents a subset of that actions functionality since `trivy` has a few more features vs `grype`.
