"""Dry sample playback with the retail driver's relative two-stage pitch ramp.

Matches 800316F8 case10, 800314DC and 80031988 case10. This deliberately
does not claim to emulate SPU ADSR, Gaussian interpolation or reverb.
"""
import array


def driver_pitch_notes(initial, curve, ticks):
    if not curve:
        return [initial] * (ticks + 1)
    if curve[0] == 2 and len(curve) >= 2:
        return [initial] * (ticks + 1)
    if curve[0] == 1 and len(curve) >= 8:
        # 800316F8/80031988 case1 stores absolute two-stage targets.
        _, step, first, second_step, second, release, release_step, keyoff = curve[:8]
        curve = [10, 0, step, (first-initial)&0xffff, second_step,
                 (second-initial)&0xffff, (release-initial)&0xffff, release_step, keyoff]
    elif curve[0] == 0 and len(curve) >= 6:
        _, step, target, release, release_step, keyoff = curve[:6]
        curve = [10, 0, step, (target-initial)&0xffff, 0,
                 (target-initial)&0xffff, (release-initial)&0xffff, release_step, keyoff]
    elif curve[0] == 8 and len(curve) >= 7:
        _, delay, step, target, release, release_step, keyoff = curve[:7]
        curve = [10, delay, step, target, 0, target, release, release_step, keyoff]
    elif curve[0] == 5 and len(curve) >= 7:
        # 800316F8 case5 is the delayed absolute form of case8.
        _, delay, step, target, release, release_step, keyoff = curve[:7]
        curve = [10, delay, step, (target-initial)&0xffff, 0,
                 (target-initial)&0xffff, (release-initial)&0xffff, release_step, keyoff]
    elif curve[0] == 6 and len(curve) >= 9:
        _, delay, step, first, second_step, second, release, release_step, keyoff = curve[:9]
        curve = [10, delay, step, (first-initial)&0xffff, second_step,
                 (second-initial)&0xffff, (release-initial)&0xffff, release_step, keyoff]
    elif curve[0] in (7, 9):
        # Undelayed relative forms, with the same key-off fields.
        curve = [8, 0, *curve[1:]] if curve[0] == 7 else [10, 0, *curve[1:]]
        return driver_pitch_notes(initial, curve, ticks)
    if len(curve) < 9 or curve[0] != 10:
        raise ValueError('Only source-traced types 0, 1, 2 and 5 through 10 are supported')
    _, delay, step, first, second_step, second, release, release_step, keyoff = curve[:9]
    note = initial
    target = (initial + first) & 0xffff
    secondary = (initial + second) & 0xffff
    pending_second = True
    active = bool(step and note != target)
    result = [note]
    for tick in range(1, ticks + 1):
        if active:
            if delay:
                delay -= 1
            else:
                note = min(target, note + step) if note < target else max(target, note - step)
                if note == target:
                    active = False
                    if pending_second:
                        target = secondary
                        step = second_step
                        pending_second = False
                        active = True
        # Original update applies the pitch step before expiring key-on time.
        if keyoff and tick == keyoff:
            target = (initial + release) & 0xffff
            step = release_step
            pending_second = False
            active = note != target
        result.append(note)
    return result


def render_pitch(pcm, initial, center, curve, table, tick_rate=60, output_rate=44100):
    source = array.array('h', pcm)
    result = array.array('h')
    notes = driver_pitch_notes(initial, curve, max(1, len(source) * tick_rate // 1000 + 1))
    position = 0.0
    while position < len(source):
        frame = len(result)
        tick = frame * tick_rate // output_rate
        if tick >= len(notes):
            notes = driver_pitch_notes(initial, curve, tick + 64)
        pitch = notes[tick] - ((center - 60) << 8)
        if pitch < 0 or pitch >= 0x5300:
            register = 0x3fff
        else:
            index, fraction = pitch >> 8, pitch & 255
            register = (table[index] * (256 - fraction) + table[index + 1] * fraction) >> 8
        if register <= 0:
            raise ValueError('Zero-rate samples require a bounded hardware playback capture')
        index = int(position)
        fraction = position - index
        value = source[index] * (1 - fraction) + source[min(index + 1, len(source) - 1)] * fraction
        result.append(max(-32768, min(32767, round(value))))
        position += register / 4096 * 44100 / output_rate
    return result.tobytes()
