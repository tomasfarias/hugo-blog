---
title: "Writing idempotent dbt tasks for Airflow"
date: 2022-05-28
author: "Tomás Farías Santana"
authorLink: "https://tomasfarias.dev"
tags: ["python", "data-engineering", "dbt", "airflow"]
---

Airflow tasks should be designed like transactions in a database[^1], such that executing them always produces the same results. This allows Airflow to safely retry a task one or more times in the event of failure (either via an automated or manual trigger). In other words, Airflow tasks that are designed to exploit Airflow's features (_Airflowic_ tasks) must be **idempotent**.

To ensure Task idempotence, Airflow gives three recommendations, briefly summarized as:
1. Replace `INSERT` with `UPSERT`, to avoid duplicate rows.
2. Avoid **volatile functions** when executing critical task computations.
3. Never read the latest data, but instead read from a specific partition.

In this post I argue idempotence should be applied to all Airflow tasks, including tasks that execute dbt. To illustrate this, I describe a common incremental dbt model pattern and how to alter it to be idempotent.

## Why do we need to ensure idempotence?

Idempotent tasks have a number of benefits:
1. Tasks can be retried as many times as we want, without risk of duplicate results.
2. Airflow can safely catch-up the task from whichever `start_date` we specify.
3. During debugging or reviewing, we can more accurately establish the input and output of the task.

