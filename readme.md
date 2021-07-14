# Record
[C#-like](https://docs.microsoft.com/en-us/dotnet/csharp/whats-new/tutorials/records) records for D

Records are classes and provide boilerplate implementations for properties, equality, hashing and toString. Get only fields can be set at construction, or when `duplicate` is called.

### Equality
Classes, interfaces and pointers are checked by reference (they point to the same thing). Basic types and structs are checked by value.

### Hashing
The hashing algorithm is very basic. It is `result = (31 * result) + currentField` for each field (in same order of declaration).

### Printing
Only fields are printed. The format is `{ fieldName = fieldValue, fieldName2 = fieldValue2, ...}`.

### Examples
```d
import drecord;

alias MyRecord = record!(
    get!(int, "x"), /// x is an int, can only be set during construction
    get_set!(float, "y"), /// y is a float, can be get or set whenever
    property!("getDoubleOfX", (r) => r.x * 2), /// a property that returns the double of x
    property!("getMultipleOfX", (r, m) => r.x * m, int), /// that takes an argument and multiples x by that value
    property!("printY", (r) => writeln(r.y)), /// prints y
    property!("resetY", (r) => r.y = 0) /// resets y to 0f
); 

auto r = new MyRecord(12, 4.5f); /// sets x, y

writeln(r); // { x = 12, y = 4.5f }
writeln(r.toHash); // 376

writeln(r.x); // 12
writeln(r.getDoubleOfX); // 24
writeln(r.getMultipleOfX(4)); // 48
r.printY; // 4.5
r.resetY;
writeln(r.y); // 0
r.y = 13f;
r.printY; // 13

/// Duplicate r, and set x to 17 (we can only do this in ctor, or during duplication)
/// This is equivalent to C#'s "with" syntax for records [0]
auto q = r.duplicate!("x")(17); 
writeln(q); // {x = 17, y = 0}
writeln(q == r); // false
writeln(q is r); // false

auto b = r.duplicate; // duplicate, don't change any fields
writeln(b == r); // true
writeln(b is r); // false
```

[0]: [Records in C#](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)