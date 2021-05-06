module easyd.base;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import std.stdio;
import std.traits;
import std.typecons;
import std.math;
import std.conv;
import std.datetime;
import core.time;
import core.thread;
import core.memory;

// aliases to allow writing types consistently in Pascal casing ////////

alias byte Int8;
alias ubyte UInt8;
alias UInt8 Byte;
alias short Int16;
alias ushort UInt16;
alias int Int32;
alias uint UInt32;
alias long Int64;
alias ulong UInt64;

alias Int32 Int;
alias ptrdiff_t NInt; //native int
alias size_t NUInt;

alias float Float32;
alias double Float64;
alias real Real;

alias Float32 Float;

alias bool Bool;
alias string Str;

////////////////////////////////////////////////////////////////////////

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

// language extensions /////////////////////////////////////////////////

void pinAddr(T)(T obj)
{
	GC.addRoot(cast(void*)obj);
	GC.setAttr(cast(void*)obj, GC.BlkAttr.NO_MOVE);
}

void unpinAddr(T)(T obj)
{
	GC.clrAttr(cast(void*)obj, GC.BlkAttr.NO_MOVE);
	GC.removeRoot(cast(void*)obj);
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

T recreate(T,P...)(ref T obj,P par)
	if(is(T==class))
{
	obj = new T(par);
	return obj;
}

bool Try(lazy void expression)
{
    try
    {
        expression;
        return true;
    }
    catch(Exception e)
    {
        return false;
    }
}

// type tools //////////////////////////////////////////////////////////

bool isRefType(T)()
{
	T obj;
	return __traits(compiles, obj=null);
}

//bool inherits(TCheck,TObj)(const TObj obj)
bool inherits(TCheck,TObj)(TObj obj) //work around for the mutable ObjectG.opCast of gtk-d, which should not be mutable of course
{
	return cast(const TCheck)(obj) !is null;
}

bool hasDefaultConstructor(T)()
{
	return __traits(compiles, (new T));
}

bool isClassOrStruct(T)()
{
	return __traits(hasMember, T, "tupleof");
}

// array tools /////////////////////////////////////////////////////////

T first(T)(T[] array)
{
	return array[0];
}

T last(T)(T[] array)
{
	return array[array.length-1];
}

T readFromPos(T)(Byte[] a, ulong pos)
	if(isBasicType!T)
{
	return *(cast(T*)(&(a[pos])));
}

void writeToPos(T)(Byte[] a, ulong pos, T value)
	if(isBasicType!T)
{
	*(cast(Unqual!T*)(&(a[pos]))) = value;
}

// trigger events //////////////////////////////////////////////////////

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

// misc ////////////////////////////////////////////////////////////////

long ifloor(T)(T x)
{
    return floor(x).to!long;
}

ulong toHash(T)(T x)
{
	return typeid(x).getHash(&x);
}

void followUp(T)(ref T follower, T master)
{
	static if(isFloatingPoint!T)
	{
		if(isNaN(master)) return;
	}
	if(master>follower) follower=master;
}

void followDown(T)(ref T follower, T master)
{
	static if(isFloatingPoint!T)
	{
		if(isNaN(master)) return;
	}
	if(master<follower) follower=master;
}

T weightedAvg(T)(T weight1, T x1, T x2)
{
	return weight1*x1 + (1-weight1)*x2;
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

ulong getMsec()
{
	return TickDuration.currSystemTick.msecs;
}

ulong msecSince(long refTime)
{
	return TickDuration.currSystemTick.msecs - refTime;
}

void sleepMsec(uint duration)
{
	if(duration==0)
	{
		core.thread.Thread.yield;
	}else{
		core.thread.Thread.sleep( dur!("msecs")( duration ) );
	}
}

DateTime now()
{
	return cast(DateTime)Clock.currTime;
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
