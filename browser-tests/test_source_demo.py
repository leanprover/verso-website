"""Tests of the highlighted Verso source in the front page's demo."""

from pathlib import Path

import pytest
from playwright.sync_api import Page, expect

FRONT_PAGE = Path(__file__).parent.parent / "Site" / "FrontPage.lean"

TRANSPARENT = "rgba(0, 0, 0, 0)"


def demo_markup() -> str:
    """Returns the body of the `versoSource` code block in the front page's source."""
    lines = FRONT_PAGE.read_text().splitlines(keepends=True)
    start = next(i for i, l in enumerate(lines) if l.startswith("````versoSource"))
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == "````")
    return "".join(lines[start + 1 : end])


def open_front_page(server: str, page: Page) -> None:
    page.goto(f"{server}/")
    page.wait_for_load_state("load")


def hover_tooltip(page: Page, target):
    """Hovers `target` and returns the visible tooltip."""
    target.hover()
    tooltip = page.locator(".tippy-box .hover-info")
    expect(tooltip).to_be_visible()
    return tooltip


class TestSourceText:
    def test_text_matches_markup(self, server: str, page: Page):
        """
        The demo shows exactly the Verso markup from the front page's source.

        Final newlines are not visible in the rendered demo, so the comparison ignores them.
        """
        open_front_page(server, page)
        text = page.locator(".verso-source").text_content()
        assert text.rstrip("\n") == demo_markup().rstrip("\n")


class TestHighlighting:
    @pytest.mark.parametrize(
        "selector",
        [
            ".verso-emph",
            ".verso-math",
            ".verso-arg",
            ".verso-codeblock-wrap .verso-codeblock-fence",
            ".verso-codeblock-wrap .verso-codeblock-content",
            ".verso-directive-wrap .verso-directive-delim",
            ".verso-role-wrap .verso-role-delim",
            ".verso-link-wrap .verso-link-delim",
            ".verso-link-wrap .verso-link",
        ],
    )
    def test_element_is_highlighted(self, server: str, page: Page, selector: str):
        """Each kind of markup in the demo has its highlighting class."""
        open_front_page(server, page)
        expect(page.locator(f".verso-source {selector}")).not_to_have_count(0)

    def test_extension_names(self, server: str, page: Page):
        """The names of code blocks, directives, and roles are highlighted."""
        open_front_page(server, page)
        names = page.locator(".verso-source .verso-ext-name").all_text_contents()
        assert {"lean", "theorem", "tactic"} <= set(names)

    def test_styled_spans_exclude_trailing_whitespace(self, server: str, page: Page):
        """
        Highlighted elements end before the whitespace that follows them.

        Code block contents are lines that each end in a newline, so they are checked separately.
        """
        open_front_page(server, page)
        texts = page.locator(
            ".verso-source [data-tooltip]:not(.verso-codeblock-content)"
        ).all_text_contents()
        assert texts
        for text in texts:
            assert text == text.rstrip(" \n"), f"Trailing whitespace in {text!r}"
        contents = page.locator(
            ".verso-source .verso-codeblock-content"
        ).all_text_contents()
        assert contents
        for text in contents:
            assert text.endswith("\n") and not text.endswith("\n\n"), repr(text)

    @pytest.mark.parametrize(
        ("wrapper", "delimiter"),
        [
            (".verso-directive-wrap", ".verso-directive-delim"),
            (".verso-codeblock-wrap", ".verso-codeblock-fence"),
            (".verso-role-wrap", ".verso-role-delim"),
            (".verso-link-wrap", ".verso-link-delim"),
        ],
    )
    def test_delimiter_hover_highlights_element(
        self, server: str, page: Page, wrapper: str, delimiter: str
    ):
        """Hovering a delimiter highlights the whole element that it delimits."""
        open_front_page(server, page)
        wrap = page.locator(f".verso-source {wrapper}").first
        expect(wrap).to_have_css("background-color", TRANSPARENT)
        wrap.locator(delimiter).first.hover()
        expect(wrap).not_to_have_css("background-color", TRANSPARENT)


class TestTooltips:
    def test_tippy_instances_on_load(self, server: str, page: Page):
        """Every element with a tooltip has a Tippy instance after the page loads."""
        open_front_page(server, page)
        counts = page.evaluate(
            """() => {
            const els = document.querySelectorAll('.verso-source [data-tooltip]');
            return [els.length, Array.from(els).filter(el => el._tippy).length];
        }"""
        )
        total, initialized = counts
        assert total > 0, "Expected elements with tooltips"
        assert initialized == total, (
            f"Only {initialized} of {total} have Tippy instances"
        )

    def test_default_tooltip(self, server: str, page: Page):
        """Markup without an elaborator hover shows the tooltip for its kind."""
        open_front_page(server, page)
        tooltip = hover_tooltip(page, page.locator(".verso-source .verso-emph").first)
        expect(tooltip).to_have_text("Emphasis, rendered as italics")

    @pytest.mark.parametrize(
        ("name", "heading"),
        [
            ("theorem", "Directive theorem"),
            ("lean", "Code block lean"),
            ("tactic", "Role Site.tactic"),
        ],
    )
    def test_elaborator_hover(self, server: str, page: Page, name: str, heading: str):
        """Extension names show the elaborator's hover, with its Markdown rendered."""
        open_front_page(server, page)
        target = page.locator(".verso-source .verso-ext-name", has_text=name).first
        tooltip = hover_tooltip(page, target)
        expect(tooltip.locator("p").first).to_have_text(heading)
        expect(tooltip.locator("code").first).to_be_visible()
        assert "`" not in tooltip.text_content(), "Tooltip shows unrendered Markdown"

    def test_argument_hover(self, server: str, page: Page):
        """Arguments show the elaborator's description of the parameter."""
        open_front_page(server, page)
        tooltip = hover_tooltip(page, page.locator(".verso-source .verso-arg").first)
        expect(tooltip).to_contain_text("the theorem name")
