# gauge/stream

## KIND_ROUNDS

a debug build's witness of a frame's rounds under the J's cancel, outside
the clock kinds and their schema (render.inc's REPORT_ROUNDS)

## KIND_RECEIPT

from schema 7 each frame's receipt, its flips as the kernel answered
them, and once before the first state the load's two presents with the
run's capture nonce (render.inc's REPORT_RECEIPT and REPORT_LOAD); from
schema 8 the receipt's final attempt's call bounds and the load's bounds
record, KIND_BOUNDS, right after the load record (REPORT_BOUNDS,
PairBracket)

## CLOCK_SCHEMA

the program's clock records' schema, 8, the fixtures and the walk held to
it

## PHASES

the critical path's phases at each schema and the drawing's parts, each
exclusive; below schema 5 tiles_us lies within planes_us and walls_us
and is never added to them, and at 5 it is the pool's boundary, a part
of its own; from schema 3 the planes, walls, and sprites are
preparation alone and the raster a part of its own

## PHASE_IMAGES

the schema 2 images whose parts are known, by the SHA-256 of the .jab
image a run's identity records (build.image_sha256): f59f7a7's three
sets, each built twice from a `git archive` export of that commit in
two directories, the two images alike, with the SDK, the toolchain, and
the flags they were built with

## u32-at

A record's 32-bit word at a byte offset, or its 64-bit one.

## main

A capture read in the order its records came, up to and including the
first end marker: the state records, the n-th frame n's, with the
placements the console answered before each, whether an R was answered
before the first state and whether one came later, the same for a C and
a W, the game's events with the frame each fell in, the frame, draw,
presentation, and packet records, kinds 7, 8, 10, and 12, each field
microseconds or a count, a packet record's workers, grain, and round
times from its schema 4 and null below it, the tile, storage, and
configuration records, kinds 13, 15, and 14, a configuration's frame
the first it governs and its arrival, the state records and the frame
records that came before it, the harts records, kind 18, each a frame's
masks by hart, a debug build's witnesses under the J's cancel, kind 19,
each a frame's rounds and cancelled rounds, as `rounds`, and the marker,
kind 9, with its frame and schema, null when none came. From schema 7 the
receipt records, kind 20, a frame's final attempt's decision stamp and
eligibility tick in ticks, its present ordinal, and the ordinal its first
attempt found, and the load's records, kind 21, each the title's and the
cleared screen's acceptance in ticks and flip end in microseconds, their
ordinals, and the run's capture nonce, with the state records before it;
from schema 8 each receipt's `call_start` and `call_end`, its final
attempt's call in ticks, and the load's bounds records, kind 22, each the
title's and the cleared screen's call start and end in ticks and the
origin, with the state and load records before it; an I's answer before
the first state sets `nonce_set`, a later one
`late_nonce`. A state carries its pose, the eye's x, y, and z and the
yaw, pitch, and roll in degrees. What follows the marker is outside the
measurement: its state records are counted as `past` and nothing else in
it is read.

## schema-of

The schema a capture's clock records sit at: its end marker's, else its
first clock record's; null for a capture with none.

## phases-of

The critical path's phases at a schema, schema 1's for one this reader
does not take.

## parts-of

The drawing's parts at a schema, schema 1's for one this reader does
not take.

## parts-meaning

What a run's moved parts measure, the phases' class, the remainder's,
and the tiles', with the evidence: schema 1 its phases with rendering
and its remainder holding none, the rendering inside the phases;
schemas 3 to 5 their phases preparation alone and their remainder
holding no rendering, the raster a part of its own, by the workers or
not; schema 2 a listed image's classes
(PHASE_IMAGES) by the SHA-256 its identity records, whatever its
identity's commit or dirty flag says, since the commit is the
checkout's at launch and never the image's; any other run unknown. The
tiles were built inside the plane and wall phases at every schema below
5, whatever the image, and at the pool's boundary from 5, schemas 6
and 7 holding the parts as 5 does. A measurement written before schema 2 was
read is at schema 1, as compare hands it here.

## phase-images

The schema 2 images whose parts are known (PHASE_IMAGES), by SHA-256.
