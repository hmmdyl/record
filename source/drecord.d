module drecord;

import std.meta;
import std.traits;
import std.conv : to;

/++ Add a field and getter to the record
+ Params:
+	type: The type the field will be
+	name: Name of the field 
+	args: An optional default initialisation lambda++/
template get(alias type, string name, args...)
{
	static assert(args.length <= 1, "There may only be 0 or 1 default initialisers");

	private alias type_ = type;
	private alias name_ = name;
	private alias args_ = args;
}

private mixin template getImpl(alias type, string name, args...)
{
	static if(args.length == 0)
		mixin("protected " ~ type.stringof ~ " " ~ name ~ "_;");
	else
		mixin("protected " ~ type.stringof ~ " " ~ name ~ "_ = AliasSeq!(args)[0]();");
	mixin("public @property auto " ~ name ~ "() { return " ~ name ~ "_; }");
}

/++ Add a field and appropriate getter and setter to the record
+ Params:
+	type: The type the field will be
+	name: Name of the field 
+	args: An optional default initialisation lambda ++/
template get_set(alias type, string name, args...)
{
	static assert(args.length <= 1, "There may only be 0 or 1 default initialisers");

	private alias type_ = type;
	private alias name_ = name;
	private alias args_ = args;
}

private mixin template get_setImpl(alias type, string name, args...)
{
	static if(args.length == 0)
		mixin("protected " ~ type.stringof ~ " " ~ name ~ "_;");
	else
		mixin("protected " ~ type.stringof ~ " " ~ name ~ "_ = AliasSeq!(args)[0]();");
	mixin("public @property auto " ~ name ~ "() { return " ~ name ~ "_; }");
	mixin("public @property void " ~ name ~ "(" ~ type.stringof ~ " nval__) { " ~ name ~ "_ = nval__; }");
}

template get_compute(alias type, string name, alias construct)
{
	private alias type_ = type;
	private alias name_ = name;
	private alias construct_ = construct;
}

private mixin template get_computeImpl(alias type, string name, alias construct)
{
	private static string generateImpl()
	{
		string header = "protected " ~ type.stringof ~ " " ~ name ~ "_;" ~ 
			"protected @property auto " ~ name ~ "_construct() { return construct(this); }" ~
			"public @property auto " ~ name ~ "() { return " ~ name ~ "_; }";
		return header;
	}
	mixin(generateImpl);
}

/++ Add a property to the record
+ Params:
+	name: Name of the property
+	accessor: A lambda of the property body
+	args: Types of arguments the property needs ++/
template property(string name, alias accessor, args...)
{
	private alias name_ = name;
	private alias accessor_ = accessor;
	private alias args_ = AliasSeq!args;
}

private mixin template propertyImpl(string name, alias accessor, args...)
{
	private alias seq = AliasSeq!args;
	private static string generateImpl()
	{
		string header = "public @property auto " ~ name ~ "(";
		string body_ = "{ return accessor(this, ";
		static foreach(i, item; seq)
		{
			header ~= item.stringof ~ " arg" ~ to!string(i) ~ "__";
			body_ ~= "arg" ~ to!string(i) ~ "__";
			static if(i < seq.length - 1) 
			{
				header ~= ", ";
				body_ ~= ", ";
			}
		}
		header ~= ") ";
		body_ ~= "); }";
		return header ~ body_;
	}
	mixin(generateImpl);
}

