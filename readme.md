# Record
[DUB Package](https://code.dlang.org/packages/record)

[C#-like](https://docs.microsoft.com/en-us/dotnet/csharp/whats-new/tutorials/records) records for D

Records are classes and provide boilerplate implementations for properties, equality, hashing and toString. Get only fields can be set at construction, or when `duplicate` is called.

### Equality
Classes, interfaces and pointers are checked by reference (they point to the same thing). Basic types and structs are checked by value.

### Hashing
The hashing algorithm is very basic. It is `result = (31 * result) + currentField` for each field (in same order of declaration).

### Printing
Only fields are printed. The format is `{ fieldName = fieldValue, fieldName2 = fieldValue2, ...}`.

### `get`
Provides a field and accessor property. It can be default initialised or set during construction or duplication.

### `get_set`
Provides a field, accessor and mutator properties. It can be default initialised, set during construction or duplication, or freely at any other time.

### `get_compute`
This provides a lambda function that is invoked after all other fields have been initialised. This means you can run an expensive algorithm that is dependent on other record fields, and it only runs once during construction (or duplication).

### `property`
Provides a lambda method that can run a custom operation on the record fields.

### Examples
General usage:
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

writeln(r); // {x = 12, y = 4.5}
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
writeln(q); // {x = 17, y = 13}
writeln(q == r); // false
writeln(q is r); // false

auto b = r.duplicate; // duplicate, don't change any fields
writeln(b == r); // true
writeln(b is r); // false
```

Default initialisation:
```D
import drecord;

alias DefaultRecord = record!(
    // The third parameter is a lambda which provides default initialisation
    get!(int, "x", () => 4), // x is set to 4 by default
    get_set!(Object, "o", () => new Object) // o is set to a new Object by default
);

auto r = new DefaultRecord; // run the default initialisers
writeln(r); // {x = 4, o = object.Object}

auto q = DefaultRecord.create!"x"(9); // run default initialisers, then set x to 9
writeln(q); // {x = 9, o = object.Object}
```

Property computation:
```D
alias MyRecord = record!(
    get!(int, "x", () => 20),
    // get_compute lets you compute a field after the rest have been initialised
    get_compute!(float, "y", (rec) => rec.x * 2f)
);

auto r = new MyRecord;
writeln(r); // {x = 20, y = 40}
r = new MyRecord(10);
writeln(r); // {x = 10, y = 20}
r = MyRecord.create!"x"(5);
writeln(r); // {x = 5, y = 10}
auto q = r.duplicate!"x"(2);
writeln(q); // {x = 2, y = 4}
```

[0]: [Records in C#](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)