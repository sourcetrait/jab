# Jab
[![License Badge]][License]

Jab is a specialized RISC-V (RVA23) system.

It defines a set of conservative [system specifications](./doc/SPEC.md) that
roughly follow current trends in affordable single-board computers.

Everything meant to be distributed and ran in Jab is in 100% assembly.

The Jab Computer (system) is built on-top of QEMU and uses it regardless of
whether the host natively supports RISC-V architecture or not. This allows for
simplicity in hardware support and isolation from the host.

Development tools are written in Rust. Build tools are written in Nushell.

Agent-maintained documentation can be found in [UNDERSTOOD.md](./doc/understood/UNDERSTOOD.md).

Repository
--------------------------------------------------------------------------------

Found a bug?  
Let us know! Upvote an existing issue or create one if not found.

Have questions, concerns, ideas, or requests?  
Upvote an existing discussion or create one if not found.

### Contributors
Contributors, please review [SOURCETRAIT.md](https://github.com/sourcetrait/sourcetrait_common/blob/dev/SOURCETRAIT.md).  

#### Copyright Assignment Agreement (CAA)
By committing to this repository you
[agree to assign](https://github.com/sourcetrait/sourcetrait_common/blob/dev/docs/legal/Copyright_Assignment_Agreement.md)
to [Asmov LLC](https://asmov.software)
all right, title, and interest worldwide in all copyright covering your
contribution.


License (AGPL3)
--------------------------------------------------------------------------------
Jab  
Developed by [SourceTrait](https://sourcetrait.com), a division of **Asmov LLC**  
Copyright (C) 2026 [Asmov LLC](https://asmov.software)  

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a [copy](./LICENSE-AGPL-3.txt) of the
GNU Affero General Public License along with this program.
If not, see https://www.gnu.org/licenses/.


[License]: #License-AGPL3
[License Badge]: https://img.shields.io/badge/license-AGPL3-blue.svg
