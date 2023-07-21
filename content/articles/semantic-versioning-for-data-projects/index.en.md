---
title: "Semantic versioning for data projects"
date: 2021-11-22
author: "Tomás Farías Santana"
authorLink: "https://tomasfarias.dev"
draft: true
tags: ["versioning", "data-engineering", "semantic-versioning", "data-warehouse"]
---

[Semantic versioning](https://semver.org/) is a versioning scheme that most api consumers, open-source contributors, package mantainers, and developers in general are very familiar with. It consists of a set of rules to determine how to version a software package, and the summary is[^1]:

Given a version number MAJOR.MINOR.PATCH, increment the:
- MAJOR version when you make incompatible API changes,
- MINOR version when you add functionality in a backwards compatible manner, and
- PATCH version when you make backwards compatible bug fixes.

The rules were written with packages that expose some sort of API for other developers to consume. Hence, applying these rules to, for example, a REST API turns out to be very straight-forward, at least for the most part. The benefits of semantic versioning involve clearer communication between project maintainers and users: maintainers can clearly announce the presence of breaking changes, and users can plan out version upgrades safely.

However, when working in a data engineering project, the concept of an API becomes more blurred as we are enabling users and applications to interact purely with data, not with other applications. Moreover, maintaining old versions of data schemas involves a higher cost than simply hosting old versions of a package.

[^1]: Summary and full specification available here: https://semver.org/.
