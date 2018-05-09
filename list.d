module easyd.list;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import std.typecons;
import std.traits;
import std.bigint;
import std.stdio;
import std.conv;
import std.algorithm;

import easyd.base;

unittest
{
	class Person
	{
		string firstName;
		string lastName;
		string likes;
		
		this(string fn,string ln,string li)
		{
			firstName=fn;
			lastName=ln;
			likes=li;
		}
		
		string name()
		{
			return firstName~" "~lastName;
		}
	}
	
	List!Person persons;
	with(persons)
	{
		add(new Person("Walter","Bright","D"));
		add(new Person("Andrei","Alexandrescu","D"));
		add(new Person("Bjarne","Stroustrup","C++"));
	}
	
	auto selection = persons.selection.filter(p => p.likes=="D").sortAsc(p => p.firstName);
	assert(selection[0].name=="Andrei Alexandrescu");
	assert(selection[1].name=="Walter Bright");
	
	auto index = persons.createIndex(p => p.name);
	auto p = index["Andrei Alexandrescu"];
	assert(p.likes=="D");
}

struct LinkedListDescriptor
{
	ptrdiff_t startLocation = -1;
	
	void del(TIterator)(ref TIterator it)
	{
		it.container.del(this,it);
	}
}

struct LinkedListPointer(TValue)
{
	ptrdiff_t location;
	CLinkedListContainer!TValue container;

	this(const CLinkedListContainer!TValue cont, LinkedListDescriptor list)
	{
		container = cast(CLinkedListContainer!TValue)cont;
		location = list.startLocation;
	}
	
	this(CLinkedListContainer!TValue cont, ptrdiff_t idx)
	{
		container = cont;
		location = idx;
	}
	
	bool hasValue()
	{
		return location>=0;
	}
	
	ref TValue value()
	{
		return container.values[location];
	}	

	private ptrdiff_t nextLocation()
	{
		if(hasValue)
		{
			return container.nextLocations[location];
		}
		else
		{
			return -1;
		}
	}
	
	private ptrdiff_t prevLocation()
	{
		if(hasValue)
		{
			return container.prevLocations[location];
		}
		else
		{
			return -1;
		}
	}
}

struct LinkedListIterator(TValue)
{
	LinkedListPointer!TValue ptr;
	alias ptr this;

	bool skipNextInc=false;
	
	this(const CLinkedListContainer!TValue cont, LinkedListDescriptor list)
	{
		container = cast(CLinkedListContainer!TValue)cont;
		location = list.startLocation;
	}
	
	this(CLinkedListContainer!TValue cont, ptrdiff_t idx)
	{
		container = cont;
		location = idx;
	}
	
	void opUnary(string op)()
		if (op == "++")
	{
		if(!skipNextInc) location = nextLocation();
		skipNextInc = false;
	}

	void opUnary(string op)()
		if (op == "--")
	{
		location = prevLocation();
	}
}

class CLinkedListContainer(TValue)
{
	void delegate(LinkedListPointer!TValue)[] beforeDel;
	TValue[] values;
	protected ptrdiff_t[] nextLocations;
	protected ptrdiff_t[] prevLocations;
	protected ptrdiff_t freeLocation=-1;
	
	void clear()
	{
		for(ptrdiff_t pos=0; pos<values.length; pos++)
		{
			static if(is(TValue:Object) || isDynamicArray!TValue || isAssociativeArray!TValue)
			{
				values[pos] = null;
			}
			nextLocations[pos] = pos + 1;
			//prevLocations[pos] = pos - 1; //Initialisierung von prevLocations nicht nötig,
			//weil sie beim Hinzufügen von Items initialisiert werden und für die Frei-Liste irrelevant sind
		}
		nextLocations[values.length-1] = -1;

		freeLocation = 0;
	}
	
	void addAnywhere(ref LinkedListDescriptor list, TValue val)
	{
		//insert after 1st item, because that requires no searching
		addAfter(list,list.startLocation,val);
	}
	
