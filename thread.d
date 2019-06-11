module easyd.thread;

// (C) 2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import core.thread;

unittest
{
	@nogc void twice(int* x)
	{
		*x *= 2;
	}
	
	int x=1;
	
	auto thread = startRealtimeThread(&twice,&x);
	thread.join;
	
	realtimeFunc(&twice,&x);
	
	assert(x==4);
}

Thread startThread(TFunc,TParam...)(TFunc threadFunc, TParam param)
{
	return (new Thread(()=>threadFunc(param))).start;
}

Thread startRealtimeThread(TFunc,TParam...)(TFunc threadFunc, TParam param) //threadFunc must be @nogc
{
	return (new Thread(()=>detachedFunc(threadFunc,param))).start;
}

void realtimeFunc(TFunc,TParam...)(TFunc func, TParam param) //func must be @nogc
{
	detachedFunc(func,param);
	thread_attachThis();
}

private @nogc void detachedFunc(TFunc,TParam...)(TFunc func, TParam param)
{
	thread_detachThis();
	func(param);
}

