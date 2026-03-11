+++
title = "TIL: How to use fixtures conditionally with pytest"
author = ["Tomás Farías Santana"]
date = 2022-12-27T00:00:00+01:00
draft = false
+++

Pytest has changed the way I write unit tests: As I work on them, I am constantly looking out for opportunities to use `pytest.mark.parametrize` to extend the scope of my tests, or `pytest.fixture` to manage resources used by tests. Recently, I learned it is possible to parametrize fixtures with `pytest.mark.parametrize` using the `indirect` argument:

```python
import socket

import pytest

import app

@pytest.fixture
def db_client(request):
    match request.param:
        case "postgres":
            client = app.setup_postgres_client()
        case "TCP":
            client = app.setup_sqlite_client()
        case _:
            raise ValueError("Only UDP or TCP socket types are supported")

    yield client

    app.teardown_db_client(client)

@pytest.mark.parameterize("db_client", ["postgres", "sqlite"], indirect=True)
def test_app(my_socket):
    app.flush(db_client)
    ...
```

As showcased, this allows me to generate multiple test cases that each interact with a different database client[^fn:1], pretty useful if your application can work with multiple databases.

[^fn:1]: Each client should be adapted to have the same common interface so that they can be used interchangeably by our app.
