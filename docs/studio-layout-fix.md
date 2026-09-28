# Studio composition and viewport fix

The Studio Runtime had retained the Core's 128×64 default viewport. Its 704×336 framebuffer was valid, but nearly all Studio nodes were clipped to that small viewport. The Preview blit was drawn afterward and remained visible, which made the application look like an enlarged Preview with empty Inspector and footer areas.

Studio now sets its own viewport to 704×336 and keeps the Preview Runtime at 128×64. The Preview renders into a separate 1024-byte Mono1 framebuffer. Studio then copies its completed pixels into a centered preview area at an integer 1×, 2×, or 4× scale. AppKit receives only the completed Studio framebuffer and draws each Studio pixel as a 2×2 rectangle; it never lays out or scales Preview nodes.

The header contains Run, Pause, Restart and Step +16ms. The left panel holds the Preview, the right Panel contains Target, size, FPS, frame, node/animation counts, focus, input, runtime/buffer RAM, remaining RAM, scale and selected node. The footer contains FPS, Scale, Overlay, Target and Demo controls.

`zig build` installs `mimoc-studio-snapshot`. Run `./zig-out/bin/mimoc-studio-snapshot > studio.pbm` to obtain a headless P4 PBM of the complete 704×336 Studio surface. The Studio test compares its PBM bytes to a golden hash, checks every Studio node is inside the surface and every Inspector field is inside its panel, verifies the 1×/2×/4× preview positions and pixels, and checks Preview full-frame/eight-page byte equivalence. The PBM was also converted to PNG and visually inspected after this change.