	ptrdiff_t addAfter(ref LinkedListDescriptor list, ptrdiff_t prevLocation, TValue val)
	{
		//writeln("addAfter " ~ prevLocation.to!string);
		auto pos = addHelper(val);
		//writeln("DestPos: " ~ pos.to!string);
		
		if(list.startLocation<0)
		{   //create 1-item-list
			nextLocations[pos] = -1;
			prevLocations[pos] = -1;
			list.startLocation = pos;
		}
		else if (prevLocation<0)
		{	//insert at beginning
			auto nextLocation = list.startLocation;
			nextLocations[pos] = nextLocation;
			list.startLocation = pos;
			
			prevLocations[pos] = prevLocation;
			if(nextLocation>=0) prevLocations[nextLocation] = pos;
		}
		else
		{   //insert into list
			auto nextLocation = nextLocations[prevLocation];
			nextLocations[pos] = nextLocation;
			nextLocations[prevLocation] = pos;

			prevLocations[pos] = prevLocation;
			if(nextLocation>=0) prevLocations[nextLocation] = pos;
		}
		
		//writeln("Finished addAfter");
		return pos;
	}

	ptrdiff_t del(ref LinkedListDescriptor list, LinkedListPointer!TValue it) //returns location of next item
	{
		if(it.container!=this)
		{
			throw exception("LinkedListPointer not from this container");
		}

		beforeDel.trigger(it);
		
		auto nextLocation = it.nextLocation;
		auto prevLocation = it.prevLocation;
		
		//writeln("prev=",prevLocation," next=",nextLocation);
		
		//Wert zurücksetzen, damit der GC keine unnötigen Objekte behält
		static if(is(TValue==class) || isDynamicArray!TValue)
		{
			values[it.location] = null;
		}
		
		//eigene Liste wieder zusammenfügen
		if(it.location==list.startLocation)
		{
			//writeln("Change list start");
			list.startLocation = nextLocation;
		}
		else
		{
			nextLocations[prevLocation] = nextLocation;
		}
		if(nextLocation>=0)
		{
			prevLocations[nextLocation] = prevLocation;
		}
		
		//frei gewordenes Item am Anfang der Frei-Liste einfügen
		nextLocations[it.location] = freeLocation;
		freeLocation = it.location;

		return nextLocation;
	}

	void del(ref LinkedListDescriptor list, ref LinkedListIterator!TValue it)
	{
		it.location = del(list,it.ptr);
		it.skipNextInc = true;
	}
	
	/* TODO for DocMan
	void bubbleUp(ref LinkedListDescriptor list, LinkedListPointer!TValue it)
	{
		if(it.container!=this)
		{
			throw exception("LinkedListPointer not from this container");
		}
		
		if(it.location == list.startLocation)
		{
			return;
		}
		
		auto nextlocation = it.nextLocation;
		auto prevlocation = it.prevLocation(list);
		
		if(prevlocation == list.startLocation)
		{
			nextLocations[list.startLocation] = nextlocation;
			nextLocations[it.location] = list.startLocation;
			list.startLocation = it.location;
		}
		else
		{
			auto previt = LinkedListPointer!TValue(this,prevlocation);
			auto prevprevlocation = previt.prevLocation(list);
			
			nextLocations[prevlocation] = nextlocation;
			nextLocations[it.location] = prevlocation;
			nextLocations[prevprevlocation] = it.location;
		}
	}
	
	void bubbleDown(ref LinkedListDescriptor list, LinkedListPointer!TValue it)
	{
		if(it.container!=this)
		{
			throw exception("LinkedListPointer not from this container");
		}
		
		if(it.nextLocation<0)
		{
			return;
		}
		
		auto nextlocation = it.nextLocation;
		auto prevlocation = it.prevLocation(list);
		auto nextit = LinkedListPointer!TValue(this,nextlocation);
		auto nextnextlocation = nextit.nextLocation;
		
		nextLocations[nextlocation] = it.location;
		nextLocations[it.location] = nextnextlocation;
		
		if(it.location == list.startLocation)
		{
			list.startLocation = nextlocation;
		}
		else
		{
			nextLocations[prevlocation] = nextlocation;
		}
	}
	*/
	
