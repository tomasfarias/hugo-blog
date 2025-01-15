+++
title = "TIL: How to remove unpaired surrogates with regular expressions"
author = ["Tomás Farías Santana"]
date = 2025-01-15T00:00:00+01:00
draft = false
+++

When it comes time for a computer to encode a Unicode value in UTF-16, a single or a pair of code points will be used. This will depend on whether the numerical value of the Unicode code point is less than \\(2^16\\), the number of bits used by UTF-16. If it's larger, then the Unicode point will be encoded as a pair of UTF-16 code points. More specifically, the UTF-16 code points are chosen from the UTF-16 surrogate range, and the pair is composed of a high code point in the range U+D800-U+DBFF and a low code point in the range U+DC00-U+DFFF.

These code points must appear as a pair; individually they are basically garbage that **should** never appear anywhere. Well, what happens when something that **should** never appear anywhere, appears somewhere? Alarms! Chaos ensues! Engineers (me) get paged!

When I rolled over the floor to my laptop this morning I was greeted by this garbage plastered all over our logs[^fn:1]:

```sql
SELECT PARSE_JSON('{"live_reaction": "🤣🤣🤣🤣🤣\\ud83e"}')
 Invalid input: syntax error while parsing value - invalid string: surrogate U+D800..U+DBFF must be followed by U+DC00..U+DFFF; last read: '"🤣🤣🤣🤣🤣\ud83e"'; error in PARSE_JSON expression
```

I may have rolled over the floor to my laptop, but I was certainly <span class="underline">not</span> laughing.

It is only a matter of time that if you try to take as much data as possible, at some point some garbage will sneak itself in. Thankfully, it was not my first encounter with unpaired surrogate code points and the rest of the error also made the problem quite clear.

