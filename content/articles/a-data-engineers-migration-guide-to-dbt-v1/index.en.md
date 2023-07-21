---
title: "A data engineer's migration guide to dbt v1.0.0"
date: 2021-12-06
author: "Tomás Farías Santana"
authorLink: "https://tomasfarias.dev"
tags: ["python", "data-engineering", "dbt"]
---

The highly anticipated [`dbt`](https://www.getdbt.com/product/what-is-dbt/) **version 1.0.0 release** just came out a few days ago, and your data team may be looking to upgrade soon to try out some of the [new features and enhancements](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0#new-features-and-changed-documentation). If you are in charge of said migration, you should also be interested in any potential **breaking changes** that may impact your project, as well as your and your team's daily dbt workflows. If you feel this applies to you, then this migration guide is for you: I'll be going over the new changes coming with a particular focus on avoiding risks during the version upgrade.

This guide will take a lot of information from the [official migration guide](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0), but aims to be more self-contained by offering **practical** migration examples and cover more potential breaking changes.

## Installing dbt

Right from the get go, the way we install `dbt` is no longer `pip install dbt`, as this has been **deprecated** and will raise an error. From v1.0.0 onwards, to install the core `dbt` CLI you should run `pip install dbt-core`.

Before v1.0.0, installing dbt would also install all database adapters (Postgres, Snowflake, Redshift, and BigQuery). But now,  after installing `dbt-core`, you have to install any adapters that you need by running `pip install dbt-<adapter>`.

This has probably brought you issues if you are running Amazon's MWAA, as the Snowflake adapter has a Rust dependency that not all platforms may support[^1]. This was particularly annoying since the Snowflake adapter was installed even if you were not using Snowflake! As someone who ran into these issues a lot, I'm **very happy** to see this change, although I would have preferred the inclusion of the adapters as extras of the main `dbt-core` package to simplify the installation even more.

On a minor note, support for Python 3.6 has been dropped by `dbt` v1.0.0, as we are approaching EOL.

### Docker

Unfortunately, as of the time of writing, the [official Docker images](https://hub.docker.com/r/fishtownanalytics/dbt/tags) have yet to be updated with the v1.0.0 release. And the [official docs](https://docs.getdbt.com/dbt-cli/install/docker) state that we should wait for more information coming soon. I suspect that dbt-labs may be migrating to a new DockerHub organization given that they were still using the old fishtownanalytics (**just speculating**, seems plausible that they would want to clean up things for a 1.0 release).

If you rely on the Docker image for production, development, or CI/CD I recommend either **holding off** on the upgrade until the new images are available, or **building your own** using the official Dockerfile:

```sh
git clone https://github.com/dbt-labs/dbt-core
cd dbt-core
docker build -t dbt:1.0.0 \
    --build-arg BASE_REQUIREMENTS_SRC_PATH=docker/requirements/requirements.txt \
    --build-arg DIST_PATH=dist/ \
    --build-arg WHEEL_REQUIREMENTS_SRC_PATH=docker/requirements/requirements.txt -f docker/Dockerfile .
```

I'm don't know too much about the Docker image building pipeline used by dbt-labs, as I couldn't find any relevant GitHub actions, so I just plugged in arguments that work. You could probably write a more straight forward image:

```docker {hl_lines=[19]}
ARG BASE_IMAGE=python:3.8-slim-bullseye

FROM $BASE_IMAGE

RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
  git \
  ssh-client \
  software-properties-common \
  make \
  build-essential \
  ca-certificates \
  libpq-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install --upgrade pip setuptools
RUN pip install dbt-core==1.0.0
ENV PYTHONIOENCODING=utf-8
ENV LANG C.UTF-8
WORKDIR /usr/app
VOLUME /usr/app
ENTRYPOINT ["dbt"]
```

Just add your adapters to the highlighted line. Although keep in mind I haven't tested this too much!

### `airflow-dbt-python`

If you rely on [`airflow-dbt-python`](https://github.com/tomasfarias/airflow-dbt-python/actions) to run `dbt` operators for `Airflow`, support for v1.0.0 of `dbt` is planned for version 0.10 projected to be released before December 15th 2021.

## Updates to dbt_project.yml

Significant changes have come to the configuration of your `dbt_project.yml`. Here is a summary table of the changes:

| Configuration Node    | Change                                                                 |
| --------------------- | ---------------------------------------------------------------------- |
| `source-paths`        | Replaced with `model-paths`.                                           |
| `data-paths`          | Replaced with `seed-paths`, default is now `seeds`.                    |
| `modules-path`        | Replaced with `packages-install-path`, default  is now `dbt_packages`. |
| `quote-columns`       | Default is now `True` for all adapters except Snowflake.               |
| `test-paths`          | Default is now `tests`.                                                |
| `analysis-paths`      | Default is now `analyses`.                                             |

All these changes should be pretty straight-forward: assuming that your `dbt_project.yml` file in v0.21 was:

```yaml
name: 'my_new_project'
version: '1.0.0'
config-version: 2

profile: 'default'

source-paths: ["models"]
analysis-paths: ["analysis"]
test-paths: ["test"]
data-paths: ["data"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
modules-path: "dbt_modules"
clean-targets:
  - "target"
  - "dbt_modules"

models:
  my_new_project:
    example:
      +materialized: view

seeds:
  +quote_columns: true
```

Your v1.0.0 `dbt_project.yml` now needs attention in the following lines:

```yaml {hl_lines=["7-10",15,18,26]}
name: 'my_new_project'
version: '1.0.0'
config-version: 2

profile: 'default'

model-paths: ["models"]
analysis-paths: ["analyses"] # Only default changed
test-paths: ["tests"] # Only default changed
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
packages-install-path: "dbt_packages"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  my_new_project:
    example:
      +materialized: view

seeds:
  +quote_columns: true # Now default for all adapters except Snowflake
```

## Workflow changes coming with dbt v1.0.0

This section covers changes that affect the way we invoke `dbt` commands, either via the CLI or using Airflow with `airflow-dbt-python`.

### Running dbt singular and generic tests

Before v1.0.0, `dbt` tests came in **two** flavors: `data` and `schema` tests. These are now `singular` and `generic` tests. This changes the invocation of the `dbt test` command as `--data` and `--schema` flags are now deprecated. This means:

```sh
dbt test --data
dbt test --schema
```

Has become:

```sh
dbt test --select test_type:singular
dbt test --select test_type:generic
```

The `test_type` selection method still accepts `data` and `schema` for backwards compatibility:

```sh
dbt test --select test_type:data test_type:schema
```

But I would still recommend migrating these invocations too as backwards compatibility may be dropped in the future.

#### In Airflow with airflow-dbt-python

As of version 0.10, `airflow-dbt-python` reflects these flag changes by deprecating the `data` and `schema` attributes of `DbtTestOperator` in favor of `singular` and `generic`. This means:

```python
data_tests = DbtTestOperator(
    task_id="dbt_test",
    data=True,
)
schema_tests = DbtTestOperator(
    task_id="dbt_test",
    schema=True,
)
all_tests = DbtTestOperator(
    task_id="dbt_test",
    select=["test_type:data", "test_type:schema"],
)
```

Now becomes:

```python {hl_lines=[3,7,11]}
singular_tests = DbtTestOperator(
    task_id="dbt_test",
    singular=True,
)
generic_tests = DbtTestOperator(
    task_id="dbt_test",
    generic=True,
)
all_tests = DbtTestOperator(
    task_id="dbt_test",
    select=["test_type:singular", "test_type:generic"],
)
```

### Deprecated macros and arguments

Some macros have been **deprecated**, ensure these are not in use in your models:
* `adapter_macro`: Use [`dispatch`](https://docs.getdbt.com/reference/dbt-jinja-functions/dispatch) method instead.
* `column_list`.
* `column_list_for_create_table`.
* `incremental_upsert`.

On the arguments side:
* `release` has been removed from `execute_macro`.
* `packages` has been deprecated from `dispatch`.

### The dbt RPC server is no longer part of dbt-core

Eventually, the RPC is being replaced by a new dbt Server. In the meantime, you will have to install the `dbt-rpc` package to continue using the RPC server:

```sh
pip install dbt-rpc
```

Also, instead of using the `dbt rpc` command, you will have to call:

```sh
dbt-rpc serve
```

### New artifact schema versions

The `dbt` following artifacts had their **schemas updated**:
* manifest: Now in [v4](https://schemas.getdbt.com/dbt/manifest/v4/index.html). Most notable changes from previous version:
  - Added metrics nodes in top level key.
  - Renamed schema and data test nodes to reflect their [new names]({{< ref "#running-dbt-data-singular-and-schema-generic-tests" >}}).
* run results: Also in [v4](https://schemas.getdbt.com/dbt/manifest/v4/index.html). No major changes from previous version at least in top level keys.
* sources: Now in [v3](https://schemas.getdbt.com/dbt/sources/v3/index.html). No major changes from previous version at least in top level keys.

This could impact any data ingestion pipelines laid in place to consume this information.

### New logging for adapter plugins

All `dbt` logging has been migrated to a new [structured event interface](https://docs.getdbt.com/reference/events-logging). If you are an adapter maintainer you will have to either set the environment variable `DBT_ENABLE_LEGACY_LOGGER=True` to use legacy logging or migrate to the new one. I'm not an adapter maintainer so I don't think I can add too much to this section. Check the official [README](https://github.com/dbt-labs/dbt-core/blob/HEAD/core/dbt/events/README.md#adapter-maintainers).

## Concluding

For the majority of `dbt` users the migration should be very **straight-forward**: you'll have to review your `dbt_project.yml`, update your `dbt test` calls, and ensure you are using the new PyPI packages in any installation processes.

The lack of a **Docker** image is perhaps the only thing I would consider a blocker for this upgrade, although if you can build your own do so as the new features coming with `dbt` v1.0.0 seem very worth it. I'll make sure to update this post once an official Docker image is published.

[^1]: The inclusion of a Rust dependency in the `cryptography` library was subject to a lot of debate, if you are interested, you may read more about that here: https://lwn.net/Articles/845535/
