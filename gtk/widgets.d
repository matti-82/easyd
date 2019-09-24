module easyd.gtk.widgets;

// (C) 2014-2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import easyd.base;
import easyd.gtk.base;

import gtk.Button;
import gtk.Entry;
import gtk.EditableIF;
import gtk.SpinButton;
import gtk.CheckButton;

class Button : gtk.Button.Button
{
    void delegate()[] onClick;

    this(string s, void delegate() onclick=null)
    {
        super(s);
        addOnClicked(&onClickFunc);
        if(onclick !is null)
        {
            onClick ~= onclick;
        }
    }

    this(StockID id, void delegate() onclick=null)
    {
        super(id);
        addOnClicked(&onClickFunc);
        if(onclick !is null)
        {
            onClick ~= onclick;
        }
    }

    protected void onClickFunc(gtk.Button.Button b)
    {
        onClick.trigger();
    }
}

class LineEdit : Entry, IBindable!string
{
    void delegate(string)[] onChange;
	void delegate()[] onPressEnter;

    this()
    {
        super();
        addOnChanged(&onChangeFunc);
		addOnActivate(&onPressEnterFunc);
    }

    protected void onChangeFunc(EditableIF e)
    {
        onChange.trigger((cast(Entry)e).getText());
    }

	protected void onPressEnterFunc(Entry e)
	{
		onPressEnter.trigger;
	}

	@property string value()
	{
		return getText;
	}
	alias value this;

	@property void value(string val)
	{
		setText(val);
	}
}

class SpinBox(T) : gtk.SpinButton.SpinButton, IBindable!T
{
	this(real min=0, real max=100, real step=1)
	{
		super(min,max,step);
	}

	@property T value()
	{
		return getValue.to!T;
	}
	alias value this;
	
	@property void value(T val)
	{
		setValue(val);
	}
}

class CheckBox : gtk.CheckButton.CheckButton, IBindable!bool
{
	this(string label="")
	{
		super(label);
	}

	@property bool value()
	{
		return getActive;
	}
	alias value this;
	
	@property void value(bool val)
	{
		setActive(val);
	}
}

