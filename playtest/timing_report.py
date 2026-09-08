"""Read-only batch timing: python3 playtest/timing_report.py <batch.json>.

Between-command time includes scheduling, image/tool handling and inference, not just model compute.
Observed intervals exclude boot and final shutdown; neither span nor union is total batch elapsed time.
Warnings describe evidence quality, not gameplay validity. No diagnostic output belongs in actor prompts.
"""
import argparse
import json
import math
from pathlib import Path

PHASES = ('think_ms', 'pickup_ms', 'play_ms', 'capture_ms')


def read_json(path, warnings):
    try:
        value = json.loads(path.read_text())
        if not isinstance(value, dict):
            raise ValueError('not an object')
        return value
    except (OSError, ValueError) as exc:
        warnings.append(f'{path}: unreadable: {exc}')
        return {}


def seat_report(seat, expected_build):
    warnings, intervals, seen = [], [], set()
    totals = dict.fromkeys(PHASES, 0)
    summed = 0
    manifest = read_json(seat/'batch.json', warnings)
    if manifest.get('build') != expected_build:
        warnings.append(f'{seat}: build mismatch')
    if not read_json(seat/'response.json', warnings).get('quit'):
        warnings.append(f'{seat}: incomplete run')
    try:
        lines = (seat/'timing.jsonl').read_text().splitlines()
    except OSError:
        lines = []
    for line in lines:
        try:
            row = json.loads(line)
            number = row['id']
            values = [row[k] for k in (*PHASES, 'wall_ms')]
            if type(number) is not int or number < 1 or any(type(v) is not int or v < 0 for v in values):
                raise ValueError('invalid id or duration')
            if sum(values[:-1]) != values[-1]:
                raise ValueError('phase sum differs from wall_ms')
        except (ValueError, KeyError, TypeError):
            warnings.append(f'{seat}: malformed timing row')
            continue
        if number in seen:
            warnings.append(f'{seat}: duplicate burst {number}')
            continue
        seen.add(number)
        summed += row['wall_ms']
        for key in PHASES:
            totals[key] += row[key]
        path = seat/f'input_{number:04d}.json'
        # The seat handles quit before writing input_N; command.py still records its timing.
        if not path.exists() and (seat/'command.json').exists():
            final = read_json(seat/'command.json',warnings)
            if final.get('id') == number and final.get('quit') is True:
                path = seat/'command.json'
        sent = read_json(path, warnings).get('sent_at')
        if type(sent) in (int,float) and math.isfinite(sent) and sent == int(sent):
            start = int(sent) - row['think_ms']
            intervals.append((start, start + row['wall_ms']))
        else:
            warnings.append(f'{seat}: missing/invalid timestamp for burst {number}')
    if not seen:
        warnings.append(f'{seat}: no usable timing rows')
    return {'session':str(seat), 'build':manifest.get('build'),
            'mission_sha256':manifest.get('mission_sha256'), 'bursts':len(seen),
            'summed_seat_ms':summed, 'totals_ms':totals, 'warnings':warnings}, intervals


def union_ms(intervals):
    total, end = 0, None
    for left, right in sorted(intervals):
        total += right - max(left, end if end is not None else left) if end is None or right > end else 0
        end = max(right, end if end is not None else right)
    return total


def report(batch_path):
    manifest = json.loads(Path(batch_path).read_text())
    seats, intervals, warnings, paths = [], [], [], set()
    for entry in manifest['seats']:
        path = Path(entry['session']).resolve()
        if path in paths:
            warnings.append(f'{path}: duplicate seat')
            continue
        paths.add(path)
        result, spans = seat_report(path, manifest['head'])
        seats.append(result)
        intervals.extend(spans)
        warnings.extend(result['warnings'])
    complete = bool(intervals) and len(intervals) == sum(s['bursts'] for s in seats)
    return {'head':manifest['head'], 'seats':seats, 'warnings':warnings,
            'summed_seat_ms':sum(s['summed_seat_ms'] for s in seats),
            'totals_ms':{k:sum(s['totals_ms'][k] for s in seats) for k in PHASES},
            'observed_span_ms':max(r for _, r in intervals)-min(l for l, _ in intervals) if complete else None,
            'observed_union_ms':union_ms(intervals) if complete else None,
            'scope':'observed command intervals only; excludes boot/shutdown; not total batch duration'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batch', type=Path)
    args = parser.parse_args()
    print(json.dumps(report(args.batch), indent=2))