template record(args...)
{
	private enum isGet(alias T) = __traits(isSame, TemplateOf!T, get);
	private enum isGetSet(alias T) = __traits(isSame, TemplateOf!T, get_set);
	private enum isProperty(alias T) = __traits(isSame, TemplateOf!T, property);
	private enum isGetCompute(alias T) = __traits(isSame, TemplateOf!T, get_compute);

	private enum isCtorParam(alias T) = isGet!T || isGetSet!T;
	private enum numCtorParam = Filter!(isCtorParam, AliasSeq!args).length;
	private enum isField(alias T) = isGet!T || isGetSet!T || isGetCompute!T;
	private enum numFields = Filter!(isField, AliasSeq!args).length;

	/// Generate a constructor that takes inputs for every field
	private static string genCtor()
	{
		string header = "public this(";
		string body_ = "{\n";

		static foreach(i, item; Filter!(isCtorParam, AliasSeq!args))
		{
			header ~= item.type_.stringof ~ " arg" ~ to!string(i) ~ "__";
			body_ ~= "\t" ~ item.name_ ~ "_ = arg" ~ to!string(i) ~ "__;\n";

			static if(i < numCtorParam - 1)
				header ~= ", ";
		}
		header ~= ")\n";
		body_ ~= "constructs; }";
		return header ~ body_;
	}

	/++ Test for equality. Reference types are checked to ensure
	+ their references are the same (point to same thing), value types
	+ are checked to ensure their values are identical.
	++/
	private static string genEquals()
	{
		string res = "import std.math : isClose;\nbool result = true;\n";
		static foreach(i, item; Filter!(isField, AliasSeq!args))
		{
			static if(is(item.type_ == class) ||
					  is(item.type_ == interface) ||
					  isPointer!(item.type_))
			{
				res ~= "if(" ~ item.name_ ~ "_ !is otherRec." ~ item.name_ ~ "_) { result = false; }\n";
			}
			else static if(isFloatingPoint!(item.type_))
			{
				res ~= "if(!isClose(" ~ item.name_ ~ "_, otherRec." ~ item.name_ ~ "_)) { result = false; }\n";
			}
			else
			{
				res ~= "if(" ~ item.name_ ~ "_ != otherRec." ~ item.name_ ~ "_) { result = false; }\n";
			}
		}
		res ~= "return result;";
		return res;
	}

	final class record
	{
		static foreach(item; AliasSeq!args)
		{
			static if(isGet!item)
				mixin getImpl!(item.type_, item.name_, item.args_);
			else static if(isGetSet!item)
				mixin get_setImpl!(item.type_, item.name_, item.args_);
			else static if(isProperty!item) 
				mixin propertyImpl!(item.name_, item.accessor_, item.args_);
			else static if(isGetCompute!item)
				mixin get_computeImpl!(item.type_, item.name_, item.construct_);
			else static assert(false, "Unsupported type. Please ensure types for record are either get!T, get_set!T, property!T");
		}

		this(bool runConstructs = true) 
		{
			if(runConstructs)
			{
				constructs;
			}
		}

		private void constructs()
		{
			static foreach(item; Filter!(isGetCompute, AliasSeq!args))
			{
				mixin("this." ~ item.name_ ~ "_ = " ~ item.name_ ~ "_construct();");
			}
		}

		mixin(genCtor);

		/// Explicitly set certain fields, default initialise the rest
		static record create(TNames...)(...)
		{
			auto r = new record(false);
			import core.vararg;
			static foreach(item; AliasSeq!TNames)
			{
				static foreach(b; AliasSeq!args)
					static if(isGetCompute!b)
						static assert(b.name_ != item, "Cannot set a get_compute property '" ~ item ~ "'");

				mixin("r." ~ item ~ "_ = va_arg!(typeof(" ~ item ~ "_))(_argptr);");
			}
			r.constructs;
			return r;
		}

		/++ Test for equality. Reference types are checked to ensure
		+ their references are the same (point to same thing), value types
		+ are checked to ensure their values are identical.
		++/
		override bool opEquals(Object other)
		{
			if(record otherRec = cast(record)other)
			{
				mixin(genEquals);
			}
			else return false;
		}

		/// Generate a human-readable string. Fields are sampled.
		override string toString()
		{
			string result = "{";

			static foreach(i, item; Filter!(isField, AliasSeq!args))
			{
				result ~= item.name_ ~ " = " ~ to!string(mixin(item.name_ ~ "_"));
				static if(i < numFields - 1)
					result ~= ", ";
			}
			result ~= "}";

			return result;
		}

		override nothrow @trusted size_t toHash()
		{
			size_t result = 0;

			static foreach(i, item; Filter!(isField, AliasSeq!args))
			{
				static if(is(item.type_ == class) || is(item.type_ == interface))
					result = result * 31 + cast(size_t)mixin(item.name_ ~ "_.toHash()");
				else static if(is(item.type_ == struct))
				{
					static if(__traits(compiles, () { item.type_().toHash; }()))
						result = result * 31 + cast(size_t)mixin(item.name_ ~ "_");
				}
				else
					result = result * 31 + cast(size_t)mixin(item.name_ ~ "_");
			}

			return result;
		}
		/++ Create a copy of this record and permit modification of read-only fields. ++/
		record duplicate(TNames...)(...)
		{
			record r = new record;
			static foreach(item; Filter!(isField, AliasSeq!args))
				mixin("r." ~ item.name_ ~ "_ = this." ~ item.name_ ~ "_;");
			import core.vararg;
			static foreach(item; AliasSeq!TNames)
			{
				static foreach(b; AliasSeq!args)
					static if(isGetCompute!b)
						static assert(b.name_ != item, "Cannot set a get_compute property '" ~ item ~ "'");

				mixin("r." ~ item ~ "_ = va_arg!(typeof(" ~ item ~ "_))(_argptr);");
			}
			r.constructs;
			return r;
		}
	}
}