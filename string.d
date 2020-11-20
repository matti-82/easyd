module easyd.string;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import std.conv;
import std.stdio;
import std.string;

unittest
{
	string s = "Hello World!";
	assert(s.countChar('l')==3);
	assert(s.find('H')==0);
	assert(s.find("World")==6);
	assert(s.contains('!'));
	assert(s.contains("or"));
	assert(s.replace("l","L")=="HeLLo WorLd!");
	assert(s.subStr(1,4)=="ello");
	assert(s.getEnd(1)=="!");
	assert(s.cutEnd(7)=="Hello");
	assert(s.grow(20,'-',true)=="--------Hello World!");
	int[] a = [1,2,3];
	assert(a.concat(",")=="1,2,3");
}

string decPoint(T)(T x)
{
	return x.to!string.replace(",",".");
}

size_t countChar(string s, char c)
{
    size_t result = 0;
    foreach(x;s) if(x==c) result++;
    return result;
}

long find(string s, char c, long start=0)
{
    for(long pos=start; pos<s.length.to!long; pos++)
    {
        if(s[pos]==c) return pos;
    }
    return -1;
}

bool contains(string s, char c, long start=0, long* foundAtPos=null)
{
    long p = find(s,c,start);
    if(foundAtPos)
    {
        *foundAtPos = p;
    }
    return p>=0;
}

long find(string s, string f, long start=0, bool returnLengthIfNotFound=false)
{
	//writeln("Searching for "~f~" in "~s~" from position "~start.to!string);
    long maxpos = s.length.to!long-f.length.to!long;
    for(long pos=start; pos<=maxpos; pos++)
    {
        for(long offset=0; offset<f.length; offset++)
        {
            if(s[pos+offset]!=f[offset]) goto next;
        }
        return pos;
        next:;
    }
	return returnLengthIfNotFound? s.length : -1;
}

bool contains(string s, string f, long start=0, long* foundAtPos=null)
{
    long p = indexOf(s,f,start);
    if(foundAtPos)
    {
        *foundAtPos = p;
    }
    return p>=0;
}

/*string replace(string s, string f, string r) //not needed anymore in new D versions
{
	//writeln("Replacing "~f~" with "~r~" in "~s);
	long start=0;
    long findpos;
    while((findpos=s.find(f,start))>=0)
    {
        s = s[0..findpos] ~ r ~ s[findpos+f.length..s.length];
        start = findpos+1+r.length.to!long-f.length.to!long;
		if(start<=0) start = 1;
    }
    return s;
}*/

struct StringPair
{
	string first;
	string second;
	
	this(string f, string s="")
	{
		first=f;
		second=s;
	}
}

string replacePH(string s, StringPair placeHolders, string f, string r)
{
	return replace(s, placeHolders.first~f~placeHolders.second, r);
}

string subStr(string s, long start, long length=-1)
{
	if (start > s.length)
	{
		return "";
	}
	if (start<0)
	{
		start = 0;
	}
	long end;
	if (length<0)
	{
		end = s.length;
	}
	else
	{
		end = start+length;
	}
	if(end>s.length)
	{
		end=s.length;
	}
	return s[start..end];
}

string cutEnd(string s, long count)
{
	if (s.length > count)
	{
		return s.subStr(0, s.length - count);
	} 
	else
	{
		return "";
	}
}

string getEnd(string s, long count)
{
	return s.subStr(s.length - count, -1);
}

string grow(string s, int length, char fillChar=' ', bool atBeginning=false)
{
	if(s.length>=length) return s;
	string fillString;
	for(int x=0; x<(length-s.length); x++) fillString ~= fillChar;
	if(atBeginning)
	{
		return fillString ~ s;
	}
	else
	{
		return s ~ fillString;
	}
}

string concat(T)(T[] a,string separator="",string delegate(T) tostr = item=>item.to!string)
{
	string result;
	for(int x=0; x<a.length; x++)
	{
		result ~= tostr(a[x]);
		if(x<a.length-1) result ~= separator;
	}
	return result;
}

string inputLine()
{
	return std.stdio.readln.replace("\n","");
}

