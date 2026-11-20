from playwright.sync_api import Page, expect


class TestKaTeX:
    def test_math_is_rendered(self, server: str, page: Page):
        """Every math element in the demo's output is typeset by KaTeX."""
        page.goto(f"{server}/")
        page.wait_for_load_state("load")

        math = page.locator(".verso-output-panel code.math")
        expect(math).not_to_have_count(0)
        expect(page.locator(".verso-output-panel code.math .katex")).to_have_count(
            math.count()
        )
        expect(page.locator(".verso-output-panel .katex-html .base")).not_to_have_count(
            0
        )