	LinkedListIterator!TValue iterator(LinkedListDescriptor list) const
	{
		return LinkedListIterator!TValue(this,list);
	}
	
	protected ptrdiff_t addHelper(TValue val)
	{
		if(freeLocation<0) increaseSize();
		
		ptrdiff_t pos = freeLocation;
		freeLocation = nextLocations[pos];
		values[pos] = val;
		
		return pos;
	}
	
	protected void increaseSize()
	{
		if(freeLocation>=0)
		{
			return;
		}
		
		auto oldsize = values.length;
		if(oldsize==0)
		{
			auto initialsize = 1024 / max(TValue.sizeof,ptrdiff_t.sizeof); //initial max. 1 KB pro Sub-Array
			if(initialsize<1) initialsize=1;
			if(initialsize>64) initialsize=64;
			values.length = initialsize;
			nextLocations.length = initialsize;
			prevLocations.length = initialsize;
		}
		if(oldsize<=MEBI)
		{
			values.length *= 2;
			nextLocations.length *= 2;
			prevLocations.length *= 2;
		}
		else
		{
			values.length += MEBI;
			nextLocations.length += MEBI;
			prevLocations.length += MEBI;
		}
		
		for(ptrdiff_t pos=oldsize; pos<values.length; pos++)
		{
			nextLocations[pos] = pos + 1;
			//prevLocations[pos] = pos - 1; //Initialisierung von prevLocations nicht nötig,
			//weil sie beim Hinzufügen von Items initialisiert werden und für die Frei-Liste irrelevant sind
		}
		nextLocations[values.length-1] = -1;
		
		freeLocation = oldsize;
	}
}

struct LinkedListContainer(TValue)
{
	mixin ImplementStruct!(CLinkedListContainer!TValue);
}

class CList(T) /*: ISpecialSerialize*/
{
	size_t length = 0;
	ListIndex!(T,T) mainIndex;
	bool valuesCanChange;
	CLinkedListContainer!T container;
	protected LinkedListDescriptor list;
	protected ptrdiff_t lastLocation;
	protected IListIndex[] indexes; //TODO: auf signale umstellen
	protected bool consecutive = true;
	
	this(bool valuescanchange = true)
	{
		container.create;
		valuesCanChange = valuescanchange;
	}

	void check()
	{
		ptrdiff_t last=-1;
		for(auto it=iterator;it.hasValue;it++)
		{
			if(it.prevLocation!=last) throw exception("Linked list broken, last item was "~last.to!string~" but prevLocation of "~it.location.to!string~" points to "~it.prevLocation.to!string);
			last = it.location;
		}
		writeln("List-links ok");
	}
	
	CList!T dup()
	{
		auto result = new CList!T;
		foreach(it,item;this) result.add(it.value);
		return result;
	}

	void clear()
	{
		container.clear;
		list.startLocation = -1;
		consecutive = true;
		length=0;
		foreach(index;indexes)
		{
			index.invalidate;
		}
	}
	
	void add(T item)
	{
		lastLocation = container.addAfter(list,lastLocation,item);
		addHelper;
	}
	
	void addBefore(LinkedListPointer!T before, T newItem)
	{
		//writeln("addBefore");
		if(!before.hasValue)
		{
			//writeln("Can't addBefore, doing normal add");
			add(newItem);
		}

		container.addAfter(list,before.prevLocation,newItem);
		addHelper;
	}
	
	void addIfNew(T item)
	{
		if(!pointerOf(item).hasValue) add(item);
	}

	static if(is(T==class))
	{
		T2 addNew(T2=T,P...)(P par)
		{
			T2 obj = new T2(par);
			add(obj);
			return obj;
		}
	}
	else
	{
		T* addNew()
		{
			add(T.init);
			return &(container.values[lastLocation]);
		}
	}

	void replace(LinkedListPointer!T it, T newValue)
	{
		container.values[it.location] = newValue;
		//TODO: Indices aktualisieren
	}
	
