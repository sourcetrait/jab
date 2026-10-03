# srcdoc.rs

## fn checked_src_dir

The source directory must be a `src`: its srcdoc is always the sibling, so
no srcdoc lands among the sources and every .eye's path follows from its
source's. The path is canonicalised first, so `.` inside a src works and a
missing directory fails there.

## fn srcdoc_dir

## fn eye_path

## fn stub_path

## fn ignore_path

## fn appended

## fn is_source

## fn is_linker

## struct SourceDir

## fn within

## fn source_dirs

## fn walk
