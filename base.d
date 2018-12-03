module easyd.base;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import std.stdio;
import std.traits;
import std.typecons;

const int MEBI = 1024*1024;

unittest
{
	static class StringArray
	{
		string[] data;
		void delegate(string)[] itemAdded;
		
		void add(string s)
		{
			data ~= s;
			itemAdded.trigger(s);
		}
	}
	
	static class MyComponent
	{
		StringArray sa;
		int callCount = 0;
		
		this()
		{
			sa.create; //equivalent to sa = new StringArray; but create avoids repeating the type (especially useful with templates)
			sa.itemAdded ~= &itemAddedHandler;
		}

		void itemAddedHandler(string s)
		{
			callCount++;
		}
	}
	
	auto mc = new MyComponent;
	mc.sa.add("Test");
	assert(mc.callCount==1);
}

T create(T,P...)(ref T obj,P par)
    if(is(T==class))
{
    if(obj is null)
    {
        obj = new T(par);
    }
    return obj;
}

bool isRefType(T)()
{
	T obj;
	return __traits(compiles, obj=null);
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

struct IdField {}

string idField(T)()
{
	static if(isAggregateType!T && !isTuple!T)
	{
		foreach (member; __traits(allMembers, T))
		{
			static if(__traits(compiles, hasUDA!(__traits(getMember, T, member), IdField)))
			{
				if (hasUDA!(__traits(getMember, T, member),	IdField)) return member;
			}
		}
	}
	return "";
}

bool setMember(TObj,TMem)(TObj obj, string member, TMem value)
{
    bool result = false;
    static if(is(TObj:Object))
    {
        foreach(t; BaseClassesTuple!TObj)
        {
            result = setMemberHelper(cast(t)(obj),member,value) || result;
        }
    }
    return setMemberHelper(obj,member,value) || result;
}

private bool setMemberHelper(TObj,TMem)(TObj obj, string member, ref TMem value)
{
    bool result = false;
    static if(__traits(hasMember, TObj, "tupleof"))
    {
        foreach (i,m; obj.tupleof)
        {
            if(__traits(identifier, obj.tupleof[i]) == member)
            {
                static if(is(typeof(value):typeof(m)))
                {
                    obj.tupleof[i] = value;
                    result = true;
                }
            }
        }
    }
    return result;
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