	ptrdiff_t del(LinkedListPointer!T it) //returns location of next item
	{
		//writeln("list.del ",this," ",it.location);
		if(it.location<0)
		{
			return -1;
		}
		if(it.location==lastLocation)
		{
			lastLocation = it.prevLocation;
		}
		else
		{
			consecutive = false;
		}
		if(indexes !is null)
		{
			//writeln("Updating indexes...");
			foreach(index;indexes)
			{
				index.autoNotifyBeforeDelete(it.location);
			}
			//writeln("...finished updating indexes");
		}
		length--;
		return container.del(list,it);
	}

	void del(ref LinkedListIterator!T it)
	{
		if(it.container!=container) return;
		it.location = del(it.ptr);
		it.skipNextInc = true;
	}

	void delFirst(T value)
	{
		auto it = pointerOf(value);
		if(it.hasValue)
		{
			del(it);
		}
	}
	
	LinkedListIterator!T iterator() const
	{
		return container.iterator(list);
	}
	
	LinkedListIterator!T lastIterator()
	{
		return LinkedListIterator!T(container,lastLocation);
	}
	
	ref T first()
	{
		return iterator.value;
	}
	
	ref T opIndex(size_t pos)
	{
		if(consecutive)
		{
			return container.values[pos];
		}
		else
		{
			throw exception("Usage of index operator not allowed after inserting or deleting items from a position before the end of list");
		}
	}
	
	static if(is(T==class)) // class /////////////////////////////////////////////////////////////////////
	{
		int opApply(int delegate(T) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(it.value);
				if (result) break;
			}
			return result;
		}
		
		int opApply(int delegate(ref LinkedListIterator!T, T) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(it,it.value);
				if (result) break;
			}
			return result;
		}
	}
	else static if(__traits(hasMember, T, "tupleof")) // struct ////////////////////////////////////////////
	{
		int opApply(int delegate(T*) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(cast(T*)&(container.values[it.location]));
				if (result) break;
			}
			return result;
		}
		
		int opApply(int delegate(ref LinkedListIterator!T, T*) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(it,cast(T*)&(container.values[it.location]));
				if (result) break;
			}
			return result;
		}
	}
	else // simple type ///////////////////////////////////////////////////////////////////////////////////
	{
		int opApply(int delegate(const T) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(it.value);
				if (result) break;
			}
			return result;
		}
		
		int opApply(int delegate(ref LinkedListIterator!T, const T) dg) const
		{
			int result = 0;
			for (auto it = iterator; it.hasValue; it++)
			{
				result = dg(it,it.value);
				if (result) break;
			}
			return result;
		}
	}
	
	Selection!T selection() const
	{
		return new Selection!T(this,true);
	}
	//alias selection this;
	
	ListIndex!(T,TKey) createIndex(TKey)(TKey delegate(T) sd, bool constField=false, size_t estimListLength=0)
	{
		auto result = new ListIndex!(T,TKey)(this,sd,constField,estimListLength);
		indexes ~= result;
		return result;
	}
	
	LinkedListPointer!T pointerOf(T value)
	{
		if(mainIndex is null)
		{
			mainIndex = createIndex(item=>item,!valuesCanChange);
		}
		return mainIndex(value);
	}
	
	bool contains(T value)
	{
		return pointerOf(value).hasValue;
	}

	bool contains(bool delegate(T) sd)
	{
		return find(sd).hasValue;
	}
	
	LinkedListPointer!T find(bool delegate(T) sd)
	{
		for(auto it=iterator; it.hasValue; it++)
		{
			if(sd(it.value)) return it;
		}
		return LinkedListPointer!T(container,-1);
	}

	T2 find(T2)(bool delegate(T2) sd)
		if(is(T2==class))
	{
		foreach(item;this)
		{
			if(item.inherits!T2)
			{
				T2 t = cast(T2)item;
				if(sd(t)) return t;
			}
		}
		return T2.init;
	}
	
	/* TODO for DocMan
	void bubbleUp(LinkedListPointer!T it)
	{
		container.bubbleUp(list,it);
	}
	
	void bubbleDown(LinkedListPointer!T it)
	{
		container.bubbleDown(list,it);
	}
	*/

	CList!T opBinary(string op)(CList!T other)
	{
		static if (op == "~")
		{
			auto result = dup;
			foreach(item;other) result.add(item);
			return result;
		}else{
			assert(0, "Operator "~op~" not implemented");
		}
	}

	/*void serialize(ISerializer destination) 
	{
		//writeln("List serialize");
		foreach(it,item;this)
		{
			destination.serializeSubItem("",it.value);
		}
	}
	
	bool deserialize(IDeserializer source)
	{
		foreach(child;source.current.children)
		{
			auto newitem = source.deserialize!T(child);
			static if(__traits(hasMember, T, "_first_member_inline_"))
			{
				newitem.tupleof[0] = StringConvert!(typeof(newitem.tupleof[0])).parse(child.value);
			}
			add(newitem);
		}
		return true;
	}*/

	void compact()
	{
		ptrdiff_t maxloc=0;
		for(auto it=iterator;it.hasValue;it++) if(it.location>maxloc) maxloc=it.location;
		container.values.length = maxloc+1;
		container.nextLocations.length = maxloc+1;
		container.prevLocations.length = maxloc+1;
		if(container.freeLocation>=container.values.length) container.freeLocation=-1;
	}
	
	protected void addHelper()
	{
		length++;
		if(indexes !is null)
		{
			//writeln("Updating indexes...");
			foreach(index;indexes)
			{
				index.autoNotifyAdded(lastLocation);
			}
			//writeln("...finished updating indexes");
		}
	}
}

