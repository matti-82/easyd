module easyd.stream;

// (C) 2014-2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import std.stdio;
import std.traits;
import std.conv;
import std.file;
import std.path;
import std.algorithm.comparison;

import easyd.base;
import easyd.string;

unittest
{
	auto stream = new BufferStream;
	int x=123;
	stream.write(x);
	assert(stream.unreadBytes==4);
	assert(stream.read!int==123);
	assert(stream.unreadBytes==0);
}

interface IReadStream
{
	bool readBuf(ref Byte[] buf, ulong maxSize); //return false, if end of stream is reached
}

bool isAtEnd(IReadStream s)
{
	Byte[] buf;
	return !s.readBuf(buf,0);
}

T read(T)(IReadStream s)
	if(isBasicType!T)
{
	Byte[] buf;
	if(s.readBuf(buf,T.sizeof))
	{
		return buf.readFromPos!T(0);
	}
	else
	{
		throw exception("Read from stream failed",false);
	}
}

T read(T)(IReadStream s, ulong bufsize=0)
	if(is(T:string))
{
	ubyte[] ba;
	ba.length = bufsize;
	s.read(ba,bufsize==0);
	return cast(string)(ba.idup);
}

T read(T)(IReadStream s, ulong bufsize=0)
	if(is(T:Byte[]))
{
	ubyte[] ba;
	ba.length = bufsize;
	s.read(ba,bufsize==0);
	return ba;
}

ulong readVarBits(IReadStream s)
{
	ubyte b = s.read!ubyte;
	if(b<255)
	{
		return b;
	}else{
		return s.read!ulong;
	}
}

bool read(T)(IReadStream s, ref T[] buffer, bool evalLength)
{
	if(evalLength) buffer.length = s.readVarBits;
	try
	{
		//std.stdio.writeln("Reading array of "~buffer.length.to!string~" elements");
		static if(is(T:ubyte))
		{
			return s.readBuf(buffer,buffer.length);
		}else{
			foreach(ref item;buffer)
			{
				item = s.read!(typeof(item));
			}
			return true;
		}
	}
	catch(Exception e)
	{
		return false;
	}
}

string readLine(IReadStream s, bool includeNewLine=false, Byte[] bom=[239,187,191])
{
	char[] a;
	char c;
	while(true)
	{
		try
		{
			c = s.read!char;
			if(c=='\n')
			{
				if(includeNewLine) a ~= c;
				break;
			}
			a ~= c;
		}catch(Exception e){
			break;
		}
	}
	for(int x=0; x<bom.length && x<a.length; x++) if(a[x].to!Byte!=bom[x]) return a.idup;
	return a.idup.subStr(bom.length);
}

abstract class IWriteStream
{
	bool writeBuf(const Byte[] buf);
	void finish(){}
	
	void write(T)(T data)
		if(isBasicType!T)
	{
		Byte[] buf;
		buf.length = T.sizeof;
		buf.writeToPos(0,data);
		writeBuf(buf);
	}

	void writeVarBits(ulong x)
	{
		if(x<255)
		{
			write(cast(ubyte)x);
		}else{
			ubyte m = 255;
			write(m);
			write(x);
		}
	}
	
	void write(T)(const T[] data, bool includeLength)
	{
		//std.stdio.writeln("IWriteStream.write");
		if(includeLength) writeVarBits(data.length);
		static if(is(T:ubyte) || is(T:char))
		{
			writeBuf(cast(ubyte[])data);
		}else{
			foreach(item;data)
			{
				write(item);
			}
		}
	}

	void writeLine(string s)
	{
		write(s,false);
		write('\n');
	}
}

abstract class IReadWriteStream : IWriteStream, IReadStream
{}

interface ISeekableStream
{
	void seekRead(ulong pos);
	void seekWrite(ulong pos);
}

abstract class ISeekableReadWriteStream : IReadWriteStream, ISeekableStream
{}

class RamStream : ISeekableReadWriteStream
{
	Byte[] data;
	ulong readPos=0;
	ulong writePos=0;

	bool readBuf(ref Byte[] buf, ulong maxSize)
	{
		buf.length = min(maxSize, data.length-readPos);
		for(uint x=0; x<buf.length; x++)
		{
			buf[x] = data[readPos++];
		}
		return buf.length>0 || readPos<data.length;
	}

	void seekRead(ulong pos)
	{
		readPos = pos;
	}

	override bool writeBuf(const Byte[] buf)
	{
		if(writePos==data.length)
		{
			data ~= buf;
			writePos += buf.length;
		}else{
			ulong neededlength = writePos + buf.length;
			if(data.length<neededlength) data.length=neededlength;
			for(uint x=0; x<buf.length; x++)
			{
				data[writePos++] = buf[x];
			}
		}
		return true;
	}

	void seekWrite(ulong pos)
	{
		writePos = pos;
	}

	void reset()
	{
		data.length=0;
		writePos=0;
		readPos=0;
	}
}

RamStream toStream(Byte[] a)
{
	auto result = new RamStream;
	result.data = a;
	return result;
}

class BufferStream : IReadWriteStream
{
	bool finished=false;
	protected Byte[] data;
	
	void peek(ref Byte[] buf, ulong maxSize)
	{
		buf.length = min(maxSize,unreadBytes);
		for(int x=0; x<buf.length; x++)
		{
			buf[x] = data[x];
		}
	}
	
	bool readBuf(ref Byte[] buf, ulong maxSize)
	{
		peek(buf,maxSize);
		if(buf.length>0)
		{
			for(int x=0; x<(data.length-buf.length); x++)
			{
				data[x] = data[x+buf.length];
			}
			data.length = data.length - buf.length;
		}
		//std.stdio.writeln("BufferStream readBuf done, unreadBytes=",unreadBytes);
		return buf.length>0 || unreadBytes>0 || !finished;
	}
	
	override bool writeBuf(const Byte[] buf)
	{
		data ~= buf;
		//std.stdio.writeln("BufferStream writeBuf done, unreadBytes=",unreadBytes);
		return true;
	}
	
	override void finish()
	{
		finished = true;
	}
	
	ulong unreadBytes()
	{
		return data.length;
	}
	
	void reset()
	{
		data.length=0;
		finished=false;
	}
}

class FileReader : IReadStream, ISeekableStream
{
	File file;
	
	this(string fileName, bool allowStdIn=false)
	{
		file = File(fileName,"r");
	}

	protected this(){}
	
	bool readBuf(ref Byte[] buf, ulong maxSize)
	{
		buf.length = maxSize;
		if(maxSize>0)
		{
			auto slice = file.rawRead(buf);
			buf.length = slice.length;
		}
		//writeln(buf.length," ",file.eof);
		return buf.length>0 || !file.eof;
	}

	void seekRead(ulong pos)
	{
		file.seek(pos);
	}

	void seekWrite(ulong pos)
	{
		throw exception("FileReader does not support writing");
	}
}

class FileWriter : IWriteStream, ISeekableStream
{
	protected File file;
	
	this(string fileName, bool append=false, bool allowStdOut=false)
	{
		if(allowStdOut && fileName=="-")
		{
			file = stdout;
		}else{
			mkdirRecurse(fileName.dirName);
			file = File(fileName,append?"a":"w");
		}
	}
	
	protected this(){}
	
	override bool writeBuf(const Byte[] buf)
	{
		return Try(file.rawWrite(buf));
	}
	
	override void finish()
	{
		file.close;
	}

	void seekWrite(ulong pos)
	{
		file.seek(pos);
	}

	void seekRead(ulong pos)
	{
		throw exception("FileWriter does not support reading");
	}
}

