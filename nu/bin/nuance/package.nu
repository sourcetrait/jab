#!/usr/bin/env nu
# The package module's path, bound at parse time
const PACKAGE = path self ../../mod/package
use $PACKAGE

# A package made from its spec, staged in `stage`, written as one tar
def "main make" [spec: path, stage: path, out: path] {
    package make $spec $stage $out
}

# A package's files held to its manifest by SHA-256 and role
def "main check" [dir: path] {
    package verify $dir
}

# A packaged bench's preflight, its first step, refusing before any run
def "main preflight" [dir: path, --spec: string, --image: string, --kernel: string, --tree: string, --serial: string, --bench: string, --out: string, --label: string = ""] {
    package preflight $dir --spec $spec --image $image --kernel $kernel --tree $tree --serial $serial --bench $bench --out $out --label $label
}

# The bin's help, its verbs listed, when called with no verb
def main [] { help main }