struct List(T)
{
	mixin ImplementStruct!(CList!T);
}

class Selection(T)
{
	bool sorted = false;
	protected T[] source;
	protected CList!T sourceList;
	protected size_t[] locations;
	
	this(const T[] src, bool addAll=false)
	{
		source = cast(T[])src;
		if(addAll)
		{
			for(size_t x=0; x<source.length; x++)
			{
				add(x);
			}
		}
	}
	
	this(const CList!T src, bool addAll=false)
	{
		source = cast(T[])(src.container.values);
		sourceList = cast(CList!T)src;
		if(addAll)
		{
			foreach(it,val;src)
			{
				add(it.location);
			}
		}
	}
	
	size_t length()
	{
		return locations.length;
	}

	Selection!T filter(bool delegate(T) condition)
	{
		size_t[] newlocations;
		foreach(l;locations)
		{
			if(condition(source[l])) newlocations ~= l;
		}
		locations = newlocations;
		return this;
	}
	
	Selection!T sortAsc(TKey)(TKey delegate(T) select)
	{
		if(sorted)
		{
			sort!((i1,i2) => select(source[i1])<select(source[i2]), SwapStrategy.stable)(locations);
		}
		else
		{
			sort!((i1,i2) => select(source[i1])<select(source[i2]), SwapStrategy.unstable)(locations);
		}
		sorted = true;
		return this;
	}
	
	Selection!T sortDesc(TKey)(TKey delegate(T) select)
	{
		if(sorted)
		{
			sort!((i1,i2) => select(source[i1])>select(source[i2]), SwapStrategy.stable)(locations);
		}
		else
		{
			sort!((i1,i2) => select(source[i1])>select(source[i2]), SwapStrategy.unstable)(locations);
		}
		sorted = true;
		return this;
	}
	
	ref T opIndex(size_t pos)
	{
		return source[locations[pos]];
	}
	
