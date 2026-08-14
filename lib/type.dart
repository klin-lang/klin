/// Klin primitive types and their C mappings.
enum PrimKind {
  i8,
  i16,
  i32,
  i64,
  u8,
  u16,
  u32,
  u64,
  f32,
  f64,
  bool_,
  usize,
  isize;

  String get klinName => switch (this) {
        PrimKind.bool_ => 'bool',
        _ => name,
      };

  String get cType => switch (this) {
        PrimKind.i8 => 'int8_t',
        PrimKind.i16 => 'int16_t',
        PrimKind.i32 => 'int32_t',
        PrimKind.i64 => 'int64_t',
        PrimKind.u8 => 'uint8_t',
        PrimKind.u16 => 'uint16_t',
        PrimKind.u32 => 'uint32_t',
        PrimKind.u64 => 'uint64_t',
        PrimKind.f32 => 'float',
        PrimKind.f64 => 'double',
        PrimKind.bool_ => 'bool',
        PrimKind.usize => 'size_t',
        PrimKind.isize => 'ptrdiff_t',
      };

  String get cZero => switch (this) {
        PrimKind.f32 || PrimKind.f64 => '0.0',
        PrimKind.bool_ => 'false',
        _ => '0',
      };

  bool get isInteger => switch (this) {
        PrimKind.i8 ||
        PrimKind.i16 ||
        PrimKind.i32 ||
        PrimKind.i64 ||
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.u64 ||
        PrimKind.usize ||
        PrimKind.isize =>
          true,
        _ => false,
      };

  bool get isFloat => this == PrimKind.f32 || this == PrimKind.f64;

  /// Parses a primitive type name.
  ///
  /// `int` and `float` are fixed-size aliases (`i32` / `f64`), matching
  /// untyped literal defaults — never C's ABI-dependent `int`/`float`.
  static PrimKind? tryParse(String name) => switch (name) {
        'i8' => PrimKind.i8,
        'i16' => PrimKind.i16,
        'i32' || 'int' => PrimKind.i32,
        'i64' => PrimKind.i64,
        'u8' => PrimKind.u8,
        'u16' => PrimKind.u16,
        'u32' => PrimKind.u32,
        'u64' => PrimKind.u64,
        'f32' => PrimKind.f32,
        'f64' || 'float' => PrimKind.f64,
        'bool' => PrimKind.bool_,
        'usize' => PrimKind.usize,
        'isize' => PrimKind.isize,
        _ => null,
      };
}

sealed class KlinType {
  const KlinType();

  String get displayName;
}

final class PrimType extends KlinType {
  final PrimKind kind;

  const PrimType(this.kind);

  @override
  String get displayName => kind.klinName;

  @override
  bool operator ==(Object other) => other is PrimType && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

final class VoidType extends KlinType {
  const VoidType();

  @override
  String get displayName => 'void';

  @override
  bool operator ==(Object other) => other is VoidType;

  @override
  int get hashCode => 0;
}

final class StructType extends KlinType {
  final String moduleName;
  final String name;

  const StructType(this.moduleName, this.name);

  @override
  String get displayName => moduleName.isEmpty ? name : '$moduleName.$name';

  @override
  bool operator ==(Object other) =>
      other is StructType &&
      other.moduleName == moduleName &&
      other.name == name;

  @override
  int get hashCode => Object.hash(moduleName, name);
}

/// A C-like enum: a distinct named type over an integer base (issue 072).
final class EnumType extends KlinType {
  final String moduleName;
  final String name;

  /// Underlying integer type (default `i32`). Not part of identity/equality.
  final PrimType base;

  const EnumType(this.moduleName, this.name, this.base);

  @override
  String get displayName => moduleName.isEmpty ? name : '$moduleName.$name';

  @override
  bool operator ==(Object other) =>
      other is EnumType &&
      other.moduleName == moduleName &&
      other.name == name;

  @override
  int get hashCode => Object.hash('enum', moduleName, name);
}

final class PtrType extends KlinType {
  final KlinType pointee;
  final bool isMut;
  final bool isVolatile;

  const PtrType(this.pointee, {this.isMut = false, this.isVolatile = false});

  @override
  String get displayName =>
      '*${isMut ? 'mut ' : ''}${isVolatile ? 'volatile ' : ''}${pointee.displayName}';

  @override
  bool operator ==(Object other) =>
      other is PtrType &&
      other.pointee == pointee &&
      other.isMut == isMut &&
      other.isVolatile == isVolatile;

  @override
  int get hashCode => Object.hash(pointee, isMut, isVolatile);
}

final class ArrayType extends KlinType {
  final KlinType elem;
  final int len;

  const ArrayType(this.elem, this.len);

  @override
  String get displayName => '[$len]${elem.displayName}';

  @override
  bool operator ==(Object other) =>
      other is ArrayType && other.elem == elem && other.len == len;

  @override
  int get hashCode => Object.hash(elem, len);
}

final class SliceType extends KlinType {
  final PrimType elem;

  const SliceType(this.elem);

  @override
  String get displayName => '[]${elem.displayName}';

  @override
  bool operator ==(Object other) => other is SliceType && other.elem == elem;

  @override
  int get hashCode => elem.hashCode;
}

/// Function pointer without capture (C function pointer).
final class FnType extends KlinType {
  final List<KlinType> params;
  final KlinType ret;

  const FnType(this.params, this.ret);

  @override
  String get displayName {
    final ps = params.map((p) => p.displayName).join(', ');
    return 'fn($ps): ${ret.displayName}';
  }

  @override
  bool operator ==(Object other) =>
      other is FnType &&
      other.ret == ret &&
      _listEq(other.params, params);

  static bool _listEq(List<KlinType> a, List<KlinType> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(ret, Object.hashAll(params));
}

/// Result of an operation whose error is always an `i32` code.
final class ResultType extends KlinType {
  final KlinType ok;

  const ResultType(this.ok);

  @override
  String get displayName => '!${ok.displayName}';

  @override
  bool operator ==(Object other) => other is ResultType && other.ok == ok;

  @override
  int get hashCode => Object.hash('result', ok);
}

/// Integer literal without an assigned concrete type yet.
final class UntypedInt extends KlinType {
  const UntypedInt();

  @override
  String get displayName => 'untyped int';

  @override
  bool operator ==(Object other) => other is UntypedInt;

  @override
  int get hashCode => 1;
}

/// Floating-point literal without an assigned concrete type yet.
final class UntypedFloat extends KlinType {
  const UntypedFloat();

  @override
  String get displayName => 'untyped float';

  @override
  bool operator ==(Object other) => other is UntypedFloat;

  @override
  int get hashCode => 2;
}

/// `error(n)` before its `!T` ok-type is known (match-arm unify, issue 132).
/// Never survives a finished check / `_defaultConcrete`.
final class BareErrorType extends KlinType {
  const BareErrorType();

  @override
  String get displayName => 'error';

  @override
  bool operator ==(Object other) => other is BareErrorType;

  @override
  int get hashCode => 17;
}

/// C string (`const char*`). Literals and `str` parameters for thin FFI / stdlib.
final class StrType extends KlinType {
  const StrType();

  @override
  String get displayName => 'str';

  @override
  bool operator ==(Object other) => other is StrType;

  @override
  int get hashCode => 3;
}
