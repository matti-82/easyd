module easyd.base;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v1"

import std.stdio;

const int MEBI = 1024*1024;

T create(T,P...)(ref T obj,P par)
    if(is(T==class))
{
    if(obj is null)
    {
        obj = new T(par);
    }
    return obj;
}

bool hasDefaultConstructor(T)()
{
	return __traits(compiles, (new T));
}

ulong toHash(T)(T x)
{
	return typeid(x).getHash(&x);
}

Exception exception(string errmsg, bool writeAlways=true)
{
	if(writeAlways) writeln("Exception: "~errmsg);
    return new Exception(errmsg);
}

void trigger(void delegate()[] listeners)
{
	foreach ( void delegate() func ; listeners )
	{
		func();
	}
}

void trigger(T)(void delegate(T)[] listeners, T data)
{
	foreach ( void delegate(T) func ; listeners )
	{
		func(data);
	}
}

void trigger(T,T2)(void delegate(T,T2)[] listeners, T data, T2 data2)
{
	foreach ( void delegate(T,T2) func ; listeners )
	{
		func(data,data2);
	}
}

mixin template ImplementStruct(T)
{
	T ptr;

    this(TPar...)(TPar par)
    {
        ptr = new T(par);
    }

    T reference()
    {
		static if(hasDefaultConstructor!T)
		{
			return ptr.create;
		}
		else
		{
			return ptr;
		}
    }
    alias reference this;

    static if(__traits(hasMember, T, "dup"))
    {
        this(this)
        {
			//writeln("Struct-Copy...");
            if(ptr !is null) ptr = ptr.dup;
			//writeln("Struct-Copy ok");
		}
    }
    else
    {
        @disable this(this);
	}

	/*static if(hasDefaultConstructor!T && !__traits(hasMember, T, "_do_not_serialize_"))
	{
		static if(is(T:ISpecialSerialize))
		{
			void serialize(ISerializer destination) 
			{
				if(ptr !is null) ptr.serialize(destination);
			}
			
			bool deserialize(IDeserializer source)
			{
				ptr.create;
				return ptr.deserialize(source);
			}
		}
		else
		{
			void serialize(ISerializer destination) 
			{
				if(ptr !is null) destination.serializeFields(ptr);
			}
			
			bool deserialize(IDeserializer source)
			{
				ptr.create;
				while(!source.isEndOfSection)
				{
					source.getItem;
					source.fillObjectMember(ptr,source.currentName);
				}
				return true;
			}
		}
	}*/
}
