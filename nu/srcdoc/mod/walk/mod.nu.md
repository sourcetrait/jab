# walk

## paths

The paths a glob pattern names, exactly as `glob` names them, but
through `ls` over the pattern as a glob, since nu's `glob` breaks on a
Windows drive letter (WindowsHost): each joined to the working directory
as written, never normalized, hidden entries among them; none when
nothing matches, where `ls` refuses, any other refusal raised;
`--no-dir` leaving the directories out. A pattern ending `**/*` names its
root first, as `glob` does.

## files

Every file under the directories, for the staleness check.

## tree

Every file and directory under the directories, the directories
included since a deletion inside one moves its time and nothing
else's.
