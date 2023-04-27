# hugo-blog

This is my personal blog, powered by [hugo](https://www.gohugo.io/) and served by [caddy](https://caddyserver.com/). I use a customized theme based on [LoveIt](https://github.com/dillonzq/LoveIt). Visit my blog at [tomasfarias.dev](https://tomasfarias.dev)!

# Why hugo?

I was looking into a static file site generator that could work with Markdown files and the two best options I could find where [zola](https://github.com/getzola/zola) and [hugo](https://github.com/gohugoio/hugo). Due to my familiarity with [Tera](https://github.com/Keats/tera) templates, and my urge to try out a new Rust tool, I went with the former. After giving it a shot for a couple of weeks, it was obvious that `zola` is at a much earlier stage compared to `hugo`, specially when it comes to theme variety. Since I'm not a web-dev person, and really not looking to do more than a few minor changes here and there, I eventually switched to `hugo`.

# How to run

There's multiple ways to run the blog. If you wish to run a development server with `hugo` you can simply do:

``` sh
hugo server --disableFastRender
```

Running with the included Dockerfile is also an option:

``` sh
docker build -t tomasfarias/hugo-blog:latest .
docker run --net=host -d tomasfarias/hugo-blog:latest
```

The blog should be available at `localhost:8080` by default.

# License

The code of this project are licensed under the ![MIT license](LICENSE). The content of the blog posts is covered under the [CC BY-NC 4.0 LICENSE](https://creativecommons.org/licenses/by-nc/4.0/).
This blog relies on the following MIT-compatible licensed projects:
* The aforementioned [hugo](https://github.com/gohugoio/hugo). See [LICENSE](https://raw.githubusercontent.com/gohugoio/hugo/master/LICENSE).
* The [m10c](https://github.com/vaga/hugo-theme-m10c) theme. See [LICENSE](https://raw.githubusercontent.com/vaga/hugo-theme-m10c/master/LICENSE.md).
* The [Nord](https://github.com/arcticicestudio/nord) color palette. See [LICENSE](https://raw.githubusercontent.com/arcticicestudio/nord/develop/LICENSE).
* The [Gruvbox](https://github.com/morhetz/gruvbox) color palette.

Exceptions may apply to static files, images, and other content. Said exceptions will be documented here.