	static if(__traits(hasMember, T, "tupleof") && !isTuple!T)
	{
		static if(is(T==class))
		{
			int opApply(int delegate(T) dg)
			{
				int result = 0;
				foreach(location;locations)
				{
					result = dg(source[location]);
					if (result) break;
				}
				return result;
			}
			
			int opApply(int delegate(ptrdiff_t,T) dg)
			{
				int result = 0;
				foreach(index,location;locations)
				{
					result = dg(index,source[location]);
					if (result) break;
				}
				return result;
			}
			
			int opApply(int delegate(ptrdiff_t,LinkedListIterator!T, T) dg)
			{
				if(sourceList is null)
				{
					throw exception("Foreach with LinkedListIterator is not allowed on arrays");
				}
				int result = 0;
				foreach(index,location;locations)
				{
					result = dg(index,LinkedListIterator!T(sourceList.container,location),source[location]);
					if (result) break;
				}
				return result;
			}
		}
		else
		{
			int opApply(int delegate(T*) dg)
			{
				int result = 0;
				foreach(location;locations)
				{
					result = dg(&(source[location]));
					if (result) break;
				}
				return result;
			}
			
			int opApply(int delegate(ptrdiff_t,T*) dg)
			{
				int result = 0;
				foreach(index,location;locations)
				{
					result = dg(index,&(source[location]));
					if (result) break;
				}
				return result;
			}
			
			int opApply(int delegate(ptrdiff_t,LinkedListIterator!T, T*) dg)
			{
				if(sourceList is null)
				{
					throw exception("Foreach with LinkedListIterator is not allowed on arrays");
				}
				int result = 0;
				foreach(index,location;locations)
				{
					result = dg(index,LinkedListIterator!T(sourceList.container,location),&(source[location]));
					if (result) break;
				}
				return result;
			}
		}
	}else{
		int opApply(int delegate(const T) dg)
		{
			int result = 0;
			foreach(location;locations)
			{
				result = dg(source[location]);
				if (result) break;
			}
			return result;
		}
		
		int opApply(int delegate(ptrdiff_t,const T) dg)
		{
			int result = 0;
			foreach(index,location;locations)
			{
				result = dg(index,source[location]);
				if (result) break;
			}
			return result;
		}
		
		int opApply(int delegate(ptrdiff_t,LinkedListIterator!T, const T) dg)
		{
			if(sourceList is null)
			{
				throw exception("Foreach with LinkedListIterator is not allowed on arrays");
			}
			int result = 0;
			foreach(index,location;locations)
			{
				result = dg(index,LinkedListIterator!T(sourceList.container,location),source[location]);
				if (result) break;
			}
			return result;
		}
	}
	
	protected void add(size_t location)
	{
		locations ~= location;
	}
}

abstract class IListIndex
{
	protected LinkedListDescriptor[] hashTable;
	protected CLinkedListContainer!ptrdiff_t locationContainer;
	
	protected abstract ulong hashOfLocation(ptrdiff_t location);
	
	void autoNotifyAdded(ptrdiff_t location)
	{
		//writeln("autoNotifyAdded " ~ location.to!string);
		if(hashTable !is null)
		{
			locationContainer.addAnywhere(hashTable[hashOfLocation(location) % hashTable.length],location);
			//writeln("Added item at " ~ location.to!string ~ " to index");
		}
	}
	
	void autoNotifyBeforeDelete(ptrdiff_t location)
	{
		if(hashTable !is null)
		{
			auto loclist = hashTable[hashOfLocation(location) % hashTable.length];
			for(auto it=locationContainer.iterator(loclist); it.hasValue; it++)
			{
				if(it.value == location)
				{
					locationContainer.del(loclist,it);
					//writeln("Deleted item "~location.to!string~" from index");
					return;
				}
			}
		}
	}

	void invalidate()
	{
		hashTable = null;
		locationContainer = null;
	}
}

size_t hash(BigInt x)
{
	return x.toLong;
}

size_t hash(T)(T x)
	if(!is(T:BigInt))
{
	return x.toHash;
}

class ListIndex(TItem,TKey) : IListIndex
{
	static immutable size_t defaultHashTableSize = 10240;
	size_t maxIterations = 10;
	static immutable float hashTableBasicSizeFactor = 1;
	static immutable float hashTableComplexSizeFactor = 3;
	bool constField;
	size_t estimatedListLength;
	float hashTableSizeFactor;
	TItem defaultValue;
	protected CList!TItem list;
	protected TKey delegate(TItem) select;

	void _do_not_serialize_(){}
	
	protected this(CList!TItem li, TKey delegate(TItem) sd, bool constField=false, size_t estimListLength=0)
	{
		//writeln("Creating list index...");
		list = li;
		select = sd;
		this.constField = constField;
		estimatedListLength = estimListLength;
		static if(isBasicType!TKey)
		{
			hashTableSizeFactor = hashTableBasicSizeFactor;
		}
		else
		{
			hashTableSizeFactor = hashTableComplexSizeFactor;
		}
	}
	
