---
title: "Setting up your Python development workflow in 2021"
date: 2021-07-19
author: "Tomás Farías Santana"
authorLink: "https://tomasfarias.dev"
tags: ["python", "workflow"]
---

It's amazing to reflect on how much has the Python ecosystem evolved since I was learning the language almost 10 years ago: type hints and static type checking with [`mypy`](https://pypi.org/project/mypy/) were not widely adopted; `pip`,`venv`, and `setup.py` files were all you used for packaging and dependency management; and [PEP 8](https://www.python.org/dev/peps/pep-0008/) was our only tool to coordinate a consistent style. Nowadays, starting a new Python project with an expected size of more than a couple of scripts involves setting up static type checking, automated code formatting, and relying on [Poetry](https://python-poetry.org/) or [Pipenv](https://pipenv.pypa.io/) for packaging and dependency management.

Checking out the [`pre-commit`](https://pre-commit.com/) hooks and CI/CD pipelines of new repositories I'm browsing usually ends up being a very rewarding experience, as it leads to discovering new tools to incorporate into my own workflow, as well as to new ideas on how can they be optimized for a given workflow. However, learning this tooling can be a daunting task for new developers who are not familiar with the standards that are **slowly** forming in the Python world: from their point-of-view, they just see annoying failing checks in their pull requests and an increase in time required to set-up their local development environments.

Hence, the idea behind this post is to serve as a review of the existing development workflow tooling, as well as to provide an example of a basic setup of a project to get anybody going; already available as the [`python-package-template`](https://github.com/tomasfarias/python-package-template). That being said, each tool could merit a blog post just on it's own (and maybe some of them will have!), so it would not be possible to cover each one of them in-depth; there will be links to official documentation to cover needs for further reading. At the very least, I hope I can show you a practical workflow to get you coding ASAP that leverages some of the most used tools in the Python ecosystem.

## Packaging and dependency management

As already mentioned in the introduction, package management in Python has gone a long way. That doesn't mean the good old `pip` + `venv` combo is going anywhere: it's still my choice of packaging for any small and quick projects or script collections due to how quick it is to setup a `venv`, `pip install` everything you need, and `pip freeze` your environment into a `requirements.txt` file:

```sh
python -m venv venv
source venv/bin/activate
pip install package1 package2
pip freeze > requirements.txt
```

However, as soon as you start building a more intricate development workflow you start running into inconveniences:
* Need to fix and install development/testing dependencies? That requires another file, usually named `dev_requirements.txt`
* Did you forget to initialize a virtual environment? Now your system Python installation has conflicting dependencies, or your project just won't build.
* Adding a description, semantic versioning, other metadata, and publishing your project requires adding and maintaining one more file: `setup.py`.

Enter the more modern `Poetry` and `Pipenv`. As dependency managers, they attempt to abstract the efforts required to maintain a reproducible environment across different workstations, a big one being the effort required to resolve dependency versions. For the packaging side, `Poetry` helps us build, and publish our Python packages to PyPI. I'm personally more biased towards `Poetry` as it's the one I've used the most. What drew me in was my familiarity with `toml` files, having worked with Rust which uses a `cargo.toml`, the friendly error messages and intuitive CLI, and the convenience of including a command to publish to PyPI, which meant I could integrate `Poetry` into my CI/CD pipelines with ease.

Going over all the nuances of `Poetry` would take a long time, so instead I'll share the most commands and configurations I use, so that I can give you a basic workflow to work with. The `Poetry` [docs](https://python-poetry.org/docs/) are comprehensive and well written, and I encourage you to go over them for more information.

Starting a project from scratch is as simple as:

```sh
poetry new my-new-project
```

This will create a new `my-new-project` directory, and populate it with a basic file structure, including a README and, more importantly for this post, a `pyproject.toml`.

If we are starting `my-new-project` from an existing project:

```sh
cd path/to/my-new-project
poetry init
```

We can add dependencies to `pyproject.toml` under the `[tool.poetry.dependencies]` section, or just using the following command:

```sh
poetry add "requests=2.26.0" beautifulsoup4@latest "pandas>=1.3"
```

As illustrated, dependency version constraints can also be specified when adding. In similar fashion, development dependencies can be added with the `--dev` flag:

```sh
poetry add --dev pytest black isort
```

Once added, we can install our dependencies. Development dependencies will be installed by default unless we use the `--no-dev` flag:

```sh
poetry install
poetry install --no-dev
```

After running this command a `poetry.lock` file will be created in the root directory of our project with the exact dependency versions we just installed. This file should be committed to version control to ensure the environment you just created can be exactly reproduced.

To run a script in a project or a tool, like one of our development dependencies, use `run`, e.g.:

```sh
potery run black my_script.py
poetry run pytest tests/test_my_script.py
poetry run python my_script.py
```

Finally, whenever we need to update a dependency, we can run:

```sh
poetry update requests
```

Keep in mind this will update `requests` to the **latest version that matches the current constraint** specified in `pyproject.toml`, not necessarily the absolute latest version. If we wish to upgrade to a version that does not satisfy the version constraint, we must re-add it with `poetry add` first.

## Styling and code formatting

Styling discussions are a waste of time, but adhering to a common style is not without its benefits, most of which boil down to lowering the barriers of entry to a project as new engineers can work with a style they are already used to. Luckily for us, there is already a style guide for Python that we can all follow and have a consistent style across all codebases: PEP 8. There is just one problem that we need to solve: how can we ensure our codebase adheres to the style guide? That's where the first set of tools comes in:
* [`black`](https://github.com/psf/black): a code formatter that asks us to relinquish control over our codebase's styling so that we can focus on more important tasks.
* [`flake8`](https://github.com/PyCQA/flake8): a PEP 8 validator to ensure we stay compliant.
* [`isort`](https://github.com/PyCQA/isort): an `import` statement sorter.

These three tools can each be manually run to style a file or multiple:

```sh
black /path/to/file.py
flake8 /path/to/file.py
isort /path/to/file.py
```

**But that's not enough**: we would like to automate the process so that even if we forget, we are still adhering to a consistent style. Enter [`pre-commit`](https://pre-commit.com/): a tool built to manage installation and execution of `git` hooks. I use `pre-commit` to run a lot of tools from this guide every time I commit and encourage you to do the same. Configuring `pre-commit` to run your styling suite is as simple as creating a `.pre-commit-config.yaml` in the root of your project like the following:

```yaml
repos:
  - repo: https://github.com/psf/black
    rev: 21.7b0
    hooks:
    - id: black
      types_or: [python, pyi]

  - repo: https://gitlab.com/pycqa/flake8
    rev: 3.9.2
    hooks:
      - id: flake8

  - repo: https://github.com/pycqa/isort
    rev: 5.5.2
    hooks:
      - id: isort
```

And running `pre-commit install`. Now any new Python files we attempt to `git commit` will be formatted by `black`, validated by `flake8`, and have their `import` statements sorted by `isort`; no inconsistent styling is getting past this checks! As an added benefit, since the files will be automatically formatted once committed, a developer can have their IDE setup with different styling guidelines that better suite their preferences.

### A note on line length

Unfortunately, PEP 8 does not always give strict formatting directives but recommendations that may be open to different interpretations, and this means that the tools we are using can be configured to support those interpretations. I say "unfortunately" because this means we can't have a single configuration that fits all projects, and teams may need to discuss the finer tweaking.

Perhaps the most controversial PEP 8 recommendation is the 80 line character limit: I've worked with teams that strictly followed the 80 character limit, and some others that went up to 110 character lines. I don't think there's a right answer here, and I lean to Raymond Hettinger's words<sup>1</sup>: anything around "90ish" is sensible for anything outside the standard library. His follow up comment is also relevant: character limits should be considered warnings that legibility may be at risk, and some actions may need to be taken, but we should never sacrifice clarity just to make a line fit under 80 characters.

Whatever you decide, `black` and `flake8` can be configured to support any line length:
* For `black`, add the following section to your `pyproject.toml`:

```toml
[tool.black]
line-length = 88
```

* For `flake8`, add the following section the `.flake8` file:

```toml
[flake8]
max-line-length = 88
```

Personally, I'm going with a character limit of 88 to copy `black`'s default settings.

## Static type checking

Static type checking helps us catch plenty of common bugs. The more obvious bugs static type checking helps with are those that raise `TypeError` exceptions, which may be prevented by simply declaring the types our methods require and using a tool like `mypy` to assert the correct usage of said methods. Moreover, I would argue that catching bugs is not the only benefit of static type checking or, more precisely, type declarations: it can be extremely helpful when diving into an unknown codebase to know exactly which types does a function expect as it assists us in understanding data flow in a program, and can save us a lot of time when introducing new patches.

Of course, it's not all positives: introducing type annotations and static type checking in our development workflow does come with some friction, specially when we are just starting with it. This friction can come in one of two ways:
1. Writing type annotations as you write code may not come naturally
2. Integrating type hints into our development workflow

### Give me a (type) hint!

Writing type annotations will eventually become second nature: we already think about type constraints as we write our code, now we are taking implicit expectations and making them explicit as the [Zen of Python](https://www.python.org/dev/peps/pep-0020/) urges. However, adding type constraints Python may seem too restrictive: we are giving up the freedom of duck-typing! Rest assured that type annotations are more akin to suggestions or **hints** (as they are [officially](https://www.python.org/dev/peps/pep-0484/) called) that we may choose to ignore if we so desire, so they do not get in the way during runtime and do not represent a significant overhead. Their usage shines during development, when they can save us plenty of time as already described.

For type hinting, I recommend using Python 3.9 or later, or importing `annotations` from `__future__` (available from Python 3.7). Python 3.9 introduced support for the generic syntax used in type hints to all collections in the standard library. This means, for example, importing `typing.List` or `typing.Dict` is no longer necessary, so the following:

```python
import typing

def sum_one_to_list_items(l: typing.List[int]) -> typing.List[int]:
    return [n + 1 for n in l]
```

Becomes a much cleaner and intuitive:

```python
def sum_one_to_list_items(l: list[int]) -> list[int]:
    return [n + 1 for n in l]
```

The `typing` module does contain other useful tools besides generic collections: we can use `typing.Union` to describe a constraint involving one of multiple types:

```python
import typing

def sum_items(l: list[typing.Union[str, int]]) -> typing.Union[str, int]:
    """Take a list of str and concat them, or a list of int and sum them"""
    return sum(l)
```

`typing.Optional` is a special case of `typing.Union` representing a union between a type and `None`. We may also define type aliases, for improved intuition:

```python
import typing

Coordinate = tuple[float, float]

def sum_coordinates(c1: Coordinate, c2: Coordinate) -> Coordinate:
    return (c1[0] + c2[0], c1[1] + c2[1])
```

Finally, use `typing.Any` to specify an unconstrained type. Of course, it should be used sparingly as we are giving up constraints. More details about these objects, as well as others, is available in the `typing` [docs](https://docs.python.org/3/library/typing.html).

### Integrating type hints into our development workflow

As with styling, we would like to abstract the effort of static type checking, which we can do, once again, by integrating `mypy` to our `pre-commit` hooks:

```yaml
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v0.812
    hooks:
      - id: mypy
```

One detail: `mypy` is available in a `pre-commit` mirror instead of the official repo.

Now on every commit we will run `mypy` on changed files, and assert our type constraints are respected as dictated by the type hints we worked in the code!

`mypy` runs out of the box without any special configuration, but you may run into one of several common ["missing imports"](https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports) error, with messages like:

```sh
main.py:1: error: Library stubs not installed for "requests" (or incompatible with Python 3.8)
main.py:2: error: Skipping analyzing 'django': found module but no type hints or library stubs
main.py:3: error: Cannot find implementation or library stub for module named "this_module_does_not_exist"
```

In particular, the second message is the one I have seen the most in my experience. It's telling us that a library we are trying to import does not come with any type hints, which means `mypy` will not attempt to infer its types. The first thing you should do is check whether an upgrade is in order: later versions of a library may have included type hints for `mypy`. If that's not the case, or upgrading is not possible for some other reason, you may consider writing the type hints yourself, but the simplest solution is to ignore the error configuring your `mypy.ini`, for example:

```sh
[mypy-django.*]
ignore_missing_imports = True
```

Ignoring errors is not ideal and should be done sporadically, but when the error originates in a dependency solving it may be out of our control.

## Wrapping up

In this post I have reviewed some of the most common development tools I use for packaging and dependency management (Poetry), static type checking (`mypy`), styling (`black` and `isort`), and PEP8 compliance (`flake8`). Each of this tools can be extensively tweaked to build a workflow that better suits you and your team, and covering each of them to their fullest extent would probably require multiple blog posts. Regardless, I hope to have at least introduced you to the tools themselves, and offered some basic configurations to get you going. To see everything coming together, feel free to checkout the accompanying repo to this post: the [`python-package-template`](https://github.com/tomasfarias/python-package-template), which can be easily used as a base to start off pretty much any project.

Finally, I urge to keep an open eye to catch any new amazing tools that may pop up in the Python ecosystem in the future. A lot has changed in the last decade, and I ultimately believe this change has been for the better as time has been given back to developers to focus on what's important: writing amazing software.

## References

1. PyCon 2015. (2015, April 11). *Raymond Hettinger - Beyond PEP 8 -- Best practices for beautiful intelligible code - PyCon 2015* [Video]. YouTube. https://www.youtube.com/watch?v=wf-BqAjZb8M&t
