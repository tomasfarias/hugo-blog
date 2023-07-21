---
title: "Working with dbt's artifacts: run_results.json"
date: 2021-07-26
author: "Tomás Farías Santana"
tags: ["dbt", "data-engineering", "data-warehouse", "sql", "jq"]
---

[`dbt`](https://www.getdbt.com/product/what-is-dbt/) is quickly becoming the standard tool for managing data-pipeline transformations (the T in ETL), and having worked with it for a year I'm getting used to some of its quirks. In particular, as I used the tool more and more, the necessity of extracting metrics that could be used to optimize our transformation pipeline, as well as pin-point performance issues became apparent. Luckily for us, the artifacts produced by executing the most common `dbt` commands contain some very useful information for us to dig our data-analysis teeth into. However, I found that the `dbt` [documentation on artifacts](https://docs.getdbt.com/reference/artifacts/dbt-artifacts) doesn't give more than a passing mention of what may be done with the data contained in them. As such, this post will dedicate itself to offer examples of the utility that may be extracted from the `run_results.json` `dbt` artifact.

For reference, all the work presented was done with the v2 schema of `run_results.json`, as produced by version `0.20.0` of `dbt`. If in the future the schemas are updated, I can't guarantee that some of the examples presented here still work, but hopefully the information available in newer versions is similar enough. The schema for `run_results.json` is documented by `dbt` [here](https://schemas.getdbt.com/dbt/run-results/v2.json).

To parse the JSON files, I'll be [`jq`](https://stedolan.github.io/jq/), a tool which is available for most OS distributions.

## Reviewing your latest `run_results.json`

As you have probably already seen in the `dbt` logs, we can timing and status information from `run_results.json` when using any of the following `dbt` commands:
* `docs generate`
* `run`
* `seed`
* `snapshot`
* `test`

### Diagnose `run_results.json`

We may interested in doing a quick diagnosis of our latest `dbt` command to answer, for example:

* How many models were successful?
* How many models did not succeed?

We can do that with the following `jq` command:

```shell
cat target/run_results.json | jq -r '[.results[].status] | group_by(.) | map({"status": unique, "total": length})'
```

Which would leave us with an output like:
```json
[
  {
    "status": [
      "error"
    ],
    "total": 8
  },
  {
    "status": [
      "skipped"
    ],
    "total": 10
  },
  {
    "status": [
      "success"
    ],
    "total": 30
  }
]
```

To take a look at the actual error messages to do some debugging, we may run:

```shell
cat target/run_results.json | jq -r '.results | map(select(.status == "error")) | map({"model": .unique_id, "error_message": .message})'
```

### Finding the most expensive models

Timing information is probably the first thing we look at when trying to diagnose performance issues. We can use the following command-line script to find the most expensive models:

```shell
cat target/run_results.json | jq -r '[{model: .results[].unique_id, execution_time: .results[].execution_time?}] | sort_by(.execution_time) | .[-1]'
```

To get the most expensive model right out of the results. The output will look something like:

```json
{
  "model": "model.dbt_project.fct_visits",
  "execution_time": 465.81539845466614
}
```

Important to note that `execution_time` is measured in seconds.

### Loading results into Amazon Redshift

This information may be loaded into our data-warehouse for further processing or to connect with a visualization tool. Of course we could just insert the values after running our command-line script, but most data-warehouses offer some utility to work with JSON files directly. For example, when working with [Amazon Redshift](https://aws.amazon.com/redshift/), we can upload our `run_results.json` to an [Amazon S3](https://aws.amazon.com/s3/) bucket and create a table for the results.

Our table schema may look like the following:

```sql
CREATE TABLE dbt_run_results (
    status VARCHAR,
    unique_id VARCHAR,
    compile_start_ts TIMESTAMP NULL,
    compile_end_ts TIMESTAMP NULL,
    execute_start_ts TIMESTAMP NULL,
    execute_end_ts TIMESTAMP NULL,
    exec_time FLOAT NULL,
    message VARCHAR
);
```

Unfortunately, Redshift cannot handle nested JSON structures like the one in `run_results.json`, so we have to do some preprocessing[^1]. Essentially, we need to flatten the results so that we have a JSON array of results from a dbt run. Said preprocessing may be done in Python, like so:

```python
def run_results_to_json_array(json_str: str) -> str:
    """Turns a dbt run results JSON string into a JSON array."""
    import json

    json_dict = json.loads(json_str)
    json_arr_str = ""

    for result in json_dict["results"]:
        new_result = {
            "status": result["status"],
            "unique_id": result["unique_id"],
            "exec_time": result["execution_time"],
            # message key is not required, so it may be missing
            "message": result.get("message"),
        }

        for timing in result["timing"]:
            key_prefix = timing["name"]
            new_result[f"{key_prefix}_start_ts"] = timing.get("started_at")
            new_result[f"{key_prefix}_end_ts"] = timing.get("completed_at")

        json_arr_str += json.dumps(new_result)

    return json_arr_str
```

After we have uploaded our new `run_results_processed.json` file, we can load it with:

```sql
COPY dbt_run_results FROM 's3://mybucket/run_results_processed.json'
IAM_ROLE 'arn:aws:iam::0123456789012:role/MyRedshiftRole'
FORMAT AS JSON;
```

## In conclusion and what comes next

I set out to write this more practical post as I did some exploring of `run_results.json` myself, and I hope that folks working with `dbt` and looking to do some quick run analysis can also find some use to it. Ideally, this post becomes the one you Google all the time when you need to remember a `jq` command to work with `run_results.json`!

Finally, I would like this post to be part of a "mini-series" of posts that work with `dbt` artifacts: `run_results.json` is just the first I decided to take a look at. Coming up, I do plan to dig into `manifest.json` as there is some valuable information to extract from there.


[^1]: A previous version of this post suggested the usage of a JSONPath file. Since then I've learned that Redshift does not support any of the more advanced JSONPath features, like wildcards, making iterating over a nested structure impossible.
