+++
title = "Parametrize your pytest tests"
author = ["Tomás Farías Santana"]
date = 2023-02-27
draft = false
+++

The two features [pytest](https://pypi.org/project/pytest/) features I use the most are [fixtures](https://docs.pytest.org/en/latest/explanation/fixtures.html#about-fixtures) and [parametrize](https://docs.pytest.org/en/latest/how-to/parametrize.html) (`pytest.mark.parametrize`). This post is about how you can use the latter to write concise, reusable, and readable tests.


## More tests in less lines of code with parametrize {#more-tests-in-less-lines-of-code-with-parametrize}

The `pytest.mark.parametrize` decorator generates a test for each tuple of parameters we pass it, which **drastically** reduces the lines of code in written unit tests, as the same unit test can be re-used for each tuple of different parameters.

Here is an example:

```python { linenos=true, linenostart=1 }
import typing

import pytest


def fibonacci_range(start: int, stop: int, step: int) -> typing.Iterator[int]:
    """Like the built-in range, but yields elements of the Fibonacci sequence."""
    first = 0
    second = 1
    range_generator = (index for index in range(start, stop, step))
    next_index = next(range_generator)

    for iteration in range(stop):
        if iteration == next_index:
            yield first

            try:
                next_index = next(range_generator)
            except StopIteration:
                break

        first, second = second, first + second


TEST_SEQUENCES = {
    (0, 1, 1): [0],
    (0, 1, 1): [0],
    (0, 1, 2): [0],
    (0, 2, 1): [0, 1],
    (0, 2, 2): [0],
    (0, 5, 1): [0, 1, 1, 2, 3],
    (0, 5, 2): [0, 1, 3],
    (0, 15, 1): [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377],
    (0, 15, 2): [0, 1, 3, 8, 21, 55, 144, 377],
}


@pytest.mark.parametrize(
    "start,stop,step",
    [
        (0, 1, 1),
        (0, 1, 2),
        (0, 2, 1),
        (0, 2, 2),
        (0, 5, 1),
        (0, 5, 2),
        (0, 15, 1),
        (0, 15, 2),
    ],
)
def test_fibonacci_range(start: int, stop: int, step: int):
    """Test the fibonacci_range function with multiple inputs."""
    computed_sequence = list(fibonacci_range(start, stop, step))
    assert computed_sequence == TEST_SEQUENCES[(start, stop, step)]
```
<div class="src-block-caption">
  <span class="src-block-number">Code Snippet 1:</span>
  <i>One unit test turns into 8 with parametrize</i>
</div>

Pytest will now generate one test per each tuple we have passed to the `pytest.mark.parametrize`. The values in each tuple will be used as arguments for the `test_fibonacci_range` test function. Running `pytest` will report that our test run included 6 tests, one for each tuple[^fn:1]:

```sh
$  pytest test.py::test_fibonacci_range -vv
============================================ test session starts ==========================================
platform linux -- Python 3.11.4, pytest-7.4.2, pluggy-1.3.0 -- $HUGO_BLOG/.direnv/python-3.11.4/bin/python
cachedir: .pytest_cache
rootdir: $HUGO_BLOG/content/articles/parametrize-your-pytest-tests
collected 8 items

test.py::test_fibonacci_range[0-1-1] PASSED                                                           [ 12%]
test.py::test_fibonacci_range[0-1-2] PASSED                                                           [ 25%]
test.py::test_fibonacci_range[0-2-1] PASSED                                                           [ 37%]
test.py::test_fibonacci_range[0-2-2] PASSED                                                           [ 50%]
test.py::test_fibonacci_range[0-5-1] PASSED                                                           [ 62%]
test.py::test_fibonacci_range[0-5-2] PASSED                                                           [ 75%]
test.py::test_fibonacci_range[0-15-1] PASSED                                                          [ 87%]
test.py::test_fibonacci_range[0-15-2] PASSED                                                          [100%]

============================================= 8 passed in 0.01s ============================================
```

We got 6 tests for the price (in lines of code) of one[^fn:2]!

Next to each item, enclosed in square brackets, we see the parameters used for each test, separated by a dash: `[0-1-1]`, `[0-1-2]`, and so on. Each generated test can also be ran individually by specifying the parameters at the end of the test we wish to run[^fn:3]:

```sh
$  pytest 'test.py::test_fibonacci_range[0-1-1]' -vv
============================================ test session starts ==========================================
platform linux -- Python 3.11.4, pytest-7.4.2, pluggy-1.3.0 -- $HUGO_BLOG/.direnv/python-3.11.4/bin/python
cachedir: .pytest_cache
rootdir: $HUGO_BLOG/content/articles/parametrize-your-pytest-tests
collected 1 item

test.py::test_fibonacci_range[0-1-1] PASSED                                                          [100%]

============================================= 1 passed in 0.00s ===========================================
```


## Stacking parametrize decorators {#stacking-parametrize-decorators}

In our example, we passed multiple arguments to parametrize `test_fibonacci_range`: `start`, `stop`, and `step`. Writing down all the possible parameter tuples we are interested in testing for each argument combination can take up a lot of time. Thankfully, pytest allows us to stack `pytest.mark.parametrize` decorators to get all possible combinations of parameters.

By stacking decorators, our example test can be re-written as:

```python { linenos=true, linenostart=1 }
@pytest.mark.parametrize("start", [0])
@pytest.mark.parametrize("stop", [1, 2, 5, 15])
@pytest.mark.parametrize("step", [1, 2])
def test_fibonacci_range_stacked(start: int, stop: int, step: int):
    """Test the fibonacci_range function with multiple inputs."""
    computed_sequence = list(fibonacci_range(start, stop, step))
    assert computed_sequence == TEST_SEQUENCES[(start, stop, step)]
```
<div class="src-block-caption">
  <span class="src-block-number">Code Snippet 2:</span>
  <i>Stacking parametrize decorators produces a Cartesian product of all parameters</i>
</div>

Which generates the same 8 parameter tuples passed to parametrize the test as the previous version of this example:

```sh
$  pytest test.py::test_fibonacci_range_stacked -vv
============================================= test session starts =========================================
platform linux -- Python 3.11.4, pytest-7.4.2, pluggy-1.3.0 -- $HUGO_BLOG/.direnv/python-3.11.4/bin/python
cachedir: .pytest_cache
rootdir: $HUGO_BLOG/content/articles/parametrize-your-pytest-tests
collected 8 items

test.py::test_fibonacci_range_stacked[1-1-0] PASSED                                                 [ 12%]
test.py::test_fibonacci_range_stacked[1-2-0] PASSED                                                 [ 25%]
test.py::test_fibonacci_range_stacked[1-5-0] PASSED                                                 [ 37%]
test.py::test_fibonacci_range_stacked[1-15-0] PASSED                                                [ 50%]
test.py::test_fibonacci_range_stacked[2-1-0] PASSED                                                 [ 62%]
test.py::test_fibonacci_range_stacked[2-2-0] PASSED                                                 [ 75%]
test.py::test_fibonacci_range_stacked[2-5-0] PASSED                                                 [ 87%]
test.py::test_fibonacci_range_stacked[2-15-0] PASSED                                                [100%]

============================================= 8 passed in 0.01s ===========================================
```

> When generating parameter tuples, pytest will iterate over all the parameters in one decorator before advancing to the next parameter in the decorators that follow.
>
> This is equivalent to a `for` loop:
>
> ```python
> for step in [1, 2]:
>     for stop in [1, 2, 5, 15]:
>         for start in [0]:
>             yield (step, stop, start)
> ```


## Pass parameters to pytest fixtures {#pass-parameters-to-pytest-fixtures}

Pytest fixtures are used to hide away complicated setup steps required for unit testing. We can pass parameters to fixtures by matching the name of a fixture with the name of an argument used in `pytest.mark.parametrize` and setting the `indirect` argument.

For example, imagine you build an app that can interact with multiple database backends. Regardless, of the database backend in use, our app should function the same. As we have abstracted all database interaction under a common interface, we can write a single test and parametrize it to run with multiple backends. We already have fixtures that return test clients for each of our databases, used in the unit tests for each of the clients, so we can write a fixture that can returns both according to how we parametrize it:

````python { linenos=true, linenostart=1 }
import pytest


@pytest.fixture
def db_client(request, postgres_client, mysql_client):
    if request.param == "postgres":
        return postgres_client
    elif request.param == "mysql":
        return mysql_client
    else:
        raise ValueError(f"Unsupported db: '{request.param}'")


@pytest.mark.parametrize("db_client", ["postgres", "mysql"], indirect=True)
def test_db_operation(db_client):
    """Test an operation that can be executed on multiple RDBMS."""
    ...
````

Any application test can use the `db_client` fixture and ensure it behaves the same regardless of database backend.


## Customize the parameter ids in the test report {#customize-the-parameter-ids-in-the-test-report}

Pytest allows us to customize the id of each parameter that will be shown in the test report. This can be useful to have **human readable names** in our test reports.

Coming back to our first example:

````python { linenos=true, linenostart=1 }
@pytest.mark.parametrize("start", [0])
@pytest.mark.parametrize("stop", [1, 2, 5, 15])
@pytest.mark.parametrize("step", [1, 2], ids=["single", "double"])
def test_fibonacci_range_with_ids(start: int, stop: int, step: int):
    """Test the fibonacci_range function with multiple inputs."""
    computed_sequence = list(fibonacci_range(start, stop, step))
    assert computed_sequence == TEST_SEQUENCES[(start, stop, step)]
````
<div class="src-block-caption">
  <span class="src-block-number">Code Snippet 3:</span>
  <i>Our step arguments now have names</i>
</div>

In our test report, pytest will output "single" and "double" as the parameter ids instead of 1 and 2 respectively:

````sh
$  pytest test.py::test_fibonacci_range_with_ids -vv
============================================= test session starts =========================================
platform linux -- Python 3.11.4, pytest-7.4.2, pluggy-1.3.0 -- $HUGO_BLOG/.direnv/python-3.11.4/bin/python
cachedir: .pytest_cache
rootdir: $HUGO_BLOG/content/articles/parametrize-your-pytest-tests
collected 8 items

test.py::test_fibonacci_range_with_ids[single-1-0] PASSED                                           [ 12%]
test.py::test_fibonacci_range_with_ids[single-2-0] PASSED                                           [ 25%]
test.py::test_fibonacci_range_with_ids[single-5-0] PASSED                                           [ 37%]
test.py::test_fibonacci_range_with_ids[single-15-0] PASSED                                          [ 50%]
test.py::test_fibonacci_range_with_ids[double-1-0] PASSED                                           [ 62%]
test.py::test_fibonacci_range_with_ids[double-2-0] PASSED                                           [ 75%]
test.py::test_fibonacci_range_with_ids[double-5-0] PASSED                                           [ 87%]
test.py::test_fibonacci_range_with_ids[double-15-0] PASSED                                          [100%]

====================================================== 8 passed in 0.01s ==================================
````

This is significantly more useful with complex types where pytest's default behavior is to take the argument name and concatenate an index, like with instances of `datetime.datetime`:

````python { linenos=true, linenostart=1 }
import datetime as dt

import pytest

first_day_of_month = [dt.datetime(2023, month, 1) for month in range(1, 13)]


@pytest.mark.parametrize("date", first_day_of_month)
def test_year_is_2023(date):
    """Dummy test."""
    assert date.year == 2023


@pytest.mark.parametrize(
    "date",
    first_day_of_month,
    ids=map(lambda d: d.strftime("%B"), first_day_of_month),
)
def test_year_is_2023_with_ids(date):
    """Dummy test."""
    assert date.year == 2023
````
<div class="src-block-caption">
  <span class="src-block-number">Code Snippet 4:</span>
  <i>Using month names as ids</i>
</div>

The pytest test report will show `date{index}` for `test_year_is_2023` and the month names for `test_year_is_2023_with_ids`:

````sh
$  pytest test_2.py -vv
============================================= test session starts =========================================
platform linux -- Python 3.11.4, pytest-7.4.2, pluggy-1.3.0 -- $HUGO_BLOG/.direnv/python-3.11.4/bin/python
cachedir: .pytest_cache
rootdir: $HUGO_BLOG/content/articles/parametrize-your-pytest-tests
collected 24 items

test_2.py::test_year_is_2023[date0] PASSED                                                          [  4%]
test_2.py::test_year_is_2023[date1] PASSED                                                          [  8%]
test_2.py::test_year_is_2023[date2] PASSED                                                          [ 12%]
test_2.py::test_year_is_2023[date3] PASSED                                                          [ 16%]
test_2.py::test_year_is_2023[date4] PASSED                                                          [ 20%]
test_2.py::test_year_is_2023[date5] PASSED                                                          [ 25%]
test_2.py::test_year_is_2023[date6] PASSED                                                          [ 29%]
test_2.py::test_year_is_2023[date7] PASSED                                                          [ 33%]
test_2.py::test_year_is_2023[date8] PASSED                                                          [ 37%]
test_2.py::test_year_is_2023[date9] PASSED                                                          [ 41%]
test_2.py::test_year_is_2023[date10] PASSED                                                         [ 45%]
test_2.py::test_year_is_2023[date11] PASSED                                                         [ 50%]
test_2.py::test_year_is_2023_with_ids[January] PASSED                                               [ 54%]
test_2.py::test_year_is_2023_with_ids[February] PASSED                                              [ 58%]
test_2.py::test_year_is_2023_with_ids[March] PASSED                                                 [ 62%]
test_2.py::test_year_is_2023_with_ids[April] PASSED                                                 [ 66%]
test_2.py::test_year_is_2023_with_ids[May] PASSED                                                   [ 70%]
test_2.py::test_year_is_2023_with_ids[June] PASSED                                                  [ 75%]
test_2.py::test_year_is_2023_with_ids[July] PASSED                                                  [ 79%]
test_2.py::test_year_is_2023_with_ids[August] PASSED                                                [ 83%]
test_2.py::test_year_is_2023_with_ids[September] PASSED                                             [ 87%]
test_2.py::test_year_is_2023_with_ids[October] PASSED                                               [ 91%]
test_2.py::test_year_is_2023_with_ids[November] PASSED                                              [ 95%]
test_2.py::test_year_is_2023_with_ids[December] PASSED                                              [100%]

===================================================== 24 passed in 0.02s ==================================
````


## Why not to parametrize {#why-not-to-parametrize}

Although `pytest.mark.parametrize` has become a staple of my unit tests, it comes at the cost of complexity and performance, like with many other abstraction layers.

As `pytest.mark.parametrize` makes it really easy to generate new tests, it is tempting to want to include as many parameter combinations as possible. This temptation comes up **a lot** when stacking `pytest.mark.parametrize` decorators.

But doing so cause problems:

1.  We may be led to believe our tests are **exhaustive** when in fact we are not covering our **problem domain**.
    -   "My unit test is has coverage of every possible 32-bit signed integer, what do you mean it's failing?".
    -   "Well, a user has a balance of $0.50 in their account...".
2.  With too many tests, a test suite can take too long to run[^fn:4].
    -   A test suite that nobody runs is useless, and the more time a test suite takes to run, the less frequently it will be ran.
3.  It can be easy to obfuscate the generated test cases by setting (or not setting) ids, or with complex code to generate argument tuples.
    -   With every new argument we parametrize, the number of possible combinations (and in turn the number of tests) can grow exponentially.
    -   When debugging, we now may need to keep in our minds not only the test but the code that generates the test.


## In conclusion {#in-conclusion}

When I started using pytest I was mostly annoyed about having to replace all my `self.assertEqual` calls for `assert` statements. It wasn't until I started diving into its [documentation](https://docs.pytest.org/en/latest/) that I learned why is it so loved as a testing framework. `pytest.mark.parametrize` is just one of the features of pytest I regularly now employ in my unit tests, and I wanted to give you a glimpse of how that looks.

There is a lot more going for pytest, like fixtures and plugins, and I hope to cover more of that in the future.

[^fn:1]: I like the expressiveness of 2 levels of verbosity (`-vv`).
[^fn:2]: And the "price" of writing the decorator, which remains constant relative to the lines in our test.
[^fn:3]: Notice the test item is enclosed in quotes. Alternatively, we would have to escape the square brackets.
[^fn:4]: This point can be addressed by having a reduced test suite to run during development, and a complete test suite to run before deployment.
