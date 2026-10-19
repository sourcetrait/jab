# wire.rs

The request is JSON, nushell's `to json`; the answer JSON for its `from
json`. Exact values go out as reduced `p/q` text beside a double for reading,
and the centers as decimal text, since an i128 has no JSON number.

## const BINDING_SHOWN

## struct Request

## struct DriftWire

## struct CaseWire

`sdl pair` sends three cases a reading: the binding's pairing and the stream
shifted by one upload each way, the ambiguity check.

## struct PairWire

## struct Response

## struct Answer

`status` is `feasible`, `infeasible`, or `unresolved`; `reason` names an
unresolved case's step.

## struct CenterWire

## struct BestWire

## struct RegionWire

## struct SpanWire

## struct BindingWire

## struct PlaceWire

## fn respond

## fn answer_case
