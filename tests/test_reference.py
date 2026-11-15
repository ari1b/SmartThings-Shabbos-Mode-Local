"""Independent reference checks. Developer-only: pip install lupa pyluach astral pyyaml.
Run: python tests/test_reference.py (from the shabbos-edge directory).
"""
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import json
import math
from lupa.lua53 import LuaRuntime
from pyluach import dates
from astral import Observer
from astral.sun import sunset
import yaml

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
src = (ROOT / 'driver' / 'src').as_posix()
lua.execute(f'package.path = {json.dumps(src + "/?.lua;")} .. package.path')
cal = lua.eval('require("calendar")')
solar = lua.eval('require("solar")')
sched = lua.eval('require("schedule")')


def settings(**kwargs):
    return sched.settings(lua.table_from(kwargs))


def at(s):
    return int(datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp())


def main():
    count = 0
    start, end = date(2026, 1, 1), date(2099, 12, 31)
    current = start
    # Every supported day, independently compare both date systems and holidays.
    while current <= end:
        ordinal = current.toordinal()
        assert cal.gregorian_ordinal(current.year, current.month, current.day) == ordinal
        assert cal.gregorian_from_ordinal(ordinal) == (current.year, current.month, current.day)
        ref = dates.GregorianDate(current.year, current.month, current.day).to_heb()
        assert cal.hebrew_from_ordinal(ordinal) == (ref.year, ref.month, ref.day), current
        for israel in (False, True):
            festival = ref.festival(israel=israel, include_working_days=False)
            expected = current.weekday() == 5 or festival is not None
            actual, _ = cal.holy_day(ordinal, israel, True)
            assert actual == expected, (current, ref, israel, festival)
            assert cal.holy_day(ordinal, israel, False)[0] == (current.weekday() == 5)
        count += 1
        current += timedelta(days=1)
    print(f'PASS: {count:,} Gregorian/Hebrew dates and both holiday calendars, 2026-2099')

    maximum_error = 0
    solar_count = 0
    locations = {
        'Bergenfield': (40.9276, -73.9974), 'Jerusalem': (31.778, 35.235),
        'London': (51.5074, -0.1278), 'Los Angeles': (34.0522, -118.2437),
        'Honolulu': (21.3099, -157.8581), 'Sydney': (-33.8688, 151.2093),
        'Auckland': (-36.8485, 174.7633),
    }
    # Solar function supports all longitudes; driver excludes the date-line region.
    for year in (2026, 2027, 2030, 2040, 2060, 2099):
        for month in range(1, 13):
            for day in (1, 15, 28):
                d = date(year, month, day)
                for name, (lat, lon) in locations.items():
                    result = solar.sunset(d.toordinal(), lat, lon, 0)
                    # Astral's date selects UTC date; choose geographic local zone
                    # so east/west UTC-day crossings refer to the same solar day.
                    zone = timezone(timedelta(hours=round(lon / 15)))
                    reference = sunset(Observer(lat, lon), date=d, tzinfo=zone).timestamp()
                    difference = abs(result - reference)
                    assert difference < 65, (d, name, difference)
                    maximum_error = max(maximum_error, difference)
                    solar_count += 1
    print(f'PASS: {solar_count:,} sunsets vs Astral; largest difference {maximum_error:.1f} seconds')

    cfg = settings()
    # Every transition over 5 years: second before and second after, plus reboot
    # (new evaluation) during the holy period, not just an in-memory timer.
    transitions = {}
    d = date(2026, 1, 1)
    while d < date(2031, 1, 1):
        events = sched.events(at(d.isoformat() + 'T12:00:00Z'), cfg)
        for _, e in events.items():
            transitions[e.at] = e.state
        d += timedelta(days=7)
    for timestamp, state in transitions.items():
        before, _ = sched.evaluate(timestamp - 1, cfg)
        exact, _ = sched.evaluate(timestamp, cfg)
        after, _ = sched.evaluate(timestamp + 1, cfg)
        assert before != state and exact == after == state
    print(f'PASS: {len(transitions):,} transition boundaries and fresh-state reconstruction')

    # 2027 diaspora: Thu/Fri Shavuos followed by Shabbos = Wed start, Sat end.
    state, event = sched.evaluate(at('2027-06-11T16:00:00Z'), cfg)
    assert state == 'on' and event.date == '2027-06-12' and event.state == 'off'
    # 2026 first Pesach: diaspora two days leading directly into Shabbos.
    state, event = sched.evaluate(at('2026-04-03T16:00:00Z'), cfg)
    assert state == 'on' and event.date == '2026-04-04'
    israel = settings(israel=True)
    state, event = sched.evaluate(at('2026-04-03T16:00:00Z'), israel)
    assert state == 'off' and event.date == '2026-04-03' and event.state == 'on'
    # Independent longitude crossing: Honolulu sunset belongs to next UTC day.
    hawaii = settings(latitude='21.3099', longitude='-157.8581')
    events = sched.events(at('2026-11-13T12:00:00Z'), hawaii)
    friday = next(e for _, e in events.items() if e.date == '2026-11-13')
    assert datetime.fromtimestamp(friday.at, timezone.utc).date() == date(2026, 11, 14)
    # Elevation moves sunset later; before/after offsets and adjustment are exact.
    n = date(2026, 11, 13).toordinal()
    assert solar.sunset(n, 40.9276, -73.9974, 100) > solar.sunset(n, 40.9276, -73.9974, 0)
    base = sched.events(at('2026-11-13T12:00:00Z'), cfg)
    shifted = sched.events(at('2026-11-13T12:00:00Z'), settings(sunsetAdjustment=3))
    assert all(shifted[i].at - base[i].at == 180 for i in range(1, len(base) + 1))
    for args in ({'latitude': 'garbage'}, {'longitude': '73,9'}, {'latitude': '90'}, {'candleMinutes': -1}):
        try:
            settings(**args)
        except Exception:
            pass
        else:
            raise AssertionError(f'Invalid config accepted: {args}')
    print('PASS: consecutive days, Israel/diaspora, UTC date crossing, elevation, offsets, invalid settings')

    # All Lua files compile and the YAML profile agrees with the discovery name.
    for path in (ROOT / 'driver' / 'src').glob('*.lua'):
        lua.execute('assert(load(...))', path.read_text())
    profile = yaml.safe_load((ROOT / 'driver' / 'profiles' / 'shabbos-mode-local.yaml').read_text())
    assert profile['name'] == 'shabbos-mode-local.v1'
    assert len({p['name'] for p in profile['preferences']}) == len(profile['preferences'])
    defaults = {p['name']: p['definition']['default'] for p in profile['preferences']}
    assert not sched.settings(lua.table_from(defaults)).enabled
    print('PASS: Lua syntax, YAML profile, configuration defaults')


if __name__ == '__main__':
    main()
