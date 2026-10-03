# done.rs

## fn done

Every check runs before the first rename, so a missing stub, a stub that does
not parse, or an .eye that is not a plain file leaves every .eye as it was.
A rename over a symlinked .eye replaces the link, never what it points at.
