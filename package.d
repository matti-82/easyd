// for those people who are too lazy to write the import for each module ;-)

module easyd;

public import easyd.base;
public import easyd.list;
public import easyd.string;
public import easyd.thread;
public import easyd.stream;

version(Windows)
{
}else{
	public import easyd.unix;
}

public import std.stdio;
public import std.algorithm.searching;
public import std.uni;
public import std.math;
