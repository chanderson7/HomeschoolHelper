# Design artifacts

- `source/homeschool-screen-prototypes.html`: editable thirteen-screen HTML fragment, including interaction logic and feature-scope notes.
- `prototype/index.html`: standalone browser export, with its rendering shell bundled into the file.

Open `prototype/index.html` locally. No server, account, npm install, or production service is required. The export embeds the prototype in a sandboxed frame. Optional icon assets may require connectivity; the app navigation retains text labels. Host-specific color-tweak controls are optional and may not appear outside the original conversation.

## Regenerate after editing

```sh
python3 scripts/update-prototype-export.py
```

The update script retains the checked-in export shell and replaces the marked prototype fragment. Keep `<!-- HSH_SOURCE_START -->` and `<!-- HSH_SOURCE_END -->` in the source. This avoids depending on an absolute path to a local design tool installation.

## Behavior and limitations

See [screen specifications](../docs/screens.md). These are interaction mockups, not SwiftUI implementation. Do not use the demo arithmetic, calendar fixtures, or confirmation toggles as production business logic.

The initial standalone rendering shell was generated with the available visualization export utility. The editable product-specific markup is isolated by the source markers. Future work can replace the rendering shell without changing the product specification.
