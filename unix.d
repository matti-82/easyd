module easyd.unix;

// (C) 2014-2018 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

public import std.file; //must be imported here as public instead of easyd/package.d, otherwise the resolving of some functions would be ambigious

import std.path;
import std.format;
import std.conv;
import std.algorithm;
import std.process;

import easyd.base;
import easyd.string;
import easyd.stream;

unittest
{
	assert(parentDir("/home/test")=="/home");
	assert(pathEqual("/home/test/bla/../","/home/test"));
	assert("/home/test".slash=="/home/test/");
	assert("/home/test/".slash=="/home/test/");
	assert("/home/test".unslash=="/home/test");
	assert("/home/test/".unslash=="/home/test");
	assert(fullPath("~/test")=="/home/"~userName~"/test");
	assert("../test/my.file".fullPathFrom("/home/bla")=="/home/test/my.file");
	assert(pureName("/tmp/test.tar.gz",false)=="test.tar");
	assert(pureName("/tmp/test.tar.gz",true)=="test");
	
	auto stream = new StdoutStream("echo test");
	assert(stream.readLine=="test");
}

string parentDir(string s)
{
	return s.fullPath.dirName;
}

bool resetDir(string d)
{
	Try(rmdirRecurse(d));
	return Try(mkdirRecurse(d));
}

bool isExecutable(string fn, bool acceptDirs=true)
{
	try
	{
		return (acceptDirs || !isDir(fn)) && (format("%o",getAttributes(fn)).getEnd(1).to!int & 1) > 0;
	}catch(Exception e){
		return false;
	}
}

bool isDir(string s)
{
	bool result = false;
	try
	{
		result = std.file.isDir(s);
	}catch(Exception e){}
	return result;
}

bool pathEqual(string p1,string p2)
{
	return p1.fullPath.unslash==p2.fullPath.unslash;
}

string slash(string s)
{
	return s.endsWith(dirSeparator)? s : s ~ dirSeparator;
}

string unslash(string s)
{
	return s.endsWith(dirSeparator)? s.cutEnd(1) : s;
}

string fullPath(string s)
{
	return s.expandTilde.absolutePath.buildNormalizedPath;
}

string fullPathFrom(string s, string refPath)
{
	string refdir;
	if(refPath.exists && !refPath.isDir)
	{
		refdir = refPath.dirName;
	}else{
		refdir = refPath;
	}
	return s.expandTilde.absolutePath(refdir).buildNormalizedPath;
}

string pureName(string s, bool multiStrip=false)
{
	s = s.baseName;
	if(multiStrip)
	{
		while(s.contains('.')) s = s.stripExtension;
		return s;
	}else{
		return s.stripExtension;
	}
}

string userName()
{
	return fullPath("~").baseName;
}

struct ScopedChdir
{
	string prevDir;
	string newDir;
	bool isTemp;

	this(string newdir, bool istemp=false)
	{
		prevDir = getcwd;
		newDir = newdir.absolutePath;
		isTemp = istemp;
		chdir(newDir);
	}

	~this()
	{
		chdir(prevDir);
		if(isTemp) rmdirRecurse(newDir);
	}
}

void symLink(string source,string dest,bool relative=true)
{
	source = source.absolutePath;
	if(relative) source = source.relativePath(dest.dirName.absolutePath);
	Try(remove(dest));
	symlink(source,dest);
}

string resolveLink(string symlink)
{
	try
	{
		symlink = symlink.absolutePath;
		return readLink(symlink).absolutePath(symlink.dirName);
	}catch(Exception e){
		return "";
	}
}

bool isLink(string symlink)
{
	return resolveLink(symlink)!="";
}

class StdoutStream : FileReader
{
	this(string command)
	{
		auto pipes = pipeShell(command,Redirect.stdout | Redirect.stderrToStdout);
		file = pipes.stdout;
	}
}

class TarStream : StdoutStream
{
	this(string path)
	{
		super("tar -c "~path);
	}
}

class UntarStream : FileWriter
{
	this()
	{
		auto pipes = pipeShell("tar -x",Redirect.stdin);
		file = pipes.stdin;
	}
}

