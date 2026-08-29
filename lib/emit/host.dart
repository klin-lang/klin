part of '../emit_c.dart';

void _emitMemHostHelpers(StringBuffer buf, Program program) {
  final names = _memHostCodename(program);
  buf.writeln('#include <stdlib.h>');
  buf.writeln();
  for (final name in names) {
    if (name == 'klin_mem_alloc_u8') {
      final res = _resultCName(const SliceType(PrimType(PrimKind.u8)));
      final slice = _sliceCName(const PrimType(PrimKind.u8));
      buf.writeln('$res klin_mem_alloc_u8(int32_t n) {');
      buf.writeln('    $res r;');
      buf.writeln('    if (n < 0) { r.is_err = true; r.u.err = 1; return r; }');
      buf.writeln('    if (n == 0) {');
      buf.writeln('        r.is_err = false;');
      buf.writeln('        r.u.ok = ($slice){ NULL, 0 };');
      buf.writeln('        return r;');
      buf.writeln('    }');
      buf.writeln('    void *p = malloc((size_t)n);');
      buf.writeln('    if (p == NULL) { r.is_err = true; r.u.err = 2; return r; }');
      buf.writeln('    r.is_err = false;');
      buf.writeln('    r.u.ok = ($slice){ (uint8_t *)p, (size_t)n };');
      buf.writeln('    return r;');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_free_u8') {
      final slice = _sliceCName(const PrimType(PrimKind.u8));
      buf.writeln('void klin_mem_free_u8($slice buf) {');
      buf.writeln('    free(buf.ptr);');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_alloc_i32') {
      final res = _resultCName(const SliceType(PrimType(PrimKind.i32)));
      final slice = _sliceCName(const PrimType(PrimKind.i32));
      buf.writeln('$res klin_mem_alloc_i32(int32_t n) {');
      buf.writeln('    $res r;');
      buf.writeln('    if (n < 0) { r.is_err = true; r.u.err = 1; return r; }');
      buf.writeln('    if (n == 0) {');
      buf.writeln('        r.is_err = false;');
      buf.writeln('        r.u.ok = ($slice){ NULL, 0 };');
      buf.writeln('        return r;');
      buf.writeln('    }');
      buf.writeln(
          '    if ((size_t)n > SIZE_MAX / sizeof(int32_t)) {');
      buf.writeln('        r.is_err = true; r.u.err = 2; return r;');
      buf.writeln('    }');
      buf.writeln(
          '    void *p = malloc((size_t)n * sizeof(int32_t));');
      buf.writeln('    if (p == NULL) { r.is_err = true; r.u.err = 2; return r; }');
      buf.writeln('    r.is_err = false;');
      buf.writeln('    r.u.ok = ($slice){ (int32_t *)p, (size_t)n };');
      buf.writeln('    return r;');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_free_i32') {
      final slice = _sliceCName(const PrimType(PrimKind.i32));
      buf.writeln('void klin_mem_free_i32($slice buf) {');
      buf.writeln('    free(buf.ptr);');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_alloc_i64') {
      const elem = PrimType(PrimKind.i64);
      final res = _resultCName(const SliceType(elem));
      final slice = _sliceCName(elem);
      final ct = _cType(elem);
      buf.writeln('$res klin_mem_alloc_i64(int32_t n) {');
      buf.writeln('    $res r;');
      buf.writeln('    if (n < 0) { r.is_err = true; r.u.err = 1; return r; }');
      buf.writeln('    if (n == 0) {');
      buf.writeln('        r.is_err = false;');
      buf.writeln('        r.u.ok = ($slice){ NULL, 0 };');
      buf.writeln('        return r;');
      buf.writeln('    }');
      buf.writeln('    if ((size_t)n > SIZE_MAX / sizeof($ct)) {');
      buf.writeln('        r.is_err = true; r.u.err = 2; return r;');
      buf.writeln('    }');
      buf.writeln('    void *p = malloc((size_t)n * sizeof($ct));');
      buf.writeln('    if (p == NULL) { r.is_err = true; r.u.err = 2; return r; }');
      buf.writeln('    r.is_err = false;');
      buf.writeln('    r.u.ok = ($slice){ ($ct *)p, (size_t)n };');
      buf.writeln('    return r;');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_free_i64') {
      final slice = _sliceCName(const PrimType(PrimKind.i64));
      buf.writeln('void klin_mem_free_i64($slice buf) {');
      buf.writeln('    free(buf.ptr);');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_alloc_f64') {
      const elem = PrimType(PrimKind.f64);
      final res = _resultCName(const SliceType(elem));
      final slice = _sliceCName(elem);
      final ct = _cType(elem);
      buf.writeln('$res klin_mem_alloc_f64(int32_t n) {');
      buf.writeln('    $res r;');
      buf.writeln('    if (n < 0) { r.is_err = true; r.u.err = 1; return r; }');
      buf.writeln('    if (n == 0) {');
      buf.writeln('        r.is_err = false;');
      buf.writeln('        r.u.ok = ($slice){ NULL, 0 };');
      buf.writeln('        return r;');
      buf.writeln('    }');
      buf.writeln('    if ((size_t)n > SIZE_MAX / sizeof($ct)) {');
      buf.writeln('        r.is_err = true; r.u.err = 2; return r;');
      buf.writeln('    }');
      buf.writeln('    void *p = malloc((size_t)n * sizeof($ct));');
      buf.writeln('    if (p == NULL) { r.is_err = true; r.u.err = 2; return r; }');
      buf.writeln('    r.is_err = false;');
      buf.writeln('    r.u.ok = ($slice){ ($ct *)p, (size_t)n };');
      buf.writeln('    return r;');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_free_f64') {
      final slice = _sliceCName(const PrimType(PrimKind.f64));
      buf.writeln('void klin_mem_free_f64($slice buf) {');
      buf.writeln('    free(buf.ptr);');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_empty_u8') {
      final slice = _sliceCName(const PrimType(PrimKind.u8));
      buf.writeln('$slice klin_mem_empty_u8(void) {');
      buf.writeln('    return ($slice){ NULL, 0 };');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_empty_i32') {
      final slice = _sliceCName(const PrimType(PrimKind.i32));
      buf.writeln('$slice klin_mem_empty_i32(void) {');
      buf.writeln('    return ($slice){ NULL, 0 };');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_empty_i64') {
      final slice = _sliceCName(const PrimType(PrimKind.i64));
      buf.writeln('$slice klin_mem_empty_i64(void) {');
      buf.writeln('    return ($slice){ NULL, 0 };');
      buf.writeln('}');
      buf.writeln();
    } else if (name == 'klin_mem_empty_f64') {
      final slice = _sliceCName(const PrimType(PrimKind.f64));
      buf.writeln('$slice klin_mem_empty_f64(void) {');
      buf.writeln('    return ($slice){ NULL, 0 };');
      buf.writeln('}');
      buf.writeln();
    }
  }
}

