import globals from "globals";
import shared from "./eslint.shared.mjs";

// The `ignores` and `files` entries describe this repository, and the shared presets and rules
// come last. The generated site and the vendored GLightbox files are left out.
export default [
    {
        ignores: [
            "node_modules/",
            ".lake/",
            ".verso/",
            "_site/",
            "browser-tests/.venv/",
            "static_files/glightbox/",
        ],
    },
    {
        files: ["**/*.js"],
        languageOptions: {
            ecmaVersion: 2024,
            sourceType: "script",
            globals: { ...globals.browser },
        },
    },
    ...shared,
];