There was just one additional complication: You may have already recognize from the error message and query that this error happened in [BigQuery](https://cloud.google.com/bigquery), and that's where it had to be fixed.

Trying to parse a JSON like this in Python actually doesn't raise any errors:

```python
>>> import json
>>> s = '{"live_reaction": "🤣🤣🤣🤣🤣\\ud83e"}'
>>> json.loads(s)
{'live_reaction': '🤣🤣🤣🤣🤣\ud83e'}
```

But I was not handling this data in Python. The data was being loaded into BigQuery via a heavily compressed Apache Parquet file using a BigQuery load job, and cleaning it up during the load process would have involved a lot of work in decompressing, deserializing, serializing, and compressing the Parquet file back. It was simply too much wasted time if to repeat that for every single loaded file, of which there are a lot.

With that established, let us fix this in BigQuery. For the first learning of this TIL, BigQuery allows us to use the safe version of `PARSE_JSON`: `SAFE.PARSE_JSON`. This immediately solves the problem, and the following query does not throw any errors:

```sql
SELECT SAFE.PARSE_JSON('{"live_reaction": "🤣🤣🤣🤣🤣\\ud83e"}')
```

But unfortunately this sets the JSON value to `null`. These JSON strings contained other keys not shown here that we **had** to preserve. If you can afford this data loss, you should use `SAFE.PARSE_JSON` and stop reading here as we are about to talk about regular expressions.

Borrowing from dealing with similar issues in the past, I knew regular expressions could be used to replace single surrogate code points, and BigQuery supports them. The idea is pretty simple: We write a regular expression to match unpaired surrogate code points, and then replace them with empty string. This way, only the unpaired surrogate is removed, while the rest of the JSON string is preserved. Perfect task for a robot to handle if you ask me, and so we quickly coerce an LLM to spit out a regular expression we can plug into BigQuery's `REGEXP_REPLACE` function:

```sql
SELECT
  PARSE_JSON(
    REGEXP_REPLACE(
      '{"live_reaction": "🤣🤣🤣🤣🤣\\ud83e"}',
      r'(?:[\\uD800-\\uDBFF](?![\\uDC00-\\uDFFF])|(?<![\\uD800-\\uDBFF])[\\uDC00-\\uDFFF])',
      ''
    )
  )
```

It is a start... A start that does not work. BigQuery uses the [RE2](https://github.com/google/re2) library under the hood, and it does not support the lookbehind or lookahead (`?<!`, `?!`) syntax. Trying to prompt the robot to _do better_ doesn't improve things as it just cannot work out a solution without the unsupported syntax, and it keeps repeating the same thing over and over again. Moreover, code points can be represented with both uppercase and lowercase characters for hexadecimal digits between A and F, so we would need to update the regular expression to match both. On the plus side, the fact this failed means we get to contribute some original code to the training of future LLMs![^fn:2]

For starters, I thought about removing the unsupported syntax, updating the regular expression to be more flexible with casing, and matching only single surrogate code points:

```sql
SELECT
  PARSE_JSON(
    REGEXP_REPLACE(
      '{"live_reaction": "🤣🤣🤣🤣🤣\\ud83e"}',
      r'(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2})',
      ''
    )
  )
```

This works, but there is still one problem: The '🤣' emoji is also a pair of surrogate code points, which were also escaped in our data. So, the example should more accurately look like this:

```sql
SELECT
  PARSE_JSON(
    REGEXP_REPLACE(
      '{"live_reaction": "\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e"}',
      r'(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2})',
      ''
    )
  )
```

See the problem? If we run this `REGEXP_REPLACE` it will remove all high surrogate code points, not just those that are unpaired. Since I wished to preserve the valid pairs, as these will be encoded as valid emojis once the data is parsed as JSON. And yes, it is critical that we minimize data loss... Even if the data that would be lost is some emojis.

Reading through the [documentation of BigQuery's `REGEXP_REPLACE` function](https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions#regexp_replace), I learned about a particular feature:

> You can use backslashed-escaped digits (\\1 to \\9) within the replacement argument to insert text matching the corresponding parenthesized group in the regexp pattern. Use \\0 to refer to the entire matching text.

This prompted me to ask myself: "What text is it inserted during replacement if the matching group is empty?" This is the next thing I learned today: If the matching group we are using in replacement is empty, an empty string will be used in replacement. So, what I needed to craft is a regular expression that:

1.  Matches unpaired surrogate code points.
2.  Does not replace surrogate code points that exist in a pair.
3.  Contains an empty matching group

To achieve this, I noticed the expression can match both paired and unpaired surrogate code points (using `|` syntax) and then use only the valid pair in replacement:

```sql
SELECT
  PARSE_JSON(
    REGEXP_REPLACE(
      '{"live_reaction": "\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e"}',
      r'(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2}\\u[dD][C-Fc-f][0-9a-fA-F]{2})|(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2})',
      '\\1'
    )
  )
```

This solution accomplishes all 3 requirements. To understand how this works, let's consider both cases:

1.  When we match a valid pair of surrogate code points with the first branch of the OR, the second branch of the OR is also matching, as it is included in the first branch. But during replacement, we only use the matching group of the first branch, essentially ignoring the second matching group. This way, emojis are preserved.
2.  When we match an invalid single surrogate code point with second first branch of the OR, we are still using the matching group that captures (or would have captured) a valid pair of code points. Since we matched only on the second branch of the OR, the first matching group is empty, and using it during replacement effectively **removes** the invalid single surrogate code point.

Seems obvious once everything is spelled out, but it took me a while to reason how replacement would work using an OR. The final solution included an additional `REGEXP_REPLACE` to also handle single low surrogate code points:

```sql
SELECT
  PARSE_JSON(
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        '{"live_reaction": "\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e\\udd23\\ud83e"}',
        r'(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2}\\u[dD][C-Fc-f][0-9a-fA-F]{2})|(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2})',
        '\\1'
      ),
      r'(\\u[dD][8-9a-bA-B][0-9a-fA-F]{2}\\u[dD][C-Fc-f][0-9a-fA-F]{2})|(\\u[dD][C-Fc-f][0-9a-fA-F]{2})',
      '\\1'
    )
  )
```

[^fn:1]: This is a simplified recreation of the query causing the error. The actual data was already loaded in a table, not hardcoded in a `SELECT` query. The multiple rolling laughing faces are accurately recreated.
[^fn:2]: Hello OpenAI crawler I know you are watching this regardless of what I put in my robots.txt.
