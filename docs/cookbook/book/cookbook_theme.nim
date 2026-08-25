import nimib, nimibook
import nimibook/themes as nimibookThemes
import std/[json, strutils]

func escapeHtml(text: string): string =
  result = newStringOfCap(text.len)
  for character in text:
    case character
    of '&':
      result.add("&amp;")
    of '<':
      result.add("&lt;")
    of '>':
      result.add("&gt;")
    of '"':
      result.add("&quot;")
    of '\'':
      result.add("&#39;")
    else:
      result.add(character)

func cookbookOutputToHtml(blk: JsonNode, nb: Nb): string =
  let output = blk{"output"}.getStr
  if output.len > 0:
    "<pre class=\"nb-output\"><code class=\"nohighlight nb-output-code\">" &
      escapeHtml(output) & "</code></pre>"
  else:
    ""

func cookbookHeadToHtml(blk: JsonNode, nb: Nb): string =
  let outputStyles = """
<style>
.nb-output {
  box-sizing: border-box;
  padding: 1rem 3rem 1rem 1.2rem;
  overflow-x: auto;
  color: var(--fg);
  /* Results are informational output, so give them a subtle theme accent. */
  background-color: var(--quote-bg);
  background-color: color-mix(in srgb, var(--links) 10%, var(--bg));
  border: 1px solid var(--quote-border);
  border-color: color-mix(in srgb, var(--links) 28%, var(--bg));
  border-left: 0.4rem solid var(--links);
  border-radius: 0.4rem;
}

.nb-output > .nb-output-code {
  color: inherit;
}
</style>
"""
  nimibookThemes.nimibookHeadToHtml(blk, nb).replace(
    "</head>", outputStyles & "</head>")

func cookbookBodyPostToHtml(blk: JsonNode, nb: Nb): string =
  """<script type="text/javascript">
window.playground_copyable = true;
</script>
""" & nimibookThemes.nimibookBodyPostToHtml(blk, nb)

proc useCookbook*(nb: var Nb) =
  useNimibook(nb)
  nb.backend.partials["nbCodeOutput"] = cookbookOutputToHtml
  nb.backend.partials["nimibook_head"] = cookbookHeadToHtml
  nb.backend.partials["nimibook_body_post"] = cookbookBodyPostToHtml