In particular, idempotent dbt tasks allow us to:
1. Retry dbt tasks safely in the event of transient network errors. As of the time of writing, this functionality is not yet implemented in dbt itself, and there is an active [open issue](https://github.com/dbt-labs/dbt-core/issues/3303), signaling the relevancy of this problem.
2. Progressively backfill incremental models, to avoid long-running queries that may run into database timeouts, or use up too many resources.

## Ensuring idempotence when executing dbt tasks in Airflow

Let's go over Airflow's three recommendations to ensure idempotence, and briefly describe how they apply to dbt tasks.

### Replace `INSERT` with `UPSERT`

If we break down dbt models by materialization, we can quickly view that we are upholding this recommendation:
* Ephemeral models are not built in the database, so we can ignore them as no `INSERT` or any other statement is executed.
* View and table models are rebuilt every time we `dbt run` them via `CREATE VIEW AS` and `CREATE TABLE AS` statements, followed by the `SELECT` statement that makes up our model.
* Incremental models can be further broken down into two:
  - Full-refreshes: Runs with `--full-refresh` behave just like when running table materialization models.
  - Incremental: Incremental runs do execute `INSERT` statements and are the only ones that are at a risk of breaking idempotence by not following this particular recommendation. We can avoid this by correctly setting one or more `unique_key` in the model configuration, in which case dbt will perform an `UPSERT`[^3].

### Avoid volatile functions

Airflow specifically mentions Python's `datetime.now()` function from the standard library when making this point, as it's a function that every time is executed it will return a different result[^4]. The behavior of this function is analogous to functions we can find in pretty much any database, like [Postgres' datetime functions](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT) or [Redshift's equivalent](https://docs.aws.amazon.com/redshift/latest/dg/r_GETDATE.html). This raises a problem when writing dbt models, as we need to find a replacement for datetime functions.

Picture the following example scenario: our company processes sales during the day, and after the work day ends we run a dbt table model to produce a report of the sales of the day:

```sql {linenos=table}
SELECT
  id,
  customer_id,
  product_id,
  price,
  date_of_sale
FROM
  sales
WHERE
  date_of_sale = CURRENT_DATE
```

Assuming our workday ends at 18:00 and no more sales are processed after that, we have until 23:59 to execute our table model as this way all sales of the day will match `CURRENT_DATE`. This works fine until one day our database is brought down for critical maintenance work that finishes past 23:59. Airflow picks retries our dbt tasks once the database is up and finishes successfully, but now our table model contains no rows (or some of the first sales of the next workday day).

In this scenario, we can retry the Airflow tasks as many times as we want, and the result will never be what we intended when we wrote the model. From a business perspective, the sales team will now lose access to some valuable reporting for the remainder of the day.

So, let's rewrite the model to uphold Airflow's recommendation. Instead of a volatile function, we will rely on [dbt variables](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/using-variables) and the [`var` function](https://docs.getdbt.com/reference/dbt-jinja-functions/var)[^5]:

```sql {linenos=table,hl_lines=[10]}
SELECT
  id,
  customer_id,
  product_id,
  price,
  date_of_sale
FROM
  sales
WHERE
  date_of_sale = '{{ var("report_date") }}'
```

Now we can simply tell dbt which date of the report are we running, for example, if we are running today's report:

```sh
dbt run sales-report --vars 'report_date: 2022-05-28'
```

Going back to our example scenario, we can manually run this command the next day and build the sales report that we missed due to the critical maintenance by setting the `report_date` variable to the previous date.

However, this is not ideal: we are using Airflow to run our dbt models, we do not want to manually have to run each model that could have been missed. Luckily for us, [airflow-dbt-python](https://pypi.org/project/airflow-dbt-python/) supports all dbt CLI flags, which means a `vars` argument exists and we can use it to set the `report_date` variable. But what should we set it to? Using Python's `datetime.now()` runs into the same issue as it's equivalent to Postgres' `CURRENT_DATE`, and hardcoding it means we have to keep manually update our DAG every day. Since Airflow knows when it's running a DAG, the solution is to let Airflow set the `report_date` via a [templating](https://airflow.apache.org/docs/apache-airflow/stable/concepts/operators.html#concepts-jinja-templating). If we check the [reference](https://airflow.apache.org/docs/apache-airflow/stable/templates-ref.html) we will see Airflow exposes the `ds` variable that simply returns the DAG's logical date in `YYYY-MM-DD` format, exactly what we need.


```python {lineos=table,hl_lines=[5, 17]}
from airflow import DAG
from airflow_dbt_python.operators.dbt import DbtRunOperator
import pendulum

report_date = "{{ ds }}"

with DAG(
    'daily_sales_report',
    description='A DAG to produce a daily sales report',
    schedule_interval="0 0 * * *",
    start_date=pendulum.datetime(2022, 5, 28, tz="UTC"),
) as dag:
    dbt_run = DbtRunOperator(
        project_dir="s3://my-bucket/my-project/",
        target="dbt_airflow_connection",
        select=["sales_report"],
        vars={"report_date": report_date},
    )
```

A few things to cover in this DAG:
* The `schedule_interval` is set to `"0 0 * * *"`, which means our DAG will execute every day at midnight UTC.
* The timezone of the DAG is given by our `start_date` argument, UTC in this example.
* The **logical date** of the DAG will be set to the start of the period covered by the DAG. Since our DAG runs every day at midnight, the start of the period is the previous day at midnight. For example, the first run will start a bit after 2022-05-29 00:00:00, and covers the period from 2022-05-28 00:00:00 up to 2022-05-29 00:00:00. This means the interval starts at 2022-05-28 00:00:00, and this will be the **logical date** of our DAG.

Going back to our example scenario, if the database is down when the DAG runs execution will fail when attempting to connect to the database. But this time, we can simply restart the failed Airflow task at any moment and the report for the day will be correctly produced. We can, and should, extend this further by setting the task's `retries` and `retry_delay` arguments so that Airflow can orchestrate retrying for us.

### Read data from a specific partition

Notice that we have already implemented this recommendation in our previous example: our Airflow dbt task is always reading data from a particular partition given by the DAG's logical date. This makes it so re-running an old `DagRun` will re-read the same data that was read the first time the `DagRun` ran. However, there is a common pattern in dbt models where this is not the case and it's particularly relevant for **incremental models**, take the first example present in the [dbt documentation page](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/configuring-incremental-models) about incremental models:

```sql {lineos=table,hl_lines=[16]}
{{
    config(
        materialized='incremental'
    )
}}

select
    *,
    my_slow_function(my_column)

from raw_app_data.events

{% if is_incremental() %}

  -- this filter will only be applied on an incremental run
  where event_time > (select max(event_time) from {{ this }})

{% endif %}
```

The highlighted line is clearly in violation of the recommendation: if we had this model executed by a DAG, every time we retry it would be reading a different partition of data, assuming data is constantly being inserted into the `raw_app_data.events` table. This can be the source of duplicate rows in models which aggregate results and have not properly configured a `unique_key`. From a business perspective, inconsistencies in daily reports can surface if we are re-trying tasks during the day, as the latest available data is included too. Ultimately, this limits the value we can extract from Airflow, by letting it manage our tasks, even in the event of failures. It's for this reason I argue this pattern leads to _non-Airflowic_ tasks, and should be avoided.

Fortunately, we can once again rely on dbt variables and the `var` function:

```sql {lineos=table,hl_lines=[16]}
{{
    config(
        materialized='incremental'
    )
}}

select
    *,
    my_slow_function(my_column)

from raw_app_data.events

{% if is_incremental() %}

  -- this filter will only be applied on an incremental run
  where event_time >= '{{ var("data_interval_start") }}' and event_time < '{{ var("data_interval_end") }}'

{% endif %}
```

> **IMPORTANT**: We make the range exclusive to avoid duplicates if events happen right in the boundary.

This model has the added benefit of not relying on a subquery to fetch the latest timestamp read, which saves an additional cost compared to simply passing the values via variables (granted, indices or equivalent optimization tools can make this cost cheap).

```python {lineos=table,hl_lines=[16,17]}
from airflow import DAG
from airflow_dbt_python.operators.dbt import DbtRunOperator
import pendulum

with DAG(
    'daily_incremental_model,
    description='A DAG to build a daily incremental model',
    schedule_interval="0 0 * * *",
    start_date=pendulum.datetime(2022, 5, 28, tz="UTC"),
) as dag:
    dbt_run = DbtRunOperator(
        project_dir="s3://my-bucket/my-project/",
        target="dbt_airflow_connection",
        select=["example_incremental_model"],
        vars={
            "data_interval_start": "{{ data_interval_start }}",
            "data_interval_end": "{{ data_interval_end }}",
        },
    )
```
In our previous example, we relied on the `ds` template variable, which is just a formatted version of the DAG's logical date or the start of the period covered by the DAG. In this example, we are using `data_interval_start`, which is the same as the DAG's logical date, and `data_interval_end` which corresponds to the end of the period covered by the DAG.

Although this pattern is critical to how incremental models work, table and view models can have similar patterns. In those cases, the solution proposed is analogous to the incremental model case.

## Conclusion

Both Airflow and dbt are central tools of many modern data stacks. We can extract the most out of them if we optimize how they interact together. In this post, I've shown a particular conflicting dbt model pattern that can be adapted to produce _Airflowic_ tasks, and allow data teams to leverage Airflow to its full capacity when working with dbt.

The adapted pattern is possible thanks to `airflow-dbt-python`, whose ultimate goal is to make dbt a first-class citizen of Airflow. If you have any ideas on how to progress on this goal, you may visit the [project's repo](https://github.com/tomasfarias/airflow-dbt-python) to start a discussion, or reach out to me directly.

[^1]: The Apache Software Foundation, "Best Practices -- Airflow Documentation," Airflow Documentation, May 27, 2022, last modified March 25, 2022, https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html.
[^2]: dbt Labs™ Inc., "Materializations | dbt Docs," dbt Docs, May 27, 2022, https://docs.getdbt.com/docs/building-a-dbt-project/building-models/materializations.
[^3]: In databases that do not support `UPSERT` or Snowflake's `MERGE`, dbt will execute a synthetic `UPSERT` by deleting existing rows before inserting all new data, in the same transaction. Some adapters may be configured to use the native `UPSERT` or the synthetic `DELETE` + `INSERT`.
[^4]: There are tools to make the output of this and other similar functions reproducible, like [time-machine](https://pypi.org/project/time-machine), although these are intended for use in testing environments. That being said, these tools could be used in production systems to get stable results from a function like `datetime.now()`. However, using the template variables provided by Airflow as we talk about in this post is more straight-forward and doesn't incur the additional overhead of a dependency.
[^5]: Notice that the `var` function supports a second argument to set a default variable. Hardcoding a value as the default can be useful for testing purposes.
