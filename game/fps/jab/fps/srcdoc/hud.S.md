# hud.S

The crosshair is a semi-translucent white dot: each pixel under it halved and
added to half of white, srli 1, and 0x7f7f7f, add 0x808080, so the aim's mark
reads over anything; the player's G-1 is unseen. The pixel loop is aligned to
64 bytes inside the function.
