---
title: "Sphinx Documentation on GitHub Pages using Poetry"
date: 2021-09-27
author: "Tomás Farías Santana"
authorLink: "https://tomasfarias.dev"
tags: ["python", "workflow", "poetry", "sphinx"]
---

[Sphinx](https://www.sphinx-doc.org/en/master/) is the most widespread documentation tool I've seen used for Python projects. It can output to multiple formats, including HTML and PDF, handle code and cross-references, and plenty of extensions are available in PyPI for more specific use-cases.

But this post is not about the wonders of Sphinx, or the nuances of how to write reStructuredText, as there is already plenty of documentation out there[^1]. Instead I'll be focusing on my efforts over the last couple of weeks to automate a **Sphinx documentation deployment pipeline**, by hosting it in [Github Pages](https://pages.github.com/), for a project that uses [`poetry`](https://python-poetry.org/) as its dependency management tool.

The project that I'll be using as an example is [`airflow-dbt-python`](https://github.com/tomasfarias/airflow-dbt-python), an Airflow operator I've written to work with `dbt` (don't worry, you don't need to know what any of these tools are for to follow this blog post, it's just the project I've worked on documenting). In the next sections I'll be dissecting each part of the documentation pipeline, and you can checkout the repo if you want to see the final product up and running.

## Specifying the dependencies in poetry

Let's start by adding the necessary dependencies to our `pyproject.toml` file (non-documentation specific dependencies have been omitted for clarity):

```toml
[tool.poetry.dependencies]
Sphinx = { version = "4.2.0", optional = true }
sphinx-rtd-theme = { version = "1.0.0", optional = true }
sphinxcontrib-napoleon = { version = "0.7", optional = true }

[tool.poetry.extras]
docs = ["Sphinx", "sphinx-rtd-theme", "sphinxcontrib-napoleon"]
```

Several things are going on here:
* Like any other dependency, we added Sphinx and the extensions we are using to the `[tool.poetry.dependencies]` section of our `pyproject.toml` file.
* For stability, we have pinned the dependency versions used.
* The dependencies have been set as **optional**, as we don't want to include them in release versions of the package by default.
* These optional dependencies have been grouped together in the `[tool.poetry.extras]` section to allow for easy installation.

This way, developers working on the project may install the documentation dependencies by running:

```shell
poetry install airflow-dbt-python --extras docs
```

## Writing our documentation with Sphinx

We will not be saying too much here as there are plenty of resources on how to write good documentation and, in particular, on how to use Sphinx to do it[^resources]. I encourage you to go over the [Sphinx quickstart guide](https://www.sphinx-doc.org/en/master/usage/quickstart.html) if you want to get up and running to continue with this blog post. If you have used `poetry` to install Sphinx, as detailed in the [previous section]({{< ref "#specifying-the-dependencies-in-poetry" >}}), **remember** you'll need to run the Sphinx commands with `poetry`:

```shell
poetry run sphinx-quickstart
```

## Setting up GitHub Actions

In order to automate the deployment of our documentation, we'll be using [GitHub Actions](https://github.com/features/actions). This is not strictly required, and other CI/CD vendors may work just as well or even better, but since my project is hosted in GitHub, I'm taking advantage of those free credits.

Here's the full YAML, which should be dropped in `.github/workflows/docs_pages.yaml`:

```yaml
name: Docs2Pages
on:
  push:
    tags: '*'
  pull_request:
    branches:
      - master

jobs:
  build-docs:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@master
      with:
        fetch-depth: 0
    - uses: actions/setup-python@v2
      with:
        python-version: 3.9
    - uses: abatilo/actions-poetry@v2.1.3
    - name: install
      run: poetry install -E amazon -E docs
    - name: Build documentation
      run: |
        mkdir gh-pages
        touch gh-pages/.nojekyll
        cd docs/
        poetry run sphinx-build -b html . _build
        cp -r _build/* ../gh-pages/
    - name: Deploy documentation
      if: ${{ github.event_name == 'push' }}
      uses: JamesIves/github-pages-deploy-action@4.1.4
      with:
        branch: gh-pages
        folder: gh-pages
```

Let's now go over each relevant section:

```yaml
on:
  push:
    tags: '*'
  pull_request:
    branches:
      - master
```

This is just configuring the action to run only when a tag is pushed, or when a pull request is made against the `master` branch of the repo. We want our documentation to be built and deployed whenever a new tag is _pushed_, but we also want to build the documentation when a pull request is _opened_ to ensure the build succeeds.

```yaml
jobs:
  build-docs:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@master
      with:
        fetch-depth: 0
    - uses: actions/setup-python@v2
      with:
        python-version: 3.9
    - uses: abatilo/actions-poetry@v2.1.3
    - name: install
      run: poetry install -E amazon -E docs
```

The first three steps handle checking out the repo, setting up python and poetry, and installing the package with its dependencies. You can checkout the specific action we use to install `poetry` over [here](https://github.com/marketplace/actions/python-poetry-action). This particular action assumes we have already setup python, which is why we run it in this particular order.

In the last step, notice that we are running the `poetry install` command using the `-E` (same as `--extras`) flag to install our `docs` dependencies. This will install Sphinx and its dependencies as we specified [before]({{< ref "#specifying-the-dependencies-in-poetry" >}}).

```yaml
    - name: Build documentation
      run: |
        mkdir gh-pages
        touch gh-pages/.nojekyll
        cd docs/
        poetry run sphinx-build -b html . _build
        cp -r _build/* ../gh-pages/
```

We finally get to the actual build step. There are several commands running here:
* Our documentation will be built on a directory we have named `gh-pages`, so the first `mkdir` creates it.
* By default, GitHub uses [Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll) to generate a static site. We are already using Sphinx for it, so we tell GitHub not to use Jekyll by including an empty `.nojekyll` file. Omitting this would cause our Sphinx themes to not be properly loaded.
* We move to the `docs/` directory and run our `sphinx-build` command using `poetry`: `poetry run sphinx-build -b html . _build`. Notice that we are **not running** `sphinx-build` directly as we have installed it using `poetry`. This will output our documentation HTML files that we just move to the `gh-pages` directory created in the first step.

```yaml
    - name: Deploy documentation
      if: ${{ github.event_name == 'push' }}
      uses: JamesIves/github-pages-deploy-action@4.1.4
      with:
        branch: gh-pages
        folder: gh-pages
```

The last step in our pipeline deploys the documentation to GitHub Pages. The actual deployment involves committing the contents of the `gh-pages` folder to a branch that we have also named `gh-pages`. You can find the action used for this step [here](https://github.com/marketplace/actions/deploy-to-github-pages). If you checkout the [`gh-pages` branch](https://github.com/tomasfarias/airflow-dbt-python/tree/gh-pages) of the repo you will see it looks nothing like other branches, it **just** contains the documentation we built in the previous step.

One last thing to mention: we have an if-conditional to ensure the deployment step happens only on `push` events. Since our entire action only runs on tag pushes or pull requests, this means deployment will only run when we push tags, as we don't support multiple documentation environments. The pipeline could be extended here to support test and/or development environments to deploy the documentation, but that's beyond the scope of this post.

## Finishing by configuring our GitHub repo

If you have followed all the steps until now, and have pushed a tag, you'll find yourself with a new `gh-pages` branch which contains all the documentation files built by Sphinx. However, nothing has happened yet as we have not told GitHub that we want to use GitHub Pages to host our documentation. This is a very simple task that we can accomplish by going into the _Settings_ of our repo, under the _Pages_ section and creating a _Source_ pointing to our new `gh-pages` branch:

![Setting up GitHub Pages in our repo](/gh-pages-setup.png)

**And that's it!** After a few minutes our documentation should be up-and-running in a URL with the format: `https://<account>.github.io/<repo>/`. GitHub will let us know when the site is available in the same Settings page:

![Our GitHub Pages is ready](/gh-pages-ready.png)

## Final thoughts

The idea for this post came to me as all of the guides and other posts I could find regarding deploying Sphinx documentation to GitHub Pages were not using `poetry` as their package management tool. Since adapting those guides gave me a few headaches, I wanted to help other people smooth out the process with my own guide. I'm hoping at least to have clearly explained the `poetry`-specific parts of the setup and would like to leave you with some ideas on what to do next:

* Consider building and deploying the documentation on pushes to master branch using different paths in the URL, e.g. `https://<account>.github.io/<repo>/master/` and `https://<account>.github.io<repo>/latest/`.
* Try mixing up the theme of the docs. The themes used by the [`flask` documentation](https://flask.palletsprojects.com/en/latest) are a nice alternative: https://github.com/pallets/pallets-sphinx-themes.

[^1]: Like the Sphinx docs themselves: https://www.sphinx-doc.org/en/master/contents.html. Check them out!
[^resources]: Here's a couple of said resources:
    * A step-by-step guide on how to setup Sphinx docs: https://eikonomega.medium.com/getting-started-with-sphinx-autodoc-part-1-2cebbbca5365
    * Motivation to write documentation and some pointers on what to include: https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/