bool _programNeedsTimeHost(Program program) {
  const names = {
    'klin_time_wall_ns',
    'klin_time_mono_ns',
    'klin_time_format',
    'klin_time_parse',
    'klin_time_parse_iso',
    'klin_time_add_date',
  };
  for (final func in program.funcs) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename' && attr.arg != null && names.contains(attr.arg)) {
        return true;
      }
    }
  }
  return false;
}

bool _programNeedsFmtHost(Program program) {
  for (final func in program.funcs) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename' && attr.arg == 'klin_fmt_write_str') {
        return true;
      }
    }
  }
  return false;
}

void _emitFmtHostHelpers(StringBuffer buf) {
  buf.writeln('#include <stdio.h>');
  buf.writeln();
  buf.writeln(
      'int32_t klin_fmt_write_str(uint8_t *buf, int32_t len, const char *msg) {');
  buf.writeln('    if (buf == NULL || len <= 0 || msg == NULL) return -1;');
  buf.writeln('    int n = snprintf((char *)buf, (size_t)len, "%s", msg);');
  buf.writeln('    if (n < 0 || n >= len) return -1;');
  buf.writeln('    return (int32_t)n;');
  buf.writeln('}');
  buf.writeln();
}

void _emitTimeHostHelpers(StringBuffer buf) {
  buf.writeln('#include <time.h>');
  buf.writeln('#include <stdio.h>');
  buf.writeln('#include <string.h>');
  buf.writeln('#include <errno.h>');
  buf.writeln();
  buf.writeln('int64_t klin_time_wall_ns(void) {');
  buf.writeln('    struct timespec ts;');
  buf.writeln('    if (clock_gettime(CLOCK_REALTIME, &ts) != 0) return 0;');
  buf.writeln(
      '    return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln('int64_t klin_time_mono_ns(void) {');
  buf.writeln('    struct timespec ts;');
  buf.writeln('    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;');
  buf.writeln(
      '    return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln(
      'int32_t klin_time_format(uint8_t *buf, int32_t buflen, const char *fmt, int64_t unix_ns) {');
  buf.writeln('    if (buf == NULL || buflen <= 0 || fmt == NULL) return -1;');
  buf.writeln('    time_t sec = (time_t)(unix_ns / 1000000000LL);');
  buf.writeln('    struct tm tm;');
  buf.writeln('    if (gmtime_r(&sec, &tm) == NULL) return -1;');
  buf.writeln(
      '    size_t n = strftime((char *)buf, (size_t)buflen, fmt, &tm);');
  buf.writeln('    if (n == 0) return -1;');
  buf.writeln('    return (int32_t)n;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln(
      'static int32_t klin_time_from_tm(int64_t *out_ns, struct tm *tm) {');
  buf.writeln('    errno = 0;');
  buf.writeln('    time_t sec = timegm(tm);');
  // time_t -1 is also a valid UTC instant (1969-12-31 23:59:59); only fail on errno.
  buf.writeln('    if (sec == (time_t)-1 && errno != 0) return 2;');
  buf.writeln('    *out_ns = (int64_t)sec * 1000000000LL;');
  buf.writeln('    return 0;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln(
      'int32_t klin_time_parse_iso(int64_t *out_ns, const char *s) {');
  buf.writeln('    if (out_ns == NULL || s == NULL) return 1;');
  buf.writeln('    int y = 0, mo = 0, d = 0, h = 0, mi = 0, sec = 0;');
  buf.writeln('    int consumed = 0;');
  buf.writeln(
      '    if (sscanf(s, "%d-%d-%dT%d:%d:%dZ%n", &y, &mo, &d, &h, &mi, &sec, &consumed) == 6) {');
  buf.writeln('        if (s[consumed] != \'\\0\') return 1;');
  buf.writeln(
      '    } else if (sscanf(s, "%d-%d-%d%n", &y, &mo, &d, &consumed) == 3) {');
  buf.writeln('        if (s[consumed] != \'\\0\') return 1;');
  buf.writeln('        h = 0; mi = 0; sec = 0;');
  buf.writeln('    } else {');
  buf.writeln('        return 1;');
  buf.writeln('    }');
  buf.writeln('    if (mo < 1 || mo > 12 || d < 1 || d > 31) return 1;');
  buf.writeln('    struct tm tm;');
  buf.writeln('    memset(&tm, 0, sizeof(tm));');
  buf.writeln('    tm.tm_year = y - 1900;');
  buf.writeln('    tm.tm_mon = mo - 1;');
  buf.writeln('    tm.tm_mday = d;');
  buf.writeln('    tm.tm_hour = h;');
  buf.writeln('    tm.tm_min = mi;');
  buf.writeln('    tm.tm_sec = sec;');
  buf.writeln('    return klin_time_from_tm(out_ns, &tm);');
  buf.writeln('}');
  buf.writeln();
  buf.writeln(
      'int32_t klin_time_parse(int64_t *out_ns, const char *fmt, const char *s) {');
  buf.writeln('    if (out_ns == NULL || fmt == NULL || s == NULL) return 1;');
  buf.writeln('    struct tm tm;');
  buf.writeln('    memset(&tm, 0, sizeof(tm));');
  buf.writeln('    const char *end = strptime(s, fmt, &tm);');
  buf.writeln('    if (end == NULL || *end != \'\\0\') return 1;');
  buf.writeln('    return klin_time_from_tm(out_ns, &tm);');
  buf.writeln('}');
  buf.writeln();
  // Go-style AddDate on UTC civil calendar; preserves sub-second ns.
  buf.writeln(
      'int32_t klin_time_add_date(int64_t *out_ns, int64_t unix_ns, int32_t years, int32_t months, int32_t days) {');
  buf.writeln('    if (out_ns == NULL) return 1;');
  buf.writeln('    int64_t sec = unix_ns / 1000000000LL;');
  buf.writeln('    int64_t frac = unix_ns % 1000000000LL;');
  buf.writeln('    if (frac < 0) {');
  buf.writeln('        frac += 1000000000LL;');
  buf.writeln('        sec -= 1;');
  buf.writeln('    }');
  buf.writeln('    time_t tsec = (time_t)sec;');
  buf.writeln('    struct tm tm;');
  buf.writeln('    if (gmtime_r(&tsec, &tm) == NULL) return 1;');
  buf.writeln('    tm.tm_year += (int)years;');
  buf.writeln('    tm.tm_mon += (int)months;');
  buf.writeln('    tm.tm_mday += (int)days;');
  buf.writeln('    tm.tm_isdst = 0;');
  buf.writeln('    int32_t rc = klin_time_from_tm(out_ns, &tm);');
  buf.writeln('    if (rc != 0) return rc;');
  buf.writeln('    *out_ns += frac;');
  buf.writeln('    return 0;');
  buf.writeln('}');
  buf.writeln();
}

