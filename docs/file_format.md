# File format

A valid file to generate a notification contains:

* 1 to 3 lines of plain text (any text lines beyond the third will be ignored).

* Optionally, [**directives**](directives_summary.md), which allow you to add images, buttons and so on. Each directive occupies its own line, starting with a pipe character (`|`), in one of the formats:

  | Syntax                              | Meaning                               |
  |-------------------------------------|---------------------------------------|
  | `\|DirectiveName: DirectiveValue`   | A directive with a string value.  Whitespace around the separating colon is ignored |
  | `\|DirectiveName`                   | A boolean directive with value `true`  |
  | `\|!DirectiveName`                  | A boolean directive with value `false` (only useful if the directive has been configured with a default value of `true`) |

* Optionally, **comments**, each on its own line and starting with `#`.  These will be ignored (and not rendered as text in the notification).

Directives and comments can be freely placed anywhere in the file: before the body text, after it, or even interspersed with body text lines.

To see what you can do with directives, check out the [summary](directives_summary.md) and [detailed guide with examples](directives_detail.md).

By default, LightlyToasted will only process files with the extension `.toa`, but this is fully [configurable](config.md).

## Escaping

If a text line needs to begin with a literal `|` or `#`, it can be escaped with a preceding `|`.  So `||` at the beginning of the line produces a literal `|`, and `|#` produces a literal `#`.

Anywhere other than the start of a line, there is no need for the escape character: single `|` and `#` characters midline are interpreted as literal text.

In a directive line, the first colon (`:`) is interpreted as the separator between name and value, but subsequent colons are simply treated as part of the value, with no need for escaping.  

For example, a URL can be supplied as directive value like this:

  `|ImageSource: https://example.com/example.jpg`  