	LinkedListPointer!TItem opCall(TKey key)
	{
		//writeln("Searching for ",key);
		checkHashTable;
		
		if(hashTable !is null)
		{
			//über hashTable suchen
			//writeln("Searching via Hash-Table");
			size_t hashentry = hash(key) % hashTable.length;
			for (auto it=locationContainer.iterator(hashTable[hashentry]); it.hasValue; it++)
			{
				auto itemkey = select(list.container.values[it.value]);
				if (itemkey == key)
				{
					return LinkedListPointer!TItem(list.container,it.value);
				}
				if(!constField)
				{
					if((hash(itemkey)%hashTable.length) != hashentry) //Key wurde geändert
					{
						writeln("Key wurde geändert und Item wird neu in ListIndex einsortiert");
						autoNotifyAdded(it.value);
						locationContainer.del(hashTable[hashentry],it);
					}
				}
			}
		}
		
		if(hashTable is null || !constField)
		{
			//iterieren
			//writeln("Searching via Iteration over ",list.length," items");
			for (auto it=list.iterator; it.hasValue; it++)
			{
				if (select(it.value) == key)
				{
					return it;
				}
			}
		}
		
		//nicht gefunden => return -1;
		//writeln("Not found");
		return LinkedListPointer!TItem(list.container,-1);
	}
	
	ref TItem opIndex(TKey key)
	{
		auto it = opCall(key);
		if(it.hasValue)
		{
			return it.value;
		}else{
			return defaultValue;
		}
	}

	bool contains(TKey key)
	{
		return opCall(key).hasValue;
	}
	
	Selection!TItem all(TKey key)
	{
		if(constField) checkHashTable;
		auto result = new Selection!TItem(list);
		
		if(hashTable is null || !constField)
		{
			//iterieren
			for (auto it=list.iterator; it.hasValue; it++)
			{
				if (select(it.value) == key)
				{
					result.add(it.location);
				}
			}
		}
		else
		{
			//über hashTable suchen
			auto hashCode = hash(key);
			for (auto it=locationContainer.iterator(hashTable[hashCode % hashTable.length]); it.hasValue; it++)
			{
				if (select(list.container.values[it.value]) == key)
				{
					result.add(it.value);
				}
			}
		}
		
		return result;
	}

	void update(TItem item)
	{
		auto it = opCall(select(item));
		if(it.hasValue)
		{
			it.value = item;
		}else{
			list.add(item);
		}
	}
	
	TKey key(LinkedListPointer!TItem item)
	{
		return select(item.value);
	}
	
	void notifyKeyChanged(TKey oldKey, LinkedListPointer!TItem item)
	{
		if(hashTable !is null)
		{
			auto hashtablepos = hash(oldKey) % hashTable.length;
			for(auto it=locationContainer.iterator(hashTable[hashtablepos]); it.hasValue; it++)
			{
				if(it.value == item.location)
				{
					locationContainer.del(hashTable[hashtablepos],it);
					//writeln("Refreshing item "~item.location.to!string~" in index");
					break;
				}
			}
			autoNotifyAdded(item.location);
		}
	}
	
	protected override ulong hashOfLocation(ptrdiff_t location)
	{
		//writeln("hashOfLocation...");
		return hash(select(list.container.values[location]));
	}
	
	protected void checkHashTable()
	{
		if(hashTable is null && list.length>maxIterations)
		{
			if(estimatedListLength>0)
			{
				hashTable.length = (max(estimatedListLength,list.length) * hashTableSizeFactor).to!size_t;
			}
			else
			{
				hashTable.length = max((list.length * hashTableSizeFactor).to!size_t, defaultHashTableSize);
			}
			//writeln("Created hash table with " ~ hashTable.length.to!string ~ " entries.");
			locationContainer = new CLinkedListContainer!ptrdiff_t;
			
			for (auto it=list.iterator; it.hasValue; it++)
			{
				autoNotifyAdded(it.location);
			}
		}
	}
}
